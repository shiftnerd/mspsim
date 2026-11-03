extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# The tech campaign's script: what happens on each day (mails, texts, set-pieces) at a time of day.
# Events are data in DAYS; `kind` is mail / text / backup_break (silent) / ransomware.
# Plan (the rest is still to build): day 3 the easy Adobe Reader print ticket (built), day 4
# desktop install + migration (built: Msp.start_project, the RMM PROJECT tab), day 10 a
# client's network rack falls off the wall, day 12 server migration, day 13 the 24x7 email
# outage and vendor call, day 16 a network install, day 20 the yearly review with the manager.

const RANSOM_CLIENT := 3  # Hoot and Holler Law
const MANAGER := "Morgan Reyes - Manager"
const DEFAULT_VIGNETTES := {
	"iphone":
	{
		"speaker": "Karen Whitfield (Brightside Realty)",
		"text":
		"I just got a new iFone 5S and all my email is gone! I have a showing in an hour. Can you please set it up?",
		"options":
		[
			{
				"id": "proper",
				"label": "SET IT UP PROPERLY, WITH A PASSCODE",
				"text":
				"Her mail works and she has a passcode now. She says you are a lifesaver. (+4 customer XP)",
				"fx": {"xp": ["people", 4], "mood": [1, 4], "hours": 0.3}
			},
			{
				"id": "all",
				"label": "SET IT UP AND MOVE HER CONTACTS TOO",
				"text":
				"It takes a while, but every client's number is on the new phone. She hugs you. A little. (+3 customer XP)",
				"fx": {"xp": ["people", 3], "mood": [1, 6], "hours": 0.6, "energy": -1}
			},
			{
				"id": "store",
				"label": "TELL HER TO CALL THE PHONE STORE",
				"text": "She sighs and says she will ask her nephew.",
				"fx": {"mood": [1, -3]}
			},
		],
	},
	"heartbleed":
	{
		"speaker": "Garrison (Co-owner)",
		"text":
		"Every client is asking about Heartbleed, that bug in the news with a logo, and I told them we are on it. Are any of their servers affected? Please check before they call us again.",
		"options":
		[
			{
				"id": "check",
				"label": "CHECK EVERY CLIENT AND WRITE A SHORT NOTE",
				"text":
				"Most are fine. One old firewall needs a patch and you schedule it for tonight. Garrison nods. (+6 security XP, reputation +1)",
				"fx": {"xp": ["security", 6], "rep": 1, "hours": 0.5}
			},
			{
				"id": "mail",
				"label": "SEND A REASSURING EMAIL TO EVERYONE",
				"text":
				"You say 'we are looking into it and will update you'. Nobody replies. That is a good sign.",
				"fx": {"mood_all": 2}
			},
			{
				"id": "wait",
				"label": "WAIT UNTIL SOMEONE ASKS",
				"text": "Garrison sighs. 'That is what everyone said about Target.'",
				"fx": {"rep": -1, "social": {"Garrison": -2}}
			},
		],
	},
	"candy":
	{
		"speaker": "The hygienist (Acme Dental)",
		"text":
		"I put Sugar Smash on the front desk computer so the waiting room kids can play. Is that okay? It is very popular.",
		"options":
		[
			{
				"id": "remove",
				"label": "REMOVE IT AND EXPLAIN WHY",
				"text":
				"You explain malware and the license. She is a bit disappointed and very understanding. (+2 customer XP)",
				"fx": {"xp": ["people", 2], "mood": [0, 2]}
			},
			{
				"id": "play",
				"label": "PLAY ONE LEVEL TO TEST IT FIRST",
				"text": "Level 41. It is very hard. Your coffee goes cold. (+2 energy)",
				"fx": {"energy": 2, "hours": 0.2}
			},
			{
				"id": "tell",
				"label": "TELL DR. PATEL",
				"text": "Dr. Patel is not amused. The hygienist is not amused either.",
				"fx": {"mood": [0, -4]}
			},
		],
	},
	"pizza":
	{
		"speaker": "A salesman from a PSA vendor",
		"text":
		"Hi! I am bringing free pizza for the service desk and I would love just thirty minutes of your time to show you our ticketing software.",
		"options":
		[
			{
				"id": "listen",
				"label": "TAKE THE PIZZA AND LISTEN",
				"text":
				"The demo is okay, and you learn what the competition charges. The pizza is good. (+2 customer XP, +3 energy)",
				"fx": {"xp": ["people", 2], "energy": 3, "hours": 0.5}
			},
			{
				"id": "grab",
				"label": "TAKE A SLICE AND LEAVE",
				"text": "Alan notices. He says nothing, loudly. (+2 energy)",
				"fx": {"energy": 2, "social": {"Alan": -1}}
			},
			{
				"id": "decline",
				"label": "TELL HIM WE ARE HAPPY WITH WHAT WE HAVE",
				"text": "He leaves the pizza anyway. Everyone is happy.",
				"fx": {"social_all": 1}
			},
		],
	},
	"win8":
	{
		"speaker": "A realtor at Brightside",
		"text":
		"I updated my computer to Windows 8 and now there is no Start button! Where did it go? I have a listing to send in ten minutes.",
		"options":
		[
			{
				"id": "show",
				"label": "SHOW HER THE HOT CORNERS AND THE START SCREEN",
				"text":
				"She learns where everything went. She calls it 'the tiles' for the rest of the year. (+3 customer XP)",
				"fx": {"xp": ["people", 3], "mood": [1, 3], "hours": 0.3}
			},
			{
				"id": "menu",
				"label": "INSTALL A START MENU REPLACEMENT",
				"text": "A familiar button comes back and she cries a little. (+2 servers XP)",
				"fx": {"xp": ["servers", 2], "mood": [1, 4], "hours": 0.2}
			},
			{
				"id": "feature",
				"label": "TELL HER IT IS A FEATURE",
				"text": "Dan laughs quietly across the room. She does not.",
				"fx": {"mood": [1, -3], "social": {"Dan": 1}}
			},
		],
	},
	"selfreview":
	{
		"speaker": "Morgan (Manager)",
		"text": "Before reviews: what are you proudest of this year? I will remember what you say.",
		"options":
		[
			{
				"id": "jobs",
				"label": "THE BIG JOBS I GOT RIGHT",
				"text": "Morgan writes it down. 'That is what I will say to Alan and Garrison.'",
				"fx": {"rep": 1}
			},
			{
				"id": "learn",
				"label": "HOW MUCH I HAVE LEARNED",
				"text": "Morgan smiles. 'Keep doing that.' (+3 customer XP)",
				"fx": {"xp": ["people", 3]}
			},
			{
				"id": "team",
				"label": "THE TEAM I WORK WITH",
				"text": "Morgan says the team has noticed. Word gets around.",
				"fx": {"social_all": 2}
			},
		],
	},
	"donuts":
	{
		"speaker": "Alan (Co-owner)",
		"text":
		"I am back, and I brought donuts. Morgan says you covered for me while I was out. I read the page you wrote about the firewall I built. Show me how you set it up in the vault?",
		"text_reset":
		"I am back, and I brought donuts. Morgan says you covered for me while I was out, and I heard what happened to the firewall. I am not angry. Show me how it is set up now?",
		"text_plain":
		"I am back, and I brought donuts. Morgan says you covered for me while I was out. Nobody wrote down how the firewall is set up, so would you show me what you did?",
		"options":
		[
			{
				"id": "show",
				"label": "SHOW HIM, HE IS PROUD",
				"text": "Alan nods slowly. 'That is better than what I had.' (+3 servers XP)",
				"fx": {"xp": ["servers", 3], "social": {"Alan": 3}}
			},
			{
				"id": "nothing",
				"label": "SAY IT WAS NOTHING",
				"text": "He insists you are being modest and gives you the last donut.",
				"fx": {"social": {"Alan": 1}, "energy": 1}
			},
			{
				"id": "subject",
				"label": "EAT A DONUT AND CHANGE THE SUBJECT",
				"text": "You discuss the weather for a minute. The donut is very good. (+2 energy)",
				"fx": {"energy": 2}
			},
		],
	},
	"tape_swap":
	{
		"speaker": "The office manager (Gnarly Gnomes)",
		"text": "Nobody has changed the backup tape since Monday. We keep forgetting. Could we just leave it in forever?",
		"min_day": 3,
		"max_day": 20,
		"options": [
			{
				"id": "label",
				"label": "PUT A COLORED LABEL ON EACH DAY'S TAPE",
				"text": "She buys a roll of stickers. The tapes look like a rainbow.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						2,
						3
					]
				}
			},
			{
				"id": "auto",
				"label": "SWITCH THEM TO DISK-BASED BACKUPS",
				"text": "A small project for a rainy day.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "remind",
				"label": "SEND A DAILY REMINDER EMAIL",
				"text": "It works for two days.",
				"fx": {
					"mood": [
						2,
						1
					]
				}
			}
		]
	},
	"toolbar":
	{
		"speaker": "A realtor at Brightside",
		"text": "My browser has a toolbar I did not ask for, and another one, and now a third. The page is the size of a postage stamp.",
		"min_day": 3,
		"max_day": 20,
		"options": [
			{
				"id": "remove",
				"label": "REMOVE THEM ALL AND EXPLAIN THE 'NEXT' BUTTON",
				"text": "She will never press 'Next' again without reading.",
				"fx": {
					"xp": [
						"security",
						3
					],
					"mood": [
						1,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "reset",
				"label": "RESET THE BROWSER",
				"text": "Clean and fast. She stops cursing.",
				"fx": {
					"xp": [
						"security",
						1
					],
					"mood": [
						1,
						2
					]
				}
			},
			{
				"id": "shrug",
				"label": "TELL HER TO CLOSE SOME TABS",
				"text": "Not the answer she wanted.",
				"fx": {
					"mood": [
						1,
						-3
					]
				}
			}
		]
	},
	"fax_black":
	{
		"speaker": "The paralegal (Hoot and Holler)",
		"text": "The fax machine is printing black pages. Every page. The partners are waiting on a signed document and it is only coming out black.",
		"min_day": 4,
		"max_day": 20,
		"options": [
			{
				"id": "clean",
				"label": "CLEAN THE SCANNER GLASS AND THE ROLLER",
				"text": "A smudge the size of a dime. The fax prints beautifully.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"mood": [
						3,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "scan",
				"label": "SCAN AND EMAIL THE DOCUMENT INSTEAD",
				"text": "No fax needed. She looks at you as if you had invented email.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						3,
						4
					]
				}
			},
			{
				"id": "order",
				"label": "ORDER A NEW FAX MACHINE",
				"text": "A new machine is fine, but the document is still stuck.",
				"fx": {
					"mood": [
						3,
						-2
					]
				}
			}
		]
	},
	"sticky_dan":
	{
		"speaker": "Dan (Network tech)",
		"text": "I found the main router password on a sticky note in three different offices. It is 'admin' in all three. Do you want me to fix it or yell?",
		"min_day": 4,
		"max_day": 20,
		"options": [
			{
				"id": "fix",
				"label": "TELL HIM TO FIX IT AND YOU WILL WRITE THE NOTE",
				"text": "He changes it. You write a short, friendly note. Dan nods.",
				"fx": {
					"xp": [
						"security",
						2
					],
					"social": {
						"Dan": 2
					}
				}
			},
			{
				"id": "yell",
				"label": "BOTH",
				"text": "You say it together and feel better.",
				"fx": {
					"social": {
						"Dan": 1
					},
					"energy": 1
				}
			},
			{
				"id": "later",
				"label": "SAY IT CAN WAIT",
				"text": "Dan raises an eyebrow, a very small one.",
				"fx": {
					"social": {
						"Dan": -1
					}
				}
			}
		]
	},
	"captcha":
	{
		"speaker": "A realtor at Brightside",
		"text": "The website keeps asking me to type distorted letters and I cannot read them. I have tried eleven times. Is the site broken?",
		"min_day": 5,
		"max_day": 20,
		"options": [
			{
				"id": "teach",
				"label": "SIT WITH HER AND SOLVE A FEW",
				"text": "She likes the one that reads 'banana'.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						1,
						3
					],
					"hours": 0.2
				}
			},
			{
				"id": "audio",
				"label": "SHOW HER THE AUDIO OPTION",
				"text": "It sounds like a ghost reading numbers, but it works.",
				"fx": {
					"mood": [
						1,
						2
					]
				}
			},
			{
				"id": "email",
				"label": "TELL HER TO EMAIL THEM",
				"text": "She does. They respond in a week.",
				"fx": {
					"mood": [
						1,
						-1
					]
				}
			}
		]
	},
	"cable_mess":
	{
		"speaker": "The owner (Gnarly Gnomes)",
		"text": "Behind the desk there is a nest of cables. My assistant says it is a fire hazard. Can you make it nice? It is not nice.",
		"min_day": 5,
		"max_day": 20,
		"options": [
			{
				"id": "tidy",
				"label": "LABEL, BUNDLE AND ROUTE EVERYTHING",
				"text": "Twenty velcro ties and forty minutes. It looks like a catalog photo.",
				"fx": {
					"xp": [
						"networking",
						4
					],
					"mood": [
						2,
						4
					],
					"hours": 0.7
				}
			},
			{
				"id": "some",
				"label": "TIDY THE WORST HALF",
				"text": "It is better. She says it is a start.",
				"fx": {
					"xp": [
						"networking",
						2
					],
					"mood": [
						2,
						2
					],
					"hours": 0.3
				}
			},
			{
				"id": "point",
				"label": "TELL HER IT IS NOT A HAZARD",
				"text": "It is slightly a hazard.",
				"fx": {
					"mood": [
						2,
						-2
					]
				}
			}
		]
	},
	"kid_laptop":
	{
		"speaker": "A client's teenager",
		"text": "I need help. My mom said you set up her computer, and my school laptop will not connect to anything. Mom says I can ask you, but I have to say please.",
		"min_day": 6,
		"max_day": 20,
		"options": [
			{
				"id": "fix",
				"label": "TAKE A LOOK, IT IS A FIVE MINUTE JOB",
				"text": "A wrong setting. She thanks you in a very serious voice.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						4,
						3
					],
					"hours": 0.2
				}
			},
			{
				"id": "teach",
				"label": "SHOW HER HOW TO CHECK IT HERSELF",
				"text": "She writes it down in a notebook. She will be running IT someday.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						4,
						2
					],
					"hours": 0.3
				}
			},
			{
				"id": "no",
				"label": "SAY YOU CAN ONLY HELP THE COMPANY",
				"text": "She understands. Probably.",
				"fx": {
					"mood": [
						4,
						-1
					]
				}
			}
		]
	},
	"voip_pitch":
	{
		"speaker": "A salesman from a phone company",
		"text": "Hi! Hosted phones are the next big thing. No more desk phone boxes in the closet. I would love to show you a quick demo with a headset.",
		"min_day": 6,
		"max_day": 20,
		"options": [
			{
				"id": "demo",
				"label": "TRY THE DEMO",
				"text": "The call is clear, the portal is clean, and the price is not.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "card",
				"label": "TAKE HIS CARD AND PASS IT TO THE OWNERS",
				"text": "Garrison files it with the other ideas. Alan nods slowly.",
				"fx": {
					"social_all": 1
				}
			},
			{
				"id": "no",
				"label": "SAY WE ARE HAPPY WITH WHAT WE HAVE",
				"text": "He leaves a pen with a logo on it.",
				"fx": {}
			}
		]
	},
	"spam_folder":
	{
		"speaker": "The office manager (Acme Dental)",
		"text": "The newsletter we send every month is landing in everybody's spam folder. Even mine. It looks fine to me!",
		"min_day": 7,
		"max_day": 20,
		"options": [
			{
				"id": "dns",
				"label": "CHECK THE MAIL SETTINGS AND FIX THE SENDER RECORD",
				"text": "One missing record. The mail lands in inboxes again.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"mood": [
						0,
						4
					],
					"hours": 0.6
				}
			},
			{
				"id": "tips",
				"label": "SUGGEST A BETTER SUBJECT LINE",
				"text": "'FREE TEETH!!!' becomes 'Your spring checkup'. It helps.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						0,
						2
					]
				}
			},
			{
				"id": "whitelist",
				"label": "TELL EVERYONE TO MARK IT AS SAFE",
				"text": "Half of them do. The other half do not read it.",
				"fx": {
					"mood": [
						0,
						1
					]
				}
			}
		]
	},
	"charger_drawer":
	{
		"speaker": "Dan (Network tech)",
		"text": "There is a drawer full of chargers and nobody knows what goes with what. I made a chart. It has color coding. Do you want a copy?",
		"min_day": 8,
		"max_day": 20,
		"options": [
			{
				"id": "copy",
				"label": "YES, AND PUT IT ON THE WALL",
				"text": "The drawer becomes the most organized place in the office.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"social": {
						"Dan": 2
					}
				}
			},
			{
				"id": "help",
				"label": "HELP HIM LABEL THEM",
				"text": "You find a charger for a phone nobody remembers. It is a good morning.",
				"fx": {
					"social": {
						"Dan": 2
					},
					"energy": 1,
					"hours": 0.3
				}
			},
			{
				"id": "laugh",
				"label": "LAUGH AT THE CHART",
				"text": "Dan does not speak to you for twenty minutes.",
				"fx": {
					"social": {
						"Dan": -2
					}
				}
			}
		]
	},
	"tv_monitor":
	{
		"speaker": "A realtor at Brightside",
		"text": "I bought a 50 inch TV for my desk. It was on sale! It looks great, but my eyes hurt and the text is blurry. Can you fix it?",
		"min_day": 8,
		"max_day": 20,
		"options": [
			{
				"id": "set",
				"label": "SET THE RIGHT RESOLUTION AND TEXT SIZE",
				"text": "A tiny tweak. She says it is like new glasses.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						1,
						4
					],
					"hours": 0.3
				}
			},
			{
				"id": "mount",
				"label": "SUGGEST MOVING IT BACK A FEW FEET",
				"text": "She tries it. A TV across the room is a TV.",
				"fx": {
					"mood": [
						1,
						2
					]
				}
			},
			{
				"id": "return",
				"label": "SAY THAT A TV IS NOT A MONITOR",
				"text": "She says it is a monitor now.",
				"fx": {
					"mood": [
						1,
						-2
					]
				}
			}
		]
	},
	"scan_to_mail":
	{
		"speaker": "The paralegal (Hoot and Holler)",
		"text": "The new copier says it can 'scan to email', but it asks for a server name I do not have. Can you do whatever it is that I should do?",
		"min_day": 9,
		"max_day": 20,
		"options": [
			{
				"id": "setup",
				"label": "SET UP THE SCAN-TO-EMAIL PROPERLY",
				"text": "A mail relay and a small password. The partners can scan from the copier.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"mood": [
						3,
						4
					],
					"hours": 0.6
				}
			},
			{
				"id": "folder",
				"label": "SET UP SCAN TO A SHARED FOLDER",
				"text": "Simpler and safer. She approves.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"mood": [
						3,
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "later",
				"label": "TELL HER YOU WILL LOOK AT IT NEXT WEEK",
				"text": "She keeps using the fax. Which is black.",
				"fx": {
					"mood": [
						3,
						-2
					]
				}
			}
		]
	},
	"old_server_larry":
	{
		"speaker": "Alan (Co-owner)",
		"text": "There is a server in the back that Larry set up in 2006. Nobody knows what it does and nobody will turn it off. Can you find out what is on it?",
		"min_day": 10,
		"max_day": 20,
		"options": [
			{
				"id": "find",
				"label": "TRACE WHAT TALKS TO IT AND WRITE IT DOWN",
				"text": "It runs a label printer and one database for the front desk. You document both.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"social": {
						"Alan": 2
					},
					"hours": 0.6
				}
			},
			{
				"id": "ask",
				"label": "ASK EVERYONE IN THE OFFICE",
				"text": "Someone remembers a login that works. Alan chuckles.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"social": {
						"Alan": 1
					}
				}
			},
			{
				"id": "leave",
				"label": "LEAVE IT ALONE, LARRY KNOWS BEST",
				"text": "Larry left in 2009.",
				"fx": {
					"social": {
						"Alan": -1
					}
				}
			}
		]
	},
	"win81_update":
	{
		"speaker": "A realtor at Brightside",
		"text": "The computer says there is a free update to Windows 8.1 and she wants to know if it brings the Start button back. I have been told it does. Is that true?",
		"min_day": 11,
		"max_day": 20,
		"options": [
			{
				"id": "yes",
				"label": "TELL HER YES, AND INSTALL IT AFTER LUNCH",
				"text": "A shiny button comes back, and she is pleased.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						1,
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "careful",
				"label": "BACK UP FIRST, THEN INSTALL",
				"text": "It takes longer. It also does not fail.",
				"fx": {
					"xp": [
						"security",
						2
					],
					"mood": [
						1,
						2
					],
					"hours": 0.7
				}
			},
			{
				"id": "skip",
				"label": "TELL HER TO WAIT",
				"text": "She installs it herself and tells you about it.",
				"fx": {
					"mood": [
						1,
						-2
					]
				}
			}
		]
	},
	"thank_you_card":
	{
		"speaker": "A card from Soggy Bottom Brewing",
		"text": "A hand-written card arrives. 'Thank you for all your help this year. The beer is on us. Come by any Friday.' There is a drawing of a pint glass.",
		"min_day": 15,
		"max_day": 20,
		"options": [
			{
				"id": "frame",
				"label": "PIN IT TO THE WALL",
				"text": "Everyone reads it. It is a good morning.",
				"fx": {
					"social_all": 1
				}
			},
			{
				"id": "share",
				"label": "READ IT TO THE TEAM",
				"text": "A little applause. A little embarrassment.",
				"fx": {
					"rep": 1
				}
			},
			{
				"id": "keep",
				"label": "PUT IT IN YOUR DRAWER",
				"text": "A private small win.",
				"fx": {
					"energy": 2
				}
			}
		]
	},
	"alan_sandwich":
	{
		"speaker": "Alan (Co-owner)",
		"text": "I made two sandwiches this morning, one too many. Roast beef. You can have it if you tell me which of the three printers has been misbehaving the most.",
		"min_day": 17,
		"max_day": 20,
		"options": [
			{
				"id": "honest",
				"label": "TELL HIM THE TRUTH ABOUT THE PRINTERS",
				"text": "The sandwich is excellent. The answer is the one at Hoot and Holler.",
				"fx": {
					"energy": 5,
					"social": {
						"Alan": 2
					}
				}
			},
			{
				"id": "diplomatic",
				"label": "TAKE THE SANDWICH AND CHANGE THE SUBJECT",
				"text": "Alan raises an eyebrow, but the sandwich stays.",
				"fx": {
					"energy": 3,
					"social": {
						"Alan": 1
					}
				}
			},
			{
				"id": "no",
				"label": "SAY YOU ALREADY ATE",
				"text": "He eats both. He does not blame you.",
				"fx": {}
			}
		]
	},
	"first_week_note":
	{
		"speaker": "Morgan (Manager)",
		"text": "The year is almost over. Is there something you wish somebody had told you on your first day? I am writing a note for the next new hire.",
		"min_day": 18,
		"max_day": 20,
		"options": [
			{
				"id": "tips",
				"label": "WRITE DOWN THREE TIPS",
				"text": "Morgan reads them aloud and says, 'Perfect.'",
				"fx": {
					"xp": [
						"people",
						3
					],
					"rep": 1
				}
			},
			{
				"id": "short",
				"label": "SAY 'ASK QUESTIONS EARLY'",
				"text": "Morgan writes that down and underlines it.",
				"fx": {
					"xp": [
						"people",
						1
					]
				}
			},
			{
				"id": "none",
				"label": "SAY 'NOTHING, REALLY'",
				"text": "Morgan thinks you are being modest.",
				"fx": {}
			}
		]
	},
}
var VIGNETTES: Dictionary = DEFAULT_VIGNETTES.duplicate(true)
const DEFAULT_DAYS := {
	1:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Your first day",
			"body":
			(
				"Welcome to Pixel IT Partners. Alan and Garrison own the place and I run the floor for them. Tickets come in on ConnectWhy PSA, you fix things "
				+ "with LabRat RMM, and you only close a ticket once it is really fixed. Reopened tickets "
				+ "make me sad. Clients also call and text, so check your phone (P) now and then. - Morgan"
			)
		},
	],
	2:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Daily chore: verify backups",
			"body":
			(
				"Every morning open LabRat RMM, click BACKUPS and check each client. Backup jobs "
				+ "can fail silently and nobody notices until the day it really matters. It takes thirty "
				+ "seconds, until your security skills are good enough for the backup watch to do it for you. - Morgan"
			)
		},
		{"at": 10.5, "kind": "vignette", "id": "iphone"},
	],
	3:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Get good at PowerShell",
			"body":
			(
				"The PowerShell Academy is on your desktop. Every lesson makes your remote fixes "
				+ "faster and more reliable, and later levels unlock scripts that fix a whole client at "
				+ "once. Study between tickets. - Morgan"
			)
		},
		{"at": 10.0, "kind": "adobe", "client": 1},
	],
	4:
	[
		{
			"at": 9.1,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Windows XP is going away",
			"body":
			(
				"Microsoft ends support for Windows XP and Office 2003 on April 8. After that there are no "
				+ "more security patches, so every XP machine at every client is a liability. "
				+ "Dr. Patel at Acme Dental is first. Survey the old PC (old software, old drivers, odd "
				+ "settings), back it up before you move anything, migrate, then verify with the user "
				+ "before you wipe it. - Morgan"
			)
		},
		{"at": 10.0, "kind": "install"},
	],
	5:
	[
		{"at": 8.6, "kind": "backup_break", "client": RANSOM_CLIENT},
		{"at": 9.6, "kind": "install_followup"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "On-call rota starts Monday",
			"body":
			(
				"You are on the pager next week (Monday to Friday nights). If a client alert wakes you, "
				+ "you can get up and fix it, check it first, or let it ride, "
				+ "but clients do not forgive a dead server. "
				+ "On-call pay is $40 a day. Leave for work early enough, too: "
				+ "Route 9 is down to one lane. - Morgan"
			)
		},
		{"at": 10.5, "kind": "vignette", "id": "heartbleed"},
	],
	6: [{"at": 9.8, "kind": "growth_plan"}],
	7:
	[
		{
			"at": 10.0,
			"kind": "mail",
			"from": "Atty. Spence <spence@hootholler.example>",
			"subject": "Backup report?",
			"body":
			"Hi, I have not seen the nightly backup report email for a few days. Probably nothing? - Spence"
		},
		{
			"at": 13.0,
			"kind": "playbook",
			"book": "rdp",
			"text":
			(
				"Brightside's server is crawling and there are strangers in the logs. "
				+ "Their remote desktop may be open to the internet. Look, then close the door."
			)
		},
		{"at": 11.0, "kind": "growth_block"},
		{"at": 15.5, "kind": "vignette", "id": "candy"},
	],
	8:
	[
		{
			"at": 9.6,
			"kind": "playbook",
			"book": "ceofraud",
			"text":
			"Hoot and Holler got a strange email asking to wire money. The paralegal is waiting on you before she does anything."
		},
		{"at": 14.0, "kind": "growth_stretch"},
	],
	9: [{"at": 10.5, "kind": "ransomware"}],
	10:
	[
		{
			"at": 10.0,
			"kind": "playbook",
			"book": "rack",
			"text":
			"Gnarly Gnomes says their network rack fell off the wall. Everything is down. Go. Photos first!"
		},
	],
	11: [{"at": 10.0, "kind": "callback_install"}],
	12:
	[
		{
			"at": 9.5,
			"kind": "playbook",
			"book": "migration",
			"text":
			"Brightside's server migration is today. Check the backups before you touch anything."
		},
		{"at": 11.0, "kind": "growth_block"},
		{"at": 15.5, "kind": "vignette", "id": "pizza"},
	],
	13:
	[
		{
			"at": 15.5,
			"kind": "playbook",
			"book": "email24",
			"text":
			"Soggy Bottom Brewing runs 24x7 and their email just died. This could be a long night."
		},
		{"at": 14.0, "kind": "growth_stretch"},
	],
	14:
	[
		{
			"at": 13.0,
			"kind": "playbook",
			"book": "no2fa",
			"text":
			"Soggy Bottom keeps getting phished and still refuses stronger logins. Go and have the conversation."
		},
		{"at": 10.0, "kind": "callback_ransom"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "About last night",
			"body":
			(
				"Whatever happened with the brewery, thank you for staying late. Overtime is on your paycheck. "
				+ "Take it easy today. - Morgan"
			)
		},
		{"at": 15.5, "kind": "vignette", "id": "win8"},
	],
	15:
	[
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Pager again",
			"body":
			"You are back on call from Monday. Storm season is here, so expect rain, traffic and worse. - Morgan"
		},
	],
	16:
	[
		{
			"at": 9.5,
			"kind": "playbook",
			"book": "netinstall",
			"text":
			"Hoot and Holler's branch office network install is today. Do it right, they remember."
		},
	],
	17: [{"at": 11.0, "kind": "growth_block"}],
	18:
	[
		{"at": 14.0, "kind": "growth_stretch"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Reviews are coming",
			"body":
			(
				"Yearly reviews are on day 20. I look at your tickets, your big jobs and what "
				+ "your coworkers say about you. No pressure. A little pressure. - Morgan"
			)
		},
		{"at": 10.5, "kind": "vignette", "id": "selfreview"},
	],
	19:
	[
		{
			"at": 9.5,
			"kind": "playbook",
			"book": "bus",
			"text": "Acme's internet is flaky and the person who knows the firewall is out sick."
		},
		{"at": 15.0, "kind": "vignette", "id": "donuts"},
	],
	20:
	[
		{"at": 9.4, "kind": "callback_worst"},
		{
			"at": 9.2,
			"kind": "mail",
			"from": MANAGER,
			"subject": "Review at the end of the day",
			"body":
			"We will sit down after close for your yearly review. There may be an offer or two. - Morgan"
		},
	],
}
var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)

