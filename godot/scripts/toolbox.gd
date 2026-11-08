extends CanvasLayer
# gdlint:disable=max-line-length
# Free Play toolbox and the run seed panel (roadmap R10 part a). Two small modal pages on one canvas:
#
#   Toolbox.open_seed(on_close)        the SEED page: type or paste hex (4F2A9C) or any word, RANDOM, TODAY <date>
#   Toolbox.open_tools(in_title, cb)   the TOOLBOX page: pick a game and its parameters, the seed, FIXED TAKE, a mutator
#   Toolbox.launch()                   start the chosen game with the chosen parameters (tests call this too)
#
# The toolbox is opened from the character select screen of Free Play (T key or the TOOLBOX chip; GO there starts Free
# Play and launches the game once the room is up) and in Free Play with Shift+F10. It only calls the public functions
# of the games: Outings.start(id, false, options), PrinterGame.start(callback, model, options), Nerf.start_war() and
# Mutators.set_forced(). Rows by game:
#   KARAOKE  SONG      the tier's pick (the card at the mic) or one of Outings.SONGS by title (even a locked one)
#   ESCAPE   DIGITS    the tier's code length, 3 or 4;  BOARD / CLOCK / PLAQUE / SHELF  ANY or one of that zone's
#            recipes (Outings.RECIPES: a digit the recipe can show is dealt); the rest of the deal comes from the seed
#   DINNER   TABLE     all three, or two of Alan, Garrison and Dan
#   PRINTER  MODEL     the six printer models (a fixed take plays the practice set of the seed, so the questions repeat)
# FIXED TAKE (Difficulty.fixed_take): every launch restarts all random streams (and the global generator) from the
# seed, mutators are off and so is the ` chooser, and the campaign event deck never runs. Retakes match.
# Keys: Up / Down row, Left / Right change, Enter (GO, SEED), Esc closes. The mouse works on every row: the left half
# of a row steps back, the right half steps forward.

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const CharSelect := preload("res://scripts/charselect.gd")
const GAMES := ["", "bowling", "karaoke", "escape", "dinner", "printer", "nerf", "chair", "cornhole", "grill", "darts"]
const GAME_LABELS := {
	"": "NONE",
	"bowling": "BOWLING",
	"karaoke": "KARAOKE",
	"escape": "ESCAPE ROOM",
	"dinner": "DINNER",
	"printer": "PRINTER",
	"nerf": "NERF WAR",
	"chair": "CHAIR RACE",
	"cornhole": "CORNHOLE",
	"grill": "COOKOUT",
	"darts": "DARTS",
}
const TABLES := [[], ["Alan", "Garrison"], ["Alan", "Dan"], ["Garrison", "Dan"]]
const TABLE_LABELS := ["ALL THREE", "ALAN GARRISON", "ALAN DAN", "GARRISON DAN"]
const CHARTS := 4
const SETS := 9
const MAX_TEXT := 12

var is_open := false
var outfit_open := false  # the Free Play outfit overlay (open_outfit): the create step over the room
var outfit_slot := 0  # whose look the overlay edits (co-op: player 2 swaps Look's working copy for theirs while it is open)
var mode := "tools"  # "tools" or "seed"
var in_title := false  # opened from the character select screen: GO starts Free Play
var queued := false  # GO on the title: launch once Free Play is running
var game_i := 0
var song_i := 0  # 0 = the usual pick, else index + 1 into Outings.SONGS
var digits := 0  # 0 = the tier's, else 3 or 4
var recipe_i := {"board": 0, "clock": 0, "plaque": 0, "shelf": 0}  # 0 = any, else index + 1 into Outings.RECIPES[zone]
var table_i := 0
var model_i := 0
var mutator := ""
var sel := 0
var seed_buf := ""
var seed_focus := 0  # 0 text field, 1 RANDOM, 2 TODAY
var last_launch := {}  # what the last launch() started (tests): {game, options}

var _on_close := Callable()
var _canvas: Node2D
var _rects: Array = []  # [Rect2, kind, index]
var _was_ui := false
var _outfit: Node = null  # the CharSelect in overlay mode
var _outfit_was_ui := false
var _outfit_was_custom := false  # the player was the custom person when the overlay opened
var _outfit_char := ""  # ... and this character otherwise
var _outfit_prev_look := {}  # co-op: slot 1's stored look when the overlay opened
var _outfit_stash := {}  # co-op: player 1's Look snapshot while the overlay edits slot 1's
var _under_tools := false  # the seed page was opened from the toolbox page


