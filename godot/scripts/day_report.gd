extends CanvasLayer
const Dash := preload("res://scripts/dash.gd")  # the metrics record (R20): the day report's sparkline
const SPARK_H := 15.0
# gdlint:disable=class-definitions-order
# The end-of-day report for the campaigns: a dimmed screen with a dark panel: a big grade and the
# score / paycheck / reputation / cash on one side (or on top in narrow formats), the details
# grouped under TICKETS / PEOPLE / ENERGY (the owner's books as one group), then the ending text
# and a button. Enter / Space / click continues. Drawn in code with the 3x5 pixel font; the text
# scale drops from 2 to 1 when a narrow format cannot fit everything.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")
const PANEL := Color("171c2a")
const STRIPE := Color("1f2536")
const LINE := Color("3a4562")
const LABEL := Color("b4bfd6")
const HEAD := Color("7fb6ff")
const GOOD := Color("8fe3a0")
const BAD := Color("ff8a80")
const WARN := Color("ffd27a")
var _row_h := 7.0  # row height in virtual pixels (one font pixel at scale 1); 6 when the short wide screen needs it
var _pad := 1.0  # text offset inside a row (0 in the tight 6 pixel rows)
const GRADE_COLORS := {
	"S": Color("f5d442"),
	"A": Color("5fd068"),
	"B": Color("5aa0e8"),
	"C": Color("e0a030"),
	"D": Color("e0463c"),
}

const BIG_GRADES := {
	"S": [".XXX", "X...", ".XX.", "...X", "XXX."],
	"A": [".XX.", "X..X", "XXXX", "X..X", "X..X"],
	"B": ["XXX.", "X..X", "XXX.", "X..X", "XXX."],
	"C": [".XXX", "X...", "X...", "X...", ".XXX"],
	"D": ["XXX.", "X..X", "X..X", "X..X", "XXX."],
}
var is_open := false
var report := {}

var _canvas: Node2D
var _mouse := Vector2.ZERO
var _button := Rect2()
var _fade := 0.0
var _sc := 1  # text scale in use (2 on narrow screens that have room for it)
var _o := Vector2.ZERO  # panel origin in screen pixels
var _opened := 0  # the report ignores confirm keys for a moment so it is not dismissed unread


func _ready() -> void:
	layer = 70
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)


func show_report(data: Dictionary) -> void:
	report = data
	is_open = true
	Sfx.play_grade(str(data.get("grade", "")))
	Cards.cover()
	_opened = Time.get_ticks_msec()
	_canvas.visible = true
	_mouse = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	create_tween().tween_method(_set_fade, _fade, 1.0, 0.3)
	_canvas.queue_redraw()


func _set_fade(value: float) -> void:
	_fade = value
	_canvas.modulate.a = value


func finish() -> void:
	if not is_open:
		return
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_canvas.visible = false
	_fade = 0.0
	Campaign.report_continue(bool(report.get("final", false)))
	Cards.flush()


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
		if _button.has_point(_mouse) and Time.get_ticks_msec() - _opened >= 600:
			finish()
	elif Controls.pressed(event):
		if Controls.confirm(event, false) and Time.get_ticks_msec() - _opened >= 600:
			finish()
	else:
		return
	get_viewport().set_input_as_handled()


func _books() -> bool:
	return report.has("rows") or report.has("groups")


func _groups() -> Array:
	var all := _groups_raw()
	return _soft(all) if bool(report.get("cozy", false)) else all


# cozy Easy: the report keeps its good news and its honest counts but shows no red and no penalty lines
# (SLA MISSED, REOPENED and a negative COWORKERS row are left out; STILL OPEN reads "carried over")
func _soft(groups: Array) -> Array:
	var out := []
	for g in groups:
		var rows := []
		for row in g[1]:
			var label := str(row[0])
			var value := str(row[1])
			if label in ["SLA MISSED", "REOPENED", "REOPENS"] or (label == "COWORKERS" and value.begins_with("-")):
				continue
			if label == "STILL OPEN":
				label = Difficulty.ct("open_row")
			rows.append([label, value, WARN if row[2] == BAD else row[2]])
		out.append([g[0], rows])
	return out


