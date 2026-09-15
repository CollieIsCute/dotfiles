#!/bin/sh

# Apps may start after the bar or change their enabled modules at runtime.
items=$("$HOME/.local/bin/sb-status-items" list) || exit 0
# SketchyBar query does not escape quotes in label values.
current=$(printf '%s\n' "$items" | /usr/bin/jq -r '[.[] | [.bundle, .window]] | sort | @base64') || exit 0
previous=$(sketchybar --query "$NAME" | /usr/bin/jq -er '.label.value') || exit 0
test "$current" = "$previous" || sketchybar --reload
