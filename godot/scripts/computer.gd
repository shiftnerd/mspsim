extends CanvasLayer
# gdlint: ignore=max-line-length
# The computer: interacting with a monitor takes over the screen (the office fades into the background
# above it) and shows a 2013 desktop with three apps drawn in the pixel font:
#   OUTLOOKISH 2013 (mail), CONNECTWHY PSA (the ticket board), LABRAT RMM (remote monitoring).
# Computer.open(desk): desk 1-8 decides whether this PC has network (Net.desk_state).
# Mouse to click; arrows / Enter / Esc also work. Everything is drawn in code;
# clickable regions are collected while drawing (_hits).

const PixelFont := preload("res://scripts/pixelfont.gd")
const TB := 11.0  # taskbar height
const TXT := Color("20242c")
const WHITE := Color("ffffff")
const BTN := Color("d9dde6")
const BTN_HI := Color("f4f6fa")
const BTN_SH := Color("8a93a4")
const TASK := Color("1c3b63")
const OUTLOOK := Color("2b579a")
const PSA_BLUE := Color("1f4e8c")
const RMM_GREY := Color("3b424d")
# RMM session buttons for the other fixes: quick workaround, heavy fix, clever fix
const ALT_TINTS := {"quick": Color("f2e2a0"), "heavy": Color("e9b1a8"), "clever": Color("a9e0b0")}
const ORANGE := Color("e07b22")
const GREEN := Color("2fa84f")
const RED := Color("d23c3c")
const AMBER := Color("e0a030")
const NOTES := [
	"Called the client, left a voicemail.",
	"Checked in with the user, working on it.",
	"Escalated to Tier 2.",
	"Gathered logs from the machine.",
	"Client says it is still broken.",
]

var is_open := false
var desk := 0
var app := "desktop"
var mail_sel := -1
var mail_top := 0  # first mail shown in the list (it scrolls with the selection)
var mail_view := false
var psa_sel := 0
var psa_detail := false
var close_ask := false  # CLOSE pressed on an unfixed ticket: waiting for YES / NO
var rmm_open := {}
var rmm_scroll := 0  # pixels the endpoint tree is scrolled
var site_info := {}  # a client's computer (onsite): their desktop, not yours
var site_view := "desktop"
var rmm_sel := ""
var rmm_detail := false
var rmm_session := false
var rmm_msg := ""
var rmm_tab := "endpoints"
var board_tab := "books"
var lync_sel := ""
var nerds_tab := "forum"
var learn_lesson := -1
var learn_q := 0
var learn_right := 0
var learn_pick := -1
var learn_done := false
var learn_opts: Array = []

var _canvas: Node2D
var _hits: Array = []
var _mouse := Vector2.ZERO
var _fade := 0.0
var _job := {}
var _area := Rect2()
var _toast := ""
var _toast_t := 0.0
var _menu := false
var _tick := 0.0


func _ready() -> void:
	layer = 60
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	Msp.changed.connect(_refresh)
	Lync.changed.connect(_refresh)
	Nerds.changed.connect(_refresh)


func open_site(info: Dictionary) -> void:
	site_info = info
	open(0)
	app = "site"
	site_view = "desktop"


func open(from_desk: int) -> void:
	desk = from_desk
	app = "desktop"
	mail_view = false
	psa_detail = false
	close_ask = false
	rmm_detail = false
	rmm_session = false
	_menu = false
	_toast = ""  # the toast timer only runs while open, so drop one left from the last session
	_toast_t = 0.0
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
	if not is_open:
		# an RMM fix keeps running with the computer closed (the result shows when you come back);
		# anything else (playbook step, install project) is dropped
		if _job.is_empty():
			return
		if not str(_job.kind) in ["fix", "script", "scriptall"]:
			_job = {}
			return
		_job.left -= delta
		if _job.left <= 0.0:
			_finish_job()
		return
	_tick += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	if not _job.is_empty():
		_job.left -= delta
		_canvas.queue_redraw()
		if _job.left <= 0.0:
			_finish_job()
	if _tick > 0.4:
		_tick = 0.0
		_canvas.queue_redraw()


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
	elif (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	):
		scroll_list(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				escape()
			KEY_UP:
				move(-1)
			KEY_DOWN:
				move(1)
			KEY_ENTER, KEY_KP_ENTER:
				enter()
	else:
		return
	get_viewport().set_input_as_handled()


# ---- input actions (also used by the tests) ----------------------------------
func click(at: Vector2) -> void:
	for i in range(_hits.size() - 1, -1, -1):
		var h: Dictionary = _hits[i]
		if h.r.has_point(at):
			activate(h.id)
			return
	_menu = false
	_canvas.queue_redraw()


# Esc steps back out of a sub-view (open menu, mail, ticket, session, lesson...) one level, and otherwise
# closes the computer in a single press (it used to go app -> desktop -> closed)
func escape() -> void:
	var nested := (
		_menu
		or (app == "mail" and mail_view)
		or (app == "psa" and psa_detail)
		or (app == "rmm" and (rmm_session or rmm_detail))
		or (app == "learn" and learn_lesson >= 0)
		or (app == "lync" and lync_sel != "")
		or (app == "site" and site_view != "desktop")
	)
	if nested:
		back()
	else:
		close()


func back() -> void:
	if _menu:
		_menu = false
	elif app == "desktop":
		close()
	elif app == "mail" and mail_view:
		mail_view = false
	elif app == "psa" and psa_detail:
		if close_ask:
			close_ask = false
		else:
			psa_detail = false
	elif app == "rmm" and (rmm_session or rmm_detail):
		rmm_session = false
		rmm_detail = false
		_cancel_job()
	elif app == "learn" and learn_lesson >= 0:
		learn_lesson = -1
		learn_done = false
	elif app == "lync" and lync_sel != "":
		lync_sel = ""
	elif app == "site" and site_view != "desktop":
		site_view = "desktop"
	elif app == "site":
		close()
	else:
		app = "desktop"
	_canvas.queue_redraw()


func move(step: int) -> void:
	match app:
		"mail":
			mail_sel = clampi(mail_sel + step, 0, maxi(0, Msp.emails.size() - 1))
			if mail_sel < Msp.emails.size() and _area.size.x >= 250.0:
				Msp.emails[mail_sel].unread = false  # the reading pane shows it: it counts as read
		"psa":
			var list := Msp.open_tickets()
			if not list.is_empty():
				psa_sel = list[clampi(_psa_index() + step, 0, list.size() - 1)].id
		"rmm":
			scroll_list(step)
	_canvas.queue_redraw()


# the RMM endpoint tree scrolls three rows at a time
func scroll_list(step: int) -> void:
	if app == "rmm" and not rmm_session and rmm_tab == "endpoints":
		rmm_scroll = maxi(0, rmm_scroll + step * 24)
		_canvas.queue_redraw()


func _psa_index() -> int:
	var list := Msp.open_tickets()
	for i in list.size():
		if list[i].id == psa_sel:
			return i
	return 0


func enter() -> void:
	if app == "mail":
		if mail_sel < 0 and not Msp.emails.is_empty():
			mail_sel = 0  # Enter works from the first press: it opens the first mail
		if mail_sel >= 0:
			activate("mail:%d" % mail_sel)
	elif app == "psa" and not psa_detail and not Msp.open_tickets().is_empty():
		activate("tk:%d" % psa_sel)


func activate(id: String) -> void:
	_menu = false
	var parts := id.split(":")
	match parts[0]:
		"app":
			app = parts[1]
		"wall":
			Career.cycle_pick("wallpaper")
		"close_app":
			if app == "site":
				site_view = "desktop"
			else:
				app = "desktop"
		"site":
			_site_action(parts)
		"start":
			_menu = true
		"logoff":
			close()
		"mail":
			mail_sel = int(parts[1])
			Msp.emails[mail_sel].unread = false
			mail_view = true
		"mback":
			mail_view = false
		"reply", "delete":
			_mail_action(parts[0])
		"back", "tk", "take", "prog", "wait", "note", "close", "closeyes", "closeno", "onsite":
			_psa_action(parts)
		"rmm", "connect", "disc", "fix", "client", "rback", "script", "scriptall":
			_rmm_action(parts)
		"tab", "bkcheck", "bkrerun":
			_rmm_action(parts)
		"proj", "pitem":
			_proj_action(parts)
		"pb":
			_start_pb_job(int(parts[1]))
		"lesson", "ans", "qnext", "lback":
			_learn_action(parts)
		"btab":
			board_tab = parts[1]
		"lync":
			_lync_action(parts)
		"nerds":
			_nerds_action(parts)
	_canvas.queue_redraw()


func _say(text: String) -> void:
	_toast = text
	_toast_t = 3.0


func _mail_action(kind: String) -> void:
	if mail_sel < 0 or mail_sel >= Msp.emails.size():
		return
	var m: Dictionary = Msp.emails[mail_sel]
	if kind == "reply":
		if m.ticket > 0:
			Msp.add_note(m.ticket, "Replied to the client by email.")
		_say("REPLY SENT")
	else:
		Msp.emails.remove_at(mail_sel)
		mail_sel = -1
		mail_view = false


func _psa_action(parts: PackedStringArray) -> void:
	var was_asking := close_ask
	close_ask = false
	match parts[0]:
		"back":
			psa_detail = false
		"tk":
			psa_sel = int(parts[1])
			psa_detail = true
		"take", "prog":
			Msp.set_status(psa_sel, "In Progress")
		"wait":
			Msp.set_status(psa_sel, "Waiting")
		"note":
			Msp.add_note(psa_sel, NOTES[randi() % NOTES.size()])
		"onsite":
			Onsite.offer(psa_sel)
		"close":
			var tk := Msp.ticket(psa_sel)
			if not tk.is_empty() and tk.status != "Closed" and not tk.fix_done and not was_asking:
				close_ask = true  # not fixed yet: closing it reopens it and costs mood
				return
			_say(Msp.close_ticket(psa_sel))
			if Msp.ticket(psa_sel).status == "Closed":
				psa_detail = false
		"closeyes":
			if was_asking:
				_say(Msp.close_ticket(psa_sel))
				if Msp.ticket(psa_sel).status == "Closed":
					psa_detail = false


func _rmm_action(parts: PackedStringArray) -> void:
	match parts[0]:
		"rmm":
			rmm_sel = parts[1]
			rmm_detail = true
		"client":
			var key := int(parts[1])
			rmm_open[key] = not rmm_open.get(key, false)
		"connect":
			rmm_session = true
			rmm_msg = "CONNECTED TO " + rmm_sel
		"disc":
			rmm_session = false
			_cancel_job()
		"fix", "script", "scriptall":
			_start_job(parts[0], parts[1] if parts.size() > 1 else "")
		"rback":
			rmm_detail = false
		"tab":
			rmm_tab = parts[1]
		"bkcheck":
			var b := Msp.backup_check(int(parts[1]))
			_say("BACKUP OK" if b.ok else "BACKUP FAILED!")
		"bkrerun":
			Msp.backup_rerun(int(parts[1]))
			_say("BACKUP RERUN OK")


func _cancel_job() -> void:
	if not _job.is_empty():
		_say("JOB CANCELLED")
	_job = {}


func _start_job(kind: String, action: String) -> void:
	var ep := Msp.endpoint(rmm_sel)
	if ep.is_empty() or not _job.is_empty():
		return
	var act := action if kind == "fix" else str(ep.problem)
	if act == "":
		rmm_msg = "NOTHING TO FIX HERE."
		return
	var secs := Skills.fix_secs_for(act)
	if kind != "fix":
		secs += 1.0
	if act == "save" and Campaign.active:
		secs = 4.0  # the user takes a moment to close things properly
	elif act == "reboot" and Campaign.active and ep.problem != "reboot":
		secs += 4.0  # the machine has to come back up
	if secs <= 0.0:
		_job = {"kind": kind, "action": act, "left": 0.0, "total": 0.1}
		_finish_job()
		return
	_job = {"kind": kind, "action": act, "left": secs, "total": secs}
	rmm_msg = "RUNNING..."


func _proj_action(parts: PackedStringArray) -> void:
	if Msp.project.is_empty() or Msp.project.done:
		return
	match parts[0]:
		"pitem":
			Msp.project_toggle(parts[1])
		"proj":
			match parts[1]:
				"ask":
					Msp.project_ask()
					_say("DR. PATEL REMEMBERED MORE")
				"all":
					Msp.project_select_all()
				"hand":
					var res := Msp.project_handover()
					_say("HANDED OVER: GRADE %s" % str(res.grade))
				_:
					_start_proj_job(parts[1])


func _start_pb_job(index: int) -> void:
	if not _job.is_empty() or not Playbook.is_active():
		return
	var choice: Dictionary = Playbook.current_step().choices[index]
	if Playbook.lock_reason(choice) != "":
		return
	var secs := Playbook.choice_secs(choice)
	_job = {"kind": "pb", "action": str(index), "left": secs, "total": maxf(secs, 0.1)}
	if secs <= 0.0:
		_finish_job()


func _start_proj_job(action: String) -> void:
	if not _job.is_empty():
		return
	var secs := Msp.project_secs(action)
	_job = {"kind": "proj", "action": action, "left": secs, "total": maxf(secs, 0.1)}
	if secs <= 0.0:
		_finish_job()


func _finish_proj(action: String) -> void:
	match action:
		"scan":
			Msp.project_scan(false)
			_say("SCAN DONE")
		"deep":
			Msp.project_scan(true)
			_say("DEEP SCAN FOUND HIDDEN ITEMS")
		"backup":
			Msp.project_backup()
			_say("OLD PC BACKED UP")
		"migrate":
			Msp.project_migrate()
			_say("MIGRATION COMPLETE")
		"verify":
			var missing := Msp.project_verify()
			_say("ALL GOOD" if missing.is_empty() else "%d ITEMS MISSING!" % missing.size())


func _finish_job() -> void:
	var job := _job
	_job = {}
	if str(job.kind) == "proj":
		_finish_proj(str(job.action))
		return
	if str(job.kind) == "pb":
		Playbook.choose(int(job.action))
		_say(Playbook.last_note)
		return
	var ep := Msp.endpoint(rmm_sel)
	if ep.is_empty():
		return
	if (
		not (job.action in ["restore", "pay", "shadow", "save"])
		and str(Msp.ALT_DEFS.get(str(job.action), {}).get("kind", "")) != "heavy"
		and randf() < Skills.fail_chance() + Growth.fail_adjust(str(job.action))
	):
		rmm_msg = (
			"TIRED: TYPED IT WRONG. TRY AGAIN."
			if Shift.is_tired()
			else "FIX DID NOT STICK. TRY AGAIN."
		)
		return
	match str(job.kind):
		"fix":
			rmm_msg = Msp.rmm_action(rmm_sel, str(job.action))
		"script":
			rmm_msg = (
				"SCRIPT FIXED %d PC(S)." % Msp.rmm_bulk(int(ep.client), str(job.action), false)
			)
		_:
			rmm_msg = (
				"SCRIPT FIXED %d PC(S) ACROSS CLIENTS."
				% Msp.rmm_bulk(int(ep.client), str(job.action), true)
			)


func _learn_shuffle() -> void:
	var q: Array = Skills.LESSONS[learn_lesson].qs[learn_q]
	learn_opts = [q[1], q[2], q[3]]
	learn_opts.shuffle()
	learn_pick = -1


func _learn_action(parts: PackedStringArray) -> void:
	match parts[0]:
		"lesson":
			if int(parts[1]) == Skills.ps_level and not Skills.can_study():
				_say("ONE LESSON A DAY. COME BACK TOMORROW.")
				return
			learn_lesson = int(parts[1])
			learn_q = 0
			learn_right = 0
			learn_done = false
			_learn_shuffle()
		"ans":
			if learn_pick < 0:
				learn_pick = int(parts[1])
				var q: Array = Skills.LESSONS[learn_lesson].qs[learn_q]
				if learn_opts[learn_pick] == q[1]:
					learn_right += 1
		"qnext":
			learn_q += 1
			if learn_q >= 3:
				learn_done = true
				if learn_right >= 2:
					Skills.pass_lesson(learn_lesson)
			else:
				_learn_shuffle()
		"lback":
			learn_lesson = -1
			learn_done = false


# ---- drawing helpers ---------------------------------------------------------
func _fill(r: Rect2, c: Color) -> void:
	_canvas.draw_rect(r, c)


func _text(s: String, p: Vector2, c: Color = TXT, scale := 1) -> void:
	PixelFont.draw(_canvas, s, p, c, scale)


func _tw(s: String, scale := 1) -> float:
	return float(PixelFont.width(s, scale))


func _clip(s: String, chars: int) -> String:
	return s if s.length() <= chars else s.substr(0, maxi(1, chars - 2)) + ".."


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


func _button(id: String, r: Rect2, label: String, enabled := true, tint := BTN) -> void:
	var hot := enabled and r.has_point(_mouse)
	_fill(r, tint.lightened(0.18) if hot else tint)
	_fill(Rect2(r.position, Vector2(r.size.x, 1)), BTN_HI)
	_fill(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), BTN_SH)
	_fill(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), BTN_SH)
	var at := (
		r.position + Vector2(floorf((r.size.x - _tw(label)) * 0.5), floorf((r.size.y - 5.0) * 0.5))
	)
	_text(label, at, TXT if enabled else Color("8b93a1"))
	if enabled:
		_region(id, r)


