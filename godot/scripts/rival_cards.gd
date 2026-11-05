extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the story cards of the rival arc and the temptations, as DATA (docs/scope-bad-habits.md sections 2.4, 5 and 7).
# CARDS has the same shape as Owner.CARDS (speaker, text, options with label, optional need, fx, text) and is merged into Owner.CARDS when
# the Owner autoload starts (the card dictionaries are shared, so story/strings.txt edits to RivalCards.* show up in both).
# DAYS places cards like Owner.DAYS: {week: [{"at": 9.5, "card": "id"}]} and Owner.events_on() merges it. Beat cards that Rival.ARC queues
# need NO DAYS entry; use DAYS only for cards that appear on a fixed morning or time of day.
# New fx keys (Owner.apply): rap [rival, habit, level], habit id, habit_start id, consc n, skel [id, weeks], visit kind, lead n, and
# rival {ops} (the rival arc: Rival.apply_fx, ops in rival.gd: defect, exit, return, scope, mood, discount, decide, ignore, sign).
# Rival beat cards are shown by Rival.morning as a copy: {rc} = the client of the arc (Delia's office), {rh} = the habit being decided.
# The text is editable in story/strings.txt under [RivalCards.CARDS...]. Charset: the 3x5 font, 2013-14, no AI, "two-factor login", no MFA.
# OWNERS: rival.gd agent (rival_*), temptation agent (temp_*, bill_*), habits agent (habit_*). Add entries, do not change other files.

