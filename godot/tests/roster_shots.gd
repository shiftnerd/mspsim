extends SceneTree
# R5 screenshots: the bowling scoreboard with four opponents (in the alley and as the overlay panel) and the dinner
# table with five faces (in the restaurant and as the overlay panel).
# Renderer needed: `Godot --path godot -s res://tests/roster_shots.gd -- --format=wide|h|v`
# Files: user://roster_<tag>_<name>.png (tag from the env var RS_TAG, default "x").

var frame := 0
var tag := "x"
var cases := ["bowl4", "bowl4_panel", "dinner5", "dinner5_panel"]
var party := ["Morgan", "Maya", "John", "Dan", "Garrison", "Alan"]


func _initialize() -> void:
	if OS.get_environment("RS_TAG") != "":
		tag = OS.get_environment("RS_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://roster_%s_%s.png" % [tag, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var step := frame - 10
	var i := step / 400
	var t := step % 400
	if i >= cases.size():
		quit()
		return false
	var c: String = cases[i]
	var campaign := root.get_node("Campaign")
	if t == 0:
		campaign.new_game(campaign.FREE)
		o.enabled = true
		o.use_rooms = not c.ends_with("_panel")
		d.seed_run(41)
		o.start("bowling" if c.begins_with("bowl") else "dinner", false, {"party": party.duplicate()})
	elif t == 200:
		o.press(KEY_ENTER)
	elif t == 215:
		if c == "dinner5":
			var seat := current_scene.get_node("Interactables/Seat2")
			var p := current_scene.get_node("Actors/Player")
			p.global_position = seat.global_position
			p.sit(seat)
		elif c == "bowl4":
			var k := 0
			for who in o.g.totals:
				o.g.totals[who] = 34 - 7 * k
				k += 1
		elif c == "bowl4_panel":
			var k := 0
			for who in o.g.totals:
				o.g.totals[who] = 34 - 7 * k
				k += 1
			o.g.stage = "aim"
			o.g.marker = 0.6
	elif t == 260:
		_shot(c)
	elif t == 265 and c == "bowl4":
		o.g.roll = 2
		o.g.pins = 0
		o._bowl_next()
	elif t == 300 and c == "bowl4":
		_shot(c + "_crew")
	elif t == 280 and c.begins_with("dinner"):
		o.dinner_talk(0)
	elif t == 320 and c.begins_with("dinner"):
		_shot(c + "_talk")
	elif t == 350:
		if o.is_open:
			o._finish(2)
		o.close()
	return false
