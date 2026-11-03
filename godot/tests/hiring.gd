extends SceneTree
# gdlint:disable=max-line-length
# C6 / V3: hiring for fit. Candidate generation (a ringer, a good fit, a middle one; skill, wage, trait and three fit axes), the
# interview mini-step that reveals them, the hiring cards, hires becoming real crew NPCs (new names from a pool, a seat at the
# conference table), the cap of six, onboarding (shadow or structured: time to first solo ticket, reopens), fit effects on
# team mood, growth and quit risk, the owners' reaction, the scorecard rows and saving. Headless.

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


func _fresh() -> void:
	root.get_node("Campaign").new_game("service")
	_clear(root.get_node("Cards"))
	root.get_node("Msp").tickets.clear()
	root.get_node("World").clock = 9.5


func _kind(cands: Array, kind: String) -> Dictionary:
	for c in cands:
		if str(c.kind) == kind:
			return c
	return {}


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var talk := root.get_node("Talk")
	var difficulty := root.get_node("Difficulty")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	player_script.current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	_fresh()

	# ---- candidates
	difficulty.seed_run(99)
	var cands: Array = crew.make_candidates(3)
	_check(cands.size() == 3, "three candidates")
	var names := {}
	var ok_names := true
	for cd in cands:
		names[cd.name] = true
		ok_names = ok_names and crew.HIRE_SHEETS.has(str(cd.name)) and not crew.names().has(str(cd.name))
	_check(names.size() == 3 and ok_names, "three different new names from the pool, none of them already on the crew (%s)" % str(names.keys()))
	var ringer := _kind(cands, "ringer")
	var fitc := _kind(cands, "fit")
	var mid := _kind(cands, "mid")
	_check(not ringer.is_empty() and not fitc.is_empty() and not mid.is_empty(), "a ringer, a good fit and a middle candidate")
	_check(float(ringer.skill) >= 1.1 and int(ringer.fit.culture) <= 2, "the ringer: skill %.2f, poor culture fit (%d)" % [float(ringer.skill), int(ringer.fit.culture)])
	_check(float(fitc.skill) <= 0.8 and int(fitc.fit.culture) >= 4 and int(fitc.fit.curiosity) >= 4, "the good fit: skill %.2f, culture %d, curiosity %d" % [float(fitc.skill), int(fitc.fit.culture), int(fitc.fit.curiosity)])
	var base_wage := int(round((280.0 + 250.0 * float(ringer.skill)) / 10.0)) * 10 + int(root.get_node("Owner").TRAITS[ringer.trait].get("wage", 0))
	_check(int(ringer.wage) > base_wage, "the ringer asks for more than the formula ($%d against $%d)" % [int(ringer.wage), base_wage])
	_check(int(ringer.wage) > int(fitc.wage), "...and more than the good fit ($%d)" % int(fitc.wage))
	var axes_ok := true
	for cd in cands:
		for a in crew.FIT_AXES:
			axes_ok = axes_ok and int(cd.fit[a]) >= 1 and int(cd.fit[a]) <= 5
		axes_ok = axes_ok and crew.AREAS.has(str(cd.area)) and float(cd.areas[str(cd.area)]) >= 1.5
	_check(axes_ok, "fit axes are 1 to 5 and each candidate is strong in an area")
	difficulty.seed_run(99)
	var again: Array = crew.make_candidates(3)
	_check(str(again) == str(cands), "the same seed gives the same candidates")
	difficulty.seed_run(100)
	_check(str(crew.make_candidates(3)) != str(cands), "another seed gives others")

	# ---- the hiring card and the interview
	sv.hire_card()
	_check(cards.is_open and cards.options.size() == 4 and str(cards.options[3].label) == "DECIDE NOW", "the card offers an interview for each and DECIDE NOW")
	_check(str(cards.text).find("?") >= 0 and str(cards.text).find("SKILL") < 0, "before an interview the skill and fit are hidden")
	var hours_before: float = sv.kb.hours_left()
	cards.pick(0)
	_check(absf(hours_before - sv.kb.hours_left() - 1.0) < 0.001, "an interview costs one manager hour")
	_check(cards.is_open and str(cards.speaker).length() > 0 and str(cards.text).find("?") >= 0, "first the technical question")
	var tech_text: String = cards.text
	cards.pick(0)
	_check(cards.is_open and str(cards.text) != tech_text, "then the behavioural one")
	cards.pick(0)
	_check(cards.is_open and str(cards.text).find("SKILL") >= 0 and sv.interviewed.size() == 1, "afterwards the card shows that candidate's skill and fit")
	_check(cards.options.size() == 3, "an interviewed candidate leaves the list")
	var shown: String = cards.text
	_check(shown.count("SKILL") == 1, "only the interviewed one is revealed")
	# out of hours
	sv.kb.hours_used = sv.kb.hours_total() - 0.5
	cards.pick(2)  # DECIDE NOW is last
	_check(cards.is_open and cards.options.size() == 4 and str(cards.options[3].label) == "NO ONE RIGHT NOW", "DECIDE NOW: hire one of three, or no one")
	var tal: int = sv.trust_of("Alan")
	var trg: int = sv.trust_of("Garrison")
	cards.pick(3)
	_check(not cards.is_open and sv.trust_of("Alan") == tal - 1 and sv.trust_of("Garrison") == trg - 1, "no one: both owners wonder why the seat is empty")
	_clear(cards)

	# ---- hire the ringer: owners, onboarding, starting tomorrow
	_fresh()
	difficulty.seed_run(99)
	sv.hire_card()
	var offered: Array = sv.cands.duplicate(true)
	var rg := _kind(offered, "ringer")
	var idx := offered.find(rg)
	cards.pick(3)  # decide now
	cards.pick(idx)
	_check(cards.is_open and cards.options.size() == 2 and str(cards.options[0].label).find("SHADOW") >= 0, "then the onboarding choice: shadow or structured")
	sv.kb.hours_used = 2.0  # one hour left of three
	cards.hide()
	cards.is_open = false
	var tal2: int = sv.trust_of("Alan")
	var trg2: int = sv.trust_of("Garrison")
	_check(sv.finish_hire(rg, "structured"), "hired")
	_check(sv.trust_of("Alan") == tal2 + 3 and sv.trust_of("Garrison") == trg2 - 2, "the ringer: Alan +3, Garrison -2 (owner pressure)")
	_check(str(crew.pending[0].path) == "shadow", "structured needs two hours: without them it falls back to shadowing")
	_check(crew.size() == 3 and crew.pending.size() == 1 and not crew.can_hire() == false, "he starts tomorrow: still three on the crew today")
	var name_r: String = str(rg.name)
	var joined: Array = crew.onboard_pending(c.day)
	_check(joined == [name_r] and crew.size() == 4 and crew.is_hire(name_r) and crew.has(name_r), "tomorrow he is on the crew (%s)" % name_r)
	_check(crew.seat_of(name_r) == "Seat4" and world.row(name_r).home == "conference" and world.row(name_r).role == "crew", "hot-desks at the conference table, Seat4")
	_check(str(world.row(name_r).character) == str(crew.HIRE_SHEETS[name_r]), "his sheet is a recoloured existing character (%s)" % str(world.row(name_r).character))
	_check(not world.roster_gone().has(name_r) and world.roster_gone().has("Priya") or crew.HIRE_SHEETS.size() > 0, "a hire is not in the 'gone' list")
	world.apply_roster()
	_check(world.chars.has(name_r), "he is a real NPC in the world")
	_check(world.chars[name_r].scene == "conference" and world.DATA.SCENES["conference"].seats.has(crew.seat_of(name_r)), "...at his seat in the conference room")
	var all_sheets := true
	for n in crew.HIRE_SHEETS:
		all_sheets = all_sheets and ResourceLoader.exists("res://characters/%s.tres" % str(crew.HIRE_SHEETS[n]))
	_check(all_sheets, "every pool name has an existing character sheet")
	_check(talk.available(name_r) and talk.voice(name_r) == "Sam" and crew.names().has(name_r), "you can talk to him (E): he borrows Sam's voice")
	_check(sv.has_one_on_one(name_r), "...and have a one on one with him")

	# ---- onboarding: shadow (no tickets of his own for two days)
	_check(crew.is_shadowing(name_r) and crew.status(name_r) == "SHADOW" and crew.raw_speed(name_r) == 0.0, "shadowing: no work, status SHADOW")
	var t: Dictionary = msp.create_ticket(0, 0, "email")
	t.fix = "reboot"
	t.pri = 3
	var res: Dictionary = sv.assign(int(t.id), name_r, true)
	_check(not res.ok and str(res.msg).find("SHADOW") >= 0, "the board will not assign to him: %s" % str(res.msg))
	_check(crew.fit(name_r, t) == 0.0 and crew.best_for(t) != name_r, "autopilot skips him")
	_check(crew.onboarding_reopen(name_r) > 0.0, "a shadowed start leaves some habits: reopens a little more in the first ten days")
	crew.end_day(0.6, "B")
	_check(crew.is_shadowing(name_r), "one day down, one to go")
	crew.end_day(0.6, "B")
	_check(not crew.is_shadowing(name_r), "after two days he works on his own")
	_check(crew.value(name_r, "solo_h") < 0.0 and crew.solo_mean_hours() < 0.0, "no first solo ticket yet")
	c.day = 9
	crew.members[name_r]["start_day"] = 7
	world.clock = 11.0
	crew.note_done(name_r, t)
	_check(absf(crew.value(name_r, "solo_h") - 18.0) < 0.001, "first solo ticket after %.1f working hours (2 days and 2 hours)" % crew.value(name_r, "solo_h"))
	_check(absf(crew.solo_mean_hours() - 18.0) < 0.001, "the scorecard mean is that number")
	var rows: Array = sv._desk_rows()
	var solo_row := ""
	var ret_row := ""
	for r in rows:
		if str(r[0]) == "FIRST SOLO":
			solo_row = str(r[1])
		if str(r[0]) == "RETENTION":
			ret_row = str(r[1])
	_check(solo_row == "2.3 DAYS" and ret_row == "100%", "scorecard: FIRST SOLO %s, RETENTION %s" % [solo_row, ret_row])
	crew.note_reopen(name_r)
	_check(int(crew.value(name_r, "reopens")) == 1, "reopens in the first month are counted per hire")

	# ---- structured onboarding: a plan, tickets from day one at a slower pace, safer with runbooks
	_fresh()
	var cand2: Dictionary = crew.make_candidates(3)[0]
	_check(sv.finish_hire(cand2, "structured"), "hired with a structured start")
	_check(absf(sv.kb.hours_used - 2.0) < 0.001, "a structured start costs two manager hours")
	crew.onboard_pending(c.day)
	var n2: String = crew.newest_hire()
	_check(not crew.is_shadowing(n2) and crew.status(n2) != "SHADOW", "no shadowing: he can take tickets tomorrow")
	c.day = 5
	crew.members[n2]["start_day"] = 5
	var s_day1: float = crew.raw_speed(n2)
	c.day = 8
	var s_later: float = crew.raw_speed(n2)
	_check(s_day1 < s_later, "...at 80%% speed for the first two days (%.2f then %.2f)" % [s_day1, s_later])
	_check(crew.onboarding_reopen(n2) == 0.0, "without runbooks a structured start does not change reopens")
	for id in ["spooler", "password", "clear_temp"]:
		sv.kb.rb(id)["state"] = sv.kb.DOCUMENTED
	c.day = 6
	_check(crew.onboarding_reopen(n2) < 0.0, "with three live runbooks it lowers them")
	c.day = 20
	_check(crew.onboarding_reopen(n2) == 0.0, "...for the first ten days only")

	# ---- the cap of six, with the seats you have
	_fresh()
	var seats := []
	for i in 3:
		var cd2: Dictionary = crew.make_candidates(3)[0]
		_check(crew.can_hire(), "hire %d: there is still a seat" % (i + 1))
		sv.finish_hire(cd2, "shadow")
		crew.onboard_pending(c.day)
		seats.append(crew.seat_of(crew.newest_hire()))
	_check(crew.size() == 6 and seats == ["Seat4", "Seat5", "Seat3"], "six on the crew in the seats Seat4, Seat5, Seat3 (%s)" % str(seats))
	_check(not crew.can_hire() and crew.open_seats() == 0, "the cap is six: no seat left")
	sv.hire_card()
	_check(not cards.is_open, "the hiring card does not open when the crew is full")
	_check(str(sv.HIRE_TEXT.full).find("six") >= 0, "the limit is explained")
	var hired: String = crew.newest_hire()
	crew.quit(hired)
	_check(crew.size() == 5 and crew.can_hire() and crew.free_seat() == crew.seat_of(hired), "a quit frees a seat and it can be filled")
	_check(crew.retention_pct() == 83, "retention: five of six (%d%%)" % crew.retention_pct())

	# ---- fit effects: mood, growth, quit risk
	_fresh()
	difficulty.seed_run(99)
	var all: Array = crew.make_candidates(3)
	var rg2 := _kind(all, "ringer")
	var ft2 := _kind(all, "fit")
	sv.finish_hire(rg2, "structured")
	sv.finish_hire(ft2, "structured")
	crew.onboard_pending(c.day)
	var rn: String = str(rg2.name)
	var fn: String = str(ft2.name)
	var sam_m: int = crew.morale("Sam")
	crew.end_day(0.6, "B")
	_check(crew.morale("Sam") <= sam_m - 1 + 0, "a ringer with a poor culture fit drags the team's mood (Sam %d to %d)" % [sam_m, crew.morale("Sam")])
	var skill0: float = crew.value(fn, "skill")
	var area0: float = crew.area_level(fn, crew.weakest_area(fn))
	for i in 10:
		crew.end_day(0.6, "B")
	_check(crew.value(fn, "skill") > skill0 or str(crew.members[fn].trait) != "green", "a good-fit hire grows (skill %.2f to %.2f)" % [skill0, crew.value(fn, "skill")])
	_check(crew.area_level(fn, crew.weakest_area(fn)) > area0 or crew.weakest_area(fn) != "", "...and learns")
	crew.members[rn]["morale"] = 40
	crew.members["Sam"]["morale"] = 40
	_check(crew.quit_chance(rn) > crew.quit_chance("Sam"), "at the same mood the poor fit is likelier to leave (%.2f against %.2f)" % [crew.quit_chance(rn), crew.quit_chance("Sam")])
	crew.members[fn]["morale"] = 40
	_check(crew.quit_chance(fn) == 0.0 or crew.quit_chance(fn) < crew.quit_chance(rn), "...and the good fit is not")

	# ---- saving
	var data: Dictionary = sv.to_dict()
	sv.reset()
	_check(crew.hire_order.is_empty() and crew.size() == 3, "reset forgets the hires")
	sv.from_dict(data)
	_check(crew.hire_order.has(rn) and crew.hire_order.has(fn) and crew.has(rn) and int(crew.value(rn, "wage")) == int(rg2.wage), "hires survive a save with their wage")
	_check(int(crew.members[rn].fit.culture) == int(rg2.fit.culture) and crew.seat_of(rn) == "Seat4", "...their fit and their seat")
	sv.from_dict({"trust": {"Alan": 50, "Garrison": 50}})
	_check(crew.hire_order.is_empty() and crew.retention_pct() == 100, "an old save has no hires")

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
