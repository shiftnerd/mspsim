extends SceneTree
# R14 (1b), the guard: no script outside scripts/controls.gd reads a raw key. Every key goes through the Controls autoload
# (an action with a key and a pad binding, or Controls.word / digit / typed for keys by name and text entry), so a pad or a
# touch layer reaches the same functions and a new raw read cannot slip back in.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/raw_keys.gd
# A hit fails with the file and the line. The allow list is short on purpose:
#   outings.gd  keeps KEY_ constants as the vocabulary of its game logic: Outings._event_key turns every key, pad button and
#               stick push into one of them, so they are names there, not key reads. Its two raw letter reads (N nudge and
#               O outing) are Controls actions now and must stay gone.

const RAW := "\\bKEY_[A-Z0-9_]+\\b|is_key_pressed|is_physical_key_pressed|\\.keycode\\b|\\.physical_keycode\\b|\\.unicode\\b"
const ALLOW_FILES := ["controls.gd", "outings.gd"]
# what even the allowed vocabulary file may not hold any more
const GONE := {"outings.gd": ["KEY_N", "KEY_O"]}

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


# a line of code without its string literals and its comment
func _code(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quote != "":
			if ch == "\\":
				i += 1
			elif ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			break
		else:
			out += ch
		i += 1
	return out


func _key(code: Key, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	return e


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _run() -> void:
	await process_frame
	var raw := RegEx.new()
	raw.compile(RAW)
	var files := 0
	var hits := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd"):
			continue
		files += 1
		var lines := FileAccess.get_file_as_string("res://scripts/" + f).split("\n")
		for n in lines.size():
			var code := _code(lines[n])
			if not f in ALLOW_FILES and raw.search(code) != null:
				hits += 1
				_check(false, "%s:%d reads a raw key: %s" % [f, n + 1, lines[n].strip_edges().substr(0, 90)])
			for word in GONE.get(f, []):
				var re := RegEx.new()
				re.compile("\\b" + str(word) + "\\b")
				if re.search(code) != null:
					hits += 1
					_check(false, "%s:%d still has %s: %s" % [f, n + 1, word, lines[n].strip_edges().substr(0, 90)])
	_check(files > 100,"scanned the scripts (%d files)" % files)
	_check(hits == 0, "no raw key reads outside controls.gd")
	# the scanner catches what it should, and leaves text and comments alone
	_check(raw.search(_code("\tif event.keycode == KEY_F9:")) != null, "a keycode compare is caught")
	_check(raw.search(_code("\tif Input.is_key_pressed(x):")) != null, "is_key_pressed is caught")
	_check(raw.search(_code("\tsay(\"PRESS KEY_A\")  # KEY_B in a comment")) == null, "strings and comments are not code")
	# the helpers the scripts use instead
	var c := root.get_node("Controls")
	_check(c.word(_key(KEY_C)) == "c" and c.word(_key(KEY_TAB)) == "tab" and c.word(_key(KEY_F9)) == "f9", "word: letters, names, F keys")
	_check(c.word(_key(KEY_PAGEUP)) == "pgup" and c.word(_key(KEY_KP_ENTER)) == "enter" and c.word(KEY_Q) == "q", "word: page keys, keypad Enter, a bare code")
	_check(c.word(_pad(JOY_BUTTON_A)) == "" and c.word(null) == "", "word: nothing for a pad button")
	_check(c.digit(_key(KEY_3)) == 3 and c.digit(_key(KEY_KP_3)) == -1 and c.digit(_key(KEY_KP_3), true) == 3, "digit: top row, the keypad only when asked")
	_check(c.digit(_key(KEY_A)) == -1 and c.fkey(_key(KEY_F11)) == 11 and c.fkey(_key(KEY_F)) == 0, "digit and fkey refuse letters")
	_check(c.shift(_key(KEY_M, true)) and not c.shift(_key(KEY_M)), "shift")
	var typed := _key(KEY_B)
	_check(c.typed(typed) == "B", "typed: a letter without a unicode value")
	typed.unicode = 45
	_check(c.typed(typed) == "-", "typed: the unicode value wins")
	# every function that had a raw key is an action with a key; the ones without a pad button have a row on screen
	for pair in [["nudge", KEY_N], ["outing", KEY_O], ["mutator", KEY_QUOTELEFT], ["preset", KEY_P], ["pray", KEY_P], ["shake_left", KEY_A], ["shake_right", KEY_D]]:
		_check(c.matches(_key(pair[1]), pair[0]) and InputMap.has_action(pair[0]), "the %s action has its key" % pair[0])
	var pads := [["nudge", JOY_BUTTON_Y], ["preset", JOY_BUTTON_Y], ["pray", JOY_BUTTON_Y], ["shake_left", JOY_BUTTON_LEFT_SHOULDER]]
	pads.append_array([["shake_right", JOY_BUTTON_RIGHT_SHOULDER], ["hot_next", JOY_BUTTON_Y], ["hot_go", JOY_BUTTON_X], ["character_next", JOY_BUTTON_RIGHT_STICK]])
	for pair in pads:
		_check(c.matches(_pad(pair[1]), pair[0]), "the %s action has its pad button" % pair[0])
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	_check(lt.is_action("roll"), "the roll action is on the left trigger")
	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
