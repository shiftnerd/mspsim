extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,max-returns
# The service manager campaign (C4 / V1, mode "service"): you are Dan, promoted to run the desk. The crew (Crew) works the
# queue by itself through the crew gate (Owner.team_speed / _work_queue); you set a focus in the MORNING HUDDLE, talk to your
# people in 1:1s, answer the owners' MEMOS (Alan wants quality and the stack, Garrison wants yes to the client and a happy
# team; each choice moves the two trust meters and has a real effect), decide who takes the big incidents (the Playbook jobs,
# played by you or run by the crew) and read the SCORECARD at the end of the day. Morgan's confidence is Campaign.rep (fired at
# 0, or when both owners' trust is under 20). Hands-on still works: your desk's PSA / RMM are the normal computer apps.
# V1 uses Cards and the PSA ticket list; the Dispatch board, Capacity view, runbooks and hiring are C5 / C6.

const Dash := preload("res://scripts/dash.gd")  # the metrics record (R20): hours worked per tech per day
const ByName := preload("res://scripts/byname.gd")  # R36: clients who ask for one tech by name
const START_CONFIDENCE := 55
const OWNERS := ["Alan", "Garrison"]
const TRUST_START := 50
const FAIL_TRUST := 20
const FOCUS := {
	"p1": {"speed": 0.95, "head": 0.7, "miss": 0.0},
	"queue": {"speed": 1.12, "head": 1.0, "miss": 0.05},
	"mentor": {"speed": 0.92, "head": 1.0, "miss": 0.0},
	"project": {"speed": 0.85, "head": 1.0, "miss": 0.0},
}
const FOCUS_ORDER := ["p1", "queue", "mentor", "project"]
const RANK := {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1}

const DEFAULT_HUDDLE := {
	"speaker": "Morning huddle",
	"text": "Morning. %d tickets open, %d of them P1 or P2. Crew mood is %s. What is today's focus?",
	"options": {
		"p1": {"label": "P1 FIRST", "note": "P1 and P2 tickets get a head start. The rest wait a little longer."},
		"queue": {"label": "CLEAR THE QUEUE", "note": "Everyone works faster today. A few more will come back."},
		"mentor": {"label": "MENTOR MAYA", "note": "You sit with Maya today. The queue slows down, she gets better."},
		"project": {"label": "PROJECT DAY", "note": "Documentation and cleanup. Slower today, fewer tickets later."},
	},
	"moods": {"good": "good", "ok": "so-so", "low": "low"},
}
var HUDDLE: Dictionary = DEFAULT_HUDDLE.duplicate(true)

