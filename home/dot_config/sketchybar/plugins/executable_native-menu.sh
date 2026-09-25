#!/bin/sh

case "${NAME:-}" in
    meter.codex|meter.claude) popup=codexbar ;;
    *) exit 0 ;;
esac

# Forced/routine updates do nothing; menus only open on an actual click.
case "${SENDER:-}:$popup:${BUTTON:-left}" in
    mouse.entered:*) sketchybar --set "$popup" popup.drawing=on ;;
    mouse.exited:*) sketchybar --set "$popup" popup.drawing=off ;;
    mouse.clicked:codexbar:left)
        sketchybar --set codexbar popup.drawing=off
        exec "$HOME/.local/bin/sb-status-items" click com.steipete.codexbar "CodexBar.StatusItem.${NAME#meter.}"
        ;;
    mouse.clicked:codexbar:right)
        exec "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/codexbar.sh"
        ;;
esac
