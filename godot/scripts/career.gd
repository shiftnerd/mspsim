extends Node
# gdlint:disable=max-line-length,class-definitions-order,class-variable-name
# The Career: lifetime counters and medals that belong to YOU, not to one campaign slot. They are saved in
# user://mspsim_career.cfg (Campaign.save_prefix + "career.cfg"), so New Game, a deleted campaign and the end of a
# year do not reset them. The game feeds them through small hooks (Career.add / best / fastest and the note_*
# helpers); every change re-checks the MEDALS table and toasts a new medal.
#
#   Career.value("tickets")          a counter ("tk.<fix>", "pr.<printer model>", "stars.<game>", "days.<mode>" ...)
#   Career.unlocked("wall_sunset")   a cosmetic unlock (UNLOCKS): true once its medal is earned
#   Career.wallpaper_color()         the Computer desktop tint you picked
#   Career.ringtone_name()           the phone ringtone you picked
#
# MEDALS rules are lists of [counter, op, number] that must all hold; op is ">=" or "<=" (a "<=" counter must be
# set, 0 means never done). Derived counters: printer_models, stars3, wh_stars3, days_total, tk_other.
# MEDALS and UNLOCKS are patchable text tables (story/strings.txt): title and desc are the text. Keep a desc under
# 31 characters so it fits one line on the career screen.

