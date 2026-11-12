extends Node2D
# Title screen. A few vignettes rotate behind the MSPSim logo: the cast lined up in the office, two
# people on the phones at their desks, coffee and the fridge in the kitchenette, and a meeting in
# the conference room. Each one is the real room scene in "title mode" (no player, no World cast)
# with NPC nodes acting it out. Enter / Space / E / a click starts the game; F9 cycles the output
# format. The office clock is frozen until you start.

const NPC_SCENE := preload("res://scenes/npc.tscn")
const LOGO := preload("res://assets/ui/mspsim_logo.png")
const LOGO_SMALL := preload("res://assets/ui/mspsim_logo_s.png")
const PROMPT := preload("res://assets/ui/press_start.png")
const PixelFont := preload("res://scripts/pixelfont.gd")
const CharSelect := preload("res://scripts/charselect.gd")
const Micro := preload("res://scripts/micro.gd")  # R16: the QUICK PLAY micro-sessions
const FLOOR_Y := 118.0
const SHOW_SECS := 9.0
const VIGNETTES := ["lineup", "phones", "kitchen", "conference"]
const ROOMS := {
	"lineup": "main_floor",
	"phones": "cubicle_area",
	"kitchen": "kitchenette",
	"conference": "conference"
}

const CONTINUE_ROWS := 6  # the CONTINUE list shows this many saves at once and scrolls with the cursor
const MODE_NAMES := {
	"tech": "TECH CAMPAIGN",
	"owner": "OWNER CAMPAIGN",
	"service": "SERVICE MANAGER",
	"sales": "SALES"
}

var _cam: Camera2D
var _logo: Sprite2D
var _prompt: Sprite2D
var _fade: ColorRect
var _room: Node = null
var _index := 0
var _t := 0.0
var _busy := false
var _started := false
var _hud_was := true
var _menu_open := false
var _sel := 0
var _items: Array = []
# "home" (CONTINUE / NEW / FREE PLAY / SETTINGS / QUIT), "cont" (every save, newest first), "top" (NEW: the campaigns), "sub" (a campaign's submenu),
# "slot" (CONTINUE / FROM THE START of one slot), "over" (which slot to overwrite) or "del"
var _level := "home"
var _from_cont := false  # the slot being opened was picked from the CONTINUE list, so back returns there
var _sub_mode := ""
var _top_sel := 0  # the top-menu cursor to come back to
var _sub_sel := 0  # the submenu cursor to come back to
var _scroll := 0  # the first visible row of a long CONTINUE list (set while drawing)
var _slot := 1  # the save slot the next start uses (R19)
var _overwrite := false  # the next new run replaces a full slot (its save is deleted when the run starts)
var _over_id := ""  # the new-run row (tech_new / tech_y2) waiting for the slot to overwrite
var _heading := ""
var _menu: Node2D
var _front: CanvasLayer
var _select: Node2D = null  # the character select screen while it is open
var _career: Node = null  # the career screen while it is open


func _ready() -> void:
	World.time_scale = 0.0
	_hud_was = World.hud_visible
	World.hud_visible = false
	Game.title_mode = true
	_cam = Camera2D.new()
	add_child(_cam)
	var back := CanvasLayer.new()
	back.layer = 10
	add_child(back)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.04, 0.08, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_fade)
	var front := CanvasLayer.new()
	front.layer = 20
	add_child(front)
	_front = front
	_logo = Sprite2D.new()
	_logo.centered = false
	front.add_child(_logo)
	_prompt = Sprite2D.new()
	_prompt.centered = false
	_prompt.texture = PROMPT
	front.add_child(_prompt)
	var blink := Timer.new()
	blink.wait_time = 0.55
	blink.autostart = true
	blink.timeout.connect(func() -> void: _prompt.visible = not _prompt.visible and not _menu_open)
	add_child(blink)
	_menu = Node2D.new()
	_menu.visible = false
	front.add_child(_menu)
	_menu.draw.connect(_draw_menu)
	Game.format_changed.connect(_on_format)
	Difficulty.load_settings()
	Look.load_settings()
	Sfx.settings_changed.connect(_menu.queue_redraw)
	Sfx.play_music("title")
	show_vignette(0)


