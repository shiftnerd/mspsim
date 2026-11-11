extends Node
# Fixed campaigns. Two independent saves ("tech" and "owner"); "free" is Free Play / Film Mode:
# the plain sandbox with no days, scoring, reports or random tickets, so you can film without
# worrying about a campaign. A campaign is TOTAL_DAYS working days. At closing time the day
# ends: a report shows the results, pays the paycheck, moves reputation, saves, and the next
# morning starts. Reputation 0 = fired.

signal day_started(day_number: int)

const PLAYER := preload("res://scripts/player.gd")
const SaveMigrate := preload("res://scripts/save_migrate.gd")  # X11: old cast names in old saves
const Dash := preload("res://scripts/dash.gd")  # the metrics record (R20), saved in its own "dash" section
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
		"label": "SERVICE CAMPAIGN", "selectable": true, "year2": true,
		"crew": true, "books": false, "cards": true, "books_lite": false,
		"day_len": 360.0, "total_days": 20, "unit": "DAY",
		"hud": "day_rep", "report": "day", "review": "service", "review_heading": "ANNUAL REVIEW", "review_pages": 2,
		"pace": 0.62, "shift": false, "scars": false, "maya_in_events": true,
		"ending_fired": "MORGAN HAS LOST CONFIDENCE. THE DESK GOES TO SOMEONE ELSE.",
		"ending_final": "TWENTY DAYS DONE. YOUR REVIEW WITH MORGAN AND THE OWNERS IS NEXT.",
		"rep_label": "CONF",
	},
	# campaign-paths 5 (C1, slice S1): John sells; the crew delivers, light books (SalesCampaign.settle: MRR, commission), cards
	"sales": {
		"label": "SALES CAMPAIGN", "selectable": true, "year2": true,
		"crew": true, "books": true, "cards": true, "books_lite": true,
		"day_len": 240.0, "total_days": 20, "unit": "WEEK",
		"hud": "week_quota", "report": "pnl", "settle": "sales", "review": "sales", "review_heading": "SALES REVIEW", "review_pages": 2,
		"pace": 0.55, "shift": false, "scars": false, "maya_in_events": false,
		"ending_fired": "GARRISON LETS YOU GO. THE PIPELINE STAYS.",
		"ending_final": "TWENTY WEEKS DONE. YOUR SALES REVIEW IS NEXT.",
	},
}
const START_REP := 50
const CLEAN_REP := 58  # T2: from here on a day's reputation gain needs a clean day
const CLEAN_PER := 6  # one loose end is forgiven for every six tickets closed
const SLOPPY_REP := 62  # from here on a sloppy day costs SLOPPY_PER for every loose end over the allowance
const SLOPPY_PER := 4
const SLOPPY_MAX := 10
const SLOPPY_NOTE := "LOOSE ENDS TODAY: NO REPUTATION GAIN."
const SLOPPY_NOTE_LOSS := "TOO MANY LOOSE ENDS TODAY. THE CLIENTS NOTICED."
const SLOTS := 3  # save slots per mode (R19): slot 1 is the original file name, 2 and 3 add _s2 / _s3

var active := false  # a real campaign (not free play) is running
var player_as := ""  # the cast member you play as ("" = a character who is not in World.CAST); saved
var mode := ""
var day := 1
var rep := START_REP
var scars := 0  # lasting damage (lost data, breached P1s, reopen storms): lowers the reputation ceiling, heals slowly
var cash := 0
var year := 1  # 1 = the normal game, 2 = Year 2 / New Game Plus, 3 = Year 3, the last chapter (Yeartwo, R10); saved, an old save loads as 1
var build: Dictionary = {}  # the point-buy character build (X7, Build): {} = the flat default, saved with the campaign
var history: Array = []
var save_prefix := "user://mspsim_"  # tests point this somewhere else
var slot := 1  # the active save slot 1..SLOTS (R19): save, continue, resume and delete use it; the title sets it

