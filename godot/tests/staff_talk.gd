extends SceneTree
# Jen, Michael and Christy can be talked to: a greeting for every mood, small talk, tips and a label.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var talk := root.get_node("Talk")
	var social := root.get_node("Social")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	for who in ["Jen", "Michael", "Christy"]:
		for tier in ["friend", "neutral", "cold"]:
			_check(str(talk.GREETINGS[who].get(tier, "")) != "", "%s has a %s greeting" % [who, tier])
		_check((talk.SMALL[who] as Array).size() >= 4, "%s has small talk" % who)
		_check((talk.TIPS_GENERIC[who] as Array).size() >= 3, "%s has tips" % who)
		_check(social.role(who) != "", "%s has a label (%s)" % [who, social.role(who)])
	var cards := root.get_node("Cards")
	while cards.is_open:
		cards.pick(0)
	_check(talk.available("Jen") and talk.available("Michael") and talk.available("Christy"), "all three can be talked to in the campaign")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
