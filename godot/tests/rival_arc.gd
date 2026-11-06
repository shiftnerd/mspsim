extends SceneTree
# R38 rival agent: the 20 week story arc of Big Cheese (rival.gd + the rival_* cards of rival_cards.gd). Headless, seeded.
# Every beat is reachable by its week, evidence only goes up, the ethics gates (slander, vendor report, SHOW THE SHEET), the evidence
# channels (exit chat, John, relabelled poaches, winback), save/load and a deterministic 20 week run.

const ALLOWED := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?-_/()'@#%&+=$<>*{}"
const BEATS := {
	3: "rival_flat",
	5: "rival_wall",
	7: "rival_defect",
	10: "rival_notebook",
	11: "rival_takeover",
	13: "rival_2fa",
	15: "rival_vendor_audit",
	17: "rival_exposed",
	18: "rival_blitz",
	19: "rival_badday",
	20: "rival_end",
}

var failures := 0
var sales: Node


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, policy: Array = []) -> void:
	var n := 0
	while cards.is_open and n < 40:
		var pick := 0
		for want in policy:
			for i in cards.options.size():
				if str(cards.options[i].label).contains(str(want)):
					pick = i
					break
			if pick != 0:
				break
		cards.pick(pick)
		n += 1


func _start(c: Node, cards: Node, o: Node, day: int) -> void:
	c.new_game("owner")
	_clear(cards)
	c.day = day
	o.cash = 90000
	seed(7)


