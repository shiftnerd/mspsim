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
# the campaign file (`difficulty` section; old saves load as normal with a fresh seed). Only the seed is
# saved, not the position inside each stream: a continued run restarts its streams from the seed.

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
	# escape room: seconds on the clock, seconds a wrong code takes off (in the room)
	"escape.time": [150.0, 120.0, 105.0],
	"escape.wrong_penalty": [5.0, 10.0, 15.0],
	# dinner: how many of the three faces show their reaction (the others stay hidden for that round)
	"dinner.reveal": [3, 3, 2],
	# printer: marker speed x, green zone width x, number of test-page questions
	"printer.speed": [0.8, 1.0, 1.25],
	"printer.zone": [1.3, 1.0, 0.85],
	"printer.questions": [1, 2, 3],
	# nerf war: how long the coworkers wait between shots, x
	"nerf.gap": [1.35, 1.0, 0.7],
}

var tier := "normal"
var run_seed := 0
var settings_path := "user://mspsim_settings.cfg"

var _streams := {}
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
	_streams.clear()


# a fresh run (New Game): a new random seed unless seed_run() fixed one first
func new_run() -> void:
	if _pinned:
		_pinned = false
		_streams.clear()
		return
	run_seed = _random_seed()
	_streams.clear()


# one persistent generator per system: the same seed gives the same draws in the same order
func rng(stream: String) -> RandomNumberGenerator:
	if not _streams.has(stream):
		_streams[stream] = rng_for(stream, 0)
	return _streams[stream]


# an independent generator for (stream, salt), e.g. one per day or per setup
func rng_for(stream: String, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s:%d" % [run_seed, stream, salt])
	return r


# Fisher-Yates with a stream (Array.shuffle() would use the global generator)
func shuffle(list: Array, stream: String) -> void:
	var r := rng(stream)
	for k in range(list.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = list[k]
		list[k] = list[j]
		list[j] = tmp


func pick(list: Array, stream: String) -> Variant:
	return list[rng(stream).randi_range(0, list.size() - 1)]


# ---- campaign save ---------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"version": 1, "tier": tier, "seed": run_seed}


func from_dict(data: Dictionary) -> void:
	set_tier(str(data.get("tier", "normal")))
	var saved := int(data.get("seed", 0))
	_pinned = false
	_streams.clear()
	run_seed = saved if saved > 0 else _random_seed()


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
