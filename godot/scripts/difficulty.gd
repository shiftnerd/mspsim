extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# One dial for the repeatable activities (printer, karaoke, bowling, escape room, dinner, nerf war):
# a tier (easy / normal / hard), a run seed, and a seeded random stream per system.
#
#   Difficulty.f("karaoke.gap")      a number from TABLE for the current tier
#   Difficulty.rng("karaoke")        the RandomNumberGenerator of one system (same seed = same draws)
#   Difficulty.seed_run(12345)       tests and "daily seed" runs: fixes the seed and restarts every stream
#
# MASTERY RAMP: the numbers above are the FIRST play of a game. Every GOOD play (2+ stars, not left early) of a game adds
# one to Career counter "good.<game>"; m = clamp(good / RAMP_PLAYS, 0, 1). f() blends the skill-check keys listed in
# MASTERY_KEYS from the tier's value toward a tighter target by m (see mastery_blend). Nothing else is scaled.
#
#   Difficulty.mastery("karaoke")    m of one game (0 with fixed_take, 0 when nothing is counted)
#   Difficulty.zone("bowl", lo, hi)  a target position drawn from the game's own seeded stream "<game>_zone"
#
# TABLE is the only place the numbers live: [easy, normal, hard]. Normal is exactly today's behaviour.
# Fairness rule: every hard value stays beatable (windows stay open, timers stay long enough for a clean
# run); tests/difficulty.gd checks the karaoke windows against the note gap. Energy is not an input of the tiers'
# numbers; the one exception is cozy Easy (below), which softens the energy effects on purpose.
#
# COZY EASY (roadmap R16): the Easy tier inside a campaign is also the cozy mode. Every cozy behaviour hangs on ONE
# function, Difficulty.cozy_on() (true only while a campaign runs on the easy tier), so it can be split off into its
# own toggle later without touching the callers. Numbers are in COZY, texts in COZY_TEXT (story/strings.txt).
# Normal and Hard never read any of it. The DAY LENGTH option (5 / 10 / 15 minutes) lives here too: day_scale.
# The tier is remembered in user://mspsim_settings.cfg (title menu); the tier and run seed are saved in
# the campaign file (`difficulty` section; old saves load as normal with a fresh seed). The state of every
# stream that was used is saved too (`streams`), so a continued run resumes each stream where it stopped;
# an old save has no states and its streams restart from the seed.
#
#   Difficulty.parse_seed("4f2a9c")  a typed or pasted seed (hex; any other text is hashed); 0 = nothing typed
#   Difficulty.daily_seed()          the seed of today's date (local clock, the same for everybody that day)
#   Difficulty.roll_seed()           pick a random seed now and pin it (the character select screen shows it)
#   Difficulty.fixed_take            Free Play toolbox: no random events or mutators, streams restart each take

