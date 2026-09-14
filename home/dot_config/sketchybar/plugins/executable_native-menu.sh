#!/bin/sh

case "${NAME:-}" in
    stats.*) popup=$NAME ;;
    meter.codex|meter.claude) popup=codexbar ;;
    *) exit 0 ;;
esac

# Forced/routine updates do nothing; menus only open on an actual click.
case "${SENDER:-}:$popup:${BUTTON:-left}" in
    mouse.entered:*) sketchybar --set "$popup" popup.drawing=on ;;
    mouse.exited:*|mouse.clicked:stats.*:*) sketchybar --set "$popup" popup.drawing=off ;;
    mouse.clicked:codexbar:left)
        sketchybar --set codexbar popup.drawing=off
        exec "$HOME/.local/bin/sb-status-items" click com.steipete.codexbar "codexbar-${NAME#meter.}"
        ;;
    mouse.clicked:codexbar:right)
        exec "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/codexbar.sh"
        ;;
esac
