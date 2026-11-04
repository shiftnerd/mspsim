extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# COOKOUT (roadmap R21 part b): the rules of the grill mini-game in the warehouse. A RefCounted with no autoload references so
# tests can run it headless (the Difficulty numbers come in as `params`, see Outings._grill_setup); the drawing is done by
# fx.gd (kind grill) in the room and the HUD by Outings.
# Four patties on the grate. Each has two sides with a cook value 0..1; only the side facing down cooks. A patty reads as
#   raw (a side under RAW), medium (the less cooked side from RAW to WELL), well (both sides from WELL up to BURN) and burnt
#   (a side over BURN). Flip it (E) while the down side is inside the flip window (WIN_LO to WIN_LO + WIN_W x window):
#   too early and it sticks and tears (that side loses half its cooking), too late and the side chars (a bit more).
#   Space pulls the selected patty onto a plate and serves the oldest ticket that still wants that doneness. Shift moves the
#   patty to the cool side (cooks at a quarter speed, a flare-up cannot reach it) and back.
# Tickets come from named coworkers at a steady pace, each wants one to three patties ("2 WELL, 1 MEDIUM") and waits `patience`
# seconds. A flare-up (seeded) makes one patty cook 2.4 times as fast for a few seconds until it is moved. Cozy Easy: no
# flare-ups, tickets never walk off, the round has twice the time, and a burnt patty is "crispy" (served as well done).
# Stars: 3 = all but one ticket served and nothing burnt, 2 = all but two, 1 = at least a third (2 or more).
# HOT DOGS (R29, `params.dogs` = the share of the items that are dogs, 0 = none as before): a slot is a burger or a dog. A dog
#   cooks 1.3x as fast, reads raw (a side under DOG_RAW), done (both sides from DOG_RAW) or burnt (a side over DOG_BURN), needs
#   one flip only (window DOG_WIN_LO to DOG_WIN_LO + DOG_WIN_W x window: early or late just spoils a side, it never tears) and
#   serves a "dog" line of a ticket ("1 DOG"). A fresh slot is a dog when the open orders want more dogs than the grate has.

const SLOTS := 4
const RAW := 0.35
const WELL := 0.55
const BURN := 0.9
const BASE_RATE := 0.05  # cook value per second per side at cook_rate 1
const WIN_LO := 0.35
const WIN_W := 0.35
const COOL_MUL := 0.25
const FLARE_MUL := 2.4
const FLARE_LEN := 4.0
const REFILL := 1.6
const LEAD := 1.0  # the first ticket
const SPREAD := 0.6  # the last ticket arrives at this share of the round
const PATIENCE := 40.0
const DOG_RAW := 0.3
const DOG_BURN := 0.85
const DOG_RATE := 1.3
const DOG_WIN_LO := 0.25
const DOG_WIN_W := 0.45
const NOTES := ["", "", "NO CHEESE", "SMOKY SAUCE", "EXTRA PICKLES", "NO ONIONS", "LOTS OF KETCHUP"]

var cook_rate := 1.0
var window := 1.0
var time := 75.0
var flare_scale := 1.0
var dog_share := 0.0
var cozy := false
var rng: RandomNumberGenerator
var names: Array = []

var slots: Array = []
var sel := 0
var clock := 0.0
var tickets: Array = []
var served := 0
var lost := 0
var burnt := 0
var dogs_plated := 0
var tossed := 0
var wasted := 0
var flips := 0
var good_flips := 0
var done := false
var done_t := 0.0
var msg := ""
var msg_t := 0.0
var events: Array = []  # {"e": "flip" | "sear" | "stick" | "char" | "bell" | "plate" | "toss" | "burnt" | "flare" | "cool" | "gone" | "new" | "end", ...}
var _next_flare := 0.0


