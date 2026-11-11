extends RefCounted
# gdlint:disable=max-line-length
# The third step of the character select screen (X7): stat rows with pips, points left, a preset chip (P cycles), two
# quirk chips and a few lines of effect text. The screen (charselect.gd) owns the keys and the _rects list; this class owns the
# working build and draws itself on the screen's canvas. Rows: the path's five stats, "q1", "q2", "preset". Layout: two
# columns at 368x128 and 320x180 (stats left, the rest right), one column at 180x320. Kinds it adds to the rect list:
# b_row (index = row), b_pip (index = stat * 10 + level), b_prev / b_next (index = row of a chip).
# The panel never changes the game by itself: confirm() on the screen puts build_out() into Build.pending.

const PixelFont := preload("res://scripts/pixelfont.gd")
const GOLD := Color("f5d442")
const DIM := Color("9aa8c0")
const PANEL := Color(0.05, 0.07, 0.12, 0.85)
const SEL := Color(0.1, 0.13, 0.2, 0.9)
const PIP := Color("6fb3ff")
const EMPTY := Color("46506a")
const LOCKED := Color("1f2433")
const RED := Color("ff7a6a")

var mode := ""
var character := ""
var path := "tech"
var who := ""
var b: Dictionary = {}
var row := 0
var rows: Array = []
var slots: Array = ["", ""]
var note := ""


func setup(for_mode: String, for_character: String) -> void:
	mode = for_mode
	character = for_character
	path = Build.path_of(for_mode)
	who = World.cast_of(for_character) if for_mode == "owner" or for_mode == "service" else ""
	rows = Build.stats_of(path).duplicate()
	rows.append_array(["q1", "q2", "preset"])
	row = 0
	note = ""
	var presets := Build.presets_for(path, who)
	b = Build.apply_preset(path, who, Difficulty.tier, str(presets[0].id)) if not presets.is_empty() else Build.new_build(Difficulty.tier)
	_load_slots()


func _load_slots() -> void:
	slots = ["", ""]
	var list: Array = b.get("quirks", [])
	for i in mini(2, list.size()):
		slots[i] = str(list[i])


func _compose() -> void:
	var list := []
	for q in slots:
		if str(q) != "":
			list.append(str(q))
	b["quirks"] = list


func _touch() -> void:
	b["preset"] = "custom"
	b["spent"] = Build.cost_of(b, path, who)
	note = ""


# the tier changed while this step was open: fit the build to the new budget
func refit() -> void:
	var id := str(b.preset)
	b["tier"] = Difficulty.tier
	if id != "custom" and not Build.preset_row(path, who, id).is_empty():
		b = Build.apply_preset(path, who, Difficulty.tier, id)
		_load_slots()
	elif not Build.validate(b, path, who).is_empty():
		var presets := Build.presets_for(path, who)
		if not presets.is_empty():
			b = Build.apply_preset(path, who, Difficulty.tier, str(presets[0].id))
			_load_slots()


func points_left() -> int:
	return Build.points_left(b, path, who)


func errors() -> Array:
	return Build.validate(b, path, who)


func valid() -> bool:
	return errors().is_empty()


func name_text() -> String:
	return Build.preset_name(b, path, who)


# the build to hand to the game
func build_out() -> Dictionary:
	b["tier"] = Difficulty.tier
	return Build.finalize(b, path, who)


func level(stat: String) -> int:
	return Build.level_of(b, stat, who)


# ---- changing things --------------------------------------------------------------------------------------------
func move_row(d: int) -> void:
	row = (row + d + rows.size()) % rows.size()
	note = ""


func set_level(stat: String, lv: int) -> void:
	var before := level(stat)
	if lv == before:
		return
	if Build.try_set(b, stat, lv, path, who):
		_touch()
		return
	if lv > before:
		var test: Dictionary = b.duplicate(true)
		test.stats[stat] = lv
		var errs := Build.validate(test, path, who)
		note = str(errs[0]) if not errs.is_empty() else ""
	else:
		note = "%s IS FREE UP TO LEVEL %d" % [Build.stat_name(path, stat), Build.floor_of(stat, who)]


func quirk_at(slot: int) -> String:
	return str(slots[slot])


func quirk_options(slot: int) -> Array:
	var out := [""]
	var other := quirk_at(1 - slot)
	for id in Build.QUIRKS:
		if str(id) == other:
			continue
		var test := []
		if other != "":
			test.append(other)
		test.append(str(id))
		if Build.quirks_ok(test, path):
			out.append(str(id))
	return out


func cycle_quirk(slot: int, d: int) -> void:
	var opts := quirk_options(slot)
	var i := maxi(0, opts.find(quirk_at(slot)))
	slots[slot] = opts[(i + d + opts.size()) % opts.size()]
	_compose()
	_touch()


