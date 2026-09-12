$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

# Let WSL prepare its own prerequisites; this does not install a distribution.
& wsl.exe --install --no-distribution
if ($LASTEXITCODE -ne 0) {
    throw "WSL setup did not complete (exit code $LASTEXITCODE). Approve administrator access or restart Windows if requested, then rerun this bootstrap."
}

$distributions = & wsl.exe --list --all --quiet
if ($LASTEXITCODE -ne 0) { throw "Cannot list WSL distributions. Restart Windows if setup requested it, then rerun this bootstrap." }
# Windows PowerShell can retain NULs from wsl.exe's UTF-16 output.
if ((($distributions -join "") -replace "`0", "").Trim() -eq "") {
    & wsl.exe --set-default-version 2
    if ($LASTEXITCODE -ne 0) { throw "Cannot enable WSL 2. Restart Windows if requested, then rerun this bootstrap." }
    & wsl.exe --install --distribution archlinux --no-launch
    if ($LASTEXITCODE -ne 0) { throw "Arch installation failed with exit code $LASTEXITCODE. Resolve the WSL error above, then rerun this bootstrap." }
}

# Check the kernel before any Linux setup, even before a new user's first login.
$kernel = & wsl.exe --user root --exec uname -r
if ($LASTEXITCODE -ne 0) { throw "Cannot start the default WSL distribution. Restart Windows if requested; otherwise resolve the WSL error above. No other distribution will be installed." }
if (($kernel -join "") -notmatch '(?i)microsoft.*wsl2') {
    throw "The default distribution must use WSL 2. Check 'wsl --list --verbose', convert it with 'wsl --set-version <name> 2', then rerun this bootstrap."
}

$uid = & wsl.exe --exec id -u
if ($LASTEXITCODE -ne 0) { throw "Cannot determine the default WSL user." }
if (($uid -join "").Trim() -eq "0") {
    $linuxUser = if ($env:CHEZMOI_WSL_USER) { $env:CHEZMOI_WSL_USER } else { $env:USERNAME.ToLowerInvariant() }
    if ($linuxUser -cnotmatch '^[a-z_][a-z0-9_-]{0,31}$' -or $linuxUser -eq 'root') {
        throw "Set CHEZMOI_WSL_USER to a valid non-root Linux username, then rerun the same Windows entry."
    }
    $distro = & wsl.exe --user root --exec printenv WSL_DISTRO_NAME
    if ($LASTEXITCODE -ne 0) { throw "Cannot determine the default WSL distribution." }
    $distro = ($distro -join "").Trim()
    $setup = & wsl.exe --user root --exec wslpath -a (Join-Path $PSScriptRoot 'bootstrap-wsl-user.sh')
    if ($LASTEXITCODE -ne 0) { throw "Cannot access the WSL user bootstrap." }
    & wsl.exe --user root --exec bash ($setup -join "").Trim() $linuxUser
    if ($LASTEXITCODE -ne 0) { throw "WSL user setup failed with exit code $LASTEXITCODE." }
    & wsl.exe --manage $distro --set-default-user $linuxUser
    if ($LASTEXITCODE -ne 0) { throw "Cannot set the default WSL user." }
}
