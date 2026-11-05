extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# The quote builder (sales campaign, roadmap C2): one screen inside the SalesHound CRM that replaces the old method / promise / price
# card chain. Steppers for the method, price, discount, SLA tier, the three scope items and the onboarding speed on one side, live
# GAUGES on the other: WIN CHANCE, MARGIN (with Alan's floor as a tick), PROMISE vs CAPACITY GAP (capacity comes from the crew model
# and the open queue) and the CASH over the first four weeks. Alan's margin floor and Garrison's 20% sign-off are inline blocks with
# the owner's line; a blocked quote cannot be sent. Wide screens show both halves, narrow ones (portrait) are paged: fields, then
# gauges. The maths is Deals.gauges(); this script only paints and routes input. State: SalesCampaign.qb {id, q, row, page}.

const Deals := preload("res://scripts/deals.gd")
const ROWS := ["method", "price", "discount", "promise", "backup", "patching", "security", "onboard", "present"]
const LABEL := {
	"method": "METHOD",
	"price": "PRICE",
	"discount": "DISCOUNT",
	"promise": "SLA TIER",
	"backup": "BACKUP",
	"patching": "UPDATES+AV",
	"security": "SECURITY",
	"onboard": "ONBOARDING",
	"present": "PRESENTED AS",
}
const GOOD := Color("2f7d46")
const WARN := Color("b8791a")
const BAD := Color("c0392b")
const INK := Color("20242c")
const MUTED := Color("5a6a85")
const TRACK := Color("c9d2e0")


static func default_quote() -> Dictionary:
	return {"method": "fixed", "promise": "std", "price": "list", "discount": 0, "extras": [], "onboard": "std", "present": "itemized"}


static func begin(l: Dictionary) -> void:
	var q := default_quote()
	q["present"] = str(l.get("present_pref", "itemized"))
	SalesCampaign.qb = {"id": int(l.id), "q": q, "row": 0, "page": 0}
	SalesCampaign.crm_view = "build"


static func close() -> void:
	SalesCampaign.qb = {}
	SalesCampaign.crm_view = "list"


static func lead() -> Dictionary:
	if SalesCampaign.qb.is_empty():
		return {}
	return SalesCampaign.lead_by_id(int(SalesCampaign.qb.id))


static func quote() -> Dictionary:
	return SalesCampaign.qb.get("q", default_quote())


static func value_text(field: String) -> String:
	var q := quote()
	match field:
		"method":
			return str(Deals.METHOD_SHORT[str(q.method)])
		"price":
			return "+10%" if str(q.price) == "premium" else "LIST"
		"discount":
			return "NONE" if int(q.discount) == 0 else "%d%% OFF" % int(q.discount)
		"promise":
			return str(Deals.TIER_NAME[str(q.promise)])
		"onboard":
			return str(Deals.ONBOARD[str(q.onboard)].short)
		"present":
			return str(SalesCampaign.SalesRival.PRESENT_SHORT[SalesCampaign.SalesRival.present_of(q)])
	return ("ON $%d" % int(Deals.EXTRAS[field].fee)) if q.extras.has(field) else "OFF"


# change a stepper by one step (dir -1 / +1)
static func change(field: String, dir: int) -> void:
	var q := quote()
	match field:
		"method":
			var i: int = Deals.METHOD_ORDER.find(str(q.method))
			q["method"] = Deals.METHOD_ORDER[posmod(i + dir, Deals.METHOD_ORDER.size())]
		"price":
			q["price"] = "premium" if str(q.price) == "list" else "list"
		"discount":
			var i: int = Deals.DISCOUNTS.find(int(q.discount))
			q["discount"] = Deals.DISCOUNTS[clampi(i + dir, 0, Deals.DISCOUNTS.size() - 1)]
		"promise":
			var order := ["low", "std", "high"]
			q["promise"] = order[clampi(order.find(str(q.promise)) + dir, 0, 2)]
		"onboard":
			var i: int = Deals.ONBOARD_ORDER.find(str(q.onboard))
			q["onboard"] = Deals.ONBOARD_ORDER[clampi(i + dir, 0, Deals.ONBOARD_ORDER.size() - 1)]
		"present":
			var order: Array = SalesCampaign.SalesRival.PRESENT
			q["present"] = order[posmod(order.find(SalesCampaign.SalesRival.present_of(q)) + dir, order.size())]
		_:
			var ex: Array = q.extras
			if ex.has(field):
				ex.erase(field)
			else:
				ex.append(field)
			q["extras"] = ex


