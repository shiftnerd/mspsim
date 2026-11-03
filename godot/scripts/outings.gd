extends CanvasLayer
# gdlint:disable=max-line-length
# Team outings: four little mini-games the crew goes out for, if you choose to go.
#   BOWLING (timing: aim, then power), KARAOKE (rhythm: arrow keys), ESCAPE ROOM (a 3-digit code, bulls and cows,
#   teammates give hints), DINNER (conversation: learn what each person likes).
# Tech campaign: on days 5, 10 and 15 Garrison (the culture owner) asks at 16:00 (open tickets wait; you go home after). Owner campaign:
# weeks 4, 9, 14 and 19, and it costs money. Free Play: press O. Results (0-3 stars) change coworker opinions, energy
# (tech) and burnout (owner); skipping invitations costs a little goodwill. Everything is drawn in code.

signal finished(game: String, stars: int)

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const INK := UiStyle.INK
const WHITE := UiStyle.WHITE
const PANEL := UiStyle.PANEL
const BLUE := UiStyle.HEAD
const GREEN := UiStyle.GREEN
const RED := UiStyle.RED
const AMBER := UiStyle.GOLD
const GAMES := {
	"bowling":
	{
		"label": "BOWLING",
		"cost": 120,
		"blurb":
		"FIVE FRAMES AGAINST ALAN, GARRISON AND DAN. PRESS SPACE TO STOP THE AIM, THEN AGAIN TO SET THE POWER.",
		"keys": "SPACE = STOP AIM / POWER  ESC = LEAVE"
	},
	"karaoke":
	{
		"label": "KARAOKE",
		"cost": 180,
		"blurb":
		"HIT THE ARROWS AS THEY REACH THE LINE. NERVOUS? THE ROOM IS RIGHT THERE WITH YOU.",
		"keys": "ARROW KEYS = HIT NOTES  ESC = LEAVE"
	},
	"escape":
	{
		"label": "ESCAPE ROOM",
		"cost": 240,
		"blurb":
		"CRACK THE 3 DIGIT CODE IN TWO MINUTES. BULLS = RIGHT DIGIT, RIGHT PLACE. COWS = RIGHT DIGIT, WRONG PLACE. FRIENDS GIVE HINTS.",
		"keys": "ARROWS  ENTER = TRY  H = HINT  ESC = LEAVE"
	},
	"dinner":
	{
		"label": "DINNER",
		"cost": 300,
		"blurb":
		"FIVE ROUNDS OF TABLE TALK. EVERYONE LOVES SOMETHING AND DREADS SOMETHING. WATCH THEIR FACES AND REMEMBER.",
		"keys": "UP / DOWN  ENTER = TALK  ESC = LEAVE"
	},
}
const DINERS := ["Alan", "Garrison", "Dan"]
const LOVES := {
	"Alan": ["SPORTS", "FOOD"],
	"Garrison": ["MOVIES", "WEEKEND PLANS"],
	"Dan": ["KIDS AND PETS", "FOOD"]
}
const HATES := {"Alan": "WORK DRAMA", "Garrison": "SPORTS", "Dan": "MOVIES"}
const TOPICS := ["WORK DRAMA", "SPORTS", "MOVIES", "FOOD", "KIDS AND PETS", "WEEKEND PLANS"]
const BOWL_SKILL := {"Alan": 0.62, "Garrison": 0.55, "Dan": 0.48}
const SEATS := {"dinner": {"Alan": "Seat1", "Garrison": "Seat3", "Dan": "Seat4", "Vic": "Seat5"}}
const PLAYER_SEAT := "Seat2"
const LANE_NEAR := [152.0, 252.0]
const LANE_FAR := [160.0, 244.0]
const MIC_X := 238.0
const ROOM_INTRO := {
	"bowling":
	"TAKE YOUR TURN ON THE LANE. PRESS E TO STEP UP, E TO STOP THE AIM, E AGAIN FOR POWER. ALAN, GARRISON AND DAN BOWL ON THE NEXT LANE. FIVE FRAMES.",
	"karaoke":
	"YOU ARE ON THE MIC. HIT THE ARROW KEYS AS THE NOTES REACH THE LINE (BOTTOM LEFT) WHILE THE ROOM WATCHES. STRING PERFECT HITS TOGETHER.",
	"escape":
	"THE CODE IS HIDDEN IN THE ROOM. LOOK AT THE CHALKBOARD, THE CLOCK AND THE PAINTING (E), THEN ENTER THE CODE AT THE KEYPAD BY THE VAULT. N ASKS A FRIEND. TWO MINUTES.",
	"dinner":
	"WALK TO THE BOOTH AND SIT NEXT TO ALAN (E). THEN CHOOSE FIVE TOPICS FOR THE TABLE AND WATCH THEIR FACES.",
}
const SONG_LEN := 24
const LANE_KEYS := [KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT]
const LANE_COLORS := [Color("e0463c"), Color("5fd068"), Color("5aa0e8"), Color("f5d442")]
const ESCAPE_TIME := 120.0
const ROOMS := {
	"bowling": "bowling_alley",
	"karaoke": "karaoke_bar",
	"escape": "escape_room",
	"dinner": "restaurant"
}
# where Alan, Garrison, Dan, Vic, Maya and Morgan stand in each room (set-pixel x, World.CAST order: a person who is
# not there leaves their spot empty). The five standing spots are unchanged; the sixth is Morgan's.
const SPOTS := {
	"bowling": [114, 186, 214, 250, 140, 165],
	"karaoke": [236, 262, 282, 130, 160, 100],
	"escape": [118, 175, 205, 305, 325, 62],  # clear of the clue zones (clock 86, painting 149, board 238, keypad 276)
	"dinner": [34, 62, 106, 140, 175, 205],
}
const TECH_DAYS := [5, 10, 15]
const OWNER_WEEKS := [4, 9, 14, 19]

var enabled := false
var use_rooms := false  # go to the real room (title menu turns this on)
var is_open := false
var game := ""
var phase := "intro"  # intro, play, result
var g := {}
var stars := 0
var lines: Array = []  # the result page
var count := 0
var skipped := 0
var best := {}
var known := {}  # dinner: who likes / dreads what, learned over time

var _canvas: Node2D
var _prev_scale := 1.0
var _from_invite := false
var _peek := false  # TAB hides the panel so you can look at the room
var _wait_id := ""  # travelling to the room
var _traveled := false
var _return_scene := ""
var _return_x := -1.0
var _caption := ""
var _caption_t := 0.0
var _marks := {}  # speech bubbles to hide: node -> seconds left
var _offered := false


func _ready() -> void:
	layer = 66
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	Campaign.day_started.connect(func(_d: int) -> void: _offered = false)
	reset()


func reset() -> void:
	count = 0
	skipped = 0
	best = {}
	known = {}
	_offered = false


func to_dict() -> Dictionary:
	return {"count": count, "skipped": skipped, "best": best, "known": known}


func from_dict(data: Dictionary) -> void:
	reset()
	count = int(data.get("count", 0))
	skipped = int(data.get("skipped", 0))
	best = data.get("best", {})
	known = data.get("known", {})


# ---- invitations ------------------------------------------------------------------------------
# a game is open, or we are on the way to its room
func busy() -> bool:
	return is_open or _wait_id != ""


func invite_day() -> bool:
	if not Campaign.active:
		return false
	if Campaign.mode == "owner":
		return OWNER_WEEKS.has(Campaign.day)
	return TECH_DAYS.has(Campaign.day)


