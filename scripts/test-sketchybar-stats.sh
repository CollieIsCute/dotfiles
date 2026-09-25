#!/bin/sh
# Run from the repository root: sh scripts/test-sketchybar-stats.sh
set -eu
plugin=home/dot_config/sketchybar/plugins/executable_stats.sh

iostat() {
    printf '%s\n' '      cpu    load average' ' us sy id   1m   5m   15m'
    printf '%s\n' '  1  1 98  2.25 2.61 2.69' ' 13 25 62  2.25 2.61 2.69'
}
sysctl() { printf '%s\n' 16384000; }
vm_stat() {
    cat <<'EOF'
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages active: 200.
Pages inactive: 200.
Pages speculative: 10.
Pages wired down: 100.
Pages purgeable: 20.
File-backed pages: 90.
Pages stored in compressor: 500.
Pages occupied by compressor: 100.
EOF
}
sketchybar() { printf '%s\n' "$*"; }

result=$(. "$plugin")
test "$result" = '--push stats.cpu 0.3800 --set stats.cpu label=38% --push stats.ram 0.5000 --set stats.ram label=50%'

# A missing second CPU sample must not push a misleading value.
iostat() { printf '%s\n' '  1  1 98  2.25 2.61 2.69'; }
set +e
result=$(. "$plugin")
status=$?
set -e
test "$status" -ne 0
test -z "$result"

# Missing memory counters must not turn into a zero-usage graph.
iostat() { printf '%s\n' '  0  0 100  2.25 2.61 2.69' '  0  0 100  2.25 2.61 2.69'; }
vm_stat() { printf '%s\n' 'Mach Virtual Memory Statistics: (page size of 16384 bytes)'; }
set +e
result=$(. "$plugin")
status=$?
set -e
test "$status" -ne 0
test -z "$result"
printf '%s\n' 'SketchyBar stats checks passed.'