func _groups_raw() -> Array:
	if report.has("groups"):
		var all: Array = report.groups.duplicate()
		if str(report.get("mutator", "")) != "":
			all.append(["THIS WEEK", [["EVENT", str(report.mutator), WARN]]])
		return all
	if report.has("rows"):
		var books := []
		for row in report.rows:
			if str(row[0]) != "":
				books.append(row)
		if str(report.get("mutator", "")) != "":
			books.append(["THIS WEEK", str(report.mutator), WARN])
		return [["", books]]
	var r := report
	var mood := int(r.clients)
	var social := int(r.social)
	var groups := [
		[
			"TICKETS",
			[
				["CLOSED", str(r.closed), GOOD if int(r.closed) > 0 else WHITE],
				["SLA MISSED", str(r.missed), BAD if int(r.missed) > 0 else GOOD],
				["REOPENED", str(r.reopened), BAD if int(r.reopened) > 0 else GOOD],
				["STILL OPEN", str(r.open_left), WARN if int(r.open_left) > 0 else GOOD],
			]
		],
		[
			"PEOPLE",
			[
				["CLIENT MOOD", "%d%%" % mood, GOOD if mood >= 70 else (BAD if mood < 40 else WARN)],
				[
					"COWORKERS",
					"%+d" % social if social != 0 else "0",
					GOOD if social > 0 else (BAD if social < 0 else WHITE)
				],
			]
		],
	]
	if str(r.get("mutator", "")) != "":
		groups.append(["THIS WEEK", [["EVENT", str(r.mutator), WARN]]])
	var stepped := int(r.get("owners", Owners.stepped))
	if stepped > 0:
		groups[1][1].append(["OWNERS STEPPED IN", str(stepped), GOOD])
	if int(r.get("favours", 0)) > 0:  # R36: work done by text, off the books
		groups[1][1].append(["UNBILLED FAVOURS", str(int(r.favours)), WARN])
	var energy := []
	if int(r.get("energy", -1)) >= 0:
		var e := int(r.energy)
		energy.append(["ENERGY", "%d%%" % e, BAD if e < 35 else (WARN if e < 55 else GOOD)])
		var notes := []
		if int(r.get("late", 0)) >= 10:
			notes.append("LATE %dM" % int(r.late))
		if int(r.get("oncall", 0)) > 0:
			notes.append("ON CALL")
		if not notes.is_empty():
			energy.append(["LATE / ON CALL", " ".join(notes), WARN])
	if float(r.overtime) > 0.0:
		energy.append(["OVERTIME", "%.1fH" % float(r.overtime), GOOD])
	if not energy.is_empty():
		groups.append(["ENERGY", energy])
	return groups


# the big numbers: [label, short label, value, colour]
func _hero() -> Array:
	var r := report
	var delta := int(r.get("rep_delta", 0))
	var tiles := []
	if not _books():
		var pts := int(r.points)
		var pcol := GOOD if pts >= 10 else (BAD if pts < 0 else WHITE)
		tiles.append(["DAY SCORE", "SCORE", str(pts), pcol])
		tiles.append(["PAYCHECK", "PAY", "$%d" % int(r.pay), GOOD if int(r.pay) > 0 else WHITE])
	var rep_text := "%d (%+d)" % [int(r.rep), delta] if delta != 0 else str(int(r.rep))
	var rcol := GOOD if delta > 0 else (BAD if delta < 0 else WHITE)
	tiles.append([str(report.get("rep_name", "REPUTATION")), str(report.get("rep_short", "REP")), rep_text, rcol])
	if not _books():
		var cash := int(r.cash)
		tiles.append(["CASH", "CASH", "%s$%d" % ["-" if cash < 0 else "", absi(cash)], GOOD if cash >= 0 else BAD])
	if bool(r.get("cozy", false)):  # no red, no minus signs on the day score or the reputation move
		for tile in tiles:
			if tile[3] == BAD:
				tile[3] = WARN
		if not _books() and int(r.points) < 0:
			tiles[0][2] = "0"
		if delta < 0:
			tiles[tiles.size() - (1 if _books() else 2)][2] = str(int(r.rep))
	return tiles


