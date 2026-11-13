"""Writes the three demo levels (Tower Defense, Capture the Flag, Reclaim the Fame) into LevelEditor/levels.

Run: python make_demo_levels.py [target folder]   (default: ../../levels)
All three levels are on the flat map "Full Metal Plate 1.7" (12288 x 12288, height 449), so units never get stuck.
"""
import json
import os
import sys

MAP = "Full Metal Plate 1.7"
SIZE = 12288
Y = 449
GRID = 16

OPTS = '\trequiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1" },\n'


def scenario(title, summary, briefing, sid, metal, energy, grace=0):
    d = {
        "version": 2, "title": title, "author": "Level Editor", "summary": summary, "briefing": briefing,
        "roles": {"0": "s", "1": "e"}, "tiers": {"0": "123", "1": "123"}, "ai": "BARb", "win": "neverend",
        "metal": metal, "energy": energy, "grace": grace, "sid": sid,
    }
    return "\tscenario = [==[" + json.dumps(d, indent=1) + "]==],\n"


def unit(name, x, z, team, wall=False):
    extra = ", neutral = true, indestructible = true" if wall else ", neutral = false"
    return "\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = 0, team = %d%s },\n" % (name, x, Y, z, team, extra)


def feature(name, x, z):
    return "\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = 0 },\n" % (name, x, Y, z)


def head(comment):
    return "-- Level Editor: saved for scenariooptions.unitloadout and featureloadout\n-- " + comment + "\nreturn {\n\tmap = \"%s\",\n\tmapsize = { %d, %d },\n\tunitlimit = 32000,\n" % (MAP, SIZE, SIZE)


def snap(v):
    return int(round(v / GRID)) * GRID


