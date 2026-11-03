extends Node
# Fixed campaigns. Two independent saves ("tech" and "owner"); "free" is Free Play / Film Mode:
# the plain sandbox with no days, scoring, reports or random tickets, so you can film without
# worrying about a campaign. A campaign is TOTAL_DAYS working days. At closing time the day
# ends: a report shows the results, pays the paycheck, moves reputation, saves, and the next
# morning starts. Reputation 0 = fired.

signal day_started(day_number: int)

const PLAYER := preload("res://scripts/player.gd")
const TOTAL_DAYS := 20
const FREE := "free"
const MODES := {"tech": "TECH CAMPAIGN", "owner": "OWNER CAMPAIGN"}
const START_REP := 50

var active := false  # a real campaign (not free play) is running
var player_as := ""  # the cast member you play as ("" = a character who is not in World.CAST); saved
var mode := ""
var day := 1
var rep := START_REP
var cash := 0
var history: Array = []
var save_prefix := "user://mspsim_"  # tests point this somewhere else

var _base := {}
var _awaiting := false
var _fired_out := false


func adjust_rep(amount: int) -> void:
	if active:
		rep = clampi(rep + amount, 0, 100)


func save_path(for_mode: String) -> String:
	return save_prefix + for_mode + ".cfg"


func has_save(for_mode: String) -> bool:
	return FileAccess.file_exists(save_path(for_mode))


