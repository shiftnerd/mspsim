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
	{
		"at": 112.0,
		"text": "SEATED? HOLD SHIFT AND PRESS A OR D TO ROLL YOUR CHAIR. E OR ANY MOVE KEY STANDS YOU UP."
	},
	{"at": 134.0, "text": "M MUTES OR RESTORES THE SOUND."},
]
var DAY1: Array = DEFAULT_DAY1.duplicate(true)
# Dan's ride-along on day 1 (when the player takes his offer on the first card): the bottom line follows what the player has done
const DEFAULT_MENTOR := {
	"pc": "DAN: SIT AT YOUR DESK AND PRESS E ON THE MONITOR. THAT OPENS THE COMPUTER.",
	"wait": "DAN: A TICKET WILL ARRIVE SOON. IT SHOWS UP IN THE PSA ON YOUR COMPUTER.",
	"take": "DAN: OPEN THE PSA AND TAKE YOUR FIRST TICKET.",
	"fix": "DAN: NOW OPEN THE RMM AND FIX IT. THE TICKET SAYS WHAT IS WRONG.",
	"close": "DAN: THE FIX IS DONE. CLOSE THE TICKET IN THE PSA.",
	"done": "DAN: THAT IS ONE CLOSED. YOU ARE ON YOUR WAY.",
}
var MENTOR: Dictionary = DEFAULT_MENTOR.duplicate(true)

var text := ""
var toast_text := ""
var objective := ""  # a standing reminder (the conference trip), shown when nothing else is

var _t := 0.0
var _pc_opened := false
var _mentor_done := false
var _mentor_obj := ""
var _next := 0
var _left := 0.0
var _toast_t := 0.0


func _ready() -> void:
	Campaign.day_started.connect(func(_d: int) -> void: reset())


func reset() -> void:
	text = ""
	_pc_opened = false
	_mentor_done = false
	_t = 0.0
	_next = 0
	_left = 0.0


# a short message at the bottom of the screen (hits in a nerf fight, out of darts...)
func toast(message: String, secs := 2.5) -> void:
	toast_text = message
	_toast_t = secs


# the step Dan is on, "" when he is not guiding (declined, not asked yet, or finished)
func _mentor_step() -> String:
	if str(Story.flags.get("mentor", "")) != "on" or _mentor_done:
		return ""
	if Computer.is_open:
		_pc_opened = true
	if Msp.closed_ok > 0:
		_mentor_done = true
		toast(str(MENTOR.done), 4.0)
		return ""
	var any := false
	var taken := false
	var fixed := false
	for t in Msp.tickets:
		if str(t.status) == "Closed":
			continue
		any = true
		taken = taken or str(t.status) != "New"
		fixed = fixed or bool(t.fix_done)
	if not _pc_opened:
		return str(MENTOR.pc)
	if not any:
		return str(MENTOR.wait)
	if fixed:
		return str(MENTOR.close)
	return str(MENTOR.fix) if taken else str(MENTOR.take)


func _mentor_update() -> void:
	var step := _mentor_step()
	if objective == "" or objective == _mentor_obj:
		objective = step
	_mentor_obj = step


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
	_mentor_update()
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			text = ""
	if _next < DAY1.size() and _t >= float(DAY1[_next].at):
		text = str(DAY1[_next].text)
		_left = SHOW_SECS
		_next += 1
