extends CanvasLayer
# gdlint:disable=class-definitions-order
# The cell phone (2013): press P. The first time you pick iFone 5 (slate phone, iOS-style look) or Nexxus 5
# (Android-style look); the choice is saved and can be changed in Settings. Like the computer it
# takes over the screen (the office stays visible in a faded strip at the top). Apps: Mail (the
# same inbox as Outlookish), Tickets (a small ConnectWhy PSA: look, take, note), Texts (dispatch
# and the boss text you about urgent tickets) and Settings. The phone is on cellular, so it still
# works when the office network is down. Everything is drawn in code with the pixel font.

# R37: a lock screen (slide to unlock), a PHONE app (contacts, keypad, text-only calls) and notification banners
# on the HUD while the phone is closed (the banner is drawn by hud.gd from `banner` / `banner_slide()`).

const PixelFont := preload("res://scripts/pixelfont.gd")
const Calls := preload("res://scripts/phone_calls.gd")
var save_path := "user://mspsim_phone.cfg"  # tests point this somewhere else
const INK := Color("17121f")
const WHITE := Color("ffffff")
const RED := Color("e0463c")
const GREEN := Color("3cc15a")
const NOTES := ["Texted the client back.", "On my way in.", "Looking at it from my phone."]

var is_open := false
var pane_slot := -1  # co-op: this instance is the pane of that player (panes.gd); -1 = the full-window autoload
var os := ""  # "ios" or "android"; "" = not chosen yet
var app := "home"
var mail_sel := -1
var tk_sel := -1
var txt_open := false
var txt_scroll := 0  # how many of the newest texts are scrolled past (Up / Down / the wheel)
var home_sel := 0  # keyboard selection on the home screen (0 mail, 1 tickets, 2 texts, 3 settings, 4 the dock's PHONE)
const HOME_APPS := ["mail", "tickets", "texts", "settings", "phone"]
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
const DIAL_SECS := 1.2  # ringing before they pick up
const UNLOCK_SECS := 0.3
const BANNER_IN := 0.25
const BANNER_HOLD := 2.0
const BANNER_OUT := 0.25
const BANNER_MAX_QUEUE := 4
const FEED_MAX := 6
const KIND_COLORS := {
	"TEXT": Color("3cc15a"), "MAIL": Color("3b8df0"), "IM": Color("33b5e5"), "SLA": Color("e0463c")
}

var locked := false  # the lock screen shows until you slide to unlock (set on every open)
var unlock_t := -1.0  # 0..1 while the slide runs, -1 when idle
var ph_view := "contacts"  # the PHONE app: contacts | keypad (a call in progress is `dialog`)
var ph_sel := 0
var ph_scroll := 0
var kp_text := ""
var kp_sel := 4
var dialog: Dictionary = {}  # the call in progress: {contact, stage dial | talk | done, t, say, opts, voicemail}
var call_sel := 0
var call_cd: Dictionary = {}  # contact id -> game hour (day * 24 + clock) it takes calls again; saved
var call_n: Dictionary = {}  # contact id -> calls made; saved
var calls_made := 0
var feed: Array = []  # the latest notifications, newest first: {kind, who, body}
var banner: Dictionary = {}  # the banner on screen: {kind, who, body, t}
var buzz_count := 0

var _bq: Array = []
var _poll := 0.0
var _primed := false
var _mail_seen := -1
var _im_seen := {}
var _buzz_ms := -100000

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
	Msp.text_received.connect(_on_text)
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		os = str(cfg.get_value("phone", "os", ""))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("phone", "os", os)
	cfg.save(save_path)


# the phone chosen on the character select screen (same saved preference as the first-open picker)
func set_os(value: String) -> void:
	os = value
	_save()


# a new campaign starts with fresh call cooldowns (the campaign save keeps them in its `phone` section)
func reset() -> void:
	call_cd = {}
	call_n = {}
	calls_made = 0
	dialog = {}
	feed = []
	banner = {}
	_bq = []
	_primed = false


func to_dict() -> Dictionary:
	return {"cd": call_cd.duplicate(), "n": call_n.duplicate(), "calls": calls_made}


func from_dict(data: Dictionary) -> void:
	call_cd = (data.get("cd", {}) as Dictionary).duplicate()
	call_n = (data.get("n", {}) as Dictionary).duplicate()
	calls_made = int(data.get("calls", 0))


