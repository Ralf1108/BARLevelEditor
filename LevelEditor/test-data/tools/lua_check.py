# Compiles every Lua file of the repository with Lua 5.1 (the Lua of the game engine) and prints the errors: syntax errors and the limits of Lua 5.1
# (at most 200 local variables and 60 upvalues per function) show up here without starting the game. Nothing is run, the files are only compiled.
# Needs the Python package lupa (pip install lupa; it brings Lua 5.1 as lupa.lua51). Call: python LevelEditor\test-data\tools\lua_check.py
import os, sys
from lupa import lua51

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
            err = check(open(path, encoding='utf-8').read(), '@' + os.path.relpath(path, root))
            if err:
                bad += 1
                print('ERROR', err)
print(files, 'Lua files compiled with Lua 5.1,', bad, 'with errors')
sys.exit(1 if bad else 0)
