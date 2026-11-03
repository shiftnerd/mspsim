extends SceneTree
# Interact priority at the client sites: doors and equipment beat small talk with staff; nearest wins otherwise.
# gdlint:disable=max-line-length

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _at(x: float) -> Node:
	var p: Node = current_scene.get_node("Actors/Player")
	p.global_position = Vector2(x, 118.0)
	p._pick = null
	return p


func _nearest(x: float) -> String:
	var p := _at(x)
	await _wait(0.25)
	var n: Node = p.nearest()
	return "" if n == null else str(n.name)


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	root.get_node("Campaign").save_prefix = "user://test_"
	game.title_mode = false

	# the dental closet: each piece of equipment is the target at its own spot
	game.go("site_dental_closet_a", "start")
	await _wait(0.8)
	_check(await _nearest(185.0) == "UseObjCabinet", "closet: the cabinet at x=185")
	_check(await _nearest(231.0) == "UseObjServer", "closet: the server tower at x=231")
	_check(await _nearest(215.0) == "UseObjServer", "closet: the server wins at its zone edge")

	# the arch office: the printer and staff stand together; the plotter wins, Tab still reaches the staff
	game.go("site_arch_a", "start")
	await _wait(0.8)
	var printer_x := 208.0 + 24.0
	var staff: Node = null
	for n in get_nodes_in_group("npcs"):
		if str(n.role) == "site:staff" and absf(n.global_position.x - (214.0 + 24.0)) < 2.0:
			staff = n
	_check(staff != null, "a staff member stands beside the plotter")
	_check(await _nearest(printer_x) == "UseObjPrinter1", "arch: standing at the plotter, E is the plotter and not small talk")
	var p := _at(238.0)
	await _wait(0.25)
	_check(p.nearest() != null and p.nearest().name == "UseObjPrinter1", "arch: still the plotter a little to the right")
	p.cycle_pick(1)
	_check(p.nearest() == staff or p.nearest().name != "UseObjPrinter1", "Tab moves on to someone else in reach")

	# the PC beats the low priority reception desk, and the desk is reachable at its left end
	_check(await _nearest(256.0 + 24.0) == "UseObjPc0", "arch: the PC beats the reception desk")
	_check(await _nearest(236.0 + 24.0) != "", "arch: something is in reach at the reception desk")

	# a door next to a staff member
	game.go("site_dental_a", "start")
	await _wait(0.8)
	var door_x := 24.0 + 21.0
	_check(str(await _nearest(door_x + 5.0)).begins_with("Use"), "dental: next to the door the door zone wins (%s)" % str(await _nearest(door_x + 5.0)))

	# alone with a person the person is the target
	game.go("site_dental_office_a", "start")
	await _wait(0.8)
	var owner_npc: Node = null
	for n in get_nodes_in_group("npcs"):
		owner_npc = n
	if owner_npc != null:
		var pp := _at(owner_npc.global_position.x)
		await _wait(0.25)
		_check(pp.nearest() == owner_npc, "alone with the owner, E talks to the owner")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
