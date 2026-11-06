extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# CORNHOLE (roadmap R21 part a): the rules of the bag toss in the warehouse. A RefCounted with no autoload references so
# tests can run it headless (the Difficulty numbers come in as `params`, see Outings._corn_setup); the drawing is done by
# fx.gd (kind cornhole_a / cornhole_b) in the room and the HUD strip by Outings.
# Two boards face each other. You stand at board A and throw at board B, the crew member of the round stands at board B and
# throws at A, one bag each in turn, four bags a turn. A bag is thrown with two stops: an AIM marker (sideways, 0.5 is the
# middle of the board) and a POWER bar (distance, POWER_BEST is the hole), both bounce between 0 and 1.
# Where a bag lands (inches on the board, 48 long and 24 wide, the hole 9 in from the far end):
#   in the HOLE (within HOLE_R of the hole, or on the lip with a coin flip) = 3, on the BOARD = 1, off it = 0.
# Cancellation scoring: at the end of a round the lower side is taken off the higher side and only the difference scores.
# You play a different crew member every round in the order Alan, Garrison, Dan, Maya, John (only the ones who came), first
# to `to` points wins. Stars: win by 7 or more = 3, win = 2, loss = 0 (1 on cozy Easy, set by the caller through `floor`).

const ORDER := ["Alan", "Garrison", "Dan", "Maya", "John"]
const BAGS := 4
const BOARD_LEN := 48.0
const BOARD_W := 24.0
const HOLE_X := 39.0
const HOLE_R := 6.5
const LIP := 2.5
const POWER_BEST := 0.6
const POWER_SCALE := 70.0
const AIM_SCALE := 36.0
const NOISE := 0.8  # inches of wobble on your own throw
const FLIGHT := 0.75
const SETTLE := 0.55
const READY := 1.2
const ROUND_PAUSE := 2.2
const WINDUP := 0.6
const MAX_ROUNDS := 14
const BIG_WIN := 7
# the crew: a base skill 0..1 (the error of a throw is lerp(11, 2.4, skill) inches), and a temper
#   precise: less sideways error. streak: hot after a hole, cold after a miss. wild: now and then a throw nobody planned.
#   show: better with an audience (three or more at the party, or you just scored) but now and then a trick throw.
const TEMPERS := {
	"Alan": {"skill": 0.62, "precise": 0.6, "streak": 0.0, "wild": 0.0, "show": 0.0},
	"Garrison": {"skill": 0.52, "precise": 1.0, "streak": 0.12, "wild": 0.0, "show": 0.0},
	"Dan": {"skill": 0.45, "precise": 1.0, "streak": 0.0, "wild": 0.14, "show": 0.0},
	"Maya": {"skill": 0.58, "precise": 0.9, "streak": 0.0, "wild": 0.0, "show": 0.0},
	"John": {"skill": 0.5, "precise": 1.0, "streak": 0.0, "wild": 0.0, "show": 0.12},
}
const HOUSE := {"skill": 0.5, "precise": 1.0, "streak": 0.0, "wild": 0.0, "show": 0.0}

var to := 15
var opp_skill := 0.0
var aim_speed := 1.3
var power_speed := 1.1
var assist := false  # a short bag slides up onto the board (easy)
var floor_stars := 0  # 1 on cozy Easy
var rng: RandomNumberGenerator
var crew: Array = []  # the opponents, in order

var phase := "ready"  # ready, aim, power, flight, settle, opp, round_end, done
var round_no := 1
var seq := 0  # 0..7 inside a round, even = you
var opp := ""
var aim_c := 0.5  # where the hole sits on the aim bar this bag (drawn green); moves when a zone_rng is given
var pow_c := POWER_BEST  # and on the power bar
var zone_rng: RandomNumberGenerator = null
var marker := 0.0
var marker_aim := 0.5  # the aim you stopped at
var power := 0.0
var dir := 1.0
var t := 0.0
var score_you := 0
var score_opp := 0
var round_you := 0
var round_opp := 0
var round_net := 0
var holes := 0  # your bags in the hole, in all
var boards := 0
var misses := 0
var flying := {}  # the bag in the air: who, px, py, kind, t
var landed: Array = []  # this round, for the drawing: {who, px, py, kind}
var events: Array = []  # what just happened: {"e": "thud" | "hole" | "knock" | "round" | "end", "who": ...}
var msg := ""
var won := false
var _hot := 0.0  # Garrison's streak
var _you_hole_round := false
var _last_opp_in := false