func _row(r: Rect2, selected: bool, alt: bool) -> void:
	var col := Color("ffffff") if not alt else Color("eef3f9")
	if selected:
		col = Color("c7dcf5")
	elif r.has_point(_mouse):
		col = Color("e1ecf8")
	_fill(r, col)


func _window(title: String, tint: Color) -> Rect2:
	var a := Rect2(_area.position, Vector2(_area.size.x, _area.size.y - TB))
	_fill(a, Color("e9ecf1"))
	_fill(Rect2(a.position, Vector2(a.size.x, 8)), tint)
	_text(title, a.position + Vector2(3, 1), WHITE)
	_button("close_app", Rect2(a.end.x - 10, a.position.y + 1, 9, 6), "X", true, Color("d86b5e"))
	return Rect2(a.position + Vector2(0, 8), Vector2(a.size.x, a.size.y - 8))


func _offline(message: String, body: Rect2) -> bool:
	var net := Net.desk_state(desk)
	if net == "ok":
		return false
	_fill(body, Color("f3f3f5"))
	var mid := body.position + Vector2(body.size.x * 0.5, body.size.y * 0.35)
	var col := RED if net == "no_link" else AMBER
	_fill(Rect2(mid - Vector2(7, 7), Vector2(14, 14)), col)
	_text("!" if net == "no_internet" else "X", mid - Vector2(1, 2), WHITE)
	var lines := _wrap(message, int(body.size.x / 4.0) - 2)
	lines.append("")
	lines.append("NO NETWORK CONNECTION." if net == "no_link" else "NO INTERNET ACCESS.")
	lines.append("CHECK THE NETWORK CLOSET.")
	for i in lines.size():
		var s: String = lines[i]
		_text(
			s,
			Vector2(floorf(body.position.x + (body.size.x - _tw(s)) * 0.5), mid.y + 12 + i * 7),
			TXT
		)
	return true


# ---- the whole screen --------------------------------------------------------
func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_hits.clear()
	_fill(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.62))  # the office, faded, behind
	var top := maxf(12.0, floorf(size.y * Game.UI_STRIP))
	_area = Rect2(0, top, size.x, size.y - top)
	match app:
		"mail":
			_paint_mail()
		"psa":
			_paint_psa()
		"rmm":
			_paint_rmm()
		"boardroom":
			_paint_boardroom()
		"lync":
			_paint_lync()
		"nerds":
			_paint_nerds()
		"learn":
			_paint_learn()
		"stats":
			_paint_stats()
		"site":
			_paint_site()
		_:
			_paint_desktop()
	_paint_taskbar()
	if _toast_t > 0.0:
		var msg := _clip(_toast, int((size.x - 8) / 4.0))
		var tx := floorf((size.x - _tw(msg)) * 0.5)
		_fill(Rect2(tx - 3, _area.end.y - TB - 10, _tw(msg) + 6, 9), Color("20242c"))
		_text(msg, Vector2(tx, _area.end.y - TB - 8), WHITE)
	_fill(Rect2(0, top - 1, size.x, 1), Color("0d1018"))
	_cursor()


func _cursor() -> void:
	var m := _mouse.floor()
	for i in 6:
		_fill(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), Color("17121f"))
	_fill(Rect2(m.x + 1, m.y + 2, 2, 2), WHITE)
	_fill(Rect2(m.x + 1, m.y + 1, 1, 1), WHITE)


func _paint_taskbar() -> void:
	var y := _area.end.y - TB
	_fill(Rect2(0, y, _area.size.x, TB), TASK)
	_fill(Rect2(0, y, _area.size.x, 1), Color("3c6aa5"))
	_button("start", Rect2(1, y + 1, 26, 9), "START", true, Color("3a7bd5"))
	if _menu and app == "site":
		var site_items := [["site:tools", "TOOLS"], ["logoff", "LOG OFF"]]
		for i in site_items.size():
			_button(
				site_items[i][0],
				Rect2(1, y - (site_items.size() - i) * 9, 54, 9),
				site_items[i][1],
				true,
				Color("e9ecf1")
			)
	elif _menu:
		var items := [
			["app:mail", "OUTLOOKISH"],
			["app:psa", "CONNECTWHY"],
			["app:rmm", "LABRAT"],
			["app:learn", "POWERSHELL"],
			["app:stats", "PROFILE"],
			["app:lync", "LYNK"],
			["app:nerds", "NERDS"],
			["logoff", "LOG OFF"],
		]
		if Campaign.books_active():
			items.insert(4, ["app:boardroom", "BOARDROOM"])
		for i in items.size():
			_button(
				items[i][0],
				Rect2(1, y - (items.size() - i) * 9, 54, 9),
				items[i][1],
				true,
				Color("e9ecf1")
			)
	var net := "ok" if app == "site" else Net.desk_state(desk)
	var dot := GREEN if net == "ok" else (AMBER if net == "no_internet" else RED)
	var clock: String = World.clock_text()
	var cx := _area.size.x - _tw(clock) - 4
	_text(clock, Vector2(cx, y + 3), WHITE)
	_fill(Rect2(cx - 7, y + 3, 5, 5), dot)
	if app != "desktop":
		_button(
			"close_app", Rect2(30, y + 1, 36, 9), _clip(app.to_upper(), 8), true, Color("5d86bd")
		)