# text in virtual pixels relative to the panel
func _t(s: String, x: float, y: float, c: Color, mult: int = 1) -> void:
	PixelFont.draw(_canvas, s, _o + Vector2(x, y) * float(_sc), c, _sc * mult)


func _tw(s: String, mult: int = 1) -> float:
	return float(PixelFont.width(s, _sc * mult)) / float(_sc)


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	var u := float(_sc)
	_canvas.draw_rect(Rect2(_o + Vector2(x, y) * u, Vector2(w, h) * u), c)


# one list row: label left, value right; a value that does not fit goes on its own line
func _row(x: float, y: float, w: float, row: Array, stripe: bool, draw: bool) -> float:
	var label := str(row[0])
	var value := str(row[1])
	var two := _tw(label) + _tw(value) + 8.0 > w
	var h := _row_h * (2.0 if two else 1.0)
	if draw:
		if stripe:
			_r(x, y, w, h, STRIPE)
		_t(label, x + 2.0, y + _pad, LABEL)
		_t(value, x + w - 2.0 - _tw(value), y + _pad + (_row_h if two else 0.0), row[2])
	return h


func _list(x: float, y: float, w: float, groups: Array, draw: bool) -> float:
	var h := 0.0
	for g in groups:
		var name := str(g[0])
		if name != "":
			if draw:
				_t(name, x + 2.0, y + h + _pad, HEAD)
				_r(x + _tw(name) + 5.0, y + h + _pad + 2.0, w - _tw(name) - 5.0, 1.0, LINE)
			h += _row_h
		var i := 0
		for row in g[1]:
			h += _row(x, y + h, w, row, i % 2 == 1, draw)
			i += 1
		h += 1.0
	return h - 1.0


# the grade letter in a 4x5 hand-drawn set: the 3x5 font makes B and E look alike at this size
func _big_grade(grade: String, x: float, y: float, color: Color) -> void:
	var rows: Array = BIG_GRADES[grade]
	for ry in rows.size():
		for rx in 4:
			if str(rows[ry])[rx] == "X":
				_r(x + float(rx * 4), y + float(ry * 4), 4.0, 4.0, color)


# the grade box, then the stat tiles (big) or rows (compact); returns its height
func _hero_block(x: float, y: float, w: float, big: bool, draw: bool) -> float:
	var grade := str(report.grade)
	var gcol: Color = GRADE_COLORS.get(grade, WHITE)
	var tiles := _hero()
	var owner_books := _books()
	var gh := 28.0 if big else 26.0
	var gw := 30.0 if big else 22.0
	if draw:
		_r(x, y, gw, gh, gcol)
		_r(x + 1.0, y + 1.0, gw - 2.0, gh - 2.0, Color("0e121c"))
		if BIG_GRADES.has(grade):
			_big_grade(grade, x + floorf((gw - 16.0) * 0.5), y + floorf((gh - 20.0) * 0.5), gcol)
		else:
			_t(grade, x + floorf((gw - 12.0) * 0.5), y + floorf((gh - 20.0) * 0.5), gcol, 4)
	if big:
		var h := gh + 4.0
		if draw:
			_t("GRADE", x + gw + 4.0, y + 2.0, LABEL)
			if not owner_books:
				_t(str(tiles[0][0]), x + gw + 4.0, y + 12.0, LABEL)
				_t(str(tiles[0][2]), x + gw + 4.0, y + 18.0, tiles[0][3], 2)
		for k in range(0 if owner_books else 1, tiles.size()):
			var value := str(tiles[k][2])
			if draw:
				_r(x, y + h, w, 12.0, STRIPE)
				_t(str(tiles[k][0]), x + 2.0, y + h + 4.0, LABEL)
				_t(value, x + w - 2.0 - _tw(value, 2), y + h + 1.0, tiles[k][3], 2)
			h += 13.0
		return h - 1.0
	# compact: the grade box on the left, the numbers as rows beside it
	var rx := x + gw + 3.0
	var rw := w - gw - 3.0
	var rh := 0.0
	for tile in tiles:
		rh += _row(rx, y + rh, rw, [tile[1], tile[2], tile[3]], true, draw)
	return maxf(gh, rh)


