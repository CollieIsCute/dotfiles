@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\libexec\asr-mode.ps1" %*
exit /b %errorlevel%
