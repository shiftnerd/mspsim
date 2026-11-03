extends SceneTree
# Screenshots of the sales campaign (renderer needed, `-- --format=wide|h|v`): the weekly report (a mid-quarter week and the
# quarter-closing week with a warning), the SalesHound CRM (all leads, a lead with a quote won, a finished lead), the
# lead card and the quote builder. PNGs land in user://sales_FORMAT_NAME.png.

var frame := 0
var fmt := "wide"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--format="):
			fmt = a.substr(9)
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://sales_%s_%s.png" % [fmt, name])


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var comp := root.get_node("Computer")
	var cards := root.get_node("Cards")
	var report := root.get_node("DayReport")
	var world := root.get_node("World")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			root.get_node("Difficulty").seed_run(2014)
			c.new_game("sales")
			world.clock = 9.0
		20:
			_shot("quota_card")
			cards.pick(1)
		26:
			_shot("plan_card")
			_clear(cards)
			# a few leads in different stages and a won deal
			var open: Array = sc.open_leads()
			open[0].stage = "MEETING"
			open[0].called = true
			if open.size() > 1:
				open[1].stage = "QUOTED"
			sc.leads.append({"id": 90, "name": "Calloway and Finch LLP", "type": "law", "who": "Atty. Calloway", "users": 22, "pain": "still on Windows XP", "quality": 52, "fee": 678, "site": false, "week": 1, "stage": "WON", "called": true, "visited": false, "moon": false, "why": ""})
			sc.leads.append({"id": 91, "name": "Four Paws Veterinary", "type": "vet", "who": "Dr. Whitt", "users": 9, "pain": "wifi in the kennels is a joke", "quality": 31, "fee": 366, "site": false, "week": 1, "stage": "LOST", "called": true, "visited": false, "moon": false, "why": "WENT ELSEWHERE"})
			sc.q_signed = [2350, 0]
			c.day = 7
			comp.open(1)
			comp.activate("app:crm")
		40:
			_shot("crm")
			comp.activate("crm:tab:LEAD")
		46:
			_shot("crm_lead")
			comp.activate("crm:tab:ALL")
			comp.activate("crm:sel:91")
		52:
			_shot("crm_lost")
			comp.close()
			c.day = 7
			sc.start_quote(int(sc.open_leads()[0].id))
		60:
			_shot("quote_builder")
			cards.pick(0)
			cards.pick(2)
		66:
			_shot("quote_price")
			_clear(cards)
			sc.margin_floor = 0.35
			c._base = {"score": 0, "closed": 0, "missed": 0, "reopened": 0}
			sc.week_new = 640
			sc.week_deals = 1
			sc.week_commission = 1280
			sc.commission_total = 2900
			sc.book = [{"id": 90, "name": "Calloway and Finch LLP", "type": "law", "mrr": 640, "margin": 0.5, "week": 6, "promise": "high", "gap": 1.0, "mood": 64, "complain": true, "resolved": false, "asked": true}]
			c._end_day()
		110:
			_shot("report")
			report.finish()
		130:
			c.day = 12
			sc.q_signed = [900, 0]
			c._base = {"score": 0, "closed": 0, "missed": 0, "reopened": 0}
			c._end_day()
		170:
			_shot("report_warning")
			report.finish()
		190:
			c.day = 20
			sc.q_signed = [1200, 3000]
			sc.q_result = ["MISS", ""]
			c._base = {"score": 0, "closed": 0, "missed": 0, "reopened": 0}
			c._end_day()
		230:
			_shot("report_final")
			quit()
	return false
