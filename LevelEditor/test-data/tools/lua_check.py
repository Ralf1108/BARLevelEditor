# Compiles every Lua file of the repository with Lua 5.1 (the Lua of the game engine) and prints the errors: syntax errors and the limits of Lua 5.1
# (at most 200 local variables and 60 upvalues per function) show up here without starting the game. Nothing is run, the files are only compiled.
# Also found (they compile, but fail in the game): a call of a local function above its definition, a top-level local read or written above its
# declaration, a global that is read but set nowhere and not known.
# Needs the Python package lupa (pip install lupa; it brings Lua 5.1 as lupa.lua51). Call: python LevelEditor\test-data\tools\lua_check.py
import os, re, struct, sys
from lupa import lua51


# A call of a function above the line where it is defined as "local function NAME" (top level): there the name is still a global and nil, the call fails in
# the game (it compiles). A name declared as local earlier (local NAME, forward declaration) is fine.
def early_calls(text):
    lines = text.split('\n')
    code = [re.sub(r'--.*$', '', l) for l in lines]   # (strings with "--" are rare enough)
    found = []
    for i, line in enumerate(lines):
        m = re.match(r'local function (\w+)\s*\(', line)
        if not m:
            continue
        name = m.group(1)
        declared = re.compile(r'\blocal\b[^=\n]*\b' + name + r'\b')
        call = re.compile(r'(?<![\w.:])' + name + r'\s*\(')
        for j in range(i):
            if declared.search(code[j]):
                break
            if call.search(code[j]) and not re.search(r'\bfunction\s+' + name + r'\b', code[j]):
                found.append('%d: %s() is called before line %d where it is defined as local function' % (j + 1, name, i + 1))
                break
    return found


# A top-level local (a line "local NAME ..." or "local function NAME" at column 0) that is read or written above that line: there the name is a
# global, a read gives nil and a write never reaches the local (it compiles). Found in the bytecode (string.dump): the instructions GETGLOBAL and
# SETGLOBAL with their lines. A name that is also declared local earlier at the top level is fine.
dump = lua51.LuaRuntime(encoding=None).eval('function(src) local f = loadstring(src) return f and string.dump(f) end')


def global_uses(b):
    pos = [12]
    sz_int, sz_t, sz_num = b[7], b[8], b[10]

    def rd(n):
        v = b[pos[0]:pos[0] + n]
        pos[0] += n
        return v

    def integer():
        return struct.unpack('<i', rd(sz_int))[0]

    def string():
        n = struct.unpack('<Q' if sz_t == 8 else '<I', rd(sz_t))[0]
        s = rd(n)
        return s[:-1].decode('latin1') if n else None

    out = []

    def func():
        string(); integer(); integer(); rd(4)
        code = [struct.unpack('<I', rd(4))[0] for _ in range(integer())]
        ks = []
        for _ in range(integer()):
            t = rd(1)[0]
            ks.append(string() if t == 4 else None)
            if t == 1:
                rd(1)
            elif t == 3:
                rd(sz_num)
        for _ in range(integer()):
            func()
        lines = [integer() for _ in range(integer())]
        for _ in range(integer()):
            string(); integer(); integer()
        for _ in range(integer()):
            string()
        for i, ins in enumerate(code):
            if ins & 0x3F in (5, 7):   # GETGLOBAL, SETGLOBAL
                out.append((ks[ins >> 14], lines[i] if i < len(lines) else 0, ins & 0x3F == 7))
    func()
    return out


def early_locals(text):
    first = {}   # name -> line of its first top-level local declaration
    for i, line in enumerate(text.split('\n')):
        m = re.match(r'local\s+function\s+(\w+)', line) or re.match(r'local\s+([\w\s,]+?)\s*(=|--|$)', line)
        if m:
            for name in re.split(r'[\s,]+', m.group(1).strip()):
                first.setdefault(name, i + 1)
    b = dump(text.encode('utf-8'))
    found = {}
    for name, line, write in (global_uses(bytes(b)) if b else []):
        if name in first and line < first[name] and name not in found:
            found[name] = '%d: %s is %s before line %d where it is declared local' % (line, name, 'written' if write else 'read', first[name])
    return sorted(found.values(), key=lambda s: int(s.split(':')[0]))


# A global that is read but neither known (Lua, the engine, the game: KNOWN) nor set anywhere in the file: a typo or a missing table prefix
# (MAZE_KINDS instead of H.MAZE_KINDS), nil in the game. A new name of the engine or the game is added to KNOWN.
KNOWN = set('''_G _VERSION assert collectgarbage coroutine debug dofile error getfenv getmetatable io ipairs load loadfile loadstring math module next
os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall
Spring gl GL CMD CMDTYPE Game Engine Platform VFS WG GG Script SYNCED UnitDefs UnitDefNames FeatureDefs FeatureDefNames WeaponDefs WeaponDefNames
widget gadget widgetHandler gadgetHandler include SendToUnsynced CallAsTeam LUAUI_DIRNAME LUA_DIRNAME GameCMD BAR Json socket
script piece Turn Move Spin StopSpin Sleep StartThread Signal SetSignalMask WaitForTurn WaitForMove Hide Show Explode EmitSfx SFX
x_axis y_axis z_axis unitID unitDefID COB
Button Control EditBox ScrollPanel TextBox Window screen0
REPO check ok'''.split())   # (last lines: the Lua unit scripts; Chili in lan_lobby.lua; the mock tests, set by mock_test.py)


def unknown_globals(text):
    b = dump(text.encode('utf-8'))
    uses = global_uses(bytes(b)) if b else []
    sets = set(name for name, _, write in uses if write)
    found = {}
    for name, line, write in uses:
        if not write and name not in KNOWN and name not in sets and name not in found:
            found[name] = '%d: the global %s is read but set nowhere in the file and not known (KNOWN of lua_check.py)' % (line, name)
    return sorted(found.values(), key=lambda s: int(s.split(':')[0]))


root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
skip = (os.path.join('LevelEditor', 'scenario', 'scenarios'), os.path.join('LevelEditor', 'levels'))   # built packages (copies) and saved levels (data)
check = lua51.LuaRuntime().eval('function(src, name) local f, err = loadstring(src, name) return err end')
files, bad = 0, 0
for d, _, names in os.walk(root):
    rel = os.path.relpath(d, root)
    if rel.startswith(skip) or rel.startswith('.git'):
        continue
    for n in names:
        if n.endswith('.lua'):
            path = os.path.join(d, n)
            files += 1
            text = open(path, encoding='utf-8').read()
            err = check(text, '@' + os.path.relpath(path, root))
            if err:
                bad += 1
                print('ERROR', err)
            else:
                early = early_calls(text) + early_locals(text) + unknown_globals(text)
                if early:
                    bad += 1
                    for e in early:
                        print('ERROR', os.path.relpath(path, root) + ':' + e)
print(files, 'Lua files compiled with Lua 5.1,', bad, 'with errors')
sys.exit(1 if bad else 0)
