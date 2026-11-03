extends SceneTree
# Screenshots of the Boardroom with the profit hours column and the PROJECTS tab (renderer needed).
# Run for each format: -- --format=h | v | wide   -> user://projects_<tab>.png

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://projects_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var comp := root.get_node("Computer")
	var sales := root.get_node("Sales")
	var pr := root.get_node("Projects")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			c.new_game("owner")
			sales.active = [0, 1, 2, 3, 4, 5]
			o.client_work[2] = 700.0
			o.client_work[0] = 200.0
			pr.record_week()
			pr.record_week()
			pr.sell_service(0, "backup")
			pr.sell_service(1, "patching")
			var q: Dictionary = pr.make_quote(1, "server")
			var p: Dictionary = pr.start_project(q, "fixed")
			p.creep = true
			pr.make_quote(3, "network")
			pr.start_project(pr.make_quote(3, "network"), "scope")
			pr.completed_count = 2
			pr.completed_profit = 640
			pr.wom_weeks = 3
			comp.open(1)
			comp.activate("app:boardroom")
		40:
			comp.activate("btab:clients")
		50:
			_shot("clients")
			comp.activate("btab:projects")
		60:
			_shot("projects")
			quit()
	return false
