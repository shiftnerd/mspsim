extends Node
# gdlint:disable=max-line-length
# Nerf guns. Take a blaster from the rack in the cubicle area (E; E again to reload), Z fires a foam dart, G puts it away.
# Darts fly in an arc, stick in walls and furniture (monitors flicker), and hit people: coworkers react in character,
# friendly ones laugh and fire back (a short nerf war in the room), and walking over a dart on the floor picks it up.
# In a campaign a hit relieves a little stress (+1 energy, up to 4 a day) and moves opinions.

const DART := preload("res://scripts/dart.gd")
const AIM := preload("res://scripts/aim.gd")
const Modes := preload("res://scripts/nerf_modes.gd")
const CUP := preload("res://scripts/nerf_cup.gd")
const MAX_AMMO := 6
const SPEED := 175.0
const CHARGE_SECS := 1.1  # holding Z this long = a full-power lob
const LOB_SPEED := 120.0  # extra forward speed at full charge
const LOB_LIFT := 58.0  # extra upward speed at full charge
const FIRE_GAP := 0.4
const WAR_SECS := 45.0
const DUCK_TOP := 40.0  # a ducking person is this tall (standing: 84)
const REACT := {
	"Alan": {"base": -1, "friendly": "heart", "line": "Alan: Not at my desk, please.", "mood": "!"},
	"Garrison": {"base": 1, "friendly": "heart", "line": "Garrison: Oh, it is ON.", "mood": "!"},
	"Maya": {"base": 1, "friendly": "heart", "line": "Maya: Hey! My granola bar!", "mood": "!"},
	"Morgan":
	{
		"base": 0,
		"friendly": "heart",
		"line": "Morgan: I am going to pretend I did not see that. Once.",
		"mood": "dots"
	},
	"Dan":
	{"base": 1, "friendly": "heart", "line": "Dan: Okay, that was a good shot.", "mood": "dots"},
	"Vic":
	{
		"base": 1,
		"friendly": "heart",
		"line": "Vic: Careful, I have a client call at two!",
		"mood": "!"
	},
}

var ammo := 0
var hits := 0  # total hits on coworkers
var taken := 0
var war_t := 0.0
var war_hits := 0
var war_taken := 0
var dodges := 0  # darts people ducked under
# the score of the war in progress (see war_result)
var war_dodged := 0  # darts you ducked
var war_missed := 0  # your darts they ducked
var war_ff := 0  # coworkers hit by coworkers
var war_assists := 0  # ... within 2.5 s of your own hit on the same person
var war_longest := 0  # longest hit of yours, px
var last_result := {}
# the mode of the war in progress (R11): "" = the classic free-for-all, "cup", "elim" or "hide" (see nerf_modes.gd)
var mode := ""
var arena := ""
var cups := 0  # cups you knocked down
var cups_rival := 0  # cups the crew knocked down
var lives := {}  # elimination: name (or "Player") -> lives left
var downed := {}  # elimination: who is out
var hide_t := 0.0  # hide and seek: seconds you were unseen
var hide_found := false
var seeker := ""
var stunned := 0.0
var mode_result := {}
var cup_wait := 0.0
var cup_node_index := -1
var cup_x := 0.0
var cup_node: Node2D = null

var charge := 0.0
var charging := false

var _cool := 0.0
var _preview: Node2D = null
var _energy_today := 0
var _energy_day := -1
var _shot_t := {}  # name -> seconds until the next war shot
var _dodge_ms := 0
var _hit_ms := {}  # name -> when you last hit them


func _ready() -> void:
	Campaign.day_started.connect(func(_d: int) -> void: _energy_today = 0)


func reset() -> void:
	ammo = 0
	hits = 0
	taken = 0
	war_t = 0.0
	war_hits = 0
	war_taken = 0
	_reset_score()
	_energy_today = 0
	_clear_mode()


func _reset_score() -> void:
	war_dodged = 0
	war_missed = 0
	war_ff = 0
	war_assists = 0
	war_longest = 0
	_hit_ms = {}


func _scene() -> Node:
	return get_tree().current_scene


func _player() -> Node:
	var scene := _scene()
	return scene.get_node_or_null("Actors/Player") if scene != null else null


func holding() -> bool:
	var p := _player()
	return p != null and str(p.get("held")) == "nerf"


