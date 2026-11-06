extends Node
# Autoload: the network closet. A UPS feeds a PDU that powers the switch, router and NAS; one
# patch cable per desk runs from the patch panel into a switch port; an uplink joins switch and
# router; the router's WAN cable goes to the ISP; the UPS plugs into the wall. Desks (monitors,
# phones, the copier) only work while their whole chain is plugged in and the devices have
# finished booting. Cable ends can be pulled out and plugged into other ports of the right kind.

const LAYOUT_PATH := "res://assets/props/network_rack_layout.json"
const BOOT := {"sw": 3.0, "rt": 6.0, "nas": 8.0}  # seconds from power to ready
# cable id -> [kind, port the movable end sits in]
const DEFAULTS := {
	"p1": ["net", "sw1"],
	"p2": ["net", "sw2"],
	"p3": ["net", "sw3"],
	"p4": ["net", "sw4"],
	"p5": ["net", "sw5"],
	"p6": ["net", "sw6"],
	"p7": ["net", "sw7"],
	"p8": ["net", "sw8"],
	"up": ["net", "sw9"],
	"nas": ["net", "sw10"],
	"wan": ["wan", "wan"],
	"sw_pwr": ["pwr", "pdu1"],
	"rt_pwr": ["pwr", "pdu2"],
	"nas_pwr": ["pwr", "pdu3"],
	"pdu_in": ["feed", "ups1"],
	"ups_in": ["inlet", "wall"],
}
const PATCH_COLORS := ["#4f7fd0", "#4f9c8e", "#e0a030", "#9a60c8"]
# R37 cable tracing: the patch panel's jack labels, a loose cable and the toner and probe (see "Network closet" in CLAUDE.md)
const DAN_JACKS := [1, 3, 8]  # printed label-maker tags (Dan is proud of them): always right
const DRIFT_JACKS := [2, 4, 5, 6, 7]  # hand-written tape that drifts when somebody re-plugs things
const WHO := {1: "DESK 1", 2: "MAYA", 3: "DAN", 4: "JOHN", 5: "MORGAN", 6: "ALAN", 7: "GARRISON", 8: "COPIER"}
const FLAP_SECS := 6.0  # a healthy jack you re-seat drops its desk this long
const TRACE_XP := 6  # networking XP for finding a loose cable by tracing instead of trusting a bad label
const FAULT_FROM_DAY := 3  # tech campaign: from this day a cable may work loose
const FAULT_CHANCE := 0.4

var layout := {}
var cables := {}  # id -> {kind, end}
var port_pos := {}  # port id -> Vector2 in rack coordinates
var carrying := ""  # the cable whose end is in the player's hand
var ups_on := true
var nas_on := true
var battery := 1.0
var labels := {}  # jack 1-8 -> {n: the desk the tag says (0 = nothing written), state: dan / ok / wrong / faded / blank / fixed}
var faults := {}  # patch cable id -> true: half-seated at the panel, that desk has no link until the jack is re-seated
var fixed_labels := {}  # jack -> true: relabelled by you, right from then on
var cable_faults := false  # the title turns this on for a real run: only then may a cable work loose in the tech campaign
var tone_desk := 0  # the tone generator is clipped on this desk's wall jack (0 = not clipped)
var traced := {}  # desk -> the jack where the probe beeped for it
var beep_jack := 0  # the jack that just beeped (a ring is drawn round it)
var beep_t := 0.0
var _boot := {"sw": 99.0, "rt": 99.0, "nas": 99.0}
var _flap := {}  # jack -> seconds left of a dropped link
var _untrusted := {}  # jack -> true when its label was not right at the moment the cable worked loose
var _label_key := ""
var _plan_day := -1
var _plan := {}
var _fired_day := -1
var _pokes := 0


func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	for p in layout.ports:
		port_pos[p.id] = Vector2(float(p.x), float(p.y))
	reset()


