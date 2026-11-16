function widget:GetInfo() return { name = "zz ren95", desc = "test only: the sounds of Renegade and Evolution (mode_ui.lua) and the hit marker", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenPowerups -Widget zz_ren95.lua: every sound file of mode_ui.lua exists in the game (VFS.FileExists); then a jump (Space), a hit and a
-- kill (ren|test|1 and ren|test|9), the power-ups (ren|test|7 and the key 1), the loss of the unit (ren|test|2) and the respawn; at the end the count of every sound played
-- (M.played: the sandbox has no sound device, PlaySoundFile is still called). With -Evo -EvoTest: level up (evo|test|... Level Up of the debug mode needs -Debug) instead.
-- Lines "[zzren95]".
local function log(...) Spring.Echo("[zzren95] " .. table.concat({ ... }, " ")) end
local evo = (Spring.GetModOptions() or {}).lanevolution == "1"
local function played()
	local M = WG.renegade and WG.renegade.M
	local t = {}
	for name, n in pairs(M and M.played or {}) do t[#t + 1] = name .. "=" .. n end
	table.sort(t)
	return table.concat(t, " ")
end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R or not R.M then return end
	if f == 60 then
		R.fake = true; R.yaw, R.pitch = 0, 0
		local missing = {}
		local n = 0
		for name, s in pairs(R.M.SOUNDS) do
			n = n + 1
			if not VFS.FileExists(s[1]) then missing[#missing + 1] = name .. ":" .. s[1] end
		end
		log("sound files:", n, "missing:", #missing, table.concat(missing, " "))
	end
	if f == 100 then R.keys = 16 end -- (Space: jump)
	if f == 103 then R.keys = 0 end
	if f == 160 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 170 then Spring.SendLuaRulesMsg("ren|test|9") end -- (a kill: hit marker and kill sound)
	if f == 180 then log("after jump and kill:", played(), "kill marker", tostring(R.H.killAt ~= nil)) end
	if f == 200 then Spring.SendLuaRulesMsg("ren|test|7") end -- (all power-ups: pick-up sound)
	if f == 230 then pcall(R.keyPress, 49, {}, false, "1", 49, 30) end -- (key 1: Sprint)
	if f == 260 then log("after the power-ups:", played()) end
	if f == 280 then Spring.SendLuaRulesMsg("ren|test|2") end -- (the unit is lost)
	if f == 480 then log("after the loss and the respawn:", played()); Spring.SendCommands("quitforce") end
end
