"""The rest of the weapon pictures for the panel of Renegade (d-gun, stun beam, flak, lightning, machine gun in three sizes, gauss, artillery, shotgun, EMP grenade, self-destruct), same style as
weapon_art.py and weapon_art2.py: a gun or launcher on the left, the projectile or the effect far right (the same place in every picture).

  python weapon_art3.py [out_dir]    writes weapon_<category>.png (768 x 128) and sheet_new.png (all of them one below the other); default out_dir: LevelEditor/game-modes/weapon-images
                                     (ART_ONLY=name,name draws only those)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import weapon_art as wa
import weapon_art2 as w2
from weapon_art import W, H, part, mask_of, poly, rrect, mix
from weapon_art2 import new, blur_add, sphere, smoke, shell, CY


def line_glow(out, pts, color, width, blur=6):
    """a glowing line along points: a wide soft halo, the body in the colour and a white core"""
    c3 = mix(color, 255, 0.85)
    l = new()
    ImageDraw.Draw(l).line(pts, fill=color + (255,), width=int(width * 2.4), joint="curve")
    out.alpha_composite(l.filter(ImageFilter.GaussianBlur(blur * 2.2)))
    l = new()
    ImageDraw.Draw(l).line(pts, fill=color + (255,), width=width, joint="curve")
    blur_add(out, l, blur * 0.5)
    l = new()
    ImageDraw.Draw(l).line(pts, fill=c3 + (255,), width=max(2, width // 2), joint="curve")
    blur_add(out, l, 1.2)


def bolt(x0, y0, x1, y1, rnd, jag, steps=26):
    """a jagged path from (x0, y0) to (x1, y1)"""
    pts = [(x0, y0)]
    for i in range(1, steps):
        t = i / steps
        pts.append((x0 + (x1 - x0) * t + rnd.uniform(-jag * 0.3, jag * 0.3), y0 + (y1 - y0) * t + rnd.uniform(-jag, jag)))
    pts.append((x1, y1))
    return pts


def muzzle_glow(out, color, r=1.0):
    gl = new()
    ImageDraw.Draw(gl).ellipse((1224 - 20 * r, 350 - 10 * r, 1318, 492 + 10 * r), fill=color + (255,))
    out.alpha_composite(gl.filter(ImageFilter.GaussianBlur(9)))


def muzzle_flash(out, k=1.0, length=300):
    fl = new()
    ImageDraw.Draw(fl).polygon([(1300, CY - 70 * k), (1300 + length * 0.5, CY - 20 * k), (1300 + length, CY), (1300 + length * 0.5, CY + 20 * k), (1300, CY + 70 * k)], fill=(255, 160, 50, 255))
    blur_add(out, fl, 10)
    fl2 = new()
    ImageDraw.Draw(fl2).polygon([(1300, CY - 36 * k), (1300 + length * 0.35, CY - 8 * k), (1300 + length * 0.7, CY), (1300 + length * 0.35, CY + 8 * k), (1300, CY + 36 * k)], fill=(255, 238, 180, 255))
    blur_add(out, fl2, 5)


def fireball(out, cx, cy, r, spikes=14, seed=1):
    """a fire ball with flames: orange halo, flame spikes, yellow body, white-hot core"""
    rnd = random.Random(seed)
    halo = new()
    ImageDraw.Draw(halo).ellipse((cx - r * 1.9, cy - r * 1.9, cx + r * 1.9, cy + r * 1.9), fill=(255, 110, 20, 150))
    out.alpha_composite(halo.filter(ImageFilter.GaussianBlur(r * 0.6)))
    fl = new()
    d = ImageDraw.Draw(fl)
    for i in range(spikes):
        a = i * math.tau / spikes + rnd.uniform(-0.15, 0.15)
        l = r * rnd.uniform(1.3, 1.9)
        d.polygon([(cx + math.cos(a - 0.28) * r * 0.8, cy + math.sin(a - 0.28) * r * 0.8), (cx + math.cos(a) * l, cy + math.sin(a) * l), (cx + math.cos(a + 0.28) * r * 0.8, cy + math.sin(a + 0.28) * r * 0.8)], fill=(255, 140, 30, 255))
    blur_add(out, fl, 6)
    for rr, c in ((r, (255, 150, 30)), (r * 0.72, (255, 205, 70)), (r * 0.42, (255, 245, 200))):
        l = new()
        ImageDraw.Draw(l).ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=c + (255,))
        blur_add(out, l, max(3, r * 0.06))


def dgun(body, tip):
    """the Disintegrator: a huge fire ball with flames, a trail of fire"""
    out = body.copy()
    muzzle_glow(out, (255, 150, 40))
    r = 150
    cx = tip - 1.8 * r
    rnd = random.Random(3)
    n = int((cx - r - 1330) / 120)
    for i in range(n):
        x = 1330 + i * (cx - r - 1330) / n
        fireball(out, x, CY + rnd.randint(-10, 10), 22 + 40 * i / n, spikes=8, seed=i)
    fireball(out, cx, CY, r, 16, 9)
    return out


def stun(body, tip):
    """the stun beam: a thin electric blue beam with rings of the pulse running along it"""
    out = wa.beam_fx(body, (90, 220, 255), 0.5)
    rings = new()
    d = ImageDraw.Draw(rings)
    x = 1450
    i = 0
    while x < tip + 100:
        h = 90 + i * 6
        d.ellipse((x - 14, CY - h, x + 14, CY + h), outline=(200, 245, 255, 255), width=6)
        x += 170
        i += 1
    blur_add(out, rings, 3)
    return out


def flak(body, tip):
    """a flak cannon: muzzle flash and, far right, three air bursts: dark smoke with an orange flash and fragments"""
    out = body.copy()
    muzzle_flash(out, 0.8, 260)
    rnd = random.Random(6)
    sh = new()
    d = ImageDraw.Draw(sh)
    for k in range(6):
        x = 1500 + k * (tip - 1700) / 6
        d.ellipse((x - 12, CY - 7, x + 12, CY + 7), fill=(255, 220, 140, 255))
    blur_add(out, sh, 3)
    for cx, cy, r in ((tip - 330, CY - 70, 120), (tip - 150, CY + 55, 150), (tip - 420, CY + 90, 90)):
        smoke(out, cx - r, cx + r, cy, r * 0.55, seed=int(cx), tone=(40, 40, 46))
        cl = new()
        d = ImageDraw.Draw(cl)
        for _ in range(9):
            a = rnd.uniform(0, math.tau)
            rr = r * rnd.uniform(0.2, 0.6)
            px, py = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            q = r * rnd.uniform(0.35, 0.6)
            d.ellipse((px - q, py - q, px + q, py + q), fill=(70, 70, 78, 150))
        out.alpha_composite(cl.filter(ImageFilter.GaussianBlur(r * 0.14)))
        sphere(out, cx, cy, r * 0.32, (255, 150, 40))
        sp = new()
        d = ImageDraw.Draw(sp)
        for _ in range(22):
            a = rnd.uniform(0, math.tau)
            l0, l1 = r * rnd.uniform(0.5, 0.8), r * rnd.uniform(1.0, 1.6)
            d.line((cx + math.cos(a) * l0, cy + math.sin(a) * l0, cx + math.cos(a) * l1, cy + math.sin(a) * l1), fill=(255, 210, 120, 255), width=3)
        blur_add(out, sp, 1.2)
    return out


def lightning(body, tip):
    """a branching bolt of white-violet lightning from the muzzle to the right"""
    out = body.copy()
    muzzle_glow(out, (170, 140, 255))
    rnd = random.Random(12)
    col = (170, 140, 255)
    main = bolt(1320, CY, tip - 40, CY, rnd, 46)
    line_glow(out, main, col, 9)
    for i in range(5, len(main) - 2, 3):
        x, y = main[i]
        a = rnd.choice((-1, 1)) * rnd.uniform(0.5, 1.0)
        br = bolt(x, y, x + math.cos(a) * 190, y + math.sin(a) * 190, rnd, 22, 8)
        line_glow(out, br, col, 5, 4)
    sphere(out, tip - 40, CY, 34, col)
    return out


def machine_gun(body, tip, rows, thick, count, sparks):
    """a machine gun: muzzle flash and a stream of tracers in `rows` lines"""
    out = body.copy()
    muzzle_flash(out, 0.55 + 0.12 * rows, 200)
    rnd = random.Random(21)
    tr = new()
    d = ImageDraw.Draw(tr)
    for r in range(rows):
        y = CY + (r - (rows - 1) / 2) * 46 + (r % 2) * 6
        for i in range(count):
            x = 1450 + i * (tip - 1500) / count + rnd.randint(-10, 10) + r * 40
            if x > tip - 40:
                continue
            d.line((x, y, x + 110, y), fill=(255, 235, 140, 255), width=thick)
            d.ellipse((x + 96, y - thick, x + 112 + thick, y + thick), fill=(255, 255, 230, 255))
    blur_add(out, tr, 2.5)
    for r in range(rows):
        sphere(out, tip - 10, CY + (r - (rows - 1) / 2) * 46, 14 + 5 * rows, (255, 190, 70))
    return out


def gauss(body, tip):
    """a gauss cannon: a glowing slug with shock rings behind it"""
    out = body.copy()
    muzzle_glow(out, (120, 190, 255))
    rings = new()
    d = ImageDraw.Draw(rings)
    cx = tip - 150
    for i, x in enumerate(range(1450, int(cx - 420), 150)):
        h = 70 + i * 12
        d.ellipse((x - 10, CY - h, x + 10, CY + h), outline=(150, 210, 255, 255), width=5)
    blur_add(out, rings, 3)
    rnd = random.Random(8)
    line_glow(out, bolt(1330, CY, cx - 340, CY, rnd, 14, 30), (120, 190, 255), 5, 3)
    sphere(out, cx - 10, CY, 70, (120, 190, 255))
    shell(out, cx, CY, 330, 36, tip=(120, 190, 255))
    return out


def artillery(body, tip):
    """artillery: a big muzzle blast, the dotted arc of the shell and the explosion where it lands"""
    out = body.copy()
    muzzle_flash(out, 1.1, 380)
    smoke(out, 1330, 1900, CY - 40, 70)
    pts = [(1330 + t * (tip - 330 - 1330), CY - 4 * 240 * t * (1 - t) + 150 * t * t) for t in [i / 60 for i in range(61)]]
    dots = new()
    d = ImageDraw.Draw(dots)
    for i, (x, y) in enumerate(pts):
        if i % 3 == 0:
            d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(255, 225, 150, 255))
    blur_add(out, dots, 2)
    shell(out, pts[28][0] + 130, pts[28][1], 260, 30)
    smoke(out, tip - 460, tip - 120, CY - 20, 90, seed=5, tone=(70, 70, 76))
    fireball(out, tip - 200, CY + 70, 110, 14, 3)
    return out


def shotgun(body, tip):
    """a shotgun: a large muzzle flash and a spray of pellets widening to the right"""
    out = body.copy()
    muzzle_flash(out, 1.0, 340)
    rnd = random.Random(31)
    sp = new()
    d = ImageDraw.Draw(sp)
    for _ in range(46):
        t = rnd.uniform(0.15, 1.0)
        x = 1500 + t * (tip - 1560)
        spread = 40 + 220 * t
        y = CY + rnd.uniform(-1, 1) * spread * 0.9
        d.line((x - 60, y - (y - CY) * 0.06, x, y), fill=(255, 225, 140, 255), width=5)
        d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(255, 250, 220, 255))
    blur_add(out, sp, 2)
    return out


def emp_grenade(body, tip):
    """an EMP grenade: a round grenade with a fuse ring, blue electric arcs and a pulse ring"""
    out = body.copy()
    muzzle_glow(out, (110, 200, 255), 0.6)
    cx = tip - 230
    rnd = random.Random(4)
    pulse = new()
    d = ImageDraw.Draw(pulse)
    for r, a in ((200, 255), (150, 200), (100, 150)):
        d.ellipse((cx - r, CY - r, cx + r, CY + r), outline=(130, 210, 255, a), width=7)
    blur_add(out, pulse, 4)
    for i in range(7):
        a = i * math.tau / 7 + 0.3
        line_glow(out, bolt(cx + math.cos(a) * 60, CY + math.sin(a) * 60, cx + math.cos(a) * 190, CY + math.sin(a) * 190, rnd, 18, 9), (130, 210, 255), 4, 3)
    g = np.zeros((H, W, 4), np.float32)
    ball = mask_of(lambda dd: dd.ellipse((cx - 64, CY - 64, cx + 64, CY + 64), fill=255))
    part(g, ball, (130, 150, 90), (36, 44, 24), bevel=22, grain=0.05, spec=1.0)
    for dy in (-26, 0, 26):
        part(g, mask_of(lambda dd, dy=dy: dd.rectangle((cx - 64, CY + dy - 5, cx + 64, CY + dy + 5), fill=255)), (30, 32, 36), (8, 9, 11), bevel=2)
    top = mask_of(lambda dd: dd.rounded_rectangle((cx - 20, CY - 84, cx + 20, CY - 52), radius=8, fill=255))
    part(g, top, (150, 152, 158), (50, 52, 58), bevel=4)
    out.alpha_composite(wa.to_img(g))
    return out


def self_destruct(tip):
    """self-destruction: a round black bomb with a burning fuse and a big explosion"""
    out = new()
    g = np.zeros((H, W, 4), np.float32)
    part(g, mask_of(lambda d: d.ellipse((380, CY - 140, 660, CY + 140), fill=255)), (110, 112, 120), (10, 11, 14), bevel=40, grain=0.05, spec=1.0, rust=0.1)
    part(g, mask_of(lambda d: d.rounded_rectangle((485, CY - 176, 555, CY - 130), radius=12, fill=255)), (120, 122, 128), (40, 42, 48), bevel=6)
    img = w2.shadowed(wa.to_img(g))
    out.alpha_composite(img)
    fuse = [(520, CY - 176), (510, CY - 215), (545, CY - 238), (590, CY - 228)]
    d = ImageDraw.Draw(out)
    d.line(fuse, fill=(150, 110, 60, 255), width=10, joint="curve")
    sphere(out, 594, CY - 227, 20, (255, 190, 60))
    sp = new()
    ds = ImageDraw.Draw(sp)
    rnd = random.Random(2)
    for _ in range(14):
        a = rnd.uniform(0, math.tau)
        ds.line((594, CY - 227, 594 + math.cos(a) * 44, CY - 227 + math.sin(a) * 44), fill=(255, 230, 140, 255), width=3)
    blur_add(out, sp, 1.5)
    smoke(out, tip - 640, tip - 60, CY - 10, 100, seed=3, tone=(70, 70, 76))
    fireball(out, tip - 260, CY, 140, 18, 5)
    return out


def make_all():
    cannon = wa.gun_body()
    pic = {}

    def tip(cw):
        return 20 + w2.FRONT * cw
    pic["d-gun"] = (dgun(cannon, tip(3300)), 3300)
    pic["stun-beam"] = (stun(cannon, tip(3300)), 3300)
    pic["flak"] = (flak(cannon, tip(3500)), 3500)
    pic["lightning"] = (lightning(cannon, tip(3300)), 3300)
    pic["machine-gun-light"] = (machine_gun(cannon, tip(3900), 1, 9, 16, 0), 3900)
    pic["machine-gun-medium"] = (machine_gun(cannon, tip(3500), 2, 11, 20, 0), 3500)
    pic["machine-gun-heavy"] = (machine_gun(cannon, tip(3200), 3, 14, 24, 0), 3200)
    pic["gauss"] = (gauss(cannon, tip(3300)), 3300)
    pic["artillery"] = (artillery(cannon, tip(3300)), 3300)
    pic["shotgun"] = (shotgun(cannon, tip(3500)), 3500)
    pic["emp-grenade"] = (emp_grenade(w2.launcher_body(1, 150), tip(3300)), 3300)
    pic["self-destruct"] = (self_destruct(tip(3300)), 3300)
    only = os.environ.get("ART_ONLY")
    return {k: v for k, v in pic.items() if not only or k in only.split(",")}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(here)), "game-modes", "weapon-images")
    os.makedirs(out, exist_ok=True)
    rows = []
    for name, (big, cw) in make_all().items():
        img = wa.panel_banner(big, cw)
        img.save(os.path.join(out, "weapon_%s.png" % name))
        rows.append((name, img))
        print("weapon_%s.png" % name, flush=True)
    for s in range(0, len(rows), 6):
        part_rows = rows[s:s + 6]
        sheet = Image.new("RGB", (768, len(part_rows) * 136), (0, 0, 0))
        for i, (name, img) in enumerate(part_rows):
            sheet.paste(img, (0, i * 136))
            ImageDraw.Draw(sheet).text((6, i * 136 + 4), name, fill=(255, 255, 255))
        sheet.save(os.path.join(out, "sheet_new%d.png" % (s // 6 + 1)))


if __name__ == "__main__":
    main()
