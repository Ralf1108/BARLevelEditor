function widget:GetInfo() return { name = "zz nocloak", desc = "test only: a unit that can cloak does not cloak by itself in Evolution", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Widget zz_nocloak.lua (one instance, speed 10): the cheat command gives the own team a Gremlin (it can cloak); at frame 200 the
-- order "cloak on" is sent to it and at frame 260 its states are logged: the cloak state must stay 0 and the unit must not be cloaked. Lines "[zznocloak]". Ends at frame 400.
local function log(...) Spring.Echo("[zznocloak] " .. table.concat({ ... }, " ")) end
local function gremlin()
	for _, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
		if UnitDefs[Spring.GetUnitDefID(id)].name == "armgremlin" then return id end
	end
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10", "cheat 1") end
	if f == 60 then Spring.SendCommands("give 1 armgremlin " .. Spring.GetMyTeamID()) end
	if f == 200 then
		local id = gremlin()
		log("gremlin", tostring(id))
		if id then
			local st = Spring.GetUnitStates(id)
			log("before: cloak state", tostring(st and st.cloak))
			Spring.GiveOrderToUnit(id, CMD.CLOAK, { 1 }, 0)
		end
	end
	if f == 260 then
		local id = gremlin()
		if id then
			local st = Spring.GetUnitStates(id)
			log("after the order: cloak state", tostring(st and st.cloak), "cloaked", tostring(Spring.GetUnitIsCloaked(id)))
		end
	end
	if f == 400 then Spring.SendCommands("quitforce") end
end
