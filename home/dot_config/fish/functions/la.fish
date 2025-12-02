function la --description 'eza -A --icons --git (fallback to ls)' --wraps eza
    if command -q eza
        command eza --icons --git --group-directories-first -A $argv
    else
        command ls -A $argv
    end
end