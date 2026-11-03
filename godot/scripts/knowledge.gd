extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# ConnectWhy Knowledge (service manager campaign, C6 / V3): the runbooks of the desk and the app that shows them.
# MODEL: one runbook per ticket class (the seven Msp ticket kinds) and per playbook job (rdp, ransom, rack, email24, migration).
# A runbook is NONE, DRAFT, DOCUMENTED or TRAINED. Writing costs your manager hours (Service.kb.hours_left, 3 a day, 5 with a
# dispatcher; a high PROCESS stat makes it cheaper and networking classes are cheaper still: Dan labels everything) and a tech's
# time (the author is away from the queue for an hour). A live DOCUMENTED runbook makes the whole crew faster and safer on that
# class and takes one level off the gap, so lower-level techs are not stuck any more. DOCUMENTED goes STALE when systems change
# (Service.CHANGES, or kb.system_change from anything else) and a refresh puts it right. TRAINED is a lesson (the senior's
# recording, a quiz you check, then sign-off on live tickets) and is permanent: it never goes stale. The bus factor: if the
# only tech who knew a class quits and it was not live, every tech is one level further from it (stuck for everyone) until
# someone learns it or it is documented. The documentation score (doc_pct) feeds the scorecard and Alan's trust.
# APP: tabs RUNBOOKS (paged list, one action button), DESK (the design and the dispatcher) and CREW (people, payroll, hiring,
# the training budget). Keys: Left / Right change tab, Up / Down pick, Enter does the next step, [ / ] page, H hires, T cycles
# the training budget. Everything is a public function so the tests can drive it; paint() only draws.

const NONE := 0
const DRAFT := 1
const DOCUMENTED := 2
const TRAINED := 3
const STATE_NAME := ["NONE", "DRAFT", "DOCUMENTED", "TRAINED"]
const SHORT_NAME := ["NONE", "DRAFT", "LIVE", "TRAINED"]
const BG := Color("eef1f6")
const HEAD := Color("2f6e5a")
const INK := Color("20242c")
const MUTED := Color("5a6372")
const TABS := [["books", "RUNBOOKS"], ["desk", "DESK"], ["crew", "CREW"]]

var runbooks := {}  # id -> {state, stale, signoff, senior, author, day, uses}
var hours_used := 0.0
var bus := {}  # class id -> the tech whose knowledge left
var view := "books"
var sel := 0
var msg := ""
var msg_at := -99999
var c: Node = null
var lesson_who := ""
var _crew_sel := 0


func _blank() -> Dictionary:
	return {"state": NONE, "stale": false, "signoff": 0, "senior": "", "author": "", "day": 0, "uses": 0}


func reset() -> void:
	runbooks = {}
	for id in ids():
		runbooks[id] = _blank()
	hours_used = 0.0
	bus = {}
	view = "books"
	sel = 0
	msg = ""
	lesson_who = ""
	_crew_sel = 0


func ids() -> Array:
	return Service.KB_ORDER


func rb(id: String) -> Dictionary:
	if not runbooks.has(id):
		runbooks[id] = _blank()
	return runbooks[id]


func state(id: String) -> int:
	return int(rb(id).state)


func is_live(id: String) -> bool:
	var s := state(id)
	return s == TRAINED or (s == DOCUMENTED and not bool(rb(id).stale))


func label(id: String) -> String:
	return str(Service.RUNBOOKS[id].label) if Service.RUNBOOKS.has(id) else id.to_upper()


func area_of(id: String) -> String:
	if Service.RUNBOOKS.has(id) and str(Service.RUNBOOKS[id].kind) == "job":
		return str(Service.RUNBOOKS[id].area)
	return str(Crew.FIX_AREA.get(id, "servers"))


func need_of(id: String) -> int:
	if Service.RUNBOOKS.has(id) and str(Service.RUNBOOKS[id].kind) == "job":
		return int(Service.RUNBOOKS[id].need)
	return int(Crew.FIX_NEED.get(id, 1))


func tag_of(id: String) -> String:
	return "%s%d" % [str(Crew.AREA_TAG[area_of(id)]), need_of(id)]


