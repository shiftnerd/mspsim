extends SceneTree
# Screenshots of ConnectWhy Knowledge and the C6 cards (needs a renderer): the runbook list, a second page, the desk and crew
# tabs, the desk design card, the candidates card, an interview and the onboarding card. Use -- --format=h|v|wide.
# PNGs: user://knowledge_<name>.png (3x upscaled).

var frame := 0
var stage := 0
var names := ["books", "books2", "desk", "crew", "design", "dispatcher", "cands", "interview", "revealed", "onboard", "retention", "report", "cap6", "board6"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("user://knowledge_%s.png" % name)
		print("saved ", name)


func _drop(cards: Node) -> void:
	cards.is_open = false
	cards._canvas.visible = false
	cards._queue.clear()


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame % 25 != 0:
		return false
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var cards := root.get_node("Cards")
	var computer := root.get_node("Computer")
	var crew := root.get_node("Crew")
	var msp := root.get_node("Msp")
	if stage > 0:
		_shot(names[stage - 1])
	match stage:
		0:
			root.get_node("Game").title_mode = false
			load("res://scripts/player.gd").current_character = "office_dan"
			c.new_game("service")
			_drop(cards)
			msp.enabled = false
			msp.tickets.clear()
			var kb = sv.kb
			c.day = 8
			sv.apply_design("tiered", true)
			_drop(cards)
			kb.rb("spooler")["state"] = kb.DOCUMENTED
			kb.rb("password")["state"] = kb.TRAINED
			kb.rb("clear_temp")["state"] = kb.DRAFT
			kb.rb("reboot")["state"] = kb.DOCUMENTED
			kb.rb("reboot")["stale"] = true
			kb.rb("adobe")["state"] = kb.DOCUMENTED
			kb.rb("adobe")["signoff"] = 2
			kb.bus["rack"] = "Terry"
			kb.hours_used = 1.5
			kb.sel = 3
			root.get_node("World").clock = 11.5
			computer.open(1)
			computer.app = "knowledge"
		1:
			computer.dispatch.cancel()
			sv.kb.sel = 9
		2:
			sv.kb.view = "desk"
		3:
			sv.kb.view = "crew"
			var cand: Dictionary = crew.make_candidates(3)[0]
			sv.finish_hire(cand, "shadow")
			crew.onboard_pending(8)
			crew.members[crew.newest_hire()]["shadow"] = 0
		4:
			computer.close()
			sv.design = ""
			sv.design_changes = 0
			sv.design_card(false)
		5:
			cards.pick(0)
		6:
			_drop(cards)
			sv.hire_card()
		7:
			cards.pick(0)
		8:
			cards.pick(0)
			cards.pick(0)
		9:
			cards.pick(cards.options.size() - 1)
			cards.pick(0)
		10:
			_drop(cards)
			c.day = 9
			sv.fire_retention("counter", "Maya")
		11:
			_drop(cards)
			sv.apply_design("pods", true)
			_drop(cards)
			var r: Dictionary = c.make_report()
			sv.close_day(r)
			r["rep"] = 61
			r["cash"] = 0
			r["total_days"] = 20
			r["fired"] = false
			r["final"] = false
			r["ending"] = ""
			root.get_node("DayReport").show_report(r)
		12:
			root.get_node("DayReport").is_open = false
			root.get_node("DayReport")._canvas.visible = false
			for i in 2:
				sv.finish_hire(crew.make_candidates(3)[0], "structured")
				crew.onboard_pending(9)
			sv.apply_design("tiered", true, false)
			_drop(cards)
			computer.open(1)
			computer.app = "dispatch"
			computer.dispatch.fuzz = 0
			computer.dispatch.view = "capacity"
		13:
			computer.dispatch.view = "board"
		_:
			quit()
			return false
	computer._canvas.queue_redraw()
	stage += 1
	return false
