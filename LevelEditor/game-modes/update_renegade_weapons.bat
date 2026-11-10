@echo off
rem Renegade: reads renegade_weapons.csv (the column Fire button) and renegade_cruise.csv (the column Cruise altitude used) and writes renegade-weapons.md, renegade-cruise.md and the blocks WEAPON_BUTTONS and CRUISE_ALT of scripts\renegade_game.lua.
rem Close the csv in Excel first. Then start Renegade as usual (start_renegade.bat): the game takes the new file.
setlocal
python "%~dp0..\test-data\tools\renegade_weapons.py" update
if errorlevel 1 (
    echo.
    echo Something went wrong ^(is Python installed? is the csv open in Excel?^).
)
echo.
pause
endlocal
