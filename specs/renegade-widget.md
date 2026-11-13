# Renegade: the widget (`renegade.lua`)

Part of the specification of [Renegade](renegade.md) (overview, game options, messages, tests, open points).

What the player sees and presses: camera, mouse, crosshair, panel, dials. All of it is local (nothing here changes the game).

## Camera and views

- **Camera:** the engine camera `fps`, set every frame (`Update`) by `Spring.SetCameraState({name = "fps", mode = 0, oldHeight = 0, px, py, pz, rx, ry, rz}, 0)`.
  - **The direction comes from `rx` and `ry`, not from `dx, dy, dz` (ignored):** `rx = pi/2 - pitch`, `ry = pi - yaw`.
  - Without `mode` and `oldHeight` the engine fell back to the `spring` camera; `free`, `ta` and `spring` did not take over by name.
  - Eye = `GetUnitViewPosition` + 0.85 x `GetUnitHeight`.
  - The own unit is hidden (`SetUnitNoDraw`) and unselectable (`SetUnitNoSelect`; otherwise the screen ray answered with the own unit in many directions and a click selected it); the selection is cleared (`SelectUnitArray({})`) so the game draws no range rings.
- **Third person view (Shift, `R.third`, `setCamera`):** Shift (polled with `GetModKeyState`, the 4th value; edge detected like Alt; not while the unit menu has the keyboard) switches between the first person view and the third person view; the text "Shift: 3rd person ON/off" stands above the panel, left.
  - In the third person view the unit is drawn (`SetUnitNoDraw(u, false); NoSelect` stays) and the `fps` camera **orbits the unit at the same look direction**: the position is the eye minus the forward vector (with pitch) x `dist` plus the up vector x `up`, `dist` = 3.5 x the radius of the unit (at least 100), `up` = 0.3 x `dist` (0.12 while the panel was at the bottom in the middle, where 0.35 hid the unit behind it; with the panel at the left the camera can be higher: the unit is seen from more above, it stands at the bottom of the screen and the compass lies over it; measured with `zz_ren55.lua`), at least 8 above the ground;
    - yaw 0 looks along +z (forward = sin(yaw), cos(yaw)).
  - The direction of the camera is unchanged, so the crosshair, the aim (`aim`: the ray from the camera through the screen centre), the previews, the lock of the anti-air circle and everything else work as in the first person view; the weapons shoot at the point the crosshair points at.
  - Measured with `zz_ren55.lua` (R.third set by the test, Pawn and Behemoth looking along +z): the camera is 100 / 167 Elmo behind and 57 / 58 above, the Behemoth is seen from behind and above, above the panel; not measured: the real Shift key (the test sets `R.third`), the aircraft, the camera at a wall or in a pit.
- **Third person distance (`setCamera`):** the camera is `radius x 6` Elmo behind the unit (at least 100; before `radius x 3.5`) and `0.12 x` that distance above the eye, so that the unit stands about 7 degrees below the crosshair: a T1 or T2 unit is seen whole above the compass (Pawn: radius 18, distance 116; Bull: 32, 203), a T3 unit too (Juggernaut: 74, 483; legs at the bottom edge).
  - The earlier height factor 0.3 put the unit at the lower edge of the screen behind the dials.
  - The camera never goes under the ground (`ground + 8`): with the view tilted up on low ground the unit stands lower on the screen.
  - Measured with `zz_ren85.lua` (pictures at pitch 3).
- **Over the shoulder (`setCamera`, `side`):** the third person camera is also shifted to the right of the unit by `0.17 x` the distance (right = `(-fz, fx)` of the look direction) and sits `0.16 x` the distance above the eye: the unit stands left of the crosshair and below it, seen from behind and above, the line of fire stays free.
  - Pictures with `zz_ren85.lua` (Bull and Juggernaut at side 0.22; reduced to 0.17 afterwards so that the unit stays clear of the weapon panel; **not seen again after that change**).
- **Camera flight (`R.tr`, `setCamera`, `enable`):** the camera does not jump.
  - `enable` stores the real camera of the game (`GetCameraPosition`, `GetCameraDirection`: rx = acos(dy), ry = YAW0 - atan2(dx, dz)) as `from` of a transition of 1.1 s; Shift (first <-> third person) stores the camera of the last frame (`R.camNow`) and flies for 0.6 s.
  - `setCamera` blends position, rx and ry from `from` to the wanted camera with a smoothstep (ry the short way round); the target follows the mouse during the flight, so aiming stays possible.
  - `R.noFly` = true switches the entry flight off (for tests).
  - **Not measured in the game** (written without a test run): look and speed of the flight, the first frame after a respawn.
