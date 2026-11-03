extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Talking to people at their desks (campaigns). E on a coworker, seated or standing, opens a conversation:
# SMALL TALK, ASK FOR HELP (they fix one of your tickets if they like you), ANY TIPS? (advice from the live game state,
# and a short lesson from a friend once a day) and LEAVE (Esc). Owner campaign: HOW ARE YOU HOLDING UP? and ANY IDEAS?.
# Each person has a voice and a specialty: Alan servers, Garrison security, Dan networking, Vic sales. Alan and Garrison
# are the two OWNERS (Alan technical, Garrison sales and culture): they talk about payroll, clients, the van and hiring.

const SPECIALTY := {
	"Alan": "servers",
	"Garrison": "security",
	"Dan": "networking",
	"Vic": "people",
	"Maya": "people",
	"Morgan": "people",
	"Sam": "servers",
	"Terry": "security"
}
const LESSON_XP := 6
const DEFAULT_GREETINGS := {
	"Alan":
	{
		"friend": "Hey, there you are. Coffee is fresh and the books can wait ten minutes. What is up?",
		"neutral": "Yeah? I have got about a minute. Payroll is waiting.",
		"cold": "...Yes?",
	},
	"Garrison":
	{
		"friend": "Oh hey! Perfect timing, I just got off with a client and my brain needed a break. What is up?",
		"neutral": "Hi. What do you need? I have a client on in five.",
		"cold": "Mm. What?",
	},
	"Dan":
	{
		"friend": "Hey! Pull up a chair. Well, stand there. What is up?",
		"neutral": "Hey. Need something?",
		"cold": "I am kind of in the middle of something.",
	},
	"Vic":
	{
		"friend": "My favourite tech! Talk to me.",
		"neutral": "Hey there. Quick one, I have a call at three.",
		"cold": "Can this wait? I am on the phone in five.",
	},
	"Maya":
	{
		"friend": "Hi! Want half a granola bar? I have been saving it for someone nice.",
		"neutral": "Hey! Sorry, I have a user on hold. What is up?",
		"cold": "Oh. Hi. I am just finishing something.",
	},
	"Morgan":
	{
		"friend": "Come in. Move the printouts, they are not load-bearing. What do you need?",
		"neutral": "Yes? I have a budget call in five minutes. Go ahead.",
		"cold": "Mm. Is this about the queue?",
	},
	"Sam":
	{
		"friend": "Hey Dan! I closed three resets before ten. Want to see my queue?",
		"neutral": "Hi. I am on a ticket. Sorry, one sec.",
		"cold": "Yeah. Okay.",
	},
	"Terry":
	{
		"friend": "Dan! Come in. The war room has the best chairs and the worst Wi-Fi.",
		"neutral": "Hey. I have a client on the phone in a minute.",
		"cold": "Not now, please.",
	},
}
var GREETINGS: Dictionary = DEFAULT_GREETINGS.duplicate(true)
const DEFAULT_SMALL := {
	"Alan":
	[
		"Windows XP goes dark on April 8th. I have got a spreadsheet of every XP box we manage. It is longer than my coffee order.",
		"I have been doing this since the NT days. These days it is payroll and vendor calls, but people still ask me to turn it off and on again. They are right more often than I like to admit.",
		"My kid asked what I do. I said I make sure the printers work. She said that sounds boring. She is not wrong.",
		"Did you see the Target breach news? Every client wants to know if they are next. Garrison has been on the phone with them since eight.",
		"The van needs brakes. The books say we can afford brakes. Barely.",
		"I priced a new rack for the closet. Buy it, do not build it, unless you enjoy supporting your own script.",
	],
	"Garrison":
	[
		"Everybody is changing their passwords after that Target thing. I would love it if they used something better than Summer2013.",
		"I finally beat level 90 on Sugar Smash. Do not tell Alan how many lives I spent.",
		"I keep telling clients: not every email from your bank is from your bank.",
		"Alan's new LabRat script saved the crew an hour on Tuesday. Do not tell him I said so.",
		"I am planning the next team outing. Bowling is the safe bet, karaoke is the brave one.",
		"Hiring is the hard part. Good techs are never on the market on a Monday.",
	],
	"Dan":
	[
		"I labeled every patch panel port last weekend. Nobody noticed. That is how you know it was good work.",
		"Floppy Bat got pulled and I am stuck at 31. I am taking it personally.",
		"The best network is the one nobody talks about. The worst one is every one of our clients.",
		"I have been reading about Heartbleed. It is going to be a long April.",
	],
	"Vic":
	[
		"Quarter is almost over and I need two more logos. Do you know anyone who hates their IT guy?",
		"I told a prospect we are the Apple of managed services. I do not know what that means either.",
		"Golf on Friday. A good relationship is built on the fifth hole.",
		"Clients love you. I just say you are the best in the building. It is only a little bit a lie.",
	],
	"Maya":
	[
		"Today I walked a lady through plugging in her monitor. It was not plugged in. I said that was a very common problem and she felt great.",
		"I just got a Galaxy S4 and I have not turned off the camera shutter sound yet. Sorry, Dan.",
		"Alan showed me how to read an event log. I felt like a detective. A tired one.",
		"I am trying to learn PowerShell on my lunch break. It is a lot like learning French, if French had brackets.",
	],
	"Morgan":
	[
		"Alan wants a status report. Garrison wants a different status report. I wrote one report and gave it two titles.",
		"Windows XP ends in April. I have a spreadsheet, a colour code and a sense of dread. The dread does not fit in the spreadsheet.",
		"Every client has forwarded me a different article about the Target breach. They all think they are next. Fair enough.",
		"I was a tech for six years before anybody let me near a budget. Do not let anyone tell you the desk is the hard part.",
		"I put iOS 7 on my phone. It is very bright. I miss my buttons.",
		"Somebody left a foam dart on top of the whiteboard. I know who. I am letting it go. Once.",
	],
	"Sam":
	[
		"I asked a user to turn it off and on again and it worked. I felt like a wizard.",
		"My sister says IT is boring. Then she calls me when her printer jams.",
		"I am saving for a Galaxy S4. Maya says wait for the next one. There is always a next one.",
	],
	"Terry":
	[
		"I work from the conference table with my laptop. Hot-desking, they call it. I call it a very long meeting with myself.",
		"My last job had a server under somebody's desk. Somebody's actual desk. With their feet on it.",
		"I like the phones. People call when something is broken, and then I fix it, and they are nice for a second.",
	],
}
var SMALL: Dictionary = DEFAULT_SMALL.duplicate(true)
const DEFAULT_GOSSIP := [
	"Between us: Morgan has been in the owners' office since nine. Never a good sign.",
	"I heard Vic is already negotiating next year's commission. Good for him.",
	"Somebody microwaved fish in the kitchenette again. We are not saying who.",
	"I heard the printer on the main floor jammed again. Nobody will own up to it.",
]
var GOSSIP: Array = DEFAULT_GOSSIP.duplicate(true)
const DEFAULT_TIPS_GENERIC := {
	"Alan":
	[
		"Restart the print spooler instead of rebooting. People who get rebooted without warning lose their work, and the client remembers it at renewal time.",
		"Verify the backups every morning. A backup you have not tested is a hope, not a backup. It is my name on the contract, not yours.",
		"Ask the user to save before you touch anything. It takes ten seconds and saves a bad email in my inbox.",
		"Buy it, do not build it. A script nobody else can read is a bus factor of one, and that one is usually me.",
	],
	"Garrison":
	[
		"Never use a default or seasonal password on a remote login. That is how they get in. I say it to every prospect.",
		"If a ransom note shows up, do not reboot. Shadow copies first, backup if you have it, paying is the last resort.",
		"Two-factor login for admins first, users second. Most attacks are still just guessing.",
		"Call the client before the invoice does. A short call keeps the contract; a long silence loses it.",
	],
	"Dan":
	[
		"Label both ends of every cable. Future you will buy present you a coffee.",
		"No link on a desk? Check the patch cable in the closet before you blame the switch.",
		"The UPS gives you about ninety seconds. Plan the shutdown, do not improvise it.",
	],
	"Vic":
	[
		"Clients forgive a slow fix. They do not forgive silence. Call before they call you.",
		"A happy client brings me a referral. An unhappy client brings me a competitor.",
		"If you can fix it before they notice, do. If you cannot, tell them early.",
	],
	"Maya":
	[
		"Be kind to the user first. Half of the problem is that they are scared they broke something.",
		"Say what you are going to do before you do it. 'I am going to restart your printer, one second.' Nobody gets scared.",
		"Write down every fix in the ticket. The next person at three in the morning will thank you. That might be you.",
	],
	"Morgan":
	[
		"A ticket with no notes is a ticket I have to ask about. A ticket with notes is one I can defend at renewal time.",
		"If you are going to miss an SLA, tell me before it breaks. I can move things around. I cannot move things I do not know about.",
		"Close what you fix. Reopen what you break. Just be the person who tells me which one it is.",
		"Study between tickets. Nobody has ever been promoted for how fast they picked up the phone.",
	],
	"Sam":
	[
		"If a ticket is above your level, say so early. Waiting does not make it easier.",
		"Restart the print spooler before you reboot anything. People lose work when you reboot.",
	],
	"Terry":
	[
		"Check the password policy before you reset anything. The same user will be back next week otherwise.",
		"Write down every fix. The next person at three in the morning might be you.",
	],
}
var TIPS_GENERIC: Dictionary = DEFAULT_TIPS_GENERIC.duplicate(true)
const DEFAULT_OWNER_HOLD := {
	"low": "I am good, boss. Busy, but good.",
	"mid": "Honestly? Tired. The queue never really empties.",
	"high": "I am burning out. I am not going to lie to you.",
}
var OWNER_HOLD: Dictionary = DEFAULT_OWNER_HOLD.duplicate(true)