func _on_format() -> void:
	show_vignette(_index)


func _size() -> Vector2:
	return Vector2(Game.FORMATS[Game.format].size)


func _layout() -> void:
	var size := _size()
	var wide := size.x > 340.0 and size.y <= 130.0
	var narrow := size.x < 250.0
	var cam_y := 64.0 if size.y <= 130.0 else (50.0 if size.y <= 200.0 else 60.0)
	var cam_x := 184.0
	if VIGNETTES[_index] == "phones" and narrow:
		cam_x = 117.0  # the two desks
	_cam.zoom = Vector2.ONE
	_cam.position = Vector2(cam_x, cam_y)
	_logo.texture = LOGO_SMALL if narrow else LOGO
	var top := 4.0 if wide else (14.0 if not narrow else 24.0)
	_logo.position = Vector2(floorf((size.x - _logo.texture.get_width()) * 0.5), top)
	var pw := float(PROMPT.get_width())
	var ph := float(PROMPT.get_height())
	if wide:
		_prompt.position = Vector2(size.x - pw - 8.0, size.y - ph - 3.0)
	else:
		_prompt.position = Vector2(
			floorf((size.x - pw) * 0.5), size.y - ph - (17.0 if not narrow else 40.0)
		)


# build vignette number i (no fade; used at start, on a format change and by tests)
func show_vignette(i: int) -> void:
	_index = i % VIGNETTES.size()
	_t = 0.0
	if _room != null:
		remove_child(_room)
		_room.queue_free()
	var kind: String = VIGNETTES[_index]
	_room = load("res://scenes/%s.tscn" % ROOMS[kind]).instantiate()
	add_child(_room)
	_act(kind)
	_layout()


func _npc(who: String, facing: String, x: float, routine: Array, seat := "", item := "") -> void:
	var npc: Node = NPC_SCENE.instantiate()
	npc.character = who
	npc.facing = facing
	npc.routine = PackedStringArray(routine)
	npc.start_seat = seat
	npc.start_item = item
	npc.position = Vector2(x, FLOOR_Y)
	_room.get_node("Actors").add_child(npc)


func _act(kind: String) -> void:
	var data: Dictionary = World.DATA.SCENES[ROOMS[kind]]
	match kind:
		"lineup":
			var size := _size()
			var wide := size.x > 340.0 and size.y <= 130.0
			var narrow := size.x < 250.0
			var xs := (
				[150.0, 184.0, 218.0, -1.0]
				if narrow
				else ([128.0, 168.0, 208.0, -1.0] if wide else [142.0, 182.0, 270.0, 310.0])
			)
			var gap := ["talk:4", "wait:3"]
			_npc("casual_garrison", "left", xs[0], gap)
			_npc("office_alan", "right", xs[1], gap)
			_npc("office_dan", "left", xs[2], ["wait:3", "say:2", "wait:4"])
			if xs[3] >= 0.0:
				_npc("office_adult", "right", xs[3], ["wait:30"])
		"phones":
			_npc("casual_garrison", "right", data.seats.Seat1, ["wait:60"], "Seat1", "coffee")
			_npc("office_dan", "right", data.seats.Seat2, ["wait:60"], "Seat2")
			var phones := get_tree().get_nodes_in_group("phones")
			for i in phones.size():
				var zone: Node = phones[i]
				get_tree().create_timer(1.2 + 2.2 * i).timeout.connect(_ring.bind(zone))
		"kitchen":
			var u: Dictionary = data.uses
			_npc(
				"office_dan",
				"right",
				u.fridge + 40.0,
				[
					"walk:%d" % (u.fridge + 8),
					"use:fridge",
					"wait:1",
					"sip",
					"wait:4",
					"sip",
					"wait:2"
				]
			)
			_npc(
				"office_alan",
				"left",
				u.coffee + 40.0,
				[
					"walk:%d" % (u.coffee + 20),
					"use:coffee",
					"wait:1",
					"sip",
					"wait:4",
					"sip",
					"wait:3"
				]
			)
			_npc(
				"casual_garrison",
				"left",
				u.coffee + 70.0,
				["wait:2", "talk:5", "wait:2", "talk:4", "wait:1"]
			)
		"conference":
			var s: Dictionary = data.seats
			_npc(
				"office_dan",
				"right",
				s.Seat1,
				["wait:1", "say:3", "wait:4", "say:2"],
				"Seat1",
				"coffee"
			)
			_npc(
				"office_alan",
				"right",
				s.Seat2,
				["wait:4", "say:3", "wait:2", "say:3"],
				"Seat2",
				"soda"
			)
			_npc(
				"casual_garrison",
				"right",
				s.Seat3,
				["wait:2", "say:2", "wait:5", "say:2"],
				"Seat3",
				"bottle"
			)


