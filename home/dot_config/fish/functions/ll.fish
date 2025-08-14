function ll --description 'eza -lh --icons --git (fallback to ls)' --wraps eza
  if command -q eza
    command eza --icons --git --group-directories-first -lh --total-size -- $argv
  else
    command ls -lh -- $argv
  end
end