# R20: the last 14 days of opened (green) and resolved (yellow) tickets from the metrics record; nothing at all when none is recorded.
# Returns the height it used (SPARK_H, or 0).
func _spark(x: float, y: float, w: float, draw: bool) -> float:
	var rows: Array = Dash.recent(Dash.SHOWN)
	var peak := 0.0
	for e in rows:
		peak = maxf(peak, maxf(float(e.opened), float(e.closed)))
	if peak <= 0.0:
		return 0.0
	if draw:
		_t("OPENED / RESOLVED", x + 2.0, y, LABEL)
		var step := floorf((w - 4.0) / float(rows.size()))
		var base := y + SPARK_H - 1.0
		_r(x + 2.0, base, step * float(rows.size()), 1.0, LINE)
		for k in rows.size():
			var oh := floorf(8.0 * float(rows[k].opened) / peak)
			var ch := floorf(8.0 * float(rows[k].closed) / peak)
			_r(x + 2.0 + float(k) * step, base - oh, 1.0, oh, Color("7fe34a"))
			_r(x + 3.0 + float(k) * step, base - ch, 1.0, ch, Color("f2e84a"))
	return SPARK_H


# R20: the same 14 days as 28 pixels of bars in the title bar (always fits, even on the fullest report); nothing when none is recorded
func _spark_mini(x: float, y: float) -> void:
	var rows: Array = Dash.recent(Dash.SHOWN)
	var peak := 0.0
	for e in rows:
		peak = maxf(peak, maxf(float(e.opened), float(e.closed)))
	if peak <= 0.0:
		return
	for k in rows.size():
		var oh := maxf(1.0, floorf(7.0 * float(rows[k].opened) / peak))
		var ch := maxf(1.0, floorf(7.0 * float(rows[k].closed) / peak))
		_r(x + float(k) * 2.0, y + 8.0 - oh, 1.0, oh, Color("7fe34a"))
		_r(x + 1.0 + float(k) * 2.0, y + 8.0 - ch, 1.0, ch, Color("f2e84a"))


func _panel_w(sc: int, size: Vector2) -> float:
	return minf(size.x / float(sc) - 8.0, 300.0)


func _button_label() -> String:
	if bool(report.final):
		return "FINISH" if bool(report.fired) or Campaign.mode == "free" else "REVIEW"
	return "NEXT DAY"


