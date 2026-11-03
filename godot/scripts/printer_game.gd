extends CanvasLayer
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length,max-returns,class-definitions-order
# The printer mini-game (onsite, the bane of every MSP's existence): open the printer and fight it in rounds.
# Which rounds depend on the MODEL (see MODELS): a laser has them all, the others drop or rename some.
#   JAM:   pull the stuck paper out. SPACE stops a moving marker: green = a clean pull, yellow = it holds (try again),
#          red = it tears and leaves a scrap (a mistake, and one more pull). The chain is 3 pulls (more on HARD, up to 6);
#          two clean pulls in a row shorten it again (never below 3).
#   TRAY:  the display says what is wrong with the paper (PC LOAD LETTER on a laser). Load the right paper or roll.
#   TONER: install the cartridges (ink tanks, a ribbon) in the order the printer asks (left / right, SPACE).
#   SHAKE: shake the cartridge (A and D).
#   TEST:  error messages on the little display; pick the right way to deal with each (1 / 2 / 3).
#          How many comes from Difficulty ("printer.questions": 1 / 2 / 3), drawn from QUESTIONS tagged for the model and tier.
# P prays to the sysadmin gods (3 prayers; each model has its own): good luck blesses you (the next mistake is forgiven,
# the green zone widens), bad luck costs you. Pray-free wins keep a streak. Fewer mistakes = more stars (0-3). Esc gives up.
# Used by Onsite (printer jobs, and practice in Free Play where the intro page lets you pick the model and a seed):
#   PrinterGame.start(func(stars: int) -> void: ..., "plotter", {"onsite": true})  # model and options are optional
# options: onsite (the marker runs up to 15% faster when you are tired, see Shift.slow_mult), practice, seed (practice).
# The questions and texts are in QUESTIONS / TEXT / MODEL_TEXT so reviewers can edit them in story/strings.txt.

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const PW := 176.0
const PH := 112.0
const INK := Color("17121f")
const BODY := Color("dfe3ea")
const PAPER := Color("f4f2ea")
const COLORS := [Color("2fa7d8"), Color("d8409a"), Color("f2d23c"), Color("2a2a33")]
const COLOR_NAMES := ["CYAN", "MAGENTA", "YELLOW", "BLACK"]
const RIBBON_COLORS := [Color("2a2a33"), Color("b3302f")]
const RIBBON_NAMES := ["BLACK", "RED"]
const TRAY := ["LETTER", "LEGAL", "A4", "HIT IT"]
const PLOTTER_TRAY := ["24 BOND", "36 BOND", "MYLAR", "HIT IT"]
const RECEIPT_TRAY := ["80 MM", "58 MM", "PLAIN", "HIT IT"]
const DOT_TRAY := ["TRACTOR", "SINGLE", "LABELS", "HIT IT"]
# the printer models. phases = the rounds in order (test is always last); tray / names / colors = what the tray and the
# cartridge round offer (the right tray is always the first, the last one is the joke); look = how it is drawn.
const MODELS := {
	"laser":
	{
		"label": "LASER",
		"phases": ["jam", "tray", "toner", "shake", "test"],
		"tray": TRAY,
		"names": COLOR_NAMES,
		"colors": COLORS,
		"look": "laser",
	},
	"inkjet":
	{
		"label": "INKJET",
		"phases": ["jam", "toner", "test"],
		"tray": TRAY,
		"names": COLOR_NAMES,
		"colors": COLORS,
		"look": "inkjet",
	},
	"plotter":
	{
		"label": "PLOTTER",
		"phases": ["jam", "tray", "toner", "shake", "test"],
		"tray": PLOTTER_TRAY,
		"names": COLOR_NAMES,
		"colors": COLORS,
		"look": "plotter",
	},
	"mfp":
	{
		"label": "MULTIFUNCTION",
		"phases": ["jam", "tray", "toner", "test"],
		"tray": TRAY,
		"names": COLOR_NAMES,
		"colors": COLORS,
		"look": "mfp",
	},
	"receipt":
	{
		"label": "RECEIPT",
		"phases": ["jam", "tray", "test"],
		"tray": RECEIPT_TRAY,
		"names": [],
		"colors": [],
		"look": "receipt",
	},
	"dot":
	{
		"label": "DOT MATRIX",
		"phases": ["jam", "tray", "toner", "test"],
		"tray": DOT_TRAY,
		"names": RIBBON_NAMES,
		"colors": RIBBON_COLORS,
		"look": "dot",
	},
}
const MODEL_ORDER := ["laser", "inkjet", "plotter", "mfp", "receipt", "dot"]
const DEFAULT_TEXT := {
	"title": "PRINTER REPAIR",
	"intro1": "THE COPIER GRINDS AND THE DISPLAY SAYS",
	"intro2": "PAPER JAM 13.20.00. THEY ALWAYS SAY THAT.",
	"intro3": "SPACE = START  ESC = SKIP",
	"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN",
	"jam_clean": "A CLEAN PULL. THE SHEET COMES OUT WHOLE.",
	"jam_hold": "IT HOLDS. NOT QUITE: TRY AGAIN.",
	"jam_tear": "RIP! A SCRAP IS STILL INSIDE.",
	"jam_short": "TWO CLEAN PULLS: THE JAM EASES, ONE FEWER TO GO.",
	"jam_scrap": "THE SCRAP NEEDS ONE MORE PULL.",
	"toner_help": "LEFT / RIGHT TO PICK, SPACE TO INSTALL",
	"toner_ok": "CLICK. IT SEATS.",
	"toner_bad": "WRONG CARTRIDGE. THE PRINTER BEEPS.",
	"shake_help": "SHAKE THE CARTRIDGE: A D A D A D",
	"shake_late": "TOO SLOW. TONER DUST EVERYWHERE.",
	"test_help": "PICK 1, 2 OR 3",
	"right": "RIGHT.",
	"wrong": "NOPE.",
	"hit": "YOU HIT THE PRINTER. IT WORKS. DO NOT TELL ANYONE.",
	"stars3": "PERFECT. A FLAWLESS TEST PAGE.",
	"stars2": "GOOD ENOUGH. A FEW STREAKS.",
	"stars1": "IT PRINTS. MOSTLY.",
	"stars0": "YOU GIVE UP. THE PRINTER WINS.",
	"done": "SPACE = CONTINUE",
	"tray_help": "PC LOAD LETTER. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
	"tray_ok": "LETTER PAPER IN TRAY 2. PC LOAD LETTER IS SOLVED. YOU ARE A HERO.",
	"tray_bad": "WRONG PAPER. THE PRINTER JAMS ON PRINCIPLE.",
	"tray_hit": "YOU HIT THE PRINTER AND IT WORKS. DO NOT TELL ANYONE.",
	"tray_screen": "PC LOAD LETTER",
	"tray_slot": "TRAY 2",
	"pray_help": "P: PRAY TO THE SYSADMIN GODS",
	"pray_none": "THE GODS HAVE HEARD ENOUGH FROM YOU TODAY.",
	"blessed_tag": "BLESSED",
	"tired_tag": "TIRED",
	"tired_note": "TIRED: THE MARKER RUNS %d PERCENT FASTER.",
	"practice_help": "LEFT / RIGHT = MODEL  UP / DOWN = SEED",
	"streak": "NO-PRAYER STREAK: %d",
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)
# the per-model overlays on TEXT: only the keys that differ
const DEFAULT_MODEL_TEXT := {
	"plotter":
	{
		"title": "PLOTTER REPAIR",
		"intro1": "THE FORTY-INCH PLOTTER CHEWS ITS ROLL",
		"intro2": "AND SAYS MEDIA JAM. A PRINT DUE AT NOON.",
		"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: EASE THE ROLL OUT",
		"jam_clean": "A CLEAN PULL. THE ROLL COMES OUT WHOLE AND FLAT.",
		"jam_hold": "THE ROLL HOLDS. NOT QUITE: TRY AGAIN.",
		"jam_tear": "RIP! A STRIP OF BOND IS STILL WRAPPED INSIDE.",
		"toner_help": "LEFT / RIGHT TO PICK AN INK TANK, SPACE TO INSTALL",
		"toner_ok": "CLICK. THE INK TANK SEATS.",
		"toner_bad": "WRONG INK TANK. THE PLOTTER BEEPS AT YOU.",
		"shake_help": "ROCK THE INK TANK: A D A D A D",
		"shake_late": "TOO SLOW. INK ON THE FLOOR AND ON THE BLUEPRINTS.",
		"hit": "YOU SLAP THE PLOTTER. IT WORKS. DO NOT TELL THE ARCHITECTS.",
		"stars3": "PERFECT. A CRISP FORTY-INCH SITE PLAN.",
		"stars2": "GOOD ENOUGH. A FEW BANDING LINES.",
		"stars1": "IT PLOTS. THE SCALE BAR IS A LITTLE OFF.",
		"stars0": "YOU GIVE UP. THE PLOTTER WINS.",
		"tray_help": "MEDIA MISMATCH. LOAD THE RIGHT ROLL. LEFT / RIGHT, SPACE",
		"tray_ok": "24 INCH BOND ROLL LOADED. THE JOB NUMBER 14-0312 PRINTS.",
		"tray_bad": "WRONG ROLL. THE PLOTTER CUTS IT SHORT.",
		"tray_hit": "YOU HIT THE PLOTTER AND IT WORKS. DO NOT TELL ANYONE.",
		"tray_screen": "MEDIA MISMATCH",
		"tray_slot": "ROLL 1",
		"pray_help": "P: PRAY TO THE PLOTTER GODS",
	},
	"inkjet":
	{
		"title": "INKJET REPAIR",
		"intro1": "THE INKJET PRINTS A PAGE OF WHITE LINES",
		"intro2": "AND A PAPER JAM LIGHT BLINKS. AGAIN.",
		"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: FREE THE SHEET",
		"jam_clean": "A CLEAN PULL. THE SHEET COMES OUT FLAT.",
		"jam_tear": "RIP! A CORNER IS STILL UNDER THE ROLLER.",
		"toner_help": "LEFT / RIGHT TO PICK AN INK TANK, SPACE TO FIT",
		"toner_ok": "CLICK. THE INK TANK SEATS.",
		"toner_bad": "WRONG SLOT. THE INKJET BEEPS.",
		"hit": "YOU TAP THE INKJET. IT PRINTS. DO NOT TELL ANYONE.",
		"stars3": "PERFECT. THE ALIGNMENT PAGE IS CRISP.",
		"stars2": "GOOD ENOUGH. A LITTLE BANDING.",
		"stars1": "IT PRINTS. THE BLACK IS A BIT GREEN.",
		"stars0": "YOU GIVE UP. THE INKJET WINS.",
		"pray_help": "P: PRAY TO THE INK GODS",
	},
	"mfp":
	{
		"title": "COPIER REPAIR",
		"intro1": "THE COPIER SCANS AND FAXES, THEN JAMS.",
		"intro2": "ADF MISFEED. PAPER EVERYWHERE.",
		"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: PULL THE SHEET",
		"jam_clean": "A CLEAN PULL. THE SHEET LEAVES THE FEEDER WHOLE.",
		"jam_tear": "RIP! HALF A LETTER IS STUCK IN THE FEEDER.",
		"toner_help": "LEFT / RIGHT TO PICK A CARTRIDGE, SPACE TO FIT",
		"hit": "YOU THUMP THE COPIER. IT WORKS. DO NOT TELL THE PARTNERS.",
		"stars3": "PERFECT. THE FAX GOES OUT AND THE COPIES ARE CLEAN.",
		"stars1": "IT COPIES. THE FAX STILL HISSES.",
		"stars0": "YOU GIVE UP. THE COPIER WINS.",
		"tray_help": "TRAY MISMATCH. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
		"tray_ok": "LETTER PAPER IN TRAY 1. THE COPIER HUMS.",
		"tray_screen": "LOAD LETTER IN TRAY 1",
		"tray_slot": "TRAY 1",
		"pray_help": "P: PRAY TO THE COPIER GODS",
	},
	"receipt":
	{
		"title": "RECEIPT PRINTER",
		"intro1": "THE RECEIPT PRINTER BEEPS AND THE LINE",
		"intro2": "AT THE DESK GROWS. THE LIGHT IS RED.",
		"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: FREE THE PAPER",
		"jam_clean": "A CLEAN PULL. THE PAPER FEEDS STRAIGHT.",
		"jam_tear": "RIP! A CURL OF THERMAL PAPER IS STUCK.",
		"hit": "YOU SMACK THE LID. IT CUTS A RECEIPT. DO NOT TELL ANYONE.",
		"stars3": "PERFECT. A CRISP RECEIPT AND A CLEAN CUT.",
		"stars2": "GOOD ENOUGH. THE CUT IS A LITTLE CROOKED.",
		"stars1": "IT PRINTS. THE TOTAL IS FAINT.",
		"stars0": "YOU GIVE UP. THE LINE GROWS.",
		"tray_help": "PAPER OUT LIGHT. LOAD THE RIGHT ROLL. LEFT / RIGHT, SPACE",
		"tray_ok": "THE 80 MM ROLL IS IN, HEAT SIDE UP. IT CUTS CLEANLY.",
		"tray_bad": "WRONG ROLL. THE LID WILL NOT CLOSE.",
		"tray_hit": "YOU HIT THE LID AND IT CLOSES. DO NOT TELL ANYONE.",
		"tray_screen": "PAPER OUT",
		"tray_slot": "ROLL BAY",
		"pray_help": "P: PRAY TO THE REGISTER GODS",
	},
	"dot":
	{
		"title": "DOT MATRIX REPAIR",
		"intro1": "THE OLD DOT MATRIX SCREECHES THROUGH ITS",
		"intro2": "FORMS AND THE TRACTOR FEED IS CROOKED.",
		"jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: FREE THE FORM",
		"jam_clean": "A CLEAN PULL. THE FORM COMES OUT WHOLE.",
		"jam_tear": "RIP! A STRIP OF PINFEED HOLES IS STILL INSIDE.",
		"toner_help": "LEFT / RIGHT TO PICK THE RIBBON, SPACE TO FIT",
		"toner_ok": "CLICK. THE RIBBON SEATS.",
		"toner_bad": "WRONG RIBBON. THE HEAD GRINDS.",
		"hit": "YOU THUMP THE CASE. IT SCREECHES AND WORKS.",
		"stars3": "PERFECT. THE CARBON COPY IS READABLE.",
		"stars2": "GOOD ENOUGH. A FEW PALE LINES.",
		"stars1": "IT PRINTS. THE THIRD COPY IS A GHOST.",
		"stars0": "YOU GIVE UP. THE DOT MATRIX WINS.",
		"tray_help": "FORMS OUT OF LINE. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
		"tray_ok": "THE FORMS RIDE THE TRACTOR PINS, SQUARE AT LAST.",
		"tray_bad": "WRONG PAPER. THE PINS TEAR THE EDGE.",
		"tray_screen": "FORM FEED ERROR",
		"tray_slot": "TRACTOR",
		"pray_help": "P: PRAY TO THE FORMS GODS",
	},
}
var MODEL_TEXT: Dictionary = DEFAULT_MODEL_TEXT.duplicate(true)
# prayers: the laser (and anything without its own list) uses PRAYERS; the others have a faith of their own
const PRAYERS := {
	"good":
	[
		"THE SYSADMIN GODS SMILE. YOUR NEXT MISTAKE IS FORGIVEN.",
		"A WARM HUM FROM A DISTANT SERVER ROOM. YOU ARE BLESSED.",
		"A DOMAIN CONTROLLER REPLICATES IN YOUR HONOR. YOU ARE BLESSED.",
	],
	"meh":
	[
		"THE GODS ARE BUSY RESTARTING A DOMAIN CONTROLLER.",
		"SILENCE. SOMEWHERE, A BACKUP FAILS.",
		"THE GODS PUT YOU ON HOLD. THE MUSIC IS BAD.",
	],
	"bad":
	[
		"THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.",
		"A SURGE ON THE POWER LINE. THE GODS ARE DISPLEASED.",
	],
}
const MODEL_PRAYERS := {
	"inkjet":
	{
		"good": ["A DROP OF CYAN FALLS WHERE IT SHOULD. YOU ARE BLESSED.", "THE NOZZLES CLEAR ALL BY THEMSELVES. YOU ARE BLESSED."],
		"meh": ["THE GODS OF INK ARE BUSY. THE CARTRIDGE IS EMPTY.", "A FAINT SMELL OF ISOPROPYL. NOTHING ELSE."],
		"bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE CHIP LIES ABOUT THE INK LEVEL. THE MARKER SPEEDS UP."],
	},
	"plotter":
	{
		"good": ["THE ROLL FEEDS STRAIGHT FOR ONCE. YOU ARE BLESSED.", "A SCALE BAR COMES OUT RIGHT. THE PLOTTER GODS NOD. YOU ARE BLESSED."],
		"meh": ["THE GODS ARE AT A SITE MEETING. NO REPLY.", "SOMEONE REVISES THE DRAWING. THE GODS SIGH."],
		"bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE PRINTHEAD CRASHES ACROSS THE PAGE. THE MARKER SPEEDS UP."],
	},
	"mfp":
	{
		"good": ["THE FAX HANDSHAKE SOUNDS RIGHT. YOU ARE BLESSED.", "THE FEEDER PICKS ONE SHEET AT A TIME. YOU ARE BLESSED."],
		"meh": ["THE GODS ARE ON THE OTHER LINE.", "A BUSY SIGNAL FROM ABOVE."],
		"bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "A FAX ARRIVES FOR THE WRONG OFFICE. THE MARKER SPEEDS UP."],
	},
	"receipt": {
		"good": ["THE CUTTER SNAPS CLEAN. YOU ARE BLESSED.", "THE DRAWER POPS OPEN ON ITS OWN. YOU ARE BLESSED."],
		"meh": ["THE GODS WANT A SIGNATURE ON THE SCREEN. NOTHING ELSE.", "THE GODS SAY THE TOTAL IS CORRECT. THAT IS ALL."],
		"bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE LINE AT THE DESK GROANS. THE MARKER SPEEDS UP."],
	},
	"dot":
	{
		"good": ["THE PINS FIND THEIR HOLES. YOU ARE BLESSED.", "A SOFT SCREECH OF APPROVAL FROM THE HEAD. YOU ARE BLESSED."],
		"meh": ["THE GODS ARE BUSY RE-INKING A RIBBON.", "A CARBON COPY OF SILENCE."],
		"bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE HEAD SCREAMS AND THE CARRIAGE STUTTERS. THE MARKER SPEEDS UP."],
	},
}
# the test-page questions. models = which printers show it (empty = all), hard = lowest tier it appears on
# (0 easy, 1 normal, 2 hard; harder questions are only used on an easier tier when a model has too few).
# Keep error and options to 36 characters, the display is small.
const DEFAULT_QUESTIONS := [
	{
		"error": "TONER LOW",
		"options": ["IGNORE IT", "REPLACE THE CARTRIDGE", "SHAKE IT AND KEEP PRINTING"],
		"correct": 1,
		"hit": -1,
		"why": "SHAKING BUYS ABOUT TWENTY PAGES. THEN THE STREAKS COME BACK.",
		"models": ["laser", "mfp"],
		"hard": 0,
	},
	{
		"error": "ERROR 79 SERVICE",
		"options": ["REINSTALL THE DRIVER", "POWER CYCLE AND RESEAT THE FORMATTER", "CALL THE VENDOR"],
		"correct": 1,
		"hit": -1,
		"why": "A 79 IS USUALLY THE FORMATTER OR A BAD PRINT JOB. UNPLUG, WAIT, RESEAT, TRY AGAIN.",
		"models": ["laser", "mfp"],
		"hard": 1,
	},
	{
		"error": "PRINTER OFFLINE",
		"options": ["SET IT BACK ONLINE", "BUY A NEW PRINTER", "REINSTALL WINDOWS"],
		"correct": 0,
		"hit": -1,
		"why": "SOMEONE PRESSED THE OFFLINE BUTTON. SOMEONE ALWAYS DOES.",
		"models": [],
		"hard": 0,
	},
	{
		"error": "PAPER MISMATCH TRAY 1",
		"options": ["OPEN THE FUSER", "SET TRAY 1 TO PLAIN PAPER", "BLAME THE USER"],
		"correct": 1,
		"hit": -1,
		"why": "THE TRAY SAYS LABELS BUT THE PAPER IS PLAIN. CHANGE THE TRAY SETTING.",
		"models": ["laser", "mfp", "inkjet"],
		"hard": 0,
	},
	{
		"error": "MEDIA JAM ROLL 1",
		"options": ["PULL THE ROLL OUT HARD", "OPEN THE COVER, FEED IT STRAIGHT", "ORDER A NEW ROLL"],
		"correct": 1,
		"hit": -1,
		"why": "A SKEWED LEADING EDGE JAMS THE PINCH ROLLERS. RELOAD IT STRAIGHT.",
		"models": ["plotter"],
		"hard": 0,
	},
	{
		"error": "REPLACE PRINTHEAD",
		"options": ["ALIGN THE PRINTHEAD", "SWAP THE HEAD AND ALIGN IT", "IGNORE IT"],
		"correct": 1,
		"hit": -1,
		"why": "BANDING THAT NEVER CLEARS MEANS A DEAD NOZZLE. SWAP IT, THEN ALIGN.",
		"models": ["plotter", "inkjet"],
		"hard": 1,
	},
	{
		"error": "OUT OF MEMORY",
		"options": ["ADD MEMORY OR SEND A FLAT PDF", "REINSTALL CAD", "PRINT IT AGAIN"],
		"correct": 0,
		"hit": -1,
		"why": "A BIG DRAWING WITH A HEAVY HATCH CHOKES THE PLOTTER. SEND A FLATTENED PDF.",
		"models": ["plotter"],
		"hard": 1,
	},
	{
		"error": "PAPER SIZE MISMATCH",
		"options": ["SET THE DRIVER TO ARCH D", "BLAME THE INTERN", "CUT THE ROLL BY HAND"],
		"correct": 0,
		"hit": -1,
		"why": "THE DRAWING SAYS 24 BY 36 BUT THE DRIVER SAYS LETTER. FIX THE PAPER SIZE.",
		"models": ["plotter"],
		"hard": 0,
	},
	{
		"error": "STREAKS AFTER A NEW INK TANK",
		"options": ["RUN THE ALIGNMENT PAGE", "BUY MORE INK", "SHAKE THE PRINTER"],
		"correct": 0,
		"hit": -1,
		"why": "A SWAPPED INK TANK OR HEAD NEEDS ALIGNING. PRINT THE ALIGNMENT PAGE AND PICK THE BEST BLOCKS.",
		"models": ["inkjet", "plotter"],
		"hard": 0,
	},
	{
		"error": "JOB STUCK: 400 MB IN QUEUE",
		"options": ["PRINT IT TEN MORE TIMES", "RESTART THE SPOOLER, CLEAR QUEUE", "UNPLUG THE PRINTER"],
		"correct": 1,
		"hit": -1,
		"why": "ONE HUGE SCAN BLOCKS THE QUEUE. STOP THE SPOOLER, EMPTY THE SPOOL FOLDER, START IT AGAIN.",
		"models": [],
		"hard": 1,
	},
	{
		"error": "CANNOT CONNECT TO SHARED PRINTER",
		"options": ["WAKE THE XP PC THAT SHARES IT", "REINSTALL EVERY PC", "BUY A NETWORK PRINTER"],
		"correct": 0,
		"hit": -1,
		"why": "THE USB PRINTER IS SHARED FROM AN OLD XP PC AND THAT PC WENT TO SLEEP. KEEP IT AWAKE.",
		"models": ["inkjet", "laser", "dot", "receipt"],
		"hard": 1,
	},
	{
		"error": "PRINTER NOT FOUND",
		"options": ["RESERVE ITS ADDRESS ON THE ROUTER", "REBUILD EVERY PC", "PRINT TO A FILE"],
		"correct": 0,
		"hit": -1,
		"why": "THE DHCP LEASE RAN OUT AND THE PRINTER GOT A NEW IP. RESERVE ONE OR SET A STATIC ADDRESS.",
		"models": ["laser", "mfp", "plotter"],
		"hard": 1,
	},
	{
		"error": "PRINTS COME OUT AT THE OTHER OFFICE",
		"options": ["SET THE RIGHT DEFAULT PRINTER", "REBUILD THE LAPTOP", "UNPLUG THE OTHER PRINTER"],
		"correct": 0,
		"hit": -1,
		"why": "THE LAPTOP KEPT THE DEFAULT PRINTER FROM THE OTHER OFFICE. PICK THE LOCAL ONE.",
		"models": [],
		"hard": 0,
	},
	{
		"error": "20 INSUFFICIENT MEMORY",
		"options": ["LOWER THE DPI OR ADD A DIMM", "POWER CYCLE UNTIL IT WORKS", "SEND THE JOB TWICE"],
		"correct": 0,
		"hit": -1,
		"why": "THIS LASER HAS 2 MB. A FULL PAGE AT HIGH DPI WILL NOT FIT. LOWER THE RESOLUTION OR ADD MEMORY.",
		"models": ["laser"],
		"hard": 1,
	},
	{
		"error": "CLOSE DUPLEX UNIT",
		"options": ["PUSH THE DUPLEX UNIT UNTIL IT CLICKS", "REPLACE THE FUSER", "UPDATE THE FIRMWARE"],
		"correct": 0,
		"hit": -1,
		"why": "THE DUPLEXER IS NOT SEATED, SO THE SENSOR SAYS OPEN. PUSH IT IN UNTIL IT CLICKS.",
		"models": ["laser", "mfp"],
		"hard": 0,
	},
	{
		"error": "PICKS TWO SHEETS, THEN NONE",
		"options": ["OIL THE ROLLERS", "CLEAN OR SWAP THE FEED ROLLERS", "FAN THE PAPER FOREVER"],
		"correct": 1,
		"hit": -1,
		"why": "GLAZED FEED ROLLERS LOSE THEIR GRIP. WIPE THEM WITH A DAMP CLOTH OR REPLACE THEM.",
		"models": ["laser", "mfp", "inkjet"],
		"hard": 1,
	},
	{
		"error": "PRINTER DEAD, NO LIGHTS AT ALL",
		"options": ["CHECK THE POWER CORD", "REPLACE THE POWER SUPPLY", "REIMAGE THE PC"],
		"correct": 0,
		"hit": -1,
		"why": "IT IS UNPLUGGED. THE CLEANER NEEDED THE SOCKET. PLUG IT IN AND TELL NOBODY.",
		"models": [],
		"hard": 0,
	},
	{
		"error": "WHITE LINES ACROSS THE PAGE",
		"options": ["RUN A HEAD CLEAN AND NOZZLE CHECK", "BUY A NEW PRINTER", "BLAME THE PAPER"],
		"correct": 0,
		"hit": -1,
		"why": "A CLOGGED NOZZLE LEAVES GAPS. RUN THE HEAD CLEANING CYCLE AND PRINT A NOZZLE CHECK.",
		"models": ["inkjet"],
		"hard": 0,
	},
	{
		"error": "CARTRIDGE NOT RECOGNIZED",
		"options": ["RESEAT IT, WIPE THE CHIP CONTACTS", "TURN OFF THE FIREWALL", "RESET THE PC"],
		"correct": 0,
		"hit": -1,
		"why": "THE CHIP CONTACTS ARE DIRTY OR THE CARTRIDGE IS NOT SEATED. CLEAN AND RESEAT IT.",
		"models": ["inkjet"],
		"hard": 1,
	},
	{
		"error": "VERTICAL LINES ON EVERY SCAN",
		"options": ["REINSTALL THE SCAN DRIVER", "CLEAN THE SCANNER GLASS", "REPLACE THE TONER"],
		"correct": 1,
		"hit": -1,
		"why": "A SPECK ON THE GLASS OR THE ADF STRIP DRAWS A LINE ON EVERY PAGE. WIPE BOTH.",
		"models": ["mfp"],
		"hard": 0,
	},
	{
		"error": "ADF PICK FAILED",
		"options": ["OPEN THE ADF, REMOVE THE STAPLE", "BUY A FLATBED", "SCAN WITH A PHONE"],
		"correct": 0,
		"hit": -1,
		"why": "A STAPLE OR A CURLED CORNER BLOCKS THE FEEDER. OPEN THE COVER AND CLEAR THE PATH.",
		"models": ["mfp"],
		"hard": 0,
	},
	{
		"error": "FAX: NO DIAL TONE",
		"options": ["REPLACE THE FAX BOARD", "MOVE THE CORD TO THE LINE JACK", "RESET THE ROUTER"],
		"correct": 1,
		"hit": -1,
		"why": "THE PHONE CORD IS IN THE EXT JACK, NOT THE LINE JACK. SWAP IT OVER.",
		"models": ["mfp"],
		"hard": 1,
	},
	{
		"error": "SCAN TO EMAIL FAILED",
		"options": ["CHECK THE MAIL SERVER AND PORT", "REPLACE THE SCANNER LAMP", "SCAN TO FOLDER FOREVER"],
		"correct": 0,
		"hit": -1,
		"why": "THE SMTP SERVER OR PORT IN THE SCANNER SETTINGS IS WRONG, OR THE RELAY NEEDS A LOGIN.",
		"models": ["mfp"],
		"hard": 2,
	},
	{
		"error": "PAPER OUT, BUT THERE IS PAPER",
		"options": ["FLIP THE ROLL, HEAT SIDE IN", "BUY A NEW ROLL", "HIT THE LID"],
		"correct": 0,
		"hit": 2,
		"why": "THERMAL PAPER HAS ONE HEATED SIDE. LOADED BACKWARDS IT PRINTS NOTHING. TURN THE ROLL OVER.",
		"models": ["receipt"],
		"hard": 0,
	},
	{
		"error": "RECEIPTS PRINT VERY FAINT",
		"options": ["CLEAN THE THERMAL HEAD", "ADD TONER", "REPLACE THE DRAWER"],
		"correct": 0,
		"hit": -1,
		"why": "PAPER DUST BUILDS UP ON THE THERMAL HEAD. WIPE IT WITH ALCOHOL AND LET IT DRY.",
		"models": ["receipt"],
		"hard": 0,
	},
	{
		"error": "CUTTER ERROR",
		"options": ["OPEN THE COVER, CLEAR THE SCRAP", "FORCE THE PAPER OUT", "RESTART THE REGISTER"],
		"correct": 0,
		"hit": -1,
		"why": "A SCRAP OF PAPER IS STUCK IN THE CUTTER BLADE. OPEN THE COVER, REMOVE IT, RESEAT THE BLADE.",
		"models": ["receipt"],
		"hard": 1,
	},
	{
		"error": "RECEIPT SHOWS GARBAGE LETTERS",
		"options": ["MATCH THE BAUD RATE TO THE REGISTER", "REPLACE THE ROLL", "UNPLUG THE DRAWER"],
		"correct": 0,
		"hit": -1,
		"why": "THE SERIAL SETTINGS DO NOT MATCH THE REGISTER. SET THE SAME BAUD RATE ON BOTH.",
		"models": ["receipt"],
		"hard": 2,
	},
	{
		"error": "PRINT IS PALE AND GHOSTLY",
		"options": ["REPLACE THE RIBBON", "ADD TONER", "SWITCH TO INKJET"],
		"correct": 0,
		"hit": -1,
		"why": "A WORN RIBBON LEAVES FAINT DOTS. FIT A NEW ONE AND THE CARBON COPIES WILL BE READABLE.",
		"models": ["dot"],
		"hard": 0,
	},
	{
		"error": "FORMS DRIFT DOWN THE PAGE",
		"options": ["SET TOP OF FORM, SEAT THE PINS", "REPLACE THE PRINT HEAD", "PRINT SMALLER"],
		"correct": 0,
		"hit": -1,
		"why": "THE FORM IS NOT ON THE TRACTOR PINS, OR THE TOP-OF-FORM IS WRONG. SQUARE IT UP AND SET IT.",
		"models": ["dot"],
		"hard": 1,
	},
	{
		"error": "COPY THREE IS BLANK",
		"options": ["MOVE THE HEAD GAP LEVER OUT", "ADD A RIBBON", "PRINT THREE TIMES"],
		"correct": 0,
		"hit": -1,
		"why": "A MULTI-PART FORM IS THICKER. THE HEAD GAP LEVER MUST BE SET WIDER SO THE LAST COPY GETS INKED.",
		"models": ["dot"],
		"hard": 2,
	},
	{
		"error": "NOTHING PRINTS FROM WINDOWS 7",
		"options": ["PICK THE USB TO PARALLEL PORT", "INSTALL XP", "HIT IT"],
		"correct": 0,
		"hit": 2,
		"why": "THE NEW PC HAS NO PARALLEL PORT. THE PRINTER NEEDS THE PORT OF ITS USB ADAPTER CABLE.",
		"models": ["dot"],
		"hard": 2,
	},
	{
		"error": "DRAWING PRINTS AT HALF SIZE",
		"options": ["SET THE SCALE TO 100 PERCENT", "ORDER A BIGGER ROLL", "REDRAW IT"],
		"correct": 0,
		"hit": -1,
		"why": "THE DRIVER IS ON FIT TO PAGE. SET THE SCALE TO 100 PERCENT AND CHOOSE THE RIGHT SHEET SIZE.",
		"models": ["plotter"],
		"hard": 0,
	},
	{
		"error": "50.2 FUSER ERROR",
		"options": ["LET IT COOL, POWER CYCLE", "REPLACE THE FUSER AT ONCE", "OPEN THE FUSER HOT"],
		"correct": 0,
		"hit": -1,
		"why": "A ONE-OFF FUSER ERROR OFTEN CLEARS AFTER COOLING. IF IT COMES BACK, REPLACE THE FUSER. NEVER OPEN IT HOT.",
		"models": ["laser", "mfp"],
		"hard": 2,
	},
	{
		"error": "BLACK STREAK DOWN EVERY PAGE",
		"options": ["CLEAN OR REPLACE THE DRUM", "ADD PAPER", "RESTART THE SPOOLER"],
		"correct": 0,
		"hit": -1,
		"why": "A SCRATCHED OR DIRTY DRUM PRINTS THE SAME LINE ON EVERY PAGE. CLEAN IT OR FIT A NEW ONE.",
		"models": ["laser", "mfp"],
		"hard": 1,
	},
]
var QUESTIONS: Array = DEFAULT_QUESTIONS.duplicate(true)

