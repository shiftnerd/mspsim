extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,max-returns
# ConnectWhy Dispatch (service manager campaign, C5): the dispatcher's board, drawn by Computer like the PSA and RMM.
# Three tabs: BOARD (a lane for every tech plus DAN (you), an ESCALATION lane for Alan and Garrison and an UNASSIGNED
# column; ticket chips with a priority stripe, skill tag and SLA bar), CAPACITY (each tech's queued hours against the hours
# left today, utilisation, morale pips, stuck / overload warnings, a focus per person) and SCORE (today so far and a
# line of the daily scores with the weekly averages). Keyboard: Tab / Shift+Tab walk the chips, Left / Right pick the lane,
# Up / Down pick the chip, Enter picks a chip up and (in another lane) puts it down, Esc cancels. Mouse: drag a chip to a
# lane. A / T / E / U are shortcuts (auto policy, take it, escalate, unassign), C / B / S change the tab, F cycles a focus.
# The tab 'fuzz' hides precision when your DISPATCH stat is low (SLA to the minute, fit as a word, utilisation in quarters).
# Narrow formats (180 wide) show one lane at a time and Left / Right switch lanes. All logic is in public functions so the
# tests can drive the board without a renderer; paint(c, body) only draws.

const BG := Color("eef1f6")
const HEAD := Color("1f4e8c")
const LANE_A := Color("e3e8f1")
const LANE_B := Color("eaeef5")
const DROP := Color("fff0c2")
const INK := Color("20242c")
const MUTED := Color("5a6372")
const CHIP_H := 14.0
const SHORT := {"": "OPEN", "Dan": "DAN", "ESC": "OWN"}

var view := "board"  # board, capacity, score
var lane := 0  # index into Service.lane_ids()
var row := 0  # chip row in that lane
var held := -1  # the ticket you carry (Enter picked it up)
var held_from := ""
var cap_sel := 0
var fuzz := -1  # -1 = from the DISPATCH stat, 0 = exact, 1 = fuzzy
var msg := ""
var msg_at := -99999

var c: Node = null
var _chips: Array = []
var _lanes: Array = []
var _drag := {}


# ---- the data the board shows ---------------------------------------------------------------------------------------
func ids() -> Array:
	return Service.lane_ids()


func lane_id() -> String:
	var l := ids()
	return str(l[clampi(lane, 0, l.size() - 1)])


func tickets_in(id: String) -> Array:
	var out := []
	for t in Msp.open_tickets():
		if not Service._crew_ticket(t):
			continue
		var a := Crew.assignee_of(t)
		if id == "ESC":
			if a in Service.OWNERS:
				out.append(t)
		elif a == id:
			out.append(t)
	return out


func selected_id() -> int:
	var list := tickets_in(lane_id())
	if list.is_empty():
		return -1
	return int(list[clampi(row, 0, list.size() - 1)].id)


func fuzzy() -> bool:
	if fuzz >= 0:
		return fuzz == 1
	return Build.level("dispatch") < 3


func lane_title(id: String, chars: int) -> String:
	match id:
		"":
			return "UNASSIGNED" if chars >= 10 else "OPEN"
		"Dan":
			return "DAN (YOU)" if chars >= 9 else "DAN"
		"ESC":
			if Service.design == "tiered":
				return "L3 OWNERS" if chars >= 9 else "L3 OWN"
			return "OWNERS" if chars >= 6 else "OWN"
	if Service.design == "tiered" and Crew.has(id):  # L1 SAM, L2 MAYA (C6 desk design); a narrow head keeps "1 SAM"
		if chars >= 9:
			return "%s %s" % [Service.lane_tag(id), id.to_upper()]
		return "%s %s" % [Service.lane_tag(id).substr(1), id.to_upper().substr(0, maxi(3, chars - 2))]
	return id.to_upper()


func sla_text(t: Dictionary) -> String:
	if bool(t.breached) or float(t.sla_left) <= 0.0:
		return "LATE"
	if fuzzy():
		return "*%dM" % int(ceil(float(t.sla_left) / 60.0))
	return Msp.mmss(float(t.sla_left))


func sla_frac(t: Dictionary) -> float:
	var f := clampf(float(t.sla_left) / maxf(1.0, float(t.sla_total)), 0.0, 1.0)
	if fuzzy():
		f = ceil(f * 4.0) / 4.0
	return f


