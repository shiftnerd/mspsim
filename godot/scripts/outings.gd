extends CanvasLayer
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Team outings: four little mini-games the crew goes out for, if you choose to go.
#   BOWLING (timing: aim, then power), KARAOKE (rhythm: arrow keys), ESCAPE ROOM (a 3-digit code, bulls and cows,
#   teammates give hints), DINNER (conversation: learn what each person likes).
# Tech campaign: on days 5, 10 and 15 Garrison (the culture owner) asks at 16:00 (open tickets wait; you go home after). Owner campaign:
# weeks 4, 9, 14 and 19, and it costs money. Free Play: press O. Results (0-3 stars) change coworker opinions, energy
# (tech) and burnout (owner); skipping invitations costs a little goodwill. Everything is drawn in code.

signal finished(game: String, stars: int)

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const INK := UiStyle.INK
const WHITE := UiStyle.WHITE
const PANEL := UiStyle.PANEL
const BLUE := UiStyle.HEAD
const GREEN := UiStyle.GREEN
const RED := UiStyle.RED
const AMBER := UiStyle.GOLD
const GAMES := {
	"bowling":
	{
		"label": "BOWLING",
		"cost": 120,
		"blurb":
		"FIVE FRAMES AGAINST ALAN, GARRISON AND DAN. PRESS SPACE TO STOP THE AIM, THEN AGAIN TO SET THE POWER.",
		"keys": "SPACE = STOP AIM / POWER  ESC = LEAVE"
	},
	"karaoke":
	{
		"label": "KARAOKE",
		"cost": 180,
		"blurb":
		"HIT THE ARROWS AS THEY REACH THE LINE. NERVOUS? THE ROOM IS RIGHT THERE WITH YOU.",
		"keys": "ARROW KEYS = HIT NOTES  ESC = LEAVE"
	},
	"escape":
	{
		"label": "ESCAPE ROOM",
		"cost": 240,
		"blurb":
		"CRACK THE 3 DIGIT CODE IN TWO MINUTES. BULLS = RIGHT DIGIT, RIGHT PLACE. COWS = RIGHT DIGIT, WRONG PLACE. FRIENDS GIVE HINTS.",
		"keys": "ARROWS  ENTER = TRY  H = HINT  ESC = LEAVE"
	},
	"dinner":
	{
		"label": "DINNER",
		"cost": 300,
		"blurb":
		"FIVE ROUNDS OF TABLE TALK. EVERYONE LOVES SOMETHING AND DREADS SOMETHING. WATCH THEIR FACES AND REMEMBER.",
		"keys": "UP / DOWN  ENTER = TALK  ESC = LEAVE"
	},
}
const DINERS := ["Alan", "Garrison", "Dan"]
# dinner: 18 topics with a tag (light, deep, touchy); the diners' tastes are in PEOPLE
const TOPICS := [
	{"id": "WORK DRAMA", "tag": "touchy"},
	{"id": "SPORTS", "tag": "light"},
	{"id": "MOVIES", "tag": "light"},
	{"id": "FOOD", "tag": "light"},
	{"id": "KIDS AND PETS", "tag": "deep"},
	{"id": "WEEKEND PLANS", "tag": "light"},
	{"id": "FANTASY FOOTBALL", "tag": "light"},
	{"id": "A NEW PHONE", "tag": "light"},
	{"id": "COMMUTE", "tag": "touchy"},
	{"id": "ROAD TRIP", "tag": "light"},
	{"id": "HOME BREWING", "tag": "light"},
	{"id": "A NEW BABY", "tag": "deep"},
	{"id": "GARDENS", "tag": "light"},
	{"id": "THE BIG GAME", "tag": "light"},
	{"id": "A TV SHOW BINGE", "tag": "light"},
	{"id": "KARAOKE", "tag": "light"},
	{"id": "RAISES AND BONUSES", "tag": "touchy"},
	{"id": "VENDOR STORIES", "tag": "light"},
	{"id": "BOSS GOSSIP", "tag": "touchy"},
	{"id": "MOVING HOUSE", "tag": "deep"},
]
# nobody ever dreads these (family is never a trap)
const PROTECTED_TOPICS := ["KIDS AND PETS", "A NEW BABY", "MOVING HOUSE"]
# loves (3) and dislikes (2); the first two loves and the first dislike are the classic tastes
# that old saves keep. A new save swaps one or two of them (see _roll_tastes).
const PEOPLE := {
	"Alan": {"loves": ["SPORTS", "FOOD", "HOME BREWING"], "hates": ["WORK DRAMA", "BOSS GOSSIP"]},
	"Garrison": {"loves": ["MOVIES", "WEEKEND PLANS", "KARAOKE"], "hates": ["SPORTS", "COMMUTE"]},
	"Dan":
	{"loves": ["KIDS AND PETS", "FOOD", "GARDENS"], "hates": ["MOVIES", "RAISES AND BONUSES"]},
	"Vic":
	{
		"loves": ["THE BIG GAME", "A NEW PHONE", "ROAD TRIP"],
		"hates": ["VENDOR STORIES"],
		"moods": ["chatty", "chatty", "relaxed", "distracted"],
	},
	"Maya":
	{
		"loves": ["A TV SHOW BINGE", "GARDENS", "KARAOKE"],
		"hates": ["COMMUTE"],
		"moods": ["relaxed", "easygoing", "chatty", "tired"],
	},
	"Morgan":
	{
		"loves": ["ROAD TRIP", "FANTASY FOOTBALL", "FOOD"],
		"hates": ["BOSS GOSSIP", "RAISES AND BONUSES"],
		"moods": ["tired", "easygoing", "easygoing", "distracted", "relaxed"],
	},
}
# the mood of the day shifts a diner's points for the whole dinner (+1 / 0 / -1)
const DINNER_MOODS := {
	"chatty": {"shift": 1, "face": ":D"},
	"relaxed": {"shift": 1, "face": ":)"},
	"easygoing": {"shift": 0, "face": ":|"},
	"tired": {"shift": -1, "face": "-_-"},
	"distracted": {"shift": -1, "face": "O_O"},
}
# owner campaign: who pays and how much (cost replaces the $300 of GAMES.dinner)
const BUDGETS := {
	"cheap": {"label": "CHEAP: PIZZA AND TAP WATER", "cost": 150, "mood": -1},
	"normal": {"label": "NORMAL: THE USUAL GRILL ORDER", "cost": 300, "mood": 0},
	"fancy": {"label": "FANCY: STEAKS AND A TOAST", "cost": 520, "mood": 1},
}
# bowling personalities (R5, B1): skill = how many pins the average roll takes, noise = how far a roll swings from it,
# streak = hot / cold swing on alternating frames (Garrison), turkey = chance of a strike on a frame (Dan is wild),
# show = bonus when there is an audience of three or more (Vic), gutter = chance of a gutter ball, late = frames sat out
# at the start (Morgan joins the game late). A person without a row does not bowl.
const BOWLERS := {
	"Alan": {"skill": 0.62, "noise": 0.15, "streak": 0.0, "turkey": 0.0, "show": 0.0, "gutter": 0.0, "late": 0},
	"Garrison": {"skill": 0.55, "noise": 0.2, "streak": 0.14, "turkey": 0.0, "show": 0.0, "gutter": 0.0, "late": 0},
	"Dan": {"skill": 0.48, "noise": 0.4, "streak": 0.0, "turkey": 0.1, "show": 0.0, "gutter": 0.06, "late": 0},
	"Vic": {"skill": 0.5, "noise": 0.24, "streak": 0.0, "turkey": 0.0, "show": 0.12, "gutter": 0.05, "late": 0},
	"Maya": {"skill": 0.6, "noise": 0.1, "streak": 0.0, "turkey": 0.0, "show": 0.0, "gutter": 0.0, "late": 0},
	"Morgan": {"skill": 0.66, "noise": 0.12, "streak": 0.0, "turkey": 0.0, "show": 0.0, "gutter": 0.0, "late": 1},
}
# dinner star bars by table size: 3 stars at neutral + a, 2 stars at neutral + b, 1 star at neutral - c (a table of
# three is the classic 22 / 15 / 10); tuned with tests/dinner_sim.gd so best play reaches 3 stars about half the time
const TABLE_BARS := {1: [3, 0, 3], 2: [6, 0, 4], 3: [7, 0, 5], 4: [9, 0, 6], 5: [11, 0, 7]}
const LANE_MAX := 4  # opponents on the scoreboard
const TABLE_MAX := 5  # faces at the table
# who comes along (R5): the classic trio is what a game started without an invitation uses (tests, the toolbox)
const CORE := ["Alan", "Garrison", "Dan"]
const SEATS := {
	"dinner":
	{"Alan": "Seat1", "Garrison": "Seat3", "Dan": "Seat4", "Vic": "Seat5", "Maya": "Seat6", "Morgan": "Seat7"}
}
const PLAYER_SEAT := "Seat2"
const LANE_NEAR := [152.0, 252.0]
const LANE_FAR := [160.0, 244.0]
const MIC_X := 238.0
const ROOM_INTRO := {
	"bowling":
	"TAKE YOUR TURN ON THE LANE. PRESS E TO STEP UP, E TO STOP THE AIM, E AGAIN FOR POWER. ALAN, GARRISON AND DAN BOWL ON THE NEXT LANE. FIVE FRAMES.",
	"karaoke":
	"YOU ARE ON THE MIC. PICK A SONG, THEN HIT THE ARROW KEYS AS THE NOTES REACH THE LINE (BOTTOM LEFT). PERFECT HITS WARM UP THE CROWD, MISSES COOL IT DOWN.",
	"escape":
	"THE CODE IS HIDDEN IN THE ROOM. LOOK AT THE CHALKBOARD, THE CLOCK, THE PAINTING AND THE TRUNK (E), THEN ENTER THE CODE AT THE KEYPAD BY THE VAULT. N ASKS A FRIEND. THE CLOCK IS RUNNING.",
	"dinner":
	"WALK TO THE BOOTH AND SIT DOWN (E). THEN CHOOSE FIVE TOPICS FOR THE TABLE. EVERYONE HAS A MOOD TODAY, SO WATCH THEIR FACES.",
}
const LANE_KEYS := [KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT]
const LANE_COLORS := [Color("e0463c"), Color("5fd068"), Color("5aa0e8"), Color("f5d442")]
# karaoke songs (invented titles and lyrics). gap = seconds between notes at the NORMAL tier (EASY and
# HARD scale it by Difficulty karaoke.gap); rhythm = gap multipliers cycled over the notes; pattern =
# how the lanes are picked (mix, sweep, sync, burst); doubles = chance of a second note on the same beat
# per tier [easy, normal, hard]; win = x the hit windows; cuts = share of the points for 1 / 2 / 3 stars
# ([3 stars, 2 stars, 1 star]); speed = pixels per second; unlock = stars
# you must have earned on any song first; lines = the lyrics screen (21 letters at most per line).
const DEFAULT_SONGS := [
	{
		"id": "wobble",
		"title": "WOBBLE WOBBLE POP",
		"artist": "DJ BEANBAG",
		"genre": "2013 POP",
		"len": 24,
		"gap": 0.75,
		"rhythm": [1.0],
		"pattern": "mix",
		"doubles": [0.0, 0.0, 0.0],
		"win": 1.0,
		"cuts": [0.75, 0.5, 0.25],
		"speed": 45.0,
		"unlock": 0,
		"lines":
		[
			"WOBBLE WOBBLE POP POP",
			"SHAKE IT FOR THE CAM",
			"BASS DROP IN MY HEAD",
			"SELFIE ON THE STAIRS",
			"NOBODY KNOWS MY MOVES",
			"ONE MORE DROP TONIGHT",
		],
	},
	{
		"id": "dirt",
		"title": "DIRT ROAD FRIDAY",
		"artist": "THE CREEKBED TWINS",
		"genre": "COUNTRY SINGALONG",
		"len": 20,
		"gap": 0.95,
		"rhythm": [1.0],
		"pattern": "sweep",
		"doubles": [0.0, 0.0, 0.1],
		"win": 1.1,
		"cuts": [0.7, 0.45, 0.2],
		"speed": 45.0,
		"unlock": 0,
		"lines":
		[
			"DIRT ROAD ON FRIDAY",
			"TAILGATE DOWN AND LOW",
			"PORCH LIGHT STILL ON",
			"HOME BY THE RIVER",
			"SING IT TO THE CORN",
			"NOBODY IS IN A RUSH",
			"ONE MORE MILE OF GOLD",
		],
	},
	{
		"id": "neon",
		"title": "NEON GYM CLASS",
		"artist": "THE SYNTH SCOUTS",
		"genre": "80S CLASSIC",
		"len": 26,
		"gap": 0.7,
		"rhythm": [1.2, 0.8, 1.2, 0.8],
		"pattern": "sync",
		"doubles": [0.0, 0.0, 0.12],
		"win": 1.0,
		"cuts": [0.7, 0.5, 0.3],
		"speed": 48.0,
		"unlock": 0,
		"lines":
		[
			"NEON LIGHTS AND SWEAT",
			"LEG WARMERS ON FIRE",
			"GYM CLASS AT MIDNIGHT",
			"ROLL THE TAPE BACK",
			"JUMP ROPE IN THE RAIN",
			"FEEL THE SYNTH GLOW",
			"NEON GYM CLASS, YEAH",
		],
	},
	{
		"id": "rap",
		"title": "FAST RAP HOT MESS",
		"artist": "MC SPREADSHEET",
		"genre": "FAST RAP",
		"len": 32,
		"gap": 0.62,
		"rhythm": [0.75, 0.75, 0.75, 1.5],
		"pattern": "burst",
		"doubles": [0.0, 0.12, 0.25],
		"win": 0.85,
		"cuts": [0.7, 0.45, 0.2],
		"speed": 55.0,
		"unlock": 3,
		"lines":
		[
			"FAST WORDS HOT MESS",
			"COFFEE ON MY SHIRT",
			"RHYMES IN THE QUEUE",
			"TICKET AFTER TICKET",
			"TWO TIMES TOO FAST",
			"BREATHE IN THE BRIDGE",
			"HOT MESS HOT MESS",
			"MIC DROP, MIC PICK UP",
		],
	},
]
var SONGS: Array = DEFAULT_SONGS.duplicate(true)
# the escape room: which clue recipes each zone can show (zone n holds digit n of the code)
const CLUE_ZONES := ["board", "clock", "plaque", "shelf"]
const CLUE_KINDS := ["clue_board", "clue_clock", "clue_painting", "clue_shelf"]
const RECIPES := {
	"board": ["sum", "product", "missing"],
	"clock": ["hour", "double"],
	"plaque": ["number", "roman", "letter"],
	"shelf": ["spine", "ribbons"],
}
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
const PRODUCTS := {4: [2, 2], 6: [2, 3], 8: [2, 4], 9: [3, 3]}
# what a friend says about each zone (the one in SPECIALTY gets the recipe tip as well)
const SPECIALTY := {"Alan": "board", "Dan": "clock", "Garrison": "keypad", "Maya": "plaque"}
const DEFAULT_RECIPE_TIPS := {
	"sum": "ADD THE TWO NUMBERS.",
	"product": "MULTIPLY THEM.",
	"missing": "WHICH DIGIT IS NOT IN THE LIST?",
	"hour": "THE HOUR IS THE DIGIT.",
	"double": "THE DIGIT IS TWICE THE HOUR.",
	"number": "THE NUMBER IS THE DIGIT.",
	"roman": "READ THE ROMAN NUMERAL.",
	"letter": "COUNT THE LETTER IN THE ALPHABET.",
	"spine": "THE VOLUME NUMBER IS THE DIGIT.",
	"ribbons": "COUNT THE BOOKMARK RIBBONS.",
	"dial": "THE DIAL CLICKS: B = RIGHT PLACE, C = WRONG PLACE.",
	"nodial": "THIS LOCK GIVES NOTHING AWAY. YOU NEED EVERY CLUE.",
}
var RECIPE_TIPS: Dictionary = DEFAULT_RECIPE_TIPS.duplicate(true)
const DEFAULT_FRIEND_HINTS := {
	"Alan":
	{
		"board": "THAT CHALKBOARD IS MY KIND OF PROBLEM. DO THE MATH.",
		"clock": "THAT OLD WALL CLOCK STOPPED FOR A REASON.",
		"plaque": "I THINK THERE IS A PLAQUE UNDER THE PAINTING.",
		"shelf": "ONE BOOK ON THAT SHELF IS STICKING OUT. LOOK CLOSER.",
		"keypad": "YOU HAVE THEM ALL. TRY THE KEYPAD ON THE VAULT.",
	},
	"Garrison":
	{
		"board": "SOMEBODY WROTE ON THAT CHALKBOARD. IT IS A CLUE, TRUST ME.",
		"clock": "THE CLOCK IS STUCK AT A STRANGE TIME. WE SHOULD LOOK.",
		"plaque": "A PLAQUE UNDER THE PAINTING! NOBODY HANGS A PAINTING FOR FREE.",
		"shelf": "THAT BOOKSHELF HAS SOMETHING IN IT THAT DOES NOT BELONG.",
		"keypad": "THAT IS ALL OF THEM. THE LOCK ON THE VAULT IS WAITING FOR YOU.",
	},
	"Dan":
	{
		"board": "THE CHALKBOARD LIGHT IS WIRED BADLY. LOOK AT THE BOARD.",
		"clock": "THAT CLOCK IS NOT WIRED TO ANYTHING, SO SOMEONE STOPPED IT ON PURPOSE.",
		"plaque": "THERE IS A CABLE RUN UNDER THE PAINTING. AND A PLAQUE.",
		"shelf": "THE BOOKSHELF IS BOLTED TO THE WALL. SOMETHING ON IT IS NOT A BOOK.",
		"keypad": "THE KEYPAD IS WIRED TO THE VAULT. ENTER WHAT YOU FOUND.",
	},
	"Maya":
	{
		"board": "THE CHALKBOARD LOOKS LIKE HOMEWORK. HOMEWORK IS A CLUE.",
		"clock": "THE WALL CLOCK IS WRONG. NOBODY LEAVES A CLOCK WRONG.",
		"plaque": "THAT PLAQUE UNDER THE PAINTING IS EASY TO MISS. READ IT.",
		"shelf": "THE BOOKSHELF HAS A LABEL ON IT. GO AND READ IT.",
		"keypad": "THAT IS EVERYTHING. GO ENTER IT AT THE VAULT.",
	},
	"Vic":
	{
		"board": "I HAVE A GUY FOR THIS. UNTIL HE CALLS, TRUST ME ON THE CHALKBOARD.",
		"clock": "I HAVE A GUY AT A CLOCK COMPANY. UNTIL THEN, LOOK AT THE CLOCK.",
		"plaque": "I SAW SOMETHING UNDER THE PAINTING. A PLAQUE, MAYBE.",
		"shelf": "THE BOOKSHELF IS A GREAT CLOSER. LOOK AT IT.",
		"keypad": "YOU HAVE IT ALL. CLOSE THE DEAL AT THE KEYPAD.",
	},
	"Morgan":
	{
		"board": "THERE IS MATH ON THE BOARD. I WILL LET YOU HAVE THAT ONE.",
		"clock": "THE CLOCK IS STOPPED. THAT IS NOT A METAPHOR. LOOK AT IT.",
		"plaque": "UNDER THE PAINTING. SOMEONE PUT A PLAQUE THERE ON PURPOSE.",
		"shelf": "THE SHELF IS DOING MORE WORK THAN IT LOOKS. READ IT.",
		"keypad": "YOU HAVE EVERYTHING. THE KEYPAD IS ON THE VAULT. GO.",
	},
}
var FRIEND_HINTS: Dictionary = DEFAULT_FRIEND_HINTS.duplicate(true)
const DEFAULT_HERRINGS := [
	"A BOOKSHELF FULL OF OLD MANUALS. NO NUMBERS HERE THAT MATTER.",
	"A DUSTY SHELF. THE LABEL SAYS: NOT THE CODE.",
	"ODD BOOKS AND A FOLDED FLAG. NOTHING USEFUL.",
]
var HERRINGS: Array = DEFAULT_HERRINGS.duplicate(true)
const DEFAULT_GUESTS := {
	"Alan": {"comes": 0.9, "code": "AL", "line": "Alan has a thing tonight."},
	"Garrison": {"comes": 0.9, "code": "GA", "line": "Garrison is sitting this one out."},
	"Dan": {"comes": 0.8, "code": "DA", "line": "Dan has a thing tonight."},
	"Vic": {"comes": 0.65, "code": "VI", "line": "Vic is on a call with a client."},
	"Maya": {"comes": 0.7, "code": "MA", "line": "Maya has plans tonight."},
	"Morgan": {"comes": 0.25, "code": "MO", "line": "Morgan is staying behind to catch up."},
}
var GUESTS: Dictionary = DEFAULT_GUESTS.duplicate(true)
const DEFAULT_CREW_LINES := {
	"Alan":
	{
		"cheer": ["NICE ROLL. STEADY.", "THAT IS HOW IT IS DONE."],
		"groan": ["IT HAPPENS. ROLL AGAIN.", "THE LANE IS SLICK TONIGHT."],
		"talk": ["I WILL TAKE THE SPARE.", "SLOW AND STEADY."],
		"sing": ["HA! KEEP GOING!", "THAT IS A REAL VOICE."],
	},
	"Garrison":
	{
		"cheer": ["YES! DID YOU SEE THAT?", "THIS IS THE BEST NIGHT."],
		"groan": ["OH NO. OH NO NO.", "I BLAME THE SHOES."],
		"talk": ["I AM ON FIRE. OR NOT.", "THE NEXT ONE IS MINE."],
		"sing": ["WOO! SING IT!", "ENCORE! ENCORE!"],
	},
	"Dan":
	{
		"cheer": ["THAT PIN HAD IT COMING.", "WHOA. DID I DO THAT?"],
		"groan": ["THE BALL HAS A MIND OF ITS OWN.", "THAT WAS A BAD CABLE RUN."],
		"talk": ["WATCH THIS ONE.", "I MIGHT GET A TURKEY."],
		"sing": ["NOT BAD AT ALL.", "I WOULD NOT TRY THAT."],
	},
	"Vic":
	{
		"cheer": ["I TOLD YOU. I TOLD EVERYONE.", "THAT IS A WINNING ROLL."],
		"groan": ["THE PINS WERE LOOSE.", "THAT DOES NOT COUNT, RIGHT?"],
		"talk": ["WATCH AND LEARN.", "I HAVE A GUY AT THIS ALLEY."],
		"sing": ["I KNEW YOU HAD IT!", "I HAVE A GUY FOR RECORDING."],
	},
	"Maya":
	{
		"cheer": ["CLEAN HIT.", "RIGHT ON THE HEAD PIN."],
		"groan": ["ONE PIN. REALLY.", "I WAS A BIT LEFT."],
		"talk": ["I HAVE A PLAN FOR THIS ONE.", "AIM, THEN BREATHE."],
		"sing": ["THAT NOTE WAS PERFECT.", "OK, THAT WAS GOOD."],
	},
	"Morgan":
	{
		"cheer": ["NOT BAD. DO NOT TELL HR.", "ACCEPTABLE."],
		"groan": ["WELL. THAT HAPPENED.", "I AM ONLY HERE FOR THE SHOES."],
		"talk": ["I DO NOT BOWL. I JUST WIN.", "ONE FRAME BEHIND IS FINE."],
		"sing": ["THAT WAS FINE. GOOD, EVEN.", "I WILL ALLOW IT."],
	},
}
var CREW_LINES: Dictionary = DEFAULT_CREW_LINES.duplicate(true)
const ROOMS := {
	"bowling": "bowling_alley",
	"karaoke": "karaoke_bar",
	"escape": "escape_room",
	"dinner": "restaurant"
}
# where Alan, Garrison, Dan, Vic, Maya and Morgan stand in each room (set-pixel x, World.CAST order: a person who is
# not there leaves their spot empty). The five standing spots are unchanged; the sixth is Morgan's.
const SPOTS := {
	"bowling": [114, 186, 214, 250, 140, 165],
	"karaoke": [236, 262, 282, 130, 160, 100],
	"escape": [118, 175, 205, 305, 325, 14],  # clear of the clue zones (shelf 52, clock 86, painting 149, board 238, keypad 276)
	"dinner": [34, 62, 106, 140, 175, 205],
}
const TECH_DAYS := [5, 10, 15]
const OWNER_WEEKS := [4, 9, 14, 19]

