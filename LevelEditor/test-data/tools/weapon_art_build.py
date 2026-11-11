"""Draws the pictures of the weapon panel of Renegade (one per category of renegade-weapon-categories.md): the weapons are drawn by weapon_art.py (laser cannon), weapon_art2.py (plasma, cannon,
missile, starburst, rocket salvo, torpedo) and weapon_art3.py (all the others); this file lists every picture and draws them in parallel (one process per core).

  python weapon_art_build.py [out_dir] [--only name,name] [--procs N]
      writes weapon_<category>.png (768 x 128) for every picture and the comparison sheets sheet1.png ... (all pictures one below the other, with their names);
      default out_dir: LevelEditor/game-modes/weapon-images (give another folder to look at the result first); --only draws only the pictures with these names; --procs: number of processes (default: the cores)
      The body of the laser cannon is also kept as source/laser_cannon_body.png when the whole set is drawn.

Every picture: a body (the cannon, a launcher with a tube of some height, the rocket pod) or none, a function that adds the projectile or the effect (body, tip=...) where tip is the x of the front of the projectile
(the same far right in every picture) and the width of the picture that the row shows (the lighter the weapon, the smaller it is in the row).
"""
import functools, multiprocessing, os, sys
from PIL import Image, ImageDraw
import weapon_art as wa
import weapon_art2 as w2
import weapon_art3 as w3

P = (200, 90, 255)   # plasma


def laser(body, tip, color, k):
    return wa.beam_fx(body, color, k)


def jobs():
    """(name, width shown, body, drawing function) of every picture, in the order of the comparison sheets"""
    j = []
    for name, k, cw in (("light", 0.25, 3900), ("medium", 0.5, 3500), ("heavy", 0.8, 3200), ("ultra", 1.15, 3000)):
        j.append(("cannon-" + name, cw, "cannon", functools.partial(w2.cannon_shot, k=k)))
    for name, th, k, cw in (("light", 90, 0.45, 3900), ("medium", 130, 0.8, 3500), ("heavy", 170, 1.1, 3200), ("ultra", 220, 1.6, 3000)):
        j.append(("missile-" + name, cw, "launcher-%d" % th, functools.partial(w2.missile_shot, k=k)))
    j.append(("heavy-rocket", 3100, "launcher-190", w2.starburst_shot))
    j.append(("rocket-salvo", 3500, "pod", w2.salvo_shot))
    for name, k, cw in (("light", 0.40, 3900), ("medium", 0.70, 3500), ("heavy", 1.0, 3100), ("ultra", 1.6, 2900)):
        j.append(("plasma-" + name, cw, "cannon", functools.partial(w2.plasma, color=P, k=k)))
    j.append(("torpedo", 3300, "launcher-170", functools.partial(w2.torpedo_shot, k=1.0)))
    for name, color, k, cw in wa.SIZES:
        j.append((name, cw, "cannon", functools.partial(laser, color=color, k=k)))
    j += [("d-gun", 3300, "cannon", w3.dgun), ("stun-beam", 3300, "cannon", w3.stun), ("flak", 3500, "cannon", w3.flak), ("lightning", 3300, "cannon", w3.lightning),
          ("machine-gun-light", 3900, "cannon", functools.partial(w3.machine_gun, rows=1, thick=9, count=16, sparks=0)),
          ("machine-gun-medium", 3500, "cannon", functools.partial(w3.machine_gun, rows=2, thick=11, count=20, sparks=0)),
          ("machine-gun-heavy", 3200, "cannon", functools.partial(w3.machine_gun, rows=3, thick=14, count=24, sparks=0)),
          ("gauss", 3300, "cannon", w3.gauss), ("artillery", 3300, "cannon", w3.artillery), ("shotgun", 3500, "cannon", w3.shotgun),
          ("emp-grenade", 3300, "launcher-150", w3.emp_grenade), ("self-destruct", 3300, None, w3.self_destruct),
          ("railgun", 3300, "cannon", w3.railgun), ("flamethrower", 3300, "cannon", w3.flamethrower), ("depth-charge", 3300, "launcher-150", w3.depth_charge),
          ("aa-missile", 3300, "launcher-110", w3.aa_missile), ("bomb", 3300, None, w3.bomb), ("nuclear", 3300, None, w3.nuclear)]
    return j


_bodies = {}


def body_of(key):
    """a body, drawn once per process"""
    if key is None:
        return None
    if key not in _bodies:
        if key == "cannon":
            _bodies[key] = wa.gun_body()
        elif key == "pod":
            _bodies[key] = w3.w2.pod_body()
        else:
            _bodies[key] = w2.launcher_body(1, int(key.split("-")[1]))
    return _bodies[key]


def render(task):
    out, (name, cw, key, fn) = task
    tip = 20 + w2.FRONT * cw
    big = fn(body_of(key), tip=tip)
    wa.panel_banner(big, cw).save(os.path.join(out, "weapon_%s.png" % name))
    return name


def main():
    args = sys.argv[1:]
    only, procs = None, os.cpu_count() or 1
    if "--only" in args:
        i = args.index("--only")
        only = args[i + 1].split(",")
        del args[i:i + 2]
    if "--procs" in args:
        i = args.index("--procs")
        procs = int(args[i + 1])
        del args[i:i + 2]
    here = os.path.dirname(os.path.abspath(__file__))
    out = args[0] if args else os.path.join(os.path.dirname(os.path.dirname(here)), "game-modes", "weapon-images")
    os.makedirs(out, exist_ok=True)
    todo = [j for j in jobs() if not only or j[0] in only]
    if not only and not args:
        src = os.path.join(out, "source")
        os.makedirs(src, exist_ok=True)
        wa.gun_body().crop((20, 190, 1330, 660)).save(os.path.join(src, "laser_cannon_body.png"))   # the cannon without glow, kept to look at it
    # the pictures that need the same body are given to a process one after the other (jobs are taken in order, so a process keeps its bodies)
    with multiprocessing.Pool(min(procs, len(todo))) as pool:
        for name in pool.imap_unordered(render, [(out, j) for j in todo]):
            print("weapon_%s.png" % name, flush=True)
    rows = [j[0] for j in todo]
    for s in range(0, len(rows), 7):
        part = rows[s:s + 7]
        sheet = Image.new("RGB", (768, len(part) * 136), (0, 0, 0))
        for i, name in enumerate(part):
            sheet.paste(Image.open(os.path.join(out, "weapon_%s.png" % name)), (0, i * 136))
            ImageDraw.Draw(sheet).text((6, i * 136 + 4), name, fill=(255, 255, 255))
        sheet.save(os.path.join(out, "sheet%d.png" % (s // 7 + 1)))


if __name__ == "__main__":
    multiprocessing.freeze_support()
    main()
