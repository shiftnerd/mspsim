extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the read-only HABITS and RIVALS tabs of the Boardroom, drawn inside the Computer (model: forum_view.gd). computer.gd only
# registers the tabs (tabs()) and forwards the paint call (paint()); everything else lives here.
# HABITS: the 14 good habits as a checklist (status word, weeks since last done, name) and the STANDARD score with its band word, the
# conscience as WORDS and Marge's folder count (never a number). Two columns from 300 px wide, one below.
# RIVALS: each rival with its rap sheet line and the habits the player knows about, best evidence first.
# The tabs stay hidden until the feature is live (a habit started, something learned, or rival cards exist from week 3).
# R38 P2: rows are clickable (hab:sel), the selected habit shows what it earns and a button (hab:do: adopt, re-adopt or do it now).
# OWNER OF THIS FILE: the habits agent.

const Habits := preload("res://scripts/habits.gd")
const Rival := preload("res://scripts/rival.gd")
const Temptation := preload("res://scripts/temptation.gd")
const RivalCards := preload("res://scripts/rival_cards.gd")

const INK := Color("20242c")
const MUTED := Color("6b7586")
const GOOD := Color("2fa84f")
const AMBER := Color("c98a10")
const BAD := Color("d23c3c")
const HEAD := Color("6b421c")
const SEL := Color("c7dcf5")
const LH := 7.0  # one text line

static var sel := "H1"  # the habit whose detail shows under the list
static var note := ""  # the line the last button press gave back


# the tabs to add to the Boardroom: [[id, label]] or empty while the feature is not live
static func tabs() -> Array:
	if live():
		return [["habits", "HABITS"], ["rivals", "RIVALS"]]
	return []


static func live() -> bool:
	return (
		Habits.any()
		or not Rival.lines().is_empty()
		or (not RivalCards.CARDS.is_empty() and Campaign.day >= 3)
		or (Campaign.mode == "owner" and Campaign.day >= Habits.OFFER_FROM)
	)


# draw the tab "habits" or "rivals" into the body area
static func paint(c: Node, a: Rect2, tab: String) -> void:
	if tab == "rivals":
		_rivals(c, a)
	else:
		_habits(c, a)


# a click on the HABITS tab: hab:sel:H3 picks a row, hab:do:H3 adopts it or does it now
static func act(c: Node, parts: Array) -> void:
	if parts.size() < 3:
		return
	sel = str(parts[2])
	if str(parts[1]) == "do":
		note = Habits.act(sel)
		c._say(note)
	else:
		note = ""


# the BOOKS rows: the Standard and its band, and the sealed envelope once H7 is working
static func books_rows() -> Array:
	var rows := []
	if not Habits.any():
		return rows
	var s := Habits.standard()
	rows.append(
		["STANDARD", Habits.standard_text(), GOOD if s >= 60 else (AMBER if s >= 35 else MUTED)]
	)
	if Habits.factor("H7") > 0.0:
		rows[0][1] = "%s, ENVELOPE" % Habits.standard_text()  # the sealed envelope of admin logins (H7)
	return rows


# the CLIENTS chip: the front desk saw the mood slip (H12), or empty
static func chip(client: int) -> String:
	return "SLIPPING" if Habits.drifting(client) else ""


static func _state_color(s: String) -> Color:
	match s:
		Habits.ADOPTED:
			return GOOD
		Habits.STALE:
			return AMBER
		Habits.LAPSED:
			return BAD
	return MUTED


