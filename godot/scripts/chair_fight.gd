extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# CHAIR FIGHT (roadmap R12): a duel on rolling chairs in the warehouse, the third event on the chair race card. A RefCounted with
# no autoload references so tests can run it headless (the Difficulty numbers come in as `params`, see Outings._chair_setup);
# chair_track.gd draws it with the race's own puppets (this class has the fields the track reads: pos, lane, wobble, rivals).
# Two chairs face each other on a strip of the floor (`LO` to `HI`, the same course positions as the race) with three lanes.
#   Z and X in turn push you off the way you face (the race's rhythm and stamina, to the number).
#   LEFT / RIGHT spin the chair around to face that way (it takes a moment, and you cannot push while it turns).
#   UP / DOWN change lane: in another lane the chairs roll past each other.
# When the chairs meet in one lane, whoever rolls at the other clearly faster (by `EDGE`) lands a BUMP: the other chair is knocked
# back and spins, dizzy, for a second (and cannot be bumped again for a moment). About the same speed is a CLASH: both bounce,
# no point. Rolling into a chair that is dizzy, turning or looking the other way counts as soon as you are fast enough.
# First to TARGET bumps wins; when the clock runs out the most bumps win. The opponent is one of the crew, drawn on the seeded
# stream; the rest of the racers watch from the ends of the strip.

const ChairRace := preload("res://scripts/chair_race.gd")
const LANES := 3
const LO := 250.0  # the strip, as course positions (ChairRace.world_x): the middle of the warehouse floor
const HI := 510.0
const TARGET := 3
const LIMIT := 75.0  # seconds of play
const COUNT := 3.0
const HIT_X := 15.0  # the chairs touch when they are closer than this
const HIT_LANE := 0.62
const MIN_BUMP := 16.0  # px/s towards the other chair before a touch counts as a bump
const EDGE := 7.0  # px/s you must be faster than the other chair to win a head-on
const DIZZY := 1.3  # seconds a bumped chair spins
const SAFE := 2.4  # seconds a bumped chair cannot be bumped again
const TURN := 0.3  # seconds a spin-around takes
const HIT_GAP := 0.45  # seconds before the two chairs can touch again
const WALL_BOUNCE := 0.25
const TIER_SKILL := 2.5  # x the tier's chair.skill (-0.08 / 0 / +0.08): in a duel the other chair's legs are all there is
# the crew as fighters: how they push and what they say
const STYLES := {
	"Alan": {"skill": 0.46, "dodge": 0.7, "chase": 0.75, "win": "ALAN: I FILED THAT UNDER 'PREVENTIVE MAINTENANCE'.", "lose": "ALAN: THAT CHAIR IS NOT RATED FOR THIS."},
	"Garrison": {"skill": 0.56, "dodge": 0.0, "chase": 0.3, "win": "GARRISON: UNDEFEATED. DO NOT CHECK THAT.", "lose": "GARRISON: REMATCH. NOW. SAME CHAIRS."},
	"Dan": {"skill": 0.5, "dodge": 0.3, "chase": 0.55, "win": "DAN: I BARELY PUT MY COFFEE DOWN.", "lose": "DAN: GOOD BUMP. I FELT THAT IN MY TICKETS."},
	"Maya": {"skill": 0.52, "dodge": 0.4, "chase": 0.4, "win": "MAYA: YOU NEVER SAW ME COMING. NOBODY DOES.", "lose": "MAYA: MY WHEELS WERE STICKY. WRITE THAT DOWN."},
	"John": {"skill": 0.5, "dodge": 0.2, "chase": 0.6, "win": "JOHN: AND THAT IS HOW YOU CLOSE.", "lose": "JOHN: I WAS ON A CALL. IN MY HEAD."},
}

