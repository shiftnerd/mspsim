extends "res://tests/layout_audit.gd"
# The pictures of README.md and docs/manual (renderer needed, not --headless; about a minute):
#   set MSPSIM_TEST=1
#   Godot --fixed-fps 60 --path godot -s res://tests/readme_shots.gd
# It walks the same screens as the layout audit, lets each one settle, and saves the wanted ones at 2x to
# user://readme/NAME.png; copy them over docs/manual/img/. (desktop.png and hud.png there carry hand-drawn marks and
# are not made here.) Not a regression test: the name ends in _shots, so run_tests.py leaves it alone.

# audit tag -> file name
const WANT := {
	"computer psa": "psa",
	"computer rmm": "rmm",
	"boardroom books": "boardroom",
	"crm list": "crm",
	"charselect tech": "creator",
}
const ROOMS := {"cubicle_area": "cubicles", "conference": "conference", "warehouse": "warehouse", "kitchenette": "kitchenette"}


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("FAIL no picture for ", name)
		failures += 1
		return
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png("user://readme/%s.png" % name)
	print("saved ", name, " ", img.get_size())


# the audit's end of a screen: here it only waits for the wanted ones (fades over) and saves them
func _end(tag: String) -> void:
	screens += 1
	if tag == "computer psa":  # a board with work on it: three tickets, one of them urgent
		var msp := root.get_node("Msp")
		msp.create_ticket(0, 5, "phone")
		msp.create_ticket(1, 1, "mail")
		msp.create_ticket(2, 0, "mail")
		root.get_node("Computer")._canvas.queue_redraw()
	if WANT.has(tag):
		await _wait(45)
		_save(str(WANT[tag]))
	else:
		await _wait(2)
	PixelFont.audit = null


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://readme")
	var game := root.get_node("Game")
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_readme_%d_" % OS.get_process_id()
	root.get_node("Difficulty").settings_path = "user://test_readme_%d_settings.cfg" % OS.get_process_id()
	# ---- the title, in the long format the menus were always shown in: home (with CONTINUE) and the list of campaigns
	var save := ConfigFile.new()
	save.set_value("campaign", "day", 12)
	save.save(camp.save_path("tech"))
	fmt = "wide"
	game.set_format("wide")
	await _scene("res://scenes/title.tscn")
	var t := current_scene
	t._open_menu()
	await _wait(40)
	_save("title-home")
	var new_row := 0
	for i in t._items.size():
		if str(t._items[i].get("id", "")) == "play":
			new_row = i
	t._choose(new_row)
	await _wait(20)
	_save("title-menu")
	DirAccess.remove_absolute(camp.save_path("tech"))
	fmt = "h"
	game.set_format("h")
	await _scene("res://scenes/title.tscn")
	await _wait(90)
	_save("title")
	# ---- the rooms, with the cast at work (Free Play, mid morning)
	game.title_mode = false
	await _scene("res://scenes/main_floor.tscn")
	camp.new_game(camp.FREE)
	root.get_node("World").clock = 10.5
	root.get_node("World").hud_visible = false
	await _wait(30)
	for scene in ROOMS:
		game.go(scene, "start")
		await _wait(150)
		_clear(root.get_node("Cards"))
		_save(str(ROOMS[scene]))
	# ---- bowling night
	var o := root.get_node("Outings")
	o.enabled = true
	o.use_rooms = true
	o.start("bowling")
	await _wait(160)
	if o.is_open:
		o.press(KEY_ENTER)
	await _wait(70)
	_save("bowling")
	if o.is_open:
		o.press(KEY_ESCAPE)
		o.press(KEY_ENTER)
	await _wait(90)
	# ---- paintball on the western street
	o.start("paintball")
	await _wait(160)
	if o.is_open:
		o.press(KEY_ENTER)
	await _wait(260)
	_save("paintball")
	if o.is_open:
		o.press(KEY_ESCAPE)
		o.press(KEY_ENTER)
	await _wait(90)
	root.get_node("World").hud_visible = true
	# ---- every screen the audit knows, saving the wanted ones
	await _title_phase()
	await _floor_phase()
	print("screens=%d failures=%d" % [screens, failures])
	quit(1 if failures > 0 else 0)
