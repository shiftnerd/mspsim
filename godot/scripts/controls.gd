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
}

# menu directions by key: the arrows always, the letters when a screen asks for them
const NAV_ARROWS := {KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right"}
const NAV_LETTERS := {KEY_W: "up", KEY_S: "down", KEY_A: "left", KEY_D: "right"}

# the help page of the pause menu: pages of [what, keys]
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


var _stick := {}
var _slot_device := {}  # slot -> the pad device its p2_ actions are registered for
var _stick_event: InputEvent = null
var _stick_frame := -1
var _stick_result := false


func _ready() -> void:
	ensure()


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
