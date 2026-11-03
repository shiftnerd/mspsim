extends Node
# gdlint:disable=max-line-length
# The weekly all-hands (campaigns): on the first day of every week after the first (days 6, 11 and 16) at 14:00 the
# boss calls everyone to the conference room. The whole cast goes and sits down. If YOU are in the conference room
# a few minutes later you attend: a short briefing and a question to ask. Skip it and the boss notices (reputation -1).
# Owner campaign: you are the one giving the all-hands (share the numbers, thank the team, set a priority).

const MEETING_DAYS := [6, 11, 16]
const CALL_AT := 14.0
const HOLD_AT := 14.2
const BOOKS := {
	"rack": "a client's network rack",
	"migration": "a server migration",
	"email24": "an email server that never sleeps",
	"netinstall": "a network install",
	"rdp": "a security scare at a client",
	"ceofraud": "a suspicious wire request",
	"no2fa": "a client who says no",
	"bus": "a day without Alan",
}

var state := ""  # "", "called", "done"
var done_day := -1
var attended := 0
var missed := 0


func _ready() -> void:
	Campaign.day_started.connect(func(_d: int) -> void: state = "")


func reset() -> void:
	state = ""
	done_day = -1
	attended = 0
	missed = 0


func is_meeting_day(day: int) -> bool:
	return Campaign.active and MEETING_DAYS.has(day)


func to_dict() -> Dictionary:
	return {"attended": attended, "missed": missed}


func from_dict(data: Dictionary) -> void:
	reset()
	attended = int(data.get("attended", 0))
	missed = int(data.get("missed", 0))


func _process(_delta: float) -> void:
	if not Campaign.active or Game.title_mode or World.time_scale <= 0.0 or Cards.is_open:
		return
	if not is_meeting_day(Campaign.day) or done_day == Campaign.day or World.clock >= World.DAY_END:
		return
	if state == "" and World.clock > HOLD_AT + 0.05:
		state = "done"  # the clock jumped past it (a trip, a long job): nobody holds it without you
		done_day = Campaign.day
		return
	if state == "" and World.clock >= CALL_AT:
		call_meeting()
	elif state == "called" and World.clock >= HOLD_AT:
		hold()


func call_meeting() -> void:
	state = "called"
	Msp.send_text("Boss", "All-hands in the conference room in a few minutes. Everyone.")
	World.start_all_hands()


func in_conference() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.get_file().get_basename() == "conference"


func hold() -> void:
	state = "done"
	done_day = Campaign.day
	if in_conference():
		attended += 1
		Career.add("meetings")
		Social.change_all(1)
		Skills.add_xp("people", 3)
		if Campaign.mode == "owner":
			_run_owner()
		else:
			_run_tech()
		return
	missed += 1
	if Campaign.mode == "owner":
		Owner.burnout = clampf(Owner.burnout + 2.0, 0.0, 100.0)
		Msp.send_text(
			"Alan",
			"Boss, the team waited in the conference room for the all-hands. Everyone noticed."
		)
	else:
		Campaign.adjust_rep(-1)
		Msp.send_text("Boss", "You missed the all-hands. I noticed. Be there next week.")


# ---- the tech campaign: Morgan runs it
func _unhappiest() -> int:
	var worst := -1
	for c in Sales.active:
		if worst < 0 or Sales.mood(int(c)) < Sales.mood(worst):
			worst = int(c)
	return worst


func _run_tech() -> void:
	var text := (
		"Quick all-hands. Alan and Garrison asked me to share the numbers: reputation is %d and our clients are %d%% happy. "
		% [Campaign.rep, int(Sales.average())]
	)
	text += [
		"Remember to ask users to save before you reboot anything.",
		"Verify the backups every morning.",
		"Close what you fix, and tell clients early when you cannot."
	][(Campaign.day / 5) % 3]
	Cards.ask(
		"Morgan (Manager)",
		text,
		[
			{"label": "ASK ABOUT THE CLIENTS", "id": "clients"},
			{"label": "ASK ABOUT TRAINING", "id": "training"},
			{"label": "WHAT IS COMING UP?", "id": "ahead"},
			{"label": "STAY QUIET", "id": "quiet"},
		],
		func(id: String) -> void: _answer(id)
	)


func _answer(id: String) -> void:
	var text := "Morgan nods and wraps up the meeting."
	match id:
		"clients":
			var worst := _unhappiest()
			if worst >= 0:
				text = (
					"%s is the one I worry about: %d%% happy. Call before they call you."
					% [str(Msp.CLIENTS[worst].name), Sales.mood(worst)]
				)
			Skills.add_xp("people", 3)
		"training":
			var pick := "servers"
			for key in ["security", "networking"]:
				if Skills.level(key) < Skills.level(pick):
					pick = key
			Skills.add_xp(pick, 6)
			text = (
				"Your weakest area is %s. I will put a few hours of reading in your queue. (+6 %s XP)"
				% [str(Skills.NAMES[pick]).to_lower(), str(Skills.NAMES[pick])]
			)
		"ahead":
			text = _preview()
	Cards.ask(
		"Morgan (Manager)", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass
	)


# what is on the calendar for the next five days
func _preview() -> String:
	var names := []
	for d in range(Campaign.day + 1, Campaign.day + 6):
		for ev in Story.DAYS.get(d, []):
			var kind := str(ev.get("kind", ""))
			if kind == "playbook" and BOOKS.has(str(ev.book)):
				names.append(str(BOOKS[str(ev.book)]))
			elif kind == "install":
				names.append("a desktop install")
			elif kind == "ransomware":
				names.append("trouble at the law firm")
	if names.is_empty():
		return "Nothing scary on the calendar this week. Use the quiet to study."
	return "Coming up this week: %s. Be ready." % ", ".join(names)


# ---- the owner campaign: you give the all-hands
func _run_owner() -> void:
	Cards.ask(
		"All-hands",
		"Your whole crew is here, coffee in hand. What do you want to say?",
		[
			{"label": "SHARE THE NUMBERS", "id": "numbers"},
			{"label": "THANK THE TEAM", "id": "thanks"},
			{"label": "SET A PRIORITY: BACKUPS AND UPDATES", "id": "priority"},
			{"label": "KEEP IT SHORT", "id": "short"},
		],
		func(id: String) -> void: _owner_answer(id)
	)


func _owner_answer(id: String) -> void:
	var text := "Short and sweet. Everybody gets back to work."
	match id:
		"numbers":
			Owner.burnout = clampf(Owner.burnout - 3.0, 0.0, 100.0)
			text = "You walk them through cash, clients and where the company is headed. Transparency feels good. (burnout -3)"
		"thanks":
			Owner.burnout = clampf(Owner.burnout - 2.0, 0.0, 100.0)
			Social.change_all(2)
			text = "You thank each of them by name. Dan looks a little misty. (burnout -2, the team likes you more)"
		"priority":
			for c in Sales.active:
				Owner.patch_debt[int(c)] = maxf(0.0, float(Owner.patch_debt.get(int(c), 0.0)) - 1.0)
			text = "Backups and updates come first this week. The crew gets a clear target. (patch debt down)"
	Cards.ask("All-hands", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
