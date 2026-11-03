extends Node2D
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
const GOLD := Color("f5d442")
const INK := Color("17121f")
const PANEL := Color(0.05, 0.07, 0.12, 0.85)
const DIM := Color("9aa8c0")
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
	"THE TECHNICAL OWNER. SERVERS, BACKUPS AND THE STACK ARE YOURS; GARRISON KEEPS THE CLIENTS HAPPY.",
	"casual_garrison":
	"THE SALES AND CULTURE OWNER. CLIENTS, PRICING AND MORALE ARE YOURS; ALAN KEEPS THE SERVERS ALIVE.",
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
var step := "char"  # "char" then (tech campaign only) "phone"
var ids: Array = []
var sel := 0
var phone_sel := 0
var facing := "right"
var _sprites: Array = []
var _rects: Array = []  # [Rect2, kind, index] for the mouse
var _born := -1


func _ready() -> void:
	_born = Engine.get_process_frames()
	Game.format_changed.connect(queue_redraw)
	queue_redraw()


func is_campaign() -> bool:
	return Campaign.MODES.has(mode)


func needs_phone() -> bool:
	return mode == "tech"


# who this mode offers: everyone in Free Play, Alan or Garrison in the owner campaign, only non-cast people in
# the tech campaign
func choices(for_mode: String) -> Array:
	if for_mode == "owner":
		return ["office_alan", "casual_garrison"]
	var cast: Array = []
	for n in World.CAST:
		cast.append(str(World.CAST[n].character))
	var out: Array = []
	for id in PLAYER.CHARACTERS:
		if Campaign.MODES.has(for_mode) and id in cast:
			continue
		out.append(id)
	return out


func setup(for_mode: String) -> void:
	mode = for_mode
	step = "char"
	ids = choices(mode)
	sel = maxi(0, ids.find(PLAYER.current_character))
	if not PLAYER.current_character in ids:
		sel = maxi(0, ids.find("office_adult"))
	phone_sel = 1 if Phone.os == "android" else 0
	Mutators.pending_start = Mutators.STANDARD
	Difficulty.roll_seed()  # the run seed is chosen here: shown on the SEED chip, X changes it
	facing = "right"
	for spr in _sprites:
		spr.queue_free()
	_sprites.clear()
	for id in ids:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = load("res://characters/%s.tres" % id)
		spr.play("idle_right")
		add_child(spr)
		_sprites.append(spr)
	queue_redraw()


func current_id() -> String:
	return str(ids[sel]) if sel < ids.size() else PLAYER.current_character


func info(id: String) -> Dictionary:
	var entry: Dictionary = PEOPLE.get(id, {"name": id.to_upper(), "blurb": ""}).duplicate()
	if mode == "owner" and OWNER_BLURBS.has(id):
		entry["blurb"] = OWNER_BLURBS[id]
	return entry


func summary(with_tier := true) -> String:
	var label: String = Campaign.MODES.get(mode, "FREE PLAY")
	var s := "%s - %s" % [label, str(info(current_id()).name)]
	if needs_phone():
		s += " - " + str(PHONES[phone_sel].name)
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


# Up / Down (or a click on the arrows) change the difficulty; it is remembered in the settings file
func change_tier(delta_tier: int) -> void:
	Difficulty.cycle_tier(delta_tier)
	Difficulty.save_settings()
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
	if step == "char" and needs_phone():
		step = "phone"
		queue_redraw()
		return
	var result := {
		"mode": mode,
		"character": current_id(),
		"phone": str(PHONES[phone_sel].id) if needs_phone() else "",
		"summary": summary(),
		"tier": Difficulty.tier,
	}
	PLAYER.current_character = current_id()
	if needs_phone():
		Phone.set_os(result.phone)
	done.emit(result)


func back() -> void:
	if step == "phone":
		step = "char"
		queue_redraw()
	else:
		cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _born or Toolbox.is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_X:
				open_seed()
			KEY_T:
				open_tools()
			KEY_F9:
				Game.cycle_format()
			KEY_LEFT, KEY_A:
				move(-1)
			KEY_RIGHT, KEY_D:
				move(1)
			KEY_UP, KEY_W:
				change_tier(1)
			KEY_DOWN, KEY_S:
				change_tier(-1)
			KEY_TAB:
				change_start(-1 if event.shift_pressed else 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
				confirm()
			KEY_ESCAPE, KEY_BACKSPACE:
				back()
			_:
				return
	elif event is InputEventMouseMotion:
		_hover(get_viewport().get_mouse_position())
		return
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_click(get_viewport().get_mouse_position())
	else:
		return
	get_viewport().set_input_as_handled()


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
	if kind == "item" and step == "char" and sel != int(r[2]):
		sel = int(r[2])
		queue_redraw()
	elif kind == "phone" and phone_sel != int(r[2]):
		phone_sel = int(r[2])
		queue_redraw()


func _click(at: Vector2) -> void:
	var r := _hit(at)
	if r.is_empty():
		return
	match str(r[1]):
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
	var heading := "CHOOSE YOUR CHARACTER" if step == "char" else "PICK YOUR PHONE"
	_ctxt(heading, 22.0 if narrow else 6.0, GOLD)
	var back_r := Rect2(3.0, 3.0, 28.0, 9.0)
	draw_rect(back_r, PANEL)
	_txt("< ESC", back_r.position + Vector2(2, 2), DIM)
	_rects.append([back_r, "back", 0])
	_draw_tier(size, narrow)
	_draw_seed(size, narrow)
	if is_campaign() and step == "char":
		_draw_start(size, narrow)
	if step == "char":
		_draw_chars(size, narrow)
	else:
		_place_sprites(size, narrow)
		_draw_phones(size, narrow)
	_ctxt(
		summary(false),
		size.y - (34.0 if narrow else (18.0 if size.y <= 130.0 else 19.0)),
		Color.WHITE
	)
	var extra := "T TOOLS" if mode == "free" else "TAB START"
	var hint := "LEFT RIGHT CHOOSE  UP DOWN LEVEL  %s  X SEED  ENTER PICK  ESC BACK" % extra
	if narrow:
		_ctxt("LEFT RIGHT CHOOSE   UP DOWN LEVEL", size.y - 20.0, DIM)
		_ctxt("%s  X SEED  ENTER  ESC" % extra, size.y - 12.0, DIM)
	else:
		_ctxt(hint, size.y - 9.0, DIM)


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


func _place_sprites(size: Vector2, narrow: bool) -> void:
	var n := ids.size()
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
	var data := info(current_id())
	var name_y := feet + (12.0 if narrow else 10.0)
	_ctxt(str(data.name), name_y, GOLD)
	var by := name_y + (20.0 if narrow else 9.0)
	var end_y := _para(str(data.blurb), by, Color.WHITE, 4 if narrow else 2)
	if is_campaign():
		var note := "THE REST OF THE TEAM IS ALREADY AT THEIR DESKS"
		if Mutators.pending_start != Mutators.STANDARD:
			note = str(Mutators.STARTS.get(Mutators.pending_start, {}).get("text", note)).to_upper()
		if end_y + 8.0 < size.y - (46.0 if narrow else 28.0):
			_para(note, end_y + 2.0, DIM, 2)


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
