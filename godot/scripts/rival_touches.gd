extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P6: the light touches (docs/scope-bad-habits.md section 1, phase P6). A static helper like Rival and Habits, no state of its own.
# - Talk and Lynk lines: Alan, Garrison, Dan, Maya, John and Christy react to the rival and to the player's Standard band and conscience band.
#   Words only: no numbers, no scores. state_key() picks which line applies; talk_line / lynk_note / marge_line read the tables.
# - Forum and IRC gating: needs strings of the form "rap:<rival>:<habit>" (optional ":<level>", default 1 = RUMOUR) read the rap sheet.
# - The tech campaign freezer bag tip, the service campaign green dashboard note (Knowledge), Year 2 (the Standard at 60 percent and a new rival).
# Ideas only from the blog series the doc credits: no names, scenes or lines from it. Text: the 3x5 font charset, 2013-14, no AI, no MFA.

const Rival := preload("res://scripts/rival.gd")
const Habits := preload("res://scripts/habits.gd")
const Temptation := preload("res://scripts/temptation.gd")

const RIVAL := "bigcheese"
const SAME_AGAIN_DAYS := 4  # a coworker does not repeat a note for this many owner weeks
const YEAR2_STANDARD := 0.6  # the share of last year's Standard that comes over

# who -> state key -> what they say at their desk (Talk: ANY IDEAS? in the owner campaign). Keys: rival (the rival is known), bare (rival known
# and the Standard is BARE or PATCHY), solid, showcase, loose (a few loose ends), closet (skeletons or a closet full).
const DEFAULT_TALK := {
	"Alan":
	{
		"rival":
		"That Big Cheese flyer is on every windshield in the lot. Everything included, no list of what everything is. A restore test is not free, and he does not price it.",
		"bare":
		"Big Cheese is the loud one, I know. But our own checklist has more empty boxes than ticks. Fix that first and then go fight him.",
		"solid":
		"The checklist is mostly ticked and the restores pass. Boring is good. Boring is what I get paid for.",
		"showcase":
		"Every box ticked, a restore tested, the change notes written. I would not say it out loud, but I am proud of this shop.",
		"loose":
		"Christy has a folder I do not love. Nothing is on fire. Yet. Clean up what you can before it clears its throat.",
		"closet":
		"I did not sleep. That folder has our name on every page. Pick one, pay it, then pick the next. I will help.",
	},
	"Garrison":
	{
		"rival":
		"Rex Calloway shook my hand for ten whole seconds at the Chamber lunch. A man who shakes that long is selling something. Find out what.",
		"bare":
		"We talk about trust all day and our own house is half built. A client who asks for proof should get a page, not a speech.",
		"solid":
		"Clients are noticing the one page reports. Nobody has ever called me to say thank you for the invoice, and two did this month.",
		"showcase":
		"Rex has a billboard. We have a Standard people can read in one page. I know which one I would rather defend at the Chamber.",
		"loose":
		"People remember a shortcut longer than a favour. Whatever is in that folder, I would rather we told them first.",
		"closet":
		"I cannot look a client in the eye this week. The deals are good and the books are not. We fix the books. Not negotiable.",
	},
	"Dan":
	{
		"rival":
		"I drove past a Big Cheese van. Ladder on the roof, nothing in the back. I count that as information.",
		"bare":
		"I cannot find half of our own cable labels. Before you judge a rival's closet, let me show you ours.",
		"solid":
		"Every rack I touch now has a label and a map. It takes a day to set up and saves three.",
		"showcase":
		"I took a photo of every closet this quarter. If I fall off the ladder, someone else can find the switch.",
		"loose":
		"I found a default password on a camera and told Christy. I wrote it down so it counts.",
		"closet":
		"There is a lot we did not write down. I have started a list. It is longer than I would like.",
	},
	"Maya":
	{
		"rival":
		"Clients keep asking me if we are the more expensive ones. I say we are the ones who can tell them what is not in the price.",
		"bare":
		"I like it when we can hand a client a page and say, here is what we do. We cannot do that yet. I would like to.",
		"solid":
		"The quarterly page is working. People used to ask what they were paying for. Now they ask what is next.",
		"showcase":
		"A client told me we are the only ones who tell her about the bad news first. I wrote that on a sticky note and kept it.",
		"loose":
		"A couple of clients have gone quiet. The quiet ones are the ones to call. Start with the ones we shortchanged.",
		"closet":
		"If one of these comes out, it will not be the money that hurts. It will be the phone calls. Let me help you make them.",
	},
	"John":
	{
		"rival":
		"Rex told three prospects we are the expensive option. I told them to ask him what a restore costs. They went quiet. I like quiet.",
		"bare":
		"I cannot sell what we do not do. Every habit you add is a line I can say out loud at a meeting.",
		"solid":
		"Prospects love the one page. It makes me look organized. Do not tell Garrison I said so.",
		"showcase":
		"I used the Standard in a pitch today. The owner asked if she could keep the page. She did not ask about price once.",
		"loose":
		"I am not saying anything. I am just saying that if a client asks me about a bill, I will tell the truth.",
		"closet":
		"I was going to bring a deal over the line today. I looked at that folder and went for a coffee instead.",
	},
}
static var TALK: Dictionary = DEFAULT_TALK.duplicate(true)

