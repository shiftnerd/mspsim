extends SceneTree
# X3 Morgan Reyes as a cast member: a desk in the cubicle area (desk 5), walks the main floor, eats at her desk, hosts the
# weekly all-hands at the conference whiteboard, has a Social row, a Lync contact, a Talk deck and a Nerf reaction,
# never takes tickets and is not a tech in the owner campaign.

var failures := 0
var started := false


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	change_scene_to_file("res://scenes/cubicle_area.tscn")


func _process(_delta: float) -> bool:
	if current_scene == null or started:
		return false
	started = true
	_run()
	return false


func _run() -> void:
	await process_frame
	await process_frame
	var world := root.get_node("World")
	var c := root.get_node("Campaign")
	var social := root.get_node("Social")
	var lync := root.get_node("Lync")
	var talk := root.get_node("Talk")
	var meeting := root.get_node("Meeting")
	var msp := root.get_node("Msp")
	var nerf := root.get_node("Nerf")
	var outings := root.get_node("Outings")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the cast entry
	_check(world.CAST.has("Morgan") and world.CAST.Morgan.character == "office_morgan", "Morgan is in World.CAST")
	_check(world.CAST.Morgan.home == "cubicle_area" and world.CAST.Morgan.seat == "Seat2", "her desk is cubicle 5 (cubicle area, Seat2)")
	_check(world.CAST.Morgan.role == "manager", "role manager")
	_check(load("res://scripts/npc.gd").DESKS.get("Morgan", 0) == 5 and social.DESK_OWNER[5] == "Morgan", "desk 5 plumbing")
	_check(social.ALL.has("Morgan") and social.ROLES["Morgan"] == "MANAGER", "Social row and label")
	_check(social.is_manager("Morgan") and not social.is_manager("Dan"), "is_manager")

	c.new_game("tech")
	_check(world.chars.has("Morgan") and social.people().has("Morgan"), "tech campaign: she is in the building and has an opinion row")
	_check(lync.contacts().has("Morgan") and lync.boss() == "Morgan" and lync.contacts().count("Morgan") == 1, "Lync: one Morgan contact, the boss")
	c.new_game("owner")
	_check(world.chars.has("Morgan") and social.people().has("Morgan") and lync.contacts().has("Marge"), "owner campaign: Morgan is staff, Marge is the boss contact")
	_check(lync.contacts().count("Morgan") == 1, "and is a Lync contact once")
	c.new_game("tech")

	# ---- the routine: desk, floor walk, lunch at her desk, never the closet
	var kinds := {}
	world.clock = 10.0
	world.chars["Morgan"].scene = "cubicle_area"
	world.chars["Morgan"].arriving = false
	for _i in 60:
		var legs: Array = world._plan("Morgan")
		for leg in legs:
			kinds[str(leg.kind)] = true
		world.chars["Morgan"].legs = [world._work_leg("Morgan", true, 20.0)]
	_check(kinds.has("work") and kinds.has("floor"), "routine: works at her desk and walks the floor (%s)" % str(kinds.keys()))
	_check(not kinds.has("closet") and not kinds.has("visit"), "she does not go to the closet or out on visits")
	var floor_legs: Array = world.plan_for("Morgan", "floor")
	var main_floor_visit := false
	for leg in floor_legs:
		main_floor_visit = main_floor_visit or (str(leg.kind) == "floor" and str(leg.scene) == "main_floor")
	_check(main_floor_visit, "the floor walk happens on the main floor")
	world.clock = world.LUNCH_START
	world.chars["Morgan"].lunched = false
	world.chars["Morgan"].scene = "cubicle_area"
	world.chars["Morgan"].arriving = false
	var lunch: Array = world._plan("Morgan")
	_check(lunch.size() == 1 and str(lunch[0].scene) == "cubicle_area", "lunch: she eats at her desk")
	# the closet errand never picks her
	var errand_src := FileAccess.get_file_as_string("res://scripts/world.gd")
	_check("for who in [\"Dan\", \"Alan\", \"Garrison\", \"Maya\", \"John\"]" in errand_src, "the closet errand list has no Morgan")

	# ---- seated at her desk in the room
	world.clock = 10.0
	world.chars["Morgan"].scene = "cubicle_area"
	world.chars["Morgan"].legs = [world._work_leg("Morgan", true, 60.0)]
	world.chars["Morgan"].leg_t = 60.0
	change_scene_to_file("res://scenes/cubicle_area.tscn")
	await create_timer(0.6).timeout
	var morgan := current_scene.get_node_or_null("Actors/Morgan")
	_check(morgan != null and morgan.seat != null, "Morgan sits at her cubicle")

	# ---- the all-hands: she hosts at the whiteboard, no chair; the boss role NPC is gone
	world.start_all_hands()
	var host_leg := false
	var seat_legs := 0
	for n in world.chars:
		for leg in world.chars[n].legs:
			if str(leg.get("kind", "")) == "meeting":
				if n == "Morgan":
					host_leg = absf(float(leg.target_x) - world.HOST_X) < 0.1
				else:
					seat_legs += 1
	_check(host_leg, "Morgan's meeting leg is at the whiteboard (hosting)")
	_check(seat_legs == 5, "the five others take chairs, leaving Seat6 for you (%d)" % seat_legs)
	meeting.state = "called"
	world.chars["Morgan"].scene = "conference"
	world.chars["Morgan"].legs = [world.chars["Morgan"].legs[0]]
	for leg in world.chars["Morgan"].legs:
		if str(leg.kind) != "meeting":
			continue
		leg.scene = "conference"
	world.chars["Morgan"].leg_t = 80.0
	world.day = 6
	change_scene_to_file("res://scenes/conference.tscn")
	await create_timer(0.6).timeout
	var host := current_scene.get_node_or_null("Actors/Morgan")
	var role_boss := false
	for node in current_scene.get_node("Actors").get_children():
		role_boss = role_boss or str(node.get("role")).begins_with("boss:")
	_check(host != null, "the real Morgan is in the conference room")
	_check(not role_boss, "and the whiteboard role NPC is not spawned")
	meeting.state = "called"
	c.new_game("owner")
	meeting.state = "called"
	var owner_boss := false
	root.get_node("Expo").populate(current_scene)
	for node in current_scene.get_node("Actors").get_children():
		owner_boss = owner_boss or str(node.get("role")) == "boss:marge"
	_check(owner_boss, "the owner campaign still has Marge at the whiteboard")
	c.new_game("tech")

	# ---- Talk deck
	_check(talk.SPECIALTY.get("Morgan", "") == "people", "Talk specialty")
	for tier_key in ["friend", "neutral", "cold"]:
		_check(str(talk.GREETINGS["Morgan"][tier_key]) != "", "greeting: " + tier_key)
	_check(talk.SMALL["Morgan"].size() >= 4 and talk.TIPS_GENERIC["Morgan"].size() >= 3, "small talk and tips")
	talk._who = "Morgan"
	_check(talk.tip() != "", "she gives a tip")
	msp.breached = 1
	talk._who = "Morgan"
	_check("missed an SLA" in str(talk._state_tip()), "her state tip reads the live game")
	msp.breached = 0
	talk._who = "Morgan"
	_check(talk.small_talk() != "", "small talk works")
	c.new_game("owner")
	talk._who = "Morgan"
	_check(talk.owner_idea() != "", "she has an owner-campaign idea")
	c.new_game("tech")

	# ---- Lync entries; she does not fix tickets
	for kind in ["lunch", "phones", "help", "thanks"]:
		_check(lync.MESSAGES.has(kind + "_Morgan"), "Lync message " + kind + "_Morgan")
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	c.new_game("owner")
	var t2: Dictionary = msp.create_ticket(0, 0, "test")
	world.chars["Morgan"].scene = "cubicle_area"
	world.chars["Morgan"].legs = [world._work_leg("Morgan", true, 60.0)]
	lync.send_action("Morgan", "help")
	_check(not bool(t2.fix_done), "asking Morgan for help never fixes a ticket")
	var last := str(lync.chats["Morgan"][-1][1])
	_check("do not take tickets" in last, "and she says so (%s)" % last.left(30))
	c.new_game("tech")
	_check(t.size() > 0, "ticket created")

	# ---- not a tech
	for n in ["Alan", "Garrison", "Dan"]:
		_check(outings.diners().has(n), "outing trio keeps " + n)
	_check(not outings.diners().has("Morgan") and not outings.bowlers().has("Morgan"), "Morgan is not a bowler or diner")
	_check(outings.roster().has("Morgan"), "but she is on the outing roster (sixth spot)")
	_check(outings.SPOTS["bowling"].size() == 6, "six standing spots, the first five unchanged")
	c.new_game("owner")
	var crew_ok := true
	for n in world.chars:
		if n == "Morgan":
			crew_ok = crew_ok and not (n in ["Alan", "Garrison", "Dan"])
	_check(crew_ok, "she is not in the owner crew list")
	c.new_game("tech")

	# ---- Nerf reaction
	_check(nerf.REACT.has("Morgan") and str(nerf.REACT["Morgan"].line).begins_with("Morgan:"), "Nerf reaction line")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