# the day waits for the invitation (a trip may have brought you home after five)
func invite_due() -> bool:
	return enabled and not _offered and invite_day() and not Story.overtime and not Game.title_mode


# who is in the building for an outing: the current cast (World.CAST order) minus the person you play as
func roster() -> Array:
	var out := []
	for n in World.CAST:
		if World.chars.has(n) and n != Campaign.player_as:
			out.append(n)
	return out


# the people the games have a personality for (love / dread topics, bowling skill): the trio, minus you
func diners() -> Array:
	var here := roster()
	return DINERS.filter(func(n: String) -> bool: return here.has(n))


func bowlers() -> Array:
	var here := roster()
	return BOWL_SKILL.keys().filter(func(n: String) -> bool: return here.has(n))


func maybe_invite() -> void:
	if not enabled or _offered or is_open or Cards.is_open or Game.title_mode or not invite_day():
		return
	if World.time_scale <= 0.0 or World.clock < 16.0 or Story.overtime:
		return
	_offered = true
	var text := "The crew is heading out after work and I would like you there. Come with us? The open tickets will still be here in the morning."
	if Campaign.mode == "owner":
		text = "The crew has been grinding for weeks. A team night would be noticed. It costs %s depending on the game." % cost_range()
	Cards.ask(
		_host(),
		text,
		[
			{"label": "YES, LET US GO", "id": "yes"},
			{"label": "NOT TONIGHT", "id": "no"},
		],
		func(id: String) -> void: _invite_answer(id)
	)


# the owner pays for the night: "$120 TO $300" (shown on the invitation before the game pick)
func cost_range() -> String:
	var lo := 100000
	var hi := 0
	for id in GAMES:
		lo = mini(lo, int(GAMES[id].cost))
		hi = maxi(hi, int(GAMES[id].cost))
	return "$%d to $%d" % [lo, hi]


# who asks: Garrison (culture owner) in the tech campaign; in the owner campaign the card comes from Alan
func _host() -> String:
	return "Alan (Co-owner)" if Campaign.mode == "owner" else "Garrison (Co-owner)"


func _invite_answer(id: String) -> void:
	if id == "yes":
		pick_game(true)
		return
	skipped += 1
	if Campaign.mode == "owner":
		Owner.burnout = clampf(Owner.burnout + 2.0, 0.0, 100.0)
	else:
		Social.change_all(-1)