# ---- Vic's talk (sales campaign, C3): what the coworkers say to the account manager ------------------------------
# tokens: {cap} crew capacity, {open} open tickets, {pct} quota %, {weeks} weeks left in the quarter, {leads} open leads,
# {client} / {mood} the unhappiest client, {deal} a deal with a promise gap, {floor} margin floor %, {claw} clawbacks
const DEFAULT_VIC_GREETINGS := {
	"Alan": {
		"friend": "Vic. Sit. Give me the number first and the story after.",
		"neutral": "Pipeline. Go. I have the books open.",
		"cold": "...What did you promise this time?",
	},
	"Garrison": {
		"friend": "There he is, my favourite closer! Tell me something good. Actually, tell me the number. Then something good.",
		"neutral": "Vic! Quick one, I have a client in five. How is the pipeline?",
		"cold": "Mm. Is this about a quote or about a discount?",
	},
	"Dan": {
		"friend": "Hey Vic. Mind the cables. If you are about to sell something, tell me first and I will tell you what I can actually do.",
		"neutral": "Hey. Is this about a new client? Because I have {open} tickets open.",
		"cold": "If it is a new client, I am not taking it.",
	},
	"Morgan": {
		"friend": "Come in, Vic. I read your handover binder last night. It was almost accurate.",
		"neutral": "Yes? I have a budget call in five minutes. Is this a promise or a question?",
		"cold": "Mm. Are we talking about what you sold, or what we can do?",
	},
	"Maya": {
		"friend": "Hi Vic! Your clients are so nice. Well, most of them. Want half a granola bar?",
		"neutral": "Hey! Sorry, I have someone on hold. What is up?",
		"cold": "Oh. Hi. I am just finishing a ticket for one of your clients.",
	},
}
var VIC_GREETINGS: Dictionary = DEFAULT_VIC_GREETINGS.duplicate(true)
const DEFAULT_VIC_SMALL := {
	"Alan": [
		"The XP deadline passed and half our prospects still run it. Every one of them thinks it is somebody else's problem.",
		"Do you know what a one hour response costs us? Neither does Garrison.",
		"The van needs brakes. The books say we can afford brakes. Barely. Your commission is not helping.",
		"I looked at the ByteBrothers website. Their server is on a residential cable line. I am not saying a word.",
		"My kid asked what you do. I said you talk people into buying what I build. She said that sounds easy. I said try it.",
	],
	"Garrison": [
		"I have golf on Friday with the Chamber president. Business is done on the fifth hole.",
		"Everybody is changing their passwords after the Target breach. I call it peace of mind. Alan calls it a required step.",
		"I closed my first deal in a parking lot. The contract was on a napkin. Do not do that.",
		"I finally beat level 90 on Sugar Smash. Do not ask what I spent.",
		"The best salesman I ever met never said yes on the first call. He said let me check with my team. Then he checked with his team.",
	],
	"Dan": [
		"Every time you sign a client I learn a new printer model.",
		"I labeled every patch panel port last weekend. Nobody noticed. That is how you know it was good work.",
		"I do not mind new clients. I mind new clients who were promised a one hour response.",
		"The aquarium at the vet clinic has better network infrastructure than we do. I looked.",
	],
	"Morgan": [
		"Alan wants a status report. Garrison wants a different status report. I wrote one report and gave it two titles.",
		"I was a tech for six years before anybody let me near a budget. The desk is not the hard part.",
		"Windows XP ended in April and I still have eleven clients on it. Sell them the migration, not the miracle.",
		"I read every handover binder. The ones that say standard SLA make me happy. The ones with highlighter make me nervous.",
	],
	"Maya": [
		"Today I walked a lady through plugging in her monitor. It was not plugged in. She felt great and told her husband you were wonderful.",
		"Your Piedmont people call me by name now. I feel famous.",
		"A client sent me a fruit basket. I do not know whom to credit, but I ate the pineapple.",
		"I am trying to learn PowerShell on my lunch break. It is a lot like selling, except it does what you tell it.",
	],
}
var VIC_SMALL: Dictionary = DEFAULT_VIC_SMALL.duplicate(true)
const DEFAULT_VIC_GOSSIP := [
	"Between us: Alan and Garrison argued about discounts again this morning. The door was closed and I could still hear the word logo.",
	"I heard ByteBrothers is hiring salesmen. The word on the street is they pay on the quote, not on the retention.",
	"Somebody microwaved fish in the kitchenette again. We are not saying who.",
	"I heard Morgan keeps a list of promises. Mostly yours. It is not a long list. Yet.",
]
var VIC_GOSSIP: Array = DEFAULT_VIC_GOSSIP.duplicate(true)
const DEFAULT_VIC_TIPS := {
	"Alan": [
		"Do not quote under the margin floor. A client who costs us money is not a client, he is a hobby.",
		"Ask what is plugged in before you promise anything. Half of these offices have a server under somebody's desk.",
		"If you cannot explain the price in one sentence, the price is wrong.",
		"Put it in writing. A promise in an email is a contract. A promise on a golf course is a story.",
	],
	"Garrison": [
		"Call before they call you. A short call keeps the contract; a long silence loses it.",
		"The logo is a door, not a house. Get through the door and then charge for the house.",
		"People buy from the guy who remembers their kid's name. Write it down. I do.",
		"ByteBrothers always quotes twenty percent under and delivers twenty percent less. Make them say what they cut.",
	],
	"Dan": [
		"Before you promise a response time, look at my queue. Walk over, I will show it to you.",
		"Four hours is easy. One hour at any time means I sleep in the van.",
		"Onboarding takes me two weeks per client. If you rush it I will do it, but something else slips.",
		"A new client is three PCs, one printer and a wireless password nobody remembers. Tell me which printer.",
	],
	"Morgan": [
		"Every promise you make goes in the binder. If it is not in the binder it did not happen, and I will say so in front of the client.",
		"If you must promise something fast, promise it to me first. I can move things around. I cannot move things I do not know about.",
		"Disclose the gap at the handover. It costs you a minute. Hiding it costs you the client in ninety days, and your commission with it.",
		"Renewals are won in the first thirty days. After that, it is just paperwork.",
	],
	"Maya": [
		"Be kind to the owner first. Half the problem is that they are scared they bought the wrong thing.",
		"Clients tell me things they never tell you: who is mad, who is leaving, who just had a baby. Ask me.",
		"When a client goes quiet, that is the dangerous kind. The loud ones stay forever.",
		"Call the angry ones on a Monday. By Friday they have told three friends.",
	],
}
var VIC_TIPS: Dictionary = DEFAULT_VIC_TIPS.duplicate(true)
const DEFAULT_VIC_STATE := {
	"Dan": {"tight": "Capacity is {cap} of 3 right now with {open} tickets open. Whatever you sell this week lands on top of that. Promise four hours, not one."},
	"Morgan": {"gap": "{deal} has a promise gap I can see from here. Come to the conference room and tell them the real SLA before they find it out in week three."},
	"Maya": {"mood": "{client} sounded annoyed when I called. They are {mood} percent happy and the number is going the wrong way. Call them before they start shopping around."},
	"Garrison": {
		"behind": "You are at {pct} percent of quota with {weeks} weeks left in the quarter. The number is the number. Get me two more logos.",
		"ahead": "{pct} percent with {weeks} weeks to go? Vic, I may cry. Keep the margin where Alan can see it.",
	},
	"Alan": {"claw": "You have lost {claw} in clawbacks. Go and find out why before you sell the next one.", "floor": "The floor is {floor} percent. Anything under it comes to me first and I say no."},
}
var VIC_STATE: Dictionary = DEFAULT_VIC_STATE.duplicate(true)
const DEFAULT_VIC_ASK := {
	"Dan": {
		"label": "CAN YOUR CREW TAKE ANOTHER CLIENT?",
		"good": "We can take one. Capacity is {cap} of 3 and the queue is {open}. Do not promise one hour. Promise four and we will beat it.",
		"tight": "Maybe. Capacity is {cap} of 3 and there are {open} tickets open. One small client, standard SLA, slow onboarding. Not two.",
		"over": "Not this week. Capacity is {cap} of 3 and there are {open} tickets open. If you sign another one I will do the onboarding in the van.",
	},
	"Morgan": {
		"label": "HOW ARE MY HANDOVERS GOING?",
		"clean": "Clean so far. The binder matches what the crew can do. Keep it that way and the renewals will look after themselves.",
		"gaps": "Not clean. {deal} still has a promise gap. The client has noticed and so have I. Fix it with a call before it becomes a complaint.",
	},
	"Maya": {
		"label": "HOW ARE MY CLIENTS DOING?",
		"fine": "They are doing great. The unhappiest one is {client} at {mood} percent, and that is a printer, not a person.",
		"worry": "{client} is at {mood} percent. They have not said they are leaving, but they have started saying 'we'll see'. That is how it starts.",
	},
	"Alan": {
		"label": "PIPELINE UPDATE",
		"ahead": "{pct} percent of quota, {leads} open leads. Fine. Do not touch the floor to hit a number.",
		"behind": "{pct} percent with {weeks} weeks left and {leads} leads. Close what you can deliver. Do not buy the quarter with discounts.",
	},
	"Garrison": {
		"label": "PIPELINE UPDATE",
		"ahead": "{pct} percent and {leads} leads in the pipe! Vic, you are making me look smart. Keep going.",
		"behind": "{pct} percent, {weeks} weeks left, {leads} leads. It is not the end of the world. It is, however, the end of the quarter. Let us talk about the hot ones.",
	},
}
var VIC_ASK: Dictionary = DEFAULT_VIC_ASK.duplicate(true)

