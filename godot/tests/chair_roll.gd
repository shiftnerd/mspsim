extends SceneTree
# gdlint:disable=max-line-length
# Rolling desk chairs (R12 part a): Shift + A / D while seated rolls the chair with momentum and friction, it stops at the
# wall and the desk, the seated pose follows, a plain move key still stands you up, coworkers flinch and react (Alan -1,
# friends +1, cold -2, rate limited), campaigns get a little energy, a sticky wheel is seeded, an empty chair rolls home.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _hold(left: bool, run: bool, frames: int) -> void:
	if run:
		Input.action_press("run")
	Input.action_press("move_left" if left else "move_right")
	await _wait(frames)
	Input.action_release("move_left" if left else "move_right")
	Input.action_release("run")


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var social := root.get_node("Social")
	var shift := root.get_node("Shift")
	var game := root.get_node("Game")
	game.title_mode = false
	c.save_prefix = "user://test_chairroll_%d_" % OS.get_process_id()
	c.new_game("tech")
	c.day = 3
	world.time_scale = 1.0
	for who in ["Alan", "Dan"]:
		world.chars[who].scene = "main_floor"
		world.force_activity(who, "work")
	# Maya owns Seat2 and John, Garrison have desks nearby: keep them at work elsewhere so nobody takes the chair mid-test
	for who in ["Maya", "Garrison", "John"]:
		if world.chars.has(who):
			world.chars[who].scene = "office_two"
			world.force_activity(who, "work")
	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(40)
	var scene := current_scene
	var p := scene.get_node("Actors/Player")
	var seat := scene.get_node("Interactables/Seat2")
	var roll: Node = p._roll
	_check(roll != null, "the player has a rolling component")
	p.global_position = Vector2(seat.global_position.x, 118)
	await _wait(5)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(120)
	_check(p.state == "sitting", "seated at Seat2 (%s)" % p.state)
	var home: float = seat.position.x

	# plain A / D (no Shift) stands you up, as before
	await _hold(true, false, 3)
	await _wait(80)
	_check(p.state == "idle" and p.seat == null, "a plain move key still stands you up (%s)" % p.state)
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(120)
	_check(p.state == "sitting", "seated again")

	# Shift + A rolls: momentum, the pose and the seat follow
	await _hold(true, true, 30)
	_check(p.state == "sitting" and p.seat == seat, "Shift + A keeps you seated (%s)" % p.state)
	_check(roll.off < -10.0, "the chair rolled left (off %.1f)" % roll.off)
	_check(
		is_equal_approx(p.global_position.x, seat.global_position.x) and is_equal_approx(roll.chair.position.x, seat.position.x - 15.0),
		"the player, the seat and the chair sprite move together"
	)
	_check(str(p.sprite.animation).begins_with("sit_"), "the seated pose is the sit pose while rolling (%s)" % p.sprite.animation)
	var off_release: float = roll.off
	_check(absf(roll.vel) > 5.0, "it keeps coasting after you let go (v %.1f)" % roll.vel)
	await _wait(10)
	_check(roll.off < off_release - 1.0, "momentum carried it further (%.1f to %.1f)" % [off_release, roll.off])
	await _wait(120)
	_check(absf(roll.vel) < 0.5, "friction stops it")

	# a rolled chair still reaches its own desk phone: reach is measured from the chair's desk spot
	var own_phone: Node = null
	for zone in get_nodes_in_group("phones"):
		var pdx: float = zone.global_position.x - (seat.global_position.x - roll.off)
		if pdx > 20.0 and pdx < 70.0:
			own_phone = zone
	_check(own_phone != null, "your desk phone is in reach of the desk spot, not the rolled seat (off %.1f)" % roll.off)

	# the walls and props: it never leaves [lo, hi]
	_check(roll.lo <= -20.0 and roll.lo >= -80.0, "there is room to back away from the desk (lo %.1f)" % roll.lo)
	_check(roll.hi <= 8.0, "the chair cannot be driven through its own desk (hi %.1f)" % roll.hi)
	await _hold(true, true, 240)
	_check(roll.off >= roll.lo - 0.01 and roll.off <= roll.lo + 3.0, "it stops at the next desk (off %.1f, lo %.1f)" % [roll.off, roll.lo])
	await _hold(false, true, 300)
	_check(roll.off <= roll.hi + 0.01 and roll.off >= roll.hi - 3.0, "and at its own desk on the way back (off %.1f, hi %.1f)" % [roll.off, roll.hi])
	await _wait(60)

	# bumping coworkers
	var alan := scene.get_node_or_null("Actors/Alan")
	var dan := scene.get_node_or_null("Actors/Dan")
	_check(alan != null and dan != null, "Alan and Dan are in the room")
	for n in [alan, dan]:
		if n.seat != null:
			n.seat.occupied = false
			n.seat = null
		n._hold = 0.0
	roll.off = -30.0
	roll._place()
	p.global_position.x = seat.global_position.x
	var cx: float = roll.chair.position.x + 9.0
	social.rel["Alan"] = 0
	social.rel["Dan"] = 0
	alan.global_position.x = cx + 8.0
	dan.global_position.x = cx - 8.0
	alan.global_position.y = seat.global_position.y  # a walking coworker may be off the desk row
	dan.global_position.y = seat.global_position.y
	roll._gap = 0.0
	roll.vel = 40.0
	roll.update(p, 0.001)
	_check(roll.bumps == 1 and roll.vel < 0.0, "rolling into Alan bumps him and bounces back")
	_check(social.value("Alan") == -1, "Alan: not at my desk (-1, now %d)" % social.value("Alan"))
	roll.vel = 40.0
	roll.update(p, 0.001)
	_check(roll.bumps == 1, "bumps are rate limited (3 s)")
	roll._gap = 0.0
	roll._who = {}
	social.rel["Alan"] = -40
	alan.global_position.x = roll.chair.position.x + 9.0 + 8.0
	roll.vel = 40.0
	roll.update(p, 0.001)
	_check(social.value("Alan") == -42, "a cold coworker takes it worse (-2, now %d)" % social.value("Alan"))
	roll._gap = 0.0
	social.rel["Dan"] = 50
	dan.global_position.x = roll.chair.position.x + 9.0 - 8.0
	roll.vel = -40.0
	roll.update(p, 0.001)
	_check(social.value("Dan") == 51, "a friend laughs (+1, now %d)" % social.value("Dan"))
	roll._gap = 0.0
	roll.vel = -40.0
	roll.update(p, 0.001)
	_check(social.value("Dan") == 51, "the same person is not charged twice in 25 s")
	alan.global_position.x = 20.0
	dan.global_position.x = 20.0

	# stress relief in a campaign: +1 energy for every 160 px, 3 a day
	shift.energy = 50.0
	roll._px = 159.9
	await _hold(true, true, 20)
	_check(shift.energy >= 51.0, "rolling relieves stress in a campaign (energy %.1f)" % shift.energy)
	var rep: int = c.rep
	for i in 6:
		roll._px = 159.9
		await _hold(i % 2 == 0, true, 10)
	_check(shift.energy <= 53.01, "at most 3 energy a day (energy %.1f)" % shift.energy)
	_check(c.rep == rep, "no reputation effects")

	# stand up with E (away from the monitor, E there opens the computer as always): never trapped, the chair rolls home
	await _hold(true, true, 240)
	var off_now: float = roll.off
	var chair_node: Node2D = roll.chair
	# a ringing desk phone would be answered with E (it is in reach from the desk spot); this check is about standing up
	for zone in get_nodes_in_group("phones"):
		zone.remove_from_group("phones")
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(60)
	_check(p.state == "idle" and p.seat == null, "E stands you up while rolled away (%s)" % p.state)
	_check(absf(p.global_position.x - seat.global_position.x) < 2.0, "you stand at the chair (player %.1f, seat %.1f, state %s)" % [p.global_position.x, seat.global_position.x, p.state])
	p.global_position.x = 40.0
	await _wait(120)
	_check(absf(chair_node.position.x - 198.0) < 0.6, "the empty chair rolled back to its desk (%.1f)" % chair_node.position.x)
	_check(absf(seat.position.x - home) < 0.6, "and so did its seat (%.1f, home %.1f)" % [seat.position.x, home])
	_check(off_now != 0.0, "(it had been rolled away)")

	# a sticky wheel is seeded: same chair, same day, same answer; some chairs on some days
	var sticky := 0
	var same := true
	root.get_node("Difficulty").seed_run(4242)  # the roll hangs on the run's seed; an unseeded process would sometimes land outside 3..25
	for d in range(1, 61):
		c.day = d
		roll._release()
		roll.bind(seat)
		var first: int = roll.sticky
		roll._release()
		roll.bind(seat)
		same = same and roll.sticky == first
		sticky += 1 if first != 0 else 0
	_check(same, "a chair's sticky wheel is the same all day")
	_check(sticky >= 3 and sticky <= 25, "a few chairs in 60 days have a sticky wheel (%d)" % sticky)
	roll.sticky = 1
	roll.vel = 0.0
	var cap: float = roll.MAX_SPEED * roll.STICKY_MAX
	p.seat = seat
	for i in 120:
		roll.drive(p, 1.0, 0.016)
	_check(absf(roll.vel) <= cap + 0.01, "a sticky wheel is slower (top speed %.1f)" % roll.vel)
	p.seat = null
	roll._release()

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
