function wo --description 'Open file/URL with the system opener' --wraps open
    set -l opener
    if command -q open
        set opener open
    else if command -q xdg-open
        set opener xdg-open
    else if command -q gio
        set opener "gio open"
    else
        echo "wo: no opener (open/xdg-open/gio) found" 1>&2
        return 127
    end

    set -l rc 0
    for item in $argv
        if test "$opener" = "gio open"
            command gio open -- "$item" >/dev/null 2>&1 &
        else
            command $opener -- "$item" >/dev/null 2>&1 &
        end
        set -l s $status
        test $s -eq 0; or set rc $s
    end

    jobs -q; and disown
    return $rc
end
