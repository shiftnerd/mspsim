extends "res://tests/layout_audit.gd"
# gdlint:disable=max-line-length
# Pad prompt scanner (roadmap R42 item 1, "glyphs everywhere"): with a pad as the active input, no text on screen may name a
# keyboard key or the mouse as a prompt (Valve's Deck Verified checklist and Microsoft's handheld guidance both ask for it).
# It walks every screen of tests/layout_audit.gd (this script extends it and shares its walker) plus the screens of
# _extra_phase() below, once as a keyboard and once as a pad, and then tries the switch:
#   1. keyboard: every keyboard prompt line recorded in tests/pad_prompts_keyboard.txt must still be drawn as it was
#      (the keyboard's text stays byte-identical; `-- --golden` rewrites the file after a deliberate change)
#   2. pad: every drawn text is scanned with the patterns in _compile() (ALLOW holds the words that are content, not prompts);
#      text that leaves the viewport fails here too, in every format (a pad token can be wider than the letter it replaces)
#   3. live: a pad button, a key and a mouse move switch the prompts of an open screen without anything else redrawing it
# Runs headless in about 30 s:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/pad_prompts.gd [-- --list] [-- --golden]
# `--list` prints every offending line with the screen it was first seen on; `--only=extra` walks only _extra_phase().

