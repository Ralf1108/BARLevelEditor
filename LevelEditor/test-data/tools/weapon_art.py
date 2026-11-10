"""Detailed pictures of weapons for the panel of Renegade, drawn with Pillow and numpy (no outside pictures, no AI): a metal body with bevelled plates, rust and scratches,
hazard stripes, vents, cables and glowing parts.

  python weapon_art.py [out_dir]    draws the cannon once and makes the three sizes of the laser from it (heavy: green, medium: blue, light: red; weapon_laser-<size>.png, the picture of a panel row: 768 x 128)
                                    and writes the body of the cannon as source/laser_cannon_body.png (default out_dir: LevelEditor/game-modes/weapon-images)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 4300, 800   # (wide: the beam runs far to the right, the banner of the panel row is 6 : 1)
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


def gun_body():
    """the laser cannon without its glow (the same body for every size; the beam and the glowing parts are added by beam_fx in the colour of the size)"""
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
        part(gun, mask_of(rrect((x, 372, x + 14, 470), 5)), (70, 72, 78), (30, 32, 36), bevel=2, grain=0.02)
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

    return out


def mix(c, white, k):
    return tuple(int(c[i] + (white - c[i]) * k) for i in range(3))


def beam_fx(body, color, k=1.0):
    """the glow in the opening, the glowing vents, the heat and the beam with its electric tendrils in a colour; k = the thickness of the beam (1 = the heavy laser)"""
    out = body.copy()
    c1, c2, c3, c4 = color, mix(color, 255, 0.45), mix(color, 255, 0.8), mix(color, 255, 0.94)
    # the glowing vents
    gl_v = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(gl_v)
    for x in (1030, 1056, 1082, 1108):
        vd.rounded_rectangle((x, 372, x + 14, 470), radius=5, fill=c2 + (255,))
    out.alpha_composite(gl_v.filter(ImageFilter.GaussianBlur(6)))
    out.alpha_composite(gl_v)
    # the glow in the opening
    glowl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glowl)
    gd.ellipse((1224, 350, 1310, 492), fill=c1 + (255,))
    gd.ellipse((1240, 372, 1306, 472), fill=c2 + (255,))
    gd.ellipse((1254, 392, 1306, 450), fill=c3 + (255,))
    out.alpha_composite(glowl.filter(ImageFilter.GaussianBlur(5)))
    # the heat round the muzzle and along the beam
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse((1100, 250, 1500, 590), fill=c1 + (150,))
    hd.rectangle((1290, int(421 - 69 * k), W, int(421 + 69 * k)), fill=c1 + (170,))
    out.alpha_composite(halo.filter(ImageFilter.GaussianBlur(42 * max(0.6, k))))
    # the body of the beam, the hot core and the white centre
    bm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bm).rounded_rectangle((1270, int(421 - 33 * k), W + 40, int(421 + 33 * k)), radius=int(33 * k), fill=c1 + (255,))
    out.alpha_composite(bm.filter(ImageFilter.GaussianBlur(7 * max(0.6, k))))
    out.alpha_composite(bm)
    core = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    cd.rounded_rectangle((1270, int(421 - 19 * k), W + 40, int(421 + 19 * k)), radius=int(19 * k), fill=c3 + (255,))
    cd.rounded_rectangle((1270, int(421 - 9 * k), W + 40, int(421 + 9 * k)), radius=int(9 * k), fill=c4 + (255,))
    out.alpha_composite(core.filter(ImageFilter.GaussianBlur(2)))
    out.alpha_composite(core)
    # lightning tendrils along the beam
    r = random.Random(11)
    tend = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(tend)
    for _ in range(int(34 * W / 2900)):
        x = r.randint(1300, W - 20)
        y = 421 + int(r.randint(-22, 22) * k)
        pts = [(x, y)]
        for _ in range(r.randint(4, 8)):
            x += r.randint(10, 34)
            y += int(r.randint(-16, 16) * k)
            pts.append((x, y))
        td.line(pts, fill=c2 + (255,), width=2)
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


def panel_banner(big, crop_width, size=(768, 128)):
    """the picture of a panel row: the weapon and its beam over the whole width (6 : 1) on a dark background; the row puts text and the cooldown on top of it. crop_width: how much of the
    picture is shown (the more, the smaller the weapon in the row)"""
    h = crop_width // 6
    crop = big.crop((20, 421 - h // 2, 20 + crop_width, 421 + h // 2))
    bg = gradient_bg(size)
    ic = crop.resize(size, Image.LANCZOS)
    bg.alpha_composite(ic, (0, 0))
    return bg.convert("RGB")


def gradient_bg(size):
    a = vgrad(size, (40, 46, 58), (14, 16, 22))
    out = Image.fromarray(a.astype(np.uint8), "RGB").convert("RGBA")
    return out


# the sizes: name, beam colour, thickness of the beam, the width of the picture that the row shows (the weapon is smaller in a row of a light weapon)
SIZES = [("laser-heavy", (60, 235, 90), 1.0, 2880), ("laser-medium", (70, 150, 255), 0.72, 3300), ("laser-light", (255, 70, 40), 0.45, 3900),
         ("laser-ultra", (60, 110, 255), 1.75, 2300),   # the heaviest laser: blue, a very thick beam (the Pulsar)
         ("heatray", (255, 205, 40), 1.35, 2600)]       # the heat ray: yellow (the Juggernaut)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(here)), "game-modes", "weapon-images")
    src = os.path.join(out, "source")
    os.makedirs(src, exist_ok=True)
    body = gun_body()
    # the picture of the cannon without glow: the source of the pictures of the sizes (drawn by this file, kept to look at it)
    body.crop((20, 190, 1330, 660)).save(os.path.join(src, "laser_cannon_body.png"))
    for name, color, k, cw in SIZES:
        big = beam_fx(body, color, k)
        panel_banner(big, cw).save(os.path.join(out, "weapon_%s.png" % name))
        print("weapon_%s.png" % name)


if __name__ == "__main__":
    main()
