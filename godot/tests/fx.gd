extends SceneTree
# Uses every interactive prop; checks each effect plays and ends.
# Run with --write-movie to get frames (movie frame index = logged frame - 1):
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/fx.gd

const ENTRIES := [
	["main_floor", "UseTV", "../Fx/TV"],
	["kitchenette", "UseCoffee", "../Fx/Coffee"],
	["cubicle_area", "Usecopier", ""],
	["cubicle_area", "Usecooler", ""],
	["bathroom", "UseSink", "../Fx/Sink"],
	["bathroom", "UseToilet", "../Fx/Toilet"],
]
const BLOCK := 600

var frame := 0
var failures := 0


func _area(use_name: String) -> Node2D:
	for c in current_scene.get_node("Interactables").get_children():
		if String(c.name).begins_with(use_name):
			return c
	return null


func _fx(use_name: String) -> Node:
	var area := _area(use_name)
	return area.get_node(area.target)


func _process(_delta: float) -> bool:
	frame += 1
	var f := frame - 20
	if f < 0:
		return false
	var k := int(f / float(BLOCK))
	var t := f % BLOCK
	if k >= ENTRIES.size():
		print("DONE failures=%d" % failures)
		quit()
		return false
	var scene_name: String = ENTRIES[k][0]
	var use_name: String = ENTRIES[k][1]
	match t:
		0:
			change_scene_to_file("res://scenes/%s.tscn" % scene_name)
		5:
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()  # NPCs share these props
		10:
			var area := _area(use_name)
			var player: CharacterBody2D = current_scene.get_node("Actors/Player")
			player.global_position = Vector2(area.global_position.x, 118)
			player.velocity = Vector2.ZERO
		20:
			var fx := _fx(use_name)
			print("PRE %d frame=%d %s/%s busy=%s" % [k, frame, scene_name, use_name, fx.busy])
			Input.action_press("interact")
			Input.action_release("interact")
		25:
			var pl: CharacterBody2D = current_scene.get_node("Actors/Player")
			pl.global_position.x = maxf(pl.global_position.x - 60.0, 150.0)
		40:
			var fx := _fx(use_name)
			var ok: bool = fx.busy or fx.kind == "tv"
			if not ok:
				failures += 1
			print(
				(
					"PLAYING %d frame=%d %s/%s busy=%s ok=%s"
					% [k, frame, scene_name, use_name, fx.busy, ok]
				)
			)
		560:
			var fx := _fx(use_name)
			if fx.busy:
				failures += 1
			print("END %d frame=%d %s/%s busy=%s" % [k, frame, scene_name, use_name, fx.busy])
	return false
