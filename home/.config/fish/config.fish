# install omf if not installed
if not type -q omf
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish
end

# user define alias
alias gaa "git add --all"
alias gc "git commit -m"
alias gf "git fetch"
alias gl "git pull"
alias glg "git log"
alias gp "git push"
alias gst "git status"
alias la "ls -A"
alias lal "la -lh"
alias ll "ls -lh"
alias sdn "shutdown now"
alias tosync "cd ~/syncfolder/"
alias ... "cd ../.."
alias .... "cd ../../.."
alias ..... "cd ../../../.."
alias ...... "cd ../../../../.."
alias ....... "cd ../../../../../.."
command -qv nvim && alias vi nvim && alias vim nvim
if [  -n "$(uname -a | grep Ubuntu)" ]; then
    alias bat="batcat --pager='never'" 
else
    alias bat="bat --pager='never''"
fi  