func on_given() -> void:
	ammo = MAX_AMMO
	Hints.toast("Z FIRES, HOLD Z TO LOB, S TO DUCK, V PICKS A WAR GAME.", 4.0)


# ---- firing ------------------------------------------------------------------------------------------
func fire_player(p: Node, power := 0.0) -> bool:
	if str(p.held) != "nerf" or ammo <= 0 or _cool > 0.0 or Game.ui_open or Game.busy:
		if str(p.held) == "nerf" and ammo <= 0:
			Hints.toast("OUT OF DARTS. PICK THEM UP OR RELOAD AT THE RACK (E).", 2.5)
		return false
	if p.state not in ["idle", "walk", "run", "sitting", "emote"]:
		return false
	_cool = FIRE_GAP
	ammo -= 1
	var dir := 1.0 if p.facing == "right" else -1.0
	if p.state != "sitting":
		p.start_emote("reach", 0.22)
	_spawn(_muzzle(p, dir), dir, "Player", power)
	return true


# hold Z to aim: the longer you hold, the higher and further the dart goes; a tap is a quick shot
func charge_start(p: Node) -> void:
	if charging or str(p.held) != "nerf" or Game.ui_open or Game.busy:
		return
	if ammo <= 0:
		fire_player(p)  # the "out of darts" message
		return
	if p.state not in ["idle", "walk", "run"]:
		return
	charging = true
	charge = 0.0
	p.start_emote("hold", 100000.0)
	_preview = AIM.new()
	_preview.z_index = 30
	_scene().get_node("Actors").add_child(_preview)


func charge_release(p: Node) -> void:
	if not charging:
		return
	charging = false
	var power := charge if charge > 0.12 else 0.0
	charge = 0.0
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null
	_cool = 0.0
	fire_player(p, power)


func launch_velocity(dir: float, power: float) -> Vector2:
	return Vector2(dir * (SPEED + power * LOB_SPEED), -14.0 - power * LOB_LIFT)


func _update_charge(delta: float) -> void:
	var p := _player()
	if p == null or str(p.held) != "nerf" or Game.ui_open:
		charging = false
		charge = 0.0
		if _preview != null and is_instance_valid(_preview):
			_preview.queue_free()
		_preview = null
		return
	charge = minf(1.0, charge + delta / CHARGE_SECS)
	var dir := 1.0 if p.facing == "right" else -1.0
	if _preview != null and is_instance_valid(_preview):
		_preview.set_path(_muzzle(p, dir), launch_velocity(dir, charge))


func fire_npc(npc: Node, dir: float, power := 0.0) -> void:
	if not is_instance_valid(npc):
		return
	if npc.seat == null and npc._hold <= 0.0:
		npc._begin_hold("reach", 0.3)
	_spawn(_muzzle(npc, dir), dir, str(npc.cast_name), power)


# shoulder height, so darts clear desks and low furniture when you stand beside them
func _muzzle(who: Node, _dir: float) -> Vector2:
	var seated: bool = who.get("seat") != null
	return who.global_position + Vector2(_dir * 9.0, -40.0 if seated else -54.0)


func _spawn(pos: Vector2, dir: float, shooter: String, power := 0.0) -> void:
	var scene := _scene()
	if scene == null:
		return
	var dart := DART.new()
	dart.shooter = shooter
	dart.vel = (
		launch_velocity(dir, power) + Vector2(0.0, Difficulty.rng("nerf").randf_range(-3.0, 3.0))
	)
	dart.position = pos
	dart.set_meta("x0", pos.x)
	scene.get_node("Actors").add_child(dart)


# the sales bell (a fx in group "bells"): a dart that reaches it rings it
func hit_bell(pos: Vector2) -> bool:
	for b in get_tree().get_nodes_in_group("bells"):
		if b.hit_test(pos):
			b.ring("dart")
			return true
	return false


# ---- what a dart can hit -----------------------------------------------------------------------------
func is_ducking(who: Node) -> bool:
	return who.get("ducking") == true or who.get("state") == "duck"


# does the dart at pos hit this body? a ducking body is lower, so a high shot flies over (a dodge)
func _hits(who: Node, pos: Vector2, dart: Node) -> bool:
	if absf(who.global_position.x - pos.x) >= 8.0:
		return false
	var below: bool = pos.y > who.global_position.y - 84.0 and pos.y < who.global_position.y - 4.0
	if not below:
		return false
	if is_ducking(who) and pos.y < who.global_position.y - DUCK_TOP:
		if dart != null and not dart.has_meta("dodged"):
			dart.set_meta("dodged", true)
			_dodged(who, str(dart.shooter))
		return false
	return true


