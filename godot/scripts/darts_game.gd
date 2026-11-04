extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# DARTS (warehouse, the board at set x 1047): the rules of a casual pub round. A RefCounted with no autoload references so tests
# can run it headless (the Difficulty numbers come in as `params`, see Outings._darts_params); the live darts in the board are
# drawn by fx.gd (kind dart_board), the zoomed board and the strip by Outings.
# Everybody throws three darts a turn, three rounds, highest total wins. You stand at the throw line; an AIM RETICLE drifts over
# the board (a slow Lissajous loop) and E throws at wherever it is. The wobble settles for about a second and then your arm tires
# (it is smallest at STEADY_T), and every dart gets a new sweet spot: the centre of the drift moves (ZONE_C mm), the speed and the
# phase change (a seeded stream, Difficulty.zone). The dart lands at the reticle plus a little scatter (`noise`, mm).
# The board is the real one in millimetres (radius 170): the bull is 50, the outer bull 25, the treble ring x3, the double ring x2,
# anything else on the board is the number of its wedge (20 at the top, clockwise 20 1 18 4 13 6 10 15 2 17 3 19 7 16 8 11 14 9 12 5).
# The crew throw at a target (the treble 20 for the good ones, the bull for the rest) with an error that falls with their skill.
# Stars: win by BIG_WIN or more = 3, win = 2, a tie or a loss by less than CLOSE = 1, else 0 (1 at least on cozy Easy, `floor`).

const ORDER := ["Alan", "Garrison", "Dan", "Maya", "Vic"]
const ROUNDS := 3
const DARTS := 3
const BOARD_R := 170.0
const BULL_R := 6.35
const OUTER_BULL_R := 15.9
const TREBLE_IN := 99.0
const TREBLE_OUT := 107.0
const DOUBLE_IN := 162.0
const SEGMENTS := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const ZONE_C := 22.0  # the drift centre of a dart is drawn within +-this (mm) of the bull
const STEADY_T := 1.3  # seconds into the aim when the wobble is smallest
const STEADY_MIN := 0.45  # the share of the drift left at that moment
const READY := 1.0
const WINDUP := 0.6
const FLIGHT := 0.35
const SETTLE := 0.5
const PULL := 1.9
const BIG_WIN := 40
const CLOSE := 25
# the crew: a base skill 0..1 (the error of a dart is lerp(40, 12, skill) mm), and a temper
#   streak: hot after a big dart, cold after a miss. wild: now and then a dart nobody planned.
#   show: better with an audience (two opponents or you just threw well) but now and then a trick throw.
const TEMPERS := {
	"Alan": {"skill": 0.6, "streak": 0.0, "wild": 0.0, "show": 0.0},
	"Garrison": {"skill": 0.5, "streak": 0.12, "wild": 0.0, "show": 0.0},
	"Dan": {"skill": 0.44, "streak": 0.0, "wild": 0.14, "show": 0.0},
	"Maya": {"skill": 0.56, "streak": 0.0, "wild": 0.0, "show": 0.0},
	"Vic": {"skill": 0.48, "streak": 0.0, "wild": 0.0, "show": 0.12},
}
const HOUSE := {"skill": 0.5, "streak": 0.0, "wild": 0.0, "show": 0.0}

var rounds := ROUNDS
var drift := 58.0  # mm, the size of the reticle's loop
var speed := 1.9  # radians a second
var noise := 7.0  # mm of scatter on your own dart
var opp_skill := 0.0
var floor_stars := 0  # 1 on cozy Easy
var rng: RandomNumberGenerator
var zone_rng: RandomNumberGenerator = null
var crew: Array = []  # the opponents, in order
var players: Array = []  # "You" then the crew (or THE HOUSE)

var phase := "ready"  # ready, aim, opp, flight, settle, pull, done
var turn_i := 0
var dart_i := 0
var t := 0.0
var aim_t := 0.0
var zc := Vector2.ZERO  # this dart's drift centre
var zs := 1.0  # its speed factor
var zp := 0.0  # its phase
var totals := {}
var turn_pts := 0
var darts_now: Array = []  # the darts in the board this turn: {who, px, py, ring, num, pts}
var flying := {}  # the dart in the air: who, px, py, t
var events: Array = []  # what just happened: {"e": "dart" | "bull" | "turn" | "pull" | "end", "who": ..., ...}
var msg := ""
var won := false
var bulls := 0  # your inner bulls
var outers := 0
var trebles := 0
var doubles := 0
var best_dart := 0  # your highest dart
var thrown := 0  # your darts
var _hot := 0.0
var _you_big := false
var _turn_best := 0