const GOLDEN := "res://tests/pad_prompts_keyboard.txt"
# words that are content, not prompts. A line is scanned with these cut out of it.
const ALLOW := [
	["\\bVERTICAL MOUSE\\b|\\bMOUSE (CORDS|PAD)\\b", "a mouse as a thing: the web shop, an escape room clue"],
	["\\bA/R\\b", "accounts receivable (the owner's books)"],
	["\\(N\\) = THE OUTING", "the dinner's legend: (2) is the outing a fact was learned at"],
	["\\bL R\\b|\\bU/D\\b|\\bL/R\\b|\\bHOOK [LR]\\b", "left / right and up / down, short: directions, which a pad has too"],
	["\\bCUSTOM TAB\\b|\\bTAB WITH A\\b|\\b(PROJECT|CAPACITY) TAB\\b|\\bTHE TAB\\b", "a tab of an app (forum threads, the RMM), and the dinner's bill"],
	["\\bESC THIS WEEK|\\bESC [0-9]+ \\(LAST", "escalations (the owner's hours, the growth line)"],
	["\\bG OPPOSES", "Garrison's initial on a partner card's trust chip"],
	["\\bH [0-9.]+/[0-9.]+|[0-9] ?[HS]\\b(?! ?=)", "hours and seconds: H 5.0/5.0, (2 H), 14.5 S"],
	["[0-9] X [0-9]", "a multiplication on the escape room's chalkboard"],
	["\\bSALON D\\b|\\bARCH D\\b|\\bDRIVE C\\b", "a conference room, a paper size, a disk"],
	["\\bSHAPE: [HV]\\b", "the screen shape setting (h, v)"],
	["\\b(TICKET|PHONE|NIGHT|ONE) SHIFT\\b|\\bSHIFT DONE\\b", "a work shift"],
	["\\b(DISK|NEW|FREE|MAILBOX) SPACE\\b|\\bSPACE HEATERS?\\b", "room on a disk, room in an office"],
	["\\bSTILL CLICK EVERYTHING|\\bCLICK[.,] ", "the users click, and the sound of a switch; story text"],
	["\\bIT CLICKS\\b|\\bDIAL CLICKS\\b|\\bCLICKS (OPEN|OFF)\\b|\\bCLICK\\. (IT|THE [A-Z ]+) SEATS", "the sound a part makes (printer answers, a door, the vault's dial)"],
	["\\b[BC] = (RIGHT|WRONG) PLACE", "the vault dial's feedback letters"],
	["\\bHIT THE ARROWS AS\\b", "karaoke: the notes on screen are arrows"],
	["\\bHAS A KEY\\b", "a client's door key (the takeover checklist)"],
	["\\b(RE-)?ENTER (IT|THE CODE|WHAT YOU FOUND|THE ACCOUNT)\\b", "to enter a code, as a verb"],
	["\\bC IS A STEADY DAY|\\bDAYS: S [0-9]", "grades: the day report's C, the service desk's count of S A B C D days"],
	["\\b[A-Z]{3,}, [A-Z]  |\\bBANKS V\\. COUNTY", "names on a client's screen (a dentist's schedule, a case file)"],
]
# story text in sentence case (mail, chats, card text: any line with a small letter) talks about disk space, night shifts and
# users who click things. There only these count as a prompt: "press P", "(P)", "the Enter key"
const PROSE := "\\b(PRESS|HIT|HOLD|TAP) (THE )?([B-HJ-Z]|ENTER|ESC|TAB|SPACE|SHIFT|CTRL|F[0-9]+)\\b|(?<![A-Z0-9])\\(([B-HJ-Z]|ESC|ENTER|TAB)\\)|\\b([B-HJ-Z]|ENTER|ESC|TAB|SHIFT|CTRL|ARROW) KEYS?\\b"
# the screens where a text of one letter is a cell of a grid or a grade, not a key (everywhere else it is scanned)
const SINGLE_OK := [
	"creator name grid",  # the pad's on-screen letters
	"day report",  # the grade
	"dispatch score",  # the grade bands C B A S
	"crm record", "crm list",  # a lead's heat: H W C
	"toolbox seed page",  # the seed's hex digits
	"touch overlay",  # the overlay's own A and B buttons
	"grill", "outing grill",  # how done a patty is: R M W D X
]
# what a pad prompt may say: the button tokens of Controls.label / PadGlyphs and the right stick's directions
const PAD_TOKENS := "\\((A|B|X|Y|LB|RB|LT|RT|START|BACK|L3|R3|UP|DOWN|LEFT|RIGHT)\\)|\\bRS (UP|DOWN|LEFT|RIGHT)\\b"
const MUST_FLAG := [
	"ENTER = START  ESC = SKIP", "LEAVE (ESC)", "PRESS E TO THROW AT IT", "E = NEXT LINE", "C=CAPACITY", "P: PRAY TO THE GODS",
	"Z X = PUSH", "A / D = SHAKE", "HOLD SHIFT TO RUN. SPACE JUMPS.", "ARROWS OR A/D MOVE", "TAB PICKS THE TARGET", "(E)",
	"N ASKS A FRIEND", "RELEASE Z TO FIRE", "ENTER OR CLICK", "SHIFT F10", "1 / 2 / 3 = ANSWER", "ANY MOVE KEY", "WASD",
	"F9 SHAPE", "SOUND ON  M", "PRESS A KEY", "A OR D", "MOVE THE MOUSE", "J",
	"check your phone (P) now and then.", "Welcome! Press P for your phone.", "Walk to the equipment and press E on it.", "Use the arrow keys.",
]
const MUST_PASS := [
	"(A) PICK  (B) BACK", "STICK = LANE  (A) (B) = PUSH  (BACK) = LEAVE", "UP DOWN ROW  LEFT RIGHT CHANGE", "RS UP",
	"A TICKET WILL ARRIVE SOON", "I AM BUYING THE FIRST ONE", "MORGAN'S DESK", "GRADE", "TKT 3 MAIL 2", "(LT) + STICK",
	"E-MAIL THE CLIENT", "W-2 RATIO 48%", "PC(S)", "A", "7",
	"Temp files. Disk space is back.", "People click things. A process helps.", "I tried the F8 menu but did not know what to pick.",
	"Night shift here too.", "Plan B is the old server.", "PATCH IT NOW (2 H)", "LOW DISK SPACE - DRIVE C IS 99% FULL",
]

var mode := "pad"
var hits := {}  # pad pass: offending text -> [pattern, where first seen]
var kb := {}  # keyboard pass: prompt line -> true
var list := false
var write_golden := false
var _rx := []
var _strip: RegEx
var _allow := []
var _lone: RegEx
var _prose: RegEx


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7).split(",")
		elif arg == "--list":
			list = true
		elif arg == "--golden":
			write_golden = true
	_compile()
	_go.call_deferred()


