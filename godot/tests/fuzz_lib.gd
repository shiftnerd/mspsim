extends RefCounted
# gdlint:disable=max-returns,max-line-length,class-definitions-order
# The UI input fuzzer's engine (not a test: tests/fuzz_ui.gd is the long harness, tests/fuzz_ui_smoke.gd the short one in the
# default suite). It opens one screen at a time, sends a seeded random stream of events at it (keys, pad buttons and axes of
# both pads, mouse moves and clicks, held keys, focus loss, format / display changes, device switches, touch overlay, rapid
# open and close), then checks the way out: ESC / pad B up to 10 times must bring the game back to a state where a new input
# has an effect, no pause, modal or clock is left stuck, nothing leaked and no text is outside the viewport.
# Every engine error (SCRIPT ERROR and ERROR:) is collected through a Logger with the screen, the seed and the last events.
#
# Replay a failure: the same screen and seed give the same event stream (frames are the unit, not wall time, except the
# 0.45 s a card ignores input after it opens: that wait is real).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/fuzz_ui.gd -- --screens=floor:card_long --seed=7 --seconds=6

const PixelFont := preload("res://scripts/pixelfont.gd")

# every screen the fuzzer knows (name -> how to open it is in open_screen)
const TITLE_SCREENS := [
	"title:prompt", "title:home", "title:quick", "title:top", "title:sub:tech", "title:sub:owner", "title:sub:sales", "title:sub:service",
	"title:continue", "title:year2", "title:settings", "title:settings_keys", "title:settings_remap", "title:career", "title:toolbox", "title:seed",
	"title:charselect:free", "title:charselect:tech", "title:charselect:owner", "title:charselect:sales", "title:charselect:service",
	"title:flow:tech", "title:flow:owner", "title:flow:sales", "title:flow:service", "title:creator:free", "title:creator:tech", "title:creator_pages",
]
const FLOOR_SCREENS := [
	"floor:hud", "floor:hud_banner", "floor:card_long", "floor:card_pic", "floor:card_scam", "floor:pause", "floor:pause_keys", "floor:pause_remap",
	"floor:report:tech", "floor:report:sloppy", "floor:report:ending", "floor:report:owner", "floor:report:owner_full",
	"floor:computer:desktop", "floor:computer:mail", "floor:computer:psa", "floor:computer:rmm", "floor:computer:learn", "floor:computer:lync", "floor:computer:dash", "floor:computer:shop", "floor:computer:site", "floor:computer:nerds",
	"floor:phone:home", "floor:phone:mail", "floor:phone:texts", "floor:phone:tickets", "floor:phone:settings", "floor:phone:phone", "floor:phone:camera",
	"floor:review:tech", "floor:review:owner", "floor:review:sales", "floor:review:service",
	"floor:boardroom:books", "floor:boardroom:clients", "floor:boardroom:projects", "floor:boardroom:team", "floor:boardroom:stack",
	"floor:crm", "floor:quote", "floor:dispatch", "floor:knowledge", "floor:design_card", "floor:hire_card",
	"floor:outing:bowling", "floor:outing:karaoke", "floor:outing:escape", "floor:outing:dinner", "floor:outing:chair", "floor:outing:chair_gauntlet", "floor:outing:chair_fight",
	"floor:outing:paintball", "floor:outing:cornhole", "floor:outing:grill", "floor:outing:darts", "floor:printer", "floor:talk",
	"floor:touch", "floor:overtime", "floor:lastday", "floor:coop", "floor:free", "floor:toolbox", "floor:outfit",
]

