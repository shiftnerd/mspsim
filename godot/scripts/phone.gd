extends CanvasLayer
# The cell phone (2013): press P. The first time you pick iFone 5 (slate phone, iOS-style look) or Nexxus 5
# (Android-style look); the choice is saved and can be changed in Settings. Like the computer it
# takes over the screen (the office stays visible in a faded strip at the top). Apps: Mail (the
# same inbox as Outlookish), Tickets (a small ConnectWhy PSA: look, take, note), Texts (dispatch
# and the boss text you about urgent tickets) and Settings. The phone is on cellular, so it still
# works when the office network is down. Everything is drawn in code with the pixel font.

const PixelFont := preload("res://scripts/pixelfont.gd")
const SAVE := "user://mspsim_phone.cfg"
const INK := Color("17121f")
const WHITE := Color("ffffff")
const RED := Color("e0463c")
const GREEN := Color("3cc15a")
const NOTES := ["Texted the client back.", "On my way in.", "Looking at it from my phone."]

var is_open := false
var os := ""  # "ios" or "android"; "" = not chosen yet
var app := "home"
var mail_sel := -1
var tk_sel := -1
var txt_open := false
var home_sel := 0  # keyboard selection on the home screen (0 mail, 1 tickets, 2 texts, 3 settings)
const HOME_APPS := ["mail", "tickets", "texts", "settings"]

var _canvas: Node2D
var _hits: Array = []
var _mouse := Vector2.ZERO
var _fade := 0.0
var _sc := 1
var _toast := ""
var _toast_t := 0.0
var _blink := 0.0


func _ready() -> void:
	layer = 61
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	Msp.changed.connect(_refresh)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		os = str(cfg.get_value("phone", "os", ""))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("phone", "os", os)
	cfg.save(SAVE)


# the phone chosen on the character select screen (same saved preference as the first-open picker)
func set_os(value: String) -> void:
	os = value
	_save()


func open() -> void:
	if is_open or Game.ui_open or Game.busy or Game.title_mode:
		return
	app = "home" if os != "" else "choose"
	mail_sel = -1
	tk_sel = -1
	txt_open = false
	is_open = true
	Game.ui_open = true
	_canvas.visible = true
	_mouse = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	create_tween().tween_method(_set_fade, _fade, 1.0, 0.2)


func close() -> void:
	is_open = false
	Game.ui_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween()
	tween.tween_method(_set_fade, _fade, 0.0, 0.15)
	tween.tween_callback(func() -> void: _canvas.visible = is_open)


func _set_fade(value: float) -> void:
	_fade = value
	Game.ui_shift = value
	_canvas.modulate.a = value


func _refresh() -> void:
	if is_open:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	_blink += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	if is_open and _blink > 0.4:
		_blink = 0.0
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			open()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		_mouse = get_viewport().get_mouse_position()
		_canvas.queue_redraw()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_mouse = get_viewport().get_mouse_position()
		click(_mouse)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				back()
			KEY_P:
				close()
			KEY_UP:
				move(-1)
			KEY_DOWN:
				move(1)
			KEY_LEFT, KEY_RIGHT:
				if app == "choose":
					activate("os:" + ("android" if event.keycode == KEY_RIGHT else "ios"))
				elif app == "home":
					home_move(1 if event.keycode == KEY_RIGHT else -1)
			KEY_ENTER, KEY_KP_ENTER:
				enter()
	else:
		return
	get_viewport().set_input_as_handled()


# ---- actions (also used by the tests) ----------------------------------------
func click(at: Vector2) -> void:
	for i in range(_hits.size() - 1, -1, -1):
		var h: Dictionary = _hits[i]
		if h.r.has_point(at):
			activate(h.id)
			return


func back() -> void:
	if app == "home" or app == "choose":
		close()
	elif app == "mail" and mail_sel >= 0:
		mail_sel = -1
	elif app == "tickets" and tk_sel >= 0:
		tk_sel = -1
	elif app == "texts" and txt_open:
		txt_open = false
	else:
		app = "home"
	_canvas.queue_redraw()


