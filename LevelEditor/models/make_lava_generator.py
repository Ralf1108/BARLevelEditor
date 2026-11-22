"""Builds the model of the Lava Extractor (lavagen.s3o): a mine in the style of a steam engine in the lava of a Volcano, with conveyor belts out
to four storage pads outside the crater.

The extractor of the Volcano and Lava Extractor proof of concept (specs/lava.md), for all three factions (texture of Armada, the team color shows
on a band of the furnace, on the belts and on the fences). Made from scratch out of boxes and prisms with areas of BAR's texture Arm_color.dds:
  - a small platform (60 x 60) with a furnace (an eight-sided tower with copper bands, a cone on top) in the middle; in the corners a copper
    chimney, a glowing pool, a gear wheel ("wheel", it turns) and two pistons ("piston1", "piston2", up and down);
  - lava runs down the furnace and from a spout into the pool; drops ("drop1".."drop3") fall while it works;
  - four conveyor belts (east, south, west, north, through the four passes of the Volcano) with crates on them ("item1".."item8", two per belt,
    they ride outwards), each to a storage pad outside the crater (radius 106 to 134) with up to 6 metal blocks ("block1".."block24": pad k has
    6k-5 to 6k). All four pads show the same stock: Carriers load at whichever is nearest.
The unit script LevelEditor/scripts/lava_generator_script.lua moves the parts and shows the blocks (the gadget lava_generator.lua calls it).
All four sides are alike: the way the extractor was built does not matter.

Usage: python make_lava_generator.py   (no BAR files are read; the texture names are BAR's)
Writes lavagen.s3o next to this script; the setup packs it into the extra games as objects3d/Units/lavagen.s3o.
"""
import math
import os

from make_lava_truck import PLATE, TEAM, write_s3o

HERE = os.path.dirname(os.path.abspath(__file__))

# areas of Arm_color.dds (u0, v0, u1, v1; v from the top: the s3o texture coordinate t is 1 - v)
DARK = (0.255, 0.695, 0.278, 0.745)  # a dark grey plate
LAVA = (0.540, 0.021, 0.551, 0.039)  # a flat orange area that glows (red channel of Arm_other.dds high)
COPPER = (0.630, 0.262, 0.645, 0.280)  # dark copper
SILVER = (0.690, 0.078, 0.740, 0.108)  # a light metal plate (the metal blocks)
MATTE = (0.665, 0.471, 0.925, 0.489)  # a dark belt with segments, not shiny (green channel of Arm_other.dds 0): the floors

BLOCKS = 6  # metal blocks on each storage pad (the unit script shows ceil(stock / stock max * 6) on each)
FURNACE = (0.0, 0.0)  # x, z of the middle of the furnace (the middle of the model stands on the Volcano)
FLOOR = 2.5  # top of the platform
HALF = 28.0  # half the width of the platform
BELT_IN, BELT_OUT = 28.0, 107.0  # the belts: from the edge of the platform to the inner edge of a pad
BELT_Y = 4.5  # the top of a belt
PAD_IN, PAD_OUT, PAD_HALF = 106.0, 134.0, 16.0  # a storage pad: from the middle outwards, and half its width
DIRS = [(1, 0), (0, 1), (-1, 0), (0, -1)]  # the four belts and pads: east (+x), south (+z), west, north


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    n = math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2) or 1.0
    return (a[0] / n, a[1] / n, a[2] / n)


def face(v, i, pts, area, out):
    """a quad: 4 points around it, turned so that its front faces the direction out; area: the texture rectangle stretched over it"""
    n = norm(cross(sub(pts[1], pts[0]), sub(pts[2], pts[0])))
    if n[0] * out[0] + n[1] * out[1] + n[2] * out[2] < 0:
        pts = pts[::-1]
        n = (-n[0], -n[1], -n[2])
    u0, v0, u1, v1 = area
    uvs = [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)]
    k = len(v)
    for p, (s, t) in zip(pts, uvs):
        v.append((p[0], p[1], p[2], n[0], n[1], n[2], s, t))
    i.extend([k, k + 1, k + 2, k, k + 2, k + 3])


def box(v, i, x0, x1, y0, y1, z0, z1, side, top, bottom=True):
    face(v, i, [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], side, (1, 0, 0))
    face(v, i, [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], side, (-1, 0, 0))
    face(v, i, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], side, (0, 0, 1))
    face(v, i, [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], side, (0, 0, -1))
    face(v, i, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], top, (0, 1, 0))
    if bottom:
        face(v, i, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], top, (0, -1, 0))


def ring(n, r, rot=0.0):
    return [(r * math.cos(rot + 2 * math.pi * k / n), r * math.sin(rot + 2 * math.pi * k / n)) for k in range(n)]