func _dodged(who: Node, shooter: String) -> void:
	dodges += 1
	if who.get("cast_name") == null:
		Career.add("nerf_dodges")
		if war_t > 0.0:
			war_dodged += 1
	elif shooter == "Player" and war_t > 0.0:
		war_missed += 1
	if who.get("cast_name") == null and Time.get_ticks_msec() - _dodge_ms > 3000:
		_dodge_ms = Time.get_ticks_msec()
		Hints.toast("DUCKED!", 1.2)
	elif shooter == "Player":
		Hints.toast("MISSED! THEY DUCKED.", 1.6)


func find_victim(pos: Vector2, shooter: String, dart: Node = null) -> Node:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if str(npc.cast_name) == shooter or npc.get("_hidden") == true or not npc.visible or downed.has(str(npc.cast_name)):
			continue
		if _hits(npc, pos, dart):
			return npc
	var p := _player()
	if p != null and shooter != "Player" and _hits(p, pos, dart):
		return p
	return null


# a wall, or a prop sprite (desks, monitors, chairs): the dart sticks to it
func stick_target(pos: Vector2) -> Node:
	var scene := _scene()
	if scene == null:
		return null
	var name := scene.scene_file_path.get_file().get_basename()
	var info: Dictionary = World.DATA.SCENES.get(name, {})
	if (
		not info.is_empty()
		and (pos.x < float(info.x0) + 2.0 or pos.x > float(info.x0) + float(info.W) - 2.0)
	):
		return scene
	for child in scene.get_node("Actors").get_children():
		if child is Sprite2D and child.texture != null:
			var origin: Vector2 = child.global_position + child.offset
			if Rect2(origin, child.texture.get_size()).has_point(pos):
				return child
	return null


func dart_hit(dart: Node, victim: Node) -> void:
	if victim.has_method("sit") and victim.get("cast_name") == null:
		_hit_player(victim, str(dart.shooter))
	else:
		_hit_npc(victim, str(dart.shooter), dart)


func _hit_npc(npc: Node, shooter: String, dart: Node = null) -> void:
	var who := str(npc.cast_name)
	var react: Dictionary = REACT.get(who, REACT["Dan"])
	if shooter == "Player":
		hits += 1
		var reach := 0.0
		if dart != null:
			reach = absf(dart.position.x - float(dart.get_meta("x0", dart.position.x)))
		Career.note_nerf_hit(reach)
		_mode_hit(who)
		_hit_ms[who] = Time.get_ticks_msec()
		if war_t > 0.0:
			war_hits += 1
			war_longest = maxi(war_longest, roundi(reach))
		var delta: int = int(react.base)
		var friendly := Social.is_friendly(who)
		if friendly:
			delta = 2
		elif Social.is_cold(who):
			delta = -2
		Social.change(who, delta)
		npc.react_hit(str(react.friendly) if delta > 0 else str(react.mood))
		Hints.toast("HIT! " + str(react.line), 2.6)
		_relieve()
		if delta > 0:
			# a coworker who takes it well fires back at once (from the desk if they are sitting)
			if war_t <= 0.0:
				start_war()
				war_hits = 1  # the hit that started the war counts
				war_longest = roundi(reach)
			_shot_t[who] = 0.8
	else:
		npc.react_hit("!")
		_lose_life(str(npc.cast_name))
		if war_t > 0.0:
			war_ff += 1
			if Time.get_ticks_msec() - int(_hit_ms.get(who, -99999)) < 2500:
				war_assists += 1


func _hit_player(p: Node, shooter: String) -> void:
	taken += 1
	_player_hit_mode()
	war_taken += 1 if war_t > 0.0 else 0
	if p.state != "sitting" and p.state != "death":
		p.start_emote("hurt", 0.45)
	p._ensure_bubble()
	p._bubble.glyph = "!"
	p._bubble.visible = true
	Social.change(shooter, 1)
	Hints.toast("%s GOT YOU!" % shooter.to_upper(), 2.0)
	_relieve()


func _relieve() -> void:
	if Campaign.active and _energy_today < 4:
		_energy_today += 1
		Shift.add_energy(1.0)


