"""The weapon table of Renegade (LevelEditor/game-modes/renegade-weapons.md and renegade_weapons.csv) and the block of renegade_game.lua made from it.

  python renegade_weapons.py table <infolog.txt>   makes (or updates) the table from the lines "[zzwep] ..." that tools/zz_weapondump.lua writes into the infolog of a sandbox
                                                   run (pve_test.ps1 -Ren -Widget zz_weapondump.lua). The columns Group and Fire button of a row that is in the table
                                                   already are kept (your changes); new rows get the proposal.
  python renegade_weapons.py lua [table.md|table.csv]   writes the block WEAPON_BUTTONS (between -- BEGIN WEAPONS and -- END WEAPONS) into scripts/renegade_game.lua
                                                   from the columns Group and Fire button of the table (default: the .md).

The proposal (the same as slotsFor in renegade_game.lua, which is used for a unit that is not in the table): weapons with the same weapon definition are one group; missiles
(missile launcher, starburst, torpedo, anti-air only) and all other groups are sorted by range; with both kinds the shortest of the others goes on LMB, the rest of the
others on RMB (the missiles on RMB when there is no second one) and the missiles on MMB; with one kind only the shortest on LMB, the next on RMB, all further on MMB.
Weapons that do no damage (footsteps, script dummies) get "-" (not fired by a button).
"""
import csv, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
MD = os.path.join(repo, "LevelEditor", "game-modes", "renegade-weapons.md")
CSV = os.path.join(repo, "LevelEditor", "game-modes", "renegade_weapons.csv")
GADGET = os.path.join(repo, "LevelEditor", "scripts", "renegade_game.lua")
FACTION = {"arm": "Armada", "cor": "Cortex", "leg": "Legion"}
COLUMNS = ["Faction", "Unit", "Code", "#", "Weapon", "Type", "Target", "Range", "Reload", "Damage", "Weapon name", "Group", "Fire button"]
BUTTONS = ("LMB", "RMB", "MMB", "-")
MISSILE = ("MissileLauncher", "StarburstLauncher", "TorpedoLauncher")


def friendly_type(w):
    t, d = w["type"], w["desc"].lower()
    names = {"Cannon": "Cannon", "BeamLaser": "Beam laser", "LaserCannon": "Laser", "MissileLauncher": "Missile", "StarburstLauncher": "Starburst missile",
             "TorpedoLauncher": "Torpedo", "LightningCannon": "Lightning", "Flame": "Flamethrower", "AircraftBomb": "Bomb", "DGun": "D-gun",
             "Shield": "Shield", "EMGCannon": "Machine gun", "TransportShield": "Transport", "StarburstMissile": "Starburst missile"}
    name = names.get(t, t)
    if t == "Cannon":
        if "plasma" in d:
            name = "Plasma"
        elif "artillery" in d or "howitzer" in d:
            name = "Artillery"
        elif "emp" in d:
            name = "EMP cannon"
    return name


def target(w):
    t = []
    if w["dmg"] > 2 and w["ground"]:
        t.append("Ground")
    if w["vtol"] > 2:
        t.append("Air")
    d = w["desc"].lower()
    if w["water"] or w["type"] == "TorpedoLauncher" or re.search(r"\b[gas]2s\b", d):
        t.append("Water")
    if not t:
        return "-"
    if len(t) == 3:
        return "All"
    return "+".join(sorted(t, key=["Air", "Ground", "Water"].index))


def usable(w):
    return w["range"] > 0 and w["type"] != "Shield" and "interceptor" not in w["flags"] and (w["dmg"] > 2 or w["vtol"] > 2)


