extends CanvasLayer
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length,max-returns
# Team outings: four little mini-games the crew goes out for, if you choose to go.
#   BOWLING (timing: aim, then power), KARAOKE (rhythm: arrow keys), ESCAPE ROOM (a 3-digit code, bulls and cows,
#   teammates give hints), DINNER (conversation: learn what each person likes).
# Tech campaign: on days 5, 10 and 15 Garrison (the culture owner) asks at 16:00 (open tickets wait; you go home after). Owner campaign:
# weeks 4, 9, 14 and 19, and it costs money. Free Play: press O. Results (0-3 stars) change coworker opinions, energy
# (tech) and burnout (owner); skipping invitations costs a little goodwill. Everything is drawn in code.

signal finished(game: String, stars: int)

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const BowlVariety := preload("res://scripts/bowl_variety.gd")
const ChairRace := preload("res://scripts/chair_race.gd")
const ChairTrack := preload("res://scripts/chair_track.gd")
const CornholeGame := preload("res://scripts/cornhole_game.gd")
const GrillGame := preload("res://scripts/grill_game.gd")
const DartsGame := preload("res://scripts/darts_game.gd")
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
	"chair":
	{
		"label": "CHAIR RACE",
		"cost": 120,
		"blurb":
		"RACE THE CREW DOWN THE WAREHOUSE ON ROLLING OFFICE CHAIRS. UP AND DOWN CHANGE LANE, PUSH OFF WITH Z AND X IN TURN. A STEADY RHYTHM IS FAST, MASHING TIRES YOU OUT. CONES, SIGNS AND BOXES COST TIME.",
		"keys": "ARROWS = LANE  Z X = PUSH  ESC = LEAVE"
	},
	"cornhole":
	{
		"label": "CORNHOLE",
		"cost": 100,
		"blurb":
		"TOSS BAGS AT THE BOARDS IN THE WAREHOUSE AGAINST THE CREW. STOP THE AIM, THEN THE POWER. A HOLE IS 3, THE BOARD IS 1, BAGS CANCEL. FIRST TO THE TARGET WINS.",
		"keys": "E = STOP AIM / POWER  ESC = LEAVE"
	},
	"grill":
	{
		"label": "COOKOUT",
		"cost": 150,
		"blurb":
		"RUN THE BBQ GRILL IN THE WAREHOUSE DOCK. FLIP BURGERS AND HOT DOGS, SERVE EACH ORDER THE WAY IT WAS ASKED FOR AND DODGE THE FLARE-UPS.",
		"keys": "E = FLIP  SPACE = SERVE  SHIFT = COOL"
	},
	"darts":
	{
		"label": "DARTS",
		"cost": 0,
		"casual": true,
		"blurb":
		"A QUICK ROUND AT THE DART BOARD IN THE WAREHOUSE. A RETICLE DRIFTS OVER THE BOARD: PRESS E TO THROW AT IT. THREE DARTS A TURN, THREE ROUNDS, HIGHEST TOTAL WINS.",
		"keys": "E = THROW  ESC = LEAVE"
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
	"John":
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
# show = bonus when there is an audience of three or more (John), gutter = chance of a gutter ball, late = frames sat out
# at the start (Morgan joins the game late). A person without a row does not bowl.
const BOWLERS := {
	"Alan": {"skill": 0.62, "noise": 0.15, "streak": 0.0, "turkey": 0.0, "show": 0.0, "gutter": 0.0, "late": 0},
	"Garrison": {"skill": 0.55, "noise": 0.2, "streak": 0.14, "turkey": 0.0, "show": 0.0, "gutter": 0.0, "late": 0},
	"Dan": {"skill": 0.48, "noise": 0.4, "streak": 0.0, "turkey": 0.1, "show": 0.0, "gutter": 0.06, "late": 0},
	"John": {"skill": 0.5, "noise": 0.24, "streak": 0.0, "turkey": 0.0, "show": 0.12, "gutter": 0.05, "late": 0},
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
	{"Alan": "Seat1", "Garrison": "Seat3", "Dan": "Seat4", "John": "Seat5", "Maya": "Seat6", "Morgan": "Seat7"}
}
const PLAYER_SEAT := "Seat2"
const LANE_NEAR := [152.0, 252.0]
const LANE_FAR := [160.0, 244.0]
const MIC_X := 238.0
# the warehouse games (set x): you at cornhole board A, the opponent at board B (the boards are drawn by fx.gd, kinds cornhole_a /
# cornhole_b), the cook at the grill; the camera is lifted so the walkway shows above the HUD and panned to the middle of the action
const CORN_A := 1126.0
const CORN_B := 1274.0
const CORN_LIFT := 166.0
const CORN_PAN := 74.0
const GRILL_X := 1294.0
# darts: you throw from the line at DART_X (set x), the board hangs at DART_BOARD_X (the panel's board, fx kind dart_board); the others wait
# to the left of the line (DART_SPOTS) and the thrower of the turn steps up to it
const DART_X := 992.0
const DART_BOARD_X := 1046.0
const DART_SPOTS := [962.0, 938.0, 914.0, 890.0]
const DARTS_LIFT := 166.0
const DARTS_PAN := 10.0
const DARTS_MAX := 3  # opponents
const DARTS_ENERGY := 2  # a campaign round at the board: a little energy on the first two plays of a day
const DARTS_LEN := 0.25  # game hours a round takes in a campaign
const GRILL_LIFT := 182.0
const GRILL_PAN := -30.0
const ROOM_INTRO := {
	"bowling":
	"TAKE YOUR TURN ON THE LANE. PRESS E TO STEP UP, E TO STOP THE AIM, E AGAIN FOR POWER. ALAN, GARRISON AND DAN BOWL ON THE NEXT LANE. FIVE FRAMES.",
	"karaoke":
	"YOU ARE ON THE MIC. PICK A SONG, THEN HIT THE ARROW KEYS AS THE NOTES REACH THE LINE (BOTTOM LEFT). PERFECT HITS WARM UP THE CROWD, MISSES COOL IT DOWN.",
	"escape":
	"THE CODE IS HIDDEN IN THE ROOM. LOOK AT THE CHALKBOARD, THE CLOCK, THE PAINTING AND THE TRUNK (E), THEN ENTER THE CODE AT THE KEYPAD BY THE VAULT. N ASKS A FRIEND. THE CLOCK IS RUNNING.",
	"dinner":
	"WALK TO THE BOOTH AND SIT DOWN (E). THEN CHOOSE FIVE TOPICS FOR THE TABLE. EVERYONE HAS A MOOD TODAY, SO WATCH THEIR FACES.",
	"chair":
	"A RACE DOWN THE WAREHOUSE, START LINE TO FINISH LINE. UP AND DOWN CHANGE LANE TO DODGE THE CONES, SIGNS, BOXES AND OIL. PUSH OFF WITH Z AND X IN TURN: A STEADY RHYTHM IS FAST, MASHING TIRES YOU OUT. THE CREW RACES YOU.",
	"cornhole":
	"TWO BOARDS IN THE WAREHOUSE. YOU THROW AT THE FAR ONE, THE CREW MEMBER OF THE ROUND AT THE NEAR ONE, A BAG EACH IN TURN. E STOPS THE AIM, E AGAIN THE POWER: STOP IN THE GREEN FOR THE HOLE (3). THE BOARD IS 1. YOUR BAGS CANCEL THEIRS.",
	"darts":
	"THE DART BOARD IN THE WAREHOUSE. A RETICLE DRIFTS OVER THE BOARD AND E THROWS AT WHEREVER IT IS. IT SETTLES FOR A MOMENT AND THEN YOUR ARM TIRES, AND EVERY DART HAS A NEW SWEET SPOT. THE BULL IS 50, A TREBLE COUNTS THREE TIMES, A DOUBLE TWICE. THREE DARTS A TURN, THREE ROUNDS.",
	"grill":
	"THE CREW LINES UP AT THE GRILL. ARROWS PICK A PATTY, E FLIPS IT (EARLY IT STICKS, LATE IT CHARS), SPACE SERVES IT TO THE OLDEST ORDER THAT WANTS IT, SHIFT MOVES IT TO THE COOL SIDE DURING A FLARE-UP.",
}
const LANE_KEYS := [KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT]
const CHAIR_KEYS := [KEY_Z, KEY_X, KEY_UP, KEY_DOWN, KEY_W, KEY_S]  # the chair race (in the warehouse) takes these; the rest of the keys do nothing
const PAD_ARROWS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT}
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
		"holds": [0.15, 0.25, 0.35],
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
	"John":
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
# E3: the safe, the trunk and the globe can be read too; each look takes a couple of seconds off the clock and tells you nothing
const DEFAULT_HERRING_TEXT := {
	"herring_safe": "THE SAFE IS BOLTED SHUT. A STICKY NOTE SAYS: THE CODE IS NOT 1-2-3. SOMEBODY ALREADY TRIED.",
	"herring_trunk": "A TRUNK OF OLD CABLES AND ONE CHRISTMAS LIGHT. NO NUMBERS, ONLY KNOTS.",
	"herring_globe": "THE GLOBE HAS A PIN IN IT AND A TAG: NOT HERE. THE COUNTRY HAS A NUMBER OF ITS OWN.",
}
var HERRING_TEXT: Dictionary = DEFAULT_HERRING_TEXT.duplicate(true)
const HERRING_COST := 2.0  # seconds a look at one of them takes off the clock
const DEFAULT_GUESTS := {
	"Alan": {"comes": 0.9, "code": "AL", "line": "Alan has a thing tonight."},
	"Garrison": {"comes": 0.9, "code": "GA", "line": "Garrison is sitting this one out."},
	"Dan": {"comes": 0.8, "code": "DA", "line": "Dan has a thing tonight."},
	"John": {"comes": 0.65, "code": "VI", "line": "John is on a call with a client."},
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
		"hole": ["PRECISION. THAT IS THE WORD.", "RIGHT IN THE HOLE."],
		"miss": ["WIND. THERE IS WIND IN HERE.", "THE BOARD MOVED."],
		"cook": ["THAT IS A PROPER BURGER.", "NICE SEAR. I APPROVE."],
		"wait": ["I HAVE A MEETING IN TEN.", "IS THERE A TICKET SYSTEM HERE?"],
	},
	"Garrison":
	{
		"cheer": ["YES! DID YOU SEE THAT?", "THIS IS THE BEST NIGHT."],
		"groan": ["OH NO. OH NO NO.", "I BLAME THE SHOES."],
		"talk": ["I AM ON FIRE. OR NOT.", "THE NEXT ONE IS MINE."],
		"sing": ["WOO! SING IT!", "ENCORE! ENCORE!"],
		"hole": ["BAG IN! DID EVERYONE SEE?!", "THE CROWD GOES WILD."],
		"miss": ["THE BAG HAD A MIND OF ITS OWN.", "WE DO NOT SPEAK OF THAT ONE."],
		"cook": ["THIS IS THE BEST DAY EVER.", "A BURGER! IN THE WAREHOUSE!"],
		"wait": ["I AM SO HUNGRY RIGHT NOW.", "IS IT LUNCH YET? STILL LUNCH?"],
	},
	"Dan":
	{
		"cheer": ["THAT PIN HAD IT COMING.", "WHOA. DID I DO THAT?"],
		"groan": ["THE BALL HAS A MIND OF ITS OWN.", "THAT WAS A BAD CABLE RUN."],
		"talk": ["WATCH THIS ONE.", "I MIGHT GET A TURKEY."],
		"sing": ["NOT BAD AT ALL.", "I WOULD NOT TRY THAT."],
		"hole": ["I DID THAT ON PURPOSE.", "SEE? HOLE. SMALL HOLE."],
		"miss": ["THAT BAG WAS DEFECTIVE.", "TO BE FAIR, IT WAS A LONG WAY."],
		"cook": ["MEDIUM. EXACTLY AS FILED.", "NO TICKET NEEDED FOR THIS."],
		"wait": ["MY BURGER IS IN THE QUEUE.", "I FILED THIS ORDER TWICE."],
	},
	"John":
	{
		"cheer": ["I TOLD YOU. I TOLD EVERYONE.", "THAT IS A WINNING ROLL."],
		"groan": ["THE PINS WERE LOOSE.", "THAT DOES NOT COUNT, RIGHT?"],
		"talk": ["WATCH AND LEARN.", "I HAVE A GUY AT THIS ALLEY."],
		"sing": ["I KNEW YOU HAD IT!", "I HAVE A GUY FOR RECORDING."],
		"hole": ["TOLD YOU. I TOLD THE WHOLE ROOM.", "THAT IS HOW YOU CLOSE A DEAL."],
		"miss": ["LET'S CALL THAT A WARM-UP.", "THE BOARD IS TILTED, RIGHT?"],
		"cook": ["THIS BURGER IS A WIN WIN.", "I KNOW A GUY WHO COOKS. YOU."],
		"wait": ["I HAVE A CLIENT CALL SOON.", "CAN I EXPENSE WAITING?"],
	},
	"Maya":
	{
		"cheer": ["CLEAN HIT.", "RIGHT ON THE HEAD PIN."],
		"groan": ["ONE PIN. REALLY.", "I WAS A BIT LEFT."],
		"talk": ["I HAVE A PLAN FOR THIS ONE.", "AIM, THEN BREATHE."],
		"sing": ["THAT NOTE WAS PERFECT.", "OK, THAT WAS GOOD."],
		"hole": ["NICE AND CLEAN.", "RIGHT IN."],
		"miss": ["I AIMED A BIT LEFT.", "OK, NOT THAT ONE."],
		"cook": ["PERFECT. THANK YOU.", "THAT IS EXACTLY WHAT I ASKED FOR."],
		"wait": ["STILL WAITING, NO RUSH.", "I CAN COME BACK."],
	},
	"Morgan":
	{
		"cheer": ["NOT BAD. DO NOT TELL HR.", "ACCEPTABLE."],
		"groan": ["WELL. THAT HAPPENED.", "I AM ONLY HERE FOR THE SHOES."],
		"talk": ["I DO NOT BOWL. I JUST WIN.", "ONE FRAME BEHIND IS FINE."],
		"sing": ["THAT WAS FINE. GOOD, EVEN.", "I WILL ALLOW IT."],
		"hole": ["NOT BAD. DO NOT TELL HR.", "ACCEPTABLE."],
		"miss": ["WELL. THAT HAPPENED.", "I AM ONLY HERE FOR THE SNACKS."],
		"cook": ["IT IS FINE. IT IS GOOD, EVEN.", "I WILL ALLOW THIS BURGER."],
		"wait": ["I DO NOT WAIT. I ABSORB.", "TIMER IS RUNNING, YOU KNOW."],
	},
}
var CREW_LINES: Dictionary = DEFAULT_CREW_LINES.duplicate(true)
const DEFAULT_KARAOKE_TEXT := {"doubles": "DOUBLES NEED BOTH KEYS AT ONCE."}
var KARAOKE_TEXT: Dictionary = DEFAULT_KARAOKE_TEXT.duplicate(true)
const ROOMS := {
	"bowling": "bowling_alley",
	"karaoke": "karaoke_bar",
	"escape": "escape_room",
	"dinner": "restaurant",
	"chair": "warehouse",
	"cornhole": "warehouse",
	"grill": "warehouse",
	"darts": "warehouse"
}
# where Alan, Garrison, Dan, John, Maya and Morgan stand in each room (set-pixel x, World.CAST order: a person who is
# not there leaves their spot empty). The five standing spots are unchanged; the sixth is Morgan's.
const SPOTS := {
	"bowling": [114, 186, 214, 250, 140, 165],
	"karaoke": [236, 262, 282, 130, 160, 100],
	"escape": [118, 175, 205, 305, 325, 14],  # clear of the clue zones (shelf 52, clock 86, painting 149, board 238, keypad 276)
	"dinner": [34, 62, 106, 140, 175, 205],
	"chair": [1135, 1160, 1185, 1210, 1235, 1260],  # whoever is not racing watches from beyond the finish line
	"cornhole": [1096, 1080, 1064, 1048, 1032, 1016],  # the audience left of board A; the opponent of the round walks to board B
	"grill": [1262, 1230, 1198, 1166, 1134, 1102],  # the queue to the left of the cook, nearest first
	"darts": [962, 938, 914, 890, 866, 842],  # waiting their turn left of the throw line
}
const TECH_DAYS := [5, 10, 15]
# the lunch break (R29): days (weeks in the owner campaign) with a midday cookout or cornhole in the warehouse, between 12:00 and
# 13:30 on the clock, taking LUNCH_LEN hours; Cozy Easy offers it every day that has no evening outing and ages no ticket
const LUNCH_TECH := [3, 7, 12, 17]
const LUNCH_OWNER := [2, 7, 12, 17]
const LUNCH_FROM := 12.0
const LUNCH_UNTIL := 13.5
const LUNCH_LEN := 0.75
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
var chair_best := {}  # chair race: best time in seconds per difficulty tier
var league: Dictionary = BowlVariety.new_league()  # bowling: the league season in progress (B5)
var party: Array = []  # who was invited tonight, in priority order (draw_party)
var stayed: Array = []  # roster members who did not come
var party_set := false
var guest_client := -1  # owner campaign (R5): the client John brings along tonight (a client index), -1 for nobody

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
var lunches := 0  # lunch breaks taken (a campaign's midday cookout or cornhole, R29)
var lunch_skips := 0
var _lunch_offered := false  # today's lunch card has been shown (saved in the resume point)
var darts_plays := 0  # casual rounds at the dart board (saved)
var darts_day := -1  # the campaign day of darts_today
var darts_today := 0  # rounds played on darts_day: the first two give energy, the first the coworkers' goodwill


