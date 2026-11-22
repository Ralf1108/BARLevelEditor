-- The unit script of the Forklift armlavafork (Lua unit script, in the extra games as scripts/Units/armlavafork.lua; BAR's gadget unit_script.lua
-- runs it). The model (LevelEditor/models/armlavafork.s3o, make_lava_forklift.py) is BAR's Rover armfav with a mast, a fork and three boxes on it.
-- The wheels turn while it drives. SetBoxes(n) (called by the gadget lava_generator.lua with Spring.UnitScript.CallAsUnit) shows n of the three
-- boxes and lifts the fork a little while it carries.

local base, mast, fork = piece("base", "mast", "fork")
local lfwheel, rfwheel, bwheel = piece("lfwheel", "rfwheel", "bwheel")
local boxes = { piece("box1"), piece("box2"), piece("box3") }
local WHEEL_SPEED = math.rad(540)
local FORK_UP = 2.5 -- how far the fork goes up while it carries (Elmo)

function SetBoxes(n)
	for i, b in ipairs(boxes) do
		if i <= n then
			Show(b)
		else
			Hide(b)
		end
	end
	Move(fork, y_axis, n > 0 and FORK_UP or 0, 4)
end

function script.Create()
	SetBoxes(0)
end

function script.StartMoving()
	Spin(lfwheel, x_axis, WHEEL_SPEED)
	Spin(rfwheel, x_axis, WHEEL_SPEED)
	Spin(bwheel, x_axis, WHEEL_SPEED)
end

function script.StopMoving()
	StopSpin(lfwheel, x_axis)
	StopSpin(rfwheel, x_axis)
	StopSpin(bwheel, x_axis)
end

function script.Killed(recentDamage, maxHealth)
	Explode(mast, SFX.SHATTER)
	return recentDamage < maxHealth * 0.5 and 1 or 2 -- the wreck of armfav (1), when hit hard its heap (2)
end
