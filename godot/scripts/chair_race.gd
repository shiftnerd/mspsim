extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# CHAIR RACE (roadmap R12 part b, rebuilt side-on in R18 phase 2): the rules and the course of the office chair race in the
# warehouse. A RefCounted with no autoload references so tests can run it headless (the Difficulty numbers come in as
# `params`, see Outings._chair_setup); the drawing is done by chair_track.gd, in the room.
# The course is one way: a position along the floor (`pos`, 0 = the grid just behind the START line, LEN = the FINISH line)
# and one of three lanes (the depth of the floor band). You change lane with UP / DOWN and push off by ALTERNATING Z and X:
#   a steady rhythm (about 0.28 to 0.55 s between pushes) is full power; mashing, or the same key twice, is weak
#   and tires you out; a tired chair (stamina low) gets a weak push, rest while you coast and it comes back.
#   Props cost seconds (and speed) when you hit them. The finish time is the clock plus the penalties.
# Rivals (Alan, Garrison, Dan, Maya, John) roll down their own lane with a seeded skill and a personality; they dodge the
# props (or crash into them on purpose, if that is who they are) and never block you.

# ---- the course -----------------------------------------------------------------------------------
const LANES := 3
const LANE_Y := [112.0, 119.0, 126.0]  # set-pixel y of the three lanes (the floor band is 110 to 127)
const ORIGIN_X := 186.0  # set-pixel x of pos 0: a chair on the grid, its knees just behind the START line (x 198..204)
const LEN := 912.0  # pos of the FINISH line (set x 1098; the checkered line is x 1096..1107)
const CHECK_FRAC := [0.25, 0.5, 0.75]
const CHECK_NAMES := ["THE RACKS", "THE PARTS CAGE", "THE BENCH"]
const ZONES := 11  # obstacle zones: every zone has at least one lane with nothing in it
const ZONE_FIRST := 110.0
const ZONE_GAP := 75.0
# prop kinds: width in px (the real sprite), a crash (false: a cone, which tips over; a puddle, which is slick)
const PROPS := {
	"cone": {"w": 14.0, "crash": false},
	"wet": {"w": 16.0, "crash": true},
	"puddle": {"w": 34.0, "crash": false},
	"can": {"w": 18.0, "crash": true},
	"box": {"w": 26.0, "crash": true},
	"pallet": {"w": 32.0, "crash": true},
}
const SOFT_POOL := ["cone", "puddle", "cone"]
const MID_POOL := ["cone", "puddle", "wet", "can", "puddle"]
const HARD_POOL := ["wet", "can", "box", "pallet", "cone", "puddle", "box"]
const HIT_LANE := 0.62  # a prop and a chair touch when their lanes are closer than this
const REACH := 6.0  # px of the chair's nose that count as touching a prop's edge
const REF_SPEED := 47.0  # px/s a clean, well-paced run averages (the rivals are scaled from it)
const COUNT := 3.0  # seconds of countdown
const LIMIT := 80.0  # race seconds before the chair is called a DNF
const FALSE_START := 0.8  # seconds added for pushing before GO
# pushing: ideal gap between two pushes, full power inside [GAP_LO, GAP_HI]
const IMPULSE := 23.0  # px/s per push at full power
const GAP_LO := 0.28
const GAP_HI := 0.55
const MASH_GAP := 0.16
const STAM_COST := 4.4
const STAM_MASH := 11.0
const STAM_SAME := 7.5
const STAM_REGEN := 11.0  # per second when you have not pushed for a moment
const STAM_STEADY := 4.0  # per second while you keep pushing
const DRAG := 0.55
const LANE_RATE := 5.0  # lanes per second (a lane change takes 0.2 s)
const SLICK_LANE := 0.3  # x the lane rate in a puddle
const SLICK_DIP := 0.18  # share of the speed a puddle takes (x chair.slick)
# PAR (Difficulty "chair.par" scales both): total seconds for 3 and 2 stars
const PAR3 := 22.0
const PAR2 := 31.0
# the five who race, with a personality (skill 0..1 is rolled around `skill` by the seed and the tier)
const RACERS := {
	"Alan":
	{
		"skill": 0.46,
		"color": Color("4a78d0"),
		"style": "careful",
		"win": "ALAN WINS. SAFETY FIRST, SPEED SECOND, TROPHY THIRD.",
		"lose": "ALAN: NOT AT MY DESK. THE RACE, I MEAN. YOU WON.",
		"start": "ALAN CHECKS HIS CHAIR FOR RECALLS.",
	},
	"Garrison":
	{
		"skill": 0.56,
		"color": Color("d0883a"),
		"style": "reckless",
		"win": "GARRISON WINS AND WILL NOT STOP TALKING ABOUT IT.",
		"lose": "GARRISON: BEST OF THREE! FINE, BEST OF FIVE!",
		"start": "GARRISON REVS AN IMAGINARY ENGINE.",
	},
	"Dan":
	{
		"skill": 0.5,
		"color": Color("4aa86a"),
		"style": "steady",
		"win": "DAN WINS. HE SAYS HE WAS JUST WARMING UP.",
		"lose": "DAN: GOOD ROLL. I WAS THINKING ABOUT TICKETS.",
		"start": "DAN IS RACING WITH ONE HAND ON HIS COFFEE.",
	},
	"Maya":
	{
		"skill": 0.5,
		"color": Color("c860a8"),
		"style": "sprinter",
		"win": "MAYA WINS. SHE BOLTED OUT OF THE GATE AND NEVER LOOKED BACK.",
		"lose": "MAYA: I WAS AHEAD FOR A WHOLE HALLWAY!",
		"start": "MAYA STRETCHES HER CALVES.",
	},
	"John":
	{
		"skill": 0.52,
		"color": Color("d8c040"),
		"style": "showboat",
		"win": "JOHN WINS AND SPINS TWICE FOR THE CROWD.",
		"lose": "JOHN: I LET YOU WIN. IT IS GOOD FOR RELATIONSHIPS.",
		"start": "JOHN SPINS ONCE FOR THE CROWD.",
	},
}
const ORDER := ["Alan", "Garrison", "Dan", "Maya", "John"]
# the grid: [lane, rows behind the front row] for the five rivals (you start in the middle lane of the front row)
const GRID := [[0, 0], [2, 0], [1, 1], [0, 1], [2, 1]]
const ROW_GAP := 26.0