func preset_ids() -> Array:
	var out := []
	for p in Build.presets_for(path, who):
		out.append(str(p.id))
	out.append("custom")
	return out


func cycle_preset(d: int) -> void:
	var ids := preset_ids()
	var i := ids.find(str(b.preset))
	if i < 0:
		i = ids.size() - 1
	var id := str(ids[(i + d + ids.size()) % ids.size()])
	note = ""
	if id == "custom":
		b["preset"] = "custom"
		return
	b = Build.apply_preset(path, who, Difficulty.tier, id)
	_load_slots()


# Left / Right on the selected row
func change(d: int) -> void:
	var r := str(rows[row])
	if r == "q1":
		cycle_quirk(0, d)
	elif r == "q2":
		cycle_quirk(1, d)
	elif r == "preset":
		cycle_preset(d)
	else:
		set_level(r, level(r) + d)


func click(kind: String, idx: int) -> void:
	match kind:
		"b_row":
			row = clampi(idx, 0, rows.size() - 1)
		"b_pip":
			var stat := str(rows[clampi(idx / 10, 0, rows.size() - 1)])
			row = idx / 10
			var lv := idx % 10
			set_level(stat, lv - 1 if lv == level(stat) else lv)
		"b_prev", "b_next":
			row = clampi(idx, 0, rows.size() - 1)
			change(-1 if kind == "b_prev" else 1)


func hover(kind: String, idx: int) -> void:
	if kind == "b_row" or kind == "b_prev" or kind == "b_next":
		row = clampi(idx, 0, rows.size() - 1)
	elif kind == "b_pip":
		row = clampi(idx / 10, 0, rows.size() - 1)


# ---- text ----------------------------------------------------------------------------------------------------------
func quirk_label(id: String) -> String:
	if id == "":
		return "NONE"
	var q: Dictionary = Build.QUIRKS.get(id, {})
	return "%s %s%d" % [str(q.get("name", id.to_upper())), "+" if int(q.get("pts", 0)) > 0 else "", int(q.get("pts", 0))]


func effect_text() -> String:
	var r := str(rows[row])
	if r == "q1" or r == "q2":
		var id := quirk_at(0 if r == "q1" else 1)
		if id == "":
			return "A QUIRK GIVES YOU EXTRA POINTS AT A SMALL COST. A GOOD ONE COSTS POINTS."
		return str(Build.QUIRKS.get(id, {}).get("text", ""))
	if r == "preset":
		var p := Build.preset_row(path, who, str(b.preset))
		return str(p.get("text", "YOUR OWN MIX. CHANGE ANY STAT.")) if not p.is_empty() else "YOUR OWN MIX. CHANGE ANY STAT."
	var lv := level(r)
	return "%s %d: %s" % [Build.stat_name(path, r), lv, Build.stat_text(path, r)]


func message() -> Array:
	var errs := errors()
	if not errs.is_empty():
		return [str(errs[0]), RED]
	if note != "":
		return [note, RED]
	var warns := Build.warnings(b, path, who)
	if not warns.is_empty():
		return [str(warns[0]), GOLD]
	return ["", GOLD]


func _wrap(s: String, chars: int, max_lines: int) -> Array:
	s = PixelFont.keys(s)  # R42: key tokens become the key or the pad button before the lines are cut
	var lines: Array = []
	var line := ""
	for word in s.split(" "):
		if line != "" and line.length() + 1 + word.length() > chars:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines.slice(0, max_lines)


