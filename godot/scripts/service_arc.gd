extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,max-returns
# The service manager campaign, C7 (V4): the rest of the 20 day story (docs/campaign-paths.md section 4.7), the owner conflict arc,
# the Summit roll-up audit, the endings, and the Service-mode voices of Talk and Lynk. Every beat names the engine it uses:
#   cards      a Cards decision with options (SCHEDULE + ARC: day, clock time, text with {day} style tokens, options with `fx`)
#   job        a Playbook-style multi-step job: `onboard` (Iron Mule) is a Playbook book injected at run time (JOB_BOOKS)
#   wave       a project wave worked off by the crew every morning (the XP end of support wave)
#   pager      the after-hours rota: a night page card each morning from the day after the policy memo
#   hooks      Mutators and Events call kb.system_change through on_mutator / on_event (HOOKS, EVENT_HOOKS)
# Each beat has a fixed day (SCHEDULE) and a seeded variation (`ctx`: the tech, the client, the counts, +/- 15 minutes). The day
# number never appears in text: {day}, {dleft} and the others are filled in. All text tables are patchable (story/strings.txt).

const VERSION := 1
const XP_TOTAL := 14  # machines in the XP wave
const XP_FROM := 4
const XP_TO := 8  # the check day
const AUDIT_FULL_DOC := 80  # documentation % that earns the full 25 points
const SIDE_NAMES := ["Alan", "Garrison", "both"]
const OWN_KEYS := ["side", "hours", "cost", "mood_c", "stale", "tickets", "later", "credit", "wave", "oncall", "unassign", "stipend", "psa", "kb_refresh", "rollup_rec", "lane", "training", "framing", "busy", "start_job"]

const DEFAULT_SCHEDULE := {
	"heartbleed": {"day": 5, "at": 13.0},
	"heartbleed2": {"day": 6, "at": 9.4},
	"wave_adjust": {"day": 6, "at": 14.0},
	"resets": {"day": 8, "at": 10.8},
	"promo": {"day": 8, "at": 14.5},
	"wave_check": {"day": 8, "at": 15.6},
	"margin": {"day": 10, "at": 11.0},
	"onboard": {"day": 12, "at": 9.6},
	"cutcost": {"day": 12, "at": 15.2},
	"stipend": {"day": 14, "at": 13.0},
	"psa": {"day": 16, "at": 9.3},
	"escalation": {"day": 17, "at": 15.0},
	"rollup": {"day": 19, "at": 15.0},
}
var SCHEDULE: Dictionary = DEFAULT_SCHEDULE.duplicate(true)

# the cards. text tokens: {day} {dleft} {who} {senior} {junior} {client} {n} {m} {cpt} {cost} {done} {total} {left} {strain} {pct}
# option keys: id, label, text (the reply), fx, need (["hours:1", "doc:25", "trust2:40", "conf:45", "nolive:password"])
const DEFAULT_ARC := {
	"heartbleed":
	{
		"speaker": "Garrison (Co-owner)",
		"text": "Heartbleed is all over the news. {n} clients have called to ask if they are safe and {m} certificate checks are on the board. I want an email to every client within the hour, so nobody reads about it before they hear it from us. Alan is standing behind me with a different idea.",
		"options":
		[
			{"id": "patch", "label": "PATCH FIRST, EMAIL AFTER", "text": "Servers first. The email goes out when the patch list is green. Garrison asked how long that is. I said the afternoon.", "fx": {"trust": {"Alan": 5, "Garrison": -4}, "side": "Alan", "mood_c": -2, "flag": "hb_patch", "buff": ["miss", -0.02, 3]}},
			{"id": "email", "label": "EMAIL THE CLIENTS NOW", "text": "The email went out before eleven, signed by the desk: we are aware, we are checking, we will report. Garrison forwarded it to John.", "fx": {"trust": {"Garrison": 5, "Alan": -4}, "side": "Garrison", "mood_c": 3, "flag": "hb_email"}},
			{"id": "both", "label": "HOLDING EMAIL AND ORDER", "need": ["hours:1"], "text": "Two lines to the clients: we are checking, you will hear from us by five. And a patch order for Alan: servers, then websites, then desktops. It took an hour. Both of them initialled it.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "side": "both", "hours": 1, "morale": -2, "flag": "hb_both"}},
		],
	},
	"heartbleed2":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": {
			"hb_patch": "Alan's patch list is green. {n} clients wrote this morning to ask why they heard nothing for a day. John is apologising on the phone. Garrison would like you to know he said so.",
			"hb_email": "After the email, {n} clients called to ask whether we had patched yet. The honest answer was: not yet. Alan has been quiet about the email, which is worse than loud.",
			"hb_both": "The holding email worked. The clients got the patch report at five and two of them said thank you. Alan and Garrison both asked for a copy of the template.",
			"none": "Heartbleed week is a long one. The certificate checks are still coming in. Keep writing down what you checked.",
		},
		"options": [{"id": "ok", "label": "NOTED", "text": "", "fx": {}}],
	},
	"wave_adjust":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "XP wave check: {done} of {total} machines are done, {left} left, and the deadline is the end of day {deadline}. {strain} How do you want to spend the rest of the week?",
		"options":
		[
			{"id": "pull", "label": "PUT {junior} ON THE WAVE", "text": "{junior} takes the wave full time. The phones go to whoever is free, and I will watch the first response times.", "fx": {"wave": {"rate": 1.5}, "morale_who": {"{junior}": -2}, "buff": ["speed", 0.97, 2]}},
			{"id": "sat", "label": "A SATURDAY SESSION, VOLUNTEERS", "text": "A Saturday morning session, volunteers only, pizza at noon. Four machines done. Nobody was told they had to come.", "fx": {"wave": {"add": 4.0}, "morale": -4, "retain_all": -1, "trust": {"Alan": 1, "Garrison": 0}}},
			{"id": "keep", "label": "KEEP THE PACE", "text": "We keep the pace. I wrote down the machines that are left and who owns each one.", "fx": {}},
		],
	},
	"resets":
	{
		"speaker": "Alan (Co-owner)",
		"text": "{senior} has spent the morning on password resets: {n} of them, with me covering tier one calls between server jobs. A senior on a reset is a waste of both of us. Garrison says a reset takes thirty seconds and clients love a human voice.",
		"text_live": "The reset runbook is working. I went back to my servers at nine and {junior} took {n} resets from the notes. Thank you for writing it down.",
		"options":
		[
			{"id": "tier", "label": "TIER IT: RESETS GO TO {junior}", "text": "Resets go to {junior}. {senior} takes the harder tickets and nobody calls Alan for a password again.", "fx": {"trust": {"Alan": 4, "Garrison": -1}, "side": "Alan", "morale_who": {"{senior}": 4}, "buff": ["speed", 1.04, 3], "flag": "resets_tier"}},
			{"id": "doc", "label": "WRITE THE RUNBOOK NOW", "need": ["hours:1", "nolive:password"], "text": "One page: verify the caller, reset, force a change, log it. {junior} can follow it without asking anyone. It took an hour.", "fx": {"trust": {"Alan": 3, "Garrison": 1}, "side": "both", "hours": 1, "kb_publish": "password", "flag": "resets_doc"}},
			{"id": "cover", "label": "ALAN KEEPS COVERING THE PHONES", "text": "Alan keeps the phones for now. He did not argue. He wrote the number of server jobs he postponed on the whiteboard.", "fx": {"trust": {"Alan": -2, "Garrison": 2}, "side": "Garrison", "morale_who": {"{senior}": -1}, "flag": "resets_alan"}},
		],
		"options_live": [{"id": "ok", "label": "GLAD IT HELPS", "text": "", "fx": {"trust": {"Alan": 3}, "flag": "resets_live"}}],
	},
	"promo":
	{
		"speaker": "{junior} (Tier 1)",
		"text": "Dan, do you have a minute? I have closed {done} tickets this week and I would like the Tier 2 title and the pay that goes with it. I am not asking for a speech. I am asking for an answer.",
		"options":
		[
			{"id": "p", "label": "PROMOTE ($80 A WEEK)", "text": "Thank you, Dan. I will not let the board down. Can I take the next server ticket?", "fx": {"promote": true, "wage": 80, "morale": 8, "retain": 3, "trust": {"Alan": 1, "Garrison": 0}}},
			{"id": "l", "label": "YES, WITH A PLAN", "text": "A plan is fair. Write down what I have to show, and the date.", "fx": {"focus_area": true, "morale": 3, "retain": 2}},
			{"id": "m", "label": "ASK MORGAN FOR THE BUDGET", "text": "Fine. Morgan has until Friday. I would rather hear no than hear nothing.", "fx": {"morale": -1, "retain": 0, "conf": 0}},
			{"id": "n", "label": "NOT YET", "text": "Okay. I hoped for a different answer. I will keep closing tickets.", "fx": {"morale": -5, "retain": -2}},
		],
	},
	"wave_check":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": {
			"done": "The XP wave is finished: {done} of {total} machines migrated before the deadline. Alan checked the list twice and found nothing. He said it was well done, which from Alan is a parade.",
			"most": "The XP wave reached {pct} percent. {left} machines are still on XP, mostly at clients who said the old PC was fine. Alan has asked who is going to explain that to their insurance company.",
			"low": "The XP wave stopped at {pct} percent. {left} machines are still running XP after the deadline and one of them has already caught something. Alan has the list. Garrison has the phone calls.",
		},
		"options": [{"id": "ok", "label": "I WILL OWN IT", "text": "", "fx": {}}],
	},
	"margin":
	{
		"speaker": "Alan (Co-owner)",
		"text": "Garrison signed {client} at {pct} percent under list for the logo, with a two hour response. Our cost per ticket is {cpt} and the deal does not clear it. Garrison says a name like that opens doors. Someone has to tell the desk what the SLA is.",
		"options":
		[
			{"id": "full", "label": "HONOUR IT: FULL SERVICE", "text": "Two hours, full service, the logo goes on the wall. I added their tickets to the board and I will report the hours every Friday.", "fx": {"trust": {"Garrison": 6, "Alan": -5}, "side": "Garrison", "mood_c": 4, "buff": ["issues", 1.05, 4], "morale": -2, "flag": "logo_full"}},
			{"id": "std", "label": "STANDARD SLA, STANDARD RULES", "text": "Standard response, standard rules. The discount buys the logo, not the queue. John will tell them kindly.", "fx": {"trust": {"Alan": 6, "Garrison": -5}, "side": "Alan", "mood_c": -3, "flag": "logo_std"}},
			{"id": "broker", "label": "BROKER A TWO YEAR DEAL", "need": ["trust2:40", "hours:1"], "text": "The discount stands if they sign two years and a scope page. Garrison keeps the logo, Alan keeps the margin. Both of them asked me to write it down.", "fx": {"trust": {"Alan": 3, "Garrison": 3}, "side": "both", "hours": 1, "flag": "logo_broker"}},
		],
	},
	"cutcost":
	{
		"speaker": "Alan (Co-owner)",
		"text": "The numbers came back. The desk costs {cost} a week and Morgan has asked for a cut of ten percent. I have a list: the training budget, the extra hours and the pod stipends. Garrison says people are the company and the answer is revenue, not cuts.",
		"options":
		[
			{"id": "cut", "label": "CUT TRAINING AND EXTRA HOURS", "text": "Training stops and the extra hours are by approval only. I told the crew myself, before the rumour.", "fx": {"trust": {"Alan": 5, "Garrison": -4}, "side": "Alan", "training": "none", "morale": -4, "retain_all": -1, "flag": "cut_training"}},
			{"id": "keep", "label": "NO CUTS: BRING THE REVENUE", "text": "No cuts this month. John and Garrison bring a signed deal, or the list comes back. Morgan wrote the date in her notebook.", "fx": {"trust": {"Garrison": 5, "Alan": -4}, "side": "Garrison", "morale": 2, "conf": -1, "flag": "no_cut"}},
			{"id": "small", "label": "A SMALLER, FAIR CUT", "need": ["doc:25", "hours:1"], "text": "Training drops to light, the pod stipends stay, and I attached the cost per ticket to the proposal. Alan and Garrison each lost something.", "fx": {"trust": {"Alan": 2, "Garrison": 2}, "side": "both", "hours": 1, "training": "light", "flag": "cut_small"}},
		],
	},
	"stipend":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "The after-hours policy is decided, so what does a night call pay? Last night's email outage cost {who} a night of sleep. Fair is a number everyone can see on the board.",
		"options":
		[
			{"id": "0", "label": "NOTHING: IT IS IN THE JOB", "text": "No stipend. I wrote the rota on the board and I will cover the first page myself.", "fx": {"trust": {"Alan": 1, "Garrison": -2}, "stipend": 0, "morale": -3}},
			{"id": "40", "label": "$40 A NIGHT, ON THE BOARD", "text": "$40 a night, posted in the kitchen with the rota. Anyone can read the arithmetic.", "fx": {"stipend": 40, "morale": 2, "trust": {"Alan": 0, "Garrison": 1}}},
			{"id": "80", "label": "$80 A NIGHT PLUS A MORNING OFF", "text": "$80 and a late start after a page. Garrison liked it. Christy asked me for the arithmetic.", "fx": {"stipend": 80, "morale": 4, "trust": {"Alan": -1, "Garrison": 2}}},
		],
	},
	"psa":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "The ServiceBeacon PSA goes live today. The vendor says migration takes the morning, every ticket field is mapped differently and the old board goes read-only at noon. How do we cut over?",
		"options":
		[
			{"id": "big", "label": "CUT OVER AT ONCE", "text": "We cut over at nine. Tickets lost their assignees in the move and the portal rejected a few logins. I am rebuilding the board by hand.", "fx": {"psa": "big", "unassign": 0.5, "tickets": {"prob": "psa_lost", "n": [2, 3]}, "morale": -3, "buff": ["speed", 0.92, 2], "trust": {"Alan": -2, "Garrison": 0}, "flag": "psa_big"}},
			{"id": "par", "label": "RUN BOTH BOARDS A DAY", "need": ["hours:1"], "text": "Both boards run today and we compare the counts at five. It is slower and nothing falls through.", "fx": {"psa": "parallel", "hours": 1, "buff": ["speed", 0.96, 1], "trust": {"Alan": 2, "Garrison": 0}, "flag": "psa_parallel"}},
			{"id": "train", "label": "TRAIN, THEN CUT OVER", "need": ["hours:2"], "text": "A two hour walkthrough, then the cut over at four. The training doubled as a runbook review: a stale page got fixed on the way.", "fx": {"psa": "trained", "hours": 2, "morale": 3, "kb_refresh": 1, "buff": ["speed", 0.97, 1], "trust": {"Alan": 1, "Garrison": 1}, "flag": "psa_trained"}},
		],
	},
	"escalation":
	{
		"speaker": "Garrison (Co-owner)",
		"text": "{client} has gone over your head. Their owner called us both: they want a dedicated senior for a month and a credit on this invoice, or they take the contract elsewhere. Alan says the contract says what it says. I say the client is always right until they are not. You have to answer them before five.",
		"options":
		[
			{"id": "give", "label": "CREDIT AND A DEDICATED SENIOR", "text": "A credit on the invoice and a named senior for a month. The client was glad. Alan did not say anything, loudly.", "fx": {"trust": {"Garrison": 8, "Alan": -7}, "side": "Garrison", "mood_c": 10, "credit": 1, "morale": -3, "flag": "esc_give"}},
			{"id": "hold", "label": "HOLD THE LINE: THE CONTRACT SAYS", "text": "I sent the scope section, the response times and the hours they used. Alan was pleased. The client said they would think about it.", "fx": {"trust": {"Alan": 8, "Garrison": -7}, "side": "Alan", "mood_c": -8, "flag": "esc_hold"}},
			{"id": "broker", "label": "BROKER A COMPROMISE", "need": ["trust2:40", "conf:45", "hours:1"], "text": "A one-time credit, a Friday check-in and a scope review in thirty days. Neither owner got what they asked for. The client agreed.", "fx": {"trust": {"Alan": 3, "Garrison": 3}, "side": "both", "mood_c": 3, "hours": 1, "credit": 1, "flag": "esc_broker"}},
		],
	},
	"rollup":
	{
		"speaker": "Morgan Reyes (Manager)",
		"text": "Summit Managed Holdings' integration lead, {auditor}, has finished with the desk. Documentation {doc_pts} of 25, retention {ret_pts}, SLA {sla_pts}, clawbacks {claw_pts}: {total} of 100. {offer} Garrison wants to sell and Alan wants to stay independent. What do you tell them?",
		"options":
		[
			{"id": "sell", "label": "RECOMMEND SELLING TO SUMMIT", "need": ["offer:1"], "text": "I told the owners the desk is worth what Summit is paying and the team would be looked after. Garrison thanked me. Alan asked for the audit sheet.", "fx": {"trust": {"Garrison": 6, "Alan": -5}, "rollup_rec": "sell"}},
			{"id": "stay", "label": "RECOMMEND STAYING INDEPENDENT", "text": "I told them the desk is better as it is than as a line in somebody else's spreadsheet. Alan nodded once. Garrison stared at the table.", "fx": {"trust": {"Alan": 6, "Garrison": -5}, "rollup_rec": "stay"}},
			{"id": "none", "label": "GIVE THEM THE SHEET, NO ADVICE", "text": "I handed both of them the same page and left. It is their company. Morgan said it was the most honest thing she had seen from the desk.", "fx": {"trust": {"Alan": 1, "Garrison": 1}, "rollup_rec": "none"}},
		],
	},
	"audit_extra":
	{
		"speaker": "Summit audit",
		"text": "Summit's integration lead, {auditor}, will read the scorecard: documentation {doc_pts} of 25, retention {ret_pts}, SLA {sla_pts}, clawbacks {claw_pts}. {total} of 100 as it stands today.",
	},
}
var ARC: Dictionary = DEFAULT_ARC.duplicate(true)