func open() -> void:
	if is_open or (Game.ui_open and pane_slot < 0) or Game.busy or Game.title_mode:
		return
	app = "home" if os != "" else "choose"
	locked = os != ""
	unlock_t = -1.0
	mail_sel = -1
	tk_sel = -1
	txt_open = false
	ph_view = "contacts"
	dialog = {}
	banner = {}  # the phone is in your hand now: the lock screen lists what came in
	_toast_t = 0.0
	is_open = true
	Sfx.play("ui_open")
	_set_ui(true)
	_canvas.visible = true
	_mouse = get_viewport().get_mouse_position()
	if pane_slot < 0:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	create_tween().tween_method(_set_fade, _fade, 1.0, 0.2)


func close() -> void:
	is_open = false
	dialog = {}  # closing the phone hangs up
	_set_ui(false)
	if pane_slot < 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween()
	tween.tween_method(_set_fade, _fade, 0.0, 0.15)
	tween.tween_callback(func() -> void: _canvas.visible = is_open)


# the global UI flag, or the pane owner's own (co-op, see computer.gd)
func _set_ui(on: bool) -> void:
	if pane_slot < 0:
		Game.ui_open = on
	else:
		Players.set_ui(pane_slot, on)


func _set_fade(value: float) -> void:
	_fade = value
	if pane_slot < 0:
		Game.ui_shift = value
	else:
		Players.pane_fade(pane_slot, value)
	_canvas.modulate.a = value


func _refresh() -> void:
	if is_open:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	_blink += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	_poll += delta
	if _poll >= 0.2:
		_poll = 0.0
		poll_notifications()
	step_banner(delta)
	var moving := false
	if unlock_t >= 0.0:
		moving = true
		unlock_t += delta / UNLOCK_SECS
		if unlock_t >= 1.0:
			unlock_t = -1.0
			locked = false
	if not dialog.is_empty():
		moving = true
		step_call(delta)
	if is_open and (moving or _blink > 0.4):
		_blink = 0.0
		_canvas.queue_redraw()


# ---- notifications (banner on the HUD while the phone is closed) --------------------------------
func _on_text(m: Dictionary) -> void:
	var body := str(m.body)
	notify("SLA" if body.contains("SLA") else "TEXT", str(m.from), body)


# new mail and new Lynk messages have no signal: look for them a few times a second
func poll_notifications() -> void:
	var top := -1 if Msp.emails.is_empty() else int(Msp.emails[0].id)
	var chats_now: Dictionary = Lync.unread
	if not _primed or Game.title_mode:
		_primed = not Game.title_mode
		_mail_seen = top
		_im_seen = chats_now.duplicate()
		return
	if top < _mail_seen:
		_mail_seen = top  # a new game emptied the inbox
	var fresh := []
	for m in Msp.emails:
		if int(m.id) <= _mail_seen:
			break
		fresh.append(m)
	_mail_seen = top
	fresh.reverse()
	for m in fresh:
		notify("MAIL", str(m.from).split(" <")[0], str(m.subject))
	for who in chats_now:
		if int(chats_now[who]) > int(_im_seen.get(who, 0)):
			var lines: Array = Lync.chats.get(who, [])
			var last := "" if lines.is_empty() else str(lines[lines.size() - 1][1])
			notify("SLA" if last.contains("SLA") else "IM", str(who), last)
	_im_seen = chats_now.duplicate()


# something arrived: remember it for the lock screen and show the banner if the phone is closed
func notify(kind: String, who: String, body: String) -> void:
	feed.push_front({"kind": kind, "who": who, "body": body})
	while feed.size() > FEED_MAX:
		feed.pop_back()
	if is_open or Game.title_mode:
		return
	_bq.append({"kind": kind, "who": who, "body": body, "t": 0.0})
	while _bq.size() > BANNER_MAX_QUEUE:
		_bq.pop_front()


# a modal that owns the top of the screen is up (cards, the day report...): banners wait their turn
func banner_blocked() -> bool:
	if Game.busy or Game.ui_open or Game.title_mode or not World.hud_visible:
		return true
	if DayReport.is_open or Cards.is_open or Review.is_open or PrinterGame.is_open:
		return true
	return Outings.is_open and not (Outings.room_mode() and Outings.phase == "play")


func banner_total() -> float:
	return BANNER_IN + BANNER_HOLD + BANNER_OUT


func step_banner(delta: float) -> void:
	if banner_blocked() or is_open:
		return
	if banner.is_empty():
		if _bq.is_empty():
			return
		banner = _bq.pop_front()
		buzz()
	banner.t = float(banner.t) + delta
	if float(banner.t) >= banner_total():
		banner = {}


# 0 = hidden above the screen, 1 = fully slid in
func banner_slide() -> float:
	if banner.is_empty():
		return 0.0
	var t := float(banner.t)
	if t < BANNER_IN:
		return t / BANNER_IN
	if t > BANNER_IN + BANNER_HOLD:
		return maxf(0.0, 1.0 - (t - BANNER_IN - BANNER_HOLD) / BANNER_OUT)
	return 1.0


