"""Runs headless Godot tests in parallel and prints a pass/fail table.

  python tools/run_tests.py [-j 4] [--timeout 600] [--godot PATH] [--list] [glob_or_name ...]

Names are matched against godot/tests/*.gd (`campaign`, `owner*`, `tests/skills.gd`). With no names it runs every
headless regression test (everything except the SKIP patterns below: screenshot tests, balance runs, harnesses).
A test passes when the exit code is 0, no output line is a FAIL marker and there is no SCRIPT ERROR. A FAIL marker is a
line that starts with FAIL (an `ok ... FAIL ...` line, as t2 prints, does not count) or "failures=N" with N > 0. Every test uses its own save prefix (user://test_<pid>_...), so workers do not collide; the runner deletes a test's files when it ends and any test file older than an hour at the start (process ids get reused, and a test must not inherit an earlier test's career counters).
Full output of each test goes to <scratch>/run_tests/<name>.log (default: the temp dir); failures print a tail.
"""
import argparse
import concurrent.futures as cf
import fnmatch
import glob
import os
import re
import subprocess
import sys
import tempfile
import time

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT_DIR = os.path.join(REPO, "godot")
TESTS = os.path.join(GODOT_DIR, "tests")
DEFAULT_GODOT = r"C:\Program Files\Godot\Godot.exe"
# not part of the default headless run (tests whose header mentions a renderer or that save PNGs are skipped too): are dev tools / long balance runs, or are libraries
SKIP = ["*_shots.gd", "bot_*.gd", "*_balance.gd", "click_harness.gd", "layout_audit.gd", "format.gd", "followcam.gd",
        "story_export.gd", "fake_npc.gd", "site_shot.gd", "titleshots.gd", "venue_shots.gd", "karaoke_song_shots.gd", "dinner_sim.gd"]
FAIL_RE = re.compile(r"^\W*FAIL\b")
FAILURES_RE = re.compile(r"^\s*failures\s*=\s*[1-9]")
ERR_RE = re.compile(r"SCRIPT ERROR")


def needs_renderer(test):
    """screenshot tests (they say so in the header or save a PNG) cannot run with --headless"""
    with open(os.path.join(TESTS, test), encoding="utf-8", errors="replace") as f:
        text = f.read()
    head = " ".join(text.splitlines()[:15]).lower()
    return "renderer" in head or "save_png" in text


def discover(names, include_skipped):
    all_tests = sorted(f for f in os.listdir(TESTS) if f.endswith(".gd"))
    if not names:
        return [t for t in all_tests if include_skipped or not (any(fnmatch.fnmatch(t, p) for p in SKIP) or needs_renderer(t))]
    picked = []
    for n in names:
        n = os.path.basename(n)
        pat = n if n.endswith(".gd") else n + ".gd"
        hits = [t for t in all_tests if fnmatch.fnmatch(t, pat)]
        if not hits:
            print("no test matches", n)
        picked += [h for h in hits if h not in picked]
    return picked


def user_dir():
    """The project's user:// folder (where tests keep their user://test_<pid>_* save files)."""
    name = "MSPSim"
    try:
        with open(os.path.join(GODOT_DIR, "project.godot"), encoding="utf-8") as f:
            m = re.search(r'^config/name="([^"]+)"', f.read(), re.M)
            if m:
                name = m.group(1)
    except OSError:
        pass
    base = os.environ.get("APPDATA")
    if base:
        return os.path.join(base, "Godot", "app_userdata", name)
    return os.path.join(os.path.expanduser("~"), ".local", "share", "godot", "app_userdata", name)


def purge_test_files(pid=None):
    """Delete leftover test saves. Process ids get reused, so a test that inherits an earlier test's career or campaign
    file (same pid) is no longer starting clean (the mastery ramp reads career counters): purge a pid's files after each
    test, and old files at the start of a run."""
    pattern = "test_%s_*" % (pid if pid is not None else "*")
    for path in glob.glob(os.path.join(user_dir(), pattern)):
        try:
            # at the start of a run only old files go (another run in a different worktree may be using fresh ones)
            if pid is None and time.time() - os.path.getmtime(path) < 3600:
                continue
            os.remove(path)
        except OSError:
            pass


def run_one(test, godot, timeout, logdir):
    t0 = time.time()
    cmd = [godot, "--headless", "--fixed-fps", "60", "--path", GODOT_DIR, "-s", "res://tests/" + test]
    status, out = "ok", ""
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        so, se = proc.communicate(timeout=timeout)
        out = (so + b"\n" + se).decode("utf-8", "replace")
        code = proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        so, se = proc.communicate()
        out = ((so or b"") + b"\n" + (se or b"")).decode("utf-8", "replace")
        code, status = -1, "timeout"
    purge_test_files(proc.pid)
    lines = out.splitlines()
    fails = sum(1 for l in lines if FAIL_RE.match(l) or FAILURES_RE.search(l))
    errs = sum(1 for l in lines if ERR_RE.search(l))
    if status == "ok" and (code != 0 or fails or errs):
        status = "FAIL"
    with open(os.path.join(logdir, test[:-3] + ".log"), "w", encoding="utf-8") as f:
        f.write(out)
    return {"test": test, "status": status, "code": code, "fails": fails, "errs": errs,
            "secs": time.time() - t0, "tail": lines[-12:]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("-j", "--jobs", type=int, default=4)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    ap.add_argument("--all", action="store_true", help="also run the tests in SKIP (renderer / balance tools)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--logdir", default=os.path.join(tempfile.gettempdir(), "run_tests"))
    a = ap.parse_args()
    tests = discover(a.names, a.all)
    if a.list:
        print("\n".join(tests))
        return 0
    os.makedirs(a.logdir, exist_ok=True)
    purge_test_files()
    t0 = time.time()
    results = []
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = [ex.submit(run_one, t, a.godot, a.timeout, a.logdir) for t in tests]
        for f in cf.as_completed(futs):
            r = f.result()
            results.append(r)
            print(f"{r['status']:8} {r['test']:28} {r['secs']:6.1f}s", flush=True)
    results.sort(key=lambda r: r["test"])
    print("\n%-30s %-8s %5s %5s %5s %7s" % ("test", "result", "exit", "FAIL", "ERR", "secs"))
    for r in results:
        print("%-30s %-8s %5d %5d %5d %7.1f" % (r["test"], r["status"], r["code"], r["fails"], r["errs"], r["secs"]))
    bad = [r for r in results if r["status"] != "ok"]
    for r in bad:
        print(f"\n--- {r['test']} ({r['status']}) tail of {os.path.join(a.logdir, r['test'][:-3] + '.log')}")
        print("\n".join(r["tail"]))
    print(f"\n{len(results) - len(bad)}/{len(results)} passed, {len(bad)} failed, {time.time() - t0:.0f}s wall, -j {a.jobs}")
    return 1 if bad else 0


sys.exit(main())
