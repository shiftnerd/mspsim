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

const PixelFont := preload("res://scripts/pixelfont.gd")
const PLAYER := preload("res://scripts/player.gd")
const BuildPanel := preload("res://scripts/build_panel.gd")
const GOLD := Color("f5d442")
const INK := Color("17121f")
const PANEL := Color(0.05, 0.07, 0.12, 0.85)
const DIM := Color("9aa8c0")
const FREE_MODE := "free"
const CUSTOM := "custom"  # the MAKE YOUR OWN card: the Look.BASE sheet in the player's own colours (R15, level 1)
const CREATE_ROWS := ["name", "style", "skin", "hair", "shirt", "pants", "shoes", "random"]
const CUSTOM_BLURB := "CHOOSE SKIN, HAIR, SHIRT, PANTS AND SHOES, THEN A NAME. A NEW HIRE, NOT ONE OF THE TEAM."
const PEOPLE := {
	"office_teen":
	{
		"name": "TEEN",
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
var create_row := 0  # the row of the create step (CREATE_ROWS)
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
	Toolbox.open_seed(func(_go: bool) -> void: queue_redraw())


# T (Free Play): the toolbox; GO there starts Free Play and launches the chosen game
func open_tools() -> void:
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
	if step == "build":
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
	if create_row == 0 and _type_key(event):
		queue_redraw()
		return true
	return _create_key(event, Controls.nav(event))


# the create step: Up / Down pick a row, Left / Right change it (the NAME row steps through suggested names, RANDOM rolls a
# person), Enter on RANDOM rolls, Enter on any other row goes on
func _create_key(event: InputEvent, dir: String) -> bool:
	if dir == "up":
		create_row = (create_row + CREATE_ROWS.size() - 1) % CREATE_ROWS.size()
	elif dir == "down":
		create_row = (create_row + 1) % CREATE_ROWS.size()
	elif dir == "left" or dir == "right":
		_create_change(-1 if dir == "left" else 1)
	elif Controls.confirm(event) and CREATE_ROWS[create_row] == "random":
		roll_look()
	else:
		return false
	queue_redraw()
	return true


func _create_change(delta: int) -> void:
	var role: String = CREATE_ROWS[create_row]
	if role == "name":
		Look.cycle_name(delta)
	elif role == "style":
		Look.cycle_style(delta)
	elif role == "random":
		roll_look()
	else:
		Look.set_swatch(role, maxi(0, Look.swatch_index(role)) + delta)
	_refresh_look()


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


func roll_look() -> void:
	Look.randomize_look()
	_refresh_look()


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
	elif step == "create" and kind in ["sw", "row", "name_prev", "name_next", "style_prev", "style_next", "random"]:
		var row := _create_row_of(r)
		if row != create_row:
			create_row = row
			queue_redraw()
	elif kind == "item" and step == "char" and sel != int(r[2]):
		sel = int(r[2])
		queue_redraw()
	elif kind == "phone" and phone_sel != int(r[2]):
		phone_sel = int(r[2])
		queue_redraw()


# the create row a mouse rect belongs to
func _create_row_of(r: Array) -> int:
	match str(r[1]):
		"sw":
			return floori(float(r[2]) / 100.0)
		"row":
			return int(r[2])
		"random":
			return CREATE_ROWS.size() - 1
		"style_prev", "style_next":
			return CREATE_ROWS.find("style")
	return 0


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
		"sw":
			create_row = floori(float(r[2]) / 100.0)
			Look.set_swatch(str(CREATE_ROWS[create_row]), int(r[2]) % 100)
			_refresh_look()
		"row":
			create_row = int(r[2])
			queue_redraw()
		"name_prev", "name_next":
			create_row = 0
			Look.cycle_name(-1 if str(r[1]) == "name_prev" else 1)
			_refresh_look()
		"style_prev", "style_next":
			create_row = CREATE_ROWS.find("style")
			Look.cycle_style(-1 if str(r[1]) == "style_prev" else 1)
			_refresh_look()
		"random":
			create_row = CREATE_ROWS.size() - 1
			roll_look()
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.08, 0.9))
	var heading: String = {"char": "CHOOSE YOUR CHARACTER", "create": "MAKE YOUR OWN PERSON", "phone": "PICK YOUR PHONE"}.get(step, "BUILD YOUR CHARACTER")
	_ctxt(heading, 22.0 if narrow else 6.0, GOLD)
	var back_r := Rect2(3.0, 3.0, 28.0, 9.0)
	draw_rect(back_r, PANEL)
	_txt("< ESC", back_r.position + Vector2(2, 2), DIM)
	_rects.append([back_r, "back", 0])
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
	_draw_summary(size, narrow)
	var extra := "T TOOLS" if mode == "free" else ("TAB START M MUT B BAN" if Yeartwo.pending else "TAB START")
	if step == "create":
		if narrow:
			_ctxt("UP DOWN ROW  LEFT RIGHT CHANGE", size.y - 20.0, DIM)
			_ctxt("TYPE NAME  ENTER GO  ESC BACK", size.y - 12.0, DIM)
		else:
			_ctxt("UP DOWN ROW  LEFT RIGHT CHANGE  TYPE NAME  ENTER GO  ESC BACK", size.y - 9.0, DIM)
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
			if i == sel and cs.animation != "idle_" + facing:
				cs.play("idle_" + facing)
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