func _ring(zone: Variant) -> void:
	if is_instance_valid(zone):
		var fx: Node = zone.get_node(zone.target)
		if not fx.busy:
			fx.ringing = true
			fx._ring_until = fx._time + 20.0


func _process(delta: float) -> void:
	if _busy or _started:
		return
	_t += delta
	if _t >= SHOW_SECS:
		_rotate()


func _rotate() -> void:
	_busy = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: show_vignette(_index + 1))
	tween.tween_property(_fade, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: _busy = false)


func _unhandled_input(event: InputEvent) -> void:
	if _started or _select != null or _career != null:
		return
	var go := false
	if Controls.pressed(event):
		if Controls.word(event) == "f9":
			Game.cycle_format()
			_menu.queue_redraw()
		go = Controls.confirm(event)
		if _menu_open:
			_menu_key(event, go)
			return
	elif event is InputEventMouseMotion and _menu_open:
		_hover(event.position)
		return
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		go = true
		if _menu_open:
			if _hover(event.position):
				_choose(_sel)
			return
	if go:
		_open_menu()


func _menu_key(event: InputEvent, confirm: bool) -> void:
	var dir := Controls.nav(event, false)
	if dir == "up":
		_move(-1)
	elif dir == "down":
		_move(1)
	elif confirm:
		_choose(_sel)
	elif Controls.back(event, false):
		_back()


# Esc / back / pad B: the slot and overwrite lists return to the submenu, a submenu returns to the top menu (cursor
# kept), the top menu closes
func _back() -> void:
	if _level == "slot" and _from_cont:
		_show_continue()
	elif _level == "slot" or _level == "over" or _level == "del":
		_show_sub(_sub_mode, _sub_sel)
	elif _level == "sub":
		_show_top(_top_sel)
	elif _level == "cont" or _level == "top" or _level == "quick":
		_show_home(0)
	else:
		_menu_open = false
		_menu.visible = false


func _open_menu() -> void:
	_show_home(0)
	_menu_open = true
	_prompt.visible = false
	_menu.visible = true
	_menu.queue_redraw()


# R40: the home lines. CONTINUE (only when something is saved) lists every save of every mode, newest first; NEW
# opens the four campaigns; FREE PLAY goes straight to its character select; SETTINGS is the pause menu's pages (the medals
# screen is a row there)
func _show_home(sel: int) -> void:
	_level = "home"
	_from_cont = false
	_sub_mode = ""
	_heading = ""
	_items = []
	if not Campaign.all_slots().is_empty():
		_items.append({"label": "CONTINUE", "id": "continue", "enabled": true})
	_items.append({"label": "NEW", "id": "play", "enabled": true})
	_items.append({"label": "FREE PLAY", "id": "free", "enabled": true})
	_items.append({"label": "QUICK PLAY", "id": "quick", "enabled": true})
	_items.append({"label": "SETTINGS", "id": "settings", "enabled": true})
	_items.append({"label": "QUIT", "id": "quit", "enabled": true})
	_sel = clampi(sel, 0, _items.size() - 1)
	_menu.queue_redraw()


# R16: QUICK PLAY, the micro-sessions (Micro): one outing or one short ticket shift on Free Play, no character select
func _show_quick() -> void:
	_level = "quick"
	_from_cont = false
	_sub_mode = ""
	_heading = "QUICK PLAY"
	_items = [
		{"label": "ONE OUTING", "id": "micro_outing", "enabled": true},
		{"label": "ONE TICKET SHIFT", "id": "micro_tickets", "enabled": true},
	]
	_sel = 0
	_menu.queue_redraw()