class ErrLog:
	extends Logger
	var lines: Array = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == 1:  # a plain warning
			return
		mutex.lock()
		lines.append("%s:%d %s %s [%s]" % [file.get_file(), line, code, rationale, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array:
		mutex.lock()
		var out := lines.duplicate()
		lines.clear()
		mutex.unlock()
		return out

# messages that are not game bugs (the engine complaining about the harness itself), filled as found
const IGNORE := []

var tree: SceneTree
var root: Window
var rng := RandomNumberGenerator.new()
var logger := ErrLog.new()
var fmt_audit := false  # a renderer is present: PixelFont.audit works
var chaos := false  # also open screens through their API at any moment (worst-time sequences)
var coop := false  # co-op join / leave events in the stream (always on for floor:coop)
var _coop_all := false
var pid := 0
var log_path := ""  # a file every line is appended to as it happens (stdout is buffered when redirected)

# results
var events_sent := 0
var screens_fuzzed := 0
var bugs: Array = []  # {screen, seed, kind, msg, events}
var orphan_start := 0
var log_lines: Array = []

var _recent: Array = []  # the last events of this burst
var _held := {}  # keycode -> frame to release at
var _axes := {}  # [device, axis] -> true while pushed
var _frame := 0
var _pending_focus_in := -1
var _screen := ""
var _seed := 0
var _scene_time_ms := 0
var _keys: Array = []
var _verbose := OS.get_environment("FUZZ_VERBOSE") == "1"


func _init(t: SceneTree) -> void:
	tree = t
	root = t.root
	pid = OS.get_process_id()
	fmt_audit = DisplayServer.get_name() != "headless"
	OS.add_logger(logger)
	for a in root.get_node("Controls").ACTIONS:
		for k in root.get_node("Controls").ACTIONS[a][0]:
			if not _keys.has(k):
				_keys.append(k)
	for k in [KEY_ENTER, KEY_ESCAPE, KEY_BACKSPACE, KEY_TAB, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN, KEY_HOME, KEY_END, KEY_DELETE, KEY_KP_ENTER, KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_MINUS, KEY_EQUAL]:
		_keys.append(k)
	for k in range(KEY_A, KEY_Z + 1):
		_keys.append(k)
	for k in range(KEY_0, KEY_9 + 1):
		_keys.append(k)
	for k in range(KEY_KP_0, KEY_KP_9 + 1):
		_keys.append(k)
	for k in range(KEY_F1, KEY_F12 + 1):
		_keys.append(k)
	var ctl := root.get_node("Controls")
	root.get_node("Campaign").save_prefix = "user://test_fuzz_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_fuzz_%d_settings.cfg" % pid
	root.get_node("Game").focus_force = true
	ctl.touch_override = -1


func set_coop_all(on: bool) -> void:
	_coop_all = on


func finish() -> void:
	OS.remove_logger(logger)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("test_fuzz_%d_" % pid):
			DirAccess.remove_absolute("user://" + f)


# ---- little helpers ------------------------------------------------------------------------------------------
func wait(n: int) -> void:
	for i in n:
		await tree.process_frame


func wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame


func _n(name: String) -> Node:
	return root.get_node(name)


func say(s: String) -> void:
	log_lines.append(s)
	print(s)
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(s)


func _report(kind: String, msg: String) -> void:
	var b := {"screen": _screen, "seed": _seed, "kind": kind, "msg": msg, "events": _recent.duplicate()}
	bugs.append(b)
	say("BUG [%s] screen=%s seed=%d: %s" % [kind, _screen, _seed, msg])
	say("     last events: %s" % " | ".join(_recent.slice(maxi(0, _recent.size() - 12))))


func _collect_errors() -> void:
	var seen := {}
	for e in logger.take():
		if seen.has(e):
			continue
		seen[e] = true
		var skip := false
		for ig in IGNORE:
			if str(e).contains(str(ig)):
				skip = true
		if not skip:
			_report("error", str(e))


# ---- opening screens -----------------------------------------------------------------------------------------
func _scene(path: String) -> void:
	for attempt in 3:
		tree.change_scene_to_file(path)
		await wait(3)
		var guard := 0
		while (tree.current_scene == null or tree.current_scene.scene_file_path != path) and guard < 300:
			await tree.process_frame
			guard += 1
		if tree.current_scene != null and tree.current_scene.scene_file_path == path:
			break
	await wait(5)


func _clear_cards() -> void:
	var cards := _n("Cards")
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1


func _reset_world() -> void:
	# whatever the last screen left behind
	var game := _n("Game")
	_n("PauseMenu").close()
	tree.paused = false
	game.busy = false
	game.ui_open = false
	game.focus_lost = false
	game._held_pause = false
	if game.text_large:
		game.set_text_large(false)
	if game.high_contrast:
		game.set_high_contrast(false)
	for c in ["Computer", "Phone", "Toolbox", "Outings", "PrinterGame"]:
		var node := _n(c)
		if node.get("is_open") == true and node.has_method("close"):
			node.close()
	_n("DayReport").is_open = false
	_n("DayReport")._canvas.visible = false
	var rev := _n("Review")
	rev.is_open = false
	rev._canvas.visible = false
	rev._fade = 0.0
	_n("Expo").seated = {}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pl := _n("Players")
	if pl.count() > 1:
		pl.enable_coop(false)
	_n("Controls").pad_active = false
	_n("Controls").touch_override = -1
	_n("Controls").touch_refresh()
	Input.use_accumulated_input = false


func _new_floor(mode: String, who: String) -> void:
	_reset_world()
	_n("Game").title_mode = false
	await _scene("res://scenes/main_floor.tscn")
	load("res://scripts/player.gd").current_character = who
	_n("Campaign").new_game(mode)
	_n("Msp").enabled = false
	await wait(5)
	_clear_cards()
	_n("World").hud_visible = true
	_n("Outings").enabled = true
	_n("Outings").use_rooms = false


func _title() -> Node:
	_reset_world()
	DirAccess.remove_absolute(_n("Career").path())
	DirAccess.remove_absolute(_n("Yeartwo").meta_path())
	for m in ["tech", "owner", "sales", "service"]:
		for slot in 3:
			DirAccess.remove_absolute(_n("Campaign").save_path(m, slot))
			DirAccess.remove_absolute(_n("Campaign").resume_path(m, slot))
	_n("Game").title_mode = true
	await _scene("res://scenes/title.tscn")
	await wait(10)
	if tree.current_scene == null or not tree.current_scene.scene_file_path.contains("title"):
		await _scene("res://scenes/title.tscn")
	return tree.current_scene


func _save_file(mode: String, day: int) -> void:
	var save := ConfigFile.new()
	save.set_value("campaign", "day", day)
	save.set_value("campaign", "year", 1)
	save.save(_n("Campaign").save_path(mode))


func _report_data(kind: String) -> Dictionary:
	var r := {
		"day": 7, "total_days": 20, "closed": 6, "missed": 1, "reopened": 0, "open_left": 2, "clients": 72,
		"points": 14, "overtime": 1.5, "social": 3, "energy": 31, "late": 25, "oncall": 1, "pay": 340,
		"rep_delta": 3, "rep": 53, "cash": 1280, "grade": "B", "fired": false, "final": false, "ending": "",
	}
	if kind == "sloppy":
		r["rep_delta"] = -1
		r["sloppy"] = true
		r["favours"] = 3
	elif kind == "ending":
		r["day"] = 20
		r["final"] = true
		r["grade"] = "A"
		r["ending"] = "YOU KEPT YOUR JOB. MORGAN SAYS THE TEAM IS GLAD YOU STAYED."
	elif kind in ["owner", "owner_full"]:
		r["grade"] = "A"
		r["title"] = "WEEK 9 OF 20 COMPLETE"
		r["rows"] = [["REVENUE", "$6400", Color("8fe3a0")], ["PAYROLL (W-2)", "-$3100", Color.WHITE], ["EBITDA", "$2450", Color("8fe3a0")], ["CASH", "$9800", Color("8fe3a0")]]
		if kind == "owner_full":
			for i in 14:
				r.rows.append(["ROW %d" % i, "THE LONG VALUE OF A LATE WEEK ROW NUMBER %d" % i, Color("ffd27a")])
	return r


# Opens one screen by name. Returns false when the screen is not available.
func open_screen(name: String) -> bool:
	var p := name.split(":")
	var comp := _n("Computer")
	var ph := _n("Phone")
	var cards := _n("Cards")
	var out := _n("Outings")
	if p[0] == "title":
		var t := await _title()
		var cs: Node = null
		match p[1]:
			"prompt":
				pass
			"home":
				t._open_menu()
			"quick":
				t._open_menu()
				t._show_quick()
			"top":
				t._open_menu()
				t._show_top(0)
			"sub":
				t._open_menu()
				t._show_top(0)
				t._show_sub(p[2], 0)
			"continue":
				_save_file("tech", 5)
				_save_file("owner", 3)
				t._open_menu()
				t._show_continue()
			"year2":
				var meta := ConfigFile.new()
				_n("Yeartwo").record(meta, "tech", "lead")
				meta.set_value("tech", "top_year", 2)
				meta.save(_n("Yeartwo").meta_path())
				_save_file("tech", 12)
				t._open_menu()
				t._show_top(0)
				t._show_sub("tech", 0)
			"settings":
				t._open_menu()
				_n("PauseMenu").open_settings()
			"settings_keys":
				t._open_menu()
				_n("PauseMenu").open_settings()
				_n("PauseMenu")._page = 0
			"settings_remap":
				t._open_menu()
				_n("PauseMenu").open_settings()
				_n("PauseMenu")._page = _n("PauseMenu").REMAP_PAGE
			"career":
				var c := _n("Career")
				c.toasts = false
				for k in ["tickets", "outings", "bowl_strikes", "pets", "meetings", "days.tech"]:
					c.counters[k] = 12
				c.check_medals()
				t._open_menu()
				t._open_career()
			"toolbox", "seed":
				t._open_menu()
				t._open_select("free")
				await wait(3)
				t = tree.current_scene
				cs = t._select if is_instance_valid(t) and t.get("_select") != null else null
				if cs != null:
					if p[1] == "toolbox":
						cs.open_tools()
					else:
						cs.open_seed()
			"charselect":
				t._open_menu()
				t._open_select("%s_new" % p[2] if p[2] != "free" else "free")
			"flow":
				t._open_menu()
				t._open_select("%s_new" % p[2])
				await wait(3)
				cs = t._select
				var guard := 0
				while cs != null and cs.step != "options" and guard < 6:
					cs.confirm()
					guard += 1
				if cs != null:
					cs.confirm()  # the build step
			"creator":
				t._open_menu()
				t._open_select("free" if p[2] == "free" else "%s_new" % p[2])
				await wait(3)
				cs = t._select
				if cs != null:
					cs.setup(p[2])
			"creator_pages":
				t._open_menu()
				t._open_select("free")
				await wait(3)
				t = tree.current_scene
				cs = t._select if is_instance_valid(t) and t.get("_select") != null else null
				if cs != null:
					cs.setup("free")
					cs.set_page(2)
		await wait(6)
		return true
	# ---- the floor
	var mode := "tech"
	var who := "office_intern"
	if p[1] == "review" or p[1] == "boardroom" or p[1] == "crm" or p[1] == "quote" or p[1] == "dispatch" or p[1] == "knowledge" or p[1] == "design_card" or p[1] == "hire_card":
		pass
	match p[1]:
		"boardroom":
			mode = "owner"
			who = "office_alan"
		"crm", "quote":
			mode = "sales"
			who = "office_john"
		"dispatch", "knowledge", "design_card", "hire_card":
			mode = "service"
			who = "office_dan"
		"review":
			mode = str(p[2])
			who = {"tech": "office_intern", "owner": "office_alan", "sales": "office_john", "service": "office_dan"}[mode]
		"free", "toolbox", "outfit":
			mode = "free"
	await _new_floor(mode, who)
	var camp := _n("Campaign")
	match p[1]:
		"hud":
			pass
		"hud_banner":
			ph.notify("TEXT", "Morgan", "Gnarly Gnomes says their network is down again. Can you look?")
			await wait(30)
		"card_long", "card_scam", "card_pic":
			if p[1] == "card_pic":
				cards.art_next = "tax"
			cards.ask("MORGAN (MANAGER)", "TWO OWNERS, ONE ACCOUNT, AND A PROSPECT WHO WANTS AN ANSWER BY FRIDAY. WHOSE SIDE ARE YOU ON? I NEED THIS DECISION BEFORE THE END OF THE DAY.", [
				{"label": "GARRISON: TAKE THE LOGO AT 30% OFF AND HOPE THE MARGIN HOLDS UP", "id": "a", "trust_chip": "GARRISON +4", "trust_dir": 1},
				{"label": "NOT ENOUGH MONEY", "id": "b", "enabled": false, "hint": "NEED $600"},
				{"label": "BROKER A SCOPED 15% (2 HOURS)", "id": "c"},
				{"label": "STALL UNTIL MONDAY", "id": "d"},
			], func(_id: String) -> void: pass)
			await wait_ms(500)
		"pause":
			_n("PauseMenu").open()
		"pause_keys":
			_n("PauseMenu").open()
			_n("PauseMenu")._page = 0
		"pause_remap":
			_n("PauseMenu").open()
			_n("PauseMenu")._page = _n("PauseMenu").REMAP_PAGE
		"report":
			_n("DayReport").show_report(_report_data(p[2]))
			await wait_ms(500)
		"computer":
			comp.open(1)
			comp.app = p[2]
		"phone":
			ph.os = "android"
			ph.open()
			ph.locked = false
			ph.app = p[2]
		"review":
			camp.rep = 74
			_n("Review").start()
			await wait(30)
		"boardroom":
			var o := _n("Owner")
			o.flags["peer_group"] = true
			o.apply({"hire": o.JUNIOR})
			comp.open(1)
			comp.activate("app:boardroom")
			comp.activate("btab:" + p[2])
		"crm", "quote":
			var sc := _n("SalesCampaign")
			sc.leads = []
			var l: Dictionary = sc.make_lead(_n("Difficulty").rng_for("fuzz", 1))
			l.stage = "LEAD"
			l.called = true
			sc.leads.append(l)
			camp.day = 4
			comp.open(1)
			comp.activate("app:crm")
			if p[1] == "quote":
				sc.start_quote(int(l.id))
		"dispatch", "knowledge":
			camp.day = 8
			comp.open(1)
			comp.app = p[1]
		"design_card":
			_n("Service").design = ""
			_n("Service").design_card(false)
		"hire_card":
			_n("Service").hire_card()
		"outing":
			var id: String = p[2]
			var opts := {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]}
			if id == "chair_gauntlet" or id == "chair_fight":
				out.chair_event = "straight"
				id = "chair"
			out.start(id, false, opts)
			if p[2] == "chair_gauntlet":
				out.press(KEY_RIGHT)
			elif p[2] == "chair_fight":
				out.press(KEY_RIGHT)
				out.press(KEY_RIGHT)
			if rng.randf() < 0.7:
				out.press(KEY_ENTER)
			await wait_ms(500)
		"printer":
			_n("PrinterGame").start(func(_stars: int) -> void: pass, "laser", {})
		"talk":
			var expo := _n("Expo")
			expo.seated = {"index": 0, "id": "patch", "title": "PATCH MANAGEMENT BEST PRACTICES", "door": 3, "lines": ["A LINE OF THE TALK", "X"], "at": 0, "t": 0.0, "clock": 10.0, "hours": 0.0}
			expo._canvas.visible = true
		"touch":
			_n("Controls").touch_override = 1
			_n("Controls").touch_refresh()
		"overtime":
			_n("Story").overtime = true
			_n("World").clock = 18.5
		"lastday":
			camp.day = camp.total_days()
			await wait(4)
			_clear_cards()
		"coop":
			var pl := _n("Players")
			pl.enable_coop(true)
			pl.join(1, 1)
		"free":
			pass
		"toolbox":
			_n("Toolbox").open_tools(true, Callable())
		"outfit":
			_n("Toolbox").open_outfit()
	await wait(6)
	return true


# ---- the event stream ----------------------------------------------------------------------------------------
func _log_ev(s: String) -> void:
	_recent.append(s)
	if _recent.size() > 60:
		_recent.pop_front()
	events_sent += 1


func _modifiers(ev: InputEventWithModifiers) -> void:
	if rng.randf() < 0.1:
		ev.shift_pressed = rng.randf() < 0.5
		ev.ctrl_pressed = rng.randf() < 0.3
		ev.alt_pressed = rng.randf() < 0.3
		ev.meta_pressed = rng.randf() < 0.1


func _guard_quit(pos: Vector2) -> bool:
	# the title's QUIT row would end the run: never click it
	var t := tree.current_scene
	if t != null and t.get("_items") != null and t.get("_menu_open") == true:
		for it in t._items:
			if str(it.get("id", "")) == "quit":
				var r: Rect2 = it.get("rect", Rect2())
				if r.grow(1).has_point(pos):
					return true
	return false


func _keep_off_quit() -> void:
	var t := tree.current_scene
	if t != null and t.get("_items") != null and t.get("_menu_open") == true and t.get("_sel") != null:
		var items: Array = t._items
		var s: int = t._sel
		if s >= 0 and s < items.size() and str(items[s].get("id", "")) == "quit":
			t._sel = 0 if s != 0 else 1 if items.size() > 1 else 0


# autoloads, the scene and the players: who gets an event sent straight to its handlers (a second pad's events never reach an
# autoload's _input in a headless run; tests/pad_reach.gd and controls_pad.gd do the same)
func _direct(ev: InputEvent) -> void:
	var names := ["Controls", "Players", "Cards", "Computer", "Expo", "DayReport", "Mutators", "Outings", "PauseMenu", "Phone", "PrinterGame", "Review", "Sfx", "Toolbox", "World"]
	var targets: Array = []
	for n in names:
		targets.append(_n(n))
	if tree.current_scene != null:
		targets.append(tree.current_scene)
	for node in targets:
		if not is_instance_valid(node) or not node.can_process():
			continue
		if node.has_method("_input"):
			node._input(ev)
		if node.has_method("_unhandled_input"):
			node._unhandled_input(ev)


func _key_event(code: int, pressed: bool, mods := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code as Key
	ev.physical_keycode = code as Key
	ev.pressed = pressed
	if code >= 32 and code < 127:
		ev.unicode = code if rng.randf() < 0.5 else code + 32 if code >= KEY_A and code <= KEY_Z else code
	if mods:
		_modifiers(ev)
	return ev


func tap_key(code: int) -> void:
	Input.parse_input_event(_key_event(code, true, false))
	Input.parse_input_event(_key_event(code, false, false))


func tap_button(device: int, button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button as JoyButton
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _mouse_point() -> Vector2:
	var size := root.get_visible_rect().size
	if rng.randf() < 0.05:
		return Vector2(rng.randf_range(-20, size.x + 20), rng.randf_range(-20, size.y + 20))
	return Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))


func _send_one() -> void:
	var game := _n("Game")
	var ctl := _n("Controls")
	var roll := rng.randi_range(0, 99)
	if roll < 30:
		var code: int = _keys[rng.randi_range(0, _keys.size() - 1)] if rng.randf() < 0.9 else rng.randi_range(32, 400)
		var down := _key_event(code, true)
		var up := _key_event(code, false)
		_log_ev("key %d%s" % [code, "+mod" if down.shift_pressed or down.ctrl_pressed or down.alt_pressed else ""])
		if code == KEY_ENTER and down.alt_pressed:
			_log_ev("alt+enter")
		Input.parse_input_event(down)
		if rng.randf() < 0.1:
			var echo := down.duplicate() as InputEventKey
			echo.echo = true
			Input.parse_input_event(echo)
		Input.parse_input_event(up)
	elif roll < 38:
		var code: int = _keys[rng.randi_range(0, _keys.size() - 1)]
		_log_ev("hold %d" % code)
		Input.parse_input_event(_key_event(code, true, false))
		_held[code] = _frame + rng.randi_range(2, 40)
	elif roll < 55:
		var dev := 0 if rng.randf() < 0.75 else 1
		var b := rng.randi_range(0, 20)
		_log_ev("pad%d button %d" % [dev, b])
		var ev := InputEventJoypadButton.new()
		ev.device = dev
		ev.button_index = b as JoyButton
		ev.pressed = true
		Input.parse_input_event(ev)
		if dev == 1:
			_direct(ev)
		var up := ev.duplicate() as InputEventJoypadButton
		up.pressed = false
		Input.parse_input_event(up)
		if dev == 1:
			_direct(up)
	elif roll < 63:
		var dev := 0 if rng.randf() < 0.75 else 1
		var axis := rng.randi_range(0, 5)
		var val: float = [-1.0, -0.6, 0.0, 0.6, 1.0, rng.randf_range(-1.0, 1.0)][rng.randi_range(0, 5)]
		_log_ev("pad%d axis %d = %.2f" % [dev, axis, val])
		var ev := InputEventJoypadMotion.new()
		ev.device = dev
		ev.axis = axis as JoyAxis
		ev.axis_value = val
		Input.parse_input_event(ev)
		if dev == 1:
			_direct(ev)
		if absf(val) > 0.3:
			_axes["%d:%d" % [dev, axis]] = [dev, axis]
		else:
			_axes.erase("%d:%d" % [dev, axis])
	elif roll < 76:
		var at := _mouse_point()
		_log_ev("move %d,%d" % [at.x, at.y])
		game.hover_at(at)
	elif roll < 88:
		var at := _mouse_point()
		if _guard_quit(at):
			return
		var button := MOUSE_BUTTON_LEFT if rng.randf() < 0.8 else (MOUSE_BUTTON_RIGHT if rng.randf() < 0.6 else MOUSE_BUTTON_MIDDLE)
		_log_ev("click %d,%d b%d" % [at.x, at.y, button])
		game.click_at(at, button)
	elif roll < 90:
		var at := _mouse_point()
		if _guard_quit(at):
			return
		_log_ev("dblclick %d,%d" % [at.x, at.y])
		game.hover_at(at)
		for i in 2:
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.position = game.ui_to_window(at)
				ev.global_position = ev.position
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.double_click = i == 1 and pressed
				Input.parse_input_event(ev)
	elif roll < 92:
		var at := _mouse_point()
		_log_ev("wheel %d,%d" % [at.x, at.y])
		game.hover_at(at)
		var ev := InputEventMouseButton.new()
		ev.position = game.ui_to_window(at)
		ev.global_position = ev.position
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if rng.randf() < 0.5 else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = true
		Input.parse_input_event(ev)
	elif roll < 93:
		if _pending_focus_in < 0:
			_log_ev("focus out")
			game.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
			_pending_focus_in = _frame + rng.randi_range(1, 30)
	elif roll < 94:
		_log_ev("format cycle")
		game.cycle_format()
	elif roll < 95:
		_log_ev("alt+enter display")
		var ev := _key_event(KEY_ENTER, true, false)
		ev.alt_pressed = true
		root.window_input.emit(ev)
	elif roll < 97:
		_log_ev("device switch key>pad>mouse")
		tap_key(_keys[rng.randi_range(0, _keys.size() - 1)])
		tap_button(0, rng.randi_range(0, 10))
		game.hover_at(_mouse_point())
		game.hover_at(_mouse_point() + Vector2(40, 40))
	elif roll < 98:
		var on := rng.randf() < 0.5
		var which := rng.randi_range(0, 2)
		if which == 1:  # SETTINGS: TEXT NORMAL / LARGE
			_log_ev("text large %s" % on)
			game.set_text_large(on)
		elif which == 2:  # SETTINGS: CONTRAST
			_log_ev("high contrast %s" % on)
			game.set_high_contrast(on)
		else:
			_log_ev("touch %s" % on)
			ctl.touch_override = 1 if on else -1
			ctl.touch_refresh()
	elif roll < 99:
		_log_ev("rapid open/close")
		var code: int = [KEY_ESCAPE, KEY_P, KEY_PAUSE, KEY_J, KEY_Y, KEY_E, KEY_ENTER][rng.randi_range(0, 6)]
		for i in rng.randi_range(2, 6):
			tap_key(code)
	else:
		if coop:
			var pl := _n("Players")
			if pl.count() > 1 and rng.randf() < 0.5:
				_log_ev("coop leave")
				pl.leave(1)
			else:
				_log_ev("coop join")
				pl.enable_coop(true)
				pl.join(1, 1)
		elif chaos:
			_chaos_open()
	_keep_off_quit()


# the things that arrive by themselves in a real game, at whatever moment: a card, a banner, the end of the day, an outing
func _chaos_open() -> void:
	if _scene_name().contains("title"):
		return  # nothing of a run arrives on the title or a character select
	var k := rng.randi_range(0, 5)
	_log_ev("chaos %d" % k)
	match k:
		0:
			_n("Cards").ask("QUINN", "A SHORT QUESTION AT A BAD TIME. WHAT DO YOU WANT TO DO ABOUT THE PRINTER IN THE FRONT OFFICE?", [{"label": "FIX IT", "id": "a"}, {"label": "IGNORE IT", "id": "b"}], func(_id: String) -> void: pass)
		1:
			_n("Phone").notify("TEXT", "Morgan", "A TEXT AT A BAD TIME")
		2:
			_n("DayReport").show_report(_report_data("tech"))
		3:
			if tree.current_scene != null and tree.current_scene.scene_file_path.contains("main_floor"):
				_n("Outings").start(["bowling", "karaoke", "dinner", "cornhole", "chair"][rng.randi_range(0, 4)], false, {"party": ["Alan", "Dan"]})
		4:
			if _n("Computer").is_open:
				_n("Computer").close()
			else:
				_n("Computer").open(1)
		5:
			_n("Campaign").day = rng.randi_range(1, 20)


func _step() -> void:
	_frame += 1
	for code in _held.keys():
		if _frame >= int(_held[code]):
			Input.parse_input_event(_key_event(int(code), false, false))
			_held.erase(code)
	if _pending_focus_in >= 0 and _frame >= _pending_focus_in:
		_pending_focus_in = -1
		_log_ev("focus in")
		_n("Game").notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_keep_off_quit()
	var n := rng.randi_range(0, 3)
	var t := tree.current_scene
	if t != null and t.get("_menu_open") == true:
		n = mini(n, 1)  # one event a frame on the title menu: a Down and an Enter in the same frame would reach the QUIT row, which ends the run
	for i in n:
		_send_one()


func _release_all() -> void:
	for code in _held.keys():
		Input.parse_input_event(_key_event(int(code), false, false))
	_held.clear()
	for k in _axes.keys():
		var ev := InputEventJoypadMotion.new()
		ev.device = int(_axes[k][0])
		ev.axis = int(_axes[k][1]) as JoyAxis
		ev.axis_value = 0.0
		Input.parse_input_event(ev)
		if int(_axes[k][0]) == 1:
			_direct(ev)
	_axes.clear()
	if _pending_focus_in >= 0:
		_pending_focus_in = -1
		_n("Game").notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)


