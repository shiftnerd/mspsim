extends SceneTree
# Screenshots of the LabRat Nerds forum at wide, h and v (needs a renderer, not --headless): user://forum_<format>_<screen>.png
# Screens: index, footer (the index scrolled to the statistics), board (Script Swap), thread (a question you can answer),
# answered (your post in the thread), vendor (the Vendor Lounge after Rodent Nation).

const FORMATS := ["wide", "h", "v"]

var frame := 0
var step := 0
var fmt := 0
var comp: Node = null


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://forum_%s_%s.png" % [FORMATS[fmt], name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var c := root.get_node("Campaign")
	var nerds := root.get_node("Nerds")
	var sk := root.get_node("Skills")
	var expo := root.get_node("Expo")
	if frame == 10:
		c.save_prefix = "user://test_%d_" % OS.get_process_id()
		c.new_game("tech")
		c.day = 9
		root.get_node("World").clock = 9.4
		sk.ps_level = 2
		sk.xp["servers"] = 60
		expo.went = true
		expo.spam = 2
		nerds.karma = 24
		comp = root.get_node("Computer")
	var t := (frame - 11) % 150
	if frame < 11:
		return false
	if fmt >= FORMATS.size():
		quit()
		return false
	var game := root.get_node("Game")
	match t:
		0:
			game.set_format(FORMATS[fmt])
			nerds.reset()
			nerds.karma = 24
			nerds.ensure_threads()
			comp.open(1)
			comp.activate("app:nerds")
			comp.forum.reset()
		24:
			_shot("index")
			comp.forum.scroll(40)
		32:
			_shot("footer")
			comp.forum.reset()
			comp.activate("nerds:board:scripts")
		56:
			_shot("board")
			# the first open question of the day
			comp.forum.reset()
			comp.activate("nerds:thread:%d" % nerds.threads[0].id)
		80:
			_shot("thread")
			comp.nerds_key("enter")
		100:
			_shot("answered")
			comp.forum.reset()
			comp.activate("nerds:board:vendor")
		124:
			_shot("vendor")
			comp.close()
			fmt += 1
	return false
