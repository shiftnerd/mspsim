extends Area2D
# Press E next to it to play an effect (see fx.gd) on `target`.

@export var target: NodePath
@export var arrow_offset := Vector2(0, -30)
@export var look_x := 0.0  # face this x when using (0 = the zone centre)
@export var group := ""  # optional group name (phone zones are "phones")
@export var low_priority := false  # loses to nearby things (the duck must not steal the monitor)

var _arrow: Node2D
var _player: Node = null


func _ready() -> void:
	if group != "":
		add_to_group(group)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_arrow = preload("res://scripts/prompt_arrow.gd").new()
	_arrow.base_y = arrow_offset.y
	_arrow.position = arrow_offset
	_arrow.visible = false
	add_child(_arrow)


func _on_body_entered(body: Node) -> void:
	if body.has_method("sit"):
		_player = body
		body.add_near(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("sit"):
		body.remove_near(self)
		_player = null
	_arrow.visible = false


func _process(_delta: float) -> void:
	var fx := get_node(target)
	_arrow.visible = (
		_player != null
		and _player.nearest() == self
		and _player.state != "sitting"
		and not fx.busy
		and fx.kind != "bell"
	)


func _hand_over(body: Node, fx: Node) -> void:
	if is_instance_valid(body) and absf(body.global_position.x - global_position.x) < 60.0:
		body.give(fx.item)


func use(body: Node) -> void:
	var fx := get_node(target)
	if fx.kind == "bell":
		Hints.toast("TOO HIGH TO REACH. MAYBE A FOAM DART?", 2.5)
		return
	if fx.style == "computer":
		Computer.open(fx.desk)
		return
	if fx.busy or fx.offline():
		_arrow.shake()
		return
	if fx.style == "call":
		fx.play()
		Msp.phone_call(fx.desk)
		body.start_call(fx.call_secs)
		return
	body.reach(look_x if look_x != 0.0 else global_position.x)
	fx.play()
	if fx.item != "":
		fx.handed.connect(_hand_over.bind(body, fx), CONNECT_ONE_SHOT)