const SCREEN := preload("res://scripts/career_screen.gd")
const VERSION := 1
const GAMES := ["bowling", "karaoke", "escape", "dinner"]  # the four classic games: FULL HOUSE counts only these
const WAREHOUSE_GAMES := ["cornhole", "grill", "chair"]  # warehouse games: own count (wh_stars3), WAREHOUSE ALL-STAR (darts is a casual extra: its own stars.darts and the BULLSEYE medal)
const KNOWN_FIXES := ["password", "spooler", "clear_temp", "reboot", "av", "restore", "adobe", "network", "project"]
const DEFAULT_MEDALS := [
	{"id": "ticket_machine", "title": "TICKET MACHINE", "desc": "CLOSE 50 TICKETS", "rules": [["tickets", ">=", 50]]},
	{"id": "help_desk_hero", "title": "HELP DESK HERO", "desc": "CLOSE 250 TICKETS", "rules": [["tickets", ">=", 250]]},
	{"id": "sticky_savior", "title": "STICKY NOTES SAVIOR", "desc": "CLOSE 10 PASSWORD TICKETS", "rules": [["tk.password", ">=", 10]]},
	{"id": "printer_whisperer", "title": "PRINTER WHISPERER", "desc": "WIN WITH EVERY PRINTER MODEL", "rules": [["printer_models", ">=", 6]]},
	{"id": "never_restarted", "title": "NEVER RESTARTED", "desc": "5 PRINTER WINS, NO PRAYERS", "rules": [["pr_streak", ">=", 5]]},
	{"id": "toner_wrangler", "title": "TONER WRANGLER", "desc": "WIN 20 PRINTER GAMES", "rules": [["printer_wins", ">=", 20]]},
	{"id": "meeting_survivor", "title": "MEETING SURVIVOR", "desc": "ATTEND 5 ALL-HANDS", "rules": [["meetings", ">=", 5]]},
	{"id": "duck_whisperer", "title": "DUCK WHISPERER", "desc": "TALK TO THE DUCK 50 TIMES", "rules": [["duck_squeaks", ">=", 50]]},
	{"id": "people_person", "title": "PEOPLE PERSON", "desc": "PLAY 3 TEAM OUTINGS", "rules": [["outings", ">=", 3]]},
	{"id": "full_house", "title": "FULL HOUSE", "desc": "3 STARS IN ALL FOUR GAMES", "rules": [["stars3", ">=", 4]]},
	{"id": "gutter_guru", "title": "GUTTER GURU", "desc": "ROLL 10 GUTTER BALLS", "rules": [["bowl_gutters", ">=", 10]]},
	{"id": "strike_zone", "title": "STRIKE ZONE", "desc": "ROLL 10 STRIKES", "rules": [["bowl_strikes", ">=", 10]]},
	{"id": "crowd_pleaser", "title": "CROWD PLEASER", "desc": "HIT 20 PERFECT KARAOKE NOTES", "rules": [["kara_perfects", ">=", 20]]},
	{"id": "vault_cracker", "title": "VAULT CRACKER", "desc": "OPEN THE VAULT IN 50 SECONDS", "rules": [["escape_best", "<=", 50]]},
	{"id": "dinner_diplomat", "title": "DINNER DIPLOMAT", "desc": "SCORE 24 AT THE TEAM DINNER", "rules": [["dinner_best", ">=", 24]]},
	{"id": "friday_warrior", "title": "FRIDAY WARRIOR", "desc": "SURVIVE 5 NERF WARS", "rules": [["nerf_wars", ">=", 5]]},
	{"id": "dead_eye", "title": "DEAD EYE", "desc": "HIT COWORKERS 30 TIMES", "rules": [["nerf_hits", ">=", 30]]},
	{"id": "long_shot", "title": "LONG SHOT", "desc": "HIT SOMEONE FROM 150 PX AWAY", "rules": [["nerf_longest", ">=", 150]]},
	{"id": "limbo_legend", "title": "LIMBO LEGEND", "desc": "DUCK 25 DARTS", "rules": [["nerf_dodges", ">=", 25]]},
	{"id": "cat_person", "title": "CAT PERSON", "desc": "PET 10 OFFICE ANIMALS", "rules": [["pets", ">=", 10]]},
	{"id": "on_hold", "title": "ON HOLD, PLEASE", "desc": "HEAR OUT 5 CLIENT COMPLAINTS", "rules": [["vic_calls", ">=", 5]]},
	{"id": "year_one", "title": "YEAR ONE", "desc": "FINISH A CAMPAIGN YEAR", "rules": [["endings", ">=", 1]]},
	{"id": "regular", "title": "REGULAR", "desc": "PLAY 20 DAYS OR WEEKS", "rules": [["days_total", ">=", 20]]},
	{"id": "corner_office", "title": "CORNER OFFICE", "desc": "RUN 10 OWNER WEEKS", "rules": [["days.owner", ">=", 10]]},
	{"id": "hook_shot", "title": "HOOK SHOT", "desc": "5 STRIKES WITH A HOOK", "rules": [["bowl_hook_strikes", ">=", 5]]},
	{"id": "league_champion", "title": "LEAGUE CHAMPION", "desc": "WIN A LEAGUE SEASON", "rules": [["league_titles", ">=", 1]]},
	{"id": "alley_cat", "title": "ALLEY CAT", "desc": "BOWL AT ALL THREE ALLEYS", "rules": [["alleys", ">=", 3]]},
	{"id": "cup_captured", "title": "CUP CAPTURED", "desc": "CAPTURE THE CUP 5 TIMES", "rules": [["nerf_cups", ">=", 5]]},
	{"id": "last_standing", "title": "LAST ONE STANDING", "desc": "WIN 3 ELIMINATION WARS", "rules": [["nerf_elim_wins", ">=", 3]]},
	{"id": "ghost", "title": "GHOST", "desc": "HIDE FOR A WHOLE ROUND", "rules": [["nerf_hide_wins", ">=", 1]]},
	{"id": "arena_regular", "title": "ARENA REGULAR", "desc": "FIGHT IN ALL 3 ARENAS", "rules": [["nerf_arenas", ">=", 3]]},
	{"id": "conference_goer", "title": "CONFERENCE GOER", "desc": "ATTEND THE CONFERENCE", "rules": [["trips", ">=", 1]]},
	{"id": "raffle_luck", "title": "RAFFLE LUCK", "desc": "WIN THE CONFERENCE RAFFLE", "rules": [["raffle_wins", ">=", 1]]},
	{"id": "session_hopper", "title": "SESSION HOPPER", "desc": "SEE 6 DIFFERENT SESSIONS", "rules": [["sessions_seen", ">=", 6]]},
	{"id": "road_warrior", "title": "ROAD WARRIOR", "desc": "SURVIVE 5 TRAFFIC JAMS", "rules": [["road_events", ">=", 5]]},
	{"id": "field_tech", "title": "FIELD TECH", "desc": "FIX 10 ONSITE JOBS", "rules": [["onsite_fixed", ">=", 10]]},
	{"id": "all_sites", "title": "JACK OF ALL SITES", "desc": "FIX JOBS AT 4 SITE TYPES", "rules": [["site_types", ">=", 4]]},
	{"id": "bag_man", "title": "BAG MAN", "desc": "10 BAGS IN THE HOLE", "rules": [["bags_in_hole", ">=", 10]]},
	{"id": "grill_sergeant", "title": "GRILL SERGEANT", "desc": "A COOKOUT, NOTHING BURNT", "rules": [["grill_clean", ">=", 1]]},
	{"id": "old_tree", "title": "OLD TREE", "desc": "FIND THE TREE IN THE WAREHOUSE", "rules": [["old_tree", ">=", 1]]},
	{"id": "lunch_bunch", "title": "LUNCH BUNCH", "desc": "TAKE 5 LUNCH BREAKS", "rules": [["lunches", ">=", 5]]},
	{"id": "dog_days", "title": "DOG DAYS", "desc": "SERVE 20 HOT DOGS", "rules": [["dogs_served", ">=", 20]]},
	{"id": "warehouse_all_star", "title": "WAREHOUSE ALL-STAR", "desc": "3 STARS IN EACH WAREHOUSE GAME", "rules": [["wh_stars3", ">=", 3]]},
	{"id": "habit_forming", "title": "HABIT FORMING", "desc": "ADOPT 5 GOOD HABITS", "rules": [["habits_adopted", ">=", 5]]},
	{"id": "spring_cleaning", "title": "SPRING CLEANING", "desc": "PAY OFF 3 SKELETONS", "rules": [["skeletons_paid", ">=", 3]]},
	{"id": "cleanup_crew", "title": "CLEAN UP CREW", "desc": "FINISH 3 TAKEOVERS", "rules": [["takeovers", ">=", 3]]},
	{"id": "clean_sheet", "title": "CLEAN SHEET", "desc": "END A YEAR WITH CLEAN BOOKS", "rules": [["clean_sheets", ">=", 1]]},
	{"id": "bullseye", "title": "BULLSEYE", "desc": "HIT THE BULL AT DARTS", "rules": [["bulls", ">=", 1]]},
	{"id": "year_two", "title": "SECOND YEAR", "desc": "FINISH A YEAR 2 RUN", "rules": [["year2_done", ">=", 1]]},
	{"id": "line_legend", "title": "LINE TAMER", "desc": "TAME THE LINE PRINTER", "rules": [["pr.line", ">=", 1]]},
	{"id": "svc_ops", "title": "OPS MANAGER", "desc": "BECOME OPS MANAGER", "rules": [["svc_end.ops", ">=", 1]]},
	{"id": "svc_hand", "title": "RIGHT HAND", "desc": "BACK ALAN OR GARRISON", "rules": [["svc_end_lead", ">=", 1]]},
	{"id": "svc_summit", "title": "SUMMIT DIRECTOR", "desc": "TAKE SUMMIT'S ROLL-UP", "rules": [["svc_end.rollup_yes", ">=", 1]]},
]
# cosmetic unlocks: data the rest of the game reads with unlocked(id). kind: wallpaper (value = desktop colour),
# ringtone (the phone Settings picks the name), duck and desk_toy (data only for now, no art yet), and the character creator's
# hat, glasses and beard (value = the accessory id of Look.ACC_STYLES; the title is the name the create row shows; Look.sanitize_acc
# turns a locked one into none, a style with no entry is free). Hats: the hard hat is the warehouse's BAG MAN medal, the Santa hat is
# the old tree's OLD TREE medal (E on the tree at the end of the warehouse), the party hat comes with the team outings. The clothes kinds shirt,
# bottom and shoes (value = the garment id of Look.SHIRT_STYLES / BOTTOM_STYLES / SHOE_STYLES) work the same way; only the work boots are earned (FIELD TECH).
# medal "" = always available; the first entry of a kind is its default.
const DEFAULT_UNLOCKS := [
	{"id": "wall_standard", "kind": "wallpaper", "title": "STANDARD BLUE", "medal": "", "value": "2d6ca8"},
	{"id": "wall_sunset", "kind": "wallpaper", "title": "SUNSET ORANGE", "medal": "ticket_machine", "value": "b8683a"},
	{"id": "wall_graphite", "kind": "wallpaper", "title": "GRAPHITE", "medal": "help_desk_hero", "value": "454b58"},
	{"id": "wall_mint", "kind": "wallpaper", "title": "MINT", "medal": "printer_whisperer", "value": "3a9a84"},
	{"id": "wall_plum", "kind": "wallpaper", "title": "PLUM", "medal": "friday_warrior", "value": "6a4690"},
	{"id": "ring_classic", "kind": "ringtone", "title": "RING RING", "medal": "", "value": ""},
	{"id": "ring_dial", "kind": "ringtone", "title": "OLD DIAL TONE", "medal": "never_restarted", "value": ""},
	{"id": "ring_chime", "kind": "ringtone", "title": "WIND CHIME", "medal": "people_person", "value": ""},
	{"id": "ring_marimba", "kind": "ringtone", "title": "MARIMBA", "medal": "crowd_pleaser", "value": ""},
	{"id": "ring_quack", "kind": "ringtone", "title": "QUACK QUACK", "medal": "duck_whisperer", "value": ""},
	{"id": "duck_classic", "kind": "duck", "title": "RUBBER DUCK", "medal": "", "value": ""},
	{"id": "duck_gold", "kind": "duck", "title": "GOLD RUBBER DUCK", "medal": "duck_whisperer", "value": ""},
	{"id": "duck_pirate", "kind": "duck", "title": "PIRATE RUBBER DUCK", "medal": "limbo_legend", "value": ""},
	{"id": "toy_none", "kind": "desk_toy", "title": "NO DESK TOY", "medal": "", "value": ""},
	{"id": "toy_stress_ball", "kind": "desk_toy", "title": "STRESS BALL", "medal": "meeting_survivor", "value": ""},
	{"id": "toy_pendulum", "kind": "desk_toy", "title": "DESK PENDULUM", "medal": "full_house", "value": ""},
	{"id": "glasses_thin", "kind": "glasses", "title": "THIN", "medal": "", "value": "thin"},
	{"id": "glasses_thick", "kind": "glasses", "title": "THICK", "medal": "", "value": "thick"},
	{"id": "glasses_round", "kind": "glasses", "title": "ROUND", "medal": "", "value": "round"},
	{"id": "glasses_aviator", "kind": "glasses", "title": "AVIATOR", "medal": "", "value": "aviator"},
	{"id": "beard_stubble", "kind": "beard", "title": "STUBBLE", "medal": "", "value": "stubble"},
	{"id": "beard_goatee", "kind": "beard", "title": "GOATEE", "medal": "", "value": "goatee"},
	{"id": "beard_full", "kind": "beard", "title": "FULL BEARD", "medal": "", "value": "full"},
	{"id": "beard_moustache", "kind": "beard", "title": "MOUSTACHE", "medal": "", "value": "moustache"},
	{"id": "hat_beanie", "kind": "hat", "title": "BEANIE", "medal": "", "value": "beanie"},
	{"id": "hat_cap", "kind": "hat", "title": "BALL CAP", "medal": "", "value": "cap"},
	{"id": "hat_hardhat", "kind": "hat", "title": "HARD HAT", "medal": "bag_man", "value": "hardhat"},
	{"id": "hat_santa", "kind": "hat", "title": "SANTA HAT", "medal": "old_tree", "value": "santa"},
	{"id": "hat_bucket", "kind": "hat", "title": "BUCKET HAT", "medal": "", "value": "bucket"},
	{"id": "hat_party", "kind": "hat", "title": "PARTY HAT", "medal": "people_person", "value": "party"},
	{"id": "shirt_polo", "kind": "shirt", "title": "POLO", "medal": "", "value": "polo"},
	{"id": "shirt_tee", "kind": "shirt", "title": "TEE", "medal": "", "value": "tee"},
	{"id": "shirt_button", "kind": "shirt", "title": "BUTTON-DOWN", "medal": "", "value": "button"},
	{"id": "shirt_sweater", "kind": "shirt", "title": "SWEATER", "medal": "", "value": "sweater"},
	{"id": "bottom_trousers", "kind": "bottom", "title": "TROUSERS", "medal": "", "value": "trousers"},
	{"id": "bottom_jeans", "kind": "bottom", "title": "JEANS", "medal": "", "value": "jeans"},
	{"id": "bottom_shorts", "kind": "bottom", "title": "SHORTS", "medal": "", "value": "shorts"},
	{"id": "bottom_skirt", "kind": "bottom", "title": "SKIRT", "medal": "", "value": "skirt"},
	{"id": "shoes_dress", "kind": "shoes", "title": "DRESS SHOES", "medal": "", "value": "dress"},
	{"id": "shoes_sneakers", "kind": "shoes", "title": "SNEAKERS", "medal": "", "value": "sneakers"},
	{"id": "shoes_boots", "kind": "shoes", "title": "WORK BOOTS", "medal": "field_tech", "value": "boots"},
]
# what the career screen lists: [section, label, counter, format]
const COUNTERS := [
	["DESK", "TICKETS CLOSED", "tickets", "n"],
	["", "  PASSWORDS", "tk.password", "n"],
	["", "  PRINTERS", "tk.spooler", "n"],
	["", "  CLEAN-UPS", "tk.clear_temp", "n"],
	["", "  REBOOTS", "tk.reboot", "n"],
	["", "  VIRUSES", "tk.av", "n"],
	["", "  RESTORES", "tk.restore", "n"],
	["", "  OTHER", "tk_other", "n"],
	["", "TECH DAYS WORKED", "days.tech", "n"],
	["", "OWNER WEEKS RUN", "days.owner", "n"],
	["", "YEARS FINISHED", "endings", "n"],
	["", "ALL-HANDS ATTENDED", "meetings", "n"],
	["", "DECISION CARDS SEEN", "cards_seen", "n"],
	["", "MUTATOR WEEKS", "mut_days", "n"],
	["", "STARTS FINISHED", "starts_done", "n"],
	["", "DAILY SEEDS PLAYED", "daily_seeds", "n"],
	["OUTINGS", "OUTINGS PLAYED", "outings", "n"],
	["", "BOWLING BEST", "stars.bowling", "stars"],
	["", "KARAOKE BEST", "stars.karaoke", "stars"],
	["", "ESCAPE ROOM BEST", "stars.escape", "stars"],
	["", "DINNER BEST", "stars.dinner", "stars"],
	["", "CORNHOLE BEST", "stars.cornhole", "stars"],
	["", "BAGS IN THE HOLE", "bags_in_hole", "n"],
	["", "COOKOUT BEST", "stars.grill", "stars"],
	["", "CHAIR RACE BEST", "stars.chair", "stars"],
	["", "PAINTBALL BEST", "stars.paintball", "stars"],
	["", "DARTS BEST", "stars.darts", "stars"],
	["", "BULLSEYES", "bulls", "n"],
	["", "BURGERS SERVED", "burgers_served", "n"],
	["", "HOT DOGS SERVED", "dogs_served", "n"],
	["", "LUNCH BREAKS", "lunches", "n"],
	["", "STRIKES", "bowl_strikes", "n"],
	["", "GUTTER BALLS", "bowl_gutters", "n"],
	["", "HOOK STRIKES", "bowl_hook_strikes", "n"],
	["", "LEAGUE TITLES", "league_titles", "n"],
	["", "ALLEYS BOWLED", "alleys", "n"],
	["", "PERFECT NOTES", "kara_perfects", "n"],
	["", "FASTEST ESCAPE", "escape_best", "secs"],
	["", "BEST DINNER SCORE", "dinner_best", "n"],
	["PRINTER", "PRINTER WINS", "printer_wins", "n"],
	["", "  LASER", "pr.laser", "n"],
	["", "  INKJET", "pr.inkjet", "n"],
	["", "  PLOTTER", "pr.plotter", "n"],
	["", "  COPIER", "pr.mfp", "n"],
	["", "  RECEIPT", "pr.receipt", "n"],
	["", "  DOT MATRIX", "pr.dot", "n"],
	["", "BEST NO-PRAYER RUN", "pr_streak", "n"],
	["NERF AND OFFICE", "NERF HITS", "nerf_hits", "n"],
	["", "DARTS DUCKED", "nerf_dodges", "n"],
	["", "CUPS CAPTURED", "nerf_cups", "n"],
	["", "ELIMINATION WINS", "nerf_elim_wins", "n"],
	["", "ARENAS FOUGHT IN", "nerf_arenas", "n"],
	["", "NERF WARS", "nerf_wars", "n"],
	["", "LONGEST HIT", "nerf_longest", "px"],
	["", "ANIMALS PETTED", "pets", "n"],
	["", "COMPLAINTS HEARD", "vic_calls", "n"],
	["", "CONFERENCES", "trips", "n"],
	["", "SESSIONS SEEN", "sessions_seen", "n"],
	["", "ONSITE JOBS FIXED", "onsite_fixed", "n"],
	["", "TRAFFIC JAMS", "road_events", "n"],
	["SALES", "DEALS WON", "deals_won", "n"],
	["", "CLAWBACKS", "clawbacks", "n"],
	["", "RENEWALS WON", "renewals", "n"],
	["", "UPSELLS SOLD", "upsells", "n"],
	["", "DUCK CHATS", "duck_squeaks", "n"],
	["", "OWNER HELP", "owner_help", "n"],
	["SERVICE DESK", "TICKETS DISPATCHED", "dispatched", "n"],
	["HABITS", "HABITS ADOPTED", "habits_adopted", "n"],
	["", "SKELETONS PAID", "skeletons_paid", "n"],
	["", "TAKEOVERS", "takeovers", "n"],
	["", "CLEAN SHEETS", "clean_sheets", "n"],
]
const FLUSH_SECS := 3.0

