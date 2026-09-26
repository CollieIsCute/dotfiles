#!/bin/bash
set -euo pipefail

case "${1:-}" in
    left|down|up|right) direction="$1" ;;
    *) exit 64 ;;
esac

# ponytail: one global lock is enough for a single AeroSpace session.
lock_dir="${TMPDIR:-/tmp}/aerospace-swap-workspaces.lock"
mkdir "$lock_dir" 2>/dev/null || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
trap exit HUP INT TERM

IFS=$'\t' read -r source_workspace source_layout < <(aerospace list-workspaces --focused --format '%{workspace}%{tab}%{workspace-root-container-layout}')
[[ "$source_workspace" =~ ^[1-9]$ ]] || exit 0

# Let AeroSpace resolve the target from the real monitor geometry.
aerospace focus-monitor "$direction" || exit 0
IFS=$'\t' read -r target_workspace target_layout < <(aerospace list-workspaces --focused --format '%{workspace}%{tab}%{workspace-root-container-layout}')
[[ "$target_workspace" =~ ^[1-9]$ ]] || { aerospace workspace "$source_workspace"; exit 0; }
windows="$(aerospace list-windows --workspace "$source_workspace" "$target_workspace" --format '%{window-id}%{tab}%{workspace}')"
target_focused_window="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"

while IFS=$'\t' read -r window_id workspace; do
    [[ -n "$window_id" ]] || continue
    destination="$source_workspace"
    if [[ "$workspace" == "$source_workspace" ]]; then destination="$target_workspace"; fi
    aerospace move-node-to-workspace --window-id "$window_id" "$destination" || true
done <<< "$windows"

aerospace layout --workspace "$source_workspace" --root "$target_layout" || true
aerospace layout --workspace "$target_workspace" --root "$source_layout" || true

aerospace focus --window-id "$target_focused_window" 2>/dev/null || aerospace workspace "$source_workspace"
