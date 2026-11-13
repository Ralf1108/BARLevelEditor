@echo off
rem Evolution: reads evolution_units.csv (the source: the columns Level, Long range and Note) and writes evolution-units.md and the lists POOL / POOL_LONG / NAMES of scripts\evo_game.lua.
rem Close the csv in Excel first. Then start Evolution as usual (start_evolution.bat): the game takes the new file.
setlocal
python "%~dp0..\test-data\generators\evolution_units.py" update
if errorlevel 1 (
    echo.
    echo Something went wrong ^(is Python installed? is the csv open in Excel?^).
)
echo.
pause
endlocal