var enabled := false
var use_rooms := false  # go to the real room (title menu turns this on)
var is_open := false
var game := ""
var phase := "intro"  # intro, play, result
var g := {}
var opts := {}  # Free Play toolbox parameters of this game: song, digits, recipes, table, panel (empty = as usual)
var stars := 0
var lines: Array = []  # the result page
var count := 0
var skipped := 0
var best := {}
var known := {}  # dinner: who likes / dreads what, learned over time
var tastes := {}  # dinner: the real tastes of this save, {who: {loves, hates}} (rolled on first use)
var song_best := {}  # karaoke: best stars per song id
var party: Array = []  # who was invited tonight, in priority order (draw_party)
var stayed: Array = []  # roster members who did not come
var party_set := false

var _canvas: Node2D
var _prev_scale := 1.0
var _from_invite := false
var _peek := false  # TAB hides the panel so you can look at the room
var _wait_id := ""  # travelling to the room
var _traveled := false
var _return_scene := ""
var _return_x := -1.0
var _caption := ""
var _caption_t := 0.0
var _marks := {}  # speech bubbles to hide: node -> seconds left
var _offered := false


func _ready() -> void:
	layer = 66
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	Campaign.day_started.connect(func(_d: int) -> void: _offered = false)
	reset()


func reset() -> void:
	count = 0
	skipped = 0
	best = {}
	known = {}
	tastes = {}
	song_best = {}
	_offered = false


