extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# One-line control hints for the first tech day, shown at the bottom by the HUD.
# They appear on a timer while the clock runs, so the quiet first day teaches the controls.

const SHOW_SECS := 8.0
const DEFAULT_DAY1 := [
	{"at": 4.0, "text": "ARROWS OR A/D MOVE. HOLD SHIFT TO RUN. SPACE JUMPS."},
	{
		"at": 24.0,
		"text": "E USES WHAT IS NEAR: DOORS, THE COFFEE MACHINE, CHAIRS. TAB PICKS THE TARGET."
	},
	{
		"at": 46.0,
		"text": "SIT AT A DESK AND PRESS E ON THE MONITOR TO OPEN THE COMPUTER. ESC CLOSES IT."
	},
	{
		"at": 68.0,
		"text": "P OPENS YOUR PHONE: MAIL, TICKETS AND TEXTS. Q WAVES, C ASKS A COWORKER TO FOLLOW."
	},
	{
		"at": 90.0,
		"text": "TICKETS APPEAR IN THE PSA. FIX THEM IN THE RMM, THEN CLOSE THEM IN THE PSA."
	},
]
var DAY1: Array = DEFAULT_DAY1.duplicate(true)

var text := ""
var toast_text := ""
var objective := ""  # a standing reminder (the conference trip), shown when nothing else is

var _t := 0.0
var _next := 0
var _left := 0.0
var _toast_t := 0.0


func _ready() -> void:
	Campaign.day_started.connect(func(_d: int) -> void: reset())


func reset() -> void:
	text = ""
	_t = 0.0
	_next = 0
	_left = 0.0


# a short message at the bottom of the screen (hits in a nerf fight, out of darts...)
func toast(message: String, secs := 2.5) -> void:
	toast_text = message
	_toast_t = secs


func active() -> bool:
	return Campaign.active and Campaign.mode == "tech" and Campaign.day == 1 and not Game.title_mode


func _process(delta: float) -> void:
	if _toast_t > 0.0 and not Game.ui_open:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast_text = ""
	if not active():
		text = ""
		return
	if World.time_scale > 0.0:
		_t += delta
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			text = ""
	if _next < DAY1.size() and _t >= float(DAY1[_next].at):
		text = str(DAY1[_next].text)
		_left = SHOW_SECS
		_next += 1