func home_move(step: int) -> void:
	home_sel = clampi(home_sel + step, 0, HOME_APPS.size() - 1)
	_canvas.queue_redraw()


func move(step: int) -> void:
	if app == "home":
		home_move(step * 2)  # two icons per row
		return
	if app == "mail":
		mail_sel = clampi(mail_sel + step, 0, maxi(0, Msp.emails.size() - 1))
	elif app == "tickets":
		var list := Msp.open_tickets()
		if not list.is_empty():
			var at := 0
			for i in list.size():
				if list[i].id == tk_sel:
					at = i
			tk_sel = list[clampi(at + step, 0, list.size() - 1)].id
	_canvas.queue_redraw()


func enter() -> void:
	if app == "choose":
		activate("os:ios")
	elif app == "home":
		activate("app:" + str(HOME_APPS[home_sel]))
	elif app == "mail" and mail_sel >= 0:
		activate("mail:%d" % mail_sel)


func activate(id: String) -> void:
	var parts := id.split(":")
	match parts[0]:
		"os":
			os = parts[1]
			_save()
			app = "home"
		"app":
			app = parts[1]
			mail_sel = -1
			tk_sel = -1
			txt_open = false
			if app == "texts":
				for m in Msp.texts:
					m.unread = false
		"home":
			app = "home"
		"back":
			back()
		"mail":
			mail_sel = int(parts[1])
			Msp.emails[mail_sel].unread = false
		"tk":
			tk_sel = int(parts[1])
		"take":
			Msp.set_status(tk_sel, "In Progress")
			_say("TICKET #%d TAKEN" % tk_sel)
		"note":
			Msp.add_note(tk_sel, NOTES[randi() % NOTES.size()])
			_say("NOTE ADDED")
		"txt":
			txt_open = true
		"reply":
			_say("TEXT SENT")
		"desk":
			_say("CLOSING TICKETS NEEDS A COMPUTER")
	_canvas.queue_redraw()


func _say(text: String) -> void:
	_toast = text
	_toast_t = 2.5


# ---- drawing helpers ---------------------------------------------------------
func _fill(r: Rect2, c: Color) -> void:
	_canvas.draw_rect(r, c)


func _text(s: String, p: Vector2, c: Color = INK, scale := -1) -> void:
	PixelFont.draw(_canvas, s, p, c, _sc if scale < 0 else scale)


func _tw(s: String) -> float:
	return float(PixelFont.width(s, _sc))


func _chars(width: float) -> int:
	return maxi(4, int(width / (4.0 * _sc)))


func _clip(s: String, chars: int) -> String:
	return s if s.length() <= chars else s.substr(0, maxi(1, chars - 1)) + "."


func _wrap(s: String, chars: int) -> Array:
	var lines := []
	var line := ""
	for word in s.split(" "):
		if line != "" and line.length() + 1 + word.length() > chars:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	lines.append(line)
	return lines


func _region(id: String, r: Rect2) -> void:
	_hits.append({"r": r, "id": id})


func _round(r: Rect2, c: Color) -> void:
	# a rect with its four corner pixels cut off
	_fill(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), c)
	_fill(Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), c)


func _disc(center: Vector2, rad: int, c: Color) -> void:
	for dy in range(-rad, rad + 1):
		var w := int(sqrt(float(rad * rad - dy * dy)) + 0.5)
		_fill(Rect2(center.x - w, center.y + dy, w * 2 + 1, 1), c)


func _is_ios() -> bool:
	return os == "ios"