# NEW: the four campaigns (Free Play has its own home line)
func _show_top(sel: int) -> void:
	_level = "top"
	_from_cont = false
	_sub_mode = ""
	_heading = "NEW"
	_items = []
	for mode in MODE_NAMES:
		_items.append({"label": MODE_NAMES[mode], "id": mode, "enabled": Campaign.is_selectable(mode)})
	_sel = clampi(sel, 0, _items.size() - 1)
	_menu.queue_redraw()


# "SALES SLOT 2 - DAY 7  12:30 - JAMIE": one line per save, newest first; the list scrolls past CONTINUE_ROWS rows
func continue_items() -> Array:
	var out := []
	for entry in Campaign.all_slots():
		var mode := str(entry.mode)
		var n := int(entry.slot)
		var label := slot_label(mode, n, entry.info as Dictionary, str(mode).to_upper() + " SLOT")
		out.append({"label": label, "id": "cont_%s_%d" % [mode, n], "enabled": true})
	return out


func _show_continue() -> void:
	_level = "cont"
	_from_cont = false
	_sub_mode = ""
	_heading = "CONTINUE"
	_items = continue_items()
	_sel = 0
	_menu.queue_redraw()


func _unit(mode: String) -> String:
	return "WEEK" if mode == "owner" or mode == "sales" else "DAY"


# "SLOT 2 - DAY 7  12:30 (YEAR 2) - JAMIE": the character name goes first when the line is too wide for the format
func slot_label(mode: String, n: int, info: Dictionary, lead := "SLOT") -> String:
	var label := "%s %d - %s %d" % [lead, n, _unit(mode), int(info.day)]
	if str(info.text) != "":
		label += "  " + str(info.text)
	label += str(info.tag)
	var named := label + " - " + str(info.character_name)
	if str(info.character_name) != "" and float(PixelFont.width(named)) + 14.0 <= _size().x:
		return named
	return label


# the rows of a campaign submenu: one row per existing save slot, START YEAR 2 (that mode's Year 1 is finished),
# NEW CAMPAIGN (the lowest empty slot, or a question which full slot to overwrite)
func sub_items(mode: String) -> Array:
	var out := []
	var saved := 0
	for n in range(1, Campaign.SLOTS + 1):
		var info: Dictionary = Campaign.slot_info(mode, n)
		if bool(info.exists):
			saved += 1
			out.append({"label": slot_label(mode, n, info), "id": "%s_slot%d" % [mode, n], "enabled": true})
	if Yeartwo.available(mode):
		var carry := Yeartwo.carry_summary(mode)
		out.append({"label": "START YEAR 2" + (" - " + carry if carry != "" else ""), "id": mode + "_y2", "enabled": true})  # R17
	if Yeartwo.available(mode, 3):  # R10: the last chapter, after a finished Year 2
		var carry3 := Yeartwo.carry_summary(mode, 3)
		out.append({"label": "START YEAR 3" + (" - " + carry3 if carry3 != "" else ""), "id": mode + "_y3", "enabled": true})
	out.append({"label": "NEW CAMPAIGN", "id": mode + "_new", "enabled": true})
	if saved > 0:
		out.append({"label": "DELETE A SLOT", "id": mode + "_delask", "enabled": true})  # R19
	return out


# R19: which slot to delete (a row opens the question; nothing is erased until YES)
func del_items(mode: String) -> Array:
	var out := []
	for n in range(1, Campaign.SLOTS + 1):
		var info: Dictionary = Campaign.slot_info(mode, n)
		if bool(info.exists):
			out.append({"label": slot_label(mode, n, info, "DELETE SLOT"), "id": "%s_del%d" % [mode, n], "enabled": true})
	out.append({"label": "CANCEL", "id": "cancel", "enabled": true})
	return out


func _show_delete_list(mode: String) -> void:
	_sub_sel = _sel
	_level = "del"
	_heading = "DELETE WHICH SLOT?"
	_items = del_items(mode)
	_sel = _items.size() - 1  # the cursor starts on CANCEL
	_menu.queue_redraw()


