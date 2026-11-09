extends RefCounted
# gdlint:disable=max-line-length,class-definitions-order
# PAINTBALL (the western capture the flag outing): the rules of the match. A RefCounted with no autoload references so
# tests can run it headless (the Difficulty numbers come in as `params`, see Outings._paint_params); the drawing is done by
# paintball_track.gd, on the field.
# The field is one street, a position `x` from 0 to LEN. Team 0 (you and two of the crew) defends the left end, team 1 (three
# of the crew) the right. Each end has a flag. Run LEFT / RIGHT, fire a paintball with Z, duck behind a barricade with DOWN.
# A tagged player is down for a few seconds and drops the flag where they fell, then comes back at their own end. Pick up the
# other flag, carry it to your own end to score. First to TARGET captures, or the most when the clock runs out.
# A shot goes the way you face and hits the nearest rival in range, unless that rival is ducking right behind a barricade
# on your side of them. Hit chance falls off with the distance and a runner is harder to hit than a standing one.

const LEN := 640.0
const BASE_X := [34.0, 606.0]  # where team 0 / team 1 start and where their flag stands
const RUN := 40.0  # px/s
const CARRY := 0.85  # x the speed with a flag
const RANGE := 170.0
const FIRE_GAP := 0.7
const RESPAWN := 4.0
const TARGET := 3
const LIMIT := 150.0  # seconds of play
const COUNT := 3.0
const PICK := 7.0  # px to touch a flag
const CAP := 10.0  # px of your own end that count as home
const COVER := 14.0  # a ducking player this close behind a barricade is covered
const BARRICADES := [150.0, 235.0, 320.0, 405.0, 490.0]
const YOU_ACC := 0.8
const AI_ACC := 0.18  # the crew's aim is this much of their skill
const NAMES := ["Alan", "Garrison", "Dan", "Maya", "John"]
const STYLES := {
	"Alan": {"skill": 0.5, "role": "defend", "careful": true, "win": "ALAN: A CLEAN, WELL DOCUMENTED VICTORY.", "lose": "ALAN: NOBODY WILL READ THE POST-MORTEM ON THAT."},
	"Garrison": {"skill": 0.6, "role": "attack", "careful": false, "win": "GARRISON: I TOLD YOU. I TOLD EVERYONE.", "lose": "GARRISON: THAT WAS A WARM-UP ROUND. RIGHT?"},
	"Dan": {"skill": 0.55, "role": "defend", "careful": true, "win": "DAN: WE HAD A PLAN. WE HAD A SPREADSHEET.", "lose": "DAN: THE SPREADSHEET DID NOT ACCOUNT FOR YOU."},
	"Maya": {"skill": 0.6, "role": "attack", "careful": false, "win": "MAYA: EASY. NOW I NEED A GRANOLA BAR.", "lose": "MAYA: I WAS ROBBED. BY PHYSICS."},
	"John": {"skill": 0.5, "role": "defend", "careful": true, "win": "JOHN: WE DID IT. DOES THIS COUNT AS A TEAM BUILDING?", "lose": "JOHN: I REGRET NOTHING. I ALSO HIT NOTHING."},
}

var params := {"skill": 1.0, "acc": 1.0}  # Difficulty scales: skill = rival accuracy and reflexes, acc = your own aim
var rng := RandomNumberGenerator.new()
var units: Array = []  # {name, team, x, vx, face, role, careful, skill, flag, down, duck, cool, react, you, tags, duck_for}
var flags: Array = []  # {team (whose flag), x, carried (unit index or -1), home}
var score := [0, 0]
var clock := 0.0
var count := COUNT
var phase := "count"  # count, play, over
var events: Array = []  # what happened this step, for the drawing: {kind: shot|tag|pick|drop|return|capture, ...}
var barricades: Array = []
var winner := -1  # 0 you, 1 them, 2 draw
var line := ""  # the latest thing worth saying
var line_t := 0.0
var you_tags := 0
var you_caps := 0
var move_dir := 0  # the player's held direction
var ticks := 0
var you_auto := false  # tests and demos: the crew plays your unit too


func setup(p: Dictionary, names: Array, r: RandomNumberGenerator) -> void:
	params = p.duplicate()
	rng = r
	units = []
	flags = []
	score = [0, 0]
	clock = 0.0
	count = COUNT
	phase = "count"
	winner = -1
	you_tags = 0
	you_caps = 0
	events = []
	barricades = []
	for b in BARRICADES:
		barricades.append(float(b) + rng.randf_range(-8.0, 8.0))
	var crew: Array = names.duplicate()
	for n in NAMES:
		if crew.size() >= 5:
			break
		if not crew.has(n):
			crew.append(n)
	_add_unit("YOU", 0, 0, true)
	_add_unit(str(crew[0]), 0, 1, false)
	_add_unit(str(crew[1]), 0, 2, false)
	for k in 3:
		_add_unit(str(crew[2 + k]), 1, k, false)
	for t in 2:
		flags.append({"team": t, "x": float(BASE_X[t]), "carried": -1, "home": true})


