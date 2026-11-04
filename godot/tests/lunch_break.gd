extends SceneTree
# gdlint:disable=max-line-length
# THE CAMPAIGN LUNCH BREAK (R29): on some days a midday card offers the cookout or cornhole in the warehouse (skippable), the break
# takes an hour on the clock and ages the queue a little (not on Cozy Easy), pays small rewards (opinions, energy, owner burnout,
# never reputation), is not counted as a team outing, costs the owner nothing, is offered once a day, is saved with the resume
# point and the career file, and stays out of the sales campaign and the evening outing days.
# Headless: Outings.maybe_lunch / press / _finish / close, no room.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _ticket(left: float) -> Dictionary:
	return {"id": 9001, "status": "Open", "sla_total": 600.0, "sla_left": left}


# a new game without the cards its start opens, and the clock running
func _new(c: Node, cards: Node, world: Node, mode: String) -> void:
	c.new_game(mode)
	cards.is_open = false
	cards._queue.clear()
	cards._canvas.visible = false
	world.time_scale = 1.0


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Outings")
	var cards := root.get_node("Cards")
	var social := root.get_node("Social")
	var world := root.get_node("World")
	var owner := root.get_node("Owner")
	var shift := root.get_node("Shift")
	var game := root.get_node("Game")
	var d := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var career := root.get_node("Career")
	var resume := root.get_node("Resume")
	c.save_prefix = "user://test_lunch_%d_" % OS.get_process_id()
	career.reset_all()
	game.title_mode = false
	o.enabled = true
	o.use_rooms = false
	d.set_tier("normal")

	# ---- which days
	_new(c, cards, world, "tech")
	for day in [3, 7, 12, 17]:
		c.day = day
		_check(o.lunch_day() and not o.invite_day(), "tech day %d has a lunch break" % day)
	for day in [1, 2, 4, 5, 6, 10, 15, 20]:
		c.day = day
		_check(not o.lunch_day(), "tech day %d has none" % day)
	for day in o.LUNCH_TECH:
		_check(not o.TECH_DAYS.has(day), "lunch day %d is not an evening outing day" % day)
	for day in o.LUNCH_OWNER:
		_check(not o.OWNER_WEEKS.has(day), "owner lunch week %d is not an evening outing week" % day)
	d.set_tier("easy")
	c.day = 2
	_check(o.lunch_day(), "Cozy Easy: lunch is offered on an ordinary day")
	c.day = 5
	_check(not o.lunch_day(), "Cozy Easy: but not on the evening outing day")
	d.set_tier("normal")
	_new(c, cards, world, "sales")
	c.day = 3
	_check(not o.lunch_day(), "the sales campaign has no lunch break")
	_new(c, cards, world, c.FREE)
	_check(not o.lunch_day(), "Free Play has none (the boards and the grill are there to use)")

	# ---- when
	_new(c, cards, world, "tech")
	c.day = 3
	world.clock = 11.9
	_check(not o.lunch_due(), "not before noon")
	world.clock = 12.2
	_check(o.lunch_due(), "at noon on a lunch day it is due")
	world.clock = 13.6
	_check(not o.lunch_due(), "not after half past one")
	world.clock = 12.2
	o.enabled = false
	_check(not o.lunch_due(), "outings off: no lunch card")
	o.enabled = true
	world.time_scale = 0.0
	_check(not o.lunch_due(), "not while the clock is stopped")
	world.time_scale = 1.0

	# ---- the card, skipping
	social.rel["Alan"] = 10
	o.maybe_lunch()
	_check(cards.is_open and cards.options.size() == 3 and cards.speaker.contains("Garrison"), "Garrison offers cookout, cornhole or skip")
	_check(str(cards.text).contains("lunch") or str(cards.text).contains("Lunch"), "the card is about lunch")
	cards.pick(2)
	_check(o.lunch_skips == 1 and social.value("Alan") == 10 and not o.is_open, "skipping costs nothing")
	o.maybe_lunch()
	_check(not cards.is_open, "offered once a day")
	_check(not o.lunch_due(), "and not due again")
	c.day_started.emit(3)
	_check(not o._lunch_offered, "a new day offers again")

	# ---- saved and resumed
	o._lunch_offered = true
	var rd: Dictionary = resume.day_dict()
	o._lunch_offered = false
	resume.apply_day(rd)
	_check(o._lunch_offered, "the resume point remembers that today's lunch card was shown")
	o.lunches = 4
	o.lunch_skips = 2
	var saved: Dictionary = o.to_dict()
	o.reset()
	_check(o.lunches == 0 and o.lunch_skips == 0, "reset clears the lunch counters")
	o.from_dict(saved)
	_check(o.lunches == 4 and o.lunch_skips == 2, "the save keeps lunches and skips")
	o.from_dict({"version": 2, "count": 1})
	_check(o.lunches == 0, "an older save has none")
	o.from_dict(saved)
	o.lunches = 0
	o.lunch_skips = 0

	# ---- taking the cookout: short, free for the owner, no reputation
	_new(c, cards, world, "tech")
	c.day = 7
	world.clock = 12.4
	msp.tickets.clear()
	msp.tickets.append(_ticket(500.0))
	msp.tickets.append({"id": 9002, "status": "Closed", "sla_total": 600.0, "sla_left": 500.0})
	social.rel["Alan"] = 10
	var energy0: float = shift.energy
	var rep0: int = c.rep
	o.maybe_lunch()
	cards.pick(0)
	_check(o.is_open and o.game == "grill" and o.lunch_on() and o.phase == "intro", "COOKOUT starts the grill as a lunch")
	_check(not o._from_invite, "a lunch is not the evening invitation")
	var gp: Dictionary = o._grill_params()
	_check(int(gp.tickets) == 4 and is_equal_approx(float(gp.time), 60.0) and float(gp.dogs) > 0.0, "a short round: 4 tickets, 60 seconds, with dogs")
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.game.total() == 4, "the game plays with four orders")
	var clock0: float = world.clock
	o._finish(3)
	_check(o.stars == 3 and shift.energy > energy0, "a good lunch gives energy")
	_check(social.value("Alan") == 12, "three stars at lunch: +2 opinions, not +4 (%d)" % social.value("Alan"))
	_check(o.lines.any(func(l: String) -> bool: return l.contains("GOOD LUNCH")), "the result page says a good lunch helps: %s" % str(o.lines))
	_check(c.rep == rep0, "no reputation for a lunch, even at three stars")
	_check(career.value("lunches") == 1 and career.value("outings") == 0 and career.value("stars.grill") == 3, "the career counts a lunch, not a team outing, and the best stars")
	o.press(KEY_ENTER)
	_check(not o.is_open and absf(world.clock - (clock0 + o.LUNCH_LEN)) < 0.001, "the break takes 45 minutes on the clock")
	_check(float(msp.tickets[0].sla_left) < 500.0 and float(msp.tickets[0].sla_left) > 450.0, "the open queue aged a little (%.1f)" % msp.tickets[0].sla_left)
	_check(float(msp.tickets[1].sla_left) == 500.0, "a closed ticket did not")
	_check(o.lunches == 1 and not o.lunch_on(), "the break is counted and the lunch flag cleared")
	_check(world.chars.values().all(func(st: Dictionary) -> bool: return bool(st.lunched)), "nobody lunches a second time")
	var sla := float(msp.tickets[0].sla_left)
	_check(not o.lunch_due(), "no second lunch that day")

	# ---- cornhole at lunch is a short game
	c.day = 12
	o._lunch_offered = false
	world.clock = 12.3
	d.set_tier("hard")
	o.maybe_lunch()
	cards.pick(1)
	_check(o.game == "cornhole" and o.lunch_on() and int(o._corn_params().to) == 11, "CORNHOLE at lunch plays to 11 even on hard")
	d.set_tier("normal")
	o.press(KEY_ESCAPE)
	_check(o.phase == "result" and o.stars == -1 and o.lines[0].contains("HEAD BACK"), "leaving at the intro is just going back to the desk")
	_check(social.value("Alan") == 12, "no goodwill lost for leaving a lunch")
	o.press(KEY_ENTER)
	_check(not o.is_open, "the card closes")

	# ---- Cozy Easy: no ticket ages
	d.set_tier("easy")
	_new(c, cards, world, "tech")
	c.day = 2
	world.clock = 12.5
	msp.tickets.clear()
	msp.tickets.append(_ticket(500.0))
	o.maybe_lunch()
	_check(cards.is_open and str(cards.text).contains("queue"), "Cozy Easy: the card promises the queue will wait")
	cards.pick(0)
	o.press(KEY_ENTER)
	o._finish(1)
	o.press(KEY_ENTER)
	_check(float(msp.tickets[0].sla_left) == 500.0 and not o.is_open, "Cozy Easy: nothing in the queue aged")
	_check(world.clock <= world.DAY_END - 0.25, "a lunch never ends the day")
	d.set_tier("normal")

	# ---- the owner campaign: free, burnout down, no cash
	_new(c, cards, world, "owner")
	c.day = 7
	world.clock = 12.2
	owner.cash = 5000
	owner.burnout = 30.0
	o.maybe_lunch()
	_check(cards.is_open and cards.speaker.contains("Co-owner") and str(cards.text).contains("company"), "owner: a co-owner says lunch is on the company")
	cards.pick(0)
	_check(owner.cash == 5000 and o.game == "grill", "the owner pays nothing for lunch")
	o.press(KEY_ENTER)
	o._finish(2)
	_check(owner.burnout == 26.0, "burnout down 4 after a two star lunch (%.1f)" % owner.burnout)
	o.press(KEY_ENTER)
	_check(owner.cash == 5000 and owner.flags.get("outings", 0) == 1, "still free afterwards")

	# ---- the evening outing keeps working after a lunch
	_new(c, cards, world, "tech")
	c.day = 5
	world.clock = 16.2
	o.maybe_invite()
	_check(cards.is_open and cards.options.size() == 2, "the evening invitation is unchanged")
	cards.pick(1)
	_check(sla >= 0.0 and not o.lunch_on(), "and does not think it is a lunch")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
