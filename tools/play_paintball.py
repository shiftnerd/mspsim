#!/usr/bin/env python
"""Play the paintball outing right away, with the debug overlay and keys.

    python tools/play_paintball.py [--godot PATH]

Keys: the outing's own (A/D or arrows run, Z fire, DOWN duck, ESC leave) plus F1 restart, F2 let the crew play your unit,
F3 time x3, F4 print the clock. PAINT_DEBUG=1 draws every unit's role / goal / target under it. Private save files are used.
"""
import argparse
import os
import subprocess

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ap = argparse.ArgumentParser()
ap.add_argument("--godot", default=os.environ.get("GODOT", r"C:\Program Files\Godot\Godot.exe"))
a = ap.parse_args()
env = dict(os.environ, PAINT_DEBUG="1")
subprocess.run([a.godot, "--path", os.path.join(REPO, "godot"), "-s", "res://dev/paintball_play.gd"], env=env)