# version 2 saves the dinner tastes and the best star count per song; an older save has neither
# (it keeps the classic tastes, so what it already knows stays true)
func to_dict() -> Dictionary:
	for who in PEOPLE:
		taste(who)
	return {
		"version": 2,
		"count": count,
		"skipped": skipped,
		"best": best,
		"known": known,
		"tastes": tastes,
		"songs": song_best,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	count = int(data.get("count", 0))
	skipped = int(data.get("skipped", 0))
	best = data.get("best", {})
	known = data.get("known", {})
	song_best = data.get("songs", {})
	if int(data.get("version", 1)) >= 2:
		tastes = data.get("tastes", {})
	else:
		for who in PEOPLE:
			tastes[who] = classic_taste(who)


# ---- invitations ------------------------------------------------------------------------------
# a game is open, or we are on the way to its room
func busy() -> bool:
	return is_open or _wait_id != ""


func invite_day() -> bool:
	if not Campaign.active:
		return false
	if Campaign.mode == "owner":
		return OWNER_WEEKS.has(Campaign.day)
	if Campaign.mode == "sales":
		return SalesCampaign.outing_kind() != ""  # a team night or a dinner with a prospect (sales_campaign.gd)
	return TECH_DAYS.has(Campaign.day)


# the day waits for the invitation (a trip may have brought you home after five)
func invite_due() -> bool:
	return enabled and not _offered and invite_day() and not Story.overtime and not Game.title_mode


# who is in the building for an outing: the current cast (World.CAST order) minus the person you play as
func roster() -> Array:
	var out := []
	for n in World.CAST:
		if World.chars.has(n) and n != Campaign.player_as:
			out.append(n)
	return out


# ---- who comes along (R5) ---------------------------------------------------------------------
# Not everybody comes every time. The invitation draws a party from the roster (draw_party: a seeded roll per
# person, friends more likely, the cold ones decline, at least two come); the games get it as options.party.
# A game started without a party (tests, the toolbox) keeps the classic trio at the table and on the lanes.
func draw_party() -> Array:
	var here := roster()
	var r := Difficulty.rng("outings")
	var ranked := []
	var away := []
	for n in here:
		var row: Dictionary = GUESTS.get(n, {"comes": 0.8})
		var p := float(row.comes)
		if Social.is_hostile(n):
			p = 0.05
		elif Social.is_cold(n):
			p = minf(p, 0.3)
		elif Social.is_friendly(n):
			p = minf(0.97, p + 0.1)
		var roll := r.randf()
		var tie := r.randf()  # two draws per person whatever happens, so one seed keeps one stream
		if roll < p:
			ranked.append({"n": n, "key": (1.0 if Social.is_friendly(n) else 0.0) + tie})
		else:
			away.append(n)
	while ranked.size() < mini(2, here.size()) and not away.is_empty():
		var best := 0
		for i in away.size():
			if float(GUESTS.get(away[i], {"comes": 0.0}).comes) > float(GUESTS.get(away[best], {"comes": 0.0}).comes):
				best = i
		ranked.append({"n": away[best], "key": 0.0})
		away.remove_at(best)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.key) > float(b.key))
	party = ranked.map(func(e: Dictionary) -> String: return str(e.n))
	stayed = away
	party_set = true
	return party


# "Coming: Alan, Dan and Vic. Garrison is sitting this one out." (the invitation card)
func coming_text() -> String:
	if not party_set:
		draw_party()
	var text := "Coming: %s." % join_names(_by_cast(party), false)
	if not stayed.is_empty():
		text += " " + str(GUESTS.get(stayed[0], {}).get("line", "%s cannot make it." % stayed[0]))
	return text


func join_names(list: Array, caps: bool) -> String:
	var names := list.map(func(n: String) -> String: return n.to_upper() if caps else n)
	if names.size() <= 1:
		return "".join(names)
	return "%s %s %s" % [", ".join(names.slice(0, names.size() - 1)), "AND" if caps else "and", names[names.size() - 1]]


func _by_cast(list: Array) -> Array:
	return World.CAST.keys().filter(func(n: String) -> bool: return list.has(n))


# everybody who is out tonight (this game's party, or the whole roster when the game had no invitation)
func present() -> Array:
	var here := roster()
	if opts.has("party"):
		return opts.party.filter(func(n: String) -> bool: return here.has(n))
	return here


# the people the games have a personality for: the party, or the classic trio when there was no invitation
func crew() -> Array:
	if opts.has("party"):
		return present()
	var here := roster()
	return CORE.filter(func(n: String) -> bool: return here.has(n))


# up to five faces at the table (the toolbox can narrow it to some of them)
func diners() -> Array:
	var table: Array = opts.get("table", [])
	var seated := crew().filter(
		func(n: String) -> bool: return PEOPLE.has(n) and (table.is_empty() or table.has(n))
	)
	return _by_cast(seated.slice(0, TABLE_MAX))


# up to four opponents on the lanes (the party is in priority order: friends first)
func bowlers() -> Array:
	return _by_cast(crew().filter(func(n: String) -> bool: return BOWLERS.has(n)).slice(0, LANE_MAX))


# the karaoke audience: the party, or (no invitation) the table plus Vic as before
func crowd() -> Array:
	if opts.has("party"):
		return present()
	var out := diners()
	if roster().has("Vic"):
		out.append("Vic")
	return out


# a line in somebody's voice: kind = cheer, groan, talk or sing ("" when they have none)
func crew_line(who: String, kind: String) -> String:
	var row: Dictionary = CREW_LINES.get(who, {})
	var list: Array = row.get(kind, [])
	return "" if list.is_empty() else str(list[randi() % list.size()])


func maybe_invite() -> void:
	if not enabled or _offered or is_open or Cards.is_open or Game.title_mode or not invite_day():
		return
	if World.time_scale <= 0.0 or World.clock < 16.0 or Story.overtime:
		return
	_offered = true
	party_set = false
	draw_party()
	var text := "The crew is heading out after work and I would like you there. Come with us? The open tickets will still be here in the morning."
	if Campaign.mode == "owner":
		text = (
			"The crew has been grinding for weeks. A team night would be noticed. It costs %s depending on the game."
			% cost_range()
		)
	if Campaign.mode == "sales":
		text = SalesCampaign.outing_text()
	text += " " + coming_text()
	Cards.ask(
		_host(),
		text,
		[
			{"label": "YES, LET US GO", "id": "yes"},
			{"label": "NOT TONIGHT", "id": "no"},
		],
		func(id: String) -> void: _invite_answer(id)
	)


# the owner pays for the night: "$120 TO $300" (shown on the invitation before the game pick)
func cost_range() -> String:
	var lo := 100000
	var hi := 0
	for id in GAMES:
		lo = mini(lo, int(GAMES[id].cost))
		hi = maxi(hi, int(GAMES[id].cost))
	# X9: the owner's dinner can be the fancy one when it is played in the restaurant
	if Campaign.mode == "owner" and use_rooms:
		hi = maxi(hi, int(BUDGETS.fancy.cost))
	return "$%d to $%d" % [lo, hi]


# who asks: Garrison (culture owner) in the tech campaign; in the owner campaign the card comes from Alan
func _host() -> String:
	return "Alan (Co-owner)" if Campaign.mode == "owner" else "Garrison (Co-owner)"


func _invite_answer(id: String) -> void:
	if id == "yes":
		if Campaign.mode == "sales" and SalesCampaign.outing_kind() == "client":
			start("dinner", true, {"party": party.duplicate()})  # the client dinner: the restaurant, a prospect at the table
			return
		pick_game(true)
		return
	skipped += 1
	if Campaign.mode == "owner":
		Owner.burnout = clampf(Owner.burnout + 2.0, 0.0, 100.0)
	else:
		Social.change_all(-1)


func pick_game(from_invite: bool) -> void:
	if not party_set:
		draw_party()
	var options := []
	for id in GAMES:
		var cost := int(GAMES[id].cost)
		var entry := {
			"label":
			"%s%s" % [str(GAMES[id].label), " ($%d)" % cost if Campaign.mode == "owner" else ""],
			"id": id
		}
		if Campaign.mode == "owner" and Owner.cash < cost:
			entry["enabled"] = false
			entry["hint"] = "NEED $%d" % cost
		options.append(entry)
	Cards.ask(
		_host(),
		"Where to? Bowling is easy, karaoke is risky, the escape room needs teamwork and dinner needs good conversation.",
		options,
		func(id: String) -> void: start(id, from_invite, {"party": party.duplicate()})
	)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or is_open or Campaign.active or Game.title_mode or Game.ui_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		party_set = false
		draw_party()
		Cards.ask(
			"Team outing",
			"Take the team out? (Free Play: nothing is scored.) " + coming_text(),
			[
				{"label": "LET US GO", "id": "yes"},
				{"label": "NEVER MIND", "id": "no"},
			],
			func(id: String) -> void: _free_answer(id)
		)


func _free_answer(id: String) -> void:
	if id == "yes":
		pick_game(false)


# ---- running an outing ------------------------------------------------------------------------
# options (Free Play toolbox, all optional): "song" = a SONGS id (any, locked or not, no card at the mic),
# "digits" 3 or 4 = the escape code length, "recipes" = {zone: recipe} fixed clue recipes (a digit that fits is
# dealt), "table" = the dinner guests, "panel" = the overlay version instead of the room. Without options every
# draw comes from the run's streams (Difficulty.rng) as before.
func start(id: String, from_invite := false, options := {}) -> void:
	opts = options.duplicate()
	if Difficulty.fixed_take:
		Difficulty.take_reset()
	var here := get_tree().current_scene
	var in_room := use_rooms and not bool(opts.get("panel", false))
	if in_room and ROOMS.has(id) and here != null and not Game.title_mode:
		_return_scene = here.scene_file_path.get_file().get_basename()
		var me := here.get_node_or_null("Actors/Player")
		_return_x = me.global_position.x if me != null else -1.0
		_traveled = true
		_wait_id = id
		_from_invite = from_invite
		var away := []
		if opts.has("party"):  # whoever did not come stays out of the building
			away = roster().filter(func(n: String) -> bool: return not opts.party.has(n))
		World.start_outing(str(ROOMS[id]), SPOTS[id], SEATS.get(id, {}), away)
		Game.go(str(ROOMS[id]), "from_outing")
		return
	_traveled = false
	_open(id, from_invite)


func _open(id: String, from_invite: bool) -> void:
	game = id
	_from_invite = from_invite
	phase = "intro"
	stars = 0
	g = {}
	lines = []
	_prev_scale = World.time_scale if World.time_scale > 0.0 else 1.0
	World.time_scale = 0.0
	is_open = true
	Game.ui_open = true
	_canvas.visible = true
	if Campaign.mode == "owner":
		Owner.cash -= int(GAMES[id].cost)
	_canvas.queue_redraw()


func begin_play(pick := "") -> void:
	phase = "play"
	match game:
		"bowling":
			_bowl_setup()
		"karaoke":
			_kara_setup(pick)
		"escape":
			_escape_setup()
			if room_mode():
				_escape_room_setup()
		_:
			_dinner_setup()
	if room_mode():
		_room_begin()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_canvas.visible = false
	Game.ui_open = false
	World.time_scale = _prev_scale
	if _from_invite and Campaign.active:
		World.clock = maxf(World.clock, World.DAY_END)
		Shift.skip_stay()
	elif _traveled:
		World.end_outing()
		Game.pending_x = _return_x
		Game.go(_return_scene, "start")
	_traveled = false
	_peek = false
	finished.emit(game, stars)


func _process(delta: float) -> void:
	if _wait_id != "":
		var here := get_tree().current_scene
		if (
			not Game.busy
			and here != null
			and here.scene_file_path.get_file().get_basename() == str(ROOMS[_wait_id])
		):
			var id := _wait_id
			_wait_id = ""
			_open(id, _from_invite)
		return
	if is_open:
		if phase == "play":
			tick(delta)
		_room_process(delta)
		_canvas.queue_redraw()
		return
	maybe_invite()


func tick(dt: float) -> void:
	if phase != "play":
		return
	match game:
		"bowling":
			_bowl_tick(dt)
		"karaoke":
			_kara_tick(dt)
		"escape":
			_escape_tick(dt)
		_:
			_dinner_tick(dt)


func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if Cards.is_open:
		return  # a card (song, budget) has the keys
	if room_mode() and phase == "play" and not _room_wants(event.keycode):
		return  # in the room you keep walking around
	press(event.keycode)
	get_viewport().set_input_as_handled()


func press(key: int) -> void:
	if not is_open:
		return
	if key == KEY_TAB and _traveled:
		_peek = not _peek
		_canvas.queue_redraw()
	elif phase == "intro" or phase == "result":
		_press_page(key)
	elif key == KEY_ESCAPE:
		_escape_or_leave()
	elif not (room_mode() and _room_press(key)):
		_press_game(key)


func _press_page(key: int) -> void:
	if phase == "result":
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			close()
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if Cards.is_open:
			return
		if use_rooms and game == "karaoke" and not opts.has("song"):
			ask_song()  # the card at the mic picks the song, then the game begins
		elif use_rooms and game == "dinner" and Campaign.mode == "owner":
			ask_budget()
		else:
			begin_play()
	elif key == KEY_ESCAPE:
		if Campaign.mode == "owner":
			Owner.cash += int(GAMES[game].cost)
		_finish(-1)


func _escape_or_leave() -> void:
	if game == "escape" and g.get("entry", false):
		g.entry = false
		Game.ui_open = false
	else:
		_finish(-1)


func _press_game(key: int) -> void:
	match game:
		"bowling":
			_bowl_press(key)
		"karaoke":
			_kara_press(key)
		"escape":
			_escape_press(key)
		_:
			_dinner_press(key)


