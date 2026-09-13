$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$OutputEncoding = [System.Text.UTF8Encoding]::new()

function Invoke-WSL {
    & wsl.exe @args
    if ($LASTEXITCODE -ne 0) { throw "WSL failed (exit code $LASTEXITCODE). Resolve the error above; approve administrator access or restart Windows if requested, then rerun the same entry." }
}

$checkout = Split-Path $PSScriptRoot -Parent
$savedWSLEnv = $env:WSLENV
try {
    $env:WSLENV = (@($savedWSLEnv, "CHEZMOI_GITHUB_ACCESS_TOKEN/u", "CHEZMOI_WSL_PASSWORD/u") | Where-Object { $_ }) -join ":"

    Invoke-WSL --install --no-distribution
    $distributions = Invoke-WSL --list --all --quiet
    # Windows PowerShell can retain NULs from wsl.exe's UTF-16 output.
    if ((($distributions -join "") -replace "`0", "").Trim() -eq "") {
        Invoke-WSL --set-default-version 2
        Invoke-WSL --install --distribution archlinux --no-launch
    }

    # Check the kernel before any Linux setup, even before a new user's first login.
    $kernel = Invoke-WSL --user root --exec uname -r
    if (($kernel -join "") -notmatch '(?i)microsoft.*wsl2') {
        throw "The default distribution must use WSL 2. Check 'wsl --list --verbose', convert it with 'wsl --set-version <name> 2', then rerun this bootstrap."
    }

    $release = Invoke-WSL --user root --exec cat /etc/os-release
    if (($release -join "`n") -notmatch '(?m)^ID="?arch"?\r?$') { throw "The default WSL distribution must be Arch Linux." }
    $uid = Invoke-WSL --exec id -u
    if (($uid -join "").Trim() -eq "0") {
        $linuxUser = if ($env:CHEZMOI_WSL_USER) { $env:CHEZMOI_WSL_USER } else { $env:USERNAME.ToLowerInvariant() }
        if ($linuxUser -cnotmatch '^[a-z_][a-z0-9_-]{0,31}$' -or $linuxUser -eq 'root') {
            throw "Set CHEZMOI_WSL_USER to a valid non-root Linux username, then rerun the same Windows entry."
        }
        if ($env:CHEZMOI_WSL_PASSWORD -match '[\r\n]') { throw "The bootstrap password must not contain line breaks." }
        Invoke-WSL --user root --exec sh -c 'test -s /etc/pacman.d/gnupg/pubring.gpg || /usr/lib/wsl/first-setup.sh'
        Invoke-WSL --user root --exec pacman -Syu --needed --noconfirm sudo
        $account = & wsl.exe --user root --exec getent passwd $linuxUser
        if ($LASTEXITCODE -eq 0) {
            if ([int]($account -split ':')[2] -lt 1000) { throw "Refusing a system account." }
        } elseif ($LASTEXITCODE -eq 2) {
            Invoke-WSL --user root --exec useradd -m -s /bin/bash $linuxUser
            if ($env:CHEZMOI_WSL_PASSWORD) {
                "${linuxUser}:$env:CHEZMOI_WSL_PASSWORD" | & wsl.exe --user root --exec bash -o pipefail -c "tr -d '\r' | chpasswd"
                if ($LASTEXITCODE -ne 0) { throw "Cannot set the Linux password." }
            } else {
                Invoke-WSL --user root --exec passwd $linuxUser
            }
        } else { throw "Cannot query the Linux account." }

        $rule = (Invoke-WSL --user root --exec mktemp).Trim()
        try {
            "$linuxUser ALL=(ALL:ALL) ALL" | & wsl.exe --user root --exec bash -o pipefail -c 'tr -d ''\r'' | tee "$1"' bash $rule | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Cannot write the sudo rule." }
            Invoke-WSL --user root --exec visudo -cf $rule
            Invoke-WSL --user root --exec install -m 0440 $rule "/etc/sudoers.d/90-chezmoi-wsl-$linuxUser"
        } finally {
            Invoke-WSL --user root --exec rm -f -- $rule
        }
        $distro = (Invoke-WSL --user root --exec printenv WSL_DISTRO_NAME).Trim()
        Invoke-WSL --manage $distro --set-default-user $linuxUser
    }

    $repo = (Invoke-WSL --user root --exec wslpath -a $checkout).Trim()
    # Keep a terminal for interactive passwords; detach only for unattended input.
    [string[]]$linuxCommand = if ($env:CHEZMOI_WSL_PASSWORD) { @('setsid', '--wait', 'bash') } else { @('bash') }
    Invoke-WSL --cd '~' --exec @linuxCommand "$repo/scripts/bootstrap-wsl.sh" $repo
}
finally {
    $env:WSLENV = $savedWSLEnv
}
