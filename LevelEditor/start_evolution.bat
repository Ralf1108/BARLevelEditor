@echo off
rem Starts an Evolution game at once: you against one SimpleAI on the map Hooked 1.1, with the debug mode of Evolution on.
rem Other map or computer player: start_evolution.bat "Map name" AIName (e.g. start_evolution.bat "Comet Catcher Remake 1.8" SimpleDefenderAI).
rem The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "MAP=%~1"
if not defined MAP set "MAP=Hooked 1.1"
set "AI=%~2"
if not defined AI set "AI=SimpleAI"
echo Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\start_evolution.ps1" -Map "%MAP%" -Ai "%AI%"
if errorlevel 1 pause
endlocal