# the runbook class of a ticket ("" when it has none: incidents and projects)
func class_of(t: Dictionary) -> String:
	var fix := str(t.get("fix", ""))
	if Service.RUNBOOKS.has(fix) and str(Service.RUNBOOKS[fix].kind) == "ticket":
		return fix
	return ""


# ---- what a runbook does for the crew -----------------------------------------------------------------------------------
# levels taken off the ticket's gap (a live runbook: 1; the bus factor: -1, one more level out of reach for everybody)
func relief(t: Dictionary) -> float:
	var id := class_of(t)
	if id == "":
		return 0.0
	if is_live(id):
		return 1.0
	return -1.0 if bus.has(id) else 0.0


func speed(t: Dictionary) -> float:
	var id := class_of(t)
	if id == "":
		return 1.0
	match state(id):
		TRAINED:
			return 1.22
		DOCUMENTED:
			return 1.0 if bool(rb(id).stale) else 1.12
		DRAFT:
			return 1.03
	return 1.0


func safety(t: Dictionary) -> float:
	var id := class_of(t)
	if id == "":
		return 0.0
	match state(id):
		TRAINED:
			return -0.07
		DOCUMENTED:
			return 0.0 if bool(rb(id).stale) else -0.04
	return 0.0


# a runbook for a Playbook job helps whoever runs it without you (Service.delegate)
func job_bonus(book: String) -> float:
	if not runbooks.has(book):
		return 0.0
	match state(book):
		TRAINED:
			return 0.15
		DOCUMENTED:
			return 0.0 if bool(rb(book).stale) else 0.08
	return 0.0


func documented_count() -> int:
	var n := 0
	for id in ids():
		if is_live(str(id)):
			n += 1
	return n


# the documentation score: the share of classes with a live (not stale) runbook
func doc_pct() -> int:
	var total := ids().size()
	return int(round(100.0 * float(documented_count()) / float(maxi(1, total))))


# ---- hours --------------------------------------------------------------------------------------------------------------
func hours_total() -> float:
	return Service.manager_hours_total()


func hours_left() -> float:
	return maxf(0.0, hours_total() - hours_used)


func spend(h: float) -> bool:
	if h > hours_left() + 0.001:
		return false
	hours_used += h
	return true


# a high PROCESS makes runbooks cheap (Dan starts at 2)
func process_mult() -> float:
	return clampf(1.0 - 0.1 * float(Build.level("process") - 2), 0.7, 1.1)


# what the next step costs: {act, verb, dan, tech}. Dan's networking classes are half price: he labels everything.
func cost_of(id: String) -> Dictionary:
	var r := rb(id)
	var m := process_mult() * (0.5 if area_of(id) == "networking" else 1.0)
	var out := {"act": "none", "verb": "TRAINED", "dan": 0.0, "tech": 0.0}
	match state(id):
		NONE:
			out = {"act": "draft", "verb": "WRITE A DRAFT", "dan": 1.0 * m, "tech": 1.0}
		DRAFT:
			out = {"act": "publish", "verb": "PUBLISH IT", "dan": 1.0 * m, "tech": 0.0}
		DOCUMENTED:
			if bool(r.stale):
				out = {"act": "refresh", "verb": "REFRESH IT", "dan": 0.5 * m, "tech": 0.0}
			elif int(r.signoff) > 0:
				out = {"act": "wait", "verb": "SIGN-OFF %d MORE" % int(r.signoff), "dan": 0.0, "tech": 0.0}
			else:
				out = {"act": "train", "verb": "TRAIN THE CREW", "dan": 1.0 * m, "tech": 1.0}
	out["dan"] = snappedf(maxf(0.3, float(out.dan)), 0.1) if float(out.dan) > 0.0 else 0.0
	return out


# the tech who knows the class best and is free (the author of a draft, or the senior in a lesson); "" = nobody, Dan does it
func senior_for(id: String) -> String:
	var best := ""
	var best_v := -1.0
	for n in Crew.names():
		var w := str(n)
		if Crew.stuck.has(w) or Crew.is_shadowing(w) or Crew.busy(w):
			continue
		var v := Crew.area_level(w, area_of(id)) + 0.001 * Crew.value(w, "skill")
		if v > best_v:
			best_v = v
			best = w
	return best