# the vibrate buzz: quiet in the dark and after hours, and cozy Easy buzzes far less often
func buzz() -> void:
	var now := Time.get_ticks_msec()
	var gap := 15000 if Difficulty.cozy_on() else 2500
	if now - _buzz_ms < gap:
		return
	_buzz_ms = now
	if not World.lights_on(World._scene) or World.clock >= World.DAY_END:
		return
	buzz_count += 1
	Sfx.play("buzz", 0.6 if Difficulty.cozy_on() else 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open and Controls.pressed(event):
		if Controls.matches(event, "phone"):
			if Players.coop:  # co-op: the phone opens as the player's own pane
				Players.takeover_host().open_phone(0)
			else:
				open()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		_canvas.queue_redraw()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_mouse = event.position
		click(_mouse)
	elif (
		event is InputEventMouseButton
		and event.pressed
		and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN)
	):
		move(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	elif _dial_key(event):
		pass
	elif Controls.pressed(event):
		var dir := Controls.nav(event, false)
		if Controls.back(event, false):
			back()
		elif Controls.matches(event, "phone"):
			close()
		elif dir == "up":
			move(-1)
		elif dir == "down":
			move(1)
		elif dir == "left" or dir == "right":
			if app == "choose":
				activate("os:" + ("android" if dir == "right" else "ios"))
			elif app == "home" and not locked:
				home_move(1 if dir == "right" else -1)
			elif app == "settings":
				activate("ring")
			elif app == "phone" and ph_view == "keypad":
				kp_move(1 if dir == "right" else -1)
		elif Controls.confirm(event, false, false):
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
	if locked or app == "home" or app == "choose":
		close()
	elif app == "phone":
		if not dialog.is_empty():
			hang_up()
		elif ph_view != "contacts":
			ph_view = "contacts"
		else:
			app = "home"
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
	if locked:
		if step < 0 and not _is_ios():
			activate("unlock")  # Nexxus: swipe up
		return
	if app == "home":
		home_move(step * 2)  # two icons per row
		return
	if app == "phone":
		if not dialog.is_empty():
			call_sel = clampi(call_sel + step, 0, maxi(0, (dialog.opts as Array).size() - 1))
		elif ph_view == "keypad":
			kp_move(step * 3)
		else:
			var n := Calls.contacts().size()
			ph_sel = clampi(ph_sel + step, 0, maxi(0, n - 1))
			ph_scroll = clampi(ph_scroll, ph_sel - 20, ph_sel)  # _paint_contacts trims it to the rows that fit
		_canvas.queue_redraw()
		return
	if app == "mail":
		mail_sel = clampi(mail_sel + step, 0, maxi(0, Msp.emails.size() - 1))
	elif app == "texts":
		txt_scroll = clampi(txt_scroll + step, 0, maxi(0, Msp.texts.size() - 1))
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
	if locked and app != "choose":
		activate("unlock")
	elif app == "choose":
		activate("os:ios")
	elif app == "phone":
		if not dialog.is_empty():
			activate("opt:%d" % call_sel)
		elif ph_view == "keypad":
			activate("key:%d" % kp_sel if kp_sel < 12 else ("del" if kp_sel == 12 else "dial"))
		else:
			activate("call:%d" % ph_sel)
	elif app == "home":
		activate("app:" + str(HOME_APPS[home_sel]))
	elif app == "settings":
		activate("career")
	elif app == "mail" and mail_sel >= 0:
		activate("mail:%d" % mail_sel)


func activate(id: String) -> void:
	var parts := id.split(":")
	if parts[0] != "none" and parts[0] != "unlock":
		locked = false  # anything you do wakes the phone past the lock screen
	match parts[0]:
		"unlock":
			if locked and unlock_t < 0.0:
				unlock_t = 0.0
				Sfx.play("ui_open", 0.5)
		"os":
			os = parts[1]
			_save()
			app = "home"
		"app":
			app = parts[1]
			mail_sel = -1
			tk_sel = -1
			txt_open = false
			txt_scroll = 0
			if app == "phone":
				ph_view = "contacts"
				dialog = {}
			if app == "texts":
				for m in Msp.texts:
					m.unread = false
		"call":
			start_call(Calls.contacts()[clampi(int(parts[1]), 0, Calls.contacts().size() - 1)])
		"opt":
			choose(int(parts[1]))
		"keypad":
			ph_view = "keypad"
			kp_sel = 4
		"contacts":
			ph_view = "contacts"
		"key":
			press_key(KEYS[clampi(int(parts[1]), 0, KEYS.size() - 1)])
		"del":
			kp_text = kp_text.substr(0, maxi(0, kp_text.length() - 1))
		"dial":
			dial_number()
		"home":
			app = "home"
		"ring":
			Career.cycle_pick("ringtone")
		"career":
			close()
			Career.open_screen()
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


# ---- the PHONE app: keypad and text-only calls ---------------------------------------------------
func kp_move(step: int) -> void:
	if absi(step) == 3:
		if step > 0:
			kp_sel = 12 if kp_sel in [9, 10] else (13 if kp_sel == 11 else mini(kp_sel + 3, 13))
		else:
			kp_sel = 9 if kp_sel == 12 else (11 if kp_sel == 13 else maxi(kp_sel - 3, 0))
	else:
		kp_sel = clampi(kp_sel + step, 0, 13)
	_dialog_redraw()


func press_key(key: String) -> void:
	if kp_text.length() < 10:
		kp_text += key
	Sfx.play("ui_tick", 0.6)


func _dial_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and app == "phone" and ph_view == "keypad" and dialog.is_empty()):
		return false
	var code: int = event.keycode
	if code >= KEY_0 and code <= KEY_9:
		press_key(str(code - KEY_0))
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		press_key(str(code - KEY_KP_0))
	elif code == KEY_BACKSPACE:
		activate("del")
	else:
		return false
	_dialog_redraw()
	return true


