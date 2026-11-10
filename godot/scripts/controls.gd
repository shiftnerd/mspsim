extends Node
# gdlint:disable=max-line-length,max-returns
# Autoload: the one place that says which key (and which gamepad button) does what (roadmap R14, portability).
# Every control is a named InputMap action registered here at startup; scripts ask for the action instead of a raw
# key, so a controller or a touch layer can be added later without touching the game scripts.
#   Controls.matches(event, "push_a")   true when a key event is one of the action's keys, or the action itself
#                                       (tests send plain key events, a gamepad sends the action)
#   Controls.confirm(event) / back(event)  Enter, Space or E / Esc or Backspace, or the ui_accept / ui_cancel actions
#   Controls.pressed(event)             a fresh key, pad button, action or stick push (guards the menu handlers)
#   Controls.nav(event) / step(...)     "up" "down" "left" "right" from arrows, W A S D, the D-pad or the stick
# Co-op (Players.coop, off by default): confirm_for(event, slot) / back_for(event, slot), action_for(slot, "jump"),
# slot_of(event); slot 1 reads a p2_ copy of the table bound to its own pad (ensure_slot).
# Gamepad: left stick or D-pad moves, A jumps, X uses, B runs, stick down ducks, RT aims, Start pauses. Most screens
# still read the keyboard; the player's movement actions and the pause menu already work with a pad.

const TOUCH_OVERLAY := preload("res://scripts/touch_overlay.gd")

# action: [keys, pad buttons, pad axes as [axis, value]]
const ACTIONS := {
	"move_left": [[KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]]],
	"move_right": [[KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]]],
	"jump": [[KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP], []],
	"run": [[KEY_SHIFT], [JOY_BUTTON_B], []],
	"interact": [[KEY_E], [JOY_BUTTON_X], []],
	"hurt": [[KEY_H], [], []],
	"die": [[KEY_K], [], []],
	"revive": [[KEY_R], [], []],
	"wave": [[KEY_Q], [JOY_BUTTON_Y], []],
	"drink": [[KEY_F], [JOY_BUTTON_LEFT_SHOULDER], []],
	"dance": [[KEY_X], [], []],
	"follow": [[KEY_C], [], []],
	"duck": [[KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]]],
	"aim": [[KEY_Z], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]],
	"push_a": [[KEY_Z], [JOY_BUTTON_A], []],
	"push_b": [[KEY_X], [JOY_BUTTON_B], []],
	"pick_next": [[KEY_TAB], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"pick_prev": [[], [JOY_BUTTON_LEFT_SHOULDER], []],
	"page_prev": [[KEY_Q, KEY_PAGEUP], [JOY_BUTTON_LEFT_SHOULDER], []],  # the create step's pages (R15 level 3)
	"page_next": [[KEY_E, KEY_PAGEDOWN], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"hold_pose": [[KEY_TAB], [JOY_BUTTON_Y], []],  # the create step's mirror preview: hold the pose / let it cycle (R15 level 3 step e)
	"pose_prev": [[KEY_COMMA], [], []],
	"pose_next": [[KEY_PERIOD], [], []],
	"outfit": [[KEY_Y], [JOY_BUTTON_LEFT_STICK], []],  # Free Play: change your look (Toolbox.open_outfit)
	"career": [[KEY_J], [], []],  # Free Play: the career screen (medals, unlocks)
	"offer_war": [[KEY_V], [JOY_BUTTON_Y], []],
	"give_item": [[KEY_G], [], []],
	"phone": [[KEY_P], [JOY_BUTTON_BACK], []],
	"character_next": [[], [JOY_BUTTON_RIGHT_STICK], []],  # co-op: the next stock person for this player (slot 0 has the 1-7 keys)
	"mute": [[KEY_M], [], []],
	"pause": [[KEY_PAUSE], [JOY_BUTTON_START], []],
	# R14 (1b): the last raw keys, as actions. A pad reaches each one by its button, or by a row on screen where noted
	"nudge": [[KEY_N], [JOY_BUTTON_Y], []],  # the escape room: ask for a nudge
	"outing": [[KEY_O], [], []],  # Free Play: take the team out (a pad: the pause menu's FREE PLAY row)
	"mutator": [[KEY_QUOTELEFT], [], []],  # Free Play: the next mutator (a pad: the pause menu's FREE PLAY row)
	"preset": [[KEY_P], [JOY_BUTTON_Y], []],  # character select, the build step: the next preset
	"pray": [[KEY_P], [JOY_BUTTON_Y], []],  # the printer game
	"shake_left": [[KEY_A], [JOY_BUTTON_LEFT_SHOULDER], []],  # the printer game: shake the toner
	"shake_right": [[KEY_D], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"hot_next": [[], [JOY_BUTTON_Y], []],  # the computer's letter hotkeys on a pad: Y steps through them ...
	"hot_go": [[], [JOY_BUTTON_X], []],  # ... and X presses the chosen one (Computer.hot_keys)
	"roll": [[], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]]],  # seated: hold to roll the chair with the stick (the keyboard holds Shift = run)
}