func _icon(kind: String, p: Vector2) -> void:
	match kind:
		"mail":
			_fill(Rect2(p, Vector2(16, 11)), WHITE)
			_fill(Rect2(p, Vector2(16, 1)), Color("17121f"))
			for i in 6:
				_fill(Rect2(p.x + 1 + i, p.y + 1 + i, 1, 1), Color("5a6a85"))
				_fill(Rect2(p.x + 14 - i, p.y + 1 + i, 1, 1), Color("5a6a85"))
		"psa":
			_fill(Rect2(p, Vector2(14, 14)), Color("e8e2c8"))
			_fill(Rect2(p + Vector2(4, -1), Vector2(6, 3)), PSA_BLUE)
			for i in 3:
				_fill(Rect2(p + Vector2(2, 4 + i * 3), Vector2(10, 1)), Color("7d8aa0"))
		"learn":
			_fill(Rect2(p, Vector2(16, 12)), Color("012456"))
			for i in 3:
				_fill(Rect2(p.x + 3 + i, p.y + 3 + i, 1, 1), WHITE)
				_fill(Rect2(p.x + 3 + i, p.y + 7 - i, 1, 1), WHITE)
			_fill(Rect2(p.x + 8, p.y + 8, 5, 1), WHITE)
		"lync":
			_fill(Rect2(p + Vector2(1, 1), Vector2(14, 9)), Color("0a6ab8"))
			_fill(Rect2(p + Vector2(3, 10), Vector2(3, 2)), Color("0a6ab8"))
			_fill(Rect2(p + Vector2(5, 3), Vector2(2, 5)), WHITE)
			_fill(Rect2(p + Vector2(5, 6), Vector2(5, 2)), WHITE)
		"nerds":
			_fill(Rect2(p + Vector2(1, 2), Vector2(14, 10)), Color("2a2a33"))
			_fill(Rect2(p + Vector2(1, 0), Vector2(4, 4)), Color("e07b22"))
			_fill(Rect2(p + Vector2(11, 0), Vector2(4, 4)), Color("e07b22"))
			_fill(Rect2(p + Vector2(4, 6), Vector2(2, 2)), WHITE)
			_fill(Rect2(p + Vector2(10, 6), Vector2(2, 2)), WHITE)
		"boardroom":
			_fill(Rect2(p + Vector2(1, 3), Vector2(14, 9)), Color("8a5a2b"))
			_fill(Rect2(p + Vector2(5, 0), Vector2(6, 4)), Color("6b421c"))
			_fill(Rect2(p + Vector2(7, 6), Vector2(2, 3)), Color("f5d442"))
		"stats":
			_fill(Rect2(p, Vector2(15, 12)), Color("e8ecf2"))
			_fill(Rect2(p.x + 2, p.y + 6, 3, 5), GREEN)
			_fill(Rect2(p.x + 6, p.y + 3, 3, 8), ORANGE)
			_fill(Rect2(p.x + 10, p.y + 1, 3, 10), Color("3a7bd5"))
		_:
			_fill(Rect2(p, Vector2(16, 11)), Color("2a2a33"))
			_fill(Rect2(p + Vector2(1, 1), Vector2(14, 8)), Color("4f7fd0"))
			_fill(Rect2(p + Vector2(6, 3), Vector2(4, 4)), ORANGE)
			_fill(Rect2(p + Vector2(5, 11), Vector2(6, 2)), Color("2a2a33"))


# ---- a client's computer (onsite): their desktop, software and mail -----------------
func _site_action(parts: PackedStringArray) -> void:
	if parts[1] == "diag":
		var obj := str(site_info.get("obj", "pc"))
		if not Onsite.job_here(obj):
			_say("NOTHING WRONG WITH THIS PC")
			return
		close()
		Onsite.pc_diagnose(obj)
		return
	if parts[1] == "audit":
		var obj := str(site_info.get("obj", "pc"))
		close()
		Onsite.inspect(obj)
		return
	site_view = parts[1]


func _paint_site() -> void:
	var a := _area
	var wall := Color(str(site_info.get("wall", "#CFE8EE")))
	var accent := Color(str(site_info.get("accent", "#2E9AB8")))
	if site_view != "desktop":
		_paint_site_window(accent)
		return
	var ink := Color("17121f") if wall.get_luminance() > 0.45 else WHITE
	_fill(a, wall)
	for i in 6:
		_fill(Rect2(a.position.x, a.position.y + i * 8.0, a.size.x, 3), accent.lerp(wall, 0.6))
	var title := str(site_info.get("name", ""))
	var scale := 2 if a.size.x >= 260.0 and _tw(title, 2) < a.size.x - 70.0 else 1
	var tx := floorf(a.position.x + (a.size.x - _tw(title, scale)) * 0.5)
	var ty := a.position.y + a.size.y * 0.40
	_text(title, Vector2(tx + 1, ty + 1), Color("17121f"), scale)
	_text(title, Vector2(tx, ty), WHITE, scale)
	var who := "%s   USER: %s" % [str(site_info.get("pc", "PC")), str(site_info.get("user", ""))]
	_text(who, Vector2(floorf(a.position.x + (a.size.x - _tw(who)) * 0.5), ty + 8 + 5 * scale), ink)
	_text("WINDOWS 7 PROFESSIONAL", Vector2(a.position.x + 4, a.end.y - TB - 8), ink)
	var icons := [
		["practice", _clip(str(site_info.get("app", "APP")), 10), "app"],
		["mail", "MAIL", "mail"],
		["computer", "COMPUTER", "psa"],
		["tools", "TOOLS", "stats"],
	]
	var per_col := maxi(1, int((a.size.y - TB - 6.0) / 27.0))
	for i in icons.size():
		var p := Vector2(
			a.position.x + 8 + float(i / per_col) * 52.0,
			a.position.y + 5 + float(i % per_col) * 27.0
		)
		var hit := Rect2(p - Vector2(5, 3), Vector2(46, 25))
		if hit.has_point(_mouse):
			_fill(hit, Color(1, 1, 1, 0.25))
		_icon(icons[i][2], p + Vector2(10, 0))
		_text(icons[i][1], p + Vector2(0, 16), ink)
		_region("site:" + icons[i][0], hit)


func _paint_site_window(accent: Color) -> void:
	var info := site_info
	var chars := 40
	match site_view:
		"practice":
			var body := _window(
				str(info.get("app", "")) + " - " + str(info.get("title", "")), accent
			)
			chars = int(body.size.x / 4.0) - 2
			var y := body.position.y + 4
			for row in info.get("rows", []):
				_text(_clip(str(row), chars), Vector2(body.position.x + 4, y), TXT)
				y += 8
		"mail":
			var body := _window("OUTLOOKISH 2010 - INBOX", Color("2b5797"))
			chars = int(body.size.x / 4.0) - 2
			var y := body.position.y + 4
			for mail in info.get("mails", []):
				_text(
					_clip("FROM: " + str(mail[0]).to_upper(), chars),
					Vector2(body.position.x + 4, y),
					Color("2b5797")
				)
				_text(_clip(str(mail[1]), chars), Vector2(body.position.x + 4, y + 7), TXT)
				y += 18
		"computer":
			var body := _window("COMPUTER", Color("4a6a8a"))
			var lines := [
				"NAME: " + str(info.get("pc", "")),
				"USER: " + str(info.get("user", "")),
				"WINDOWS 7 PROFESSIONAL SP1",
				"DRIVE C: 82 GB FREE OF 250 GB",
				"NETWORK: " + str(info.get("net", "CONNECTED")),
			]
			var y := body.position.y + 4
			for line in lines:
				_text(
					_clip(str(line), int(body.size.x / 4.0) - 2),
					Vector2(body.position.x + 4, y),
					RED if str(line).contains("NO NETWORK") else TXT
				)
				y += 8
		_:
			var body := _window("YOUR TOOLBOX", Color("5a5f6a"))
			_text(
				"YOU ARE ONSITE. THIS IS THEIR COMPUTER.",
				Vector2(body.position.x + 4, body.position.y + 4),
				Color("46506a")
			)
			_button(
				"site:diag",
				Rect2(body.position.x + 4, body.position.y + 16, minf(body.size.x - 8, 90.0), 10),
				"DIAGNOSE AND FIX",
				true,
				Color("9bd6a8")
			)
			_button(
				"site:audit",
				Rect2(body.position.x + 4, body.position.y + 28, minf(body.size.x - 8, 90.0), 10),
				"LOOK AROUND",
				true,
				Color("e9d99b")
			)
			_text(
				"EVENT LOG: NOTHING UNUSUAL",
				Vector2(body.position.x + 4, body.position.y + 44),
				TXT
			)
			_text(
				(
					"PING 8.8.8.8: "
					+ ("TIMED OUT" if str(info.get("net", "")).contains("NO") else "OK")
				),
				Vector2(body.position.x + 4, body.position.y + 52),
				TXT
			)


func _paint_desktop() -> void:
	var a := _area
	var wall := Career.wallpaper_color()
	_fill(a, wall)
	for i in 8:
		_fill(Rect2(a.position.x, a.position.y + i * 6.0, a.size.x, 3), wall.lightened(0.1))
	var title := "PIXEL IT PARTNERS"
	var scale := 2 if a.size.x >= 220.0 else 1
	var tx := floorf(a.position.x + (a.size.x - _tw(title, scale)) * 0.5)
	var ty := a.position.y + a.size.y * 0.42
	_text(title, Vector2(tx + 1, ty + 1), Color("17121f"), scale)
	_text(title, Vector2(tx, ty), WHITE, scale)
	var sub := "SERVICE DESK - SINCE 2013"
	_text(
		sub,
		Vector2(floorf(a.position.x + (a.size.x - _tw(sub)) * 0.5), ty + 6 + 5 * scale),
		Color("bcd4f0")
	)
	var icons := [
		["mail", "OUTLOOKISH", Msp.unread()],
		["psa", "CONNECTWHY", Msp.open_tickets().size()],
		["rmm", "LABRAT", 0],
		["learn", "POWERSHELL", 0],
		["stats", "PROFILE", 0],
		["lync", "LYNK", Lync.unread_total()],
		["nerds", "NERDS", 0],
	]
	if Campaign.books_active():
		icons.append(["boardroom", "BOARDROOM", 0])
	var per_col := maxi(1, int((a.size.y - TB - 6.0) / 27.0))
	for i in icons.size():
		var p := Vector2(
			a.position.x + 8 + float(i / per_col) * 52.0,
			a.position.y + 5 + float(i % per_col) * 27.0
		)
		var hit := Rect2(p - Vector2(5, 3), Vector2(46, 25))
		if hit.has_point(_mouse):
			_fill(hit, Color(1, 1, 1, 0.18))
		_icon(icons[i][0], p + Vector2(10, 0))
		_text(icons[i][1], p + Vector2(0, 16), WHITE)
		if icons[i][2] > 0:
			_fill(Rect2(p.x + 22, p.y - 3, 9, 7), RED)
			_text(str(icons[i][2]), Vector2(p.x + 25, p.y - 2), WHITE)
		_region("app:" + icons[i][0], hit)
	if Career.unlocked_of("wallpaper").size() > 1:  # a medal unlocked another wallpaper: click the chip to change
		var chip := "WALLPAPER: " + str(Career.pick_of("wallpaper").title)
		var cr := Rect2(a.end.x - _tw(chip) - 10, a.position.y + 3, _tw(chip) + 8, 9)
		_fill(cr, Color(0, 0, 0, 0.35) if not cr.has_point(_mouse) else Color(0, 0, 0, 0.6))
		_text(chip, cr.position + Vector2(4, 2), WHITE)
		_region("wall:next", cr)
	var net := Net.desk_state(desk)
	if net != "ok":
		var note := "NETWORK CABLE UNPLUGGED" if net == "no_link" else "NO INTERNET ACCESS"
		var r := Rect2(a.end.x - _tw(note) - 12, a.end.y - TB - 14, _tw(note) + 8, 11)
		_fill(r, RED if net == "no_link" else AMBER)
		_text(note, r.position + Vector2(4, 3), WHITE)


# ---- mail (Outlookish 2013) --------------------------------------------------
func _paint_mail() -> void:
	var body := _window("OUTLOOKISH 2013 - INBOX (%d UNREAD)" % Msp.unread(), OUTLOOK)
	if _offline("OUTLOOKISH CANNOT CONNECT TO THE MAIL SERVER.", body):
		return
	var narrow := body.size.x < 250.0
	var list_w := body.size.x if (narrow and not mail_view) else (0.0 if narrow else clampf(floorf(body.size.x * 0.48), 112.0, 150.0))
	if not narrow:
		_fill(Rect2(body.position, Vector2(40, body.size.y)), Color("dfe5ef"))
		_text("INBOX", body.position + Vector2(4, 4), OUTLOOK)
		_text("SENT", body.position + Vector2(4, 13), Color("7d8aa0"))
		_text("DELETED", body.position + Vector2(4, 22), Color("7d8aa0"))
	var lx := body.position.x + (0.0 if narrow else 40.0)
	if list_w > 0.0:
		_mail_list(Rect2(lx, body.position.y, list_w, body.size.y))
	if mail_sel >= 0 and mail_sel < Msp.emails.size() and (mail_view or not narrow):
		var rx := body.position.x if narrow else lx + list_w
		_mail_read(Rect2(rx, body.position.y, body.end.x - rx, body.size.y), narrow)
	elif not narrow:
		_fill(Rect2(lx + list_w, body.position.y, body.end.x - lx - list_w, body.size.y), WHITE)
		_text(
			"SELECT AN ITEM TO READ", Vector2(lx + list_w + 6, body.position.y + 8), Color("8b93a1")
		)