var MEDALS: Array = DEFAULT_MEDALS.duplicate(true)
var UNLOCKS: Array = DEFAULT_UNLOCKS.duplicate(true)

var counters := {}
var earned := {}  # medal id -> true
var prefs := {"wallpaper": "", "ringtone": ""}
var toasts := true  # tests switch the medal toast off
var last_medal := ""

var _dirty := false
var _flush_t := 0.0


func _ready() -> void:
	load_file()
	Campaign.day_started.connect(_on_day)


func path() -> String:
	return Campaign.save_prefix + "career.cfg"


# ---- save / load ------------------------------------------------------------------------------------
func load_file() -> void:
	counters = {}
	earned = {}
	prefs = {"wallpaper": "", "ringtone": ""}
	var cfg := ConfigFile.new()
	if cfg.load(path()) != OK:
		return  # no file yet (or an old build): everything starts at zero
	if cfg.has_section("counters"):
		for k in cfg.get_section_keys("counters"):
			counters[k] = int(cfg.get_value("counters", k, 0))
	if cfg.has_section("medals"):
		for k in cfg.get_section_keys("medals"):
			if bool(cfg.get_value("medals", k, false)):
				earned[k] = true
	for k in prefs:
		prefs[k] = str(cfg.get_value("prefs", k, ""))


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("career", "version", VERSION)
	for k in counters:
		cfg.set_value("counters", k, int(counters[k]))
	for k in earned:
		cfg.set_value("medals", k, true)
	for k in prefs:
		cfg.set_value("prefs", k, str(prefs[k]))
	cfg.save(path())
	_dirty = false