var is_open := false
var model := "laser"
var phase := ""
var mistakes := 0
var stars := 0
var msg := ""
var marker := 0.0
var zone := 0.5
var spot := 0
var jam_len := 3  # pulls in this chain (3 to 6): clean pulls shorten it, a torn scrap adds one
var combo := 0  # clean pulls in a row
var order: Array = []
var step := 0
var sel := 0
var shakes := 0
var asked: Array = []
var qi := 0
var faith := 3
var blessed := 0
var tray_sel := 0
var fast := false
var prayed := false
var tired := 1.0  # marker speed x: 1.0 to 1.15 on an onsite job when Shift says you are tired
var practice := false
var practice_seed := 1
var streak := 0  # pray-free wins in a row (saved with the campaign)

var _canvas: Node2D
var _callback := Callable()
var _prng: RandomNumberGenerator = null  # only in practice: the seed on the intro page rules
var _t := 0.0
var _dir := 1.0
var _shake_t := 0.0
var _last_shake := ""
var _answered := false
var _result_t := 0.0


func _ready() -> void:
	layer = 62
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)


func start(callback: Callable, flavour: String = "laser", opts: Dictionary = {}) -> void:
	_callback = callback
	model = flavour if MODELS.has(flavour) else "laser"
	practice = bool(opts.get("practice", false))
	practice_seed = clampi(int(opts.get("seed", 1)), 1, 99)
	tired = 1.0
	if bool(opts.get("onsite", false)):
		tired = 1.0 + clampf(Shift.slow_mult() - 1.0, 0.0, 0.5) * 0.3
	_prng = null
	if practice:
		_reseed()
	is_open = true
	Game.ui_open = true
	_canvas.visible = true
	phase = "intro"
	mistakes = 0
	stars = 0
	msg = ""
	spot = 0
	jam_len = 3
	combo = 0
	step = 0
	sel = 0
	qi = 0
	faith = 3
	blessed = 0
	tray_sel = 0
	fast = false
	prayed = false
	marker = 0.0
	_t = 0.0
	_answered = false
	_canvas.queue_redraw()


