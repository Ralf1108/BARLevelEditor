-- The unit script of the Cargo Truck armlavatruck (Lua unit script, in the extra games as scripts/Units/armlavatruck.lua; BAR's gadget
-- unit_script.lua runs it). The model (LevelEditor/models/armlavatruck.s3o, make_lava_truck.py) is BAR's missile truck armsam with an open bed, a
-- tailgate and six crates. The wheels turn while it drives. Called by the gadget lava_generator.lua with Spring.UnitScript.CallAsUnit:
--   SetCrates(n): n of the six crates show on the bed (at once);
--   LoadCrate(n): crate n slides in from behind (from the storage pad, up over the tailgate) to its place;
--   Gate(open): the tailgate folds down or up;
--   Wheels(dir): the wheels turn forwards (1), backwards (-1) or stop (0) (while the gadget moves the truck itself, MoveCtrl, at a storage pad).

local rwheel, lwheel, gate = piece("rwheel", "lwheel", "gate")
local crates = {}
for n = 1, 6 do
	crates[n] = piece("crate" .. n)
end
local CRATE_Z = { 1.0, 1.0, -7.5, -7.5, -16.0, -16.0 } -- the places of the crates along the bed (the model: CRATE_Z)
local FROM_Z, FROM_Y = -34, -9 -- a crate comes from there (the model: behind the truck, at the height of a storage pad)
local LOAD_TIME = 0.45 -- seconds a crate slides
local GATE_OPEN = math.rad(-100) -- the tailgate folded down (backwards)
local WHEEL_SPEED = math.rad(540)

function SetCrates(n)
	for i, c in ipairs(crates) do
		Move(c, z_axis, 0)
		Move(c, y_axis, 0)
		if i <= n then
			Show(c)
		else
			Hide(c)
		end
	end
end

function LoadCrate(n)
	local c = crates[n]
	if not c then
		return
	end
	local dz = FROM_Z - CRATE_Z[n]
	Move(c, z_axis, dz)
	Move(c, y_axis, FROM_Y)
	Show(c)
	Move(c, z_axis, 0, math.abs(dz) / LOAD_TIME)
	Move(c, y_axis, 0, math.abs(FROM_Y) / LOAD_TIME)
end

function Gate(open)
	Turn(gate, x_axis, open and GATE_OPEN or 0, math.rad(240))
end

function Wheels(dir)
	if dir == 0 then
		StopSpin(rwheel, x_axis)
		StopSpin(lwheel, x_axis)
	else
		Spin(rwheel, x_axis, dir * WHEEL_SPEED)
		Spin(lwheel, x_axis, dir * WHEEL_SPEED)
	end
end

function script.Create()
	SetCrates(0)
end

function script.StartMoving()
	Wheels(1)
end

function script.StopMoving()
	Wheels(0)
end

function script.Killed(recentDamage, maxHealth)
	Explode(gate, SFX.SHATTER)
	return recentDamage < maxHealth * 0.5 and 1 or 2 -- the wreck of armsam (1), when hit hard its heap (2)
end