func advance(id: String) -> Dictionary:
	if not runbooks.has(id):
		return {"ok": false, "msg": str(Service.KB_TEXT.msg.none)}
	var cost := cost_of(id)
	var act := str(cost.act)
	if act == "none":
		return {"ok": false, "msg": str(Service.KB_TEXT.msg.already)}
	if act == "wait":
		return {"ok": false, "msg": str(Service.KB_TEXT.msg.signoff) % int(rb(id).signoff)}
	if float(cost.dan) > hours_left() + 0.001:
		return {"ok": false, "msg": str(Service.KB_TEXT.msg.need) % [float(cost.dan), hours_left()]}
	var who := ""
	if float(cost.tech) > 0.0:
		who = senior_for(id)
	spend(float(cost.dan))
	if who != "":
		Crew.set_busy(who, float(cost.tech))
	var r := rb(id)
	var text := ""
	match act:
		"draft":
			r["state"] = DRAFT
			r["author"] = who if who != "" else "Dan"
			r["day"] = Campaign.day
			text = str(Service.KB_TEXT.msg.draft) % label(id)
		"publish":
			r["state"] = DOCUMENTED
			r["stale"] = false
			r["day"] = Campaign.day
			text = str(Service.KB_TEXT.msg.live) % label(id)
			if bus.has(id):
				bus.erase(id)
		"refresh":
			r["stale"] = false
			text = str(Service.KB_TEXT.msg.refresh) % label(id)
		"train":
			_lesson(id, who if who != "" else "Maya")
			text = str(Service.KB_TEXT.msg.signoff) % 2
	if act != "train":
		Hints.toast(text, 2.5)
	return {"ok": true, "msg": text, "act": act, "who": who}


# the lesson: the senior's recording, then a check you make before the trainee is signed off on live tickets
func _lesson(id: String, who: String) -> void:
	lesson_who = who
	var q: Dictionary = Service.RUNBOOKS[id].quiz
	var order := [0, 1, 2]
	var rng: RandomNumberGenerator = Difficulty.rng("service.kb")
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var opts := []
	for k in order:
		opts.append({"label": str(q.options[int(k)]), "id": str(k)})
	var text := str(Service.KB_TEXT.lesson.text) % [who, label(id), str(q.q)]
	Cards.ask("%s (Tier 1)" % who, text, opts, func(pick: String) -> void: quiz_pick(id, int(pick)))


# public so the tests can answer the quiz. Returns true when the lesson held up.
func quiz_pick(id: String, pick: int) -> bool:
	var q: Dictionary = Service.RUNBOOKS[id].quiz
	var ok := pick == int(q.answer)
	var who := lesson_who if lesson_who != "" else "Maya"
	if ok:
		rb(id)["signoff"] = 2
		rb(id)["senior"] = who
	var text := str(Service.KB_TEXT.lesson.good) % who if ok else str(Service.KB_TEXT.lesson.fail)
	Cards.ask("%s (Tier 1)" % who, text, [{"label": str(Service.KB_TEXT.lesson.ok), "id": "ok"}], func(_x: String) -> void: pass)
	return ok


# a live ticket of the class was closed properly: the sign-off counts, and the third makes it permanent
func note_closed(who: String, t: Dictionary) -> void:
	var id := class_of(t)
	if id == "" or not runbooks.has(id):
		return
	var r := rb(id)
	r["uses"] = int(r.uses) + 1
	if state(id) == DOCUMENTED and int(r.signoff) > 0 and who != str(r.senior):
		r["signoff"] = int(r.signoff) - 1
		if int(r.signoff) == 0:
			r["state"] = TRAINED
			r["stale"] = false
			Hints.toast(str(Service.KB_TEXT.msg.trained) % label(id), 3.0)


