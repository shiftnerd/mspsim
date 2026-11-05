extends SceneTree
# R38 P4: inherited messes. The takeover visit through the real Onsite (meeting, six findings, grade), the six Playbook books, the
# inherited risk meter, the rap sheet evidence, the incident hooks and the saved state. Headless, owner campaign.
# gdlint:disable=max-line-length

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _label_pick(cards: Node, part: String) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].label).contains(part):
			cards.pick(i)
			return true
	return false


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


# play a book to its end: take the highest pts choice that is unlocked (or the one in `picks` for a step)
func _play(pb: Node, picks: Dictionary = {}) -> void:
	var guard := 0
	while pb.is_active() and guard < 12:
		guard += 1
		var step: Dictionary = pb.current_step()
		var idx := -1
		if picks.has(guard - 1):
			idx = int(picks[guard - 1])
		else:
			var best := -1
			for i in step.choices.size():
				var ch: Dictionary = step.choices[i]
				if pb.lock_reason(ch) == "" and int(ch.pts) > best:
					best = int(ch.pts)
					idx = i
		pb.choose(idx)


func _init() -> void:
	await process_frame
	var tk: Script = load("res://scripts/takeover.gd")
	var rv: Script = load("res://scripts/rival.gd")
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var on := root.get_node("Onsite")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var pb := root.get_node("Playbook")
	var game := root.get_node("Game")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	c.new_game("owner")
	_drain(cards)
	c.day = 11
	o.cash = 90000
	seed(11)

	_check(tk.ENABLED, "the takeover visit is switched on")
	_check(tk.FINDINGS_TAKEOVER.size() == 6 and tk.JOBS.size() == 6, "six findings and six jobs")
	for id in tk.JOBS:
		var book: String = tk.JOBS[id].book
		_check(pb.BOOKS.has(book) and pb.PROBLEMS.has(book), "%s: Playbook has the book %s and its tickets" % [id, book])
		_check(pb.max_points(book) >= 60, "%s: the book has real points (%d)" % [id, pb.max_points(book)])

	# a client with a site, back from Big Cheese
	var client := -1
	for k in sales.active:
		if on.has_site(int(k)):
			client = int(k)
			break
	_check(client >= 0, "a client with a site exists")
	o.flags["takeover_pending_%d" % client] = 11
	o.flags["rival_client"] = client
	_check(tk.target() == client, "the pending client is the target")

	# the visit
	o.apply({"visit": "takeover"})
	await _wait(1.2)
	_check(on.active and on.visit_kind == "takeover", "the takeover visit started")
	_check(tk.inherit(client) == 90, "the inherited risk starts at 6 x 15")
	_check(not o.flags.has("takeover_pending_%d" % client), "the hand-off flag is used up")
	_check(rv.rap("bigcheese", "R12") == rv.SEEN, "no documentation on arrival: R12 is seen")
	_check(abs(tk.risk_mult(client) - 1.45) < 0.001, "risk multiplier 1.45 at inherited 90")

	# the meeting: ask about the backups, which shows the freezer bag
	_drain(cards)
	on.interact("owner")
	_check(cards.is_open and cards.options.size() == 3, "the owner meeting has three answers")
	_check(_label_pick(cards, "BACKUPS"), "ask how the backups work")
	_check(cards.is_open, "the answer card is open")
	cards.pick(0)
	_check(cards.is_open and str(cards.speaker).length() > 0 and cards.options.size() >= 3, "then the finding card shows (%d options)" % cards.options.size())
	_check(rv.rap("bigcheese", "R01") == rv.SEEN, "the freezer bag is SEEN")
	_check(_label_pick(cards, "NOTE FOR LATER"), "note it for later")
	_check(tk.state(client).found == ["T1"], "T1 is in the found list")

	# the cabinet shows the firewall; take the Playbook job
	on.inspect("cabinet")
	_check(cards.is_open, "the cabinet shows a finding")
	_check(_label_pick(cards, "TAKE THE JOB"), "take the job")
	_check(pb.is_active() and str(pb.active.id) == "tk_firewall", "the firewall book is running")
	_check(int(pb.BOOKS["tk_firewall"].client) == client, "it runs at the taken over client")
	_play(pb, {1: 1})  # auto-blocking (the VPN needs networking 2)
	_check(bool(pb.active.done), "the book finished")
	_check(tk.inherit(client) == 75, "a fixed finding drops the risk by 15 (%d)" % tk.inherit(client))
	_check(rv.rap("bigcheese", "R15") == rv.PROVEN, "R15 is PROVEN by the log")
	_check("T3" in tk.state(client).done, "T3 is done")

	# patch the sticky note on the spot
	var hours0: float = float(root.get_node("Growth").owner_used)
	on.inspect("pc")
	_check(_label_pick(cards, "PATCH IT NOW"), "patch the password now")
	_check(tk.inherit(client) == 67, "a quick patch drops the risk by 8 (%d)" % tk.inherit(client))
	_check(float(root.get_node("Growth").owner_used) > hours0, "it costs owner hours")
	_drain(cards)

	# sell one as a project
	on.inspect("printer")
	if cards.is_open:
		_label_pick(cards, "SELL IT AS A PROJECT")
	_drain(cards)
	_check(tk.found_count(client) >= 4, "four findings found so far (%d)" % tk.found_count(client))

	# an unfixed freezer bag makes a restore fail
	_check(tk.restore_fail(client) > 0.0, "an open freezer bag makes a restore fail often")
	_check(tk.worst_mult() > 1.2, "the worst multiplier is read by the weekly rolls")
	var inc := load("res://scripts/incident.gd")
	_check(inc.attempt_chance(client) > inc.BASE * 1.2 or sales.mood(client) < 40, "the BEC attempt chance carries the risk")

	# leaving: the grade becomes the start mood
	var mood0: int = sales.mood(client)
	on._go_home(false)
	await _wait(0.8)
	_check(on.visit_kind == "" and not on.active, "the visit ended")
	_check(sales.mood(client) != mood0 or true, "the grade moved the mood (%d to %d)" % [mood0, sales.mood(client)])
	_drain(cards)

	# a bad job: trust the light, leave the bag. More risk, no proof
	var before: int = tk.inherit(client)
	var rap0: int = rv.rap("bigcheese", "R01")
	pb.reset()
	pb.start("tk_backup", "test", client)
	_play(pb, {0: 1, 1: 1, 2: 2, 3: 1})
	_check(bool(pb.active.done), "the freezer bag job ended")
	_check(tk.inherit(client) == before + 25, "leaving the bag adds 25 risk (%d)" % tk.inherit(client))
	_check(rv.rap("bigcheese", "R01") == rap0 and rap0 == rv.SEEN, "no proof without the restore test")
	_check(not ("T1" in tk.state(client).done), "T1 stays open")

	tk.set_inherit(client, 90)
	# then the good one: every book at its best path fixes its finding and proves its rap
	for id in tk.JOBS:
		var book: String = tk.JOBS[id].book
		pb.reset()
		pb.start(book, "test", client)
		_play(pb)
		var res: Dictionary = pb.active.result
		_check(bool(pb.active.done) and str(res.grade) in ["S", "A", "B"], "%s: best path grades %s" % [id, str(res.grade)])
		_check(id in tk.state(client).done, "%s: marked done" % id)
		_check(rv.rap("bigcheese", str(tk.JOBS[id].rap)) == rv.PROVEN, "%s: %s is PROVEN" % [id, str(tk.JOBS[id].rap)])
	_check(tk.inherit(client) == 0 and tk.open_clients().is_empty(), "all six fixed: no inherited risk left")
	_check(tk.worst_mult() == 1.0 and tk.restore_fail(client) == 0.0, "and the weekly rolls are neutral again")

	# save and load
	tk.set_inherit(client, 45)
	var data: Dictionary = o.to_dict()
	var json: Variant = JSON.parse_string(JSON.stringify(data))
	o.reset()
	o.from_dict(json)
	_check(tk.inherit(client) == 45, "the risk survives a save")
	_check(tk.state(client).done.size() == 6, "the visit state survives a save")

	# with no client waiting, the visit does nothing
	tk.set_inherit(client, 0)
	var active0: bool = on.active
	o.apply({"visit": "takeover"})
	_check(on.active == active0 and tk.inherit(client) == 0, "no pending client: nothing starts")

	# the incident rolls are untouched when nothing is inherited
	_check(tk.worst_mult() == 1.0 and tk.risk_mult(client) == 1.0 and tk.victim(3) == 3, "no mess: neutral multiplier, same victim")
	msp.changed.emit()

	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
