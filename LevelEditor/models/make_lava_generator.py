"""Builds the model of the Lava Generator (lavagen.s3o): a mine in the style of a steam engine on a Volcano, with a storage yard for its metal.

The generator of the Volcano and Lava Generator proof of concept (specs/lava.md), for all three factions (texture of Armada, the team color shows
on a band of the furnace and on the fence). Made from scratch out of boxes and prisms with areas of BAR's texture Arm_color.dds:
  - a furnace (an eight-sided tower with copper bands, a cone on top) in the middle, a copper chimney behind it;
  - lava runs down the front of the furnace from a spout into a glowing pool (the texture area is a glowing one); drops ("drop1".."drop3") fall
    along it while it works;
  - a copper gear wheel ("wheel") on the left side turns, two pistons ("piston1", "piston2") behind the furnace go up and down;
  - a storage yard on the right (a floor, posts and rails) with 15 metal blocks ("block1".."block15"): as many show as its stock holds.
The unit script LevelEditor/scripts/lava_generator_script.lua moves the parts and shows the blocks (the gadget lava_generator.lua calls it).

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

BLOCKS = 15  # metal blocks in the yard (the unit script shows ceil(stock / stock max * 15))
FURNACE = (-12.0, 0.0)  # x, z of the middle of the furnace (the middle of the model stands on the Volcano)
FLOOR = 2.5  # top of the platform


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


def base_piece():
    v, i = [], []
    fx, fz = FURNACE
    box(v, i, -44, 44, 0, FLOOR, -40, 40, PLATE, MATTE)  # the platform
    # the furnace: eight sides, copper bands, a band in team color, a cone and a short stack on top
    prism_y(v, i, fx, fz, FLOOR, 30, 14, 14, 8, PLATE, DARK)
    for y in (9.0, 21.0):
        prism_y(v, i, fx, fz, y, y + 1.8, 14.8, 14.8, 8, COPPER, COPPER)
    prism_y(v, i, fx, fz, 30, 32.5, 15.2, 15.2, 8, TEAM, DARK)
    prism_y(v, i, fx, fz, 32.5, 39, 15.2, 6, 8, DARK, DARK)
    prism_y(v, i, fx, fz, 39, 43, 4, 4, 8, COPPER, LAVA)  # (the glow of the lava inside, seen from above)
    # the chimney behind it
    prism_y(v, i, fx - 7, fz - 13, FLOOR, 60, 3.6, 3.6, 8, COPPER, DARK)
    prism_y(v, i, fx - 7, fz - 13, 56, 58, 4.6, 4.6, 8, DARK, DARK)
    # the spout over the lava and the basin of the pool in front
    box(v, i, fx - 6, fx + 6, 26, 29, fz + 12, fz + 19, COPPER, DARK)
    for x0, x1, z0, z1 in ((fx - 14, fx + 14, fz + 14, fz + 16), (fx - 14, fx + 14, fz + 30, fz + 32), (fx - 14, fx - 12, fz + 14, fz + 32), (fx + 12, fx + 14, fz + 14, fz + 32)):
        box(v, i, x0, x1, FLOOR, FLOOR + 3.5, z0, z1, DARK, COPPER, False)
    # the axle of the wheel
    prism_x(v, i, fx - 27.5, fx - 13, 17, fz, 1.6, 8, DARK, DARK)
    # the cylinders of the pistons
    for x in (fx - 6, fx + 6):
        prism_y(v, i, x, fz - 19, FLOOR, 14, 2.8, 2.8, 8, DARK, DARK)
    # a copper pipe from the furnace to the yard
    prism_x(v, i, fx + 13, 10, 12, fz - 6, 1.5, 8, COPPER, COPPER)
    # the yard: a floor, posts and two rails around it (open towards the front)
    box(v, i, 10, 44, FLOOR, FLOOR + 0.6, -38, 38, DARK, MATTE, False)
    for x in (10, 42):
        for z in (-38, -12.5, 12.5, 36):
            box(v, i, x, x + 2, FLOOR, 12, z, z + 2, DARK, TEAM, False)
    for y in (6.0, 10.0):
        box(v, i, 10, 44, y, y + 0.8, -38, -37, TEAM, TEAM)  # back
        box(v, i, 10, 11, y, y + 0.8, -38, 38, TEAM, TEAM)  # left
        box(v, i, 43, 44, y, y + 0.8, -38, 38, TEAM, TEAM)  # right
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
    """the lava: streams from the crater on top down the cone and the furnace, the fall at the front into the pool (glows)"""
    v, i = [], []
    fx, fz = FURNACE
    # the streams: down the cone (sides 0 to 3: front right, front, front left, left), over the band, down the furnace (not the front: the spout)
    for k, s0, s1 in ((0, 0.55, 0.7), (1, 0.42, 0.58), (2, 0.3, 0.45), (3, 0.5, 0.62), (6, 0.4, 0.52)):
        streak(v, i, 32.5, 39, 15.2, 6, k, s0, s1)
        streak(v, i, 30, 32.5, 15.2, 15.2, k, s0, s1)
        if k != 1:
            streak(v, i, FLOOR + 0.2, 30, 14, 14, k, s0 + 0.03, s1 - 0.03)
    a = 14 * math.cos(math.pi / 8)  # the front face of the furnace (eight sides, one flat to the front)
    face(v, i, [(fx - 4.5, 4.0, fz + a + 0.3), (fx + 4.5, 4.0, fz + a + 0.3), (fx + 4.5, 27, fz + a + 0.3), (fx - 4.5, 27, fz + a + 0.3)], LAVA, (0, 0, 1))
    face(v, i, [(fx - 4.5, FLOOR + 1.5, fz + a + 0.3), (fx + 4.5, FLOOR + 1.5, fz + a + 0.3), (fx + 4.5, 4.0, fz + a + 0.3), (fx - 4.5, 4.0, fz + a + 0.3)], LAVA, (0, 0, 1))
    face(v, i, [(fx - 12, FLOOR + 2.8, fz + 16), (fx + 12, FLOOR + 2.8, fz + 16), (fx + 12, FLOOR + 2.8, fz + 30), (fx - 12, FLOOR + 2.8, fz + 30)], LAVA, (0, 1, 0))
    return piece(b'lava', (0.0, 0.0, 0.0), v, i)


def drop_piece(n):
    v, i = [], []
    box(v, i, -1.6, 1.6, 0, 2.6, 0, 1.4, LAVA, LAVA)
    fx, fz = FURNACE
    a = 14 * math.cos(math.pi / 8)
    return piece(b'drop%d' % n, (fx - 3 + 3 * (n - 1), 26.0, fz + a + 0.4), v, i)


def wheel_piece():
    """the gear wheel (it turns around x): a disc, a hub, spokes and teeth"""
    v, i = [], []
    prism_x(v, i, -1.2, 1.2, 0, 0, 11, 16, COPPER, COPPER)
    prism_x(v, i, -2.0, 2.0, 0, 0, 3, 8, DARK, DARK)
    for k in range(16):
        a = 2 * math.pi * k / 16
        c, s = math.cos(a), math.sin(a)
        # a tooth: a small box on the rim, turned with the angle (made from its 8 corners)
        pts = []
        for dy, dz in ((-1.2, 0), (1.2, 0), (1.2, 2.2), (-1.2, 2.2)):
            r = 11 + dz
            pts.append((r * c - dy * s, r * s + dy * c))
        for x0, x1 in ((-1.2, 1.2),):
            face(v, i, [(x1, pts[0][0], pts[0][1]), (x1, pts[1][0], pts[1][1]), (x1, pts[2][0], pts[2][1]), (x1, pts[3][0], pts[3][1])], DARK, (1, 0, 0))
            face(v, i, [(x0, pts[0][0], pts[0][1]), (x0, pts[1][0], pts[1][1]), (x0, pts[2][0], pts[2][1]), (x0, pts[3][0], pts[3][1])], DARK, (-1, 0, 0))
            for p, q in ((0, 1), (1, 2), (2, 3), (3, 0)):
                mid = ((pts[p][0] + pts[q][0]) / 2, (pts[p][1] + pts[q][1]) / 2)
                face(v, i, [(x0, pts[p][0], pts[p][1]), (x1, pts[p][0], pts[p][1]), (x1, pts[q][0], pts[q][1]), (x0, pts[q][0], pts[q][1])], DARK, (0, mid[0], mid[1]))
    for k in range(4):  # spokes in a dark plate on both sides
        a = math.pi * k / 4
        c, s = math.cos(a), math.sin(a)
        for x in (-1.3, 1.3):
            pts = [(-10 * c - 0.9 * s, -10 * s + 0.9 * c), (10 * c - 0.9 * s, 10 * s + 0.9 * c), (10 * c + 0.9 * s, 10 * s - 0.9 * c), (-10 * c + 0.9 * s, -10 * s - 0.9 * c)]
            face(v, i, [(x, p[0], p[1]) for p in pts], DARK, (x, 0, 0))
    fx, fz = FURNACE
    return piece(b'wheel', (fx - 29.0, 17.0, fz), v, i)


def piston_piece(n, x):
    v, i = [], []
    prism_y(v, i, 0, 0, -6, 7, 1.3, 1.3, 8, SILVER, DARK)
    prism_y(v, i, 0, 0, 7, 8.5, 2.4, 2.4, 8, COPPER, COPPER)
    return piece(b'piston%d' % n, (x, 14.0, FURNACE[1] - 19), v, i)


def block_piece(n):
    """a metal block of the yard: 3 columns from the furnace side to the right, 5 rows from the back to the front"""
    k = n - 1
    col, row = k // 5, k % 5
    x, z = 17 + col * 10.5, -30 + row * 13.5
    v, i = [], []
    box(v, i, -3.4, 3.4, 0, 4.2, -4.4, 4.4, SILVER, SILVER, False)
    return piece(b'block%d' % n, (x, FLOOR + 0.6, z), v, i)


def main():
    v, i = base_piece()
    children = [lava_piece()] + [drop_piece(n) for n in (1, 2, 3)] + [wheel_piece()]
    children += [piston_piece(1, FURNACE[0] - 6), piston_piece(2, FURNACE[0] + 6)]
    children += [block_piece(n) for n in range(1, BLOCKS + 1)]
    m = {'radius': 50.0, 'height': 60.0, 'mid': (0.0, 18.0, 0.0), 'tex1': b'Arm_color.dds', 'tex2': b'Arm_other.dds',
         'root': piece(b'base', (0.0, 0.0, 0.0), v, i, children)}
    out = os.path.join(HERE, 'lavagen.s3o')
    with open(out, 'wb') as f:
        f.write(write_s3o(m))
    print('written', out)


if __name__ == '__main__':
    main()