def prism_y(v, i, cx, cz, y0, y1, r0, r1, n, side, top, rot=None, cap=True):
    """an n-sided upright prism (r0 at y0, r1 at y1: a cone stump when they differ), a cap on top"""
    rot = math.pi / n if rot is None else rot
    a, b = ring(n, r0, rot), ring(n, r1, rot)
    for k in range(n):
        m = (k + 1) % n
        mid = ((a[k][0] + a[m][0]) / 2, (a[k][1] + a[m][1]) / 2)
        face(v, i, [(cx + a[k][0], y0, cz + a[k][1]), (cx + a[m][0], y0, cz + a[m][1]), (cx + b[m][0], y1, cz + b[m][1]), (cx + b[k][0], y1, cz + b[k][1])],
             side, (mid[0], 0.3, mid[1]))
    if cap:  # the top as a fan of quads (each a triangle with one doubled point)
        for k in range(n):
            m = (k + 1) % n
            face(v, i, [(cx, y1, cz), (cx, y1, cz), (cx + b[k][0], y1, cz + b[k][1]), (cx + b[m][0], y1, cz + b[m][1])], top, (0, 1, 0))


def prism_x(v, i, x0, x1, cy, cz, r, n, side, cap_area, rot=0.0):
    """an n-sided prism lying along x (a wheel, an axle), caps on both ends"""
    a = ring(n, r, rot)
    for k in range(n):
        m = (k + 1) % n
        mid = ((a[k][0] + a[m][0]) / 2, (a[k][1] + a[m][1]) / 2)
        face(v, i, [(x0, cy + a[k][0], cz + a[k][1]), (x1, cy + a[k][0], cz + a[k][1]), (x1, cy + a[m][0], cz + a[m][1]), (x0, cy + a[m][0], cz + a[m][1])],
             side, (0, mid[0], mid[1]))
    for x, d in ((x0, -1), (x1, 1)):
        for k in range(n):
            m = (k + 1) % n
            face(v, i, [(x, cy, cz), (x, cy, cz), (x, cy + a[k][0], cz + a[k][1]), (x, cy + a[m][0], cz + a[m][1])], cap_area, (d, 0, 0))


def piece(name, off, v, i, children=()):
    return {'name': name, 'vtype': 0, 'ptype': 0, 'coll': 0, 'off': off, 'verts': v, 'idx': i, 'children': list(children)}

# ---------------------------------------------------------------- the parts


def along(d, r, s):
    """the point r out along the direction d and s to its side (x, z)"""
    return (d[0] * r - d[1] * s, d[1] * r + d[0] * s)


def dbox(v, i, d, r0, r1, s0, s1, y0, y1, side, top, bottom=True):
    """a box from r0 to r1 out along the direction d (one of DIRS) and from s0 to s1 to its side"""
    (ax, az), (bx, bz) = along(d, r0, s0), along(d, r1, s1)
    box(v, i, min(ax, bx), max(ax, bx), y0, y1, min(az, bz), max(az, bz), side, top, bottom)


