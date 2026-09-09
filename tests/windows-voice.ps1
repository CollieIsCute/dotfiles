# Run on Windows after chezmoi apply. Uses the real CPU model and installed binaries.
$ErrorActionPreference = "Stop"
$command = Join-Path $env:USERPROFILE ".local\bin\asr-mode.cmd"
if (!(Test-Path -LiteralPath $command)) { throw "Missing installed asr-mode.cmd" }
if (!(Test-Path -LiteralPath (Join-Path $env:USERPROFILE ".local\bin\openwhispr.exe"))) {
    throw "Missing portable OpenWhispr"
}
$voiceSettings = Get-Content -Raw -LiteralPath (Join-Path $env:APPDATA "open-whispr\.env")
foreach ($setting in @('DICTATION_KEY=Shift+F13', 'VOICE_AGENT_KEY=Meta+F13', 'ACTIVATION_MODE=push')) {
    if ($voiceSettings -notmatch ("(?m)^" + [regex]::Escape($setting) + "\r?$")) {
        throw "Missing OpenWhispr setting: $setting"
    }
}

$savedLocalAppData = $env:LOCALAPPDATA
$savedCache = $env:XDG_CACHE_HOME
$testRoot = Join-Path $env:TEMP ("asr test " + [guid]::NewGuid())
$env:LOCALAPPDATA = $testRoot
$env:XDG_CACHE_HOME = $testRoot
$stateFile = Join-Path $testRoot "crispasr\server.json"

function Invoke-Mode([string]$Mode, [bool]$ShouldPass = $true) {
    & $command $Mode
    if (($LASTEXITCODE -eq 0) -ne $ShouldPass) {
        throw "Unexpected exit code $LASTEXITCODE for asr-mode $Mode"
    }
}

try {
    Invoke-Mode invalid $false
    Invoke-Mode off
    # A stale record must never kill a different executable, even with matching PID/time.
    $self = Get-Process -Id $PID
    @{ ProcessId = $PID; StartTicks = $self.StartTime.ToUniversalTime().Ticks } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile
    Invoke-Mode off

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 8080)
    $listener.Start()
    try {
        Invoke-Mode off $false
        if (!$listener.Server.IsBound) { throw "Stopped an unrelated listener" }
    } finally { $listener.Stop() }

    Invoke-Mode sensevoice
    $first = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json
    if (!(Get-Process -Id $first.ProcessId -ErrorAction SilentlyContinue)) {
        throw "ASR did not survive its launcher exiting"
    }
    $connections = @(Get-NetTCPConnection -State Listen -LocalPort 8080)
    if ($connections.Count -ne 1 -or $connections[0].LocalAddress -ne "127.0.0.1" -or
        $connections[0].OwningProcess -ne $first.ProcessId) {
        throw "ASR is not bound exclusively to loopback"
    }
    # The right executable with the wrong start time must not be terminated either.
    @{ ProcessId = $first.ProcessId; StartTicks = 0 } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile
    Invoke-Mode off $false
    if (!(Get-Process -Id $first.ProcessId -ErrorAction SilentlyContinue)) {
        throw "Stopped a process with a mismatched start time"
    }
    $first | ConvertTo-Json | Set-Content -LiteralPath $stateFile
    $model = Join-Path $testRoot "crispasr\sensevoice-small-q8_0.gguf"
    $downloaded = (Get-Item -LiteralPath $model).LastWriteTimeUtc
    Invoke-Mode sensevoice
    if (Get-Process -Id $first.ProcessId -ErrorAction SilentlyContinue) {
        throw "Restart left the previous ASR process alive"
    }
    if ((Get-Item -LiteralPath $model).LastWriteTimeUtc -ne $downloaded) {
        throw "Restart downloaded the cached model again"
    }
    Invoke-Mode off
    Invoke-Mode off
    if (Test-Path -LiteralPath $stateFile) { throw "off left a process record" }

    # An invalid cached model must produce failure and leave no managed process/port.
    Set-Content -LiteralPath $model -Value "invalid model"
    Invoke-Mode sensevoice $false
    if (Test-Path -LiteralPath $stateFile) { throw "Failed startup left a process record" }
    if ([Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port -contains 8080) {
        throw "Failed startup left port 8080 listening"
    }
    $cpu = Join-Path $env:USERPROFILE ".local\libexec\crispasr\cpu\crispasr.exe"
    if (Get-Process -Name crispasr -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $cpu }) {
        throw "Failed startup left a CrispASR process"
    }
    Invoke-Mode off
    Write-Output "PASS: Windows CPU startup, restart, cache reuse, process ownership, occupied port, failure cleanup, and off"
} finally {
    try { Invoke-Mode off }
    finally {
        $env:LOCALAPPDATA = $savedLocalAppData
        $env:XDG_CACHE_HOME = $savedCache
    }
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