# the name of a key, for the screens that take keys by name (Controls.word): every other key is its letter, digit or F number
const WORDS := {
	KEY_TAB: "tab", KEY_LEFT: "left", KEY_RIGHT: "right", KEY_UP: "up", KEY_DOWN: "down", KEY_ENTER: "enter", KEY_KP_ENTER: "enter",
	KEY_ESCAPE: "esc", KEY_BACKSPACE: "backspace", KEY_SPACE: "space", KEY_PAGEUP: "pgup", KEY_PAGEDOWN: "pgdn",
	KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_QUOTELEFT: "`", KEY_SHIFT: "shift",
}

# the words a hint line uses for the menu keys -> the menu role (MENU_ROLES) that key belongs to
const HINT_ROLES := {"ENTER": "menu_confirm", "ESC": "menu_back", "UP": "menu_up", "DOWN": "menu_down", "LEFT": "menu_left", "RIGHT": "menu_right", "Z": "game_a", "X": "game_b", "SHIFT": "game_cool"}
# what a pad shows for those words (the arrows stay: the D-pad has them)
const HINT_PAD := {"ENTER": "(A)", "SPACE": "(A)", "ESC": "(B)", "ARROWS": "STICK", "TAB": "(RB)", "Z": "(A)", "X": "(B)", "SHIFT": "(B)", "E": "(A)"}
# the words of a walking-around prompt (the HUD hint, the room hints) -> the action
const HINT_WORLD := {"E": "interact", "P": "phone", "Q": "wave", "F": "drink", "SPACE": "jump", "SHIFT": "run", "TAB": "pick_next", "Z": "aim"}

