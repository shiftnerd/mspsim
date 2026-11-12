"""Runs headless Godot tests in parallel and prints a pass/fail table.

  python tools/run_tests.py [-j 4] [--timeout 600] [--godot PATH] [--list] [--changed [REF]] [--retry N] [glob_or_name ...]

--changed [REF]  only the tests that can be affected by what changed since REF (default HEAD: uncommitted and staged work, plus new
                 files). A changed script selects the tests that mention it (its file name or its autoload name), those of the
                 scripts that use it (one more hop) and a test named after it; a changed test selects itself; anything the map
                 cannot place (project.godot, tools/make_godot.py, assets other than sets, scenes nobody names) means the full run.
                 Over-inclusive on purpose. Use the full run before a commit that touches shared autoloads.
--retry N        run a failing test again up to N times; a test that passes on a retry is listed as FLAKY (and does not fail the run)

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
SKIP = ["*_shots.gd", "bot_*.gd", "*_balance.gd", "format.gd", "followcam.gd",
        "story_export.gd", "make_systems_reference.gd", "soak_sim.gd", "soak_lib.gd", "fuzz_ui.gd", "fuzz_lib.gd", "fake_npc.gd", "site_shot.gd", "titleshots.gd", "venue_shots.gd", "karaoke_song_shots.gd", "dinner_sim.gd"]
FAIL_RE = re.compile(r"^\W*FAIL\b")
FAILURES_RE = re.compile(r"^\s*failures\s*=\s*[1-9]")
ERR_RE = re.compile(r"SCRIPT ERROR")


def needs_renderer(test):
    """screenshot tests (they say so in the header or save a PNG) cannot run with --headless"""
    with open(os.path.join(TESTS, test), encoding="utf-8", errors="replace") as f:
        text = f.read()
    head = " ".join(text.splitlines()[:15]).lower()
    return "renderer" in head or "save_png" in text


SCRIPTS = os.path.join(GODOT_DIR, "scripts")


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


def autoloads():
    """{AutoloadName: 'stem'} from project.godot"""
    out = {}
    try:
        with open(os.path.join(GODOT_DIR, "project.godot"), encoding="utf-8") as f:
            for m in re.finditer(r'^(\w+)="\*?res://scripts/(\w+)\.gd"', f.read(), re.M):
                out[m.group(1)] = m.group(2)
    except OSError:
        pass
    return out


def changed_files(ref):
    def git(*a):
        return subprocess.run(["git", *a], cwd=REPO, capture_output=True, text=True).stdout.split("\n")
    names = set(git("diff", "--name-only", ref)) | set(git("ls-files", "-o", "--exclude-standard"))
    return sorted(n.strip() for n in names if n.strip())


def select_changed(ref):
    """The tests a change since `ref` can affect, or None for 'run everything'."""
    files = changed_files(ref)
    if not files:
        return []
    by_stem = {v: k for k, v in autoloads().items()}
    scripts = {os.path.splitext(f)[0]: open(os.path.join(SCRIPTS, f), encoding="utf-8", errors="replace").read()
               for f in os.listdir(SCRIPTS) if f.endswith(".gd")}
    tests = {f: open(os.path.join(TESTS, f), encoding="utf-8", errors="replace").read() for f in os.listdir(TESTS) if f.endswith(".gd")}

    def mentions(text, stem):
        if re.search(r"scripts/%s\.gd|\b%s\.gd\b" % (re.escape(stem), re.escape(stem)), text):
            return True
        name = by_stem.get(stem)
        return bool(name and re.search(r"\b%s\b" % re.escape(name), text))

    picked = set()
    stems = set()
    for f in files:
        if f.startswith("godot/tests/") and f.endswith(".gd"):
            picked.add(os.path.basename(f))
        elif f.startswith("godot/scripts/") and f.endswith(".gd"):
            stems.add(os.path.splitext(os.path.basename(f))[0])
        elif f.startswith("godot/scenes/") and f.endswith(".tscn"):
            scene = os.path.splitext(os.path.basename(f))[0]
            hit = [t for t, text in tests.items() if scene in text]
            if not hit:
                return None
            picked.update(hit)
        elif f.startswith("godot/story/"):
            picked.update(["strings.gd", "canon.gd", "canon_text.gd"])
        elif f.startswith(("docs/", "office/", "sprites/", "archive/", "godot/assets/sets/")) or f.endswith((".md", ".txt")):
            continue  # documents and art sources; the importer and the audit tests are the checks
        elif f.startswith("tools/") and not f.endswith(("make_godot.py", "check_generator.py")):
            continue  # helper scripts and Lua tools are not tested by the suite
        else:
            return None  # project.godot, the generator, shared assets: run everything
    users = {}
    for stem in stems:  # one more hop: scripts that mention a changed script
        for other, text in scripts.items():
            if other != stem and mentions(text, stem):
                users.setdefault(stem, set()).add(other)
    for stem in stems:
        for t, text in tests.items():
            if mentions(text, stem) or t.startswith(stem) or any(mentions(text, u) for u in users.get(stem, ())):
                picked.add(t)
    picked.add("smoke.gd")
    return sorted(t for t in picked if t in tests)


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
            "secs": time.time() - t0,
            "tail": [l for l in lines if FAIL_RE.match(l) or FAILURES_RE.search(l) or ERR_RE.search(l)][:20] + [""] + lines[-12:]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("-j", "--jobs", type=int, default=4)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT))
    ap.add_argument("--changed", nargs="?", const="HEAD", default=None, metavar="REF")
    ap.add_argument("--retry", type=int, default=0)
    ap.add_argument("--all", action="store_true", help="also run the tests in SKIP (renderer / balance tools)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--logdir", default=os.path.join(tempfile.gettempdir(), "run_tests"))
    a = ap.parse_args()
    tests = discover(a.names, a.all)
    if a.changed is not None and not a.names:
        sel = select_changed(a.changed)
        if sel is None:
            print("a changed file cannot be mapped to tests: running everything")
        else:
            tests = [t for t in tests if t in sel]
            print("changed since %s: %d test(s) selected" % (a.changed, len(tests)))
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
            tries = 0
            while r["status"] != "ok" and tries < a.retry:
                tries += 1
                r2 = run_one(r["test"], a.godot, a.timeout, a.logdir)
                if r2["status"] == "ok":
                    r2["status"], r2["secs"] = "FLAKY", r["secs"] + r2["secs"]
                    r = r2
                    break
                r = r2
            results.append(r)
            print(f"{r['status']:8} {r['test']:28} {r['secs']:6.1f}s", flush=True)
    results.sort(key=lambda r: r["test"])
    print("\n%-30s %-8s %5s %5s %5s %7s" % ("test", "result", "exit", "FAIL", "ERR", "secs"))
    for r in results:
        print("%-30s %-8s %5d %5d %5d %7.1f" % (r["test"], r["status"], r["code"], r["fails"], r["errs"], r["secs"]))
    bad = [r for r in results if r["status"] not in ("ok", "FLAKY")]
    flaky = [r["test"] for r in results if r["status"] == "FLAKY"]
    if flaky:
        print("\nFLAKY (failed, then passed on a retry): " + ", ".join(flaky))
    for r in bad:
        print(f"\n--- {r['test']} ({r['status']}) tail of {os.path.join(a.logdir, r['test'][:-3] + '.log')}")
        print("\n".join(r["tail"]))
    print(f"\n{len(results) - len(bad)}/{len(results)} passed, {len(bad)} failed, {time.time() - t0:.0f}s wall, -j {a.jobs}")
    return 1 if bad else 0


sys.exit(main())
