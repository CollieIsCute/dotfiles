#!/bin/sh
set -eu

repo=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
function_file=$repo/home/dot_config/fish/functions/voxtype-mode.fish
completion_file=$repo/home/dot_config/fish/completions/voxtype-mode.fish
config_file=$repo/home/dot_config/voxtype/config.toml

fish -n "$function_file" "$completion_file"

help=$(VOXTYPE_FUNCTION=$function_file fish -c 'source $VOXTYPE_FUNCTION; voxtype-mode --help')
printf '%s\n' "$help" | grep -F 'sensevoice' >/dev/null
printf '%s\n' "$help" | grep -F 'qwen-1.7b' >/dev/null
printf '%s\n' "$help" | grep -F 'off' >/dev/null
if printf '%s\n' "$help" | grep -Fi 'whisper' >/dev/null; then
    echo 'voxtype-mode still exposes a Whisper model' >&2
    exit 1
fi
if grep -Eq 'sha256|shasum|checksum|continue-at|wc -c' "$function_file"; then
    echo 'voxtype-mode still contains verified or resumable downloads' >&2
    exit 1
fi

modes=$(VOXTYPE_COMPLETION=$completion_file fish --no-config -c 'set -e fish_complete_path; source $VOXTYPE_COMPLETION; complete -C "voxtype-mode "' | cut -f1 | sort)
expected=$(printf '%s\n' off qwen-1.7b sensevoice)
test "$modes" = "$expected"

grep -Fx 'backend = "remote"' "$config_file" >/dev/null
grep -Fx 'remote_endpoint = "http://127.0.0.1:8080"' "$config_file" >/dev/null
if grep -Eq 'large-v3|\[sensevoice\]' "$config_file"; then
    echo 'VoxType config still references a removed local model' >&2
    exit 1
fi

if test "${VOXTYPE_CHECK_ASSETS:-0}" = 1; then
    test -x "$HOME/.local/libexec/voxtype/voxtype"
    test -x "$HOME/.local/libexec/crispasr/crispasr"
    "$HOME/.local/libexec/voxtype/voxtype" --version 2>&1 | grep -F '0.7.5' >/dev/null
    "$HOME/.local/libexec/crispasr/crispasr" --version 2>&1 | grep -F '0.8.28' >/dev/null
    case $(uname -s) in
        Darwin) test -f "$HOME/.local/libexec/crispasr/libc2pa_c.dylib" ;;
        Linux)
            test -f "$HOME/.local/libexec/crispasr/libc2pa_c.so"
            test -f "$HOME/.local/libexec/crispasr/libopenblas.so.0"
            ;;
    esac
fi
