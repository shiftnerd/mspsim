#!/usr/bin/env python
"""Mechanical pixel-art style check of the exported PNGs under godot/assets (the style rules of CLAUDE.md that a script can see).

    python tools/art_lint.py [--all] [paths...]      default: the files changed since HEAD (uncommitted, staged, untracked); --all = everything

Checks, per PNG:
  * no semi-transparent pixels (alpha is 0 or 255: no anti-aliasing, no soft shadows)
  * not too many colours (props 48, character sheets 80, sets 700: a set is a picture, a prop is one object)
  * character sheets (assets/characters/*.png): height 80, width a multiple of 64, and at least 85 % of the silhouette edge pixels
    are the outline colour #17121F (a missing or doubled outline shows up as a low share)
  * set pictures: no stray size (width at least 320)
Known exceptions go in tools/art_lint_allow.txt (`path-suffix  check  reason`). Exits 1 when something fails.
Needs Pillow (pip install pillow).
"""
import argparse
import glob
import os
import subprocess
import sys

from PIL import Image

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ASSETS = os.path.join(REPO, "godot", "assets")
OUTLINE = (0x17, 0x12, 0x1F)
LIMITS = {"props": 48, "characters": 80, "sets": 700}


def allowed():
    out = {}
    path = os.path.join(os.path.dirname(__file__), "art_lint_allow.txt")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                parts = line.split(None, 2)
                if len(parts) >= 2:
                    out.setdefault(parts[0], set()).add(parts[1])
    return out


def kind_of(path):
    try:
        rel = os.path.relpath(path, ASSETS).replace(os.sep, "/")
    except ValueError:  # another drive: not one of ours
        return "", os.path.basename(path)
    return rel.split("/")[0], rel


def edge_share(im):
    """share of silhouette-edge pixels (opaque next to transparent, 4-neighbours) that are the outline colour"""
    w, h = im.size
    px = im.load()
    edge = 0
    ink = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                    edge += 1
                    ink += (r, g, b) == OUTLINE
                    break
    return (ink / edge) if edge else 1.0


def lint(path, allow):
    group, rel = kind_of(path)
    skip = set()
    for suffix, checks in allow.items():
        if rel.endswith(suffix):
            skip |= checks
    problems = []
    im = Image.open(path).convert("RGBA")
    px = im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()
    alphas = {p[3] for p in px}
    if "alpha" not in skip and any(0 < a < 255 for a in alphas):
        problems.append(("alpha", "semi-transparent pixels (anti-aliasing or a soft edge)"))
    colours = {p[:3] for p in px if p[3] > 0}
    limit = LIMITS.get(group)
    if limit and "colours" not in skip and len(colours) > limit:
        problems.append(("colours", "%d colours (limit %d for %s)" % (len(colours), limit, group)))
    if group == "characters" and path.endswith(".png"):
        if "size" not in skip and (im.height != 80 or im.width % 64):
            problems.append(("size", "character sheet is %dx%d (height 80, width a multiple of 64)" % im.size))
        elif "outline" not in skip:
            share = edge_share(im)
            if share < 0.85:
                problems.append(("outline", "only %.0f%% of the edge pixels are the outline colour" % (share * 100)))
    if group == "sets" and path.endswith(".png") and "size" not in skip and im.width < 320:
        problems.append(("size", "set picture is %d px wide (minimum 320)" % im.width))
    return problems


def changed():
    def git(*a):
        return subprocess.run(["git", *a], cwd=REPO, capture_output=True, text=True).stdout.split("\n")
    names = set(git("diff", "--name-only", "HEAD")) | set(git("ls-files", "-o", "--exclude-standard"))
    return [os.path.join(REPO, n) for n in sorted(names) if n.startswith("godot/assets/") and n.endswith(".png")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    if a.paths:
        files = [os.path.abspath(p) for p in a.paths]
    elif a.all:
        files = sorted(glob.glob(os.path.join(ASSETS, "**", "*.png"), recursive=True))
    else:
        files = changed()
    allow = allowed()
    bad = 0
    for f in files:
        if not os.path.exists(f):
            continue
        for check, msg in lint(f, allow):
            bad += 1
            print("FAIL %s: [%s] %s" % (os.path.relpath(f, REPO).replace(os.sep, "/"), check, msg))
    print("art_lint: %d file(s), %d problem(s)" % (len(files), bad))
    return 1 if bad else 0


sys.exit(main())
