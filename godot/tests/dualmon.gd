extends SceneTree
# R25: every desk has TWO monitors side by side (A 4:3 + B 16:9). E (standing or seated) still opens the same single
# computer (only A has an interact zone), and both screens go offline together when the desk loses its network.

const ROOMS := [
	"main_floor",
	"cubicle_area",
	"office_one",
	"office_two",
	"conference",
	"site_realty_a",
	"site_realty_b",
	"site_trailer_a",
	"site_trailer_b",
]
const BLOCK := 14

var frame := 0
var failures := 0
var desks_seen := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _kids(prefix: String) -> Array:
	var out := []
	for c in current_scene.get_node("Actors").get_children():
		if str(c.name).begins_with(prefix):
			out.append(c)
	return out


# the monitor's feet (bottom of its art) rest on the desk's top edge
func _stands_on(m: Sprite2D, d: Sprite2D) -> bool:
	var feet: float = m.position.y + m.offset.y + float(m.texture.get_height())
	return absf(feet - (d.position.y + d.offset.y + 2.0)) <= 2.0


func _audit(room: String) -> void:
	var desks := _kids("desk_cubicle_74_")
	var mon_a := _kids("monitor_a_")
	var bs := _kids("monitor_b_")
	desks_seen += desks.size()
	_check(mon_a.size() == desks.size() and bs.size() == desks.size(), "%s: %d desks, %d A + %d B" % [room, desks.size(), mon_a.size(), bs.size()])
	for d in desks:
		var found_a := 0
		var found_b := 0
		for m in mon_a:
			var dx: float = m.position.x - d.position.x
			if dx > 15.0 and dx < 30.0 and _stands_on(m, d):
				found_a += 1
		for m in bs:
			var dx: float = m.position.x - d.position.x
			if dx > 34.0 and dx < 45.0 and _stands_on(m, d):
				found_b += 1
		_check(found_a == 1 and found_b == 1, "%s: the desk at x%d has one A and one B standing on it" % [room, int(d.position.x)])
	# interact zones: A only (B never steals E), at most one computer per desk
	var zones_a := 0
	for z in current_scene.get_node("Interactables").get_children():
		if z.get("target") == null or not z.has_node(z.target):
			continue
		var fx: Node = z.get_node(z.target)
		if fx.kind == "monitor" and fx.panel == 2:
			failures += 1
			print("FAIL %s: a zone targets monitor B (%s)" % [room, z.name])
		if fx.kind == "monitor" and fx.panel == 1:
			zones_a += 1
			_check(z.is_in_group("computers"), "%s: A's zone is a computer zone" % room)
	_check(zones_a == mon_a.size(), "%s: one computer zone per desk" % room)
	for m in mon_a:
		_check(m.get_node("Fx").panel == 1 and m.get_node("Fx").kind == "monitor", "%s: A is a monitor fx, panel 1" % room)
	for m in bs:
		_check(m.get_node("Fx").panel == 2 and m.get_node("Fx").kind == "monitor", "%s: B is a monitor fx, panel 2" % room)
	# the two screens of an office desk share the patch panel port
	if room in ["main_floor", "cubicle_area", "office_one", "office_two"]:
		for i in mon_a.size():
			_check(
				mon_a[i].get_node("Fx").desk > 0 and mon_a[i].get_node("Fx").desk == bs[i].get_node("Fx").desk,
				"%s: desk %d feeds both screens" % [room, mon_a[i].get_node("Fx").desk]
			)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null or frame < 20:
		return false
	var f := frame - 20
	var k := int(f / float(BLOCK))
	if k < ROOMS.size():
		match f % BLOCK:
			0:
				change_scene_to_file("res://scenes/%s.tscn" % ROOMS[k])
			8:
				_audit(ROOMS[k])
		return false
	var seq := f - ROOMS.size() * BLOCK
	var net := root.get_node("Net")
	var comp := root.get_node("Computer")
	match seq:
		0:
			change_scene_to_file("res://scenes/main_floor.tscn")
		8:
			_check(desks_seen >= 8, "every office desk was audited (%d)" % desks_seen)
			for c in current_scene.get_node("Actors").get_children():
				if "routine" in c:
					c.queue_free()
			current_scene.get_node("Actors/Player").sit(current_scene.get_node("Interactables/Seat1"))
		70:
			var player := current_scene.get_node("Actors/Player")
			_check(player.state == "sitting", "seated at desk 1")
			var zone: Node = player._seat_computer()
			_check(zone != null and zone.get_node(zone.target).panel == 1, "the seated computer is monitor A's zone")
			Input.action_press("interact")
			Input.action_release("interact")
		90:
			_check(comp.is_open, "E opens the computer, once")
			comp.back()
			comp.back()
			net.pick("p1")  # desk 1's patch cable is out
		120:
			var states := []
			for m in _kids("monitor_"):
				var fx: Node = m.get_node("Fx")
				if fx.desk == 1:
					states.append(net.desk_state(fx.desk))
			_check(states.size() == 2 and states[0] != "ok" and states[1] != "ok", "both screens of desk 1 are offline: %s" % str(states))
			net.reset()
		130:
			print("failures=", failures)
			quit(1 if failures > 0 else 0)
	return false
