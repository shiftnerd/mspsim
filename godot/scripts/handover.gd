extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# The handover scene (sales campaign, roadmap C2): after a win Morgan and Dan sit down in the conference room (the real Conference
# scene, World.send_to_meeting) and you go through the promise list with them. Each promise is KEPT (Dan plans for it, half the gap
# stays as load), RENEGOTIATED (you tell the client the real terms: no gap, a little goodwill spent) or DROPPED (nobody tells the
# client: the whole gap stays and the client still expects it). What is left of the gap becomes the new client's starting mood and
# the service risk that feeds the churn meter. Dan and Morgan answer with bubbles and a short card. If you never walk in, the next
# Monday the paperwork is sent over and everything counts as dropped.

const Deals := preload("res://scripts/deals.gd")
const KEEP_FACTOR := 0.5
const RENEG_MOOD := 3
const START_MOOD := 72


static func pending() -> Dictionary:
	if SalesCampaign.pending_handover == 0:
		return {}
	return Deals.book_deal(SalesCampaign.pending_handover)


# the win has been thanked: call the meeting
static func queue(deal: Dictionary) -> void:
	deal["state"] = "handover"
	if SalesCampaign.pending_handover != 0:
		SalesCampaign.handover_queue.append(int(deal.id))  # one meeting at a time
		return
	SalesCampaign.pending_handover = int(deal.id)
	_call_team()
	_objective()
	if Meeting.in_conference():
		start(deal)


static func _call_team() -> void:
	if not (World.chars.has("Morgan") and World.chars.has("Dan")):
		return
	World.send_to_meeting("Morgan", "Seat3", 150.0)
	World.send_to_meeting("Dan", "Seat4", 150.0)


static func _objective() -> void:
	if not SalesCampaign.bell_ready:
		Hints.objective = "HANDOVER: JOIN MORGAN AND DAN IN THE CONFERENCE ROOM"


static func clear_objective() -> void:
	if Hints.objective.begins_with("HANDOVER"):
		Hints.objective = ""


# polled by SalesCampaign: you walked into the conference room with a handover waiting
static func tick() -> void:
	var d := pending()
	if d.is_empty():
		SalesCampaign.pending_handover = 0
		return
	if Cards.is_open or DayReport.is_open:
		return
	if Meeting.in_conference():
		start(d)


static func start(deal: Dictionary) -> void:
	SalesCampaign.pending_handover = 0
	clear_objective()
	var list: Array = deal.get("promises", [])
	if list.is_empty():
		finish(deal, false)
		return
	Cards.ask(
		"{ops}",
		"Handover for %s with Dan and me. $%d a week. You made %d promises; we go through them one by one. Keep it, renegotiate it with the client, or drop it.%s" % [str(deal.name), int(deal.mrr), list.size(), SalesCampaign.SalesRival.takeover_line(deal)],
		[{"label": "LET'S GO THROUGH THE LIST", "id": "go"}],
		func(_id: String) -> void: ask_promise(deal, 0)
	)


static func promise_text(deal: Dictionary, i: int) -> String:
	var list: Array = deal.promises
	var p: Dictionary = list[i]
	var g: float = float(p.gap)
	var dan := "Dan: that one is easy." if g < 0.3 else ("Dan: tight, but I can plan for it." if g < 1.0 else "Dan: I do not have the people for that one.")
	return "Promise %d of %d, %s: %s (gap %.1f). %s" % [i + 1, list.size(), str(p.kind).to_lower(), str(p.label), g, dan]


static func ask_promise(deal: Dictionary, i: int) -> void:
	var list: Array = deal.promises
	if i >= list.size():
		finish(deal, true)
		return
	var p: Dictionary = list[i]
	var g: float = float(p.gap)
	Cards.ask(
		"{ops}",
		promise_text(deal, i),
		[
			{"label": "KEEP IT: DAN PLANS FOR IT", "id": "kept"},
			{"label": "RENEGOTIATE: TELL THEM THE REAL TERMS", "id": "renegotiated"},
			{"label": "DROP IT AND SAY NOTHING", "id": "dropped"},
		],
		func(id: String) -> void:
			decide(deal, i, id)
			_react(id, g)
			ask_promise(deal, i + 1)
	)


# one promise's outcome: what is left of its gap
static func decide(deal: Dictionary, i: int, how: String) -> void:
	var p: Dictionary = deal.promises[i]
	p["state"] = how
	var g: float = float(p.gap)
	match how:
		"kept":
			p["left"] = snappedf(g * KEEP_FACTOR, 0.1)
		"renegotiated":
			p["left"] = 0.0
		_:
			p["left"] = g


# the whole list at once (the old three-answer handover maps onto this)
static func decide_all(deal: Dictionary, how: String) -> void:
	for i in deal.get("promises", []).size():
		decide(deal, i, how)