# the Iron Mule onboarding (a Playbook book; injected into Playbook.BOOKS while a service campaign runs)
const DEFAULT_JOB_BOOKS := {
	"onboard":
	{
		"title": "IRON MULE ONBOARDING",
		"client": 10,
		"specials": ["onboard"],
		"steps":
		[
			{
				"title": "DISCOVERY",
				"text": "Iron Mule Demolition has two trailers, nine users and no documentation at all. John promised them they would be live in a day. Where do you start?",
				"choices":
				[
					{"label": "WALK THE SITE WITH THE FOREMAN", "secs": 8.0, "pts": 20, "hours": 1.0, "flag": "walked", "note": "Two trailers, a hub under a desk and a printer nobody owns. Everything is on your clipboard."},
					{"label": "SEND A DISCOVERY QUESTIONNAIRE", "secs": 4.0, "pts": 12, "hours": 0.3, "flag": "questionnaire", "note": "Half the answers come back blank. The other half say 'ask Ray'."},
					{"label": "SKIP IT: THEY SAID IT IS SIMPLE", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "blind", "note": "You go in blind. Nobody knows what is plugged into what."},
				]
			},
			{
				"title": "CREDENTIALS",
				"text": "The only passwords are on a yellow sticky note and in Ray's head. The admin account is shared by the whole office.",
				"choices":
				[
					{"label": "COLLECT EVERY CREDENTIAL INTO THE VAULT", "secs": 6.0, "pts": 20, "hours": 0.6, "flag": "vault", "note": "Every login is in the vault, tagged by owner. The sticky note is in the shredder."},
					{"label": "USE THE SHARED ADMIN ACCOUNT FOR NOW", "secs": 2.0, "pts": 5, "hours": 0.1, "flag": "shared", "note": "It works. Anyone in the office can still do the same."},
					{"label": "ASK EVERYONE TO EMAIL THEIR PASSWORD", "secs": 1.0, "pts": 0, "hours": 0.1, "flag": "leak", "note": "Nine passwords arrive by email. One of them is 'password1'."},
				]
			},
			{
				"title": "BACKUPS",
				"text": "A green checkmark says the nightly backup works. Nobody has ever restored from it.",
				"choices":
				[
					{"label": "TEST A RESTORE BEFORE ANYTHING ELSE", "secs": 8.0, "pts": 20, "hours": 0.8, "flag": "restore_tested", "note": "The restore worked on the second try. The first try found a missing folder."},
					{"label": "START A NEW BACKUP RIGHT AWAY", "secs": 5.0, "pts": 12, "hours": 0.4, "flag": "backup_new", "note": "A fresh backup is running. You will know in the morning if it works."},
					{"label": "TRUST THE GREEN CHECKMARK", "secs": 0.0, "pts": 5, "hours": 0.0, "flag": "backup_trust", "note": "It looks fine. Looking is all anyone has done."},
				]
			},
			{
				"title": "THE UNLABELLED SERVER",
				"text": "A tower server hums under a desk with no label, no owner and a post-it that says DO NOT TURN OFF. Nobody knows what it does.",
				"choices":
				[
					{"label": "TRACE THE CABLES AND LABEL IT", "secs": 8.0, "pts": 20, "hours": 0.6, "flag": "labelled", "note": "It is the file server and the badge reader. It is labelled now, in your handwriting."},
					{"label": "LEAVE IT ALONE AND WRITE IT DOWN", "secs": 3.0, "pts": 10, "hours": 0.2, "flag": "noted", "note": "Logged as 'unknown server, do not touch', with the date and the post-it."},
					{"label": "SHUT IT DOWN TO SEE WHAT BREAKS", "secs": 2.0, "pts": 0, "hours": 0.2, "flag": "broke", "note": "The badge reader and the label printer stopped. So did Ray's mood."},
				]
			},
			{
				"title": "THE SHARED ADMIN PASSWORD",
				"text": "Everyone in the office logs in as the same administrator. A former dispatcher still knows the password.",
				"choices":
				[
					{"label": "NAMED ACCOUNTS AND A SEALED ENVELOPE", "secs": 8.0, "pts": 20, "hours": 0.6, "flag": "named", "note": "Everyone has their own login. The admin password lives in a sealed envelope in Ray's safe."},
					{"label": "ONE NEW SHARED PASSWORD", "secs": 3.0, "pts": 5, "hours": 0.2, "flag": "newshared", "note": "A new password, the same shared account. The dispatcher no longer knows it. Everyone else does."},
					{"label": "LEAVE IT UNTIL NEXT WEEK", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "left", "note": "It is on next week's list. It will be on the list next week too."},
				]
			},
			{
				"title": "HAND IT OVER",
				"text": "Time to leave. Sam will be the one answering when they call.",
				"choices":
				[
					{"label": "A ONE PAGE DOC AND A WALKTHROUGH FOR SAM", "secs": 6.0, "pts": 20, "hours": 0.5, "flag": "documented", "note": "One page: where everything is, who owns it, what to call. Sam read it twice."},
					{"label": "EMAIL THE NOTES TO THE TEAM", "secs": 3.0, "pts": 8, "hours": 0.1, "flag": "emailed", "note": "The notes are in everybody's inbox and nowhere else."},
					{"label": "NOTHING: IT IS ALL IN YOUR HEAD", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "undocumented", "note": "You are now the only person who knows how Iron Mule works. You have been here before."},
				]
			},
		],
	},
}
var JOB_BOOKS: Dictionary = DEFAULT_JOB_BOOKS.duplicate(true)

