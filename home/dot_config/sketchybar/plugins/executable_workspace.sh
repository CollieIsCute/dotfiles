#!/bin/sh
set -eu

CONFIG_DIR=${CONFIG_DIR:-"$HOME/.config/sketchybar"}
ON_SURFACE=0xfff2f0f4
ON_PRIMARY=0xff381e72
test -r "$CONFIG_DIR/colors.sh" && . "$CONFIG_DIR/colors.sh"

# One batch updates all slots. Events handle focus/create/close; the 2 s refresh
# also covers moving a background window without a native window event.
# https://nikitabobko.github.io/AeroSpace/commands#list-workspaces
mkdir -p "$HOME/.cache/sketchybar"
exec 9>"$HOME/.cache/sketchybar/workspaces.lock"
lockf -s -t 0 9 || exit 0
focused=$(aerospace list-workspaces --focused) || exit 1
occupied=$(aerospace list-workspaces --monitor all --empty no) || exit 1

set --
for sid in 1 2 3 4 5 6 7 8 9 magic; do
    visible=off
    highlight=off
    color=$ON_SURFACE
    if test "$sid" = "$focused"; then
        visible=on
        highlight=on
        color=$ON_PRIMARY
    elif printf '%s\n' "$occupied" | grep -Fxq "$sid"; then
        visible=on
    fi
    set -- "$@" --set "space.$sid" "drawing=$visible" \
        "background.drawing=$highlight" "icon.color=$color"
done
sketchybar "$@"