var params := {"stamina": 1.0, "skill": 0.0}
var rng := RandomNumberGenerator.new()
var chairs: Array = []  # [you, the opponent]: {n, x, s, v, lane, lane_to, face, stam, key, last, dizzy, safe, turn, bumps, flag, color, ...}
var rivals: Array = []  # what the track draws beside you: the opponent (chairs[1]) and whoever watches
var obstacles: Array = []  # (the track asks: there are none)
var arena := [LO, HI]
var fight := true
var phase := "count"  # count, go, done
var clock := -COUNT
var end_t := 0.0
var winner := -1  # 0 you, 1 them, 2 a draw
var msg := ""
var msg_t := 0.0
var feel := ""
var feel_t := 0.0
var events: Array = []  # go, bump, ouch, clash, clunk, finish (for sounds; the owner clears it)
var clashes := 0
var you_auto := false  # tests and demos: the crew's driver has your chair too
var cp_next := 0  # (the track asks: no checkpoints)
var checks: Array = []
var length := HI

var _hit_cd := 0.0
var _flash := {0: 0.0, 1: 0.0}

# what chair_track.gd reads for "You"
var pos: float:
	get:
		return float(chairs[0].x) if not chairs.is_empty() else LO
var lane: float:
	get:
		return float(chairs[0].lane) if not chairs.is_empty() else 1.0
var wobble: float:
	get:
		return float(chairs[0].dizzy) if not chairs.is_empty() else 0.0
var face: int:
	get:
		return int(chairs[0].face) if not chairs.is_empty() else 1
var stam: float:
	get:
		return float(chairs[0].stam) if not chairs.is_empty() else 100.0


# params: stamina (x cost of your pushes), skill (added to the opponent's), opponent (a name, for tests and the toolbox).
# names: the racers who came (any of ChairRace.ORDER): one fights, the rest watch.
func setup(p: Dictionary, names: Array, r: RandomNumberGenerator) -> void:
	for k in p:
		params[k] = p[k]
	rng = r
	var pool: Array = names.filter(func(n: String) -> bool: return STYLES.has(n))
	var who := str(params.get("opponent", ""))
	if not STYLES.has(who):
		who = str(pool[rng.randi() % pool.size()]) if not pool.is_empty() else "Garrison"
	var st: Dictionary = STYLES[who]
	chairs = [_chair("You", LO + 40.0, 1, Color.WHITE, 0.5), _chair(who, HI - 40.0, -1, ChairRace.RACERS[who].color, clampf(float(st.skill) + TIER_SKILL * float(params.get("skill", 0.0)) + (rng.randf() - 0.5) * 0.06, 0.1, 0.9))]
	rivals = [chairs[1]]
	var n := 0
	for other in pool:
		if other == who:
			continue
		var left := n % 2 == 0
		var at := (LO - 26.0 - 22.0 * float(n >> 1)) if left else (HI + 26.0 + 22.0 * float(n >> 1))
		rivals.append({"n": other, "s": at, "lane": float([0, 2][(n >> 1) % 2]), "flag": "", "face": 1 if left else -1, "color": ChairRace.RACERS[other].color, "watch": true})
		n += 1
	phase = "count"
	clock = -COUNT
	end_t = 0.0
	winner = -1
	msg = ""
	msg_t = 0.0
	clashes = 0
	events = []


func _chair(who: String, x: float, facing: int, color: Color, skill: float) -> Dictionary:
	return {
		"n": who,
		"x": x,
		"s": x,
		"v": 0.0,
		"lane": 1.0,
		"lane_to": 1,
		"face": facing,
		"stam": 100.0,
		"key": -1,
		"last": -10.0,
		"dizzy": 0.0,
		"safe": 0.0,
		"turn": 0.0,
		"bumps": 0,
		"flag": "",
		"color": color,
		"skill": skill,
		"pushes": 0,
		"good": 0,
		# the driver's own notes (the crew, or the test bot)
		"rest": false,
		"gap": 0.4,
		"see_t": 0.0,
		"lane_t": 0.0,
		"dodge_cd": 0.0,
	}


func opponent() -> String:
	return str(chairs[1].n)