# ---- the state checks ----------------------------------------------------------------------------------------
# what is still open: "" = nothing, a base screen
func modal() -> String:
	var t := tree.current_scene
	if t == null:
		return "no scene"
	var game := _n("Game")
	if t.scene_file_path.contains("title"):
		if _n("PauseMenu").is_open:
			return "settings"
		if t.get("_select") != null:
			return "charselect"
		if t.get("_career") != null:
			return "career"
		if t.get("_menu_open") == true:
			return "title menu"
		if _n("Toolbox").is_open:
			return "toolbox"
		for n in ["Computer", "Phone", "DayReport", "Review", "Outings", "PrinterGame"]:  # nothing of a run may be open on the title
			if _n(n).is_open:
				return n
		return ""
	if _n("Toolbox").outfit_open and not _n("PauseMenu").is_open:
		return "outfit"  # the outfit overlay owns every key: a card that came up over it can only be answered after Esc closes it
	for n in ["PauseMenu", "Toolbox", "PrinterGame", "Cards", "DayReport", "Review", "Computer", "Phone", "Outings"]:  # the order keys reach them: the pause menu, the toolbox and the printer game take every key even over a card
		if _n(n).is_open:
			return n
	if not _n("Expo").seated.is_empty():
		return "Expo session"
	if game.ui_open:
		return "Game.ui_open"
	return ""


