@echo off
rem PalCraft installer launcher. Any extra arguments (e.g. -WhatIf) are passed through.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PalCraft-Installer.ps1" %*
if errorlevel 1 (
  echo.
  echo The installer reported a problem. See %TEMP%\PalCraft-install.log
  pause
)