func pick_game(from_invite: bool) -> void:
	var options := []
	for id in GAMES:
		var cost := int(GAMES[id].cost)
		var entry := {
			"label":
			"%s%s" % [str(GAMES[id].label), " ($%d)" % cost if Campaign.mode == "owner" else ""],
			"id": id
		}
		if Campaign.mode == "owner" and Owner.cash < cost:
			entry["enabled"] = false
			entry["hint"] = "NEED $%d" % cost
		options.append(entry)
	Cards.ask(
		_host(),
		"Where to? Bowling is easy, karaoke is risky, the escape room needs teamwork and dinner needs good conversation.",
		options,
		func(id: String) -> void: start(id, from_invite)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or is_open or Campaign.active or Game.title_mode or Game.ui_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		Cards.ask(
			"Team outing",
			"Take the team out? (Free Play: nothing is scored.)",
			[
				{"label": "LET US GO", "id": "yes"},
				{"label": "NEVER MIND", "id": "no"},
			],
			func(id: String) -> void: _free_answer(id)
		)


func _free_answer(id: String) -> void:
	if id == "yes":
		pick_game(false)


# ---- running an outing ------------------------------------------------------------------------
func start(id: String, from_invite := false) -> void:
	var here := get_tree().current_scene
	if use_rooms and ROOMS.has(id) and here != null and not Game.title_mode:
		_return_scene = here.scene_file_path.get_file().get_basename()
		var me := here.get_node_or_null("Actors/Player")
		_return_x = me.global_position.x if me != null else -1.0
		_traveled = true
		_wait_id = id
		_from_invite = from_invite
		World.start_outing(str(ROOMS[id]), SPOTS[id], SEATS.get(id, {}))
		Game.go(str(ROOMS[id]), "from_outing")
		return
	_traveled = false
	_open(id, from_invite)


func _open(id: String, from_invite: bool) -> void:
	game = id
	_from_invite = from_invite
	phase = "intro"
	stars = 0
	g = {}
	lines = []
	_prev_scale = World.time_scale if World.time_scale > 0.0 else 1.0
	World.time_scale = 0.0
	is_open = true
	Game.ui_open = true
	_canvas.visible = true
	if Campaign.mode == "owner":
		Owner.cash -= int(GAMES[id].cost)
	_canvas.queue_redraw()


func begin_play() -> void:
	phase = "play"
	match game:
		"bowling":
			_bowl_setup()
		"karaoke":
			_kara_setup()
		"escape":
			_escape_setup()
			if room_mode():
				_escape_room_setup()
		_:
			_dinner_setup()
	if room_mode():
		_room_begin()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_canvas.visible = false
	Game.ui_open = false
	World.time_scale = _prev_scale
	if _from_invite and Campaign.active:
		World.clock = maxf(World.clock, World.DAY_END)
		Shift.skip_stay()
	elif _traveled:
		World.end_outing()
		Game.pending_x = _return_x
		Game.go(_return_scene, "start")
	_traveled = false
	_peek = false
	finished.emit(game, stars)


func _process(delta: float) -> void:
	if _wait_id != "":
		var here := get_tree().current_scene
		if (
			not Game.busy
			and here != null
			and here.scene_file_path.get_file().get_basename() == str(ROOMS[_wait_id])
		):
			var id := _wait_id
			_wait_id = ""
			_open(id, _from_invite)
		return
	if is_open:
		if phase == "play":
			tick(delta)
		_room_process(delta)
		_canvas.queue_redraw()
		return
	maybe_invite()


func tick(dt: float) -> void:
	if phase != "play":
		return
	match game:
		"bowling":
			_bowl_tick(dt)
		"karaoke":
			_kara_tick(dt)
		"escape":
			_escape_tick(dt)
		_:
			_dinner_tick(dt)


func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if room_mode() and phase == "play" and not _room_wants(event.keycode):
		return  # in the room you keep walking around
	press(event.keycode)
	get_viewport().set_input_as_handled()


func press(key: int) -> void:
	if not is_open:
		return
	if key == KEY_TAB and _traveled:
		_peek = not _peek
		_canvas.queue_redraw()
	elif phase == "intro" or phase == "result":
		_press_page(key)
	elif key == KEY_ESCAPE:
		_escape_or_leave()
	elif not (room_mode() and _room_press(key)):
		_press_game(key)


func _press_page(key: int) -> void:
	if phase == "result":
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			close()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		begin_play()
	elif key == KEY_ESCAPE:
		if Campaign.mode == "owner":
			Owner.cash += int(GAMES[game].cost)
		_finish(-1)


func _escape_or_leave() -> void:
	if game == "escape" and g.get("entry", false):
		g.entry = false
		Game.ui_open = false
	else:
		_finish(-1)


func _press_game(key: int) -> void:
	match game:
		"bowling":
			_bowl_press(key)
		"karaoke":
			_kara_press(key)
		"escape":
			_escape_press(key)
		_:
			_dinner_press(key)


# stars: 0-3, or -1 when you left early
func _finish(result: int) -> void:
	stars = result
	phase = "result"
	lines = []
	if result < 0:
		lines.append("YOU LEFT EARLY. NOBODY SAYS ANYTHING. EVERYBODY NOTICES.")
		Social.change_all(-1)
	else:
		count += 1
		best[game] = maxi(int(best.get(game, 0)), result)
		Career.note_outing(
			game,
			result,
			{
				"perfects": int(g.get("perfect", 0)),
				"secs": roundi(Difficulty.f("escape.time") - float(g.get("time", 0.0))),
				"score": int(g.get("score", 0))
			}
		)
		Social.change_all(1 + result)
		if Campaign.active:
			lines.append("EVERYONE ON THE TEAM LIKES YOU %d MORE." % (1 + result))
		else:
			lines.append("A GOOD NIGHT OUT. (FREE PLAY: NOTHING IS SCORED.)")
		if Campaign.mode == "owner":
			var relief := 5.0 + 3.0 * float(result)
			Owner.burnout = clampf(Owner.burnout - relief, 0.0, 100.0)
			Owner.flags["outings"] = int(Owner.flags.get("outings", 0)) + 1
			lines.append("BURNOUT DOWN %d POINTS. THE CREW FEELS SEEN." % int(relief))
			if game == "escape" and result >= 2:
				Owner.speed += 0.02
				lines.append("THEY WORK BETTER TOGETHER NOW: TEAM SPEED UP.")
		elif Campaign.active:
			var gain := 4.0 + 2.0 * float(result)
			Shift.add_energy(gain)
			lines.append("ENERGY +%d. A NIGHT OUT HELPS." % int(gain))
		if result >= 3:
			Campaign.adjust_rep(1)
			if Campaign.active:
				lines.append("WORD GETS AROUND ABOUT THIS ONE: REPUTATION +1.")
	if room_mode():
		_release_player()
		Game.ui_open = true
		_caption_t = 0.0
	_canvas.queue_redraw()


# ---- bowling ------------------------------------------------------------------------------------
func _all_up() -> Array:
	return [true, true, true, true, true, true, true, true, true, true]


func _bowl_totals() -> Dictionary:
	var totals := {"You": 0}
	for who in bowlers():
		totals[who] = 0
	return totals


func _bowl_setup() -> void:
	g = {
		"frame": 1,
		"roll": 1,
		"pins": 10,
		"stage": "aim",
		"marker": 0.0,
		"power": 0.0,
		"dir": 1.0,
		"wait": 0.0,
		"ball": 0.0,
		"msg": "",
		"totals": _bowl_totals(),
		"knocked": 0,
		"up": [_all_up(), _all_up()],
		"fall": {},
		"queue": [],
		"opp": "",
		"opp_t": 0.0,
		"opp_ball": 0.0,
		"opp_off": 0.5,
		"opp_total": 0,
		"opp_knock": 0,
		"opp_phase": 0,
	}
	if room_mode():
		g.stage = "ready"
		caption("YOUR TURN. PRESS E TO STEP UP.", 99.0)


func _bowl_tick(dt: float) -> void:
	for key in g.fall.keys():
		g.fall[key] = float(g.fall[key]) - dt
		if float(g.fall[key]) <= 0.0:
			g.fall.erase(key)
	var stage: String = g.stage
	if stage == "aim" or stage == "power":
		var key := "marker" if stage == "aim" else "power"
		var speed := Difficulty.f("bowl.aim_speed" if stage == "aim" else "bowl.power_speed")
		var v: float = float(g[key]) + float(g.dir) * dt * speed
		if v >= 1.0:
			v = 1.0
			g.dir = -1.0
		elif v <= 0.0:
			v = 0.0
			g.dir = 1.0
		g[key] = v
	elif stage == "roll":
		g.ball = minf(1.0, float(g.ball) + dt * 1.6)
		if float(g.ball) >= 1.0:
			_bowl_resolve()
	elif stage == "pause":
		g.wait = float(g.wait) - dt
		if float(g.wait) <= 0.0:
			_bowl_next()
	elif stage == "others":
		_bowl_others(dt)


func _bowl_press(key: int) -> void:
	if key not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
		return
	if room_mode() and g.stage not in ["ready", "aim", "power"]:
		caption("WAIT. E DOES NOTHING UNTIL IT IS YOUR TURN.", 1.5)
		return
	if g.stage == "ready":
		_place_player(_x0() + float(LANE_NEAR[0]))
		_hold_player("idle")
		g.stage = "aim"
		g.marker = 0.0
		g.dir = 1.0
		caption("PRESS E TO STOP THE AIM (STOP IN THE GREEN).", 99.0)
	elif g.stage == "aim":
		g.stage = "power"
		g.power = 0.0
		g.dir = 1.0
		caption("PRESS E TO STOP THE POWER (STOP IN THE GREEN).", 99.0)
	elif g.stage == "power":
		g.stage = "roll"
		g.ball = 0.0
		caption("WAIT. THE BALL IS ROLLING.", 3.0)
		var p := _actor("Player")
		if p != null:
			p.start_emote("reach", 0.8)


func bowl_strength() -> float:
	var accuracy := 1.0 - absf(float(g.marker) - 0.5) * 2.0
	var quality := clampf(1.0 - absf(float(g.power) - 0.85) / 0.85, 0.0, 1.0)
	var noise := Difficulty.rng("bowl").randf_range(-0.08, 0.08)
	return clampf(accuracy * 0.6 + quality * 0.4 + noise, 0.0, 1.0)


func _bowl_resolve() -> void:
	var strength := bowl_strength()
	var left := int(g.pins)
	var knocked := (
		left
		if strength > 0.92
		else clampi(roundi(float(left) * minf(1.0, strength * 1.15)), 0, left)
	)
	g.knocked = knocked
	g.pins = left - knocked
	g.totals["You"] = int(g.totals["You"]) + knocked
	Career.note_bowl(knocked, int(g.roll))
	if knocked == 10 and int(g.roll) == 1:
		g.totals["You"] = int(g.totals["You"]) + 3
		g.msg = "STRIKE!"
	elif int(g.pins) == 0:
		g.msg = "SPARE!"
	elif knocked == 0:
		g.msg = "GUTTER BALL..."
	else:
		g.msg = "%d PINS" % knocked
	g.stage = "pause"
	g.wait = 1.4 if room_mode() else 1.1
	if room_mode():
		_pins_fall(0, knocked)
		_bubble(_actor("Player"), "!" if knocked >= 8 else ("?" if knocked == 0 else "dots"), 1.2)
		for who in diners():
			if knocked >= 10:
				_bubble(_actor(who), "heart", 1.2)


func _bowl_roll_opp(who: String) -> Dictionary:
	var skill := float(BOWL_SKILL[who]) + Difficulty.f("bowl.opp_skill")
	var r := Difficulty.rng("bowl")
	var first := clampi(roundi(10.0 * (skill + r.randf_range(-0.28, 0.28))), 0, 10)
	var total := first
	var knock := first
	if first == 10:
		total += 3
	else:
		var second := clampi(
			roundi(float(10 - first) * (skill + r.randf_range(-0.28, 0.28))), 0, 10 - first
		)
		total += second
		knock += second
	return {"total": total, "knock": knock}


func _bowl_next() -> void:
	var frame_over: bool = int(g.roll) == 2 or int(g.pins) == 0
	if not frame_over:
		g.roll = 2
		g.stage = "aim"
		g.marker = 0.0
		g.dir = 1.0
		if room_mode():
			caption("SECOND ROLL. PRESS E TO STOP THE AIM.", 99.0)
		return
	if room_mode():
		g.queue = bowlers()
		g.opp = ""
		g.stage = "others"
		caption("WAIT. THE CREW BOWLS NEXT.", 2.0)
		return
	for who in bowlers():
		g.totals[who] = int(g.totals[who]) + int(_bowl_roll_opp(who).total)
	_bowl_advance()


func _bowl_advance() -> void:
	if int(g.frame) >= 5:
		_bowl_end()
		return
	g.frame = int(g.frame) + 1
	g.roll = 1
	g.pins = 10
	g.stage = "ready" if room_mode() else "aim"
	g.marker = 0.0
	g.dir = 1.0
	g.msg = ""
	g.up = [_all_up(), _all_up()]
	if room_mode():
		caption("FRAME %d. YOUR TURN: PRESS E TO STEP UP." % int(g.frame), 99.0)


# the crew takes its turn on the next lane, one at a time
func _bowl_others(dt: float) -> void:
	g.opp_t = float(g.opp_t) + dt
	if str(g.opp) == "":
		if g.queue.is_empty():
			_bowl_advance()
			return
		g.opp = str(g.queue.pop_front())
		var res := _bowl_roll_opp(str(g.opp))
		g.opp_total = int(res.total)
		g.opp_knock = int(res.knock)
		var wobble := Difficulty.rng("bowl").randf_range(-0.5, 0.5)
		g.opp_off = clampf(0.5 + (1.0 - float(res.knock) / 10.0) * wobble, 0.0, 1.0)
		g.opp_ball = 0.0
		g.opp_t = 0.0
		g.opp_phase = 0
		g.up[1] = _all_up()
		caption("WAIT. %s STEPS UP." % str(g.opp).to_upper(), 1.5)
		return
	if int(g.opp_phase) == 0:
		g.opp_ball = minf(1.0, float(g.opp_t) / 0.6)
		if float(g.opp_t) >= 0.6:
			g.opp_phase = 1
			_pins_fall(1, int(g.opp_knock))
			_bubble(_actor(str(g.opp)), "!" if int(g.opp_knock) >= 8 else "dots", 1.2)
			caption("%s KNOCKS DOWN %d" % [str(g.opp).to_upper(), int(g.opp_knock)], 1.5)
	elif float(g.opp_t) >= 1.7:
		g.totals[g.opp] = int(g.totals[g.opp]) + int(g.opp_total)
		g.opp = ""
		g.opp_ball = 0.0


func _pins_fall(lane: int, count: int) -> void:
	var up: Array = g.up[lane]
	var standing := []
	for i in 10:
		if up[i]:
			standing.append(i)
	Difficulty.shuffle(standing, "bowl")
	for i in mini(count, standing.size()):
		up[standing[i]] = false
		g.fall["%d_%d" % [lane, standing[i]]] = 0.8


func bowl_rank() -> int:
	var rank := 0
	for who in bowlers():
		if int(g.totals[who]) > int(g.totals["You"]):
			rank += 1
	return rank


func _bowl_end() -> void:
	_finish([3, 2, 1, 1][bowl_rank()])


# ---- karaoke ------------------------------------------------------------------------------------
func _kara_setup() -> void:
	var notes := []
	var gap := Difficulty.f("karaoke.gap")
	var r := Difficulty.rng("karaoke")
	for i in SONG_LEN:
		notes.append({"lane": r.randi_range(0, 3), "time": 1.5 + gap * float(i), "state": ""})
	g = {
		"t": 0.0,
		"notes": notes,
		"score": 0,
		"perfect": 0,
		"good": 0,
		"miss": 0,
		"streak": 0,
		"flash": "",
		"flash_t": 0.0,
		"gap": gap,
		"perfect_win": Difficulty.f("karaoke.perfect"),
		"good_win": Difficulty.f("karaoke.good"),
	}


func _kara_tick(dt: float) -> void:
	g.t = float(g.t) + dt
	g.flash_t = maxf(0.0, float(g.flash_t) - dt)
	for n in g.notes:
		if n.state == "" and float(n.time) + _good_win() < float(g.t):
			n.state = "miss"
			g.miss = int(g.miss) + 1
			g.streak = 0
			_streak_broken()
			g.flash = "MISS"
			g.flash_t = 0.5
	if float(g.t) > _song_secs() + 0.6:
		_kara_end()


func _good_win() -> float:
	return float(g.get("good_win", 0.3))


func _song_secs() -> float:
	return 1.5 + float(g.get("gap", 0.75)) * float(SONG_LEN)


func _kara_press(key: int) -> void:
	var lane := LANE_KEYS.find(key)
	if lane < 0:
		return
	kara_hit(lane)


func kara_hit(lane: int) -> String:
	var pick: Dictionary = {}
	var gap := 9.0
	for n in g.notes:
		if n.state == "" and int(n.lane) == lane and absf(float(n.time) - float(g.t)) < gap:
			gap = absf(float(n.time) - float(g.t))
			pick = n
	if pick.is_empty() or gap > _good_win():
		g.streak = 0
		_streak_broken()
		return ""
	var perfect := gap <= float(g.get("perfect_win", 0.12))
	pick.state = "perfect" if perfect else "good"
	g.score = int(g.score) + (2 if perfect else 1)
	g.perfect = int(g.perfect) + (1 if perfect else 0)
	g.good = int(g.good) + (0 if perfect else 1)
	g.streak = int(g.streak) + 1
	g.flash = "PERFECT!" if perfect else "GOOD"
	g.flash_t = 0.5
	if room_mode() and int(g.streak) % 4 == 0:
		_cheer()
	if room_mode() and int(g.streak) >= 8 and not g.get("dance", false):
		g.dance = true
		_hold_player("dance")
	return str(pick.state)


func _kara_end() -> void:
	var share := float(g.score) / float(SONG_LEN * 2)
	_finish(3 if share >= 0.75 else (2 if share >= 0.5 else (1 if share >= 0.25 else 0)))


# ---- escape room --------------------------------------------------------------------------------
func _escape_setup() -> void:
	var digits := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	Difficulty.shuffle(digits, "escape")
	var friends := 0
	for who in Social.people():
		friends += 1 if Social.is_friendly(who) else 0
	g = {
		"code": [digits[0], digits[1], digits[2]],
		"cur": [0, 0, 0],
		"cursor": 0,
		"guesses": [],
		"time": Difficulty.f("escape.time"),
		"hints": clampi(maxi(1, friends), 1, 3),
		"hints_used": 0,
		"revealed": [],
		"msg": "",
	}


func _escape_tick(dt: float) -> void:
	g.time = float(g.time) - dt
	if float(g.time) <= 0.0:
		g.msg = "TIME IS UP"
		_finish(0)


func _escape_press(key: int) -> void:
	var cur: Array = g.cur
	match key:
		KEY_LEFT:
			g.cursor = (int(g.cursor) + 2) % 3
		KEY_RIGHT:
			g.cursor = (int(g.cursor) + 1) % 3
		KEY_UP:
			cur[int(g.cursor)] = (int(cur[int(g.cursor)]) + 1) % 10
		KEY_DOWN:
			cur[int(g.cursor)] = (int(cur[int(g.cursor)]) + 9) % 10
		KEY_ENTER, KEY_KP_ENTER:
			if room_mode():
				_room_submit()
			else:
				escape_try(cur.duplicate())
		KEY_H:
			if not room_mode():
				escape_hint()


func escape_score(guess: Array) -> Array:
	var code: Array = g.code
	var bulls := 0
	var cows := 0
	for i in 3:
		if int(guess[i]) == int(code[i]):
			bulls += 1
		elif code.has(int(guess[i])):
			cows += 1
	return [bulls, cows]


func escape_try(guess: Array) -> void:
	if g.guesses.size() >= 8:
		return
	var score := escape_score(guess)
	g.guesses.append([guess, score[0], score[1]])
	if int(score[0]) == 3:
		var tries: int = g.guesses.size()
		var result := 3 if tries <= 4 else (2 if tries <= 6 else 1)
		if int(g.hints_used) >= 2:
			result = maxi(1, result - 1)
		g.msg = "THE DOOR CLICKS OPEN!"
		_finish(result)
	elif g.guesses.size() >= 8:
		g.msg = "OUT OF TRIES"
		_finish(0)


# the first friendly coworker (upper case) for hints; with nobody friendly, the first person in the room
func _first_friend() -> String:
	for who in Social.people():
		if Social.is_friendly(who):
			return who.to_upper()
	var here := roster()
	return str(here[0]).to_upper() if not here.is_empty() else "ALAN"


func escape_hint() -> String:
	if int(g.hints) <= 0:
		return ""
	var open := []
	for i in 3:
		if not g.revealed.has(i):
			open.append(i)
	if open.is_empty():
		return ""
	var slot: int = Difficulty.pick(open, "escape")
	g.revealed.append(slot)
	g.hints = int(g.hints) - 1
	g.hints_used = int(g.hints_used) + 1
	g.cur[slot] = g.code[slot]
	var friend := _first_friend()
	g.msg = "%s: SLOT %d IS A %d" % [friend, slot + 1, int(g.code[slot])]
	return str(g.msg)


# ---- dinner -------------------------------------------------------------------------------------
func _dinner_setup() -> void:
	g = {"round": 1, "options": [], "sel": 0, "react": {}, "wait": 0.0, "score": 0, "last": ""}
	_dinner_deal()


func _dinner_deal() -> void:
	var pool: Array = TOPICS.duplicate()
	Difficulty.shuffle(pool, "dinner")
	g.options = pool.slice(0, 4)
	g.sel = 0
	g.react = {}
	g.wait = 0.0


func _dinner_tick(dt: float) -> void:
	if not g.react.is_empty():
		g.wait = float(g.wait) - dt
		if float(g.wait) <= 0.0:
			if int(g.round) >= 5:
				_dinner_end()
			else:
				g.round = int(g.round) + 1
				_dinner_deal()


func _dinner_press(key: int) -> void:
	if not g.react.is_empty() or str(g.get("stage", "")) == "sit":
		return
	match key:
		KEY_UP:
			g.sel = (int(g.sel) + 3) % 4
		KEY_DOWN:
			g.sel = (int(g.sel) + 1) % 4
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			dinner_talk(int(g.sel))


func dinner_talk(index: int) -> int:
	var topic: String = g.options[index]
	var total := 0
	g.react = {}
	g.hidden = _dinner_hidden()
	for who in diners():
		var mood := "meh"
		var pts := 1
		if LOVES[who].has(topic):
			mood = "love"
			pts = 2
		elif HATES[who] == topic:
			mood = "hate"
			pts = 0
		total += pts
		g.react[who] = mood
		if g.hidden.has(who):
			continue  # a face you could not read teaches you nothing
		var entry: Dictionary = known.get(who, {"likes": [], "hates": []})
		if mood == "love" and not entry.likes.has(topic):
			entry.likes.append(topic)
		elif mood == "hate" and not entry.hates.has(topic):
			entry.hates.append(topic)
		known[who] = entry
	g.score = int(g.score) + total
	g.wait = 1.4
	if room_mode():
		_dinner_react()
	return total


# harder tiers hide some faces for a round (the points still count)
func _dinner_hidden() -> Array:
	var table := diners()
	var hide_n := table.size() - clampi(Difficulty.i("dinner.reveal"), 0, table.size())
	if hide_n <= 0:
		return []
	var order: Array = table.duplicate()
	Difficulty.shuffle(order, "dinner")
	return order.slice(0, hide_n)


func _dinner_end() -> void:
	var score := int(g.score)
	var scale := float(diners().size()) / 3.0  # the targets are for a table of three; fewer faces, fewer points
	_finish(
		(
			3
			if score >= roundi(24.0 * scale)
			else (2 if score >= roundi(19.0 * scale) else (1 if score >= roundi(14.0 * scale) else 0))
		)
	)


# ---- in the room: the games are played in the scene itself ---------------------------------------
func room_mode() -> bool:
	return _traveled and is_open


func _x0() -> float:
	return float(World.DATA.SCENES[str(ROOMS[game])].x0)


func _actor(who: String) -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Actors/" + who) if scene != null else null


func _place_player(x: float) -> void:
	var p := _actor("Player")
	if p != null:
		p.global_position = Vector2(x, 118.0)
		p.velocity = Vector2.ZERO


func _hold_player(anim: String, toward := INF) -> void:
	var p := _actor("Player")
	if p != null:
		p.start_emote(anim, 100000.0, toward)


func _release_player() -> void:
	var p := _actor("Player")
	if p != null and p.state == "emote":
		p.start_emote("idle", 0.05)


func caption(text: String, secs := 3.0) -> void:
	_caption = text
	_caption_t = secs


func _bubble(node: Node, glyph: String, secs := 1.2) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("_ensure_bubble"):
		node._ensure_bubble()
	if node.get("_bubble") == null:
		return
	node._bubble.glyph = glyph
	node._bubble.visible = true
	_marks[node] = secs


func _room_begin() -> void:
	Game.ui_open = false
	match game:
		"karaoke":
			var mic := _x0() + MIC_X
			_place_player(mic)
			_hold_player("talk", mic + 60.0)
			caption("ARROW KEYS AT THE LINE. SING!", 4.0)
		"escape":
			caption("LOOK AROUND. E ON THE CHALKBOARD, THE CLOCK, THE PAINTING. N = HINT", 6.0)
		"dinner":
			g.stage = "sit"
			caption("SIT AT THE BOOTH WITH ALAN (PRESS E ON THE SEAT)", 99.0)


func _room_process(delta: float) -> void:
	_caption_t = maxf(0.0, _caption_t - delta)
	for node in _marks.keys():
		_marks[node] = float(_marks[node]) - delta
		if float(_marks[node]) <= 0.0:
			if is_instance_valid(node) and node.get("_bubble") != null:
				node._bubble.visible = false
			_marks.erase(node)
	if phase == "play" and game == "dinner" and str(g.get("stage", "")) == "sit":
		var p := _actor("Player")
		if p != null and p.state == "sitting":
			g.stage = "talk"
			Game.ui_open = true
			caption("PICK A TOPIC (UP / DOWN, ENTER). WATCH THEIR FACES.", 5.0)


# keys the in-room game wants (the rest still move you around)
func _room_wants(key: int) -> bool:
	if key == KEY_ESCAPE:
		return true
	match game:
		"bowling":
			return key in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		"karaoke":
			return key in LANE_KEYS
		"escape":
			if g.get("entry", false):
				return key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]
			return key == KEY_N
		_:
			return (
				str(g.get("stage", "")) == "talk"
				and key in [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			)


func _room_press(key: int) -> bool:
	if game == "escape" and key == KEY_N and not g.get("entry", false):
		escape_nudge()
		return true
	return false


# E belongs to the bowling game while it runs (the crew should not answer it)
func blocks_interact() -> bool:
	return is_open and room_mode() and phase == "play" and game == "bowling"


# the one control hint line: pages show it as their footer, rooms in the bar at the bottom
func hint() -> String:
	if phase == "intro":
		return "ENTER = START  ESC = SKIP  TAB = LOOK" if _traveled else "ENTER = START  ESC = SKIP"
	if phase == "result":
		return "ENTER = CONTINUE"
	if not room_mode():
		return str(GAMES[game].keys)
	match game:
		"bowling":
			match str(g.get("stage", "")):
				"ready":
					return "E = STEP UP  ESC = LEAVE"
				"aim":
					return "E = STOP THE AIM  ESC = LEAVE"
				"power":
					return "E = STOP THE POWER  ESC = LEAVE"
			return "WAIT FOR YOUR TURN  ESC = LEAVE"
		"karaoke":
			return "ARROW KEYS = HIT NOTES  ESC = LEAVE"
		"escape":
			if g.get("entry", false):
				return "ARROWS  ENTER = TRY  ESC = BACK"
			return "E = LOOK / USE  N = HINT  ESC = LEAVE"
	if str(g.get("stage", "")) == "talk":
		return "UP / DOWN  ENTER = TALK  ESC = LEAVE"
	return "E = SIT DOWN  ESC = LEAVE"


# ---- karaoke extras
func _cheer() -> void:
	var cheer: Array = diners()
	if roster().has("Vic"):
		cheer.append("Vic")
	if cheer.is_empty():
		return
	var who: String = Difficulty.pick(cheer, "karaoke")
	_bubble(_actor(who), "heart", 1.5)


func _streak_broken() -> void:
	if not room_mode() or game != "karaoke":
		return
	if g.get("dance", false):
		g.dance = false
		_hold_player("talk", _x0() + MIC_X + 60.0)
	if Difficulty.rng("karaoke").randf() < 0.3:
		var crowd := diners()
		if not crowd.is_empty():
			_bubble(_actor(Difficulty.pick(crowd, "karaoke")), "?", 1.0)


# ---- escape room extras
func _escape_room_setup() -> void:
	var pool := [1, 2, 3, 4, 5, 6, 7, 8, 9]
	Difficulty.shuffle(pool, "escape")
	var a: int = pool[0]
	var first := Difficulty.rng("escape").randi_range(0, a)
	g = {
		"code": [a, pool[1], pool[2]],
		"cur": [0, 0, 0],
		"cursor": 0,
		"guesses": [],
		"time": Difficulty.f("escape.time"),
		"hints": 3,
		"hints_used": 0,
		"revealed": [],
		"msg": "",
		"found": [],
		"entry": false,
		"wrong": 0,
		"eq": [first, a - first],
	}


func interact(kind: String) -> void:
	if not room_mode() or game != "escape" or phase != "play" or g.is_empty():
		return
	match kind:
		"clue_board":
			_found(0)
			caption(
				(
					"THE CHALKBOARD: %d + %d = ?   THE ANSWER IS THE FIRST DIGIT."
					% [int(g.eq[0]), int(g.eq[1])]
				),
				5.0
			)
		"clue_clock":
			_found(1)
			caption(
				"THE CLOCK HAS STOPPED AT %d O'CLOCK. THAT IS THE SECOND DIGIT." % int(g.code[1]),
				5.0
			)
		"clue_painting":
			_found(2)
			caption(
				"A BRASS PLAQUE UNDER THE PAINTING: NO. %d. THE THIRD DIGIT." % int(g.code[2]), 5.0
			)
		"keypad":
			g.entry = true
			Game.ui_open = true
			caption(
				"ENTER THE CODE: UP / DOWN CHANGE, LEFT / RIGHT MOVE, ENTER TRIES IT, ESC BACKS OFF",
				6.0
			)


func _found(index: int) -> void:
	if not g.found.has(index):
		g.found.append(index)


func escape_nudge() -> String:
	if int(g.hints) <= 0:
		caption("NOBODY HAS ANYTHING LEFT TO SAY.", 2.0)
		return ""
	var friend := _first_friend()
	var text := "YOU HAVE ALL THREE. TRY THE KEYPAD ON THE VAULT."
	for i in 3:
		if not g.found.has(i):
			text = [
				"TRY THE CHALKBOARD.", "THAT WALL CLOCK LOOKS WRONG.", "WHAT IS UNDER THE PAINTING?"
			][i]
			break
	g.hints = int(g.hints) - 1
	g.hints_used = int(g.hints_used) + 1
	text = "%s: %s" % [friend, text]
	caption(text, 4.0)
	_bubble(_actor(friend.capitalize()), "!", 1.5)
	return text


func _room_submit() -> void:
	var cur: Array = g.cur
	if cur == g.code:
		var left := float(g.time)
		var result := 3 if left >= 70.0 else (2 if left >= 35.0 else 1)
		if int(g.hints_used) >= 2:
			result = maxi(1, result - 1)
		g.entry = false
		g.msg = "THE VAULT OPENS!"
		_finish(result)
		return
	g.wrong = int(g.wrong) + 1
	var penalty := Difficulty.f("escape.wrong_penalty")
	g.time = float(g.time) - penalty
	caption("WRONG CODE. THE ALARM SHAVES %d SECONDS OFF." % int(penalty), 3.0)


# ---- dinner extras
func _dinner_react() -> void:
	var parts := []
	for who in diners():
		var mood: String = g.react[who]
		if g.get("hidden", []).has(who):
			_bubble(_actor(who), "?", 1.3)
			parts.append("%s IS HARD TO READ" % who.to_upper())
			continue
		_bubble(
			_actor(who), "heart" if mood == "love" else ("!" if mood == "hate" else "dots"), 1.3
		)
		parts.append(
			(
				"%s %s"
				% [
					who.to_upper(),
					{"love": "LOVES IT", "hate": "DREADS IT", "meh": "IS FINE"}[mood]
				]
			)
		)
	caption(", ".join(parts), 2.0)


# ---- the in-room display (replaces the panel while you play)
func _paint_hud(size: Vector2) -> void:
	UiStyle.hint_bar(_canvas, size, hint())
	var top := UiStyle.caption_bar(_canvas, size, _caption if _caption_t > 0.0 else "")
	var strip := Rect2(0.0, top - UiStyle.STRIP_H, minf(size.x, 164.0), UiStyle.STRIP_H)
	match game:
		"bowling":
			_hud_bowling(strip)
		"karaoke":
			_hud_karaoke(strip)
		"escape":
			_hud_escape(strip)
		_:
			_hud_dinner(strip, size)


func _hud_bowling(s: Rect2) -> void:
	var o := UiStyle.strip(_canvas, s)
	_t("FRAME %d OF 5" % int(g.frame), o.x, o.y, WHITE)
	var stage := str(g.stage)
	var x := s.position.x + 58.0
	if stage == "aim" or stage == "power":
		var bar := Rect2(s.position.x + 82.0, s.position.y + 3.0, 80.0, 5.0)
		_canvas.draw_rect(bar, UiStyle.SOFT)
		if stage == "aim":
			_canvas.draw_rect(Rect2(bar.position.x + 32.0, bar.position.y, 16.0, 5.0), GREEN)
			_canvas.draw_rect(
				Rect2(bar.position.x + 79.0 * float(g.marker), bar.position.y - 2.0, 2.0, 9.0),
				WHITE
			)
			_t("AIM", x, o.y, WHITE)
		else:
			_canvas.draw_rect(Rect2(bar.position.x + 58.0, bar.position.y, 14.0, 5.0), GREEN)
			_canvas.draw_rect(
				Rect2(bar.position.x, bar.position.y, 80.0 * float(g.power), 5.0), AMBER
			)
			_t("POWER", x, o.y, WHITE)
	else:
		var status := (
			"YOUR TURN" if stage == "ready" else ("ROLLING" if stage == "roll" else "CREW BOWLS")
		)
		_t(status, x, o.y, UiStyle.SOFT)


func _hud_karaoke(s: Rect2) -> void:
	var lanes := Rect2(4.0, s.position.y - 79.0, 100.0, 78.0)
	UiStyle.box(_canvas, lanes)
	_paint_karaoke(
		Rect2(
			lanes.position.x + 2.0, lanes.position.y + 2.0, lanes.size.x - 4.0, lanes.size.y - 4.0
		),
		true
	)
	var o := UiStyle.strip(_canvas, s)
	_t("SCORE %d  STREAK %d" % [int(g.score), int(g.streak)], o.x, o.y, WHITE)
	if float(g.flash_t) > 0.0:
		_t(str(g.flash), s.position.x + 88.0, o.y, GREEN if g.flash != "MISS" else RED)


func _hud_escape(s: Rect2) -> void:
	var o := UiStyle.strip(_canvas, s)
	if not g.get("entry", false):
		_t("CLUES %d OF 3  HINTS %d" % [g.found.size(), int(g.hints)], o.x, o.y, WHITE)
		return
	_t("CODE", o.x, o.y, WHITE)
	for i in 3:
		var r := Rect2(s.position.x + 32.0 + 12.0 * float(i), s.position.y + 1.0, 10.0, 9.0)
		_canvas.draw_rect(r, WHITE)
		_canvas.draw_rect(
			Rect2(r.position.x, r.end.y - 1.0, 10.0, 1.0),
			BLUE if int(g.cursor) == i else UiStyle.SOFT
		)
		PixelFont.draw(
			_canvas,
			str(int(g.cur[i])),
			r.position + Vector2(3.0, 2.0),
			GREEN if g.revealed.has(i) else INK,
			1
		)


func _hud_dinner(s: Rect2, size: Vector2) -> void:
	var o := UiStyle.strip(_canvas, s)
	if str(g.get("stage", "")) != "talk":
		_t("SIT AT THE BOOTH", o.x, o.y, UiStyle.SOFT)
		return
	_t("ROUND %d OF 5  SCORE %d" % [int(g.round), int(g.score)], o.x, o.y, WHITE)
	var w := minf(size.x - 8.0, 84.0)  # narrow, so it stays right of Vic at the bar in the 320x180 format
	var box := Rect2(size.x - w - 4.0, s.position.y - 43.0, w, 42.0)
	UiStyle.box(_canvas, box)
	for i in 4:
		var on: bool = int(g.sel) == i and g.react.is_empty()
		var ry := box.position.y + 4.0 + 9.0 * float(i)
		if on:
			_canvas.draw_rect(Rect2(box.position.x + 2.0, ry - 1.0, w - 4.0, 8.0), Color("ffe08a"))
		_t(str(g.options[i]), box.position.x + 4.0, ry, INK if on else WHITE)


# ---- drawing ------------------------------------------------------------------------------------
func _t(s: String, x: float, y: float, color := INK) -> void:
	PixelFont.draw(_canvas, s, Vector2(x, y), color, 1)


func _tc(s: String, cx: float, y: float, color := INK) -> void:
	PixelFont.draw(_canvas, s, Vector2(cx - float(PixelFont.width(s, 1)) * 0.5, y), color, 1)


func _wrap(s: String, chars: int) -> Array:
	return UiStyle.wrap_text(s, chars)


func _star(c: Vector2, r: float, color: Color) -> void:
	UiStyle.star(_canvas, c, r, color)


func _arrow(lane: int, c: Vector2, size: float, color: Color) -> void:
	var s := size
	var pts := PackedVector2Array()
	match lane:
		0:
			pts = PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s, -s), c + Vector2(s, s)])
		1:
			pts = PackedVector2Array([c + Vector2(0, -s), c + Vector2(-s, s), c + Vector2(s, s)])
		2:
			pts = PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, -s), c + Vector2(s, -s)])
		_:
			pts = PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s, -s), c + Vector2(-s, s)])
	_canvas.draw_colored_polygon(pts, color)