# ---- the race state ----------------------------------------------------------------------------
var phase := "count"  # count, go, done
var clock := -COUNT  # race seconds; negative during the countdown
var pos := 0.0
var speed := 0.0
var lane := 1.0  # where the chair is across the floor band (0 = far wall, 2 = near)
var lane_to := 1  # the lane you are heading for
var stam := 100.0
var penalty := 0.0
var crashes := 0
var cones := 0
var false_started := false
var cp_next := 0  # checkpoints passed
var finish_t := -1.0  # the clock when you crossed the line (without penalties)
var end_t := 0.0  # seconds since you finished
var dnf := false
var msg := ""
var msg_t := 0.0
var feel := ""
var feel_t := 0.0
var wobble := 0.0  # seconds the chair shakes after a crash
var slick := false  # in a puddle right now
var oil_seen := false
var obstacles: Array = []  # {x, lane, kind, down, hit}
var rivals: Array = []  # {n, s, v, cur, fade, stalls, stall_t, hold, lane, pref, done, color, style, skill, flag}
var events: Array = []  # what just happened, for sounds (go, crash, cone, oil, check, finish, false); the owner clears it
var params := {"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0}
var pushes := 0
var good_pushes := 0

var _last_key := -1
var _last_push := -10.0
var _hit_cd := 0.0
var _flash := {0: 0.0, 1: 0.0}
var _cp_pos: Array = []


# ---- the course (helpers) -----------------------------------------------------------------------
# the set-pixel x of a position along the course
static func world_x(p: float) -> float:
	return ORIGIN_X + p


# the set-pixel y of a lane (a fractional lane between two)
static func lane_y(l: float) -> float:
	var c := clampf(l, 0.0, float(LANES - 1))
	var i := mini(int(c), LANES - 2)
	return lerpf(float(LANE_Y[i]), float(LANE_Y[i + 1]), c - float(i))


# the pos of checkpoint i
static func check_pos(i: int) -> float:
	return LEN * float(CHECK_FRAC[i])


static func prop_width(kind: String) -> float:
	return float(PROPS[kind].w)


# how far before a prop's middle the nose of a chair touches it
static func prop_ahead(kind: String) -> float:
	return prop_width(kind) * 0.5 + REACH


# ---- setup ---------------------------------------------------------------------------------------
# params: crash (seconds a crash costs), stamina (x cost), slick (x puddle), par (x star times), skill (added to the rivals).
# racers: the names that race (any of ORDER). rng: a seeded generator (the props, rival skill and mistakes).
func setup(p: Dictionary, racers: Array, rng: RandomNumberGenerator) -> void:
	for k in p:
		params[k] = p[k]
	_cp_pos = []
	for i in CHECK_FRAC.size():
		_cp_pos.append(check_pos(i))
	_lay_course(rng)
	pos = 0.0
	speed = 0.0
	lane = 1.0
	lane_to = 1
	rivals = []
	var n := 0
	for who in racers:
		if not RACERS.has(who):
			continue
		var row: Dictionary = RACERS[who]
		var skill := clampf(float(row.skill) + float(p.get("skill", 0.0)) + (rng.randf() - 0.5) * 0.08, 0.1, 0.9)
		var slot: Array = GRID[n % GRID.size()]
		var r := {
			"n": who,
			"s": -ROW_GAP * float(slot[1]),
			"v": REF_SPEED * (0.62 + 0.62 * skill),
			"cur": 0.0,
			"fade": 0.0,
			"stalls": [],
			"stall_t": 0.0,
			"hold": -1,
			"lane": float(slot[0]),
			"pref": int(slot[0]),
			"done": -1.0,
			"color": row.color,
			"style": row.style,
			"skill": skill,
			"flag": "",
		}
		var hazards := []
		for i in obstacles.size():
			if bool(PROPS[obstacles[i].kind].crash) or obstacles[i].kind == "cone":
				hazards.append(i)
		match str(row.style):
			"reckless":
				for k in 2:
					if hazards.is_empty():
						break
					var at_i := rng.randi() % hazards.size()
					if rng.randf() < 0.6:
						r.stalls.append(_stall_at(int(hazards[at_i]), 1.1 + rng.randf() * 0.6))
					hazards.remove_at(at_i)
			"steady":
				if rng.randf() < 0.25 and not hazards.is_empty():
					r.stalls.append(_stall_at(int(hazards[rng.randi() % hazards.size()]), 0.8))
			"sprinter":
				r.fade = 0.3
			"showboat":
				r.stalls.append({"s": float(_cp_pos[rng.randi() % _cp_pos.size()]), "t": 1.3, "o": -1})
		r.stalls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))
		rivals.append(r)
		n += 1
	phase = "count"
	clock = -COUNT
	msg = ""
	msg_t = 0.0
	events = []