# "FIT 80%" for a tech, or just a word when your DISPATCH level is low
func fit_text(who: String, t: Dictionary) -> String:
	if not Crew.has(who):
		return ""
	var f := Crew.fit(who, t)
	if fuzzy():
		return "FIT " + ("GOOD" if f >= 0.7 else ("OK" if f >= 0.4 else "POOR"))
	return "FIT %d%%" % int(round(f * 100.0))


func warn_text(who: String, t: Dictionary) -> String:
	if not Crew.has(who):
		return ""
	if Crew.gap_of(who, t) >= 1:
		return "ABOVE HIS LEVEL" if fuzzy() else "NEEDS %s%d HE HAS %d" % [Crew.tag_of(t), Crew.need_of(t), Crew.level(who, Crew.area_of(t))]
	if Crew.load_of(who) - (1 if Crew.assignee_of(t) == who else 0) >= Crew.OVERLOAD_AT - 1:
		return "HE IS BUSY"
	return ""


func info_line() -> String:
	if Time.get_ticks_msec() - msg_at < 3000 and msg != "":
		return msg
	var lid := lane_id()
	if held >= 0:
		var t := Msp.ticket(held)
		if t.is_empty():
			return ""
		var s := "CARRY %d TO %s" % [held, Service.lane_name(lid)]
		var f := fit_text(lid, t)
		var w := warn_text(lid, t)
		return "%s %s %s ENTER=DROP ESC=CANCEL" % [s, f, w]
	var id := selected_id()
	if id < 0:
		return "TAB=NEXT  ENTER=PICK UP  A=AUTO  C=CAPACITY"
	var t2 := Msp.ticket(id)
	var cl := "PITP" if int(t2.client) < 0 else str(Msp.CLIENTS[int(t2.client)].short)
	var extra := ""
	if Crew.has(lid):
		extra = fit_text(lid, t2) + " " + warn_text(lid, t2)
	return "%d P%d %s %s NEEDS %s%d %s" % [id, int(t2.pri), cl, str(t2.summary), Crew.tag_of(t2), Crew.need_of(t2), extra]


func say(text: String) -> void:
	msg = text
	msg_at = Time.get_ticks_msec()


# ---- picking up, moving and dropping ---------------------------------------------------------------------------------
func clamp_cursor() -> void:
	var n := ids().size()
	lane = clampi(lane, 0, n - 1)
	var list := tickets_in(lane_id())
	row = clampi(row, 0, maxi(0, list.size() - 1))


func move_lane(step: int) -> void:
	lane = clampi(lane + step, 0, ids().size() - 1)
	clamp_cursor()


func move_row(step: int) -> void:
	row += step
	clamp_cursor()


# all chips in lane order: [[lane, row], ...]
func _flat() -> Array:
	var out := []
	var l := ids()
	for i in l.size():
		var n := tickets_in(str(l[i])).size()
		for r in n:
			out.append([i, r])
	return out


func next_chip(step: int) -> void:
	if held >= 0:
		move_lane(step)  # Tab while carrying walks the drop target
		return
	var flat := _flat()
	if flat.is_empty():
		return
	var at := -1
	for i in flat.size():
		if flat[i][0] == lane and flat[i][1] == row:
			at = i
			break
	at = (at + step + flat.size()) % flat.size() if at >= 0 else (0 if step > 0 else flat.size() - 1)
	lane = int(flat[at][0])
	row = int(flat[at][1])


func pick() -> bool:
	var id := selected_id()
	if id < 0:
		return false
	held = id
	held_from = lane_id()
	return true


func cancel() -> void:
	if held < 0:
		return
	var l := ids()
	lane = maxi(0, l.find(held_from))
	held = -1
	clamp_cursor()


func drop() -> Dictionary:
	if held < 0:
		return {"ok": false, "msg": ""}
	var res := Service.assign(held, lane_id(), true)
	say(str(res.msg))
	if bool(res.ok):
		_follow(held)
		held = -1
	return res


# after a move, put the cursor on the chip wherever it went
func _follow(id: int) -> void:
	var l := ids()
	for i in l.size():
		var list := tickets_in(str(l[i]))
		for r in list.size():
			if int(list[r].id) == id:
				lane = i
				row = r
				return


# send the chip under the cursor straight to a lane (the shortcuts)
func send_selected(to: String) -> Dictionary:
	var id := selected_id()
	if id < 0:
		return {"ok": false, "msg": ""}
	var res := Service.assign(id, to, true)
	say(str(res.msg))
	_follow(id)
	return res


func tech_names() -> Array:
	return Crew.names()


