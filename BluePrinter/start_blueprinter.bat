@echo off
rem Makes sure the newest BluePrinter is installed and starts the normal Beyond All Reason with it.
rem For a small test game with a passive opponent use start_blueprinter_test.bat.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_blueprinter.ps1"
if errorlevel 1 pause
endlocal
