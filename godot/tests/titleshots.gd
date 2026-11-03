extends SceneTree
# Screenshots of the title screen vignettes and of the title menu levels (needs a renderer):
# user://title_<format>_<n>.png and user://titlemenu_<format>_<top|full|plain|slots2|slots3|over>.png (slots: tech with 2 / 3 saves,
# over: all three full and NEW CAMPAIGN asking which slot to overwrite)

const JOBS := [["h", 0], ["h", 1], ["h", 2], ["h", 3], ["wide", 1], ["wide", 2], ["v", 1], ["v", 3]]
const WAIT := 400
const MENU_WAIT := 20
const MENU_FORMATS := ["wide", "h", "v"]
const MENU_KINDS := ["top", "full", "plain", "slots2", "slots3", "over"]

var frame := 0
var job := 0
var menu_job := 0
var menu_start := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/title.tscn")


func _fake_state() -> void:
	var c := root.get_node("Campaign")
	var y := root.get_node("Yeartwo")
	c.save_prefix = "user://test_titleshots_%d_" % OS.get_process_id()
	for mode in ["tech", "owner"]:
		var cfg := ConfigFile.new()
		cfg.set_value("campaign", "day", 7 if mode == "tech" else 4)
		cfg.set_value("campaign", "year", 1)
		cfg.save(c.save_path(mode))
	var meta := ConfigFile.new()
	y.record(meta, "tech", "lead")  # a finished tech year: the tech submenu gains START YEAR 2
	meta.save(y.meta_path())


# tech saves in the first n slots (day 7 / 12 with a custom person in Year 2 / 20)
func _slots(n: int) -> void:
	var c := root.get_node("Campaign")
	for i in range(1, 4):
		DirAccess.remove_absolute(c.save_path("tech", i))
		if i > n:
			continue
		var cfg := ConfigFile.new()
		cfg.set_value("campaign", "day", [7, 12, 20][i - 1])
		cfg.set_value("campaign", "year", 2 if i == 2 else 1)
		if i == 2:
			cfg.set_value("campaign", "look", {"active": true, "name": "JAMIE"})
		cfg.save(c.save_path("tech", i))


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	if job < JOBS.size():
		var t := frame - job * (WAIT + 10)
		var info: Array = JOBS[job]
		if t == 2:
			root.get_node("Game").set_format(info[0])
			current_scene.show_vignette(info[1])
			current_scene._t = -100.0  # no rotation while we wait
		if t == WAIT:
			root.get_texture().get_image().save_png("user://title_%s_%d.png" % [info[0], info[1]])
			print("saved %s %d (room %s)" % [info[0], info[1], current_scene._room.name])
			job += 1
			if job >= JOBS.size():
				_fake_state()
				menu_start = frame
		return false
	var step := (frame - menu_start) % (MENU_WAIT + 5)
	var fmt: String = MENU_FORMATS[menu_job / MENU_KINDS.size()]
	var kind: String = MENU_KINDS[menu_job % MENU_KINDS.size()]
	if step == 1:
		_slots(1)
		root.get_node("Game").set_format(fmt)
		current_scene.show_vignette(1)
		current_scene._t = -100.0
		current_scene._open_menu()
		if kind == "full":
			current_scene._choose(0)  # TECH: continue, year 2, new
		elif kind == "plain":
			current_scene._choose(1)  # OWNER: continue, new
		elif kind.begins_with("slots"):
			_slots(int(kind.trim_prefix("slots")))
			current_scene._choose(0)
		elif kind == "over":
			_slots(3)
			current_scene._choose(0)
			current_scene._choose(current_scene._items.size() - 1)  # NEW CAMPAIGN with all three full
	if step == MENU_WAIT:
		root.get_texture().get_image().save_png("user://titlemenu_%s_%s.png" % [fmt, kind])
		var labels: Array = current_scene._items.map(func(i: Dictionary) -> String: return i.label)
		print("saved menu %s %s: %s sel=%s" % [fmt, kind, str(labels), str(current_scene._select)])
		menu_job += 1
		if menu_job >= MENU_FORMATS.size() * MENU_KINDS.size():
			print("DONE")
			quit()
	return false
