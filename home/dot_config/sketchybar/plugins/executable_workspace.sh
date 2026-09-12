#!/bin/sh
set -eu

CONFIG_DIR=${CONFIG_DIR:-"$HOME/.config/sketchybar"}
ON_SURFACE=0xfff2f0f4
ON_PRIMARY=0xff381e72
test -r "$CONFIG_DIR/colors.sh" && . "$CONFIG_DIR/colors.sh"

sid=${NAME#space.}
if test "${FOCUSED_WORKSPACE:-}" = "$sid"; then
    sketchybar --set "$NAME" background.drawing=on icon.color="$ON_PRIMARY"
else
    sketchybar --set "$NAME" background.drawing=off icon.color="$ON_SURFACE"
fi
