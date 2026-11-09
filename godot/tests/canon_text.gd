extends SceneTree
# Canon, the mechanical part: the game is set in 2013-14 and parodies its real brands (docs/GAME_BIBLE.md). strings.gd already
# scans story/strings.txt for the era words (Strings.BANNED); this test scans EVERY string literal in godot/scripts/*.gd, which is where
# the outing blurbs, the events, the chats and the HUD text live, for the same era words and for the real MSP vendors the
# game parodies. A hit fails with the file and the line of text. A deliberate use goes in ALLOW (file -> phrases) with a reason.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/canon_text.gd

# real MSP and security vendors: the game uses invented names (ConnectWhy, LabRat RMM, Outlookish 2013, LabRat Nerds)
const BRANDS := [
	"connectwise",
	"kaseya",
	"datto",
	"autotask",
	"ninjaone",
	"n-able",
	"solarwinds",
	"veeam",
	"barracuda",
	"sophos",
	"crowdstrike",
	"webroot",
	"halopsa",
	"syncro",
	"atera",
	"teamviewer",
	"quickbooks",
	"salesforce",
	"screenconnect",
]
# deliberate uses: a forum regular names the remote tool his shop moved to (a 2013 product)
const ALLOW := {"nerds.gd": ["screenconnect"]}
# files that hold the lists themselves
const SKIP_FILES := ["strings.gd"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _word(phrase: String) -> RegEx:
	var re := RegEx.new()
	re.compile("(?<![a-z0-9])" + _escape(phrase.strip_edges()) + "(?![a-z0-9])")
	return re


func _escape(text: String) -> String:
	var out := ""
	for ch in text:
		out += ("\\" + ch) if ch in ".-+*?()[]{}|^$\\" else ch
	return out


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var era: Array = load("res://scripts/strings.gd").BANNED
	var phrases: Array = []
	for p in era:
		phrases.append({"text": str(p), "kind": "era word", "re": _word(str(p))})
	for p in BRANDS:
		phrases.append({"text": str(p), "kind": "real brand", "re": _word(str(p))})
	var lit := RegEx.new()
	lit.compile('"((?:[^"\\\\\\n]|\\\\.)*)"')
	var scanned := 0
	var hits := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if not f.ends_with(".gd") or f in SKIP_FILES:
			continue
		var text := FileAccess.get_file_as_string("res://scripts/" + f)
		var allowed: Array = ALLOW.get(f, [])
		for m in lit.search_all(text):
			var low := m.get_string(1).to_lower()
			scanned += 1
			for p in phrases:
				if str(p.text).strip_edges() in allowed:
					continue
				if (p.re as RegEx).search(low) != null:
					hits += 1
					_check(false, "%s: %s '%s' in \"%s\"" % [f, p.kind, str(p.text).strip_edges(), m.get_string(1).substr(0, 70)])
	_check(scanned > 5000, "scanned the string literals of the scripts (%d)" % scanned)
	_check(hits == 0, "no era words or real vendor names in the player-facing text")
	_check(not era.is_empty(), "the era list is loaded (%d words)" % era.size())
	# the scanner itself catches what it should
	var probe := _word("slack")
	_check(probe.search("we use slack here") != null and probe.search("slacker") == null, "word boundaries: slack yes, slacker no")
	print("canon_text: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