# owner memos: both owners pull in opposite directions. Option a is the sender's ask, b is the other owner's reply, c does both.
const DEFAULT_MEMOS := {
	"m1":
	{
		"day": 2, "at": 10.0, "speaker": "Alan (Co-owner)",
		"text": "Memo: patch every workstation and the switch firmware this week. Quality first. Garrison replied-all: Dr. Patel's Wi-Fi has to work before his lunch.",
		"options":
		[
			{"id": "a", "label": "PATCH FIRST", "text": "I will put the patch run on the board. Dr. Patel waits for the window.", "fx": {"trust": {"Alan": 6, "Garrison": -5}, "buff": ["issues", 0.93, 4], "mood": -2}},
			{"id": "b", "label": "DR. PATEL FIRST", "text": "Understood. Patel's Wi-Fi first. The patches move to next week.", "fx": {"trust": {"Alan": -5, "Garrison": 6}, "mood": 4}},
			{"id": "c", "label": "BOTH, EXTRA HOURS", "text": "Both are on the board. It costs the crew an evening.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "morale": -4, "mood": 2, "buff": ["issues", 0.96, 3]}},
		],
	},
	"m2":
	{
		"day": 5, "at": 10.0, "speaker": "Garrison (Co-owner)",
		"text": "Memo: a prospect wants onboarding in a day. Say yes, we need the win. Alan replied: survey the network first, or it goes badly.",
		"options":
		[
			{"id": "a", "label": "SAY YES TO ONE DAY", "text": "One day it is. I will tell the crew it is a sprint.", "fx": {"trust": {"Alan": -4, "Garrison": 6}, "mood": 5, "morale": -3}},
			{"id": "b", "label": "SURVEY FIRST", "text": "Three days with a survey. I wrote down why.", "fx": {"trust": {"Alan": 6, "Garrison": -5}, "buff": ["miss", -0.02, 4]}},
			{"id": "c", "label": "A DAY, THEN A SURVEY", "text": "We start in a day and survey as we go. Tight, but written down.", "fx": {"trust": {"Alan": 1, "Garrison": 2}, "morale": -2, "mood": 2}},
		],
	},
	"m3":
	{
		"day": 8, "at": 10.0, "speaker": "Alan (Co-owner)",
		"text": "Memo: tier the desk. Seniors on hard tickets, juniors on resets, no exceptions. Garrison replied: account pods, so each client sees the same faces.",
		"options":
		[
			{"id": "a", "label": "TIER THE DESK", "text": "Tiers it is. I will label the queues.", "fx": {"trust": {"Alan": 6, "Garrison": -4}, "buff": ["speed", 1.06, 5]}},
			{"id": "b", "label": "ACCOUNT PODS", "text": "Pods. Each client gets a name on the ticket.", "fx": {"trust": {"Alan": -4, "Garrison": 6}, "mood": 4, "morale": 3}},
			{"id": "c", "label": "TIERS FOR THE TOP 3", "text": "Tiers for the big three clients and pods for the rest. More work for me.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "buff": ["speed", 1.03, 5], "mood": 1}},
		],
	},
	"m4":
	{
		"day": 11, "at": 9.8, "speaker": "Garrison (Co-owner)",
		"text": "Memo: the crew has earned a long Friday. Pizza at three and everyone leaves early. Alan replied: documentation week, nothing is written down.",
		"options":
		[
			{"id": "a", "label": "PIZZA AND AN EARLY FRIDAY", "text": "Friday at three. I will cover the phones.", "fx": {"trust": {"Alan": -4, "Garrison": 6}, "morale": 8, "retain_all": 1}},
			{"id": "b", "label": "DOCUMENTATION WEEK", "text": "Documentation week. I will schedule the hours.", "fx": {"trust": {"Alan": 6, "Garrison": -4}, "buff": ["issues", 0.94, 5], "morale": -2}},
			{"id": "c", "label": "PIZZA AT LUNCH, THEN DOCS", "text": "Pizza at noon, documents in the afternoon. Nobody leaves early.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "morale": 3, "buff": ["issues", 0.97, 3]}},
		],
	},
	"m5":
	{
		"day": 14, "at": 10.0, "speaker": "Alan (Co-owner)",
		"text": "Memo: set an after-hours rota, one tech a week, fixed. Garrison replied: pay a bonus and let people volunteer.",
		"options":
		[
			{"id": "a", "label": "A FIXED ROTA", "text": "A rota, posted in the kitchen. Fair and predictable.", "fx": {"trust": {"Alan": 5, "Garrison": -3}, "morale": -3, "buff": ["miss", -0.015, 5]}},
			{"id": "b", "label": "BONUS FOR VOLUNTEERS", "text": "A bonus for volunteers. Maya says she will take the first week.", "fx": {"trust": {"Alan": -3, "Garrison": 5}, "morale": 4}},
			{"id": "c", "label": "ROTA PLUS A SMALL BONUS", "text": "A rota with a small bonus. Both of you get half of what you asked for.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "morale": 1}},
		],
	},
	"m6":
	{
		"day": 17, "at": 10.0, "speaker": "Garrison (Co-owner)",
		"text": "Memo: Iron Mule wants unlimited changes for the same fee. Say yes and keep them happy. Alan replied: enforce the contract or it never ends.",
		"options":
		[
			{"id": "a", "label": "SAY YES TO THEM", "text": "I told Iron Mule yes. I will watch the hours they take.", "fx": {"trust": {"Alan": -4, "Garrison": 6}, "mood": 6, "buff": ["issues", 1.08, 5]}},
			{"id": "b", "label": "ENFORCE THE CONTRACT", "text": "I sent them the scope section, politely. It is written down now.", "fx": {"trust": {"Alan": 6, "Garrison": -5}, "mood": -4, "buff": ["issues", 0.95, 5]}},
			{"id": "c", "label": "A CHANGE ORDER", "text": "A change order for the extras. They can say yes or no.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "mood": 1}},
		],
	},
}
var MEMOS: Dictionary = DEFAULT_MEMOS.duplicate(true)

# one-off story cards of the 20 days (the incidents are INCIDENTS)
const DEFAULT_BEATS := {
	"handover":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "Alan and Garrison have asked me to give you the desk. Dan, you run the process now. Alan wants quality. Garrison wants speed. What comes first?",
		"options":
		[
			{"id": "q", "label": "QUALITY FIRST", "text": "Quality first. I will label every queue and write the rules down.", "fx": {"trust": {"Alan": 5, "Garrison": -2}, "buff": ["miss", -0.02, 5]}},
			{"id": "s", "label": "SPEED FIRST", "text": "Speed first. Fast answers, then we tidy up.", "fx": {"trust": {"Alan": -2, "Garrison": 5}, "buff": ["speed", 1.05, 5]}},
			{"id": "b", "label": "BOTH, SLOWLY", "text": "Both. I will start with the queue. It will take a week.", "fx": {"trust": {"Alan": 2, "Garrison": 2}}},
		],
	},
	"xp":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "Windows XP stops getting patches on April 8. Every XP box is a liability and the clients keep asking. How do we run the migrations?",
		"options":
		[
			{"id": "d", "label": "DURING THE DAY", "text": "Daytime migrations. The queue will feel it.", "fx": {"buff": ["speed", 0.94, 3], "mood": 3}},
			{"id": "n", "label": "AFTER HOURS, BATCHED", "text": "Batches after hours, with a note to each client. The crew gets time back.", "fx": {"morale": -3, "trust": {"Alan": 3, "Garrison": 0}, "buff": ["issues", 0.97, 4]}},
			{"id": "m", "label": "GIVE THEM TO MAYA", "text": "Maya takes the XP list. I will check her notes at the end of the day.", "fx": {"morale_who": {"Maya": 5}, "mentor": "Maya"}},
		],
	},
	"vic":
	{
		"speaker": "John (Account Manager)",
		"text": "I promised Brightside a two hour response on everything. They loved it. Your crew can do that, right?",
		"options":
		[
			{"id": "h", "label": "HOLD JOHN TO IT", "text": "We can do it if the P3s wait. I wrote the exceptions on the board.", "fx": {"social": {"John": 2}, "trust": {"Alan": 0, "Garrison": 3}, "morale": -2}},
			{"id": "r", "label": "RE-QUOTE IT WITH JOHN", "text": "Four hours, with two hours for urgent. John will call them. He did not enjoy it.", "fx": {"social": {"John": -2}, "trust": {"Alan": 3, "Garrison": -2}}},
			{"id": "t", "label": "ASK GARRISON", "text": "Garrison says to do it and we sort the staffing later. I am not sure that is a plan.", "fx": {"trust": {"Alan": -2, "Garrison": 4}, "morale": -3, "mood": 3}},
		],
	},
	"nosale":
	{
		"speaker": "John (Account Manager)",
		"text": "A new prospect wants fifty seats at half our price, with a four-hour response. Garrison likes the logo. The numbers look thin to me. Do we take them?",
		"options":
		[
			{"id": "y", "label": "TAKE THEM", "text": "We take them. I will plan the capacity before they start.", "fx": {"trust": {"Alan": -3, "Garrison": 5}, "morale": -3, "buff": ["issues", 1.06, 4]}},
			{"id": "n", "label": "SAY NO, POLITELY", "text": "No. I wrote down why: price, scope and response time do not fit. John will say it nicely.", "fx": {"trust": {"Alan": 5, "Garrison": -4}, "social": {"John": -1}}},
			{"id": "c", "label": "COUNTER-OFFER", "text": "Counter-offer: full price, a longer response time, a signed scope. They may walk.", "fx": {"trust": {"Alan": 2, "Garrison": 1}}},
		],
	},
	"grow":
	{
		"speaker": "Maya (Tier 1)",
		"text": "Dan, can I talk to you? I think I am ready to take the harder tickets. Tier 2. Would you coach me?",
		"options":
		[
			{"id": "y", "label": "YES, I WILL COACH YOU", "text": "Yes. We start tomorrow: you take the next server ticket and I watch. I will write the checklist.", "fx": {"graduate": "Maya", "trust": {"Alan": 3, "Garrison": 2}}, "needs_mentored": 2},
			{"id": "l", "label": "NOT YET, HERE IS WHY", "text": "Not yet. Here are three skills to work on. Ask me again in a month.", "fx": {"morale_who": {"Maya": -4}, "retain": {"Maya": 0}}},
			{"id": "w", "label": "I WILL SPEAK TO MORGAN", "text": "I will talk to Morgan about the budget. I will tell you what she says on Monday.", "fx": {"morale_who": {"Maya": 1}}},
		],
	},
	"audit":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "Summit Managed Holdings is looking at us. They want to audit the desk, and Alan and Garrison disagree about selling. What do you tell the owners about the numbers?",
		"options":
		[
			{"id": "t", "label": "THE NUMBERS, AS THEY ARE", "text": "I gave both of them the same sheet. Nothing rounded.", "fx": {"audit": 0}},
			{"id": "a", "label": "ALAN: A CLEAN, DOCUMENTED DESK", "text": "I told Alan the desk is documented and the process is ready for an audit.", "fx": {"trust": {"Alan": 5, "Garrison": -3}}},
			{"id": "g", "label": "GARRISON: HAPPY CLIENTS", "text": "I told Garrison our clients are happy and the team stays. That is what a buyer pays for.", "fx": {"trust": {"Alan": -3, "Garrison": 5}}},
		],
	},
	"friday":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "Friday numbers. Your confidence rating with me is %d and the week averaged a %s. Anything you need from me?",
		"options":
		[
			{"id": "t", "label": "ANOTHER TECH, PLEASE", "text": "I asked for another tech. Morgan will bring it to the owners. I attached the utilisation numbers.", "fx": {"flag": "headcount", "trust": {"Alan": 1, "Garrison": -1}}},
			{"id": "f", "label": "I WILL FIX THE NUMBERS", "text": "I will fix the numbers. Monday you will see the changes on the board.", "fx": {"conf": 1}},
			{"id": "n", "label": "NOTHING TO ADD", "text": "Nothing to add. Everything is written down.", "fx": {}},
		],
	},
}
var BEATS: Dictionary = DEFAULT_BEATS.duplicate(true)

# the big incidents: you take the Playbook job yourself, send Maya, or ask the owner whose area it is
const DEFAULT_INCIDENTS := {
	"rdp": {"speaker": "Alan (Co-owner)", "text": "Brightside's server is crawling and the log shows logins we do not know. Who takes it?", "owner": "Alan", "title": "RDP BREAK-IN"},
	"ransom": {"speaker": "Garrison (Co-owner)", "text": "Hoot and Holler has a ransom note on their server. Their partners are calling me. Who takes it?", "owner": "Alan", "title": "THE RANSOMWARE"},
	"rack": {"speaker": "Morgan Reyes (Manager)", "text": "The network rack at Gnarly Gnomes came off the wall. Three tickets, everything down. Who takes it?", "owner": "Alan", "title": "THE FALLEN RACK"},
	"email24": {"speaker": "Garrison (Co-owner)", "text": "Soggy Bottom Brewing runs around the clock and their email is down. This may run into the night. Who takes it?", "owner": "Alan", "title": "THE EMAIL NIGHT"},
	"migration": {"speaker": "Alan (Co-owner)", "text": "Brightside's old server is out of support. Today is the cutover. It has to be careful. Who takes it?", "owner": "Alan", "title": "THE SERVER MIGRATION"},
	"onboard": {"speaker": "Garrison (Co-owner)", "text": "Iron Mule Demolition signs today and they have no documentation. Who takes the onboarding?", "owner": "Garrison", "title": "IRON MULE ONBOARDING"},
}
var INCIDENTS: Dictionary = DEFAULT_INCIDENTS.duplicate(true)
const DEFAULT_INCIDENT_OPTIONS := {
	"take": "I TAKE IT MYSELF",
	"send": "SEND MAYA",
	"ask": "ASK THE OWNER",
	"took": "I am on it. The board is Maya's until I am back.",
	"sent": "Maya has it, with the checklist. I will review the result.",
	"asked": "I asked the owner to step in. It cost them an afternoon.",
}
var INCIDENT_OPTIONS: Dictionary = DEFAULT_INCIDENT_OPTIONS.duplicate(true)

# 1:1 cards. Decks: Maya, Tech ({name} is Sam or Terry), John. Each option: label, reply, fx (morale / retain / social / trust).
const DEFAULT_ONE_ON_ONES := {
	"Maya":
	[
		{
			"text": "I closed eleven tickets yesterday and nobody said anything. Is that good?",
			"options":
			[
				{"label": "TELL HER EXACTLY WHAT WAS GOOD", "reply": "Eleven is good. The Acme spooler notes were the best. I mean it.", "fx": {"morale": 6, "retain": 1}},
				{"label": "SAY THANKS", "reply": "Thanks. Keep going.", "fx": {"morale": 2}},
				{"label": "ASK ABOUT THE REOPENS", "reply": "Two came back. Let's look at those together.", "fx": {"morale": -2, "skill": 0.02}},
			],
		},
		{
			"text": "I do not like calling clients when I do not know the answer. It makes me freeze.",
			"options":
			[
				{"label": "GIVE HER A SCRIPT", "reply": "Here is a card: say what you know, say what you will check, say when you will call back. I wrote it.", "fx": {"morale": 4, "retain": 1, "skill": 0.02}},
				{"label": "SIT IN ON THE NEXT CALL", "reply": "I will sit next to you on the next one. You talk. I stay quiet.", "fx": {"morale": 5, "stress": -4}},
				{"label": "TELL HER TO PUSH THROUGH", "reply": "It gets easier. Just do it.", "fx": {"morale": -4}},
			],
		},
		{
			"text": "Sam gets the easy tickets and I get the weird ones. Is that on purpose?",
			"options":
			[
				{"label": "EXPLAIN THE TIERS", "reply": "Yes. You are ready for the harder ones. It is not a punishment. I should have said so.", "fx": {"morale": 5, "retain": 1}},
				{"label": "SWAP FOR A WEEK", "reply": "We swap for a week and compare the times. I will keep a table.", "fx": {"morale": 3, "speed": -0.02}},
				{"label": "SAY IT IS HOW IT IS", "reply": "It is how the queue falls.", "fx": {"morale": -5}},
			],
		},
		{
			"text": "My cousin works at the bank across the street. They are hiring a tech. I am not leaving. I just wanted you to know.",
			"options":
			[
				{"label": "ASK WHAT WOULD MAKE HER STAY", "reply": "Thank you for telling me. What would make this a better job? I will write it down.", "fx": {"morale": 4, "retain": 3}},
				{"label": "PROMISE A RAISE REVIEW", "reply": "I will take it to Morgan this month. I will not promise a number.", "fx": {"morale": 3, "retain": 2, "trust": {"Garrison": -1}}},
				{"label": "WISH HER LUCK", "reply": "Okay. Good luck either way.", "fx": {"morale": -3, "retain": -2}},
			],
		},
		{
			"text": "The front desk at Acme asked for me by name today. Is that allowed?",
			"options":
			[
				{"label": "PUT HER NAME ON THE ACCOUNT", "reply": "It is allowed. I put your name on the Acme page as first contact. In ink.", "fx": {"morale": 5, "retain": 1, "mood": 1}},
				{"label": "SAY IT IS A GOOD SIGN", "reply": "It is a good sign. Keep doing what you did.", "fx": {"morale": 3}},
				{"label": "REMIND HER THE QUEUE DECIDES", "reply": "The queue decides who gets what. Not the client.", "fx": {"morale": -3}},
			],
		},
		{
			"text": "I stayed until seven twice this week. Nobody asked me to. I just did not want to leave them open.",
			"options":
			[
				{"label": "SEND HER HOME ON TIME", "reply": "At five you write a handover note and you go. I read it. The ticket will still be there, and so will you.", "fx": {"morale": 4, "retain": 1, "stress": -5}},
				{"label": "THANK HER AND LOG THE HOURS", "reply": "Thank you. I logged both evenings. Take Friday afternoon.", "fx": {"morale": 3, "stress": -2}},
				{"label": "SAY THAT IS THE JOB", "reply": "Some weeks are like that.", "fx": {"morale": -3, "stress": 4}},
			],
		},
		{
			"text": "I wrote down how I fix the scanner at Brightside. Three steps. Do you want it, or is that silly?",
			"options":
			[
				{"label": "MAKE IT A RUNBOOK WITH HER NAME ON IT", "reply": "Not silly. It goes in the binder with your name on the top line. I will print a label.", "fx": {"morale": 6, "retain": 1, "skill": 0.02}},
				{"label": "ASK HER TO SHOW SAM", "reply": "Show Sam on the next one. If he can follow it, it is good.", "fx": {"morale": 3, "skill": 0.01}},
				{"label": "SAY THE BINDER IS FULL", "reply": "We have enough paper.", "fx": {"morale": -4}},
			],
		},
		{
			"text": "John told a client I would call back in ten minutes. I was on another call. Then the client was angry at me.",
			"options":
			[
				{"label": "TALK TO JOHN TODAY", "reply": "That is mine to fix, not yours. I will talk to John before lunch. Promises go through the board.", "fx": {"morale": 5, "retain": 1, "social": {"John": -1}}},
				{"label": "GIVE HER A LINE TO USE", "reply": "Say: I have your ticket open right now. It is true and it buys a minute.", "fx": {"morale": 3, "skill": 0.01}},
				{"label": "TELL HER TO CALL BACK FASTER", "reply": "Then call back faster.", "fx": {"morale": -5}},
			],
		},
		{
			"text": "Honest question. Am I the phone person because I am good at it, or because I am the only girl?",
			"options":
			[
				{"label": "COUNT THE CALLS, FIX THE ROTA", "reply": "Fair question. I counted. You took six calls in ten last month. That is wrong. New rota on the wall by Monday.", "fx": {"morale": 6, "retain": 2}},
				{"label": "SAY BECAUSE SHE IS GOOD AT IT", "reply": "Because you are the best at it. But I hear you.", "fx": {"morale": 2}},
				{"label": "SAY SOMEBODY HAS TO", "reply": "Somebody has to answer.", "fx": {"morale": -5, "retain": -1}},
			],
		},
		{
			"text": "The granola bars in my drawer keep vanishing. I am not mad. I am keeping a tally.",
			"options":
			[
				{"label": "BUY A BOX FOR THE ROOM", "reply": "I put a box by the printer, labelled CREW. Yours stay yours. I labelled the drawer too.", "fx": {"morale": 4, "retain": 1}},
				{"label": "PROMISE TO ASK AROUND", "reply": "I will ask. Quietly.", "fx": {"morale": 2}},
				{"label": "SAY IT IS ONLY GRANOLA", "reply": "It is a granola bar, Maya.", "fx": {"morale": -2}},
			],
		},
	],
	"Tech":
	[
		{
			"text": "{name} says: I got stuck on a printer yesterday and did not ask. I did not want to bother you.",
			"options":
			[
				{"label": "ASK HIM TO ASK, ALWAYS", "reply": "Asking is part of the job. Five minutes is the rule: stuck for five, ask. I wrote it on the board.", "fx": {"morale": 4, "retain": 1}},
				{"label": "WALK THROUGH THE FIX", "reply": "Let's do it now. I will show you where the queue lives.", "fx": {"morale": 5, "skill": 0.03}},
				{"label": "TELL HIM TO TRY HARDER", "reply": "Try harder.", "fx": {"morale": -4}},
			],
		},
		{
			"text": "{name} says: The phones are loud and I cannot think. I am making mistakes.",
			"options":
			[
				{"label": "SWAP THE PHONE SHIFT", "reply": "I moved you to ticket work until noon. I will take the phones.", "fx": {"morale": 5, "stress": -6}},
				{"label": "A BREAK AND A CHECKLIST", "reply": "Ten minutes away from the desk, then use the checklist. I laminated it.", "fx": {"morale": 3, "stress": -3}},
				{"label": "TELL HIM IT IS BUSY", "reply": "It is busy for everyone.", "fx": {"morale": -3, "stress": 4}},
			],
		},
		{
			"text": "{name} says: I want to learn servers. Is there a path?",
			"options":
			[
				{"label": "MAKE A SHORT PLAN", "reply": "Three steps, one a month, and you shadow me on the next server ticket. I will write it.", "fx": {"morale": 6, "retain": 2, "skill": 0.03}},
				{"label": "POINT TO THE ACADEMY", "reply": "Start with the PowerShell lessons. Ask me after the first one.", "fx": {"morale": 2, "skill": 0.01}},
				{"label": "SAY NOT YET", "reply": "Not yet. First the basics.", "fx": {"morale": -3, "retain": -1}},
			],
		},
		{
			"text": "{name} says: Yesterday a client yelled at me. I am okay. I just wanted to say it.",
			"options":
			[
				{"label": "TAKE THE CLIENT YOURSELF", "reply": "I will call them back. You did nothing wrong. Write down what they said, I will use it.", "fx": {"morale": 6, "retain": 1, "mood": 1}},
				{"label": "ASK WHAT HAPPENED", "reply": "Tell me what happened, in order. We will make a script for next time.", "fx": {"morale": 4, "stress": -3}},
				{"label": "SAY CLIENTS ARE LIKE THAT", "reply": "That happens.", "fx": {"morale": -3}},
			],
		},
		{
			"text": "{name} says: I closed a ticket and it came back the next day. Same printer. I feel stupid.",
			"options":
			[
				{"label": "READ THE TICKET TOGETHER", "reply": "Not stupid. A reopen tells us what the note was missing. Bring it up, we read it together.", "fx": {"morale": 5, "skill": 0.03}},
				{"label": "SAY IT HAPPENS TO EVERYONE", "reply": "Mine come back too. Check the cable first next time.", "fx": {"morale": 3, "skill": 0.01}},
				{"label": "COUNT THE REOPENS OUT LOUD", "reply": "That is the third one this month.", "fx": {"morale": -4, "stress": 3}},
			],
		},
		{
			"text": "{name} says: Maya is faster than me at everything. I do not think I will catch up.",
			"options":
			[
				{"label": "SHOW THE TREND, NOT THE RANK", "reply": "Do not compare with Maya. Compare with you in the first week. Here is the table. You are twice as fast.", "fx": {"morale": 6, "retain": 1}},
				{"label": "PAIR THEM FOR A DAY", "reply": "Sit next to her on Tuesday. Watch what she skips.", "fx": {"morale": 3, "skill": 0.02}},
				{"label": "SAY SOMEBODY IS ALWAYS FASTER", "reply": "Somebody is always faster.", "fx": {"morale": -3}},
			],
		},
		{
			"text": "{name} says: I do not understand half of what Alan says about the servers. I nod anyway.",
			"options":
			[
				{"label": "DRAW IT ON THE WHITEBOARD", "reply": "Stop nodding. Come to the whiteboard, I will draw the rack. Boxes and arrows, nothing else.", "fx": {"morale": 5, "skill": 0.03}},
				{"label": "ASK ALAN TO SLOW DOWN", "reply": "I will ask Alan to use fewer letters. He will grumble. He will do it.", "fx": {"morale": 4, "trust": {"Alan": -1}}},
				{"label": "SAY NODDING IS FINE", "reply": "Keep nodding. It comes with time.", "fx": {"morale": -2}},
			],
		},
		{
			"text": "{name} says: Can I take Friday afternoon? My sister is moving. I know the queue is long.",
			"options":
			[
				{"label": "YES, AND COVER THE QUEUE", "reply": "Go. I take your tickets from one. Leave me notes I can read.", "fx": {"morale": 6, "retain": 2}},
				{"label": "YES, IF THE TICKETS HAVE NOTES", "reply": "Yes, if every open ticket has a note by noon.", "fx": {"morale": 3, "retain": 1}},
				{"label": "SAY NOT THIS WEEK", "reply": "Not this week.", "fx": {"morale": -5, "retain": -1}},
			],
		},
		{
			"text": "{name} says: A client offered me twenty dollars to fix a home computer after hours. I said I would ask.",
			"options":
			[
				{"label": "EXPLAIN THE RULE AND CALL THEM", "reply": "Good that you asked. Home machines go through the shop, with a ticket, so you are covered if it breaks. I will call them.", "fx": {"morale": 4, "retain": 1, "trust": {"Alan": 1}}},
				{"label": "LET IT GO THIS ONCE", "reply": "This once. Tell me how it went.", "fx": {"morale": 3, "trust": {"Alan": -1}}},
				{"label": "SAY ABSOLUTELY NOT", "reply": "No side jobs. Ever.", "fx": {"morale": -3}},
			],
		},
		{
			"text": "{name} says: I broke a mailbox rule at Soggy Bottom. I fixed it before anybody saw. Do I have to say?",
			"options":
			[
				{"label": "WRITE IT UP TOGETHER", "reply": "You just did, and that is the right way round. Two lines in the ticket. Nobody gets shouted at for a note.", "fx": {"morale": 5, "retain": 1, "skill": 0.02}},
				{"label": "SAY TELL ME FIRST NEXT TIME", "reply": "Next time tell me first, then fix. Today it is fine.", "fx": {"morale": 2, "skill": 0.01}},
				{"label": "ASK WHAT ELSE IS BROKEN", "reply": "What else have you not told me?", "fx": {"morale": -5, "stress": 4}},
			],
		},
		{
			"text": "{name} says: I keep forgetting to write the time on tickets. Morgan sent the report back.",
			"options":
			[
				{"label": "PUT A TIMER ON THE DESK", "reply": "Here. A kitchen timer. Start it when you open a ticket. I labelled it.", "fx": {"morale": 4, "skill": 0.02}},
				{"label": "CHECK THE BOARD AT FOUR", "reply": "At four I look at your board and we fill the gaps together. For two weeks.", "fx": {"morale": 3, "stress": -2}},
				{"label": "SAY MORGAN IS RIGHT", "reply": "Morgan is right. Write the time.", "fx": {"morale": -3}},
			],
		},
		{
			"text": "{name} says: Does Garrison pick who goes to the bowling night? Nobody asked me last time.",
			"options":
			[
				{"label": "FIX THE LIST", "reply": "Nobody picks. The list was old. You are on it now. I checked twice.", "fx": {"morale": 5, "retain": 1}},
				{"label": "SAY IT WAS AN ACCIDENT", "reply": "It was an accident. Come next time.", "fx": {"morale": 2}},
				{"label": "SAY IT IS NOT A WORK MATTER", "reply": "That is not a work matter.", "fx": {"morale": -4, "retain": -1}},
			],
		},
		{
			"text": "{name} says: I think I am better on the phones than on the tickets. Is that a bad thing here?",
			"options":
			[
				{"label": "BUILD ON IT", "reply": "It is a good thing. You take first calls for a month and I teach you one ticket type a week.", "fx": {"morale": 5, "retain": 1, "mood": 1}},
				{"label": "SAY WE NEED BOTH", "reply": "We need both. Keep at the tickets.", "fx": {"morale": 2}},
				{"label": "SAY THE JOB IS TICKETS", "reply": "The job is tickets.", "fx": {"morale": -4}},
			],
		},
		{
			"text": "{name} says: The runbook said restart the service. It did not work. I restarted it four more times.",
			"options":
			[
				{"label": "TEACH THE STOP RULE", "reply": "Twice, then stop and read the log. If the log means nothing to you, bring it to me. I will add that line to the runbook.", "fx": {"morale": 4, "skill": 0.03}},
				{"label": "FIX THE RUNBOOK", "reply": "Then the runbook is wrong. Show me the step, I will change it today.", "fx": {"morale": 4, "skill": 0.01}},
				{"label": "SAY FIVE TIMES IS SILLY", "reply": "Five times. Really.", "fx": {"morale": -4}},
			],
		},
	],
	"John":
	[
		{
			"text": "I have a prospect who wants a handshake deal. No contract until next month. Come on, Dan.",
			"options":
			[
				{"label": "ASK FOR A ONE-PAGE SCOPE", "reply": "One page. What we do, what we do not, how fast. You can say it is for the crew.", "fx": {"social": {"John": 1}, "trust": {"Alan": 2, "Garrison": 0}}},
				{"label": "LET HIM HAVE THE HANDSHAKE", "reply": "Fine. But I log every hour they use.", "fx": {"social": {"John": 3}, "trust": {"Alan": -1, "Garrison": 2}, "mood": 1}},
				{"label": "REFUSE UNTIL SIGNED", "reply": "No work without a signature.", "fx": {"social": {"John": -3}, "trust": {"Alan": 2, "Garrison": -2}}},
			],
		},
		{
			"text": "My clients say tickets take forever. I tell them you are working on it. Are you?",
			"options":
			[
				{"label": "SHOW HIM THE BOARD", "reply": "Here is the queue, by age. Tell them the real number. Honest is better.", "fx": {"social": {"John": 2}, "mood": 1}},
				{"label": "GIVE HIM A PHONE NUMBER", "reply": "Give them my desk line for P1s. I will pick up.", "fx": {"social": {"John": 3}, "morale": -2}},
				{"label": "TELL HIM TO BE PATIENT", "reply": "We are working on it.", "fx": {"social": {"John": -2}}},
			],
		},
		{
			"text": "Garrison wants a client dinner on Thursday. Can the crew cover the phones?",
			"options":
			[
				{"label": "COVER IT MYSELF", "reply": "I cover the phones. Go. Bring the client back happy.", "fx": {"social": {"John": 3}, "trust": {"Alan": 0, "Garrison": 2}, "morale": 1}},
				{"label": "ASK MAYA FIRST", "reply": "I will ask Maya. If she says yes, there is a bonus.", "fx": {"social": {"John": 1}, "morale_who": {"Maya": 2}}},
				{"label": "SAY NO", "reply": "Not Thursday. The queue is too long.", "fx": {"social": {"John": -3}, "trust": {"Alan": 1, "Garrison": -2}}},
			],
		},
		{
			"text": "I know I over-promise. Garrison says it is how we win. You say it is how we lose. Who is right?",
			"options":
			[
				{"label": "SPLIT IT: PROMISE LESS, SELL BETTER", "reply": "Both. Promise what we can do and sell why it matters. I will help you write the lines.", "fx": {"social": {"John": 3}, "trust": {"Alan": 1, "Garrison": 1}}},
				{"label": "TELL HIM HE IS RIGHT", "reply": "Garrison is right about the win. I will find a way to do the work.", "fx": {"social": {"John": 4}, "trust": {"Alan": -1, "Garrison": 2}, "morale": -2}},
				{"label": "TELL HIM HE IS WRONG", "reply": "You are the one the clients blame.", "fx": {"social": {"John": -4}, "trust": {"Alan": 2, "Garrison": -2}}},
			],
		},
		{
			"text": "I told Brightside we do weekends. We do weekends, right? Dan?",
			"options":
			[
				{"label": "PRICE IT AS AN EXTRA", "reply": "We can, as a paid extra with a number on it. I will write the rate. You sell the rate.", "fx": {"social": {"John": 2}, "trust": {"Alan": 1, "Garrison": 1}}},
				{"label": "COVER THIS ONE, THEN FIX THE WORDING", "reply": "I will take this Saturday myself. Then we change the wording together.", "fx": {"social": {"John": 3}, "morale": -2, "mood": 1}},
				{"label": "TELL HIM TO TAKE IT BACK", "reply": "Call them back and take it away.", "fx": {"social": {"John": -3}, "mood": -1}},
			],
		},
		{
			"text": "The new client wants everything live by Monday. I said probably. What is probably, in tech?",
			"options":
			[
				{"label": "GIVE HIM A REAL DATE", "reply": "Probably is Thursday. Mail on Monday, the rest by Thursday. Tell them that, in writing.", "fx": {"social": {"John": 2}, "trust": {"Alan": 2, "Garrison": 0}}},
				{"label": "PULL THE CREW IN", "reply": "Fine. Monday. I move two people off the queue.", "fx": {"social": {"John": 3}, "morale": -3, "trust": {"Alan": 0, "Garrison": 1}}},
				{"label": "SAY PROBABLY MEANS NO", "reply": "It means no.", "fx": {"social": {"John": -3}, "trust": {"Alan": 0, "Garrison": -1}}},
			],
		},
		{
			"text": "Be honest. Do your people hate it when I walk into the room?",
			"options":
			[
				{"label": "TELL HIM WHAT WOULD HELP", "reply": "They do not hate you. They hate surprises. Bring the ticket number with you and they will like you fine.", "fx": {"social": {"John": 3}, "morale": 2}},
				{"label": "SAY THEY LIKE HIM", "reply": "They like you. Mostly.", "fx": {"social": {"John": 2}}},
				{"label": "SAY YES", "reply": "A little.", "fx": {"social": {"John": -4}}},
			],
		},
		{
			"text": "I want to bring Maya to a client lunch. She explains things better than I do. Can I borrow her?",
			"options":
			[
				{"label": "YES, WITH NOTICE, AND SHE PICKS", "reply": "One lunch a month, a day of notice, and she picks the client. Ask her, not me.", "fx": {"social": {"John": 2}, "morale_who": {"Maya": 3}}},
				{"label": "YES, THIS ONCE", "reply": "This once. I cover her phone.", "fx": {"social": {"John": 3}, "morale_who": {"Maya": 1}}},
				{"label": "NO, SHE IS A TECH", "reply": "She is a tech, not a brochure.", "fx": {"social": {"John": -3}}},
			],
		},
		{
			"text": "A client wants ten percent off because the printer broke twice. I kind of already said yes.",
			"options":
			[
				{"label": "TRADE IT FOR A FIX", "reply": "No discount. A clean printer setup, free, this week, with my name on it. That is worth more than ten percent.", "fx": {"social": {"John": 1}, "trust": {"Alan": 2, "Garrison": 0}, "mood": 1}},
				{"label": "LET IT STAND FOR ONE MONTH", "reply": "One month. And next time you ask first.", "fx": {"social": {"John": 3}, "trust": {"Alan": -1, "Garrison": 1}}},
				{"label": "MAKE HIM TAKE IT BACK", "reply": "Then un-say it.", "fx": {"social": {"John": -4}, "trust": {"Alan": 1, "Garrison": 0}, "mood": -1}},
			],
		},
		{
			"text": "What do I say when they ask how long a fix takes? It depends makes them twitch.",
			"options":
			[
				{"label": "GIVE HIM THREE NUMBERS", "reply": "Urgent: we call back within the hour. Normal: same day. Projects: a date in writing. I made you a card for your wallet.", "fx": {"social": {"John": 3}, "mood": 1}},
				{"label": "TELL HIM TO READ THE BOARD", "reply": "Look at the board before you answer. It is on the wall for a reason.", "fx": {"social": {"John": 1}}},
				{"label": "SAY IT DEPENDS", "reply": "It depends.", "fx": {"social": {"John": -2}}},
			],
		},
	],
}
var ONE_ON_ONES: Dictionary = DEFAULT_ONE_ON_ONES.duplicate(true)
const DEFAULT_ONE_TEXT := {
	"already": "We talked this morning, Dan. I am fine. Thanks.",
	"walkup": "%s stops by your desk.",
	"quiet": "Nothing new since last time, Dan. I am okay. Thanks for asking.",
}
var ONE_TEXT: Dictionary = DEFAULT_ONE_TEXT.duplicate(true)

# C5: the dispatch numbers and the crew's words
const OWNER_AREAS := {"servers": "Alan", "networking": "Alan", "powershell": "Alan", "security": "Garrison", "people": "Garrison"}
const POLICIES := ["all", "low", "off"]
const OWNER_RATE := 1.6  # ticket-seconds an owner works per second
const OWNER_DAY_CAP := 2  # escalations an owner takes a day
const OWNER_COST := 2  # owner trust it costs
const HANDOVER_COST := 6.0  # ticket-seconds lost when a ticket changes desks
const ASSIST := 0.5  # share of an idle tech's time that helps the busy ones
const NEGLECT_AFTER := 90.0  # seconds a P1 may wait on the board before an owner notices
const DEFAULT_CREW_TEXT := {
	"msg": {"none": "NO SUCH TICKET", "not_desk": "NOT A DESK TICKET", "same": "ALREADY THERE", "busy": "%s IS BUSY TODAY", "gone": "HE LEFT", "assigned": "#%d TO %s"},
	"lanes": {"none": "UNASSIGNED", "esc": "OWNERS"},
	"stuck": {
		"text": "Ticket #%d is above my level (%s). Can you look when you have a minute?",
		"toast": "%s IS STUCK. REASSIGN IT.",
		"thanks": "%s: THANKS FOR THE HELP.",
		"called": "%s CALLED %s FOR HELP.",
		"alone": "Never mind, I will figure it out. It will take a while.",
	},
	"neglect": "P1 #%d HAS WAITED ON THE BOARD. GARRISON NOTICED.",
	"farewell": {
		"text": "Dan, I handed in my notice to Morgan this morning. It is not you. It was a lot, and I need a break. Thank you for the chance, %s.",
		"options":
		[
			{"id": "w", "label": "WISH THEM WELL", "reply": "Good luck. I mean it. The door is open.", "fx": {"morale": 1}},
			{"id": "a", "label": "ASK WHAT WENT WRONG", "reply": "The queue was never empty and nobody asked. Please write that down.", "fx": {"morale": 2, "retain_all": 1}},
			{"id": "o", "label": "ASK FOR TWO WEEKS", "reply": "I will stay until Friday, but my head is already out of here.", "fx": {"morale": -1}},
		],
	},
}
var CREW_TEXT: Dictionary = DEFAULT_CREW_TEXT.duplicate(true)

# the days' scripted events: at (clock), kind mail / memo / beat / incident / friday
const DEFAULT_DAYS := {
	1: [{"at": 9.4, "kind": "beat", "id": "handover"}, {"at": 9.1, "kind": "mail", "from": "Morgan Reyes - Manager", "subject": "The desk is yours", "body": "Dan, welcome to the chair. Each morning there is a huddle: pick the focus for the day. Talk to your people with E, they notice. Alan and Garrison will send memos that disagree with each other. Do not try to please both every time. - Morgan"}],
	3: [{"at": 9.1, "kind": "mail", "from": "Morgan Reyes - Manager", "subject": "Your own queue", "body": "You can still pick up tickets with your own PSA and RMM when the crew is stuck. Just remember every minute at the keyboard is a minute nobody is looking at the board. - Morgan"}, {"at": 9.8, "kind": "design"}],
	4: [{"at": 10.5, "kind": "beat", "id": "xp"}],
	6: [{"at": 10.5, "kind": "beat", "id": "vic"}, {"at": 11.6, "kind": "hire"}],
	7: [{"at": 10.2, "kind": "incident", "id": "rdp", "book": "rdp"}],
	9: [{"at": 10.2, "kind": "incident", "id": "ransom", "book": "ransom"}],
	10: [{"at": 16.0, "kind": "friday"}],
	11: [{"at": 10.2, "kind": "incident", "id": "rack", "book": "rack"}],
	12: [{"at": 11.0, "kind": "hire"}],
	13: [{"at": 10.2, "kind": "incident", "id": "email24", "book": "email24"}],
	15: [{"at": 10.2, "kind": "incident", "id": "migration", "book": "migration"}, {"at": 16.0, "kind": "friday"}],
	16: [{"at": 10.5, "kind": "beat", "id": "nosale"}],
	18: [{"at": 10.5, "kind": "beat", "id": "grow"}],
	19: [{"at": 10.5, "kind": "beat", "id": "audit"}],
	20: [{"at": 9.1, "kind": "mail", "from": "Morgan Reyes - Manager", "subject": "Review at the end of the day", "body": "After close, you, me, Alan and Garrison sit down for your review. Bring the scorecard. - Morgan"}],
}
var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)

