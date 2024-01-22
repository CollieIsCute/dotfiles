fish_add_path /opt/homebrew/bin
eval "$(/opt/homebrew/bin/brew shellenv)"

alias buu='brew update && brew upgrade && brew cleanup && omf install && omf update'