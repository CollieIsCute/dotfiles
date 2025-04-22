# ~/.config/fish/functions/manp.fish
# manp: Display a manual page for a selected command using fzf.
# If 'man' fails to find the manual, fallback to tldr (if installed).

function manp
    # Check for dependencies before proceeding
    if not type -q fzf
        echo "fzf is not installed. Please install fzf to use this function."
        return 1
    end

    if not type -q tldr
        echo "tldr is not installed. Fallback to tldr will not be available."
    end

    # Main logic
    type -a (functions; builtin -n; alias; command -v (string split \n $PATH | string join '/*')) \
    | string trim | string match -r '^[a-zA-Z0-9._+-]+$' | sort -u | fzf | read -l cmd

    if test -n "$cmd"
        man $cmd ^/dev/null; or tldr $cmd
    end
end