func _ready() -> void:
	layer = 72
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	Game.format_changed.connect(_canvas.queue_redraw)


# ---- the settings ------------------------------------------------------------------------------
func game_id() -> String:
	return str(GAMES[game_i])


func model_id() -> String:
	return str(PrinterGame.MODEL_ORDER[model_i])


# the options handed to Outings.start for the chosen game
func outing_options() -> Dictionary:
	var out := {}
	match game_id():
		"karaoke":
			if song_i > 0:
				out["song"] = str(Outings.SONGS[song_i - 1].id)
		"escape":
			if digits > 0:
				out["digits"] = digits
			var recipes := {}
			for zone in Outings.CLUE_ZONES:
				var at := int(recipe_i.get(zone, 0))
				if at > 0:
					recipes[zone] = str(Outings.RECIPES[zone][at - 1])
			if not recipes.is_empty():
				out["recipes"] = recipes
		"dinner":
			if table_i > 0:
				out["table"] = TABLES[table_i].duplicate()
	return out


func printer_options() -> Dictionary:
	if Difficulty.fixed_take:
		return {"practice": true, "seed": 1 + Difficulty.run_seed % 99}
	return {}


func set_fixed_take(on: bool) -> void:
	Difficulty.fixed_take = on
	if on:
		mutator = ""
		Mutators.set_forced("")
		Difficulty.take_reset()
		seed(Difficulty.run_seed)


# start the chosen game; returns false when nothing is chosen or the game cannot start now
func launch() -> bool:
	var id := game_id()
	if id == "" or Outings.is_open or PrinterGame.is_open:
		return false
	_apply_mutator()
	if Difficulty.fixed_take:
		Difficulty.take_reset()
		seed(Difficulty.run_seed)
	var options := outing_options()
	last_launch = {"game": id, "options": options}
	match id:
		"printer":
			PrinterGame.start(_printer_done, model_id(), printer_options())
			last_launch["options"] = printer_options()
			last_launch["model"] = model_id()
		"nerf":
			Nerf.start_war()
		_:
			Outings.start(id, false, options)
	return true


func _printer_done(stars: int) -> void:
	Hints.toast("PRINTER: %d OF 3 STARS" % stars, 3.0)


func _apply_mutator() -> void:
	if Campaign.active or Game.title_mode:
		return
	Mutators.set_forced("" if Difficulty.fixed_take else mutator)


# called when Free Play has started from the title: the chosen mutator, then the queued game
func after_start() -> void:
	if Campaign.active:
		Difficulty.fixed_take = false
		return
	_apply_mutator()
	if not queued:
		return
	queued = false
	await get_tree().create_timer(1.2).timeout
	launch()


# ---- opening and closing ----------------------------------------------------------------------------
func can_open() -> bool:
	return not is_open and not Game.title_mode and not Campaign.active and not Game.ui_open


func open_tools(from_title := false, on_close := Callable()) -> void:
	if is_open:
		return
	if not from_title and not can_open():
		return
	in_title = from_title
	queued = false
	mutator = Mutators.forced if not from_title else mutator
	_show("tools", on_close)
	sel = clampi(sel, 0, rows().size() - 1)


# ---- the Free Play outfit swap (R15 level 3 step e) ---------------------------------------------------
func _player() -> Node:
	var scene := get_tree().current_scene
	return Players.player0(scene) if scene != null else null


func can_outfit(slot := 0) -> bool:
	var who := _player() if slot == 0 else Players.node(slot)
	return can_open() and not outfit_open and Campaign.mode == Campaign.FREE and not Game.busy and who != null


