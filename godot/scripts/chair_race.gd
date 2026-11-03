extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# CHAIR RACE (roadmap R12 part b): the rules, the course and the drawing of the office chair race. A static-free
# RefCounted so tests can run it without the Outings autoload (it has no autoload references: the Difficulty numbers
# come in as `params`, see Outings._chair_setup). Seen from above: a course of corridors through the main floor and the
# cubicle area (desks on both sides are walls), cones, a wet floor sign over a puddle, trash cans, the copier, four
# checkpoints and a finish line. You steer with LEFT / RIGHT and push off by ALTERNATING Z and X:
#   a steady rhythm (about 0.28 to 0.55 s between pushes) is full power; mashing, or the same key twice, is weak
#   and tires you out; a tired chair (stamina low) gets a weak push, rest while you coast and it comes back.
#   Walls and obstacles cost seconds (and speed). The finish time is the clock plus the penalties.
# Rivals (Alan, Garrison, Dan, Maya, Vic) follow the corridor with a seeded skill and a personality; they do not crash
# into you, but their mistakes cost them time too.

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const WORLD := Vector2(830.0, 170.0)
const HALF := 16.0  # half the corridor width
const RADIUS := 3.0  # the chair
const POINTS := [
	Vector2(14, 130),
	Vector2(130, 130),
	Vector2(170, 88),
	Vector2(270, 88),
	Vector2(310, 130),
	Vector2(400, 130),
	Vector2(440, 88),
	Vector2(520, 88),
	Vector2(560, 40),
	Vector2(640, 40),
	Vector2(680, 88),
	Vector2(760, 88),
	Vector2(800, 130),
]
const CHECKS := [3, 5, 9, 11]  # point indexes of the checkpoints
const CHECK_NAMES := ["THE COPIER", "THE CUBICLES", "THE WHITEBOARD", "THE LAST TURN"]
const FINISH_BACK := 5.0  # the finish line is this far before the last point
# [segment, fraction along it, 1 = the side is rolled from the seed / 0 = fixed to the right, offset from the middle, kind]
const OBSTACLES := [
	[0, 0.35, 1, 7.0, "cone"],
	[0, 0.72, 1, 7.0, "cone"],
	[2, 0.2, 0, 0.0, "wet"],
	[2, 0.78, 1, 7.0, "cone"],
	[3, 0.35, 0, 11.0, "copier"],
	[4, 0.45, 1, 7.0, "cone"],
	[4, 0.85, 1, 8.0, "bin"],
	[6, 0.5, 1, 7.0, "cone"],
	[8, 0.5, 1, 7.0, "cone"],
	[10, 0.3, 1, 7.0, "cone"],
	[10, 0.72, 1, 8.0, "bin"],
]
const HIT_R := {"cone": 3.5, "wet": 4.0, "copier": 5.5, "bin": 3.5}
const PUDDLE_R := 13.0
const REF_SPEED := 45.0  # px/s a clean, well-paced run averages (the rivals are scaled from it)
const COUNT := 3.0  # seconds of countdown
const LIMIT := 80.0  # race seconds before the chair is called a DNF
const FALSE_START := 0.8  # seconds added for pushing before GO
# pushing: ideal gap between two pushes, full power inside [GAP_LO, GAP_HI]
const IMPULSE := 22.0  # px/s per push at full power
const GAP_LO := 0.28
const GAP_HI := 0.55
const MASH_GAP := 0.16
const STAM_COST := 5.0
const STAM_MASH := 12.0
const STAM_SAME := 8.0
const STAM_REGEN := 11.0  # per second when you have not pushed for a moment
const STAM_STEADY := 4.0  # per second while you keep pushing
const DRAG := 0.55
const TURN := 3.2
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
	"Vic":
	{
		"skill": 0.52,
		"color": Color("d8c040"),
		"style": "showboat",
		"win": "VIC WINS AND SPINS TWICE FOR THE CROWD.",
		"lose": "VIC: I LET YOU WIN. IT IS GOOD FOR RELATIONSHIPS.",
		"start": "VIC SPINS ONCE FOR THE CROWD.",
	},
}
const ORDER := ["Alan", "Garrison", "Dan", "Maya", "Vic"]
const WALL := Color("2a2d3a")
const FLOOR := Color("b7bcc8")
const FLOOR2 := Color("aab0be")
const EDGE := Color("171a24")
const DESK := Color("7a5a3c")
const DESK_TOP := Color("9a7650")
const SCREEN := Color("4a6a86")