func _ready() -> void:
	layer = 66
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)
	Campaign.day_started.connect(
		func(_d: int) -> void:
			_offered = false
			_lunch_offered = false
	)
	reset()


func reset() -> void:
	count = 0
	skipped = 0
	best = {}
	known = {}
	tastes = {}
	song_best = {}
	chair_best = {}
	league = BowlVariety.new_league()
	_offered = false
	_lunch_offered = false
	lunches = 0
	lunch_skips = 0
	darts_plays = 0
	darts_day = -1
	darts_today = 0


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
		"league": league,
		"chair": chair_best,
		"lunches": lunches,
		"lunch_skips": lunch_skips,
		"darts_plays": darts_plays,
		"darts_day": darts_day,
		"darts_today": darts_today,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	count = int(data.get("count", 0))
	skipped = int(data.get("skipped", 0))
	best = data.get("best", {})
	known = data.get("known", {})
	song_best = data.get("songs", {})
	chair_best = data.get("chair", {})
	lunches = int(data.get("lunches", 0))
	lunch_skips = int(data.get("lunch_skips", 0))
	darts_plays = int(data.get("darts_plays", 0))
	darts_day = int(data.get("darts_day", -1))
	darts_today = int(data.get("darts_today", 0))
	league = BowlVariety.new_league()
	for key in data.get("league", {}):
		league[key] = data.league[key]
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
	guest_client = -1
	if Campaign.mode == "owner" and party.has("John") and not Sales.active.is_empty():
		var rg := Difficulty.rng_for("outings.guest", count)  # its own stream, so the party draw above keeps its numbers
		guest_client = int(Sales.active[rg.randi() % Sales.active.size()])
	return party


# "Coming: Alan, Dan and John. Garrison is sitting this one out." (the invitation card)
func coming_text() -> String:
	if not party_set:
		draw_party()
	var text := "Coming: %s." % join_names(_by_cast(party), false)
	if not stayed.is_empty():
		text += " " + str(GUESTS.get(stayed[0], {}).get("line", "%s cannot make it." % stayed[0]))
	if guest_client >= 0:
		var cl: Dictionary = Msp.CLIENTS[guest_client]
		text += " John is bringing %s (%s)." % [str(cl.contact), str(cl.name)]
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


# the karaoke audience: the party, or (no invitation) the table plus John as before
func crowd() -> Array:
	if opts.has("party"):
		return present()
	var out := diners()
	if roster().has("John"):
		out.append("John")
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
			{"label": "YES, LET'S GO", "id": "yes"},
			{"label": "NOT TONIGHT", "id": "no"},
		],
		func(id: String) -> void: _invite_answer(id)
	)


# ---- the lunch break (R29) -----------------------------------------------------------------------------------------------
func lunch_day() -> bool:
	if not Campaign.active or Campaign.mode == "sales" or invite_day():
		return false
	if Difficulty.cozy_on():
		return true
	return (LUNCH_OWNER if Campaign.mode == "owner" else LUNCH_TECH).has(Campaign.day)


# a lunch break is playing (or was the last thing played): the options of the outing carry `lunch`
func lunch_on() -> bool:
	return bool(opts.get("lunch", false))


func lunch_due() -> bool:
	if not enabled or _lunch_offered or is_open or busy() or Cards.is_open or Cards.waiting() > 0 or Game.title_mode or Game.busy:
		return false
	if World.time_scale <= 0.0 or Story.overtime or Onsite.busy or Onsite.active or Net.carrying != "" or Playbook.is_active():
		return false
	if Expo.away or Expo.is_trip_day(Campaign.day) or not lunch_day():
		return false
	return World.clock >= LUNCH_FROM and World.clock < LUNCH_UNTIL


func maybe_lunch() -> void:
	if not lunch_due():
		return
	_lunch_offered = true
	party_set = false
	draw_party()
	var text := "It is lunch time and the grill is going in the warehouse dock, with the cornhole boards out. A short break, about an hour on the clock, and nobody will mind if you skip it."
	if Difficulty.cozy_on():
		text += " Nothing in the queue will mind either."
	if Campaign.mode == "owner":
		text += " Lunch is on the company."
	text += " " + coming_text()
	Cards.ask(
		_host(),
		text,
		[
			{"label": "COOKOUT: BURGERS AND DOGS", "id": "grill"},
			{"label": "CORNHOLE", "id": "cornhole"},
			{"label": "SKIP LUNCH", "id": "no"},
		],
		func(id: String) -> void: _lunch_answer(id)
	)


func _lunch_answer(id: String) -> void:
	if id == "no":
		lunch_skips += 1
		return
	for n in World.chars:  # nobody walks off to eat again
		World.chars[n].lunched = true
	start(id, false, {"party": party.duplicate(), "lunch": true})


# back at work: the break took LUNCH_LEN hours (the queue aged at half the onsite rate, not at all on Cozy Easy)
func _lunch_after() -> void:
	if stars >= 0:
		lunches += 1
	World.clock = minf(World.DAY_END - 0.25, World.clock + LUNCH_LEN)
	if not Difficulty.cozy_on():
		var scale := World.day_len / 600.0
		for t in Msp.tickets:
			if t.status != "Closed":
				t.sla_left = maxf(float(t.sla_total) * 0.35, float(t.sla_left) - LUNCH_LEN * Onsite.SLA_PER_HOUR * 0.5 * scale)
	Hints.toast("BACK FROM LUNCH. THE QUEUE WAITED." if Difficulty.cozy_on() else "BACK FROM LUNCH. THE QUEUE KEPT TICKING A LITTLE.", 3.0)


# the owner pays for the night: "$120 TO $300" (shown on the invitation before the game pick)
func cost_range() -> String:
	var lo := 100000
	var hi := 0
	for id in GAMES:
		if GAMES[id].get("casual", false):
			continue
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
		if GAMES[id].get("casual", false):
			continue  # the dart board is its own thing (E at the board), not an evening out
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
		"Where to? Bowling is easy, karaoke is risky, the escape room needs teamwork, dinner needs good conversation, the chair race needs a steady rhythm, cornhole is a friendly toss and the cookout is a rush of orders.",
		options,
		func(id: String) -> void: start(id, from_invite, _game_options(id))
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
				{"label": "LET'S GO", "id": "yes"},
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
	if GAMES.get(id, {}).get("casual", false):
		opts["casual"] = true  # the dart board is a casual game whoever starts it (the toolbox, a test)
	if Difficulty.fixed_take:
		Difficulty.take_reset()
	var here := get_tree().current_scene
	var in_room := use_rooms and not bool(opts.get("panel", false))
	if in_room and ROOMS.has(id) and here != null and not Game.title_mode:
		_return_scene = here.scene_file_path.get_file().get_basename()
		var me := Players.player0(here)
		_return_x = me.global_position.x if me != null else -1.0
		_traveled = true
		_wait_id = id
		_from_invite = from_invite
		var away := []
		if opts.has("party"):  # whoever did not come stays out of the building
			away = roster().filter(func(n: String) -> bool: return not opts.party.has(n))
		if id == "chair":  # the racers are puppets on the floor, the rest of the party watches from the finish line
			away.append_array(racers().filter(func(n: String) -> bool: return not away.has(n)))
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
	if Campaign.mode == "owner" and not lunch_on() and not casual_on():
		Owner.cash -= int(GAMES[id].cost)
	if id == "chair":
		_chair_setup()
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
		"cornhole":
			_corn_setup()
		"grill":
			_grill_setup()
		"darts":
			_darts_setup()
		"chair":
			_chair_door(true)  # set up when the page opened: the race is on the floor, the countdown starts now
		_:
			_dinner_setup()
	if room_mode():
		_room_begin()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_chair_clear()
	_reset_camera()
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
	if lunch_on() and Campaign.active:
		_lunch_after()
	if casual_on() and Campaign.active and stars >= 0:
		_casual_after()
	_traveled = false
	_peek = false
	opts["lunch"] = false
	opts["casual"] = false
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
	maybe_lunch()


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
		"chair":
			_chair_tick(dt)
		"cornhole":
			_corn_tick(dt)
		"grill":
			_grill_tick(dt)
		"darts":
			_darts_tick(dt)
		_:
			_dinner_tick(dt)


func _input(event: InputEvent) -> void:
	if is_open and game == "karaoke" and phase == "play" and event is InputEventKey and not event.pressed:
		_kara_release(event.keycode)  # K2: hold notes
		return
	if not is_open or not Controls.pressed(event):
		return
	var key := _event_key(event)
	if key == KEY_NONE:
		return
	if Cards.is_open:
		return  # a card (song, budget) has the keys
	if room_mode() and phase == "play" and not _room_wants(key):
		return  # in the room you keep walking around
	press(key)
	get_viewport().set_input_as_handled()


# the key code the game logic works on: a key is itself, a pad button or action is the key it stands for
# (D-pad or stick = the arrows, A = Enter, X = E, B = Esc; in the chair race A and B are the two pushes, Z and X)
func _event_key(event: InputEvent) -> int:
	if event is InputEventKey:
		return event.keycode
	var racing: bool = game == "chair" and phase == "play"
	var grilling: bool = game == "grill" and phase == "play"
	var dir := Controls.nav(event, false)
	var key := KEY_NONE
	if racing and Controls.matches(event, "push_a"):
		key = KEY_Z
	elif racing and Controls.matches(event, "push_b"):
		key = KEY_X
	elif grilling and Controls.matches(event, "run"):
		key = KEY_SHIFT  # B on a pad: the cool side
	elif dir != "":
		key = PAD_ARROWS[dir]
	elif Controls.back(event):
		key = KEY_ESCAPE
	elif Controls.matches(event, "interact"):
		key = KEY_E
	elif Controls.confirm(event):
		key = KEY_ENTER
	return key


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
		elif use_rooms and game == "bowling" and Campaign.active and not opts.get("alley_picked", false):
			ask_alley()  # R11: tonight's draw is the suggestion, the card lets you pick the lanes
		elif use_rooms and game == "dinner" and Campaign.mode == "owner":
			ask_budget()
		else:
			begin_play()
	elif key == KEY_ESCAPE:
		if Campaign.mode == "owner" and not lunch_on() and not casual_on():
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
		"chair":
			_chair_press(key)
		"cornhole":
			_corn_press(key)
		"grill":
			_grill_press(key)
		"darts":
			_darts_press(key)
		_:
			_dinner_press(key)


# the mastery ramp on the result page: one short line after a good play (2+ stars). Dinner has no skill-check numbers to ramp.
func _mastery_lines(result: int) -> Array:
	if result < 2 or game == "dinner" or Difficulty.fixed_take:
		return []
	var n := mini(int(Career.value("good." + game)), Difficulty.RAMP_PLAYS)
	if n >= Difficulty.RAMP_PLAYS:
		return ["FULL MASTERY."]
	return ["MASTERY %d/%d. SHARPER NEXT TIME." % [n, Difficulty.RAMP_PLAYS]]


