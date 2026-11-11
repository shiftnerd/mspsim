extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R8 / R16: the campaign's calendar and its seasons. A static helper (no state of its own: what was already shown is in
# Story.flags["season_seen"], saved with the campaign).
#
# The calendar: a run is one year in 20 units (days or weeks), from NOVEMBER 2013 to OCTOBER 2014 (Year 2: 2014-15).
# Unit u is month (u - 1) * 12 / 20 of that year: 1-2 NOV, 3-4 DEC, 5 JAN, 6-7 FEB, 8-9 MAR, 10 APR, 11-12 MAY,
# 13-14 JUN, 15 JUL, 16-17 AUG, 18-19 SEP, 20 OCT. The story fits: Morgan's Windows XP mail of day 4 is a warning in
# December, the old "tax season" deck card sits in February to April.
#
# A SEASON is a span of units with a tag. Tags do three things:
#  - deck cards and vignettes with a tag are only in the event deck's pool in season (Events.pool asks in_season();
#    the draw itself still uses the seeded `events` stream). CARDS below are seasonal cards; TAGS tags existing ones.
#  - one CALENDAR EVENT per season (EVENTS): a card at a fixed unit and time, announced on the HUD's next-up list
#  - small office dressing on the main floor while the season runs (OfficeDecor draws dressing())
# Free Play has no calendar (no season, no dressing).