# ---- the war ------------------------------------------------------------------------------------------
func start_war(mode_id := "") -> void:
	war_t = WAR_SECS
	war_hits = 0
	war_taken = 0
	_reset_score()
	_shot_t = {}
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.get("_hidden") != true:
			npc.give_item("nerf")  # everybody in the room, sitting or standing
		_shot_t[str(npc.cast_name)] = Difficulty.rng("nerf").randf_range(1.5, 3.5)
	Hints.toast("NERF WAR! THEY ARE FIRING BACK.", 3.0)
	_begin_mode(mode_id)


# ---- modes and arenas (R11) -----------------------------------------------------------------------------
func arena_scene() -> String:
	var s := _scene()
	return "" if s == null else s.scene_file_path.get_file().get_basename()


# V with a blaster in hand: pick the game for this room
func offer_war() -> void:
	if war_t > 0.0 or Game.ui_open or Cards.is_open or Game.busy or not holding():
		return
	var a := Modes.arena_for(arena_scene())
	if a.is_empty():
		Hints.toast("NO ARENA HERE. TRY THE OFFICE, THE CUBICLES OR THE CONFERENCE ROOM.", 3.0)
		return
	var options := []
	for id in Modes.MODE_ORDER:
		options.append({"label": str(Modes.MODES[id].label), "id": id})
	options.append({"label": "FREE-FOR-ALL (NO RULES)", "id": "free"})
	options.append({"label": "NEVER MIND", "id": "no"})
	Cards.ask(
		"NERF WAR",
		"ARENA: %s (%d SECONDS). PICK A GAME." % [str(a.label), int(a.secs)],
		options,
		func(id: String) -> void: war_picked(id)
	)


func war_picked(id: String) -> void:
	if id == "no" or war_t > 0.0:
		return
	start_war("" if id == "free" else id)


func _clear_mode() -> void:
	mode = ""
	lives = {}
	downed = {}
	cups = 0
	cups_rival = 0
	hide_t = 0.0
	hide_found = false
	seeker = ""
	stunned = 0.0
	cup_wait = 0.0
	if cup_node != null and is_instance_valid(cup_node):
		cup_node.queue_free()
	cup_node = null


func _begin_mode(id: String) -> void:
	_clear_mode()
	if id == "" or not Modes.MODES.has(id):
		return
	var a := Modes.arena_for(arena_scene())
	if a.is_empty():
		return
	mode = id
	arena = arena_scene()
	war_t = float(a.secs)
	Career.note_first("arena", arena, "nerf_arenas")
	var names := []
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.get("_hidden") != true:
			names.append(str(npc.cast_name))
	match id:
		"cup":
			_place_cup(-1)
		"elim":
			lives["Player"] = int(a.lives)
			for n in names:
				lives[n] = int(a.lives)
		"hide":
			if not names.is_empty():
				seeker = str(Difficulty.pick(names, "nerf"))
			for npc in get_tree().get_nodes_in_group("npcs"):
				if str(npc.cast_name) != seeker and str(npc.held) == "nerf":
					npc.give_item("")
			_shot_t = {seeker: 1.5}
	Hints.toast("%s IN %s. %s" % [str(Modes.MODES[id].label), str(a.label), str(Modes.MODES[id].line)], 5.0)


func _place_cup(from: int) -> void:
	var a := Modes.arena_for(arena)
	var info: Dictionary = World.DATA.SCENES.get(arena, {})
	var p := _player()
	var x0 := float(info.get("x0", 0))
	var w := float(info.get("W", 320))
	var idx := Modes.next_cup_index(a, x0, w, from, p.global_position.x if p != null else 0.0)
	cup_x = Modes.cup_x(a, x0, w, idx)
	cup_node_index = idx
	if cup_node == null or not is_instance_valid(cup_node):
		cup_node = CUP.new()
		cup_node.z_index = 12
		_scene().get_node("Actors").add_child(cup_node)
	cup_node.position = Vector2(cup_x, Modes.CUP_Y)


# a dart in flight at pos (dart.gd calls this): does it knock the cup off its stand?
func cup_check(pos: Vector2, shooter: String) -> void:
	if mode != "cup" or war_t <= 0.0 or cup_wait > 0.0 or cup_node == null:
		return
	if absf(pos.x - cup_x) > Modes.CUP_HALF_W or pos.y < Modes.CUP_Y - 14.0 or pos.y > Modes.CUP_Y + 10.0:
		return
	cup_down(shooter)


