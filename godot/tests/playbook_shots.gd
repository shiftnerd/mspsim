extends SceneTree
# Screenshots: a playbook step on the computer and the yearly review pages (needs a renderer).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://pbshot_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var comp := root.get_node("Computer")
	var pb := root.get_node("Playbook")
	var review := root.get_node("Review")
	var so := root.get_node("Social")
	match frame:
		10:
			c.save_prefix = "user://test_"
			c.new_game("tech")
			pb.start("rack")
			pb.choose(1)
			pb.choose(0)
			comp.open(1)
			comp.activate("app:rmm")
			comp.activate("tab:project")
		40:
			_shot("step")
			c.rep = 70
			so.rel = {"Alan": 70, "Garrison": 30, "Dan": -20}
			root.get_node("Story").flags = {
				"rack": "S", "ransom": "lost", "migration": "B", "install": "ok"
			}
			comp.close()
			review.start()
		60:
			_shot("review0")
			review.advance()
		70:
			_shot("review1")
			review.advance()
		80:
			_shot("review2")
			review.choose(0)
		90:
			_shot("review3")
			quit()
	return false