var _base := {}
var _awaiting := false
var _last_hour := 0  # the hour of World.clock last seen (the hourly resume point, R16)
var _snap_due := false  # an hour passed and the resume point is not written yet (a card was open)
var _resume_scene := ""  # the room a resumed run opens in (start_scene hands it out once)
var _fired_out := false


# gains get harder as the name grows: 100 is only for the end of a really good run
func gain_scale() -> float:
	if rep >= 85:
		return 0.25
	if rep >= 72:
		return 0.3
	return 0.6 if rep >= 60 else 1.0


# T2: a day is clean enough when its loose ends (SLAs missed, reopens, plain tickets left in the queue: Msp.loose_open) are
# at most one for every CLEAN_PER tickets closed
func clean_day(closed: int, loose: int) -> bool:
	return loose_excess(closed, loose) <= 0


# the loose ends beyond the allowance (0 or less = a clean day)
func loose_excess(closed: int, loose: int) -> int:
	return loose - floori(float(closed) / float(CLEAN_PER))


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
	if not active or Difficulty.cozy_on():  # cozy Easy: nothing leaves a lasting mark
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


# the DAY LENGTH option (pause menu) takes over when the next morning begins (World.begin_next_day)
func apply_day_length() -> void:
	Difficulty.apply_day_scale()
	World.day_len = day_len_for(mode) * Difficulty.day_scale


func total_days() -> int:
	return int(prop("total_days", TOTAL_DAYS))


# for_slot 0 = the active slot; slot 1 keeps the old file name, so every earlier save loads as slot 1 untouched
func slot_part(for_slot := 0) -> String:
	var n := slot if for_slot <= 0 else for_slot
	return "" if n <= 1 else "_s%d" % clampi(n, 2, SLOTS)


func _ready() -> void:
	# tests and headless runs write saves, the career and the meta file under their own prefix (a test that chose its own keeps it)
	var is_test := DisplayServer.get_name() == "headless" or OS.get_environment("MSPSIM_TEST") == "1"
	if is_test and save_prefix == "user://mspsim_":
		save_prefix = "user://test_%d_" % OS.get_process_id()


func save_path(for_mode: String, for_slot := 0) -> String:
	return save_prefix + for_mode + slot_part(for_slot) + ".cfg"


func has_save(for_mode: String, for_slot := 0) -> bool:
	return FileAccess.file_exists(save_path(for_mode, for_slot))


func saved_day(for_mode: String, for_slot := 0) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(save_path(for_mode, for_slot)) != OK:
		return 0
	return int(cfg.get_value("campaign", "day", 1))


# what the title shows for one slot: {exists, has_save, has_resume, day, text (clock of the resume point), tag, character_name}
func slot_info(for_mode: String, for_slot: int) -> Dictionary:
	var out := {"exists": false, "has_save": false, "has_resume": false, "day": 0, "text": "", "tag": "", "character_name": ""}
	var snap := resume_info(for_mode, for_slot)
	var cfg := ConfigFile.new()
	if cfg.load(save_path(for_mode, for_slot)) == OK:
		out["has_save"] = true
		out["day"] = int(cfg.get_value("campaign", "day", 1))
	elif not snap.is_empty():
		cfg = load_resume(for_mode, for_slot)  # day 1 of the tech campaign: only the resume point exists yet
	else:
		return out
	out["exists"] = true
	if not snap.is_empty():
		out["has_resume"] = true
		out["text"] = str(snap.text)
		if not bool(out.has_save):
			out["day"] = int(snap.day)
	out["tag"] = Yeartwo.tag_of(int(cfg.get_value("campaign", "year", 1)))  # " (YEAR 2)" / " (YEAR 3)"
	var look: Variant = cfg.get_value("campaign", "look", {})
	var who := str(cfg.get_value("campaign", "player_as", ""))
	if look is Dictionary and bool(look.get("active", false)) and str(look.get("name", "")) != "":
		who = str(look.name)
	elif who == "":
		who = str(cfg.get_value("campaign", "character", "office_adult")).get_slice("_", 1)
	out["character_name"] = who.to_upper()
	return out


