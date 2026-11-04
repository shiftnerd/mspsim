extends Node2D
# One plug point in the network closet: a switch port, a PDU or UPS outlet, the router's WAN
# port, the wall outlet, or a power button. E pulls the plug out (you carry the cable end) or
# plugs the cable you carry into it.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")

@export var port_id := ""
@export var arrow_offset := Vector2(0, -5)

var player: Node = null
var _arrow: Node2D
var _shown := false


func _ready() -> void:
	add_to_group("ports")
	if _is_jack():
		z_index = 30  # the tag readout sits over the rack
	_arrow = preload("res://scripts/prompt_arrow.gd").new()
	_arrow.base_y = arrow_offset.y
	_arrow.position = arrow_offset
	_arrow.visible = false
	add_child(_arrow)


func _process(_delta: float) -> void:
	_arrow.visible = player != null and player.nearest() == self
	if _is_jack():
		var sel := _arrow.visible
		if sel != _shown:
			_shown = sel
			queue_redraw()
		elif sel:
			queue_redraw()  # the tag text follows the labels (a relabel, a new day)


func _is_jack() -> bool:
	return port_id.begins_with("pp")


# the tag on a patch panel jack, as a readable strip under it while the arrow is on the jack
func _draw() -> void:
	if not _is_jack() or not _shown:
		return
	var jack := int(port_id.substr(2))
	var text := Net.label_text(jack)
	var w := PixelFont.width(text, 1) + 4
	var jack_x := 10.0 + 7.0 * float(jack - 1)  # the jack's x inside the rack art (70 wide)
	var x := clampf(-w * 0.5, 2.0 - jack_x, 68.0 - jack_x - w)
	draw_rect(Rect2(x - 1, 4, w + 2, 9), INK)
	draw_rect(Rect2(x, 5, w, 7), Color("efe6c8") if Net.label_ok(jack) else Color("c9b98a"))
	PixelFont.draw(self, text, Vector2(x + 2, 6), INK, 1)


# E on a patch panel jack: with the toner it probes (a beep, or a second E relabels a bad tag), with empty hands it re-seats the cable
func _use_jack(body: Node) -> void:
	var jack := int(port_id.substr(2))
	if Net.carrying != "" or not body.held in ["", "toner"]:
		_arrow.shake()
		return
	body.reach(global_position.x)
	if body.held == "":
		match Net.reseat(jack):
			"traced_fix":
				Hints.toast("RE-SEATED JACK %d. YOU TRACED IT: NICE WORK (+NETWORKING)" % jack, 3.0)
				Sfx.play("ticket")
			"fixed":
				Hints.toast("RE-SEATED JACK %d: THE DESK IS BACK" % jack, 2.5)
				Sfx.play("ui_pick")
			"loose":
				Hints.toast("JACK %d WORKED LOOSE. THE DESK DROPS" % jack, 2.5)
				Sfx.play("ui_error")
			_:
				Hints.toast("RE-SEATED JACK %d. IT WAS FINE: THAT DESK DROPS FOR A MOMENT" % jack, 3.0)
				Sfx.play("ui_error")
		return
	if int(Net.traced.get(jack, 0)) == jack and Net.relabel(jack):
		Hints.toast("NEW TAG ON JACK %d: %s. DAN WOULD APPROVE" % [jack, Net.label_text(jack)], 3.0)
		Sfx.play("ui_pick")
		return
	match Net.probe(jack):
		"notone":
			Hints.toast("NO TONE YET. CLIP IT ON A DESK JACK: E AT THE MONITOR OR PHONE", 3.0)
			_arrow.shake()
		"quiet":
			Hints.toast("JACK %d: SILENCE. NOT DESK %d" % [jack, Net.tone_desk], 2.0)
			Sfx.play("ui_tick")
		_:
			var tag := "" if Net.label_ok(jack) else ". TAG SAYS %s: E AGAIN TO RELABEL" % Net.label_text(jack)
			Hints.toast("BEEP! JACK %d IS DESK %d%s" % [jack, jack, tag], 3.5)
			Sfx.play("ui_pick")


func use(body: Node) -> void:
	if _is_jack():
		_use_jack(body)
		return
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
