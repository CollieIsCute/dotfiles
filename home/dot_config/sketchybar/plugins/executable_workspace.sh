#!/bin/sh
set -efu

# One batch updates all slots. Events handle focus/create/close; the 2 s refresh
# also covers moving a background window without a native window event.
# https://nikitabobko.github.io/AeroSpace/commands#list-workspaces
mkdir -p "$HOME/.cache/sketchybar"
exec 9>"$HOME/.cache/sketchybar/workspaces.lock"
lockf -s -t 0 9 || exit 0
focused=$(aerospace list-workspaces --focused) || exit 1
occupied=$(aerospace list-workspaces --monitor all --empty no) || exit 1

set -- --set '/^space\./' drawing=off background.drawing=off icon.highlight=off
IFS='
'
for sid in $occupied "$focused"; do
  case "$sid" in [1-9] | magic) ;; *) continue ;; esac
  set -- "$@" --set "space.$sid" drawing=on
  if test "$sid" = "$focused"; then
    set -- "$@" background.drawing=on icon.highlight=on
  fi
done
sketchybar "$@"