# R40: every existing save of every campaign, newest first: [{mode, slot, info (slot_info), time (file modified time)}]
func all_slots() -> Array:
	var out := []
	for mode in MODES:
		for n in range(1, SLOTS + 1):
			var info := slot_info(mode, n)
			if not bool(info.exists):
				continue
			var t := maxi(FileAccess.get_modified_time(save_path(mode, n)), FileAccess.get_modified_time(resume_path(mode, n)))
			out.append({"mode": mode, "slot": n, "info": info, "time": t})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.time) > int(b.time))
	return out


# the lowest slot with nothing in it (no end-of-day save and no resume point), 0 when all are full
func first_empty_slot(for_mode: String) -> int:
	for n in range(1, SLOTS + 1):
		if not bool(slot_info(for_mode, n).exists):
			return n
	return 0


# erase one slot: its end-of-day save and its resume point; the meta (medals, Year 2) is untouched
func delete_slot(for_mode: String, for_slot: int) -> void:
	clear_resume(for_mode, for_slot)
	if has_save(for_mode, for_slot):
		DirAccess.remove_absolute(save_path(for_mode, for_slot))


# who you play as in this mode, from the chosen character: the tech campaign never plays a cast member, the owner
# campaign plays Alan or Garrison, Free Play any of the seven (a character outside the cast gives "")
func derive_player_as(for_mode: String) -> String:
	var who: String = World.cast_of(PLAYER.current_character)
	if for_mode == "owner":
		return who if Roles.OWNERS.has(who) else "Alan"  # the owner campaign is always played as an owner (X4)
	if for_mode == "sales":
		return "John"  # the sales campaign is always played as John (C1)
	if for_mode == "service":
		return "Dan"  # the service manager campaign is always played as Dan (C4)
	if who == "":
		return ""
	return who if for_mode == FREE else ""


# the room a new run starts in: your own desk when you play a cast member
func start_scene() -> String:
	if _resume_scene != "":
		var room := _resume_scene
		_resume_scene = ""
		return room
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
	clear_resume(for_mode)  # a new run never offers the old mid-day point
	_resume_scene = ""
	active = is_selectable(for_mode)
	player_as = derive_player_as(for_mode)
	if for_mode in ["owner", "sales"] and World.cast_of(PLAYER.current_character) != player_as:
		PLAYER.current_character = str(World.CAST[player_as].character)  # a direct start plays as Alan (owner) or John (sales)
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
	year = Yeartwo.take_year(for_mode)  # New Game Plus (R10b): 2 or 3 when START YEAR 2 / 3 was chosen on the title menu, else 1
	Difficulty.new_run()  # first: the Msp fleet and every later draw come from the new seed
	World.new_run()
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
	Shop.reset()
	Phone.reset()
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


