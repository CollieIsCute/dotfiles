#!/bin/sh
# Run from the repository root: sh scripts/test-sketchybar-volume.sh
set -eu
plugin=home/dot_config/sketchybar/plugins/executable_volume.sh
level=63 muted=false
osascript() {
    case "$2" in
        'output volume of (get volume settings)') printf '%s\n' "$level" ;;
        'output muted of (get volume settings)') printf '%s\n' "$muted" ;;
        'set volume output muted not (output muted of (get volume settings))')
            if test "$muted" = true; then muted=false; else muted=true; fi ;;
        'set volume output volume '*)
            level=$(printf '%s\n' "$2" | awk '{ print $5 }')
            case "$2" in *'output muted false') muted=false ;; esac ;;
        *) return 1 ;;
    esac
}
sketchybar() { printf '%s\n' "$*"; }
expect_volume() {
    test "$result" = "--set volume icon=$2 label=$1% --set volume.slider slider.percentage=$1 --set volume.mute icon=$2"
}

NAME=volume SENDER=mouse.clicked
result=$(. "$plugin")
test "$result" = '--set volume popup.drawing=toggle
--set volume icon=󰕾 label=63% --set volume.slider slider.percentage=63 --set volume.mute icon=󰕾'

NAME=volume.mute
result=$(. "$plugin")
expect_volume 63 '󰖁'

NAME=volume.slider PERCENTAGE=27 muted=true
result=$(. "$plugin")
expect_volume 27 '󰕿'
PERCENTAGE=0
result=$(. "$plugin")
expect_volume 0 '󰖁'
PERCENTAGE=100
result=$(. "$plugin")
expect_volume 100 '󰕾'

PERCENTAGE='101; bad input'
set +e
result=$(. "$plugin")
exit_status=$?
set -e
test "$exit_status" -ne 0
test -z "$result"

NAME=volume SENDER=mouse.scrolled SCROLL_DELTA=1 level=99 muted=false
result=$(. "$plugin")
expect_volume 100 '󰕾'
SCROLL_DELTA=-1 level=1
result=$(. "$plugin")
expect_volume 0 '󰖁'

SENDER=volume_change INFO=45
result=$(. "$plugin")
expect_volume 45 '󰖀'
SENDER=mouse.exited.global
result=$(. "$plugin")
test "$result" = '--set volume popup.drawing=off'
printf '%s\n' 'SketchyBar volume checks passed.'
