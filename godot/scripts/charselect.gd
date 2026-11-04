extends Node2D
# gdlint:disable=max-returns
# Character select / first-day screen, shown by the title menu before a new run starts. A row of
# the playable characters (a carousel in narrow portrait) with an idle preview, a name and a short
# blurb; the tech campaign then asks for your phone. Left / Right move, Enter / E / Space confirm,
# Esc goes back, mouse hover and click work like the title menu. Confirming applies the choice
# (Player.current_character, Phone.os) and emits done(result); Esc on the first step emits
# cancelled. In the campaigns the cast members (Alan, Garrison, Dan, Vic ...) are already at
# their desks as NPCs, so the tech campaign offers only the people who are not in World.CAST; the
# owner campaign offers Alan or Garrison (the other owner becomes your partner NPC); Free Play offers
# everyone. Whoever you pick as a cast member leaves the cast and sits at their own desk (Campaign.player_as).

signal done(result: Dictionary)
signal cancelled
signal look_changed  # the create step changed the look (the outfit overlay wears it on the player at once)

const PixelFont := preload("res://scripts/pixelfont.gd")
const PLAYER := preload("res://scripts/player.gd")
const BuildPanel := preload("res://scripts/build_panel.gd")
const GOLD := Color("f5d442")
const INK := Color("17121f")
const PANEL := Color(0.05, 0.07, 0.12, 0.85)
const DIM := Color("9aa8c0")
const FREE_MODE := "free"
const CUSTOM := "custom"  # the MAKE YOUR OWN card: the Look.BASE sheet in the player's own colours (R15, level 1)
# The create step's pages and rows are DATA (R15 level 3): a page is {id, label, rows}, a row {kind, label, id}. Kinds:
# "name" (the text box: typed, or the pad's letter grid), "choice" (a list in Look.CHOICES[id], < > chips), "swatch" (the
# colours of Look.SWATCHES[id]) and "acc" (an accessory slot of Look.ACC_STYLES: none first, only the styles that are unlocked,
# "N LOCKED" beside the chips; Look.cycle_acc). A new option is ONE line here plus its list; a page with no rows has no tab
# (a page's `empty` text shows only if one is ever reached). Wide fits tabs + 5 rows + the bottom row, so EXTRAS and WORK hold three each.
const CREATE_PAGES := [
	{
		"id": "look",
		"label": "LOOK",
		"rows":
		[
			{"kind": "name", "label": "NAME"},
			{"kind": "choice", "id": "hair_style", "label": "STYLE"},
			{"kind": "swatch", "id": "skin", "label": "SKIN"},
			{"kind": "swatch", "id": "hair", "label": "HAIR"},
		],
	},
	{
		"id": "clothes",
		"label": "CLOTHES",
		"rows":
		[
			{"kind": "choice", "id": "shirt_style", "label": "TOP"},
			{"kind": "swatch", "id": "shirt", "label": "SHIRT"},
			{"kind": "choice", "id": "pattern", "label": "PATTERN"},
			{"kind": "choice", "id": "bottom", "label": "BOTTOM"},
			{"kind": "swatch", "id": "pants", "label": "PANTS"},
		],
	},
	{
		"id": "shoes",
		"label": "SHOES",
		"rows":
		[
			{"kind": "choice", "id": "shoe_style", "label": "SHOES"},
			{"kind": "swatch", "id": "shoes", "label": "COLOR"},
		],
	},
	{
		"id": "extras",
		"label": "EXTRAS",
		"empty": "NOTHING HERE YET",
		"rows":
		[
			{"kind": "acc", "id": "glasses", "label": "GLASSES"},
			{"kind": "acc", "id": "beard", "label": "BEARD"},
			{"kind": "acc", "id": "hat", "label": "HAT"},
		],
	},
	{
		"id": "work",
		"label": "WORK",
		"empty": "NOTHING HERE YET",
		"rows":
		[
			{"kind": "acc", "id": "badge", "label": "NAMETAG"},
			{"kind": "acc", "id": "lanyard", "label": "LANYARD"},
			{"kind": "acc", "id": "watch", "label": "WATCH"},
		],
	},
]
const CREATE_ACTIONS := ["random", "presets", "done"]  # the bottom row: RANDOM | PRESETS | DONE
# The mirror preview (R15 level 3 step e): the preview person cycles these poses [animation, label], POSE_SECS each, so every overlay
# (glasses, beard, hat, nametag, lanyard, watch) and the palette can be judged in motion and seated. TAB (pad Y) holds the pose, < > or
# , . step it (and hold it), a click on the person holds it, a click on the label chips steps it. The seated gestures are one-shots: a
# held or long pose replays them.
const POSES := [
	["idle", "IDLE"],
	["walk", "WALK"],
	["wave", "WAVE"],
	["sit", "SIT"],
	["type", "TYPE"],
	["sitstretch", "STRETCH"],
	["sitscratch", "SCRATCH"],
	["sitlook", "LOOK"],
	["sityawn", "YAWN"],
	["sitnod", "NOD"],
	["sitphone", "PHONE"],
	["sitmouse", "MOUSE"],
	["sitslump", "SLUMP"],
	["toss", "TOSS"],
]
const POSE_SECS := 2.4
const GRID_COLS := 9  # the pad's letter grid
const CUSTOM_BLURB := "CHOOSE LOOK AND CLOTHES ON THE PAGES, THEN A NAME. A NEW HIRE, NOT ONE OF THE TEAM."
const PEOPLE := {
	"office_intern":
	{
		"name": "INTERN",
		"blurb": "FRESH HIRE WITH LONG HAIR AND BIG PLANS. LEARNS FAST, SPILLS COFFEE."
	},
	"office_adult":
	{"name": "ADULT", "blurb": "SEASONED TECH IN A MAROON POLO. HAS REBOOTED EVERY XP BOX TWICE."},
	"office_dan":
	{"name": "DAN", "blurb": "CALM IN A BLUE SHIRT AND GLASSES. NETWORKS ARE HIS THING."},
	"office_alan":
	{"name": "ALAN", "blurb": "CO-OWNER IN A RED SHIRT AND GREEN VEST. SERVER ROOM REGULAR, WATCHES THE BACKUPS."},
	"site_alan":
	{
		"name": "ALAN - ON SITE",
		"blurb": "ALAN IN THE GRAY WORK POLO. VAN KEYS, CABLE TESTER, NO TIME TO CHAT."
	},
	"casual_garrison":
	{
		"name": "GARRISON",
		"blurb": "CO-OWNER IN TEAL PLAID AND A GOATEE. CLIENTS AND CULTURE, ALWAYS TIME FOR A CHAT."
	},
	"sales_vic":
	{
		"name": "VIC",
		"blurb": "ACCOUNT MANAGER IN A JACKET AND RED TIE. A DEAL IS ALWAYS ABOUT TO CLOSE."
	},
}
# the owner campaign shows these instead of the Free Play blurbs
const OWNER_BLURBS := {
	"office_alan":
	"TECH OWNER: SERVERS, BACKUPS, THE STACK. GARRISON KEEPS CLIENTS HAPPY.",
	"casual_garrison":
	"SALES OWNER: CLIENTS, PRICING, MORALE. ALAN KEEPS THE SERVERS ALIVE.",
}
# the sales campaign offers Vic only
const SALES_BLURB := "THE ACCOUNT MANAGER. YOU SELL, DAN AND MORGAN DELIVER. SELL ONLY WHAT THEY CAN DELIVER AND HIT QUOTA BY JUNE 30."
# the service manager campaign offers Dan only
const SERVICE_BLURBS := {
	"office_dan": "THE QUIET NETWORK TECH WHO LABELS EVERYTHING, PROMOTED TO RUN THE DESK. LABEL THE PEOPLE NOW.",
}
const PHONES := [
	{
		"id": "ios",
		"name": "IFONE 5",
		"blurb": "SLATE, IOS 7, ONE HOME BUTTON. EVERYONE ELSE'S SCREEN IS CRACKED."
	},
	{
		"id": "android",
		"name": "NEXXUS 5",
		"blurb": "MATTE BLACK, ANDROID 4.4 KITKAT. THE $349 PHONE WITH THE GOOD SCREEN."
	},
]