const MONTHS := ["NOV", "DEC", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT"]
const FIRST_YEAR := 2013
const LAST_SHIFT := 1  # how many years the calendar may move on from 2013-14 (Year 2 does; Year 3 stays where Year 2 was)
# id -> name, first and last unit, year (0 = every year, 1 = the first year only), dressing (what OfficeDecor draws)
const SEASONS := {
	"holidays": {"name": "THE HOLIDAYS", "from": 3, "to": 4, "year": 0, "dressing": "lights"},
	"tax": {"name": "TAX SEASON", "from": 6, "to": 10, "year": 0, "dressing": "boxes"},
	"xp": {"name": "XP END OF SUPPORT", "from": 9, "to": 10, "year": 1, "dressing": "countdown"},
	"school": {"name": "BACK TO SCHOOL", "from": 17, "to": 18, "year": 0, "dressing": "drive"},
}
# existing deck cards and vignettes that only make sense in a season: id -> season
const TAGS := {"tax_season": "tax"}
# the season of each card in CARDS and each event in EVENTS
const CARD_SEASON := {
	"xmas_ecard": "holidays", "holiday_phones": "holidays", "tax_printer": "tax", "tax_updates": "tax",
	"xp_six": "xp", "xp_sticker": "xp", "school_laptops": "school", "school_talk": "school",
	"potluck": "holidays", "tax_basket": "tax", "xp_day": "xp", "supply_drive": "school",
}
# the calendar events: id -> [unit, clock]
const EVENT_AT := {"potluck": [4, 12.2], "tax_basket": [8, 11.0], "xp_day": [10, 11.0], "supply_drive": [18, 11.5]}
const EVENT_NAMES := {"potluck": "HOLIDAY POTLUCK", "tax_basket": "A BASKET ARRIVES", "xp_day": "XP SUPPORT ENDS", "supply_drive": "SUPPLY DRIVE"}
const DROP_AT := 15.5  # a calendar event still waiting at this time is dropped for the year

# seasonal cards for the event deck (the same shape as Events.DECK cards; min_day / max_day equal the season)
const DEFAULT_CARDS := {
	"xmas_ecard":
	{
		"id": "xmas_ecard", "kinds": ["both"], "min_day": 3, "max_day": 4, "weight": 1.6, "cooldown": 99, "requires": [],
		"speaker": "A receptionist at a client",
		"text": "Somebody opened a dancing elf e-card and now every screen up front has a toolbar nobody ordered. She says the elf looked trustworthy.",
		"options":
		[
			{
				"id": "clean", "label": "CLEAN THE MACHINES AND LEAVE THE ELF OUT OF IT",
				"text": "Forty minutes and three toolbars later they are computers again. The elf was from her sister.",
				"fx": {"xp": ["security", 2], "mood_all": 1, "hours": 0.4}
			},
			{
				"id": "block", "label": "BLOCK THE E-CARD SITES AT THE FIREWALL",
				"text": "Nobody notices until Valentine's Day.",
				"fx": {"xp": ["networking", 2]}
			},
		]
	},
	"holiday_phones":
	{
		"id": "holiday_phones", "kinds": ["both"], "min_day": 3, "max_day": 4, "weight": 1.6, "cooldown": 99, "requires": [],
		"speaker": "{c}",
		"text": "Half our clients close between the holidays. Somebody still has to watch the phones on the 26th, and everybody is looking at their shoes.",
		"options":
		[
			{
				"id": "me", "label": "TAKE THE 26TH. IT WILL BE QUIET",
				"text": "It is quiet. One call, about a printer, from a man who is also the only one in his building.",
				"fx": {"social": {"{c}": 2}, "rep": 1}
			},
			{
				"id": "split", "label": "SPLIT IT INTO HALF DAYS",
				"text": "Fair, and everybody still gets leftovers.",
				"fx": {"social_all": 1}
			},
			{
				"id": "vm", "label": "LET THE VOICEMAIL WORK FOR ONCE",
				"text": "The voicemail does fine. It has no family.",
				"fx": {}
			},
		]
	},
	"tax_printer":
	{
		"id": "tax_printer", "kinds": ["both"], "min_day": 6, "max_day": 10, "weight": 1.4, "cooldown": 99, "requires": [],
		"speaker": "A bookkeeper at a client",
		"text": "The check printer started printing every return one line too low. It is the worst week of the year for that, and I would like you to know that I know that.",
		"options":
		[
			{
				"id": "now", "label": "DROP EVERYTHING AND FIX IT NOW",
				"text": "A tray setting. She watches you fix it like a hawk and then offers you a mint.",
				"fx": {"mood_all": 2, "hours": 0.3}
			},
			{
				"id": "talk", "label": "TALK HER THROUGH THE TRAY SETTINGS",
				"text": "It takes twice as long and she learns where the setting is. That is worth something in April.",
				"fx": {"xp": ["people", 2], "mood_all": 1}
			},
		]
	},
	"tax_updates":
	{
		"id": "tax_updates", "kinds": ["both"], "min_day": 6, "max_day": 10, "weight": 1.4, "cooldown": 99, "requires": [],
		"speaker": "The accountant at a client",
		"text": "We file on the fifteenth and the server wants to install updates tonight. I am not asking a question. I am telling you how nervous I am.",
		"options":
		[
			{
				"id": "hold", "label": "HOLD THE UPDATES UNTIL THE 16TH",
				"text": "Nothing restarts. He sends a one-word thank-you, which from him is a parade.",
				"fx": {"mood_all": 1}
			},
			{
				"id": "patch", "label": "PATCH TONIGHT, AFTER A GOOD BACKUP",
				"text": "It goes fine, and you were awake to see it.",
				"fx": {"xp": ["servers", 3], "hours": 0.5}
			},
		]
	},
	"xp_six":
	{
		"id": "xp_six", "kinds": ["both"], "min_day": 9, "max_day": 10, "weight": 1.8, "cooldown": 99, "requires": [],
		"speaker": "An office manager at a client",
		"text": "The article says our old computers stop being safe on April 8. We have six. One of them runs the label printer and nobody remembers how.",
		"options":
		[
			{
				"id": "plan", "label": "WRITE A REPLACEMENT PLAN, OLDEST FIRST",
				"text": "Five get a date. The label machine gets a firewall rule and a note that says DO NOT TOUCH.",
				"fx": {"xp": ["security", 3], "mood_all": 1}
			},
			{
				"id": "quote", "label": "SEND A QUOTE FOR SIX NEW MACHINES",
				"text": "They buy four. The other two will think about it until they catch something.",
				"fx": {"mood_all": 1}
			},
		]
	},
	"xp_sticker":
	{
		"id": "xp_sticker", "kinds": ["both"], "min_day": 9, "max_day": 10, "weight": 1.4, "cooldown": 99, "requires": [],
		"speaker": "{c}",
		"text": "I found a roll of DESIGNED FOR WINDOWS XP stickers in the supply closet. I have been putting them on things that are not computers.",
		"options":
		[
			{
				"id": "join", "label": "PUT ONE ON THE COFFEE MACHINE",
				"text": "It has never been more accurate. The coffee machine is also out of support.",
				"fx": {"social": {"{c}": 2}}
			},
			{
				"id": "save", "label": "SAVE ONE FOR THE LAST XP BOX",
				"text": "A small ceremony is planned. Somebody will say a few words.",
				"fx": {"social_all": 1}
			},
		]
	},
	"school_laptops":
	{
		"id": "school_laptops", "kinds": ["both"], "min_day": 17, "max_day": 18, "weight": 1.6, "cooldown": 99, "requires": [],
		"speaker": "A front desk manager at a client",
		"text": "Three of us have kids starting school and three family laptops showed up at the office this morning. They are acting slow. One has a sticker of a horse on it.",
		"options":
		[
			{
				"id": "lunch", "label": "CLEAN THEM UP OVER LUNCH",
				"text": "Fourteen toolbars between the three. The horse one was the cleanest.",
				"fx": {"mood_all": 2, "hours": 0.5}
			},
			{
				"id": "tips", "label": "SEND A SHORT LIST OF WHAT TO UNINSTALL",
				"text": "Two of three follow it. The third laptop comes back in October.",
				"fx": {"xp": ["people", 2]}
			},
			{
				"id": "no", "label": "POLITELY POINT AT THE AGREEMENT",
				"text": "They understand. They also remember.",
				"fx": {"mood_all": -1}
			},
		]
	},
	"school_talk":
	{
		"id": "school_talk", "kinds": ["both"], "min_day": 17, "max_day": 18, "weight": 1.4, "cooldown": 99, "requires": [],
		"speaker": "{c}",
		"text": "A school counselor called. They want somebody to tell a class what working with computers is like. I said you, because you still remember being confused.",
		"options":
		[
			{
				"id": "go", "label": "DO IT. TWENTY MINUTES, ONE SLIDE",
				"text": "The kids ask if you have ever met a hacker. You say yes, in a print queue. Only the teacher laughs.",
				"fx": {"rep": 1, "hours": 0.5}
			},
			{
				"id": "send", "label": "SEND A BOX OF DEAD HARD DRIVES INSTEAD",
				"text": "The drives are a hit. One comes back missing.",
				"fx": {"social": {"{c}": 1}}
			},
		]
	},
}
static var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)

