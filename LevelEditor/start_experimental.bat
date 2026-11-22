@echo off
rem Starts a test game of the Experimental Units at once on the map Full Metal Plate 1.7: next to your start a Volcano with a Lava Extractor,
rem a Carrier, a Cargo Truck and a Forklift side by side and a vehicle plant behind them. Select a vehicle and right-click the Lava Extractor (order Haul).
rem Other map: start_experimental.bat "Map name". The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "MAP=%~1"
if not defined MAP set "MAP=Full Metal Plate 1.7"
echo Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\start_experimental.ps1" -Map "%MAP%"
if errorlevel 1 pause
endlocal