var mode := "free"
var step := "char"  # "char", then (tech campaign only) "phone", then (tech and owner) "build" (X7, build_panel.gd)
var ids: Array = []
var sel := 0
var phone_sel := 0
var facing := "right"
var create_row := 0  # the row of the create step: an index into the page's rows, one past the last = the RANDOM | PRESETS | DONE row
var create_page := 0  # the page of the create step (_pages())
var create_col := 0  # the button on the bottom row (CREATE_ACTIONS)
var create_modal := ""  # "", "presets" (the slot chooser) or "name" (the pad's letter grid)
var overlay := false  # the Free Play outfit swap (Toolbox.open_outfit): only the create step, over the running room
var pose_i := 0  # the mirror preview's pose: an index into POSES
var pose_hold := false  # the pose stays until released
var _pose_t := 0.0
var _backup := {}  # Look.snapshot() when the overlay opened: Esc puts it back
var _pre_row := 0
var _pre_col := 0
var _grid_i := 0
var _name_backup := ""
var _sprites: Array = []
var _rects: Array = []  # [Rect2, kind, index] for the mouse
var _born := -1
var _panel: RefCounted = null  # the build step's working build
var _confirmed := false


func _ready() -> void:
	_born = Engine.get_process_frames()
	Game.format_changed.connect(queue_redraw)
	queue_redraw()


func is_campaign() -> bool:
	return Campaign.MODES.has(mode)


func needs_phone() -> bool:
	return mode == "tech"


# MAKE YOUR OWN is offered where the player is nobody from the cast: the tech campaign and Free Play (the owner, sales and
# service campaigns play Alan / Garrison / Vic / Dan)
func offers_custom(for_mode: String) -> bool:
	return for_mode == "tech" or for_mode == FREE_MODE


func is_custom() -> bool:
	return sel < ids.size() and ids[sel] == CUSTOM


# the raw card id under the cursor (CUSTOM for the MAKE YOUR OWN card)
func sel_id() -> String:
	return str(ids[sel]) if sel < ids.size() else PLAYER.current_character


# the point-buy step (X7): the campaigns that have a stat set; Free Play has none
func needs_build() -> bool:
	return Build.selectable(mode)


func _open_build() -> void:
	step = "build"
	if _panel == null or _panel.character != current_id():
		_panel = BuildPanel.new()
		_panel.setup(mode, current_id())
	queue_redraw()


# who this mode offers: everyone in Free Play, Alan or Garrison in the owner campaign, only non-cast people in
# the tech campaign
func choices(for_mode: String) -> Array:
	if Campaign.is_planned(for_mode):
		return []  # registered but not playable yet (X8): it cannot be chosen
	if for_mode == "owner":
		return ["office_alan", "casual_garrison"]
	if for_mode == "sales":
		return ["sales_vic"]
	if for_mode == "service":
		return ["office_dan"]
	var cast: Array = []
	for n in World.CAST:
		cast.append(str(World.CAST[n].character))
	var out: Array = []
	for id in PLAYER.CHARACTERS:
		if Campaign.MODES.has(for_mode) and id in cast:
			continue
		out.append(id)
	return out


func setup(for_mode: String, year2 := false) -> void:
	mode = for_mode
	step = "char"
	ids = choices(mode)
	if offers_custom(mode):
		ids.push_front(CUSTOM)
	sel = maxi(0, ids.find(PLAYER.current_character))
	if not PLAYER.current_character in ids:
		sel = maxi(0, ids.find("office_adult"))
	if offers_custom(mode) and Look.active:
		sel = 0  # the last new run was a custom person
	create_row = 0
	create_page = 0
	create_col = 0
	create_modal = ""
	phone_sel = 1 if Phone.os == "android" else 0
	_panel = null
	_confirmed = false
	Mutators.pending_start = Mutators.STANDARD
	Yeartwo.begin_select(for_mode, year2)  # New Game Plus: the MUT chip and +2 build points
	Difficulty.roll_seed()  # the run seed is chosen here: shown on the SEED chip, X changes it
	facing = "right"
	for spr in _sprites:
		spr.queue_free()
	_sprites.clear()
	for id in ids:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Look.frames_for(Look.BASE if id == CUSTOM else id, id == CUSTOM)
		Look.apply(spr, Look.BASE, id == CUSTOM)
		spr.play("idle_right")
		add_child(spr)
		_sprites.append(spr)
	queue_redraw()


# the Free Play outfit swap: the create step alone, editing the player's own look live (Esc restores it, DONE keeps it)
func setup_overlay() -> void:
	overlay = true
	mode = FREE_MODE
	step = "create"
	ids = [CUSTOM]
	sel = 0
	create_row = 0
	create_page = 0
	create_col = 0
	create_modal = ""
	pose_i = 0
	pose_hold = false
	_pose_t = 0.0
	facing = "right"
	_backup = Look.snapshot()
	Look.active = true  # the preview wears the look even when the player is a stock person right now
	for spr in _sprites:
		spr.queue_free()
	_sprites.clear()
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = Look.frames_for(Look.BASE, true)
	Look.apply(spr, Look.BASE, true)
	spr.play("idle_right")
	add_child(spr)
	_sprites.append(spr)
	queue_redraw()


func _finish_overlay(keep: bool) -> void:
	if keep:
		Look.look["name"] = Look.final_name()
		Look.save_settings(true)
		done.emit({"look": Look.look.duplicate(), "acc": Look.acc.duplicate()})
	else:
		Look.restore(_backup)
		cancelled.emit()


# ---- the mirror preview's poses
func pose_anim() -> String:
	return "%s_%s" % [POSES[pose_i][0], facing]


func set_pose(index: int, hold := false) -> void:
	pose_i = posmod(index, POSES.size())
	pose_hold = pose_hold or hold
	_pose_t = 0.0
	_apply_pose()
	queue_redraw()


func toggle_hold() -> void:
	pose_hold = not pose_hold
	_pose_t = 0.0
	queue_redraw()


# the custom card plays the pose (a one-shot gesture that has finished starts again)
func _apply_pose() -> void:
	if step != "create" or sel >= _sprites.size():
		return
	var spr: AnimatedSprite2D = _sprites[sel]
	var anim := pose_anim()
	if spr.sprite_frames == null or not spr.sprite_frames.has_animation(anim):
		return
	if spr.animation != anim or not spr.is_playing():
		spr.play(anim)


func _process(delta: float) -> void:
	if step != "create":
		return
	_pose_t += delta
	if _pose_t >= POSE_SECS and not pose_hold and create_modal == "":
		set_pose(pose_i + 1)
		return
	_apply_pose()


func current_id() -> String:
	if is_custom():
		return Look.BASE
	return sel_id()


func info(id: String) -> Dictionary:
	if id == CUSTOM:
		return {"name": "MAKE YOUR OWN", "blurb": CUSTOM_BLURB}
	var entry: Dictionary = PEOPLE.get(id, {"name": id.to_upper(), "blurb": ""}).duplicate()
	if mode == "owner" and OWNER_BLURBS.has(id):
		entry["blurb"] = OWNER_BLURBS[id]
	if mode == "sales":
		entry["blurb"] = SALES_BLURB
	if mode == "service" and SERVICE_BLURBS.has(id):
		entry["blurb"] = SERVICE_BLURBS[id]
	return entry


func summary(with_tier := true) -> String:
	var label: String = Campaign.MODES.get(mode, "FREE PLAY")
	var who: String = Look.final_name() if is_custom() else str(info(current_id()).name)
	var s := "%s - %s" % [label, who]
	if needs_phone():
		s += " - " + str(PHONES[phone_sel].name)
	if _panel != null and (step == "build" or _confirmed):
		s += " - " + str(_panel.name_text())
	if Yeartwo.pending:
		s += " - YEAR 2"
	if with_tier:
		s += " - " + Difficulty.label()
		if is_campaign() and Mutators.pending_start != Mutators.STANDARD:
			s += " - " + str(Mutators.STARTS.get(Mutators.pending_start, {}).get("short", ""))
	return s


