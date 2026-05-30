#!/bin/bash

# Power management menu using wofi
choice=$(echo -e "🔒 Lock\n🏠 Logout\n🔄 Reboot\n⏻ Shutdown" | wofi --dmenu --prompt "Power Menu" --width 200 --height 160)

case $choice in
    "🔒 Lock")
        hyprlock
        ;;
    "🏠 Logout")
        hyprctl dispatch 'hl.dsp.exit()'
        ;;
    "🔄 Reboot")
        systemctl reboot
        ;;
    "⏻ Shutdown")
        systemctl poweroff
        ;;
esac