func setup(params: Dictionary, who: Array, r: RandomNumberGenerator) -> void:
	cook_rate = float(params.get("cook_rate", 1.0))
	window = float(params.get("window", 1.0))
	time = float(params.get("time", 75.0))
	flare_scale = float(params.get("flare", 1.0))
	dog_share = clampf(float(params.get("dogs", 0.0)), 0.0, 0.9)
	cozy = bool(params.get("cozy", false))
	if cozy:
		flare_scale = 0.0
	rng = r
	names = who.duplicate() if not who.is_empty() else ["A COWORKER"]
	slots = []
	var n_dogs := roundi(float(SLOTS) * dog_share)
	for i in SLOTS:
		slots.append(_fresh("dog" if i >= SLOTS - n_dogs else "burger"))
	tickets = []
	var n := int(params.get("tickets", 6))
	var gap := (time * SPREAD - LEAD) / float(maxi(1, n - 1))
	for i in n:
		tickets.append(_ticket(i, LEAD + gap * float(i)))
	sel = 0
	clock = 0.0
	served = 0
	lost = 0
	burnt = 0
	dogs_plated = 0
	tossed = 0
	wasted = 0
	flips = 0
	good_flips = 0
	done = false
	done_t = 0.0
	_next_flare = rng.randf_range(8.0, 13.0) / maxf(flare_scale, 0.01)
	msg = "SIX HUNGRY COWORKERS. FIRE UP THE GRILL." if n == 6 else "HUNGRY COWORKERS. FIRE UP THE GRILL."


func _fresh(kind := "burger") -> Dictionary:
	return {"on": true, "kind": kind, "c": [0.0, 0.0], "down": 0, "cool": false, "flare": 0.0, "burnt": false, "refill": 0.0, "torn": false, "flipped": 0}


# what a new slot holds: a dog when the open orders want more dogs than the grate has (and nothing else is missing more)
func _next_kind() -> String:
	if dog_share <= 0.0:
		return "burger"
	var want_dog := 0
	var want_burger := 0
	for t in tickets:
		if t.state == "open":
			want_dog += int(t.need.get("dog", 0)) - int(t.have.get("dog", 0))
			want_burger += int(t.need.well) + int(t.need.medium) - int(t.have.well) - int(t.have.medium)
	var on_dog := 0
	var on_burger := 0
	for s in slots:
		if s.on:
			if s.kind == "dog":
				on_dog += 1
			else:
				on_burger += 1
	var d := want_dog - on_dog
	var b := want_burger - on_burger
	return "dog" if d > b or (d == b and on_dog == 0) else "burger"


func _ticket(i: int, at: float) -> Dictionary:
	var count := 1 + int(rng.randf() < 0.55) + int(i % 3 == 2 and rng.randf() < 0.3)
	var need := {"medium": 0, "well": 0, "dog": 0}
	for k in count:
		if dog_share > 0.0 and rng.randf() < dog_share:
			need["dog"] += 1
		else:
			need["well" if rng.randf() < 0.55 else "medium"] += 1
	return {
		"id": i,
		"who": str(names[i % names.size()]),
		"need": need,
		"have": {"medium": 0, "well": 0, "dog": 0},
		"at": at,
		"left": PATIENCE,
		"note": str(NOTES[rng.randi() % NOTES.size()]),
		"state": "later",  # later, open, served, gone
	}


func total() -> int:
	return tickets.size()


# the lines of a ticket for a bubble or the HUD: "2 WELL", "1 MEDIUM"
func lines(t: Dictionary) -> Array:
	var out := []
	if int(t.need.well) > 0:
		out.append("%d WELL" % int(t.need.well))
	if int(t.need.medium) > 0:
		out.append("%d MEDIUM" % int(t.need.medium))
	var dogs := int(t.need.get("dog", 0))
	if dogs > 0:
		out.append("%d DOG%s" % [dogs, "S" if dogs > 1 else ""])
	return out


func open_tickets() -> Array:
	return tickets.filter(func(t: Dictionary) -> bool: return t.state == "open")


# ---- doneness -------------------------------------------------------------------------------------------------
static func band(c0: float, c1: float) -> String:
	if maxf(c0, c1) > BURN:
		return "burnt"
	var lo := minf(c0, c1)
	if lo < RAW:
		return "raw"
	return "medium" if lo < WELL else "well"