const DEFAULT_REVIEW := {
	"heading": "ANNUAL REVIEW",
	"quotes":
	{
		"Alan": {"high": "THE DESK IS DOCUMENTED AND THE NUMBERS ARE HONEST. THAT IS ALL I EVER ASKED.", "mid": "SOLID WORK. I WOULD LIKE MORE TIME ON THE STACK.", "low": "TOO MANY CORNERS CUT. I HAD TO FIX THEM."},
		"Garrison": {"high": "THE CLIENTS LIKE YOU AND THE TEAM STAYS. YOU GET IT.", "mid": "GOOD, BUT YOU SAY NO TOO OFTEN.", "low": "THE CLIENTS NEEDED A YES AND GOT A MEMO."},
		"crew": {"high": "DAN LABELS EVERYTHING AND LISTENS. WE WOULD FOLLOW HIM.", "mid": "QUIET, FAIR, A BIT HARD TO READ.", "low": "WE DO NOT KNOW WHERE WE STAND."},
	},
	"endings":
	{
		"ops": {"label": "OPERATIONS MANAGER", "desc": "BOTH OWNERS BACK YOU. A RAISE, A BIGGER DESK AND A HIRE.", "text": "YOU BECOME OPERATIONS MANAGER. A RAISE, A SECOND TECH AND A STANDING SEAT AT THE OWNERS' TABLE. THE PATCH PANEL IS STILL LABELLED."},
		"alan": {"label": "SIDE WITH ALAN: TECHNICAL DIRECTOR", "desc": "ALAN WANTS YOU RUNNING THE STACK AND THE PROCESS.", "text": "YOU TAKE ALAN'S OFFER: TECHNICAL DIRECTOR. MORE SERVERS, FEWER CLIENT DINNERS, EVERYTHING DOCUMENTED. GARRISON SHAKES YOUR HAND AND STAYS POLITE."},
		"garrison": {"label": "SIDE WITH GARRISON: GROWTH MANAGER", "desc": "GARRISON WANTS YOU BUILDING A BIGGER, FASTER SERVICE DESK.", "text": "YOU TAKE GARRISON'S OFFER: GROWTH MANAGER. BIGGER SLAS, MORE CLIENTS, A TEAM DINNER EVERY MONTH. ALAN WRITES YOU A VERY LONG MEMO."},
		"leave": {"label": "LEAVE FOR AN IN-HOUSE IT JOB", "desc": "A CLIENT OFFERS YOU THEIR ONLY IT JOB: ONE NETWORK, CALM HOURS.", "text": "YOU TURN IN YOUR BADGE. ONE OFFICE, ONE NETWORK, NO PAGER. YOU LABEL THEIR PATCH PANEL ON YOUR FIRST DAY."},
		"rollup_yes": {"label": "ACCEPT SUMMIT'S ROLL-UP", "desc": "THE OWNERS SELL. YOU STAY ON AS SUMMIT'S SERVICE DIRECTOR.", "text": "THE OWNERS SIGN WITH SUMMIT MANAGED HOLDINGS AND YOU BECOME THEIR SERVICE DIRECTOR FOR THE REGION. THE SCORECARD TRAVELS WITH YOU. EVERY NEW PATCH PANEL YOU MEET GETS A LABEL."},
		"rollup_no": {"label": "DECLINE THE ROLL-UP", "desc": "YOU ADVISE THE OWNERS TO STAY INDEPENDENT.", "text": "THE OWNERS TURN SUMMIT DOWN AND KEEP THE COMPANY. THE DESK STAYS YOURS, WITH A BETTER SCORECARD AND A LONGER LIST OF THINGS TO DOCUMENT."},
		"stay": {"label": "STAY ON PROBATION", "desc": "KEEP THE DESK, WITH A THIRTY-DAY PLAN FROM MORGAN.", "text": "YOU KEEP THE DESK WITH A WRITTEN PLAN. MORGAN WILL CHECK IT EVERY FRIDAY. YOU START BY LABELLING THE PLAN."},
	},
}
var REVIEW: Dictionary = DEFAULT_REVIEW.duplicate(true)

const KNOWLEDGE := preload("res://scripts/knowledge.gd")
# ---- C6 (V3): runbooks, desk design, hiring for fit, onboarding, retention events. All patchable text lives in these tables. ----
const KB_ORDER := ["spooler", "password", "clear_temp", "reboot", "av", "restore", "adobe", "rdp", "ransom", "rack", "email24", "migration"]
const DEFAULT_RUNBOOKS := {
	"spooler": {"label": "PRINT SPOOLER", "kind": "ticket", "quiz": {"q": "A printer shows queued jobs that never print. What do you do first?", "options": ["RESTART THE PRINT SPOOLER AND TEST A PAGE", "REIMAGE THE PC", "REBOOT THE SERVER"], "answer": 0}},
	"password": {"label": "PASSWORD RESET", "kind": "ticket", "quiz": {"q": "Somebody emails to say they are locked out. What comes first?", "options": ["CONFIRM IT IS REALLY THEM, THEN RESET", "RESET IT FOR ANYONE WHO ASKS", "SEND THE ADMIN PASSWORD"], "answer": 0}},
	"clear_temp": {"label": "SLOW PC CLEANUP", "kind": "ticket", "quiz": {"q": "A PC crawls and the disk is full. What is the safe order?", "options": ["CLEAR TEMP FILES, THEN CHECK THE DISK", "DELETE THE USER PROFILE", "FORMAT AND START OVER"], "answer": 0}},
	"reboot": {"label": "BLUE SCREEN / REBOOT", "kind": "ticket", "quiz": {"q": "A frozen PC needs a restart. What do you do before you press the button?", "options": ["ASK THE USER TO SAVE THEIR WORK", "RESTART AT ONCE", "UNPLUG IT FROM THE WALL"], "answer": 0}},
	"av": {"label": "POP-UPS / VIRUS", "kind": "ticket", "quiz": {"q": "A PC is full of pop-ups and ads. What is the first move?", "options": ["TAKE IT OFF THE NETWORK, THEN SCAN", "CLOSE THE POP-UPS AND MOVE ON", "INSTALL A SECOND ANTIVIRUS"], "answer": 0}},
	"restore": {"label": "RESTORE FROM BACKUP", "kind": "ticket", "quiz": {"q": "Files are encrypted and the client wants them back. What first?", "options": ["CHECK THE BACKUP IS GOOD, THEN RESTORE", "PAY BEFORE LOOKING AT ANYTHING", "DELETE THE ENCRYPTED FILES"], "answer": 0}},
	"adobe": {"label": "PDF READER WON'T PRINT", "kind": "ticket", "quiz": {"q": "The reader opens but will not print anything. Safest first fix?", "options": ["REPAIR THE READER AND PRINT A TEST", "REINSTALL WINDOWS", "TELL THEM TO USE THE FAX"], "answer": 0}},
	"rdp": {"label": "RDP EXPOSED (JOB)", "kind": "job", "area": "security", "need": 2, "quiz": {"q": "Remote Desktop is open to the internet. What closes the door?", "options": ["A VPN OR A FIREWALL THAT BLOCKS GUESSING", "CHANGING THE PORT NUMBER ONLY", "A LONGER PASSWORD AND HOPE"], "answer": 0}},
	"ransom": {"label": "RANSOMWARE (JOB)", "kind": "job", "area": "security", "need": 2, "quiz": {"q": "CryptoLocker is on a file server. What do you do first?", "options": ["ISOLATE IT, THEN RESTORE FROM BACKUP", "LEAVE IT RUNNING TO SEE WHAT HAPPENS", "PAY IT BEFORE ANYONE ASKS"], "answer": 0}},
	"rack": {"label": "RACK DOWN (JOB)", "kind": "job", "area": "networking", "need": 2, "quiz": {"q": "The network rack came off the wall. Before you touch a cable?", "options": ["PHOTOGRAPH AND LABEL EVERY CABLE", "PULL THEM ALL AND SORT IT OUT LATER", "REBOOT THE SWITCH"], "answer": 0}},
	"email24": {"label": "EMAIL OUTAGE NIGHT (JOB)", "kind": "job", "area": "servers", "need": 2, "quiz": {"q": "The mail server is down at night and the client runs 24x7. First?", "options": ["OPEN A PRIORITY CASE WITH THE VENDOR", "WAIT UNTIL MORNING", "REBUILD EVERY MAILBOX"], "answer": 0}},
	"migration": {"label": "SERVER MIGRATION (JOB)", "kind": "job", "area": "servers", "need": 2, "quiz": {"q": "The cutover is tonight. What must be true before you start?", "options": ["THE BACKUP IS VERIFIED AND A ROLLBACK EXISTS", "NOBODY HAS EMAILED YOU", "THE OLD SERVER IS ALREADY OFF"], "answer": 0}},
}
var RUNBOOKS: Dictionary = DEFAULT_RUNBOOKS.duplicate(true)

