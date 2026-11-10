@echo off
rem Starts a Renegade game at once (first person test): you with one Peewee on the map Hooked 1.1 against 3 computer Peewees that walk around and fight you.
rem Other map, computer player or number of enemies: start_renegade.bat "Map name" AIName Count (e.g. start_renegade.bat "Comet Catcher Remake 1.8" SimpleAI 5).
rem Keys in the game: mouse = look, W A S D = walk, left mouse button = main weapon, right mouse button = the other weapons, Insert = normal camera and back, Tab = free mouse for the debug menu (turn into another unit). The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "DATA=C:\Games\Beyond-All-Reason\data"
set "MAP=%~1"
if not defined MAP set "MAP=Hooked 1.1"
set "AI=%~2"
if not defined AI set "AI=NullAI"
set "BOTS=%~3"
if not defined BOTS set "BOTS=3"
echo Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1" -Data "%DATA%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\start_renegade.ps1" -Data "%DATA%" -Map "%MAP%" -Ai "%AI%" -Bots %BOTS%
if errorlevel 1 pause
endlocal
