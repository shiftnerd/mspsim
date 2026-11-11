extends SceneTree
# gdlint:disable=max-line-length
# Q6: the same seed must give the same game. A bot plays the first days of the tech campaign (hard tier, where one ticket more
# or less moves the reputation) twice in one process with the same seed, and a whole sales campaign twice; the two rows of each
# pair must be equal. Between the two runs the office keeps running, so anything that survives Campaign.new_game with a value
# from before the seed (the bug this test was written for: World's meeting timer was drawn once at boot) shows up as a difference.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/determinism.gd

const OFFICE_FRAMES := [900, 1800, 2700]  # bot frames of day 1 (ts=4: about 10:30, 12:30 and 14:30 on the office clock)

var failures := 0
var _office: Array = []


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _sig(r: Dictionary) -> String:
	return "rep %d score %d closed %d missed %d ending %s | %s" % [int(r.rep), int(r.score), int(r.get("closed", 0)), int(r.get("missed", 0)), str(r.get("ending", "")), str(r.get("info", ""))]


# the office at one frame: every cast member's room, leg and (when they have a body in the loaded room) state and place
func _office_hook(frame: int) -> void:
	if not OFFICE_FRAMES.has(frame):
		return
	var world := root.get_node("World")
	var names: Array = world.chars.keys()
	names.sort()
	var who := []
	for n in names:
		var ch: Dictionary = world.chars[n]
		var body := ""
		if ch.node != null and is_instance_valid(ch.node):
			body = " %s %.2f" % [str(ch.node.get("state")), float(ch.node.global_position.x)]
		who.append("%s@%s:%s%s" % [str(n), str(ch.scene), str(ch.legs[0].kind) if not ch.legs.is_empty() else "-", body])
	_office.append("f%d clock %.4f | %s" % [frame, float(world.clock), ", ".join(PackedStringArray(who))])


func _take_office() -> Array:
	var out := _office
	_office = []
	return out


func _first_diff(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			return "%s\n     %s" % [str(a[i]), str(b[i])]
	return "" if a.size() == b.size() else "%d snapshots against %d" % [a.size(), b.size()]


# an owner run week by week: bank, reputation, partner trust, company value, clients and the cards of the week
func _weeks(r: Dictionary) -> String:
	var out := []
	for w in r.get("weeks", []):
		out.append("w%d $%d rep %d trust %d value %d clients %d cards %s" % [int(w.week), int(w.cash), int(w.rep), int(w.trust), int(w.value), int(w.clients), "/".join(PackedStringArray(w.cards))])
	return " | ".join(PackedStringArray(out))


func _init() -> void:
	await process_frame
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	# tech, hard, careful, seed 11: four days, twice
	bots.ts = 120.0
	bots.stop_day = 4
	var a: Dictionary = await bots.play("tech", "hard", "careful", 11)
	# let the office run on between the two games, as it does between two sessions
	root.get_node("World").time_scale = 30.0
	for i in 90:
		await process_frame
	var b: Dictionary = await bots.play("tech", "hard", "careful", 11)
	_check(int(a.closed) > 0, "the bot closed tickets in four days (%d)" % int(a.closed))
	_check(_sig(a) == _sig(b), "tech hard careful seed 11, days 1-4: two runs are the same\n     %s\n     %s" % [_sig(a), _sig(b)])
	var other: Dictionary = await bots.play("tech", "hard", "careful", 12)
	_check(_sig(a) != _sig(other), "another seed is another game")
	bots.stop_day = 0
	# sales, normal, careful, seed 11: the whole campaign, twice
	bots.ts = 20.0
	var s1: Dictionary = await bots.play("sales", "normal", "careful", 11)
	var s2: Dictionary = await bots.play("sales", "normal", "careful", 11)
	_check(_sig(s1) == _sig(s2), "sales normal careful seed 11: two runs are the same\n     %s\n     %s" % [_sig(s1), _sig(s2)])
	# X13: owner seeds in different orders. Seed 3 gave $831,705 alone and $872,920 after seeds 1 and 2. The runs parted on
	# day 1 when two people stopped to chat one frame apart: World.try_chat measures its cooldown on `_total`, the office's
	# running time, which kept growing over the runs of a process, so the same three seconds rounded to another frame. The
	# chat drew from the global generator, and from week 13 the wire fraud rolls (global generator too) went another way.
	# Seed 3 plays its first weeks alone, then again after seeds 1 and 2, then once more after the leftovers are forced (a
	# long-running office, Dan and Maya at the end of the cast as after an absence, a sales bell still pending); seed 2 is
	# played before and after seed 3. Compared: the office itself at three moments of day 1 (where everybody is, what they
	# do, and a draw from the global generator) and the books week by week.
	bots.ts = 4.0
	bots.stop_day = 3
	bots.frame_hook = _office_hook
	var world := root.get_node("World")
	var o3: Dictionary = await bots.play("owner", "normal", "careful", 3)
	var office3 := _take_office()
	var o1: Dictionary = await bots.play("owner", "normal", "careful", 1)
	var office1 := _take_office()
	var o2: Dictionary = await bots.play("owner", "normal", "careful", 2)
	var office2 := _take_office()
	var o3_after: Dictionary = await bots.play("owner", "normal", "careful", 3)
	var office3_after := _take_office()
	_check(office3.size() == OFFICE_FRAMES.size() and office3 == office3_after, "owner seed 3, day 1: the office is the same alone and after seeds 1 and 2\n     %s\n     %s" % [_first_diff(office3, office3_after), ""])
	_check(_weeks(o3) == _weeks(o3_after), "owner normal careful seed 3, weeks 1-3: alone and after seeds 1 and 2 are the same\n     %s\n     %s" % [_weeks(o3), _weeks(o3_after)])
	var o2_after: Dictionary = await bots.play("owner", "normal", "careful", 2)
	var office2_after := _take_office()
	_check(office2 == office2_after and _weeks(o2) == _weeks(o2_after), "seed 2 before and after seed 3 is the same\n     %s\n     %s" % [_first_diff(office2, office2_after), _weeks(o2_after)])
	_check(_weeks(o1) != _weeks(o3) and office1 != office3, "another owner seed is another game")
	world._total += 98765.4321
	for who in ["Dan", "Maya"]:
		if world.chars.has(who):
			var st: Dictionary = world.chars[who]
			world.chars.erase(who)
			world.chars[who] = st
	if world.chars.has("John"):
		world.chars["John"]["bell"] = true
	var o3_dirty: Dictionary = await bots.play("owner", "normal", "careful", 3)
	var office3_dirty := _take_office()
	_check(office3 == office3_dirty, "and after the leftovers were forced (a long-running office, the cast in another order, a pending bell)\n     %s" % _first_diff(office3, office3_dirty))
	_check(_weeks(o3) == _weeks(o3_dirty), "the books too\n     %s\n     %s" % [_weeks(o3), _weeks(o3_dirty)])
	bots.frame_hook = Callable()
	var order := []
	for who in world.chars:
		order.append(str(who))
	var cast_order := []
	for who in world.CAST.keys() + world.crew_names() + world.staff_names():
		if world.chars.has(who):
			cast_order.append(str(who))
	_check(order == cast_order, "a new game puts the cast back in CAST order: %s" % str(order))
	bots.stop_day = 0
	root.get_node("Campaign").quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
