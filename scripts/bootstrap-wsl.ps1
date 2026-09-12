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
    Write-Host "Arch installed. Create a non-root Linux user with sudo access (see README), then run 'chezmoi apply' from Windows."
}

# Check the kernel before any Linux setup, even before a new user's first login.
$kernel = & wsl.exe --user root --exec uname -r
if ($LASTEXITCODE -ne 0) { throw "Cannot start the default WSL distribution. Restart Windows if requested; otherwise resolve the WSL error above. No other distribution will be installed." }
if (($kernel -join "") -notmatch '(?i)microsoft.*wsl2') {
    throw "The default distribution must use WSL 2. Check 'wsl --list --verbose', convert it with 'wsl --set-version <name> 2', then rerun this bootstrap."
}

# --no-launch skips Arch's first-login keyring setup. Reuse the official script.
& wsl.exe --user root --exec bash -c 'source /etc/os-release; if [[ $ID == arch && ! -s /etc/pacman.d/gnupg/pubring.gpg ]]; then /usr/lib/wsl/first-setup.sh; fi'
if ($LASTEXITCODE -ne 0) { throw "WSL first-login setup failed with exit code $LASTEXITCODE." }