# menu directions by key: the arrows always, the letters when a screen asks for them
const NAV_ARROWS := {KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right"}
const NAV_LETTERS := {KEY_W: "up", KEY_S: "down", KEY_A: "left", KEY_D: "right"}

# the help page of the pause menu: pages of [what, keys]
# the walking-around actions a player can put on another key (the menus and mini-games keep their own keys); one key per action
const REMAPPABLE := ["move_left", "move_right", "jump", "run", "interact", "wave", "drink", "duck", "dance", "follow", "phone", "aim", "outfit", "career"]

# the pad actions a player can put on another button (A / B / X / Y / shoulders and so on); the movement stays on the stick and D-pad
const REMAPPABLE_PAD := ["jump", "run", "interact", "wave", "drink", "phone", "pick_next"]

# the key list's rows that follow a remap (row label -> action)
const HELP_ACTIONS := {"JUMP": "jump", "RUN": "run", "DUCK": "duck", "USE, SIT, DOORS": "interact", "CELL PHONE": "phone", "WAVE": "wave", "SIP YOUR DRINK": "drink", "DANCE": "dance", "FOLLOW ME": "follow", "CAREER SCREEN": "career"}

# the keys the menus and mini-games read as fixed keys: a player can put an extra key on each (the plain key keeps working too).
# [role, the key the screens look for, the label]
const MENU_ROLES := [
	["menu_confirm", KEY_ENTER, "MENU CONFIRM"], ["menu_back", KEY_ESCAPE, "MENU BACK"],
	["menu_up", KEY_UP, "MENU UP"], ["menu_down", KEY_DOWN, "MENU DOWN"],
	["menu_left", KEY_LEFT, "MENU LEFT"], ["menu_right", KEY_RIGHT, "MENU RIGHT"],
	["game_a", KEY_Z, "GAME A (Z)"], ["game_b", KEY_X, "GAME B (X)"], ["game_cool", KEY_SHIFT, "GAME COOL SIDE"],
]
# keys an alias may never take (the plain menu keys, pause, the debug keys)
const MENU_RESERVED := [KEY_SPACE, KEY_E, KEY_TAB, KEY_BACKSPACE, KEY_KP_ENTER, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10, KEY_F11, KEY_F12]

const HELP := [
	[
		"MOVING AND USING",
		[
			["MOVE", "A D OR ARROWS"],
			["JUMP", "SPACE OR W"],
			["RUN", "HOLD SHIFT"],
			["DUCK", "S OR DOWN"],
			["USE, SIT, DOORS", "E"],
			["PICK A TARGET", "TAB, SHIFT TAB"],
			["CELL PHONE", "P"],
			["PAUSE, HELP", "ESC OR PAUSE"],
		],
	],
	[
		"PEOPLE AND SEATS",
		[
			["ROLL YOUR CHAIR", "SHIFT + A D (SEATED)"],
			["STAND UP", "ANY MOVE KEY OR E"],
			["WAVE", "Q"],
			["SIP YOUR DRINK", "F"],
			["DANCE", "X (FREE PLAY ENDS IT)"],
			["FOLLOW ME", "C, NEXT TO A COWORKER"],
			["TALK", "E, NEXT TO A COWORKER"],
			["MUTE SOUND", "M"],
		],
	],
	[
		"GAMES AND EXTRAS",
		[
			["FIRE A DART", "TAP Z"],
			["LONG SHOT", "HOLD Z, RELEASE"],
			["START A WAR, GIVE", "V, G"],
			["CHAIR RACE PUSH", "Z X IN TURN"],
			["CHAIR RACE STEER", "ARROWS"],
			["BOWLING AND ESCAPE", "E"],
			["KARAOKE LANES", "ARROWS"],
			["SHAPE, OUTFIT", "F9, Y (FREE PLAY)"],
			["CAREER SCREEN", "J (FREE PLAY)"],
		],
	],
]


var rumble_on := true  # pad rumble for hits, strikes and crashes (co-op phase 8)
var binds_path := "user://controls.cfg"
var capturing := false  # the remap page is waiting for a key: nothing is translated
var pad_active := false  # the last press came from a pad (the hint lines then show pad buttons)
var touch_override := -1  # -1 = ask the display server, 0 = never, 1 = always (tests): the touch overlay
var touch: CanvasLayer = null  # the touch overlay (scripts/touch_overlay.gd); only exists on a touch screen
var _overrides := {}  # action -> the physical key code it was remapped to
var _pad_overrides := {}  # action -> the joypad button it was remapped to
var _alias := {}  # physical key -> the key a menu or mini-game screen looks for (MENU_ROLES)
var _stick := {}
var _slot_device := {}  # slot -> the pad device its p2_ actions are registered for
var _stick_event: InputEvent = null
var _stick_frame := -1
var _stick_result := false


func _ready() -> void:
	ensure()
	load_binds()
	touch_refresh.call_deferred()


# make (or remove) the touch overlay to match touch_on(). It is the last child of the root so it sees a touch before any
# screen does (input goes to the last nodes first) and stays last when a scene is swapped in.
func touch_refresh() -> void:
	var want := touch_on()
	var root := get_tree().root
	if want and touch == null:
		touch = TOUCH_OVERLAY.new()
		touch.name = "TouchOverlay"
		root.add_child(touch)
		root.child_entered_tree.connect(_keep_touch_last)
	elif not want and touch != null:
		root.child_entered_tree.disconnect(_keep_touch_last)
		touch.queue_free()
		touch = null


func _keep_touch_last(node: Node) -> void:
	if touch != null and node != touch:
		get_tree().root.move_child.call_deferred(touch, -1)


# register every action that is missing (the player and the tests may also call this; it is safe to repeat)
func ensure() -> void:
	# the menu actions need the pad's A and B (Godot's own defaults leave them out in some builds)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		if InputMap.has_action(pair[0]) and not _has_button(pair[0], pair[1]):
			var btn := InputEventJoypadButton.new()
			btn.button_index = pair[1]
			InputMap.action_add_event(pair[0], btn)
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		var spec: Array = ACTIONS[action]
		for code in spec[0]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
			if code == KEY_SHIFT:  # macOS reports the modifier keys by their logical key: bind that too (either shift, any layout)
				var logical := InputEventKey.new()
				logical.keycode = code
				InputMap.action_add_event(action, logical)
		for button in spec[1]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			InputMap.action_add_event(action, pad)
		for ax in spec[2]:
			var motion := InputEventJoypadMotion.new()
			motion.axis = ax[0]
			motion.axis_value = ax[1]
			InputMap.action_add_event(action, motion)


# co-op (docs/scope-coop.md 5.1): slot 0 keeps the plain action names, slot 1 uses a p2_ copy of the whole table that only
# listens to its own joypad device. "" for slot 0, "p2_" for slot 1.
func prefix(slot: int) -> String:
	return "" if slot <= 0 else "p%d_" % (slot + 1)


# the action name that slot `slot` reads: action_for(1, "jump") = "p2_jump"
func action_for(slot: int, action: String) -> String:
	return prefix(slot) + action


# the joypad a slot's rumble goes to: slot 0 is pad 0, slot 1 the pad it joined with; -1 when there is none connected
func rumble_device(slot: int) -> int:
	var device := 0 if slot <= 0 else int(Players.slot(slot).device)
	return device if device >= 0 and Input.get_connected_joypads().has(device) else -1


func rumble(slot: int, strength := 0.5, secs := 0.2) -> void:
	var device := rumble_device(slot)
	if rumble_on and device >= 0:
		Input.start_joy_vibration(device, clampf(strength * 0.6, 0.0, 1.0), clampf(strength, 0.0, 1.0), secs)


# a pressed alias key reaches the screens as the key they look for. Controls is the first autoload, so this runs before any
# screen; the typing screens (the name row, the seed field) are left alone so letters still type.
func _input(event: InputEvent) -> void:
	_note_device(event)
	if _alias.is_empty() or capturing or not event is InputEventKey:
		return
	var canon: int = _alias.get(int(event.physical_keycode), 0)
	if canon == 0 or typing():
		return
	var key := event.duplicate() as InputEventKey
	key.keycode = canon as Key
	key.physical_keycode = canon as Key
	key.unicode = 0
	get_viewport().set_input_as_handled()
	Input.parse_input_event(key)


# a screen where letters are typed (nodes in the group "typing_screen" answer is_typing())
func typing() -> bool:
	for n in get_tree().get_nodes_in_group("typing_screen"):
		if n.has_method("is_typing") and n.is_typing():
			return true
	return false


# the extra key on a menu role (-1 for none)
func menu_key_of(role: String) -> int:
	for code in _alias:
		for r in MENU_ROLES:
			if r[0] == role and int(r[1]) == int(_alias[code]):
				return int(code)
	return -1


# put an extra key on a menu role. False for the plain menu keys, a walking key, the debug keys or an unknown role. A key
# another role had moves here.
func rebind_menu(role: String, code: int) -> bool:
	var canon := 0
	for r in MENU_ROLES:
		if r[0] == role:
			canon = int(r[1])
	if canon == 0 or code <= 0 or code in MENU_RESERVED:
		return false
	for r in MENU_ROLES:
		if int(r[1]) == code:
			return false
	for action in ACTIONS:
		if key_of(action) == code or code in ACTIONS[action][0]:
			return false  # a key something else in the game already answers to
	for old in _alias.keys():
		if int(_alias[old]) == canon:
			_alias.erase(old)
	_alias[code] = canon
	return true


# the physical key an action answers to on the keyboard (its first default key until it is remapped); -1 for none
func key_of(action: String) -> int:
	if _overrides.has(action):
		return int(_overrides[action])
	var keys: Array = ACTIONS[action][0] if ACTIONS.has(action) else []
	return int(keys[0]) if not keys.is_empty() else -1


# put `action` on `code` (and swap: whoever had that key gets this action's old key). Only REMAPPABLE actions; true when done
func rebind(action: String, code: int) -> bool:
	if not REMAPPABLE.has(action) or code <= 0:
		return false
	var old := key_of(action)
	for other in REMAPPABLE:
		if other != action and key_of(other) == code:
			_apply_key(other, old)
	_alias.erase(code)  # a walking key is not also a menu alias
	_apply_key(action, code)
	return true


# the name of a physical key
func key_name(code: int) -> String:
	if DisplayServer.get_name() == "headless":  # no keyboard layout to ask (tests): the key as it is
		return OS.get_keycode_string(code).to_upper()
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code)).to_upper()


