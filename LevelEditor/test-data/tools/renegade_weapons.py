"""The weapon table of Renegade (LevelEditor/game-modes/renegade-weapons.md and renegade_weapons.csv) and the block of renegade_game.lua made from it.

  python renegade_weapons.py update                makes the table game-modes/renegade-weapons.md (for reading) and the block WEAPON_BUTTONS (between -- BEGIN WEAPONS and
                                                   -- END WEAPONS) of scripts/renegade_game.lua from game-modes/renegade_weapons.csv, which is the source: change the columns
                                                   Group and Fire button there (Excel) and run update_renegade_weapons.bat in game-modes.
  python renegade_weapons.py table <infolog.txt>   makes the csv (and the md and the block) new from the lines "[zzwep] ..." that tools/zz_weapondump.lua writes into the
                                                   infolog of a sandbox run (pve_test.ps1 -Ren -Widget zz_weapondump.lua). Group and Fire button of a row that is in the csv
                                                   already are kept (your changes); new rows get the proposal.

The proposal (the same as slotsFor in renegade_game.lua, which is used for a unit that is not in the table): weapons with the same weapon definition are one group; missiles
(missile launcher, starburst, torpedo, anti-air only) and all other groups are sorted by range; with both kinds the shortest of the others goes on LMB, the rest of the
others on RMB (the missiles on RMB when there is no second one) and the missiles on MMB; with one kind only the shortest on LMB, the next on RMB, all further on MMB.
Weapons that do no damage (footsteps, script dummies) get an empty Group and Fire button (not fired by a button).
"""
import csv, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
MD = os.path.join(repo, "LevelEditor", "game-modes", "renegade-weapons.md")   # (made from the csv)
CSV = os.path.join(repo, "LevelEditor", "game-modes", "renegade_weapons.csv")
GADGET = os.path.join(repo, "LevelEditor", "scripts", "renegade_game.lua")
FACTION = {"arm": "Armada", "cor": "Cortex", "leg": "Legion"}
COLUMNS = ["Faction", "Unit", "Code", "#", "Weapon", "Type", "Target", "Range", "Reload", "Damage", "Weapon name", "Group", "Fire button"]
BUTTONS = ("LMB", "RMB", "MMB", "")


def clean(x):
    """a cell of Group or Fire button: the old "-" (and "-0", which a spreadsheet made of it) mean empty"""
    x = (x or "").strip()
    return "" if x in ("-", "-0") else x
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
    """what the weapon can hit: the tokens of its description (g2g = ground to ground, g2a = ground to air, a2g, a2a, g2s ... = water) when it has them (the damage against
    aircraft alone says nothing: many ground missiles have the same damage against every armor class), otherwise the damage (ground, air) and the type (torpedo = water)"""
    d = w["desc"].lower()
    tokens = set(re.findall(r"\b([gas]2[gas])\b", d))
    t = []
    if tokens:
        if tokens & {"g2g", "a2g", "s2g"}: t.append("Ground")
        if tokens & {"g2a", "a2a", "s2a"}: t.append("Air")
        if tokens & {"g2s", "a2s", "s2s"}: t.append("Water")
    else:
        if w["dmg"] > 2 and w["ground"]: t.append("Ground")
        if w["vtol"] > 2: t.append("Air")
        if w["water"] or w["type"] == "TorpedoLauncher": t.append("Water")
    if not t: return "-"
    if len(t) == 3: return "All"
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
            result[w["n"]] = ("", "")
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

Which weapon of a unit is fired with which mouse button in Renegade. **Change the last two columns in `renegade_weapons.csv`** (and nothing else): the rest is read from the game. The table below is made from the csv (between the two comment lines `BEGIN TABLE` and `END TABLE`: do not edit it); the text around it, like this, may be edited.

- **Group**: a letter per unit; weapons with the same letter belong together (they are fired together, like the three medium plasma guns of the Epoch). empty = the weapon is not fired by a button (footsteps, script dummies).
- **Fire button**: `LMB` (left mouse button), `RMB` (right), `MMB` (middle) or empty (no button). A group has one button: the button of the first row of the group counts. Several groups may share a button.
- **Target**: what the weapon can hit (Ground, Air, Water; All = everything). Anti-air weapons cannot take a ground point: they fire at the aircraft you look at.
- The proposal: weapons with the same weapon definition are one group; missiles (missile launchers, starburst, torpedoes, anti-air weapons) and all other groups are sorted by range. Short range on LMB, long range on RMB, missiles on MMB (with two groups only: the short on LMB, the other on RMB; with three or more of the same kind: the shortest on LMB, the next on RMB, all further on MMB).
- A unit that is not in the table (and the Scavenger copies of the units: they use the entry of the normal unit) gets the proposal worked out in the game (`slotsFor` in `renegade_game.lua`).

