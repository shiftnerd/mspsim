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
			os.confirm()
			_check(os.step == "build" and os._panel.who == "Alan" and os._panel.path == "owner", "owner: the build step reads Alan's bias")
			_check(os._panel.level("technical") >= 2 and os._panel.points_left() >= 0, "Alan's TECHNICAL shows its free 2")
			os.back()
			_check(os.step == "char", "Esc on the owner build step goes back to the character")
			os.move(1)
			os.confirm()
			_check(os._panel.who == "Garrison" and os._panel.level("sales") >= 2, "Garrison: the panel is rebuilt for the other owner")
			os.free()
			var fp: Node = load("res://scripts/charselect.gd").new()
			fp.setup("free")
			_check(not fp.needs_build(), "Free Play has no build step")
			fp.free()
			_press(KEY_ENTER)
		1:
			_check(title._menu_open, "Enter opens the title menu")
			_press(KEY_ENTER)  # first item: TECH CAMPAIGN (new)
		2:
			var cs: Node = title._select
			_check(cs != null and cs.mode == "tech", "TECH CAMPAIGN opens the select screen")
			_check(
				cs.ids.size() == 4 and cs.current_id() == "office_adult", "starts on the default"
			)
			_check(not title._started and not campaign.active, "nothing has started yet")
			_press(KEY_RIGHT)
		3:
			var cs: Node = title._select
			_check(cs.current_id() == "site_alan" and cs.facing == "right", "Right moves on")
			_press(KEY_RIGHT)
		4:
			var cs: Node = title._select
			_check(cs.current_id() == "office_intern", "the row wraps around")
			_press(KEY_LEFT)
		5:
			var cs: Node = title._select
			_check(cs.current_id() == "site_alan" and cs.facing == "left", "Left goes back")
			_press(KEY_ENTER)
		6:
			var cs: Node = title._select
			_check(cs.step == "phone" and title._select != null, "tech asks for the phone next")
			_check(
				"IFONE 5" in cs.summary() and "SITE" in cs.summary(), "the summary line names both"
			)
			_press(KEY_RIGHT)
		7:
			var cs: Node = title._select
			_check(cs.phone_sel == 1 and "NEXXUS 5" in cs.summary(), "the phone can be changed")
			_check(
				root.get_node("Difficulty").tier == "normal" and cs.summary().ends_with("NORMAL"),
				"the summary line ends with the difficulty (normal by default)"
			)
			_press(KEY_UP)  # harder
			_press(KEY_ESCAPE)
		8:
			var cs: Node = title._select
			_check(cs.step == "char", "Esc on the phone step goes back to the character")
			var diff := root.get_node("Difficulty")
			_check(diff.tier == "hard" and cs.summary().ends_with("HARD"), "Up makes it harder")
			var cfg := ConfigFile.new()
			cfg.load("user://test_cs_%d_settings.cfg" % OS.get_process_id())
			_check(
				cfg.get_value("difficulty", "tier", "") == "hard",
				"the choice is saved in the settings"
			)
			_press(KEY_DOWN)
			_press(KEY_DOWN)  # hard -> normal -> easy
			_press(KEY_UP)  # ... -> normal
			_press(KEY_ESCAPE)
		9:
			_check(title._select == null and title._menu_open, "Esc on the first step: title menu")
			_press(KEY_ENTER)  # open the select again
		10:
			var cs: Node = title._select
			_check(cs != null, "the menu still works after going back")
			_press(KEY_LEFT)  # adult -> intern
		11:
			_press(KEY_ENTER)
		12:
			_press(KEY_RIGHT)  # nexus
		13:
			_press(KEY_ENTER)
		14:
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
		15:
			var cs: Node = title._select
			_check(cs._panel.row == 1, "Down moves to the next row")
			_check(cs._panel.name_text() == "CUSTOM", "P picked SCRIPTER and the edit made it CUSTOM (%s)" % cs._panel.name_text())
			_check(cs._panel.level("networking") == 0 and cs._panel.level("powershell") == 4, "Left took a level off NETWORKING")
			_press(KEY_ESCAPE)
		16:
			var cs: Node = title._select
			_check(cs.step == "phone", "Esc on the build step goes back to the phone")
			_press(KEY_ENTER)
		17:
			var cs: Node = title._select
			_check(cs.step == "build" and cs._panel.level("networking") == 0, "Enter on the phone returns to the build, edits kept")
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
		18:
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
		19:
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
		20:
			_press(KEY_ENTER)
		21:
			# the tech submenu has CONTINUE first: choosing it must not open the select screen
			_check(title._items[0].id == "tech", "the top menu starts with TECH CAMPAIGN")
			title._choose(0)
			_check(title._items[0].id == "tech_slot1", "its submenu offers the saved slot")
			_press(KEY_ENTER)
		22:
			_check(title._select == null and title._started, "Continue skips the select screen")
			_check(
				campaign.active and player_script.current_character == "casual_garrison",
				"Continue uses the saved character"
			)
			campaign.active = false
			campaign.mode = ""
			DirAccess.remove_absolute(campaign.save_path("tech"))
			wait = 90  # let the scene change to the main floor finish first
		23:
			root.get_node("Game").title_mode = true
			root.get_node("World").time_scale = 0.0
			change_scene_to_file("res://scenes/title.tscn")
			wait = 40
		24:
			_press(KEY_ENTER)
		25:
			title._sel = title._items.size() - 2  # CAREER is the last entry
			_check(title._items[title._sel].id == "free", "FREE PLAY is the item before CAREER")
			_press(KEY_ENTER)
		26:
			var cs: Node = title._select
			_check(
				cs != null and cs.mode == "free" and cs.ids.size() == 8, "free play offers all 7 plus MAKE YOUR OWN"
			)
			_check(not cs.needs_phone() and "SALES" != cs.summary(), "no phone step in free play")
			cs.sel = 0
			cs.confirm()
			_check(cs.step == "create" and cs._pages().size() == 2, "MAKE YOUR OWN opens the create step with two pages")
			cs.set_page(1)
			_check(cs._page_rows()[1].id == "pattern" and cs._page_rows().size() == 5, "the CLOTHES page has its five rows")
			cs.open_presets()
			_check(cs.create_modal == "presets", "the presets chooser opens")
			cs.back()
			_check(cs.create_modal == "" and cs.step == "create", "Back closes the chooser first")
			cs.back()
			_check(cs.step == "char", "Back leaves the create step")
			cs.set_page(0)
			for k in 7:
				if cs.current_id() != "sales_vic":
					cs.move(1)
			_check(cs.current_id() == "sales_vic", "Vic is the 7th")
			cs.confirm()
		27:
			_check(title._started and not campaign.active, "free play started without a campaign")
			_check(player_script.current_character == "sales_vic", "playing as Vic")
			phone.set_os(old_os)
			player_script.current_character = old_char
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	step += 1
	wait = 5
	return false
