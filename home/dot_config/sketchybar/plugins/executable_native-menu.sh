#!/bin/sh

# --update also runs item scripts; never open menus during startup or reload.
case "${SENDER:-}" in
    mouse.clicked) ;;
    *) exit 0 ;;
esac

case "${NAME:-}" in
    codexbar)
        # Opening the app does not open its status menu. CodexBar 0.60 keeps a
        # zero-size menu when closed, so existence alone is not visibility.
        osascript <<'APPLESCRIPT'
tell application "System Events" to tell process "CodexBar"
    tell menu bar item 1 of menu bar 2
        if not (exists menu 1) or (size of menu 1 is {0, 0}) then click
    end tell
end tell
APPLESCRIPT
        ;;
esac
