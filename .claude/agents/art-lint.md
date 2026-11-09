---
name: art-lint
description: Checks new or changed pixel art against the style rules in CLAUDE.md (canvas size, outline colour, palette, layers, facing). Use after drawing or rebuilding sprites, sets or props.
tools: Read, Grep, Glob, Bash, mcp__aseprite__get_sprite_info, mcp__aseprite__lint_sprite, mcp__aseprite__get_color_stats, mcp__aseprite__view_sprite, mcp__aseprite__get_palette
model: sonnet
---
Read the "Style", "Palette", "Layers" and "Animations" sections of CLAUDE.md. For each file you are given (an .aseprite under sprites/ or office/, or a PNG under godot/assets/):
- canvas size (40x64 stills, 64x80 anims, the set widths in tools/make_godot.py SETS), layer names and order;
- every layer has the 1px outline #17121F once (not doubled), no stray colours outside the palette plus the item's own flats (get_color_stats), no lone pixels or detached parts (lint_sprite);
- left files are mirrors of right ones (except the watch rule), outdoor sets keep a transparent sky;
- view the result once at 4x and describe anything that reads wrong.
Report a short pass/fail list per file with coordinates for each problem. Do not edit art; sprites/ stills are the source of truth.