static var _bg: ImageTexture = null
static var _seg_cache: Array = []
static var _len_cache := 0.0

# ---- the race state ----------------------------------------------------------------------------
var phase := "count"  # count, go, done
var clock := -COUNT  # race seconds; negative during the countdown
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var prog := 0.0  # arc length along the corridor
var seg := 0
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
var obstacles: Array = []  # {pos, r, kind, down}
var rivals: Array = []  # {n, s, v, cur, fade, stalls, stall_t, lane, done, color, style}
var wet_seen := false
var params := {"crash": 1.0, "stamina": 1.0, "slick": 1.0, "par": 1.0}
var pushes := 0
var good_pushes := 0

var _last_key := -1
var _last_push := -10.0
var _hit_cd := 0.0
var _flash := {0: 0.0, 1: 0.0}
var _cp_s: Array = []
var _fin_s := 0.0


# ---- the course (shared by every race) -----------------------------------------------------------
static func _segments() -> Array:
	if _seg_cache.is_empty():
		var s := 0.0
		for i in POINTS.size() - 1:
			var a: Vector2 = POINTS[i]
			var b: Vector2 = POINTS[i + 1]
			var l := a.distance_to(b)
			_seg_cache.append({"a": a, "b": b, "len": l, "s0": s, "dir": (b - a) / l})
			s += l
		_len_cache = s
	return _seg_cache


static func length() -> float:
	_segments()
	return _len_cache


# the point `s` along the corridor and the direction of travel there
static func at_s(s: float) -> Dictionary:
	var segs := _segments()
	var v := clampf(s, 0.0, _len_cache)
	for e in segs:
		if v <= float(e.s0) + float(e.len) + 0.001:
			var d: Vector2 = e.dir
			return {"p": e.a + d * (v - float(e.s0)), "dir": d, "i": segs.find(e)}
	var last: Dictionary = segs[segs.size() - 1]
	return {"p": last.b, "dir": last.dir, "i": segs.size() - 1}


# nearest point of the corridor's middle line among segments `i - 1 .. i + 1` (so a hairpin cannot snap you to the far leg)
static func locate(p: Vector2, i: int) -> Dictionary:
	var segs := _segments()
	var best := {}
	var best_d := INF
	for k in range(maxi(0, i - 1), mini(segs.size(), i + 2)):
		var e: Dictionary = segs[k]
		var t := clampf((p - e.a).dot(e.dir), 0.0, float(e.len))
		var q: Vector2 = e.a + e.dir * t
		var d := p.distance_to(q)
		if d < best_d:
			best_d = d
			best = {"d": d, "s": float(e.s0) + t, "i": k, "q": q, "dir": e.dir}
	return best


static func point_on(si: int, frac: float, off: float) -> Vector2:
	var e: Dictionary = _segments()[si]
	var mid: Vector2 = e.a + e.dir * (float(e.len) * frac)
	return mid + Vector2(-e.dir.y, e.dir.x) * off  # + off = to the right of the way you go


