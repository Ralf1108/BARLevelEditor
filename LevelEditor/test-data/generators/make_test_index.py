"""Writes LevelEditor/test-data/tests-index.md: one table of every test widget (tools/zz_*.lua, tools/probes/zz_*.lua) with its kind, what it
checks and the command that starts it.

Kinds: test = it logs OK / WRONG (or PASS / FAIL) lines, the tools give a verdict; set = a test of the regression set (tools/run_game_tests.ps1);
check = it logs values, the log is read; pictures = it takes the pictures of a manual; probe = it measured or dumped something once (tools/probes).

  python make_test_index.py          writes the index
  python make_test_index.py --check  exits with 1 when the index is not up to date, a widget has no description or no start command, or its
                                     start command names another widget

The text comes from the widget itself: `desc` of its GetInfo and the first comment lines (the line "Test widget of <command>: <what it does>").
"""
import os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(os.path.dirname(os.path.dirname(here)))
tools = os.path.join(repo, "LevelEditor", "test-data", "tools")
OUT = os.path.join(repo, "LevelEditor", "test-data", "tests-index.md")


def natural(name):
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", name)]


def describe(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    lines = text.split("\n")
    desc = ""
    m = re.search(r'desc\s*=\s*"([^"]*)"', lines[0]) if lines else None
    if m:
        desc = re.sub(r"^test only:\s*", "", m.group(1)).strip()
    command, what = "", ""
    comment = []
    for l in lines[1:8]:
        if l.startswith("--"):
            comment.append(l[2:].strip())
        elif comment:
            break
    joined = " ".join(comment)
    m = re.match(r"Test widget of ([^:]+?):\s*(.*)", joined)
    if m:
        command, what = m.group(1).strip(), m.group(2).strip()
    elif joined:
        what = joined
    return desc, command, what, text


def kind(name, desc, text, probe, in_set):
    if probe:
        return "probe"
    if name in in_set:
        return "set"
    if re.search(r'"(OK|WRONG|FAIL|PASS) ?"', text):
        return "test"
    if re.search(r"\bpictures?\b", desc):
        return "pictures"
    return "check"


def cell(s):
    return s.replace("|", "\\|").replace("\n", " ")


def build():
    probes = os.path.join(tools, "probes")
    found = [(f, tools) for f in os.listdir(tools)] + [(f, probes) for f in os.listdir(probes)]
    names = sorted(((f, d) for f, d in found if f.startswith("zz_") and f.endswith(".lua")), key=lambda p: natural(p[0]))
    in_set = set(n + ".lua" for n in re.findall(r"Name = '(zz_\w+)'", open(os.path.join(tools, "run_game_tests.ps1"), encoding="utf-8").read()))
    rows, missing, count = [], [], {}
    for f, d in names:
        desc, command, what, text = describe(os.path.join(d, f))
        if not desc and not what:
            missing.append(f + " (no description)")
        if not command:
            missing.append(f + ' (no start command: second line "-- Test widget of <command>: ...")')
        other = [w for w in re.findall(r"-Widget (zz_\w+\.lua)", command) if w != f]
        if other:
            missing.append(f + " (its start command names " + other[0] + ")")
        k = kind(f, desc, text, d == probes, in_set)
        count[k] = count.get(k, 0) + 1
        short = what if len(what) <= 260 else what[:257].rsplit(" ", 1)[0] + " ..."
        rows.append("| `%s` | %s | %s | %s |" % (f, k, cell(desc or short), ("`%s`" % cell(command)) if command else ""))
    kinds = ", ".join("%d %s" % (count[k], k) for k in ("set", "test", "check", "pictures", "probe") if k in count)
    out = ["# Test widgets (`tools/zz_*.lua`, `tools/probes/zz_*.lua`)", "",
           "Made by `generators/make_test_index.py` from the first lines of every widget: change the widget, not this file. How to run them: [README](README.md), pitfalls: [TESTING](TESTING.md).", "",
           "%d widgets (%s). The name of the log lines is in the widget (`[zz...]`); the game starts with the command in the last column." % (len(names), kinds), "",
           "| Kind | Meaning |", "|---|---|",
           "| set | a test of the regression set: `tools\\run_game_tests.ps1` runs it and gives a verdict |",
           "| test | logs OK / WRONG (or PASS / FAIL) lines: the tool that starts it ends with a verdict and an exit code |",
           "| check | logs values of a behaviour: the log is read (no verdict) |",
           "| pictures | takes the pictures of a manual |",
           "| probe | measured or dumped something once (`tools\\probes`): not a test |", "",
           "| Widget | Kind | What it checks | Started with |", "|---|---|---|---|"] + rows
    return "\n".join(out) + "\n", missing


if __name__ == "__main__":
    text, missing = build()
    if "--check" in sys.argv:
        old = open(OUT, encoding="utf-8", newline="").read().replace("\r\n", "\n") if os.path.exists(OUT) else ""
        bad = old != text or missing
        if old != text:
            print("tests-index.md is not up to date: python LevelEditor/test-data/generators/make_test_index.py")
        for f in missing:
            print("widget header:", f)
        sys.exit(1 if bad else 0)
    open(OUT, "w", encoding="utf-8", newline="").write(text)
    print("%d widgets written to %s" % (text.count("\n| `zz_"), OUT))
    for f in missing:
        print("widget header:", f)
