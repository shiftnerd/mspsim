extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# The SalesHound CRM (sales campaign, slice S1): a desktop app for John that lists the pipeline and lets you work a lead. It is a
# simple read-and-move list: the tabs filter by stage (LEAD / MEETING / QUOTED / WON / LOST), Up / Down pick a lead, and the
# buttons (or C / V / Q / D) call, visit, quote or drop it. A call and a quote cost one selling hour each (SalesCampaign.spend),
# a visit drives you to their office. C2 adds: F (CHASE) follows a deal up, U (UPSELL) sells a service to a won client, I (INFO) flips
# the detail pane to the deal record (risk meter, promises, notes, the 90 day clock) and Q opens the quote builder screen
# (quote_builder.gd) in place of the list while you build a quote (SalesCampaign.crm_view).
# All state lives in SalesCampaign (crm_sel, crm_tab, leads); this script only paints and routes input for the Computer.
# `cp` is the Computer autoload: its drawing helpers (_fill, _text, _button, _row, _region, _window, _clip, _wrap) do the work.

const Deals := preload("res://scripts/deals.gd")
const TABS := [["ALL", "ALL"], ["LEAD", "LEAD"], ["MEETING", "MEET"], ["QUOTED", "QUOTE"], ["WON", "WON"], ["LOST", "LOST"]]
const STAGE_SHORT := {"LEAD": "LEAD", "MEETING": "MEET", "QUOTED": "QUOTE", "WON": "WON", "LOST": "LOST"}
const STAGE_TINT := {
	"LEAD": Color("2f6fb8"),
	"MEETING": Color("b8791a"),
	"QUOTED": Color("8e3a2b"),
	"WON": Color("2f7d46"),
	"LOST": Color("8b93a1"),
}
const HEAT_TINT := {"HOT": Color("c0392b"), "WARM": Color("b8791a"), "COLD": Color("5a6a85")}
const INK := Color("20242c")
const MUTED := Color("5a6a85")


# the leads the current tab shows: open ones first (by stage, then quality), then finished ones
static func rows() -> Array:
	var out := []
	for l in SalesCampaign.leads:
		if SalesCampaign.crm_tab == "ALL" or str(l.stage) == SalesCampaign.crm_tab:
			out.append(l)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var sa: int = SalesCampaign.STAGES.find(str(a.stage))
			var sb: int = SalesCampaign.STAGES.find(str(b.stage))
			if sa != sb:
				return sa < sb
			return int(a.quality) > int(b.quality)
	)
	return out


# the selected lead (the first row when the remembered one is not in this tab)
static func selected() -> Dictionary:
	var list := rows()
	for l in list:
		if int(l.id) == SalesCampaign.crm_sel:
			return l
	if list.is_empty():
		return {}
	SalesCampaign.crm_sel = int(list[0].id)
	return list[0]