func _dialog_redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func dial_number() -> void:
	if kp_text == "":
		return
	var found: Dictionary = Calls.by_number(kp_text)
	if found.is_empty():
		found = {"id": "none", "name": Calls.number_text(kp_text) if kp_text.length() > 3 else kp_text, "sub": "", "kind": "none", "num": kp_text}
	start_call(found)


func start_call(contact: Dictionary) -> void:
	if not dialog.is_empty():
		return
	if not Calls.ready(contact):
		_say("CALLED THEM LATELY - TRY LATER")
		return
	dialog = {"contact": contact, "stage": "dial", "t": 0.0, "say": "", "opts": [Calls.HANG], "voicemail": false}
	call_sel = 0
	calls_made += 1
	Sfx.play("ui_pick", 0.7)
	_dialog_redraw()


# the other end picks up (after DIAL_SECS of ringing, or right away in tests)
func pick_up() -> void:
	if dialog.is_empty() or dialog.stage != "dial":
		return
	var opened: Dictionary = Calls.open_call(dialog.contact)
	dialog.stage = "talk"
	dialog.t = 0.0
	dialog.say = opened.say
	dialog.opts = opened.opts
	dialog.voicemail = opened.voicemail
	Sfx.play("headset", 0.6)
	call_sel = 0
	_dialog_redraw()


func step_call(delta: float) -> void:
	dialog.t = float(dialog.t) + delta
	if dialog.stage == "dial" and float(dialog.t) >= DIAL_SECS:
		pick_up()


func choose(index: int) -> void:
	if dialog.is_empty():
		return
	if dialog.stage == "dial":
		hang_up()
		return
	var opts: Array = dialog.opts
	var opt: Dictionary = opts[clampi(index, 0, opts.size() - 1)]
	if opt.id == "hang":
		hang_up()
		return
	if dialog.stage != "talk":
		return
	var result: Dictionary = Calls.act(dialog.contact, str(opt.id))
	dialog.say = result.say
	dialog.stage = "done"
	dialog.opts = [Calls.HANG]
	call_sel = 0
	_dialog_redraw()


