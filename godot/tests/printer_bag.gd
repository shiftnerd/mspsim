extends SceneTree
# P6: the bag you carry into an onsite printer job: the right one for the printer is worth a mistake, a wrong one costs one, none is neutral.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _start(pg: Node, model: String, bag: String) -> void:
	pg.is_open = false
	pg.start(func(_s: int) -> void: pass, model, {"bag": bag} if bag != "" else {})


func _init() -> void:
	await process_frame
	var pg := root.get_node("PrinterGame")
	var skills := root.get_node("Skills")
	root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var all_bags := true
	for m in pg.MODELS:
		all_bags = all_bags and pg.BAGS.has(pg.BAG_FOR.get(m, ""))
	_check(all_bags, "every printer model has a right bag from the four")
	_start(pg, "laser", "")
	pg.mistakes = 2
	_check(pg.bag_adj == 0 and pg._score() == 2, "no bag: two mistakes are two stars")
	_start(pg, "laser", "fuser")
	pg.mistakes = 2
	_check(pg.bag_adj == -1 and pg._score() == 3, "the fuser kit is right for the laser: the same two mistakes are three stars")
	_start(pg, "laser", "cable")
	pg.mistakes = 1
	_check(pg.bag_adj == 1 and pg._score() == 2, "a network cable is wrong for it: one mistake is only two stars")
	_start(pg, "inkjet", "air")
	_check(pg.bag_adj == -1, "compressed air is right for the inkjet")
	_start(pg, "plotter", "paper")
	_check(pg.bag_adj == -1, "paper is right for the plotter")
	_start(pg, "line", "fuser")
	_check(pg.bag_adj == -1 and pg.faith == 0, "and the boss still has no prayers")
	pg.is_open = false
	# the choice on the card: four bags, the best marked once you know some servers
	skills.xp["servers"] = 0
	var plain: Array = pg.bag_options("laser")
	_check(plain.size() == 4 and plain.all(func(o: Dictionary) -> bool: return not str(o.label).contains("BEST")), "four bags and nothing marked at first")
	skills.xp["servers"] = skills.need(1)
	var marked: Array = pg.bag_options("laser").filter(func(o: Dictionary) -> bool: return str(o.label).contains("BEST"))
	_check(skills.level("servers") >= 2 and marked.size() == 1 and str(marked[0].id) == "fuser", "with servers level 2 the right bag is marked (BEST)")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