# Tab / Shift+Tab (or a click on the START chip arrows) pick the starting condition of the new run
func change_start(step: int) -> void:
	if not is_campaign():
		return
	var list: Array = Mutators.starts_for(mode)
	var i := maxi(0, list.find(Mutators.pending_start))
	Mutators.pending_start = str(list[(i + step + list.size()) % list.size()])
	queue_redraw()


# M / Shift+M (or a click on the MUT chip arrows) pick the mutator of a Year 2 run, B switches PICK / BAN
func change_mut(step: int) -> void:
	if Yeartwo.pending:
		Yeartwo.change_mut(mode, step)
		queue_redraw()


func toggle_mut_mode() -> void:
	if Yeartwo.pending:
		Yeartwo.toggle_mut_mode()
		queue_redraw()


# Up / Down (or a click on the arrows) change the difficulty; it is remembered in the settings file
func change_tier(delta_tier: int) -> void:
	Difficulty.cycle_tier(delta_tier)
	Difficulty.save_settings()
	if _panel != null:
		_panel.refit()
	queue_redraw()


# X (or a click on the SEED chip): type, paste, roll or pick today's seed
func open_seed() -> void:
	if overlay:
		return
	Toolbox.open_seed(func(_go: bool) -> void: queue_redraw())


# T (Free Play): the toolbox; GO there starts Free Play and launches the chosen game
func open_tools() -> void:
	if overlay:
		return
	if mode != "free":
		return
	Toolbox.open_tools(true, _tools_closed)


func _tools_closed(go: bool) -> void:
	queue_redraw()
	if go:
		confirm()


func move(delta_sel: int) -> void:
	if step == "char":
		if ids.is_empty():
			return
		sel = (sel + delta_sel + ids.size()) % ids.size()
		facing = "right" if delta_sel > 0 else "left"
	else:
		phone_sel = (phone_sel + delta_sel + PHONES.size()) % PHONES.size()
	queue_redraw()


func confirm() -> void:
	if overlay:
		_finish_overlay(true)
		return
	if step == "char" and is_custom():
		step = "create"
		queue_redraw()
		return
	if step == "create":
		Look.look["name"] = Look.final_name()
	if (step == "char" or step == "create") and needs_phone():
		step = "phone"
		queue_redraw()
		return
	if step != "build" and needs_build():
		_open_build()
		return
	if step == "build" and not _panel.valid():
		queue_redraw()
		Hints.toast(str(_panel.errors()[0]), 2.0)
		return
	_confirmed = step == "build"
	Build.pending = _panel.build_out() if _confirmed else {}
	var result := {
		"mode": mode,
		"character": current_id(),
		"phone": str(PHONES[phone_sel].id) if needs_phone() else "",
		"summary": summary(),
		"tier": Difficulty.tier,
		"build": Build.pending,
		"look": Look.look.duplicate() if is_custom() else {},
	}
	PLAYER.current_character = current_id()
	Look.active = is_custom()
	Look.save_settings(Look.active)  # the look is the default of the next new run
	if needs_phone():
		Phone.set_os(result.phone)
	done.emit(result)


func back() -> void:
	if step == "create" and create_modal != "":
		close_modal(false)
	elif overlay:
		_finish_overlay(false)
	elif step == "build":
		step = "phone" if needs_phone() else ("create" if is_custom() else "char")
		queue_redraw()
	elif step == "phone":
		step = "create" if is_custom() else "char"
		queue_redraw()
	elif step == "create":
		step = "char"
		queue_redraw()
	else:
		cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _born or Toolbox.is_open:
		return
	if Controls.pressed(event):
		if step == "create" and _create_input(event):
			get_viewport().set_input_as_handled()
			return
		var dir := Controls.nav(event)
		if step == "build" and _build_key(event, dir):
			get_viewport().set_input_as_handled()
			return
		if dir == "left":
			move(-1)
		elif dir == "right":
			move(1)
		elif dir == "up":
			change_tier(1)
		elif dir == "down":
			change_tier(-1)
		elif Controls.confirm(event):
			confirm()
		elif Controls.back(event):
			back()
		elif Controls.matches(event, "pick_prev"):
			change_start(-1)
		elif Controls.matches(event, "pick_next"):
			change_start(1)
		elif event is InputEventKey:
			match event.keycode:
				KEY_X:
					open_seed()
				KEY_T:
					open_tools()
				KEY_F9:
					Game.cycle_format()
				KEY_M:
					change_mut(-1 if event.shift_pressed else 1)
				KEY_B:
					toggle_mut_mode()
				_:
					return
		else:
			return
	elif event is InputEventMouseMotion:
		_hover(event.position)
		return
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_click(event.position)
	else:
		return
	get_viewport().set_input_as_handled()


# the build step's own keys: Up / Down rows, Left / Right change, P preset (the rest is shared with the other steps)
func _build_key(event: InputEvent, dir: String) -> bool:
	if dir == "up":
		_panel.move_row(-1)
	elif dir == "down":
		_panel.move_row(1)
	elif dir == "left":
		_panel.change(-1)
	elif dir == "right":
		_panel.change(1)
	elif event is InputEventKey and event.keycode == KEY_P:
		_panel.cycle_preset(1)
	else:
		return false
	queue_redraw()
	return true


func _create_input(event: InputEvent) -> bool:
	if create_modal != "":
		return _modal_input(event)
	if Controls.matches(event, "hold_pose"):
		toggle_hold()
		return true
	if Controls.matches(event, "pose_prev") or Controls.matches(event, "pose_next"):
		set_pose(pose_i + (-1 if Controls.matches(event, "pose_prev") else 1), true)
		return true
	var rows := _page_rows()
	var on_name := create_row < rows.size() and str(rows[create_row].kind) == "name"
	if on_name and _type_key(event):
		queue_redraw()
		return true
	if Controls.matches(event, "page_prev") or Controls.matches(event, "page_next"):
		var letter: bool = event is InputEventKey and event.keycode in [KEY_Q, KEY_E]
		if not (letter and on_name):  # Q and E are letters on the NAME row (a pad's shoulder buttons always turn the page)
			_turn_page(-1 if Controls.matches(event, "page_prev") else 1)
			return true
	return _create_key(event, Controls.nav(event))


# the create step: Up / Down pick a row (the last one is the RANDOM | PRESETS | DONE row), Left / Right change it (on the last
# row they pick the button), Enter or a pad's A presses the button, on the NAME row a pad opens the letter grid, Enter on any
# other row goes on
func _create_key(event: InputEvent, dir: String) -> bool:
	var n := _page_rows().size() + 1
	if dir == "up":
		create_row = (create_row + n - 1) % n
	elif dir == "down":
		create_row = (create_row + 1) % n
	elif dir == "left" or dir == "right":
		_create_change(-1 if dir == "left" else 1)
	elif Controls.confirm(event) and create_row == n - 1:
		_press_action(CREATE_ACTIONS[create_col])
	elif Controls.confirm(event) and not event is InputEventKey and str(_page_rows()[create_row].kind) == "name":
		open_name_grid()
	else:
		return false
	queue_redraw()
	return true


func _create_change(delta: int) -> void:
	var rows := _page_rows()
	if create_row >= rows.size():
		create_col = (create_col + delta + CREATE_ACTIONS.size()) % CREATE_ACTIONS.size()
		return
	var row: Dictionary = rows[create_row]
	match str(row.kind):
		"name":
			Look.cycle_name(delta)
		"choice":
			Look.cycle_choice(str(row.id), delta)
		"acc":
			Look.cycle_acc(str(row.id), delta)
		"swatch":
			Look.set_swatch(str(row.id), maxi(0, Look.swatch_index(str(row.id))) + delta)
	_refresh_look()


func _press_action(action: String) -> void:
	match action:
		"random":
			roll_look()
		"presets":
			open_presets()
		"done":
			confirm()


