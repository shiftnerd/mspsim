extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# LabRat Nerds: the community forum and IRC channel for LabRat users (a parody of the LabTech Geek community of the day).
#   FORUM: a few threads a day. Reading gives a little skill XP; answering (needs the skill level) gives more XP and karma.
#   IRC (#labratnerds): "call a friend". Ask the channel which fix a ticket needs, or what to do at the current job step.
#   Four nicks answer one by one; accuracy depends on the nick and on your karma; the troll may lead you astray.
#   Asking costs a little karma and has a cooldown, so you earn the right to ask by contributing on the forum.

signal changed

const NICKS := {
	"rodent_rick": {"acc": 0.85, "color": Color("5aa0e8")},
	"gnawer": {"acc": 0.75, "color": Color("3cc15a")},
	"PS_wizard": {"acc": 0.9, "color": Color("c585f0")},
	"old_hand": {"acc": 0.8, "color": Color("e0a030")},
	"xX_n00b_Xx": {"acc": 0.4, "color": Color("e07b22")},
	"trollbot": {"acc": 0.2, "color": Color("d23c3c")},
}
const DEFAULT_JOKES := [
	"have you tried turning it off and on again?",
	"just reinstall windows lol",
	"blame the antivirus",
	"that is a PEBKAC, tell the user",
	"format c: fixes everything",
]
var JOKES: Array = DEFAULT_JOKES.duplicate(true)
const DEFAULT_THREADS := [
	{"title": "Print spooler keeps dying on 2008 R2", "skill": "servers", "level": 0},
	{"title": "Users locked out after bad passwords: GPO?", "skill": "security", "level": 0},
	{"title": "Disk full, where is all the temp junk?", "skill": "servers", "level": 0},
	{"title": "Blue screen 0x7B after a controller swap", "skill": "servers", "level": 1},
	{"title": "CryptoLocker: shadow copies, any luck?", "skill": "security", "level": 2},
	{"title": "Robocopy /MIR and NTFS permissions", "skill": "servers", "level": 2},
	{"title": "VLANs for voice and data on a cheap switch", "skill": "networking", "level": 2},
	{"title": "Stopping RDP brute force: what do you use?", "skill": "security", "level": 1},
	{"title": "Windows XP end of support: migration list?", "skill": "servers", "level": 1},
	{"title": "Script to clean temp files on every client", "skill": "servers", "level": 1},
]
var THREADS: Array = DEFAULT_THREADS.duplicate(true)
const COOLDOWN := 45.0
const RANKS := [[40, "GURU"], [20, "REGULAR"], [8, "MEMBER"], [0, "LURKER"]]

var karma := 10
var threads: Array = []  # today's threads: {id, read, answered}
var channel: Array = []  # [nick, text]
var hint := {}  # {question, best, votes, total, pending}

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


func ensure_threads() -> void:
	if Campaign.day == _day and not threads.is_empty():
		return
	_day = Campaign.day
	var ids := []
	for i in THREADS.size():
		ids.append(i)
	ids.shuffle()
	threads = []
	for i in 5:
		threads.append({"id": ids[i], "read": false, "answered": false})
	changed.emit()


func read_thread(index: int) -> void:
	ensure_threads()
	var th: Dictionary = threads[index]
	if th.read:
		return
	th.read = true
	Skills.add_xp(str(THREADS[int(th.id)].skill), 2)
	changed.emit()


func answer_thread(index: int) -> String:
	ensure_threads()
	var th: Dictionary = threads[index]
	if th.answered:
		return "ALREADY ANSWERED"
	var def: Dictionary = THREADS[int(th.id)]
	if Skills.level(str(def.skill)) < int(def.level):
		karma = maxi(0, karma - 1)
		changed.emit()
		return "YOU ARE NOT SURE ENOUGH TO ANSWER"
	th.answered = true
	th.read = true
	karma += 2
	Skills.add_xp(str(def.skill), 4)
	changed.emit()
	return "POSTED. +2 KARMA"


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
	return {"karma": karma}


func from_dict(data: Dictionary) -> void:
	reset()
	karma = int(data.get("karma", 10))