const DESIGN_ORDER := ["tiered", "swarm", "pods"]
const DISPATCHER_WAGE := 520  # dollars a week for a dispatcher
const POD_STIPEND := 40  # dollars a week per tech for pod leads
const DEFAULT_DESIGNS := {
	"card": {
		"speaker": "Morgan Reyes - Manager",
		"text": "Dan, the desk needs a shape. Alan wants tiers: easy tickets to L1, hard ones to L2, the owners as L3. Garrison wants everyone to live with their own clients. You can also let everybody take everything. Change your mind later and it costs two hours and a confused morning, once.",
		"revisit": "You want to reshape the desk. It costs two manager hours, a morning of confusion and a little trust with both owners, and you only get this one change. Which design?",
		"keep": "KEEP IT AS IT IS",
		"dispatcher": "Who dispatches? You are the dispatcher by default: every ticket goes through your hands and your manager hours stay thin. A dispatcher costs money every week but gives you hours back and picks tickets up faster.",
		"you": "I DISPATCH MYSELF",
		"hire": "HIRE A DISPATCHER ($520 A WEEK)",
		"done": "The desk is %s. %s",
		"changed": "THE DESK IS %s NOW.",
		"no_hours": "NEEDS 2 MANAGER HOURS",
		"used": "ALREADY CHANGED ONCE",
	},
	"tiered": {
		"label": "TIERED DESK", "short": "TIERED", "option": "TIERED: L1, L2 AND L3 LANES",
		"text": "Easy tickets go to L1, harder ones to L2, the owners are L3. Clean handoffs and fewer reopens. The cost: seniors wait for work while juniors wait for seniors, and hot tickets cross lanes only when their own is full. It suits a desk that has a dispatcher.",
		"note": "L1 AND L2 LANES. FEWER REOPENS, SLOWER TO FLEX.",
		"trust": {"Alan": 4, "Garrison": -2},
		"mail": {"Alan": ["Alan (Co-owner)", "Tiers", "Good. Levels, handoffs, escalation paths. That is how a desk grows up. Write it down. - Alan"], "Garrison": ["Garrison (Co-owner)", "Tiers", "I hope the clients do not feel the queue. Tell me if an L1 ticket waits while an L2 tech sits idle. - Garrison"]},
	},
	"swarm": {
		"label": "SWARM DESK", "short": "SWARM", "option": "SWARM: EVERYONE TAKES EVERYTHING",
		"text": "Nobody owns a lane. Whoever is free picks up whatever is next. Fast and flexible, and the board is a lively place. The cost: tickets go to the wrong person now and then, the SLA clock suffers when a hot one lands on the wrong desk, and more of them come back.",
		"note": "ANYONE, ANYTHING. FASTER, BUT MIS-ALLOCATION AND REOPENS.",
		"trust": {"Alan": -3, "Garrison": 3},
		"mail": {"Alan": ["Alan (Co-owner)", "Swarm", "I will not argue with a free-for-all that closes tickets. I will argue when a password reset lands on the person who is rebuilding the firewall. - Alan"], "Garrison": ["Garrison (Co-owner)", "Swarm", "Love it. Everyone helps everyone, clients get answers faster. Keep it moving. - Garrison"]},
	},
	"pods": {
		"label": "CLIENT PODS", "short": "PODS", "option": "PODS: A TECH FOR EACH CLIENT GROUP",
		"text": "Each tech owns a few clients and learns them. Deep knowledge builds day by day and clients feel looked after. The cost: pods do not help each other much, a pod tech who is out or leaves leaves a hole, and pod leads cost more every week.",
		"note": "ONE TECH PER CLIENT GROUP. DEEP KNOWLEDGE, DEARER, BRITTLE.",
		"trust": {"Alan": -1, "Garrison": 4},
		"mail": {"Alan": ["Alan (Co-owner)", "Pods", "Pods are fine if the knowledge leaves the pod. Make them write it down. - Alan"], "Garrison": ["Garrison (Co-owner)", "Pods", "A face for every client. That is a story I can sell. - Garrison"]},
	},
	"dispatcher": {
		"you": {"trust": {}, "text": "You keep the board yourself."},
		"hire": {"trust": {"Alan": 2, "Garrison": -1}, "text": "A dispatcher starts Monday. You have two hours back every day."},
	},
}
var DESIGNS: Dictionary = DEFAULT_DESIGNS.duplicate(true)

const DEFAULT_KB_TEXT := {
	"msg": {"need": "NEED %.1f H, %.1f H LEFT", "draft": "DRAFT STARTED: %s", "live": "RUNBOOK LIVE: %s", "refresh": "REFRESHED: %s", "stale": "%s RUNBOOK IS OUT OF DATE", "trained": "%s IS TRAINED. IT STAYS.", "already": "ALREADY TRAINED", "nobody": "NOBODY TO DO IT", "shadow": "%s IS SHADOWING", "none": "NO SUCH RUNBOOK", "signoff": "SIGN-OFF %d MORE"},
	"lesson": {
		"text": "%s recorded the %s fix and walked the trainee through it. Before you sign it off, check the lesson: %s",
		"good": "The lesson holds up. %s will sign it off on the next live tickets. Once they have, it stays trained.",
		"fail": "That was not the safest step. The recording needs another take and the hour is gone. Try the lesson again.",
		"ok": "OK",
	},
	"bus": {
		"mail_from": "Morgan Reyes - Manager",
		"subject": "Who knew how to do that?",
		"body": "%s was the only one who knew %s and nothing was written down. Until somebody learns it or it is documented, everyone will stall on it. - Morgan",
		"alan": "Alan (Co-owner)",
	},
	"stale": {"from": "Alan (Co-owner)", "subject": "Runbooks out of date"},
}
var KB_TEXT: Dictionary = DEFAULT_KB_TEXT.duplicate(true)

# systems change: a runbook on one of these goes stale on that day (CHANGES[day].pick of them, seeded). Trained runbooks never do.
const DEFAULT_CHANGES := {
	"8": {"classes": ["spooler", "adobe"], "pick": 1, "subject": "New copiers Monday", "body": "Garrison signed for new copiers at three clients. The print drivers and the PDF reader set-up change this week. Anything written down about printing is out of date."},
	"12": {"classes": ["av", "password"], "pick": 1, "subject": "New antivirus and password rules", "body": "The RMM now pushes a different antivirus and the password rules change on Monday. Whatever the crew wrote down for that is wrong now."},
	"15": {"classes": ["reboot", "clear_temp"], "pick": 1, "subject": "Windows updates this weekend", "body": "A round of Windows updates went to every workstation. The usual fixes behave differently. The notes need another look."},
}
var CHANGES: Dictionary = DEFAULT_CHANGES.duplicate(true)

const TRAINING_ORDER := ["none", "light", "full"]
const TRAINING := {
	"none": {"label": "OFF", "cost": 0, "area": 0.0, "morale": 0},
	"light": {"label": "LIGHT ($150 A WEEK)", "cost": 150, "area": 0.01, "morale": 0},
	"full": {"label": "FULL ($400 A WEEK)", "cost": 400, "area": 0.03, "morale": 1},
}

const DEFAULT_HIRE_TEXT := {
	"intro": "Three people came through the door for the open desk. An interview costs one of your hours and shows real skill and fit. Hours left today: %.1f.",
	"line": "%s - %s - $%d - %s",
	"revealed": ": SKILL %.2f, FIT %d/%d/%d",
	"hidden": ": ?",
	"fit_key": "FIT = CULTURE / COMMUNICATION / CURIOSITY, 1 TO 5.",
	"trait_short": {"wizard": "WIZARD", "people": "CLIENT PRO", "green": "EAGER", "flight": "FLIGHT RISK", "steady": "STEADY"},
	"interview": "INTERVIEW %s (1H)",
	"decide": "DECIDE NOW",
	"no_hours": "NO HOURS LEFT",
	"decide_text": "Who gets the desk? Morgan signs whatever you decide.",
	"hire": "HIRE %s",
	"none": "NO ONE RIGHT NOW",
	"full": "The crew is full: six people is all the seats and desks you have.",
	"tech_q": {
		"powershell": "How would you find every user whose password is older than ninety days?",
		"networking": "A switch port drops every few minutes. What do you check first?",
		"servers": "Users cannot open the file share but ping works. Where do you start?",
		"security": "A user clicked a link in a fake invoice email. What do you do in the first ten minutes?",
	},
	"tech_a": {
		"strong": "%s answers at once, then adds a second check nobody asked for.",
		"ok": "%s gets there with a nudge and says so honestly.",
		"weak": "%s talks around it and glances at the door.",
	},
	"tech_next": "NEXT QUESTION",
	"behave_q": "Tell me about a time a client was angry and you were in the wrong.",
	"behave_a": {
		"high": "%s calls the client back the same day, then writes it up so nobody else repeats it.",
		"mid": "%s apologised and fixed it, and says the follow-up could have been better.",
		"low": "%s blames the ticketing system and the last manager.",
	},
	"summary": "NOTE IT",
	"onboard": {
		"text": "%s starts tomorrow. How do you start them? Shadowing Maya for two days is gentle and costs no hours. A structured start with a written plan costs you two hours today and gets them on tickets sooner.",
		"shadow": "SHADOW MAYA FOR TWO DAYS",
		"structured": "STRUCTURED START (2H)",
		"hint": "NEEDS 2 MANAGER HOURS",
		"shadow_done": "%s will shadow for two days.",
		"structured_done": "%s has a plan and starts on tickets tomorrow.",
	},
	"welcome": {"from": "Morgan Reyes - Manager", "subject": "New hire: %s", "body": "%s starts today and has a seat at the conference table. Tell me how the first weeks go. - Morgan"},
	"react": {
		"ringer": {"trust": {"Alan": 3, "Garrison": -2}, "text": "Alan likes the hire. Garrison asks whether they will fit in."},
		"fit": {"trust": {"Alan": -1, "Garrison": 3}, "text": "Garrison likes the hire. Alan asks whether they can do the hard tickets."},
		"mid": {"trust": {"Alan": 1, "Garrison": 1}, "text": "Both owners nod."},
		"none": {"trust": {"Alan": -1, "Garrison": -1}, "text": "Both owners wonder why the seat is still empty."},
	},
}
var HIRE_TEXT: Dictionary = DEFAULT_HIRE_TEXT.duplicate(true)

# crew life events, fed by morale and workload. who: skilled / curious / loaded / senior / low. Evaluated each morning from day 4.
const RETENTION_ORDER := ["resign", "burnout", "counter", "promotion", "training"]
const DEFAULT_RETENTION := {
	"counter": {
		"min_day": 5, "cool": 9, "speaker": "%s (Tier 1)",
		"text": "A competitor, ByteBrothers, has offered %s a title and $80 a week more. Nobody has said anything. You know because the recruiter emailed the wrong person.",
		"options":
		[
			{"id": "m", "label": "MATCH IT ($80 A WEEK)", "reply": "I did not expect that. I will stay, and thank you for asking before I had to.", "fx": {"wage": 80, "retain": 3, "morale": 5, "trust": {"Alan": -1, "Garrison": 1}}},
			{"id": "t", "label": "TALK ABOUT THE PLAN", "reply": "A growth plan is worth something. Show me it is real and I will think about it.", "fx": {"roll": {"p": 0.5, "win": {"retain": 2, "morale": 4, "focus_area": true}, "lose": {"morale": -2, "retain": -1}}}},
			{"id": "w", "label": "WISH THEM WELL", "reply": "Understood. I will give you my two weeks, and I will write the handover down.", "fx": {"quit": true, "trust": {"Garrison": -1}}},
		],
	},
	"training": {
		"min_day": 4, "cool": 10, "speaker": "%s (Tier 1)",
		"text": "%s asks for a course budget: a vendor certification class, about $400, and two Fridays for the exam. It would help the whole desk.",
		"options":
		[
			{"id": "a", "label": "APPROVE THE COURSE ($400)", "reply": "Thank you. I will share what I learn on Friday.", "fx": {"cost": 400, "area": 0.5, "skill": 0.02, "morale": 6, "retain": 2, "trust": {"Alan": 2}}},
			{"id": "h", "label": "HALF: STUDY ON FRIDAYS", "reply": "That works. I will take the book home.", "fx": {"area": 0.25, "morale": 2, "trust": {"Alan": 1}}},
			{"id": "n", "label": "NOT THIS QUARTER", "reply": "Okay. I will ask again in the new year.", "fx": {"morale": -4, "retain": -1, "trust": {"Alan": -1}}},
		],
	},
	"burnout": {
		"min_day": 4, "cool": 7, "speaker": "%s (Tier 1)",
		"text": "%s has carried a full board for days and has stopped joking at lunch. Tickets are slower and the replies are short.",
		"options":
		[
			{"id": "u", "label": "TAKE TICKETS OFF THEIR DESK", "reply": "Thank you. I can see over the top of the pile again.", "fx": {"unload": true, "morale": 5, "stress": -15}},
			{"id": "d", "label": "A QUIET HALF DAY", "reply": "I will go for a walk and come back with a clear head.", "fx": {"off_day": true, "morale": 8, "stress": -25}},
			{"id": "t", "label": "TOUGH IT OUT, BUSY WEEK", "reply": "Sure. Whatever you need.", "fx": {"morale": -6, "stress": 5, "trust": {"Alan": 1}}},
		],
	},
	"promotion": {
		"min_day": 9, "cool": 12, "speaker": "%s (Tier 1)",
		"text": "%s asks to move up to Tier 2. They have been taking the harder tickets and want the title and the pay that goes with it.",
		"options":
		[
			{"id": "p", "label": "PROMOTE ($80 A WEEK)", "reply": "Thank you, Dan. I will not let the board down.", "fx": {"promote": true, "wage": 80, "morale": 8, "retain": 3, "trust": {"Alan": 1, "Garrison": -1}}},
			{"id": "l", "label": "YES, WITH A PLAN", "reply": "A plan is fair. Tell me what I have to show.", "fx": {"focus_area": true, "morale": 2, "retain": 1}},
			{"id": "n", "label": "NOT YET", "reply": "Okay. I hoped for a different answer.", "fx": {"morale": -4, "retain": -1}},
		],
	},
	"resign": {
		"min_day": 6, "cool": 8, "speaker": "%s (Tier 1)",
		"text": "%s left a polite letter on your desk. No complaint, just a thank you and a last day. Morgan does not know yet.",
		"options":
		[
			{"id": "a", "label": "ASK WHAT WOULD CHANGE", "reply": "Thank you for asking. If the board stays this calm, I will stay.", "fx": {"roll": {"p": 0.55, "win": {"retain": 3, "morale": 6}, "lose": {"quit": true}}}},
			{"id": "r", "label": "COUNTER WITH A RAISE ($60 A WEEK)", "reply": "That is generous. I will tear up the letter.", "fx": {"wage": 60, "morale": 5, "retain": 2, "trust": {"Garrison": -1}}},
			{"id": "g", "label": "ACCEPT IT GRACEFULLY", "reply": "Thank you. It is not about you.", "fx": {"quit": true, "morale_all": -2}},
		],
	},
}
var RETENTION: Dictionary = DEFAULT_RETENTION.duplicate(true)
const RET_COOLDOWN := 3  # days between any two life events
const DEFAULT_ROWS := {"documented": "DOCUMENTED", "retention": "RETENTION", "solo": "FIRST SOLO", "cost": "COST PER TICKET", "design": "DESK", "none": "NO DESIGN YET", "solo_wait": "NOT YET", "solo_none": "NO HIRES", "days": "%.1f DAYS", "bus": "BUS FACTOR"}
var ROWS: Dictionary = DEFAULT_ROWS.duplicate(true)

var trust := {"Alan": TRUST_START, "Garrison": TRUST_START}
var focus := "p1"
var buffs: Array = []  # {key, val, left}
var flags := {}
const OTO_QUIET_MORALE := 3  # C7: what a check-in is worth once the deck is used up (a card's middle answer)
var oto_seen := {}  # deck -> cards used
var oto_log := []  # C7: [deck, card index] of every 1:1 of this run in order (-1 = the check-in after the deck ran out); not saved
var oto_day := {}  # who -> the day you last had a 1:1
var grades: Array = []  # [{day, grade, score, util, sla}]
var project_days := 0
var memos_done := {}
var _fired := {}
var _cap := 0.0
var _work_base := 0.0
var _frt_sum := 0.0
var _frt_n := 0
var _seen := {}
var _pick_t := 0.0
var _stuck_t := 0.0
var _outings_seen := 0
var _day_util := 0.0
var _walked := false
var auto := "all"  # who the crew picks up on its own: "all", "low" (P3 / P4 only) or "off" (you assign everything)
var owner_used := {"Alan": 0, "Garrison": 0}  # escalations to each owner today
var dispatched := 0  # assignments you made by hand this run
var escalated := 0  # tickets that went to an owner this run
var _flag_t := 0.0
var _hand_day := 0
var kb = KNOWLEDGE.new()  # the runbooks (C6): the Knowledge app's model
var design := ""  # "" (not chosen yet: the autopilot picks by fit), "tiered", "swarm" or "pods"
var dispatcher := false  # a hired dispatcher (otherwise you dispatch yourself)
var design_day := 0
var design_changes := 0  # the desk can be reshaped once
var pods := {}  # client index -> the tech who owns that client
var pod_days := {}  # client index -> days the same tech has had it (deep client knowledge)
var misallocated := 0  # swarm tickets that went to the wrong desk
var training := "none"  # the weekly training budget: none, light or full
var spent_today := 0.0  # one-off spending today (courses)
var spent_total := 0
var last_event_day := -99
var event_days := {}  # retention event id -> the day it last fired
var events_fired: Array = []  # "id:who:day"
var leaving: Array = []  # techs who walk out tonight (a life-event choice)
var cands: Array = []  # the candidates on the hiring card
var interviewed := {}


