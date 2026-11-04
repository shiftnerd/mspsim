extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# R20 screenshots (needs a renderer): PIXEL IT METRICS at the current output format for all four modes, painted straight into the
# viewport (the board at full size), then in the METRICS computer app and on the wall TV takeover.
#   Godot --path godot -s res://tests/dash_shots.gd -- --format=wide|h|v     (add --only=paint|app|tv, --cozy)
# Files: user://dash_<format>_<variant>_<mode>.png

var Board: GDScript
var Dash: GDScript
var variants := ["paint", "app", "tv"]
var modes := ["tech", "owner", "sales", "service"]
var step := 0
var wait := 0
var node: Node2D
var cur_mode := "tech"
var cur_variant := "paint"
var cozy := false
var steps: Array = []
var need := 6  # frames to wait before the picture (the computer fades in over 0.2 s)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			variants = a.substr(7).split(",")
		if a == "--cozy":
			cozy = true


func _fill(mode: String) -> void:
	var c := root.get_node("Campaign")
	var d := root.get_node("Difficulty")
	d.set_tier("easy" if cozy else "normal")
	d.seed_run(12)
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	root.get_node("Build").pending = {}
	c.new_game(mode)
	root.get_node("Career").toasts = false
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1
	root.get_node("World").clock = 10.5
	for child in root.get_children():  # nothing but the board in the picture: no cards, no HUD
		if child is CanvasLayer and not str(child.name) in ["Computer", "Game"]:
			child.visible = false
	var msp := root.get_node("Msp")
	var rows := []
	var seed_v := 7
	for k in 16:
		seed_v = (seed_v * 37 + 11) % 101
		var op := 5 + seed_v % 11
		seed_v = (seed_v * 37 + 11) % 101
		rows.append({"d": k + 1, "opened": op, "closed": maxi(2, op + seed_v % 7 - 3), "missed": seed_v % 3, "hours": {}})
	Dash.from_dict({"days": rows})
	c.day = 17
	var gr := root.get_node("Growth")
	var pe: int = gr.period()
	gr.esc = {pe - 1: 6, pe: 1 if mode == "owner" else 7}  # tech day 17 is day 2 of a week: pace 2.4, so 7 is up; owner 1 of 6 is down
	Dash.begin_day(17)
	Dash.today().opened = 6
	Dash.today().closed = 4
	Dash.today().missed = 1
	var crew := root.get_node("Crew")
	var i := 0
	for who in crew.names():
		Dash.add_hours(str(who), 120.0 * float((i * 3) % 5 + 1))
		i += 1
	for k in 5:
		msp.create_ticket(k % 5, k, "shot")
	msp.backups[2].ok = false
	if mode == "owner":
		root.get_node("Owner").history = [{"day": 11, "profit": 900, "ebitda": 800, "cash": 4000}, {"day": 12, "profit": 1500, "ebitda": 1300, "cash": 5200}, {"day": 13, "profit": -300, "ebitda": -200, "cash": 4900}, {"day": 14, "profit": 1900, "ebitda": 1700, "cash": 6600}, {"day": 15, "profit": 2400, "ebitda": 2200, "cash": 8800}, {"day": 16, "profit": 2100, "ebitda": 1900, "cash": 10700}]
	if mode == "service":
		root.get_node("Service").owner_used["Alan"] = 1


func _shot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://dash_%s_%s_%s.png" % [root.get_node("Game").format, tag, cur_mode])


func _process(_delta: float) -> bool:
	if Board == null:
		Board = load("res://scripts/dashboard.gd")
		Dash = load("res://scripts/dash.gd")
		root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
		for v in variants:
			for m in modes:
				steps.append([v, m])
		return false
	wait += 1
	if wait < need:
		return false
	wait = 0
	if step > 0:
		_shot("%s" % steps[step - 1][0])
		if node != null:
			node.queue_free()
			node = null
		if cur_variant != "paint":
			root.get_node("Computer").close()
			root.get_node("Computer")._fade = 0.0
			root.get_node("Computer")._canvas.visible = false
			root.get_node("Game").ui_open = false
	if step >= steps.size():
		quit()
		return false
	cur_variant = steps[step][0]
	cur_mode = steps[step][1]
	need = 6 if cur_variant == "paint" else 40
	_fill(cur_mode)
	match cur_variant:
		"paint":
			node = Node2D.new()
			root.add_child(node)
			var size := Vector2(root.get_node("Game").FORMATS[root.get_node("Game").format].size)
			node.draw.connect(func() -> void: Board.paint(node, Rect2(Vector2.ZERO, size), cur_mode, 5.0))
			node.queue_redraw()
		"app":
			var comp := root.get_node("Computer")
			comp.open(1)
			comp.activate("app:dash")
			comp.dash_t = 5.0
			comp._fade = 1.0
			comp._canvas.modulate.a = 1.0
		"tv":
			var comp2 := root.get_node("Computer")
			comp2.open_tv()
			comp2.dash_t = 5.0
			comp2._fade = 1.0
			comp2._canvas.modulate.a = 1.0
	step += 1
	return false
