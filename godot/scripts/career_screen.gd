extends Node2D
# gdlint:disable=max-line-length
# The CAREER screen: lifetime counters (pages of rows) and the medal board (earned / locked with the rule hint),
# drawn with the 3x5 font in the shared UiStyle panel. Opened by Career.open_screen() from the title menu and the
# phone Settings. Left / Right (A / D) change page, Esc / Backspace go back, F9 cycles the format; the mouse can
# click the < > buttons (or the wheel) and X. Two columns when the panel is wide (368x128, 320x180), one in portrait.

signal closed

const UiStyle := preload("res://scripts/ui_style.gd")
const PixelFont := preload("res://scripts/pixelfont.gd")
const MEDAL_H := 16.0
const ROW_H := 7.0
const HEAD_ROW_H := 9.0
# the mastery page: [label, the game id of Career "good.<game>"]
const MASTERY_ROWS := [["BOWLING", "bowling"], ["KARAOKE", "karaoke"], ["ESCAPE ROOM", "escape"], ["CORNHOLE", "cornhole"], ["COOKOUT", "grill"], ["CHAIR RACE", "chair"], ["DARTS", "darts"], ["PRINTER", "printer"]]

var page := 0
var pages: Array = []
var sel := 0  # the medal the cursor is on (an index into the page's medals)
var detail := false  # the selected medal's detail panel is open
var _built_for := Vector2.ZERO
var _btns: Array = []  # [Rect2, id]
var _hover := ""
var _born := -1


func _ready() -> void:
	_born = Engine.get_process_frames()
	Game.format_changed.connect(queue_redraw)
	queue_redraw()


func page_count() -> int:
	return pages.size()


func go(step: int) -> void:
	if pages.is_empty():
		return
	page = posmod(page + step, pages.size())
	sel = 0
	detail = false
	queue_redraw()


func _medals_here() -> Array:
	return pages[page].get("medals", []) if not pages.is_empty() else []


func close() -> void:
	closed.emit()