func reset_all() -> void:
	counters = {}
	earned = {}
	prefs = {"wallpaper": "", "ringtone": ""}
	_dirty = true


func _process(delta: float) -> void:
	if _dirty:
		_flush_t += delta
		if _flush_t >= FLUSH_SECS:
			_flush_t = 0.0
			save_file()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty:
		save_file()


# ---- counters ---------------------------------------------------------------------------------------
func value(key: String) -> int:
	match key:
		"printer_models":
			var n := 0
			for m in PrinterGame.MODEL_ORDER:  # the six ordinary models; the server room boss is counted apart (pr.line)
				if int(counters.get("pr." + str(m), 0)) > 0:
					n += 1
			return n
		"stars3":
			var n := 0
			for g in GAMES:
				if int(counters.get("stars." + g, 0)) >= 3:
					n += 1
			return n
		"wh_stars3":
			var n := 0
			for g in WAREHOUSE_GAMES:
				if int(counters.get("stars." + g, 0)) >= 3:
					n += 1
			return n
		"days_total":
			return int(counters.get("days.tech", 0)) + int(counters.get("days.owner", 0)) + int(counters.get("days.free", 0))
		"tk_other":
			var sum := 0
			for f in ["password", "spooler", "clear_temp", "reboot", "av", "restore"]:
				sum += int(counters.get("tk." + f, 0))
			return maxi(0, int(counters.get("tickets", 0)) - sum)
	return int(counters.get(key, 0))


