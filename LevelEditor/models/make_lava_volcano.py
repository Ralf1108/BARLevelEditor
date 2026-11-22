"""Builds the model of the Volcano (lavavolcano.s3o) and its textures, a feature of the Level Editor: a crater of rock around a lake of lava.

The Volcano of the Volcano and Lava Extractor proof of concept (specs/lava.md). The model is only the rock: a floor of hot rock around the middle
(the lake, small enough for the platform of a Lava Extractor to cover it), a ring wall close around that platform with three breaches where lava
flows out, and a few boulders on the outside. The lava itself (the lake and the three streams, moving) is drawn by the gadget lava_generator.lua
with BAR's lava texture; it needs the same numbers (LAKE, RIM_*, BREACHES, BREACH_H).
The textures are made here too (no file of BAR is used): plates of dark rock with cracks (cells of a Voronoi pattern); in the upper half of the
texture the cracks glow (inner wall of the crater, the red channel of the second texture makes them shine), in the lower half they are dark (outer
slopes, boulders). Nothing reflects the sky (green channel 0).

Usage: python make_lava_volcano.py   (needs numpy and Pillow; no BAR files are read)
Writes lavavolcano.s3o, lavavolcano_color.png and lavavolcano_other.png next to this script; the setup packs them into the extra games as
objects3d/Units/lavavolcano.s3o and unittextures/lavavolcano_*.png.
"""
import math
import os
import random

import numpy as np
from PIL import Image

from make_lava_generator import face, piece
from make_lava_truck import write_s3o

HERE = os.path.dirname(os.path.abspath(__file__))

LAKE = 40.0  # radius of the lake of lava (drawn by the gadget): the platform of a Lava Extractor (88 x 80) covers it
FLOOR_Y = 0.6  # height of the floor of the crater (from the edge of the lake to the wall)
RIM_IN = 62.0  # inner foot of the wall (height 0): just outside the corners of the platform of a Lava Extractor (radius 59.5)
RIM_TOP = 72.0  # the crest
RIM_OUT = 98.0  # outer foot (height 0)
CREST = 20.0  # height of the crest (it varies by +-4)
BREACHES = (40.0, 160.0, 280.0)  # angles (degrees, from +x towards +z) of the breaches the streams flow out of
BREACH_W = 16.0  # half width of a breach (degrees)
BREACH_H = 2.5  # height of the crest in the middle of a breach
SEG = 48  # parts around
# rings across the wall: (fraction from the inner foot to the crest (0..1) or from the crest to the outer foot (1..2), height factor)
PROFILE = [(0.0, 0.0), (0.35, 0.55), (0.75, 0.93), (1.0, 1.0), (1.3, 0.85), (1.6, 0.45), (2.0, 0.0)]
TEX = 512  # size of the textures
HOT, COLD = (0.0, 0.5), (0.5, 1.0)  # v ranges (from the top, as in the game) of the two halves of the texture: glowing cracks, dark cracks
REPEAT = 8  # parts around that share one width of the texture


def breach_factor(deg):
    """1 away from the breaches, down to the breach height in their middle"""
    f = 1.0
    for b in BREACHES:
        d = abs((deg - b + 180) % 360 - 180)
        if d < BREACH_W:
            s = d / BREACH_W
            f = min(f, BREACH_H / CREST + (1 - BREACH_H / CREST) * s * s)
    return f


def area(k, j, rows, half):
    """the texture rectangle of part k (around) of band j (of rows bands across) in one half: continuous over REPEAT parts and over the bands"""
    u0 = (k % REPEAT) / REPEAT
    v0 = half[0] + (half[1] - half[0]) * j / rows
    return (u0, v0, u0 + 1 / REPEAT, v0 + (half[1] - half[0]) / rows)


def wall_piece():
    rnd = random.Random(7)
    crest = [CREST + rnd.uniform(-4, 4) for _ in range(SEG)]
    shift = [rnd.uniform(-2, 4) for _ in range(SEG)]  # (never more than 2 inwards: the platform of an extractor)
    rings = []  # rings[j][k] = (x, y, z)
    for frac, hf in PROFILE:
        ring = []
        for k in range(SEG):
            deg = 360.0 * k / SEG
            a = math.radians(deg)
            r = RIM_IN + (RIM_TOP - RIM_IN) * frac if frac <= 1 else RIM_TOP + (RIM_OUT - RIM_TOP) * (frac - 1)
            r += shift[k] * (1 - abs(frac - 1) * 0.5)
            y = crest[k] * breach_factor(deg) * hf
            ring.append((r * math.cos(a), y, r * math.sin(a)))
        rings.append(ring)
    inner_bands = sum(1 for f, _ in PROFILE[1:] if f <= 1.0)
    outer_bands = len(PROFILE) - 1 - inner_bands
    v, i = [], []
    for j in range(len(rings) - 1):
        inner = j < inner_bands
        for k in range(SEG):
            m = (k + 1) % SEG
            pts = [rings[j][k], rings[j][m], rings[j + 1][m], rings[j + 1][k]]
            mx = sum(p[0] for p in pts) / 4
            mz = sum(p[2] for p in pts) / 4
            out = (-mx, 1.0, -mz) if inner else (mx, 1.0, mz)  # the inner side faces the middle, the outer side away from it
            tex = area(k, j, inner_bands, HOT) if inner else area(k, j - inner_bands, outer_bands, COLD)
            u0, v0, u1, v1 = tex
            # (face stretches the rectangle from the first to the third point; bands run from the foot to the crest and on)
            face(v, i, pts, (u0, v0, u1, v1), out)
    return v, i