var flags := {}  # story results (saved with the campaign)
var overtime := false  # an incident is keeping the day open past closing time
var ot_hours := 0.0

var _fired := {}
var _followed := false


func reset() -> void:
	flags = {}
	_fired = {}
	overtime = false
	ot_hours = 0.0
	_followed = false
	Playbook.reset()


# the scripted events of a day; Year 2 moves some of them by a day or two (Yeartwo.story_shuffle)
func events_on(day: int) -> Array:
	return Yeartwo.events_on("tech", day, DAYS)


func begin_day(day: int) -> void:
	_fired = {}
	_followed = false
	overtime = false
	ot_hours = 0.0
	Msp.new_day(day)


func _process(_delta: float) -> void:
	if not Campaign.active or Campaign.mode != "tech" or Game.title_mode or World.time_scale <= 0.0:
		return
	var events: Array = events_on(Campaign.day)
	for i in events.size():
		var ev: Dictionary = events[i]
		if not _fired.has(i) and World.clock >= float(ev.at):
			_fired[i] = true
			fire(ev)
	if not _followed and World.clock >= 9.4:
		_followed = true
		_spawn_followups()


# trouble from sloppy jobs comes back the next morning
func queue_followup(item: Dictionary) -> void:
	var entry := item.duplicate()
	entry["due"] = Campaign.day + int(item.get("days", 1))
	var list: Array = flags.get("followups", [])
	list.append(entry)
	flags["followups"] = list


