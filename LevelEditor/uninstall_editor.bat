@echo off
rem Removes the Level Editor again (extra game, junctions, desktop icon). Levels and blueprints are kept.
rem With "uninstall_editor.bat -WithSettings" the settings files in the game folder are deleted as well.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall_editor.ps1" %*
echo.
pause
endlocal