# stars: 0-3, or -1 when you left early
func _finish(result: int) -> void:
	stars = result
	phase = "result"
	lines = []
	if result < 0:
		lines.append("YOU LEFT EARLY. NOBODY SAYS ANYTHING. EVERYBODY NOTICES.")
		Social.change_all(-1)
	else:
		count += 1
		best[game] = maxi(int(best.get(game, 0)), result)
		Career.note_outing(
			game,
			result,
			{
				"perfects": int(g.get("perfect", 0)),
				"secs": roundi(Difficulty.f("escape.time") - float(g.get("time", 0.0))),
				"score": int(g.get("score", 0))
			}
		)
		Social.change_all(1 + result)
		if Campaign.mode == "sales":
			lines.append_array(SalesCampaign.outing_done(game, result))
		if Campaign.active:
			lines.append("EVERYONE ON THE TEAM LIKES YOU %d MORE." % (1 + result))
		else:
			lines.append("A GOOD NIGHT OUT. (FREE PLAY: NOTHING IS SCORED.)")
		if Campaign.mode == "owner":
			var relief := 5.0 + 3.0 * float(result)
			Owner.burnout = clampf(Owner.burnout - relief, 0.0, 100.0)
			Owner.flags["outings"] = int(Owner.flags.get("outings", 0)) + 1
			lines.append("BURNOUT DOWN %d POINTS. THE CREW FEELS SEEN." % int(relief))
			if game == "escape" and result >= 2:
				Owner.speed += 0.02
				lines.append("THEY WORK BETTER TOGETHER NOW: TEAM SPEED UP.")
		elif Campaign.active and Campaign.mode != "sales":
			var gain := 4.0 + 2.0 * float(result)
			Shift.add_energy(gain)
			lines.append("ENERGY +%d. A NIGHT OUT HELPS." % int(gain))
		if result >= 3:
			Campaign.adjust_rep(1)
			if Campaign.active:
				lines.append("WORD GETS AROUND ABOUT THIS ONE: REPUTATION +1.")
	if room_mode():
		_release_player()
		Game.ui_open = true
		_caption_t = 0.0
	_canvas.queue_redraw()


# ---- bowling ------------------------------------------------------------------------------------
func _all_up() -> Array:
	return [true, true, true, true, true, true, true, true, true, true]


func _bowl_totals() -> Dictionary:
	var totals := {"You": 0}
	for who in bowlers():
		totals[who] = 0
	return totals


func _bowl_setup() -> void:
	g = {
		"frame": 1,
		"roll": 1,
		"pins": 10,
		"stage": "aim",
		"marker": 0.0,
		"power": 0.0,
		"dir": 1.0,
		"wait": 0.0,
		"ball": 0.0,
		"msg": "",
		"totals": _bowl_totals(),
		"knocked": 0,
		"up": [_all_up(), _all_up()],
		"fall": {},
		"queue": [],
		"opp": "",
		"opp_t": 0.0,
		"opp_ball": 0.0,
		"opp_off": 0.5,
		"opp_total": 0,
		"opp_knock": 0,
		"opp_first": 0,
		"opp_phase": 0,
	}
	if room_mode():
		g.stage = "ready"
		caption("YOUR TURN. PRESS E TO STEP UP.", 99.0)


func _bowl_tick(dt: float) -> void:
	for key in g.fall.keys():
		g.fall[key] = float(g.fall[key]) - dt
		if float(g.fall[key]) <= 0.0:
			g.fall.erase(key)
	var stage: String = g.stage
	if stage == "aim" or stage == "power":
		var key := "marker" if stage == "aim" else "power"
		var speed := Difficulty.f("bowl.aim_speed" if stage == "aim" else "bowl.power_speed")
		var v: float = float(g[key]) + float(g.dir) * dt * speed
		if v >= 1.0:
			v = 1.0
			g.dir = -1.0
		elif v <= 0.0:
			v = 0.0
			g.dir = 1.0
		g[key] = v
	elif stage == "roll":
		g.ball = minf(1.0, float(g.ball) + dt * 1.6)
		if float(g.ball) >= 1.0:
			_bowl_resolve()
	elif stage == "pause":
		g.wait = float(g.wait) - dt
		if float(g.wait) <= 0.0:
			_bowl_next()
	elif stage == "others":
		_bowl_others(dt)


func _bowl_press(key: int) -> void:
	if key not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
		return
	if room_mode() and g.stage not in ["ready", "aim", "power"]:
		caption("WAIT. E DOES NOTHING UNTIL IT IS YOUR TURN.", 1.5)
		return
	if g.stage == "ready":
		_place_player(_x0() + float(LANE_NEAR[0]))
		_hold_player("idle")
		g.stage = "aim"
		g.marker = 0.0
		g.dir = 1.0
		caption("PRESS E TO STOP THE AIM (STOP IN THE GREEN).", 99.0)
	elif g.stage == "aim":
		g.stage = "power"
		g.power = 0.0
		g.dir = 1.0
		caption("PRESS E TO STOP THE POWER (STOP IN THE GREEN).", 99.0)
	elif g.stage == "power":
		g.stage = "roll"
		g.ball = 0.0
		caption("WAIT. THE BALL IS ROLLING.", 3.0)
		var p := _actor("Player")
		if p != null:
			p.start_emote("reach", 0.8)


func bowl_strength() -> float:
	var accuracy := 1.0 - absf(float(g.marker) - 0.5) * 2.0
	var quality := clampf(1.0 - absf(float(g.power) - 0.85) / 0.85, 0.0, 1.0)
	var noise := Difficulty.rng("bowl").randf_range(-0.08, 0.08)
	return clampf(accuracy * 0.6 + quality * 0.4 + noise, 0.0, 1.0)


func _bowl_resolve() -> void:
	var strength := bowl_strength()
	var left := int(g.pins)
	var knocked := (
		left
		if strength > 0.92
		else clampi(roundi(float(left) * minf(1.0, strength * 1.15)), 0, left)
	)
	g.knocked = knocked
	g.pins = left - knocked
	g.totals["You"] = int(g.totals["You"]) + knocked
	Career.note_bowl(knocked, int(g.roll))
	if knocked == 10 and int(g.roll) == 1:
		g.totals["You"] = int(g.totals["You"]) + 3
		g.msg = "STRIKE!"
	elif int(g.pins) == 0:
		g.msg = "SPARE!"
	elif knocked == 0:
		g.msg = "GUTTER BALL..."
	else:
		g.msg = "%d PINS" % knocked
	g.stage = "pause"
	g.wait = 1.4 if room_mode() else 1.1
	if room_mode():
		_pins_fall(0, knocked)
		_bubble(_actor("Player"), "!" if knocked >= 8 else ("?" if knocked == 0 else "dots"), 1.2)
		for who in bowlers():
			if knocked >= 10:
				_bubble(_actor(who), "heart", 1.2)
		_crew_reacts(knocked)


# one frame of a crew member, from their BOWLERS row: skill and noise, a hot / cold swing on alternating frames,
# a show-off bonus with an audience (3+ opponents, or you just hit 8+), a turkey or a gutter ball now and then
func _bowl_roll_opp(who: String) -> Dictionary:
	var row: Dictionary = BOWLERS[who]
	var skill := float(row.skill) + Difficulty.f("bowl.opp_skill")
	var r := Difficulty.rng("bowl")
	if float(row.streak) > 0.0:
		skill += float(row.streak) * (1.0 if int(g.get("frame", 1)) % 2 == 0 else -1.0)
	if float(row.show) > 0.0 and (bowlers().size() >= 3 or int(g.get("knocked", 0)) >= 8):
		skill += float(row.show)
	var noise := float(row.noise)
	var first := clampi(roundi(10.0 * (skill + r.randf_range(-noise, noise))), 0, 10)
	if float(row.turkey) > 0.0 and r.randf() < float(row.turkey):
		first = 10
	if float(row.gutter) > 0.0 and r.randf() < float(row.gutter):
		first = 0
	var total := first
	var knock := first
	if first == 10:
		total += 3
	else:
		var second := clampi(
			roundi(float(10 - first) * (skill + r.randf_range(-noise, noise))), 0, 10 - first
		)
		total += second
		knock += second
	return {"total": total, "knock": knock, "first": first}


# Morgan sits out the first frame (BOWLERS.late) and joins in after
func bowls_in_frame(who: String, frame: int) -> bool:
	return frame > int(BOWLERS[who].late)


# somebody on the bench says something in their own voice (a caption, never a penalty)
func _crew_reacts(knocked: int) -> void:
	var kind := "cheer" if knocked >= 8 else ("groan" if knocked <= 1 else "")
	if kind == "" or randf() > 0.6:
		return
	var who: String = bowlers().pick_random() if not bowlers().is_empty() else ""
	if who == "":
		return
	var line := crew_line(who, kind)
	if line != "":
		caption("%s: %s" % [who.to_upper(), line], 2.2)


func _bowl_next() -> void:
	var frame_over: bool = int(g.roll) == 2 or int(g.pins) == 0
	if not frame_over:
		g.roll = 2
		g.stage = "aim"
		g.marker = 0.0
		g.dir = 1.0
		if room_mode():
			caption("SECOND ROLL. PRESS E TO STOP THE AIM.", 99.0)
		return
	var frame := int(g.frame)
	var turn := bowlers().filter(func(n: String) -> bool: return bowls_in_frame(n, frame))
	if room_mode():
		g.queue = turn
		g.opp = ""
		g.stage = "others"
		caption("WAIT. THE CREW BOWLS NEXT.", 2.0)
		return
	for who in turn:
		g.totals[who] = int(g.totals[who]) + int(_bowl_roll_opp(who).total)
	_bowl_advance()


func _bowl_advance() -> void:
	if int(g.frame) >= 5:
		_bowl_end()
		return
	g.frame = int(g.frame) + 1
	g.roll = 1
	g.pins = 10
	g.stage = "ready" if room_mode() else "aim"
	g.marker = 0.0
	g.dir = 1.0
	g.msg = ""
	g.up = [_all_up(), _all_up()]
	if room_mode():
		caption("FRAME %d. YOUR TURN: PRESS E TO STEP UP." % int(g.frame), 99.0)


# the crew takes its turn on the next lane, one at a time
func _bowl_others(dt: float) -> void:
	g.opp_t = float(g.opp_t) + dt
	if str(g.opp) == "":
		if g.queue.is_empty():
			_bowl_advance()
			return
		g.opp = str(g.queue.pop_front())
		var res := _bowl_roll_opp(str(g.opp))
		g.opp_total = int(res.total)
		g.opp_knock = int(res.knock)
		g.opp_first = int(res.first)
		var wobble := Difficulty.rng("bowl").randf_range(-0.5, 0.5)
		g.opp_off = clampf(0.5 + (1.0 - float(res.knock) / 10.0) * wobble, 0.0, 1.0)
		g.opp_ball = 0.0
		g.opp_t = 0.0
		g.opp_phase = 0
		g.up[1] = _all_up()
		if int(BOWLERS[str(g.opp)].late) > 0 and int(g.frame) == int(BOWLERS[str(g.opp)].late) + 1:
			caption("%s JOINS THE GAME. RELUCTANTLY." % str(g.opp).to_upper(), 1.5)
		else:
			caption("WAIT. %s STEPS UP." % str(g.opp).to_upper(), 1.5)
		return
	if int(g.opp_phase) == 0:
		g.opp_ball = minf(1.0, float(g.opp_t) / 0.6)
		if float(g.opp_t) >= 0.6:
			g.opp_phase = 1
			_pins_fall(1, int(g.opp_knock))
			_bubble(_actor(str(g.opp)), "!" if int(g.opp_knock) >= 8 else "dots", 1.2)
			var kind := "cheer" if int(g.opp_first) == 10 else ("groan" if int(g.opp_knock) <= 2 else "talk")
			var line := crew_line(str(g.opp), kind) if kind != "talk" or randf() < 0.5 else ""
			if line != "":
				caption("%s (%d): %s" % [str(g.opp).to_upper(), int(g.opp_knock), line], 2.0)
			else:
				caption("%s KNOCKS DOWN %d" % [str(g.opp).to_upper(), int(g.opp_knock)], 1.5)
	elif float(g.opp_t) >= 1.7:
		g.totals[g.opp] = int(g.totals[g.opp]) + int(g.opp_total)
		g.opp = ""
		g.opp_ball = 0.0


func _pins_fall(lane: int, count: int) -> void:
	var up: Array = g.up[lane]
	var standing := []
	for i in 10:
		if up[i]:
			standing.append(i)
	Difficulty.shuffle(standing, "bowl")
	for i in mini(count, standing.size()):
		up[standing[i]] = false
		g.fall["%d_%d" % [lane, standing[i]]] = 0.8


func bowl_rank() -> int:
	var rank := 0
	for who in bowlers():
		if int(g.totals[who]) > int(g.totals["You"]):
			rank += 1
	return rank


func _bowl_end() -> void:
	_finish([3, 2, 1, 1, 1][mini(bowl_rank(), 4)])


# ---- the song table
func song_by_id(id: String) -> Dictionary:
	for song in SONGS:
		if str(song.id) == id:
			return song
	return SONGS[0]


# a song is open when you have earned its stars on any song (the rap needs a 3 star night)
func song_unlocked(id: String) -> bool:
	var need := int(song_by_id(id).get("unlock", 0))
	if need <= 0:
		return true
	for key in song_best:
		if int(song_best[key]) >= need:
			return true
	return int(best.get("karaoke", 0)) >= need


