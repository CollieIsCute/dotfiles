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

function __voxtype_stop_jobs --argument-names os
    switch $os
        case Linux
            command systemctl --user stop voxtype-active.service voxtype-asr.service voxtype-qwen.service voxtype.service >/dev/null 2>&1
            or true
        case Darwin
            for label in com.collie.voxtype.active com.collie.voxtype.asr
                command launchctl remove $label >/dev/null 2>&1
                or true
            end
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

    for dependency in id pgrep
        command -q $dependency
        or begin
            echo "voxtype-mode: missing $dependency" >&2
            return 1
        end
    end
    if test $os = Linux
        command -q systemctl
        and command systemctl --user show-environment >/dev/null
        or begin
            echo 'voxtype-mode: systemd user manager is unavailable' >&2
            return 1
        end
        if test $mode != off; and not command -q systemd-run
            echo 'voxtype-mode: missing systemd-run' >&2
            return 1
        end
    else if not command -q launchctl
        echo 'voxtype-mode: missing launchctl' >&2
        return 1
    end

    set -l voxtype "$HOME/.local/libexec/voxtype/voxtype"
    set -l crisp "$HOME/.local/libexec/crispasr/crispasr"
    set -l pattern (string join '|' \
        (string escape --style=regex -- "$voxtype") \
        (string escape --style=regex -- "$crisp") \
        /usr/bin/voxtype '/usr/lib/voxtype/voxtype-[^ ]+')
    set pattern "^($pattern)( |\$)"

    if test $mode = off
        __voxtype_stop_jobs $os
        if test $os = Linux
            for unit in voxtype-active.service voxtype-asr.service voxtype-qwen.service voxtype.service
                if command systemctl --user is-active --quiet $unit
                    echo "voxtype-mode: $unit is still active" >&2
                    return 1
                end
            end
        else
            for label in com.collie.voxtype.active com.collie.voxtype.asr
                if command launchctl list $label >/dev/null 2>&1
                    echo "voxtype-mode: $label is still active" >&2
                    return 1
                end
            end
        end
        if command pgrep -u (id -u) -f "$pattern" >/dev/null
            echo 'voxtype-mode: an ASR process is still running' >&2
            command pgrep -a -u (id -u) -f "$pattern" >&2
            return 1
        end
        return
    end

    test -x "$voxtype" -a -x "$crisp"
    or begin
        echo 'voxtype-mode: missing VoxType or CrispASR; run chezmoi apply' >&2
        return 1
    end

    set -l gpu_args
    switch $os
        case Linux
            test -r "$HOME/.local/libexec/crispasr/libc2pa_c.so"
            or begin
                echo 'voxtype-mode: incomplete CrispASR install; run chezmoi apply' >&2
                return 1
            end
            set gpu_args --gpu-backend vulkan
        case Darwin
            test -r "$HOME/.local/libexec/crispasr/libc2pa_c.dylib"
            or begin
                echo 'voxtype-mode: incomplete CrispASR install; run chezmoi apply' >&2
                return 1
            end
            set gpu_args --gpu-backend metal
    end

    set -l data_home "$XDG_DATA_HOME"
    test -n "$data_home"
    or set data_home "$HOME/.local/share"
    set -l data_dir "$data_home/voxtype/models"
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
            set server_mode $gpu_args
            set model "$data_dir/qwen3-asr-1.7b-q8_0.gguf"
            __voxtype_download_model \
                'Qwen3-ASR 1.7B Q8_0 (2.51 GB)' \
                https://huggingface.co/cstr/qwen3-asr-1.7b-GGUF/resolve/674df5d44b50a63e7102a18895ed20e3f91de301/qwen3-asr-1.7b-q8_0.gguf \
                "$model"
            or return
    end

    __voxtype_stop_jobs $os
    set -l server_cmd "$crisp" --server --backend $backend $server_mode \
        --lid-backend off -m "$model" --host 127.0.0.1 --port 8080
    switch $os
        case Linux
            command systemd-run --user --quiet --collect --service-type=exec \
                --unit=voxtype-asr.service -- $server_cmd
        case Darwin
            command launchctl submit -l com.collie.voxtype.asr -- $server_cmd
    end
    or return

    set -l ready 0
    set -l attempt 0
    while test $attempt -lt 30
        if command curl --fail --silent --max-time 2 http://127.0.0.1:8080/health >/dev/null
            set ready 1
            break
        end
        set attempt (math $attempt + 1)
        sleep 1
    end
    if test $ready -ne 1
        __voxtype_stop_jobs $os
        echo 'voxtype-mode: CrispASR did not become ready' >&2
        return 1
    end

    set -l daemon_cmd "$voxtype" daemon
    if test $os = Darwin
        set daemon_cmd /usr/bin/env VOXTYPE_HOTKEY_ENABLED=true VOXTYPE_HOTKEY=F13 "$voxtype" daemon
    end
    switch $os
        case Linux
            command systemd-run --user --quiet --collect --service-type=exec \
                --unit=voxtype-active.service -- $daemon_cmd
        case Darwin
            command launchctl submit -l com.collie.voxtype.active -- $daemon_cmd
    end
    or begin
        __voxtype_stop_jobs $os
        return 1
    end
end
