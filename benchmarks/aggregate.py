#!/usr/bin/env python3
"""Aggregate complete-workflow artifacts, rejecting unequal package states."""
import argparse
import json
import pathlib
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--artifacts', required=True, type=pathlib.Path)
parser.add_argument('--output', required=True, type=pathlib.Path)
parser.add_argument('--image-version', help='Compare only one GitHub runner image rollout.')
args = parser.parse_args()
groups = {}
for path in sorted(args.artifacts.glob('**/result.json')):
    row = json.loads(path.read_text())
    if args.image_version and row.get('image_version') != args.image_version:
        continue
    backend = row['backend']
    if row.get('clean_prefix'):
        backend += '-clean'
    if backend == 'native-experiment':
        if 'native_preunlink' in row:
            backend = 'native-with-link-migration'
        else:
            backend = 'native-direct' if 'node' in row.get('native_core_formulae', []) else 'native-with-node-fallback'
    groups.setdefault(backend, []).append(row)
report = {
    'image_version_filter': args.image_version,
    'method': 'Medians of complete cold-cache first deployments and real buu on separate macOS CI runners. Total time saved = 100 * (1 - candidate_seconds / Homebrew_seconds).',
    'limitations': ['Two repetitions per workflow; real network and upstream metadata are variable.', 'Runner comes with Homebrew and other packages preinstalled.', 'Query-only PR still uses Homebrew for initial install and every buu update/upgrade; observed timing variation is not a native fastbrew speedup.'],
    'backends': {},
    'comparisons': {},
}
for backend, rows in groups.items():
    complete = [r for r in rows if r.get('complete')]
    summary = {'attempts': len(rows), 'completed': len(complete), 'failures': [{'stage': r.get('failure', 'verification'), 'run_url': r['run_url'], 'elapsed_seconds': sum(s['seconds'] for s in r['steps'])} for r in rows if not r.get('complete')]}
    if complete:
        for phase in ['first_install', 'buu', 'combined']:
            values = [r['first_install_seconds']+r['buu_seconds'] if phase == 'combined' else r[phase+'_seconds'] for r in complete]
            summary[phase] = {'median_seconds': statistics.median(values), 'samples_seconds': values, 'min_seconds': min(values), 'max_seconds': max(values)}
        summary['outdated_before_buu'] = [{'formulae': len(r['before_buu_outdated']['formulae']), 'casks': len(r['before_buu_outdated']['casks'])} for r in complete]
        summary['outdated_after_buu'] = [{'formulae': len(r['after_buu_outdated']['formulae']), 'casks': len(r['after_buu_outdated']['casks'])} for r in complete]
    report['backends'][backend] = summary


def same_state(rows, field):
    values = [json.dumps(r[field], sort_keys=True) for r in rows]
    return len(set(values)) == 1


baseline_backend = 'homebrew-clean' if 'homebrew-clean' in groups else 'homebrew'
baseline = [r for r in groups.get(baseline_backend, []) if r.get('complete')]
for backend, rows in groups.items():
    if backend == baseline_backend:
        continue
    candidates = [r for r in rows if r.get('complete')]
    if not baseline or not candidates:
        report['comparisons'][backend] = {'eligible': False, 'reason': 'No complete comparable workflow; failed or partial durations cannot be used as a speedup.'}
        continue
    together = baseline+candidates
    checks = {
        'all_attempts_completed': len(candidates) == len(rows),
        'same_runner_image': same_state(together, 'image_version'),
        'same_initial_inventory': same_state(together, 'initial_inventory'),
        'same_inventory_before_buu': same_state(together, 'before_buu_inventory'),
        'same_final_inventory': same_state(together, 'after_buu_inventory'),
        'all_packages_current_after_buu': all(not r['after_buu_outdated']['formulae'] and not r['after_buu_outdated']['casks'] for r in together),
    }
    comparison = {'checks': checks}
    for phase in ['first_install', 'buu', 'combined']:
        eligible = checks['all_attempts_completed'] and checks['same_runner_image']
        if phase == 'first_install':
            eligible &= checks['same_initial_inventory'] and checks['same_inventory_before_buu']
        elif phase == 'buu':
            eligible &= checks['same_inventory_before_buu'] and checks['same_final_inventory'] and checks['all_packages_current_after_buu']
        else:
            eligible &= checks['same_initial_inventory'] and checks['same_final_inventory'] and checks['all_packages_current_after_buu']
        brew = report['backends'][baseline_backend][phase]['median_seconds']
        candidate = report['backends'][backend][phase]['median_seconds']
        comparison[phase] = {'eligible': bool(eligible), 'observed_percent_time_saved': 100*(1-candidate/brew), 'seconds_saved': brew-candidate}
        if backend == 'queries':
            comparison[phase]['causal_native_fastbrew_time_saved_percent'] = 0
    report['comparisons'][backend] = comparison
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
