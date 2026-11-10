extends SceneTree
# gdlint:disable=max-line-length,class-variable-name
# Office growth (roadmap R16, scripts/office_decor.gd): decor unlocked by reputation, cash and medals, announced once,
# kept when the numbers dip, saved with the campaign (the end-of-day save and the mid-day resume point), drawn on the
# main floor by a node in the room's Fx layer, nothing in Free Play. Headless, with the main floor loaded for the node.


var OfficeDecor: Script  # loaded in _init: a -s script compiles before the autoloads exist
var failures := 0
var c: Node
var cards: Node
var career: Node
var hints: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain() -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


func _fresh(mode: String) -> void:
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Game").title_mode = false
	root.get_node("Game").ui_open = false
	c.new_game(mode)
	_drain()
	root.get_node("Msp").enabled = false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	await process_frame
	OfficeDecor = load("res://scripts/office_decor.gd")
	c = root.get_node("Campaign")
	cards = root.get_node("Cards")
	career = root.get_node("Career")
	hints = root.get_node("Hints")
	var story := root.get_node("Story")
	var game := root.get_node("Game")
	var world := root.get_node("World")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	career.toasts = false
	career.reset_all()

	# ---- the table
	var ids := {}
	var table_ok := true
	for it in OfficeDecor.ITEMS:
		table_ok = table_ok and not ids.has(it.id) and OfficeDecor.RULE_NAMES.has(str(it.rule[0])) and int(it.rule[1]) > 0 and str(it.name) != ""
		ids[it.id] = true
	_check(table_ok and OfficeDecor.ITEMS.size() >= 6, "%d decor items, each with a rule" % OfficeDecor.ITEMS.size())
	_check(OfficeDecor.rule_text(OfficeDecor.item("fish")) == "REPUTATION 75", "rule text: %s" % OfficeDecor.rule_text(OfficeDecor.item("fish")))

	# ---- unlocking
	_fresh("tech")
	_check(OfficeDecor.unlocked().is_empty() and OfficeDecor.check().is_empty(), "a new run (reputation 50, no cash, no medals) has a bare office")
	c.rep = 56
	hints.toast_text = ""
	var fresh: Array = OfficeDecor.check()
	_check(fresh == ["plant"] and OfficeDecor.has("plant") and str(hints.toast_text) == "NEW IN THE OFFICE: A TALL PLANT", "reputation 56 brings the plant and a toast (%s)" % str(hints.toast_text))
	hints.toast_text = ""
	_check(OfficeDecor.check().is_empty() and str(hints.toast_text) == "", "it is announced once")
	c.rep = 30
	OfficeDecor.check()
	_check(OfficeDecor.has("plant"), "a dip in reputation does not take it away")
	c.cash = 450
	_check(OfficeDecor.check() == ["rug"], "banked pay of $450 buys the rug")
	c.rep = 80
	c.cash = 1600
	fresh = OfficeDecor.check()
	_check(fresh == ["certificate", "fish", "neon"], "reputation 80 and $1600: certificate, fish tank, neon sign (%s)" % str(fresh))
	_check(not OfficeDecor.has("trophy"), "no trophy shelf without medals")
	for m in career.MEDALS.slice(0, 3):
		career.earned[str(m.id)] = true
	_check(career.earned_count() >= 3 and OfficeDecor.check() == ["trophy"], "three medals put up the trophy shelf")
	for m in career.MEDALS.slice(0, 8):
		career.earned[str(m.id)] = true
	_check(OfficeDecor.check() == ["trophies"] and OfficeDecor.unlocked().size() == OfficeDecor.ITEMS.size(), "eight medals fill it: everything is unlocked")

	# ---- the sprites (tools/make_decor.lua): every one the node draws is there, at the size the placements assume
	var art_ok := true
	for id in OfficeDecor.SPRITES:
		var tex: Texture2D = OfficeDecor.art(id)
		if tex == null or Vector2i(tex.get_size()) != OfficeDecor.SPRITES[id]:
			art_ok = false
			print("     missing or wrong size: %s" % id)
	_check(art_ok and OfficeDecor.SPRITES.size() == 15, "the %d decor and season sprites load at their sizes" % OfficeDecor.SPRITES.size())
	_check(OfficeDecor.art("decor_nothing") == null, "a missing sprite is null (the node falls back to rectangles)")

	# ---- saved with the campaign, and with the mid-day resume point
	var want: Array = OfficeDecor.unlocked().duplicate()
	c.save()
	c.new_game("free")
	_check(OfficeDecor.unlocked().is_empty() and OfficeDecor.check().is_empty(), "Free Play has no decor")
	_check(c.continue_game("tech"), "continue from the end-of-day save")
	_drain()
	_check(OfficeDecor.unlocked() == want, "the decor is back (%d items)" % want.size())
	_fresh("tech")
	c.rep = 56
	OfficeDecor.check()
	world.clock = 11.0
	var at_snap: Array = OfficeDecor.unlocked().duplicate()
	_check(c.snapshot() and at_snap.has("plant"), "a mid-day resume point")
	c.new_game("free")
	var resumed: bool = c.continue_game("tech", true)
	_check(resumed and OfficeDecor.unlocked() == at_snap, "the resume point keeps the decor (%s)" % str(OfficeDecor.unlocked()))
	_drain()

	# ---- the books campaigns measure cash by what the company gained
	_fresh("owner")
	var o := root.get_node("Owner")
	_check(OfficeDecor.measure("cash") == 0, "owner: no gain yet")
	o.cash = o.START_CASH + 4500
	_check(OfficeDecor.measure("cash") == 450 and OfficeDecor.check().has("rug"), "owner: $4500 gained counts as 450")

	# ---- the node on the main floor
	_fresh("tech")
	c.rep = 80
	c.cash = 1600
	career.earned = {}
	game.go("main_floor", "start")
	await _wait(60)
	var stage := current_scene
	var node: Node = stage.get_node_or_null("Fx/OfficeDecor") if stage != null else null
	_check(node != null and node.get_index() == 0, "the main floor has the decor node at the bottom of its Fx layer")
	_check(OfficeDecor.unlocked() == ["plant", "rug", "certificate", "fish", "neon"], "walking in unlocks what the numbers allow: %s" % str(OfficeDecor.unlocked()))
	c.day = 3
	await _wait(150)
	_check(is_instance_valid(node), "it draws the decor and the holiday lights without an error")
	_check(story.flags.get("decor", []) == OfficeDecor.unlocked(), "the unlocked list lives in the story flags")
	game.go("kitchenette", "start")
	await _wait(60)
	_check(current_scene != null and current_scene.get_node_or_null("Fx/OfficeDecor") == null, "other rooms have no decor node")
	c.new_game("free")
	game.go("main_floor", "start")
	await _wait(60)
	var free_node: Node = current_scene.get_node_or_null("Fx/OfficeDecor")
	_check(free_node != null and OfficeDecor.unlocked().is_empty(), "Free Play: the node is there and draws nothing")
	career.reset_all()

	print("failures=%d" % failures)
	print("DONE")
	quit(1 if failures > 0 else 0)