# stars: 0-3, or -1 when you left early
func _finish(result: int) -> void:
	stars = result
	phase = "result"
	lines = []
	if result < 0 and casual_on():
		lines.append("YOU PUT THE DARTS BACK. NOBODY MINDS.")
	elif result < 0 and lunch_on():
		lines.append("YOU HEAD BACK TO YOUR DESK. NOBODY MINDS A SHORT LUNCH.")
	elif result < 0:
		lines.append("YOU LEFT EARLY. NOBODY SAYS ANYTHING. EVERYBODY NOTICES.")
		Social.change_all(-1)
	elif casual_on():
		_darts_finish(result)
	else:
		count += 1
		best[game] = maxi(int(best.get(game, 0)), result)
		Career.note_outing(
			game,
			result,
			{
				"perfects": int(g.get("perfect", 0)),
				"secs": roundi(Difficulty.f("escape.time") - float(g.get("time", 0.0))),
				"score": int(g.get("score", 0)),
				"holes": int(g.game.holes) if game == "cornhole" and g.has("game") else 0,
				"served": int(g.game.served) if game == "grill" and g.has("game") else 0,
				"clean": game == "grill" and g.has("game") and int(g.game.burnt) == 0 and result >= 2,
				"dogs": int(g.game.dogs_plated) if game == "grill" and g.has("game") else 0,
				"lunch": lunch_on()
			}
		)
		var liking := (2 if result >= 3 else 1) if lunch_on() else 1 + result
		Social.change_all(liking)
		if guest_client >= 0 and Campaign.mode == "owner":  # R5: John's client had a good evening
			Sales.adjust(guest_client, 2 + result)
			lines.append("%s ENJOYED THE EVENING. (CLIENT MOOD +%d)" % [str(Msp.CLIENTS[guest_client].contact).to_upper(), 2 + result])
			guest_client = -1
		if game == "chair":
			lines.append_array(_chair_lines())
		if game == "cornhole":
			lines.append_array(_corn_lines())
		if game == "grill":
			lines.append_array(_grill_lines())
		if Campaign.mode == "sales":
			lines.append_array(SalesCampaign.outing_done(game, result))
		if Campaign.active:
			lines.append("EVERYONE ON THE TEAM LIKES YOU %d MORE." % liking)
		else:
			lines.append("A GOOD NIGHT OUT. (FREE PLAY: NOTHING IS SCORED.)")
		lines.append_array(_mastery_lines(result))
		if Campaign.mode == "owner":
			var relief := (2.0 + float(result)) if lunch_on() else 5.0 + 3.0 * float(result)
			Owner.burnout = clampf(Owner.burnout - relief, 0.0, 100.0)
			Owner.flags["outings"] = int(Owner.flags.get("outings", 0)) + 1
			lines.append("BURNOUT DOWN %d POINTS. THE CREW FEELS SEEN." % int(relief))
			if game == "escape" and result >= 2:
				Owner.speed += 0.02
				lines.append("THEY WORK BETTER TOGETHER NOW: TEAM SPEED UP.")
		elif Campaign.active and Campaign.mode != "sales":
			var gain := (2.0 + float(result)) if lunch_on() else 4.0 + 2.0 * float(result)
			Shift.add_energy(gain)
			lines.append("ENERGY +%d. %s" % [int(gain), "A GOOD LUNCH HELPS." if lunch_on() else "A NIGHT OUT HELPS."])
		if result >= 3 and not lunch_on():
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
		"alley": str(opts.get("alley", "strike_zone")),
		"spin": 0,
		"acc": 1.0,
		"hcp": _league_hcp(str(opts.get("alley", "strike_zone"))),
	}
	_bowl_zone_roll()
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
	if key in [KEY_LEFT, KEY_RIGHT] and str(g.get("stage", "")) in ["aim", "power"]:
		var want := -1 if key == KEY_LEFT else 1
		g.spin = 0 if int(g.get("spin", 0)) == want else want
		caption(
			(
				"NO HOOK. THE GREEN ZONE IS BACK."
				if int(g.spin) == 0
				else "HOOK %s: THE GREEN ZONE MOVES. A WILD HOOK CAN GO OFF THE LANE." % ("LEFT" if want < 0 else "RIGHT")
			),
			99.0
		)
		return
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
		_bowl_zone_roll()
		caption("PRESS E TO STOP THE AIM IN THE GREEN. ARROWS = HOOK.", 99.0)
	elif g.stage == "aim":
		g.stage = "power"
		g.power = 0.0
		g.dir = 1.0
		caption("PRESS E TO STOP THE POWER (STOP IN THE GREEN).", 99.0)
	elif g.stage == "power":
		g.stage = "roll"
		g.ball = 0.0
		Sfx.play("bowl_roll")
		caption("WAIT. THE BALL IS ROLLING.", 3.0)
		var p := _actor("Player")
		if p != null:
			p.start_emote("reach", 0.8)


func bowl_strength() -> float:
	var spin := int(g.get("spin", 0))
	var accuracy := BowlVariety.accuracy(oil_id(), float(g.marker), spin, Difficulty.f("bowl.oil"), float(g.get("shift", 0.0)))
	g.acc = accuracy
	var quality := clampf(1.0 - absf(float(g.power) - float(g.get("pcen", 0.85))) / 0.85, 0.0, 1.0)
	var span := 0.08 + BowlVariety.HOOK_NOISE * absf(float(spin)) * Difficulty.f("bowl.spin_noise")
	var noise := Difficulty.rng("bowl").randf_range(-span, span)
	return clampf(accuracy * 0.6 + quality * 0.4 + noise, 0.0, 1.0)


func _bowl_resolve() -> void:
	var strength := bowl_strength()
	var left := int(g.pins)
	var knocked := (
		left
		if strength > 0.92
		else clampi(roundi(float(left) * minf(1.0, strength * 1.15)), 0, left)
	)
	knocked = _hook_adjust(knocked, left, strength)
	g.knocked = knocked
	g.pins = left - knocked
	g.totals["You"] = int(g.totals["You"]) + knocked
	Career.note_bowl(knocked, int(g.roll))
	_note_hook(knocked)
	if knocked == 10 and int(g.roll) == 1:
		g.totals["You"] = int(g.totals["You"]) + 3
		g.msg = "STRIKE!"
		Sfx.play("bowl_strike")
	elif int(g.pins) == 0:
		g.msg = "SPARE!"
	elif knocked == 0:
		g.msg = "GUTTER BALL..."
	else:
		g.msg = "%d PINS" % knocked
	g.stage = "pause"
	g.wait = 1.4 if room_mode() else 1.1
	if str(g.get("hook_msg", "")) != "":
		g.msg = str(g.hook_msg)
	g.erase("hook_msg")
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
	skill += BowlVariety.fit(oil_id(), who)
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
		_bowl_zone_roll()
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
	_bowl_zone_roll()
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


# ---- oil, hook and league (R11; the tables are in bowl_variety.gd)
func alley_id() -> String:
	return str(g.get("alley", "strike_zone"))


func oil_id() -> String:
	return str(BowlVariety.alley(alley_id()).oil)


func is_league() -> bool:
	return bool(BowlVariety.alley(alley_id()).league)


# where the green zone sits on the aim bar (0..1) and how wide it is
func bowl_center() -> float:
	return BowlVariety.center(oil_id(), int(g.get("spin", 0)), float(g.get("shift", 0.0)))


# the green zones move: every roll draws a new aim shift and a new power centre (stream "bowl_zone"; Free Play fixed takes repeat)
const ZONE_SHIFT := 0.12
const POWER_ZONE := [0.62, 0.9]  # where the power bar's best point can sit (0.85 was the old fixed one)


func _bowl_zone_roll() -> void:
	g.shift = Difficulty.zone("bowl", -ZONE_SHIFT, ZONE_SHIFT)
	g.pcen = Difficulty.zone("bowl", POWER_ZONE[0], POWER_ZONE[1])


func bowl_zone_width() -> float:
	return 0.2 / (float(BowlVariety.oil(oil_id()).width) * Difficulty.f("bowl.oil"))


func _aim_label() -> String:
	var s := int(g.get("spin", 0))
	return "AIM" if s == 0 else ("HOOK L" if s < 0 else "HOOK R")


func _league_hcp(alley: String) -> Dictionary:
	var out := {}
	if not bool(BowlVariety.alley(alley).league):
		return out
	for who in ["You"] + bowlers():
		out[who] = BowlVariety.handicap(league, str(who))
	return out


# a hook thrown far from the green zone sweeps off the lane; a hook that lands well carries the pins
func _hook_adjust(knocked: int, left: int, strength: float) -> int:
	if int(g.get("spin", 0)) == 0:
		return knocked
	if float(g.get("acc", 1.0)) < BowlVariety.GUTTER_ACC:
		g["hook_msg"] = "HOOKED OFF THE LANE..."
		return 0
	if strength > 0.92 - BowlVariety.HOOK_STRIKE:
		return left
	return knocked


func _note_hook(knocked: int) -> void:
	if int(g.get("spin", 0)) != 0:
		Career.add("bowl_hooks")
		if knocked >= 10 and int(g.roll) == 1:
			Career.add("bowl_hook_strikes")
	g.spin = 0


# score used for the rank: pins plus the league handicap (nothing on an ordinary night)
func _bowl_adj(who: String) -> int:
	return int(g.totals[who]) + int(g.get("hcp", {}).get(who, 0))


func _league_close() -> void:
	Career.note_alley(alley_id())
	if not is_league():
		return
	var scores := {}
	for who in g.totals:
		scores[who] = int(g.totals[who])
	var res := BowlVariety.record(league, scores)
	var place := 1
	for who in g.totals:
		if who != "You" and int(res.adjusted[who]) > int(res.adjusted["You"]):
			place += 1
	var places := ["1ST", "2ND", "3RD", "4TH", "5TH", "6TH"]
	Career.add("league_nights")
	lines.append(
		"LEAGUE NIGHT %d OF %d: YOU PLACE %s WITH HANDICAPS." % [int(res.night), BowlVariety.LEAGUE_NIGHTS, places[mini(place - 1, 5)]]
	)
	if bool(res.done):
		Career.add("league_seasons")
		if str(res.winner) == "You":
			Career.add("league_titles")
			lines.append("THE SEASON IS OVER. YOU WIN THE LEAGUE! THEY GIVE YOU A SMALL TROPHY.")
		else:
			lines.append("THE SEASON IS OVER. %s WINS THE LEAGUE. SEE YOU NEXT SEASON." % str(res.winner).to_upper())


# the alley for tonight: a seeded draw (a season in progress pulls people to league night)
func _game_options(id: String) -> Dictionary:
	var o := {"party": party.duplicate()}
	if id == "bowling":
		o["alley"] = BowlVariety.pick_alley(Difficulty.rng_for("alley", count * 7 + int(league.night)), int(league.night))
	return o


func _paint_bowl_intro(b: Rect2, y0: float) -> float:
	var y := y0
	var alley := BowlVariety.alley(str(opts.get("alley", "strike_zone")))
	var oil := BowlVariety.oil(str(alley.oil))
	var texts := ["ALLEY: " + str(alley.label), str(alley.line), str(oil.line), "LEFT / RIGHT = HOOK (MORE CARRY, MORE RISK)."]
	if bool(alley.league):
		texts.append("LEAGUE: NIGHT %d OF %d. HANDICAPS COUNT FOR THE RANK." % [int(league.night) + 1, BowlVariety.LEAGUE_NIGHTS])
	for text in texts:
		for part in _wrap(text, int(b.size.x / 4.0)):
			_t(part, b.position.x, y, BLUE if text == texts[0] else INK)
			y += 7.0
	return y + 2.0
func bowl_rank() -> int:
	var rank := 0
	for who in bowlers():
		if _bowl_adj(who) > _bowl_adj("You"):
			rank += 1
	return rank


func _bowl_end() -> void:
	_finish([3, 2, 1, 1, 1][mini(bowl_rank(), 4)])
	_league_close()


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


# the one-line warning for songs with two arrows on one beat ("" when there are none): hard always has them
func kara_warning(song_id := "") -> String:
	var idx := maxi(0, Difficulty.TIERS.find(Difficulty.tier))
	if Difficulty.tier == "hard":
		return str(KARAOKE_TEXT.doubles)
	for song in SONGS:
		if (song_id == "" or str(song.id) == song_id) and float(song.doubles[idx]) > 0.0:
			return str(KARAOKE_TEXT.doubles)
	return ""


# R11: which lanes tonight; the seeded draw is marked as the pick of the evening and is what you get in the toolbox and in tests
func ask_alley() -> void:
	var options := []
	for id in BowlVariety.ALLEY_ORDER:
		var a: Dictionary = BowlVariety.alley(str(id))
		options.append({"label": str(a.short) + ("  (TONIGHT'S PICK)" if str(id) == str(opts.get("alley", "strike_zone")) else ""), "id": str(id)})
	var tonight: Dictionary = BowlVariety.alley(str(opts.get("alley", "strike_zone")))
	Cards.ask(
		"Bowling alley",
		"Where to? Each place oils its lanes differently. " + str(tonight.line),
		options,
		func(id: String) -> void:
			opts["alley"] = id
			opts["alley_picked"] = true
			begin_play()
	)


func ask_song() -> void:
	var warn := kara_warning()
	Cards.ask(
		"Karaoke host",
		"Step up to the mic. Which song?" + ((" " + warn) if warn != "" else ""),
		song_options(),
		func(id: String) -> void: begin_play(id)
	)


# ---- karaoke ------------------------------------------------------------------------------------
# the chart of one song at one tier: {notes, gap, span, speed}. Pure given the generator, so tests can
# build the same chart twice. Doubles put a second arrow in another lane on the same beat.
func kara_chart(song: Dictionary, tier: String, r: RandomNumberGenerator) -> Dictionary:
	var gap := float(song.gap) * Difficulty.mastery_blend("karaoke.gap", tier) / 0.75
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
		var note := {"lane": lane, "time": t, "state": ""}
		var hold_chance := float((song.get("holds", [0.0, 0.0, 0.0]) as Array)[maxi(0, Difficulty.TIERS.find(tier))])
		if hold_chance > 0.0 and r.randf() < hold_chance:  # K2: a long note, held until it ends
			note["len"] = snappedf(gap * float(rhythm[i % rhythm.size()]) * 0.7, 0.05)
		notes.append(note)
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
		"pager_at": _pager_time(float(chart.span)),
		"paged": false,
	}
	_assign_duet()


# K5: a friend from the party takes the two right lanes (a duet): their notes are resolved for them by a skill roll
const DUET_LANES := 2  # lanes from this one up are the partner's
const DUET_ODDS := [0.55, 0.30]  # perfect, then good; the rest are misses