# ---- pages ----
# the pages with rows (an empty EXTRAS page has no tab until its rows land)
func _pages() -> Array:
	var out: Array = []
	for p in CREATE_PAGES:
		if not (p.rows as Array).is_empty():
			out.append(p)
	return out


func _page_rows() -> Array:
	var pages := _pages()
	create_page = clampi(create_page, 0, pages.size() - 1)
	return pages[create_page].rows


func _turn_page(delta: int) -> void:
	set_page(create_page + delta)


func set_page(index: int) -> void:
	var n := _pages().size()
	var was_bottom := create_row >= _page_rows().size()
	create_page = (index % n + n) % n
	create_row = _page_rows().size() if was_bottom else mini(create_row, _page_rows().size())
	queue_redraw()


# typing on the NAME row: letters, digits, space and dash are added, Backspace deletes (an empty name lets Backspace go back)
func _type_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var code: int = event.keycode
	var buf := str(Look.look.get("name", ""))
	if code == KEY_BACKSPACE:
		if buf == "":
			return false
		Look.look["name"] = buf.left(buf.length() - 1)
		_refresh_look()
		return true
	if code in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_TAB]:
		return false
	var ch := ""
	if event.unicode > 0:
		ch = char(event.unicode)
	elif code >= KEY_A and code <= KEY_Z:
		ch = char(code)
	if not Look.name_char_ok(ch):
		return false
	if buf.length() < Look.MAX_NAME and not (ch == " " and buf == ""):
		Look.look["name"] = buf + ch.to_upper()
	_refresh_look()
	return true


# ---- the two small modals: the presets chooser and the pad's letter grid ----
func open_presets() -> void:
	Look.load_presets()
	create_modal = "presets"
	_pre_row = 0
	_pre_col = 0
	queue_redraw()


func open_name_grid() -> void:
	create_modal = "name"
	_name_backup = str(Look.look.get("name", ""))
	_grid_i = 0
	queue_redraw()


func close_modal(keep := true) -> void:
	if create_modal == "name" and not keep:
		Look.look["name"] = _name_backup
		_refresh_look()
	create_modal = ""
	queue_redraw()


# the letter grid: A to Z and the dash in 3 rows of 9, then SPACE, DEL and DONE across the bottom row
func grid_cells() -> Array:
	var out: Array = []
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ-"
	for i in letters.length():
		out.append({"label": letters[i], "ch": letters[i], "row": floori(float(i) / GRID_COLS), "col": i % GRID_COLS, "span": 1})
	out.append({"label": "SP", "ch": " ", "row": 3, "col": 0, "span": 2})
	out.append({"label": "DEL", "ch": "del", "row": 3, "col": 2, "span": 3})
	out.append({"label": "DONE", "ch": "done", "row": 3, "col": 5, "span": 4})
	return out


func _grid_press(i: int) -> void:
	var ch := str(grid_cells()[i].ch)
	var buf := str(Look.look.get("name", ""))
	if ch == "done":
		Look.look["name"] = Look.final_name()
		close_modal()
		_refresh_look()
		return
	if ch == "del":
		Look.look["name"] = buf.left(maxi(0, buf.length() - 1))
	elif buf.length() < Look.MAX_NAME and not (ch == " " and buf == ""):
		Look.look["name"] = buf + ch
	_refresh_look()


func _grid_move(dir: String) -> void:
	var cells := grid_cells()
	var cur: Dictionary = cells[_grid_i]
	var row := int(cur.row)
	if dir == "left" or dir == "right":
		var same: Array = []
		for i in cells.size():
			if int(cells[i].row) == row:
				same.append(i)
		_grid_i = same[(same.find(_grid_i) + (1 if dir == "right" else -1) + same.size()) % same.size()]
		return
	var target := (row + (1 if dir == "down" else 3)) % 4
	var cx := float(cur.col) + float(cur.span) * 0.5
	var best := -1
	var best_d := 1000.0
	for i in cells.size():
		if int(cells[i].row) == target:
			var d := absf(float(cells[i].col) + float(cells[i].span) * 0.5 - cx)
			if d < best_d:
				best = i
				best_d = d
	_grid_i = best


# every key while a modal is open (the rest of the step is out of reach)
func _modal_input(event: InputEvent) -> bool:
	var dir := Controls.nav(event)
	if create_modal == "name":
		if _type_key(event):  # a keyboard still types
			queue_redraw()
			return true
		if Controls.back(event):
			close_modal(false)
		elif dir != "":
			_grid_move(dir)
		elif Controls.confirm(event):
			_grid_press(_grid_i)
		queue_redraw()
		return true
	if Controls.back(event):
		close_modal()
	elif dir == "up":
		_pre_row = (_pre_row + 3) % (Look.PRESET_SLOTS + 1)
	elif dir == "down":
		_pre_row = (_pre_row + 1) % (Look.PRESET_SLOTS + 1)
	elif dir == "left" or dir == "right":
		_pre_col = 1 - _pre_col
	elif Controls.confirm(event):
		_preset_press(_pre_row, _pre_col)
	queue_redraw()
	return true


# SAVE HERE (col 0) or LOAD (col 1) on a slot row, CANCEL on the last
func _preset_press(row: int, col: int) -> void:
	if row >= Look.PRESET_SLOTS:
		close_modal()
	elif col == 0:
		Look.save_preset(row)
	elif Look.load_preset(row):
		close_modal()
		_refresh_look()  # the look is worn live in the preview
	else:
		Hints.toast("THAT SLOT IS EMPTY", 1.5)
	queue_redraw()


func roll_look() -> void:
	Look.randomize_look()
	_refresh_look()


# the text of a choice row's box: the style (a hairstyle a hat replaces shows as SPIKY>SHORT), or the accessory's name
func _choice_text(row: Dictionary) -> String:
	if str(row.kind) == "acc":
		return Look.acc_title(str(row.id), str(Look.acc.get(row.id, "")))
	var st := str(Look.CHOICES[row.id][Look.choice_index(str(row.id))]).to_upper()
	if Look.CLOTHES_KINDS.has(str(row.id)):
		st = Look.clothes_title(str(row.id), str(Look.CHOICES[row.id][Look.choice_index(str(row.id))]))
	if str(row.id) == "hair_style":
		var shown := Look.hair_shown(Look.look, Look.acc)
		if shown != str(Look.look.get("hair_style", "")):
			st += ">" + shown.to_upper()
	return st


# the preview cards wear the look
func _refresh_look() -> void:
	for i in ids.size():
		if ids[i] == CUSTOM:
			Look.apply(_sprites[i], Look.BASE, true)
			var fr := Look.frames_for(Look.BASE, true)
			if _sprites[i].sprite_frames != fr:  # another hairstyle is another sheet: keep the animation running
				var anim: StringName = _sprites[i].animation
				_sprites[i].sprite_frames = fr
				_sprites[i].play(anim)
	look_changed.emit()
	queue_redraw()


func _hit(at: Vector2) -> Array:
	for r in _rects:
		if r[0].has_point(at):
			return r
	return []


func _hover(at: Vector2) -> void:
	var r := _hit(at)
	if r.is_empty():
		return
	var kind: String = r[1]
	if kind.begins_with("b_"):
		if step == "build":
			_panel.hover(kind, int(r[2]))
			queue_redraw()
	elif step == "create" and kind in ["sw", "row", "name_box", "ch_prev", "ch_next", "act", "pre_save", "pre_load", "pre_cancel", "gcell"]:
		_create_hover(r)
	elif kind == "item" and step == "char" and sel != int(r[2]):
		sel = int(r[2])
		queue_redraw()
	elif kind == "phone" and phone_sel != int(r[2]):
		phone_sel = int(r[2])
		queue_redraw()


# a mouse move over a create rect picks that row, button or modal cell
func _create_hover(r: Array) -> void:
	var kind := str(r[1])
	var index := int(r[2])
	if kind == "pre_save" or kind == "pre_load":
		_pre_row = index
		_pre_col = 0 if kind == "pre_save" else 1
	elif kind == "pre_cancel":
		_pre_row = Look.PRESET_SLOTS
	elif kind == "gcell":
		_grid_i = index
	elif kind == "act":
		create_row = _page_rows().size()
		create_col = index
	elif kind == "sw":
		create_row = floori(float(index) / 100.0)
	else:
		create_row = index
	queue_redraw()