var _who := ""
var _npc: Node = null
var _taught := {}  # who -> day they last taught you something
var _listened := {}  # who -> week you last asked how they are holding up


func reset() -> void:
	_who = ""
	_npc = null
	_taught = {}
	_listened = {}


func available(who: String) -> bool:
	return Campaign.active and (SPECIALTY.has(who) or Crew.is_hire(who)) and not Cards.is_open


# a tech you hired (C6) has no lines of their own: they borrow Sam's voice and a specialty from their strongest area
func voice(who: String) -> String:
	return who if GREETINGS.has(who) else "Sam"


func specialty(who: String) -> String:
	if SPECIALTY.has(who):
		return str(SPECIALTY[who])
	var best := "networking"
	for a in ["powershell", "networking", "servers", "security"]:
		if Crew.area_level(who, a) > Crew.area_level(who, best):
			best = a
	return best if Skills.NAMES.has(best) else "servers"


func tier(who: String) -> String:
	if Social.is_friendly(who):
		return "friend"
	return "cold" if Social.is_cold(who) else "neutral"


func start(who: String, npc: Node) -> void:
	_who = who
	_npc = npc
	var p := _player()
	if p != null:
		p.start_emote("talk", 100000.0, npc.global_position.x)
	_menu(_greeting(who))