func _duet_partner() -> String:
	for who in present():
		if Social.is_friendly(str(who)):
			return str(who)
	return ""


func _assign_duet() -> void:
	_assign_duet_with(_duet_partner())


func _assign_duet_with(who: String) -> void:
	if who == "":
		return
	g["partner"] = who
	for n in g.notes:
		if int(n.lane) >= DUET_LANES:
			n["auto"] = true


# the partner's notes come due: perfect, good or miss by their roll (a miss cools the crowd a little but never breaks your streak)
func _duet_tick() -> void:
	for n in g.notes:
		if n.state != "" or not n.get("auto", false) or float(n.time) > float(g.t):
			continue
		var roll := Difficulty.rng("karaoke.duet").randf()
		if roll < float(DUET_ODDS[0]):
			n.state = "perfect"
			g.score = int(g.score) + 2
			g.perfect = int(g.perfect) + 1
			_mood_add(2.0)
		elif roll < float(DUET_ODDS[0]) + float(DUET_ODDS[1]):
			n.state = "good"
			g.score = int(g.score) + 1
			g.good = int(g.good) + 1
			_mood_add(1.0)
		else:
			n.state = "miss"
			g.miss = int(g.miss) + 1
			_mood_add(-3.0)


# K8: on a call week a pager chime can go off mid-song (a quarter of the songs). Ignoring it costs nothing: the call waits in your queue afterwards.
const PAGER_CHANCE := 0.25


func _pager_time(span: float) -> float:
	if not Shift.is_on_call():
		return -1.0
	var r := Difficulty.rng("karaoke.pager")
	if r.randf() >= PAGER_CHANCE:
		return -1.0
	return span * r.randf_range(0.25, 0.7)


func _kara_tick(dt: float) -> void:
	if g.get("wait", false):
		return
	g.t = float(g.t) + dt
	g.flash_t = maxf(0.0, float(g.flash_t) - dt)
	if float(g.get("pager_at", -1.0)) > 0.0 and not g.get("paged", false) and float(g.t) >= float(g.pager_at):
		g.paged = true
		g.flash = "PAGER! IT CAN WAIT FOR THE SONG"
		g.flash_t = 2.0
		Sfx.play("text")
	_duet_tick()
	var held: Dictionary = g.get("held", {})
	for lane in held.keys():
		var hn: Dictionary = held[lane].note
		if float(g.t) >= float(hn.time) + float(hn.len):
			held.erase(lane)  # held to the end
	for n in g.notes:
		if n.state == "" and float(n.time) + _good_win() < float(g.t):
			n.state = "miss"
			g.miss = int(g.miss) + 1
			g.streak = 0
			_streak_broken()
			_mood_add(-_miss_drain(int(g.miss)))
			g.flash = "MISS"
			g.flash_t = 0.5
	if float(g.mood) <= 0.0:
		g.msg = "THE ROOM LAUGHS AND HEADS BACK TO THE BAR. GOOD TRY!"
		_kara_end()
	elif float(g.t) > _song_secs() + 0.6:
		_kara_end()


# the crowd cools by 6 per missed note; on hard the first two misses of a song cost 3 (Difficulty karaoke.grace / grace_drain)
func _miss_drain(nth: int) -> float:
	if nth <= Difficulty.i("karaoke.grace"):
		return Difficulty.f("karaoke.grace_drain")
	return 6.0


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


# K2: the key came up: a perfect hold let go before its end is only a good
func _kara_release(key: int) -> void:
	var lane := LANE_KEYS.find(key)
	var held: Dictionary = g.get("held", {})
	if lane < 0 or not held.has(lane):
		return
	var h: Dictionary = held[lane]
	held.erase(lane)
	var note: Dictionary = h.note
	if float(g.t) < float(note.time) + float(note.len) - 0.2:
		g.flash = "LET GO EARLY"
		g.flash_t = 0.6
		if bool(h.perfect):
			note.state = "good"
			g.score = int(g.score) - 1
			g.perfect = int(g.perfect) - 1
			g.good = int(g.good) + 1


func _kara_press(key: int) -> void:
	var lane := LANE_KEYS.find(key)
	if lane < 0:
		return
	kara_hit(lane)


func kara_hit(lane: int) -> String:
	if g.get("wait", false):
		return ""
	var pick: Dictionary = {}
	var gap := 9.0
	for n in g.notes:
		if n.state == "" and not n.get("auto", false) and int(n.lane) == lane and absf(float(n.time) - float(g.t)) < gap:
			gap = absf(float(n.time) - float(g.t))
			pick = n
	if pick.is_empty() or gap > _good_win():
		g.streak = 0
		_streak_broken()
		Sfx.play("ui_error")
		_mood_add(-2.0)
		return ""
	var perfect := gap <= float(g.get("perfect_win", 0.12))
	pick.state = "perfect" if perfect else "good"
	if float(pick.get("len", 0.0)) > 0.0:  # a hold note: keep the key down until it ends or the perfect turns into a good
		var held: Dictionary = g.get("held", {})
		held[lane] = {"note": pick, "perfect": perfect}
		g["held"] = held
	Sfx.play("kara_perfect" if perfect else "kara_good")
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
	if g.get("paged", false):  # the page you ignored is waiting as a ticket, and nobody minds
		var t: Dictionary = Msp._random_ticket("pager")
		Msp.send_text("Boss", "Your pager went off during the song. A client is waiting: it is in your queue%s." % ((" (#%d)" % int(t.id)) if not t.is_empty() else ""))
	if g.get("encore", false):
		result = (int(g.first) + result + 1) >> 1  # the night's stars are the two songs averaged, half rounded up
	elif _set_break(result):
		return
	_finish(result)


# K6: in the owner campaign a karaoke night is a two song set with a decision at the bar between them
const SET_TAB := 80  # a round for the room


func _set_break(first: int) -> bool:
	if not Campaign.active or Campaign.mode != "owner" or opts.has("song") or g.get("encore", false):
		return false
	g["wait"] = true  # the song is over: nothing ticks while the bar tab card is up
	var tab := SET_TAB
	Cards.ask(
		"The bar",
		"One song down. The room is warm, the second is yours if you want it. A round on you before it starts would not hurt.",
		[
			{"label": "BUY A ROUND (%s)" % Owner.money(tab), "id": "round", "enabled": Owner.cash >= tab},
			{"label": "KEEP IT MOVING", "id": "skip"},
			{"label": "CALL IT A NIGHT", "id": "stop"},
		],
		func(id: String) -> void: _set_next(id, first, tab)
	)
	return true


func _set_next(id: String, first: int, tab: int) -> void:
	if id == "stop" or id == "__none":
		_finish(first)
		return
	var warm := 50.0
	if id == "round":
		Owner.cash -= tab
		warm = 80.0
	var prev := str(g.song.id) if g.has("song") else ""
	var next := prev
	for song in SONGS:
		if str(song.id) != prev and song_unlocked(str(song.id)):
			next = str(song.id)
			break
	_kara_setup(next)
	g["encore"] = true
	g["first"] = first
	g["mood"] = warm


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
	var cost := Difficulty.f("escape.hint_penalty")  # E4: on easy every hint after the first costs a few seconds
	if int(g.hints_used) >= 2 and cost > 0.0:
		g.time = float(g.time) - cost
		g.msg += " (-%d S)" % int(cost)
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
	Game.ui_open = game == "chair"  # the race has the keys: the real player stays put (hidden) until it is over
	match game:
		"karaoke":
			var mic := _x0() + MIC_X
			_place_player(mic)
			_hold_player("talk", mic + 60.0)
			caption("%s. ARROW KEYS AT THE LINE. SING!" % str(g.song.title), 4.0)
		"cornhole":
			_corn_begin()
		"grill":
			_grill_begin()
		"darts":
			_darts_begin()
		"escape":
			caption("LOOK AROUND. E ON THE CHALKBOARD, THE CLOCK, THE PAINTING. N = HINT", 6.0)
		"dinner":
			g.stage = "sit"
			caption("SIT AT THE BOOTH WITH THE TEAM (PRESS E ON THE SEAT)", 99.0)


func _room_process(delta: float) -> void:
	_caption_t = maxf(0.0, _caption_t - delta)
	_room_extras(delta)
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
	if key == KEY_ESCAPE or (game == "chair" and key in CHAIR_KEYS):
		return true
	match game:
		"bowling":
			return key in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or (key in [KEY_LEFT, KEY_RIGHT] and str(g.get("stage", "")) in ["aim", "power"])
		"cornhole", "darts":
			return key in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		"grill":
			return key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D, KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_SHIFT]
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
	return is_open and room_mode() and phase == "play" and game in ["bowling", "cornhole", "grill", "darts"]


# the one control hint line: pages show it as their footer, rooms in the bar at the bottom
func hint() -> String:
	var text := ""
	if phase == "intro":
		text = "ENTER = START  ESC = SKIP  TAB = LOOK" if _traveled else "ENTER = START  ESC = SKIP"
	elif phase == "result":
		text = "ENTER = CONTINUE"
	elif not room_mode():
		text = _chair_hint() if game == "chair" else str(GAMES[game].keys)
	else:
		text = _room_hint()
	return text


func _room_hint() -> String:
	var text := "E = SIT DOWN  ESC = LEAVE"
	if str(g.get("stage", "")) == "talk":
		text = "UP / DOWN  ENTER = TALK  ESC = LEAVE"
	match game:
		"bowling":
			text = _bowl_hint(str(g.get("stage", "")))
		"karaoke":
			text = "ARROW KEYS = HIT NOTES  ESC = LEAVE"
		"chair":
			text = _chair_hint()
		"cornhole":
			text = _corn_hint()
		"grill":
			text = _grill_hint()
		"darts":
			text = _darts_hint()
		"escape":
			if g.get("entry", false):
				text = "ARROWS  ENTER = TRY  ESC = BACK"
			else:
				text = "E = LOOK / USE  N = HINT  ESC = LEAVE"
	return text


func _bowl_hint(stage: String) -> String:
	var text := "WAIT FOR YOUR TURN  ESC = LEAVE"
	match stage:
		"ready":
			text = "E = STEP UP  ESC = LEAVE"
		"aim":
			text = "E = STOP THE AIM  ESC = LEAVE"
		"power":
			text = "E = STOP THE POWER  ESC = LEAVE"
	return text


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
	# E6: which spots hold the clues is drawn each run (the one left over is the red herring); the toolbox keeps the fixed layout
	var spots := [0, 1, 2, 3]
	if not opts.has("recipes") and not opts.has("fixed_spots"):
		Difficulty.shuffle(spots, "escape.spots")
	var clues := []
	for i in n:
		var zone: String = CLUE_ZONES[int(spots[i])]
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
		"spots": spots.slice(0, n),
		"dial": Difficulty.i("escape.dial") > 0,
		"eq": eq,
	}


func interact(kind: String) -> void:
	if kind == "dart_board":
		offer_darts()
		return
	if kind.begins_with("cornhole_") or kind == "grill":
		_offer_here("grill" if kind == "grill" else "cornhole")
		return
	if not room_mode() or game != "escape" or phase != "play" or g.is_empty():
		return
	if kind.begins_with("herring_"):
		g.time = float(g.time) - HERRING_COST
		caption("%s (-%d S)" % [str(HERRING_TEXT.get(kind, HERRINGS[0])), int(HERRING_COST)], 4.0)
		return
	var zone_index := CLUE_KINDS.find(kind)
	var index := zone_index
	if zone_index >= 0 and g.has("spots"):
		index = (g.spots as Array).find(zone_index)  # which clue is on this spot (-1: a red herring)
	elif zone_index >= g.clues.size():
		index = -1
	if zone_index >= 0:
		if index >= 0:
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
			zone = CLUE_ZONES[int(g.spots[i]) if g.has("spots") else i]
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
	var strip_w := 176.0 if game == "dinner" else (232.0 if game == "chair" and size.x > 300.0 else 164.0)  # five faces need the room
	var strip := Rect2(0.0, top - UiStyle.STRIP_H, minf(size.x, strip_w), UiStyle.STRIP_H)
	match game:
		"bowling":
			_hud_bowling(strip)
		"karaoke":
			_hud_karaoke(strip, size)
		"chair":
			_hud_chair(strip)
		"cornhole":
			_hud_cornhole(strip)
		"grill":
			_hud_grill(strip, size)
		"darts":
			_hud_darts(strip, size)
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
			_canvas.draw_rect(Rect2(bar.position.x + 79.0 * (bowl_center() - bowl_zone_width() * 0.5), bar.position.y, 79.0 * bowl_zone_width(), 5.0), GREEN)
			_canvas.draw_rect(
				Rect2(bar.position.x + 79.0 * float(g.marker), bar.position.y - 2.0, 2.0, 9.0),
				WHITE
			)
			_t(_aim_label(), x, o.y, WHITE)
		else:
			_canvas.draw_rect(Rect2(bar.position.x + 79.0 * (float(g.get("pcen", 0.85)) - 0.125), bar.position.y, 14.0, 5.0), GREEN)
			_canvas.draw_rect(
				Rect2(bar.position.x, bar.position.y, 80.0 * float(g.power), 5.0), AMBER
			)
			_t("POWER", x, o.y, WHITE)
	else:
		var status := (
			"YOUR TURN" if stage == "ready" else ("ROLLING" if stage == "roll" else "CREW BOWLS")
		)
		_t(status, x, o.y, UiStyle.SOFT)


# at 180 px wide (the v format) the lanes box is 15 px shorter so it stays below the singers' feet; paint_karaoke
# squeezes the note travel to match, so the notes still arrive on the same beat
func _hud_karaoke(s: Rect2, size: Vector2) -> void:
	var tall := 78.0 if size.x >= 260.0 else 63.0
	var lanes := Rect2(4.0, s.position.y - tall - 1.0, 100.0, tall)
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
	var w := minf(size.x - 8.0, 84.0)  # narrow, so it stays right of John at the bar in the 320x180 format
	var box := Rect2(size.x - w - 4.0, s.position.y - 43.0, w, 42.0)
	UiStyle.box(_canvas, box)
	for i in 4:
		var on: bool = int(g.sel) == i and g.react.is_empty()
		var ry := box.position.y + 4.0 + 9.0 * float(i)
		if on:
			_canvas.draw_rect(Rect2(box.position.x + 2.0, ry - 1.0, w - 4.0, 8.0), Color("ffe08a"))
		_t(str(g.options[i]), box.position.x + 4.0, ry, INK if on else WHITE)


