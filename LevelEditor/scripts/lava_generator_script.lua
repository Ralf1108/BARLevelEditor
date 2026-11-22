-- The unit script of the Lava Extractor (armlavagen, corlavagen, leglavagen; a Lua unit script, in the extra games as scripts/Units/lavagen.lua; BAR's
-- gadget unit_script.lua runs it). The model (LevelEditor/models/lavagen.s3o, make_lava_generator.py): a furnace with a lava fall, a gear wheel,
-- two pistons and a storage yard with 15 metal blocks. Called by the gadget lava_generator.lua with Spring.UnitScript.CallAsUnit:
--   SetActive(on): on a Volcano the wheel turns, the pistons go up and down and drops of lava fall; off: all stands still;
--   SetBlocks(n): n of the 15 blocks of the yard show (the metal stock).

local wheel = piece("wheel")
local pistons = { piece("piston1"), piece("piston2") }
local drops = { piece("drop1"), piece("drop2"), piece("drop3") }
local blocks = {}
for n = 1, 15 do
	blocks[n] = piece("block" .. n)
end
local SIG_WORK = 2
local DROP_FALL = 22 -- how far a drop falls (Elmo, from the spout to the pool)
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
		Move(p, y_axis, -DROP_FALL, 18)
		WaitForMove(p, y_axis)
		Hide(p)
		Sleep(150)
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
	else
		StopSpin(wheel, x_axis, math.rad(30))
		for _, p in ipairs(pistons) do
			Move(p, y_axis, 0, 8)
		end
		for _, p in ipairs(drops) do
			Hide(p)
		end
	end
end

function SetBlocks(n)
	for i, b in ipairs(blocks) do
		if i <= n then
			Show(b)
		else
			Hide(b)
		end
	end
end

function script.Create()
	SetUnitValue(COB.YARD_OPEN, 1) -- (the yard of the yardmap, "y": Carriers drive in)
	SetBlocks(0)
	for _, p in ipairs(drops) do
		Hide(p)
	end
end

function script.Killed(recentDamage, maxHealth)
	Explode(wheel, SFX.SHATTER)
	return recentDamage < maxHealth * 0.5 and 1 or 2 -- the wreck of the metal extractor (1), when hit hard its heap (2)
end