func _mail_list(r: Rect2) -> void:
	var rows := int(r.size.y / 14.0)
	if mail_sel >= 0:  # keep the selected mail on screen
		mail_top = clampi(mail_top, mail_sel - rows + 1, mail_sel)
	mail_top = clampi(mail_top, 0, maxi(0, Msp.emails.size() - rows))
	for i in range(mail_top, mini(mail_top + rows, Msp.emails.size())):
		var m: Dictionary = Msp.emails[i]
		var rr := Rect2(r.position.x, r.position.y + (i - mail_top) * 14.0, r.size.x, 14)
		_row(rr, i == mail_sel, i % 2 == 1)
		var col := OUTLOOK if m.unread else Color("5a6372")
		_text(_clip(m.from, int(r.size.x / 4.0) - 2), rr.position + Vector2(3, 2), col)
		_text(
			_clip(m.subject, int(r.size.x / 4.0) - 2),
			rr.position + Vector2(3, 8),
			TXT if m.unread else Color("7d8595")
		)
		_region("mail:%d" % i, rr)
	if Msp.emails.is_empty():
		_fill(r, WHITE)
		_text("NO MESSAGES", r.position + Vector2(6, 6), Color("8b93a1"))


func _mail_read(r: Rect2, narrow: bool) -> void:
	var m: Dictionary = Msp.emails[mail_sel]
	_fill(r, WHITE)
	_text("FROM: " + _clip(m.from, int(r.size.x / 4.0) - 7), r.position + Vector2(4, 3), OUTLOOK)
	_text(_clip(m.subject, int(r.size.x / 4.0) - 2), r.position + Vector2(4, 10), TXT)
	_fill(Rect2(r.position.x + 3, r.position.y + 17, r.size.x - 6, 1), Color("c9d2e0"))
	var lines := _wrap(m.body, int((r.size.x - 8) / 4.0))
	for i in mini(lines.size(), int((r.size.y - 40) / 7.0)):
		_text(lines[i], r.position + Vector2(4, 21 + i * 7), TXT)
	var by := r.end.y - 11
	_button("reply", Rect2(r.position.x + 3, by, 30, 9), "REPLY")
	_button("delete", Rect2(r.position.x + 36, by, 32, 9), "DELETE")
	if narrow:
		_button("mback", Rect2(r.end.x - 31, by, 28, 9), "BACK")


# ---- PSA (ConnectWhy PSA) ----------------------------------------------------
func _paint_psa() -> void:
	var body := _window("CONNECTWHY PSA - SERVICE BOARD", PSA_BLUE)
	if _offline("CONNECTWHY PSA - SERVER NOT AVAILABLE.", body):
		return
	if psa_detail and not Msp.ticket(psa_sel).is_empty():
		_paint_ticket(body)
	else:
		psa_detail = false
		_paint_board(body)


func _pri_color(pri: int) -> Color:
	return [RED, ORANGE, AMBER, Color("7d8aa0")][clampi(pri, 1, 4) - 1]


func _mmss(secs: float) -> String:
	var s := maxi(0, int(secs))
	return "%d:%02d" % [s / 60, s % 60]


func _paint_board(body: Rect2) -> void:
	var wide := body.size.x >= 300.0
	var tickets := Msp.open_tickets()
	_fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("cfd9e8"))
	_text("OPEN %d" % tickets.size(), body.position + Vector2(3, 2), PSA_BLUE)
	var stats := "SCORE %d  CLOSED %d  SLA MISSED %d" % [Msp.score, Msp.closed_ok, Msp.breached]
	_text(_clip(stats, int((body.size.x - 40) / 4.0)), body.position + Vector2(40, 2), TXT)
	var y0 := body.position.y + 9
	_fill(Rect2(body.position.x, y0, body.size.x, 7), Color("9db3d1"))
	var cols := [0.0, 26.0]
	var sum_x := body.position.x + (74.0 if wide else 26.0)
	_text("#", Vector2(body.position.x + 2, y0 + 1), WHITE)
	if wide:
		_text("CO", Vector2(body.position.x + cols[1], y0 + 1), WHITE)
	_text("SUMMARY", Vector2(sum_x, y0 + 1), WHITE)
	_text("SLA", Vector2(body.end.x - 22, y0 + 1), WHITE)
	var rows := int((body.size.y - 16) / 9.0)
	var first := clampi(_psa_index() - rows + 1, 0, maxi(0, tickets.size() - rows))
	for i in mini(rows, tickets.size() - first):
		var t: Dictionary = tickets[first + i]
		var rr := Rect2(body.position.x, y0 + 7 + i * 9.0, body.size.x, 9)
		_row(rr, t.id == psa_sel, i % 2 == 1)
		_fill(Rect2(rr.position.x, rr.position.y, 2, 9), _pri_color(t.pri))
		_text(str(t.id), rr.position + Vector2(4, 2), TXT)
		var short := "PITP" if t.client < 0 else str(Msp.CLIENTS[t.client].short)
		if wide:
			_text(short, rr.position + Vector2(cols[1], 2), Color("5a6372"))
		var sum_chars := int((body.end.x - 26 - sum_x) / 4.0) - 3
		_text(_clip(t.summary, sum_chars), Vector2(sum_x, rr.position.y + 2), TXT)
		var late: bool = t.breached or t.sla_left < 30.0
		_text(
			"LATE" if t.breached else _mmss(t.sla_left),
			Vector2(body.end.x - 22, rr.position.y + 2),
			RED if late else Color("5a6372")
		)
		_region("tk:%d" % t.id, rr)
	if tickets.is_empty():
		_text("NO OPEN TICKETS. NICE.", body.position + Vector2(8, 28), Color("8b93a1"))


func _paint_ticket(body: Rect2) -> void:
	var t := Msp.ticket(psa_sel)
	_fill(body, WHITE)
	var chars := int((body.size.x - 8) / 4.0)
	_fill(Rect2(body.position, Vector2(body.size.x, 9)), _pri_color(t.pri))
	_text(_clip("#%d  %s" % [t.id, t.summary], chars), body.position + Vector2(3, 2), WHITE)
	var y := body.position.y + 12
	var info := [
		_clip(Msp.client_text(t), chars),
		"PRIORITY P%d   STATUS: %s" % [t.pri, str(t.status).to_upper()],
		"SLA: %s%s" % [_mmss(t.sla_left), "  (MISSED)" if t.breached else ""],
		(
			("DESK: " + str(Msp.DESK_NAMES.get(t.desk, "?")))
			if t.internal
			else ("ENDPOINT: " + str(t.endpoint))
		),
	]
	for s in info:
		_text(s, Vector2(body.position.x + 4, y), PSA_BLUE if s == info[0] else TXT)
		y += 7
	y += 2
	var lines := _wrap(t.body, chars)
	var space := int((body.end.y - 24 - y) / 7.0)
	for i in mini(lines.size(), maxi(2, space - 3)):
		_text(lines[i], Vector2(body.position.x + 4, y), Color("46506a"))
		y += 7
	_fill(Rect2(body.position.x + 3, y, body.size.x - 6, 1), Color("c9d2e0"))
	y += 3
	var shown := maxi(1, int((body.end.y - 24 - y) / 7.0))
	for i in range(maxi(0, t.notes.size() - shown), t.notes.size()):
		_text("- " + _clip(t.notes[i], chars - 2), Vector2(body.position.x + 4, y), Color("7d8aa0"))
		y += 7
	_ticket_buttons(body)


func _ticket_buttons(body: Rect2) -> void:
	var tk := Msp.ticket(psa_sel)
	if close_ask:
		var warn := Rect2(body.position.x + 3, body.end.y - 33, body.size.x - 6, 20)
		_fill(warn, Color("f6d7d2"))
		var wchars := int((warn.size.x - 6.0) / 4.0)
		var wl := _wrap("NOT FIXED YET. CLOSING REOPENS IT: ANGRY CLIENT, COWORKERS -1.", wchars)
		for i in mini(2, wl.size()):
			_text(wl[i], warn.position + Vector2(3, 3 + i * 7), RED)
		var half := floorf((body.size.x - 6.0) * 0.5)
		_button(
			"closeyes",
			Rect2(body.position.x + 3, body.end.y - 11, half - 2, 9),
			"CLOSE ANYWAY",
			true,
			Color("e8b0a8")
		)
		_button(
			"closeno",
			Rect2(body.position.x + 3 + half, body.end.y - 11, half - 2, 9),
			"KEEP WORKING",
			true,
			Color("9bd6a8")
		)
		return
	# CLOSE sits at the far end, away from NOTE
	var items := [
		["back", "BACK"],
		["take", "TAKE"],
		["prog", "PROGRESS"],
		["note", "NOTE"],
		["wait", "WAIT"],
		["close", "CLOSE"]
	]
	if not tk.is_empty() and Onsite.is_onsite(tk):
		items[2] = ["onsite", "GO ONSITE"]
	var wide := body.size.x >= 250.0
	var cols := 6 if wide else 3
	var bw := floorf((body.size.x - 6) / cols)
	for i in items.size():
		var r := Rect2(
			body.position.x + 3 + (i % cols) * bw,
			body.end.y - 11 - (0 if wide else (1 - i / cols) * 10),
			bw - 2,
			9
		)
		var tint := BTN if items[i][0] != "close" else Color("9bd6a8")
		_button(items[i][0], r, items[i][1], true, tint)


# ---- RMM (LabRat RMM) --------------------------------------------------------
func _paint_rmm() -> void:
	var body := _window("LABRAT RMM - CONTROL CENTER", RMM_GREY)
	if _offline("LABRAT CANNOT REACH THE AUTOMATION SERVER.", body):
		return
	if rmm_session and not Msp.endpoint(rmm_sel).is_empty():
		_paint_session(body)
		return
	rmm_session = false
	_fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("d5d9e0"))
	_button(
		"tab:endpoints",
		Rect2(body.position.x + 2, body.position.y + 1, 44, 8),
		"ENDPOINTS",
		true,
		BTN_HI if rmm_tab == "endpoints" else BTN
	)
	_button(
		"tab:backups",
		Rect2(body.position.x + 48, body.position.y + 1, 38, 8),
		"BACKUPS",
		true,
		BTN_HI if rmm_tab == "backups" else BTN
	)
	_button(
		"tab:project",
		Rect2(body.position.x + 88, body.position.y + 1, 38, 8),
		"PROJECT",
		true,
		BTN_HI if rmm_tab == "project" else BTN
	)
	body = Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
	if rmm_tab == "backups":
		_paint_backups(body)
		return
	if rmm_tab == "project":
		_paint_project(body)
		return
	var narrow := body.size.x < 250.0
	if narrow and rmm_detail:
		_rmm_detail(body, true)
		return
	var list_w := body.size.x if narrow else 124.0
	_rmm_list(Rect2(body.position, Vector2(list_w, body.size.y)))
	if not narrow:
		_rmm_detail(
			Rect2(body.position.x + list_w, body.position.y, body.size.x - list_w, body.size.y),
			false
		)


