@echo off
setlocal
set "AHK_EXE=C:\Program Files\AutoHotkey\AutoHotkeyU64.exe"
if not exist "%AHK_EXE%" (
  echo AutoHotkey v1 Unicode 64-bit was not found at:
  echo %AHK_EXE%
  pause
  exit /b 1
)
start "" "%AHK_EXE%" "%~dp0DeltaForcePostmatchAudit.ahk"
endlocal