func _spawn_followups() -> void:
	var list: Array = flags.get("followups", [])
	var keep := []
	for item in list:
		if int(item.due) <= Campaign.day:
			Msp.spawn_return(item)
		else:
			keep.append(item)
	flags["followups"] = keep


func fire(ev: Dictionary) -> void:
	match str(ev.kind):
		"mail":
			Msp.mail(str(ev.from), str(ev.subject), str(ev.body))
		"text":
			Msp.send_text(str(ev.from), str(ev.body))
		"backup_break":
			Msp.break_backup(int(ev.client))
		"ransomware":
			_ransomware()
		"playbook":
			Playbook.start(str(ev.book))
			Msp.send_text("Boss", str(ev.get("text", "A big job just came in.")))
		"vignette":
			_vignette(str(ev.id))
		"adobe":
			Msp.create_problem(int(ev.client), Msp.ADOBE, "email")
		"callback_install":
			_callback_install()
		"callback_ransom":
			_callback_ransom()
		"callback_worst":
			_callback_worst()
		"growth_plan":
			Growth.start_plan()
		"growth_block":
			if not Expo.away:
				Growth.offer_block()
		"growth_stretch":
			if not Expo.away:
				Growth.offer_stretch()
		"install":
			var t := Msp.create_problem(0, Msp.INSTALL, "email")
			Msp.start_project(int(t.get("id", 0)))
		"install_followup":
			if flags.get("install", "") == "lost":
				Msp.mail(
					"Dr. Patel <patel@acmedental.example>",
					"XRAY STILL MISSING",
					"I spent the evening reloading the xray software from CDs. Never again. - Patel"
				)
				(
					Msp
					. send_text(
						"Boss",
						"Acme lost their xray software in the migration. Always survey and back up first."
					)
				)


