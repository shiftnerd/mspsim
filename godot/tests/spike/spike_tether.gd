extends SceneTree
# THROWAWAY coop spike, risk 5 (docs/coop-risk-findings.md): the shared-camera tether math with two scripted players, at every
# format of Game.FORMATS and three room widths. Pure math (no scene): the proposed rule is
#   cam_x = midpoint of the players, clamped to the room limits (the room is centred when it fits the view);
#   every player is clamped to [cam - view/2 + margin, cam + view/2 - margin].
# Asserts: both always inside the view, separation <= view - 2*margin, camera inside the limits, and that two runners still
# cross a long room in a bounded time (nobody is stuck forever). Run: Godot --headless --path godot -s res://tests/spike/spike_tether.gd

const MARGIN := 10.0
const RUN := 90.0
const SMOOTH := 7.0  # stage.gd position_smoothing_speed
const DT := 1.0 / 60.0

var fails := 0


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print(("ok   " if c else "FAIL ") + what)


class Sim:
	var view := 320.0
	var room_l := 0.0
	var room_r := 368.0
	var cam := 160.0
	var x := [100.0, 120.0]
	var worst_sep := 0.0
	var outside := 0
	var cam_out := 0

	func target() -> float:
		var mid: float = (x[0] + x[1]) * 0.5
		if room_r - room_l <= view:
			return (room_l + room_r) * 0.5
		return clampf(mid, room_l + view * 0.5, room_r - view * 0.5)

	func step(v0: float, v1: float, margin: float) -> void:
		x[0] += v0 * DT
		x[1] += v1 * DT
		# smoothed camera, like Camera2D position_smoothing_speed 7
		cam += (target() - cam) * minf(1.0, SMOOTH * DT)
		var lo: float = cam - view * 0.5 + margin
		var hi: float = cam + view * 0.5 - margin
		if room_r - room_l <= view:  # the whole room is on screen: only the room limits tether
			lo = room_l + margin
			hi = room_r - margin
		for i in 2:
			x[i] = clampf(x[i], lo, hi)
		worst_sep = maxf(worst_sep, absf(x[0] - x[1]))
		for i in 2:
			if x[i] < cam - view * 0.5 or x[i] > cam + view * 0.5:
				outside += 1
		if cam - view * 0.5 < room_l - 0.01 and room_r - room_l > view:
			cam_out += 1
		if cam + view * 0.5 > room_r + 0.01 and room_r - room_l > view:
			cam_out += 1


func run_case(fmt: String, view: float, room: float) -> void:
	var s := Sim.new()
	s.view = view
	s.room_r = room
	s.x = [room * 0.25, room * 0.25 + 20.0]
	s.cam = s.target()
	# scenario 1: P1 sprints right 12 s while P2 stands still, then P2 sprints right and P1 sprints left 6 s
	for i in 720:
		s.step(RUN, 0.0, MARGIN)
	var sep1: float = s.worst_sep
	for i in 360:
		s.step(-RUN, RUN, MARGIN)
	# scenario 2: both run to the right end of the room (P2 starts 3 s late): how long until both are at the end
	var t := 0.0
	s.x = [room * 0.1, room * 0.1 + 20.0]
	s.cam = s.target()
	while (s.x[0] < room - MARGIN - 1.0 or s.x[1] < room - MARGIN - 1.0) and t < 120.0:
		s.step(RUN, RUN if t > 3.0 else 0.0, MARGIN)
		t += DT
	var cap: float = minf(view, room) - 2.0 * MARGIN
	var fits := room <= view
	var note := " (room fits the view: no scrolling)" if fits else ""
	print("INFO %-7s view=%3d room=%4d  max separation %.1f px (cap %.1f), scenario-2 crossing time %.1f s%s" % [fmt, int(view), int(room), s.worst_sep, cap, t, note])
	ok(s.outside == 0, "%s view %d room %d: both players always inside the visible rect" % [fmt, int(view), int(room)])
	ok(s.worst_sep <= cap + 0.6, "%s view %d room %d: separation never above view - 2*margin" % [fmt, int(view), int(room)])
	ok(s.cam_out == 0, "%s view %d room %d: camera never shows outside the room" % [fmt, int(view), int(room)])
	ok(t < 119.0, "%s view %d room %d: both reach the far end (%.1f s), nobody is stuck" % [fmt, int(view), int(room), t])
	# the leader is held, but only while the follower trails: with the follower idle the leader stops at cap
	ok(sep1 <= cap + 0.6, "%s: with P2 idle P1 was stopped %.1f px ahead (cap %.1f)" % [fmt, sep1, cap])


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	for fmt in game.ORDER:
		var f: Dictionary = game.FORMATS[fmt]
		var view: float = float(f.size.x) / float(f.zoom)
		for room in [368.0, 640.0, 1480.0]:
			run_case(fmt, view, room)
	print("failures=", fails)
	quit(1 if fails > 0 else 0)