# a dog is raw, "dog" (done) or burnt
static func dog_band(c0: float, c1: float) -> String:
	if maxf(c0, c1) > DOG_BURN:
		return "burnt"
	return "raw" if minf(c0, c1) < DOG_RAW else "dog"


func doneness(i: int) -> String:
	var s: Dictionary = slots[i]
	if not s.on:
		return "empty"
	if s.kind == "dog":
		var d := dog_band(float(s.c[0]), float(s.c[1]))
		return "dog" if d == "burnt" and cozy else d
	var b := band(float(s.c[0]), float(s.c[1]))
	return "well" if b == "burnt" and cozy else b


func flip_range(kind := "burger") -> Vector2:
	if kind == "dog":
		return Vector2(DOG_WIN_LO, DOG_WIN_LO + DOG_WIN_W * window)
	return Vector2(WIN_LO, WIN_LO + WIN_W * window)


# ---- the player's keys ------------------------------------------------------------------------------------------
func select(i: int) -> void:
	sel = posmod(i, SLOTS)


func move_sel(step: int) -> void:
	select(sel + step)


func flip(i: int = -1) -> String:
	var at := sel if i < 0 else i
	var s: Dictionary = slots[at]
	if done or not s.on:
		return ""
	var down: int = s.down
	var v := float(s.c[down])
	var is_dog: bool = s.kind == "dog"
	var r := flip_range(str(s.kind))
	var res := "sear"
	if v < r.x:
		s.c[down] = v * (0.7 if is_dog else 0.5)
		s.torn = true
		res = "stick"
		msg = "ROLLED TOO SOON. THAT SIDE IS PALE." if is_dog else "STUCK TO THE GRATE. IT TORE."
	elif v > r.y:
		s.c[down] = v + 0.06
		res = "char"
		msg = "FLIPPED LATE. THAT SIDE IS CHARRED."
	else:
		good_flips += 1
		msg = "NICE GRILL MARKS." if is_dog else "NICE SEAR."
	s.down = 1 - down
	s.flipped = int(s.flipped) + 1
	flips += 1
	msg_t = 2.0
	events.append({"e": "flip", "slot": at, "res": res})
	return res


func cool(i: int = -1) -> void:
	var at := sel if i < 0 else i
	var s: Dictionary = slots[at]
	if done or not s.on:
		return
	s.cool = not s.cool
	s.flare = 0.0
	msg = "MOVED TO THE COOL SIDE." if s.cool else "BACK OVER THE FLAMES."
	msg_t = 1.5
	events.append({"e": "cool", "slot": at})


# Space: the patty goes on a plate and feeds the oldest ticket that wants it. Returns served, plated, tossed or wasted
func pull(i: int = -1) -> String:
	var at := sel if i < 0 else i
	var s: Dictionary = slots[at]
	if done or not s.on:
		return ""
	var d := doneness(at)
	var out := "wasted"
	var is_dog: bool = s.kind == "dog"
	if d == "raw" or d == "burnt":
		tossed += 1
		out = "tossed"
		msg = "TOSSED: %s." % ("STILL RAW" if d == "raw" else "BURNT")
		events.append({"e": "toss", "slot": at})
	else:
		var hit := {}
		for t in tickets:
			if t.state == "open" and int(t.have.get(d, 0)) < int(t.need.get(d, 0)):
				hit = t
				break
		if hit.is_empty():
			wasted += 1
			msg = "NOBODY ORDERED THAT ONE."
			events.append({"e": "toss", "slot": at})
		else:
			hit.have[d] = int(hit.have.get(d, 0)) + 1
			out = "plated"
			if is_dog:
				dogs_plated += 1
			msg = "%s GETS A %s." % [str(hit.who).to_upper(), "HOT DOG" if is_dog else d.to_upper() + " BURGER"]
			events.append({"e": "plate", "slot": at, "who": hit.who})
			if int(hit.have.well) >= int(hit.need.well) and int(hit.have.medium) >= int(hit.need.medium) and int(hit.have.get("dog", 0)) >= int(hit.need.get("dog", 0)):
				hit.state = "served"
				served += 1
				out = "served"
				msg = "%s: ORDER UP! THANKS." % str(hit.who).to_upper()
				events.append({"e": "bell", "who": hit.who, "id": hit.id})
	msg_t = 2.0
	s.on = false
	s.refill = REFILL
	s.cool = false
	s.flare = 0.0
	return out


