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
	"offer_war": [[KEY_V], [JOY_BUTTON_Y], []],
	"give_item": [[KEY_G], [], []],
	"phone": [[KEY_P], [JOY_BUTTON_BACK], []],
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
			["SCREEN SHAPE", "F9"],
		],
	],
]


var _stick := {}
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
		for button in spec[1]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			InputMap.action_add_event(action, pad)
		for ax in spec[2]:
			var motion := InputEventJoypadMotion.new()
			motion.axis = ax[0]
			motion.axis_value = ax[1]
			InputMap.action_add_event(action, motion)


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
