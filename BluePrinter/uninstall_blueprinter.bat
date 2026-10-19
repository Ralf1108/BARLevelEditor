@echo off
rem Removes the BluePrinter widget again (widget, shared code, junctions). The blueprints are kept.
rem With "uninstall_blueprinter.bat -WithSettings" the settings file in the game folder is deleted as well.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall_blueprinter.ps1" %*
echo.
pause
endlocal