func _compile() -> void:
	_strip = RegEx.create_from_string(PAD_TOKENS)
	_prose = RegEx.create_from_string(PROSE)
	_lone = RegEx.create_from_string("^[B-HJ-WYZ]$")  # (an X alone is the close box of a window)
	for row in ALLOW:
		_allow.append(RegEx.create_from_string(str(row[0]).replace(" ", "\\s+")))
	var lone := "(?<![A-Z0-9'.\\-/&+$%#:_])LETTER(?![A-Z0-9'\\-/&+%_])(?!\\.\\.)"
	for row in [
		# the keys that have a name, and the mouse
		["key name", "\\b(ENTER|ESC|SPACE|SPACEBAR|TAB|SHIFT|CTRL|BACKSPACE|WASD|ARROWS|ARROW KEYS?|PGUP|PGDN|F([1-9]|1[0-2])|CLICK|CLICKS|MOUSE)\\b"],
		["keys", "\\b(ANY|MOVE|BOTH|REMAP|ALL) KEYS?\\b|\\bA KEY\\b|\\bKEY / BUTTON\\b"],
		# a letter standing alone is a key (A and I are words: A has its own rows below)
		["lone letter", lone.replace("LETTER", "[B-HJ-Z]")],
		["letter in brackets", "(?<![A-Z0-9])\\([A-Z]\\)"],
		["a = ", "(?<![A-Z0-9'.\\-/])A ?= ?[A-Z]"],
		["a / d", "(?<![A-Z0-9'.\\-])[A-Z] ?/ ?[A-Z](?![A-Z0-9'])"],
		["a or d", "\\b(PRESS|HOLD|TAP|RELEASE) A\\b|\\bA OR [A-Z]\\b|\\b[A-Z] OR A\\b|\\bA [B-Z]\\b(?!\\.\\.)"],
		["digit keys", "(?<![A-Z0-9.:$] )(?<![A-Z0-9.:$])[0-9]( ?[/-] ?[0-9])+ ?= ?[A-Z]"],
	]:
		_rx.append([row[0], RegEx.create_from_string(row[1])])


# "" when the text holds no keyboard or mouse prompt, else the name of the pattern that found one
func flag(text: String, pad: bool) -> String:
	var found := flags(text, pad)
	return "" if found.is_empty() else str(found[0][0])


# every [pattern, line] of a text (its lines are scanned one by one, after the ALLOW words are cut out of the whole text)
func flags(text: String, pad: bool, single := true) -> Array:
	var t := text.to_upper().replace("(S)", "S")  # PC(S), TICKET(S)
	for rx in _allow:
		t = (rx as RegEx).sub(t, " ~ ", true)
	var out := []
	var src := text.split("\n")
	var cut := t.split("\n")
	for i in cut.size():
		var line := cut[i]
		if pad:
			line = _strip.sub(line, " ~ ", true)
		if i < src.size() and src[i] != src[i].to_upper():  # sentence case: story text
			if _prose.search(line) != null:
				out.append(["story text", src[i].to_upper()])
			continue
		if line.strip_edges().length() <= 1 and not (single and _lone.search(line.strip_edges()) != null):
			continue  # a single character: only a letter counts, and not in a grid (SINGLE_OK)
		if line.strip_edges().length() <= 1:
			out.append(["one letter", src[i].to_upper() if i < src.size() else line])
			continue
		for row in _rx:
			if (row[1] as RegEx).search(line) != null:
				out.append([str(row[0]), src[i].to_upper() if i < src.size() else line])
				break
	return out


