extends SceneTree
# gdlint:disable=max-line-length
# THE COOKOUT (R21 b): the cook bands and the flip window, flipping, the cool side and flare-ups, serving the oldest matching ticket,
# the tickets (names, pace, patience), the tiers (a bot plays a clean run on every tier, hard included), the stars, Cozy Easy
# (no flare-ups, nobody walks off, burnt = crispy, a floor of one star), determinism from the seed, and the outing around it (the
# card, the overlay game, the keys, the hint, the counters, the GRILL SERGEANT medal, and no brand names in the text).
# Headless: the rules run through GrillGame.step / flip / pull / cool, the outing through Outings.press / tick.

const Grill := preload("res://scripts/grill_game.gd")
const NAMES := ["Alan", "Garrison", "Dan", "Vic", "Maya"]
const TIERS := {
	"easy": {"cook_rate": 0.85, "window": 1.3, "tickets": 5, "time": 85.0, "flare": 0.5},
	"normal": {"cook_rate": 1.0, "window": 1.0, "tickets": 6, "time": 75.0, "flare": 1.0},
	"hard": {"cook_rate": 1.25, "window": 0.8, "tickets": 6, "time": 68.0, "flare": 1.5},
}
const BRANDS := ["WEBER", "TRAEGER", "COLEMAN", "KINGSFORD", "HEINZ", "KRAFT", "MCDONALD", "WENDY", "BURGER KING", "OSCAR MAYER", "HEBREW", "HORMEL", "SPAM", "PEPSI", "COCA"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r


func _game(tier: String, seed_n: int, extra := {}, who := NAMES) -> RefCounted:
	var p: Dictionary = TIERS[tier].duplicate()
	p.merge(extra, true)
	var g := Grill.new()
	g.setup(p, who, _rng(seed_n))
	return g


# a competent cook: flips at the right time for what the open orders want, serves what fits, parks a flaring patty, tosses nothing
# (the bot reacts to a flare-up after `react` seconds)
func _bot(g: RefCounted, react: float, dt := 0.1) -> void:
	var cool_until := {}
	var seen := {}
	var guard := 0
	while not g.done and guard < 6000:
		guard += 1
		_bot_step(g, react, cool_until, seen)
		g.step(dt)


func _bot_step(g: RefCounted, react: float, cool_until: Dictionary, seen: Dictionary) -> void:
	for i in 4:
		var nw := 0
		var nm := 0
		for t in g.open_tickets():
			nw += int(t.need.well) - int(t.have.well)
			nm += int(t.need.medium) - int(t.have.medium)
		var s: Dictionary = g.slots[i]
		if not s.on:
			continue
		if float(s.flare) > 0.0 and not s.cool:
			if not seen.has(i):
				seen[i] = g.clock
			if g.clock - float(seen[i]) >= react:
				g.cool(i)
				cool_until[i] = g.clock + 5.0
				seen.erase(i)
		elif s.cool and g.clock >= float(cool_until.get(i, 0.0)):
			g.cool(i)
		if s.cool:
			continue
		var c: Array = s.c
		if int(s.flipped) == 0 and float(c[s.down]) >= (0.58 if nw > nm else 0.4):
			g.flip(i)
			continue
		var d: String = g.doneness(i)
		var lo := minf(float(c[0]), float(c[1]))
		var hi := maxf(float(c[0]), float(c[1]))
		if int(s.flipped) >= 1 and ((d == "medium" and nm > 0 and lo >= 0.37) or (d == "well" and nw > 0 and lo >= 0.58) or hi > 0.84):
			g.pull(i)


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	var o := root.get_node("Outings")
	var career := root.get_node("Career")
	var sfx := root.get_node("Sfx")
	var campaign := root.get_node("Campaign")
	var game := root.get_node("Game")
	var world := root.get_node("World")
	game.title_mode = false
	campaign.save_prefix = "user://test_grill_%d_" % OS.get_process_id()  # the career file of this test, not the real one
	career.reset_all()

	# ---- the tiers are in the table
	for key in ["grill.cook_rate", "grill.window", "grill.tickets", "grill.time", "grill.flare"]:
		_check(d.TABLE.has(key) and d.TABLE[key].size() == 3, "%s has three tiers" % key)
	_check(d.TABLE["grill.cook_rate"][0] < d.TABLE["grill.cook_rate"][2] and d.TABLE["grill.window"][0] > d.TABLE["grill.window"][2], "hard cooks faster and the flip window is narrower")
	_check(d.TABLE["grill.time"][0] > d.TABLE["grill.time"][2] and d.TABLE["grill.flare"][0] < d.TABLE["grill.flare"][2], "hard has less time and more flare-ups")
	for tier in TIERS:
		d.set_tier(tier)
		_check(is_equal_approx(d.f("grill.cook_rate"), TIERS[tier].cook_rate) and d.i("grill.tickets") == TIERS[tier].tickets and is_equal_approx(d.f("grill.time"), TIERS[tier].time), "%s: Difficulty matches the table the test uses" % tier)
	d.set_tier("normal")

	# ---- the cook bands
	_check(Grill.band(0.0, 0.0) == "raw" and Grill.band(0.34, 0.9) == "raw", "a side under 0.35 is raw")
	_check(Grill.band(0.35, 0.35) == "medium" and Grill.band(0.54, 0.8) == "medium", "0.35 to 0.55 is medium (the less cooked side counts)")
	_check(Grill.band(0.55, 0.55) == "well" and Grill.band(0.6, 0.9) == "well", "both sides from 0.55 is well done")
	_check(Grill.band(0.8, 0.91) == "burnt" and Grill.band(0.95, 0.2) == "burnt", "over 0.9 is burnt, even on one side")
	var g := _game("normal", 1)
	_check(g.flip_range().is_equal_approx(Vector2(0.35, 0.7)), "the flip window is 0.35 to 0.7")
	_check(_game("hard", 1).flip_range().y < _game("easy", 1).flip_range().y, "the window is narrower on hard")

	# ---- the grate: four patties, only the down side cooks
	_check(g.slots.size() == 4 and g.slots.all(func(s: Dictionary) -> bool: return s.on and s.c == [0.0, 0.0] and s.down == 0), "four raw patties on the grate")
	g.step(10.0)
	_check(is_equal_approx(float(g.slots[0].c[0]), 10.0 * Grill.BASE_RATE) and float(g.slots[0].c[1]) == 0.0, "10 seconds cooks the down side by 0.5 and the other not at all")
	var fast := _game("hard", 1)
	fast.step(10.0)
	_check(float(fast.slots[0].c[0]) > float(g.slots[0].c[0]) * 1.2, "hard cooks faster")
	# ---- flipping
	g = _game("normal", 2)
	g.slots[0].c[0] = 0.2
	_check(g.flip(0) == "stick" and is_equal_approx(float(g.slots[0].c[0]), 0.1) and g.slots[0].down == 1 and g.slots[0].torn, "too early: it sticks, loses half and the patty turns over")
	g.slots[1].c[0] = 0.5
	_check(g.flip(1) == "sear" and is_equal_approx(float(g.slots[1].c[0]), 0.5) and g.good_flips == 1, "in the window: a clean sear")
	g.slots[2].c[0] = 0.8
	_check(g.flip(2) == "char" and float(g.slots[2].c[0]) > 0.8, "too late: that side chars")
	g.select(3)
	_check(g.flip() == "sear" or g.flip() == "stick", "E flips the selected slot")
	g.slots[1].c[1] = 0.3
	g.step(10.0)
	_check(float(g.slots[1].c[1]) > 0.7 and is_equal_approx(float(g.slots[1].c[0]), 0.5), "after the flip the other side cooks")
	_check(_game("easy", 3).flip_range().y > 0.8 * 0 + 0.7, "easy: a wide window")
	# selection wraps
	g.select(0)
	g.move_sel(-1)
	_check(g.sel == 3, "the arrows wrap around the grate")
	g.move_sel(1)
	_check(g.sel == 0, "and back")

	# ---- the cool side and flare-ups
	g = _game("normal", 4)
	g.cool(0)
	g.step(10.0)
	_check(g.slots[0].cool and is_equal_approx(float(g.slots[0].c[0]), 10.0 * Grill.BASE_RATE * Grill.COOL_MUL), "the cool side cooks at a quarter speed")
	g.cool(0)
	_check(not g.slots[0].cool, "Shift again puts it back over the flames")
	g = _game("normal", 4)
	g.slots[1].flare = Grill.FLARE_LEN
	g.step(1.0)
	_check(is_equal_approx(float(g.slots[1].c[0]), Grill.BASE_RATE * Grill.FLARE_MUL), "a flare-up cooks 2.4 times as fast")
	g.cool(1)
	_check(float(g.slots[1].flare) == 0.0 and g.events.any(func(e: Dictionary) -> bool: return e.e == "cool"), "moving it ends the flare for that patty")
	g = _game("normal", 5)
	var flares := 0
	for k in 700:
		g.step(0.1)
		for e in g.events:
			flares += 1 if e.e == "flare" else 0
		g.events.clear()
		if g.done:
			break
	_check(flares >= 2 and flares <= 8, "flare-ups come now and then (%d in a round)" % flares)
	var f_easy := _game("easy", 5)
	var f_hard := _game("hard", 5)
	_check(f_easy._next_flare > f_hard._next_flare, "the first flare-up comes later on easy")
	# an ignored flare-up burns a patty that was fine
	g = _game("normal", 6)
	g.slots[2].c[0] = 0.6
	g.slots[2].flare = Grill.FLARE_LEN
	g.step(Grill.FLARE_LEN)
	_check(g.burnt == 1 and g.slots[2].burnt, "a flare-up left alone burns it (%.2f)" % float(g.slots[2].c[0]))

	# ---- tickets
	g = _game("normal", 7)
	_check(g.tickets.size() == 6 and g.total() == 6, "six tickets on normal")
	_check(_game("easy", 7).total() == 5 and _game("hard", 7).total() == 6, "five on easy, six on hard")
	_check(g.tickets.map(func(t: Dictionary) -> String: return str(t.who)).slice(0, 5) == NAMES, "from named coworkers, in cast order")
	var arrivals: Array = g.tickets.map(func(t: Dictionary) -> float: return float(t.at))
	var sorted := arrivals.duplicate()
	sorted.sort()
	_check(arrivals == sorted and arrivals[0] <= 1.5 and arrivals[5] <= 75.0 * 0.62, "they arrive in turn over the first 60%% of the round (%s)" % str(arrivals))
	var sizes: Array = g.tickets.map(func(t: Dictionary) -> int: return int(t.need.well) + int(t.need.medium))
	_check(sizes.all(func(n: int) -> bool: return n >= 1 and n <= 3), "an order is one to three burgers (%s)" % str(sizes))
	_check(g.lines(g.tickets[0]).size() >= 1 and str(g.lines(g.tickets[0])[0]).contains("WELL") or str(g.lines(g.tickets[0])[0]).contains("MEDIUM"), "an order reads like '2 WELL' / '1 MEDIUM'")
	_check(_game("normal", 7, {}, ["Alan"]).tickets.all(func(t: Dictionary) -> bool: return t.who == "Alan"), "a party of one: all the orders are theirs")
	_check(_game("normal", 7, {}, []).tickets[0].who == "A COWORKER", "nobody there: a coworker")
	g.step(1.2)
	_check(g.open_tickets().size() == 1 and g.events.any(func(e: Dictionary) -> bool: return e.e == "new"), "the first order comes in at once")
	# a ticket gives up
	g = _game("normal", 8)
	g.step(1.2)
	var first: Dictionary = g.tickets[0]
	for k in 420:
		g.step(0.1)
		g.slots.map(func(s: Dictionary) -> void: s.c = [0.0, 0.0])
	_check(first.state == "gone" and g.lost >= 1 and g.events.any(func(e: Dictionary) -> bool: return e.e == "gone"), "an order that waits too long walks off")

	# ---- serving
	g = _game("normal", 9)
	g.step(1.2)
	g.tickets[0].need = {"medium": 1, "well": 1}
	g.tickets[0].have = {"medium": 0, "well": 0}
	g.step(0.1)
	g.slots[0].c = [0.5, 0.45]
	_check(g.doneness(0) == "medium", "0.5 / 0.45 reads medium")
	_check(g.pull(0) == "plated" and g.tickets[0].have.medium == 1 and not g.slots[0].on, "pulling it serves the order's medium (the order is not complete yet)")
	g.slots[1].c = [0.7, 0.6]
	_check(g.pull(1) == "served" and g.tickets[0].state == "served" and g.served == 1, "the well done one completes it: served")
	_check(g.events.any(func(e: Dictionary) -> bool: return e.e == "bell"), "the serve bell")
	g.slots[2].c = [0.1, 0.0]
	_check(g.pull(2) == "tossed" and g.tossed == 1, "a raw patty is tossed")
	g.slots[3].c = [0.7, 0.7]
	_check(g.pull(3) == "wasted" and g.wasted == 1, "a good patty nobody ordered is wasted")
	_check(g.pull(3) == "", "an empty slot does nothing")
	g.step(Grill.REFILL + 0.1)
	_check(g.slots[0].on and g.slots[0].c == [0.0, 0.0] and g.slots[3].on, "a fresh patty goes on the grate after a moment")
	# the oldest matching order gets it
	g = _game("normal", 9)
	g.step(20.0)
	var n_open: int = g.open_tickets().size()
	g.tickets[0].need = {"medium": 0, "well": 1}
	g.tickets[0].have = {"medium": 0, "well": 0}
	g.tickets[1].need = {"medium": 0, "well": 1}
	g.tickets[1].have = {"medium": 0, "well": 0}
	g.tickets[0].state = "open"
	g.tickets[1].state = "open"
	g.slots[0].c = [0.7, 0.7]
	g.pull(0)
	_check(n_open >= 2 and g.tickets[0].state == "served" and g.tickets[1].state == "open", "the oldest matching order is served first")
	# burnt
	g = _game("normal", 10)
	g.slots[0].c = [0.95, 0.4]
	_check(g.doneness(0) == "burnt" and g.pull(0) == "tossed", "a burnt patty is tossed")

	# ---- stars
	_check(g.stars_for(6, 0, 6, false) == 3 and g.stars_for(5, 0, 6, false) == 3, "5 of 6 with nothing burnt: 3 stars")
	_check(g.stars_for(5, 1, 6, false) == 2 and g.stars_for(4, 0, 6, false) == 2, "5 of 6 but one burnt, or 4 of 6: 2 stars")
	_check(g.stars_for(3, 0, 6, false) == 1 and g.stars_for(2, 0, 6, false) == 1, "3 or 2 of 6: 1 star")
	_check(g.stars_for(1, 0, 6, false) == 0 and g.stars_for(0, 0, 6, false) == 0, "fewer than 2: no stars")
	_check(g.stars_for(4, 0, 5, false) == 3 and g.stars_for(3, 0, 5, false) == 2 and g.stars_for(2, 0, 5, false) == 1, "easy has five orders: 4 / 3 / 2 are the cuts")
	_check(g.stars_for(0, 0, 6, true) == 1 and g.stars_for(6, 3, 6, true) == 3, "Cozy Easy: a floor of one star, burnt does not cost the third")
	g = _game("normal", 11)
	_check(g.stars() == 0, "no stars before the end")

	# ---- the round ends
	g = _game("normal", 12)
	g.step(75.0)
	_check(g.done and g.lost == 6 and g.stars() == 0, "the time runs out: the open orders are lost (%d)" % g.lost)
	_check(g.events.any(func(e: Dictionary) -> bool: return e.e == "end"), "and says so")
	var gone := _game("normal", 12)
	gone.step(75.0)
	_check(gone.pull(0) == "" and gone.flip(0) == "", "nothing happens after the end")

	# ---- the bot: a clean run on every tier, many seeds (perfect play is possible on hard)
	for tier in TIERS:
		var best := 0
		var three := 0
		for k in 20:
			var bg := _game(tier, 100 + k)
			_bot(bg, 0.6)
			best = maxi(best, bg.stars())
			three += 1 if bg.stars() == 3 else 0
		_check(best == 3 and three >= 12, "%s: a competent cook gets 3 stars in %d of 20 games" % [tier, three])
	var lazy := _game("normal", 101)
	lazy.step(75.0)
	_check(lazy.stars() == 0, "doing nothing is no stars")
	var sloppy := _game("normal", 101)
	for k in 750:
		for i in 4:
			if sloppy.slots[i].on and float(sloppy.slots[i].c[0]) > 0.2:
				sloppy.pull(i)  # pulls everything at once, whatever it is
		sloppy.step(0.1)
	_check(sloppy.stars() <= 1 and sloppy.tossed + sloppy.wasted >= 5, "pulling everything at once wastes patties and fails (%d stars)" % sloppy.stars())

	# ---- determinism
	var a := _game("normal", 55)
	var b := _game("normal", 55)
	var c := _game("normal", 56)
	_bot(a, 0.6)
	_bot(b, 0.6)
	_bot(c, 0.6)
	_check(a.served == b.served and a.burnt == b.burnt and is_equal_approx(a.clock, b.clock) and a.tickets.map(func(t: Dictionary) -> int: return int(t.need.well)) == b.tickets.map(func(t: Dictionary) -> int: return int(t.need.well)), "the same seed gives the same round")
	_check(a.tickets.map(func(t: Dictionary) -> String: return str(t.need)) != c.tickets.map(func(t: Dictionary) -> String: return str(t.need)), "another seed gives other orders")

	# ---- Cozy Easy
	var cozy := _game("easy", 13, {"cozy": true})
	_check(cozy.flare_scale == 0.0, "cozy: no flare-ups")
	var seen_flare := false
	for k in 2000:
		cozy.step(0.1)
		for e in cozy.events:
			seen_flare = seen_flare or e.e == "flare"
		cozy.events.clear()
		if cozy.done:
			break
	_check(not seen_flare and cozy.done and cozy.clock >= 85.0 * 2.0, "cozy: no flare-ups, and the round runs twice as long (%.0f s)" % cozy.clock)
	_check(cozy.lost == 5 and cozy.stars() == 1, "cozy: doing nothing is not a failure but still 1 star (%d lost)" % cozy.lost)
	cozy = _game("easy", 13, {"cozy": true})
	cozy.step(1.2)
	cozy.step(120.0 * 0.0 + 80.0)
	_check(cozy.tickets[0].state == "open" or cozy.tickets[0].state == "later" or cozy.tickets[0].state == "served", "cozy: nobody walks off in the first minute")
	cozy = _game("easy", 14, {"cozy": true})
	cozy.step(1.2)
	cozy.tickets[0].need = {"medium": 0, "well": 1}
	cozy.tickets[0].have = {"medium": 0, "well": 0}
	cozy.slots[0].c = [0.97, 0.95]
	_check(cozy.doneness(0) == "well", "cozy: a burnt patty is crispy, it counts as well done")
	cozy.step(0.1)
	_check(cozy.msg.contains("CRISPY") or cozy.burnt == 0, "cozy: the crew eats them: %s" % cozy.msg)
	_check(cozy.pull(0) == "served" and cozy.served == 1, "cozy: and it is served")

	# ---- the outing: card, overlay game, keys, hint, counters, medal, texts
	_check(o.GAMES.has("grill") and o.GAMES.grill.label == "COOKOUT" and o.GAMES.grill.cost == 150, "the outing list has the cookout at $150")
	_check(o.ROOMS.grill == "warehouse" and o.SPOTS.grill.size() == 6, "it is played in the warehouse with a spot for each cast member")
	var texts: Array = [str(o.GAMES.grill.blurb), str(o.ROOM_INTRO.grill), str(o.GAMES.grill.keys), str(Grill.NOTES), str(o.GAMES.grill.label)]
	for who in ["Alan", "Garrison", "Dan", "Vic", "Maya", "Morgan"]:
		for kind in ["cook", "wait"]:
			var lines: Array = o.CREW_LINES[who].get(kind, [])
			_check(lines.size() >= 2, "%s: two %s lines" % [who, kind])
			for line in lines:
				texts.append(str(line))
				_check(str(line).length() <= 40, "%s %s: '%s' fits a caption" % [who, kind, line])
	for m in career.MEDALS:
		if m.id in ["grill_sergeant", "bag_man"]:
			texts.append(str(m.title) + " " + str(m.desc))
			_check(str(m.desc).length() <= 31, "the %s medal text fits a line" % m.id)
	var brand := ""
	for text in texts:
		for name in BRANDS:
			if str(text).to_upper().contains(name):
				brand = "%s in '%s'" % [name, text]
	_check(brand == "", "no brand names in the cookout text (%s)" % brand)
	campaign.new_game(campaign.FREE)
	world.time_scale = 1.0
	o.enabled = true
	o.use_rooms = false
	d.seed_run(777)  # the outing draws from the run's streams: a seeded run plays the same every time
	o.start("grill", false, {"party": ["Alan", "Garrison", "Dan"]})
	_check(o.is_open and o.game == "grill" and o.phase == "intro", "the overlay game opens on its intro page")
	_check(o.grill_crew() == ["Alan", "Garrison", "Dan"], "the customers are the party")
	o.press(KEY_ENTER)
	_check(o.phase == "play" and o.g.has("game") and o.g.game.names == ["Alan", "Garrison", "Dan"], "ENTER starts the game")
	_check(o.hint() == o.GAMES.grill.keys and not o.blocks_interact(), "without a room the hint is the key line")
	var gg: RefCounted = o.g.game
	o.press(KEY_RIGHT)
	_check(gg.sel == 1, "RIGHT picks the next patty")
	o.press(KEY_LEFT)
	o.press(KEY_LEFT)
	_check(gg.sel == 3, "LEFT picks the one before (wrapping)")
	o.tick(1.5)
	gg.slots[3].c = [0.5, 0.0]
	o.press(KEY_E)
	_check(gg.slots[3].down == 1 and sfx.played.has("grill_sizzle"), "E flips the selected patty (and it sizzles)")
	o.press(KEY_SHIFT)
	_check(gg.slots[3].cool, "Shift moves it to the cool side")
	o.press(KEY_SHIFT)
	gg.slots[3].c = [0.7, 0.7]
	gg.tickets[0].need = {"medium": 0, "well": 1}
	gg.tickets[0].have = {"medium": 0, "well": 0}
	o.press(KEY_SPACE)
	o.tick(0.1)
	_check(gg.served == 1 and sfx.played.has("serve_bell"), "Space pulls it and serves the oldest matching order (and the bell rings)")
	var o_stars := 0
	var guard := 0
	while o.phase == "play" and guard < 2000:
		guard += 1
		_bot_step(gg, 0.6, {}, {})
		o.tick(0.1)
	o_stars = o.stars
	_check(o.phase == "result" and o_stars >= 2, "a clean round reaches the result page (%d stars)" % o_stars)
	_check(career.value("burgers_served") == gg.served and gg.served >= 4, "served burgers are counted (%d, career %d)" % [gg.served, career.value("burgers_served")])
	_check(career.value("stars.grill") == o_stars, "the best stars are noted for the career screen")
	_check(career.has_medal("grill_sergeant") == (gg.burnt == 0), "GRILL SERGEANT is earned by a run with nothing burnt (%d burnt)" % gg.burnt)
	_check(o.lines.any(func(l: String) -> bool: return l.contains("SERVED")), "the result page says how many: %s" % str(o.lines))
	o.press(KEY_ENTER)
	_check(not o.is_open, "ENTER closes the result")
	# leaving early
	o.start("grill", false, {"party": ["Alan"]})
	o.press(KEY_ENTER)
	o.press(KEY_ESCAPE)
	_check(o.phase == "result" and o.stars == -1, "Esc leaves early")
	o.press(KEY_ENTER)
	# Cozy Easy in a campaign
	d.set_tier("easy")
	campaign.new_game("tech")
	o.start("grill", false, {"party": ["Alan", "Garrison"]})
	o.press(KEY_ENTER)
	var cz: RefCounted = o.g.game
	_check(cz.cozy and cz.flare_scale == 0.0 and cz.stars() == 0, "cozy comes from the Difficulty (no flare-ups)")
	for k in 3000:
		if o.phase != "play":
			break
		o.tick(0.1)
	_check(o.phase == "result" and o.stars == 1, "Cozy Easy: serving nobody is still 1 star (%d)" % o.stars)
	o.press(KEY_ENTER)
	d.set_tier("normal")
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