const TIERS := ["easy", "normal", "hard"]
const LABELS := {"easy": "EASY", "normal": "NORMAL", "hard": "HARD"}
# a line under the tier picker (R16): what the tier feels like in each campaign. Easy is the cozy tier, so its line says so.
const TIER_NOTES := {
	"tech": {
		"easy": "COZY TECH: NOBODY GETS FIRED, THE USERS ARE PATIENT AND THE COFFEE IS ALWAYS HOT.",
		"normal": "TECH AS ISSUED. THE PRINTER STILL HATES YOU AND THE USERS STILL CLICK EVERYTHING.",
		"hard": "TECH ON FIRE. SHORT CLOCKS, LOUD USERS AND SOMEBODY ALWAYS HAS A DEADLINE.",
	},
	"service": {
		"easy": "COZY DESK: A LOVELY CREW, GENTLE CLOCKS AND OWNERS WHO ONLY SIGH QUIETLY.",
		"normal": "THE DESK AS IT IS. TWO OWNERS, TWO OPINIONS, ONE DAN.",
		"hard": "THE OWNERS DISAGREE LOUDER AND THE CREW GETS STUCK AT THE WORST TIMES.",
	},
	"sales": {
		"easy": "COZY SALES: FRIENDLY LEADS, A GENTLE QUOTA AND THE BELL RINGS A LOT.",
		"normal": "THE USUAL PIPELINE. EVERYONE LOVES YOU UNTIL THEY SEE THE PRICE.",
		"hard": "A THIN PIPELINE, CLIENTS WHO HAGGLE AND BYTEBROTHERS CIRCLING.",
	},
	"owner": {
		"easy": "COZY OWNER: A KIND BANK, A KIND STAFF AND PAYROLL ALWAYS CLEARS.",
		"normal": "RUNNING THE SHOP. EVERY DOLLAR HAS AN OPINION.",
		"hard": "THIN MARGINS, TOUCHY CLIENTS AND A RIVAL ALWAYS ONE STEP AHEAD.",
	},
}
const SEED_MASK := 0xFFFFFF
const COZY_TIER := "easy"
const DAY_SCALES := [0.5, 1.0, 1.5]  # the DAY LENGTH option: x on the mode's World.day_len (tech 300 / 600 / 900 s)
# cozy numbers (read through cz(): the cozy value inside a cozy run, the normal one otherwise)
const COZY := {
	"rep_floor": 15,  # reputation never goes below this: PROBATION instead of fired
	"bailout": 2000,  # the one-time rescue when the books go under (owner, sales)
	"sla_window": 1.6,  # x on every SLA window
	"sla_mood": -2,  # client mood for a missed SLA (8 normally)
	"reopen_mood": -1,  # client mood for a reopened ticket (6 normally)
	"ransom_rep": -5,  # reputation lost when ransomware files are gone (15 normally)
	"drain": 0.5,  # x on the energy drain
	"poach": 0.5,  # x on the rival's poaching risk
	"first_ticket": 20.0,  # seconds before the first ticket of day 1 (75 normally)
	"page_chance": 0.25,  # the pager's chance on an on-call night (0.6 normally), and one page a week at most
}
const DEFAULT_COZY_TEXT := {
	"probation_tech": "Nobody is getting fired. The numbers are soft, so the owners are calling it a friendly probation. Just be here tomorrow and we will take it one ticket at a time. - Morgan",
	"probation_service": "Nobody is going anywhere. The owners are a little worried, so call it a friendly probation. Same desk tomorrow, same coffee. - Morgan",
	"probation_owner": "The numbers have us all nervous, but the doors are open and the lights are on. Call it a probation of the friendly kind. See you Monday. - Christy",
	"probation_sales": "Rough stretch, I know. Garrison says it is a probation, but the friendly kind. Come in Monday and we will look at the pipeline together. - John",
	"probation_note": "ON PROBATION, THE FRIENDLY KIND. SEE YOU TOMORROW.",
	"bailout_title": "THE BANK",
	"bailout_owner": "I got on the phone with the bank myself. They will cover $%d so we can make payroll, but they only do this the one time. Please spend it wisely.",
	"bailout_sales": "I know a woman at the bank. She will cover $%d so the company can keep going while you get the pipeline moving. It is a one-time favor, so do not waste it.",
	"bailout_label": "THANK THEM AND TAKE THE MONEY",
	"bailout_note": "THE BANK STEPPED IN WITH $%d. IT ONLY HAPPENS ONCE.",
	"bailout_again": "THE BANK IS BEING PATIENT. PLEASE WATCH THE CASH.",
	"sla_subject": "A note on #%d",
	"sla_mail": "Ticket #%d (%s) ran past its SLA. Nothing to worry about, please have a look when you can.",
	"sla_text": "Ticket #%d ran past its SLA. It happens. The client is fine, just keep an eye on the clock.",
	"reopen_note": "Client asked for another look: not quite right yet.",
	"reopen_mail": "Hi there, it looks like this one is still acting up. No rush, whenever you get a chance to take another look. Thanks!",
	"ransom_mail": "The files are gone and that hurts, but we know you tried everything. Let's talk about backups. - %s",
	"ransom_text": "The files are gone. It happens. Let's talk about backups when you have a minute.",
	"tired_text": "You are getting tired. A cup of coffee from the kitchenette would not hurt.",
	"commute_late": "SLEEP IN. LEAVE AT 8:30 (YOU WILL STILL MAKE IT)",
	"pager_ignore": "LET THE BACKUP PHONE TAKE IT",
	"pager_ignored": "THE BACKUP PHONE TOOK THE PAGE.",
	"stay_one": "STAY 1 HOUR (+$%d)",
	"stay_two": "STAY 2 HOURS (+$%d)",
	"coach_row": "COACHING NOTE",
	"coach_text": "GARRISON WANTS TO WALK THROUGH THE PIPELINE WITH YOU. NO PRESSURE.",
	"coach_first": ": A WORD WITH GARRISON",
	"coach_second": ": ANOTHER LOOK",
	"open_row": "STILL OPEN, CARRIED OVER",
	"grade_c": "C IS A STEADY DAY. THE DESK KEPT RUNNING AND NOBODY IS KEEPING SCORE.",
}
var COZY_TEXT: Dictionary = DEFAULT_COZY_TEXT.duplicate(true)
const TABLE := {
	# karaoke: seconds between notes, perfect / good hit windows (a miss is a note older than the good window)
	"karaoke.gap": [0.95, 0.75, 0.55],
	"karaoke.perfect": [0.16, 0.12, 0.09],
	"karaoke.good": [0.36, 0.3, 0.24],
	# karaoke: the first N misses of a song drain only `grace_drain` of the crowd instead of 6 (hard goes easy on the opening misses)
	"karaoke.grace": [0, 0, 2],
	"karaoke.grace_drain": [6.0, 6.0, 3.0],
	# bowling: added to every opponent's skill (0.48-0.62 today), speed of the aim marker and the power bar
	"bowl.opp_skill": [-0.08, 0.0, 0.08],
	"bowl.aim_speed": [1.1, 1.5, 2.0],
	"bowl.power_speed": [0.9, 1.2, 1.6],
	# bowling (R11): how strict the oil is (x the lane's width) and how wild a hook is (x)
	"bowl.oil": [0.85, 1.0, 1.15],
	"bowl.spin_noise": [0.7, 1.0, 1.4],
	# escape room: seconds on the clock, seconds a wrong code takes off (in the room)
	"escape.time": [150.0, 120.0, 105.0],
	"escape.wrong_penalty": [5.0, 10.0, 15.0],
	# seconds each hint after the first takes off the clock (easy only: a friend's help is not free there either)
	"escape.hint_penalty": [5.0, 0.0, 0.0],
	# digits in the code (a fourth clue appears on hard) and whether the dial lock tells you bulls and cows (1 = yes)
	"escape.digits": [3, 3, 4],
	"escape.dial": [1, 1, 0],
	# dinner: how many of the three faces show their reaction (the others stay hidden for that round)
	"dinner.reveal": [3, 3, 2],
	# dinner ramp (R30): extra points per diner the table expects for 3 and 2 stars; and, at a dinner with the ordering round and the
	# marked topic list (options.variety), how many of the four shared plates suit everybody and the share of your known tastes that is marked
	"dinner.expect": [0.0, 0.0, 0.4],
	"dinner.fits": [3.0, 2.0, 1.0],
	"dinner.hints": [1.0, 1.0, 0.5],
	# printer: marker speed x, green zone width x, number of test-page questions
	"printer.speed": [0.8, 1.0, 1.25],
	"printer.zone": [1.3, 1.0, 0.95],
	"printer.questions": [1, 2, 3],
	# printer: pulls in the jam chain (a torn scrap adds one, two clean pulls in a row take one off, 3 to 6)
	"printer.chain": [3, 3, 5],
	# nerf war: how long the coworkers wait between shots, x
	"nerf.gap": [1.35, 1.0, 0.7],
	# chair race (R12): seconds a wall or a trash can costs, x on the stamina a push costs, x on the size of the wet puddle,
	# x on the 3 and 2 star times, added to the rivals' skill (0.46 to 0.56 today)
	"chair.crash": [0.7, 1.0, 1.5],
	"chair.stamina": [0.9, 1.0, 1.1],
	"chair.slick": [0.8, 1.0, 1.3],
	"chair.par": [1.2, 1.0, 0.9],
	"chair.skill": [-0.08, 0.0, 0.08],
	# paintball: x on the crew's aim and reflexes, x on your own aim
	"paint.skill": [0.8, 1.0, 1.25],
	"paint.acc": [1.1, 1.0, 0.9],
	# cornhole (R21): points to win, added to the crew's skill, how fast the aim marker and the power bar bounce (a bar a second),
	# 1 = a bag that lands just short slides up onto the board
	"corn.to": [11, 15, 21],
	"corn.opp_skill": [-0.08, 0.0, 0.06],
	"corn.aim_speed": [1.0, 1.3, 1.7],
	"corn.power_speed": [0.8, 1.1, 1.5],
	"corn.assist": [1, 0, 0],
	# the cookout (R21): x on how fast a side cooks, x on the width of the flip window, tickets in a round, seconds, x on how often
	# a flare-up starts (Cozy Easy has none)
	"grill.cook_rate": [0.85, 1.0, 1.25],
	"grill.window": [1.3, 1.0, 0.8],
	"grill.tickets": [5, 6, 6],
	"grill.time": [85, 75, 68],
	# darts (warehouse board): the size of the aim reticle's loop in mm (the board is 170 across the radius), how fast it moves (radians a
	# second), the scatter of your own dart in mm, added to the crew's skill
	"darts.drift": [46.0, 58.0, 70.0],
	"darts.speed": [1.5, 1.9, 2.4],
	"darts.noise": [6.0, 7.0, 8.0],
	"darts.opp_skill": [-0.08, 0.0, 0.06],
	"grill.flare": [0.5, 1.0, 1.5],
	# hot dogs (R29): the share of the items on the orders that are dogs (0 = a burger-only cookout)
	"grill.dogs": [0.3, 0.35, 0.4],
	# Q6, the campaigns (read through cf(): only while a campaign runs). tech.*: random ticket interval x (hard = more tickets),
	# SLA window x, chance a quick workaround comes back x. tech.gain / loss and rep.gain / loss: the day report's reputation move x
	# (gains / losses; the tech campaign has its own pair because its reputation climbs fastest).
	# owner.cost: weekly overhead x. sales.lead: added to a new lead's quality. service.trust: x on the trust an owner LOSES.
	"crew.pace": [1.1, 1.0, 0.9],
	"crew.sla": [1.15, 1.0, 0.85],
	"tech.pace": [1.25, 1.0, 0.45],
	"tech.sla": [1.3, 1.0, 0.4],
	"tech.alt_ret": [0.8, 1.0, 1.3],
	"tech.drain": [0.9, 1.0, 2.0],
	"tech.pair": [0.0, 0.0, 0.7],
	# T2: 1 = past reputation 58 a day only adds reputation when it was clean enough (Campaign.clean_day). Off on easy (cozy
	# ignores misses) and on hard (its short clocks make misses routine; tech.loss prices them there)
	"tech.clean": [0.0, 1.0, 0.0],
	# P6 (a): a workstation heavy fix (reimage, rebuild profile) at a client with a site can be done in person. On the remote
	# version: tech.heavy_fail = chance it fails at the last step, tech.heavy_slow = time x. tech.onsite_mood = client mood the visit earns.
	"tech.heavy_fail": [0.0, 0.0, 0.25],
	"tech.heavy_slow": [1.0, 1.0, 1.3],
	"tech.onsite_mood": [3.0, 2.0, 1.0],
	"tech.gain": [1.25, 1.0, 0.4],
	"tech.loss": [0.75, 1.0, 2.2],
	"rep.gain": [1.2, 1.0, 0.8],
	"rep.loss": [0.75, 1.0, 1.3],
	"owner.cost": [0.95, 1.0, 1.03],
	"sales.lead": [5, 0, -5],
	"sales.flow": [0.65, 0.5, 0.3],  # chance of a third new lead in a week
	# X13: two missed quarters end the sales job (0), unless the year as a whole reached this share of both quotas (hard only:
	# its quota is a fifth higher, and a careful year that came close was let go on 1 seed in 5, in Year 2 on 3 in 5)
	"sales.keep": [0.0, 0.0, 0.65],
	"service.trust": [0.7, 1.0, 1.6],
}

