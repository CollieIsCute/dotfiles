# Existing panes keep their shell environment across tmux reattachments.
status is-interactive; and set -q TMUX; and command -q tmux; or return

function __tmux_sync_environment --on-event fish_preexec
    set -l environment (command tmux show-environment 2>/dev/null)
    or return

    for variable in DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR
        set -l assignment (string match -- "$variable=*" $environment)
        if test (count $assignment) -eq 1
            set -gx $variable (string replace -- "$variable=" "" "$assignment")
        else if contains -- "-$variable" $environment
            set -e $variable
        end
    end
end

__tmux_sync_environment
