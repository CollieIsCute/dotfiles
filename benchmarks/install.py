#!/usr/bin/env python3
"""Time verified CLI bottle installs in disposable Homebrew prefixes."""
import argparse
import datetime
import json
import os
import pathlib
import random
import shutil
import statistics
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', required=True, type=pathlib.Path)
parser.add_argument('--fastbrew', required=True, type=pathlib.Path)
parser.add_argument('--api-cache', required=True, type=pathlib.Path)
parser.add_argument('--output', required=True, type=pathlib.Path)
parser.add_argument('--brew-prefix', default='/opt/homebrew', type=pathlib.Path)
args = parser.parse_args()
WORK = args.work_dir.resolve()
BREW_SOURCE = args.brew_prefix.resolve()
FASTBREW = args.fastbrew.resolve()
API_SOURCE = args.api_cache.resolve()
PACKAGES = ['fzf', 'uv', 'tokei']
if WORK == BREW_SOURCE or WORK.is_relative_to(BREW_SOURCE) or BREW_SOURCE.is_relative_to(WORK):
    parser.error('--work-dir must be separate from the live Homebrew prefix')
if WORK.exists() and any(WORK.iterdir()):
    parser.error('--work-dir must be empty; create a dedicated temporary directory')
WORK.mkdir(parents=True, exist_ok=True)
for folder in ['tmp','logs','config']:
    (WORK/folder).mkdir(exist_ok=True)
TEMPLATE = WORK/'template'
TEMPLATE.mkdir(exist_ok=True)
if not (TEMPLATE/'Library').exists():
    subprocess.run(['/bin/cp', '-cR', str(BREW_SOURCE/'Library'), str(TEMPLATE/'Library')], check=True)
    subprocess.run(['/bin/cp', '-cR', str(BREW_SOURCE/'.git'), str(TEMPLATE/'.git')], check=True)
    (TEMPLATE/'bin').mkdir()
    shutil.copy2(BREW_SOURCE/'bin/brew', TEMPLATE/'bin/brew')


def replace_prefix(prefix):
    if not prefix.resolve().is_relative_to(WORK.resolve()):
        raise RuntimeError('Refusing a prefix outside the benchmark directory')
    if prefix.exists():
        shutil.rmtree(prefix)
    subprocess.run(['/bin/cp', '-cR', str(TEMPLATE), str(prefix)], check=True)
    for subdir in ['Cellar','Caskroom','opt','etc','var/homebrew/linked','var/homebrew/locks','sbin','share','lib','include','Frameworks']:
        (prefix/subdir).mkdir(parents=True, exist_ok=True)


def environment(prefix, cache):
    env = dict(os.environ)
    env.update(HOMEBREW_PREFIX=str(prefix), HOMEBREW_CELLAR=str(prefix/'Cellar'),
               HOMEBREW_REPOSITORY=str(prefix), HOMEBREW_LIBRARY=str(prefix/'Library'),
               HOMEBREW_CACHE=str(cache), HOMEBREW_LOGS=str(WORK/'logs'),
               HOMEBREW_TEMP=str(WORK/'tmp'), HOMEBREW_USER_CONFIG_HOME=str(WORK/'config'),
               HOMEBREW_NO_AUTO_UPDATE='1', HOMEBREW_NO_ANALYTICS='1',
               HOMEBREW_NO_ENV_HINTS='1', HOMEBREW_NO_COLOR='1', HOMEBREW_NO_EMOJI='1',
               HOMEBREW_NO_INSTALL_CLEANUP='1', HOMEBREW_NO_AUTOREMOVE='1',
               HOMEBREW_API_AUTO_UPDATE_SECS='864000',
               FASTBREW_REQUIRE_SANDBOX='1', FASTBREW_NO_DELEGATE='1',
               PATH=str(prefix/'bin')+':'+str(prefix/'sbin')+':'+os.environ['PATH'])
    for key in ['HOMEBREW_BREW_FILE','HOMEBREW_PATH','FASTBREW_BREW']:
        env.pop(key, None)
    return env


report = {'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'packages':PACKAGES, 'cold_runs':2, 'warm_runs':5,
          'method':'Fresh isolated prefix for every install. Cold = empty bottle cache, warm metadata. Warm = cached bottles, warm metadata. Normal post-install steps enabled. Native fastbrew only; delegation forbidden.',
          'note':'Standalone CLI bottles only; does not estimate GUI, LLVM, Node or full-machine upgrade performance.',
          'scenarios':[]}
