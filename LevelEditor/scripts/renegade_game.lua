-- Renegade (synchronized part), a planned game mode of LAN Play: every human player steers one original unit in the first person. Active only with the
-- game option lanrenegade=1. Proof of concept 2: every team with a human player and a commander gets a Peewee (armpw) instead; the game widget renegade.lua
-- sends the view and the keys ("ren|<yaw degrees>|<pitch degrees>|<keys>|<fire>|<x>|<y>|<z>|<unit>", keys: W 1, A 2, S 4, D 8; x y z the point under the crosshair, unit the enemy there or -1); this gadget moves the unit with ordinary
-- move orders (no MoveCtrl) toward a point in the wished direction and stops it when no key is down.
-- While fire is 1 the unit gets the point (or the enemy unit) as its target (Spring.SetUnitTarget, user target), so its own weapon, turret, reload and damage
-- apply; its fire state is hold fire: it shoots only at what the player aims at. Test only: game option lanrenotest=1 and "ren|test|1" put an enemy
-- Peewee (hold fire) 150 Elmo in front of the unit. 
-- Game option lanrenebots=<n>: n computer Peewees of the first team without a human walk around and fight the players (a lost one comes back after 5 s),
-- lanrenedebug=1: the player may turn into another unit ("ren|unit|<unit name>", units with a weapon: also aircraft, ships (they lie on the land: for the tests), turrets). A player's unit that is lost comes back after 3 s at a place far from
-- the enemies. Team rules parameter renUnit (public): the unit of the team (0 = none). Spec: specs/renegade.md.
function gadget:GetInfo()
	return {
		name = "Renegade",
		desc = "LAN Play game mode: one unit per human, steered in the first person",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local opt = (Spring.GetModOptions() or {}).lanrenegade
if opt ~= "1" and opt ~= 1 then
	return false -- not a Renegade game
end

if not gadgetHandler:IsSyncedCode() then
	return false -- everything is synchronized; the view is the job of the widget renegade.lua
end

local START_UNIT = "armpw"
local STEP = 200 -- Elmo: how far ahead of the unit the move order points
local REISSUE = 10 -- frames: a move order is given again after that time while a key is down
local TURN = 6 -- degrees: the order is given again at once when the wished direction turned by more than that

local TEST = (Spring.GetModOptions() or {}).lanrenotest == "1"
local AIM_EVERY = 3 -- frames: the target is given again (a move order may drop it)
local ENERGY_START, ENERGY_STORE, ENERGY_INCOME = 200000, 200000, 5000 -- energy of a player: at the start, the storage, and the income per second (shots cost energy)
local energyInit = {}
local MO = Spring.GetModOptions() or {}
local DEBUG = MO.lanrenedebug == "1"
local BOTS = math.max(0, math.min(30, tonumber(MO.lanrenebots) or 0))
local RESPAWN = 150 -- frames until a player's unit comes back (5 s; the widget counts down, team rules parameter renRespawn = the frame)
local lastPos = {} -- team -> where its unit was lost (when no place is found, e.g. for a ship on land)
local BOT_RESPAWN = 150
local turnInto -- (defined below: the debug message of RecvLuaMsg needs it)
local units = {} -- team -> unit id
local kind = {} -- team -> unit definition name of the player's unit (a lost unit comes back as the same one)
local due = {} -- team -> frame at which the unit comes back
local bots, botDue, botTeam = {}, {}, nil -- bots: unit id -> true; botDue: frames at which a lost one comes back
local input = {} -- team -> { yaw, pitch, keys, fire, last = { frame, yaw, keys }, moving }

local function sign(n) return n > 0 and 1 or (n < 0 and -1 or 0) end

-- the direction of the keys in the world: forward (sin yaw, cos yaw) on x / z, right (-cos yaw, sin yaw)
local function wish(inp)
	local k = inp.keys
	local f = (k % 2 >= 1 and 1 or 0) - (math.floor(k / 4) % 2 >= 1 and 1 or 0)
	local r = (math.floor(k / 8) % 2 >= 1 and 1 or 0) - (math.floor(k / 2) % 2 >= 1 and 1 or 0)
	if f == 0 and r == 0 then return nil end
	local y = math.rad(inp.yaw)
	local sx, cz = math.sin(y), math.cos(y)
	local dx, dz = sx * f + (-cz) * r, cz * f + sx * r
	local l = math.sqrt(dx * dx + dz * dz)
	return dx / l, dz / l
end

-- An aircraft stays in the air for good: fly mode (idle mode 0) from the first key on, it never lands by itself. Its height is changed only by Space and Ctrl (lift).
local IDLEMODE = CMD.IDLEMODE or 145
local function fixedGunship(ud)
	if not (ud.canFly and (ud.isHoveringAirUnit or ud.hoverAttack)) then return false end
	for _, wp in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		if wd and not wd.turret and wd.type ~= "AircraftBomb" and (tonumber(wd.range) or 0) > 0 then return true end
	end
	return false
end
local function flyer(u)
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	return ud and ud.canFly
end
local CRUISE_ALT -- (filled in the block WEAPON_BUTTONS below: the highest height above the ground of an aircraft, column Cruise altitude of the table)

-- The height of an aircraft that flies (gunships hover where they are): Space raises it, Ctrl lowers it (LIFT_RATE Elmo a frame, between MIN_ALT and MAX_ALT above the
-- ground). The height is the flying height the move type wants (Spring.MoveCtrl.SetGunshipMoveTypeData / SetAirMoveTypeData "wantedHeight"); a landed aircraft takes off.
local LIFT_RATE, MIN_ALT, MAX_ALT, DOWN_SPEED, TAKEOFF_ALT = 4, 4, 1000, 2.3, 400
-- the highest height of an aircraft: its cruise altitude (column Cruise altitude used of the table; a unit that is not in it: 3 times the cruiseAltitude of its definition); never over MAX_ALT
local function maxAlt(u)
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	local v = ud and ((CRUISE_ALT and CRUISE_ALT[(ud.name:gsub("_scav$", ""))]) or (tonumber(ud.cruiseAltitude) or 0) * 3)
	return math.max(MIN_ALT + 20, math.min(MAX_ALT, (v and v > 0) and v or 660))
end
local LAND_HOLD = 60 -- frames: the lower key held at the bottom (2 s) lands the aircraft
-- (the height the move type reaches is not the height asked for: it hovers about 100 Elmo higher; the difference is measured whenever the aircraft is not climbing or sinking
-- and taken off from what is asked for, so the real height is the wished one)
local function applyHeight(u, inp)
	local cmd = math.max(0, inp.alt - (inp.off or 100))
	inp.cmd = cmd
	local mc = Spring.MoveCtrl
	if mc.SetGunshipMoveTypeData then pcall(mc.SetGunshipMoveTypeData, u, "wantedHeight", cmd) end
	if mc.SetAirMoveTypeData then pcall(mc.SetAirMoveTypeData, u, "wantedHeight", cmd) end
end

-- A gunship with fixed guns looks where the player looks (its yaw follows the view) and moves in any direction with its nose toward the view: forward, backward, to the side.
-- The move type turns the aircraft toward the way it flies, so its turn rate is set to 0 (SetGunshipMoveTypeData "turnRate" and "maxRudder"; measured: the nose then stays
-- where it is while the unit flies backward at full speed) and the heading is set here every frame (Spring.SetUnitDirection, horizontal).
local function faceView(team, f)
	local u, inp = units[team], input[team]
	if not u or not inp or not inp.aimed or not Spring.ValidUnitID(u) then return end
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	if not ud or not fixedGunship(ud) then return end
	if inp.turnLockUnit ~= u then
		inp.turnLockUnit = u
		local mc = Spring.MoveCtrl
		for _, key in ipairs({ "turnRate", "maxRudder" }) do pcall(mc.SetGunshipMoveTypeData, u, key, 0) end
		if TEST then Spring.Echo("[Renegade] heading locked to the view for " .. ud.name) end
	end
	local yaw = math.rad(inp.yaw)
	Spring.SetUnitDirection(u, math.sin(yaw), 0, math.cos(yaw))
end

local function lift(team, f)
	local u, inp = units[team], input[team]
	if not u or not inp or not Spring.ValidUnitID(u) then return end
	if inp.keys % 32 > 0 and inp.takeoffUnit ~= u and flyer(u) then -- (the lower key alone does not take off)
		-- the first key of an aircraft that stands on the ground: it takes off once, up to TAKEOFF_ALT; from then on only Space and Ctrl change the height
		inp.takeoffUnit = u
		inp.landed = false
		local x, y, z = Spring.GetUnitPosition(u)
		if y - Spring.GetGroundHeight(x, z) < 25 then
			inp.altUnit, inp.alt = u, math.min(TAKEOFF_ALT, maxAlt(u))
			applyHeight(u, inp)
			Spring.GiveOrderToUnit(u, IDLEMODE, { 0 }, 0)
			Spring.GiveOrderToUnit(u, CMD.MOVE, { x, y, z }, 0)
			if TEST then Spring.Echo(string.format("[Renegade] takeoff: wanted height %d", inp.alt)) end
		end
	end
	if inp.alt and inp.altUnit == u and inp.cmd and f % 10 == 0 then
		local x, y, z = Spring.GetUnitPosition(u)
		local _, vy = Spring.GetUnitVelocity(u)
		if vy and math.abs(vy) < 0.1 and y - Spring.GetGroundHeight(x, z) > 40 then
			local off = (y - Spring.GetGroundHeight(x, z)) - inp.cmd
			if math.abs(off - (inp.off or 100)) > 6 then
				inp.off = off
				applyHeight(u, inp) -- (the aircraft settles at the wished height)
				if TEST then Spring.Echo(string.format("[Renegade] height offset measured %.0f, asked for %.0f", off, inp.cmd)) end
			end
		end
	end
	local up, down = inp.keys % 32 >= 16, inp.keys % 64 >= 32
	if not (up or down) then
		if inp.lifting and Spring.ValidUnitID(u) then
			-- the key is let go: hold the height it has now (the move type would climb on to the old wanted height and beyond)
			inp.lifting = false
			local x, y, z = Spring.GetUnitPosition(u)
			inp.alt = math.max(MIN_ALT, math.min(maxAlt(u), y - Spring.GetGroundHeight(x, z)))
			applyHeight(u, inp)
			inp.holdUntil = f + 45 -- (and the vertical speed is taken away for 1.5 s: the move type lags and overshoots)
		end
		if inp.holdUntil and f < inp.holdUntil and Spring.ValidUnitID(u) then
			local vx, vy, vz = Spring.GetUnitVelocity(u)
			if vx then Spring.SetUnitVelocity(u, vx, 0, vz) end
		end
		return
	end
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	if not ud or not ud.canFly then return end
	inp.lifting = true
	local x, y, z = Spring.GetUnitPosition(u)
	if inp.altUnit ~= u then inp.altUnit, inp.alt = u, nil end
	inp.alt = inp.alt or math.max(MIN_ALT, y - Spring.GetGroundHeight(x, z))
	local before = inp.alt
	inp.alt = math.max(MIN_ALT, math.min(maxAlt(u), inp.alt + (up and LIFT_RATE or 0) - (down and LIFT_RATE or 0)))
	local mc = Spring.MoveCtrl
	if down and y - Spring.GetGroundHeight(x, z) > MIN_ALT + 5 then
		-- the move type lets an aircraft sink only slowly: push it down (about 70 Elmo a second)
		local vx, vy, vz = Spring.GetUnitVelocity(u)
		if vx then Spring.SetUnitVelocity(u, vx, math.min(vy, -DOWN_SPEED), vz) end
	end
	applyHeight(u, inp)
	-- all the way down and the lower key held on: it lands (and takes off again with the next key)
	if down and not inp.landed and y - Spring.GetGroundHeight(x, z) <= MIN_ALT + 12 then
		inp.landHold = (inp.landHold or 0) + 1
		if inp.landHold >= LAND_HOLD then
			Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
			Spring.GiveOrderToUnit(u, IDLEMODE, { 1 }, 0)
			inp.landHold, inp.lifting, inp.takeoffUnit, inp.alt, inp.moving, inp.landed = 0, false, nil, nil, false, true
			if TEST then Spring.Echo("[Renegade] landing") end
			return
		end
	else
		inp.landHold = 0
	end
	if up and (y - Spring.GetGroundHeight(x, z)) < 20 and not inp.moving then
		Spring.GiveOrderToUnit(u, IDLEMODE, { 0 }, 0)
		Spring.GiveOrderToUnit(u, CMD.MOVE, { x, y, z }, 0) -- (a landed aircraft takes off)
	end
	if TEST and (inp.liftLogged or 0) < 3 and inp.alt ~= before then inp.liftLogged = (inp.liftLogged or 0) + 1; Spring.Echo(string.format("[Renegade] lift: wanted height %.0f (now %.0f)", inp.alt, y - Spring.GetGroundHeight(x, z))) end
end

local function steer(team, f)
	local u, inp = units[team], input[team]
	if not u or not inp or not Spring.ValidUnitID(u) then return end
	local dx, dz = wish(inp)
	if not dx then
		if inp.moving then
			Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
			inp.moving = false
			if flyer(u) then
				Spring.GiveOrderToUnit(u, IDLEMODE, { 0 }, 0) -- (stay up)
			end
		end
		return
	end
	if not inp.moving and flyer(u) then Spring.GiveOrderToUnit(u, IDLEMODE, { 0 }, 0) end
	local l = inp.last
	local turned = math.abs(((inp.yaw - l.yaw + 180) % 360) - 180) > TURN
	if inp.moving and not turned and l.keys == inp.keys % 16 and f - l.frame < REISSUE then return end
	local x, _, z = Spring.GetUnitPosition(u)
	local tx = math.max(16, math.min(Game.mapSizeX - 16, x + dx * STEP))
	local tz = math.max(16, math.min(Game.mapSizeZ - 16, z + dz * STEP))
	Spring.GiveOrderToUnit(u, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	inp.moving = true
	l.frame, l.yaw, l.keys = f, inp.yaw, inp.keys % 16
end

-- The shot (like in a shooter: never a "target"): three mouse buttons, each fires a group of the unit's weapons (slotsFor): the left button the short range
-- weapons, the right button the long range ones, the middle button the missiles. Each weapon gets the point the player aims at as its target
-- (Spring.SetUnitTarget with a position, user target, weapon number), shortened along the line from the unit to the point to the reach of that weapon, so it fires
-- toward the crosshair even where nothing is in reach. The enemy unit under the crosshair is not chosen as a target, except for anti-air weapons (they can only
-- hit what flies: the player looks at the aircraft). A message sets the target at once; it is renewed every AIM_EVERY frames; releasing the buttons clears it.
-- The groups: the weapons with the same weapon definition are one group (they fire together). Missiles (missile launchers, starburst, torpedoes, and the
-- anti-air weapons) and all others are sorted by range. With both kinds: the shortest weapon of the others on the left button, the rest of the others on the right
-- button (the right button takes the missiles when there is no second one), the missiles on the middle button. With only one kind: the shortest on the left,
-- the next on the right, all further ones on the middle button.
-- BEGIN WEAPONS (made by test-data/tools/renegade_weapons.py from game-modes/renegade_weapons.csv: change the table, not this block)
local WEAPON_BUTTONS = {
	armaak = { L = { 2 }, R = { 1 }, M = {  } },
	armaas = { L = { 3 }, R = { 2 }, M = {  } },
	armah = { L = { 2 }, R = {  }, M = {  } },
	armamb = { L = { 1 }, R = { 2 }, M = {  } },
	armamd = { L = {  }, R = {  }, M = {  } },
	armamph = { L = { 1 }, R = { 2 }, M = {  } },
	armanac = { L = { 1 }, R = {  }, M = {  } },
	armanavaldefturret = { L = { 2 }, R = { 1 }, M = {  } },
	armanni = { L = { 1 }, R = {  }, M = {  } },
	armannit3 = { L = { 1 }, R = {  }, M = {  } },
	armantiship = { L = {  }, R = {  }, M = {  } },
	armart = { L = { 1 }, R = {  }, M = {  } },
	armassimilator = { L = { 1 }, R = {  }, M = {  } },
	armatl = { L = { 1 }, R = {  }, M = {  } },
	armbanth = { L = { 1 }, R = { 2 }, M = { 3 } },
	armbats = { L = { 1, 2 }, R = {  }, M = {  } },
	armbeamer = { L = { 1 }, R = {  }, M = {  } },
	armblade = { L = { 1 }, R = {  }, M = {  } },
	armbotrail = { L = { 1 }, R = {  }, M = {  } },
	armbrawl = { L = { 1 }, R = {  }, M = {  } },
	armbrtha = { L = { 1 }, R = {  }, M = {  } },
	armbull = { L = { 1 }, R = {  }, M = {  } },
	armcarry = { L = {  }, R = {  }, M = {  } },
	armcir = { L = { 1 }, R = {  }, M = {  } },
	armclaw = { L = { 1 }, R = {  }, M = {  } },
	armcom = { L = { 1 }, R = { 3 }, M = { 2 } },
	armcomboss = { L = { 1 }, R = { 3 }, M = { 2 } },
	armcomcon = { L = { 1 }, R = { 3 }, M = { 2 } },
	armcomlvl10 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl2 = { L = { 1 }, R = { 3 }, M = { 2 } },
	armcomlvl3 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl4 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl5 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl6 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl7 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl8 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomlvl9 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armcomnew = { L = { 1 }, R = { 3 }, M = { 2 } },
	armcroc = { L = { 1 }, R = { 2 }, M = {  } },
	armcrus = { L = { 2 }, R = { 1 }, M = { 3 } },
	armdecade = { L = { 1, 2 }, R = {  }, M = {  } },
	armdecadet3 = { L = { 1, 2 }, R = {  }, M = {  } },
	armdecom = { L = { 2 }, R = { 3 }, M = { 1 } },
	armdecomlvl10 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl2 = { L = { 1 }, R = { 3 }, M = { 2 } },
	armdecomlvl3 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl4 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl5 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl6 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl7 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl8 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdecomlvl9 = { L = { 6 }, R = { 3 }, M = { 1, 2, 4, 5 } },
	armdfly = { L = { 1 }, R = {  }, M = {  } },
	armdl = { L = { 1 }, R = {  }, M = {  } },
	armdrone = { L = { 1 }, R = {  }, M = {  } },
	armdronecarry = { L = { 2 }, R = {  }, M = {  } },
	armdronecarryland = { L = {  }, R = {  }, M = {  } },
	armdroneold = { L = { 1 }, R = {  }, M = {  } },
	armemp = { L = { 1 }, R = {  }, M = {  } },
	armepoch = { L = { 2, 4, 5 }, R = { 1, 3 }, M = { 6, 7 } },
	armexcalibur = { L = { 1 }, R = {  }, M = {  } },
	armfast = { L = { 1 }, R = {  }, M = {  } },
	armfav = { L = { 1 }, R = {  }, M = {  } },
	armfboy = { L = { 1 }, R = {  }, M = {  } },
	armfepocht4 = { L = { 2, 4, 5 }, R = { 1, 3 }, M = { 6, 7 } },
	armferret = { L = { 1 }, R = {  }, M = {  } },
	armfflak = { L = { 1 }, R = {  }, M = {  } },
	armfgate = { L = {  }, R = {  }, M = {  } },
	armfhlt = { L = { 1 }, R = {  }, M = {  } },
	armfido = { L = { 1 }, R = {  }, M = {  } },
	armfig = { L = { 1 }, R = {  }, M = {  } },
	armflak = { L = { 1 }, R = {  }, M = {  } },
	armflash = { L = { 1 }, R = {  }, M = {  } },
	armflea = { L = { 1 }, R = {  }, M = {  } },
	armfmine3 = { L = {  }, R = {  }, M = {  } },
	armfrock = { L = { 1 }, R = {  }, M = {  } },
	armfrt = { L = { 1 }, R = {  }, M = {  } },
	armgate = { L = {  }, R = {  }, M = {  } },
	armgatet3 = { L = {  }, R = {  }, M = {  } },
	armgplat = { L = { 1 }, R = {  }, M = {  } },
	armgremlin = { L = { 1 }, R = {  }, M = {  } },
	armguard = { L = { 1 }, R = { 2 }, M = {  } },
	armham = { L = { 1 }, R = {  }, M = {  } },
	armhawk = { L = { 1 }, R = {  }, M = {  } },
	armhlt = { L = { 1 }, R = {  }, M = {  } },
	armjanus = { L = { 1, 2 }, R = {  }, M = {  } },
	armjeth = { L = { 1 }, R = {  }, M = {  } },
	armjuno = { L = {  }, R = {  }, M = {  } },
	armkam = { L = { 1 }, R = {  }, M = {  } },
	armkraken = { L = { 1 }, R = {  }, M = {  } },
	armlance = { L = { 1 }, R = {  }, M = {  } },
	armlatnk = { L = { 1 }, R = { 2 }, M = {  } },
	armliche = { L = { 1 }, R = {  }, M = {  } },
	armlichet4 = { L = { 1 }, R = {  }, M = {  } },
	armllt = { L = { 1 }, R = {  }, M = {  } },
	armlship = { L = { 1 }, R = { 2 }, M = {  } },
	armlun = { L = { 1 }, R = { 2 }, M = {  } },
	armlunchbox = { L = { 1 }, R = {  }, M = {  } },
	armlwall = { L = { 1 }, R = {  }, M = {  } },
	armmanni = { L = { 1 }, R = {  }, M = {  } },
	armmar = { L = { 1 }, R = { 2 }, M = {  } },
	armmart = { L = { 1 }, R = {  }, M = {  } },
	armmav = { L = { 1 }, R = {  }, M = {  } },
	armmeatball = { L = { 1 }, R = { 2 }, M = {  } },
	armmercury = { L = { 1 }, R = {  }, M = {  } },
	armmerl = { L = { 1 }, R = {  }, M = {  } },
	armmh = { L = { 1 }, R = {  }, M = {  } },
	armmine1 = { L = {  }, R = {  }, M = {  } },
	armmine2 = { L = {  }, R = {  }, M = {  } },
	armmine3 = { L = {  }, R = {  }, M = {  } },
	armminivulc = { L = { 1 }, R = {  }, M = {  } },
	armmlv = { L = { 1 }, R = {  }, M = {  } },
	armmship = { L = { 1 }, R = { 2 }, M = {  } },
	armnavaldefturret = { L = { 1 }, R = {  }, M = {  } },
	armpb = { L = { 1 }, R = {  }, M = {  } },
	armpincer = { L = { 1 }, R = {  }, M = {  } },
	armpnix = { L = { 1 }, R = {  }, M = {  } },
	armprowl = { L = { 1 }, R = { 2 }, M = {  } },
	armpship = { L = { 1, 2 }, R = {  }, M = {  } },
	armpshipt3 = { L = { 1, 2 }, R = {  }, M = {  } },
	armpt = { L = { 1 }, R = { 2 }, M = {  } },
	armptt2 = { L = { 1, 2 }, R = { 3 }, M = {  } },
	armpw = { L = { 1 }, R = {  }, M = {  } },
	armpwt4 = { L = { 1 }, R = {  }, M = {  } },
	armrattet4 = { L = { 1 }, R = {  }, M = {  } },
	armraz = { L = { 1 }, R = {  }, M = {  } },
	armrl = { L = { 1 }, R = {  }, M = {  } },
	armrock = { L = { 1 }, R = {  }, M = {  } },
	armroy = { L = { 1 }, R = { 2 }, M = {  } },
	armsaber = { L = { 1 }, R = {  }, M = {  } },
	armsam = { L = { 2 }, R = { 1 }, M = {  } },
	armsb = { L = { 1 }, R = {  }, M = {  } },
	armscab = { L = {  }, R = {  }, M = {  } },
	armseadragon = { L = { 1 }, R = { 2 }, M = {  } },
	armseap = { L = { 1 }, R = {  }, M = {  } },
	armserp = { L = { 1, 2 }, R = {  }, M = {  } },
	armserpt3 = { L = { 1 }, R = { 2, 3, 4, 5 }, M = {  } },
	armsfig = { L = { 1 }, R = {  }, M = {  } },
	armsfig2 = { L = { 1 }, R = {  }, M = {  } },
	armsh = { L = { 1 }, R = {  }, M = {  } },
	armshockwave = { L = { 1 }, R = {  }, M = {  } },
	armsilo = { L = { 1 }, R = {  }, M = {  } },
	armsnipe = { L = { 1 }, R = {  }, M = {  } },
	armspid = { L = { 1 }, R = {  }, M = {  } },
	armsptk = { L = { 1 }, R = {  }, M = {  } },
	armsptkt4 = { L = { 1 }, R = {  }, M = {  } },
	armspy = { L = {  }, R = {  }, M = {  } },
	armstil = { L = { 1 }, R = {  }, M = {  } },
	armstump = { L = { 1 }, R = {  }, M = {  } },
	armsub = { L = { 1 }, R = {  }, M = {  } },
	armsubk = { L = { 1 }, R = {  }, M = {  } },
	armtdrone = { L = { 1 }, R = {  }, M = {  } },
	armthor = { L = { 3, 4 }, R = { 1 }, M = { 2 } },
	armthund = { L = { 1 }, R = {  }, M = {  } },
	armthundt4 = { L = { 1 }, R = {  }, M = {  } },
	armtl = { L = { 1 }, R = {  }, M = {  } },
	armtorps = { L = { 1 }, R = {  }, M = {  } },
	armtrident = { L = { 2 }, R = {  }, M = {  } },
	armvader = { L = { 2 }, R = {  }, M = {  } },
	armvadert4 = { L = { 2 }, R = { 1 }, M = {  } },
	armvang = { L = { 1 }, R = { 2 }, M = {  } },
	armvulc = { L = { 1 }, R = {  }, M = {  } },
	armwar = { L = { 1 }, R = {  }, M = {  } },
	armyork = { L = { 2 }, R = {  }, M = {  } },
	armzapper = { L = { 1 }, R = {  }, M = {  } },
	armzeus = { L = { 1 }, R = {  }, M = {  } },
	coraak = { L = { 2 }, R = { 1 }, M = {  } },
	corah = { L = { 2 }, R = {  }, M = {  } },
	corak = { L = { 1 }, R = {  }, M = {  } },
	corakt4 = { L = { 1 }, R = {  }, M = {  } },
	coramph = { L = { 2 }, R = { 1 }, M = {  } },
	coranavaldefturret = { L = { 2 }, R = { 1 }, M = {  } },
	corantiship = { L = {  }, R = {  }, M = {  } },
	corape = { L = { 1 }, R = {  }, M = {  } },
	corarch = { L = { 3 }, R = { 2 }, M = {  } },
	coratl = { L = { 1 }, R = {  }, M = {  } },
	corban = { L = { 1 }, R = {  }, M = {  } },
	corbats = { L = { 4 }, R = { 1, 2, 3 }, M = {  } },
	corbhmth = { L = { 1, 2, 3 }, R = {  }, M = {  } },
	corblackhy = { L = { 2, 4, 5 }, R = { 1 }, M = { 3, 6 } },
	corbuzz = { L = { 1 }, R = {  }, M = {  } },
	corbw = { L = { 1 }, R = {  }, M = {  } },
	corcan = { L = { 1 }, R = {  }, M = {  } },
	corcarry = { L = {  }, R = {  }, M = {  } },
	corcat = { L = { 1 }, R = {  }, M = {  } },
	corcom = { L = { 1 }, R = { 3 }, M = { 2 } },
	corcomboss = { L = { 1 }, R = { 3 }, M = { 2 } },
	corcomcon = { L = { 1 }, R = { 3 }, M = { 2 } },
	corcomlvl10 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcomlvl2 = { L = { 1 }, R = { 3 }, M = { 2 } },
	corcomlvl3 = { L = { 1 }, R = { 3 }, M = { 2, 5 } },
	corcomlvl4 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcomlvl5 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcomlvl6 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcomlvl7 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcomlvl8 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcomlvl9 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	corcrash = { L = { 1 }, R = {  }, M = {  } },
	corcrus = { L = { 2 }, R = { 1 }, M = { 3 } },
	corcrw = { L = { 1 }, R = { 2, 3 }, M = {  } },
	corcrwh = { L = { 1 }, R = { 3, 4, 5, 6 }, M = { 2 } },
	corcrwt4 = { L = { 1 }, R = { 3, 4, 5, 6 }, M = { 2 } },
	corcut = { L = { 1 }, R = {  }, M = {  } },
	cordeadeye = { L = { 1 }, R = {  }, M = {  } },
	cordecom = { L = { 2 }, R = { 3 }, M = { 1 } },
	cordecomlvl10 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordecomlvl2 = { L = { 1 }, R = { 3 }, M = { 2 } },
	cordecomlvl3 = { L = { 1 }, R = { 3 }, M = { 2, 5 } },
	cordecomlvl4 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordecomlvl5 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordecomlvl6 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordecomlvl7 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordecomlvl8 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordecomlvl9 = { L = { 1 }, R = { 3 }, M = { 2, 5, 6 } },
	cordemon = { L = { 1 }, R = { 2 }, M = {  } },
	cordesolator = { L = { 1 }, R = { 2 }, M = {  } },
	cordl = { L = { 1 }, R = {  }, M = {  } },
	cordoom = { L = { 3 }, R = { 2 }, M = { 1 } },
	cordoomt3 = { L = { 3 }, R = { 2 }, M = { 1 } },
	cordrone = { L = { 1 }, R = {  }, M = {  } },
	cordronecarry = { L = { 2 }, R = {  }, M = {  } },
	cordronecarryair = { L = {  }, R = {  }, M = {  } },
	cordroneold = { L = { 1 }, R = {  }, M = {  } },
	cords = { L = { 1 }, R = {  }, M = {  } },
	corenaa = { L = { 1 }, R = {  }, M = {  } },
	corerad = { L = { 1 }, R = {  }, M = {  } },
	coresupp = { L = { 1, 2 }, R = {  }, M = {  } },
	coresuppt3 = { L = { 1, 2 }, R = {  }, M = {  } },
	corexp = { L = { 1 }, R = {  }, M = {  } },
	corfav = { L = { 1 }, R = {  }, M = {  } },
	corfblackhyt4 = { L = { 2, 4, 5 }, R = { 1 }, M = { 3, 6 } },
	corfdoom = { L = { 3 }, R = { 2 }, M = { 1 } },
	corfgate = { L = {  }, R = {  }, M = {  } },
	corfhlt = { L = { 1 }, R = {  }, M = {  } },
	corflak = { L = { 1 }, R = {  }, M = {  } },
	corfmd = { L = {  }, R = {  }, M = {  } },
	corfmine3 = { L = {  }, R = {  }, M = {  } },
	corforge = { L = { 1 }, R = {  }, M = {  } },
	corfrock = { L = { 1 }, R = {  }, M = {  } },
	corfrt = { L = { 1 }, R = {  }, M = {  } },
	corfship = { L = { 1 }, R = { 2 }, M = {  } },
	corftiger = { L = { 1 }, R = {  }, M = {  } },
	corgarp = { L = { 1 }, R = {  }, M = {  } },
	corgate = { L = {  }, R = {  }, M = {  } },
	corgatet3 = { L = {  }, R = {  }, M = {  } },
	corgator = { L = { 1 }, R = {  }, M = {  } },
	corgatreap = { L = { 1 }, R = {  }, M = {  } },
	corgol = { L = { 1 }, R = {  }, M = {  } },
	corgolt4 = { L = { 2, 3 }, R = { 1 }, M = {  } },
	corgplat = { L = { 1 }, R = {  }, M = {  } },
	corhal = { L = { 1 }, R = {  }, M = {  } },
	corhllllt = { L = { 1 }, R = { 2 }, M = { 3, 4 } },
	corhllt = { L = { 2 }, R = { 1 }, M = {  } },
	corhlt = { L = { 1 }, R = {  }, M = {  } },
	corhltfus = { L = { 1 }, R = {  }, M = {  } },
	corhrk = { L = { 1 }, R = {  }, M = {  } },
	corhurc = { L = { 1 }, R = {  }, M = {  } },
	corint = { L = { 1 }, R = {  }, M = {  } },
	corjugg = { L = { 2, 3 }, R = { 1 }, M = { 4 } },
	corjuno = { L = {  }, R = {  }, M = {  } },
	corkarg = { L = { 1 }, R = { 2 }, M = {  } },
	corkarganetht4 = { L = { 1 }, R = { 2 }, M = {  } },
	corkark = { L = { 2 }, R = { 1 }, M = {  } },
	corkorg = { L = { 1 }, R = { 2 }, M = { 3 } },
	corlevlr = { L = { 1 }, R = {  }, M = {  } },
	corllt = { L = { 1 }, R = {  }, M = {  } },
	cormabm = { L = {  }, R = {  }, M = {  } },
	cormadsam = { L = { 1 }, R = {  }, M = {  } },
	cormando = { L = { 1 }, R = {  }, M = {  } },
	cormandot4 = { L = { 1 }, R = { 2 }, M = {  } },
	cormart = { L = { 1 }, R = {  }, M = {  } },
	cormaw = { L = { 1 }, R = {  }, M = {  } },
	cormexp = { L = { 1 }, R = { 2 }, M = {  } },
	cormh = { L = { 1 }, R = {  }, M = {  } },
	cormine1 = { L = {  }, R = {  }, M = {  } },
	cormine2 = { L = {  }, R = {  }, M = {  } },
	cormine3 = { L = {  }, R = {  }, M = {  } },
	cormine4 = { L = {  }, R = {  }, M = {  } },
	corminibuzz = { L = { 1 }, R = {  }, M = {  } },
	cormist = { L = { 2 }, R = { 1 }, M = {  } },
	cormlv = { L = { 1 }, R = {  }, M = {  } },
	cormort = { L = { 1 }, R = {  }, M = {  } },
	cormship = { L = { 1 }, R = { 2 }, M = {  } },
	cormwall = { L = { 1 }, R = {  }, M = {  } },
	cornavaldefturret = { L = { 1 }, R = {  }, M = {  } },
	corobligator = { L = { 2 }, R = { 1 }, M = {  } },
	coronager = { L = { 1 }, R = {  }, M = {  } },
	corparrow = { L = { 1 }, R = {  }, M = {  } },
	corprince = { L = { 2, 3, 4 }, R = { 1 }, M = { 5, 6 } },
	corpship = { L = { 1 }, R = {  }, M = {  } },
	corpt = { L = { 2 }, R = { 1 }, M = {  } },
	corpun = { L = { 1 }, R = { 2 }, M = {  } },
	corpyro = { L = { 1 }, R = {  }, M = {  } },
	corraid = { L = { 1 }, R = {  }, M = {  } },
	correap = { L = { 1 }, R = {  }, M = {  } },
	corrl = { L = { 1 }, R = {  }, M = {  } },
	corroach = { L = {  }, R = {  }, M = {  } },
	corroy = { L = { 1 }, R = { 2 }, M = {  } },
	corsala = { L = { 1 }, R = {  }, M = {  } },
	corsb = { L = { 1 }, R = {  }, M = {  } },
	corscreamer = { L = { 1 }, R = {  }, M = {  } },
	corseal = { L = { 1 }, R = {  }, M = {  } },
	corseap = { L = { 1 }, R = {  }, M = {  } },
	corsent = { L = { 2 }, R = {  }, M = {  } },
	corsentinel = { L = { 2 }, R = {  }, M = {  } },
	corsfig = { L = { 1 }, R = {  }, M = {  } },
	corsfig2 = { L = { 1 }, R = { 2 }, M = {  } },
	corsh = { L = { 1 }, R = {  }, M = {  } },
	corshad = { L = { 1 }, R = {  }, M = {  } },
	corshark = { L = { 1 }, R = {  }, M = {  } },
	corshiva = { L = { 1 }, R = { 2 }, M = {  } },
	corsiegebreaker = { L = { 1 }, R = {  }, M = {  } },
	corsilo = { L = { 1 }, R = {  }, M = {  } },
	corsktl = { L = {  }, R = {  }, M = {  } },
	corslrpc = { L = { 1 }, R = {  }, M = {  } },
	corsnap = { L = { 1 }, R = {  }, M = {  } },
	corsok = { L = { 1 }, R = { 2 }, M = {  } },
	corspy = { L = {  }, R = {  }, M = {  } },
	corssub = { L = { 1 }, R = {  }, M = {  } },
	corstorm = { L = { 1 }, R = {  }, M = {  } },
	corsub = { L = { 1 }, R = {  }, M = {  } },
	corsumo = { L = { 1 }, R = {  }, M = {  } },
	cortdrone = { L = { 1 }, R = {  }, M = {  } },
	cortermite = { L = { 1 }, R = {  }, M = {  } },
	corthermite = { L = { 2 }, R = { 1 }, M = {  } },
	corthud = { L = { 1 }, R = {  }, M = {  } },
	cortitan = { L = { 1 }, R = {  }, M = {  } },
	cortl = { L = { 1 }, R = {  }, M = {  } },
	cortoast = { L = { 1 }, R = { 2 }, M = {  } },
	cortorch = { L = { 1 }, R = {  }, M = {  } },
	cortrem = { L = { 1 }, R = {  }, M = {  } },
	cortron = { L = { 1 }, R = {  }, M = {  } },
	corvamp = { L = { 1 }, R = {  }, M = {  } },
	corveng = { L = { 1 }, R = {  }, M = {  } },
	corves = { L = { 4 }, R = { 1 }, M = { 2, 3 } },
	corvipe = { L = { 1 }, R = {  }, M = {  } },
	corvroc = { L = { 1 }, R = {  }, M = {  } },
	corwolv = { L = { 1 }, R = {  }, M = {  } },
	legaabot = { L = { 1 }, R = {  }, M = {  } },
	legabm = { L = {  }, R = {  }, M = {  } },
	legacluster = { L = { 1 }, R = { 2 }, M = {  } },
	legadvaabot = { L = { 1 }, R = { 2 }, M = {  } },
	legafigdef = { L = { 1 }, R = {  }, M = {  } },
	legah = { L = { 1 }, R = {  }, M = {  } },
	legaheattank = { L = { 1 }, R = {  }, M = {  } },
	legamcluster = { L = { 1 }, R = {  }, M = {  } },
	legamph = { L = { 1 }, R = { 2 }, M = {  } },
	legamphtank = { L = { 1 }, R = {  }, M = {  } },
	leganavalaaturret = { L = { 1 }, R = {  }, M = {  } },
	leganavaldefturret = { L = { 2 }, R = { 1 }, M = {  } },
	leganavaltorpturret = { L = { 1 }, R = {  }, M = {  } },
	leganavyaaship = { L = { 1 }, R = { 2, 3 }, M = {  } },
	leganavyantinukecarrier = { L = {  }, R = {  }, M = {  } },
	leganavyantiswarm = { L = { 1 }, R = { 2 }, M = {  } },
	leganavyartyship = { L = { 2, 3, 4 }, R = { 1 }, M = {  } },
	leganavybattleship = { L = { 3, 4 }, R = { 2 }, M = { 1 } },
	leganavybattlesub = { L = { 1 }, R = {  }, M = {  } },
	leganavycruiser = { L = { 1 }, R = { 2 }, M = {  } },
	leganavyflagship = { L = { 2, 3 }, R = { 4, 5, 6, 7 }, M = {  } },
	leganavyheavysub = { L = { 1 }, R = {  }, M = {  } },
	leganavymissileship = { L = { 1 }, R = { 2 }, M = {  } },
	legapollyon = { L = { 5, 6 }, R = { 1, 2, 3, 4 }, M = { 7, 8, 9, 10 } },
	legapopupdef = { L = { 2, 3 }, R = { 1 }, M = {  } },
	legaskirmtank = { L = { 1 }, R = {  }, M = {  } },
	legaspy = { L = {  }, R = {  }, M = {  } },
	legatorpbomber = { L = { 1, 2 }, R = {  }, M = {  } },
	legavantinuke = { L = {  }, R = {  }, M = {  } },
	legavroc = { L = { 1 }, R = {  }, M = {  } },
	legbal = { L = { 1 }, R = {  }, M = {  } },
	legbar = { L = { 1 }, R = {  }, M = {  } },
	legbart = { L = { 1 }, R = {  }, M = {  } },
	legbastion = { L = { 1 }, R = {  }, M = {  } },
	legbombard = { L = { 1 }, R = {  }, M = {  } },
	legbunk = { L = { 3 }, R = { 2 }, M = {  } },
	legcar = { L = { 1 }, R = {  }, M = {  } },
	legcen = { L = { 1 }, R = {  }, M = {  } },
	legcib = { L = {  }, R = {  }, M = {  } },
	legcluster = { L = { 1 }, R = { 2 }, M = {  } },
	legcom = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomecon = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl10 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl2 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl3 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl4 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl5 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl6 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl7 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl8 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomlvl9 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legcomoff = { L = { 3 }, R = { 1 }, M = { 2, 4 } },
	legcomt2com = { L = { 3 }, R = { 1 }, M = { 2, 4, 5 } },
	legcomt2def = { L = { 3 }, R = { 1 }, M = { 2, 4 } },
	legcomt2off = { L = { 3 }, R = { 1 }, M = { 2, 4 } },
	legctl = { L = { 1 }, R = {  }, M = {  } },
	legdecom = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl10 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl2 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl3 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl4 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl5 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl6 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl7 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl8 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdecomlvl9 = { L = { 1 }, R = { 3 }, M = { 2, 4 } },
	legdeflector = { L = {  }, R = {  }, M = {  } },
	legdrone = { L = { 1 }, R = {  }, M = {  } },
	legdtf = { L = { 1 }, R = {  }, M = {  } },
	legdtl = { L = { 1 }, R = {  }, M = {  } },
	legdtm = { L = { 1 }, R = {  }, M = {  } },
	legdtr = { L = { 1 }, R = {  }, M = {  } },
	legeallterrainmech = { L = { 1 }, R = { 2 }, M = { 4 } },
	legeheatraymech = { L = { 4, 5 }, R = { 2, 3 }, M = { 6 } },
	legeheatraymech_old = { L = { 2, 3, 4, 5 }, R = { 6 }, M = {  } },
	legehovertank = { L = { 1 }, R = { 2, 3, 4 }, M = {  } },
	legelrpcmech = { L = { 1 }, R = {  }, M = {  } },
	legerailtank = { L = { 1, 2, 3 }, R = {  }, M = {  } },
	legeshotgunmech = { L = { 2 }, R = { 3, 4 }, M = {  } },
	legfhive = { L = {  }, R = {  }, M = {  } },
	legfig = { L = { 1 }, R = {  }, M = {  } },
	legflak = { L = { 1 }, R = {  }, M = {  } },
	legfloat = { L = { 2 }, R = { 1 }, M = {  } },
	legfmg = { L = { 1 }, R = {  }, M = {  } },
	legfort = { L = { 3, 4, 5 }, R = { 1, 2 }, M = { 6 } },
	legfortt4 = { L = { 3, 4, 5 }, R = { 1, 2 }, M = { 6 } },
	legfrl = { L = { 1 }, R = {  }, M = {  } },
	leggat = { L = { 1 }, R = {  }, M = {  } },
	leggatet3 = { L = {  }, R = {  }, M = {  } },
	leggob = { L = { 1 }, R = {  }, M = {  } },
	leggobt3 = { L = { 1 }, R = {  }, M = {  } },
	leghades = { L = { 1 }, R = {  }, M = {  } },
	legheavydrone = { L = { 1 }, R = {  }, M = {  } },
	legheavydronesmall = { L = { 1 }, R = {  }, M = {  } },
	leghelios = { L = { 1 }, R = {  }, M = {  } },
	leghive = { L = {  }, R = {  }, M = {  } },
	leghrk = { L = { 1 }, R = {  }, M = {  } },
	leginc = { L = { 1 }, R = {  }, M = {  } },
	leginf = { L = { 1 }, R = {  }, M = {  } },
	leginfestor = { L = { 1 }, R = {  }, M = {  } },
	legionnaire = { L = { 1 }, R = {  }, M = {  } },
	legjav = { L = { 1 }, R = { 2 }, M = {  } },
	legjuno = { L = {  }, R = {  }, M = {  } },
	legkam = { L = { 3 }, R = { 2 }, M = {  } },
	legkark = { L = { 2 }, R = { 1 }, M = {  } },
	legkeres = { L = { 1 }, R = { 2, 3 }, M = {  } },
	leglht = { L = { 1 }, R = {  }, M = {  } },
	leglob = { L = { 1 }, R = {  }, M = {  } },
	leglraa = { L = { 1 }, R = {  }, M = {  } },
	leglrpc = { L = { 1 }, R = {  }, M = {  } },
	leglupara = { L = { 1 }, R = {  }, M = {  } },
	legmed = { L = { 2 }, R = {  }, M = {  } },
	legmg = { L = { 1 }, R = {  }, M = {  } },
	legmh = { L = { 1 }, R = {  }, M = {  } },
	legmine1 = { L = {  }, R = {  }, M = {  } },
	legmine2 = { L = {  }, R = {  }, M = {  } },
	legmine3 = { L = {  }, R = {  }, M = {  } },
	legmineb = { L = {  }, R = {  }, M = {  } },
	legministarfall = { L = { 1 }, R = {  }, M = {  } },
	legmlv = { L = { 1 }, R = {  }, M = {  } },
	legmos = { L = { 1 }, R = {  }, M = {  } },
	legmost3 = { L = { 1 }, R = {  }, M = {  } },
	legmrv = { L = { 1 }, R = {  }, M = {  } },
	legnap = { L = { 1 }, R = {  }, M = {  } },
	legnavaldefturret = { L = { 1 }, R = {  }, M = {  } },
	legnavyaaship = { L = { 1 }, R = {  }, M = {  } },
	legnavyartyship = { L = { 1 }, R = { 2 }, M = {  } },
	legnavydestro = { L = { 1 }, R = {  }, M = {  } },
	legnavyfrigate = { L = { 1 }, R = { 2 }, M = {  } },
	legnavyscout = { L = { 1 }, R = {  }, M = {  } },
	legnavysub = { L = { 1 }, R = {  }, M = {  } },
	legner = { L = { 1 }, R = {  }, M = {  } },
	legpede = { L = { 1, 6 }, R = { 2, 5 }, M = { 3, 4 } },
	legperdition = { L = { 1 }, R = {  }, M = {  } },
	legphoenix = { L = { 2 }, R = {  }, M = {  } },
	legrail = { L = { 1 }, R = { 2 }, M = {  } },
	legrampart = { L = {  }, R = {  }, M = {  } },
	legrhapsis = { L = { 1 }, R = {  }, M = {  } },
	legrl = { L = { 1 }, R = {  }, M = {  } },
	legrwall = { L = { 1 }, R = {  }, M = {  } },
	legscout = { L = { 1 }, R = {  }, M = {  } },
	legsh = { L = { 1 }, R = {  }, M = {  } },
	legshot = { L = { 1 }, R = {  }, M = {  } },
	legsilo = { L = { 1 }, R = {  }, M = {  } },
	legsnapper = { L = {  }, R = {  }, M = {  } },
	legspbomber = { L = { 1 }, R = {  }, M = {  } },
	legspcarrier = { L = {  }, R = {  }, M = {  } },
	legspfighter = { L = { 1 }, R = {  }, M = {  } },
	legspsurfacegunship = { L = { 1 }, R = {  }, M = {  } },
	legsptorpgunship = { L = { 1 }, R = {  }, M = {  } },
	legsrail = { L = { 1 }, R = {  }, M = {  } },
	legsrailt4 = { L = { 1 }, R = {  }, M = {  } },
	legstarfall = { L = { 1 }, R = {  }, M = {  } },
	legstr = { L = { 1 }, R = {  }, M = {  } },
	legstronghold = { L = { 1 }, R = {  }, M = {  } },
	legtl = { L = { 1 }, R = {  }, M = {  } },
	legvcarry = { L = {  }, R = {  }, M = {  } },
	legvenator = { L = { 1 }, R = {  }, M = {  } },
	legvflak = { L = { 1 }, R = {  }, M = {  } },
}
CRUISE_ALT = { -- the highest height above the ground an aircraft may fly (table renegade_cruise.csv, column Cruise altitude used)
	armaca = 240,
	armassistdrone = 300,
	armatlas = 300,
	armawac = 480,
	armblade = 330,
	armbrawl = 300,
	armca = 210,
	armcsa = 150,
	armdfly = 405,
	armdrone = 120,
	armdroneold = 210,
	armfepocht4 = 300,
	armfify = 234,
	armfig = 375,
	armhaca = 150,
	armhawk = 480,
	armhvytrans = 300,
	armkam = 210,
	armlance = 270,
	armliche = 450,
	armlichet4 = 450,
	armpeep = 540,
	armpnix = 660,
	armsaber = 255,
	armsat = 8100,
	armsb = 630,
	armseap = 300,
	armsehak = 660,
	armsfig = 420,
	armsfig2 = 420,
	armstil = 360,
	armtdrone = 120,
	armthund = 495,
	armthundt4 = 570,
	coraca = 210,
	corape = 300,
	corassistdrone = 300,
	corawac = 330,
	corbw = 234,
	corca = 225,
	corcrw = 225,
	corcrwh = 255,
	corcrwt4 = 330,
	corcsa = 165,
	corcut = 255,
	cordrone = 120,
	cordronecarryair = 300,
	cordroneold = 234,
	cords = 495,
	corfblackhyt4 = 300,
	corfink = 330,
	corhaca = 165,
	corhunt = 570,
	corhurc = 660,
	corhvytrans = 300,
	corsat = 8100,
	corsb = 450,
	corseah = 405,
	corseap = 300,
	corsfig = 420,
	corsfig2 = 420,
	corshad = 495,
	cortdrone = 120,
	cortitan = 270,
	corvalk = 300,
	corvamp = 480,
	corveng = 375,
	legaca = 210,
	legafigdef = 480,
	legassistdrone = 300,
	legatorpbomber = 270,
	legatrans = 300,
	legca = 225,
	legcib = 390,
	legdrone = 234,
	legfig = 375,
	legfort = 300,
	legfortt4 = 750,
	leghaca = 165,
	legheavydrone = 204,
	legheavydronesmall = 204,
	legionnaire = 480,
	legkam = 150,
	leglts = 300,
	legmineb = 450,
	legmos = 210,
	legmost3 = 450,
	legnap = 540,
	legphoenix = 660,
	legspbomber = 630,
	legspcarrier = 300,
	legspcon = 150,
	legspfighter = 420,
	legspradarsonarplane = 660,
	legspsurfacegunship = 255,
	legsptorpgunship = 300,
	legstronghold = 405,
	legvenator = 480,
	legwhisper = 390,
}
-- END WEAPONS
local MISSILE = { MissileLauncher = true, StarburstLauncher = true, TorpedoLauncher = true }
local slotCache = {}
local function slotsFor(ud)
	local c = slotCache[ud.id]
	if c then return c end
	local armor = (Game.armorTypes or {}).default or 0
	local vtol = (Game.armorTypes or {}).vtol or 14
	local groups, byDef = {}, {}
	for i, wp in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		local d = wd and wd.damages and tonumber(wd.damages[armor]) or 0
		local v = wd and wd.damages and tonumber(wd.damages[vtol]) or 0
		-- (weapons without damage are no weapons: footsteps and the dummies that the unit scripts use)
		if wd and (tonumber(wd.range) or 0) > 0 and wd.type ~= "Shield" and (tonumber(wd.interceptor) or 0) == 0 and (d > 2 or v > 2) then
			local g = byDef[wp.weaponDef]
			if not g then
				local desc = tostring(wd.description or ""):lower()
				-- air only: no damage against the ground, or the description names only air targets (g2a / a2a / s2a and no x2g / x2s: the Demon's shoulder rockets)
				local airTok = desc:find("[gas]2a") ~= nil and desc:find("[gas]2[gs]") == nil
				g = { range = tonumber(wd.range), list = {}, missile = MISSILE[wd.type] and true or false, aa = ((d <= 2 and v > d) or airTok), dgun = wd.type == "DGun" }
				-- a weapon that hits the ground and aircraft (the description says "g2a" or "a2a"): at an aircraft in the circle it locks on, at the ground the player aims
				g.hy = not g.aa and d > 2 and v > 2 and (desc:find("g2a", 1, true) ~= nil or desc:find("a2a", 1, true) ~= nil)
				if g.aa then g.missile = true end
				byDef[wp.weaponDef] = g
				groups[#groups + 1] = g
			end
			g.list[#g.list + 1] = i
		end
	end
	local s = { L = {}, R = {}, M = {}, aa = {}, hy = {} }
	for _, g in ipairs(groups) do
		for _, i in ipairs(g.list) do
			if g.aa then s.aa[i] = true end
			if g.hy then s.hy[i] = true end
		end
	end
	local entry = WEAPON_BUTTONS[(ud.name:gsub("_scav$", ""))] -- the table of game-modes/renegade-weapons.md (a Scavenger copy: the normal unit's entry)
	if entry then
		s.L, s.R, s.M = entry.L, entry.R, entry.M
		slotCache[ud.id] = s
		return s
	end
	local others, miss, dguns = {}, {}, {}
	for _, g in ipairs(groups) do
		local l = g.dgun and dguns or (g.missile and miss or others)
		l[#l + 1] = g
	end
	local function byRange(x, y) return x.range < y.range end
	table.sort(others, byRange)
	table.sort(miss, byRange)
	local function merge(list, from)
		local out = {}
		for k = from, #list do
			for _, i in ipairs(list[k].list) do out[#out + 1] = i end
		end
		return out
	end
	if #dguns > 0 then
		-- the D-gun (the commander's Disintegrator) is always on the right button; the shortest of the others on the left, the rest in the middle
		s.R = merge(dguns, 1)
		local rest = {}
		for _, g in ipairs(others) do rest[#rest + 1] = g end
		for _, g in ipairs(miss) do rest[#rest + 1] = g end
		s.L = rest[1] and rest[1].list or {}
		s.M = merge(rest, 2)
	elseif #miss > 0 and #others > 0 then
		s.L, s.R, s.M = merge(others, 1), {}, merge(miss, 1)
		s.L = others[1].list
		s.R = merge(others, 2)
		if #s.R == 0 then s.R, s.M = s.M, {} end
	else
		local list = (#others > 0) and others or miss
		s.L = list[1] and list[1].list or {}
		s.R = list[2] and list[2].list or {}
		s.M = merge(list, 3)
	end
	slotCache[ud.id] = s
	return s
end

local function weaponsFor(u, mask)
	local ud = UnitDefs[Spring.GetUnitDefID(u)]
	local s = slotsFor(ud)
	local list = {}
	local function add(l) for _, i in ipairs(l) do list[#list + 1] = i end end
	if mask % 2 >= 1 then add(s.L) end
	if math.floor(mask / 2) % 2 >= 1 then add(s.R) end
	if mask >= 4 then add(s.M) end
	return list, ud, s
end

local function shortened(u, ud, i, x, y, z)
	local wd = WeaponDefs[ud.weapons[i].weaponDef]
	local ux, uy, uz = Spring.GetUnitPosition(u, true)
	local dx, dy, dz = x - ux, y - uy, z - uz
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	local r = ((wd and wd.range) or 0) - 8
	if d > r and d > 0 then
		local k = math.max(0, r) / d
		x, y, z = ux + dx * k, uy + dy * k, uz + dz * k
	end
	return math.max(1, math.min(Game.mapSizeX - 1, x)), y, math.max(1, math.min(Game.mapSizeZ - 1, z))
end

-- clear the targets of all weapons: SetUnitTarget(unit, nil) does not clear a target that was set for one weapon number, a stop order does (it clears the
-- move order too: the steering gives it again)
local function clearTargets(u, inp)
	Spring.SetUnitTarget(u, nil)
	-- (measured: a target of one weapon is not cleared by SetUnitTarget(nil) for that weapon number, only by a stop order. The stop order also stops a walking or flying
	-- unit, so it is given only before the turret has started to follow the view: from then on the weapons that are not pressed get the view point as their target and
	-- their reload is held (aim only), so nothing keeps firing and no stop order is needed.)
	if inp.aimed then return end
	Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
	inp.moving = false
end

-- A bomb is dropped where the aircraft is (not at the point the player looks at): its target is the point where a bomb dropped now would land (the position moved by the
-- velocity for the fall time over the ground; the widget draws the same point), so the weapon is in range and aimed at once and the bombs fall as soon as the button is down.
local function bombPoint(u)
	local ux, uy, uz = Spring.GetUnitPosition(u)
	local vx, vy, vz = Spring.GetUnitVelocity(u)
	if not ux or not vx then return nil end
	local g = (Game.gravity or 120) / 900
	local x, z = ux, uz
	for _ = 1, 4 do
		local drop = uy - Spring.GetGroundHeight(x, z)
		local tt = (vy + math.sqrt(vy * vy + 2 * g * math.max(0, drop))) / g
		x, z = ux + vx * tt, uz + vz * tt
	end
	x, z = math.max(1, math.min(Game.mapSizeX - 1, x)), math.max(1, math.min(Game.mapSizeZ - 1, z))
	return x, Spring.GetGroundHeight(x, z), z
end

-- The target of one weapon: the point (or, for an anti-air weapon and a weapon that also hits aircraft, the locked aircraft)
local function applyTarget(team, u, ud, s, i, t)
	local lock = t.unit >= 0 and Spring.ValidUnitID(t.unit) and not Spring.AreTeamsAllied(team, Spring.GetUnitTeam(t.unit))
	if s.aa[i] then
		-- anti-air: only at the aircraft the player looks at
		if lock then Spring.SetUnitTarget(u, t.unit, false, true, i) end
	elseif s.hy[i] and lock and (UnitDefs[Spring.GetUnitDefID(t.unit)] or {}).canFly then
		local ok = Spring.SetUnitTarget(u, t.unit, false, true, i) -- ground and air: at an aircraft in the circle it locks on
		if TEST and not input[team].logged then input[team].logged = true; Spring.Echo("[Renegade] air lock of weapon " .. i .. " on " .. t.unit .. ": " .. tostring(ok)) end
		if not ok then -- (the weapon refuses the unit as a target: the point where it is)
			local x, y, z = Spring.GetUnitPosition(t.unit, true)
			if x then
				x, y, z = shortened(u, ud, i, x, y, z)
				Spring.SetUnitTarget(u, x, y, z, false, true, i)
			end
		end
	elseif (WeaponDefs[ud.weapons[i].weaponDef] or {}).type == "AircraftBomb" then
		local x, y, z = bombPoint(u)
		if x then Spring.SetUnitTarget(u, x, y, z, false, true, i) end
	else
		local x, y, z = shortened(u, ud, i, t.x, t.y, t.z)
		local wd = WeaponDefs[ud.weapons[i].weaponDef]
		local ok
		if wd and wd.type == "DGun" then
			ok = Spring.SetUnitTarget(u, x, y, z, true, true, i) -- the D-gun: a manual fire weapon (the dgun flag)
		else
			ok = Spring.SetUnitTarget(u, x, y, z, false, true, i)
		end
		if TEST and not ok then
			local px, py, pz = Spring.GetUnitPosition(u)
			local fx, _, fz = Spring.GetUnitDirection(u)
			local ang = math.deg(math.abs((math.atan2(x - px, z - pz) - math.atan2(fx, fz) + math.pi) % (2 * math.pi) - math.pi))
			if ang < 15 and (input[team].refused or 0) < 4 then
			input[team].refused = (input[team].refused or 0) + 1
			Spring.Echo(string.format("[Renegade] SetUnitTarget refused: weapon %d (%s, range %s, maxAngleDif %s) point %.0f %.0f %.0f, unit at %.0f %.0f %.0f, distance %.0f, %.0f degrees off the facing", i, tostring(wd and wd.type), tostring(wd and wd.range), tostring(ud.weapons[i].maxAngleDif), x, y, z, px, py, pz, math.sqrt((x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2), ang))
		end
		end
	end
end

-- One click is one shot: a weapon that is pressed (inp.hold[weapon].down) keeps its target while the button is down (continuous fire, as fast as it reloads). When the
-- button goes up before the weapon has fired (the turret was still turning, the weapon was still reloading) the target stays until the weapon has fired (its
-- reloadFrame changed) or its time is up (`until`: 45 frames plus the reload time, at most 8 s), then the stop order clears it. A weapon that has fired is let go at once.
local function reloadFrame(u, i) return Spring.GetUnitWeaponState(u, i, "reloadFrame") or 0 end

-- The turret follows the view without firing ("aim only"): every weapon of the three buttons that is not pressed gets the point the player looks at as its target
-- (shortened to its reach: the turret turns toward it) and its reload is held: once it is ready its reloadFrame is set far into the future (BLOCK), so it aims but does not
-- fire. Pressing the button sets it to now (it fires as soon as it has turned); a weapon that is reloading is left alone (BLOCK is set when it is ready). The widget shows a
-- weapon with reloadFrame >= BLOCK / 2 as READY. Not for anti-air weapons (they have no target without a lock) and not for stockpile weapons (starburst).
local BLOCK = 1000000
local function unblock(u, i, f)
	if reloadFrame(u, i) >= BLOCK / 2 then Spring.SetUnitWeaponState(u, i, "reloadFrame", f) end
end
local function aimable(ud, i)
	local wd = WeaponDefs[ud.weapons[i].weaponDef]
	return wd and not wd.stockpile and wd.type ~= "DGun" and wd.type ~= "AircraftBomb" -- (the D-gun is fired by hand: it has no target before the button)
end

local function shoot(team, f, force)
	local u, inp = units[team], input[team]
	if not u or not inp or not Spring.ValidUnitID(u) then return end
	local hold = inp.hold
	local list, ud, s = weaponsFor(u, inp.fire)
	local pressed = {}
	for _, i in ipairs(list) do pressed[i] = true end
	local change, clear = false, false
	for i in pairs(pressed) do
		local a = hold[i]
		if not a or not a.down then
			local before = reloadFrame(u, i)
			unblock(u, i, f)
			if TEST then Spring.Echo("[Renegade] press weapon " .. i .. " at frame " .. f .. ": reloadFrame " .. before .. " -> " .. reloadFrame(u, i)) end
			local time = Spring.GetUnitWeaponState(u, i, "reloadTime") or 1
			hold[i] = { down = true, since = f, rf0 = reloadFrame(u, i), fired = false, t = inp.target, deadline = f + 150 + math.min(240, math.floor(time * 30)) }
			change = true
		else
			a.t = inp.target
		end
	end
	for i, a in pairs(hold) do
		if not a.fired and reloadFrame(u, i) > a.rf0 then
			a.fired = true
			if TEST then Spring.Echo("[Renegade] weapon " .. i .. " fired, frame " .. f .. ", reloadFrame " .. reloadFrame(u, i) .. ", " .. (f - a.since) .. " frames after the press") end
		end
		if a.down and not pressed[i] then
			a.down = false -- released
			change = true
		end
		if not a.down and (a.fired or f >= a.deadline) then
			hold[i] = nil
			clear = true
		end
	end
	if clear then
		clearTargets(u, inp) -- (also clears the targets of the weapons that are still held: they get theirs again below)
		change = true
	end
	local tick = change or force or f % AIM_EVERY == 0 or ud.canFly -- (an aircraft moves fast: the bombs' target every frame)
	if tick then
		for i, a in pairs(hold) do applyTarget(team, u, ud, s, i, a.t) end
	end
	-- aim only: the other weapons of the buttons follow the view, their reload is held
	if inp.aimed then
		for _, list2 in ipairs({ s.L, s.R, s.M }) do
			for _, i in ipairs(list2) do
				if not hold[i] and not s.aa[i] and aimable(ud, i) then
					if reloadFrame(u, i) <= f then Spring.SetUnitWeaponState(u, i, "reloadFrame", BLOCK) end
					if tick then
						local t = inp.target
						local x, y, z = shortened(u, ud, i, t.x, t.y, t.z)
						Spring.SetUnitTarget(u, x, y, z, false, true, i)
					end
				end
			end
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if TEST and msg == "ren|test|1" then
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local u = units[team]
		if u and not spec then
			local x, y, z = Spring.GetUnitPosition(u)
			local inp = input[team]
			local yaw = math.rad(inp.yaw)
			local ex, ez = x + math.sin(yaw) * 150, z + math.cos(yaw) * 150
			for _, t in ipairs(Spring.GetTeamList()) do
				if not Spring.AreTeamsAllied(t, team) and t ~= Spring.GetGaiaTeamID() then
					local e = Spring.CreateUnit(START_UNIT, ex, Spring.GetGroundHeight(ex, ez), ez, 0, t)
					if e then
						Spring.GiveOrderToUnit(e, CMD.FIRE_STATE, { 0 }, 0)
						Spring.Echo("[Renegade] test enemy " .. e .. " at " .. math.floor(ex) .. " " .. math.floor(ez))
					end
					break
				end
			end
		end
		return
	end
	if TEST and msg == "ren|test|3" then -- an enemy gunship (hold fire) 250 Elmo ahead of the unit, 100 Elmo up
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local u = units[team]
		if u and not spec then
			local x, y, z = Spring.GetUnitPosition(u)
			local yaw = math.rad(input[team].yaw)
			local ex, ez = x + math.sin(yaw) * 250, z + math.cos(yaw) * 250
			for _, tm in ipairs(Spring.GetTeamList()) do
				if not Spring.AreTeamsAllied(tm, team) and tm ~= Spring.GetGaiaTeamID() then
					local e = Spring.CreateUnit("armbrawl", ex, Spring.GetGroundHeight(ex, ez) + 100, ez, 0, tm)
					if e then
						Spring.GiveOrderToUnit(e, CMD.FIRE_STATE, { 0 }, 0)
						Spring.Echo("[Renegade] test gunship " .. e)
					end
					break
				end
			end
		end
		return
	end
	if TEST and msg == "ren|test|2" then
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		if units[team] and not spec then Spring.DestroyUnit(units[team], true, false) end
		return
	end
	local spawn = msg:match("^ren|spawn|([%w_]+)$")
	if spawn then
		-- debug: an enemy unit 1000 Elmo ahead of the player's view, a ground unit on the ground, an aircraft 200 Elmo up; it fights toward the player
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local ud = UnitDefNames[spawn]
		local u = units[team]
		if DEBUG and not spec and ud and u and Spring.ValidUnitID(u) then
			local enemy
			for _, tm in ipairs(Spring.GetTeamList()) do
				if not Spring.AreTeamsAllied(tm, team) and tm ~= Spring.GetGaiaTeamID() then enemy = tm; break end
			end
			if enemy then
				local x, y, z = Spring.GetUnitPosition(u)
				local yaw = math.rad(input[team].yaw)
				local ex = math.max(64, math.min(Game.mapSizeX - 64, x + math.sin(yaw) * 1000))
				local ez = math.max(64, math.min(Game.mapSizeZ - 64, z + math.cos(yaw) * 1000))
				local ey = Spring.GetGroundHeight(ex, ez) + (ud.canFly and 200 or 0)
				local id = Spring.CreateUnit(spawn, ex, ey, ez, math.random(0, 3), enemy)
				if id then
					Spring.GiveOrderToUnit(id, CMD.FIGHT, { x, Spring.GetGroundHeight(x, z), z }, 0)
					if TEST then Spring.Echo(string.format("[Renegade] spawned %s %d at %d Elmo, height above the ground %d", spawn, id, math.sqrt((ex - x) ^ 2 + (ez - z) ^ 2), ey - Spring.GetGroundHeight(ex, ez))) end
				end
			end
		end
		return
	end
	local want = msg:match("^ren|unit|([%w_]+)$")
	if want then
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		if DEBUG and not spec then turnInto(team, want) end
		return
	end
	local yaw, pitch, keys, fire, tx, ty, tz, tu = msg:match("^ren|(-?%d+)|(-?%d+)|(%d+)|(%d)|(-?%d+)|(-?%d+)|(-?%d+)|(-?%d+)$")
	if not yaw then return end
	local _, active, spec, team = Spring.GetPlayerInfo(playerID, false)
	if spec or not units[team] then return end
	local inp = input[team]
	inp.yaw, inp.pitch = tonumber(yaw) % 360, math.max(-89, math.min(89, tonumber(pitch)))
	inp.keys, inp.fire = math.max(0, math.min(63, tonumber(keys))), math.max(0, math.min(7, tonumber(fire)))
	inp.target = { x = tonumber(tx), y = tonumber(ty), z = tonumber(tz), unit = tonumber(tu) }
	inp.aimed = true -- (from the first message on the turret follows the view)
	if TEST and inp.fire ~= 0 and not inp.said then inp.said = true; Spring.Echo("[Renegade] first message with a button: fire " .. inp.fire .. " at frame " .. Spring.GetGameFrame() .. ", weapons " .. #weaponsFor(units[team], inp.fire)) end
	shoot(team, Spring.GetGameFrame(), true)
end

-- a place on the land for a unit: of 24 random places where the unit can stand, the one farthest from the units of the other teams (a player) or the one at
-- about 800 Elmo from the nearest player unit (a bot: the fight comes to the player)
local function others(team)
	local l = {}
	for tm, u in pairs(units) do
		if tm ~= team and Spring.ValidUnitID(u) then l[#l + 1] = u end
	end
	return l
end

local function nearestDist(x, z, list)
	local best = 1e9
	for _, u in ipairs(list) do
		local ux, _, uz = Spring.GetUnitPosition(u)
		if ux then best = math.min(best, math.sqrt((ux - x) ^ 2 + (uz - z) ^ 2)) end
	end
	return best
end

local function place(defName, list, wanted)
	local defID = UnitDefNames[defName].id
	local bestX, bestZ, bestScore
	for pass = 1, 2 do -- the second pass without the test of the movement class (a ship on land, a turret)
		for _ = 1, 24 do
			local x = 200 + math.random() * (Game.mapSizeX - 400)
			local z = 200 + math.random() * (Game.mapSizeZ - 400)
			local y = Spring.GetGroundHeight(x, z)
			if y > 2 and (pass == 2 or Spring.TestMoveOrder(defID, x, y, z, 0, 0, 0, true, false, true)) then
				local d = nearestDist(x, z, list)
				local score = wanted and -math.abs(d - wanted) or d
				if not bestScore or score > bestScore then bestX, bestZ, bestScore = x, z, score end
			end
		end
		if bestX then break end
	end
	if not bestX then return nil end
	return bestX, Spring.GetGroundHeight(bestX, bestZ), bestZ
end

-- the unit of a player: new, or after a loss, or turned into another one (debug)
local function giveUnit(team, defName, x, y, z, face)
	local id = Spring.CreateUnit(defName, x, y, z, face or 0, team)
	if not id then return nil end
	units[team] = id
	kind[team] = defName
	input[team] = input[team] or { yaw = 0, pitch = 0, keys = 0, fire = 0, last = { frame = 0, yaw = 0, keys = 0 }, moving = false, target = { x = 0, y = 0, z = 0, unit = -1 }, mask = 0, hold = {} }
	input[team].moving, input[team].mask = false, 0
	input[team].hold = {}
	input[team].fire = 0
	Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0) -- hold fire: only the player aims
	Spring.SetTeamRulesParam(team, "renUnit", id, { public = true })
	-- the groups of weapons of the buttons for the widget: "left;right;middle" (weapon numbers), and the anti-air weapons
	local s = slotsFor(UnitDefNames[defName])
	local aa = {}
	for i in pairs(s.aa) do aa[#aa + 1] = i end
	table.sort(aa)
	Spring.SetUnitRulesParam(id, "renSlots", table.concat(s.L, ",") .. ";" .. table.concat(s.R, ",") .. ";" .. table.concat(s.M, ","), { public = true })
	Spring.SetUnitRulesParam(id, "renAA", table.concat(aa, ","), { public = true })
	if flyer(id) then Spring.SetUnitRulesParam(id, "renMaxAlt", maxAlt(id), { public = true }) end
	local hy = {}
	for i in pairs(s.hy) do hy[#hy + 1] = i end
	table.sort(hy)
	Spring.SetUnitRulesParam(id, "renHY", table.concat(hy, ","), { public = true })
	return id
end

turnInto = function(team, defName)
	local u = units[team]
	local ud = UnitDefNames[defName]
	if not u or not Spring.ValidUnitID(u) or not ud or #(ud.weapons or {}) == 0 then return end
	local x, y, z = Spring.GetUnitPosition(u)
	local hp, mhp = Spring.GetUnitHealth(u)
	local old = u
	local id = giveUnit(team, defName, x, y, z, Spring.GetUnitBuildFacing(u))
	if not id then return end
	local _, nmhp = Spring.GetUnitHealth(id)
	if hp and mhp and nmhp then Spring.SetUnitHealth(id, nmhp * hp / mhp) end
	Spring.DestroyUnit(old, false, true) -- (units[team] is the new one already: no respawn)
	Spring.Echo("[Renegade] team " .. team .. " turned into " .. defName .. " (unit " .. id .. ")")
end

-- a team with a human and a commander: the commander is replaced by the first unit
local function take(team)
	if units[team] ~= nil then return end
	local human = false
	for _, p in ipairs(Spring.GetPlayerList(team, true)) do
		local _, _, spec = Spring.GetPlayerInfo(p, false)
		if not spec then human = true end
	end
	if not human then return end
	for _, u in ipairs(Spring.GetTeamUnits(team)) do
		local ud = UnitDefs[Spring.GetUnitDefID(u)]
		if ud and ud.customParams and ud.customParams.iscommander then
			local x, y, z = Spring.GetUnitPosition(u)
			local face = Spring.GetUnitBuildFacing(u)
			Spring.DestroyUnit(u, false, true)
			local id = giveUnit(team, START_UNIT, x, y, z, face)
			if id then Spring.Echo("[Renegade] team " .. team .. " steers a " .. START_UNIT .. " (unit " .. id .. ")") end
			return
		end
	end
end

-- the bots: units of the first team that has no human; they fight their way toward the nearest player unit
local function findBotTeam()
	for _, team in ipairs(Spring.GetTeamList()) do
		if team ~= Spring.GetGaiaTeamID() and units[team] == nil then
			local human = false
			for _, p in ipairs(Spring.GetPlayerList(team, true)) do
				local _, _, spec = Spring.GetPlayerInfo(p, false)
				if not spec then human = true end
			end
			if not human then return team end
		end
	end
end

local function spawnBot()
	if not botTeam then return end
	local x, y, z = place(START_UNIT, others(botTeam), 800)
	if not x then return end
	local id = Spring.CreateUnit(START_UNIT, x, y, z, math.random(0, 3), botTeam)
	if id then
		bots[id] = true
		if TEST then Spring.Echo("[Renegade] bot " .. id .. " at " .. math.floor(x) .. " " .. math.floor(z)) end
	end
end

local function steerBots()
	local players = others(botTeam)
	if #players == 0 then return end
	if TEST then
		local n, near = 0, 1e9
		for id in pairs(bots) do
			n = n + 1
			local x, _, z = Spring.GetUnitPosition(id)
			if x then near = math.min(near, nearestDist(x, z, players)) end
		end
		Spring.Echo("[Renegade] bots " .. n .. ", nearest to a player " .. math.floor(near) .. " Elmo")
	end
	for id in pairs(bots) do
		local x, _, z = Spring.GetUnitPosition(id)
		if x then
			local best, bx, bz = 1e9
			for _, u in ipairs(players) do
				local ux, _, uz = Spring.GetUnitPosition(u)
				local d = (ux - x) ^ 2 + (uz - z) ^ 2
				if d < best then best, bx, bz = d, ux, uz end
			end
			local tx = math.max(16, math.min(Game.mapSizeX - 16, bx + (math.random() - 0.5) * 300))
			local tz = math.max(16, math.min(Game.mapSizeZ - 16, bz + (math.random() - 0.5) * 300))
			Spring.GiveOrderToUnit(id, CMD.FIGHT, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
		end
	end
end

-- test only: how many weapon groups do the units have (do three buttons do)?
local function census()
	local count, names = {}, {}
	for _, ud in pairs(UnitDefs) do
		if #(ud.weapons or {}) > 0 and not ud.name:find("_scav") and not ud.name:find("^raptor") then
			local s = slotsFor(ud)
			local n = 0
			for _, l in ipairs({ s.L, s.R, s.M }) do if #l > 0 then n = n + 1 end end
			count[n] = (count[n] or 0) + 1
			if #s.M > 0 and #s.R > 0 and #s.L > 0 then names[#names + 1] = ud.name end
		end
	end
	local t = {}
	for n, c in pairs(count) do t[#t + 1] = n .. " buttons: " .. c .. " units" end
	table.sort(t)
	Spring.Echo("[Renegade] census: " .. table.concat(t, ", "))
	for _, n in ipairs({ "armbanth", "armepoch", "corkarg", "armraz", "armpw", "armllt", "armroy", "corkorg", "armthor", "armmav" }) do
		local ud = UnitDefNames[n]
		if ud then
			local s = slotsFor(ud)
			local out = {}
			for i, wp in ipairs(ud.weapons) do
				local wd = WeaponDefs[wp.weaponDef]
				out[#out + 1] = i .. "=" .. wd.name .. "(" .. tostring(wd.type) .. " r" .. math.floor(wd.range) .. ")"
			end
			Spring.Echo("[Renegade] " .. n .. ": L " .. table.concat(s.L, ",") .. " R " .. table.concat(s.R, ",") .. " M " .. table.concat(s.M, ",") .. "   " .. table.concat(out, " "))
		end
	end
end

function gadget:GameFrame(f)
	if TEST and f == 40 then census() end
	if f >= 30 and f <= 300 and f % 15 == 0 then
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() then take(team) end
		end
	end
	for team in pairs(units) do
		faceView(team, f)
		steer(team, f)
		lift(team, f)
		shoot(team, f)
		if not energyInit[team] then
			energyInit[team] = true
			Spring.SetTeamResource(team, "es", ENERGY_STORE)
			Spring.SetTeamResource(team, "energy", ENERGY_START)
		end
		if f % 30 == 0 then Spring.AddTeamResource(team, "energy", ENERGY_INCOME) end
	end
	for team, at in pairs(due) do
		if f >= at then
			local x, y, z = place(kind[team], others(team), nil)
			if not x and lastPos[team] then x, y, z = lastPos[team][1], lastPos[team][2], lastPos[team][3] end
			if x and giveUnit(team, kind[team], x, y, z, 0) then
				due[team] = nil
				Spring.SetTeamRulesParam(team, "renRespawn", 0, { public = true })
			else
				due[team] = f + 30 -- (it did not work: again in a second)
			end
		end
	end
	if BOTS > 0 then
		if f == 120 then
			botTeam = findBotTeam()
			for _ = 1, BOTS do spawnBot() end
		end
		if botTeam and f > 120 then
			for i = #botDue, 1, -1 do
				if f >= botDue[i] then table.remove(botDue, i); spawnBot() end
			end
			if f % 120 == 0 then steerBots() end
		end
	end
end

function gadget:UnitDestroyed(u, defID, team)
	if units[team] == u then
		units[team] = nil
		Spring.SetTeamRulesParam(team, "renUnit", 0, { public = true })
		due[team] = Spring.GetGameFrame() + RESPAWN
		Spring.SetTeamRulesParam(team, "renRespawn", due[team], { public = true })
		local x, y, z = Spring.GetUnitPosition(u)
		if x then lastPos[team] = { x, y, z } end
	elseif bots[u] then
		bots[u] = nil
		botDue[#botDue + 1] = Spring.GetGameFrame() + BOT_RESPAWN
	end
end
