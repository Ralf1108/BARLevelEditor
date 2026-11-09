"""Makes the table of the unit candidates of Evolution (LevelEditor/game-modes/evolution-units.md and evolution_units.csv).

Input: the lines "[zzunit] ..." that tools/zz_unitdump.lua writes into the infolog of a sandbox run (pve_test.ps1 -Widget zz_unitdump.lua), and
shared/unit_categories/unit_categories.json (type of a unit: bots, vehicles, hover, air, sea). The level of a unit: the Evolution level whose
reference units (the current LADDERS of evo_game.lua) have the closest score = damage per second x health (on a logarithmic scale).
Usage: python evolution_units.py <infolog.txt>
"""
import json, math, re, sys, os

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
log = sys.argv[1]
FACTION = {"arm": "Armada", "cor": "Cortex", "leg": "Legion"}
cats = {u["code"]: u for u in json.load(open(os.path.join(repo, "shared", "unit_categories", "unit_categories.json"), encoding="utf-8"))}

# the current ladders of evo_game.lua (level = index)
src = open(os.path.join(repo, "LevelEditor", "scripts", "evo_game.lua"), encoding="utf-8").read()
block = src[src.index("local LADDERS = {"):]
block = block[:block.index("\n}\n")]
ladder = {}
for row in re.findall(r"\{([^{}]*)\}", block.split("\n", 1)[1]):
    for i, n in enumerate(re.findall(r'"(\w+)"', row), 1):
        ladder[n] = i

units = []
for line in open(log, encoding="utf-8", errors="replace"):
    m = re.search(r"\[zzunit\] (.*)$", line.rstrip())
    if not m or m.group(1) == "done":
        continue
    f = m.group(1).split(";")
    if len(f) < 13:
        continue
    name, fac, human, tech, dps, aa, hp, metal, speed, rng, move, flags, weapons = f[:13]
    if re.search(r"scav|raptor", name + " " + human, re.I):
        continue   # (the Scavenger and Raptor copies are not listed at all)
    units.append(dict(name=name, fac=FACTION[fac], human=human, tech=tech, dps=float(dps), aa=float(aa), hp=float(hp), metal=float(metal),
                      speed=float(speed), range=float(rng), move=move, flags=flags, weapons=weapons))

def kind(u):
    c = cats.get(u["name"], {}).get("category", "")
    if "fly" in u["flags"]: return "Air"
    if c == "sea" or "water" in u["flags"] or u["move"].startswith(("boat", "ship", "sub")): return "Sea"
    if c == "hover" or u["move"].startswith(("hover", "hhover", "ahover")): return "Hover"
    if c == "bots" or u["move"].startswith(("kbot", "bot", "abot", "sbot", "hbot", "tbot", "habot", "htbot", "vbot", "epicbot", "epicallterrain")): return "Bot"
    if c == "vehicles" or u["move"].startswith(("tank", "atank", "htank", "mtank", "vehicle", "epicveh")): return "Vehicle"
    return c.capitalize() or u["move"]

# left out by hand (the name of the unit: the reason)
MANUAL = {"corjugg": "too slow (speed 17)", "corban": "missile launcher"}

def why(u):
    """why a unit is not included in Evolution (empty: it is included)"""
    r = []
    ws = [w.split(":") for w in u["weapons"].split()]
    main = max([w for w in ws if w[0] != "StarburstLauncher"] or ws, key=lambda w: float(w[2])) if ws else None   # (the weapon with the most damage per second; Starburst launchers are stockpiled missiles)
    if u["move"] in ("commanderbot", "scavcommanderbot"): r.append("commander")
    if "drone" in u["name"]: r.append("drone")
    if "builder" in u["flags"]: r.append("constructor")
    if "fly" in u["flags"]: r.append("aircraft")
    if kind(u) == "Sea": r.append("water unit")
    if re.search(r"mine ?layer|minesweeper|mine", u["human"], re.I): r.append("mine layer")
    if re.match(r"(Epic|Archaic) ", u["human"]): r.append("Epic / Archaic variant")
    if "Tumbleweed" in u["human"]: r.append("Tumbleweed")
    if u["dps"] <= 0 and not r: r.append("no ground weapon (radar, jammer, spy, anti air, crawling bomb)")
    # artillery / rocket launcher: the description of the unit says so, or its main weapon reaches 1000 Elmo or more
    desc = cats.get(u["name"], {}).get("description", "")
    if not r and (re.search(r"artillery|rocket|missile launcher|mortar|howitzer|mlrs", desc + " " + u["human"], re.I) or (main and main[0] in ("Cannon", "MissileLauncher") and float(main[1]) >= 1000)):
        r.append("artillery / rocket launcher")
    if not r and u["dps"] * u["hp"] < 10000: r.append("scout: DPS x health below 10000")
    if not r and main and main[0] in ("MissileLauncher", "StarburstLauncher") and u["name"] not in ladder: r.append("rocket launcher (mainly a missile weapon)")
    if not r and u["dps"] < 40: r.append("weak support: DPS below 40")
    if not r and u["name"] in MANUAL: r.append(MANUAL[u["name"]])
    return ", ".join(r)

