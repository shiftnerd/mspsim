extends SceneTree
# Screenshots of the deeper sales loop (C2; renderer needed, `-- --format=wide|h|v`): the CRM deal record of a quoted and of a won
# deal (risk meter, promises with their outcomes, notes), the quote builder (fields and gauges; in portrait both pages with a block
# from Alan), the handover cards in the conference room, the renewal card and the clawback card. PNGs land in
# user://deals_FORMAT_NAME.png.

var frame := 0
var fmt := "wide"
var lead_q: Dictionary = {}
var lead_w: Dictionary = {}
var deal: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--format="):
			fmt = a.substr(9)
	change_scene_to_file("res://scenes/conference.tscn")


func _shot(name: String) -> void:
	root.get_node("Computer")._canvas.queue_redraw()
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://deals_%s_%s.png" % [fmt, name])


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1


func _lead(sc: Node, n: int, name: String, stage: String) -> Dictionary:
	var l: Dictionary = sc.make_lead(root.get_node("Difficulty").rng_for("deals_shots", n))
	l.name = name
	l.users = 24
	l.fee = 726
	l.quality = 58
	l.pain = "no backup of patient files"
	l.stage = stage
	l.called = true
	l.touch = 1
	sc.leads.append(l)
	return l


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var comp := root.get_node("Computer")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var deals = load("res://scripts/deals.gd")
	var handover = load("res://scripts/handover.gd")
	var retention = load("res://scripts/retention.gd")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			root.get_node("Difficulty").seed_run(2014)
			c.new_game("sales")
			world.clock = 9.0
		20:
			_clear(cards)
			sc.leads = []
			sc.book = []
			c.day = 4
			lead_q = _lead(sc, 1, "Maple Street Dentistry", "QUOTED")
			lead_q.quoted_day = 3
			lead_q.quote = deals.norm({"method": "fixed", "promise": "high", "price": "list", "extras": ["backup"], "onboard": "rush", "win": 0.5})
			lead_q.promises = deals.promise_list(lead_q, lead_q.quote)
			lead_q.notes = ["WK2 CALLED", "WK3 QUOTE $836/WK, WIN 50%"]
			lead_w = _lead(sc, 2, "Calloway and Finch LLP", "QUOTED")
			var q: Dictionary = deals.norm({"method": "fixed", "promise": "high", "price": "list", "extras": ["backup", "security"], "onboard": "rush"})
			deal = sc.close_deal(lead_w, q)
			_clear(cards)
			sc.pending_handover = 0
			handover.decide(deal, 0, "kept")
			handover.decide(deal, 1, "renegotiated")
			for i in range(2, deal.promises.size()):
				handover.decide(deal, i, "dropped")
			handover.finish(deal, false)
			_clear(cards)
			sc.crm_page = 1
			sc.crm_tab = "ALL"
			sc.crm_sel = int(lead_q.id)
			comp.open(1)
			comp.activate("app:crm")
		40:
			_shot("crm_record_quoted")
			sc.crm_sel = int(lead_w.id)
		46:
			_shot("crm_record_won")
			sc.crm_page = 0
		52:
			_shot("crm_summary_won")
			comp.close()
			c.day = 4
			sc.margin_floor = 0.42
			var open_lead: Dictionary = _lead(sc, 3, "Harbor Smiles Dental", "LEAD")
			sc.start_quote(int(open_lead.id))
			comp.open(1)
			comp.activate("app:crm")
			sc.QuoteBuilder.change("promise", 1)
			sc.QuoteBuilder.change("discount", 1)
			sc.QuoteBuilder.change("discount", 1)
			sc.QuoteBuilder.change("backup", 1)
			sc.QuoteBuilder.change("onboard", -1)
			sc.qb["row"] = 2
		70:
			_shot("builder")
			sc.qb["page"] = 1
		76:
			_shot("builder_gauges")
			sc.QuoteBuilder.close()
			comp.close()
			sc.margin_floor = 0.35
			handover.start(deal)
		88:
			_shot("handover_intro")
			cards.pick(0)
		94:
			_shot("handover_promise")
			_clear(cards)
			var e: Dictionary = sc.base_book[0] if not sc.base_book.is_empty() else {"id": -1, "name": "Acme Dental", "client": 0, "mrr": 650, "who": "Dr. Patel", "mood": 70}
			retention.renewal_card(e)
		106:
			_shot("renewal")
			_clear(cards)
			deal["commission"] = 1280
			retention.leave(deal, "THE PROMISE GAP: YOU SOLD MORE THAN WE COULD DELIVER")
		118:
			_shot("clawback")
			quit()
	comp._canvas.queue_redraw()
	return false
