extends SceneTree
# gdlint:disable=max-line-length
# R38 P6: the text guard for the rival and good-habit content (docs/scope-bad-habits.md sections 0, 8 and 9).
# Every string of every R38 table must (1) draw in the 3x5 pixel font (no square brackets, curly quotes or long dashes; the {token}
# placeholders are filled before drawing), (2) hold no 2013-14 slip (AI, MFA, Teams, Slack, Windows 10 ...) and (3) hold none of the
# names in story/banned_names.txt (the blog series' character names, seeded by the user; empty today).
# The tables are DISCOVERED, not counted: the scripts in REGISTRY plus every script under scripts/ whose header comment starts with # R38, all
# their constants (recursively), the forum threads and IRC lines with a rap: condition, the sales beats about the rival, the Year 2
# text, the career entries of R38 and the matching entries of story/strings.txt. A table added later by another agent is covered
# by the same rules without a change here (a new script only has to start a header comment line with # R38).

const PixelFont := preload("res://scripts/pixelfont.gd")
const REGISTRY := [
	"res://scripts/rival.gd",
	"res://scripts/rival_cards.gd",
	"res://scripts/habits.gd",
	"res://scripts/habits_view.gd",
	"res://scripts/temptation.gd",
	"res://scripts/takeover.gd",
	"res://scripts/rival_touches.gd",
]
const HEADER_LINES := 15
const NOT_ALLOWED := "[]"  # in the font, but the house rules keep square brackets out of the text
const KEY_PREFIXES := [
	"Rival.", "RivalCards.", "RivalTouches.", "Habits.", "Temptation.", "Takeover."
]
const BANNED_FILE := "res://story/banned_names.txt"
const SLIPS := [
	"\\bai\\b",
	"\\bmfa\\b",
	"\\bteams\\b",
	"\\bslack\\b",
	"windows 10",
	"windows 11",
	"chatgpt",
	"discord",
	"tiktok",
	"office 365",
	"microsoft 365",
	"\\bedr\\b",
	"gdpr",
	"zoom call",
	"artificial intelligence",
]

var failures := 0
var glyphs: Dictionary = PixelFont.GLYPHS
var slips: Array = []
var names: Array = []


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# ---- the rules -------------------------------------------------------------------------------------------------------
func load_banned() -> Array:
	var out := []
	if not FileAccess.file_exists(BANNED_FILE):
		return out
	for raw in FileAccess.get_file_as_string(BANNED_FILE).split("\n"):
		var line := raw.strip_edges()
		if line != "" and not line.begins_with("#"):
			out.append(line.to_lower())
	return out


# the problems of one string ("" when it is fine): characters the font cannot draw, 2013-14 slips, banned names
func problems(text: String) -> String:
	var bad := ""
	var plain := text
	var tokens := RegEx.create_from_string("\\{[a-z_]+\\}")
	plain = tokens.sub(plain, "", true)
	for ch in plain.to_upper():
		if not glyphs.has(ch) or ch in NOT_ALLOWED:
			bad += " char[%s]" % ch
	var low := plain.to_lower()
	for re in slips:
		if re.search(low) != null:
			bad += " slip[%s]" % re.get_pattern()
	for n in names:
		if low.contains(str(n)):
			bad += " banned[%s]" % n
	return bad


# every string value under a variant, with a path for the report
func gather(value: Variant, path: String, out: Array) -> void:
	if value is String:
		out.append([path, value])
	elif value is Dictionary:
		for k in value:
			gather(value[k], path + "." + str(k), out)
	elif value is Array:
		for i in value.size():
			gather(value[i], path + "." + str(i), out)


func r38_scripts() -> Array:
	var out := []
	for p in REGISTRY:
		out.append(str(p))
	var dir := DirAccess.open("res://scripts")
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var path := "res://scripts/" + f
		if out.has(path):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n").slice(0, HEADER_LINES):
			if line.begins_with("# R38"):  # a header comment, not a hook line that merely says R38
				out.append(path)
				break
	return out


func scan(label: String, list: Array) -> int:
	var bad := []
	for pair in list:
		var p := problems(str(pair[1]))
		if p != "":
			bad.append("%s:%s (%s)" % [pair[0], p, str(pair[1]).left(40)])
	_check(bad.is_empty(), "%s: %d strings clean %s" % [label, list.size(), str(bad.slice(0, 4))])
	return list.size()


