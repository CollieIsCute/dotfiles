#!/bin/sh
set -eu
icon=$("$HOME/.local/bin/sb-status-items" input-source)
sketchybar --set "$NAME" icon="$icon"
