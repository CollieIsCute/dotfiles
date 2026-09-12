#!/bin/sh
set -eu

get_volume() {
    osascript -e 'output volume of (get volume settings)' 2>/dev/null || printf '0\n'
}

case ${SENDER:-} in
    mouse.clicked)
        osascript -e 'set volume output muted not (output muted of (get volume settings))' >/dev/null
        volume=$(get_volume)
        ;;
    mouse.scrolled)
        volume=$(get_volume)
        case $volume in *[!0-9]*|'') volume=0 ;; esac
        case ${SCROLL_DELTA:-0} in
            -*) volume=$((volume - 3)) ;;
            0|'') ;;
            *) volume=$((volume + 3)) ;;
        esac
        test "$volume" -ge 0 || volume=0
        test "$volume" -le 100 || volume=100
        osascript -e "set volume output volume $volume" >/dev/null
        ;;
    volume_change)
        volume=${INFO:-0}
        ;;
    *)
        volume=$(get_volume)
        ;;
esac

muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null || printf 'false\n')
case $volume in *[!0-9]*|'') volume=0 ;; esac

if test "$muted" = true || test "$volume" -eq 0; then
    icon='󰖁'
elif test "$volume" -lt 30; then
    icon='󰕿'
elif test "$volume" -lt 60; then
    icon='󰖀'
else
    icon='󰕾'
fi

sketchybar --set "$NAME" icon="$icon" label="$volume%"
