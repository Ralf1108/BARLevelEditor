"""Writes LevelEditor/test-data/tests-index.md: one table of every test widget (tools/zz_*.lua) with what it checks and the command that starts it.

  python make_test_index.py          writes the index
  python make_test_index.py --check  exits with 1 when the index is not up to date (or a widget has no description)

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
    return desc, command, what


def cell(s):
    return s.replace("|", "\\|").replace("\n", " ")


def build():
    names = sorted((f for f in os.listdir(tools) if f.startswith("zz_") and f.endswith(".lua")), key=natural)
    rows, missing = [], []
    for f in names:
        desc, command, what = describe(os.path.join(tools, f))
        if not desc and not what:
            missing.append(f)
        short = what if len(what) <= 260 else what[:257].rsplit(" ", 1)[0] + " ..."
        rows.append("| `%s` | %s | %s |" % (f, cell(desc or short), ("`%s`" % cell(command)) if command else ""))
    out = ["# Test widgets (`tools/zz_*.lua`)", "",
           "Made by `generators/make_test_index.py` from the first lines of every widget: change the widget, not this file. How to run them: [README](README.md), pitfalls: [TESTING](TESTING.md).", "",
           "%d widgets. The name of the log lines is in the widget (`[zz...]`); the game starts with the command in the last column." % len(names), "",
           "| Widget | What it checks | Started with |", "|---|---|---|"] + rows
    return "\n".join(out) + "\n", missing


if __name__ == "__main__":
    text, missing = build()
    if "--check" in sys.argv:
        old = open(OUT, encoding="utf-8", newline="").read().replace("\r\n", "\n") if os.path.exists(OUT) else ""
        bad = old != text or missing
        if old != text:
            print("tests-index.md is not up to date: python LevelEditor/test-data/generators/make_test_index.py")
        for f in missing:
            print("no description:", f)
        sys.exit(1 if bad else 0)
    open(OUT, "w", encoding="utf-8", newline="").write(text)
    print("%d widgets written to %s" % (text.count("\n| `zz_"), OUT))
    for f in missing:
        print("no description:", f)
