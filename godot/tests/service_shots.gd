extends SceneTree
# Screenshots of the service campaign UI (needs a renderer): the morning huddle card, an owner memo, a 1:1 card, the
# scorecard and the review. Use -- --format=h|v|wide. PNGs: user://service_<name>.png

var frame := 0
var stage := 0
var names := ["huddle", "memo", "oto", "scorecard", "review"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://service_%s.png" % name)
		print("saved ", name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame % 25 != 0:
		return false
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var sv := root.get_node("Service")
	if stage > 0:
		_shot(names[stage - 1])
		cards.is_open = false
		cards._canvas.visible = false
		cards._queue.clear()
		root.get_node("DayReport").is_open = false
		root.get_node("DayReport")._canvas.visible = false
		root.get_node("Review").is_open = false
		root.get_node("Review")._canvas.visible = false
	match stage:
		0:
			root.get_node("Game").title_mode = false
			load("res://scripts/player.gd").current_character = "office_dan"
			c.new_game("service")  # opens the huddle
		1:
			sv.memo("m1")
		2:
			sv.one_on_one("Maya")
		3:
			c.day = 7
			var r: Dictionary = c.make_report()
			sv.close_day(r)
			r["rep"] = 61
			r["cash"] = 0
			r["total_days"] = 20
			r["fired"] = false
			r["final"] = false
			r["ending"] = ""
			root.get_node("DayReport").show_report(r)
		4:
			c.day = 20
			sv.trust["Alan"] = 70
			sv.trust["Garrison"] = 65
			c.rep = 72
			root.get_node("Review").start()
			root.get_node("Review").page = int(OS.get_environment("SVC_PAGE")) if OS.get_environment("SVC_PAGE") != "" else 0
			root.get_node("Review")._canvas.queue_redraw()
		_:
			quit()
			return false
	stage += 1
	return false
