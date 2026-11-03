extends SceneTree
# C7 / V4: the Service-mode voices of Talk and Lynk. Small talk and tips for Maya, Sam, Terry, a hire, Vic, Morgan, Alan and
# Garrison come from ServiceArc.VOICES; Alan asks about quality, Garrison about clients and Morgan about the scorecard (a
# question card Dan answers); Lynk messages come from the service cast with effects; the tech campaign keeps its own lines.

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node, choice := 0) -> int:
	var n := 0
	while cards.is_open and n < 40:
		var idx: int = choice if choice < cards.options.size() else 0
		if not bool(cards.options[idx].get("enabled", true)):
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					idx = i
					break
		cards.pick(idx)
		n += 1
	return n


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var arc := root.get_node("ServiceArc")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var talk := root.get_node("Talk")
	var lync := root.get_node("Lync")
	var social := root.get_node("Social")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	player_script.current_character = "office_dan"
	c.new_game("service")
	_clear(cards)
	c.day = 6

	# ---- a hire, for the borrowed voice
	var cand: Dictionary = crew.make_candidates(3)[0]
	sv.finish_hire(cand, "structured")
	crew.onboard_pending(6)
	var hire: String = str(crew.hire_order[0])
	_check(crew.is_hire(hire), "a hire is on the crew (%s)" % hire)

	# ---- small talk and tips for everybody
	var people := ["Maya", "Sam", "Terry", hire, "Vic", "Morgan", "Alan", "Garrison"]
	var all_service := true
	var all_tips := true
	for who in people:
		social.rel[who] = 40  # friendly, so no curt replies
		talk._who = who
		var key: String = "hire" if who == hire else who
		var line: String = talk.small_talk()
		all_service = all_service and arc.VOICES.small[key].has(line)
		var tip: String = talk.tip()
		var base: String = tip.split(" (+")[0]
		all_tips = all_tips and arc.VOICES.tips[key].has(base)
	_check(all_service, "small talk is in the service voice for all eight (Maya, Sam, Terry, a hire, Vic, Morgan, Alan, Garrison)")
	_check(all_tips, "tips are in the service voice too")
	var owners_distinct: bool = arc.VOICES.small.Alan != arc.VOICES.small.Garrison and arc.VOICES.small.Morgan != arc.VOICES.small.Vic
	_check(owners_distinct, "each voice is its own")
	social.rel["Alan"] = -50
	talk._who = "Alan"
	_check(talk.small_talk().begins_with("Mm."), "a cold coworker is curt in any voice")
	social.rel["Alan"] = 40

	# ---- the menu: Alan, Garrison and Morgan have a question for Dan
	for who in ["Alan", "Garrison", "Morgan"]:
		_check(arc.has_question(who), "%s has a question" % who)
	_check(not arc.has_question("Maya") and not arc.has_question("Sam"), "the crew has one on ones, not questions")
	talk._who = "Alan"
	talk._menu("Hello.")
	var labels := []
	for o in cards.options:
		labels.append(str(o.label))
	_check(labels.has("THEIR QUESTION"), "Alan's menu offers THEIR QUESTION: " + str(labels))
	cards._pick_leave()
	_clear(cards)
	talk._who = ""

	# ---- the question flow: Alan asks about quality
	var ta0: int = sv.trust_of("Alan")
	arc.question("Alan")
	_check(cards.is_open and str(cards.speaker) == "Alan" and str(cards.text).length() > 30, "Alan asks his question")
	_check(cards.options.size() == 3, "three quiet answers")
	var asked_text := str(cards.text)
	cards.pick(0)
	_check(cards.is_open and str(cards.text).length() > 10, "he replies")
	_clear(cards)
	_check(sv.trust_of("Alan") >= ta0, "the good answer does not cost trust")
	arc.question("Alan")
	_check(str(cards.text).contains("Ask me again tomorrow"), "the same day he does not ask twice")
	_clear(cards)
	c.day = 7
	arc.question("Alan")
	_check(str(cards.text) != asked_text, "the next day it is another question")
	_clear(cards)
	arc.question("Garrison")
	_check(str(cards.text).contains("%d" % int(root.get_node("Sales").average())) or str(cards.text).length() > 30, "Garrison asks about the clients")
	_clear(cards)
	sv.grades = [{"day": 6, "grade": "B", "score": 70, "util": 70, "sla": 91}]
	c.day = 8
	var seen_morgan := false
	arc.question("Morgan")
	seen_morgan = str(cards.text).contains("grade yesterday was B")
	_clear(cards)
	_check(seen_morgan, "Morgan asks about the scorecard with your real grade")
	var conf0: int = c.rep
	arc.question("Morgan")
	_clear(cards)
	var conf1: int = c.rep
	_check(conf1 >= conf0 - 1, "her answers move confidence by at most a point")

	# ---- Lynk: the service cast writes to you
	var contacts: Array = lync.contacts()
	_check(contacts.has("Sam") and contacts.has("Terry") and contacts.has("Maya") and contacts.has("Morgan"), "the crew are Lynk contacts: " + str(contacts))
	lync.pending = {}
	lync.chats = {}
	for n in ["Maya", "Sam", "Alan"]:  # in the building and at their desks
		root.get_node("World").chars[n].scene = "main_floor"
		root.get_node("World").chars[n].legs = [{"kind": "work"}]
	var pushed := 0
	for i in 12:
		lync.pending = {}
		if arc.lynk_incoming():
			pushed += 1
			break
	_check(pushed == 1 and lync.pending.size() == 1, "a service message arrives with a pending reply")
	var who: String = str(lync.pending.keys()[0])
	var msg: Dictionary = lync.pending[who]
	_check(arc.VOICES.lync.has(who) and msg.options.size() == 2, "from %s, with two answers" % who)
	var soc0: int = social.value(who) if social.rel.has(who) else 0
	lync.reply(who, 0)
	_check(not lync.pending.has(who) and lync.chats[who].size() >= 2, "the reply is sent and answered")
	# a reply with morale and trust effects
	lync.pending = {"Maya": arc.VOICES.lync.Maya[0]}
	crew.members["Maya"]["morale"] = 50
	lync.reply("Maya", 0)
	_check(crew.morale("Maya") > 50, "saying yes to Maya lifts her morale")
	lync.pending = {"Alan": arc.VOICES.lync.Alan[0]}
	var tr0: int = sv.trust_of("Alan")
	lync.reply("Alan", 0)
	_check(sv.trust_of("Alan") >= tr0 + 1, "answering Alan properly earns his trust")
	lync.chats = {}
	lync.unread = {}
	lync._boss_reply("Morgan")
	var boss_line: String = str(lync.chats["Morgan"][-1][1])
	_check(boss_line.length() > 20 and not boss_line.contains("backups today"), "Morgan's advice is about the desk: " + boss_line)

	# ---- the tech campaign keeps its own voices
	c.new_game("tech")
	_clear(cards)
	talk._who = "Maya"
	social.rel["Maya"] = 40
	var tline: String = talk.small_talk()
	var tech_ok: bool = false
	for l in talk.SMALL.Maya:
		tech_ok = tech_ok or tline.begins_with(str(l))  # (a friend sometimes adds gossip)
	_check(tech_ok, "in the tech campaign Maya still uses her old lines")
	_check(not arc.has_question("Alan"), "no question card outside the service campaign")
	var lbl := []
	talk._who = "Alan"
	talk._menu("Hello.")
	for o in cards.options:
		lbl.append(str(o.label))
	cards._pick_leave()
	_clear(cards)
	_check(not lbl.has("THEIR QUESTION"), "and no extra menu entry")
	talk._who = ""

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