func reset() -> void:
	cables.clear()
	for id in DEFAULTS:
		cables[id] = {"kind": DEFAULTS[id][0], "end": DEFAULTS[id][1]}
	carrying = ""
	ups_on = true
	nas_on = true
	battery = 1.0
	for key in _boot:
		_boot[key] = 99.0
	labels.clear()
	faults.clear()
	fixed_labels.clear()
	traced.clear()
	_flap.clear()
	_untrusted.clear()
	_label_key = ""
	tone_desk = 0
	beep_jack = 0
	beep_t = 0.0
	_plan_day = -1
	_fired_day = -1


# the resume point (R16): where every cable end is and what is powered
func to_dict() -> Dictionary:
	return {
		"cables": cables.duplicate(true),
		"ups_on": ups_on,
		"nas_on": nas_on,
		"battery": battery,
		"boot": _boot.duplicate(),
		"faults": faults.keys(),
		"fixed": fixed_labels.keys(),
		"untrusted": _untrusted.keys(),
		"traced": traced.duplicate(),
		"tone": tone_desk,
		"fired": _fired_day,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("cables", {})
	if saved is Dictionary:
		for id in saved:
			var c: Variant = saved[id]
			if cables.has(id) and c is Dictionary and c.has("kind") and c.has("end"):
				cables[id] = {"kind": str(c.kind), "end": str(c.end)}
	ups_on = bool(data.get("ups_on", true))
	nas_on = bool(data.get("nas_on", true))
	battery = float(data.get("battery", 1.0))
	var boot: Variant = data.get("boot", {})
	if boot is Dictionary:
		for key in _boot:
			_boot[key] = float(boot.get(key, 99.0))
	for id in data.get("faults", []):
		faults[str(id)] = true
	for k in data.get("fixed", []):
		fixed_labels[int(k)] = true
	for k in data.get("untrusted", []):
		_untrusted[int(k)] = true
	var saved_trace: Variant = data.get("traced", {})
	if saved_trace is Dictionary:
		for d in saved_trace:
			traced[int(d)] = int(saved_trace[d])
	tone_desk = int(data.get("tone", 0))
	_fired_day = int(data.get("fired", -1))


func cable_color(id: String) -> Color:
	if id.begins_with("p"):
		return Color(PATCH_COLORS[(int(id.substr(1)) - 1) % PATCH_COLORS.size()])
	match id:
		"up":
			return Color("e8d43c")
		"nas":
			return Color("6ec24e")
		"wan":
			return Color("d23c3c")
		"ups_in":
			return Color("b8bcc4")
	return Color("7b808c")


func far_pos(id: String) -> Vector2:
	var f: Array = layout.far[id]
	return Vector2(float(f[0]), float(f[1]))


func occupant(port: String) -> String:
	for id in cables:
		if cables[id].end == port:
			return id
	return ""


func accepts(cable: String, port: String) -> bool:
	match cables[cable].kind:
		"net":
			return port.begins_with("sw")
		"wan":
			return port == "wan"
		"pwr":
			return port.begins_with("pdu")
		"feed":
			return port.begins_with("ups")
		"inlet":
			return port == "wall"
	return false


func pick(cable: String) -> void:
	cables[cable].end = ""
	carrying = cable
	_cut_power_timers()


func plug(port: String) -> void:
	cables[carrying].end = port
	carrying = ""


func drop_carry() -> void:
	carrying = ""


func press(button: String) -> void:
	if button == "ups_btn":
		ups_on = not ups_on
	elif button == "nas_btn":
		nas_on = not nas_on
	_cut_power_timers()


# a device that lost power forgets that it was booted
func _cut_power_timers() -> void:
	var p := power()
	for key in ["sw", "rt", "nas"]:
		if not p[key]:
			_boot[key] = 0.0


# which devices are being fed power right now (before boot time)
func power() -> Dictionary:
	var p := {}
	p.wall = cables.ups_in.end == "wall"
	p.ups_out = ups_on and (p.wall or battery > 0.0)
	p.pdu = p.ups_out and cables.pdu_in.end.begins_with("ups")
	p.sw = p.pdu and cables.sw_pwr.end.begins_with("pdu")
	p.rt = p.pdu and cables.rt_pwr.end.begins_with("pdu")
	p.nas = p.pdu and cables.nas_pwr.end.begins_with("pdu") and nas_on
	return p


func status() -> Dictionary:
	var s := power()
	s.sw_ready = s.sw and _boot.sw >= BOOT.sw
	s.rt_ready = s.rt and _boot.rt >= BOOT.rt
	s.nas_ready = s.nas and _boot.nas >= BOOT.nas
	s.uplink = s.sw_ready and s.rt_ready and cables.up.end.begins_with("sw")
	s.wan = s.rt_ready and cables.wan.end == "wan"
	s.internet = s.uplink and s.wan
	return s


# "ok", "no_internet" (linked, but router / WAN / uplink down) or "no_link" (no cable / switch)
func desk_state(desk: int) -> String:
	if desk < 1 or desk > 8:
		return "ok"
	var s := status()
	if faults.has("p%d" % desk) or float(_flap.get(desk, 0.0)) > 0.0:
		return "no_link"
	if not (s.sw_ready and cables["p%d" % desk].end.begins_with("sw")):
		return "no_link"
	return "ok" if s.internet else "no_internet"


func _process(delta: float) -> void:
	_tick_tracing(delta)
	var p := power()
	for key in ["sw", "rt", "nas"]:
		_boot[key] = _boot[key] + delta if p[key] else 0.0
	if ups_on:
		if p.wall:
			battery = minf(1.0, battery + delta / 100.0)
		else:
			battery = maxf(0.0, battery - delta / 90.0)


# ---- cable tracing (R37): labels on the patch panel jacks, loose cables, the toner and probe ----
# jack k's cable always runs to desk k (the copier is desk 8); only the TAG on the jack can be wrong.
func label(jack: int) -> Dictionary:
	_ensure_labels()
	return labels[jack]


func label_ok(jack: int) -> bool:
	return str(label(jack).state) in ["dan", "ok", "fixed"]


# what the tag shows: "5 MORGAN", "FADED", "BLANK"
func label_text(jack: int) -> String:
	var l := label(jack)
	if l.state == "blank":
		return "BLANK"
	if l.state == "faded":
		return "FADED"
	return "%d %s" % [int(l.n), WHO[int(l.n)]]


func _label_epoch() -> int:
	return World.day if Campaign.active else 0


func _ensure_labels() -> void:
	var epoch := _label_epoch()
	if _label_key == "%d:%d" % [Difficulty.run_seed, epoch] and not labels.is_empty():
		return
	labels = roll_labels(epoch)
	_label_key = "%d:%d" % [Difficulty.run_seed, epoch]


# the labels of one day, seeded per run (Difficulty stream "labels"): Dan's tags are right, one pair of hand-written tags is
# swapped (two pairs now and then), the rest of the tape may be blank or faded. Your relabelled jacks stay right.
func roll_labels(epoch: int) -> Dictionary:
	var r := Difficulty.rng_for("labels", epoch)
	var out := {}
	for k in range(1, 9):
		out[k] = {"n": k, "state": "dan" if DAN_JACKS.has(k) else "ok"}
	var drift := DRIFT_JACKS.duplicate()
	Difficulty.shuffle_with(drift, r)
	var pairs := 2 if r.randf() < 0.35 else 1
	for i in pairs:
		var a: int = drift.pop_front()
		var b: int = drift.pop_front()
		out[a] = {"n": b, "state": "wrong"}
		out[b] = {"n": a, "state": "wrong"}
	for k in drift:
		var roll := r.randf()
		if roll < 0.25:
			out[k] = {"n": 0, "state": "blank"}
		elif roll < 0.5:
			out[k] = {"n": k, "state": "faded"}
	for k in fixed_labels:
		out[k] = {"n": k, "state": "fixed"}
	return out


func is_loose(jack: int) -> bool:
	return faults.has("p%d" % jack)


func loosen(jack: int) -> void:
	faults["p%d" % jack] = true
	_untrusted[jack] = not label_ok(jack)
	traced.erase(jack)


# the tone generator is clipped on the wall jack at this desk
func tone_at(desk: int) -> void:
	tone_desk = desk


# the probe on a patch panel jack: a beep when its cable is the one with the tone on it
func probe(jack: int) -> String:
	if tone_desk == 0:
		return "notone"
	if tone_desk != jack:
		return "quiet"
	traced[jack] = jack
	beep_jack = jack
	beep_t = 2.5
	return "beep"


# E on a patch jack with empty hands: pull the cable and push it back in. Fixes a half-seated cable (a bonus when you traced it
# because its label could not be trusted); on a healthy jack the desk drops for a few seconds and its owner is not pleased.
func reseat(jack: int) -> String:
	var id := "p%d" % jack
	if faults.has(id):
		faults.erase(id)
		_flap[jack] = 1.0
		var bonus: bool = bool(_untrusted.get(jack, false)) and int(traced.get(jack, 0)) == jack
		_untrusted.erase(jack)
		if bonus:
			Skills.add_xp(str(Skills.FIX_XP.get("trace", "networking")), TRACE_XP)
			Social.change(str(Social.DESK_OWNER.get(jack, "")), 2)
			return "traced_fix"
		return "fixed"
	if float(_flap.get(jack, 0.0)) <= 0.0:
		Social.note_outage(jack)
	_flap[jack] = FLAP_SECS
	if not Campaign.active:
		_pokes += 1
		if Difficulty.rng_for("labels.loose", _pokes).randf() < 0.5:
			faults[id] = true  # Free Play: it did not go back in properly
			_untrusted[jack] = not label_ok(jack)
			return "loose"
	return "bounced"


# the tiny relabel action: the probe found this jack, so write the right tag (Dan likes that)
func relabel(jack: int) -> bool:
	if label_ok(jack) or int(traced.get(jack, 0)) != jack:
		return false
	fixed_labels[jack] = true
	labels[jack] = {"n": jack, "state": "fixed"}
	Social.change("Dan", 2)
	return true


# tech campaign: from day 3 a patch cable may work loose at a seeded time; the desk then raises the usual "no network cable" ticket
func fault_plan(day: int) -> Dictionary:
	var r := Difficulty.rng_for("cablefault", day)
	var on := day >= FAULT_FROM_DAY and r.randf() < FAULT_CHANCE
	var at := 9.5 + r.randf() * 5.0
	var pick_bad := r.randf() < 0.7
	var any := r.randi_range(1, 5)
	var pick := r.randf()
	var bad := []
	var today := roll_labels(day)
	for k in range(1, 6):
		if not str(today[k].state) in ["dan", "ok", "fixed"]:
			bad.append(k)
	var jack: int = any
	if pick_bad and not bad.is_empty():
		jack = bad[int(pick * bad.size())]
	return {"on": on, "at": at, "jack": jack}


func _tick_tracing(delta: float) -> void:
	beep_t = maxf(0.0, beep_t - delta)
	for k in _flap.keys():
		_flap[k] = maxf(0.0, float(_flap[k]) - delta)
		if _flap[k] <= 0.0:
			_flap.erase(k)
	if not (cable_faults and Campaign.active and Campaign.mode == "tech" and Msp.enabled) or Game.title_mode:
		return
	if World.day != _plan_day:
		_plan_day = World.day
		_plan = fault_plan(World.day)
	if _plan.on and _fired_day != World.day and World.clock >= float(_plan.at):
		_fired_day = World.day
		loosen(int(_plan.jack))
