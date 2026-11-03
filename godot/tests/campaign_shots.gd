extends SceneTree
# Screenshots: the title menu and the end-of-day report (needs a renderer).
#   Godot --path godot --fixed-fps 60 -s res://tests/campaign_shots.gd -- --format=h

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://campaign_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		40:
			current_scene._open_menu()
		60:
			_shot("menu")
			var c := root.get_node("Campaign")
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			root.get_node("Game").title_mode = false
			c.new_game("tech")
			var msp := root.get_node("Msp")
			for k in 3:
				var t: Dictionary = msp.create_ticket(k, 0, "test")
				msp.rmm_action(t.endpoint, "spooler")
				msp.close_ticket(t.id)
			msp.create_ticket(4, 1, "test")
			current_scene.queue_free()
			c._end_day()
		120:
			_shot("report")
			quit()
	return false
