extends SceneTree
# Plays wave / talk on the player so the frames can be inspected (--write-movie).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/bathroom.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	var p: CharacterBody2D = current_scene.get_node("Actors/Player") if current_scene else null
	if p == null:
		return false
	match frame:
		20:
			p.start_emote("wave", 1.0)
		100:
			p.start_emote("talk", 2.6, INF, "!")
		110:
			print("talk anim=%s frame=%d" % [p.sprite.animation, p.sprite.frame])
		300:
			print("DONE")
			quit()
	return false