func score() -> Array:
	return [int(chairs[0].bumps), int(chairs[1].bumps)]


func _say(text: String, secs := 1.2) -> void:
	msg = text
	msg_t = secs


func countdown_text() -> String:
	return "" if clock >= 0.0 else str(int(ceilf(-clock)))


func time_left() -> int:
	return maxi(0, ceili(LIMIT - maxf(clock, 0.0)))


func lit(key: int) -> bool:
	return float(_flash[key]) > 0.0


# ---- the controls (chair 0 is you) ---------------------------------------------------------------------
func push(key: int) -> bool:
	return push_of(0, key)


func change_lane(dir: int) -> void:
	lane_of(0, dir)


func spin(dir: int) -> bool:
	return spin_of(0, dir)


func lane_of(i: int, dir: int) -> void:
	if phase == "done":
		return
	var c: Dictionary = chairs[i]
	c.lane_to = clampi(int(c.lane_to) + dir, 0, LANES - 1)


# face the other way: the chair spins around (TURN seconds without a push)
func spin_of(i: int, dir: int) -> bool:
	var c: Dictionary = chairs[i]
	if phase != "go" or dir == 0 or signi(dir) == int(c.face) or float(c.dizzy) > 0.0 or float(c.turn) > 0.0:
		return false
	c.face = signi(dir)
	c.turn = TURN
	return true


# one push off the floor, the way the chair faces: the race's rhythm and stamina (ChairRace.push)
func push_of(i: int, key: int) -> bool:
	var c: Dictionary = chairs[i]
	if phase != "go" or float(c.dizzy) > 0.0 or float(c.turn) > 0.0:
		return false
	var gap: float = clock - float(c.last)
	var same: bool = key == int(c.key)
	var q := 1.0
	var cost: float = ChairRace.STAM_COST
	var how := "GOOD"
	if int(c.key) < 0:
		gap = (ChairRace.GAP_LO + ChairRace.GAP_HI) * 0.5
		same = false
	if same:
		q = 0.25
		cost = ChairRace.STAM_SAME
		how = "SAME LEG"
	elif gap < ChairRace.MASH_GAP:
		q = 0.15
		cost = ChairRace.STAM_MASH
		how = "TOO FAST"
	elif gap < ChairRace.GAP_LO:
		var t: float = (gap - ChairRace.MASH_GAP) / (ChairRace.GAP_LO - ChairRace.MASH_GAP)
		q = lerpf(0.3, 1.0, t)
		cost = lerpf(ChairRace.STAM_MASH, ChairRace.STAM_COST, t)
		how = "RUSHED"
	elif gap > ChairRace.GAP_HI:
		q = maxf(0.6, 1.0 - (gap - ChairRace.GAP_HI) * 0.5)
		how = "SLOW"
	else:
		c.good = int(c.good) + 1
	var f := 0.3 + 0.7 * clampf(float(c.stam) / 100.0, 0.0, 1.0)
	if float(c.stam) < 15.0:
		how = "TIRED"
	c.v = float(c.v) + float(c.face) * ChairRace.IMPULSE * q * f
	c.stam = maxf(0.0, float(c.stam) - cost * (float(params.stamina) if i == 0 else 1.0))
	c.pushes = int(c.pushes) + 1
	c.key = key
	c.last = clock
	if i == 0:
		feel = how
		feel_t = 0.8
		_flash[key] = 0.25
	return true


# ---- the clock -----------------------------------------------------------------------------------------
func step(dt: float) -> void:
	msg_t = maxf(0.0, msg_t - dt)
	feel_t = maxf(0.0, feel_t - dt)
	for k in _flash:
		_flash[k] = maxf(0.0, float(_flash[k]) - dt)
	clock += dt
	if phase == "done":
		end_t += dt
	elif clock < 0.0:
		return
	elif phase == "count":
		phase = "go"
		_say("GO!", 0.9)
		events.append("go")
	_hit_cd = maxf(0.0, _hit_cd - dt)
	for i in 2:
		if phase == "go" and (i == 1 or you_auto):
			_drive(i, dt)
		_roll(chairs[i], dt)
	if phase != "go":
		return
	_meet()
	if int(chairs[0].bumps) >= TARGET or int(chairs[1].bumps) >= TARGET or clock >= LIMIT:
		_finish()