# a key by name ("tab", "shift_tab", "left", "right", "up", "down", "enter", "a", "t", "e", "u", "c", "b", "s", "f"); true = used
func key(name: String) -> bool:
	match name:
		"tab":
			if view == "board":
				next_chip(1)
			else:
				_cap_move(1)
		"shift_tab":
			if view == "board":
				next_chip(-1)
			else:
				_cap_move(-1)
		"left":
			if view == "board":
				move_lane(-1)
		"right":
			if view == "board":
				move_lane(1)
		"up":
			if view == "board":
				if held < 0:
					move_row(-1)
			else:
				_cap_move(-1)
		"down":
			if view == "board":
				if held < 0:
					move_row(1)
			else:
				_cap_move(1)
		"enter":
			if view == "board":
				if held >= 0:
					drop()
				else:
					pick()
			elif view == "capacity":
				_cycle_focus()
		"a":
			say("AUTO: " + Service.cycle_auto().to_upper())
		"t":
			if view == "board" and held < 0:
				send_selected("Dan")
		"e":
			if view == "board" and held < 0:
				send_selected("ESC")
		"u":
			if view == "board" and held < 0:
				send_selected("")
		"c":
			view = "capacity"
		"b":
			view = "board"
		"s":
			view = "score"
		"f":
			if view == "capacity":
				_cycle_focus()
		_:
			return false
	return true


func back() -> bool:
	if held >= 0:
		cancel()
		return true
	if view != "board":
		view = "board"
		return true
	return false


func nested() -> bool:
	return held >= 0 or view != "board" or not _drag.is_empty()


func _cap_move(step: int) -> void:
	var n := Crew.names().size()
	if n > 0:
		cap_sel = clampi(cap_sel + step, 0, n - 1)


func _cycle_focus() -> void:
	var names := Crew.names()
	if names.is_empty():
		return
	var who := str(names[clampi(cap_sel, 0, names.size() - 1)])
	var area := Crew.cycle_focus(who)
	say("%s FOCUS: %s" % [who.to_upper(), "NONE" if area == "" else area.to_upper()])


# ---- the mouse ---------------------------------------------------------------------------------------------------------
func lane_at(p: Vector2) -> int:
	for l in _lanes:
		if l.r.has_point(p):
			return int(l.i)
	return -1


# true = the board used the press (a chip or a lane); false = let Computer treat it as a normal click
func mouse_down(p: Vector2) -> bool:
	if view != "board":
		return false
	for k in range(_chips.size() - 1, -1, -1):
		var ch: Dictionary = _chips[k]
		if ch.r.has_point(p):
			if held >= 0:
				lane = int(ch.lane)
				clamp_cursor()
				drop()
				return true
			lane = int(ch.lane)
			row = int(ch.row)
			_drag = {"id": int(ch.id), "from": str(ids()[lane]), "start": p, "pos": p, "moved": false}
			return true
	if held >= 0:
		var i := lane_at(p)
		if i >= 0:
			lane = i
			clamp_cursor()
			drop()
			return true
	return false


func mouse_move(p: Vector2) -> void:
	if _drag.is_empty():
		return
	_drag["pos"] = p
	if p.distance_to(_drag.start) > 3.0:
		_drag["moved"] = true
		var i := lane_at(p)
		if i >= 0:
			lane = i


func mouse_up(p: Vector2) -> bool:
	if _drag.is_empty():
		return false
	var d := _drag
	_drag = {}
	if bool(d.moved):
		var i := lane_at(p)
		if i >= 0:
			var res := Service.assign(int(d.id), str(ids()[i]), true)
			say(str(res.msg))
			_follow(int(d.id))
		else:
			_follow(int(d.id))
	return true


# clicks on the buttons (ids "dsp:...") come from Computer.activate
func act(parts: PackedStringArray) -> void:
	match parts[1]:
		"view":
			view = parts[2]
		"auto":
			say("AUTO: " + Service.cycle_auto().to_upper())
		"lane":
			lane = int(parts[2])
			clamp_cursor()
			if held >= 0:
				pass
		"prev":
			move_lane(-1)
		"next":
			move_lane(1)
		"cap":
			cap_sel = int(parts[2])
		"focus":
			_cycle_focus()