# what the key list prints for a row: the default text, or the key the action was remapped to
func help_value(label: String, text: String) -> String:
	if label == "MOVE" and (_overrides.has("move_left") or _overrides.has("move_right")):
		return "%s %s" % [key_name(key_of("move_left")), key_name(key_of("move_right"))]
	var action := str(HELP_ACTIONS.get(label, ""))
	if action != "" and _overrides.has(action):
		return key_name(key_of(action))
	return text


# a short name for a pad button (the Xbox-style layout the bindings are written for)
func button_name(button: int) -> String:
	var names := ["A", "B", "X", "Y", "BACK", "GUIDE", "START", "L3", "R3", "LB", "RB", "UP", "DOWN", "LEFT", "RIGHT"]
	return names[button] if button >= 0 and button < names.size() else "BTN %d" % button


# the pad button an action answers to (its first default button until it is remapped); -1 for none
func button_of(action: String) -> int:
	if _pad_overrides.has(action):
		return int(_pad_overrides[action])
	var buttons: Array = ACTIONS[action][1] if ACTIONS.has(action) else []
	return int(buttons[0]) if not buttons.is_empty() else -1


# put `action` on pad button `button` (a clash swaps), for the first player's pad and the second player's copy of the action
func rebind_button(action: String, button: int) -> bool:
	if not REMAPPABLE_PAD.has(action) or button < 0:
		return false
	var old := button_of(action)
	for other in REMAPPABLE_PAD:
		if other != action and button_of(other) == button:
			_apply_button(other, old)
	_apply_button(action, button)
	return true