# ---- drawing ------------------------------------------------------------------------------------
# ---- chair race (R12, side-on in R18): the rules are in chair_race.gd, the drawing in chair_track.gd ------------
# who races: the party (or the whole roster when nobody was invited), those with a personality in ChairRace.RACERS
func racers() -> Array:
	var pool := present() if opts.has("party") else roster()
	return ChairRace.ORDER.filter(func(n: String) -> bool: return pool.has(n))


func _chair_params() -> Dictionary:
	return {
		"crash": Difficulty.f("chair.crash"),
		"stamina": Difficulty.f("chair.stamina"),
		"slick": Difficulty.f("chair.slick"),
		"par": Difficulty.f("chair.par"),
		"skill": Difficulty.f("chair.skill"),
	}


# the race is set up as soon as its page opens (so the room can show the racers on the grid); the countdown starts with ENTER
func _chair_setup() -> void:
	var race := ChairRace.new()
	race.setup(_chair_params(), racers(), Difficulty.rng("chair"))
	g = {"race": race, "place": 0, "new_best": false, "count": 4}
	var scene := get_tree().current_scene
	if room_mode() and scene != null and scene.get_node_or_null("Actors") != null:
		var me := _actor("Player")
		var specs := [
			{
				"key": "You",
				"character": me.character_id() if me != null else "office_adult",
				"custom": Look.is_custom(),
				"color": Color.WHITE,
				"label": "YOU",
			}
		]
		for r in race.rivals:
			specs.append({"key": r.n, "character": str(World.row(r.n).character), "custom": false, "color": r.color, "label": str(r.n).substr(0, 1)})
		var track := ChairTrack.new()
		track.setup(scene, race, _x0(), specs)
		g["track"] = track


# the racers and the copied props leave the floor, the real player is shown again
func _chair_clear() -> void:
	var track: Variant = g.get("track")
	if track != null and is_instance_valid(track):
		track.clear()
	g.erase("track")
	_chair_door(false)


# the warehouse overhead door rolls up for the start (a small cinematic through the roll_door fx, loud because it is far from
# the grid) and down again when the race is over; a door the player had already opened stays open
func _chair_door(up: bool) -> void:
	var door := get_tree().get_first_node_in_group("roll_door") if room_mode() else null
	if up:
		if door == null or g.has("door_was"):
			return
		g["door_was"] = float(door.goal)
		if door.goal < 0.5:
			door.door_set(1.0, true)
		return
	if not g.has("door_was"):
		return
	var was: float = g.get("door_was")
	g.erase("door_was")
	if was >= 0.5:
		return
	if door != null and is_instance_valid(door):
		door.door_set(0.0, true)
	else:
		World.door_open = 0.0


func _chair_tick(dt: float) -> void:
	var race: RefCounted = g.race
	if g.has("lane"):  # tests steer without the keyboard
		race.go_lane(int(g.lane))
	race.step(dt)
	_chair_cues(race)
	if race.phase == "done" and race.end_t >= 1.2:
		_chair_end()


# sounds for what just happened, and the line in the caption bar (the countdown, a toast, how the push felt, or where the next checkpoint is)
func _chair_cues(race: RefCounted) -> void:
	for e in race.events:
		match str(e):
			"crash":
				Sfx.play("clunk")
			"cone", "oil", "false":
				Sfx.play("squeak")
			"go", "finish":
				Sfx.play("bell")
			"check":
				Sfx.play("ui_tick")
	race.events.clear()
	var line := ""
	if race.clock < 0.0:
		line = "READY... %s" % race.countdown_text()
		if int(g.count) != int(ceilf(-race.clock)):
			g.count = int(ceilf(-race.clock))
			Sfx.play("ui_tick")
	elif race.msg_t > 0.0:
		line = race.msg
	elif race.feel_t > 0.0:
		line = race.feel
	elif race.cp_next < ChairRace.CHECK_NAMES.size():
		line = "NEXT: %s" % ChairRace.CHECK_NAMES[race.cp_next]
	else:
		line = "THE FINISH LINE!"
	caption(line, 0.3)


func _chair_press(key: int) -> void:
	var race: RefCounted = g.race
	match key:
		KEY_Z:
			race.push(0)
		KEY_X:
			race.push(1)
		KEY_UP, KEY_W:
			race.change_lane(-1)
		KEY_DOWN, KEY_S:
			race.change_lane(1)


func _chair_hint() -> String:
	if phase == "play" and g.has("race") and float(g.race.clock) < 0.0:
		return "GET READY  ESC = LEAVE"
	return str(GAMES.chair.keys)


# the race is over: the best time of this tier, the stars from the time, then the usual result page
func _chair_end() -> void:
	var race: RefCounted = g.race
	var t: float = race.total()
	g.place = race.place()
	g.new_best = not race.dnf and (not chair_best.has(Difficulty.tier) or t < float(chair_best[Difficulty.tier]))
	if g.new_best:
		chair_best[Difficulty.tier] = snappedf(t, 0.01)
	_chair_door(false)
	_finish(race.stars())


func _chair_lines() -> Array:
	var race: RefCounted = g.race
	var out := []
	if race.dnf:
		out.append("THE CHAIR NEVER MADE IT PAST THE LAST CHECKPOINT. (80 SECOND LIMIT.)")
	else:
		out.append(race.comment())
	if g.new_best:
		out.append("A NEW BEST TIME FOR %s: %.1f SECONDS." % [Difficulty.label(), race.total()])
	return out


# without the room (the overlay page) there is only the numbers
func _paint_chair(b: Rect2) -> void:
	var race: RefCounted = g.race
	var y := b.position.y
	var head := "READY... %s" % race.countdown_text() if race.clock < 0.0 else "TIME %.1fS" % race.total()
	_t("%s  PLACE %d OF %d" % [head, race.place_now(), race.rivals.size() + 1], b.position.x, y)
	_t("CHECKPOINT %d OF %d" % [race.cp_next, ChairRace.CHECK_NAMES.size()], b.position.x, y + 9.0)
	_t("STAMINA %d" % int(race.stam), b.position.x, y + 18.0, BLUE)
	if race.msg_t > 0.0:
		_t(race.msg, b.position.x, y + 27.0, RED if race.msg.contains("+") else INK)


# the strip at the bottom of the room: the Z and X keys, the clock, your place, everybody's progress, your stamina
func _hud_chair(s: Rect2) -> void:
	var race: RefCounted = g.race
	var o := UiStyle.strip(_canvas, s)
	var keys := ["Z", "X"]
	for k in 2:
		var lit: bool = race.lit(k)
		var kx := o.x + 9.0 * float(k)
		_canvas.draw_rect(Rect2(kx, s.position.y + 2.0, 7.0, 8.0), AMBER if lit else UiStyle.MUTED)
		_t(keys[k], kx + 2.0, s.position.y + 4.0, INK if lit else WHITE)
	_t("READY" if race.clock < 0.0 else "%.1fS" % race.total(), o.x + 21.0, o.y, WHITE)
	_t("P%d/%d" % [race.place_now(), race.rivals.size() + 1], o.x + 47.0, o.y, UiStyle.SOFT)
	var bw := 30.0
	var bx := s.end.x - bw - 5.0
	var stam_col := GREEN if race.stam > 40.0 else (AMBER if race.stam > 15.0 else RED)
	_canvas.draw_rect(Rect2(bx - 1.0, s.position.y + 2.0, bw + 2.0, 7.0), INK)
	_canvas.draw_rect(Rect2(bx, s.position.y + 3.0, bw * clampf(race.stam / 100.0, 0.0, 1.0), 5.0), stam_col)
	var rx := o.x + 68.0
	var rw := bx - rx - 6.0
	var ry := s.position.y + 6.0
	_canvas.draw_rect(Rect2(rx, ry, rw, 1.0), UiStyle.SOFT)
	for i in ChairRace.CHECK_FRAC.size():
		_canvas.draw_rect(Rect2(rx + rw * float(ChairRace.CHECK_FRAC[i]), ry - 2.0, 1.0, 5.0), UiStyle.SOFT)
	_canvas.draw_rect(Rect2(rx + rw, ry - 3.0, 2.0, 7.0), WHITE)
	for who in race.rivals:
		var fx := rx + rw * clampf(float(who.s) / ChairRace.LEN, 0.0, 1.0)
		_canvas.draw_rect(Rect2(fx - 1.0, ry - 1.0, 3.0, 3.0), who.color)
	var mx := rx + rw * clampf(race.pos / ChairRace.LEN, 0.0, 1.0)
	_canvas.draw_rect(Rect2(mx - 2.0, ry - 2.0, 5.0, 5.0), INK)
	_canvas.draw_rect(Rect2(mx - 1.0, ry - 1.0, 3.0, 3.0), WHITE)


# ---- cornhole (R21 a): two boards in the warehouse, you at A, the crew member of the round at B ------------------------
func cornholers() -> Array:
	var pool := present() if opts.has("party") else roster()
	return CornholeGame.ORDER.filter(func(n: String) -> bool: return pool.has(n))


func _corn_params() -> Dictionary:
	return {
		"to": mini(Difficulty.i("corn.to"), 11) if lunch_on() else Difficulty.i("corn.to"),
		"opp_skill": Difficulty.f("corn.opp_skill"),
		"aim_speed": Difficulty.f("corn.aim_speed"),
		"power_speed": Difficulty.f("corn.power_speed"),
		"assist": Difficulty.i("corn.assist") > 0,
		"floor": 1 if Difficulty.cozy_on() else 0,
		"zone_rng": Difficulty.rng("cornhole_zone"),
	}


func _corn_setup() -> void:
	var cg := CornholeGame.new()
	cg.setup(_corn_params(), cornholers(), Difficulty.rng("cornhole"))
	g = {"game": cg, "end_t": 0.0, "last_phase": "", "round": 0, "remark": "", "remark_t": 0.0}


# you step up to board A and the audience stands to the left of it
func _corn_begin() -> void:
	g["snap"] = 3
	_place_player(_x0() + CORN_A)
	_hold_player("idle", _x0() + CORN_B)
	caption("CORNHOLE. FOUR BAGS EACH, A HOLE IS 3, THE BOARD IS 1.", 4.0)


func _corn_tick(dt: float) -> void:
	var cg: RefCounted = g.game
	cg.step(dt)
	g.remark_t = maxf(0.0, float(g.remark_t) - dt)
	_corn_cues(cg)
	if cg.is_done():
		g.end_t = float(g.end_t) + dt
		if float(g.end_t) >= 1.2:
			_corn_end()


# sounds, poses and remarks for what just happened, and the line in the caption bar
func _corn_cues(cg: RefCounted) -> void:
	for e in cg.events:
		match str(e.e):
			"hole":
				Sfx.play("bag_hole")
				_corn_react(cg, str(e.who), true)
			"knock":
				Sfx.play("bag_knock")
			"thud":
				Sfx.play("bag_thud")
				_corn_react(cg, str(e.who), false)
			"round":
				_corn_seat(cg)
	cg.events.clear()
	if cg.phase == "flight" and str(g.last_phase) != "flight":
		var mine: bool = str(cg.flying.get("who", "")) == "you"
		var node := _actor("Player") if mine else _actor(str(cg.opp))
		if room_mode():
			_pose(node, "toss", 0.9, _x0() + (CORN_B if mine else CORN_A))
	g.last_phase = cg.phase
	if room_mode():
		_corn_keep_held(cg)
	var line := ""
	match str(cg.phase):
		"aim":
			line = "AIM: PRESS E WHEN THE MARKER IS IN THE GREEN."
		"power":
			line = "POWER: PRESS E WHEN THE BAR IS IN THE GREEN."
		"opp":
			line = "%s STEPS UP." % str(cg.opp).to_upper()
		_:
			line = str(cg.msg)
	if float(g.remark_t) > 0.0 and cg.phase in ["flight", "settle", "opp", "round_end"]:
		line = str(g.remark)
	caption(line, 0.3)


# the crew member of the round walks to board B, the one before goes back to the audience
func _corn_seat(cg: RefCounted) -> void:
	if not room_mode() or int(g.round) == cg.round_no:
		return
	g.round = cg.round_no
	var spots: Array = SPOTS.cornhole
	var cast := World.CAST.keys()
	for who in cg.crew:
		var node := _actor(str(who))
		if node == null:
			continue
		var home := _x0() + float(spots[maxi(0, cast.find(who)) % spots.size()])
		var at := _x0() + CORN_B if str(who) == str(cg.opp) else home
		node.global_position = Vector2(at, node.global_position.y)
		_pose(node, "idle", 0.1, _x0() + (CORN_A if str(who) == str(cg.opp) else CORN_B))


# a pose for a person: you have start_emote, a coworker has _face and _begin_hold (then _refresh puts the idle frame back)
func _pose(node: Node, anim: String, secs: float, toward: float) -> void:
	if node == null:
		return
	if node.has_method("start_emote"):
		node.start_emote(anim, secs, toward)
	elif node.has_method("_begin_hold"):
		node._face(toward)
		node._begin_hold(anim, secs)


# a throw or a wait should not let the player wander off or fall out of the pose
func _corn_keep_held(cg: RefCounted) -> void:
	var p := _actor("Player")
	if p != null and p.state != "emote" and phase == "play" and not cg.is_done():
		_hold_player("idle", _x0() + CORN_B)


func _corn_react(cg: RefCounted, who: String, hole: bool) -> void:
	var speaker := str(cg.opp) if who == "opp" else ""
	if who == "you" and hole and not cg.crew.is_empty():
		speaker = str(cg.crew[randi() % cg.crew.size()])
	elif who == "you" and not hole and randf() < 0.5:
		speaker = str(cg.opp)
	if room_mode():
		var thrower := _actor("Player") if who == "you" else _actor(str(cg.opp))
		_bubble(thrower, "!" if hole else "?", 1.2)
		if hole and speaker != "" and speaker != str(cg.opp):
			_bubble(_actor(speaker), "heart", 1.2)
	if speaker == "" or randf() > (0.75 if hole else 0.5):
		return
	var line := crew_line(speaker, "hole" if hole else "miss")
	if line != "":
		g.remark = "%s: %s" % [speaker.to_upper(), line]
		g.remark_t = 2.4