func add(key: String, n := 1) -> void:
	counters[key] = int(counters.get(key, 0)) + n
	_changed()


func best(key: String, v: int) -> void:
	if v > int(counters.get(key, 0)):
		counters[key] = v
		_changed()


func fastest(key: String, v: int) -> void:
	var cur := int(counters.get(key, 0))
	if v > 0 and (cur == 0 or v < cur):
		counters[key] = v
		_changed()


func _changed() -> void:
	_dirty = true
	check_medals()


# ---- the hooks the game calls --------------------------------------------------------------------------
func note_ticket(fix: String) -> void:
	counters["tickets"] = int(counters.get("tickets", 0)) + 1
	counters["tk." + fix] = int(counters.get("tk." + fix, 0)) + 1
	_changed()


# a finished outing (result 0-3, or -1 for leaving early); info: strikes, gutters, perfects, escape_secs, dinner_score
func note_outing(game: String, result: int, info := {}) -> void:
	if result < 0:
		return
	if bool(info.get("lunch", false)):
		add("lunches")  # a lunch break is not a team outing (PEOPLE PERSON counts those)
	elif bool(info.get("casual", false)):
		add("casual_games")  # a quick round at the dart board is not a team outing either
	else:
		add("outings")
	best("stars." + game, result)
	note_good(game, result)
	match game:
		"karaoke":
			add("kara_perfects", int(info.get("perfects", 0)))
		"escape":
			if result >= 1:
				fastest("escape_best", int(info.get("secs", 0)))
		"dinner":
			best("dinner_best", int(info.get("score", 0)))
		"cornhole":
			add("bags_in_hole", int(info.get("holes", 0)))
		"darts":
			add("bulls", int(info.get("bulls", 0)))
			best("darts_best", int(info.get("score", 0)))
		"grill":
			add("burgers_served", int(info.get("served", 0)))
			add("dogs_served", int(info.get("dogs", 0)))
			if bool(info.get("clean", false)):
				best("grill_clean", 1)


