# Compiles every Lua file of the repository with Lua 5.1 (the Lua of the game engine) and prints the errors: syntax errors and the limits of Lua 5.1
# (at most 200 local variables and 60 upvalues per function) show up here without starting the game. Nothing is run, the files are only compiled.
# Needs the Python package lupa (pip install lupa; it brings Lua 5.1 as lupa.lua51). Call: python LevelEditor\test-data\tools\lua_check.py
import os, re, sys
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
                early = early_calls(text)
                if early:
                    bad += 1
                    for e in early:
                        print('ERROR', os.path.relpath(path, root) + ':' + e)
print(files, 'Lua files compiled with Lua 5.1,', bad, 'with errors')
sys.exit(1 if bad else 0)
