extends SceneTree
# Screenshots: the day report with an ENERGY row, the pager and morning cards (needs a renderer).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://hours_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var shift := root.get_node("Shift")
	var cards := root.get_node("Cards")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			shift.enabled = true
			c.new_game("tech")
			c.day = 7
			shift.late_min = 25
			shift.energy = 54.0
			shift._oncall_pay = 40
			shift.stay_hours = 1.0
			root.get_node("World").clock = 17.5
			shift._page_card()
		30:
			_shot("pager")
			cards.pick(1)
		50:
			_shot("morning")
			cards.pick(1)
			var r: Dictionary = c.make_report()
			r["rep"] = 50
			r["cash"] = 400
			r["total_days"] = 20
			r["fired"] = false
			r["final"] = false
			r["ending"] = ""
			root.get_node("DayReport").show_report(r)
		80:
			_shot("report")
			quit()
	return false
