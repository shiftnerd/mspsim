extends SceneTree
# Dev tool: windowed screenshot of the co-op split view into SPLIT_SHOT (a png path).
#   SPLIT_SHOT=C:/x/split.png Godot --path godot -s res://tests/split_shot.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_splitshot_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_splitshot_%d_settings.cfg" % pid
	root.get_node("Campaign").new_game("free")
	root.get_node("Game").set_format("h")
	change_scene_to_file("res://scenes/warehouse.tscn")
	await create_timer(1.0).timeout
	var players := root.get_node("Players")
	players.enable_coop(true)
	players.join(1, 1)
	for i in 20:
		await physics_frame
	players.node(0).global_position.x = 200.0
	players.node(1).global_position.x = 800.0
	for i in 90:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SPLIT_SHOT"))
	players.enable_coop(false)
	quit()
