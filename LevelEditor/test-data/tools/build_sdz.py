"""Builds LevelEditorScenarios.sdz from the repository files (like install_editor.ps1) into the folder given as argument."""
import re, sys, zipfile
import os
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')) + '/'
DATA = sys.argv[2] if len(sys.argv) > 2 else 'C:/Games/Beyond-All-Reason/data'
out = sys.argv[1]
with zipfile.ZipFile(DATA + '/games/LevelEditorMod.sdz') as z:
    depend = re.search(r'depend\s*=\s*\{\s*"([^"]+)"', z.read('modinfo.lua').decode('utf-8')).group(1)
modinfo = 'return {\n\tname = "Level Editor Scenarios",\n\tshortName = "LEScn",\n\tversion = "1",\n\tgame = "LevelEditorScenarios",\n\tshortGame = "LEScn",\n\tdescription = "test build",\n\tmutator = "Official",\n\tmodtype = 1,\n\tdepend = { "%s" },\n}\n' % depend
S = REPO + 'LevelEditor/scripts/'
rd = lambda p: open(p, encoding='utf-8', newline='').read()
entries = [('luarules/gadgets/td_waves.lua', rd(S + 'td_waves.lua')), ('luarules/gadgets/ctf_game.lua', rd(S + 'ctf_game.lua')),
           ('luarules/gadgets/rtf_game.lua', rd(S + 'rtf_game.lua')), ('luarules/gadgets/pve_supply_drops.lua', rd(S + 'pve_supply_drops_stub.lua')),
           ('luarules/gadgets/unit_restrictions.lua', rd(S + 'unit_restrictions.lua')), ('luaui/Include/bar_rules.lua', rd(REPO + 'shared/bar_rules.lua')), ('modinfo.lua', modinfo)]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for n, t in entries:
        zi = zipfile.ZipInfo(n, (2000, 1, 1, 0, 0, 0)); zi.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(zi, t)
print('built', out, depend)