# ---- drawing -------------------------------------------------------------------------------------------------------------
func paint(computer: Node, body: Rect2) -> void:
	c = computer
	_chips.clear()
	_lanes.clear()
	clamp_cursor()
	c._fill(body, BG)
	var narrow := body.size.x < 280.0
	# tab bar
	var bar := Rect2(body.position, Vector2(body.size.x, 9))
	c._fill(bar, Color("cfd9e8"))
	var tabs := [["board", "BOARD"], ["capacity", "CAPACITY" if not narrow else "CAP"], ["score", "SCORE"]]
	var tw := 38.0 if not narrow else 28.0
	for i in tabs.size():
		var w := tw + (8.0 if tabs[i][0] == "capacity" and not narrow else 0.0)
		var x := body.position.x + 2.0 + float(i) * (tw + 2.0) + (8.0 if i == 2 and not narrow else 0.0)
		c._button("dsp:view:" + str(tabs[i][0]), Rect2(x, body.position.y + 1, w, 8), str(tabs[i][1]), true, c.BTN_HI if view == tabs[i][0] else c.BTN)
	var auto_label := "AUTO " + str(Service.auto).to_upper()
	var aw: float = c._tw(auto_label) + 8.0
	c._button("dsp:auto", Rect2(body.end.x - aw - 2.0, body.position.y + 1, aw, 8), auto_label, true, Color("f2e2a0") if Service.auto != "all" else c.BTN)
	var area := Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
	match view:
		"capacity":
			_capacity(area, narrow)
		"score":
			_score(area, narrow)
		_:
			if narrow:
				_board_narrow(area)
			else:
				_board_wide(area)
	if not _drag.is_empty() and bool(_drag.moved):
		var t := Msp.ticket(int(_drag.id))
		if not t.is_empty():
			var r := Rect2(Vector2(_drag.pos) - Vector2(26, 6), Vector2(52, CHIP_H))
			_chip(t, r, true, false, true)


func _lane_color(id: String) -> Color:
	match id:
		"":
			return Color("7d8aa0")
		"Dan":
			return Color("2f8a4f")
		"ESC":
			return Color("c8681a")
	if Crew.has(id):  # the desk design tints the lane heads (C6)
		match Service.design:
			"tiered":
				return Color("173a6b") if Service.lane_of(id) == "L2" else HEAD
			"pods":
				return Color("1f6e68")
			"swarm":
				return Color("5a3d8a")
	return HEAD


func _footer(a: Rect2, lines: int) -> void:
	var h := 7.0 * float(lines) + 1.0
	var r := Rect2(a.position.x, a.end.y - h, a.size.x, h)
	c._fill(r, Color("cfd9e8"))
	var chars := int((a.size.x - 4.0) / 4.0)
	var text := info_line()
	if lines == 1:
		c._text(c._clip(text, chars), r.position + Vector2(2, 1), INK)
	else:
		var wrapped: Array = c._wrap(text, chars)
		for i in mini(lines, wrapped.size()):
			c._text(str(wrapped[i]), r.position + Vector2(2, 1 + i * 7), INK)


func _board_wide(a: Rect2) -> void:
	var l := ids()
	var n := l.size()
	var lane_w := floorf(a.size.x / float(n))
	var body_h := a.size.y - 8.0
	var chars := int((lane_w - 4.0) / 4.0)
	for i in n:
		var id := str(l[i])
		var x := a.position.x + float(i) * lane_w
		var lr := Rect2(x, a.position.y, lane_w, body_h)
		_lanes.append({"r": lr, "i": i})
		var carrying := (held >= 0 or (not _drag.is_empty() and bool(_drag.moved))) and i == lane
		c._fill(lr, DROP if carrying else (LANE_A if i % 2 == 0 else LANE_B))
		var head := Rect2(x, a.position.y, lane_w, 7)
		c._fill(head, _lane_color(id))
		if i == lane:
			c._fill(Rect2(x, a.position.y + 6, lane_w, 1), Color("ffffff"))
		var list := tickets_in(id)
		var label := lane_title(id, chars - 3)
		c._text(c._clip(label, chars - 3), head.position + Vector2(2, 1), c.WHITE)
		var mark := ""
		if Crew.has(id):
			mark = Crew.glyph_of(id)
		if mark != "":
			c._text(mark, Vector2(head.end.x - 5, head.position.y + 1), c.RED if mark == "?" else Color("ffd27a"))
		elif list.size() > 0:
			c._text(str(list.size()), Vector2(head.end.x - 3 - 4 * str(list.size()).length(), head.position.y + 1), Color("dfe8f7"))
		c._region("dsp:lane:%d" % i, head)
		var rows := int((body_h - 8.0) / CHIP_H)
		var first := 0
		if i == lane:
			first = clampi(row - rows + 1, 0, maxi(0, list.size() - rows))
		for k in range(first, mini(list.size(), first + rows)):
			var r := Rect2(x + 1, a.position.y + 8.0 + float(k - first) * CHIP_H, lane_w - 2, CHIP_H - 1)
			_chip(list[k], r, i == lane and k == row, false, false)
			_chips.append({"r": r, "id": int(list[k].id), "lane": i, "row": k})
		if list.size() > first + rows:
			c._text("+%d" % (list.size() - first - rows), Vector2(x + lane_w - 14, a.position.y + body_h - 6), MUTED)
		if carrying and held >= 0:
			var t := Msp.ticket(held)
			if not t.is_empty():
				var gr := Rect2(x + 1, a.position.y + body_h - CHIP_H, lane_w - 2, CHIP_H - 1)
				_chip(t, gr, true, false, true)
	_footer(a, 1)