func _rmm_list(r: Rect2) -> void:
	_fill(r, Color("f4f5f7"))
	# total height of the tree: the list scrolls (wheel or Up / Down) when it is longer than the window
	var total := 0
	for c in Sales.active:
		total += 9
		if rmm_open.get(c, false):
			for ep in Msp.endpoints:
				if ep.client == c:
					total += 8
	var max_scroll := maxi(0, total - int(r.size.y))
	rmm_scroll = clampi(rmm_scroll, 0, max_scroll)
	var y := r.position.y - float(rmm_scroll)
	for c in Sales.active:
		var alert := false
		for ep in Msp.endpoints:
			if ep.client == c and _ep_alert(ep):
				alert = true
		if y >= r.position.y and y + 9 <= r.end.y:
			var hr := Rect2(r.position.x, y, r.size.x - 4, 9)
			_fill(hr, Color("d5d9e0") if not hr.has_point(_mouse) else Color("e4e7ec"))
			_text(
				(
					("- " if rmm_open.get(c, false) else "+ ")
					+ _clip(Msp.CLIENTS[c].name, int(r.size.x / 4.0) - 6)
				),
				hr.position + Vector2(3, 2),
				TXT
			)
			if alert:
				_fill(Rect2(hr.end.x - 7, y + 2, 4, 4), ORANGE)
			_region("client:%d" % c, hr)
		y += 9
		if rmm_open.get(c, false):
			for ep in Msp.endpoints:
				if ep.client != c:
					continue
				if y >= r.position.y and y + 8 <= r.end.y:
					var er := Rect2(r.position.x, y, r.size.x - 4, 8)
					_row(er, ep.name == rmm_sel, false)
					_fill(Rect2(er.position.x + 5, y + 2, 4, 4), RED if _ep_alert(ep) else GREEN)
					_text(ep.name, er.position + Vector2(12, 1), TXT)
					_region("rmm:" + ep.name, er)
				y += 8
	if max_scroll > 0:  # a thin scroll bar on the right edge
		var track := Rect2(r.end.x - 3, r.position.y, 2, r.size.y)
		_fill(track, Color("d5d9e0"))
		var bar_h := maxf(8.0, r.size.y * r.size.y / float(total))
		var bar_y := r.position.y + (r.size.y - bar_h) * float(rmm_scroll) / float(max_scroll)
		_fill(Rect2(track.position.x, bar_y, 2, bar_h), Color("6b7280"))


# an endpoint shows an alert when something is broken on it or an open, unfixed ticket points at it
func _ep_alert(ep: Dictionary) -> bool:
	if str(ep.problem) != "":
		return true
	for t in Msp.tickets:
		if t.status != "Closed" and not t.fix_done and str(t.endpoint) == str(ep.name):
			return true
	return false


func _symptom(problem: String, restore_failed := false) -> String:
	var texts := {
		"spooler": "PRINT SPOOLER SERVICE IS NOT RUNNING",
		"password": "ACCOUNT LOCKED OUT - TOO MANY BAD PASSWORDS",
		"clear_temp": "LOW DISK SPACE - DRIVE C IS 99% FULL",
		"reboot": "STOP ERROR 0X7B - SYSTEM HALTED",
		"av": "407 ITEMS DETECTED: ADWARE.FREECRUISE",
		"restore": "FILES ENCRYPTED (.LOCKED) AND A RANSOM NOTE. DO NOT REBOOT. RESTORE!",
		"adobe": "ADOBE READER PRINT DIALOG IS BROKEN. OTHER APPS PRINT FINE.",
		"project": "NEW PC ARRIVED. SEE THE PROJECT TAB TO SET UP AND MIGRATE.",
	}
	if problem == "restore" and restore_failed:
		return "BACKUP RESTORE FAILED. TRY SHADOW COPIES, PAY THE RANSOM OR GIVE UP: CLOSE THE TICKET."
	if problem.begins_with("onsite_"):
		return str(Onsite.TEXT.symptom)
	return str(texts.get(problem, "NO ISSUES FOUND. ALL SERVICES NORMAL."))


func _rmm_detail(r: Rect2, narrow: bool) -> void:
	_fill(r, WHITE)
	var ep := Msp.endpoint(rmm_sel)
	if ep.is_empty():
		_text("SELECT AN ENDPOINT", r.position + Vector2(6, 8), Color("8b93a1"))
		return
	var chars := int((r.size.x - 8) / 4.0)
	_text(ep.name, r.position + Vector2(4, 4), RMM_GREY)
	_text(_clip(Msp.CLIENTS[ep.client].name, chars), r.position + Vector2(4, 12), Color("5a6372"))
	_text("USER: " + str(ep.user), r.position + Vector2(4, 20), TXT)
	_text("OS: " + str(ep.os), r.position + Vector2(4, 27), TXT)
	var alert: bool = ep.problem != ""
	_fill(Rect2(r.position.x + 4, r.position.y + 36, r.size.x - 8, 9), RED if alert else GREEN)
	_text("ALERT" if alert else "ONLINE - OK", r.position + Vector2(8, 38), WHITE)
	var lines := _wrap(
		_symptom(ep.problem, ep.get("restore_failed", false)) if alert else "NO ISSUES FOUND.", chars
	)
	for i in lines.size():
		_text(lines[i], r.position + Vector2(4, 49 + i * 7), TXT)
	_button(
		"connect", Rect2(r.position.x + 4, r.end.y - 12, 44, 10), "CONNECT", true, Color("f0b27a")
	)
	if narrow:
		_button("rback", Rect2(r.end.x - 34, r.end.y - 12, 30, 10), "BACK")


func _paint_session(body: Rect2) -> void:
	var ep := Msp.endpoint(rmm_sel)
	_fill(body, Color("245c9a"))
	_fill(Rect2(body.position, Vector2(body.size.x, 8)), Color("14263d"))
	_text(
		_clip("REMOTE: " + str(ep.name) + " (" + str(ep.user) + ")", int((body.size.x - 50) / 4.0)),
		body.position + Vector2(3, 1),
		WHITE
	)
	_button(
		"disc",
		Rect2(body.end.x - 46, body.position.y + 1, 44, 6),
		"DISCONNECT",
		true,
		Color("d86b5e")
	)
	var dlg := Rect2(body.position.x + 8, body.position.y + 14, body.size.x - 16, 26)
	_fill(dlg, Color("ece9d8"))
	_fill(Rect2(dlg.position, Vector2(dlg.size.x, 6)), Color("1c3b63"))
	var alert: bool = ep.problem != ""
	_text("SYSTEM MESSAGE" if alert else "ALL CLEAR", dlg.position + Vector2(3, 1), WHITE)
	var lines := _wrap(_symptom(ep.problem, ep.get("restore_failed", false)), int((dlg.size.x - 8) / 4.0))
	for i in mini(lines.size(), 3):
		_text(lines[i], dlg.position + Vector2(4, 9 + i * 6), RED if alert else GREEN)
	_text(_clip(rmm_msg, int((body.size.x - 8) / 4.0)), body.position + Vector2(4, 42), WHITE)
	if not _job.is_empty():
		var frac := clampf(1.0 - float(_job.left) / float(_job.total), 0.0, 1.0)
		_fill(Rect2(body.position.x + 4, body.position.y + 48, body.size.x - 8, 4), Color("14263d"))
		_fill(Rect2(body.position.x + 4, body.position.y + 48, (body.size.x - 8) * frac, 4), GREEN)
	var actions: Array = []
	for key in Msp.FIXES:
		if (key == "shadow" or key == "pay") and ep.problem != "restore":
			continue  # only on a ransomed machine
		if (
			key == "save"
			and (ep.problem in ["", "reboot", "restore", "project"] or ep.user == "server")
		):
			continue  # nobody to warn, or the machine is already down
		actions.append(key)
	var labels: Array = []
	for key in actions:
		labels.append(Msp.reboot_label(ep) if key == "reboot" else Msp.FIXES[key])
	for alt in Msp.alts_for(ep):
		actions.append(alt)
		labels.append(Msp.alt_label(ep, alt))
	if Skills.can_script():
		actions.append("script")
		labels.append("SCRIPT: THIS CLIENT")
	if Skills.script_all():
		actions.append("scriptall")
		labels.append("SCRIPT: ALL CLIENTS")
	var cols := clampi(int(body.size.x / 84.0), 2, 4)
	var bw := floorf((body.size.x - 6) / float(cols))
	# many buttons (other fixes + both scripts): squeeze the rows so they stay inside the window
	var rows := ceili(float(actions.size()) / float(cols))
	var pitch := clampf(floorf((body.end.y - body.position.y - 55.0) / float(rows)), 7.0, 10.0)
	for i in actions.size():
		var r := Rect2(
			body.position.x + 3 + float(i % cols) * bw,
			body.position.y + 54 + float(i / cols) * pitch,
			bw - 2,
			pitch - 1.0
		)
		var id: String = (
			"fix:" + str(actions[i])
			if actions[i] != "script" and actions[i] != "scriptall"
			else str(actions[i])
		)
		var tint := Color("9fd8ff") if id.begins_with("script") else Color("d9dde6")
		if Msp.ALT_DEFS.has(str(actions[i])):
			tint = ALT_TINTS[str(Msp.ALT_DEFS[actions[i]].kind)]
		_button(id, r, _clip(str(labels[i]), int((bw - 4.0) / 4.0)), _job.is_empty(), tint)


func _paint_backups(body: Rect2) -> void:
	_fill(body, WHITE)
	var compact := body.size.y < 100.0
	var row_h := 14.0
	if compact:
		row_h = 11.0 if Sales.active.size() <= 5 else 8.0
	_text(
		(
			"NIGHTLY BACKUP JOBS - BACKUP WATCH CHECKS THEM FOR YOU"
			if Skills.backup_watch()
			else "NIGHTLY BACKUP JOBS - VERIFY EACH ONE EVERY DAY"
		),
		body.position + Vector2(4, 3),
		RMM_GREY
	)
	for idx in Sales.active.size():
		var c: int = Sales.active[idx]
		var b: Dictionary = Msp.backups[c]
		var rr := Rect2(
			body.position.x, body.position.y + 11 + float(idx) * row_h, body.size.x, row_h
		)
		_row(rr, false, c % 2 == 1)
		_text(_clip(Msp.CLIENTS[c].name, 22), rr.position + Vector2(3, 2), TXT)
		var checked: bool = int(b.checked_day) == Campaign.day or Skills.backup_watch()
		var status := "NOT CHECKED TODAY"
		var color := Color("7d8595")
		if checked and b.ok:
			status = "OK - LAST GOOD: TODAY"
			color = GREEN
		elif checked:
			var ago := maxi(1, Campaign.day - int(b.good_day))
			status = "FAILED! LAST GOOD: %d DAY%s AGO" % [ago, "" if ago == 1 else "S"]
			color = RED
		var at := rr.position + (Vector2(100, 2) if compact else Vector2(3, 8))
		_text(_clip(status, int((body.end.x - at.x - 34) / 4.0)), at, color)
		if not checked:
			_button("bkcheck:%d" % c, Rect2(rr.end.x - 31, rr.position.y + 1, 29, 9), "CHECK")
		elif not b.ok:
			_button(
				"bkrerun:%d" % c,
				Rect2(rr.end.x - 31, rr.position.y + 1, 29, 9),
				"RERUN",
				true,
				Color("f0b27a")
			)


func _paint_playbook(body: Rect2) -> void:
	_fill(body, WHITE)
	var pb := Playbook.active
	var book: Dictionary = Playbook.BOOKS[pb.id]
	var steps: Array = book.steps
	var chars := int((body.size.x - 8) / 4.0)
	var title := str(book.title)
	if not bool(pb.done):
		title = (
			"%s - %s (%d/%d)"
			% [book.title, Playbook.current_step().title, int(pb.step) + 1, steps.size()]
		)
	_text(_clip(title, chars), body.position + Vector2(4, 3), RMM_GREY)
	if not _job.is_empty():
		var frac := clampf(1.0 - float(_job.left) / float(_job.total), 0.0, 1.0)
		_fill(Rect2(body.position.x + 3, body.position.y + 10, (body.size.x - 6) * frac, 2), GREEN)
	var y := body.position.y + 13
	if bool(pb.done):
		var res: Dictionary = pb.result
		_text(
			"JOB COMPLETE. GRADE %s (%d%%)." % [str(res.grade), int(res.pts)],
			Vector2(body.position.x + 4, y),
			GREEN
		)
		y += 9
		var room := int((body.end.y - y) / 7.0)
		var shown := 0
		for line in pb.log:
			if shown >= room:
				break
			_text(_clip("- " + str(line), chars), Vector2(body.position.x + 4, y), Color("46506a"))
			y += 7
			shown += 1
		return
	for line in _wrap(str(Playbook.current_step().text), chars):
		_text(line, Vector2(body.position.x + 4, y), Color("46506a"))
		y += 7
	y += 2
	var choices: Array = Playbook.current_step().choices
	var busy := not _job.is_empty()
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var lock := Playbook.lock_reason(ch)
		var label := str(ch.label) if lock == "" else "%s [%s]" % [ch.label, lock]
		_button(
			"pb:%d" % i,
			Rect2(body.position.x + 4, y + float(i) * 10.0, body.size.x - 8, 9),
			_clip(label, chars - 3),
			lock == "" and not busy
		)


