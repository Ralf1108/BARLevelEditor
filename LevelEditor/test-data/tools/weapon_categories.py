"""Groups the weapons of Renegade (game-modes/renegade_weapons.csv) into picture categories for the weapon panel.

  python weapon_categories.py        writes game-modes/renegade-weapon-categories.md (the categories with counts and examples) and game-modes/renegade_weapon_categories.csv
                                     (every weapon on a mouse button with its proposed category and picture name; a proposal, the csv of the weapons is not changed)

Heat rays (description with "heat ray") are one category (yellow), the lasers of the heaviest kind (tachyon, ion accelerator, "ultra" or 2500 damage and more) another (laser-ultra, blue and very thick).
A weapon gets a family (laser, plasma cannon, missile launcher ...) from its Type and its description, and a size (light, medium, heavy) from words in the description
(light, mini, small / heavy, huge, massive, ultra) and otherwise from the damage of one shot. Weapons without a button (footsteps, dummies) are left out.
"""
import csv, os, re, sys, collections

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
GM = os.path.join(repo, "LevelEditor", "game-modes")
SRC = os.path.join(GM, "renegade_weapons.csv")
OUT_MD = os.path.join(GM, "renegade-weapon-categories.md")
OUT_CSV = os.path.join(GM, "renegade_weapon_categories.csv")

LIGHT = ("light", "mini", "small", "micro", "anti-swarm", "close-quarters light")
HEAVY = ("heavy", "huge", "massive", "ultra", "big", "giant", "super", "siege", "battleship", "experimental")


# the families with a picture for each size; every other family has one picture
SIZED = ("laser", "plasma", "cannon", "missile", "machine-gun")


def dmg(r):
    m = re.match(r"\s*(\d+)", r["Damage"] or "")
    return int(m.group(1)) if m else 0


def size(d, r, bounds):
    """light / medium / heavy: by words in the description, else by the damage of one shot against the bounds of the family"""
    if any(w in d for w in HEAVY):
        return "heavy"
    if any(w in d for w in LIGHT):
        return "light"
    x = dmg(r)
    lo, hi = bounds
    return "light" if x < lo else ("heavy" if x >= hi else "medium")


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
    if t in ("Beam laser", "Laser") and ("tachyon" in d or "ion accelerator" in d or re.search(chr(92) + "bultra" + chr(92) + "b", d) or dmg(r) >= 2500):
        return "laser-ultra", None   # (blue and very thick: the Pulsar, the tachyon beams ...)
    if t == "Melee" or "self-destruct" in d or "dummy" in d or "crawlingbomb" in d:
        return "self-destruct", None
    if t == "Bomb":
        if "nuclear" in d or "atomic" in d:
            return "nuclear", None
        return "bomb", (None, size(d, r, (150, 400)))
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


def main():
    rows = [r for r in csv.DictReader(open(SRC, encoding="utf-8-sig", newline=""), delimiter=";") if (r["Fire button"] or "").strip()]
    cat = collections.defaultdict(list)
    out = []
    for r in rows:
        fam, sz = classify(r)
        name = fam if (not sz or fam not in SIZED) else "%s-%s" % (fam, sz[1])
        cat[name].append(r)
        out.append([r["Faction"], r["Unit"], r["Code"], r["#"], r["Weapon"], r["Type"], r["Damage"], name, "weapon_%s.png" % name])
    with open(OUT_CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        w.writerow(["Faction", "Unit", "Code", "#", "Weapon", "Type", "Damage", "Category", "Picture"])
        for o in out:
            w.writerow(o)
    lines = ["# Renegade: weapon categories for the pictures of the panel", "",
             "[Renegade](renegade.md) · [Weapon table](renegade-weapons.md) · [Start page](../../README.md)", "",
             "%d weapons on a mouse button, %d different weapon definitions, grouped into **%d categories** (a picture each). Made by `test-data/tools/weapon_categories.py` from `renegade_weapons.csv`; "
             "`renegade_weapon_categories.csv` has every weapon with its category and the proposed picture name." % (len(rows), len({r["Weapon name"] for r in rows}), len(cat)), "",
             "| Category | Picture | Weapons | Units | Examples |", "|---|---|---|---|---|"]
    for name, l in sorted(cat.items(), key=lambda x: -len(x[1])):
        ex = collections.Counter((r["Unit"] + ": " + r["Weapon"]) for r in l)
        examples = "; ".join(k for k, _ in ex.most_common(3))
        lines.append("| %s | weapon_%s.png | %d | %d | %s |" % (name, name, len(l), len({r["Code"] for r in l}), examples.replace("|", "/")))
    open(OUT_MD, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print(len(rows), "weapons,", len(cat), "categories")
    for name, l in sorted(cat.items(), key=lambda x: -len(x[1])):
        print("%4d %-22s %s" % (len(l), name, "; ".join(k for k, _ in collections.Counter((r["Weapon"]) for r in l).most_common(2))[:90]))


if __name__ == "__main__":
    main()
