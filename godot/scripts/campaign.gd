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
# the campaigns you can start today (title menu, character select); must equal the MODE_DEFS rows with "selectable"
const MODES := {"tech": "TECH CAMPAIGN", "owner": "OWNER CAMPAIGN", "service": "SERVICE CAMPAIGN", "sales": "SALES CAMPAIGN"}
# MODE REGISTRY (X8, "P0b"): one row per campaign mode. The three GATES say which machinery a mode runs:
#   crew   the team works the ticket queue by itself (Owner.team_speed, _work_queue, ticket volume, premature closes)
#   books  cash, P&L, payroll, weekly settle, valuation, the Boardroom app, projects, deal income
#   cards  the weekly decision flow (Owner.CARDS / DAYS, the week structure, partner, player-profile edges)
# The rest are the per-mode properties the code used to hard-code with `mode == "owner"`. A new mode (service, sales) is a
# row here plus its content tables; "selectable" stays false until its slice is playable. See docs/campaign-paths.md 8.1.
const MODE_DEFS := {
	"tech": {
		"label": "TECH CAMPAIGN", "selectable": true, "year2": true,
		"crew": false, "books": false, "cards": false, "books_lite": false,
		"day_len": 600.0, "total_days": 20, "unit": "DAY",
		"hud": "day_rep", "report": "day", "review": "yearly", "review_heading": "YEARLY REVIEW", "review_pages": 2,
		"pace": 1.0, "shift": true, "scars": true, "maya_in_events": true,
		"ending_fired": "REPUTATION GONE. YOU ARE FIRED.",
		"ending_final": "YEAR COMPLETE. YOUR YEARLY REVIEW IS NEXT.",
	},
	"owner": {
		"label": "OWNER CAMPAIGN", "selectable": true, "year2": true,
		"crew": true, "books": true, "cards": true, "books_lite": false,
		"day_len": 240.0, "total_days": 20, "unit": "WEEK",
		"hud": "week_cash", "report": "pnl", "review": "board", "review_heading": "BOARD REVIEW", "review_pages": 3,
		"pace": 0.6, "shift": false, "scars": false, "maya_in_events": false,
		"ending_fired": "YOUR NAME IS MUD. THE COMPANY CLOSES.",
		"ending_final": "YEAR COMPLETE. YOUR BOARD REVIEW IS NEXT.",
	},
	# C4 / V1 (campaign-paths 4): Dan runs the desk; the crew works the queue, no books, a huddle card each day. rep = Morgan's confidence
	"service": {
		"label": "SERVICE CAMPAIGN", "selectable": true, "year2": false,
		"crew": true, "books": false, "cards": true, "books_lite": false,
		"day_len": 360.0, "total_days": 20, "unit": "DAY",
		"hud": "day_rep", "report": "day", "review": "service", "review_heading": "ANNUAL REVIEW", "review_pages": 2,
		"pace": 0.62, "shift": false, "scars": false, "maya_in_events": true,
		"ending_fired": "MORGAN HAS LOST CONFIDENCE. THE DESK GOES TO SOMEONE ELSE.",
		"ending_final": "TWENTY DAYS DONE. YOUR REVIEW WITH MORGAN AND THE OWNERS IS NEXT.",
		"rep_label": "CONF",
	},
	# campaign-paths 5 (C1, slice S1): Vic sells; the crew delivers, light books (SalesCampaign.settle: MRR, commission), cards
	"sales": {
		"label": "SALES CAMPAIGN", "selectable": true, "year2": false,
		"crew": true, "books": true, "cards": true, "books_lite": true,
		"day_len": 240.0, "total_days": 20, "unit": "WEEK",
		"hud": "week_quota", "report": "pnl", "settle": "sales", "review": "sales", "review_heading": "SALES REVIEW", "review_pages": 2,
		"pace": 0.55, "shift": false, "scars": false, "maya_in_events": false,
		"ending_fired": "GARRISON LETS YOU GO. THE PIPELINE STAYS.",
		"ending_final": "TWENTY WEEKS DONE. YOUR SALES REVIEW IS NEXT.",
	},
}
const START_REP := 50