const DEFAULT_JOB_PROBLEMS := {
	"onboard":
	[
		{"summary": "NEW CLIENT: Iron Mule Demolition onboarding", "fix": "project", "pri": 3, "special": "onboard", "body": "We start with you today and there is nothing written down. Ray says he is the only one who knows the network. Please come and meet him. - %s"},
		{"summary": "Iron Mule: main PC will not join the network", "fix": "project", "pri": 3, "special": "onboard", "body": "Ray's PC in the trailer cannot reach the shared folder. He says it worked last week. - %s"},
	],
}
var JOB_PROBLEMS: Dictionary = DEFAULT_JOB_PROBLEMS.duplicate(true)

# tickets the story creates: summary, fix, pri, server, body (% = the contact's first name)
const DEFAULT_PROBS := {
	"hb_cert": {"summary": "Heartbleed: check the server certificate", "fix": "reboot", "pri": 2, "server": true, "body": "The news says our website and mail server might be affected. Please check the certificate and restart the services after the patch. A customer already asked me about it. - %s"},
	"hb_called": {"summary": "Did you patch yet? (Heartbleed)", "fix": "password", "pri": 2, "body": "You emailed us this morning that you were checking. We changed our passwords because of the news and now one of us is locked out. Can you reset hers? And did you patch? - %s"},
	"xp_hit": {"summary": "Old XP machine is acting strange", "fix": "av", "pri": 2, "body": "The old PC in the back office, the one that was supposed to be replaced, is popping up windows I have never seen. I did not click anything. Probably. - %s"},
	"onb_leak": {"summary": "Iron Mule: someone logged in as admin last night", "fix": "password", "pri": 2, "body": "Ray says the administrator login was used at eleven last night and none of us were here. Can you look at this? - %s"},
	"onb_broke": {"summary": "Iron Mule: badge reader and label printer are dead", "fix": "reboot", "pri": 2, "server": true, "body": "Since yesterday nobody can badge in and nothing prints labels. Ray thinks it is your server thing. - %s"},
	"psa_lost": {"summary": "My ticket disappeared after the new system", "fix": "password", "pri": 3, "body": "The new portal sent me a password that does not work and my open ticket is gone. Can you reset it and find the old one? - %s"},
	"pager_issue": {"summary": "After hours: server alert", "fix": "reboot", "pri": 3, "server": true, "body": "Our alert went off overnight and your on-call person looked at it. Please make sure it is really fixed. - %s"},
}
var PROBS: Dictionary = DEFAULT_PROBS.duplicate(true)

# systems change: Mutators and Events call kb.system_change through on_mutator / on_event
const DEFAULT_HOOKS := {
	"xp_eol": {"classes": ["reboot", "clear_temp", "av"], "pick": 2, "subject": "XP end of support", "body": "XP is out of support and the replacement machines are Windows 7. Every fix we wrote for the old boxes behaves differently."},
	"heartbleed": {"classes": ["password", "av", "restore"], "pick": 2, "subject": "Heartbleed", "body": "Every certificate and password policy changed this week. The pages that told the crew what to say to clients are out of date."},
	"new_psa": {"classes": ["spooler", "password", "reboot", "clear_temp", "adobe", "av", "restore"], "pick": 3, "subject": "The new PSA", "body": "The ticket system changed. The screenshots and field names in the runbooks do not match the new board."},
}
var HOOKS: Dictionary = DEFAULT_HOOKS.duplicate(true)

const DEFAULT_EVENT_HOOKS := {
	"xp_panic": {"classes": ["reboot", "clear_temp"], "pick": 1, "subject": "More XP machines", "body": "A client replaced its XP machines on its own, with different settings."},
	"copier_lease": {"classes": ["spooler", "adobe"], "pick": 1, "subject": "A new copier lease", "body": "A client leased new copiers. The drivers and the scan-to-email set-up changed."},
	"office_move": {"classes": ["spooler", "reboot"], "pick": 1, "subject": "A client moved offices", "body": "A client moved offices. The network and the printers are not where the notes say."},
	"licence_audit": {"classes": ["av"], "pick": 1, "subject": "A licence audit", "body": "A licence audit replaced the antivirus on a few machines."},
	"first_chromebook": {"classes": ["password"], "pick": 1, "subject": "Chromebooks", "body": "A client bought Chromebooks. Resets work differently for them."},
	"dropbox_it": {"classes": ["restore"], "pick": 1, "subject": "Files in the cloud", "body": "A client moved its files into a sync service. Restoring a folder is no longer what the notes say."},
}
var EVENT_HOOKS: Dictionary = DEFAULT_EVENT_HOOKS.duplicate(true)

# who asks what: Alan about quality, Garrison about clients, Morgan about the scorecard. {doc} {ret} {sla} {mood} {conf} {cpt} {grade} {open}
const DEFAULT_QUESTIONS := {
	"Alan":
	[
		{"text": "Quick one. How much of the desk is written down, and which pages have gone stale? I would rather hear it from you than find it at two in the morning.", "options": [{"label": "{doc} PERCENT, STALE ONES LISTED", "reply": "Good. Send me the list of stale pages tonight. I will read them on the train.", "fx": {"trust": {"Alan": 2}}}, {"label": "I WILL HAVE IT BY FRIDAY", "reply": "Friday. Written down, please.", "fx": {}}, {"label": "THE CLIENTS COME FIRST THIS WEEK", "reply": "They always do. Until the page is missing.", "fx": {"trust": {"Alan": -1}}}]},
		{"text": "Reopens. I count them every night. Which tickets keep coming back, and what are you doing about them?", "options": [{"label": "THREE CLASSES: RUNBOOKS NEXT", "reply": "Three classes, three runbooks. That is a plan.", "fx": {"trust": {"Alan": 2}}}, {"label": "ONE TECH CLOSES TOO EARLY", "reply": "Then slow them down. A closed ticket that reopens is two tickets.", "fx": {"trust": {"Alan": 1}}}, {"label": "WE ARE BUSY", "reply": "Busy is not a number.", "fx": {"trust": {"Alan": -1}}}]},
		{"text": "If I put another senior on the desk tomorrow, would the process hold, or would they just do whatever they remember?", "options": [{"label": "THEY WOULD READ THE RUNBOOKS", "reply": "That is exactly what I wanted to hear.", "fx": {"trust": {"Alan": 2}}}, {"label": "THEY WOULD ASK TERRY", "reply": "So Terry is the process. That is a risk.", "fx": {"trust": {"Alan": -1}}}, {"label": "THEY WOULD NEED A WEEK", "reply": "A week is fair. Make it five days.", "fx": {}}]},
	],
	"Garrison":
	[
		{"text": "How are our clients feeling this week? Not the dashboard. The real answer. Mood is {mood} on the sheet and I know it is not the same thing.", "options": [{"label": "BIG THREE HAPPY, ONE WATCHING", "reply": "Which one is watching? I will take them to lunch.", "fx": {"trust": {"Garrison": 2}}}, {"label": "THEY WANT FASTER ANSWERS", "reply": "Faster is a feeling. I can sell a feeling.", "fx": {"trust": {"Garrison": 1}}}, {"label": "THE NUMBERS ARE FINE", "reply": "The numbers are always fine. Then someone leaves.", "fx": {"trust": {"Garrison": -1}}}]},
		{"text": "If John brings me a deal tomorrow that needs a yes in an hour, can I say yes? Tell me honestly what the desk can carry.", "options": [{"label": "ONE MORE CLIENT, NOT TWO", "reply": "One. I will pick the good one.", "fx": {"trust": {"Garrison": 2}}}, {"label": "ASK ME FIRST, ALWAYS", "reply": "Ask first. Fine. I will try.", "fx": {"trust": {"Garrison": -1, "Alan": 1}}}, {"label": "YES, AND WE FIND THE HOURS", "reply": "That is what I like about you, Dan. Mostly.", "fx": {"trust": {"Garrison": 2, "Alan": -1}}}]},
		{"text": "The team is the company. Are they happy? When did you last do a one on one?", "options": [{"label": "THIS WEEK, WITH EVERYONE", "reply": "Good. Keep it up. People remember being asked.", "fx": {"trust": {"Garrison": 2}}}, {"label": "MAYA YES, THE REST NOT YET", "reply": "Do the rest. Today if you can.", "fx": {}}, {"label": "THE BOARD TAKES MY DAY", "reply": "The board will still be there tomorrow. People will not always be.", "fx": {"trust": {"Garrison": -1}}}]},
	],
	"Morgan":
	[
		{"text": "Your scorecard grade yesterday was {grade}. SLA {sla} percent. If I took that to the owners this afternoon, what would you want me to add?", "options": [{"label": "THE CAUSE OF MISSES, IN WRITING", "reply": "Send it before four. I will attach it.", "fx": {"conf": 1}}, {"label": "THE GOOD DAYS COUNT TOO", "reply": "They do. Bring me the trend, not a single day.", "fx": {}}, {"label": "NOTHING, IT SPEAKS FOR ITSELF", "reply": "Scorecards do not speak. People do. Learn that.", "fx": {"conf": -1}}]},
		{"text": "Cost per ticket is {cpt} and Christy is asking. What is the one thing that would lower it without hurting the team?", "options": [{"label": "MORE RUNBOOKS, FEWER ESCALATIONS", "reply": "That is the first answer that did not involve firing someone.", "fx": {"conf": 1}}, {"label": "A BETTER SENIOR AND JUNIOR MIX", "reply": "Show me the mix. I will bring it to the owners.", "fx": {}}, {"label": "I NEED TO CHECK THE NUMBERS", "reply": "Then check them. I will ask again on Friday.", "fx": {}}]},
		{"text": "Alan and Garrison both asked me to ask you the same thing in different words. Who do you work for?", "options": [{"label": "THE DESK AND THE CLIENTS", "reply": "Say that to both of them. Separately. Same words.", "fx": {"conf": 1}}, {"label": "WHOEVER IS RIGHT THAT DAY", "reply": "That is how you end up working for nobody.", "fx": {"conf": -1}}, {"label": "YOU, MORGAN", "reply": "Flattering. Not an answer.", "fx": {}}]},
	],
}
var QUESTIONS: Dictionary = DEFAULT_QUESTIONS.duplicate(true)

