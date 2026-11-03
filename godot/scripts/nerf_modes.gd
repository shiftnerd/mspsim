extends RefCounted
# gdlint:disable=max-line-length
# Nerf war modes and arenas (roadmap R11). Static tables that Nerf preloads; the state lives in Nerf.
# A war started with start_war() and no mode is the classic free-for-all (the rack, a happy coworker firing back).
# V while holding a blaster opens the mode card in an arena room (the office, the cubicle area, the conference room).

const MODES := {
	"cup":
	{
		"label": "CAPTURE THE CUP",
		"line": "KNOCK THE CUP OFF ITS STAND THREE TIMES BEFORE THE CREW DOES. IT MOVES EACH TIME.",
		"win": 3,
	},
	"elim":
	{
		"label": "ELIMINATION",
		"line": "EVERYONE HAS LIVES. A HIT TAKES ONE. LAST ONE STANDING WINS. DUCKING HELPS.",
		"win": 0,
	},
	"hide":
	{
		"label": "HIDE AND SEEK LITE",
		"line": "ONE COWORKER IS THE SEEKER. STAY UNHIT UNTIL THE CLOCK RUNS OUT. DUCK, MOVE, OR STUN THE SEEKER WITH A HIT.",
		"win": 0,
	},
}
const MODE_ORDER := ["cup", "elim", "hide"]
# secs = round length, gap = x the crew's shot interval, lives = elimination lives, cups = where the cup can stand (share of the room width)
const ARENAS := {
	"main_floor": {"label": "THE OFFICE", "secs": 50.0, "gap": 1.0, "lives": 3, "cups": [0.25, 0.5, 0.78]},
	"cubicle_area": {"label": "THE CUBICLE AREA", "secs": 45.0, "gap": 0.9, "lives": 3, "cups": [0.2, 0.45, 0.8]},
	"conference": {"label": "THE CONFERENCE ROOM", "secs": 40.0, "gap": 1.2, "lives": 2, "cups": [0.15, 0.5, 0.85]},
}
const CUP_Y := 44.0  # world y of the cup (on a shelf above the monitors: it takes a lob, hold Z)
const CUP_HALF_W := 14.0
const CUP_FALL_SECS := 0.9
const HIDE_STUN := 4.0
const SEEKER_GAP := [1.6, 2.8]


static func arena_for(scene: String) -> Dictionary:
	return ARENAS.get(scene, {})


static func cup_x(arena: Dictionary, x0: float, width: float, index: int) -> float:
	var spots: Array = arena.cups
	return x0 + width * float(spots[index % spots.size()])


# the next spot at least 60 px away from where the player stands (cycling through the arena's list)
static func next_cup_index(arena: Dictionary, x0: float, width: float, from: int, player_x: float) -> int:
	var n: int = arena.cups.size()
	for step in range(1, n + 1):
		var i := (from + step) % n
		if absf(cup_x(arena, x0, width, i) - player_x) >= 60.0:
			return i
	return (from + 1) % n