func _roll(c: Dictionary, dt: float) -> void:
	c.dizzy = maxf(0.0, float(c.dizzy) - dt)
	c.safe = maxf(0.0, float(c.safe) - dt)
	c.turn = maxf(0.0, float(c.turn) - dt)
	c.flag = "spin" if (float(c.dizzy) > 0.0 or float(c.turn) > 0.0) else ""
	c.lane = move_toward(float(c.lane), float(c.lane_to), ChairRace.LANE_RATE * dt)
	var v: float = float(c.v) * exp(-ChairRace.DRAG * dt)
	v = move_toward(v, 0.0, 1.5 * dt)
	var x: float = float(c.x) + v * dt
	if x < LO or x > HI:
		x = clampf(x, LO, HI)
		if absf(v) > 20.0:
			events.append("clunk")
			v = -v * WALL_BOUNCE
		else:
			v = 0.0
	c.x = x
	c.s = x
	c.v = v
	c.stam = minf(100.0, float(c.stam) + (ChairRace.STAM_REGEN if clock - float(c.last) > 0.45 else ChairRace.STAM_STEADY) * dt)


# the two chairs touch
func _meet() -> void:
	var a: Dictionary = chairs[0]
	var b: Dictionary = chairs[1]
	var gap: float = float(b.x) - float(a.x)
	if _hit_cd > 0.0 or absf(gap) >= HIT_X or absf(float(a.lane) - float(b.lane)) >= HIT_LANE:
		return
	var dir := 1.0 if gap >= 0.0 else -1.0  # from you to them
	var ta: float = float(a.v) * dir  # how fast each rolls at the other
	var tb: float = -float(b.v) * dir
	if ta + tb <= 4.0:
		return  # drifting apart, or barely moving
	_hit_cd = HIT_GAP
	# a chair that is dizzy, turning, or has its back to the other one is not attacking
	var pa: float = ta if _attacks(a, dir) else 0.0
	var pb: float = tb if _attacks(b, -dir) else 0.0
	var closing := ta + tb
	var kick := 16.0 + 0.3 * closing
	var mid: float = (float(a.x) + float(b.x)) * 0.5
	a.x = clampf(mid - dir * (HIT_X * 0.5 + 0.5), LO, HI)
	b.x = clampf(mid + dir * (HIT_X * 0.5 + 0.5), LO, HI)
	a.v = -dir * kick
	b.v = dir * kick
	if pa >= MIN_BUMP and pa - pb > EDGE and float(b.safe) <= 0.0:
		_bump(0, 1, dir)
	elif pb >= MIN_BUMP and pb - pa > EDGE and float(a.safe) <= 0.0:
		_bump(1, 0, -dir)
	elif maxf(pa, pb) >= MIN_BUMP:
		clashes += 1
		_say("CLASH! NOBODY GIVES.", 1.0)
		events.append("clash")
	else:
		events.append("tap")


func _attacks(c: Dictionary, toward: float) -> bool:
	return float(c.dizzy) <= 0.0 and float(c.turn) <= 0.0 and float(c.face) * toward > 0.0


func _bump(by: int, on: int, dir: float) -> void:
	var w: Dictionary = chairs[by]
	var l: Dictionary = chairs[on]
	w.bumps = int(w.bumps) + 1
	w.v = float(w.v) * 0.5
	l.v = dir * (absf(float(l.v)) * 1.5 + 8.0)
	l.dizzy = DIZZY
	l.safe = SAFE
	if by == 0:
		_say("BUMP! %d TO %d" % score(), 1.4)
		events.append("bump")
	else:
		_say("%s GOT YOU! %d TO %d" % [str(w.n).to_upper(), int(chairs[0].bumps), int(chairs[1].bumps)], 1.4)
		events.append("ouch")


