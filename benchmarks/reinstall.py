#!/usr/bin/env python3
import argparse,datetime,json,os,pathlib,random,statistics,subprocess,time
parser=argparse.ArgumentParser(description='Benchmark same-version reinstalls of fzf, uv and tokei in the live Homebrew prefix; original kegs are backed up first.')
parser.add_argument('--fastbrew',required=True,type=pathlib.Path)
parser.add_argument('--cache',required=True,type=pathlib.Path)
parser.add_argument('--output',required=True,type=pathlib.Path)
parser.add_argument('--backup-dir',required=True,type=pathlib.Path)
parser.add_argument('--brew-prefix',default='/opt/homebrew',type=pathlib.Path)
args=parser.parse_args()
ROOT=args.output.resolve().parent
ROOT.mkdir(parents=True,exist_ok=True)
PREFIX=args.brew_prefix.resolve()
if args.backup_dir.resolve().is_relative_to(PREFIX):
 parser.error('--backup-dir must be outside the live Homebrew prefix')
PACKAGES=['fzf','uv','tokei']
TOOLS={'brew':PREFIX/'bin/brew','fastbrew':args.fastbrew.resolve()}
BACKUPS=args.backup_dir.resolve()
BACKUPS.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,HOMEBREW_CACHE=str(args.cache.resolve()),HOMEBREW_NO_AUTO_UPDATE='1',HOMEBREW_NO_ANALYTICS='1',HOMEBREW_NO_ENV_HINTS='1',HOMEBREW_NO_INSTALL_CLEANUP='1',HOMEBREW_NO_AUTOREMOVE='1',HOMEBREW_API_AUTO_UPDATE_SECS='864000')
for key in ['FASTBREW_REQUIRE_SANDBOX','FASTBREW_NO_DELEGATE']:
 env.pop(key,None)
output=args.output.resolve()
report={'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'prefix':str(PREFIX),'runs':5,'warmup_runs':1,'method':'Same-version reinstalls in the real default /opt/homebrew prefix. Shared warmed bottle cache; normal post-install and dependency checks. No automatic metadata updates or cleanup. Original kegs cloned to temporary backup before changes.','scenarios':[]}
before={}
for package in PACKAGES:
 kegs=list((PREFIX/'Cellar'/package).iterdir())
 if len(kegs)!=1:raise RuntimeError('Expected exactly one installed keg for '+package)
 receipt=json.loads((kegs[0]/'INSTALL_RECEIPT.json').read_text())
 version=kegs[0].name
 before[package]=(version,receipt['installed_on_request'])
 backup=BACKUPS/package
 if not backup.exists():subprocess.run(['/bin/cp','-cR',str(kegs[0]),str(backup)],check=True)
 for client in TOOLS:
  result=subprocess.run([str(TOOLS[client]),'fetch',package],env=env,text=True,capture_output=True,timeout=120)
  if result.returncode:raise RuntimeError('Could not warm bottle cache: '+result.stderr)
 print('Prepared backup and warm cache for '+package,flush=True)
rng=random.Random(20261014)
for package in PACKAGES:
 row={'package':package,'clients':{client:[] for client in TOOLS}}
 for iteration in range(6):
  order=list(TOOLS)
  rng.shuffle(order)
  for client in order:
   command=[str(TOOLS[client]),'reinstall',package]
   if client=='brew':command.append('--yes')
   start=time.perf_counter()
   result=subprocess.run(command,env=env,text=True,capture_output=True,timeout=180)
   elapsed=(time.perf_counter()-start)*1000
   (ROOT/f'live-{package}-{iteration}-{client}.log').write_text(result.stdout+'\n'+result.stderr)
   if result.returncode:raise RuntimeError(f'{client} reinstall {package} failed: {result.stderr}')
   kegs=list((PREFIX/'Cellar'/package).iterdir())
   receipt=json.loads((kegs[0]/'INSTALL_RECEIPT.json').read_text())
   if len(kegs)!=1 or (kegs[0].name,receipt['installed_on_request'])!=before[package]:raise RuntimeError('Installed version or request flag changed for '+package)
   smoke=subprocess.run([str(PREFIX/'bin'/package),'--version'],env=env,text=True,capture_output=True,timeout=30)
   if smoke.returncode:raise RuntimeError('Runtime failed for '+package+': '+smoke.stderr)
   if package=='fzf':
    smoke=subprocess.run([str(PREFIX/'bin/fzf'),'--filter=alpha'],input='alpha\nbeta\n',env=env,text=True,capture_output=True,timeout=30)
    if smoke.returncode or smoke.stdout!='alpha\n':raise RuntimeError('fzf filtering failed')
   if iteration:row['clients'][client].append(elapsed)
   print(f'live {package} {client} #{iteration}: {elapsed:.0f} ms',flush=True)
 row['median_ms']={client:statistics.median(values) for client,values in row['clients'].items()}
 row['timing_ratio']=row['median_ms']['brew']/row['median_ms']['fastbrew']
 row['verified_version']=before[package][0]
 report['scenarios'].append(row)
 output.write_text(json.dumps(report,indent=2)+'\n')
 print(f'live {package}: {row["timing_ratio"]:.2f}x',flush=True)