# Talk (small talk, tips) and Lynk lines in Service mode. The keys are the people; "hire" is anyone you hired.
const DEFAULT_VOICES := {
	"small":
	{
		"Maya": ["I labelled my monitor cables. Terry noticed. He said nothing, but he nodded.", "Did you see the XP boxes at Acme? One of them has a sticker from 2006.", "Can I ask you something later? It is about the Tier 2 stuff. Not urgent. A little urgent.", "Sam is great on the phones. I just wish he would write his notes down."],
		"Sam": ["The password resets are fine. It is when they call twice that I get nervous.", "I read the runbook for spooler problems on the train. I did not know you could do that.", "Terry lent me his good headset. Now I have to be good.", "Do you think I could do tier two one day? Not now. One day."],
		"Terry": ["I have been doing this for eleven years. I have never had a manager who asked what I thought.", "The pager is not the problem. It is the not knowing when.", "Somebody should label that rack at Gnarly. I would. If anyone asked me.", "Quiet day. I do not trust quiet days."],
		"hire": ["Is it always this busy? I am not complaining. I am just taking notes.", "The runbooks are good. At my last job we had a binder. Nobody knew where it was.", "I do not want to be the new guy twice. Can I take a ticket on my own today?", "Everyone here says please. It is unsettling."],
		"John": ["Dan, buddy. The prospect wants a two hour response. I said we are flexible. Are we flexible?", "I told them you are the most careful man in the building. They did not hear 'careful'. They heard 'expensive'.", "Between us: I promise what I think you can deliver. Mostly.", "If you ever want to sit in on a pitch, you can be the quiet one. You would be good at it."],
		"Morgan": ["Alan and Garrison were in my office again. They wanted me to settle something. I told them to ask you.", "Your scorecard is the first one I read in the morning. Do not let that go to your head.", "If you need something, ask on Friday. If it is on fire, ask now.", "I was a tech once. I miss the part where nobody asked me about budgets."],
		"Alan": ["I had a client ask if we were 'doing the Heartbleed thing'. I said no. We were doing the whole thing.", "Documentation is the only part of this job that is still there on Monday.", "When this desk is quiet I know it is working. Do not tell Garrison.", "A good process is boring. I am trying to get everything boring."],
		"Garrison": ["I brought donuts to Brightside this morning. They asked about the SLA. Then they ate the donuts.", "People remember how fast you answered, not how right you were. I am half joking.", "Alan thinks I only care about logos. I care about clients. The logo is just where they put their name.", "If you ever want a bigger desk, bring me a number and a plan."],
	},
	"tips":
	{
		"Maya": ["Sam gets stuck on security tickets. If you put the antivirus ones on my side he will stop avoiding the board.", "The ticket you keep reopening has the same cause every time. Write it down once and the next person will not have to ask me."],
		"Sam": ["I wait too long before I tell you I am stuck. Ask me at noon, not at four.", "Terry is stuck on the pager more than anyone says. He will not tell you. You have to ask."],
		"Terry": ["Never assign Sam a server ticket on a Monday. He doubts himself. Give him a password reset first.", "The best runbooks are the ones the author did not want to write. Ask who hated a ticket."],
		"hire": ["The first week I was afraid to ask. A runbook is somebody saying it is okay to not know.", "I do my best work when I know who to ask. Tell me who to ask."],
		"John": ["Garrison cares about the clients who threaten to leave. Alan about the ones who never complain. They are not the same list.", "Tell me what the desk can really take. I would rather lose a deal than lie to a client."],
		"Morgan": ["Both owners trust you when you tell them no with a number. Neither trusts you when you say yes with a feeling.", "Bring me a plan on Friday, not a problem."],
		"Alan": ["If a page in the knowledge base is more than a month old, assume it is wrong. Systems change.", "A tech who is stuck does not need rescue. They need a page."],
		"Garrison": ["Clients like to hear a name. Give them one tech who knows them.", "Do something nice for the crew this week. It always shows in the numbers a month later."],
	},
	"lync":
	{
		"Maya": [
			{"text": "Dan, can I take the next server ticket? I have been reading about it.", "options": [{"label": "YES, I WILL WATCH", "social": 2, "morale": 3, "reply": "Thanks! I will write down what I did."}, {"label": "NOT TODAY, THE QUEUE IS HOT", "social": 0, "reply": "Okay. Tomorrow?"}]},
			{"text": "The reset runbook is out of date. The new rules say twelve characters. Do you want me to fix it?", "options": [{"label": "YES, PLEASE", "social": 2, "reply": "On it. I will tag you for the review."}, {"label": "LET ME DO IT TONIGHT", "social": 0, "reply": "Okay, I will leave it."}]},
		],
		"John": [
			{"text": "Garrison wants me to promise the prospect a two hour response. Can the desk do two hours?", "options": [{"label": "FOUR HOURS, TWO FOR URGENT", "social": 1, "reply": "Four and two. I will make it sound like a feature."}, {"label": "ASK ME AFTER THE AUDIT", "social": 0, "reply": "After the audit. Noted."}]},
			{"text": "Heads up: a client is unhappy and has my number on speed dial. I am sending them to you.", "options": [{"label": "SEND THEM, I WILL CALL BACK", "social": 2, "reply": "You are a good man, Dan."}, {"label": "WRITE IT DOWN, I WILL CHECK", "social": 0, "reply": "I wrote it on a napkin. It is fine."}]},
		],
		"Morgan": [
			{"text": "Friday: bring your scorecard and one thing you will fix. One.", "options": [{"label": "THE STALE RUNBOOKS", "social": 1, "conf": 1, "reply": "Good. Specific."}, {"label": "THE ESCALATIONS", "social": 1, "reply": "Fine. Show me the count."}]},
		],
		"Alan": [
			{"text": "I saw a ticket close with no note. Who closed it?", "options": [{"label": "I WILL ASK AND FIX IT", "social": 2, "trust": 1, "reply": "Thank you. A closed ticket with no note is a future ticket."}, {"label": "THE CREW IS DOING THEIR BEST", "social": 0, "reply": "Their best needs a template."}]},
		],
		"Garrison": [
			{"text": "Who is our happiest client right now? I want to ask them for a reference.", "options": [{"label": "ACME. ASK THEM", "social": 2, "trust": 1, "reply": "Perfect. I will bring pastries."}, {"label": "ASK ME AFTER THE REVIEW", "social": 0, "reply": "Sure. Soon, though."}]},
		],
		"Sam": [
			{"text": "Dan? I am stuck on the VPN ticket. I did not want to ask in front of everyone.", "options": [{"label": "COME OVER, WE DO IT TOGETHER", "social": 2, "morale": 3, "reply": "Thank you. I will write it down."}, {"label": "READ THE RUNBOOK FIRST", "social": 0, "reply": "Okay. I will try."}]},
		],
		"Terry": [
			{"text": "The pager went off twice last night. I fixed it. I just wanted somebody to know.", "options": [{"label": "THANK YOU. TAKE A SLOW MORNING", "social": 2, "morale": 4, "reply": "I will. Thanks."}, {"label": "WRITE IT UP FOR THE RUNBOOK", "social": 0, "reply": "Okay. I will write it up."}]},
		],
	},
}
var VOICES: Dictionary = DEFAULT_VOICES.duplicate(true)

const DEFAULT_TEXT := {
	"auditor": "Ross Calder",
	"offers": {
		"3": "Summit would like to buy the company on good terms, keep the desk intact and make you their regional service director.",
		"2": "Summit is interested at a fair price and wants the desk to stay as it is for a year.",
		"1": "Summit would buy, but the offer is low and it comes with a list of 'integration findings'.",
		"0": "Summit has withdrawn. The findings were too long to fix.",
	},
	"strain": {"ok": "The crew can hold this pace.", "tight": "The crew is already tight.", "bad": "The crew is stretched thin."},
	"pager": {
		"text": "Last night {who} was paged for {client}: {issue}. They fixed it from the kitchen table. {line}",
		"issues": ["a server that stopped answering", "a failed backup alarm", "a locked-out owner", "a mail queue that would not drain"],
		"fair": "The rota is even.",
		"unfair": "{who} has taken more nights than anyone else.",
		"options": {"home": "SEND THEM HOME FOR THE MORNING", "keep": "THANK THEM, KEEP THE DAY", "cover": "TAKE THE NEXT PAGE MYSELF"},
		"replies": {"home": "Thanks, Dan. I will be in at noon.", "keep": "Thanks. I will have extra coffee.", "cover": "Really? Thank you. Text me if it is a bad one."},
	},
	"friday": {
		"subject": "Friday: the desk",
		"low": "Morgan here. The knowledge base is nearly empty (%d percent documented) or somebody left (retention %d percent). I will not write that down for the owners yet, but I will on the next Friday.",
		"flat": "Morgan here. The desk is documented %d percent and retention is %d percent. Fine. Not a story.",
		"good": "Morgan here. The desk is documented %d percent and retention is %d percent. That is what a buyer reads first. Thank you.",
	},
	"fired_owners": "BOTH OWNERS HAVE LOST TRUST IN YOU. THE DESK GOES TO SOMEONE ELSE.",
	"onboard_mails": {
		"vault": "Every credential is in the vault, tagged by owner. I can open a ticket for anything without asking Ray. - Sam",
		"shared": "The shared admin login is still active. Please do not share it more than it already is. - Sam",
	},
	"audit_page": "SUMMIT AUDIT: DOC %d  RETENTION %d  SLA %d  CLAWBACKS %d  TOTAL %d / 100",
	"waves": {"title": "XP WAVE", "done": "%d OF %d MACHINES"},
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)

