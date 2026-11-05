"""Reads which unit is in which category on the website (https://www.beyondallreason.info/units/<faction>-<category>) and writes unit_categories.json next to this script:
[ { "code": "corak", "description": "Fast Infantry Bot", "faction": "cortex", "category": "bots", "tech_level": 1,
    "image": "https://cdn.prod.website-files.com/.../corak.webp", "icon": "https://cdn.prod.website-files.com/.../armpw.webp" }, ... ]
  code         the unit code (name in the game), taken from the link /unit/<code>
  description  the short description under the unit name on the page (the tooltip of the unit in the game)
  faction      armada, cortex or legion
  category     bots, vehicles, air, sea, hover, factories, defense, buildings (the buttons of the website; the page address ends in -bots, -vehicles, -aircraft, -ships,
               -hovercraft, -factories, -defense-buildings, -buildings)
  tech_level   the tech level of the unit as the page shows it ("T1" is 1, "T2" is 2, "T3" is 3; 0 if the page shows none)
  image        the address of the picture of the unit (a .webp file on the website's CDN; "" if the page has none)
  icon         the address of the strategic icon of the unit (the small symbol the game shows when zoomed out, labelled "Strategic Icon" on the page; "" if none).
               Several units share one icon file: its file name is not always the name of the unit.
Run:  python scrape_unit_categories.py [output file]
Notes: the pages are built differently per faction (a list of cards or a grid, some pages have both), and some are split into pages ("?<hash>_page=2", e.g. Legion):
the script collects, per unit code, everything that follows the links /unit/<code> up to the link of the next unit, and follows the pages until one brings no new unit.
Legion has no hover page on the website (HTTP 404), so it has no hover units here. The lists are what the website shows: units it does not list (e.g. some T3 and
special units) are not in the file. Needs only the Python standard library and an internet connection.
"""
import html, json, os, re, sys, urllib.request, urllib.error

FACTIONS = ['armada', 'cortex', 'legion']
# the categories of the website (the buttons Bots, Vehicles, Air, Sea, Hover, Factories, Defense, Buildings) and the last part of the page address
CATEGORIES = [('bots', 'bots'), ('vehicles', 'vehicles'), ('air', 'aircraft'), ('sea', 'ships'), ('hover', 'hovercraft'),
              ('factories', 'factories'), ('defense', 'defense-buildings'), ('buildings', 'buildings')]
out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'unit_categories.json')


def get(address):
    req = urllib.request.Request(address, headers={'User-Agent': 'Mozilla/5.0 (unit category list for a hobby project)'})
    return urllib.request.urlopen(req, timeout=60).read().decode('utf8', 'replace')


def first_image(text, classes):
    """The address of the first <img> whose first class is one of `classes`."""
    for tag in re.finditer(r'<img\b[^>]*>', text):
        src = re.search(r'\bsrc="([^"]+)"', tag.group(0))
        cls = re.search(r'\bclass="([^"]*)"', tag.group(0))
        if src and cls and cls.group(1).split(' ')[0] in classes:
            return src.group(1)
    return ''


def tech_level(text):
    """1 to 3: the card shows it as <div class="unit-special-text">T1</div>; the grid has the three levels as <div title="Tech Level N" class="flex-unit-grid-tech ...">
    and hides the wrong ones with the class w-condition-invisible. 0 if neither is there."""
    for tag in re.finditer(r'<div title="Tech Level (\d)" class="([^"]*)"', text):
        if 'w-condition-invisible' not in tag.group(2):
            return int(tag.group(1))
    m = re.search(r'class="unit-special-text[^"]*">\s*T(\d)\s*<', text)
    return int(m.group(1)) if m else 0


def description(text):
    m = re.search(r'class="(?:us-text|[^"]*unit-grid-text sub)[^"]*">([^<]*)<', text)
    return html.unescape(m.group(1)).strip() if m else ''


rows, log = [], []
for faction in FACTIONS:
    for cat, slug in CATEGORIES:
        url = 'https://www.beyondallreason.info/units/%s-%s' % (faction, slug)
        try:
            first = get(url)
        except urllib.error.HTTPError as e:
            log.append('%s-%s: HTTP %d (no page)' % (faction, cat, e.code))
            continue
        # a page may be split ("?<hash>_page=2", the Legion pages show 10 units each): the pages are followed until one brings no new unit
        pages = [first]
        for param in sorted(set(re.findall(r'\?([0-9a-f]+_page)=\d+', first))):
            for number in range(2, 30):
                try:
                    more = get('%s?%s=%d' % (url, param, number))
                except urllib.error.HTTPError:
                    break
                pages.append(more)
                if 'w-pagination-next' not in more or ('?%s=%d' % (param, number + 1)) not in more:
                    break
        order, parts = [], {}   # the unit codes in the order of the page; per code the text that follows its links
        for page in pages:
            hits = [(m.start(), m.group(1)) for m in re.finditer(r'href="/unit/([^"]+)"', page)]
            for k, (pos, code) in enumerate(hits):
                end = next((p for p, c in hits[k + 1:] if c != code), len(page))
                if code not in parts:
                    order.append(code)
                    parts[code] = ''
                parts[code] += page[pos:end]
        missing = {'image': 0, 'icon': 0, 'tech': 0}
        for code in order:
            text = parts[code]
            row = {'code': code, 'description': description(text), 'faction': faction, 'category': cat, 'tech_level': tech_level(text),
                   'image': first_image(text, ('unit-img', 'flex-unit-grid-img')), 'icon': first_image(text, ('us-straticon-img', 'flex-unit-grid-icon'))}
            missing['image'] += 0 if row['image'] else 1
            missing['icon'] += 0 if row['icon'] else 1
            missing['tech'] += 0 if row['tech_level'] else 1
            rows.append(row)
        log.append('%s-%s: %d units%s' % (faction, cat, len(order), ''.join(', %d without %s' % (n, k) for k, n in missing.items() if n)))
json_text = '[\n' + ',\n'.join('\t' + json.dumps(r, ensure_ascii=False) for r in rows) + '\n]\n'
open(out_path, 'w', encoding='utf8', newline='\n').write(json_text)
sys.stdout.buffer.write(('\n'.join(log) + '\ntotal %d\n' % len(rows)).encode('utf8', 'replace'))
