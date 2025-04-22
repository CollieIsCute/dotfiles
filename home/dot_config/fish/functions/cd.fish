function cd
  if type -q z
    z $argv
  else
    builtin cd $argv
  end
end