func _apply_button(action: String, button: int) -> void:
	for name in [action, "p2_" + action]:
		if not InputMap.has_action(name):
			continue
		var device := 0
		var seen := false
		for ev in InputMap.action_get_events(name):
			if ev is InputEventJoypadButton:
				if not seen:
					device = ev.device
					seen = true
				InputMap.action_erase_event(name, ev)
		if button >= 0:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			pad.device = device
			InputMap.action_add_event(name, pad)
	_pad_overrides[action] = button


func _apply_key(action: String, code: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	if code > 0:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)
	_overrides[action] = code


# back to the default keys
func reset_binds() -> void:
	for action in _overrides.keys():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		for code in ACTIONS[action][0]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)
	_overrides = {}
	for action in _pad_overrides.keys():
		var buttons: Array = ACTIONS[action][1]
		if not buttons.is_empty():
			_apply_button(action, int(buttons[0]))
	_pad_overrides = {}
	_alias = {}


func save_binds() -> void:
	var cfg := ConfigFile.new()
	for code in _alias:
		cfg.set_value("menu", str(int(code)), int(_alias[code]))
	for action in _overrides:
		cfg.set_value("binds", action, int(_overrides[action]))
	for action in _pad_overrides:
		cfg.set_value("pad", action, int(_pad_overrides[action]))
	if _overrides.is_empty() and _pad_overrides.is_empty() and _alias.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(binds_path))
	else:
		cfg.save(binds_path)


