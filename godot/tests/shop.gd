extends SceneTree
# S1: the shop. Items cost cash, a slot holds one item (one keyboard at a time), the effects read through Shop.factor / bonus,
# purchases save with the campaign and come over into Year 2, Free Play owns everything, the Easy tier is cheaper.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var shop := root.get_node("Shop")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var ids := {}
	var dup := false
	for it in shop.CATALOG:
		dup = dup or ids.has(str(it.id))
		ids[str(it.id)] = true
	_check(not dup and shop.CATALOG.size() == 12, "12 items with unique ids (no kettle)")
	_check(ids.has("kb_blue") and ids.has("kb_brown") and ids.has("kb_red"), "three keyboards: blue, brown and red switches")
	_check(str(shop.STORE) != "ThinkGeek".to_upper(), "the store has its own parody name (%s)" % shop.STORE)
	# free play owns everything
	_check(not c.active and shop.owns("kb_red") and shop.owns("riser"), "Free Play owns everything")
	c.new_game("tech")
	root.get_node("Difficulty").tier = "normal"
	_check(shop.available() and not shop.owns("kb_blue"), "a tech campaign owns nothing at the start")
	c.cash = 50
	_check(shop.why_not("kb_blue") != "" and not bool(shop.buy("kb_blue").ok) and c.cash == 50, "not enough cash: nothing is bought and no cash is spent")
	c.cash = 500
	_check(bool(shop.buy("kb_blue").ok) and c.cash == 410 and shop.owns("kb_blue"), "the blue keyboard costs $90")
	_check(shop.is_loud() and is_equal_approx(shop.factor("fix_secs"), 0.95), "blue switches are loud and cut fix time by 5 percent")
	var swap: Dictionary = shop.buy("kb_red")
	_check(bool(swap.ok) and shop.owns("kb_red") and not shop.owns("kb_blue") and c.cash == 300, "a red keyboard replaces the blue one")
	_check(not shop.is_loud() and is_equal_approx(shop.factor("fix_secs"), 0.96), "red switches are quiet, 4 percent faster")
	_check(not bool(shop.buy("kb_red").ok), "you cannot buy what you own")
	shop.buy("mouse")
	shop.buy("riser")
	_check(is_equal_approx(shop.factor("drain"), 0.95 * 0.90), "the mouse and the riser stack on the energy drain")
	c.cash = 2000
	shop.buy("cushion")
	shop.buy("plant")
	_check(is_equal_approx(shop.bonus("rest"), 4.0), "the cushion and the plant add to the night's rest")
	shop.buy("headset")
	_check(is_equal_approx(shop.bonus("people_xp"), 1.0), "the headset adds customer XP")
	# the effect reaches the real fix time
	var skills := root.get_node("Skills")
	var base: float = skills.fix_secs_for("reboot")
	shop.reset()
	var plain: float = skills.fix_secs_for("reboot")
	_check(base < plain or plain <= 0.0, "the keyboard shortens a real fix (%.2f vs %.2f)" % [base, plain])
	# saved with the campaign
	c.cash = 2000
	shop.buy("kb_brown")
	shop.buy("poster")
	var d: Dictionary = shop.to_dict()
	shop.reset()
	shop.from_dict(d)
	_check(shop.owned == ["kb_brown", "poster"], "purchases round-trip through the save")
	shop.from_dict({"owned": ["kb_brown", "nonsense", "kb_brown"]})
	_check(shop.owned == ["kb_brown"], "unknown and repeated ids are dropped when loading")
	# Year 2 keeps the desk
	shop.reset()
	shop.restore(["mouse", "rgb"])
	_check(shop.owns("mouse") and shop.owns("rgb"), "Year 2 restores the desk")
	# the desk shows what you own
	shop.reset()
	shop.restore(["kb_red", "plant", "poster", "speakers"])
	var st := Node.new()
	st.scene_file_path = "res://scenes/main_floor.tscn"
	var actors := Node.new()
	actors.name = "Actors"
	st.add_child(actors)
	root.add_child(st)
	shop.dress(st)
	var drawn := 0
	for n in actors.get_children():
		drawn += 1 if n.is_in_group("shop_props") else 0
	_check(drawn == 5, "the desk draws four items, two speakers among them (%d sprites)" % drawn)
	shop.buy("mouse")
	var after := 0
	for n in actors.get_children():
		after += 1 if n.is_in_group("shop_props") and not n.is_queued_for_deletion() else 0
	_check(after == 6, "a purchase redraws the desk without piling up props (%d)" % after)
	st.queue_free()
	# the Easy tier is cheaper
	var diff := root.get_node("Difficulty")
	var normal_price: int = shop.price("riser")
	diff.tier = "easy"
	_check(shop.price("riser") <= normal_price, "the Easy tier never costs more (%d vs %d)" % [shop.price("riser"), normal_price])
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