# ---- setup ---------------------------------------------------------------------------------------
# params: crash (seconds a wall costs), stamina (x cost), slick (x puddle), par (x star times), skill (added to the rivals).
# racers: the names that race (any of ORDER). rng: a seeded generator (cone sides, rival skill and mistakes).
func setup(p: Dictionary, racers: Array, rng: RandomNumberGenerator) -> void:
	for k in p:
		params[k] = p[k]
	_segments()
	_cp_s = []
	for i in CHECKS:
		_cp_s.append(float(_segments()[i - 1].s0) + float(_segments()[i - 1].len))
	_fin_s = _len_cache - FINISH_BACK
	var first: Dictionary = _segments()[0]
	pos = first.a + first.dir * 6.0
	heading = (first.dir as Vector2).angle()
	speed = 0.0
	prog = 6.0
	seg = 0
	obstacles = []
	var cone_arcs := []
	for o in OBSTACLES:
		var side := 1.0
		if int(o[2]) != 0:  # 1 = the side is rolled from the seed, 0 = fixed to the right of the way you go
			side = 1.0 if rng.randf() < 0.5 else -1.0
		var at := point_on(int(o[0]), float(o[1]), side * float(o[3]))
		var kind := str(o[4])
		obstacles.append({"pos": at, "r": float(HIT_R[kind]), "kind": kind, "down": false, "side": side})
		if kind == "cone" or kind == "bin":
			cone_arcs.append(float(_segments()[int(o[0])].s0) + float(_segments()[int(o[0])].len) * float(o[1]))
	rivals = []
	var lanes := [-9.0, -3.0, 3.0, 9.0, 0.0]
	var n := 0
	for who in racers:
		if not RACERS.has(who):
			continue
		var row: Dictionary = RACERS[who]
		var skill := clampf(float(row.skill) + float(p.get("skill", 0.0)) + (rng.randf() - 0.5) * 0.08, 0.1, 0.9)
		var r := {
			"n": who,
			"s": 6.0 + 0.5 * float(n),
			"v": REF_SPEED * (0.62 + 0.62 * skill),
			"cur": 0.0,
			"fade": 0.0,
			"stalls": [],
			"stall_t": 0.0,
			"lane": float(lanes[n % lanes.size()]),
			"done": -1.0,
			"color": row.color,
			"style": row.style,
			"skill": skill,
			"flag": "",
		}
		match str(row.style):
			"reckless":
				var picks := cone_arcs.duplicate()
				for k in 2:
					if picks.is_empty():
						break
					var at_i := rng.randi() % picks.size()
					if rng.randf() < 0.6:
						r.stalls.append({"s": float(picks[at_i]), "t": 1.1 + rng.randf() * 0.6})
					picks.remove_at(at_i)
			"steady":
				if rng.randf() < 0.25 and not cone_arcs.is_empty():
					r.stalls.append({"s": float(cone_arcs[rng.randi() % cone_arcs.size()]), "t": 0.8})
			"sprinter":
				r.fade = 0.3
			"showboat":
				r.stalls.append({"s": float(_cp_s[rng.randi() % _cp_s.size()]), "t": 1.3})
		r.stalls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.s) < float(b.s))
		rivals.append(r)
		n += 1
	phase = "count"
	clock = -COUNT
	msg = ""
	msg_t = 0.0



# ---- the clock ------------------------------------------------------------------------------------
func step(dt: float, steer: float) -> void:
	if phase == "done":
		end_t += dt
		clock += dt
		_rivals(dt)
		return
	msg_t = maxf(0.0, msg_t - dt)
	feel_t = maxf(0.0, feel_t - dt)
	_hit_cd = maxf(0.0, _hit_cd - dt)
	for k in _flash:
		_flash[k] = maxf(0.0, float(_flash[k]) - dt)
	clock += dt
	if clock < 0.0:
		return
	if phase == "count":
		phase = "go"
		_say("GO!", 0.9)
	_rivals(dt)
	_drive(dt, clampf(steer, -1.0, 1.0))
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
func push(key: int) -> void:
	if phase == "done":
		return
	if clock < 0.0:  # a false start
		if not false_started:
			false_started = true
			penalty += FALSE_START
			_say("FALSE START +%.1fS" % FALSE_START, 1.4)
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


func _feel(text: String) -> void:
	feel = text
	feel_t = 0.8