# ---- systems change, the bus factor -----------------------------------------------------------------------------------
# documented (not trained) runbooks on these classes go stale. Returns the ids that did.
func system_change(classes: Array, subject := "", body := "") -> Array:
	var hit := []
	for id in classes:
		var r := rb(str(id))
		if state(str(id)) == DOCUMENTED and not bool(r.stale):
			r["stale"] = true
			hit.append(str(id))
	if not hit.is_empty():
		var names := []
		for id in hit:
			names.append(label(str(id)))
		Msp.mail(str(Service.KB_TEXT.stale.from), subject if subject != "" else str(Service.KB_TEXT.stale.subject), "%s (%s) - Alan" % [body if body != "" else "Systems changed.", ", ".join(names)])
		Hints.toast(str(Service.KB_TEXT.msg.stale) % str(names[0]), 3.0)
	return hit


func capable(id: String) -> Array:
	var out := []
	for n in Crew.names():
		if Crew.level(str(n), area_of(id)) >= need_of(id):
			out.append(str(n))
	return out


# classes only one tech can do and nothing documents: the knowledge hotspots
func single_points() -> Array:
	var out := []
	for id in ids():
		if not is_live(str(id)) and capable(str(id)).size() <= 1:
			out.append(str(id))
	return out


# a tech quit (his flag is already gone): classes only he could do, with no live runbook, are now stuck for everybody
func on_quit(who: String) -> Array:
	var hit := []
	for id in ids():
		var s := str(id)
		if is_live(s) or not capable(s).is_empty():
			continue
		if Crew.level(who, area_of(s)) >= need_of(s):
			bus[s] = who
			hit.append(s)
	if not hit.is_empty():
		var names := []
		for s in hit:
			names.append(label(str(s)))
		Msp.mail(str(Service.KB_TEXT.bus.mail_from), str(Service.KB_TEXT.bus.subject), str(Service.KB_TEXT.bus.body) % [who, ", ".join(names)])
		Service.add_trust("Alan", -2)
		Hints.toast("%s: %s" % [str(Service.ROWS.bus), str(names[0])], 3.0)
	return hit


func begin_day(day: int) -> void:
	hours_used = 0.0
	for id in bus.keys():
		if is_live(str(id)) or not capable(str(id)).is_empty():
			bus.erase(id)
	var ch: Dictionary = Service.CHANGES.get(str(day), {})
	if not ch.is_empty():
		var live := []
		for id in ch.classes:
			if state(str(id)) == DOCUMENTED and not bool(rb(str(id)).stale):
				live.append(str(id))
		var rng: RandomNumberGenerator = Difficulty.rng("service.kb")
		var picks := []
		while not live.is_empty() and picks.size() < int(ch.get("pick", 1)):
			var i := rng.randi() % live.size()
			picks.append(live[i])
			live.remove_at(i)
		system_change(picks, str(ch.subject), str(ch.body))


# ---- saving -----------------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"rb": runbooks.duplicate(true), "hours": hours_used, "bus": bus.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("rb", {})
	for id in saved:
		if runbooks.has(id):
			for k in saved[id]:
				runbooks[id][k] = saved[id][k]
	hours_used = float(data.get("hours", 0.0))
	bus = data.get("bus", {}).duplicate()


# ---- the app: input ---------------------------------------------------------------------------------------------------
func say(text: String) -> void:
	msg = text
	msg_at = Time.get_ticks_msec()


func sel_id() -> String:
	var l := ids()
	return str(l[clampi(sel, 0, l.size() - 1)])


func set_view(v: String) -> void:
	view = v


func cycle_view(step: int) -> void:
	var order := ["books", "desk", "crew"]
	view = order[(order.find(view) + step + order.size()) % order.size()]


func do_advance() -> Dictionary:
	var res := advance(sel_id())
	say(str(res.msg))
	return res