func hang_up() -> void:
	if dialog.is_empty():
		return
	var secs := float(dialog.t) if dialog.stage != "dial" else 0.0
	dialog = {}
	call_sel = 0
	_say("CALL ENDED " + _mmss(secs) if secs >= 1.0 else "HUNG UP")
	_dialog_redraw()


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
	var top := 0.0 if pane_slot >= 0 else maxf(12.0, floorf(size.y * Game.UI_STRIP))
	_fill(Rect2(0, top - 1, size.x, 1), Color("0d1018"))
	if app == "choose":
		_paint_choose(Rect2(0, top, size.x, size.y - top))
		_cursor()
		return
	# the phone gets as much screen as it can (a little wider than the real one) so text fits
	var ptop := 2.0 if pane_slot >= 0 else maxf(12.0, floorf(size.y * 0.17))
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
	var in_call: bool = app == "phone" and not dialog.is_empty()
	var bg := _wallpaper(s) if (app == "home" or locked) else (_call_bg(s) if in_call else _app_bg(s))
	_hits.append({"r": s, "id": "none"})
	var content := Rect2(s.position.x, s.position.y + _bar_h(), s.size.x, s.size.y - _bar_h())
	if not _is_ios():
		content.size.y -= 9.0 * _sc  # android nav bar
	_status_bar(s, bg)
	if locked:
		_paint_lock(content)
		if not _is_ios():
			_nav_bar(Rect2(s.position.x, s.end.y - 9.0 * _sc, s.size.x, 9.0 * _sc))
		return
	match app:
		"phone":
			_paint_phone(content)
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
		"settings": Color("8b919c"),
		"phone": Color("34b84f")
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
		"phone":
			# a handset: ear piece top left, mouth piece bottom right, a curved arm between them
			var rows := ["XXX......", "XXXX.....", ".XXX.....", ".XX......", ".XXX.....", "..XXX....", "...XXXXX.", ".....XXXX", "......XXX"]
			for ry in rows.size():
				for rx in 9:
					if str(rows[ry])[rx] == "X":
						_fill(Rect2(c.x + (rx - 4.5) * u, c.y + (ry - 4.5) * u, u, u), WHITE)
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
	var psz := 10.0 * _sc
	if _is_ios():
		_fill(Rect2(a.position.x, a.end.y - 14 * _sc, a.size.x, 14 * _sc), Color(1, 1, 1, 0.22))
		var pr := Rect2(a.position.x + 3, a.end.y - 12 * _sc, psz, psz)
		_dock_phone(pr)
		var tx := pr.end.x + 4.0
		var label := "PIXEL IT PARTNERS" if _chars(a.end.x - tx - 2) >= 17 else "PIXEL IT"
		_text(
			_clip(label, _chars(a.end.x - tx - 2)), Vector2(tx, a.end.y - 9 * _sc), WHITE
		)
	else:
		var pr := Rect2(a.position.x + 3, a.end.y - 12 * _sc, psz, psz)
		_dock_phone(pr)
		var bar := Rect2(pr.end.x + 3, a.end.y - 12 * _sc + _sc, a.end.x - pr.end.x - 6, 8 * _sc)
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


func _row(r: Rect2, alt: bool, sel := false) -> void:
	var col := WHITE if not alt else Color("f1f1f4")
	if sel:
		col = Color("cfe0fb")
	elif r.has_point(_mouse):
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
	var bottom := body.end.y - (18 if Msp.texts.size() > 1 else 10) * _sc  # the REPLY bar (and the "n OF m" line above it)
	txt_scroll = clampi(txt_scroll, 0, maxi(0, Msp.texts.size() - 1))
	var shown := 0
	for k in range(txt_scroll, Msp.texts.size()):
		var m: Dictionary = Msp.texts[k]  # Msp.send_text push_fronts: index 0 is the newest, scrolled past `txt_scroll` of them
		var lines := _wrap(m.body, chars)
		var h := (lines.size() * 7 + 11) * _sc
		if y + h > bottom:
			if shown > 0:
				break
			# the first text on the page always shows, cut to the lines that fit
			var room := int((bottom - y - 9 * _sc - 2) / (7 * _sc))
			lines = lines.slice(0, maxi(1, room))
			h = (lines.size() * 7 + 11) * _sc
		shown += 1
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
	elif Msp.texts.size() > 1:
		# where you are in the list and how to reach the rest (the newest text used to hide everything above the fold)
		var more := "%d-%d OF %d  UP/DOWN" % [txt_scroll + 1, txt_scroll + shown, Msp.texts.size()]
		_text(_clip(more, _chars(body.size.x - 8)), Vector2(body.position.x + 3, body.end.y - 18 * _sc), Color("8b93a1"))
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
	# the TONE and CAREER rows take the bottom of the screen: the network block only shows when it fits above them
	var room := y + 16 * _sc <= body.end.y - 22 * _sc
	if room:
		_text("NETWORK", Vector2(body.position.x + 3, y), Color("7d8595"))
		_text("CELLULAR 4G", Vector2(body.position.x + 3, y + 8 * _sc), INK)
	var note := _wrap("WORKS WITHOUT THE OFFICE NETWORK", _chars(body.size.x - 6))
	if not room or y + (17 + 7 * note.size()) * _sc > body.end.y - 22 * _sc:
		note = []
	for i in note.size():
		_text(str(note[i]), Vector2(body.position.x + 3, y + (17 + 7 * i) * _sc), Color("7d8595"))
	var ring := Rect2(body.position.x + 2, body.end.y - 21 * _sc, body.size.x - 4, 9 * _sc)
	_fill(ring, WHITE)
	_text("TONE: " + _clip(Career.ringtone_name(), _chars(body.size.x - 10) - 6), ring.position + Vector2(3, 2 * _sc), INK)
	_region("ring", ring)
	var cr := Rect2(body.position.x + 2, body.end.y - 10 * _sc, body.size.x - 4, 9 * _sc)
	_fill(cr, Color("dce8fa"))
	_text("CAREER", cr.position + Vector2(3, 2 * _sc), INK)
	_region("career", cr)


