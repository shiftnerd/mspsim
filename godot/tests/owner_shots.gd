extends SceneTree
# Screenshots of the owner campaign: Boardroom, the weekly P&L, a peer meeting card (renderer).

var frame := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://owner_%s.png" % name)


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var comp := root.get_node("Computer")
	var sales := root.get_node("Sales")
	var cards := root.get_node("Cards")
	match frame:
		10:
			c.save_prefix = "user://test_%d_" % OS.get_process_id()
			c.new_game("owner")
			o.flags["peer_group"] = true
			o.flags["mentor"] = true
			o.flags["backup_service"] = true
			o.marketing = 400
			o.apply({"hire": o.JUNIOR})
			sales.sign_client()
			sales.satisfaction[1] = 40
			comp.open(1)
			o.apply({"stack": {"psa": "ticketo", "hardware": "budgetbyte"}, "vic_plan": "balanced"})
			o.ar = [{"client": 6, "amount": 800, "age": 2, "delay": 3}]
			sales.active.append(6)
			comp.open(1)
			comp.activate("app:boardroom")
		40:
			_shot("boardroom")
			comp.activate("btab:clients")
		44:
			_shot("clients")
			comp.activate("btab:team")
		48:
			_shot("team")
			comp.activate("btab:stack")
		52:
			_shot("stack")
			comp.close()
			o.show_card("peer4")
		60:
			_shot("card")
			cards.pick(1)
			c.day = 5
			c._base = {"score": 0, "closed": 0, "missed": 0, "reopened": 0}
			c._end_day()
		100:
			_shot("report")
			quit()
	return false
