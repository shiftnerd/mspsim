extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The service manager campaign (C4 / V1, mode "service"): you are Dan, promoted to run the desk. The crew (Crew) works the
# queue by itself through the crew gate (Owner.team_speed / _work_queue); you set a focus in the MORNING HUDDLE, talk to your
# people in 1:1s, answer the owners' MEMOS (Alan wants quality and the stack, Garrison wants yes to the client and a happy
# team; each choice moves the two trust meters and has a real effect), decide who takes the big incidents (the Playbook jobs,
# played by you or run by the crew) and read the SCORECARD at the end of the day. Morgan's confidence is Campaign.rep (fired at
# 0, or when both owners' trust is under 20). Hands-on still works: your desk's PSA / RMM are the normal computer apps.
# V1 uses Cards and the PSA ticket list; the Dispatch board, Capacity view, runbooks and hiring are C5 / C6.

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
		"speaker": "Vic (Account Manager)",
		"text": "I promised Brightside a two hour response on everything. They loved it. Your crew can do that, right?",
		"options":
		[
			{"id": "h", "label": "HOLD VIC TO IT", "text": "We can do it if the P3s wait. I wrote the exceptions on the board.", "fx": {"social": {"Vic": 2}, "trust": {"Alan": 0, "Garrison": 3}, "morale": -2}},
			{"id": "r", "label": "RE-QUOTE IT WITH VIC", "text": "Four hours, with two hours for urgent. Vic will call them. He did not enjoy it.", "fx": {"social": {"Vic": -2}, "trust": {"Alan": 3, "Garrison": -2}}},
			{"id": "t", "label": "ASK GARRISON", "text": "Garrison says to do it and we sort the staffing later. I am not sure that is a plan.", "fx": {"trust": {"Alan": -2, "Garrison": 4}, "morale": -3, "mood": 3}},
		],
	},
	"nosale":
	{
		"speaker": "Vic (Account Manager)",
		"text": "A new prospect wants fifty seats at half our price, with a four-hour response. Garrison likes the logo. The numbers look thin to me. Do we take them?",
		"options":
		[
			{"id": "y", "label": "TAKE THEM", "text": "We take them. I will plan the capacity before they start.", "fx": {"trust": {"Alan": -3, "Garrison": 5}, "morale": -3, "buff": ["issues", 1.06, 4]}},
			{"id": "n", "label": "SAY NO, POLITELY", "text": "No. I wrote down why: price, scope and response time do not fit. Vic will say it nicely.", "fx": {"trust": {"Alan": 5, "Garrison": -4}, "social": {"Vic": -1}}},
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

# 1:1 cards. Decks: Maya, Tech ({name} is Sam or Terry), Vic. Each option: label, reply, fx (morale / retain / social / trust).
const DEFAULT_ONE_ON_ONES := {
	"Maya":
	[
		{
			"text": "I closed eleven tickets yesterday and nobody said anything. Is that good?",
			"options":
			[
				{"label": "TELL HER EXACTLY WHAT WAS GOOD", "reply": "Eleven is good. The Acme spooler notes were the best. I mean it.", "fx": {"morale": 6, "retain": 1}},
				{"label": "SAY THANKS", "reply": "Thanks. Keep going.", "fx": {"morale": 2}},
				{"label": "ASK ABOUT THE REOPENS", "reply": "Two came back. Let us look at those together.", "fx": {"morale": -2, "skill": 0.02}},
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
	],
	"Tech":
	[
		{
			"text": "{name} says: I got stuck on a printer yesterday and did not ask. I did not want to bother you.",
			"options":
			[
				{"label": "ASK HIM TO ASK, ALWAYS", "reply": "Asking is part of the job. Five minutes is the rule: stuck for five, ask. I wrote it on the board.", "fx": {"morale": 4, "retain": 1}},
				{"label": "WALK THROUGH THE FIX", "reply": "Let us do it now. I will show you where the queue lives.", "fx": {"morale": 5, "skill": 0.03}},
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
	],
	"Vic":
	[
		{
			"text": "I have a prospect who wants a handshake deal. No contract until next month. Come on, Dan.",
			"options":
			[
				{"label": "ASK FOR A ONE-PAGE SCOPE", "reply": "One page. What we do, what we do not, how fast. You can say it is for the crew.", "fx": {"social": {"Vic": 1}, "trust": {"Alan": 2, "Garrison": 0}}},
				{"label": "LET HIM HAVE THE HANDSHAKE", "reply": "Fine. But I log every hour they use.", "fx": {"social": {"Vic": 3}, "trust": {"Alan": -1, "Garrison": 2}, "mood": 1}},
				{"label": "REFUSE UNTIL SIGNED", "reply": "No work without a signature.", "fx": {"social": {"Vic": -3}, "trust": {"Alan": 2, "Garrison": -2}}},
			],
		},
		{
			"text": "My clients say tickets take forever. I tell them you are working on it. Are you?",
			"options":
			[
				{"label": "SHOW HIM THE BOARD", "reply": "Here is the queue, by age. Tell them the real number. Honest is better.", "fx": {"social": {"Vic": 2}, "mood": 1}},
				{"label": "GIVE HIM A PHONE NUMBER", "reply": "Give them my desk line for P1s. I will pick up.", "fx": {"social": {"Vic": 3}, "morale": -2}},
				{"label": "TELL HIM TO BE PATIENT", "reply": "We are working on it.", "fx": {"social": {"Vic": -2}}},
			],
		},
		{
			"text": "Garrison wants a client dinner on Thursday. Can the crew cover the phones?",
			"options":
			[
				{"label": "COVER IT MYSELF", "reply": "I cover the phones. Go. Bring the client back happy.", "fx": {"social": {"Vic": 3}, "trust": {"Alan": 0, "Garrison": 2}, "morale": 1}},
				{"label": "ASK MAYA FIRST", "reply": "I will ask Maya. If she says yes, there is a bonus.", "fx": {"social": {"Vic": 1}, "morale_who": {"Maya": 2}}},
				{"label": "SAY NO", "reply": "Not Thursday. The queue is too long.", "fx": {"social": {"Vic": -3}, "trust": {"Alan": 1, "Garrison": -2}}},
			],
		},
		{
			"text": "I know I over-promise. Garrison says it is how we win. You say it is how we lose. Who is right?",
			"options":
			[
				{"label": "SPLIT IT: PROMISE LESS, SELL BETTER", "reply": "Both. Promise what we can do and sell why it matters. I will help you write the lines.", "fx": {"social": {"Vic": 3}, "trust": {"Alan": 1, "Garrison": 1}}},
				{"label": "TELL HIM HE IS RIGHT", "reply": "Garrison is right about the win. I will find a way to do the work.", "fx": {"social": {"Vic": 4}, "trust": {"Alan": -1, "Garrison": 2}, "morale": -2}},
				{"label": "TELL HIM HE IS WRONG", "reply": "You are the one the clients blame.", "fx": {"social": {"Vic": -4}, "trust": {"Alan": 2, "Garrison": -2}}},
			],
		},
	],
}
var ONE_ON_ONES: Dictionary = DEFAULT_ONE_ON_ONES.duplicate(true)
const DEFAULT_ONE_TEXT := {
	"already": "We talked this morning, Dan. I am fine. Thanks.",
	"walkup": "%s stops by your desk.",
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
	3: [{"at": 9.1, "kind": "mail", "from": "Morgan Reyes - Manager", "subject": "Your own queue", "body": "You can still pick up tickets with your own PSA and RMM when the crew is stuck. Just remember every minute at the keyboard is a minute nobody is looking at the board. - Morgan"}],
	4: [{"at": 10.5, "kind": "beat", "id": "xp"}],
	6: [{"at": 10.5, "kind": "beat", "id": "vic"}],
	7: [{"at": 10.2, "kind": "incident", "id": "rdp", "book": "rdp"}],
	9: [{"at": 10.2, "kind": "incident", "id": "ransom", "book": "ransom"}],
	10: [{"at": 16.0, "kind": "friday"}],
	11: [{"at": 10.2, "kind": "incident", "id": "rack", "book": "rack"}],
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
		"stay": {"label": "STAY ON PROBATION", "desc": "KEEP THE DESK, WITH A THIRTY-DAY PLAN FROM MORGAN.", "text": "YOU KEEP THE DESK WITH A WRITTEN PLAN. MORGAN WILL CHECK IT EVERY FRIDAY. YOU START BY LABELLING THE PLAN."},
	},
}
var REVIEW: Dictionary = DEFAULT_REVIEW.duplicate(true)

var trust := {"Alan": TRUST_START, "Garrison": TRUST_START}
var focus := "p1"
var buffs: Array = []  # {key, val, left}
var flags := {}
var oto_seen := {}  # deck -> cards used
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


func _ready() -> void:
	reset()


func active() -> bool:
	return Campaign.active and Campaign.mode == "service"


func reset() -> void:
	trust = {"Alan": TRUST_START, "Garrison": TRUST_START}
	focus = "p1"
	buffs = []
	flags = {}
	oto_seen = {}
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
	Crew.reset()


# a new run: Dan arrives with good networking, Morgan's confidence starts at 55
func begin_run() -> void:
	Campaign.rep = START_CONFIDENCE
	var need: int = Skills.XP_AT[2]
	Skills.xp["networking"] = maxi(int(Skills.xp.get("networking", 0)), need)


# ---- numbers other scripts read ---------------------------------------------------------------------------------
func trust_of(owner_name: String) -> int:
	return int(trust.get(owner_name, TRUST_START))


func add_trust(owner_name: String, amount: int) -> void:
	if trust.has(owner_name):
		trust[owner_name] = clampi(trust_of(owner_name) + amount, 0, 100)


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
func _people_scale() -> float:
	return minf(1.5, 1.0 + 0.1 * float(Skills.level("people")))


func apply_fx(fx: Dictionary, scale := 1.0) -> void:
	for who in fx.get("trust", {}):
		add_trust(str(who), int(fx.trust[who]))
	if fx.has("morale"):
		var n := int(round(float(fx.morale) * (scale if int(fx.morale) > 0 else 1.0)))
		Crew.add_all(n)
	for who in fx.get("morale_who", {}):
		var v := int(fx.morale_who[who])
		Crew.add_morale(str(who), int(round(float(v) * (scale if v > 0 else 1.0))))
	for who in fx.get("retain", {}):
		Crew.add_retain(str(who), int(fx.retain[who]))
	if fx.has("retain_all"):
		for who in Crew.names():
			Crew.add_retain(str(who), int(fx.retain_all))
	if fx.has("mood"):
		for c in Sales.active:
			Sales.adjust(int(c), int(fx.mood))
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
	_farewells()
	huddle()


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
		if picked >= 2:
			break
		var best := Crew.best_for(t, 2)
		if best == "":
			break  # the crew is full: it waits
		assign(id, best, false)
		picked += 1


func _note_response(t: Dictionary, _who: String) -> void:
	_seen[int(t.id)] = true
	_frt_sum += clampf((float(t.sla_total) - float(t.sla_left)) / maxf(1.0, float(t.sla_total)), 0.0, 1.0)
	_frt_n += 1


# ---- dispatch: who works what (C5) --------------------------------------------------------------------------------
# lane ids: "" = unassigned, a tech's name, "Dan" (you take it yourself), "ESC" = the owners' escalation lane
func lane_ids() -> Array:
	return [""] + Crew.names() + ["Dan", "ESC"]


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
		add_trust(who, -OWNER_COST)
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
			cap[who] = float(cap[who]) + idle_pool * ASSIST * Crew.worker_speed(str(who)) / busy_speed
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
		Msp.close_ticket(id)  # closed too early: it comes back to the same desk
		return
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
	Cards.ask(str(b.speaker), str(b.text), options, func(pick: String) -> void: answer_beat(id, pick))


func answer_beat(id: String, pick: String) -> void:
	var b: Dictionary = BEATS[id]
	for o in b.options:
		if str(o.id) == pick:
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
	return Campaign.mode == "service" and (who == "Maya" or who == "Vic" or Crew.has(who))


func _deck_of(who: String) -> String:
	return who if who == "Maya" or who == "Vic" else "Tech"


func one_on_one(who: String, after := Callable()) -> void:
	var label := Roles.label(who) if who == "Maya" or who == "Vic" else "%s (Tier 1)" % who
	if int(oto_day.get(who, -1)) == Campaign.day:
		Cards.ask(label, str(ONE_TEXT.already), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: _call(after))
		return
	oto_day[who] = Campaign.day
	if Crew.has(who):
		Crew.members[who]["last_oto"] = Campaign.day
	var deck_id := _deck_of(who)
	var deck: Array = ONE_ON_ONES[deck_id]
	var used := int(oto_seen.get(deck_id, 0))
	oto_seen[deck_id] = used + 1
	var card: Dictionary = deck[used % deck.size()]
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
		if Campaign.day - last >= 3 and (who == "" or last < int(Crew.value(who, "last_oto"))):
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
	var delta: int = {"S": 3, "A": 2, "B": 1, "C": -1, "D": -3}[grade]
	if grade in ["S", "A"] and trust_of("Alan") >= 60 and trust_of("Garrison") >= 60:
		delta += 1
	if trust_of("Alan") < 25 or trust_of("Garrison") < 25:
		delta -= 1
	var out_notes: Array = []
	# end-of-day bookkeeping: the day's focus, the crew's mood, quits, the owners' drift
	if focus == "mentor":
		Crew.mentor("Maya")
	if focus == "project":
		project_days += 1
	var gone: Array = Crew.end_day(util, grade)
	for who in gone:
		out_notes.append("%s QUIT" % str(who).to_upper())
		Msp.mail("Pixel IT Partners - Manager", "%s resigned" % who, "%s handed in a notice this evening. - Morgan" % who)
	if grade in ["S", "A"]:
		add_trust("Alan", 1)
		add_trust("Garrison", 1)
	elif grade == "D":
		add_trust("Alan", -1)
		add_trust("Garrison", -1)
	var both_low := trust_of("Alan") < FAIL_TRUST and trust_of("Garrison") < FAIL_TRUST
	if both_low:
		delta = -Campaign.rep
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
	if not out_notes.is_empty():
		people.append(["CREW", " ".join(out_notes), DayReport.BAD])
	r["groups"] = [["SCORECARD", scorecard], ["TEAM", people], ["OWNERS", owners]]
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
	if ta >= 55 and ta >= tg:
		out.append({"id": "alan", "label": str(REVIEW.endings.alan.label), "desc": str(REVIEW.endings.alan.desc)})
	if tg >= 55 and tg >= ta:
		out.append({"id": "garrison", "label": str(REVIEW.endings.garrison.label), "desc": str(REVIEW.endings.garrison.desc)})
	if Campaign.rep >= 45:
		out.append({"id": "leave", "label": str(REVIEW.endings.leave.label), "desc": str(REVIEW.endings.leave.desc)})
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
			lines.append(["TWENTY DAYS AT THE DESK. LET US LOOK AT THE NUMBERS.", ink])
			lines.append(["CONFIDENCE %d   CREW MORALE %d   CLIENT MOOD %d" % [Campaign.rep, Crew.morale_avg(), int(Sales.average())], ink])
			lines.append(["CLOSED %d   SLA MISSED %d   REOPENED %d" % [Msp.closed_ok, Msp.breached, Msp.reopened], ink])
			var count := {"S": 0, "A": 0, "B": 0, "C": 0, "D": 0}
			for g in grades:
				count[str(g.grade)] = int(count[str(g.grade)]) + 1
			lines.append(["DAYS: S %d  A %d  B %d  C %d  D %d" % [count.S, count.A, count.B, count.C, count.D], ink])
			lines.append(["TRUST: ALAN %d (%s)  GARRISON %d (%s)" % [trust_of("Alan"), trust_word(trust_of("Alan")), trust_of("Garrison"), trust_word(trust_of("Garrison"))], ink])
			for key in ["rdp", "ransom", "rack", "email24", "migration"]:
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
		2:
			lines.append(["YOUR OPTIONS", blue])
		_:
			lines.append(["THE END", blue])
			lines.append([str(REVIEW.endings[ending].text) if REVIEW.endings.has(ending) else "", ink])
	return lines


# ---- saving -----------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"trust": trust.duplicate(), "focus": focus, "buffs": buffs.duplicate(true), "flags": flags.duplicate(true),
		"oto_seen": oto_seen.duplicate(), "oto_day": oto_day.duplicate(), "grades": grades.duplicate(true),
		"project_days": project_days, "memos": memos_done.duplicate(), "crew": Crew.to_dict(), "outings": _outings_seen,
		"auto": auto, "dispatched": dispatched, "escalated": escalated,
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
