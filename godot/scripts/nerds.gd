extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# LabRat Nerds: the community forum and IRC channel for LabRat users (a parody of the LabTech Geek community of the day).
#   FORUM (R27): a board index (BOARDS: topic and post counts that grow with the day, a last-post line, footer statistics and a clock),
#   about 65 period-correct threads (THREADS: a post and replies each) and today's five open questions. Reading one of today's
#   questions gives a little skill XP; replying (needs the skill level, and the PowerShell level for script threads) gives more XP and
#   karma and your post appears in the thread; a wrong attempt gets a polite correction (-1 karma, none on cozy Easy).
#   The screens are drawn by forum_view.gd. Everything is seeded by the campaign day and the run seed, so a day looks the same twice.
#   IRC (#labratnerds): "call a friend". Ask the channel which fix a ticket needs, or what to do at the current job step.
#   Four nicks answer one by one; accuracy depends on the nick and on your karma; the troll may lead you astray.
#   Asking costs a little karma and has a cooldown, so you earn the right to ask by contributing on the forum.

signal changed

const NICKS := {
	"rodent_rick": {"acc": 0.85, "color": Color("5aa0e8")},
	"gnawer": {"acc": 0.75, "color": Color("3cc15a")},
	"PS_wizard": {"acc": 0.9, "color": Color("c585f0")},
	"old_hand": {"acc": 0.8, "color": Color("e0a030")},
	"MPriest": {"acc": 0.85, "color": Color("e8d88a")},
	"GrizzleAdmin": {"acc": 0.9, "color": Color("d9a066")},
	"HELPPLZ_Pip": {"acc": 0.3, "color": Color("f06292")},
	"xX_n00b_Xx": {"acc": 0.4, "color": Color("e07b22")},
	"trollbot": {"acc": 0.2, "color": Color("d23c3c")},
}
# forum titles under the nick (nicks that only post on the forum are not in NICKS: they never answer in the channel)
const POSTERS := {
	"rodent_rick": "REGULAR",
	"gnawer": "MEMBER",
	"PS_wizard": "GURU",
	"old_hand": "REGULAR",
	"MPriest": "MOD",
	"GrizzleAdmin": "ADMIN",
	"HELPPLZ_Pip": "LURKER",
	"xX_n00b_Xx": "LURKER",
	"trollbot": "MEMBER",
	"sysadmin_sue": "MEMBER",
	"wrench_rob": "MEMBER",
	"cable_cat": "REGULAR",
	"tcp_tim": "REGULAR",
	"bytes_n_bagels": "MEMBER",
	"dbl_click_dave": "MEMBER",
	"packet_pam": "REGULAR",
	"LAN_lord": "GURU",
	"ShadowPoint_Brad": "VENDOR",
	"WebWoot_Dee": "VENDOR",
	"SoftSwipe_Rex": "VENDOR",
}
const POSTER_COLORS := ["4fb3a0", "b58cd8", "d98c6a", "7aa7d9", "c2b04a", "d9738f", "7fc46e"]
const PLAYER_NICK := "FreshRat"
const NEW_MEMBERS := [
	"tek_tom",
	"jenny_msp",
	"bigfoot_it",
	"sql_steve",
	"vlan_vince",
	"rack_rachel",
	"ping_pong_pete",
	"helpdesk_hank",
	"nina_noc",
	"dave_the_admin",
	"fixit_felix",
	"greg_in_it",
	"patch_patty",
	"one_man_msp",
	"reboot_randy",
]
const DEFAULT_JOKES := [
	"have you tried turning it off and on again?",
	"just reinstall windows lol",
	"blame the antivirus",
	"that is a PEBKAC, tell the user",
	"format c: fixes everything",
]
var JOKES: Array = DEFAULT_JOKES.duplicate(true)
# MPriest (Priest Michael, the forum moderator) ends his answers in the channel with one of these
const DEFAULT_BLESSINGS := [
	"bless you, mate.",
	"go in peace and test your restores.",
	"she'll be right.",
	"no worries, and sin no more.",
]
var BLESSINGS: Array = DEFAULT_BLESSINGS.duplicate(true)
# GrizzleAdmin (the grumpy old-timer admin) ends his answers with one of these
const DEFAULT_GRUMBLES := [
	"read the FAQ next time.",
	"in my day we had a manual and we read it.",
	"this was solved in 2009. use the search.",
	"and get off my forum.",
]
var GRUMBLES: Array = DEFAULT_GRUMBLES.duplicate(true)
# the polite Re: line a nick posts when you answer a question that is over your head
const DEFAULT_CORRECTIONS := [
	"Re: Thanks for trying! That will not work here, read the replies above again.",
	"Re: Close, but test that on a lab box first. It breaks on this setup.",
	"Re: Nice try. Come back when you have done this one a few times.",
	"Re: I would not run that in production. Have a look at the earlier posts.",
]
var CORRECTIONS: Array = DEFAULT_CORRECTIONS.duplicate(true)
# the screen text (the title, the disclaimer, the lock jokes, ...)
const DEFAULT_TEXT := {
	"title": "LABRAT NERDS - AUTOMATING THE BURROW",
	"disclaimer":
	"This community is NOT affiliated with the software vendor. Information is provided as-is. Test all scripts on a lab system before production, including scripts from off duty vendor employees.",
	"vip_locked":
	"VIP AREA: VENDOR EMPLOYEES ONLY. THE DOOR HAS A BADGE READER AND YOU HAVE A LANYARD FULL OF STICKERS.",
	"vip_guru": "EVEN A GURU CANNOT GET IN. THE ADMIN SAYS THE SNACKS ARE NOT THAT GOOD.",
	"vendor_closed":
	"Only approved vendors can post in the Vendor Lounge. You can read the offers.",
	"sticky_locked": "STICKY THREAD: LOCKED, NO REPLIES.",
	"solved": "SOLVED. THIS ONE IS CLOSED FOR REPLIES.",
	"posted": "POSTED. +%d KARMA",
	"no_karma_lost": "(NO KARMA LOST)",
	"need_ps": "NEEDS POWERSHELL LEVEL %d",
	"ps_note":
	"YOUR POWERSHELL IS LEVEL %d. SCRIPT: THIS CLIENT IS FOR LEVEL 2, SCRIPT: ALL CLIENTS FOR LEVEL 4.",
	"ps_note_on":
	"YOUR POWERSHELL IS LEVEL %d. SCRIPT: THIS CLIENT IS UNLOCKED, AND SCRIPT THREADS EARN +1 KARMA.",
	"dash_note": "TIP: THE BIGGEST NUMBER ON THE TV IS ALWAYS THE OLDEST TICKET.",
	"vendor_note": "%d VENDORS HAVE YOUR BADGE NUMBER FROM RODENT NATION.",
	"open_note": "OPEN = TODAY'S QUESTIONS. READ THEM FOR XP, REPLY FOR XP AND KARMA.",
	"sig_regular": "-- test it on a lab box first",
	"sig_guru": "-- GURU. I broke it before you did.",
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)
const DEFAULT_BOARDS := [
	{
		"id": "general",
		"label": "GENERAL SQUEAKS",
		"desc": "Anything about LabRat that fits nowhere else",
		"parent": "",
		"topics": 331,
		"posts": 1621,
		"gt": 2,
		"gp": 9
	},
	{
		"id": "burrow",
		"label": "THE BURROW",
		"desc": "Community: off topic, links, musings and war stories",
		"parent": "",
		"topics": 148,
		"posts": 1190,
		"gt": 1,
		"gp": 7
	},
	{
		"id": "sandbox",
		"label": "PLUGIN SANDBOX",
		"desc": "Plugins you wrote, plugins you broke",
		"parent": "",
		"topics": 122,
		"posts": 2338,
		"gt": 1,
		"gp": 8
	},
	{
		"id": "tabs",
		"label": "CUSTOM TABS",
		"desc": "Sub-forum: tabs on the computer screen",
		"parent": "sandbox",
		"topics": 51,
		"posts": 402,
		"gt": 1,
		"gp": 3
	},
	{
		"id": "dash",
		"label": "DASHBOARDS",
		"desc": "Sub-forum: tiles, wall TVs and big red numbers",
		"parent": "sandbox",
		"topics": 33,
		"posts": 261,
		"gt": 1,
		"gp": 3
	},
	{
		"id": "advanced",
		"label": "ADVANCED CONFIGS",
		"desc": "Crazy modifications and semi-hidden features",
		"parent": "",
		"topics": 79,
		"posts": 640,
		"gt": 1,
		"gp": 4
	},
	{
		"id": "cloud",
		"label": "CLOUD BURROW",
		"desc": "Hosted servers, hosted mail, other people's computers",
		"parent": "",
		"topics": 5,
		"posts": 31,
		"gt": 0,
		"gp": 1
	},
	{
		"id": "tips",
		"label": "CONFIG TIPS",
		"desc": "Small settings that save a big headache",
		"parent": "",
		"topics": 88,
		"posts": 714,
		"gt": 1,
		"gp": 5
	},
	{
		"id": "tools",
		"label": "COOL TOOLS",
		"desc": "Command line tools, scripts and PowerShell",
		"parent": "",
		"topics": 96,
		"posts": 805,
		"gt": 1,
		"gp": 5
	},
	{
		"id": "dataview",
		"label": "DATAVIEW SWAP",
		"desc": "Share and build dataviews",
		"parent": "",
		"topics": 64,
		"posts": 388,
		"gt": 1,
		"gp": 3
	},
	{
		"id": "hardware",
		"label": "HARDWARE MONITORING",
		"desc": "Tools and SNMP OIDs",
		"parent": "",
		"topics": 71,
		"posts": 530,
		"gt": 1,
		"gp": 4
	},
	{
		"id": "requests",
		"label": "FEATURE REQUESTS",
		"desc": "Let us know what would make your job even easier",
		"parent": "",
		"topics": 57,
		"posts": 470,
		"gt": 1,
		"gp": 4
	},
	{
		"id": "remote",
		"label": "REMOTE CONTROL",
		"desc": "Redirectors, tunnels and VNC",
		"parent": "",
		"topics": 62,
		"posts": 512,
		"gt": 1,
		"gp": 4
	},
	{
		"id": "reporting",
		"label": "REPORTING",
		"desc": "Reports, report ideas and some SQL",
		"parent": "",
		"topics": 83,
		"posts": 604,
		"gt": 1,
		"gp": 4
	},
	{
		"id": "scripts",
		"label": "SCRIPT SWAP",
		"desc": "Share your scripts: the biggest board",
		"parent": "",
		"topics": 319,
		"posts": 2160,
		"gt": 2,
		"gp": 12
	},
	{
		"id": "vendor",
		"label": "VENDOR LOUNGE",
		"desc": "Approved vendors only can post. Everybody can read.",
		"parent": "",
		"topics": 3,
		"posts": 9,
		"gt": 0,
		"gp": 0,
		"is_new": true,
		"vendors_only": true
	},
	{
		"id": "vip",
		"label": "VIP AREA",
		"desc": "For vendor employees ONLY",
		"parent": "",
		"topics": 0,
		"posts": 0,
		"gt": 0,
		"gp": 0,
		"locked": true
	},
	{
		"id": "plugdev",
		"label": "PLUGIN DEVELOPMENT",
		"desc": "Writing plugins: API, SDK, and the lab you do not have",
		"parent": "",
		"topics": 41,
		"posts": 388,
		"gt": 1,
		"gp": 2
	},
]
var BOARDS: Array = DEFAULT_BOARDS.duplicate(true)
const DEFAULT_THREADS := [
	{
		"title": "Print spooler keeps dying on 2008 R2",
		"board": "general",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"The spooler stops every morning around nine. Restart it and it works until tomorrow. Server is 2008 R2, about 40 printers."
			},
			{
				"by": "old_hand",
				"text":
				"Delete the stuck job files in the spool folder, then check for the one bad driver. It is always the 32 bit driver from 2009."
			},
			{
				"by": "gnawer",
				"text":
				"Seconded. Twenty seven of our forty printers were running one cheap driver. Replaced it and no more morning deaths."
			},
		],
		"answer":
		"Clear the spool folder, stop and start the service, then remove the old 32 bit driver. Mine was a copier from 2009.",
	},
	{
		"title": "Users locked out after bad passwords: GPO?",
		"board": "tips",
		"skill": "security",
		"level": 0,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Whole office locked out on Monday mornings. Is the lockout policy too tight? It says 3 tries."
			},
			{
				"by": "GrizzleAdmin",
				"text":
				"3 tries is a policy written by someone who has never met a user. Set 10, reset after 30 minutes. And look for the phone that still has the old password saved."
			},
			{
				"by": "rodent_rick",
				"text":
				"The phone. It is always the phone. Check the mail sync on the boss's phone first."
			},
		],
		"answer":
		"Raise the threshold to 10 and the reset to 30 minutes, then hunt the phone or laptop with the old saved password.",
	},
	{
		"title": "Disk full, where is all the temp junk?",
		"board": "tips",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "cable_cat",
				"text":
				"C: is at 98 percent on a file server. Not much installed. Where does the space go?"
			},
			{
				"by": "old_hand",
				"text":
				"Run a folder size tool from the root. Check the Windows folder for old installer files, and look for a log that never rotates."
			},
			{
				"by": "tcp_tim",
				"text":
				"In my case it was 40 GB of IIS logs. Nobody had set the cleanup. Twelve months of them."
			},
		],
		"answer":
		"Scan the drive by folder size. Usually it is logs, old profiles or the installer cache. Clear those, then set a cleanup job.",
	},
	{
		"title": "Blue screen 0x7B after a controller swap",
		"board": "advanced",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text":
				"Swapped the RAID card on an old server, now it blue screens 0x7B at boot. Disks are fine on the new card."
			},
			{
				"by": "PS_wizard",
				"text":
				"0x7B is inaccessible boot device. The new controller driver is not in the image. Boot a repair disk and load the driver, or switch it to the old mode in the BIOS."
			},
			{"by": "xX_n00b_Xx", "text": "just reinstall windows lol"},
			{"by": "GrizzleAdmin", "text": "Nobody reinstall anything. Read the post above."},
		],
		"answer":
		"Boot the repair disk, load the new controller driver, then reboot. Do not reinstall, the data is fine.",
	},
	{
		"title": "CryptoLocker: shadow copies, any luck?",
		"board": "general",
		"skill": "security",
		"level": 2,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text":
				"A client got hit. Files all renamed and a ransom note, 300 dollars in bitcoin. They have no backup. Is paying the only way?"
			},
			{
				"by": "PS_wizard",
				"text":
				"Try shadow copies first. The thing does not always remove them. Right click the folder, previous versions. Disconnect the machine from the network before you do anything else."
			},
			{
				"by": "rodent_rick",
				"text":
				"We got about 40 percent back that way. Pay only if you must, and tell the client it may not work. Then sell them a backup."
			},
		],
		"answer":
		"Unplug it from the network, check previous versions and shadow copies, and restore what you can. Paying is a last resort.",
	},
	{
		"title": "Robocopy /MIR and NTFS permissions",
		"board": "tools",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text":
				"Mirrored a share to a new server with robocopy /MIR. Files are there but nobody can open half of them."
			},
			{
				"by": "old_hand",
				"text":
				"You need /COPY:DATSOU, or /SEC. Default does not copy the security. And careful, /MIR deletes at the destination."
			},
			{
				"by": "GrizzleAdmin",
				"text":
				"I have seen /MIR delete a whole department. Run it with /L first. Always /L first."
			},
		],
		"answer":
		"Use /COPYALL or /COPY:DATSOU, run with /L first to preview, and only then run it for real. /MIR deletes extras.",
	},
	{
		"title": "VLANs for voice and data on a cheap switch",
		"board": "hardware",
		"skill": "networking",
		"level": 2,
		"posts":
		[
			{
				"by": "packet_pam",
				"text":
				"Office wants phones and PCs on separate VLANs on one cheap managed switch. Phones plug in, PCs plug into the phone."
			},
			{
				"by": "gnawer",
				"text":
				"Tag the voice VLAN on the phone port, leave data untagged as the native VLAN. The phone passes the PC through."
			},
			{
				"by": "tcp_tim",
				"text":
				"Check the switch supports it on the same port. Some cheap ones only do one tagged VLAN per access port."
			},
		],
		"answer":
		"Make each port a trunk with data untagged and voice tagged, so the phone tags itself and passes the PC through.",
	},
	{
		"title": "Stopping RDP brute force: what do you use?",
		"board": "remote",
		"skill": "security",
		"level": 1,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Event log full of failed logins from China. Port 3389 is forwarded to the server. Please tell me what to do."
			},
			{
				"by": "rodent_rick",
				"text":
				"First, stop forwarding 3389. Use a VPN. If you cannot, change the port and use a firewall that blocks repeat failures."
			},
			{
				"by": "MPriest",
				"text": "Brother, I have seen this sin many times. Close the door. Bless you."
			},
		],
		"answer":
		"Stop forwarding 3389. Put it behind a VPN or at least a firewall that blocks repeat failed logins, and check for weak passwords.",
	},
	{
		"title": "Windows XP end of support: migration list?",
		"board": "burrow",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"April 8 is close. Anyone have a checklist for moving a small office off XP? Twelve PCs, two with old apps."
			},
			{
				"by": "old_hand",
				"text":
				"Inventory first. Ones that cannot go to 7 get isolated, no internet. Back up profiles, move to 7 and Office 2010 at the same time."
			},
			{
				"by": "GrizzleAdmin",
				"text":
				"I was running XP before most of you could spell RMM. Do not wait until April 7."
			},
		],
		"answer":
		"Inventory the PCs, back up the profiles, upgrade to Windows 7 and isolate any old app machine from the internet.",
	},
	{
		"title": "Script to clean temp files on every client",
		"board": "scripts",
		"skill": "servers",
		"level": 1,
		"ps": 1,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text":
				"Need a script to clear temp folders on all our clients every week. Anything safe to run unattended?"
			},
			{
				"by": "PS_wizard",
				"text":
				"Delete files older than a week in the user temp and the Windows temp. Skip anything locked. Run it as a script in the RMM, not by hand."
			},
			{"by": "trollbot", "text": "format c: fixes everything"},
		],
		"answer":
		"Delete files older than seven days from the Windows and user temp folders, skip the locked ones, and run it weekly as a scheduled script.",
	},
	{
		"title": "Forum rules (read before posting)",
		"board": "general",
		"skill": "people",
		"level": 0,
		"sticky": true,
		"posts":
		[
			{
				"by": "GrizzleAdmin",
				"text":
				"1. Search before you ask. 2. Say what version you run. 3. Test every script on a lab box before production. 4. No ALL CAPS posts. 5. Be polite or be gone. This site is not affiliated with the software vendor."
			},
			{
				"by": "MPriest",
				"text": "Rule six is mine: sin no more, and post your results afterwards."
			},
			{"by": "HELPPLZ_Pip", "text": "WHAT IS A LAB BOX?"},
		],
		"answer": "",
	},
	{
		"title": "Agents not reporting in",
		"board": "general",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "tcp_tim",
				"text":
				"About 30 agents have not checked in since Friday. Server is fine. Anyone else seeing this?"
			},
			{
				"by": "gnawer",
				"text":
				"Do the offline machines share a site? Ours were all behind one router that got a new firmware."
			},
			{
				"by": "old_hand",
				"text":
				"Check the agent service and the time. Clocks that are off by a few minutes stop checking in."
			},
		],
		"answer":
		"Check whether they share a site or router first, then the agent service and the clock on the machine.",
	},
	{
		"title": "Patch Tuesday auto-approve rules",
		"board": "general",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "cable_cat",
				"text":
				"Do you auto-approve everything on Patch Tuesday or wait? Last month a patch broke printing for a whole client."
			},
			{
				"by": "rodent_rick",
				"text":
				"Critical and security on a test group first, the rest a week later. Never on the same day as month end."
			},
			{
				"by": "GrizzleAdmin",
				"text": "Patch Tuesday is not the day to find out. Wait a week."
			},
		],
		"answer":
		"Approve critical updates to a small test group first, wait a few days, then roll out. Never patch the whole fleet on the first day.",
	},
	{
		"title": "Which backup alerts are noise?",
		"board": "general",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text": "I get 200 backup emails a day. Which ones do you really act on?"
			},
			{
				"by": "PS_wizard",
				"text":
				"Failed twice in a row is a call. Missing for 24 hours is a call. Success mails go to the bin. Warnings about open files, ignore."
			},
			{"by": "MPriest", "text": "A green tick is a rumour. Test a restore once a month."},
		],
		"answer":
		"Act on two failures in a row or a missing job, ignore success mails and open file warnings, and test one restore every month.",
	},
	{
		"title": "Rodent Nation 2014: who is going?",
		"board": "burrow",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"Anyone going to the conference in Orlando? I need someone to share a taxi and a room with."
			},
			{
				"by": "MPriest",
				"text": "I will be at the community table with a sunburn. Come say hello."
			},
			{"by": "xX_n00b_Xx", "text": "is there free pizza"},
		],
		"answer":
		"I am hoping to go. See you at the community table, and I will bring a pen for the raffle.",
	},
	{
		"title": "What is on your desk right now? Post pics",
		"board": "burrow",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "cable_cat",
				"text":
				"Mine: two monitors, a cold coffee, a stress ball shaped like a router, and 14 sticky notes."
			},
			{
				"by": "packet_pam",
				"text": "A label maker, a console cable, and half a sandwich from Tuesday."
			},
			{"by": "GrizzleAdmin", "text": "A very old keyboard. Do not touch it."},
		],
		"answer":
		"Two monitors, a headset, a rubber duck and a pile of cables I swear I will sort on Friday.",
	},
	{
		"title": "Best ticket you ever got",
		"board": "burrow",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text": "Mine: the coffee machine would not print. It was a coffee machine. Yours?"
			},
			{
				"by": "wrench_rob",
				"text":
				"A user called because the internet was broken. It was a cup holder: the CD tray."
			},
			{
				"by": "rodent_rick",
				"text": "My top one: the keyboard was on fire. Not figuratively."
			},
		],
		"answer":
		"Mine was a user who said the screen was dark. The monitor was off, and she had been pressing the power button on the speaker.",
	},
	{
		"title": "XP end of support: what are you telling clients?",
		"board": "burrow",
		"skill": "people",
		"level": 1,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"How do you explain that XP will be unsafe after April 8 without scaring people?"
			},
			{
				"by": "old_hand",
				"text":
				"Short and honest: no more security patches, so every new hole stays open. Give a date and a price. People move when it is a plan."
			},
			{
				"by": "gnawer",
				"text":
				"Photos help. Put the old machine next to a new one and quote the price of both."
			},
		],
		"answer":
		"Be honest, keep it short and bring a plan: no more patches after April 8, here is the list, here is the price, here is the date.",
	},
	{
		"title": "Plugin template that survives an upgrade",
		"board": "sandbox",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text":
				"Every upgrade breaks my plugin. Is there a template with the right hooks so it survives?"
			},
			{
				"by": "PS_wizard",
				"text":
				"Keep your code out of the vendor folders and keep the SQL in your own table. Version it. And test the upgrade on a copy."
			},
			{
				"by": "GrizzleAdmin",
				"text": "I have said this for five years. Your own table. Your own folder."
			},
		],
		"answer":
		"Keep the files outside the vendor folders, use your own table, and test every upgrade on a copy first.",
	},
	{
		"title": "Plugin crashed the database after the upgrade",
		"board": "sandbox",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text":
				"Upgraded last night, now CPU is at 100 percent on the DB. A plugin with a loop?"
			},
			{
				"by": "old_hand",
				"text":
				"Disable plugins one by one and watch the CPU. The one that runs every minute is the usual suspect."
			},
			{
				"by": "tcp_tim",
				"text":
				"Mine was a plugin that ran a report on every agent check-in. 5,000 agents. Do the maths."
			},
		],
		"answer":
		"Turn the plugins off one by one and watch the CPU. Anything that runs on every check-in is the usual suspect.",
	},
	{
		"title": "Plugin Sandbox rules and how to submit",
		"board": "sandbox",
		"skill": "people",
		"level": 0,
		"sticky": true,
		"posts":
		[
			{
				"by": "GrizzleAdmin",
				"text":
				"Post the plugin, a screenshot, what it changes and how to remove it. No plugin that phones home. Unknown binaries get deleted, and so do their authors."
			},
			{"by": "PS_wizard", "text": "Include a rollback. Always include a rollback."},
			{"by": "HELPPLZ_Pip", "text": "CAN I SUBMIT A PLUGIN THAT MAKES THE PC GO FASTER???"},
		],
		"answer": "",
	},
	{
		"title": "Custom tab that shows the warranty date",
		"board": "tabs",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Wanted a tab on each computer showing the warranty end. Anyone done this with the serial number?"
			},
			{
				"by": "gnawer",
				"text":
				"Use a query on the BIOS serial and the vendor's page. Cache it in your own table or they will block you."
			},
			{
				"by": "cable_cat",
				"text": "I do that for two vendors. Third one has a captcha. It wins."
			},
		],
		"answer":
		"Read the BIOS serial, look up the warranty on the vendor site, cache the answer in your own table and show it on the tab.",
	},
	{
		"title": "Tab with a ScreenConnect link per agent",
		"board": "tabs",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "tcp_tim",
				"text":
				"A tab with one click remote control for each agent using ScreenConnect. How do I build the URL?"
			},
			{
				"by": "rodent_rick",
				"text":
				"Each session name equals the machine name. Build the link from the name and open it in a new window."
			},
			{
				"by": "old_hand",
				"text": "Beware of machine names with spaces. Fun for the whole family."
			},
		],
		"answer":
		"Name the session after the machine, build the URL from the name, encode spaces, and open it in a new window.",
	},
	{
		"title": "Custom tab: last reboot and uptime",
		"board": "tabs",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "packet_pam",
				"text":
				"Boss wants to know which machines have not been rebooted in months. Is there a tab for uptime?"
			},
			{
				"by": "PS_wizard",
				"text":
				"Read the last boot time from the machine, store the number of days, color the tab red after 30."
			},
			{"by": "xX_n00b_Xx", "text": "just reboot them all lol"},
		],
		"answer":
		"Read the last boot time from each machine, save the days since, and show red after 30 days.",
	},
	{
		"title": "Dashboards: show us your office TV",
		"board": "dash",
		"skill": "people",
		"level": 0,
		"sticky": true,
		"posts":
		[
			{
				"by": "GrizzleAdmin",
				"text":
				"Post a photo of your wall TV. No logos of clients, no passwords on screen. Yes, I can see them."
			},
			{
				"by": "bytes_n_bagels",
				"text":
				"Ours is a big old TV with red and green tiles. Open tickets, missed SLAs, agents offline. The boss looks at it three times a day."
			},
			{"by": "MPriest", "text": "Mine just says: is it backed up? in green."},
		],
		"answer": "",
	},
	{
		"title": "Red and green tiles for open tickets",
		"board": "dash",
		"skill": "people",
		"level": 1,
		"posts":
		[
			{
				"by": "cable_cat",
				"text":
				"How do I build a dashboard with big tiles: open tickets, closed today, missed? Needs to be readable from the door."
			},
			{
				"by": "PS_wizard",
				"text":
				"Three numbers per tile at most. Big fonts. Green under the target, red over it. No pie charts, nobody can read a pie from the door."
			},
			{
				"by": "old_hand",
				"text": "Add a number for the oldest ticket. Everyone looks at that one."
			},
		],
		"answer":
		"Keep it to a few big numbers, green under target and red over it, and add the age of the oldest ticket.",
	},
	{
		"title": "Dashboard for missed SLAs only",
		"board": "dash",
		"skill": "people",
		"level": 1,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text":
				"Boss only wants to see tickets that missed their SLA this week. Per tech. Is that mean?"
			},
			{
				"by": "rodent_rick",
				"text":
				"Show it per client, not per tech. Then it is a service problem, not a blame game."
			},
			{
				"by": "GrizzleAdmin",
				"text": "Per tech dashboards get people to close tickets badly. Ask me how I know."
			},
		],
		"answer":
		"Show misses per client and per cause rather than per person, so the team fixes the process.",
	},
	{
		"title": "Move the database to its own disk",
		"board": "advanced",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text":
				"The RMM database shares a disk with the OS and everything is slow. How do I move it safely?"
			},
			{
				"by": "old_hand",
				"text":
				"Stop the services, back up, detach, move, attach. In that order. Then test it before you tell anyone."
			},
			{"by": "GrizzleAdmin", "text": "Back up TWICE. Then back up."},
		],
		"answer":
		"Stop the services, take a backup, detach the database, move the files, attach it again, and test before you restart the agents.",
	},
	{
		"title": "Agent check-in interval: 5 minutes or 15?",
		"board": "advanced",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "tcp_tim",
				"text": "We have 4,000 agents. Would a 15 minute check-in hurt monitoring?"
			},
			{
				"by": "PS_wizard",
				"text": "Five for servers, fifteen for workstations. Your server will thank you."
			},
			{
				"by": "gnawer",
				"text": "We went to fifteen for everyone and nobody noticed for a year."
			},
		],
		"answer":
		"Use five minutes for servers and fifteen for workstations. It saves load and you will not miss anything.",
	},
	{
		"title": "Stop the nightly cleanup from deleting logs",
		"board": "advanced",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text":
				"The nightly cleanup is deleting the logs I need for audits. Hidden setting somewhere?"
			},
			{
				"by": "old_hand",
				"text":
				"There is a retention value in the config table. Change it, restart the service, write down that you did."
			},
			{"by": "trollbot", "text": "just delete everything and say it was the hackers"},
		],
		"answer":
		"Change the retention value in the config table, restart the service, and note it in the change log.",
	},
	{
		"title": "Cloud server access after the upgrade",
		"board": "cloud",
		"skill": "networking",
		"level": 1,
		"posts":
		[
			{
				"by": "packet_pam",
				"text":
				"After the upgrade nobody can reach the hosted server from the office. VPN is up but nothing comes through."
			},
			{
				"by": "rodent_rick",
				"text":
				"Check the routes. A new subnet on the cloud side that the office router does not know about, probably."
			},
			{"by": "tcp_tim", "text": "And the firewall rule. They often reset after an upgrade."},
		],
		"answer":
		"Look at the routes first, then the firewall rules. An upgrade often resets one of them.",
	},
	{
		"title": "Moving a hosted mailbox without losing the calendar",
		"board": "cloud",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"Migrating 20 mailboxes to hosted Exchange. How do I keep calendars and shared folders?"
			},
			{
				"by": "old_hand",
				"text":
				"Export to PST is the worst way. Use the migration tool, do it in batches, and migrate on a Friday night."
			},
			{"by": "MPriest", "text": "Test with your own mailbox first, mate."},
		],
		"answer":
		"Use the migration tool in small batches on a Friday night, test with your own mailbox first, and check the shared folders.",
	},
	{
		"title": "Is it OK to host the RMM server in the cloud?",
		"board": "cloud",
		"skill": "security",
		"level": 1,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text":
				"Boss wants to move our RMM server to a cloud box to save the hardware. Is that sane?"
			},
			{
				"by": "gnawer",
				"text":
				"Works fine. Lock it down: only the agent port is open, admin through VPN, and test the backups."
			},
			{
				"by": "GrizzleAdmin",
				"text": "It is a computer in somebody else's building. Treat it like one."
			},
		],
		"answer":
		"Fine, as long as only the agent port is open to the internet, admin goes through a VPN, and the backups are tested.",
	},
	{
		"title": "Disable Java auto-update on XP boxes",
		"board": "tips",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Java asks to update at every login on our XP machines and users click the wrong button."
			},
			{
				"by": "rodent_rick",
				"text":
				"Control panel, Java, Update tab, untick. Or push the setting by script and install it silently."
			},
			{"by": "old_hand", "text": "Better: remove Java where nothing needs it. Fewer holes."},
		],
		"answer":
		"Turn off the update prompt in the Java control panel, push the setting by script, and remove Java where it is not needed.",
	},
	{
		"title": "Set the power plan on every laptop",
		"board": "tips",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "cable_cat",
				"text": "Laptops go to sleep during the nightly backup. How do I stop it?"
			},
			{
				"by": "PS_wizard",
				"text":
				"Set the plan to never sleep on AC power by policy. Keep battery settings as they are."
			},
			{
				"by": "packet_pam",
				"text": "Also wake the machines for the backup if the hardware allows."
			},
		],
		"answer":
		"Push a power plan by policy that never sleeps on AC power, and leave the battery settings alone.",
	},
	{
		"title": "Nightly robocopy with an email report",
		"board": "tools",
		"skill": "servers",
		"level": 1,
		"ps": 1,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text":
				"I want a nightly copy to a second box and an email if it fails. Without buying anything."
			},
			{
				"by": "PS_wizard",
				"text":
				"Robocopy with a log, a scheduled task, and a little script that mails the last lines of the log if the exit code is 8 or more."
			},
			{"by": "GrizzleAdmin", "text": "Exit codes below 8 are fine. Read the manual."},
		],
		"answer":
		"Use robocopy with a log file in a scheduled task and mail the log if the exit code is 8 or more.",
	},
	{
		"title": "Ninite for all new installs",
		"board": "tools",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text": "Rolling out 30 new PCs. Anyone using Ninite to install the basics?"
			},
			{
				"by": "gnawer",
				"text":
				"Yes. Make an installer with the apps you need, run it silently, done in ten minutes. Works great with the RMM."
			},
			{
				"by": "tcp_tim",
				"text":
				"There is a paid version that updates too. Worth it for 100 machines or more."
			},
		],
		"answer":
		"Build a Ninite installer with your standard apps and run it silently from the RMM on every new PC.",
	},
	{
		"title": "Command line: find who has a file open",
		"board": "tools",
		"skill": "servers",
		"level": 1,
		"ps": 1,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text":
				"A user says a file is locked. Which command shows who has it open on the server?"
			},
			{
				"by": "old_hand",
				"text":
				"net file shows the open files on a share. Close it with the /close switch. Or open the shared folders view."
			},
			{"by": "trollbot", "text": "turn the server off and on again"},
		],
		"answer":
		"Run net file on the server to see who has it open, then close it with net file and the ID and ask the user to save first.",
	},
	{
		"title": "Free tool to read SMART data",
		"board": "tools",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "packet_pam",
				"text":
				"Drive is making a noise. Anything free that shows the SMART status in a readable way?"
			},
			{
				"by": "rodent_rick",
				"text":
				"There are a few free ones. Check reallocated and pending sectors. Any pending sectors and you replace the drive."
			},
			{"by": "MPriest", "text": "Replace it before it replaces you."},
		],
		"answer":
		"Use a free SMART viewer, check the reallocated and pending sector counts, and replace the drive if they are not zero.",
	},
	{
		"title": "Dataview: machines with no antivirus",
		"board": "dataview",
		"skill": "security",
		"level": 1,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Anyone have a dataview that lists every machine with no antivirus reporting?"
			},
			{
				"by": "gnawer",
				"text":
				"Filter on missing product and last seen within 7 days, so retired machines do not show. Sort by client."
			},
			{
				"by": "PS_wizard",
				"text": "Exclude servers you handle differently. Add them back as a second view."
			},
		],
		"answer":
		"Filter on a missing antivirus product and last seen in the last seven days, so retired machines do not fill the list.",
	},
	{
		"title": "Dataview: laptops older than 4 years",
		"board": "dataview",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "cable_cat",
				"text": "Looking for a list of old laptops to build a refresh budget for a client."
			},
			{
				"by": "tcp_tim",
				"text": "Group by BIOS date. Anything before 2010 goes on the replace list."
			},
			{
				"by": "old_hand",
				"text": "Put the list in front of the owner in January. Not in June."
			},
		],
		"answer":
		"Group by BIOS date and put everything older than four years on the refresh list with a price per machine.",
	},
	{
		"title": "Dataview: servers with less than 10 percent free",
		"board": "dataview",
		"skill": "servers",
		"level": 0,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text": "A simple view for low disk space on servers. I want it on my homepage."
			},
			{
				"by": "rodent_rick",
				"text":
				"Filter servers only, the free percentage under 10 on any drive, sort by lowest. Works for me."
			},
			{
				"by": "dbl_click_dave",
				"text": "Add a second one for under 20 for the warning level."
			},
		],
		"answer":
		"Filter on servers, free space under ten percent on any drive, sorted lowest first, with a second view at twenty percent as a warning.",
	},
	{
		"title": "RAID monitoring on older servers (SNMP OID?)",
		"board": "hardware",
		"skill": "networking",
		"level": 1,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text":
				"Need the SNMP OID for RAID status on a pre-2010 server with the old controller. Vendor site has nothing."
			},
			{
				"by": "PS_wizard",
				"text":
				"Install the vendor agent so it exposes SNMP, then walk the tree and look for the logical disk status. Anything not 'ok' is an alert."
			},
			{
				"by": "old_hand",
				"text":
				"Walk it twice, once with a disk pulled. Then you know which number changes."
			},
		],
		"answer":
		"Install the controller's management agent so it exposes SNMP, then walk the tree and alert on any logical disk that is not ok.",
	},
	{
		"title": "UPS battery status over SNMP",
		"board": "hardware",
		"skill": "networking",
		"level": 1,
		"posts":
		[
			{
				"by": "tcp_tim",
				"text":
				"Can I see the battery health of the small office UPS in the RMM? It beeps and nobody knows why."
			},
			{
				"by": "packet_pam",
				"text":
				"Put a network card in the UPS, give it an address and poll the battery status and runtime. Alert under 5 minutes."
			},
			{
				"by": "bytes_n_bagels",
				"text": "And replace the battery every three years. It is a consumable."
			},
		],
		"answer":
		"Add a network card to the UPS, poll the battery status and runtime over SNMP, and alert when the runtime drops under five minutes.",
	},
	{
		"title": "Switch port alerts: too noisy",
		"board": "hardware",
		"skill": "networking",
		"level": 2,
		"posts":
		[
			{
				"by": "cable_cat",
				"text":
				"Every time someone turns off a PC I get a port down alert. 200 a day. Help."
			},
			{
				"by": "rodent_rick",
				"text": "Alert only on uplink ports and server ports. Leave the user ports out."
			},
			{
				"by": "gnawer",
				"text": "Or alert when the port is down for more than an hour during working hours."
			},
		],
		"answer":
		"Only alert on uplink and server ports, and add a delay on the rest so a PC turned off for lunch does not page you.",
	},
	{
		"title": "Temperature sensor in the server closet",
		"board": "hardware",
		"skill": "networking",
		"level": 0,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"Closet has no AC. I want a temperature alert before the server cooks itself."
			},
			{
				"by": "old_hand",
				"text":
				"A cheap network sensor and an alert at 30 Celsius. And a fan. And tell the landlord."
			},
			{"by": "MPriest", "text": "Hot servers are the devil's work, mate."},
		],
		"answer":
		"Install a cheap network temperature sensor, alert at 30 degrees, add a fan and put the cost in the quote.",
	},
	{
		"title": "Feature request: bulk-close old tickets",
		"board": "requests",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text":
				"Please add a way to close 500 stale tickets at once without opening each one."
			},
			{
				"by": "rodent_rick",
				"text": "+1. Meanwhile use a report to export the IDs and close them with a script."
			},
			{
				"by": "GrizzleAdmin",
				"text": "Open tickets are not an archive. Close them when they are done."
			},
		],
		"answer": "Voted for it. For now I export the IDs and close the old ones in batches.",
	},
	{
		"title": "Please add a dark mode",
		"board": "requests",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "cable_cat",
				"text": "My eyes hurt at 2 a.m. Dark mode please. Even gray would help."
			},
			{"by": "tcp_tim", "text": "+1. Night shift here, same."},
			{"by": "trollbot", "text": "just turn the monitor off"},
		],
		"answer": "Voted for it. Night shift here too and the white screen hurts.",
	},
	{
		"title": "iFone 5 screen for the ticket app: please",
		"board": "requests",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Could the ticket page work on a phone? I am out of the office half the day and squinting at the full page."
			},
			{
				"by": "PS_wizard",
				"text":
				"A small screen with the ticket list and one button to take it. That is enough."
			},
			{"by": "old_hand", "text": "Vote and be patient. They read this forum."},
		],
		"answer":
		"Voted for it. A phone view with the list and a take button would save me a trip back to the office.",
	},
	{
		"title": "Vote: patch status on the home screen",
		"board": "requests",
		"skill": "people",
		"level": 1,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text": "Show the percent patched per client on the home screen. Boss keeps asking."
			},
			{
				"by": "gnawer",
				"text": "Voted. Meanwhile I made a dataview that counts missing patches per client."
			},
			{
				"by": "GrizzleAdmin",
				"text": "I will pass it on. They said that in 2011. I am still here."
			},
		],
		"answer": "Voted for it. Until then I run a dataview and a report each Monday.",
	},
	{
		"title": "Moving off the old remote tool",
		"board": "remote",
		"skill": "networking",
		"level": 1,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"Our old remote tool is being phased out. We need one that works through firewalls and works for both Mac and PC."
			},
			{
				"by": "rodent_rick",
				"text":
				"ScreenConnect is what we moved to. Self hosted, one port in, works behind most firewalls."
			},
			{
				"by": "gnawer",
				"text": "Pilot it on one client for two weeks before you roll it out to everybody."
			},
		],
		"answer":
		"Pick a tool that connects out through the firewall, pilot it on one client for two weeks, then move the rest.",
	},
	{
		"title": "VNC through the firewall: what port?",
		"board": "remote",
		"skill": "networking",
		"level": 1,
		"posts":
		[
			{
				"by": "tcp_tim",
				"text":
				"Client has VNC on 5900 and wants me to open the port on the firewall. Fine?"
			},
			{
				"by": "GrizzleAdmin",
				"text":
				"NO. Never open 5900 to the world. VPN, or a tunnel, or I will ban you myself."
			},
			{"by": "PS_wizard", "text": "Tunnel it over SSH or the remote tool. Do not expose it."},
		],
		"answer":
		"Do not open 5900. Use a VPN or a tunnel and keep VNC listening on the inside only.",
	},
	{
		"title": "Tunnel the remote tool through a proxy",
		"board": "remote",
		"skill": "networking",
		"level": 2,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text":
				"One client forces all traffic through a proxy. The agent cannot connect out."
			},
			{
				"by": "old_hand",
				"text":
				"Set the proxy in the agent config or by script. And ask whether the proxy lets the port through at all."
			},
			{
				"by": "packet_pam",
				"text":
				"Ours needed a whitelist for the server name. Send the IT person the address."
			},
		],
		"answer":
		"Set the proxy in the agent config, ask the client to whitelist the server name, and test from a lab machine first.",
	},
	{
		"title": "Count patching percentage per client",
		"board": "reporting",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text":
				"Need the percent of machines fully patched per client for the monthly report."
			},
			{
				"by": "PS_wizard",
				"text":
				"Count machines with zero missing patches and divide by active machines. Leave out retired ones."
			},
			{
				"by": "rodent_rick",
				"text": "Run it on the 15th, not on Patch Tuesday. Otherwise everyone is at zero."
			},
		],
		"answer":
		"Count machines with no missing patches, divide by the active machines, and run it mid month rather than on Patch Tuesday.",
	},
	{
		"title": "Bad performance percent in the health report",
		"board": "reporting",
		"skill": "servers",
		"level": 1,
		"posts":
		[
			{
				"by": "cable_cat",
				"text":
				"The health report gives one client 12 percent bad performance and I cannot find the cause."
			},
			{
				"by": "old_hand",
				"text":
				"It counts machines over 90 percent CPU for an hour. One broken backup job can do it for all of them."
			},
			{
				"by": "gnawer",
				"text":
				"Check what ran at that hour. Ours was an antivirus scan on all machines at 2 p.m."
			},
		],
		"answer":
		"Find what ran at the busy hour. A scheduled scan or a stuck backup on every machine is the usual cause.",
	},
	{
		"title": "Monthly report the owner will actually read",
		"board": "reporting",
		"skill": "people",
		"level": 1,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text": "I send a 12 page report each month. The owner has never opened it."
			},
			{
				"by": "MPriest",
				"text":
				"One page. Three numbers. One sentence about what you did for them. Then a coffee."
			},
			{
				"by": "GrizzleAdmin",
				"text": "I once mailed a blank page for three months. Nobody noticed."
			},
		],
		"answer":
		"Use one page with three numbers and one sentence about what you did for them, and bring it to the meeting.",
	},
	{
		"title": "SQL: tickets closed per tech per week",
		"board": "reporting",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text": "Need a query for tickets closed per tech per week for the last 12 weeks."
			},
			{
				"by": "PS_wizard",
				"text":
				"Group by tech and the week of the close date. Read only, on a copy of the database. Do not run it on the live one at 9 a.m."
			},
			{
				"by": "dbl_click_dave",
				"text": "Use a left join to the techs table or the techs with zero show nothing."
			},
		],
		"answer":
		"Group by tech and the week of the close date, join the techs table so zeroes show, and run it on a copy of the database.",
	},
	{
		"title": "How to post a script (read this first)",
		"board": "scripts",
		"skill": "people",
		"level": 0,
		"sticky": true,
		"posts":
		[
			{
				"by": "GrizzleAdmin",
				"text":
				"Title says what it does. Say what it was tested on. Put the script in code tags. Say how to undo it. Scripts with no undo get deleted. Not affiliated with the software vendor. Test on a lab system."
			},
			{
				"by": "PS_wizard",
				"text": "And comment your code. In a year you will be the stranger who needs help."
			},
			{"by": "HELPPLZ_Pip", "text": "I POSTED MY SCRIPT AND IT HAS NO REPLIES WHY"},
		],
		"answer": "",
	},
	{
		"title": "Detect files with double extensions (invoice.pdf.exe)",
		"board": "scripts",
		"skill": "security",
		"level": 1,
		"ps": 1,
		"posts":
		[
			{
				"by": "bytes_n_bagels",
				"text":
				"Looking for a script that finds files like invoice.pdf.exe on the file shares."
			},
			{
				"by": "PS_wizard",
				"text":
				"Match names with a document extension followed by an executable one. Include .scr and .com. Log the paths, do not delete them."
			},
			{
				"by": "GrizzleAdmin",
				"text":
				"Also check if the user's explorer hides known extensions. It does. That is why it works."
			},
		],
		"answer":
		"Search the shares for a document extension followed by exe, scr or com, log the paths, and turn on showing file extensions by policy.",
	},
	{
		"title": "Restart a stuck service remotely",
		"board": "scripts",
		"skill": "servers",
		"level": 1,
		"ps": 2,
		"posts":
		[
			{
				"by": "tcp_tim",
				"text":
				"A service hangs on stopping every few days. Need a script that kills it and starts it again."
			},
			{
				"by": "old_hand",
				"text":
				"Get the process ID of the service, stop the process if the stop times out, then start the service. Log it so you can prove it happened."
			},
			{"by": "trollbot", "text": "just reboot the whole server"},
		],
		"answer":
		"Stop the service with a timeout, kill the process if it hangs, start it again and write a line to the log.",
	},
	{
		"title": "Find users with passwords that never expire",
		"board": "scripts",
		"skill": "security",
		"level": 2,
		"ps": 2,
		"posts":
		[
			{
				"by": "wrench_rob",
				"text":
				"Audit time. I need a list of accounts with the password never expires flag."
			},
			{
				"by": "PS_wizard",
				"text":
				"Query the directory for the flag, sort by last password change, export a CSV. Exclude service accounts you have documented."
			},
			{"by": "GrizzleAdmin", "text": "The CSV goes to the owner. The owner says 'oh'."},
		],
		"answer":
		"Query the directory for the never expires flag, sort by last password change, export it to a CSV and review the service accounts.",
	},
	{
		"title": "Script: list installed software to a CSV",
		"board": "scripts",
		"skill": "servers",
		"level": 1,
		"ps": 1,
		"posts":
		[
			{
				"by": "sysadmin_sue",
				"text":
				"Want an inventory of installed software for all machines at a client, in one CSV."
			},
			{
				"by": "rodent_rick",
				"text":
				"Read the uninstall keys in the registry, both the 32 bit and 64 bit locations. Add the machine name and run it from the RMM."
			},
			{
				"by": "gnawer",
				"text":
				"Do not use the slow WMI product class. It also triggers a repair on every MSI package."
			},
		],
		"answer":
		"Read the uninstall keys for both the 32 and 64 bit software, add the machine name, and export one CSV per client.",
	},
	{
		"title": "Welcome to the Vendor Lounge (approved vendors only)",
		"board": "vendor",
		"skill": "people",
		"level": 0,
		"sticky": true,
		"posts":
		[
			{
				"by": "GrizzleAdmin",
				"text":
				"Only approved vendors may post here. One post a week. No spam, no cold calls, no 'free' scanners that install a toolbar. Break this and I find your sales manager."
			},
			{"by": "MPriest", "text": "Be kind to the vendors. They have a hard job too."},
			{"by": "HELPPLZ_Pip", "text": "CAN I SELL MY BROTHER'S USED LAPTOPS HERE"},
		],
		"answer": "",
	},
	{
		"title": "ShadowPoint Backup: forty percent off image backup",
		"board": "vendor",
		"skill": "security",
		"level": 0,
		"posts":
		[
			{
				"by": "ShadowPoint_Brad",
				"text":
				"Image based backup with instant virtualization. Boot a dead server as a virtual machine in minutes. Forty percent off for forum members this month!"
			},
			{
				"by": "rodent_rick",
				"text": "Tested it. The restore really is fast. The price per server is not small."
			},
			{"by": "GrizzleAdmin", "text": "Vendors: one post. Brad: you used your one."},
		],
		"answer": "",
	},
	{
		"title": "WebWoot Security: free scan for your clients",
		"board": "vendor",
		"skill": "security",
		"level": 0,
		"posts":
		[
			{
				"by": "WebWoot_Dee",
				"text":
				"We scan your clients' websites for known holes, free for one month. See the weak spots before the bad guys do."
			},
			{
				"by": "gnawer",
				"text": "Free is fine. Ask what happens to the list of holes afterwards."
			},
			{"by": "old_hand", "text": "Get it in writing that the data stays yours."},
		],
		"answer": "",
	},
	{
		"title": "SoftSwipe PSA: tired of your ticket system?",
		"board": "vendor",
		"skill": "people",
		"level": 0,
		"posts":
		[
			{
				"by": "SoftSwipe_Rex",
				"text":
				"Our PSA does tickets, time, billing and quotes in one screen. Migrate in a weekend! Ask me about the console game raffle."
			},
			{"by": "tcp_tim", "text": "Does it migrate the ticket history or just the clients?"},
			{
				"by": "SoftSwipe_Rex",
				"text": "Great question. Let me get back to you after the weekend."
			},
		],
		"answer": "",
	},
	{
		"title": "Rodent Nation 2014: thank you for stopping by",
		"board": "vendor",
		"skill": "people",
		"level": 0,
		"needs": "went",
		"posts":
		[
			{
				"by": "WebWoot_Dee",
				"text":
				"It was great to meet so many of you at the show! Slides from our session are in the usual place. The Rock Star Upgrade winner will be emailed this week."
			},
			{"by": "MPriest", "text": "Lovely booth. The pens were excellent."},
			{"by": "ShadowPoint_Brad", "text": "Thank you all. The rat mascot says hello."},
		],
		"answer": "",
	},
	{
		"title": "Re: Rodent Nation 2014 follow-up: your free trial",
		"board": "vendor",
		"skill": "people",
		"level": 0,
		"needs": "scan",
		"posts":
		[
			{
				"by": "SoftSwipe_Rex",
				"text":
				"Hi everyone who scanned a badge at our booth: your free trial is ready! If you did not get my email, check your spam folder. And your other spam folder."
			},
			{
				"by": "old_hand",
				"text": "Three mails from one vendor in two days. That is a record."
			},
			{"by": "xX_n00b_Xx", "text": "i got 5 emails is that good"},
		],
		"answer": "",
	},
	{
		"title": "Plugin API: where are the docs?",
		"board": "plugdev",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "LAN_lord",
				"text": "I want to write a plugin. Is there any documentation on the API?"
			},
			{
				"by": "PS_wizard",
				"text":
				"There is a wiki that is 70 percent accurate. The rest is in the forum posts of 2011."
			},
			{
				"by": "GrizzleAdmin",
				"text": "The docs are the forum. Use the search. Buy me a coffee."
			},
		],
		"answer":
		"Start with the wiki, read the old forum posts, and keep a notes file on everything that turns out to be wrong.",
	},
	{
		"title": "Writing a plugin that reads SNMP",
		"board": "plugdev",
		"skill": "networking",
		"level": 2,
		"posts":
		[
			{
				"by": "packet_pam",
				"text":
				"Want a plugin that reads SNMP from switches and shows port speeds in a tab."
			},
			{
				"by": "rodent_rick",
				"text":
				"Use a library, do not write the protocol yourself. Poll slowly. Cache the results."
			},
			{
				"by": "tcp_tim",
				"text": "And walk the tree on a lab switch first. Real switches have opinions."
			},
		],
		"answer":
		"Use an SNMP library, poll slowly, cache the results in your own table and test on a lab switch before production.",
	},
	{
		"title": "Unit testing a plugin without a lab",
		"board": "plugdev",
		"skill": "servers",
		"level": 2,
		"posts":
		[
			{
				"by": "dbl_click_dave",
				"text": "I have no lab. How do I test a plugin without breaking production?"
			},
			{
				"by": "old_hand",
				"text":
				"Build a lab. A cheap box and a free hypervisor. A copy of the database. Half a day well spent."
			},
			{"by": "GrizzleAdmin", "text": "The lab is not optional. The lab is the thing."},
		],
		"answer":
		"Build a small lab with a spare box and a free hypervisor and restore a copy of the database before testing.",
	},
]
var THREADS: Array = DEFAULT_THREADS.duplicate(true)
const COOLDOWN := 45.0
const RANKS := [[40, "GURU"], [20, "REGULAR"], [8, "MEMBER"], [0, "LURKER"]]
const PAGE := 25

