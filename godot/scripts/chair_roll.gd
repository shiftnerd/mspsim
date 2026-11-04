extends Node
# gdlint:disable=max-line-length
# Rolling desk chairs (roadmap R12 part a). The player node owns one of these. While you are seated, HOLD SHIFT and
# press A / D (or the arrows) to scoot the chair: it speeds up, coasts and slows down on its own, stops at the wall,
# the desk and the props next to it, and bumps into coworkers (they flinch; friends laugh +1, Alan -1 "not at my
# desk", a cold coworker -2, at most one bump every 3 s and one opinion change per person every 25 s). Your seated
# pose follows the chair. A plain move key or E stands you up exactly as before (nothing here can trap you), and an
# empty chair that was rolled away slides back to its desk after a while. Some chairs have a sticky wheel (seeded
# per chair and day): slower, and it pulls to one side. In a campaign rolling relieves a little stress (+1 energy
# for each 160 px, at most 3 a day); there are no reputation effects. Free Play works the same (opinions are
# only recorded in campaigns, as everywhere else).
# The chair is the Sprite2D "chair_office*" next to the seat; the seat (Area2D) moves with it.

const ACCEL := 150.0  # px/s^2 while the key is held
const MAX_SPEED := 60.0
const FRICTION := 46.0  # px/s^2 once you let go
const STICKY_MAX := 0.6  # x top speed with a sticky wheel
const STICKY_PULL := 14.0  # px/s^2 sideways drift of a sticky wheel
const STICKY_CHANCE := 0.18
const BUMP_SPEED := 14.0
const BUMP_GAP := 3.0  # seconds between two bumps
const BUMP_WHO_MS := 25000  # one opinion change per person in this time
const HOME_AFTER := 10.0  # seconds before an empty chair rolls back (or at once when you walk off)
const HOME_SPEED := 70.0
const RELIEF_PX := 160.0
const RELIEF_MAX := 3
const CHAIR_W := 18.0
const SEAT_DX := 15.0  # the seat sits this far from the chair sprite's left edge
const BLOCKERS := [
	"desk_", "copier", "cooler", "plant_", "filing", "couch", "conference_table", "chair_", "cabinet", "shelf", "fridge", "table"
]
const REACT := {
	"Alan": {"base": -1, "line": "ALAN: NOT AT MY DESK, PLEASE."},
	"Garrison": {"base": 0, "line": "GARRISON: NICE WHEELS. WATCH THE KNEES."},
	"Maya": {"base": 0, "line": "MAYA: HEY! MY GRANOLA BAR!"},
	"Dan": {"base": 0, "line": "DAN: OKAY, THAT WAS A GOOD ROLL."},
	"Vic": {"base": 0, "line": "VIC: CAREFUL, I HAVE A CALL AT TWO!"},
	"Morgan": {"base": 0, "line": "MORGAN: I WILL PRETEND I DID NOT SEE THAT."},
}

static var _relief_day := -1
static var _relief_n := 0
static var _told := {}

var seat: Node2D = null
var chair: Sprite2D = null
var off := 0.0  # how far the chair is from its desk spot (px, + = right)
var vel := 0.0
var lo := 0.0  # the room it has: off stays in [lo, hi]
var hi := 0.0
var sticky := 0  # 0, or -1 / +1: the side a sticky wheel pulls to
var bumps := 0  # coworkers bumped since you sat down
var rolled := 0.0  # px rolled since you sat down

var _home_seat := 0.0
var _home_chair := 0.0
var _idle := 0.0
var _gap := 0.0
var _squeak := 0.0
var _who := {}
var _px := 0.0


