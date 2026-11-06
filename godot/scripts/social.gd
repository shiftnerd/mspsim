extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# Coworker opinions of you (campaign only). Each cast member keeps a number from -100 to 100:
#   +  chatting with them, covering the phones (every third call), closing tickets (their own
#      desk's outage ticket counts the most), the team's tickets (every fifth)
#   -  cutting their desk's network, reopened tickets
# Mood decides how they treat you: friends greet you with a heart, cold coworkers do not wave
# or follow you, hostile ones will not even chat. Reputation gets a small nudge from the
# average mood at the end of the day.

signal changed

const ALL := ["Alan", "Garrison", "Dan", "John", "Maya", "Morgan"]  # everyone who has a row (World.CAST order)
# Canon: Alan and Garrison are the two OWNERS of Pixel IT Partners (labels only; opinions work the same for everyone)
const OWNERS := ["Alan", "Garrison"]
const ROLES := {
	"Alan": "CO-OWNER",
	"Garrison": "CO-OWNER",
	"Dan": "NETWORK TECH",
	"John": "ACCOUNT MANAGER",
	"Maya": "TIER 1",
	"Morgan": "MANAGER"
}
const DESK_OWNER := {6: "Alan", 7: "Garrison", 3: "Dan", 4: "John", 2: "Maya", 5: "Morgan"}
const CHAT_GAP := 40.0  # seconds before another chat with the same person counts again
const DEFAULT_THANKS := [
	"thanks for grabbing the phones earlier!",
	"you are a lifesaver on the phones",
	"hey, appreciate the phone coverage",
]
var THANKS: Array = DEFAULT_THANKS.duplicate(true)

var rel := {}
var calls_answered := 0
const MAX_REOPEN_LOSS := 3

var day_delta := 0

var _last_chat := {}
var _closed := 0
var _reopen_loss := 0  # coworker opinion lost to reopens today (capped)


func is_owner(who: String) -> bool:
	return OWNERS.has(who)


# Morgan runs the desk: she does not take tickets and is not one of the techs
func is_manager(who: String) -> bool:
	return who == "Morgan"


# the coworkers you actually have: everyone in the building except the person you play as (and Maya, who is not on
# your payroll in the owner campaign). Morgan is a coworker in every mode.
func people() -> Array:
	var gone: Array = World.roster_gone()
	var out: Array = []
	for who in ALL:
		if not gone.has(who):
			out.append(who)
	return out


func role(who: String) -> String:
	return str(ROLES.get(who, ""))


func _ready() -> void:
	reset()


func reset() -> void:
	rel = {}
	for who in ALL:
		rel[who] = 0
	calls_answered = 0
	day_delta = 0
	_last_chat = {}
	_closed = 0
	_reopen_loss = 0


func value(who: String) -> int:
	return int(rel.get(who, 0))


func change(who: String, amount: int) -> void:
	if not Campaign.active or not rel.has(who) or not people().has(who):
		return
	var before := value(who)
	rel[who] = clampi(before + amount, -100, 100)
	day_delta += value(who) - before
	changed.emit()


func change_all(amount: int) -> void:
	for who in people():
		change(who, amount)


func mood(who: String) -> String:
	var v := value(who)
	if v >= 60:
		return "FRIEND"
	if v >= 25:
		return "FRIENDLY"
	if v > -15:
		return "NEUTRAL"
	if v > -45:
		return "COLD"
	return "HOSTILE"


func is_friendly(who: String) -> bool:
	return Campaign.active and value(who) >= 25


func is_cold(who: String) -> bool:
	return Campaign.active and value(who) <= -15


func is_hostile(who: String) -> bool:
	return Campaign.active and value(who) <= -45


# the bubble icon over a chat with this person
func glyph(who: String) -> String:
	if is_friendly(who):
		return "heart"
	return "?" if is_cold(who) else "!"


func average() -> float:
	var total := 0
	var all := people()
	for who in all:
		total += value(who)
	return float(total) / float(maxi(1, all.size()))


# a small nudge to the end-of-day reputation change
func rep_bonus() -> int:
	if average() >= 40.0:
		return 1
	return -1 if average() <= -20.0 else 0


func note_chat(who: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_chat.get(who, -999.0)) >= CHAT_GAP:
		_last_chat[who] = now
		change(who, 1)


func note_call_answered() -> void:
	calls_answered += 1
	if Campaign.active and calls_answered % 3 == 0:
		change_all(1)
		var pool := people()
		Msp.send_text(pool[randi() % pool.size()], THANKS[randi() % THANKS.size()])


func note_ticket_closed(ticket: Dictionary) -> void:
	if ticket.internal:
		change(str(DESK_OWNER.get(int(ticket.desk), "")), 4)
		return
	_closed += 1
	if _closed % 5 == 0:
		change_all(1)


func note_reopen() -> void:
	# at most 3 points a day, so a bad habit hurts but one rough day does not wreck the row
	if _reopen_loss >= MAX_REOPEN_LOSS:
		return
	_reopen_loss += 1
	change_all(-1)


func note_outage(desk: int) -> void:
	change(str(DESK_OWNER.get(desk, "")), -2)


func note_outage_fixed(desk: int) -> void:
	change(str(DESK_OWNER.get(desk, "")), 2)


func begin_day() -> void:
	day_delta = 0
	_reopen_loss = 0


func to_dict() -> Dictionary:
	return {"rel": rel.duplicate(), "calls": calls_answered}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("rel", {})
	for who in saved:
		if rel.has(who):
			rel[who] = int(saved[who])
	calls_answered = int(data.get("calls", 0))
