extends Node
# Autoload: the mid-day resume point (roadmap R16; the rules live in Campaign: can_snapshot, snapshot, load_resume).
# This node does the parts that need a tree that is always processing and the world's innards:
#  - the lifecycle: the app is paused (Android home), the window loses focus or is closed -> write the resume point
#    now (Campaign.snapshot refuses at an unsafe moment and the last good one stays); the Android back button opens the
#    pause menu (and closes it again), it never quits by itself (project setting quit_on_go_back is off)
#  - capture(cfg) / apply(cfg): the clock, the cast (trimmed), lights, the player's room, held item and seat, the cable
#    ends and the per-day odds and ends of Shift, Social, Events, Onsite, Outings and Meeting
#  - write(): temp file, check it reads back, keep the old one as .bak, rename into place

const VERSION := 2
# step 5: these singletons are saved whole (every plain-data script variable, not the patchable tables in capitals):
# the Playbook job in progress, the onsite visit, and the owner / service / sales week under way
const DEEP := ["Playbook", "Onsite", "Owner", "Partner", "Service", "ServiceArc", "SalesCampaign", "Crew", "Projects"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			Campaign.snapshot()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()


# the Android back button: the pause menu opens, and the next press closes its page or the menu
func go_back() -> void:
	if PauseMenu.is_open:
		PauseMenu.back()
	elif PauseMenu.can_open(false):
		PauseMenu.open()


# ---- the file ----------------------------------------------------------------------------------
func write(cfg: ConfigFile, path: String) -> bool:
	var tmp := path + ".tmp"
	if cfg.save(tmp) != OK:
		return false
	var check := ConfigFile.new()
	if check.load(tmp) != OK or not check.has_section("resume"):
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + ".bak")  # replaces an older .bak
	return DirAccess.rename_absolute(tmp, path) == OK


# ---- what the snapshot holds beyond the end-of-day sections ------------------------------------------
func capture(cfg: ConfigFile) -> void:
	cfg.set_value("msp", "state", Msp.to_dict())
	cfg.set_value("net", "state", Net.to_dict())
	cfg.set_value("story_day", "state", Story.snapshot())
	cfg.set_value("world", "state", world_dict())
	cfg.set_value("player", "state", player_dict())
	cfg.set_value("day", "state", day_dict())
	cfg.set_value("deep", "state", deep_dict())
	# last: a file cut short never has this section, so it never counts as a resume point
	var head := {"version": VERSION, "mode": Campaign.mode, "day": Campaign.day, "clock": World.clock}
	cfg.set_value("resume", "head", head)


func world_dict() -> Dictionary:
	var cast := {}
	for n in World.chars:
		var st: Dictionary = World.chars[n]
		var held := str(st.held)
		var sips := int(st.sips)
		var node: Variant = st.node
		if node != null and is_instance_valid(node):  # standing in the room: the live person knows
			held = str(node.held)
			sips = int(node.sips)
		cast[n] = {"scene": st.scene, "held": held, "sips": sips, "lunched": st.lunched}
	return {"clock": World.clock, "day": World.day, "lights": World.lights.duplicate(), "door": World.door_open, "cast": cast}


func player_dict() -> Dictionary:
	var scene := get_tree().current_scene
	var p: Node = Players.player0(scene) if scene != null else null
	if p == null:
		return {}
	var seat := ""
	if p.state == "sitting" and p.seat != null and is_instance_valid(p.seat):
		seat = str(p.seat.name)
	var room := scene.scene_file_path.get_file().get_basename()
	return {"room": room, "held": str(p.held), "sips": int(p.sips), "seat": seat, "x": float(p.position.x)}


# true for values a ConfigFile can hold and give back unchanged (no objects, callables or signals anywhere inside)
func plain(v: Variant) -> bool:
	match typeof(v):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			for item in v:
				if not plain(item):
					return false
		TYPE_DICTIONARY:
			for k in v:
				if not plain(k) or not plain(v[k]):
					return false
	return true