func _player() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Actors/Player") if scene != null else null


func _bubble(glyph: String) -> void:
	if _npc != null and is_instance_valid(_npc) and _npc.get("_bubble") != null:
		_npc._bubble.glyph = glyph
		_npc._bubble.visible = true


func _menu(text: String) -> void:
	if Campaign.mode == "sales":
		_sales_menu(text)
		return
	var owner_mode := Campaign.mode == "owner"
	var service_mode := Campaign.mode == "service" and Service.has_one_on_one(_who)
	Cards.ask(
		_who,
		text,
		[
			{"label": "SMALL TALK", "id": "small"},
			{"label": "ONE ON ONE" if service_mode else ("HOW ARE YOU HOLDING UP?" if owner_mode else ("ASK THE OWNER" if Owners.asks_owner(_who) else "ASK FOR HELP")), "id": "ask"},
			{"label": "ANY IDEAS?" if owner_mode else "ANY TIPS?", "id": "tip"},
			{"label": "LEAVE (ESC)", "id": "leave"},
		],
		func(id: String) -> void: _pick(id)
	)


func _pick(id: String) -> void:
	if Campaign.mode == "sales" and (id == "ask" or id == "tip"):
		_reply(sales_answer(_who) if id == "ask" else sales_tip())
		return
	match id:
		"small":
			_reply(small_talk())
		"ask":
			if Campaign.mode == "service" and Service.has_one_on_one(_who):
				Service.one_on_one(_who, func() -> void: _menu("Anything else?"))
				return
			_reply(holding_up() if Campaign.mode == "owner" else ask_help())
		"tip":
			_reply(owner_idea() if Campaign.mode == "owner" else tip())
		_:
			_leave()