func key(name: String) -> bool:
	match name:
		"left":
			cycle_view(-1)
		"right":
			cycle_view(1)
		"tab":
			cycle_view(1)
		"up":
			_move(-1)
		"down":
			_move(1)
		"pgup":
			_move(-per_page)
		"pgdn":
			_move(per_page)
		"enter", "w":
			if view == "books":
				do_advance()
			elif view == "desk":
				desk_action()
			else:
				hire_action()
		"h":
			hire_action()
		"t":
			say("TRAINING: " + str(Service.TRAINING[Service.cycle_training()].label))
		"r":
			view = "books"
		"d":
			view = "desk"
		"c":
			view = "crew"
		_:
			return false
	return true


var per_page := 6


func _move(step: int) -> void:
	if view == "books":
		sel = clampi(sel + step, 0, ids().size() - 1)
	elif view == "crew":
		_crew_sel = clampi(_crew_sel + step, 0, maxi(0, Crew.names().size() - 1))


func desk_action() -> void:
	if Service.design == "":
		Service.design_card(false)
	elif Service.can_change_design():
		Service.design_card(true)
	else:
		say(str(Service.DESIGNS.card.used) if Service.design_changes >= 1 else str(Service.DESIGNS.card.no_hours))


func hire_action() -> void:
	if not Crew.can_hire():
		say(str(Service.HIRE_TEXT.full))
		return
	Service.hire_card()


func act(parts: PackedStringArray) -> void:
	match parts[1]:
		"view":
			view = parts[2]
		"row":
			sel = int(parts[2])
		"go":
			do_advance()
		"page":
			_move(int(parts[2]) * per_page)
		"desk":
			desk_action()
		"hire":
			hire_action()
		"train":
			say("TRAINING: " + str(Service.TRAINING[Service.cycle_training()].label))
		"crew":
			_crew_sel = int(parts[2])


func back() -> bool:
	return false


func nested() -> bool:
	return false


# ---- the app: drawing -------------------------------------------------------------------------------------------------
func _state_color(id: String) -> Color:
	var s := state(id)
	if bus.has(id) and not is_live(id):
		return Color("d23c3c")
	if s == DOCUMENTED and bool(rb(id).stale):
		return Color("e0a030")
	return [Color("b4bcc9"), Color("e0a030"), Color("2fa84f"), Color("2b579a")][s]


func paint(computer: Node, body: Rect2) -> void:
	c = computer
	c._fill(body, BG)
	var narrow := body.size.x < 280.0
	var bar := Rect2(body.position, Vector2(body.size.x, 9))
	c._fill(bar, Color("cfe0d8"))
	var tw := 38.0 if not narrow else 28.0
	for i in TABS.size():
		var label_text: String = str(TABS[i][1])
		if narrow and i == 0:
			label_text = "BOOKS"
		var w := tw + (8.0 if i == 0 and not narrow else 0.0)
		var x := body.position.x + 2.0 + float(i) * (tw + 2.0) + (8.0 if i > 0 and not narrow else 0.0)
		c._button("kb:view:" + str(TABS[i][0]), Rect2(x, body.position.y + 1, w, 8), label_text, true, c.BTN_HI if view == TABS[i][0] else c.BTN)
	var hours_text := "HOURS %.1f/%.1f" % [hours_left(), hours_total()]
	if narrow:
		hours_text = "H %.1f/%.1f" % [hours_left(), hours_total()]
	c._text(hours_text, Vector2(body.end.x - c._tw(hours_text) - 3, body.position.y + 2), INK if hours_left() >= 1.0 else c.RED)
	var area := Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
	match view:
		"desk":
			_desk(area, narrow)
		"crew":
			_crew(area, narrow)
		_:
			_books(area, narrow)


func _footer(a: Rect2, h: float, text: String, chars: int) -> Rect2:
	var r := Rect2(a.position.x, a.end.y - h, a.size.x, h)
	c._fill(r, Color("cfe0d8"))
	var lines: Array = c._wrap(text, chars)
	for i in mini(int((h - 11.0) / 7.0), lines.size()):
		c._text(str(lines[i]), r.position + Vector2(2, 1 + i * 7), INK)
	return r


