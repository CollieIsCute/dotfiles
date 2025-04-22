function lal
  if command -vq eza
    eza --icons --git -Alh --total-size $argv
  else
    ls -Alh $argv
  end
end