extends SceneTree
# gdlint:disable=max-line-length
# X12 housekeeping: the takeover visit through its REAL trigger, as a scripted run (tests/takeover.gd starts the visit by setting the
# hand-off flag itself). The rival arc is played the way the owner campaign plays it: week 6 settles and queues the week 7 notice,
# the client leaves for Big Cheese, week 10 settles and queues the week 11 card, "{client} wants to come back", SEND DAN FOR A
# TAKEOVER ASSESSMENT brings the client back and starts the onsite visit. Then the whole text of the visit is read: the trigger
# card, the owner meeting, the six finding cards with their answers and the six Playbook jobs. "Reads" = not empty, only characters
# the pixel font has, no placeholder left in, and the card fits the screen in the wide, 16:9 and tall formats.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/takeover_trigger.gd

const PixelFont := preload("res://scripts/pixelfont.gd")
const SIZES := {"wide": Vector2(368, 128), "h": Vector2(320, 180), "v": Vector2(180, 320)}

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _drain(cards: Node) -> void:
	var guard := 0
	while cards.is_open and guard < 20:
		cards.pick(0)
		guard += 1


func _label_pick(cards: Node, part: String) -> bool:
	for i in cards.options.size():
		if str(cards.options[i].label).contains(part):
			cards.pick(i)
			return true
	return false


# "" when the text reads, else what is wrong with it
func _reads(text: String) -> String:
	if text.strip_edges() == "":
		return "empty"
	if text.contains("{") or text.contains("%s") or text.contains("%d"):
		return "a placeholder is left in: " + text.left(60)
	for ch in text.to_upper():
		if ch != " " and ch != "\n" and not PixelFont.GLYPHS.has(ch):
			return "no glyph for '%s' in: %s" % [ch, text.left(60)]
	return ""


# the height of a card with this text and these options in a format (the arithmetic of Cards._paint), and the screen's
func _card_height(cards: Node, text: String, options: Array, size: Vector2) -> float:
	var pw := minf(size.x - 8.0, 250.0)
	var chars := int((pw - 10.0) / 4.0)
	var lines := 0
	for para in text.split("\n"):
		lines += cards._wrap(para, chars).size()
	var opts_h := 0.0
	var tap_h := 19.0 if size.y > size.x else 0.0
	for i in options.size():
		var full := "%d. %s" % [i + 1, str(options[i].label)]
		opts_h += maxf(3.0 + 7.0 * float(cards._wrap(full, chars - 1).size()), tap_h) + 1.0
	return 12.0 + float(lines) * 7.0 + 4.0 + opts_h + 4.0