# the newest redraw of each canvas, its lines joined into paragraphs (a wrapped sentence is one text, a line break between rows)
func _paragraphs(recs: Array) -> Array:
	var out := []
	var cur := ""
	var last_y := -99.0
	var last_cid := 0
	for rec in recs:
		var y: float = (rec.rect as Rect2).position.y
		if cur != "" and rec.cid == last_cid and y - last_y >= 6.0 and y - last_y <= 8.0:
			cur += "\n" + str(rec.text)
		else:
			if cur != "":
				out.append(cur)
			cur = str(rec.text)
		last_y = y
		last_cid = rec.cid
	if cur != "":
		out.append(cur)
	return out


# per canvas only its newest redraw counts (older frames belong to what the screen showed before)
func _newest(recs: Array) -> Array:
	var latest := {}
	for rec in recs:
		latest[rec.cid] = maxi(int(latest.get(rec.cid, 0)), int(rec.frame))
	return recs.filter(func(rec: Dictionary) -> bool: return rec.frame == latest[rec.cid])


func _texts(tag: String, all: Array) -> void:
	var recs := _newest(all)
	if mode == "kb":
		for rec in recs:
			if not flags(str(rec.text), false, false).is_empty():
				kb[str(rec.text).to_upper()] = true
		return
	var single := true
	for ok in SINGLE_OK:
		single = single and not tag.begins_with(str(ok))
	for text in _paragraphs(recs):
		for hit in flags(str(text), true, single):
			if not hits.has(hit[1]):
				hits[hit[1]] = [hit[0], "%s %s" % [fmt, tag]]


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL " + what)


func _go() -> void:
	for text in MUST_FLAG:
		_check(flag(text, true) != "", "scanner: '%s' is a keyboard prompt and was not flagged" % text)
	for text in MUST_PASS:
		_check(flag(text, true) == "", "scanner: '%s' was flagged (%s)" % [text, flag(text, true)])
	_check(flag("GAME B (X)", false) != "" and flag("(A) OR (X)", true) == "", "scanner: (X) is a key on a keyboard and a button on a pad")
	_tokens()
	# 1. the keyboard: what it printed before stays
	mode = "kb"
	force_pad = 0
	await _walk(FORMATS)
	_golden()
	# 2. the pad
	mode = "pad"
	force_pad = 1
	await _walk(FORMATS)
	var lines := hits.keys()
	lines.sort()
	if list:
		for line in lines:
			print("PROMPT [%s] %s: %s" % [hits[line][0], hits[line][1], line])
	else:
		for i in mini(lines.size(), 12):
			print("FAIL pad prompt [%s] %s: %s" % [hits[lines[i]][0], hits[lines[i]][1], lines[i]])
	failures += lines.size()
	force_pad = -1
	root.get_node("Controls").pad_active = false
	# 3. the switch is live
	await _live()
	print("screens=%d offending_lines=%d keyboard_prompt_lines=%d failures=%d" % [screens, lines.size(), kb.size(), failures])
	quit(1 if failures > 0 else 0)


