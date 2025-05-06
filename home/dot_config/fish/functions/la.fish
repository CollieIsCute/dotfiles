function la
  if command -vq eza
    eza --icons --git -A $argv
  else
    ls -A $argv
  end
end