def base_piece():
    v, i = [], []
    fx, fz = FURNACE
    box(v, i, -HALF, HALF, 0, FLOOR, -HALF, HALF, PLATE, MATTE)  # the platform
    # the furnace: eight sides, copper bands, a band in team color, a cone and a short stack on top
    prism_y(v, i, fx, fz, FLOOR, 24, 11, 11, 8, PLATE, DARK)
    for y in (8.0, 17.0):
        prism_y(v, i, fx, fz, y, y + 1.6, 11.6, 11.6, 8, COPPER, COPPER)
    prism_y(v, i, fx, fz, 24, 26, 12, 12, 8, TEAM, DARK)
    prism_y(v, i, fx, fz, 26, 32, 12, 5, 8, DARK, DARK)
    prism_y(v, i, fx, fz, 32, 35, 3.4, 3.4, 8, COPPER, LAVA)  # (the glow of the lava inside, seen from above)
    # the chimney (corner north-west)
    prism_y(v, i, -18, -18, FLOOR, 48, 3.0, 3.0, 8, COPPER, DARK)
    prism_y(v, i, -18, -18, 45, 46.6, 3.8, 3.8, 8, DARK, DARK)
    # the spout over the pool and the basin of the pool (corner south-east)
    box(v, i, 6, 12, 19, 21.5, 6, 12, COPPER, DARK)
    for x0, x1, z0, z1 in ((12, 27, 12, 13.5), (12, 27, 25.5, 27), (12, 13.5, 12, 27), (25.5, 27, 12, 27)):
        box(v, i, x0, x1, FLOOR, FLOOR + 3, z0, z1, DARK, COPPER, False)
    # the stand and the axle of the wheel (corner south-west)
    box(v, i, -22, -20, FLOOR, 12, 18, 21, DARK, DARK, False)
    box(v, i, -12, -10, FLOOR, 12, 18, 21, DARK, DARK, False)
    prism_x(v, i, -22, -9.5, 12, 19.5, 1.4, 8, DARK, DARK)
    # the cylinders of the pistons (corner north-east)
    for x in (14.0, 22.0):
        prism_y(v, i, x, -19, FLOOR, 11, 2.6, 2.6, 8, DARK, DARK)
    # the conveyor belts: a frame on legs, the belt on top, rails in team color, out to the pads
    for d in DIRS:
        dbox(v, i, d, BELT_IN, BELT_OUT, -4.5, 4.5, BELT_Y - 1.6, BELT_Y, DARK, MATTE)
        for s in (-4.9, 4.5):
            dbox(v, i, d, BELT_IN, BELT_OUT, s, s + 0.4, BELT_Y, BELT_Y + 0.8, TEAM, TEAM)
        r = BELT_IN + 10
        while r < BELT_OUT:
            for s in (-4.2, 3.0):
                dbox(v, i, d, r, r + 1.2, s, s + 1.2, 0, BELT_Y - 1.6, DARK, DARK, False)
            r += 18
    # the storage pads outside the crater: a floor, posts in team color, rails on three sides (open to the outside: the Carriers load there)
    for d in DIRS:
        dbox(v, i, d, PAD_IN, PAD_OUT, -PAD_HALF, PAD_HALF, 0, 0.8, DARK, MATTE)
        for r, s in ((PAD_IN, -PAD_HALF), (PAD_IN, PAD_HALF - 1.6), (PAD_OUT - 1.6, -PAD_HALF), (PAD_OUT - 1.6, PAD_HALF - 1.6)):
            dbox(v, i, d, r, r + 1.6, s, s + 1.6, 0, 9, DARK, TEAM, False)
        for y in (4.5, 7.5):
            dbox(v, i, d, PAD_IN, PAD_OUT, -PAD_HALF, -PAD_HALF + 0.6, y, y + 0.7, TEAM, TEAM)
            dbox(v, i, d, PAD_IN, PAD_OUT, PAD_HALF - 0.6, PAD_HALF, y, y + 0.7, TEAM, TEAM)
            for s0, s1 in ((-PAD_HALF, -5.5), (5.5, PAD_HALF)):  # (the inner side: open where the belt comes in)
                dbox(v, i, d, PAD_IN, PAD_IN + 0.6, s0, s1, y, y + 0.7, TEAM, TEAM)
    return v, i


def streak(v, i, y0, y1, r0, r1, k, s0, s1, out=0.3):
    """a stripe of lava on side k of an eight-sided part of the furnace (r0 at y0, r1 at y1), from s0 to s1 across the side, a little outside it"""
    fx, fz = FURNACE
    rot = math.pi / 8
    a0, a1 = rot + 2 * math.pi * k / 8, rot + 2 * math.pi * (k + 1) / 8
    mid = (a0 + a1) / 2
    ox, oz = out * math.cos(mid), out * math.sin(mid)

    def at(r, y, s):
        x = r * math.cos(a0) * (1 - s) + r * math.cos(a1) * s
        z = r * math.sin(a0) * (1 - s) + r * math.sin(a1) * s
        return (fx + x + ox, y, fz + z + oz)
    face(v, i, [at(r0, y0, s0), at(r0, y0, s1), at(r1, y1, s1), at(r1, y1, s0)], LAVA, (math.cos(mid), 0.3, math.sin(mid)))


def lava_piece():
    """the lava: streams from the crater on top down the cone and the furnace, the fall from the spout into the pool (glows)"""
    v, i = [], []
    for k, s0, s1 in ((0, 0.42, 0.58), (1, 0.5, 0.64), (3, 0.36, 0.5), (5, 0.45, 0.6), (7, 0.3, 0.44)):
        streak(v, i, 26, 32, 12, 5, k, s0, s1)
        streak(v, i, 24, 26, 12, 12, k, s0, s1)
        if k != 0:
            streak(v, i, FLOOR + 0.2, 24, 11, 11, k, s0 + 0.03, s1 - 0.03)
    # the fall: from the spout (south-east) straight down, then the pool
    face(v, i, [(9.5, FLOOR + 3, 13.2), (12.5, FLOOR + 3, 10.2), (12.5, 19, 10.2), (9.5, 19, 13.2)], LAVA, (1, 0, 1))
    face(v, i, [(13.5, FLOOR + 2.6, 13.5), (25.5, FLOOR + 2.6, 13.5), (25.5, FLOOR + 2.6, 25.5), (13.5, FLOOR + 2.6, 25.5)], LAVA, (0, 1, 0))
    return piece(b'lava', (0.0, 0.0, 0.0), v, i)


