extends SceneTree
# Screenshots of the new computer screens (academy, quiz, profile, backups, RMM session).
#   Godot --path godot --fixed-fps 60 -s res://tests/skills_shots.gd -- --format=h

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://skills_%s.png" % name)


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
			c.save_prefix = "user://test_"
			c.new_game("tech")
			sk.ps_level = 4
			sk.xp["servers"] = 45
			sk.xp["security"] = 20
			msp.break_backup(3)
			msp.create_ticket(0, 0, "test")
			comp.open(1)
		30:
			_shot("desktop")
			comp.activate("app:learn")
		40:
			_shot("academy")
			comp.activate("lesson:4")
		50:
			_shot("quiz")
			comp.activate("lback")
			comp.activate("app:stats")
		60:
			_shot("stats")
			comp.activate("app:rmm")
			comp.activate("tab:backups")
			msp.backup_check(3)
			msp.backup_check(0)
		70:
			_shot("backups")
			comp.activate("tab:endpoints")
			comp.activate("client:0")
			var ep: String = msp.open_tickets()[0].endpoint
			comp.activate("rmm:" + ep)
			comp.activate("connect")
			comp.activate("fix:spooler")
		80:
			_shot("session")
			quit()
	return false