func _corn_press(key: int) -> void:
	if key not in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	var cg: RefCounted = g.game
	if not cg.your_turn():
		caption("WAIT. IT IS NOT YOUR THROW.", 1.2)
		return
	if cg.press() == "aim":
		Sfx.play("ui_tick")


func _corn_hint() -> String:
	var cg: RefCounted = g.game
	if cg.phase == "aim":
		return "E = STOP THE AIM  ESC = LEAVE"
	if cg.phase == "power":
		return "E = STOP THE POWER  ESC = LEAVE"
	return "WAIT FOR YOUR THROW  ESC = LEAVE"


func _corn_end() -> void:
	var cg: RefCounted = g.game
	_finish(cg.stars())


func _corn_lines() -> Array:
	var cg: RefCounted = g.game
	var out := []
	if cg.won:
		out.append("YOU WON %d TO %d." % [cg.score_you, cg.score_opp] + (" A BLOWOUT." if cg.margin() >= CornholeGame.BIG_WIN else ""))
	elif Difficulty.cozy_on():
		out.append("THEY WON %d TO %d. NOBODY IS KEEPING SCORE, REALLY." % [cg.score_opp, cg.score_you])
	else:
		out.append("THE CREW WON %d TO %d. REMATCH SOMETIME." % [cg.score_opp, cg.score_you])
	out.append("%d BAGS IN THE HOLE, %d ON THE BOARD." % [cg.holes, cg.boards])
	return out


# the strip at the bottom: the score, which bag, then the aim marker or the power bar (the green is the hole)
func _hud_cornhole(s: Rect2) -> void:
	var cg: RefCounted = g.game
	var o := UiStyle.strip(_canvas, s)
	_t("%d-%d TO %d" % [cg.score_you, cg.score_opp, cg.to], o.x, o.y, WHITE)
	_t("BAG %d" % cg.bag_no(), s.position.x + 52.0, o.y, UiStyle.SOFT)
	var bar := Rect2(s.position.x + 82.0, s.position.y + 3.0, 80.0, 5.0)
	if cg.phase == "aim" or cg.phase == "power":
		_canvas.draw_rect(bar, UiStyle.SOFT)
		var aim: bool = cg.phase == "aim"
		var centre: float = cg.aim_c if aim else cg.pow_c
		var half := CornholeGame.HOLE_R / (CornholeGame.AIM_SCALE if aim else CornholeGame.POWER_SCALE)
		_canvas.draw_rect(Rect2(bar.position.x + 79.0 * (centre - half), bar.position.y, 79.0 * half * 2.0, 5.0), GREEN)
		var v: float = cg.marker if aim else cg.power
		_canvas.draw_rect(Rect2(bar.position.x + 79.0 * v, bar.position.y - 2.0, 2.0, 9.0), WHITE)
	else:
		var status := "ROUND %d" % cg.round_no
		if cg.phase == "opp" or (cg.phase in ["flight", "settle"] and str(cg.opp) != "" and cg.seq % 2 == 1):
			status = "%s THROWS" % str(cg.opp).to_upper()
		elif cg.phase in ["flight", "settle"]:
			status = "YOUR BAG FLIES"
		_t(status, bar.position.x, o.y, UiStyle.SOFT)


# the overlay version (no room): the numbers
func _paint_cornhole(b: Rect2) -> void:
	var cg: RefCounted = g.game
	var y := b.position.y
	_t("ROUND %d: YOU AGAINST %s" % [cg.round_no, str(cg.opp)], b.position.x, y)
	_t("SCORE %d TO %d  (FIRST TO %d)" % [cg.score_you, cg.score_opp, cg.to], b.position.x, y + 9.0, BLUE)
	_t("BAG %d OF %d  THIS ROUND %d TO %d" % [cg.bag_no(), CornholeGame.BAGS, cg.round_you, cg.round_opp], b.position.x, y + 18.0)
	_t(str(cg.msg), b.position.x, y + 27.0, RED if cg.phase == "round_end" else INK)
	var bar := Rect2(b.position.x, b.end.y - 8.0, 70.0, 5.0)
	if cg.phase == "aim" or cg.phase == "power":
		_canvas.draw_rect(bar, Color("c9d2e0"))
		var aim: bool = cg.phase == "aim"
		var centre: float = cg.aim_c if aim else cg.pow_c
		var half := CornholeGame.HOLE_R / (CornholeGame.AIM_SCALE if aim else CornholeGame.POWER_SCALE)
		_canvas.draw_rect(Rect2(bar.position.x + 69.0 * (centre - half), bar.position.y, 69.0 * half * 2.0, 5.0), GREEN)
		var v: float = cg.marker if aim else cg.power
		_canvas.draw_rect(Rect2(bar.position.x + 69.0 * v, bar.position.y - 2.0, 2.0, 9.0), INK)


# ---- darts: a casual round at the board in the warehouse (not an evening outing) ---------------------------------------------
# E at the board (fx kind dart_board) offers a round: you and one or two coworkers who wander over, three darts a turn, three
# rounds, an aim reticle that drifts over the board (see DartsGame). In Free Play nothing is scored; in a campaign a round costs
# DARTS_LEN game hours and gives a little energy (the first two rounds of a day) and, the first round of a day, +1 opinion with the
# people who played (_darts_finish, _casual_after). Esc leaves early: no stars, no penalty.
func casual_on() -> bool:
	return bool(opts.get("casual", false))


# the opponents: the party (up to DARTS_MAX) or, when the game was not started with one, the first two on the roster
func darts_crew() -> Array:
	var pool := present() if opts.has("party") else roster()
	var crew_list := DartsGame.ORDER.filter(func(n: String) -> bool: return pool.has(n))
	return crew_list.slice(0, DARTS_MAX if opts.has("party") else 2)


# one or two coworkers who are up for a round: a seeded pick from an own stream (the evening parties keep their draws)
func darts_party() -> Array:
	var here := roster().filter(func(n: String) -> bool: return DartsGame.ORDER.has(n) and not Social.is_hostile(n))
	if here.is_empty():
		return []
	var r := Difficulty.rng_for("darts_party", darts_plays * 17 + maxi(0, Campaign.day))
	Difficulty.shuffle_with(here, r)
	var n := 2 if here.size() >= 2 and r.randf() < 0.6 else 1
	return _by_cast(here.slice(0, n))


# a round can start now: nothing else has the player (a card, an outing, a visit, overtime, a carried cable, a stopped clock) and a campaign day has the minutes left
func darts_ready() -> bool:
	if not enabled or is_open or busy() or Cards.is_open or Cards.waiting() > 0 or Game.title_mode or Game.busy or Game.ui_open:
		return false
	if Campaign.active:
		if World.time_scale <= 0.0 or Story.overtime or Onsite.busy or Onsite.active or Net.carrying != "" or Playbook.is_active() or Expo.away:
			return false
		if World.clock + DARTS_LEN >= World.DAY_END:
			return false
	return true


# E at the board: the card (false when a round cannot start now, the board then only makes a joke)
func offer_darts() -> bool:
	if not darts_ready():
		return false
	var pty := darts_party()
	var text := "A round of darts: three darts a turn, three rounds, highest total wins. "
	if pty.is_empty():
		text += "Nobody else is around, so it is you against the house."
	else:
		text += "%s %s up for it." % [join_names(pty, false), "is" if pty.size() == 1 else "are"]
	text += " It takes about a quarter of an hour." if Campaign.active else " (Free Play: nothing is scored.)"
	Cards.ask(
		"Darts",
		text,
		[{"label": "LET'S PLAY", "id": "yes"}, {"label": "NEVER MIND", "id": "no"}],
		func(answer: String) -> void:
			if answer == "yes":
				start("darts", false, {"party": pty, "casual": true})
	)
	return true


func _darts_params() -> Dictionary:
	return {
		"drift": Difficulty.f("darts.drift"),
		"speed": Difficulty.f("darts.speed"),
		"noise": Difficulty.f("darts.noise"),
		"opp_skill": Difficulty.f("darts.opp_skill"),
		"floor": 1 if Difficulty.cozy_on() else 0,
		"zone_rng": Difficulty.rng("darts_zone"),
	}


func _darts_setup() -> void:
	var dg := DartsGame.new()
	dg.setup(_darts_params(), darts_crew(), Difficulty.rng("darts"))
	g = {"game": dg, "end_t": 0.0, "last_phase": "", "remark": "", "remark_t": 0.0}


func _darts_begin() -> void:
	g["snap"] = 3
	_darts_seat(g.game)
	caption("DARTS. THREE DARTS A TURN, THREE ROUNDS. E THROWS AT THE RETICLE.", 4.0)


# the thrower of the turn stands at the line, everybody else waits to the left of it, facing the board
func _darts_seat(dg: RefCounted) -> void:
	if not room_mode():
		return
	var x0 := _x0()
	var k := 0
	var up := str(dg.thrower())
	for who in dg.players:
		var node := _actor("Player") if who == "You" else _actor(str(who))
		if node == null:
			continue
		var at: float = DART_X
		if str(who) != up:
			at = float(DART_SPOTS[k % DART_SPOTS.size()])
			k += 1
		if who == "You":
			_place_player(x0 + at)
			_hold_player("idle", x0 + DART_BOARD_X)
		else:
			node.global_position = Vector2(x0 + at, node.global_position.y)
			_pose(node, "idle", 0.1, x0 + DART_BOARD_X)


func _darts_tick(dt: float) -> void:
	var dg: RefCounted = g.game
	dg.step(dt)
	g.remark_t = maxf(0.0, float(g.remark_t) - dt)
	_darts_cues(dg)
	if dg.is_done():
		g.end_t = float(g.end_t) + dt
		if float(g.end_t) >= 1.6:
			_finish(dg.stars())


# sounds, poses and remarks for what just happened, and the line in the caption bar
func _darts_cues(dg: RefCounted) -> void:
	for e in dg.events:
		match str(e.e):
			"dart", "bull":
				Sfx.play("dart_hit")
				if str(e.e) == "bull":
					Sfx.play("bag_hole")
				_darts_react(dg, e)
			"turn":
				_darts_seat(dg)
			"pull":
				Sfx.play("ui_tick")
	dg.events.clear()
	if dg.phase == "flight" and str(g.last_phase) != "flight" and room_mode():
		var who := str(dg.flying.who)
		_pose(_actor("Player") if who == "You" else _actor(who), "toss", 0.9, _x0() + DART_BOARD_X)
	g.last_phase = dg.phase
	if room_mode():
		var p := _actor("Player")
		if p != null and p.state != "emote" and phase == "play" and not dg.is_done():
			_hold_player("idle", _x0() + DART_BOARD_X)
	var line := ""
	match str(dg.phase):
		"aim":
			line = "AIM: PRESS E TO THROW AT THE RETICLE. THE WOBBLE SETTLES FOR A MOMENT."
		"opp", "ready":
			line = str(dg.msg)
		_:
			line = str(dg.msg)
	if float(g.remark_t) > 0.0 and dg.phase in ["settle", "pull", "opp"]:
		line = str(g.remark)
	caption(line, 0.3)


# a big dart (40 or more, or the bull) is cheered by somebody else, a dart off the board groans
func _darts_react(dg: RefCounted, e: Dictionary) -> void:
	var who := str(e.who)
	var pts := int(e.pts)
	var big: bool = pts >= 40
	var off: bool = pts == 0
	var speaker := ""
	if big:
		var others: Array = dg.players.filter(func(n: String) -> bool: return n != who and n != "You" and n != "THE HOUSE")
		if not others.is_empty():
			speaker = str(others[randi() % others.size()])
	elif off and who != "You":
		speaker = who
	elif off and randf() < 0.5 and not dg.crew.is_empty():
		speaker = str(dg.crew[randi() % dg.crew.size()])
	if room_mode():
		var thrower := _actor("Player") if who == "You" else _actor(who)
		if big or off:
			_bubble(thrower, "!" if big else "?", 1.2)
		if big and speaker != "":
			_bubble(_actor(speaker), "heart", 1.2)
	if speaker == "" or randf() > (0.8 if big else 0.5):
		return
	var line := crew_line(speaker, "hole" if big else "miss")
	if line != "":
		g.remark = "%s: %s" % [speaker.to_upper(), line]
		g.remark_t = 2.4


func _darts_press(key: int) -> void:
	if key not in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		return
	var dg: RefCounted = g.game
	if not dg.aiming():
		if not dg.is_done():
			caption("WAIT. IT IS NOT YOUR THROW.", 1.2)
		return
	dg.press()


func _darts_hint() -> String:
	var dg: RefCounted = g.game
	return "E = THROW  ESC = LEAVE" if dg.aiming() else "WAIT FOR YOUR THROW  ESC = LEAVE"


# the result of a round (a casual game): the records, a line or two about the game, the small campaign rewards
func _darts_finish(result: int) -> void:
	var dg: RefCounted = g.game
	darts_plays += 1
	best[game] = maxi(int(best.get(game, 0)), result)
	Career.note_outing(game, result, {"casual": true, "bulls": dg.bulls, "score": int(dg.totals["You"])})
	lines.append_array(_darts_lines())
	if Campaign.active:
		if darts_day != Campaign.day:
			darts_day = Campaign.day
			darts_today = 0
		var first := darts_today == 0
		darts_today += 1
		if first and not dg.crew.is_empty():
			for who in dg.crew:
				Social.change(str(who), 1)
			lines.append("THEY LIKE YOU A LITTLE MORE: A FRIENDLY GAME.")
		if Campaign.mode == "owner":
			Owner.burnout = clampf(Owner.burnout - 2.0, 0.0, 100.0)
			lines.append("BURNOUT DOWN 2 POINTS. A QUICK BREAK HELPS.")
		elif Campaign.mode != "sales":
			if darts_today <= 2:
				Shift.add_energy(float(DARTS_ENERGY))
				lines.append("ENERGY +%d. A QUICK BREAK HELPS." % DARTS_ENERGY)
			else:
				lines.append("NO MORE BREAKS TODAY. BACK TO THE QUEUE.")
	else:
		lines.append("A QUICK ROUND. (FREE PLAY: NOTHING IS SCORED.)")
	lines.append_array(_mastery_lines(result))


