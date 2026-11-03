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

var layout := {}
var cables := {}  # id -> {kind, end}
var port_pos := {}  # port id -> Vector2 in rack coordinates
var carrying := ""  # the cable whose end is in the player's hand
var ups_on := true
var nas_on := true
var battery := 1.0
var _boot := {"sw": 99.0, "rt": 99.0, "nas": 99.0}


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
	if not (s.sw_ready and cables["p%d" % desk].end.begins_with("sw")):
		return "no_link"
	return "ok" if s.internet else "no_internet"


func _process(delta: float) -> void:
	var p := power()
	for key in ["sw", "rt", "nas"]:
		_boot[key] = _boot[key] + delta if p[key] else 0.0
	if ups_on:
		if p.wall:
			battery = minf(1.0, battery + delta / 100.0)
		else:
			battery = maxf(0.0, battery - delta / 90.0)
