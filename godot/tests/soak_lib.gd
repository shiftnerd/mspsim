extends RefCounted
# gdlint:disable=class-definitions-order,duplicated-load,max-line-length,max-returns,unused-argument
# The simulation soak (slug soak-sim). Plays long bot runs of every mode and fails on: any script error / push_error / "leaked" /
# "ERROR:" line (captured in process through a Logger, with the run configuration that produced it), a run that stops making
# progress (the state is dumped), node / object / orphan growth day after day, and a save / resume that does not load back to the
# same numbers. Used by tests/soak_sim.gd (the CLI harness) and tests/soak_sim_smoke.gd (the default-suite smoke test).
# Not a balance tool: it never looks at the score, only at errors.
#
#   var lib := load("res://tests/soak_lib.gd").new(self)
#   var res: Dictionary = await lib.run_cell({"kind": "campaign", "mode": "tech", "tier": "normal", "strat": "careful", "seed": 1})
#   res = {cfg, ok, errors: [...], stuck: {...}, flags: [...], days, frames, nodes: [...], saves: n, resumes: n, secs}

const SAVE_NUMS := ["day", "rep", "scars", "cash", "year"]
const OUTING_KEYS := {
	"bowling": [KEY_SPACE],
	"karaoke": [KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT],
	"escape": [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_H, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_E],
	"dinner": [KEY_UP, KEY_DOWN, KEY_ENTER],
	"chair": [KEY_Z, KEY_X, KEY_UP, KEY_DOWN, KEY_Z, KEY_X],
	"cornhole": [KEY_E],
	"grill": [KEY_E, KEY_SPACE, KEY_SHIFT],
	"paintball": [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_Z, KEY_SHIFT],
	"darts": [KEY_E],
}


# ---- the error capture ----------------------------------------------------------------------------------------------------
class Capture:
	extends Logger
	var cfg := "-"
	var errors: Array = []
	var warnings: Array = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		var text := "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		_mutex.lock()
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings.append({"cfg": cfg, "text": text})
		else:
			errors.append({"cfg": cfg, "kind": ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)], "text": text})
		_mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		if not error:
			return
		var m := message.strip_edges()
		if m.begins_with("SCRIPT ERROR") or m.begins_with("ERROR:") or m.contains("leaked"):
			return  # already reported through _log_error (the engine prints them again as text)
		if m == "":
			return
		_mutex.lock()
		warnings.append({"cfg": cfg, "text": "stderr: " + m.substr(0, 200)})
		_mutex.unlock()

	func take() -> Dictionary:
		_mutex.lock()
		var out := {"errors": errors, "warnings": warnings}
		errors = []
		warnings = []
		_mutex.unlock()
		return out


var tree: SceneTree
var root: Node
var cap: Capture
var rng := RandomNumberGenerator.new()
var ts := 20.0
var stuck_frames := 1500  # frames without a clock step, a new day, an answered card or a closed ticket (about 25 s at 60 fps, 15 to 60 game minutes at ts 20)
var verbose := false

# per-run state (reset by _begin_monitor)
var _bots: RefCounted = null
var _spec: Dictionary = {}
var _frame := 0
var _last_sig := ""
var _last_move := 0
var _stuck: Dictionary = {}
var _nudges := 0
var _day_seen := 0
var _series: Array = []  # [{day, nodes, objs, orphans, mem}]
var _save_checks := 0
var _save_fail: Array = []
var _resume_checks := 0
var _resume_fail: Array = []
var _resume_marks: Dictionary = {}
var _chaos_close: Dictionary = {}
var _chaos_log: Array = []


func _init(t: SceneTree) -> void:
	tree = t
	root = t.root


func install_capture() -> void:
	cap = Capture.new()
	OS.add_logger(cap)