func _darts_lines() -> Array:
	var dg: RefCounted = g.game
	var out := []
	var mine := int(dg.totals["You"])
	if dg.margin() > 0:
		out.append("YOU WIN %d TO %d." % [mine, dg.best_opp()] + (" A WALKOVER." if dg.margin() >= DartsGame.BIG_WIN else ""))
	elif dg.margin() == 0:
		out.append("A TIE AT %d. NOBODY WILL LET IT GO." % mine)
	elif Difficulty.cozy_on():
		out.append("%s WON WITH %d. YOU HAD %d. IT IS ONLY DARTS." % [str(dg.leader()).to_upper(), dg.best_opp(), mine])
	else:
		out.append("%s WINS WITH %d. YOU HAD %d. REMATCH SOMETIME." % [str(dg.leader()).to_upper(), dg.best_opp(), mine])
	var extra := "BEST DART %d" % dg.best_dart
	if dg.bulls > 0:
		extra += ", %d BULLSEYE%s" % [dg.bulls, "" if dg.bulls == 1 else "S"]
	if dg.trebles > 0:
		extra += ", %d TREBLE%s" % [dg.trebles, "" if dg.trebles == 1 else "S"]
	out.append(extra + ".")
	return out


# back at work after a campaign round: the clock moved on DARTS_LEN hours and the queue aged at half the onsite rate (not on Cozy Easy)
func _casual_after() -> void:
	World.clock = minf(World.DAY_END - 0.25, World.clock + DARTS_LEN)
	if not Difficulty.cozy_on():
		var scale := World.day_len / 600.0
		for t in Msp.tickets:
			if t.status != "Closed":
				t.sla_left = maxf(float(t.sla_total) * 0.35, float(t.sla_left) - DARTS_LEN * Onsite.SLA_PER_HOUR * 0.5 * scale)
	Hints.toast("BACK FROM THE DART BOARD. THE QUEUE WAITED." if Difficulty.cozy_on() else "BACK FROM THE DART BOARD. THE QUEUE KEPT TICKING A LITTLE.", 3.0)


const DART_COLORS := [Color("5aa0e8"), Color("f2862e"), Color("e0463c"), Color("5fd068")]


func _dart_color(dg: RefCounted, who: String) -> Color:
	return DART_COLORS[maxi(0, dg.players.find(who)) % DART_COLORS.size()]


# a ring segment of the board (a polygon along two arcs, angles in radians clockwise from the top)
func _board_wedge(c: Vector2, r0: float, r1: float, a0: float, a1: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 4:
		var a := lerpf(a0, a1, float(k) / 3.0)
		pts.append(c + Vector2(sin(a), -cos(a)) * r1)
	for k in 4:
		var a := lerpf(a1, a0, float(k) / 3.0)
		pts.append(c + Vector2(sin(a), -cos(a)) * r0)
	_canvas.draw_colored_polygon(pts, color)


# the zoomed board of the HUD: the real rings at r pixels, this turn's darts and, on your aim, the reticle (its ring is tighter when steady)
func _draw_dart_zoom(c: Vector2, r: float, dg: RefCounted) -> void:
	var sc := r / DartsGame.BOARD_R
	_canvas.draw_circle(c, r + 1.5, INK)
	for i in 20:
		var a0 := deg_to_rad(float(i) * 18.0 - 9.0)
		var a1 := deg_to_rad(float(i) * 18.0 + 9.0)
		var dark: bool = i % 2 == 0
		var single := Color("2a2a33") if dark else Color("e8ddb0")
		var ring := Color("c23b2e") if dark else Color("2f8b4e")
		_board_wedge(c, DartsGame.OUTER_BULL_R * sc, DartsGame.TREBLE_IN * sc, a0, a1, single)
		_board_wedge(c, DartsGame.TREBLE_IN * sc, DartsGame.TREBLE_OUT * sc, a0, a1, ring)
		_board_wedge(c, DartsGame.TREBLE_OUT * sc, DartsGame.DOUBLE_IN * sc, a0, a1, single)
		_board_wedge(c, DartsGame.DOUBLE_IN * sc, r, a0, a1, ring)
	_canvas.draw_circle(c, DartsGame.OUTER_BULL_R * sc, Color("2f8b4e"))
	_canvas.draw_circle(c, maxf(1.0, DartsGame.BULL_R * sc), Color("c23b2e"))
	for d in dg.darts_now:
		var at := c + Vector2(float(d.px), float(d.py)) * sc
		at = c + (at - c).limit_length(r + 3.0)
		var col := _dart_color(dg, str(d.who))
		_canvas.draw_rect(Rect2(at - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), INK)
		_canvas.draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), col)
	if dg.aiming():
		var at: Vector2 = c + Vector2(dg.reticle()) * sc
		at = c + (at - c).limit_length(r + 3.0)
		var rad: float = 2.0 + 3.5 * float(dg.steadiness(dg.aim_t))
		_canvas.draw_arc(at, rad + 1.0, 0.0, TAU, 14, INK, 1.0)
		_canvas.draw_arc(at, rad, 0.0, TAU, 14, AMBER, 1.0)
		_canvas.draw_rect(Rect2(at - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), WHITE)


# the strip: the round, everybody's total (the thrower bright) and the darts left in this turn; the zoomed board sits above its right end
func _hud_darts(s: Rect2, size: Vector2) -> void:
	var dg: RefCounted = g.game
	var o := UiStyle.strip(_canvas, s)
	_t("R%d/%d" % [dg.round_no(), dg.rounds], o.x, o.y, UiStyle.SOFT)
	var x := s.position.x + 26.0
	for who in dg.players:
		var short := "YOU" if who == "You" else str(who).to_upper().substr(0, 3)
		var text := "%s %d" % [short, int(dg.totals[who])]
		_t(text, x, o.y, WHITE if str(who) == str(dg.thrower()) else UiStyle.SOFT)
		x += 4.0 * float(text.length()) + 6.0
	var left: int = DartsGame.DARTS - dg.dart_i if dg.phase in ["ready", "aim", "opp"] else (DartsGame.DARTS - dg.dart_i - 1 if dg.phase in ["flight", "settle"] else 0)
	for i in DartsGame.DARTS:
		var px := s.end.x - 8.0 - 6.0 * float(DartsGame.DARTS - 1 - i)
		var col := AMBER if i < left else UiStyle.MUTED
		_canvas.draw_rect(Rect2(px, s.position.y + 4.0, 3.0, 3.0), col)
	var r := 22.0
	var box := Rect2(size.x - 2.0 * r - 8.0, s.position.y - 2.0 * r - 6.0, 2.0 * r + 8.0, 2.0 * r + 6.0)
	UiStyle.box(_canvas, box)
	_draw_dart_zoom(Vector2(box.position.x + box.size.x * 0.5, box.position.y + 4.0 + r), r, dg)


# the overlay version (no room): the numbers and the zoomed board
func _paint_darts(b: Rect2) -> void:
	var dg: RefCounted = g.game
	var y := b.position.y
	_t("ROUND %d OF %d   DART %d OF %d" % [dg.round_no(), dg.rounds, mini(DartsGame.DARTS, dg.dart_i + 1), DartsGame.DARTS], b.position.x, y)
	for i in dg.players.size():
		var who: String = dg.players[i]
		_t("%s %d" % [who.to_upper(), int(dg.totals[who])], b.position.x, y + 9.0 + 8.0 * float(i), BLUE if who == str(dg.thrower()) else INK)
	_t(str(dg.msg), b.position.x, b.end.y - 8.0, RED if dg.phase == "pull" else INK)
	_draw_dart_zoom(Vector2(b.end.x - 32.0, b.position.y + 34.0), 30.0, dg)


# ---- the cookout (R21 b): the grill in the dock, the crew queues to the left of you -------------------------------------
func grill_crew() -> Array:
	var pool := present() if opts.has("party") else roster()
	return _by_cast(pool)


func _grill_params() -> Dictionary:
	var p := {
		"cook_rate": Difficulty.f("grill.cook_rate"),
		"window": Difficulty.f("grill.window"),
		"tickets": Difficulty.i("grill.tickets"),
		"time": Difficulty.f("grill.time"),
		"flare": Difficulty.f("grill.flare"),
		"dogs": Difficulty.f("grill.dogs"),
		"zone_rng": Difficulty.rng("grill_zone"),
		"cozy": Difficulty.cozy_on(),
	}
	if lunch_on():  # a short lunch: two tickets fewer, a fifth less time
		p["tickets"] = maxi(4, int(p.tickets) - 2)
		p["time"] = float(p.time) * 0.8
	return p


func _grill_setup() -> void:
	var gg := GrillGame.new()
	gg.setup(_grill_params(), grill_crew(), Difficulty.rng("grill"))
	g = {"game": gg, "end_t": 0.0, "remark": "", "remark_t": 0.0, "sizzle": 0.0}


func _grill_begin() -> void:
	g["snap"] = 3
	_place_player(_x0() + GRILL_X)
	_hold_player("idle", _x0() + GRILL_X + 60.0)
	caption("ARROWS PICK A PATTY. E FLIPS, SPACE SERVES, SHIFT = COOL SIDE.", 5.0)


func _grill_tick(dt: float) -> void:
	var gg: RefCounted = g.game
	gg.step(dt)
	g.remark_t = maxf(0.0, float(g.remark_t) - dt)
	g.sizzle = float(g.sizzle) - dt
	_grill_cues(gg)
	if gg.done:
		g.end_t = float(g.end_t) + dt
		if float(g.end_t) >= 1.4:
			_grill_end()


func _grill_cues(gg: RefCounted) -> void:
	var p := _actor("Player")
	for e in gg.events:
		match str(e.e):
			"flip":
				Sfx.play("grill_sizzle")
				if p != null and room_mode():
					p.start_emote("toss", 0.9, _x0() + GRILL_X + 60.0)
			"flare":
				Sfx.play("grill_flare")
			"bell":
				Sfx.play("serve_bell")
				if p != null and room_mode():
					p.start_emote("hold", 0.6, _x0() + GRILL_X + 60.0)
				_grill_react(str(e.who), "cook", "heart")
			"new":
				Sfx.play("ui_tick")
				_bubble(_actor(str(e.who)), "!", 1.6)
			"gone":
				_grill_react(str(e.who), "wait", "?")
			"toss":
				Sfx.play("ui_error")
			"burnt":
				Sfx.play("grill_flare")
	gg.events.clear()
	if gg.cooking() and float(g.sizzle) <= 0.0:
		g.sizzle = 3.0
		Sfx.play("grill_sizzle", 0.4)
	if room_mode() and p != null and p.state != "emote" and phase == "play" and not gg.done:
		_hold_player("idle", _x0() + GRILL_X + 60.0)
	var line := str(gg.msg) if float(gg.msg_t) > 0.0 else "ARROWS PICK A PATTY. E FLIPS IT, SPACE SERVES IT, SHIFT PARKS IT ON THE COOL SIDE."
	if float(g.remark_t) > 0.0:
		line = str(g.remark)
	caption(line, 0.3)


func _grill_react(who: String, kind: String, glyph: String) -> void:
	if room_mode():
		_bubble(_actor(who), glyph, 1.4)
	if randf() > 0.7:
		return
	var line := crew_line(who, kind)
	if line != "":
		g.remark = "%s: %s" % [who.to_upper(), line]
		g.remark_t = 2.4


func _grill_press(key: int) -> void:
	var gg: RefCounted = g.game
	match key:
		KEY_LEFT, KEY_A:
			gg.move_sel(-1)
			Sfx.play("ui_tick")
		KEY_RIGHT, KEY_D:
			gg.move_sel(1)
			Sfx.play("ui_tick")
		KEY_E:
			gg.flip()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			gg.pull()
			var p := _actor("Player")
			if p != null and room_mode():
				p.start_emote("hold", 0.5, _x0() + GRILL_X + 60.0)
		KEY_SHIFT:
			gg.cool()


func _grill_hint() -> String:
	return "ARROWS = PICK  E = FLIP  SPACE = SERVE"


func _grill_end() -> void:
	var gg: RefCounted = g.game
	_finish(gg.stars())


func _grill_lines() -> Array:
	var gg: RefCounted = g.game
	var out := []
	out.append("SERVED %d OF %d TICKETS." % [gg.served, gg.total()])
	if gg.burnt == 0:
		out.append("NOTHING BURNT. THE GRILL IS SPOTLESS.")
	elif Difficulty.cozy_on():
		out.append("%d CRISPY ONES. THE CREW ATE THEM ANYWAY." % gg.burnt)
	else:
		out.append("%d BURNT. THE SMOKE ALARM IS A GOOD SPORT." % gg.burnt)
	return out