func _paint() -> void:
	if not is_open:
		return
	var size := get_viewport().get_visible_rect().size
	if room_mode() and phase == "play":
		_paint_hud(size)
		return
	if _traveled and _peek:
		UiStyle.hint_bar(_canvas, size, "TAB = BACK TO THE GAME")
		return
	_canvas.draw_rect(
		Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.0 if _traveled else 0.86)
	)
	var panel := UiStyle.panel_rect(size, 250.0, 112.0)
	var title := str(GAMES[game].label) + ("  TEAM OUTING" if phase != "result" else "  RESULT")
	var body := UiStyle.panel(_canvas, panel, title, "", 0.88 if _traveled else 1.0)
	match phase:
		"intro":
			_paint_intro(body)
		"result":
			_paint_result(body)
		_:
			match game:
				"bowling":
					_paint_bowling(body)
				"karaoke":
					_paint_karaoke(body)
				"escape":
					_paint_escape(body)
				_:
					_paint_dinner(body)
	UiStyle.footer(_canvas, panel, hint())


func _paint_intro(b: Rect2) -> void:
	var y := b.position.y + 2.0
	var blurb := str(ROOM_INTRO[game]) if _traveled else str(GAMES[game].blurb)
	for line in _wrap(blurb, int(b.size.x / 4.0)):
		_t(line, b.position.x, y)
		y += 7.0
	y += 4.0
	if Campaign.mode == "owner":
		_t("COST $%d" % int(GAMES[game].cost), b.position.x, y, RED)
		y += 7.0
	if best.has(game):
		_t("YOUR BEST: %d OF 3 STARS" % int(best[game]), b.position.x, y, GREEN)