# ---- cells ----------------------------------------------------------------------------------------------------------------
func cfg_text(spec: Dictionary) -> String:
	var parts: Array = []
	for k in ["kind", "mode", "year", "tier", "strat", "seed", "id", "theme", "recipe", "song", "variety", "night", "party", "mut", "coop", "chaos", "reload", "resumes"]:
		if spec.has(k):
			parts.append("%s=%s" % [k, str(spec[k])])
	return " ".join(parts)


func run_cell(spec: Dictionary) -> Dictionary:
	_spec = spec
	var cfg := cfg_text(spec)
	if cap != null:
		cap.cfg = cfg
		cap.take()  # nothing of an earlier run is this run's
	var t0 := Time.get_ticks_msec()
	_begin_monitor()
	var info := ""
	match str(spec.get("kind", "campaign")):
		"campaign":
			info = await _run_campaign()
		"free":
			info = await _run_free()
		"outing":
			info = await _run_outing()
		"nerf":
			info = await _run_nerf()
		"printer":
			info = await _run_printer()
		"expo":
			info = await _run_expo()
		"saves":
			info = await _run_saves()
		"ablate":
			info = await _run_ablate()
		_:
			info = "UNKNOWN KIND"
	var captured: Dictionary = cap.take() if cap != null else {"errors": [], "warnings": []}
	var flags: Array = _growth_flags()
	var errors: Array = captured.errors
	var ok := errors.is_empty() and _stuck.is_empty() and flags.is_empty() and _save_fail.is_empty() and _resume_fail.is_empty()
	var res := {
		"cfg": cfg, "ok": ok, "errors": errors, "warnings": (captured.warnings as Array).size(), "stuck": _stuck, "flags": flags, "info": info,
		"days": _day_seen, "frames": _frame, "saves": _save_checks, "save_fail": _save_fail, "resumes": _resume_checks, "resume_fail": _resume_fail,
		"nodes": _series.map(func(s: Dictionary) -> Array: return [s.day, s.nodes, s.objs, s.orphans]), "secs": snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.1),
		"chaos": _chaos_log.size(),
	}
	return res


func _begin_monitor() -> void:
	_frame = 0
	_last_sig = ""
	_last_move = 0
	_stuck = {}
	_nudges = 0
	_day_seen = 0
	_series = []
	_save_checks = 0
	_save_fail = []
	_resume_checks = 0
	_resume_fail = []
	_resume_marks = {}
	_chaos_close = {}
	_chaos_log = []
	rng.seed = int(_spec.get("seed", 1)) * 104729 + 17


# ---- the campaign cells ---------------------------------------------------------------------------------------------------
func _run_campaign() -> String:
	var mode := str(_spec.mode)
	var strat := str(_spec.get("strat", "careful"))
	if strat == "mixed" and mode in ["owner", "sales"]:
		strat = "careful" if int(_spec.seed) % 2 == 0 else "lazy"  # (the bots of those modes have no "mixed")
	_bots = load("res://tests/bot_lib.gd").new(tree)
	_bots.ts = float(_spec.get("ts", 4.0 if mode == "owner" else ts))
	_bots.year = int(_spec.get("year", 1))
	_bots.coop = bool(_spec.get("coop", false))
	_bots.frame_hook = _on_frame
	if int(_spec.get("resumes", 0)) > 0:
		var total := int(_spec.resume_span) if _spec.has("resume_span") else 6000
		for k in int(_spec.resumes):
			_resume_marks[rng.randi_range(300, total)] = true
	var row: Dictionary = await _bots.play(mode, str(_spec.get("tier", "normal")), strat, int(_spec.seed))
	_end_of_run_cleanup()
	return "%s ending %s rep %s last_day %s" % [str(row.get("cls", "?")), str(row.get("ending", "?")), str(row.get("rep", "?")), str(row.get("last_day", "?"))]


func _end_of_run_cleanup() -> void:
	var cards := root.get_node("Cards")
	var guard := 0
	while cards.is_open and guard < 40:
		guard += 1
		cards.pick(0)
	root.get_node("World").time_scale = 1.0
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Difficulty").day_scale_next = 1.0
	root.get_node("Difficulty").day_scale = 1.0
	for n in ["Phone", "Computer"]:
		if root.get_node(n).is_open:
			root.get_node(n).close()