# where the create step puts the preview (cx, feet) and the rows (x0, y0, pitch): wide 368x128, h 320x180, v 180x320
func _create_layout(size: Vector2, narrow: bool) -> Dictionary:
	if narrow:
		return {"cx": size.x * 0.5, "feet": 116.0, "x0": 8.0, "y0": 128.0, "pitch": 14.0}
	if size.y <= 130.0:
		return {"cx": 52.0, "feet": 98.0, "x0": 104.0, "y0": 17.0, "pitch": 11.0}
	return {"cx": 60.0, "feet": 130.0, "x0": 116.0, "y0": 28.0, "pitch": 17.0}


# the create step (R15): a name row, one swatch row per colour, and a RANDOM / DONE row; the preview is live
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
	for i in CREATE_ROWS.size():
		var role: String = CREATE_ROWS[i]
		var y: float = float(lay.y0) + float(i) * pitch
		var hot := i == create_row
		var sy := y + floorf((pitch - sw) * 0.5)
		var ty := sy + floorf((sw - 5.0) * 0.5)
		if hot:
			draw_rect(Rect2(x0 - 3.0, y, sx + cell * 12.0 - x0 + 3.0, pitch - 1.0), PANEL)
		if role == "name":
			_txt("NAME", Vector2(x0, ty), GOLD if hot else DIM)
			var box := Rect2(sx + 8.0, sy, 49.0, sw)
			draw_rect(box, INK)
			draw_rect(box, GOLD if hot else DIM, false, 1.0)
			var shown := who + ("_" if hot and who.length() < Look.MAX_NAME else "")
			_txt(shown, Vector2(box.position.x + 4.0, ty), Color.WHITE)
			_txt("<", Vector2(sx, ty), GOLD)
			_txt(">", Vector2(box.end.x + 3.0, ty), GOLD)
			_rects.append([Rect2(sx - 2.0, y, 10.0, pitch), "name_prev", 0])
			_rects.append([Rect2(box.end.x + 1.0, y, 9.0, pitch), "name_next", 0])
		elif role == "style":
			_txt("STYLE", Vector2(x0, ty), GOLD if hot else DIM)
			var sbox := Rect2(sx + 8.0, sy, 49.0, sw)
			draw_rect(sbox, INK)
			draw_rect(sbox, GOLD if hot else DIM, false, 1.0)
			var st := str(Look.look.get("hair_style", Look.HAIR_STYLES[0])).to_upper()
			_txt(st, Vector2(floorf(sbox.position.x + (sbox.size.x - float(PixelFont.width(st))) * 0.5), ty), Color.WHITE)
			_txt("<", Vector2(sx, ty), GOLD)
			_txt(">", Vector2(sbox.end.x + 3.0, ty), GOLD)
			_rects.append([Rect2(sx - 2.0, y, 10.0, pitch), "style_prev", 0])
			_rects.append([Rect2(sbox.end.x + 1.0, y, 9.0, pitch), "style_next", 0])
		elif role == "random":
			var rr := Rect2(x0, sy - 1.0, 44.0, 9.0)
			draw_rect(rr, PANEL)
			draw_rect(rr, GOLD if hot else DIM, false, 1.0)
			_txt("RANDOM", Vector2(rr.position.x + 10.0, rr.position.y + 2.0), Color.WHITE)
			_rects.append([rr, "random", 0])
			var gr := Rect2(x0 + 50.0, sy - 1.0, 32.0, 9.0)
			draw_rect(gr, PANEL)
			draw_rect(gr, GOLD, false, 1.0)
			_txt("DONE", Vector2(gr.position.x + 8.0, gr.position.y + 2.0), GOLD)
			_rects.append([gr, "go", 0])
		else:
			_txt(role.to_upper(), Vector2(x0, ty), GOLD if hot else DIM)
			var list: Array = Look.SWATCHES[role]
			for j in list.size():
				var r := Rect2(sx + float(j) * cell, sy, sw, sw)
				draw_rect(r, Color.html(str(list[j])))
				draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
				if list[j] == Look.look[role]:
					draw_rect(r.grow(1.0), GOLD, false, 1.0)
				_rects.append([Rect2(r.position.x - 1.0, y, cell, pitch), "sw", i * 100 + j])
		_rects.append([Rect2(x0 - 3.0, y, sx + cell * 12.0 - x0 + 3.0, pitch), "row", i])


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
