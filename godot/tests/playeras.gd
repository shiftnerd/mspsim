extends SceneTree
# X2 player-as-cast-member: Campaign.player_as removes the chosen cast member from World.chars (and Social.people(),
# Outings.roster(), Lync) the way Maya leaves the owner campaign; the owner campaign offers Alan or Garrison and the
# other one is the partner NPC; the choice is saved; Free Play uses the same clean removal; you start seated.

var failures := 0
var started := false


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# a randomly drawn event card owns the keyboard and blocks an outing from starting: dismiss any first
func _dismiss_cards() -> void:
	var cards := root.get_node("Cards")
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(cards.options.size() - 1)
		guard += 1


func _begin(outings: Node, id: String) -> void:
	_dismiss_cards()
	outings.start(id)


func _enter(outings: Node) -> void:
	_dismiss_cards()
	outings.press(KEY_ENTER)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _clear_cards(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(0)
		n += 1


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
	var outings := root.get_node("Outings")
	var roles := root.get_node("Roles")
	var cards := root.get_node("Cards")
	var msp := root.get_node("Msp")
	var game := root.get_node("Game")
	var report := root.get_node("DayReport")
	var player_script := load("res://scripts/player.gd")
	var cs: Node2D = load("res://scripts/charselect.gd").new()
	c.save_prefix = "user://test_%d_" % OS.get_process_id()

	# ---- the character select offers the right people per mode
	var tech: Array = cs.choices("tech")
	var owner_ids: Array = cs.choices("owner")
	var free: Array = cs.choices("free")
	_check(tech == ["office_teen", "office_adult", "site_alan"], "tech campaign: the non-cast characters")
	_check(owner_ids == ["office_alan", "casual_garrison"], "owner campaign: Alan or Garrison")
	_check(free.size() == 7, "Free Play: all seven")
	cs.setup("owner")
	var blurbs := []
	for id in owner_ids:
		blurbs.append(str(cs.info(id).blurb))
	_check("TECHNICAL OWNER" in blurbs[0] and "SALES AND CULTURE" in blurbs[1], "each owner has a one-line blurb")
	cs.free()

	# ---- the owner campaign as Alan
	player_script.current_character = "office_alan"
	c.new_game("owner")
	game.title_mode = false
	_check(c.active and c.mode == "owner" and c.player_as == "Alan", "owner campaign: player_as = Alan")
	_check(world.CAST.has("Alan"), "World.CAST is untouched")
	_check(not world.chars.has("Alan"), "Alan is removed from World.chars")
	_check(world.chars.has("Garrison"), "Garrison is the partner NPC")
	_check(world.chars.has("Maya"), "Maya is on your payroll in the owner campaign (X4)")
	_check(world.chars.has("Morgan"), "Morgan stays in the building")
	_check(not social.people().has("Alan") and social.people().has("Garrison"), "Social.people() has no Alan")
	_check(social.people().has("Maya"), "and she is one of your coworkers")
	_check(not outings.roster().has("Alan") and outings.roster().has("Garrison"), "Outings.roster() has no Alan")
	_check(not lync.contacts().has("Alan") and lync.contacts().has("Marge"), "Lync contacts: no Alan, Marge is the boss")
	var desk: Dictionary = world.player_desk()
	_check(desk.scene == "office_one" and desk.seat == "Seat1" and c.start_scene() == "office_one", "Alan's desk is Office 1")
	_check(roles.partner() == "Garrison", "the partner is Garrison")
	_check(roles.speaker("Alan (Co-owner)") == "Garrison (Co-owner)", "Alan (Co-owner) cards come from the partner")
	_check(roles.speaker("Vic") == "Vic", "other speakers are unchanged")
	cards.ask("Alan (Co-owner)", "test", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	_check(cards.speaker == "Garrison (Co-owner)", "a card that names you is spoken by the partner")
	_clear_cards(cards)
	msp.send_text("Alan", "x")
	_check(str(msp.texts[0].from) == "Garrison", "a text from you comes from the partner")

	# seated start: the first room
	game.vars["start_seated"] = true
	game.pending_spawn = "start"
	change_scene_to_file("res://scenes/office_one.tscn")
	await create_timer(0.5).timeout
	var me := current_scene.get_node("Actors/Player")
	_check(me.seat != null and me.state == "sitting", "the run starts seated at your desk")
	_check(current_scene.get_node_or_null("Actors/Alan") == null, "and there is no second Alan in the room")
	_check(not game.vars.has("start_seated"), "the seated start is used once")

	# a few weeks end to end with no script errors
	var weeks := 0
	for _w in 4:
		_clear_cards(cards)
		world.clock = world.DAY_END
		for _i in 3:
			await process_frame
		_clear_cards(cards)
		for _i in 3:
			await process_frame
		if report.is_open:
			var was: int = c.day
			report.finish()
			await create_timer(0.8).timeout
			_clear_cards(cards)
			weeks += 1 if c.day == was + 1 else 0
	_check(weeks >= 3, "the owner campaign runs week after week as Alan (%d weeks)" % weeks)
	_check(c.player_as == "Alan" and not world.chars.has("Alan"), "and you are still Alan")

	# save / continue keeps player_as
	c.save()
	c.player_as = ""
	player_script.current_character = "office_adult"
	_check(c.continue_game("owner"), "continue loads the owner save")
	_check(c.player_as == "Alan" and not world.chars.has("Alan"), "continue keeps player_as = Alan")
	# an old save (no player_as) means nobody
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("owner"))
	cfg.erase_section_key("campaign", "player_as")
	cfg.save(c.save_path("owner"))
	_check(c.continue_game("owner") and c.player_as == "Alan" and not world.chars.has("Alan"), "an old owner save plays as Alan (X4: the owner campaign is always an owner)")
	DirAccess.remove_absolute(c.save_path("owner"))

	# ---- Garrison
	player_script.current_character = "casual_garrison"
	c.new_game("owner")
	_check(c.player_as == "Garrison" and not world.chars.has("Garrison") and world.chars.has("Alan"), "as Garrison, Alan is the partner")
	_check(c.start_scene() == "office_two" and roles.partner() == "Alan", "Garrison's desk is Office 2")

	# ---- a non-cast character in the owner campaign (old behaviour), and the tech campaign
	player_script.current_character = "office_adult"
	c.new_game("owner")
	_check(c.player_as == "Alan" and not world.chars.has("Alan") and world.chars.has("Garrison"), "a non-owner pick in the owner campaign plays as Alan (X4)")
	player_script.current_character = "office_dan"
	c.new_game("tech")
	_check(c.player_as == "" and world.chars.has("Dan") and world.chars.has("Maya"), "the tech campaign never removes a cast member")
	_check(social.people().size() == 6, "tech: six coworkers")

	# ---- Free Play: the same clean removal
	c.new_game("free")
	_check(not c.active and c.player_as == "Dan", "Free Play as Dan: player_as = Dan")
	_check(not world.chars.has("Dan") and not social.people().has("Dan"), "the NPC copy is gone, not hidden")
	_check(world.chars.size() == 5 and outings.roster().size() == 5, "five coworkers remain")
	player_script.current_character = "sales_vic"
	c.refresh_free()
	_check(world.chars.has("Dan") and not world.chars.has("Vic"), "switching character brings Dan back and removes Vic")
	_check(world.chars.has("Maya"), "and Maya is still there")
	player_script.current_character = "office_teen"
	c.refresh_free()
	_check(world.chars.size() == 6 and c.player_as == "", "a non-cast character removes nobody")

	# ---- the outing games with a smaller table
	player_script.current_character = "office_dan"
	c.new_game("free")
	outings.enabled = true
	outings.use_rooms = false
	_begin(outings, "bowling")
	_enter(outings)
	_check(not outings.g.totals.has("Dan") and outings.g.totals.has("Alan"), "bowling: no Dan on the scoreboard")
	_check(outings.bowlers() == ["Alan", "Garrison"], "bowlers = the roster that bowls")
	outings.is_open = false
	_begin(outings, "dinner")
	_enter(outings)
	var total: int = outings.dinner_talk(0)
	_check(total >= 0 and total <= 6 and outings.diners() == ["Alan", "Garrison"], "dinner: two faces at the table")  # 2 points a face plus a mood point
	outings.is_open = false
	_begin(outings, "escape")
	_enter(outings)
	outings.escape_hint()
	_check(outings.g.has("code"), "escape: hints work without Dan")
	outings.is_open = false

	# restore for the other tests
	player_script.current_character = "office_adult"
	c.new_game("tech")
	_check(world.chars.size() == 6, "back to the full cast")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
