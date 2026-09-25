#!/bin/sh
set -eu
export LC_ALL=C

# The first iostat sample is since boot; the second measures the last second.
cpu=$(iostat -c 2 -w 1 -n 0 | awk '
    NF == 6 && $3 ~ /^[0-9]+$/ { idle = $3; samples++ }
    END {
        if (samples != 2 || idle < 0 || idle > 100) exit 1
        printf "%.4f %.0f%%", (100 - idle) / 100, 100 - idle
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
        printf "%.4f %.0f%%", ratio, ratio * 100
    }
')

# Both samplers return a normalized graph value and a percentage label.
set -- $cpu $ram
sketchybar --push stats.cpu "$1" --set stats.cpu label="$2" \
    --push stats.ram "$3" --set stats.ram label="$4"