# Free Play only: Y (not F8: the debug builds jump to a room on it) or the pause menu's OUTFIT row. The create step opens over the room, the preview and the player wear every
# change live, DONE keeps the look (saved as the default look in the settings file), Esc puts the old person back. Game.ui_open holds
# the player and the pause menu off meanwhile, and is given back as it was.
func open_outfit(slot := 0) -> bool:
	if not can_outfit(slot):
		return false
	outfit_slot = slot
	var who := _player() if slot == 0 else Players.node(slot)
	_outfit_was_custom = Look.is_custom()
	_outfit_char = str(who.current_character)
	if slot > 0:
		var s: Object = Players.slot(slot)
		_outfit_was_custom = not s.look.is_empty()
		_outfit_char = str(s.character)
		_outfit_prev_look = s.look.duplicate()
		_outfit_stash = Look.snapshot()
		Look.look = Look.sanitize(s.look) if _outfit_was_custom else Look.default_look()
		Look.acc = Look.sanitize_acc(s.look.get("acc", {})) if _outfit_was_custom else Look.default_acc()
	_outfit_was_ui = Game.ui_open
	Game.ui_open = true
	outfit_open = true
	_outfit = CharSelect.new()
	add_child(_outfit)
	_outfit.slot = slot
	_outfit.setup_overlay()
	_outfit.look_changed.connect(_outfit_live)
	_outfit.done.connect(_outfit_done)
	_outfit.cancelled.connect(_outfit_cancelled)
	_outfit_live()
	return true


# every change in the overlay is worn by the player at once (sheet, palette, HeadGear)
func _outfit_live() -> void:
	var who := _player() if outfit_slot == 0 else Players.node(outfit_slot)
	if who != null:
		if outfit_slot > 0:
			Players.slot(outfit_slot).look = Look.copy_look()
		who.wear_look()


func _close_outfit() -> void:
	outfit_open = false
	if outfit_slot > 0:
		Look.restore(_outfit_stash)  # player 1's own look is back in the working copy
	Game.ui_open = _outfit_was_ui
	if _outfit != null:
		_outfit.queue_free()
		_outfit = null


func _outfit_done(_result: Dictionary) -> void:
	_outfit_live()  # (player 2's look is stored from the working copy before it is swapped back)
	_close_outfit()
	if outfit_slot == 0:
		Campaign.refresh_free()  # the cast member you were walks back to their desk
	Hints.toast("NEW LOOK", 1.5)


func _outfit_cancelled() -> void:
	_close_outfit()
	var who := _player() if outfit_slot == 0 else Players.node(outfit_slot)
	if outfit_slot > 0 and who != null:
		Players.slot(outfit_slot).look = _outfit_prev_look
		if _outfit_was_custom:
			who.wear_look()
		else:
			who._reload_sheet(_outfit_char)
	elif who != null:
		if _outfit_was_custom:
			who.wear_look()  # Look.restore already put the old look back
		else:
			who._switch_character(_outfit_char)


func open_seed(on_close := Callable()) -> void:
	if is_open:
		return
	seed_buf = ""
	seed_focus = 0
	_show("seed", on_close)


func _show(for_mode: String, on_close: Callable) -> void:
	mode = for_mode
	_on_close = on_close
	_was_ui = Game.ui_open
	Game.ui_open = true
	is_open = true
	_canvas.visible = true
	_canvas.queue_redraw()


func close(go := false) -> void:
	if not is_open:
		return
	if mode == "seed" and _under_tools:  # back to the toolbox page
		_under_tools = false
		mode = "tools"
		_canvas.queue_redraw()
		return
	is_open = false
	_canvas.visible = false
	Game.ui_open = _was_ui
	var cb := _on_close
	_on_close = Callable()
	if cb.is_valid():
		cb.call(go)


# ---- seed page ---------------------------------------------------------------------------------------
func type_char(ch: String) -> void:
	if seed_buf.length() < MAX_TEXT:
		seed_buf += ch.to_upper()
		_canvas.queue_redraw()


func backspace() -> void:
	seed_buf = seed_buf.substr(0, maxi(0, seed_buf.length() - 1))
	_canvas.queue_redraw()


func paste() -> void:
	var clip := DisplayServer.clipboard_get().strip_edges().to_upper()
	for i in clip.length():
		var c := clip[i]
		if (c >= "0" and c <= "9") or (c >= "A" and c <= "Z") or c in ["#", "-", "_"]:
			type_char(c)


# apply the typed text; an empty field keeps the current seed. Returns the seed now in force.
func seed_commit() -> int:
	var v := Difficulty.parse_seed(seed_buf)
	if v > 0:
		Difficulty.seed_run(v)
	if Difficulty.fixed_take:
		Difficulty.take_reset()
	return Difficulty.run_seed