func setup(params: Dictionary, crew_names: Array, r: RandomNumberGenerator) -> void:
	rounds = int(params.get("rounds", ROUNDS))
	drift = float(params.get("drift", 58.0))
	speed = float(params.get("speed", 1.9))
	noise = float(params.get("noise", 7.0))
	opp_skill = float(params.get("opp_skill", 0.0))
	floor_stars = int(params.get("floor", 0))
	rng = r
	zone_rng = params.get("zone_rng", null)
	crew = ORDER.filter(func(n: String) -> bool: return crew_names.has(n))
	players = ["You"]
	players.append_array(crew if not crew.is_empty() else ["THE HOUSE"])
	totals = {}
	for p in players:
		totals[p] = 0
	turn_i = -1
	won = false
	_hot = 0.0
	_you_big = false
	bulls = 0
	outers = 0
	trebles = 0
	doubles = 0
	best_dart = 0
	thrown = 0
	_next_turn()


# ---- the board ------------------------------------------------------------------------------------------
# what a dart at p (mm from the bull, x to the right, y down) scores: {ring, num, pts}
static func score_at(p: Vector2) -> Dictionary:
	var d := p.length()
	if d <= BULL_R:
		return {"ring": "bull", "num": 50, "pts": 50}
	if d <= OUTER_BULL_R:
		return {"ring": "outer", "num": 25, "pts": 25}
	if d > BOARD_R:
		return {"ring": "miss", "num": 0, "pts": 0}
	var deg := fposmod(rad_to_deg(atan2(p.x, -p.y)) + 9.0, 360.0)
	var num: int = SEGMENTS[int(deg / 18.0) % 20]
	if d >= TREBLE_IN and d <= TREBLE_OUT:
		return {"ring": "treble", "num": num, "pts": num * 3}
	if d >= DOUBLE_IN:
		return {"ring": "double", "num": num, "pts": num * 2}
	return {"ring": "single", "num": num, "pts": num}


# the centre of a wedge's treble ring (the crew's aim and the bot's): num 20 is straight up
static func wedge_centre(num: int, radius: float) -> Vector2:
	var i := SEGMENTS.find(num)
	var a := deg_to_rad(float(i) * 18.0)
	return Vector2(sin(a), -cos(a)) * radius


static func ring_label(s: Dictionary) -> String:
	match str(s.ring):
		"bull":
			return "BULLSEYE! 50"
		"outer":
			return "OUTER BULL 25"
		"treble":
			return "TREBLE %d: %d" % [int(s.num), int(s.pts)]
		"double":
			return "DOUBLE %d: %d" % [int(s.num), int(s.pts)]
		"single":
			return "%d" % int(s.pts)
	return "OFF THE BOARD"


# ---- the reticle ----------------------------------------------------------------------------------------
# how much of the drift is left at aim time s: it settles to STEADY_MIN at STEADY_T, then the arm tires
func steadiness(s: float) -> float:
	return STEADY_MIN + (1.0 - STEADY_MIN) * clampf(absf(s - STEADY_T) / STEADY_T, 0.0, 1.0)


func reticle_at(s: float) -> Vector2:
	var w := speed * zs
	var k := drift * steadiness(s)
	return zc + Vector2(sin(w * s + zp), 0.85 * sin(w * 1.31 * s + zp * 1.7 + 1.0)) * k


func reticle() -> Vector2:
	return reticle_at(aim_t)


# a new sweet spot for the next dart: the loop's centre moves, its speed and phase change
func roll_zone() -> void:
	if zone_rng == null:
		zc = Vector2.ZERO
		zs = 1.0
		zp = 0.0
		return
	zc = Vector2(zone_rng.randf_range(-ZONE_C, ZONE_C), zone_rng.randf_range(-ZONE_C, ZONE_C))
	zs = zone_rng.randf_range(0.88, 1.14)
	zp = zone_rng.randf_range(0.0, TAU)


# ---- turns ----------------------------------------------------------------------------------------------
func thrower() -> String:
	return str(players[turn_i % players.size()]) if turn_i >= 0 and turn_i < players.size() * rounds else ""


func round_no() -> int:
	return mini(rounds, turn_i / players.size() + 1)


func your_turn() -> bool:
	return thrower() == "You"


func opponent() -> String:  # whoever throws now when it is not you ("" on your turn)
	var who := thrower()
	return "" if who == "You" else who


func is_done() -> bool:
	return phase == "done"


func aiming() -> bool:
	return phase == "aim"


func _next_turn() -> void:
	turn_i += 1
	if turn_i >= players.size() * rounds:
		phase = "done"
		_settle_result()
		events.append({"e": "end", "who": ""})
		return
	dart_i = 0
	turn_pts = 0
	_turn_best = 0
	darts_now = []
	flying = {}
	phase = "ready"
	t = 0.0
	msg = "ROUND %d: %s" % [round_no(), "YOUR THROW" if your_turn() else "%s STEPS UP" % thrower()]
	events.append({"e": "turn", "who": thrower()})