for u in units:
    u["type"] = kind(u)
    u["score"] = u["dps"] * u["hp"]
    u["note"] = why(u)
    u["ladder"] = ladder.get(u["name"], "")

# the reference score of every level: the geometric mean of the ladder units of the three factions
ref = {}
for lvl in range(1, 11):
    s = [u["score"] for u in units if u["ladder"] == lvl and u["score"] > 0]
    ref[lvl] = math.exp(sum(math.log(x) for x in s) / len(s)) if s else None
def level(u):
    if u["score"] <= 0 or not any(ref.values()):
        return ""
    return min((l for l in ref if ref[l]), key=lambda l: abs(math.log(u["score"]) - math.log(ref[l])))
OVERRIDE = {"legamph": 7}   # Telchine: 1107 DPS (like level 8) with 2750 health (like level 5): level 7
def long_range(u):
    """True: a laser, plasma or rail gun unit of 850 Elmo or more that is not on the ladder (no missiles): the game option Long range"""
    ws = [w.split(":") for w in u["weapons"].split() if not w.startswith("StarburstLauncher")]
    main = max(ws, key=lambda w: float(w[2])) if ws else None
    return not u["ladder"] and u["range"] >= 850 and main is not None and main[0] != "MissileLauncher"
for u in units:
    incl = not u["note"]
    u["level"] = (u["ladder"] or OVERRIDE.get(u["name"]) or level(u)) if incl else ""   # (a unit that is in the game keeps its level)
    u["long"] = "yes" if incl and long_range(u) else ""
    if u["long"]: u["note"] = "included only with the option Long range"
included = [u for u in units if u["level"] != ""]
rows = sorted(included, key=lambda u: (u["level"], u["fac"], u["score"])) + sorted([u for u in units if u["level"] == ""], key=lambda u: (u["note"], u["fac"], u["human"]))
head = ["Level", "Included", "Faction", "Name", "Unit", "Type", "Tech", "DPS", "Health", "Score", "Metal", "Speed", "Range", "Long range", "Note (why not included)"]
def cells(u):
    return [u["level"], u["ladder"], u["fac"], u["human"], u["name"], u["type"], u["tech"], round(u["dps"]), round(u["hp"]), round(u["score"]), round(u["metal"]), round(u["speed"]), round(u["range"]), u["long"], u["note"]]

# the lists of evo_game.lua (between "-- BEGIN POOL" and "-- END POOL"): per level the candidates of Armada, Cortex and Legion; the units with a long range
# separately (they join with the game option Long range); the names for the chat
FIX = {"armprowl": "Prowler"}   # (this unit has no translated name in the game)
def pool(kindlong):
    out = ["{"]
    for l in range(1, 11):
        lists = []
        for fac in ("Armada", "Cortex", "Legion"):
            names = sorted(u["name"] for u in included if u["level"] == l and u["fac"] == fac and bool(u["long"]) == kindlong)
            lists.append("{ " + ", ".join('"%s"' % n for n in names) + " }" if names else "{}")
        if any(x != "{}" for x in lists):
            out.append("\t[%d] = { %s }," % (l, ", ".join(lists)))
    out.append("}")
    return "\n".join(out)
gen = ["-- BEGIN POOL (made by test-data/tools/evolution_units.py from game-modes/evolution-units.md: change the table, not this block)",
       "-- Every level: the candidates of Armada, Cortex and Legion (a spawn takes a random faction, then a random unit of it); POOL_LONG: the units that join with the game option Long range",
       "local POOL = " + pool(False), "local POOL_LONG = " + pool(True),
       "for name, title in pairs({"]
for u in sorted(included, key=lambda u: u["name"]):
    gen.append('\t%s = "%s",' % (u["name"], FIX.get(u["name"], u["human"])))
