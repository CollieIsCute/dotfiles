fish_add_path /opt/homebrew/bin
eval "$(/opt/homebrew/bin/brew shellenv)"

alias buu='brew update --auto-update && brew upgrade && brew cleanup && fisher update'
