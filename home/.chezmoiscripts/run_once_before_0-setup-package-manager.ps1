$ErrorActionPreference = "Stop"
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
$scoop = Join-Path $scoopRoot "shims\scoop.cmd"

if (!(Test-Path $scoop)) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
}

if (!(Test-Path $scoop)) {
    throw "Scoop installation completed but $scoop was not found."
}