func _finish() -> void:
	is_open = false
	Game.ui_open = false
	_canvas.visible = false
	if _callback.is_valid():
		_callback.call(stars)


func _score() -> int:
	if mistakes <= 1:
		return 3
	if mistakes <= 3:
		return 2
	if mistakes <= 5:
		return 1
	return 0


# ---- models, texts, randomness
func _tx(key: String) -> String:
	var over: Dictionary = MODEL_TEXT.get(model, {})
	if over.has(key):
		return str(over[key])
	return str(TEXT.get(key, ""))


func _qs() -> Array:
	return QUESTIONS


func _m() -> Dictionary:
	return MODELS[model]


func _phases() -> Array:
	return _m().phases


func _tray() -> Array:
	return _m().tray


func _names() -> Array:
	return _m().names


func _colors() -> Array:
	return _m().colors


func _rng() -> RandomNumberGenerator:
	return _prng if _prng != null else Difficulty.rng("printer")


func _reseed() -> void:
	_prng = RandomNumberGenerator.new()
	_prng.seed = hash("%d:%s" % [practice_seed, model])


func _shuffle(list: Array) -> void:
	var r := _rng()
	for k in range(list.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = list[k]
		list[k] = list[j]
		list[j] = tmp


# the question indices that can come up on a model (no tier filter)
func pool_for(for_model: String) -> Array:
	var out := []
	for k in QUESTIONS.size():
		var tags: Array = QUESTIONS[k].get("models", [])
		if tags.is_empty() or tags.has(for_model):
			out.append(k)
	return out


func _prayers() -> Dictionary:
	return MODEL_PRAYERS.get(model, PRAYERS)


# ---- phases
func _begin_jam() -> void:
	phase = "jam"
	spot = 0
	combo = 0
	jam_len = clampi(Difficulty.i("printer.chain"), 3, 6)
	_new_zone()
	msg = _tx("jam_help")


func _new_zone() -> void:
	zone = _rng().randf_range(0.22, 0.78)
	marker = 0.0
	_dir = 1.0


func _begin_tray() -> void:
	phase = "tray"
	tray_sel = 0
	msg = _tx("tray_help")


# go on to the next round of this model (the test page is always the last)
func _advance(keep_msg := false) -> void:
	var keep := msg
	var list := _phases()
	var at := list.find(phase)
	var nxt := str(list[at + 1]) if at >= 0 and at + 1 < list.size() else "test"
	match nxt:
		"jam":
			_begin_jam()
		"tray":
			_begin_tray()
		"toner":
			_begin_toner()
		"shake":
			_begin_shake()
		_:
			_begin_test()
	if keep_msg:
		msg = keep


func _mistake() -> void:
	if blessed > 0:
		blessed -= 1
		msg += " THE GODS FORGIVE IT."
	else:
		mistakes += 1


func _pray() -> void:
	if faith <= 0:
		msg = _tx("pray_none")
		return
	faith -= 1
	prayed = true
	var p := _prayers()
	var r := _rng()
	var roll := r.randf()
	if roll < 0.55:
		blessed += 1
		msg = str(p.good[r.randi_range(0, p.good.size() - 1)])
	elif roll < 0.8:
		msg = str(p.meh[r.randi_range(0, p.meh.size() - 1)])
	elif roll < 0.92:
		mistakes += 1
		msg = str(p.bad[0])
	else:
		fast = true
		msg = str(p.bad[1]) if str(p.bad[1]).contains("SPEEDS UP") else str(p.bad[1]) + " THE MARKER SPEEDS UP."


func _begin_toner() -> void:
	phase = "toner"
	order = range(_names().size())
	_shuffle(order)
	step = 0
	sel = 0
	msg = _tx("toner_help")


func _begin_shake() -> void:
	phase = "shake"
	shakes = 0
	_shake_t = 5.0
	_last_shake = ""
	msg = _tx("shake_help")


func _begin_test() -> void:
	phase = "test"
	var elig := []
	var rest := []
	var level := Difficulty.tier_index()
	for k in pool_for(model):
		if int(QUESTIONS[k].get("hard", 0)) <= level:
			elig.append(k)
		else:
			rest.append(k)
	_shuffle(elig)
	_shuffle(rest)
	var pool := elig + rest
	asked = pool.slice(0, mini(Difficulty.i("printer.questions"), pool.size()))
	qi = 0
	_answered = false
	msg = _tx("test_help")


func _end() -> void:
	stars = _score()
	phase = "result"
	_result_t = 0.0
	msg = _tx("stars%d" % stars)
	_record()


# the pray-free streak: a win without a prayer adds one, a prayer or a lost run ends it
func _record() -> void:
	if stars >= 1 and not prayed:
		streak += 1
	else:
		streak = 0


func to_dict() -> Dictionary:
	return {"version": 1, "streak": streak}


func from_dict(data: Dictionary) -> void:
	streak = maxi(0, int(data.get("streak", 0)))


func reset() -> void:
	streak = 0


# ---- input
func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E:
			press("confirm")
		KEY_LEFT:
			press("left")
		KEY_RIGHT:
			press("right")
		KEY_UP:
			press("up")
		KEY_DOWN:
			press("down")
		KEY_A:
			press("a")
		KEY_D:
			press("d")
		KEY_1, KEY_2, KEY_3:
			press(str(event.keycode - KEY_0))
		KEY_P:
			press("pray")
		KEY_ESCAPE:
			press("escape")
		_:
			return
	get_viewport().set_input_as_handled()


func press(key: String) -> void:
	if not is_open:
		return
	if key == "escape":
		if phase == "result":
			return  # the result is kept
		if phase == "intro":
			stars = -1  # backed out before starting: no time is spent
			_finish()
			return
		stars = 0
		phase = "result"
		_result_t = 0.0
		msg = _tx("stars0")
		_record()
		_canvas.queue_redraw()
		return
	if key == "pray":
		if phase in ["intro", "jam", "tray", "toner", "shake", "test"]:
			_pray()
		_canvas.queue_redraw()
		return
	match phase:
		"intro":
			if key == "confirm":
				if practice:
					_reseed()
				_begin_jam()
			elif practice and key in ["left", "a", "right", "d"]:
				var at := MODEL_ORDER.find(model)
				var dir := -1 if key in ["left", "a"] else 1
				model = str(MODEL_ORDER[posmod(at + dir, MODEL_ORDER.size())])
				_reseed()
			elif practice and key in ["up", "down"]:
				practice_seed = clampi(practice_seed + (1 if key == "up" else -1), 1, 99)
				_reseed()
		"tray":
			if key in ["left", "a"]:
				tray_sel = posmod(tray_sel - 1, _tray().size())
			elif key in ["right", "d"]:
				tray_sel = posmod(tray_sel + 1, _tray().size())
			elif key == "confirm":
				_load_paper()
		"jam":
			if key == "confirm":
				_pull()
		"toner":
			var n := _names().size()
			if key in ["left", "a"]:
				sel = posmod(sel - 1, n)
			elif key in ["right", "d"]:
				sel = posmod(sel + 1, n)
			elif key == "confirm":
				_install()
		"shake":
			if key in ["a", "left", "d", "right"]:
				var side := "a" if key in ["a", "left"] else "d"
				if side != _last_shake:
					_last_shake = side
					shakes += 1
					if shakes >= 10:
						msg = ""
						_advance()
		"test":
			if not _answered and key in ["1", "2", "3"]:
				_answer(int(key) - 1)
			elif _answered and key == "confirm":
				_next_question()
		"result":
			if key == "confirm" and _result_t > 0.5:
				_finish()
	_canvas.queue_redraw()


func _load_paper() -> void:
	if tray_sel == 0:
		msg = _tx("tray_ok")
		_advance(true)
	elif tray_sel == 3 and _rng().randf() < 0.05:
		msg = _tx("tray_hit")
		_advance(true)
	else:
		msg = _tx("tray_bad")
		_mistake()


func _pull() -> void:
	var d := absf(marker - zone)
	var zw := Difficulty.f("printer.zone")
	if d <= (0.07 + 0.03 * float(mini(blessed, 2))) * zw:
		spot += 1
		combo += 1
		msg = _tx("jam_clean")
		if combo >= 2 and jam_len > 3 and jam_len - spot >= 2:
			jam_len -= 1
			combo = 0
			msg += " " + _tx("jam_short")
		_new_zone()
		if spot >= jam_len:
			_advance()
	elif d <= (0.16 + 0.04 * float(mini(blessed, 2))) * zw:
		msg = _tx("jam_hold")
	else:
		msg = _tx("jam_tear")
		combo = 0
		if jam_len < 6:
			jam_len += 1
			msg += " " + _tx("jam_scrap")
		_mistake()
		_new_zone()


func _install() -> void:
	if sel == int(order[step]):
		step += 1
		msg = _tx("toner_ok")
		if step >= _names().size():
			_advance(true)
	else:
		msg = _tx("toner_bad")
		_mistake()


func _answer(choice: int) -> void:
	var q: Dictionary = _qs()[int(asked[qi])]
	_answered = true
	if choice == int(q.correct):
		msg = _tx("right") + " " + str(q.why)
	elif choice == int(q.hit) and _rng().randf() < 0.05:
		msg = _tx("hit")
	else:
		msg = _tx("wrong") + " " + str(q.why)
		_mistake()


func _next_question() -> void:
	qi += 1
	_answered = false
	if qi >= asked.size():
		_end()
	else:
		msg = _tx("test_help")


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	_result_t += delta
	if phase == "jam":
		var speed := Difficulty.f("printer.speed") * tired
		marker += _dir * delta * (0.8 + 0.3 * float(mini(spot, 4))) * speed * (1.5 if fast else 1.0)
		if marker >= 1.0:
			marker = 1.0
			_dir = -1.0
		elif marker <= 0.0:
			marker = 0.0
			_dir = 1.0
	elif phase == "shake":
		_shake_t -= delta
		if _shake_t <= 0.0:
			msg = _tx("shake_late")
			_mistake()
			_advance(true)
	_canvas.queue_redraw()


# ---- drawing
var _o := Vector2.ZERO
var _pw := PW


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	_canvas.draw_rect(Rect2(_o + Vector2(x, y), Vector2(w, h)), c)


func _txt(s: String, x: float, y: float, c: Color = INK, scale := 1) -> void:
	PixelFont.draw(_canvas, s, _o + Vector2(x, y), c, scale)


func _wrap(s: String, chars: int) -> Array:
	var lines := []
	var cur := ""
	for w in s.split(" "):
		if cur != "" and cur.length() + 1 + w.length() > chars:
			lines.append(cur)
			cur = w
		else:
			cur = (cur + " " + w).strip_edges()
	if cur != "":
		lines.append(cur)
	return lines


func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.7))
	var panel := UiStyle.panel_rect(size, PW, PH)
	_o = panel.position
	_pw = panel.size.x
	var note := "MISTAKES %d" % mistakes
	if phase != "result":
		note += "  PRAY %d" % faith
	UiStyle.panel(_canvas, panel, _tx("title"), note)
	if blessed > 0 and phase != "result":
		_txt(str(TEXT.blessed_tag), PW - 32.0, 10, Color("1f7a3a"))
	match phase:
		"intro":
			_paint_intro()
		"jam":
			_paint_jam()
		"tray":
			_paint_tray()
		"toner":
			_paint_toner()
		"shake":
			_paint_shake()
		"test":
			_paint_test()
		"result":
			_paint_result()
	if phase != "result":
		var lines := _wrap(msg, int((panel.size.x - 8.0) / 4.0))
		for i in mini(lines.size(), 3):
			_txt(
				str(lines[i]),
				4,
				panel.size.y - 9.0 - float(mini(lines.size(), 3) - i) * 7.0,
				UiStyle.MUTED
			)
	UiStyle.footer(_canvas, panel, _hint())