# the key tokens of Controls.keys: the same string names the key, the pad button, and the remapped one
func _tokens() -> void:
	var ctl := root.get_node("Controls")
	var before: String = ctl.binds_path
	ctl.binds_path = "user://test_%d_pad_prompts_binds.cfg" % OS.get_process_id()
	ctl.reset_binds()
	var rows := [
		# text, on a keyboard, on a pad
		["PRESS {E} TO THROW", "PRESS E TO THROW", "PRESS (X) TO THROW"],
		["LEAVE ({ESC})", "LEAVE (ESC)", "LEAVE (B)"],
		["{ESC:pause} FOR THE MENU", "ESC FOR THE MENU", "(START) FOR THE MENU"],
		["HOLD {SHIFT} TO DUCK, {Z} FIRES", "HOLD SHIFT TO DUCK, Z FIRES", "HOLD (B) TO DUCK, (A) FIRES"],
		["{PRESS A OR D|PUSH THE STICK} TO ROLL", "PRESS A OR D TO ROLL", "PUSH THE STICK TO ROLL"],
		["FOCUS{ (F)|}", "FOCUS (F)", "FOCUS"],
		["check your phone ({P}) now", "check your phone (P) now", "check your phone (BACK) now"],
		["{ARROW KEYS:move} = HIT NOTES", "ARROW KEYS = HIT NOTES", "STICK = HIT NOTES"],
		["LEAVE ({ESC:MENU_BACK})", "LEAVE (ESC)", "LEAVE (B)"],  # a card label is upper-cased as a whole
		["{me}, {c} AND {closed} OF {0}", "{me}, {c} AND {closed} OF {0}", "{me}, {c} AND {closed} OF {0}"],  # the story's own braces
		["NO TOKENS HERE: E P Q", "NO TOKENS HERE: E P Q", "NO TOKENS HERE: E P Q"],
	]
	for row in rows:
		ctl.pad_active = false
		_check(ctl.keys(row[0]) == row[1], "token, keyboard: '%s' gives '%s' (want '%s')" % [row[0], ctl.keys(row[0]), row[1]])
		ctl.pad_active = true
		_check(ctl.keys(row[0]) == row[2], "token, pad: '%s' gives '%s' (want '%s')" % [row[0], ctl.keys(row[0]), row[2]])
	# hint() rewrites the bare words and leaves a token's answer alone; with the default keys the keyboard's line is the text
	ctl.pad_active = false
	_check(ctl.hint("ENTER{ OR CLICK|}") == "ENTER OR CLICK" and ctl.hint("ENTER = OK  ESC = BACK") == "ENTER = OK  ESC = BACK", "hint, keyboard: unchanged with the default keys")
	_check(ctl.world_hint("DARTS 3  Z FIRE{ (HOLD = FAR)|}  {G} AWAY") == "DARTS 3  Z FIRE (HOLD = FAR)  G AWAY", "world hint, keyboard: %s" % ctl.world_hint("DARTS 3  Z FIRE{ (HOLD = FAR)|}  {G} AWAY"))
	ctl.pad_active = true
	_check(ctl.hint("ENTER{ OR CLICK|}") == "(A)" and ctl.hint("P1 = Z X  P2 = {A B|(A) (B)}") == "P1 = (A) (B)  P2 = (A) (B)", "hint, pad: %s" % ctl.hint("P1 = Z X  P2 = {A B|(A) (B)}"))
	_check(ctl.world_hint("DARTS 3  Z FIRE{ (HOLD = FAR)|}  {G} AWAY") == "DARTS 3  (RT) FIRE  RS LEFT AWAY", "world hint, pad: %s" % ctl.world_hint("DARTS 3  Z FIRE{ (HOLD = FAR)|}  {G} AWAY"))
	# a remap: the token follows the key on a keyboard and the button on a pad
	ctl.pad_active = false
	ctl.rebind("interact", KEY_K)
	_check(ctl.keys("PRESS {E} TO THROW") == "PRESS K TO THROW", "token, remapped key: %s" % ctl.keys("PRESS {E} TO THROW"))
	ctl.pad_active = true
	ctl.rebind_button("interact", JOY_BUTTON_Y)
	_check(ctl.keys("PRESS {E} TO THROW") == "PRESS (Y) TO THROW", "token, remapped button: %s" % ctl.keys("PRESS {E} TO THROW"))
	ctl.reset_binds()
	ctl.pad_active = false
	_check(ctl.keys("PRESS {E} TO THROW") == "PRESS E TO THROW", "token: back to E after the reset")
	ctl.binds_path = before


# what the screen drew by itself in the frames after an input event (nothing here asks for a redraw)
func _after(event: InputEvent) -> String:
	PixelFont.audit = []
	Input.parse_input_event(event)
	await _wait(6)
	var out := PackedStringArray()
	for rec in _newest(PixelFont.audit):
		out.append(str(rec.text).to_upper())
	PixelFont.audit = null
	return "\n".join(out)