# ---- the whole screen --------------------------------------------------------
func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_hits.clear()
	_fill(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.7))
	var top := maxf(12.0, floorf(size.y * Game.UI_STRIP))
	_fill(Rect2(0, top - 1, size.x, 1), Color("0d1018"))
	if app == "choose":
		_paint_choose(Rect2(0, top, size.x, size.y - top))
		_cursor()
		return
	# the phone gets as much screen as it can (a little wider than the real one) so text fits
	var ptop := maxf(12.0, floorf(size.y * 0.17))
	var avail := size.y - ptop - 6.0
	var pw := minf(avail * 0.68, size.x - 8.0)
	var ph := minf(avail, pw / 0.68)
	var body := Rect2(
		floorf((size.x - pw) * 0.5), ptop + 3.0 + floorf((avail - ph) * 0.5), floorf(pw), floorf(ph)
	)
	_sc = 2 if body.size.x >= 118.0 else 1
	var screen := _skin(body)
	_paint_screen(screen)
	if _toast_t > 0.0:
		var tx := screen.position.x + floorf((screen.size.x - _tw(_toast)) * 0.5)
		_fill(
			Rect2(tx - 3, screen.end.y - 22 * _sc, _tw(_toast) + 6, 7 * _sc + 2),
			Color(0, 0, 0, 0.8)
		)
		_text(_toast, Vector2(tx, screen.end.y - 21 * _sc), WHITE)
	_cursor()


func _cursor() -> void:
	var m := _mouse.floor()
	for i in 6:
		_fill(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
	_fill(Rect2(m.x + 1, m.y + 2, 2, 2), WHITE)
	_fill(Rect2(m.x + 1, m.y + 1, 1, 1), WHITE)


# the phone body; returns the screen rect
func _skin(b: Rect2) -> Rect2:
	if _is_ios():
		_round(b, Color("9aa0a8"))  # aluminium edge
		_round(Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)), Color("1c1e23"))  # slate front
		_fill(
			Rect2(b.position.x + floorf(b.size.x * 0.5) - 5, b.position.y + 3, 10, 1),
			Color("55595f")
		)  # speaker
		_disc(
			Vector2(b.position.x + floorf(b.size.x * 0.5) + 8, b.position.y + 3), 1, Color("2e3138")
		)
		var hc := Vector2(b.position.x + floorf(b.size.x * 0.5), b.end.y - 6)
		_disc(hc, 3, Color("55595f"))
		_disc(hc, 2, Color("1c1e23"))
		_region("home", Rect2(hc - Vector2(4, 4), Vector2(9, 9)))
		return Rect2(b.position.x + 3, b.position.y + 7, b.size.x - 6, b.size.y - 7 - 12)
	_round(b, Color("3a3d44"))
	_round(Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)), Color("0e0f12"))  # matte black
	_fill(Rect2(b.position.x + floorf(b.size.x * 0.5) - 4, b.position.y + 2, 8, 1), Color("2a2c31"))
	return Rect2(b.position.x + 3, b.position.y + 5, b.size.x - 6, b.size.y - 5 - 4)


func _bar_h() -> float:
	return 7.0 * _sc


func _paint_screen(s: Rect2) -> void:
	var bg := _wallpaper(s) if app == "home" else _app_bg(s)
	_hits.append({"r": s, "id": "none"})
	var content := Rect2(s.position.x, s.position.y + _bar_h(), s.size.x, s.size.y - _bar_h())
	if not _is_ios():
		content.size.y -= 9.0 * _sc  # android nav bar
	_status_bar(s, bg)
	match app:
		"mail":
			_paint_mail(content)
		"tickets":
			_paint_tickets(content)
		"texts":
			_paint_texts(content)
		"settings":
			_paint_settings(content)
		_:
			_paint_home(content)
	if not _is_ios():
		_nav_bar(Rect2(s.position.x, s.end.y - 9.0 * _sc, s.size.x, 9.0 * _sc))


func _wallpaper(s: Rect2) -> bool:
	if _is_ios():
		for i in 12:
			var t := float(i) / 11.0
			_fill(
				Rect2(
					s.position.x,
					s.position.y + s.size.y * i / 12.0,
					s.size.x,
					s.size.y / 12.0 + 1.0
				),
				Color("2d6fd6").lerp(Color("a259c9"), t)
			)
	else:
		for i in 12:
			var t := float(i) / 11.0
			_fill(
				Rect2(
					s.position.x,
					s.position.y + s.size.y * i / 12.0,
					s.size.x,
					s.size.y / 12.0 + 1.0
				),
				Color("0b2742").lerp(Color("03060d"), t)
			)
		_fill(Rect2(s.position.x, s.position.y + s.size.y * 0.55, s.size.x, 1), Color("1d4f7a"))
	return true