func _paint_project(body: Rect2) -> void:
	_fill(body, WHITE)
	if not Playbook.active.is_empty() and (Playbook.is_active() or Msp.project.is_empty()):
		_paint_playbook(body)
		return
	var pr := Msp.project
	if pr.is_empty():
		_text("NO ACTIVE PROJECT.", body.position + Vector2(4, 6), Color("8b93a1"))
		return
	var chars := int((body.size.x - 8) / 4.0)
	var title := (
		"PROJECT: NEW PC FOR %s (#%d)"
		% [str(Msp.CLIENTS[int(pr.client)].contact).to_upper(), int(pr.ticket)]
	)
	_text(_clip(title, chars), body.position + Vector2(4, 3), RMM_GREY)
	var busy := not _job.is_empty()
	if busy:
		var frac := clampf(1.0 - float(_job.left) / float(_job.total), 0.0, 1.0)
		_fill(Rect2(body.position.x + 3, body.position.y + 10, (body.size.x - 6) * frac, 2), GREEN)
	var steps := [
		["scan", "SCAN OLD PC"],
		["deep", "DEEP SCAN"],
		["ask", "ASK THE USER"],
		["backup", "BACKUP OLD PC"],
		["all", "SELECT ALL KNOWN"],
		["migrate", "MIGRATE"],
		["verify", "VERIFY"],
		["hand", "HAND OVER"],
	]
	var cols := clampi(int(body.size.x / 84.0), 2, 4)
	var bw := floorf((body.size.x - 6) / float(cols))
	var rows := ceili(float(steps.size()) / float(cols))
	for i in steps.size():
		var r := Rect2(
			body.position.x + 3 + float(i % cols) * bw,
			body.position.y + 13 + float(i / cols) * 10.0,
			bw - 2,
			9
		)
		var tint := Color("9bd6a8") if steps[i][0] == "hand" else BTN
		_button("proj:" + steps[i][0], r, steps[i][1], not busy and not bool(pr.done), tint)
	var list_y := body.position.y + 13 + float(rows) * 10.0 + 3
	var two_cols := body.size.x >= 300.0
	var per_col := 4 if two_cols else Msp.INSTALL_ITEMS.size()
	for i in Msp.INSTALL_ITEMS.size():
		var it: Dictionary = Msp.INSTALL_ITEMS[i]
		var rx := (
			body.position.x + 4 + (float(i / per_col) * body.size.x * 0.5 if two_cols else 0.0)
		)
		var ry := list_y + float(i % per_col) * 8.0
		var known: bool = pr.found.get(it.id, false)
		var got: bool = pr.migrated.get(it.id, false)
		var picked: bool = pr.selected.get(it.id, false)
		_fill(Rect2(rx, ry, 5, 5), Color("c9d2e0"))
		if picked or got:
			_fill(Rect2(rx + 1, ry + 1, 3, 3), GREEN if got else ORANGE)
		var label := str(it.name) if known else "???"
		_text(label, Vector2(rx + 9, ry), TXT if known else Color("8b93a1"))
		if got:
			_text("COPIED", Vector2(rx + 9 + _tw(label) + 6, ry), GREEN)
		elif known and pr.verified:
			_text("MISSING!", Vector2(rx + 9 + _tw(label) + 6, ry), RED)
		if known and not got and not bool(pr.done):
			_region(
				"pitem:" + str(it.id),
				Rect2(rx - 1, ry - 1, body.size.x * (0.5 if two_cols else 1.0) - 8, 8)
			)
	if bool(pr.done):
		var res: Dictionary = pr.result
		var line := "HANDED OVER. GRADE %s (%d%%)." % [str(res.grade), int(res.pts)]
		_text(
			line,
			Vector2(body.position.x + 4, body.end.y - 9),
			GREEN if res.outcome == "ok" else ORANGE
		)


# ---- PowerShell Academy ------------------------------------------------------
func _paint_learn() -> void:
	var body := _window("POWERSHELL ACADEMY", Color("012456"))
	_fill(body, Color("f3f6fb"))
	if learn_lesson >= 0:
		_paint_quiz(body)
		return
	var chars := int((body.size.x - 8) / 4.0)
	_text(
		_clip("LEVEL %d OF 5. EACH LEVEL: FASTER, MORE RELIABLE FIXES." % Skills.ps_level, chars),
		body.position + Vector2(4, 3),
		Color("012456")
	)
	for i in Skills.LESSONS.size():
		var rr := Rect2(
			body.position.x + 3, body.position.y + 12 + float(i) * 11.0, body.size.x - 6, 10
		)
		var state := (
			"DONE" if i < Skills.ps_level else ("START" if i == Skills.ps_level else "LOCKED")
		)
		_row(rr, false, i % 2 == 1)
		var title := "%d. %s" % [i + 1, Skills.LESSONS[i].title]
		_text(title, rr.position + Vector2(3, 2), TXT if state != "LOCKED" else Color("8b93a1"))
		var col := GREEN if state == "DONE" else (ORANGE if state == "START" else Color("8b93a1"))
		_text(state, Vector2(rr.end.x - _tw(state) - 4, rr.position.y + 2), col)
		if state == "START":
			_region("lesson:%d" % i, rr)
	var lv := Skills.ps_level
	var y := body.position.y + 12 + float(Skills.LESSONS.size()) * 11.0 + 4
	var perks := [
		(
			"FIX TIME %.1fS   FAILS %d%%"
			% [float(Skills.FIX_SECS[lv]), int(float(Skills.FAIL[lv]) * 100.0)]
		),
		(
			"SCRIPTS: "
			+ ("ALL CLIENTS" if lv >= 4 else ("ONE CLIENT" if lv >= 2 else "NONE YET (LEVEL 2)"))
		),
	]
	for line in perks:
		_text(_clip(line, chars), Vector2(body.position.x + 4, y), Color("46506a"))
		y += 7


func _paint_quiz(body: Rect2) -> void:
	var lesson: Dictionary = Skills.LESSONS[learn_lesson]
	var chars := int((body.size.x - 8) / 4.0)
	var head := (
		"%s - RESULT" % lesson.title
		if learn_done
		else "%s - QUESTION %d OF 3" % [lesson.title, mini(learn_q + 1, 3)]
	)
	_text(_clip(head, chars), body.position + Vector2(4, 3), Color("012456"))
	if learn_done:
		var passed := learn_right >= 2
		_text("%d OF 3 RIGHT" % learn_right, body.position + Vector2(4, 16), TXT)
		_text(
			"PASSED! LEVEL UP." if passed else "NOT QUITE. NEED 2 OF 3.",
			body.position + Vector2(4, 26),
			GREEN if passed else RED
		)
		_button("lback", Rect2(body.position.x + 4, body.position.y + 40, 40, 9), "BACK")
		return
	var q: Array = lesson.qs[learn_q]
	var y := body.position.y + 14
	for line in _wrap(str(q[0]), chars):
		_text(line, Vector2(body.position.x + 4, y), TXT)
		y += 7
	y += 3
	for k in learn_opts.size():
		var tint := BTN
		if learn_pick >= 0 and learn_opts[k] == q[1]:
			tint = Color("9bd6a8")
		elif learn_pick == k:
			tint = Color("e8a39b")
		_button(
			"ans:%d" % k,
			Rect2(body.position.x + 4, y + float(k) * 11.0, body.size.x - 8, 10),
			_clip(str(learn_opts[k]), chars - 2),
			learn_pick < 0,
			tint
		)
	if learn_pick >= 0:
		_button(
			"qnext", Rect2(body.end.x - 40, body.end.y - 12, 36, 9), "NEXT", true, Color("9fd8ff")
		)


# ---- profile / stats -----------------------------------------------------------
# ---- Lynk 2013 ------------------------------------------------------------
func _paint_lync() -> void:
	var body := _window("LYNK 2013", Color("0a6ab8"))
	_fill(body, WHITE)
	if Net.desk_state(desk) == "no_link":
		_text("LYNK CANNOT SIGN IN. NO NETWORK CABLE.", body.position + Vector2(6, 8), RED)
		return
	var contacts: Array = Lync.contacts()
	var narrow := body.size.x < 250.0
	var list_w := body.size.x if (narrow and lync_sel == "") else (0.0 if narrow else 104.0)
	if list_w > 0.0:
		for i in contacts.size():
			var who: String = contacts[i]
			var info: Array = Lync.presence(who)
			var rr := Rect2(body.position.x, body.position.y + float(i) * 11.0, list_w, 11)
			_row(rr, who == lync_sel, i % 2 == 1)
			_fill(Rect2(rr.position.x + 3, rr.position.y + 3, 5, 5), Lync.color_of(str(info[1])))
			_text(who.to_upper(), rr.position + Vector2(11, 3), TXT)
			_text(
				_clip(str(info[0]), int((list_w - 56) / 4.0)),
				rr.position + Vector2(50, 3),
				Color("7d8595")
			)
			var n := int(Lync.unread.get(who, 0))
			if n > 0:
				_fill(Rect2(rr.end.x - 11, rr.position.y + 2, 9, 7), RED)
				_text(str(mini(n, 9)), rr.position + Vector2(rr.size.x - 8, 3), WHITE)
			_region("lync:contact:" + who, rr)
	if lync_sel == "" or list_w >= body.size.x:
		if lync_sel == "" and not narrow:
			_text("PICK A CONTACT", body.position + Vector2(list_w + 6, 8), Color("8b93a1"))
		return
	var x := body.position.x + list_w
	var w := body.end.x - x
	_fill(Rect2(x, body.position.y, w, body.size.y), Color("f1f4f8"))
	var info2: Array = Lync.presence(lync_sel)
	Lync.mark_read(lync_sel)
	_text(
		_clip(
			"%s%s - %s"
			% [
				lync_sel.to_upper(),
				" (OWNER)" if Social.is_owner(lync_sel) else "",
				str(info2[0])
			],
			int((w - 40) / 4.0)
		),
		Vector2(x + 4, body.position.y + 3),
		Color("0a6ab8")
	)
	if narrow:
		_button("lync:back", Rect2(body.end.x - 28, body.position.y + 1, 26, 8), "BACK")
	var chars := int((w - 8) / 4.0)
	var lines: Array = []
	for entry in Lync.chats.get(lync_sel, []):
		for part in _wrap(str(entry[1]), chars - 3):
			lines.append([str(entry[0]), part])
	var rows := int((body.size.y - 38) / 7.0)
	var y := body.position.y + 13
	for i in range(maxi(0, lines.size() - rows), lines.size()):
		var mine: bool = lines[i][0] == "me"
		_text(
			("> " if mine else "") + str(lines[i][1]),
			Vector2(x + 4, y),
			Color("0a6ab8") if mine else TXT
		)
		y += 7
	var by := body.end.y - 11
	if Lync.pending.has(lync_sel):
		var opts: Array = Lync.pending[lync_sel].options
		var bw := floorf((w - 6) / float(maxi(1, opts.size())))
		for i in opts.size():
			_button(
				"lync:reply:%d" % i,
				Rect2(x + 3 + float(i) * bw, by, bw - 2, 9),
				_clip(str(opts[i].label), int((bw - 6) / 4.0))
			)
		return
	var acts := [["lunch", "LUNCH?"], ["help", "NEED A HAND"], ["thanks", "THANKS!"]]
	if lync_sel == Lync.boss():
		acts = [["boss", "ANY ADVICE?" if lync_sel == "Morgan" else "HOW ARE WE DOING?"]]
	var aw := floorf((w - 6) / float(acts.size()))
	for i in acts.size():
		_button(
			"lync:act:" + str(acts[i][0]),
			Rect2(x + 3 + float(i) * aw, by, aw - 2, 9),
			str(acts[i][1])
		)


