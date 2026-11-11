extends SceneTree
# gdlint:disable=max-line-length
# The Year 3 people: Quinn (the new hire, on the floor in tech Year 3 only, on the main floor for her two beats), Ross Calder of
# Summit (owner campaign) and Terry Vance the headhunter (service campaign) who walk the main floor on the day of their beat.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _stage() -> Node:
	var st := Node.new()
	st.scene_file_path = "res://scenes/main_floor.tscn"
	var actors := Node.new()
	actors.name = "Actors"
	st.add_child(actors)
	root.add_child(st)
	return st


func _count(st: Node, role: String) -> int:
	var n := 0
	for a in st.get_node("Actors").get_children():
		n += 1 if str(a.get("role")) == role else 0
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var w := root.get_node("World")
	var y := root.get_node("Yeartwo")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_y3p_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	# sheets: 135 frames of 64x80 in both facings, a SpriteFrames, a hands json
	for who in ["office_quinn", "office_ross", "office_terry"]:
		_check(load("res://characters/%s.tres" % who) != null, "%s has a SpriteFrames" % who)
		for side in ["right", "left"]:
			var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/%s_%s.png" % [who, side]))
			_check(sheet != null and sheet.get_width() == 135 * 64 and sheet.get_height() == 80, "%s %s sheet is 135 frames of 64x80" % [who, side])
			var f := FileAccess.open("res://assets/characters/%s_%s_hands.json" % [who, side], FileAccess.READ)
			var rows: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
			_check(rows is Array and rows.size() == 135, "%s %s hands json has 135 rows" % [who, side])
	# Quinn: the floor in tech Year 3 only
	c.new_game("tech")
	c.year = 1
	w.apply_roster()
	_check(not w.chars.has("Quinn"), "no Quinn in a first year of the tech campaign")
	c.year = 3
	w.apply_roster()
	_check(w.chars.has("Quinn") and w.row("Quinn").character == "office_quinn", "Quinn is on the floor in tech Year 3")
	var legs: Array = w.chars["Quinn"].legs
	_check(not legs.is_empty(), "Quinn has a routine")
	y.beat("newhire")
	_check(w.chars["Quinn"].legs.size() > 1, "the newhire beat sends Quinn out on the floor (%d legs)" % w.chars["Quinn"].legs.size())
	var n := 0
	while cards.is_open and n < 10:
		cards.pick(0)
		n += 1
	for m in ["owner", "service", "sales"]:
		c.new_game(m)
		c.year = 3
		w.apply_roster()
		_check(not w.chars.has("Quinn"), "no Quinn in the %s campaign" % m)
	c.new_game("tech")
	c.year = 2
	w.apply_roster()
	_check(not w.chars.has("Quinn"), "no Quinn in Year 2")
	# the visitors
	var sb := load("res://scripts/sales_beats.gd")
	for spec in [["owner", "summit", "buyer", "visitor:buyer"], ["service", "terry", "headhunter", "visitor:headhunter"]]:
		c.new_game(spec[0])
		c.year = 3
		var day := int(y.year_cfg("beats")[spec[0]][spec[1]])
		c.day = day - 1
		var st := _stage()
		sb.call(spec[2], st)
		_check(_count(st, spec[3]) == 0, "%s: nobody the day before" % spec[3])
		st.queue_free()
		c.day = day
		st = _stage()
		sb.call(spec[2], st)
		_check(_count(st, spec[3]) == 1, "%s walks the main floor on the day of the %s beat" % [spec[3], spec[1]])
		st.queue_free()
		c.year = 2
		st = _stage()
		sb.call(spec[2], st)
		_check(_count(st, spec[3]) == 0, "%s: not in Year 2" % spec[3])
		st.queue_free()
		c.year = 3
		c.new_game("tech")
		c.year = 3
		c.day = day
		st = _stage()
		sb.call(spec[2], st)
		_check(_count(st, spec[3]) == 0, "%s: not in the tech campaign" % spec[3])
		st.queue_free()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