func _app_bg(s: Rect2) -> bool:
	_fill(s, WHITE if _is_ios() else Color("f2f2f2"))
	return false


func _status_bar(s: Rect2, over_wallpaper: bool) -> void:
	var r := Rect2(s.position, Vector2(s.size.x, _bar_h()))
	var light := over_wallpaper or not _is_ios()
	if _is_ios():
		_fill(r, Color(0, 0, 0, 0.0) if over_wallpaper else Color("f7f7f9"))
	else:
		_fill(r, Color("000000"))
	var col := WHITE if light else INK
	var clock: String = World.clock_text()
	var y := r.position.y + _sc
	if _is_ios():
		for i in 5:
			_disc(
				Vector2(r.position.x + 3 + i * 2 * _sc, y + 2 * _sc),
				0 if _sc == 1 else 1,
				col if i < 4 else Color(col, 0.4)
			)
		_text(clock, Vector2(r.position.x + floorf((r.size.x - _tw(clock)) * 0.5), y), col)
		_fill(Rect2(r.end.x - 9 * _sc, y + _sc, 7 * _sc, 3 * _sc), col)
	else:
		_text(clock, Vector2(r.end.x - _tw(clock) - 2, y), col)
		_text("PITP", Vector2(r.position.x + 2, y), Color("9aa0a8"))
		_fill(Rect2(r.end.x - _tw(clock) - 4 - 6 * _sc, y + _sc, 4 * _sc, 3 * _sc), col)


func _nav_bar(r: Rect2) -> void:
	_fill(r, Color("000000"))
	var cy := r.position.y + r.size.y * 0.5
	var cx := r.position.x + r.size.x * 0.5
	var u := float(_sc)
	var nav := Color("e8e8e8")
	# back triangle, home circle, recents square
	for i in int(3 * u):
		_fill(Rect2(cx - r.size.x * 0.3 - 2 * u + i, cy - (3 * u - i), 1, (3 * u - i) * 2), nav)
	_fill(Rect2(cx - 2 * u, cy - 2 * u, 4 * u, 4 * u), Color("000000"))
	_disc(Vector2(cx, cy), int(2 * u), nav)
	_disc(Vector2(cx, cy), int(2 * u) - 1, Color("000000"))
	var sq := Rect2(cx + r.size.x * 0.3 - 2 * u, cy - 2 * u, 4 * u, 4 * u)
	_fill(sq, nav)
	_fill(Rect2(sq.position + Vector2(1, 1), sq.size - Vector2(2, 2)), Color("000000"))
	_region("back", Rect2(r.position.x, r.position.y, r.size.x * 0.34, r.size.y))
	_region("home", Rect2(r.position.x + r.size.x * 0.34, r.position.y, r.size.x * 0.33, r.size.y))


