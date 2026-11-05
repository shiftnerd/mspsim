extends RefCounted
# R37: business email compromise (wire fraud) and the post-incident review. A static helper (no state of its own):
# the owner campaign keeps its numbers in Owner.flags (saved with the campaign), the tech campaign in Story.flags.
#   Owner: a client is hit by a spoofed boss email. Weekly exposure roll from week 12 (after the scare card): the
#   call-back rule, the hosted email filter service and a good review each make a hit less likely. Cards are in
#   Owner.CARDS (bec_*, pm_*), so the text is editable in story/strings.txt.
#   Tech: Story.POSTMORTEMS (Morgan runs a blameless review: what happened, the root cause, two action items).
# Everything here is 2013-14: phone calls, a hosted spam filter, a funds transfer fraud rider on a crime policy.

const Habits := preload("res://scripts/habits.gd")  # R38: signed forms, unique logins and written OK make a scam harder
const FILTER := "mailfilter"  # the recurring service (Projects.SERVICES)
const FIRST_WEEK := 13
const BASE := 0.035  # chance per client per week that a scammer tries
const MAX_LOSSES := 2
const GAP := 2  # weeks between losses
const SHARE := 0.4  # the share of a client's loss you credit
const PM_DONE := 0.6  # a held review: the same class of incident is this much less likely (check variant: 0.5)
const PM_SKIP := 1.15  # a skipped review repeats the mistake
# what has to have happened before a tech review makes sense (Story.flags set when the job or ticket is finished)
const HAPPENED := {"ransom": "ransom", "rack": "rack", "email": "email24", "bec": "ceofraud"}
const MORGAN := "Morgan Reyes (Manager)"


# ---- owner campaign: wire fraud ----------------------------------------------------------------------------
static func armed() -> bool:
	return Campaign.mode == "owner" and Owner.flags.has("card_bec_scare") and Campaign.day >= FIRST_WEEK


# a scammer tries this client this week
static func attempt_chance(client: int) -> float:
	var p := BASE
	if Owner.flags.get("bec_ignored", false):
		p *= 1.5
	if Sales.mood(client) < 40:
		p *= 1.4
	return p


# the share of attempts that get through (the rest are caught by a call-back or the filter)
static func miss_share(client: int) -> float:
	var miss := 1.0
	if Owner.flags.get("bec_policy", false):
		miss *= 0.25
	elif Owner.flags.get("bec_self_check", false):
		miss *= 0.7
	if Projects.has_service(client, FILTER):
		miss *= 0.5
	return miss * lesson_mult("bec") * Habits.bec_mult()


# the sum over clients: what the weekly report calls the wire fraud risk
static func exposure() -> float:
	var total := 0.0
	for c in Sales.active:
		total += attempt_chance(int(c)) * miss_share(int(c))
	return total


static func risk_word() -> String:
	var e := exposure()
	return "HIGH" if e >= 0.15 else ("MEDIUM" if e >= 0.05 else "LOW")


static func losses() -> int:
	return int(Owner.flags.get("bec_losses", 0))


# {client} and {amount} in card text: the client in the story (picked when the scare card opens) and the sum
static func fill(body: String) -> String:
	if not body.contains("{client}") and not body.contains("{amount}"):
		return body
	if not Owner.flags.has("bec_client") or not Sales.active.has(int(Owner.flags.bec_client)):
		if Sales.active.is_empty():
			return body
		Owner.flags["bec_client"] = int(Sales.active[randi() % Sales.active.size()])
		Owner.flags["bec_amount"] = 4000 + 500 * (randi() % 21)
	var name: String = str(Msp.CLIENTS[int(Owner.flags.bec_client)].name)
	return body.replace("{client}", name).replace("{amount}", Owner.money(int(Owner.flags.get("bec_amount", 8000))))


static func credit_amount() -> int:
	return int(round(float(Owner.flags.get("bec_amount", 8000)) * SHARE / 50.0)) * 50


# called by Owner.settle once a week
static func week() -> void:
	if not armed():
		return
	for c in Sales.active.duplicate():
		if randf() >= attempt_chance(int(c)):
			continue
		var can_hit := losses() < MAX_LOSSES and Campaign.day - int(Owner.flags.get("bec_last", -9)) >= GAP
		if randf() < miss_share(int(c)) and can_hit:
			_hit(int(c))
		else:
			_caught(int(c))
		return  # one event a week


static func _caught(client: int) -> void:
	Sales.adjust(client, 3)
	Owner.flags["bec_caught"] = int(Owner.flags.get("bec_caught", 0)) + 1
	var msg := "%s CAUGHT A FAKE WIRE REQUEST." % str(Msp.CLIENTS[client].name).to_upper()
	Msp.send_text("Marge", "%s They called back before paying. Nothing lost." % msg)
	Hints.toast(msg, 4.0)


