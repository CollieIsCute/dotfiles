#!/bin/sh

case "${NAME:-}" in
    stats.*)
        case "${SENDER:-}" in
            mouse.entered) sketchybar --set "$NAME" popup.drawing=on ;;
            mouse.exited|mouse.clicked) sketchybar --set "$NAME" popup.drawing=off ;;
        esac
        exit 0
        ;;
esac

# --update also runs item scripts; never open menus during startup or reload.
case "${SENDER:-}" in
    mouse.clicked) ;;
    *) exit 0 ;;
esac

case "${NAME:-}" in
    meter.codex|meter.claude)
        exec "$HOME/.local/bin/sb-status-items" click com.steipete.codexbar "codexbar-${NAME#meter.}"
        ;;
esac
