#!/bin/bash
set -euo pipefail

direction="${1:-}"
case "$direction" in
    left|down|up|right) ;;
    *) exit 64 ;;
esac

# ponytail: one global lock is enough for a single AeroSpace session.
lock_dir="${TMPDIR:-/tmp}/aerospace-swap-workspaces.lock"
mkdir "$lock_dir" 2>/dev/null || exit 0
cleanup() { rmdir "$lock_dir" 2>/dev/null || true; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

source_workspace="$(aerospace list-workspaces --focused)"
[[ "$source_workspace" =~ ^[1-9]$ ]] || exit 0

source_monitor="$(aerospace list-monitors --focused --format '%{monitor-id}')"
source_windows="$(aerospace list-windows --workspace "$source_workspace" --format '%{window-id}%{tab}%{window-layout}%{tab}%{window-is-fullscreen}')"

# Let AeroSpace resolve the target from the real monitor geometry.
aerospace focus-monitor "$direction" || exit 0
target_monitor="$(aerospace list-monitors --focused --format '%{monitor-id}')"
target_workspace="$(aerospace list-workspaces --focused)"
if [[ "$target_monitor" == "$source_monitor" || ! "$target_workspace" =~ ^[1-9]$ ]]; then
    aerospace workspace "$source_workspace"
    exit 0
fi

target_windows="$(aerospace list-windows --workspace "$target_workspace" --format '%{window-id}%{tab}%{window-layout}%{tab}%{window-is-fullscreen}')"
target_focused_window="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
workspace_layouts="$(aerospace list-workspaces --all --format '%{workspace}%{tab}%{workspace-root-container-layout}')"
source_layout="$(awk -F '\t' -v workspace="$source_workspace" '$1 == workspace { print $2; exit }' <<< "$workspace_layouts")"
target_layout="$(awk -F '\t' -v workspace="$target_workspace" '$1 == workspace { print $2; exit }' <<< "$workspace_layouts")"

move_windows() {
    local windows="$1" workspace="$2" window_id
    while IFS=$'\t' read -r window_id _; do
        [[ -n "$window_id" ]] || continue
        aerospace move-node-to-workspace --window-id "$window_id" "$workspace" || true
    done <<< "$windows"
}

restore_windows() {
    local windows="$1" window_id layout fullscreen
    while IFS=$'\t' read -r window_id layout fullscreen; do
        [[ -n "$window_id" ]] || continue
        [[ "$layout" == floating ]] && aerospace layout --window-id "$window_id" floating || true
        [[ "$fullscreen" == true ]] && aerospace fullscreen on --window-id "$window_id" || true
    done <<< "$windows"
}

move_windows "$source_windows" "$target_workspace"
move_windows "$target_windows" "$source_workspace"

[[ -n "$target_layout" ]] && aerospace layout --workspace "$source_workspace" --root "$target_layout" || true
[[ -n "$source_layout" ]] && aerospace layout --workspace "$target_workspace" --root "$source_layout" || true
restore_windows "$source_windows"
restore_windows "$target_windows"

if [[ -n "$target_focused_window" ]]; then
    aerospace focus --window-id "$target_focused_window" || aerospace workspace "$source_workspace"
else
    aerospace workspace "$source_workspace"
fi