# ---- time ---------------------------------------------------------------------------------------------------------
func step(dt: float) -> void:
	if done:
		done_t += dt
		return
	clock += dt
	msg_t = maxf(0.0, msg_t - dt)
	for i in SLOTS:
		_cook(i, dt)
	_flares()
	for t in tickets:
		if t.state == "later" and clock >= float(t.at):
			t.state = "open"
			events.append({"e": "new", "who": t.who, "id": t.id})
		elif t.state == "open" and not cozy:
			t.left = float(t.left) - dt
			if float(t.left) <= 0.0:
				t.state = "gone"
				lost += 1
				msg = "%s GAVE UP AND WALKED OFF." % str(t.who).to_upper()
				msg_t = 2.5
				events.append({"e": "gone", "who": t.who, "id": t.id})
	var limit := time * (2.0 if cozy else 1.0)
	var pending := tickets.filter(func(t: Dictionary) -> bool: return t.state == "later" or t.state == "open")
	if pending.is_empty() or clock >= limit:
		for t in pending:
			t.state = "gone"
			lost += 1
		done = true
		events.append({"e": "end"})


func _cook(i: int, dt: float) -> void:
	var s: Dictionary = slots[i]
	if not s.on:
		s.refill = float(s.refill) - dt
		if float(s.refill) <= 0.0:
			slots[i] = _fresh(_next_kind())
		return
	var is_dog: bool = s.kind == "dog"
	var mul := COOL_MUL if s.cool else 1.0
	if float(s.flare) > 0.0:
		s.flare = float(s.flare) - dt
		if not s.cool:
			mul *= FLARE_MUL
	var down: int = s.down
	s.c[down] = minf(1.3, float(s.c[down]) + BASE_RATE * cook_rate * mul * (DOG_RATE if is_dog else 1.0) * dt)
	if not s.burnt and maxf(float(s.c[0]), float(s.c[1])) > (DOG_BURN if is_dog else BURN):
		s.burnt = true
		burnt += 1
		events.append({"e": "burnt", "slot": i})
		if cozy:
			msg = "CRISPY. THE CREW EATS THEM ANYWAY."
			msg_t = 2.0


func _flares() -> void:
	if flare_scale <= 0.0 or clock < _next_flare:
		return
	_next_flare = clock + rng.randf_range(10.0, 16.0) / flare_scale
	var cands := []
	for i in SLOTS:
		if slots[i].on and not slots[i].cool:
			cands.append(i)
	if cands.is_empty():
		return
	var at: int = cands[rng.randi() % cands.size()]
	slots[at].flare = FLARE_LEN
	msg = "FLARE-UP ON %d! SHIFT MOVES IT." % (at + 1)
	msg_t = 2.0
	events.append({"e": "flare", "slot": at})


# ---- the result -----------------------------------------------------------------------------------------------------
func cooking() -> bool:
	return slots.any(func(s: Dictionary) -> bool: return s.on and not s.cool)


func flare_slots() -> Array:
	var out := []
	for i in SLOTS:
		if float(slots[i].flare) > 0.0:
			out.append(i)
	return out


func time_left() -> float:
	return maxf(0.0, (time * (2.0 if cozy else 1.0)) - clock)


func stars_for(n_served: int, n_burnt: int, n_total: int, is_cozy: bool) -> int:
	var out := 0
	if n_served >= n_total - 1 and (n_burnt == 0 or is_cozy):
		out = 3
	elif n_served >= n_total - 2:
		out = 2
	elif n_served >= maxi(2, ceili(float(n_total) / 3.0)):
		out = 1
	if is_cozy:
		out = maxi(out, 1)
	return out


func stars() -> int:
	return stars_for(served, burnt, tickets.size(), cozy) if done else 0