# ---- first run: pick a phone -------------------------------------------------
func _paint_choose(a: Rect2) -> void:
	_sc = 1
	var t := "PICK YOUR PHONE"
	_text(t, Vector2(floorf(a.position.x + (a.size.x - _tw(t)) * 0.5), a.position.y + 6), WHITE)
	var sub := "(YOU CAN CHANGE IT IN SETTINGS)"
	_text(
		sub,
		Vector2(floorf(a.position.x + (a.size.x - _tw(sub)) * 0.5), a.position.y + 14),
		Color("9aa8c0")
	)
	var h := minf(a.size.y - 40.0, 90.0)
	var w := floorf(h * 0.52)
	for i in 2:
		var ios := i == 0
		var x: float = floorf(a.position.x + a.size.x * 0.5) + (-w - 14 if ios else 14)
		var b := Rect2(x, a.position.y + 24, w, h)
		var hot := b.has_point(_mouse) or (_blink < 0.2 and false)
		_round(
			Rect2(b.position - Vector2(2, 2), b.size + Vector2(4, 4)),
			Color("e8c34a") if hot else Color(0, 0, 0, 0)
		)
		_round(b, Color("9aa0a8") if ios else Color("3a3d44"))
		_round(
			Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)),
			Color("1c1e23") if ios else Color("0e0f12")
		)
		var scr := Rect2(
			b.position.x + 3,
			b.position.y + (7 if ios else 5),
			b.size.x - 6,
			b.size.y - (19 if ios else 9)
		)
		_fill(scr, Color("4a78d6") if ios else Color("0b2742"))
		_fill(Rect2(scr.position.x + 2, scr.position.y + 3, scr.size.x - 4, 3), Color(1, 1, 1, 0.5))
		if ios:
			_disc(Vector2(b.position.x + w * 0.5, b.end.y - 6), 2, Color("55595f"))
		else:
			_fill(Rect2(scr.position.x, scr.end.y - 3, scr.size.x, 3), Color("000000"))
		var label: String = "IFONE 5" if ios else "NEXXUS 5"
		_text(label, Vector2(floorf(x + (w - _tw(label)) * 0.5), b.end.y + 5), WHITE)
		_region(
			"os:" + ("ios" if ios else "android"),
			Rect2(b.position - Vector2(4, 4), Vector2(w + 8, h + 20))
		)


# ---- home --------------------------------------------------------------------
func _icon(kind: String, r: Rect2) -> void:
	var cols := {
		"mail": Color("3b8df0"),
		"tickets": Color("f0a030"),
		"texts": Color("3cc15a"),
		"settings": Color("8b919c")
	}
	if _is_ios():
		_round(r, cols[kind])
	else:
		_fill(
			Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2),
			Color(cols[kind], 0.9)
		)
	var c := r.get_center()
	var u := float(_sc)
	match kind:
		"mail":
			_fill(Rect2(c.x - 4 * u, c.y - 2.5 * u, 8 * u, 5 * u), WHITE)
			for i in int(4 * u):
				_fill(Rect2(c.x - 4 * u + i, c.y - 2.5 * u + i * 0.6, 1, 1), Color("5a6a85"))
				_fill(Rect2(c.x + 3 * u - i, c.y - 2.5 * u + i * 0.6, 1, 1), Color("5a6a85"))
		"tickets":
			_fill(Rect2(c.x - 3 * u, c.y - 4 * u, 6 * u, 8 * u), WHITE)
			for i in 3:
				_fill(Rect2(c.x - 2 * u, c.y - 2.5 * u + i * 2.5 * u, 4 * u, u), Color("c98a1c"))
		"texts":
			_fill(Rect2(c.x - 4 * u, c.y - 3 * u, 8 * u, 5 * u), WHITE)
			_fill(Rect2(c.x - 3 * u, c.y + 2 * u, 2 * u, 2 * u), WHITE)
		_:
			_disc(c, int(3 * u), WHITE)
			_disc(c, int(u), cols["settings"])