- **Overview camera (`overviewCam`):** switching to the normal game (key next to Shift) and a new unit while the normal game is on set the game's camera (the saved one, `R.savedCam`, or the current one) over the unit with `dist` / `height` 2200 and fly there in 0.5 - 1 s, so that the battlefield is seen.
  - Measured: camera `spring` after the switch (`zz_ren63.lua`); **not measured: how far 2200 is on a real map.**
- **Long sight (`SIGHT_FACTOR`, `farView`):** in the first / third person view enemies must not pop up at the edge of the line of sight.
  - `giveUnit` sets `Spring.SetUnitSensorRadius(unit, "los" / "airLos", SIGHT)` with the sight of the unit type times `SIGHT_FACTOR` = 3 (base value from `GetUnitSensorRadius`; measured: Pawn los 1287 / airLos 1929, Behemoth 2160 / 3240, so the engine takes it; before, a global line of sight revealed the whole map and the minimap with it, which was not wanted: the radar and the minimap show only what the sight covers; the radar of the unit is unchanged).
  - The widget (`farView(true)` in `enable`, `farView(false)` in `disable` / `Shutdown`) sends `disticon 100000` (units never become icons in the distance; back to 200) and moves the fog out (`Spring.SetAtmosphere` fogStart 1e6 / fogEnd 2e6; the old values from `GetAtmosphere` come back).
  - The far clip plane of the engine is not changed.
  - Measured: sight 4000 read back, no Lua errors; **not measured: what the view looks like** (fog, icons, enemies far away, the minimap).

## Mouse and keys