func _board_narrow(a: Rect2) -> void:
	var l := ids()
	var n := l.size()
	var bw := floorf(a.size.x / float(n))
	for i in n:
		var id := str(l[i])
		var cnt := tickets_in(id).size()
		var nm: String = str(SHORT.get(id, id.to_upper().substr(0, 4)))
		var label := "%s %d" % [nm, cnt] if cnt > 0 else nm
		c._button("dsp:lane:%d" % i, Rect2(a.position.x + float(i) * bw, a.position.y, bw - 1, 9), c._clip(label, int((bw - 3) / 4)), true, c.BTN_HI if i == lane else c.BTN)
	var id := lane_id()
	var y := a.position.y + 10.0
	var head := Rect2(a.position.x, y, a.size.x, 20)
	c._fill(head, _lane_color(id))
	c._button("dsp:prev", Rect2(head.position.x + 1, y + 1, 9, 9), "<", lane > 0)
	c._button("dsp:next", Rect2(head.end.x - 10, y + 1, 9, 9), ">", lane < n - 1)
	var title := lane_title(id, 20)
	c._text(title, Vector2(head.position.x + floorf((head.size.x - c._tw(title)) * 0.5), y + 2), c.WHITE)
	var sub := ""
	if Crew.has(id):
		sub = "%s  MORALE %d  LOAD %d" % [Crew.status(id), Crew.morale(id), Crew.load_of(id)]
		if Service.design == "pods" and Service.pod_text(id) != "":
			sub = "POD " + Service.pod_text(id)
		elif Service.design == "tiered":
			sub = "%s  %s  LOAD %d" % [Service.lane_tag(id), Crew.status(id), Crew.load_of(id)]
	elif id == "Dan":
		sub = "YOU TAKE THESE YOURSELF"
	elif id == "ESC":
		sub = "ALAN %d/2  GARRISON %d/2 TODAY" % [int(Service.owner_used.Alan), int(Service.owner_used.Garrison)]
	else:
		sub = "WAITING FOR A DESK"
	c._text(c._clip(sub, int((head.size.x - 4) / 4)), Vector2(head.position.x + floorf((head.size.x - c._tw(c._clip(sub, int((head.size.x - 4) / 4)))) * 0.5), y + 11), Color("dfe8f7"))
	var foot_h := 15.0
	var lr := Rect2(a.position.x, y + 21, a.size.x, a.end.y - y - 21 - foot_h)
	_lanes.append({"r": lr, "i": lane})
	var carrying := held >= 0
	c._fill(lr, DROP if carrying else LANE_A)
	var list := tickets_in(id)
	var ch_h := 21.0
	var rows := int(lr.size.y / (ch_h + 1.0))
	var first := clampi(row - rows + 1, 0, maxi(0, list.size() - rows))
	for k in range(first, mini(list.size(), first + rows)):
		var r := Rect2(lr.position.x + 1, lr.position.y + 1 + float(k - first) * (ch_h + 1.0), lr.size.x - 2, ch_h)
		_chip(list[k], r, k == row, true, false)
		_chips.append({"r": r, "id": int(list[k].id), "lane": lane, "row": k})
	if list.is_empty():
		c._text("EMPTY. DROP A TICKET HERE." if carrying else "NOTHING HERE.", lr.position + Vector2(4, 6), MUTED)
	if list.size() > first + rows:
		c._text("+%d MORE" % (list.size() - first - rows), Vector2(lr.end.x - 34, lr.end.y - 7), MUTED)
	_footer(Rect2(a.position, a.size), 2)