# the same KEY = ACTION hint line the outing pages use
func _hint() -> String:
	match phase:
		"intro":
			return _tx("intro3")
		"jam":
			return "SPACE = PULL  P = PRAY  ESC = GIVE UP"
		"tray":
			return "LEFT / RIGHT  SPACE = LOAD  P = PRAY"
		"toner":
			return "LEFT / RIGHT  SPACE = FIT  P = PRAY"
		"shake":
			return "A / D = SHAKE  P = PRAY  ESC = GIVE UP"
		"test":
			return (
				"SPACE = NEXT  ESC = GIVE UP" if _answered else "1 / 2 / 3 = ANSWER  ESC = GIVE UP"
			)
	return _tx("done")


# the printer, drawn in 160 x 40 at y: every model has its own shape
func _printer(y: float) -> void:
	var cols := _colors()
	match str(_m().look):
		"inkjet":
			_r(30, y, 116, 6, PAPER)  # the sheet in the rear feed
			_r(8, y + 6, 160, 30, Color("e8e2d0"))
			_r(8, y + 6, 160, 3, Color("fbf8ee"))
			_r(12, y + 14, 152, 14, Color("2e3138"))
			_r(52, y + 31, 72, 5, Color("2e3138"))  # the output tray
			for i in 4:
				_r(24.0 + 38.0 * float(i), y + 17, 26, 8, cols[i])
		"plotter":
			_r(8, y, 160, 22, Color("d5d8de"))
			_r(8, y, 160, 3, Color("f2f4f8"))
			_r(12, y + 8, 152, 8, Color("2e3138"))
			_r(26, y + 22, 5, 18, Color("8e939e"))  # the stand
			_r(145, y + 22, 5, 18, Color("8e939e"))
			_r(44, y + 22, 88, 16, PAPER)  # the plot hanging out
			_r(44, y + 22, 88, 1, Color("9aa7b8"))
			_r(52, y + 28, 30, 1, Color("2fa7d8"))
			_r(52, y + 32, 60, 1, Color("8a8f9a"))
		"mfp":
			_r(8, y, 160, 8, Color("9fb4c8"))  # the scanner lid and glass
			_r(8, y, 160, 2, Color("d4e2ee"))
			_r(8, y + 8, 160, 32, Color("c9cdd6"))
			_r(8, y + 37, 160, 3, Color("8e939e"))
			_r(12, y + 13, 152, 18, Color("2e3138"))
			_r(18, y + 16, 30, 11, Color("3a6a42"))  # the little display
			for i in 4:
				_r(60.0 + 22.0 * float(i), y + 17, 16, 9, Color("6a6f7a"))
		"receipt":
			_r(52, y + 6, 72, 32, Color("e3e0d6"))
			_r(52, y + 6, 72, 3, Color("fbf8ee"))
			_r(56, y + 14, 64, 8, Color("2e3138"))  # the slot
			_r(70, y + 22, 36, 16, PAPER)  # the receipt
			for i in 4:
				_r(70.0 + 9.0 * float(i), y + 36, 5, 2, PAPER)  # the torn edge
			_r(60, y, 56, 6, Color("8e939e"))  # the lid
			_canvas.draw_circle(_o + Vector2(114.0, y + 12.0), 2.0, Color("e04a3a"))
		"dot":
			_r(34, y, 108, 12, PAPER)  # the form coming up
			for i in 5:
				_r(36, y + 1.0 + 2.0 * float(i), 2, 1, Color("8a8f9a"))  # pinfeed holes
				_r(138, y + 1.0 + 2.0 * float(i), 2, 1, Color("8a8f9a"))
			_r(8, y + 12, 160, 26, Color("d9d2b8"))
			_r(8, y + 12, 160, 3, Color("efe9d2"))
			_r(8, y + 35, 160, 3, Color("a89f84"))
			_r(20, y + 19, 136, 8, Color("3b3a36"))  # the carriage track
			_r(80, y + 16, 14, 12, Color("2a2a33"))  # the head
		_:
			_r(8, y, 160, 40, Color("c9cdd6"))
			_r(8, y, 160, 3, Color("f2f4f8"))
			_r(8, y + 37, 160, 3, Color("8e939e"))
			_r(12, y + 8, 152, 24, Color("2e3138"))
			for i in 4:
				_canvas.draw_circle(_o + Vector2(32.0 + 40.0 * float(i), y + 20.0), 7.0, Color("6a6f7a"))
				_canvas.draw_circle(_o + Vector2(32.0 + 40.0 * float(i), y + 20.0), 3.0, Color("4a4f5a"))