# who -> state key -> a text they send you (Lynk, owner campaign). Christy is the controller and has no desk talk, only these.
const DEFAULT_LYNK := {
	"Alan":
	{
		"rival": "Saw the Big Cheese van at the diner again. Eating well. Wonder who pays.",
		"solid": "Restores passed again. I am not smiling. That is just my face.",
		"loose": "Christy showed me the folder. We should talk. Not now. Soon.",
		"closet": "Tell me which one you want fixed first. I will bring the clipboard."
	},
	"Garrison":
	{
		"rival": "Rex sent me a basket of cheese. I am not eating it. Do you think it is bugged?",
		"solid": "A client praised the one page report. Frame it. I mean it.",
		"loose": "Quick question. Is there anything in the books I should hear from you first?",
		"closet": "Whatever the folder says, I want to hear it from you today."
	},
	"Dan":
	{
		"rival":
		"Another Big Cheese client asked me for a spare key. I did not give it. I thought about it.",
		"solid": "All the closets are labelled. I took photos. I may have a problem.",
		"loose": "I found an old shortcut in a closet. Writing it up now, no judgment.",
		"closet": "I made a list of what we skipped. It has a second page. Sorry."
	},
	"Maya":
	{
		"rival":
		"A client says Big Cheese told her we are not bonded. We are. Can I send her the paper?",
		"solid": "She loved the quarterly page. She asked for two copies.",
		"loose":
		"Three clients sounded off today. I think it is about the things we did not tell them.",
		"closet":
		"I can call the worried ones tomorrow. I would rather tell them than have them find out."
		# who -> state key -> a text they send you (Lynk, owner campaign). Christy is the controller and has no desk talk, only these.
	},
	"John":
	{
		"rival":
		"Rex was at the lunch again. Said he is booked solid. Funny, he asked me for a lead.",
		"solid":
		"Closed a deal with the one page. The owner said it was the first time anyone showed her what she bought.",
		"loose": "If anyone asks about a bill, I am telling the truth. Just so you know.",
		"closet": "I have two deals ready and I am holding them. Say when."
	},
	"Christy":
	{
		"rival":
		"I cannot find a single Big Cheese invoice that says what it is for. I do not think that is an accident.",
		"solid": "The books are tidy this week and so is my desk. I am nervous. Is that normal?",
		"loose": "There is a folder in my bottom drawer. It is not thick. It is not thin either.",
		"closet":
		"The folder does not close any more. We should sit down before the board does it for us."
	},
}
static var LYNK: Dictionary = DEFAULT_LYNK.duplicate(true)

# tech campaign: a tip about the freezer bag backup (Talk, ANY TIPS?; rarely; Alan and Dan)
const DEFAULT_TIPS := {
	"Alan":
	"A backup on a USB drive in a freezer bag in the trunk of a car is not a backup. It is a hope. Restore one file somewhere else, then you know.",
	"Dan":
	"Never trust the little green light on the backup box. Restore one file from every client once a quarter and write down the date.",
}
static var TIPS: Dictionary = DEFAULT_TIPS.duplicate(true)

# service campaign: a note under the runbook (Knowledge): runbook id -> the line added to its footer
const DEFAULT_NOTES := {
	"restore": "A GREEN LIGHT IS NOT PROOF. RESTORE ONE FILE.",
	"av": "A GREEN DASHBOARD IS NOT A CHECK. LOOK AT IT.",
}
static var NOTES: Dictionary = DEFAULT_NOTES.duplicate(true)

# the medal and counter ids this file adds to Career (the text guard checks them)
const COUNTERS := ["habits_adopted", "skeletons_paid", "takeovers", "clean_sheets"]

static var _orig_rival: Dictionary = {}


# ---- forum and IRC gating --------------------------------------------------------------------------------------------
# needs "rap:bigcheese:R05" (RUMOUR or better), "rap:bigcheese:R05:2" (SEEN or better). False for anything else.
static func needs_ok(needs: String) -> bool:
	var p := needs.split(":")
	if p.size() < 3 or p[0] != "rap":
		return false
	var level := int(p[3]) if p.size() > 3 else Rival.RUMOUR
	return Rival.rap(str(p[1]), str(p[2])) >= level


