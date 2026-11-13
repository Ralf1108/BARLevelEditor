# Checks the documents without the game: every relative link and picture of a tracked .md file points to a tracked file or a folder, and every #anchor to a heading of the
# file it names (the way GitHub writes it: lower case, no punctuation, spaces as hyphens). Links to other sites are not followed.
# Call: python LevelEditor\test-data\tools\doc_check.py      (exit code 1 when a link is broken)
import os, re, subprocess, sys, urllib.parse

repo = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
files = [f for f in subprocess.check_output(['git', 'ls-files'], cwd=repo, text=True).split('\n') if f]
tracked = set(files)
_heads = {}


def slug(h):
    h = re.sub(r'[`*_]', '', h.strip().lower())
    h = re.sub(r'<[^>]+>', '', h)
    return re.sub(r'[^\w\- ]', '', h).replace(' ', '-')


def headings(rel):
    if rel not in _heads:
        text = open(os.path.join(repo, rel), encoding='utf-8').read()
        text = re.sub(r'^```.*?^```', '', text, flags=re.M | re.S)
        _heads[rel] = {slug(h) for h in re.findall(r'^#{1,6}\s+(.*?)\s*#*\s*$', text, re.M)}
    return _heads[rel]


broken = 0
checked = 0
for f in files:
    if not f.endswith('.md'):
        continue
    text = open(os.path.join(repo, f), encoding='utf-8').read()
    text = re.sub(r'^```.*?^```', '', text, flags=re.M | re.S)   # (no links inside code blocks)
    text = re.sub(r'`[^`\n]*`', '', text)                         # (nor inside inline code)
    for m in re.finditer(r'\]\(([^)\s]+)\)|src="([^"]+)"|href="([^"]+)"', text):
        target = m.group(1) or m.group(2) or m.group(3)
        if target.startswith(('http://', 'https://', 'mailto:')):
            continue
        checked += 1
        path, _, anchor = target.partition('#')
        path = urllib.parse.unquote(path)
        if path:
            full = os.path.normpath(os.path.join(os.path.dirname(f), path)).replace(os.sep, '/')
            if full not in tracked and not os.path.isdir(os.path.join(repo, full)):
                broken += 1
                print('BROKEN %s -> %s' % (f, target))
                continue
        else:
            full = f
        if anchor and full.endswith('.md') and full in tracked and anchor not in headings(full):
            broken += 1
            print('BROKEN %s -> %s (no such heading in %s)' % (f, target, full))
print('%d links checked, %d broken' % (checked, broken))
sys.exit(1 if broken else 0)