func load_binds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(binds_path) != OK:
		return
	if cfg.has_section("binds"):
		for action in cfg.get_section_keys("binds"):
			rebind(str(action), int(cfg.get_value("binds", action, 0)))
	if cfg.has_section("menu"):
		for code in cfg.get_section_keys("menu"):
			var canon: int = int(cfg.get_value("menu", code, 0))
			for r in MENU_ROLES:
				if int(r[1]) == canon:
					rebind_menu(str(r[0]), int(code))
	if cfg.has_section("pad"):
		for action in cfg.get_section_keys("pad"):
			rebind_button(str(action), int(cfg.get_value("pad", action, -1)))


# register slot's actions for joypad `device` (safe to repeat; a new device re-binds). Only called while co-op is on
# (Players.enable_coop / join), so single player never sees a p2_ action. Pad 2 needs its own confirm and cancel: the
# built-in ui_accept / ui_cancel listen to device 0 only, so p2_ui_accept / p2_ui_cancel carry A and B for the device.
func ensure_slot(slot: int, device: int) -> void:
	if slot <= 0 or _slot_device.get(slot, -2) == device:
		return
	_slot_device[slot] = device
	var pfx := prefix(slot)
	for action in ACTIONS:
		var spec: Array = ACTIONS[action]
		var events := []
		for button in spec[1]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			pad.device = device
			events.append(pad)
		for ax in spec[2]:
			var motion := InputEventJoypadMotion.new()
			motion.axis = ax[0]
			motion.axis_value = ax[1]
			motion.device = device
			events.append(motion)
		_rebind(pfx + action, events)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var btn := InputEventJoypadButton.new()
		btn.button_index = pair[1]
		btn.device = device
		_rebind(pfx + pair[0], [btn])


func _rebind(name: String, events: Array) -> void:
	if InputMap.has_action(name):
		InputMap.action_erase_events(name)
	else:
		InputMap.add_action(name, 0.5)
	for ev in events:
		InputMap.action_add_event(name, ev)


# which player an event belongs to (see Players.slot_of): keys are slot 0, a pad is the slot that joined on its device
func slot_of(event: InputEvent) -> int:
	return Players.slot_of(event)


# confirm / back for a slot: slot 0 is the plain confirm() / back() (Enter, Space, E or its pad A), slot 1 is the A / B of
# its own pad only. An event that belongs to another slot is never a confirm.
func confirm_for(event: InputEvent, slot: int, with_e: bool = true, with_space: bool = true) -> bool:
	if slot_of(event) != slot:
		return false
	if slot <= 0:
		return confirm(event, with_e, with_space)
	return event.is_action(prefix(slot) + "ui_accept")


func back_for(event: InputEvent, slot: int, with_backspace: bool = true) -> bool:
	if slot_of(event) != slot:
		return false
	if slot <= 0:
		return back(event, with_backspace)
	return event.is_action(prefix(slot) + "ui_cancel")