# from_resume = true loads the mid-day resume point (snapshot) when there is a good one for today; otherwise (and by
# default) the end-of-day save: the morning of that day
func continue_game(for_mode: String, from_resume := false) -> bool:
	if is_planned(for_mode):
		return false
	var cfg := ConfigFile.new()
	var resumed := false
	if from_resume:
		var snap := load_resume(for_mode)
		if snap != null:
			cfg = snap
			resumed = true
	if not resumed and cfg.load(save_path(for_mode)) != OK:
		return false
	SaveMigrate.names(cfg)  # X11: a save from before John and Christy took over the account manager's and the bookkeeper's names
	_resume_scene = ""
	mode = for_mode
	active = true
	day = int(cfg.get_value("campaign", "day", 1))
	rep = int(cfg.get_value("campaign", "rep", START_REP))
	scars = int(cfg.get_value("campaign", "scars", 0))
	cash = int(cfg.get_value("campaign", "cash", 0))
	year = int(cfg.get_value("campaign", "year", 1))  # an old save is Year 1
	history = cfg.get_value("campaign", "history", [])
	# a save from before the rename (the old name is split so a rename script cannot touch it)
	var saved_char := str(cfg.get_value("campaign", "character", "office_adult")).replace("office_te" + "en", "office_intern")
	PLAYER.current_character = saved_char if saved_char in PLAYER.CHARACTERS else "office_adult"
	Look.from_dict(cfg.get_value("campaign", "look", {}))  # an old save has none: a stock character
	var saved_as := str(cfg.get_value("campaign", "player_as", ""))  # old saves: nobody
	player_as = saved_as if World.CAST.has(saved_as) else ""
	if for_mode == "owner" and not Roles.OWNERS.has(player_as):
		player_as = "Alan"  # an old owner save: you were the boss, now you are Alan
		PLAYER.current_character = "office_alan"
	if for_mode == "sales":
		player_as = "John"
		PLAYER.current_character = "office_john"
	if for_mode == "service":
		player_as = "Dan"
		PLAYER.current_character = str(World.CAST["Dan"].character)
	Game.vars["start_seated"] = player_as != ""
	_awaiting = false
	build = Build.from_dict(cfg.get_value("campaign", "build", {}))  # an old save has none: the flat default
	if resumed:
		Msp.from_dict(cfg.get_value("msp", "state", {}))
	else:
		Msp.reset()
	Skills.from_dict(cfg.get_value("campaign", "skills", {}))
	Story.reset()
	if resumed:
		Story.restore(cfg.get_value("story_day", "state", {}))
	Social.from_dict(cfg.get_value("campaign", "social", {}))
	Sales.from_dict(cfg.get_value("campaign", "sales", {}))
	Owner.from_dict(cfg.get_value("campaign", "owner", {}))
	Nerds.from_dict(cfg.get_value("campaign", "nerds", {}))
	Shift.from_dict(cfg.get_value("campaign", "shift", {}))
	Players.from_dict(cfg.get_value("campaign", "coop", {}))  # player 2, when the run was a co-op one
	Growth.from_dict(cfg.get_value("campaign", "growth", {}))
	Outings.from_dict(cfg.get_value("campaign", "outings", {}))
	PrinterGame.from_dict(cfg.get_value("campaign", "printer", {}))
	Difficulty.from_dict(cfg.get_value("campaign", "difficulty", {}))
	Meeting.from_dict(cfg.get_value("campaign", "meeting", {}))
	Shop.from_dict(cfg.get_value("campaign", "shop", {}))
	Phone.from_dict(cfg.get_value("campaign", "phone", {}))  # R37: call cooldowns and counts; an old save has none
	Projects.from_dict(cfg.get_value("campaign", "projects", {}))
	Expo.from_dict(cfg.get_value("campaign", "conference", {}))
	Onsite.from_dict(cfg.get_value("campaign", "onsite", {}))
	Events.from_dict(cfg.get_value("campaign", "events", {}))
	Service.from_dict(cfg.get_value("campaign", "service", {}))
	Mutators.from_dict(cfg.get_value("campaign", "mutators", {}))
	Yeartwo.from_dict(cfg.get_value("campaign", "yeartwo", {}))
	SalesCampaign.from_dict(cfg.get_value("campaign", "sales_campaign", {}))
	Dash.from_dict(cfg.get_value("campaign", "dash", {}))  # an old save has none: empty charts
	if for_mode == "sales":
		SalesCampaign.begin_run()
	Lync.reset()
	World.day_len = day_len_for(for_mode)
	Story.flags = cfg.get_value("campaign", "story", {})
	var saved_backups: Array = cfg.get_value("campaign", "backups", [])
	if saved_backups.size() == Msp.backups.size():
		Msp.backups = saved_backups
	Msp.enabled = true
	if resumed:
		# the day is already under way: no Msp.reset, Story.reset or World.begin_next_day, and none of the day-begin
		# hooks (Mutators, Events, Yeartwo, Story, Shift cards, the day_started listeners) may run a second time
		Resume.apply(cfg)
		Msp.pace = maxf(0.5, 1.0 - (0.015 if mode == "tech" else 0.025) * float(day - 1)) * float(prop("pace", 1.0))
		_last_hour = int(World.clock)
		_snap_due = false
		Sfx.play_music("day")
		return true
	World.begin_next_day(day)
	_begin_day()
	return true