func _begin_dart() -> void:
	t = 0.0
	if your_turn():
		phase = "aim"
		aim_t = 0.0
		roll_zone()
	else:
		phase = "opp"


# E (or Space / Enter): throw at the reticle. Returns "throw" or "".
func press() -> String:
	if phase != "aim":
		return ""
	var p := reticle()
	p.x += rng.randfn(0.0, noise)
	p.y += rng.randfn(0.0, noise)
	_launch("You", p)
	return "throw"


func _launch(who: String, p: Vector2) -> void:
	flying = {"who": who, "px": p.x, "py": p.y, "t": 0.0}
	phase = "flight"
	t = 0.0


# ---- the crew's dart ------------------------------------------------------------------------------------
func temper(who: String) -> Dictionary:
	return TEMPERS.get(who, HOUSE)


# the skill of somebody right now (their base, the tier, the streak and the show-off bonus)
func skill_of(who: String) -> float:
	var row := temper(who)
	var skill := float(row.skill) + opp_skill
	if float(row.streak) > 0.0:
		skill += float(row.streak) * _hot
	if float(row.show) > 0.0 and (crew.size() >= 2 or _you_big):
		skill += float(row.show)
	return clampf(skill, 0.0, 1.0)


func sigma_of(who: String) -> float:
	return lerpf(40.0, 12.0, skill_of(who))


# the good ones go for the treble 20, the rest for the bull
func target_of(who: String) -> Vector2:
	return wedge_centre(20, (TREBLE_IN + TREBLE_OUT) * 0.5) if skill_of(who) >= 0.55 else Vector2.ZERO


func throw_opp() -> void:
	var who := thrower()
	var row := temper(who)
	var s := sigma_of(who)
	if float(row.wild) > 0.0 and rng.randf() < float(row.wild):
		s *= 2.6
	elif float(row.show) > 0.0 and rng.randf() < 0.18:
		s *= 2.0  # a trick throw
	var aim := target_of(who)
	_launch(who, Vector2(aim.x + rng.randfn(0.0, s), aim.y + rng.randfn(0.0, s)))


# ---- time -----------------------------------------------------------------------------------------------
func step(dt: float) -> void:
	match phase:
		"ready":
			t += dt
			if t >= READY:
				_begin_dart()
		"aim":
			aim_t += dt
		"opp":
			t += dt
			if t >= WINDUP:
				throw_opp()
		"flight":
			t += dt
			flying["t"] = minf(1.0, t / FLIGHT)
			if t >= FLIGHT:
				_land()
		"settle":
			t += dt
			if t >= SETTLE:
				dart_i += 1
				if dart_i >= DARTS:
					_end_turn()
				else:
					_begin_dart()
		"pull":
			t += dt
			if t >= PULL:
				_next_turn()


func _land() -> void:
	var who: String = flying.who
	var s := score_at(Vector2(float(flying.px), float(flying.py)))
	var pts := int(s.pts)
	darts_now.append({"who": who, "px": float(flying.px), "py": float(flying.py), "ring": s.ring, "num": s.num, "pts": pts})
	totals[who] = int(totals[who]) + pts
	turn_pts += pts
	_turn_best = maxi(_turn_best, pts)
	if who == "You":
		thrown += 1
		best_dart = maxi(best_dart, pts)
		match str(s.ring):
			"bull":
				bulls += 1
			"outer":
				outers += 1
			"treble":
				trebles += 1
			"double":
				doubles += 1
		_you_big = pts >= 40
		msg = ring_label(s)
	else:
		_hot = 1.0 if pts >= 40 else (-1.0 if pts == 0 else 0.0)
		msg = "%s: %s" % [who, ring_label(s)]
	events.append({"e": "bull" if str(s.ring) == "bull" else "dart", "who": who, "pts": pts, "ring": s.ring, "num": s.num})
	flying = {}
	phase = "settle"
	t = 0.0


func _end_turn() -> void:
	msg = "%s: %d THIS TURN. TOTAL %d." % [thrower() if not your_turn() else "YOU", turn_pts, int(totals[thrower()])]
	events.append({"e": "pull", "who": thrower()})
	phase = "pull"
	t = 0.0


# ---- the result -----------------------------------------------------------------------------------------
func best_opp() -> int:
	var top := 0
	for p in players:
		if p != "You":
			top = maxi(top, int(totals[p]))
	return top


func leader() -> String:  # who is ahead (You on a tie)
	var top := "You"
	for p in players:
		if int(totals[p]) > int(totals[top]):
			top = p
	return top


func margin() -> int:
	return int(totals["You"]) - best_opp()


func _settle_result() -> void:
	won = margin() > 0


func stars() -> int:
	if not is_done():
		return 0
	var m := margin()
	var s := 0
	if m >= BIG_WIN:
		s = 3
	elif m > 0:
		s = 2
	elif m > -CLOSE:
		s = 1
	return maxi(s, floor_stars)
