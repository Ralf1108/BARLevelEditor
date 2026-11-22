-- The unit script of the Lava Extractor (armlavagen, corlavagen, leglavagen; a Lua unit script, in the extra games as scripts/Units/lavagen.lua; BAR's
-- gadget unit_script.lua runs it). The model (LevelEditor/models/lavagen.s3o, make_lava_generator.py): a furnace with a lava fall, a gear wheel,
-- two pistons, four conveyor belts with two crates each and four storage pads with 6 metal blocks each. Called by the gadget lava_generator.lua
-- with Spring.UnitScript.CallAsUnit:
--   SetActive(on): on a Volcano the wheel turns, the pistons go up and down, drops of lava fall and the crates ride out on the belts; off: all
--     stands still;
--   SetBlocks(n): n of the 6 blocks show on every pad (the metal stock; all pads show the same).

local wheel = piece("wheel")
local pistons = { piece("piston1"), piece("piston2") }
local drops = { piece("drop1"), piece("drop2"), piece("drop3") }
local items = {}
for n = 1, 8 do
	items[n] = piece("item" .. n)
end
local blocks = {}
for n = 1, 24 do
	blocks[n] = piece("block" .. n)
end
local PER_PAD = 6
local SIG_WORK = 2
local DROP_FALL = 15 -- how far a drop falls (Elmo, from the spout to the pool)
local BELT = 74 -- how far a crate rides (Elmo, from the start of a belt to its pad)
local BELT_SPEED = 14
-- the belts in the order of the model: east (+x), south (+z), west (-x), north (-z): the axis and the sign of a Move outwards (the x axis of a
-- unit script is the other way round than the x of the model)
local BELTS = { { x_axis, -1 }, { z_axis, 1 }, { x_axis, 1 }, { z_axis, -1 } }
local active = false

local function piston(p, delay)
	SetSignalMask(SIG_WORK)
	Sleep(delay)
	while true do
		Move(p, y_axis, 4, 8)
		WaitForMove(p, y_axis)
		Move(p, y_axis, 0, 8)
		WaitForMove(p, y_axis)
	end
end

local function drop(p, delay)
	SetSignalMask(SIG_WORK)
	Sleep(delay)
	while true do
		Move(p, y_axis, 0)
		Show(p)
		Move(p, y_axis, -DROP_FALL, 16)
		WaitForMove(p, y_axis)
		Hide(p)
		Sleep(150)
	end
end

local function ride(p, belt, delay)
	SetSignalMask(SIG_WORK)
	local axis, sign = belt[1], belt[2]
	Sleep(delay)
	while true do
		Move(p, axis, 0)
		Show(p)
		Move(p, axis, sign * BELT, BELT_SPEED)
		WaitForMove(p, axis)
		Hide(p)
		Sleep(300)
	end
end

function SetActive(on)
	if on == active then
		return
	end
	active = on
	Signal(SIG_WORK)
	if on then
		Spin(wheel, x_axis, math.rad(60), math.rad(30))
		StartThread(piston, pistons[1], 0)
		StartThread(piston, pistons[2], 500)
		for i, p in ipairs(drops) do
			StartThread(drop, p, (i - 1) * 400)
		end
		for n, p in ipairs(items) do
			local belt = BELTS[math.floor((n - 1) / 2) + 1]
			StartThread(ride, p, belt, ((n - 1) % 2) * math.floor(BELT / BELT_SPEED * 500)) -- (the second crate of a belt half a ride later)
		end
	else
		StopSpin(wheel, x_axis, math.rad(30))
		for _, p in ipairs(pistons) do
			Move(p, y_axis, 0, 8)
		end
		for _, p in ipairs(drops) do
			Hide(p)
		end
		for _, p in ipairs(items) do
			Hide(p)
		end
	end
end

function SetBlocks(n)
	for i, b in ipairs(blocks) do
		if (i - 1) % PER_PAD < n then
			Show(b)
		else
			Hide(b)
		end
	end
end

function script.Create()
	SetBlocks(0)
	for _, p in ipairs(drops) do
		Hide(p)
	end
	for _, p in ipairs(items) do
		Hide(p)
	end
end

function script.Killed(recentDamage, maxHealth)
	Explode(wheel, SFX.SHATTER)
	return recentDamage < maxHealth * 0.5 and 1 or 2 -- the wreck of the metal extractor (1), when hit hard its heap (2)
end
