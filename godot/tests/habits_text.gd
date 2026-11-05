extends SceneTree
# R38 P2: the words of the good habits stay in the 3x5 pixel font charset and in 2013-14 (no AI, no MFA, no long dashes, no brackets).

const OK_CHARS := ".,:;!?-_/()'@#%&+=$<> *"
const BANNED := ["mfa", " ai ", "chatgpt", "teams", "slack", "windows 10", "windows 11", "tiktok", "discord", "smartphone app"]

var failures := 0
var checked := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL " + what)


func _scan(where: String, text: String) -> void:
	checked += 1
	var low := " " + text.to_lower() + " "
	for word in BANNED:
		_check(not low.contains(word), "%s has the banned word '%s'" % [where, word])
	for i in text.length():
		var ch := text[i]
		var letter := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")
		_check(letter or OK_CHARS.contains(ch), "%s has the character '%s' (%s)" % [where, ch, text.substr(0, 40)])


func _walk(where: String, v: Variant) -> void:
	if v is Dictionary:
		for k in v:
			if str(k) in ["fx"]:
				continue
			_walk(where + "." + str(k), v[k])
	elif v is Array:
		for i in v.size():
			_walk(where + "." + str(i), v[i])
	elif v is String:
		_scan(where, v)


func _init() -> void:
	await process_frame
	var h: Script = load("res://scripts/habits.gd")
	_walk("HABITS", h.HABITS)
	_walk("TEXT", h.TEXT)
	_walk("CARDS", h.CARDS)
	_check(checked > 80, "enough strings were scanned (%d)" % checked)
	_check(h.HABITS.size() == 14, "14 habits")
	print("scanned %d strings, failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)