# ---- small quiet-day moments: a short card with a few choices and small effects
func _vignette(id: String) -> void:
	var v: Dictionary = VIGNETTES.get(id, {})
	if v.is_empty():
		return
	var options := []
	for o in v.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(
		str(v.speaker),
		_vignette_text(id, v),
		options,
		func(pick: String) -> void: _vignette_answer(id, pick)
	)


# Alan's donut card follows how the firewall day went: only a documented firewall has a page to praise
func _vignette_text(id: String, v: Dictionary) -> String:
	if id == "donuts" and not bool(flags.get("bus_doc", false)):
		return str(v.get("text_reset" if bool(flags.get("bus_reset", false)) else "text_plain", v.text))
	return str(v.text)


func _vignette_answer(id: String, pick: String) -> void:
	var v: Dictionary = VIGNETTES[id]
	var text := ""
	for o in v.options:
		if str(o.id) == pick:
			text = str(o.text)
			_vignette_fx(o.get("fx", {}))
	Cards.ask(str(v.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _vignette_fx(fx: Dictionary) -> void:
	if fx.has("xp"):
		Skills.add_xp(str(fx.xp[0]), int(fx.xp[1]))
	if fx.has("mood"):
		Sales.adjust(int(fx.mood[0]), int(fx.mood[1]))
	if fx.has("mood_all"):
		for c in Sales.active:
			Sales.adjust(int(c), int(fx.mood_all))
	if fx.has("rep"):
		Campaign.adjust_rep(int(fx.rep))
	for who in fx.get("social", {}):
		Social.change(str(who), int(fx.social[who]))
	if fx.has("social_all"):
		Social.change_all(int(fx.social_all))
	if fx.has("energy"):
		Shift.add_energy(float(fx.energy))
	if fx.has("hours"):
		World.clock += float(fx.hours)


# ---- earlier choices come back later
func _callback_install() -> void:
	var from := "Dr. Patel <patel@acmedental.example>"
	match str(flags.get("install", "")):
		"ok":
			(
				Msp
				. mail(
					from,
					"The new computer",
					"Two weeks in and the whole front desk asks who set up the new PC. The xray software even runs faster. Thank you. - Patel"
				)
			)
			Sales.adjust(0, 6)
		"restored":
			(
				Msp
				. mail(
					from,
					"The new computer",
					"It took an extra day to get the xray software back, but it works. Next time, please ask what I keep on there first. - Patel"
				)
			)
			Sales.adjust(0, 1)
		"lost":
			(
				Msp
				. mail(
					from,
					"Still thinking about the xray software",
					"My staff still talk about the week we spent reloading from CDs. I am asking for a quote from another IT company. - Patel"
				)
			)
			Sales.adjust(0, -8)


func _callback_ransom() -> void:
	var from := "Atty. Spence <spence@hootholler.example>"
	match str(flags.get("ransom", "")):
		"saved":
			(
				Msp
				. mail(
					from,
					"Renewal",
					"After what happened in March, the partners voted to sign a three year renewal. A colleague at another firm asked for your number. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, 8)
			Campaign.adjust_rep(1)
		"partial":
			(
				Msp
				. mail(
					from,
					"Recovered files",
					"We got most of the files back. Two clients' records are gone and I had to call them. The partners are watching your work closely. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, -4)
		"paid":
			(
				Msp
				. mail(
					from,
					"The ransom",
					"The partners still cannot believe we paid criminals in bitcoin. It worked, but we want a real backup plan, now. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, -3)
		"lost":
			(
				Msp
				. mail(
					from,
					"Reviewing our IT provider",
					"We lost two years of client files and had to tell the bar association. The partners are reviewing every IT provider in the county. - Spence"
				)
			)
			Sales.adjust(RANSOM_CLIENT, -12)


# before the review Morgan brings up the job that went worst
func _callback_worst() -> void:
	var names := {
		"install": "THE DESKTOP INSTALL",
		"ransom": "THE RANSOMWARE",
		"rack": "THE FALLEN RACK",
		"migration": "THE SERVER MIGRATION",
		"email24": "THE EMAIL NIGHT",
		"netinstall": "THE NETWORK INSTALL",
		"ceofraud": "THE WIRE FRAUD",
		"no2fa": "THE CLIENT WHO SAID NO",
		"bus": "THE DAY WITHOUT ALAN",
	}
	var scores := {
		"S": 5,
		"A": 4,
		"B": 3,
		"C": 2,
		"D": 1,
		"ok": 5,
		"restored": 3,
		"lost": 1,
		"saved": 5,
		"partial": 3,
		"paid": 2
	}
	var worst_key := ""
	var worst := 99
	for key in names:
		var value := str(flags.get(key, ""))
		if value != "" and int(scores.get(value, 3)) < worst:
			worst = int(scores.get(value, 3))
			worst_key = key
	if worst_key == "" or worst >= 4:
		return
	(
		Msp
		. mail(
			MANAGER.split(" - ")[0] + " <morgan@pixelit.example>",
			"Before we sit down",
			(
				"I will ask about %s. It was your roughest job this year. Think about what you would do differently. - Morgan"
				% str(names[worst_key]).to_lower()
			)
		)
	)


func _ransomware() -> void:
	var t := Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
	if t.is_empty():
		for ep in Msp.endpoints:
			if ep.client == RANSOM_CLIENT and ep.name.contains("SRV"):
				ep.problem = ""
		t = Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
	flags["ransom_ticket"] = int(t.get("id", 0))
	var warning := "Hoot and Holler has a ransom note on their server. "
	warning += "Do NOT pay and do NOT reboot. Restore from backup! (If it fails: shadow copies.)"
	Msp.send_text("Boss", warning)