func _paint_intro() -> void:
	_printer(16)
	var lines := [_tx("intro1"), _tx("intro2")]
	for i in lines.size():
		_txt(str(lines[i]), 4, 58.0 + float(i) * 7.0)
	var y := 74.0
	if practice:
		_txt(
			"< %s >  SEED %02d" % [str(_m().label), practice_seed],
			4,
			y,
			UiStyle.HEAD
		)
		_txt(_tx("practice_help"), 4, y + 7.0, UiStyle.MUTED)
		y += 14.0
	if tired > 1.01:
		_txt(_tx("tired_note") % int(roundf((tired - 1.0) * 100.0)), 4, y, Color("c0392b"))


func _paint_jam() -> void:
	_printer(14)
	var n := jam_len
	var w := minf(28.0, 160.0 / float(n) - 4.0)
	for i in n:
		var x := 8.0 + (float(i) + 0.5) * 160.0 / float(n)
		if i < spot:
			_r(x - w * 0.5, 28, w, 5, PAPER)
		else:
			var bits := maxi(2, int(w / 5.0))
			for k in bits:
				var bx := x - w * 0.5 + float(k) * w / float(bits)
				_r(bx, 24.0 + float((k + i) % 3) * 3.0, w / float(bits) + 1.0, 9, PAPER)
				_r(bx, 24.0 + float((k + i) % 3) * 3.0, w / float(bits) + 1.0, 1, Color("c9c3b2"))
	_txt("PULLED %d OF %d" % [spot, jam_len], 8, 58)
	if tired > 1.01:
		_txt(_tx("tired_tag"), 80, 58, Color("c0392b"))
	_r(16, 74, 144, 10, Color("8a8f9a"))
	var zw := Difficulty.f("printer.zone")
	_r(16.0 + 144.0 * (zone - 0.16 * zw), 74, 144.0 * 0.32 * zw, 10, Color("f2c94c"))
	_r(16.0 + 144.0 * (zone - 0.07 * zw), 74, 144.0 * 0.14 * zw, 10, Color("4cff7a"))
	_r(16.0 + 144.0 * marker - 1.0, 71, 3, 16, INK)


