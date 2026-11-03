extends SceneTree
# Screenshots of ConnectWhy Dispatch (needs a renderer): the board, a chip being carried, the capacity view and the score
# view. Use -- --format=h|v|wide. PNGs: user://dispatch_<name>.png

var frame := 0
var stage := 0
var names := ["board", "carry", "capacity", "score", "fuzzy"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("user://dispatch_%s.png" % name)
		print("saved ", name)


func _mk(fix: String, pri: int, client: int, left: float) -> int:
	var msp := root.get_node("Msp")
	for ep in msp.endpoints:
		ep.problem = ""
	var t: Dictionary = msp.create_ticket(client, 0, "email")
	if t.is_empty():
		return -1
	t.fix = fix
	t.pri = pri
	t.sla_total = 300.0
	t.sla_left = left
	msp.endpoint(str(t.endpoint)).problem = fix
	return int(t.id)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame % 25 != 0:
		return false
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var cards := root.get_node("Cards")
	var computer := root.get_node("Computer")
	var crew := root.get_node("Crew")
	var msp := root.get_node("Msp")
	if stage > 0:
		_shot(names[stage - 1])
	match stage:
		0:
			root.get_node("Game").title_mode = false
			load("res://scripts/player.gd").current_character = "office_dan"
			c.new_game("service")
			cards.is_open = false
			cards._canvas.visible = false
			cards._queue.clear()
			msp.enabled = false
			msp.tickets.clear()
			sv.auto = "off"
			var ids := [
				_mk("av", 1, 0, 40.0), _mk("reboot", 2, 1, 150.0), _mk("spooler", 3, 3, 280.0), _mk("restore", 3, 0, 20.0),
				_mk("password", 4, 1, 250.0), _mk("clear_temp", 3, 3, 90.0), _mk("adobe", 4, 0, 200.0), _mk("reboot", 3, 1, 260.0),
				_mk("av", 2, 3, 120.0), _mk("password", 3, 0, 60.0),
			]
			sv.assign(ids[1], "Maya", false)
			sv.assign(ids[2], "Maya", false)
			sv.assign(ids[4], "Maya", false)
			sv.assign(ids[5], "Maya", false)
			sv.assign(ids[3], "Sam", false)
			sv.assign(ids[6], "Terry", false)
			sv.assign(ids[8], "Terry", false)
			sv.assign(ids[9], "Dan", false)
			sv.assign(ids[0], "ESC", false)
			crew.stuck["Sam"] = {"ticket": ids[3], "left": 30.0, "asked": false}
			crew.members["Sam"]["morale"] = 38
			crew.members["Maya"]["morale"] = 80
			c.day = 8
			sv.grades = [
				{"day": 1, "grade": "C", "score": 55, "util": 60, "sla": 80}, {"day": 2, "grade": "B", "score": 66, "util": 70, "sla": 85},
				{"day": 3, "grade": "B", "score": 70, "util": 70, "sla": 85}, {"day": 4, "grade": "D", "score": 40, "util": 90, "sla": 50},
				{"day": 5, "grade": "B", "score": 64, "util": 65, "sla": 90}, {"day": 6, "grade": "A", "score": 80, "util": 75, "sla": 95},
				{"day": 7, "grade": "A", "score": 82, "util": 75, "sla": 100},
			]
			root.get_node("World").clock = 11.5
			computer.dispatch.fuzz = 0
			computer.open(1)
			computer.app = "dispatch"
		1:
			computer.dispatch.lane = 0
			computer.dispatch.row = 0
			computer.dispatch.key("enter")
			computer.dispatch.key("right")
			computer.dispatch.key("right")
		2:
			computer.dispatch.cancel()
			computer.dispatch.view = "capacity"
			computer.dispatch.cap_sel = 1
		3:
			computer.dispatch.view = "score"
		4:
			computer.dispatch.view = "board"
			computer.dispatch.fuzz = 1
		_:
			quit()
			return false
	computer._canvas.queue_redraw()
	stage += 1
	return false
