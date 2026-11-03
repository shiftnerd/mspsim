extends SceneTree
# Maya, the new Tier 1 tech: a coworker at main floor desk 2 (in the owner campaign she is on your payroll from week 1, X4).

var failures := 0
var frame := 0
var phase := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var world := root.get_node("World")
	var c := root.get_node("Campaign")
	var talk := root.get_node("Talk")
	var social := root.get_node("Social")
	if phase == 0:
		c.save_prefix = "user://test_%d_" % OS.get_process_id()
		c.new_game("tech")
		root.get_node("Game").title_mode = false
		_check(
			world.CAST.has("Maya") and world.chars.has("Maya"),
			"Maya is in the cast in the tech campaign"
		)
		_check(
			social.people().has("Maya") and social.DESK_OWNER[2] == "Maya",
			"and has an opinion of you and a desk"
		)
		_check(root.get_node("Lync").contacts().has("Maya"), "and is a contact on Lync")
		world.force_activity("Maya", "work")
		world.chars["Maya"].scene = "main_floor"
		change_scene_to_file("res://scenes/main_floor.tscn")
		phase = 1
		frame = 0
	elif phase == 1 and frame == 60:
		var maya := current_scene.get_node_or_null("Actors/Maya")
		_check(maya != null and maya.seat != null, "Maya sits at her desk on the main floor")
		_check(maya != null and str(maya.character) == "office_maya", "and she looks like Maya")
		for i in 4:
			talk._who = "Maya"
			var tip: String = talk.tip()
			if i == 0:
				_check(tip != "", "she has advice (%s)" % tip.left(40))
		_check(
			str(talk.GREETINGS["Maya"].friend) != "" and talk.SPECIALTY["Maya"] == "people",
			"she has a voice and a specialty"
		)
		# a ticket nearly out of time gets a tip from her
		var t: Dictionary = root.get_node("Msp").create_ticket(0, 0, "email")
		t.sla_left = 30.0
		talk._who = "Maya"
		_check(
			"almost out of time" in str(talk._state_tip()),
			"she warns you about a ticket about to breach"
		)
		# the owner campaign: she is on your payroll now (X4)
		c.new_game("owner")
		_check(world.chars.has("Maya"), "in the owner campaign Maya is on your payroll (X4)")
		c.new_game("tech")
		_check(world.chars.has("Maya"), "and she is back when you start a tech campaign")
		print("failures=", failures)
		quit(1 if failures > 0 else 0)
	return false
