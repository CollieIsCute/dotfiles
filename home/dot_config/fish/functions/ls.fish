function ls --description 'eza (fallback to ls)' --wraps eza
  if command -q eza
    command eza --icons --git --group-directories-first -- $argv
  else
    command ls -- $argv
  end
end