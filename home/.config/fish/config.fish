# run OS specific script
switch (uname)
    case Darwin
        source (dirname (status --current-filename))/config-macos.fish
    case Linux
        source (dirname (status --current-filename))/config-linux.fish
end

# user define alias
alias gaa="git add --all"
alias gc="git commit -m"
alias gf="git fetch"
alias gl="git pull"
alias glg="git log"
alias gp="git push"
alias gst="git status"
alias la="ls -A"
alias lal="la -lh"
alias ll="ls -lh"
alias sdn="shutdown now"
alias tosync="cd ~/syncfolder/"
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."
alias .......="cd ../../../../../.."
command -v nvim >/dev/null && alias vi="nvim"