func _chip(t: Dictionary, r: Rect2, sel: bool, tall: bool, ghost: bool) -> void:
	var carried := int(t.id) == held and not ghost
	c._fill(r, Color("d4d9e2") if carried else (Color("fff7e0") if ghost else c.WHITE))
	c._fill(Rect2(r.position.x, r.position.y, 2, r.size.y), c._pri_color(int(t.pri)))
	var cl := "PITP" if int(t.client) < 0 else str(Msp.CLIENTS[int(t.client)].short)
	var late: bool = bool(t.breached) or float(t.sla_left) < 30.0
	var stuck := false
	var a := Crew.assignee_of(t)
	if Crew.stuck.has(a) and int(Crew.stuck[a].ticket) == int(t.id):
		stuck = true
	var x := r.position.x + 4.0
	var chars := int((r.size.x - 6.0) / 4.0)
	var tag := "%s%d" % [Crew.tag_of(t), Crew.need_of(t)]
	if tall:
		c._text("%d P%d %s" % [int(t.id), int(t.pri), cl], Vector2(x, r.position.y + 1), INK)
		c._text(c._clip(str(t.summary), chars), Vector2(x, r.position.y + 7), MUTED)
		c._text(tag, Vector2(x, r.position.y + 13), INK)
		var st := sla_text(t)
		c._text(st, Vector2(r.end.x - 3 - c._tw(st), r.position.y + 13), c.RED if late else INK)
	else:
		c._text(c._clip("%d %s" % [int(t.id), tag], chars - (2 if stuck else 0)), Vector2(x, r.position.y + 1), INK)
		var st2 := sla_text(t)
		var left: String = c._clip(cl, maxi(1, chars - st2.length() - 1))
		c._text(left, Vector2(x, r.position.y + 7), MUTED)
		c._text(st2, Vector2(r.end.x - 2 - c._tw(st2), r.position.y + 7), c.RED if late else INK)
	if stuck:
		c._text("?", Vector2(r.end.x - 5, r.position.y + 1), c.RED)
	# the SLA bar
	var f := sla_frac(t)
	var by := r.end.y - 2.0
	c._fill(Rect2(r.position.x + 2, by, r.size.x - 2, 1), Color("d5dae3"))
	var col: Color = c.GREEN if f > 0.5 else (c.AMBER if f > 0.25 else c.RED)
	c._fill(Rect2(r.position.x + 2, by, floorf((r.size.x - 2) * f), 1), col)
	if sel or ghost:
		var oc: Color = Color("c8681a") if (ghost or held >= 0) else c.PSA_BLUE
		c._fill(Rect2(r.position, Vector2(r.size.x, 1)), oc)
		c._fill(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), oc)
		c._fill(Rect2(r.position.x, r.position.y, 1, r.size.y), oc)
		c._fill(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), oc)


# ---- capacity -----------------------------------------------------------------------------------------------------------
func util_text(u: float) -> String:
	var pct := int(round(u * 100.0))
	if fuzzy():
		return "*%d%%" % (int(round(u * 4.0)) * 25)
	return "%d%%" % pct


func _util_color(u: float) -> Color:
	return c.GREEN if u <= 0.85 else (c.AMBER if u <= 1.0 else c.RED)


func _pips(p: Vector2, morale: int) -> void:
	var on := int(round(float(morale) / 20.0))
	for i in 5:
		var col: Color = (c.GREEN if morale >= 55 else (c.AMBER if morale >= 35 else c.RED)) if i < on else Color("c5ccd8")
		c._fill(Rect2(p.x + float(i) * 4.0, p.y, 3, 4), col)


