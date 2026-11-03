extends SceneTree
# Screenshots: the RMM PROJECT tab and the PROFILE with coworkers (needs a renderer).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://install_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var comp := root.get_node("Computer")
	var so := root.get_node("Social")
	match frame:
		10:
			c.save_prefix = "user://test_"
			c.new_game("tech")
			var t: Dictionary = msp.create_problem(0, msp.INSTALL, "email")
			msp.start_project(t.id)
			msp.project_scan(false)
			msp.project_ask()
			msp.project_toggle("docs")
			msp.project_toggle("mail")
			msp.project_migrate()
			msp.project_toggle("xray")
			comp.open(1)
			comp.activate("app:rmm")
			comp.activate("tab:project")
		40:
			_shot("project")
			so.rel = {"Alan": 70, "Garrison": -20, "Dan": 8}
			comp.activate("app:stats")
		60:
			_shot("profile")
			quit()
	return false