# ---- the dock's PHONE icon -----------------------------------------------------------------------
func _dock_phone(r: Rect2) -> void:
	if home_sel == HOME_APPS.size() - 1:
		_fill(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color(1, 1, 1, 0.45))
	_icon("phone", r)
	_region("app:phone", Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)))


# ---- lock screen ---------------------------------------------------------------------------------
func _paint_lock(a: Rect2) -> void:
	var u := float(_sc)
	var x0 := a.position.x
	var hour := int(World.clock)  # the same truncation as the status bar, so the two clocks agree
	var minute := int((World.clock - float(hour)) * 60.0)
	var hm := "%d:%02d" % [(hour + 11) % 12 + 1, minute]
	var big := 3 * _sc
	var y := a.position.y + 3.0 * u
	var tint := WHITE if _is_ios() else Color("dff3ff")
	_text(hm, Vector2(x0 + floorf((a.size.x - PixelFont.width(hm, big)) * 0.5), y), tint, big)
	y += 17.0 * u
	var date: String = Nerds.date_text(maxi(1, Campaign.day))
	if _tw(date) > a.size.x - 4.0:
		date = date.split(",")[0]
	_text(date, Vector2(x0 + floorf((a.size.x - _tw(date)) * 0.5), y), Color(1, 1, 1, 0.85))
	y += 8.0 * u
	var fresh := unread_total()
	var count := "%d NEW" % fresh if fresh > 0 else "NOTHING NEW"
	_text(count, Vector2(x0 + floorf((a.size.x - _tw(count)) * 0.5), y), Color(1, 1, 1, 0.6))
	y += 8.0 * u
	var slider_h := 9.0 * u
	var sy := a.end.y - slider_h - 2.0 * u
	var rh := 15.0 * u
	var rows := clampi(int((sy - y) / (rh + u)), 0, mini(3, feed.size()))
	for i in rows:
		var f: Dictionary = feed[i]
		var r := Rect2(x0 + 2, y + i * (rh + u), a.size.x - 4, rh)
		if _is_ios():
			_round(r, Color(0.04, 0.05, 0.12, 0.5))
		else:
			_fill(r, Color(0, 0, 0, 0.5))
			_fill(Rect2(r.position.x, r.position.y, 1, rh), KIND_COLORS.get(f.kind, WHITE))
		_fill(Rect2(r.position.x + 2 * u, r.position.y + 2 * u, 3 * u, 3 * u), KIND_COLORS.get(f.kind, WHITE))
		var chars := _chars(r.size.x - 8 * u)
		var head := "%s %s" % [f.kind, str(f.who)]
		_text(_clip(head, chars), r.position + Vector2(7 * u, u), WHITE)
		_text(_clip(str(f.body), chars + 1), r.position + Vector2(2 * u, 8 * u), Color(1, 1, 1, 0.8))
	var slide := maxf(unlock_t, 0.0)
	var bar := Rect2(x0 + 3, sy, a.size.x - 6, slider_h)
	if _is_ios():
		_round(bar, Color(0, 0, 0, 0.35))
		var kw := 10.0 * u
		var kx := bar.position.x + 1 + (bar.size.x - kw - 2) * slide
		_round(Rect2(kx, bar.position.y + 1, kw, slider_h - 2), Color(1, 1, 1, 0.85))
		_text(">", Vector2(kx + floorf((kw - 3 * u) * 0.5), bar.position.y + 2 * u), INK)
		var label := "SLIDE TO UNLOCK" if _chars(bar.size.x - kw - 6) >= 15 else "UNLOCK"
		var shimmer := 0.45 + 0.3 * (1.0 if _blink < 0.2 else 0.0)
		_text(label, Vector2(bar.position.x + kw + 5, bar.position.y + 2 * u), Color(1, 1, 1, shimmer * (1.0 - slide)))
	else:
		var cx := floorf(x0 + a.size.x * 0.5)
		var ay := sy - 3.0 * u - slide * 10.0 * u
		for row in int(3 * u):
			_fill(Rect2(cx - row, ay + row, row * 2 + 1, 1), Color("33b5e5"))
		var label := "SWIPE UP"
		_text(label, Vector2(cx - floorf(_tw(label) * 0.5), sy + 4 * u), Color(1, 1, 1, 0.7))
	_region("unlock", a)


func unread_total() -> int:
	return Msp.unread() + Msp.unread_texts() + Lync.unread_total()


