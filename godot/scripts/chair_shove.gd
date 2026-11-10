extends Node
# gdlint:disable=max-line-length
# CHAIR SHOVE (roadmap R12): standing up, you push a seated coworker's rolling chair. Stand next to their chair, HOLD SHIFT (run)
# and press E (interact): the chair rolls away from you with them in it, coasts, stops at the wall, the desk and the props (the
# rolling chair's own limits, chair_roll.gd), and after a moment they scoot back to the desk. They react like a coworker you
# bumped with your own chair: a friend laughs (+1), a cold one glares (-2), Alan minds (-1), the rest have a line; at most one
# opinion change per person every 25 s. Plain E still talks to them. Every push counts for the Career (PUSHY at 10).
# The node lives under the seat while the chair is away from its desk and frees itself when it is home again or the coworker
# stands up (then the chair snaps home, as an empty rolled chair does when somebody else takes it).

const CHAIR_ROLL := preload("res://scripts/chair_roll.gd")
const REACH := 30.0  # px between you and the seat
const SHOVE := 64.0  # px/s the chair leaves your hands at
const HOME_AFTER := 3.0  # seconds it stands still before they scoot back
const HOME_SPEED := 38.0
const WHO_MS := 25000  # one opinion change per person in this time
const REACT := {
	"Alan": {"base": -1, "line": "ALAN: I HAD A CHANGE WINDOW OPEN. IT IS CLOSED NOW."},
	"Garrison": {"base": 0, "line": "GARRISON: AGAIN! FASTER THIS TIME!"},
	"Maya": {"base": 0, "line": "MAYA: HEY! I WAS MID-SENTENCE!"},
	"Dan": {"base": 0, "line": "DAN: ...AND I AM BACK. GOOD PUSH."},
	"John": {"base": 0, "line": "JOHN: I AM ON A CALL! (HE IS NOT.)"},
	"Morgan": {"base": 0, "line": "MORGAN: THIS IS GOING IN YOUR REVIEW."},
}

static var _who := {}  # cast name -> ticks of the last opinion change

var seat: Node2D = null
var npc: Node2D = null
var roll: Node = null  # a chair_roll.gd bound to the seat: the chair, how far it may go, the walls
var pushes := 0

var _idle := 0.0


# Shift + E next to an occupied rolling chair (player.gd). false = nothing to push here: the E goes on to whatever is nearest
static func try_shove(p: Node) -> bool:
	if not p.is_inside_tree():
		return false
	var best: Node2D = null
	var best_d := REACH
	for n in p._near:
		if not is_instance_valid(n) or n.get("occupied") != true:
			continue
		var d: float = absf(n.global_position.x - p.global_position.x)
		if d <= best_d:
			best_d = d
			best = n
	if best == null:
		return false
	var sitter := _sitter(p.get_tree(), best)
	if sitter == null:
		return false
	var node: Node = best.get_node_or_null("ChairShove")
	if node == null:
		node = new()
		node.name = "ChairShove"
		best.add_child(node)
		if not node.begin(best, sitter):
			best.remove_child(node)
			node.queue_free()
			return false
	var dir := signf(best.global_position.x - p.global_position.x)
	if dir == 0.0:
		dir = 1.0 if str(p.facing) == "right" else -1.0
	node.kick(dir)
	_react(sitter)
	Career.note_shove()
	p.reach(best.global_position.x)
	return true


# the coworker in this seat (somebody on a call, in a conversation or hidden is left alone)
static func _sitter(tree: SceneTree, s: Node) -> Node2D:
	for n in tree.get_nodes_in_group("npcs"):
		if n.get("seat") == s and n.visible and not bool(n.get("_hidden")) and float(n.get("_hold")) <= 0.0 and str(n.get("role")) == "":
			return n
	return null


static func _react(n: Node) -> void:
	var who := str(n.get("cast_name"))
	var glyph := "!"
	var line := "%s: HEY!" % (who.to_upper() if who != "" else "THEY")
	if who == "":
		n.react_hit(glyph)
		Hints.toast("WHEELS. THEY DID NOT ASK FOR THAT.", 2.2)
		return
	var react: Dictionary = REACT.get(who, {"base": 0, "line": line})
	var change := int(react.base)
	line = str(react.line)
	if Social.is_cold(who) or Social.is_hostile(who):
		change = -2
		line = "%s GLARES AT YOU FROM ACROSS THE ROOM." % who.to_upper()
	elif Social.is_friendly(who):
		change = 1
		glyph = "heart"
		line = "%s LAUGHS. WHEEE!" % who.to_upper()
	var now := Time.get_ticks_msec()
	if now - int(_who.get(who, -WHO_MS * 2)) >= WHO_MS:
		_who[who] = now
		Social.change(who, change)
	n.react_hit(glyph)
	Hints.toast(line, 2.6)


# take hold of the seat's chair; false when this seat has no rolling chair (a couch, a booth)
func begin(s: Node2D, sitter: Node2D) -> bool:
	seat = s
	npc = sitter
	roll = CHAIR_ROLL.new()
	add_child(roll)
	return roll.bind(s)


func kick(dir: float) -> void:
	roll.vel = dir * SHOVE * (CHAIR_ROLL.STICKY_MAX if roll.sticky != 0 else 1.0)
	pushes += 1
	_idle = 0.0
	Sfx.play("squeak")
	if npc != null and npc.has_method("_play"):
		npc._play("sit")  # hands off the keyboard while the chair is moving


func rolling() -> bool:
	return roll != null and (absf(roll.vel) > 1.0 or roll.off != 0.0)


func _physics_process(delta: float) -> void:
	if roll == null or not is_instance_valid(seat) or not is_instance_valid(roll.chair):
		queue_free()
		return
	if not is_instance_valid(npc) or npc.get("seat") != seat:
		_done(false)  # they stood up (or left): the chair is back at its desk
		return
	roll.vel = move_toward(roll.vel, 0.0, CHAIR_ROLL.FRICTION * delta)
	roll._px = 0.0  # (rolling somebody else relieves nobody's stress)
	roll._move(roll.vel * delta)
	if absf(roll.vel) < 1.0:
		_idle += delta
		if _idle >= HOME_AFTER:
			roll.off = move_toward(roll.off, 0.0, HOME_SPEED * delta)
	else:
		_idle = 0.0
	roll._place()
	npc.global_position.x = seat.global_position.x
	if roll.off == 0.0 and absf(roll.vel) < 1.0:
		_done(true)


func _done(seated: bool) -> void:
	roll.snap_home()
	if seated and is_instance_valid(npc):
		npc.global_position.x = seat.global_position.x
		if npc.has_method("_refresh") and float(npc.get("_hold")) <= 0.0:
			npc._refresh()  # back to typing
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