# the calendar events (one per season, at EVENT_AT): the same card shape, shown by tick()
const DEFAULT_EVENTS := {
	"potluck":
	{
		"id": "potluck", "kinds": ["both"], "min_day": 4, "max_day": 4, "weight": 1.0, "cooldown": 99, "requires": [],
		"speaker": "The office",
		"text": "The holiday potluck is on the conference table. There are four trays of the same meatballs and one salad nobody will admit to.",
		"options":
		[
			{
				"id": "stay", "label": "FILL A PLATE AND STAY A WHILE",
				"text": "You hear about a cruise from 2009 and the correct way to load a dishwasher. It is nice.",
				"fx": {"social_all": 2, "hours": 0.5}
			},
			{
				"id": "cookies", "label": "PUT OUT THE COOKIES YOU BROUGHT",
				"text": "Gone in six minutes. Somebody asks for the recipe and you say it is from a box.",
				"fx": {"social_all": 2}
			},
			{
				"id": "desk", "label": "TAKE A PLATE BACK TO YOUR DESK",
				"text": "The meatballs are fine. The queue does not care what day it is.",
				"fx": {"social_all": 1}
			},
		]
	},
	"tax_basket":
	{
		"id": "tax_basket", "kinds": ["both"], "min_day": 8, "max_day": 8, "weight": 1.0, "cooldown": 99, "requires": [],
		"speaker": "A delivery",
		"text": "A fruit basket arrived from an accounting client. The card says: for keeping us running in the worst month. Please do not let anything break until the 16th.",
		"options":
		[
			{
				"id": "share", "label": "PUT IT IN THE KITCHENETTE FOR EVERYONE",
				"text": "The pears go first. The card goes on the fridge.",
				"fx": {"social_all": 1, "mood_all": 1}
			},
			{
				"id": "call", "label": "CALL AND SAY THANK YOU",
				"text": "They are surprised anybody calls about fruit. It lands well.",
				"fx": {"mood_all": 2}
			},
		]
	},
	"xp_day":
	{
		"id": "xp_day", "kinds": ["both"], "min_day": 10, "max_day": 10, "weight": 1.0, "cooldown": 99, "requires": [],
		"speaker": "The office",
		"text": "April 8. Support for Windows XP ends today. Somebody printed a banner on the plotter and taped it over the oldest machine in the building: YOU HAD A GOOD RUN.",
		"options":
		[
			{
				"id": "words", "label": "SAY A FEW WORDS",
				"text": "You thank it for starting every morning since 2003. People clap. It does not shut down properly, one last time.",
				"fx": {"social_all": 2}
			},
			{
				"id": "chase", "label": "USE THE DAY TO CHASE THE LAST XP MACHINES",
				"text": "Three clients finally sign off on replacements. Fear works where reminders did not.",
				"fx": {"xp": ["security", 3], "mood_all": 2}
			},
		]
	},
	"supply_drive":
	{
		"id": "supply_drive", "kinds": ["both"], "min_day": 18, "max_day": 18, "weight": 1.0, "cooldown": 99, "requires": [],
		"speaker": "The office",
		"text": "There is a box by the door for the school supply drive. So far it holds one glue stick and a mouse pad from a vendor.",
		"options":
		[
			{
				"id": "buy", "label": "PICK UP A BAG OF SUPPLIES AT LUNCH",
				"text": "Pencils, notebooks and the good scissors. The box looks respectable now.",
				"fx": {"social_all": 2, "hours": 0.3}
			},
			{
				"id": "swag", "label": "DONATE FROM THE VENDOR SWAG DRAWER",
				"text": "Forty pens and nine stress balls. Some classroom is about to be very well branded.",
				"fx": {"social_all": 1}
			},
		]
	},
}
static var EVENTS: Dictionary = DEFAULT_EVENTS.duplicate(true)


