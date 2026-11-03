extends SceneTree
# Sips facing right then left (frames show where the cup meets the mouth).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/bathroom.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var p: CharacterBody2D = current_scene.get_node("Actors/Player")
	match frame:
		10:
			p.give("coffee")
		20:
			p.drink()
		120:
			p.face("left")
		130:
			p.drink()
		230:
			quit()
	return false