func _paint_home(a: Rect2) -> void:
	var items := [
		["mail", "MAIL", Msp.unread()],
		["tickets", "TICKETS", Msp.open_tickets().size()],
		["texts", "TEXTS", Msp.unread_texts()],
		["settings", "SETTINGS", 0]
	]
	var isz := 12.0 * _sc
	var cell_w := floorf(a.size.x / 2.0)
	for i in items.size():
		var cx := a.position.x + (i % 2) * cell_w + floorf((cell_w - isz) * 0.5)
		var cy := a.position.y + 6 * _sc + (i / 2) * (isz + 12 * _sc)
		var r := Rect2(cx, cy, isz, isz)
		if i == home_sel:
			_fill(Rect2(r.position - Vector2(3, 2), Vector2(isz + 6, isz + 10 * _sc)), Color(1, 1, 1, 0.35))
		_icon(items[i][0], r)
		var label: String = items[i][1]
		if _tw(label) > cell_w - 2.0:
			label = {"TICKETS": "TKTS", "SETTINGS": "SETUP", "TEXTS": "TEXT"}.get(label, label)
		_text(label, Vector2(floorf(cx + (isz - _tw(label)) * 0.5), cy + isz + _sc * 2), WHITE)
		if items[i][2] > 0:
			_disc(Vector2(r.end.x, r.position.y), 2 * _sc + 1, RED)
			if _sc == 1:
				_text(str(mini(9, items[i][2])), Vector2(r.end.x - 1, r.position.y - 2), WHITE)
		_region(
			"app:" + items[i][0],
			Rect2(r.position - Vector2(4, 3), Vector2(isz + 8, isz + 13 * _sc))
		)
	# dock (iOS) or search bar (Android)
	if _is_ios():
		_fill(Rect2(a.position.x, a.end.y - 14 * _sc, a.size.x, 14 * _sc), Color(1, 1, 1, 0.22))
		var label := "PIXEL IT PARTNERS" if _chars(a.size.x - 4) >= 17 else "PIXEL IT"
		_text(
			_clip(label, _chars(a.size.x - 4)), Vector2(a.position.x + 3, a.end.y - 9 * _sc), WHITE
		)
	else:
		var bar := Rect2(a.position.x + 3, a.end.y - 12 * _sc, a.size.x - 6, 8 * _sc)
		_fill(bar, Color("eeeeee"))
		_text("GOOGOL", bar.position + Vector2(3, 1.5 * _sc), Color("4a7bd0"))


# ---- shared app chrome -------------------------------------------------------
func _header(a: Rect2, title: String, can_back: bool) -> Rect2:
	var h := 9.0 * _sc
	var bar := Rect2(a.position.x, a.position.y, a.size.x, h)
	_fill(bar, Color("f7f7f9") if _is_ios() else Color("33b5e5"))
	if _is_ios():
		_fill(Rect2(bar.position.x, bar.end.y - 1, bar.size.x, 1), Color("c8c8cc"))
	var col := INK if _is_ios() else WHITE
	_text(
		_clip(title, _chars(a.size.x - 24 * _sc)),
		Vector2(
			(
				(
					bar.position.x
					+ floorf((bar.size.x - _tw(_clip(title, _chars(a.size.x - 24 * _sc)))) * 0.5)
				)
				if _is_ios()
				else bar.position.x + 3 + (6 * _sc if can_back else 0)
			),
			bar.position.y + 2 * _sc
		),
		col
	)
	if can_back:
		if _is_ios():
			_text("<", Vector2(bar.position.x + 2, bar.position.y + 2 * _sc), Color("2b79f0"))
		else:
			_text("<", Vector2(bar.position.x + 2, bar.position.y + 2 * _sc), WHITE)
		_region("back", Rect2(bar.position, Vector2(14 * _sc, h)))
	return Rect2(a.position.x, a.position.y + h, a.size.x, a.size.y - h)


func _row(r: Rect2, alt: bool) -> void:
	var col := WHITE if not alt else Color("f1f1f4")
	if r.has_point(_mouse):
		col = Color("dce8fa")
	_fill(r, col)
	_fill(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color("d8d8dc"))


