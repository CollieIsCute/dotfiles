#!/bin/sh
# Run from the repository root: sh scripts/test-sketchybar-stats.sh
set -eu
plugin=home/dot_config/sketchybar/plugins/executable_stats.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
STATS_SMC="$scratch/smc"
cat >"$STATS_SMC" <<'EOF'
#!/bin/sh
printf '%s\n' '[Tp01] 40' '[Tp05] 60' '[Tp09] 0' '[Tg0f] 90'
EOF
chmod +x "$STATS_SMC"

iostat() {
    printf '%s\n' '      cpu    load average' ' us sy id   1m   5m   15m'
    printf '%s\n' '  1  1 98  2.25 2.61 2.69' ' 13 25 62  2.25 2.61 2.69'
}
sysctl() {
    case "$2" in
        hw.memsize) printf '%s\n' 16384000 ;;
        machdep.cpu.brand_string) printf '%s\n' 'Apple M2' ;;
    esac
}
ioreg() { printf '%s\n' '{"Device Utilization %":25,"In use system memory":1610612736}'; }
plutil() { cat; }
pmset() { printf '%s\n' '-InternalBattery-0 (id=1) 43%; discharging; 4:03 remaining present: true'; }
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
test "$result" = '--push stats.cpu 0.3800 --set stats.ram label=50%
--push stats.gpu 0.25 --set stats.gpu drawing=on --set stats.vram drawing=on label=1.5G
--set stats.temp label=50°C
--set stats.battery drawing=on label=43%'

# Optional sensors do not suppress the CPU/RAM update or invent zero readings.
ioreg() { printf '%s\n' '{}'; }
pmset() { :; }
STATS_SMC="$scratch/missing"
result=$(. "$plugin")
test "$result" = '--push stats.cpu 0.3800 --set stats.ram label=50%
--set stats.gpu drawing=off --set stats.vram drawing=off
--set stats.temp label=—
--set stats.battery drawing=off'

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

plugin=home/dot_config/sketchybar/plugins/executable_network.sh
route() { printf '%s\n' '  interface: en0'; }
sleep() { :; }
net_calls=0
down=1500000 up=250000
netstat() {
    test "$*" = '-ibn -I en0' || return 1
    printf 'en0 1500 <Link#11> aa:bb:cc:dd:ee:ff 100 0 %s 50 0 %s 0\n' \
        "$((1000000 + net_calls * down))" "$((1000000 + net_calls * up))"
    printf '%s\n' 'en0 1500 10.0.0/24 10.0.0.1 100 0 9999999 50 0 9999999 0'
    net_calls=$((net_calls + 1))
}
result=$(. "$plugin")
test "$result" = '--set stats.network label=↓1.5MB/s ↑250.0KB/s'

# Large transfers and idle links retain meaningful units.
down=2000000000 up=0
result=$(. "$plugin")
test "$result" = '--set stats.network label=↓2.0GB/s ↑0B/s'

# An offline machine clears the old rate without polling an arbitrary interface.
route() { return 1; }
netstat() { return 1; }
result=$(. "$plugin")
test "$result" = '--set stats.network label=↓— ↑—'
printf '%s\n' 'SketchyBar stats checks passed.'