func _click(at: Vector2) -> void:
	var r := _hit(at)
	if r.is_empty():
		return
	if str(r[1]).begins_with("b_"):
		if step == "build":
			_panel.click(str(r[1]), int(r[2]))
			queue_redraw()
		return
	match str(r[1]):
		"pose":
			toggle_hold()
		"pose_prev", "pose_next":
			set_pose(pose_i + (-1 if str(r[1]) == "pose_prev" else 1), true)
		"tab":
			set_page(int(r[2]))
		"sw":
			create_row = floori(float(r[2]) / 100.0)
			Look.set_swatch(str(_page_rows()[create_row].id), int(r[2]) % 100)
			_refresh_look()
		"row":
			create_row = int(r[2])
			queue_redraw()
		"name_box":
			create_row = int(r[2])
			open_name_grid()
		"ch_prev", "ch_next":
			create_row = int(r[2])
			_create_change(-1 if str(r[1]) == "ch_prev" else 1)
		"act":
			create_row = _page_rows().size()
			create_col = int(r[2])
			_press_action(CREATE_ACTIONS[create_col])
		"pre_save", "pre_load":
			_pre_row = int(r[2])
			_pre_col = 0 if str(r[1]) == "pre_save" else 1
			_preset_press(_pre_row, _pre_col)
		"pre_cancel":
			close_modal()
		"gcell":
			_grid_i = int(r[2])
			_grid_press(_grid_i)
		"go":
			confirm()
		"back":
			back()
		"prev":
			move(-1)
		"next":
			move(1)
		"tier_down":
			change_tier(-1)
		"tier_up":
			change_tier(1)
		"start_down":
			change_start(-1)
		"start_up":
			change_start(1)
		"mut_down":
			change_mut(-1)
		"mut_up":
			change_mut(1)
		"mut_mode":
			toggle_mut_mode()
		"seed":
			open_seed()
		"tools":
			open_tools()
		_:
			_hover(at)
			confirm()


# ---- drawing --------------------------------------------------------------------
func _size() -> Vector2:
	return Vector2(Game.FORMATS[Game.format].size)


func _txt(s: String, p: Vector2, c := Color.WHITE) -> void:
	PixelFont.draw(self, s, p, c)


func _ctxt(s: String, y: float, c := Color.WHITE) -> void:
	_txt(s, Vector2(floorf((_size().x - float(PixelFont.width(s))) * 0.5), y), c)


func _wrap(s: String, chars: int, max_lines := 4) -> Array:
	var lines: Array = []
	var line := ""
	for word in s.split(" "):
		if line != "" and line.length() + 1 + word.length() > chars:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines.slice(0, max_lines)


# wide (368x128) has room for one blurb line above the summary: keep the whole sentences that fit on it
func _one_line(s: String, chars: int) -> String:
	var out := ""
	for sentence in s.split(". "):
		var piece: String = sentence if sentence.ends_with(".") else sentence + "."
		var next := piece if out == "" else out + " " + piece
		if next.length() > chars:
			break
		out = next
	return out if out != "" else s


func _para(s: String, y: float, c: Color, max_lines := 4) -> float:
	var chars := int((_size().x - 20.0) / 4.0)
	for line in _wrap(s, chars, max_lines):
		_ctxt(str(line), y, c)
		y += 8.0
	return y


func _draw() -> void:
	var size := _size()
	var narrow := size.x < 250.0
	_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.08, 0.78 if overlay else 0.9))  # the outfit overlay lets the room show through
	var heading: String = {"char": "CHOOSE YOUR CHARACTER", "create": "CHANGE YOUR LOOK" if overlay else "MAKE YOUR OWN PERSON", "phone": "PICK YOUR PHONE"}.get(step, "BUILD YOUR CHARACTER")
	_ctxt(heading, 22.0 if narrow else 6.0, GOLD)
	var back_r := Rect2(3.0, 3.0, 28.0, 9.0)
	draw_rect(back_r, PANEL)
	_txt("< ESC", back_r.position + Vector2(2, 2), DIM)
	_rects.append([back_r, "back", 0])
	if not overlay:
		_draw_tier(size, narrow)
		_draw_seed(size, narrow)
	if is_campaign() and step == "char":
		_draw_start(size, narrow)
		if Yeartwo.pending:
			_draw_mut(size, narrow)
	if step == "char":
		_draw_chars(size, narrow)
	elif step == "create":
		_place_sprites(size, narrow)
		_draw_create(size, narrow)
	elif step == "build":
		_place_sprites(size, narrow)
		_panel.draw(self, size, narrow, _rects)
	else:
		_place_sprites(size, narrow)
		_draw_phones(size, narrow)
	if not overlay:
		_draw_summary(size, narrow)
	var extra := "T TOOLS" if mode == "free" else ("TAB START M MUT B BAN" if Yeartwo.pending else "TAB START")
	if step == "create":
		if create_modal != "":
			_ctxt("ARROWS MOVE  ENTER PICK  ESC BACK", size.y - (12.0 if narrow else 9.0), DIM)
		elif narrow:
			_ctxt("UP DOWN ROW  LEFT RIGHT CHANGE", size.y - 20.0, DIM)
			_ctxt("Q E PAGE  TAB HOLD  ENTER GO  ESC BACK", size.y - 12.0, DIM)
		else:
			var keys := "Q E PAGE  UP DOWN ROW  LEFT RIGHT CHANGE  TAB HOLD POSE  ENTER GO  ESC BACK"
			if float(PixelFont.width(keys)) > size.x - 4.0:
				keys = "Q E PAGE  ARROWS  TAB HOLD POSE  ENTER GO  ESC BACK"
			_ctxt(keys, size.y - 9.0, DIM)
		return
	if step == "build":
		if narrow:
			_ctxt("UP DOWN ROW  LEFT RIGHT CHANGE", size.y - 20.0, DIM)
			_ctxt("P PRESET  X SEED  ENTER GO  ESC BACK", size.y - 12.0, DIM)
		else:
			_ctxt("UP DOWN ROW  LEFT RIGHT CHANGE  P PRESET  X SEED  ENTER GO  ESC BACK", size.y - 9.0, DIM)
		return
	var hint := "LEFT RIGHT CHOOSE  UP DOWN LEVEL  %s  X SEED  ENTER PICK  ESC BACK" % extra
	if float(PixelFont.width(hint)) > size.x - 4.0:  # NEW GAME PLUS adds M MUT B BAN: too long for 320
		hint = hint.replace("LEFT RIGHT CHOOSE", "LEFT RIGHT")
	if narrow:
		_ctxt("LEFT RIGHT CHOOSE   UP DOWN LEVEL", size.y - 27.0, DIM)
		_ctxt("%s  X SEED" % extra, size.y - 19.0, DIM)
		_ctxt("ENTER PICK  ESC BACK", size.y - 11.0, DIM)
	else:
		_ctxt(hint, size.y - 9.0, DIM)


# the summary line at the bottom; wraps onto two lines when the build step makes it wider than the screen
func _draw_summary(size: Vector2, narrow: bool) -> void:
	var base := size.y - (34.0 if narrow else (18.0 if size.y <= 130.0 else 19.0))
	var text := summary(false)
	if float(PixelFont.width(text)) <= size.x - 8.0:
		_ctxt(text, base, Color.WHITE)
		return
	var parts := text.split(" - ")
	var first := ""
	for i in parts.size():
		var next: String = parts[i] if first == "" else first + " - " + parts[i]
		if first != "" and float(PixelFont.width(next)) > size.x - 8.0:
			_ctxt(first, base - 8.0, Color.WHITE)
			_ctxt(" - ".join(parts.slice(i)), base, Color.WHITE)
			return
		first = next
	_ctxt(text, base, Color.WHITE)


