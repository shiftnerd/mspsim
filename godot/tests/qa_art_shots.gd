extends SceneTree
# gdlint:disable=max-line-length
# Visual QA of the art added in Nov 2026 (renderer needed, NOT --headless; set MSPSIM_TEST=1 so the window stays a window):
#   Godot --path godot --fixed-fps 60 -s res://tests/qa_art_shots.gd -- --format=h|deck|wide|v
# Env QA_SET = a comma list of the groups to shoot (default all): breakout, escape, paintball, people, decor, hats, ui.
# Env QA_OUT = the folder for the PNGs (default user://qa_art/): <group>_<name>_<format>.png. Never point it into the project.

var out_dir := "user://qa_art/"
var sets: Array = ["breakout", "escape", "paintball", "people", "decor", "hats", "ui"]
var fmt := "wide"


func _initialize() -> void:
	if OS.get_environment("QA_OUT") != "":
		out_dir = OS.get_environment("QA_OUT").replace("\\", "/")
		if not out_dir.ends_with("/"):
			out_dir += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	if OS.get_environment("QA_SET") != "":
		sets = Array(OS.get_environment("QA_SET").split(","))
	root.get_node("Campaign").save_prefix = "user://test_qaart_%d_" % OS.get_process_id()
	change_scene_to_file("res://scenes/main_floor.tscn")
	_run.call_deferred()


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _shot(name: String, keep_card := false) -> void:
	if not keep_card and root.get_node("Cards").is_open:  # a story card that opened by itself hides the room
		_drain()
		await process_frame
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("%s%s_%s.png" % [out_dir, name, fmt])
		print("saved ", name)


func _go(scene: String, spawn: String = "start") -> void:
	root.get_node("Game").go(scene, spawn)
	await _wait(1.0)


func _run() -> void:
	await _wait(0.5)
	fmt = str(root.get_node("Game").format)
	for s in sets:
		print("SET ", s)
		await call("_set_" + str(s))
	print("DONE")
	quit(0)


# ---- 1. the four breakout rooms: speaker, audience, the player in a free chair ---------------------------------------
func _set_breakout() -> void:
	var expo := root.get_node("Expo")
	var rooms := ["breakout_a", "breakout_b", "breakout_c", "breakout_d"]
	for i in rooms.size():
		expo.away = true
		expo._stage = "round"
		expo.rnd = i % 3
		expo._seen = rooms[i]
		await _go(rooms[i])
		await _wait(1.5)
		await _shot("breakout_%s_stand" % rooms[i])
		var player: Node = current_scene.get_node("Actors/Player")
		var seat: Node = expo._free_seat()
		if seat != null:
			player.global_position = seat.global_position
			seat.use(player)
			await _wait(1.6)
			await _shot("breakout_%s_sit" % rooms[i])
			# the same without the talk caption, to judge the chairs
			expo._canvas.visible = false
			await _shot("breakout_%s_sit_clean" % rooms[i])
			expo._canvas.visible = true
			var guard := 0
			while not expo.seated.is_empty() and guard < 30:
				expo.talk_skip()
				guard += 1
			await _wait(1.2)


func _free_play() -> void:
	var campaign := root.get_node("Campaign")
	campaign.new_game(campaign.FREE)
	var o := root.get_node("Outings")
	o.enabled = true
	o.use_rooms = true
	root.get_node("Difficulty").seed_run(41)


func _end_outing() -> void:
	var o := root.get_node("Outings")
	if o.is_open:
		o._finish(2)
	await _wait(0.3)
	o.close()
	await _wait(1.5)


# ---- 2. the escape room in its four themes: background, shelf, the three themed props, the clue spots ------------------
func _set_escape() -> void:
	var o := root.get_node("Outings")
	for th in ["study", "server", "detective", "lab"]:
		_free_play()
		o.start("escape", false, {} if th == "study" else {"theme": th})
		await _wait(3.0)
		o.press(KEY_ENTER)
		await _wait(1.5)
		await _shot("escape_%s_room" % th)
		var fx_root: Node = current_scene.get_node_or_null("Fx")
		if fx_root != null:
			for n in ["Board", "WallClock", "Painting", "Shelf", "Keypad"]:
				var fx: Node = fx_root.get_node_or_null(n)
				if fx != null and fx.has_method("play"):
					fx.play()
		var player: Node = current_scene.get_node("Actors/Player")
		player.global_position.x = 60.0
		await _wait(1.0)
		await _shot("escape_%s_left" % th)
		player.global_position.x = 250.0
		await _wait(1.0)
		await _shot("escape_%s_right" % th)
		await _end_outing()
		# the same room with nobody but you in it: the props, the floor line, the clue spots
		_free_play()
		var alone := {"party": []}
		if th != "study":
			alone["theme"] = th
		o.start("escape", false, alone)
		await _wait(3.0)
		o.press(KEY_ENTER)
		await _wait(1.0)
		current_scene.get_node("Actors/Player").global_position.x = 160.0
		await _wait(0.6)
		await _shot("escape_%s_alone" % th)
		# and without the HUD strip, to judge where the props stand
		var hidden := []
		for layer in root.find_children("*", "CanvasLayer", true, false):
			if layer.visible:
				layer.visible = false
				hidden.append(layer)
		await _shot("escape_%s_bare" % th)
		for layer in hidden:
			layer.visible = true
		await _end_outing()