# the song the card offers first: in a campaign the first open one you have not three-starred yet
func default_song() -> String:
	if Campaign.active:
		for song in SONGS:
			if song_unlocked(str(song.id)) and int(song_best.get(str(song.id), 0)) < 3:
				return str(song.id)
	return str(SONGS[0].id)


# the song card at the mic: the default first, a locked song last (greyed out)
func song_options() -> Array:
	var first := default_song()
	var order := [first]
	for song in SONGS:
		if str(song.id) != first:
			order.append(str(song.id))
	var open := []
	var shut := []
	for id in order:
		var song := song_by_id(str(id))
		var stars_text := ""
		if song_best.has(id):
			var n := int(song_best[id])
			stars_text = "  %d STAR%s" % [n, "" if n == 1 else "S"]
		var entry := {"label": "%s%s" % [str(song.title), stars_text], "id": id}
		if song_unlocked(str(id)):
			open.append(entry)
		else:
			entry["enabled"] = false
			entry["hint"] = "EARN %d STARS ON ANY SONG" % int(song.get("unlock", 0))
			shut.append(entry)
	return open + shut


func ask_song() -> void:
	Cards.ask(
		"Karaoke host",
		"Step up to the mic. Which song?",
		song_options(),
		func(id: String) -> void: begin_play(id)
	)


# ---- karaoke ------------------------------------------------------------------------------------
# the chart of one song at one tier: {notes, gap, span, speed}. Pure given the generator, so tests can
# build the same chart twice. Doubles put a second arrow in another lane on the same beat.
func kara_chart(song: Dictionary, tier: String, r: RandomNumberGenerator) -> Dictionary:
	var gap := float(song.gap) * float(Difficulty.at("karaoke.gap", tier)) / 0.75
	var rhythm: Array = song.rhythm
	var chance := float(song.doubles[maxi(0, Difficulty.TIERS.find(tier))])
	var notes := []
	var t := 1.5
	var lane := r.randi_range(0, 3)
	var dir := 1
	for i in int(song.len):
		match str(song.pattern):
			"sweep":
				if r.randf() < 0.15:
					lane = r.randi_range(0, 3)
				else:
					if lane + dir < 0 or lane + dir > 3:
						dir = -dir
					lane += dir
			"sync":
				if i % 2 == 0:
					lane = (lane + r.randi_range(1, 3)) % 4
			"burst":
				if i % 4 == 0:
					lane = r.randi_range(0, 3)
				else:
					lane = (lane + 1) % 4
			_:
				lane = r.randi_range(0, 3)
		notes.append({"lane": lane, "time": t, "state": ""})
		if chance > 0.0 and r.randf() < chance:
			notes.append({"lane": (lane + r.randi_range(1, 3)) % 4, "time": t, "state": ""})
		t += gap * float(rhythm[i % rhythm.size()])
	return {"notes": notes, "gap": gap, "span": t, "speed": float(song.speed)}


func _kara_setup(song_id := "") -> void:
	var id := song_id if song_id != "" else str(opts.get("song", default_song()))
	if not song_unlocked(id) and not opts.has("song"):  # the toolbox may pick any song
		id = str(SONGS[0].id)
	var song := song_by_id(id)
	var chart := kara_chart(song, Difficulty.tier, Difficulty.rng("karaoke"))
	g = {
		"t": 0.0,
		"song": song,
		"notes": chart.notes,
		"len": int(song.len),
		"gap": float(chart.gap),
		"span": float(chart.span),
		"speed": float(chart.speed),
		"cuts": song.cuts,
		"score": 0,
		"perfect": 0,
		"good": 0,
		"miss": 0,
		"streak": 0,
		"flash": "",
		"flash_t": 0.0,
		"mood": 50.0,
		"chorus": false,
		"perfect_win": Difficulty.f("karaoke.perfect") * float(song.win),
		"good_win": Difficulty.f("karaoke.good") * float(song.win),
	}


func _kara_tick(dt: float) -> void:
	g.t = float(g.t) + dt
	g.flash_t = maxf(0.0, float(g.flash_t) - dt)
	for n in g.notes:
		if n.state == "" and float(n.time) + _good_win() < float(g.t):
			n.state = "miss"
			g.miss = int(g.miss) + 1
			g.streak = 0
			_streak_broken()
			_mood_add(-6.0)
			g.flash = "MISS"
			g.flash_t = 0.5
	if float(g.mood) <= 0.0:
		g.msg = "THE ROOM LAUGHS AND HEADS BACK TO THE BAR. GOOD TRY!"
		_kara_end()
	elif float(g.t) > _song_secs() + 0.6:
		_kara_end()


func _good_win() -> float:
	return float(g.get("good_win", 0.3))


func _song_secs() -> float:
	if g.has("span"):
		return float(g.span)
	return 1.5 + float(g.get("gap", 0.75)) * float(g.get("len", 24))


# how the crowd feels, 0 to 100 (perfects lift it, misses sink it; a full room joins the last chorus)
func _mood_add(amount: float) -> void:
	g.mood = clampf(float(g.get("mood", 50.0)) + amount, 0.0, 100.0)
	if float(g.mood) >= 100.0 and not g.get("chorus", false):
		g.chorus = true
		g.flash = "THE ROOM SINGS!"
		g.flash_t = 1.2
		if room_mode():
			_cheer()
			caption("THE WHOLE ROOM JOINS THE CHORUS!", 3.0)


func _kara_press(key: int) -> void:
	var lane := LANE_KEYS.find(key)
	if lane < 0:
		return
	kara_hit(lane)


func kara_hit(lane: int) -> String:
	var pick: Dictionary = {}
	var gap := 9.0
	for n in g.notes:
		if n.state == "" and int(n.lane) == lane and absf(float(n.time) - float(g.t)) < gap:
			gap = absf(float(n.time) - float(g.t))
			pick = n
	if pick.is_empty() or gap > _good_win():
		g.streak = 0
		_streak_broken()
		_mood_add(-2.0)
		return ""
	var perfect := gap <= float(g.get("perfect_win", 0.12))
	pick.state = "perfect" if perfect else "good"
	g.score = int(g.score) + (2 if perfect else 1)
	g.perfect = int(g.perfect) + (1 if perfect else 0)
	g.good = int(g.good) + (0 if perfect else 1)
	g.streak = int(g.streak) + 1
	g.flash = "PERFECT!" if perfect else "GOOD"
	g.flash_t = 0.5
	_mood_add((3.0 if perfect else 1.5) + minf(2.0, floorf(float(g.streak) / 4.0)))
	if room_mode() and int(g.streak) % 4 == 0:
		_cheer()
	if room_mode() and int(g.streak) >= 8 and not g.get("dance", false):
		g.dance = true
		_hold_player("dance")
	return str(pick.state)


func _kara_end() -> void:
	var share := float(g.score) / float(maxi(1, g.notes.size() * 2))
	var cuts: Array = g.get("cuts", [0.75, 0.5, 0.25])
	var result := (
		3 if share >= cuts[0] else (2 if share >= cuts[1] else (1 if share >= cuts[2] else 0))
	)
	if g.get("chorus", false) and share >= 0.5 and result < 3:
		result += 1  # the room sang the last chorus with you
	if g.has("song"):
		var id := str(g.song.id)
		song_best[id] = maxi(int(song_best.get(id, 0)), result)
	_finish(result)


# ---- escape room --------------------------------------------------------------------------------
func _zeros(n: int) -> Array:
	var out := []
	out.resize(n)
	out.fill(0)
	return out


func _escape_setup() -> void:
	var digits := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	Difficulty.shuffle(digits, "escape")
	var n := escape_digits()
	var friends := 0
	for who in present():
		friends += 1 if Social.is_friendly(who) else 0
	g = {
		"code": digits.slice(0, n),
		"cur": _zeros(n),
		"cursor": 0,
		"guesses": [],
		"time": Difficulty.f("escape.time"),
		"hints": clampi(maxi(1, friends), 1, 3),
		"hints_used": 0,
		"revealed": [],
		"msg": "",
	}


# the code length: the tier's, or the toolbox's choice (3 or 4)
func escape_digits() -> int:
	return clampi(int(opts.get("digits", Difficulty.i("escape.digits"))), 3, 4)


func _escape_tick(dt: float) -> void:
	g.time = float(g.time) - dt
	if float(g.time) <= 0.0:
		g.msg = "TIME IS UP"
		_finish(0)


func _escape_press(key: int) -> void:
	var cur: Array = g.cur
	var n: int = cur.size()
	match key:
		KEY_LEFT:
			g.cursor = (int(g.cursor) + n - 1) % n
		KEY_RIGHT:
			g.cursor = (int(g.cursor) + 1) % n
		KEY_UP:
			cur[int(g.cursor)] = (int(cur[int(g.cursor)]) + 1) % 10
		KEY_DOWN:
			cur[int(g.cursor)] = (int(cur[int(g.cursor)]) + 9) % 10
		KEY_ENTER, KEY_KP_ENTER:
			if room_mode():
				_room_submit()
			else:
				escape_try(cur.duplicate())
		KEY_H:
			if not room_mode():
				escape_hint()


func escape_score(guess: Array) -> Array:
	var code: Array = g.code
	var bulls := 0
	var cows := 0
	for i in code.size():
		if int(guess[i]) == int(code[i]):
			bulls += 1
		elif code.has(int(guess[i])):
			cows += 1
	return [bulls, cows]


func escape_try(guess: Array) -> void:
	if g.guesses.size() >= 8:
		return
	var score := escape_score(guess)
	g.guesses.append([guess, score[0], score[1]])
	if int(score[0]) == g.code.size():
		var tries: int = g.guesses.size()
		var result := 3 if tries <= 4 else (2 if tries <= 6 else 1)
		if int(g.hints_used) >= 2:
			result = maxi(1, result - 1)
		g.msg = "THE DOOR CLICKS OPEN!"
		_finish(result)
	elif g.guesses.size() >= 8:
		g.msg = "OUT OF TRIES"
		_finish(0)


# the first friend you get on with (the hints are in their voice); never yourself, and with nobody friendly the first person in the room
func _friend() -> String:
	var out := present()
	for who in Social.people():
		if Social.is_friendly(who) and out.has(who):
			return who
	return str(out[0]) if not out.is_empty() else "Alan"


func _first_friend() -> String:
	return _friend().to_upper()


func escape_hint() -> String:
	if int(g.hints) <= 0:
		return ""
	var open := []
	for i in g.code.size():
		if not g.revealed.has(i):
			open.append(i)
	if open.is_empty():
		return ""
	var slot: int = Difficulty.pick(open, "escape")
	g.revealed.append(slot)
	g.hints = int(g.hints) - 1
	g.hints_used = int(g.hints_used) + 1
	g.cur[slot] = g.code[slot]
	g.msg = "%s: SLOT %d IS A %d" % [_friend().to_upper(), slot + 1, int(g.code[slot])]
	return str(g.msg)


# ---- dinner -------------------------------------------------------------------------------------
func topic_ids() -> Array:
	var out := []
	for t in TOPICS:
		out.append(str(t.id))
	return out


func topic_tag(id: String) -> String:
	for t in TOPICS:
		if str(t.id) == id:
			return str(t.tag)
	return "light"


# the tastes an old save (and the first versions of the game) always had
func classic_taste(who: String) -> Dictionary:
	var row: Dictionary = PEOPLE.get(who, {"loves": [], "hates": []})
	return {"loves": row.loves.slice(0, 2), "hates": row.hates.slice(0, 1)}


# what a person really loves and dreads in THIS save: the PEOPLE row with one or two tastes swapped
func taste(who: String) -> Dictionary:
	if not tastes.has(who):
		tastes[who] = _roll_tastes(who)
	return tastes[who]


func _roll_tastes(who: String) -> Dictionary:
	var row: Dictionary = PEOPLE.get(who, {"loves": [], "hates": []})
	var loves: Array = row.loves.duplicate()
	var hates: Array = row.hates.duplicate()
	var r := Difficulty.rng_for("tastes", hash(who) & 0xFFFF)
	for _swap in r.randi_range(1, 2):
		var pool := []
		for id in topic_ids():
			if not loves.has(id) and not hates.has(id):
				pool.append(id)
		if hates.is_empty() or (not loves.is_empty() and r.randf() < 0.5):
			if not loves.is_empty():
				loves[r.randi_range(0, loves.size() - 1)] = pool[r.randi_range(0, pool.size() - 1)]
		else:
			var kind := []
			for id in pool:
				if not PROTECTED_TOPICS.has(id):
					kind.append(id)
			hates[r.randi_range(0, hates.size() - 1)] = kind[r.randi_range(0, kind.size() - 1)]
	return {"loves": loves, "hates": hates}


# 2 for something they love, 0 for something they dread, 1 otherwise (before mood)
func taste_pts(who: String, topic: String) -> int:
	var t := taste(who)
	if t.loves.has(topic):
		return 2
	if t.hates.has(topic):
		return 0
	return 1


# the mood of the day (and the owner's budget) lifts or sinks every answer by up to two points
func diner_shift(who: String) -> int:
	var shift := 0
	if g.has("moods"):
		shift += int(DINNER_MOODS[str(g.moods.get(who, "easygoing"))].shift)
	shift += int(BUDGETS[str(g.get("budget", "normal"))].mood)
	return clampi(shift, -2, 2)