func _ready() -> void:
	reset()
	Msp.ticket_added.connect(ByName.on_ticket)  # R36: a client that knows a tech asks for him


func active() -> bool:
	return Campaign.active and Campaign.mode == "service"


func reset() -> void:
	trust = {"Alan": TRUST_START, "Garrison": TRUST_START}
	focus = "p1"
	buffs = []
	flags = {}
	oto_seen = {}
	oto_log = []
	oto_day = {}
	grades = []
	project_days = 0
	memos_done = {}
	_fired = {}
	_cap = 0.0
	_work_base = 0.0
	_frt_sum = 0.0
	_frt_n = 0
	_seen = {}
	_pick_t = 0.0
	_stuck_t = 0.0
	_outings_seen = 0
	_day_util = 0.0
	_walked = false
	auto = "all"
	owner_used = {"Alan": 0, "Garrison": 0}
	dispatched = 0
	escalated = 0
	_flag_t = 0.0
	_hand_day = 0
	design = ""
	dispatcher = false
	design_day = 0
	design_changes = 0
	pods = {}
	pod_days = {}
	misallocated = 0
	training = "none"
	spent_today = 0.0
	spent_total = 0
	last_event_day = -99
	event_days = {}
	events_fired = []
	leaving = []
	cands = []
	interviewed = {}
	kb.reset()
	Crew.reset()
	ServiceArc.reset()


# a new run: Dan arrives with good networking, Morgan's confidence starts at 55
func begin_run() -> void:
	Campaign.rep = START_CONFIDENCE
	var need: int = Skills.XP_AT[2]
	Skills.xp["networking"] = maxi(int(Skills.xp.get("networking", 0)), need)
	ServiceArc.begin_run()


# ---- numbers other scripts read ---------------------------------------------------------------------------------
func trust_of(owner_name: String) -> int:
	return int(trust.get(owner_name, TRUST_START))


func add_trust(owner_name: String, amount: int) -> void:
	if trust.has(owner_name):
		var change := amount
		if amount < 0:
			change = -maxi(1, roundi(float(-amount) * Difficulty.cf("service.trust")))  # Q6: a harder tier forgives less
		trust[owner_name] = clampi(trust_of(owner_name) + change, 0, 100)


func trust_word(v: int) -> String:
	if v >= 70:
		return "BACKS YOU"
	if v >= 50:
		return "TRUSTS YOU"
	return "WATCHING" if v >= 30 else "DOUBTS YOU"


# the crew's speed multiplier from the focus and the memo effects (written into Owner.speed)
func speed_mult() -> float:
	var m := float(FOCUS[focus].speed)
	for b in buffs:
		if str(b.key) == "speed":
			m *= float(b.val)
	return m


func _buff_mult(key: String) -> float:
	var m := 1.0
	for b in buffs:
		if str(b.key) == key:
			m *= float(b.val)
	return m


func _buff_add(key: String) -> float:
	var a := 0.0
	for b in buffs:
		if str(b.key) == key:
			a += float(b.val)
	return a


# Owner.edge() in this mode: the neutral edge changed by the focus, the buffs and the cleanup days you did
func edge(key: String) -> float:
	var base := float(Owner.DEFAULT_EDGE[key])
	if key == "close_miss":
		return clampf(base + float(FOCUS[focus].miss) + _buff_add("miss"), 0.01, 0.4)
	if key == "issues":
		return base * maxf(0.82, 1.0 - 0.03 * float(project_days)) * _buff_mult("issues")
	return base


func _sync() -> void:
	Owner.speed = speed_mult()


func crew_mood_word() -> String:
	var m := Crew.morale_avg()
	return str(HUDDLE.moods.good) if m >= 65 else (str(HUDDLE.moods.ok) if m >= 45 else str(HUDDLE.moods.low))


# ---- effects ----------------------------------------------------------------------------------------------------
# 1:1 gains: your CUSTOMER skill, the PEOPLE stat of the build (0.1 a level) and the QUIET TYPE quirk
func _people_scale() -> float:
	var s := 1.0 + 0.1 * float(Skills.level("people")) + 0.1 * float(Build.level("people"))
	return clampf(s * (1.0 + Build.fx("oto")), 0.6, 1.8)


# CLIENT RELATIONS: what you gain with an owner or a client counts for more, what you lose for less
func _rel_scale(v: int) -> float:
	var lv := float(Build.level("relations"))
	return 1.0 + 0.1 * lv if v > 0 else maxf(0.5, 1.0 - 0.08 * lv)


# ESCALATION: a better judge of when a ticket should go up costs the owner's trust less
func owner_cost() -> int:
	return clampi(OWNER_COST - Build.level("escalation") / 2, 0, OWNER_COST)


func apply_fx(fx: Dictionary, scale := 1.0) -> void:
	for who in fx.get("trust", {}):
		var dv := int(fx.trust[who])
		add_trust(str(who), int(round(float(dv) * _rel_scale(dv))))
	if fx.has("morale"):
		var n := int(round(float(fx.morale) * (scale if int(fx.morale) > 0 else 1.0)))
		Crew.add_all(n)
	for who in fx.get("morale_who", {}):
		var v := int(fx.morale_who[who])
		Crew.add_morale(str(who), int(round(float(v) * (scale if v > 0 else 1.0))))
	for who in fx.get("retain", {}):
		var rv := int(fx.retain[who])
		Crew.add_retain(str(who), rv + (1 if rv > 0 and Build.level("people") >= 2 else 0))
	if fx.has("retain_all"):
		for who in Crew.names():
			Crew.add_retain(str(who), int(fx.retain_all))
	if fx.has("mood"):
		var mv := int(fx.mood)
		for c in Sales.active:
			Sales.adjust(int(c), int(round(float(mv) * _rel_scale(mv))))
	if fx.has("conf"):
		Campaign.adjust_rep(int(fx.conf))
	for who in fx.get("social", {}):
		Social.change(str(who), int(fx.social[who]))
	if fx.has("buff"):
		var b: Array = fx.buff
		buffs.append({"key": str(b[0]), "val": float(b[1]), "left": int(b[2])})
		_sync()
	if fx.has("flag"):
		flags[str(fx.flag)] = true
	if fx.has("mentor"):
		Crew.mentor(str(fx.mentor))
	if fx.has("graduate"):
		var m := str(fx.graduate)
		if Crew.has(m):
			Crew.members[m]["skill"] = minf(Crew.MAYA_CAP + 0.1, Crew.value(m, "skill") + 0.15)
			for a in Crew.AREAS:
				Crew.train(m, a, 0.5)
			Crew.add_morale(m, 10)
			Crew.add_retain(m, 3)
			flags["graduated"] = m
	if fx.has("audit"):
		flags["audited"] = true


func _skill_fx(who: String, fx: Dictionary) -> void:
	if fx.has("skill") and Crew.has(who):
		Crew.skill_gain(who, float(fx.skill))
	if fx.has("stress"):
		Crew.add_stress(who, int(fx.stress))


# ---- the day -----------------------------------------------------------------------------------------------------
func begin_day(day: int) -> void:
	_fired = {}
	_cap = 0.0
	_work_base = _client_work()
	_frt_sum = 0.0
	_frt_n = 0
	_walked = false
	_pick_t = 0.0
	owner_used = {"Alan": 0, "Garrison": 0}
	_hand_day = 0
	Crew.stuck = {}
	var keep: Array = []
	for b in buffs:
		b["left"] = int(b.left) - 1
		if int(b.left) > 0:
			keep.append(b)
	buffs = keep
	# an outing since yesterday lifts the crew
	if Outings.count > _outings_seen:
		Crew.add_all(6)
		_outings_seen = Outings.count
	_sync()
	spent_today = 0.0
	leaving = []
	kb.begin_day(day)
	if design == "pods":
		for c in pods:
			pod_days[c] = int(pod_days.get(c, 0)) + 1
		rebuild_pods()
	_farewells()
	huddle()
	retention_event()
	ServiceArc.begin_day(day)


func _client_work() -> float:
	var total := 0.0
	for c in Owner.client_work:
		total += float(Owner.client_work[c])
	return total


func open_counts() -> Array:
	var open := Msp.open_tickets()
	var hot := 0
	for t in open:
		if int(t.pri) <= 2:
			hot += 1
	return [open.size(), hot]


func huddle() -> void:
	var counts := open_counts()
	var opts := []
	for id in FOCUS_ORDER:
		opts.append({"label": str(HUDDLE.options[id].label), "id": id})
	Cards.ask(
		str(HUDDLE.speaker),
		str(HUDDLE.text) % [int(counts[0]), int(counts[1]), crew_mood_word().to_upper()],
		opts,
		func(id: String) -> void: set_focus(id)
	)


func set_focus(id: String) -> void:
	if not FOCUS.has(id):
		return
	focus = id
	_sync()
	Hints.toast(str(HUDDLE.options[id].note), 3.5)


func _process(delta: float) -> void:
	if not active() or Game.title_mode or World.time_scale <= 0.0 or not Msp.enabled:
		return
	var dt := delta * World.time_scale
	var events: Array = DAYS.get(Campaign.day, [])
	for i in events.size():
		var ev: Dictionary = events[i]
		if not _fired.has(i) and World.clock >= float(ev.at):
			_fired[i] = true
			fire(ev)
	for id in MEMOS:
		if int(MEMOS[id].day) == Campaign.day and not memos_done.has(id) and World.clock >= float(MEMOS[id].at):
			memo(str(id))
	if World.clock < World.DAY_END:
		_cap += Owner.team_speed() * dt
		_pick_t += dt
		if _pick_t >= 3.0:
			_pick_t = 0.0
			_pickup()
		_stuck_tick(dt)
		Crew.tick(dt)
		_aging(dt)
		_flag_t += dt
		if _flag_t >= 0.5:
			_flag_t = 0.0
			_flag_nodes()
	if not _walked and World.clock >= 14.0 and Campaign.day >= 2:
		_walked = true
		_walk_up()


func fire(ev: Dictionary) -> void:
	match str(ev.kind):
		"mail":
			Msp.mail(str(ev.from), str(ev.subject), str(ev.body))
		"memo":
			memo(str(ev.id))
		"beat":
			beat(str(ev.id))
		"incident":
			incident(str(ev.id), str(ev.book))
		"friday":
			friday()
		"design":
			if design == "":
				design_card()
		"hire":
			hire_card()


# ---- crew pick-up, first response, stuck -------------------------------------------------------------------------
func _crew_ticket(t: Dictionary) -> bool:
	return not (t.internal or str(t.special) != "" or str(t.fix) in ["project", "network"])


func _load_of(who: String) -> int:
	return Crew.load_of(who)


func _auto_takes(t: Dictionary) -> bool:
	match auto:
		"all":
			return true
		"low":
			return int(t.pri) >= 3
	return false


func _pickup() -> void:
	if Crew.names().is_empty():
		return
	var picked := 0
	for t in Msp.open_tickets():
		if not _crew_ticket(t):
			continue
		var id := int(t.id)
		if _seen.has(id):
			continue
		if str(t.status) != "New":
			_note_response(t, "Dan")  # you got there first
			continue
		if not _auto_takes(t):
			continue
		if picked >= pickup_cap():
			break
		var best := route_for(t)
		if best == "":
			continue  # nobody can take it now: it waits
		assign(id, best, false)
		picked += 1


func _note_response(t: Dictionary, _who: String) -> void:
	_seen[int(t.id)] = true
	_frt_sum += clampf((float(t.sla_total) - float(t.sla_left)) / maxf(1.0, float(t.sla_total)), 0.0, 1.0)
	_frt_n += 1


# ---- dispatch: who works what (C5) --------------------------------------------------------------------------------
# lane ids: "" = unassigned, a tech's name, "Dan" (you take it yourself), "ESC" = the owners' escalation lane
func lane_ids() -> Array:
	return [""] + board_techs() + ["Dan", "ESC"]


# who in the escalation lane should take it: Alan for the technical areas, Garrison for security and people
func owner_for(t: Dictionary) -> String:
	var pick: String = str(OWNER_AREAS.get(Crew.area_of(t), "Alan"))
	if int(owner_used[pick]) >= OWNER_DAY_CAP:
		pick = "Garrison" if pick == "Alan" else "Alan"
	return pick


func owner_free(who: String) -> bool:
	return int(owner_used.get(who, 99)) < OWNER_DAY_CAP


# move a ticket to a lane. Returns {ok, msg}. by_hand = you did it on the board (counts toward the career number)
func assign(id: int, who: String, by_hand := true) -> Dictionary:
	var t := Msp.ticket(id)
	if t.is_empty() or str(t.status) == "Closed":
		return {"ok": false, "msg": str(CREW_TEXT.msg.none)}
	if not _crew_ticket(t):
		return {"ok": false, "msg": str(CREW_TEXT.msg.not_desk)}
	if who == "ESC":
		who = owner_for(t)
	var from := Crew.assignee_of(t)
	if who == from:
		return {"ok": true, "msg": str(CREW_TEXT.msg.same), "same": true}
	if who in OWNERS:
		if not owner_free(who):
			return {"ok": false, "msg": str(CREW_TEXT.msg.busy) % who.to_upper()}
	elif who != "" and who != "Dan" and (not Crew.has(who) or Crew.is_gone(who)):
		return {"ok": false, "msg": str(CREW_TEXT.msg.gone)}
	elif Crew.is_shadowing(who):
		return {"ok": false, "msg": str(KB_TEXT.msg.shadow) % who.to_upper()}
	if Crew.stuck.has(from) and int(Crew.stuck[from].ticket) == id:
		Crew.free_stuck(from, "moved")
	t["assignee"] = who
	t["struggle"] = 0.0
	t.erase("pushed")
	if who == "":
		Msp.set_status(id, "New")
		Msp.add_note(id, "Back on the board, unassigned.")
	else:
		if str(t.status) != "In Progress":
			Msp.set_status(id, "In Progress")
		Msp.add_note(id, "Assigned to %s." % who)
		if not Owner._work.has(id):
			var mult := float(FOCUS[focus].head) if int(t.pri) <= 2 else 1.0
			Owner._work[id] = float(Owner.WORK[int(t.pri)]) * mult
		elif from != "" and from != who:
			Owner._work[id] = float(Owner._work[id]) + HANDOVER_COST
		if not _seen.has(id):
			_note_response(t, who)
	if who in OWNERS:
		owner_used[who] = int(owner_used[who]) + 1
		add_trust(who, -owner_cost())
		escalated += 1
	if by_hand:
		dispatched += 1
		_hand_day += 1
		Career.add("dispatched")
	return {"ok": true, "msg": str(CREW_TEXT.msg.assigned) % [id, lane_name(who)], "same": false}


func lane_name(who: String) -> String:
	if who == "":
		return str(CREW_TEXT.lanes.none)
	if who == "ESC":
		return str(CREW_TEXT.lanes.esc)
	return who.to_upper()


# a tech quit: his tickets go back on the board
func release_all(who: String) -> void:
	ByName.on_quit(who)  # R36: the clients that asked for him
	for t in Msp.tickets:
		if str(t.status) != "Closed" and Crew.assignee_of(t) == who:
			t["assignee"] = ""
			t["struggle"] = 0.0
			t.status = "New"
			t.notes.append("Back on the board: %s left." % who)
	Msp.changed.emit()


func cycle_auto() -> String:
	auto = POLICIES[(POLICIES.find(auto) + 1) % POLICIES.size()]
	return auto


# the crew gate in this mode (Owner._work_queue calls it): every tech works only what is on his desk
func work_queue(seconds: float) -> void:
	if seconds <= 0.0:
		return
	for t in Msp.open_tickets():
		if _crew_ticket(t) and bool(t.fix_done):
			Msp.close_ticket(int(t.id))
	var names := Crew.names()
	var total := Crew.skill()
	var team := Owner.team_speed() * seconds
	var mine := {}
	var cap := {}
	var idle_pool := 0.0
	var busy_speed := 0.0
	for who in names:
		var list := _desk_of(str(who))
		mine[who] = list
		var sp := Crew.worker_speed(str(who))
		cap[who] = team * sp / total if total > 0.0 else 0.0
		if list.is_empty():
			idle_pool += float(cap[who])
		else:
			busy_speed += sp
	for who in names:
		if not mine[who].is_empty() and busy_speed > 0.0:
			cap[who] = float(cap[who]) + idle_pool * assist_rate() * Crew.worker_speed(str(who)) / busy_speed
		_work_tech(str(who), mine[who], float(cap[who]), seconds)
	for o in OWNERS:
		_work_owner(o, _desk_of(o), seconds)


func _desk_of(who: String) -> Array:
	var out := []
	for t in Msp.open_tickets():
		if _crew_ticket(t) and Crew.assignee_of(t) == who and not bool(t.fix_done):
			out.append(t)
	return out


func _work_tech(who: String, list: Array, cap_units: float, seconds: float) -> void:
	if list.is_empty() or cap_units <= 0.0:
		return
	var time_left := seconds
	var base := cap_units / seconds
	for t in list:
		if time_left <= 0.001:
			break
		var id := int(t.id)
		var q := Crew.match_mult(who, t) * (0.6 if t.get("pushed", false) else 1.0)
		var rate := base * q
		var need := float(Owner._work.get(id, Owner.WORK[int(t.pri)]))
		var dt := minf(time_left, need / rate)
		var progress := dt * rate
		Owner.client_work[int(t.client)] = float(Owner.client_work.get(int(t.client), 0.0)) + progress
		Dash.add_hours(who, dt)
		need -= progress
		time_left -= dt
		Owner._work[id] = need
		if Crew.gap_of(who, t) >= 1 and not t.get("pushed", false):
			t["struggle"] = float(t.get("struggle", 0.0)) + dt
			if float(t.struggle) >= Crew.STUCK_AFTER and need > 0.0:
				_stall(who, t)
				return
		if need <= 0.0:
			_finish(who, t)


