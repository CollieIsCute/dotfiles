function cd --description 'z (fallback to builtin cd)' --wraps z
    type -q z && z -- $argv || builtin cd -- $argv
end