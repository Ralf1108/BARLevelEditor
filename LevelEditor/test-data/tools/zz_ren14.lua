function widget:GetInfo() return { name = "zz ren14", desc = "test only: Renegade one click = one shot", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren14.lua: a short click (the button is down for 3 frames) while the turret still has to turn (the aim is behind the unit's
-- facing): does the weapon fire once (its reloadFrame changes) and is the target cleared afterwards? Then a held button: continuous fire (the reload frame changes several times).
-- Units: Pawn (left button), Titan (right button, the laser reloads for 7.5 s). Lines "[zzren14]".
local function log(...) Spring.Echo("[zzren14] " .. table.concat({ ... }, " ")) end
local R
local steps = { { "armpw", 1, 1 }, { "armbanth", 2, 2 } } -- unit, button, weapon number
local base
local function rf(i) return Spring.GetUnitWeaponState(R.unit, i, "reloadFrame") or 0 end
local function tgt(i) return tostring((Spring.GetUnitWeaponTarget(R.unit, i))) end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, -5 end
	local k = math.floor((f - 100) / 400) + 1
	local s = steps[k]
	if not s then if f > 100 + #steps * 400 then Spring.SendCommands("quitforce") end return end
	local d = (f - 100) % 400
	if d == 0 then Spring.SendLuaRulesMsg("ren|unit|" .. s[1]) end
	if d == 40 then R.yaw, R.pitch = 330, -5 end -- far from the facing (the unit faces south after the change)
	if d == 60 then base = rf(s[3]); R.fire = s[2] end
	if d == 63 then R.fire = 0 end -- a click: three frames
	if d == 70 then log(s[1], "10 frames after the click: reloadFrame", rf(s[3]), "(before", base, ") target", tgt(s[3])) end
	if d == 150 then log(s[1], "90 frames after the click: reloadFrame", rf(s[3]), "(before", base, ") fired:", tostring(rf(s[3]) > base), "target", tgt(s[3])) end
	if d == 160 then base = rf(s[3]); R.fire = s[2] end -- held
	if d == 300 then log(s[1], "held 140 frames: reloadFrame", rf(s[3]), "(before", base, ")"); R.fire = 0 end
	if d == 330 then log(s[1], "released: target", tgt(s[3])) end
end
