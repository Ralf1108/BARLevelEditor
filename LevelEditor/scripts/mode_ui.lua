-- What the screens of Evolution and Renegade share (unsynced; luaui/Include/mode_ui.lua, loaded by evo_ui.lua and by the widget renegade.lua). Returns M.
--   M.drawShieldRings(rule)        DrawWorld: a pulsing blue ring round every unit of a player with a spawn shield (unit rules ledShield = the frame it ends, led_gadgets.lua G.shield);
--                                  rule = the team rule with the unit of each team ("renUnit", "evoUnit")
--   M.drawOwnShield(unit, vsx, vsy) DrawScreen: "SPAWN SHIELD 3" under the middle while the own unit is shielded
--   M.drawNote(vsx, vsy)            DrawScreen: the note of the own team (team rules ledNote = "<frame>|<text>", G.note) for NOTE_LIFE seconds
local M = {}
local NOTE_LIFE = 6 * 30

local function shieldLeft(id)
	local untilF = id and Spring.ValidUnitID(id) and Spring.GetUnitRulesParam(id, "ledShield") or 0
	return math.max(0, (untilF or 0) - Spring.GetGameFrame())
end
M.shieldLeft = shieldLeft

function M.drawShieldRings(rule)
	local t = os.clock()
	for _, team in ipairs(Spring.GetTeamList()) do
		local id = Spring.GetTeamRulesParam(team, rule)
		if id and id > 0 and shieldLeft(id) > 0 and Spring.IsUnitVisible(id) then
			local x, y, z = Spring.GetUnitPosition(id)
			local r = (Spring.GetUnitRadius(id) or 30) * 1.4 + 6 * math.sin(t * 6)
			gl.DepthTest(false)
			gl.LineWidth(3)
			gl.Color(0.35, 0.75, 1, 0.75)
			gl.DrawGroundCircle(x, y, z, r, 40)
			gl.Color(0.7, 0.9, 1, 0.35)
			gl.DrawGroundCircle(x, y, z, r + 8, 40)
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
		end
	end
end

function M.drawOwnShield(unit, vsx, vsy)
	local left = shieldLeft(unit)
	if left <= 0 then return end
	local s = math.max(0.7, vsy / 1080)
	gl.Color(0.45, 0.8, 1, 1)
	gl.Text(string.format("SPAWN SHIELD %d", math.ceil(left / 30)), vsx / 2, vsy * 0.36, 24 * s, "co")
	gl.Color(0.8, 0.9, 1, 0.9)
	gl.Text("no damage for a few seconds; it ends when you fire", vsx / 2, vsy * 0.36 - 22 * s, 14 * s, "co")
	gl.Color(1, 1, 1, 1)
end

function M.note(team)
	local raw = tostring(Spring.GetTeamRulesParam(team or Spring.GetMyTeamID(), "ledNote") or "")
	local f, text = raw:match("^(%d+)|(.*)$")
	if not f then return nil end
	return tonumber(f), text
end

function M.drawNote(vsx, vsy)
	if Spring.GetSpectatingState() then return end
	local f, text = M.note()
	local age = f and Spring.GetGameFrame() - f
	if not age or age < 0 or age > NOTE_LIFE then return end
	local s = math.max(0.7, vsy / 1080)
	local a = math.min(1, (NOTE_LIFE - age) / 30)
	local w = gl.GetTextWidth(text) * 26 * s + 40 * s
	local y = vsy * 0.70
	gl.Color(0.05, 0.08, 0.04, 0.75 * a)
	gl.Rect(vsx / 2 - w / 2, y - 14 * s, vsx / 2 + w / 2, y + 34 * s)
	gl.Color(0.55, 1, 0.45, a)
	gl.Text(text, vsx / 2, y, 26 * s, "co")
	gl.Color(1, 1, 1, 1)
end

return M