func save() -> void:
	if not active or not is_selectable(mode):
		return
	var cfg := ConfigFile.new()
	_write_sections(cfg)
	cfg.save(save_path(mode))


# every section the end-of-day save holds; the mid-day resume point (snapshot) writes the same ones
func _write_sections(cfg: ConfigFile) -> void:
	cfg.set_value("campaign", "day", day)
	cfg.set_value("campaign", "rep", rep)
	cfg.set_value("campaign", "scars", scars)
	cfg.set_value("campaign", "cash", cash)
	cfg.set_value("campaign", "year", year)
	cfg.set_value("campaign", "history", history)
	cfg.set_value("campaign", "character", PLAYER.current_character)
	cfg.set_value("campaign", "look", Look.to_dict())  # R15: the colours of a custom person (character is office_intern then)
	cfg.set_value("campaign", "player_as", player_as)
	cfg.set_value("campaign", "build", build)
	cfg.set_value("campaign", "skills", Skills.to_dict())
	cfg.set_value("campaign", "story", Story.flags)
	cfg.set_value("campaign", "social", Social.to_dict())
	cfg.set_value("campaign", "sales", Sales.to_dict())
	cfg.set_value("campaign", "owner", Owner.to_dict())
	cfg.set_value("campaign", "nerds", Nerds.to_dict())
	cfg.set_value("campaign", "shift", Shift.to_dict())
	cfg.set_value("campaign", "coop", Players.to_dict())
	cfg.set_value("campaign", "growth", Growth.to_dict())
	cfg.set_value("campaign", "outings", Outings.to_dict())
	cfg.set_value("campaign", "printer", PrinterGame.to_dict())
	cfg.set_value("campaign", "difficulty", Difficulty.to_dict())
	cfg.set_value("campaign", "meeting", Meeting.to_dict())
	cfg.set_value("campaign", "shop", Shop.to_dict())
	cfg.set_value("campaign", "phone", Phone.to_dict())
	cfg.set_value("campaign", "projects", Projects.to_dict())
	cfg.set_value("campaign", "conference", Expo.to_dict())
	cfg.set_value("campaign", "onsite", Onsite.to_dict())
	cfg.set_value("campaign", "events", Events.to_dict())
	cfg.set_value("campaign", "service", Service.to_dict())
	cfg.set_value("campaign", "mutators", Mutators.to_dict())
	cfg.set_value("campaign", "yeartwo", Yeartwo.to_dict())
	cfg.set_value("campaign", "sales_campaign", SalesCampaign.to_dict())
	cfg.set_value("campaign", "backups", Msp.backups)
	cfg.set_value("campaign", "dash", Dash.to_dict())


# ---- the mid-day resume point (R16, docs/scope-cozy-and-resume.md B) -------------------------------------------
# A coarse snapshot at safe moments, in <prefix><mode>_resume.cfg (the end-of-day save is never touched). It is
# written hourly, when the pause menu opens and when the app is paused, loses focus or is closed (resume.gd).
# Lost on resume: cast mid-walk positions, RMM jobs in progress, open UI and cards, mini-games, onsite visits,
# nerf wars, conversations, the exact x position. Free Play is never saved.
func resume_path(for_mode: String, for_slot := 0) -> String:
	return save_prefix + for_mode + slot_part(for_slot) + "_resume.cfg"


# the safe-moment gate: a campaign running, nothing open that holds a callable or a half-played game
func can_snapshot() -> bool:
	if not active or not is_selectable(mode) or Game.title_mode or Game.busy or _awaiting:
		return false
	if World.clock < World.DAY_START or World.clock >= World.DAY_END:
		return false
	if Story.overtime or Net.carrying != "" or Expo.away or Expo.is_trip_day(day):
		return false
	return not _something_open()


# a card, a screen, a mini-game or a visit has the player
func _something_open() -> bool:
	if Game.ui_open or Cards.is_open or Cards.waiting() > 0 or Computer.is_open or Phone.is_open:
		return true
	if DayReport.is_open or Review.is_open or Toolbox.is_open:
		return true
	# step 5: standing at a client site is a safe moment (Resume keeps the visit); the drive itself is not
	return Outings.busy() or Outings.is_open or PrinterGame.is_open or (Onsite.busy and not Onsite.active)