const DEFAULT_CARDS := {
	"rival_flat":
	{
		"speaker": "{sales_owner}",
		"text":
		"{me}, I sat next to a man called Rex Calloway at the Chamber of Commerce lunch. Big Cheese Technology Group. He gave me a flyer: EVERYTHING INCLUDED, $39 A SEAT. No list of what everything is. Vic ate two of his cookies and says the price is a steal.",
		"options":
		[
			{
				"label": "LOOK UP WHAT $39 A SEAT BUYS ($0, VIC ASKS AROUND)",
				"fx": {"rap": ["bigcheese", "R11", 1]},
				"text":
				"Vic calls two of Rex's clients. Both say the same thing: a person shows up, they are very nice, and nobody can say whether backups are in the price. You write EVERYTHING on a sticky note and put a question mark after it."
			},
			{
				"label": "PRINT A ONE PAGE COMPARISON ($120)",
				"need": 120,
				"fx": {"cash": -120, "habit_start": "H2"},
				"text":
				"Marge makes a one page chart: what you do each week, what it costs, and what is NOT included. It is the first time a client has seen a list like that. Two clients keep it on the fridge."
			},
			{
				"label": "DROP YOUR PRICE TO MATCH",
				"fx": {"price": -0.10, "skel": ["temp_price", 6], "consc": -2},
				"text":
				"Vic is thrilled. Alan does the margin on a napkin and puts the napkin in a drawer."
			},
			{
				"label": "IGNORE HIM, HE WILL BE GONE BY JULY",
				"fx": {},
				"text": "Garrison says he has met a hundred Rexes. Rex is not gone by July."
			},
		],
	},
	"rival_wall":
	{
		"speaker": "Vic Marlowe",
		"text":
		"Look at Big Cheese on Yowl. Forty-one five-star reviews. I clicked through them: thirty-eight come from accounts that have never reviewed anything else, and four were posted the same afternoon. There is a new billboard on the county road too: WE DO IT ALL FOR $39 A SEAT. BOOKED SOLID.",
		"options":
		[
			{
				"label": "HAVE VIC LOOK AT WHO WROTE THEM",
				"fx": {"rap": ["bigcheese", "R09", 1]},
				"text":
				"Vic asks around the Chamber. Nobody has met one of those reviewers. It is a rumour, and you cannot print a rumour."
			},
			{
				"label": "ASK THREE HAPPY CLIENTS FOR A REAL REVIEW",
				"fx": {"rap": ["bigcheese", "R09", 1], "rep": 1, "consc": 1, "owner_hours": 1},
				"text":
				"Three honest reviews arrive in a week. They are not five stars every time. They mention names and dates, which is how you can tell."
			},
			{
				"label": "PAINT A BILLBOARD OF YOUR OWN ($600)",
				"need": 600,
				"fx": {"cash": -600, "lead": 2},
				"text":
				"The sign painter asks what to write. You say: WE TEST OUR BACKUPS. He asks if that is all. It is all."
			},
			{
				"label": "IGNORE IT, REVIEWS DO NOT PAY THE BILLS",
				"fx": {},
				"text": "Garrison nods. Vic frowns at the billboard every time he drives past it."
			},
		],
	},
	"rival_defect":
	{
		"speaker": "Marge",
		"text":
		"{rc} gave notice this morning. They are moving to Big Cheese. Their owner liked the $39 a seat and the free pizza on Fridays. Delia, the office manager, did not look at me when she handed me the letter.",
		"options":
		[
			{
				"label": "MATCH THE PRICE FOR 8 WEEKS (15 PERCENT OFF)",
				"fx":
				{
					"consc": -1,
					"skel": ["temp_price", 8],
					"rival": {"discount": [0.85, 8], "mood": 6}
				},
				"text": "They stay. You now run their office at a loss and everyone knows it."
			},
			{
				"label": "SHOW THEM WHAT IS NOT IN THE FLAT PRICE ($250)",
				"need": 250,
				"roll":
				[
					[
						0.45,
						{"cash": -250, "rival": {"mood": 10}},
						"You build the page with them: backups, patching, the 2 a.m. calls. The owner nods and says he will keep you."
					],
					[
						0.55,
						{"cash": -250, "rival": {"defect": true}},
						"You build the page with them: backups, patching, the 2 a.m. calls. The owner nods and says he will think about it. He thinks about it all the way to Big Cheese."
					],
				],
			},
			{
				"label": "WISH THEM WELL AND ASK FOR AN EXIT CHAT",
				"fx":
				{
					"consc": 1,
					"rap": ["bigcheese", "R11", 2],
					"rival": {"defect": true, "exit": true}
				},
				"text":
				"You hand over a clean folder of passwords and diagrams and say the door stays open. Delia puts your card in her notebook."
			},
			{
				"label": "FIRE BACK: TELL THEM BIG CHEESE LOSES CLIENTS",
				"fx": {"rep": -2, "consc": -1, "rival": {"defect": true}},
				"text":
				"It is true as far as you know, which is not very far. The owner stops listening."
			},
		],
	},
	"rival_notebook":
	{
		"speaker": "Delia Pruitt",
		"text":
		"It's Delia from {rc}. I have a notebook. Since April the server went slow on the 3rd, the 11th, the 17th, and twice on a Monday. I wrote it all down with the date. Rex says I should stop worrying. Would you like to see it?",
		"options":
		[
			{
				"label": "YES. COME IN AND BRING THE NOTEBOOK",
				"fx":
				{
					"rap": [["bigcheese", "R17", 2], ["bigcheese", "R16", 2]],
					"habit_start": "H12",
					"consc": 1
				},
				"text":
				"She reads you fourteen entries. Three of them line up with a backup job that ran at 2:30 on the night the clocks moved. She is the only person in that office who has noticed anything."
			},
			{
				"label": "ASK HER TO PHOTOGRAPH IT FOR YOUR FILE",
				"fx": {"rap": [["bigcheese", "R16", 3], ["bigcheese", "R17", 3]]},
				"text": "Eight photos arrive by text. Your file is now a lot bigger than Rex's."
			},
			{
				"label": "TELL HER TO CANCEL BIG CHEESE NOW",
				"fx": {"rep": -1, "consc": -1},
				"text":
				"You are not their IT person. Delia pauses, then says she will let you know."
			},
			{
				"label": "THANK HER AND STAY OUT OF IT",
				"fx": {"rap": ["bigcheese", "R17", 2], "rival": {"ignore": "R17"}},
				"text": "Probably wise. Delia thanks you and goes back to writing."
			},
		],
	},
	"rival_takeover":
	{
		"speaker": "{tech}",
		"text":
		"{rc} wants to come back. Delia says Rex has not returned a call in nine days and the owner has a bad feeling about the black box in the closet. I say: before we say yes, I want to see what they left behind.",
		"options":
		[
			{
				"label": "SEND DAN FOR A TAKEOVER ASSESSMENT ($300, 4 HOURS)",
				"need": 300,
				"fx":
				{
					"cash": -300,
					"owner_hours": 4,
					"habit_start": "H10",
					"visit": "takeover",
					"rival": {"return": true, "mood": 4}
				},
				"text":
				"Dan takes a camera, a flashlight and a clipboard. He is very quiet on the drive back."
			},
			{
				"label": "QUOTE A FIXED PRICE CLEANUP ($1,800)",
				"roll":
				[
					[
						0.7,
						{"cash": 900, "rival": {"return": true}},
						"They accept the number. The mess turns out to be about the size you guessed. You clear nine hundred dollars and a long weekend."
					],
					[
						0.3,
						{"cash": -600, "rival": {"return": true}},
						"Fixed price on an unknown mess. Behind the closet door is a second mess. I stare at you like you walked into a river."
					],
				],
			},
			{
				"label": "ONLY SIGN WITH A CLEAN CONTRACT AND A TWO WEEK SCOPE FIRST",
				"fx": {"consc": 1, "rival": {"return": true, "scope": true}},
				"text": "They sign. You spend the first two weeks on what is actually there."
			},
			{
				"label": "PASS, WE ARE FULL",
				"fx": {},
				"text": "Delia says she understands. Her voice says she hoped."
			},
		],
	},
	"rival_2fa":
	{
		"speaker": "Marge",
		"text":
		"A bookkeeper at one of Big Cheese's clients forwarded us a fraud email by mistake. Her owner's mailbox was read for days because two-factor login was switched off for convenience. Rex told them it was a nuisance. She has the sent folder to prove it, and she is not happy.",
		"options":
		[
			{
				"label": "CHECK TWO-FACTOR LOGIN FOR OUR OWN CLIENTS ($200)",
				"need": 200,
				"fx": {"cash": -200, "habit_start": "H4", "consc": 1},
				"text":
				"Alan makes a list: who has it on, who has it off, who said it was too much trouble. Eleven names. Nine are fixed by Friday."
			},
			{
				"label": "CALL THE BOOKKEEPER AND OFFER A FREE LOOK",
				"fx": {"lead": 1, "owner_hours": 2},
				"text":
				"She does not switch yet, but she keeps your number on the monitor frame. Rex's number is in a drawer."
			},
			{
				"label": "WRITE IT ON THE RAP SHEET AND MOVE ON",
				"fx": {},
				"text": "Marge puts the date next to the line. She underlines it twice."
			},
		],
	},
	"rival_vendor_audit":
	{
		"speaker": "Marge",
		"text":
		"A letter from WebWoot Security landed in a client's inbox by mistake, and the client forwarded it to us. Big Cheese was billed for 212 seats it never reported, and its antivirus is suspended until the weekend. Our phone started ringing at 6 tonight. Three of them are Big Cheese clients.",
		"options":
		[
			{
				"label": "ANSWER EVERY CALL TONIGHT, NO SALES PITCH",
				"fx": {"owner_hours": 4, "rep": 1, "consc": 1, "mood_all": 3},
				"text":
				"You tell each one the same thing: turn it off, do not click anything, call your own IT person. Two of them say thank you in a tone you remember."
			},
			{
				"label": "OFFER A FREE SECURITY CHECK TO THE CALLERS ($300)",
				"need": 300,
				"fx": {"cash": -300, "lead": 3, "owner_hours": 3},
				"text":
				"Dan and Alan split the checks across Saturday. Three offices now have a list in their hands, and it is not a long list."
			},
			{
				"label": "KEEP QUIET, THIS IS NOT OUR FIGHT",
				"fx": {},
				"text":
				"The phone stops by nine. Marge puts the letter in the folder labelled RAP SHEET."
			},
		],
	},
	"rival_exposed":
	{
		"speaker": "Vic Marlowe",
		"text":
		"A LabRat Nerds thread went up overnight called FIVE STARS FROM NOBODY, and the county paper has a blurb on page six: forty-one reviews, thirty-eight from accounts with no other history. Rex deleted the thread by noon. The Chamber lunch was very quiet today.",
		"options":
		[
			{
				"label": "STAY OUT OF IT AND LET THE PAPER DO ITS JOB",
				"fx": {"consc": 1},
				"text":
				"Garrison says that is the grown up answer. Vic says it is also the boring one."
			},
			{
				"label": "SEND THE REPORTER OUR OWN HONEST REVIEWS",
				"fx": {"rep": 2, "owner_hours": 1},
				"text":
				"Six real reviews, with names and dates and one complaint about parking. The reporter prints the parking one and it does you a lot of good."
			},
			{
				"label": "QUOTE THE PAPER TO EVERY PROSPECT",
				"fx": {"lead": 2, "consc": -1},
				"text":
				"It works. It works a little too well, and Alan says he is not comfortable being the second loudest voice in the room."
			},
		],
	},
	"rival_blitz":
	{
		"speaker": "Vic Marlowe",
		"text":
		"Big Cheese is back with a free IT assessment for every office on the county road, and this time Rex has a line: some people say the other guys are not bonded. Vic has three prospects who have already heard it, and two of our clients got the flyer.",
		"options":
		[
			{
				"label": "CALL EVERY CLIENT BEFORE THEY CALL YOU",
				"fx": {"owner_hours": 4, "mood_all": 4},
				"text":
				"You make eleven calls in one afternoon. Nine are short. Two want to talk about everything else, which is what you hoped for."
			},
			{
				"label": "SHOW THE SHEET: WHAT YOU CAN PROVE, WITH DATES, NO GOSSIP",
				"fx": {"owner_hours": 2, "mood_all": 6, "rep": 2, "consc": 1},
				"text":
				"Three pages. Each line says what, when, and where the paper is. No names but his. Rex's rumour dies at the first meeting that has paper in it."
			},
			{
				"label": "OFFER A LOYALTY PRICE FOR 12 WEEKS (10 PERCENT OFF)",
				"fx": {"discount": {"mult": 0.9, "weeks": 12}, "mood_all": 3},
				"text":
				"Most of them stay. Marge sighs at the margin and says that is what she gets for asking."
			},
			{
				"label": "RELY ON YOUR REPUTATION",
				"fx": {},
				"text":
				"Garrison says we are good enough that we do not need to do anything. That is the sentence people say before they find out."
			},
		],
	},
	"rival_badday":
	{
		"speaker": "Marge",
		"text":
		"Our phone has not stopped. Five Big Cheese clients called between 6 and 8. One had a machine encrypted, the freezer bag was found with a dead drive, and Rex's own phone rings out. They all want to know if we can take them tomorrow.",
		"options":
		[
			{
				"label": "TAKE THEM ALL TOMORROW",
				"fx": {"burnout": 12, "social_all": -1, "rival": {"sign": 5}},
				"text": "You say yes five times. Dan stares at the whiteboard for a while."
			},
			{
				"label": "ASSESS EACH ONE FIRST AND TAKE THE BEST THREE",
				"fx": {"burnout": 4, "consc": 1, "visit": "takeover", "rival": {"sign": 3}},
				"text":
				"Three signed, two sent to a friendly MSP in the next county with a handshake. Alan calls it triage."
			},
			{
				"label": "HELP THEM RECOVER WITHOUT TAKING THEM ($600)",
				"need": 600,
				"fx": {"cash": -600, "rep": 3, "consc": 2, "owner_hours": 6},
				"text":
				"You spend a Saturday recovering what you can. Word gets around the Chamber of Commerce by Monday."
			},
			{
				"label": "PASS, WE HAVE OUR OWN PROBLEMS",
				"fx": {},
				"text": "The phones stop eventually."
			},
		],
	},
	"rival_decide":
	{
		"speaker": "Marge",
		"text":
		"You now know something about Big Cheese: {rh}. {rl} A client of theirs, and a few prospects who sit at the same Chamber lunch, would want to hear it. What do you do with it?",
		"options":
		[
			{
				"label": "WIN THE CLIENT: USE IT IN YOUR OWN TALK, HONESTLY",
				"roll":
				[
					[
						0.7,
						{"owner_hours": 2, "lead": 2, "rep": 1, "rival": {"decide": "win"}},
						"You do not name Rex. You print a page: here is what I would check in your office. Two owners take the page home. One calls on Thursday."
					],
					[
						0.3,
						{"owner_hours": 2, "rival": {"decide": "win"}},
						"The owner is loyal to a friendly man who sponsors the Little League shirts. He thanks you for the page and uses it as a coaster."
					],
				],
			},
			{
				"label": "WARN THEM: A FACTUAL LETTER, ONLY WHAT YOU SAW",
				"fx": {"owner_hours": 1, "rival": {"decide": "warn"}},
				"text":
				"The letter goes out to that one client only. It says what, when and how you know."
			},
			{
				"label": "REPORT IT TO THE VENDOR",
				"roll":
				[
					[
						0.7,
						{"cash": 300, "rep": 1, "rival": {"decide": "vendor"}},
						"The vendor's compliance desk writes back in four days. A credit lands on your account and an invitation to the partner breakfast."
					],
					[
						0.3,
						{"rival": {"decide": "vendor"}},
						"The vendor thanks you for your concern. Nothing else happens, which Alan says is the usual result."
					],
				],
			},
			{
				"label": "IGNORE IT",
				"fx": {"rival": {"decide": "ignore"}},
				"text": "Marge puts it in the folder. The folder is getting thick."
			},
		],
	},
	"rival_counter":
	{
		"speaker": "Vic Marlowe",
		"text":
		"Rex told the whole Chamber lunch you are going around saying things about him. It is half true, which is why it travels. Two prospects went quiet this week.",
		"options":
		[
			{
				"label": "WRITE A SHORT, POLITE CORRECTION",
				"fx": {"owner_hours": 1, "consc": 1},
				"text":
				"Four lines, signed with your name. It does not undo the damage, but it stops it growing."
			},
			{
				"label": "SAY NOTHING, IT WILL PASS",
				"fx": {"rep": -1},
				"text": "It passes, slowly, and takes a prospect or two with it."
			},
		],
	},
	"rival_knew":
	{
		"speaker": "Marge",
		"text":
		"One of Big Cheese's clients was hurt by exactly the thing you had written down: {rh}. Somebody at the Chamber lunch says you knew. I did not say anything. I just looked at the folder.",
		"options":
		[
			{
				"label": "I SHOULD HAVE SAID SOMETHING",
				"fx": {"rep": -1, "consc": -1},
				"text": "Marge nods once. It is the worst possible answer and the true one."
			},
			{
				"label": "SEND THEM A FREE CHECK NOW ($200)",
				"need": 200,
				"fx": {"cash": -200, "rep": -1},
				"text":
				"It is late, but it is something. They do not mention it again, which is a kind of thanks."
			},
		],
	},
	"rival_end":
	{
		"speaker": "Vic Marlowe",
		"text":
		"Big Cheese sold the book to an outfit from out of town. Rex shook every hand at the Chamber lunch and said he was going to spend more time with his family. A painter was on the county road billboard by Tuesday. It says COMING SOON.",
		"options":
		[
			{
				"label": "RAISE A COFFEE TO REX",
				"fx": {"consc": 1},
				"text": "Garrison says every town needs one. Alan says every town only needs one."
			},
			{
				"label": "PUT HIS FLYER IN THE DRAWER",
				"fx": {},
				"text": "EVERYTHING INCLUDED. You still do not know what everything was."
			},
		],
	},
}
static var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)

const DEFAULT_DAYS := {}
static var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)


# the Owner.DAYS table plus the placements of this file (the owner's events_on reads it)
static func merged_days(base: Dictionary) -> Dictionary:
	if DAYS.is_empty():
		return base
	var out := base.duplicate()
	for day in DAYS:
		out[day] = (out.get(day, []) as Array) + (DAYS[day] as Array)
	return out
