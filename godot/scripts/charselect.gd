extends Node2D
# Character select / first-day screen, shown by the title menu before a new run starts. A row of
# the playable characters (a carousel in narrow portrait) with an idle preview, a name and a short
# blurb; the tech campaign then asks for your phone. Left / Right move, Enter / E / Space confirm,
# Esc goes back, mouse hover and click work like the title menu. Confirming applies the choice
# (Player.current_character, Phone.os) and emits done(result); Esc on the first step emits
# cancelled. In the campaigns the cast members (Alan, Garrison, Dan, Vic ...) are already at
# their desks as NPCs, so only the people who are not in World.CAST are offered; Free Play
# offers everyone.

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
	{"name": "ALAN", "blurb": "RED SHIRT, GREEN VEST, SERVER ROOM REGULAR. WATCHES THE BACKUPS."},
	"site_alan":
	{
		"name": "ALAN - ON SITE",
		"blurb": "ALAN IN THE GRAY WORK POLO. VAN KEYS, CABLE TESTER, NO TIME TO CHAT."
	},
	"casual_garrison":
	{
		"name": "GARRISON",
		"blurb": "TEAL PLAID AND A GOATEE. SECURITY MINDED, ALWAYS TIME FOR A CHAT."
	},
	"sales_vic":
	{
		"name": "VIC",
		"blurb": "ACCOUNT MANAGER IN A JACKET AND RED TIE. A DEAL IS ALWAYS ABOUT TO CLOSE."
	},
}
const PHONES := [
	{
		"id": "ios",
		"name": "IPHONE 5",
		"blurb": "SLATE, IOS 7, ONE HOME BUTTON. EVERYONE ELSE'S SCREEN IS CRACKED."
	},
	{
		"id": "android",
		"name": "NEXUS 5",
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


# who this mode offers: everyone in Free Play, only non-cast people in a campaign
func choices(for_mode: String) -> Array:
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
	return PEOPLE.get(id, {"name": id.to_upper(), "blurb": ""})


func summary() -> String:
	var label: String = Campaign.MODES.get(mode, "FREE PLAY")
	var s := "%s - %s" % [label, str(info(current_id()).name)]
	if needs_phone():
		s += " - " + str(PHONES[phone_sel].name)
	return s


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
	if Engine.get_process_frames() == _born:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F9:
				Game.cycle_format()
			KEY_LEFT, KEY_A:
				move(-1)
			KEY_RIGHT, KEY_D:
				move(1)
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
	if step == "char":
		_draw_chars(size, narrow)
	else:
		_place_sprites(size, narrow)
		_draw_phones(size, narrow)
	_ctxt(
		summary(), size.y - (34.0 if narrow else (18.0 if size.y <= 130.0 else 19.0)), Color.WHITE
	)
	var hint := "LEFT RIGHT CHOOSE   ENTER PICK   ESC BACK"
	if narrow:
		_ctxt("LEFT RIGHT CHOOSE", size.y - 20.0, DIM)
		_ctxt("ENTER PICK   ESC BACK", size.y - 12.0, DIM)
	else:
		_ctxt(hint, size.y - 9.0, DIM)


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