func _stall_at(index: int, secs: float) -> Dictionary:
	return {"s": float(obstacles[index].x) - prop_ahead(str(obstacles[index].kind)), "t": secs, "o": index}


# ZONES zones, 75 px apart: one or two props each, never three lanes at once, so there is always an empty lane
# (the early zones are cones and puddles, later ones add the signs, cans, boxes and pallets)
func _lay_course(rng: RandomNumberGenerator) -> void:
	obstacles = []
	for z in ZONES:
		var lanes := [0, 1, 2]
		for i: int in [2, 1]:  # shuffle
			var j: int = rng.randi() % (i + 1)
			var t: int = lanes[i]
			lanes[i] = lanes[j]
			lanes[j] = t
		var count := 2 if rng.randf() < (0.35 if z < 3 else 0.75) else 1
		var pool: Array = SOFT_POOL if z < 2 else (MID_POOL if z < 5 else HARD_POOL)
		for k in count:
			obstacles.append(
				{
					"x": ZONE_FIRST + ZONE_GAP * float(z) + rng.randf_range(-7.0, 7.0),
					"lane": int(lanes[k]),
					"kind": str(pool[rng.randi() % pool.size()]),
					"down": false,
					"hit": false,
				}
			)


# ---- the clock ------------------------------------------------------------------------------------
func step(dt: float) -> void:
	if phase == "done":
		end_t += dt
		clock += dt
		speed *= exp(-1.6 * dt)  # coast over the line
		pos = minf(pos + speed * dt, LEN + 70.0)
		wobble = maxf(0.0, wobble - dt)
		_lane_move(dt)
		_advance(rivals, dt, clock)
		return
	msg_t = maxf(0.0, msg_t - dt)
	feel_t = maxf(0.0, feel_t - dt)
	wobble = maxf(0.0, wobble - dt)
	_hit_cd = maxf(0.0, _hit_cd - dt)
	for k in _flash:
		_flash[k] = maxf(0.0, float(_flash[k]) - dt)
	_lane_move(dt)
	clock += dt
	if clock < 0.0:
		return
	if phase == "count":
		phase = "go"
		_say("GO!", 0.9)
		events.append("go")
	_advance(rivals, dt, clock)
	_drive(dt)
	if clock >= LIMIT and phase == "go":
		dnf = true
		_finish()


func _say(text: String, secs := 1.2) -> void:
	msg = text
	msg_t = secs