func _reply(text: String) -> void:
	Cards.ask(
		_who,
		text,
		[{"label": "OK", "id": "ok"}, {"label": "LEAVE (ESC)", "id": "leave"}],
		func(id: String) -> void: _after(id)
	)


func _after(id: String) -> void:
	if id == "leave":
		_leave()
	else:
		_menu("Anything else?")


func _leave() -> void:
	var p := _player()
	if p != null:
		p.start_emote("idle", 0.05)
	if _npc != null and is_instance_valid(_npc) and _npc.has_method("talk_end"):
		_npc.talk_end()
	_who = ""
	_npc = null


# ---- the topics --------------------------------------------------------------------------------
func small_talk() -> String:
	Social.note_chat(_who)
	var lines: Array = VIC_SMALL[_who] if (Campaign.mode == "sales" and VIC_SMALL.has(_who)) else SMALL[voice(_who)]
	var text: String = lines[randi() % lines.size()]
	_bubble(Social.glyph(_who))
	if tier(_who) == "cold":
		return "Mm. " + text.split(".")[0] + "."
	if randf() < 0.25:
		var gossip: Array = VIC_GOSSIP if Campaign.mode == "sales" else GOSSIP
		text += " " + str(gossip[randi() % gossip.size()])
	return text


func ask_help() -> String:
	var res := str(Lync.send_action(_who, "help"))
	var last := ""
	if Lync.chats.has(_who) and not Lync.chats[_who].is_empty():
		last = str(Lync.chats[_who][-1][1])
	_bubble("heart" if res == "help" and Social.is_friendly(_who) else "dots")
	return last if last != "" else "Sorry, I am swamped."


