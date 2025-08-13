function oscp --wraps=scp --description 'SCP with legacy algorithms for old boxes'
    # 最小限度放寬：允許舊主機的 ssh-rsa/ssh-dss host key，
    # 並附帶較舊但常見的 KEX。你的自訂參數在後面，會覆蓋這些預設。
    set -l legacy \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o KexAlgorithms=+diffie-hellman-group14-sha1

    # 先走預設（SFTP 傳輸），失敗再自動改用舊 scp 協議（-O）
    command scp $legacy $argv
    set -l code $status
    if test $code -ne 0
        echo "oscp: fallback to legacy scp protocol (-O) ..." 1>&2
        command scp -O $legacy $argv
    end
end