# the whole panel below the title bar; returns the panel height in virtual pixels
func _stack(sc: int, size: Vector2, draw: bool) -> float:
	_sc = sc
	var wide := size.x / float(sc) >= 200.0
	var big := size.x / float(sc) >= 140.0
	var pw := _panel_w(sc, size)
	var groups := _groups()
	var left: Array = report.get("left_groups", [])  # extra groups: under the grade box when wide, after the others when narrow
	var y := 11.0
	var inner := pw - 8.0
	var hero_w := 112.0
	if wide:
		var hh := _hero_block(4.0, y, hero_w, true, draw)
		var lx := 4.0 + hero_w + 6.0
		var lh := _list(lx, y, pw - lx - 4.0, groups, draw)
		if left.is_empty() and hh + 3.0 + SPARK_H <= lh:  # R20: the opened / resolved sparkline fills the spare room under the grade
			_spark(4.0, y + hh + 3.0, hero_w, draw)
		if not left.is_empty():
			hh += 3.0 + _list(4.0, y + hh + 3.0, hero_w, left, draw)
		if draw:
			_r(4.0 + hero_w + 2.0, y, 1.0, maxf(hh, lh), LINE)
		y += maxf(hh, lh)
	else:
		groups = groups + left
		y += _hero_block(4.0, y, inner, big, draw) + 3.0
		y += _list(4.0, y, inner, groups, draw)
		if size.y / float(sc) - y >= 62.0:  # (narrow screens: only when there is room left for the rest)
			y += 3.0 + _spark(4.0, y + 3.0, inner, draw)
	for note in report.get("notes", []):  # cozy Easy: a probation or bailout line, in a calm colour
		y += 3.0
		for line in _wrap(str(note), int(inner / 4.0)):
			if draw:
				_t(line, 4.0, y, HEAD)
			y += _row_h
	var ending := str(report.get("ending", ""))
	if ending != "":
		y += 4.0
		var col := BAD if bool(report.get("fired", false)) else WARN
		for line in _wrap(ending, int(inner / 4.0)):
			if draw:
				_t(line, 4.0, y, col)
			y += _row_h
	y += 2.0
	if draw:
		_r(4.0, y, inner, 1.0, LINE)
	y += 2.0
	var label := _button_label()
	var bw := _tw(label) + 12.0
	var hint := Controls.hint("ENTER OR CLICK")
	if _tw(hint) + bw + 12.0 > pw:
		hint = Controls.hint("ENTER")
	if draw:
		_t(hint, 4.0, y + 2.5, LABEL)
		_button = Rect2(_o + Vector2(pw - bw - 4.0, y) * float(sc), Vector2(bw, 10.0) * float(sc))
		if _button.size.y < 19.0:  # R14 (5): the hit rect is thumb-sized, the drawn button stays
			_button = _button.grow_individual(0.0, floorf((19.0 - _button.size.y) * 0.5) + 1.0, 0.0, floorf((19.0 - _button.size.y) * 0.5) + 1.0)
		var hot := _button.has_point(_mouse)
		_r(pw - bw - 4.0, y, bw, 10.0, Color("5aa0e8") if hot else Color("3a7bd5"))
		_t(label, pw - bw + 2.0, y + 2.5, WHITE)
	return y + 10.0 + 3.0


func _paint() -> void:
	if report.is_empty():
		return
	var size := get_viewport().get_visible_rect().size
	var sc := 2 if size.x < 220.0 else 1
	_row_h = 7.0
	_pad = 1.0
	var h := _stack(sc, size, false)
	if sc == 2 and h * 2.0 > size.y - 4.0:
		sc = 1
		h = _stack(sc, size, false)
	if sc == 1 and h > size.y - 2.0:  # the short wide screen: tighter rows (the 5 pixel font still has a 1 pixel gap)
		_row_h = 6.0
		_pad = 0.0
		h = _stack(sc, size, false)
	var u := float(sc)
	var pw := _panel_w(sc, size)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.86))
	_o = Vector2(floorf((size.x - pw * u) * 0.5), maxf(1.0, floorf((size.y - h * u) * 0.5)))
	_r(-1.0, -1.0, pw + 2.0, h + 2.0, LINE)
	_r(0.0, 0.0, pw, h, PANEL)
	_r(0.0, 0.0, pw, 10.0, Color("1f4e8c"))
	var title := str(
		report.get("title", "DAY %d OF %d COMPLETE" % [int(report.day), int(report.total_days)])
	)
	if int(report.get("year", 1)) >= 2:
		title += " - YEAR 2"
	if _tw(title) + 8.0 > pw:
		title = title.replace(" COMPLETE", "")
	_t(title, 4.0, 2.5, WHITE)
	if pw - _tw(title) - 8.0 >= 28.0:
		_spark_mini(pw - 30.0, 1.0)
	_stack(sc, size, true)
	var m := _mouse.floor()
	for i in 6:
		_canvas.draw_rect(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
	_canvas.draw_rect(Rect2(m.x + 1, m.y + 1, 1, 2), WHITE)


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