# what is open, for a bug report
func describe() -> String:
	var t := tree.current_scene
	var parts: Array = ["scene=" + _scene_name(), "paused=%s" % tree.paused]
	for n in ["Cards", "DayReport", "Review", "Computer", "Phone", "Outings", "Toolbox", "PrinterGame", "PauseMenu"]:
		if _n(n).is_open:
			parts.append(n + " open")
	var pm := _n("PauseMenu")
	if pm.is_open:
		parts.append("pause page=%d confirm=%s capture=%s settings=%s" % [pm._page, pm._confirm, pm._capture, pm.settings_mode])
	var comp := _n("Computer")
	if comp.is_open:
		parts.append("computer app=%s menu=%s mail_view=%s psa_detail=%s close_ask=%s rmm_session=%s rmm_detail=%s tv=%s" % [str(comp.app), str(comp._menu), str(comp.mail_view), str(comp.psa_detail), str(comp.close_ask), str(comp.rmm_session), str(comp.rmm_detail), str(comp.tv_mode)])
	if _n("Review").is_open:
		var rv := _n("Review")
		parts.append("review page=%d opt_page=%d end_page=%d offers=%d ending=%s fade=%f" % [rv.page, rv._opt_page(), rv._end_page(), rv.offers.size(), str(rv.ending), rv._fade])
	if _n("Cards").is_open:
		var cd := _n("Cards")
		parts.append("card age_ms=%d sel=%d options=%s queued=%d" % [Time.get_ticks_msec() - int(cd._opened), cd.sel, str(cd.options.map(func(o: Dictionary) -> String: return "%s%s" % [str(o.id), "" if bool(o.get("enabled", true)) else "(off)"])), cd._queue.size()])
	var ctl := _n("Controls")
	parts.append("capturing=%s typing=%s pad_active=%s focus_lost=%s" % [str(ctl.capturing), str(ctl.typing()), str(ctl.pad_active), str(_n("Game").focus_lost)])
	var o := _n("Outings")
	if o.is_open:
		parts.append("outing game=%s phase=%s" % [str(o.game), str(o.phase)])
	if t != null and t.get("_select") != null:
		var cs: Node = t._select
		parts.append("charselect step=%s flow=%s modal=%s overlay=%s row=%s pad_active=%s touch=%s" % [str(cs.get("step")), str(cs.flow()), str(cs.create_modal), str(cs.overlay), str(cs.create_row), str(_n("Controls").pad_active), str(_n("Controls").touch_on())])
	if _n("Game").ui_open:
		parts.append("ui_open")
	return ", ".join(parts)


