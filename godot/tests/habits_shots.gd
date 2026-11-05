extends SceneTree
# R38 P2: screenshots of the Boardroom HABITS tab (renderer needed) in three states: a few habits started, everything on, the BOOKS rows.
# Run for each format: -- --format=h | v | wide   -> user://habits_<name>.png   (368x128 is "wide", 320x180 "h", 180x320 "v")

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://habits_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var comp := root.get_node("Computer")
	var sales := root.get_node("Sales")
	var h: Script = load("res://scripts/habits.gd")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			c.new_game("owner")
			c.day = 30
			sales.active = [0, 1, 2, 3, 4, 5]
			o.cash = 9000
			h.start("H1")
			h.start("H2")
			h.start("H3")
			h.start("H7")
			h.start("H12")
			o.habits.H1.last = 30 - 14  # stale
			o.habits.H2.last = 30 - 3
			o.habits.H3.last = 30 - 22  # lapsed (every 10, twice is 20)
			o.habits.H7.last = 30 - 1
			comp.open(1)
			comp.activate("app:boardroom")
		40:
			comp.activate("btab:habits")
			comp.activate("hab:sel:H1")
		50:
			_shot("some")
			comp.activate("hab:sel:H11")
		60:
			_shot("none_selected")
			for id in h.HABITS:
				h.start(str(id))
			comp.activate("hab:sel:H2")
		70:
			_shot("all")
			comp.activate("btab:books")
		80:
			_shot("books")
			quit()
	return false