func diner_points(who: String, topic: String) -> int:
	return clampi(taste_pts(who, topic) + diner_shift(who), 0, 3)


# a trap: somebody at the table dreads it
func is_trap(topic: String) -> bool:
	for who in diners():
		if taste(who).hates.has(topic):
			return true
	return false


func dinner_mood_text() -> String:
	var parts := []
	for who in diners():
		parts.append("%s IS %s" % [who.to_upper(), str(g.moods.get(who, "easygoing")).to_upper()])
	return ", ".join(parts)


func _dinner_setup() -> void:
	g = {
		"round": 1,
		"options": [],
		"sel": 0,
		"react": {},
		"wait": 0.0,
		"score": 0,
		"last": "",
		"budget": "normal",
		"moods": {},
		"picked": [],
	}
	var ids: Array = DINNER_MOODS.keys()
	var r := Difficulty.rng("dinner")
	for who in diners():
		var pool: Array = PEOPLE.get(who, {}).get("moods", ids)  # a quirk: some moods come up more often
		g.moods[who] = pool[r.randi_range(0, pool.size() - 1)]
	_dinner_deal()


# four topics a round: at least one safe (nobody dreads it) and one trap, never one you already used
func _dinner_deal() -> void:
	var safe := []
	var trap := []
	for id in topic_ids():
		if g.get("picked", []).has(id):
			continue
		if is_trap(id):
			trap.append(id)
		else:
			safe.append(id)
	if safe.is_empty() or trap.is_empty():
		safe = []
		trap = []
		for id in topic_ids():
			if is_trap(id):
				trap.append(id)
			else:
				safe.append(id)
	Difficulty.shuffle(safe, "dinner")
	Difficulty.shuffle(trap, "dinner")
	# a treat: somebody loves it and nobody dreads it, so a good round is always on the table
	var treats := safe.filter(
		func(id: String) -> bool:
			for who in diners():
				if taste(who).loves.has(id):
					return true
			return false
	)
	var chosen := []
	if not treats.is_empty():
		chosen.append(treats[0])
		safe.erase(treats[0])
	chosen.append(safe.pop_back())
	chosen.append(trap.pop_back())
	var rest := safe + trap
	Difficulty.shuffle(rest, "dinner")
	chosen.append_array(rest.slice(0, 4 - chosen.size()))
	Difficulty.shuffle(chosen, "dinner")
	g.options = chosen
	g.sel = 0
	g.react = {}
	g.wait = 0.0


func _dinner_tick(dt: float) -> void:
	if not g.react.is_empty():
		g.wait = float(g.wait) - dt
		if float(g.wait) <= 0.0:
			if int(g.round) >= 5:
				_dinner_end()
			else:
				g.round = int(g.round) + 1
				_dinner_deal()


func _dinner_press(key: int) -> void:
	if not g.react.is_empty() or str(g.get("stage", "")) == "sit":
		return
	match key:
		KEY_UP:
			g.sel = (int(g.sel) + 3) % 4
		KEY_DOWN:
			g.sel = (int(g.sel) + 1) % 4
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			dinner_talk(int(g.sel))


func dinner_talk(index: int) -> int:
	var topic: String = g.options[index]
	var total := 0
	g.react = {}
	g.picked.append(topic)
	g.hidden = _dinner_hidden()
	for who in diners():
		var base := taste_pts(who, topic)
		var mood := "love" if base == 2 else ("hate" if base == 0 else "meh")
		total += diner_points(who, topic)
		g.react[who] = mood
		if g.hidden.has(who):
			continue  # a face you could not read teaches you nothing
		var entry: Dictionary = known.get(who, {"likes": [], "hates": []})
		if mood == "love" and not entry.likes.has(topic):
			entry.likes.append(topic)
		elif mood == "hate" and not entry.hates.has(topic):
			entry.hates.append(topic)
		known[who] = entry
	g.score = int(g.score) + total
	g.wait = 1.4
	if room_mode():
		_dinner_react()
	return total


# the owner pays: cheap, normal or fancy (the cost replaces the $300 charged on arrival)
func budget_options() -> Array:
	var spare := int(Owner.cash) + int(GAMES.dinner.cost)
	var out := []
	for id in ["normal", "cheap", "fancy"]:
		var b: Dictionary = BUDGETS[id]
		var entry := {"label": "%s ($%d)" % [str(b.label), int(b.cost)], "id": id}
		if spare < int(b.cost):
			entry["enabled"] = false
			entry["hint"] = "NEED $%d" % int(b.cost)
		out.append(entry)
	return out


func ask_budget() -> void:
	Cards.ask(
		"Restaurant host",
		"Who picks up the check? A fancy table lifts the mood all night.",
		budget_options(),
		func(id: String) -> void:
			begin_play()
			set_budget(id)
	)


func set_budget(id: String) -> void:
	if game != "dinner" or g.is_empty() or not BUDGETS.has(id):
		return
	if Campaign.mode == "owner":
		Owner.cash += int(BUDGETS[str(g.budget)].cost) - int(BUDGETS[id].cost)
	g.budget = id


# harder tiers hide some faces for a round (the points still count)
func _dinner_hidden() -> Array:
	var table := diners()
	var hide_n := table.size() - clampi(Difficulty.i("dinner.reveal"), 0, table.size())
	if hide_n <= 0:
		return []
	var order: Array = table.duplicate()
	Difficulty.shuffle(order, "dinner")
	return order.slice(0, hide_n)


# the score for 3 / 2 / 1 stars: a good mood at the table lifts the bar, a tired one lowers it
func dinner_targets() -> Array:
	var shifts := 0
	for who in diners():
		shifts += diner_shift(who)
	var n := diners().size()
	var row: Array = TABLE_BARS[clampi(n, 1, TABLE_MAX)]
	var neutral := 5 * n  # five rounds of an indifferent answer from everyone
	return [
		roundi(neutral + int(row[0]) + 3 * shifts),
		roundi(neutral + int(row[1]) + 3 * shifts),
		roundi(neutral - int(row[2]) + 3 * shifts)
	]


func _dinner_end() -> void:
	var score := int(g.score)
	var cut := dinner_targets()
	_finish(3 if score >= cut[0] else (2 if score >= cut[1] else (1 if score >= cut[2] else 0)))


# ---- in the room: the games are played in the scene itself ---------------------------------------
func room_mode() -> bool:
	return _traveled and is_open


func _x0() -> float:
	return float(World.DATA.SCENES[str(ROOMS[game])].x0)


func _actor(who: String) -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Actors/" + who) if scene != null else null


func _place_player(x: float) -> void:
	var p := _actor("Player")
	if p != null:
		p.global_position = Vector2(x, 118.0)
		p.velocity = Vector2.ZERO


func _hold_player(anim: String, toward := INF) -> void:
	var p := _actor("Player")
	if p != null:
		p.start_emote(anim, 100000.0, toward)


func _release_player() -> void:
	var p := _actor("Player")
	if p != null and p.state == "emote":
		p.start_emote("idle", 0.05)


func caption(text: String, secs := 3.0) -> void:
	_caption = text
	_caption_t = secs


func _bubble(node: Node, glyph: String, secs := 1.2) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("_ensure_bubble"):
		node._ensure_bubble()
	if node.get("_bubble") == null:
		return
	node._bubble.glyph = glyph
	node._bubble.visible = true
	_marks[node] = secs


func _room_begin() -> void:
	Game.ui_open = false
	match game:
		"karaoke":
			var mic := _x0() + MIC_X
			_place_player(mic)
			_hold_player("talk", mic + 60.0)
			caption("%s. ARROW KEYS AT THE LINE. SING!" % str(g.song.title), 4.0)
		"escape":
			caption("LOOK AROUND. E ON THE CHALKBOARD, THE CLOCK, THE PAINTING. N = HINT", 6.0)
		"dinner":
			g.stage = "sit"
			caption("SIT AT THE BOOTH WITH THE TEAM (PRESS E ON THE SEAT)", 99.0)


func _room_process(delta: float) -> void:
	_caption_t = maxf(0.0, _caption_t - delta)
	for node in _marks.keys():
		_marks[node] = float(_marks[node]) - delta
		if float(_marks[node]) <= 0.0:
			if is_instance_valid(node) and node.get("_bubble") != null:
				node._bubble.visible = false
			_marks.erase(node)
	if phase == "play" and game == "dinner" and str(g.get("stage", "")) == "sit":
		var p := _actor("Player")
		if p != null and p.state == "sitting":
			g.stage = "talk"
			Game.ui_open = true
			caption("%s. PICK A TOPIC (UP / DOWN, ENTER)." % dinner_mood_text(), 6.0)