# every plain-data script variable of the DEEP singletons: {singleton: {variable: value}}
func deep_dict() -> Dictionary:
	var out := {}
	for who in DEEP:
		var node := get_node_or_null("/root/" + who)
		if node == null:
			continue
		var vars := {}
		for p in node.get_property_list():
			var key := str(p.name)
			if (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or key == key.to_upper():
				continue
			var v: Variant = node.get(key)
			if plain(v):
				vars[key] = v
		out[who] = vars
	return out


func apply_deep(d: Dictionary) -> void:
	for who in d:
		var node := get_node_or_null("/root/" + str(who))
		if node == null or not (d[who] is Dictionary) or not DEEP.has(str(who)):
			continue
		for key in d[who]:
			if str(key) in node:
				node.set(str(key), d[who][key])
	if Onsite.active:  # resumed at a client site: the office stays frozen until you drive back
		Onsite._prev_msp = true
		Onsite._prev_scale = 1.0
		Msp.enabled = false
		World.time_scale = 0.0
	Playbook.changed.emit()


# the per-day state that the day-begin hooks set up and the end-of-day sections do not carry
func day_dict() -> Dictionary:
	return {
		"base": Campaign._base.duplicate(),
		"shift": {
			"late_min": Shift.late_min,
			"stay_hours": Shift.stay_hours,
			"asked": Shift._asked,
			"stay_until": Shift._stay_until,
			"warned": Shift._warned,
			"oncall_pay": Shift._oncall_pay,
			"note": Shift.last_note,
		},
		"social": {"day_delta": Social.day_delta, "reopen_loss": Social._reopen_loss, "closed": Social._closed},
		"events": Events.pending.duplicate(true),
		"onsite": {"spawn_at": Onsite._spawn_at, "pet_energy": Onsite._pet_energy},
		"outings": {"offered": Outings._offered, "lunch": Outings._lunch_offered},
		"meeting": Meeting.state,
	}


# ---- the way back ------------------------------------------------------------------------------
func apply(cfg: ConfigFile) -> void:
	Net.from_dict(cfg.get_value("net", "state", {}))
	apply_day(cfg.get_value("day", "state", {}))
	apply_world(cfg.get_value("world", "state", {}))
	apply_player(cfg.get_value("player", "state", {}))
	apply_deep(cfg.get_value("deep", "state", {}))


func apply_day(d: Dictionary) -> void:
	var base: Variant = d.get("base", {})
	if base is Dictionary and not (base as Dictionary).is_empty():
		Campaign._base = (base as Dictionary).duplicate()
	else:
		Campaign._base = {"score": Msp.score, "closed": Msp.closed_ok, "missed": Msp.breached, "reopened": Msp.reopened}
	var sh: Dictionary = d.get("shift", {})
	Shift.late_min = int(sh.get("late_min", 0))
	Shift.stay_hours = float(sh.get("stay_hours", 0.0))
	Shift._asked = bool(sh.get("asked", false))
	Shift._stay_until = float(sh.get("stay_until", 0.0))
	Shift._warned = int(sh.get("warned", 0))
	Shift._oncall_pay = int(sh.get("oncall_pay", 0))
	Shift.last_note = str(sh.get("note", ""))
	var so: Dictionary = d.get("social", {})
	Social.day_delta = int(so.get("day_delta", 0))
	Social._reopen_loss = int(so.get("reopen_loss", 0))
	Social._closed = int(so.get("closed", 0))
	var ev: Variant = d.get("events", {})
	Events.pending = (ev as Dictionary).duplicate(true) if ev is Dictionary else {}
	var on: Dictionary = d.get("onsite", {})
	Onsite._spawn_at = float(on.get("spawn_at", -1.0))
	Onsite._pet_energy = int(on.get("pet_energy", 0))
	Outings._offered = bool(d.get("outings", {}).get("offered", false))
	Outings._lunch_offered = bool(d.get("outings", {}).get("lunch", false))
	Meeting.state = str(d.get("meeting", ""))


# the clock and lights come back exactly; the cast is trimmed: everybody is at their desk (or still outside, coming
# in) with their held item, sips and lunch flag, and plans their next leg from there
func apply_world(d: Dictionary) -> void:
	World.day = int(d.get("day", Campaign.day))
	World.clock = float(d.get("clock", World.DAY_START))
	World.lights.clear()
	World.door_open = clampf(float(d.get("door", 0.0)), 0.0, 1.0)
	var lights: Variant = d.get("lights", {})
	if lights is Dictionary:
		for room in lights:
			World.lights[World.LEGACY_ROOMS.get(str(room), str(room))] = bool(lights[room])
	Mutators.prepare_day(World.day)  # who is out sick today (flu season), the same pick as this morning
	World.apply_roster()
	var cast: Dictionary = d.get("cast", {})
	for n in World.chars:
		var st: Dictionary = World.chars[n]
		var node: Variant = st.node
		if node != null and is_instance_valid(node):
			node._leaving = true
		st.node = null
		var saved: Dictionary = cast.get(n, {})
		st.held = str(saved.get("held", ""))
		st.sips = int(saved.get("sips", 0))
		st.lunched = bool(saved.get("lunched", false))
		st.following = false
		st.follow_t = 0.0
		st.fresh = false
		st.arriving = false
		st.arrive = ""
		if str(saved.get("scene", "")) == World.OUTSIDE:
			var wait_s := randf_range(5.0, 25.0)
			st.scene = World.OUTSIDE
			st.legs = [
				{
					"kind": "away",
					"scene": World.OUTSIDE,
					"routine": PackedStringArray(),
					"dur": wait_s,
					"target_x": -1.0,
					"to_scene": "main_floor",
					"to_spawn": "from_outside",
				}
			]
		else:
			st.scene = World.row(n).home
			st.legs = [World._work_leg(n, true, randf_range(20.0, 50.0))]
		st.leg_t = st.legs[0].dur


# the room, the held cup and the seat travel through Game.vars; the stage seats the player (Stage._seat_player)
func apply_player(d: Dictionary) -> void:
	var room: String = World.LEGACY_ROOMS.get(str(d.get("room", "")), str(d.get("room", "")))
	if room != "" and ResourceLoader.exists("res://scenes/%s.tscn" % room):
		Campaign._resume_scene = room
		Game.vars["resume_seat"] = str(d.get("seat", ""))
	if d.has("x"):
		Game.vars["resume_x"] = float(d.x)
	Game.vars["held"] = str(d.get("held", ""))
	Game.vars["sips"] = int(d.get("sips", 0))