func _paint_result(b: Rect2) -> void:
	UiStyle.stars(_canvas, b.position.x + b.size.x * 0.5, b.position.y, stars)
	var y := b.position.y + 24.0
	for line in lines:
		for part in _wrap(str(line), int(b.size.x / 4.0)):
			_t(part, b.position.x, y)
			y += 7.0
	var detail := ""
	if not g.is_empty():
		match game:
			"bowling":
				detail = "YOU %d" % int(g.totals["You"])
				for who in bowlers():
					detail += "  %s %d" % [who.to_upper(), int(g.totals[who])]
			"karaoke":
				detail = (
					"PERFECT %d  GOOD %d  MISSED %d" % [int(g.perfect), int(g.good), int(g.miss)]
				)
			"escape":
				detail = (
					"CODE %d%d%d  TRIES %d  HINTS %d"
					% [
						int(g.code[0]),
						int(g.code[1]),
						int(g.code[2]),
						maxi(g.guesses.size(), int(g.get("wrong", 0)) + (1 if stars > 0 else 0)),
						int(g.hints_used)
					]
				)
			"dinner":
				detail = "TABLE SCORE %d OF %d" % [int(g.score), 10 * diners().size()]
	if detail != "":
		_t(detail, b.position.x, y + 3.0, BLUE)


