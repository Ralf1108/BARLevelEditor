function widget:GetInfo() return { name = "zz teams", desc = "test only: plays through the teams page T and the alliances", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_teams.lua: works page T and the right click menu of the team buttons through WG.LevelEditorWidget
-- and logs "[zzar]" lines (the prefix is the same as in the Arena test). One step per game frame number; ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local tm, saveLevel, loadLevel, td
local function ok(cond) return cond and "OK" or "WRONG" end

local function allRects()
	local out = {}
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then
			for _, r in ipairs(v) do
				if type(r) == "table" and r.x1 then out[#out + 1] = r end
			end
		end
	end
	return out
end
local function rect(pred)
	for _, r in ipairs(allRects()) do
		if pred(r) then return r end
	end
end
local function click(r, button)
	if not r then log("NO BUTTON") return end
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, button or 1)
	W():MouseRelease(x, y, button or 1)
end
local function pageRect(kind, team)
	local _, content = W():DebugLayout()
	for _, r in ipairs((tm.layout(content))) do
		if r.kind == kind and (team == nil or r.team == team) then return r end
	end
end
local function menuItem(group)
	for _, r in ipairs(tm.menuRects() or {}) do
		if r.value == group then return r end
	end
end
local function allied(a, b) return Spring.AreTeamsAllied(a, b) end

local steps = {}
steps[40] = function()
	local save
	tm, save, loadLevel, td = W():DebugTeams()
	saveLevel = save
	log("teams module", tostring(tm))
	log("defaults: team 0 human, team 1 NullAI, no groups:", ok(tm.row(0).ai == "" and tm.row(1).ai == "NullAI" and tm.group(0) == 0), "allied 0/1:", tostring(allied(0, 1)))
	click(rect(function(r) return r.kind == "teams" end)) -- button T
	log("page T open, rows:", tostring(pageRect("tmkind", 3) ~= nil))
	Spring.SendCommands("screenshot png")
end

steps[80] = function()
	-- alliance of team 1 through the page: click the Alliance cell, then the color 3 in the menu
	click(pageRect("tmgroup", 1))
	log("menu open after click on the Alliance cell:", ok(tm.menu ~= nil))
	click(menuItem(3))
	log("team 1 in group 3:", ok(tm.group(1) == 3))
	-- alliance of team 0 through the right click on the team button of the strip
	local r0 = rect(function(r) return r.team == 0 and type(r.team) == "number" end)
	click(r0, 3)
	log("menu open after the right click on team 0:", ok(tm.menu ~= nil and tm.menu.team == 0))
	click(menuItem(3))
	log("team 0 in group 3:", ok(tm.group(0) == 3))
end

steps[140] = function()
	log("allied 0/1 (same group):", ok(allied(0, 1) == true), " allied 0/2:", ok(allied(0, 2) == false))
	-- human or AI, the AI name, the start resources
	click(pageRect("tmkind", 2))
	log("team 2 is a human now:", ok(tm.row(2).ai == ""))
	click(pageRect("tmai", 3))
	log("list of the AIs open:", ok(tm.drop ~= nil))
	for _, r in ipairs(tm.dropRects() or {}) do
		if r.value == "BARb" then click(r) end
	end
	log("team 3 has BARb:", ok(tm.row(3).ai == "BARb"))
	click(pageRect("tmfield", 0))
	for _, ch in ipairs({ "5", "0", "0", "0" }) do tm.text(ch) end
	tm.key(13)
	log("team 0 start metal 5000:", ok(tm.row(0).metal == 5000), tm.row(0).metal)
	local player = tm.player()
	log("player / enemy for Tower Defense:", player, tm.enemy(player), ok(player == 0 and tm.enemy(player) == 1))
	Spring.SendCommands("screenshot png")
end

steps[200] = function()
	saveLevel("zz_teams_test", false)
	log("saved")
	-- change everything, then load: the saved state comes back, the alliances are applied again
	tm.setGroup(0, 0)
	tm.setGroup(1, 0)
	tm.data[1].metal = 7
	tm.data[3].ai = "NullAI"
end

steps[260] = function()
	log("after the changes: allied 0/1:", ok(allied(0, 1) == false))
	loadLevel(nil, nil, { "zz_teams_test" })
	log("load sent")
end

steps[400] = function()
	log("loaded: groups", tm.group(0), tm.group(1), ok(tm.group(0) == 3 and tm.group(1) == 3), "metal", tm.row(0).metal, ok(tm.row(0).metal == 5000), "team 3 AI", tm.row(3).ai, ok(tm.row(3).ai == "BARb"), "team 2 human", ok(tm.row(2).ai == ""))
	log("allied 0/1 after the load:", ok(allied(0, 1) == true))
	log("END")
	Spring.SendCommands("quitforce")
end

local done = {}
function widget:Update()
	local f0 = Spring.GetGameFrame()
	local keys = {}
	for k in pairs(steps) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if k <= f0 and not done[k] then
			done[k] = true
			local ok2, err = pcall(steps[k])
			if not ok2 then log("TEST ERROR at", k, tostring(err)) end
			break
		end
	end
end
