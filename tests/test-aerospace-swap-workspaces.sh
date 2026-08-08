#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
script="$repo_root/home/dot_config/aerospace/executable_swap-workspaces.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

action_log="$test_dir/actions"

(
    export TMPDIR="$test_dir"
    moved=false

    aerospace() {
        case "$*" in
            "list-workspaces --all --visible --format "*)
                printf '1\tabove\n2\tcurrent\n3\tbelow\n'
                ;;
            "list-workspaces --focused")
                printf 'current\n'
                ;;
            "list-monitors --focused --format "*)
                if $moved; then printf '3\n'; else printf '2\n'; fi
                ;;
            "move-workspace-to-monitor down")
                moved=true
                printf '%s\n' "$*" >> "$action_log"
                ;;
            "move-workspace-to-monitor --workspace below 2"|"workspace current")
                printf '%s\n' "$*" >> "$action_log"
                ;;
            *)
                printf 'unexpected aerospace call: %s\n' "$*" >&2
                return 1
                ;;
        esac
    }

    source "$script" down
)

expected=$'move-workspace-to-monitor down\nmove-workspace-to-monitor --workspace below 2\nworkspace current'
actual="$(cat "$action_log")"
[[ "$actual" == "$expected" ]]

if (source "$script" diagonal 2>/dev/null); then
    printf 'invalid direction unexpectedly succeeded\n' >&2
    exit 1
fi

printf 'aerospace workspace swap tests passed\n'
