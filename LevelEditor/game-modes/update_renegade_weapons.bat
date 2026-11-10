@echo off
rem Renegade: reads renegade_weapons.csv (the source: the columns Group and Fire button) and writes renegade-weapons.md and the block WEAPON_BUTTONS of scripts\renegade_game.lua.
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
