"""Makes the table of the unit candidates of Evolution (the end of LevelEditor/game-modes/evolution.md and evolution_units.csv).

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
    types = [w.split(":")[0] for w in u["weapons"].split()]
    longest = max([float(w.split(":")[1]) for w in u["weapons"].split()] or [0])
    if "fly" in u["flags"]: n.append("air")
    if kind(u) == "Sea": n.append("water")
    if "builder" in u["flags"]: n.append("builder")
    if u["dps"] <= 0: n.append("no ground weapon")
    if any(t in ("StarburstLauncher",) for t in types) or (longest >= 700 and any(t in ("Cannon", "MissileLauncher", "TorpedoLauncher") for t in types)): n.append("artillery / rocket?")
    if re.search(r"artillery|rocket|missile launcher|mobile mortar|howitzer|mlrs", u["human"], re.I): n.append("artillery / rocket (name)")
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

# the table at the end of the manual
md = os.path.join(repo, "LevelEditor", "game-modes", "evolution.md")
t = open(md, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in t else "\n"
marker = "## Unit candidates"
if marker in t:
    t = t[:t.index(marker)].rstrip() + nl
lines = [marker, "",
         "Every mobile unit of Armada, Cortex and Legion with the level it would get in Evolution: the level whose current units (column *On ladder*) have the closest damage per second times health. DPS: against the default armor, without anti air, paralyzers and the D-gun. Also as a table for Excel: [evolution_units.csv](evolution_units.csv) (made by `LevelEditor/test-data/tools/evolution_units.py` from the numbers of the game).", "",
         "| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
for u in rows:
    lines.append("| " + " | ".join(str(c) for c in cells(u)) + " |")
t = t.rstrip() + nl + nl + nl.join(lines) + nl
open(md, "w", encoding="utf-8", newline="").write(t)
print(len(rows), "units; level counts:", {l: sum(1 for u in rows if u["level"] == l) for l in range(1, 11)})