func _finish() -> void:
	phase = "done"
	end_t = 0.0
	var s := score()
	winner = 0 if s[0] > s[1] else (1 if s[1] > s[0] else 2)
	_say("THAT IS THE FIGHT!" if maxi(s[0], s[1]) >= TARGET else "TIME!", 2.0)
	events.append("finish")


# ---- the driver (the crew; with you_auto, your chair too) ------------------------------------------------
# faces the other chair, pushes in a rhythm its skill allows, rests when it is out of breath, follows you into your lane after
# a beat, and (the careful ones) ducks into another lane when it is about to lose a head-on
func _drive(i: int, dt: float) -> void:
	var c: Dictionary = chairs[i]
	var o: Dictionary = chairs[1 - i]
	var st: Dictionary = STYLES.get(str(c.n), {"dodge": 0.3, "chase": 0.5})
	var skill: float = float(c.skill)
	var gap: float = float(o.x) - float(c.x)
	var toward := 1 if gap >= 0.0 else -1
	c.dodge_cd = maxf(0.0, float(c.dodge_cd) - dt)
	if float(c.dizzy) > 0.0:
		return
	if int(c.face) != toward:  # they are behind me: notice, then spin around
		c.see_t = float(c.see_t) + dt
		if float(c.see_t) >= 0.5 - 0.3 * skill:
			c.see_t = 0.0
			spin_of(i, toward)
		return
	c.see_t = 0.0
	var mine: float = float(c.v) * float(toward)
	var theirs: float = -float(o.v) * float(toward)
	var same_lane: bool = int(c.lane_to) == int(o.lane_to)
	if same_lane and absf(gap) < 70.0 and theirs - mine > EDGE and float(c.dodge_cd) <= 0.0 and float(c.safe) <= 0.0:
		c.dodge_cd = 1.6
		if rng.randf() < float(st.dodge) * (0.6 + 0.8 * skill):
			var to := int(c.lane_to) + (1 if int(c.lane_to) == 0 else (-1 if int(c.lane_to) == LANES - 1 else (1 if rng.randf() < 0.5 else -1)))
			c.lane_to = clampi(to, 0, LANES - 1)
			c.lane_t = -0.6  # and stays there for a moment
	elif not same_lane:
		c.lane_t = float(c.lane_t) + dt
		if float(c.lane_t) >= float(st.chase) * (1.3 - 0.6 * skill):
			c.lane_t = 0.0
			c.lane_to = int(c.lane_to) + signi(int(o.lane_to) - int(c.lane_to))
	else:
		c.lane_t = minf(float(c.lane_t), 0.0)
	# the legs
	if float(c.stam) < 22.0:
		c.rest = true
	elif float(c.stam) > 55.0 + 20.0 * skill:
		c.rest = false
	var wait: float = float(c.gap)
	if bool(c.rest) or clock - float(c.last) < wait or mine > 62.0:
		return
	var key := 1 - int(c.key) if int(c.key) >= 0 else 0
	if rng.randf() < 0.22 * (1.0 - skill):
		key = int(c.key) if int(c.key) >= 0 else 0  # the wrong leg
	push_of(i, key)
	c.gap = lerpf(0.56, 0.36, skill) + rng.randf_range(-0.05, 0.07) * (1.2 - skill)


# ---- the result ----------------------------------------------------------------------------------------
func stars() -> int:
	var s := score()
	if winner == 0:
		return 3 if s[1] <= 1 else 2
	if winner == 2 or s[0] >= 2:
		return 1
	return 0


func comment() -> String:
	if winner == 2:
		return "A DRAW. BOTH CHAIRS NEED A NEW WHEEL."
	var st: Dictionary = STYLES.get(opponent(), {})
	return str(st.get("lose" if winner == 0 else "win", ""))
