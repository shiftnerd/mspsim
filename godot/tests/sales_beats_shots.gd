extends SceneTree
# gdlint:disable=class-variable-name
# Screenshots of the sales story beats (C3; renderer needed, `-- --format=wide|h|v`): the logo decision (Garrison, Alan, your pick),
# the ByteBrothers offer, the audit card, the business review in the stand-in client office, and the review page with the roll-up
# ending. PNGs land in user://beats_FORMAT_NAME.png.

var frame := 0
var fmt := "wide"
var SB: GDScript


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--format="):
			fmt = a.substr(9)
	change_scene_to_file("res://scenes/conference.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://beats_%s_%s.png" % [fmt, name])


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(cards.options.size() - 1)
		n += 1


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var onsite := root.get_node("Onsite")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			root.get_node("Difficulty").seed_run(2014)
			SB = load("res://scripts/sales_beats.gd")
			c.new_game("sales")
			world.clock = 9.0
		20:
			_clear(cards)
			sc.leads = []
			sc.book = []
			c.day = 15
			SB.week(15)
		32:
			_shot("logo_garrison")
			cards.pick(0)
		40:
			_shot("logo_alan")
			cards.pick(0)
		48:
			_shot("logo_pick")
			_clear(cards)
			sc.book.clear()
			c.day = 18
			sc.wins = 4
			SB.week(18)
		60:
			_shot("recruit")
			_clear(cards)
			c.day = 19
			sc.clawbacks = 1
			sc.churned = [{"name": "Gone Co", "week": 4, "left": 9, "mrr": 500, "claw": 500, "why": "x"}]
			SB.week(19)
		72:
			_shot("diligence")
			_clear(cards)
			c.day = 8
			world.clock = 9.0
			var e := {"id": -3, "name": "Gnarly Gnomes", "client": 2, "mrr": 750, "renew_at": 19, "kept": 0, "broken": 0, "mood": 70, "who": "Bob Gnarly"}
			sc.base_book = [e]
			sc.qbr_visit(e, false)
		170:
			_shot("qbr_office")
			onsite._meeting()
		180:
			_shot("qbr_meeting")
			cards.pick(0)
		190:
			_clear(cards)
			onsite._go_home(false)
		230:
			_clear(cards)
			sc.flags["summit"] = true
			sc.flags["dd"] = "clean"
			sc.wins = 5
			sc.q_result = ["HIT", "HIT"]
			sc.q_signed = [sc.quota_target(0) + 100, sc.quota_target(1) + 100]
			c.rep = 70
			sc.book = [{"id": 1, "name": "A", "type": "law", "who": "x", "mrr": 3000, "mood": 80, "gap": 0.0, "resolved": true, "promises": [], "state": "safe"}]
			root.get_node("Review").start()
		250:
			var rv := root.get_node("Review")
			rv.page = 2
			rv._canvas.queue_redraw()
		256:
			_shot("review_offers")
			root.get_node("Review").page = 0
			root.get_node("Review")._canvas.queue_redraw()
		262:
			_shot("review_book")
			quit()
	return false
