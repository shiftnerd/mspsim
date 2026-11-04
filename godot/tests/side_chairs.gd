extends SceneTree
# Chairs people sit in are SIDE views now (the sitter's sprite is side-on). Checks every set scene: each chair prop is a
# `_side` (facing right) or `_side_l` (facing left) piece, the front chair art is only left for the chair race, and every
# non-lounge seat in a room that has chairs has a chair prop right behind it (the backrest just left of the seat). Lounge seats (couch,
# bench, armchair; `stash = false`) sit in a side-view lounge piece too (`couch_side`, `bench_seat_side`, `chair_slipper_green_side`), or on
# a round bar stool (the same from every side); the front-view `couch` / `bench_seat` pieces are gone.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _scenes() -> Array:
	var out := []
	var dir := DirAccess.open("res://scenes")
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			out.append(f)
	out.sort()
	return out


func _initialize() -> void:
	var chairs_total := 0
	var lounge_checked := 0
	var seats_checked := 0
	for f in _scenes():
		var scene: Node = load("res://scenes/" + f).instantiate()
		var actors := scene.get_node_or_null("Actors")
		if actors == null:
			scene.free()
			continue
		var chairs := []
		var lounges := []
		for c in actors.get_children():
			if c is Sprite2D and c.texture != null:
				var t := str(c.texture.resource_path).get_file().get_basename()
				_check(t != "couch" and t != "bench_seat", "%s: %s is not a front-view couch or bench" % [f, c.name])
				if t in ["couch_side", "bench_seat_side", "chair_slipper_green_side"] or t.contains("stool"):
					lounges.append([c, t])
		for c in actors.get_children():
			var nm := str(c.name)
			if c is Sprite2D and nm.begins_with("chair_") and not nm.begins_with("chair_rack") and not nm.begins_with("chair_slipper"):
				chairs.append(c)
				var tex := str(c.texture.resource_path).get_file().get_basename()
				_check(tex.ends_with("_side") or tex.ends_with("_side_l"), "%s: %s is a side view (%s)" % [f, nm, tex])
		chairs_total += chairs.size()
		var inter := scene.get_node_or_null("Interactables")
		if inter != null:
			for s in inter.get_children():
				if str(s.name).begins_with("Seat") and s.get("stash") == false:
					lounge_checked += 1
					var lok := false
					for l in lounges:
						var ld: float = s.position.x - l[0].position.x
						if l[1].contains("stool"):
							lok = lok or (ld >= 3.0 and ld <= 11.0)
						else:
							lok = lok or (ld >= 10.0 and ld <= 16.0 and absf(l[0].position.y - s.position.y) < 14.0)
					_check(lok, "%s: lounge seat %s sits in a side-view piece or on a stool" % [f, s.name])

		if inter != null and not chairs.is_empty():
			for s in inter.get_children():
				if not str(s.name).begins_with("Seat") or s.get("stash") == false:
					continue
				seats_checked += 1
				var ok := false
				var on_floor := false
				for c in chairs:
					var d: float = s.position.x - c.position.x
					# the backrest sits 9 to 16 px left of the seat, the chair is 20 px wide and on the seat's row
					if d >= 9.0 and d <= 16.0 and absf(c.position.y - s.position.y) < 14.0:
						ok = true
						# the casters end 1 px under the sitter's soles: top y + 36 = the seat's y
						var bottom: float = c.position.y + c.offset.y + float(c.texture.get_height()) - 1.0   # the last PNG row: the casters hang 1 px below the sitter's sole row
						on_floor = c.texture.get_height() == 37 and absf(bottom - s.position.y) <= 0.5
				_check(ok, "%s: %s has a side chair behind it" % [f, s.name])
				if ok:
					_check(on_floor, "%s: the chair behind %s is the 35 px chair, its casters on the feet line" % [f, s.name])
		scene.free()
	_check(chairs_total >= 30, "the sets expose side chairs (%d)" % chairs_total)
	_check(lounge_checked >= 10, "lounge seats were checked (%d)" % lounge_checked)
	_check(seats_checked >= 15, "seats were checked against chairs (%d)" % seats_checked)
	_check(FileAccess.file_exists("res://assets/props/chair_office.png"), "the front chair art stays for the chair race")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