# 3. a pad button flips the prompts of an open screen to the pad's, a key and a mouse move flip them back. The events are
# ones no screen answers (the pad's guide button, the Ctrl key, a mouse move), so the redraw can only come from the switch.
func _live() -> void:
	var ctl := root.get_node("Controls")
	var cards := root.get_node("Cards")
	var pm := root.get_node("PauseMenu")
	var guide := InputEventJoypadButton.new()
	guide.button_index = JOY_BUTTON_GUIDE
	guide.pressed = true
	var ctrl := InputEventKey.new()
	ctrl.keycode = KEY_CTRL
	ctrl.physical_keycode = KEY_CTRL
	ctrl.pressed = true
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(3, 0)
	var sweep := InputEventMouseMotion.new()
	sweep.relative = Vector2(60, 0)
	root.get_node("Game").title_mode = false
	await _scene("res://scenes/main_floor.tscn")
	await _new_game("tech", "office_intern")
	root.get_node("Campaign").day = 3
	await _wait(12)
	_leave(cards)
	ctl.set_pad_active(false)
	for screen in ["card", "pause", "outing"]:
		if screen == "card":
			var talk := root.get_node("Talk")
			talk._who = "Alan"
			talk._menu("WHAT IS UP?")
		elif screen == "pause":
			pm.open()
		else:
			var out := root.get_node("Outings")
			out.enabled = true
			out.use_rooms = false
			out.start("grill", false, {"party": ["Alan", "Garrison", "Dan"]})
		await _wait(6)
		var seen: String = await _after(guide)
		_check(ctl.pad_active, "live %s: a pad button makes the pad the active input" % screen)
		_check(seen != "" and flag(seen, true) == "", "live %s: the open screen redrew with the pad's prompts (%s)" % [screen, str(flags(seen, true))])
		seen = await _after(nudge)
		_check(ctl.pad_active, "live %s: a nudge of the mouse does not take the prompts back" % screen)
		seen = await _after(ctrl)
		_check(not ctl.pad_active and flag(seen, false) != "", "live %s: a key brings the keyboard's prompts back (%s)" % [screen, seen.replace("\n", " / ").right(70)])
		await _after(guide)
		seen = await _after(sweep)
		_check(not ctl.pad_active and flag(seen, false) != "", "live %s: moving the mouse brings them back too (%s)" % [screen, seen.replace("\n", " / ").right(70)])
		if screen == "card":
			_leave(cards)
		elif screen == "pause":
			pm.close()
		else:
			root.get_node("Outings").close()
			root.get_node("Outings").enabled = false
		await _wait(3)
	ctl.set_pad_active(false)


func _golden() -> void:
	var lines := kb.keys()
	lines.sort()
	if write_golden:
		var f := FileAccess.open(GOLDEN, FileAccess.WRITE)
		for line in lines:
			f.store_line(str(line))
		f.close()
		print("wrote %d keyboard prompt lines to %s" % [lines.size(), GOLDEN])
		return
	if not only.is_empty():
		return  # a part of the walk (-- --only=extra) does not draw every line of the file
	if not FileAccess.file_exists(GOLDEN):
		_check(false, "no %s (run with -- --golden)" % GOLDEN)
		return
	var missing := 0
	for line in FileAccess.get_file_as_string(GOLDEN).split("\n"):
		line = line.strip_edges(false, true)
		if line != "" and not kb.has(line):
			missing += 1
			if missing <= 12:
				print("FAIL keyboard prompt changed or gone: " + line)
	failures += missing


func _walk(formats: Array) -> void:
	if not only.has("extra"):
		await super(formats)
	for f in formats:
		fmt = f
		root.get_node("Game").set_format(f)
		await _extra_phase()