func _lync_action(parts: PackedStringArray) -> void:
	match parts[1]:
		"contact":
			lync_sel = parts[2]
			Lync.open_chat(lync_sel)
		"back":
			lync_sel = ""
		"reply":
			Lync.reply(lync_sel, int(parts[2]))
		"act":
			Lync.send_action(lync_sel, parts[2])


# ---- LabRat Nerds: forum + IRC ------------------------------------------------------
func _paint_nerds() -> void:
	var body := _window("LABRAT NERDS - COMMUNITY", Color("c0561a"))
	_fill(body, WHITE)
	if Net.desk_state(desk) != "ok":
		_text("THE FORUM NEEDS THE INTERNET.", body.position + Vector2(6, 8), AMBER)
		return
	Nerds.ensure_threads()
	_fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("f0d9c4"))
	_button(
		"nerds:tab:forum",
		Rect2(body.position.x + 2, body.position.y + 1, 36, 8),
		"FORUM",
		true,
		BTN_HI if nerds_tab == "forum" else BTN
	)
	_button(
		"nerds:tab:irc",
		Rect2(body.position.x + 40, body.position.y + 1, 52, 8),
		"IRC CHAT",
		true,
		BTN_HI if nerds_tab == "irc" else BTN
	)
	_text(
		"KARMA %d  %s" % [Nerds.karma, Nerds.rank()],
		Vector2(body.end.x - 76, body.position.y + 2),
		Color("c0561a")
	)
	var area := Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
	if nerds_tab == "irc":
		_paint_irc(area)
		return
	var chars := int((area.size.x - 62) / 4.0)
	var y := area.position.y + 3
	for i in Nerds.threads.size():
		var th: Dictionary = Nerds.threads[i]
		var def: Dictionary = Nerds.THREADS[int(th.id)]
		var rr := Rect2(area.position.x, y, area.size.x, 11)
		_row(rr, false, i % 2 == 1)
		var tag := "ANSWERED" if th.answered else ("READ" if th.read else "NEW")
		_text(
			_clip(str(def.title), chars),
			rr.position + Vector2(3, 3),
			TXT if not th.read else Color("7d8595")
		)
		_text(
			tag,
			Vector2(rr.end.x - 58, rr.position.y + 3),
			GREEN if th.answered else (Color("7d8595") if th.read else ORANGE)
		)
		_button(
			"nerds:read:%d" % i, Rect2(rr.end.x - 32, rr.position.y + 1, 14, 9), "R", not th.read
		)
		_button(
			"nerds:answer:%d" % i,
			Rect2(rr.end.x - 16, rr.position.y + 1, 14, 9),
			"A",
			not th.answered
		)
		y += 12
	_text(
		"R = READ (A LITTLE XP)   A = ANSWER (NEEDS THE SKILL: MORE XP + KARMA)",
		Vector2(area.position.x + 4, y + 2),
		Color("7d8595")
	)


func _paint_irc(area: Rect2) -> void:
	var chars := int((area.size.x - 8) / 4.0)
	_text("#LABRATNERDS   6 NERDS ONLINE", area.position + Vector2(4, 3), Color("c0561a"))
	var rows := int((area.size.y - 38) / 7.0)
	var lines: Array = []
	for entry in Nerds.channel:
		for part in _wrap("%s: %s" % [str(entry[0]), str(entry[1])], chars):
			lines.append([str(entry[0]), part])
	var y := area.position.y + 12
	for i in range(maxi(0, lines.size() - rows), lines.size()):
		var nick := str(lines[i][0])
		var color: Color = (
			Nerds.NICKS[nick].color
			if Nerds.NICKS.has(nick)
			else (BTN_SH if nick != "you" else Color("0a6ab8"))
		)
		_text(lines[i][1], Vector2(area.position.x + 4, y), color)
		y += 7
	var by := area.end.y - 21
	var hint: Dictionary = Nerds.hint
	if not hint.is_empty() and not bool(hint.get("pending", false)):
		_text(
			_clip(
				(
					"VERDICT: %s (%d OF %d AGREE)"
					% [str(hint.best).to_upper(), int(hint.votes), int(hint.total)]
				),
				chars
			),
			Vector2(area.position.x + 4, by - 8),
			GREEN
		)
	var wait := Nerds.cooldown_left()
	var ask_ready := Nerds.can_ask()
	var label := "ASK ABOUT THIS TICKET" if ask_ready else "WAIT %ds" % int(ceilf(wait))
	_button(
		"nerds:ask:ticket",
		Rect2(area.position.x + 3, by + 9, area.size.x * 0.5 - 4, 9),
		label,
		ask_ready
	)
	_button(
		"nerds:ask:step",
		Rect2(area.position.x + area.size.x * 0.5 + 1, by + 9, area.size.x * 0.5 - 4, 9),
		"ASK ABOUT THE JOB" if ask_ready else "...",
		ask_ready and Playbook.is_active()
	)


func _nerds_action(parts: PackedStringArray) -> void:
	match parts[1]:
		"tab":
			nerds_tab = parts[2]
		"read":
			Nerds.read_thread(int(parts[2]))
		"answer":
			_say(Nerds.answer_thread(int(parts[2])))
		"ask":
			if parts[2] == "step":
				Nerds.ask_step()
			else:
				var t := Msp.ticket(psa_sel) if psa_sel > 0 else {}
				if t.is_empty() or t.status == "Closed":
					var open := Msp.open_tickets()
					t = open[0] if not open.is_empty() else {}
				Nerds.ask_ticket(t)


func _paint_boardroom() -> void:
	var body := _window("BOARDROOM - " + Msp.COMPANY, Color("6b421c"))
	_fill(body, Color("f3f6fb"))
	var tabs := [
		["books", "BOOKS"],
		["clients", "CLIENTS"],
		["projects", "PROJECTS"],
		["team", "TEAM"],
		["stack", "STACK"]
	]
	var tab_w := minf(42.0, (body.size.x - 4.0) / float(tabs.size()))
	_fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("e4d9c9"))
	for i in tabs.size():
		var tint := BTN_HI if board_tab == tabs[i][0] else BTN
		var tab_label: String = tabs[i][1] if tab_w >= 40.0 or tabs[i][0] != "projects" else "PROJ"
		_button(
			"btab:" + tabs[i][0],
			Rect2(body.position.x + 2 + float(i) * tab_w, body.position.y + 1, tab_w - 2.0, 8),
			tab_label,
			true,
			tint
		)
	var area := Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
	match board_tab:
		"clients":
			_board_clients(area)
		"projects":
			_board_projects(area)
		"team":
			_board_team(area)
		"stack":
			_board_stack(area)
		_:
			_board_books(area)


func _board_rows(rows: Array, x: float, y: float, value_x: float, limit: int) -> float:
	for row in rows:
		_text(str(row[0]), Vector2(x, y), Color("46506a"))
		_text(_clip(str(row[1]), limit), Vector2(x + value_x, y), row[2])
		y += 7
	return y


func _board_books(a: Rect2) -> void:
	var est := Owner.weekly_estimate()
	var two := a.size.x >= 300.0
	var x := a.position.x + 4
	var y := a.position.y + 3
	var value_x := 58.0 if two else minf(104.0, a.size.x * 0.55)
	var room := int((a.size.x * (0.5 if two else 1.0) - value_x - 8.0) / 4.0)
	var w2_ok: bool = float(est.w2) <= Owner.W2_TARGET
	var margin_ok: bool = float(est.margin) >= Owner.PEER_MARGIN
	var left := [
		["CASH", "$%d" % Owner.cash, GREEN if Owner.cash >= 0 else RED],
		["REVENUE/WEEK", "$%d" % int(est.revenue), TXT],
		["PAYROLL (W-2)", "-$%d" % int(est.payroll), TXT],
		[
			"W-2 RATIO",
			"%d%% (TARGET %d%%)" % [int(100.0 * float(est.w2)), int(100.0 * Owner.W2_TARGET)],
			GREEN if w2_ok else RED
		],
		["OTHER COSTS", "-$%d" % int(est.fixed), TXT],
		["MARKETING", "-$%d" % int(est.marketing), TXT],
		["EBITDA", "$%d" % int(est.ebitda), GREEN if int(est.ebitda) >= 0 else RED],
		[
			"MARGIN",
			"%d%% (PEERS %d%%)" % [int(100.0 * float(est.margin)), int(100.0 * Owner.PEER_MARGIN)],
			GREEN if margin_ok else AMBER
		],
	]
	y = _board_rows(left, x, y, value_x, room)
	var advisers := []
	if Owner.flags.get("peer_group", false):
		advisers.append("PEERS")
	if Owner.flags.get("mentor", false):
		advisers.append("DANA")
	if Owner.flags.get("backup_service", false):
		advisers.append("BACKUP SVC")
	var right := [
		["WEEK", "%d OF %d" % [Campaign.day, Campaign.TOTAL_DAYS], TXT],
		["A/R OWED", "$%d" % Owner.ar_total(), AMBER if Owner.ar_total() > 0 else TXT],
		["COMPANY VALUE", "$%d (%.1fX)" % [Owner.valuation(), Owner.multiple()], Color("6b421c")],
		["TEAM SPEED", "%.1f" % Owner.team_speed(), TXT],
		["OWNER DRAW", "$%d/WK (%s)" % [Owner.draw_due() if Campaign.day >= Owner.DRAW_START else int(Owner.DRAW.get(Owner.draw_policy, 0)), Owner.draw_policy.to_upper()], TXT],
		["GOAL", Owner.goal_row()[1], TXT],
		["ON BOARD", ", ".join(advisers) if not advisers.is_empty() else "NOBODY YET", TXT],
		["MATURITY", "%d %s" % [Owner.oml(), Owner.OML_NAMES[Owner.oml() - 1]], Color("6b421c")],
	]
	right.append(["PATH", Owner.path_label(), Color("6b421c")])
	if Campaign.day >= 6 and not Owner.flags.get("rdp_safe", false):
		right.append(
			["RDP", "WEAK" if Owner.flags.get("rdp_weak", false) else "OPEN TO THE INTERNET", RED]
		)
	if Owner.at_risk_count() > 0:
		right.append(["POACH RISK", "%d CLIENT(S) AT RISK" % Owner.at_risk_count(), RED])
	if two:
		_board_rows(right, a.position.x + a.size.x * 0.5 + 4, a.position.y + 3, 58.0, room)
	else:
		_board_rows(right, x, y + 3, value_x, room)


