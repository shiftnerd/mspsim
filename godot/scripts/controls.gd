extends Node
# gdlint:disable=max-line-length
# Autoload: the one place that says which key (and which gamepad button) does what (roadmap R14, portability).
# Every control is a named InputMap action registered here at startup; scripts ask for the action instead of a raw
# key, so a controller or a touch layer can be added later without touching the game scripts.
#   Controls.matches(event, "push_a")   true when a key event is one of the action's keys, or the action itself
#                                       (tests send plain key events, a gamepad sends the action)
#   Controls.confirm(event) / back(event)  Enter, Space or E / Esc or Backspace, or the ui_accept / ui_cancel actions
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


func _ready() -> void:
	ensure()


# register every action that is missing (the player and the tests may also call this; it is safe to repeat)
func ensure() -> void:
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


func confirm(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E] or event.is_action("ui_accept")
	return event.is_action("ui_accept")


func back(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.keycode in [KEY_ESCAPE, KEY_BACKSPACE] or event.is_action("ui_cancel")
	return event.is_action("ui_cancel")
