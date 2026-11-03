extends SceneTree
# Screenshots of the RMM session with the other-fix buttons (renderer needed).
#   Godot --path godot --fixed-fps 60 -s res://tests/altfix_shots.gd -- --format=wide|v

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://altfix_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var comp := root.get_node("Computer")
	var msp := root.get_node("Msp")
	var sk := root.get_node("Skills")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			c.new_game("tech")
			sk.ps_level = 4
			sk.xp["servers"] = 80
			sk.xp["security"] = 40
			sk.xp["networking"] = 40
			sk.xp["people"] = 40
			msp.reset()
			var t: Dictionary = msp.create_ticket(0, 3, "test")
			msp.endpoint(t.endpoint).unsaved = true
			comp.open(1)
		30:
			comp.activate("app:rmm")
			comp.activate("client:0")
			var ep: String = msp.open_tickets()[0].endpoint
			comp.activate("rmm:" + ep)
			comp.activate("connect")
		40:
			_shot("bluescreen")
			comp.activate("disc")
			msp.reset()
			var t2: Dictionary = msp.create_ticket(0, 2, "test")
			msp.endpoint(t2.endpoint).unsaved = true
			comp.activate("rmm:" + t2.endpoint)
			comp.activate("connect")
		50:
			_shot("slow")
			comp.activate("disc")
			msp.reset()
			var t3: Dictionary = msp.create_ticket(0, 5, "test")
			comp.activate("rmm:" + t3.endpoint)
			comp.activate("connect")
		60:
			_shot("server")
			quit()
	return false
