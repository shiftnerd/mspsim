#!/usr/bin/env python
"""Edit a script in the generator text (tools/make_godot.py) and in the real godot/ tree in one go.

The rule of this project: every `.gd` edit lives in BOTH places in the same commit, because `make_godot.py` is never run in
the real tree (CLAUDE.md). The generator holds files as compact text blocks (4-space indent), the real files are formatted
(tabs). This tool does the same edit twice, atomically: either both files change or nothing is written.

    python tools/port_edit.py edit SPEC.json [--dry-run]
        SPEC.json: {"edits": [{"file": "scripts/outings.gd", "old": "...", "new": "..."}, ...]}
        `old` and `new` are written the way the generator text is (4-space indent). Each `old` must occur exactly once in the
        generator block of that file AND (after the 4-space -> tab conversion) exactly once in the real file.
    python tools/port_edit.py add godot/scripts/new_file.gd [--after scripts/other.gd]
        put the real file into the generator as a new write(...) block (after another block, default: at the end of the scripts)
    python tools/port_edit.py resync godot/scripts/file.gd
        replace the generator block with the current text of the real file. Only for a file you created by hand (the real
        files are formatted, so resyncing an old file swaps its compact text for the formatted one)
    python tools/port_edit.py check
        git add -N the untracked files under godot/ and tools/ (check_generator only sees tracked files) and run the
        generator check in a temp scratch directory; exits non-zero when anything differs

Line endings of both files are kept (CRLF stays CRLF). Backslashes are escaped for the generator's non-raw ''' strings.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GEN = os.path.join(REPO, "tools", "make_godot.py")
GODOT = os.path.join(REPO, "godot")


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        text = f.read()
    return text.replace("\r\n", "\n"), "\r\n" in text


def write(path, text, crlf):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text.replace("\n", "\r\n") if crlf else text)


def to_tabs(text):
    out = []
    for line in text.split("\n"):
        m = re.match(r"^((?: {4})+)", line)
        out.append(("\t" * (len(m.group(1)) // 4) + line[len(m.group(1)):]) if m else line)
    return "\n".join(out)


def to_spaces(text):
    out = []
    for line in text.split("\n"):
        m = re.match(r"^(\t+)", line)
        out.append(("    " * len(m.group(1)) + line[len(m.group(1)):]) if m else line)
    return "\n".join(out)


def block_span(gen, name):
    """(start, end) of the write("<name>", '''...''') block, end is just after the closing ''')"""
    start = gen.find('write("%s", \'\'\'' % name)
    if start < 0:
        raise SystemExit("no write() block for %s in make_godot.py" % name)
    end = gen.index("''')\n", start) + 5
    return start, end


def escape(text):
    if "'''" in text:
        raise SystemExit("the file contains ''' and cannot be embedded in the generator")
    return text.replace("\\", "\\\\")


def cmd_edit(args):
    with open(args.spec, encoding="utf-8") as f:
        spec = json.load(f)
    gen, gen_crlf = read(GEN)
    real_cache = {}
    new_gen = gen
    for e in spec["edits"]:
        name = e["file"]
        old, new = e["old"], e["new"]
        a, b = block_span(new_gen, name)
        block = new_gen[a:b]
        if block.count(old) != 1:
            raise SystemExit("generator: %d matches in %s for: %r" % (block.count(old), name, old[:80]))
        new_gen = new_gen[:a] + block.replace(old, new) + new_gen[b:]
        real_path = os.path.join(GODOT, name)
        text, crlf = real_cache.get(name) or read(real_path)
        o_real, n_real = to_tabs(old), to_tabs(new)
        # the generator text has doubled backslashes; the real file has single ones
        o_real, n_real = o_real.replace("\\\\", "\\"), n_real.replace("\\\\", "\\")
        if text.count(o_real) != 1:
            raise SystemExit("real file: %d matches in %s for: %r" % (text.count(o_real), name, o_real[:80]))
        real_cache[name] = (text.replace(o_real, n_real), crlf)
    if args.dry_run:
        print("ok (dry run): %d edit(s) apply cleanly to the generator and %d real file(s)" % (len(spec["edits"]), len(real_cache)))
        return
    write(GEN, new_gen, gen_crlf)
    for name, (text, crlf) in real_cache.items():
        write(os.path.join(GODOT, name), text, crlf)
    print("edited the generator and: " + ", ".join(sorted(real_cache)))


def _block_text(real_path):
    text, _ = read(real_path)
    return escape(to_spaces(text)).rstrip("\n") + "\n"


def cmd_add(args):
    real_path = os.path.abspath(args.file)
    name = os.path.relpath(real_path, GODOT).replace(os.sep, "/")
    gen, crlf = read(GEN)
    if 'write("%s", \'\'\'' % name in gen:
        raise SystemExit("%s already has a block; use resync" % name)
    block = 'write("%s", \'\'\'%s\'\'\')\n' % (name, _block_text(real_path))
    if args.after:
        _, end = block_span(gen, args.after)
    else:
        last = [m.start() for m in re.finditer(r'^write\("scripts/', gen, re.M)][-1]
        _, end = block_span(gen, re.match(r'write\("([^"]+)"', gen[last:]).group(1))
    write(GEN, gen[:end] + "\n" + block + gen[end:], crlf)
    print("added %s to the generator" % name)


def cmd_resync(args):
    real_path = os.path.abspath(args.file)
    name = os.path.relpath(real_path, GODOT).replace(os.sep, "/")
    gen, crlf = read(GEN)
    a, b = block_span(gen, name)
    write(GEN, gen[:a] + 'write("%s", \'\'\'%s\'\'\')\n' % (name, _block_text(real_path)) + gen[b:], crlf)
    print("resynced %s into the generator" % name)


def cmd_check(args):
    subprocess.run(["git", "add", "-N", "godot", "tools"], cwd=REPO, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    scratch = tempfile.mkdtemp(prefix="gen_check_")
    r = subprocess.run([sys.executable, "-I", os.path.join(REPO, "tools", "check_generator.py"), "--scratch", scratch], cwd=REPO)
    sys.exit(r.returncode)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("edit")
    p.add_argument("spec")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(fn=cmd_edit)
    p = sub.add_parser("add")
    p.add_argument("file")
    p.add_argument("--after")
    p.set_defaults(fn=cmd_add)
    p = sub.add_parser("resync")
    p.add_argument("file")
    p.set_defaults(fn=cmd_resync)
    p = sub.add_parser("check")
    p.set_defaults(fn=cmd_check)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