# ---- mail --------------------------------------------------------------------
func _paint_mail(a: Rect2) -> void:
	var body := _header(a, "INBOX" if mail_sel < 0 else "MESSAGE", mail_sel >= 0)
	if mail_sel >= 0 and mail_sel < Msp.emails.size():
		var m: Dictionary = Msp.emails[mail_sel]
		var chars := _chars(body.size.x - 6)
		_fill(body, WHITE)
		var sender := str(m.from).split(" <")[0]
		_text(
			_clip(sender, chars),
			body.position + Vector2(3, 3 * _sc),
			Color("2b79f0") if _is_ios() else Color("0a7ea4")
		)
		var subject := _wrap(str(m.subject), chars)
		var n := mini(2, subject.size())
		for i in n:
			_text(str(subject[i]), body.position + Vector2(3, (11 + 7 * i) * _sc), INK)
		var top_y := (12 + 7 * n) * _sc
		var lines := _wrap(m.body, chars)
		for i in mini(lines.size(), int((body.size.y - top_y - 3 * _sc) / (7.0 * _sc))):
			_text(lines[i], body.position + Vector2(3, top_y + i * 7 * _sc), Color("46506a"))
		return
	var rh := 15.0 * _sc
	for i in mini(int(body.size.y / rh), Msp.emails.size()):
		var m: Dictionary = Msp.emails[i]
		var rr := Rect2(body.position.x, body.position.y + i * rh, body.size.x, rh)
		_row(rr, i % 2 == 1)
		if m.unread:
			_disc(rr.position + Vector2(3, rh * 0.5), maxi(1, _sc), Color("2b79f0"))
		var chars := _chars(rr.size.x - 10)
		_text(_clip(str(m.from).split(" <")[0], chars), rr.position + Vector2(8, 2 * _sc), INK)
		_text(_clip(m.subject, chars), rr.position + Vector2(8, 2 * _sc + 7 * _sc), Color("7d8595"))
		_region("mail:%d" % i, rr)


# ---- tickets -----------------------------------------------------------------
func _pri_color(pri: int) -> Color:
	return [RED, Color("e07b22"), Color("e0a030"), Color("7d8aa0")][clampi(pri, 1, 4) - 1]


func _mmss(secs: float) -> String:
	var s := maxi(0, int(secs))
	return "%d:%02d" % [s / 60, s % 60]


func _paint_tickets(a: Rect2) -> void:
	var t := Msp.ticket(tk_sel) if tk_sel >= 0 else {}
	var body := _header(a, "TICKETS" if t.is_empty() else "#%d" % t.id, not t.is_empty())
	if not t.is_empty():
		_paint_ticket(body, t)
		return
	var list := Msp.open_tickets()
	var rh := 15.0 * _sc
	for i in mini(int(body.size.y / rh), list.size()):
		var k: Dictionary = list[i]
		var rr := Rect2(body.position.x, body.position.y + i * rh, body.size.x, rh)
		_row(rr, i % 2 == 1)
		_fill(Rect2(rr.position.x, rr.position.y, 2, rh - 1), _pri_color(k.pri))
		var chars := _chars(rr.size.x - 8)
		_text(_clip(k.summary, chars), rr.position + Vector2(5, 2 * _sc), INK)
		var late: bool = k.breached or k.sla_left < 30.0
		var left := "LATE" if k.breached else _mmss(k.sla_left)
		var who := "PITP" if k.client < 0 else str(Msp.CLIENTS[k.client].short)
		_text(
			who + " " + left,
			rr.position + Vector2(5, 2 * _sc + 7 * _sc),
			RED if late else Color("7d8595")
		)
		_region("tk:%d" % k.id, rr)
	if list.is_empty():
		_fill(body, WHITE)
		_text("NO OPEN TICKETS", body.position + Vector2(4, 6 * _sc), Color("8b93a1"))


func _paint_ticket(body: Rect2, t: Dictionary) -> void:
	_fill(body, WHITE)
	var chars := _chars(body.size.x - 6)
	var y := body.position.y + 3 * _sc
	_fill(Rect2(body.position.x, body.position.y, body.size.x, 2), _pri_color(t.pri))
	var info := [
		_clip(Msp.client_text(t), chars),
		"P%d  %s" % [t.pri, str(t.status).to_upper()],
		"SLA " + ("LATE" if t.breached else _mmss(t.sla_left))
	]
	for s in info:
		_text(s, Vector2(body.position.x + 3, y), Color("2b79f0") if s == info[0] else INK)
		y += 7 * _sc
	y += 2 * _sc
	var lines := _wrap(t.body, chars)
	var room := int((body.end.y - 24 * _sc - y) / (7.0 * _sc))
	for i in mini(lines.size(), maxi(1, room)):
		_text(lines[i], Vector2(body.position.x + 3, y), Color("46506a"))
		y += 7 * _sc
	var bw := floorf((body.size.x - 8) / 3.0)
	for i in 3:
		var id: String = ["take", "note", "desk"][i]
		var label: String = ["TAKE", "NOTE", "DONE"][i]
		var r := Rect2(body.position.x + 2 + i * (bw + 2), body.end.y - 11 * _sc, bw, 9 * _sc)
		_fill(r, Color("2b79f0") if i < 2 else Color("9aa0a8"))
		_text(label, r.position + Vector2(floorf((bw - _tw(label)) * 0.5), 2 * _sc), WHITE)
		_region(id, r)


