#!/bin/sh
set -eu
export LC_ALL=C

interface=$({ route -n get default 2>/dev/null || route -n get -inet6 default 2>/dev/null; } |
  awk '/interface:/ { print $2; exit }')
if test -z "$interface"; then
  sketchybar --set stats.network label='↓— ↑—'
  exit 0
fi

# Finite snapshots also work when SketchyBar makes children ignore SIGPIPE.
# ponytail: approximate one-second rates; timestamp samples if finer timing is needed.
sample=$({
  netstat -ibn -I "$interface"
  sleep 1
  netstat -ibn -I "$interface"
} | awk '
    function rate(bytes) {
        if (bytes < 1000) return sprintf("%.0fB/s", bytes)
        if (bytes < 1000000) return sprintf("%.1fKB/s", bytes / 1000)
        if (bytes < 1000000000) return sprintf("%.1fMB/s", bytes / 1000000)
        return sprintf("%.1fGB/s", bytes / 1000000000)
    }
    $3 ~ /^<Link#/ {
        incoming = $(NF - 4); outgoing = $(NF - 1)
        if (++samples == 1) { before_in = incoming; before_out = outgoing; next }
        down = incoming - before_in; up = outgoing - before_out
        if (down < 0 || up < 0) exit 1
        printf "↓%s ↑%s\n", rate(down), rate(up)
    }
    END { if (samples != 2) exit 1 }
')
sketchybar --set stats.network label="$sample"