func setup(params: Dictionary, crew_names: Array, r: RandomNumberGenerator) -> void:
	to = int(params.get("to", 15))
	opp_skill = float(params.get("opp_skill", 0.0))
	aim_speed = float(params.get("aim_speed", 1.3))
	power_speed = float(params.get("power_speed", 1.1))
	assist = bool(params.get("assist", false))
	floor_stars = int(params.get("floor", 0))
	rng = r
	zone_rng = params.get("zone_rng", null)
	crew = ORDER.filter(func(n: String) -> bool: return crew_names.has(n))
	round_no = 0
	score_you = 0
	score_opp = 0
	holes = 0
	boards = 0
	misses = 0
	won = false
	_new_round()


func opponent_for(round_n: int) -> String:
	return "THE CREW" if crew.is_empty() else str(crew[(round_n - 1) % crew.size()])


func temper(who: String) -> Dictionary:
	return TEMPERS.get(who, HOUSE)


func _new_round() -> void:
	round_no += 1
	opp = opponent_for(round_no)
	seq = 0
	round_you = 0
	round_opp = 0
	round_net = 0
	landed = []
	flying = {}
	_you_hole_round = false
	_hot = 0.0
	phase = "ready"
	t = 0.0
	msg = "ROUND %d: YOU AGAINST %s" % [round_no, opp]
	events.append({"e": "round", "who": opp})


func is_done() -> bool:
	return phase == "done"


# which of your four bags this is (1 to 4)
func bag_no() -> int:
	return mini(BAGS, int(float(seq) * 0.5) + 1)


func your_turn() -> bool:
	return phase in ["aim", "power"]


# ---- the player's two stops ----------------------------------------------------------------------------
# E (or Space / Enter): stop the aim, then stop the power, which throws. Returns what happened.
func press() -> String:
	if phase == "aim":
		marker_aim = marker
		phase = "power"
		power = 0.0
		dir = 1.0
		return "aim"
	if phase == "power":
		throw_you(marker_aim, power)
		return "throw"
	return ""


# where a bag with this aim and power would land (without the wobble)
static func spot(aim: float, pow_v: float, aim_mid := 0.5, pow_mid := POWER_BEST) -> Vector2:
	return Vector2(HOLE_X + (pow_v - pow_mid) * POWER_SCALE, (aim - aim_mid) * AIM_SCALE)


# a new sweet spot for your next bag: the hole is the same, the stops that find it move (the green is drawn there)
func roll_zone() -> void:
	if zone_rng == null:
		aim_c = 0.5
		pow_c = POWER_BEST
		return
	aim_c = zone_rng.randf_range(0.32, 0.68)
	pow_c = zone_rng.randf_range(0.42, 0.78)


func throw_you(aim: float, pow_v: float) -> void:
	var p := spot(aim, pow_v, aim_c, pow_c)
	p.x += rng.randfn(0.0, NOISE)
	p.y += rng.randfn(0.0, NOISE)
	_launch("you", p)


func _launch(who: String, p: Vector2) -> void:
	flying = {"who": who, "px": p.x, "py": p.y, "kind": _classify(p), "t": 0.0}
	phase = "flight"
	t = 0.0


func _classify(p: Vector2) -> String:
	var d := p.distance_to(Vector2(HOLE_X, 0.0))
	if d <= HOLE_R:
		return "hole"
	if d <= HOLE_R + LIP and rng.randf() < 0.5:
		return "hole"
	if p.x < 0.0:
		return "board" if assist and p.x >= -8.0 else "floor"
	if p.x > BOARD_LEN or absf(p.y) > BOARD_W * 0.5:
		return "floor"
	return "board"


# ---- the crew's throw ----------------------------------------------------------------------------------
# the error of a throw in inches for somebody (their skill, tier, streak and show-off bonus)
func opp_sigma(who: String) -> Vector2:
	var row := temper(who)
	var skill := float(row.skill) + opp_skill
	if float(row.streak) > 0.0:
		skill += float(row.streak) * _hot
	if float(row.show) > 0.0 and (crew.size() >= 3 or _you_hole_round):
		skill += float(row.show)
	var sd := lerpf(10.0, 2.2, clampf(skill, 0.0, 1.0))
	return Vector2(sd, sd * 0.8 * float(row.precise))


