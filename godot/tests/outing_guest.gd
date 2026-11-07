extends SceneTree
# R5: in the owner campaign John sometimes brings a client; the invitation says so and the client's mood goes up after the evening.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var sales := root.get_node("Sales")
	var diff := root.get_node("Difficulty")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	c.new_game("tech")
	diff.seed_run(5)
	o.draw_party()
	_check(o.guest_client == -1 and not o.coming_text().contains("bringing"), "the tech campaign: nobody brings a client")
	c.new_game("owner")
	while root.get_node("Cards").is_open:
		root.get_node("Cards").pick(0)
	var got := 0
	var with_john := 0
	var client := -1
	for s in 40:
		diff.seed_run(900 + s)
		o.party_set = false
		o.draw_party()
		if o.party.has("John"):
			with_john += 1
			if o.guest_client >= 0:
				got += 1
				client = o.guest_client
	_check(with_john > 0 and got == with_john, "whenever John comes in the owner campaign he brings a client (%d of %d)" % [got, with_john])
	o.guest_client = client
	o.party = ["John", "Alan"]
	o.party_set = true
	var cl: Dictionary = root.get_node("Msp").CLIENTS[client]
	_check(o.coming_text().contains("John is bringing %s" % str(cl.contact)), "the invitation says so: %s" % o.coming_text())
	var before: int = sales.mood(client)
	o.game = "karaoke"
	o.g = {}
	o.lines = []
	o._finish(2)
	var happier: bool = sales.mood(client) > before and o.guest_client == -1 and str(o.lines).contains("ENJOYED THE EVENING")
	_check(happier, "after the night the client is happier (%d to %d)" % [before, sales.mood(client)])
	diff.seed_run(900)
	o.party_set = false
	o.draw_party()
	var nobody: bool = not o.party.has("John") or o.guest_client >= 0
	_check(nobody, "and a night without John has no guest")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
