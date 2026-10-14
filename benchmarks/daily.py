#!/usr/bin/env python3
"""Measure whole dotfiles bootstrap and buu on a disposable macOS CI runner."""
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import platform
import re
import shutil
import subprocess
import time

FASTBREW_URL = 'https://github.com/tigercosmos/fastbrew/releases/download/v0.1.3/fastbrew-aarch64-apple-darwin'
FASTBREW_SHA256 = '8b4a6bea152b7c8a230c8f257b56ea49470a9a7ee1c8e38829b4aabc54f2720b'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--backend', required=True, choices=['homebrew', 'queries', 'native-experiment'])
parser.add_argument('--revision', required=True)
parser.add_argument('--base-revision', required=True)
parser.add_argument('--output-dir', required=True, type=pathlib.Path)
args = parser.parse_args()
if os.environ.get('GITHUB_ACTIONS') != 'true' or platform.system() != 'Darwin' or platform.machine() != 'arm64':
    parser.error('Run only on an ephemeral Apple Silicon GitHub Actions runner; this installs and upgrades every declared package.')
OUTPUT = args.output_dir.resolve()
OUTPUT.mkdir(parents=True, exist_ok=True)
PREFIX = pathlib.Path('/opt/homebrew')
env = dict(os.environ, HOMEBREW_NO_ANALYTICS='1', NONINTERACTIVE='1')
report = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'backend': args.backend,
    'revision': args.revision,
    'base_revision': args.base_revision,
    'platform': platform.platform(),
    'runner': os.environ.get('RUNNER_NAME'),
    'image_version': os.environ.get('ImageVersion'),
    'run_url': f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
    'buu': 'brew update && brew upgrade -y && fisher update',
    'limitations': [
        'Runner has preinstalled Homebrew packages; first install means first complete dotfiles deployment, not a factory-empty Mac.',
        'Real network and upstream metadata are live; runners and transfer speeds vary.',
        'Native experiment preinstalls core formulae except node with fastbrew, completes all remaining Brewfile work with Homebrew Bundle, and translates -y to fastbrew noninteractive upgrade only in this test.',
        'Node stays with Homebrew Bundle during bootstrap because it handles the runner preinstalled node@24 link conflict. The initial experiment without this fallback failed twice.',
        'Native experiment retains Homebrew update so the Homebrew executable itself is updated.',
        'Formula/cask inventories and outdated lists must be checked for equivalent work before reporting a speedup.',
    ],
    'steps': [],
}


def save():
    (OUTPUT/'result.json').write_text(json.dumps(report, indent=2)+'\n')


def inventory():
    formulae = {}
    for rack in sorted((PREFIX/'Cellar').glob('*')):
        if rack.is_dir():
            formulae[rack.name] = sorted(k.name for k in rack.iterdir() if (k/'INSTALL_RECEIPT.json').exists())
    casks = {}
    for rack in sorted((PREFIX/'Caskroom').glob('*')):
        if rack.is_dir():
            casks[rack.name] = sorted(k.name for k in rack.iterdir() if k.is_dir() and not k.name.startswith('.'))
    return {'formulae': formulae, 'casks': casks}


def run(name, command):
    print(f'::group::{name}', flush=True)
    start = time.perf_counter()
    with (OUTPUT/(name+'.log')).open('w') as log:
        process = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in process.stdout:
            log.write(line)
            print(line, end='', flush=True)
        status = process.wait()
    seconds = time.perf_counter()-start
    report['steps'].append({'name': name, 'command': command, 'seconds': seconds, 'returncode': status})
    save()
    print(f'::endgroup::\n{name}: {seconds:.3f}s; exit={status}', flush=True)
    if status:
        report['failure'] = name
        report['final_inventory'] = inventory()
        save()
        raise SystemExit(status)
    return seconds


def outdated(name):
    inspect_env = dict(env, HOMEBREW_NO_AUTO_UPDATE='1')
    result = subprocess.run([str(PREFIX/'bin/brew'), 'outdated', '--json=v2'], env=inspect_env, capture_output=True, text=True)
    (OUTPUT/(name+'.json')).write_text(result.stdout)
    if result.returncode:
        raise RuntimeError('Cannot verify outdated packages: '+result.stderr)
    return json.loads(result.stdout)