func tip() -> String:
	Social.note_chat(_who)
	_bubble("!")
	var text := _state_tip()
	if text == "":
		var pool: Array = TIPS_GENERIC[voice(_who)]
		text = pool[randi() % pool.size()]
	if tier(_who) == "cold":
		return text.split(".")[0] + ". That is all you are getting."
	var skill := specialty(_who)
	if Social.is_friendly(_who) and int(_taught.get(_who, -1)) != Campaign.day:
		_taught[_who] = Campaign.day
		Skills.add_xp(skill, LESSON_XP)
		text += " (+%d %s XP: they walk you through it.)" % [LESSON_XP, str(Skills.NAMES[skill])]
	elif not Social.is_friendly(_who):
		text += " (Get on their good side and they will teach you more.)"
	return text


# advice built from what is actually going on right now
func _state_tip() -> String:
	match _who:
		"Alan":
			for c in Sales.active:
				if not Msp.backups[int(c)].ok:
					return (
						"I was in the console before nine and %s backup is red. Check it before it matters."
						% Owner.poss(str(Msp.CLIENTS[int(c)].name))
					)
		"Dan":
			for d in range(1, 9):
				if Net.desk_state(d) != "ok":
					return (
						"%s has no network. Look at the patch panel in the closet first."
						% str(Msp.DESK_NAMES.get(d, "A desk"))
					)
		"Vic":
			var worst := -1
			for c in Sales.active:
				if worst < 0 or Sales.mood(int(c)) < Sales.mood(worst):
					worst = int(c)
			if worst >= 0 and Sales.mood(worst) < 55:
				return (
					"%s sounded annoyed when I called. Give them some attention before they start shopping around."
					% str(Msp.CLIENTS[worst].name)
				)
		"Garrison":
			if Msp.breached > 0:
				return "I walked the floor and saw the SLA misses on the board. Clients bring those up at the QBR. Fix the P1s first, always. The rest can wait ten minutes."
		"Morgan":
			if Msp.breached > 0:
				return "We have missed an SLA today. It is not a disaster. Write down what happened so the next one does not."
			if Msp.open_tickets().size() >= 4:
				return "The queue is at %d tickets. Work the P1s first and tell me if you need me to move something." % Msp.open_tickets().size()
		"Maya":
			for t in Msp.open_tickets():
				if float(t.sla_left) < 60.0 and not bool(t.breached):
					return (
						"Ticket #%d is almost out of time. I would hate for that to be a miss. Want a hand?"
						% int(t.id)
					)
	return ""


