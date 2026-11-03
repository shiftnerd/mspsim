extends Node
# Autoload: scene changes with a fade, the output format, and values that survive scene changes.
#   Format: Godot --path godot -- --format=h     (wide | h | v | vclose, or env PIXEL_FORMAT)
#   Video:  Godot --path godot --resolution 1920x1080 --fixed-fps 60 --write-movie out.avi
#           -- --format=h
# F9 cycles the format while playing.

signal format_changed

const PixelFont := preload("res://scripts/pixelfont.gd")

# size = logical pixels; zoom = camera zoom; cam_y = world y the camera centres on;
# scale = default window pixel scale without --resolution (6x of h = 1920x1080, 6x of v = 1080x1920)
const FORMATS := {
	"wide": {"size": Vector2i(368, 128), "zoom": 1.0, "cam_y": 64.0, "scale": 4, "follow": false},
	"h": {"size": Vector2i(320, 180), "zoom": 1.0, "cam_y": 50.0, "scale": 4, "follow": true},
	"v": {"size": Vector2i(180, 320), "zoom": 1.0, "cam_y": 60.0, "scale": 3, "follow": true},
	"vclose": {"size": Vector2i(180, 320), "zoom": 2.0, "cam_y": 92.0, "scale": 3, "follow": true},
}
const ORDER := ["wide", "h", "v", "vclose"]

const UI_STRIP := 0.2  # share of the screen height left visible above a computer / phone UI

var vars := {}  # e.g. office_return = "from_office1"
var pending_spawn := "start"
var pending_x := -1.0  # one-shot x override for the next spawn (-1 = use the spawn point)
var busy := false
var format := "wide"
var title_mode := false  # the title screen shows real rooms without the player or the cast
var ui_open := false  # a computer / phone UI is open: the player is paused
var ui_shift := 0.0  # 0..1: the stage camera slides so the player shows in the faded strip

var _fade: ColorRect


func _process(_delta: float) -> void:
	# Layout audit: with env LAYOUT_AUDIT=1 any test run prints text that leaves the viewport or overlaps other text.
	if PixelFont.audit != null and OS.get_environment("LAYOUT_AUDIT") == "1":
		for line in PixelFont.audit_report(format, true):
			print(line)


func _ready() -> void:
	if OS.get_environment("LAYOUT_AUDIT") == "1":
		PixelFont.audit = []
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var wanted := OS.get_environment("PIXEL_FORMAT")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--format="):
			wanted = arg.substr(9)
	set_format(wanted if FORMATS.has(wanted) else "wide")


func set_format(name: String) -> void:
	format = name
	var f: Dictionary = FORMATS[name]
	var size: Vector2i = f.size
	var win := get_window()
	win.content_scale_size = size
	if not "--resolution" in OS.get_cmdline_args() and DisplayServer.get_name() != "headless":
		win.size = size * int(f.scale)
	format_changed.emit()


func cycle_format() -> void:
	set_format(ORDER[(ORDER.find(format) + 1) % ORDER.size()])


# Test helper (Q4): a real mouse click at a LOGICAL UI point (0..size of the current format), sent through
# Input.parse_input_event. parse_input_event wants window pixels, so the point goes through the window's final
# (content scale) transform; that makes it independent of the window size, which differs in a hidden, headless or
# --resolution window. The UI scripts read event.position (logical), not the OS cursor, so the click lands.
func ui_to_window(ui_point: Vector2) -> Vector2:
	return get_window().get_final_transform() * ui_point


func hover_at(ui_point: Vector2) -> void:
	Input.use_accumulated_input = false
	var motion := InputEventMouseMotion.new()
	motion.position = ui_to_window(ui_point)
	motion.global_position = motion.position
	Input.parse_input_event(motion)


func click_at(ui_point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	hover_at(ui_point)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = ui_to_window(ui_point)
		ev.global_position = ev.position
		ev.button_index = button
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)


func go_title() -> void:
	busy = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func go(scene: String, spawn: String) -> void:
	if busy:
		return
	busy = true
	if spawn.begins_with("@"):
		spawn = str(vars.get(spawn.substr(1), "start"))
	var here := get_tree().current_scene
	if here != null and is_instance_valid(World):
		World.player_left(here.scene_file_path.get_file().get_basename(), scene)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.15)
	await t.finished
	pending_spawn = spawn
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.15)
	await t2.finished
	busy = false