static func gauges() -> Dictionary:
	var l := lead()
	if l.is_empty():
		return {}
	return Deals.gauges(l, quote())


# ---- painting ---------------------------------------------------------------------------------------------
static func paint(cp, body: Rect2) -> void:
	cp._fill(body, Color("f3f6fb"))
	var l := lead()
	if l.is_empty():
		close()
		return
	var g := gauges()
	var w: float = body.size.x
	var wide: bool = w >= 250.0
	var page: int = int(SalesCampaign.qb.get("page", 0))
	var chars: int = int(w / 4.0) - 2
	# header: who, how big, what it costs in hours
	cp._fill(Rect2(body.position, Vector2(w, 9)), Color("e4d9c9"))
	var head := "%s  %d USERS  $%d  HRS %d" % [str(l.name).to_upper(), int(l.users), int(l.fee), SalesCampaign.slots_left()]
	cp._text(cp._clip(head, chars), body.position + Vector2(3, 2), INK)
	var area := Rect2(body.position + Vector2(0, 10), body.size - Vector2(0, 10))
	if wide:
		var left := Rect2(area.position, Vector2(floorf(w * 0.5), area.size.y))
		var right := Rect2(area.position + Vector2(left.size.x, 0), Vector2(w - left.size.x, area.size.y))
		_paint_fields(cp, left, false)
		_paint_gauges(cp, right, g, true)
	else:
		if page == 0:
			_paint_fields(cp, Rect2(area.position, Vector2(w, area.size.y - 11)), true)
			var mini := "WIN %d%%  MARGIN %d%%  GAP %.1f" % [int(round(100.0 * float(g.win))), int(round(100.0 * float(g.margin))), float(g.gap)]
			cp._text(cp._clip(mini, chars), Vector2(area.position.x + 3, area.end.y - 18), INK)
		else:
			_paint_gauges(cp, Rect2(area.position, Vector2(w, area.size.y - 11)), g, false)
		var by: float = area.end.y - 10
		cp._button("crm:qb:back", Rect2(area.position.x + 2, by, 40, 9), "BACK", true)
		if page == 0:
			cp._button("crm:qb:page", Rect2(area.end.x - 62, by, 60, 9), "GAUGES >", true, Color("a9c4e8"))
		else:
			cp._button("crm:qb:page", Rect2(area.position.x + 46, by, 52, 9), "< FIELDS", true, Color("a9c4e8"))
			cp._button("crm:qb:send", Rect2(area.end.x - 62, by, 60, 9), "SEND QUOTE", bool(g.can_send), Color("a9e0b0"))


static func _paint_fields(cp, r: Rect2, roomy: bool) -> void:
	cp._fill(r, Color("ffffff"))
	var n: int = ROWS.size()
	var row_h: float = clampf(floorf((r.size.y - 1.0) / float(n)), 7.0, 17.0 if roomy else 10.0)
	var sel: int = int(SalesCampaign.qb.get("row", 0))
	for i in n:
		var f: String = ROWS[i]
		var row := Rect2(r.position.x, r.position.y + 1.0 + float(i) * row_h, r.size.x, row_h)
		cp._row(row, i == sel, i % 2 == 1)
		cp._region("crm:qb:row:%d" % i, row)
		var ty: float = row.position.y + floorf((row_h - 5.0) * 0.5)
		cp._text(str(LABEL[f]), Vector2(row.position.x + 2, ty), INK)
		var vw: float = 62.0
		var vx: float = row.end.x - vw - 2.0
		cp._button("crm:qb:chg:%s:-1" % f, Rect2(vx, row.position.y + 1, 7, row_h - 2), "<", true)
		cp._button("crm:qb:chg:%s:1" % f, Rect2(vx + vw - 7, row.position.y + 1, 7, row_h - 2), ">", true)
		var vt: String = cp._clip(value_text(f), 12)
		cp._text(vt, Vector2(vx + 7 + floorf((vw - 14 - cp._tw(vt)) * 0.5), ty), WARN if f in ["discount"] and vt != "NONE" else INK)


