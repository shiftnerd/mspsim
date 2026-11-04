extends SceneTree
# gdlint:disable=max-line-length
# The warehouse's small interactions (fx.gd: vending_machine, chair_rack, cage, bench_pc, lamp_chain, radio, floor_fan, and the old
# tree's lights) and the dart board in the real room: every one responds to E with a toast from its table (seeded by the day),
# the vending machine hands you a soda or water (and now and then eats the quarter), the tree lights toggle and a bulb pops, none of
# the low priority ones steals E from a normal one, every line is 3x5 font safe and period correct, and a round of darts played in the
# warehouse itself (the thrower at the line, the others waiting, the live darts drawn in the board, the camera, the way home).
# Headless: `Godot --headless --fixed-fps 60 --path godot -s res://tests/warehouse_play.gd`

const PixelFont := preload("res://scripts/pixelfont.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _settle(name: String) -> void:
	var n := 0
	while (_scene_name() != name or root.get_node("Game").busy) and n < 800:
		await process_frame
		n += 1
	for i in 6:
		await process_frame


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _zone(prefix: String) -> Node:
	for z in current_scene.get_node("Interactables").get_children():
		if str(z.name).begins_with(prefix):
			return z
	return null


func _fx_of(zone: Node) -> Node:
	return zone.get_node(zone.target)


func _nearest_at(x: float) -> String:
	var p: Node = current_scene.get_node("Actors/Player")
	p.global_position = Vector2(x, 118.0)
	p._pick = null
	await _wait(0.25)
	var n: Node = p.nearest()
	return "" if n == null else str(n.name)


# the text of a toast now (Hints.toast_text), cleared first by the caller
func _toast() -> String:
	return str(root.get_node("Hints").toast_text)


func _safe(text: String) -> bool:
	for ch in text:
		if not PixelFont.GLYPHS.has(ch):
			return false
	return true


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	var campaign := root.get_node("Campaign")
	var hints := root.get_node("Hints")
	var career := root.get_node("Career")
	var d := root.get_node("Difficulty")
	var o := root.get_node("Outings")
	var world := root.get_node("World")
	var sfx := root.get_node("Sfx")
	sfx.silent = true
	campaign.save_prefix = "user://test_%d_" % OS.get_process_id()
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	game.title_mode = false
	career.reset_all()
	campaign.new_game(campaign.FREE)
	d.seed_run(1357)
	change_scene_to_file("res://scenes/warehouse.tscn")
	await _settle("warehouse")
	var room := current_scene
	var player: Node = room.get_node("Actors/Player")
	var fxc: Node = room.get_node("Fx/Radio")  # any effect node: the tables and the static state are read through it

	# ---- the zones exist, the small ones are low priority, the machine is not
	var names := {
		"vending": "Usevending_machine",
		"rack": "Usechair_rack",
		"fan": "Usefloor_fan",
		"cage": "UsePartsCage",
		"bench": "UseBenchPC",
		"lamp": "UseLampChain",
		"radio": "UseRadio",
		"tree": "UseTree",
		"board": "UseDartBoard",
	}
	var zones := {}
	for key in names:
		zones[key] = _zone(names[key])
		_check(zones[key] != null, "an E zone for the %s" % key)
	for key in ["rack", "fan", "cage", "bench", "lamp", "radio", "board"]:
		_check(zones[key] != null and zones[key].low_priority, "%s is low priority (it never steals E)" % key)
	_check(zones.vending != null and not zones.vending.low_priority and zones.tree != null and not zones.tree.low_priority, "the vending machine and the tree are normal priority")
	var kinds := {"vending": "vending_machine", "rack": "chair_rack", "fan": "floor_fan", "cage": "cage", "bench": "bench_pc", "lamp": "lamp_chain", "radio": "radio", "tree": "old_tree", "board": "dart_board"}
	for key in kinds:
		_check(_fx_of(zones[key]).kind == kinds[key], "the %s zone points at its effect (%s)" % [key, kinds[key]])
	_check(room.get_node("Actors").get_children().any(func(n: Node) -> bool: return str(n.name).begins_with("vending_machine") and n.get_node_or_null("Fx") != null), "the machine's effect sits on its sprite (y-sorted with it)")

	# ---- priority: who gets E where (the door still wins at the door, the small things win only when alone)
	var x0: float = room.get_node("Background").position.x
	var at_door := await _nearest_at(x0 + 1347.0)
	_check(at_door == "UseDoor", "E at the overhead door picks the door switch zone, not the dart board (%s)" % at_door)
	var at_vend: float = zones.vending.global_position.x
	var picked := await _nearest_at(at_vend)
	_check(picked == str(zones.vending.name), "E at the machine picks the machine (%s)" % picked)
	var picked_rack := await _nearest_at(zones.rack.global_position.x)
	_check(picked_rack == str(zones.rack.name), "E at the chair rack picks the rack (%s)" % picked_rack)
	var picked_bench := await _nearest_at(zones.bench.global_position.x)
	_check(picked_bench == str(zones.bench.name), "E at the bench PC picks the bench (%s)" % picked_bench)
	var picked_radio := await _nearest_at(zones.radio.global_position.x)
	_check(picked_radio == str(zones.radio.name), "E at the radio picks the radio (%s)" % picked_radio)
	# a normal zone a little further away beats a low priority one right at the player
	var extra: Area2D = room.get_node("Interactables/UseSwitch").duplicate()
	extra.name = "UseTemp"
	extra.low_priority = false
	room.get_node("Interactables").add_child(extra)
	extra.global_position = Vector2(zones.radio.global_position.x + 9.0, 70.0)
	await _wait(0.2)
	var with_temp := await _nearest_at(zones.radio.global_position.x)
	_check(with_temp == "UseTemp", "a normal zone 9 px away beats the low priority radio under your feet (%s)" % with_temp)
	extra.queue_free()
	await _wait(0.2)

	# ---- the vending machine: a held item, the sound, now and then the machine eats the quarter
	var vend := _fx_of(zones.vending)
	player.held = ""
	player.global_position = Vector2(at_vend, 118.0)
	var got := ""
	var presses := 0
	var ate := 0  # presses that came back empty
	while got == "" and presses < 30:
		presses += 1
		hints.toast_text = ""
		zones.vending.use(player)
		await _wait(2.0)
		if player.held != "":
			got = str(player.held)
		else:
			ate += 1
	_check(got in ["soda", "bottle"], "E at the machine gives a soda or a bottle of water after %d press(es): %s" % [presses, got])
	_check(not vend.busy, "the machine is free again after its cycle")
	sfx.played.clear()
	player.held = "coffee"
	hints.toast_text = ""
	zones.vending.use(player)
	await _wait(0.4)
	_check(_toast() == fxc.VEND_FULL and player.held == "coffee" and not vend.busy, "hands full: it says so and keeps the quarter")
	player.held = ""
	# the eaten quarter: force it, then thump
	var eaten := false
	for k in 60:
		vend._vend_owed = false
		player.held = ""
		hints.toast_text = ""
		zones.vending.use(player)
		await _wait(0.2)
		if vend._vend_ate:
			eaten = true
			_check(_toast() == fxc.VEND_ATE and vend.item == "", "it ate the quarter: the toast says press E again")
			await _wait(1.8)
			_check(player.held == "" and vend._vend_owed, "nothing came out and the machine owes you one")
			hints.toast_text = ""
			zones.vending.use(player)
			await _wait(1.6)
			_check(player.held == "soda" and _toast() == fxc.VEND_THUMP, "the second press: you thump it and a soda falls out")
			break
		await _wait(1.8)
	_check(eaten, "the machine eats a quarter now and then (within 60 presses)")
	player.held = ""
	var clunked: bool = sfx.played.has("clunk") or sfx.played.has("ui_tick")
	_check(clunked, "a coin tick and a clunk were asked for")

	# ---- the chair rack
	var rack := _fx_of(zones.rack)
	hints.toast_text = ""
	zones.rack.use(player)
	_check(fxc.RACK_LINES.has(_toast()) and rack._x_t >= 0.0 - 1.0, "E at the rack: a line about the chair (%s)" % _toast())
	hints.toast_text = ""
	zones.rack.use(player)
	_check(_toast() == fxc.RACK_AGAIN, "E again while the chair is out: it spins and stops")

	# ---- the parts cage
	var cage := _fx_of(zones.cage)
	var seen := {}
	var finds0: int = career.value("cage_finds")
	for k in 70:
		hints.toast_text = ""
		cage.play()
		seen[_toast()] = true
		if k < 2:
			_check(fxc.CAGE_LINES.has(_toast()) or fxc.CAGE_FINDS.has(_toast()), "the cage: a line from its table (%s)" % _toast())
	_check(seen.size() >= 6, "the cage has variety (%d different lines in 70 peeks)" % seen.size())
	_check(career.value("cage_finds") > finds0 and career.value("cage_finds") < finds0 + 30, "and rarely something useful turns up (%d finds)" % (career.value("cage_finds") - finds0))

	# ---- the bench PC: how far along, a second press restarts it
	var bench := _fx_of(zones.bench)
	var screen := room.get_node("Fx/BenchScreen")
	screen._img_t0 = screen._time - 73.5 / 6.0
	hints.toast_text = ""
	bench.play()
	_check(_toast().begins_with("IMG ") and _toast().contains("PERCENT"), "E at the bench PC: how far along the image is (%s)" % _toast())
	var before: int = screen.img_pct()
	bench.play()
	_check(_toast() == fxc.IMG_AGAIN and screen.img_pct() < 3, "a second press restarts the image (was %d percent, now %d)" % [before, screen.img_pct()])
	bench._x_t = -100.0
	hints.toast_text = ""
	bench.play()
	_check(_toast().begins_with("IMG "), "and a press a while later reads the bar again")

	# ---- the high bay light
	var lamp := _fx_of(zones.lamp)
	var flicker := room.get_node("Fx/FlickerLamp")
	hints.toast_text = ""
	lamp.play()
	_check(fxc.LAMP_LINES.has(_toast()) and flicker._kick_until > flicker._time, "the pull chain: a line, and the light is kicked (dark for a moment)")

	# ---- the radio: three stations and off
	var radio := _fx_of(zones.radio)
	fxc.radio_i = 0
	var heard := []
	for k in 4:
		hints.toast_text = ""
		radio.play()
		heard.append(_toast())
	var names_ok := true
	for k in 3:
		names_ok = names_ok and str(heard[k]).begins_with(str(fxc.RADIO_STATIONS[k].name))
	_check(names_ok and fxc.radio_i == 0 and str(heard[3]).contains("OFF"), "the radio cycles three stations and then off: %s" % str(heard))
	_check(fxc.RADIO_STATIONS.size() == 3, "three stations")

	# ---- the fan
	var fan := _fx_of(zones.fan)
	fxc.fan_on = false
	hints.toast_text = ""
	fan.play()
	_check(fxc.fan_on and _toast() == fxc.FAN_ON, "E turns the fan on")
	fan.play()
	_check(not fxc.fan_on and _toast() == fxc.FAN_OFF, "and off")

	# ---- the old tree: the first E is the hat, then the lights toggle and a bulb pops now and then
	var tree := _fx_of(zones.tree)
	var lights := room.get_node("Fx/TreeLights")
	fxc.tree_on = true
	fxc.tree_popped = []
	hints.toast_text = ""
	tree.play()
	_check(career.has_medal("old_tree") and _toast() == fxc.TREE_FIRST, "the first E on the tree is still the Santa hat")
	var offs := 0
	var ons := 0
	for k in 40:
		var was: bool = fxc.tree_on
		hints.toast_text = ""
		tree.play()
		if k % 3 == 1:
			continue  # every third press is one of the old remarks
		if _toast() == fxc.TREE_OFF:
			offs += 1
			if offs == 1:
				_check(not fxc.tree_on and was, "the lights go off")
		elif fxc.tree_on:
			ons += 1
	_check(offs >= 5 and ons >= 5, "E toggles the tree's lights both ways (%d off, %d on)" % [offs, ons])
	_check(fxc.tree_popped.size() >= 1 and fxc.tree_popped.size() <= fxc.TREE_BULBS.size() - 2, "a dead bulb pops now and then and it stays dead (%d popped)" % fxc.tree_popped.size())
	fxc.tree_on = false
	lights.queue_redraw()
	await process_frame
	fxc.tree_on = true

	# ---- lines: seeded by the day, 3x5 font safe, period correct, no brands
	var lamp2 := _fx_of(zones.lamp)
	lamp2._x_n = 0
	var a: String = lamp2._x_line(fxc.LAMP_LINES, "t")
	lamp2._x_n = 0
	var b: String = lamp2._x_line(fxc.LAMP_LINES, "t")
	_check(a == b, "the same day and the same press give the same line")
	var picks := {}
	for day in 12:
		campaign.day = day + 1
		lamp2._x_n = 0
		picks[lamp2._x_line(fxc.CAGE_LINES, "t")] = true
	_check(picks.size() >= 3, "another day picks other lines (%d different in 12 days)" % picks.size())
	var all: Array = []
	for list in [fxc.VEND_LINES, fxc.RACK_LINES, fxc.CAGE_LINES, fxc.CAGE_FINDS, fxc.IMG_LINES, fxc.LAMP_LINES, fxc.TREE_ON, fxc.DART_LINES]:
		all.append_array(list)
	all.append_array([fxc.VEND_WATER, fxc.VEND_ATE, fxc.VEND_THUMP, fxc.VEND_FULL, fxc.RACK_AGAIN, fxc.IMG_AGAIN, fxc.FAN_ON, fxc.FAN_OFF, fxc.TREE_OFF, fxc.TREE_POP])
	for st in fxc.RADIO_STATIONS:
		all.append(str(st.name))
		all.append_array(st.lines)
		_check(str(st.num).length() == 3, "%s: three digits for the little display" % st.name)
	var bad := []
	var banned := ["AI ", " AI", "SMARTPHONE", "IPHONE", "NETFLIX", "SPOTIFY", "TIKTOK", "CHATGPT", "WINDOWS 10", "STREAMING", "PODCAST", "COCA", "PEPSI", "SONY", "WALMART"]
	for line in all:
		var text := str(line)
		if not _safe(text) or text != text.to_upper():
			bad.append(text)
		for word in banned:
			if (" " + text + " ").contains(word):
				bad.append(text)
	_check(bad.is_empty(), "%d lines: upper case, glyphs the 3x5 font has, nothing from after 2014 and no brands %s" % [all.size(), str(bad)])
	var longest := 0
	for line in all:
		longest = maxi(longest, str(line).length())
	_check(longest <= 64, "no line is longer than 64 characters (%d)" % longest)
	campaign.day = 0

	# ---- the dart board in the room: a card in Free Play, the joke when no round can start
	o.enabled = true
	o.use_rooms = true
	var cards := root.get_node("Cards")
	var board := _fx_of(zones.board)
	cards.is_open = false
	cards._queue.clear()
	world.time_scale = 1.0
	hints.toast_text = ""
	board.play()
	_check(cards.is_open and cards.speaker == "Darts", "E at the dart board in Free Play opens the darts card")
	cards.pick(1)
	_check(not o.is_open, "NEVER MIND leaves it")
	o.enabled = false
	hints.toast_text = ""
	board.play()
	_check(not cards.is_open and fxc.DART_LINES.has(_toast()), "with outings off the board only makes a joke (%s)" % _toast())
	o.enabled = true
	cards.is_open = false
	cards._queue.clear()

	# ---- a round of darts in the warehouse itself
	d.seed_run(4321)
	o.start("darts", false, {"party": ["Alan", "Garrison"]})
	var n := 0
	while not o.is_open and n < 800:
		await process_frame
		n += 1
	await _settle("warehouse")
	room = current_scene
	player = room.get_node("Actors/Player")
	_check(o.is_open and o.room_mode() and o.phase == "intro" and o.casual_on(), "darts opens in the warehouse (casual)")
	o.press(KEY_ENTER)
	var dg: RefCounted = o.g.game
	x0 = o._x0()
	_check(absf(player.global_position.x - (x0 + o.DART_X)) < 1.0 and not game.ui_open, "you stand at the throw line")
	o.tick(0.1)
	var alan := room.get_node("Actors/Alan")
	var gar := room.get_node("Actors/Garrison")
	_check(absf(alan.global_position.x - (x0 + float(o.DART_SPOTS[0]))) < 2.0 and absf(gar.global_position.x - (x0 + float(o.DART_SPOTS[1]))) < 2.0, "Alan and Garrison wait to the left of the line")
	_check(o.blocks_interact() and o.hint().begins_with("WAIT FOR YOUR THROW"), "READY: wait for your throw")
	var fxb := room.get_node("Fx/DartBoard")
	_check(fxb._darts_game() == dg and fxb.z_index == 1, "the board's effect draws the game's darts over the panel")
	await process_frame
	await process_frame
	var cam := room.get_viewport().get_camera_2d()
	_check(cam != null and absf(cam.offset.x - o.DARTS_PAN) < 0.5 and cam.offset.y >= 0.0, "the camera is panned toward the board and lifted above the HUD (%s)" % str(cam.offset))
	o.tick(1.2)
	_check(dg.phase == "aim" and o.hint() == "E = THROW  ESC = LEAVE" and o._caption.contains("AIM"), "aim: the hint line says E = THROW")
	dg.aim_t = 1.3
	o.press(KEY_E)
	o.tick(0.1)
	_check(dg.phase == "flight" and player.state == "emote" and str(player.sprite.animation).begins_with("toss_"), "E throws: the dart flies and you toss")
	o.tick(0.5)
	_check(dg.darts_now.size() == 1 and dg.darts_now[0].who == "You", "the dart sticks in the board")
	# play the rest of the game with timing near the bull; watch the others take their turn at the line
	var seated := false
	var guard := 0
	while o.phase == "play" and guard < 9000:
		guard += 1
		if dg.phase == "aim":
			var tt := 0.9
			var best := 1e9
			while tt < 2.1:
				var dist: float = dg.reticle_at(tt).length()
				if dist < best:
					best = dist
					dg.aim_t = tt
				tt += 0.01
			o.press(KEY_E)
		o.tick(0.05)
		if guard % 60 == 0:
			await process_frame
		if dg.thrower() == "Alan" and dg.phase == "opp" and not seated:
			seated = true
			_check(absf(alan.global_position.x - (x0 + o.DART_X)) < 2.0 and absf(player.global_position.x - (x0 + float(o.DART_SPOTS[0]))) < 2.0, "Alan's turn: he steps up to the line and you wait")
	_check(seated and o.phase == "result", "a whole game reaches the result page (%d stars, %s)" % [o.stars, str(dg.totals)])
	o.press(KEY_ENTER)
	await _settle("warehouse")
	_check(not o.is_open and _scene_name() == "warehouse", "back at the board after the result: you are where you were")
	cam = current_scene.get_viewport().get_camera_2d()
	_check(cam == null or absf(cam.offset.x) < 0.5, "the camera is back to normal")
	o.use_rooms = false
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