func _capacity(a: Rect2, narrow: bool) -> void:
	var names := Crew.names()
	cap_sel = clampi(cap_sel, 0, maxi(0, names.size() - 1))
	var y := a.position.y + 1.0
	var avail := maxf(Crew.hours_left(), 0.5)
	c._text("HOURS LEFT TODAY %.1f   BAR = QUEUED HOURS" % Crew.hours_left() if not narrow else "HOURS LEFT %.1f" % Crew.hours_left(), Vector2(a.position.x + 2, y), MUTED)
	y += 7.0
	var rh := 13.0 if not narrow else 22.0
	if not narrow:  # up to six techs now (C6): squeeze the rows to fit above the totals
		rh = clampf(floorf((a.size.y - 7.0 - 10.0 - 18.0) / float(maxi(1, names.size()))), 7.0, 13.0)
	for i in names.size():
		var who := str(names[i])
		var r := Rect2(a.position.x, y, a.size.x, rh - 1)
		c._fill(r, Color("c7dcf5") if i == cap_sel else (c.WHITE if i % 2 == 0 else Color("eef3f9")))
		c._region("dsp:cap:%d" % i, r)
		var ry := y + (minf(0.0, floorf((rh - 13.0) * 0.5)) if not narrow else 0.0)
		var u := Crew.utilisation(who)
		var hours := Crew.load_hours(who)
		var st := Crew.status(who)
		var st_col: Color = c.RED if st in ["STUCK", "OVERLOAD"] else (c.GREEN if st == "WORKING" else MUTED)
		var bx := a.position.x + 32.0
		var bw := floorf(a.size.x * 0.34)
		var ty := ry + 3.0
		if narrow:
			bx = a.position.x + 3.0
			bw = a.size.x - 8.0
		c._text(who.to_upper(), Vector2(a.position.x + 3, ry + 3), INK)
		if narrow:
			c._text(st, Vector2(a.position.x + 28, ry + 3), st_col)
			c._text(util_text(u), Vector2(a.end.x - 22, ry + 3), _util_color(u))
			_pips(Vector2(a.end.x - 48, ry + 4), Crew.morale(who))
			ty = ry + 12.0
		# the bar: 100% of the hours left is at two thirds
		c._fill(Rect2(bx, ty, bw, 5), Color("c5ccd8"))
		var scale := avail * 1.5
		var fill := clampf(hours / scale, 0.0, 1.0)
		c._fill(Rect2(bx, ty, floorf(bw * fill), 5), _util_color(u))
		c._fill(Rect2(bx + floorf(bw / 1.5), ty - 1, 1, 7), INK)
		if not narrow:
			var x := bx + bw + 4.0
			c._text(util_text(u), Vector2(x, ry + 3), _util_color(u))
			x += 22.0
			_pips(Vector2(x, ry + 4), Crew.morale(who))
			x += 24.0
			c._text(st, Vector2(x, ry + 3), st_col)
			x += 36.0
			var foc := Crew.focus_of(who)
			c._text(str(Crew.AREA_TAG[foc]) if foc != "" else "-", Vector2(x, ry + 3), Color("1f4e8c"))
			if st == "OVERLOAD" or st == "STUCK":
				c._fill(Rect2(a.end.x - 9, ry + 2, 7, 8), c.RED)
				c._text("!", Vector2(a.end.x - 6, ry + 3), c.WHITE)
		y += rh
	if names.is_empty():
		c._text("NOBODY LEFT ON THE CREW.", Vector2(a.position.x + 4, y + 4), c.RED)
		y += 12.0
	# the owners and the totals
	var al := "ALAN %d/%d TODAY  TRUST %d" % [int(Service.owner_used.Alan), Service.OWNER_DAY_CAP, Service.trust_of("Alan")]
	var ga := "GARRISON %d/%d TODAY  TRUST %d" % [int(Service.owner_used.Garrison), Service.OWNER_DAY_CAP, Service.trust_of("Garrison")]
	if narrow:
		c._text(c._clip(al, 42), Vector2(a.position.x + 3, y + 2), INK)
		c._text(c._clip(ga, 42), Vector2(a.position.x + 3, y + 9), INK)
		y += 17.0
	else:
		c._text(al, Vector2(a.position.x + 3, y + 1), INK)
		c._text(ga, Vector2(a.position.x + floorf(a.size.x * 0.5), y + 1), INK)
		y += 8.0
	var open := tickets_in("").size()
	var summary := "CREW MORALE %d  UNASSIGNED %d  OPEN %d" % [Crew.morale_avg(), open, Msp.open_tickets().size()]
	c._text(c._clip(summary, int((a.size.x - 6.0) / 4.0)), Vector2(a.position.x + 3, y + 1), MUTED)
	var bottom := Rect2(a.position.x, a.end.y - 10, a.size.x, 10)
	c._fill(bottom, Color("cfd9e8"))
	c._button("dsp:focus", Rect2(bottom.position.x + 2, bottom.position.y + 1, 52, 8), "FOCUS (F)", not names.is_empty())
	var note := "SET A FOCUS: THAT AREA FITS HIM BETTER AND HE TRAINS IT"
	if narrow:
		note = "FOCUS TRAINS AN AREA"
	if Time.get_ticks_msec() - msg_at < 3000 and msg != "":
		note = msg
	c._text(c._clip(note, int((a.size.x - 62.0) / 4.0)), Vector2(bottom.position.x + 58, bottom.position.y + 3), INK)