func _scene_name() -> String:
	return tree.current_scene.scene_file_path.get_file() if tree.current_scene != null else "none"


# ESC / pad B (the back action) up to 10 times, ENTER / A now and then (a card and the day report need an answer): must end
# in a state with nothing open where a new input has an effect
func recover() -> bool:
	_release_all()
	await wait(2)
	await wait_ms(500)
	var back_presses := 0
	var last := ""
	var same := 0
	for round_n in 24:
		var m := modal()
		if _verbose:
			say("  recover round %d: modal=%s %s" % [round_n, m, describe()])
		if m == "":
			break
		same = same + 1 if m == last else 0
		last = m
		if m in ["Cards", "DayReport", "Review"]:  # these want an answer, not a way out (and ignore input for 0.45 s of real time after they open)
			await wait_ms(470)
			if round_n % 2 == 1:  # the selected row of a card can be a greyed-out one (a mouse hover selects it)
				tap_key(KEY_DOWN)
				await wait(2)
			tap_key(KEY_ENTER)
			await wait(3)
			if modal() == m:
				tap_button(0, JOY_BUTTON_A)
				await wait(3)
			if modal() == m and m == "Cards":
				tap_key(KEY_ESCAPE)  # a card with a leave / close row answers Esc
				await wait(3)
			if _verbose and modal() == m and m == "Cards":
				var before: bool = _n("Cards").is_open
				_n("Cards")._input(_key_event(KEY_ENTER, true, false))
				say("  direct Cards._input(ENTER): open %s -> %s" % [before, _n("Cards").is_open])
		elif m == "Expo session":  # a talk is sat through: Enter skips a line once it has been up for 0.35 s of game time
			await wait(30)
			tap_key(KEY_ENTER)
			await wait(3)
		elif same >= 11 and same % 2 == 1:  # Esc did nothing for a while: a result page may want its Enter
			tap_key(KEY_ENTER)
			await wait(3)
		else:
			if back_presses % 2 == 0 or m == "PauseMenu":
				tap_key(KEY_ESCAPE)
			else:
				tap_button(0, JOY_BUTTON_B)
			back_presses += 1
			await wait(4)
	var left := modal()
	if left != "":
		# last resort the game itself offers: the pause menu's own close, an answer to every card
		_clear_cards()
		await wait(4)
		left = modal()
		if left != "":
			for i in 3:
				tap_key(KEY_ESCAPE)
				await wait(4)
				say("  trace: after another ESC: " + describe())
			_report("softlock", "after %d back presses and answers the screen is still open: %s (%s)" % [back_presses, left, describe()])
			return false
	var game := _n("Game")
	if tree.paused:
		_report("stuck_pause", "the tree is paused with nothing open (focus_lost=%s)" % game.focus_lost)
		tree.paused = false
		return false
	if game.focus_lost:
		_report("stuck_focus", "Game.focus_lost stayed true after the focus came back")
		game.focus_lost = false
	if Engine.time_scale != 1.0:
		_report("time_scale", "Engine.time_scale is %f" % Engine.time_scale)
		Engine.time_scale = 1.0
	if game.busy and _scene_name() != "none":
		await wait(60)
		if game.busy:
			_report("stuck_busy", "Game.busy stayed true (a scene change that never finished)")
			game.busy = false
	# a new input has an effect: ESC opens the pause menu on a floor with a player; on the title it is a no-op, so Enter opens the menu
	if _scene_name().contains("main_floor"):
		if _n("PauseMenu").can_open(true):
			tap_key(KEY_ESCAPE)
			await wait(4)
			if not _n("PauseMenu").is_open:
				_report("dead_input", "ESC did not open the pause menu on a quiet floor (%s)" % describe())
				return false
			tap_key(KEY_ESCAPE)
			await wait(4)
			if _n("PauseMenu").is_open:
				_n("PauseMenu").close()
				_report("dead_input", "ESC did not close the pause menu")
				return false
	elif _scene_name().contains("title"):
		await wait(40)  # a title that has just loaded ignores input for a moment
		var t := tree.current_scene
		if t != null and t.get("_started") == true:  # a run is on its way (GO was pressed): the scene changes in a moment
			await wait(240)
			if not _scene_name().contains("title"):
				return true
			_report("stuck_start", "the title started a run (_started) and is still the scene 4 s later (%s)" % describe())
			return false
		tap_key(KEY_ENTER)
		await wait(4)
		t = tree.current_scene
		if t.get("_menu_open") != true and modal() == "":
			_report("dead_input", "ENTER did nothing on the title prompt (%s)" % describe())
			return false
	return true