func _hud_grill(s: Rect2, size: Vector2) -> void:
	var gg: RefCounted = g.game
	var o := UiStyle.strip(_canvas, s)
	var secs := int(ceilf(gg.time_left()))
	_t("SERVED %d/%d  %dS  BURNT %d" % [gg.served, gg.total(), secs, gg.burnt], o.x, o.y, WHITE)
	# the open tickets, left: who, what, how long they will wait
	var rows: Array = gg.open_tickets().slice(0, 3)
	var tall := 30.0
	var tbox := Rect2(4.0, s.position.y - tall - 1.0, 78.0, tall)
	UiStyle.box(_canvas, tbox)
	if rows.is_empty():
		_t("NO ORDERS", tbox.position.x + 4.0, tbox.position.y + 4.0, UiStyle.SOFT)
	for i in rows.size():
		var t: Dictionary = rows[i]
		var ry := tbox.position.y + 3.0 + 9.0 * float(i)
		var parts := []
		var left_w := int(t.need.well) - int(t.have.well)
		var left_m := int(t.need.medium) - int(t.have.medium)
		var left_d := int(t.need.dog) - int(t.have.dog)
		if left_w > 0:
			parts.append("%dW" % left_w)
		if left_m > 0:
			parts.append("%dM" % left_m)
		if left_d > 0:
			parts.append("%dD" % left_d)
		var codes := (" " if parts.size() < 3 else "").join(parts)
		_t(str(t.who).to_upper().substr(0, 6), tbox.position.x + 3.0, ry, WHITE)
		_t(codes, tbox.position.x + 28.0, ry, AMBER)
		var frac := clampf(float(t.left) / GrillGame.PATIENCE, 0.0, 1.0) if not gg.cozy else 1.0
		_canvas.draw_rect(Rect2(tbox.position.x + 54.0, ry + 1.0, 20.0, 3.0), UiStyle.MUTED)
		_canvas.draw_rect(Rect2(tbox.position.x + 54.0, ry + 1.0, 20.0 * frac, 3.0), GREEN if frac > 0.5 else (AMBER if frac > 0.25 else RED))
	# the grate, right: four patties, the up side's colour, the down side's progress under it
	var gbox := Rect2(size.x - 4.0 - 90.0, s.position.y - tall - 1.0, 90.0, tall)
	UiStyle.box(_canvas, gbox)
	for i in GrillGame.SLOTS:
		var cell := Rect2(gbox.position.x + 3.0 + 21.0 * float(i), gbox.position.y + 3.0, 20.0, 25.0)
		var slot: Dictionary = gg.slots[i]
		var dog: bool = slot.kind == "dog"
		var win: Vector2 = gg.flip_range(str(slot.kind), float(slot.get("woff", 0.0)))
		if i == gg.sel:
			_canvas.draw_rect(cell, AMBER)
			_canvas.draw_rect(Rect2(cell.position + Vector2.ONE, cell.size - Vector2(2, 2)), UiStyle.DARK)
		_t(str(i + 1), cell.position.x + 9.0, cell.position.y + 19.0, AMBER if i == gg.sel else UiStyle.SOFT)
		if not slot.on:
			continue
		var up: float = float(slot.c[1 - int(slot.down)])
		var down_v: float = float(slot.c[int(slot.down)])
		if dog:  # a hot dog: a long, thin body with rounded ends
			_canvas.draw_rect(Rect2(cell.position.x + 3.0, cell.position.y + 5.0, 15.0, 6.0), _dog_color(up))
			_canvas.draw_rect(Rect2(cell.position.x + 2.0, cell.position.y + 6.0, 17.0, 4.0), _dog_color(up))
			_canvas.draw_rect(Rect2(cell.position.x + 4.0, cell.position.y + 6.0, 13.0, 1.0), Color(1, 1, 1, 0.2))
		else:
			_canvas.draw_rect(Rect2(cell.position.x + 2.0, cell.position.y + 3.0, 17.0, 10.0), _cook_color(up))
			_canvas.draw_rect(Rect2(cell.position.x + 3.0, cell.position.y + 4.0, 15.0, 1.0), Color(1, 1, 1, 0.18))
		var bar := Rect2(cell.position.x + 2.0, cell.position.y + 15.0, 16.0, 3.0)
		_canvas.draw_rect(bar, UiStyle.MUTED)
		_canvas.draw_rect(Rect2(bar.position.x + 17.0 * win.x, bar.position.y - 1.0, 1.0, 5.0), UiStyle.SOFT)
		_canvas.draw_rect(Rect2(bar.position.x + 17.0 * minf(win.y, 1.0), bar.position.y - 1.0, 1.0, 5.0), UiStyle.SOFT)
		_canvas.draw_rect(Rect2(bar.position.x, bar.position.y, 17.0 * clampf(down_v, 0.0, 1.0), 3.0), _dog_color(down_v) if dog else _cook_color(down_v))
		var tag := str(gg.doneness(i))
		if slot.cool:
			_canvas.draw_rect(Rect2(cell.position.x + 2.0, cell.position.y, 17.0, 2.0), Color("5aa0e8"))
		elif float(slot.flare) > 0.0:
			_canvas.draw_rect(Rect2(cell.position.x + 2.0, cell.position.y, 17.0, 2.0), Color("f08a30") if int(float(Time.get_ticks_msec()) / 120.0) % 2 == 0 else RED)
		_t({"raw": "R", "medium": "M", "well": "W", "dog": "D", "burnt": "X"}.get(tag, "-"), cell.position.x + 9.0, cell.position.y + 6.0, INK if tag == "raw" else WHITE)


func _cook_color(v: float) -> Color:
	if v > GrillGame.BURN:
		return Color("2a1c18")
	if v < 0.35:
		return Color("e58a8a").lerp(Color("c9704f"), v / 0.35)
	if v < 0.55:
		return Color("c9704f").lerp(Color("8f5233"), (v - 0.35) / 0.2)
	return Color("8f5233").lerp(Color("4a2c1c"), clampf((v - 0.55) / 0.35, 0.0, 1.0))


# a hot dog's colour for a side: pink, then red-brown, then dark
func _dog_color(v: float) -> Color:
	if v > GrillGame.DOG_BURN:
		return Color("2a1c18")
	if v < GrillGame.DOG_RAW:
		return Color("e58a8a").lerp(Color("c9503a"), v / GrillGame.DOG_RAW)
	return Color("c9503a").lerp(Color("7a2f1f"), clampf((v - GrillGame.DOG_RAW) / 0.4, 0.0, 1.0))


# the overlay version (no room): the numbers
func _paint_grill(b: Rect2) -> void:
	var gg: RefCounted = g.game
	var y := b.position.y
	_t("SERVED %d OF %d  TIME %d  BURNT %d" % [gg.served, gg.total(), int(ceilf(gg.time_left())), gg.burnt], b.position.x, y)
	for i in GrillGame.SLOTS:
		var slot: Dictionary = gg.slots[i]
		var text := "%d: EMPTY" % (i + 1)
		if slot.on:
			text = "%d: %s  %d %d" % [i + 1, str(gg.doneness(i)).to_upper(), int(float(slot.c[0]) * 100.0), int(float(slot.c[1]) * 100.0)]
		_t(text, b.position.x, y + 9.0 + 8.0 * float(i), BLUE if i == gg.sel else INK)
	var rows: Array = gg.open_tickets().slice(0, 3)
	for i in rows.size():
		var t: Dictionary = rows[i]
		_t("%s: %s" % [str(t.who).to_upper(), ", ".join(gg.lines(t))], b.position.x, y + 43.0 + 8.0 * float(i), AMBER)
	if float(gg.msg_t) > 0.0:
		_t(str(gg.msg), b.position.x, b.end.y - 8.0, RED)


# ---- the warehouse extras for both games: the camera sits so the floor is above the HUD, boards and grill are the way in
# (the walkway band y 110 to 127 must show above the strip and the caption bars: a short screen looks lower down)
func _room_extras(_delta: float) -> void:
	if not room_mode() or game not in ["cornhole", "grill", "darts"] or phase == "intro":
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var f: Dictionary = Game.FORMATS[Game.format]
	var view := get_viewport().get_visible_rect().size / float(f.zoom)
	var centre: float = float(f.cam_y) if f.follow else 64.0
	var lift := CORN_LIFT if game == "cornhole" else (DARTS_LIFT if game == "darts" else GRILL_LIFT)
	var pan := CORN_PAN if game == "cornhole" else (DARTS_PAN if game == "darts" else GRILL_PAN)
	cam.offset = Vector2(pan, maxf(0.0, lift - (centre + view.y * 0.5)))
	if int(g.get("snap", 0)) > 0:  # you were moved 900 px: the camera should not glide there
		g.snap = int(g.snap) - 1
		cam.reset_smoothing()


func _reset_camera() -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null:
		cam.offset = Vector2.ZERO


# E on a board, the bag tray or the grill: a Free Play outing right here (never in a campaign: those come on outing days)
func _offer_here(id: String) -> void:
	if is_open or Cards.is_open or busy():
		return
	if not enabled or Campaign.active or Game.title_mode:
		Hints.toast(
			"THE CORNHOLE BOARDS. SOMEONE CHALKED THE SCORE ON THE WALL." if id == "cornhole" else "A BBQ GRILL. SOMEONE LEFT THE TONGS OUT.", 3.0
		)
		return
	var ask := "Throw some bags? Cornhole against the crew. (Free Play: nothing is scored.) " if id == "cornhole" else "Fire up the grill? A cookout for the crew. (Free Play: nothing is scored.) "
	party_set = false
	draw_party()
	Cards.ask(
		"Team outing",
		ask + coming_text(),
		[{"label": "LET'S GO", "id": "yes"}, {"label": "NEVER MIND", "id": "no"}],
		func(answer: String) -> void:
			if answer == "yes":
				start(id, false, _game_options(id))
	)


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
	var title := str(GAMES[game].label) + (("  A QUICK ROUND" if casual_on() else "  TEAM OUTING") if phase != "result" else "  RESULT")
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
				"chair":
					_paint_chair(body)
				"cornhole":
					_paint_cornhole(body)
				"grill":
					_paint_grill(body)
				"darts":
					_paint_darts(body)
				_:
					_paint_dinner(body)
	UiStyle.footer(_canvas, panel, hint())


# R5: who is in the room for a karaoke night or an escape room, in words ("" for the other games, which name their own crew)
func _party_line(for_game: String) -> String:
	if for_game != "karaoke" and for_game != "escape":
		return ""
	var here := present()
	if here.is_empty():
		return "JUST YOU." if for_game == "karaoke" else "NOBODY CAME, SO NO HINTS."
	var text := ("IN THE ROOM: " if for_game == "karaoke" else "HELPING YOU: ") + join_names(here, true) + "."
	if for_game == "karaoke" and _duet_partner() != "":
		text += " %s WILL SING THE RIGHT LANES." % _duet_partner().to_upper()
	return text


func _paint_intro(b: Rect2) -> void:
	var y := b.position.y + 2.0
	var blurb := str(ROOM_INTRO[game]) if _traveled else str(GAMES[game].blurb)
	if game == "bowling" and not bowlers().is_empty():  # the blurbs name the classic trio: say who is really here
		blurb = blurb.replace("ALAN, GARRISON AND DAN", join_names(bowlers(), true))
	if game == "karaoke":
		blurb += " " + kara_warning(default_song() if not _traveled else "")
	for line in _wrap(blurb, int(b.size.x / 4.0)):
		_t(line, b.position.x, y)
		y += 7.0
	y += 4.0
	if Campaign.mode == "owner":
		_t("COST $%d" % int(GAMES[game].cost), b.position.x, y, RED)
		y += 7.0
	if game == "bowling":
		y = _paint_bowl_intro(b, y)
	if game == "cornhole" or game == "grill":
		var crew_names := cornholers() if game == "cornhole" else grill_crew()
		var who_text := ("OPPONENTS: " if game == "cornhole" else "ORDERS FROM: ") + join_names(crew_names, true) if not crew_names.is_empty() else "JUST YOU AND THE HOUSE."
		if game == "cornhole":
			who_text += ".  FIRST TO %d." % Difficulty.i("corn.to")
		else:
			who_text += ".  %d ORDERS IN %d SECONDS." % [Difficulty.i("grill.tickets"), roundi(Difficulty.f("grill.time"))]
		for part in _wrap(who_text, int(b.size.x / 4.0)):
			_t(part, b.position.x, y)
			y += 7.0
	var party_text := _party_line(game)  # R5: the karaoke and escape intros name who came along
	if party_text != "":
		for part in _wrap(party_text, int(b.size.x / 4.0)):
			_t(part, b.position.x, y)
			y += 7.0
	if game == "darts":
		var crew_names := darts_crew()
		var who_text := ("OPPONENTS: " + join_names(crew_names, true)) if not crew_names.is_empty() else "JUST YOU AND THE HOUSE"
		who_text += ".  %d ROUNDS OF %d DARTS." % [DartsGame.ROUNDS, DartsGame.DARTS]
		for part in _wrap(who_text, int(b.size.x / 4.0)):
			_t(part, b.position.x, y)
			y += 7.0
	if game == "chair":
		var names := racers()
		var who := "RIVALS: " + join_names(names, true) if not names.is_empty() else "NO RIVALS TONIGHT: A TIME TRIAL."
		for part in _wrap(who, int(b.size.x / 4.0)):
			_t(part, b.position.x, y)
			y += 7.0
		if chair_best.has(Difficulty.tier):
			_t("BEST TIME (%s): %.1f S" % [Difficulty.label(), float(chair_best[Difficulty.tier])], b.position.x, y, GREEN)
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
			"cornhole":
				detail = "YOU %d  CREW %d  HOLES %d" % [int(g.game.score_you), int(g.game.score_opp), int(g.game.holes)]
			"grill":
				detail = "SERVED %d OF %d  BURNT %d" % [int(g.game.served), int(g.game.total()), int(g.game.burnt)]
			"darts":
				var dg: RefCounted = g.game
				detail = "YOU %d" % int(dg.totals["You"])
				for who in dg.players:
					if who != "You":
						detail += "  %s %d" % [str(who).to_upper(), int(dg.totals[who])]
			"chair":
				var race: RefCounted = g.race
				detail = "TIME %s  PLACE %d OF %d  HITS %d" % ["DNF" if race.dnf else "%.1fS" % race.total(), int(g.place), race.rivals.size() + 1, race.crashes + race.cones]
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
		_canvas.draw_rect(Rect2(bar.position.x + 69.0 * (bowl_center() - bowl_zone_width() * 0.5), bar_y, 69.0 * bowl_zone_width(), 5.0), GREEN)
		_canvas.draw_rect(
			Rect2(bar.position.x + 69.0 * float(g.marker), bar_y - 2.0, 2.0, 9.0), INK
		)
		_t(_aim_label(), x + 74.0 - 4.0, bar_y - 8.0, BLUE)
	elif g.stage == "power":
		_canvas.draw_rect(Rect2(bar.position.x + 69.0 * (float(g.get("pcen", 0.85)) - 0.125), bar_y, 12.0, 5.0), GREEN)
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
	var squeeze := minf(1.0, (line_y - top) / 60.0) if hud else 1.0  # the short lanes box at v
	for lane in 4:
		var cx := left + 20.0 * float(lane) + 10.0
		_canvas.draw_rect(Rect2(cx - 9.0, top, 18.0, line_y + 6.0 - top), Color("dde3ee"))
		_arrow(lane, Vector2(cx, line_y), 5.0, Color(LANE_COLORS[lane], 0.45))
	for n in g.notes:
		var dy: float = (float(n.time) - float(g.t)) * float(g.get("speed", 45.0)) * squeeze
		if dy < -14.0 or dy > line_y - top + 4.0:
			continue
		var col: Color = LANE_COLORS[int(n.lane)]
		if n.state == "miss":
			col = Color("8a8f9a")
		elif n.state != "":
			col = Color(col, 0.35)
		elif n.get("auto", false):
			col = Color(col, 0.55)  # the partner's notes: fainter, they sing those
		if float(n.get("len", 0.0)) > 0.0 and n.state != "miss":  # a hold note: the tail runs up the lane
			var tail := minf(float(n.len) * float(g.get("speed", 45.0)) * squeeze, line_y - dy - top)
			_canvas.draw_rect(Rect2(left + 20.0 * float(n.lane) + 8.0, line_y - dy - tail, 4.0, tail), Color(col, 0.6))
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