# writes the resume point now; false (and the last good one stays) when it is not a safe moment or the write fails
func snapshot() -> bool:
	if not can_snapshot():
		return false
	var cfg := ConfigFile.new()
	_write_sections(cfg)
	Resume.capture(cfg)
	return Resume.write(cfg, resume_path(mode))


# the newest good resume point of this mode (the file, else its .bak), or null: corrupt, truncated, another version
# or not from the day the end-of-day save is on
func load_resume(for_mode: String, for_slot := 0) -> ConfigFile:
	for suffix in ["", ".bak"]:
		var cfg := ConfigFile.new()
		if cfg.load(resume_path(for_mode, for_slot) + suffix) == OK and _resume_ok(cfg, for_mode, for_slot):
			return cfg
	return null


func _resume_ok(cfg: ConfigFile, for_mode: String, for_slot: int) -> bool:
	var head: Variant = cfg.get_value("resume", "head", {})
	if not (head is Dictionary):
		return false
	if int(head.get("version", 0)) != Resume.VERSION or str(head.get("mode", "")) != for_mode:
		return false
	var want := saved_day(for_mode, for_slot) if has_save(for_mode, for_slot) else 1  # day 1 has no end-of-day save yet
	if int(head.get("day", -1)) != want:
		return false
	for section in ["campaign", "msp", "story_day", "world", "net", "day"]:
		if not cfg.has_section(section):
			return false
	return true


# {day, clock, text} of the good resume point for the title menu, {} when there is none
func resume_info(for_mode: String, for_slot := 0) -> Dictionary:
	var cfg := load_resume(for_mode, for_slot)
	if cfg == null:
		return {}
	var head: Dictionary = cfg.get_value("resume", "head", {})
	var clock := float(head.get("clock", 9.0))
	return {"day": int(head.day), "clock": clock, "text": "%d:%02d" % [int(clock), int((clock - floorf(clock)) * 60.0)]}


func clear_resume(for_mode: String, for_slot := 0) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(resume_path(for_mode, for_slot) + suffix):
			DirAccess.remove_absolute(resume_path(for_mode, for_slot) + suffix)


# the review is over: remember how the year ended and go back to the title
func finish_campaign(ending: String) -> void:
	Mutators.note_finish()
	clear_resume(mode)
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
	Dash.begin_day(day)
	_base = {
		"score": Msp.score,
		"closed": Msp.closed_ok,
		"missed": Msp.breached,
		"reopened": Msp.reopened,
	}
	# owner weeks are 4 minutes long: tickets arrive faster so the team can actually saturate (registry "pace")
	Msp.pace = maxf(0.5, 1.0 - (0.015 if mode == "tech" else 0.025) * float(day - 1)) * float(prop("pace", 1.0))
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
	_last_hour = int(World.clock)
	_snap_due = false
	day_started.emit(day)