# ---- state (saved) -------------------------------------------------------------------------------------------------
var picks := {}  # beat or memo id -> the option id you chose
var fired := {}  # SCHEDULE id -> the day it fired
var ctx := {}  # SCHEDULE id -> the seeded details of that beat (who, client, counts)
var sides := {"Alan": 0, "Garrison": 0, "both": 0}
var wave := {"total": 0, "done": 0.0, "mode": "", "rate": 0.0, "log": ""}
var oncall := {"policy": "", "stipend": 0, "load": {}, "nights": 0, "dan": 0, "fair_note": ""}
var pending := {}  # day -> [{client, prob}] tickets that arrive that morning
var credits := 0  # concessions that cost the company (credits, free work): the clawbacks of the audit
var lost_clients := 0
var framing := 0  # you polished the numbers for an owner before the audit
var rollup_rec := ""  # "", "sell", "stay" or "none"
var audit := {}  # the Summit scorecard computed on the audit day
var psa_mode := ""
var promo_who := ""
var _job_done := false
var _night_day := 0


func _ready() -> void:
	reset()


func reset() -> void:
	picks = {}
	fired = {}
	ctx = {}
	sides = {"Alan": 0, "Garrison": 0, "both": 0}
	wave = {"total": 0, "done": 0.0, "mode": "", "rate": 0.0, "log": ""}
	oncall = {"policy": "", "stipend": 0, "load": {}, "nights": 0, "dan": 0, "fair_note": ""}
	pending = {}
	credits = 0
	lost_clients = 0
	framing = 0
	rollup_rec = ""
	audit = {}
	psa_mode = ""
	promo_who = ""
	_job_done = false
	_night_day = 0
	remove_books()


func active() -> bool:
	return Campaign.active and Campaign.mode == "service"


# the start of a run: install the job book and fix the mutator plan to the story's engines
func begin_run() -> void:
	install_books()
	Mutators.plan = [
		{"id": "xp_eol", "from": XP_FROM, "to": XP_FROM},
		{"id": "heartbleed", "from": int(SCHEDULE.heartbleed.day), "to": int(SCHEDULE.heartbleed.day) + 1},
		{"id": "new_psa", "from": int(SCHEDULE.psa.day), "to": int(SCHEDULE.psa.day)},
	]
	wave = {"total": XP_TOTAL, "done": 0.0, "mode": "", "rate": 0.0, "log": ""}


func install_books() -> void:
	for id in JOB_BOOKS:
		Playbook.BOOKS[id] = JOB_BOOKS[id].duplicate(true)
	for id in JOB_PROBLEMS:
		Playbook.PROBLEMS[id] = JOB_PROBLEMS[id].duplicate(true)


func remove_books() -> void:
	for id in JOB_BOOKS:
		if not Playbook.is_active() or str(Playbook.active.get("id", "")) != str(id):
			Playbook.BOOKS.erase(id)
			Playbook.PROBLEMS.erase(id)


# ---- the clock: beats fire on their day ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not active() or Game.title_mode or World.time_scale <= 0.0 or not Msp.enabled:
		return
	for id in SCHEDULE:
		var s: Dictionary = SCHEDULE[id]
		if int(s.day) == Campaign.day and not fired.has(id) and World.clock >= time_of(str(id)) and World.clock < World.DAY_END - 0.4:
			fire(str(id))
	job_done_check()


func time_of(id: String) -> float:
	var at: float = float(SCHEDULE[id].at)
	var r: RandomNumberGenerator = Difficulty.rng_for("service.arc.t", id.hash() & 0xffff)
	return clampf(snappedf(at + r.randf_range(-0.25, 0.25), 0.1), 9.1, 15.8)


func _rng(id: String) -> RandomNumberGenerator:
	return Difficulty.rng_for("service.arc", id.hash() & 0xffff)


func day_of(id: String) -> int:
	return int(SCHEDULE[id].day) if SCHEDULE.has(id) else 0


# how many cards a day already carries (the Events deck only draws on days with at most two)
func beat_count(day: int) -> int:
	var n := 0
	for ev in Service.DAYS.get(day, []):
		if str(ev.kind) != "mail":
			n += 2 if str(ev.kind) == "incident" else 1
	for id in Service.MEMOS:
		if int(Service.MEMOS[id].day) == day:
			n += 1
	for id in SCHEDULE:
		if int(SCHEDULE[id].day) == day:
			n += 2 if str(id) == "onboard" else 1
	for e in Mutators.plan:
		if int(e.from) == day:
			n += 1
	return n


func quiet(day: int) -> bool:
	return day >= 2 and day < Campaign.TOTAL_DAYS and beat_count(day) <= 2


# ---- seeded details of a beat -------------------------------------------------------------------------------------
func _details(id: String) -> Dictionary:
	if ctx.has(id):
		return ctx[id]
	var r := _rng(id)
	var d := {}
	var crew: Array = Crew.names()
	var seniors := []
	var juniors := []
	for n in crew:
		if Service.lane_of(str(n)) == "L2" or str(n) in ["Maya"]:
			seniors.append(str(n))
		else:
			juniors.append(str(n))
	if seniors.is_empty():
		seniors = crew.duplicate()
	if juniors.is_empty():
		juniors = crew.duplicate()
	d["senior"] = str(seniors[r.randi() % maxi(1, seniors.size())]) if not seniors.is_empty() else "Maya"
	d["junior"] = str(juniors[r.randi() % maxi(1, juniors.size())]) if not juniors.is_empty() else "Sam"
	d["who"] = str(crew[r.randi() % maxi(1, crew.size())]) if not crew.is_empty() else "Maya"
	var pool: Array = Sales.active.duplicate()
	if pool.is_empty():
		pool = [0]
	d["client_i"] = int(pool[r.randi() % pool.size()])
	d["client"] = str(Msp.CLIENTS[int(d.client_i)].name)
	d["n"] = r.randi_range(2, 4)
	d["m"] = r.randi_range(3, 5)
	d["pct"] = r.randi_range(18, 26)
	ctx[id] = d
	return d


func _tokens(text: String, id: String, extra := {}) -> String:
	var d := _details(id) if SCHEDULE.has(id) else {}
	var t := text
	var vals := {
		"day": str(Campaign.day), "dleft": str(maxi(0, Campaign.TOTAL_DAYS - Campaign.day)), "deadline": str(XP_TO),
		"cpt": ("$%d" % Service.cost_per_ticket()) if Service.cost_per_ticket() >= 0 else "high",
		"cost": "$%d" % Service.weekly_cost(),
		"doc": str(Service.kb.doc_pct()), "ret": str(Crew.retention_pct()), "mood": str(int(Sales.average())),
		"conf": str(Campaign.rep),
		"sla": str(_sla_pct()),
		"grade": str(Service.grades.back().grade) if not Service.grades.is_empty() else "B",
		"open": str(Msp.open_tickets().size()),
		"auditor": str(TEXT.auditor),
		"total_machines": str(XP_TOTAL),
	}
	for k in d:
		vals[k] = str(d[k])
	for k in extra:
		vals[k] = str(extra[k])
	for k in vals:
		t = t.replace("{" + str(k) + "}", str(vals[k]))
	return t


# ---- cards ---------------------------------------------------------------------------------------------------------
func fire(id: String) -> void:
	fired[id] = Campaign.day
	_details(id)
	match id:
		"onboard":
			_onboard_card()
		"heartbleed":
			_spawn_n("hb_cert", int(ctx.heartbleed.m) - 2, id)
			_card(id)
		"heartbleed2":
			_heartbleed_followup()
		"wave_adjust":
			_wave_adjust()
		"wave_check":
			_wave_check()
		"resets":
			_resets()
		"promo":
			_promo()
		"rollup":
			_rollup()
		"stipend":
			_card(id)
		"psa":
			_card(id)
		_:
			_card(id)


func _ok_hint(opt: Dictionary) -> String:
	for need in opt.get("need", []):
		var parts := str(need).split(":")
		match parts[0]:
			"hours":
				if Service.kb.hours_left() + 0.001 < float(parts[1]):
					return "NEEDS %sH" % parts[1]
			"doc":
				if Service.kb.doc_pct() < int(parts[1]):
					return "%s PCT DOCS" % parts[1]
			"trust2":
				if Service.trust_of("Alan") < int(parts[1]) or Service.trust_of("Garrison") < int(parts[1]):
					return "TRUST %s+" % parts[1]
			"conf":
				if Campaign.rep < int(parts[1]):
					return "CONF %s+" % parts[1]
			"nolive":
				if Service.kb.is_live(str(parts[1])):
					return "DONE ALREADY"
			"offer":
				if int(audit.get("tier", 0)) < int(parts[1]):
					return "NO OFFER"
	return ""


func _options(id: String, list: Array) -> Array:
	var out := []
	for o in list:
		var entry := {"label": _tokens(str(o.label), id), "id": str(o.id)}
		var hint := _ok_hint(o)
		if hint != "":
			entry["enabled"] = false
			entry["hint"] = hint
		out.append(entry)
	return out


func _card(id: String) -> void:
	var b: Dictionary = ARC[id]
	Cards.ask(_tokens(str(b.speaker), id), _tokens(str(b.text), id), _options(id, b.options), func(pick: String) -> void: answer(id, pick))