# ---- sales campaign (C3): you are Vic ------------------------------------------------------------
func _greeting(who: String) -> String:
	if Campaign.mode == "sales" and VIC_GREETINGS.has(who):
		return _fill(str(VIC_GREETINGS[who][tier(who)]))
	return str(GREETINGS[voice(who)][tier(who)])


func _sales_menu(text: String) -> void:
	var row: Dictionary = VIC_ASK.get(_who, {})
	Cards.ask(
		_who,
		text,
		[
			{"label": "SMALL TALK", "id": "small"},
			{"label": str(row.get("label", "HOW ARE THINGS?")), "id": "ask"},
			{"label": "ANY TIPS?", "id": "tip"},
			{"label": "LEAVE (ESC)", "id": "leave"},
		],
		func(id: String) -> void: _pick(id)
	)


# the unhappiest client you look after: {name, mood}
func _worst_client() -> Dictionary:
	var worst := {"name": "nobody", "mood": 100}
	for d in SalesCampaign.book:
		if int(d.mood) < int(worst.mood):
			worst = {"name": str(d.name), "mood": int(d.mood)}
	for c in Sales.active:
		if Sales.mood(int(c)) < int(worst.mood):
			worst = {"name": str(Msp.CLIENTS[int(c)].name), "mood": Sales.mood(int(c))}
	return worst


# a won deal whose promise gap is still open
func _gap_deal() -> String:
	for d in SalesCampaign.book:
		if float(d.gap) >= 0.5 and not bool(d.resolved):
			return str(d.name)
	return ""


func _fill(t: String) -> String:
	var q := SalesCampaign.quarter_index()
	var worst := _worst_client()
	var deal := _gap_deal()
	return (
		t
		. replace("{cap}", "%.1f" % SalesCampaign.capacity())
		. replace("{open}", str(Msp.open_tickets().size()))
		. replace("{pct}", str(SalesCampaign.quota_pct()))
		. replace("{weeks}", str(int(SalesCampaign.QUARTERS[q].to) - Campaign.day + 1))
		. replace("{leads}", str(SalesCampaign.open_leads().size()))
		. replace("{client}", str(worst.name))
		. replace("{mood}", str(worst.mood))
		. replace("{deal}", deal if deal != "" else "your last deal")
		. replace("{floor}", str(int(round(SalesCampaign.margin_floor * 100.0))))
		. replace("{claw}", str(SalesCampaign.clawbacks))
	)


