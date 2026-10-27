@echo off
rem Installs the BluePrinter widget when it is not up to date and starts a small test game (1 player vs. passive AI) to look at the menu.
rem Optional: start_blueprinter_test.bat "Map Name"
setlocal
if "%~1"=="" (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_blueprinter_test.ps1"
) else (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_blueprinter_test.ps1" -Map "%~1"
)
if errorlevel 1 pause
endlocal
