extends SceneTree
# The rubber duck on the player monitor: E squeaks, stares blankly or listens.

var frame := 0
var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 20:
		return false
	var player := current_scene.get_node_or_null("Actors/Player")
	var duck_fx: Node = null
	var zone: Node = null
	for z in current_scene.get_node("Interactables").get_children():
		if str(z.name).begins_with("Userubber_duck"):
			zone = z
			duck_fx = z.get_node(z.target)
	_check(zone != null and duck_fx != null, "there is a rubber duck on the desk")
	_check(zone.low_priority, "and it never wins over the monitor")
	var seen := {}
	for i in 60:
		duck_fx._duck_t = 0.0
		duck_fx.play()
		seen[duck_fx._duck_msg] = true
	_check(
		seen.has("SQUEAK!") and seen.has("..."),
		"it squeaks or stares blankly (%s)" % str(seen.keys())
	)
	_check(seen.has("!"), "and after ten squeaks it has heard enough")
	zone.use(player)
	_check(duck_fx._duck_t > 0.0, "the player can press E on it")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
	return false