# the difficulty chip: LEVEL < NORMAL > (top right, or under the heading in narrow portrait)
func _draw_tier(size: Vector2, narrow: bool) -> void:
	var text := "LEVEL  %s" % Difficulty.label()
	var w := float(PixelFont.width("LEVEL  HARD")) + 24.0
	var r := Rect2(
		floorf((size.x - w) * 0.5) if narrow else size.x - w - 3.0, 30.0 if narrow else 3.0, w, 9.0
	)
	draw_rect(r, PANEL)
	draw_rect(r, GOLD if Difficulty.tier != "normal" else DIM, false, 1.0)
	_txt("<", r.position + Vector2(3, 2), GOLD)
	_txt(">", r.position + Vector2(r.size.x - 7.0, 2), GOLD)
	var tw := float(PixelFont.width(text))
	_txt(text, r.position + Vector2(floorf((r.size.x - tw) * 0.5), 2), Color.WHITE)
	_rects.append([Rect2(r.position, Vector2(w * 0.5, 9.0)), "tier_down", 0])
	_rects.append([Rect2(r.position + Vector2(w * 0.5, 0.0), Vector2(w * 0.5, 9.0)), "tier_up", 0])


# the run seed chip: SEED 4F2A9C (X opens the seed page); in Free Play a TOOLS chip follows it
func _draw_seed(size: Vector2, narrow: bool) -> void:
	var text := "SEED  " + Difficulty.seed_text()
	if Difficulty.daily != "":
		text = "DAILY " + Difficulty.seed_text()
	var w := float(PixelFont.width("SEED  4F2A9C")) + 8.0
	var pos := Vector2(34.0, 3.0)
	var wide := size.x > 340.0
	if wide and is_campaign():  # the START chip sits at the left
		var level_w := float(PixelFont.width("LEVEL  HARD")) + 24.0
		pos = Vector2(size.x - level_w - 3.0 - w - 4.0, 3.0)
	var r := Rect2(pos, Vector2(w, 9.0))
	draw_rect(r, PANEL)
	draw_rect(r, GOLD if Difficulty.daily != "" else DIM, false, 1.0)
	var tw := float(PixelFont.width(text))
	_txt(text, r.position + Vector2(floorf((w - tw) * 0.5), 2), Color.WHITE)
	_rects.append([r, "seed", 0])
	if is_campaign() and Difficulty.cozy_chosen():  # R16: the Easy tier is the cozy mode; tag it beside the seed
		var tag_w := float(PixelFont.width("COZY")) + 8.0
		var tag := Rect2(r.position + Vector2(0.0, 10.0), Vector2(tag_w, 8.0))  # under the seed chip (portrait)
		if wide:
			tag = Rect2(Vector2(size.x - tag_w - 3.0, 13.0), Vector2(tag_w, 8.0))  # under the level chip, clear of the heading
		elif not narrow:
			tag = Rect2(r.position + Vector2(w + 3.0, 0.0), Vector2(tag_w, 9.0))  # beside it (the h format has room)
		draw_rect(tag, PANEL)
		draw_rect(tag, GOLD, false, 1.0)
		_txt("COZY", tag.position + Vector2(4, tag.size.y * 0.5 - 3.0), GOLD)
	if mode == "free" and step == "char":
		var tools := Rect2(pos + Vector2(w + 3.0, 0.0), Vector2(float(PixelFont.width("TOOLS")) + 8.0, 9.0))
		if not wide:
			tools.position = Vector2(size.x - tools.size.x - 3.0, 3.0 if narrow else 14.0)
		draw_rect(tools, PANEL)
		draw_rect(tools, GOLD if Difficulty.fixed_take else DIM, false, 1.0)
		_txt("TOOLS", tools.position + Vector2(4, 2), Color.WHITE)
		_rects.append([tools, "tools", 0])


# the starting condition chip: START < MESSY MSP > (left of the heading, under the level chip at 320 wide, top right in portrait)
func _draw_start(size: Vector2, narrow: bool) -> void:
	var s: Dictionary = Mutators.STARTS.get(Mutators.pending_start, {})
	var text := "START  %s" % str(s.get("short", "STANDARD"))
	var w := float(PixelFont.width("START  FAMILY BIZ")) + 16.0
	var pos := Vector2(34.0, 3.0)
	if narrow:
		pos = Vector2(size.x - w - 3.0, 3.0)
	elif size.x < 340.0:
		pos = Vector2(size.x - w - 3.0, 14.0)
	var r := Rect2(pos, Vector2(w, 9.0))
	draw_rect(r, PANEL)
	draw_rect(r, GOLD if Mutators.pending_start != Mutators.STANDARD else DIM, false, 1.0)
	_txt("<", r.position + Vector2(3, 2), GOLD)
	_txt(">", r.position + Vector2(r.size.x - 7.0, 2), GOLD)
	var tw := float(PixelFont.width(text))
	_txt(text, r.position + Vector2(floorf((r.size.x - tw) * 0.5), 2), Color.WHITE)
	_rects.append([Rect2(r.position, Vector2(w * 0.5, 9.0)), "start_down", 0])
	_rects.append([Rect2(r.position + Vector2(w * 0.5, 0.0), Vector2(w * 0.5, 9.0)), "start_up", 0])


# Year 2: the mutator chip MUT < AUTO > (M picks, B switches PICK / BAN): right under the level chip when wide, at the left
# under the heading at 320 wide, centred below the level chip in portrait
func _draw_mut(size: Vector2, narrow: bool) -> void:
	var text := Yeartwo.chip_text()
	var w := float(PixelFont.width("PICK PRINTER APOC.")) + 16.0
	var pos := Vector2(3.0, 14.0)
	if narrow:
		pos = Vector2(3.0, 12.0)
	elif size.x > 340.0:
		pos = Vector2(size.x - w - 3.0, 14.0)
	var r := Rect2(pos, Vector2(w, 9.0))
	draw_rect(r, PANEL)
	draw_rect(r, GOLD if Yeartwo.pick != "" else (Color("ff8a80") if Yeartwo.ban != "" else DIM), false, 1.0)
	_txt("<", r.position + Vector2(3, 2), GOLD)
	_txt(">", r.position + Vector2(r.size.x - 7.0, 2), GOLD)
	var tw := float(PixelFont.width(text))
	_txt(text, r.position + Vector2(floorf((r.size.x - tw) * 0.5), 2), Color.WHITE)
	_rects.append([Rect2(r.position, Vector2(w * 0.5 - 14.0, 9.0)), "mut_down", 0])
	_rects.append([Rect2(r.position + Vector2(w * 0.5 + 14.0, 0.0), Vector2(w * 0.5 - 14.0, 9.0)), "mut_up", 0])
	_rects.append([Rect2(r.position + Vector2(w * 0.5 - 14.0, 0.0), Vector2(28.0, 9.0)), "mut_mode", 0])


func _place_sprites(size: Vector2, narrow: bool) -> void:
	var n := ids.size()
	if step == "create":  # only the custom person, big enough to see the colours
		var lay := _create_layout(size, narrow)
		for i in n:
			var cs: AnimatedSprite2D = _sprites[i]
			cs.visible = i == sel
			cs.scale = Vector2.ONE
			cs.position = Vector2(float(lay.cx), float(lay.feet) - 40.0)
			if i == sel:
				_apply_pose()
		return
	var pitch := minf(50.0, (size.x - 16.0) / maxf(1.0, float(n)))
	var feet := 83.0 if size.y <= 130.0 else 104.0
	if narrow:
		feet = 176.0
	for i in n:
		var spr: AnimatedSprite2D = _sprites[i]
		var show_it := step == "char" and (not narrow or i == sel)
		spr.visible = show_it
		spr.scale = Vector2(2, 2) if narrow else Vector2.ONE
		var cx := size.x * 0.5 if narrow else (size.x - pitch * n) * 0.5 + pitch * (i + 0.5)
		spr.position = Vector2(cx, feet - (80.0 if narrow else 40.0))
		var face := facing if i == sel else ("right" if i < sel else "left")
		var anim := "idle_" + face
		if spr.animation != anim:
			spr.play(anim)