# ---- the mastery ramp (per game, not per day) ---------------------------------------------------------
const RAMP_PLAYS := 10  # good plays that bring a game to full mastery
const EASY_RAMP := 0.35  # the Easy tier (cozy included) only blends this share of the way toward the normal value
const HARD_OVER := 0.25  # at full mastery Hard goes at most this share of the normal-to-hard step beyond its own value
const MASTERY_GAMES := {"karaoke": "karaoke", "bowl": "bowling", "escape": "escape", "dinner": "dinner", "printer": "printer", "grill": "grill", "chair": "chair", "paint": "paintball", "corn": "cornhole", "darts": "darts"}
# the keys that tighten with mastery. Everything else stays fixed on purpose: counts and switches (karaoke.grace,
# escape.digits / dial, dinner.reveal, printer.questions / chain, corn.to / assist, grill.tickets), random frequencies
# (grill.flare, grill.dogs), prizes and thresholds (not in TABLE at all), the nerf war and the campaign dials.
const MASTERY_KEYS := [
	"karaoke.gap", "karaoke.perfect", "karaoke.good",
	"bowl.opp_skill", "bowl.aim_speed", "bowl.power_speed", "bowl.oil", "bowl.spin_noise",
	"escape.time", "escape.wrong_penalty",
	"dinner.expect", "dinner.fits", "dinner.hints",
	"printer.speed", "printer.zone",
	"grill.cook_rate", "grill.window", "grill.time",
	"chair.crash", "chair.stamina", "chair.slick", "chair.par", "chair.skill", "paint.skill",
	"corn.opp_skill", "corn.aim_speed", "corn.power_speed",
	"darts.drift", "darts.speed", "darts.opp_skill",
]