func _paint_bowling(b: Rect2) -> void:
	var x := b.position.x
	var y := b.position.y
	_t("FRAME %d  ROLL %d" % [int(g.frame), int(g.roll)], x, y)
	var names := ["You"] + bowlers()
	for i in names.size():
		_t(
			"%s %d" % [names[i].to_upper(), int(g.totals[names[i]])],
			x,
			y + 10.0 + 8.0 * float(i),
			BLUE if i == 0 else INK
		)
	var lane := Rect2(x + 78.0, y, minf(b.size.x - 82.0, 90.0), b.size.y - 18.0)
	_canvas.draw_rect(lane, Color("d9b26b"))
	_canvas.draw_rect(Rect2(lane.position.x, lane.position.y, 3.0, lane.size.y), Color("5a3a22"))
	_canvas.draw_rect(Rect2(lane.end.x - 3.0, lane.position.y, 3.0, lane.size.y), Color("5a3a22"))
	var px := lane.position.x + lane.size.x * 0.5
	var idx := 0
	for row in 4:
		for k in row + 1:
			var standing: bool = idx < int(g.pins)
			var pos := Vector2(
				px + (float(k) - float(row) * 0.5) * 8.0, lane.position.y + 6.0 + float(row) * 7.0
			)
			_canvas.draw_rect(
				Rect2(pos - Vector2(2, 2), Vector2(4, 4)), WHITE if standing else Color("b8975a")
			)
			idx += 1
	if g.stage == "roll":
		var by := lane.end.y - 4.0 - (lane.size.y - 14.0) * float(g.ball)
		var bx := px + (float(g.marker) - 0.5) * lane.size.x * 0.5
		_canvas.draw_rect(Rect2(bx - 3.0, by - 3.0, 6.0, 6.0), INK)
	var bar_y := b.end.y - 8.0
	var bar := Rect2(x, bar_y, 70.0, 5.0)
	_canvas.draw_rect(bar, Color("c9d2e0"))
	if g.stage == "aim":
		_canvas.draw_rect(Rect2(bar.position.x + 28.0, bar_y, 14.0, 5.0), GREEN)
		_canvas.draw_rect(
			Rect2(bar.position.x + 69.0 * float(g.marker), bar_y - 2.0, 2.0, 9.0), INK
		)
		_t("AIM", x + 74.0 - 4.0, bar_y - 8.0, BLUE)
	elif g.stage == "power":
		_canvas.draw_rect(Rect2(bar.position.x + 52.0, bar_y, 12.0, 5.0), GREEN)
		_canvas.draw_rect(Rect2(bar.position.x, bar_y, 70.0 * float(g.power), 5.0), AMBER)
		_t("POWER", x + 74.0 - 4.0, bar_y - 8.0, BLUE)
	if str(g.msg) != "":
		_t(str(g.msg), x, bar_y - 8.0, RED if "GUTTER" in str(g.msg) else GREEN)