# keys the in-room game wants (the rest still move you around)
func _room_wants(key: int) -> bool:
	if key == KEY_ESCAPE:
		return true
	match game:
		"bowling":
			return key in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		"karaoke":
			return key in LANE_KEYS
		"escape":
			if g.get("entry", false):
				return key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]
			return key == KEY_N
		_:
			return (
				str(g.get("stage", "")) == "talk"
				and key in [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			)


func _room_press(key: int) -> bool:
	if game == "escape" and key == KEY_N and not g.get("entry", false):
		escape_nudge()
		return true
	return false


# E belongs to the bowling game while it runs (the crew should not answer it)
func blocks_interact() -> bool:
	return is_open and room_mode() and phase == "play" and game == "bowling"


# the one control hint line: pages show it as their footer, rooms in the bar at the bottom
func hint() -> String:
	if phase == "intro":
		return "ENTER = START  ESC = SKIP  TAB = LOOK" if _traveled else "ENTER = START  ESC = SKIP"
	if phase == "result":
		return "ENTER = CONTINUE"
	if not room_mode():
		return str(GAMES[game].keys)
	match game:
		"bowling":
			match str(g.get("stage", "")):
				"ready":
					return "E = STEP UP  ESC = LEAVE"
				"aim":
					return "E = STOP THE AIM  ESC = LEAVE"
				"power":
					return "E = STOP THE POWER  ESC = LEAVE"
			return "WAIT FOR YOUR TURN  ESC = LEAVE"
		"karaoke":
			return "ARROW KEYS = HIT NOTES  ESC = LEAVE"
		"escape":
			if g.get("entry", false):
				return "ARROWS  ENTER = TRY  ESC = BACK"
			return "E = LOOK / USE  N = HINT  ESC = LEAVE"
	if str(g.get("stage", "")) == "talk":
		return "UP / DOWN  ENTER = TALK  ESC = LEAVE"
	return "E = SIT DOWN  ESC = LEAVE"


# ---- karaoke extras
func _cheer() -> void:
	var cheer: Array = crowd()
	if cheer.is_empty():
		return
	var who: String = Difficulty.pick(cheer, "karaoke")
	_bubble(_actor(who), "heart", 1.5)
	var line := crew_line(who, "sing")  # the crowd cheers by name
	if line != "":
		caption("%s: %s" % [who.to_upper(), line], 1.8)


func _streak_broken() -> void:
	if not room_mode() or game != "karaoke":
		return
	if g.get("dance", false):
		g.dance = false
		_hold_player("talk", _x0() + MIC_X + 60.0)
	if Difficulty.rng("karaoke").randf() < 0.3:
		var listeners := crowd()
		if not listeners.is_empty():
			_bubble(_actor(Difficulty.pick(listeners, "karaoke")), "?", 1.0)


# ---- escape room extras
# can this recipe show this digit? (a product needs a pair that multiplies to it, a double needs an even digit)
func recipe_fits(recipe: String, digit: int) -> bool:
	match recipe:
		"product":
			return PRODUCTS.has(digit)
		"double":
			return digit % 2 == 0
	return true


# one clue: what the zone shows ("show"), what the caption says ("say") and the digit it hides
func make_clue(zone: String, recipe: String, digit: int, r: RandomNumberGenerator) -> Dictionary:
	var clue := {"zone": zone, "recipe": recipe, "digit": digit, "args": {}, "show": "", "say": ""}
	match recipe:
		"sum":
			var a := r.randi_range(0, digit)
			clue.args = {"a": a, "b": digit - a}
			clue.show = "%d+%d=?" % [a, digit - a]
			clue.say = "THE CHALKBOARD: %d + %d = ?" % [a, digit - a]
		"product":
			var pair: Array = PRODUCTS[digit]
			clue.args = {"a": pair[0], "b": pair[1]}
			clue.show = "%dX%d=?" % pair
			clue.say = "THE CHALKBOARD: %d X %d = ?" % pair
		"missing":
			var list := [1, 2, 3, 4, 5, 6, 7, 8, 9]
			list.erase(digit)
			for k in range(list.size() - 1, 0, -1):
				var j := r.randi_range(0, k)
				var tmp = list[k]
				list[k] = list[j]
				list[j] = tmp
			clue.args = {"list": list}
			clue.show = "%s|MISSING?" % "".join(PackedStringArray(list.map(func(v): return str(v))))
			clue.say = (
				"THE CHALKBOARD LISTS 1 TO 9 WITH ONE LEFT OUT: %s. WHICH ONE?"
				% " ".join(PackedStringArray(list.map(func(v): return str(v))))
			)
		"hour":
			clue.args = {"hour": digit}
			clue.show = str(digit)
			clue.say = "THE CLOCK HAS STOPPED AT %d O'CLOCK." % digit
		"double":
			var half := int(digit / 2.0)
			clue.args = {"hour": half}
			clue.show = str(half)
			clue.say = (
				"THE CLOCK HAS STOPPED AT %d O'CLOCK. A NOTE ON THE FACE: TWICE THE HOUR." % half
			)
		"number":
			clue.args = {"n": digit}
			clue.show = str(digit)
			clue.say = "A BRASS PLAQUE UNDER THE PAINTING: NO. %d." % digit
		"roman":
			clue.args = {"numeral": ROMAN[digit]}
			clue.show = ROMAN[digit]
			clue.say = "THE PLAQUE UNDER THE PAINTING READS %s. A ROMAN NUMERAL." % ROMAN[digit]
		"letter":
			var letter := char(64 + digit)
			clue.args = {"letter": letter}
			clue.show = letter
			clue.say = (
				"THE PLAQUE UNDER THE PAINTING SHOWS THE LETTER %s. WHERE IS IT IN THE ALPHABET?"
				% letter
			)
		"spine":
			clue.args = {"n": digit}
			clue.show = "VOL %d" % digit
			clue.say = "ONE BOOK ON THE SHELF STICKS OUT: VOLUME %d." % digit
		"ribbons":
			clue.args = {"n": digit}
			clue.show = str(digit)
			clue.say = "BOOKMARK RIBBONS HANG FROM THE SHELF. COUNT THEM: %d." % digit
	return clue


# the digit a clue stands for, worked out from what it shows (tests check it against the code)
func clue_answer(clue: Dictionary) -> int:
	var a: Dictionary = clue.args
	var out := int(a.get("n", 0))
	match str(clue.recipe):
		"sum":
			out = int(a.a) + int(a.b)
		"product":
			out = int(a.a) * int(a.b)
		"missing":
			out = 45
			for v in a.list:
				out -= int(v)
		"hour":
			out = int(a.hour)
		"double":
			out = int(a.hour) * 2
		"roman":
			out = ROMAN.find(str(a.numeral))
		"letter":
			out = str(a.letter).unicode_at(0) - 64
	return out


func _escape_room_setup() -> void:
	var pool := [1, 2, 3, 4, 5, 6, 7, 8, 9]
	Difficulty.shuffle(pool, "escape")
	var n := escape_digits()
	var r := Difficulty.rng("escape")
	var wanted: Dictionary = opts.get("recipes", {})  # toolbox: a fixed recipe per clue zone
	var clues := []
	for i in n:
		var zone: String = CLUE_ZONES[i]
		var want := str(wanted.get(zone, ""))
		if want != "" and RECIPES[zone].has(want) and not recipe_fits(want, int(pool[i])):
			for j in range(i + 1, pool.size()):  # bring a digit this recipe can show
				if recipe_fits(want, int(pool[j])):
					var tmp = pool[i]
					pool[i] = pool[j]
					pool[j] = tmp
					break
		var fits := []
		for recipe in RECIPES[zone]:
			if recipe_fits(str(recipe), int(pool[i])) and (want == "" or str(recipe) == want):
				fits.append(recipe)
		if fits.is_empty():
			fits = RECIPES[zone].filter(func(rc) -> bool: return recipe_fits(str(rc), int(pool[i])))
		clues.append(make_clue(zone, str(fits[r.randi_range(0, fits.size() - 1)]), int(pool[i]), r))
	var eq := [clues[0].args.get("a", 0), clues[0].args.get("b", 0)]
	g = {
		"code": pool.slice(0, n),
		"cur": _zeros(n),
		"cursor": 0,
		"guesses": [],
		"time": Difficulty.f("escape.time"),
		"hints": 3,
		"hints_used": 0,
		"revealed": [],
		"msg": "",
		"found": [],
		"entry": false,
		"wrong": 0,
		"clues": clues,
		"dial": Difficulty.i("escape.dial") > 0,
		"eq": eq,
	}


func interact(kind: String) -> void:
	if not room_mode() or game != "escape" or phase != "play" or g.is_empty():
		return
	var index := CLUE_KINDS.find(kind)
	if index >= 0:
		if index < g.clues.size():
			_found(index)
			caption(
				(
					"%s  THAT IS DIGIT %d OF %d IN THE CODE."
					% [str(g.clues[index].say), index + 1, g.code.size()]
				),
				6.0
			)
		else:
			caption(
				str(HERRINGS[Difficulty.rng("escape").randi_range(0, HERRINGS.size() - 1)]), 4.0
			)
	elif kind == "keypad":
		g.entry = true
		Game.ui_open = true
		caption(
			"ENTER THE CODE: UP / DOWN CHANGE, LEFT / RIGHT MOVE, ENTER TRIES IT, ESC BACKS OFF",
			6.0
		)


func _found(index: int) -> void:
	if not g.found.has(index):
		g.found.append(index)


func escape_nudge() -> String:
	if int(g.hints) <= 0:
		caption("NOBODY HAS ANYTHING LEFT TO SAY.", 2.0)
		return ""
	var friend := _friend()
	var zone := "keypad"
	var recipe := ""
	for i in g.clues.size():
		if not g.found.has(i):
			zone = CLUE_ZONES[i]
			recipe = str(g.clues[i].recipe)
			break
	var table: Dictionary = FRIEND_HINTS.get(friend, FRIEND_HINTS["Alan"])
	var text := str(table.get(zone, ""))
	if str(SPECIALTY.get(friend, "")) == zone:
		if zone == "keypad":
			text += " " + str(RECIPE_TIPS["dial" if g.get("dial", false) else "nodial"])
		else:
			text += " " + str(RECIPE_TIPS.get(recipe, ""))
	g.hints = int(g.hints) - 1
	g.hints_used = int(g.hints_used) + 1
	text = "%s: %s" % [friend.to_upper(), text]
	caption(text, 5.0)
	_bubble(_actor(friend), "!", 1.5)
	return text


func _room_submit() -> void:
	var cur: Array = g.cur
	if cur == g.code:
		var left := float(g.time)
		var big := 70.0 if g.code.size() <= 3 else 55.0
		var result := 3 if left >= big else (2 if left >= big / 2.0 else 1)
		if int(g.hints_used) >= 2:
			result = maxi(1, result - 1)
		g.entry = false
		g.msg = "THE VAULT OPENS!"
		_finish(result)
		return
	g.wrong = int(g.wrong) + 1
	var penalty := Difficulty.f("escape.wrong_penalty")
	g.time = float(g.time) - penalty
	var text := "WRONG CODE. THE ALARM SHAVES %d SECONDS OFF." % int(penalty)
	if g.get("dial", false):
		# the dial lock is a second route: it tells you which digits fit (bulls and cows)
		var score := escape_score(cur)
		g.guesses.append([cur.duplicate(), score[0], score[1]])
		text += "  THE DIAL CLICKS: %d IN PLACE, %d OUT OF PLACE." % [int(score[0]), int(score[1])]
	caption(text, 4.0)


# ---- dinner extras
func _dinner_react() -> void:
	var parts := []
	for who in diners():
		var mood: String = g.react[who]
		if g.get("hidden", []).has(who):
			_bubble(_actor(who), "?", 1.3)
			parts.append("%s IS HARD TO READ" % who.to_upper())
			continue
		_bubble(
			_actor(who), "heart" if mood == "love" else ("!" if mood == "hate" else "dots"), 1.3
		)
		parts.append(
			(
				"%s %s"
				% [
					who.to_upper(),
					{"love": "LOVES IT", "hate": "DREADS IT", "meh": "IS FINE"}[mood]
				]
			)
		)
	caption(", ".join(parts), 2.0)


# ---- the in-room display (replaces the panel while you play)
func _paint_hud(size: Vector2) -> void:
	UiStyle.hint_bar(_canvas, size, hint())
	var top := UiStyle.caption_bar(_canvas, size, _caption if _caption_t > 0.0 else "")
	var strip_w := 176.0 if game == "dinner" else 164.0  # five faces need the room
	var strip := Rect2(0.0, top - UiStyle.STRIP_H, minf(size.x, strip_w), UiStyle.STRIP_H)
	match game:
		"bowling":
			_hud_bowling(strip)
		"karaoke":
			_hud_karaoke(strip)
		"escape":
			_hud_escape(strip)
		_:
			_hud_dinner(strip, size)


func _hud_bowling(s: Rect2) -> void:
	var o := UiStyle.strip(_canvas, s)
	_t("FRAME %d OF 5" % int(g.frame), o.x, o.y, WHITE)
	var stage := str(g.stage)
	var x := s.position.x + 58.0
	if stage == "aim" or stage == "power":
		var bar := Rect2(s.position.x + 82.0, s.position.y + 3.0, 80.0, 5.0)
		_canvas.draw_rect(bar, UiStyle.SOFT)
		if stage == "aim":
			_canvas.draw_rect(Rect2(bar.position.x + 32.0, bar.position.y, 16.0, 5.0), GREEN)
			_canvas.draw_rect(
				Rect2(bar.position.x + 79.0 * float(g.marker), bar.position.y - 2.0, 2.0, 9.0),
				WHITE
			)
			_t("AIM", x, o.y, WHITE)
		else:
			_canvas.draw_rect(Rect2(bar.position.x + 58.0, bar.position.y, 14.0, 5.0), GREEN)
			_canvas.draw_rect(
				Rect2(bar.position.x, bar.position.y, 80.0 * float(g.power), 5.0), AMBER
			)
			_t("POWER", x, o.y, WHITE)
	else:
		var status := (
			"YOUR TURN" if stage == "ready" else ("ROLLING" if stage == "roll" else "CREW BOWLS")
		)
		_t(status, x, o.y, UiStyle.SOFT)


func _hud_karaoke(s: Rect2) -> void:
	var lanes := Rect2(4.0, s.position.y - 79.0, 100.0, 78.0)
	UiStyle.box(_canvas, lanes)
	_paint_karaoke(
		Rect2(
			lanes.position.x + 2.0, lanes.position.y + 2.0, lanes.size.x - 4.0, lanes.size.y - 4.0
		),
		true
	)
	var o := UiStyle.strip(_canvas, s)
	_t("SCORE %d  STREAK %d" % [int(g.score), int(g.streak)], o.x, o.y, WHITE)
	if float(g.flash_t) > 0.0:
		_t(str(g.flash), s.position.x + 88.0, o.y, GREEN if g.flash != "MISS" else RED)


func _hud_escape(s: Rect2) -> void:
	var o := UiStyle.strip(_canvas, s)
	if not g.get("entry", false):
		_t(
			"CLUES %d OF %d  HINTS %d" % [g.found.size(), g.code.size(), int(g.hints)],
			o.x,
			o.y,
			WHITE
		)
		return
	_t("CODE", o.x, o.y, WHITE)
	for i in g.code.size():
		var r := Rect2(s.position.x + 32.0 + 12.0 * float(i), s.position.y + 1.0, 10.0, 9.0)
		_canvas.draw_rect(r, WHITE)
		_canvas.draw_rect(
			Rect2(r.position.x, r.end.y - 1.0, 10.0, 1.0),
			BLUE if int(g.cursor) == i else UiStyle.SOFT
		)
		PixelFont.draw(
			_canvas,
			str(int(g.cur[i])),
			r.position + Vector2(3.0, 2.0),
			GREEN if g.revealed.has(i) else INK,
			1
		)


func _hud_dinner(s: Rect2, size: Vector2) -> void:
	var o := UiStyle.strip(_canvas, s)
	if str(g.get("stage", "")) != "talk":
		_t("SIT AT THE BOOTH", o.x, o.y, UiStyle.SOFT)
		return
	_t("ROUND %d/5  SCORE %d" % [int(g.round), int(g.score)], o.x, o.y, WHITE)
	# the mood of the day, one face per diner (A = Alan ...; two letters when two names start alike)
	var fx_x := s.position.x + 88.0
	var table := diners()
	var firsts := table.map(func(n: String) -> String: return n.substr(0, 1))
	for who in table:
		var md: String = str(g.get("moods", {}).get(who, "easygoing"))
		var shift := int(DINNER_MOODS[md].shift)
		var face := str(DINNER_MOODS[md].face)
		var tag: String = who.substr(0, 2 if firsts.count(who.substr(0, 1)) > 1 else 1).to_upper()
		_t(tag, fx_x, o.y, UiStyle.SOFT)
		fx_x += 4.0 * float(tag.length())
		_t(face, fx_x, o.y, GREEN if shift > 0 else (AMBER if shift < 0 else WHITE))
		fx_x += 4.0 * float(face.length()) + 3.0
	var w := minf(size.x - 8.0, 84.0)  # narrow, so it stays right of Vic at the bar in the 320x180 format
	var box := Rect2(size.x - w - 4.0, s.position.y - 43.0, w, 42.0)
	UiStyle.box(_canvas, box)
	for i in 4:
		var on: bool = int(g.sel) == i and g.react.is_empty()
		var ry := box.position.y + 4.0 + 9.0 * float(i)
		if on:
			_canvas.draw_rect(Rect2(box.position.x + 2.0, ry - 1.0, w - 4.0, 8.0), Color("ffe08a"))
		_t(str(g.options[i]), box.position.x + 4.0, ry, INK if on else WHITE)


# ---- drawing ------------------------------------------------------------------------------------
func _t(s: String, x: float, y: float, color := INK) -> void:
	PixelFont.draw(_canvas, s, Vector2(x, y), color, 1)


func _tc(s: String, cx: float, y: float, color := INK) -> void:
	PixelFont.draw(_canvas, s, Vector2(cx - float(PixelFont.width(s, 1)) * 0.5, y), color, 1)


func _wrap(s: String, chars: int) -> Array:
	return UiStyle.wrap_text(s, chars)


func _star(c: Vector2, r: float, color: Color) -> void:
	UiStyle.star(_canvas, c, r, color)


func _arrow(lane: int, c: Vector2, size: float, color: Color) -> void:
	var s := size
	var pts := PackedVector2Array()
	match lane:
		0:
			pts = PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s, -s), c + Vector2(s, s)])
		1:
			pts = PackedVector2Array([c + Vector2(0, -s), c + Vector2(-s, s), c + Vector2(s, s)])
		2:
			pts = PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, -s), c + Vector2(s, -s)])
		_:
			pts = PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s, -s), c + Vector2(-s, s)])
	_canvas.draw_colored_polygon(pts, color)