func _drive(dt: float, steer: float) -> void:
	var puddle := false
	for o in obstacles:
		if o.kind == "wet" and pos.distance_to(o.pos) < PUDDLE_R * float(params.slick):
			puddle = true
	if puddle and not wet_seen:
		wet_seen = true
		_say("WET FLOOR! NO GRIP", 1.4)
	var rate := TURN / (1.0 + absf(speed) / 40.0)
	if puddle:
		rate *= 0.3
	heading += steer * rate * dt
	speed *= exp(-DRAG * (0.35 if puddle else 1.0) * dt)
	speed = maxf(0.0, speed - 1.5 * dt)
	pos += Vector2.from_angle(heading) * speed * dt
	stam = minf(100.0, stam + (STAM_REGEN if clock - _last_push > 0.45 else STAM_STEADY) * dt)
	for o in obstacles:
		if o.kind == "wet":
			if pos.distance_to(o.pos + Vector2(8, -6)) < RADIUS + 3.0 and _hit_cd <= 0.0:
				_crash(1.0, "WET FLOOR SIGN!")
			continue
		if o.down:
			continue
		var d: float = pos.distance_to(o.pos)
		if d < RADIUS + float(o.r):
			if o.kind == "cone":
				o.down = true
				cones += 1
				penalty += 0.5 * float(params.crash)
				speed *= 0.6
				_say("CONE! +%.1fS" % (0.5 * float(params.crash)), 1.0)
			else:
				var away: Vector2 = (pos - o.pos).normalized() if d > 0.01 else Vector2.RIGHT
				pos = o.pos + away * (RADIUS + float(o.r) + 0.2)
				if _hit_cd <= 0.0:
					_crash(1.0, "BONK! " + ("THE COPIER" if o.kind == "copier" else "A TRASH CAN"))
	var at := locate(pos, seg)
	seg = int(at.i)
	if float(at.d) > HALF - RADIUS:
		var out: Vector2 = (pos - at.q).normalized() if float(at.d) > 0.01 else Vector2.UP
		pos = (at.q as Vector2) + out * (HALF - RADIUS)
		var into := Vector2.from_angle(heading).dot(out) * speed
		if into > 14.0 and _hit_cd <= 0.0:
			_crash(1.0, "CUBICLE WALL!")
			heading = lerp_angle(heading, (at.dir as Vector2).angle(), 0.7)
		elif into > 0.0:
			speed *= 0.97
	prog = float(at.s)
	while cp_next < CHECKS.size() and prog >= float(_cp_s[cp_next]):
		cp_next += 1
		if cp_next < CHECKS.size():
			_say("CHECKPOINT %d OF %d" % [cp_next, CHECKS.size()], 1.2)
	if prog >= _fin_s:
		_say("FINISH!", 2.0)
		_finish()


func _crash(secs: float, text: String) -> void:
	var pen := secs * float(params.crash)
	penalty += pen
	crashes += 1
	_hit_cd = 0.7
	speed *= 0.3
	_say("%s +%.1fS" % [text, pen], 1.4)


# ---- the rivals -----------------------------------------------------------------------------------
func _rivals(dt: float) -> void:
	for r in rivals:
		if float(r.done) >= 0.0:
			continue
		if float(r.stall_t) > 0.0:
			r.stall_t = float(r.stall_t) - dt
			r.cur = 0.0
			r.flag = "!"
			continue
		r.flag = ""
		var frac := float(r.s) / _len_cache
		var target := float(r.v) * (1.0 + float(r.fade) * (0.5 - frac))
		r.cur = move_toward(float(r.cur), target, 34.0 * dt)
		var before := float(r.s)
		r.s = before + float(r.cur) * dt
		if not r.stalls.is_empty() and float(r.s) >= float(r.stalls[0].s):
			r.stall_t = float(r.stalls[0].t)
			r.stalls.remove_at(0)
		if float(r.s) >= _fin_s:
			r.done = maxf(0.0, clock)


# run the rivals to the line (when you have finished) so the standings are complete
func settle() -> void:
	var saved := clock
	var guard := 0
	while guard < 4000 and rivals.any(func(r: Dictionary) -> bool: return float(r.done) < 0.0):
		guard += 1
		clock += 0.05
		_rivals(0.05)
	clock = saved


# [{n, t}] best first; the player is "You"
func standings() -> Array:
	settle()
	var out := [{"n": "You", "t": total() if not dnf else 999.0}]
	for r in rivals:
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
		if float(r.s) > prog or float(r.done) >= 0.0:
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