**How to change it:** the source is `renegade_weapons.csv` (open it in Excel, columns separated by semicolons): change **Group** and **Fire button**, save, then double-click `update_renegade_weapons.bat` (in this folder). It writes this page (only the table between the markers `BEGIN TABLE` and `END TABLE` is rewritten, the text around it stays) and the block between `-- BEGIN WEAPONS` and `-- END WEAPONS` in `renegade_game.lua` (do not edit that by hand either); the game takes the new file as usual (`start_renegade.bat`). New units or changed weapons: run `pve_test.ps1 -Ren -Widget zz_weapondump.lua` and `python renegade_weapons.py table <infolog.txt>`; your entries stay.

"""


BEGIN_TABLE = "<!-- BEGIN TABLE (made from renegade_weapons.csv by test-data/tools/renegade_weapons.py: change the csv, not what stands between the markers; the text around may be edited) -->"
END_TABLE = "<!-- END TABLE -->"


def write_md(rows):
    """only what stands between the markers is written (the count and the table); the text around it stays as it is. A file without the markers (or none) is made with the text INTRO."""
    codes = {r[2] for r in rows}
    lines = ["%d weapons of %d units." % (len(rows), len(codes)), "", "| " + " | ".join(COLUMNS) + " |", "|" + "|".join(["---"] * len(COLUMNS)) + "|"]
    for r in rows:
        lines.append("| " + " | ".join(c.replace("|", "/") for c in r) + " |")
    block = BEGIN_TABLE + "\n" + "\n".join(lines) + "\n" + END_TABLE + "\n"
    old = open(MD, encoding="utf-8", newline="").read().replace("\r\n", "\n") if os.path.exists(MD) else ""
    if BEGIN_TABLE[:20] in old and END_TABLE in old:
        a = old.index(BEGIN_TABLE[:20])
        b = old.index(END_TABLE) + len(END_TABLE) + 1
        text = old[:a] + block + old[b:]
    else:
        text = INTRO + block
    open(MD, "w", encoding="utf-8", newline="\n").write(text)


def write_csv(rows):
    with open(CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        w.writerow(COLUMNS)
        for r in rows:
            w.writerow(r)


def make_table(log):
    units = read_dump(log)
    old = {}
    if os.path.exists(CSV):
        for r in read_table(CSV):
            old[(r["Code"], r["#"])] = (clean(r.get("Group")), clean(r.get("Fire button")))
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
    write_csv(rows)
    write_md(rows)
    print("%d rows, %d units" % (len(rows), len(units)))
    make_lua(CSV)


def make_update():
    rows = [[r[c] for c in COLUMNS] for r in read_table(CSV)]
    write_md(rows)
    print("%s written (%d rows)" % (os.path.basename(MD), len(rows)))
    make_lua(CSV)


def make_lua(src):
    rows = read_table(src)
    units = {}
    for r in rows:
        r["Fire button"], r["Group"] = clean(r.get("Fire button")), clean(r.get("Group"))
        if r["Fire button"] not in BUTTONS:
            print("unknown button", r.get("Fire button"), "at", r.get("Code"), r.get("#"))
            continue
        units.setdefault(r["Code"], []).append(r)
    lines = []
    for code in sorted(units):
        rs = units[code]
        groupbtn = {}
        for r in rs:
            g = r.get("Group", "")
            if g == "" or r["Fire button"] == "":
                continue
            if g in groupbtn and groupbtn[g] != r["Fire button"]:
                print("note: %s group %s has several buttons, %s counts" % (code, g, groupbtn[g]))
                continue
            groupbtn[g] = r["Fire button"]
        by = {"LMB": [], "RMB": [], "MMB": []}
        for r in rs:
            g = r.get("Group", "")
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
    elif len(sys.argv) >= 2 and sys.argv[1] == "update":
        make_update()
    elif len(sys.argv) >= 2 and sys.argv[1] == "lua":
        make_lua(sys.argv[2] if len(sys.argv) > 2 else CSV)
    else:
        print(__doc__)
