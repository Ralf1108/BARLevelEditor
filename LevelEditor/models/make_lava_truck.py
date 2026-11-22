"""Builds the model of the Cargo Truck (armlavatruck.s3o) from the model of BAR's missile truck armsam (Samson).

The truck of the Volcano and Lava Extractor proof of concept (specs/lava.md): the rocket launcher of armsam is emptied (its pieces stay, the
animation script of armsam names them) and a new piece "cargo" carries a container on the bed (plates of the texture Arm_color.dds of Armada, a
stripe in team color on both sides). Everything else (body, cab, wheels, tracks) is armsam as it is. The model of armsam is a work of the BAR
team (its licence applies to this copy too).

Usage: python make_lava_truck.py [BAR data folder]   (default C:\\Games\\Beyond-All-Reason\\data)
Writes armlavatruck.s3o next to this script; the setup packs it into the extra games as objects3d/Units/armlavatruck.s3o.
"""
import gzip
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = 'objects3d/units/armsam.s3o'

# ---------------------------------------------------------------- the model in BAR's packages (rapid: packages\*.sdp list, pool\xx\yyy.gz files)


def game_file(data, path):
    best = None
    for f in os.listdir(os.path.join(data, 'packages')):
        if f.endswith('.sdp'):
            p = os.path.join(data, 'packages', f)
            if best is None or os.path.getmtime(p) > os.path.getmtime(best[0]):
                d = gzip.open(p).read()
                i = 0
                while i < len(d):
                    n = d[i]
                    if d[i + 1:i + 1 + n].decode('latin1').lower() == path:
                        best = (p, d[i + 1 + n:i + 17 + n].hex())
                        break
                    i += 1 + n + 24
    if not best:
        sys.exit('not found in the packages of ' + data + ': ' + path)
    md5 = best[1]
    return gzip.open(os.path.join(data, 'pool', md5[:2], md5[2:] + '.gz')).read()

# ---------------------------------------------------------------- S3O: read into pieces, write back


def cstr(b, o):
    return b[o:b.index(b'\0', o)]


def read_piece(b, o):
    (nameo, nch, cho, nv, vo, vtype, ptype, vts, vto, coll, x, y, z) = struct.unpack_from('<9i i3f', b, o)
    return {
        'name': cstr(b, nameo), 'vtype': vtype, 'ptype': ptype, 'coll': coll, 'off': (x, y, z),
        'verts': [struct.unpack_from('<8f', b, vo + 32 * i) for i in range(nv)],
        'idx': [struct.unpack_from('<i', b, vto + 4 * i)[0] for i in range(vts)],
        'children': [read_piece(b, struct.unpack_from('<i', b, cho + 4 * i)[0]) for i in range(nch)],
    }


def read_s3o(b):
    magic, ver, rad, h, mx, my, mz, root, coll, t1, t2 = struct.unpack_from('<12s i 5f 4i', b, 0)
    return {'radius': rad, 'height': h, 'mid': (mx, my, mz), 'tex1': cstr(b, t1), 'tex2': cstr(b, t2), 'root': read_piece(b, root)}


def write_s3o(m):
    out = bytearray(b'\0' * 60)

    def put(data):
        o = len(out)
        out.extend(data)
        return o

    def piece(p):
        o = put(b'\0' * 52)
        name = put(p['name'] + b'\0')
        verts = put(b''.join(struct.pack('<8f', *v) for v in p['verts']))
        idx = put(b''.join(struct.pack('<i', i) for i in p['idx']))
        kids = [piece(c) for c in p['children']]
        cho = put(b''.join(struct.pack('<i', k) for k in kids))
        struct.pack_into('<9i i3f', out, o, name, len(kids), cho, len(p['verts']), verts, p['vtype'], p['ptype'], len(p['idx']), idx, p['coll'], *p['off'])
        return o

    root = piece(m['root'])
    t1 = put(m['tex1'] + b'\0')
    t2 = put(m['tex2'] + b'\0')
    struct.pack_into('<12s i 5f 4i', out, 0, b'Spring unit\0', 0, m['radius'], m['height'], *m['mid'], root, 0, t1, t2)
    return bytes(out)


def find(p, name):
    if p['name'] == name:
        return p
    for c in p['children']:
        r = find(c, name)
        if r:
            return r

# ---------------------------------------------------------------- the container


# areas of Arm_color.dds (u from the left, v from the top: the s3o texture coordinate t is 1 - v): (u0, v0, u1, v1)
PLATE = (0.752, 0.255, 0.935, 0.43)  # the large grey plate with panels
GRATE = (0.285, 0.700, 0.370, 0.735)  # the grate with the yellow frame (roof)
TEAM = (0.627, 0.316, 0.670, 0.322)  # a solid bar of the team color mask (alpha)


def quad(verts, idx, corners, normal, area):
    """corners: 4 points counter-clockwise seen from outside; area: the texture rectangle stretched over it"""
    u0, v0, u1, v1 = area
    uvs = [(u0, 1 - v1), (u1, 1 - v1), (u1, 1 - v0), (u0, 1 - v0)]
    n = len(verts)
    for (x, y, z), (s, t) in zip(corners, uvs):
        verts.append((x, y, z, normal[0], normal[1], normal[2], s, t))
    idx.extend([n, n + 1, n + 2, n, n + 2, n + 3])


def box(verts, idx, x0, x1, y0, y1, z0, z1, side, top, end):
    quad(verts, idx, [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], (1, 0, 0), side)    # right (+x)
    quad(verts, idx, [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (-1, 0, 0), side)   # left (-x)
    quad(verts, idx, [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], (0, 1, 0), top)     # top
    quad(verts, idx, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1), end)     # front (+z, to the cab)
    quad(verts, idx, [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], (0, 0, -1), end)    # back (-z)


def cargo_piece():
    verts, idx = [], []
    # the container on the bed (behind the cab: the cab ends at z 8, the bed is at y 12)
    box(verts, idx, -10.5, 10.5, 12.0, 22.0, -21.0, 6.5, PLATE, GRATE, PLATE)
    # a stripe in team color along both sides, a little outside the walls
    box(verts, idx, -10.8, 10.8, 18.0, 19.6, -20.0, 5.5, TEAM, TEAM, TEAM)
    return {'name': b'cargo', 'vtype': 0, 'ptype': 0, 'coll': 0, 'off': (0.0, 0.0, 0.0), 'verts': verts, 'idx': idx, 'children': []}


def main():
    data = sys.argv[1] if len(sys.argv) > 1 else r'C:\Games\Beyond-All-Reason\data'
    m = read_s3o(game_file(data, BASE))
    for name in (b'turret', b'mlauncher'):  # the rocket launcher: empty, the pieces stay for the script
        p = find(m['root'], name)
        p['verts'], p['idx'] = [], []
    m['root']['children'].append(cargo_piece())
    m['height'] = 22.0
    m['mid'] = (0.0, 9.0, -2.0)
    m['radius'] = 25.0
    out = os.path.join(HERE, 'armlavatruck.s3o')
    with open(out, 'wb') as f:
        f.write(write_s3o(m))
    print('written', out)


if __name__ == '__main__':
    main()