func info_for(id: String) -> String:
	var cost := cost_of(id)
	var parts := ["%s %s." % [tag_of(id), STATE_NAME[state(id)]]]
	if bool(rb(id).stale) and state(id) == DOCUMENTED:
		parts.append("OUT OF DATE.")
	if bus.has(id) and not is_live(id):
		parts.append("%s LEFT: STUCK FOR ALL." % str(bus[id]).to_upper())
	elif id in single_points():
		var who: Array = capable(id)
		parts.append("ONLY %s CAN DO IT." % (str(who[0]).to_upper() if not who.is_empty() else "NOBODY"))
	if str(cost.act) in ["draft", "publish", "refresh", "train"]:
		parts.append("%s: %.1fH OF YOURS%s." % [str(cost.verb), float(cost.dan), " AND 1H OF A TECH" if float(cost.tech) > 0.0 else ""])
	return " ".join(parts)


func _books(a: Rect2, narrow: bool) -> void:
	var list := ids()
	var row_h := 8.0 if not narrow else 10.0
	var foot_h := 19.0 if not narrow else 40.0
	var list_top := a.position.y + 8.0
	var list_h := a.size.y - 8.0 - foot_h
	per_page = maxi(1, int(list_h / row_h))
	sel = clampi(sel, 0, list.size() - 1)
	var page_n := sel / per_page
	var pages := int(ceil(float(list.size()) / float(per_page)))
	c._text("CLASS", Vector2(a.position.x + 9, a.position.y + 1), MUTED)
	if not narrow:
		c._text("LEVEL", Vector2(a.position.x + a.size.x * 0.42, a.position.y + 1), MUTED)
		c._text("STATE", Vector2(a.position.x + a.size.x * 0.55, a.position.y + 1), MUTED)
	var score := "DOC %d%%" % doc_pct()
	c._text(score, Vector2(a.position.x + (a.size.x * 0.76 if not narrow else 52.0), a.position.y + 1), INK)
	if pages > 1:
		c._button("kb:page:-1", Rect2(a.end.x - 30, a.position.y, 9, 8), "<", page_n > 0)
		c._text("%d/%d" % [page_n + 1, pages], Vector2(a.end.x - 20, a.position.y + 1), MUTED)
		c._button("kb:page:1", Rect2(a.end.x - 9, a.position.y, 8, 8), ">", page_n < pages - 1)
	var first := page_n * per_page
	for k in range(first, mini(list.size(), first + per_page)):
		var id := str(list[k])
		var r := Rect2(a.position.x, list_top + float(k - first) * row_h, a.size.x, row_h - 1)
		c._fill(r, Color("c7e3d5") if k == sel else (c.WHITE if k % 2 == 0 else Color("eef3f9")))
		c._region("kb:row:%d" % k, r)
		c._fill(Rect2(r.position.x + 2, r.position.y + 1, 4, r.size.y - 2), _state_color(id))
		var name_chars := int((a.size.x * 0.4) / 4.0) if not narrow else int((a.size.x - 60.0) / 4.0)
		c._text(c._clip(label(id), name_chars), r.position + Vector2(9, 1 if not narrow else 2), INK)
		var st: String = SHORT_NAME[state(id)]
		var flag := ""
		if bus.has(id) and not is_live(id):
			flag = "STUCK"
		elif state(id) == DOCUMENTED and bool(rb(id).stale):
			flag = "STALE"
		elif state(id) == DOCUMENTED and int(rb(id).signoff) > 0:
			flag = "SIGN %d" % int(rb(id).signoff)
		elif id in single_points():
			flag = "RISK"
		if narrow:
			c._text(flag if flag != "" else st, Vector2(r.end.x - 4 * (flag if flag != "" else st).length() - 3, r.position.y + 2), c.RED if flag in ["STUCK", "RISK"] else (c.AMBER if flag != "" else INK))
		else:
			c._text(tag_of(id), Vector2(a.position.x + a.size.x * 0.42, r.position.y + 1), Color("1f4e8c"))
			c._text(st, Vector2(a.position.x + a.size.x * 0.55, r.position.y + 1), INK)
			if flag != "":
				c._text(flag, Vector2(a.position.x + a.size.x * 0.76, r.position.y + 1), c.RED if flag in ["STUCK", "RISK"] else c.AMBER)
	var chars := int((a.size.x - 4.0) / 4.0)
	var foot := _footer(a, foot_h, info_for(sel_id()), chars)
	var cost := cost_of(sel_id())
	var go_label := "%s (ENTER)" % str(cost.verb)
	if narrow:
		go_label = str(cost.verb)
	var can := str(cost.act) in ["draft", "publish", "refresh", "train"]
	c._button("kb:go", Rect2(foot.position.x + 2, foot.end.y - 10, minf(foot.size.x - 4.0, c._tw(go_label) + 10.0), 9), go_label, can, Color("b8e0c8") if can else c.BTN)
	if Time.get_ticks_msec() - msg_at < 3500 and msg != "":
		var note: String = c._clip(msg, int((foot.size.x - c._tw(go_label) - 20.0) / 4.0))
		c._text(note, Vector2(foot.position.x + c._tw(go_label) + 14.0, foot.end.y - 8), INK)