# ---- 3. paintball, day and night: six players, cover, flags -------------------------------------------------------------
func _set_paintball() -> void:
	var o := root.get_node("Outings")
	for night in [false, true]:
		var tag := "night" if night else "day"
		_free_play()
		o.start("paintball", false, {"night": night})
		await _wait(3.0)
		o.press(KEY_ENTER)
		await _wait(1.0)
		await _shot("paintball_%s_start" % tag)
		o.g.rules.you_auto = true
		for k in 3:
			await _wait(4.0)
			await _shot("paintball_%s_play%d" % [tag, k])
		await _end_outing()


func _drain() -> void:
	var cards := root.get_node("Cards")
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


func _campaign(mode: String, year: int, day: int) -> void:
	var c := root.get_node("Campaign")
	root.get_node("Game").ui_open = false
	c.new_game(mode)
	_drain()
	root.get_node("Msp").enabled = false
	c.year = year
	c.day = day
	root.get_node("World").apply_roster()
	root.get_node("World").clock = 10.5


func _npc(role: String) -> Node:
	for n in get_nodes_in_group("npcs"):
		if str(n.get("role")) == role or str(n.get("cast_name")) == role or str(n.get("character")) == role:
			return n
	return null


func _player_to(x: float) -> void:
	var p: Node = current_scene.get_node_or_null("Actors/Player")
	if p != null:
		p.global_position.x = x
	await _wait(0.8)


# ---- 4. the Year 3 people and the forum regulars -----------------------------------------------------------------------
func _set_people() -> void:
	var y := root.get_node("Yeartwo")
	var w := root.get_node("World")
	_campaign("tech", 3, 2)
	await _go("conference")
	await _wait(2.0)
	var q := _npc("Quinn")
	print("Quinn in conference: ", q != null)
	if q != null:
		await _player_to(q.global_position.x - 40.0)
	await _shot("people_quinn_seated")
	y.beat("newhire")
	await _wait(0.5)
	await _shot("people_quinn_card", true)
	_drain()
	await _go("main_floor")
	for k in 4:
		await _wait(3.0)
		q = _npc("Quinn")
		if q != null:
			await _player_to(q.global_position.x - 36.0)
			await _shot("people_quinn_floor%d" % k)
	if q == null:
		print("Quinn never reached the main floor")
	var days: Dictionary = y.year_cfg("beats")
	for spec in [["owner", "summit", "visitor:buyer", "ross"], ["service", "terry", "visitor:headhunter", "terry"]]:
		_campaign(spec[0], 3, int(days[spec[0]][spec[1]]))
		await _go("main_floor")
		for k in 3:
			await _wait(4.0 if k > 0 else 1.0)
			var v := _npc(spec[2])
			if v == null:
				print("no ", spec[2])
				break
			await _player_to(v.global_position.x + (40.0 if k == 0 else -36.0))
			await _shot("people_%s%d" % [spec[3], k])
		_drain()
	# the forum regulars at the venue
	var expo := root.get_node("Expo")
	_campaign("tech", 1, 12)
	for room in expo.CROWD:
		for entry in expo.CROWD[room]:
			if not (str(entry.who) in ["expo_walt", "expo_tony", "expo_dot"]):
				continue
			expo.away = true
			expo._stage = "round"
			expo._seen = room
			await _go(room)
			await _wait(1.0)
			var n := _npc(str(entry.who))
			if n != null:
				await _player_to(n.global_position.x - 34.0)
			await _shot("people_%s" % str(entry.who))
	expo.away = false
	w.clock = 10.0