# ---- drawing ---------------------------------------------------------------------------------------
# the panel of the race (taller than the other pages on tall screens)
static func panel_rect(size: Vector2) -> Rect2:
	return UiStyle.panel_rect(size, 358.0, clampf(size.y - 20.0, 116.0, 200.0))


static func _background() -> ImageTexture:
	if _bg != null:
		return _bg
	var w := int(WORLD.x)
	var h := int(WORLD.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(WALL)
	# desks: a grid of cubicle desks with a screen, wherever the corridor is not
	for gx in range(0, w, 30):
		for gy in range(0, h, 20):
			for y in range(gy + 4, gy + 14):
				for x in range(gx + 4, gx + 26):
					if x < w and y < h:
						var edge := y == gy + 4 or y == gy + 13 or x == gx + 4 or x == gx + 25
						img.set_pixel(x, y, DESK_TOP if not edge else DESK)
			for y in range(gy + 6, gy + 9):
				for x in range(gx + 11, gx + 19):
					if x < w and y < h:
						img.set_pixel(x, y, SCREEN)
	var segs := _segments()
	# the corridor: a floor with a faint tile pattern, a dark edge line
	for e in segs:
		var lo := Vector2(minf(e.a.x, e.b.x), minf(e.a.y, e.b.y)) - Vector2.ONE * (HALF + 2.0)
		var hi := Vector2(maxf(e.a.x, e.b.x), maxf(e.a.y, e.b.y)) + Vector2.ONE * (HALF + 2.0)
		for y in range(maxi(0, int(lo.y)), mini(h, int(hi.y) + 1)):
			for x in range(maxi(0, int(lo.x)), mini(w, int(hi.x) + 1)):
				var p := Vector2(float(x) + 0.5, float(y) + 0.5)
				var t := clampf((p - e.a).dot(e.dir), 0.0, float(e.len))
				var d := p.distance_to(e.a + e.dir * t)
				if d <= HALF:
					var tile := ((x / 8) + (y / 8)) % 2 == 0
					img.set_pixel(x, y, FLOOR if tile else FLOOR2)
				elif d <= HALF + 1.2 and img.get_pixel(x, y) != FLOOR and img.get_pixel(x, y) != FLOOR2:
					img.set_pixel(x, y, EDGE)
	# round the joints so a corner has no notch
	for i in POINTS.size():
		var c: Vector2 = POINTS[i]
		for y in range(maxi(0, int(c.y - HALF)), mini(h, int(c.y + HALF) + 1)):
			for x in range(maxi(0, int(c.x - HALF)), mini(w, int(c.x + HALF) + 1)):
				if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c) <= HALF:
					var tile := ((x / 8) + (y / 8)) % 2 == 0
					img.set_pixel(x, y, FLOOR if tile else FLOOR2)
	_bg = ImageTexture.create_from_image(img)
	return _bg


func _screen(p: Vector2, r: Rect2, cam: Vector2) -> Vector2:
	return r.position + p - cam


