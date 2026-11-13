@echo off
rem Renegade: reads renegade_weapons.csv (the column Fire button), renegade_cruise.csv (the column Cruise altitude used), renegade_weapon_limits.csv and the pictures in weapon-images, and writes
rem renegade-weapons.md, renegade-cruise.md, renegade-weapon-categories.md and fills the columns Category, Weapon image, Tech and DPS of renegade_weapons.csv and the blocks WEAPON_BUTTONS, CRUISE_ALT, ATTACK_ALT and WEAPON_PICS of scripts\renegade_data.lua.
rem Close the csv files in Excel first. Then start Renegade as usual (start_renegade.bat): the game takes the new file.
setlocal
python "%~dp0..\test-data\generators\weapon_categories.py"
if errorlevel 1 goto failed
python "%~dp0..\test-data\generators\renegade_weapons.py" update
if errorlevel 1 goto failed
goto done
:failed
echo.
echo Something went wrong ^(is Python installed? is a csv open in Excel?^).
:done
echo.
pause
endlocal