# the chair that belongs to a seat, and how far it may roll; false = this seat has no rolling chair
func bind(s: Node2D) -> bool:
	if s == seat and is_instance_valid(chair):
		return true
	_release()
	seat = s
	if s == null or not s.is_inside_tree():
		return false
	var scene := s.get_tree().current_scene
	var actors := scene.get_node_or_null("Actors") if scene != null else null
	if actors == null:
		return false
	var want: float = s.position.x - SEAT_DX
	for c in actors.get_children():
		if (
			c is Sprite2D
			and str(c.name).begins_with("chair_office")
			and c.texture != null
			and absf(c.position.x - want) < 6.0
			and absf(c.position.y - (s.position.y - 6.0)) < 8.0
		):
			chair = c
			break
	if chair == null:
		return false
	_home_seat = s.position.x
	_home_chair = chair.position.x
	off = 0.0
	vel = 0.0
	rolled = 0.0
	bumps = 0
	_px = 0.0
	_idle = 0.0
	_limits(scene, actors)
	_roll_sticky(scene)
	return true


func _limits(scene: Node, actors: Node) -> void:
	var x0 := chair.position.x
	var x1 := x0 + CHAIR_W
	lo = -1000.0
	hi = 1000.0
	var wl := scene.get_node_or_null("WallLeft")
	var wr := scene.get_node_or_null("WallRight")
	if wl != null:
		lo = maxf(lo, wl.position.x + 5.0 - x0)
	if wr != null:
		hi = minf(hi, wr.position.x - 5.0 - x1)
	for c in actors.get_children():
		if c == chair or not (c is Sprite2D) or c.texture == null:
			continue
		var cname := str(c.name)
		var blocks := false
		for prefix in BLOCKERS:
			if cname.begins_with(prefix):
				blocks = true
		if not blocks:
			continue
		var bx: float = c.position.x
		var bw: float = c.texture.get_width()
		if bx < x1 and bx + bw > x0:
			# the chair's own desk (or anything it already overlaps): you may push in a little
			if bx + bw * 0.5 > x0 + CHAIR_W * 0.5:
				hi = minf(hi, 6.0)
			else:
				lo = maxf(lo, -6.0)
		elif bx + bw <= x0:
			lo = maxf(lo, bx + bw - x0)
		else:
			hi = minf(hi, bx - x1)
	lo = minf(lo, 0.0)
	hi = maxf(hi, 0.0)


# a sticky wheel: a seeded roll per chair and day, the same chair is the same all day
func _roll_sticky(scene: Node) -> void:
	sticky = 0
	var day := Campaign.day if Campaign.active else 0
	var key := "%s/%s" % [scene.name, seat.name]
	var r := Difficulty.rng_for("chair.sticky", day * 1009 + absi(key.hash()) % 1009)
	if r.randf() < STICKY_CHANCE:
		sticky = 1 if r.randf() < 0.5 else -1


# every physics frame (the player calls it): friction, walls, the chair and the seated pose follow, rolling home
func update(p: Node, delta: float) -> void:
	if seat == null:
		return
	if not is_instance_valid(seat) or not is_instance_valid(chair):
		_forget()
		return
	var seated: bool = p.seat == seat
	_gap = maxf(0.0, _gap - delta)
	_squeak = maxf(0.0, _squeak - delta)
	if not seated:
		_empty(p, delta)
		return
	vel = move_toward(vel, 0.0, FRICTION * delta)
	if sticky != 0 and absf(vel) > 4.0:
		vel += float(sticky) * STICKY_PULL * delta
	_move(vel * delta)
	_place()
	p.global_position.x = seat.global_position.x
	_pose(p)
	if absf(vel) > BUMP_SPEED and _gap <= 0.0:
		_bump(p)


# Shift + A / D while seated: returns false when this seat has no rolling chair (then the key stands you up)
func drive(p: Node, dir: float, delta: float) -> bool:
	if p.seat == null or not bind(p.seat):
		return false
	var cap := MAX_SPEED * (STICKY_MAX if sticky != 0 else 1.0)
	if absf(vel) < 5.0 and _squeak <= 0.0:
		_squeak = 2.5
		Hints.toast("SQUEAK!", 0.9)
		Sfx.play("squeak")
		if sticky != 0:
			_tell()
	vel = clampf(vel + dir * ACCEL * delta, -cap, cap)
	_idle = 0.0
	return true


func _tell() -> void:
	var key := "%s/%s/%d" % [get_tree().current_scene.name, seat.name, Campaign.day]
	if not _told.has(key):
		_told[key] = true
		Hints.toast("STICKY WHEEL. THIS CHAIR PULLS TO ONE SIDE.", 3.0)


