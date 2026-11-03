extends CanvasLayer
# The end-of-day report for the campaigns: a dimmed screen with a small panel (tickets closed,
# SLA missed, pay, reputation, a grade letter) and a button. Enter / Space / click continues.
# Drawn in code with the pixel font.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")
const GRADE_COLORS := {
	"S": Color("f5d442"),
	"A": Color("5fd068"),
	"B": Color("5aa0e8"),
	"C": Color("e0a030"),
	"D": Color("e0463c"),
}

var is_open := false
var report := {}

var _canvas: Node2D
var _mouse := Vector2.ZERO
var _button := Rect2()
var _fade := 0.0
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
		if _button.has_point(_mouse) and Time.get_ticks_msec() - _opened >= 600:
			finish()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (
			event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			and Time.get_ticks_msec() - _opened >= 600
		):
			finish()
	else:
		return
	get_viewport().set_input_as_handled()


func _rows() -> Array:
	if report.has("rows"):
		return report.rows
	var r := report
	var signed := "%+d" % int(r.rep_delta)
	return [
		["TICKETS CLOSED", str(r.closed), WHITE],
		["SLA MISSED", str(r.missed), Color("ff8a80") if int(r.missed) > 0 else WHITE],
		["REOPENED", str(r.reopened), Color("ff8a80") if int(r.reopened) > 0 else WHITE],
		["STILL OPEN", str(r.open_left), WHITE],
		["CLIENT MOOD", "%d%%" % int(r.clients), WHITE],
		["DAY SCORE", str(r.points), WHITE],
		(
			["OVERTIME", "%.1fH" % float(r.overtime), Color("8fe3a0")]
			if float(r.overtime) > 0.0
			else ["", "", WHITE]
		),
		[
			"COWORKERS",
			"%+d" % int(r.social),
			(
				Color("8fe3a0")
				if int(r.social) > 0
				else (Color("ff8a80") if int(r.social) < 0 else WHITE)
			)
		],
		(
			[
				"ENERGY",
				_energy_text(),
				Color("ff8a80") if int(r.get("energy", 100)) < 35 else Color("8fe3a0")
			]
			if int(r.get("energy", -1)) >= 0
			else ["", "", WHITE]
		),
		["PAYCHECK", "$%d" % int(r.pay), Color("8fe3a0")],
		["REPUTATION", "%d (%s)" % [int(r.rep), signed], WHITE],
		["CASH", "$%d" % int(r.cash), Color("8fe3a0")],
	]


func _energy_text() -> String:
	var s := "%d%%" % int(report.get("energy", 0))
	if int(report.get("late", 0)) >= 10:
		s += " LATE %dM" % int(report.late)
	if int(report.get("oncall", 0)) > 0:
		s += " ON CALL"
	return s


func _text(s: String, p: Vector2, c: Color, scale: int) -> void:
	PixelFont.draw(_canvas, s, p, c, scale)


func _paint() -> void:
	if report.is_empty():
		return
	var size := get_viewport().get_visible_rect().size
	var sc := 2 if size.x < 220.0 else 1
	var u := float(sc)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.82))
	var rows := _rows().filter(func(row: Array) -> bool: return str(row[0]) != "")
	var ending: String = str(report.ending)
	var pw := minf(size.x - 8.0, 150.0 * u)
	var rh := 8.0 if rows.size() <= 11 else 7.0
	var ph := (14.0 + float(rows.size()) * rh + (16.0 if ending != "" else 4.0) + 18.0) * u
	var panel := Rect2(floorf((size.x - pw) * 0.5), floorf((size.y - ph) * 0.5), pw, ph)
	_canvas.draw_rect(panel, Color("e9ecf1"))
	_canvas.draw_rect(Rect2(panel.position, Vector2(pw, 9.0 * u)), Color("1f4e8c"))
	var title := str(
		report.get("title", "DAY %d OF %d COMPLETE" % [int(report.day), int(report.total_days)])
	)
	_text(title, panel.position + Vector2(3.0 * u, 2.0 * u), WHITE, sc)
	var y := panel.position.y + 12.0 * u
	for row in rows:
		_text(row[0], Vector2(panel.position.x + 4.0 * u, y), Color("46506a"), sc)
		var value: String = row[1]
		var vw := float(PixelFont.width(value, sc))
		# values are drawn on a dark chip so the light colours stay readable
		_canvas.draw_rect(
			Rect2(panel.end.x - vw - 7.0 * u, y - u, vw + 6.0 * u, 7.0 * u), Color("2a2f3a")
		)
		_text(value, Vector2(panel.end.x - vw - 4.0 * u, y), row[2], sc)
		y += rh * u
	var grade: String = str(report.grade)
	var gcol: Color = GRADE_COLORS.get(grade, WHITE)
	var gbox := Rect2(panel.position.x + 4.0 * u, panel.end.y - 15.0 * u, 12.0 * u, 12.0 * u)
	_canvas.draw_rect(gbox, Color("2a2f3a"))
	_text(grade, gbox.position + Vector2(u, 1.0 * u), gcol, sc * 2)
	_text("GRADE", gbox.position + Vector2(14.0 * u, 3.0 * u), Color("46506a"), sc)
	if ending != "":
		var lines := _wrap(ending, int((pw - 8.0 * u) / (4.0 * u)))
		for line in lines:
			_text(
				line,
				Vector2(panel.position.x + 4.0 * u, y + 1.0 * u),
				Color("b3262c") if report.fired else Color("1f4e8c"),
				sc
			)
			y += 7.0 * u
	var label := "NEXT DAY"
	if bool(report.final):
		label = "FINISH" if bool(report.fired) or Campaign.mode == "free" else "REVIEW"
	var bw := float(PixelFont.width(label, sc)) + 12.0 * u
	_button = Rect2(panel.end.x - bw - 4.0 * u, panel.end.y - 13.0 * u, bw, 9.0 * u)
	var hot := _button.has_point(_mouse)
	_canvas.draw_rect(_button, Color("5aa0e8") if hot else Color("3a7bd5"))
	_text(label, _button.position + Vector2(6.0 * u, 2.0 * u), WHITE, sc)
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