static func _hit(client: int) -> void:
	Owner.flags["bec_client"] = client
	Owner.flags["bec_amount"] = 4000 + 500 * (randi() % 21)
	Owner.flags["bec_losses"] = losses() + 1
	Owner.flags["bec_last"] = Campaign.day
	Owner.apply({"mood": {str(client): -12}})
	var queue: Array = Owner.flags.get("inc_queue", [])
	queue.append("bec_loss")
	if not Owner.flags.get("bec_rider", false) and not Owner.flags.get("bec_rider_asked", false):
		queue.append("bec_rider")
	if not Owner.flags.has("pm_bec"):
		queue.append("pm_bec")
	Owner.flags["inc_queue"] = queue


# the next morning: one queued card a day (Owner.begin_day)
static func morning() -> void:
	var queue: Array = Owner.flags.get("inc_queue", [])
	if queue.is_empty():
		return
	var id := str(queue.pop_front())
	Owner.flags["inc_queue"] = queue
	if id == "bec_rider":
		Owner.flags["bec_rider_asked"] = true
	Owner.show_card(id)


# the fx key "bec" in a card option
static func owner_fx(kind: String) -> void:
	var client := int(Owner.flags.get("bec_client", -1))
	var key := str(client)
	match kind:
		"policy":
			_policy()
		"filter":
			sell_filter(client)
		"both":
			_policy()
			sell_filter(client)
		"ignore":
			Owner.flags["bec_ignored"] = true
		"self_check":
			Owner.flags["bec_self_check"] = true
			Owner.flags["practice_callback"] = true
		"credit":
			Owner.apply({"cash": -credit_amount(), "mood": {key: 6}})
			if Sales.active.has(client) and not Projects.has_service(client, FILTER):
				Projects.sell_service(client, FILTER)
		"lawyer":
			var odds := 0.8 if Owner.flags.get("bec_policy", false) else 0.5
			if randf() < odds:
				Owner.apply({"mood": {key: -3}})
				Owner.show_card("bec_lawyer_ok")
			else:
				var half := int(float(Owner.flags.get("bec_amount", 8000)) * 0.5)
				Owner.apply({"cash": -half, "rep": -3, "mood": {key: -10}})
				Owner.show_card("bec_lawyer_bad")
		"claim":
			var odds2 := 0.7 if Owner.flags.get("bec_rider", false) else 0.3
			if randf() < odds2:
				Owner.apply({"cash": -int(credit_amount() / 5), "mood": {key: 5}})
				Owner.show_card("bec_claim_ok")
			else:
				Owner.apply({"cash": -credit_amount(), "mood": {key: 2}})
				Owner.show_card("bec_claim_no")
		"blame":
			Owner.apply({"rep": -3, "mood": {key: -18}})
			if Sales.active.has(client) and randf() < 0.4:
				Owner.drop_client(client, "")
				Owner.show_card("bec_blame_left")
			else:
				Owner.show_card("bec_blame_stay")
		"rider":
			Owner.flags["bec_rider"] = true
			Owner.weekly_extra += 30


static func _policy() -> void:
	Owner.flags["bec_policy"] = true
	Owner.flags["practice_callback"] = true
	Owner.apply({"mood_all": 1, "owner_hours": 4})


# the hosted email filter: the client in the story signs, the others by mood. Returns how many signed.
static func sell_filter(victim := -1, everyone := true) -> int:
	var n := 0
	for c in Sales.active.duplicate():
		if Projects.has_service(int(c), FILTER):
			continue
		var yes := int(c) == victim or (everyone and randf() < 0.35 + float(Sales.mood(int(c))) / 250.0)
		if yes:
			Projects.sell_service(int(c), FILTER)
			n += 1
	if n > 0:
		Hints.toast("%d CLIENTS SIGNED FOR THE EMAIL FILTER." % n, 4.0)
	return n


# ---- post-incident review: owner side ----------------------------------------------------------------------
# the fx key "pm": [class, how] with how = runbook / check / skip
static func owner_review(cls: String, how: String) -> void:
	Owner.flags["pm_" + cls] = how
	if how == "skip":
		return
	Owner.flags["practice_postmortem"] = true
	if cls == "rack":
		Owner.speed += 0.03  # a labelled, photographed rack is quicker to fix next time


# 1.0 without a review, PM_DONE (0.5 for the check variant) after one, PM_SKIP when it was skipped
static func lesson_mult(cls: String) -> float:
	match str(Owner.flags.get("pm_" + cls, "")):
		"runbook":
			return PM_DONE
		"check":
			return 0.5
		"skip":
			return PM_SKIP
	return 1.0


# ---- tech campaign: Morgan's blameless review ---------------------------------------------------------------
static func tech_ready(cls: String) -> bool:
	return Story.flags.has(str(HAPPENED.get(cls, cls)))


# a review event fired: run it now, or wait until the incident has happened (Year 2 moves the big jobs around)
static func tech_start(cls: String) -> void:
	if str(Story.flags.get("pm_" + cls, "")) != "":
		return
	if not tech_ready(cls):
		var wait: Array = Story.flags.get("pm_wait", [])
		if not wait.has(cls):
			wait.append(cls)
		Story.flags["pm_wait"] = wait
		return
	_tech_open(cls)


