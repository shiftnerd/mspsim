extends SceneTree
# gdlint:disable=max-line-length
# Q6: the owner campaign has its own pair of reputation dials (Difficulty.TABLE owner.gain / owner.loss), so hard can bite the
# owner without moving sales and service, which read rep.gain / rep.loss.
#   easy and normal: the owner's numbers ARE the shared ones, so every weekly reputation move is what it was (the bot lines of
#     those tiers are byte-identical; checked here on every delta the weekly report can produce)
#   hard: gains shrink more and losses grow more than for sales and service; sales and service hard are not touched
# The five-seed bot table (careful 70-80, lazy fails, nobody bankrupt) is in docs/dev/notes-rest.md; rerun it with
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_run.gd -- owner hard careful,lazy seeds=5 ts=4
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/owner_hard.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _moves(c: Node, mode: String) -> Array:
	c.mode = mode
	var out := []
	for delta in range(-3, 5):
		out.append(c._tier_rep(delta))
	return out


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var pid := OS.get_process_id()
	var c := root.get_node("Campaign")
	var d := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_ownerhard_" % pid
	d.settings_path = "user://test_%d_ownerhard_settings.cfg" % pid
	root.get_node("Game").title_mode = false
	_check(d.TABLE.has("owner.gain") and d.TABLE.has("owner.loss") and d.TABLE.has("owner.cost"), "the owner has its own gain, loss and cost dials")
	for i in 2:
		var tier := str(d.TIERS[i])
		_check(float(d.TABLE["owner.gain"][i]) == float(d.TABLE["rep.gain"][i]) and float(d.TABLE["owner.loss"][i]) == float(d.TABLE["rep.loss"][i]), "%s: the owner's reputation dials are the shared ones (gain %s, loss %s)" % [tier, str(d.TABLE["owner.gain"][i]), str(d.TABLE["owner.loss"][i])])
	_check(float(d.TABLE["rep.gain"][2]) == 0.8 and float(d.TABLE["rep.loss"][2]) == 1.3, "sales and service hard keep their numbers (rep.gain 0.8, rep.loss 1.3)")
	_check(float(d.TABLE["owner.gain"][2]) < float(d.TABLE["rep.gain"][2]) and float(d.TABLE["owner.loss"][2]) > float(d.TABLE["rep.loss"][2]), "hard: the owner gains less and loses more than the shared dials (gain %s, loss %s)" % [str(d.TABLE["owner.gain"][2]), str(d.TABLE["owner.loss"][2])])
	_check(float(d.TABLE["owner.gain"][2]) >= 0.3 and float(d.TABLE["owner.loss"][2]) <= 2.5 and float(d.TABLE["owner.cost"][2]) <= 1.1, "and stays inside a sane range (a week can still earn a point; costs at most 10% up)")

	# the weekly report's move, every delta it can produce (-3 .. 4), per tier
	c.new_game("owner")
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1
	for tier in ["easy", "normal"]:
		d.set_tier(tier)
		var as_owner := _moves(c, "owner")
		var as_sales := _moves(c, "sales")
		_check(as_owner == as_sales, "%s: a week moves the owner's reputation exactly as before (%s)" % [tier, str(as_owner)])
	d.set_tier("hard")
	var hard_owner := _moves(c, "owner")
	var hard_sales := _moves(c, "sales")
	var never_easier := true
	var harder := 0
	for i in hard_owner.size():
		never_easier = never_easier and int(hard_owner[i]) <= int(hard_sales[i])
		harder += 1 if int(hard_owner[i]) < int(hard_sales[i]) else 0
	_check(never_easier and harder >= 3, "hard: no weekly move is kinder to the owner than to sales, and %d of 8 are harsher (owner %s, sales %s)" % [harder, str(hard_owner), str(hard_sales)])
	_check(int(hard_owner[4]) == 1 and int(hard_owner[7]) >= 2, "hard: a good week still earns a point and the best week two or more (+1 -> %d, +4 -> %d)" % [int(hard_owner[4]), int(hard_owner[7])])
	_check(int(hard_owner[3]) == 0, "a flat week stays flat")
	_check(_moves(c, "service") == hard_sales, "service reads the shared pair like sales")
	c.mode = "owner"
	d.set_tier("normal")
	# outside a campaign the dial reads normal (cf)
	c.active = false
	d.set_tier("hard")
	_check(d.cf("owner.cost") == 1.0, "outside a campaign the cost dial reads normal")
	d.set_tier("normal")

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