var tier := "normal"
var run_seed := 0
var day_scale := 1.0  # the DAY LENGTH in use today (x on the mode's day_len); changes at the next morning
var day_scale_next := 1.0  # the one chosen in the pause menu; saved with the campaign
var settings_path := "user://mspsim_settings.cfg"

var daily := ""  # "YYYYMMDD" while the run seed is the daily seed of that date
var fixed_take := false  # Free Play toolbox "fixed take": retakes match (see take_reset)

var _streams := {}
var _saved := {}  # stream -> saved state, applied when the stream is first used after a load
var _resumed := {}  # streams whose state came from a save
var _pinned := false  # seed_run() was called: the next new_run() keeps that seed


func _ready() -> void:
	# tests and headless runs get their own settings file, so playing the game (tier, look) never changes a test
	var is_test := DisplayServer.get_name() == "headless" or OS.get_environment("MSPSIM_TEST") == "1"
	if is_test and settings_path == "user://mspsim_settings.cfg":  # a test that already chose its own path keeps it
		settings_path = "user://test_%d_settings.cfg" % OS.get_process_id()
	if run_seed == 0:
		run_seed = _random_seed()


func _random_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return maxi(1, r.randi() & SEED_MASK)


# ---- tier ----------------------------------------------------------------------------------------
func tier_index() -> int:
	return maxi(0, TIERS.find(tier))


