extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# The SalesHound CRM (sales campaign, slice S1): a desktop app for Vic that lists the pipeline and lets you work a lead. It is a
# simple read-and-move list: the tabs filter by stage (LEAD / MEETING / QUOTED / WON / LOST), Up / Down pick a lead, and the
# buttons (or C / V / Q / D) call, visit, quote or drop it. A call and a quote cost one selling hour each (SalesCampaign.spend),
# a visit drives you to their office. The full CRM (deal stages with promises, gauges, renewals) is slice S2.
# All state lives in SalesCampaign (crm_sel, crm_tab, leads); this script only paints and routes input for the Computer.
# `cp` is the Computer autoload: its drawing helpers (_fill, _text, _button, _row, _region, _window, _clip, _wrap) do the work.

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
	cp._text(cp._clip(str(l.name).to_upper(), chars), Vector2(x, y), STAGE_TINT[str(l.stage)])
	y += 7.0
	var info := "%s  %d USERS  $%d/WK" % [str(SalesCampaign.TYPES[str(l.type)].label), int(l.users), int(l.fee)]
	cp._text(cp._clip(info, chars), Vector2(x, y), INK)
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
	if str(l.stage) == "LOST" and str(l.get("why", "")) != "":
		cp._text(cp._clip("LOST: " + str(l.why), chars), Vector2(x, y), STAGE_TINT["LOST"])
	elif str(l.stage) == "WON":
		cp._text("WON. THE HANDOVER IS DONE.", Vector2(x, y), STAGE_TINT["WON"])
	elif not bool(l.site):
		cp._text("PHONE ONLY, NO SITE VISIT", Vector2(x, y), MUTED)
	# the buttons
	var open: bool = ["LEAD", "MEETING"].has(str(l.stage))
	var bw: float = (r.size.x - 6.0) / 4.0
	var by: float = r.end.y - 18.0
	var can_call: bool = open and not bool(l.called) and SalesCampaign.slots_left() >= 1
	var can_visit: bool = open and SalesCampaign.can_visit(l) == ""
	var can_quote: bool = open and SalesCampaign.slots_left() >= 1
	cp._button("crm:call", Rect2(r.position.x + 3.0, by, bw - 1.0, 9), "CALL", can_call)
	cp._button("crm:visit", Rect2(r.position.x + 3.0 + bw, by, bw - 1.0, 9), "VISIT", can_visit)
	cp._button("crm:quote", Rect2(r.position.x + 3.0 + bw * 2.0, by, bw - 1.0, 9), "QUOTE", can_quote, Color("a9e0b0"))
	cp._button("crm:drop", Rect2(r.position.x + 3.0 + bw * 3.0, by, bw - 1.0, 9), "DROP", open, Color("e9b1a8"))
	cp._text(cp._clip("C CALL  V VISIT  Q QUOTE  D DROP", chars), Vector2(x, r.end.y - 7.0), MUTED)


static func move(_cp, step: int) -> void:
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
	var l := selected()
	if l.is_empty():
		return
	if str(l.stage) == "LEAD" and not bool(l.called):
		action(cp, ["crm", "call"])
	elif ["LEAD", "MEETING"].has(str(l.stage)):
		action(cp, ["crm", "quote"])


static func key(cp, code: int) -> void:
	match code:
		KEY_C:
			action(cp, ["crm", "call"])
		KEY_V:
			action(cp, ["crm", "visit"])
		KEY_Q:
			action(cp, ["crm", "quote"])
		KEY_D:
			action(cp, ["crm", "drop"])
		KEY_LEFT, KEY_RIGHT:
			var at := 0
			for i in TABS.size():
				if TABS[i][0] == SalesCampaign.crm_tab:
					at = i
			SalesCampaign.crm_tab = str(TABS[clampi(at + (1 if code == KEY_RIGHT else -1), 0, TABS.size() - 1)][0])
	cp._canvas.queue_redraw()


static func action(cp, parts: PackedStringArray) -> void:
	var l := selected()
	match parts[1]:
		"tab":
			SalesCampaign.crm_tab = parts[2]
		"sel":
			SalesCampaign.crm_sel = int(parts[2])
		"call":
			if not l.is_empty():
				cp._say(SalesCampaign.call_lead(int(l.id)))
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