func total() -> float:
	if finish_t >= 0.0:
		return finish_t + penalty
	return maxf(0.0, clock) + penalty


func countdown_text() -> String:
	if clock >= 0.0:
		return ""
	return str(int(ceilf(-clock)))


func _finish() -> void:
	phase = "done"
	finish_t = clampf(clock, 0.0, LIMIT)
	end_t = 0.0


# ---- the player ----------------------------------------------------------------------------------
# UP / DOWN: one lane over (dir -1 = towards the far wall, +1 = towards you)
func change_lane(dir: int) -> void:
	if phase == "done":
		return
	lane_to = clampi(lane_to + dir, 0, LANES - 1)


# head for lane i (the test override)
func go_lane(i: int) -> void:
	lane_to = clampi(i, 0, LANES - 1)


func _lane_move(dt: float) -> void:
	var rate := LANE_RATE * (SLICK_LANE / float(params.slick) if slick else 1.0)
	lane = move_toward(lane, float(lane_to), rate * dt)


func push(key: int) -> void:
	if phase == "done":
		return
	if clock < 0.0:  # a false start
		if not false_started:
			false_started = true
			penalty += FALSE_START
			_say("FALSE START +%.1fS" % FALSE_START, 1.4)
			events.append("false")
		return
	var gap := clock - _last_push
	var same := key == _last_key
	var q := 1.0
	var cost := STAM_COST
	if _last_key < 0:
		gap = (GAP_LO + GAP_HI) * 0.5
		same = false
	if same:
		q = 0.25
		cost = STAM_SAME
		_feel("SAME LEG")
	elif gap < MASH_GAP:
		q = 0.15
		cost = STAM_MASH
		_feel("TOO FAST")
	elif gap < GAP_LO:
		q = lerpf(0.3, 1.0, (gap - MASH_GAP) / (GAP_LO - MASH_GAP))
		cost = lerpf(STAM_MASH, STAM_COST, (gap - MASH_GAP) / (GAP_LO - MASH_GAP))
		_feel("RUSHED")
	elif gap > GAP_HI:
		q = maxf(0.6, 1.0 - (gap - GAP_HI) * 0.5)
		_feel("SLOW")
	else:
		good_pushes += 1
		_feel("GOOD")
	var f := 0.3 + 0.7 * clampf(stam / 100.0, 0.0, 1.0)
	if stam < 15.0:
		_feel("TIRED")
	speed += IMPULSE * q * f
	stam = maxf(0.0, stam - cost * float(params.stamina))
	pushes += 1
	_last_key = key
	_last_push = clock
	_flash[key] = 0.25


func lit(key: int) -> bool:
	return float(_flash[key]) > 0.0


func _feel(text: String) -> void:
	feel = text
	feel_t = 0.8


func _drive(dt: float) -> void:
	slick = false
	for o in obstacles:
		if o.kind == "puddle" and absf(pos - float(o.x)) < prop_width("puddle") * 0.5 * float(params.slick) and absf(lane - float(o.lane)) < HIT_LANE + 0.1:
			slick = true
			if not o.hit:
				o.hit = true
				speed *= 1.0 - SLICK_DIP * float(params.slick)
				events.append("oil")
				if not oil_seen:
					oil_seen = true
					_say("OIL! NO GRIP", 1.4)
	speed *= exp(-DRAG * dt)
	speed = maxf(0.0, speed - 1.5 * dt)
	pos += speed * dt
	stam = minf(100.0, stam + (STAM_REGEN if clock - _last_push > 0.45 else STAM_STEADY) * dt)
	for o in obstacles:
		if o.hit or o.kind == "puddle" or absf(lane - float(o.lane)) >= HIT_LANE:
			continue
		var d: float = pos - float(o.x)
		if d < -prop_ahead(str(o.kind)) or d > 8.0:
			continue
		if o.kind == "cone":
			o.hit = true
			o.down = true
			cones += 1
			penalty += 0.5 * float(params.crash)
			speed *= 0.6
			_say("CONE! +%.1fS" % (0.5 * float(params.crash)), 1.0)
			events.append("cone")
		elif _hit_cd <= 0.0:
			o.hit = true
			_crash(1.0, _crash_text(str(o.kind)))
	while cp_next < _cp_pos.size() and pos >= float(_cp_pos[cp_next]):
		cp_next += 1
		_say("CHECKPOINT %d OF %d" % [cp_next, _cp_pos.size()], 1.2)
		events.append("check")
	if pos >= LEN:
		_say("FINISH!", 2.0)
		events.append("finish")
		_finish()


