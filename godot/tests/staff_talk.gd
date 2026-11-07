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
	# the Lync list and the phone list
	var lync := root.get_node("Lync")
	var contacts: Array = lync.contacts()
	var four := ["Jen", "Michael", "Christy", "Adam"].all(func(n: String) -> bool: return contacts.has(n))
	_check(four, "the four are on the Lync list (%s)" % str(contacts))
	var Calls = load("res://scripts/phone_calls.gd")
	var ids := []
	for k in Calls.contacts():
		ids.append(str(k.id))
	var once: bool = ids.has("adam") and ids.has("michael") and not ids.has("w:Adam") and not ids.has("w:Michael")
	_check(ids.has("w:Jen") and ids.has("w:Christy") and once, "the phone list: Jen and Christy as coworkers, Adam and Michael once each (%s)" % str(ids))
	c.new_game("service")
	_check(not lync.contacts().has("Jen") and not lync.contacts().has("Adam"), "none of them is on the service campaign's list")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