static func _tone(good: bool, ok: bool) -> Color:
	return GOOD if good else (WARN if ok else BAD)


static func _bar(cp, r: Rect2, frac: float, col: Color, tick := -1.0) -> void:
	cp._fill(r, TRACK)
	cp._fill(Rect2(r.position, Vector2(floorf(r.size.x * clampf(frac, 0.0, 1.0)), r.size.y)), col)
	if tick >= 0.0:
		cp._fill(Rect2(r.position.x + floorf(r.size.x * clampf(tick, 0.0, 1.0)), r.position.y - 1, 1, r.size.y + 2), INK)


static func _paint_gauges(cp, r: Rect2, g: Dictionary, with_buttons: bool) -> void:
	cp._fill(r, Color("eef3f9"))
	cp._fill(Rect2(r.position, Vector2(1, r.size.y)), TRACK)
	var x: float = r.position.x + 4.0
	var bw: float = r.size.x - 8.0
	var y: float = r.position.y + 2.0
	var tall: bool = not with_buttons
	var step: float = 14.0 if tall else 10.0
	var chars: int = int(bw / 4.0)
	var win: float = float(g.win)
	var m: float = float(g.margin)
	var gp: float = float(g.gap)
	var cash: int = int(g.cash4)
	# WIN CHANCE
	cp._text(cp._clip("WIN CHANCE %d%%" % int(round(100.0 * win)), chars), Vector2(x, y), INK)
	_bar(cp, Rect2(x, y + 6, bw, 3), win, _tone(win >= 0.55, win >= 0.35))
	y += step
	# MARGIN with Alan's floor
	var floor_m: float = SalesCampaign.margin_floor
	cp._text(cp._clip("MARGIN %d%% (FLOOR %d%%)" % [int(round(100.0 * m)), int(round(100.0 * floor_m))], chars), Vector2(x, y), INK)
	_bar(cp, Rect2(x, y + 6, bw, 3), m / 0.7, _tone(m >= floor_m + 0.06, m >= floor_m - 0.0001), floor_m / 0.7)
	y += step
	# PROMISE vs CAPACITY
	cp._text(cp._clip("PROMISE GAP %.1f (CAPACITY %.1f)" % [gp, float(g.cap)], chars), Vector2(x, y), INK)
	_bar(cp, Rect2(x, y + 6, bw, 3), gp / 3.0, _tone(gp <= 0.3, gp <= 1.0))
	y += step
	# CASH over four weeks
	cp._text(cp._clip("CASH 4 WEEKS %s$%d" % ["-" if cash < 0 else "+", absi(cash)], chars), Vector2(x, y), INK)
	_bar(cp, Rect2(x, y + 6, bw, 3), absf(float(cash)) / 3000.0, _tone(cash >= 500, cash >= 0))
	y += step
	# RIVAL PRICE: the incumbent's weekly price against ours (hidden until you have asked who they use now)
	var rv: Dictionary = g.rival
	var rp: int = int(rv.week)
	var price_line := true
	if not bool(rv.known):
		cp._text(cp._clip("RIVAL PRICE: ASK WHO THEY USE", chars), Vector2(x, y), MUTED)
		y += 7.0
	elif rp <= 0:
		cp._text(cp._clip(("RIVAL: %s (%s)" % [str(rv.name), str(rv.note)]) if str(rv.note) != "" else "RIVAL: NOBODY YET", chars), Vector2(x, y), MUTED)
		y += 7.0
	else:
		var ours: float = float(g.price)
		var top: float = maxf(1.0, maxf(ours, float(rp)) * 1.25)
		cp._text(cp._clip("RIVAL %s $%d  YOU $%d" % [str(rv.name), rp, int(ours)], chars), Vector2(x, y), INK)
		_bar(cp, Rect2(x, y + 6, bw, 3), float(rp) / top, MUTED, ours / top)
		y += step
		price_line = tall  # the roomy layout adds the hours line below, the small one gives the line to the owners
	if price_line:
		cp._text(cp._clip("PRICE $%d/WK  HOURS %d  %s" % [int(g.price), int(g.hours), str(rv.note) if bool(rv.known) else ""], chars), Vector2(x, y), MUTED)
		y += 7.0
	# the owners' lines
	var line_h := 7.0
	var room: int = int((r.end.y - y - (11.0 if with_buttons else 12.0)) / line_h)
	var shown := 0
	for b in g.blocks:
		if shown >= room:
			break
		var col: Color = BAD if bool(b.hard) else WARN
		var lines: Array = cp._wrap("%s: %s" % [str(b.who), str(b.text)], chars)
		for ln in lines:
			if shown >= room:
				break
			cp._text(str(ln), Vector2(x, y), col)
			y += line_h
			shown += 1
	if with_buttons:
		var by: float = r.end.y - 10.0
		cp._button("crm:qb:back", Rect2(r.position.x + 3, by, 34, 9), "BACK", true)
		cp._button("crm:qb:send", Rect2(r.end.x - 62, by, 59, 9), "SEND QUOTE", bool(g.can_send), Color("a9e0b0"))