func set_tier(name: String) -> void:
	tier = name if name in TIERS else "normal"


func cycle_tier(step: int) -> String:
	set_tier(TIERS[(tier_index() + step + TIERS.size()) % TIERS.size()])
	return tier


# the tier picker's note for a campaign mode ("" for a mode without one, such as Free Play)
func tier_note(mode_name: String) -> String:
	return str(TIER_NOTES.get(mode_name, {}).get(tier, ""))


func label() -> String:
	return str(LABELS.get(tier, "NORMAL"))


# the number for one key at the current tier (0 and an error for an unknown key)
func f(key: String) -> float:
	return mastery_blend(key, tier)


func i(key: String) -> int:
	return int(at(key, tier))  # whole numbers (digits, counts, switches) never ramp


# a campaign dial (Q6): the tier's number while a campaign runs, the normal one otherwise (Free Play and the old tests are unchanged)
func cf(key: String) -> float:
	return f(key) if Campaign.active else float(at(key, "normal"))


# the ticket dials of the running mode: the tech campaign reads tech.pace / tech.sla, the crew campaigns (owner, sales, service) crew.pace / crew.sla
func cm(base: String) -> float:
	return cf(("tech." if Campaign.mode == "tech" else "crew.") + base)


# ---- the mastery ramp --------------------------------------------------------------------------------
func game_of(key: String) -> String:
	return str(MASTERY_GAMES.get(key.get_slice(".", 0), ""))


# m 0..1 of one game: good plays / RAMP_PLAYS. Free Play fixed takes stay repeatable (0).
func mastery(game: String) -> float:
	if fixed_take or game == "":
		return 0.0
	return clampf(float(Career.value("good." + game)) / float(RAMP_PLAYS), 0.0, 1.0)