func _move(step: float) -> void:
	var target := off + step
	var clamped := clampf(target, lo, hi)
	if clamped != target:
		if absf(vel) > 20.0:
			Hints.toast("CLUNK.", 0.8)
			Sfx.play("clunk")
			vel = -vel * 0.25
		else:
			vel = 0.0
	rolled += absf(clamped - off)
	_px += absf(clamped - off)
	off = clamped
	if _px >= RELIEF_PX:
		_px -= RELIEF_PX
		_relieve()


func _place() -> void:
	chair.position.x = _home_chair + off
	seat.position.x = _home_seat + off


func _pose(p: Node) -> void:
	if p.state != "sitting" or not seat.typing:
		return
	var want := "sit" if (absf(off) > 3.0 or absf(vel) > 4.0) else "type"
	if want == "type" and p.gesturing():
		return  # an idle gesture is playing (seated life); it hands back to type when it ends
	if not str(p.sprite.animation).begins_with(want + "_"):
		p._play(want)


func _relieve() -> void:
	if not Campaign.active:
		return
	if _relief_day != Campaign.day:
		_relief_day = Campaign.day
		_relief_n = 0
	if _relief_n < RELIEF_MAX:
		_relief_n += 1
		Shift.add_energy(1.0)
		Hints.toast("WHEEE. THAT HELPED A LITTLE.", 2.0)


# the first coworker the chair runs into: they flinch, the chair bounces back
func _bump(p: Node) -> void:
	var cx := chair.position.x + CHAIR_W * 0.5
	for n in get_tree().get_nodes_in_group("npcs"):
		if not n.has_method("react_hit") or not n.visible or n == p:
			continue
		var raw: Variant = n.get("cast_name")
		var who := str(raw) if raw != null else ""
		if who == "":
			continue
		var dx: float = n.global_position.x - cx
		if absf(dx) > 12.0 or dx * vel <= 0.0:
			continue
		if absf(n.global_position.y - seat.global_position.y) > 30.0:
			continue
		vel = -vel * 0.3
		_gap = BUMP_GAP
		bumps += 1
		Sfx.play("clunk")
		var change := 0
		var glyph := "!"
		var react: Dictionary = REACT.get(who, {"base": 0, "line": "%s: WATCH IT!" % who.to_upper()})
		var now := Time.get_ticks_msec()
		var fresh: bool = now - int(_who.get(who, -BUMP_WHO_MS * 2)) >= BUMP_WHO_MS
		var line := str(react.line)
		if Social.is_cold(who) or Social.is_hostile(who):
			change = -2
			line = "%s GLARES AT YOU." % who.to_upper()
		elif Social.is_friendly(who):
			change = 1
			glyph = "heart"
			line = "%s LAUGHS. WHEEE!" % who.to_upper()
		else:
			change = int(react.base)
		if fresh:
			_who[who] = now
			Social.change(who, change)
		n.react_hit(glyph)
		Hints.toast(line, 2.6)
		return


# you stood up: the chair coasts to a stop, then rolls back to its desk
func _empty(p: Node, delta: float) -> void:
	if off == 0.0 and vel == 0.0:
		_forget()
		return
	if bool(seat.get("occupied")):
		snap_home()
		return
	vel = move_toward(vel, 0.0, FRICTION * delta)
	_move(vel * delta)
	if absf(vel) < 1.0:
		_idle += delta
		var far: bool = absf(p.global_position.x - chair.position.x) > 70.0
		if _idle >= HOME_AFTER or far:
			off = move_toward(off, 0.0, HOME_SPEED * delta)
	_place()
	if off == 0.0:
		vel = 0.0


func snap_home() -> void:
	off = 0.0
	vel = 0.0
	if is_instance_valid(chair) and is_instance_valid(seat):
		_place()


func _release() -> void:
	snap_home()
	_forget()


func _forget() -> void:
	seat = null
	chair = null
	off = 0.0
	vel = 0.0
	sticky = 0
