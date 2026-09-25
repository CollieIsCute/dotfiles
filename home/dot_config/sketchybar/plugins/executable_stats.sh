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
        printf "%.4f %.0f%%", ratio, ratio * 100
    }
')

# RAM also returns a percentage label; CPU is graph-only.
set -- $ram
sketchybar --push stats.cpu "$cpu" \
    --push stats.ram "$1" --set stats.ram label="$2"
