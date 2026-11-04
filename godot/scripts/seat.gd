extends Area2D
# A chair. The node sits at the seated character's feet.
# Press E next to it to sit; E / move / jump to stand.

@export var facing := "right"
@export var typing := true
@export var stash := true  # false for lounge seats (armchair, couch): the cup stays in hand
@export var cup_dx := 35.0  # where a cup stands when seated (offset from the seat, desktop y)
@export var cup_y := 84.0
@export var stand_y := 118.0
@export var arrow_offset := Vector2(0, -44)

var occupied := false

var _arrow: Node2D
var _bodies: Array[Node] = []  # every player body inside the zone


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_arrow = preload("res://scripts/prompt_arrow.gd").new()
	_arrow.base_y = arrow_offset.y
	_arrow.position = arrow_offset
	_arrow.visible = false
	add_child(_arrow)


func _on_body_entered(body: Node) -> void:
	if body.has_method("sit"):
		if body not in _bodies:
			_bodies.append(body)
		body.add_near(self)


func _on_body_exited(body: Node) -> void:
	if body.has_method("sit"):
		body.remove_near(self)
		_bodies.erase(body)
	_arrow.visible = _watched()


func _watched() -> bool:
	if occupied:
		return false
	for body in _bodies:
		if is_instance_valid(body) and body.nearest() == self and body.state != "sitting":
			return true
	return false


func _process(_delta: float) -> void:
	_arrow.visible = _watched()


func use(body: Node) -> void:
	if occupied:
		_arrow.shake()
		return
	_arrow.visible = false
	if Players.coop:  # two bodies can reach a chair: the first one in owns it (single player never sets this: NPC seating is unchanged)
		occupied = true
	body.sit(self)
