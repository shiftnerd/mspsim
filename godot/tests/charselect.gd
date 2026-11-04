extends SceneTree
# gdlint:disable=duplicated-load
# The character select screen: choices per mode, moving, going back, confirming (Player character,
# Phone.os, Campaign state), the cast rule in campaigns, and Continue skipping the screen.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/charselect.gd

var player_script = null  # player.gd, loaded once autoloads exist (a preload fails here)

var frame := 0
var failures := 0
var step := 0
var wait := 0
var old_os := ""
var old_char := ""
var saved_world_cast := 0


func _initialize() -> void:
	root.get_node("Difficulty").settings_path = "user://test_cs_%d_settings.cfg" % OS.get_process_id()
	DirAccess.remove_absolute("user://test_cs_%d_settings.cfg" % OS.get_process_id())
	change_scene_to_file("res://scenes/title.tscn")


func _press(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# the new flow without the title: the creator opens directly, the START list per mode (cast rule), a ready-made person plays as the stock
# sprite until it is edited, an edit turns it into MY LOOK, the settings keep the last custom look, saved looks join the list
func _flow_checks() -> void:
	var look := root.get_node("Look")
	var diff := root.get_node("Difficulty")
	var before_look: Dictionary = look.look.duplicate()
	var before_acc: Dictionary = look.acc.duplicate()
	var before_active: bool = look.active
	look.look = look.default_look()
	look.look["name"] = "MINE"
	look.acc = look.default_acc()
	look.active = false
	look.presets = [{}, {}, {}]
	DirAccess.remove_absolute(diff.settings_path)
	var cs: Node2D = load("res://scripts/charselect.gd").new()
	var world := root.get_node("World")
	# the list per mode
	cs.setup("tech")
	_check(cs.step == "create" and cs.direct and cs.is_custom() and cs.sel == 0, "tech: opens straight in the creator on MY LOOK")
	_check(cs.ids == ["custom", "office_intern", "office_adult", "site_alan"], "tech START: MY LOOK + the non-cast people (%s)" % str(cs.ids))
	var cast_ok := true
	for n in world.CAST:
		if str(world.CAST[n].character) in cs.ids:
			cast_ok = false
	_check(cast_ok, "tech START has no cast member")
	_check(str(cs._page_rows()[0].kind) == "start" and str(cs._page_rows()[1].kind) == "name", "the START row is first on the LOOK page")
	_check(cs.start_label("custom") == "MY LOOK" and cs.start_label("site_alan") == "SITE ALAN", "START labels")
	cs.setup("free")
	_check(cs.ids.size() == 8 and cs.ids[0] == "custom", "free START: MY LOOK + all seven")
	for id in ["office_dan", "office_alan", "casual_garrison", "sales_vic", "office_adult", "office_intern", "site_alan"]:
		_check(id in cs.ids, "free START has %s" % id)
	for m in ["owner", "sales", "service"]:
		cs.setup(m)
		_check(cs.step == "char" and not cs.direct and not "custom" in cs.ids, "%s keeps its fixed people as cards (%s)" % [m, str(cs.ids)])
	_check(cs.flow() == ["char", "options", "build"], "service: card, options, build")
	# a ready-made person, unedited: the stock sprite, Look untouched
	cs.setup("free")
	cs.set_start(2)  # the ADULT
	_check(cs.stock_pick() and not cs.is_custom() and cs.current_id() == "office_adult", "ADULT: a ready-made start")
	_check(look.look.hair_style == "receding" and look.look.shirt == "8c2b40" and look.acc.beard == "full", "ADULT is also an editable look: receding hair, maroon shirt, beard")
	var spr: AnimatedSprite2D = cs._preview()
	_check(spr.sprite_frames == look.frames_for("office_adult", false) and spr.material == null, "the preview plays the original adult sprite")
	_check(cs.summary(false) == "FREE PLAY - ADULT", "the summary names the ready-made person (%s)" % cs.summary(false))
	cs.set_start(0)
	_check(cs.is_custom() and look.look.name == "MINE" and look.acc.beard == "", "MY LOOK brings the working look back")
	_check(cs._preview().material != null, "the custom preview is in the palette")
	cs.set_start(2)
	cs._refresh_look()
	_check(cs.stock_pick(), "a refresh with nothing changed keeps the stock sprite")
	var got := {}
	cs.done.connect(func(r: Dictionary) -> void: got.merge(r))
	cs.confirm()
	cs.confirm()
	_check(got.get("character", "") == "office_adult" and got.get("look", {1: 1}).is_empty(), "starting from ADULT unedited: the stock character, no look")
	var player_script = load("res://scripts/player.gd")
	_check(player_script.current_character == "office_adult" and not look.active, "Player.current_character is the stock id and Look.active is false")
	_check(look.look.name == "MINE" and look.acc.beard == "", "the settings keep the last custom look, not the ready-made one")
	# editing a ready-made person turns it into MY LOOK
	cs.setup("free")
	cs.set_start(2)
	cs.create_row = 3  # START, NAME, STYLE
	var rows: Array = cs._page_rows()
	_check(str(rows[3].id) == "skin", "row 3 is SKIN")
	cs.create_row = 2
	cs._create_change(1)  # STYLE: another hairstyle
	_check(cs.sel == 0 and cs.is_custom() and not cs.stock_pick(), "one edit turns ADULT into MY LOOK")
	_check(cs.current_id() == "office_intern", "...built on the custom base sheet")
	_check(look.look.shirt == "8c2b40" and look.look.hair_style != "receding", "...keeping the rest of the ADULT look")
	_check(cs._preview().material != null, "the preview is the palette sheet now")
	var edited_style: String = look.look.hair_style
	cs.set_start(2)
	_check(cs.stock_pick() and look.look.hair_style == "receding", "picking ADULT again starts over")
	cs.set_start(0)
	_check(look.look.hair_style == edited_style and cs.is_custom(), "MY LOOK keeps the edited look")
	cs.set_start(2)
	cs.create_row = 1
	cs._create_change(1)  # the NAME row cycles a name
	_check(cs.is_custom() and cs.sel == 0, "a changed name is an edit too")
	cs.set_start(2)
	cs.roll_look()
	_check(cs.is_custom() and cs.sel == 0, "RANDOM is an edit too")
	cs.set_start(6)  # GARRISON, then Enter on the NAME row-free page goes on as an edited look
	cs.create_row = 2
	cs._create_change(1)
	got.clear()
	cs.confirm()
	cs.confirm()
	var who: String = str(got.get("character", ""))
	_check(who == "office_intern" and got.get("look", {}).get("shirt", "") == "4f9c8e", "an edited GARRISON start runs as the custom person (%s)" % who)
	_check(look.active and player_script.current_character == "office_intern", "...with Look.active set")
	# Esc on the first page puts the working look back and leaves
	look.look = look.default_look()
	look.look["name"] = "MINE"
	look.acc = look.default_acc()
	cs.setup("tech")
	cs.set_start(1)
	var left := [false]
	cs.cancelled.connect(func() -> void: left[0] = true)
	cs.back()
	_check(left[0] and look.look.name == "MINE", "Esc on the first page leaves and restores the working look")
	# a saved look joins the list
	look.look["name"] = "SAVED1"
	look.save_preset(0)
	look.look["name"] = "MINE"
	cs.setup("free")
	_check(cs.ids.size() == 9 and cs.ids[1] == "slot1" and cs.start_label("slot1") == "SAVED1", "a saved look is a START entry (%s)" % str(cs.ids))
	cs.set_start(1)
	_check(cs.is_custom() and look.look.name == "SAVED1" and cs.current_id() == "office_intern", "a saved look is wearable and custom")
	# the outfit swap: the same list, every entry an editable look
	cs.setup_overlay()
	_check(cs.overlay and cs.ids.size() == 9 and cs.step == "create", "the outfit overlay lists the same START entries")
	cs.set_start(cs.ids.find("office_dan"))
	_check(cs.is_custom() and look.look.shirt == "3c55c0" and look.acc.glasses == "thin", "an overlay start is always a custom look (DAN: blue shirt, glasses)")
	cs.free()
	look.presets = [{}, {}, {}]
	look.look = before_look
	look.acc = before_acc
	look.active = before_active
	DirAccess.remove_absolute(diff.settings_path)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 20:
		return false
	if wait > 0:
		wait -= 1
		return false
	if player_script == null:
		player_script = load("res://scripts/player.gd")
	var campaign := root.get_node("Campaign")
	var phone := root.get_node("Phone")
	var title := current_scene
	match step:
		0:
			campaign.save_prefix = "user://test_cs_%d_" % OS.get_process_id()
			for m in ["tech", "owner"]:
				if campaign.has_save(m):
					DirAccess.remove_absolute(campaign.save_path(m))
			old_os = phone.os
			phone.save_path = "user://test_cs_%d_phone.cfg" % OS.get_process_id()
			phone.os = "ios"  # the default highlight
			old_char = player_script.current_character
			player_script.current_character = "office_adult"
			# logic without the title: which people each mode offers
			var cs: Node = load("res://scripts/charselect.gd").new()
			var free: Array = cs.choices("free")
			var tech: Array = cs.choices("tech")
			_check(
				free.size() == 7 and "sales_vic" in free, "free play offers all 7 playable people"
			)
			_check(
				tech == ["office_intern", "office_adult", "site_alan"],
				"campaigns offer only people who are not cast members"
			)
			var cast_ok := true
			for n in root.get_node("World").CAST:
				if root.get_node("World").CAST[n].character in tech:
					cast_ok = false
			_check(cast_ok, "no cast member is offered in a campaign (no NPC copy to hide)")
			_check(
				cs.choices("owner") == ["office_alan", "casual_garrison"],
				"the owner campaign offers Alan or Garrison (X2)"
			)
			cs.free()
			# the build step per mode (X7): owner goes straight from the character to the build (no phone), Free Play has none
			var os: Node = load("res://scripts/charselect.gd").new()
			os.setup("owner")
			_check(os.needs_build() and not os.needs_phone(), "owner: a build step, no phone step")
			_check(os.step == "char" and not os.direct and os.ids == ["office_alan", "casual_garrison"], "owner: the two owners as cards, not the creator")
			os.confirm()
			_check(os.step == "options", "owner: the options page comes before the build")
			os.confirm()
			_check(os.step == "build" and os._panel.who == "Alan" and os._panel.path == "owner", "owner: the build step reads Alan's bias")
			_check(os._panel.level("technical") >= 2 and os._panel.points_left() >= 0, "Alan's TECHNICAL shows its free 2")
			os.back()
			_check(os.step == "options", "Esc on the owner build step goes back to the options")
			os.back()
			_check(os.step == "char", "Esc on the options goes back to the character")
			os.move(1)
			os.confirm()
			os.confirm()
			_check(os._panel.who == "Garrison" and os._panel.level("sales") >= 2, "Garrison: the panel is rebuilt for the other owner")
			os.free()
			var fp: Node = load("res://scripts/charselect.gd").new()
			fp.setup("free")
			_check(not fp.needs_build(), "Free Play has no build step")
			_check(fp.flow() == ["create", "options"], "Free Play: the creator, then the options")
			fp.free()
			_flow_checks()
			_press(KEY_ENTER)
		1:
			_check(title._menu_open, "Enter opens the title menu")
			_press(KEY_ENTER)  # first item: TECH CAMPAIGN (new)
		2:
			var cs: Node = title._select
			_check(cs != null and cs.mode == "tech", "TECH CAMPAIGN opens the select screen")
			_check(
				cs.step == "create" and cs.direct and cs.is_custom() and cs.current_id() == "office_intern",
				"the select opens straight in the creator, on MY LOOK"
			)
			_check(cs.ids == ["custom", "office_intern", "office_adult", "site_alan"], "START lists MY LOOK and the non-cast people")
			_check(not title._started and not campaign.active, "nothing has started yet")
			_press(KEY_RIGHT)  # the START row: first ready-made person
		3:
			var cs: Node = title._select
			_check(cs.current_id() == "office_intern" and cs.stock_pick(), "Right on START picks the ready-made intern")
			_press(KEY_RIGHT)
		4:
			var cs: Node = title._select
			_check(cs.current_id() == "office_adult" and cs.stock_pick(), "Right goes on to the adult")
			_press(KEY_RIGHT)
		5:
			var cs: Node = title._select
			_check(cs.current_id() == "site_alan", "then site Alan")
			_press(KEY_RIGHT)
		6:
			var cs: Node = title._select
			_check(cs.is_custom() and cs.sel == 0, "the list wraps around to MY LOOK")
			_press(KEY_LEFT)
		7:
			var cs: Node = title._select
			_check(cs.current_id() == "site_alan", "Left goes back to site Alan")
			_press(KEY_ENTER)
		8:
			var cs: Node = title._select
			_check(cs.step == "phone" and title._select != null, "tech asks for the phone next")
			_check(
				"IFONE 5" in cs.summary() and "SITE" in cs.summary(), "the summary line names both"
			)
			_press(KEY_RIGHT)
		9:
			var cs: Node = title._select
			_check(cs.phone_sel == 1 and "NEXXUS 5" in cs.summary(), "the phone can be changed")
			_check(
				root.get_node("Difficulty").tier == "normal" and cs.summary().ends_with("NORMAL"),
				"the summary line ends with the difficulty (normal by default)"
			)
			_press(KEY_ENTER)
		10:
			var cs: Node = title._select
			_check(cs.step == "options" and cs.options_rows()[0].id == "level", "the phone leads to the options page, LEVEL first")
			_press(KEY_RIGHT)  # harder
		11:
			var cs: Node = title._select
			var diff := root.get_node("Difficulty")
			_check(diff.tier == "hard" and cs.summary().ends_with("HARD"), "Right on LEVEL makes it harder")
			var cfg := ConfigFile.new()
			cfg.load("user://test_cs_%d_settings.cfg" % OS.get_process_id())
			_check(
				cfg.get_value("difficulty", "tier", "") == "hard",
				"the choice is saved in the settings"
			)
			_press(KEY_LEFT)
			_press(KEY_LEFT)  # hard -> normal -> easy
			_press(KEY_RIGHT)  # ... -> normal
			_press(KEY_ESCAPE)
		12:
			var cs: Node = title._select
			_check(cs.step == "phone", "Esc on the options goes back to the phone")
			_press(KEY_ESCAPE)
		13:
			var cs: Node = title._select
			_check(cs.step == "create" and cs.current_id() == "site_alan", "Esc on the phone goes back to the creator")
			_press(KEY_ESCAPE)
		14:
			_check(title._select == null and title._menu_open, "Esc on the first page: title menu")
			_press(KEY_ENTER)  # open the select again
		15:
			var cs: Node = title._select
			_check(cs != null and cs.step == "create" and cs.is_custom(), "the menu still works after going back")
			_press(KEY_RIGHT)  # MY LOOK -> intern
		16:
			_press(KEY_ENTER)
		17:
			_press(KEY_RIGHT)  # nexus
		18:
			_press(KEY_ENTER)  # options
		19:
			_press(KEY_ENTER)  # build
		20:
			var cs: Node = title._select
			var build := root.get_node("Build")
			_check(cs.step == "build" and cs._panel != null, "the phone step leads to the build step (X7)")
			_check(cs._panel.path == "tech" and cs._panel.who == "", "tech build step: the five Skills, no bias")
			_check(
				cs._panel.name_text() == "GENERALIST" and "GENERALIST" in cs.summary(),
				"it starts on a preset and the summary line names it"
			)
			_check(cs._panel.valid() and cs._panel.points_left() >= 0, "the starting preset is valid")
			_press(KEY_P)  # next preset
			_press(KEY_DOWN)  # row 1: networking
			_press(KEY_LEFT)  # -1 networking
		21:
			var cs: Node = title._select
			_check(cs._panel.row == 1, "Down moves to the next row")
			_check(cs._panel.name_text() == "CUSTOM", "P picked SCRIPTER and the edit made it CUSTOM (%s)" % cs._panel.name_text())
			_check(cs._panel.level("networking") == 0 and cs._panel.level("powershell") == 4, "Left took a level off NETWORKING")
			_press(KEY_ESCAPE)
		22:
			var cs: Node = title._select
			_check(cs.step == "options", "Esc on the build step goes back to the options")
			_press(KEY_ENTER)
		23:
			var cs: Node = title._select
			_check(cs.step == "build" and cs._panel.level("networking") == 0, "Enter on the options returns to the build, edits kept")
			cs._panel.b = root.get_node("Build").new_build("normal")
			cs._panel.set_level("powershell", 4)
			cs._panel.set_level("networking", 4)
			_check(cs._panel.level("networking") == 0 and cs._panel.note != "", "a second stat at 4 is refused with a note (%s)" % cs._panel.note)
			cs._panel.set_level("powershell", 3)
			cs._panel.set_level("security", 3)
			cs._panel.set_level("servers", 3)
			cs._panel.set_level("people", 3)
			_check(cs._panel.level("people") == 0 and cs._panel.points_left() == 0, "the budget is enforced while buying (0 left)")
			cs.confirm()
		24:
			_check(title._started and campaign.active and campaign.mode == "tech", "tech started")
			_check(
				root.get_node("Difficulty").tier == "normal", "the run starts on the chosen tier"
			)
			_check(
				(
					root.get_node("Hints").toast_text.contains("NORMAL")
					and root.get_node("Hints").toast_text.contains("RUN ")
				),
				"the start toast shows the tier and the run seed"
			)
			_check(
				player_script.current_character == "office_intern",
				"the chosen character is the player"
			)
			_check(not root.get_node("Look").active, "the ready-made intern left unedited plays the stock sprite (Look.active false)")
			_check(phone.os == "android", "the phone preference is set (Nexxus 5)")
			_check(
				campaign.build.stats.get("powershell", 0) == 3 and root.get_node("Skills").ps_level == 3,
				"the chosen build reaches the game: PowerShell 3 on day 1"
			)
			_check(root.get_node("Build").pending.is_empty(), "the pending build was taken")
			var world := root.get_node("World")
			_check(
				world.chars.has("Alan") and world.chars.has("Dan"),
				"the whole team is still the cast"
			)
			campaign.save()
			wait = 60
		25:
			var cfg := ConfigFile.new()
			cfg.load(campaign.save_path("tech"))
			_check(
				cfg.get_value("campaign", "character", "") == "office_intern", "saved with the run"
			)
			# an old save has no character: Continue defaults to the adult
			cfg.erase_section_key("campaign", "character")
			cfg.save(campaign.save_path("tech"))
			player_script.current_character = "site_alan"
			_check(campaign.continue_game("tech"), "an old save still loads")
			_check(
				player_script.current_character == "office_adult", "old saves default to the adult"
			)
			cfg.set_value("campaign", "character", "casual_garrison")
			cfg.save(campaign.save_path("tech"))
			campaign.continue_game("tech")
			_check(
				player_script.current_character == "casual_garrison",
				"Continue restores the character"
			)
			# back to the title for the free play + continue checks
			campaign.active = false
			campaign.mode = ""
			root.get_node("Game").title_mode = true
			root.get_node("World").time_scale = 0.0
			change_scene_to_file("res://scenes/title.tscn")
			wait = 40
		26:
			_press(KEY_ENTER)
		27:
			# the tech submenu has CONTINUE first: choosing it must not open the select screen
			_check(title._items[0].id == "tech", "the top menu starts with TECH CAMPAIGN")
			title._choose(0)
			_check(title._items[0].id == "tech_slot1", "its submenu offers the saved slot")
			_press(KEY_ENTER)
		28:
			_check(title._select == null and title._started, "Continue skips the select screen")
			_check(
				campaign.active and player_script.current_character == "casual_garrison",
				"Continue uses the saved character"
			)
			campaign.active = false
			campaign.mode = ""
			DirAccess.remove_absolute(campaign.save_path("tech"))
			wait = 90  # let the scene change to the main floor finish first
		29:
			root.get_node("Game").title_mode = true
			root.get_node("World").time_scale = 0.0
			change_scene_to_file("res://scenes/title.tscn")
			wait = 40
		30:
			_press(KEY_ENTER)
		31:
			title._sel = title._items.size() - 2  # CAREER is the last entry
			_check(title._items[title._sel].id == "free", "FREE PLAY is the item before CAREER")
			_press(KEY_ENTER)
		32:
			var cs: Node = title._select
			_check(
				cs != null and cs.mode == "free" and cs.ids.size() == 8, "free play offers all 7 plus MY LOOK in START"
			)
			_check(cs.step == "create" and cs._pages().size() == 5, "Free Play opens the create step with five pages")
			_check(not cs.needs_phone() and "SALES" != cs.summary(), "no phone step in free play")
			cs.set_page(1)
			_check(cs._page_rows()[2].id == "pattern" and cs._page_rows().size() == 5, "the CLOTHES page has its five rows")
			cs.open_presets()
			_check(cs.create_modal == "presets", "the presets chooser opens")
			cs.back()
			_check(cs.create_modal == "" and cs.step == "create", "Back closes the chooser first")
			cs.set_page(0)
			cs.set_start(7)
			_check(cs.current_id() == "sales_vic" and cs.stock_pick(), "Vic is the 7th START entry")
			cs.confirm()
			_check(cs.step == "options", "Enter on the creator goes to the options")
			cs.confirm()
		33:
			_check(title._started and not campaign.active, "free play started without a campaign")
			_check(player_script.current_character == "sales_vic", "playing as Vic")
			phone.set_os(old_os)
			player_script.current_character = old_char
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	step += 1
	wait = 5
	return false