def propose(weapons):
    """weapons of one unit -> {weapon number: (group letter, button)}"""
    groups = {}
    order = []
    for w in weapons:
        if not usable(w):
            continue
        g = groups.get(w["wname"])
        if g is None:
            aa = w["dmg"] <= 2 and w["vtol"] > 2
            g = dict(name=w["wname"], range=w["range"], nums=[], missile=(w["type"] in MISSILE) or aa)
            groups[w["wname"]] = g
            order.append(g)
        g["nums"].append(w["n"])
    others = sorted([g for g in order if not g["missile"]], key=lambda g: g["range"])
    miss = sorted([g for g in order if g["missile"]], key=lambda g: g["range"])
    button = {}
    if others and miss:
        button[id(others[0])] = "LMB"
        for g in others[1:]:
            button[id(g)] = "RMB"
        mb = "MMB" if len(others) > 1 else "RMB"
        for g in miss:
            button[id(g)] = mb
    else:
        lst = others or miss
        for i, g in enumerate(lst):
            button[id(g)] = ("LMB", "RMB", "MMB")[min(i, 2)]
    result = {}
    ranked = sorted(order, key=lambda g: ({"LMB": 0, "RMB": 1, "MMB": 2}[button[id(g)]], g["range"]))
    for k, g in enumerate(ranked):
        letter = chr(ord("A") + k)
        for n in g["nums"]:
            result[n] = (letter, button[id(g)])
    for w in weapons:
        if w["n"] not in result:
            result[w["n"]] = ("-", "-")
    return result


def read_dump(path):
    units = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.search(r"\[zzwep\] (.*)$", line.rstrip())
        if not m or m.group(1) == "done":
            continue
        f = m.group(1).split(";")
        if len(f) < 16:
            continue
        code, fac, human, n, wname, desc, typ, rng, reload_, dmg, vtol, proj, salvo, ground, water, flags = f[:16]
        units.setdefault(code, dict(code=code, fac=fac, human=human, weapons=[]))["weapons"].append(
            dict(n=int(n), wname=wname, desc=desc, type=typ, range=int(float(rng)), reload=float(reload_), dmg=float(dmg), vtol=float(vtol),
                 proj=int(proj), salvo=int(salvo), ground=ground == "1", water=water == "1", flags=flags))
    return units


def read_table(path):
    """the rows of the table (md or csv) as dicts by column name"""
    rows = []
    if path.endswith(".csv"):
        with open(path, encoding="utf-8-sig", newline="") as fh:
            for r in csv.DictReader(fh, delimiter=";"):
                rows.append(r)
        return rows
    head = None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n").rstrip("\r")
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells[0] == "Faction":
            head = cells
            continue
        if head is None or set(cells[0]) <= set("-: "):
            continue
        rows.append(dict(zip(head, cells)))
    return rows


INTRO = """# Renegade: the weapons of all units

[Renegade](renegade.md) · [Specification](../../specs/renegade.md) · [Start page](../../README.md)

Which weapon of a unit is fired with which mouse button in Renegade. **Change the last two columns** (and nothing else): the rest is read from the game.

- **Group**: a letter per unit; weapons with the same letter belong together (they are fired together, like the three medium plasma guns of the Epoch). `-` = the weapon is not fired by a button (footsteps, script dummies).
- **Fire button**: `LMB` (left mouse button), `RMB` (right) or `MMB` (middle). A group has one button: the button of the first row of the group counts. Several groups may share a button.
- **Target**: what the weapon can hit (Ground, Air, Water; All = everything). Anti-air weapons cannot take a ground point: they fire at the aircraft you look at.
- The proposal: weapons with the same weapon definition are one group; missiles (missile launchers, starburst, torpedoes, anti-air weapons) and all other groups are sorted by range. Short range on LMB, long range on RMB, missiles on MMB (with two groups only: the short on LMB, the other on RMB; with three or more of the same kind: the shortest on LMB, the next on RMB, all further on MMB).
- A unit that is not in the table (and the Scavenger copies of the units: they use the entry of the normal unit) gets the proposal worked out in the game (`slotsFor` in `renegade_game.lua`).

After a change: `python LevelEditor\\test-data\\tools\\renegade_weapons.py lua` writes the table into `renegade_game.lua` (the block between `-- BEGIN WEAPONS` and `-- END WEAPONS`; do not edit it by hand), then the game gets the new file as usual. The same table is `renegade_weapons.csv` (for Excel; `lua renegade_weapons.csv` reads that one instead). New units or changed weapons: run `pve_test.ps1 -Ren -Widget zz_weapondump.lua` and `python renegade_weapons.py table <infolog.txt>`; your entries stay.

"""


