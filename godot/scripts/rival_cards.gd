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
		"{me}, I sat next to a man called Rex Calloway at the Chamber of Commerce lunch. Big Cheese Technology Group. He gave me a flyer: EVERYTHING INCLUDED, $39 A SEAT. No list of what everything is. John ate two of his cookies and says the price is a steal.",
		"options":
		[
			{
				"label": "LOOK UP WHAT $39 A SEAT BUYS ($0, JOHN ASKS AROUND)",
				"fx": {"rap": ["bigcheese", "R11", 1]},
				"text":
				"John calls two of Rex's clients. Both say the same thing: a person shows up, they are very nice, and nobody can say whether backups are in the price. You write EVERYTHING on a sticky note and put a question mark after it."
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
				"John is thrilled. Alan does the margin on a napkin and puts the napkin in a drawer."
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
		"speaker": "John Marlowe",
		"text":
		"Look at Big Cheese on Yowl. Forty-one five-star reviews. I clicked through them: thirty-eight come from accounts that have never reviewed anything else, and four were posted the same afternoon. There is a new billboard on the county road too: WE DO IT ALL FOR $39 A SEAT. BOOKED SOLID.",
		"options":
		[
			{
				"label": "HAVE JOHN LOOK AT WHO WROTE THEM",
				"fx": {"rap": ["bigcheese", "R09", 1]},
				"text":
				"John asks around the Chamber. Nobody has met one of those reviewers. It is a rumour, and you cannot print a rumour."
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
				"text": "Garrison nods. John frowns at the billboard every time he drives past it."
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
		"speaker": "John Marlowe",
		"text":
		"A LabRat Nerds thread went up overnight called FIVE STARS FROM NOBODY, and the county paper has a blurb on page six: forty-one reviews, thirty-eight from accounts with no other history. Rex deleted the thread by noon. The Chamber lunch was very quiet today.",
		"options":
		[
			{
				"label": "STAY OUT OF IT AND LET THE PAPER DO ITS JOB",
				"fx": {"consc": 1},
				"text":
				"Garrison says that is the grown up answer. John says it is also the boring one."
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
		"speaker": "John Marlowe",
		"text":
		"Big Cheese is back with a free IT assessment for every office on the county road, and this time Rex has a line: some people say the other guys are not bonded. John has three prospects who have already heard it, and two of our clients got the flyer.",
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
		"speaker": "John Marlowe",
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
		"speaker": "John Marlowe",
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
	"temp_seats":
	{
		"speaker": "Marge",
		"text":
		"WebWoot sent the quarterly seat true-up form. We run their antivirus on 63 seats. If we write 41, the invoice drops $308 a month and nobody checks. Rex told Garrison he does it every quarter.",
		"options":
		[
			{
				"label": "REPORT 41 AND KEEP THE $308 A MONTH",
				"fx": {"weekly": -71, "skel": ["temp_seats", -1], "consc": -2},
				"text":
				"Marge types 41 and does not look up. The invoice drops. She puts the original form in the folder."
			},
			{
				"label": "REPORT 63 AND ASK FOR A VOLUME TIER",
				"fx": {"weekly": -21, "consc": 1},
				"text":
				"The rep sighs, then finds a tier that saves $90 a month. It is not $308, but it is true."
			},
			{
				"label": "CHANGE VENDORS, INTRO RATE ($800 TO SWITCH)",
				"need": 800,
				"fx": {"cash": -800, "vendor_switch": true, "consc": 1},
				"text":
				"The new rep is delighted. $35 a week off for the first three months, then list price. The paperwork starts Monday."
			},
		],
	},
	"temp_reboot":
	{
		"speaker": "John Marlowe",
		"text":
		"The printer at {client} needed a reboot. Eight minutes. Big Cheese bills that as ADVANCED DIAGNOSTICS, $85, and their clients never ask what it is. I think we could do the same.",
		"options":
		[
			{
				"label": "BILL IT AS ADVANCED DIAGNOSTICS ($85)",
				"fx": {"cash": 85, "weekly": -25, "skel": ["temp_reboot", -1], "consc": -2},
				"text":
				"The invoice goes out with the long phrase. John grins. Somewhere a bookkeeper reaches for her glasses."
			},
			{
				"label": "BILL THE EIGHT MINUTES ($20)",
				"fx": {"cash": 20, "consc": 1},
				"text":
				"Twenty dollars and a short note: the printer needed a restart, and here is the setting that stops it. The client keeps the note."
			},
			{
				"label": "OFFER A MONTHLY PRINTER CHECK ($40 A WEEK)",
				"fx": {"cash": 20, "weekly": -10, "consc": 1},
				"text":
				"Now the reboot is part of something. Marge calls it recurring revenue with a stapler."
			},
		],
	},
	"temp_launder":
	{
		"speaker": "John Marlowe",
		"text":
		"A Mrs. Dunning called, said a friend recommended us. Her server is slow, she runs XP in the front office, and her IT person never calls back. She knows our rates and Marge's name. The friend is a client who has never mentioned us to anybody.",
		"options":
		[
			{
				"label": "TAKE THE MEETING, SHE IS A HOT LEAD",
				"fx": {"lead": 2, "skel": ["temp_launder", -1], "consc": -2},
				"text":
				"She is a great lead. She is a great lead because someone read our tickets and sold her the story."
			},
			{
				"label": "ASK HER HOW SHE HEARD ABOUT US",
				"fx": {"rap": ["bigcheese", "R10", 2], "consc": 1},
				"text":
				"She mentions a shared mailbox at the dental office. John goes quiet, then says he will make a call."
			},
			{
				"label": "TELL THE CLIENT THEIR MAILBOX IS OPEN, FOR FREE",
				"fx": {"habit_start": "H12", "consc": 2, "rep": 1, "owner_hours": 1},
				"text":
				"They fix the mailbox that afternoon. Mrs. Dunning becomes a client three weeks later, and she tells everyone why."
			},
		],
	},
	"temp_review":
	{
		"speaker": "{sales_owner}",
		"text":
		"A prospect asked John if we're bonded and HIPAA safe, because somebody told her we aren't. Big Cheese again. Meanwhile their Yowl page has forty reviews. My nephew says he can set up a few accounts for us in an afternoon.",
		"options":
		[
			{
				"label": "POST THREE REVIEWS AS CUSTOMERS",
				"fx": {"rep": 4, "lead": 3, "skel": ["temp_review", -1], "consc": -2},
				"text":
				"Three glowing reviews from a happy dental office manager. Alan reads them and does not speak for the rest of the day."
			},
			{
				"label": "SHOW HER THE BOND CERTIFICATE AND THE BAA",
				"fx": {"lead": 1, "owner_hours": 1, "consc": 1},
				"text":
				"Two documents and a coffee. She signs the following week and apologises for asking."
			},
			{
				"label": "ASK TWO HAPPY CLIENTS FOR A REAL REVIEW",
				"fx": {"rep": 1, "consc": 1},
				"text": "Delia writes the best one. She mentions the printer."
			},
			{
				"label": "SAY NOTHING",
				"fx": {"rep": -1},
				"text": "The rumour spreads, as rumours do at Chamber lunches."
			},
		],
	},
	"temp_restore":
	{
		"speaker": "{tech}",
		"text":
		"It has been a quarter. The restore test is due: pull one machine off the backup and bring it back on a spare. About three hours. Everything is green. Everything has been green for three months.",
		"options":
		[
			{
				"label": "SKIP IT, THE LIGHT IS ON",
				"fx": {"skel": ["temp_restore", -1], "consc": -1},
				"text":
				"The light is on. You decide that is good enough, which is a sentence you will remember."
			},
			{
				"label": "RUN THE TEST ($150, 3 HOURS)",
				"need": 150,
				"roll":
				[
					[
						0.3,
						{"cash": -150, "owner_hours": 3, "habit": "H1", "consc": 1, "rep": 1},
						"It works. It also finds one machine that was never in the job. Alan fixes it before lunch."
					],
					[
						0.7,
						{"cash": -150, "owner_hours": 3, "habit": "H1", "consc": 1},
						"The machine comes back from the backup, boots, and opens the right files. Alan writes the date on the spare PC with a marker."
					],
				],
			},
			{
				"label": "HAND IT TO DAN AND TRUST HIM",
				"roll":
				[
					[
						0.75,
						{"owner_hours": 1, "habit": "H1", "consc": 1},
						"Dan runs it. He labels the spare PC and the drive. He is slightly happy about the label."
					],
					[
						0.25,
						{"owner_hours": 1, "skel": ["temp_restore", -1]},
						"Dan was pulled onto a printer halfway through. The test sits in his notes as almost done."
					],
				],
			},
		],
	},
	"temp_price":
	{
		"speaker": "John Marlowe",
		"text":
		"I found a dental office that is shopping for IT. Big Cheese quoted them $39 a seat. If we go 25 percent under our price I can sign them tomorrow. Alan did the math on a napkin: the work costs us about 80 percent of what we would charge.",
		"options":
		[
			{
				"label": "CUT 25 PERCENT AND SIGN THEM",
				"fx":
				{
					"sign": true,
					"discount_new": {"mult": 0.75, "weeks": 30},
					"skel": ["temp_price", -1],
					"consc": -2
				},
				"text":
				"They sign before lunch. Alan folds the napkin into quarters and puts it in the drawer with the other one."
			},
			{
				"label": "SELL THE VALUE PAGE, AT OUR PRICE ($250)",
				"need": 250,
				"roll":
				[
					[
						0.4,
						{"cash": -250, "sign": true, "consc": 1},
						"You walk them through what is not in the flat price. They sign at your number and ask for the page again."
					],
					[
						0.6,
						{"cash": -250, "consc": 1},
						"They like the page and keep the cheaper quote. The page stays on their fridge anyway."
					],
				],
			},
			{
				"label": "LET THEM GO",
				"fx": {},
				"text": "John shrugs. Alan says a client you lose money on is not a client."
			},
		],
	},
	"temp_2fa":
	{
		"speaker": "{tech}",
		"text":
		"The partner at {client} says two-factor login makes him late for lunch. His office manager asks if we can switch it off for him alone, so he stops calling me. It takes two minutes, and I have nothing on paper saying we ever warned him.",
		"options":
		[
			{
				"label": "SWITCH IT OFF FOR HIM, JUST HIM",
				"fx": {"skel": ["temp_2fa", -1], "consc": -2, "mood_all": 1, "owner_hours": -1},
				"text":
				"The calls stop. The partner shakes your hand at the door. Nothing in writing says why."
			},
			{
				"label": "GET A SIGNED RISK FORM FIRST",
				"fx": {"habit": "H4", "consc": 1, "mood_all": -1},
				"text":
				"He signs without reading. The paper goes in the right folder, which is a different one."
			},
			{
				"label": "INSIST: NO EXCEPTIONS",
				"fx": {"consc": 1, "mood_all": -2, "owner_hours": 1},
				"text":
				"He grumbles for a week and then forgets about it. His office manager sends a thank-you email."
			},
		],
	},
	"temp_quest":
	{
		"speaker": "Marge",
		"text":
		"Granite Mutual's renewal came in. Question 14: is two-factor login on for every administrator account? Question 19: are restores tested at least quarterly? Answer yes to both and the premium is $38 a week. Answer true and it is $65.",
		"options":
		[
			{
				"label": "ANSWER YES TO EVERYTHING",
				"fx": {"weekly": -27, "skel": ["temp_quest", 99], "consc": -2},
				"text":
				"The broker smiles and says it is a very common answer. The premium drops. A folder in Marge's cabinet gets thicker."
			},
			{
				"label": "ANSWER TRUTHFULLY, PROMISE TWO FIXES BY JULY",
				"fx": {"habit_start": ["H1", "H7"], "consc": 1},
				"text":
				"The broker writes a note: IMPROVING. The policy renews at $65. You have two things to do before July."
			},
			{
				"label": "ASK THE BROKER FOR A CHEAPER CARRIER",
				"roll":
				[
					[
						0.4,
						{"weekly": -11, "consc": 1},
						"He grumbles. Two phone calls later: $54 a week, with a one page list of what they need to see."
					],
					[
						0.6,
						{"consc": 1},
						"He tries three carriers. Nobody beats $65 for an honest answer. He tells you so, which you respect."
					],
				],
			},
		],
	},
	"temp_come_clean":
	{
		"speaker": "Marge",
		"text":
		"I keep a folder called THINGS I WOULD RATHER NOT BE ASKED ABOUT. There are {n} things in it now. Buyers read that folder, and so do insurers. I can phone the people involved and tell them the truth before they find it. It costs less than the bill would.",
		"options":
		[
			{
				"label": "OWN UP TO THE OLDEST ONE ({costa})",
				"fx": {},
				"text":
				"Marge makes the call herself. The truth is cheaper than the bill, and the folder is a little lighter."
			},
			{
				"label": "OWN UP TO THE BIGGEST ONE ({costb})",
				"fx": {},
				"text":
				"Marge makes the call herself. The truth is cheaper than the bill, and the folder is a little lighter."
			},
			{
				"label": "NOT YET",
				"fx": {},
				"text": "Marge closes the cabinet. She does not say anything. She does not have to."
			},
		],
	},
	"bill_temp_seats":
	{
		"speaker": "Marge",
		"text":
		"WebWoot audited the seat count: 63 seats, not 41. A back bill plus a 25 percent penalty, {bill} out of the account, and list price with no partner discount from now on. The rep was polite about it, which was worse.",
		"options":
		[
			{
				"label": "PAY IT AND KEEP A PROPER SEAT LIST",
				"fx": {"consc": 1, "owner_hours": 1},
				"text":
				"Marge builds the seat list herself. Next quarter the form takes ten minutes and every number on it is true."
			},
			{
				"label": "ARGUE WITH THE REP",
				"fx": {"rep": -1, "consc": -1},
				"text":
				"You argue about the count. The rep reads the old form back to you, slowly. You stop arguing."
			},
		],
	},
	"bill_temp_reboot":
	{
		"speaker": "Marge",
		"text":
		"A bookkeeper at {vname} went through one invoice and asked what ADVANCED DIAGNOSTICS means. The honest answer was a reboot. We refund {bill} and the owner wants a word.",
		"options":
		[
			{
				"label": "GO THERE AND SAY SORRY IN PERSON",
				"fx": {"consc": 1, "owner_hours": 1, "mood": {"{v}": 6}},
				"text":
				"You say it plainly. The owner is quiet, then asks if you do printer checks. You do."
			},
			{
				"label": "CALL IT A BILLING MIX-UP",
				"fx": {"consc": -1, "rep": -1},
				"text":
				"Marge reads it back to you in the voice she uses for tax notices. Nobody believes the mix-up."
			},
		],
	},
	"bill_temp_launder":
	{
		"speaker": "John Marlowe",
		"text":
		"Mrs. Dunning asked me, kindly, how we knew about her server before she called. The answer is the open mailbox at {vname}, and now {vname} knows. {vleave} The Chamber lunch heard about it by noon.",
		"options":
		[
			{
				"label": "TELL THEM THE WHOLE TRUTH",
				"fx": {"consc": 1, "owner_hours": 2, "mood": {"{v}": 6}},
				"text":
				"It is a long, bad conversation. At the end of it they still have your number, which is more than you earned."
			},
			{
				"label": "DENY IT",
				"fx": {"consc": -1, "rep": -1},
				"text": "Nobody believes you. John stops coming to the Chamber lunch for a week."
			},
		],
	},
	"bill_temp_review":
	{
		"speaker": "{sales_owner}",
		"text":
		"A thread on LabRat Nerds called FIVE STARS FROM ONE KEYBOARD matched our three reviews to my nephew's writing: the same odd phrase, three times. Two forum regulars who liked us have gone quiet, and the Chamber lunch is very polite today.",
		"options":
		[
			{
				"label": "POST ONE SHORT, TRUE APOLOGY",
				"fx": {"consc": 1, "owner_hours": 1, "rep": 1},
				"text":
				"Four lines, under your own name. It does not undo anything, but it is the last thing in the thread."
			},
			{
				"label": "DELETE THE FAKE ACCOUNTS AND SAY NOTHING",
				"fx": {"consc": -1, "rep": -1},
				"text": "The accounts go away. The screenshots do not."
			},
		],
	},
	"bill_temp_quest":
	{
		"speaker": "Marge",
		"text":
		"The claim came back. The insurer put our renewal answers next to the logs: no two-factor login for administrators, no restore test on file. They want {bill} back and the broker has stopped returning calls. Next year's premium is a different number.",
		"options":
		[
			{
				"label": "FIX BOTH ITEMS AND WRITE THEM DOWN",
				"fx": {"habit_start": ["H1", "H7"], "consc": 1},
				"text":
				"Alan makes the list. Two things get done by Friday and dated. The folder has a page that says so."
			},
			{
				"label": "BLAME THE BROKER",
				"fx": {"rep": -1, "consc": -1},
				"text": "The broker has a copy of the form. It has your signature on it."
			},
		],
	},
	"bill_temp_price":
	{
		"speaker": "Marge",
		"text":
		"The profit review is out. {vname} costs us more than it pays: the 25 percent we gave away was the margin. We have been working there at a loss for weeks, about {bill} by my count.",
		"options":
		[
			{
				"label": "ASK FOR A 20 PERCENT RISE",
				"roll":
				[
					[
						0.55,
						{"fee_boost": {"client": "{v}", "mult": 1.2}, "consc": 1},
						"They grumble and sign the new number. The napkin comes out of the drawer to be framed."
					],
					[
						0.45,
						{"drop_client": "{v}"},
						"They say Big Cheese never asked for more. They leave at the end of the month."
					],
				],
			},
			{
				"label": "KEEP THEM AND EAT THE MARGIN",
				"fx": {"consc": -1},
				"text": "Marge puts the review in the folder, next to the napkin."
			},
		],
	},
	"bill_temp_2fa":
	{
		"speaker": "Marge",
		"text":
		"An account at {vname} was taken over. Their owner asks what we told him about two-factor login. We told him on the phone. Nothing is on paper and he says he never agreed to switch it off. Cleanup and a settlement came to {bill}.",
		"options":
		[
			{
				"label": "WRITE EVERY WARNING DOWN FROM NOW ON",
				"fx": {"habit_start": "H13", "consc": 1},
				"text":
				"Alan starts a one line email after every warning. It takes thirty seconds and the folder gets a section."
			},
			{
				"label": "SAY IT WAS HIS CHOICE",
				"fx": {"rep": -1, "consc": -1},
				"text": "It was, but you cannot prove it. He tells his lawyer, who tells him to be calm."
			},
		],
	},
	"bill_temp_restore":
	{
		"speaker": "{tech}",
		"text":
		"The restore failed at {vname}. The backup light was green all quarter, but the job had been skipping the folders that matter since a firewall change. We rebuilt from paper copies and old drives. {bill} in hours and parts.",
		"options":
		[
			{
				"label": "RUN A RESTORE TEST ON EVERY CLIENT NOW",
				"fx": {"habit": "H1", "owner_hours": 3, "consc": 1},
				"text":
				"It takes a long weekend. Two more jobs turn out to be missing folders. All three get fixed before Monday."
			},
			{
				"label": "CALL IT BAD LUCK",
				"fx": {"consc": -1},
				"text":
				"It was not luck. Alan does not say so. Alan just looks at the green light for a long time."
			},
		],
	},
}
static var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)

# the temptation cards that come on a fixed morning; temp_seats, temp_reboot, temp_review and temp_quest are placed by Rival.ARC
const DEFAULT_DAYS := {
	6: [{"at": 13.5, "card": "temp_2fa"}],
	10: [{"at": 14.5, "card": "temp_launder"}],
	12: [{"at": 13.5, "card": "temp_restore"}],
	14: [{"at": 12.0, "card": "temp_price"}],
}
static var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)


# the Owner.DAYS table plus the placements of this file (the owner's events_on reads it)
static func merged_days(base: Dictionary) -> Dictionary:
	if DAYS.is_empty():
		return base
	var out := base.duplicate()
	for day in DAYS:
		out[day] = (out.get(day, []) as Array) + (DAYS[day] as Array)
	return out
