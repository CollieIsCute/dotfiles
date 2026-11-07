#!/bin/sh

case "${NAME:-}" in
meter.codex | meter.claude) ;;
*) exit 0 ;;
esac

# Forced/routine updates do nothing; menus only open on an actual click.
case "${SENDER:-}:${BUTTON:-left}" in
mouse.entered:*) sketchybar --set codexbar popup.drawing=on ;;
mouse.exited:*) sketchybar --set codexbar popup.drawing=off ;;
mouse.clicked:left)
  sketchybar --set codexbar popup.drawing=off
  exec "$HOME/.local/bin/sb-status-items" click "${NAME#meter.}"
  ;;
mouse.clicked:right)
  exec "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/codexbar.sh"
  ;;
esac
