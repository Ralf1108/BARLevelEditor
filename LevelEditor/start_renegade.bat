@echo off
rem Starts a Renegade game at once (first person test): you with one Peewee on the map Hooked 1.1 against 3 computer Peewees that walk around and fight you.
rem Other map, computer player or number of enemies: start_renegade.bat "Map name" AIName Count (e.g. start_renegade.bat "Comet Catcher Remake 1.8" SimpleAI 5).
rem All units are loaded (also Legion, the extra units of the release candidates and the Scavenger and Raptor units). For quick tests add the fourth parameter quick (start_renegade.bat "Hooked 1.1" NullAI 3 quick): then they are not loaded and the start is faster.
rem Keys in the game: mouse = look, W A S D = walk, left / right / middle mouse button = short range weapons / long range weapons / missiles, Insert = normal camera and back, Tab = free mouse for the debug menu (turn into another unit). The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "MAP=%~1"
if not defined MAP set "MAP=Hooked 1.1"
set "AI=%~2"
if not defined AI set "AI=NullAI"
set "BOTS=%~3"
if not defined BOTS set "BOTS=3"
set "QUICK="
if /i "%~4"=="quick" set "QUICK=-QuickTest"
echo Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\start_renegade.ps1" -Map "%MAP%" -Ai "%AI%" -Bots %BOTS% %QUICK%
if errorlevel 1 pause
endlocal
