function __voxtype_download_model --argument-names binary model
    set -l config_home "$XDG_CONFIG_HOME"
    test -n "$config_home"
    or set config_home "$HOME/.config"
    set -l config "$config_home/voxtype/config.toml"

    test -f "$config"
    or begin
        echo "voxtype-mode: missing managed config: $config" >&2
        return 1
    end

    set -l backup (mktemp)
    or return 1
    command cp -p -- "$config" "$backup"
    or begin
        command rm -f -- "$backup"
        return 1
    end

    "$binary" setup --download --model "$model" --quiet --no-post-install
    set -l result $status
    command cp -p -- "$backup" "$config"
    or set result 1
    command rm -f -- "$backup"
    return $result
end

function __voxtype_qwen_checksum_ok --argument-names expected file
    test -f "$file"
    and printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status
end

function voxtype-mode --description 'Switch VoxType ASR model or stop ASR'
    argparse h/help -- $argv
    or return 2

    if set -q _flag_help
        printf '%s\n' \
            'Usage: voxtype-mode MODE' \
            '' \
            'Modes:' \
            '  whisper-turbo  Whisper large-v3-turbo (Vulkan)' \
            '  whisper-large  Whisper large-v3 (Vulkan)' \
            '  sensevoice     SenseVoiceSmall FP32 (CPU)' \
            '  qwen-1.7b      Qwen3-ASR 1.7B Q8_0 (CrispASR/Vulkan)' \
            '  off            Stop and verify all managed ASR processes' \
            '' \
            'A missing model is downloaded only when that mode is selected.'
        return
    end

    if test (count $argv) -ne 1
        echo 'Usage: voxtype-mode {whisper-turbo|whisper-large|sensevoice|qwen-1.7b|off}' >&2
        return 2
    end
    contains -- $argv[1] whisper-turbo whisper-large sensevoice qwen-1.7b off
    or begin
        echo "voxtype-mode: unknown mode: $argv[1]" >&2
        return 2
    end

    for dependency in systemctl pgrep
        command -q $dependency
        or begin
            echo "voxtype-mode: missing $dependency" >&2
            return 1
        end
    end
    systemctl --user show-environment >/dev/null
    or begin
        echo 'voxtype-mode: systemd user manager is unavailable' >&2
        return 1
    end
    if test $argv[1] != off; and not command -q systemd-run
        echo 'voxtype-mode: missing systemd-run' >&2
        return 1
    end

    set -l active_unit voxtype-active.service
    set -l qwen_unit voxtype-qwen.service
    set -l data_home "$XDG_DATA_HOME"
    test -n "$data_home"
    or set data_home "$HOME/.local/share"
    set -l data_dir "$data_home/voxtype/models"
    set -l crisp_dir "$HOME/.local/libexec/crispasr"
    set -l crisp_pattern (string escape --style=regex "$crisp_dir/crispasr")
    set -l asr_process_pattern (string join '' '^(/usr/bin/voxtype|/usr/lib/voxtype/voxtype-|' $crisp_pattern ')( |$)')
    set -l daemon_cmd
    set -l start_qwen 0
    set -l qwen_model

    switch $argv[1]
        case whisper-turbo
            test -s "$data_dir/ggml-large-v3-turbo.bin"
            or __voxtype_download_model /usr/lib/voxtype/voxtype-vulkan large-v3-turbo
            or return
            set daemon_cmd /usr/lib/voxtype/voxtype-vulkan \
                --engine whisper --model large-v3-turbo --gpu-isolation daemon

        case whisper-large
            test -s "$data_dir/ggml-large-v3.bin"
            or __voxtype_download_model /usr/lib/voxtype/voxtype-vulkan large-v3
            or return
            set daemon_cmd /usr/lib/voxtype/voxtype-vulkan \
                --engine whisper --model large-v3 --gpu-isolation daemon

        case sensevoice
            set -l sense_dir "$data_dir/sensevoice-small-fp32"
            if not test -s "$sense_dir/model.onnx"; or not test -s "$sense_dir/tokens.txt"
                __voxtype_download_model /usr/lib/voxtype/voxtype-onnx-avx2 small-fp32
                or return
            end
            set daemon_cmd /usr/lib/voxtype/voxtype-onnx-avx2 \
                --engine sensevoice --on-demand-loading daemon

        case qwen-1.7b
            test -x "$crisp_dir/crispasr" -a -r "$crisp_dir/libc2pa_c.so"
            or begin
                echo 'voxtype-mode: missing CrispASR; run chezmoi apply' >&2
                return 1
            end

            for dependency in curl sha256sum stat
                command -q $dependency
                or begin
                    echo "voxtype-mode: missing $dependency" >&2
                    return 1
                end
            end

            set qwen_model "$data_dir/qwen3-asr-1.7b-q8_0.gguf"
            set -l qwen_part "$qwen_model.part"
            set -l qwen_size 2506723200
            set -l qwen_sha 9851ab996591a2d0cb0efb216002764b509c86bd40c95e613d7b65b8e69c8a6e
            set -l qwen_url https://huggingface.co/cstr/qwen3-asr-1.7b-GGUF/resolve/674df5d44b50a63e7102a18895ed20e3f91de301/qwen3-asr-1.7b-q8_0.gguf

            if not __voxtype_qwen_checksum_ok $qwen_sha "$qwen_model"
                mkdir -p "$data_dir"
                if test -f "$qwen_part"
                    and test (stat -c %s "$qwen_part") -ge $qwen_size
                    if __voxtype_qwen_checksum_ok $qwen_sha "$qwen_part"
                        mv -f -- "$qwen_part" "$qwen_model"
                    else
                        rm -f -- "$qwen_part"
                    end
                end

                if not __voxtype_qwen_checksum_ok $qwen_sha "$qwen_model"
                    echo 'Downloading Qwen3-ASR 1.7B Q8_0 (2.51 GB)...'
                    curl --fail --location --retry 3 --continue-at - \
                        --output "$qwen_part" "$qwen_url"
                    or return

                    test (stat -c %s "$qwen_part") -eq $qwen_size
                    and __voxtype_qwen_checksum_ok $qwen_sha "$qwen_part"
                    or begin
                        rm -f -- "$qwen_part"
                        echo 'voxtype-mode: Qwen model verification failed' >&2
                        return 1
                    end
                    mv -f -- "$qwen_part" "$qwen_model"
                end
            end

            set start_qwen 1
            set daemon_cmd /usr/lib/voxtype/voxtype-avx2 \
                --engine whisper --whisper-mode remote --language auto \
                --remote-endpoint http://127.0.0.1:8080 daemon

        case off
            systemctl --user stop $active_unit $qwen_unit voxtype.service >/dev/null 2>&1
            or true
            for unit in $active_unit $qwen_unit voxtype.service
                if systemctl --user is-active --quiet $unit
                    echo "voxtype-mode: $unit is still active" >&2
                    return 1
                end
            end
            if pgrep -u (id -u) -f "$asr_process_pattern" >/dev/null
                echo 'voxtype-mode: an ASR process is still running' >&2
                pgrep -a -u (id -u) -f "$asr_process_pattern" >&2
                return 1
            end
            return

    end

    systemctl --user stop $active_unit $qwen_unit voxtype.service >/dev/null 2>&1
    or true

    if test $start_qwen -eq 1
        systemd-run --user --quiet --collect --service-type=exec --unit=$qwen_unit -- \
            "$crisp_dir/crispasr" --server --backend qwen3 --gpu-backend vulkan \
            --lid-backend none -m "$qwen_model" --host 127.0.0.1 --port 8080
        or return
        curl --fail --silent --retry 30 --retry-delay 1 --retry-connrefused \
            --max-time 2 http://127.0.0.1:8080/health >/dev/null
        or begin
            systemctl --user stop $qwen_unit >/dev/null 2>&1
            echo 'voxtype-mode: CrispASR did not become ready' >&2
            return 1
        end
    end

    systemd-run --user --quiet --collect --service-type=exec --unit=$active_unit -- $daemon_cmd
    or begin
        test $start_qwen -eq 1
        and systemctl --user stop $qwen_unit >/dev/null 2>&1
        return 1
    end
end
