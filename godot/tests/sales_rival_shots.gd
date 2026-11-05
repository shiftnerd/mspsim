extends SceneTree
# gdlint:disable=max-line-length
# Screenshots of the rival hooks in the CRM and the quote builder (R38 P5; renderer needed, `-- --format=wide|h|v`): a MEETING lead
# whose incumbent is known (the RIVAL line and the ASSESS button), the same lead after an honest ASSESS (the findings count), a lead
# whose incumbent is still hidden, the quote builder fields with PRESENTED AS and the gauges with the RIVAL PRICE and Alan's line
# about the flat form. PNGs land in user://rivalcrm_FORMAT_NAME.png.

var frame := 0
var fmt := "wide"
var lead_a: Dictionary = {}
var lead_b: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--format="):
			fmt = a.substr(9)
	change_scene_to_file("res://scenes/conference.tscn")


func _shot(name: String) -> void:
	root.get_node("Computer")._canvas.queue_redraw()
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://rivalcrm_%s_%s.png" % [fmt, name])


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 40:
		cards.pick(0)
		n += 1


func _lead(sc: Node, n: int, name: String, inc: String, seen: bool, stage: String) -> Dictionary:
	var l: Dictionary = sc.make_lead(root.get_node("Difficulty").rng_for("rival_shots", n))
	l.name = name
	l.users = 24
	l.fee = 726
	l.quality = 58
	l.pain = "no backup of patient files"
	l.stage = stage
	l.called = true
	l.touch = 1
	l.incumbent = inc
	l.inc_seen = seen
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
	var sr = load("res://scripts/sales_rival.gd")
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
			c.day = 7
			lead_a = _lead(sc, 1, "Marlowe Family Dental", "bigcheese", true, "MEETING")
			lead_b = _lead(sc, 2, "Harbor Smiles Dental", "bytebrothers", false, "MEETING")
			sc.crm_page = 0
			sc.crm_tab = "ALL"
			sc.crm_sel = int(lead_a.id)
			comp.open(1)
			comp.activate("app:crm")
		40:
			_shot("crm_known")
			sc.crm_sel = int(lead_b.id)
		46:
			_shot("crm_hidden")
			sc.crm_sel = int(lead_a.id)
			sr.assess(int(lead_a.id))
		52:
			cards.pick(0)
		58:
			_clear(cards)
			_shot("crm_assessed")
			comp.close()
			sc.margin_floor = 0.35
			sc.start_quote(int(lead_a.id))
			comp.open(1)
			comp.activate("app:crm")
			sc.QuoteBuilder.change("promise", 1)
			sc.QuoteBuilder.change("present", 1)
			sc.qb["row"] = 8
		76:
			_shot("builder_flat")
			sc.qb["page"] = 1
		82:
			_shot("builder_flat_gauges")
			sc.QuoteBuilder.change("present", 1)
			sc.qb["page"] = 0
		88:
			_shot("builder_tiers")
			sc.qb["page"] = 1
		94:
			_shot("builder_tiers_gauges")
			quit()
	comp._canvas.queue_redraw()
	return false