# ---- the calendar -----------------------------------------------------------------------------------
static func month_index(unit: int) -> int:
	return clampi(int(float(maxi(unit, 1) - 1) * 12.0 / float(Campaign.TOTAL_DAYS)), 0, 11)


static func month(unit: int) -> String:
	return str(MONTHS[month_index(unit)])


# "DEC 2013" (Year 2 runs a year later). R10: Year 3 does not: the calendar stops at Year 2's (LAST_SHIFT), so the
# date line never leaves the era the game is written in, and a third year is "another year at Pixel IT"
static func date_text(unit := -1, year := -1) -> String:
	var u := Campaign.day if unit < 0 else unit
	var y := Campaign.year if year < 0 else year
	var m := month_index(u)
	return "%s %d" % [MONTHS[m], FIRST_YEAR + (0 if m < 2 else 1) + clampi(y - 1, 0, LAST_SHIFT)]


# the season tags of a unit (in SEASONS order); year 1, 2 or 3 (a "first year only" season is in neither later year)
static func tags(unit: int, year := 1) -> Array:
	var out := []
	for id in SEASONS:
		var s: Dictionary = SEASONS[id]
		if unit >= int(s.from) and unit <= int(s.to) and (int(s.year) == 0 or int(s.year) == year):
			out.append(str(id))
	return out


# today's seasons; none outside a campaign
static func current() -> Array:
	if not Campaign.active:
		return []
	return tags(Campaign.day, Campaign.year)


static func season_name(id: String) -> String:
	return str(SEASONS.get(id, {}).get("name", ""))


# the season a deck card or vignette belongs to ("" = all year)
static func season_of(id: String) -> String:
	return str(CARD_SEASON.get(id, TAGS.get(id, "")))


# may this card be drawn on this unit? Untagged cards always, tagged ones only in their season
static func in_season(id: String, unit: int, year := 1) -> bool:
	var s := season_of(id)
	return s == "" or tags(unit, year).has(s)


# what OfficeDecor draws today: the dressing names of the running seasons
static func dressing() -> Array:
	var out := []
	for id in current():
		out.append(str(SEASONS[id].dressing))
	return out


# ---- the calendar events ------------------------------------------------------------------------------
# today's calendar event that has not been shown yet: {id, at, name}, or {}
static func event_today() -> Dictionary:
	if not Campaign.active:
		return {}
	var seen: Dictionary = Story.flags.get("season_seen", {})
	for id in EVENT_AT:
		if int(EVENT_AT[id][0]) != Campaign.day or seen.has(id):
			continue
		if not tags(Campaign.day, Campaign.year).has(season_of(str(id))):
			continue
		return {"id": str(id), "at": float(EVENT_AT[id][1]), "name": str(EVENT_NAMES[id])}
	return {}


static func _mark(id: String) -> void:
	var seen: Dictionary = Story.flags.get("season_seen", {})
	seen[id] = Campaign.day
	Story.flags["season_seen"] = seen


# called every frame by Events._process: shows today's calendar event at its time, at a calm moment
static func tick() -> void:
	if not Campaign.active or Game.title_mode:
		return
	var ev := event_today()
	if ev.is_empty() or World.clock < float(ev.at):
		return
	if World.clock >= DROP_AT:
		_mark(str(ev.id))  # the day got away (a trip, a long job): not this year
		return
	if World.time_scale <= 0.0 or Cards.is_open or Cards.waiting() > 0 or Game.ui_open:
		return
	if Expo.away or Onsite.busy or Outings.busy() or DayReport.is_open:
		return
	_mark(str(ev.id))
	show_event(str(ev.id))


static func show_event(id: String) -> void:
	var card: Dictionary = EVENTS.get(id, {})
	if card.is_empty():
		return
	var people: Array = Events.roster()
	var c: Dictionary = Events.resolve(card, "" if people.is_empty() else str(people[0]))
	var options := []
	for o in c.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.art_next = Events.art_for(id)
	Cards.ask(str(c.speaker), str(c.text), options, func(pick: String) -> void: Events._answer(c, pick))
