extends SceneTree
# Screenshots of the LabRat Nerds IRC tab at wide, h and v (needs a renderer, not --headless): user://irc_<format>_<screen>.png
# Screens: log (ambient talk, a work verdict, friendship in the nick list), who (pick a nick), topics (a FRIEND with a locked topic),
# join (jump into the last line), talked (after a chat).

const FORMATS := ["wide", "h", "v"]

var frame := 0
var fmt := 0
var comp: Node = null


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://irc_%s_%s.png" % [FORMATS[fmt], shot_name])


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 10:
		return false
	var c := root.get_node("Campaign")
	var nerds := root.get_node("Nerds")
	var msp := root.get_node("Msp")
	if frame == 10:
		c.save_prefix = "user://test_%d_" % OS.get_process_id()
		c.new_game("tech")
		c.day = 4
		root.get_node("World").clock = 10.2
		root.get_node("Expo").went = true
		comp = root.get_node("Computer")
	var t := (frame - 11) % 120
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
			nerds.karma = 30
			nerds.friend = {"rodent_rick": 34, "gnawer": 12, "PS_wizard": 65, "HELPPLZ_Pip": 31}
			comp.open(1)
			comp.activate("app:nerds")
			comp.activate("nerds:tab:irc")
			nerds.ask_ticket(msp.tickets[0] if not msp.tickets.is_empty() else {})
			nerds._process(10.0)
		24:
			_shot("log")
			comp.activate("nerds:view:who")
		40:
			_shot("who")
			comp.activate("nerds:who:rodent_rick")
		56:
			_shot("topics")
			comp.activate("nerds:view:chat")
			comp.activate("nerds:view:join")
		72:
			_shot("join")
			comp.activate("nerds:join:joke")
			nerds._process(5.0)
		92:
			_shot("talked")
			comp.close()
			fmt += 1
	return false