func audit_text(tag: String) -> void:
	if not fmt_audit or PixelFont.audit == null:
		return
	var seen: int = PixelFont.audit.size()
	if seen == 0:
		return
	for line in PixelFont.audit_report("%s %s" % [_n("Game").format, tag], false):
		if line.begins_with("OFFSCREEN"):
			_report("offscreen", line)


# ---- one screen ---------------------------------------------------------------------------------------------
# Opens `name`, fuzzes it for `frames` frames with `seed`, checks and recovers. Returns the number of bugs it found.
func fuzz_screen(name: String, seed_value: int, frames: int) -> int:
	_screen = name
	_seed = seed_value
	_recent.clear()
	var before := bugs.size()
	logger.take()
	rng.seed = hash("%s/%d" % [name, seed_value])
	var game := _n("Game")
	coop = _coop_all or name == "floor:coop"
	if fmt_audit:
		game.set_format(["wide", "h", "deck", "v"][rng.randi_range(0, 3)])
	var opened := await open_screen(name)
	_collect_errors()
	if not opened:
		say("SKIP %s" % name)
		return 0
	screens_fuzzed += 1
	say("screen %s seed %d" % [name, seed_value])
	var orphans0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if fmt_audit:
		PixelFont.audit = []
	await wait_ms(480)
	for i in frames:
		_step()
		await tree.process_frame
		if i % 60 == 59:
			_collect_errors()
	_collect_errors()
	if fmt_audit and modal() != "":
		await wait(3)
		audit_text("end of burst")
	if fmt_audit:
		PixelFont.audit = null
	await recover()
	await wait(3)
	_collect_errors()
	var orphans1 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans1 - orphans0 > 60:
		_report("orphans", "orphan nodes grew by %d in one burst (%d -> %d)" % [orphans1 - orphans0, orphans0, orphans1])
	game.set_format("wide")
	game.set_text_large(false)
	game.set_high_contrast(false)
	return bugs.size() - before