# the open card: reads and fits in every format. Returns "" or the complaint
func _card_ok(cards: Node) -> String:
	var bad := _reads(str(cards.text))
	if bad == "":
		bad = _reads(str(cards.speaker))
	for o in cards.options:
		if bad == "":
			bad = _reads(str(o.label))
	for fmt in SIZES:
		var h := _card_height(cards, str(cards.text), cards.options, SIZES[fmt])
		if bad == "" and h > float(SIZES[fmt].y) - 8.0:
			bad = "%d px high on the %s screen (%d)" % [int(h), fmt, int(SIZES[fmt].y)]
	return bad


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
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	root.get_node("Difficulty").set_tier("normal")
	root.get_node("Difficulty").seed_run(1911)
	c.new_game("owner")
	_drain(cards)
	o.cash = 90000

	# ---- week 6 settles: the notice is queued for the week 7 morning
	var client := -1
	for k in sales.active:
		if on.has_site(int(k)):
			client = int(k)
			break
	_check(client >= 0 and sales.active.size() >= 2, "the owner has a client with an office to visit")
	for k in sales.active:
		sales.satisfaction[int(k)] = 40 if int(k) == client else 75  # the least happy client is the one Big Cheese gets
	c.day = 6
	rv.arc_week(o, 6)
	_check(o.flags.get("arc_queue", []).has("rival_defect"), "week 6 queues the week 7 notice")
	c.day = 7
	rv.morning(o)
	_check(cards.is_open and rv.arc_client() == client and str(cards.text).contains(str(root.get_node("Msp").CLIENTS[client].name)), "week 7: the notice names the least happy client")
	_check(_card_ok(cards) == "", "the notice card reads %s" % _card_ok(cards))
	_check(_label_pick(cards, "WISH THEM WELL"), "you wish them well")
	_drain(cards)
	_check(not sales.active.has(client) and o.gone.has(client) and rv.defected(client), "they are gone to Big Cheese")

	# ---- week 10 settles: the takeover card is queued for the week 11 morning
	c.day = 10
	rv.arc_week(o, 10)
	_check(o.flags.get("arc_queue", []).has("rival_takeover"), "week 10 queues the week 11 card")
	c.day = 11
	var cash0: int = o.cash
	# (the notebook beat of week 10 may still be waiting in the queue: one card a morning)
	var guard := 0
	while guard < 4 and not (cards.is_open and str(cards.text).contains("wants to come back")):
		_drain(cards)
		rv.morning(o)
		guard += 1
	_check(cards.is_open and str(cards.text).contains("wants to come back") and str(cards.text).contains(str(root.get_node("Msp").CLIENTS[client].name)), "week 11: they want to come back, by name")
	_check(_card_ok(cards) == "", "the takeover card reads %s" % _card_ok(cards))
	_check(str(cards.options[0].label).begins_with("SEND DAN FOR A TAKEOVER ASSESSMENT"), "the first answer sends Dan for the assessment")

	# ---- the real trigger: the answer brings the client back AND starts the visit
	cards.pick(0)
	_check(sales.active.has(client), "the client is back")
	_check(o.cash == cash0 - 300, "the assessment costs $300")
	await _wait(1.2)
	_drain(cards)  # the answer's own line
	await _wait(0.3)
	_check(on.active and on.visit_kind == "takeover" and on._site_client() == client, "the takeover visit starts at their office (active %s, kind %s)" % [str(on.active), str(on.visit_kind)])
	_check(tk.inherit(client) == 6 * tk.PER_FINDING and not o.flags.has("takeover_pending_%d" % client), "six findings are waiting, the hand-off flag is used up")
	_check(tk.state(client).has("found") and tk.found_count(client) == 0, "nothing found yet")

	# ---- the visit, read card by card
	_drain(cards)
	on.interact("owner")
	_check(cards.is_open and str(cards.text) == str(tk.MEETING.text) and cards.options.size() == 3, "the owner meets you with the takeover meeting")
	_check(_card_ok(cards) == "", "the meeting reads %s" % _card_ok(cards))
	for opt in tk.MEETING.options:
		_check(_reads(str(opt.text)) == "", "meeting answer %s reads %s" % [str(opt.id), _reads(str(opt.text))])
	_label_pick(cards, "FRESH START")
	_drain(cards)
	var seen := {}
	var site_type := str(on.SITES[client].type)
	var objects: Array = on.OBJECTS[site_type].duplicate()
	for extra in ["pc", "printer", "cabinet", "server", "vip", "exam", "xray"]:
		if not objects.has(extra):
			objects.append(extra)  # six findings, five or six objects: the later ones show what is still hidden
	for obj in objects:
		on._inspected.erase(obj)
		on.inspect(obj)
		if not cards.is_open:
			continue
		var title := str(cards.speaker)
		var job := ""
		for id in tk.JOBS:
			if title.ends_with(str(tk.JOBS[id].name)):
				job = id
		_check(job != "" and title.begins_with(str(tk.TEXT.title)), "%s shows a finding: %s" % [obj, title])
		_check(str(cards.text) == str(tk._entry(job).text) and _card_ok(cards) == "", "%s: the card reads %s" % [job, _card_ok(cards)])
		_check(cards.options.size() >= 3 and str(cards.options[0].label) in [str(tk.TEXT.job), str(tk.TEXT.job_busy)], "%s: take the job, patch it, sell it or note it (%d answers)" % [job, cards.options.size()])
		_check(_reads(str(tk._entry(job).quick)) == "" and _reads(str(tk._entry(job).summary)) == "", "%s: the quick patch line and the ticket summary read" % job)
		seen[job] = true
		_label_pick(cards, "NOTE FOR LATER")
		_drain(cards)
	_check(seen.size() == 6 and tk.found_count(client) == 6, "all six findings come up on the walk-around (%s)" % str(seen.keys()))
	on._inspected.clear()
	on.inspect("pc")
	_check(not cards.is_open, "a seventh look finds nothing more")

	# ---- the six jobs: every step and every choice reads, and the job runs from the finding card
	for id in tk.JOBS:
		var book: Dictionary = pb.BOOKS[str(tk.JOBS[id].book)]
		var bad := _reads(str(book.title))
		var steps := 0
		for step in book.steps:
			steps += 1
			for part in [str(step.title), str(step.text)]:
				if bad == "":
					bad = _reads(part)
			for ch in step.choices:
				for part in [str(ch.label), str(ch.note)]:
					if bad == "":
						bad = _reads(part)
				if bad == "" and str(ch.label).length() > 44:
					bad = "a choice of %d characters: %s" % [str(ch.label).length(), str(ch.label)]
		_check(bad == "" and steps >= 3, "%s %s: %d steps, all of it reads %s" % [id, str(book.title), steps, bad])
	on._inspected.clear()
	tk.show_finding(client, tk._entry("T2"))
	_check(_label_pick(cards, "TAKE THE JOB") and pb.is_active() and str(pb.active.id) == "tk_creds", "TAKE THE JOB starts the Playbook job of that finding")
	_check(int(pb.BOOKS["tk_creds"].client) == client, "at the client who came back")
	_drain(cards)

	# ---- leaving grades the visit
	on._go_home(false)
	await _wait(0.8)
	_drain(cards)
	_check(not on.active and on.visit_kind == "", "the visit ends when you drive home")

	# ---- the same run with a client who has no office to visit: they come back, no visit, and no mess is inherited unseen
	c.new_game("owner")
	_drain(cards)
	o.cash = 90000
	var remote := -1
	for k in sales.active:
		if not on.has_site(int(k)):
			remote = int(k)
			break
	if remote >= 0:
		for k in sales.active:
			sales.satisfaction[int(k)] = 40 if int(k) == remote else 75
		c.day = 6
		rv.arc_week(o, 6)
		c.day = 7
		rv.morning(o)
		_label_pick(cards, "WISH THEM WELL")
		_drain(cards)
		c.day = 10
		rv.arc_week(o, 10)
		c.day = 11
		guard = 0
		while guard < 4 and not (cards.is_open and str(cards.text).contains("wants to come back")):
			_drain(cards)
			rv.morning(o)
			guard += 1
		_check(cards.is_open and rv.arc_client() == remote, "a client without an office wants to come back too")
		cards.pick(0)
		await _wait(1.0)
		_drain(cards)
		_check(sales.active.has(remote) and not on.active, "they are back, and there is no office to drive to")
		_check(tk.inherit(remote) == 0 and tk.state(remote).is_empty() and tk.worst_mult() == 1.0, "nothing is inherited without a visit (no risk that could never be looked at)")
	else:
		_check(true, "(every client of this seed has an office)")
	print("takeover_trigger: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
