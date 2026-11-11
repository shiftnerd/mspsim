"""X13 test hygiene: proves that headless tests never touch the player's own files in user://.

  python tools/user_dir_check.py [--godot PATH] [test ...]

Two checks over a run of ten varied tests (phone, controls, remap, pause and title menus, campaign, career, sound, creator),
one Godot process at a time:

1. THE REAL DIRECTORY. The listing, sizes and modification times of the player's files in the real user:// folder (every file
   whose name does not start with `test_` and that is a save or settings file: .cfg, .save, .json, .dat, .txt) are
   snapshotted before and after the run. Nothing may appear, vanish or change.
2. A FRESH DIRECTORY. The same ten tests run again with APPDATA pointed at an empty temp folder, so user:// is a folder
   nothing else writes to (other worktrees run tests in the real one at the same time). Every file a test leaves there must
   be named `test_...` (a test's own prefix); Godot's own `logs/` and cache folders and PNG screenshots are listed but allowed.

Exit code 1 when either check fails. Not a Godot test itself: `run_tests.py` does not pick it up (it starts Godot ten times).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

# (run_tests.py is not imported: it has no __main__ guard and would start the whole suite)
REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT_DIR = os.path.join(REPO, "godot")
DEFAULT_GODOT = r"C:\Program Files\Godot\Godot.exe"
FAIL_RE = re.compile(r"^\W*FAIL\b")


def user_dir():
    """The project's real user:// folder."""
    name = "MSPSim"
    with open(os.path.join(GODOT_DIR, "project.godot"), encoding="utf-8") as f:
        m = re.search(r'^config/name="([^"]+)"', f.read(), re.M)
        if m:
            name = m.group(1)
    base = os.environ.get("APPDATA")
    if base:
        return os.path.join(base, "Godot", "app_userdata", name)
    return os.path.join(os.path.expanduser("~"), ".local", "share", "godot", "app_userdata", name)


TESTS = ["phone", "phone_key", "remap_menu", "controls_pad", "pause", "title_menu", "campaign", "sfx", "career", "creator"]
PLAYER_EXT = (".cfg", ".save", ".json", ".dat", ".txt")
ENGINE_DIRS = ("logs", "shader_cache", "vulkan")


def player_files(folder):
    """{name: (size, mtime_ns)} of the player's own files (not a test's, not a screenshot)"""
    out = {}
    try:
        names = os.listdir(folder)
    except OSError:
        return out
    for n in names:
        p = os.path.join(folder, n)
        if n.startswith("test_") or not os.path.isfile(p) or not n.lower().endswith(PLAYER_EXT):
            continue
        st = os.stat(p)
        out[n] = (st.st_size, st.st_mtime_ns)
    return out


def run(test, godot, env):
    cmd = [godot, "--headless", "--fixed-fps", "60", "--path", GODOT_DIR, "-s", "res://tests/%s.gd" % test]
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env, timeout=900)
        out = p.stdout.decode("utf-8", "replace")
        bad = p.returncode != 0 or any(FAIL_RE.match(l) for l in out.splitlines())
        return "FAIL" if bad else "ok"
    except subprocess.TimeoutExpired:
        return "timeout"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    a = ap.parse_args()
    tests = a.names or TESTS
    failures = 0

    def check(ok, what):
        nonlocal failures
        failures += 0 if ok else 1
        print(("ok   " if ok else "FAIL ") + what)

    real = user_dir()
    before = player_files(real)
    print("real user dir: %s (%d player files: %s)" % (real, len(before), ", ".join(sorted(before)) or "none"))
    for t in tests:
        print("  real   %-14s %s" % (t, run(t, a.godot, os.environ.copy())))
    after = player_files(real)
    check(sorted(before) == sorted(after), "the real directory lists the same player files after %d tests (new: %s, gone: %s)"
          % (len(tests), sorted(set(after) - set(before)) or "none", sorted(set(before) - set(after)) or "none"))
    changed = [n for n in before if n in after and before[n] != after[n]]
    check(not changed, "no player file changed its size or modification time (%s)" % (changed or "none"))

    fresh = tempfile.mkdtemp(prefix="mspsim_userdir_")
    env = os.environ.copy()
    env["APPDATA"] = fresh
    for t in tests:
        print("  fresh  %-14s %s" % (t, run(t, a.godot, env)))
    left, shots, strays = [], [], []
    for base, _dirs, files in os.walk(fresh):
        rel = os.path.relpath(base, fresh).replace("\\", "/")
        for f in files:
            if any(("/%s/" % d) in ("/" + rel + "/") for d in ENGINE_DIRS) or "app_userdata" not in rel:
                continue  # the engine's own log and cache files, editor settings
            if f.startswith("test_"):  # test_<pid>_... or test_<name>_<pid>_...
                left.append(f)
            elif f.lower().endswith(".png"):
                shots.append(f)
            else:
                strays.append(rel + "/" + f)
    print("fresh user dir: %d test_<pid>_ files, %d screenshots, strays: %s" % (len(left), len(shots), strays or "none"))
    check(len(left) > 0, "the tests did write files there (so the fresh folder really was user://)")
    check(not strays, "every file a test wrote in a fresh user:// is named test_<pid>_... (%s)" % (strays or "none"))
    shutil.rmtree(fresh, ignore_errors=True)
    # the test files left in the real directory are purged by run_tests.py (older than an hour) on its next run
    print("done, failures: %d" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