# ---- the PHONE app ---------------------------------------------------------------------------------
func _call_bg(s: Rect2) -> bool:
	if _is_ios():
		for i in 12:
			_fill(
				Rect2(s.position.x, s.position.y + s.size.y * i / 12.0, s.size.x, s.size.y / 12.0 + 1.0),
				Color("2f3846").lerp(Color("101216"), float(i) / 11.0)
			)
	else:
		_fill(s, Color("000000"))
	return true


func _accent() -> Color:
	return Color("2b79f0") if _is_ios() else Color("33b5e5")


func _paint_phone(a: Rect2) -> void:
	if not dialog.is_empty():
		_paint_call(a)
		return
	var body := _header(a, "CONTACTS" if ph_view == "contacts" else "KEYPAD", true)
	if ph_view == "keypad":
		_paint_keypad(body)
	else:
		_paint_contacts(body)


func _paint_contacts(body: Rect2) -> void:
	_fill(body, WHITE)
	var list: Array = Calls.contacts()
	var bar_h := 10.0 * _sc
	var rh := 15.0 * _sc
	var rows := maxi(1, int((body.size.y - bar_h) / rh))
	ph_sel = clampi(ph_sel, 0, list.size() - 1)
	if ph_sel < ph_scroll:
		ph_scroll = ph_sel
	elif ph_sel >= ph_scroll + rows:
		ph_scroll = ph_sel - rows + 1
	ph_scroll = clampi(ph_scroll, 0, maxi(0, list.size() - rows))
	for k in rows:
		var i := ph_scroll + k
		if i >= list.size():
			break
		var c: Dictionary = list[i]
		var rr := Rect2(body.position.x, body.position.y + k * rh, body.size.x, rh)
		_row(rr, i % 2 == 1, i == ph_sel)
		_fill(Rect2(rr.position.x, rr.position.y, 2, rh - 1), _kind_color(str(c.kind)))
		var chars := _chars(rr.size.x - 12)
		_text(_clip(str(c.name), chars), rr.position + Vector2(5, 2 * _sc), INK)
		var wait: float = Calls.wait_left(c)
		var sub := str(c.sub) if wait <= 0.0 else "LATER"
		_text(_clip(sub, chars), rr.position + Vector2(5, 9 * _sc), RED if wait > 0.0 else Color("7d8595"))
		if c.kind == "client" and Campaign.active:
			var m := Sales.mood(int(c.client))
			_disc(
				Vector2(rr.end.x - 5, rr.position.y + rh * 0.5),
				maxi(1, _sc),
				GREEN if m >= 70 else (Color("e0a030") if m >= 40 else RED)
			)
		_region("call:%d" % i, rr)
	if list.size() > rows:
		var track := body.size.y - bar_h
		var th := maxf(4.0, track * float(rows) / float(list.size()))
		var ty := body.position.y + (track - th) * float(ph_scroll) / float(maxi(1, list.size() - rows))
		_fill(Rect2(body.end.x - 1, ty, 1, th), Color("9aa0a8"))
	var kb := Rect2(body.position.x, body.end.y - bar_h, body.size.x, bar_h)
	_fill(kb, _accent())
	_text("KEYPAD", kb.position + Vector2(floorf((kb.size.x - _tw("KEYPAD")) * 0.5), 2.5 * _sc), WHITE)
	_region("keypad", kb)


func _paint_keypad(body: Rect2) -> void:
	var u := float(_sc)
	_fill(body, WHITE if _is_ios() else Color("f2f2f2"))
	var shown := Calls.number_text(kp_text) if kp_text.length() > 3 else kp_text
	var found: Dictionary = Calls.by_number(kp_text) if kp_text != "" else {}
	var caret := "_" if _blink < 0.25 else ""
	_text(shown + caret, Vector2(body.position.x + floorf((body.size.x - _tw(shown + "_")) * 0.5), body.position.y + 2 * u), INK)
	var who: String = "" if found.is_empty() else str(found.name)
	_text(_clip(who, _chars(body.size.x - 4)), body.position + Vector2(3, 8 * u), _accent())
	var bottom_h := 9.0 * u
	var ky0 := body.position.y + 14.0 * u
	var kh := floorf((body.end.y - bottom_h - 2 - ky0) / 4.0)
	var kw := floorf((body.size.x - 4) / 3.0)
	var ks := _sc * (2 if kh >= 12.0 * u else 1)
	for i in 12:
		var r := Rect2(body.position.x + 2 + (i % 3) * kw, ky0 + (i / 3) * kh, kw - 1, kh - 1)
		var hot := kp_sel == i or r.has_point(_mouse)
		_round(r, Color("cfe0fb") if hot else (Color("e4e6ea") if _is_ios() else WHITE))
		if not _is_ios():
			_fill(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color("c4c8cf"))
		var k: String = KEYS[i]
		_text(
			k,
			Vector2(
				r.position.x + floorf((r.size.x - PixelFont.width(k, ks)) * 0.5),
				r.position.y + floorf((r.size.y - 5.0 * ks) * 0.5)
			),
			INK,
			ks
		)
		_region("key:%d" % i, r)
	var by := body.end.y - bottom_h - 1
	var half := floorf((body.size.x - 6) / 2.0)
	for j in 2:
		var r := Rect2(body.position.x + 2 + j * (half + 2), by, half, bottom_h)
		var hot := kp_sel == 12 + j or r.has_point(_mouse)
		var base := Color("9aa0a8") if j == 0 else Color("34b84f")
		_fill(r, base.lightened(0.25) if hot else base)
		var label := "DEL" if j == 0 else "CALL"
		_text(label, r.position + Vector2(floorf((half - _tw(label)) * 0.5), 2 * u), WHITE)
		_region("del" if j == 0 else "dial", r)