func _paint_karaoke(b: Rect2, hud := false) -> void:
	var x := b.position.x
	var y := b.position.y
	var top := y + (2.0 if hud else 18.0)
	if not hud:
		_t("TOTALLY LEGAL HIT (2013)", x, y, BLUE)
		_t("SCORE %d   STREAK %d" % [int(g.score), int(g.streak)], x, y + 8.0)
	var line_y := b.end.y - 12.0
	var left := b.position.x + b.size.x * 0.5 - 40.0
	for lane in 4:
		var cx := left + 20.0 * float(lane) + 10.0
		_canvas.draw_rect(Rect2(cx - 9.0, top, 18.0, line_y + 6.0 - top), Color("dde3ee"))
		_arrow(lane, Vector2(cx, line_y), 5.0, Color(LANE_COLORS[lane], 0.45))
	for n in g.notes:
		var dy: float = (float(n.time) - float(g.t)) * 45.0
		if dy < -14.0 or dy > line_y - top + 4.0:
			continue
		var col: Color = LANE_COLORS[int(n.lane)]
		if n.state == "miss":
			col = Color("8a8f9a")
		elif n.state != "":
			col = Color(col, 0.35)
		_arrow(int(n.lane), Vector2(left + 20.0 * float(n.lane) + 10.0, line_y - dy), 5.0, col)
	if float(g.flash_t) > 0.0 and not hud:
		_tc(str(g.flash), left + 80.0 + 24.0, y + 30.0, GREEN if g.flash != "MISS" else RED)
	var song := minf(1.0, float(g.t) / _song_secs())
	_canvas.draw_rect(Rect2(x, b.end.y - 4.0, b.size.x, 3.0), UiStyle.SOFT)
	_canvas.draw_rect(Rect2(x, b.end.y - 4.0, b.size.x * song, 3.0), BLUE)


