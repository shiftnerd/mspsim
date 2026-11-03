extends CanvasLayer
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length,max-returns,class-definitions-order
# The printer mini-game (onsite, the bane of every MSP's existence): open the printer and fight it in three rounds.
#   1. PAPER JAM: pull the stuck paper out of three spots. SPACE stops a moving marker: green = a clean pull,
#      yellow = it holds (try again), red = it tears and leaves a scrap (a mistake).
#   2. PC LOAD LETTER: the display says it, and nobody knows what it means. Load the right paper (LETTER) in the tray.
#   3. TONER: install the four cartridges in the order the printer asks (left / right, SPACE), then shake the cartridge (A and D).
#   4. TEST PAGE: two error messages on the little display; pick the right way to deal with each (1 / 2 / 3).
# P prays to the sysadmin gods (3 prayers): good luck blesses you (the next mistake is forgiven, the green zone widens), bad luck costs you.
# Fewer mistakes = more stars (0-3). Esc gives up. Used by Onsite (printer jobs, and practice in Free Play):
#   PrinterGame.start(func(stars: int) -> void: ...)
# The questions and texts are in QUESTIONS / TEXT so reviewers can edit them in story/strings.txt.

const PixelFont := preload("res://scripts/pixelfont.gd")
const PW := 176.0
const PH := 112.0
const INK := Color("17121f")
const BODY := Color("dfe3ea")
const PAPER := Color("f4f2ea")
const COLORS := [Color("2fa7d8"), Color("d8409a"), Color("f2d23c"), Color("2a2a33")]
const COLOR_NAMES := ["CYAN", "MAGENTA", "YELLOW", "BLACK"]
const DEFAULT_TEXT := {
	"title": "PRINTER REPAIR",
	"intro1": "THE COPIER GRINDS AND THE DISPLAY SAYS",
	"intro2": "PAPER JAM 13.20.00. THEY ALWAYS SAY THAT.",
	"intro3": "SPACE TO BEGIN, ESC TO GIVE UP",
	"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN",
	"jam_clean": "A CLEAN PULL. THE SHEET COMES OUT WHOLE.",
	"jam_hold": "IT HOLDS. NOT QUITE: TRY AGAIN.",
	"jam_tear": "RIP! A SCRAP IS STILL INSIDE.",
	"toner_help": "LEFT / RIGHT TO PICK, SPACE TO INSTALL",
	"toner_ok": "CLICK. IT SEATS.",
	"toner_bad": "WRONG CARTRIDGE. THE PRINTER BEEPS.",
	"shake_help": "SHAKE THE CARTRIDGE: A D A D A D",
	"shake_late": "TOO SLOW. TONER DUST EVERYWHERE.",
	"test_help": "PICK 1, 2 OR 3",
	"right": "RIGHT.",
	"wrong": "NOPE.",
	"hit": "YOU HIT THE PRINTER. IT WORKS. DO NOT TELL ANYONE.",
	"stars3": "PERFECT. A FLAWLESS TEST PAGE.",
	"stars2": "GOOD ENOUGH. A FEW STREAKS.",
	"stars1": "IT PRINTS. MOSTLY.",
	"stars0": "YOU GIVE UP. THE PRINTER WINS.",
	"done": "SPACE TO CLOSE",
	"tray_help": "PC LOAD LETTER. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
	"tray_ok": "LETTER PAPER IN TRAY 2. PC LOAD LETTER IS SOLVED. YOU ARE A HERO.",
	"tray_bad": "WRONG PAPER. THE PRINTER JAMS ON PRINCIPLE.",
	"tray_hit": "YOU HIT THE PRINTER AND IT WORKS. DO NOT TELL ANYONE.",
	"pray_help": "P: PRAY TO THE SYSADMIN GODS",
	"pray_none": "THE GODS HAVE HEARD ENOUGH FROM YOU TODAY.",
	"blessed_tag": "BLESSED",
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)
const PRAYERS := {
	"good":
	[
		"THE SYSADMIN GODS SMILE. YOUR NEXT MISTAKE IS FORGIVEN.",
		"A WARM HUM FROM A DISTANT SERVER ROOM. YOU ARE BLESSED.",
		"A DOMAIN CONTROLLER REPLICATES IN YOUR HONOR. YOU ARE BLESSED.",
	],
	"meh":
	[
		"THE GODS ARE BUSY RESTARTING A DOMAIN CONTROLLER.",
		"SILENCE. SOMEWHERE, A BACKUP FAILS.",
		"THE GODS PUT YOU ON HOLD. THE MUSIC IS BAD.",
	],
	"bad":
	[
		"THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.",
		"A SURGE ON THE POWER LINE. THE GODS ARE DISPLEASED.",
	],
}
const TRAY := ["LETTER", "LEGAL", "A4", "HIT IT"]
const DEFAULT_QUESTIONS := [
	{
		"error": "TONER LOW",
		"options": ["IGNORE IT", "REPLACE THE CARTRIDGE", "SHAKE IT AND KEEP PRINTING"],
		"correct": 1,
		"hit": -1,
		"why": "SHAKING BUYS ABOUT TWENTY PAGES. THEN THE STREAKS COME BACK.",
	},
	{
		"error": "ERROR 79 SERVICE",
		"options":
		["REINSTALL THE DRIVER", "POWER CYCLE AND RESEAT THE FORMATTER", "CALL THE VENDOR"],
		"correct": 1,
		"hit": -1,
		"why": "A 79 IS USUALLY THE FORMATTER OR A BAD PRINT JOB. UNPLUG, WAIT, RESEAT, TRY AGAIN.",
	},
	{
		"error": "PRINTER OFFLINE",
		"options": ["SET IT BACK ONLINE", "BUY A NEW PRINTER", "REINSTALL WINDOWS"],
		"correct": 0,
		"hit": -1,
		"why": "SOMEONE PRESSED THE OFFLINE BUTTON. SOMEONE ALWAYS DOES.",
	},
	{
		"error": "PAPER MISMATCH TRAY 1",
		"options": ["OPEN THE FUSER", "SET TRAY 1 TO PLAIN PAPER", "BLAME THE USER"],
		"correct": 1,
		"hit": -1,
		"why": "THE TRAY SAYS LABELS BUT THE PAPER IS PLAIN. CHANGE THE TRAY SETTING.",
	},
]
var QUESTIONS: Array = DEFAULT_QUESTIONS.duplicate(true)

