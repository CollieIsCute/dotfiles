@echo off
powershell.exe -NoProfile -File "%~dp0..\libexec\asr-mode.ps1" %*
exit /b %errorlevel%
