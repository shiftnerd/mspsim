extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The LabRat Nerds forum screens (R27), drawn inside the NERDS app of the Computer: the board index, a board's thread list and a thread.
# MODEL: all the data and the rules live in the Nerds autoload (boards, threads, counts, last posts, stats, posting). This file only
# holds where you are (view, board, thread, selection, scroll) and draws it. Every screen is a list of ROWS (one to three text lines,
# or a single line for the text of a post) that scrolls a whole row at a time, so nothing is ever cut in half.
# LAYOUT: the app works at the wide (368x128), h (320x180) and v (180x320) formats. Below 300 px wide the board rows get a third line
# (name and counts, description, last post); wider screens put the description next to the name. Long titles are clipped with "..".
# KEYS (Computer._nerds_key maps keyboard and pad onto these names): up, down, pgup, pgdn, enter, left, right.
#   Up / Down pick a board or a thread (or scroll a thread), Enter opens (or REPLY inside a thread), Left / Esc go back one level.
# MOUSE: click a row, the wheel scrolls, the buttons at the bottom scroll, BACK goes up one level, REPLY answers an open question.

const INK := Color("20242c")
const MUTED := Color("6b7586")
const LINK := Color("1f4e8c")
const ACCENT := Color("c0561a")
const PAPER := Color("ffffff")
const BAR := Color("f0d9c4")
const HEAD_BG := Color("f6e7d8")
const POST_BG := Color("e4ebf4")
const MINE_BG := Color("dcf0df")
const LH := 7.0  # one text line

var view := "boards"  # boards | threads | thread
var board_id := ""
var thread_id := -1
var sel := 0  # the selected row (boards and threads)
var top := 0  # the first visible row
var c: Node = null

var _stack: Array = []  # [view, board_id, thread_id, sel, top] of the screens you came from
var _rows: Array = []
var _chars := 40
var _list_h := 60.0
var _to_end := false
var _fresh := true  # the index was just opened: on a short screen the notice scrolls away so the boards start at the top


func reset() -> void:
	view = "boards"
	board_id = ""
	thread_id = -1
	sel = 0
	top = 0
	_stack = []
	_rows = []
	_to_end = false
	_fresh = true


func nested() -> bool:
	return view != "boards"


# ---- moving around ----
func open_board(id: String) -> bool:
	if Nerds.board(id).is_empty():
		return false
	if Nerds.board_locked(id):
		if c != null:
			c._say(str(Nerds.TEXT.vip_guru) if Nerds.karma >= 40 else str(Nerds.TEXT.vip_locked))
		return false
	_push()
	view = "threads"
	board_id = id
	sel = 0
	top = 0
	_rows = []
	return true


func open_thread(id: int) -> bool:
	if id < 0 or id >= Nerds.THREADS.size():
		return false
	_push()
	view = "thread"
	thread_id = id
	board_id = Nerds.board_of(id)
	sel = 0
	top = 0
	_rows = []
	Nerds.open_thread(id)
	return true


func _push() -> void:
	_stack.append([view, board_id, thread_id, sel, top])


func back() -> void:
	if _stack.is_empty():
		reset()
		return
	var prev: Array = _stack.pop_back()
	view = str(prev[0])
	board_id = str(prev[1])
	thread_id = int(prev[2])
	sel = int(prev[3])
	top = int(prev[4])
	_rows = []


# the row that is selected: its action id ("" when nothing is)
func selected_action() -> String:
	_ensure_rows()
	return str(_rows[sel].act) if sel >= 0 and sel < _rows.size() else ""


func _ensure_rows() -> void:
	if _rows.is_empty() and c != null:  # the rows are laid out with the Computer's text helpers: no Computer yet (a key before the first paint) means no rows
		_build()
		_first_selectable()


func _first_selectable() -> void:
	if view == "thread":
		return
	if sel >= 0 and sel < _rows.size() and str(_rows[sel].act) != "":
		return
	for i in _rows.size():
		if str(_rows[i].act) != "":
			sel = i
			return


func _move_sel(step: int) -> void:
	var i := sel + step
	while i >= 0 and i < _rows.size():
		if str(_rows[i].act) != "":
			sel = i
			_show_sel()
			return
		i += step


# scroll so the selected row is on screen
func _show_sel() -> void:
	if sel < top:
		top = sel
	while top < sel and _height(top, sel + 1) > _list_h:
		top += 1