func seed_random() -> int:
	Difficulty.roll_seed()
	return Difficulty.run_seed


func seed_today() -> int:
	return Difficulty.use_daily()


func _seed_act(which: int) -> void:
	match which:
		0:
			seed_commit()
		1:
			seed_random()
		_:
			seed_today()
	close(false)


# ---- the toolbox rows --------------------------------------------------------------------------------
func rows() -> Array:
	var out := [{"id": "game", "label": "GAME", "value": str(GAME_LABELS[game_id()])}]
	match game_id():
		"karaoke":
			var title := "CARD AT MIC" if song_i == 0 else str(Outings.SONGS[song_i - 1].title)
			out.append({"id": "song", "label": "SONG", "value": title})
		"escape":
			out.append({"id": "digits", "label": "CODE DIGITS", "value": "TIER" if digits == 0 else str(digits)})
			for zone in Outings.CLUE_ZONES.slice(0, digits if digits > 0 else maxi(3, Difficulty.i("escape.digits"))):
				var at := int(recipe_i.get(zone, 0))
				out.append({"id": "rec_" + str(zone), "label": str(zone).to_upper(), "value": "ANY" if at == 0 else str(Outings.RECIPES[zone][at - 1]).to_upper()})
		"dinner":
			out.append({"id": "table", "label": "TABLE", "value": str(TABLE_LABELS[table_i])})
		"printer":
			out.append({"id": "model", "label": "MODEL", "value": str(PrinterGame.MODELS[model_id()].label)})
	var tag := "DAILY " + Difficulty.seed_text() if Difficulty.daily != "" else Difficulty.seed_text()
	out.append({"id": "seed", "label": "SEED", "value": tag})
	out.append({"id": "take", "label": "FIXED TAKE", "value": "ON" if Difficulty.fixed_take else "OFF"})
	if not Difficulty.fixed_take:
		var name := "NONE"
		if mutator != "" and Mutators.MUTATORS.has(mutator):
			name = str(Mutators.MUTATORS[mutator].get("name", mutator)).to_upper()
		out.append({"id": "mutator", "label": "MUTATOR", "value": name})
	var go := "START FREE PLAY" if in_title else ("GO" if game_id() != "" else "CLOSE")
	out.append({"id": "go", "label": "", "value": go})
	return out


func current_row() -> Dictionary:
	var list := rows()
	return list[clampi(sel, 0, list.size() - 1)]


func move_row(step: int) -> void:
	var n := rows().size()
	sel = (sel + step + n) % n
	_canvas.queue_redraw()


# Left / Right (or a click) on the selected row
func change(step: int) -> void:
	match str(current_row().id):
		"game":
			game_i = (game_i + step + GAMES.size()) % GAMES.size()
			sel = 0
		"song":
			song_i = (song_i + step + Outings.SONGS.size() + 1) % (Outings.SONGS.size() + 1)
		"digits":
			digits = [0, 3, 4][([0, 3, 4].find(digits) + step + 3) % 3]
		"table":
			table_i = (table_i + step + TABLES.size()) % TABLES.size()
		"model":
			model_i = (model_i + step + PrinterGame.MODEL_ORDER.size()) % PrinterGame.MODEL_ORDER.size()
		"take":
			set_fixed_take(not Difficulty.fixed_take)
		_ when str(current_row().id).begins_with("rec_"):
			var zone := str(current_row().id).substr(4)
			var n: int = Outings.RECIPES[zone].size() + 1
			recipe_i[zone] = (int(recipe_i[zone]) + step + n) % n
		"mutator":
			var ids: Array = [""]
			ids.append_array(Mutators.ids_for("tech"))
			var at := ids.find(mutator)
			mutator = str(ids[(maxi(at, 0) + step + ids.size()) % ids.size()])
		"seed":
			if step != 0:
				seed_random()
	sel = clampi(sel, 0, rows().size() - 1)
	_canvas.queue_redraw()


# Enter on the selected row
func activate() -> void:
	match str(current_row().id):
		"seed":
			seed_buf = ""
			seed_focus = 0
			_under_tools = true
			mode = "seed"
			_canvas.queue_redraw()
		"go":
			if in_title:
				queued = game_id() != ""
				close(true)
			elif game_id() == "":
				close(false)
			else:
				close(false)
				launch()
		_:
			change(1)


