"""Builds the model of the Forklift (armlavafork.s3o) from the model of BAR's scout car armfav (Rover).

The forklift of the Volcano and Lava Extractor proof of concept (specs/lava.md): the gun of armfav is removed; new pieces: a roof on four posts
over the seat ("guard"), a counterweight at the back ("weight"), a mast at the front ("mast") with the fork ("fork", it moves up and down) and
three boxes on the fork ("box1", "box2", "box3", one above the other). The unit script LevelEditor/scripts/lava_forklift_script.lua hides the boxes and shows as many as the
forklift carries. Body and wheels are armfav as it is. The model of armfav is a work of the BAR team (its licence applies to this copy too).

Usage: python make_lava_forklift.py [BAR data folder]   (default C:\\Games\\Beyond-All-Reason\\data)
Writes armlavafork.s3o next to this script; the setup packs it into the extra games as objects3d/Units/armlavafork.s3o.
"""
import os
import sys

from make_lava_truck import GRATE, PLATE, TEAM, box, game_file, read_s3o, write_s3o

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = 'objects3d/units/armfav.s3o'

# areas of Arm_color.dds (u0, v0, u1, v1; v from the top)
CRATE = (0.7552, 0.6671, 0.8016, 0.6960)  # a yellow panel with a dark frame (the sides of a box)
DARK = (0.255, 0.695, 0.278, 0.745)  # a dark grey plate (mast, fork, posts, counterweight)

BOX_H = 4.8  # height of one box; the boxes stand on the tines one above the other


def piece(name, off, verts, idx, children=()):
    return {'name': name, 'vtype': 0, 'ptype': 0, 'coll': 0, 'off': off, 'verts': verts, 'idx': idx, 'children': list(children)}


def guard_piece():
    v, i = [], []
    for x in (-5.6, 4.8):
        for z in (-6.5, 3.6):
            box(v, i, x, x + 0.8, 10.0, 19.0, z, z + 0.8, DARK, DARK, DARK)  # the posts
    box(v, i, -6.2, 6.2, 19.0, 19.8, -7.0, 5.0, DARK, GRATE, DARK)  # the roof
    return piece(b'guard', (0.0, 0.0, 0.0), v, i)


def weight_piece():
    v, i = [], []
    box(v, i, -6.0, 6.0, 7.0, 12.5, -12.5, -8.5, PLATE, PLATE, PLATE)
    box(v, i, -6.2, 6.2, 10.4, 11.4, -12.7, -8.3, TEAM, TEAM, TEAM)  # a stripe in team color around it
    return piece(b'weight', (0.0, 0.0, 0.0), v, i)


def box_piece(n):
    v, i = [], []
    box(v, i, -4.0, 4.0, 0.0, BOX_H - 0.2, 1.4, 10.8, CRATE, GRATE, CRATE)
    return piece(b'box%d' % n, (0.0, 0.8 + (n - 1) * BOX_H, 0.0), v, i)


def fork_piece():
    v, i = [], []
    box(v, i, -4.6, 4.6, 0.0, 7.0, 0.0, 0.8, DARK, DARK, DARK)  # the carriage
    for x in (-3.6, 2.2):
        box(v, i, x, x + 1.4, 0.0, 0.8, 0.8, 12.0, DARK, DARK, DARK)  # the two tines
    return piece(b'fork', (0.0, 2.6, 1.3), v, i, [box_piece(n) for n in (1, 2, 3)])


def mast_piece():
    v, i = [], []
    for x in (-5.0, 3.8):
        box(v, i, x, x + 1.2, 2.0, 25.0, 0.0, 1.2, DARK, DARK, DARK)  # the two rails
    box(v, i, -5.0, 5.0, 24.0, 25.4, 0.0, 1.2, TEAM, TEAM, TEAM)  # the bar on top, in team color
    return piece(b'mast', (0.0, 0.0, 12.6), v, i, [fork_piece()])


def main():
    data = sys.argv[1] if len(sys.argv) > 1 else r'C:\Games\Beyond-All-Reason\data'
    m = read_s3o(game_file(data, BASE))
    root = m['root']
    root['children'] = [c for c in root['children'] if c['name'] != b'gun']  # (the gun and its flare)
    root['children'] += [guard_piece(), weight_piece(), mast_piece()]
    m['height'] = 25.0
    m['mid'] = (0.0, 10.0, 1.0)
    m['radius'] = 22.0
    out = os.path.join(HERE, 'armlavafork.s3o')
    with open(out, 'wb') as f:
        f.write(write_s3o(m))
    print('written', out)


if __name__ == '__main__':
    main()