static func paint(cp) -> void:
	if SalesCampaign.crm_view == "build":
		var bb: Rect2 = cp._window("SALESHOUND CRM - QUOTE BUILDER", Color("b8602b"))
		SalesCampaign.QuoteBuilder.paint(cp, bb)
		return
	var body: Rect2 = cp._window("SALESHOUND CRM - PIPELINE", Color("b8602b"))
	cp._fill(body, Color("f3f6fb"))
	var sel := selected()
	var list := rows()
	var w: float = body.size.x
	var qi: int = SalesCampaign.quarter_index()
	# the summary strip
	cp._fill(Rect2(body.position, Vector2(w, 9)), Color("e4d9c9"))
	var summary := "%s %d%%  PIPE $%d  NEW $%d  WK %d  HOURS %d" % [SalesCampaign.quarter_label(), SalesCampaign.quota_pct(qi), SalesCampaign.pipeline_value(), int(SalesCampaign.q_signed[qi]), Campaign.day, SalesCampaign.slots_left()]
	cp._text(cp._clip(summary, int(w / 4.0) - 1), body.position + Vector2(3, 2), INK)
	# the stage tabs
	var tab_w: float = (w - 4.0) / float(TABS.size())
	for i in TABS.size():
		var tint: Color = cp.BTN_HI if SalesCampaign.crm_tab == TABS[i][0] else cp.BTN
		cp._button("crm:tab:" + str(TABS[i][0]), Rect2(body.position.x + 2.0 + float(i) * tab_w, body.position.y + 10.0, tab_w - 1.0, 8), str(TABS[i][1]), true, tint)
	var area := Rect2(body.position + Vector2(0, 19), body.size - Vector2(0, 19))
	var side_by_side: bool = w >= 300.0
	var list_r := area
	var detail_r := area
	if side_by_side:
		list_r = Rect2(area.position, Vector2(floorf(w * 0.55), area.size.y))
		detail_r = Rect2(area.position + Vector2(list_r.size.x, 0), Vector2(w - list_r.size.x, area.size.y))
	else:
		list_r = Rect2(area.position, Vector2(w, floorf(area.size.y * 0.5)))
		detail_r = Rect2(area.position + Vector2(0, list_r.size.y), Vector2(w, area.size.y - list_r.size.y))
	_paint_list(cp, list_r, list, sel)
	_paint_detail(cp, detail_r, sel)


static func _paint_list(cp, r: Rect2, list: Array, sel: Dictionary) -> void:
	cp._fill(r, Color("ffffff"))
	var per: int = maxi(1, int(r.size.y / 7.0))
	if list.is_empty():
		cp._text("NO LEADS HERE. THEY ARRIVE EACH MONDAY.", r.position + Vector2(3, 3), MUTED)
		return
	var at := 0
	for i in list.size():
		if int(list[i].id) == int(sel.get("id", -1)):
			at = i
	var top: int = clampi(at - per + 1, 0, maxi(0, list.size() - per)) if at >= per else 0
	for k in per:
		var i: int = top + k
		if i >= list.size():
			break
		var l: Dictionary = list[i]
		var row := Rect2(r.position.x, r.position.y + float(k) * 7.0, r.size.x, 7)
		cp._row(row, int(l.id) == int(sel.get("id", -1)), k % 2 == 1)
		cp._region("crm:sel:%d" % int(l.id), row)
		var finished: bool = not SalesCampaign.is_open(l)
		var name_chars: int = int((r.size.x - 70.0) / 4.0)
		cp._text(cp._clip(str(l.name).to_upper(), name_chars), row.position + Vector2(2, 1), MUTED if finished else INK)
		var heat := SalesCampaign.heat(l)
		cp._text(heat.left(1), row.position + Vector2(r.size.x - 66.0, 1), HEAT_TINT[heat])
		cp._text("$%d" % int(l.fee), row.position + Vector2(r.size.x - 58.0, 1), INK)
		cp._text(str(STAGE_SHORT[str(l.stage)]), row.position + Vector2(r.size.x - 30.0, 1), STAGE_TINT[str(l.stage)])