# each morning after 9:40 (Story._spawn_followups): reviews that were waiting for their incident
static func tech_morning() -> void:
	var wait: Array = Story.flags.get("pm_wait", [])
	for cls in wait.duplicate():
		if tech_ready(str(cls)):
			wait.erase(cls)
			Story.flags["pm_wait"] = wait
			_tech_open(str(cls))
			return


static func _tech_open(cls: String) -> void:
	var pm: Dictionary = Story.POSTMORTEMS.get(cls, {})
	if pm.is_empty():
		return
	Story.flags["pm_" + cls] = "open"
	Cards.ask(
		MORGAN,
		str(pm.intro),
		[{"label": str(pm.go), "id": "go"}, {"label": str(pm.skip), "id": "skip"}],
		func(pick: String) -> void: _tech_intro(cls, pick)
	)


static func _tech_intro(cls: String, pick: String) -> void:
	var pm: Dictionary = Story.POSTMORTEMS[cls]
	if pick == "skip":
		Story.flags["pm_" + cls] = "skip"
		Social.change("Morgan", -2)
		Cards.ask(MORGAN, str(pm.skipped), [{"label": "OK", "id": "ok"}], func(_p: String) -> void: pass)
		return
	World.clock += 0.5  # half an hour in the conference room
	var options := []
	for cause in pm.causes:
		options.append({"label": str(cause.label), "id": str(cause.id)})
	Cards.ask(MORGAN, str(pm.cause_q), options, func(id: String) -> void: _tech_cause(cls, id))


static func _tech_cause(cls: String, id: String) -> void:
	var pm: Dictionary = Story.POSTMORTEMS[cls]
	var note := ""
	for cause in pm.causes:
		if str(cause.id) != id:
			continue
		note = str(cause.note)
		if bool(cause.get("right", false)):
			Story.flags["pm_cause"] = int(Story.flags.get("pm_cause", 0)) + 1
			Skills.add_xp(str(pm.skill), 6)
			Social.change("Morgan", 1)
		elif id == "person":
			Social.change("Morgan", -1)  # a blameless review does not name a person
	Cards.ask(
		MORGAN,
		note + " " + str(pm.items_q),
		_item_options(pm, []),
		func(pick: String) -> void: _tech_item(cls, [], pick)
	)


static func _item_options(pm: Dictionary, taken: Array) -> Array:
	var options := []
	for item in pm.items:
		if not taken.has(str(item.id)):
			options.append({"label": str(item.label), "id": str(item.id)})
	if not taken.is_empty():
		options.append({"label": str(pm.enough), "id": "enough"})
	return options


static func _tech_item(cls: String, taken: Array, pick: String) -> void:
	var pm: Dictionary = Story.POSTMORTEMS[cls]
	var now := taken.duplicate()
	var note := ""
	if pick != "enough":
		now.append(pick)
		for item in pm.items:
			if str(item.id) == pick:
				note = str(item.note)
	if pick == "enough" or now.size() >= 2:
		_tech_close(cls, now, note)
		return
	Cards.ask(
		MORGAN,
		note + " " + str(pm.more_q),
		_item_options(pm, now),
		func(next: String) -> void: _tech_item(cls, now, next)
	)


static func _tech_close(cls: String, taken: Array, last_note: String) -> void:
	var pm: Dictionary = Story.POSTMORTEMS[cls]
	for item in pm.items:
		if taken.has(str(item.id)):
			_tech_effect(str(item.eff), pm)
			Story.flags["pm_" + str(item.id)] = true
	Story.flags["pm_" + cls] = "done"
	Social.change("Morgan", 2 if not taken.is_empty() else 0)
	Cards.ask(
		MORGAN,
		(last_note + " " + str(pm.done)).strip_edges(),
		[{"label": "OK", "id": "ok"}],
		func(_p: String) -> void: pass
	)


# immediate effects happen now; the rest are flags other scripts read (pm_has)
static func _tech_effect(eff: String, pm: Dictionary) -> void:
	Story.flags["pm_eff_" + eff] = true
	match eff:
		"xp":
			var skill := str(pm.skill)
			Skills.add_xp(skill, 8)
			if Growth.esc_skill.has(skill):
				Growth.esc_skill[skill] = maxi(0, int(Growth.esc_skill[skill]) - 2)  # one gap less to close
		"calm":
			Social.change_all(1)
		"mood":
			for c in Sales.active:
				Sales.adjust(int(c), 2)


static func pm_has(eff: String) -> bool:
	return Campaign.mode == "tech" and bool(Story.flags.get("pm_eff_" + eff, false))


# read by Msp.new_day: the chance a backup quietly fails overnight
static func backup_fail_chance() -> float:
	return 0.04 if pm_has("backups") else 0.08


# read by Growth.fail_adjust: a runbook makes fixes a little safer
static func fix_bonus() -> float:
	return -0.03 if pm_has("fixes") else 0.0


# read by Msp.next_spawn_gap: patch policy and monitoring mean a few fewer tickets
static func ticket_gap() -> float:
	return 1.05 if pm_has("pace") else 1.0
