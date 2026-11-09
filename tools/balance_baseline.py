#!/usr/bin/env python
"""Balance drift check: run the bot smoke test and compare its numbers with a stored baseline.

    python tools/balance_baseline.py [--update] [--log FILE] [--godot PATH]

Runs godot/tests/tiers_balance.gd (about 3 minutes: sales, tech and service campaigns with a careful and a lazy bot at easy /
normal / hard) and parses its `BOT <mode> <tier> <strategy> seed N: rep R score S ending E cls C ...` lines. Each cell
is compared with docs/dev/balance_baseline.json:
  * rep (reputation) may move by REP_TOL points, score by SCORE_TOL (a share of the baseline, with a small floor);
  * a different good / mid / bad class is reported as a warning (the bots are not fully deterministic: the same seed moves a few
    points between runs, so only a drift larger than the tolerance fails).
Exits 1 on drift. `--update` rewrites the baseline from this run (do it on purpose, after a balance change you meant to make).
`--log FILE` parses an existing output instead of running Godot.

The test's own asserts (the tier ordering: careful beats lazy, easy >= normal >= hard) are statistical and fail now and then on their own;
the table of numbers here is the better regression signal. See docs/dev/tools-tests.md.
"""
import argparse
import json
import os
import re
import subprocess
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BASELINE = os.path.join(REPO, "docs", "dev", "balance_baseline.json")
DEFAULT_GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot.exe")
LINE = re.compile(r"^BOT (\w+) (\w+) (\w+) seed (\d+): rep (-?\d+) score (-?\d+) ending (\S+) cls (\w+)")
REP_TOL = 20
SCORE_TOL = 0.35
SCORE_FLOOR = 25


def parse(text):
    cells = {}
    for line in text.splitlines():
        m = LINE.match(line.strip())
        if m:
            mode, tier, strat, seed, rep, score, ending, cls = m.groups()
            cells["%s %s %s seed %s" % (mode, tier, strat, seed)] = {"rep": int(rep), "score": int(score), "ending": ending, "cls": cls}
    return cells


def run_godot(godot):
    cmd = [godot, "--headless", "--fixed-fps", "60", "--path", os.path.join(REPO, "godot"), "-s", "res://tests/tiers_balance.gd"]
    r = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    return r.stdout + "\n" + r.stderr


def compare(now, base):
    bad, warn = [], []
    for key, b in sorted(base.items()):
        n = now.get(key)
        if n is None:
            bad.append("%s: missing from this run" % key)
            continue
        if abs(n["rep"] - b["rep"]) > REP_TOL:
            bad.append("%s: rep %d (baseline %d, tolerance %d)" % (key, n["rep"], b["rep"], REP_TOL))
        if abs(n["score"] - b["score"]) > max(SCORE_FLOOR, SCORE_TOL * abs(b["score"])):
            bad.append("%s: score %d (baseline %d, tolerance %d%%)" % (key, n["score"], b["score"], int(SCORE_TOL * 100)))
        if n["cls"] != b["cls"]:
            warn.append("%s: ending class %s (baseline %s)" % (key, n["cls"], b["cls"]))
    for key in sorted(set(now) - set(base)):
        warn.append("%s: new cell, not in the baseline" % key)
    return bad, warn


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--update", action="store_true")
    ap.add_argument("--log")
    ap.add_argument("--godot", default=DEFAULT_GODOT)
    a = ap.parse_args()
    text = open(a.log, encoding="utf-8", errors="replace").read() if a.log else run_godot(a.godot)
    now = parse(text)
    if not now:
        print("no BOT lines found: the test did not run")
        return 2
    if a.update or not os.path.exists(BASELINE):
        with open(BASELINE, "w", encoding="utf-8", newline="\n") as f:
            json.dump(now, f, indent=1, sort_keys=True)
            f.write("\n")
        print("baseline written: %d cells -> %s" % (len(now), os.path.relpath(BASELINE, REPO)))
        return 0
    base = json.load(open(BASELINE, encoding="utf-8"))
    bad, warn = compare(now, base)
    for w in warn:
        print("WARN " + w)
    for b in bad:
        print("DRIFT " + b)
    print("balance_baseline: %d cells compared, %d drift, %d warning(s)" % (len(base), len(bad), len(warn)))
    return 1 if bad else 0


sys.exit(main())
