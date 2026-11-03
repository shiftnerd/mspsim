extends Node
# gdlint:disable=max-line-length
# Story text you can edit without touching code. The game's mails, texts, jobs, cards, dialogue, forum threads and
# endings live in data tables in the scripts (the defaults); `res://story/strings.txt` holds every one of those
# strings as plain text under a [key]. At startup this autoload reads the file and replaces the defaults with what
# it says, so editing the file changes the game. Rules: a string that is missing from the file keeps its default,
# a key that does not exist is reported (not an error), a line starting with # is a comment, and a replacement
# must keep the same %s / %d placeholders as the original (otherwise it is ignored and reported).
# tests/story_export.gd writes the file (--init), refreshes it after the code changes (--sync, keeps your edits)
# and writes the readable story bible res://story/STORY.md (--doc).

const FILE := "res://story/strings.txt"
const ROOTS := {
	"Story": ["DAYS", "VIGNETTES"],
	"Events": ["DECK"],
	"Playbook": ["BOOKS", "PROBLEMS"],
	"Owner": ["CARDS"],
	"Msp": ["PROBLEMS", "RANSOM", "ADOBE", "INSTALL"],
	"Talk": ["GREETINGS", "SMALL", "GOSSIP", "TIPS_GENERIC", "OWNER_HOLD"],
	"Nerds": ["JOKES", "THREADS"],
	"Lync": ["MESSAGES"],
	"Review": ["QUOTES", "OWNER_QUOTES", "EPILOGUES"],
	"Social": ["THANKS"],
	"Shift": ["WEEK_TRAFFIC", "REASONS", "PAGES"],
	"Hints": ["DAY1"],
	"Growth": ["STRETCH"],
	"Expo": ["TEXT", "ROUNDS", "VENDORS", "CHATS"],
	"PrinterGame": ["TEXT", "QUESTIONS", "MODEL_TEXT"],
	"Onsite":
	["TEXT", "JOBS", "MORE_JOBS", "EVENTS", "STAFF", "SITE_APPS", "PETS", "FINDINGS", "MEETINGS"],
}
# fields that are always text (even when short, like OK) and fields that never are
const TEXT_KEYS := [
	"title",
	"text",
	"body",
	"subject",
	"from",
	"label",
	"speaker",
	"note",
	"summary",
	"reply",
	"desc",
	"line",
	"error",
	"situation",
	"result"
]
const SKIP_KEYS := [
	"kind",
	"fix",
	"flag",
	"unflag",
	"needs",
	"id",
	"special",
	"specials",
	"book",
	"event",
	"card",
	"skill",
	"trait",
	"show",
	"effect",
	"req",
	"fx",
	"stack",
	"client",
	"unless"
]
const BANNED := [
	"chatgpt",
	" ai ",
	"artificial intelligence",
	"microsoft teams",
	"slack",
	"microsoft 365",
	"office 365",
	"tiktok",
	"discord",
	"windows 10",
	"windows 11",
	"gdpr",
	"mfa ",
	"edr",
	"zoom call"
]

var report: Array = []  # what went wrong (or was suspicious) while loading the file
var applied := 0
var loaded := false


func _ready() -> void:
	load_file()
	for line in report:
		push_warning("story/strings.txt: " + str(line))


# ---- the data tables ---------------------------------------------------------------------------
func _node(root: String) -> Node:
	return get_node_or_null("/root/" + root)


func _defaults(root: String, name: String) -> Variant:
	var node := _node(root)
	if node == null:
		return null
	var map: Dictionary = node.get_script().get_script_constant_map()
	return map.get("DEFAULT_" + name, null)


func is_text(key: String, value: String) -> bool:
	if key in SKIP_KEYS:
		return false
	if key in TEXT_KEYS:
		return true
	return value.length() >= 15 and value.contains(" ")


# every editable string of the defaults: [{key, text, path}]
func entries() -> Array:
	var out := []
	for root in ROOTS:
		for name in ROOTS[root]:
			var data: Variant = _defaults(str(root), str(name))
			if data != null:
				_walk(data, [str(root), str(name)], "", out)
	return out


func _walk(value: Variant, path: Array, hint: String, out: Array) -> void:
	if value is Dictionary:
		for k in value:
			_walk(value[k], path + [str(k)], str(k), out)
	elif value is Array:
		for i in value.size():
			_walk(value[i], path + [str(i)], hint, out)
	elif value is String and is_text(hint, value):
		out.append({"key": ".".join(path), "text": value, "path": path})


# ---- reading the file ---------------------------------------------------------------------------
# [key] lines start an entry; the lines under it are joined with single spaces; # lines are comments
func parse(content: String) -> Dictionary:
	var out := {}
	var key := ""
	var parts: Array = []
	for raw in content.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]") and line.length() > 2:
			if key != "":
				out[key] = " ".join(parts)
			key = line.substr(1, line.length() - 2)
			parts = []
		elif key != "" and line != "":
			parts.append(line)
	if key != "":
		out[key] = " ".join(parts)
	return out