var is_open := false
var phase := ""
var mistakes := 0
var stars := 0
var msg := ""
var marker := 0.0
var zone := 0.5
var spot := 0
var order: Array = []
var step := 0
var sel := 0
var shakes := 0
var asked: Array = []
var qi := 0
var faith := 3
var blessed := 0
var tray_sel := 0
var fast := false

var _canvas: Node2D
var _callback := Callable()
var _t := 0.0
var _dir := 1.0
var _shake_t := 0.0
var _last_shake := ""
var _answered := false
var _result_t := 0.0


func _ready() -> void:
	layer = 62
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)


func start(callback: Callable) -> void:
	_callback = callback
	is_open = true
	Game.ui_open = true
	_canvas.visible = true
	phase = "intro"
	mistakes = 0
	stars = 0
	msg = ""
	spot = 0
	step = 0
	sel = 0
	qi = 0
	faith = 3
	blessed = 0
	tray_sel = 0
	fast = false
	marker = 0.0
	_t = 0.0
	_answered = false
	_canvas.queue_redraw()


func _finish() -> void:
	is_open = false
	Game.ui_open = false
	_canvas.visible = false
	if _callback.is_valid():
		_callback.call(stars)


func _score() -> int:
	if mistakes <= 1:
		return 3
	if mistakes <= 3:
		return 2
	if mistakes <= 5:
		return 1
	return 0


# ---- phases
func _begin_jam() -> void:
	phase = "jam"
	spot = 0
	_new_zone()
	msg = str(TEXT.jam_help)


func _new_zone() -> void:
	zone = randf_range(0.22, 0.78)
	marker = 0.0
	_dir = 1.0


func _begin_tray() -> void:
	phase = "tray"
	tray_sel = 0
	msg = str(TEXT.tray_help)


func _mistake() -> void:
	if blessed > 0:
		blessed -= 1
		msg += " THE GODS FORGIVE IT."
	else:
		mistakes += 1