def floor(v, i):
    """the floor of the crater: a ring of hot rock from under the edge of the lake to under the wall"""
    r0, r1 = LAKE - 3, RIM_IN + 2
    for k in range(SEG):
        a0, a1 = 2 * math.pi * k / SEG, 2 * math.pi * (k + 1) / SEG
        pts = [(r0 * math.cos(a0), FLOOR_Y, r0 * math.sin(a0)), (r0 * math.cos(a1), FLOOR_Y, r0 * math.sin(a1)),
               (r1 * math.cos(a1), FLOOR_Y, r1 * math.sin(a1)), (r1 * math.cos(a0), FLOOR_Y, r1 * math.sin(a0))]
        face(v, i, pts, area(k, 0, 1, HOT), (0, 1, 0))


def boulders(v, i):
    """a few rocks on the outer slope, away from the breaches"""
    rnd = random.Random(11)
    placed = 0
    while placed < 9:
        deg = rnd.uniform(0, 360)
        if breach_factor(deg) < 1:
            continue
        a = math.radians(deg)
        r = rnd.uniform(RIM_TOP + 8, RIM_OUT + 4)
        cx, cz, s = r * math.cos(a), r * math.sin(a), rnd.uniform(3.5, 7)
        top = (cx + rnd.uniform(-1, 1), s * 1.3, cz + rnd.uniform(-1, 1))
        n = 5
        base = [(cx + s * math.cos(2 * math.pi * q / n + deg), 0.0, cz + s * math.sin(2 * math.pi * q / n + deg)) for q in range(n)]
        mid = [(cx + 0.8 * (b[0] - cx), s * 0.7, cz + 0.8 * (b[2] - cz)) for b in base]
        for q in range(n):
            w = (q + 1) % n
            out = (base[q][0] + base[w][0] - 2 * cx, 0.5, base[q][2] + base[w][2] - 2 * cz)
            tex = (q / n, COLD[0] + 0.1, (q + 1) / n, COLD[0] + 0.25)
            face(v, i, [base[q], base[w], mid[w], mid[q]], tex, out)
            face(v, i, [mid[q], mid[w], top, top], tex, (out[0], 1.5, out[2]))
        placed += 1

# ---------------------------------------------------------------- the textures


def smooth_noise(rng, n, cells):
    """value noise that tiles: random values on a coarse grid, enlarged smoothly"""
    g = rng.random((cells, cells))
    g = np.concatenate([g, g[:1]], axis=0)
    g = np.concatenate([g, g[:, :1]], axis=1)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((n + n // cells, n + n // cells), Image.BICUBIC)
    return np.asarray(img).astype(float)[:n, :n] / 255.0


def textures():
    rng = np.random.default_rng(5)
    n = TEX
    ys, xs = np.mgrid[0:n, 0:n] / n
    seeds = rng.random((70, 2))
    d1 = np.full((n, n), 9.0)
    d2 = np.full((n, n), 9.0)
    cell = np.zeros((n, n), int)
    for idx, (sx, sy) in enumerate(seeds):  # distances to the nearest and the second nearest seed (the texture tiles: wrapped distances)
        dx = np.abs(xs - sx)
        dy = np.abs(ys - sy)
        d = np.sqrt(np.minimum(dx, 1 - dx) ** 2 + np.minimum(dy, 1 - dy) ** 2)
        nearer = d < d1
        d2 = np.where(nearer, d1, np.minimum(d2, d))
        cell = np.where(nearer, idx, cell)
        d1 = np.where(nearer, d, d1)
    edge = d2 - d1
    crack = np.clip(1 - edge / 0.010, 0, 1) ** 1.5  # thin lines between the plates
    halo = np.clip(1 - edge / 0.035, 0, 1) ** 2  # the warm edge of a plate next to a crack
    shade = rng.random(len(seeds))[cell] * 0.35 + 0.65  # every plate a little darker or lighter
    grain = smooth_noise(rng, n, 64) * 0.5 + smooth_noise(rng, n, 16) * 0.5
    rock = (0.06 + 0.09 * grain) * shade
    hot = ys < 0.5  # the upper half: glowing cracks
    r = rock * 1.05 + hot * (crack * 0.95 + halo * 0.22)
    g = rock * 0.95 + hot * (crack * 0.42 + halo * 0.05)
    b = rock * 0.90 + hot * crack * 0.06
    dark = ~hot
    r, g, b = [np.where(dark, c * (1 - crack * 0.7), c) for c in (r, g, b)]  # the lower half: cracks darker than the rock
    color = np.dstack([r, g, b, np.zeros_like(r)])  # alpha 0: no team color
    other = np.dstack([hot * np.clip(crack * 1.2 + halo * 0.3, 0, 1), np.zeros_like(r), np.full_like(r, 0.8), np.ones_like(r)])
    for name, arr in (('lavavolcano_color.png', color), ('lavavolcano_other.png', other)):
        # (upside down: the engine reads a PNG texture of a model the other way round than BAR's DDS textures, whose areas count v from the top)
        Image.fromarray((np.clip(arr[::-1], 0, 1) * 255).astype(np.uint8), 'RGBA').save(os.path.join(HERE, name))
        print('written', name)


def main():
    v, i = wall_piece()
    floor(v, i)
    boulders(v, i)
    m = {'radius': 95.0, 'height': 24.0, 'mid': (0.0, 8.0, 0.0), 'tex1': b'lavavolcano_color.png', 'tex2': b'lavavolcano_other.png',
         'root': piece(b'base', (0.0, 0.0, 0.0), v, i)}
    out = os.path.join(HERE, 'lavavolcano.s3o')
    with open(out, 'wb') as f:
        f.write(write_s3o(m))
    print('written', out, len(v), 'vertices')
    textures()


if __name__ == '__main__':
    main()
