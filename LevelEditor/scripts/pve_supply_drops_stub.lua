-- Replaces the gadget luarules/gadgets/pve_supply_drops.lua of the game, inside the extra game of the Level Editor and of the scenarios
-- (the files of the extra game come before those of the game it builds on; the files of the official game are not changed).
-- Why: that gadget treats every unit with "lootbox" in its name as a lootbox and lets the units of other teams within 1024 Elmo capture it (a progress
-- bar, then the unit is handed to the enemy next to it). The flags and the collection points of Capture the Flag are such units. The gadget is also
-- the one that drops lootboxes by the game option "lootboxes" (off by default), which these games do not need.
-- "return false" = the gadget is not loaded (as in the gadgets of the game itself).
return false
