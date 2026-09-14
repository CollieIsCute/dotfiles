#!/bin/sh
set -eu

label=$(date '+%m %d %H:%M:%S' | awk '{
    split("壹 貳 參 肆 伍 陸 柒 捌 玖 拾 拾壹 拾貳", months)
    printf "%s月 %d %s", months[$1 + 0], $2, $3
}')
sketchybar --set "$NAME" label="$label"