# ---- score --------------------------------------------------------------------------------------------------------------
func score_rows() -> Array:
	var td := Service.today()
	var util: float = float(td.util)
	return [
		["SLA KEPT", "%d%%" % int(td.sla)],
		["CLOSED / LATE", "%d / %d" % [int(td.closed), int(td.missed)]],
		["REOPENS", str(int(td.reopened))],
		["FIRST RESPONSE", Msp.mmss(float(td.frt))],
		["UTILISATION", "%d%%" % int(round(util * 100.0))],
		["OPEN NOW", str(int(td.open))],
		["DESK DESIGN", Service.design_label()],
		["CONFIDENCE", str(Campaign.rep)],
		["ALAN / GARRISON", "%d / %d" % [Service.trust_of("Alan"), Service.trust_of("Garrison")]],
	]


func _score(a: Rect2, narrow: bool) -> void:
	var rows := score_rows()
	var x := a.position.x + 3.0
	var y := a.position.y + 2.0
	var rw := floorf(a.size.x * 0.44) if not narrow else a.size.x - 6.0
	c._text("TODAY SO FAR", Vector2(x, y), HEAD)
	y += 8.0
	for r in rows:
		c._text(str(r[0]), Vector2(x, y), MUTED)
		c._text(str(r[1]), Vector2(x + rw - c._tw(str(r[1])) - 4.0, y), INK)
		y += 7.0
	var plot: Rect2
	if narrow:
		plot = Rect2(a.position.x + 14, y + 12, a.size.x - 20, a.end.y - y - 28)
		c._text("DAILY SCORE", Vector2(x, y + 3), HEAD)
	else:
		plot = Rect2(a.position.x + rw + 18, a.position.y + 12, a.size.x - rw - 24, a.size.y - 26)
		c._text("DAILY SCORE AND WEEKLY AVERAGE", Vector2(a.position.x + rw + 8, a.position.y + 2), HEAD)
	_chart(plot)


# the line of daily scores (last ten days) with a bar for each week's average
func _chart(plot: Rect2) -> void:
	c._fill(plot, c.WHITE)
	var lo := 30.0
	var hi := 100.0
	for band in [[45.0, "C"], [62.0, "B"], [78.0, "A"], [90.0, "S"]]:
		var gy := plot.end.y - (float(band[0]) - lo) / (hi - lo) * plot.size.y
		c._fill(Rect2(plot.position.x, gy, plot.size.x, 1), Color("e1e6ef"))
		c._text(str(band[1]), Vector2(plot.position.x - 6, gy - 2), MUTED)
	var grades: Array = Service.grades
	if grades.is_empty():
		c._text("NO DAYS YET", plot.position + Vector2(6, plot.size.y * 0.4), MUTED)
		return
	var first := maxi(0, grades.size() - 10)
	var shown: Array = grades.slice(first)
	var n := shown.size()
	var step := plot.size.x / float(maxi(1, 10))
	var pts: Array = []
	for i in n:
		var sc := clampf(float(shown[i].score), lo, hi)
		pts.append(Vector2(plot.position.x + step * (float(i) + 0.5), plot.end.y - (sc - lo) / (hi - lo) * plot.size.y))
	# weekly averages (5 days a week): a flat bar behind each week's points
	var week_start := 0
	while week_start < n:
		var wk := (int(shown[week_start].day) - 1) / 5
		var wend := week_start
		var total := 0.0
		while wend < n and (int(shown[wend].day) - 1) / 5 == wk:
			total += float(shown[wend].score)
			wend += 1
		var avg := clampf(total / float(wend - week_start), lo, hi)
		var ay := plot.end.y - (avg - lo) / (hi - lo) * plot.size.y
		c._fill(Rect2(plot.position.x + step * float(week_start) + 1, ay - 1, step * float(wend - week_start) - 2, 3), Color("f2c36b"))
		week_start = wend
	for i in n - 1:
		_line(pts[i], pts[i + 1], c.PSA_BLUE)
	for i in n:
		var col: Color = c.GREEN if float(shown[i].score) >= 62.0 else (c.AMBER if float(shown[i].score) >= 45.0 else c.RED)
		c._fill(Rect2(pts[i].x - 1, pts[i].y - 1, 3, 3), col)
		c._text(str(int(shown[i].day)), Vector2(pts[i].x - 2.0 * str(int(shown[i].day)).length(), plot.end.y + 2), MUTED)


# a crisp one pixel line (draw_line looks broken on steep slopes at this scale)
func _line(a: Vector2, b: Vector2, col: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(maxi(1, steps)))
		c._fill(Rect2(floorf(p.x), floorf(p.y), 1, 1), col)
