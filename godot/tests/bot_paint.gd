extends RefCounted
# gdlint:disable=max-line-length
# A scripted, average paintball player (a library for tests/paintball_tuning.gd and tests/coop_paintball.gd, not a test).
# It plays one piloted unit of paintball_game.gd through the same calls the keys make (set_move_of, set_duck_of, change_lane,
# fire) and has a person's limits: it needs a moment to notice somebody in its lane, it is a little late on the trigger, it
# only sometimes thinks of dodging into another lane or of ducking behind a barricade while it reloads.
#   var bot := BotPaint.new(seed)      one per piloted unit
#   bot.drive(game, 0, dt)             once per step, before game.step(dt)

const NOTICE := 0.32  # seconds before the first shot at somebody who has just come into the lane
const SLOPPY := 0.12  # seconds late on the trigger after the reload
const THINK := 0.5  # seconds between two decisions about lanes and cover

var rng := RandomNumberGenerator.new()
var seen_t := 0.0
var late_t := 0.0
var think_t := 0.0
var duck_t := 0.0
var shots := 0


func _init(seed_n := 1) -> void:
	rng.seed = seed_n


# enemies ahead of unit u (the way it would run to `goal`), nearest first: [{d, lane, j}]
func _ahead(g: RefCounted, i: int, dir: float, reach: float) -> Array:
	var u: Dictionary = g.units[i]
	var out := []
	for j in g.units.size():
		var v: Dictionary = g.units[j]
		if int(v.team) == int(u.team) or float(v.down) > 0.0:
			continue
		var d: float = (float(v.x) - float(u.x)) * dir
		if d > 0.0 and d <= reach:
			out.append({"d": d, "lane": int(v.lane), "j": j})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.d) < float(b.d))
	return out


func _goal(g: RefCounted, i: int) -> float:
	var u: Dictionary = g.units[i]
	var team := int(u.team)
	var mine: Dictionary = g.flags[team]
	var theirs: Dictionary = g.flags[1 - team]
	if bool(u.flag):
		return g.base_of(team)
	if int(mine.carried) >= 0 and absf(float(g.units[int(mine.carried)].x) - float(u.x)) < 200.0:
		return float(g.units[int(mine.carried)].x)  # somebody is running off with our flag, close by
	if not bool(mine.home) and int(mine.carried) < 0 and absf(float(mine.x) - float(u.x)) < 120.0:
		return float(mine.x)  # our flag lies in the street nearby
	if int(theirs.carried) >= 0:
		return g.base_of(team) + 60.0 * (1.0 if team == 0 else -1.0)  # a team mate has theirs: cover the way home
	return float(theirs.x)


func drive(g: RefCounted, i: int, dt: float) -> void:
	var u: Dictionary = g.units[i]
	if g.phase != "play" or float(u.down) > 0.0:
		g.set_move_of(i, 0)
		g.set_duck_of(i, false)
		seen_t = 0.0
		return
	think_t -= dt
	duck_t -= dt
	var goal := _goal(g, i)
	var d := goal - float(u.x)
	var dir := 0 if absf(d) < 4.0 else (1 if d > 0.0 else -1)
	var look := float(dir) if dir != 0 else float(int(u.face))
	var ahead := _ahead(g, i, look, float(g.reach))
	var in_lane := ahead.filter(func(e: Dictionary) -> bool: return int(e.lane) == int(u.lane))
	# cover: now and then, when somebody is shooting down my lane while I reload and a barricade is right here
	if duck_t > 0.0:
		g.set_duck_of(i, true)
		g.set_move_of(i, 0)
		return
	g.set_duck_of(i, false)
	if think_t <= 0.0:
		think_t = THINK
		if not in_lane.is_empty() and float(u.cool) > 0.3 and g.near_cover(float(u.x)) and not bool(u.flag) and rng.randf() < 0.3:
			duck_t = minf(float(u.cool), 0.6)
		elif not in_lane.is_empty() and (float(u.cool) > 0.3 or bool(u.flag)) and rng.randf() < (0.6 if bool(u.flag) else 0.35):
			_sidestep(g, i, ahead)  # dodge out of the line of fire
		elif in_lane.is_empty() and not ahead.is_empty() and not bool(u.flag) and float(ahead[0].d) < 120.0 and rng.randf() < 0.5:
			g.change_lane(i, signi(int(ahead[0].lane) - int(u.lane)))  # go and get them
	g.set_move_of(i, dir)
	# the trigger
	if g.target_of(i) >= 0:
		seen_t += dt
		if float(u.cool) <= 0.0:
			late_t += dt
		if seen_t >= NOTICE and late_t >= SLOPPY and g.fire(i):
			late_t = 0.0
			shots += 1
	else:
		seen_t = 0.0
		late_t = 0.0


# one lane over, to the side with fewer rivals ahead
func _sidestep(g: RefCounted, i: int, ahead: Array) -> void:
	var u: Dictionary = g.units[i]
	var best := 0
	var best_n := 99
	for step: int in [-1, 1]:
		var to := int(u.lane) + step
		if to < 0 or to >= int(g.LANES):
			continue
		var n := ahead.filter(func(e: Dictionary) -> bool: return int(e.lane) == to).size()
		if n < best_n or (n == best_n and rng.randf() < 0.5):
			best_n = n
			best = step
	if best != 0:
		g.change_lane(i, best)
