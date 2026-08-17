function __voxtype_download_model --argument-names label url file
    test -f "$file"
    and return

    command mkdir -p (command dirname "$file")
    or return
    echo "Downloading $label..."
    command curl --fail --location --retry 3 --output "$file" "$url"
    or begin
        command rm -f -- "$file"
        return 1
    end
end

function __voxtype_stop_macos
    for label in com.collie.voxtype.active com.collie.voxtype.asr
        command launchctl remove $label >/dev/null 2>&1
        or true
    end
end

function voxtype-mode --description 'Switch VoxType ASR model or stop ASR'
    argparse h/help -- $argv
    or return 2

    if set -q _flag_help
        printf '%s\n' \
            'Usage: voxtype-mode MODE' \
            '' \
            'Modes:' \
            '  sensevoice  SenseVoice Small Q8_0 (CPU)' \
            '  qwen-1.7b   Qwen3-ASR 1.7B Q8_0 (GPU)' \
            '  off         Stop and verify all managed ASR processes' \
            '' \
            'A missing model is downloaded only when that mode is selected.'
        return
    end

    if test (count $argv) -ne 1
        echo 'Usage: voxtype-mode {sensevoice|qwen-1.7b|off}' >&2
        return 2
    end
    set -l mode $argv[1]
    contains -- $mode sensevoice qwen-1.7b off
    or begin
        echo "voxtype-mode: unknown mode: $mode" >&2
        return 2
    end

    set -l os (uname -s)
    contains -- $os Linux Darwin
    or begin
        echo "voxtype-mode: unsupported platform: $os" >&2
        return 1
    end

    if test $os = Linux
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
        if test $mode != off; and not command -q systemd-run
            echo 'voxtype-mode: missing systemd-run' >&2
            return 1
        end
    else
        for dependency in launchctl pgrep
            command -q $dependency
            or begin
                echo "voxtype-mode: missing $dependency" >&2
                return 1
            end
        end
    end

    set -l active_unit voxtype-active.service
    set -l asr_unit voxtype-asr.service
    set -l data_home "$XDG_DATA_HOME"
    test -n "$data_home"
    or set data_home "$HOME/.local/share"
    set -l data_dir "$data_home/voxtype/models"
    set -l crisp "$HOME/.local/libexec/crispasr/crispasr"
    set -l voxtype /usr/bin/voxtype
    set -l process_pattern (string join '|' \
        /usr/bin/voxtype '/usr/lib/voxtype/voxtype-[^ ]+' \
        (string escape --style=regex -- "$crisp"))

    if test $os = Darwin
        set voxtype "$HOME/.local/libexec/voxtype/voxtype"
        set process_pattern (string join '|' \
            (string escape --style=regex -- "$voxtype") \
            (string escape --style=regex -- "$crisp"))
    end
    set process_pattern "^($process_pattern)( |\$)"

    if test $mode = off
        if test $os = Linux
            systemctl --user stop $active_unit $asr_unit voxtype-qwen.service voxtype.service >/dev/null 2>&1
            or true
            for unit in $active_unit $asr_unit voxtype-qwen.service voxtype.service
                if systemctl --user is-active --quiet $unit
                    echo "voxtype-mode: $unit is still active" >&2
                    return 1
                end
            end
        else
            __voxtype_stop_macos
            for label in com.collie.voxtype.active com.collie.voxtype.asr
                if launchctl list $label >/dev/null 2>&1
                    echo "voxtype-mode: $label is still active" >&2
                    return 1
                end
            end
        end
        if pgrep -u (id -u) -f "$process_pattern" >/dev/null
            echo 'voxtype-mode: an ASR process is still running' >&2
            if test $os = Linux
                pgrep -a -u (id -u) -f "$process_pattern" >&2
            else
                pgrep -fl -u (id -u) "$process_pattern" >&2
            end
            return 1
        end
        return
    end

    test -x "$voxtype" -a -x "$crisp"
    or begin
        echo 'voxtype-mode: missing VoxType or CrispASR; run chezmoi apply' >&2
        return 1
    end

    set -l backend
    set -l server_mode
    set -l model
    switch $mode
        case sensevoice
            set backend sensevoice
            set server_mode -ng
            set model "$data_dir/sensevoice-small-q8_0.gguf"
            __voxtype_download_model \
                'SenseVoice Small Q8_0 (252 MB)' \
                https://huggingface.co/cstr/sensevoice-small-GGUF/resolve/e14d94223aef728879f08dfb4d5f20fe873b22ef/sensevoice-small-q8_0.gguf \
                "$model"
            or return
        case qwen-1.7b
            set backend qwen3
            set server_mode --gpu-backend vulkan
            test $os = Darwin
            and set server_mode --gpu-backend metal
            set model "$data_dir/qwen3-asr-1.7b-q8_0.gguf"
            __voxtype_download_model \
                'Qwen3-ASR 1.7B Q8_0 (2.51 GB)' \
                https://huggingface.co/cstr/qwen3-asr-1.7b-GGUF/resolve/674df5d44b50a63e7102a18895ed20e3f91de301/qwen3-asr-1.7b-q8_0.gguf \
                "$model"
            or return
    end

    set -l server_cmd "$crisp" --server --backend $backend $server_mode \
        --lid-backend off -m "$model" --host 127.0.0.1 --port 8080
    if test $os = Linux
        systemctl --user stop $active_unit $asr_unit voxtype-qwen.service voxtype.service >/dev/null 2>&1
        or true
        systemd-run --user --quiet --collect --service-type=exec --unit=$asr_unit -- $server_cmd
    else
        __voxtype_stop_macos
        launchctl submit -l com.collie.voxtype.asr -- $server_cmd
    end
    or return

    curl --fail --silent --retry 30 --retry-delay 1 --retry-connrefused \
        --max-time 2 http://127.0.0.1:8080/health >/dev/null
    or begin
        if test $os = Linux
            systemctl --user stop $asr_unit >/dev/null 2>&1
        else
            __voxtype_stop_macos
        end
        echo 'voxtype-mode: CrispASR did not become ready' >&2
        return 1
    end

    set -l daemon_cmd "$voxtype" daemon
    test $os = Darwin
    and set daemon_cmd /usr/bin/env VOXTYPE_HOTKEY_ENABLED=true VOXTYPE_HOTKEY=F13 "$voxtype" daemon
    if test $os = Linux
        systemd-run --user --quiet --collect --service-type=exec --unit=$active_unit -- $daemon_cmd
    else
        launchctl submit -l com.collie.voxtype.active -- $daemon_cmd
    end
    or begin
        if test $os = Linux
            systemctl --user stop $asr_unit >/dev/null 2>&1
        else
            __voxtype_stop_macos
        end
        return 1
    end
end