static func _paint_detail(cp, r: Rect2, l: Dictionary) -> void:
	cp._fill(r, Color("eef3f9"))
	cp._fill(Rect2(r.position, Vector2(1, r.size.y)), Color("c9d2e0"))
	if l.is_empty():
		return
	var chars: int = int((r.size.x - 8.0) / 4.0)
	var x: float = r.position.x + 4.0
	var y: float = r.position.y + 2.0
	cp._text(cp._clip(str(l.name).to_upper(), chars - 4), Vector2(x, y), STAGE_TINT[str(l.stage)])
	cp._text("%d/2" % (SalesCampaign.crm_page + 1), Vector2(r.end.x - 16, y), MUTED)
	y += 7.0
	if SalesCampaign.crm_page == 1:
		_paint_record(cp, r, l, x, y, chars)
	else:
		_paint_summary(cp, r, l, x, y, chars)
	# the buttons
	var stage: String = str(l.stage)
	var open: bool = ["LEAD", "MEETING"].has(stage)
	var live: bool = open or stage == "QUOTED"
	var by: float = r.end.y - 28.0  # two rows of buttons: CALL VISIT QUOTE ASSESS, then CHASE DROP INFO
	var by2: float = r.end.y - 18.0
	var bw: float = (r.size.x - 6.0) / 4.0
	var bw2: float = (r.size.x - 6.0) / 3.0
	var can_call: bool = open and not bool(l.called) and SalesCampaign.slots_left() >= 1
	var can_visit: bool = open and SalesCampaign.can_visit(l) == ""
	var can_quote: bool = open and SalesCampaign.slots_left() >= 1
	var can_chase: bool = live and SalesCampaign.slots_left() >= 1
	var can_assess: bool = stage == "MEETING" and SalesCampaign.SalesRival.can_assess(l) == ""
	var can_up: bool = stage == "WON" and SalesCampaign.slots_left() >= 1 and not Deals.book_deal(int(l.id)).is_empty()
	cp._button("crm:call", Rect2(r.position.x + 3.0, by, bw - 1.0, 9), "CALL", can_call)
	cp._button("crm:visit", Rect2(r.position.x + 3.0 + bw, by, bw - 1.0, 9), "VISIT", can_visit)
	cp._button("crm:quote", Rect2(r.position.x + 3.0 + bw * 2.0, by, bw - 1.0, 9), "QUOTE", can_quote, Color("a9e0b0"))
	cp._button("crm:assess", Rect2(r.position.x + 3.0 + bw * 3.0, by, bw - 1.0, 9), "ASSESS", can_assess, Color("f0d9a0"))
	cp._button("crm:follow", Rect2(r.position.x + 3.0, by2, bw2 - 1.0, 9), "CHASE", can_chase)
	if stage == "WON":
		cp._button("crm:upsell", Rect2(r.position.x + 3.0 + bw2, by2, bw2 - 1.0, 9), "UPSELL", can_up, Color("a9c4e8"))
	else:
		cp._button("crm:drop", Rect2(r.position.x + 3.0 + bw2, by2, bw2 - 1.0, 9), "DROP", live, Color("e9b1a8"))
	cp._button("crm:more", Rect2(r.position.x + 3.0 + bw2 * 2.0, by2, bw2 - 1.0, 9), "INFO", true, Color("e4d9c9"))
	var keys := ""
	for item in ["C CALL", "V VISIT", "Q QUOTE", "A ASSESS", "F CHASE", "D DROP", "U UPSELL", "I INFO"]:  # whole items only, no "U U.."
		if (keys + "  " + item).strip_edges().length() <= chars:
			keys = (keys + "  " + item).strip_edges()
		else:
			break
	cp._text(keys, Vector2(x, r.end.y - 7.0), MUTED)


static func _paint_summary(cp, _r: Rect2, l: Dictionary, x: float, y0: float, chars: int) -> void:
	var y: float = y0
	var info := "%s  %d USERS  $%d/WK" % [str(SalesCampaign.TYPES[str(l.type)].label), int(l.users), int(l.fee)]
	cp._text(cp._clip(info, chars), Vector2(x, y), INK)
	y += 7.0
	var rv: String = SalesCampaign.SalesRival.rival_line(l)
	var found: int = SalesCampaign.SalesRival.findings(l).size()
	if found > 0:
		rv = "%s  %d FINDINGS" % [rv, found]
	cp._text(cp._clip(rv, chars), Vector2(x, y), STAGE_TINT["QUOTED"] if SalesCampaign.SalesRival.is_seen(l) else MUTED)
	y += 7.0
	var pain_lines: Array = cp._wrap("PAIN: " + str(l.pain).to_upper(), chars)
	for pl in pain_lines.slice(0, 2):
		cp._text(str(pl), Vector2(x, y), INK)
		y += 7.0
	var status := "%s %s" % [str(l.who).to_upper(), SalesCampaign.heat(l)]
	status += "  CALLED" if bool(l.called) else ""
	status += "  VISITED" if bool(l.visited) else ""
	cp._text(cp._clip(status, chars), Vector2(x, y), MUTED)
	y += 7.0
	var stage: String = str(l.stage)
	if stage == "LOST" and str(l.get("why", "")) != "":
		cp._text(cp._clip("LOST: " + str(l.why), chars), Vector2(x, y), STAGE_TINT["LOST"])
	elif stage == "WON":
		var d: Dictionary = Deals.book_deal(int(l.id))
		var txt := "WON. THE HANDOVER IS DONE."
		if not d.is_empty():
			txt = "HANDOVER WAITS IN THE CONFERENCE ROOM" if str(d.get("state", "")) == "handover" else "90 DAYS: WEEK %d OF %d" % [mini(Campaign.day - int(d.week), Deals.WINDOW_WEEKS), Deals.WINDOW_WEEKS]
		cp._text(cp._clip(txt, chars), Vector2(x, y), STAGE_TINT["WON"])
	elif stage == "QUOTED":
		cp._text(cp._clip("QUOTED. BYTEBROTHERS MAY STEAL IT", chars), Vector2(x, y), STAGE_TINT["QUOTED"])
	elif not bool(l.site):
		cp._text("PHONE ONLY, NO SITE VISIT", Vector2(x, y), MUTED)