# ---- which line applies ------------------------------------------------------------------------------------------------
# "" (nothing to say), "rival", "bare", "solid", "showcase", "loose" or "closet". The conscience speaks first, then the Standard, then the rival.
static func state_key() -> String:
	var band := Temptation.band()
	if band == "SKELETONS" or band == "A CLOSET FULL":
		return "closet"
	if band == "A FEW LOOSE ENDS":
		return "loose"
	var std := Habits.band()
	if std == "SHOWCASE":
		return "showcase"
	if std == "SOLID":
		return "solid"
	if Rival.known(RIVAL):
		return "bare" if Habits.standard() < 35 else "rival"
	return ""


# ANY IDEAS? at a desk: "" while there is nothing to say
static func talk_line(who: String) -> String:
	var key := state_key()
	if key == "":
		return ""
	return str(TALK.get(who, {}).get(key, ""))


# a text from a coworker: [who, text] or [] (nobody has anything new). Remembers who said what, so notes do not repeat for a while.
static func lynk_note(people: Array, boss: String, roll: int) -> Array:
	var key := state_key()
	if key == "bare":
		key = "rival"
	if key == "":
		return []
	var who_list := []
	for p in people + [boss]:
		var w := str(p)
		if LYNK.has(w) and LYNK[w].has(key) and not who_list.has(w) and not _recent(w, key):
			who_list.append(w)
	if who_list.is_empty():
		return []
	var who := str(who_list[abs(roll) % who_list.size()])
	Owner.flags["tl_%s_%s" % [who, key]] = Campaign.day
	return [who, str(LYNK[who][key])]


static func _recent(who: String, key: String) -> bool:
	var seen := int(Owner.flags.get("tl_%s_%s" % [who, key], -999))
	return Campaign.day - seen < SAME_AGAIN_DAYS


# Christy's reply to HOW ARE WE DOING? gets a sentence added (words only) when the habits or the folder matter
static func marge_line() -> String:
	var key := state_key()
	if key == "bare":
		key = "rival"
	return str(LYNK.get("Christy", {}).get(key, ""))


# tech campaign, ANY TIPS?: now and then Alan or Dan talks about backups in freezer bags
static func freezer_tip(who: String, mode: String, roll: float) -> String:
	if mode != "tech" or roll >= 0.25:
		return ""
	return str(TIPS.get(who, ""))


# service campaign, Knowledge footer: "" for most runbooks
static func runbook_note(id: String) -> String:
	return str(NOTES.get(id, ""))


# ---- Year 2 --------------------------------------------------------------------------------------------------------------
# the Standard of the finished run, kept in the meta record (Yeartwo.record)
static func standard_now() -> int:
	return Habits.standard()


# start habits (free, fresh from day 1) until about YEAR2_STANDARD of last year's score is back; the heaviest habits first, ties by id
static func carry_habits(prev_standard: int) -> Array:
	var target := int(round(float(prev_standard) * YEAR2_STANDARD))
	var ids: Array = Habits.HABITS.keys()
	ids.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			var wa := int(Habits.HABITS[a].get("weight", 0))
			var wb := int(Habits.HABITS[b].get("weight", 0))
			return wa > wb or (wa == wb and str(a) < str(b))
	)
	var out := []
	var total := 0
	for id in ids:
		var w := int(Habits.HABITS[id].get("weight", 0))
		if w > 0 and total + w <= target:
			total += w
			out.append(str(id))
	return out


# Yeartwo.begin_run (owner campaign): the carried habits are started now
static func year2_begin(prev: Dictionary) -> Array:
	var ids := carry_habits(int(prev.get("standard", 0)))
	var counted := Career.value("habits_adopted")  # a carried habit is not a new adoption
	for id in ids:
		Habits.start(str(id))
	Career.counters["habits_adopted"] = counted
	return ids


# the rap sheet shows the Year 2 rival (Yeartwo.TEXT.habits.rival) under a new name while Campaign.year is 2, the original otherwise
static func rival_year(year: int) -> void:
	if not Rival.RIVALS.has(RIVAL):
		return
	if year >= 2:
		if _orig_rival.is_empty():
			_orig_rival = (Rival.RIVALS[RIVAL] as Dictionary).duplicate(true)
		var row: Dictionary = Yeartwo.TEXT.habits.rival
		for k in row:
			Rival.RIVALS[RIVAL][k] = row[k]
	elif not _orig_rival.is_empty():
		for k in _orig_rival:
			Rival.RIVALS[RIVAL][k] = _orig_rival[k]
		_orig_rival = {}


# the end of an owner year with nothing in Christy's folder and clean books: a CLEAN SHEET for the career
static func note_year_end() -> bool:
	if Temptation.folder_count() == 0 and Temptation.band() == "CLEAN BOOKS" and Habits.any():
		Career.add("clean_sheets")
		return true
	return false
