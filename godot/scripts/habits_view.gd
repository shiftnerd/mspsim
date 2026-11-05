extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the read-only HABITS and RIVALS tabs of the Boardroom, drawn inside the Computer (model: forum_view.gd). computer.gd only
# registers the tabs (tabs()) and forwards the paint call (paint()); everything else lives here.
# HABITS: the 14 good habits as a checklist (status word, weeks since last done, name) and the STANDARD score with its band word, the
# conscience as WORDS and Marge's folder count (never a number). Two columns from 300 px wide, one below.
# RIVALS: each rival with its rap sheet line and the habits the player knows about, best evidence first.
# The tabs stay hidden until the feature is live (a habit started, something learned, or rival cards exist from week 3).
# OWNER OF THIS FILE: the habits agent (polish: details of a selected row, what it earns). Signatures below are FINAL.

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
const LH := 7.0  # one text line


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
	)


# draw the tab "habits" or "rivals" into the body area
static func paint(c: Node, a: Rect2, tab: String) -> void:
	if tab == "rivals":
		_rivals(c, a)
	else:
		_habits(c, a)


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
	if Habits.any():
		c._text(c._clip("STANDARD %s" % Habits.standard_text(), chars), Vector2(x, y), HEAD)
	else:
		c._text(c._clip("STANDARD: NOTHING STARTED YET", chars), Vector2(x, y), MUTED)
	y += LH
	c._text(
		c._clip(
			"CONSCIENCE: %s  FOLDER: %d" % [Temptation.band(), Temptation.folder_count()], chars
		),
		Vector2(x, y),
		MUTED
	)
	y += LH + 2.0
	var two: bool = a.size.x >= 300.0
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
		var name_chars := int((col_w - 62.0) / 4.0)
		c._text(id, Vector2(cx, cy), INK)
		c._text(s, Vector2(cx + 14.0, cy), _state_color(s))
		var ag: int = Habits.age(id)
		c._text("%dW" % ag if ag >= 0 else "-", Vector2(cx + 46.0, cy), MUTED)
		c._text(
			c._clip(str(Habits.HABITS[id].name), name_chars),
			Vector2(cx + 62.0, cy),
			INK if s != Habits.NONE else MUTED
		)


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