func _draw_chars(size: Vector2, narrow: bool) -> void:
	_place_sprites(size, narrow)
	var n := ids.size()
	var pitch := minf(50.0, (size.x - 16.0) / maxf(1.0, float(n)))
	var feet := 83.0 if size.y <= 130.0 else 104.0
	if narrow:
		feet = 176.0
		var panel := Rect2(26.0, feet - 136.0, size.x - 52.0, 146.0)
		draw_rect(panel, PANEL)
		draw_rect(panel, GOLD, false, 1.0)
		var mid := panel.position.y + panel.size.y * 0.5
		for side in 2:
			var ar := Rect2(2.0 if side == 0 else size.x - 22.0, mid - 12.0, 20.0, 24.0)
			_rects.append([ar, "prev" if side == 0 else "next", 0])
			_txt("<" if side == 0 else ">", ar.position + Vector2(8, 9), GOLD)
		_rects.append([panel, "item", sel])
		var dots_y := feet + 22.0
		for i in n:
			var dx := size.x * 0.5 + (float(i) - float(n - 1) * 0.5) * 8.0
			draw_rect(Rect2(dx - 1.5, dots_y, 3, 3), GOLD if i == sel else Color("46506a"))
	else:
		for i in n:
			var cx := (size.x - pitch * n) * 0.5 + pitch * (i + 0.5)
			var r := Rect2(cx - pitch * 0.5 + 1.0, feet - 68.0, pitch - 2.0, 76.0)
			_rects.append([r, "item", i])
			draw_rect(r, Color(0.1, 0.13, 0.2, 0.9) if i == sel else PANEL)
			if i == sel:
				draw_rect(r, GOLD, false, 1.0)
	var data := info(sel_id())
	var name_y := feet + (12.0 if narrow else 10.0)
	_ctxt(str(data.name), name_y, GOLD)
	var by := name_y + (20.0 if narrow else 9.0)
	var blurb := str(data.blurb)
	if size.y <= 130.0 and not narrow:
		blurb = _one_line(blurb, int((size.x - 20.0) / 4.0))
	var end_y := _para(blurb, by, Color.WHITE, 4 if narrow else 2)
	if is_campaign():
		var note := "THE REST OF THE TEAM IS ALREADY AT THEIR DESKS"
		if Mutators.pending_start != Mutators.STANDARD:
			note = str(Mutators.STARTS.get(Mutators.pending_start, {}).get("text", note)).to_upper()
		if end_y + 8.0 < size.y - (46.0 if narrow else 28.0):
			_para(note, end_y + 2.0, DIM, 2)


# where the create step puts the preview (cx, feet) and the rows (x0, y0, pitch): wide 368x128, h 320x180, v 180x320. The tab
# chips take the first row (y0), the page's rows and the RANDOM | PRESETS | DONE row follow
func _create_layout(size: Vector2, narrow: bool) -> Dictionary:
	if narrow:
		return {"cx": size.x * 0.5, "feet": 116.0, "x0": 8.0, "y0": 134.0, "pitch": 14.0}
	if size.y <= 130.0:
		return {"cx": 52.0, "feet": 98.0, "x0": 104.0, "y0": 17.0, "pitch": 11.0}
	return {"cx": 60.0, "feet": 130.0, "x0": 116.0, "y0": 28.0, "pitch": 17.0}


func _row_y(lay: Dictionary, i: int) -> float:
	return float(lay.y0) + float(i + 1) * float(lay.pitch)


# a boxed chip with a centred label; the mouse rect is added when kind is given
func _chip(r: Rect2, text: String, hot: bool, kind := "", index := 0, fill := PANEL) -> void:
	draw_rect(r, fill)
	draw_rect(r, GOLD if hot else DIM, false, 1.0)
	var tw := float(PixelFont.width(text))
	_txt(text, Vector2(r.position.x + floorf((r.size.x - tw) * 0.5), r.position.y + floorf((r.size.y - 5.0) * 0.5)), Color.WHITE if hot else DIM)
	if kind != "":
		_rects.append([r, kind, index])


# the create step (R15, level 3): tab chips, the current page's rows, then RANDOM | PRESETS | DONE; the preview is live
func _draw_create(size: Vector2, narrow: bool) -> void:
	var lay := _create_layout(size, narrow)
	var x0: float = lay.x0
	var pitch: float = lay.pitch
	var sx := x0 + 30.0
	var cell := minf(12.0, floorf((size.x - sx - 6.0) / 12.0))
	var sw := cell - 3.0
	var who := str(Look.look.get("name", ""))
	var cap := who if who != "" else "?"
	_txt(cap, Vector2(floorf(float(lay.cx) - float(PixelFont.width(cap)) * 0.5), float(lay.feet) + 3.0), GOLD)
	_draw_pose_chips(lay)
	_draw_chair(lay)
	var rows := _page_rows()
	# the tab chips
	var tx := x0 - 3.0
	var pages := _pages()
	if create_modal == "":
		for p in pages.size():
			var label := str(pages[p].label)
			var tw := float(PixelFont.width(label)) + 10.0
			_chip(Rect2(tx, float(lay.y0), tw, pitch - 2.0), label, p == create_page, "tab", p)
			tx += tw + 3.0
	if create_modal == "presets":
		_draw_presets(lay, size)
		return
	if create_modal == "name":
		_draw_name_grid(lay, size)
		return
	if rows.is_empty():
		_ctxt(str(pages[create_page].get("empty", "")), _row_y(lay, 1), DIM)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := _row_y(lay, i)
		var hot := i == create_row
		var sy := y + floorf((pitch - sw) * 0.5)
		var ty := sy + floorf((sw - 5.0) * 0.5)
		if hot:
			draw_rect(Rect2(x0 - 3.0, y, sx + cell * 12.0 - x0 + 3.0, pitch - 1.0), PANEL)
		_txt(str(row.label), Vector2(x0, ty), GOLD if hot else DIM)
		var kind := str(row.kind)
		if kind == "name" or kind == "choice" or kind == "acc":
			var box := Rect2(sx + 8.0, sy, 49.0, sw)
			draw_rect(box, INK)
			draw_rect(box, GOLD if hot else DIM, false, 1.0)
			_txt("<", Vector2(sx, ty), GOLD)
			_txt(">", Vector2(box.end.x + 3.0, ty), GOLD)
			if kind == "name":
				var shown := who + ("_" if hot and who.length() < Look.MAX_NAME else "")
				_txt(shown, Vector2(box.position.x + 4.0, ty), Color.WHITE)
				_rects.append([box, "name_box", i])
			else:
				var st := _choice_text(row)
				_txt(st, Vector2(floorf(box.position.x + (box.size.x - float(PixelFont.width(st))) * 0.5), ty), Color.WHITE)
				if kind == "acc" and not Look.acc_locked(str(row.id)).is_empty():
					_txt("%d LOCKED" % Look.acc_locked(str(row.id)).size(), Vector2(box.end.x + 14.0, ty), DIM)
				elif kind == "choice" and Look.CLOTHES_KINDS.has(str(row.id)) and not Look.clothes_locked(str(row.id)).is_empty():
					_txt("%d LOCKED" % Look.clothes_locked(str(row.id)).size(), Vector2(box.end.x + 14.0, ty), DIM)
			_rects.append([Rect2(sx - 2.0, y, 10.0, pitch), "ch_prev", i])
			_rects.append([Rect2(box.end.x + 1.0, y, 9.0, pitch), "ch_next", i])
		else:
			var list: Array = Look.SWATCHES[row.id]
			for j in list.size():
				var r := Rect2(sx + float(j) * cell, sy, sw, sw)
				draw_rect(r, Color.html(str(list[j])))
				draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
				if list[j] == Look.look[row.id]:
					draw_rect(r.grow(1.0), GOLD, false, 1.0)
				_rects.append([Rect2(r.position.x - 1.0, y, cell, pitch), "sw", i * 100 + j])
		_rects.append([Rect2(x0 - 3.0, y, sx + cell * 12.0 - x0 + 3.0, pitch), "row", i])
	# the bottom row: RANDOM | PRESETS | DONE
	var by := _row_y(lay, rows.size())
	var widths := [44.0, 48.0, 32.0]
	var bx := x0
	for a in CREATE_ACTIONS.size():
		var hot_a := create_row == rows.size() and create_col == a
		var rr := Rect2(bx, by + floorf((pitch - 9.0) * 0.5), widths[a], 9.0)
		_chip(rr, str(CREATE_ACTIONS[a]).to_upper(), hot_a, "act", a)
		bx += float(widths[a]) + 4.0


