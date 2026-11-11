"""The rest of the weapon pictures for the panel of Renegade (d-gun, stun beam, flak, lightning, machine gun in three sizes, gauss, artillery, shotgun, EMP grenade, self-destruct, railgun, flamethrower, depth charge, anti-air missile, bomb, nuclear), same style as
weapon_art.py and weapon_art2.py: a gun or launcher on the left, the projectile or the effect far right (the same place in every picture).

  The pictures are drawn by weapon_art_build.py (it lists them and draws them in parallel); this file has the drawing functions: f(body, tip) -> the picture before the crop.
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import weapon_art as wa
import weapon_art2 as w2
from weapon_art import W, H, part, mask_of, poly, rrect, mix
from weapon_art2 import new, blur_add, sphere, smoke, shell, muzzle_glow, CY


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
    muzzle_glow(out, (255, 160, 50))
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
    muzzle_glow(out, (255, 160, 50))
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
    muzzle_glow(out, (255, 160, 50))
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
    muzzle_glow(out, (255, 160, 50))
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


def self_destruct(body_unused, tip):
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


def backdrop(body, top, bottom, rays=None):
    """the body on a whole-picture background (water or sky) with a vertical gradient"""
    bg = Image.fromarray(wa.vgrad((W, H), top, bottom).astype(np.uint8), "RGB").convert("RGBA")
    if rays:
        r = new()
        rd = ImageDraw.Draw(r)
        for x in range(200, W, 420):
            rd.polygon([(x, 0), (x + 90, 0), (x - 160, H), (x - 260, H)], fill=rays)
        bg.alpha_composite(r.filter(ImageFilter.GaussianBlur(30)))
    bg.alpha_composite(body)
    return bg


def railgun(body, tip):
    """a railgun: a very thin white-hot slug, its glowing streak and chevron shock waves behind it"""
    out = body.copy()
    muzzle_glow(out, (255, 190, 110), 0.7)
    cx = tip - 40
    streak = new()
    ImageDraw.Draw(streak).polygon([(1330, CY - 4), (cx - 80, CY - 12), (cx - 80, CY + 12), (1330, CY + 4)], fill=(255, 210, 140, 255))
    blur_add(out, streak, 8)
    ch = new()
    d = ImageDraw.Draw(ch)
    for i in range(7):
        x = cx - 120 - i * 260
        if x < 1450:
            break
        h = 60 + i * 26
        d.line([(x + 70, CY - h), (x, CY), (x + 70, CY + h)], fill=(190, 225, 255, 255 - i * 25), width=7)
    blur_add(out, ch, 3)
    needle = new()
    ImageDraw.Draw(needle).polygon([(cx - 240, CY - 14), (cx - 40, CY - 14), (cx + 40, CY), (cx - 40, CY + 14), (cx - 240, CY + 14)], fill=(255, 250, 235, 255))
    blur_add(out, needle, 3)
    sphere(out, cx - 10, CY, 24, (255, 180, 90))
    return out


def flamethrower(body, tip):
    """a flamethrower: a stream of fire that widens from the muzzle, with fire balls and black smoke at the end"""
    out = body.copy()
    muzzle_glow(out, (255, 140, 30))
    cone = new()
    ImageDraw.Draw(cone).polygon([(1310, CY - 30), (tip, CY - 190), (tip, CY + 190), (1310, CY + 30)], fill=(255, 120, 20, 200))
    out.alpha_composite(cone.filter(ImageFilter.GaussianBlur(40)))
    rnd = random.Random(13)
    n = 16
    for i in range(n):
        tt = i / (n - 1)
        x = 1360 + tt * (tip - 1500)
        r = 26 + 130 * tt
        fireball(out, x, CY + rnd.uniform(-1, 1) * (20 + 110 * tt), r * 0.75, 8, i)
    smoke(out, tip - 380, tip - 20, CY - 70, 70, seed=4, tone=(50, 50, 56))
    return out


def depth_charge(body, tip):
    """a depth charge: a steel barrel with hoops sinking in blue water, bubbles above and behind it"""
    out = backdrop(body, (34, 110, 170), (8, 34, 70), (140, 210, 255, 26))
    rnd = random.Random(17)
    cx, cy = tip - 90, CY + 20
    bub = new()
    d = ImageDraw.Draw(bub)
    for _ in range(90):
        x = rnd.randint(1330, int(cx - 80))
        y = cy - rnd.randint(0, 130) - (cx - x) * 0.04
        r = rnd.randint(4, 15)
        d.ellipse((x - r, y - r, x + r, y + r), outline=(215, 240, 255, 230), width=2, fill=(170, 215, 240, 60))
    out.alpha_composite(bub)
    g = np.zeros((H, W, 4), np.float32)
    drum = mask_of(lambda dd: dd.rounded_rectangle((cx - 110, cy - 80, cx + 110, cy + 80), radius=34, fill=255))
    part(g, drum, (110, 118, 124), (20, 26, 32), bevel=16, grain=0.05, spec=1.0, rust=0.2)
    for dx in (-72, -4, 64):
        part(g, wa.ImageChops_multiply(mask_of(lambda dd, dx=dx: dd.rectangle((cx + dx, cy - 86, cx + dx + 18, cy + 86), fill=255)), drum), (170, 130, 60), (70, 48, 18), bevel=3)
    part(g, mask_of(lambda dd: dd.rounded_rectangle((cx - 36, cy - 104, cx + 36, cy - 76), radius=8, fill=255)), (200, 60, 50), (90, 24, 20), bevel=3)
    out.alpha_composite(wa.to_img(g))
    return out


SKY = ((70, 130, 210), (170, 205, 235))   # the sky of the weapons against aircraft (anti-air missile, flak, anti-nuke, bomb, nuclear): a light blue that gets paler downwards


def on_sky(body, tip, fn):
    """the picture of fn on the sky backdrop (a module function so that functools.partial(on_sky, fn=...) can be sent to the processes of weapon_art_build.py)"""
    bg = backdrop(new(), SKY[0], SKY[1])
    bg.alpha_composite(fn(body, tip))
    return bg


def aa_missile(body, tip):
    """an anti-air missile: a slim missile with a smoke trail in the sky, a jet in front of it"""
    out = backdrop(body, SKY[0], SKY[1])
    cx = tip - 330
    smoke(out, 1330, cx - 380, CY, 26, seed=11, tone=(235, 235, 240))
    w2.missile(out, cx, CY, 380, 17, flame_len=240)
    jet = new()
    d = ImageDraw.Draw(jet)
    j = tip - 70
    d.polygon([(j - 180, CY - 14), (j - 30, CY - 14), (j + 60, CY), (j - 30, CY + 14), (j - 180, CY + 14)], fill=(52, 58, 68, 255))
    d.polygon([(j - 110, CY - 12), (j - 150, CY - 100), (j - 120, CY - 100), (j - 50, CY - 12)], fill=(60, 66, 78, 255))
    d.polygon([(j - 110, CY + 12), (j - 150, CY + 100), (j - 120, CY + 100), (j - 50, CY + 12)], fill=(60, 66, 78, 255))
    d.polygon([(j - 180, CY - 14), (j - 215, CY - 50), (j - 195, CY - 50), (j - 150, CY - 14)], fill=(60, 66, 78, 255))
    out.alpha_composite(jet.filter(ImageFilter.GaussianBlur(1)))
    ex = new()
    ImageDraw.Draw(ex).ellipse((j - 40, CY - 30, j + 40, CY + 30), fill=(255, 190, 70, 120))
    blur_add(out, ex, 18)
    return out


def bomb_shape(length, rad, angle):
    """a falling bomb (olive body, yellow band, fins) turned by `angle` degrees: an RGBA picture"""
    g = np.zeros((H, W, 4), np.float32)
    cx, cy = 600, CY
    body = mask_of(lambda d: (d.rounded_rectangle((cx - length, cy - rad, cx - length * 0.15, cy + rad), radius=int(rad * 0.4), fill=255),
                              d.polygon([(cx - length * 0.2, cy - rad), (cx + length * 0.1, cy), (cx - length * 0.2, cy + rad)], fill=255)))
    fin = mask_of(lambda d: (d.polygon([(cx - length, cy - rad), (cx - length * 0.8, cy - rad), (cx - length * 0.95, cy - rad * 2.2)], fill=255),
                             d.polygon([(cx - length, cy + rad), (cx - length * 0.8, cy + rad), (cx - length * 0.95, cy + rad * 2.2)], fill=255)))
    part(g, fin, (90, 96, 100), (28, 30, 34), bevel=3)
    part(g, body, (120, 128, 70), (34, 38, 18), bevel=max(4, rad // 4), grain=0.05, spec=1.0, rust=0.1)
    band = mask_of(lambda d: d.rectangle((cx - length * 0.5, cy - rad - 2, cx - length * 0.42, cy + rad + 2), fill=255))
    part(g, wa.ImageChops_multiply(band, body), (230, 190, 40), (120, 90, 20), bevel=2)
    img = wa.to_img(g).crop((cx - length - 10, cy - int(rad * 2.4), cx + int(length * 0.15), cy + int(rad * 2.4)))
    return img.rotate(angle, expand=True, resample=Image.BICUBIC)


def bomb(body_unused, tip):
    """a bomb: the wing of an aircraft with a rack at the left, three bombs falling away from it in a curve"""
    out = new()
    wing = new()
    d = ImageDraw.Draw(wing)
    d.polygon([(120, CY - 200), (900, CY - 120), (900, CY - 70), (120, CY - 150)], fill=(86, 92, 102, 255))
    d.polygon([(120, CY - 200), (900, CY - 120), (900, CY - 110), (120, CY - 188)], fill=(130, 136, 148, 255))
    d.rectangle((420, CY - 112, 560, CY - 64), fill=(60, 64, 72, 255))
    out.alpha_composite(wing.filter(ImageFilter.GaussianBlur(1)))
    for i, (x, y, a) in enumerate(((560, CY - 30, -8), (1500, CY + 50, -22), (tip - 280, CY + 130, -40))):
        b = bomb_shape(250, 38, a)
        st = new()
        ImageDraw.Draw(st).polygon([(x - 260, y - 10), (x - 700, y - 60 - i * 20), (x - 700, y - 20 - i * 20), (x - 260, y + 10)], fill=(255, 255, 255, 40))
        out.alpha_composite(st.filter(ImageFilter.GaussianBlur(10)))
        out.alpha_composite(b, (int(x - b.width / 2), int(y - b.height / 2)))
    return out


def trefoil(out, cx, cy, r):
    """the radiation sign: a yellow disc with three black blades and a black centre"""
    s = new()
    d = ImageDraw.Draw(s)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(250, 205, 30, 255))
    for k in range(3):
        a0 = -90 + k * 120 - 30
        d.pieslice((cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86), a0 - 30 + 30, a0 + 30 + 30, fill=(20, 20, 22, 255))
    d.ellipse((cx - r * 0.50, cy - r * 0.50, cx + r * 0.50, cy + r * 0.50), fill=(250, 205, 30, 255))
    d.ellipse((cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2), fill=(20, 20, 22, 255))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(20, 20, 22, 255), width=max(3, int(r * 0.06)))
    out.alpha_composite(s)


def nuke_missile(out, cx, cy, length, rad):
    """a nuclear missile pointing right: all white with a radiation sign, a black and yellow warning ring behind the nose, dark fins and a long flame"""
    w2.flame(out, cx - length, cy, length * 0.55, rad * 0.9)
    g = np.zeros((H, W, 4), np.float32)
    white = (246, 246, 250)
    bm = mask_of(lambda d: (d.rounded_rectangle((cx - length, cy - rad, cx - length * 0.22, cy + rad), radius=int(rad * 0.3), fill=255),
                            d.polygon([(cx - length * 0.24, cy - rad), (cx + length * 0.12, cy), (cx - length * 0.24, cy + rad)], fill=255)))
    fin = mask_of(lambda d: (d.polygon([(cx - length, cy - rad), (cx - length * 0.7, cy - rad), (cx - length * 0.95, cy - rad * 2.6)], fill=255),
                             d.polygon([(cx - length, cy + rad), (cx - length * 0.7, cy + rad), (cx - length * 0.95, cy + rad * 2.6)], fill=255)))
    part(g, fin, (120, 124, 132), (40, 42, 48), bevel=3)
    part(g, bm, white, tuple(int(c * 0.72) for c in white), bevel=max(4, int(rad / 4)), grain=0.03, spec=1.0)
    ring = mask_of(lambda d: d.rectangle((cx - length * 0.36, cy - rad - 2, cx - length * 0.28, cy + rad + 2), fill=255))
    part(g, wa.ImageChops_multiply(ring, bm), (230, 190, 40), (120, 90, 20), bevel=2)
    ring2 = mask_of(lambda d: d.rectangle((cx - length * 0.80, cy - rad - 2, cx - length * 0.78, cy + rad + 2), fill=255))
    part(g, wa.ImageChops_multiply(ring2, bm), (40, 42, 48), (14, 15, 18), bevel=2)
    out.alpha_composite(wa.to_img(g))
    trefoil(out, cx - length * 0.55, cy, rad * 0.8)


def nuclear(body_unused, tip):
    """a nuclear missile: a white missile with a radiation sign, in the middle at the left, and a mushroom cloud far right"""
    out = new()
    w2.smoke(out, 150, 760, CY, 34, seed=7, tone=(200, 200, 206))
    nuke_missile(out, 1560, CY, 1000, 72)
    cx = tip - 200
    ground = new()
    ImageDraw.Draw(ground).ellipse((cx - 260, CY + 190, cx + 260, CY + 250), fill=(120, 80, 50, 220))
    out.alpha_composite(ground.filter(ImageFilter.GaussianBlur(12)))
    stem = new()
    ImageDraw.Draw(stem).polygon([(cx - 42, CY + 220), (cx - 24, CY - 60), (cx + 24, CY - 60), (cx + 42, CY + 220)], fill=(190, 110, 60, 255))
    blur_add(out, stem, 14)
    cap = new()
    d = ImageDraw.Draw(cap)
    for dx, dy, r in ((-90, -110, 78), (90, -110, 78), (0, -150, 100), (-50, -70, 70), (50, -70, 70), (0, -90, 90)):
        d.ellipse((cx + dx - r, CY + dy - r, cx + dx + r, CY + dy + r), fill=(235, 130, 40, 255))
    blur_add(out, cap, 12)
    core = new()
    d = ImageDraw.Draw(core)
    for dx, dy, r in ((-60, -120, 52), (60, -120, 52), (0, -140, 70), (0, -100, 60)):
        d.ellipse((cx + dx - r, CY + dy - r, cx + dx + r, CY + dy + r), fill=(255, 215, 120, 255))
    blur_add(out, core, 10)
    return out


def anti_nuke(body, tip):
    """an anti-nuke launcher: a slim interceptor missile and, far right, the incoming nuclear warhead (white, radiation sign) hit in an explosion"""
    out = body.copy()
    cx = tip - 560
    smoke(out, 1330, cx - 520, CY, 26, seed=14, tone=(205, 205, 212))
    w2.missile(out, cx, CY, 520, 28, flame_len=300)
    wh = new()
    nuke_missile(wh, W - 1 - (tip - 180), CY, 420, 40)
    out.alpha_composite(wh.transpose(Image.FLIP_LEFT_RIGHT))
    fireball(out, tip - 270, CY, 95, 14, 7)
    return out
