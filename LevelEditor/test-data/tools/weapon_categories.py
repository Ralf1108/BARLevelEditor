"""Groups the weapons of Renegade (game-modes/renegade_weapons.csv) into picture categories for the weapon panel.

  python weapon_categories.py        writes game-modes/renegade-weapon-categories.md (the categories with counts and examples) and game-modes/renegade_weapon_categories.csv
                                     (every weapon on a mouse button with its proposed category and picture name; a proposal, the csv of the weapons is not changed)

Heat rays (description with "heat ray") are one category (yellow), the lasers of the heaviest kind (tachyon, ion accelerator, "ultra" word or the ultra limit of the damage) another (laser-ultra, blue and very thick).
A weapon gets a family (laser, plasma cannon, missile launcher ...) from its Type and its description. The families laser, plasma, cannon, missile and machine-gun have four sizes (light, medium, heavy, ultra):
the size comes from the tech level of the unit (T1 light, T2 medium, T3 and above heavy; renegade_unit_tech.csv, read from the game by test-data/tools/zz_tech.lua), moved one step down by a weak shot
and one step up by a strong shot (damage per second against the limits of the family in renegade_weapon_limits.csv); a shot at the ultra limit is ultra whatever the unit is.
Weapons without a button (footsteps, dummies) are left out.
"""
import csv, os, re, sys, collections

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
GM = os.path.join(repo, "LevelEditor", "game-modes")
SRC = os.path.join(GM, "renegade_weapons.csv")
OUT_MD = os.path.join(GM, "renegade-weapon-categories.md")
OUT_CSV = os.path.join(GM, "renegade_weapon_categories.csv")

TECH_CSV = os.path.join(GM, "renegade_unit_tech.csv")
LIMITS_CSV = os.path.join(GM, "renegade_weapon_limits.csv")
IMAGES = os.path.join(GM, "weapon-images")

# the families with a picture for each size; every other family has one picture
SIZED = ("laser", "plasma", "cannon", "missile", "machine-gun")
SIZES = ("light", "medium", "heavy", "ultra")
# the start values of renegade_weapon_limits.csv (damage per second): up to Weak a size less than the tech level gives, up to Normal the size of the tech level, up to Strong a size more, above Strong ultra (empty: no ultra size by damage)
DEFAULT_LIMITS = {"laser": (100, 600, 1500), "plasma": (60, 400, 1500), "cannon": (60, 250, 550), "missile": (40, 150, 800), "machine-gun": (20, 80, "")}
LIMIT_COLUMNS = ["Family", "Weak up to", "Normal up to", "Strong up to"]   # damage per second


def read_csv(path):
    return list(csv.DictReader(open(path, encoding="utf-8-sig", newline=""), delimiter=";"))


def load_limits():
    """the limits per family; the csv is made with the start values when it is missing (change it in Excel)"""
    if not os.path.exists(LIMITS_CSV):
        with open(LIMITS_CSV, "w", encoding="utf-8-sig", newline="") as fh:
            w = csv.writer(fh, delimiter=";")
            w.writerow(LIMIT_COLUMNS)
            for f, v in DEFAULT_LIMITS.items():
                w.writerow([f] + list(v))
    out = {}
    for r in read_csv(LIMITS_CSV):
        v = [(r[c] or "").strip() for c in LIMIT_COLUMNS[1:]]
        out[r["Family"]] = (int(v[0]), int(v[1]), int(v[2]) if v[2] else None)
    return out


def load_tech():
    return {r["Code"]: int(r["Tech"]) for r in read_csv(TECH_CSV) if (r["Tech"] or "").isdigit()} if os.path.exists(TECH_CSV) else {}


LIMITS = load_limits()
TECH = load_tech()


def dps(r):
    """damage per second of the weapon: the damage of one shot divided by the reload time (the number of projectiles of a salvo is not in the table)"""
    m = re.match(r"\s*([\d.]+)", r["Reload"] or "")
    rl = max(float(m.group(1)), 0.1) if m else 1.0
    return dmg(r) / rl


def dmg(r):
    m = re.match(r"\s*(\d+)", r["Damage"] or "")
    return int(m.group(1)) if m else 0


def size(d, r, bounds):
    """(only for the families that are one picture: unused)"""
    return None