func _confirm_delete(mode: String, n: int) -> void:
	_level = "del"
	_heading = "ERASE SLOT %d FOR GOOD?" % n
	_items = [
		{"label": "YES, DELETE SLOT %d" % n, "id": "%s_delyes%d" % [mode, n], "enabled": true},
		{"label": "KEEP IT", "id": "cancel", "enabled": true},
	]
	_sel = 1
	_menu.queue_redraw()


# the rows after picking a slot that holds both a mid-day resume point and a day-start save
func slot_items(mode: String, n: int) -> Array:
	var info: Dictionary = Campaign.slot_info(mode, n)
	var unit := _unit(mode)
	return [
		{"label": "CONTINUE - %s %d  %s" % [unit, int(info.day), str(info.text)] + str(info.tag), "id": mode + "_resume", "enabled": true},
		{"label": "%s %d FROM THE START" % [unit, int(info.day)] + str(info.tag), "id": mode + "_continue", "enabled": true},
	]


# every slot is full: which one does the new run replace? (the row itself is the confirmation; CANCEL keeps all three)
func over_items(mode: String) -> Array:
	var out := []
	for n in range(1, Campaign.SLOTS + 1):
		var info: Dictionary = Campaign.slot_info(mode, n)
		out.append({"label": slot_label(mode, n, info, "OVERWRITE SLOT"), "id": "%s_over%d" % [mode, n], "enabled": true})
	out.append({"label": "CANCEL", "id": "cancel", "enabled": true})
	return out


func _show_sub(mode: String, sel: int) -> void:
	_level = "sub"
	_sub_mode = mode
	_heading = str(MODE_NAMES[mode])
	_items = sub_items(mode)
	_sel = clampi(sel, 0, _items.size() - 1)
	_menu.queue_redraw()


# a campaign line: its submenu, or straight to the new-run flow when NEW CAMPAIGN is all it could offer (slot 1)
func _enter_mode(mode: String) -> void:
	var rows := sub_items(mode)
	if rows.size() == 1:
		_slot = 1
		_overwrite = false
		_open_select(mode + "_new")
		return
	_top_sel = _sel
	_show_sub(mode, 0)


# a saved slot was picked: CONTINUE / FROM THE START when it has both kinds of save, else straight in
func _enter_slot(mode: String, n: int) -> void:
	var info: Dictionary = Campaign.slot_info(mode, n)
	_slot = n
	_overwrite = false
	if bool(info.has_resume) and bool(info.has_save):
		_sub_sel = _sel
		_level = "slot"
		_heading = "SLOT %d" % n
		_items = slot_items(mode, n)
		_sel = 0
		_menu.queue_redraw()
	else:
		_start(mode + ("_resume" if bool(info.has_resume) else "_continue"))


# NEW CAMPAIGN / START YEAR 2: the lowest empty slot at once, or the overwrite question when all are full
func _begin_new(id: String) -> void:
	var mode := id.get_slice("_", 0)
	var n := Campaign.first_empty_slot(mode)
	if n > 0:
		_slot = n
		_overwrite = false
		_open_select(id)
		return
	_sub_sel = _sel
	_over_id = id
	_level = "over"
	_heading = "OVERWRITE WHICH SLOT?"
	_items = over_items(mode)
	_sel = 0
	_menu.queue_redraw()


func _move(step: int) -> void:
	var i := _sel
	for _n in _items.size():
		i = (i + step + _items.size()) % _items.size()
		if _items[i].enabled:
			_sel = i
			break
	_menu.queue_redraw()


func _hover(at: Vector2) -> bool:
	for i in _items.size():
		if _items[i].enabled and _items[i].get("rect", Rect2()).has_point(at):
			_sel = i
			_menu.queue_redraw()
			return true
	return false