var active := false  # a real campaign (not free play) is running
var player_as := ""  # the cast member you play as ("" = a character who is not in World.CAST); saved
var mode := ""
var day := 1
var rep := START_REP
var scars := 0  # lasting damage (lost data, breached P1s, reopen storms): lowers the reputation ceiling, heals slowly
var cash := 0
var year := 1  # 1 = the normal game, 2 = Year 2 / New Game Plus (Yeartwo, R10b); saved, an old save loads as 1
var build: Dictionary = {}  # the point-buy character build (X7, Build): {} = the flat default, saved with the campaign
var history: Array = []
var save_prefix := "user://mspsim_"  # tests point this somewhere else

var _base := {}
var _awaiting := false
var _fired_out := false


# gains get harder as the name grows: 100 is only for the end of a really good run
func gain_scale() -> float:
	if rep >= 85:
		return 0.25
	if rep >= 72:
		return 0.3
	return 0.6 if rep >= 60 else 1.0


# the most the day report can add at this reputation
func daily_cap() -> int:
	for entry in [[72, 1], [58, 2], [50, 3]]:
		if rep >= int(entry[0]):
			return int(entry[1])
	return 4


func rep_cap() -> int:
	return clampi(100 - scars, 40, 100)


# a lasting cost: the ceiling drops now and recovers one point on each A or S day
func add_scar(amount: int) -> void:
	if not active:
		return
	scars = mini(scars + amount, 60)
	rep = mini(rep, rep_cap())


func adjust_rep(amount: int) -> void:
	if not active:
		return
	var change := amount
	if amount > 0:
		change = maxi(1, roundi(float(amount) * gain_scale()))
		change = mini(change, maxi(0, rep_cap() - rep))
	rep = clampi(rep + change, 0, 100)


# ---- the mode registry -------------------------------------------------------------------------
# a registry row ({} for Free Play, no mode, or an unknown name)
func mode_def(for_mode := "") -> Dictionary:
	return MODE_DEFS.get(mode if for_mode == "" else for_mode, {})


# can the player start (and save) this mode? Only registered rows with selectable = true
func is_selectable(for_mode: String) -> bool:
	return bool(MODE_DEFS.get(for_mode, {}).get("selectable", false))


# a registered row that is not playable yet (planned modes): new_game / continue_game / save refuse it
func is_planned(for_mode: String) -> bool:
	return MODE_DEFS.has(for_mode) and not is_selectable(for_mode)


# a property of the current mode (or of for_mode), with a default for Free Play
func prop(key: String, fallback: Variant, for_mode := "") -> Variant:
	return mode_def(for_mode).get(key, fallback)


# the three gates; false outside a running campaign
func crew_active() -> bool:
	return active and bool(mode_def().get("crew", false))


func books_active() -> bool:
	return active and bool(mode_def().get("books", false))


func cards_active() -> bool:
	return active and bool(mode_def().get("cards", false))


func day_len_for(for_mode: String) -> float:
	return float(MODE_DEFS.get(for_mode, {}).get("day_len", 600.0))


func total_days() -> int:
	return int(prop("total_days", TOTAL_DAYS))


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
	if for_mode == "owner":
		return who if Roles.OWNERS.has(who) else "Alan"  # the owner campaign is always played as an owner (X4)
	if for_mode == "sales":
		return "Vic"  # the sales campaign is always played as Vic (C1)
	if for_mode == "service":
		return "Dan"  # the service manager campaign is always played as Dan (C4)
	if who == "":
		return ""
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
	if is_planned(for_mode):
		push_warning("Campaign: mode '%s' is registered but not selectable yet" % for_mode)
		return
	mode = for_mode
	active = is_selectable(for_mode)
	player_as = derive_player_as(for_mode)
	if for_mode in ["owner", "sales"] and World.cast_of(PLAYER.current_character) != player_as:
		PLAYER.current_character = str(World.CAST[player_as].character)  # a direct start plays as Alan (owner) or Vic (sales)
	if for_mode == "service":
		PLAYER.current_character = str(World.CAST["Dan"].character)
	Game.vars["start_seated"] = player_as != ""
	day = 1
	rep = START_REP
	scars = 0
	cash = 0
	history = []
	_awaiting = false
	Yeartwo.reset()
	year = 2 if Yeartwo.take_pending(for_mode) else 1  # New Game Plus (R10b): chosen on the title menu
	Difficulty.new_run()  # first: the Msp fleet and every later draw come from the new seed
	build = Build.take_pending(for_mode)  # the character select's point-buy build; the flat default for direct starts
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
	Service.reset()
	SalesCampaign.reset()
	Mutators.start(for_mode)
	Mutators.apply_start()
	Build.apply_start()
	Yeartwo.begin_run(for_mode)  # Year 2: the carry-over, the three newer clients, the story shuffle
	if for_mode == "service":
		Service.begin_run()
	World.day_len = day_len_for(for_mode)
	Msp.enabled = active
	if for_mode == "sales":
		SalesCampaign.begin_run()
	if active:
		World.begin_next_day(1)
		_begin_day()
	else:
		World.apply_roster()