# the first time an id of a kind is seen (an alley, an arena, a session, a site type) it counts once toward total
func note_first(kind: String, id: String, total: String) -> void:
	var key := kind + "." + id
	if int(counters.get(key, 0)) > 0:
		return
	counters[key] = 1
	add(total)


func note_alley(id: String) -> void:
	note_first("alley", id, "alleys")
func note_bowl(knocked: int, roll: int) -> void:
	if knocked >= 10 and roll == 1:
		add("bowl_strikes")
	elif knocked == 0:
		add("bowl_gutters")


# the mastery ramp (Difficulty.mastery): a GOOD play is 2+ stars, counted once per finished play (never an early exit)
func note_good(game: String, result: int) -> void:
	if result >= 2:
		add("good." + game)


# P4: the server room line printer shows up on onsite printer jobs once you have won with three of the ordinary models
func boss_ready() -> bool:
	return value("printer_models") >= 3


func note_printer(model: String, stars: int, prayed: bool, streak: int) -> void:
	note_good("printer", stars)
	if stars >= 1:
		add("printer_wins")
		add("pr." + model)
	best("pr_streak", streak if not prayed else 0)


func note_nerf_hit(reach: float) -> void:
	add("nerf_hits")
	best("nerf_longest", roundi(reach))


# a campaign year was finished. Cozy runs (the Easy tier) are counted apart: reputation, value and ending medals
# count only for non-cozy runs, every other medal counts everywhere (R16).
func note_ending(ending := "") -> void:
	add("endings.cozy" if Difficulty.cozy_on() else "endings")
	if Campaign.mode == "service" and ending != "" and not Difficulty.cozy_on():
		add("svc_end." + ending)
		if ending in ["alan", "garrison"]:
			add("svc_end_lead")


