-- What the screens of Evolution and Renegade share (unsynced; luaui/Include/mode_ui.lua, loaded by evo_ui.lua and by the widget renegade.lua). Returns M.
--   M.drawShieldRings(rule)        DrawWorld: a pulsing blue ring round every unit of a player with a spawn shield (unit rules ledShield = the frame it ends, led_gadgets.lua G.shield);
--                                  rule = the team rule with the unit of each team ("renUnit", "evoUnit")
--   M.drawOwnShield(unit, vsx, vsy) DrawScreen: "SPAWN SHIELD 3" under the middle while the own unit is shielded
--   M.drawNote(vsx, vsy)            DrawScreen: the note of the own team (team rules ledNote = "<frame>|<text>", G.note) for NOTE_LIFE seconds
--   M.play(name)                    a sound of SOUNDS (files of the game; the "ui" channel, so the volume of the interface sounds counts); the same sound at most every gap seconds
--   M.watchAbilities(rule)          Update: the sounds of the own power-ups from the team rule (renAbilities / evoAbilities): "pickup" for a new one, "use1" to "use5" when one starts
--   M.watchNote()                   Update: "bonus" when a new note of the own team comes
local M = {}
local NOTE_LIFE = 6 * 30

-- name -> { file of the game, volume, the shortest gap in seconds }
local SOUNDS = {
	jump = { "sounds/commands/cmd-move-swoosh.wav", 0.6, 0.2 },
	land = { "sounds/unit/banthstep.wav", 0.35, 0.2 },
	hit = { "sounds/commands/cmd-settarget.wav", 0.45, 0.1 },
	kill = { "sounds/ui/beep6.wav", 0.8, 0.1 },
	death = { "sounds/ui/warning1.wav", 0.7, 1 },
	respawn = { "sounds/ui/commanderspawn-mono.wav", 0.6, 1 },
	lowhp = { "sounds/ui/warning2.wav", 0.6, 3 },
	lock = { "sounds/function/targeting.wav", 0.45, 0.5 },
	pickup = { "sounds/commands/cmd-on.wav", 0.8, 0.2 },
	bonus = { "sounds/ui/teleport-short-mono.wav", 0.7, 1 },
	use1 = { "sounds/commands/cmd-move-swoosh.wav", 0.8, 0.3 },
	use2 = { "sounds/commands/cmd-repair.wav", 0.8, 0.3 },
	use3 = { "sounds/function/radar.wav", 0.8, 0.3 },
	use4 = { "sounds/function/cloak.wav", 0.8, 0.3 },
	use5 = { "sounds/function/jammer.wav", 0.8, 0.3 },
	levelup = { "sounds/function/comlevelup.wav", 0.9, 0.5 },
	armageddon = { "sounds/modbroadcast/dramatic.mp3", 0.8, 5 },
	win = { "sounds/modbroadcast/claping.mp3", 0.8, 5 },
	lose = { "sounds/modbroadcast/sad-trombone.mp3", 0.8, 5 },
	wave = { "sounds/modbroadcast/braam-1.mp3", 0.7, 2 },
	checkpoint = { "sounds/ui/beep4.wav", 0.8, 0.2 },
	lap = { "sounds/modbroadcast/bells.mp3", 0.7, 1 },
	tick = { "sounds/ui/beep6.wav", 0.6, 0.5 },
}
M.SOUNDS = SOUNDS
M.played = {} -- name -> how often (the tests)
local lastPlay = {}
function M.play(name)
	local s = SOUNDS[name]
	if not s then return end
	local now = os.clock()
	if lastPlay[name] and now - lastPlay[name] < s[3] then return end
	lastPlay[name] = now
	M.played[name] = (M.played[name] or 0) + 1
	M.lastSound = name
	pcall(Spring.PlaySoundFile, s[1], s[2], "ui")
end

-- the power-ups of the own team: "index:seconds of cooldown:seconds it still works" (powerups.lua A.publish); a new index = picked up; the time it works going up from 0, or the cooldown
-- going up from 0 while it did not work (Repair has no time) = used
local abil = {}
function M.watchAbilities(rule)
	if Spring.GetSpectatingState() then return end
	local raw = tostring(Spring.GetTeamRulesParam(Spring.GetMyTeamID(), rule) or "")
	local now = {}
	for i, c, a in raw:gmatch("(%d+):(%d+):(%d+)") do now[tonumber(i)] = { tonumber(c), tonumber(a) } end
	local old = abil[rule]
	if old then
		for i, v in pairs(now) do
			local o = old[i]
			if not o then
				M.play("pickup")
			elseif (o[2] == 0 and v[2] > 0) or (o[1] == 0 and o[2] == 0 and v[1] > 0) then
				M.play("use" .. i)
			end
		end
	end
	abil[rule] = now
end

local lastNote
function M.watchNote()
	local f = M.note()
	if f and lastNote and f ~= lastNote then M.play("bonus") end
	lastNote = f or lastNote or 0
end

local function shieldLeft(id)
	local untilF = id and Spring.ValidUnitID(id) and Spring.GetUnitRulesParam(id, "ledShield") or 0
	return math.max(0, (untilF or 0) - Spring.GetGameFrame())
end
M.shieldLeft = shieldLeft

-- the note of a team (default: the own one): frame and text, or nil
function M.note(team)
	local raw = tostring(Spring.GetTeamRulesParam(team or Spring.GetMyTeamID(), "ledNote") or "")
	local f, text = raw:match("^(%d+)|(.*)$")
	if not f then return nil end
	return tonumber(f), text
end

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