func _pray() -> void:
	if faith <= 0:
		msg = str(TEXT.pray_none)
		return
	faith -= 1
	var roll := randf()
	if roll < 0.55:
		blessed += 1
		msg = str(PRAYERS.good[randi() % PRAYERS.good.size()])
	elif roll < 0.8:
		msg = str(PRAYERS.meh[randi() % PRAYERS.meh.size()])
	elif roll < 0.92:
		mistakes += 1
		msg = str(PRAYERS.bad[0])
	else:
		fast = true
		msg = str(PRAYERS.bad[1]) + " THE MARKER SPEEDS UP."


func _begin_toner() -> void:
	phase = "toner"
	order = [0, 1, 2, 3]
	order.shuffle()
	step = 0
	sel = 0
	msg = str(TEXT.toner_help)


func _begin_shake() -> void:
	phase = "shake"
	shakes = 0
	_shake_t = 5.0
	_last_shake = ""
	msg = str(TEXT.shake_help)


func _begin_test() -> void:
	phase = "test"
	var pool := range(QUESTIONS.size())
	pool.shuffle()
	asked = [pool[0], pool[1]]
	qi = 0
	_answered = false
	msg = str(TEXT.test_help)


func _end() -> void:
	stars = _score()
	phase = "result"
	_result_t = 0.0
	msg = str(TEXT.get("stars%d" % stars, ""))


# ---- input
func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E:
			press("confirm")
		KEY_LEFT:
			press("left")
		KEY_RIGHT:
			press("right")
		KEY_A:
			press("a")
		KEY_D:
			press("d")
		KEY_1, KEY_2, KEY_3:
			press(str(event.keycode - KEY_0))
		KEY_P:
			press("pray")
		KEY_ESCAPE:
			press("escape")
		_:
			return
	get_viewport().set_input_as_handled()


func press(key: String) -> void:
	if not is_open:
		return
	if key == "escape":
		if phase == "result":
			return  # the result is kept
		if phase == "intro":
			stars = -1  # backed out before starting: no time is spent
			_finish()
			return
		stars = 0
		phase = "result"
		_result_t = 0.0
		msg = str(TEXT.stars0)
		_canvas.queue_redraw()
		return
	if key == "pray":
		if phase in ["intro", "jam", "tray", "toner", "shake", "test"]:
			_pray()
		_canvas.queue_redraw()
		return
	match phase:
		"intro":
			if key == "confirm":
				_begin_jam()
		"tray":
			if key in ["left", "a"]:
				tray_sel = posmod(tray_sel - 1, TRAY.size())
			elif key in ["right", "d"]:
				tray_sel = posmod(tray_sel + 1, TRAY.size())
			elif key == "confirm":
				_load_paper()
		"jam":
			if key == "confirm":
				_pull()
		"toner":
			if key in ["left", "a"]:
				sel = posmod(sel - 1, 4)
			elif key in ["right", "d"]:
				sel = posmod(sel + 1, 4)
			elif key == "confirm":
				_install()
		"shake":
			if key in ["a", "left", "d", "right"]:
				var side := "a" if key in ["a", "left"] else "d"
				if side != _last_shake:
					_last_shake = side
					shakes += 1
					if shakes >= 10:
						msg = ""
						_begin_test()
		"test":
			if not _answered and key in ["1", "2", "3"]:
				_answer(int(key) - 1)
			elif _answered and key == "confirm":
				_next_question()
		"result":
			if key == "confirm" and _result_t > 0.5:
				_finish()
	_canvas.queue_redraw()


func _load_paper() -> void:
	if tray_sel == 0:
		msg = str(TEXT.tray_ok)
		_begin_toner_after_tray()
	elif tray_sel == 3 and randf() < 0.05:
		msg = str(TEXT.tray_hit)
		_begin_toner_after_tray()
	else:
		msg = str(TEXT.tray_bad)
		_mistake()


func _begin_toner_after_tray() -> void:
	var keep := msg
	_begin_toner()
	msg = keep


func _pull() -> void:
	var d := absf(marker - zone)
	if d <= 0.07 + 0.03 * float(mini(blessed, 2)):
		spot += 1
		msg = str(TEXT.jam_clean)
		_new_zone()
		if spot >= 3:
			_begin_tray()
	elif d <= 0.16 + 0.04 * float(mini(blessed, 2)):
		msg = str(TEXT.jam_hold)
	else:
		msg = str(TEXT.jam_tear)
		_mistake()
		_new_zone()