gen += ["}) do", "\tNAMES[name] = title", "end", "-- END POOL"]
evo = os.path.join(repo, "LevelEditor", "scripts", "evo_game.lua")
src = open(evo, encoding="utf-8", newline="").read()
enl = "\r\n" if "\r\n" in src else "\n"
a = src.index("-- BEGIN POOL"); b = src.index("-- END POOL") + len("-- END POOL")
open(evo, "w", encoding="utf-8", newline="").write(src[:a] + enl.join(gen) + src[b:])

# the csv for Excel (semicolons, UTF-8 with BOM)
out = os.path.join(repo, "LevelEditor", "game-modes", "evolution_units.csv")
with open(out, "w", encoding="utf-8-sig", newline="") as fh:
    fh.write(";".join(head) + "\r\n")
    for u in rows:
        fh.write(";".join(str(c) for c in cells(u)) + "\r\n")

# the table in a file of its own: game-modes/evolution-units.md; the manual links to it at its end
nl = "\r\n"
tab = ["# Evolution: unit candidates", "",
       "[Evolution](evolution.md) · [Specification](../../specs/evolution.md) · [Start page](../../README.md)", "",
       "The selection of the units that can appear in Evolution (the candidates) and the level each one gets. Also as a table for Excel: [evolution_units.csv](evolution_units.csv); both are made by `LevelEditor/test-data/tools/evolution_units.py` from the numbers of the game.", "",
       "**Which units are candidates**", "",
       "- Looked at: every mobile unit of Armada, Cortex and Legion (the Scavenger and Raptor copies are not listed)",
       "- Candidates: bots, vehicles and hovercraft with a ground weapon; they have a level in the table",
       "- Left out (the last column says why): constructors, aircraft, water units, commanders, drones, mine layers, Epic and Archaic variants, Tumbleweeds",
       "- Left out: units without a ground weapon (radar, jammers, spies, anti air, crawling bombs)",
       "- Left out: artillery and rocket launchers (the description says so, the main weapon is a cannon or missile of 1000 Elmo or more, or the main weapon is a missile or rocket weapon: Salacia, Torch; the units of the first version are kept)",
       "- Left out: scouts (DPS x health below 10000) and weak support units (DPS below 40): no chance in a fight",
       "- Left out by hand: Behemoth (too slow) and Banisher (missile launcher)",
       "- *Long range = yes*: laser, plasma and rail gun units of 850 Elmo or more (no missiles); they only join when the option Long range of the room is on",
       "- *Included*: the 30 units that were in the game before (the number is their level); the others are new candidates", "",
       "**How the level is found**", "",
       "- *Score* = DPS x health (the strength in a fight of one against one)",
       "- DPS: against the default armor, without anti air, paralyzers, the D-gun and stockpile weapons",
       "- The 30 units of the first version (column *Included*) keep their level and are the yardstick: the score of a level is the geometric mean of its three units",
       "- A new unit gets the level whose score is closest to its own (on a logarithmic scale): the ranges are in the table below",
       "- One manual change: Telchine on level 7 (1107 DPS but only 2750 health)", "",
       "**The ranges of the levels** (DPS x health)", "",
       "| Level | Reference (3 units in the game) | From | To |", "|---|---|---|---|"]
edge = {l: math.sqrt(ref[l] * ref[l + 1]) for l in range(1, 10)}
for l in range(1, 11):
    lo = "0" if l == 1 else f"{edge[l - 1]:,.0f}"
    hi = "no limit" if l == 10 else f"{edge[l]:,.0f}"
    tab.append(f"| {l} | {ref[l]:,.0f} | {lo} | {hi} |")
tab += ["", "**All units** (the candidates first, sorted by level; then the units that are left out, the last column says why)", "",
        "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
for u in rows:
    tab.append("| " + " | ".join(str(c) for c in cells(u)) + " |")
open(os.path.join(repo, "LevelEditor", "game-modes", "evolution-units.md"), "w", encoding="utf-8", newline="").write(nl.join(tab) + nl)
md = os.path.join(repo, "LevelEditor", "game-modes", "evolution.md")
t = open(md, encoding="utf-8", newline="").read()
marker = "## Unit candidates"
if marker in t:
    t = t[:t.index(marker)].rstrip() + nl
t = t.rstrip() + nl + nl + marker + nl + nl + "The table of all units that can be used for Evolution, with their type, tech level, damage per second and the level they would get: [Unit candidates](evolution-units.md) (also as [evolution_units.csv](evolution_units.csv) for Excel)." + nl
open(md, "w", encoding="utf-8", newline="").write(t)
print(len(included), "included of", len(rows), "units; level counts:", {l: sum(1 for u in included if u["level"] == l) for l in range(1, 11)})