func _add_unit(who: String, team: int, slot: int, you: bool) -> void:
	var st: Dictionary = STYLES.get(who, {"skill": 0.5, "role": "defend", "careful": false})
	var role := "defend"  # one defender a side; the other two go for the flag (on your side one is you)
	if slot <= 1:
		role = "attack"
	units.append(
		{
			"name": who,
			"team": team,
			"x": float(BASE_X[team]) + (8.0 * slot) * (1.0 if team == 0 else -1.0),
			"vx": 0.0,
			"face": 1 if team == 0 else -1,
			"role": role,
			"careful": bool(st.get("careful", false)),
			"skill": clampf(float(st.skill) + rng.randf_range(-0.08, 0.08), 0.2, 0.95),
			"flag": false,
			"down": 0.0,
			"duck": false,
			"cool": 0.0,
			"react": 0.0,
			"you": you,
			"tags": 0,
			"duck_for": 0.0,
		}
	)


func say(text: String, secs := 1.6) -> void:
	line = text
	line_t = secs


func other(team: int) -> int:
	return 1 - team


func base_of(team: int) -> float:
	return float(BASE_X[team])


# ---- the player's controls -----------------------------------------------------------------------------
func set_move(dir: int) -> void:
	move_dir = clampi(dir, -1, 1)


func set_duck(on: bool) -> void:
	var u: Dictionary = units[0]
	u.duck = on and float(u.down) <= 0.0


func fire_you() -> bool:
	return phase == "play" and fire(0)


# ---- one step ------------------------------------------------------------------------------------------
func step(dt: float) -> void:
	events = []
	line_t = maxf(0.0, line_t - dt)
	if phase == "over":
		return
	if phase == "count":
		count -= dt
		if count <= 0.0:
			phase = "play"
			say("GO!", 1.0)
		return
	clock += dt
	ticks += 1
	var order := range(units.size())
	if ticks % 2 == 1:
		order.reverse()  # neither side always acts first
	for i in order:
		_tick_unit(i, dt)
	for i in order:
		_flags_for(i)
	if score[0] >= TARGET or score[1] >= TARGET or clock >= LIMIT:
		_end()


func _tick_unit(i: int, dt: float) -> void:
	var u: Dictionary = units[i]
	u.cool = maxf(0.0, float(u.cool) - dt)
	if float(u.down) > 0.0:
		u.down = float(u.down) - dt
		u.vx = 0.0
		u.duck = false
		if float(u.down) <= 0.0:
			u.down = 0.0
			u.x = base_of(int(u.team)) + 6.0 * float(1 - 2 * int(u.team)) * float(i % 3)
			u.face = 1 if int(u.team) == 0 else -1
		return
	if bool(u.you) and not you_auto:
		u.vx = 0.0 if bool(u.duck) else float(move_dir) * RUN
		if move_dir != 0:
			u.face = move_dir
	else:
		_ai(i, dt)
	var speed_mul: float = CARRY if bool(u.flag) else 1.0
	u.x = clampf(float(u.x) + float(u.vx) * speed_mul * dt, 8.0, LEN - 8.0)


func _flags_for(i: int) -> void:
	var u: Dictionary = units[i]
	if float(u.down) > 0.0:
		return
	for f in flags:
		if int(f.carried) != -1 or absf(float(f.x) - float(u.x)) > PICK:
			continue
		if int(f.team) != int(u.team):
			f.carried = i
			f.home = false
			u.flag = true
			events.append({"kind": "pick", "unit": i, "flag": int(f.team)})
			say("%s HAS THE FLAG!" % str(u.name), 1.4)
		elif not bool(f.home):
			f.x = base_of(int(f.team))
			f.home = true
			events.append({"kind": "return", "unit": i, "flag": int(f.team)})
			say("%s SENDS THE FLAG HOME." % str(u.name), 1.4)
	if bool(u.flag) and absf(float(u.x) - base_of(int(u.team))) <= CAP:
		var theirs: Dictionary = flags[other(int(u.team))]
		theirs.carried = -1
		theirs.home = true
		theirs.x = base_of(int(theirs.team))
		u.flag = false
		score[int(u.team)] += 1
		if bool(u.you):
			you_caps += 1
		events.append({"kind": "capture", "unit": i, "team": int(u.team)})
		say("%s SCORES! %d TO %d" % [str(u.name), score[0], score[1]], 1.8)


func _end() -> void:
	phase = "over"
	if score[0] > score[1]:
		winner = 0
	elif score[1] > score[0]:
		winner = 1
	else:
		winner = 2


# ---- shooting ------------------------------------------------------------------------------------------
func target_of(i: int) -> int:
	var u: Dictionary = units[i]
	var best := -1
	var best_d := RANGE + 1.0
	for j in units.size():
		var v: Dictionary = units[j]
		if int(v.team) == int(u.team) or float(v.down) > 0.0:
			continue
		var d: float = (float(v.x) - float(u.x)) * float(u.face)
		if d > 0.0 and d <= RANGE and d < best_d:
			best_d = d
			best = j
	return best