# the deal record: risk meter, the promises made, the last note
static func _paint_record(cp, r: Rect2, l: Dictionary, x: float, y0: float, chars: int) -> void:
	var y: float = y0
	var stage: String = str(l.stage)
	var risk: int = Deals.risk(l)
	var label := "GOING COLD"
	if stage == "QUOTED":
		label = "STOLEN BY BYTEBROTHERS"
	elif stage == "WON":
		label = "CHURN RISK"
	elif stage == "LOST":
		label = "FINISHED"
	cp._text(cp._clip("%s %d%%" % [label, risk], chars), Vector2(x, y), INK)
	y += 6.0
	var bar_w: float = r.size.x - 10.0
	cp._fill(Rect2(x, y, bar_w, 3), Color("c9d2e0"))
	var tint: Color = Color("2f7d46") if risk < 35 else (Color("b8791a") if risk < 65 else Color("c0392b"))
	cp._fill(Rect2(x, y, floorf(bar_w * float(risk) / 100.0), 3), tint)
	y += 5.0
	var line2 := "TOUCHED WK %d  CHASED %d" % [int(l.get("touch", l.week)), int(l.get("follow", 0))]
	if stage == "WON":
		var d: Dictionary = Deals.book_deal(int(l.id))
		if not d.is_empty():
			line2 = "GAP %.1f MOOD %d KEPT %d BROKEN %d" % [float(d.gap), int(d.mood), SalesCampaign.Retention.kept_count(d), SalesCampaign.Retention.broken_count(d)]
	cp._text(cp._clip(line2, chars), Vector2(x, y), MUTED)
	y += 7.0
	var promises: Array = l.get("promises", [])
	if promises.is_empty():
		cp._text(cp._clip("NO PROMISES YET. THEY COME WITH THE QUOTE.", chars), Vector2(x, y), MUTED)
		y += 7.0
	var room: int = int((r.end.y - 29.0 - y) / 7.0)
	var notes: Array = l.get("notes", [])
	var show_note: bool = not notes.is_empty() and room >= promises.size() + 1
	if show_note:
		room -= 1
	var shown := 0
	var fit: int = room if promises.size() <= room else maxi(1, room - 1)
	for p in promises:
		if shown >= fit:
			break
		var st: String = str(p.state)
		var tag: String = {"open": "-", "kept": "K", "renegotiated": "R", "dropped": "D"}.get(st, "-")
		var col: Color = {"open": INK, "kept": Color("2f7d46"), "renegotiated": Color("b8791a"), "dropped": Color("c0392b")}.get(st, INK)
		cp._text(cp._clip("%s %s" % [tag, str(p.label)], chars), Vector2(x, y), col)
		y += 7.0
		shown += 1
	if promises.size() > shown:
		cp._text("+%d MORE PROMISES" % (promises.size() - shown), Vector2(x, y), MUTED)
		y += 7.0
	if show_note:
		cp._text(cp._clip(str(notes.back()), chars), Vector2(x, y), MUTED)