# ---- input -------------------------------------------------------------------------------------------
static func move(_cp, step: int) -> void:
	SalesCampaign.qb["row"] = clampi(int(SalesCampaign.qb.get("row", 0)) + step, 0, ROWS.size() - 1)


static func send(cp) -> void:
	var l := lead()
	if l.is_empty():
		close()
		return
	var g := gauges()
	if not bool(g.can_send):
		var why := "NOT YET"
		for b in g.blocks:
			if bool(b.hard):
				why = "%s: %s" % [str(b.who), str(b.text)]
				break
		cp._say(why)
		return
	var q := quote().duplicate(true)
	close()
	SalesCampaign.send_quote(l, q)
	cp._say("QUOTE SENT TO %s" % str(l.name).to_upper())


static func enter(cp) -> void:
	var wide: bool = cp._area.size.x >= 250.0
	if not wide and int(SalesCampaign.qb.get("page", 0)) == 0:
		SalesCampaign.qb["page"] = 1
		return
	send(cp)


static func key(cp, code: int) -> void:
	match code:
		KEY_LEFT:
			change(ROWS[int(SalesCampaign.qb.get("row", 0))], -1)
		KEY_RIGHT:
			change(ROWS[int(SalesCampaign.qb.get("row", 0))], 1)
		KEY_TAB:
			SalesCampaign.qb["page"] = 1 - int(SalesCampaign.qb.get("page", 0))
		KEY_S:
			send(cp)
		KEY_B:
			close()
	cp._canvas.queue_redraw()


static func action(cp, parts: PackedStringArray) -> void:
	match parts[2]:
		"row":
			SalesCampaign.qb["row"] = clampi(int(parts[3]), 0, ROWS.size() - 1)
		"chg":
			SalesCampaign.qb["row"] = maxi(0, ROWS.find(parts[3]))
			change(parts[3], int(parts[4]))
		"page":
			SalesCampaign.qb["page"] = 1 - int(SalesCampaign.qb.get("page", 0))
		"send":
			send(cp)
		"back":
			close()
