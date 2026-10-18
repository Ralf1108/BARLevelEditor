@echo off
rem Sets up the Level Editor: BAR must be installed (launcher started once).
rem Afterwards: start_level_editor.bat
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_editor.ps1"
echo.
pause
endlocal