func _paint_tray() -> void:
	_r(10, 14, 156, 20, Color("14301c"))
	_r(12, 16, 152, 16, Color("3a6a42"))
	_txt(_tx("tray_screen"), 16, 21, Color("d8f8d8"), 1)
	_txt(_tx("tray_slot"), 160.0 - float(_tx("tray_slot").length()) * 4.0, 21, Color("d8f8d8"), 1)
	for i in _tray().size():
		var x := 12.0 + 38.0 * float(i)
		_r(x, 40, 34, 28, INK)
		_r(x + 1, 41, 32, 26, PAPER if i < 3 else Color("c9cdd6"))
		if i < 3:
			for k in 3:
				_r(x + 5, 46.0 + float(k) * 5.0, 24.0 - float(i) * 2.0, 1, Color("8a8f9a"))
		_txt(str(_tray()[i]).substr(0, 8), x + 3, 58, INK)
		if i == tray_sel:
			_r(x - 2, 38, 38, 2, Color("ff6a3a"))
			_r(x - 2, 68, 38, 2, Color("ff6a3a"))


func _paint_toner() -> void:
	var n := _names().size()
	var x0 := (PW - (40.0 * float(n) - 10.0)) * 0.5
	for i in n:
		var x := x0 + 40.0 * float(i)
		_r(x, 24, 30, 36, INK)
		_r(x + 1, 25, 28, 34, _colors()[i])
		_r(x + 3, 28, 24, 5, Color(1, 1, 1, 0.35))
		_txt(str(_names()[i]).substr(0, 4), x + 2, 50, Color.WHITE if i != 2 or n < 4 else INK)
		if i == sel:
			_r(x - 2, 22, 34, 2, Color("ff6a3a"))
			_r(x - 2, 60, 34, 2, Color("ff6a3a"))
	if step < n:
		_txt("INSTALL: " + str(_names()[int(order[step])]), 8, 70, INK, 1)
	for i in n:
		_r(
			160.0 - 10.0 * float(n) + 10.0 * float(i),
			70,
			7,
			7,
			_colors()[int(order[i])] if i < step else Color("8a8f9a")
		)


