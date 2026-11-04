extends SceneTree
# Screenshots of the START chip on the character select screen and the mutator morning card (needs a renderer):
# user://mutators_FORMAT_STEP.png
#   Godot --path godot --fixed-fps 60 -s res://tests/mutators_shots.gd -- --format=wide|h|v

var frame := 0
var failures := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://mutators_%s_%s.png" % [root.get_node("Game").format, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var mu := root.get_node("Mutators")
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_mushots_%d_" % OS.get_process_id()
		40:
			current_scene._open_menu()
			current_scene._choose(0)
		80:
			var cs: Node = current_scene._select
			if cs == null:
				print("FAIL no select screen")
				quit(1)
				return true
			cs.setup("tech")
			cs.step = "options"  # the START row lives on the options page
		90:
			_shot("chip_standard")
		95:
			current_scene._select.change_start(1)
		105:
			_shot("chip_messy")
		110:
			current_scene._select.change_start(1)
			current_scene._select.change_start(1)
		120:
			_shot("chip_rival")
		125:
			current_scene._select.setup("owner")
			current_scene._select.step = "options"
			for i in 3:
				current_scene._select.change_start(1)
		135:
			_shot("chip_family")
		140:
			current_scene._select.queue_free()
			current_scene._select = null
			mu.plan = [{"id": "xp_eol", "from": 1, "to": 1}]
			mu.announce("xp_eol")
		170:
			_shot("card_xp")
		175:
			root.get_node("Cards").pick(0)
			root.get_node("Cards").pick(0)
			mu.announce("flu_season")
		205:
			_shot("card_flu")
			print("DONE")
			quit(0)
	return false