func paint(c: CanvasItem, r: Rect2) -> void:
	var cam := Vector2(
		clampf(pos.x - r.size.x * 0.5 + 24.0, 0.0, maxf(0.0, WORLD.x - r.size.x)),
		clampf(pos.y - r.size.y * 0.5, 0.0, maxf(0.0, WORLD.y - r.size.y))
	)
	c.draw_rect(r, WALL)
	c.draw_texture_rect_region(_background(), r, Rect2(cam, r.size))
	# the finish line and the checkpoints
	_gate(c, r, cam, _fin_s, Color.WHITE, true)
	for i in CHECKS.size():
		_gate(c, r, cam, float(_cp_s[i]), Color("e0a030") if i == cp_next else (Color("2f9e4f") if i < cp_next else Color("5a6070")), false)
	for o in obstacles:
		_obstacle(c, r, cam, o)
	for who in rivals:
		var lane_p: Vector2 = at_s(float(who.s)).p
		var d: Vector2 = at_s(float(who.s)).dir
		var rp := lane_p + Vector2(-d.y, d.x) * float(who.lane)
		_chair(c, r, cam, rp, d.angle(), who.color, str(who.n).substr(0, 1), str(who.flag))
	_chair(c, r, cam, pos, heading, Color.WHITE, "", "", true)
	# the clock and the stamina
	var strip := Rect2(r.position, Vector2(r.size.x, 9.0))
	c.draw_rect(strip, UiStyle.DARK)
	var t := total()
	var line := "%.1fS  CP %d/%d  P%d/%d" % [t, cp_next, CHECKS.size(), place_now(), rivals.size() + 1]
	if clock < 0.0:
		line = "GET READY"
	UiStyle.text(c, line, strip.position.x + 3.0, strip.position.y + 2.0, UiStyle.WHITE)
	var bw := 30.0
	var bx := strip.end.x - bw - 4.0
	c.draw_rect(Rect2(bx - 1.0, strip.position.y + 2.0, bw + 2.0, 5.0), UiStyle.INK)
	var col := UiStyle.GREEN if stam > 40.0 else (UiStyle.GOLD if stam > 15.0 else UiStyle.RED)
	c.draw_rect(Rect2(bx, strip.position.y + 3.0, bw * clampf(stam / 100.0, 0.0, 1.0), 3.0), col)
	if clock < 0.0:
		PixelFont.draw(c, countdown_text(), Vector2(r.get_center().x - 6.0, r.get_center().y - 10.0), Color("ffd24a"), 4)
	elif msg_t > 0.0:
		var mc := UiStyle.RED if msg.contains("+") else UiStyle.GOLD
		var mw := float(PixelFont.width(msg, 1))
		c.draw_rect(Rect2(r.get_center().x - mw * 0.5 - 3.0, r.position.y + 11.0, mw + 6.0, 9.0), UiStyle.DARK)
		UiStyle.center(c, msg, r.get_center().x, r.position.y + 13.0, Color.WHITE if mc == UiStyle.GOLD else Color("ffb0a8"))


func _gate(c: CanvasItem, r: Rect2, cam: Vector2, s: float, color: Color, checker: bool) -> void:
	var at := at_s(s)
	var d: Vector2 = at.dir
	var n := Vector2(-d.y, d.x)
	var a := _screen((at.p as Vector2) - n * HALF, r, cam)
	var b := _screen((at.p as Vector2) + n * HALF, r, cam)
	if not r.grow(-2.0).has_point(a) or not r.grow(-2.0).has_point(b):
		# only draw a gate whose both ends are on the board
		return
	if checker:
		for k in 8:
			var q := a.lerp(b, (float(k) + 0.5) / 8.0)
			for j in 2:
				var cc := Color.WHITE if (k + j) % 2 == 0 else UiStyle.INK
				c.draw_rect(Rect2(q + d * (float(j) * 2.0 - 2.0) - Vector2(1, 1), Vector2(2, 2)), cc)
	else:
		c.draw_line(a, b, color, 1.0)
		c.draw_rect(Rect2(a - Vector2(1, 3), Vector2(2, 4)), color)
		c.draw_rect(Rect2(b - Vector2(1, 3), Vector2(2, 4)), color)


func _obstacle(c: CanvasItem, r: Rect2, cam: Vector2, o: Dictionary) -> void:
	var sp := _screen(o.pos, r, cam)
	var pad := PUDDLE_R * float(params.slick) + 2.0 if o.kind == "wet" else 8.0
	if not r.grow(-pad).has_point(sp):
		return
	match str(o.kind):
		"cone":
			if o.down:
				c.draw_rect(Rect2(sp - Vector2(3, 1), Vector2(6, 2)), Color("e8782a"))
				return
			c.draw_colored_polygon(PackedVector2Array([sp + Vector2(-3, 3), sp + Vector2(3, 3), sp + Vector2(0, -4)]), Color("e8782a"))
			c.draw_rect(Rect2(sp + Vector2(-2, 0), Vector2(4, 1)), Color.WHITE)
		"wet":
			var pr := PUDDLE_R * float(params.slick)
			c.draw_circle(sp, pr, Color(0.35, 0.6, 0.9, 0.35))
			c.draw_circle(sp, pr * 0.6, Color(0.5, 0.75, 1.0, 0.3))
			var sg := sp + Vector2(8, -6)
			c.draw_colored_polygon(PackedVector2Array([sg + Vector2(-4, 4), sg + Vector2(4, 4), sg + Vector2(0, -5)]), Color("f0d020"))
			c.draw_rect(Rect2(sg + Vector2(-1, -1), Vector2(2, 3)), UiStyle.INK)
		"copier":
			c.draw_rect(Rect2(sp - Vector2(7, 5), Vector2(14, 10)), Color("d8dce6"))
			c.draw_rect(Rect2(sp - Vector2(7, 5), Vector2(14, 10)), UiStyle.INK, false)
			c.draw_rect(Rect2(sp - Vector2(5, 3), Vector2(7, 4)), Color("6a8ab0"))
		_:
			c.draw_circle(sp, 3.5, Color("5a6a60"))
			c.draw_circle(sp, 2.0, Color("2e3a34"))