func _install() -> void:
	if sel == int(order[step]):
		step += 1
		msg = str(TEXT.toner_ok)
		if step >= 4:
			_begin_shake()
	else:
		msg = str(TEXT.toner_bad)
		_mistake()


func _answer(choice: int) -> void:
	var q: Dictionary = QUESTIONS[int(asked[qi])]
	_answered = true
	if choice == int(q.correct):
		msg = str(TEXT.right) + " " + str(q.why)
	elif choice == int(q.hit) and randf() < 0.05:
		msg = str(TEXT.hit)
	else:
		msg = str(TEXT.wrong) + " " + str(q.why)
		_mistake()


func _next_question() -> void:
	qi += 1
	_answered = false
	if qi >= asked.size():
		_end()
	else:
		msg = str(TEXT.test_help)


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	_result_t += delta
	if phase == "jam":
		marker += _dir * delta * (0.8 + 0.3 * float(spot)) * (1.5 if fast else 1.0)
		if marker >= 1.0:
			marker = 1.0
			_dir = -1.0
		elif marker <= 0.0:
			marker = 0.0
			_dir = 1.0
	elif phase == "shake":
		_shake_t -= delta
		if _shake_t <= 0.0:
			msg = str(TEXT.shake_late)
			_mistake()
			_begin_test()
	_canvas.queue_redraw()


# ---- drawing
var _o := Vector2.ZERO


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	_canvas.draw_rect(Rect2(_o + Vector2(x, y), Vector2(w, h)), c)


func _txt(s: String, x: float, y: float, c: Color = INK, scale := 1) -> void:
	PixelFont.draw(_canvas, s, _o + Vector2(x, y), c, scale)


func _wrap(s: String, chars: int) -> Array:
	var lines := []
	var cur := ""
	for w in s.split(" "):
		if cur != "" and cur.length() + 1 + w.length() > chars:
			lines.append(cur)
			cur = w
		else:
			cur = (cur + " " + w).strip_edges()
	if cur != "":
		lines.append(cur)
	return lines


func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.7))
	_o = ((size - Vector2(PW, PH)) * 0.5).floor()
	_r(-1, -1, PW + 2, PH + 2, INK)
	_r(0, 0, PW, PH, BODY)
	_r(0, 0, PW, 9, Color("4a5a78"))
	_txt(str(TEXT.title), 3, 2, Color.WHITE)
	var mis := "MISTAKES %d" % mistakes
	_txt(mis, PW - PixelFont.width(mis) - 3, 2, Color("ffd6d0"))
	if phase != "result":
		var faith_line := "P PRAY %d" % faith + ("  BLESSED %d" % blessed if blessed > 0 else "")
		_txt(faith_line, 4, PH - 6.0, Color("8a5a2b") if blessed == 0 else Color("2e7a3a"))
	match phase:
		"intro":
			_paint_intro()
		"jam":
			_paint_jam()
		"tray":
			_paint_tray()
		"toner":
			_paint_toner()
		"shake":
			_paint_shake()
		"test":
			_paint_test()
		"result":
			_paint_result()
	var lines := _wrap(msg, int((PW - 8.0) / 4.0))
	for i in mini(lines.size(), 3):
		_txt(str(lines[i]), 4, PH - 13.0 - float(mini(lines.size(), 3) - i) * 7.0, Color("46506a"))


func _printer(y: float) -> void:
	_r(8, y, 160, 40, Color("c9cdd6"))
	_r(8, y, 160, 3, Color("f2f4f8"))
	_r(8, y + 37, 160, 3, Color("8e939e"))
	_r(12, y + 8, 152, 24, Color("2e3138"))
	for i in 4:
		_canvas.draw_circle(_o + Vector2(32.0 + 40.0 * float(i), y + 20.0), 7.0, Color("6a6f7a"))
		_canvas.draw_circle(_o + Vector2(32.0 + 40.0 * float(i), y + 20.0), 3.0, Color("4a4f5a"))


func _paint_intro() -> void:
	_printer(16)
	var lines := [str(TEXT.intro1), str(TEXT.intro2), "", str(TEXT.intro3)]
	for i in lines.size():
		_txt(str(lines[i]), 6, 62.0 + float(i) * 7.0)


