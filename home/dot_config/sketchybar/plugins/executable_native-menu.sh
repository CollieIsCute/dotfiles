#!/bin/sh

# --update also runs item scripts; never open menus during startup or reload.
case "${SENDER:-}" in
    mouse.entered|mouse.clicked) ;;
    *) exit 0 ;;
esac

case "${NAME:-}" in
    codexbar)
        # Opening the app does not open its status menu. Avoid toggling it shut
        # when a click follows hover. CodexBar 0.60 keeps a zero-size menu when
        # closed, so existence alone does not mean it is visible.
        osascript <<'APPLESCRIPT'
tell application "System Events" to tell process "CodexBar"
    tell menu bar item 1 of menu bar 2
        if not (exists menu 1) or (size of menu 1 is {0, 0}) then click
    end tell
end tell
APPLESCRIPT
        ;;
    control_center)
        osascript <<'APPLESCRIPT'
tell application "System Events" to tell process "ControlCenter"
    repeat with statusItem in menu bar items of menu bar 1
        set itemID to missing value
        try
            set itemID to value of attribute "AXIdentifier" of statusItem
        end try
        if itemID is "com.apple.menuextra.controlcenter" then
            click statusItem
            return
        end if
    end repeat
    error "Control Center status item was not found."
end tell
APPLESCRIPT
        ;;
esac