func continue_game(for_mode: String) -> bool:
	if is_planned(for_mode):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(save_path(for_mode)) != OK:
		return false
	mode = for_mode
	active = true
	day = int(cfg.get_value("campaign", "day", 1))
	rep = int(cfg.get_value("campaign", "rep", START_REP))
	scars = int(cfg.get_value("campaign", "scars", 0))
	cash = int(cfg.get_value("campaign", "cash", 0))
	year = int(cfg.get_value("campaign", "year", 1))  # an old save is Year 1
	history = cfg.get_value("campaign", "history", [])
	var saved_char := str(cfg.get_value("campaign", "character", "office_adult"))
	PLAYER.current_character = saved_char if saved_char in PLAYER.CHARACTERS else "office_adult"
	var saved_as := str(cfg.get_value("campaign", "player_as", ""))  # old saves: nobody
	player_as = saved_as if World.CAST.has(saved_as) else ""
	if for_mode == "owner" and not Roles.OWNERS.has(player_as):
		player_as = "Alan"  # an old owner save: you were the boss, now you are Alan
		PLAYER.current_character = "office_alan"
	if for_mode == "sales":
		player_as = "Vic"
		PLAYER.current_character = "sales_vic"
	if for_mode == "service":
		player_as = "Dan"
		PLAYER.current_character = str(World.CAST["Dan"].character)
	Game.vars["start_seated"] = player_as != ""
	_awaiting = false
	build = Build.from_dict(cfg.get_value("campaign", "build", {}))  # an old save has none: the flat default
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
	Service.from_dict(cfg.get_value("campaign", "service", {}))
	Mutators.from_dict(cfg.get_value("campaign", "mutators", {}))
	Yeartwo.from_dict(cfg.get_value("campaign", "yeartwo", {}))
	SalesCampaign.from_dict(cfg.get_value("campaign", "sales_campaign", {}))
	if for_mode == "sales":
		SalesCampaign.begin_run()
	Lync.reset()
	World.day_len = day_len_for(for_mode)
	Story.flags = cfg.get_value("campaign", "story", {})
	var saved_backups: Array = cfg.get_value("campaign", "backups", [])
	if saved_backups.size() == Msp.backups.size():
		Msp.backups = saved_backups
	Msp.enabled = true
	World.begin_next_day(day)
	_begin_day()
	return true


func save() -> void:
	if not active or not is_selectable(mode):
		return
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "day", day)
	cfg.set_value("campaign", "rep", rep)
	cfg.set_value("campaign", "scars", scars)
	cfg.set_value("campaign", "cash", cash)
	cfg.set_value("campaign", "year", year)
	cfg.set_value("campaign", "history", history)
	cfg.set_value("campaign", "character", PLAYER.current_character)
	cfg.set_value("campaign", "player_as", player_as)
	cfg.set_value("campaign", "build", build)
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
	cfg.set_value("campaign", "service", Service.to_dict())
	cfg.set_value("campaign", "mutators", Mutators.to_dict())
	cfg.set_value("campaign", "yeartwo", Yeartwo.to_dict())
	cfg.set_value("campaign", "sales_campaign", SalesCampaign.to_dict())
	cfg.set_value("campaign", "backups", Msp.backups)
	cfg.save(save_path(mode))


