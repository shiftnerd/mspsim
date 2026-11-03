extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Playbooks: the multi-step jobs of the tech campaign (a client's rack falls off the wall, a server migration, the 24x7
# email outage with the vendor call, a network install). Each step is a situation with choices. A choice can cost real
# seconds (`secs`, a timed job on the computer) and game hours (`hours`, the clock jumps: that is how the email outage
# runs into the night), awards points (`pts`), sets flags, and can be locked behind a skill (`req`) or an earlier flag
# (`needs`). The best path is the high-points one; sloppy choices leave flags that cause trouble later.
# The jobs show in LabRat RMM, PROJECT tab.

signal changed

const DEFAULT_BOOKS := {
	"rack":
	{
		"title": "RACK RECOVERY",
		"client": 2,
		"specials": ["rack"],
		"steps":
		[
			{
				"title": "MAKE IT SAFE",
				"text":
				"The rack tore off the plywood wall and is lying on the floor, still powered, with the UPS beeping. What first?",
				"choices":
				[
					{
						"label": "POWER EVERYTHING DOWN",
						"secs": 4.0,
						"pts": 20,
						"hours": 0.1,
						"note": "Everything powered down cleanly."
					},
					{
						"label": "PHOTOGRAPH THE CABLING FIRST",
						"secs": 6.0,
						"pts": 15,
						"hours": 0.2,
						"flag": "photo",
						"note": "Photos taken. They will save time later."
					},
					{
						"label": "STAND IT UP RIGHT AWAY",
						"secs": 2.0,
						"pts": 0,
						"hours": 0.1,
						"flag": "damaged",
						"note": "Sparks! The switch fan died."
					},
				]
			},
			{
				"title": "REMOUNT THE RACK",
				"text": "The plywood wall ripped out. How do you get the rack back up?",
				"choices":
				[
					{
						"label": "BUY ANCHORS, MOUNT TO THE STUDS",
						"secs": 8.0,
						"pts": 20,
						"hours": 0.5,
						"note": "Mounted to the studs. It is not going anywhere."
					},
					{
						"label": "PROP IT ON A DESK FOR NOW",
						"secs": 2.0,
						"pts": 5,
						"hours": 0.1,
						"flag": "temp",
						"note": "Propped on a desk. Temporary."
					},
					{
						"label": "SCREW IT INTO THE DRYWALL",
						"secs": 3.0,
						"pts": 0,
						"hours": 0.2,
						"flag": "weak",
						"note": "Hopefully those anchors hold."
					},
				]
			},
			{
				"title": "RECABLE",
				"text":
				"Dozens of cables, half the labels torn off. How do you put it back together?",
				"choices":
				[
					{
						"label": "FOLLOW YOUR PHOTOS",
						"secs": 6.0,
						"pts": 25,
						"hours": 0.3,
						"needs": "photo",
						"needs_label": "NEEDS PHOTOS",
						"note": "Cables match the photos exactly."
					},
					{
						"label": "RUN THE CABLE TESTER",
						"secs": 6.0,
						"pts": 25,
						"hours": 0.3,
						"req": ["networking", 2],
						"note": "The tester maps every cable to its port."
					},
					{
						"label": "TRACE AND LABEL EVERY CABLE",
						"secs": 12.0,
						"pts": 20,
						"hours": 0.6,
						"note": "Slow, but every cable is now labelled."
					},
					{
						"label": "PLUG THEM WHERE THEY FIT",
						"secs": 3.0,
						"pts": 5,
						"hours": 0.1,
						"flag": "miswired",
						"note": "It all fits somewhere."
					},
				]
			},
			{
				"title": "POWER ON",
				"text": "Time to bring the network back up. In what order?",
				"choices":
				[
					{
						"label": "UPS, ROUTER, SWITCH, THEN THE NAS",
						"secs": 10.0,
						"pts": 25,
						"hours": 0.2,
						"note": "Everything came up in order."
					},
					{
						"label": "SWITCH FIRST, THEN THE REST",
						"secs": 8.0,
						"pts": 10,
						"hours": 0.2,
						"note": "Worked, but the router had to be rebooted."
					},
					{
						"label": "EVERYTHING AT ONCE",
						"secs": 3.0,
						"pts": 5,
						"hours": 0.5,
						"flag": "nas_check",
						"note": "The NAS is running a disk check for an hour."
					},
				]
			},
			{
				"title": "VERIFY",
				"text": "Lights are green. Are you done?",
				"choices":
				[
					{
						"label": "TEST INTERNET, PRINTERS AND PHONES",
						"secs": 6.0,
						"pts": 15,
						"hours": 0.2,
						"flag": "verified",
						"note": "Everything tested and working."
					},
					{
						"label": "PING THE GATEWAY AND CALL IT DONE",
						"secs": 2.0,
						"pts": 5,
						"hours": 0.0,
						"flag": "unverified",
						"note": "The gateway answers. Probably fine."
					},
				]
			},
		],
	},
	"migration":
	{
		"title": "SERVER MIGRATION",
		"client": 1,
		"specials": ["migration"],
		"steps":
		[
			{
				"title": "PLAN",
				"text": "Brightside's old 2008 server is being replaced. Before anything else...",
				"choices":
				[
					{
						"label": "CHECK THE BACKUPS FIRST",
						"secs": 4.0,
						"pts": 20,
						"hours": 0.1,
						"effect": "backup",
						"note": "Backups checked."
					},
					{
						"label": "SKIP IT, WE ARE IN A HURRY",
						"secs": 0.0,
						"pts": 0,
						"flag": "nocheck",
						"note": "No time for backups. What could go wrong?"
					},
				]
			},
			{
				"title": "PICK A WINDOW",
				"text": "When do you do the cutover?",
				"choices":
				[
					{
						"label": "AFTER HOURS TONIGHT",
						"secs": 4.0,
						"pts": 20,
						"hours": 0.0,
						"note": "Scheduled after hours. Nobody is disturbed."
					},
					{
						"label": "SATURDAY MORNING",
						"secs": 6.0,
						"pts": 15,
						"hours": 0.0,
						"note": "Scheduled for the weekend."
					},
					{
						"label": "RIGHT NOW, DURING THE DAY",
						"secs": 1.0,
						"pts": 0,
						"flag": "downtime",
						"note": "Everyone is working. This will be noisy."
					},
				]
			},
			{
				"title": "COPY THE DATA",
				"text": "File shares, line-of-business data and permissions all have to move.",
				"choices":
				[
					{
						"label": "ROBOCOPY SCRIPT, KEEP PERMISSIONS",
						"secs": 6.0,
						"pts": 25,
						"hours": 0.5,
						"req": ["powershell", 3],
						"note": "Scripted copy with permissions intact."
					},
					{
						"label": "DISK IMAGE THE OLD SERVER",
						"secs": 10.0,
						"pts": 15,
						"hours": 1.0,
						"note": "Imaged and restored. Slow but safe."
					},
					{
						"label": "DRAG AND DROP THE FOLDERS",
						"secs": 14.0,
						"pts": 10,
						"hours": 1.0,
						"flag": "perms",
						"note": "Copied, but the permissions did not follow."
					},
				]
			},
			{
				"title": "CUTOVER",
				"text": "The new server has the data. Switch the office over.",
				"choices":
				[
					{
						"label": "REPOINT DNS, REMAP DRIVES, TEST",
						"secs": 8.0,
						"pts": 20,
						"hours": 0.5,
						"note": "Cutover smooth. Drives remapped."
					},
					{
						"label": "JUST TURN THE OLD SERVER OFF",
						"secs": 2.0,
						"pts": 0,
						"hours": 0.1,
						"flag": "outage",
						"note": "Nobody can find the files. Phones are ringing."
					},
				]
			},
			{
				"title": "RETIRE THE OLD ONE",
				"text": "What happens to the old server?",
				"choices":
				[
					{
						"label": "KEEP IT POWERED OFF FOR TWO WEEKS",
						"secs": 2.0,
						"pts": 15,
						"hours": 0.0,
						"note": "Parked in the closet, just in case."
					},
					{
						"label": "WIPE IT NOW",
						"secs": 4.0,
						"pts": 5,
						"hours": 0.0,
						"flag": "nostash",
						"note": "Wiped. There is no way back."
					},
				]
			},
		],
	},
	"email24":
	{
		"title": "EMAIL OUTAGE",
		"client": 4,
		"specials": ["email24"],
		"steps":
		[
			{
				"title": "DIAGNOSE",
				"text":
				"The brewery runs 24x7 and nobody has had email for an hour. Fermentation alerts are not arriving. Where do you start?",
				"choices":
				[
					{
						"label": "READ THE MAIL SERVER LOGS",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.3,
						"flag": "diagnosed",
						"note": "The mail database dismounted: the log drive is full."
					},
					{
						"label": "ASK THE STAFF WHAT THEY SEE",
						"secs": 5.0,
						"pts": 10,
						"hours": 0.3,
						"note": "Staff just says: it is broken."
					},
					{
						"label": "REBOOT THE MAIL SERVER",
						"secs": 8.0,
						"pts": 0,
						"hours": 0.5,
						"flag": "rebooted",
						"note": "It is stuck in recovery now."
					},
				]
			},
			{
				"title": "CALL THE VENDOR",
				"text":
				"The mail software vendor has a support line. It is 17:40 and the queue is long.",
				"choices":
				[
					{
						"label": "FOLLOW THE TIER 1 SCRIPT",
						"secs": 20.0,
						"pts": 5,
						"hours": 1.0,
						"note": "Forty minutes on hold. They say: reboot it."
					},
					{
						"label": "ASK FOR TIER 2",
						"secs": 14.0,
						"pts": 20,
						"hours": 0.7,
						"note": "Tier 2 agrees it is the log drive."
					},
					{
						"label": "NEGOTIATE AN ESCALATION",
						"secs": 8.0,
						"pts": 30,
						"hours": 0.4,
						"req": ["people", 2],
						"note": "An engineer is calling you back in ten minutes."
					},
				]
			},
			{
				"title": "FIX IT",
				"text": "Free up the log drive and get the database mounted.",
				"choices":
				[
					{
						"label": "MOVE THE LOGS WITH A SCRIPT",
						"secs": 6.0,
						"pts": 25,
						"hours": 0.5,
						"req": ["powershell", 2],
						"note": "Logs moved. The drive has 90 GB free."
					},
					{
						"label": "WAIT FOR THE VENDOR ENGINEER",
						"secs": 25.0,
						"pts": 15,
						"hours": 1.5,
						"note": "The engineer fixes it, eventually."
					},
					{
						"label": "DELETE OLD LOGS BY HAND",
						"secs": 14.0,
						"pts": 10,
						"hours": 1.0,
						"flag": "risky",
						"note": "You deleted logs the database still needed."
					},
				]
			},
			{
				"title": "PROVE IT WORKS",
				"text": "The database says it is mounted.",
				"choices":
				[
					{
						"label": "REMOUNT AND SEND TEST MAIL",
						"secs": 6.0,
						"pts": 15,
						"hours": 0.3,
						"note": "Test mail went through both ways."
					},
					{
						"label": "MARK IT FIXED AND GO HOME",
						"secs": 1.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "unverified",
						"note": "Closed without testing. Hope."
					},
				]
			},
			{
				"title": "TELL THE STAFF",
				"text": "People have been waiting all evening.",
				"choices":
				[
					{
						"label": "EMAIL A STATUS TO EVERYONE",
						"secs": 4.0,
						"pts": 10,
						"hours": 0.2,
						"note": "A clear status email goes out."
					},
					{
						"label": "SAY NOTHING",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"note": "Radio silence."
					},
				]
			},
		],
	},
	"rdp":
	{
		"title": "REMOTE ACCESS BREAK-IN",
		"client": 1,
		"specials": ["rdp"],
		"steps":
		[
			{
				"title": "DIAGNOSE",
				"text":
				"Brightside's server crawls and the realtors say strange users keep showing up in the logs. Where do you look?",
				"choices":
				[
					{
						"label": "READ THE SECURITY EVENT LOG",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.3,
						"flag": "diag",
						"note":
						"Thousands of failed logins a day from overseas, hammering the Administrator account."
					},
					{
						"label": "ASK THE USERS WHAT CHANGED",
						"secs": 5.0,
						"pts": 10,
						"hours": 0.3,
						"note": "Nobody changed anything. It was fine last week."
					},
					{
						"label": "REBOOT THE SERVER",
						"secs": 8.0,
						"pts": 0,
						"hours": 0.4,
						"flag": "rebooted",
						"note": "Back up in minutes, just as slow."
					},
				]
			},
			{
				"title": "FIND THE HOLE",
				"text": "Something is getting in. How do you find it?",
				"choices":
				[
					{
						"label": "CHECK THE FIREWALL RULES",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.3,
						"flag": "found",
						"note":
						"Port 3389 (remote desktop) is forwarded straight to the server. The whole internet can try to log in."
					},
					{
						"label": "SCAN THE SERVER FOR MALWARE",
						"secs": 8.0,
						"pts": 10,
						"hours": 0.4,
						"note": "Nothing found. It is not a virus, it is somebody logging in."
					},
					{
						"label": "BLAME THE ANTIVIRUS",
						"secs": 1.0,
						"pts": 0,
						"hours": 0.1,
						"flag": "wrongtrack",
						"note": "The antivirus has nothing to do with it."
					},
				]
			},
			{
				"title": "CONTAIN",
				"text":
				"Some of those thousands of guesses might have worked. Most attackers back then just guess common passwords.",
				"choices":
				[
					{
						"label": "AUDIT THE ACCOUNTS, RESET THE WEAK PASSWORDS",
						"secs": 10.0,
						"pts": 25,
						"hours": 0.6,
						"flag": "audited",
						"note":
						"Two accounts used passwords like Summer2013. One had been used from overseas last week: it relayed spam, nothing was copied."
					},
					{
						"label": "JUST RESET THE ADMINISTRATOR PASSWORD",
						"secs": 3.0,
						"pts": 10,
						"hours": 0.1,
						"flag": "partial",
						"note": "Better, but two realtor accounts still use weak passwords."
					},
					{
						"label": "DO NOTHING UNTIL THE FIREWALL IS FIXED",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "unaudited",
						"note": "Whatever got in is still in."
					},
				]
			},
			{
				"title": "CLOSE THE DOOR",
				"text": "Remote desktop is wide open to the internet. What do you do about it?",
				"choices":
				[
					{
						"label": "PUT REMOTE DESKTOP BEHIND A VPN",
						"secs": 10.0,
						"pts": 25,
						"hours": 1.0,
						"flag": "vpn",
						"note":
						"Remote access now needs the VPN first. The guessing attacks hit a closed door."
					},
					{
						"label": "FIREWALL THAT AUTO-BLOCKS REPEATED FAILED LOGINS",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.5,
						"flag": "autoblock",
						"note":
						"After a few bad guesses an address is blocked automatically. The attacks stop within the hour."
					},
					{
						"label": "JUST CHANGE THE REMOTE DESKTOP PORT NUMBER",
						"secs": 3.0,
						"pts": 5,
						"hours": 0.1,
						"flag": "obscurity",
						"note": "A new port number. They will find it."
					},
					{
						"label": "LEAVE IT, THE PASSWORDS ARE FIXED NOW",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "open",
						"note": "Still open to the whole internet."
					},
				]
			},
			{
				"title": "TELL THE CLIENT",
				"text": "How do you leave things with the realtors?",
				"choices":
				[
					{
						"label": "WRITE IT UP, RECOMMEND TWO-FACTOR AND A VPN",
						"secs": 6.0,
						"pts": 15,
						"hours": 0.3,
						"flag": "documented",
						"note": "A clear write-up with recommendations goes to the owner."
					},
					{
						"label": "FIX IT QUIETLY",
						"secs": 0.0,
						"pts": 5,
						"hours": 0.0,
						"note": "No write-up. They never learn how close it was."
					},
				]
			},
		],
	},
	"ceofraud":
	{
		"title": "WIRE REQUEST FROM THE BOSS",
		"client": 3,
		"specials": ["ceofraud"],
		"steps":
		[
			{
				"title": "THE EMAIL",
				"text":
				"A paralegal at Hoot and Holler forwards an email that looks like it is from Atty. Spence: wire $38,000 from the client trust account today, quietly, no calls. She thinks it is odd. What do you do first?",
				"choices":
				[
					{
						"label": "LOOK AT THE FULL EMAIL HEADERS",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.3,
						"flag": "headers",
						"note":
						"The sender name says Spence. The reply address is spence@hootholler-law.example: a lookalike domain."
					},
					{
						"label": "CALL ATTY. SPENCE ON HIS CELL",
						"secs": 4.0,
						"pts": 25,
						"hours": 0.2,
						"flag": "called",
						"note":
						"He never sent anything. He is in a deposition and furious that anyone would think so."
					},
					{
						"label": "REPLY AND ASK IF IT IS REAL",
						"secs": 2.0,
						"pts": 3,
						"hours": 0.1,
						"flag": "replied",
						"note":
						"'Yes, it is me. Please hurry.' The scammer answers in four minutes."
					},
					{
						"label": "TELL HER TO WIRE IT, IT LOOKS REAL",
						"secs": 1.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "wired",
						"note": "The wire goes out before lunch."
					},
				]
			},
			{
				"title": "HOW DID THEY KNOW?",
				"text":
				"The email used the right wording, the right account and the right amount. Somebody has been reading the firm's mail. Where do you look?",
				"choices":
				[
					{
						"label": "CHECK THE MAILBOX RULES AND RECENT LOGINS",
						"secs": 8.0,
						"pts": 25,
						"hours": 0.4,
						"flag": "rule",
						"note":
						"A hidden rule forwards every message mentioning wires to an outside address. The login that created it came from overseas."
					},
					{
						"label": "RESET EVERYONE'S PASSWORD AND HOPE",
						"secs": 5.0,
						"pts": 10,
						"hours": 0.3,
						"flag": "reset",
						"note": "New passwords, but the forwarding rule is still there."
					},
					{
						"label": "BLAME THE SPAM FILTER",
						"secs": 1.0,
						"pts": 0,
						"hours": 0.1,
						"note": "The spam filter has nothing to do with it."
					},
				]
			},
			{
				"title": "CONTAIN IT",
				"text": "The attacker has a way into the mailbox. What do you do?",
				"choices":
				[
					{
						"label": "REMOVE THE RULE, RESET THE PASSWORD, END ALL SESSIONS",
						"secs": 8.0,
						"pts": 25,
						"hours": 0.4,
						"flag": "contained",
						"note":
						"The rule is gone, the password is new and every login session is signed out."
					},
					{
						"label": "JUST RESET THE PASSWORD",
						"secs": 3.0,
						"pts": 10,
						"hours": 0.1,
						"flag": "partial",
						"note": "The old session is still signed in on a server in another country."
					},
					{
						"label": "DELETE THE EMAIL AND MOVE ON",
						"secs": 1.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "deleted",
						"note": "You deleted the evidence the bank will want."
					},
				]
			},
			{
				"title": "THE MONEY",
				"text":
				"Was anything already sent? The trust account matters more than the mailbox.",
				"choices":
				[
					{
						"label": "HAVE THE FIRM CALL THE BANK AND ASK FOR A RECALL NOW",
						"secs": 3.0,
						"pts": 20,
						"hours": 0.2,
						"flag": "bank",
						"note": "The bank freezes the wire in time. This is a good day."
					},
					{
						"label": "SEND THE BANK AN EMAIL FOR MORNING",
						"secs": 2.0,
						"pts": 5,
						"hours": 0.0,
						"flag": "late",
						"note": "The bank answers tomorrow. That is probably too late."
					},
				]
			},
			{
				"title": "NEXT TIME",
				"text": "How do you leave things with the firm?",
				"choices":
				[
					{
						"label":
						"CALL-BACK RULE FOR EVERY WIRE REQUEST, PLUS TWO-FACTOR LOGIN FOR EMAIL",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.3,
						"flag": "trained",
						"note":
						"A new rule goes on the wall: no wire without a phone call to a known number."
					},
					{
						"label": "SEND A SCARY EMAIL TO EVERYONE",
						"secs": 2.0,
						"pts": 5,
						"hours": 0.1,
						"note": "Everybody reads it. Nobody changes anything."
					},
					{
						"label": "FIX IT QUIETLY",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "quiet",
						"note": "No write-up. They will be a target again."
					},
				]
			},
		],
	},
	"no2fa":
	{
		"title": "THE CLIENT WHO SAID NO",
		"client": 4,
		"specials": ["no2fa"],
		"steps":
		[
			{
				"title": "THE CONVERSATION",
				"text":
				"Soggy Bottom Brewing keeps getting phished and you want stronger passwords and a second login step. Lucy says it is too much hassle and she is not changing anything. How do you handle it?",
				"choices":
				[
					{
						"label": "SHOW HER WHAT A STOLEN PASSWORD LOOKS LIKE",
						"secs": 6.0,
						"pts": 20,
						"hours": 0.5,
						"flag": "showed",
						"note":
						"You pull up a list of leaked passwords from other companies. Hers is on it. She goes quiet."
					},
					{
						"label": "GET A SIGNED WAIVER",
						"secs": 5.0,
						"pts": 15,
						"hours": 0.3,
						"flag": "waiver",
						"note":
						"She signs that she was warned and declined. The paper trail will protect you."
					},
					{
						"label": "INSIST: NO CHANGE, NO SERVICE",
						"secs": 3.0,
						"pts": 10,
						"hours": 0.2,
						"flag": "insisted",
						"note": "She is furious, but she agrees to try it for a month."
					},
					{
						"label": "LET IT GO",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "ignored",
						"note": "You leave without a word. Nothing changes."
					},
				]
			},
			{
				"title": "ROLL IT OUT",
				"text": "If she agrees, how do you do it so it hurts as little as possible?",
				"choices":
				[
					{
						"label": "START WITH THE OWNER AND THE BOOKKEEPER, THEN EVERYONE ELSE",
						"secs": 8.0,
						"pts": 20,
						"hours": 0.6,
						"flag": "phased",
						"needs": "showed",
						"needs_label": "SHOW HER FIRST",
						"note":
						"The two people who handle money get it first. Everyone else gets it next week."
					},
					{
						"label": "TURN IT ON FOR EVERYONE AT ONCE",
						"secs": 6.0,
						"pts": 10,
						"hours": 0.4,
						"flag": "bigbang",
						"needs": "insisted",
						"needs_label": "NEEDS THE INSIST",
						"note":
						"Everyone is locked out Monday morning. Lucy calls you eleven times."
					},
					{
						"label": "WRITE DOWN THE RISK AND LEAVE IT",
						"secs": 4.0,
						"pts": 10,
						"hours": 0.3,
						"flag": "writeup",
						"note": "You file the risk assessment and move on."
					},
				]
			},
			{
				"title": "THE FOLLOW-UP",
				"text": "How do you leave it?",
				"choices":
				[
					{
						"label": "BOOK A CHECK-IN IN THREE WEEKS",
						"secs": 3.0,
						"pts": 15,
						"hours": 0.1,
						"flag": "checkin",
						"note": "A reminder goes on the calendar."
					},
					{
						"label": "NOTHING",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"note": "You will see how it goes."
					},
				]
			},
		],
	},
	"bus":
	{
		"title": "THE ONLY PERSON WHO KNOWS",
		"client": 0,
		"specials": ["bus"],
		"steps":
		[
			{
				"title": "ALAN IS OUT",
				"text":
				"Acme Dental's internet is flaky and the fix is a setting in their firewall. Alan set it up years ago and Alan is out sick today. Nobody has the password. What do you try?",
				"choices":
				[
					{
						"label": "LOOK IN THE DOCUMENTATION PORTAL",
						"secs": 6.0,
						"pts": 25,
						"hours": 0.3,
						"flag": "docs",
						"note":
						"There is an entry, half finished, and a note that says the password is in the safe."
					},
					{
						"label": "LOOK ON ALAN'S DESK",
						"secs": 4.0,
						"pts": 10,
						"hours": 0.2,
						"flag": "sticky",
						"note":
						"A sticky note under the keyboard has a password on it. Of course it does."
					},
					{
						"label": "CALL ALAN AT HOME",
						"secs": 3.0,
						"pts": 15,
						"hours": 0.2,
						"flag": "called",
						"req": ["people", 2],
						"note": "He answers from the couch and tells you."
					},
					{
						"label": "FACTORY RESET THE FIREWALL",
						"secs": 10.0,
						"pts": 0,
						"hours": 0.5,
						"flag": "reset",
						"note":
						"It reboots with a blank configuration. Acme's internet is now completely gone."
					},
				]
			},
			{
				"title": "GET IN",
				"text": "You have a way in (or you wiped it). What next?",
				"choices":
				[
					{
						"label": "CHANGE THE SETTING AND TEST EVERYTHING",
						"secs": 8.0,
						"pts": 25,
						"hours": 0.4,
						"flag": "fixed",
						"note": "The change is small and the internet is stable again."
					},
					{
						"label": "CHANGE THE SETTING AND HOPE",
						"secs": 4.0,
						"pts": 10,
						"hours": 0.1,
						"flag": "unverified",
						"note": "It seems better."
					},
					{
						"label": "REBUILD THE CONFIGURATION FROM SCRATCH",
						"secs": 12.0,
						"pts": 15,
						"hours": 1.0,
						"flag": "rebuilt",
						"needs": "reset",
						"needs_label": "ONLY AFTER A RESET",
						"note": "It takes an hour, and you spend most of it guessing what Alan did."
					},
				]
			},
			{
				"title": "NEVER AGAIN",
				"text": "This should never depend on one person. What do you do before you leave?",
				"choices":
				[
					{
						"label": "DOCUMENT IT AND PUT THE PASSWORD IN THE PASSWORD VAULT",
						"secs": 8.0,
						"pts": 25,
						"hours": 0.5,
						"flag": "documented",
						"note":
						"The firewall now has a page in the portal and a vaulted password everyone can use."
					},
					{
						"label": "WRITE IT ON A STICKY NOTE",
						"secs": 2.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "sticky2",
						"note": "Alan would be proud."
					},
					{
						"label": "TELL ALAN TO WRITE IT DOWN LATER",
						"secs": 1.0,
						"pts": 5,
						"hours": 0.0,
						"note": "He promises to. He will not."
					},
				]
			},
		],
	},
	"netinstall":
	{
		"title": "NETWORK INSTALL",
		"client": 3,
		"specials": ["netinstall"],
		"steps":
		[
			{
				"title": "SURVEY THE SITE",
				"text":
				"Hoot and Holler is opening a branch office: 12 desks, a conference room and a printer room.",
				"choices":
				[
					{
						"label": "WALK THE SITE AND COUNT DROPS",
						"secs": 8.0,
						"pts": 20,
						"hours": 0.5,
						"note": "You count 14 drops, not 12."
					},
					{
						"label": "ASK FOR THE LAYOUT BY EMAIL",
						"secs": 5.0,
						"pts": 10,
						"hours": 0.2,
						"note": "You get a rough floor plan."
					},
					{
						"label": "TRUST THE FLOOR PLAN",
						"secs": 2.0,
						"pts": 5,
						"hours": 0.0,
						"flag": "guess",
						"note": "You plan for 12 drops."
					},
				]
			},
			{
				"title": "RUN THE CABLE",
				"text": "Pulling cable through the ceiling.",
				"choices":
				[
					{
						"label": "CAT6, 14 DROPS",
						"secs": 14.0,
						"pts": 20,
						"hours": 1.0,
						"note": "Cat6 pulled everywhere: future-proof."
					},
					{
						"label": "CAT5E, 14 DROPS",
						"secs": 10.0,
						"pts": 15,
						"hours": 0.8,
						"note": "Cat5e is fine for gigabit."
					},
					{
						"label": "CAT5E, 10 DROPS TO SAVE TIME",
						"secs": 6.0,
						"pts": 5,
						"hours": 0.5,
						"flag": "short",
						"note": "Four desks have no wall jack."
					},
				]
			},
			{
				"title": "TEST THE RUNS",
				"text": "Are all those cables good?",
				"choices":
				[
					{
						"label": "CERTIFY EVERY DROP WITH THE TESTER",
						"secs": 10.0,
						"pts": 20,
						"hours": 0.5,
						"note": "Every drop certified."
					},
					{
						"label": "SPOT CHECK A FEW",
						"secs": 4.0,
						"pts": 10,
						"hours": 0.2,
						"flag": "untested",
						"note": "Most look fine."
					},
					{
						"label": "SKIP IT, WE WILL FIND OUT",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "untested",
						"note": "We will find out."
					},
				]
			},
			{
				"title": "CONFIGURE THE SWITCHES",
				"text": "Data, voice phones and guest Wi-Fi all share this network.",
				"choices":
				[
					{
						"label": "VLANS: DATA, VOICE AND GUEST",
						"secs": 8.0,
						"pts": 25,
						"hours": 0.5,
						"req": ["powershell", 2],
						"note": "Three clean VLANs with scripted configs."
					},
					{
						"label": "SEPARATE THE VOICE VLAN ONLY",
						"secs": 8.0,
						"pts": 15,
						"hours": 0.5,
						"note": "Phones are separate. Guests share the data VLAN."
					},
					{
						"label": "ONE FLAT NETWORK",
						"secs": 3.0,
						"pts": 5,
						"hours": 0.1,
						"flag": "flat",
						"note": "Everything on one network."
					},
				]
			},
			{
				"title": "WI-FI",
				"text": "Staff and guests want wireless everywhere.",
				"choices":
				[
					{
						"label": "SURVEY, THEN PLACE TWO ACCESS POINTS",
						"secs": 8.0,
						"pts": 20,
						"hours": 0.5,
						"note": "Coverage is solid everywhere."
					},
					{
						"label": "ONE ACCESS POINT IN THE MIDDLE",
						"secs": 3.0,
						"pts": 10,
						"hours": 0.1,
						"flag": "deadzone",
						"note": "The conference room has a dead spot."
					},
				]
			},
			{
				"title": "DOCUMENT IT",
				"text": "The job is done and it is nearly time to go.",
				"choices":
				[
					{
						"label": "LABEL THE PANEL AND WRITE IT UP",
						"secs": 8.0,
						"pts": 20,
						"hours": 0.4,
						"flag": "documented",
						"note": "Every port labelled. Documentation filed."
					},
					{
						"label": "SKIP THE PAPERWORK",
						"secs": 0.0,
						"pts": 0,
						"hours": 0.0,
						"flag": "undocumented",
						"note": "No documentation. Future you will suffer."
					},
				]
			},
		],
	},
}
var BOOKS: Dictionary = DEFAULT_BOOKS.duplicate(true)
const DEFAULT_PROBLEMS := {
	"rack":
	[
		{
			"summary": "RACK FELL OFF THE WALL - everything is down",
			"fix": "project",
			"pri": 1,
			"special": "rack",
			"body":
			"The whole network rack came off the wall with a crash! Nothing works! Please come NOW. - %s"
		},
		{
			"summary": "No internet in the whole shop",
			"fix": "project",
			"pri": 2,
			"special": "rack",
			"body": "Is the internet down for you too? It is dead here. - %s"
		},
		{
			"summary": "Phones are dead",
			"fix": "project",
			"pri": 2,
			"special": "rack",
			"body": "Customers cannot reach us, the phones are all dead. - %s"
		},
	],
	"migration":
	[
		{
			"summary": "Server migration: cutover",
			"fix": "project",
			"pri": 3,
			"special": "migration",
			"server": true,
			"body":
			"The old server is out of support, we agreed you would move us to the new one. Please do it carefully. - %s"
		},
	],
	"email24":
	[
		{
			"summary": "EMAIL DOWN - 24x7 site",
			"fix": "project",
			"pri": 1,
			"special": "email24",
			"server": true,
			"body":
			"Nobody has had email for an hour and our fermentation alerts come by email. We run around the clock. FIX IT! - %s"
		},
	],
	"rdp":
	[
		{
			"summary": "Server very slow, strange logins in the log",
			"fix": "project",
			"pri": 2,
			"special": "rdp",
			"server": true,
			"body":
			"Our server has been crawling all week and the log shows people we do not know. Can you look? - %s"
		},
	],
	"ceofraud":
	[
		{
			"summary": "Odd request to wire $38,000 from the trust account",
			"fix": "project",
			"pri": 1,
			"special": "ceofraud",
			"body":
			"Our paralegal got an email from Mr. Spence asking her to wire $38,000. He says he never sent it. What is going on? - %s"
		},
	],
	"no2fa":
	[
		{
			"summary": "Security review: stronger logins for Soggy Bottom",
			"fix": "project",
			"pri": 3,
			"special": "no2fa",
			"body":
			"You wanted to talk about passwords or something. I do not have time for this. - %s"
		},
	],
	"bus":
	[
		{
			"summary": "Internet keeps dropping at Acme Dental",
			"fix": "project",
			"pri": 2,
			"special": "bus",
			"body":
			"The internet drops every few minutes and patients are waiting. Alan always knows what to do but he is out today! - %s"
		},
	],
	"netinstall":
	[
		{
			"summary": "New branch office network install",
			"fix": "project",
			"pri": 3,
			"special": "netinstall",
			"body":
			"We open the new branch next week and need the network, phones and Wi-Fi set up. - %s"
		},
	],
}
var PROBLEMS: Dictionary = DEFAULT_PROBLEMS.duplicate(true)

var active := {}  # the job in progress: {id, tickets, step, pts, flags, log, done, result, start_client_backup}

var last_note := ""


func reset() -> void:
	active = {}
	last_note = ""


func is_active() -> bool:
	return not active.is_empty() and not bool(active.done)


func steps_of(id: String) -> Array:
	return BOOKS[id].steps


func max_points(id: String) -> int:
	var total := 0
	for step in steps_of(id):
		var best := 0
		for ch in step.choices:
			best = maxi(best, int(ch.pts))
		total += best
	return total


# open the tickets for a job and start it; returns the main ticket id
func start(id: String, source := "email") -> int:
	var ids := []
	for prob in PROBLEMS[id]:
		var t := Msp.create_problem(int(BOOKS[id].client), prob, source)
		if not t.is_empty():
			ids.append(int(t.id))
	active = {
		"id": id,
		"tickets": ids,
		"step": 0,
		"pts": 0,
		"flags": {},
		"log": [],
		"done": false,
		"result": {},
		"backup_ok": bool(Msp.backups[int(BOOKS[id].client)].ok),
	}
	if id == "email24":
		Story.overtime = true
	changed.emit()
	return int(ids[0]) if not ids.is_empty() else 0


func current_step() -> Dictionary:
	if active.is_empty() or bool(active.done):
		return {}
	return steps_of(str(active.id))[int(active.step)]


# why a choice can't be picked yet ("" = available)
func lock_reason(choice: Dictionary) -> String:
	if choice.has("req"):
		var skill: String = choice.req[0]
		if Skills.level(skill) < int(choice.req[1]):
			return "%s %d" % [str(Skills.NAMES[skill]), int(choice.req[1])]
	if choice.has("needs") and not active.flags.get(choice.needs, false):
		return str(choice.get("needs_label", "NEEDS " + str(choice.needs).to_upper()))
	return ""


func choice_secs(choice: Dictionary) -> float:
	return float(choice.secs) if Campaign.active else 0.0


func choose(index: int) -> Dictionary:
	var step := current_step()
	if step.is_empty():
		return {}
	var choice: Dictionary = step.choices[index]
	if lock_reason(choice) != "":
		return {}
	active.pts = int(active.pts) + int(choice.pts)
	if choice.has("flag"):
		active.flags[choice.flag] = true
	var note := str(choice.note)
	if choice.get("effect", "") == "backup":
		var client: int = BOOKS[active.id].client
		var b := Msp.backup_check(client)
		if not b.ok:
			Msp.backup_rerun(client)
			active.flags["backup_fixed"] = true
			note = "The backup was FAILING. You re-ran it before touching anything."
			active.pts = int(active.pts) + 10
	World.clock += float(choice.get("hours", 0.0))
	active.log.append(note)
	last_note = note
	active.step = int(active.step) + 1
	if int(active.step) >= steps_of(str(active.id)).size():
		finish()
	changed.emit()
	return choice


func grade_for(percent: int) -> String:
	for entry in [[92, "S"], [80, "A"], [65, "B"], [45, "C"]]:
		if percent >= int(entry[0]):
			return str(entry[1])
	return "D"


func finish() -> void:
	var id: String = active.id
	var flags: Dictionary = active.flags
	var percent := clampi(int(100.0 * float(active.pts) / float(max_points(id))), 0, 100)
	var grade := grade_for(percent)
	var rep_delta: int = {"S": 5, "A": 3, "B": 1, "C": -2, "D": -5}[grade]
	var client: int = BOOKS[id].client
	var contact: String = Msp.CLIENTS[client].contact
	var address: String = contact + " <" + Msp.CLIENTS[client].mail + ">"
	var extra := _outcome(id, flags, client)
	rep_delta += int(extra.rep)
	Msp.score += int((percent - 50) / 2.5) + int(extra.score)
	Campaign.adjust_rep(rep_delta)
	Sales.adjust(client, {"S": 10, "A": 6, "B": 2, "C": -5, "D": -12}[grade])
	Skills.add_xp(
		(
			"networking"
			if id in ["rack", "netinstall"]
			else (
				"security"
				if id in ["rdp", "ceofraud", "no2fa"]
				else ("people" if id == "bus" else "servers")
			)
		),
		12
	)
	for t in Msp.tickets:
		if t.status != "Closed" and BOOKS[id].specials.has(str(t.special)):
			t.fix_done = true
			t.notes.append("Job finished: grade %s (%d%%)." % [grade, percent])
			var ep := Msp.endpoint(str(t.endpoint))
			if not ep.is_empty() and ep.problem == "project":
				ep.problem = ""
	Msp.mail(address, "RE: " + str(PROBLEMS[id][0].summary), str(extra.mail))
	if id == "email24":
		Story.overtime = false
		Story.ot_hours = maxf(0.0, World.clock - World.DAY_END)
	for follow in extra.follow:
		Story.queue_followup(follow)
	active.done = true
	active.result = {"pts": percent, "grade": grade, "text": str(extra.mail)}
	Story.flags[id] = grade
	changed.emit()


# what the flags cost or earn: returns {rep, score, mail, follow: [{client, summary, body}]}
func _outcome(id: String, flags: Dictionary, client: int) -> Dictionary:
	var out := {"rep": 0, "score": 0, "mail": "Thank you, that was handled well.", "follow": []}
	match id:
		"rack":
			out.mail = "We are back up. Thank you for dropping everything!"
			if flags.get("damaged", false):
				out.score = -5
				out.mail = "We are up, but you killed the switch fan. Please be careful."
			if flags.get("weak", false) or flags.get("temp", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Rack is wobbling again",
						"body":
						"The rack is moving on the wall again. I am scared to touch it. - %s",
						"pri": 2
					}
				)
			if flags.get("miswired", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Some desks have no network",
						"body": "Two desks cannot get online since the rack incident. - %s",
						"pri": 2
					}
				)
			if flags.get("unverified", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Phones randomly dropping calls",
						"body":
						"Our phones drop calls since the rack fell. You said it was fixed! - %s",
						"pri": 2
					}
				)
		"migration":
			out.mail = "The new server is great, nobody noticed the move."
			if flags.get("nocheck", false) and not active.backup_ok:
				out.rep = -12
				out.score = -20
				out.mail = "The cutover corrupted the accounting data and your backup was NOT running. We lost a month of books!"
				(
					Msp
					. send_text(
						"Boss",
						"Brightside lost data in the migration and the backup was broken. We need to talk."
					)
				)
			elif flags.get("outage", false) or flags.get("downtime", false):
				out.rep = -2
				out.mail = "It works now, but we had a rough hour with nobody able to open files."
			if flags.get("perms", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Staff can see each other's files",
						"body": "Everyone can open the payroll folder now! - %s",
						"pri": 2
					}
				)
		"email24":
			out.mail = "Email is back and the brewery alerts are flowing. You saved the batch. Thank you!"
			if flags.get("rebooted", false):
				out.score = -5
			if flags.get("risky", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Email database errors again",
						"body": "Email stopped again after midnight, errors in the log. - %s",
						"pri": 2
					}
				)
			if flags.get("unverified", false):
				out.rep = -3
				out.mail = "You said it was fixed, but mail still bounces from outside. Please check properly!"
		"rdp":
			out.mail = "Thank you. We had no idea the server was open to the whole internet."
			if (
				(flags.get("vpn", false) or flags.get("autoblock", false))
				and flags.get("audited", false)
			):
				out.rep = 2
				out.mail = "Door closed and accounts audited. We sleep better now. Thank you."
			if flags.get("open", false):
				out.rep = -2
				(
					out
					. follow
					. append(
						{
							"client": client,
							"summary": "Server hacked again from overseas",
							"body":
							"The log shows another login from overseas and files have been renamed. You said it was fixed! - %s",
							"pri": 1
						}
					)
				)
			if flags.get("obscurity", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Password guessing is back on the new port",
						"body": "The same attackers are back, on the new port number. - %s",
						"pri": 2
					}
				)
			if flags.get("unaudited", false) or flags.get("partial", false):
				out.score = -5
				(
					out
					. follow
					. append(
						{
							"client": client,
							"summary": "Our email is being blocked as spam",
							"body":
							"Customers say our messages bounce as spam. Is our server sending junk? - %s",
							"pri": 2
						}
					)
				)
		"ceofraud":
			out.mail = "Thank you. The money is safe and Mr. Spence says he would like you to explain the whole thing to the partners."
			if flags.get("wired", false):
				out.rep = -10
				out.score = -25
				out.mail = "The $38,000 is gone. The bank cannot recall it. The partners want to know why IT did not stop it."
				Msp.send_text("Boss", "Hoot and Holler wired money to a scammer. Come see me. Now.")
			else:
				if flags.get("late", false) and not flags.get("bank", false):
					out.score = -10
					out.mail = "The bank says part of the wire is already gone. We will be fine, but it was close."
				if flags.get("replied", false):
					out.score -= 3
				if flags.get("deleted", false):
					(
						out
						. follow
						. append(
							{
								"client": client,
								"summary": "The bank wants the original email",
								"body":
								"The bank asked for the original fraud email and it was deleted. Can you recover it? - %s",
								"pri": 3
							}
						)
					)
				if flags.get("partial", false) or flags.get("reset", false):
					(
						out
						. follow
						. append(
							{
								"client": client,
								"summary": "Another strange email from the boss",
								"body":
								"We just got another odd email that looks like Mr. Spence wrote it. - %s",
								"pri": 1
							}
						)
					)
				if flags.get("quiet", false):
					out.follow.append(
						{
							"client": client,
							"summary": "The same request again",
							"body":
							"Somebody emailed asking for a wire again. Is this normal? - %s",
							"pri": 2
						}
					)
				if flags.get("trained", false):
					out.rep = 3
		"no2fa":
			out.mail = "I did not like it, but we have it now."
			if flags.get("ignored", false):
				out.rep = -3
				out.mail = "Nobody wanted to talk about it."
				(
					out
					. follow
					. append(
						{
							"client": client,
							"summary": "Our email was used to send spam",
							"body":
							"Customers say they got spam from our address and one said it was a phishing email! - %s",
							"pri": 1
						}
					)
				)
				Sales.adjust(client, -6)
			elif flags.get("waiver", false) and not flags.get("showed", false):
				out.mail = "We signed what you asked. If something happens it is not on you, I suppose."
			if flags.get("bigbang", false):
				Sales.adjust(client, -8)
			if flags.get("showed", false) and flags.get("phased", false):
				out.rep = 2
				out.mail = "You were right about the password. Thank you for not making me feel stupid."
		"bus":
			out.mail = "Thank you for jumping in. We never realised how much depended on Alan."
			if flags.get("reset", false):
				out.score = -10
				out.mail = "We lost the internet for an hour and a half. Never touch the firewall like that again."
				Msp.send_text(
					"Alan",
					"I heard you reset the firewall. I am coming in. Do not touch anything else."
				)
			if flags.get("sticky2", false) or flags.get("unverified", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Internet dropped again",
						"body": "It dropped again this morning. Was it fixed? - %s",
						"pri": 2
					}
				)
			if flags.get("documented", false):
				out.rep = 2
				Social.change("Alan", 3)
		"netinstall":
			out.mail = "The new branch is online and everything works. Great job."
			if flags.get("documented", false):
				out.rep = 2
			if flags.get("untested", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Two wall jacks are dead",
						"body": "Two desks at the branch have no network from the wall. - %s",
						"pri": 3
					}
				)
			if flags.get("flat", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Guest Wi-Fi can reach our servers",
						"body": "A guest could open our file server. Is that normal?! - %s",
						"pri": 2
					}
				)
			if flags.get("deadzone", false) or flags.get("short", false):
				out.follow.append(
					{
						"client": client,
						"summary": "Branch Wi-Fi / jacks missing",
						"body":
						"The conference room has no Wi-Fi and four desks have no jack. - %s",
						"pri": 3
					}
				)
	return out