func _work_owner(who: String, list: Array, seconds: float) -> void:
	var left := OWNER_RATE * seconds
	for t in list:
		if left <= 0.0:
			break
		var id := int(t.id)
		var need := float(Owner._work.get(id, Owner.WORK[int(t.pri)]))
		var take := minf(need, left)
		left -= take
		need -= take
		Owner._work[id] = need
		if need <= 0.0:
			_finish(who, t)


func _finish(who: String, t: Dictionary) -> void:
	var id := int(t.id)
	Owner._work.erase(id)
	var miss := float(Owner.edge("close_miss"))
	if Crew.has(who):
		Crew.note_done(who, t)
		miss += Crew.reopen_add(who, t) + (0.15 if t.get("pushed", false) else 0.0)
	else:
		miss = 0.02
	t.erase("struggle")
	t.erase("pushed")
	if Difficulty.rng("service.work").randf() < clampf(miss, 0.0, 0.6):
		if Crew.has(who):
			Crew.note_reopen(who)
		Msp.close_ticket(id)  # closed too early: it comes back to the same desk
		return
	ByName.on_done(who, t)  # R36: a real close counts for his name at that client (a ticket that bounces does not)
	if Crew.has(who):
		kb.note_closed(who, t)
	Growth.owner_escalation(t)
	Msp.set_status(id, "In Progress")
	Msp.rmm_action(str(t.endpoint), str(t.fix))
	Msp.close_ticket(id)


func _stall(who: String, t: Dictionary) -> void:
	if Crew.stuck.has(who):
		return
	Crew.stuck[who] = {"ticket": int(t.id), "left": Crew.STUCK_GIVE_UP, "asked": false}
	Crew.members[who]["stalls"] = int(Crew.members[who].stalls) + 1
	Crew.add_stress(who, 3)
	Msp.send_text(who, str(CREW_TEXT.stuck.text) % [int(t.id), Crew.tag_of(t)])
	Hints.toast(str(CREW_TEXT.stuck.toast) % who.to_upper(), 2.5)


# a stuck tech waits for you; after a while he calls an owner (unless the policy is OFF), and in the end he pushes through alone
func _stuck_tick(dt: float) -> void:
	for who in Crew.stuck.keys():
		var s: Dictionary = Crew.stuck[who]
		var t := Msp.ticket(int(s.ticket))
		if t.is_empty() or str(t.status) == "Closed" or bool(t.fix_done):
			Crew.free_stuck(str(who), "closed")
			Social.change("Maya" if who == "Maya" else "Morgan", 1)
			Hints.toast(str(CREW_TEXT.stuck.thanks) % str(who).to_upper(), 2.5)
			continue
		if Crew.assignee_of(t) != who:
			Crew.free_stuck(str(who), "moved")
			continue
		s["left"] = float(s.left) - dt
		if not s.asked and Crew.STUCK_GIVE_UP - float(s.left) >= Crew.STUCK_ASK and auto != "off":
			s["asked"] = true
			var res := assign(int(t.id), "ESC", false)
			if res.ok:
				var o := Crew.assignee_of(Msp.ticket(int(t.id)))
				Hints.toast(str(CREW_TEXT.stuck.called) % [str(who).to_upper(), o.to_upper()], 3.0)
				_visit_owner(str(who), o)
				continue
		if float(s.left) <= 0.0:
			t["pushed"] = true
			t["struggle"] = 0.0
			Crew.stuck.erase(who)
			Crew.add_morale(str(who), -2)
			Crew.add_stress(str(who), 2)
			Msp.send_text(str(who), str(CREW_TEXT.stuck.alone))


func _visit_owner(who: String, owner_name: String) -> void:
	if World.chars.has(who) and str(World.chars[who].scene) == str(World.row(who).home):
		World.force_activity(who, "owner_" + owner_name.to_lower())


# unassigned P1 / P2 tickets age faster, and Garrison notices a P1 nobody took
func _aging(dt: float) -> void:
	for t in Msp.open_tickets():
		if not _crew_ticket(t) or Crew.assignee_of(t) != "" or int(t.pri) > 2:
			continue
		t.sla_left = float(t.sla_left) - 0.5 * dt
		t["waited"] = float(t.get("waited", 0.0)) + dt
		if int(t.pri) == 1 and float(t.waited) >= NEGLECT_AFTER and not t.get("noticed", false):
			t["noticed"] = true
			add_trust("Garrison", -1)
			Hints.toast(str(CREW_TEXT.neglect) % int(t.id), 3.0)


# bubbles over the heads of people who are stuck or buried
func _flag_nodes() -> void:
	for who in Crew.names(true):
		if not World.chars.has(who):
			continue
		var node = World.chars[who].node
		if node != null and is_instance_valid(node):
			node.flag_glyph = "" if Crew.is_gone(who) else Crew.glyph_of(who)


func _farewells() -> void:
	for who in Crew.farewells:
		var card: Dictionary = CREW_TEXT.farewell
		var opts := []
		for o in card.options:
			opts.append({"label": str(o.label), "id": str(o.id)})
		var name: String = who
		Cards.ask("%s (Tier 1)" % name, str(card.text) % name, opts, func(pick: String) -> void: _answer_farewell(name, pick))
	Crew.farewells = []


func _answer_farewell(who: String, pick: String) -> void:
	for o in CREW_TEXT.farewell.options:
		if str(o.id) == pick:
			apply_fx(o.fx.duplicate(true))
			Cards.ask("%s (Tier 1)" % who, str(o.reply), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)
			return


# today's numbers so far (the Dispatch SCORE tab; close_day uses the same formulas)
func today() -> Dictionary:
	var base: Dictionary = Campaign._base
	var closed := Msp.closed_ok - int(base.get("closed", 0))
	var missed := Msp.breached - int(base.get("missed", 0))
	var reopened := Msp.reopened - int(base.get("reopened", 0))
	var sla := 100 if closed + missed == 0 else int(round(100.0 * float(closed) / float(closed + missed)))
	var frac := _frt_sum / float(_frt_n) if _frt_n > 0 else 0.1
	return {"closed": closed, "missed": missed, "reopened": reopened, "sla": sla, "frt": frac * 200.0, "util": utilisation(), "open": Msp.open_tickets().size()}


# ---- cards ------------------------------------------------------------------------------------------------------
func _opts(list: Array) -> Array:
	var out := []
	for o in list:
		var entry: Dictionary = {"label": str(o.label), "id": str(o.id)}
		out.append(entry)
	return out


func memo(id: String) -> void:
	if not MEMOS.has(id) or memos_done.has(id):
		return
	memos_done[id] = true
	var m: Dictionary = MEMOS[id]
	Cards.ask(str(m.speaker), str(m.text), _opts(m.options), func(pick: String) -> void: answer_memo(id, pick))


func answer_memo(id: String, pick: String) -> void:
	var m: Dictionary = MEMOS[id]
	for o in m.options:
		if str(o.id) == pick:
			ServiceArc.note(id, pick)
			apply_fx(o.fx, _people_scale())
			Cards.ask(str(m.speaker), str(o.text), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)
			return


func beat(id: String) -> void:
	if not BEATS.has(id):
		return
	var b: Dictionary = BEATS[id]
	var options := []
	for o in b.options:
		var entry := {"label": str(o.label), "id": str(o.id)}
		if o.has("needs_mentored") and Crew.value("Maya", "mentored") < float(o.needs_mentored):
			entry["enabled"] = false
			entry["hint"] = "NEEDS MENTORING"
		options.append(entry)
	Cards.ask(str(b.speaker), ServiceArc.beat_text(id, str(b.text)), options, func(pick: String) -> void: answer_beat(id, pick))


func answer_beat(id: String, pick: String) -> void:
	var b: Dictionary = BEATS[id]
	for o in b.options:
		if str(o.id) == pick:
			ServiceArc.note(id, pick)
			apply_fx(o.fx, _people_scale())
			Cards.ask(str(b.speaker), str(o.text), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)
			return


func friday() -> void:
	var b: Dictionary = BEATS.friday
	var avg := "C"
	if not grades.is_empty():
		var total := 0
		var n := 0
		for g in grades.slice(maxi(0, grades.size() - 5)):
			total += int(RANK[str(g.grade)])
			n += 1
		var r := int(round(float(total) / float(maxi(1, n))))
		for k in RANK:
			if int(RANK[k]) == r:
				avg = str(k)
	var options := []
	for o in b.options:
		options.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(str(b.speaker), str(b.text) % [Campaign.rep, avg], options, func(pick: String) -> void: answer_beat("friday", pick))


# ---- incidents: take the Playbook job yourself, send Maya, or ask the owner -------------------------------------------
func incident(id: String, book: String) -> void:
	var inc: Dictionary = INCIDENTS[id]
	if Playbook.is_active():
		return
	var options := [
		{"label": str(INCIDENT_OPTIONS.take), "id": "take"},
		{"label": str(INCIDENT_OPTIONS.send), "id": "send"},
		{"label": "%s (%s)" % [str(INCIDENT_OPTIONS.ask), str(inc.owner).to_upper()], "id": "ask"},
	]
	Cards.ask(str(inc.speaker), str(inc.text), options, func(pick: String) -> void: run_incident(book, pick))


func run_incident(book: String, pick: String) -> void:
	var owner_name := str(INCIDENTS[book].owner) if INCIDENTS.has(book) else "Alan"
	match pick:
		"take":
			if book == "ransom":
				Story._ransomware()
			else:
				Playbook.start(book)
				Msp.send_text("Morgan", "A big job just came in. It is in your RMM, on the PROJECT tab.")
			flags["hands_" + book] = true
		"send":
			delegate(book, _maya_quality(), "Maya")
			Crew.add_morale("Maya", 2)
		"ask":
			delegate(book, 0.9, owner_name)
			add_trust(owner_name, 3)
			add_trust("Garrison" if owner_name == "Alan" else "Alan", -2)


func _maya_quality() -> float:
	return clampf(0.3 + 0.004 * float(Crew.morale("Maya")) + 0.04 * Crew.value("Maya", "mentored") + (Crew.value("Maya", "skill") - 1.0), 0.3, 0.85)


# run a Playbook job without you: each step takes the best unlocked choice with chance `quality`, else another one
func delegate(book: String, quality: float, who: String) -> Dictionary:
	quality = clampf(quality + kb.job_bonus(book), 0.0, 0.97)  # a runbook for the job helps whoever runs it
	if book == "ransom":
		return _delegate_ransom(quality, who)
	var clock: float = World.clock
	var rng: RandomNumberGenerator = Difficulty.rng("service.jobs")
	Playbook.start(book)
	var guard := 0
	while Playbook.is_active() and guard < 12:
		guard += 1
		var step: Dictionary = Playbook.current_step()
		var open: Array = []
		var best := -1
		var best_pts := -1
		for i in step.choices.size():
			var ch: Dictionary = step.choices[i]
			if Playbook.lock_reason(ch) != "":
				continue
			open.append(i)
			if int(ch.pts) > best_pts:
				best_pts = int(ch.pts)
				best = i
		if open.is_empty():
			break
		var idx: int = best
		if rng.randf() >= quality and open.size() > 1:
			var others: Array = open.duplicate()
			others.erase(best)
			idx = others[rng.randi() % others.size()]
		Playbook.choose(idx)
	World.clock = clock
	var res: Dictionary = Playbook.active.get("result", {})
	flags["job_" + book] = str(res.get("grade", "C"))
	Msp.send_text("Morgan", "%s finished the job: grade %s." % [who, str(res.get("grade", "C"))])
	ServiceArc.job_done_check()
	return res


func _delegate_ransom(quality: float, who: String) -> Dictionary:
	Story._ransomware()
	var tid := int(Story.flags.get("ransom_ticket", 0))
	var t: Dictionary = Msp.ticket(tid)
	if t.is_empty():
		return {}
	var ep: Dictionary = Msp.endpoint(str(t.endpoint))
	var rng: RandomNumberGenerator = Difficulty.rng("service.jobs")
	if bool(Msp.backups[Story.RANSOM_CLIENT].ok):
		Msp.rmm_action(str(t.endpoint), "restore")
	else:
		Msp._restore(ep)  # records the failed restore, like a first try
		if rng.randf() < 0.4 + 0.3 * quality:
			Msp._ransom_shadow(ep)
		if str(Story.flags.get("ransom", "")) not in ["partial", "paid", "lost"]:
			Msp._ransom_shadow(ep)
		if str(Story.flags.get("ransom", "")) not in ["partial", "paid", "lost"]:
			if rng.randf() < 0.5:
				Msp._ransom_pay(ep)
			else:
				Msp._ransom_lost(ep, "Gave up on the files. Data lost.")
	t.fix_done = true
	Msp.close_ticket(tid)
	flags["job_ransom"] = str(Story.flags.get("ransom", ""))
	Msp.send_text("Morgan", "%s handled Hoot and Holler: %s." % [who, str(Story.flags.get("ransom", "")).to_upper()])
	return {"grade": str(Story.flags.get("ransom", ""))}


# ---- 1:1s ------------------------------------------------------------------------------------------------------
func has_one_on_one(who: String) -> bool:
	return Campaign.mode == "service" and (who == "Maya" or who == "John" or Crew.has(who))


func _deck_of(who: String) -> String:
	return who if who == "Maya" or who == "John" else "Tech"


# C7: the order a run deals a deck in. Seeded by the run (the same run keeps its order through a save, another run gets another
# one); `oto_seen[deck]` counts how many of it have been dealt, so no card comes twice until the deck is used up
func oto_order(deck_id: String) -> Array:
	var order := []
	for i in ONE_ON_ONES[deck_id].size():
		order.append(i)
	Difficulty.shuffle_with(order, Difficulty.rng_for("service.oto", hash(deck_id)))
	return order


# cards of the deck this run has not seen yet
func oto_left(deck_id: String) -> int:
	return maxi(0, ONE_ON_ONES[deck_id].size() - int(oto_seen.get(deck_id, 0)))


func one_on_one(who: String, after := Callable()) -> void:
	var label := Roles.label(who) if who == "Maya" or who == "John" else "%s (Tier 1)" % who
	if int(oto_day.get(who, -1)) == Campaign.day:
		Cards.ask(label, str(ONE_TEXT.already), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: _call(after))
		return
	oto_day[who] = Campaign.day
	if Crew.has(who):
		Crew.members[who]["last_oto"] = Campaign.day
	var deck_id := _deck_of(who)
	var deck: Array = ONE_ON_ONES[deck_id]
	var used := int(oto_seen.get(deck_id, 0))
	if used >= deck.size():
		# C7: every card of the deck has been dealt in this run and none comes twice: a short check-in instead
		oto_log.append([deck_id, -1])
		if Crew.has(who):
			apply_fx({"morale_who": {who: OTO_QUIET_MORALE}}, _people_scale())
		Cards.ask(label, str(ONE_TEXT.quiet), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: _call(after))
		return
	oto_seen[deck_id] = used + 1
	var at := int(oto_order(deck_id)[used])
	oto_log.append([deck_id, at])
	var card: Dictionary = deck[at]
	var options := []
	for i in card.options.size():
		options.append({"label": str(card.options[i].label), "id": str(i)})
	Cards.ask(label, str(card.text).replace("{name}", who), options, func(pick: String) -> void: _answer_oto(who, label, card, int(pick), after))


func _answer_oto(who: String, label: String, card: Dictionary, pick: int, after: Callable) -> void:
	var o: Dictionary = card.options[pick]
	var fx: Dictionary = o.fx.duplicate(true)
	# a one-name morale / retain effect goes to the person you are talking to
	if Crew.has(who):
		if fx.has("morale"):
			fx["morale_who"] = {who: int(fx.morale)}
			fx.erase("morale")
		if fx.has("retain"):
			fx["retain"] = {who: int(fx.retain)}
		_skill_fx(who, fx)
	elif fx.has("morale"):
		Crew.add_all(int(fx.morale))
		fx.erase("morale")
	apply_fx(fx, _people_scale())
	Cards.ask(label, str(o.reply), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: _call(after))


func _call(cb: Callable) -> void:
	if cb.is_valid():
		cb.call()


# somebody walks up to your desk in the afternoon: the tech who has not had a 1:1 for the longest
func _walk_up() -> void:
	var who := ""
	for n in Crew.names():
		if n == "Maya":
			continue
		var last := int(Crew.value(str(n), "last_oto"))
		if Campaign.day - last >= 3 and (who == "" or last < int(Crew.value(who, "last_oto"))) and oto_left(_deck_of(str(n))) > 0:
			who = str(n)
	if who == "":
		return
	Hints.toast(str(ONE_TEXT.walkup) % who.to_upper(), 3.0)
	one_on_one(who)


# ---- the scorecard ----------------------------------------------------------------------------------------------
func utilisation() -> float:
	if _cap <= 0.0:
		return 0.0
	return clampf((_client_work() - _work_base) / _cap, 0.0, 1.0)