func cup_down(shooter: String) -> void:
	cup_wait = Modes.CUP_FALL_SECS
	cup_node.fall()
	var win := int(Modes.MODES.cup.win)
	if shooter == "Player":
		cups += 1
		Career.add("nerf_cups")
		Hints.toast("CUP DOWN! %d OF %d" % [cups, win], 2.0)
	else:
		cups_rival += 1
		Hints.toast("%s KNOCKED THE CUP! %d OF %d FOR THE CREW" % [shooter.to_upper(), cups_rival, win], 2.5)
	if cups >= win or cups_rival >= win:
		_end_war()


# called every frame of a mode war from _process; true = the war is over (you left the arena)
func _mode_ends(delta: float) -> bool:
	if mode == "":
		return false
	if arena_scene() != arena:
		return true
	stunned = maxf(0.0, stunned - delta)
	if mode == "hide":
		hide_t += delta
	elif mode == "cup" and cup_wait > 0.0:
		cup_wait -= delta
		if cup_wait <= 0.0:
			_place_cup(cup_node_index)
	return false


func _npc_fire_at(npc: Node, x: float) -> void:
	var dx: float = x - npc.global_position.x
	var dir := 1.0 if dx >= 0.0 else -1.0
	if npc.seat == null:
		npc.facing = "right" if dir > 0.0 else "left"
		npc._play("idle")
	fire_npc(npc, dir, clampf((absf(dx) - 110.0) / 200.0, 0.0, 1.0))


func _mode_hit(who: String) -> void:
	if mode == "elim":
		_lose_life(who)
	elif mode == "hide" and who == seeker:
		stunned = Modes.HIDE_STUN
		Hints.toast("SEEKER STUNNED FOR %d SECONDS" % int(Modes.HIDE_STUN), 2.0)


func _player_hit_mode() -> void:
	if mode == "hide" and war_t > 0.0:
		hide_found = true
		Hints.toast("FOUND!", 1.5)
		_end_war()
	else:
		_lose_life("Player")


func _lose_life(who: String) -> void:
	if mode != "elim" or war_t <= 0.0 or not lives.has(who) or downed.has(who):
		return
	lives[who] = int(lives[who]) - 1
	if int(lives[who]) > 0:
		return
	downed[who] = true
	if who == "Player":
		Hints.toast("YOU ARE OUT!", 2.0)
		_end_war()
		return
	for npc in get_tree().get_nodes_in_group("npcs"):
		if str(npc.cast_name) == who:
			npc.give_item("")
			npc.react_hit("dots")
	_shot_t.erase(who)
	Hints.toast("%s IS OUT!" % who.to_upper(), 1.8)
	for n in lives:
		if n != "Player" and not downed.has(n):
			return
	_end_war()


func hud_extra() -> String:
	match mode:
		"cup":
			return "  CUP %d/%d" % [cups, int(Modes.MODES.cup.win)]
		"elim":
			return "  LIVES %d" % int(lives.get("Player", 0))
		"hide":
			return "  UNSEEN %d" % int(hide_t)
	return ""


func _end_mode() -> void:
	if mode == "":
		return
	var won := false
	var line := ""
	match mode:
		"cup":
			var need := int(Modes.MODES.cup.win)
			won = cups >= need
			line = (
				"CUP WAR: YOU %d, THE CREW %d. %s"
				% [cups, cups_rival, "YOU WIN!" if won else ("THE CREW WINS." if cups_rival > cups else "TIME. A DRAW.")]
			)
		"elim":
			won = not downed.has("Player")
			for n in lives:
				if n != "Player" and not downed.has(n):
					won = false
			line = (
				"ELIMINATION: "
				+ ("LAST ONE STANDING!" if won else ("YOU WERE OUT." if downed.has("Player") else "TIME. SOME OF THEM SURVIVED."))
			)
			if won:
				Career.add("nerf_elim_wins")
		"hide":
			won = not hide_found and hide_t >= float(Modes.arena_for(arena).secs) - 1.5
			Career.best("nerf_hide_best", int(hide_t))
			line = ("HIDE AND SEEK: UNSEEN FOR %d SECONDS!" if won else "HIDE AND SEEK: FOUND AFTER %d SECONDS.") % int(hide_t)
			if won:
				Career.add("nerf_hide_wins")
	if won:
		Career.add("nerf_mode_wins")
	mode_result = {"id": mode, "arena": arena, "won": won, "line": line, "cups": cups, "rival": cups_rival, "secs": int(hide_t)}
	last_result["mode"] = mode_result
	Hints.toast(line, 5.0)
	_clear_mode()
