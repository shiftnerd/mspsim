extends SceneTree
# Canon: Alan and Garrison are the two OWNERS of Pixel IT Partners (Alan technical, Garrison sales and culture),
# not ordinary techs. Fails if the old tech-style role phrases come back in the player-facing text tables, and checks
# the owners still have greetings, small talk and tips, owner-style Lynk messages and owner labels.

# ("senior tech" is not banned any more: Adam is the senior tech; the owners still are not)
const BANNED := [
	"security guy",
	"security tech",
	"(security)",
	"the security person",
	"junior tech",
]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# every string inside a table, however deeply nested
func _strings(v: Variant, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Dictionary:
		for k in v:
			_strings(v[k], out)
	elif v is Array:
		for x in v:
			_strings(x, out)


func _scan(label: String, table: Variant) -> void:
	var all: Array = []
	_strings(table, all)
	var bad := ""
	for s in all:
		var low := str(s).to_lower()
		for phrase in BANNED:
			if low.contains(phrase):
				bad = str(s).substr(0, 60)
	_check(bad == "", "%s has no tech-style role phrases %s" % [label, bad])


func _init() -> void:
	await process_frame
	var talk := root.get_node("Talk")
	var lync := root.get_node("Lync")
	var social := root.get_node("Social")
	var story := root.get_node("Story")
	var review := root.get_node("Review")

	# ---- the player-facing tables
	_scan("Talk.GREETINGS", talk.GREETINGS)
	_scan("Talk.SMALL", talk.SMALL)
	_scan("Talk.TIPS_GENERIC", talk.TIPS_GENERIC)
	_scan("Talk.GOSSIP", talk.GOSSIP)
	_scan("Lync.MESSAGES", lync.MESSAGES)
	_scan("Story.DAYS", story.DAYS)
	_scan("Story.VIGNETTES", story.VIGNETTES)
	_scan("Playbook.BOOKS", root.get_node("Playbook").BOOKS)
	_scan("Owner.CARDS", root.get_node("Owner").CARDS)
	_scan("Review.QUOTES", review.QUOTES)
	_scan("Review.OWNER_QUOTES", review.OWNER_QUOTES)
	_scan("Review.EPILOGUES", review.EPILOGUES)
	_scan("Growth.STRETCH", root.get_node("Growth").STRETCH)
	var file := FileAccess.get_file_as_string("res://story/strings.txt")
	_check(not file.is_empty(), "story/strings.txt is readable")
	var bad_file := ""
	for phrase in BANNED:
		if file.to_lower().contains(phrase):
			bad_file = phrase
	_check(bad_file == "", "story/strings.txt has no tech-style role phrase " + bad_file)

	# ---- the owners keep their voices
	for who in ["Alan", "Garrison"]:
		for tier in ["friend", "neutral", "cold"]:
			_check(str(talk.GREETINGS[who].get(tier, "")) != "", "%s has a %s greeting" % [who, tier])
		_check((talk.SMALL[who] as Array).size() >= 4, "%s has small talk" % who)
		_check((talk.TIPS_GENERIC[who] as Array).size() >= 3, "%s has tips" % who)
		_check(social.is_owner(who), "%s is an owner" % who)
		_check(social.role(who) == "CO-OWNER", "%s is labelled CO-OWNER" % who)
		for kind in ["lunch", "phones", "help", "thanks"]:
			_check(lync.MESSAGES.has(kind + "_" + who), "%s has an owner-style %s message" % [who, kind])
	for who in ["Dan", "John", "Maya"]:
		_check(not social.is_owner(who), "%s is staff, not an owner" % who)

	# ---- owner Lynk asks keep the quick-reply structure and the effects of the generic ones
	for who in ["Alan", "Garrison"]:
		for kind in ["lunch", "phones", "help"]:
			var generic: Array = lync.MESSAGES[kind].options
			var mine: Array = lync.MESSAGES[kind + "_" + who].options
			var same := mine.size() == generic.size()
			for i in mini(mine.size(), generic.size()):
				same = same and int(mine[i].social) == int(generic[i].social)
				same = same and int(mine[i].get("xp", 0)) == int(generic[i].get("xp", 0))
			_check(same, "%s's %s message has the same options and effects" % [who, kind])
		_check(not str(lync.MESSAGES["phones_" + who].text).to_lower().contains("my phones"), "%s does not ask you to cover the phones" % who)
		_check(not str(lync.MESSAGES["help_" + who].text).to_lower().contains("spooler"), "%s does not ask how to fix a spooler" % who)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