# ---- sequences ----------------------------------------------------------------------------------------------
# start a campaign, play `frames` frames of random input, quit to the title through the pause menu, CONTINUE it
func sequence_campaign(mode: String, seed_value: int, frames: int) -> int:
	_screen = "sequence:campaign:" + mode
	_seed = seed_value
	_recent.clear()
	var before := bugs.size()
	logger.take()
	rng.seed = hash("%s/%d" % [_screen, seed_value])
	var who: String = {"tech": "office_intern", "owner": "office_alan", "sales": "office_john", "service": "office_dan"}.get(mode, "office_intern")
	await _new_floor(mode, who)
	_n("Msp").enabled = true
	_n("Shift").enabled = true
	await wait_ms(480)
	var camp := _n("Campaign")
	for i in frames:
		_step()
		await tree.process_frame
		if i % 60 == 59:
			_collect_errors()
	_collect_errors()
	await recover()
	# quit to the title through the pause menu (what the QUIT TO TITLE row does)
	var day_before: int = camp.day
	camp.snapshot()
	var pm := _n("PauseMenu")
	if pm.can_open(true):
		pm.open()
		pm._sel = pm._labels().size() - 1
		pm._activate()
		pm._sel = 1
		pm._activate()
	else:
		_n("Game").go_title()
	await wait(40)
	_collect_errors()
	if tree.current_scene == null or not _scene_name().contains("title"):
		_report("quit_to_title", "the scene after quit is %s" % _scene_name())
	else:
		var t := tree.current_scene
		t._open_menu()
		var cont := -1
		for i in t._items.size():
			if str(t._items[i].get("id", "")) == "continue":
				cont = i
		if cont < 0:
			say("NOTE %s: no CONTINUE row after quit (no resume point written; overtime or a save refused)" % _screen)
		else:
			t._choose(cont)
			await wait(4)
			if t.get("_items") != null and t._items.size() > 0:
				t._choose(0)
			await wait(120)
			_collect_errors()
			if _scene_name().contains("title"):
				_report("continue", "CONTINUE did not reach the floor (scene %s)" % _scene_name())
			elif not camp.active:
				_report("continue", "CONTINUE reached the floor with no campaign running")
			elif camp.day < day_before - 1:
				_report("continue", "CONTINUE lost days: %d -> %d" % [day_before, camp.day])
			else:
				await recover()
	return bugs.size() - before
