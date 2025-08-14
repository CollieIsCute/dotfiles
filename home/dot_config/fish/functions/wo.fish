# ~/.config/fish/functions/wo.fish
function wo --description 'Open file/URL with the system opener'
    set -l code 127

    for item in $argv
        if type -q open
            # macOS: open 一次可收多個參數；逐一處理也可
            command open -- "$item" >/dev/null 2>&1 &
            set code 0
        else if type -q xdg-open
            # Linux: xdg-open 通常一次處理一個，逐一呼叫較穩
            command xdg-open -- "$item" >/dev/null 2>&1 &
            set code 0
        end
    end

    test $code -eq 0; and disown
    return $code
end
