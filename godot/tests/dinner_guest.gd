extends SceneTree
# gdlint:disable=max-line-length
# R6: the dinner guest has a body. With a guest at the table (Outings.dinner_guest()) the client's own character sits in
# the second booth's outer seat (Seat4, where SetDressing lays the place setting), seated and in the seated poses; the crew
# member who had that seat sits on the free stool at the bar (nobody stays home, the table's score is the same party); a
# dinner without a guest seats nobody extra; the guest leaves with the dinner and the seats are free again. A prospect
# (no client index) gets a face from the pool, the same one every time.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/dinner_guest.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _settle(name: String) -> void:
	var n := 0
	while (_scene_name() != name or root.get_node("Game").busy) and n < 600:
		await process_frame
		n += 1
	for i in 8:
		await process_frame


func _go(o: Node, options: Dictionary) -> void:
	o.start("dinner", false, options)
	var n := 0
	while not o.is_open and n < 800:
		await process_frame
		n += 1
	await _settle("restaurant")
	o.press(KEY_ENTER)
	for i in 8:
		await process_frame


func _leave(o: Node) -> void:
	if o.phase == "play":
		o.press(KEY_ESCAPE)
	o.press(KEY_ENTER)
	await _settle("main_floor")


func _seat_of(who: String) -> String:
	var npc := current_scene.get_node_or_null("Actors/" + who)
	return str(npc.seat.name) if npc != null and npc.seat != null else ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var pid := OS.get_process_id()
	var o := root.get_node("Outings")
	var game := root.get_node("Game")
	var c := root.get_node("Campaign")
	var msp := root.get_node("Msp")
	var onsite := root.get_node("Onsite")
	c.save_prefix = "user://test_%d_dguest_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_dguest_settings.cfg" % pid
	game.title_mode = false
	c.new_game(c.FREE)
	root.get_node("Difficulty").seed_run(4241)
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _settle("main_floor")
	o.enabled = true
	o.use_rooms = true
	var party := ["Alan", "Garrison", "Dan", "John"]

	# ---- no guest: the seats as they always were
	await _go(o, {"party": party.duplicate(), "variety": true})
	_check(o.dinner_guest().is_empty() and o.guest_node == null and current_scene.get_node_or_null("Actors/DinnerGuest") == null, "a dinner without a guest seats nobody extra")
	_check(_seat_of("Dan") == "Seat4" and _seat_of("Garrison") == "Seat3" and _seat_of("Alan") == "Seat1", "the crew has the booths (Dan %s, Garrison %s, Alan %s)" % [_seat_of("Dan"), _seat_of("Garrison"), _seat_of("Alan")])
	_check(not current_scene.get_node("Interactables/Seat8").occupied, "and the last stool at the bar is free")
	var diners_plain: Array = o.diners().duplicate()
	await _leave(o)

	# ---- a client with an office of their own (client 0, the dental practice): their owner's character at the booth
	await _go(o, {"party": party.duplicate(), "variety": true, "guest": 0})
	var guest: Dictionary = o.dinner_guest()
	var node: Node = current_scene.get_node_or_null("Actors/DinnerGuest")
	var want: String = ""
	for entry in onsite.CAST_AT[onsite.SITES[0].type][onsite.SITES[0].skin].office:
		if str(entry[2]) == "owner":
			want = str(entry[0])
	_check(str(guest.name) == str(msp.CLIENTS[0].contact), "the guest tonight is %s of %s" % [guest.get("name", ""), guest.get("firm", "")])
	_check(node != null and node == o.guest_node, "the guest is a person in the room")
	if node != null:
		_check(str(node.character) == want and want != "" and o.guest_character() == want, "it is the character you meet in that client's own office (%s)" % node.character)
		_check(node.seat != null and str(node.seat.name) == "Seat4" and node.seat.occupied, "seated in the second booth's outer seat (%s)" % (str(node.seat.name) if node.seat != null else "-"))
		_check(node.global_position.x == current_scene.get_node("Interactables/Seat4").global_position.x, "on the seat, where the place setting is laid (x %d)" % int(node.global_position.x))
		_check(str(node.sprite.animation).begins_with("sit"), "in a seated pose (%s)" % node.sprite.animation)
		_check(node.sprite.sprite_frames != null and node.sprite.sprite_frames.has_animation("sit_right") and node.sprite.sprite_frames.get_frame_count("sit_right") > 0 and node.sprite.sprite_frames.has_animation("sitnod_right"), "the client's sheet has the seated frames")
		_check(node.get_node("Shape").disabled and str(node.role) == "guest" and str(node.cast_name) == "", "nobody to walk up to: no talk zone, not a cast member")
		# seat life: left alone for a while the guest makes one of the seated gestures
		var gestures := {}
		for i in 60 * 45:
			await physics_frame
			gestures[str(node.sprite.animation)] = true
		var all_seated := true
		for a in gestures:
			all_seated = all_seated and str(a).begins_with("sit")
		_check(node.seat != null and all_seated and gestures.size() >= 2, "45 seconds later the guest is still seated and has moved like a seated person (poses seen: %s)" % str(gestures.keys()))
	_check(_seat_of("Dan") == "Seat8", "Dan gave up the booth seat and sits at the bar (%s)" % _seat_of("Dan"))
	var dan := current_scene.get_node_or_null("Actors/Dan")
	_check(dan != null and str(dan.sprite.animation).begins_with("sit") and dan.global_position.x == current_scene.get_node("Interactables/Seat8").global_position.x, "seated there, not standing (%s)" % (str(dan.sprite.animation) if dan != null else "-"))
	_check(_seat_of("Garrison") == "Seat3" and _seat_of("Alan") == "Seat1", "the others keep their seats")
	_check(o.diners() == diners_plain and o.diners().has("Dan"), "the party at the table is the same: nobody stayed home (%s)" % str(o.diners()))
	_check(not root.get_node("World").chars.has("DinnerGuest"), "the world's cast list never hears of the guest")
	# you sit down and the dinner runs as before, guest reactions included
	var player := current_scene.get_node("Actors/Player")
	player.global_position = current_scene.get_node("Interactables/Seat2").global_position
	player.sit(current_scene.get_node("Interactables/Seat2"))
	var guard := 0
	while str(o.g.stage) == "sit" and guard < 300:
		await process_frame
		guard += 1
	_check(str(o.g.stage) != "sit" and o._dinner_open_line().contains(str(guest.name).to_upper()), "you sit down and the table starts, naming the guest")
	_check(is_instance_valid(node) and node.seat != null, "the guest stays through the talk")
	await _leave(o)
	_check(o.guest_node == null and current_scene.get_node_or_null("Actors/DinnerGuest") == null, "the guest leaves with the dinner")
	await _wait_frames(6)

	# ---- the next dinner without a guest: everything is back
	await _go(o, {"party": party.duplicate(), "variety": true})
	_check(current_scene.get_node_or_null("Actors/DinnerGuest") == null and _seat_of("Dan") == "Seat4" and not current_scene.get_node("Interactables/Seat8").occupied, "the next dinner without a guest: Dan has the booth again, the stool is free (%s)" % _seat_of("Dan"))
	await _leave(o)

	# ---- a prospect (a name, no client): a face from the pool, the same one for the same name
	o.g = {"guest": {"client": -1, "name": "Dana Whitfield", "firm": "Whitfield Consulting"}}
	var face: String = o.guest_character()
	_check(o.GUEST_POOL.has(face) and face.begins_with("client_") and o.guest_character() == face, "a prospect gets a client face from the pool, the same every time (%s)" % face)
	var faces := {}
	for who in ["Pat Lee", "Sam Ortiz", "Chris Vale", "Robin Park", "Lou Marsh", "Kit Dorn"]:
		o.g = {"guest": {"client": -1, "name": who, "firm": ""}}
		faces[o.guest_character()] = true
	_check(faces.size() >= 3, "different names, different faces (%d of 6)" % faces.size())
	var sheets_ok := true
	for sheet in o.GUEST_POOL:
		sheets_ok = sheets_ok and _has_sheet(str(sheet))
	_check(sheets_ok, "every face of the pool is a character the game has")
	for ci in onsite.SITES:
		o.g = {"guest": {"client": int(ci), "name": str(msp.CLIENTS[int(ci)].contact), "firm": ""}}
		sheets_ok = sheets_ok and _has_sheet(o.guest_character())
	_check(sheets_ok, "and so is the owner of every client site")
	o.g = {}
	_check(o.guest_character() == "", "no guest, no character")

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


# a character the NPC scene can show: some file under res://assets carries its name
func _has_sheet(sheet: String) -> bool:
	return _find_file("res://assets", sheet)


func _find_file(dir_path: String, sheet: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	for f in dir.get_files():
		if f.begins_with(sheet):
			return true
	for d in dir.get_directories():
		if _find_file(dir_path + "/" + d, sheet):
			return true
	return false