func _board_clients(a: Rect2) -> void:
	var x := a.position.x + 4
	var y := a.position.y + 3
	_text(
		"CLIENT   FEE/WEEK   MOOD   PROFIT" + ("   HOURS" if a.size.x >= 300.0 else ""),
		Vector2(x, y),
		Color("6b421c")
	)
	y += 8
	for i in mini(Sales.active.size(), int((a.end.y - y) / 7.0)):
		var c: int = Sales.active[i]
		_text(_clip(str(Msp.CLIENTS[c].short), 5), Vector2(x, y), TXT)
		_text("$%d" % Owner.client_fee(c), Vector2(x + 24, y), Color("46506a"))
		var meter := Rect2(x + 58, y, 36, 5)
		_fill(meter, Color("c9d2e0"))
		var happy := Sales.mood(c)
		_fill(
			Rect2(meter.position, Vector2(meter.size.x * float(happy) / 100.0, 5)),
			GREEN if happy >= 55 else (AMBER if happy >= 30 else RED)
		)
		var profit := Owner.client_profit(c)
		_text(
			"%s$%d" % ["+" if profit >= 0 else "-", absi(profit)],
			Vector2(x + 98, y),
			GREEN if profit >= 0 else RED
		)
		var wide := a.size.x >= 300.0
		if wide:
			var over := Projects.over_hours(c)
			var hrs := (
				"%dH" % int(Projects.avg_hours(c)) + ((" +%d" % int(over)) if over >= 3.0 else "")
			)
			_text(hrs, Vector2(x + 132, y), RED if over >= 3.0 else Color("46506a"))
		var tag := ""
		if Owner.overdue(c):
			tag = "LATE $%d" % Owner.ar_total(c)
		elif Owner.pay_delay(c) > 0:
			tag = "PAYS SLOW"
		var due := Owner.review_due(c)
		var shown := tag
		if shown == "":
			shown = "AT RISK" if Owner.poach_risk(c) >= 0.12 else ("REVIEW DUE" if due else "")
		var letters := (
			("B" if not Msp.backups[c].ok else "")
			+ ("P" if float(Owner.patch_debt.get(c, 0.0)) >= 4.0 else "")
			+ ("M" if Sales.mood(c) < 50 else "")
		)
		if letters != "":
			shown += " GAPS " + letters
		_text(
			_clip(shown, int((a.end.x - x - (174 if wide else 134)) / 4.0)),
			Vector2(x + (172 if wide else 132), y),
			AMBER if shown != "" else Color("46506a")
		)
		y += 7
	if not Owner.gone.is_empty() and y < a.end.y - 6:
		var names := []
		for lost_client in Owner.gone:
			names.append(str(Msp.CLIENTS[int(lost_client)].short))
		_text(
			_clip(
				"LOST TO " + Owner.COMPETITOR.to_upper() + ": " + ", ".join(names),
				int((a.size.x - 8) / 4.0)
			),
			Vector2(x, y + 2),
			RED
		)


func _board_projects(a: Rect2) -> void:
	var x := a.position.x + 4
	var y := a.position.y + 3
	var limit := int((a.size.x - 8.0) / 4.0)
	var est := Owner.weekly_estimate()
	_text(_clip("RECURRING $%d/WK" % int(est.revenue), limit), Vector2(x, y), Color("6b421c"))
	y += 7
	_text(
		_clip(
			(
				"SERVICES $%d/WK   DONE %d JOBS, $%d"
				% [Projects.service_revenue(), Projects.completed_count, Projects.completed_profit]
			),
			limit
		),
		Vector2(x, y),
		Color("6b421c")
	)
	y += 8
	var shown := 0
	for p in Projects.projects:
		if y > a.end.y - 14:
			break
		if p.status != "active" and shown >= 2 and p.status != "done":
			continue
		var left := (
			"WEEK %d/%d" % [int(p.total) - int(p.weeks), int(p.total)]
			if p.status == "active"
			else str(p.status).to_upper()
		)
		var money := (
			("EST $%d" % Projects.quote_profit({"price": p.price, "hw": p.hw, "est": p.est}))
			if p.status == "active"
			else ("%s$%d" % ["+" if int(p.profit) >= 0 else "-", absi(int(p.profit))])
		)
		var color := (
			RED
			if (p.status == "lost" or (p.status == "done" and int(p.profit) < 0) or bool(p.creep))
			else (GREEN if p.status == "done" else TXT)
		)
		_text(
			_clip(
				(
					"%s %s %s %s%s"
					% [
						str(Msp.CLIENTS[int(p.client)].short),
						str(Projects.TYPES[str(p.type)].label).split(" (")[0],
						left,
						money,
						" CREEP" if bool(p.creep) else ""
					]
				),
				limit
			),
			Vector2(x, y),
			color
		)
		y += 7
		shown += 1
	if Projects.projects.is_empty():
		_text(
			_clip(
				"NO PROJECTS YET. VIC BRINGS THEM IN: DESKTOPS, NETWORKS, SERVERS, SECURITY.", limit
			),
			Vector2(x, y),
			Color("46506a")
		)
		y += 7
	y += 3
	var drag := int(Projects.drag() * 100.0)
	_text(_clip("TEAM TIME ON PROJECTS %d%%" % drag, limit), Vector2(x, y), Color("46506a"))
	y += 7
	_text(
		_clip(
			(
				"BAD WORD OF MOUTH: %s"
				% (("%d WK" % Projects.wom_weeks) if Projects.wom_weeks > 0 else "NONE")
			),
			limit
		),
		Vector2(x, y),
		RED if Projects.wom_weeks > 0 else Color("46506a")
	)


func _board_team(a: Rect2) -> void:
	var x := a.position.x + 4
	var y := a.position.y + 3
	var limit := int((a.size.x - 8.0) / 4.0)
	var rows := []
	for i in Owner.crew_size():
		var member: Dictionary = Owner.CREW[i]
		var wage := int(round(float(member.wage) * Owner.wage_mult()))
		rows.append(["%s  SKILL %.1f  $%d/WK" % [str(member.name).to_upper(), float(member.skill), wage], TXT])
	rows.append(["MORGAN  MANAGER  $%d/WK" % int(round(float(Owner.MORGAN_WAGE) * Owner.wage_mult())), TXT])
	if Roles.partner() != "":
		rows.append(["%s  CO-OWNER  HANDS-ON %.1f  TRUST %d" % [Roles.partner().to_upper(), Partner.hands(), Partner.trust], Color("6b421c")])
	for hire in Owner.extra_staff:
		var tag := str(Owner.TRAITS[hire.get("trait", "steady")].label)
		rows.append(
			[
				(
					"%s  %.2f  $%d/WK  %s"
					% [str(hire.name).to_upper(), float(hire.skill), Owner.hire_wage(hire), tag]
				),
				TXT
			]
		)
	var plan: Dictionary = Owner.VIC_PLANS[Owner.vic_plan]
	rows.append(
		[
			"VIC  %s  $%d/WK + $%d A DEAL" % [plan.label, int(plan.wage), int(plan.per_deal)],
			Color("6b421c")
		]
	)
	var moods := Owner.vic_new_client_mood()
	rows.append(
		[
			(
				"VIC DEALS %d  NEW CLIENT MOOD %s"
				% [Owner.vic_deals, "-" if moods < 0 else "%d%%" % moods]
			),
			TXT
		]
	)
	var morale := Owner.stack_sum("morale")
	rows.append(["MORALE FROM TOOLS %+d%%" % int(morale), GREEN if morale >= 0.0 else RED])
	rows.append(
		[
			"BURNOUT %d%%" % int(Owner.burnout),
			GREEN if Owner.burnout < 40.0 else (AMBER if Owner.burnout < 70.0 else RED)
		]
	)
	for line in Growth.board_lines():
		rows.append(line)
	for row in rows:
		if y > a.end.y - 7:
			break
		_text(_clip(str(row[0]), limit), Vector2(x, y), row[1])
		y += 7


func _board_stack(a: Rect2) -> void:
	var x := a.position.x + 4
	var y := a.position.y + 3
	var limit := int((a.size.x - 8.0) / 4.0)
	for category in Owner.STACK:
		var option: Dictionary = Owner.stack_option(str(category))
		_text(
			_clip(
				(
					"%s: %s  $%d/WK"
					% [
						Owner.STACK[category].label,
						str(option.name).to_upper(),
						int(option.get("cost", 0))
					]
				),
				limit
			),
			Vector2(x, y),
			Color("6b421c")
		)
		y += 7
		var fx := []
		if option.has("speed") and float(option.speed) != 0.0:
			fx.append("SPEED %+d%%" % int(100.0 * float(option.speed)))
		if option.has("morale") and int(option.morale) != 0:
			fx.append("MORALE %+d%%" % int(option.morale))
		if option.has("issues") and float(option.issues) != 1.0:
			fx.append("TICKETS %+d%%" % int(100.0 * (float(option.issues) - 1.0)))
		if option.has("sales") and float(option.sales) != 0.0:
			fx.append("SALES %+d%%" % int(100.0 * float(option.sales)))
		if option.has("margin"):
			fx.append("$%d A DEAL" % int(option.margin))
		_text(
			_clip(
				"  " + str(option.note) + (": " + ", ".join(fx) if not fx.is_empty() else ""), limit
			),
			Vector2(x, y),
			Color("46506a")
		)
		y += 8
	_text(
		_clip("TOOLS $%d/WK   TICKET LOAD x%.2f" % [Owner.stack_cost(), Owner.issue_mult()], limit),
		Vector2(x, y),
		TXT
	)


func _mood_color(who: String) -> Color:
	if Social.is_friendly(who):
		return GREEN
	if Social.is_hostile(who):
		return RED
	return AMBER if Social.is_cold(who) else Color("7d8595")


func _paint_stats() -> void:
	var body := _window("PROFILE - " + Msp.COMPANY, Color("2f6b4f"))
	_fill(body, Color("f3f6fb"))
	var two_cols := body.size.x >= 300.0
	var y := body.position.y + 4
	var bar_w := (
		minf(70.0, body.size.x * 0.5 - 96.0) if two_cols else minf(70.0, body.size.x - 96.0)
	)
	for key in Skills.NAMES:
		_text(str(Skills.NAMES[key]), Vector2(body.position.x + 4, y), TXT)
		_text("LV %d" % Skills.level(key), Vector2(body.position.x + 60, y), ORANGE)
		var bar := Rect2(body.position.x + 84, y, bar_w, 5)
		_fill(bar, Color("c9d2e0"))
		_fill(Rect2(bar.position, Vector2(bar.size.x * Skills.progress(key), 5)), GREEN)
		y += 9
	var x := body.position.x + 4
	if two_cols:
		x = body.position.x + body.size.x * 0.5 + 4
		y = body.position.y + 4
	else:
		y += 4
	_text("OWNERS AND TEAM", Vector2(x, y), Color("2f6b4f"))
	y += 8
	for who in Social.people():
		_text(who, Vector2(x, y), TXT)
		_text(Social.mood(who), Vector2(x + 44, y), _mood_color(who))
		var meter := Rect2(x + 92, y, 40, 5)
		_fill(meter, Color("c9d2e0"))
		_fill(
			Rect2(
				meter.position, Vector2(meter.size.x * float(Social.value(who) + 100) / 200.0, 5)
			),
			_mood_color(who)
		)
		y += 8
	y += 4
	var lines := []
	if Campaign.active:
		lines.append(
			(
				"DAY %d OF %d   REPUTATION %d   CASH $%d"
				% [Campaign.day, Campaign.TOTAL_DAYS, Campaign.rep, Campaign.cash]
			)
		)
	else:
		lines.append("FREE PLAY")
	lines.append(
		"CLOSED %d  SLA MISSED %d  REOPENED %d" % [Msp.closed_ok, Msp.breached, Msp.reopened]
	)
	lines.append("SCORE %d   PHONE CALLS %d" % [Msp.score, Social.calls_answered])
	if Campaign.active and Campaign.mode == "tech" and Expo.invited and not Expo.decided:
		lines.append("RODENT NATION: %d OF 4 KPIS MET (NEED %d)" % [Expo.passed(), Expo.NEED])
		for k in Expo.kpis():
			if not bool(k.ok):
				lines.append("  STILL NEEDED: %s (NOW %s)" % [str(k.name), str(k.now)])
	elif Campaign.active and Campaign.mode == "tech" and Expo.decided:
		lines.append("RODENT NATION: %s" % ("YOU WENT" if Expo.qualified else "NOT THIS YEAR"))
	lines.append("CLIENTS %d   HAPPINESS %d%%" % [Sales.active.size(), int(Sales.average())])
	if Shift.active():
		lines.append(
			(
				"ENERGY %d%% (%s)%s"
				% [int(Shift.energy), Shift.label(), "  ON CALL" if Shift.is_on_call() else ""]
			)
		)
		lines.append(Shift.summary())
	if Growth.status_line() != "":
		lines.append(Growth.status_line())
	if Campaign.active and Skills.next_perk() != "":
		lines.append(Skills.next_perk())
	for line in lines:
		_text(_clip(line, int((body.end.x - x - 4) / 4.0)), Vector2(x, y), Color("46506a"))
		y += 7