func _paint_shake() -> void:
	var off := sin(_t * 30.0) * 3.0
	_r(70.0 + off, 22, 36, 44, INK)
	_r(71.0 + off, 23, 34, 42, _colors().back())
	_r(75.0 + off, 27, 26, 5, Color(1, 1, 1, 0.3))
	_r(16, 72, 144, 7, Color("8a8f9a"))
	_r(16, 72, 144.0 * float(shakes) / 10.0, 7, Color("4cff7a"))
	_r(16, 82, 144.0 * clampf(_shake_t / 5.0, 0.0, 1.0), 3, Color("ff6a3a"))


func _paint_test() -> void:
	var q: Dictionary = _qs()[int(asked[qi])]
	_r(10, 14, 156, 22, Color("14301c"))
	_r(12, 16, 152, 18, Color("3a6a42"))
	_txt(str(q.error), 16, 22, Color("d8f8d8"), 1)
	for i in 3:
		_txt("%d  %s" % [i + 1, str(q.options[i])], 10, 42.0 + float(i) * 8.0)


func _paint_result() -> void:
	UiStyle.stars(_canvas, _o.x + _pw * 0.5, _o.y + 12.0, stars)
	var y := 36.0
	for part in _wrap(msg, int((PW - 8.0) / 4.0)):
		_txt(str(part), 4, y)
		y += 7.0
	_txt("MISTAKES %d" % mistakes, 4, y + 3.0, UiStyle.HEAD)
	if streak >= 2:
		_txt(_tx("streak") % streak, 4, y + 10.0, UiStyle.GOLD)