func _has_button(action: String, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return true
	return false


# is this event the action? Plain key events (from tests, or keys with no physical code) are compared by key code
func matches(event: InputEvent, action: String) -> bool:
	if not ACTIONS.has(action):
		return false
	if event.is_action(action):
		return true
	if _overrides.has(action):
		return false  # a remapped action answers to its new key only
	if event is InputEventKey:
		if action == "pick_prev":
			return event.keycode == KEY_TAB and event.shift_pressed
		if action == "pick_next" and event.shift_pressed:
			return false
		return event.keycode in ACTIONS[action][0]
	return false


# Enter, Space or E (a screen that never took Space or E passes false), or the ui_accept action from a pad
func confirm(event: InputEvent, with_e: bool = true, with_space: bool = true) -> bool:
	if event is InputEventKey:
		var codes: Array = [KEY_ENTER, KEY_KP_ENTER]
		if with_space:
			codes.append(KEY_SPACE)
		if with_e:
			codes.append(KEY_E)
		return event.keycode in codes
	return event.is_action("ui_accept")


# a team card in co-op: confirm / back from either player (slot 1's own pad A / B too), the first one wins
func confirm_any(event: InputEvent, with_e: bool = true, with_space: bool = true) -> bool:
	return confirm(event, with_e, with_space) or (Players.coop and event.is_action(prefix(1) + "ui_accept"))


func back_any(event: InputEvent, with_backspace: bool = true) -> bool:
	return back(event, with_backspace) or (Players.coop and event.is_action(prefix(1) + "ui_cancel"))


# Esc or Backspace (a screen that only took Esc passes false), or the ui_cancel action from a pad
func back(event: InputEvent, with_backspace: bool = true) -> bool:
	if event is InputEventKey:
		return event.keycode == KEY_ESCAPE or (with_backspace and event.keycode == KEY_BACKSPACE)
	return event.is_action("ui_cancel")


# a fresh press: a key (not a repeat), a pad button, an action, or a stick pushed past half way (once per push).
# Screens guard their handlers with this instead of `event is InputEventKey and event.pressed and not event.echo`
func pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton or event is InputEventAction:
		return event.pressed
	if event is InputEventJoypadMotion:
		return _stick_push(event)
	return false


# "up", "down", "left" or "right" for a fresh press of an arrow (and W A S D when letters is true), a D-pad button or
# a stick push (the ui_up / ui_down / ui_left / ui_right actions); "" for anything else
func nav(event: InputEvent, letters: bool = true) -> String:
	if not pressed(event):
		return ""
	if event is InputEventKey:
		if NAV_ARROWS.has(event.keycode):
			return NAV_ARROWS[event.keycode]
		return NAV_LETTERS.get(event.keycode, "") if letters else ""
	if event is InputEventJoypadMotion:
		# the left stick, by hand: is_action() does not tell up from down on an axis
		if event.axis == JOY_AXIS_LEFT_X:
			return "right" if event.axis_value > 0.0 else "left"
		return ("down" if event.axis_value > 0.0 else "up") if event.axis == JOY_AXIS_LEFT_Y else ""
	for dir in ["up", "down", "left", "right"]:
		if event.is_action("ui_" + dir):
			return dir
	return ""


# -1 for up / left, 1 for down / right, 0 for none: the step a list or a carousel takes (vertical: up and down only,
# otherwise left and right only)
func step(event: InputEvent, vertical: bool, letters: bool = true) -> int:
	var d := nav(event, letters)
	if vertical:
		return -1 if d == "up" else (1 if d == "down" else 0)
	return -1 if d == "left" else (1 if d == "right" else 0)


# stick events repeat on every wobble: only the move from inside the dead zone to past half way counts, and every
# screen that looks at the same event gets the same answer
func _stick_push(event: InputEventJoypadMotion) -> bool:
	var frame := Engine.get_process_frames()
	if event == _stick_event and frame == _stick_frame:
		return _stick_result
	_stick_event = event
	_stick_frame = frame
	var key: int = event.device * 32 + event.axis
	var now := 0
	if absf(event.axis_value) >= 0.5:
		now = 1 if event.axis_value > 0.0 else -1
	var was: int = _stick.get(key, 0)
	_stick[key] = now
	_stick_result = now != 0 and now != was
	return _stick_result


# ---- keys by name (R14 1b): no script outside this file reads a raw key code (tests/raw_keys.gd) ----
# the name of a key event or key code: "a".."z", "0".."9" ("kp0".."kp9" on the keypad), "f1".."f12", or a WORDS entry; "" else
func word(what: Variant) -> String:
	var code := 0
	if what is InputEventKey:
		code = what.keycode
	elif typeof(what) == TYPE_INT:
		code = what
	if code >= KEY_A and code <= KEY_Z:
		return char(code).to_lower()
	if code >= KEY_0 and code <= KEY_9:
		return str(code - KEY_0)
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return "kp%d" % (code - KEY_KP_0)
	if code >= KEY_F1 and code <= KEY_F12:
		return "f%d" % (code - KEY_F1 + 1)
	return str(WORDS.get(code, ""))


# 0..9 for a digit key (the keypad too when asked), -1 for anything else
func digit(event: InputEvent, keypad: bool = false) -> int:
	var w := word(event)
	if w.length() == 1 and w >= "0" and w <= "9":
		return int(w)
	if keypad and w.begins_with("kp"):
		return int(w.substr(2))
	return -1


# 1..12 for an F key, 0 for anything else
func fkey(event: InputEvent) -> int:
	var w := word(event)
	return int(w.substr(1)) if w.length() >= 2 and w.begins_with("f") and w.substr(1).is_valid_int() else 0


# the physical key of a key event (what a remap stores), 0 for anything else
func physical(event: InputEvent) -> int:
	return int(event.physical_keycode) if event is InputEventKey else 0


# press an action from code (a menu row or the touch overlay standing in for its key): the screens that ask
# Controls.pressed(event) and Controls.matches(event, action) take it like the key
func tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


# the modifiers of a key event
func shift(event: InputEvent) -> bool:
	return event is InputEventKey and event.shift_pressed


func ctrl(event: InputEvent) -> bool:
	return event is InputEventKey and event.ctrl_pressed


func alt(event: InputEvent) -> bool:
	return event is InputEventKey and event.alt_pressed


# either Shift is down right now (macOS reports the modifiers by their logical key, so the run action alone can miss it)
func shift_held() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


# the character a key event types ("" for none): text entry (a name, a number)
func typed(event: InputEvent) -> String:
	if not event is InputEventKey:
		return ""
	if event.unicode > 0:
		return char(event.unicode)
	if event.keycode >= KEY_A and event.keycode <= KEY_Z:
		return char(event.keycode)
	return ""


# ---- what the hint lines print (R34: a hint shows the key or pad button that works NOW, not the default letter) ----
func _note_device(event: InputEvent) -> void:
	var pad := pad_active
	if event is InputEventJoypadButton:
		pad = pad or event.pressed
	elif event is InputEventJoypadMotion:
		pad = pad or absf(event.axis_value) >= 0.5
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		pad = false
	pad_active = pad


# the touch overlay is wanted: a touch screen (or the test override)
func touch_on() -> bool:
	if touch_override >= 0:
		return touch_override == 1
	return DisplayServer.is_touchscreen_available()


# the current binding of an action or a menu role, as a hint prints it: the key's name, or "(A)" style for a pad button
func label(action: String) -> String:
	if pad_active:
		for role in HINT_ROLES:
			if HINT_ROLES[role] == action and HINT_PAD.has(role):
				return str(HINT_PAD[role])
		if ACTIONS.has(action):
			var button := button_of(action)
			if button >= 0:
				return "(%s)" % button_name(button)
			for ax in ACTIONS[action][2]:
				if ax[0] == JOY_AXIS_TRIGGER_RIGHT or ax[0] == JOY_AXIS_TRIGGER_LEFT:
					return "(RT)" if ax[0] == JOY_AXIS_TRIGGER_RIGHT else "(LT)"
				return "STICK"
	for r in MENU_ROLES:
		if r[0] == action:
			var extra := menu_key_of(action)
			return key_name(extra) if extra > 0 else str(HINT_ROLES.find_key(action))
	var code := key_of(action)
	return key_name(code) if code > 0 else ""


# a hint line with its key words swapped for what works now: a remapped menu key shows its new key, a pad shows its buttons.
# `map` adds this screen's own letters ({"P": "pray"}: word -> action). With the default keys on a keyboard the text is unchanged.
func hint(text: String, map: Dictionary = {}) -> String:
	if not pad_active and _overrides.is_empty() and _alias.is_empty():
		return text
	var out := ""
	var token := ""
	for i in text.length() + 1:
		var ch := text[i] if i < text.length() else ""
		if ch != "" and ((ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
			token += ch
			continue
		out += _hint_word(token, map) + ch
		token = ""
	return out.replace("((", "(").replace("))", ")")


# the same for a walking-around prompt ("E: SIT", "P: PHONE"): the walking actions follow their remap
func world_hint(text: String) -> String:
	return hint(text, HINT_WORLD)


func _hint_word(token: String, map: Dictionary) -> String:
	if token == "":
		return ""
	if map.has(token):
		var action := str(map[token])
		if pad_active or _overrides.has(action):
			var shown := label(action)
			return shown if shown != "" else token
		return token
	if pad_active:
		return str(HINT_PAD.get(token, token))
	if HINT_ROLES.has(token):
		var extra := menu_key_of(str(HINT_ROLES[token]))
		return key_name(extra) if extra > 0 else token
	return token