static func _habits(c: Node, a: Rect2) -> void:
	var x := a.position.x + 4.0
	var y := a.position.y + 3.0
	var chars := int((a.size.x - 8.0) / 4.0)
	var two: bool = a.size.x >= 300.0
	var top: String = (
		"STANDARD %s" % Habits.standard_text() if Habits.any() else "STANDARD: NOTHING STARTED"
	)
	var books := "CONSCIENCE: %s  FOLDER: %d" % [Temptation.band(), Temptation.folder_count()]
	if two:
		c._text(c._clip(top, 30), Vector2(x, y), HEAD)
		c._text(c._clip(books, chars - 31), Vector2(x + 124.0, y), MUTED)
		y += LH + 1.0
	else:
		c._text(c._clip(top, chars), Vector2(x, y), HEAD)
		y += LH
		c._text(c._clip(books, chars), Vector2(x, y), MUTED)
		y += LH + 1.0
	var col_w: float = (a.size.x - 8.0) * (0.5 if two else 1.0)
	var ids: Array = Habits.all()
	var per_col: int = int(ceil(float(ids.size()) / 2.0)) if two else ids.size()
	for i in ids.size():
		var id := str(ids[i])
		var cx: float = x + (col_w if i >= per_col else 0.0)
		var cy: float = y + float(i % per_col if two else i) * LH
		if cy + LH > a.end.y:
			break
		var s: String = Habits.state(id)
		var row := Rect2(cx - 2.0, cy - 1.0, col_w - 2.0, LH)
		if id == sel:
			c._fill(row, SEL)
		c._region("hab:sel:" + id, row)
		var name_chars := int((col_w - 70.0) / 4.0)
		c._text(id, Vector2(cx, cy), INK)
		c._text(s, Vector2(cx + 14.0, cy), _state_color(s))
		var ag: int = Habits.age(id)
		c._text("%dW" % ag if ag >= 0 else "-", Vector2(cx + 44.0, cy), MUTED)
		c._text(
			c._clip(str(Habits.HABITS[id].name), name_chars),
			Vector2(cx + 62.0, cy),
			INK if s != Habits.NONE else MUTED
		)
	var rows_h: float = float(per_col) * LH
	_detail(c, a, y + rows_h + 2.0, two)


# the selected habit: its name, what it earns, how far the real thing has got, and the button
static func _detail(c: Node, a: Rect2, y0: float, two: bool) -> void:
	var x := a.position.x + 4.0
	var left := a.end.y - y0
	if left < 10.0 or not Habits.HABITS.has(sel):
		return
	var info: Dictionary = Habits.HABITS[sel]
	var act_info: Dictionary = Habits.action(sel)
	var btn_w := 78.0
	var btn := Rect2(a.end.x - btn_w - 4.0, y0, btn_w, 8.0)
	var chars := int((a.size.x - 8.0 - (btn_w + 4.0 if two else 0.0)) / 4.0)
	var out := [[str(info.name), HEAD]]
	if int((left - 1.0) / LH) < 2:  # a short screen: the one line summary instead of the name
		out = [[str(Habits.TEXT.get("short_" + sel, "")), INK]]
	else:
		for l in c._wrap(str(info.earns).to_upper(), chars):
			out.append([str(l), INK])
	out.append([Habits.progress(sel), MUTED])
	if note != "":
		out.append([note, AMBER])
	var lines_room := int((left - (0.0 if two else 10.0)) / LH)
	for i in mini(out.size(), maxi(lines_room, 1)):
		c._text(c._clip(str(out[i][0]), chars), Vector2(x, y0 + float(i) * LH), out[i][1])
	if not two:
		btn = Rect2(x, a.end.y - 10.0, a.size.x - 8.0, 8.0)
		if y0 + float(mini(out.size(), maxi(lines_room, 1))) * LH > btn.position.y:
			return
	c._button("hab:do:" + sel, btn, str(act_info.label), bool(act_info.enabled))


static func _rivals(c: Node, a: Rect2) -> void:
	var x := a.position.x + 4.0
	var y := a.position.y + 3.0
	var chars := int((a.size.x - 8.0) / 4.0)
	var room := int((a.end.y - y) / LH)
	var out: Array = []  # [text, color]
	for r in Rival.RIVALS:
		var rival := str(r)
		var info: Dictionary = Rival.RIVALS[rival]
		if rival == "plumbline" and not Rival.known(rival):
			continue
		out.append(["%s (%s)" % [info.name, info.owner], HEAD])
		var l := Rival.line(rival)
		out.append([l if l != "" else "NOTHING KNOWN YET.", INK if l != "" else MUTED])
		for level in [Rival.PROVEN, Rival.SEEN, Rival.RUMOUR]:
			for h in info.habits:
				if Rival.rap(rival, str(h)) == level:
					out.append(
						[
							"  %s %s" % [Rival.LEVELS[level], Rival.HABITS[h].name],
							(
								GOOD
								if level == Rival.PROVEN
								else (AMBER if level == Rival.SEEN else MUTED)
							)
						]
					)
	for i in out.size():
		if i >= room:
			break
		var text: String = out[i][0]
		if i == room - 1 and out.size() > room:
			text = "+%d MORE" % (out.size() - room + 1)
		c._text(c._clip(text, chars), Vector2(x, y + float(i) * LH), out[i][1])