func close_day(r: Dictionary) -> void:
	var closed := int(r.closed)
	var missed := int(r.missed)
	var reopened := int(r.reopened)
	var open_left := int(r.open_left)
	var sla := 100 if closed + missed == 0 else int(round(100.0 * float(closed) / float(closed + missed)))
	var fcr := 100 if closed + reopened == 0 else int(round(100.0 * (1.0 - float(reopened) / float(closed + reopened))))
	var frac := _frt_sum / float(_frt_n) if _frt_n > 0 else 0.1
	var frt_secs := frac * 200.0
	var util := utilisation()
	var morale := Crew.morale_avg()
	var mood := int(r.clients)
	var backlog := 10 if open_left == 0 else (7 if open_left <= 2 else (4 if open_left <= 4 else 0))
	var band := 10 if util >= 0.6 and util <= 0.9 else (6 if util >= 0.45 and util <= 1.0 else 2)
	var score := 35.0 * float(sla) / 100.0 + 20.0 * float(fcr) / 100.0
	score += 15.0 * (1.0 - clampf((frac - 0.1) / 0.4, 0.0, 1.0)) + float(backlog) + float(band) + float(morale) / 10.0
	var grade := "D"
	for entry in [[90.0, "S"], [78.0, "A"], [62.0, "B"], [45.0, "C"]]:
		if score >= float(entry[0]):
			grade = str(entry[1])
			break
	var delta: int = {"S": 2, "A": 1, "B": 0, "C": -2, "D": -4}[grade]
	if grade in ["S", "A"] and trust_of("Alan") >= 60 and trust_of("Garrison") >= 60:
		delta += 1
	if trust_of("Alan") < 25 or trust_of("Garrison") < 25:
		delta -= 1
	delta += ServiceArc.friday_delta()
	var out_notes: Array = []
	# end-of-day bookkeeping: the day's focus, the crew's mood, quits, the owners' drift
	if focus == "mentor":
		Crew.mentor("Maya")
	if focus == "project":
		project_days += 1
	_training_day()
	ServiceArc.silence()
	var gone: Array = Crew.end_day(util, grade)
	for who in gone:
		out_notes.append("%s QUIT" % str(who).to_upper())
		Msp.mail("Pixel IT Partners - Manager", "%s resigned" % who, "%s handed in a notice this evening. - Morgan" % who)
	for who in leaving:
		if Crew.has(who) and not Crew.is_gone(who):
			Crew.quit(who)
			Crew.farewells.append(who)
			out_notes.append("%s QUIT" % str(who).to_upper())
	leaving = []
	for who in Crew.onboard_pending(Campaign.day):
		out_notes.append("%s JOINS" % str(who).to_upper())
	crew_changed()
	_owner_day()
	if grade == "S":
		add_trust("Alan", 1)
		add_trust("Garrison", 1)
	elif grade == "D":
		add_trust("Alan", -1)
		add_trust("Garrison", -1)
	var both_low := trust_of("Alan") < FAIL_TRUST and trust_of("Garrison") < FAIL_TRUST and not Difficulty.cozy_on()
	if both_low:
		delta = -Campaign.rep
		r["fired_text"] = str(ServiceArc.TEXT.fired_owners)
	grades.append({"day": Campaign.day, "grade": grade, "score": int(round(score)), "util": int(round(util * 100.0)), "sla": sla})
	var mood_col := DayReport.GOOD if mood >= 70 else (DayReport.BAD if mood < 40 else DayReport.WARN)
	var morale_col := DayReport.GOOD if morale >= 65 else (DayReport.BAD if morale < 40 else DayReport.WARN)
	var sla_col := DayReport.GOOD if sla >= 90 else (DayReport.BAD if sla < 70 else DayReport.WARN)
	var util_col := DayReport.GOOD if band >= 10 else (DayReport.WARN if band >= 6 else DayReport.BAD)
	var scorecard := [
		["FIRST RESPONSE", Msp.mmss(frt_secs), DayReport.GOOD if frac < 0.2 else (DayReport.BAD if frac > 0.45 else DayReport.WARN)],
		["SLA KEPT", "%d%%" % sla, sla_col],
		["TICKETS CLOSED", str(closed), DayReport.GOOD if closed > 0 else DayReport.WHITE],
		["REOPENS", str(reopened), DayReport.BAD if reopened > 0 else DayReport.GOOD],
		["UTILISATION", "%d%%" % int(round(util * 100.0)), util_col],
	]
	var people := [
		["TECH MORALE", "%d%%" % morale, morale_col],
		["CLIENT MOOD", "%d%%" % mood, mood_col],
		["FOCUS", str(HUDDLE.options[focus].label), DayReport.WHITE],
		["DISPATCHED", "%d BY HAND, %d TO OWNERS" % [_hand_day, int(owner_used.Alan) + int(owner_used.Garrison)], DayReport.WHITE],
	]
	var owners := [
		["ALAN TRUST", "%d  %s" % [trust_of("Alan"), trust_word(trust_of("Alan"))], _trust_col(trust_of("Alan"))],
		["GARRISON TRUST", "%d  %s" % [trust_of("Garrison"), trust_word(trust_of("Garrison"))], _trust_col(trust_of("Garrison"))],
	]
	for row in ServiceArc.report_rows():
		owners.append(row)
	if not out_notes.is_empty():
		people.append(["CREW", " ".join(out_notes), DayReport.BAD])
	r["groups"] = [["SCORECARD", scorecard], ["TEAM", people], ["OWNERS", owners]]
	r["left_groups"] = [["DESK", _desk_rows()]]
	r["title"] = "DAY %d SCORECARD" % Campaign.day
	r["grade"] = grade
	r["points"] = int(round(score))
	r["pay"] = 0
	r["rep_delta"] = delta
	r["rep_name"] = "CONFIDENCE"
	r["rep_short"] = "CONF"
	r["score_detail"] = {"sla": sla, "fcr": fcr, "frt": frt_secs, "util": util, "morale": morale, "backlog": backlog}
	r["trust"] = trust.duplicate()


func _trust_col(v: int) -> Color:
	return DayReport.GOOD if v >= 60 else (DayReport.BAD if v < 30 else DayReport.WARN)


# ---- endings (Review) -------------------------------------------------------------------------------------------
func review_offers() -> Array:
	var out := []
	var ta := trust_of("Alan")
	var tg := trust_of("Garrison")
	if ta >= 55 and tg >= 55 and Campaign.rep >= 60:
		out.append({"id": "ops", "label": str(REVIEW.endings.ops.label), "desc": str(REVIEW.endings.ops.desc)})
	if ta >= 55 and ta >= tg and Campaign.rep >= 60:
		out.append({"id": "alan", "label": str(REVIEW.endings.alan.label), "desc": str(REVIEW.endings.alan.desc)})
	if tg >= 55 and tg >= ta and Campaign.rep >= 60:
		out.append({"id": "garrison", "label": str(REVIEW.endings.garrison.label), "desc": str(REVIEW.endings.garrison.desc)})
	if Campaign.rep >= 45:
		out.append({"id": "leave", "label": str(REVIEW.endings.leave.label), "desc": str(REVIEW.endings.leave.desc)})
		out.append_array(ServiceArc.extra_offers())
	out.append({"id": "stay", "label": str(REVIEW.endings.stay.label), "desc": str(REVIEW.endings.stay.desc)})
	return out


func _quote(key: String, v: int) -> String:
	var q: Dictionary = REVIEW.quotes[key]
	return str(q.high if v >= 60 else (q.mid if v >= 35 else q.low))


func review_lines(page: int, ending: String) -> Array:
	var blue: Color = Review.BLUE
	var ink: Color = Review.INK
	var lines := []
	match page:
		0:
			lines.append(["MORGAN REYES - MANAGER", blue])
			lines.append(["TWENTY DAYS AT THE DESK. LET'S LOOK AT THE NUMBERS.", ink])
			lines.append(["CONFIDENCE %d   CREW MORALE %d   CLIENT MOOD %d" % [Campaign.rep, Crew.morale_avg(), int(Sales.average())], ink])
			lines.append(["CLOSED %d   SLA MISSED %d   REOPENED %d" % [Msp.closed_ok, Msp.breached, Msp.reopened], ink])
			var count := {"S": 0, "A": 0, "B": 0, "C": 0, "D": 0}
			for g in grades:
				count[str(g.grade)] = int(count[str(g.grade)]) + 1
			lines.append(["DAYS: S %d  A %d  B %d  C %d  D %d" % [count.S, count.A, count.B, count.C, count.D], ink])
			lines.append(["TRUST: ALAN %d (%s)  GARRISON %d (%s)" % [trust_of("Alan"), trust_word(trust_of("Alan")), trust_of("Garrison"), trust_word(trust_of("Garrison"))], ink])
			lines.append(["DESK: %s   DOCUMENTED %d%%   RETENTION %d%%" % [design_label(), kb.doc_pct(), Crew.retention_pct()], ink])
			for key in ["rdp", "ransom", "rack", "email24", "migration", "onboard"]:
				var grade := str(flags.get("job_" + key, Story.flags.get(key, "")))
				if grade != "":
					lines.append(["%s: %s" % [str(INCIDENTS[key].title), grade.to_upper()], Review.BAD if grade in ["D", "lost"] else ink, "job"])
		1:
			lines.append(["WHAT THE OWNERS AND YOUR TEAM SAY", blue])
			lines.append(["ALAN, CO-OWNER (%s):" % trust_word(trust_of("Alan")), blue])
			lines.append(["'%s'" % _quote("Alan", trust_of("Alan")), ink])
			lines.append(["GARRISON, CO-OWNER (%s):" % trust_word(trust_of("Garrison")), blue])
			lines.append(["'%s'" % _quote("Garrison", trust_of("Garrison")), ink])
			lines.append(["YOUR TEAM:", blue])
			lines.append(["'%s'" % _quote("crew", Crew.morale_avg()), ink])
			lines.append_array(ServiceArc.audit_lines(blue, ink))
		2:
			lines.append(["YOUR OPTIONS", blue])
		_:
			lines.append(["THE END", blue])
			lines.append([str(REVIEW.endings[ending].text) if REVIEW.endings.has(ending) else Yeartwo.ending_text(ending), ink])
	return lines


# ---- C6 (V3): desk design, hiring for fit, onboarding, retention events, owner reactions --------------------------------
func manager_hours_total() -> float:
	return 3.0 + (2.0 if dispatcher else 0.0)


func weekly_cost() -> int:
	var total := Crew.payroll_week()
	if dispatcher:
		total += DISPATCHER_WAGE
	total += int(TRAINING[training].cost)
	total += ServiceArc.oncall_cost()
	if design == "pods":
		total += POD_STIPEND * Crew.size()
	return total


# dollars a ticket: a day of the payroll, the training and any one-off spend, over the tickets closed today
func cost_per_ticket() -> int:
	var closed: int = Msp.closed_ok - int(Campaign._base.get("closed", 0))
	if closed <= 0:
		return -1  # nothing closed yet today
	return int(round((float(weekly_cost()) / 5.0 + spent_today) / float(closed)))


func design_label() -> String:
	return str(DESIGNS[design].label) if DESIGNS.has(design) else str(ROWS.none)


func lane_of(who: String) -> String:
	return str(Crew.members.get(who, {}).get("lane", "L1"))


# the small tag on a board lane head: L1 / L2 on a tiered desk, L3 for the owners, POD / ALL on the others
func lane_tag(id: String) -> String:
	match design:
		"tiered":
			if id == "ESC":
				return "L3"
			return lane_of(id) if Crew.has(id) else ""
		"swarm":
			return "ALL" if Crew.has(id) else ""
		"pods":
			return "POD" if Crew.has(id) else ""
	return ""


# the clients in a tech's pod, as short names
func pod_of(who: String) -> Array:
	var out := []
	for c in pods:
		if str(pods[c]) == who:
			out.append(int(c))
	out.sort()
	return out


func pod_text(who: String) -> String:
	var parts := []
	for c in pod_of(who):
		parts.append(str(Msp.CLIENTS[int(c)].short))
	return " ".join(parts)


# sort the techs so a tiered board reads L1 then L2
func board_techs() -> Array:
	var techs: Array = Crew.names()
	if design == "tiered":
		techs.sort_custom(func(a, b) -> bool: return lane_of(str(a)) < lane_of(str(b)))
	return techs


func rebuild_pods() -> void:
	var techs := []
	for n in Crew.names():
		if not Crew.is_shadowing(str(n)):
			techs.append(str(n))
	var clients: Array = Sales.active.duplicate()
	clients.sort()
	var keep := {}
	for c in clients:
		var owner_name := str(pods.get(int(c), ""))
		if techs.has(owner_name):
			keep[int(c)] = owner_name
	var count := {}
	for t in techs:
		count[t] = 0
	for c in keep:
		count[keep[c]] = int(count[keep[c]]) + 1
	for c in clients:
		if keep.has(int(c)) or techs.is_empty():
			continue
		var best := str(techs[0])
		for t in techs:
			if int(count[t]) < int(count[best]):
				best = str(t)
		keep[int(c)] = best
		count[best] = int(count[best]) + 1
		pod_days[int(c)] = 0  # a new face: the deep knowledge starts again
	pods = keep


# a tech quit, was hired or changed lane: the pods follow
func crew_changed() -> void:
	if design == "pods":
		rebuild_pods()


func pickup_cap() -> int:
	return 2 if (design == "" or dispatcher) else 1


func _in_lane(who: String, t: Dictionary) -> bool:
	return lane_of(who) == ("L1" if Crew.need_of(t) <= 1 else "L2")


func design_speed(who: String, t: Dictionary) -> float:
	match design:
		"tiered":
			return (1.04 if _in_lane(who, t) else 0.92) * (1.04 if dispatcher else 1.0)
		"swarm":
			return 1.06
		"pods":
			if str(pods.get(int(t.client), "")) == who:
				return 1.0 + minf(0.12, 0.03 * float(pod_days.get(int(t.client), 0)))
			return 0.95
	return 1.0


func design_reopen(who: String, t: Dictionary) -> float:
	match design:
		"tiered":
			return -0.02 if _in_lane(who, t) else 0.02
		"swarm":
			return 0.03
		"pods":
			return -0.03 if str(pods.get(int(t.client), "")) == who else 0.01
	return 0.0


func assist_rate() -> float:
	match design:
		"tiered":
			return ASSIST * 0.8
		"swarm":
			return ASSIST * 1.2
		"pods":
			return ASSIST * 0.5
	return ASSIST


func _best_in(t: Dictionary, lane_filter: String, max_load: int) -> String:
	var best := ""
	var best_fit := -1.0
	for who in Crew.names():
		var w := str(who)
		if Crew.stuck.has(w) or Crew.is_shadowing(w) or Crew.load_of(w) >= max_load:
			continue
		if lane_filter != "" and lane_of(w) != lane_filter:
			continue
		var f := Crew.fit(w, t)
		if f > best_fit + 0.0001:
			best_fit = f
			best = w
	return best


# who the autopilot gives a ticket to under the chosen design ("" = nobody can take it now)
func route_for(t: Dictionary) -> String:
	var asked: String = ByName.route(t)  # R36: the tech they asked for takes it, even with a full desk
	if asked != "":
		return asked
	match design:
		"tiered":
			var want := "L1" if Crew.need_of(t) <= 1 else "L2"
			var best := _best_in(t, want, 2)
			if best == "" and int(t.pri) <= 2:
				best = _best_in(t, "L2" if want == "L1" else "L1", 1)  # a hot ticket may cross lanes into an idle desk
			return best
		"swarm":
			var base := _best_in(t, "", 3)
			var odds := 0.08 if dispatcher else 0.16
			if base != "" and Difficulty.rng("service.swarm").randf() < odds:
				var open := []
				for who in Crew.names():
					if not Crew.stuck.has(who) and not Crew.is_shadowing(str(who)) and Crew.load_of(str(who)) < 3 and who != base:
						open.append(str(who))
				if not open.is_empty():
					misallocated += 1
					return str(open[Difficulty.rng("service.swarm").randi() % open.size()])
			return base
		"pods":
			var owner_name := str(pods.get(int(t.client), ""))
			if Crew.has(owner_name) and not Crew.is_gone(owner_name) and not Crew.stuck.has(owner_name) and not Crew.is_shadowing(owner_name) and Crew.load_of(owner_name) < 3:
				return owner_name
			return ""
	return Crew.best_for(t, 2)


func can_change_design() -> bool:
	return design != "" and design_changes < 1 and kb.hours_left() >= 2.0


# choose (or change) the desk design. Returns {ok, msg}. `revisit` costs 2 manager hours, crew morale and a little trust, once.
func apply_design(kind: String, with_dispatcher: bool, revisit := false) -> Dictionary:
	if not DESIGNS.has(kind) or not kind in DESIGN_ORDER:
		return {"ok": false, "msg": ""}
	if revisit:
		if design_changes >= 1:
			return {"ok": false, "msg": str(DESIGNS.card.used)}
		if not kb.spend(2.0):
			return {"ok": false, "msg": str(DESIGNS.card.no_hours)}
		design_changes += 1
		Crew.add_all(-3)
		add_trust("Alan", -1)
		add_trust("Garrison", -1)
		buffs.append({"key": "speed", "val": 0.9, "left": 1})
	var was_dispatcher := dispatcher
	design = kind
	dispatcher = with_dispatcher
	design_day = Campaign.day
	if with_dispatcher != was_dispatcher or not revisit:
		for who in DESIGNS.dispatcher["hire" if with_dispatcher else "you"].trust:
			add_trust(str(who), int(DESIGNS.dispatcher["hire" if with_dispatcher else "you"].trust[who]))
	var d: Dictionary = DESIGNS[kind]
	for who in d.trust:
		add_trust(str(who), int(d.trust[who]))
	for who in d.mail:
		var m: Array = d.mail[who]
		Msp.mail(str(m[0]), str(m[1]), str(m[2]))
	pods = {}
	pod_days = {}
	if kind == "pods":
		rebuild_pods()
	for n in Crew.names():  # a tiered desk sorts the crew into lanes by skill
		if kind == "tiered" and not Crew.is_hire(str(n)):
			Crew.members[n]["lane"] = str(Crew.START_LANE.get(str(n), "L1"))
	_sync()
	Hints.toast(str(DESIGNS.card.changed) % str(d.label), 3.0)
	return {"ok": true, "msg": str(DESIGNS.card.changed) % str(d.label)}