def make_table(log):
    units = read_dump(log)
    old = {}
    if os.path.exists(MD):
        for r in read_table(MD):
            old[(r["Code"], r["#"])] = (r.get("Group", "-"), r.get("Fire button", "-"))
    rows = []
    facs = list(FACTION)
    for code in sorted(units, key=lambda c: (facs.index(units[c]["fac"]) if units[c]["fac"] in facs else 9, units[c]["human"].lower(), c)):
        u = units[code]
        prop = propose(u["weapons"])
        for w in sorted(u["weapons"], key=lambda w: w["n"]):
            grp, btn = old.get((code, str(w["n"])), prop[w["n"]])
            dmg = "%d" % w["dmg"] if w["dmg"] > 2 else ("%d (air)" % w["vtol"] if w["vtol"] > 2 else "0")
            rows.append([FACTION[u["fac"]], u["human"], code, str(w["n"]), w["desc"], friendly_type(w), target(w), str(w["range"]), "%.1f s" % w["reload"],
                         dmg, w["wname"], grp, btn])
    with open(MD, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(INTRO)
        fh.write("%d weapons of %d units.\n\n" % (len(rows), len(units)))
        fh.write("| " + " | ".join(COLUMNS) + " |\n|" + "|".join(["---"] * len(COLUMNS)) + "|\n")
        for r in rows:
            fh.write("| " + " | ".join(c.replace("|", "/") for c in r) + " |\n")
    with open(CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        w.writerow(COLUMNS)
        for r in rows:
            w.writerow(r)
    print("%d rows, %d units" % (len(rows), len(units)))


def make_lua(src):
    rows = read_table(src)
    units = {}
    for r in rows:
        if r.get("Fire button", "-") not in BUTTONS:
            print("unknown button", r.get("Fire button"), "at", r.get("Code"), r.get("#"))
            continue
        units.setdefault(r["Code"], []).append(r)
    lines = []
    for code in sorted(units):
        rs = units[code]
        groupbtn = {}
        for r in rs:
            g = r.get("Group", "-")
            if g == "-" or r["Fire button"] == "-":
                continue
            if g in groupbtn and groupbtn[g] != r["Fire button"]:
                print("note: %s group %s has several buttons, %s counts" % (code, g, groupbtn[g]))
                continue
            groupbtn[g] = r["Fire button"]
        by = {"LMB": [], "RMB": [], "MMB": []}
        for r in rs:
            g = r.get("Group", "-")
            if g in groupbtn:
                by[groupbtn[g]].append(int(r["#"]))
        lines.append("\t%s = { L = { %s }, R = { %s }, M = { %s } }," % (code, ", ".join(map(str, sorted(by["LMB"]))), ", ".join(map(str, sorted(by["RMB"]))), ", ".join(map(str, sorted(by["MMB"])))))
    text = open(GADGET, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    text = text.replace("\r\n", "\n")
    a, b = text.index("-- BEGIN WEAPONS"), text.index("-- END WEAPONS")
    head = "-- BEGIN WEAPONS (made by test-data/tools/renegade_weapons.py from game-modes/renegade-weapons.md: change the table, not this block)\nlocal WEAPON_BUTTONS = {\n"
    text = text[:a] + head + "\n".join(lines) + "\n}\n" + text[b:]
    open(GADGET, "w", encoding="utf-8", newline="").write(text.replace("\n", nl))
    print("%d units written" % len(lines))


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "table":
        make_table(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "lua":
        make_lua(sys.argv[2] if len(sys.argv) > 2 else MD)
    else:
        print(__doc__)