output = args.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
rng = random.Random(20261014)
for package in PACKAGES:
    measurements = {client:{'cold':[],'warm':[]} for client in ['brew','fastbrew']}
    for client in ['brew','fastbrew']:
        cache = WORK/(client+'-'+package+'-cache')
        cache.mkdir(exist_ok=True)
        if not (cache/'api').exists():
            subprocess.run(['/bin/cp','-cR',str(API_SOURCE),str(cache/'api')],check=True)
        prefix = WORK/(client+'-prefix')
        replace_prefix(prefix)
        env = environment(prefix, cache)
        executable = prefix/'bin/brew' if client=='brew' else FASTBREW
        prime = subprocess.run([str(executable),'info',package],env=env,text=True,capture_output=True,timeout=120)
        if prime.returncode:
            raise RuntimeError(f'{client} metadata warmup failed: {prime.stderr}')
    for phase,count in [('cold',2),('warm',5)]:
        for repetition in range(count):
            order = ['brew','fastbrew']
            rng.shuffle(order)
            for client in order:
                cache = WORK/(client+'-'+package+'-cache')
                if phase=='cold':
                    for child in cache.iterdir():
                        if child.name not in {'api','fastbrew'}:
                            if child.is_dir():shutil.rmtree(child)
                            else:child.unlink()
                prefix = WORK/(client+'-prefix')
                replace_prefix(prefix)
                env = environment(prefix,cache)
                executable = prefix/'bin/brew' if client=='brew' else FASTBREW
                command = [str(executable),'install',package]
                if client=='brew':command.append('--yes')
                start = time.perf_counter()
                result = subprocess.run(command,env=env,text=True,capture_output=True,timeout=240)
                elapsed = (time.perf_counter()-start)*1000
                row={'duration_ms':elapsed,'returncode':result.returncode,'stderr':result.stderr[-2200:]}
                log=WORK/f'{package}.{phase}.{repetition}.{client}.log'
                log.write_text(result.stdout+'\n'+result.stderr)
                if result.returncode==0:
                    receipts=list((prefix/'Cellar'/package).glob('*/INSTALL_RECEIPT.json'))
                    if len(receipts)!=1:raise RuntimeError(f'{client} {package} did not create exactly one receipt')
                    version=subprocess.run([str(prefix/'bin'/package),'--version'],env=env,text=True,capture_output=True,timeout=30)
                    if version.returncode:raise RuntimeError(f'{client} {package} runtime failed: {version.stderr}')
                    row['runtime_version']=version.stdout.strip()
                    row['installed_version']=json.loads(receipts[0].read_text())['source']['versions']['stable']
                    if package=='fzf':
                        smoke=subprocess.run([str(prefix/'bin/fzf'),'--filter=alpha'],input='alpha\nbeta\n',env=env,text=True,capture_output=True,timeout=30)
                        if smoke.returncode or smoke.stdout!='alpha\n':raise RuntimeError('fzf filtering failed')
                    elif package=='tokei':
                        fixture=WORK/'sample.py'
                        fixture.write_text('print("hello")\n')
                        smoke=subprocess.run([str(prefix/'bin/tokei'),str(fixture),'--output','json'],env=env,text=True,capture_output=True,timeout=30)
                        if smoke.returncode or json.loads(smoke.stdout)['Python']['code']!=1:raise RuntimeError('tokei counting failed')
                measurements[client][phase].append(row)
                print(f'{package} {phase} #{repetition+1} {client}: {elapsed:.0f} ms, exit={result.returncode}',flush=True)
    entry={'package':package,'clients':measurements}
    for phase in ['cold','warm']:
        if all(r['returncode']==0 for c in measurements.values() for r in c[phase]):
            medians={client:statistics.median(r['duration_ms'] for r in values[phase]) for client,values in measurements.items()}
            entry[phase]={'median_ms':medians,'timing_ratio':medians['brew']/medians['fastbrew']}
            print(f'{package} {phase}: {entry[phase]}',flush=True)
    report['scenarios'].append(entry)
    output.write_text(json.dumps(report,indent=2)+'\n')
