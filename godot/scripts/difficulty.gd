extends Node
# gdlint:disable=max-line-length
# One dial for the repeatable activities (printer, karaoke, bowling, escape room, dinner, nerf war):
# a tier (easy / normal / hard), a run seed, and a seeded random stream per system.
#
#   Difficulty.f("karaoke.gap")      a number from TABLE for the current tier
#   Difficulty.rng("karaoke")        the RandomNumberGenerator of one system (same seed = same draws)
#   Difficulty.seed_run(12345)       tests and "daily seed" runs: fixes the seed and restarts every stream
#
# TABLE is the only place the numbers live: [easy, normal, hard]. Normal is exactly today's behaviour.
# Fairness rule: every hard value stays beatable (windows stay open, timers stay long enough for a clean
# run); tests/difficulty.gd checks the karaoke windows against the note gap. Energy is not an input.
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
const SEED_MASK := 0xFFFFFF
const TABLE := {
	# karaoke: seconds between notes, perfect / good hit windows (a miss is a note older than the good window)
	"karaoke.gap": [0.95, 0.75, 0.55],
	"karaoke.perfect": [0.16, 0.12, 0.09],
	"karaoke.good": [0.36, 0.3, 0.24],
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
	# digits in the code (a fourth clue appears on hard) and whether the dial lock tells you bulls and cows (1 = yes)
	"escape.digits": [3, 3, 4],
	"escape.dial": [1, 1, 0],
	# dinner: how many of the three faces show their reaction (the others stay hidden for that round)
	"dinner.reveal": [3, 3, 2],
	# printer: marker speed x, green zone width x, number of test-page questions
	"printer.speed": [0.8, 1.0, 1.25],
	"printer.zone": [1.3, 1.0, 0.85],
	"printer.questions": [1, 2, 3],
	# printer: pulls in the jam chain (a torn scrap adds one, two clean pulls in a row take one off, 3 to 6)
	"printer.chain": [3, 3, 5],
	# nerf war: how long the coworkers wait between shots, x
	"nerf.gap": [1.35, 1.0, 0.7],
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
	"tech.gain": [1.25, 1.0, 0.4],
	"tech.loss": [0.75, 1.0, 2.2],
	"rep.gain": [1.2, 1.0, 0.8],
	"rep.loss": [0.75, 1.0, 1.3],
	"owner.cost": [0.95, 1.0, 1.03],
	"sales.lead": [5, 0, -5],
	"service.trust": [0.7, 1.0, 1.6],
}

var tier := "normal"
var run_seed := 0
var settings_path := "user://mspsim_settings.cfg"

var daily := ""  # "YYYYMMDD" while the run seed is the daily seed of that date
var fixed_take := false  # Free Play toolbox "fixed take": retakes match (see take_reset)

var _streams := {}
var _saved := {}  # stream -> saved state, applied when the stream is first used after a load
var _resumed := {}  # streams whose state came from a save
var _pinned := false  # seed_run() was called: the next new_run() keeps that seed


func _ready() -> void:
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


func label() -> String:
	return str(LABELS.get(tier, "NORMAL"))


# the number for one key at the current tier (0 and an error for an unknown key)
func f(key: String) -> float:
	return float(at(key, tier))


func i(key: String) -> int:
	return int(at(key, tier))


# a campaign dial (Q6): the tier's number while a campaign runs, the normal one otherwise (Free Play and the old tests are unchanged)
func cf(key: String) -> float:
	return f(key) if Campaign.active else float(at(key, "normal"))


# the ticket dials of the running mode: the tech campaign reads tech.pace / tech.sla, the crew campaigns (owner, sales, service) crew.pace / crew.sla
func cm(base: String) -> float:
	return cf(("tech." if Campaign.mode == "tech" else "crew.") + base)


func at(key: String, for_tier: String) -> Variant:
	if not TABLE.has(key):
		push_error("Difficulty: unknown key " + key)
		return 0.0
	return TABLE[key][maxi(0, TIERS.find(for_tier))]


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
	return {"version": 2, "tier": tier, "seed": run_seed, "streams": states, "daily": daily}


func from_dict(data: Dictionary) -> void:
	set_tier(str(data.get("tier", "normal")))
	var saved := int(data.get("seed", 0))
	_pinned = false
	_forget_streams()
	run_seed = saved if saved > 0 else _random_seed()
	daily = str(data.get("daily", ""))
	fixed_take = false
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