# called once per bot frame
func _on_frame(_n: int) -> void:
	_frame += 1
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	# progress: the clock steps, a day turns, a card is answered, a ticket closes
	var sig := "%d|%.3f|%d|%d" % [int(c.day), float(world.clock), _bots.card_log.size() if _bots != null else 0, int(msp.closed_ok)]
	if sig != _last_sig:
		_last_sig = sig
		_last_move = _frame
	elif _frame - _last_move > stuck_frames and not _bots.abort:
		_stuck = _dump("no progress for %d frames" % stuck_frames)
		_nudges += 1
		if _nudges >= 2:
			_bots.abort = true  # a second stall after a nudge: end the run (it reports TIMEOUT)
		else:
			world.clock = 23.9  # nudge: close the day
			_last_move = _frame
	# the day turned
	if int(c.day) != _day_seen and c.active:
		var first := _day_seen == 0
		_day_seen = int(c.day)
		_sample()
		if not first and bool(_spec.get("reload", false)):
			_check_save_reload()
	if _resume_marks.has(_frame) or (_resume_marks.size() > 0 and _resume_pending > 0):
		_try_resume()
	if bool(_spec.get("chaos", false)):
		_chaos()
	if _bots != null and _frame > int(_spec.get("max_frames", 400000)):
		_bots.abort = true


var _resume_pending := 0


