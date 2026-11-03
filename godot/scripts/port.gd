extends Node2D
# One plug point in the network closet: a switch port, a PDU or UPS outlet, the router's WAN
# port, the wall outlet, or a power button. E pulls the plug out (you carry the cable end) or
# plugs the cable you carry into it.

@export var port_id := ""
@export var arrow_offset := Vector2(0, -5)

var player: Node = null
var _arrow: Node2D


func _ready() -> void:
	add_to_group("ports")
	_arrow = preload("res://scripts/prompt_arrow.gd").new()
	_arrow.base_y = arrow_offset.y
	_arrow.position = arrow_offset
	_arrow.visible = false
	add_child(_arrow)


func _process(_delta: float) -> void:
	_arrow.visible = player != null and player.nearest() == self


func use(body: Node) -> void:
	if port_id.ends_with("_btn"):
		Net.press(port_id)
		body.reach(global_position.x)
		return
	var cable := Net.occupant(port_id)
	var done := false
	if Net.carrying == "":
		if cable != "" and body.held == "":
			Net.pick(cable)
			body.give("plug_net" if Net.cables[cable].kind in ["net", "wan"] else "plug_pwr")
			done = true
	elif cable == "" and Net.accepts(Net.carrying, port_id):
		Net.plug(port_id)
		body.give("")
		done = true
	if done:
		body.reach(global_position.x)
	else:
		_arrow.shake()
