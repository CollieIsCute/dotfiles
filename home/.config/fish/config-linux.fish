# ubuntu specific functions
if cat /etc/os-release | grep -q -E "Ubuntu"
    function wo
        set openlist $argv
        for item in $openlist
            xdg-open $item > /dev/null 2>&1 &
        end
    end
    
    function hide
        setsid $argv > /dev/null 2>&1 &
    end
end

if cat /etc/os-release | grep -q -E "Ubuntu"
    alias bat="batcat --pager='never'" 
else
    alias bat="bat --pager='never'"
end