# close whatever card is up by its last answer (a talk card's first answer opens the next card)
func _leave(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 10:
		cards.pick(cards.options.size() - 1)
		n += 1


# the screens the layout audit does not open, which carry prompts
func _extra_phase() -> void:
	var cards := root.get_node("Cards")
	var comp := root.get_node("Computer")
	var world := root.get_node("World")
	var hints := root.get_node("Hints")
	var out := root.get_node("Outings")
	root.get_node("Game").title_mode = false
	await _scene("res://scenes/main_floor.tscn")
	await _new_game("tech", "office_intern")
	world.clock = 11.0
	root.get_node("Campaign").day = 3
	await _wait(12)
	# the tutorial lines and Dan's ride-along, as the HUD prints them
	var tips := []
	for row in hints.DAY1:
		tips.append(str(row.text))
	for key in hints.MENTOR:
		tips.append(str(hints.MENTOR[key]))
	tips.append(str(root.get_node("Expo").TEXT.get("seat_hint", "")))
	var quiet := 0
	var guard := 0
	while quiet < 40 and guard < 900:  # the morning's mail banners slide in from above the screen: wait them out
		quiet = quiet + 1 if (root.get_node("Phone").banner.is_empty() and root.get_node("Phone")._bq.is_empty()) else 0
		guard += 1
		await process_frame
	for i in tips.size():
		hints.toast(tips[i], 99.0)
		root.get_node("Phone")._bq.clear()  # a mail banner sliding in is not part of this screen
		root.get_node("Phone").banner = {}
		_leave(cards)
		await _hud_shot("hint %d" % i)
	hints.toast("", 0.0)
	hints.toast_text = ""
	# a coworker's talk card
	var talk := root.get_node("Talk")
	talk._who = "Alan"
	_begin()
	talk._menu("WHAT IS UP?")
	await _end("talk card")
	_leave(cards)
	# the pause menu, its key list and the remap page
	var pm := root.get_node("PauseMenu")
	pm.open()
	for page in [-1, 0, 1, 2, pm.REMAP_PAGE]:
		pm._page = page
		_begin()
		pm._canvas.queue_redraw()
		await _end("pause page %d" % page)
	pm._page = -1
	pm.close()
	await _wait(2)
	# the rest of the computer and the phone
	for app in ["stats", "nerds", "nerds irc", "dash", "shop"]:
		_begin()
		comp.open(1)
		comp.app = app.split(" ")[0]
		comp.nerds_tab = "irc" if app == "nerds irc" else "forum"
		comp._canvas.queue_redraw()
		await _end("computer " + app)
		comp.close()
		await _wait(2)
	var ph := root.get_node("Phone")
	for view in ["keypad", "contacts"]:
		_begin()
		ph.open()
		ph.locked = false
		ph.app = "phone"
		ph.ph_view = view
		ph._canvas.queue_redraw()
		await _end("phone " + view)
		ph.close()
		await _wait(2)
	# the printer game, step by step
	var pg := root.get_node("PrinterGame")
	for phase in ["intro", "jam", "tray", "toner", "shake", "test", "result"]:
		pg.start(func(_s: int) -> void: pass)
		if pg.has_method("_begin_" + phase):
			pg.call("_begin_" + phase)
		else:
			pg.phase = phase
		_begin()
		pg._canvas.queue_redraw()
		await _end("printer " + phase)
		pg.is_open = false
		pg._canvas.visible = false
	root.get_node("Game").ui_open = false
	# the year-end review
	var rev := root.get_node("Review")
	_begin()
	rev.start()
	await _end("review")
	rev.is_open = false
	rev._canvas.visible = false
	root.get_node("Game").ui_open = false
	# every outing: the page version (intro, play) and the room version's caption and hint bar
	out.enabled = true
	out.use_rooms = false
	for id in out.GAMES:
		_begin()
		out.start(id, false, {"party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
		await _end("outing %s intro" % id)
		out._traveled = true  # the room version's intro text, without travelling there
		_begin()
		await _end("outing %s room intro" % id)
		out._traveled = false
		out.press(KEY_ENTER)
		out.tick(4.0)
		out.tick(0.1)
		_begin()
		await _end("outing %s play" % id)
		out._traveled = true
		if id == "escape":
			out._escape_room_setup()
		out.tick(0.1)
		_begin()
		await _end("outing %s room" % id)
		out._traveled = false
		out.close()
	root.get_node("Phone")._bq.clear()
	root.get_node("Phone").banner = {}
	root.get_node("Game").ui_open = false
	out.enabled = false