func _height(from: int, to: int) -> float:
	var h := 0.0
	for i in range(from, mini(to, _rows.size())):
		h += float(_rows[i].h)
	return h


# the largest `top` that still fills the list
func _max_top() -> int:
	var h := 0.0
	var i := _rows.size()
	while i > 0 and h + float(_rows[i - 1].h) <= _list_h:
		h += float(_rows[i - 1].h)
		i -= 1
	return i


func _visible_count() -> int:
	var n := 0
	var h := 0.0
	var i := top
	while i < _rows.size() and h + float(_rows[i].h) <= _list_h:
		h += float(_rows[i].h)
		n += 1
		i += 1
	return maxi(1, n)


# mouse wheel and the buttons: move the window, not the selection (the selection follows if it left the screen)
func scroll(step: int) -> void:
	_ensure_rows()
	top = clampi(top + step, 0, _max_top())
	if view != "thread":
		var last := top + _visible_count() - 1
		if sel < top or sel > last:
			sel = clampi(sel, top, last)
			_first_selectable_from(sel)


func _first_selectable_from(start: int) -> void:
	for i in range(start, _rows.size()):
		if str(_rows[i].act) != "":
			sel = i
			return
	for i in range(start, -1, -1):
		if str(_rows[i].act) != "":
			sel = i
			return


# keys: returns true when the key did something
func key(name: String) -> bool:
	_ensure_rows()
	match name:
		"up", "down":
			var step := -1 if name == "up" else 1
			if view == "thread":
				scroll(step)
			else:
				_move_sel(step)
			return true
		"pgup", "pgdn":
			var page := maxi(1, _visible_count() - 1) * (-1 if name == "pgup" else 1)
			if view == "thread":
				scroll(page)
			else:
				_move_sel(page)
				if sel >= 0 and sel < _rows.size() and str(_rows[sel].act) == "":
					_first_selectable_from(sel)
			return true
		"enter":
			if view == "thread":
				reply()
			else:
				act(PackedStringArray(["nerds"] + Array(selected_action().split(":")).slice(1)))
			return true
		"left":
			if nested():
				back()
				return true
	return false