- **Mouse and keys:** each frame the cursor is read (`GetMouseState`) and warped to the middle (`WarpMouse`); the way it moved is the turn (`SENS` 0.15 degrees per pixel, mouse up = look up, right = yaw down), the cursor is "none".
  - `MousePress`, `MouseRelease` and `MouseWheel` return true while the view is on (the RTS does nothing), W A S D too.
  - The buttons are read every frame as well (a lost release must not keep the unit firing).
  - **Tab** (debug menu: free mouse, no look, no steering, no fire) is polled with `GetKeyState(9)`: as a commander the press never reached `KeyPress` (the game's own use came first).
  - **Insert** or `/renegade` switches the view off and on; `/renegade log` writes the camera state, `/renegade flip` turns the yaw offset by 180 degrees.
- **Mouse only inside the window (`widget:Update`, `outside`):** the mouse look needs `WarpMouse` to the middle every frame (there is no relative mouse mode in the Lua interface of the engine).
  - When the reported cursor position is outside the window (the player works in another program) there is no look, no `WarpMouse` and `R.fire` = 0 (before, the cursor was pulled into the window and a click elsewhere fired).
  - The key next to Shift (normal game) frees the mouse completely.
- **Mouse without focus (`R.away`):** when another window has the focus and the cursor is over the game window, `WarpMouse` does not take effect and the cursor stays away from the middle: more than 10 % of the screen from it for 6 frames in a row sets `R.away`: no look, no firing, no keys, no warp, the cursor shows.
  - The next left click in the window ends it (that click does not fire).
  - The **Windows key** sets `R.away` at once too (rising edge of the meta key of `GetModKeyState`, `R.metaWas`): the start menu or another program takes the focus and the cursor is not pulled back; it stays free, also when it comes back over the window, until a click in the window.
  - **Not measured with the real key.** **Not measured: needs a second window with the focus (the test windows have no such case).**
- **Mouse free (`R.away`), second version:** the Windows key alone was not enough (the user had half a second to move the cursor out, then it was pulled back: `WarpMouse` works without the focus while the cursor is over the window, so the "far from the middle" test never fires).
  - Now `R.away` is set (1) when the cursor is outside the window (latched: it stays free when the cursor comes back over the window), (2) by the Windows key from `KeyPress` (key 310 / 311 / 312, scan 227 / 231), the meta state of `GetModKeyState` and `GetKeyState(310 / 311 / 312)`, (3) as before by 6 frames far from the middle.
  - Only a left click inside the window ends it.
  - The log shows "key <code> scan <code>" for the first 12 keys and for the Windows key, "Windows / meta key", "cursor left the window".
  - **Not measured with the real key; the codes are the ones Spring reports for "meta" (310).**
- **Mouse free, third version (`leaving`):** the game does not report the cursor outside of the window when it leaves it (the coordinates stay inside, near the edge: logged "mouse 1299 18", "1007 23"), and no key event comes for the Windows key.
  - The cursor is at the middle all the time otherwise, so a position within 4 % (at least 30 px) of an edge counts as leaving and sets `R.away` (latched; only a left click away from the edge ends it).
  - **Not measured with the real window.**
- **Power-ups without Evolution (`R.powerups`, `R.U`):** with `lanrenepowerups` the widget loads `powerups_ui.lua` and draws the bar of the five buttons in `DrawScreen` (`U.bar`, rule `renAbilities`, `labels` = the key numbers, from 230 to 630 x scale right of the middle, 12 to 76 above the bottom: a gap of about 40 x scale to the speedometer) while the view is on, and the beacons (`U.drawBeacons("renBeacons")`) in `DrawWorld` always; the keys send `ren|use|<n>`.
- **Power-up keys (`R.evo`, `KeyPress`):** with the game option `lanevolution` the keys 1 to 5 (also the number pad, not with Ctrl, Alt or the Windows key, not while the search field is typed in) send `evo|use|<n>` (the buttons of the bar of Evolution, `powerups.lua`) while the view is on and return true (the game does not get them);
  - the bar of Evolution (`evo_ui.lua`, `H.bar`) writes the number on each button while the player steers a unit in Renegade (`labels` of `U.bar`);
  - `R.keyPress` (a function of `WG.renegade`) is the key press of the widget for the test widgets (`zz_ren91.lua`).
- **Space is the engine's meta key:** `GetModKeyState` reports the Space bar as "meta", so the Windows key poll (commit `73fc9c4`) took every Space for the Windows key: the mouse was free and Space did not lift aircraft (found in the infolog: "Windows / meta key true" with no key 310 to 312).
  - The poll now uses only `GetKeyState(310 / 311 / 312)` and the KeyPress codes.
  - `mods.meta` in the mode key test of `KeyPress` stays (Space + mode key does nothing).
- **Switch between Renegade and the normal game (`toggleMode`):** the key next to the left Shift (on a German keyboard "<" / ">", key code 60 / 62, scan code 100), **Insert** and the text command `/renegade` switch the first / third person mode off and on.
  - **Off:** `disable()` (the unit is drawn and selectable again, the keys and the mouse are not taken any more), the camera of the normal game comes back (`R.savedCam`: the camera state taken in `enable` while it was not `fps`; `SetCameraState(..., 0.5)`), and the gadget is told `ren|mode|0`: `input[team].normal` is set, holds and targets are cleared, a stop order, the fire state **2 (fire at will)** instead of 0 (hold fire), the held reloads are released (`unblock`), the team rule `renNormal` = 1;
    - while it is set the loop of the gadget skips `faceView`, `steer`, `lift` and `shoot` and `RecvLuaMsg` ignores the view messages, so the unit is an ordinary unit that can be given orders (a unit that is made after a death gets fire state 2 as well).
  - **On:** `ren|mode|1` (fire state 0, steering from the next message), `enable` takes the camera again (the third person state `R.third` is kept).
  - The key is read twice, from `KeyPress` and by polling `GetKeyState(60)` (the game may take a key before the widget, as with Tab); a press within 0.3 s of the last counts once.
  - Measured with `zz_ren63.lua` (the text command, the same function): Renegade: camera `fps`, fire state 0; normal: camera `spring`, fire state 2, `renNormal` 1, the unit selected with the information panel of the game (screenshot); back: `fps`, fire state 0, `renNormal` 0.
  - **Not measured: the real key** (a test cannot press it; the poll uses key code 60, the KeyPress also 62 and, if `Insert` is easier, that one works).
- **Full fire (Alt):** a press of Alt (polled with `GetModKeyState`, rising edge) switches `R.full` on and off; while it is on the left button sends `fire` = 7 (all three groups) and the panel shows the tag LMB (red) on every row.
  - Above the panel on the right: "Alt: FULL FIRE ON" / "off".

## Aim, crosshair, rings and arrows

- **Ray (`aim`):** `TraceScreenRay(middle, false, false, true)` gives `"unit", id` or `"ground", {x, y, z}` (the table also with `onlyCoords`).
  - The engine answered "sky" for slopes of the heightmap (ground 337 to 560 Elmo away at pitch 3 degrees), so `march` follows the view ray over `GetGroundHeight` in steps of 24 Elmo (bisected at the hit, inside the map only); mountains outside the map have no heightmap and stay "sky".
  - `R.hit` = unit or ground point, distance from the eye and from the unit (`udist`); `R.shot` = `R.hit`, or a point 3000 Elmo along the ray in the sky.
- **Crosshair and weapon rows (`reach`, `dropper`):** four lines;
  - for every group of weapons (its first weapon) `reach` tells whether it is valid for what `R.hit` is (an aircraft: only anti-air weapons `renAA` and the hybrid ones `renHY`; anything else: not the anti-air-only ones) and compares the distance from the unit (`udist`) with its range: **green** up to 90% of the range, **yellow** up to 110% (`EDGE` 0.1), **red** beyond or when the weapon cannot hit this target.
  - The crosshair has the best colour of all groups (green as soon as one valid weapon reaches the target), white for the sky; the rows of the panel get the colour of their own weapon as a tint (none for the sky, and none for an aircraft or a bomber: `dropper`).
  - Text under the crosshair: "Pawn 100%  151 m" / "ground  84 m" / "sky" (the distance; no IN RANGE text any more).
  - `R.best` and `R.states` hold the colours for the tests.
  - Measured with `zz_ren33.lua` (Titan with ranges 465, 800, 860, an enemy walks up): distance 1819-1138 all red, 871 yellow (rows red, yellow, yellow), 742 green (red, yellow, green).
  - The range rings are only drawn with `/renegade rings` or the debug button "Range rings: on/off" (third button above the panel, `R.btn3`; `R.rings`, off at the start).
- **Anti-air circle (`aaPick`):** shown when the unit has weapons in `renAA` or `renHY`: an orange circle of 15 % of the screen height (`AA_RADIUS`) round the crosshair.
  - Of the visible enemy units (`GetVisibleUnits(ENEMY_UNITS)`) that fly (`canFly`), are in front of the camera and within the longest range of those weapons, the one whose picture (`WorldToScreenCoords`) is nearest to the middle inside the circle is the lock `R.aaTarget` (an orange square and "AA LOCK <name>");
    - with a lock the circle **glows** (bright yellow, 3.5 pixels, three wider translucent rings that pulse).
  - The lock is the `unit` of the message.
- **Rings and barrel lines (`DrawWorld`, depth test off, thickest first):** for each group a ring (`gl.DrawGroundCircle`) of its range and a line on the ground from the unit in the direction its barrel points now (`GetUnitWeaponVectors` of the first weapon: straight up while it is not aiming, then the aim direction; a nearly vertical direction is replaced by the unit's facing; at most 260 Elmo): you look round faster than the turret turns, fire when the line points where you look.
  - Left red 3 pixels, right yellow 5, middle green 7, so all show when they lie on each other.
  - The lines were not seen on a picture yet.
- **Crosshair information (`DrawScreen`, `text`):** the text under the crosshair is a list of lines (`text` with newlines): unit: name, health, distance; ground: "ground", distance; bomber: "BOMBS READY" / "almost" / "TOO HIGH", height, hint; turret cone and steep hint likewise.
  - Each line is drawn left-aligned, one under the other, at the **lower right** of the crosshair: x = centre + 1.8 s, y = centre - 2.2 s going down by 1.25 x the font size (`s` = vsy / 90 is the size of the crosshair), so the crosshair stays free and a long text runs away from it.
  - Measured: screenshot with `zz_ren74.lua` ("BOMBS READY" and "156 m" in two lines at the lower right).
- **Facing arrow (`facingArrow`):** a small thick green arrow on the ground in front of the unit (25 to 100 Elmo, black outline) in the direction the unit faces (`GetUnitDirection`): the way it walks or drives when W is pressed; a tank has to turn first when you look behind you.
- **Turret arrow:** the green arrow of a unit that cannot move (`not ud.canMove`) points the way the weapon of the first button group points now (`GetUnitWeaponVectors`), not the way the building faces; a mobile unit keeps the arrow of its facing.
- **Impact preview (`impactPreview`, in `DrawWorld`):** for each button group whose first weapon is lobbed (type MissileLauncher, StarburstLauncher, ArtilleryShell, or a Cannon with `highTrajectory` >= 1 or range >= 800; not anti-air) the point under the crosshair (`R.hit`: ground or unit; nothing in the sky), shortened to the reach of the weapon, is drawn as a translucent disc of the explosion size (half of `damageAreaOfEffect`, which is the diameter; at least 8) with a black-edged ring, a cross (no beam any more: it was in the way) and a thin line from the unit, all in the color of the button.
  - **Bombs** (type `AircraftBomb`): the preview shows where a bomb dropped now would land: the position of the aircraft moved by its velocity (`GetUnitVelocity`) for the fall time over the ground height (gravity `Game.gravity` / 900 per frame, four passes), no aim point needed.
  - The gadget sets the same point (`bombPoint`, refreshed every frame for aircraft) as the target of a bomb weapon instead of the crosshair point, so the bombs fall at once: measured with a Thunder at 426 Elmo height: the first bomb 4 frames after the press (`zz_ren18.lua`).
  - Not measured with a picture yet; the scatter of the weapon is not drawn.

## Weapon panel

- **Panel (`panel`):** right of the middle at the bottom (the game's buttons are left of it): the health bar (red to green, "HEALTH 370 / 370"), then one row per button group: description of its weapon ("x3" for several), tag LMB red / RMB yellow / MMB green, range (the longest of the group), reload time, READY / reloading and a bar in the color of the button (from `reloadFrame` and `reloadTime` of the first weapon; a `reloadFrame` of 500000 or more is the gadget holding a weapon that only aims: READY);
  - an orange "AIR ONLY" under the tag for anti-air groups (they fire only at an aircraft in the circle) or "(aircraft in the circle: lock; ground: aim)" for those groups.
  - The groups come from `renSlots` (cached by the three parameter texts: a Pawn and an anti-air turret both have "1;;").
- **Layout of the panel (`panel`, `debugButton`, `altimeter`):** from the top: the three debug buttons (cards with a gradient and an edge, `card()`), the health bar with the **name of the unit** at the left and `hp / max` at the right, then one card per weapon (68 high).
  - A weapon row shows the **name of its picture** (`niceName`: `laser-light` = "Light Laser", `machine-gun-heavy` = "Heavy Machine Gun", a few special names in `NICE_NAMES`; a weapon without a picture keeps its technical name; `x2` for two weapons that fire together), the button as a badge at the top right, and below four values, each with a symbol (drawn with lines: range = target ring, reload = clock, damage = burst, DPS = rising bars) and a small label: **RANGE, RELOAD, DAMAGE** (one shot with all its projectiles: `damages[default armor] x projectiles`; an anti-air weapon against aircraft) and **DPS** (orange: damage x salvo size x weapons of the group / reload time; `weaponStats`).
  - A bomber shows DROPS BELOW and NOW instead of RANGE; an AUTO row shows RANGE (`map` from 20000) and "fires by itself".
  - A dark veil and a darker strip behind the values keep them readable over the picture.
  - **Altimeter:** the scale shows the height above the sea level (0 = sea level);
    - the ground is a **yellow** part at the bottom up to the height of the ground under the unit, above it the height in the air (blue, orange when an aircraft is below 40 m);
    - an aircraft's scale reaches up to the ground plus its highest height, any other unit's up to 600 (or the ground + 100);
    - the number on top is the height above the ground (aircraft) or the height of the ground (others);
    - `GROUND n m` in yellow below the bar.
  - Measured with `zz_ren47.lua` (Behemoth with D-Gun and heavy lasers, Whirlwind bomber): screenshots look right, DPS of the two heavy lasers 500 (75 x 2 / 0.3 s).
- **Panel, second round (the pointers and the arrow on the ground of this round were replaced by the compass below):** the panel is 502 wide with a picture (432 without; 35% more), a row is 80 high (the picture of 6 : 1 is no longer squeezed);
  - **the button (LMB, RMB, MMB, AUTO; `AIR ONLY` under it) is a coloured column at the right of the card**, outside of the picture;
  - the rows are **sorted by range** (shortest on top, `table.sort` with the order of the buttons as the tie breaker; AUTO rows last);
  - the buttons above are labelled "Unit", "Spawn", "Range" (no "v").
  - **In the world** (`DrawWorld`): the barrel lines are replaced by a flat **pointer** (`pointer`: an arrowhead in the colour of the button with a dark edge, side by side for the groups; the direction of the barrel as before);
    - the green facing arrow lies nearer;
    - both scale with the height of the eye (`size` = eye height above the ground / 45, 0.33 to 1.6: a Pawn at 20 Elmo sees a Behemoth-sized arrow huge otherwise; nearer than about three eye heights the panel hides them).
  - **Previews** (`impactPreview`): for bombs (disc, ring and the line to the landing point) and for the arc weapons (see below: disc and ring, no line); the flat shooters have only the crosshair colour.
  - **List of the players** (`scoreboard`, top right under the menu bar, like the overview of Evolution): colour of the team, name (`GetPlayerInfo` of the leader, `GetAIInfo` for an AI), the unit (or "respawning"), kills K and deaths D; the most kills on top, the own row highlighted; as many rows as fit above the altimeter, then "+N more".
  - The gadget counts: `UnitDestroyed(u, defID, team, attackerID, attackerDefID, attackerTeam)` raises the team rules parameter `renKills` of the attacking team for every enemy unit it destroys and `renDeaths` of a team when its player unit dies.
  - Measured with `zz_ren48.lua` (Pawn, Behemoth, Gunslinger): list shows "Player" with the unit, K 0 D 0; the order of the rows is 435, 550, 590 for the Behemoth.
- **Position of the panel:** the panel of the weapons (with the debug buttons and the texts above it) is at the **left side** of the screen, `x1 = 8 x scale`, `y1 = 8 x scale`: in the bottom left corner, growing upwards (there is no build menu at the left in this mode), so that the middle of the screen, above all in the third person view, stays free;
  - the list of the players and the altimeter stay at the right, the compass is at the bottom in the middle.
  - Measured: screenshot with `zz_ren48.lua` (earlier with `y1` = 210 x scale above a menu that does not exist).
- **Colours of the rows:** every row has the same neutral blue-grey edge and button box (the colours red / green / yellow of the buttons were dropped from the panel: too colourful; they remain for the pointers on the ground); only the tint of the reach (green / yellow / red over the card) is left.
- **Values and symbols (third round):** the order is RANGE, SHOTS / S (`rate` = salvo size / reload time; one decimal, two below 0.1; was the reload time), DAMAGE (one shot), DPS (orange).
  - Symbols drawn with `gl` in `icon`: range = target ring, rate = a bullet with speed lines, damage = an explosion (a jagged filled star), dps = damage over time (axes, a curve that rises faster and faster, an arrowhead).
  - The list of the players uses the symbols of Evolution for kills (a crosshair) and deaths (a skull; `crosshair`, `skull` copied from `evo_game.lua`) in its header instead of K and D.
- **Panel above the info panel of the game (`panel`):** the info panel of the game (the unit under the cursor, bottom left) covered the weapon panel.
  - The panel's lower edge is now raised by the height of that panel: `WG["info"].getPosition()` returns the width and the height as fractions of the screen (measured at 1600 x 900: 0.199, 0.131), plus 6 s.
  - Measured with `zz_ren83.lua` (picture: the panel above the info panel of the game, no overlap).
- **Binoculars indicator (`panel`):** a unit that has the binoculars (`zoomLevels` above 0) gets a small card right of its weapon panel (76 x 82 x scale, at the bottom): a binoculars symbol (two rings, a bridge, eyepieces), two triangles for the mouse wheel (down and up) and the word "wheel";
  - while the binoculars are on the edge and the symbol are light blue and the word becomes the magnification ("x2").
  - Not drawn for a unit without them.
  - Screenshot with `zz_ren71.lua` (Sharpshooter).

## Compass, speedometer, health bar, altimeter

- **Compass (`compass`, replaces the arrows on the ground):** a round dial at the bottom in the middle of the screen (radius 62 x scale).
  - Up on the dial = the way you look (`GetCameraVectors`: forward, right);
    - the **green arrow** is the way the vehicle drives (`GetUnitDirection`; for a turret its first weapon points), the **coloured arrowheads at the rim** are the barrels of the groups of weapons (`GetUnitWeaponVectors`, the colour of the button; a weapon that does not aim reports straight up: then the facing of the unit counts).
  - An arrow that points up: the vehicle goes where you look.
  - The green and red arrows and the barrel lines on the ground are gone from `DrawWorld` (`pointer`, `facingArrow` removed); the glowing line that shows where the unit wants to go (the engine's) stays.
  - Measured with `zz_ren52.lua` (Bull `armbull`: `skyShot` at 437 = 0.95 x 460, so the Bulldog qualifies as an arc weapon; Mauser as before): the dial shows the green arrow up and a red arrowhead.
- **Speed display, second version (`compass`, health bar):** the digital box is gone.
  - **Speedometer** right of the compass (a dial of radius 50 x scale): 0 to 150 (higher for a faster unit, in steps of 50: `scale`), 270 degrees from bottom left over the top to bottom right, ticks every 25, numbers every 50, a red **needle** for the speed now (`GetUnitVelocity` x `Game.gameSpeed`, Elmo per second, all three directions) and the speed as a **digital number in a dark box at the bottom of the dial** (size 24 x scale; between the 0 and the 150 labels), a yellow tick at the highest speed of the unit (`UnitDef.speed`).
  - **"max speed N"** stands in the middle of the health bar (the user asked for it next to the weapon values; the rows are full, so it is in the bar).
  - Measured: screenshot with `zz_ren71.lua` (the needle at 0, the yellow tick at 33 for the Sharpshooter); the number next to the dial text "SPEED" overlapped the labels and was dropped.
- **Health bar under the dials (`compass`):** the health bar (red to green, the name of the unit at the left, the numbers at the right) is under the compass and the speedometer (the dials moved up by 30 s); the weapon panel at the left has only the weapons (the "max speed" text is gone: the yellow mark of the speedometer shows it).
  - Picture in the test `zz_ren83.lua`.
- **Altimeter scale and the jump of the view:** the altimeter is a **fixed scale from 0 (sea level) to 500 m above it** (`ALT_MAX` 500, a tick every 100); a marker beyond the ends stays at the edge.
  - **Bug "the view suddenly jumps straight up":** the mouse look (`Update`) took the distance of the cursor from the middle as the turn; a cursor that was somewhere else (after the menu, after the window or the game had a pause, a hitch of the frame, a warp that did not take effect) gave one huge turn that the clamp at +-89 degrees turned into "straight up".
  - Not reproduced; fixed by guarding: a jump of more than 40% of the screen in one frame, a gap of more than 0.25 s between two frames and the first frame after the menu (`R.skipLook`) only put the cursor back (`R.lookSkipped` counts them for the tests).
- **Altimeter layout and the red MAX mark (`altimeter`, rules parameter `renMaxAlt`):** the height number on top, "GROUND" and below it the ground height (two lines) and the hints "Space up" / "Ctrl down" are centred on the card (`mid`; the card is 20 x scale taller at the bottom); before, the right-aligned texts stuck out at the left edge.
  - The gadget publishes `renMaxAlt` (`maxAlt(unit)`, the highest height above the ground) in `giveUnit`; for an aircraft the widget draws a red line with "MAX" at `ground + renMaxAlt` (it moves with the ground under the unit; at the top edge of the scale when higher).
  - Measured with `zz_ren74.lua` (screenshot): the line is at the marker when the Stormbringer is at its ceiling (248 over the ground).

## Binoculars

- **Binoculars (`toggleZoom`, `zoomStep`, `binoculars`):** the **middle button** switches them on and off **when the unit has no weapon on it** (`slots.M` empty: the 95 of the 448 units with a button that use the middle button for a weapon keep it: the Behemoth, the Myrmidon and others; checked in `renegade_weapons.csv`), **B** does it for every unit;
  - only for units whose longest range is **at least 600** (`zoomLevels`: 210 of the units without a middle button weapon have 600 or more, 174 have 700 or more, 118 have 800 or more) and below 20000 (no anti-nuke).
  - Levels: **one level per 300 Elmo of range** (`ZOOM_STEP`; 900 = 3, 1450 = 4, at most 6), the magnification is 1 + level;
    - the **mouse wheel** works as the main control (`zoomStep`, for every unit with a range of 600 or more, also one with a weapon on the middle button): **forward switches the binoculars on (level 1) and zooms in, back zooms out, one step back from level 1 switches them off**;
    - the middle button and B stay as switches.
  - **Field of view:** the `fps` camera state takes `fov` (measured: 45 degrees normally, 23.4 at x2, 11.8 at x4; `R.baseFov` is read when Renegade starts, `setCamera` writes `fov`); the mouse look is divided by the magnification (`SENS / zoomFactor()`), the aim works through the screen centre as before.
  - Drawn: the view in a circle (0.46 of the screen height) with a soft dark edge and black outside, a thin cross with a gap, "xN" and the keys at the top.
  - Switched off on a new unit and when Renegade is switched off.
  - Measured with `zz_ren71.lua`: Sharpshooter (900): middle button zoom 1 (fov 23.4), wheel to level 3 (fov 11.8), one down, middle again off (back to 45); Behemoth (range 590): "no binoculars", zoom stays 0.
  - Not measured: the real middle button press and the wheel (the test calls `R.toggleZoom` / `R.zoomStep`), a unit with a middle button weapon and a range above 600 (only B).

## Damage numbers, loss and respawn

- **Damage numbers:** every hit on a unit that the player can see (line of sight; all units, not the own one) shows as a red number (blue for paralyzer damage) over the unit that rises and fades (1.6 s); hits on the same unit within 0.7 s are added up, so the number counts up under steady fire.
  - The synced gadget `renegade_game.lua` has `gadget:UnitDamaged` and sends each hit with `SendToUnsynced("renDmg", unit, damage, paralyzer)`; its unsynced part (a `return` at the top of the file used to end it) passes it to the widget global `renDamage` (`widgetHandler:RegisterGlobal`), `R.damaged` and `drawDamageNumbers` in `renegade.lua` (at most 80 numbers).
  - The callin `widget:UnitDamaged` itself never arrived in the widget (tested: no call).
  - Tested with `zz_ren88.lua` (test enemy 150 Elmo ahead, shot at: red 17 over it).
- **Loss:** while `renRespawn` is in the future "YOU DIED" and "respawn in 5" ... "1" in big letters (`countdown`, also without the view); the view comes back by itself when the unit appears.
- **Respawn:** with no own unit `Update` calls `disable()` (`R.on` false, `R.third` is kept); the new unit goes through `enable` again, which now hides the model only when `not R.third` (before, it always hid it, so in the third person view the camera was right but the unit was invisible / the view wrong until Shift was pressed twice) and starts the camera flight from the old camera.
  - In the normal game (`R.off`) a new unit (`R.seen`) makes the game camera fly to it (`SetCameraState` with the unit's px, pz, 1 s); the key next to Shift goes into it.
  - **Not measured in the game.**

## Debug menu and test hooks

- **Debug menu (`lanrenedebug`):** above the panel three buttons side by side (`debugButton`): "Unit v" (`R.btn`; the name of the unit is now in the health bar), "Spawn v" (`R.btn2`) and "Range" (`R.btn3`, the range rings: green when on, red when off).
  - A click (with the mouse free, Tab) opens the unit menu of the Level Editor (`Shared.newUnits` of `editor_common.lua`, loaded by `VFS.Include("luaui/Include/editor_common.lua")`): search field (`ownText`, `widget:TextInput`; Enter = done, Esc = clear, Tab leaves), rows faction (Armada, Cortex, Legion), group (Turrets, Bots, Vehicles, Hover, Air, Ships), tech level, the pictures of the units that have a weapon, the mouse wheel scrolls, no 3D preview.
  - In the mode of "Debug unit" a click on a picture sends `ren|unit|<name>` and leaves the menu; in the mode of "Spawn enemy" (`R.pickMode = "enemy"`) it sends `ren|spawn|<name>` and the menu stays open.
- **Information under the unit menu (`drawPicker`, `pickerLayout`):** the text under the pictures was the scale of the small pictures (about 10 pixels): now it is as large as the panel (`sc` = screen height / 1080, at least 0.8; the window is at least 780 x `sc` wide and has 150 x `sc` of room at the bottom).
  - For the unit under the mouse pointer: line 1 "**Name (code)**" (once) followed by the **description** (`translatedTooltip`);
    - line 2 **speed** and **health**;
    - then **one line for each weapon definition** (the three with the shortest range, like the panel; a weapon that is there several times says "x2"): description, **range, shots per second** (salvo size / reload), **damage** of a shot (all projectiles; against aircraft for an air-only weapon, marked "(air)") and **DPS**.
  - Without a unit under the pointer the hint is shown.
  - `R.testHover` (an index into the list) is for the tests (`zz_ren72.lua`, screenshots).
  - Not measured: units with several weapons or an air-only weapon in the menu (the first screenshot is a Tick with one laser).
- Test hooks: `WG.renegade` is the state table (`fake` = the test widget steers: yaw, pitch, keys, fire; `menu`, `list`, `pickMode`, `hit`, `shot`, `aaTarget`, `aaCircle`, `unit`).
