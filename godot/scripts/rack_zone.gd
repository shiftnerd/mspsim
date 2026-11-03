extends Area2D
# Standing anywhere in the closet puts every plug point in reach (Tab moves the arrow around).


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body.has_method("sit"):
		for port in get_tree().get_nodes_in_group("ports"):
			body.add_near(port)
			port.player = body


func _on_exit(body: Node) -> void:
	if body.has_method("sit"):
		for port in get_tree().get_nodes_in_group("ports"):
			body.remove_near(port)
			port.player = null
