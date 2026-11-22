function widget:GetInfo() return { name = "zz aitake", desc = "test only: does the computer player take radars?", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -Widget zz_aitake.lua (one instance): speed 20, logs the chat lines "... took a radar." of the game (the human stands still, so
-- they are the computer's), ends at frame 9000 and logs how many it counted.
local took = 0
local function log(...) Spring.Echo("[zzaitake] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 20", "setminspeed 20") end
	if f % 900 == 0 then log("frame", f, "took", took) end
	if f == 9000 then log("result: the computer took", took, "radars or collectors"); Spring.SendCommands("quitforce") end
end
function widget:AddConsoleLine(line)
	if line:find(" took a ", 1, true) and not line:find("zzaitake", 1, true) then took = took + 1; log(line) end
end