func _process(_delta: float) -> void:
	if not active or _awaiting or Game.title_mode or Onsite.busy:
		return
	var hour := int(World.clock)
	if hour > _last_hour:
		_snap_due = true  # the hourly resume point: tried every frame until a safe moment
	_last_hour = hour
	if _snap_due and snapshot():
		_snap_due = false
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
	var cozy := Difficulty.cozy_on()  # cozy Easy: misses, reopens and open tickets cost no pay and no reputation
	var pay := maxi(
		0,
		(
			100
			+ closed * 20
			- (0 if cozy else missed * 25 + reopened * 10)
			+ int(overtime * 30.0)
			+ Shift.pay_extra()
		)
	)
	var rep_delta := clampi(
		(
			closed * 2
			- (0 if cozy else missed * 3 + reopened * 2 + open_left)
			+ Social.rep_bonus()
			+ Sales.rep_effect()
			+ Shift.rep_delta()
		),
		-10,
		daily_cap()
	)
	# T2: past CLEAN_REP the day report only adds reputation for a day that was clean enough (see clean_day); a sloppy day
	# adds nothing, and from SLOPPY_REP on it costs SLOPPY_PER for every loose end too many (at most SLOPPY_MAX). Tech
	# campaign, normal tier (Difficulty `tech.clean`).
	var sloppy := false
	if mode == "tech" and not cozy and rep >= CLEAN_REP and Difficulty.cf("tech.clean") > 0.0:
		var excess := loose_excess(closed, missed + reopened + Msp.loose_open())
		if excess > 0:
			sloppy = true
			rep_delta = mini(rep_delta, -clampi(SLOPPY_PER * excess, SLOPPY_PER, SLOPPY_MAX) if rep >= SLOPPY_REP else 0)
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
		"sloppy": sloppy,
		"grade": grade,
		"social": Social.day_delta,
		"overtime": snappedf(overtime + Shift.stay_hours, 0.1),
		"clients": int(Sales.average()),
		"energy": int(Shift.energy) if Shift.active() else -1,
		"late": Shift.late_min,
		"oncall": Shift.oncall_pay(),
		"favours": Msp.favours_today,
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
		if mode == "owner":
			Owner.OwnerOps.desk_week(r)  # X13: the desk's week is a row of the owner's report (it is what moves the reputation)
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
		cash += Mutators.cash(int(r.pay))
	if bool(prop("scars", false)):
		if int(r.reopened) >= 3:
			add_scar(2)  # a reopen storm: the clients stop trusting your closes
		elif scars > 0 and r.grade in ["S", "A"]:
			scars -= 1
		r["rep_cap"] = rep_cap()
	r["rep_delta"] = _tier_rep(int(r.rep_delta))
	if bool(r.get("sloppy", false)):
		r["notes"] = [SLOPPY_NOTE if int(r.rep_delta) >= 0 else SLOPPY_NOTE_LOSS]
	rep = clampi(rep + int(r.rep_delta), 0, rep_cap() if bool(prop("scars", false)) else 100)
	if Difficulty.cozy_on():
		_cozy_close(r)  # cozy Easy: nobody is fired, the books get one rescue
	elif r.get("bankrupt", false):
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


# cozy Easy (roadmap R16): the reputation never drops below the floor (a PROBATION line instead of "fired") and
# the first time the books go under the bank steps in with a bailout. The report gets soft `notes` lines.
func _cozy_close(r: Dictionary) -> void:
	r["cozy"] = true
	var notes: Array = []
	if str(r.get("grade", "")) == "D":
		r["grade"] = "C"  # the grade floor: on Easy the worst day is a C
	if bool(r.get("bankrupt", false)):
		r["bankrupt"] = false
		if Owner.bailout == 0:
			var amount := int(Difficulty.cz("bailout", 0.0))
			Owner.bailout = amount
			Owner.cash += amount
			cash = Owner.cash
			notes.append(Difficulty.ct("bailout_note") % amount)
			_bailout_card(amount)
		else:
			notes.append(Difficulty.ct("bailout_again"))
	var floor_rep := int(Difficulty.cz("rep_floor", 0.0))
	if rep < floor_rep:
		rep = floor_rep
		notes.append(Difficulty.ct("probation_note"))
		var sender := {"owner": "Christy", "sales": "John"}.get(mode, "Morgan") as String
		Msp.send_text(sender, Difficulty.ct("probation_" + mode))
	if str(r.get("grade", "")) == "C":
		notes.append(Difficulty.ct("grade_c"))  # a C comes with a calm line, so it does not read as failing
	if not notes.is_empty():
		r["notes"] = notes


func _bailout_card(amount: int) -> void:
	var owner_mode := mode == "owner"
	Cards.ask(
		"Christy (Controller)" if owner_mode else "Dana Whitfield (Consultant)",
		Difficulty.ct("bailout_owner" if owner_mode else "bailout_sales") % amount,
		[{"label": Difficulty.ct("bailout_label"), "id": "ok"}],
		func(_id: String) -> void: pass
	)


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
	clear_resume(mode)  # the day is over: its mid-day point is stale
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