# what a coworker answers to the question on their button (also used by Lynk's NEED A HAND)
func sales_answer(who: String) -> String:
	var row: Dictionary = VIC_ASK.get(who, {})
	var key := "good"
	match who:
		"Dan":
			var cap := SalesCampaign.capacity()
			key = "good" if cap >= 2.2 else ("tight" if cap >= 1.2 else "over")
		"Morgan":
			key = "gaps" if _gap_deal() != "" else "clean"
		"Maya":
			key = "worry" if int(_worst_client().mood) < 60 else "fine"
		_:
			key = "behind" if SalesCampaign.behind_pace() else "ahead"
	Social.note_chat(who)
	if _npc != null and is_instance_valid(_npc) and who == _who:
		_bubble("!")
	return _fill(str(row.get(key, row.get("good", "Not now."))))


func sales_tip() -> String:
	Social.note_chat(_who)
	_bubble("!")
	var text := _sales_state_tip()
	if text == "":
		var pool: Array = VIC_TIPS.get(_who, [])
		text = str(pool[randi() % pool.size()]) if not pool.is_empty() else "Sell what we can deliver."
	if tier(_who) == "cold":
		return text.split(".")[0] + ". That is all you are getting."
	return text


# advice from the live book: Dan warns about capacity, Morgan about promises, Maya about client moods, the owners about the number
func _sales_state_tip() -> String:
	var st: Dictionary = VIC_STATE.get(_who, {})
	match _who:
		"Dan":
			if SalesCampaign.capacity() < 1.8:
				return _fill(str(st.tight))
		"Morgan":
			if _gap_deal() != "":
				return _fill(str(st.gap))
		"Maya":
			if int(_worst_client().mood) < 65:
				return _fill(str(st.mood))
		"Garrison":
			return _fill(str(st.behind if SalesCampaign.behind_pace() else st.ahead))
		"Alan":
			if SalesCampaign.clawbacks > 0:
				return _fill(str(st.claw))
	return ""


# ---- owner campaign ---------------------------------------------------------------------------
func holding_up() -> String:
	var level := "low" if Owner.burnout < 30.0 else ("mid" if Owner.burnout < 60.0 else "high")
	var text: String = OWNER_HOLD[level]
	_bubble("heart")
	if int(_listened.get(_who, -1)) != Campaign.day:
		_listened[_who] = Campaign.day
		Owner.burnout = clampf(Owner.burnout - 2.0, 0.0, 100.0)
		Social.note_chat(_who)
		text += " Thanks for asking, though. It helps."
	return text


func owner_idea() -> String:
	Social.note_chat(_who)
	_bubble("!")
	var text := ""
	match _who:
		"Alan":
			text = "If you want fewer fires: patch on time and keep the backups green."
			if Msp.open_tickets().size() >= 5:
				text = "The queue is backed up. Another pair of hands would help more than a new tool."
		"Garrison":
			text = "Good call on the backups. Next, get remote access off the open internet."
			if not Owner.flags.get("backup_service", false):
				text = "Every client without a managed backup is one bad day from calling a lawyer. We should sell the backup service."
		"Morgan":
			text = "Hire before you need to, not after. Hiring takes six weeks. Burnout takes three."
			if Msp.open_tickets().size() >= 5:
				text = "The queue is backed up and the crew is running hot. I would add a pair of hands before I added a tool."
		"Dan":
			text = "Label everything and write it down. The day Alan is on vacation you will be glad."
			for c in Sales.active:
				if float(Owner.patch_debt.get(int(c), 0.0)) >= 4.0:
					text = (
						"Updates are piling up at %s. That is how somebody else's engineer ends up on their server."
						% str(Msp.CLIENTS[int(c)].name)
					)
					break
		_:
			text = "The pipeline is thin. A team night would not hurt either; the crew has not had one."
	return text