func _init() -> void:
	await process_frame
	for s in SLIPS:
		slips.append(RegEx.create_from_string(s))
	names = load_banned()

	# ---- the scanner itself
	_check(problems("Two-factor login is on.") == "", "plain 2013-14 text passes")
	_check(
		problems("Call {client} at 9:30. Cost: $50 (50%).") == "",
		"placeholders, digits and punctuation pass"
	)
	_check(problems("see [this]").contains("char"), "a square bracket is caught")
	_check(problems("it’s done").contains("char"), "a curly quote is caught")
	_check(problems("one — two").contains("char"), "a long dash is caught")
	_check(problems("We use AI for tickets").contains("slip"), "AI is caught")
	_check(problems("turn on MFA").contains("slip"), "MFA is caught")
	_check(
		problems("a Slack channel and Windows 10").contains("slip"),
		"Slack and Windows 10 are caught"
	)
	_check(problems("Mail is on the Teams server").contains("slip"), "Teams is caught")
	_check(problems("Wait for the paid mail") == "", "ai inside a word is fine")
	names = ["zzname"]
	_check(problems("hello Zzname there").contains("banned"), "a banned name is caught (any case)")
	names = load_banned()
	_check(
		FileAccess.file_exists(BANNED_FILE),
		"story/banned_names.txt exists (%d names)" % names.size()
	)

	# ---- the script tables (constants, recursively)
	var scripts := r38_scripts()
	_check(
		scripts.size() >= REGISTRY.size(),
		"%d R38 scripts discovered (%d registered)" % [scripts.size(), REGISTRY.size()]
	)
	var total := 0
	for path in scripts:
		var script: Script = load(path)
		var list := []
		var map: Dictionary = script.get_script_constant_map()
		for k in map:
			gather(map[k], str(k), list)
		total += scan(path.get_file(), list)

	# ---- the forum threads and IRC lines that need a rap sheet entry
	var nerds := root.get_node("Nerds")
	var forum := []
	var rap_threads := 0
	for i in nerds.THREADS.size():
		var th: Dictionary = nerds.THREADS[i]
		if str(th.get("needs", "")).begins_with("rap:"):
			rap_threads += 1
			gather(th.title, "thread%d.title" % i, forum)
			gather(th.get("answer", ""), "thread%d.answer" % i, forum)
			for p in th.posts:
				gather(p.text, "thread%d.post" % i, forum)
				gather(p.by, "thread%d.by" % i, forum)
	var rap_ambient := 0
	for ex in nerds.AMBIENT:
		if str(ex.get("needs", "")).begins_with("rap:"):
			rap_ambient += 1
			for line in ex.lines:
				gather(line[1], "irc.%s" % str(ex.id), forum)
	total += scan(
		"forum and IRC (%d threads, %d exchanges with a rap: need)" % [rap_threads, rap_ambient],
		forum
	)

	# ---- the sales campaign text about the rival
	var sales := root.get_node("SalesCampaign")
	var beats := []
	for k in sales.BEAT_TEXT:
		if str(k).contains("rival") or str(k).contains("incumbent") or str(k).contains("flat"):
			gather(sales.BEAT_TEXT[k], "sales." + str(k), beats)
	total += scan("sales beats about the rival", beats)

	# ---- Year 2, the career entries of R38
	var y2 := []
	gather(root.get_node("Yeartwo").TEXT.get("habits", {}), "Yeartwo.TEXT.habits", y2)
	total += scan("Yeartwo.TEXT.habits", y2)
	var career := root.get_node("Career")
	var mine := []
	var touches: Script = load("res://scripts/rival_touches.gd")
	for m in career.MEDALS:
		for rule in m.rules:
			if touches.COUNTERS.has(str(rule[0])):
				gather(m.title, "medal." + str(m.id), mine)
				gather(m.desc, "medal." + str(m.id), mine)
	for row in career.COUNTERS:
		if touches.COUNTERS.has(str(row[2])):
			gather(row[1], "counter." + str(row[2]), mine)
			gather(row[0], "counter." + str(row[2]), mine)
	_check(mine.size() >= 12, "the career has the R38 counters and medals (%d texts)" % mine.size())
	total += scan("career medals and counters", mine)

	# ---- what the editors see: the R38 entries of story/strings.txt
	var strings := root.get_node("Strings")
	var edited := []
	if FileAccess.file_exists(strings.FILE):
		var table: Dictionary = strings.parse(FileAccess.get_file_as_string(strings.FILE))
		for key in table:
			for pre in KEY_PREFIXES:
				if str(key).begins_with(pre):
					edited.append([key, table[key]])
			if str(key).begins_with("Nerds.THREADS.") or str(key).begins_with("Nerds.AMBIENT."):
				continue  # the old forum is checked by tests/forum.gd
	total += scan("story/strings.txt R38 entries", edited)

	# the same rules on the live tables (strings.txt edits are applied to them at start-up)
	var live := []
	for root_name in KEY_PREFIXES:
		var label := str(root_name).trim_suffix(".")
		if strings.SCRIPTS.has(label):
			var script: Script = load(strings.SCRIPTS[label])
			for table_name in strings.ROOTS.get(label, []):
				gather(script.get(str(table_name)), label + "." + str(table_name), live)
	total += scan("live static tables", live)
	_check(total > 100, "at least 100 strings were scanned (%d)" % total)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
