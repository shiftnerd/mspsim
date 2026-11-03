extends SceneTree
# Screenshot: Vic walks in with a client complaint (needs a renderer): user://sales_card.png

var frame := 0
var shot := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var sales := root.get_node("Sales")
	var cards := root.get_node("Cards")
	if frame == 5:
		root.get_node("Campaign").new_game("free")
		var t: Dictionary = msp.create_ticket(0, 1, "test")
		msp.ticket(t.id).sla_left = 20.0
		world.chars["Vic"].scene = "cubicle_area"
		sales.pending = {"ticket": t.id, "client": 0}
		world.send_vic_to_player()
	if cards.is_open and not shot:
		shot = true
		var img := root.get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png("user://sales_card.png")
		quit()
	if frame > 3000:
		quit()
	return false
