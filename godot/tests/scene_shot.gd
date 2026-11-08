extends SceneTree
# Dev tool: windowed screenshot of a scene. SCENE_SHOT=res://scenes/x.tscn SHOT_OUT=C:/x/shot.png Godot --path godot -s res://tests/scene_shot.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pid := OS.get_process_id()
	root.get_node("Campaign").save_prefix = "user://test_sceneshot_%d_" % pid
	root.get_node("Difficulty").settings_path = "user://test_sceneshot_%d_settings.cfg" % pid
	root.get_node("Campaign").new_game("free")
	change_scene_to_file(OS.get_environment("SCENE_SHOT"))
	await create_timer(1.5).timeout
	for i in 30:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
	quit()