func _strings_of(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for e in v:
			_strings_of(e, out)
	elif v is Dictionary:
		for k in v:
			_strings_of(v[k], out)


# the arc the way the game plays it: the morning shows the queued beat, the settle queues the next one
func _run(c: Node, cards: Node, o: Node, rival: Script, policy: Array) -> Dictionary:
	var shown := {}
	var levels := []
	for w in range(1, 21):
		c.day = w
		var before: Array = o.flags.keys()
		rival.morning(o)
		_clear(cards, policy)
		for k in o.flags:
			if str(k).begins_with("arc_rival") and not before.has(k):
				shown[str(k).substr(4)] = w
		rival.arc_week(o, w)
		var snap := {}
		for r in rival.RIVALS:
			for h in rival.RIVALS[r].habits:
				snap[rival.key(str(r), str(h))] = rival.rap(str(r), str(h))
		levels.append(snap)
	return {"shown": shown, "levels": levels}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var d := root.get_node("Difficulty")
	sales = root.get_node("Sales")
	var rival: Script = load("res://scripts/rival.gd")
	var habits: Script = load("res://scripts/habits.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- the cards: all there, charset, period
	for w in BEATS:
		var id: String = BEATS[w]
		_check(
			o.CARDS.has(id) and not o.CARDS[id].options.is_empty(), "%s exists with options" % id
		)
		_check(rival.ARC.get(w, "") == id, "%s is in the arc at week %d" % [id, w])
	for id in o.RivalCards.CARDS:
		if not str(id).begins_with("rival_"):
			continue
		var all := []
		_strings_of(o.RivalCards.CARDS[id], all)
		var bad := ""
		for s in all:
			for i in str(s).length():
				if not ALLOWED.contains(str(s)[i]):
					bad = "%s in %s" % [str(s)[i], id]
			var low := " " + str(s).to_lower() + " "
			for word in [" ai ", "mfa", "slack", "teams", "windows 10", "chatgpt"]:
				if low.contains(word):
					bad = "%s in %s" % [word, id]
		_check(bad == "", "%s: 3x5 charset and 2013-14 words %s" % [id, bad])

	# ---- every beat is reachable by its week (the client leaves by the exit chat, so the Delia beats follow)
	_start(c, cards, o, 1)
	d.seed_run(4711)
	_start(c, cards, o, 1)
	var run := _run(c, cards, o, rival, ["EXIT CHAT", "CONTRACT", "ONE PAGE", "WIN THE CLIENT"])
	for w in BEATS:
		var id: String = BEATS[w]
		_check(
			int(run.shown.get(id, -1)) == w,
			"%s shown in week %d (got %d)" % [id, w, int(run.shown.get(id, -1))]
		)
	# evidence only goes up, week after week
	var monotone := true
	for i in range(1, run.levels.size()):
		for k in run.levels[i]:
			if int(run.levels[i][k]) < int(run.levels[i - 1][k]):
				monotone = false
	_check(monotone, "evidence never goes down over 20 weeks")
	_check(rival.rap("bigcheese", "R03") >= 2, "the two-factor beat gave SEEN")
	_check(rival.rap("bigcheese", "R06") == 3, "the vendor letter is PROVEN")
	_check(rival.rap("bigcheese", "R09") == 3, "the exposed reviews are PROVEN")
	_check(rival.rap("bigcheese", "R11") >= 2, "the exit chat gave SEEN on the flat price")
	_check(
		rival.rap("bigcheese", "R17") >= 2 and rival.rap("bigcheese", "R16") >= 2,
		"the notebook gave the front desk and the clock change"
	)
	var rc: int = rival.arc_client()
	_check(
		rc >= 0 and o.flags.has("takeover_pending_%d" % rc) and sales.active.has(rc),
		"the client came back with the inherited mess flag for the takeover agent"
	)
	_check(o.flags.get("rival_returned", 0) == 11, "the takeover card of week 11 brought them back")

	# ---- 20 weeks, deterministic: the same seed and the same choices give the same book
	var sig := []
	for pass_no in 2:
		d.seed_run(31337)
		_start(c, cards, o, 1)
		var r2 := _run(c, cards, o, rival, ["EXIT CHAT", "CONTRACT", "ONE PAGE", "WARN THEM"])
		(
			sig
			. append(
				[
					JSON.stringify(r2.shown),
					JSON.stringify(r2.levels),
					c.rep,
					o.cash,
					sales.active.duplicate(),
					o.consc,
				]
			)
		)
	_check(sig[0] == sig[1], "two runs with one seed and one set of choices are identical")

	# ---- the relabel: half of the poaches from week 6 are Big Cheese, none before, and no extra rolls
	_start(c, cards, o, 5)
	d.seed_run(99)
	var made := 0
	var early := 0
	var items := 0
	for week in [5, 9]:
		for n in 100:
			c.day = week
			o._dynamic["poach_price"] = {
				"speaker": "John Marlowe",
				"text": "A rival: %s." % o.COMPETITOR,
				"options":
				[
					{"label": "WISH THEM WELL", "fx": {"drop_client": 1, "left_for": "price"}},
					{
						"label": "SHOW THEM THE VALUE",
						"roll":
						[
							[0.5, {"cash": -250}, "stay"],
							[0.5, {"drop_client": 1, "left_for": "price"}, "go"]
						]
					},
				],
			}
			var opts_before := 2
			seed(5)
			var a := randi()
			seed(5)
			rival.relabel(o, "poach_price", 1)
			var b := randi()
			if a != b:
				failures += 1
				print("FAIL relabel used the global rolls")
			items += 1
			var card: Dictionary = o._dynamic["poach_price"]
			if card.options.size() > opts_before:
				if week == 5:
					early += 1
				else:
					made += 1
	_check(early == 0, "no Big Cheese poach label before week 6")
	_check(
		made > 30 and made < 70,
		"about half of the poaches are Big Cheese from week 6 (%d of 100)" % made
	)
	_check(items == 200, "relabel never changes the number of poach cards")
	# a relabelled card names Big Cheese, tags the leaver in every drop and offers the exit chat
	c.day = 9
	var tagged := false
	for n in 20:
		o._dynamic["poach_price"] = {
			"speaker": "V",
			"text": "x %s y" % o.COMPETITOR,
			"options": [{"label": "L", "fx": {"drop_client": 1, "left_for": "price"}}],
		}
		rival.relabel(o, "poach_price", 1)
		var cd: Dictionary = o._dynamic["poach_price"]
		if cd.options.size() == 2:
			tagged = (
				str(cd.text).contains("Big Cheese")
				and cd.options[0].fx.has("rival")
				and str(cd.options[1].label).contains("NEW IT PERSON")
			)
			break
	_check(tagged, "a relabelled poach names Big Cheese and gains ASK WHO THEIR NEW IT PERSON IS")
	# the exit chat sets the flat price evidence and tags the client
	_start(c, cards, o, 9)
	var gone_client: int = int(sales.active[0])
	o.apply(
		{
			"drop_client": gone_client,
			"left_for": "price",
			"rival": {"tag": gone_client, "exit": gone_client}
		}
	)
	_check(rival.rap("bigcheese", "R11") == 2, "the exit chat gave R11 SEEN")
	_check(
		str(o.gone[gone_client].get("rival", "")) == "bigcheese",
		"the leaver is tagged for the winback"
	)
	o._dynamic["winback"] = {"speaker": "V", "text": "x %s y" % o.COMPETITOR, "options": []}
	rival.on_winback(o, gone_client)
	_check(
		(
			o.flags.has("takeover_pending_%d" % gone_client)
			and str(o._dynamic["winback"].text).contains("Big Cheese")
		),
		"the winback card carries the inherited mess flag"
	)
	var parsed: Variant = JSON.parse_string(JSON.stringify(o.to_dict()))
	_start(c, cards, o, 1)
	o.from_dict(parsed)
	_check(
		(
			str(o.gone[gone_client].get("rival", "")) == "bigcheese"
			and o.flags.has("takeover_pending_%d" % gone_client)
			and rival.rap("bigcheese", "R11") == 2
		),
		"the tag, the flag and the rap sheet survive a JSON save"
	)

	# ---- John's intel: a rumour only, from the pool, never lowers anything
	_start(c, cards, o, 6)
	d.seed_run(5)
	var heard := ""
	for n in 12:
		heard = rival.intel("bigcheese")
		if heard != "":
			break
	_check(
		heard != "" and rival.rap("bigcheese", heard) == rival.RUMOUR,
		"John hears a rumour: %s" % heard
	)
	rival.set_rap("bigcheese", heard, rival.SEEN)
	for n in 12:
		rival.intel("bigcheese")
	_check(rival.rap("bigcheese", heard) == rival.SEEN, "a rumour never lowers what you saw")
	var findings: Array = rival.assessment("bigcheese")
	_check(
		findings.size() >= 3 and findings.size() <= 5 and findings[0] == heard,
		"the assessment lists the known habit first"
	)

	# ---- the decision: gates and consequences
	_start(c, cards, o, 13)
	rival.set_rap("bigcheese", "R03", rival.RUMOUR)
	rival.show(o, "rival_decide", "R03")
	_check(
		cards.options.size() == 3,
		"REPORT TO THE VENDOR is not offered for a habit a vendor cannot act on"
	)
	_clear(cards)
	rival.set_rap("bigcheese", "R06", rival.SEEN)
	rival.show(o, "rival_decide", "R06")
	_check(cards.options.size() == 3, "REPORT TO THE VENDOR needs PROVEN (SEEN is not enough)")
	_clear(cards)
	rival.set_rap("bigcheese", "R06", rival.PROVEN)
	rival.show(o, "rival_decide", "R06")
	_check(cards.options.size() == 4, "REPORT TO THE VENDOR appears with PROVEN")
	var labels := []
	for opt in cards.options:
		labels.append(str(opt.label))
	_check(
		(
			labels[0].begins_with("WIN THE CLIENT")
			and labels[1].begins_with("WARN")
			and labels[2].begins_with("REPORT")
			and labels[3].begins_with("IGNORE")
		),
		"the four options: win, warn, report, ignore"
	)
	_clear(cards)
	# slander: warning on a rumour costs reputation and conscience and brings Rex's counter-rumour
	_start(c, cards, o, 13)
	rival.set_rap("bigcheese", "R03", rival.RUMOUR)
	o.flags["rival_dh"] = "R03"
	var rep0: int = c.rep
	var consc0: int = o.consc
	o.apply({"rival": {"decide": "warn"}})
	_check(
		c.rep == rep0 - 2 and o.consc == consc0 - 1,
		"warning on a rumour is slander (rep -2, conscience -1)"
	)
	_check(
		(o.flags.get("arc_queue", []) as Array).has("rival_counter"),
		"and Rex answers with a counter-rumour card"
	)
	# a warning on what you saw is rewarded (once a week for the conscience)
	_start(c, cards, o, 13)
	rival.set_rap("bigcheese", "R03", rival.SEEN)
	o.flags["rival_dh"] = "R03"
	rep0 = c.rep
	consc0 = o.consc
	o.apply({"rival": {"decide": "warn"}})
	_check(
		c.rep == rep0 + 1 and o.consc == consc0 + 1,
		"an ethical warning gives rep +1 and conscience +1"
	)
	# ignore: a later "you knew" card, only when you had seen it
	_start(c, cards, o, 13)
	o.flags["rival_dh"] = "R03"
	o.apply({"rival": {"decide": "ignore"}})
	_check(
		not o.flags.has("rival_knew_R03"), "ignoring a habit you never saw leaves nothing to know"
	)
	rival.set_rap("bigcheese", "R03", rival.SEEN)
	o.apply({"rival": {"decide": "ignore"}})
	_check(int(o.flags.get("rival_knew_R03", 0)) == 13, "ignoring a SEEN habit is remembered")
	rival.arc_week(o, 14)
	_check(
		not (o.flags.get("arc_queue", []) as Array).has("rival_knew|R03"), "too early for the card"
	)
	o.flags["arc_queue"] = []
	rival.arc_week(o, 21)
	_check(
		(o.flags.get("arc_queue", []) as Array).has("rival_knew|R03"),
		"the you knew card comes later"
	)
	rival.morning(o)
	_check(
		cards.is_open and str(cards.text).contains("two-factor"),
		"the card names the habit you ignored"
	)
	_clear(cards)
	# the vendor report brings the retaliation
	_start(c, cards, o, 15)
	rival.set_rap("bigcheese", "R06", rival.PROVEN)
	o.flags["rival_dh"] = "R06"
	o.apply({"rival": {"decide": "vendor"}})
	rep0 = c.rep
	rival.arc_week(o, 16)
	_check(c.rep == rep0 - 1, "Rex retaliates a week later")

	# ---- SHOW THE SHEET needs proof and a good Standard
	_start(c, cards, o, 18)
	rival.show(o, "rival_blitz", "")
	_check(cards.options.size() == 3, "no SHOW THE SHEET without proof")
	_clear(cards)
	rival.set_rap("bigcheese", "R06", rival.PROVEN)
	rival.show(o, "rival_blitz", "")
	_check(cards.options.size() == 3, "no SHOW THE SHEET with proof but no Standard")
	_clear(cards)
	for h in habits.all():
		habits.start(str(h))
	_check(
		habits.standard() >= 60,
		"all habits started make a Standard of 60 or more (%d)" % habits.standard()
	)
	rival.show(o, "rival_blitz", "")
	_check(cards.options.size() == 4, "SHOW THE SHEET appears with proof and a good Standard")
	_clear(cards)

	# ---- beats that do not apply are dropped quietly
	_start(c, cards, o, 11)
	o.flags["arc_queue"] = ["rival_takeover"]
	rival.morning(o)
	_check(not cards.is_open, "no takeover card when nobody left")
	_start(c, cards, o, 10)
	o.flags["arc_queue"] = ["rival_notebook"]
	rival.morning(o)
	_check(not cards.is_open, "no notebook when nobody left")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