func _paint_jam() -> void:
	_printer(14)
	for i in 3:
		var x := 36.0 + 44.0 * float(i)
		if i < spot:
			_r(x - 14, 28, 28, 5, PAPER)
		else:
			for k in 5:
				_r(x - 12.0 + float(k) * 5.0, 24.0 + float((k + i) % 3) * 3.0, 6, 9, PAPER)
				_r(
					x - 12.0 + float(k) * 5.0,
					24.0 + float((k + i) % 3) * 3.0,
					6,
					1,
					Color("c9c3b2")
				)
	_txt("PULLED %d OF 3" % spot, 8, 58)
	_r(16, 74, 144, 10, Color("8a8f9a"))
	_r(16.0 + 144.0 * (zone - 0.16), 74, 144.0 * 0.32, 10, Color("f2c94c"))
	_r(16.0 + 144.0 * (zone - 0.07), 74, 144.0 * 0.14, 10, Color("4cff7a"))
	_r(16.0 + 144.0 * marker - 1.0, 71, 3, 16, INK)


func _paint_tray() -> void:
	_r(10, 14, 156, 20, Color("14301c"))
	_r(12, 16, 152, 16, Color("3a6a42"))
	_txt("PC LOAD LETTER", 16, 21, Color("d8f8d8"), 1)
	_txt("TRAY 2", 130, 21, Color("d8f8d8"), 1)
	for i in TRAY.size():
		var x := 12.0 + 38.0 * float(i)
		_r(x, 40, 34, 28, INK)
		_r(x + 1, 41, 32, 26, PAPER if i < 3 else Color("c9cdd6"))
		if i < 3:
			for k in 3:
				_r(x + 5, 46.0 + float(k) * 5.0, 24.0 - float(i) * 2.0, 1, Color("8a8f9a"))
		_txt(str(TRAY[i]), x + 3, 58, INK)
		if i == tray_sel:
			_r(x - 2, 38, 38, 2, Color("ff6a3a"))
			_r(x - 2, 68, 38, 2, Color("ff6a3a"))


func _paint_toner() -> void:
	for i in 4:
		var x := 14.0 + 40.0 * float(i)
		_r(x, 24, 30, 36, INK)
		_r(x + 1, 25, 28, 34, COLORS[i])
		_r(x + 3, 28, 24, 5, Color(1, 1, 1, 0.35))
		_txt(str(COLOR_NAMES[i]).substr(0, 4), x + 2, 50, Color.WHITE if i != 2 else INK)
		if i == sel:
			_r(x - 2, 22, 34, 2, Color("ff6a3a"))
			_r(x - 2, 60, 34, 2, Color("ff6a3a"))
	if step < 4:
		_txt("INSTALL: " + str(COLOR_NAMES[int(order[step])]), 8, 70, INK, 1)
	for i in 4:
		_r(
			120.0 + 10.0 * float(i),
			70,
			7,
			7,
			COLORS[int(order[i])] if i < step else Color("8a8f9a")
		)


func _paint_shake() -> void:
	var off := sin(_t * 30.0) * 3.0
	_r(70.0 + off, 22, 36, 44, INK)
	_r(71.0 + off, 23, 34, 42, COLORS[3])
	_r(75.0 + off, 27, 26, 5, Color(1, 1, 1, 0.3))
	_r(16, 72, 144, 7, Color("8a8f9a"))
	_r(16, 72, 144.0 * float(shakes) / 10.0, 7, Color("4cff7a"))
	_r(16, 82, 144.0 * clampf(_shake_t / 5.0, 0.0, 1.0), 3, Color("ff6a3a"))


func _paint_test() -> void:
	var q: Dictionary = QUESTIONS[int(asked[qi])]
	_r(10, 14, 156, 22, Color("14301c"))
	_r(12, 16, 152, 18, Color("3a6a42"))
	_txt(str(q.error), 16, 22, Color("d8f8d8"), 1)
	for i in 3:
		_txt("%d  %s" % [i + 1, str(q.options[i])], 10, 42.0 + float(i) * 8.0)


func _paint_result() -> void:
	for i in 3:
		var col := Color("f2c94c") if i < stars else Color("8a8f9a")
		_r(46.0 + 30.0 * float(i), 28, 20, 20, INK)
		_r(48.0 + 30.0 * float(i), 30, 16, 16, col)
	_txt(str(TEXT.done), 10, 60)
