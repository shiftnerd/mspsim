extends SceneTree
# Screenshots: Lync and LabRat Nerds (needs a renderer): user://community_*.png

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://community_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var lync := root.get_node("Lync")
	var nerds := root.get_node("Nerds")
	var comp := root.get_node("Computer")
	var msp := root.get_node("Msp")
	match frame:
		10:
			c.save_prefix = "user://test_"
			c.new_game("tech")
			for n in ["Alan", "Garrison", "Dan", "Vic"]:
				root.get_node("World").chars[n].scene = root.get_node("World").CAST[n].home
				root.get_node("World").chars[n].legs = [{"kind": "work"}]
			root.get_node("World").chars["Dan"].legs = [{"kind": "meeting"}]
			root.get_node("Social").rel["Alan"] = 40
			lync.incoming("lunch")
			lync._push("Garrison", "Garrison", "Hey, thanks for being easy to work with.")
			var t: Dictionary = msp.create_ticket(0, 0, "test")
			comp.psa_sel = t.id
			comp.open(1)
			comp.activate("app:lync")
		30:
			_shot("lync_list")
			var who := ""
			for k in lync.pending:
				who = k
			comp.activate("lync:contact:" + who)
		40:
			_shot("lync_chat")
			comp.activate("app:nerds")
		50:
			_shot("forum")
			comp.activate("nerds:read:0")
			comp.activate("nerds:tab:irc")
			nerds.karma = 30
			nerds.ask_ticket(msp.tickets[0])
			nerds._process(10.0)
		70:
			_shot("irc")
			quit()
	return false
