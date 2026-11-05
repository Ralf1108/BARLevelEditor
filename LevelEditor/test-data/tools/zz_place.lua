function widget:GetInfo() return { name = "zz place", desc = "test only: window position, start position, ready", layer = 0, enabled = true } end
-- Test widget of lan_test.ps1 -Mode pve.
-- (The window is placed by the Chobby settings that lan_test.ps1 writes: window mode 6, a quarter of the left half of the screen.)
-- Start position: in the start screen the camera points at the middle of the start box of the ally team, so that the middle of the window is inside the box; the
-- test script clicks there again and again (the engine takes a start position only from a mouse click; with the draft mode one player after the other).
-- When the start position is set it logs "placed" (the script stops clicking) and sends ready.
local FALLBACK = { PlayerA = { 1536, 768 }, PlayerB = { 9216, 768 }, PlayerC = { 1536, 11500 } }
local pos
local name
local placedAt
local readySent = false
local function log(...) local t = {} for i, v in ipairs({ ... }) do t[i] = tostring(v) end Spring.Echo("[zzplace] " .. table.concat(t, " ")) end

function widget:Initialize()
	name = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
	local x1, z1, x2, z2 = Spring.GetAllyTeamStartBox(Spring.GetMyAllyTeamID())
	if x1 and x2 and x2 > x1 then pos = { (x1 + x2) / 2, (z1 + z2) / 2 } else pos = FALLBACK[name] end
	log("player", tostring(name), "start box", tostring(x1), tostring(z1), tostring(x2), tostring(z2), "target", pos and pos[1] or "none", pos and pos[2] or "none")
end
function widget:Update()
	if (Spring.GetGameFrame() or 0) > 0 or not pos or readySent then return end
	if not placedAt then
		local y = Spring.GetGroundHeight(pos[1], pos[2])
		Spring.SetCameraTarget(pos[1], y, pos[2], 0)
		if not widget.shown then
			widget.shown = true
			local sx, sy = Spring.WorldToScreenCoords(pos[1], y, pos[2])
			local vx, vy = Spring.GetViewGeometry()
			log("target on the screen", tostring(sx), tostring(sy), "window", tostring(vx), tostring(vy))
		end
		local x = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
		if x and x > 0 then placedAt = os.clock(); log("placed at", x) end
	elseif os.clock() > placedAt + 2 then
		readySent = true
		Spring.SendLuaRulesMsg("ready_to_start_game")
		log("ready sent")
	end
end
function widget:GameStart() log("GameStart") end