func _desk(a: Rect2, narrow: bool) -> void:
	var chars := int((a.size.x - 6.0) / 4.0)
	var y := a.position.y + 2.0
	var d: Dictionary = Service.DESIGNS.get(Service.design, {})
	var title := "DESK: " + (str(d.label) if not d.is_empty() else str(Service.ROWS.none))
	c._text(title, Vector2(a.position.x + 3, y), HEAD)
	y += 8.0
	var disp := "DISPATCHER: " + ("HIRED ($%d A WEEK)" % Service.DISPATCHER_WAGE if Service.dispatcher else "YOU (MANAGER HOURS %.1f)" % hours_total())
	c._text(c._clip(disp, chars), Vector2(a.position.x + 3, y), INK)
	y += 9.0
	var text := str(d.text) if not d.is_empty() else str(Service.DESIGNS.card.text)
	var lines: Array = c._wrap(text, chars)
	var max_lines := int((a.end.y - y - 24.0) / 7.0)
	for i in mini(max_lines, lines.size()):
		c._text(str(lines[i]), Vector2(a.position.x + 3, y + float(i) * 7.0), INK)
	y += float(mini(max_lines, lines.size())) * 7.0 + 2.0
	var extra := ""
	match Service.design:
		"swarm":
			extra = "MIS-ALLOCATED %d" % Service.misallocated
		"pods":
			extra = "PODS: " + "  ".join(PackedStringArray(_pod_lines()))
		"tiered":
			extra = "LANES: " + "  ".join(PackedStringArray(_lane_lines()))
	if extra != "" and y < a.end.y - 22.0:
		c._text(c._clip(extra, chars), Vector2(a.position.x + 3, y), MUTED)
	var bottom := Rect2(a.position.x, a.end.y - 12, a.size.x, 12)
	c._fill(bottom, Color("cfe0d8"))
	var label_text := "CHOOSE THE DESK"
	var can := true
	if Service.design != "":
		label_text = "CHANGE THE DESK (2H, ONCE)"
		can = Service.can_change_design()
	if narrow:
		label_text = label_text.replace(" (2H, ONCE)", "")
	c._button("kb:desk", Rect2(bottom.position.x + 2, bottom.position.y + 1, c._tw(label_text) + 10.0, 10), label_text, can, Color("b8e0c8") if can else c.BTN)
	if Time.get_ticks_msec() - msg_at < 3500 and msg != "":
		c._text(c._clip(msg, int((a.size.x - c._tw(label_text) - 20.0) / 4.0)), Vector2(bottom.position.x + c._tw(label_text) + 14.0, bottom.position.y + 4), INK)


func _lane_lines() -> Array:
	var out := []
	for tag in ["L1", "L2"]:
		var names := []
		for n in Crew.names():
			if Service.lane_of(str(n)) == tag:
				names.append(str(n).to_upper())
		out.append("%s %s" % [tag, " ".join(PackedStringArray(names))])
	return out


func _pod_lines() -> Array:
	var out := []
	for n in Crew.names():
		var p := Service.pod_text(str(n))
		if p != "":
			out.append("%s %s" % [str(n).to_upper(), p])
	return out