# the actions of mouse clicks and Enter: parts = ["nerds", "board", id] and so on
func act(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		return  # Enter on a row with no action (or before there are rows)
	match parts[1]:
		"board":
			if parts.size() >= 3:  # only these two carry an id
				open_board(parts[2])
		"thread":
			if parts.size() >= 3:
				open_thread(int(parts[2]))
		"back":
			back()
		"reply":
			reply()
		"up":
			scroll(-3)
		"dn":
			scroll(3)


# REPLY on the open thread: the answer check lives in Nerds.answer_thread
func reply() -> String:
	if view != "thread":
		return ""
	var text := ""
	var k := Nerds.today_index(thread_id)
	if k >= 0:
		text = Nerds.answer_thread(k)
		_to_end = true
	elif Nerds.is_sticky(thread_id):
		text = str(Nerds.TEXT.sticky_locked)
	elif not Nerds.board_open_to_you(board_id):
		text = str(Nerds.TEXT.vendor_closed)
	else:
		text = str(Nerds.TEXT.solved)
	_rows = []
	if c != null:
		c._say(text)
	return text


# ---- the rows ----
func _row(lines: Array, act := "", bg = null, tag: Array = []) -> Dictionary:
	return {"lines": lines, "act": act, "bg": bg, "tag": tag, "h": float(lines.size()) * LH + 3.0}


# one line of running text (no padding): a line of a post
func _line(text: String, color: Color = INK) -> Dictionary:
	return {"lines": [[text, color]], "act": "", "bg": null, "tag": [], "h": LH, "flat": true}


func _wrapped(text: String, color: Color, chars: int) -> Array:
	var out := []
	for part in c._wrap(text, chars):
		out.append([str(part), color])
	return out


func _build() -> void:
	_rows = []
	match view:
		"threads":
			_build_threads()
		"thread":
			_build_thread()
		_:
			_build_boards()


func _build_boards() -> void:
	var wide := _chars >= 60
	_rows.append(_row(_wrapped(str(Nerds.TEXT.disclaimer), MUTED, _chars), ""))
	for b in Nerds.BOARDS:
		var id := str(b.id)
		var pad := "  " if str(b.parent) != "" else ""
		var counts := Nerds.board_counts(id)
		var count_text := (
			"LOCKED"
			if Nerds.board_locked(id)
			else "%s/%s" % [Nerds.commas(int(counts[0])), Nerds.commas(int(counts[1]))]
		)
		var count_color: Color = c.RED if Nerds.board_locked(id) else LINK
		var name_text: String = pad + str(b.label)
		var new_tag := " NEW!" if bool(b.get("is_new", false)) else ""
		var last_line := Nerds.last_post_line(id)
		var lines := []
		var room := _chars - count_text.length() - 2
		if wide:
			var head := name_text + new_tag + " - " + str(b.desc)
			lines.append([c._clip(head, room), LINK])
			lines.append([c._clip(pad + last_line, _chars), MUTED])
		else:
			lines.append([c._clip(name_text + new_tag, room), LINK])
			lines.append([c._clip(pad + str(b.desc), _chars), INK])
			lines.append([c._clip(pad + last_line, _chars), MUTED])
		var r := _row(lines, "nerds:board:" + id)
		r.tag = [count_text, count_color]
		_rows.append(r)
	var s := Nerds.stats()
	var foot := []
	foot.append(["FORUM STATISTICS", ACCENT])
	var totals := (
		"TOTAL POSTS %s  TOPICS %s  MEMBERS %s"
		% [Nerds.commas(int(s.posts)), Nerds.commas(int(s.topics)), Nerds.commas(int(s.members))]
	)
	for part in c._wrap(totals, _chars):
		foot.append([str(part), INK])
	foot.append(["OUR NEWEST MEMBER: " + str(s.newest), LINK])
	foot.append([Nerds.last_visit_line(), MUTED])
	foot.append([Nerds.clock_line(), MUTED])
	_rows.append(_row(foot, "", HEAD_BG))


func _board_notes(id: String) -> Array:
	var notes := []
	if id == "scripts" or id == "tools":
		var lv := Skills.level("powershell")
		if Skills.can_script():
			notes.append([str(Nerds.TEXT.ps_note_on) % lv, c.GREEN])
		else:
			notes.append([str(Nerds.TEXT.ps_note) % lv, MUTED])
	elif id == "dash":
		notes.append([str(Nerds.TEXT.dash_note), MUTED])
	elif id == "vendor":
		notes.append([str(Nerds.TEXT.vendor_closed), MUTED])
		if Expo.spam > 0:
			notes.append([str(Nerds.TEXT.vendor_note) % Expo.spam, c.ORANGE])
	return notes


func _build_threads() -> void:
	var b := Nerds.board(board_id)
	if _list_h >= 80.0:  # the crumb bar already names the board on a short screen
		_rows.append(
			_row([[str(b.label), ACCENT]] + _wrapped(str(b.desc), MUTED, _chars), "", HEAD_BG)
		)
	var notes := _board_notes(board_id)
	var any_open := false
	var ids := Nerds.board_threads(board_id)
	for i in ids:
		if Nerds.today_index(i) >= 0:
			any_open = true
	if any_open:
		notes.append([str(Nerds.TEXT.open_note), c.ORANGE])
	for n in notes:
		_rows.append(_row(_wrapped(str(n[0]), n[1], _chars), ""))
	if ids.is_empty():
		_rows.append(_row([["NO TOPICS YET.", MUTED]], ""))
	for i in ids:
		var tag: Array = []
		var title_color := INK
		var k := Nerds.today_index(i)
		if Nerds.is_sticky(i):
			tag = ["STICKY", LINK]
		elif k >= 0:
			var th: Dictionary = Nerds.threads[k]
			if bool(th.answered):
				tag = ["ANSWERED", c.GREEN]
			else:
				tag = ["OPEN", c.ORANGE]
				title_color = INK if not bool(th.read) else MUTED
		var last: Dictionary = Nerds.last_of(i)
		var n := Nerds.reply_count(i)
		var title := str(Nerds.THREADS[i].title)
		var room := _chars - (str(tag[0]).length() + 1 if not tag.is_empty() else 0)
		var by := str(Nerds.thread_posts(i)[0].by)
		var when := (
			Nerds.when_text(int(last.day), int(last.minute))
			if _chars >= 60
			else Nerds.day_text(int(last.day))
		)
		var replies := "%d %s" % [n, "REPLY" if n == 1 else "REPLIES"]
		var meta := "BY %s  %s  LAST: %s" % [by, replies, when]
		var r := _row(
			[[c._clip(title, room), title_color], [c._clip(meta, _chars), MUTED]],
			"nerds:thread:%d" % i
		)
		r.tag = tag
		_rows.append(r)
	var counts := Nerds.board_counts(board_id)
	var pages := maxi(1, ceili(float(counts[0]) / float(Nerds.PAGE)))
	_rows.append(
		_row(
			[
				[
					c._clip(
						(
							"PAGE 1 OF %d: THE NEWEST %d OF %s TOPICS"
							% [pages, ids.size(), Nerds.commas(int(counts[0]))]
						),
						_chars
					),
					MUTED
				]
			],
			""
		)
	)


func _build_thread() -> void:
	var i := thread_id
	var def: Dictionary = Nerds.THREADS[i]
	var b := Nerds.board(board_id)
	var head := _wrapped(str(def.title), ACCENT, _chars)
	head.append(
		[
			c._clip(
				(
					"%s   %d %s"
					% [
						str(b.label),
						Nerds.reply_count(i),
						"REPLY" if Nerds.reply_count(i) == 1 else "REPLIES"
					]
				),
				_chars
			),
			MUTED
		]
	)
	_rows.append(_row(head, "", HEAD_BG))
	var k := Nerds.today_index(i)
	if k >= 0 and not bool(Nerds.threads[k].answered):
		var need := Nerds.need_text(i)
		if need == "":
			_rows.append(
				_row(
					[
						[
							c._clip(
								"OPEN QUESTION: YOU KNOW THIS ONE. REPLY FOR XP AND KARMA.", _chars
							),
							c.GREEN
						]
					],
					""
				)
			)
		else:
			_rows.append(
				_row(_wrapped("OPEN QUESTION. TO ANSWER YOU NEED " + need + ".", c.RED, _chars), "")
			)
	for p in Nerds.thread_posts(i):
		var mine_post := bool(p.mine)
		var nick := str(p.by)
		var rank_text := " (%s)" % Nerds.poster_rank(nick)
		var when := Nerds.when_text(int(p.day), int(p.minute))
		var header := {
			"lines": [[nick + rank_text, Nerds.poster_color(nick)]],
			"act": "",
			"bg": MINE_BG if mine_post else POST_BG,
			"tag": [when, MUTED],
			"h": LH + 3.0
		}
		_rows.append(header)
		for part in c._wrap(str(p.text), _chars - 1):
			_rows.append(_line(" " + str(part)))
		if mine_post and Nerds.signature() != "":
			_rows.append(_line(" " + Nerds.signature(), MUTED))
		_rows.append({"lines": [], "act": "", "bg": null, "tag": [], "h": 3.0})
	var foot := ""
	if Nerds.is_sticky(i):
		foot = str(Nerds.TEXT.sticky_locked)
	elif not Nerds.board_open_to_you(board_id):
		foot = str(Nerds.TEXT.vendor_closed)
	elif k < 0:
		foot = str(Nerds.TEXT.solved)
	elif not bool(Nerds.threads[k].answered):
		foot = "PRESS {ENTER OR CLICK REPLY|(A)} TO ANSWER."
	if foot != "":
		for part in c._wrap(foot, _chars):
			_rows.append(_line(str(part), MUTED))


# ---- drawing ----
func paint(computer: Node, body: Rect2) -> void:
	c = computer
	c._fill(body, PAPER)
	var narrow := body.size.x < 300.0
	# the crumb bar on top
	var bar := Rect2(body.position, Vector2(body.size.x, 9))
	c._fill(bar, BAR)
	var crumb := _crumb()
	var back_w := 26.0 if nested() else 0.0
	var legend := "TOPICS/POSTS" if view == "boards" else ""
	var legend_w: float = c._tw(legend) + 6.0 if legend != "" else 0.0
	c._text(
		c._clip(crumb, int((body.size.x - back_w - legend_w - 8.0) / 4.0)),
		body.position + Vector2(3, 2),
		INK
	)
	if legend != "":
		c._text(legend, Vector2(bar.end.x - legend_w + 1.0, bar.position.y + 2.0), MUTED)
	if nested():
		c._button(
			"nerds:back", Rect2(bar.end.x - back_w - 1, bar.position.y + 1, back_w, 8), "BACK"
		)
	# the bottom bar: a hint and the scroll buttons
	var foot := Rect2(body.position.x, body.end.y - 10, body.size.x, 10)
	c._fill(foot, BAR)
	var list := Rect2(body.position.x, body.position.y + 9, body.size.x - 4.0, body.size.y - 19.0)
	_chars = int((list.size.x - 8.0) / 4.0)
	_list_h = list.size.y
	_build()
	_first_selectable()
	sel = clampi(sel, 0, maxi(0, _rows.size() - 1))
	if _to_end:
		top = _max_top()
		_to_end = false
	if _fresh and view == "boards":
		top = 1 if _list_h < 80.0 else 0
		_fresh = false
	top = clampi(top, 0, _max_top())
	if view != "thread":
		_show_sel()
	var y := list.position.y
	var i := top
	while i < _rows.size() and y + float(_rows[i].h) <= list.end.y + 0.01:
		_paint_row(_rows[i], Rect2(list.position.x, y, list.size.x, float(_rows[i].h)), i)
		y += float(_rows[i].h)
		i += 1
	_scrollbar(Rect2(list.end.x, list.position.y, 3, list.size.y))
	# buttons
	var bx := foot.end.x - 2.0
	if view == "thread":
		var k := Nerds.today_index(thread_id)
		var can_reply := (
			k >= 0 and not bool(Nerds.threads[k].answered) and Nerds.board_open_to_you(board_id)
		)
		var label := (
			"REPLY" if can_reply else ("DONE" if k >= 0 or Nerds.mine.has(thread_id) else "LOCKED")
		)
		bx -= 32.0
		c._button(
			"nerds:reply",
			Rect2(bx, foot.position.y + 1, 32, 8),
			label,
			can_reply,
			c.BTN_HI if can_reply else c.BTN
		)
		bx -= 2.0
	bx -= 14.0
	c._button("nerds:dn", Rect2(bx, foot.position.y + 1, 14, 8), "DN")
	bx -= 16.0
	c._button("nerds:up", Rect2(bx, foot.position.y + 1, 14, 8), "UP")
	var hint_chars := int((bx - foot.position.x - 6.0) / 4.0)
	c._text(c._clip(Controls.hint(_hint(narrow)), hint_chars), foot.position + Vector2(3, 3), MUTED)


func _crumb() -> String:
	match view:
		"threads":
			return "INDEX > " + str(Nerds.board(board_id).label)
		"thread":
			return str(Nerds.board(board_id).label) + " > " + str(Nerds.THREADS[thread_id].title)
	return str(Nerds.TEXT.title)


func _hint(narrow: bool) -> String:
	match view:
		"threads":
			return "UP/DOWN PICK  ENTER OPEN  ESC BACK" if not narrow else "ENTER OPEN  ESC BACK"
		"thread":
			return (
				"UP/DOWN SCROLL  ENTER REPLY  ESC BACK" if not narrow else "ENTER REPLY  ESC BACK"
			)
	return Nerds.clock_line() if not narrow else "ENTER OPEN  RIGHT: IRC"


func _paint_row(row: Dictionary, r: Rect2, index: int) -> void:
	var act := str(row.act)
	var is_flat := bool(row.get("flat", false))
	if act != "":
		c._row(r, index == sel, index % 2 == 1)
		c._region(act, r)
	elif row.bg != null:
		c._fill(r, row.bg)
	var lines: Array = row.lines
	var oy := 1.0 if not is_flat else 0.0
	for k in lines.size():
		c._text(str(lines[k][0]), r.position + Vector2(3, oy + float(k) * LH), lines[k][1])
	var tag: Array = row.tag
	if not tag.is_empty():
		var tx: float = r.end.x - c._tw(str(tag[0])) - 3.0
		c._text(str(tag[0]), Vector2(tx, r.position.y + oy), tag[1])


func _scrollbar(r: Rect2) -> void:
	var total := _height(0, _rows.size())
	if total <= _list_h + 0.01:
		return
	c._fill(r, Color("e3d2c0"))
	var share := _list_h / total
	var thumb_h := maxf(6.0, r.size.y * share)
	var at := _height(0, top) / total
	c._fill(
		Rect2(
			r.position.x,
			r.position.y + (r.size.y - thumb_h) * clampf(at / maxf(0.01, 1.0 - share), 0.0, 1.0),
			r.size.x,
			thumb_h
		),
		ACCENT
	)