# the review is over: remember how the year ended and go back to the title
func finish_campaign(ending: String) -> void:
	Mutators.note_finish()
	var meta := ConfigFile.new()
	meta.load(save_prefix + "meta.cfg")
	meta.set_value(mode, "ending", ending)
	Yeartwo.record(meta, mode, ending)  # the unlock for New Game Plus: ending, reputation, value, levels, tier
	meta.save(save_prefix + "meta.cfg")
	if has_save(mode):
		DirAccess.remove_absolute(save_path(mode))
	quit_to_title()


func quit_to_title() -> void:
	World.day_len = 600.0
	active = false
	mode = ""
	player_as = ""
	build = {}
	year = 1
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
	# owner weeks are 4 minutes long: tickets arrive faster so the team can actually saturate (registry "pace")
	Msp.pace = maxf(0.5, 1.0 - 0.025 * float(day - 1)) * float(prop("pace", 1.0))
	Social.begin_day()
	Story.begin_day(day)
	if cards_active():
		Owner.begin_day(day)
	if mode == "sales":
		SalesCampaign.begin_week(day)
	if mode == "service":
		Service.begin_day(day)
	if bool(prop("shift", false)):
		Shift.begin_day(day)
	Events.begin_day(day)
	Mutators.begin_day(day)
	Yeartwo.begin_day(day)
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
	r["year"] = year
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
		daily_cap()
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
	if mode == "service":
		Service.close_day(r)  # the scorecard: groups, grade and Morgan's confidence change replace the ticket report
	if books_active() and str(prop("report", "day")) == "pnl":
		var books: Dictionary = SalesCampaign.settle() if str(prop("settle", "owner")) == "sales" else Owner.settle()
		r["rows"] = books.rows
		r["title"] = books.title
		r["grade"] = books.grade
		r["pay"] = 0
		# a profitable week helps the name; only a clearly bad one (a new hire, a project) hurts it
		var profit_rep := 1 if int(books.profit) > 0 else (-1 if int(books.profit) < -1000 else 0)
		r["rep_delta"] = clampi(int(r.rep_delta) + profit_rep, -3, 4)
		if books.has("rep_delta"):
			r["rep_delta"] = int(books.rep_delta)  # the sales campaign scores the week by quota pace and client mood
		cash = Owner.cash
		r["bankrupt"] = books.bankrupt
	else:
		cash += int(r.pay)
	if bool(prop("scars", false)):
		if int(r.reopened) >= 3:
			add_scar(2)  # a reopen storm: the clients stop trusting your closes
		elif scars > 0 and r.grade in ["S", "A"]:
			scars -= 1
		r["rep_cap"] = rep_cap()
	r["rep_delta"] = _tier_rep(int(r.rep_delta))
	rep = clampi(rep + int(r.rep_delta), 0, rep_cap() if bool(prop("scars", false)) else 100)
	if r.get("bankrupt", false):
		rep = 0
	r["rep"] = rep
	r["cash"] = cash
	r["total_days"] = total_days()
	r["fired"] = rep <= 0
	_fired_out = rep <= 0
	r["final"] = day >= total_days() or rep <= 0
	r["ending"] = _ending(r)
	history.append({"day": day, "grade": r.grade, "points": r.points})
	Game.ui_open = true
	DayReport.show_report(r)


# Q6: the tier's say in the daily reputation move: on hard gains shrink and losses grow, on easy the other way round
func _tier_rep(delta: int) -> int:
	if delta == 0:
		return 0
	var pre := "tech." if mode == "tech" else "rep."
	var m := Difficulty.f(pre + ("gain" if delta > 0 else "loss"))
	return (1 if delta > 0 else -1) * maxi(1, roundi(absf(float(delta)) * m))


func _ending(r: Dictionary) -> String:
	if r.fired:
		if bool(r.get("bankrupt", false)):
			return "THE COMPANY IS BANKRUPT."
		if r.has("fired_text"):
			return str(r.fired_text)
		return str(prop("ending_fired", "REPUTATION GONE. YOU ARE FIRED."))
	if day < total_days():
		return ""
	return str(prop("ending_final", "YEAR COMPLETE. YOUR YEARLY REVIEW IS NEXT."))


# the report screen's button
func report_continue(final: bool) -> void:
	if final:
		_awaiting = true  # the last day settles once: the clock is still at closing time
	else:
		_awaiting = false
	if final and str(prop("review", "")) != "" and not _fired_out:
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