# ---- input -----------------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10 and event.shift_pressed:
		if can_open() and Campaign.mode == Campaign.FREE:
			open_tools()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and Controls.matches(event, "outfit"):
		if open_outfit():
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and Controls.matches(event, "career"):
		if can_open() and not Game.busy:  # Free Play only (a campaign has the phone's Settings)
			Career.open_screen()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _outfit != null:  # the outfit overlay owns every key and click (nothing reaches the room behind it)
		_outfit._unhandled_input(event)
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if Controls.pressed(event):
		_key(event)
	elif event is InputEventMouseMotion:
		_hover(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
	get_viewport().set_input_as_handled()


func _key(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F9:
		Game.cycle_format()
		return
	if mode == "seed":
		if event is InputEventKey:
			_seed_key(event)
		else:
			_seed_pad(event)
		return
	var dir := Controls.nav(event)
	if dir == "up":
		move_row(-1)
	elif dir == "down":
		move_row(1)
	elif dir == "left":
		change(-1)
	elif dir == "right":
		change(1)
	elif Controls.confirm(event):
		activate()
	elif Controls.back(event):
		close(false)


# the seed entry from a pad: Up / Down move the focus, A presses the focused button, B closes (typing is keyboard only)
func _seed_pad(event: InputEvent) -> void:
	var dir := Controls.nav(event)
	if dir == "down":
		seed_focus = (seed_focus + 1) % 3
	elif dir == "up":
		seed_focus = (seed_focus + 2) % 3
	elif dir == "left" and seed_focus > 0:
		seed_focus = 1
	elif dir == "right" and seed_focus > 0:
		seed_focus = 2
	elif Controls.confirm(event):
		_seed_act(seed_focus)
	elif Controls.back(event):
		close(false)
		return
	_canvas.queue_redraw()


func _seed_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			close(false)
		KEY_ENTER, KEY_KP_ENTER:
			_seed_act(seed_focus)
		KEY_TAB, KEY_DOWN:
			seed_focus = (seed_focus + 1) % 3
			_canvas.queue_redraw()
		KEY_UP:
			seed_focus = (seed_focus + 2) % 3
			_canvas.queue_redraw()
		KEY_LEFT:
			if seed_focus > 0:
				seed_focus = 1
				_canvas.queue_redraw()
		KEY_RIGHT:
			if seed_focus > 0:
				seed_focus = 2
				_canvas.queue_redraw()
		KEY_BACKSPACE:
			backspace()
		KEY_V:
			if event.ctrl_pressed:
				paste()
			elif seed_focus == 0:
				type_char("V")
		_:
			if seed_focus == 0 and event.unicode > 32 and event.unicode < 127 and not event.ctrl_pressed:
				var c := char(event.unicode).to_upper()
				if (c >= "0" and c <= "9") or (c >= "A" and c <= "Z") or c in ["#", "-", "_"]:
					type_char(c)


func _hit(at: Vector2) -> Array:
	for r in _rects:
		if r[0].has_point(at):
			return r
	return []


func _hover(at: Vector2) -> void:
	var r := _hit(at)
	if r.is_empty():
		return
	if str(r[1]) == "row" and sel != int(r[2]):
		sel = int(r[2])
		_canvas.queue_redraw()
	elif str(r[1]) == "focus" and seed_focus != int(r[2]):
		seed_focus = int(r[2])
		_canvas.queue_redraw()


func _click(at: Vector2) -> void:
	var r := _hit(at)
	if r.is_empty():
		return
	match str(r[1]):
		"row":
			sel = int(r[2])
			var rect: Rect2 = r[0]
			var id := str(current_row().id)
			if id in ["go", "seed"]:
				activate()
			else:
				change(1 if at.x >= rect.position.x + rect.size.x * 0.5 else -1)
		"focus":
			seed_focus = int(r[2])
			if seed_focus > 0:
				_seed_act(seed_focus)
			else:
				_canvas.queue_redraw()


# ---- drawing ---------------------------------------------------------------------------------------
func _size() -> Vector2:
	return Vector2(Game.FORMATS[Game.format].size)


func _paint() -> void:
	_rects.clear()
	var size := _size()
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.05, 0.6))
	if mode == "seed":
		_paint_seed(size)
	else:
		_paint_tools(size)


