#!/usr/bin/env python3
"""Time the user's complete live buu, including network checks and Fisher."""
import argparse
import datetime
import json
import os
import pathlib
import random
import statistics
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fastbrew', required=True, type=pathlib.Path)
parser.add_argument('--wrapper', required=True, type=pathlib.Path)
parser.add_argument('--output-dir', required=True, type=pathlib.Path)
parser.add_argument('--runs', type=int, default=3)
args = parser.parse_args()
if args.runs < 1:
    parser.error('--runs must be positive')
OUTPUT = args.output_dir.resolve()
OUTPUT.mkdir(parents=True, exist_ok=True)
PREFIX = pathlib.Path('/opt/homebrew')
env = dict(os.environ)
env['PATH'] = str(args.fastbrew.resolve().parent)+':'+env['PATH']
env['BREW_BENCHMARK_WRAPPER'] = str(args.wrapper.resolve())
report = {
    'timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'method': 'Actual default prefix and unmodified buu alias. Serial, randomized paired runs. Network metadata checks, installed package scan, normal cleanup/dependency checks and real Fisher updates included. No dry run, no disabled download or cleanup.',
    'command': 'brew update && brew upgrade -y && fisher update',
    'limitation': 'A repeat with no outdated packages measures the complete no-op update workflow; it does not measure downloading and installing new package versions.',
    'runs': [],
}


def inventory():
    result = {'formulae': {}, 'casks': {}}
    for rack in sorted((PREFIX/'Cellar').iterdir()):
        if rack.is_dir():
            result['formulae'][rack.name] = sorted(k.name for k in rack.iterdir() if (k/'INSTALL_RECEIPT.json').exists())
    for rack in sorted((PREFIX/'Caskroom').iterdir()):
        if rack.is_dir():
            result['casks'][rack.name] = sorted(k.name for k in rack.iterdir() if k.is_dir() and not k.name.startswith('.'))
    return result


def outdated():
    result = subprocess.run([str(PREFIX/'bin/brew'), 'outdated', '--json=v2'], env=dict(env, HOMEBREW_NO_AUTO_UPDATE='1'), text=True, capture_output=True, check=True)
    return json.loads(result.stdout)


def save():
    (OUTPUT/'result.json').write_text(json.dumps(report, indent=2)+'\n')


rng = random.Random(20261014)
for repetition in range(args.runs):
    order = ['homebrew', 'queries']
    rng.shuffle(order)
    for backend in order:
        row = {'backend': backend, 'repetition': repetition+1, 'before_inventory': inventory(), 'before_outdated': outdated()}
        command = 'buu' if backend == 'homebrew' else 'source "$BREW_BENCHMARK_WRAPPER"; buu'
        profile = OUTPUT/f'{repetition+1}-{backend}.profile'
        start = time.perf_counter()
        process = subprocess.run([str(PREFIX/'bin/fish'), '--profile', str(profile), '-c', command], env=env, text=True, capture_output=True)
        row.update(seconds=time.perf_counter()-start, returncode=process.returncode)
        (OUTPUT/f'{repetition+1}-{backend}.log').write_text(process.stdout+'\n'+process.stderr)
        row['after_inventory'] = inventory()
        row['after_outdated'] = outdated()
        row['native_fastbrew_calls_in_profile'] = sum('command fastbrew' in line for line in profile.read_text().splitlines())
        row['fisher_updated_plugins'] = [line for line in process.stdout.splitlines() if 'Updated ' in line and 'plugin' in line]
        row['network_errors'] = [line for line in (process.stdout+process.stderr).splitlines() if any(s in line.lower() for s in ['http 403', 'host unavailable', 'rate limit exceeded', 'failed to download'])]
        row['package_versions_unchanged'] = row['before_inventory'] == row['after_inventory']
        report['runs'].append(row)
        save()
        print(f'{backend} #{repetition+1}: {row["seconds"]:.3f}s, exit={process.returncode}, changed={not row["package_versions_unchanged"]}', flush=True)
        if process.returncode:
            raise SystemExit(process.returncode)
valid = all(r['returncode'] == 0 and not r['network_errors'] for r in report['runs'])
report['all_successful'] = valid
report['median_seconds'] = {backend: statistics.median(r['seconds'] for r in report['runs'] if r['backend'] == backend) for backend in ['homebrew', 'queries']}
if valid and all(r['package_versions_unchanged'] and not r['before_outdated']['formulae'] and not r['before_outdated']['casks'] for r in report['runs']):
    report['scenario'] = 'complete buu with all installed packages already current'
    baseline, candidate = (report['median_seconds'][b] for b in ['homebrew', 'queries'])
    report['observed_percent_time_saved'] = (1-candidate/baseline)*100
    report['causal_fastbrew_savings'] = 'No native fastbrew update/install/upgrade work is routed by the query-only wrapper; paired timing variation cannot be attributed to fastbrew acceleration.'
else:
    report['scenario'] = 'package state or network outcome changed; no paired speedup claimed'
save()
