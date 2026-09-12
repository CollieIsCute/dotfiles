#!/bin/sh
set -eu

sketchybar --set "$NAME" label="$(date '+%B %d %H:%M:%S')"
