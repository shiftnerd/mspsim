extends SceneTree
# Screenshots of the character select screen (needs a renderer): user://charselect_FORMAT_STEP.png
#   Godot --path godot --fixed-fps 60 -s res://tests/charselect_shots.gd -- --format=wide|h|v
# free_create (the creator it opens in), free_ready (a ready-made start), free_clothes, tech_create, tech_phone, tech_options,
# tech_build, free_options, owner_char (the cards of the owner campaign), owner_options

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
	var cs: Node = current_scene._select
	match frame:
		5:
			root.get_node("Campaign").save_prefix = "user://test_csshots_%d_" % OS.get_process_id()  # no saves: no Continue
		40:
			current_scene._open_menu()
			current_scene._choose(0)  # TECH CAMPAIGN
		80:
			if cs == null:
				print("FAIL no select screen")
				quit(1)
				return true
			cs.setup("free")
		90:
			_shot("free_create")
			cs.set_start(2)  # ADULT
		100:
			_shot("free_ready")
			cs.set_page(1)
		110:
			_shot("free_clothes")
			cs.set_page(0)
			cs.confirm()
		120:
			_shot("free_options")
			cs.setup("tech")
		130:
			cs.set_start(3)  # ready-made site Alan
		140:
			_shot("tech_create")
			cs.confirm()
		150:
			_shot("tech_phone")
			cs.confirm()
		160:
			_shot("tech_options")
			cs.opt_row = 1
		170:
			_shot("tech_options_start")
			cs.confirm()
		180:
			_shot("tech_build")
			cs.setup("owner")
		190:
			_shot("owner_char")
			cs.confirm()
		200:
			_shot("owner_options")
			print("DONE")
			quit(0)
	return false