func _paint() -> void:
	if not is_open:
		return
	var size := get_viewport().get_visible_rect().size
	if room_mode() and phase == "play":
		_paint_hud(size)
		return
	if Cards.is_open:
		return  # the song / budget card has the screen (the page comes back after it)
	if _traveled and _peek:
		UiStyle.hint_bar(_canvas, size, "TAB = BACK TO THE GAME")
		return
	_canvas.draw_rect(
		Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.0 if _traveled else 0.86)
	)
	var panel := UiStyle.panel_rect(size, 250.0, 112.0)
	var title := str(GAMES[game].label) + ("  TEAM OUTING" if phase != "result" else "  RESULT")
	var body := UiStyle.panel(_canvas, panel, title, "", 0.88 if _traveled else 1.0)
	match phase:
		"intro":
			_paint_intro(body)
		"result":
			_paint_result(body)
		_:
			match game:
				"bowling":
					_paint_bowling(body)
				"karaoke":
					_paint_karaoke(body)
				"escape":
					_paint_escape(body)
				_:
					_paint_dinner(body)
	UiStyle.footer(_canvas, panel, hint())


func _paint_intro(b: Rect2) -> void:
	var y := b.position.y + 2.0
	var blurb := str(ROOM_INTRO[game]) if _traveled else str(GAMES[game].blurb)
	if game == "bowling" and not bowlers().is_empty():  # the blurbs name the classic trio: say who is really here
		blurb = blurb.replace("ALAN, GARRISON AND DAN", join_names(bowlers(), true))
	for line in _wrap(blurb, int(b.size.x / 4.0)):
		_t(line, b.position.x, y)
		y += 7.0
	y += 4.0
	if Campaign.mode == "owner":
		_t("COST $%d" % int(GAMES[game].cost), b.position.x, y, RED)
		y += 7.0
	if best.has(game):
		_t("YOUR BEST: %d OF 3 STARS" % int(best[game]), b.position.x, y, GREEN)


func _paint_result(b: Rect2) -> void:
	UiStyle.stars(_canvas, b.position.x + b.size.x * 0.5, b.position.y, stars)
	var y := b.position.y + 24.0
	for line in lines:
		for part in _wrap(str(line), int(b.size.x / 4.0)):
			_t(part, b.position.x, y)
			y += 7.0
	var detail := ""
	if not g.is_empty():
		match game:
			"bowling":
				detail = "YOU %d" % int(g.totals["You"])
				for who in bowlers():
					detail += "  %s %d" % [who.to_upper(), int(g.totals[who])]
			"karaoke":
				detail = (
					"PERFECT %d  GOOD %d  MISSED %d" % [int(g.perfect), int(g.good), int(g.miss)]
				)
			"escape":
				var digits := ""
				for d in g.code:
					digits += str(int(d))
				detail = (
					"CODE %s  TRIES %d  HINTS %d"
					% [
						digits,
						maxi(g.guesses.size(), int(g.get("wrong", 0)) + (1 if stars > 0 else 0)),
						int(g.hints_used)
					]
				)
			"dinner":
				detail = "TABLE SCORE %d (3 STARS AT %d)" % [int(g.score), int(dinner_targets()[0])]
	if detail != "":
		_t(detail, b.position.x, y + 3.0, BLUE)


func _paint_bowling(b: Rect2) -> void:
	var x := b.position.x
	var y := b.position.y
	_t("FRAME %d  ROLL %d" % [int(g.frame), int(g.roll)], x, y)
	var names := ["You"] + bowlers()
	for i in names.size():
		_t(
			"%s %d" % [names[i].to_upper(), int(g.totals[names[i]])],
			x,
			y + 10.0 + 8.0 * float(i),
			BLUE if i == 0 else INK
		)
	var lane := Rect2(x + 78.0, y, minf(b.size.x - 82.0, 90.0), b.size.y - 18.0)
	_canvas.draw_rect(lane, Color("d9b26b"))
	_canvas.draw_rect(Rect2(lane.position.x, lane.position.y, 3.0, lane.size.y), Color("5a3a22"))
	_canvas.draw_rect(Rect2(lane.end.x - 3.0, lane.position.y, 3.0, lane.size.y), Color("5a3a22"))
	var px := lane.position.x + lane.size.x * 0.5
	var idx := 0
	for row in 4:
		for k in row + 1:
			var standing: bool = idx < int(g.pins)
			var pos := Vector2(
				px + (float(k) - float(row) * 0.5) * 8.0, lane.position.y + 6.0 + float(row) * 7.0
			)
			_canvas.draw_rect(
				Rect2(pos - Vector2(2, 2), Vector2(4, 4)), WHITE if standing else Color("b8975a")
			)
			idx += 1
	if g.stage == "roll":
		var by := lane.end.y - 4.0 - (lane.size.y - 14.0) * float(g.ball)
		var bx := px + (float(g.marker) - 0.5) * lane.size.x * 0.5
		_canvas.draw_rect(Rect2(bx - 3.0, by - 3.0, 6.0, 6.0), INK)
	var bar_y := b.end.y - 8.0
	var bar := Rect2(x, bar_y, 70.0, 5.0)
	_canvas.draw_rect(bar, Color("c9d2e0"))
	if g.stage == "aim":
		_canvas.draw_rect(Rect2(bar.position.x + 28.0, bar_y, 14.0, 5.0), GREEN)
		_canvas.draw_rect(
			Rect2(bar.position.x + 69.0 * float(g.marker), bar_y - 2.0, 2.0, 9.0), INK
		)
		_t("AIM", x + 74.0 - 4.0, bar_y - 8.0, BLUE)
	elif g.stage == "power":
		_canvas.draw_rect(Rect2(bar.position.x + 52.0, bar_y, 12.0, 5.0), GREEN)
		_canvas.draw_rect(Rect2(bar.position.x, bar_y, 70.0 * float(g.power), 5.0), AMBER)
		_t("POWER", x + 74.0 - 4.0, bar_y - 8.0, BLUE)
	if str(g.msg) != "":
		_t(str(g.msg), x, bar_y - 8.0, RED if "GUTTER" in str(g.msg) else GREEN)


func _paint_karaoke(b: Rect2, hud := false) -> void:
	var x := b.position.x
	var y := b.position.y
	var top := y + (2.0 if hud else 18.0)
	if not hud:
		_t(("%s (%s)" % [str(g.song.title), str(g.song.genre)]).substr(0, 40), x, y, BLUE)
		_t("SCORE %d   STREAK %d" % [int(g.score), int(g.streak)], x, y + 8.0)
		_t("CROWD", b.end.x - 24.0, y + 8.0, UiStyle.MUTED)
	var line_y := b.end.y - 12.0
	var left := b.position.x + b.size.x * 0.5 - 40.0
	for lane in 4:
		var cx := left + 20.0 * float(lane) + 10.0
		_canvas.draw_rect(Rect2(cx - 9.0, top, 18.0, line_y + 6.0 - top), Color("dde3ee"))
		_arrow(lane, Vector2(cx, line_y), 5.0, Color(LANE_COLORS[lane], 0.45))
	for n in g.notes:
		var dy: float = (float(n.time) - float(g.t)) * float(g.get("speed", 45.0))
		if dy < -14.0 or dy > line_y - top + 4.0:
			continue
		var col: Color = LANE_COLORS[int(n.lane)]
		if n.state == "miss":
			col = Color("8a8f9a")
		elif n.state != "":
			col = Color(col, 0.35)
		_arrow(int(n.lane), Vector2(left + 20.0 * float(n.lane) + 10.0, line_y - dy), 5.0, col)
	if float(g.flash_t) > 0.0 and not hud:
		_tc(str(g.flash), left + 80.0 + 24.0, y + 30.0, GREEN if g.flash != "MISS" else RED)
	# the crowd: a bar that fills as they warm up (green when the whole room is singing)
	var bar := Rect2(b.end.x - 6.0, top, 4.0, line_y + 6.0 - top)
	var level := float(g.get("mood", 50.0)) / 100.0
	_canvas.draw_rect(bar, UiStyle.SOFT)
	_canvas.draw_rect(
		Rect2(bar.position.x, bar.end.y - bar.size.y * level, 4.0, bar.size.y * level),
		GREEN if level >= 0.6 else (AMBER if level >= 0.3 else RED)
	)
	var song := minf(1.0, float(g.t) / _song_secs())
	_canvas.draw_rect(Rect2(x, b.end.y - 4.0, b.size.x, 3.0), UiStyle.SOFT)
	_canvas.draw_rect(Rect2(x, b.end.y - 4.0, b.size.x * song, 3.0), BLUE)


func _paint_escape(b: Rect2) -> void:
	var x := b.position.x
	var y := b.position.y
	var n: int = g.code.size()
	_t(
		(
			"TIME %d   HINTS LEFT %d   TRIES %d OF 8"
			% [int(float(g.time)), int(g.hints), g.guesses.size()]
		),
		x,
		y,
		RED if float(g.time) < 20.0 else INK
	)
	var row := 0
	for entry in g.guesses:
		if row >= 8:
			break
		var digits := []
		for d in entry[0]:
			digits.append(str(int(d)))
		_t(
			"%s  B%d C%d" % [" ".join(PackedStringArray(digits)), int(entry[1]), int(entry[2])],
			x,
			y + 10.0 + 7.0 * float(row),
			INK
		)
		row += 1
	var bx := x + b.size.x - 20.0 * float(n) - 2.0
	for i in n:
		var r := Rect2(bx + 20.0 * float(i), y + 12.0, 16.0, 22.0)
		_canvas.draw_rect(r, WHITE)
		_canvas.draw_rect(
			Rect2(r.position.x, r.end.y - 2.0, 16.0, 2.0),
			BLUE if int(g.cursor) == i else Color("c9d2e0")
		)
		PixelFont.draw(
			_canvas,
			str(int(g.cur[i])),
			r.position + Vector2(5.0, 6.0),
			GREEN if g.revealed.has(i) else INK,
			2
		)
	_t("U/D CHANGE   L/R MOVE", minf(bx - 6.0, b.end.x - 87.0), y + 40.0, Color("46506a"))
	if str(g.msg) != "":
		for part in _wrap(str(g.msg), 18):
			_t(part, bx - 6.0, y + 50.0, BLUE)
			y += 7.0


func _paint_dinner(b: Rect2) -> void:
	var x := b.position.x
	var y := b.position.y
	_t("ROUND %d OF 5   TABLE SCORE %d" % [int(g.round), int(g.score)], x, y)
	for i in 4:
		var on: bool = int(g.sel) == i and g.react.is_empty()
		if on:
			_canvas.draw_rect(Rect2(x - 1.0, y + 9.0 + 9.0 * float(i), 82.0, 8.0), Color("ffe08a"))
		_t(str(g.options[i]), x + 2.0, y + 11.0 + 9.0 * float(i))
	var rx := x + 92.0
	var table := diners()
	for i in table.size():
		var who: String = table[i]
		var ry := y + 9.0 + 14.0 * float(i)
		_t(who.to_upper(), rx, ry, BLUE)
		var md: String = str(g.get("moods", {}).get(who, "easygoing"))
		var shift := int(DINNER_MOODS[md].shift)
		_t(
			str(DINNER_MOODS[md].face) + (" " + md.to_upper() if b.size.x >= 200.0 else ""),  # the word needs room
			rx + 60.0,
			ry,
			GREEN if shift > 0 else (RED if shift < 0 else UiStyle.MUTED)
		)
		if g.react.has(who):
			var mood: String = g.react[who]
			var face := "<3" if mood == "love" else (":(" if mood == "hate" else "OK")
			if g.get("hidden", []).has(who):
				face = "??"
				mood = "meh"
			_t(face, rx + 40.0, ry, GREEN if mood == "love" else (RED if mood == "hate" else INK))
		var entry: Dictionary = known.get(who, {"likes": [], "hates": []})
		var note := ""
		if not entry.likes.is_empty():
			note += "LIKES " + ", ".join(entry.likes)
		if not entry.hates.is_empty():
			note += ("  " if note != "" else "") + "NOT " + ", ".join(entry.hates)
		_t(note.substr(0, int((b.size.x - 92.0) / 4.0)), rx, ry + 7.0, Color("46506a"))