def drop_piece(n):
    v, i = [], []
    box(v, i, -1.2, 1.2, 0, 2.2, -1.2, 1.2, LAVA, LAVA)
    return piece(b'drop%d' % n, (10.0 + n * 0.7, 18.5, 11.5 - n * 0.7), v, i)


def wheel_piece():
    """the gear wheel (it turns around x): a disc, a hub, spokes and teeth"""
    v, i = [], []
    R = 8.0
    prism_x(v, i, -1.0, 1.0, 0, 0, R, 16, COPPER, COPPER)
    prism_x(v, i, -1.6, 1.6, 0, 0, 2.4, 8, DARK, DARK)
    for k in range(14):
        a = 2 * math.pi * k / 14
        c, s = math.cos(a), math.sin(a)
        pts = []
        for dy, dz in ((-1.0, 0), (1.0, 0), (1.0, 1.8), (-1.0, 1.8)):
            r = R + dz
            pts.append((r * c - dy * s, r * s + dy * c))
        x0, x1 = -1.0, 1.0
        face(v, i, [(x1, p[0], p[1]) for p in pts], DARK, (1, 0, 0))
        face(v, i, [(x0, p[0], p[1]) for p in pts], DARK, (-1, 0, 0))
        for p, q in ((0, 1), (1, 2), (2, 3), (3, 0)):
            mid = ((pts[p][0] + pts[q][0]) / 2, (pts[p][1] + pts[q][1]) / 2)
            face(v, i, [(x0, pts[p][0], pts[p][1]), (x1, pts[p][0], pts[p][1]), (x1, pts[q][0], pts[q][1]), (x0, pts[q][0], pts[q][1])], DARK, (0, mid[0], mid[1]))
    for k in range(4):  # spokes in a dark plate on both sides
        a = math.pi * k / 4
        c, s = math.cos(a), math.sin(a)
        for x in (-1.1, 1.1):
            r = R - 1
            pts = [(-r * c - 0.8 * s, -r * s + 0.8 * c), (r * c - 0.8 * s, r * s + 0.8 * c), (r * c + 0.8 * s, r * s - 0.8 * c), (-r * c + 0.8 * s, -r * s - 0.8 * c)]
            face(v, i, [(x, p[0], p[1]) for p in pts], DARK, (x, 0, 0))
    return piece(b'wheel', (-16.0, 12.0, 19.5), v, i)


def piston_piece(n, x):
    v, i = [], []
    prism_y(v, i, 0, 0, -5, 6, 1.2, 1.2, 8, SILVER, DARK)
    prism_y(v, i, 0, 0, 6, 7.4, 2.2, 2.2, 8, COPPER, COPPER)
    return piece(b'piston%d' % n, (x, 11.0, -19.0), v, i)


def item_piece(n):
    """a crate on a belt: two per belt (belt k has the items 2k-1 and 2k); the unit script moves them outwards from the start of the belt"""
    d = DIRS[(n - 1) // 2]
    x, z = along(d, BELT_IN + 1, 0)
    v, i = [], []
    box(v, i, -2.2, 2.2, 0, 3.0, -2.2, 2.2, SILVER, SILVER, False)
    return piece(b'item%d' % n, (x, BELT_Y, z), v, i)


def block_piece(n):
    """a metal block of a pad: pad k has the blocks 6k-5 .. 6k: two rows out from the middle, three across"""
    k = n - 1
    d = DIRS[k // BLOCKS]
    q = k % BLOCKS
    r = PAD_IN + 8 + (q // 3) * 11
    s = -9 + (q % 3) * 9
    x, z = along(d, r, s)
    v, i = [], []
    box(v, i, -3.2, 3.2, 0, 3.8, -3.2, 3.2, SILVER, SILVER, False)
    return piece(b'block%d' % n, (x, 0.8, z), v, i)


def main():
    v, i = base_piece()
    children = [lava_piece()] + [drop_piece(n) for n in (1, 2, 3)] + [wheel_piece()]
    children += [piston_piece(1, 14.0), piston_piece(2, 22.0)]
    children += [item_piece(n) for n in range(1, 2 * len(DIRS) + 1)]
    children += [block_piece(n) for n in range(1, BLOCKS * len(DIRS) + 1)]
    m = {'radius': 60.0, 'height': 48.0, 'mid': (0.0, 14.0, 0.0), 'tex1': b'Arm_color.dds', 'tex2': b'Arm_other.dds',
         'root': piece(b'base', (0.0, 0.0, 0.0), v, i, children)}
    out = os.path.join(HERE, 'lavagen.s3o')
    with open(out, 'wb') as f:
        f.write(write_s3o(m))
    print('written', out)


if __name__ == '__main__':
    main()
