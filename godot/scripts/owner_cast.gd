extends RefCounted
# gdlint:disable=max-line-length,class-variable-name,class-definitions-order
# X11: the second cast in the owner campaign. Jen (the front desk: phones, intake, the wall between clients and your cell phone) and
# Michael (the senior tech who takes tickets off people) each bring three decision cards (C7b: Christy and Morgan bring two each). Data only, in the shape of Owner.CARDS:
# Owner._ready() merges CARDS into Owner.CARDS by reference and Owner.events_on() merges DAYS into Owner.DAYS (the same way as
# RivalCards). Patchable from story/strings.txt as OwnerCast.CARDS. The effects are ordinary fx keys: mood, speed (the crew's capacity),
# weekly and payroll (cash every week), burnout, trust (the other owner's opinion) and owner hours.

const DEFAULT_CARDS := {
	"jen_phones":
	{
		"speaker": "Jen (Front Desk)",
		"text":
		"{me}, about four calls in ten come through my desk now. When I am on one, the next one rings the tech desks, and when nobody picks up it goes to voicemail. Clients hear a beep and assume the worst. I have three ideas and one of them is free.",
		"options":
		[
			{
				"label": "RING THE TECHS WHEN YOU ARE BUSY (FREE)",
				"fx": {"mood_all": 2, "speed": -0.03, "trust": {"Alan": -1, "Garrison": 1}},
				"text": "Every call gets a person. Dan answers with his full name and a sigh. The queue moves a little slower."
			},
			{
				"label": "A PART-TIME SECOND VOICE ($110/WK)",
				"fx": {"weekly": 110, "mood_all": 3, "rep": 1, "trust": {"Alan": 0, "Garrison": 1}},
				"text": "A student answers the second line three afternoons a week. She says the company name like she owns it."
			},
			{
				"label": "VOICEMAIL IS FINE",
				"fx": {"mood_all": -2},
				"text": "The beep stays. So does the worst assumption."
			},
		],
	},
	"jen_intake":
	{
		"speaker": "Jen (Front Desk)",
		"text":
		"Can I ask three things before a call becomes a ticket? Who is it, what is down, and how many people are waiting. Right now I write COMPUTER BROKEN and Dan has to phone them back to find out which computer. He told me that. Twice.",
		"options":
		[
			{
				"label": "YES. THREE QUESTIONS ON EVERY CALL",
				"fx": {"speed": 0.05, "mood_all": -1, "trust": {"Alan": 1, "Garrison": 0}},
				"text": "Tickets arrive with a name, a machine and a headcount. A few callers grumble about the questions. Dan stops phoning people back."
			},
			{
				"label": "AND SHE BOOKS THE ONSITE VISITS ($200)",
				"need": 200,
				"fx": {"cash": -200, "speed": 0.08, "owner_hours": 1, "trust": {"Alan": 1, "Garrison": 1}},
				"text": "A whiteboard goes up by her desk with the whole week on it. She runs it in four colours of marker. Nobody else is allowed the red one."
			},
			{
				"label": "NO, PUT EVERY CALL STRAIGHT THROUGH",
				"fx": {"mood_all": 1, "speed": -0.03},
				"text": "Callers reach a tech at once. The tech was in the middle of something. Now he is in the middle of two things."
			},
		],
	},
	"jen_wall":
	{
		"speaker": "Jen (Front Desk)",
		"text":
		"A client's owner has your cell number and he uses it. Three times this week, twice during dinner by the sound of it. I can be the wall, if you want a wall. I am polite about it. People thank me afterwards.",
		"options":
		[
			{
				"label": "BE THE WALL",
				"fx": {"burnout": -6, "mood_all": -1, "trust": {"Alan": 1, "Garrison": -1}},
				"text": "Calls go to the desk first. One client sulks for a week. You eat a whole dinner."
			},
			{
				"label": "I WILL KEEP TAKING THE CALLS",
				"fx": {"burnout": 5, "mood_all": 2, "owner_hours": 2, "trust": {"Alan": -1, "Garrison": 1}},
				"text": "The clients love it. Your phone lives face up on the table now."
			},
			{
				"label": "A DIRECT LINE TO JEN, NOT TO ME ($60)",
				"need": 60,
				"fx": {"cash": -60, "burnout": -3, "mood_all": 1},
				"text": "She gets a second handset and a little card with her name on it. The owner calls her instead. He calls her a lot."
			},
		],
	},
	"michael_catch":
	{
		"speaker": "Michael (Senior Tech)",
		"text":
		"I took eleven tickets off Dan and Maya this week. I do not mind, it is faster than watching. I am telling you because mine are late now, and nobody will tell you that but me.",
		"options":
		[
			{
				"label": "KEEP CATCHING THEM",
				"fx": {"speed": 0.05, "burnout": 5, "trust": {"Alan": 0, "Garrison": -1}},
				"text": "The queue is quick. Michael's own list grows a second page. He says it is fine, in the voice people use for that."
			},
			{
				"label": "CAP IT: TWO HAND-OFFS A DAY EACH",
				"fx": {"speed": -0.02, "burnout": -3, "social_all": 1, "trust": {"Alan": 1, "Garrison": 1}},
				"text": "Dan and Maya finish more of their own. It is slower this month. Michael goes home on time and is suspicious about it."
			},
			{
				"label": "MAKE IT HIS JOB: ESCALATIONS (+$100/WK)",
				"fx": {"payroll": 100, "speed": 0.07, "trust": {"Alan": 1, "Garrison": -1}},
				"text": "He gets the title and the raise. The hard ones go to him on purpose now, with a note attached."
			},
		],
	},
	"michael_teach":
	{
		"speaker": "Michael (Senior Tech)",
		"text":
		"Half of what I take off people is the same five problems. Give me an hour on Fridays with Dan and Maya and I will stop being the only one who knows. Or I write it down, which nobody will read.",
		"options":
		[
			{
				"label": "FRIDAY HOUR, PIZZA ON THE COMPANY ($150)",
				"need": 150,
				"fx": {"cash": -150, "speed": 0.06, "mood_all": -1, "social_all": 1, "trust": {"Alan": 1, "Garrison": 1}},
				"text": "The queue waits an hour on Fridays. By the third week Maya fixes a print server alone and tells everyone twice."
			},
			{
				"label": "WRITE IT DOWN (2 HOURS OF MINE TO REVIEW)",
				"fx": {"owner_hours": 2, "habit": "H11", "speed": 0.02, "trust": {"Alan": 1, "Garrison": 0}},
				"text": "Five pages in a binder with tabs. Dan reads them. Dan also corrects the spelling."
			},
			{
				"label": "NO TIME FOR THAT NOW",
				"fx": {"social_all": -1},
				"text": "Michael nods and takes the next one off Maya's list."
			},
		],
	},
	"michael_offer":
	{
		"speaker": "Michael (Senior Tech)",
		"text":
		"One of our clients offered me a job. In-house IT, my own office, a door. I have not said no. I am telling you first because that is how I would want it done to me.",
		"options":
		[
			{
				"label": "MATCH IT (+$150/WK)",
				"fx": {"payroll": 150, "burnout": -2, "social_all": 1, "trust": {"Alan": 1, "Garrison": 0}},
				"text": "He stays. He asks if the door was ever on the table. It was not."
			},
			{
				"label": "REMIND THE CLIENT OF THE NO-HIRE CLAUSE",
				"fx": {"mood_all": -2, "rep": -1, "social_all": -1, "trust": {"Alan": 0, "Garrison": -1}},
				"text": "The client backs off, coolly. Michael stays, and knows exactly why."
			},
			{
				"label": "LEND HIM TO THEM ONE DAY A WEEK ($180/WK)",
				"fx": {"weekly": -180, "speed": -0.04, "mood_all": 1, "trust": {"Alan": -1, "Garrison": 1}},
				"text": "Thursdays he works from their office, billed by the day. They get a door with his name on it. We get an invoice with ours."
			},
		],
	},
	"christy_net45":
	{
		"speaker": "Christy (Controller)",
		"text":
		"Three clients pay on day forty-five. My reminders go out on day thirty-one and they are polite. Nobody reads polite. I have two ideas. One is a discount, which I dislike on principle.",
		"options":
		[
			{
				"label": "TWO PERCENT OFF FOR PAYING IN TEN DAYS ($40/WK)",
				"fx": {"weekly": 40, "cash": 600, "trust": {"Alan": 1, "Garrison": 0}},
				"text": "Two of the three pay in ten days. The discount costs forty a week and the cash lands five weeks sooner. Christy smiles at a discount for the first time."
			},
			{
				"label": "LET HER PHONE THEM, LEDGER OPEN",
				"fx": {"cash": 400, "mood_all": -2, "trust": {"Alan": 1, "Garrison": -1}},
				"text": "She calls with the ledger open and a very even voice. They pay. Two of them stop answering Dan's friendly emails for a week."
			},
			{
				"label": "KEEP THE POLITE REMINDERS ($300 LATE)",
				"need": 300, "fx": {"cash": -300, "mood_all": 1},
				"text": "The cheques arrive when they arrive. Christy keeps a chart of how late. The chart is very detailed."
			},
		],
	},
	"christy_card":
	{
		"speaker": "Christy (Controller)",
		"text":
		"The company card shows lunch, a phone case and one item marked MISC. Not a crime. A trend. Do you want a policy, or a conversation?",
		"options":
		[
			{
				"label": "ONE PAGE POLICY, $100 LIMIT",
				"fx": {"weekly": -30, "mood_all": -1, "trust": {"Alan": 1, "Garrison": 0}},
				"text": "A page, a limit, and a line for MISC that says explain. Spending drops. Dan asks if toner counts as lunch."
			},
			{
				"label": "A WORD AT THE HUDDLE (1 HOUR OF MINE)",
				"fx": {"owner_hours": 1, "weekly": -15, "social_all": 1, "trust": {"Alan": 0, "Garrison": 1}},
				"text": "You say it kindly. Christy says it more kindly. Two people look at their shoes. It mostly works."
			},
			{
				"label": "LEAVE IT, THE TRUST IS THE POINT ($200)",
				"need": 200, "fx": {"cash": -200, "mood_all": 1, "trust": {"Alan": -1, "Garrison": 1}},
				"text": "The next statement is two hundred higher. The phone case, Christy admits, is a nice phone case."
			},
		],
	},
	"morgan_overtime":
	{
		"speaker": "Morgan (Manager)",
		"text":
		"The crew is doing evenings again. Nobody complains, which is how I know it is a problem. I can put a hard stop at six, or I can keep not noticing the emails stamped seven o'clock.",
		"options":
		[
			{
				"label": "HARD STOP AT SIX, MORGAN ENFORCES IT",
				"fx": {"speed": -0.03, "burnout": -5, "mood_all": 1, "trust": {"Alan": 1, "Garrison": 0}},
				"text": "Six o'clock is a wall. The queue is a little longer on Mondays. Maya takes a pottery class and tells everybody."
			},
			{
				"label": "TIME BACK FOR EVENINGS (+$90/WK)",
				"fx": {"payroll": 90, "burnout": -3, "mood_all": 2, "trust": {"Alan": 0, "Garrison": 1}},
				"text": "An hour off for every hour past six. Morgan keeps the tally in a spiral notebook with a rubber band."
			},
			{
				"label": "LET IT RIDE THIS MONTH",
				"fx": {"speed": 0.04, "burnout": 5, "trust": {"Alan": -1, "Garrison": 1}},
				"text": "The queue moves. Morgan stops sending the evening emails, which is worse."
			},
		],
	},
	"morgan_reviews":
	{
		"speaker": "Morgan (Manager)",
		"text":
		"Reviews are due. I can write all three in an afternoon, or I can sit with each of them for twenty minutes first, and they will tell their friends. The afternoon is cheaper.",
		"options":
		[
			{
				"label": "TWENTY MINUTES EACH, IN PERSON (2 HOURS)",
				"fx": {"owner_hours": 2, "mood_all": 2, "social_all": 1, "speed": 0.02, "trust": {"Alan": 1, "Garrison": 1}},
				"text": "Three chairs, three coffees. Dan asks what a growth plan is. Maya has already written hers."
			},
			{
				"label": "AN AFTERNOON, WRITTEN, WITH RAISES (+$80/WK)",
				"fx": {"payroll": 80, "mood_all": 1, "trust": {"Alan": 0, "Garrison": 1}},
				"text": "A page each and a number on it. Morgan reads them out loud once and files them in the drawer."
			},
			{
				"label": "SKIP IT THIS QUARTER",
				"fx": {"mood_all": -2, "social_all": -1, "trust": {"Alan": 1, "Garrison": -1}},
				"text": "Nobody says anything. Morgan writes DEFERRED on a sticky note. It stays on her monitor."
			},
		],
	},
}
static var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)

# the week and time of day each card comes (kept clear of the other cards of that week)
const DEFAULT_DAYS := {
	4: [{"at": 15.5, "card": "jen_phones"}],
	6: [{"at": 14.2, "card": "michael_catch"}],
	9: [{"at": 12.0, "card": "jen_intake"}],
	12: [{"at": 14.8, "card": "michael_teach"}],
	14: [{"at": 13.5, "card": "jen_wall"}],
	17: [{"at": 13.0, "card": "michael_offer"}],
	10: [{"at": 15.2, "card": "christy_net45"}],
	11: [{"at": 12.4, "card": "christy_card"}],
	13: [{"at": 10.8, "card": "morgan_overtime"}],
	16: [{"at": 12.6, "card": "morgan_reviews"}],
}
static var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)


# a DAYS table plus the placements of this file (the owner's events_on reads it)
static func merged_days(base: Dictionary) -> Dictionary:
	if DAYS.is_empty():
		return base
	var out := base.duplicate()
	for day in DAYS:
		out[day] = (out.get(day, []) as Array) + (DAYS[day] as Array)
	return out
