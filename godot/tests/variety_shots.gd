extends SceneTree
# R11 screenshots: the bowling intro with the alley and oil line, the aim bar with a hook on dry lanes, the league night
# result, the nerf war card, and the cup war in the cubicle area.
# Renderer needed: `Godot --path godot -s res://tests/variety_shots.gd -- --format=wide|h|v`
# Files: user://variety_<tag>_<name>.png (tag from the env var VS_TAG, default "x").

var frame := 0
var tag := "x"
var cases := ["bowl_intro", "bowl_hook", "bowl_league", "nerf_card", "nerf_cup"]


func _initialize() -> void:
	if OS.get_environment("VS_TAG") != "":
		tag = OS.get_environment("VS_TAG")
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://variety_%s_%s.png" % [tag, name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var nerf := root.get_node("Nerf")
	var cards := root.get_node("Cards")
	var campaign := root.get_node("Campaign")
	var step := frame - 10
	var i := step / 300
	var t := step % 300
	if i >= cases.size():
		quit()
		return false
	var c: String = cases[i]
	if c.begins_with("bowl"):
		if t == 0:
			campaign.new_game(campaign.FREE)
			o.enabled = true
			o.use_rooms = false
			d.seed_run(12)
			o.start("bowling", false, {"alley": "league" if c == "bowl_league" else "rental", "party": ["Alan", "Garrison", "Dan", "Vic"]})
		elif t == 60 and c == "bowl_intro":
			_shot(c)
		elif t == 80 and c != "bowl_intro":
			o.press(KEY_ENTER)
		elif t == 100 and c == "bowl_hook":
			o.g.marker = 0.3
			o.press(KEY_LEFT)
		elif t == 140 and c == "bowl_hook":
			_shot(c)
		elif t == 100 and c == "bowl_league":
			var k := 0
			for who in o.g.totals:
				o.g.totals[who] = 36 - 6 * k
				k += 1
			o._bowl_end()
		elif t == 150 and c == "bowl_league":
			_shot(c)
		elif t == 200:
			if o.is_open:
				o.close()
	else:
		if t == 0:
			campaign.new_game(campaign.FREE)
			d.seed_run(12)
			change_scene_to_file("res://scenes/cubicle_area.tscn")
		elif t == 60:
			var p := current_scene.get_node("Actors/Player")
			p.give("nerf")
			if c == "nerf_card":
				nerf.offer_war()
		elif t == 90 and c == "nerf_card":
			_shot(c)
		elif t == 100 and c == "nerf_cup":
			nerf.start_war("cup")
		elif t == 160 and c == "nerf_cup":
			_shot(c)
		elif t == 200:
			if cards.is_open:
				cards.pick(cards.options.size() - 1)
			nerf.war_t = 0.0
			nerf._clear_mode()
	return false
