extends RefCounted
# Seated life (R26): a seeded gesture picker for people in chairs (npc.gd, player.gd). Every 5 to 18 seconds of
# seated idle time (typing counts) the owner plays one non-looping gesture animation (`sitstretch` ... `sitnod`, frames
# 86-123 of every sheet) and then goes back to `type` / `sit`. This class only decides WHEN and WHICH; the owner checks
# that nothing else is going on (a call, a chat, an outage grumble, Game.busy ...) and passes `ready` to tick().

const ALL := [
	"sitstretch",
	"sitscratch",
	"sitlook",
	"sityawn",
	"sitslump",
	"sitmouse",
	"sitphone",
	"sitnod",
	"sip",
	"sitcouch",
]
# gestures that only turn the head: fine while a drink is in the hand (the others move the near arm)
const HEAD_ONLY := ["sitlook", "sitnod"]
const MIN_GAP := 5.0
const MAX_GAP := 18.0
# the plain weights (sitmouse needs a desk, sitnod is a meeting / lunch one, sip needs a drink)
const BASE := {
	"sitstretch": 1.0,
	"sitscratch": 1.0,
	"sitlook": 2.0,
	"sityawn": 1.0,
	"sitslump": 1.0,
	"sitmouse": 2.0,
	"sitphone": 1.0,
	"sitnod": 3.0,
	"sip": 1.5,
	"sitcouch": 3.0,
}
# personality: Alan sips, Garrison stretches and leans back, Dan fixes his glasses / scratches, John checks his phone,
# Maya drums and looks around; everyone else (clients' staff included) uses BASE
const PERSONALITY := {
	"Alan": {"sip": 5.0, "sitscratch": 0.5, "sitstretch": 0.5},
	"Garrison": {"sitstretch": 4.0, "sitslump": 3.0, "sitscratch": 0.5},
	"Dan": {"sitscratch": 4.0, "sitlook": 1.0},
	"John": {"sitphone": 5.0, "sitstretch": 1.5},
	"Maya": {"sitmouse": 4.0, "sitlook": 3.5},
}
# the player's character ids (and any NPC that is not a named cast member) map to the same personalities
const CHARACTER_KEY := {
	"office_alan": "Alan",
	"site_alan": "Alan",
	"casual_garrison": "Garrison",
	"office_dan": "Dan",
	"office_john": "John",
	"office_maya": "Maya",
}
const NONE := {}

var who := ""
var rng: RandomNumberGenerator
var timer := 0.0
var lounge := false  # the owner sits in a lounge seat (a couch or an armchair): sitcouch, the arm over the back, is for those
var _mine: Dictionary = NONE


# a stable per-person, per-day number for Difficulty.rng_for
static func salt_for(name_key: String, day: int) -> int:
	return day * 1009 + absi(name_key.hash()) % 1009


func _init(name_key: String, salt: int) -> void:
	who = name_key
	_mine = PERSONALITY.get(CHARACTER_KEY.get(name_key, name_key), NONE)
	rng = Difficulty.rng_for("gesture", salt)
	timer = rng.randf_range(MIN_GAP, MAX_GAP)


# counts seated idle time; true once the gap is over (call pick() next)
func tick(delta: float, ready: bool) -> bool:
	if not ready:
		return false
	timer -= delta
	return timer <= 0.0


func weight(g: String, typing: bool, held: bool, cup_in_reach: bool) -> float:
	if g == "sip":
		return float(_mine.get(g, BASE[g])) if cup_in_reach else 0.0
	if held and not HEAD_ONLY.has(g):
		return 0.0
	if g == "sitmouse" and not typing:
		return 0.0
	if g == "sitnod" and typing:
		return 0.0
	if g == "sitcouch" and (typing or not lounge):
		return 0.0
	return float(_mine.get(g, BASE[g]))


# the next gesture ("" if none fits); restarts the gap
func pick(typing: bool, held: bool, cup_in_reach: bool) -> String:
	timer = rng.randf_range(MIN_GAP, MAX_GAP)
	var total := 0.0
	for g in ALL:
		total += weight(g, typing, held, cup_in_reach)
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for g in ALL:
		roll -= weight(g, typing, held, cup_in_reach)
		if roll <= 0.0 and weight(g, typing, held, cup_in_reach) > 0.0:
			return g
	return "sitlook"


# somebody in the room is talking (a meeting): mostly look their way, sometimes nod; restarts the gap
func pick_listen() -> String:
	timer = rng.randf_range(MIN_GAP, MAX_GAP) * 0.7
	return "sitlook" if rng.randf() < 0.55 else "sitnod"