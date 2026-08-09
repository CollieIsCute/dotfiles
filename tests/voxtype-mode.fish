#!/usr/bin/env fish

set -l root (path resolve (path dirname (status filename))/..)
set -l scratch (mktemp -d)
set -l fake_bin "$scratch/bin"

function __voxtype_test_cleanup --on-event fish_exit --inherit-variable scratch
    rm -rf -- "$scratch"
end

mkdir -p "$fake_bin" "$scratch/data/voxtype/models" "$scratch/config/voxtype"
printf '%s\n' '#!/bin/sh' 'printf "systemctl %s\n" "$*" >> "$VOXTYPE_TEST_LOG"' \
    'case " $* " in *" is-active "*) exit 1 ;; esac' >"$fake_bin/systemctl"
printf '%s\n' '#!/bin/sh' 'printf "systemd-run %s\n" "$*" >> "$VOXTYPE_TEST_LOG"' >"$fake_bin/systemd-run"
printf '%s\n' '#!/bin/sh' 'case "$*" in *" -f ^"*".*/libexec"*) exit 0 ;; *" -f ^"*) exit 1 ;; *) exit 0 ;; esac' >"$fake_bin/pgrep"
printf '%s\n' '#!/bin/sh' 'printf "mutated config\n" > "$XDG_CONFIG_HOME/voxtype/config.toml"' >"$fake_bin/voxtype-download"
chmod +x "$fake_bin"/*

set -gx HOME "$scratch/home"
set -gx XDG_DATA_HOME "$scratch/data"
set -gx XDG_CONFIG_HOME "$scratch/config"
set -gx VOXTYPE_TEST_LOG "$scratch/calls.log"
set -gx PATH $fake_bin $PATH

source "$root/home/dot_config/fish/functions/voxtype-mode.fish"
or exit 1
source "$root/home/dot_config/fish/completions/voxtype-mode.fish"
or exit 1
source "$root/home/dot_config/fish/functions/voxtype-post-process.fish"
or exit 1

set -l formatted (printf '%s\n' '软件process使用3个thread，Qwen3-ASR模型。' | voxtype-post-process)
test "$formatted" = '軟體 process 使用 3 個 thread，Qwen3-ASR 模型。'
or exit 1
set -l reformatted (printf '%s\n' "$formatted" | voxtype-post-process)
test "$reformatted" = "$formatted"
or exit 1

string match -q '*command = "fish -c voxtype-post-process"*' <"$root/home/dot_config/voxtype/config.toml"
or exit 1

printf 'managed config\n' >"$XDG_CONFIG_HOME/voxtype/config.toml"
__voxtype_download_model "$fake_bin/voxtype-download" test-model
and string match -q 'managed config' <"$XDG_CONFIG_HOME/voxtype/config.toml"
or exit 1

set -l help_text (voxtype-mode --help)
test $status -eq 0
and string match -q '*qwen-1.7b*' -- "$help_text"
or exit 1

voxtype-mode invalid >/dev/null 2>&1
test $status -eq 2
and not test -e "$VOXTYPE_TEST_LOG"
or exit 1

voxtype-mode off
and string match -q '*stop voxtype-active.service voxtype-qwen.service voxtype.service*' <"$VOXTYPE_TEST_LOG"
or exit 1

printf '%s\n' '#!/bin/sh' 'exit 0' >"$fake_bin/pgrep"
voxtype-mode off >/dev/null 2>&1
test $status -eq 1
or exit 1
printf '%s\n' '#!/bin/sh' 'case "$*" in *" -f ^"*".*/libexec"*) exit 0 ;; *" -f ^"*) exit 1 ;; *) exit 0 ;; esac' >"$fake_bin/pgrep"

printf x >"$XDG_DATA_HOME/voxtype/models/ggml-large-v3-turbo.bin"
voxtype-mode whisper-turbo
and string match -q '*voxtype-vulkan*--gpu-isolation daemon*' <"$VOXTYPE_TEST_LOG"
or exit 1

printf x >"$XDG_DATA_HOME/voxtype/models/ggml-large-v3.bin"
voxtype-mode whisper-large
and string match -q '*--model large-v3 --gpu-isolation daemon*' <"$VOXTYPE_TEST_LOG"
or exit 1

mkdir -p "$XDG_DATA_HOME/voxtype/models/sensevoice-small-fp32"
printf x >"$XDG_DATA_HOME/voxtype/models/sensevoice-small-fp32/model.onnx"
printf x >"$XDG_DATA_HOME/voxtype/models/sensevoice-small-fp32/tokens.txt"
voxtype-mode sensevoice
and string match -q '*voxtype-onnx-avx2*--engine sensevoice --on-demand-loading daemon*' <"$VOXTYPE_TEST_LOG"
or exit 1

voxtype-mode qwen-1.7b >/dev/null 2>&1
test $status -eq 1
or exit 1

mkdir -p "$HOME/.local/libexec/crispasr"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$HOME/.local/libexec/crispasr/crispasr"
printf x >"$HOME/.local/libexec/crispasr/libc2pa_c.so"
printf x >"$XDG_DATA_HOME/voxtype/models/qwen3-asr-1.7b-q8_0.gguf"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$fake_bin/curl"
chmod +x "$HOME/.local/libexec/crispasr/crispasr" "$fake_bin/curl"
function __voxtype_qwen_checksum_ok
    return 0
end
voxtype-mode qwen-1.7b
and string match -q '*crispasr*--backend qwen3*--lid-backend none*' <"$VOXTYPE_TEST_LOG"
or exit 1

set -l modes (complete -C 'voxtype-mode ' | string split \t -f 1 | sort)
test (string join ' ' $modes) = 'off qwen-1.7b sensevoice whisper-large whisper-turbo'
