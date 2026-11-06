@echo off
rem Starts two BAR instances on this computer that play together in LAN Play: PlayerA (with a Raptors computer in its team) and PlayerB (with a Scavengers
rem computer in its team), Raptors against Scavengers. Each human commands the units of its computer (the computer only spawns).
rem Own write folders (%TEMP%\lan_test), the installed game is not changed. The Level Editor setup (install_editor.bat) must have run once.
rem The two start positions are placed by the script with mouse clicks into the game windows: leave the mouse alone for the first minute after the start.
rem Close the game windows to end it.
setlocal
set "L=%~dp0"
set "DATA=C:\Games\Beyond-All-Reason\data"
tasklist /FI "IMAGENAME eq spring.exe" 2>nul | find /I "spring.exe" >nul
if not errorlevel 1 (
	echo A BAR game is running. Please close it first.
	pause & exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%test-data\tools\lan_test.ps1" -Mode mix -Play -Sync missing -WaitSec 14400 -Data "%DATA%"
if errorlevel 1 pause
endlocal