# ---- texts -------------------------------------------------------------------
func _paint_texts(a: Rect2) -> void:
	var body := _header(a, "MESSAGES", false)
	_fill(body, WHITE)
	var chars := _chars(body.size.x - 10)
	var y := body.position.y + 3 * _sc
	var bubble := Color("2b79f0") if _is_ios() else Color("33b5e5")
	var bottom := body.end.y - 10 * _sc  # the REPLY bar
	for k in Msp.texts.size():
		var m: Dictionary = Msp.texts[Msp.texts.size() - 1 - k]  # newest first
		var lines := _wrap(m.body, chars)
		var h := (lines.size() * 7 + 11) * _sc
		if y + h > bottom:
			if k > 0:
				break
			# the newest text always shows, cut to the lines that fit
			var room := int((bottom - y - 9 * _sc - 2) / (7 * _sc))
			lines = lines.slice(0, maxi(1, room))
			h = (lines.size() * 7 + 11) * _sc
		_text(_clip(m.from, chars), Vector2(body.position.x + 3, y), Color("7d8595"))
		var r := Rect2(
			body.position.x + 3, y + 7 * _sc, body.size.x - 6, lines.size() * 7 * _sc + 2
		)
		_round(r, Color("e5e5ea") if _is_ios() else Color("dcdcdc"))
		for j in lines.size():
			_text(lines[j], r.position + Vector2(2, 1 + j * 7 * _sc), INK)
		y += h + 2 * _sc
	if Msp.texts.is_empty():
		_text("NO MESSAGES", body.position + Vector2(4, 6 * _sc), Color("8b93a1"))
	_fill(Rect2(body.position.x, body.end.y - 10 * _sc, body.size.x, 10 * _sc), Color("f1f1f4"))
	_text("REPLY", Vector2(body.position.x + 3, body.end.y - 8 * _sc), bubble)
	_region("reply", Rect2(body.position.x, body.end.y - 10 * _sc, body.size.x, 10 * _sc))


# ---- settings ----------------------------------------------------------------
func _paint_settings(a: Rect2) -> void:
	var body := _header(a, "SETTINGS", false)
	_fill(body, Color("f2f2f2"))
	var y := body.position.y + 3 * _sc
	_text("PHONE", Vector2(body.position.x + 3, y), Color("7d8595"))
	y += 8 * _sc
	for i in 2:
		var ios := i == 0
		var r := Rect2(body.position.x + 2, y + i * 11 * _sc, body.size.x - 4, 9 * _sc)
		_fill(r, Color("dce8fa") if (ios == _is_ios()) else WHITE)
		_text("IFONE 5" if ios else "NEXXUS 5", r.position + Vector2(3, 2 * _sc), INK)
		if ios == _is_ios():
			_text("*", Vector2(r.end.x - 6, r.position.y + 2 * _sc), Color("2b79f0"))
		_region("os:" + ("ios" if ios else "android"), r)
	y += 25 * _sc
	_text("NETWORK", Vector2(body.position.x + 3, y), Color("7d8595"))
	_text("CELLULAR 4G", Vector2(body.position.x + 3, y + 8 * _sc), INK)
	var note := _wrap("WORKS WITHOUT THE OFFICE NETWORK", _chars(body.size.x - 6))
	for i in note.size():
		_text(str(note[i]), Vector2(body.position.x + 3, y + (17 + 7 * i) * _sc), Color("7d8595"))
