function cd --description 'z (fallback to builtin cd)' --wraps cd
  if type -q z
    z -- $argv
  else
    builtin cd -- $argv
  end
end