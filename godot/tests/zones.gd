extends SceneTree
# gdlint:disable=max-line-length
# MOVING SWEET SPOTS: the target of each skill check changes per attempt (bowling aim + power, cornhole aim + power, the grill's flip
# window per patty, the printer's pull zone), stays on its bar, keeps its width, and is a pure function of the seeded stream
# (same seed = same sequence; Free Play fixed_take restarts the streams).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/zones.gd

const Corn := preload("res://scripts/cornhole_game.gd")
const Grill := preload("res://scripts/grill_game.gd")

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _spread(list: Array) -> float:
	return float(list.max()) - float(list.min())


func _bowl(o: Node) -> Array:
	var out := []
	for i in 12:
		o._bowl_zone_roll()
		out.append([float(o.g.shift), float(o.g.pcen), o.bowl_center()])
	return out


func _corn(seed_n: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_n
	var zr := RandomNumberGenerator.new()
	zr.seed = seed_n + 1
	var g := Corn.new()
	g.setup({"to": 15, "zone_rng": zr}, ["Alan", "Dan"], r)
	var out := []
	for i in 12:
		g.roll_zone()
		out.append([g.aim_c, g.pow_c])
	return out


func _init() -> void:
	await process_frame
	var d := root.get_node("Difficulty")
	var o := root.get_node("Outings")
	d.settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	d.fixed_take = false

	# bowling
	d.seed_run(4242)
	o.start("bowling")
	o.press(KEY_ENTER)
	var a: Array = _bowl(o)
	var shifts: Array = a.map(func(x: Array) -> float: return x[0])
	var pcs: Array = a.map(func(x: Array) -> float: return x[1])
	_check(_spread(shifts) > 0.05 and _spread(pcs) > 0.05, "bowling: the aim zone and the power zone move between rolls")
	var inb := true
	var half: float = o.bowl_zone_width() * 0.5
	for x in a:
		inb = inb and float(x[2]) - half >= 0.0 and float(x[2]) + half <= 1.0 and float(x[1]) - 0.125 >= 0.0 and float(x[1]) + 0.05 <= 1.0
	_check(inb, "bowling: both zones stay fully on their bars")
	_check(is_equal_approx(o.bowl_zone_width(), 0.2), "bowling: the zone width is unchanged")
	d.seed_run(4242)
	o.start("bowling")
	o.press(KEY_ENTER)
	_check(_bowl(o) == a, "bowling: the same seed gives the same zones")
	d.seed_run(4243)
	o.start("bowling")
	o.press(KEY_ENTER)
	_check(_bowl(o) != a, "bowling: another seed gives other zones")
	# the drawn zone is the scored zone
	o.g.stage = "aim"
	o.g.spin = 0
	o.g.marker = o.bowl_center()
	o.g.power = float(o.g.pcen)
	o.bowl_strength()
	_check(float(o.g.acc) > 0.99, "bowling: aiming at the drawn green is perfect (%.3f)" % float(o.g.acc))
	d.fixed_take = true
	d.take_reset()
	o.start("bowling")
	o.press(KEY_ENTER)
	var f1: Array = [o.g.shift, o.g.pcen]
	d.take_reset()
	o.start("bowling")
	o.press(KEY_ENTER)
	_check([o.g.shift, o.g.pcen] == f1, "bowling: fixed_take restarts the stream, so a retake has the same zones")
	d.fixed_take = false

	# cornhole
	var c1: Array = _corn(7)
	_check(_corn(7) == c1 and _corn(8) != c1, "cornhole: seeded and repeatable")
	var aims: Array = c1.map(func(x: Array) -> float: return x[0])
	var pows: Array = c1.map(func(x: Array) -> float: return x[1])
	_check(_spread(aims) > 0.05 and _spread(pows) > 0.05, "cornhole: the aim and power zones move between bags")
	var ok := true
	var half_a: float = Corn.HOLE_R / Corn.AIM_SCALE
	var half_p: float = Corn.HOLE_R / Corn.POWER_SCALE
	for x in c1:
		ok = ok and float(x[0]) - half_a >= 0.0 and float(x[0]) + half_a <= 1.0 and float(x[1]) - half_p >= 0.0 and float(x[1]) + half_p <= 1.0
		ok = ok and Corn.spot(float(x[0]), float(x[1]), float(x[0]), float(x[1])).is_equal_approx(Vector2(Corn.HOLE_X, 0.0))
	_check(ok, "cornhole: zones stay on the bars and the drawn zone centre is the hole")
	var plain := Corn.new()
	var r0 := RandomNumberGenerator.new()
	plain.setup({"to": 15}, ["Alan"], r0)
	plain.roll_zone()
	_check(plain.aim_c == 0.5 and plain.pow_c == Corn.POWER_BEST, "cornhole: without a zone stream the classic place (old tests)")

	# grill
	var zr := RandomNumberGenerator.new()
	zr.seed = 11
	var r1 := RandomNumberGenerator.new()
	r1.seed = 5
	var g := Grill.new()
	g.setup({"window": 1.3, "dogs": 0.4, "zone_rng": zr}, ["A", "B"], r1)
	var los := []
	var wide := true
	var clear := true
	for k in 24:
		g.slots[k % 4] = g._fresh("dog" if k % 3 == 0 else "burger")
		var s: Dictionary = g.slots[k % 4]
		var base: Vector2 = g.flip_range(str(s.kind))
		var rr: Vector2 = g.flip_range(str(s.kind), float(s.woff))
		los.append(rr.x)
		wide = wide and is_equal_approx(rr.y - rr.x, base.y - base.x)
		clear = clear and rr.y < (Grill.DOG_BURN if s.kind == "dog" else Grill.BURN) and rr.x > 0.1
	_check(_spread(los) > 0.05, "grill: flip windows sit in different places")
	_check(wide and clear, "grill: the window keeps its width and stays clear of the burn line")
	var gp := Grill.new()
	gp.setup({}, ["A"], r1)
	_check(is_equal_approx(gp.flip_range().x, 0.35) and float(gp.slots[0].woff) == 0.0, "grill: no zone stream = the classic 0.35")

	# printer (already moved before this change)
	var pg := root.get_node("PrinterGame")
	d.seed_run(99)
	pg.start(Callable())
	var zs := []
	for i in 10:
		pg._new_zone()
		zs.append(pg.zone)
	_check(_spread(zs) > 0.1 and float(zs.min()) >= 0.22 and float(zs.max()) <= 0.78, "printer: the pull zone already moves per pull and stays on the bar")
	pg.is_open = false
	root.get_node("Game").ui_open = false
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
