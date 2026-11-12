#!/usr/bin/env python
"""Regenerate the systems reference to a temporary file and list which sections changed against the committed one.

    python tools/check_systems_reference.py            # report only (exit 0 when equal, 1 when different)
    python tools/check_systems_reference.py --update   # also overwrite docs/design/systems-reference.md with the fresh text
    python tools/check_systems_reference.py --godot PATH

The generator is godot/tests/make_systems_reference.gd (reads the game's data tables). Sections are the "## " and "### " headings;
for each changed section the number of table rows and the first differing line are printed.
"""
import argparse
import difflib
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(REPO, "docs", "design", "systems-reference.md")
DEFAULT_GODOT = r"C:\Program Files\Godot\Godot.exe"


def sections(text):
    """heading -> list of lines under it"""
    out, cur = {}, "(top)"
    out[cur] = []
    for line in text.splitlines():
        if line.startswith("## ") or line.startswith("### "):
            cur = line.strip()
            out[cur] = []
        else:
            out[cur].append(line)
    return out


def rows(lines):
    n = sum(1 for ln in lines if ln.startswith("| ") and not ln.startswith("| ---"))
    return max(0, n - 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    ap.add_argument("--update", action="store_true")
    args = ap.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "systems-reference.md")
        cmd = [args.godot, "--headless", "--path", os.path.join(REPO, "godot"), "-s", "res://tests/make_systems_reference.gd", "--", "--out", out]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0 or not os.path.exists(out):
            print("generator failed (exit %d)" % res.returncode)
            print((res.stdout + res.stderr)[-2000:])
            return 2
        with open(out, encoding="utf-8") as f:
            fresh = f.read()
    old = ""
    if os.path.exists(DOC):
        with open(DOC, encoding="utf-8") as f:
            old = f.read()
    if fresh == old:
        print("systems-reference.md is up to date")
        return 0
    a, b = sections(old), sections(fresh)
    changed = 0
    for k in list(a.keys()) + [k for k in b.keys() if k not in a]:
        if k not in b:
            print("REMOVED  %s" % k)
            changed += 1
        elif k not in a:
            print("ADDED    %s (%d rows)" % (k, rows(b[k])))
            changed += 1
        elif a[k] != b[k]:
            first = next((x for x in difflib.unified_diff(a[k], b[k], lineterm="", n=0) if x[0] in "+-" and x[:3] not in ("+++", "---")), "")
            print("CHANGED  %s (rows %d -> %d)  %s" % (k, rows(a[k]), rows(b[k]), first[:100]))
            changed += 1
    print("%d section(s) differ" % changed)
    if args.update:
        with open(DOC, "w", encoding="utf-8", newline="\n") as f:
            f.write(fresh)
        print("updated", DOC)
    return 1


if __name__ == "__main__":
    sys.exit(main())