def sized(fam, r):
    """light / medium / heavy / ultra of a weapon of a sized family: from the tech level of the unit, one step down for a weak and one up for a strong shot, ultra from the ultra limit"""
    weak, normal, strong = LIMITS[fam]
    x = dps(r)
    if strong is not None and x > strong:
        return "ultra"
    tech = TECH.get(r["Code"], 2)
    s = 0 if tech <= 1 else (1 if tech == 2 else 2)
    s += -1 if x <= weak else (0 if x <= normal else 1)
    return SIZES[max(0, min(2, s))]


def classify(r):
    d = (r["Weapon"] or "").lower()
    t = r["Type"]
    wn = (r["Weapon name"] or "").lower()
    # families that are one picture each
    if t == "D-gun" or "disintegrator" in d:
        return "d-gun", None
    if t == "Shield" or "repulsor" in d:
        return "shield", None
    if t == "Flamethrower":
        return "flamethrower", None
    if t == "Lightning":
        return "lightning", None
    if "emp" in d and t in ("EMP cannon",) or d.startswith("emp grenade"):
        return "emp-grenade", None
    if "stun" in d or "paralyz" in d or "flashbang" in d or ("emp" in d and "beam" in d):
        return "stun-beam", None
    if "heat ray" in d or "heatray" in d:
        return "heatray", None   # (yellow: the Juggernaut, the Adjudicator, Thermite ...)
    if t in ("Beam laser", "Laser") and ("tachyon" in d or "ion accelerator" in d or re.search(chr(92) + "bultra" + chr(92) + "b", d) or dps(r) > (LIMITS["laser"][2] or 10 ** 9)):
        return "laser-ultra", None   # (blue and very thick: the Pulsar, the tachyon beams ...)
    if t == "Melee" or "self-destruct" in d or "dummy" in d or "crawlingbomb" in d or "detonator" in d:
        return "self-destruct", None
    if t == "Bomb":
        if "nuclear" in d or "atomic" in d:
            return "nuclear", None
        return "bomb", (None, size(d, r, (150, 400)))
    if "icbm" in d and "intercept" in d:
        return "anti-nuke", None   # (the launchers that shoot down nuclear missiles: they fire by themselves, no button, but the picture is prepared)
    if "nuclear" in d or "icbm" in d or "thermonuclear" in d or "nuclear" in wn or "nuke" in d:
        return "nuclear", None
    if t == "Torpedo" or "torpedo" in d or "depthcharge" in d or "depth charge" in d:
        return "depth-charge" if ("depth" in d) else "torpedo", (None, size(d, r, (150, 400)))
    if t == "Artillery" or "artillery" in d:
        return "artillery", (None, size(d, r, (200, 600)))
    if "railgun" in d or "rail accelerator" in d:
        return "railgun", (None, size(d, r, (150, 500)))
    if "gauss" in d:
        return "gauss", (None, size(d, r, (300, 1000)))
    if "flak" in d:
        return "flak", (None, size(d, r, (50, 200)))
    if "shotgun" in d:
        return "shotgun", (None, size(d, r, (60, 200)))
    if "machine gun" in d or "rotary" in d or "chaingun" in d or "rapid-fire plasma gun" in d:
        return "machine-gun", (None, size(d, r, (15, 60)))
    if t == "Starburst missile" or "starburst" in d or "heavyrockets" in d or "rocket pod" in d:
        return "heavy-rocket", (None, size(d, r, (300, 900)))
    if t == "Missile" or "missile" in d or "rocket" in d:
        if "anti-air" in d or "aa " in d or "aa missile" in d:
            return "aa-missile", (None, size(d, r, (60, 250)))
        if "multi-rocket" in d or "salvo" in d or "pop-up rapid" in d or "rapid-fire" in d:
            return "rocket-salvo", (None, size(d, r, (40, 150)))
        return "missile", (None, size(d, r, (80, 300)))
    if t == "Plasma" or "plasma" in d:
        return "plasma", (None, size(d, r, (60, 300)))
    if t in ("Beam laser", "Laser") or "laser" in d or "beam" in d:
        return "laser", (None, size(d, r, (60, 250)))
    if t == "Cannon" or "cannon" in d:
        return "cannon", (None, size(d, r, (60, 300)))
    return "other", None


def order(name):
    """sort key: the family, then light < medium < heavy < ultra"""
    for k, s in enumerate(SIZES):
        if name.endswith("-" + s):
            return (name[:-len(s) - 1], k)
    return (name, -1)


