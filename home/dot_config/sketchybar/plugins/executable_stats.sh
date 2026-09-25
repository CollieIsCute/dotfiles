#!/bin/sh
set -eu
export LC_ALL=C

# The first iostat sample is since boot; the second measures the last second.
cpu=$(iostat -c 2 -w 1 -n 0 | awk '
    NF == 6 && $3 ~ /^[0-9]+$/ { idle = $3; samples++ }
    END {
        if (samples != 2 || idle < 0 || idle > 100) exit 1
        printf "%.4f", (100 - idle) / 100
    }
')

# Match Stats memory usage: exclude purgeable and file-backed cache.
ram=$(vm_stat | awk -v total="$(sysctl -n hw.memsize)" '
    /page size of/ { page_size = $8 }
    /^Pages (active|inactive|speculative|wired down|occupied by compressor):/ {
        used += $NF; fields++
    }
    /^Pages purgeable:|^File-backed pages:/ { used -= $NF; fields++ }
    END {
        ratio = total > 0 ? used * page_size / total : -1
        if (fields != 7 || page_size <= 0 || ratio < 0 || ratio > 1) exit 1
        printf "%.0f%%", ratio * 100
    }
')

sketchybar --push stats.cpu "$cpu" --set stats.ram label="$ram"

# Noctalia gpu_vram is unavailable on unified-memory GPUs; keep its label as —.
gpu=$(ioreg -r -c IOAccelerator -a | plutil -extract 0.PerformanceStatistics json -o - - 2>/dev/null |
    jq -er '
        ."Device Utilization %" | select(type == "number" and . >= 0 and . <= 100) / 100
    ') || gpu=''
if test -n "$gpu"; then
    sketchybar --push stats.gpu "$gpu" --set stats.gpu drawing=on
else
    sketchybar --set stats.gpu drawing=off
fi

temp='—'
smc=${STATS_SMC:-/Applications/Stats.app/Contents/Resources/smc}
# M2 CPU sensor keys from Stats Modules/Sensors/values.swift.
case "$(sysctl -n machdep.cpu.brand_string)" in
    'Apple M2'*)
        if test -x "$smc"; then
            temp=$("$smc" list -t | awk '
                /^\[Tp(1[htpl]|0[159DXbfj])\]/ && $2 > 0 && $2 < 128 { sum += $2; n++ }
                END { if (n) printf "%.0f°C", sum / n; else print "—" }
            ')
        fi
        ;;
esac
sketchybar --set stats.temp label="$temp"

battery=$(pmset -g batt | awk 'match($0, /[0-9]+%/) { print substr($0, RSTART, RLENGTH); exit }')
if test -n "$battery"; then
    sketchybar --set stats.battery drawing=on label="$battery"
else
    sketchybar --set stats.battery drawing=off
fi
