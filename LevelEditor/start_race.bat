@echo off
rem Starts a Renegade Race at once: you choose a scout (keys 1 to 4 or a click) and drive 2 laps through 8 rings on the map Comet Catcher Remake 1.8.
rem Other map: start_race.bat "Map name" (e.g. start_race.bat "Full Metal Plate 1.7"). For a faster start add quick as the second parameter (start_race.bat "Comet Catcher Remake 1.8" quick): then the Legion units are not loaded (no Wheelie).
rem Keys in the game: W A S D = drive, mouse = look, Space = jump (Tick only); after the race N = new race, L = leave. The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "MAP=%~1"
if not defined MAP set "MAP=Comet Catcher Remake 1.8"
set "QUICK="
if /i "%~2"=="quick" set "QUICK=-QuickTest"
echo Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\start_renegade.ps1" -Mode race -Map "%MAP%" -Ai NullAI -Bots 0 -DebugMode 0 %QUICK%
if errorlevel 1 pause
endlocal