# the home menu and CONTINUE list rows; true when the id was one of them
func _choose_home(id: String) -> bool:
	if id == "quit":
		get_tree().quit()
	elif id == "settings":
		PauseMenu.open_settings()
	elif id == "continue":
		_top_sel = _sel
		_show_continue()
	elif id == "play":
		_top_sel = _sel
		_show_top(0)
	elif id == "quick":
		_top_sel = _sel
		_show_quick()
	elif id.begins_with("micro_"):
		_start(id)
	elif id.begins_with("cont_"):
		var mode := id.get_slice("_", 1)
		_sub_mode = mode
		_enter_slot(mode, int(id.get_slice("_", 2)))
		_from_cont = _level == "slot"
	else:
		return false
	return true


func _choose(i: int) -> void:
	if i < 0 or i >= _items.size() or not _items[i].enabled:
		return
	var id := str(_items[i].id)
	if id == "career":
		_open_career()
		return
	if _choose_home(id):
		return
	if MODE_NAMES.has(id):
		_enter_mode(id)
		return
	if id == "cancel":
		_back()
	elif id.ends_with("_delask"):
		_show_delete_list(id.get_slice("_", 0))
	elif "_delyes" in id:
		Campaign.delete_slot(id.get_slice("_", 0), int(id.get_slice("_delyes", 1)))
		_show_sub(_sub_mode, 0)
	elif "_del" in id:
		_confirm_delete(id.get_slice("_", 0), int(id.get_slice("_del", 1)))
	elif "_slot" in id:
		_enter_slot(id.get_slice("_", 0), int(id.get_slice("_slot", 1)))
	elif "_over" in id:
		_slot = int(id.get_slice("_over", 1))
		_overwrite = true
		_open_select(_over_id)
	elif id.ends_with("_new") or id.ends_with("_y2") or id.ends_with("_y3"):
		_begin_new(id)
	elif id.ends_with("_continue") or id.ends_with("_resume"):
		_start(id)  # a saved run keeps its character: no select screen
	else:
		_open_select(id)


func _open_career() -> void:
	if _career != null:
		return
	_logo.visible = false
	_menu.visible = false
	_career = Career.open_screen(_close_career)


func _close_career() -> void:
	_career = null
	_logo.visible = true
	_menu.visible = _menu_open
	_menu.queue_redraw()


# new runs pick their character (and, in the tech campaign, their phone) first
func _open_select(id: String) -> void:
	if _select != null:
		return
	var year := 3 if id.ends_with("_y3") else 2  # START YEAR 3 (R10): the same screen, the last chapter
	var year2 := id.ends_with("_y2") or id.ends_with("_y3")  # New Game Plus (Yeartwo): the same screen with the MUT chip
	if year2:
		id = id.trim_suffix("_y2").trim_suffix("_y3") + "_new"
	var mode := Campaign.FREE
	if id == "tech_new":
		mode = "tech"
	elif id == "owner_new":
		mode = "owner"
	elif id == "service_new":
		mode = "service"
	elif id == "sales_new":
		mode = "sales"
	_select = CharSelect.new()
	_select.setup(mode, year2, year)
	_select.done.connect(_on_select_done.bind(id))
	_select.cancelled.connect(_close_select)
	_front.add_child(_select)
	_logo.visible = false
	_menu.visible = false


func _close_select() -> void:
	Yeartwo.pending = false
	if _select == null:
		return
	_select.queue_free()
	_select = null
	_logo.visible = true
	_menu.visible = _menu_open
	_menu.queue_redraw()


func _on_select_done(result: Dictionary, id: String) -> void:
	if _select == null:
		return  # a second GO in the same frame (a double click, Enter twice): the run is already starting
	_select.queue_free()
	_select = null
	_start(id, str(result.summary))


