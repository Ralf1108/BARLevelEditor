"""Draws the pictures of the weapon categories (renegade-weapon-categories.md) for the weapon panel of Renegade, with Pillow.

  python weapon_icons.py [out_dir]     writes weapon_<category>.png (256 x 128, transparent corners) and a preview of the panel row with it: preview_panel.png

Only the categories that are drawn so far (DRAWN) are made. The pictures are drawn at twice the size and scaled down (smooth edges).
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 256, 128
S = 2  # supersampling


def gradient(w, h, top, bottom):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        k = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(4))
        for x in range(w):
            px[x, y] = c
    return img


def card():
    """the dark rounded card every picture sits on"""
    w, h = W * S, H * S
    bg = gradient(w, h, (34, 40, 52, 255), (14, 17, 24, 255))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=22 * S, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    return out, mask


def glow(layer, radius, strength=1.0):
    g = layer.filter(ImageFilter.GaussianBlur(radius * S))
    if strength != 1.0:
        a = g.getchannel("A").point(lambda v: min(255, int(v * strength)))
        g.putalpha(a)
    return g


def barrel(base, x0, y, size, tone=1.0):
    """a metal emitter on the left: a block with a darker muzzle ring and a light edge on top"""
    d = ImageDraw.Draw(base)
    hh = size * S
    top, bot = y - hh // 2, y + hh // 2
    body = gradient(60 * S, hh, (int(150 * tone), int(158 * tone), int(172 * tone), 255), (int(60 * tone), int(66 * tone), int(80 * tone), 255))
    base.paste(body, (x0 * S, top))
    d.rectangle((x0 * S, top, x0 * S + 60 * S, top + 2 * S), fill=(220, 228, 240, 255))
    ring = gradient(14 * S, hh + 12 * S, (90, 96, 110, 255), (30, 34, 44, 255))
    base.paste(ring, ((x0 + 60) * S, top - 6 * S))
    d.rectangle(((x0 + 74) * S, y - (hh // 2 - 4 * S) // S * S // 1, (x0 + 78) * S, y + (hh // 2 - 4 * S) // S * S // 1), fill=(255, 235, 200, 255))
    return (x0 + 78) * S


def beam(base, x_start, y, thickness, color, length_to):
    """a glowing beam: a wide soft halo, a coloured body and a white-hot core"""
    w, h = base.size
    layers = []
    halo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).rectangle((x_start, y - thickness * 3 * S, length_to, y + thickness * 3 * S), fill=color + (150,))
    layers.append(glow(halo, thickness * 2.2, 1.5))
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((x_start, y - thickness * S, length_to, y + thickness * S), radius=thickness * S, fill=color + (255,))
    layers.append(glow(body, thickness * 0.35, 1.0))
    layers.append(body)
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(core).rounded_rectangle((x_start, y - thickness * S // 2.4, length_to, y + thickness * S // 2.4), radius=thickness * S // 2, fill=(255, 250, 235, 255))
    layers.append(glow(core, 0.8, 1.0))
    layers.append(core)
    for l in layers:
        base.alpha_composite(l)


def burst(base, cx, cy, r, color):
    """the flash where the beam hits: a bright radial glow and a few sparks"""
    w, h = base.size
    fl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(fl)
    for k in range(10, 0, -1):
        rr = r * S * k / 10
        a = int(255 * (1 - k / 10) ** 1.4)
        c = (int(color[0] + (255 - color[0]) * (1 - k / 10)), int(color[1] + (255 - color[1]) * (1 - k / 10)), int(color[2] + (255 - color[2]) * (1 - k / 10)), min(255, a + 40))
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=c)
    base.alpha_composite(glow(fl, 3, 1.2))
    base.alpha_composite(fl)
    sp = ImageDraw.Draw(base)
    for ang, ln in ((-35, 26), (-12, 34), (15, 30), (38, 24), (62, 18), (-60, 18), (180 - 25, 14)):
        a = math.radians(ang)
        sp.line((cx + math.cos(a) * r * S * 0.5, cy + math.sin(a) * r * S * 0.5, cx + math.cos(a) * (r + ln) * S, cy + math.sin(a) * (r + ln) * S), fill=(255, 220, 160, 255), width=2 * S)


def laser(thick, color, barrel_size, double=False):
    img, mask = card()
    y = H * S // 2
    xs = barrel(img, 14, y, barrel_size)
    if double:
        beam(img, xs, y - 14 * S, thick, color, (W - 62) * S)
        beam(img, xs, y + 14 * S, thick, color, (W - 62) * S)
    else:
        beam(img, xs, y, thick, color, (W - 62) * S)
    burst(img, (W - 50) * S, y, 26 if thick > 6 else 18, color)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    d = ImageDraw.Draw(out)
    d.rounded_rectangle((1, 1, W * S - 2, H * S - 2), radius=22 * S, outline=(120, 130, 150, 255), width=2 * S)
    return out.resize((W, H), Image.LANCZOS)


DRAWN = {
    "laser-heavy": lambda: laser(14, (255, 70, 40), 46),
}


def preview(icon, path, title="High energy laser", line="range 435   reload 0.3 s   READY", tag="LMB", color=(255, 80, 60)):
    """how the picture looks in a row of the panel (the panel is 320 wide, a row 62 high, shown at 2x)"""
    k = 2
    w, h = 340 * k, 80 * k
    bg = Image.new("RGBA", (w, h), (24, 24, 28, 255))
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, w, h), fill=(0, 0, 0, 255))
    d.rectangle((6 * k, 6 * k, w - 6 * k, h - 6 * k), fill=(35, 35, 40, 255))
    ic = icon.resize((int(W * 0.5 * k * 0.62 * 2 / 2), int(H * 0.5 * k * 0.62 * 2 / 2)), Image.LANCZOS)
    ic = icon.resize((96 * k // 1, 48 * k // 1), Image.LANCZOS)
    bg.alpha_composite(ic, (12 * k, 16 * k))
    try:
        f1 = ImageFont.truetype("arial.ttf", 17 * k)
        f2 = ImageFont.truetype("arial.ttf", 12 * k)
    except OSError:
        f1 = f2 = ImageFont.load_default()
    x = 122 * k
    d.text((x, 12 * k), title, font=f1, fill=(255, 255, 255, 255))
    d.text((w - 18 * k, 12 * k), tag, font=f2, fill=color + (255,), anchor="ra")
    d.text((x, 38 * k), line, font=f2, fill=(180, 180, 180, 255))
    d.rectangle((x, 58 * k, w - 18 * k, 66 * k), fill=(40, 40, 40, 255))
    d.rectangle((x, 58 * k, w - 18 * k, 66 * k), fill=color + (255,))
    bg.save(path)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "weapon-icons")
    os.makedirs(out, exist_ok=True)
    for name, fn in DRAWN.items():
        img = fn()
        img.save(os.path.join(out, "weapon_%s.png" % name))
        print("weapon_%s.png" % name)
    preview(DRAWN["laser-heavy"](), os.path.join(out, "preview_panel.png"))


if __name__ == "__main__":
    main()