def main():
    rows = [r for r in read_csv(SRC) if (r["Fire button"] or "").strip() or classify(r)[0] == "anti-nuke"]
    cat = collections.defaultdict(list)
    out = []
    for r in rows:
        fam, _ = classify(r)
        name = ("%s-%s" % (fam, sized(fam, r))) if fam in SIZED else fam
        cat[name].append(r)
        out.append([r["Faction"], r["Unit"], r["Code"], r["#"], r["Weapon"], r["Type"], r["Damage"], TECH.get(r["Code"], ""), name, "weapon_%s.png" % name if os.path.exists(os.path.join(IMAGES, "weapon_%s.png" % name)) else ""])
    out.sort(key=lambda o: (order(o[8]), o[0], o[1], int(o[3])))
    with open(OUT_CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        w.writerow(["Faction", "Unit", "Code", "#", "Weapon", "Type", "Damage", "Tech", "Category", "Picture"])
        for o in out:
            w.writerow(o)
    names = sorted(cat, key=order)
    have = [n for n in names if os.path.exists(os.path.join(IMAGES, "weapon_%s.png" % n))]
    lines = ["# Renegade: weapon categories for the pictures of the panel", "",
             "[Renegade](renegade.md) · [Weapon table](renegade-weapons.md) · [Start page](../../README.md)", "",
             "%d weapons on a mouse button (and the anti-nuke launchers, which fire by themselves), %d different weapon definitions, grouped into **%d categories** (a picture each, %d drawn so far). Made by `test-data/tools/weapon_categories.py` from `renegade_weapons.csv`; "
             "`renegade_weapon_categories.csv` has every weapon with its category (sorted by category and strength) and the picture; the pictures are drawn by `weapon_art.py` and `weapon_art2.py` (folder `weapon-images`)." % (len(rows), len({r["Weapon name"] for r in rows}), len(cat), len(have)), "",
             "## How a weapon gets its category", "",
             "1. **Family** from the type and the description of the weapon: laser, plasma, cannon, missile, machine gun, torpedo, bomb, flak, d-gun ... and so on (the table below). The heat rays (description with \"heat ray\") are the family heatray (yellow).",
             "2. **Size** (light, medium, heavy, ultra) only for the families laser, plasma, cannon, missile and machine-gun (all other families have one picture):",
             "   - the base size comes from the **tech level of the unit** that carries the weapon: T1 light, T2 medium, T3 and T4 heavy (`renegade_unit_tech.csv`; a unit that is not in it counts as T2);",
             "   - the damage per second (DPS: damage of one shot / reload) moves it: up to *Weak up to* one size down (a weak weapon), up to *Normal up to* it stays, up to *Strong up to* one size up (a strong weapon); never beyond heavy;",
             "   - a weapon above *Strong up to* is **ultra** whatever the unit is. For the lasers also the tachyon and ion beams and every weapon with the word \"ultra\" in its description are ultra (laser-ultra: blue, very thick).",
             "3. The limits are in `renegade_weapon_limits.csv` (change them in Excel, then run `update_renegade_weapons.bat`... or `python test-data/tools/weapon_categories.py`):", "",
             "| Family | Weak up to | Normal up to | Strong up to | Ultra above |", "|---|---|---|---|---|"]
    for f, (a, b, c) in LIMITS.items():
        lines.append("| %s | %d | %d | %s | %s |" % (f, a, b, c if c is not None else "", ("above " + str(c)) if c is not None else "none"))
    lines += ["", "(damage per second: a weapon with up to 100 DPS is weak, up to 600 normal, up to 1500 strong (laser example), above that ultra; an empty *Strong up to* means: no ultra size by damage)", "",
              "## The categories", "", "| Category | Picture | Weapons | Units | Examples |", "|---|---|---|---|---|"]
    for name in names:
        l = cat[name]
        ex = collections.Counter((r["Unit"] + ": " + r["Weapon"]) for r in l)
        examples = "; ".join(k for k, _ in ex.most_common(3))
        pic = '<img src="weapon-images/weapon_%s.png" width="384">' % name if name in have else ""
        lines.append("| %s | %s | %d | %d | %s |" % (name, pic, len(l), len({r["Code"] for r in l}), examples.replace("|", "/")))
    open(OUT_MD, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print(len(rows), "weapons,", len(cat), "categories,", len(have), "with a picture")
    for name in names:
        print("%4d %-22s %s" % (len(cat[name]), name, "; ".join(k for k, _ in collections.Counter((r["Weapon"]) for r in cat[name]).most_common(2))[:90]))


if __name__ == "__main__":
    main()
