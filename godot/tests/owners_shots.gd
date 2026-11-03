extends SceneTree
# Screenshots (needs a renderer; `-- --format=wide|h|v`): Alan at a ringing phone with a headset
# (user://owners_phone.png) and the day report with its OWNERS STEPPED IN row (user://owners_report.png).

var frame := 0
var phase := 0
var _t := 0.0


func _initialize() -> void:
	change_scene_to_file("res://scenes/cubicle_area.tscn")


func _process(delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var world := root.get_node("World")
	var o := root.get_node("Owners")
	var campaign := root.get_node("Campaign")
	if frame == 5:
		root.get_node("Game").title_mode = false
		campaign.new_game("tech")
		campaign.day = 3
		world.clock = 10.0
		root.get_node("Msp").reset()
		world.chars["Alan"].scene = "cubicle_area"
		world.chars["Alan"].arrive = "from_main"
		world.chars["Alan"].legs = [{"kind": "work", "scene": "cubicle_area", "target_x": 100.0, "dur": 30.0, "routine": PackedStringArray(["wait:5"])}]
		world.apply_roster()
		world._spawn("Alan")
	if frame == 25:
		for nd in current_scene.get_node("Actors").get_children():
			if nd.get("cast_name") != null and nd.cast_name != "" and nd.cast_name != "Alan":
				nd.queue_free()
	if frame == 30 and phase == 0:
		world.time_scale = 1.0
		for who in ["Vic", "Morgan", "Dan", "Maya"]:
			if world.chars.has(who):
				var nd: Node = world.chars[who].node
				if nd != null and is_instance_valid(nd):
					nd.queue_free()
				world.chars.erase(who)
		var zones := get_nodes_in_group("phones")
		var n := 0
		for z in zones:
			var fx: Node = z.get_node(z.target)
			fx.ringing = true
			fx._ring_until = fx._time + 60.0
			n += 1
		var d: Dictionary = o.check()
		print("check ", d, " active ", o.active(), " allowed ", o.allowed_now(), " trig ", o.trigger(), " rings ", o.ringing_phones().size(), " free ", o.is_free("Alan"), o.is_free("Garrison"), " tier ", root.get_node("Difficulty").tier, " pd ", o.per_day())
		if d.is_empty():
			o.fake_rings = 2
			d = o.check()
		o.step_in(str(d.who), str(d.reason), d)
		phase = 1
	if phase == 1:
		_t += delta
		var alan := current_scene.get_node_or_null("Actors/Alan")
		if frame % 240 == 0:
			print("alan ", alan, " ", alan.state if alan else "", " x ", alan.global_position.x if alan else 0, " step ", alan._step if alan else 0, " routine ", alan.routine if alan else "", " phones ", o.ringing_phones().size(), " ", get_nodes_in_group("phones").map(func(z): return [z.get_node(z.target).ringing, z.get_node(z.target).busy, snappedf(z.global_position.x,1)]))
		if alan != null and alan._call_stage == "talking":
			phase = 2
			print("talking")
			_t = 0.0
	if phase == 2:
		_t += delta
		if _t > 0.8:
			_save("owners_phone")
			phase = 3
			o.stepped = 2
			var c := root.get_node("Campaign")
			var r: Dictionary = c.make_report()
			r["rep"] = c.rep
			r["cash"] = c.cash
			r["total_days"] = 20
			r["fired"] = false
			r["final"] = false
			r["ending"] = ""
			r["rep_cap"] = 100
			root.get_node("DayReport").show_report(r)
			_t = 0.0
	if phase == 3:
		_t += delta
		if _t > 6.0:
			_save("owners_report")
			quit()
	if frame > 3000:
		print("timeout in phase ", phase)
		quit()
	return false


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://%s.png" % name)
