function ossh --wraps=ssh --description 'SSH with legacy algorithms for old boxes'
    # 最小限度放寬：允許舊主機的 ssh-rsa host key，並附帶較舊但常見的 KEX。
    # 注意 ssh 的 -o 是「先出現的優先」，這些預設會蓋過你在後面加的同名 -o。
    set -l legacy \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o KexAlgorithms=+diffie-hellman-group14-sha1

    # 先走預設，失敗再回退到 legacy 參數。
    # 只看 255（ssh 自己的連線錯誤），避免遠端最後一個指令非 0 時又重連一次。
    command ssh $argv
    set -l code $status
    if test $code -eq 255
        echo "ossh: fallback with legacy ssh options ..." 1>&2
        # 舊主機的 ncurses 沒有 xterm-kitty 的 terminfo，只換掉這個值；
        # 其他 TERM（包含用 `TERM=... ossh` 指定的）照原樣送出。
        set -l term $TERM
        test "$term" = xterm-kitty; and set term xterm-256color
        TERM=$term command ssh $legacy $argv
        return $status
    end
    return $code
end