func _chair(c: CanvasItem, r: Rect2, cam: Vector2, p: Vector2, ang: float, color: Color, letter: String, flag: String, me := false) -> void:
	var sp := _screen(p, r, cam)
	if not r.grow(-6.0).has_point(sp):
		return
	c.draw_circle(sp, RADIUS + 1.0, UiStyle.INK)
	c.draw_circle(sp, RADIUS, color)
	var fwd := Vector2.from_angle(ang)
	c.draw_line(sp, sp + fwd * (RADIUS + 3.0), UiStyle.GOLD if me else UiStyle.INK, 1.0)
	if me:
		c.draw_arc(sp, RADIUS + 3.0, 0.0, TAU, 12, UiStyle.GOLD, 1.0)
	if letter != "":
		UiStyle.text(c, letter, sp.x - 1.0, sp.y - 11.0, UiStyle.WHITE)
	if flag != "":
		UiStyle.text(c, flag, sp.x + 4.0, sp.y - 9.0, UiStyle.RED)


# the strip under the board: the two push keys, how the last push felt, and everybody's progress
func paint_strip(c: CanvasItem, s: Rect2) -> void:
	c.draw_rect(s, UiStyle.DARK)
	c.draw_rect(Rect2(s.position, Vector2(s.size.x, 1.0)), UiStyle.HEAD)
	var x := s.position.x + 3.0
	var keys := ["Z", "X"]
	for k in 2:
		var lit := float(_flash[k]) > 0.0
		c.draw_rect(Rect2(x, s.position.y + 2.0, 7.0, 8.0), UiStyle.GOLD if lit else UiStyle.MUTED)
		UiStyle.text(c, keys[k], x + 2.0, s.position.y + 4.0, UiStyle.INK if lit else UiStyle.WHITE)
		x += 9.0
	if feel_t > 0.0:
		var fc := UiStyle.GREEN if feel == "GOOD" else UiStyle.RED
		UiStyle.text(c, feel, x + 2.0, s.position.y + 4.0, Color("9ae6a8") if fc == UiStyle.GREEN else Color("ffb0a8"))
	var bx := s.position.x + 62.0
	var bw := s.end.x - bx - 5.0
	var by := s.position.y + 6.0
	c.draw_rect(Rect2(bx, by, bw, 1.0), UiStyle.SOFT)
	for i in CHECKS.size():
		c.draw_rect(Rect2(bx + bw * float(_cp_s[i]) / _len_cache, by - 2.0, 1.0, 5.0), UiStyle.SOFT)
	c.draw_rect(Rect2(bx + bw, by - 3.0, 2.0, 7.0), UiStyle.WHITE)
	for who in rivals:
		var fx := bx + bw * clampf(float(who.s) / _fin_s, 0.0, 1.0)
		c.draw_rect(Rect2(fx - 1.0, by - 1.0, 3.0, 3.0), who.color)
	var mx := bx + bw * clampf(prog / _fin_s, 0.0, 1.0)
	c.draw_rect(Rect2(mx - 2.0, by - 2.0, 5.0, 5.0), UiStyle.INK)
	c.draw_rect(Rect2(mx - 1.0, by - 1.0, 3.0, 3.0), Color.WHITE)
