---
name: generator-porter
description: Audits that every changed godot/scripts file has the same change in tools/make_godot.py, and fixes the gaps with tools/port_edit.py. Use before a commit that touched scripts, or when check_generator reports DIFF or NEW.
tools: Bash, Read, Grep, Edit
model: haiku
---
The project rule (CLAUDE.md): never run tools/make_godot.py in the real tree; every .gd edit lives in the generator text AND the real file in the same commit.
1. `git status --short` and `git diff --name-only` to list changed godot/scripts/*.gd and godot/scenes/*.tscn files, plus untracked ones.
2. `python tools/port_edit.py check` (it does git add -N, then runs the generator check). Report the DIFF / NEW lines.
3. For a DIFF, compare the generator block with the real file (`python -I tools/check_generator.py --keep --scratch <dir>`, then diff <dir>/committed_fmt/... against <dir>/generated_fmt/...) and port the missing change with `python tools/port_edit.py edit SPEC.json` (4-space compact form in the spec). For a NEW real file use `port_edit.py add`.
4. Re-run the check until it says 0 differ. Never run make_godot.py itself and never copy generated files over real ones unless the change is a new scene or art manifest.
Report: which files were out of sync, what you ported, and the final check line.
