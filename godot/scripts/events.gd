extends Node
# gdlint:disable=max-line-length
# The event deck (roadmap R8). One small card per quiet day, drawn in the morning with the seeded
# `events` stream (Difficulty.rng) and shown at a random time between 10:00 and 13:30. Cards use the
# vignette format (speaker, text, options with fx) and the vignette resolver (Story._vignette_fx);
# owner cards also use cash / burnout (Owner.apply). Quiet days only: no draw on a day that already has
# a story vignette, the ransomware, the overtime night, an outing or the trip, the first two days, the
# last day or in Free Play. The 17 extra vignettes live in Story.VIGNETTES (they carry `min_day`) and
# share the same draw. Keep every magnitude small: a card must never make the day unwinnable.

const VERSION := 1
const KINDS := ["tech", "owner", "both"]
const SKILLS := ["networking", "servers", "security", "people"]
const FX_KEYS := ["xp", "mood", "mood_all", "rep", "social", "social_all", "energy", "hours", "cash", "burnout"]
# the biggest absolute value each key may have (xp: up to +6)
const FX_BOUNDS := {
	"xp": 6,
	"mood": 8,
	"mood_all": 4,
	"rep": 1,
	"social": 3,
	"social_all": 2,
	"energy": 6,
	"hours": 0.75,
	"cash": 300,
	"burnout": 4,
}
const OWNER_ONLY := ["cash", "burnout"]
const TECH_ONLY := ["xp", "energy"]
const ALL_NAMES := ["Alan", "Garrison", "Morgan", "Marge", "Dan", "Vic", "Maya"]
const NAMES_FOR := {
	"tech": ["Alan", "Garrison", "Morgan", "Dan", "Vic", "Maya"],
	"owner": ["Alan", "Garrison", "Marge", "Dan", "Vic"],
}
const OWNERS := ["Alan", "Garrison"]
const BUSY_KINDS := ["vignette", "ransomware", "callback_worst"]
const WINDOW_START := 10.0
const WINDOW_LEN := 3.5
const LATEST := 15.5  # a card still waiting at this time is dropped
const MAX_OPTIONS := 3
const MAX_LABEL := 58
const MAX_TEXT := 320
const OPTIONS_OK := [{"label": "OK", "id": "ok"}]

