# ~/.config/fish/completions/wo.fish
# 若系統有 open，就繼承 open 的補全
complete -c wo -w open    -n "type -q open"

# 若沒有 open 但有 xdg-open，就繼承 xdg-open 的補全
complete -c wo -w xdg-open -n "not type -q open; and type -q xdg-open"