func _paint_escape(b: Rect2) -> void:
	var x := b.position.x
	var y := b.position.y
	_t(
		(
			"TIME %d   HINTS LEFT %d   TRIES %d OF 8"
			% [int(float(g.time)), int(g.hints), g.guesses.size()]
		),
		x,
		y,
		RED if float(g.time) < 20.0 else INK
	)
	var row := 0
	for entry in g.guesses:
		if row >= 8:
			break
		_t(
			(
				"%d %d %d  B%d C%d"
				% [
					int(entry[0][0]),
					int(entry[0][1]),
					int(entry[0][2]),
					int(entry[1]),
					int(entry[2])
				]
			),
			x,
			y + 10.0 + 7.0 * float(row),
			INK
		)
		row += 1
	var bx := x + b.size.x - 74.0
	for i in 3:
		var r := Rect2(bx + 20.0 * float(i), y + 12.0, 16.0, 22.0)
		_canvas.draw_rect(r, WHITE)
		_canvas.draw_rect(
			Rect2(r.position.x, r.end.y - 2.0, 16.0, 2.0),
			BLUE if int(g.cursor) == i else Color("c9d2e0")
		)
		PixelFont.draw(
			_canvas,
			str(int(g.cur[i])),
			r.position + Vector2(5.0, 6.0),
			GREEN if g.revealed.has(i) else INK,
			2
		)
	_t("U/D CHANGE   L/R MOVE", bx - 6.0, y + 40.0, Color("46506a"))
	if str(g.msg) != "":
		for part in _wrap(str(g.msg), 18):
			y += 0.0
			_t(part, bx - 6.0, y + 50.0, BLUE)
			y += 7.0


func _paint_dinner(b: Rect2) -> void:
	var x := b.position.x
	var y := b.position.y
	_t("ROUND %d OF 5   TABLE SCORE %d" % [int(g.round), int(g.score)], x, y)
	for i in 4:
		var on: bool = int(g.sel) == i and g.react.is_empty()
		if on:
			_canvas.draw_rect(Rect2(x - 1.0, y + 9.0 + 9.0 * float(i), 82.0, 8.0), Color("ffe08a"))
		_t(str(g.options[i]), x + 2.0, y + 11.0 + 9.0 * float(i))
	var rx := x + 92.0
	var table := diners()
	for i in table.size():
		var who: String = table[i]
		var ry := y + 9.0 + 14.0 * float(i)
		_t(who.to_upper(), rx, ry, BLUE)
		if g.react.has(who):
			var mood: String = g.react[who]
			var face := "<3" if mood == "love" else (":(" if mood == "hate" else "OK")
			if g.get("hidden", []).has(who):
				face = "??"
				mood = "meh"
			_t(face, rx + 40.0, ry, GREEN if mood == "love" else (RED if mood == "hate" else INK))
		var entry: Dictionary = known.get(who, {"likes": [], "hates": []})
		var note := ""
		if not entry.likes.is_empty():
			note += "LIKES " + ", ".join(entry.likes)
		if not entry.hates.is_empty():
			note += ("  " if note != "" else "") + "NOT " + ", ".join(entry.hates)
		_t(note.substr(0, int((b.size.x - 92.0) / 4.0)), rx, ry + 7.0, Color("46506a"))