# ---- 5. decor, seasons, the dinner guest, the warehouse floor paint, Jen's headset, the Dispatch star -------------------
func _set_decor() -> void:
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	_campaign("tech", 1, 5)
	root.get_node("Story").flags["decor"] = ["plant", "rug", "certificate", "trophy", "fish", "neon", "trophies"]
	await _go("main_floor")
	var x0 := float(root.get_node("World").DATA.SCENES["main_floor"].x0)
	for day in [5, 3, 7, 9, 17]:
		c.day = day
		await _wait(1.2)
		for at in [70.0, 200.0, 320.0]:
			await _player_to(x0 + at)
			await _shot("decor_day%d_x%d" % [day, int(at)])
			if fmt == "wide":
				break
	# Jen's desk
	await _go("cubicle_two")
	var jen := _npc("Jen")
	print("Jen: ", jen != null, " in the cast: ", root.get_node("World").chars.has("Jen"), " ", root.get_node("World").chars.get("Jen", {}).get("scene", "?"))
	if jen != null:
		await _player_to(jen.global_position.x - 40.0)
	await _shot("decor_jen_desk")
	# the dinner with a guest
	_free_play()
	o.start("dinner", false, {"guest": 0, "variety": true, "party": ["Alan", "Garrison", "Dan"]})
	await _wait(3.0)
	o.press(KEY_ENTER)
	await _wait(1.0)
	var seat: Node = current_scene.get_node_or_null("Interactables/Seat2")
	var p: Node = current_scene.get_node("Actors/Player")
	if seat != null:
		p.global_position = seat.global_position
		p.sit(seat)
	await _wait(1.5)
	await _shot("decor_dinner_order")
	var guard := 0
	print("dinner guest: ", o.dinner_guest(), " ordering ", o.dinner_ordering(), " game ", o.game, " phase ", o.phase, " g ", o.g.keys())
	while o.is_open and o.dinner_ordering() and guard < 12:
		o.press(KEY_ENTER)
		await _wait(0.4)
		guard += 1
	await _wait(1.0)
	await _shot("decor_dinner_plates")
	print("ordering ", o.dinner_ordering(), " tries ", guard)
	await _end_outing()
	# the warehouse: the chair fight ring and the gauntlet's finish line
	for event in ["fight", "gauntlet", "straight"]:
		_free_play()
		o.chair_event = event
		o.start("chair", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"], "event": event})
		await _wait(3.0)
		await _shot("decor_chair_%s_intro" % event)
		o.press(KEY_ENTER)
		await _wait(4.5)
		await _shot("decor_chair_%s_play" % event)
		if event != "fight" and o.g.has("race"):
			o.g.race.pos = float(o.g.race.length) - 70.0
			o.tick(0.05)
			await _wait(0.3)
			await _shot("decor_chair_%s_finish" % event)
		await _end_outing()
	o.chair_event = "straight"
	# Dispatch: chips with the asked-for star
	load("res://scripts/player.gd").current_character = "office_dan"
	_campaign("service", 1, 8)
	var msp := root.get_node("Msp")
	var sv := root.get_node("Service")
	var computer := root.get_node("Computer")
	msp.tickets.clear()
	sv.auto = "off"
	var ids := []
	var fixes := ["av", "reboot", "spooler", "restore", "password", "clear_temp"]
	for k in fixes.size():
		for ep in msp.endpoints:
			ep.problem = ""
		var t: Dictionary = msp.create_ticket(k % 3, 0, "email")
		if t.is_empty():
			continue
		t.fix = fixes[k]
		t.pri = 1 + k % 4
		t.sla_total = 300.0
		t.sla_left = 40.0 + 40.0 * k
		if k % 2 == 0:
			t["asked_tech"] = "Maya"
		ids.append(int(t.id))
	if ids.size() >= 4:
		sv.assign(ids[0], "Maya", false)
		sv.assign(ids[1], "Maya", false)
		sv.assign(ids[2], "Sam", false)
	computer.open(1)
	computer.app = "dispatch"
	await _wait(1.0)
	await _shot("decor_dispatch_star")
	computer.close()
	load("res://scripts/player.gd").current_character = "office_intern"


# ---- 6. hats and the other accessories ---------------------------------------------------------------------------------
const HAT_POSES := [["idle", 0], ["walk", 2], ["sit", 0], ["type", 1], ["death", 99]]
const HAT_HAIR := ["side", "long", "bald"]


func _strip(name: String, looks: Array, zoom: int, poses: Array = HAT_POSES, sides: Array = ["right", "left"]) -> void:
	var look := root.get_node("Look")
	var cw := 64
	var ch := 88
	var vp := SubViewport.new()
	vp.size = Vector2i(cw * poses.size() * sides.size(), ch * looks.size())
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("8a93a8")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for r in looks.size():
		var col := 0
		for side in sides:
			for pose in poses:
				var lk: Dictionary = looks[r].duplicate(true)
				var spr := AnimatedSprite2D.new()
				spr.sprite_frames = look.frames_for(look.BASE, true, lk)
				spr.offset = Vector2(0, -40)
				spr.position = Vector2(col * cw + cw / 2.0, r * ch + ch)
				vp.add_child(spr)
				look.apply(spr, look.BASE, true, lk)
				var anim := "%s_%s" % [pose[0], side]
				spr.play(anim)
				spr.pause()
				spr.frame = mini(int(pose[1]), spr.sprite_frames.get_frame_count(anim) - 1)
				col += 1
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	img.save_png("%s%s.png" % [out_dir, name])
	print("saved ", name)
	vp.queue_free()


# the long sleeves in every walk and run frame (the dark wrist band suspect): button-down and sweater with no watch, and the polo
func _set_sleeves() -> void:
	var base := {"name": "QA", "skin": "f3b488", "hair": "9a5124", "shirt": "e8e0c8", "pants": "3a3f66", "shoes": "5a3522", "hair_style": "side"}
	var looks := []
	for shirt in ["polo", "button", "sweater"]:
		var lk: Dictionary = base.duplicate()
		lk["shirt_style"] = shirt
		lk["acc"] = {}
		looks.append(lk)
	var poses := []
	for k in 8:
		poses.append(["walk", k])
	for k in 6:
		poses.append(["run", k])
	await _strip("sleeves_right", looks, 3, poses, ["right"])
	await _strip("sleeves_left", looks, 3, poses, ["left"])


func _set_hats() -> void:
	var look := root.get_node("Look")
	var career := root.get_node("Career")
	for u in career.UNLOCKS:
		if str(u.medal) != "":
			career.earned[str(u.medal)] = true
	var base := {"name": "QA", "skin": "f3b488", "hair": "9a5124", "shirt": "4f7fd0", "pants": "3a3f66", "shoes": "5a3522"}
	if fmt == "h":  # the strips do not depend on the format: once is enough
		for hair in HAT_HAIR:
			var rows := []
			for hat in look.ACC_STYLES.hat:
				var lk: Dictionary = base.duplicate()
				lk["hair_style"] = hair
				lk["acc"] = {"hat": hat}
				rows.append(lk)
			await _strip("hats_strip_%s" % hair, rows, 2)
		var others := []
		for acc in [{"lanyard": "conference"}, {"badge": "name"}, {"watch": "silver"}, {"watch": "gold"}, {"watch": "sport"}]:
			for shirt in ["polo", "button"]:
				var lk2: Dictionary = base.duplicate()
				lk2["hair_style"] = "side"
				lk2["shirt_style"] = shirt
				lk2["acc"] = acc
				others.append(lk2)
		for shirt in ["button", "sweater"]:  # the long sleeves with no watch at all: the wrist band suspect
			var lk3: Dictionary = base.duplicate()
			lk3["hair_style"] = "side"
			lk3["shirt_style"] = shirt
			lk3["acc"] = {}
			others.append(lk3)
		await _strip("hats_strip_other", others, 2)
	# on the floor: a custom person wearing a hat, a lanyard, the sticker and a watch
	var hats: Array = look.ACC_STYLES.hat
	for k in hats.size():
		_free_play()
		look.active = true
		look.look = base.duplicate()
		look.look["hair_style"] = HAT_HAIR[k % HAT_HAIR.size()]
		look.acc = {"hat": hats[k], "lanyard": "conference", "badge": "name", "watch": ["silver", "gold", "sport"][k % 3]}
		await _go("main_floor")
		var p: Node = current_scene.get_node("Actors/Player")
		p.facing = "left" if k % 2 == 1 else "right"
		await _wait(0.6)
		await _shot("hats_floor_%s" % hats[k])
	# the creator's mirror preview
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(1.0)
	current_scene._open_menu()
	current_scene._open_select("tech_new")
	await _wait(0.7)
	var cs: Node = current_scene._select
	if cs == null:
		print("no select screen")
		return
	for k in hats.size():
		look.look = base.duplicate()
		look.look["hair_style"] = HAT_HAIR[k % HAT_HAIR.size()]
		look.acc = {"hat": hats[k], "lanyard": "conference", "badge": "name", "watch": ["silver", "gold", "sport"][k % 3]}
		cs._refresh_look()
		cs.set_pose([0, 1, 3][k % 3], true)
		await _wait(0.5)
		await _shot("hats_mirror_%s" % hats[k])
	cs.queue_free()
	current_scene._select = null
	look.active = false
	look.acc = look.default_acc()
	root.get_node("Game").title_mode = false
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(1.0)


# ---- 7. HUD art: the chair duel, an event card with its picture, the mutator icons, the camera app, pad glyphs --------
func _set_ui() -> void:
	var o := root.get_node("Outings")
	var cards := root.get_node("Cards")
	var players := root.get_node("Players")
	var glyphs: Script = load("res://scripts/pad_glyphs.gd")
	# the duel
	_free_play()
	players.enable_coop(true)
	players.join(1, 1)
	o.chair_event = "fight"
	o.start("chair", false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"], "event": "fight"})
	await _wait(3.0)
	await _shot("ui_duel_intro")
	o.press(KEY_ENTER)
	await _wait(4.5)
	if o.g.has("race") and o.g.race.get("duel") == true:
		o.g.race.chairs[0].bumps = 2
		o.g.race.chairs[1].bumps = 1
		o.g.race._say("PLAYER 1 GOT YOU! 2 TO 1", 5.0)
	else:
		print("no duel running")
	await _wait(0.3)
	await _shot("ui_duel_hud")
	glyphs.force = 1
	await _wait(0.3)
	await _shot("ui_duel_hud_pad")
	glyphs.force = -1
	await _end_outing()
	players.enable_coop(false)
	o.chair_event = "straight"
	# event cards with a picture, keyboard and pad
	_campaign("tech", 1, 4)
	await _go("main_floor")
	for pic in ["tax", "printer", "holidays", "security"]:
		glyphs.force = 1 if pic in ["printer", "security"] else -1
		cards.art_next = pic
		cards.ask("THE TONER SUPPLIER", "YOUR ORDER OF TONER FOR THREE CLIENTS IS A WEEK LATE. PRESS (A) TO PICK, (B) TO SHRUG. TWO OFFICES ARE DOWN TO THEIR LAST CARTRIDGE.", [
			{"label": "BORROW A CARTRIDGE FROM THE WAREHOUSE", "id": "a"},
			{"label": "CALL ANOTHER SUPPLIER (X) AT TWICE THE PRICE", "id": "b"},
			{"label": "WAIT ONE MORE DAY", "id": "c"},
		], func(_id: String) -> void: pass)
		await _wait(0.6)
		await _shot("ui_card_%s" % pic, true)
		_drain()
	# a HUD hint and a footer with the pad active
	glyphs.force = 1
	var hints := root.get_node("Hints")
	if hints.has_method("toast"):
		hints.toast("PRESS (A) TO SIT, (X) TO TALK, (LB) (RB) TO SWITCH, (START) FOR THE MENU, STICK TO WALK")
	await _wait(0.5)
	await _shot("ui_hint_pad")
	var computer := root.get_node("Computer")
	computer.open(1)
	await _wait(0.8)
	await _shot("ui_footer_pad")
	computer.close()
	# the phone's camera app
	var phone := root.get_node("Phone")
	phone.open()
	phone.locked = false
	phone.app = "home"
	phone._canvas.queue_redraw()
	await _wait(0.6)
	await _shot("ui_phone_home_pad")
	phone.app = "camera"
	phone.cam_view = "finder"
	phone._canvas.queue_redraw()
	await _wait(0.5)
	await _shot("ui_phone_camera_pad")
	glyphs.force = -1
	phone._canvas.queue_redraw()
	await _wait(0.3)
	await _shot("ui_phone_camera")
	phone.close()
	# the mutator icons on the character select's options page
	change_scene_to_file("res://scenes/title.tscn")
	await _wait(1.0)
	current_scene._open_menu()
	current_scene._open_select("tech_y2")
	await _wait(0.7)
	var cs: Node = current_scene._select
	if cs != null:
		root.get_node("Yeartwo").pending = true  # no finished year in this test's saves: show the MUT row anyway
		cs.step = "options"
		cs.queue_redraw()
		await _wait(0.5)
		await _shot("ui_mutators_options")
		if cs.has_method("change_mut"):
			for k in 4:
				cs.change_mut(1)
				await _wait(0.2)
				await _shot("ui_mutators_options%d" % k)
		cs.queue_free()
		current_scene._select = null
	root.get_node("Game").title_mode = false
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(1.0)
