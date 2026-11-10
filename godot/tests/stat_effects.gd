extends SceneTree
# gdlint:disable=max-line-length
# X7: does every point-buy stat of the tech path change what happens? The careful bot plays the first DAYS days on the hard
# tier (where a few seconds a ticket decide whether a clock is met) with the flat build and then with one stat at 4, same seed.
# The bot plays the stats the way a player would: it takes the clever fixes a skill unlocks, runs the PowerShell scripts when two
# tickets want the same fix, skips the daily backup check once BACKUP WATCH does it, and it works through the game's own fix
# times, failure rolls and SLA clocks. A stat passes when at least one outcome (reputation, score, tickets closed, SLAs missed,
# client mood) differs from the flat run; the table is printed for docs/balance-notes.md.
# The four tech presets must also give at least three different outcomes on hard (they used to tie at reputation 100 on normal).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/stat_effects.gd

const DAYS := 8
const SEED := 11
var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _row(bots: RefCounted, build: Dictionary) -> Dictionary:
	bots.preset_build = build
	var r: Dictionary = await bots.play("tech", "hard", "careful", SEED)
	var st: Dictionary = r.get("tech_stats", {})
	return {
		"rep": int(r.rep), "score": int(r.score), "closed": int(r.closed), "missed": int(r.missed),
		"mood": int(root.get_node("Sales").average()), "clever": int(st.get("clever", 0)), "scripted": int(st.get("scripted", 0)), "fails": int(st.get("fails", 0)),
	}


func _line(name: String, r: Dictionary) -> String:
	return "STAT %-14s rep %3d  score %4d  closed %3d  missed %3d  mood %3d  clever %3d  scripted %2d  failed fixes %2d" % [name, r.rep, r.score, r.closed, r.missed, r.mood, r.clever, r.scripted, r.fails]


func _outcome(r: Dictionary) -> Array:
	return [r.rep, r.score, r.closed, r.missed, r.mood]


func _init() -> void:
	await process_frame
	var build := root.get_node("Build")
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = 120.0
	bots.stop_day = DAYS
	var flat: Dictionary = await _row(bots, {})
	print(_line("flat", flat))
	for stat in build.stats_of("tech"):
		var b := {"preset": "custom", "stats": {str(stat): 4}, "spent": 7, "tier": "hard"}
		var r: Dictionary = await _row(bots, b)
		print(_line(str(stat) + " 4", r))
		_check(_outcome(r) != _outcome(flat), "%s at 4 changes the first %d days (%s against flat %s)" % [str(stat), DAYS, str(_outcome(r)), str(_outcome(flat))])
	var seen := {}
	for row in build.PRESETS.get("tech", []):
		var r: Dictionary = await _row(bots, build.apply_preset("tech", "", "hard", str(row.id)))
		print(_line(str(row.id), r))
		seen[str(_outcome(r))] = true
	_check(seen.size() >= 3, "the four tech presets give at least three different outcomes (%d)" % seen.size())
	bots.preset_build = {}
	root.get_node("Campaign").quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