static func move(cp, step: int) -> void:
	if SalesCampaign.crm_view == "build":
		SalesCampaign.QuoteBuilder.move(cp, step)
		return
	var list := rows()
	if list.is_empty():
		return
	var at := 0
	for i in list.size():
		if int(list[i].id) == SalesCampaign.crm_sel:
			at = i
	SalesCampaign.crm_sel = int(list[clampi(at + step, 0, list.size() - 1)].id)


# Enter does the next sensible thing: call a fresh lead, quote one you have talked to
static func enter(cp) -> void:
	if SalesCampaign.crm_view == "build":
		SalesCampaign.QuoteBuilder.enter(cp)
		cp._canvas.queue_redraw()
		return
	var l := selected()
	if l.is_empty():
		return
	if str(l.stage) == "LEAD" and not bool(l.called):
		action(cp, ["crm", "call"])
	elif ["LEAD", "MEETING"].has(str(l.stage)):
		action(cp, ["crm", "quote"])


static func key(cp, code: int) -> void:
	if SalesCampaign.crm_view == "build":
		SalesCampaign.QuoteBuilder.key(cp, code)
		return
	match code:
		KEY_C:
			action(cp, ["crm", "call"])
		KEY_V:
			action(cp, ["crm", "visit"])
		KEY_Q:
			action(cp, ["crm", "quote"])
		KEY_D:
			action(cp, ["crm", "drop"])
		KEY_A:
			action(cp, ["crm", "assess"])
		KEY_F:
			action(cp, ["crm", "follow"])
		KEY_U:
			action(cp, ["crm", "upsell"])
		KEY_I:
			action(cp, ["crm", "more"])
		KEY_LEFT, KEY_RIGHT:
			var at := 0
			for i in TABS.size():
				if TABS[i][0] == SalesCampaign.crm_tab:
					at = i
			SalesCampaign.crm_tab = str(TABS[clampi(at + (1 if code == KEY_RIGHT else -1), 0, TABS.size() - 1)][0])
	cp._canvas.queue_redraw()


static func action(cp, parts: PackedStringArray) -> void:
	if parts[1] == "qb":
		SalesCampaign.QuoteBuilder.action(cp, parts)
		return
	var l := selected()
	match parts[1]:
		"more":
			SalesCampaign.crm_page = 1 - SalesCampaign.crm_page
		"follow":
			if not l.is_empty():
				cp._say(SalesCampaign.follow_up(int(l.id)))
		"upsell":
			var d: Dictionary = Deals.book_deal(int(l.get("id", 0))) if not l.is_empty() else {}
			if d.is_empty() or str(l.stage) != "WON":
				cp._say("NO CLIENT TO UPSELL.")
			elif SalesCampaign.slots_left() < 1:
				cp._say("NO SELLING HOURS LEFT.")
			elif SalesCampaign.Retention.upsell_options(d).is_empty():
				cp._say("THEY HAVE EVERY SERVICE WE SELL.")
			elif SalesCampaign.spend(1):
				SalesCampaign.Retention.upsell_card(d)
		"tab":
			SalesCampaign.crm_tab = parts[2]
		"sel":
			SalesCampaign.crm_sel = int(parts[2])
		"call":
			if not l.is_empty():
				cp._say(SalesCampaign.call_lead(int(l.id)))
		"assess":
			if not l.is_empty():
				cp._say(SalesCampaign.SalesRival.assess(int(l.id)))
		"visit":
			if not l.is_empty():
				var why := SalesCampaign.can_visit(l)
				if why != "":
					cp._say("NO VISIT: " + why)
				else:
					SalesCampaign.visit(int(l.id))
		"quote":
			if not l.is_empty():
				SalesCampaign.start_quote(int(l.id))
		"drop":
			if not l.is_empty():
				SalesCampaign.drop_lead(int(l.id))
				cp._say("DROPPED " + str(l.name).to_upper())
