function oscp --wraps=scp --description 'SCP with legacy algorithms for old boxes'
    # 最小限度放寬：允許舊主機的 ssh-rsa host key，並附帶較舊但常見的 KEX。
    # 注意 ssh 的 -o 是「先出現的優先」，這些預設會蓋過你在後面加的同名 -o。
    set -l legacy \
        -o HostKeyAlgorithms=+ssh-rsa \
        -o PubkeyAcceptedAlgorithms=+ssh-rsa \
        -o KexAlgorithms=+diffie-hellman-group14-sha1

    # 先走預設（SFTP 傳輸），連線失敗再自動改用舊 scp 協議（-O）。
    # 只看 255（連線 / SFTP 握手失敗）；檔案不存在、權限不足等傳輸錯誤是 1，不重試。
    command scp $argv
    set -l code $status
    if test $code -eq 255
        echo "oscp: fallback to legacy scp protocol (-O) ..." 1>&2
        command scp -O $legacy $argv
        return $status
    end
    return $code
end
