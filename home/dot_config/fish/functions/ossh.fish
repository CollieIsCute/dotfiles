function ossh --wraps=ssh --description 'SSH with legacy algorithms for old boxes'
    # 最小限度放寬：允許舊主機的 ssh-rsa/ssh-dss host key，
    # 並附帶較舊但仍常見的 KEX。你的自訂參數在後面，會覆蓋這些預設。
    set -l legacy \
        -o HostKeyAlgorithms=+ssh-rsa \
            -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o KexAlgorithms=+diffie-hellman-group14-sha1

    command ssh $legacy $argv
end
