extends SceneTree
# C5 / V2: the crew as people. Sam and Terry are real NPCs in the service campaign only (and only while they work for you),
# the five skill areas, tickets that need a level, focus and learning, plan kinds, the bubble flag, Talk, and the other modes
# staying exactly as they were. Headless.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var talk := root.get_node("Talk")
	var player_script: GDScript = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false

	# ---- the other modes do not see the techs
	player_script.current_character = "office_adult"
	c.new_game("tech")
	_clear(cards)
	_check(not world.chars.has("Sam") and not world.chars.has("Terry") and world.chars.size() == 6, "tech campaign: still the six cast members (%d)" % world.chars.size())
	_check(world.CAST.size() == 6 and world.CREW_CAST.size() == 2, "CAST is untouched, the techs live in CREW_CAST")
	c.new_game("owner")
	_clear(cards)
	_check(not world.chars.has("Sam") and not world.chars.has("Terry"), "owner campaign: no service techs")
	c.quit_to_title()

	# ---- the service campaign
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	c.new_game("service")
	_clear(cards)
	_check(world.chars.has("Sam") and world.chars.has("Terry") and world.chars.has("Maya") and not world.chars.has("Dan"), "service campaign: Maya, Sam and Terry are NPCs, Dan is you")
	_check(world.row("Sam").character == "office_teen" and world.row("Terry").character == "office_adult", "Sam and Terry reuse the teen and adult sheets")
	_check(world.row("Sam").home == "main_floor" and world.row("Sam").seat == "Seat1", "Sam has the free main floor desk")
	_check(world.row("Terry").home == "conference" and world.row("Terry").seat == "Seat6", "Terry hot-desks at the conference table")
	_check(world.chars.size() == 7, "seven people in the building (%d)" % world.chars.size())
	_check(world.chars["Sam"].scene in ["main_floor", "__outside__"] and world.chars["Terry"].scene in ["conference", "__outside__"], "they start at home or on the way in")
	_check(talk.available("Sam") and talk.available("Terry") and sv.has_one_on_one("Sam"), "you can talk to them and have a 1:1")
	crew.members["Terry"]["gone"] = true
	world.apply_roster()
	_check(not world.chars.has("Terry") and world.chars.has("Sam"), "a tech who quit leaves the building")
	crew.members["Terry"]["gone"] = false
	world.apply_roster()
	_check(world.chars.has("Terry"), "and comes back with the roster")

	# ---- areas, needs and learning
	_check(crew.AREAS.size() == 5 and crew.level("Maya", "people") == 3 and crew.level("Sam", "powershell") == 0, "five areas with roster levels")
	var t := {"fix": "restore", "pri": 1}
	_check(crew.need_of(t) == 3 and crew.area_of(t) == "security", "a P1 restore needs SECURITY 3")
	t = {"fix": "reboot", "pri": 4}
	_check(crew.need_of(t) == 1 and crew.tag_of(t) == "SRV", "a P4 reboot needs SERVERS 1")
	var sam0: float = crew.area_level("Sam", "servers")
	crew.note_done("Sam", {"fix": "reboot", "pri": 4})
	var easy: float = crew.area_level("Sam", "servers") - sam0
	sam0 = crew.area_level("Sam", "servers")
	crew.note_done("Sam", {"fix": "restore", "pri": 3})
	crew.note_done("Sam", {"fix": "reboot", "pri": 1})
	_check(easy > 0.0, "doing tickets teaches (+%.3f)" % easy)
	crew.set_focus("Sam", "networking")
	var before: float = crew.area_level("Sam", "networking")
	crew.end_day(0.7, "B")
	_check(crew.area_level("Sam", "networking") > before, "a focus trains its area every day")
	var spool := {"fix": "spooler", "pri": 3, "id": 1, "status": "New"}
	var plain: float = crew.fit("Sam", spool)
	crew.set_focus("Sam", "")
	_check(crew.fit("Sam", spool) < plain, "a focus on the ticket's area raises the fit")
	_check(crew.cycle_focus("Sam") == "powershell" and crew.cycle_focus("Sam") == "networking", "cycling a focus walks the areas")
	crew.set_focus("Sam", "")
	crew.skill_gain("Maya", 0.03)
	_check(crew.area_level("Maya", "powershell") > 1.0 or crew.area_level("Maya", "security") > 1.0, "coaching raises the weakest area")

	# ---- plan kinds, bubbles
	msp.tickets.clear()
	_check(crew.plan_kinds("Sam").count("work") < 3 and not crew.plan_kinds("Sam").has("closet"), "an idle tech wanders (%s)" % str(crew.plan_kinds("Sam")))
	for ep in msp.endpoints:
		ep.problem = ""
	var tk: Dictionary = msp.create_ticket(0, 0, "email")
	tk.fix = "spooler"
	sv.assign(int(tk.id), "Sam")
	_check(crew.status("Sam") == "WORKING" and crew.plan_kinds("Sam").count("work") >= 3 and crew.plan_kinds("Sam").has("closet"), "a working tech stays at the desk, a networking ticket sends him to the closet")
	var props := []
	for pr in load("res://scripts/npc.gd").get_script_property_list():
		props.append(str(pr.name))
	_check(props.has("flag_glyph"), "the NPC has a flag glyph for the bubble")
	crew.stuck["Sam"] = {"ticket": int(tk.id), "left": 30.0, "asked": false}
	_check(crew.glyph_of("Sam") == "?" and crew.plan_kinds("Sam") == ["work"], "a stuck tech sits and shows a ? bubble")
	crew.stuck.clear()
	_check(world.plan_for("Sam", "owner_alan").size() > 2, "a stuck tech can walk to Alan's office")

	# ---- the data
	_check(crew.names() == ["Maya", "Sam", "Terry"], "the roster")
	var d: Dictionary = crew.to_dict()
	crew.members["Terry"]["areas"]["servers"] = 3.5
	crew.from_dict(d)
	_check(absf(crew.area_level("Terry", "servers") - 2.0) < 0.001, "to_dict / from_dict round trips the areas")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