# ---- drawing -------------------------------------------------------------------------------------------------------
func draw(c: CanvasItem, size: Vector2, narrow: bool, rects: Array) -> void:
	var two := size.x > 250.0
	var tall := size.y > 150.0
	var lx := 8.0
	var points_y := 15.0
	var sy := 25.0
	var step := 10.0
	var col_w := 178.0
	var rx := 196.0
	var ry := 25.0
	var rstep := 11.0
	var rw := size.x - rx - 6.0
	var effect_y := 60.0
	var effect_lines := 4
	if two and tall:
		points_y = 28.0
		sy = 39.0
		step = 12.0
		col_w = 152.0
		rx = 170.0
		ry = 39.0
		rstep = 12.0
		rw = size.x - rx - 6.0
		effect_y = 79.0
		effect_lines = 5
	elif narrow:
		points_y = 46.0
		sy = 58.0
		step = 13.0
		col_w = size.x - 12.0
		rx = 6.0
		rw = size.x - 12.0
		ry = sy + step * float(rows.size() - 3) + 2.0
		rstep = 12.0
		effect_y = ry + rstep * 3.0 + 4.0
		effect_lines = 6
	# points left
	var left := points_left()
	var budget_text := "POINTS LEFT %d OF %d" % [left, Build.budget(Difficulty.tier) + Build.quirk_points(b)]
	if narrow:
		var tw := float(PixelFont.width(budget_text))
		PixelFont.draw(c, budget_text, Vector2(floorf((size.x - tw) * 0.5), points_y), GOLD if left >= 0 else RED)
	else:
		PixelFont.draw(c, budget_text, Vector2(lx, points_y), GOLD if left >= 0 else RED)
	# stat rows
	var stats := Build.stats_of(path)
	for i in stats.size():
		_draw_stat(c, rects, i, str(stats[i]), Vector2(lx, sy + step * float(i)), col_w, step - 1.0)
	# chips: preset first in two columns (the quirks follow), quirks then preset in one column
	var qi := stats.size()
	var order := [qi + 2, qi, qi + 1] if two else [qi, qi + 1, qi + 2]
	for k in 3:
		var ri: int = order[k]
		_draw_chip(c, rects, ri, Rect2(rx, ry + rstep * float(k), rw, 9.0))
	# effect text and the message
	var chars := int((rw - 2.0) / 4.0)
	var y := effect_y
	for line in _wrap(effect_text(), chars, effect_lines):
		PixelFont.draw(c, str(line), Vector2(rx, y), Color.WHITE)
		y += 8.0
	var msg := message()
	if str(msg[0]) != "":
		var lines := _wrap(str(msg[0]), chars, 2)
		var my := maxf(y + 3.0, effect_y + 8.0 * float(effect_lines) + 3.0) if two else y + 3.0
		for line in lines:
			PixelFont.draw(c, str(line), Vector2(rx, my), msg[1])
			my += 8.0


func _draw_stat(c: CanvasItem, rects: Array, i: int, stat: String, pos: Vector2, w: float, h: float) -> void:
	var r := Rect2(pos.x - 3.0, pos.y - 1.0, w, h + 1.0)
	var sel := row == i
	c.draw_rect(r, SEL if sel else PANEL)
	if sel:
		c.draw_rect(r, GOLD, false, 1.0)
	rects.append([r, "b_row", i])
	var ty := pos.y + floorf((h - 5.0) * 0.5)
	var lv := level(stat)
	var fl := Build.floor_of(stat, who)
	var cap := mini(Build.MAX_START, Build.cap_of(stat, who))
	PixelFont.draw(c, Build.stat_name(path, stat), Vector2(pos.x, ty), Color.WHITE if sel else DIM)
	for k in range(1, 6):
		var pr := Rect2(pos.x + 62.0 + float(k - 1) * 6.0, pos.y + floorf((h - 4.0) * 0.5), 4.0, 4.0)
		var col := EMPTY
		if k <= fl:
			col = GOLD
		elif k <= lv:
			col = PIP
		elif k > cap:
			col = LOCKED
		c.draw_rect(pr, col)
		rects.append([Rect2(pr.position - Vector2(1, 2), Vector2(6, h)), "b_pip", i * 10 + k])
	PixelFont.draw(c, "L%d" % lv, Vector2(pos.x + 96.0, ty), GOLD if lv > fl else Color.WHITE)
	var cost := int(Build.COST[lv]) - int(Build.COST[fl]) if lv > fl else 0
	if cost > 0 and w > 130.0:
		PixelFont.draw(c, "-%d" % cost, Vector2(pos.x + 112.0, ty), DIM)


func _draw_chip(c: CanvasItem, rects: Array, ri: int, r: Rect2) -> void:
	var kind := str(rows[ri])
	var text := ""
	if kind == "preset":
		text = "PRESET  " + name_text()
	else:
		text = "QUIRK  " + quirk_label(quirk_at(0 if kind == "q1" else 1))
	c.draw_rect(r, SEL if row == ri else PANEL)
	c.draw_rect(r, GOLD if row == ri else DIM, false, 1.0)
	PixelFont.draw(c, "<", r.position + Vector2(3, 2), GOLD)
	PixelFont.draw(c, ">", r.position + Vector2(r.size.x - 7.0, 2), GOLD)
	var tw := float(PixelFont.width(text))
	PixelFont.draw(c, text, r.position + Vector2(floorf((r.size.x - tw) * 0.5), 2), Color.WHITE)
	rects.append([Rect2(r.position, Vector2(r.size.x * 0.5, r.size.y)), "b_prev", ri])
	rects.append([Rect2(r.position + Vector2(r.size.x * 0.5, 0.0), Vector2(r.size.x * 0.5, r.size.y)), "b_next", ri])