# is unit `j` ducking right behind a barricade, as seen from where `from_x` stands?
func covered(j: int, from_x: float) -> bool:
	var v: Dictionary = units[j]
	if not bool(v.duck):
		return false
	var side := signf(from_x - float(v.x))
	for b in barricades:
		var off: float = float(b) - float(v.x)
		if absf(off) <= COVER and signf(off) == side:
			return true
	return false


func near_cover(x: float) -> bool:
	for b in barricades:
		if absf(float(b) - x) <= COVER:
			return true
	return false


func fire(i: int) -> bool:
	var u: Dictionary = units[i]
	if float(u.cool) > 0.0 or float(u.down) > 0.0 or bool(u.duck):
		return false
	u.cool = FIRE_GAP
	var j := target_of(i)
	var hit := -1
	if j >= 0:
		var v: Dictionary = units[j]
		if not covered(j, float(u.x)):
			var d: float = absf(float(v.x) - float(u.x))
			var acc: float = (YOU_ACC * float(params.acc)) if (bool(u.you) and not you_auto) else (float(u.skill) * AI_ACC * float(params.skill))
			var chance := clampf(acc * (1.0 - 0.5 * d / RANGE) * (0.8 if absf(float(v.vx)) > 0.0 else 1.0), 0.05, 0.95)
			if rng.randf() < chance:
				hit = j
	events.append({"kind": "shot", "unit": i, "from": float(u.x), "face": int(u.face), "hit": hit, "target": j})
	if hit >= 0:
		_tag(hit, i)
	return true


func _tag(j: int, by: int) -> void:
	var v: Dictionary = units[j]
	v.down = RESPAWN
	v.duck = false
	v.vx = 0.0
	units[by].tags = int(units[by].tags) + 1
	if bool(units[by].you):
		you_tags += 1
	events.append({"kind": "tag", "unit": j, "by": by, "x": float(v.x)})
	if bool(v.flag):
		var f: Dictionary = flags[other(int(v.team))]
		f.carried = -1
		f.x = float(v.x)
		v.flag = false
		events.append({"kind": "drop", "unit": j, "flag": int(f.team)})
		say("%s DROPPED THE FLAG!" % str(v.name), 1.4)
	elif bool(units[by].you):
		say("TAGGED %s!" % str(v.name).to_upper(), 1.0)


# ---- the crew ------------------------------------------------------------------------------------------
func _goal(i: int) -> float:
	var u: Dictionary = units[i]
	var team := int(u.team)
	var mine: Dictionary = flags[team]
	var theirs: Dictionary = flags[other(team)]
	if bool(u.flag):
		return base_of(team)
	if int(mine.carried) >= 0:  # my flag is being run off: go after the carrier
		return float(units[int(mine.carried)].x)
	if not bool(mine.home):  # my flag lies in the street: take it back
		return float(mine.x)
	if str(u.role) == "attack":
		return float(theirs.x)
	return base_of(team) + (70.0 + float(i % 2) * 20.0) * (1.0 if team == 0 else -1.0)


func _ai(i: int, dt: float) -> void:
	var u: Dictionary = units[i]
	var j := target_of(i)
	var cov := near_cover(float(u.x))
	if j >= 0:
		u.react = float(u.react) + dt
		var delay := 0.55 - 0.3 * float(u.skill)
		if bool(u.careful) and cov and float(u.cool) > 0.0:
			u.duck = true
			u.duck_for = 0.8
		if float(u.react) >= delay and not bool(u.duck):
			fire(i)
	else:
		u.react = 0.0
	if bool(u.duck):
		u.duck_for = float(u.duck_for) - dt
		if float(u.duck_for) <= 0.0:
			u.duck = false
	if bool(u.duck):
		u.vx = 0.0
		return
	var goal := _goal(i)
	var d := goal - float(u.x)
	if absf(d) < 6.0:
		u.vx = 0.0
	else:
		u.vx = signf(d) * RUN
		u.face = int(signf(d))
	if j >= 0 and not bool(u.flag) and str(u.role) == "defend":
		u.vx *= 0.3  # a defender stands and trades shots


# ---- the result ----------------------------------------------------------------------------------------
func stars() -> int:
	if winner == 0:
		return 3 if score[0] - score[1] >= 2 and you_tags + you_caps >= 3 else 2
	if winner == 2:
		return 1
	return 0


func comment() -> String:
	if winner == 2:
		return "A DRAW. NOBODY WILL LET IT GO."
	var who := ""
	for u in units:
		if int(u.team) == 1:
			who = str(u.name)
			break
	var st: Dictionary = STYLES.get(who, {})
	if winner == 0:
		return str(st.get("lose", "THEY WILL WANT A REMATCH."))  # the rival speaks: they lost
	return str(st.get("win", "THEIR TEAM WINS."))


func carrier_of(team: int) -> int:  # the unit carrying `team`'s flag, or -1
	return int(flags[team].carried)