func _crew(a: Rect2, narrow: bool) -> void:
	var names := Crew.names()
	_crew_sel = clampi(_crew_sel, 0, maxi(0, names.size() - 1))
	var y := a.position.y + 1.0
	var head := "NAME   LANE  WAGE  MORALE  STATE" if not narrow else "NAME  LANE  WAGE  MOOD"
	c._text(head, Vector2(a.position.x + 3, y), MUTED)
	y += 7.0
	var rh := 8.0 if not narrow else 10.0
	for i in names.size():
		var who := str(names[i])
		var r := Rect2(a.position.x, y, a.size.x, rh - 1)
		c._fill(r, Color("c7e3d5") if i == _crew_sel else (c.WHITE if i % 2 == 0 else Color("eef3f9")))
		c._region("kb:crew:%d" % i, r)
		c._text(who.to_upper(), r.position + Vector2(3, 1 if not narrow else 2), INK)
		var x := a.position.x + (36.0 if not narrow else 34.0)
		c._text(Service.lane_of(who) if Service.design == "tiered" else "-", Vector2(x, r.position.y + (1 if not narrow else 2)), Color("1f4e8c"))
		x += 18.0
		c._text("$%d" % int(Crew.value(who, "wage")), Vector2(x, r.position.y + (1 if not narrow else 2)), INK)
		x += 26.0
		c._text("%d" % Crew.morale(who), Vector2(x, r.position.y + (1 if not narrow else 2)), c.GREEN if Crew.morale(who) >= 60 else (c.RED if Crew.morale(who) < 40 else c.AMBER))
		x += 20.0
		var st := Crew.status(who)
		if not narrow:
			c._text(st, Vector2(x, r.position.y + 1), c.RED if st in ["STUCK", "OVERLOAD"] else INK)
			if Crew.is_hire(who):
				var f: Dictionary = Crew.members[who].fit
				c._text("FIT %d/%d/%d" % [int(f.get("culture", 3)), int(f.get("comm", 3)), int(f.get("curiosity", 3))], Vector2(x + 44, r.position.y + 1), MUTED)
		y += rh
	var sums := "PAYROLL $%d A WEEK  SEATS %d/%d" % [Service.weekly_cost(), names.size(), Crew.MAX_CREW]
	if narrow:
		c._text(c._clip("PAYROLL $%d/WK" % Service.weekly_cost(), 40), Vector2(a.position.x + 3, y + 2), INK)
		c._text("SEATS %d/%d  COST %s/TICKET" % [names.size(), Crew.MAX_CREW, ("$%d" % Service.cost_per_ticket()) if Service.cost_per_ticket() >= 0 else "-"], Vector2(a.position.x + 3, y + 9), INK)
	else:
		c._text(sums, Vector2(a.position.x + 3, y + 2), INK)
		c._text(("$%d A TICKET" % Service.cost_per_ticket()) if Service.cost_per_ticket() >= 0 else "NO TICKETS CLOSED", Vector2(a.position.x + a.size.x * 0.62, y + 2), INK)
	var bottom := Rect2(a.position.x, a.end.y - 12, a.size.x, 12)
	c._fill(bottom, Color("cfe0d8"))
	var hire_label := "HIRE (H)" if Crew.can_hire() else "FULL"
	c._button("kb:hire", Rect2(bottom.position.x + 2, bottom.position.y + 1, 40, 10), hire_label, Crew.can_hire(), Color("b8e0c8") if Crew.can_hire() else c.BTN)
	var tl := "TRAINING: " + str(Service.TRAINING[Service.training].label)
	if narrow:
		tl = "TRAIN: " + str(Service.TRAINING[Service.training].label).split(" ")[0]
	c._button("kb:train", Rect2(bottom.position.x + 46, bottom.position.y + 1, minf(bottom.size.x - 48.0, c._tw(tl) + 8.0), 10), c._clip(tl, int((bottom.size.x - 56.0) / 4.0)), true)
	if Time.get_ticks_msec() - msg_at < 3500 and msg != "" and not narrow:
		pass
