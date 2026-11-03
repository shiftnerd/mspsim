extends SceneTree
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
			campaign.save_prefix = "user://test_cs_"
			for m in ["tech", "owner"]:
				if campaign.has_save(m):
					DirAccess.remove_absolute(campaign.save_path(m))
			old_os = phone.os
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
				tech == ["office_teen", "office_adult", "site_alan"],
				"campaigns offer only people who are not cast members"
			)
			var cast_ok := true
			for n in root.get_node("World").CAST:
				if root.get_node("World").CAST[n].character in tech:
					cast_ok = false
			_check(cast_ok, "no cast member is offered in a campaign (no NPC copy to hide)")
			_check(cs.choices("owner") == tech, "the owner campaign follows the same rule")
			cs.free()
			_press(KEY_ENTER)
		1:
			_check(title._menu_open, "Enter opens the title menu")
			_press(KEY_ENTER)  # first item: TECH CAMPAIGN (new)
		2:
			var cs: Node = title._select
			_check(cs != null and cs.mode == "tech", "TECH CAMPAIGN opens the select screen")
			_check(
				cs.ids.size() == 3 and cs.current_id() == "office_adult", "starts on the default"
			)
			_check(not title._started and not campaign.active, "nothing has started yet")
			_press(KEY_RIGHT)
		3:
			var cs: Node = title._select
			_check(cs.current_id() == "site_alan" and cs.facing == "right", "Right moves on")
			_press(KEY_RIGHT)
		4:
			var cs: Node = title._select
			_check(cs.current_id() == "office_teen", "the row wraps around")
			_press(KEY_LEFT)
		5:
			var cs: Node = title._select
			_check(cs.current_id() == "site_alan" and cs.facing == "left", "Left goes back")
			_press(KEY_ENTER)
		6:
			var cs: Node = title._select
			_check(cs.step == "phone" and title._select != null, "tech asks for the phone next")
			_check(
				"IPHONE 5" in cs.summary() and "SITE" in cs.summary(), "the summary line names both"
			)
			_press(KEY_RIGHT)
		7:
			var cs: Node = title._select
			_check(cs.phone_sel == 1 and "NEXUS 5" in cs.summary(), "the phone can be changed")
			_press(KEY_ESCAPE)
		8:
			var cs: Node = title._select
			_check(cs.step == "char", "Esc on the phone step goes back to the character")
			_press(KEY_ESCAPE)
		9:
			_check(title._select == null and title._menu_open, "Esc on the first step: title menu")
			_press(KEY_ENTER)  # open the select again
		10:
			var cs: Node = title._select
			_check(cs != null, "the menu still works after going back")
			_press(KEY_LEFT)  # adult -> teen
		11:
			_press(KEY_ENTER)
		12:
			_press(KEY_RIGHT)  # nexus
		13:
			_press(KEY_ENTER)
		14:
			_check(title._started and campaign.active and campaign.mode == "tech", "tech started")
			_check(
				player_script.current_character == "office_teen",
				"the chosen character is the player"
			)
			_check(phone.os == "android", "the phone preference is set (Nexus 5)")
			var world := root.get_node("World")
			_check(
				world.chars.has("Alan") and world.chars.has("Dan"),
				"the whole team is still the cast"
			)
			campaign.save()
			wait = 60
		15:
			var cfg := ConfigFile.new()
			cfg.load(campaign.save_path("tech"))
			_check(
				cfg.get_value("campaign", "character", "") == "office_teen", "saved with the run"
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
		16:
			_press(KEY_ENTER)
		17:
			# the menu now has CONTINUE TECH first: choosing it must not open the select screen
			_check(title._items[0].id == "tech_continue", "the menu offers Continue")
			_press(KEY_ENTER)
		18:
			_check(title._select == null and title._started, "Continue skips the select screen")
			_check(
				campaign.active and player_script.current_character == "casual_garrison",
				"Continue uses the saved character"
			)
			campaign.active = false
			campaign.mode = ""
			DirAccess.remove_absolute(campaign.save_path("tech"))
			wait = 90  # let the scene change to the main floor finish first
		19:
			root.get_node("Game").title_mode = true
			root.get_node("World").time_scale = 0.0
			change_scene_to_file("res://scenes/title.tscn")
			wait = 40
		20:
			_press(KEY_ENTER)
		21:
			title._sel = title._items.size() - 1
			_check(title._items[title._sel].id == "free", "FREE PLAY is the last item")
			_press(KEY_ENTER)
		22:
			var cs: Node = title._select
			_check(
				cs != null and cs.mode == "free" and cs.ids.size() == 7, "free play offers all 7"
			)
			_check(not cs.needs_phone() and "SALES" != cs.summary(), "no phone step in free play")
			for k in 7:
				if cs.current_id() != "sales_vic":
					cs.move(1)
			_check(cs.current_id() == "sales_vic", "Vic is the 7th")
			cs.confirm()
		23:
			_check(title._started and not campaign.active, "free play started without a campaign")
			_check(player_script.current_character == "sales_vic", "playing as Vic")
			phone.set_os(old_os)
			player_script.current_character = old_char
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	step += 1
	wait = 5
	return false