func _on_day(_d: int) -> void:
	add("days." + (Campaign.mode if Campaign.mode != "" else "free"))


# ---- medals -----------------------------------------------------------------------------------------
func rule_ok(r: Array) -> bool:
	var v := value(str(r[0]))
	var n := int(r[2])
	if str(r[1]) == "<=":
		return v > 0 and v <= n
	return v >= n


func met(m: Dictionary) -> bool:
	for r in m.rules:
		if not rule_ok(r):
			return false
	return true


func has_medal(id: String) -> bool:
	return earned.has(id)


func medal(id: String) -> Dictionary:
	for m in MEDALS:
		if str(m.id) == id:
			return m
	return {}


# award every medal whose rule now holds; returns the ids that are new
func check_medals() -> Array:
	var fresh := []
	for m in MEDALS:
		var id := str(m.id)
		if not earned.has(id) and met(m):
			earned[id] = true
			fresh.append(id)
	if not fresh.is_empty():
		last_medal = str(fresh[fresh.size() - 1])
		if toasts:
			Hints.toast("MEDAL EARNED: " + str(medal(last_medal).title), 4.0)
		save_file()
	return fresh


# progress text for a locked single-rule medal: "3/10" (empty when it has no count)
func progress(m: Dictionary) -> String:
	if m.rules.size() != 1 or str(m.rules[0][1]) != ">=":
		return ""
	return "%d/%d" % [mini(value(str(m.rules[0][0])), int(m.rules[0][2])), int(m.rules[0][2])]


