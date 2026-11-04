extends SceneTree
# gdlint:disable=max-line-length
# Character creator level 3 step (e) (R15): the mirror preview of the create screen (poses, hold, overlays in every pose), the Free Play
# outfit swap (Y and the pause menu row, applied live to the player, Game.ui_open and the pause rules kept), presets that keep the
# accessories, and NPC copies (npc.gd custom_look, the Free Play twin) that wear the player's whole look.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/outfit.gd

const POSE_NAMES := [
	"idle", "walk", "wave", "sit", "type", "sitstretch", "sitscratch", "sitlook", "sityawn", "sitnod", "sitphone", "sitmouse", "sitslump", "toss"
]

var failures := 0
var cs_script: GDScript = null


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(2)


func _ev(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _click(at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = at
	return e


func _rect_of(cs: Node, kind: String) -> Rect2:
	for r in cs._rects:
		if r[1] == kind:
			return r[0]
	return Rect2()


# wait for the scene change and any fade (Game.busy) to be over
func _settle() -> void:
	await _wait(30)
	var n := 0
	while root.get_node("Game").busy and n < 400:
		await process_frame
		n += 1
	await _wait(5)


func _player() -> Node:
	return current_scene.get_node("Actors/Player")


func _init() -> void:
	await process_frame
	cs_script = load("res://scripts/charselect.gd")
	var look := root.get_node("Look")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	var world := root.get_node("World")
	var pm := root.get_node("PauseMenu")
	var tb := root.get_node("Toolbox")
	d.settings_path = "user://test_outfit_%d_settings.cfg" % OS.get_process_id()
	c.save_prefix = "user://test_outfit_%d_" % OS.get_process_id()
	DirAccess.remove_absolute(d.settings_path)
	game.title_mode = false
	var full := {"glasses": "round", "beard": "goatee", "hat": "beanie", "badge": "name", "lanyard": "conference", "watch": "gold", "beard_color": "", "frame_color": ""}

	# ---- the mirror preview
	look.look = look.sanitize({"name": "ZOE", "hair_style": "long", "skin": "8d5524", "hair": "e05a9a", "shirt": "2f6b3a"})
	look.acc = full.duplicate()
	var cs = cs_script.new()
	root.add_child(cs)
	cs.setup("free")
	cs.sel = 0
	cs.confirm()
	_check(cs.step == "create" and cs.is_custom(), "MAKE YOUR OWN opens the create step")
	_check(cs_script.POSES.size() == 14, "fourteen poses")
	var names := []
	for p in cs_script.POSES:
		names.append(p[0])
	_check(names == POSE_NAMES, "idle, walk, wave, sit, type, the eight seated gestures and toss, in that order")
	var spr: AnimatedSprite2D = cs._sprites[0]
	var all_there := true
	var all_gear := true
	for facing in ["right", "left"]:
		cs.facing = facing
		for i in cs_script.POSES.size():
			cs.set_pose(i)
			await process_frame
			all_there = all_there and spr.animation == StringName("%s_%s" % [POSE_NAMES[i], facing])
			var gear := spr.get_node("HeadGear")
			if not gear.visible:
				all_gear = false
			for slot in ["glasses", "beard", "hat", "badge", "lanyard", "watch"]:
				if not gear.get_node(slot).visible:
					all_gear = false
	cs.facing = "right"
	_check(all_there, "the preview plays every pose in both facings")
	_check(all_gear, "glasses, beard, hat, nametag, lanyard and watch are drawn in every pose and facing")
	var mat: ShaderMaterial = spr.material
	_check(mat != null and mat.get_shader_parameter("dst")[0] == Color.html("8d5524"), "the palette is on the preview in the poses")
	# the cycle
	cs.set_pose(0)
	cs.pose_hold = false
	cs._process(cs_script.POSE_SECS + 0.1)
	_check(cs.pose_i == 1, "the pose changes after %s seconds" % cs_script.POSE_SECS)
	cs._process(0.5)
	_check(cs.pose_i == 1, "and not before")
	var seen := {}
	for i in 14:
		seen[cs.pose_i] = true
		cs._process(cs_script.POSE_SECS + 0.1)
	_check(seen.size() == 14 and cs.pose_i == 1, "the cycle visits all fourteen and wraps")
	# hold
	cs._unhandled_input(_ev(KEY_TAB))
	_check(cs.pose_hold, "TAB holds the pose")
	var held: int = cs.pose_i
	cs._process(10.0)
	_check(cs.pose_i == held, "a held pose stays")
	cs.create_row = 0  # the NAME row: TAB still works, letters still type
	cs._unhandled_input(_ev(KEY_TAB))
	_check(not cs.pose_hold, "TAB again lets it cycle, also on the NAME row")
	cs._unhandled_input(_ev(KEY_PERIOD))
	_check(cs.pose_i == held + 1 and cs.pose_hold, "the period steps to the next pose and holds it")
	cs._unhandled_input(_ev(KEY_COMMA))
	cs._unhandled_input(_ev(KEY_COMMA))
	_check(cs.pose_i == held - 1 and cs.pose_hold, "the comma steps back")
	var before_name: String = look.look.name
	var ev_t := _ev(KEY_T)
	ev_t.unicode = "T".unicode_at(0)
	cs._unhandled_input(ev_t)
	_check(look.look.name == (before_name + "T").left(look.MAX_NAME) and cs.pose_hold, "a letter on the NAME row still types")
	look.look["name"] = "ZOE"
	# a gesture that has finished plays again
	cs.set_pose(5, true)
	spr.stop()
	cs._process(0.1)
	_check(spr.is_playing() and spr.animation == &"sitstretch_right", "a finished seated gesture replays while held")
	# mouse
	cs.queue_redraw()
	await _wait(2)
	var person := _rect_of(cs, "pose")
	var left := _rect_of(cs, "pose_prev")
	var right := _rect_of(cs, "pose_next")
	_check(person.size.x > 0.0 and left.size.x > 0.0 and right.size.x > 0.0, "the preview and its two arrows are clickable rects")
	cs.pose_hold = false
	cs._unhandled_input(_click(person.get_center()))
	_check(cs.pose_hold, "a click on the person holds the pose")
	var at: int = cs.pose_i
	cs._unhandled_input(_click(right.get_center()))
	cs._unhandled_input(_click(left.get_center()))
	cs._unhandled_input(_click(left.get_center()))
	_check(cs.pose_i == posmod(at - 1, 14), "a click on the arrows steps the pose")
	# the pad
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	pad.pressed = true
	cs.pose_hold = false
	cs._unhandled_input(pad)
	_check(cs.pose_hold, "the pad's Y holds the pose")
	cs.pose_hold = false
	# presets keep the accessories
	cs.queue_free()
	look.look = look.sanitize({"name": "ZOE", "shirt": "2f6b3a"})
	look.acc = full.duplicate()
	look.acc["hat"] = ""
	look.acc["glasses"] = "aviator"
	look.save_preset(0)
	_check(look.preset(0).acc.glasses == "aviator" and look.preset(0).acc.watch == "gold", "a preset keeps the accessories")
	look.acc = look.default_acc()
	_check(look.load_preset(0) and look.acc.glasses == "aviator" and look.acc.badge == "name" and look.look.name == "ZOE", "loading a preset wears its accessories")
	_check(not look.look.has("acc"), "Look.look itself never holds acc")
	var cfg := ConfigFile.new()
	_check(cfg.load(d.settings_path) == OK and (cfg.get_value("looks", "slot1", {}) as Dictionary).get("acc", {}).get("glasses", "") == "aviator", "the settings file stores the preset's acc")
	look.load_presets()
	_check(look.preset(0).acc.glasses == "aviator", "and it survives a reload")
	look.presets[1] = look.sanitize({"name": "OLD"})  # an old preset: no acc at all
	look.acc = full.duplicate()
	_check(look.load_preset(1) and look.acc == look.default_acc(), "an old preset (no acc) loads with none")
	look.presets[2] = look.sanitize_preset({"name": "HARD", "acc": {"hat": "hardhat", "glasses": "thin"}})
	look.acc = look.default_acc()
	look.load_preset(2)
	_check(look.acc.hat == "" and look.acc.glasses == "thin", "a locked hat in a preset becomes none")
	look.presets = [{}, {}, {}]

	# ---- NPC copies (custom_look)
	look.look = look.sanitize({"name": "ZOE", "hair_style": "curly", "skin": "8d5524", "shirt": "2f6b3a"})
	look.acc = full.duplicate()
	var copy: Dictionary = look.copy_look()
	_check(copy.acc.glasses == "round" and copy.acc.hat == "beanie" and copy.hair_style == "curly" and copy.name == "ZOE", "copy_look holds the look and the accessories")
	copy = look.copy_look({"shirt": "f4f2ea", "acc": {"glasses": "thin"}})
	_check(copy.shirt == "f4f2ea" and copy.acc.glasses == "thin" and copy.acc.hat == "", "copy_look takes overrides (acc replaced whole)")
	_check(look.sheet_for(look.BASE, true, look.copy_look()) == "custom_intern_short", "a copy in a hat wears the hat's hair sheet")
	look.acc["hat"] = ""

	# ---- Free Play: the room
	c.new_game("free")
	world.time_scale = 1.0
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle()
	var who := _player()
	look.acc = look.default_acc()
	look.look = look.sanitize({"name": "ZOE", "skin": "8d5524"})
	look.active = false
	who._switch_character("office_adult")
	await _wait(2)
	_check(c.mode == "free" and not c.active and who.current_character == "office_adult", "Free Play with a stock person")

	look.active = true
	look.look = look.sanitize({"name": "ZOE", "hair_style": "bob", "skin": "8d5524", "shirt": "2f6b3a"})
	look.acc = full.duplicate()

	# ---- the outfit swap, key Y
	_check(tb.can_outfit() and not tb.outfit_open, "Y is available in Free Play")
	await _key(KEY_Y)
	_check(tb.outfit_open and game.ui_open, "Y opens the overlay and holds the player (Game.ui_open)")
	var ov: Node = tb._outfit
	_check(ov != null and ov.overlay and ov.step == "create" and ov.is_custom(), "it is the create step alone")
	_check(who.current_character == look.BASE and look.is_custom(), "the player wears the custom person right away")
	await _key(KEY_PAUSE)
	_check(not pm.is_open and not paused, "the Pause key does not open the menu over it")
	await _key(KEY_ESCAPE)
	_check(not tb.outfit_open and not game.ui_open, "Esc closes it and gives Game.ui_open back")
	_check(who.current_character == "office_adult" and not look.active, "and puts the stock person back")
	_check(look.acc.glasses == "round" and look.look.skin == "8d5524", "and the look as it was")
	# edit live, Esc restores
	look.acc = look.default_acc()
	look.look = look.sanitize({"name": "ZOE", "skin": "8d5524", "shirt": "2f6b3a"})
	look.active = true
	who.wear_look()
	await _wait(2)
	await _key(KEY_Y)
	ov = tb._outfit
	ov.set_page(3)
	ov.create_row = 0
	await _key(KEY_RIGHT)
	_check(look.acc.glasses == "thin", "Right on GLASSES in the overlay changes the look")
	await _wait(2)
	var pg = who.sprite.get_node("HeadGear")
	_check(pg.get_node("glasses").visible and (pg.get_node("glasses").material as ShaderMaterial) != null, "the player's HeadGear shows the new glasses live")
	ov.set_page(0)
	ov.create_row = 2
	await _key(KEY_RIGHT)
	_check((who.sprite.material as ShaderMaterial).get_shader_parameter("dst")[0] != Color.html("8d5524"), "a new skin colour reaches the player's material live")
	await _key(KEY_ESCAPE)
	_check(look.acc.glasses == "" and look.look.skin == "8d5524" and not tb.outfit_open, "Esc undoes the changes")
	_check((who.sprite.material as ShaderMaterial).get_shader_parameter("dst")[0] == Color.html("8d5524"), "and the player wears the old colours again")
	# DONE keeps it
	await _key(KEY_Y)
	ov = tb._outfit
	ov.set_page(3)
	ov.create_row = 2
	await _key(KEY_RIGHT)
	_check(look.acc.hat != "", "a hat picked")
	ov.create_row = ov._page_rows().size()
	ov.create_col = 2
	await _key(KEY_ENTER)
	_check(not tb.outfit_open and not game.ui_open, "DONE closes the overlay")
	var hat: String = look.acc.hat
	var pg2 = who.sprite.get_node("HeadGear")
	_check(who.current_character == look.BASE and look.is_custom() and pg2.get_node("hat").visible, "the player keeps the new look with its hat")
	var cfg2 := ConfigFile.new()
	_check(cfg2.load(d.settings_path) == OK and (cfg2.get_value("look", "acc", {}) as Dictionary).get("hat", "") == hat, "it is saved in the settings file")
	# a stock person who keeps the look
	look.active = false
	who._switch_character("office_adult")
	await _wait(2)
	await _key(KEY_Y)
	ov = tb._outfit
	ov.create_row = ov._page_rows().size()
	ov.create_col = 2
	await _key(KEY_ENTER)
	_check(who.current_character == look.BASE and look.is_custom(), "DONE as a stock person makes you the custom person")

	# ---- the pause menu rows
	await _key(KEY_ESCAPE)
	_check(pm.is_open and paused, "Esc opens the pause menu in Free Play")
	var labels: Array = pm._labels()
	_check(labels == ["RESUME", "CONTROLS", "SHAPE: %s" % game.format.to_upper(), "OUTFIT", "QUIT TO TITLE"], "Free Play rows: OUTFIT before QUIT")
	pm._sel = 3
	await _key(KEY_ENTER)
	await _wait(3)
	_check(not pm.is_open and not paused and tb.outfit_open and game.ui_open, "the OUTFIT row closes the menu and opens the overlay")
	look.acc["glasses"] = "thick"
	ov = tb._outfit
	ov.create_row = ov._page_rows().size()
	ov.create_col = 2
	await _key(KEY_ENTER)
	await _wait(3)
	await _key(KEY_ESCAPE)
	pm._sel = pm._labels().size() - 1
	_check(pm._row_id(pm._sel) == "quit", "the last row is QUIT")
	await _key(KEY_ESCAPE)
	_check(not pm.is_open, "Esc resumes")
	# campaigns have no outfit row
	c.mode = "tech"
	c.active = true
	var tech_rows: Array = pm._labels()
	_check(not "OUTFIT" in tech_rows and "DAY LENGTH" in str(tech_rows), "a campaign keeps its own rows (no OUTFIT)")
	_check(not tb.can_outfit(), "and no outfit swap")
	c.active = false
	c.mode = "free"

	DirAccess.remove_absolute(d.settings_path)
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