func _sample() -> void:
	_series.append({
		"day": _day_seen,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objs": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	})


# the growth rules (thresholds were set from the first clean runs: see docs/dev/notes-soak-sim.md)
func _growth_flags() -> Array:
	var out: Array = []
	if _series.size() < 5:
		return out
	var base: Dictionary = {}
	for s in _series:
		if int(s.day) == 3 or (base.is_empty() and int(s.day) >= 3):
			base = s
	if base.is_empty():
		return out
	var last: Dictionary = _series[_series.size() - 1]
	var tol_nodes := float(_spec.get("node_tol", 0.15))
	if float(last.nodes) > float(base.nodes) * (1.0 + tol_nodes) + 40.0:
		out.append("nodes grew %d -> %d (day %d to %d)" % [base.nodes, last.nodes, base.day, last.day])
	if float(last.objs) > float(base.objs) * (1.0 + tol_nodes) + 200.0:
		out.append("objects grew %d -> %d (day %d to %d)" % [base.objs, last.objs, base.day, last.day])
	if int(last.orphans) > int(base.orphans) + 25:
		out.append("orphan nodes climbed %d -> %d" % [base.orphans, last.orphans])
	return out


func _dump(why: String) -> Dictionary:
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var scene := tree.current_scene
	var cards := root.get_node("Cards")
	var d := {
		"why": why, "frame": _frame, "day": int(c.day), "clock": snappedf(float(world.clock), 0.01), "time_scale": world.time_scale, "mode": str(c.mode), "active": c.active,
		"awaiting": c._awaiting, "scene": scene.scene_file_path.get_file() if scene != null else "-", "ui_open": root.get_node("Game").ui_open, "busy": root.get_node("Game").busy, "title": root.get_node("Game").title_mode,
		"cards_open": cards.is_open, "cards_waiting": cards.waiting(), "card": str(cards.text).substr(0, 60) if cards.is_open else "",
		"phone": root.get_node("Phone").is_open, "computer": root.get_node("Computer").is_open, "report": root.get_node("DayReport").is_open, "review": root.get_node("Review").is_open,
		"outing": root.get_node("Outings").is_open, "onsite": root.get_node("Onsite").active, "onsite_busy": root.get_node("Onsite").busy, "overtime": root.get_node("Story").overtime,
		"open_tickets": root.get_node("Msp").open_tickets().size(), "playbook": root.get_node("Playbook").is_active(), "expo_away": root.get_node("Expo").away,
		"shift_can_end": root.get_node("Shift").can_end_day(), "invite_due": root.get_node("Outings").invite_due(),
	}
	return d


# key order of a dictionary is not state
func _canon(v: Variant) -> String:
	return JSON.stringify(v, "", true)


# ---- save / reload at the morning of every day -----------------------------------------------------------------------------
func _numbers(c: Node) -> Dictionary:
	var out := {}
	for k in SAVE_NUMS:
		out[k] = int(c.get(k))
	out["skills"] = _canon(root.get_node("Skills").to_dict())
	return out


# the end-of-day save the game wrote at the morning of this day: read it, load it, compare. (Newer sections load whatever the file holds.)
func _check_save_reload() -> void:
	var c := root.get_node("Campaign")
	var mode := str(c.mode)
	if not c.has_save(mode):
		return
	_save_checks += 1
	var cfg := ConfigFile.new()
	if cfg.load(c.save_path(mode)) != OK:
		_save_fail.append("day %d: the save file does not read back" % int(c.day))
		return
	var want := {}
	for k in SAVE_NUMS:
		want[k] = int(cfg.get_value("campaign", k, 0))
	var want_skills := _canon(cfg.get_value("campaign", "skills", {}))
	var live := _numbers(c)
	var before_day := int(c.day)
	var ok: bool = c.continue_game(mode)
	if not ok:
		_save_fail.append("day %d: continue_game returned false" % before_day)
		return
	var after := _numbers(c)
	for k in SAVE_NUMS:
		if int(after[k]) != int(want[k]):
			_save_fail.append("day %d: %s is %s after the load, the file says %s" % [before_day, k, str(after[k]), str(want[k])])
		if k in ["day", "rep", "cash"] and int(live[k]) != int(want[k]):
			_save_fail.append("day %d: %s was %s in memory but the file says %s" % [before_day, k, str(live[k]), str(want[k])])
	if str(after.skills) != want_skills:
		_save_fail.append("day %d: skills differ after the load: file %s | loaded %s" % [before_day, want_skills.substr(0, 300), str(after.skills).substr(0, 300)])
	_drain_cards()


func _drain_cards() -> void:
	var cards := root.get_node("Cards")
	var guard := 0
	while cards.is_open and guard < 60:
		guard += 1
		var en: Array = _bots._enabled_idx(cards) if _bots != null else [0]
		cards.pick(int(en[rng.randi() % en.size()]) if not en.is_empty() else 0)


# ---- the mid-day resume point ----------------------------------------------------------------------------------------------
func _resume_numbers(c: Node) -> Dictionary:
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	return {
		"day": int(c.day), "rep": int(c.rep), "cash": int(c.cash), "scars": int(c.scars), "clock": snappedf(float(world.clock), 0.01), "open": msp.open_tickets().size(), "closed": int(msp.closed_ok),
		"score": int(msp.score), "skills": _canon(root.get_node("Skills").to_dict()), "energy": snappedf(float(root.get_node("Shift").energy), 0.1), "owner_cash": int(root.get_node("Owner").cash),
	}


func _try_resume() -> void:
	var c := root.get_node("Campaign")
	if not c.can_snapshot():
		_resume_pending = 1  # wait for a safe moment
		return
	_resume_pending = 0
	var mode := str(c.mode)
	if not c.snapshot():
		return
	var before := _resume_numbers(c)
	var ok: bool = c.continue_game(mode, true)
	_resume_checks += 1
	if not ok:
		_resume_fail.append("frame %d: continue_game(resume) returned false" % _frame)
		return
	var after := _resume_numbers(c)
	for k in before:
		if str(before[k]) != str(after[k]):
			_resume_fail.append("frame %d day %d: %s %s -> %s after the resume" % [_frame, int(c.day), k, str(before[k]), str(after[k])])
	_drain_cards()


# ---- the chaotic bot's hands: random screens, pace, day length, tier, day skips ---------------------------------------------
func _chaos() -> void:
	var game := root.get_node("Game")
	var phone := root.get_node("Phone")
	var computer := root.get_node("Computer")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var diff := root.get_node("Difficulty")
	# things opened a while ago close again
	for key in _chaos_close.keys():
		if _frame >= int(_chaos_close[key]):
			_chaos_close.erase(key)
			if key == "phone" and phone.is_open:
				phone.close()
			elif key == "computer" and computer.is_open:
				computer.close()
	if rng.randf() > 0.006:
		return
	var pick := rng.randi() % 9
	_chaos_log.append(pick)
	match pick:
		0:
			if not phone.is_open and not game.title_mode:
				phone.open()
				_chaos_close["phone"] = _frame + rng.randi_range(5, 200)
		1:
			if not computer.is_open and not game.ui_open and not game.title_mode:
				computer.open(0)
				_chaos_close["computer"] = _frame + rng.randi_range(5, 200)
		2:
			if phone.is_open:
				phone.close()
			if computer.is_open:
				computer.close()
		3:
			if cards.is_open:
				cards.pick(rng.randi() % maxi(1, cards.options.size()))
		4:
			if not root.get_node("DayReport").is_open and not cards.is_open and world.clock < world.DAY_END - 0.5:
				world.clock = world.DAY_END - 0.01  # skip the rest of the day
		5:
			root.get_node("Msp").pace = clampf(float(root.get_node("Msp").pace) * rng.randf_range(0.5, 2.0), 0.25, 3.0)
		6:
			diff.set_tier(["easy", "normal", "hard"][rng.randi() % 3])
		7:
			diff.cycle_day_scale(1 if rng.randf() < 0.5 else -1)
		8:
			world.clock = clampf(float(world.clock) + rng.randf_range(0.2, 2.0), 0.0, 23.0)


# ---- Free Play with every mutator ------------------------------------------------------------------------------------------
func _run_free() -> String:
	var c := root.get_node("Campaign")
	var mut := root.get_node("Mutators")
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	d.settings_path = "user://soak_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://soak_%d_" % OS.get_process_id()
	game.title_mode = false
	game.busy = false
	d.set_tier(str(_spec.get("tier", "normal")))
	d.seed_run(int(_spec.seed))
	c.new_game("free")
	tree.change_scene_to_file("res://scenes/main_floor.tscn")
	for i in 6:
		await tree.process_frame
	game.busy = false
	var id := str(_spec.get("mut", ""))
	mut.set_forced(id)
	msp.enabled = true
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(tree)
	bots.strategy = str(_spec.get("strat", "careful"))
	bots.rng.seed = int(_spec.seed)
	_bots = bots
	world.time_scale = ts
	var cards := root.get_node("Cards")
	var secs := float(_spec.get("sim_secs", 240.0))
	var clock0 := float(world.clock)
	var frames := 0
	var made := 0
	while frames < int(secs * 60.0) and _stuck.is_empty():
		frames += 1
		await tree.process_frame
		_frame += 1
		if cards.is_open:
			bots._drain_tech(cards)
		bots._tech_tick(ts / 60.0)
		if frames % 60 == 0:
			world.time_scale = ts
		if world.clock >= world.DAY_END - 0.05:
			world.clock = world.DAY_START  # free play has no day end: keep the clock inside the day
		if bool(_spec.get("chaos", false)):
			_chaos()
		if frames % 600 == 0:
			_sample()
			_day_seen += 1
	mut.set_forced("")
	_end_of_run_cleanup()
	c.quit_to_title()
	await tree.process_frame
	return "free %s %d frames" % [id if id != "" else "none", frames]


# ---- the outings ---------------------------------------------------------------------------------------------------------
func _run_outing() -> String:
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	var out := root.get_node("Outings")
	var world := root.get_node("World")
	var cards := root.get_node("Cards")
	d.settings_path = "user://soak_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://soak_%d_" % OS.get_process_id()
	game.title_mode = false
	game.busy = false
	d.set_tier(str(_spec.get("tier", "normal")))
	d.seed_run(int(_spec.seed))
	var mode := str(_spec.get("mode", "free"))
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(tree)
	_bots = bots
	bots._clean_slate()
	c.new_game(mode)
	tree.change_scene_to_file("res://scenes/main_floor.tscn")
	for i in 6:
		await tree.process_frame
	game.busy = false
	if mode != "free":
		_drain_cards()
	world.time_scale = 1.0
	var id := str(_spec.id)
	var opts: Dictionary = {"panel": not bool(_spec.get("room", false))}
	for k in ["party", "variety", "night", "theme", "recipes", "digits", "song", "table", "event"]:
		if _spec.has(k):
			opts[k] = _spec[k]
	out.use_rooms = bool(_spec.get("room", false))
	out.start(id, false, opts)
	var keys: Array = OUTING_KEYS.get(id, [KEY_SPACE])
	var frames := 0
	var limit := int(_spec.get("max_frames", 12000))
	var speed := int(_spec.get("speed", 4))
	var last_phase := ""
	var phase_frames := 0
	while frames < limit:
		frames += 1
		await tree.process_frame
		_frame += 1
		if cards.is_open:
			_drain_cards()
			continue
		if not out.is_open:
			if out._wait_id != "":
				continue
			break
		var ph := str(out.phase)
		if ph == last_phase:
			phase_frames += 1
		else:
			last_phase = ph
			phase_frames = 0
		if ph == "intro":
			if bool(_spec.get("room", false)):
				out.press(KEY_ENTER)
			else:
				out.begin_play(str(_spec.song) if _spec.has("song") else "")
		elif ph == "result":
			out.press(KEY_ENTER)
		else:
			if rng.randf() < 0.5:
				out.press(int(keys[rng.randi() % keys.size()]))
			for k in speed:
				out.tick(1.0 / 60.0)
			if phase_frames > limit - 200:
				break
	var info := "%s %d frames" % [id, frames]
	if out.is_open:
		_stuck = _dump("outing %s did not end in %d frames (phase %s)" % [id, frames, str(out.phase)])
		_stuck["outing_phase"] = str(out.phase)
		out.close()
	await tree.process_frame
	await tree.process_frame
	if game.ui_open and not cards.is_open:
		_stuck = _dump("ui_open stayed set after outing %s" % id)
		game.ui_open = false
	_end_of_run_cleanup()
	out.use_rooms = false
	c.quit_to_title()
	await tree.process_frame
	return info


func _run_nerf() -> String:
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var nerf := root.get_node("Nerf")
	var world := root.get_node("World")
	var d := root.get_node("Difficulty")
	d.settings_path = "user://soak_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://soak_%d_" % OS.get_process_id()
	game.title_mode = false
	game.busy = false
	d.seed_run(int(_spec.seed))
	c.new_game("free")
	var scene := str(_spec.get("scene", "main_floor"))
	tree.change_scene_to_file("res://scenes/%s.tscn" % scene)
	for i in 8:
		await tree.process_frame
	game.busy = false
	var me: Node = root.get_node("Players").player0(tree.current_scene)
	if me != null:
		nerf.on_given(0)
	nerf.start_war(str(_spec.get("id", "")))
	world.time_scale = 1.0
	var frames := 0
	while frames < int(float(_spec.get("sim_secs", 80.0)) * 60.0):
		frames += 1
		await tree.process_frame
		_frame += 1
		if me != null and is_instance_valid(me) and frames % 20 == 0:
			nerf.fire_player(me, rng.randf())
		if nerf.war_t <= 0.0:
			break
	_end_of_run_cleanup()
	c.quit_to_title()
	await tree.process_frame
	return "nerf %s in %s %d frames" % [str(_spec.get("id", "free")), scene, frames]


func _run_printer() -> String:
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var pg := root.get_node("PrinterGame")
	var d := root.get_node("Difficulty")
	d.settings_path = "user://soak_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://soak_%d_" % OS.get_process_id()
	game.title_mode = false
	game.busy = false
	d.seed_run(int(_spec.seed))
	c.new_game("free")
	tree.change_scene_to_file("res://scenes/main_floor.tscn")
	for i in 6:
		await tree.process_frame
	game.busy = false
	var done := [false]
	var popts: Dictionary = {}
	if _spec.has("boss"):
		popts["boss"] = bool(_spec.boss)
	pg.start(func(_r: Variant = null) -> void: done[0] = true, str(_spec.get("model", "laser")), popts)
	var frames := 0
	var keys := [KEY_SPACE, KEY_ENTER, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_E, KEY_Z, KEY_X]
	while frames < int(_spec.get("max_frames", 9000)) and pg.is_open:
		frames += 1
		await tree.process_frame
		_frame += 1
		if frames % 2 == 0:
			var ev := InputEventKey.new()
			ev.keycode = keys[rng.randi() % keys.size()]
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventKey.new()
			up.keycode = ev.keycode
			up.pressed = false
			Input.parse_input_event(up)
	if pg.is_open:
		_stuck = _dump("printer game %s did not end in %d frames" % [str(_spec.get("model", "laser")), frames])
		pg.is_open = false
		game.ui_open = false
	_end_of_run_cleanup()
	c.quit_to_title()
	await tree.process_frame
	return "printer %s %d frames done %s" % [str(_spec.get("model", "laser")), frames, str(done[0])]


# the conference trip (tech day 17) and the owner trip walk: the bot plays a tech campaign up to the trip
func _run_expo() -> String:
	_spec["strat"] = _spec.get("strat", "careful")
	_spec["mode"] = _spec.get("mode", "tech")
	return await _run_campaign()


# ---- saves: quit to title and CONTINUE, delete slot, a new campaign over an old save ---------------------------------------
func _run_saves() -> String:
	var mode := str(_spec.get("mode", "tech"))
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	var log: Array = []
	# 1. a run with 20 resume points and the morning reload every day, for `days` days
	_spec["reload"] = true
	_spec["resumes"] = int(_spec.get("resumes", 20))
	_spec["resume_span"] = int(_spec.get("resume_span", 3000))
	_spec["max_frames"] = int(_spec.get("max_frames", 3600))
	var camp_spec: Dictionary = _spec.duplicate()
	camp_spec["kind"] = "campaign"
	var saved_spec := _spec
	_spec = camp_spec
	var info := await _run_campaign()
	_spec = saved_spec
	log.append(info)
	# 2. quit to title and CONTINUE (needs a save: write one)
	var pid := OS.get_process_id()
	c.save_prefix = "user://soak_%d_" % pid
	d.settings_path = "user://soak_%d_settings.cfg" % pid
	game.title_mode = false
	game.busy = false
	c.new_game(mode)
	for i in 4:
		await tree.process_frame
	c.day = 3
	c.rep = 61
	c.save()
	_save_checks += 1
	c.quit_to_title()
	await tree.process_frame
	await tree.process_frame
	game.busy = false
	if not c.continue_game(mode):
		_save_fail.append("CONTINUE after quit to title failed")
	elif int(c.day) != 3 or int(c.rep) != 61:
		_save_fail.append("CONTINUE gave day %d rep %d, wanted 3 / 61" % [int(c.day), int(c.rep)])
	_drain_cards()
	# 3. a new campaign over the old save: the old save is replaced by day 1 on the next save, no resume point is offered
	c.new_game(mode)
	_drain_cards()
	if int(c.day) != 1:
		_save_fail.append("a new campaign over an old save started on day %d" % int(c.day))
	if c.resume_info(mode).size() > 0:
		_save_fail.append("a new campaign still offers the old resume point")
	# 4. delete the slot
	c.save()
	_save_checks += 1
	if not c.has_save(mode):
		_save_fail.append("save() wrote nothing")
	c.delete_slot(mode, 1)
	if c.has_save(mode):
		_save_fail.append("delete_slot left the save")
	_end_of_run_cleanup()
	c.quit_to_title()
	await tree.process_frame
	return "saves: " + " | ".join(log)


# ---- old saves: every section and every key of a real save taken away in turn --------------------------------------------
# An old save lacks whatever was added later. Take a save the game just wrote, delete each section of it (and then each key of
# each section) and load: a missing section must load as the stock one, with no script error.
func _run_ablate() -> String:
	var mode := str(_spec.get("mode", "tech"))
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	var pid := OS.get_process_id()
	c.save_prefix = "user://soak_%d_" % pid
	d.settings_path = "user://soak_%d_settings.cfg" % pid
	game.title_mode = false
	game.busy = false
	d.seed_run(int(_spec.get("seed", 1)))
	c.new_game(mode)
	_drain_cards()
	c.day = 4
	c.save()
	var path: String = c.save_path(mode)
	var base := ConfigFile.new()
	base.load(path)
	var loads := 0
	var failed := 0
	var variants: Array = []
	for sec in base.get_sections():
		for key in base.get_section_keys(sec):
			variants.append([sec, key, ""])
			# one level down: the keys of a dictionary value
			var v: Variant = base.get_value(sec, key)
			if v is Dictionary and sec == "campaign":
				for sub in (v as Dictionary).keys():
					variants.append([sec, key, str(sub)])
	for var_i in variants.size():
		var sec := str(variants[var_i][0])
		var key := str(variants[var_i][1])
		var sub := str(variants[var_i][2])
		base.save(path)
		var cfg := ConfigFile.new()
		cfg.load(path)
		if sub == "":
			cfg.erase_section_key(sec, key)
		else:
			var dict: Dictionary = (cfg.get_value(sec, key) as Dictionary).duplicate(true)
			dict.erase(sub)
			cfg.set_value(sec, key, dict)
		cfg.save(path)
		cap.cfg = "%s ablate %s/%s%s" % [cfg_text(_spec), sec, key, ("/" + sub) if sub != "" else ""]
		var ok: bool = c.continue_game(mode)
		loads += 1
		if not ok:
			failed += 1
		_drain_cards()
		if var_i % 25 == 0:
			await tree.process_frame
	# the whole campaign section as an old file wrote it: a save with only the day (tests/slots.gd's fixture)
	var tiny := ConfigFile.new()
	tiny.set_value("campaign", "day", 5)
	tiny.save(path)
	cap.cfg = cfg_text(_spec) + " ablate only-day"
	if not c.continue_game(mode):
		failed += 1
	loads += 1
	_drain_cards()
	var empty := ConfigFile.new()
	empty.save(path)
	cap.cfg = cfg_text(_spec) + " ablate empty-file"
	c.continue_game(mode)  # an empty file: must not error (it may refuse or load stock)
	loads += 1
	_drain_cards()
	_save_checks += loads
	if failed > 0:
		_save_fail.append("%d of %d ablated saves did not load (continue_game false)" % [failed, loads])
	c.delete_slot(mode, 1)
	_end_of_run_cleanup()
	c.quit_to_title()
	await tree.process_frame
	return "ablate %s: %d loads, %d refused" % [mode, loads, failed]


# the smoke preset (tests/soak_sim_smoke.gd, --preset=fast)
func fast_preset() -> Array:
	return [
		{"kind": "campaign", "mode": "tech", "year": 1, "tier": "normal", "strat": "chaotic", "seed": 1, "chaos": true, "reload": true, "max_frames": 2400},
		{"kind": "outing", "id": "bowling", "tier": "normal", "seed": 1, "max_frames": 1500},
		{"kind": "outing", "id": "darts", "tier": "normal", "seed": 1, "max_frames": 1500},
		{"kind": "ablate", "mode": "tech", "seed": 1},
	]