func _kind_color(kind: String) -> Color:
	return {"client": Color("2b79f0"), "coworker": Color("3cc15a"), "pizza": Color("f0a030")}.get(kind, Color("8b93a1"))


# the in-call screen: avatar, name, ringing / timer, what they say and the things you can say back
func _paint_call(a: Rect2) -> void:
	var u := float(_sc)
	var contact: Dictionary = dialog.contact
	var x0 := a.position.x
	var y := a.position.y + 3.0 * u
	var cy := y + 2.5 * u
	_disc(Vector2(x0 + 6 * u, cy), int(3 * u), _kind_color(str(contact.get("kind", ""))))
	var initial := str(contact.get("name", "?")).substr(0, 1)
	_text(initial, Vector2(x0 + 6 * u - floorf(1.5 * u), cy - floorf(2.5 * u)), WHITE)
	var chars := _chars(a.size.x - 13 * u)
	_text(_clip(str(contact.get("name", "")), chars), Vector2(x0 + 12 * u, y), WHITE)
	var status := ""
	if dialog.stage == "dial":
		status = "CALLING" + ".".repeat(int(float(dialog.t) * 3.0) % 4)
	else:
		status = _mmss(float(dialog.t))
		if dialog.voicemail:
			status += " VOICEMAIL"
		elif str(contact.get("sub", "")) != "":
			status += " " + str(contact.sub)
	_text(_clip(status, chars), Vector2(x0 + 12 * u, y + 8 * u), Color("9fd8a8") if dialog.stage != "dial" else Color("9fb0c8"))
	var line_y := y + 15.0 * u
	if not _is_ios():
		_fill(Rect2(x0 + 2, line_y, a.size.x - 4, 1), Color("33b5e5"))
	var opts: Array = dialog.opts
	var oh := 8.0 * u
	var opt_top := a.end.y - opts.size() * (oh + 1.0) - 1.0
	var say: String = Calls.number_text(str(contact.get("num", ""))) if dialog.stage == "dial" else str(dialog.say)
	var lines := _wrap(say, _chars(a.size.x - 6))
	var room := maxi(1, int((opt_top - line_y - 3.0 * u) / (7.0 * u)))
	if lines.size() > room:
		lines = lines.slice(0, room)
		lines[room - 1] = _clip(str(lines[room - 1]) + "..", str(lines[room - 1]).length())
	for i in lines.size():
		_text(str(lines[i]), Vector2(x0 + 3, line_y + 3 * u + i * 7 * u), WHITE if dialog.stage != "dial" else Color("c8d0de"))
	for i in opts.size():
		var o: Dictionary = opts[i]
		var r := Rect2(x0 + 2, opt_top + i * (oh + 1.0), a.size.x - 4, oh)
		var hang: bool = o.id == "hang"
		var sel: bool = i == call_sel
		var alpha := 0.5 if sel else (0.35 if r.has_point(_mouse) else 0.2)
		var col: Color = RED if hang else Color(1, 1, 1, alpha)
		if hang and (sel or r.has_point(_mouse)):
			col = col.lightened(0.2)
		if _is_ios():
			_round(r, col)
		else:
			_fill(r, col)
			if sel and not hang:
				_fill(Rect2(r.position.x, r.position.y, 1, oh), Color("33b5e5"))
		var label := str(o.label)
		_text(label, r.position + Vector2(floorf((r.size.x - _tw(label)) * 0.5), floorf((oh - 5.0 * u) * 0.5)), WHITE)
		_region("opt:%d" % i, r)