static func _crash_text(kind: String) -> String:
	match kind:
		"wet":
			return "WET FLOOR SIGN!"
		"can":
			return "BONK! A TRASH CAN"
		"box":
			return "BONK! THE BOXES"
		_:
			return "BONK! THE PALLET"


func _crash(secs: float, text: String) -> void:
	var pen := secs * float(params.crash)
	penalty += pen
	crashes += 1
	_hit_cd = 0.7
	wobble = 0.9
	speed *= 0.3
	_say("%s +%.1fS" % [text, pen], 1.4)
	events.append("crash")


# ---- the rivals -----------------------------------------------------------------------------------
# move a list of rivals on by dt (the real ones, or a copy that is run to the line for the standings)
func _advance(list: Array, dt: float, at: float) -> void:
	for r in list:
		_rival_lane(r, dt)
		if float(r.done) >= 0.0:
			continue
		if float(r.stall_t) > 0.0:
			r.stall_t = float(r.stall_t) - dt
			r.cur = 0.0
			if r.flag != "spin":
				r.flag = "!"
			if float(r.stall_t) <= 0.0:
				r.hold = -1
			continue
		r.flag = ""
		var frac := float(r.s) / LEN
		var target := float(r.v) * (1.0 + float(r.fade) * (0.5 - frac))
		r.cur = move_toward(float(r.cur), target, 34.0 * dt)
		r.s = float(r.s) + float(r.cur) * dt
		if not r.stalls.is_empty() and float(r.s) >= float(r.stalls[0].s):
			var st: Dictionary = r.stalls[0]
			r.stall_t = float(st.t)
			r.hold = int(obstacles[int(st.o)].lane) if int(st.o) >= 0 else -1
			r.flag = "spin" if int(st.o) < 0 else "!"
			r.stalls.remove_at(0)
		if float(r.s) >= LEN:
			r.done = maxf(0.0, at)


# a rival dodges the prop in the way (nearest free lane), or heads straight for the one it means to crash into
func _rival_lane(r: Dictionary, dt: float) -> void:
	var want := int(r.pref)
	if int(r.hold) >= 0:
		want = int(r.hold)
	elif not r.stalls.is_empty() and int(r.stalls[0].o) >= 0 and float(r.stalls[0].s) - float(r.s) < 42.0:
		want = int(obstacles[int(r.stalls[0].o)].lane)
	elif _blocked(want, float(r.s)):
		var best := want
		var best_d := 99
		for l in LANES:
			if not _blocked(l, float(r.s)) and absi(l - want) < best_d:
				best = l
				best_d = absi(l - want)
		want = best
	r.lane = move_toward(float(r.lane), float(want), 3.0 * dt)


func _blocked(l: int, at: float) -> bool:
	for o in obstacles:
		if int(o.lane) == l and float(o.x) - at > -prop_width(str(o.kind)) * 0.5 and float(o.x) - at < 46.0:
			return true
	return false


# when each rival reaches the line, with the race run on (a copy: the rivals you see stay where they are)
func projected() -> Array:
	var copy: Array = rivals.duplicate(true)
	var at := maxf(clock, 0.0)
	var guard := 0
	while guard < 4000 and copy.any(func(r: Dictionary) -> bool: return float(r.done) < 0.0):
		guard += 1
		at += 0.05
		_advance(copy, 0.05, at)
	return copy


# [{n, t}] best first; the player is "You"
func standings() -> Array:
	var out := [{"n": "You", "t": total() if not dnf else 999.0}]
	for r in projected():
		out.append({"n": r.n, "t": float(r.done)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	return out


func place() -> int:
	var list := standings()
	for i in list.size():
		if list[i].n == "You":
			return i + 1
	return list.size()


func place_now() -> int:
	var ahead := 0
	for r in rivals:
		if float(r.s) > pos or float(r.done) >= 0.0:
			ahead += 1
	return ahead + 1


func stars() -> int:
	if dnf or finish_t < 0.0:
		return 0
	var t := total()
	var par := float(params.par)
	if t <= PAR3 * par:
		return 3
	if t <= PAR2 * par:
		return 2
	return 1


# who gets the line in the result: the winner's boast, or a loser's grumble when you won
func comment() -> String:
	var list := standings()
	var top: Dictionary = list[0]
	if top.n == "You":
		if list.size() > 1 and RACERS.has(list[1].n):
			return str(RACERS[list[1].n].lose)
		return "NOBODY ELSE TURNED UP. YOU WIN BY DEFAULT."
	return str(RACERS[top.n].win) if RACERS.has(top.n) else ""