var karma := 10
var threads: Array = []  # today's questions: {id, read, answered}
var channel: Array = []  # [nick, text]
var hint := {}  # {question, best, votes, total, pending}
var mine := {}  # thread id -> the day you answered it (your post shows in the thread)
var first_day := -1  # the day of your first post (the newest member can be you that day)
var corrections := {}  # thread id -> {by, text} for today's wrong attempts

var _last_ask := -999.0
var _lines: Array = []  # queued [delay, nick, text]
var _day := -1


func _ready() -> void:
	reset()


func reset() -> void:
	karma = 10
	threads = []
	channel = [["#labratnerds", "welcome. be nice, read the FAQ."]]
	hint = {}
	mine = {}
	first_day = -1
	corrections = {}
	_last_ask = -999.0
	_lines = []
	_day = -1


func rank() -> String:
	for entry in RANKS:
		if karma >= int(entry[0]):
			return str(entry[1])
	return "LURKER"


# the nicks are likelier to be right the more you contribute
func accuracy_mult() -> float:
	return 0.8 + float(clampi(karma, 0, 40)) / 40.0 * 0.3


# ---- seeded randomness: the same campaign day and run seed always give the same board ----
func _rng(salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(hash("%s|%d|%d" % [salt, Campaign.day, Difficulty.run_seed]))
	return r


func _h(salt: String) -> int:
	return absi(hash(salt))


# ---- the threads ----
func is_sticky(i: int) -> bool:
	return bool(THREADS[i].get("sticky", false))


# a vendor thread only shows after Rodent Nation ("went") or after you gave a vendor your badge ("scan")
func thread_visible(i: int) -> bool:
	match str(THREADS[i].get("needs", "")):
		"went":
			return Expo.went
		"scan":
			return Expo.spam > 0
	return true


func board_of(i: int) -> String:
	return str(THREADS[i].board)


# can today's questions come from this thread (a real, open question)?
func is_question(i: int) -> bool:
	return (
		not is_sticky(i)
		and thread_visible(i)
		and str(THREADS[i].get("needs", "")) == ""
		and board_of(i) != "vendor"
	)


# thread ids on a board: stickies first, then the newest
func board_threads(board_id: String) -> Array:
	var ids := []
	for i in THREADS.size():
		if board_of(i) == board_id and thread_visible(i):
			ids.append(i)
	ids.sort_custom(
		func(a: int, b: int) -> bool:
			if is_sticky(a) != is_sticky(b):
				return is_sticky(a)
			return age_days(a) < age_days(b)
	)
	return ids


# days ago the first post was written
func age_days(i: int) -> int:
	if is_sticky(i):
		return 120 + _h("age%d" % i) % 90
	return 3 + _h("age%d" % i) % 70


# the posts of a thread with their times: [{by, text, day, minute, mine}] (your answer and any correction come last)
func thread_posts(i: int) -> Array:
	var out := []
	var day := Campaign.day - age_days(i)
	var minute := 480 + _h("m%d" % i) % 500
	var src: Array = THREADS[i].posts
	for k in src.size():
		if k > 0:
			var gap := _h("g%d_%d" % [i, k]) % 3
			if gap == 0:
				minute = mini(1400, minute + 25 + _h("n%d_%d" % [i, k]) % 90)
			else:
				day += gap
				minute = 480 + _h("n%d_%d" % [i, k]) % 600
			day = mini(day, Campaign.day - 1)
		out.append(
			{
				"by": str(src[k].by),
				"text": str(src[k].text),
				"day": day,
				"minute": minute,
				"mine": false
			}
		)
	if corrections.has(i):
		out.append(
			{
				"by": str(corrections[i].by),
				"text": str(corrections[i].text),
				"day": Campaign.day,
				"minute": now_minute(),
				"mine": false
			}
		)
	if mine.has(i):
		out.append(
			{
				"by": PLAYER_NICK,
				"text": str(THREADS[i].get("answer", "")),
				"day": int(mine[i]),
				"minute": 12 * 60,
				"mine": true
			}
		)
		if mine[i] == Campaign.day:
			out[out.size() - 1].minute = now_minute()
	return out


func reply_count(i: int) -> int:
	return thread_posts(i).size() - 1


# the last post of a thread: {by, day, minute}
func last_of(i: int) -> Dictionary:
	var posts := thread_posts(i)
	return posts[posts.size() - 1]


func poster_rank(nick: String) -> String:
	if nick == PLAYER_NICK:
		return rank()
	return str(POSTERS.get(nick, "MEMBER"))


func poster_color(nick: String) -> Color:
	if nick == PLAYER_NICK:
		return Color("0a6ab8")
	if NICKS.has(nick):
		return NICKS[nick].color
	return Color(POSTER_COLORS[_h(nick) % POSTER_COLORS.size()])


# the signature line under your posts: earned with karma
func signature() -> String:
	if karma >= 40:
		return str(TEXT.sig_guru)
	if karma >= 20:
		return str(TEXT.sig_regular)
	return ""


# ---- the date and the clock (April 2014: day 4 is April 8, the end of support for XP) ----
func now_minute() -> int:
	return int(World.clock * 60.0)


# campaign days are working days: day 1 is Thursday April 3, 2014, so day 4 is Tuesday April 8 (the end of support for XP) and weekends are skipped
func _unix_of(day: int) -> int:
	var work := day - 1
	var weeks := floori(work / 5.0)
	var calendar := weeks * 7 + int([0, 1, 4, 5, 6][work - weeks * 5])
	var start := int(
		Time.get_unix_time_from_datetime_dict(
			{"year": 2014, "month": 4, "day": 3, "hour": 12, "minute": 0, "second": 0}
		)
	)
	return start + calendar * 86400


# "TUE APR 8, 2014" for a campaign day number
func date_text(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(_unix_of(day))
	var weekdays := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
	var months := [
		"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
	]
	return (
		"%s %s %d, %d"
		% [weekdays[int(d.weekday)], months[int(d.month) - 1], int(d.day), int(d.year)]
	)


# "9:14 AM" for a minute of the day
func time_text(minute: int) -> String:
	var m := clampi(minute, 0, 1439)
	var h := floori(m / 60.0)
	return "%d:%02d %s" % [(h + 11) % 12 + 1, m % 60, "AM" if h < 12 else "PM"]


# "APR 5 4:12 PM" (short) or "TODAY 9:14 AM" / "YESTERDAY 4:12 PM"
func when_text(day: int, minute: int, long := false) -> String:
	if day == Campaign.day:
		return "TODAY " + time_text(minute)
	if day == Campaign.day - 1:
		return "YESTERDAY " + time_text(minute)
	var full := date_text(day)
	return (full if long else full.substr(4, full.length() - 10)) + " " + time_text(minute)


# "TODAY", "YESTERDAY" or "APR 5": the day without the time (for the narrow screens)
func day_text(day: int) -> String:
	if day == Campaign.day:
		return "TODAY"
	if day == Campaign.day - 1:
		return "YESTERDAY"
	var full := date_text(day)
	return full.substr(4, full.length() - 10)


func clock_line() -> String:
	return "IT IS CURRENTLY %s %s" % [date_text(Campaign.day), time_text(now_minute())]


func last_visit_line() -> String:
	return "YOUR LAST VISIT WAS %s" % date_text(maxi(1, Campaign.day - 1))


# ---- the boards ----
func board(id: String) -> Dictionary:
	for b in BOARDS:
		if str(b.id) == id:
			return b
	return {}


func board_locked(id: String) -> bool:
	return bool(board(id).get("locked", false))


# only the vendors post in the Vendor Lounge (and nobody in the locked VIP area)
func board_open_to_you(id: String) -> bool:
	return not bool(board(id).get("vendors_only", false)) and not board_locked(id)


func my_posts_in(board_id: String) -> int:
	var n := 0
	for i in mine:
		if board_of(int(i)) == board_id:
			n += 1
	return n


# [topics, posts] for a board: the base size, a little growth every day, your own posts
func board_counts(id: String) -> Array:
	var b := board(id)
	if b.is_empty() or board_locked(id):
		return [0, 0]
	var day := maxi(0, Campaign.day)
	return [int(b.topics) + day * int(b.gt), int(b.posts) + day * int(b.gp) + my_posts_in(id)]


# the board's last post {title, by, day, minute, thread}: a thread picked with the day's seed, or your own post
func last_post(id: String) -> Dictionary:
	var ids := board_threads(id)
	if ids.is_empty():
		return {}
	var mine_here := -1
	var mine_day := -1
	for i in ids:
		if mine.has(i) and int(mine[i]) >= mine_day:
			mine_here = int(i)
			mine_day = int(mine[i])
	if mine_here >= 0 and mine_day == Campaign.day:
		return {
			"title": str(THREADS[mine_here].title),
			"by": PLAYER_NICK,
			"day": mine_day,
			"minute": now_minute(),
			"thread": mine_here
		}
	var r := _rng("last" + id)
	var pick: int = ids[r.randi() % ids.size()]
	var posts := thread_posts(pick)
	var by := str(posts[r.randi() % posts.size()].by)
	var ago := r.randi_range(4, 60 * 20)  # minutes ago, so it moves with the game clock
	var minute := now_minute() - ago
	var day := Campaign.day
	if minute < 0:
		minute += 1440
		day -= 1
	return {
		"title": str(THREADS[pick].title), "by": by, "day": day, "minute": minute, "thread": pick
	}


func last_post_line(id: String) -> String:
	var lp := last_post(id)
	if lp.is_empty():
		return "NO POSTS"
	return (
		"LAST POST: RE: %s BY %s, %s"
		% [str(lp.title), str(lp.by), when_text(int(lp.day), int(lp.minute))]
	)


# the footer statistics: {posts, topics, members, newest}
func stats() -> Dictionary:
	var posts := 0
	var topics := 0
	for b in BOARDS:
		var n := board_counts(str(b.id))
		topics += int(n[0])
		posts += int(n[1])
	var newest := str(NEW_MEMBERS[_rng("new").randi() % NEW_MEMBERS.size()])
	if first_day >= 0 and (Campaign.day == first_day or _rng("you").randf() < 0.2):
		newest = PLAYER_NICK
	return {
		"posts": posts,
		"topics": topics,
		"members": 5296 + Campaign.day * 3 + (1 if first_day >= 0 else 0),
		"newest": newest
	}


# "8,408": thousands with a comma
func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---- today's questions ----
func ensure_threads() -> void:
	if Campaign.day == _day and not threads.is_empty():
		return
	_day = Campaign.day
	corrections = {}
	var r := _rng("daily")
	var easy := []
	var rest := []
	for i in THREADS.size():
		if not is_question(i):
			continue
		if int(THREADS[i].level) == 0 and int(THREADS[i].get("ps", 0)) == 0:
			easy.append(i)
		else:
			rest.append(i)
	_shuffle(easy, r)
	_shuffle(rest, r)
	var ids := []
	for i in 2:  # two you can always answer, three from the rest
		if not easy.is_empty():
			ids.append(easy.pop_front())
	var more := rest + easy
	_shuffle(more, r)
	while ids.size() < 5 and not more.is_empty():
		ids.append(more.pop_front())
	threads = []
	for id in ids:
		threads.append({"id": int(id), "read": false, "answered": false})
	changed.emit()


func _shuffle(list: Array, r: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp


# the index in today's list of a thread id, or -1 when it is not one of today's questions
func today_index(id: int) -> int:
	ensure_threads()
	for k in threads.size():
		if int(threads[k].id) == id:
			return k
	return -1


# opening a thread in the forum: today's questions count as read (a little XP)
func open_thread(id: int) -> void:
	var k := today_index(id)
	if k >= 0:
		read_thread(k)


func read_thread(index: int) -> void:
	ensure_threads()
	var th: Dictionary = threads[index]
	if th.read:
		return
	th.read = true
	Skills.add_xp(str(THREADS[int(th.id)].skill), 2)
	changed.emit()


# what a thread asks of you: "" when you can answer it, else the missing skill as text
func need_text(id: int) -> String:
	var def: Dictionary = THREADS[id]
	var lines := []
	if Skills.level(str(def.skill)) < int(def.level):
		lines.append(
			"%s %d" % [str(Skills.NAMES.get(str(def.skill), str(def.skill))), int(def.level)]
		)
	if Skills.level("powershell") < int(def.get("ps", 0)):
		lines.append(str(TEXT.need_ps) % int(def.ps))
	return ", ".join(lines)


func answer_thread(index: int) -> String:
	ensure_threads()
	var th: Dictionary = threads[index]
	if th.answered:
		return "ALREADY ANSWERED"
	var def: Dictionary = THREADS[int(th.id)]
	if (
		Skills.level(str(def.skill)) < int(def.level)
		or Skills.level("powershell") < int(def.get("ps", 0))
	):
		var cozy := Difficulty.cozy_on()
		if not cozy:
			karma = maxi(0, karma - 1)
		var r := _rng("corr%d" % int(th.id))
		var who: Array = [
			"rodent_rick", "old_hand", "gnawer", "PS_wizard", "MPriest", "GrizzleAdmin"
		]
		corrections[int(th.id)] = {
			"by": who[r.randi() % who.size()], "text": CORRECTIONS[r.randi() % CORRECTIONS.size()]
		}
		changed.emit()
		return "YOU ARE NOT SURE ENOUGH TO ANSWER" + (" " + str(TEXT.no_karma_lost) if cozy else "")
	th.answered = true
	th.read = true
	corrections.erase(int(th.id))
	mine[int(th.id)] = Campaign.day
	if first_day < 0:
		first_day = Campaign.day
	var gain := 2
	if int(def.get("ps", 0)) > 0 and Skills.can_script():
		gain += 1  # a script that works is respected
	karma += gain
	Skills.add_xp(str(def.skill), 4)
	changed.emit()
	return str(TEXT.posted) % gain


func cooldown_left() -> float:
	return maxf(0.0, COOLDOWN - (Time.get_ticks_msec() / 1000.0 - _last_ask))


func can_ask() -> bool:
	return cooldown_left() <= 0.0 and _lines.is_empty()


# ask the channel which option is best; returns the verdict (it fills in over a few seconds)
func ask(question: String, options: Array, best: int) -> Dictionary:
	if not can_ask() or options.is_empty():
		return {}
	_last_ask = Time.get_ticks_msec() / 1000.0
	channel.append(["you", question])
	if karma < 4:
		channel.append(["#labratnerds", "nobody answers a lurker who never posts. try the forum."])
		hint = {}
		changed.emit()
		return {"ignored": true}
	karma = maxi(0, karma - 1)
	var nicks: Array = NICKS.keys()
	nicks.shuffle()
	var votes := {}
	var total := 4
	for i in total:
		var nick: String = nicks[i]
		var right := randf() < minf(0.97, float(NICKS[nick].acc) * accuracy_mult())
		var pick := best
		if not right and options.size() > 1:
			pick = (best + 1 + randi() % (options.size() - 1)) % options.size()
		votes[pick] = int(votes.get(pick, 0)) + 1
		var text := "I would go with: " + str(options[pick]).to_lower()
		if nick == "trollbot" and randf() < 0.5:
			text = str(JOKES[randi() % JOKES.size()])
		elif nick == "MPriest":
			text += " " + str(BLESSINGS[randi() % BLESSINGS.size()])
		elif nick == "GrizzleAdmin":
			text += " " + str(GRUMBLES[randi() % GRUMBLES.size()])
		elif nick == "HELPPLZ_Pip":
			text = text.to_upper() + "!!! PLEASE HELP ME TOO"
		_lines.append([1.2 + float(i) * 1.6, nick, text])
	var winner := best
	var most := -1
	for key in votes:
		if int(votes[key]) > most:
			most = int(votes[key])
			winner = int(key)
	hint = {
		"question": question,
		"best": str(options[winner]),
		"votes": most,
		"total": total,
		"pending": true,
		"winner": winner
	}
	changed.emit()
	return hint


# which fix does this ticket need? the channel's answer to "what should I run?"
func ask_ticket(t: Dictionary) -> Dictionary:
	if t.is_empty() or t.fix == "project" or t.fix == "network":
		channel.append(
			["#labratnerds", "that one is a job, not a one-click fix. ask about the job step."]
		)
		changed.emit()
		return {}
	var correct := str(t.fix)
	if correct == "restore" and not bool(Msp.backups[int(t.client)].ok):
		correct = "shadow"  # no backup: the community says try shadow copies, do not pay
	var keys := [correct]
	var others := ["spooler", "password", "clear_temp", "reboot", "av", "adobe"]
	others.shuffle()
	for key in others:
		if keys.size() >= 4:
			break
		if key != correct:
			keys.append(key)
	keys.shuffle()
	var labels := []
	for key in keys:
		labels.append(str(Msp.FIXES[key]))
	return ask(
		"#%d %s: what should I run?" % [int(t.id), str(t.summary)], labels, keys.find(correct)
	)


# what next at the current step of a big job?
func ask_step() -> Dictionary:
	if not Playbook.is_active():
		channel.append(["#labratnerds", "you are not in the middle of a job. which ticket?"])
		changed.emit()
		return {}
	var step: Dictionary = Playbook.current_step()
	var labels := []
	var best := 0
	var best_pts := -1
	for i in step.choices.size():
		var ch: Dictionary = step.choices[i]
		labels.append(str(ch.label))
		if Playbook.lock_reason(ch) == "" and int(ch.pts) > best_pts:
			best_pts = int(ch.pts)
			best = i
	return ask("%s: what next?" % str(step.title), labels, best)


func _process(delta: float) -> void:
	if _lines.is_empty():
		return
	for line in _lines:
		line[0] = float(line[0]) - delta
	while not _lines.is_empty() and float(_lines[0][0]) <= 0.0:
		var line: Array = _lines.pop_front()
		channel.append([line[1], line[2]])
		while channel.size() > 14:
			channel.pop_front()
	if _lines.is_empty() and bool(hint.get("pending", false)):
		hint["pending"] = false
	changed.emit()


func to_dict() -> Dictionary:
	return {"karma": karma, "mine": mine.duplicate(), "first_day": first_day}


func from_dict(data: Dictionary) -> void:
	reset()
	karma = int(data.get("karma", 10))
	first_day = int(data.get("first_day", -1))
	var saved: Dictionary = data.get("mine", {})
	for key in saved:
		mine[int(key)] = int(saved[key])