func _paint_tools(size: Vector2) -> void:
	var list := rows()
	var h := 12.0 + 9.0 * float(list.size()) + 12.0
	var r := UiStyle.panel_rect(size, 300.0, h)
	var body := UiStyle.panel(_canvas, r, "FREE PLAY TOOLBOX", "SHIFT F10" if not in_title else "")
	var label_w := 52.0
	for i in list.size():
		var row: Dictionary = list[i]
		var y := body.position.y + 9.0 * float(i)
		var rect := Rect2(body.position.x - 2.0, y - 1.0, body.size.x + 4.0, 9.0)
		_rects.append([rect, "row", i])
		var hot := i == sel
		if hot:
			_canvas.draw_rect(rect, UiStyle.SOFT)
		var id := str(row.id)
		var value := str(row.value)
		if id == "go":
			var w := float(PixelFont.width(value)) + 12.0
			var gr := Rect2(rect.position.x + floorf((rect.size.x - w) * 0.5), y - 1.0, w, 9.0)
			_canvas.draw_rect(gr, UiStyle.GREEN if hot else UiStyle.MUTED)
			UiStyle.center(_canvas, value, gr.position.x + w * 0.5, y + 1.0, UiStyle.WHITE)
			continue
		UiStyle.text(_canvas, str(row.label), body.position.x, y + 1.0, UiStyle.INK)
		var vx := body.position.x + label_w
		var vw := body.size.x - label_w
		UiStyle.center(_canvas, value, vx + vw * 0.5, y + 1.0, UiStyle.HEAD if hot else UiStyle.INK)
		if hot and id != "seed":
			UiStyle.text(_canvas, "<", vx, y + 1.0, UiStyle.GOLD)
			UiStyle.text(_canvas, ">", vx + vw - 5.0, y + 1.0, UiStyle.GOLD)
	var hint := "UP DOWN ROW  LEFT RIGHT CHANGE  ENTER  ESC CLOSE"
	if r.size.x < 250.0:
		hint = "ARROWS  ENTER  ESC"
	UiStyle.footer(_canvas, r, hint)


func _paint_seed(size: Vector2) -> void:
	var r := UiStyle.panel_rect(size, 220.0, 70.0)
	var body := UiStyle.panel(_canvas, r, "RUN SEED", "NOW " + Difficulty.seed_text())
	var field := Rect2(body.position.x, body.position.y + 1.0, body.size.x, 11.0)
	_canvas.draw_rect(field, UiStyle.WHITE)
	_canvas.draw_rect(field, UiStyle.HEAD if seed_focus == 0 else UiStyle.SOFT, false, 1.0)
	var shown := seed_buf
	if shown == "" and seed_focus != 0:
		shown = "HEX OR ANY WORD"
	var caret := "_" if (seed_focus == 0 and int(Time.get_ticks_msec() / 400) % 2 == 0) else ""
	UiStyle.text(_canvas, shown + caret, field.position.x + 3.0, field.position.y + 2.0, UiStyle.INK if seed_buf != "" else UiStyle.MUTED)
	_rects.append([field, "focus", 0])
	var labels := ["RANDOM", "TODAY " + Difficulty.date_label()]
	var x := body.position.x
	var by := body.position.y + 16.0
	for k in 2:
		var w := float(PixelFont.width(labels[k])) + 10.0
		var br := Rect2(x, by, w, 11.0)
		_canvas.draw_rect(br, UiStyle.HEAD if seed_focus == k + 1 else UiStyle.MUTED)
		UiStyle.text(_canvas, labels[k], br.position.x + 5.0, by + 2.0, UiStyle.WHITE)
		_rects.append([br, "focus", k + 1])
		x += w + 4.0
	if Difficulty.daily != "":
		UiStyle.text(_canvas, "DAILY SEED RUN", body.position.x, by + 15.0, UiStyle.GREEN)
	var hint := "TYPE OR PASTE  TAB  ENTER OK  ESC"
	if r.size.x < 200.0:
		hint = "TYPE  TAB  ENTER  ESC"
	UiStyle.footer(_canvas, r, hint)
	if seed_focus == 0:  # keep the caret blinking
		_canvas.queue_redraw()