# ---------------------------------------------------------------- Tower Defense: a serpentine corridor
def corridor_walls(points, half=64):
    """Wall pieces (cells of 16 Elmo) around a corridor along the axis-parallel polyline `points`."""
    cells = set()
    for (x1, z1), (x2, z2) in zip(points, points[1:]):
        for cx in range(snap(min(x1, x2) - half) // GRID, snap(max(x1, x2) + half) // GRID + 1):
            for cz in range(snap(min(z1, z2) - half) // GRID, snap(max(z1, z2) + half) // GRID + 1):
                cells.add((cx, cz))
    walls = set()
    for cx, cz in cells:
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                n = (cx + dx, cz + dz)
                if n not in cells:
                    walls.add(n)
    return sorted(walls)


def tower_defense():
    xa, xb = 4200, 8200
    lanes = [4800, 5900, 7000, 8100]
    pts = [(xa, lanes[0]), (xb, lanes[0]), (xb, lanes[1]), (xa, lanes[1]), (xa, lanes[2]), (xb, lanes[2]), (xb, lanes[3]), (xa, lanes[3])]
    walls = corridor_walls(pts)
    waves = [
        ("arm", "vb", "1", 6, 0, 100), ("cor", "vb", "1", 8, 45, 100), ("leg", "vb", "1", 10, 45, 120),
        ("armcor", "vbh", "1", 12, 50, 150), ("corleg", "vb", "12", 12, 50, 170), ("armleg", "vbh", "12", 14, 55, 200),
        ("armcorleg", "vb", "12", 16, 55, 250), ("armcorleg", "vbh", "2", 14, 60, 300),
        ("armcorleg", "vb", "12", 20, 60, 350), ("armcorleg", "vbh", "23", 20, 70, 450),
    ]
    s = head("Demo: Tower Defense - Serpentine. Build towers in the three open strips between the lanes; ten waves walk the 19,000 Elmo long corridor.")
    s += scenario("Serpentine (Tower Defense)", "Ten waves walk a long zigzag corridor: build towers in the strips between the lanes",
                  "Enemies walk the corridor from the west end of the top lane to the goal at the bottom. The walls cannot be destroyed or taken apart. "
                  "Build towers in the three open strips between the lanes, keep your economy running and let at most 10 enemies through.",
                  "demo-td-serpentine", 2500, 5000)
    s += "\ttowerdefense = {\n\t\tbanned = { },\n\t\tbannedTech = { },\n\t\teconomy = true,\n\t\tenabled = true,\n\t\tfog = false,\n"
    s += "\t\tgoal = { %d, %d },\n\t\tleaks = 10,\n\t\tspawn = { %d, %d },\n" % (xa + 60, lanes[3], xa + 60, lanes[0])
    s += "\t\twaves = {\n"
    for fac, kind, tech, count, gap, hp in waves:
        s += '\t\t\t{ count = %d, fac = "%s", gap = %d, hp = %d, kind = "%s", tech = "%s" },\n' % (count, fac, gap, hp, kind, tech)
    s += "\t\t},\n\t\twaypoints = {\n"
    for x, z in pts[1:-1]:
        s += "\t\t\t{ %d, %d },\n" % (x, z)
    s += "\t\t},\n\t\twidth = 8,\n\t},\n" + OPTS
    s += "\tunitloadout = {\n"
    mid = (lanes[1] + lanes[2]) // 2
    s += unit("armcom", 6144, mid, 0)
    for i in range(4):
        s += unit("armck", 5900 + i * 160, mid + 150, 0)
    for i in range(3):
        s += unit("armllt", 5700 + i * 400, mid - 250, 0)
    for cx, cz in walls:
        s += unit("armfort", cx * GRID, cz * GRID, 0, wall=True)
    s += "\t},\n\tfeatureloadout = {\n\t},\n}\n"
    return s, len(walls)


# ---------------------------------------------------------------- Capture the Flag: chicanes in the middle
def barrier(x, z1, z2, name):
    out = []
    z = snap(z1)
    while z <= z2:
        out.append((snap(x), z))
        z += GRID
    return out


def capture_the_flag():
    west, east = 3400, SIZE - 3400
    cw, ce = west + 500, east - 500
    s = head("Demo: Capture the Flag - Crossroads. Two bases, three neutral flags in the middle behind two chicanes; hold 4 flags to win.")
    s += scenario("Crossroads (Capture the Flag)", "Two teams, three neutral flags in the middle, two flags in each base: hold 4 flags at once",
                  "Take the three neutral flags in the middle and steal flags from the enemy base. Every flag at your collection point pays 5 metal per second. "
                  "Whoever holds 4 flags at once wins. The unit that carries a flag cannot shoot, so escort it.",
                  "demo-ctf-crossroads", 3000, 5000)
    s += "\tcapture = {\n\t\tamount = 5,\n\t\tenabled = true,\n\t\tflags = {\n"
    for z in (5300, 6988):
        s += "\t\t\t{ team = 0, x = %d, z = %d },\n" % (west - 100, z)
        s += "\t\t\t{ team = 1, x = %d, z = %d },\n" % (east + 100, z)
    for z in (4900, 6144, 7388):
        s += "\t\t\t{ team = -1, x = 6144, z = %d },\n" % z
    s += "\t\t},\n\t\thomes = {\n"
    s += "\t\t\t{ team = 0, x = %d, z = 6144 },\n\t\t\t{ team = 1, x = %d, z = 6144 },\n" % (cw, ce)
    s += "\t\t},\n\t\tradius = 100,\n\t\treturnTime = 60,\n\t\tscore = 4,\n\t\tspeed = 50,\n\t\tvisible = true,\n\t},\n" + OPTS
    s += "\tunitloadout = {\n"
    for team, base, sign, com, bld, fast in ((0, west, 1, "armcom", "armck", ("armflash", "armpw", "armfast")), (1, east, -1, "corcom", "corck", ("corgator", "corak", "corfast"))):
        s += unit(com, base, 6144, team)
        for i in range(2):
            s += unit(bld, base + sign * 250, 5900 + i * 490, team)
        for i, name in enumerate(fast):
            s += unit(name, base + sign * 700, 5700 + i * 400, team)
        s += unit(fast[0], base + sign * 700, 6900, team)
    walls = []
    for x in (5300, 6988):
        walls += barrier(x, 3900, 5500, "armfort") + barrier(x, 6800, 8400, "armfort")
    # a short wall next to every collection point as cover
    for x in (cw + 400, ce - 400):
        walls += barrier(x, 5700, 6600, "armfort")
    for x, z in walls:
        s += unit("armfort", x, z, 0, wall=True)
    s += "\t},\n\tfeatureloadout = {\n\t},\n}\n"
    return s


# ---------------------------------------------------------------- Reclaim the Fame: crystal fields
def reclaim_the_fame():
    west, east = 3400, SIZE - 3400
    c = SIZE // 2
    crystals = []
    # contested middle: one large, four medium
    crystals.append(("pilha_crystal3", c, c))
    for dx, dz in ((0, 1400), (0, -1400)):
        crystals.append(("pilha_crystal2", c + dx, c + dz))
    for dx in (-900, 900):
        crystals.append(("pilha_crystal2", c + dx, c))
    # flanks and the paths to the bases: small crystals, mirrored
    for dx, dz in ((1300, 2300), (-1300, 2300), (1300, -2300), (-1300, -2300), (2100, 900), (-2100, 900), (2100, -900), (-2100, -900)):
        crystals.append(("pilha_crystal1", c + dx, c + dz))
    # two small ones at every base
    for x in (west + 900, east - 900):
        for dz in (-900, 900):
            crystals.append(("pilha_crystal1", x, c + dz))
    s = head("Demo: Reclaim the Fame - Crystal fields. A large crystal in the middle, medium ones around it, small ones near the bases; first to 3000 points wins.")
    s += scenario("Crystal Fields (Reclaim the Fame)", "Reclaim crystals with your builders, defend them and hunt the enemy's: first to 3000 points wins",
                  "Crystals pay points to the construction units that reclaim them: 1 point per second for every 100 build power, more for bigger crystals. "
                  "Send builders to the middle, protect them and build defenses. The first team at 3000 points wins.",
                  "demo-rtf-crystal-fields", 2500, 5000)
    s += "\treclaim = {\n\t\tenabled = true,\n\t\tscore = 3000,\n\t\trate = 100,\n\t\tf1 = 100,\n\t\tf2 = 200,\n\t\tf3 = 400,\n\t\tvisible = true,\n\t\tstatics = false,\n\t\tground = true,\n\t\tships = true,\n\t\tair = false,\n\t},\n" + OPTS
    s += "\tunitloadout = {\n"
    for team, base, sign, com, bld, army in ((0, west, 1, "armcom", "armck", "armpw"), (1, east, -1, "corcom", "corck", "corak")):
        s += unit(com, base, c, team)
        for i in range(4):
            s += unit(bld, base + sign * 450, c - 450 + i * 300, team)
        for i in range(4):
            s += unit(army, base + sign * 900, c - 450 + i * 300, team)
    s += "\t},\n\tfeatureloadout = {\n"
    for name, x, z in crystals:
        s += feature(name, x, z)
    s += "\t},\n}\n"
    return s, len(crystals)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "levels")
    os.makedirs(out, exist_ok=True)
    td, walls = tower_defense()
    files = {"demo_td_serpentine.lua": td, "demo_ctf_crossroads.lua": capture_the_flag()}
    rf, n = reclaim_the_fame()
    files["demo_rtf_crystal_fields.lua"] = rf
    for name, text in files.items():
        with open(os.path.join(out, name), "w", encoding="utf-8", newline="") as f:
            f.write(text)
        print(name, len(text), "bytes")
    print("walls:", walls, "crystals:", n)


main()
