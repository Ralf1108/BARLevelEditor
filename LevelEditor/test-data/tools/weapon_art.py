"""Detailed pictures of weapons for the panel of Renegade, drawn with Pillow and numpy (no outside pictures, no AI): a metal body with bevelled plates, rust and scratches,
hazard stripes, vents, cables and glowing parts.

  python weapon_art.py [out_dir]    draws the heavy laser: weapon_laser-heavy_big.png (1600 x 700, transparent) and weapon_laser-heavy.png (the picture for the panel, 256 x 128)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1600, 700
rng = np.random.default_rng(7)
random.seed(7)


# ------------------------------------------------------------------ helpers
def mask_of(draw_fn, size=(W, H)):
    m = Image.new("L", size, 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def noise(size, scale, seed):
    """soft random noise 0..1: random values blurred (the larger the scale, the larger the blotches)"""
    r = np.random.default_rng(seed)
    a = (r.random((size[1] // max(1, scale) + 2, size[0] // max(1, scale) + 2)) * 255).astype(np.uint8)
    im = Image.fromarray(a).resize(size, Image.BICUBIC)
    return np.asarray(im, dtype=np.float32) / 255.0


def vgrad(size, top, bottom):
    h = size[1]
    k = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    t = np.array(top, np.float32)[None, None, :]
    b = np.array(bottom, np.float32)[None, None, :]
    return np.broadcast_to(t + (b - t) * k, (h, size[0], 3)).copy()


def shade(mask, bevel=7, light=(-0.6, -0.8)):
    """a lit edge: from the blurred mask the slope is taken; slopes toward the light get brighter, away from it darker (-1..1)"""
    b = np.asarray(mask.filter(ImageFilter.GaussianBlur(bevel)), dtype=np.float32) / 255.0
    gy, gx = np.gradient(b)
    n = np.sqrt(gx * gx + gy * gy + 1e-4)
    d = (gx * light[0] + gy * light[1]) / n
    edge = np.clip(n * 18, 0, 1)
    return -d * edge


def shade_edge(mask, width=16):
    """1 at the edge of a part, falling to 0 inside (rust and wear gather at the edges)"""
    a = np.asarray(mask, np.float32) / 255.0
    inner = np.asarray(mask.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(width)), np.float32) / 255.0
    return np.clip(a - inner, 0, 1)


def rivets(layer, pts, r=6):
    for x, y in pts:
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).ellipse((x - r, y - r, x + r, y + r), fill=255)
        part(layer, m, (170, 172, 178), (60, 62, 68), bevel=3, grain=0.02, spec=1.0)


def part(layer, mask, top, bottom, bevel=7, grain=0.10, rust=0.0, spec=0.55):
    """paints a metal part into the layer (an RGBA float array): a vertical gradient, bevelled edges, a fine grain, a little rust"""
    size = mask.size
    col = vgrad(size, top, bottom)
    s = shade(mask, bevel)
    col += (s[:, :, None] * 120 * spec)
    rim = shade_edge(mask, 5)
    col *= (1 - rim[:, :, None] * 0.30)
    g = noise(size, 3, int(rng.integers(1 << 30))) - 0.5
    col *= (1 + g[:, :, None] * grain * 2)
    if rust > 0:
        r = noise(size, 22, int(rng.integers(1 << 30))) * 0.55 + noise(size, 6, int(rng.integers(1 << 30))) * 0.45
        rim = shade_edge(mask)
        r = np.clip((r + rim * 0.55 - (0.80 - rust * 1.2)) * 6, 0, 1) * 0.8
        col = col * (1 - r[:, :, None] * 0.45) + np.array([112, 66, 40], np.float32)[None, None, :] * (r[:, :, None] * 0.45)
    a = np.asarray(mask, dtype=np.float32) / 255.0
    paste(layer, np.clip(col, 0, 255), a)


def paste(layer, rgb, alpha):
    a = alpha[:, :, None]
    layer[:, :, :3] = layer[:, :, :3] * (1 - a) + rgb * a
    layer[:, :, 3] = np.maximum(layer[:, :, 3], alpha * 255)


def to_img(layer):
    return Image.fromarray(np.clip(layer, 0, 255).astype(np.uint8), "RGBA")


def poly(points):
    return lambda d: d.polygon(points, fill=255)


def rrect(box, r):
    return lambda d: d.rounded_rectangle(box, radius=r, fill=255)


def hazard(layer, mask, box, color=(226, 170, 32), gap=34, width=20, angle=1.0):
    """yellow and black stripes on a part (clipped to the mask), a little worn away"""
    stripes = Image.new("L", mask.size, 0)
    d = ImageDraw.Draw(stripes)
    x0, y0, x1, y1 = box
    for k in range(-20, 80):
        x = x0 + k * gap
        d.polygon([(x, y1), (x + width, y1), (x + width + (y1 - y0) * angle, y0), (x + (y1 - y0) * angle, y0)], fill=255)
    clip = mask_of(lambda dd: dd.rectangle(box, fill=255))
    st = np.minimum(np.asarray(stripes, np.float32), np.asarray(clip, np.float32)) * (np.asarray(mask, np.float32) / 255.0) / 255.0
    wear = noise(mask.size, 7, 99)
    st = st * np.clip((wear - 0.25) * 3, 0.35, 1)
    base = np.array(color, np.float32)[None, None, :]
    lit = base * (1 + shade(mask, 5)[:, :, None] * 0.25)
    # the dark gaps between the stripes
    dark = np.asarray(clip, np.float32) / 255.0 * (np.asarray(mask, np.float32) / 255.0) * (1 - st)
    layer[:, :, :3] = layer[:, :, :3] * (1 - dark[:, :, None] * 0.75) + np.array([20, 20, 22], np.float32)[None, None, :] * (dark[:, :, None] * 0.75)
    layer[:, :, :3] = layer[:, :, :3] * (1 - st[:, :, None]) + lit * st[:, :, None]


def scratches(layer, count=150):
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = random.randint(40, W - 340), random.randint(200, 640)
        l = random.randint(10, 70)
        a = random.uniform(-0.35, 0.35)
        d.line((x, y, x + math.cos(a) * l, y + math.sin(a) * l), fill=random.randint(60, 150), width=1)
    s = np.asarray(img, np.float32) / 255.0
    inside = layer[:, :, 3] / 255.0
    layer[:, :, :3] += (s * inside)[:, :, None] * 60


def hose(layer, pts, width, color, shadow=True):
    """a cable or a hose: a thick line along a curve, a bright stripe on top of it and a dark under side"""
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=width, joint="curve")
    for p in pts:
        d.ellipse((p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2), fill=255)
    part(layer, m, color, tuple(int(c * 0.35) for c in color), bevel=width // 3, grain=0.05, spec=0.9)
    hi = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hi).line([(p[0] - width * 0.18, p[1] - width * 0.22) for p in pts], fill=120, width=max(2, width // 6), joint="curve")
    h = np.asarray(hi.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0 * (np.asarray(m, np.float32) / 255.0)
    layer[:, :, :3] += h[:, :, None] * 110


def curve(p0, p1, p2, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


# ------------------------------------------------------------------ the heavy laser
OLIVE_T, OLIVE_B = (118, 120, 70), (62, 66, 38)
STEEL_T, STEEL_B = (132, 134, 140), (52, 54, 60)
DARK_T, DARK_B = (58, 60, 66), (22, 24, 28)


def heavy_laser():
    gun = np.zeros((H, W, 4), np.float32)
    cy = 420

    # --- the rear clamp: a C-shaped bracket with three claws
    part(gun, mask_of(poly([(120, 250), (250, 250), (290, 300), (290, 560), (250, 620), (150, 620), (110, 560), (110, 470), (150, 470), (150, 350), (110, 350), (110, 300)])), STEEL_T, STEEL_B, bevel=9, rust=0.10)
    part(gun, mask_of(rrect((30, 345, 160, 395), 16)), STEEL_T, STEEL_B, bevel=6, rust=0.06)
    part(gun, mask_of(rrect((30, 470, 160, 520), 16)), STEEL_T, STEEL_B, bevel=6, rust=0.06)
    part(gun, mask_of(rrect((60, 280, 170, 590), 38)), DARK_T, DARK_B, bevel=10)
    inner = mask_of(rrect((82, 320, 150, 555), 24))
    part(gun, inner, (28, 30, 34), (12, 13, 16), bevel=8)
    hz = mask_of(rrect((118, 330, 150, 540), 8))
    hazard(gun, hz, (110, 330, 160, 540), angle=-0.6, gap=36, width=18)

    # --- the machine body: dark core, vents on top, a pipe underneath
    body = mask_of(poly([(250, 300), (760, 300), (800, 340), (1010, 340), (1040, 300), (1250, 290), (1300, 330), (1300, 560), (1250, 600), (260, 600), (230, 560), (230, 330)]))
    part(gun, body, DARK_T, DARK_B, bevel=8, rust=0.10)
    # vent block on top with fins
    top = mask_of(poly([(430, 235), (500, 215), (790, 215), (820, 245), (820, 330), (430, 330)]))
    part(gun, top, STEEL_T, STEEL_B, bevel=8, rust=0.12)
    fins = Image.new("L", (W, H), 0)
    fd = ImageDraw.Draw(fins)
    for i in range(30):
        x = 470 + i * 12
        fd.rectangle((x, 238, x + 7, 322), fill=255)
    part(gun, ImageChops_multiply(fins, top), (22, 24, 28), (8, 9, 11), bevel=2, grain=0.05)
    for i in range(30):
        x = 470 + i * 12
        gun[240:322, x:x + 2, :3] += 40 * (gun[240:322, x:x + 2, 3:4] / 255.0)
    for x0 in (440, 590):
        part(gun, mask_of(rrect((x0, 196, x0 + 70, 240), 10)), STEEL_T, STEEL_B, bevel=6, rust=0.05)

    # --- the olive armour plates
    plate1 = mask_of(poly([(290, 322), (440, 322), (520, 360), (520, 470), (290, 470)]))
    part(gun, plate1, OLIVE_T, OLIVE_B, bevel=8, rust=0.12)
    hazard(gun, plate1, (300, 326, 470, 368), angle=-0.7)
    plate2 = mask_of(poly([(520, 345), (860, 345), (900, 390), (1010, 390), (1010, 470), (760, 470), (720, 430), (520, 430)]))
    part(gun, plate2, OLIVE_T, OLIVE_B, bevel=8, rust=0.12)
    part(gun, mask_of(rrect((555, 372, 650, 410), 6)), (40, 42, 46), (16, 17, 20), bevel=3)
    for i in range(5):
        gun[378 + i * 6:380 + i * 6, 565:640, :3] *= 0.55
    plate3 = mask_of(poly([(910, 500), (1040, 450), (1160, 450), (1210, 480), (1170, 560), (920, 560)]))
    part(gun, plate3, OLIVE_T, OLIVE_B, bevel=8, rust=0.15)
    hazard(gun, plate3, (950, 500, 1130, 548), angle=-0.7)
    # slats in the middle section
    sl = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(sl)
    for i in range(11):
        x = 540 + i * 26
        sd.rectangle((x, 475, x + 12, 585), fill=255)
    part(gun, ImageChops_multiply(sl, body), (22, 24, 28), (8, 9, 11), bevel=2, grain=0.05)

    # --- the lower tube with rings
    tube = mask_of(rrect((360, 540, 630, 625), 36))
    part(gun, tube, STEEL_T, STEEL_B, bevel=14, rust=0.10, spec=0.9)
    for x in (400, 450, 520, 580):
        part(gun, mask_of(rrect((x, 538, x + 22, 627), 6)), (96, 98, 104), (34, 36, 40), bevel=4)
    part(gun, mask_of(rrect((596, 556, 640, 610), 14)), (20, 22, 26), (6, 7, 9), bevel=6)

    # --- cables
    hose(gun, curve((240, 440), (270, 520), (350, 520)), 20, (188, 38, 34))
    hose(gun, curve((330, 300), (300, 280), (320, 330)), 18, (40, 40, 44))
    hose(gun, curve((300, 470), (330, 560), (430, 520)), 16, (30, 30, 34))
    hose(gun, curve((300, 330), (330, 300), (390, 292)), 14, (190, 40, 36))
    hose(gun, curve((380, 524), (440, 500), (540, 515)), 20, (188, 38, 34))
    part(gun, mask_of(rrect((535, 485, 640, 540), 10)), STEEL_T, STEEL_B, bevel=6, rust=0.06)

    # --- the muzzle housing
    muz = mask_of(poly([(1010, 330), (1090, 300), (1250, 280), (1310, 315), (1310, 575), (1250, 610), (1090, 590), (1010, 560)]))
    part(gun, muz, STEEL_T, STEEL_B, bevel=10, rust=0.14, spec=0.8)
    for x in (1030, 1056, 1082, 1108):
        part(gun, mask_of(rrect((x, 372, x + 14, 470), 5)), (255, 140, 60), (200, 60, 24), bevel=2, grain=0.02)
    cap = mask_of(poly([(1130, 300), (1260, 282), (1300, 322), (1300, 380), (1130, 380)]))
    part(gun, cap, (150, 152, 158), (70, 72, 78), bevel=8, rust=0.08)
    # the ring around the opening
    ring = mask_of(lambda d: d.ellipse((1190, 316, 1330, 524), fill=255))
    part(gun, ring, (170, 172, 178), (60, 62, 68), bevel=10, spec=1.0)
    ring2 = mask_of(lambda d: d.ellipse((1214, 342, 1318, 498), fill=255))
    part(gun, ring2, (46, 48, 54), (16, 17, 20), bevel=8)
    for k in range(10):
        a = k / 10 * math.pi * 2
        x, y = 1266 + math.cos(a) * 62, 420 + math.sin(a) * 82
        part(gun, mask_of(lambda d, x=x, y=y: d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=255)), (200, 202, 208), (60, 62, 68), bevel=2)

    rivets(gun, [(310, 340), (420, 340), (500, 350), (310, 455), (500, 455), (540, 360), (700, 360), (850, 360), (990, 408), (960, 520), (1100, 520), (1180, 470), (460, 245), (780, 232), (1100, 320), (1250, 300), (1030, 560), (1250, 590)], 6)
    k = np.linspace(1.22, 0.78, H, dtype=np.float32)[:, None, None]
    gun[:, :, :3] = np.clip(gun[:, :, :3] * k, 0, 255)
    scratches(gun)
    img = to_img(gun)

    # --- ambient shadow under the gun
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(22)).point(lambda v: int(v * 0.55))
    sh.putalpha(a)
    sh.paste((0, 0, 0, 255), (0, 0), a)
    sh = ImageChopsOffset(sh, 0, 26)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(sh)
    out.alpha_composite(img)

    # --- the glow inside the opening, the heat round it and the beam with its electric tendrils
    glowl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glowl)
    gd.ellipse((1224, 350, 1310, 492), fill=(255, 120, 30, 255))
    gd.ellipse((1240, 372, 1306, 472), fill=(255, 190, 90, 255))
    gd.ellipse((1254, 392, 1306, 450), fill=(255, 245, 210, 255))
    out.alpha_composite(glowl.filter(ImageFilter.GaussianBlur(5)))
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse((1100, 250, 1500, 590), fill=(255, 80, 20, 150))
    hd.rectangle((1290, 352, W, 488), fill=(255, 70, 20, 170))
    out.alpha_composite(halo.filter(ImageFilter.GaussianBlur(42)))
    bm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bm)
    bd.rounded_rectangle((1270, 388, W + 40, 454), radius=33, fill=(255, 92, 22, 255))
    out.alpha_composite(bm.filter(ImageFilter.GaussianBlur(7)))
    out.alpha_composite(bm)
    core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    cd.rounded_rectangle((1270, 402, W + 40, 440), radius=19, fill=(255, 226, 150, 255))
    cd.rounded_rectangle((1270, 412, W + 40, 430), radius=9, fill=(255, 255, 245, 255))
    out.alpha_composite(core.filter(ImageFilter.GaussianBlur(2)))
    out.alpha_composite(core)
    # lightning tendrils along the beam
    tend = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(tend)
    for _ in range(14):
        x = random.randint(1300, W - 20)
        y = 421 + random.randint(-22, 22)
        pts = [(x, y)]
        for _ in range(random.randint(4, 8)):
            x += random.randint(10, 34)
            y += random.randint(-16, 16)
            pts.append((x, y))
        td.line(pts, fill=(255, 190, 90, 255), width=2)
    out.alpha_composite(tend.filter(ImageFilter.GaussianBlur(1.4)))
    out.alpha_composite(tend)
    return out


def ImageChops_multiply(a, b):
    return Image.fromarray((np.asarray(a, np.float32) * np.asarray(b, np.float32) / 255.0).astype(np.uint8))


def ImageChopsOffset(img, dx, dy):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (dx, dy))
    return out


def panel_icon(big, size=(256, 128)):
    """the picture for the panel: the weapon and a part of the beam on a dark card with rounded corners"""
    bbox = big.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    crop = big.crop((max(0, bbox[0] - 10), max(0, bbox[1] + 40), min(W, bbox[2] - 120), min(H, bbox[3] - 20)))
    card = Image.new("RGBA", size, (0, 0, 0, 0))
    bg = Image.new("RGBA", size, (30, 33, 40, 255))
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=16, fill=255)
    card.paste(bg, (0, 0), m)
    k = min((size[0] - 16) / crop.width, (size[1] - 12) / crop.height)
    ic = crop.resize((int(crop.width * k), int(crop.height * k)), Image.LANCZOS)
    card.alpha_composite(ic, ((size[0] - ic.width) // 2, (size[1] - ic.height) // 2))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((1, 1, size[0] - 2, size[1] - 2), radius=16, outline=(110, 118, 134, 255), width=2)
    return card


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "weapon-icons")
    os.makedirs(out, exist_ok=True)
    big = heavy_laser()
    bg = Image.new("RGBA", big.size, (28, 28, 30, 255))
    bg.alpha_composite(big)
    big.save(os.path.join(out, "weapon_laser-heavy_big.png"))
    bg.convert("RGB").save(os.path.join(out, "weapon_laser-heavy_big_on_dark.png"))
    panel_icon(big).save(os.path.join(out, "weapon_laser-heavy.png"))
    print("done")


if __name__ == "__main__":
    main()