# a small office chair under the seated poses (the sheet draws the person sitting on nothing: the rooms bring the chair)
func _draw_chair(lay: Dictionary) -> void:
	var anim := str(POSES[pose_i][0])
	if create_modal != "" or not (anim.begins_with("sit") or anim == "type"):
		return
	var dir := 1.0 if facing == "right" else -1.0
	var cx: float = lay.cx
	var oy: float = float(lay.feet) - 80.0
	var dark := Color("2a2f3a")
	var mid := Color("46506a")
	for part in [[-14.0, -12.0, 50.0, 24.0, mid], [-12.0, 10.0, 71.0, 3.0, mid], [-2.0, 0.0, 74.0, 4.0, dark], [-9.0, 7.0, 78.0, 2.0, dark]]:
		var xa: float = cx + dir * float(part[0])
		var xb: float = cx + dir * float(part[1])
		draw_rect(Rect2(minf(xa, xb), oy + float(part[2]), absf(xb - xa), float(part[3])), part[4])


# the mirror preview's pose line under the name: < POSE > (HOLD in front while it is held); a click on the person holds it
func _draw_pose_chips(lay: Dictionary) -> void:
	if create_modal != "":
		return
	var cx: float = lay.cx
	var y: float = float(lay.feet) + 10.0
	var label := str(POSES[pose_i][1])
	if pose_hold:
		label = "HOLD " + label
	var w := float(PixelFont.width(label))
	_txt(label, Vector2(floorf(cx - w * 0.5), y), GOLD if pose_hold else DIM)
	var left := Rect2(floorf(cx - w * 0.5) - 12.0, y - 2.0, 10.0, 9.0)
	var right := Rect2(floorf(cx + w * 0.5) + 2.0, y - 2.0, 10.0, 9.0)
	_txt("<", left.position + Vector2(2, 2), GOLD)
	_txt(">", right.position + Vector2(2, 2), GOLD)
	_rects.append([left, "pose_prev", 0])
	_rects.append([right, "pose_next", 0])
	_rects.append([Rect2(cx - 22.0, float(lay.feet) - 66.0, 44.0, 68.0), "pose", 0])


# the presets chooser: three slots with a name and a swatch strip, SAVE HERE / LOAD each, CANCEL
func _draw_presets(lay: Dictionary, size: Vector2) -> void:
	var x0: float = lay.x0
	var pitch: float = lay.pitch
	draw_rect(Rect2(x0 - 4.0, float(lay.y0) - 1.0, size.x - x0 - 4.0, pitch * float(Look.PRESET_SLOTS + 3) + 1.0), PANEL)
	_txt("PRESETS", Vector2(x0, float(lay.y0) + floorf((pitch - 5.0) * 0.5)), GOLD)
	for s in Look.PRESET_SLOTS:
		var y := _row_y(lay, s)
		var p: Dictionary = Look.preset(s)
		var hot := _pre_row == s
		var ty := y + floorf((pitch - 5.0) * 0.5)
		_txt(str(s + 1), Vector2(x0, ty), GOLD if hot else DIM)
		var box := Rect2(x0 + 8.0, y + 1.0, 50.0, pitch - 3.0)
		draw_rect(box, INK)
		draw_rect(box, GOLD if hot else DIM, false, 1.0)
		_txt(str(p.get("name", "EMPTY")), Vector2(box.position.x + 3.0, ty), Color.WHITE if not p.is_empty() else DIM)
		if not p.is_empty():
			for k in Look.ROLES.size():
				var role: String = Look.ROLES[k]
				draw_rect(Rect2(x0 + 62.0 + float(k) * 6.0, ty - 1.0, 5.0, 7.0), Color.html(str(p[role])))
		_chip(Rect2(x0 + 98.0, y + 1.0, 22.0, pitch - 3.0), "SAVE", hot and _pre_col == 0, "pre_save", s)
		_chip(Rect2(x0 + 122.0, y + 1.0, 22.0, pitch - 3.0), "LOAD", hot and _pre_col == 1, "pre_load", s)
	var cy := _row_y(lay, Look.PRESET_SLOTS)
	_chip(Rect2(x0, cy + 1.0, 44.0, pitch - 3.0), "CANCEL", _pre_row == Look.PRESET_SLOTS, "pre_cancel", 0)


# the pad's letter grid
func _draw_name_grid(lay: Dictionary, size: Vector2) -> void:
	var x0: float = lay.x0
	var pitch: float = lay.pitch
	var cw := minf(26.0, floorf((size.x - x0 - 8.0) / float(GRID_COLS)))
	draw_rect(Rect2(x0 - 4.0, float(lay.y0) - 1.0, cw * float(GRID_COLS) + 8.0, pitch * 5.0 + 1.0), PANEL)
	var who := str(Look.look.get("name", ""))
	var box := Rect2(x0, float(lay.y0) + 1.0, 62.0, pitch - 3.0)
	draw_rect(box, INK)
	draw_rect(box, GOLD, false, 1.0)
	_txt(who + ("_" if who.length() < Look.MAX_NAME else ""), Vector2(box.position.x + 4.0, box.position.y + floorf((box.size.y - 5.0) * 0.5)), Color.WHITE)
	var cells := grid_cells()
	for i in cells.size():
		var c: Dictionary = cells[i]
		var r := Rect2(x0 + float(c.col) * cw, _row_y(lay, int(c.row)) + 1.0, float(c.span) * cw - 2.0, pitch - 3.0)
		_chip(r, str(c.label), i == _grid_i, "gcell", i, Color(0.1, 0.13, 0.2, 0.9) if i == _grid_i else PANEL)


func _draw_phones(size: Vector2, narrow: bool) -> void:
	var ph := 54.0 if size.y <= 130.0 else (80.0 if not narrow else 92.0)
	var pw := floorf(ph * 0.52)
	var top := 22.0 if size.y <= 130.0 else (26.0 if not narrow else 56.0)
	for i in 2:
		var ios := i == 0
		var x := floorf(size.x * 0.5) + (-pw - 16.0 if ios else 16.0)
		var b := Rect2(x, top, pw, ph)
		var hot := phone_sel == i
		_rects.append([Rect2(b.position - Vector2(6, 4), b.size + Vector2(12, 16)), "phone", i])
		if hot:
			draw_rect(Rect2(b.position - Vector2(3, 3), b.size + Vector2(6, 6)), GOLD)
		draw_rect(b, Color("9aa0a8") if ios else Color("3a3d44"))
		draw_rect(
			Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)),
			Color("1c1e23") if ios else Color("0e0f12")
		)
		var scr := Rect2(
			b.position.x + 3,
			b.position.y + (7 if ios else 5),
			b.size.x - 6,
			b.size.y - (19 if ios else 9)
		)
		draw_rect(scr, Color("4a78d6") if ios else Color("0b2742"))
		draw_rect(
			Rect2(scr.position.x + 2, scr.position.y + 3, scr.size.x - 4, 3), Color(1, 1, 1, 0.5)
		)
		if ios:
			draw_circle(Vector2(b.position.x + pw * 0.5, b.end.y - 6), 2, Color("55595f"))
		else:
			draw_rect(Rect2(scr.position.x, scr.end.y - 3, scr.size.x, 3), Color("000000"))
		var label: String = PHONES[i].name
		_txt(
			label,
			Vector2(floorf(x + (pw - float(PixelFont.width(label))) * 0.5), b.end.y + 5),
			Color.WHITE if hot else DIM
		)
	_para(str(PHONES[phone_sel].blurb), top + ph + 16.0, Color.WHITE, 3)
