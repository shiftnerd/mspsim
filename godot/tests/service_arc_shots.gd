extends SceneTree
# Screenshots of the C7 story (needs a renderer): two beat cards (Heartbleed with a disabled compromise, the cost cut), the
# roll-up audit card and the review page with the Summit audit line. Use -- --format=h|v|wide.
# PNGs: user://arc_<name>_<format>.png

var frame := 0
var stage := 0
var names := ["heartbleed", "margin", "rollup", "review"]
var fmt := "wide"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--format="):
			fmt = str(a).substr(9)
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("user://arc_%s_%s.png" % [name, fmt])
		print("saved ", name)


func _clear() -> void:
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame % 25 != 0:
		return false
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var arc := root.get_node("ServiceArc")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	if stage > 0:
		_shot(names[stage - 1])
	match stage:
		0:
			root.get_node("Game").title_mode = false
			load("res://scripts/player.gd").current_character = "office_dan"
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			c.new_game("service")
			_clear()
			msp.enabled = false
			msp.tickets.clear()
			c.day = 5
			root.get_node("World").clock = 13.2
			arc.fire("heartbleed")
		1:
			_clear()
			c.day = 10
			sv.trust["Alan"] = 30  # the compromise is greyed out
			arc.fire("margin")
		2:
			_clear()
			sv.trust["Alan"] = 60
			c.day = 19
			msp.closed_ok = 120
			msp.breached = 12
			for id in ["spooler", "password", "reboot", "clear_temp", "av", "restore"]:
				sv.kb.rb(id)["state"] = sv.kb.DOCUMENTED
			arc.fire("rollup")
		3:
			_clear()
			c.rep = 72
			sv.trust["Garrison"] = 66
			sv.trust["Alan"] = 61
			root.get_node("Review").start()
			root.get_node("Review").page = 1
			root.get_node("Review")._canvas.queue_redraw()
		4:
			quit()
	stage += 1
	return false