func _end_war() -> void:
	war_t = 0.0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and str(npc.held) == "nerf":
			npc.give_item("")
	var s := war_result()
	last_result = s
	Career.add("nerf_wars")
	var msg := "NERF WAR OVER: YOU HIT %d, THEY GOT YOU %d" % [war_hits, war_taken]
	if not s.titles.is_empty():
		msg += ". " + ", ".join(PackedStringArray(s.titles))
	Hints.toast(msg, 5.0)
	_end_mode()
	if Campaign.active:
		Social.change_all(1)


# the score card of a war: hits, taken, dodged (you), missed (they), friendly fire, assists, longest hit (px), titles
func war_result() -> Dictionary:
	var s := {
		"hits": war_hits,
		"taken": war_taken,
		"dodged": war_dodged,
		"missed": war_missed,
		"ff": war_ff,
		"assists": war_assists,
		"longest": war_longest,
	}
	s["titles"] = war_titles(s)
	return s


func war_titles(s: Dictionary) -> Array:
	var out := []
	if int(s.dodged) >= 3:
		out.append("MOST DUCKED")
	if int(s.longest) >= 150:
		out.append("SNIPER")
	if int(s.ff) >= 3:
		out.append("FRIENDLY FIRE")
	if int(s.assists) >= 2:
		out.append("TEAM PLAYER")
	if int(s.hits) >= 5 and int(s.taken) == 0:
		out.append("UNTOUCHABLE")
	return out


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if charging:
		_update_charge(delta)
	if war_t <= 0.0:
		return
	war_t -= delta
	if war_t <= 0.0 or _scene() == null or _mode_ends(delta):
		_end_war()
		return
	for npc in get_tree().get_nodes_in_group("npcs"):
		var who := str(npc.cast_name)
		if npc.get("_hidden") == true or not _shot_t.has(who) or str(npc.held) != "nerf":
			continue
		_shot_t[who] = float(_shot_t[who]) - delta
		if float(_shot_t[who]) <= 0.0:
			_shot_t[who] = Difficulty.rng("nerf").randf_range(2.0, 4.5) * Difficulty.f("nerf.gap")
			_npc_shoots(npc)


func _npc_shoots(npc: Node) -> void:
	var targets := []
	var p := _player()
	if p != null:
		targets.append(p)
	for other in get_tree().get_nodes_in_group("npcs"):
		if other != npc and other.get("_hidden") != true:
			targets.append(other)
	if targets.is_empty():
		return
	var rng := Difficulty.rng("nerf")
	if mode == "hide":
		if stunned > 0.0:
			return
		_shot_t[str(npc.cast_name)] = rng.randf_range(float(Modes.SEEKER_GAP[0]), float(Modes.SEEKER_GAP[1])) * Difficulty.f("nerf.gap")
		if p != null:
			targets = [p]
	elif mode == "cup" and cup_node != null and rng.randf() < 0.4:
		_npc_fire_at(npc, cup_x)
		return
	elif mode == "elim":
		targets = targets.filter(func(t: Node) -> bool: return not downed.has(str(t.get("cast_name"))))
		if targets.is_empty():
			return
	var target: Node = Difficulty.pick(targets, "nerf")
	var dx: float = target.global_position.x - npc.global_position.x
	var dir := 1.0 if dx >= 0.0 else -1.0
	if npc.seat == null:
		npc.facing = "right" if dir > 0.0 else "left"
		npc._play("idle")
	# lob it when the target is far away
	fire_npc(npc, dir, clampf((absf(dx) - 110.0) / 200.0, 0.0, 1.0))


func gone(dart: Node) -> void:
	# a dart that came to rest on the floor can be collected
	var p := _player()
	if (
		p != null
		and str(p.held) == "nerf"
		and ammo < MAX_AMMO
		and absf(p.global_position.x - dart.global_position.x) < 10.0
	):
		ammo += 1
		dart.queue_free()
