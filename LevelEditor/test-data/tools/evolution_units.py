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
    if name.endswith("_scav") or move in ("commanderbot", "scavcommanderbot") or "drone" in name:
        continue   # (the Scavenger copies, the commanders and the drones are no candidates)
    if re.search(r"scav|raptor", name + " " + human, re.I) or "fly" in flags or "builder" in flags or re.search(r"mine ?layer|minesweeper|mine", human, re.I):
        continue   # (Scavengers, Raptors, aircraft, constructors, mine layers)
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

def note(u):
    n = []
    ws = [w.split(":") for w in u["weapons"].split()]
    main = max([w for w in ws if w[0] != "StarburstLauncher"] or ws, key=lambda w: float(w[2])) if ws else None   # (the weapon with the most damage per second; Starburst launchers are stockpiled missiles)
    if "fly" in u["flags"]: n.append("air")
    if kind(u) == "Sea": n.append("water")
    if "builder" in u["flags"]: n.append("builder")
    if u["dps"] <= 0: n.append("no ground weapon")
    # artillery / rocket launcher: the description of the unit says so, or its main weapon reaches 1000 Elmo or more
    desc = cats.get(u["name"], {}).get("description", "")
    if re.search(r"artillery|rocket|missile launcher|mortar|howitzer|mlrs", desc + " " + u["human"], re.I) or (main and main[0] in ("Cannon", "MissileLauncher") and float(main[1]) >= 1000):
        n.append("artillery / rocket")
    return ", ".join(sorted(set(n)))

for u in units:
    u["type"] = kind(u)
    u["score"] = u["dps"] * u["hp"]
    u["note"] = note(u)
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
for u in units:
    u["level"] = level(u)

# artillery and rocket launchers are no candidates either (the notes of the rule of thumb and of the name)
units = [u for u in units if "artillery" not in u["note"]]
rows = sorted(units, key=lambda u: (u["level"] == "", u["level"] if u["level"] != "" else 0, u["fac"], u["score"]))
head = ["Level", "On ladder", "Faction", "Name", "Unit", "Type", "Tech", "DPS", "Health", "Metal", "Speed", "Range", "Note"]
def cells(u):
    return [u["level"], u["ladder"], u["fac"], u["human"], u["name"], u["type"], u["tech"], round(u["dps"]), round(u["hp"]), round(u["metal"]), round(u["speed"]), round(u["range"]), u["note"]]

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
       "Every mobile ground and water unit of Armada, Cortex and Legion that may be used for Evolution, with the level it would get: the level whose current units (column *On ladder*) have the closest damage per second times health. Left out: Scavenger and Raptor units, constructors, aircraft, artillery and rocket launchers, mine layers, commanders and drones. DPS: against the default armor, without anti air, paralyzers and the D-gun. Also as a table for Excel: [evolution_units.csv](evolution_units.csv). Both are made by `LevelEditor/test-data/tools/evolution_units.py` from the numbers of the game (`zz_unitdump.lua`).", "",
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
print(len(rows), "units; level counts:", {l: sum(1 for u in rows if u["level"] == l) for l in range(1, 11)})
