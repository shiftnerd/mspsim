extends SceneTree
# Screenshots of the character select screen (needs a renderer): user://charselect_FORMAT_STEP.png
#   Godot --path godot --fixed-fps 60 -s res://tests/charselect_shots.gd -- --format=wide|h|v

var frame := 0
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://charselect_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_csshots_%d_" % OS.get_process_id()  # no saves: no Continue
		40:
			current_scene._open_menu()
			current_scene._choose(0)  # TECH CAMPAIGN
		80:
			var cs: Node = current_scene._select
			if cs == null:
				print("FAIL no select screen")
				quit(1)
				return true
			cs.setup("free")
		90:
			_shot("free")
		100:
			current_scene._select.setup("tech")
			current_scene._select.move(1)
		140:
			_shot("tech_char")
			current_scene._select.confirm()
		170:
			_shot("tech_phone")
			print("DONE")
			quit(0)
	return false