func throw_opp() -> void:
	var s := opp_sigma(opp)
	var row := temper(opp)
	if float(row.wild) > 0.0 and rng.randf() < float(row.wild):
		s *= 2.8
	elif float(row.show) > 0.0 and rng.randf() < 0.18:
		s *= 2.0  # a trick throw
	_launch("opp", Vector2(HOLE_X + rng.randfn(0.0, s.x), rng.randfn(0.0, s.y)))


# ---- time ----------------------------------------------------------------------------------------------
func step(dt: float) -> void:
	match phase:
		"ready":
			t += dt
			if t >= READY:
				_next_turn()
		"aim", "power":
			var speed := aim_speed if phase == "aim" else power_speed
			var key_v: float = marker if phase == "aim" else power
			key_v += dir * dt * speed
			if key_v >= 1.0:
				key_v = 1.0
				dir = -1.0
			elif key_v <= 0.0:
				key_v = 0.0
				dir = 1.0
			if phase == "aim":
				marker = key_v
			else:
				power = key_v
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
				seq += 1
				_next_turn()
		"round_end":
			t += dt
			if t >= ROUND_PAUSE:
				if _game_over():
					phase = "done"
					events.append({"e": "end", "who": ""})
				else:
					_new_round()


func _next_turn() -> void:
	t = 0.0
	if seq >= BAGS * 2:
		_end_round()
	elif seq % 2 == 0:
		phase = "aim"
		marker = 0.0
		power = 0.0
		dir = 1.0
		roll_zone()
	else:
		phase = "opp"


# what a bag does when it comes down
func _land() -> void:
	var who: String = flying.who
	var kind: String = flying.kind
	var pts := 3 if kind == "hole" else (1 if kind == "board" else 0)
	landed.append({"who": who, "px": float(flying.px), "py": float(flying.py), "kind": kind})
	if who == "you":
		round_you += pts
		if kind == "hole":
			holes += 1
			_you_hole_round = true
			msg = "IN THE HOLE! +3"
			events.append({"e": "hole", "who": who})
		elif kind == "board":
			boards += 1
			msg = "ON THE BOARD +1"
			events.append({"e": "knock", "who": who})
		else:
			misses += 1
			msg = "OFF THE BOARD"
			events.append({"e": "thud", "who": who})
	else:
		round_opp += pts
		_last_opp_in = kind == "hole"
		_hot = 1.0 if kind == "hole" else (-1.0 if kind == "floor" else 0.0)
		msg = "%s: %s" % [opp, "IN THE HOLE! +3" if kind == "hole" else ("ON THE BOARD +1" if kind == "board" else "OFF THE BOARD")]
		events.append({"e": "hole" if kind == "hole" else ("knock" if kind == "board" else "thud"), "who": who})
	flying = {}
	phase = "settle"
	t = 0.0


func _end_round() -> void:
	round_net = round_you - round_opp
	if round_net > 0:
		score_you += round_net
	elif round_net < 0:
		score_opp += -round_net
	msg = (
		"ROUND %d: %d TO %d. YOU +%d." % [round_no, round_you, round_opp, round_net]
		if round_net > 0
		else ("ROUND %d: %d TO %d. %s +%d." % [round_no, round_you, round_opp, opp, -round_net] if round_net < 0 else "ROUND %d: %d TO %d. THEY CANCEL." % [round_no, round_you, round_opp])
	)
	phase = "round_end"
	t = 0.0


func _game_over() -> bool:
	if score_you >= to or score_opp >= to:
		won = score_you > score_opp
		return true
	if round_no >= MAX_ROUNDS and score_you != score_opp:
		won = score_you > score_opp
		return true
	if round_no >= MAX_ROUNDS + 2:
		won = false
		return true
	return false


func margin() -> int:
	return score_you - score_opp


func stars() -> int:
	if not is_done():
		return 0
	if won:
		return 3 if margin() >= BIG_WIN else 2
	return floor_stars