# the value of a key at a tier with a given mastery: easy -> EASY_RAMP of the way to normal, normal -> hard,
# hard -> hard plus HARD_OVER of the normal-to-hard step. m 0 is exactly the TABLE value.
func blend(key: String, for_tier: String, m: float) -> float:
	var v := float(at(key, for_tier))
	if m <= 0.0 or not key in MASTERY_KEYS:
		return v
	var row: Array = TABLE[key]
	var k := maxi(0, TIERS.find(for_tier))
	var target := float(row[2]) + HARD_OVER * (float(row[2]) - float(row[1]))
	var w := m
	if k < 2:
		target = float(row[k + 1])
	if k == 0:
		w = m * EASY_RAMP
	return lerpf(v, target, w)


func mastery_blend(key: String, for_tier: String) -> float:
	return blend(key, for_tier, mastery(game_of(key)))


# a target position (the sweet spot of a skill check) from the game's own stream; no stream draw changes elsewhere
func zone(game: String, lo: float, hi: float) -> float:
	return rng(game + "_zone").randf_range(lo, hi)


func at(key: String, for_tier: String) -> Variant:
	if not TABLE.has(key):
		push_error("Difficulty: unknown key " + key)
		return 0.0
	return TABLE[key][maxi(0, TIERS.find(for_tier))]


# ---- cozy Easy and the day length -------------------------------------------------------------------
# the tier that makes a run cozy (the one place that says so); the character select shows it before the run exists
func cozy_chosen() -> bool:
	return tier == COZY_TIER


# true inside a running campaign on the cozy tier. Every cozy behaviour asks this and nothing else.
func cozy_on() -> bool:
	return Campaign.active and cozy_chosen()


# a cozy number from COZY, or `normal` when cozy is off
func cz(key: String, normal: float) -> float:
	return float(COZY.get(key, normal)) if cozy_on() else normal


# a cozy text (COZY_TEXT, patchable in story/strings.txt)
func ct(key: String) -> String:
	return str(COZY_TEXT.get(key, ""))


# " COZY" for the seed chip and the start toast (empty when the run is not cozy)
func cozy_tag() -> String:
	return "COZY" if cozy_chosen() else ""


# the day length option: x on the mode's day_len. Ticket pace and SLA windows use it so a longer day is not a busier one.
func day_factor() -> float:
	return day_scale if Campaign.active else 1.0


# the factor on every new SLA window: the day length and, when cozy, the wider window
func sla_scale() -> float:
	return day_factor() * cz("sla_window", 1.0)


func set_day_scale(value: float) -> void:
	var best := 1.0
	for s in DAY_SCALES:
		if absf(float(s) - value) < absf(best - value):
			best = float(s)
	day_scale_next = best


func cycle_day_scale(step: int) -> float:
	var k := 1
	for n in DAY_SCALES.size():
		if is_equal_approx(float(DAY_SCALES[n]), day_scale_next):
			k = n
	day_scale_next = float(DAY_SCALES[(k + step + DAY_SCALES.size()) % DAY_SCALES.size()])
	return day_scale_next


# the morning comes: the chosen length takes over
func apply_day_scale() -> void:
	day_scale = day_scale_next


# "10 MIN" for the pause menu: the real length of the chosen day in this mode
func day_label() -> String:
	var secs := Campaign.day_len_for(Campaign.mode) * day_scale_next
	return "%d MIN" % roundi(secs / 60.0)


# ---- seed and random streams -----------------------------------------------------------------------
func seed_text() -> String:
	return "%06X" % run_seed


# fix the run seed (tests, daily seed): every stream starts again from it
func seed_run(value: int) -> void:
	run_seed = maxi(1, value & SEED_MASK)
	_pinned = true
	daily = ""
	_forget_streams()


func _forget_streams() -> void:
	_streams.clear()
	_saved.clear()
	_resumed.clear()


# a random seed now, kept for the next run (the select screen shows it and the player may change it)
func roll_seed() -> int:
	seed_run(_random_seed())
	return run_seed


# text typed or pasted into the seed field: up to 6 hex digits are the code itself ("4F2A9C", "#4f2a9c", "0x1F");
# longer hex keeps its low 24 bits; any other text is hashed (a word is a fine seed). 0 means nothing usable.
func parse_seed(text: String) -> int:
	var t := text.strip_edges().to_upper().replace(" ", "").replace("-", "")
	t = t.trim_prefix("#").trim_prefix("0X")
	if t == "":
		return 0
	var hex := true
	for ch in t:
		if not (ch >= "0" and ch <= "9") and not (ch >= "A" and ch <= "F"):
			hex = false
	if hex:
		return maxi(1, t.hex_to_int() & SEED_MASK)
	return maxi(1, hash(t) & SEED_MASK)