report['initial_inventory'] = inventory()
# Each measurement starts with an empty API/bottle cache. Never clear a user's cache.
cache = pathlib.Path.home()/'Library/Caches/Homebrew'
if cache.exists():
    shutil.rmtree(cache)
report['initial_cache'] = 'empty API and bottle cache'
save()
bootstrap_start = time.perf_counter()
run('initial-update', [str(PREFIX/'bin/brew'), 'update'])
run('install-chezmoi', [str(PREFIX/'bin/brew'), 'install', 'chezmoi'])
revision = args.revision if args.backend == 'queries' else args.base_revision
fastbrew = OUTPUT/'fastbrew'
if args.backend == 'native-experiment':
    run('download-fastbrew', ['curl', '-fL', '--retry', '2', FASTBREW_URL, '-o', str(fastbrew)])
    if hashlib.sha256(fastbrew.read_bytes()).hexdigest() != FASTBREW_SHA256:
        raise RuntimeError('fastbrew checksum mismatch')
    fastbrew.chmod(0o755)
    manifest = subprocess.check_output(['git', 'show', args.base_revision+':home/dot_config/brew/Brewfile'], text=True)
    # Every runner is arm64, so both arm64 conditional core formulae are included.
    core = [name for name in re.findall(r'^brew "([^"]+)"', manifest, re.MULTILINE) if '/' not in name and name != 'node']
    report['native_core_formulae'] = core
    run('native-core-install', [str(fastbrew), 'install', *core])
# Homebrew Bundle handles the same trusted taps, casks, and service declarations.
run('apply-dotfiles', [str(PREFIX/'bin/chezmoi'), 'init', 'collieiscute', '--revision', revision, '--apply', '-v'])
report['first_install_seconds'] = time.perf_counter()-bootstrap_start
report['before_buu_inventory'] = inventory()
report['before_buu_outdated'] = outdated('before-buu-outdated')
fish = PREFIX/'bin/fish'
run('record-buu-definition', [str(fish), '-c', 'functions buu; type brew'])
command = 'buu'
if args.backend == 'native-experiment':
    # Keep the user's literal buu alias and unrestricted upgrade scope.
    # v0.1.3 has no -y flag; native upgrade is already noninteractive.
    shim = OUTPUT/'native-benchmark.fish'
    shim.write_text('''function brew --wraps brew
    if test "$argv[1]" = upgrade
        set -l upgrade_args
        for arg in $argv[2..-1]
            if test "$arg" != -y; and test "$arg" != --yes
                set -a upgrade_args $arg
            end
        end
        command "$FASTBREW_BENCHMARK_BINARY" upgrade $upgrade_args
    else
        command brew $argv
    end
end
''')
    env['FASTBREW_BENCHMARK_BINARY'] = str(fastbrew)
    command = 'source '+str(shim)+'; buu'
report['buu_seconds'] = run('complete-buu', [str(fish), '--profile', str(OUTPUT/'buu.profile'), '-c', command])
profile = (OUTPUT/'buu.profile').read_text().splitlines()[1:]
report['buu_profile'] = []
for line in profile:
    match = re.match(r'\s*(\d+)\s+(\d+)\s+(.+)', line)
    if match:
        self_us, total_us, instruction = match.groups()
        report['buu_profile'].append({'self_seconds': int(self_us)/1e6, 'total_seconds': int(total_us)/1e6, 'command': instruction})
report['after_buu_inventory'] = inventory()
report['after_buu_outdated'] = outdated('after-buu-outdated')
run('verify-dependencies', [str(PREFIX/'bin/brew'), 'missing'])
for package in ['fish', 'fzf', 'node', 'nvim', 'tokei', 'uv']:
    run('smoke-'+package, [str(PREFIX/'bin'/package), '--version'])
report['complete'] = True
save()
summary = pathlib.Path(os.environ['GITHUB_STEP_SUMMARY'])
with summary.open('a') as f:
    f.write(f"{args.backend}: first installation {report['first_install_seconds']:.2f}s; complete buu {report['buu_seconds']:.2f}s. Raw logs and inventories are in the artifact.\n")