func _input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _born:
		return
	if Controls.pressed(event):
		var dir := Controls.nav(event)
		if event is InputEventKey and event.keycode == KEY_F9:
			Game.cycle_format()
		elif dir == "left":
			go(-1)
		elif dir == "right":
			go(1)
		elif (dir == "up" or dir == "down") and not detail and not _medals_here().is_empty():
			sel = posmod(sel + (1 if dir == "down" else -1), _medals_here().size())
			queue_redraw()
		elif Controls.confirm(event) and not _medals_here().is_empty():
			detail = not detail
			queue_redraw()
		elif Controls.back(event):
			if detail:
				detail = false
				queue_redraw()
			else:
				close()
	elif event is InputEventMouseMotion:
		var h := _hit(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
		return
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			go(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			go(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			click(event.position)
	else:
		return
	get_viewport().set_input_as_handled()


func _hit(at: Vector2) -> String:
	for b in _btns:
		if b[0].has_point(at):
			return str(b[1])
	return ""


func click(at: Vector2) -> void:
	var hit := _hit(at)
	if hit.begins_with("medal:"):
		var i := int(hit.get_slice(":", 1))
		detail = not (detail and i == sel)
		sel = i
		queue_redraw()
		return
	if detail:
		detail = false
		queue_redraw()
		return
	match hit:
		"prev":
			go(-1)
		"next":
			go(1)
		"back":
			close()


# ---- layout -----------------------------------------------------------------------------------------
func _body_rect(size: Vector2) -> Rect2:
	var r := UiStyle.panel_rect(size, 360.0, 124.0 if size.y < 150.0 else 400.0)
	return Rect2(r.position.x + 4.0, r.position.y + 12.0, r.size.x - 8.0, r.size.y - 21.0)


func columns(body_w: float) -> int:
	return 2 if body_w >= 290.0 else 1


# split the counter rows and the medals into pages that fit the body
func build(size: Vector2) -> void:
	var body := _body_rect(size)
	var cols := columns(body.size.x)
	pages = []
	var cap_c := int(body.size.y / ROW_H) * cols
	var items: Array = []
	for row in Career.COUNTERS:
		if str(row[0]) != "":
			items.append({"head": str(row[0])})
		items.append({"label": str(row[1]), "key": str(row[2]), "fmt": str(row[3])})
	var i := 0
	while i < items.size():
		var chunk: Array = items.slice(i, i + cap_c)
		# do not leave a section title alone at the bottom of a page
		if chunk.size() == cap_c and chunk.back().has("head"):
			chunk.pop_back()
		i += chunk.size()
		pages.append({"title": "CAREER - TOTALS", "items": chunk})
	pages.append({"title": "CAREER - MASTERY", "mastery": true})
	var cap_m := maxi(1, int(body.size.y / MEDAL_H)) * cols
	var n_pages := int(ceil(float(Career.MEDALS.size()) / float(cap_m)))
	for p in n_pages:
		pages.append({"title": "CAREER - MEDALS %d/%d" % [Career.earned_count(), Career.MEDALS.size()], "medals": Career.MEDALS.slice(p * cap_m, (p + 1) * cap_m)})
	page = clampi(page, 0, maxi(0, pages.size() - 1))
	_built_for = size


func _fmt(v: int, fmt: String) -> String:
	match fmt:
		"stars":
			return "-" if v <= 0 else "%d/3" % v
		"secs":
			return "-" if v <= 0 else "%d SEC" % v
		"px":
			return "-" if v <= 0 else "%d PX" % v
	return str(v)


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.8))
	if size != _built_for or pages.is_empty():
		build(size)
	_btns.clear()
	var pg: Dictionary = pages[page]
	var r := UiStyle.panel_rect(size, 360.0, 124.0 if size.y < 150.0 else 400.0)
	var body := UiStyle.panel(self, r, str(pg.title), "%d/%d" % [page + 1, pages.size()])
	var cols := columns(body.size.x)
	var gap := 6.0
	var colw := (body.size.x - gap * float(cols - 1)) / float(cols)
	if pg.has("items"):
		_draw_counters(pg.items, body, cols, colw, gap)
	elif pg.has("mastery"):
		_draw_mastery(body, cols, colw, gap)
	else:
		_draw_medals(pg.medals, body, cols, colw, gap)
		if detail and sel < pg.medals.size():
			_draw_detail(size, pg.medals[sel])
	UiStyle.footer(self, r, "ARROWS  ENTER = DETAILS  ESC BACK" if pg.has("medals") else "ARROWS PAGE  ESC BACK")
	_button("prev", "<", Rect2(r.end.x - 34.0, r.end.y - 9.0, 9.0, 8.0))
	_button("next", ">", Rect2(r.end.x - 23.0, r.end.y - 9.0, 9.0, 8.0))
	_button("back", "X", Rect2(r.end.x - 12.0, r.end.y - 9.0, 9.0, 8.0))


func _button(id: String, label: String, rc: Rect2) -> void:
	_btns.append([rc, id])
	draw_rect(rc, UiStyle.GOLD if _hover == id else UiStyle.SOFT)
	UiStyle.center(self, label, rc.position.x + rc.size.x * 0.5, rc.position.y + 2.0, UiStyle.INK)


func _draw_counters(items: Array, body: Rect2, _cols: int, colw: float, gap: float) -> void:
	var per_col := int(body.size.y / ROW_H)
	for i in items.size():
		var it: Dictionary = items[i]
		var cx := body.position.x + float(i / per_col) * (colw + gap)
		var cy := body.position.y + float(i % per_col) * ROW_H
		if it.has("head"):
			UiStyle.text(self, str(it.head), cx, cy, UiStyle.HEAD)
			draw_rect(Rect2(cx, cy + 6.0, colw, 1.0), UiStyle.SOFT)
			continue
		var v := Career.value(str(it.key))
		UiStyle.text(self, str(it.label), cx, cy, UiStyle.INK)
		UiStyle.right(self, _fmt(v, str(it.fmt)), cx + colw, cy, UiStyle.GOLD.darkened(0.35) if v > 0 else UiStyle.MUTED)


# the mastery ramp: ten good plays (2 or more stars) bring a game to full mastery, and the game gets a little tighter as it grows
func _draw_mastery(body: Rect2, cols: int, colw: float, gap: float) -> void:
	UiStyle.text(self, "2+ STARS COUNT. 10 = MASTERY.", body.position.x, body.position.y, UiStyle.HEAD)
	var per_col := maxi(1, int((body.size.y - 10.0) / 8.0))
	var ramp := int(Difficulty.RAMP_PLAYS)
	for i in MASTERY_ROWS.size():
		var x := body.position.x + float(i / per_col) * (colw + gap)
		var y := body.position.y + 10.0 + float(i % per_col) * 8.0
		var n := mini(Career.value("good." + str(MASTERY_ROWS[i][1])), ramp)
		UiStyle.text(self, str(MASTERY_ROWS[i][0]), x, y, UiStyle.INK)
		var bx := x + colw - float(ramp) * 4.0 - 24.0 if cols > 1 else x + 70.0
		for k in ramp:
			draw_rect(Rect2(bx + float(k) * 4.0, y + 1.0, 3.0, 4.0), UiStyle.GOLD if k < n else UiStyle.SOFT)
		UiStyle.right(self, "%d/%d" % [n, ramp], bx + float(ramp) * 4.0 + 22.0, y, UiStyle.MUTED if n == 0 else UiStyle.GOLD.darkened(0.35))


# the open medal: the whole name and description, how far you are, and what it unlocks
func _draw_detail(size: Vector2, m: Dictionary) -> void:
	var r := UiStyle.panel_rect(size, 250.0, 70.0 if size.y < 150.0 else 110.0)
	var body := UiStyle.panel(self, r, str(m.title), "EARNED" if Career.has_medal(str(m.id)) else "NOT YET")
	var chars := int(body.size.x / 4.0)
	var y := body.position.y
	for line in UiStyle.wrap_text(str(m.desc), chars):
		UiStyle.text(self, str(line), body.position.x, y, UiStyle.INK)
		y += 7.0
	var prog := Career.progress(m)
	if prog != "" and not Career.has_medal(str(m.id)):
		UiStyle.text(self, "PROGRESS " + prog, body.position.x, y + 2.0, UiStyle.HEAD)
		y += 9.0
	var gives: Array = []
	for u in Career.UNLOCKS:
		if str(u.medal) == str(m.id):
			gives.append(str(u.title))
	if not gives.is_empty():
		for line in UiStyle.wrap_text("UNLOCKS: " + ", ".join(gives), chars):
			UiStyle.text(self, str(line), body.position.x, y + 2.0, UiStyle.GOLD.darkened(0.35))
			y += 7.0
	UiStyle.footer(self, r, "ENTER OR ESC = CLOSE")


func _draw_medals(list: Array, body: Rect2, _cols: int, colw: float, gap: float) -> void:
	var per_col := maxi(1, int(body.size.y / MEDAL_H))
	var chars := int((colw - 9.0) / 4.0)
	for i in list.size():
		var m: Dictionary = list[i]
		var x := body.position.x + float(i / per_col) * (colw + gap)
		var y := body.position.y + float(i % per_col) * MEDAL_H
		var got := Career.has_medal(str(m.id))
		var row := Rect2(x - 1.0, y - 1.0, colw + 2.0, MEDAL_H - 1.0)
		_btns.append([row, "medal:%d" % i])
		if i == sel:
			draw_rect(row, Color(UiStyle.GOLD, 0.25))
		if got:
			UiStyle.star(self, Vector2(x + 3.5, y + 3.0), 4.0, UiStyle.GOLD)
		else:
			draw_rect(Rect2(x, y, 7.0, 7.0), UiStyle.SOFT)
			draw_rect(Rect2(x + 1.0, y + 1.0, 5.0, 5.0), UiStyle.PANEL)
			draw_rect(Rect2(x + 2.0, y + 3.0, 3.0, 3.0), UiStyle.MUTED)
		var prog := "" if got else Career.progress(m)
		var name_chars := chars - (prog.length() + 1 if prog != "" else 0)
		UiStyle.text(self, str(m.title).substr(0, name_chars), x + 9.0, y, UiStyle.INK if got else UiStyle.MUTED)
		if prog != "":
			UiStyle.right(self, prog, x + colw, y, UiStyle.MUTED)
		UiStyle.text(self, str(m.desc).substr(0, chars), x + 9.0, y + 7.0, UiStyle.HEAD if got else UiStyle.MUTED.lightened(0.25))