# today's date as the year-month-day number; the same value for everybody on the same local date
func date_number(date: Dictionary = {}) -> int:
	var d := date if not date.is_empty() else Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)


func daily_seed(date: Dictionary = {}) -> int:
	return maxi(1, date_number(date) & SEED_MASK)


# "03 NOV" for the button label
func date_label(date: Dictionary = {}) -> String:
	var d := date if not date.is_empty() else Time.get_date_dict_from_system()
	var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	return "%02d %s" % [int(d.day), months[clampi(int(d.month) - 1, 0, 11)]]


# pin today's seed; the run that starts next counts as a daily seed run in the Career counters
func use_daily(date: Dictionary = {}) -> int:
	seed_run(daily_seed(date))
	daily = "%08d" % date_number(date)
	return run_seed


# a fresh run (New Game): a new random seed unless seed_run() fixed one first
func new_run() -> void:
	day_scale = 1.0
	day_scale_next = 1.0
	if _pinned:
		_pinned = false
		_forget_streams()
		_note_daily()
		return
	run_seed = _random_seed()
	daily = ""
	_forget_streams()


# a daily seed run counts once per date in Career ("daily_seeds")
func _note_daily() -> void:
	if daily == "":
		return
	if int(Career.counters.get("dsd." + daily, 0)) == 0:
		Career.counters["dsd." + daily] = 1
		Career.add("daily_seeds")


# fixed take: every take starts the streams again from the seed, so a retake repeats the draws
func take_reset() -> void:
	_forget_streams()


# one persistent generator per system: the same seed gives the same draws in the same order
func rng(stream: String) -> RandomNumberGenerator:
	if not _streams.has(stream):
		var r := rng_for(stream, 0)
		if _saved.has(stream):
			r.state = int(str(_saved[stream]))
			_resumed[stream] = true
			_saved.erase(stream)
		_streams[stream] = r
	return _streams[stream]


# true when this stream was resumed from a save (its position is already restored)
func resumed(stream: String) -> bool:
	return _resumed.has(stream)


# an independent generator for (stream, salt), e.g. one per day or per setup
func rng_for(stream: String, salt: int) -> RandomNumberGenerator:
	if run_seed == 0:  # an autoload that runs before this one
		run_seed = _random_seed()
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s:%d" % [run_seed, stream, salt])
	return r


# Fisher-Yates with a stream (Array.shuffle() would use the global generator)
func shuffle(list: Array, stream: String) -> void:
	shuffle_with(list, rng(stream))


func shuffle_with(list: Array, r: RandomNumberGenerator) -> void:
	for k in range(list.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = list[k]
		list[k] = list[j]
		list[j] = tmp


func pick(list: Array, stream: String) -> Variant:
	return list[rng(stream).randi_range(0, list.size() - 1)]


# ---- campaign save ---------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	var states := {}
	for name in _saved:  # not used yet since the load: keep the saved position
		states[name] = str(_saved[name])
	for name in _streams:
		states[name] = str(_streams[name].state)
	return {"version": 2, "tier": tier, "seed": run_seed, "streams": states, "daily": daily, "day_scale": day_scale_next}


func from_dict(data: Dictionary) -> void:
	set_tier(str(data.get("tier", "normal")))
	var saved := int(data.get("seed", 0))
	_pinned = false
	_forget_streams()
	run_seed = saved if saved > 0 else _random_seed()
	daily = str(data.get("daily", ""))
	fixed_take = false
	set_day_scale(float(data.get("day_scale", 1.0)))  # an old save has none: the normal day
	day_scale = day_scale_next
	var states: Variant = data.get("streams", {})
	if saved > 0 and states is Dictionary:  # an old save has none: the streams restart from the seed
		for name in states:
			_saved[str(name)] = str(states[name])


# ---- settings (the tier chosen on the title menu) ----------------------------------------------------
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		set_tier(str(cfg.get_value("difficulty", "tier", "normal")))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("difficulty", "tier", tier)
	cfg.save(settings_path)