func answer(id: String, pick: String) -> void:
	var b: Dictionary = ARC[id]
	var opts: Array = b.options
	if id == "resets" and Service.kb.is_live("password") and b.has("options_live"):
		opts = b.options_live
	for o in opts:
		if str(o.id) == pick:
			picks[id] = pick
			apply(o.fx.duplicate(true), id)
			var reply := _tokens(str(o.text), id)
			if reply != "":
				Cards.ask(_tokens(str(b.speaker), id), reply, [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)
			return


# a story fx dictionary: our own keys first, the rest through Service.apply_fx
func apply(fx: Dictionary, id := "") -> void:
	var d: Dictionary = ctx.get(id, {})
	if fx.has("side"):
		note_side(str(fx.side))
	if fx.has("hours"):
		Service.kb.spend(float(fx.hours))
	if fx.has("cost"):
		Service.spent_today += float(fx.cost)
		Service.spent_total += int(fx.cost)
	if fx.has("mood_c"):
		var c: int = int(d.get("client_i", -1))
		if c >= 0 and Sales.active.has(c):
			Sales.adjust(c, int(fx.mood_c))
		else:
			for ac in Sales.active:
				Sales.adjust(int(ac), int(fx.mood_c))
	if fx.has("credit"):
		credits += int(fx.credit)
	if fx.has("stale"):
		Service.kb.system_change(fx.stale)
	if fx.has("kb_publish"):
		var rb: Dictionary = Service.kb.rb(str(fx.kb_publish))
		rb["state"] = Service.kb.DOCUMENTED
		rb["stale"] = false
	if fx.has("kb_refresh"):
		var left := int(fx.kb_refresh)
		for cid in Service.kb.ids():
			if left > 0 and bool(Service.kb.rb(str(cid)).stale):
				Service.kb.rb(str(cid))["stale"] = false
				left -= 1
	if fx.has("tickets"):
		_spawn_n(str(fx.tickets.prob), randi_in(fx.tickets.n, id), id)
	if fx.has("wave"):
		wave["rate"] = float(wave.rate) + float(fx.wave.get("rate", 0.0))
		wave["done"] = minf(float(wave.total), float(wave.done) + float(fx.wave.get("add", 0.0)))
	if fx.has("stipend"):
		oncall["stipend"] = int(fx.stipend)
	if fx.has("psa"):
		psa_mode = str(fx.psa)
	if fx.has("unassign"):
		_unassign(float(fx.unassign))
	if fx.has("rollup_rec"):
		rollup_rec = str(fx.rollup_rec)
	if fx.has("training"):
		Service.training = str(fx.training)
	if fx.has("framing"):
		framing += int(fx.framing)
	# {who}-style names in morale_who / lane
	var rest := {}
	for k in fx:
		if not (k in OWN_KEYS) and k != "kb_publish":
			rest[k] = fx[k]
	if rest.has("morale_who"):
		var named := {}
		for k in rest.morale_who:
			named[_tokens(str(k), id)] = rest.morale_who[k]
		rest["morale_who"] = named
	if id == "promo" and promo_who != "":
		if rest.has("conf"):
			Campaign.adjust_rep(int(rest.conf))
			rest.erase("conf")
		Service._ret_fx(promo_who, rest)
		return
	Service.apply_fx(rest, Service._people_scale())


func randi_in(bounds: Array, id: String) -> int:
	return _rng(id + "n").randi_range(int(bounds[0]), int(bounds[1]))


# ---- sides: the owner conflict arc -------------------------------------------------------------------------------
func note_side(who: String) -> void:
	if sides.has(who):
		sides[who] = int(sides[who]) + 1


# memos and beats of Service call this with the option they were answered with
func note(id: String, pick: String) -> void:
	picks[id] = pick
	var side := ""
	if Service.MEMOS.has(id):
		var m: Dictionary = Service.MEMOS[id]
		var sender := "Alan" if str(m.speaker).begins_with("Alan") else "Garrison"
		var other := "Garrison" if sender == "Alan" else "Alan"
		side = sender if pick == "a" else (other if pick == "b" else "both")
	elif Service.BEATS.has(id):
		match [id, pick]:
			["handover", "q"], ["vic", "r"], ["nosale", "n"], ["audit", "a"]:
				side = "Alan"
			["handover", "s"], ["vic", "t"], ["vic", "h"], ["nosale", "y"], ["audit", "g"]:
				side = "Garrison"
			["handover", "b"], ["nosale", "c"]:
				side = "both"
	if side != "":
		note_side(side)
	if id == "m5":
		oncall["policy"] = {"a": "rota", "b": "volunteer", "c": "hybrid"}.get(pick, "rota")
	if id == "xp":
		wave["mode"] = pick
		wave["rate"] = {"d": 3.2, "n": 4.6, "m": 2.6}.get(pick, 3.0)
		wave["done"] = 1.0
	if id == "audit" and pick in ["a", "g"]:
		framing += 1


func lean() -> String:
	var a: int = int(sides.Alan)
	var g: int = int(sides.Garrison)
	if a >= g + 2:
		return "Alan"
	if g >= a + 2:
		return "Garrison"
	return "both"


# ---- morning: tickets that were waiting, the wave, the pager -------------------------------------------------------
func begin_day(day: int) -> void:
	if not active():
		return
	for k in pending.keys():
		if int(k) <= day:
			for item in pending[k]:
				spawn(int(item.client), str(item.prob), "story")
			pending.erase(k)
	if day > XP_FROM and day <= XP_TO and int(wave.total) > 0:
		var f: float = clampf(float(Crew.morale_avg()) / 65.0, 0.6, 1.2)
		wave["done"] = minf(float(wave.total), float(wave.done) + float(wave.rate) * f)
		if str(wave.mode) == "n":
			Crew.add_all(-2)
		if str(wave.mode) == "m":
			Crew.mentor("Maya")
	if str(oncall.policy) != "" and day >= 15 and day <= 19:
		_pager(day)


func spawn(client: int, prob_id: String, src: String) -> int:
	if not PROBS.has(prob_id):
		return 0
	var t: Dictionary = Msp.create_problem(client, PROBS[prob_id].duplicate(true), src, true)
	return int(t.get("id", 0)) if not t.is_empty() else 0


func _spawn_n(prob_id: String, n: int, id: String) -> void:
	var r := _rng(id + prob_id)
	var pool: Array = Sales.active.duplicate()
	for i in maxi(0, n):
		if pool.is_empty():
			return
		spawn(int(pool[r.randi() % pool.size()]), prob_id, "story")


func queue_ticket(day: int, client: int, prob_id: String) -> void:
	var list: Array = pending.get(day, [])
	list.append({"client": client, "prob": prob_id})
	pending[day] = list


func _unassign(frac: float) -> void:
	var r := _rng("unassign")
	for t in Msp.open_tickets():
		if str(t.special) != "" or Crew.assignee_of(t) == "":
			continue
		if r.randf() < frac:
			Service.assign(int(t.id), "", false)


# ---- the XP wave -------------------------------------------------------------------------------------------------
func wave_pct() -> int:
	return int(round(100.0 * float(wave.done) / float(maxi(1, int(wave.total))))) if int(wave.total) > 0 else 0


func _wave_adjust() -> void:
	var d := _details("wave_adjust")
	var left := int(wave.total) - int(wave.done)
	var strain := str(TEXT.strain.bad if Crew.morale_avg() < 50 else (TEXT.strain.tight if Crew.morale_avg() < 62 else TEXT.strain.ok))
	var b: Dictionary = ARC.wave_adjust
	Cards.ask(
		_tokens(str(b.speaker), "wave_adjust"),
		_tokens(str(b.text), "wave_adjust", {"done": int(wave.done), "total": int(wave.total), "left": left, "strain": strain}),
		_options("wave_adjust", b.options),
		func(pick: String) -> void: answer("wave_adjust", pick)
	)
	d["left"] = left


func _wave_check() -> void:
	var pct := wave_pct()
	var left := int(wave.total) - int(wave.done)
	var kind := "done" if pct >= 95 else ("most" if pct >= 65 else "low")
	var b: Dictionary = ARC.wave_check
	var extra := {"done": int(wave.done), "total": int(wave.total), "left": left, "pct": pct}
	var fx := {}
	var pool: Array = Sales.active
	var c1: int = int(_details("wave_check").client_i)
	var c2: int = int(pool[_rng("wave2").randi() % pool.size()]) if not pool.is_empty() else c1
	match kind:
		"done":
			fx = {"trust": {"Alan": 4}}
			Msp.mail("Alan (Co-owner)", "The XP list", "No XP machines left on the list. Thank you. - Alan")
		"most":
			fx = {"trust": {"Alan": -2}}
			queue_ticket(Campaign.day + 1, c1, "xp_hit")
		"low":
			fx = {"trust": {"Alan": -5, "Garrison": -2}, "mood": -4}
			queue_ticket(Campaign.day + 1, c1, "xp_hit")
			queue_ticket(Campaign.day + 1, c2, "xp_hit")
			credits += 1
	wave["log"] = kind
	picks["wave_check"] = kind
	Service.apply_fx(fx, 1.0)
	Cards.ask(_tokens(str(b.speaker), "wave_check"), _tokens(str(b.text[kind]), "wave_check", extra), _options("wave_check", b.options), func(_p: String) -> void: pass)


func _heartbleed_followup() -> void:
	var kind := "none"
	for k in ["hb_patch", "hb_email", "hb_both"]:
		if Service.flags.get(k, false):
			kind = k
	var b: Dictionary = ARC.heartbleed2
	var fx := {}
	match kind:
		"hb_patch":
			fx = {"mood_c": -2, "trust": {"Garrison": -1}}
		"hb_email":
			fx = {"trust": {"Alan": -2}, "mood_c": -1}
			_spawn_n("hb_called", 2, "heartbleed2")
		"hb_both":
			fx = {"trust": {"Alan": 1, "Garrison": 1}, "mood_c": 2}
	apply(fx, "heartbleed2")
	picks["heartbleed2"] = kind
	var n := int(ctx.get("heartbleed2", {}).get("n", 2))
	Cards.ask(_tokens(str(b.speaker), "heartbleed2"), _tokens(str(b.text[kind]), "heartbleed2", {"n": n}), _options("heartbleed2", b.options), func(_p: String) -> void: pass)


func _resets() -> void:
	var d := _details("resets")
	var b: Dictionary = ARC.resets
	if Service.kb.is_live("password"):
		Cards.ask(_tokens(str(b.speaker), "resets"), _tokens(str(b.text_live), "resets"), _options("resets", b.options_live), func(pick: String) -> void: answer("resets", pick))
		return
	d["n"] = _rng("resets").randi_range(5, 9)
	_card("resets")


func _promo() -> void:
	var who := ""
	var best := -1.0
	for n in Crew.names():
		var w := str(n)
		if Crew.is_shadowing(w) or Service.lane_of(w) != "L1":
			continue
		var v: float = Crew.value(w, "skill") + 0.01 * Crew.value(w, "done")
		if v > best:
			best = v
			who = w
	if who == "":
		return
	promo_who = who
	var d := _details("promo")
	d["junior"] = who
	d["done"] = int(Crew.value(who, "done"))
	Service.event_days["promotion"] = Campaign.day  # the retention event does not ask again
	_card("promo")


func _onboard_card() -> void:
	if Playbook.is_active():
		# one job at a time: Morgan closes out the job you left open so that Iron Mule can start
		var open_id := str(Playbook.active.get("id", ""))
		Service.flags["job_" + open_id] = "D"
		Playbook.reset()
		Msp.send_text("Morgan", "I closed out the job you left open. It will show on your review. Iron Mule starts today.")
		Campaign.adjust_rep(-1)
	var client := 10
	if not Sales.active.has(client):
		Sales.sign_client(client)
	var d := _details("onboard")
	d["client_i"] = client
	d["client"] = str(Msp.CLIENTS[client].name)
	var promise := "John promised them they would be live in a day, and Garrison repeated it at the handshake."
	if str(picks.get("m2", "")) == "a":
		promise = "You told Garrison yes to one day in the memo, and it is on the contract."
	elif str(picks.get("m2", "")) == "b":
		promise = "You asked for a survey first. John had already promised a day, so he is nervous."
	var inc: Dictionary = Service.INCIDENTS.onboard
	var text := "%s signs today. %s They have no network diagram, no passwords list and a server nobody has named. Who takes the onboarding?" % [str(d.client), promise]
	var options := [
		{"label": str(Service.INCIDENT_OPTIONS.take), "id": "take"},
		{"label": str(Service.INCIDENT_OPTIONS.send), "id": "send"},
		{"label": "%s (%s)" % [str(Service.INCIDENT_OPTIONS.ask), str(inc.owner).to_upper()], "id": "ask"},
	]
	Cards.ask(str(inc.speaker), text, options, func(pick: String) -> void: _onboard_run(pick))


func _onboard_run(pick: String) -> void:
	picks["onboard"] = pick
	Service.run_incident("onboard", pick)
	job_done_check()


# a finished onboarding job: the flags decide the owners' reaction and the tickets that come back
func job_done_check() -> void:
	if _job_done or Playbook.active.is_empty() or str(Playbook.active.get("id", "")) != "onboard" or not bool(Playbook.active.get("done", false)):
		return
	_job_done = true
	var f: Dictionary = Playbook.active.get("flags", {})
	var grade := str(Playbook.active.get("result", {}).get("grade", "C"))
	Service.flags["job_onboard"] = grade
	var trust := {"Alan": 0, "Garrison": 0}
	if f.get("vault", false) and f.get("named", false):
		trust["Alan"] = 4
		Msp.mail("Sam", "Iron Mule is in the vault", str(TEXT.onboard_mails.vault))
	if f.get("shared", false) or f.get("leak", false) or f.get("newshared", false):
		queue_ticket(Campaign.day + 1, 10, "onb_leak")
		Msp.mail("Sam", "Iron Mule: shared login", str(TEXT.onboard_mails.shared))
	if f.get("broke", false):
		queue_ticket(Campaign.day + 1, 10, "onb_broke")
		trust["Garrison"] = -2
	if f.get("documented", false):
		trust["Alan"] = int(trust["Alan"]) + 2
	if grade in ["S", "A"]:
		trust["Garrison"] = int(trust["Garrison"]) + 2
	if grade == "D":
		trust["Alan"] = int(trust["Alan"]) - 2
		credits += 1
	Service.apply_fx({"trust": trust}, 1.0)


# ---- the pager --------------------------------------------------------------------------------------------------
func oncall_cost() -> int:
	var per_night := int(oncall.stipend)
	return per_night * 2 if str(oncall.policy) in ["volunteer", "hybrid"] else (per_night if str(oncall.policy) == "rota" else 0)


func _oncall_pool() -> Array:
	var out := []
	for n in Crew.names():
		if not Crew.is_shadowing(str(n)):
			out.append(str(n))
	return out


func _page_who(day: int) -> String:
	var pool := _oncall_pool()
	if pool.is_empty():
		return ""
	match str(oncall.policy):
		"volunteer":
			# the willing ones: Maya first, and whoever has the most morale
			var best := ""
			for n in pool:
				if best == "" or Crew.morale(str(n)) + (8 if str(n) == "Maya" else 0) > Crew.morale(best) + (8 if best == "Maya" else 0):
					best = str(n)
			return best
		"hybrid":
			return str(pool[(day - 15) % pool.size()])
	return str(pool[(day - 15) % pool.size()])


func _pager(day: int) -> void:
	var r := Difficulty.rng_for("service.pager", day)
	if r.randf() > 0.55:
		return
	var who := _page_who(day)
	if who == "":
		return
	var load: Dictionary = oncall.load
	load[who] = int(load.get(who, 0)) + 1
	oncall["nights"] = int(oncall.nights) + 1
	var cost := int(oncall.stipend)
	if cost > 0:
		Service.spent_today += float(cost)
		Service.spent_total += cost
	Crew.add_stress(who, 6)
	Crew.add_morale(who, -2 if cost == 0 else 0)
	var client := int(Sales.active[r.randi() % Sales.active.size()]) if not Sales.active.is_empty() else 0
	spawn(client, "pager_issue", "after hours")
	var pg: Dictionary = TEXT.pager
	var fair := fairness()
	var line := str(pg.fair) if fair >= 0.5 else str(pg.unfair).replace("{who}", _heaviest())
	if fair < 0.5 and str(oncall.policy) == "volunteer":
		Crew.add_retain(_heaviest(), -1)
	var text := str(pg.text).replace("{who}", who).replace("{client}", str(Msp.CLIENTS[client].name)).replace("{issue}", str(pg.issues[r.randi() % pg.issues.size()])).replace("{line}", line)
	Msp.send_text("Pager", "%s was paged after hours." % who)
	var opts := [{"label": str(pg.options.home), "id": "home"}, {"label": str(pg.options.keep), "id": "keep"}, {"label": str(pg.options.cover), "id": "cover"}]
	Cards.ask("Dispatch (Pager)", text, opts, func(pick: String) -> void: _pager_answer(who, pick))


func _pager_answer(who: String, pick: String) -> void:
	match pick:
		"home":
			Crew.add_morale(who, 5)
			Crew.set_busy(who, 4.0)
			Crew.add_stress(who, -6)
		"keep":
			Crew.add_morale(who, 1)
		"cover":
			Crew.add_morale(who, 4)
			Crew.add_stress(who, -4)
			oncall["dan"] = int(oncall.dan) + 1
			Service.add_trust("Alan", 1)
			Service.buffs.append({"key": "speed", "val": 0.98, "left": 1})
			Service._sync()
	Cards.ask(who, str(TEXT.pager.replies[pick]), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: pass)


func _heaviest() -> String:
	var best := ""
	for n in oncall.load:
		if best == "" or int(oncall.load[n]) > int(oncall.load[best]):
			best = str(n)
	return best


# 1.0 = an even rota, 0.0 = one person takes every night
func fairness() -> float:
	var load: Dictionary = oncall.load
	var pool := _oncall_pool()
	if pool.size() < 2 or int(oncall.nights) < 2:
		return 1.0
	var hi := 0
	var lo := 99
	for n in pool:
		var v := int(load.get(str(n), 0))
		hi = maxi(hi, v)
		lo = mini(lo, v)
	return clampf(1.0 - float(hi - lo) / float(maxi(1, int(oncall.nights))), 0.0, 1.0)


# ---- the PSA cut over ---------------------------------------------------------------------------------------------
func on_mutator(id: String) -> void:
	if not active() or not HOOKS.has(id):
		return
	_stale(HOOKS[id], id)


func on_event(id: String) -> void:
	if not active() or not EVENT_HOOKS.has(id):
		return
	_stale(EVENT_HOOKS[id], id)


# a system change: some of the documented classes go stale (seeded, documented ones first)
func _stale(h: Dictionary, id: String) -> Array:
	var r := _rng("stale." + id)
	var hit_pool := []
	for c in h.classes:
		if Service.kb.state(str(c)) == Service.kb.DOCUMENTED and not bool(Service.kb.rb(str(c)).stale):
			hit_pool.append(str(c))
	for k in range(hit_pool.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = hit_pool[k]
		hit_pool[k] = hit_pool[j]
		hit_pool[j] = tmp
	var pick: Array = hit_pool.slice(0, mini(int(h.get("pick", 1)), hit_pool.size()))
	if pick.is_empty():
		return []
	return Service.kb.system_change(pick, str(h.subject), str(h.body))


# the owners keep score every evening: Alan reads the documentation and the reopens, Garrison the clients and the crew
func owner_drift() -> void:
	if not active() or Campaign.day < 3:
		return
	var td: Dictionary = Service.today()
	var doc: int = Service.kb.doc_pct()
	var mood := int(Sales.average())
	var morale: int = Crew.morale_avg()
	var a := 0
	var g := 0
	if Campaign.day >= 4 and doc < 25:
		a -= 1
	if int(td.sla) < 80 or int(td.reopened) > 0:
		a -= 1
	if doc >= 60 and int(td.sla) >= 90:
		a += 1
	if mood < 50:
		g -= 2
	elif mood < 65:
		g -= 1
	if morale < 50:
		g -= 1
	var talked := false
	for who in Service.oto_day:
		talked = talked or int(Service.oto_day[who]) == Campaign.day
	if mood >= 75 and morale >= 70 and talked:
		g += 1  # Garrison hears that you asked the crew how they are
	if a != 0:
		Service.add_trust("Alan", a)
	if g != 0:
		Service.add_trust("Garrison", g)


# Morgan reads the desk on Fridays: written down and kept is rewarded, nothing in the knowledge base is not
func friday_delta() -> int:
	if not active() or Campaign.day % 5 != 0:
		return 0
	var doc: int = Service.kb.doc_pct()
	var d := 0
	if doc < 25:
		d -= 4
	elif doc < 40:
		d -= 1
	elif doc >= 60:
		d += 2
	elif doc >= 40:
		d += 1
	if Crew.retention_pct() < 100:
		d -= 2
	var note := str(TEXT.friday.low if d < 0 else (TEXT.friday.good if d > 0 else TEXT.friday.flat))
	Msp.mail("Morgan Reyes - Manager", str(TEXT.friday.subject), note % [doc, Crew.retention_pct()])
	return d


# a tech nobody has talked to in five days loses a little heart every day (Maya, who never walks up to you, first)
func silence() -> void:
	if not active() or Campaign.day < 6:
		return
	for n in Crew.names():
		var w := str(n)
		if Crew.is_shadowing(w):
			continue
		var gap := Campaign.day - maxi(1, int(Crew.value(w, "last_oto")))
		if gap >= 5:
			Crew.add_morale(w, -2)


# ---- the Summit audit ---------------------------------------------------------------------------------------------
func _sla_pct() -> int:
	var total: int = Msp.closed_ok + Msp.breached
	return 100 if total <= 0 else int(round(100.0 * float(Msp.closed_ok) / float(total)))


func audit_score() -> Dictionary:
	var doc := clampf(25.0 * float(Service.kb.doc_pct()) / float(AUDIT_FULL_DOC), 0.0, 25.0)
	var ret_pct: int = Crew.retention_pct()
	var morale_part := clampf((float(Crew.morale_avg()) - 40.0) / 40.0, 0.0, 1.0)
	var ret := 25.0 * clampf((float(ret_pct) - 50.0) / 50.0, 0.0, 1.0) * (0.6 + 0.4 * morale_part)
	var sla := 25.0 * clampf((float(_sla_pct()) - 70.0) / 25.0, 0.0, 1.0)
	var reopen_rate := float(Msp.reopened) / float(maxi(1, Msp.closed_ok))
	var claw := clampf(25.0 - 4.0 * float(credits) - 5.0 * float(lost_clients) - 40.0 * reopen_rate, 0.0, 25.0)
	var total := int(round(doc + ret + sla + claw))
	var polish := 0
	if framing > 0:
		polish = 2 if total >= 50 else -6  # an owner's framing helps a solid desk and is found out on a weak one
	total = clampi(total + polish, 0, 100)
	var tier := 3 if total >= 80 else (2 if total >= 65 else (1 if total >= 45 else 0))
	return {"doc": int(round(doc)), "ret": int(round(ret)), "sla": int(round(sla)), "claw": int(round(claw)), "total": total, "tier": tier, "polish": polish}


func _rollup() -> void:
	audit = audit_score()
	var d := _details("rollup")
	var b: Dictionary = ARC.rollup
	var extra := {"doc_pts": audit.doc, "ret_pts": audit.ret, "sla_pts": audit.sla, "claw_pts": audit.claw, "total": audit.total, "offer": str(TEXT.offers[str(audit.tier)])}
	Cards.ask(_tokens(str(b.speaker), "rollup"), _tokens(str(b.text), "rollup", extra), _options("rollup", b.options), func(pick: String) -> void: answer("rollup", pick))
	d["tier"] = audit.tier


# the audit card at the start of the audit day shows the number
func beat_text(id: String, text: String) -> String:
	if id == "audit" and active():
		audit = audit_score()
		var extra := {"doc_pts": audit.doc, "ret_pts": audit.ret, "sla_pts": audit.sla, "claw_pts": audit.claw, "total": audit.total}
		return text + " " + _tokens(str(ARC.audit_extra.text), "audit_extra", extra)
	if id == "xp" and active():
		return text + " The wave is %d machines, and it has to be finished by the end of day %d." % [XP_TOTAL, XP_TO]
	return text


# ---- the endings ------------------------------------------------------------------------------------------------
func extra_offers() -> Array:
	var out := []
	if audit.is_empty():
		audit = audit_score()
	var tier := int(audit.tier)
	if tier >= 1:
		out.append({"id": "rollup_yes", "label": str(Service.REVIEW.endings.rollup_yes.label), "desc": str(Service.REVIEW.endings.rollup_yes.desc)})
		out.append({"id": "rollup_no", "label": str(Service.REVIEW.endings.rollup_no.label), "desc": str(Service.REVIEW.endings.rollup_no.desc)})
	return out


func audit_lines(blue: Color, ink: Color) -> Array:
	if audit.is_empty():
		audit = audit_score()
	return [[str(TEXT.audit_page) % [int(audit.doc), int(audit.ret), int(audit.sla), int(audit.claw), int(audit.total)], blue if int(audit.total) >= 55 else ink]]


# the scorecard rows the story adds (kept to a few so the report still fits)
func report_rows() -> Array:
	var rows := []
	if Campaign.day >= XP_FROM and Campaign.day <= XP_TO and int(wave.total) > 0:
		rows.append([str(TEXT.waves.title), "%d%%" % wave_pct(), DayReport.GOOD if wave_pct() >= 70 else DayReport.WARN])
	if str(oncall.policy) != "" and int(oncall.nights) > 0:
		rows.append(["PAGER", "%d NIGHTS  FAIR %d%%" % [int(oncall.nights), int(round(fairness() * 100.0))], DayReport.GOOD if fairness() >= 0.5 else DayReport.WARN])
	return rows


# ---- Talk and Lynk in Service mode --------------------------------------------------------------------------------
func _voice(who: String) -> String:
	if VOICES.small.has(who):
		return who
	return "hire" if Crew.is_hire(who) else ""


func small_talk(who: String) -> String:
	var key := _voice(who)
	if key == "":
		return ""
	var lines: Array = VOICES.small[key]
	var r := Difficulty.rng_for("service.voice", Campaign.day * 31 + who.hash() % 97)
	return str(lines[r.randi() % lines.size()])


func tip(who: String) -> String:
	var key := _voice(who)
	if key == "" or not VOICES.tips.has(key):
		return ""
	var lines: Array = VOICES.tips[key]
	var r := Difficulty.rng_for("service.tip", Campaign.day * 17 + who.hash() % 89)
	return str(lines[r.randi() % lines.size()])


func has_question(who: String) -> bool:
	return active() and QUESTIONS.has(who)


# Alan asks about quality, Garrison about clients, Morgan about the scorecard. Dan answers quietly. Once a day each.
func question(who: String, after := Callable()) -> void:
	var done: Dictionary = Service.flags.get("asked_day", {})
	if int(done.get(who, -1)) == Campaign.day:
		Cards.ask(who, "We covered it today. Ask me again tomorrow.", [{"label": "OK", "id": "ok"}], func(_x: String) -> void: Service._call(after))
		return
	done[who] = Campaign.day
	Service.flags["asked_day"] = done
	var list: Array = QUESTIONS[who]
	var count := int(Service.flags.get("asked_n_" + who, 0))
	Service.flags["asked_n_" + who] = count + 1
	var q: Dictionary = list[count % list.size()]
	var options := []
	for i in q.options.size():
		options.append({"label": _tokens(str(q.options[i].label), ""), "id": str(i)})
	Cards.ask(who, _tokens(str(q.text), ""), options, func(pick: String) -> void: _question_answer(who, q, int(pick), after))


func _question_answer(who: String, q: Dictionary, pick: int, after: Callable) -> void:
	var o: Dictionary = q.options[pick]
	Service.apply_fx(o.fx.duplicate(true), Service._people_scale())
	Cards.ask(who, str(o.reply), [{"label": "OK", "id": "ok"}], func(_x: String) -> void: Service._call(after))


# what Morgan answers on Lynk when you ask for advice
func boss_line() -> String:
	var stale := 0
	for id in Service.kb.ids():
		if bool(Service.kb.rb(str(id)).stale):
			stale += 1
	if stale > 0:
		return "%d runbooks went stale after the last change. Alan will ask about them on Friday." % stale
	if Campaign.rep < 50:
		return "My confidence in the desk is %d. Bring me a plan on Friday, not a problem." % Campaign.rep
	var gap: int = absi(Service.trust_of("Alan") - Service.trust_of("Garrison"))
	if gap >= 20:
		return "Alan and Garrison trust you %d points apart. A buyer would notice that gap before anything else." % gap
	return "The scorecard is steady. Keep the one on ones going and write down what you change."


# Lynk: a message from the service cast. Returns true when a message was pushed.
func lynk_incoming() -> bool:
	var pool := []
	for who in Lync.contacts():
		var key := str(who)
		if VOICES.lync.has(key) and not Lync.pending.has(key) and Lync.presence(key)[0] == "AVAILABLE":
			pool.append(key)
	if pool.is_empty() or Lync.pending.size() >= 2:
		return false
	var r := Difficulty.rng("service.lynk")
	var who: String = pool[r.randi() % pool.size()]
	var msgs: Array = VOICES.lync[who]
	var msg: Dictionary = msgs[r.randi() % msgs.size()]
	Lync._push(who, who, _tokens(str(msg.text), ""))
	Lync.pending[who] = msg
	return true


# the extra effects of a Lynk reply (trust, morale, confidence); the warmer reply with a high PEOPLE stat
func lynk_reply(who: String, opt: Dictionary) -> void:
	var fx := {}
	if opt.has("morale"):
		if Crew.has(who):
			fx["morale_who"] = {who: int(opt.morale)}
	if opt.has("trust"):
		fx["trust"] = {who: int(opt.trust)} if who in ["Alan", "Garrison"] else {}
	if opt.has("conf"):
		fx["conf"] = int(opt.conf)
	if not fx.is_empty():
		Service.apply_fx(fx, Service._people_scale())


# ---- saving -------------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"version": VERSION, "picks": picks.duplicate(), "fired": fired.duplicate(), "ctx": ctx.duplicate(true), "sides": sides.duplicate(),
		"wave": wave.duplicate(), "oncall": oncall.duplicate(true), "pending": pending.duplicate(true), "credits": credits,
		"lost_clients": lost_clients, "framing": framing, "rollup_rec": rollup_rec, "audit": audit.duplicate(), "psa_mode": psa_mode,
		"promo_who": promo_who, "job_done": _job_done,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	install_books()
	if data.is_empty():
		return
	picks = data.get("picks", {}).duplicate()
	fired = data.get("fired", {}).duplicate()
	ctx = data.get("ctx", {}).duplicate(true)
	sides = data.get("sides", sides).duplicate()
	wave = data.get("wave", wave).duplicate()
	oncall = data.get("oncall", oncall).duplicate(true)
	pending = {}
	for k in data.get("pending", {}):
		pending[int(k)] = data.pending[k].duplicate(true)
	credits = int(data.get("credits", 0))
	lost_clients = int(data.get("lost_clients", 0))
	framing = int(data.get("framing", 0))
	rollup_rec = str(data.get("rollup_rec", ""))
	audit = data.get("audit", {}).duplicate()
	psa_mode = str(data.get("psa_mode", ""))
	promo_who = str(data.get("promo_who", ""))
	_job_done = bool(data.get("job_done", false))
