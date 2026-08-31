function __asr_download_model --argument-names label url file
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

function __asr_stop_managed --argument-names os
    if test $os = Linux
        command systemctl --user stop crispasr.service \
            voxtype-active.service voxtype-asr.service voxtype-qwen.service voxtype.service \
            >/dev/null 2>&1
    else
        for label in com.collie.crispasr com.collie.voxtype.active com.collie.voxtype.asr
            command launchctl remove $label >/dev/null 2>&1
            or true
        end
        return
    end
    or true
end

function asr-mode --description 'Switch CrispASR model or stop ASR'
    argparse h/help -- $argv
    or return 2

    if set -q _flag_help
        printf '%s\n' \
            'Usage: asr-mode {sensevoice|qwen-1.7b|off}' \
            '' \
            '  sensevoice  SenseVoice Small Q8_0 (CPU)' \
            '  qwen-1.7b   Qwen3-ASR 1.7B Q8_0 (GPU)' \
            '  off         Stop CrispASR and verify PID and port 8080 are gone' \
            '' \
            'OpenWhispr remains running; this command controls CrispASR only.'
        return
    end

    if test (count $argv) -ne 1
        echo 'Usage: asr-mode {sensevoice|qwen-1.7b|off}' >&2
        return 2
    end
    set -l mode $argv[1]
    contains -- $mode sensevoice qwen-1.7b off
    or begin
        echo "asr-mode: unknown mode: $mode" >&2
        return 2
    end

    set -l os (uname -s)
    contains -- $os Linux Darwin
    or begin
        echo "asr-mode: unsupported platform: $os" >&2
        return 1
    end

    set -l dependencies curl pgrep
    if test $os = Linux
        set -a dependencies systemctl
        test $mode = off
        or set -a dependencies systemd-run
    else
        set -a dependencies launchctl
    end
    for dependency in $dependencies
        command -q $dependency
        or begin
            echo "asr-mode: missing $dependency" >&2
            return 1
        end
    end
    if test $os = Linux
        command systemctl --user show-environment >/dev/null
        or begin
            echo 'asr-mode: systemd user manager is unavailable' >&2
            return 1
        end
    end

    set -l unit crispasr.service
    set -l label com.collie.crispasr
    set -l health http://127.0.0.1:8080/health
    set -l data_home "$XDG_DATA_HOME"
    test -n "$data_home"
    or set data_home "$HOME/.local/share"
    # Reuse the existing models; moving 2.76 GB adds no value.
    set -l model_dir "$data_home/voxtype/models"
    set -l crisp "$HOME/.local/libexec/crispasr/crispasr"
    set -l process_pattern "^"(string escape --style=regex -- "$crisp")"( |\$)"

    if test $mode = off
        __asr_stop_managed $os
        if test $os = Linux
            if command systemctl --user is-active --quiet $unit
                echo "asr-mode: $unit is still active" >&2
                return 1
            end
        else if command launchctl list $label >/dev/null 2>&1
            echo "asr-mode: $label is still loaded" >&2
            return 1
        end
        if command pgrep -u (id -u) -f "$process_pattern" >/dev/null
            echo 'asr-mode: CrispASR is still running' >&2
            return 1
        end
        if command curl --fail --silent --max-time 1 "$health" >/dev/null 2>&1
            echo 'asr-mode: port 8080 health endpoint is still reachable' >&2
            return 1
        end
        return
    end

    test -x "$crisp"
    or begin
        echo 'asr-mode: missing CrispASR; run chezmoi apply' >&2
        return 1
    end

    set -l backend
    set -l server_mode
    set -l model
    switch $mode
        case sensevoice
            set backend sensevoice
            set server_mode -ng
            set model "$model_dir/sensevoice-small-q8_0.gguf"
            __asr_download_model \
                'SenseVoice Small Q8_0 (252 MB)' \
                https://huggingface.co/cstr/sensevoice-small-GGUF/resolve/e14d94223aef728879f08dfb4d5f20fe873b22ef/sensevoice-small-q8_0.gguf \
                "$model"
            or return
        case qwen-1.7b
            set backend qwen3
            set server_mode --gpu-backend vulkan
            test $os = Darwin
            and set server_mode --gpu-backend metal
            set model "$model_dir/qwen3-asr-1.7b-q8_0.gguf"
            __asr_download_model \
                'Qwen3-ASR 1.7B Q8_0 (2.51 GB)' \
                https://huggingface.co/cstr/qwen3-asr-1.7b-GGUF/resolve/674df5d44b50a63e7102a18895ed20e3f91de301/qwen3-asr-1.7b-q8_0.gguf \
                "$model"
            or return
    end

    set -l server_cmd "$crisp" --server --backend $backend $server_mode \
        --lid-backend off -m "$model" --host 127.0.0.1 --port 8080
    __asr_stop_managed $os
    if test $os = Linux
        command systemd-run --user --quiet --collect --service-type=exec --unit=$unit -- $server_cmd
    else
        command launchctl submit -l $label -- $server_cmd
    end
    or return

    command curl --fail --silent --retry 30 --retry-delay 1 --retry-connrefused \
        --max-time 2 "$health" >/dev/null
    or begin
        __asr_stop_managed $os
        echo 'asr-mode: CrispASR did not become ready' >&2
        return 1
    end
    if not command pgrep -u (id -u) -f "$process_pattern" >/dev/null
        __asr_stop_managed $os
        echo 'asr-mode: CrispASR process is not running' >&2
        return 1
    end
end