# turn the outcomes into the client's starting mood and the service risk
static func finish(deal: Dictionary, show_card: bool) -> void:
	var left := 0.0
	var kept := 0
	var reneg := 0
	var dropped := 0
	var heavy_kept := false
	var heavy_dropped := false
	for p in deal.get("promises", []):
		left += float(p.get("left", p.gap))
		match str(p.state):
			"kept":
				kept += 1
				heavy_kept = heavy_kept or float(p.gap) >= 0.5
			"renegotiated":
				reneg += 1
			"dropped":
				dropped += 1
				heavy_dropped = heavy_dropped or float(p.gap) >= 0.5
	left = snappedf(left, 0.1)
	deal["gap"] = left
	deal["mood"] = clampi(START_MOOD - int(round(left * 8.0)) - RENEG_MOOD * reneg, 25, 85)
	deal["complain"] = left >= 0.5
	deal["resolved"] = false
	deal["churn"] = clampi(int(round(10.0 + 12.0 * left + 4.0 * float(dropped))), 0, 100)
	deal["mood"] = clampi(int(deal.mood) + SalesCampaign.SalesRival.mood_adjust(deal), 25, 90)
	deal["churn"] = clampi(int(deal.churn) + SalesCampaign.SalesRival.churn_adjust(deal), 0, 100)
	deal["state"] = "active"
	deal["onboarded"] = false
	deal["onboard_due"] = int(deal.week) + int(Deals.ONBOARD[str(deal.get("onboard", "std"))].weeks)
	deal["delays"] = 0
	if reneg > 0:
		Social.change("Morgan", 1)
		Social.change("Dan", 1)
	if heavy_kept:
		Social.change("Dan", 1)
	if heavy_dropped:
		Social.change("Dan", -1)
	var l: Dictionary = SalesCampaign.lead_by_id(int(deal.id))
	if not l.is_empty():
		l["promises"] = deal.get("promises", [])
		Deals.note(l, "HANDOVER: GAP %.1f, MOOD %d" % [left, int(deal.mood)])
	SalesCampaign.handovers += 1
	if show_card:
		var line := (
			"That I can work with. I will label the tickets and %s goes live on schedule." % str(deal.name)
			if left < 0.5
			else (
				"It is tight, %s will notice. Please do not promise more than this." % str(deal.name)
				if left < 1.5
				else "I cannot staff that. Expect %s to call you before the month is out." % str(deal.name)
			)
		)
		Cards.ask(
			"Dan (Network Tech)",
			"%s Starting mood %d%%, service risk %.1f." % [line, int(deal.mood), left],
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: _react("done", left)
		)
	_next()
	SalesCampaign.changed.emit()


# the next win in line gets its meeting
static func _next() -> void:
	if SalesCampaign.pending_handover != 0 or SalesCampaign.handover_queue.is_empty():
		return
	SalesCampaign.pending_handover = int(SalesCampaign.handover_queue.pop_front())
	_call_team()
	_objective()


# nobody went to the conference room: the signed paperwork goes over and every promise is dropped
static func paperwork(deal: Dictionary) -> void:
	if SalesCampaign.pending_handover == int(deal.id):
		SalesCampaign.pending_handover = 0
	clear_objective()
	decide_all(deal, "dropped")
	finish(deal, false)
	Msp.send_text("Morgan", "The paperwork for %s came over with no handover. Dan is guessing what you promised." % str(deal.name))


# Monday: every handover nobody attended becomes paperwork
static func paperwork_all() -> void:
	var ids: Array = SalesCampaign.handover_queue.duplicate()
	if SalesCampaign.pending_handover != 0:
		ids.push_front(SalesCampaign.pending_handover)
	SalesCampaign.handover_queue = []
	SalesCampaign.pending_handover = 0
	for id in ids:
		var d := Deals.book_deal(int(id))
		if not d.is_empty() and str(d.get("state", "")) == "handover":
			paperwork(d)


static func _react(how: String, gap: float) -> void:
	var dan := "!" if gap >= 1.0 else ("dots" if how == "kept" else "heart")
	var morgan := "heart" if how == "renegotiated" else ("?" if how == "dropped" else "dots")
	if how == "done":
		dan = "heart" if gap < 0.5 else ("dots" if gap < 1.5 else "!")
		morgan = "heart" if gap < 0.5 else "dots"
	bubble("Dan", dan)
	bubble("Morgan", morgan)


# a speech bubble over a cast member who is in the room (no-op when they are elsewhere or the test has no scene)
static func bubble(who: String, glyph: String) -> void:
	if not World.chars.has(who):
		return
	var node = World.chars[who].get("node")
	if node == null or not is_instance_valid(node):
		return
	var b = node.get("_bubble")
	if b == null:
		return
	b.glyph = glyph
	b.visible = true
	node.set("_grumble_t", 2.6)
