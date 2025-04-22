function la
  if command -vq eza
    eza --icons --git -lA $argv
  else
    ls -lA $argv
  end
end