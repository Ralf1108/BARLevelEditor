# Runs the mock tests (tools\mock_*.lua) with Lua 5.1 outside the game: each one fakes the part of the Spring API it needs, runs a shared Lua module and checks
# what it does. A mock calls check(cond, text) for every check (a failure is printed and counted) and ok(text) for a passed group.
# Needs the Python package lupa (like lua_check.py). Call: python LevelEditor\test-data\tools\mock_test.py [name ...]   (e.g. mock_area_attack)
import glob, os, sys
from lupa import lua51

tools = os.path.dirname(os.path.abspath(__file__))
repo = os.path.abspath(os.path.join(tools, '..', '..', '..')).replace('\\', '/')
names = sys.argv[1:] or sorted(os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(tools, 'mock_*.lua')))
failed = 0
for name in names:
    lua = lua51.LuaRuntime()
    state = {'fail': 0, 'checks': 0}

    def check(cond, text, state=state):
        state['checks'] += 1
        if not cond:
            state['fail'] += 1
            print('  FAIL', text)

    def ok(text, state=state):
        print('  ok  ', text)

    g = lua.globals()
    g.REPO, g.check, g.ok = repo, check, ok
    print('==', name)
    try:
        lua.execute(open(os.path.join(tools, name + '.lua'), encoding='utf-8').read())
    except Exception as e:
        state['fail'] += 1
        print('  ERROR', e)
    print('  %d checks, %d failed' % (state['checks'], state['fail']))
    failed += state['fail']
print('mock tests:', 'all passed' if failed == 0 else '%d failed' % failed)
sys.exit(1 if failed else 0)
