"""More weapon pictures for the panel of Renegade (plasma cannon, cannon, missile launcher, torpedo launcher, starburst launcher, rocket salvo), same style as weapon_art.py
(drawn with Pillow and numpy, the same bevelled metal parts): a gun or a launcher with the projectile coming out at the front.

  The pictures are drawn by weapon_art_build.py (it lists them and draws them in parallel); this file has the drawing functions.
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import weapon_art as wa
from weapon_art import W, H, part, mask_of, poly, rrect, hazard, rivets, scratches, hose, curve, mix, OLIVE_T, OLIVE_B, STEEL_T, STEEL_B, DARK_T, DARK_B

CY = 421


def muzzle_glow(out, color, r=1.0):
    """the glow in the opening of the muzzle (so that it is not black)"""
    gl = new()
    ImageDraw.Draw(gl).ellipse((1224 - 20 * r, 350 - 10 * r, 1318, 492 + 10 * r), fill=color + (255,))
    out.alpha_composite(gl.filter(ImageFilter.GaussianBlur(9)))


def blur_add(out, layer, r):
    out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r)))
    out.alpha_composite(layer)


def new():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


# ------------------------------------------------------------------ the launcher: a housing with a bundle of tubes
def launcher_body(rows, tube_h, label_stripes=True):
    """a box launcher: a rear clamp, an olive housing and `rows` tubes of the height tube_h stacked at the front (they end at x 1310)"""
    g = np.zeros((H, W, 4), np.float32)
    part(g, mask_of(poly([(120, 250), (250, 250), (290, 300), (290, 560), (250, 620), (150, 620), (110, 560), (110, 300)])), STEEL_T, STEEL_B, bevel=9, rust=0.10)
    part(g, mask_of(rrect((60, 280, 170, 590), 38)), DARK_T, DARK_B, bevel=10)
    part(g, mask_of(rrect((82, 320, 150, 555), 24)), (28, 30, 34), (12, 13, 16), bevel=8)
    hazard(g, mask_of(rrect((118, 330, 150, 540), 8)), (110, 330, 160, 540), angle=-0.6, gap=36, width=18)
    body = mask_of(poly([(250, 290), (900, 290), (940, 330), (940, 570), (900, 610), (260, 610), (230, 570), (230, 330)]))
    part(g, body, DARK_T, DARK_B, bevel=8, rust=0.10)
    plate = mask_of(poly([(290, 322), (880, 322), (910, 350), (910, 520), (290, 520)]))
    part(g, plate, OLIVE_T, OLIVE_B, bevel=8, rust=0.12)
    hazard(g, plate, (300, 330, 540, 380), angle=-0.7)
    part(g, mask_of(rrect((600, 360, 780, 410), 8)), (40, 42, 46), (16, 17, 20), bevel=3)
    for i in range(5):
        g[368 + i * 8:371 + i * 8, 612:770, :3] *= 0.5
    # the feed hoses
    hose(g, curve((240, 450), (260, 560), (360, 560)), 20, (188, 38, 34))
    hose(g, curve((330, 300), (300, 270), (330, 330)), 18, (40, 40, 44))
    # the tubes
    total = rows * tube_h + (rows - 1) * 10
    y0 = CY - total // 2
    for i in range(rows):
        a, b = y0 + i * (tube_h + 10), y0 + i * (tube_h + 10) + tube_h
        t = mask_of(rrect((880, a, 1310, b), min(tube_h // 2, 40)))
        part(g, t, STEEL_T, STEEL_B, bevel=max(4, tube_h // 8), rust=0.10, spec=0.9)
        for x in (930, 1010, 1100):
            part(g, mask_of(rrect((x, a - 3, x + 18, b + 3), 5)), (96, 98, 104), (34, 36, 40), bevel=3)
        mouth = mask_of(lambda d, a=a, b=b: d.ellipse((1262, a + 2, 1332, b - 2), fill=255))
        part(g, mouth, (170, 172, 178), (60, 62, 68), bevel=6, spec=1.0)
        inner = mask_of(lambda d, a=a, b=b: d.ellipse((1282, a + tube_h * 0.12, 1330, b - tube_h * 0.12), fill=255))
        part(g, inner, (12, 13, 16), (3, 4, 5), bevel=4)
    pts = [(300, 340), (420, 340), (500, 350), (860, 340), (880, 500), (300, 500), (700, 300), (500, 300), (860, 580), (300, 580)]
    rivets(g, pts, 6)
    k = np.linspace(1.22, 0.78, H, dtype=np.float32)[:, None, None]
    g[:, :, :3] = np.clip(g[:, :, :3] * k, 0, 255)
    scratches(g)
    return shadowed(wa.to_img(g))


def shadowed(img):
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(22)).point(lambda v: int(v * 0.55))
    sh.putalpha(a)
    sh.paste((0, 0, 0, 255), (0, 0), a)
    sh = wa.ImageChopsOffset(sh, 0, 26)
    out = new()
    out.alpha_composite(sh)
    out.alpha_composite(img)
    return out


# ------------------------------------------------------------------ the projectiles
def pod_body():
    """a rocket pod (like on a helicopter): a housing and a round drum at the front whose face has a ring of small round openings"""
    g = np.zeros((H, W, 4), np.float32)
    part(g, mask_of(poly([(120, 250), (250, 250), (290, 300), (290, 560), (250, 620), (150, 620), (110, 560), (110, 300)])), STEEL_T, STEEL_B, bevel=9, rust=0.10)
    part(g, mask_of(rrect((60, 280, 170, 590), 38)), DARK_T, DARK_B, bevel=10)
    part(g, mask_of(rrect((82, 320, 150, 555), 24)), (28, 30, 34), (12, 13, 16), bevel=8)
    hazard(g, mask_of(rrect((118, 330, 150, 540), 8)), (110, 330, 160, 540), angle=-0.6, gap=36, width=18)
    body = mask_of(poly([(250, 330), (800, 330), (840, 360), (840, 540), (800, 570), (260, 570), (230, 540), (230, 360)]))
    part(g, body, DARK_T, DARK_B, bevel=8, rust=0.10)
    plate = mask_of(poly([(290, 352), (780, 352), (810, 380), (810, 500), (290, 500)]))
    part(g, plate, OLIVE_T, OLIVE_B, bevel=8, rust=0.12)
    hazard(g, plate, (300, 358, 520, 400), angle=-0.7)
    hose(g, curve((240, 450), (260, 560), (360, 540)), 20, (188, 38, 34))
    # the drum: its side, a ring and its round face with the openings
    side = mask_of(rrect((780, 255, 1250, 590), 40))
    part(g, side, STEEL_T, STEEL_B, bevel=14, rust=0.10, spec=0.9)
    for x in (830, 930, 1040, 1140):
        part(g, mask_of(rrect((x, 251, x + 20, 594), 6)), (96, 98, 104), (34, 36, 40), bevel=4)
    face = mask_of(lambda d: d.ellipse((1150, 236, 1340, 606), fill=255))
    part(g, face, (170, 172, 178), (60, 62, 68), bevel=10, spec=1.0)
    face2 = mask_of(lambda d: d.ellipse((1166, 258, 1326, 584), fill=255))
    part(g, face2, (74, 76, 82), (26, 28, 32), bevel=6)
    holes = [(0, 0)] + [(math.cos(i * math.tau / 6) * 1.0, math.sin(i * math.tau / 6) * 1.0) for i in range(6)] + [(math.cos(i * math.tau / 12 + 0.26) * 1.95, math.sin(i * math.tau / 12 + 0.26) * 1.95) for i in range(12)]
    for hx, hy in holes:
        x, y = 1246 + hx * 36, 421 + hy * 60
        part(g, mask_of(lambda d, x=x, y=y: d.ellipse((x - 17, y - 29, x + 17, y + 29), fill=255)), (150, 152, 158), (50, 52, 58), bevel=3)
        part(g, mask_of(lambda d, x=x, y=y: d.ellipse((x - 11, y - 22, x + 11, y + 22), fill=255)), (10, 11, 13), (2, 3, 4), bevel=2)
    rivets(g, [(300, 365), (500, 365), (780, 365), (300, 485), (760, 485), (900, 270), (1100, 270), (900, 575), (1100, 575)], 6)
    k = np.linspace(1.22, 0.78, H, dtype=np.float32)[:, None, None]
    g[:, :, :3] = np.clip(g[:, :, :3] * k, 0, 255)
    scratches(g)
    return shadowed(wa.to_img(g))


# ------------------------------------------------------------------ the projectiles; tip = the x of the front of the projectile (the same far right in every picture, the trails run from the muzzle to it)
def sphere(out, cx, cy, r, color):
    """a glowing ball: a wide halo, the body in the colour, a bright core with a white centre"""
    c2, c3, c4 = mix(color, 255, 0.45), mix(color, 255, 0.8), mix(color, 255, 0.95)
    halo = new()
    ImageDraw.Draw(halo).ellipse((cx - r * 2.0, cy - r * 2.0, cx + r * 2.0, cy + r * 2.0), fill=color + (140,))
    out.alpha_composite(halo.filter(ImageFilter.GaussianBlur(r * 0.7)))
    for rr, c in ((r, color), (r * 0.78, c2), (r * 0.5, c3), (r * 0.28, c4)):
        l = new()
        ImageDraw.Draw(l).ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=c + (255,))
        blur_add(out, l, max(2, r * 0.05))


def plasma(body, color, k, tip):
    """a plasma ball far to the right with a long trail of smaller balls from the muzzle; k = size (1 = heavy)"""
    out = body.copy()
    c2 = mix(color, 255, 0.5)
    gl = new()
    ImageDraw.Draw(gl).ellipse((1220, 350, 1318, 492), fill=color + (255,))
    out.alpha_composite(gl.filter(ImageFilter.GaussianBlur(8)))
    r = 105 * k
    cx = tip - 1.5 * r
    rnd = random.Random(5)
    n = max(7, int((cx - r - 1330) / 95))
    for i in range(n):
        x = 1330 + i * (cx - r - 1330) / n
        sphere(out, x, CY + rnd.randint(-8, 8) * k, r * (0.12 + 0.30 * i / n), color)
    sphere(out, cx, CY, r, color)
    sp = new()
    d = ImageDraw.Draw(sp)
    for _ in range(26):
        a = rnd.uniform(0, math.tau)
        l0, l1 = r * rnd.uniform(1.0, 1.4), r * rnd.uniform(1.5, 2.3)
        d.line((cx + math.cos(a) * l0, CY + math.sin(a) * l0, cx + math.cos(a) * l1, CY + math.sin(a) * l1), fill=c2 + (255,), width=3)
    blur_add(out, sp, 1.5)
    return out


def shell(out, cx, cy, length, rad, tip=(190, 150, 70)):
    """an artillery shell pointing right: steel body, brass band, dark tip, a lit edge on top"""
    m = mask_of(lambda d: (d.rounded_rectangle((cx - length, cy - rad, cx, cy + rad), radius=int(rad * 0.4), fill=255),
                           d.polygon([(cx - 6, cy - rad), (cx + length * 0.28, cy - rad * 0.28), (cx + length * 0.28, cy + rad * 0.28), (cx - 6, cy + rad)], fill=255)))
    g = np.zeros((H, W, 4), np.float32)
    part(g, m, (170, 172, 178), (52, 54, 60), bevel=max(4, rad // 5), grain=0.05, spec=1.0)
    band = mask_of(lambda d: d.rectangle((cx - length * 0.42, cy - rad - 2, cx - length * 0.34, cy + rad + 2), fill=255))
    part(g, wa.ImageChops_multiply(band, m), (206, 160, 70), (110, 80, 30), bevel=3, grain=0.02)
    tipm = mask_of(lambda d: d.polygon([(cx + length * 0.05, cy - rad * 0.95), (cx + length * 0.28, cy - rad * 0.28), (cx + length * 0.28, cy + rad * 0.28), (cx + length * 0.05, cy + rad * 0.95)], fill=255))
    part(g, tipm, tip, tuple(int(c * 0.4) for c in tip), bevel=4)
    out.alpha_composite(wa.to_img(g))


def flame(out, x_back, cy, length, rad, color=(255, 150, 40)):
    """an exhaust flame running to the left from x_back: orange body, yellow core, white centre"""
    c2, c3 = mix(color, 255, 0.5), mix(color, 255, 0.9)
    for s, c in ((1.0, color), (0.7, c2), (0.4, c3)):
        l = new()
        ImageDraw.Draw(l).polygon([(x_back, cy - rad * s), (x_back - length * s, cy - rad * 0.15 * s), (x_back - length * s * 1.05, cy + rad * 0.15 * s), (x_back, cy + rad * s)], fill=c + (255,))
        blur_add(out, l, 6 * s)


def smoke(out, x0, x1, cy, rad, seed=3, tone=(120, 120, 124)):
    rnd = random.Random(seed)
    sm = new()
    d = ImageDraw.Draw(sm)
    x = x0
    while x < x1:
        r = rnd.randint(int(rad * 0.55), int(rad * 1.1))
        yy = cy + rnd.randint(-int(rad * .6), int(rad * .6))
        d.ellipse((x - r, yy - r, x + r, yy + r), fill=tone + (rnd.randint(70, 130),))
        x += int(rad * 0.7)
    out.alpha_composite(sm.filter(ImageFilter.GaussianBlur(rad * 0.35)))


def cannon_shot(body, k, tip):
    """a muzzle flash, a long smoke trail and the shell far to the right with a motion streak; k = size of the shell (1 = heavy)"""
    out = body.copy()
    muzzle_glow(out, (255, 160, 50))
    fl = new()
    ImageDraw.Draw(fl).polygon([(1300, CY - 80 * k), (1560 + 120 * k, CY - 22 * k), (1740 + 180 * k, CY), (1560 + 120 * k, CY + 22 * k), (1300, CY + 80 * k)], fill=(255, 150, 40, 255))
    blur_add(out, fl, 12)
    fl2 = new()
    ImageDraw.Draw(fl2).polygon([(1300, CY - 44 * k), (1500 + 100 * k, CY - 10 * k), (1620 + 120 * k, CY), (1500 + 100 * k, CY + 10 * k), (1300, CY + 44 * k)], fill=(255, 235, 170, 255))
    blur_add(out, fl2, 6)
    rad = int(46 * k + 12)
    length = int(330 * k + 110)
    cx = tip - 0.28 * length
    smoke(out, 1330, cx - length, CY - 20, 55 * k + 20)
    streak = new()
    ImageDraw.Draw(streak).polygon([(cx - length, CY - rad * 0.5), (cx - length - 900, CY), (cx - length, CY + rad * 0.5)], fill=(255, 220, 160, 150))
    out.alpha_composite(streak.filter(ImageFilter.GaussianBlur(8)))
    shell(out, cx, CY, length, rad)
    return out


def missile(out, cx, cy, length, rad, flame_len=None):
    """a rocket pointing right: a white body, red nose, large red fins, a band and a long exhaust flame (it must not look like a shell)"""
    flame(out, cx - length, cy, flame_len or length * 1.1, rad * 1.0)
    g = np.zeros((H, W, 4), np.float32)
    body = (238, 238, 242)
    bm = mask_of(lambda d: (d.rounded_rectangle((cx - length, cy - rad, cx - length * 0.2, cy + rad), radius=int(rad * 0.3), fill=255),
                            d.polygon([(cx - length * 0.22, cy - rad), (cx + length * 0.14, cy), (cx - length * 0.22, cy + rad)], fill=255)))
    fin = mask_of(lambda d: (d.polygon([(cx - length, cy - rad), (cx - length * 0.62, cy - rad), (cx - length * 0.92, cy - rad * 3.4)], fill=255),
                             d.polygon([(cx - length, cy + rad), (cx - length * 0.62, cy + rad), (cx - length * 0.92, cy + rad * 3.4)], fill=255)))
    part(g, fin, (214, 60, 52), (96, 24, 20), bevel=3)
    part(g, bm, body, tuple(int(c * 0.40) for c in body), bevel=max(4, int(rad / 4)), grain=0.04, spec=1.0)
    nm = mask_of(lambda d: d.polygon([(cx - length * 0.34, cy - rad), (cx + length * 0.14, cy), (cx - length * 0.34, cy + rad)], fill=255))
    part(g, nm, (214, 50, 44), (100, 22, 20), bevel=4)
    for fx in (0.52, 0.44):
        st = mask_of(lambda d, fx=fx: d.rectangle((cx - length * fx, cy - rad - 2, cx - length * (fx - 0.05), cy + rad + 2), fill=255))
        part(g, wa.ImageChops_multiply(st, bm), (40, 42, 48), (14, 15, 18), bevel=2)
    out.alpha_composite(wa.to_img(g))


def missile_shot(body, k, tip):
    out = body.copy()
    rad = int(40 * k + 14)
    length = int(340 * k + 190)
    cx = tip - 0.14 * length
    smoke(out, 1330, cx - length * 1.4, CY, 40 * k + 16, seed=8, tone=(200, 200, 206))
    missile(out, cx, CY, length, rad)
    return out


def torpedo_shot(body, k, tip):
    """a long torpedo in steel with a propeller; the whole picture is water, bubbles only behind the torpedo"""
    water = Image.fromarray(wa.vgrad((W, H), (34, 110, 170), (8, 34, 70)).astype(np.uint8), "RGB").convert("RGBA")
    rays = new()
    rd = ImageDraw.Draw(rays)
    for x in range(200, W, 420):
        rd.polygon([(x, 0), (x + 90, 0), (x - 160, H), (x - 260, H)], fill=(140, 210, 255, 26))
    water.alpha_composite(rays.filter(ImageFilter.GaussianBlur(30)))
    water.alpha_composite(body)
    out = water
    rad = int(34 * k + 16)
    length = int(520 * k + 360)
    cx = tip - rad
    rnd = random.Random(2)
    bub = new()
    d = ImageDraw.Draw(bub)
    for _ in range(int(220 * (cx - length - 1330) / 1800)):
        x = rnd.randint(1330, int(cx - length - 40))
        y = CY + rnd.randint(-int(rad * 1.5), int(rad * 1.5))
        r = rnd.randint(4, int(10 + 10 * k))
        d.ellipse((x - r, y - r, x + r, y + r), outline=(215, 240, 255, 230), width=2, fill=(170, 215, 240, 60))
    out.alpha_composite(bub)
    g = np.zeros((H, W, 4), np.float32)
    bm = mask_of(lambda d: (d.rounded_rectangle((cx - length, CY - rad, cx - 30, CY + rad), radius=int(rad * 0.5), fill=255),
                            d.ellipse((cx - length * 0.2, CY - rad, cx + rad * 0.9, CY + rad), fill=255)))
    part(g, bm, (150, 170, 184), (34, 46, 60), bevel=max(5, rad // 4), grain=0.04, spec=1.0)
    band = mask_of(lambda d: d.rectangle((cx - length * 0.5, CY - rad - 2, cx - length * 0.42, CY + rad + 2), fill=255))
    part(g, wa.ImageChops_multiply(band, bm), (230, 70, 56), (110, 28, 24), bevel=2)
    prop = mask_of(lambda d: (d.polygon([(cx - length, CY), (cx - length - 20, CY - rad * 2.2), (cx - length + 30, CY - rad * 2.2)], fill=255),
                              d.polygon([(cx - length, CY), (cx - length - 20, CY + rad * 2.2), (cx - length + 30, CY + rad * 2.2)], fill=255)))
    part(g, prop, (200, 170, 80), (80, 62, 26), bevel=3)
    out.alpha_composite(wa.to_img(g))
    return out


def salvo_shot(body, tip):
    """many small rockets in a fan, their tips at the right, with smoke trails"""
    out = body.copy()
    n = 7
    for i in range(n):
        f = (i - (n - 1) / 2) / ((n - 1) / 2)
        cy = CY + f * 150
        t = tip - abs(f) * 150 - (i % 3) * 110
        smoke(out, 1330, t - 330, cy, 16, seed=20 + i, tone=(200, 200, 206))
        missile(out, t - 0.14 * 220, cy, 220, 15, flame_len=150)
    return out


def starburst_shot(body, tip):
    """a large rocket and, far to the right, its burst: a bright flash with a fan of small rockets (bomblets) flying out of it, each with a glowing head and a tail"""
    out = body.copy()
    cx, cy = tip - 250, CY
    rocket_nose = cx - 330
    smoke(out, 1330, rocket_nose - 560 * 1.2, CY, 46, seed=9, tone=(200, 200, 206))
    missile(out, rocket_nose - 0.14 * 560, cy, 560, 46)
    glow = new()
    ImageDraw.Draw(glow).ellipse((cx - 260, cy - 260, cx + 260, cy + 260), fill=(255, 170, 40, 200))
    out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(70)))
    rnd = random.Random(4)
    n = 15
    for i in range(n):
        a = -math.pi * 0.5 + (i + 0.5) * math.tau / n
        a += rnd.uniform(-0.08, 0.08)
        ln = rnd.randint(200, 330)
        x1, y1 = cx + math.cos(a) * ln, cy + math.sin(a) * ln * 0.9
        x0, y0 = cx + math.cos(a) * 40, cy + math.sin(a) * 40 * 0.9
        tail = new()
        td = ImageDraw.Draw(tail)
        td.polygon([(x0, y0), (x1 - math.sin(a) * 9, y1 + math.cos(a) * 9), (x1 + math.sin(a) * 9, y1 - math.cos(a) * 9)], fill=(255, 190, 70, 230))
        blur_add(out, tail, 4)
        hd = new()
        ImageDraw.Draw(hd).ellipse((x1 - 16, y1 - 16, x1 + 16, y1 + 16), fill=(255, 245, 210, 255))
        blur_add(out, hd, 5)
    flash = new()
    fd = ImageDraw.Draw(flash)
    for r, c in ((90, (255, 190, 70)), (62, (255, 230, 140)), (34, (255, 255, 235))):
        fd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c + (255,))
    blur_add(out, flash, 10)
    return out


# ------------------------------------------------------------------ the pictures
FRONT = 0.93   # the front of the projectile at this part of the width of the picture shown
