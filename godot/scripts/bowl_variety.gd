extends RefCounted
# gdlint:disable=max-line-length
# Bowling variety (roadmap R11, ideas B2 B3 B4 B5 B6): oil patterns, alleys, bowling styles, the hook (spin) and the
# league night. A static helper that Outings preloads; the game state stays in Outings (g.alley, g.spin, league).
# A game started without options uses the classic alley (STRIKE ZONE LANES, house shot, no league), so older tests and
# the Free Play toolbox are unchanged. The tier numbers live in Difficulty.TABLE (bowl.oil, bowl.spin_noise).

# bias = how far the oil pushes the ball to the right (the green zone moves LEFT by that much),
# width = how fast accuracy falls away from the green zone (house shot 1.0 is the classic bar)
const OILS := {
	"house":
	{
		"label": "HOUSE SHOT",
		"bias": 0.0,
		"width": 1.0,
		"line": "HOUSE SHOT: EVEN OIL. THE GREEN ZONE IS WHERE YOU EXPECT IT."
	},
	"dry":
	{
		"label": "DRY LANES",
		"bias": 0.12,
		"width": 1.0,
		"line": "DRY LANES: THE BALL DRIFTS RIGHT. THE GREEN ZONE SITS LEFT. A LEFT HOOK FIGHTS THE DRIFT."
	},
	"sport":
	{
		"label": "SPORT SHOT",
		"bias": 0.03,
		"width": 1.35,
		"line": "SPORT SHOT: TIGHT OIL. THE GREEN ZONE IS NARROW AND MISSES COST MORE."
	},
}
# three alleys: the sign, the oil, and who is there. share = how often the seeded draw picks it
const ALLEYS := {
	"strike_zone":
	{
		"label": "STRIKE ZONE LANES",
		"short": "STRIKE ZONE",
		"oil": "house",
		"league": false,
		"share": 0.4,
		"line": "THE USUAL ALLEY. THE BALL RETURN IS SLOW BUT HONEST."
	},
	"rental":
	{
		"label": "RENTED LANES AT THE REC CENTER",
		"short": "REC CENTER",
		"oil": "dry",
		"league": false,
		"share": 0.35,
		"line": "TWO LANES, ONE BROKEN VENDING MACHINE AND NO OIL TO SPEAK OF."
	},
	"league":
	{
		"label": "PIN PALS LEAGUE NIGHT",
		"short": "LEAGUE NIGHT",
		"oil": "sport",
		"league": true,
		"share": 0.25,
		"line": "THURSDAY LEAGUE. THREE NIGHTS MAKE A SEASON. WEAKER BOWLERS GET A HANDICAP."
	},
}
const ALLEY_ORDER := ["strike_zone", "rental", "league"]
const LEAGUE_NIGHTS := 3
const HOOK_STRIKE := 0.05  # a hook lowers the strike line (0.92) by this much: the angle carries the pins
const HOOK_NOISE := 0.07  # ... and widens the wobble of the roll
const HOOK_LEFT_CANCEL := 0.7  # a hook against the drift cancels this much of it (with the drift: 1 + this)
const GUTTER_ACC := 0.3  # a hook thrown this far from the green zone sweeps off the lane
# how the lane suits a style: oil -> style -> change of the roll's skill (0.48-0.66 today)
const STYLES := {
	"Alan": "straight",
	"Garrison": "hooker",
	"Dan": "power",
	"Vic": "show",
	"Maya": "precise",
	"Morgan": "precise",
}
const STYLE_LABELS := {
	"straight": "STRAIGHT",
	"hooker": "HOOKER",
	"power": "POWER",
	"show": "SHOW-OFF",
	"precise": "PRECISE",
}
const STYLE_FIT := {
	"house": {"straight": 0.0, "hooker": 0.0, "power": 0.0, "show": 0.0, "precise": 0.0},
	"dry": {"straight": -0.05, "hooker": 0.05, "power": 0.0, "show": 0.0, "precise": -0.02},
	"sport": {"straight": 0.02, "hooker": -0.04, "power": -0.05, "show": -0.02, "precise": 0.05},
}


static func alley(id: String) -> Dictionary:
	return ALLEYS.get(id, ALLEYS["strike_zone"])


static func oil(id: String) -> Dictionary:
	return OILS.get(id, OILS["house"])


static func oil_of(alley_id: String) -> Dictionary:
	return oil(str(alley(alley_id).oil))


