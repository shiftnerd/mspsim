extends SceneTree
# R5: the karaoke and escape room intros name who came along (and a friend who will sing the duet).

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var social := root.get_node("Social")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	_check(o._party_line("bowling") == "" and o._party_line("darts") == "", "the other games name their own crew")
	o.opts = {"party": ["Dan", "Maya"]}
	for who in social.people():
		social.rel[who] = 0
	var here: Array = o.present()
	var karaoke: String = o._party_line("karaoke")
	_check(here.size() == 2 and karaoke.begins_with("IN THE ROOM: ") and karaoke.contains("DAN") and karaoke.contains("MAYA"), "karaoke names the party: %s" % karaoke)
	_check(not karaoke.contains("WILL SING"), "nobody friendly, no duet line")
	social.rel["Maya"] = 60
	karaoke = o._party_line("karaoke")
	_check(karaoke.contains("MAYA WILL SING THE RIGHT LANES"), "a friend is named as the duet partner: %s" % karaoke)
	var escape: String = o._party_line("escape")
	_check(escape.begins_with("HELPING YOU: ") and escape.contains("DAN") and not escape.contains("SING"), "the escape room says who is helping: %s" % escape)
	o.opts = {"party": []}
	_check(o._party_line("karaoke") == "JUST YOU." and o._party_line("escape").contains("NO HINTS"), "alone it says so")
	o.opts = {}
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