func earned_count() -> int:
	var n := 0
	for m in MEDALS:
		if earned.has(str(m.id)):
			n += 1
	return n


# ---- cosmetic unlocks -------------------------------------------------------------------------------
func unlock_entry(id: String) -> Dictionary:
	for u in UNLOCKS:
		if str(u.id) == id:
			return u
	return {}


func unlocked(id: String) -> bool:
	var u := unlock_entry(id)
	if u.is_empty():
		return false
	return str(u.medal) == "" or earned.has(str(u.medal))


func unlocked_of(kind: String) -> Array:
	var out := []
	for u in UNLOCKS:
		if str(u.kind) == kind and unlocked(str(u.id)):
			out.append(u)
	return out


# the id picked for a kind (falls back to the default when the pick is not unlocked)
func pick_of(kind: String) -> Dictionary:
	var list := unlocked_of(kind)
	if list.is_empty():
		return {}
	for u in list:
		if str(u.id) == str(prefs.get(kind, "")):
			return u
	return list[0]


func cycle_pick(kind: String, step := 1) -> Dictionary:
	var list := unlocked_of(kind)
	if list.is_empty():
		return {}
	var cur := str(pick_of(kind).id)
	var at := 0
	for i in list.size():
		if str(list[i].id) == cur:
			at = i
	var nxt: Dictionary = list[posmod(at + step, list.size())]
	prefs[kind] = str(nxt.id)
	_dirty = true
	save_file()
	return nxt


func wallpaper_color() -> Color:
	var u := pick_of("wallpaper")
	return Color(str(u.value)) if not u.is_empty() and str(u.value) != "" else Color("2d6ca8")


# the Sfx id of the ringtone you picked (RING RING is the plain "text" blip)
func ringtone_sfx() -> String:
	var id := str(pick_of("ringtone").get("id", ""))
	return id if id in ["ring_dial", "ring_chime", "ring_marimba", "ring_quack"] else "text"


func ringtone_name() -> String:
	var u := pick_of("ringtone")
	return str(u.title) if not u.is_empty() else "RING RING"


# ---- the screen -------------------------------------------------------------------------------------
# open the career screen on a CanvasLayer under the scene tree root; closing frees it. Returns the screen.
func open_screen(on_close := Callable()) -> Node:
	var layer := CanvasLayer.new()
	layer.layer = 70
	var screen: Node2D = SCREEN.new()
	layer.add_child(screen)
	get_tree().root.add_child(layer)
	var was_ui := Game.ui_open
	Game.ui_open = true
	screen.closed.connect(
		func() -> void:
			Game.ui_open = was_ui
			layer.queue_free()
			if on_close.is_valid():
				on_close.call()
	)
	return screen
