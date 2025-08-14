function ossh --wraps=ssh --description 'SSH with legacy algorithms for old boxes'
    # 最小限度放寬：允許舊主機的 ssh-rsa host key，
    # 並附帶較舊但常見的 KEX。你的自訂參數在後面，會覆蓋這些預設。
    set -l legacy \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o KexAlgorithms=+diffie-hellman-group14-sha1

    # 先走預設，失敗再回退到 legacy 參數
    command ssh $argv
    set -l code $status
    if test $code -ne 0
        echo "ossh: fallback with legacy ssh options ..." 1>&2
        command ssh $legacy $argv
    end
end
