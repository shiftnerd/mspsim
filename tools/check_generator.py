"""Checks that tools/make_godot.py still reproduces the committed godot/ project text.

Copies the tracked files of tools/ and godot/ into a scratch directory, runs the generator THERE (never in the
real tree; the Godot import step at the end is disabled in the copy) and diffs the result against the working tree.
Run:  python -I tools/check_generator.py [--keep] [--scratch DIR]
Exit 0 = identical (line endings ignored), 1 = differences listed.
"""
import argparse
import re
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CHECK = (".gd", ".tscn", ".tres", ".godot", ".json", ".cfg")  # text kinds the generator can write


def tracked():
    out = subprocess.run(["git", "ls-files", "tools", "godot"], cwd=REPO, capture_output=True, text=True, check=True)
    return [p for p in out.stdout.splitlines() if p]


def norm(path):
    with open(path, "rb") as f:
        return f.read().replace(b"\r\n", b"\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", action="store_true", help="keep the scratch copy")
    ap.add_argument("--scratch", default="")
    ap.add_argument("--no-format", action="store_true", help="skip the generator's gdformat pass")
    a = ap.parse_args()
    scratch = a.scratch or tempfile.mkdtemp(prefix="check_gen_")
    if os.path.exists(scratch) and a.scratch:
        shutil.rmtree(scratch)
    files = [p for p in tracked() if os.path.exists(os.path.join(REPO, p))]
    for rel in files:
        dst = os.path.join(scratch, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(REPO, rel), dst)
    gen = os.path.join(scratch, "tools", "make_godot.py")
    with open(gen, encoding="utf-8") as f:
        src = f.read()
    # no Godot import pass in the scratch copy
    src = re.sub(r"(?m)^GODOT_EXE = .*$", 'GODOT_EXE = ""', src)
    if a.no_format:
        src = src.replace('shutil.which("gdformat")', "False")
    with open(gen, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    r = subprocess.run([sys.executable, "-I", gen], cwd=scratch, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-2000:], r.stderr[-3000:])
        print("generator failed")
        return 2
    # the committed scripts were hand-edited after the last gdformat pass, so compare gdformat-normalised copies
    ref = os.path.join(scratch, "committed_fmt")
    shutil.copytree(os.path.join(REPO, "godot", "scripts"), os.path.join(ref, "scripts"))
    gen_ref = os.path.join(scratch, "generated_fmt")
    shutil.copytree(os.path.join(scratch, "godot", "scripts"), os.path.join(gen_ref, "scripts"))
    if shutil.which("gdformat"):
        for d in (ref, gen_ref):  # gdformat moves members around, so run both sides to a fixpoint (3 passes)
            for _ in range(3):
                subprocess.run(["gdformat", os.path.join(d, "scripts")], capture_output=True)
    diffs, same, missing = [], 0, []
    for root, _, names in os.walk(os.path.join(scratch, "godot")):
        for n in names:
            full = os.path.join(root, n)
            rel = os.path.relpath(full, scratch).replace("\\", "/")
            if rel.startswith("godot/assets/") or not rel.endswith(CHECK):
                continue
            real = os.path.join(REPO, rel)
            if rel.startswith("godot/scripts/") and rel.endswith(".gd"):
                real = os.path.join(ref, rel[len("godot/"):])
                full = os.path.join(gen_ref, rel[len("godot/"):])
            if not os.path.exists(real):
                missing.append(rel)
            elif norm(full) != norm(real):
                diffs.append(rel)
            else:
                same += 1
    for rel in diffs:
        print("DIFF   ", rel)
    for rel in missing:
        print("NEW    ", rel, "(generated, not in the tree)")
    print(f"{same} identical, {len(diffs)} differ, {len(missing)} only generated; scratch={scratch}")
    if not a.keep and not a.scratch:
        shutil.rmtree(scratch, ignore_errors=True)
    return 1 if diffs or missing else 0


sys.exit(main())