const DEFAULT_DECK := {
	"toner_late": {
		"id": "toner_late",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 8,
		"requires": [],
		"speaker": "The toner supplier",
		"text": "Your order of toner for three clients is a week late. The driver says the truck is 'around'. Two offices are down to their last cartridge.",
		"options": [
			{
				"id": "local",
				"label": "BUY A FEW CARTRIDGES AT THE OFFICE STORE",
				"text": "A little more expensive, but nobody runs out. The cashier asks if you are starting a print shop.",
				"fx": {
					"mood_all": 1,
					"hours": 0.3
				}
			},
			{
				"id": "warn",
				"label": "WARN THE CLIENTS AND ASK THEM TO PRINT LESS",
				"text": "Most of them say they never print anything. They print forty pages an hour.",
				"fx": {
					"mood_all": -1
				}
			},
			{
				"id": "wait",
				"label": "WAIT FOR THE TRUCK",
				"text": "It arrives at 4:50 with the wrong colors in two of the boxes.",
				"fx": {
					"rep": -1
				}
			}
		]
	},
	"heat_wave": {
		"id": "heat_wave",
		"kinds": [
			"both"
		],
		"min_day": 12,
		"max_day": 19,
		"weight": 1.0,
		"cooldown": 12,
		"requires": [],
		"speaker": "The building manager",
		"text": "Heads up: the air conditioning is out in the whole building. The server closet is already at 91 degrees and climbing.",
		"options": [
			{
				"id": "fan",
				"label": "PROP THE DOOR OPEN AND BRING A BIG FAN",
				"text": "It is loud and ugly, but the temperature drops by eight degrees.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "shutdown",
				"label": "SHUT DOWN WHAT YOU CAN SAFELY LIVE WITHOUT",
				"text": "A tidy shutdown of the test box and the old print server. The closet stays under 85.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"hours": 0.5,
					"mood_all": -1
				}
			},
			{
				"id": "hope",
				"label": "HOPE THEY FIX IT BEFORE LUNCH",
				"text": "They fix it at 2:30. The fans in the NAS sound like a jet engine until then.",
				"fx": {
					"rep": -1
				}
			}
		]
	},
	"free_pizza": {
		"id": "free_pizza",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 10,
		"requires": [],
		"speaker": "A vendor rep",
		"text": "I had a lunch-and-learn cancelled and I have six large pizzas going cold in my car. Would your team like them? No presentation, I promise. Maybe a short one.",
		"options": [
			{
				"id": "yes",
				"label": "SAY YES AND CALL EVERYONE TO THE KITCHEN",
				"text": "The whole floor shows up in about eleven seconds. Somebody makes a joke about the thin crust.",
				"fx": {
					"social_all": 2
				}
			},
			{
				"id": "one",
				"label": "TAKE ONE BOX AND SEND HIM ON HIS WAY",
				"text": "He leaves a brochure on top of the box. You do not read it.",
				"fx": {
					"social_all": 1
				}
			},
			{
				"id": "no",
				"label": "SAY NO, YOU HAVE A SERVICE CALL",
				"text": "The pizza goes to the dentist next door instead.",
				"fx": {}
			}
		]
	},
	"cold_snap": {
		"id": "cold_snap",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 6,
		"weight": 1.2,
		"cooldown": 15,
		"requires": [],
		"speaker": "A client's office manager",
		"text": "It is freezing and the whole office brought in space heaters. Three of them are plugged into one power strip under my desk. Is that bad?",
		"options": [
			{
				"id": "circuits",
				"label": "SPLIT THEM ACROSS CIRCUITS AND SHOW HER THE BREAKER BOX",
				"text": "Nothing trips all day. She says you are very calm for a person with a flashlight.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"mood": [
						2,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "strip",
				"label": "BUY THEM A PROPER SURGE STRIP",
				"text": "It is not the real answer, but it is better than what they had.",
				"fx": {
					"mood": [
						2,
						1
					]
				}
			},
			{
				"id": "leave",
				"label": "TELL HER IT IS FINE",
				"text": "At 2:15 the breaker trips and the server restarts by itself. Nobody is happy.",
				"fx": {
					"mood": [
						2,
						-5
					]
				}
			}
		]
	},
	"lost_phone": {
		"id": "lost_phone",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "{c}",
		"text": "I cannot find my phone anywhere. I think I left it in the van, or at the pizza place, or in a client's bathroom. Could you ring it?",
		"options": [
			{
				"id": "ring",
				"label": "CALL IT AND FOLLOW THE RINGTONE",
				"text": "It was in the van, between the seats. Thank you, thank you.",
				"fx": {
					"social": {
						"{c}": 2
					},
					"hours": 0.2
				}
			},
			{
				"id": "locate",
				"label": "USE THE LOCATE-MY-PHONE PAGE AND LOCK IT",
				"text": "The map shows it a block away. You walk over together, and it was in the van all along.",
				"fx": {
					"social": {
						"{c}": 2
					},
					"hours": 0.3
				}
			},
			{
				"id": "later",
				"label": "SAY YOU WILL HELP AFTER THIS TICKET",
				"text": "It turns up by itself. They are a little quiet at lunch.",
				"fx": {
					"social": {
						"{c}": -1
					}
				}
			}
		]
	},
	"cousin_site": {
		"id": "cousin_site",
		"kinds": [
			"both"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 12,
		"requires": [],
		"speaker": "A client",
		"text": "My cousin builds websites and he says our current one is 'so 2009'. He wants admin access to everything for a week. Is that okay?",
		"options": [
			{
				"id": "scope",
				"label": "ASK WHAT HE NEEDS AND GIVE HIM ONLY THAT",
				"text": "You set up a separate login for the website host and nothing else. He is a little disappointed.",
				"fx": {
					"xp": [
						"security",
						3
					],
					"mood": [
						1,
						3
					]
				}
			},
			{
				"id": "meet",
				"label": "OFFER TO MEET THE COUSIN FIRST",
				"text": "He turns out to be nice and a bit overcommitted. The new site is going to be fine.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						1,
						2
					],
					"hours": 0.4
				}
			},
			{
				"id": "full",
				"label": "GIVE HIM THE PASSWORDS, SOMEONE HAS TO",
				"text": "Two weeks later the domain registrar sends a strange email. You will deal with it later.",
				"fx": {
					"rep": -1
				}
			}
		]
	},
	"toner_mixup": {
		"id": "toner_mixup",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 10,
		"requires": [],
		"speaker": "The front desk at a client",
		"text": "The toner that came today is for a different printer model. The box says laser but the printer says something else, and we have a stack of invoices to send.",
		"options": [
			{
				"id": "swap",
				"label": "CALL THE SUPPLIER AND ARRANGE A SWAP",
				"text": "They send the right one by courier. Only half of the apology is believable.",
				"fx": {
					"mood": [
						3,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "test",
				"label": "CHECK THE PART NUMBER AND TRY IT ANYWAY",
				"text": "It almost fits. After twenty minutes it very much does not.",
				"fx": {
					"xp": [
						"servers",
						2
					],
					"hours": 0.5
				}
			},
			{
				"id": "print",
				"label": "PRINT THE INVOICES AT YOUR OWN OFFICE",
				"text": "You print and drive them over. They say they will buy you lunch someday.",
				"fx": {
					"mood": [
						3,
						4
					],
					"hours": 0.6
				}
			}
		]
	},
	"leaky_ceiling": {
		"id": "leaky_ceiling",
		"kinds": [
			"both"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 14,
		"requires": [],
		"speaker": "The landlord's handyman",
		"text": "There is a drip coming through the ceiling tile right above your server closet. I have a bucket. What do you want me to do?",
		"options": [
			{
				"id": "tarp",
				"label": "COVER THE RACK WITH A TARP AND MOVE THE UPS",
				"text": "You and the handyman do it in ten minutes. He calls you 'the cable guy' and it is not meant as an insult.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "shutdown",
				"label": "POWER DOWN THE BOTTOM OF THE RACK",
				"text": "Safer, and a little dramatic. The roofer shows up the next morning.",
				"fx": {
					"xp": [
						"servers",
						2
					],
					"hours": 0.5,
					"mood_all": -1
				}
			},
			{
				"id": "bucket",
				"label": "LEAVE THE BUCKET AND KEEP WORKING",
				"text": "The bucket holds. Mostly.",
				"fx": {
					"rep": -1
				}
			}
		]
	},
	"dropbox_it": {
		"id": "dropbox_it",
		"kinds": [
			"both"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 12,
		"requires": [],
		"speaker": "A client's accountant",
		"text": "I moved all our client folders to a Dropbox account I made myself. It is so much easier than the file server. Can you just give my partner access too?",
		"options": [
			{
				"id": "manage",
				"label": "OFFER TO SET UP A BUSINESS ACCOUNT WITH RULES",
				"text": "Shared folders, a policy and an admin. She says that sounds like a lot, then thanks you.",
				"fx": {
					"xp": [
						"security",
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
				"id": "ban",
				"label": "TELL HER IT IS AGAINST THE POLICY",
				"text": "She stops. She also stops answering your mail for a day.",
				"fx": {
					"mood": [
						3,
						-4
					]
				}
			},
			{
				"id": "allow",
				"label": "LET HER KEEP IT, YOU HAVE MORE URGENT THINGS",
				"text": "It works. It also adds a mystery that will probably come up again.",
				"fx": {
					"rep": -1
				}
			}
		]
	},
	"first_chromebook": {
		"id": "first_chromebook",
		"kinds": [
			"both"
		],
		"min_day": 7,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 20,
		"requires": [],
		"speaker": "A client",
		"text": "I bought one of those little Chromebooks for $249 at the store. Can you put our software on it? I thought it was just like a normal laptop.",
		"options": [
			{
				"id": "explain",
				"label": "EXPLAIN WHAT IT CAN AND CAN NOT RUN",
				"text": "It runs the web version of everything but the practice software. She decides to keep it for the waiting room.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						1,
						3
					]
				}
			},
			{
				"id": "remote",
				"label": "SET UP A REMOTE DESKTOP SESSION TO THE OFFICE PC",
				"text": "It works, a little oddly. She is delighted, and tells her friends about it.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"mood": [
						1,
						2
					],
					"hours": 0.5
				}
			},
			{
				"id": "return",
				"label": "SUGGEST SHE RETURN IT",
				"text": "She sighs and puts the box back in the car.",
				"fx": {
					"mood": [
						1,
						-3
					]
				}
			}
		]
	},
	"xp_panic": {
		"id": "xp_panic",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 9,
		"weight": 1.4,
		"cooldown": 14,
		"requires": [],
		"speaker": "A client",
		"text": "My nephew says Windows XP stops being supported on April 8 and that after that every virus in the world will get in. Is it true? I have six of those computers.",
		"options": [
			{
				"id": "plan",
				"label": "MAKE A LIST OF EVERY XP MACHINE AND A SCHEDULE",
				"text": "Six machines, three months, and a quote she can show her husband.",
				"fx": {
					"xp": [
						"people",
						4
					],
					"mood": [
						1,
						4
					],
					"hours": 0.5
				}
			},
			{
				"id": "calm",
				"label": "TELL HER IT WILL BE FINE FOR NOW",
				"text": "That is sort of true. She still asks again on Friday.",
				"fx": {
					"mood": [
						1,
						1
					]
				}
			},
			{
				"id": "scare",
				"label": "TELL HER SHE SHOULD HAVE LISTENED LAST YEAR",
				"text": "She did not enjoy that.",
				"fx": {
					"mood": [
						1,
						-4
					]
				}
			}
		]
	},
	"exchange_q": {
		"id": "exchange_q",
		"kinds": [
			"both"
		],
		"min_day": 5,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 20,
		"requires": [],
		"speaker": "A client",
		"text": "A vendor says we should move our email 'to the cloud' and get it hosted Exchange for $12 a mailbox. We have six people and an old server. Does that make sense?",
		"options": [
			{
				"id": "compare",
				"label": "WRITE A SHORT COMPARISON FOR THE OWNER",
				"text": "Costs, risks, and what happens to the old mail. It is clear and she appreciates it.",
				"fx": {
					"xp": [
						"people",
						4
					],
					"mood": [
						4,
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "pilot",
				"label": "PROPOSE A TEST WITH TWO MAILBOXES",
				"text": "You migrate two people. It goes fine, and the vendor's dashboard has a surprise or two.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"hours": 0.6
				}
			},
			{
				"id": "wait",
				"label": "TELL HER YOU WILL LOOK INTO IT SOMETIME",
				"text": "Sometime turns into 'another time'.",
				"fx": {
					"mood": [
						4,
						-2
					]
				}
			}
		]
	},
	"tax_season": {
		"id": "tax_season",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 9,
		"weight": 1.3,
		"cooldown": 12,
		"requires": [],
		"speaker": "The accountant at a client",
		"text": "It is tax season and my staff are calling you twice as often. They are in the same room, so please just answer both of them.",
		"options": [
			{
				"id": "both",
				"label": "ANSWER BOTH, BACK TO BACK",
				"text": "You answer in order and they thank you for the same two fixes. Two answers, one problem.",
				"fx": {
					"xp": [
						"people",
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
				"id": "queue",
				"label": "SET UP ONE PERSON AS THE CONTACT",
				"text": "A single contact helps a lot. It also helps you.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						3,
						2
					]
				}
			},
			{
				"id": "bill",
				"label": "REMIND THEM THIS IS OUTSIDE THE AGREEMENT",
				"text": "True, but not what they were hoping for in April.",
				"fx": {
					"mood": [
						3,
						-4
					]
				}
			}
		]
	},
	"office_move": {
		"id": "office_move",
		"kinds": [
			"both"
		],
		"min_day": 6,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 24,
		"requires": [],
		"speaker": "A client",
		"text": "We are moving to a new suite across the parking lot in a month. Can you tell me what the network needs? I would rather not find out on moving day.",
		"options": [
			{
				"id": "survey",
				"label": "WALK THE NEW SPACE WITH A TAPE MEASURE",
				"text": "You count drops, check for a closet and write it all down. She hugs the clipboard.",
				"fx": {
					"xp": [
						"networking",
						4
					],
					"mood": [
						2,
						4
					],
					"hours": 0.6
				}
			},
			{
				"id": "quote",
				"label": "SEND A QUOTE FOR THE MOVE",
				"text": "She replies with 'wow, you think of everything'.",
				"fx": {
					"xp": [
						"people",
						2
					],
					"mood": [
						2,
						2
					]
				}
			},
			{
				"id": "later",
				"label": "ASK HER TO CALL BACK CLOSER TO THE DATE",
				"text": "She calls back the night before. You are not very available.",
				"fx": {
					"mood": [
						2,
						-3
					]
				}
			}
		]
	},
	"home_printer": {
		"id": "home_printer",
		"kinds": [
			"both"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.2,
		"cooldown": 8,
		"requires": [],
		"speaker": "A client",
		"text": "I know this is not work, but can you just look at my home printer? It has been blinking at me since Sunday. I will buy you lunch.",
		"options": [
			{
				"id": "lunch",
				"label": "OFFER TO LOOK AT IT AT THE OFFICE",
				"text": "It was a loose paper tray. Lunch is a sandwich, and a good one.",
				"fx": {
					"mood": [
						0,
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "phone",
				"label": "WALK HER THROUGH IT ON THE PHONE",
				"text": "Four minutes. The blinking was the tray. She is thrilled.",
				"fx": {
					"mood": [
						0,
						2
					],
					"hours": 0.2
				}
			},
			{
				"id": "nope",
				"label": "SAY IT IS NOT IN THE CONTRACT",
				"text": "True, and she understands. A little.",
				"fx": {
					"mood": [
						0,
						-2
					]
				}
			}
		]
	},
	"licence_audit": {
		"id": "licence_audit",
		"kinds": [
			"both"
		],
		"min_day": 8,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 20,
		"requires": [],
		"speaker": "A letter from a software trade group",
		"text": "The letter says it is 'a friendly reminder to review your licensing'. It lists a deadline and the number of your office PCs, which is correct.",
		"options": [
			{
				"id": "review",
				"label": "AUDIT EVERY CLIENT'S LICENSES BEFORE THE DEADLINE",
				"text": "You find two stray installs and one very expired trial. Better you than them.",
				"fx": {
					"xp": [
						"security",
						4
					],
					"rep": 1,
					"hours": 0.6
				}
			},
			{
				"id": "clean",
				"label": "SCAN OUR OWN MACHINES AND LEAVE IT AT THAT",
				"text": "Our house is in order. The letter goes into a drawer with the others.",
				"fx": {
					"xp": [
						"servers",
						2
					]
				}
			},
			{
				"id": "ignore",
				"label": "PUT THE LETTER IN THE PILE",
				"text": "A second letter, not so friendly, shows up in three weeks.",
				"fx": {
					"rep": -1
				}
			}
		]
	},
	"pw_reset_call": {
		"id": "pw_reset_call",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.2,
		"cooldown": 6,
		"requires": [],
		"speaker": "A client",
		"text": "I changed my password last week and now I cannot remember it. I wrote it down, but I wrote it on a sticky note and that note has been through the wash.",
		"options": [
			{
				"id": "reset",
				"label": "RESET IT AND SET UP A PASSWORD HINT SHEET",
				"text": "She feels silly. You tell her it is the number two call of the week.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						0,
						3
					],
					"hours": 0.2
				}
			},
			{
				"id": "manager",
				"label": "SUGGEST A PASSWORD MANAGER",
				"text": "She likes the idea. She also writes the master password on a sticky note.",
				"fx": {
					"xp": [
						"security",
						3
					],
					"mood": [
						0,
						1
					],
					"hours": 0.3
				}
			},
			{
				"id": "quick",
				"label": "RESET IT AND HANG UP",
				"text": "Efficient. A bit short.",
				"fx": {
					"mood": [
						0,
						-1
					]
				}
			}
		]
	},
	"guest_wifi": {
		"id": "guest_wifi",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "The office manager at a client",
		"text": "We have guests in the waiting room asking for the Wi-Fi and I am giving out the main password. Is there a better way?",
		"options": [
			{
				"id": "guest",
				"label": "SET UP A SEPARATE GUEST NETWORK",
				"text": "A new name, a new password, and no access to the files. She puts it on a card at the front desk.",
				"fx": {
					"xp": [
						"networking",
						4
					],
					"mood": [
						0,
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "change",
				"label": "CHANGE THE PASSWORD AND TELL HER TO KEEP IT SECRET",
				"text": "Less of a plan than it sounds. It works for a month.",
				"fx": {
					"xp": [
						"networking",
						1
					],
					"mood": [
						0,
						1
					]
				}
			},
			{
				"id": "sign",
				"label": "TELL HER TO TAPE A SIGN TO THE ROUTER",
				"text": "That is not an answer.",
				"fx": {
					"mood": [
						0,
						-3
					]
				}
			}
		]
	},
	"scam_call": {
		"id": "scam_call",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 12,
		"requires": [],
		"speaker": "A client",
		"text": "A man called from 'Windows technical support' and said my computer had a virus. He asked me to go to a website. I did, and then I thought I should call you.",
		"options": [
			{
				"id": "clean",
				"label": "REMOTE IN, CHECK EVERYTHING AND CHANGE HER PASSWORDS",
				"text": "She gave him access for ten minutes. You find the tool and remove it. She will not forget this call.",
				"fx": {
					"xp": [
						"security",
						5
					],
					"mood": [
						1,
						3
					],
					"hours": 0.6
				}
			},
			{
				"id": "tell",
				"label": "EXPLAIN HOW THOSE CALLS WORK AND HANG UP",
				"text": "A short lesson. She nods firmly.",
				"fx": {
					"xp": [
						"security",
						2
					]
				}
			},
			{
				"id": "brief",
				"label": "SEND A WARNING TO ALL CLIENTS",
				"text": "A short note, written in plain English. Several of them reply with 'thank you', one with 'what scam?'.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood_all": 1,
					"hours": 0.5
				}
			}
		]
	},
	"found_usb": {
		"id": "found_usb",
		"kinds": [
			"tech"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "The cleaner at a client",
		"text": "I found a little USB stick in the parking lot. It says 'PAYROLL' in marker. Should I give it to someone? I did not plug it in.",
		"options": [
			{
				"id": "sandbox",
				"label": "TAKE IT, SCAN IT ON AN ISOLATED MACHINE",
				"text": "It is blank apart from a copy of a cat picture. Still, a good call.",
				"fx": {
					"xp": [
						"security",
						4
					],
					"hours": 0.3
				}
			},
			{
				"id": "bin",
				"label": "TELL HER TO THROW IT AWAY",
				"text": "Fine, and done. Her face says she would have liked a bit more.",
				"fx": {
					"xp": [
						"security",
						1
					]
				}
			},
			{
				"id": "plug",
				"label": "PLUG IT INTO YOUR WORKSTATION TO SEE",
				"text": "The antivirus has opinions. You spend an hour cleaning up.",
				"fx": {
					"energy": -3,
					"hours": 0.5
				}
			}
		]
	},
	"coffee_machine": {
		"id": "coffee_machine",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 10,
		"requires": [],
		"speaker": "{c}",
		"text": "The coffee machine just coughed and stopped. I cannot work like this. You are good with machines. Please?",
		"options": [
			{
				"id": "descale",
				"label": "DESCALE IT, YOU HAVE DONE THIS BEFORE",
				"text": "It sputters, clears its throat and makes a perfect cup. The room applauds.",
				"fx": {
					"energy": 4,
					"social": {
						"{c}": 2
					},
					"hours": 0.3
				}
			},
			{
				"id": "order",
				"label": "SUGGEST SPLITTING THE COST OF A NEW ONE",
				"text": "A good idea. The new machine arrives on Friday.",
				"fx": {
					"energy": 1,
					"social_all": 1
				}
			},
			{
				"id": "tea",
				"label": "SUGGEST TEA",
				"text": "The look you get is not at all like tea.",
				"fx": {
					"social": {
						"{c}": -1
					}
				}
			}
		]
	},
	"tape_check": {
		"id": "tape_check",
		"kinds": [
			"tech"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 14,
		"requires": [],
		"speaker": "A client",
		"text": "My nephew says tape backups are old fashioned and that we should send everything to the cloud. We have been using the tapes for nine years. Do I need to change?",
		"options": [
			{
				"id": "explain",
				"label": "EXPLAIN THE OPTIONS AND WHAT EACH ONE COSTS",
				"text": "She chooses a cloud copy and keeps one tape in the safe. Sensible.",
				"fx": {
					"xp": [
						"security",
						3
					],
					"mood": [
						0,
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "test",
				"label": "TEST A RESTORE FROM THE OLDEST TAPE",
				"text": "It restores perfectly except for one folder. You are glad you asked.",
				"fx": {
					"xp": [
						"security",
						5
					],
					"hours": 0.7
				}
			},
			{
				"id": "keep",
				"label": "TELL HER THEY ARE FINE",
				"text": "Until they are not.",
				"fx": {
					"mood": [
						0,
						-1
					]
				}
			}
		]
	},
	"spreadsheet_help": {
		"id": "spreadsheet_help",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 8,
		"requires": [],
		"speaker": "{c}",
		"text": "Do you know how to make a column add itself up in the spreadsheet? Not the whole thing, only if the cell says 'paid'? I have been at it for forty minutes.",
		"options": [
			{
				"id": "show",
				"label": "SHOW THEM, AND LEARN SOMETHING TOO",
				"text": "A small formula. You both look at it for a moment, impressed.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"social": {
						"{c}": 2
					},
					"hours": 0.3
				}
			},
			{
				"id": "do",
				"label": "DO IT FOR THEM",
				"text": "It is done in a minute. They say you are a wizard, quietly.",
				"fx": {
					"social": {
						"{c}": 1
					},
					"hours": 0.1
				}
			},
			{
				"id": "later",
				"label": "TELL THEM TO ASK YOU LATER",
				"text": "Later never quite happens.",
				"fx": {
					"social": {
						"{c}": -1
					}
				}
			}
		]
	},
	"power_blip": {
		"id": "power_blip",
		"kinds": [
			"tech"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "A client",
		"text": "There was a thunderstorm and the lights flickered. Everything came back, but the server is beeping, and the beeping is in a rhythm.",
		"options": [
			{
				"id": "ups",
				"label": "CHECK THE UPS AND LOG THE EVENT",
				"text": "The battery needs replacing soon. You write a note.",
				"fx": {
					"xp": [
						"servers",
						4
					],
					"mood": [
						2,
						2
					],
					"hours": 0.4
				}
			},
			{
				"id": "silence",
				"label": "SILENCE IT AND CHECK THE SERVER LOGS",
				"text": "A clean restart, a clean shutdown. Good news, and a quiet room.",
				"fx": {
					"xp": [
						"servers",
						3
					],
					"hours": 0.3
				}
			},
			{
				"id": "ignore",
				"label": "TELL THEM TO PRESS THE MUTE BUTTON",
				"text": "It beeps again at 3 AM, in the dark.",
				"fx": {
					"mood": [
						2,
						-3
					]
				}
			}
		]
	},
	"conference_call": {
		"id": "conference_call",
		"kinds": [
			"tech"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 10,
		"requires": [],
		"speaker": "A client",
		"text": "We are about to hold a conference call with a new customer and the speakerphone has no sound. The meeting starts in ten minutes. I am sweating.",
		"options": [
			{
				"id": "fast",
				"label": "RUN OVER AND SET UP A LAPTOP AS THE SPEAKER",
				"text": "You plug it in, set the volume, and everybody smiles. They get the contract.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						3,
						5
					],
					"hours": 0.5,
					"energy": -2
				}
			},
			{
				"id": "phone",
				"label": "WALK THEM THROUGH IT FROM HERE",
				"text": "It takes four of the ten minutes, and the meeting starts on time.",
				"fx": {
					"xp": [
						"networking",
						2
					],
					"mood": [
						3,
						3
					],
					"hours": 0.2
				}
			},
			{
				"id": "book",
				"label": "TELL THEM TO RESCHEDULE",
				"text": "The new customer is not impressed.",
				"fx": {
					"mood": [
						3,
						-5
					]
				}
			}
		]
	},
	"old_pc_donation": {
		"id": "old_pc_donation",
		"kinds": [
			"tech"
		],
		"min_day": 5,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 20,
		"requires": [],
		"speaker": "The school secretary",
		"text": "Our school computer lab needs machines. Do your clients ever throw away old ones? We would take anything that boots.",
		"options": [
			{
				"id": "wipe",
				"label": "WIPE A FEW OLD PCS PROPERLY AND DONATE THEM",
				"text": "A pallet of Windows 7 machines goes to the school. The kids send you a drawing of a PC.",
				"fx": {
					"xp": [
						"security",
						4
					],
					"social_all": 1,
					"hours": 0.6
				}
			},
			{
				"id": "list",
				"label": "TAKE A LIST AND PASS IT ON",
				"text": "A small thing, but they will be back next month.",
				"fx": {
					"xp": [
						"people",
						2
					]
				}
			},
			{
				"id": "no",
				"label": "TELL HER WE HAVE NOTHING",
				"text": "True this week.",
				"fx": {}
			}
		]
	},
	"lunch_run": {
		"id": "lunch_run",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 8,
		"requires": [],
		"speaker": "{c}",
		"text": "I am doing a sandwich run. Want me to get you something? Last time I got your order wrong, so this time I am writing it down.",
		"options": [
			{
				"id": "big",
				"label": "A BIG SANDWICH AND SOMETHING TO DRINK",
				"text": "It is perfect. You feel human again.",
				"fx": {
					"energy": 5,
					"social": {
						"{c}": 1
					}
				}
			},
			{
				"id": "salad",
				"label": "A SALAD",
				"text": "It is a very good salad.",
				"fx": {
					"energy": 2,
					"social": {
						"{c}": 1
					}
				}
			},
			{
				"id": "skip",
				"label": "NO THANKS, YOU HAVE A TICKET",
				"text": "You eat a granola bar over the keyboard.",
				"fx": {
					"energy": -2
				}
			}
		]
	},
	"phish_invoice": {
		"id": "phish_invoice",
		"kinds": [
			"tech"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "A client",
		"text": "I got an email from a shipping company with an invoice attached, but I never ordered anything. I did not open it. I think. Maybe I did.",
		"options": [
			{
				"id": "check",
				"label": "CHECK HER PC AND THE MAIL SERVER",
				"text": "She did open it, but the attachment did not run. You block the sender.",
				"fx": {
					"xp": [
						"security",
						5
					],
					"mood": [
						1,
						3
					],
					"hours": 0.5
				}
			},
			{
				"id": "teach",
				"label": "TEACH THE WHOLE OFFICE WHAT TO LOOK FOR",
				"text": "A fifteen-minute talk in the break room. The cookies helped.",
				"fx": {
					"xp": [
						"people",
						4
					],
					"mood": [
						1,
						4
					],
					"hours": 0.6
				}
			},
			{
				"id": "delete",
				"label": "TELL HER TO DELETE IT",
				"text": "True, but she wanted to know what it was.",
				"fx": {
					"mood": [
						1,
						-2
					]
				}
			}
		]
	},
	"sticky_password": {
		"id": "sticky_password",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 10,
		"requires": [],
		"speaker": "A visiting client",
		"text": "I am not sure it is smart to say, but everybody here keeps their password on a sticky note on the monitor. Is that a problem?",
		"options": [
			{
				"id": "audit",
				"label": "OFFER A PASSWORD CLEAN-UP AND A SHORT TALK",
				"text": "You sit with each person for two minutes. It makes a real difference.",
				"fx": {
					"xp": [
						"security",
						4
					],
					"mood": [
						0,
						3
					],
					"hours": 0.6
				}
			},
			{
				"id": "drawer",
				"label": "SUGGEST A LOCKED DRAWER AS A START",
				"text": "A first step. It will do for now.",
				"fx": {
					"xp": [
						"security",
						2
					],
					"mood": [
						0,
						1
					]
				}
			},
			{
				"id": "fine",
				"label": "SAY IT IS FINE IF NOBODY VISITS",
				"text": "A visitor is sitting right there, and she writes it down.",
				"fx": {
					"mood": [
						0,
						-2
					]
				}
			}
		]
	},
	"projector_cart": {
		"id": "projector_cart",
		"kinds": [
			"tech"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 10,
		"requires": [],
		"speaker": "A client",
		"text": "We have a projector in the conference room and nobody knows how to connect it. The laptop says 'No signal'. We have a presentation in twenty minutes.",
		"options": [
			{
				"id": "keys",
				"label": "SHOW THEM THE KEY COMBINATION FOR THE SECOND SCREEN",
				"text": "Fn plus a function key. They look at you as if you had performed magic.",
				"fx": {
					"xp": [
						"networking",
						3
					],
					"mood": [
						4,
						4
					],
					"hours": 0.3
				}
			},
			{
				"id": "cable",
				"label": "REPLACE THE OLD CABLE",
				"text": "The old cable had a bent pin. You hand over the spare.",
				"fx": {
					"xp": [
						"servers",
						2
					],
					"mood": [
						4,
						3
					],
					"hours": 0.4
				}
			},
			{
				"id": "no",
				"label": "TELL THEM TO REBOOT AND TRY AGAIN",
				"text": "It works. It also takes twenty minutes.",
				"fx": {
					"mood": [
						4,
						-2
					]
				}
			}
		]
	},
	"bad_cable": {
		"id": "bad_cable",
		"kinds": [
			"tech"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "A client",
		"text": "Our Internet is slow in one room, but only on Tuesdays, only after lunch. Everyone says it is a coincidence. I do not think so.",
		"options": [
			{
				"id": "trace",
				"label": "WALK THE CABLE AND FIND WHAT HAPPENS AFTER LUNCH",
				"text": "The microwave and a bad switch share an outlet. You move one.",
				"fx": {
					"xp": [
						"networking",
						5
					],
					"mood": [
						2,
						4
					],
					"hours": 0.7
				}
			},
			{
				"id": "log",
				"label": "ASK HER TO KEEP A LOG FOR A WEEK",
				"text": "A week later the log is very clear.",
				"fx": {
					"xp": [
						"people",
						3
					],
					"mood": [
						2,
						2
					]
				}
			},
			{
				"id": "restart",
				"label": "RESTART THE ROUTER",
				"text": "It is better on Wednesday. On Tuesday it is the same.",
				"fx": {
					"mood": [
						2,
						-1
					]
				}
			}
		]
	},
	"insurance_agent": {
		"id": "insurance_agent",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 12,
		"requires": [],
		"speaker": "An insurance agent",
		"text": "After the Target news every client is asking about cyber liability cover. I can write you a policy for your company, and a short brochure for your clients.",
		"options": [
			{
				"id": "policy",
				"label": "TAKE THE POLICY FOR THE COMPANY",
				"text": "A fair premium, and one more thing the clients ask about. Fewer sleepless nights.",
				"fx": {
					"cash": -200,
					"rep": 1
				}
			},
			{
				"id": "brochure",
				"label": "TAKE THE BROCHURE ONLY",
				"text": "It is decent. A few clients keep it on their desk.",
				"fx": {
					"cash": -30,
					"mood_all": 1
				}
			},
			{
				"id": "pass",
				"label": "PASS",
				"text": "He leaves a business card and a pen.",
				"fx": {}
			}
		]
	},
	"payroll_error": {
		"id": "payroll_error",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 12,
		"requires": [],
		"speaker": "Marge (Bookkeeper)",
		"text": "The bank charged us for a payroll run twice. I found it, I called them, and I have a refund in writing. I need ten minutes of your time to sign something.",
		"options": [
			{
				"id": "sign",
				"label": "SIGN IT AND THANK HER",
				"text": "A refund of $220 is on the way. She smiles, once.",
				"fx": {
					"cash": 220,
					"burnout": -1
				}
			},
			{
				"id": "meet",
				"label": "TAKE HER TO LUNCH",
				"text": "It costs forty dollars and buys a lot of loyalty.",
				"fx": {
					"cash": -40,
					"burnout": -2
				}
			},
			{
				"id": "busy",
				"label": "TELL HER YOU WILL SIGN IT TOMORROW",
				"text": "A day late. The refund comes a day later too.",
				"fx": {
					"cash": 100
				}
			}
		]
	},
	"van_tire": {
		"id": "van_tire",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.9,
		"cooldown": 10,
		"requires": [
			"client:2"
		],
		"speaker": "Marge (Bookkeeper)",
		"text": "The company van has a flat tire in the parking lot of Gnarly Gnomes. The jack is missing. The spare is also a bit flat.",
		"options": [
			{
				"id": "tow",
				"label": "CALL ROADSIDE ASSISTANCE",
				"text": "They are quick, and polite, and it costs $90.",
				"fx": {
					"cash": -90,
					"mood": [
						2,
						1
					]
				}
			},
			{
				"id": "fix",
				"label": "FIX IT YOURSELF AND BORROW A JACK",
				"text": "It takes an hour. Someone takes your photo.",
				"fx": {
					"cash": -30,
					"burnout": 2,
					"hours": 0.4
				}
			},
			{
				"id": "wait",
				"label": "GET A RIDE AND LEAVE IT FOR TOMORROW",
				"text": "The visit is rescheduled. Gnarly Gnomes does not love that.",
				"fx": {
					"mood": [
						2,
						-4
					]
				}
			}
		]
	},
	"referral_gift": {
		"id": "referral_gift",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 16,
		"requires": [],
		"speaker": "A happy client",
		"text": "I gave your name to a friend who owns a dry-cleaning shop. She is going to call. I hope that is alright. Also, here is a gift card for the team.",
		"options": [
			{
				"id": "thank",
				"label": "WRITE A HANDWRITTEN THANK YOU",
				"text": "She puts it on her desk. The lead calls the next week.",
				"fx": {
					"cash": 250,
					"mood_all": 1
				}
			},
			{
				"id": "share",
				"label": "SPLIT THE GIFT CARD WITH THE TEAM",
				"text": "Everyone gets a free lunch. Morale goes up a little.",
				"fx": {
					"burnout": -3
				}
			},
			{
				"id": "keep",
				"label": "KEEP THE CARD FOR YOURSELF",
				"text": "You get a very nice dinner. Marge does not mention it, and you hear her not mentioning it.",
				"fx": {
					"cash": 60,
					"burnout": 1
				}
			}
		]
	},
	"rebate_check": {
		"id": "rebate_check",
		"kinds": [
			"owner"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 16,
		"requires": [],
		"speaker": "A distributor's account manager",
		"text": "Your quarterly rebate check is ready. It is a little smaller than last time because of a new tier. I can explain, or you can just deposit it.",
		"options": [
			{
				"id": "deposit",
				"label": "DEPOSIT IT, THANK YOU",
				"text": "$180 into the account. A quiet small win.",
				"fx": {
					"cash": 180
				}
			},
			{
				"id": "ask",
				"label": "ASK HIM TO EXPLAIN THE NEW TIER",
				"text": "A twenty-minute call. You learn how to reach the next tier, and how many licenses it takes.",
				"fx": {
					"cash": 180,
					"burnout": 1
				}
			},
			{
				"id": "push",
				"label": "TELL HIM THE OLD RATE IS FINE",
				"text": "He says he will see what he can do. He does not.",
				"fx": {}
			}
		]
	},
	"birthday_cake": {
		"id": "birthday_cake",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "The team",
		"text": "It is someone's birthday and the break room smells like a bakery. We bought a cake. Come and cut it before it gets too sad.",
		"options": [
			{
				"id": "cut",
				"label": "CUT THE CAKE AND SAY A FEW WORDS",
				"text": "Everyone claps. A very small speech, a very big cake.",
				"fx": {
					"burnout": -3,
					"cash": -20
				}
			},
			{
				"id": "pop",
				"label": "POP IN FOR A MINUTE",
				"text": "A slice of cake, a joke, and out. Good enough.",
				"fx": {
					"burnout": -1
				}
			},
			{
				"id": "busy",
				"label": "SEND YOUR REGRETS",
				"text": "Somebody saves you a slice. It is a bit stale by 4:00.",
				"fx": {
					"burnout": 1
				}
			}
		]
	},
	"copier_lease": {
		"id": "copier_lease",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 16,
		"requires": [],
		"speaker": "The copier salesman",
		"text": "Your copier lease is up in sixty days. I can renew at a slightly higher rate, or I can put you in a newer model with a longer contract. The newer one does color.",
		"options": [
			{
				"id": "renew",
				"label": "RENEW THE OLD ONE",
				"text": "Predictable and cheap. The old copier sighs with relief.",
				"fx": {
					"cash": -60
				}
			},
			{
				"id": "newer",
				"label": "TAKE THE NEWER MODEL",
				"text": "It is faster, it has color, and the contract is long. The team loves it.",
				"fx": {
					"cash": -150,
					"burnout": -2
				}
			},
			{
				"id": "shop",
				"label": "SHOP AROUND FOR A BETTER PRICE",
				"text": "It takes you an evening and saves $70.",
				"fx": {
					"cash": 70,
					"burnout": 2
				}
			}
		]
	},
	"chamber_lunch": {
		"id": "chamber_lunch",
		"kinds": [
			"owner"
		],
		"min_day": 4,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 14,
		"requires": [],
		"speaker": "The chamber of commerce",
		"text": "Our monthly lunch is this Thursday. Small business owners, a keynote about marketing, and a very long raffle. Your seat is saved, if you want it.",
		"options": [
			{
				"id": "go",
				"label": "GO AND TALK TO PEOPLE",
				"text": "A prospect hands you a card. The raffle prize is a pen. The prospect is better than the pen.",
				"fx": {
					"cash": -35,
					"mood_all": 1,
					"burnout": 1
				}
			},
			{
				"id": "send",
				"label": "SEND VIC",
				"text": "He comes back with three business cards and a story.",
				"fx": {
					"cash": -35,
					"burnout": -1
				}
			},
			{
				"id": "skip",
				"label": "SKIP IT",
				"text": "There is always the next one.",
				"fx": {}
			}
		]
	},
	"client_text_night": {
		"id": "client_text_night",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 1.0,
		"cooldown": 10,
		"requires": [],
		"speaker": "A client",
		"text": "I know it is 9 PM, but I just got an email from the bank that I can not open and it says it is urgent. I am very sorry to text you now.",
		"options": [
			{
				"id": "answer",
				"label": "ANSWER AND CHECK IT TOGETHER",
				"text": "It was a phishing email. She is grateful, and you are tired.",
				"fx": {
					"mood_all": 1,
					"burnout": 3
				}
			},
			{
				"id": "morning",
				"label": "REPLY THAT YOU WILL LOOK AT IT FIRST THING",
				"text": "She spends the night worrying, but she is fine.",
				"fx": {
					"burnout": -1
				}
			},
			{
				"id": "oncall",
				"label": "FORWARD IT TO WHOEVER IS ON CALL",
				"text": "A team effort, and a small win for the rota.",
				"fx": {
					"burnout": 1
				}
			}
		]
	},
	"landlord_notice": {
		"id": "landlord_notice",
		"kinds": [
			"owner"
		],
		"min_day": 3,
		"max_day": 20,
		"weight": 0.8,
		"cooldown": 16,
		"requires": [],
		"speaker": "The landlord",
		"text": "A notice that the rent goes up 4 percent in the autumn. There is also a note about the parking lot being repaved on Thursday.",
		"options": [
			{
				"id": "accept",
				"label": "ACCEPT THE INCREASE",
				"text": "It is a small amount, and the lot looks good afterward.",
				"fx": {
					"cash": -40
				}
			},
			{
				"id": "negotiate",
				"label": "ASK FOR A TWO-YEAR LEASE AT THE OLD RATE",
				"text": "He says he will think about it. He does.",
				"fx": {
					"cash": 40,
					"burnout": 1
				}
			},
			{
				"id": "move",
				"label": "START LOOKING AT OTHER OFFICES",
				"text": "You see three offices and one of them has a creaky floor.",
				"fx": {
					"burnout": 2
				}
			}
		]
	}
}
var DECK: Dictionary = DEFAULT_DECK.duplicate(true)

var draws := 0  # how many mornings have drawn (saved; the `events` stream is replayed to this point)
var last: Dictionary = {}  # card id -> the day it was last drawn
var recent: Array = []  # the last ids drawn, newest last
var pending: Dictionary = {}  # today's draw: {deck, id, at, who}
var last_shown := ""  # the id of the card most recently shown (tests)
var shown := 0

var _ok_cache := {}


func reset() -> void:
	draws = 0
	last = {}
	recent = []
	pending = {}
	last_shown = ""
	shown = 0


# ---- saving ---------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"version": VERSION, "draws": draws, "last": last.duplicate(), "recent": recent.duplicate()}


# an old save has no `events` section: everything starts empty. The stream restarts from the run seed
# on a continue of an old save, so it is replayed to where it was (each draw uses exactly ROLLS numbers);
# saves written since R10a carry every stream position (Difficulty.to_dict) and need no replay.
const ROLLS := 5


func from_dict(data: Dictionary) -> void:
	reset()
	draws = int(data.get("draws", 0))
	var saved_last: Variant = data.get("last", {})
	if saved_last is Dictionary:
		for id in saved_last:
			last[str(id)] = int(saved_last[id])
	var saved_recent: Variant = data.get("recent", [])
	if saved_recent is Array:
		for id in saved_recent:
			recent.append(str(id))
	var r := Difficulty.rng("events")
	if not Difficulty.resumed("events"):  # a save with stream positions is already in place
		for i in draws * ROLLS:
			r.randf()


# ---- the people a card may name ---------------------------------------------------------------------
# the coworkers (not the owners, not the manager) who exist in the current campaign
func roster() -> Array:
	var out := []
	for who in World.CAST:
		if OWNERS.has(who):
			continue
		if who == "Maya" and not bool(Campaign.prop("maya_in_events", true)):
			continue  # she is not on the owner's payroll
		out.append(str(who))
	return out


func _names_allowed(kinds: Array) -> Array:
	var allowed := []
	for n in ALL_NAMES:
		var ok := true
		for kind in ["tech", "owner"]:
			if (kinds.has("both") or kinds.has(kind)) and not NAMES_FOR[kind].has(n):
				ok = false
		if ok:
			allowed.append(n)
	return allowed


# ---- the balance guard ------------------------------------------------------------------------------
# problems with an fx dictionary (empty = fine); `kinds` is the card's kinds
func fx_problems(fx: Dictionary, kinds: Array) -> Array:
	var out := []
	var names := _names_allowed(kinds)
	for key in fx:
		var k := str(key)
		if not FX_KEYS.has(k):
			out.append("unknown fx key %s" % k)
			continue
		if OWNER_ONLY.has(k) and not kinds.has("owner"):
			out.append("%s only belongs on an owner card" % k)
		if TECH_ONLY.has(k) and kinds == ["owner"]:
			out.append("%s does not belong on an owner card" % k)
		var limit := float(FX_BOUNDS[k])
		var v: Variant = fx[key]
		match k:
			"xp":
				if not (v is Array) or v.size() != 2 or not SKILLS.has(str(v[0])):
					out.append("xp needs [skill, n]")
				elif int(v[1]) < 1 or int(v[1]) > int(limit):
					out.append("xp %d is out of bounds" % int(v[1]))
			"mood":
				if not (v is Array) or v.size() != 2 or int(v[0]) < 0 or int(v[0]) > 4:
					out.append("mood needs [client 0-4, n]")
				elif absf(float(v[1])) > limit:
					out.append("mood %d is out of bounds" % int(v[1]))
			"social":
				if not (v is Dictionary):
					out.append("social needs a dictionary")
				else:
					for who in v:
						if absf(float(v[who])) > limit:
							out.append("social %s is out of bounds" % str(who))
						if str(who) != "{c}" and not names.has(str(who)):
							out.append("social names %s who is not in this campaign" % str(who))
			"hours":
				if float(v) < 0.0 or float(v) > limit:
					out.append("hours %s is out of bounds" % str(v))
			_:
				if absf(float(v)) > limit:
					out.append("%s %s is out of bounds" % [k, str(v)])
	return out


# true when no effect in the fx hurts much: a card must always offer a way out that costs (almost) nothing
func is_safe_fx(fx: Dictionary) -> bool:
	if int(fx.get("rep", 0)) < 0 or float(fx.get("energy", 0)) < 0.0:
		return false
	if int(fx.get("mood_all", 0)) < 0 or int(fx.get("cash", 0)) < -100:
		return false
	if fx.has("mood") and int(fx.mood[1]) < 0:
		return false
	if float(fx.get("burnout", 0)) > 2.0:
		return false
	for who in fx.get("social", {}):
		if int(fx.social[who]) < 0:
			return false
	return true


func _text_problems(text: String, kinds: Array) -> Array:
	var out := []
	var allowed := _names_allowed(kinds)
	for n in ALL_NAMES:
		if text.contains(n) and not allowed.has(n):
			out.append("names %s who is not in this campaign" % n)
	return out


# every problem with one deck card (empty = fine)
func violations(card: Dictionary) -> Array:
	var out := []
	var id := str(card.get("id", ""))
	if id == "":
		out.append("no id")
	var kinds: Array = card.get("kinds", [])
	if kinds.is_empty():
		out.append("%s: no kinds" % id)
	for kind in kinds:
		if not KINDS.has(str(kind)):
			out.append("%s: bad kind %s" % [id, str(kind)])
	if kinds.has("both") and kinds.size() > 1:
		out.append("%s: both must stand alone" % id)
	var lo := int(card.get("min_day", 0))
	var hi := int(card.get("max_day", 0))
	if lo < 1 or hi > Campaign.TOTAL_DAYS or lo > hi:
		out.append("%s: bad days %d-%d" % [id, lo, hi])
	var weight := float(card.get("weight", 0.0))
	if weight <= 0.0 or weight > 3.0:
		out.append("%s: weight %s" % [id, str(weight)])
	if int(card.get("cooldown", -1)) < 0 or int(card.get("cooldown", 0)) > 99:
		out.append("%s: cooldown" % id)
	if not (card.get("requires", []) is Array):
		out.append("%s: requires must be a list" % id)
	if str(card.get("speaker", "")) == "" or str(card.get("text", "")) == "":
		out.append("%s: no speaker or text" % id)
	if str(card.get("text", "")).length() > MAX_TEXT:
		out.append("%s: text too long" % id)
	out.append_array(_text_problems(str(card.get("speaker", "")) + " " + str(card.get("text", "")), kinds))
	var options: Array = card.get("options", [])
	if options.size() < 2 or options.size() > MAX_OPTIONS:
		out.append("%s: needs 2-%d options" % [id, MAX_OPTIONS])
	var ids := {}
	var safe := false
	for o in options:
		var oid := str(o.get("id", ""))
		if oid == "" or ids.has(oid):
			out.append("%s: option id %s" % [id, oid])
		ids[oid] = true
		if str(o.get("label", "")) == "" or str(o.get("label", "")).length() > MAX_LABEL:
			out.append("%s/%s: label" % [id, oid])
		if str(o.get("text", "")) == "":
			out.append("%s/%s: no result text" % [id, oid])
		out.append_array(_text_problems(str(o.get("label", "")) + " " + str(o.get("text", "")), kinds))
		var fx: Dictionary = o.get("fx", {})
		for p in fx_problems(fx, kinds):
			out.append("%s/%s: %s" % [id, oid, p])
		if is_safe_fx(fx):
			safe = true
	if not safe:
		out.append("%s: no option is safe" % id)
	return out


# the same checks for a Story vignette that is drawn from the deck
func vignette_violations(id: String, v: Dictionary) -> Array:
	var card := v.duplicate(true)
	card["id"] = id
	card["kinds"] = ["tech"]
	card["weight"] = float(v.get("weight", 1.0))
	card["cooldown"] = 99
	card["max_day"] = int(v.get("max_day", Campaign.TOTAL_DAYS))
	card["requires"] = []
	return violations(card)


# problems with the whole deck and the drawn vignettes
func validate_all() -> Array:
	var out := []
	for id in DECK:
		var card: Dictionary = DECK[id]
		if str(card.get("id", "")) != str(id):
			out.append("%s: the key and id differ" % str(id))
		out.append_array(violations(card))
	for id in Story.VIGNETTES:
		if Story.VIGNETTES[id].has("min_day"):
			out.append_array(vignette_violations(str(id), Story.VIGNETTES[id]))
	return out


func _valid(id: String, card: Dictionary, vignette: bool) -> bool:
	var key := ("v:" if vignette else "e:") + id
	if not _ok_cache.has(key):
		var problems := vignette_violations(id, card) if vignette else violations(card)
		_ok_cache[key] = problems.is_empty()
	return bool(_ok_cache[key])


# ---- which days draw ----------------------------------------------------------------------------------
# a quiet day: no story card, no outing, no trip, not the first days or the last
func quiet_day(day: int, mode: String) -> bool:
	if mode == "service":
		return ServiceArc.quiet(day)  # C7: the deck draws on the service desk's quiet days
	if day < (3 if mode == "tech" else 2) or day >= Campaign.TOTAL_DAYS:
		return false
	if mode == "tech":
		if Outings.TECH_DAYS.has(day) or Expo.is_trip_day(day):
			return false
		for ev in Story.events_on(day):
			if BUSY_KINDS.has(str(ev.get("kind", ""))):
				return false
			if str(ev.get("kind", "")) == "playbook" and str(ev.get("book", "")) == "email24":
				return false  # the overtime night
		return true
	if mode == "owner":
		if Outings.OWNER_WEEKS.has(day):
			return false
		var events: Array = Owner.events_on(day)
		if events.size() > 3:
			return false
		for ev in events:
			if str(ev.get("event", "")) == "ransomware" or str(ev.get("card", "")) == "email24":
				return false
		return true
	return false


func _requires_ok(card: Dictionary) -> bool:
	for token in card.get("requires", []):
		var parts := str(token).split(":")
		match parts[0]:
			"client":
				if not Sales.active.has(int(parts[1])):
					return false
			"cash":
				if Campaign.mode != "owner" or Owner.cash < int(parts[1]):
					return false
	var shown_text := str(card.get("speaker", "")) + str(card.get("text", ""))
	return not (shown_text.contains("{c}") and roster().is_empty())


func _cooled(id: String, cooldown: int, day: int) -> bool:
	return last.has(id) and day - int(last[id]) < cooldown


# every card that may be drawn today: [{deck, id, weight}]
func pool(day: int, mode: String) -> Array:
	var out := []
	for id in DECK:
		var card: Dictionary = DECK[id]
		var kinds: Array = card.get("kinds", [])
		if not (kinds.has("tech" if mode == "service" else mode) or kinds.has("both")):
			continue
		if day < int(card.min_day) or day > int(card.max_day):
			continue
		if _cooled(str(id), int(card.cooldown), day) or not _requires_ok(card):
			continue
		if _valid(str(id), card, false):
			out.append({"deck": "event", "id": str(id), "weight": float(card.weight) * Mutators.boost(str(id))})
	if mode == "tech":
		for id in Story.VIGNETTES:
			var v: Dictionary = Story.VIGNETTES[id]
			if not v.has("min_day") or day < int(v.min_day) or day > int(v.get("max_day", 99)):
				continue
			if last.has(str(id)):
				continue  # a vignette is shown once a run
			if _valid(str(id), v, true):
				out.append({"deck": "vignette", "id": str(id), "weight": float(v.get("weight", 1.0))})
	return out


# ---- the morning draw -----------------------------------------------------------------------------------
# Called from Campaign._begin_day. Every draw uses exactly ROLLS numbers from the `events` stream,
# so a fixed seed repeats and a continued run can replay the stream.
func begin_day(day: int) -> void:
	pending = {}
	if not Campaign.active or Game.title_mode or not quiet_day(day, Campaign.mode):
		return
	draws += 1
	var r := Difficulty.rng("events")
	var pick_roll := r.randf()
	var at_roll := r.randf()
	var who_roll := r.randf()
	r.randf()
	r.randf()
	var cards := pool(day, Campaign.mode)
	if cards.is_empty():
		return
	var total := 0.0
	for c in cards:
		total += float(c.weight)
	var target := pick_roll * total
	var chosen: Dictionary = cards[cards.size() - 1]
	for c in cards:
		target -= float(c.weight)
		if target < 0.0:
			chosen = c
			break
	var people := roster()
	pending = {
		"deck": chosen.deck,
		"id": chosen.id,
		"at": snappedf(WINDOW_START + WINDOW_LEN * at_roll, 0.1),
		"who": "" if people.is_empty() else str(people[int(who_roll * people.size()) % people.size()]),
	}
	last[str(chosen.id)] = day
	recent.append(str(chosen.id))
	while recent.size() > 12:
		recent.pop_front()


func _process(_delta: float) -> void:
	if pending.is_empty() or not Campaign.active or Game.title_mode:
		return
	if World.clock >= LATEST:
		pending = {}
		return
	if World.clock < float(pending.at) or World.time_scale <= 0.0 or Cards.is_open:
		return
	if Expo.away or Onsite.busy or Outings.busy() or DayReport.is_open:
		return
	var draw := pending
	pending = {}
	show_draw(draw)


# ---- showing a card ---------------------------------------------------------------------------------------
func show_draw(draw: Dictionary) -> void:
	last_shown = str(draw.id)
	shown += 1
	ServiceArc.on_event(str(draw.id))  # C7: a systems change makes the Service runbooks stale
	if str(draw.deck) == "vignette":
		Story.fire({"kind": "vignette", "id": str(draw.id)})
		return
	var card: Dictionary = DECK.get(str(draw.id), {})
	if card.is_empty():
		return
	var c := resolve(card, str(draw.get("who", "")))
	var options := []
	for o in c.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(str(c.speaker), str(c.text), options, func(pick: String) -> void: _answer(c, pick))


# a copy of the card with {c} replaced by a coworker's name
func resolve(card: Dictionary, who: String) -> Dictionary:
	var c := card.duplicate(true)
	var nm := who if who != "" else "A coworker"
	c["speaker"] = str(c.speaker).replace("{c}", nm)
	c["text"] = str(c.text).replace("{c}", nm)
	for o in c.options:
		o["label"] = str(o.label).replace("{c}", nm)
		o["text"] = str(o.text).replace("{c}", nm)
		if o.get("fx", {}).has("social"):
			var swapped := {}
			for k in o.fx.social:
				swapped[str(k).replace("{c}", who)] = o.fx.social[k]
			o.fx["social"] = swapped
	return c


func _answer(c: Dictionary, pick: String) -> void:
	var text := ""
	for o in c.options:
		if str(o.id) == pick:
			text = str(o.text)
			apply_fx(o.get("fx", {}))
	Cards.ask(str(c.speaker), text, OPTIONS_OK, func(_id: String) -> void: pass)


# the vignette resolver does the work; cash and burnout go to the owner books, and an owner has no XP or
# energy to gain
func apply_fx(fx: Dictionary) -> void:
	var rest := fx.duplicate(true)
	var books := {}
	for key in OWNER_ONLY:
		if rest.has(key):
			books[key] = rest[key]
			rest.erase(key)
	if Campaign.mode == "owner":
		for key in TECH_ONLY:
			rest.erase(key)
		if not books.is_empty():
			Owner.apply(books)
	if rest.has("hours") and World.clock + float(rest.hours) > World.DAY_END - 1.5:
		rest.erase("hours")  # never push the day into its last hour
	Story._vignette_fx(rest)
