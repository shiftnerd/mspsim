extends Area2D
# A door (press E next to it) or, with auto = true, an edge exit that fires on touch.

@export var target_scene := ""
@export var target_spawn := "start"
@export var remember := ""  # "key=value" stored in Game.vars when used
@export var auto := false
@export var locked := false  # can't be used: the arrow turns red and shakes
@export var occupancy := ""  # a bathroom scene: the door is locked while somebody is inside (World.bathroom_occupied)
@export var special := ""  # "front" = the office front door: choose a client site to drive to; "dock" = the warehouse doorway to the lot (locked unless the overhead door is all the way up)
@export var arrow_offset := Vector2(0, -36)

var _arrow: Node2D
var _bodies: Array[Node] = []  # every player body inside the zone (two players can stand at one door)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if not auto:
		_arrow = preload("res://scripts/prompt_arrow.gd").new()
		_arrow.base_y = arrow_offset.y
		_arrow.position = arrow_offset
		_arrow.visible = false
		if locked:
			_arrow.modulate = Color(0.62, 0.62, 0.68)
		add_child(_arrow)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("sit"):
		return
	if auto:
		use(body)
	else:
		if body not in _bodies:
			_bodies.append(body)
		body.add_near(self)


func _on_body_exited(body: Node) -> void:
	if auto or not body.has_method("sit"):
		return
	body.remove_near(self)
	_bodies.erase(body)
	_arrow.visible = _watched()


func is_locked() -> bool:
	return locked or (occupancy != "" and World.bathroom_occupied(occupancy)) or (special == "dock" and not _dock_open())


# the overhead door (fx kind roll_door) has rolled all the way up
func _dock_open() -> bool:
	var door: Node = get_tree().get_first_node_in_group("roll_door")
	return door != null and float(door.open) >= 0.999 and float(door.goal) > 0.5


# does any player inside the zone have this door as the thing to use (and is not sitting)?
func _watched() -> bool:
	for body in _bodies:
		if is_instance_valid(body) and body.nearest() == self and body.state != "sitting":
			return true
	return false


func _process(_delta: float) -> void:
	if _arrow != null:
		_arrow.visible = _watched()
		if (occupancy != "" or special == "dock") and not _arrow.shaking():
			_arrow.modulate = Color(0.62, 0.62, 0.68) if is_locked() else Color.WHITE


func use(body: Node) -> void:
	if special == "front":
		Onsite.offer_door()
		return
	if is_locked():
		_arrow.shake()
		if occupancy != "":
			Hints.toast("OCCUPIED")
		elif special == "dock":
			Hints.toast("THE DOOR IS SHUT. ROLL IT UP FIRST.", 2.2)
		return
	var partner: int = Players.busy_partner(body)
	if partner >= 0 and not Players.force_door(partner):  # co-op: the partner is at a screen; the door asks twice before it drags them out
		_arrow.shake()
		Hints.toast("P%d IS AT THEIR SCREEN. TRY THE DOOR AGAIN TO MAKE THEM LEAVE." % (partner + 1), 2.5)
		return
	if remember != "":
		var kv := remember.split("=")
		Game.vars[kv[0]] = kv[1]
	Game.go(target_scene, target_spawn)
