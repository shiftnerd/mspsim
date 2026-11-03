extends SceneTree
# Sits the player in every seat of the listed scenes and logs the state.
# Run with --write-movie to get frames:
#   Godot --path godot --fixed-fps 60 --write-movie out.png -s res://tests/seats.gd
# Movie frame index = logged frame - 1.

const ENTRIES := [
	["main_floor", "Seat1"],
	["main_floor", "Seat2"],
	["main_floor", "Seat3"],
	["office_one", "Seat1"],
	["office_one", "Seat2"],
	["office_two", "Seat1"],
	["office_two", "Seat2"],
	["office_two", "Seat3"],
	["cubicle_area", "Seat1"],
	["cubicle_area", "Seat2"],
	["conference", "Seat1"],
	["conference", "Seat2"],
	["conference", "Seat3"],
	["conference", "Seat6"],
]
const BLOCK := 120

var frame := 0


func _process(_delta: float) -> bool:
	frame += 1
	var f := frame - 20
	if f < 0:
		return false
	var k := int(f / float(BLOCK))
	var t := f % BLOCK
	if k >= ENTRIES.size():
		print("DONE")
		quit()
		return false
	var scene_name: String = ENTRIES[k][0]
	var seat_name: String = ENTRIES[k][1]
	match t:
		0:
			change_scene_to_file("res://scenes/%s.tscn" % scene_name)
		10:
			var seat: Node2D = current_scene.get_node("Interactables/%s" % seat_name)
			var player: CharacterBody2D = current_scene.get_node("Actors/Player")
			player.global_position = Vector2(seat.global_position.x, 118)
			player.velocity = Vector2.ZERO
		20:
			Input.action_press("interact")
			Input.action_release("interact")
		80:
			var seat: Node2D = current_scene.get_node("Interactables/%s" % seat_name)
			var player: CharacterBody2D = current_scene.get_node("Actors/Player")
			var at_seat := player.global_position.is_equal_approx(seat.global_position)
			print(
				(
					"SHOT %d frame=%d %s/%s state=%s anim=%s at_seat=%s"
					% [
						k,
						frame,
						scene_name,
						seat_name,
						player.state,
						player.sprite.animation,
						at_seat
					]
				)
			)
		90:
			# Seat2 stands with a move key, the rest with E
			if seat_name == "Seat2" and scene_name == "main_floor":
				Input.action_press("move_right")
			else:
				Input.action_press("interact")
				Input.action_release("interact")
		92:
			Input.action_release("move_right")
		115:
			var seat: Node2D = current_scene.get_node("Interactables/%s" % seat_name)
			var player: CharacterBody2D = current_scene.get_node("Actors/Player")
			var on_floor_at_chair := (
				absf(player.global_position.x - seat.global_position.x) < 14.0
				and is_equal_approx(player.global_position.y, 118.0)
			)
			var collision_on: bool = not player.get_node("Collision").disabled
			print(
				(
					"STAND %d %s/%s state=%s scene=%s pos=(%.0f, %.0f) floor_at_chair=%s collision_on=%s"
					% [
						k,
						scene_name,
						seat_name,
						player.state,
						current_scene.name,
						player.global_position.x,
						player.global_position.y,
						on_floor_at_chair,
						collision_on
					]
				)
			)
	return false
