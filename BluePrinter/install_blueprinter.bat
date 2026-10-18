@echo off
rem Installs the BluePrinter widget in the official Beyond All Reason (BAR must be installed).
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_blueprinter.ps1"
echo.
pause
endlocal