func load_file(path := FILE) -> int:
	report = []
	applied = 0
	loaded = false
	if not FileAccess.file_exists(path):
		return 0
	loaded = true
	var table := parse(FileAccess.get_file_as_string(path))
	var known := {}
	for e in entries():
		known[str(e.key)] = e
	for key in table:
		if not known.has(key):
			report.append("UNKNOWN KEY (ignored): [%s]" % key)
			continue
		var text: String = table[key]
		var original: String = known[key].text
		if text == original:
			continue
		if text == "":
			report.append("EMPTY (kept the default): [%s]" % key)
			continue
		if _placeholders(text) != _placeholders(original):
			report.append(
				(
					"PLACEHOLDERS CHANGED (ignored): [%s] must keep %s"
					% [key, str(_placeholders(original))]
				)
			)
			continue
		if _store(known[key].path, text):
			applied += 1
			_scan_banned(key, text)
	return applied


# the %s %d %.1f ... markers in a string, in order
func _placeholders(text: String) -> Array:
	var out := []
	var i := 0
	while i < text.length():
		if text[i] == "%":
			if i + 1 < text.length() and text[i + 1] == "%":
				i += 2
				continue
			var j := i + 1
			while j < text.length() and text[j] in "0123456789.+-# ":
				j += 1
			if j < text.length():
				out.append(text[j])
			i = j
		i += 1
	return out


func _scan_banned(key: String, text: String) -> void:
	var low := " " + text.to_lower() + " "
	for word in BANNED:
		if low.contains(word):
			report.append(
				"PERIOD CHECK (this is 2013-14): [%s] mentions '%s'" % [key, word.strip_edges()]
			)


# write a string into the live table (the patched copy of the defaults)
func _store(path: Array, text: String) -> bool:
	var node := _node(str(path[0]))
	if node == null:
		return false
	var cur: Variant = node.get(str(path[1]))
	for i in range(2, path.size() - 1):
		cur = _child(cur, str(path[i]))
		if cur == null:
			return false
	var last := str(path[path.size() - 1])
	if cur is Array and last.is_valid_int():
		cur[int(last)] = text
		return true
	if cur is Dictionary:
		for k in cur:
			if str(k) == last:
				cur[k] = text
				return true
	return false


func _child(cur: Variant, part: String) -> Variant:
	if cur is Array and part.is_valid_int() and int(part) < cur.size():
		return cur[int(part)]
	if cur is Dictionary:
		for k in cur:
			if str(k) == part:
				return cur[k]
	return null


# ---- writing the file ----------------------------------------------------------------------------
# a short human description of where a string is used (a comment above its [key])
func describe(path: Array) -> String:
	var root := str(path[0])
	var name := str(path[1])
	var rest := path.slice(2)
	if root == "Story" and name == "DAYS" and rest.size() >= 2:
		var ev: Dictionary = _child(_child(_node("Story").get("DAYS"), str(rest[0])), str(rest[1]))
		return (
			"Day %s, %s, %s: %s"
			% [
				str(rest[0]),
				_clock(float(ev.get("at", 0.0))),
				str(ev.get("kind", "event")).to_upper(),
				str(rest[rest.size() - 1])
			]
		)
	if root == "Playbook" and name == "BOOKS" and rest.size() >= 1:
		var book: Dictionary = _child(_node("Playbook").get("BOOKS"), str(rest[0]))
		var where := "job: " + str(book.get("title", rest[0]))
		if rest.size() >= 3 and str(rest[1]) == "steps":
			where += ", step %d" % (int(rest[2]) + 1)
		return where
	if root == "Owner" and name == "CARDS" and rest.size() >= 1:
		return "owner card: " + str(rest[0])
	return " > ".join(path)


func _clock(hours: float) -> String:
	var h := int(hours)
	return "%d:%02d" % [h, int((hours - float(h)) * 60.0)]


# the whole file text. Existing edits (key -> text) are kept; new strings use the code's text.
func build(existing: Dictionary) -> String:
	var lines := PackedStringArray(
		[
			"# MSPSim story text. Edit the text under each [key] and keep the [key] line as it is.",
			"# Keep %s / %d markers (they are filled in by the game). Lines under a key are joined into one paragraph.",
			"# The game is set in 2013-14: no AI, Teams, Slack, Windows 10/11, MFA, TikTok. See README.md.",
			"",
		]
	)
	var seen := {}
	var last_group := ""
	for e in entries():
		var group := " > ".join(PackedStringArray([str(e.path[0]), str(e.path[1])]))
		if group != last_group:
			lines.append("")
			lines.append("# ======================= " + group + " =======================")
			last_group = group
		lines.append("# " + describe(e.path))
		lines.append("[%s]" % str(e.key))
		lines.append(str(existing.get(str(e.key), e.text)))
		lines.append("")
		seen[str(e.key)] = true
	var obsolete := []
	for key in existing:
		if not seen.has(key):
			obsolete.append(key)
	if not obsolete.is_empty():
		(
			lines
			. append(
				"# ======================= NO LONGER USED BY THE GAME (safe to delete) ======================="
			)
		)
		for key in obsolete:
			lines.append("[%s]" % str(key))
			lines.append(str(existing[key]))
			lines.append("")
	return "\n".join(lines)