func saved_day(for_mode: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(save_path(for_mode)) != OK:
		return 0
	return int(cfg.get_value("campaign", "day", 1))


# who you play as in this mode, from the chosen character: the tech campaign never plays a cast member, the owner
# campaign plays Alan or Garrison, Free Play any of the seven (a character outside the cast gives "")
func derive_player_as(for_mode: String) -> String:
	var who: String = World.cast_of(PLAYER.current_character)
	if who == "":
		return ""
	if for_mode == "owner":
		return who if Roles.OWNERS.has(who) else ""
	return who if for_mode == FREE else ""


# the room a new run starts in: your own desk when you play a cast member
func start_scene() -> String:
	var desk: Dictionary = World.player_desk()
	return str(desk.scene) if not desk.is_empty() else "main_floor"


# Free Play: the number keys swap the character you play, so the cast follows (the old one returns to their desk)
func refresh_free() -> void:
	if active or mode != FREE:
		return
	player_as = derive_player_as(FREE)
	World.apply_roster()


func new_game(for_mode: String) -> void:
	mode = for_mode
	active = MODES.has(for_mode)
	player_as = derive_player_as(for_mode)
	Game.vars["start_seated"] = player_as != ""
	day = 1
	rep = START_REP
	cash = 0
	history = []
	_awaiting = false
	Difficulty.new_run()  # first: the Msp fleet and every later draw come from the new seed
	Difficulty.fixed_take = Difficulty.fixed_take and not active  # a fixed take is Free Play only
	Msp.reset()
	Skills.reset()
	Story.reset()
	Social.reset()
	Sales.reset()
	Owner.reset()
	Lync.reset()
	Nerds.reset()
	Shift.reset()
	Growth.reset()
	Outings.reset()
	PrinterGame.reset()
	Talk.reset()
	Meeting.reset()
	Projects.reset()
	Expo.reset()
	Onsite.reset()
	Events.reset()
	Mutators.start(for_mode)
	Mutators.apply_start()
	World.day_len = 240.0 if for_mode == "owner" else 600.0
	Msp.enabled = active
	if active:
		World.begin_next_day(1)
		_begin_day()
	else:
		World.apply_roster()


func continue_game(for_mode: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(save_path(for_mode)) != OK:
		return false
	mode = for_mode
	active = true
	day = int(cfg.get_value("campaign", "day", 1))
	rep = int(cfg.get_value("campaign", "rep", START_REP))
	cash = int(cfg.get_value("campaign", "cash", 0))
	history = cfg.get_value("campaign", "history", [])
	var saved_char := str(cfg.get_value("campaign", "character", "office_adult"))
	PLAYER.current_character = saved_char if saved_char in PLAYER.CHARACTERS else "office_adult"
	var saved_as := str(cfg.get_value("campaign", "player_as", ""))  # old saves: nobody
	player_as = saved_as if World.CAST.has(saved_as) else ""
	Game.vars["start_seated"] = player_as != ""
	_awaiting = false
	Msp.reset()
	Skills.from_dict(cfg.get_value("campaign", "skills", {}))
	Story.reset()
	Social.from_dict(cfg.get_value("campaign", "social", {}))
	Sales.from_dict(cfg.get_value("campaign", "sales", {}))
	Owner.from_dict(cfg.get_value("campaign", "owner", {}))
	Nerds.from_dict(cfg.get_value("campaign", "nerds", {}))
	Shift.from_dict(cfg.get_value("campaign", "shift", {}))
	Growth.from_dict(cfg.get_value("campaign", "growth", {}))
	Outings.from_dict(cfg.get_value("campaign", "outings", {}))
	PrinterGame.from_dict(cfg.get_value("campaign", "printer", {}))
	Difficulty.from_dict(cfg.get_value("campaign", "difficulty", {}))
	Meeting.from_dict(cfg.get_value("campaign", "meeting", {}))
	Projects.from_dict(cfg.get_value("campaign", "projects", {}))
	Expo.from_dict(cfg.get_value("campaign", "conference", {}))
	Onsite.from_dict(cfg.get_value("campaign", "onsite", {}))
	Events.from_dict(cfg.get_value("campaign", "events", {}))
	Mutators.from_dict(cfg.get_value("campaign", "mutators", {}))
	Lync.reset()
	World.day_len = 240.0 if for_mode == "owner" else 600.0
	Story.flags = cfg.get_value("campaign", "story", {})
	var saved_backups: Array = cfg.get_value("campaign", "backups", [])
	if saved_backups.size() == Msp.backups.size():
		Msp.backups = saved_backups
	Msp.enabled = true
	World.begin_next_day(day)
	_begin_day()
	return true


func save() -> void:
	if not active:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "day", day)
	cfg.set_value("campaign", "rep", rep)
	cfg.set_value("campaign", "cash", cash)
	cfg.set_value("campaign", "history", history)
	cfg.set_value("campaign", "character", PLAYER.current_character)
	cfg.set_value("campaign", "player_as", player_as)
	cfg.set_value("campaign", "skills", Skills.to_dict())
	cfg.set_value("campaign", "story", Story.flags)
	cfg.set_value("campaign", "social", Social.to_dict())
	cfg.set_value("campaign", "sales", Sales.to_dict())
	cfg.set_value("campaign", "owner", Owner.to_dict())
	cfg.set_value("campaign", "nerds", Nerds.to_dict())
	cfg.set_value("campaign", "shift", Shift.to_dict())
	cfg.set_value("campaign", "growth", Growth.to_dict())
	cfg.set_value("campaign", "outings", Outings.to_dict())
	cfg.set_value("campaign", "printer", PrinterGame.to_dict())
	cfg.set_value("campaign", "difficulty", Difficulty.to_dict())
	cfg.set_value("campaign", "meeting", Meeting.to_dict())
	cfg.set_value("campaign", "projects", Projects.to_dict())
	cfg.set_value("campaign", "conference", Expo.to_dict())
	cfg.set_value("campaign", "onsite", Onsite.to_dict())
	cfg.set_value("campaign", "events", Events.to_dict())
	cfg.set_value("campaign", "mutators", Mutators.to_dict())
	cfg.set_value("campaign", "backups", Msp.backups)
	cfg.save(save_path(mode))


# the review is over: remember how the year ended and go back to the title
func finish_campaign(ending: String) -> void:
	Mutators.note_finish()
	var meta := ConfigFile.new()
	meta.load(save_prefix + "meta.cfg")
	meta.set_value(mode, "ending", ending)
	meta.save(save_prefix + "meta.cfg")
	if has_save(mode):
		DirAccess.remove_absolute(save_path(mode))
	quit_to_title()


func quit_to_title() -> void:
	World.day_len = 600.0
	active = false
	mode = ""
	player_as = ""
	World.apply_roster()
	Msp.enabled = true
	World.time_scale = 1.0
	Game.ui_open = false
	Game.go_title()


func _begin_day() -> void:
	_base = {
		"score": Msp.score,
		"closed": Msp.closed_ok,
		"missed": Msp.breached,
		"reopened": Msp.reopened,
	}
	# owner weeks are 4 minutes long: tickets arrive faster so the team can actually saturate
	Msp.pace = maxf(0.5, 1.0 - 0.025 * float(day - 1)) * (0.6 if mode == "owner" else 1.0)
	Social.begin_day()
	Story.begin_day(day)
	if mode == "owner":
		Owner.begin_day(day)
	else:
		Shift.begin_day(day)
	Events.begin_day(day)
	Mutators.begin_day(day)
	day_started.emit(day)


func _process(_delta: float) -> void:
	if not active or _awaiting or Game.title_mode or Onsite.busy:
		return
	if Cards.is_open or Outings.busy():
		return  # the week report waits until every card and outing is finished
	var late: bool = World.clock >= 23.5
	if (
		World.clock >= World.DAY_END
		and (not Story.overtime or late)
		and (late or (Shift.can_end_day() and not Outings.invite_due()))
	):
		if late and Story.overtime:
			Story.overtime = false
			Story.ot_hours = World.clock - World.DAY_END
		_end_day()


# ---- end of day ------------------------------------------------------------
func make_report() -> Dictionary:
	var r: Dictionary = Expo.adjust_report(_make_report())
	if Mutators.tag() != "":
		r["mutator"] = Mutators.tag()
	return r


func _make_report() -> Dictionary:
	var closed: int = Msp.closed_ok - int(_base.closed)
	var missed: int = Msp.breached - int(_base.missed)
	var reopened: int = Msp.reopened - int(_base.reopened)
	var open_left: int = Msp.open_tickets().size()
	var points: int = Msp.score - int(_base.score)
	var overtime: float = Story.ot_hours
	var pay := maxi(
		0,
		100 + closed * 20 - missed * 25 - reopened * 10 + int(overtime * 30.0) + Shift.pay_extra()
	)
	var rep_delta := clampi(
		(
			closed * 2
			- missed * 3
			- reopened * 2
			- open_left
			+ Social.rep_bonus()
			+ Sales.rep_effect()
			+ Shift.rep_delta()
		),
		-10,
		8
	)
	var grade := "D"
	if points >= 20 and missed == 0 and open_left == 0 and closed >= 4:
		grade = "S"
	elif points >= 20 and missed == 0:
		grade = "A"
	elif points >= 10:
		grade = "B"
	elif points >= 0:
		grade = "C"
	return {
		"day": day,
		"closed": closed,
		"missed": missed,
		"reopened": reopened,
		"open_left": open_left,
		"points": points,
		"pay": pay,
		"rep_delta": rep_delta,
		"grade": grade,
		"social": Social.day_delta,
		"overtime": snappedf(overtime + Shift.stay_hours, 0.1),
		"clients": int(Sales.average()),
		"energy": int(Shift.energy) if Shift.active() else -1,
		"late": Shift.late_min,
		"oncall": Shift.oncall_pay(),
	}


func _end_day() -> void:
	_awaiting = true
	World.time_scale = 0.0
	Shift.close_day()
	if Computer.is_open:
		Computer.close()
	if Phone.is_open:
		Phone.close()
	var r := make_report()
	if mode == "owner":
		var books := Owner.settle()
		r["rows"] = books.rows
		r["title"] = books.title
		r["grade"] = books.grade
		r["pay"] = 0
		# a profitable week helps the name; only a clearly bad one (a new hire, a project) hurts it
		var profit_rep := 1 if int(books.profit) > 0 else (-1 if int(books.profit) < -1000 else 0)
		r["rep_delta"] = clampi(int(r.rep_delta) + profit_rep, -3, 4)
		cash = Owner.cash
		r["bankrupt"] = books.bankrupt
	else:
		cash += int(r.pay)
	rep = clampi(rep + int(r.rep_delta), 0, 100)
	if r.get("bankrupt", false):
		rep = 0
	r["rep"] = rep
	r["cash"] = cash
	r["total_days"] = TOTAL_DAYS
	r["fired"] = rep <= 0
	_fired_out = rep <= 0
	r["final"] = day >= TOTAL_DAYS or rep <= 0
	r["ending"] = _ending(r)
	history.append({"day": day, "grade": r.grade, "points": r.points})
	Game.ui_open = true
	DayReport.show_report(r)


func _ending(r: Dictionary) -> String:
	if r.fired:
		if mode == "owner":
			return (
				"THE COMPANY IS BANKRUPT."
				if bool(r.get("bankrupt", false))
				else "YOUR NAME IS MUD. THE COMPANY CLOSES."
			)
		return "REPUTATION GONE. YOU ARE FIRED."
	if day < TOTAL_DAYS:
		return ""
	return (
		"YEAR COMPLETE. YOUR BOARD REVIEW IS NEXT."
		if mode == "owner"
		else "YEAR COMPLETE. YOUR YEARLY REVIEW IS NEXT."
	)


# the report screen's button
func report_continue(final: bool) -> void:
	if final:
		_awaiting = true  # the last day settles once: the clock is still at closing time
	else:
		_awaiting = false
	if final and (mode == "tech" or mode == "owner") and not _fired_out:
		Review.start()
		return
	if final:
		if has_save(mode):
			DirAccess.remove_absolute(save_path(mode))
		quit_to_title()
		return
	day += 1
	save()
	World.time_scale = 1.0
	Game.ui_open = false
	World.begin_next_day(day)
	_begin_day()
	Game.go("main_floor", "from_outside")