func design_card(revisit := false) -> void:
	if revisit and not can_change_design():
		return
	var tx: Dictionary = DESIGNS.card
	var opts := []
	for id in DESIGN_ORDER:
		var o := {"label": str(DESIGNS[id].option), "id": id}
		if revisit and id == design:
			o["enabled"] = false
			o["hint"] = "CURRENT"
		opts.append(o)
	if revisit:
		opts.append({"label": str(tx.keep), "id": "keep"})
	Cards.ask(str(tx.speaker), str(tx.revisit) if revisit else str(tx.text), opts, func(pick: String) -> void: _design_picked(pick, revisit))


func _design_picked(pick: String, revisit: bool) -> void:
	if pick == "keep" or not pick in DESIGN_ORDER:
		return
	var tx: Dictionary = DESIGNS.card
	var opts := [{"label": str(tx.you), "id": "you"}, {"label": str(tx.hire), "id": "hire"}]
	Cards.ask(str(tx.speaker), str(tx.dispatcher), opts, func(p: String) -> void: _finish_design(pick, p == "hire", revisit))


func _finish_design(kind: String, with_dispatcher: bool, revisit: bool) -> void:
	var res := apply_design(kind, with_dispatcher, revisit)
	if not res.ok:
		Hints.toast(str(res.msg), 3.0)
		return
	var d: Dictionary = DESIGNS[kind]
	Cards.ask(str(DESIGNS.card.speaker), str(DESIGNS.card.done) % [str(d.label), str(d.note)], [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)


# ---- hiring: three candidates, an interview mini-step, a choice, an onboarding path ------------------------------------
func hire_card() -> void:
	if not Crew.can_hire():
		Hints.toast(str(HIRE_TEXT.full), 3.0)
		return
	cands = Crew.make_candidates(3)
	interviewed = {}
	_hire_list()


func _cand_line(c: Dictionary) -> String:
	var s := str(HIRE_TEXT.line) % [str(c.name).to_upper(), str(c.area).to_upper(), int(c.wage), str(HIRE_TEXT.trait_short.get(str(c.trait), "STEADY"))]
	if interviewed.has(str(c.name)):
		var f: Dictionary = c.fit
		s += str(HIRE_TEXT.revealed) % [float(c.skill), int(f.culture), int(f.comm), int(f.curiosity)]
	else:
		s += str(HIRE_TEXT.hidden)
	return s


func _hire_list() -> void:
	var lines := [str(HIRE_TEXT.intro) % kb.hours_left(), str(HIRE_TEXT.fit_key)]
	for c in cands:
		lines.append(_cand_line(c))
	var opts := []
	for i in cands.size():
		if interviewed.has(str(cands[i].name)):
			continue
		var o := {"label": str(HIRE_TEXT.interview) % str(cands[i].name).to_upper(), "id": "i%d" % i}
		if kb.hours_left() < 1.0:
			o["enabled"] = false
			o["hint"] = str(HIRE_TEXT.no_hours)
		opts.append(o)
	opts.append({"label": str(HIRE_TEXT.decide), "id": "decide"})
	Cards.ask("Morgan Reyes - Manager", "\n".join(lines), opts, func(pick: String) -> void: _hire_pick(pick))


func _hire_pick(pick: String) -> void:
	if pick.begins_with("i"):
		interview(int(pick.substr(1)))
	else:
		_hire_decide()


# the interview: a technical question then a behavioural one; they reveal skill and fit. Costs an hour.
func interview(i: int) -> bool:
	if i < 0 or i >= cands.size() or interviewed.has(str(cands[i].name)):
		return false
	if not kb.spend(1.0):
		Hints.toast(str(KB_TEXT.msg.need) % [1.0, kb.hours_left()], 3.0)
		return false
	var c: Dictionary = cands[i]
	interviewed[str(c.name)] = true
	var band := "strong" if float(c.skill) >= 1.0 else ("ok" if float(c.skill) >= 0.75 else "weak")
	var q := str(HIRE_TEXT.tech_q[str(c.area)]) if HIRE_TEXT.tech_q.has(str(c.area)) else str(HIRE_TEXT.tech_q.servers)
	var ans := str(HIRE_TEXT.tech_a[band]) % str(c.name)
	Cards.ask(str(c.name), "%s\n%s" % [q, ans], [{"label": str(HIRE_TEXT.tech_next), "id": "n"}], func(_x: String) -> void: _interview_b(c))
	return true


func _interview_b(c: Dictionary) -> void:
	var cul := int(c.fit.culture)
	var band := "high" if cul >= 4 else ("mid" if cul == 3 else "low")
	var ans := str(HIRE_TEXT.behave_a[band]) % str(c.name)
	Cards.ask(str(c.name), "%s\n%s" % [str(HIRE_TEXT.behave_q), ans], [{"label": str(HIRE_TEXT.summary), "id": "n"}], func(_x: String) -> void: _hire_list())


func _hire_decide() -> void:
	var lines := [str(HIRE_TEXT.decide_text)]
	var opts := []
	for i in cands.size():
		lines.append(_cand_line(cands[i]))
		opts.append({"label": str(HIRE_TEXT.hire) % str(cands[i].name).to_upper(), "id": "h%d" % i})
	opts.append({"label": str(HIRE_TEXT.none), "id": "none"})
	Cards.ask("Morgan Reyes - Manager", "\n".join(lines), opts, func(pick: String) -> void: _hire_chosen(pick))


func _hire_chosen(pick: String) -> void:
	if pick == "none" or not pick.begins_with("h"):
		_owner_react("none")
		return
	var c: Dictionary = cands[int(pick.substr(1))]
	var opts := [
		{"label": str(HIRE_TEXT.onboard.shadow), "id": "shadow"},
		{"label": str(HIRE_TEXT.onboard.structured), "id": "structured"},
	]
	if kb.hours_left() < 2.0:
		opts[1]["enabled"] = false
		opts[1]["hint"] = str(HIRE_TEXT.onboard.hint)
	Cards.ask("Morgan Reyes - Manager", str(HIRE_TEXT.onboard.text) % str(c.name), opts, func(path: String) -> void: finish_hire(c, path))


# the hire is made: starts tomorrow, the owners react, the onboarding path is set. Public for tests.
func finish_hire(c: Dictionary, path: String) -> bool:
	if not Crew.can_hire():
		return false
	if path == "structured" and not kb.spend(2.0):
		path = "shadow"
	Crew.hire(c, path)
	Msp.mail(str(HIRE_TEXT.welcome.from), str(HIRE_TEXT.welcome.subject) % str(c.name), str(HIRE_TEXT.welcome.body) % str(c.name))
	Hints.toast(str(HIRE_TEXT.onboard[path + "_done"]) % str(c.name), 3.0)
	_owner_react(str(c.kind))
	return true


func _owner_react(kind: String) -> void:
	var r: Dictionary = HIRE_TEXT.react[kind]
	for who in r.trust:
		add_trust(str(who), int(r.trust[who]))
	flags["hire_" + kind] = true
	Hints.toast(str(r.text), 3.5)


# ---- retention: crew life events fed by morale and workload ------------------------------------------------------------
func _ret_who(id: String) -> String:
	var best := ""
	var best_v := -1.0
	for n in Crew.names():
		var w := str(n)
		if Crew.is_shadowing(w):
			continue
		var v := -1.0
		match id:
			"counter":
				if Crew.morale(w) < 62 and Crew.value(w, "skill") >= 0.85:
					v = Crew.value(w, "skill")
			"training":
				if training == "none" and (Crew.fit_avg(w) >= 3.5 or Campaign.day >= 8):
					v = float(Crew.members[w].get("fit", {}).get("curiosity", 3)) + 0.01 * float(Crew.value(w, "done"))
			"burnout":
				if int(Crew.value(w, "over_days")) >= 2 or Crew.value(w, "stress") >= 70.0:
					v = Crew.value(w, "stress") + 10.0 * Crew.value(w, "over_days")
			"promotion":
				if Crew.value(w, "done") >= 6 and Crew.value(w, "skill") >= 0.95 and lane_of(w) == "L1" and Crew.morale(w) >= 50:
					v = Crew.value(w, "skill")
				elif flags.get("graduated", "") == w and not flags.get("promoted_" + w, false):
					v = 5.0
			"resign":
				if Crew.morale(w) <= 38 and Campaign.day - int(Crew.value(w, "last_oto")) >= 4:
					v = 100.0 - float(Crew.morale(w))
		if v > best_v:
			best_v = v
			best = w
	return best if best_v >= 0.0 else ""


# the life event due this morning ({id, who}), or {} if none. Deterministic from the state.
func retention_due() -> Dictionary:
	if Campaign.day < 4 or Campaign.day - last_event_day < RET_COOLDOWN:
		return {}
	for id in RETENTION_ORDER:
		var ev: Dictionary = RETENTION[id]
		if Campaign.day < int(ev.min_day) or Campaign.day - int(event_days.get(id, -99)) < int(ev.cool):
			continue
		var who := _ret_who(id)
		if who != "":
			return {"id": id, "who": who}
	return {}


func retention_event() -> bool:
	var due := retention_due()
	if due.is_empty():
		return false
	fire_retention(str(due.id), str(due.who))
	return true


func fire_retention(id: String, who: String) -> void:
	var ev: Dictionary = RETENTION[id]
	last_event_day = Campaign.day
	event_days[id] = Campaign.day
	events_fired.append("%s:%s:%d" % [id, who, Campaign.day])
	var opts := []
	for o in ev.options:
		opts.append({"label": str(o.label), "id": str(o.id)})
	Cards.ask(str(ev.speaker) % who, str(ev.text) % who, opts, func(pick: String) -> void: answer_retention(id, who, pick))


func answer_retention(id: String, who: String, pick: String) -> void:
	for o in RETENTION[id].options:
		if str(o.id) == pick:
			_ret_fx(who, o.fx.duplicate(true))
			Cards.ask("%s (Tier 1)" % who, str(o.reply), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)
			return


func _ret_fx(who: String, fx: Dictionary) -> void:
	if not Crew.has(who):
		return
	if fx.has("roll"):
		var r: Dictionary = fx.roll
		var p := minf(0.9, float(r.p) * _people_scale() / 1.2)
		_ret_fx(who, (r.win if Difficulty.rng("service.retention").randf() < p else r.lose).duplicate(true))
	var scale := _people_scale()
	if fx.has("morale"):
		Crew.add_morale(who, int(round(float(fx.morale) * (scale if int(fx.morale) > 0 else 1.0))))
	if fx.has("morale_all"):
		Crew.add_all(int(fx.morale_all))
	if fx.has("retain"):
		Crew.add_retain(who, int(fx.retain))
	if fx.has("stress"):
		Crew.add_stress(who, int(fx.stress))
	if fx.has("skill"):
		Crew.skill_gain(who, float(fx.skill))
	if fx.has("area"):
		Crew.train(who, Crew.focus_of(who) if Crew.focus_of(who) != "" else Crew.weakest_area(who), float(fx.area))
	if fx.has("focus_area") and Crew.focus_of(who) == "":
		Crew.set_focus(who, Crew.weakest_area(who))
	if fx.has("wage"):
		Crew.members[who]["wage"] = int(Crew.value(who, "wage")) + int(fx.wage)
	if fx.has("cost"):
		spent_today += float(fx.cost)
		spent_total += int(fx.cost)
	for o in fx.get("trust", {}):
		add_trust(str(o), int(fx.trust[o]))
	if fx.has("promote"):
		Crew.members[who]["lane"] = "L2"
		flags["promoted_" + who] = true
	if fx.has("unload"):
		for t in Msp.open_tickets():
			if Crew.assignee_of(t) == who and Crew.load_of(who) > 1:
				assign(int(t.id), "", false)
	if fx.has("off_day"):
		Crew.set_busy(who, 8.0)
	if fx.has("quit") and not leaving.has(who) and not Difficulty.cozy_on():
		leaving.append(who)


# ---- training budget (a weekly choice: OFF / LIGHT / FULL) --------------------------------------------------------------
func cycle_training() -> String:
	training = TRAINING_ORDER[(TRAINING_ORDER.find(training) + 1) % TRAINING_ORDER.size()]
	return training


func _training_day() -> void:
	var t: Dictionary = TRAINING[training]
	if float(t.area) <= 0.0:
		return
	for n in Crew.names():
		Crew.train(str(n), Crew.focus_of(str(n)) if Crew.focus_of(str(n)) != "" else Crew.weakest_area(str(n)), float(t.area))
		if int(t.morale) != 0:
			Crew.add_morale(str(n), int(t.morale))


# ---- owners react to the documentation, the bus factor and a team that stays ------------------------------------------
func _owner_day() -> void:
	ServiceArc.owner_drift()
	var pct: int = kb.doc_pct()
	if pct >= 50 and not flags.get("doc50", false):
		flags["doc50"] = true
		add_trust("Alan", 3)
		Msp.mail("Alan (Co-owner)", "The runbooks", "Half the desk is written down. I can send a new hire to the knowledge base and not to you. Keep going. - Alan")
	if pct >= 80 and not flags.get("doc80", false):
		flags["doc80"] = true
		add_trust("Alan", 3)
		add_trust("Garrison", 1)
	if Campaign.day >= 10 and Crew.retention_pct() == 100 and Crew.morale_avg() >= 65 and not flags.get("stay", false):
		flags["stay"] = true
		add_trust("Garrison", 3)
		Msp.mail("Garrison (Co-owner)", "The team", "Nobody has left and everybody is smiling. That is worth more than a spreadsheet. - Garrison")


func _desk_rows() -> Array:
	var pct: int = kb.doc_pct()
	var solo := Crew.solo_mean_hours()
	var solo_text := str(ROWS.solo_none)
	if not Crew.hire_order.is_empty():
		solo_text = str(ROWS.days) % (floorf(solo / 8.0 * 10.0 + 0.5) / 10.0) if solo >= 0.0 else str(ROWS.solo_wait)  # half rounds up on every platform (printf rounds 2.25 to 2.2 on Linux, 2.3 on Windows)
	var ret := Crew.retention_pct()
	return [
		[str(ROWS.design), (str(DESIGNS[design].short) if DESIGNS.has(design) else str(ROWS.none)) + (" + DISP" if dispatcher else ""), DayReport.WHITE],
		[str(ROWS.documented), "%d%%" % pct, DayReport.GOOD if pct >= 60 else (DayReport.WARN if pct >= 25 else DayReport.BAD)],
		[str(ROWS.retention), "%d%%" % ret, DayReport.GOOD if ret >= 100 else (DayReport.WARN if ret >= 66 else DayReport.BAD)],
		[str(ROWS.solo), solo_text, DayReport.WHITE],
		[str(ROWS.cost), "$%d" % cost_per_ticket() if cost_per_ticket() >= 0 else "-", DayReport.WHITE],
	]


# ---- saving -----------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"trust": trust.duplicate(), "focus": focus, "buffs": buffs.duplicate(true), "flags": flags.duplicate(true),
		"oto_seen": oto_seen.duplicate(), "oto_day": oto_day.duplicate(), "grades": grades.duplicate(true),
		"project_days": project_days, "memos": memos_done.duplicate(), "crew": Crew.to_dict(), "outings": _outings_seen,
		"auto": auto, "dispatched": dispatched, "escalated": escalated,
		"design": design, "dispatcher": dispatcher, "design_day": design_day, "design_changes": design_changes,
		"pods": pods.duplicate(), "pod_days": pod_days.duplicate(), "misallocated": misallocated, "training": training,
		"spent_total": spent_total, "last_event_day": last_event_day, "event_days": event_days.duplicate(),
		"events_fired": events_fired.duplicate(), "kb": kb.to_dict(), "arc": ServiceArc.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	var t: Dictionary = data.get("trust", {})
	for who in OWNERS:
		trust[who] = int(t.get(who, TRUST_START))
	focus = str(data.get("focus", "p1"))
	if not FOCUS.has(focus):
		focus = "p1"
	buffs = data.get("buffs", []).duplicate(true)
	flags = data.get("flags", {}).duplicate(true)
	oto_seen = data.get("oto_seen", {}).duplicate()
	oto_day = data.get("oto_day", {}).duplicate()
	grades = data.get("grades", []).duplicate(true)
	project_days = int(data.get("project_days", 0))
	memos_done = data.get("memos", {}).duplicate()
	_outings_seen = int(data.get("outings", 0))
	auto = str(data.get("auto", "all"))
	if not POLICIES.has(auto):
		auto = "all"
	dispatched = int(data.get("dispatched", 0))
	escalated = int(data.get("escalated", 0))
	Crew.from_dict(data.get("crew", {}))
	design = str(data.get("design", ""))
	if not design in DESIGN_ORDER:
		design = ""
	dispatcher = bool(data.get("dispatcher", false))
	design_day = int(data.get("design_day", 0))
	design_changes = int(data.get("design_changes", 0))
	pods = {}
	for c in data.get("pods", {}):
		pods[int(c)] = str(data.pods[c])
	pod_days = {}
	for c in data.get("pod_days", {}):
		pod_days[int(c)] = int(data.pod_days[c])
	misallocated = int(data.get("misallocated", 0))
	training = str(data.get("training", "none"))
	if not TRAINING.has(training):
		training = "none"
	spent_total = int(data.get("spent_total", 0))
	last_event_day = int(data.get("last_event_day", -99))
	event_days = data.get("event_days", {}).duplicate()
	events_fired = data.get("events_fired", []).duplicate()
	kb.from_dict(data.get("kb", {}))
	ServiceArc.from_dict(data.get("arc", {}))
