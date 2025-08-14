function lal --description 'eza -Alh --icons --git (fallback to ls)' --wraps eza
    if command -q eza
        command eza --icons --git -Alh --total-size --group-directories-first -- $argv
    else
        command ls -Alh -- $argv
    end
end
