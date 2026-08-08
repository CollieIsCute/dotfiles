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

visible_workspaces="$(aerospace list-workspaces --all --visible --format '%{monitor-id}%{tab}%{workspace}')"
source_workspace="$(aerospace list-workspaces --focused)"
source_monitor="$(aerospace list-monitors --focused --format '%{monitor-id}')"

# Let AeroSpace resolve the target from the real monitor geometry.
aerospace move-workspace-to-monitor "$direction" || exit 0
target_monitor="$(aerospace list-monitors --focused --format '%{monitor-id}')"
target_workspace="$(
    printf '%s\n' "$visible_workspaces" |
        awk -F '\t' -v monitor="$target_monitor" '$1 == monitor { sub(/^[^\t]*\t/, ""); print; exit }'
)"

[[ -n "$target_workspace" ]]
aerospace move-workspace-to-monitor --workspace "$target_workspace" "$source_monitor"
aerospace workspace "$source_workspace"