func _start(id: String, summary := "") -> void:
	_started = true
	World.time_scale = 1.0
	World.hud_visible = _hud_was
	Game.title_mode = false
	Shift.enabled = true
	Outings.enabled = true
	Onsite.enabled = true
	Net.cable_faults = true  # R37: loose patch cables in the tech campaign (tests start campaigns without them)
	Outings.use_rooms = true
	var run_mode := id.get_slice("_", 0)
	Campaign.slot = _slot if Campaign.MODES.has(run_mode) else 1
	if _overwrite and id.ends_with("_new"):
		Campaign.delete_slot(run_mode, _slot)  # the chosen full slot is replaced now, not when the first day ends
	_overwrite = false
	match id:
		"tech_new":
			Campaign.new_game("tech")
		"tech_continue":
			Campaign.continue_game("tech")
		"tech_resume":
			Campaign.continue_game("tech", true)
		"owner_new":
			Campaign.new_game("owner")
		"owner_resume", "service_resume", "sales_resume":
			Campaign.continue_game(run_mode, true)  # R16 step 5: every campaign has a mid-day / mid-week point
		"owner_continue":
			Campaign.continue_game("owner")
		"service_new":
			Campaign.new_game("service")
		"service_continue":
			Campaign.continue_game("service")
		"sales_new":
			Campaign.new_game("sales")
		"sales_continue":
			Campaign.continue_game("sales")
		_:
			Campaign.new_game(Campaign.FREE)
	Game.go(Campaign.start_scene(), "start")
	if id.begins_with("micro_"):
		Micro.begin(id.trim_prefix("micro_"))  # sets up the toolbox launch or the ticket shift
	else:
		Micro.clear()
	Toolbox.after_start()
	if summary != "":
		var wide_enough: bool = Game.FORMATS[Game.format].size.x >= 300
		Hints.toast(summary + ("  COZY" if Difficulty.cozy_on() else "") + ("  RUN " + Difficulty.seed_text() if wide_enough else ""), 4.0)


# the first visible row of a CONTINUE list that shows CONTINUE_ROWS at once and keeps the cursor on the last visible row
func scroll_for(sel: int, count: int) -> int:
	return clampi(sel - CONTINUE_ROWS + 1, 0, maxi(0, count - CONTINUE_ROWS))


func _draw_menu() -> void:
	var size := _size()
	var y := _logo.position.y + float(_logo.texture.get_height()) + 7.0
	# one column; the rows (and the heading of a submenu) squeeze to stay on screen
	var avail := size.y - 1.0 - y
	var shown := _items.size()
	_scroll = 0
	if _level == "cont" and shown > CONTINUE_ROWS:
		shown = CONTINUE_ROWS
		_scroll = scroll_for(_sel, _items.size())
	var rows := shown + (1 if _heading != "" else 0)
	# R14 (5): the tall format has the room for thumb-sized rows (19 px); the others keep the 8 to 10 px rows
	var pitch := clampf(floorf(avail / float(maxi(1, rows))), 8.0, 20.0 if size.y > size.x else 10.0)
	var ty := floorf((pitch - 1.0 - 5.0) * 0.5)
	if _heading != "":
		var hw := float(PixelFont.width(_heading)) + 12.0
		var hr := Rect2(floorf((size.x - hw) * 0.5), y, hw, pitch - 1.0)
		_menu.draw_rect(hr, Color(0.05, 0.07, 0.12, 0.95))
		PixelFont.draw(_menu, _heading, hr.position + Vector2(6, ty), Color("f5d442"))
		y += pitch
	for i in _items.size():
		var item: Dictionary = _items[i]
		if i < _scroll or i >= _scroll + shown:
			item["rect"] = Rect2()  # scrolled out of the window
			continue
		var label: String = item.label
		var w := float(PixelFont.width(label)) + 12.0
		var r := Rect2(floorf(size.x * 0.5 - w * 0.5), y + float(i - _scroll) * pitch, w, pitch - 1.0)
		item["rect"] = r
		var chosen: bool = i == _sel and item.enabled
		var back := Color("f5d442") if chosen else Color(0.05, 0.07, 0.12, 0.8)
		var ink := Color("17121f") if chosen else (Color.WHITE if item.enabled else Color("7d8595"))
		_menu.draw_rect(r, back)
		PixelFont.draw(_menu, label, r.position + Vector2(6, ty), ink)
	var sound := Sfx.status_text() + Controls.keys("  {M}")
	var sound_x := size.x - float(PixelFont.width(sound)) - 4.0
	_menu.draw_rect(Rect2(sound_x - 2.0, 1.0, float(PixelFont.width(sound)) + 5.0, 9.0), Color(0.04, 0.03, 0.08, 0.5))  # grey on the ceiling tiles did not read
	PixelFont.draw(_menu, sound, Vector2(sound_x, 3.0), Color("c8cede"))
