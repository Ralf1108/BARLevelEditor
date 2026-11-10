@echo off
rem Starts a Renegade game at once (first person test): you with one Peewee against a passive computer player on the map Hooked 1.1.
rem Other map or computer player: start_renegade.bat "Map name" AIName (e.g. start_renegade.bat "Comet Catcher Remake 1.8" SimpleAI).
rem Keys in the game: mouse = look, W A S D = walk, left mouse button = fire, Insert = normal camera and back. The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "DATA=C:\Games\Beyond-All-Reason\data"
set "MAP=%~1"
if not defined MAP set "MAP=Hooked 1.1"
set "AI=%~2"
if not defined AI set "AI=NullAI"
echo Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1" -Data "%DATA%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\start_renegade.ps1" -Data "%DATA%" -Map "%MAP%" -Ai "%AI%"
if errorlevel 1 pause
endlocal