# where the green zone sits on the 0..1 aim bar for this oil and hook (-1 left, 0 straight, 1 right)
static func center(oil_id: String, spin: int) -> float:
	var bias := float(oil(oil_id).bias)
	var scale := 1.0
	if spin < 0:
		scale = 1.0 - HOOK_LEFT_CANCEL
	elif spin > 0:
		scale = 1.0 + HOOK_LEFT_CANCEL
	return clampf(0.5 - bias * scale, 0.1, 0.9)


# how well the aim marker (0..1) fits the lane: 1 = in the middle of the green zone
static func accuracy(oil_id: String, marker: float, spin: int, tier_width := 1.0) -> float:
	var w := float(oil(oil_id).width) * tier_width
	return clampf(1.0 - absf(marker - center(oil_id, spin)) * 2.0 * w, 0.0, 1.0)


static func style_of(who: String) -> String:
	return str(STYLES.get(who, "straight"))


# change of a bowler's skill on this lane
static func fit(oil_id: String, who: String) -> float:
	return float(STYLE_FIT.get(oil_id, STYLE_FIT["house"]).get(style_of(who), 0.0))


# the seeded draw of tonight's alley; a league season in progress pulls people back to league night
static func pick_alley(rng: RandomNumberGenerator, league_night: int) -> String:
	var shares := {}
	for id in ALLEY_ORDER:
		shares[id] = float(ALLEYS[id].share)
	if league_night > 0:
		shares["league"] = 1.2
	var total := 0.0
	for id in ALLEY_ORDER:
		total += float(shares[id])
	var roll := rng.randf() * total
	for id in ALLEY_ORDER:
		roll -= float(shares[id])
		if roll <= 0.0:
			return id
	return "strike_zone"


# ---- league night -------------------------------------------------------------------------------------
# league = {"night": nights played this season, "totals": {who: pins}, "games": {who: games}, "seasons": n, "titles": n}
static func new_league() -> Dictionary:
	return {"night": 0, "totals": {}, "games": {}, "seasons": 0, "titles": 0}


# handicap of one bowler tonight: 0.9 x the gap to the best average so far (nothing on the first night)
static func handicap(league: Dictionary, who: String) -> int:
	var games: Dictionary = league.get("games", {})
	var totals: Dictionary = league.get("totals", {})
	if not games.has(who) or int(games[who]) <= 0:
		return 0
	var best := 0.0
	for name in games:
		if int(games[name]) > 0:
			best = maxf(best, float(totals.get(name, 0)) / float(games[name]))
	var mine := float(totals.get(who, 0)) / float(games[who])
	return maxi(0, roundi((best - mine) * 0.9))


# add a finished night (scores = {who: pins}); returns {"night": n, "done": bool, "winner": who or ""} and resets at the
# end of a season. Winner = highest season total with handicaps counted.
static func record(league: Dictionary, scores: Dictionary) -> Dictionary:
	var totals: Dictionary = league.totals
	var games: Dictionary = league.games
	var adjusted := {}
	for who in scores:
		adjusted[who] = int(scores[who]) + handicap(league, str(who))
	for who in scores:
		totals[who] = int(totals.get(who, 0)) + int(scores[who])
		games[who] = int(games.get(who, 0)) + 1
	league.night = int(league.night) + 1
	var out := {"night": int(league.night), "done": false, "winner": "", "adjusted": adjusted}
	if int(league.night) >= LEAGUE_NIGHTS:
		var best := -1
		for who in totals:
			var tot := int(totals[who]) + handicap_total(league, str(who))
			if tot > best:
				best = tot
				out.winner = str(who)
		out.done = true
		league.seasons = int(league.seasons) + 1
		if out.winner == "You":
			league.titles = int(league.titles) + 1
		league.night = 0
		league.totals = {}
		league.games = {}
	return out


# the handicap a season total gets: the average gap x the nights played
static func handicap_total(league: Dictionary, who: String) -> int:
	return handicap(league, who) * int(league.get("games", {}).get(who, 0))


static func league_standing(league: Dictionary) -> Array:
	var rows := []
	for who in league.get("totals", {}):
		rows.append(
			{
				"who": str(who),
				"total": int(league.totals[who]),
				"hcp": handicap(league, str(who)),
			}
		)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.total) + int(a.hcp) * 3 > int(b.total) + int(b.hcp) * 3)
	return rows
