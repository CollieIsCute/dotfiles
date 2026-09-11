#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet("sensevoice", "qwen-1.7b", "off")]
    [string]$Mode
)

if (!$Mode) {
    Write-Output "Usage: asr-mode {sensevoice|qwen-1.7b|off}"
    exit 2
}

$ErrorActionPreference = "Stop"
$lock = $null
try {
    $crispRoot = Join-Path $env:USERPROFILE ".local\libexec\crispasr"
    $cpu = Join-Path $crispRoot "cpu\crispasr.exe"
    $vulkan = Join-Path $crispRoot "vulkan\crispasr.exe"
    $crisp = if ($Mode -eq "qwen-1.7b") { $vulkan } else { $cpu }
    $stateDir = Join-Path $env:LOCALAPPDATA "crispasr"
    $stateFile = Join-Path $stateDir "server.json"
    $health = "http://127.0.0.1:8080/health"
    [IO.Directory]::CreateDirectory($stateDir) | Out-Null
    # Serialize starts, switches, downloads and off for this user.
    $lock = [IO.File]::Open((Join-Path $stateDir "server.lock"), "OpenOrCreate", "ReadWrite", "None")

    function Stop-ASRProcess($Managed) {
        try { Stop-Process -InputObject $Managed }
        catch { if (!$Managed.HasExited) { throw } }
        if (!$Managed.WaitForExit(5000)) { throw "CrispASR did not stop; retaining its process record." }
    }

    function Stop-ASR {
        if (Test-Path -LiteralPath $stateFile) {
            $state = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json
            $managed = Get-Process -Id $state.ProcessId -ErrorAction SilentlyContinue
            $ownsProcess = $false
            if ($managed) {
                # Check executable and creation time: Windows can reuse a stale PID.
                try {
                    $ownsProcess = $managed.Path -in @($cpu, $vulkan) -and
                        $managed.StartTime.ToUniversalTime().Ticks -eq $state.StartTicks
                } catch { if (!$managed.HasExited) { throw } }
            }
            if ($ownsProcess) { Stop-ASRProcess $managed }
            Remove-Item -LiteralPath $stateFile
        }
    }

    function Assert-PortFree {
        $listeners = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
        if ($listeners.Port -contains 8080) {
            throw "Port 8080 is still in use. Close its owner before starting ASR."
        }
    }

    if ($Mode -eq "off") {
        Stop-ASR
        Assert-PortFree
        return
    }
    if (!(Test-Path -LiteralPath $crisp)) { throw "Missing CrispASR; run chezmoi apply." }

    if ($Mode -eq "sensevoice") {
        $model = Join-Path $stateDir "sensevoice-small-q8_0.gguf"
        $url = "https://huggingface.co/cstr/sensevoice-small-GGUF/resolve/e14d94223aef728879f08dfb4d5f20fe873b22ef/sensevoice-small-q8_0.gguf"
    } else {
        $model = Join-Path $stateDir "qwen3-asr-1.7b-q8_0.gguf"
        $url = "https://huggingface.co/cstr/qwen3-asr-1.7b-GGUF/resolve/674df5d44b50a63e7102a18895ed20e3f91de301/qwen3-asr-1.7b-q8_0.gguf"
    }
    if (!(Test-Path -LiteralPath $model)) {
        Write-Output "Downloading $Mode..."
        & curl.exe --fail --location --retry 3 --output "$model.part" $url
        if ($LASTEXITCODE -ne 0) {
            Remove-Item -LiteralPath "$model.part" -ErrorAction SilentlyContinue
            throw "Model download failed."
        }
        Move-Item -LiteralPath "$model.part" -Destination $model -Force
    }

    Stop-ASR
    Assert-PortFree
    $process = $null
    try {
        $process = Start-Process -FilePath $crisp -PassThru -WindowStyle Hidden `
            -ArgumentList "--server --lid-backend off -m `"$model`" --host 127.0.0.1 --port 8080" `
            -RedirectStandardOutput (Join-Path $stateDir "server.out.log") `
            -RedirectStandardError (Join-Path $stateDir "server.err.log")
        @{ ProcessId = $process.Id; StartTicks = $process.StartTime.ToUniversalTime().Ticks } |
            ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
        $ready = $false
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            if ($process.HasExited) { break }
            try {
                $response = Invoke-WebRequest -UseBasicParsing -Uri $health -TimeoutSec 2
                $owner = Get-NetTCPConnection -State Listen -LocalPort 8080 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200 -and $owner.OwningProcess -contains $process.Id) {
                    $ready = $true
                    break
                }
            } catch { }
            Start-Sleep -Seconds 1
        }
        if (!$ready) { throw "CrispASR did not become ready. See $stateDir\server.err.log (check the model, VC++ runtime and Vulkan driver)." }
        Write-Output "OpenWhispr Model ID:"
        Write-Output $model
    } catch {
        if ($process -and !$process.HasExited) {
            Stop-ASRProcess $process
        }
        Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
        throw
    }
} catch {
    [Console]::Error.WriteLine("asr-mode: $_")
    exit 1
} finally {
    if ($lock) { $lock.Dispose() }
}
