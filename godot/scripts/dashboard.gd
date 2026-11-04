extends RefCounted
# gdlint:disable=class-definitions-order,max-returns,max-line-length,unsafe-method-access
# PIXEL IT METRICS (roadmap R20, docs/scope-dashboard.md): the wall-dashboard look of a 2014 service desk (ten tiles of 14-segment LED
# digits, a bar chart of the hours or the queue, a green and yellow opened / resolved chart) used by the METRICS computer app in every
# mode and by the wall TV takeover. Static helpers only. `tiles(mode)` and `series(mode)` are pure data (tests read them headless);
# `paint(canvas, rect, mode, t, opts)` draws rectangles and polygons only, at any size: three layouts (wide, h, v).
# Cozy Easy (Difficulty.cozy_on()): no red (a red tile shows amber) and no per-tech hours chart.

const PixelFont := preload("res://scripts/pixelfont.gd")
const Dash := preload("res://scripts/dash.gd")

const TITLE := "PIXEL IT METRICS"
const MODES := ["tech", "owner", "sales", "service"]
const BG := Color("04060a")
const PANEL := Color("090d14")
const BEZEL := Color("aab4c6")
const LABEL := Color("e4eaf3")
const GRID := Color("1b2531")
const DIM := Color("6f7d93")
const AMBER := Color("ffbf3a")
const COLORS := {"g": Color("3ddc55"), "o": Color("ff9a1f"), "y": Color("f2e84a"), "r": Color("ff3b30")}
# bar colours: front, lighter top, darker side (the 2 px extrusion)
const BARS := {
	"g": [Color("7fe34a"), Color("b9f58c"), Color("3f8a24")],
	"y": [Color("f2e84a"), Color("fffa9c"), Color("a39a1c")],
	"o": [Color("ff9a1f"), Color("ffc87a"), Color("a85c0c")],
}
# the 14 segments of a glyph: a top, b top right, c bottom right, d bottom, e bottom left, f top left, g left middle,
# h right middle, i top centre, j upper left diagonal, k upper right diagonal, l bottom centre, m lower left diagonal, n lower right diagonal
const SEGS := "abcdefghijklmn"
const GLYPHS := {
	"0": "abcdef", "1": "bc", "2": "abdegh", "3": "abcdgh", "4": "bcfgh", "5": "acdfgh", "6": "acdefgh", "7": "abc", "8": "abcdefgh", "9": "abcdfgh",
	"A": "abcefgh", "B": "abcdhil", "C": "adef", "D": "abcdil", "E": "adefg", "F": "aefg", "G": "acdefh", "H": "bcefgh", "I": "adil", "J": "bcde",
	"K": "efgkn", "L": "def", "M": "bcefjk", "N": "bcefjn", "O": "abcdef", "P": "abefgh", "Q": "abcdefn", "R": "abefghn", "S": "acdfgh", "T": "ail",
	"U": "bcdef", "V": "efkm", "W": "bcefmn", "X": "jkmn", "Y": "jkl", "Z": "adkm", "-": "gh", "+": "ghil", "/": "km", "*": "ghijklmn", " ": "",
}


# ---- the data (pure: no drawing) ---------------------------------------------------------------------------------------
static func mode_now() -> String:
	var m: String = Campaign.mode if Campaign.active else "tech"
	return m if MODES.has(m) else "tech"


static func _tile(id: String, label: String, value: Variant, status: String, digits := 3, kpi := {}) -> Dictionary:
	var text := str(value)
	var cap := int(pow(10.0, float(digits))) - 1
	if value is int and int(value) > cap:
		text = str(cap)
	return {"id": id, "label": label, "value": value, "text": text, "status": status, "digits": digits, "kpi": kpi}


# higher is worse: red from `red`, orange from `orange`
static func _hi(v: float, orange: float, red: float) -> String:
	return "r" if v >= red else ("o" if v >= orange else "g")


# lower is worse
static func _lo(v: float, orange: float, red: float) -> String:
	return "r" if v <= red else ("o" if v <= orange else "g")


static func _base(key: String) -> int:
	return int(Campaign._base.get(key, 0)) if Campaign.active else 0


static func _count(pred: Callable) -> int:
	var n := 0
	for t in Msp.open_tickets():
		if pred.call(t):
			n += 1
	return n


static func _failing_backups() -> int:
	var n := 0
	for b in Msp.backups:
		if not bool(b.ok):
			n += 1
	return n


static func _day_score() -> int:
	var s: int = Msp.score - _base("score")
	return maxi(0, s) if Difficulty.cozy_on() else s


# ESCALATIONS (SLA breaches + reopens this week) with the trend arrow against last week
static func _esc_tile() -> Dictionary:
	var n: int = Growth.esc_now() if Campaign.active else 0
	var tl := _tile("esc", "ESCALATIONS", n, _hi(n, 2, 4), 2)
	tl["trend"] = Growth.esc_trend()
	return tl


# the ten tiles of a mode: [{id, label, value, text, status g|o|y|r, digits, kpi}]
static func tiles(mode: String) -> Array:
	match mode:
		"owner":
			return _owner_tiles()
		"sales":
			return _sales_tiles()
		"service":
			return _service_tiles()
	return _tech_tiles()


static func _tech_tiles() -> Array:
	var open: int = Msp.open_tickets().size()
	var prog := _count(func(t: Dictionary) -> bool: return str(t.status) == "In Progress")
	var hot := _count(func(t: Dictionary) -> bool: return int(t.pri) <= 2)
	var onsite := _count(func(t: Dictionary) -> bool: return str(t.fix).begins_with("onsite"))
	var missed := int(Dash.today().missed)
	var energy := int(round(Shift.energy))
	var score := _day_score()
	return [
		_tile("open", "OPEN", open, _hi(open, 3, 5)),
		_tile("prog", "IN PROGRESS", prog, "o" if prog > 0 else "g"),
		_tile("done", "CLOSED TODAY", int(Dash.today().closed), "g"),
		_tile("sla", "SLA BREACHED", missed, "r" if missed > 0 else "g"),
		_tile("hot", "P1/P2 OPEN", hot, _hi(hot, 1, 2)),
		_tile("bkp", "BACKUPS DOWN", _failing_backups(), "r" if _failing_backups() > 0 else "g"),
		_tile("site", "WAITING ONSITE", onsite, "o" if onsite > 0 else "g"),
		_esc_tile(),
		_tile("nrg", "ENERGY", energy, _lo(energy, 55, 35)),
		_tile("score", "DAY SCORE", score, "g" if score >= 10 else ("y" if score >= 0 else "r"), 3),
	]


static func _owner_tiles() -> Array:
	var est: Dictionary = Owner.weekly_estimate()
	var w2 := int(round(float(est.w2) * 100.0))
	var ar: int = Owner.ar_total()
	var mood := int(round(Sales.average()))
	var open: int = Msp.open_tickets().size()
	var ebitda := int(est.ebitda)
	if Difficulty.cozy_on():
		ebitda = maxi(0, ebitda)
	var mult: float = Owner.multiple()
	var cash: int = Owner.cash
	return [
		_tile("cash", "CASH $", maxi(0, cash), _lo(cash, 4000, 1500), 5),
		_tile("rev", "REVENUE/WK $", int(est.revenue), "g", 5),
		_tile("ebit", "EBITDA/WK $", ebitda, "g" if ebitda >= 600 else ("y" if ebitda >= 0 else "r"), 4),
		_tile("w2", "W-2 %", w2, _hi(w2, 55, 62), 3, {"met": w2 <= 55, "goal": str(Owner.goal.get("id", "")) == "w2"}),
		_tile("cli", "CLIENTS", Sales.active.size(), "g", 2),
		_tile("ar", "A/R OWED $", ar, _hi(ar, 1500, 3000), 4, {"met": ar < 1500, "goal": str(Owner.goal.get("id", "")) == "ar"}),
		_esc_tile(),
		_tile("burn", "BURNOUT", int(Owner.burnout), _hi(Owner.burnout, 50, 75)),
		_tile("mood", "CLIENT MOOD", mood, _lo(mood, 60, 40), 3, {"met": mood >= 75, "goal": str(Owner.goal.get("id", "")) == "mood"}),
		_tile("mult", "VALUE MULTIPLE", "%.1f" % mult, "g" if mult >= 4.0 else ("y" if mult >= 3.0 else "o"), 3),
	]


static func _stage_count(stage: String) -> int:
	var n := 0
	for l in SalesCampaign.leads:
		if str(l.stage) == stage:
			n += 1
	return n


static func _sales_tiles() -> Array:
	var hot := 0
	for l in SalesCampaign.open_leads():
		if SalesCampaign.heat(l) == "HOT":
			hot += 1
	var pct: int = SalesCampaign.quota_pct()
	var mood := int(round(Sales.average()))
	var hours: int = SalesCampaign.slots_left()
	var lost: int = SalesCampaign.losses
	return [
		_tile("pipe", "PIPELINE $", int(SalesCampaign.pipeline_value()), "g", 5),
		_tile("meet", "MEETINGS", _stage_count("MEETING"), "g", 2),
		_tile("quo", "QUOTED", _stage_count("QUOTED"), "y", 2),
		_tile("won", "WON", int(SalesCampaign.wins), "g", 2),
		_tile("quota", "QUOTA %", pct, "g" if pct >= 100 else ("o" if SalesCampaign.behind_pace() else "y"), 3),
		_tile("deal", "DEALS THIS WEEK", int(SalesCampaign.week_deals), "g", 2),
		_tile("hot", "HOT LEADS", hot, "y", 2),
		_tile("mood", "CLIENT MOOD", mood, _lo(mood, 60, 40)),
		_tile("hrs", "SELLING HOURS", hours, _lo(hours, 2, 0), 2),
		_tile("lost", "LOST", lost, "o" if lost > 0 else "g", 2),
	]


static func _service_tiles() -> Array:
	var open: int = Msp.open_tickets().size()
	var inc := _count(func(t: Dictionary) -> bool: return str(t.get("special", "")) != "")
	var trust := mini(Service.trust_of("Alan"), Service.trust_of("Garrison"))
	var esc := 0
	for k in Service.owner_used:
		esc += int(Service.owner_used[k])
	var missed := int(Dash.today().missed)
	var unassigned := _count(func(t: Dictionary) -> bool: return Service._crew_ticket(t) and Crew.assignee_of(t) == "")
	var over := 0
	for who in Crew.names():
		if float(Crew.members[who].over_t) > 0.0:
			over += 1
	var mood: int = Crew.morale_avg()
	var score := _day_score()
	return [
		_tile("queue", "QUEUE", open, _hi(open, 4, 7)),
		_tile("inc", "INCIDENTS", inc, "r" if inc > 0 else "g", 2),
		_tile("trust", "OWNER TRUST", trust, _lo(trust, 45, 30)),
		_tile("esc", "ESCALATIONS", esc, "o" if esc > 0 else "g", 2),
		_tile("sla", "SLA BREACHED", missed, "r" if missed > 0 else "g"),
		_tile("unas", "UNASSIGNED", unassigned, "o" if unassigned > 0 else "g", 2),
		_tile("ot", "OVERTIME", over, "o" if over > 0 else "g", 2),
		_tile("mood", "CREW MOOD", mood, _lo(mood, 60, 40)),
		_tile("done", "CLOSED TODAY", int(Dash.today().closed), "g"),
		_tile("score", "DAY SCORE", score, "g" if score >= 10 else ("y" if score >= 0 else "r")),
	]


# red tiles of a mode (before the cozy amber), for the glance hint
static func red_tiles(mode: String) -> Array:
	var out := []
	for tl in tiles(mode):
		if str(tl.status) == "r":
			out.append(tl)
	return out


# the colour of a status as the board shows it (cozy Easy: red is amber)
static func status_color(status: String, cozy := false) -> Color:
	if status == "r" and cozy:
		return AMBER
	return COLORS[status]


# the glance hint (R20 step 5): the TV frame flashes while any tile is red (amber on cozy Easy), and once a day a toast says which
static func glance_color() -> Color:
	if not Campaign.active or Game.title_mode or red_tiles(mode_now()).is_empty():
		return Color(0, 0, 0, 0)
	return status_color("r", Difficulty.cozy_on())


# "" or the toast for the first red tile, once per day
static func glance_toast() -> String:
	var reds := red_tiles(mode_now())
	if reds.is_empty() or not Campaign.active or Dash.glanced == Dash.now():
		return ""
	Dash.glanced = Dash.now()
	var label := str(reds[0].label)
	return ("THE METRICS BOARD HAS A TILE TO LOOK AT: %s" % label) if Difficulty.cozy_on() else ("THE METRICS BOARD IS RED: %s" % label)


# a few pixels of the board for the 32x14 micro channel on the wall TV: four status blocks and a 6 day sparkline
static func paint_micro(c: CanvasItem, sx: float, sy: float, w: float, h: float) -> void:
	_r(c, sx, sy, w, h, Color("07090e"))
	var list := tiles(mode_now())
	var cozy := Difficulty.cozy_on()
	for i in 4:
		var col := status_color(str(list[i].status), cozy)
		var bx := sx + 1.0 + float(i % 2) * 9.0
		var by := sy + 1.0 + float(i / 2) * 7.0
		_r(c, bx, by, 8, 6, Color(col.r, col.g, col.b, 0.35))
		_r(c, bx + 1, by + 1, 6, 4, col)
	var rows := Dash.recent(6)
	var m := 1.0
	for e in rows:
		m = maxf(m, maxf(float(e.opened), float(e.closed)))
	var x0 := sx + 20.0
	var base := sy + h - 1.0
	_r(c, x0 - 1, base, 13, 1, Color("2a3442"))
	for k in rows.size():
		var oh := floorf((h - 3.0) * float(rows[k].opened) / m)
		var ch := floorf((h - 3.0) * float(rows[k].closed) / m)
		_r(c, x0 + float(k) * 2.0, base - oh, 1, oh, COLORS.g)
		_r(c, x0 + float(k) * 2.0 + 1.0, base - ch, 1, ch, COLORS.y)


# initials of a client or a person: "Hoot and Holler Law" -> "HH", "Dan" -> "DA"
static func initials(label: String) -> String:
	var words := []
	for w in label.split(" "):
		if w != "" and w.to_lower() != "and":
			words.append(w)
	if words.size() >= 2:
		return (str(words[0]).substr(0, 1) + str(words[1]).substr(0, 1)).to_upper()
	return label.substr(0, 2).to_upper()


# a rounded-up axis top and the step between gridlines
static func nice_max(m: float) -> Array:
	m = maxf(m, 4.0)  # an empty or quiet chart still has a 0 to 4 axis
	var raw := maxf(1.0, m / 4.0)  # whole numbers on the axis
	var mag := pow(10.0, floorf(log(raw) / log(10.0)))
	var step := mag
	for k in [1.0, 2.0, 5.0, 10.0]:
		step = mag * k
		if step >= raw:
			break
	return [ceilf(m / step) * step, step]


# one chart: {title, labels, series: [{name, color, vals}], max, step}
static func _chart(title: String, labels: Array, series: Array) -> Dictionary:
	var m := 0.0
	for s in series:
		for v in s.vals:
			m = maxf(m, float(v))
	var nm := nice_max(m)
	return {"title": title, "labels": labels, "series": series, "max": nm[0], "step": nm[1]}


static func _queue_chart() -> Dictionary:
	var labels := []
	var vals := []
	for c in Msp.CLIENTS.size():
		labels.append(initials(str(Msp.CLIENTS[c].name)))
		var n := 0
		for t in Msp.open_tickets():
			if int(t.client) == c:
				n += 1
		vals.append(float(n))
	return _chart("OPEN TICKETS BY CLIENT", labels, [{"name": "OPEN", "color": "g", "vals": vals}])


static func _flow_chart() -> Dictionary:
	var rows := Dash.recent(Dash.SHOWN)
	var labels := []
	var opened := []
	var closed := []
	for e in rows:
		labels.append(str(int(e.d) % 100) if int(e.d) >= 1 else "")
		opened.append(float(e.opened))
		closed.append(float(e.closed))
	var title := "OPENED / RESOLVED"  # (the labels under the bars are the day numbers, or the weeks in the owner campaign)
	return _chart(title, labels, [{"name": "OPENED", "color": "g", "vals": opened}, {"name": "RESOLVED", "color": "y", "vals": closed}])


# the two charts of a mode: [left, right]. Left: the hours per tech (service, not on cozy Easy), EBITDA by week (owner), the pipeline
# by stage (sales), otherwise the open tickets by client. Right: opened and resolved per day from Dash (zeros when nothing is recorded).
static func series(mode: String) -> Array:
	var left: Dictionary
	match mode:
		"owner":
			var labels := []
			var vals := []
			var hist: Array = Owner.history
			for i in 8:
				var idx := hist.size() - 8 + i
				if idx >= 0:
					labels.append("W%d" % int(hist[idx].day))
					vals.append(maxf(0.0, float(hist[idx].ebitda)))
				else:
					labels.append("")
					vals.append(0.0)
			left = _chart("EBITDA BY WEEK $", labels, [{"name": "EBITDA", "color": "g", "vals": vals}])
		"sales":
			var names := ["LEAD", "MEETING", "QUOTED", "WON", "LOST"]
			var short := ["LD", "MT", "QT", "WN", "LS"]
			var counts := []
			for s in names:
				counts.append(float(_stage_count(s)))
			left = _chart("PIPELINE BY STAGE", short, [{"name": "LEADS", "color": "o", "vals": counts}])
		"service":
			if Difficulty.cozy_on():
				left = _queue_chart()
			else:
				var labels := []
				var vals := []
				for who in Crew.names():
					labels.append(initials(str(who)))
					vals.append(snappedf(float(Dash.today().hours.get(who, 0.0)), 0.1))
				left = _chart("HOURS WORKED BY TECH TODAY", labels, [{"name": "HOURS", "color": "g", "vals": vals}])
		_:
			left = _queue_chart()
	return [left, _flow_chart()]


# ---- layout ------------------------------------------------------------------------------------------------------------
static func layout_kind(size: Vector2) -> String:
	if size.x < 230.0:
		return "v"
	return "h" if size.y >= 140.0 else "wide"


# {kind, title, tiles: [Rect2 x10], charts: [Rect2]} for a rect; wide has ONE chart rect (it switches between the two series)
static func layout(rect: Rect2, with_title := true) -> Dictionary:
	var kind := layout_kind(rect.size)
	var head := 7.0 if with_title else 0.0
	var body := Rect2(rect.position + Vector2(2, head + 1), rect.size - Vector2(4, head + 2))
	var cols := 2 if kind == "v" else 5
	var rows := 5 if kind == "v" else 2
	var gap := 2.0
	var tw := floorf((body.size.x - gap * float(cols - 1)) / float(cols))
	var th_pref := body.size.y * (0.11 if kind == "v" else (0.2 if kind == "h" else 0.28))
	var th := clampf(floorf(th_pref), 15.0, 34.0)
	var out := {"kind": kind, "title": Rect2(rect.position, Vector2(rect.size.x, head)), "tiles": [], "charts": []}
	var x0 := body.position.x + floorf((body.size.x - (tw * float(cols) + gap * float(cols - 1))) * 0.5)
	for i in 10:
		var c := i % cols
		var r := i / cols
		out.tiles.append(Rect2(Vector2(x0 + float(c) * (tw + gap), body.position.y + float(r) * (th + gap)), Vector2(tw, th)))
	var tiles_h := th * float(rows) + gap * float(rows - 1)
	var rest := Rect2(body.position + Vector2(0, tiles_h + gap), Vector2(body.size.x, body.size.y - tiles_h - gap))
	match kind:
		"h":
			var half := floorf((rest.size.x - gap) * 0.5)
			out.charts = [Rect2(rest.position, Vector2(half, rest.size.y)), Rect2(rest.position + Vector2(half + gap, 0), Vector2(rest.size.x - half - gap, rest.size.y))]
		"v":
			var hh := floorf((rest.size.y - gap) * 0.5)
			out.charts = [Rect2(rest.position, Vector2(rest.size.x, hh)), Rect2(rest.position + Vector2(0, hh + gap), Vector2(rest.size.x, rest.size.y - hh - gap))]
		_:
			out.charts = [rest]
	return out


# ---- drawing -----------------------------------------------------------------------------------------------------------
static func _r(c: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	if w > 0.0 and h > 0.0:
		c.draw_rect(Rect2(x, y, w, h), col)


static func _text(c: CanvasItem, s: String, x: float, y: float, col: Color) -> void:
	PixelFont.draw(c, s, Vector2(floorf(x), floorf(y)), col, 1)


static func _tw(s: String) -> float:
	return float(PixelFont.width(s, 1))


static func _quad(c: CanvasItem, p1: Vector2, p2: Vector2, thick: float, col: Color) -> void:
	var d := p2 - p1
	if d.length() < 0.5:
		return
	var n := Vector2(-d.y, d.x).normalized() * thick * 0.5
	c.draw_colored_polygon(PackedVector2Array([p1 + n, p2 + n, p2 - n, p1 - n]), col)


# one 14-segment cell at (x, y) w by h px: lit segments in `col`, the others as a faint ghost
static func digit(c: CanvasItem, ch: String, x: float, y: float, w: float, h: float, col: Color, dp := false) -> void:
	var lit: String = GLYPHS.get(ch.to_upper(), "")
	var ghost := Color(col.r, col.g, col.b, 0.12)
	var t := 1.0 if h < 14.0 else (2.0 if h < 24.0 else 3.0)
	var mid := y + floorf(h * 0.5)
	var cx := x + floorf(w * 0.5)
	var my := mid - floorf(t * 0.5)
	var hv := maxf(1.0, mid - y - 2.0)
	var rects := {
		"a": Rect2(x + 1, y, w - 2, t), "d": Rect2(x + 1, y + h - t, w - 2, t),
		"f": Rect2(x, y + 1, t, hv), "b": Rect2(x + w - t, y + 1, t, hv),
		"e": Rect2(x, mid + 1, t, hv), "c": Rect2(x + w - t, mid + 1, t, hv),
		"g": Rect2(x + 1, my, maxf(1.0, cx - x - 1), t), "h": Rect2(cx + 1, my, maxf(1.0, x + w - 1 - cx - 1), t),
		"i": Rect2(cx - floorf(t * 0.5), y + t + 1, t, maxf(1.0, mid - y - t - 2)),
		"l": Rect2(cx - floorf(t * 0.5), mid + 2, t, maxf(1.0, y + h - t - 1 - mid - 2)),
	}
	var diag := {
		"j": [Vector2(x + t + 1, y + t + 1), Vector2(cx - 1, mid - 1)], "k": [Vector2(x + w - t - 1, y + t + 1), Vector2(cx + 2, mid - 1)],
		"m": [Vector2(x + t + 1, y + h - t - 1), Vector2(cx - 1, mid + 2)], "n": [Vector2(x + w - t - 1, y + h - t - 1), Vector2(cx + 2, mid + 2)],
	}
	for s in SEGS:
		var on := lit.contains(s)
		var colr := col if on else ghost
		if rects.has(s):
			c.draw_rect(rects[s], colr)
		elif h >= 9.0:
			_quad(c, diag[s][0], diag[s][1], maxf(1.0, t * 0.9), colr)
		elif on:
			c.draw_rect(Rect2(diag[s][0].lerp(diag[s][1], 0.5).floor(), Vector2(1, 1)), colr)
	if dp:
		c.draw_rect(Rect2(x + w, y + h - maxf(t, 2.0), 2, maxf(t, 2.0)), col)


static func _status_color(status: String, cozy: bool, t: float) -> Color:
	if status == "r":
		var pulse := 0.8 + 0.2 * sin(t * 3.4)
		var base: Color = AMBER if cozy else COLORS.r
		return Color(base.r, base.g, base.b, pulse)
	return COLORS[status]


static func _tick(c: CanvasItem, x: float, y: float, met: bool) -> void:
	if met:
		var g: Color = COLORS.g
		_r(c, x, y + 2, 1, 1, g)
		_r(c, x + 1, y + 3, 1, 1, g)
		_r(c, x + 2, y + 2, 1, 1, g)
		_r(c, x + 3, y + 1, 1, 1, g)
		_r(c, x + 4, y, 1, 1, g)
	else:
		_r(c, x, y + 2, 5, 1, AMBER)


# the trend arrow (5 px wide, 7 tall): up is bad (red, amber on cozy Easy), flat is yellow, down is good (green)
const ARROWS := {
	1: [[2, 0, 1, 1], [1, 1, 3, 1], [0, 2, 5, 1], [2, 3, 1, 4]],
	0: [[0, 3, 3, 1], [3, 1, 1, 5], [4, 2, 1, 3], [5, 3, 1, 1]],
	-1: [[2, 0, 1, 4], [0, 4, 5, 1], [1, 5, 3, 1], [2, 6, 1, 1]],
}


static func _arrow(c: CanvasItem, x: float, y: float, trend: int, cozy: bool) -> void:
	var col: Color = COLORS.y
	if trend > 0:
		col = AMBER if cozy else COLORS.r
	elif trend < 0:
		col = COLORS.g
	for p in ARROWS[clampi(trend, -1, 1)]:
		_r(c, x + float(p[0]), y + float(p[1]), float(p[2]), float(p[3]), col)


static func _paint_tile(c: CanvasItem, r: Rect2, tl: Dictionary, t: float, cozy: bool) -> void:
	var goal: bool = tl.kpi is Dictionary and bool(tl.kpi.get("goal", false))
	var edge: Color = COLORS.y if goal else BEZEL
	_r(c, r.position.x, r.position.y, r.size.x, r.size.y, edge)
	_r(c, r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2, PANEL)
	for k in [Vector2(0, 0), Vector2(r.size.x - 1, 0), Vector2(0, r.size.y - 1), Vector2(r.size.x - 1, r.size.y - 1)]:
		_r(c, r.position.x + k.x, r.position.y + k.y, 1, 1, BG)  # the rounded corners
	var label_h := 7.0
	var label := str(tl.label)
	while _tw(label) > r.size.x - 4.0 and label.length() > 3:
		label = label.substr(0, label.length() - 1)
	_text(c, label, r.position.x + floorf((r.size.x - _tw(label)) * 0.5), r.end.y - label_h, LABEL)
	var digits := int(tl.digits)
	var dh := clampf(r.size.y - label_h - 5.0, 7.0, 26.0)
	var text := str(tl.text)
	var chars := text.replace(".", "").length()
	var gap := 2.0 if text.contains(".") else 1.0
	var cw := floorf(minf((r.size.x - 6.0) / float(digits) - gap, dh * 0.62))
	cw = maxf(cw, 4.0)
	var total := float(digits) * (cw + gap) - gap
	var x0 := r.position.x + floorf((r.size.x - total) * 0.5)
	var y0 := r.position.y + 3.0
	var col := _status_color(str(tl.status), cozy, t)
	var idx := digits - chars  # right aligned
	var cell := 0
	var i := 0
	while cell < digits:
		var ch := " "
		var dp := false
		if cell >= idx and i < text.length():
			ch = text[i]
			i += 1
			if i < text.length() and text[i] == ".":
				dp = true
				i += 1
		digit(c, ch, x0 + float(cell) * (cw + gap), y0, cw, dh, col, dp and cw >= 5.0)
		cell += 1
	if tl.has("trend") and r.size.y >= 18.0:
		_arrow(c, r.position.x + 3.0, r.position.y + 2.0, int(tl.trend), cozy)
	if tl.kpi is Dictionary and tl.kpi.has("met"):
		_tick(c, r.end.x - 8.0, r.position.y + 2.0, bool(tl.kpi.met))


static func _paint_chart(c: CanvasItem, r: Rect2, ch: Dictionary, grow: float) -> void:
	_r(c, r.position.x, r.position.y, r.size.x, r.size.y, PANEL)
	var title := str(ch.title)
	while _tw(title) > r.size.x - 4.0 and title.length() > 4:
		title = title.substr(0, title.length() - 1)
	var legend: bool = ch.series.size() > 1 and r.size.x >= 100.0
	var tx := r.position.x + 3.0 if legend else r.position.x + floorf((r.size.x - _tw(title)) * 0.5)
	_text(c, title, tx, r.position.y + 1, LABEL)
	var plot := Rect2(r.position + Vector2(11, 8), r.size - Vector2(15, 16))
	if r.size.y < 28.0:
		plot = Rect2(r.position + Vector2(11, 7), r.size - Vector2(15, 13))
	if plot.size.y < 8.0 or plot.size.x < 20.0:
		return
	var top := float(ch.max)
	var step := float(ch.step)
	var lines := int(round(top / step))
	for k in range(0, lines + 1):
		var gy := plot.end.y - plot.size.y * float(k) / float(lines)
		_r(c, plot.position.x, floorf(gy), plot.size.x, 1, GRID)
		if (k == lines or k == 0 or lines <= 2 or (k == lines / 2 and plot.size.y >= 34.0)) and plot.size.y >= 18.0:
			var v := int(step * float(k))
			var lab := str(v) if v < 1000 else "%dK" % int(v / 1000)
			_text(c, lab, plot.position.x - _tw(lab) - 2.0, gy - 2.0, DIM)
	_r(c, plot.position.x, plot.position.y, 1, plot.size.y, GRID)
	var labels: Array = ch.labels
	var n := labels.size()
	var series: Array = ch.series
	var k_series := series.size()
	var gw := plot.size.x / float(maxi(1, n))
	var bw := floorf((gw - 3.0) / float(k_series))
	bw = clampf(bw, 2.0, 12.0)
	var ext := 2.0 if bw >= 3.0 else 1.0
	var eased := 1.0 - pow(1.0 - clampf(grow, 0.0, 1.0), 3.0)
	for i in n:
		var gx := plot.position.x + gw * float(i) + floorf((gw - bw * float(k_series) - ext) * 0.5) + 1.0
		for s in k_series:
			var v := float(series[s].vals[i])
			var col: Array = BARS[str(series[s].color)]
			var bx := gx + bw * float(s)
			var bh := floorf(plot.size.y * v / top * eased)
			if bh < 1.0:
				_r(c, bx, plot.end.y - 1, bw, 1, Color(col[0].r, col[0].g, col[0].b, 0.25))
				continue
			var by := plot.end.y - bh
			_r(c, bx, by, bw, bh, col[0])
			c.draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + ext, by - ext), Vector2(bx + bw + ext, by - ext), Vector2(bx + bw, by)]), col[1])
			c.draw_colored_polygon(PackedVector2Array([Vector2(bx + bw, by), Vector2(bx + bw + ext, by - ext), Vector2(bx + bw + ext, by + bh - ext), Vector2(bx + bw, by + bh)]), col[2])
	var lw := 0.0
	for lab in labels:
		lw = maxf(lw, _tw(str(lab)))
	var every := maxi(1, int(ceilf((lw + 2.0) / gw)))
	for i in n:
		if i % every == 0:
			var lab := str(labels[i])
			_text(c, lab, plot.position.x + gw * float(i) + (gw - _tw(lab)) * 0.5, plot.end.y + 2.0, DIM)
	if legend:  # the legend, top right
		var lx := r.end.x - 4.0
		for s in range(k_series - 1, -1, -1):
			var nm := str(series[s].name)
			lx -= _tw(nm)
			_text(c, nm, lx, r.position.y + r.size.y - 6.0 if r.size.y < 28.0 else r.position.y + 1.0, DIM)
			lx -= 4.0
			_r(c, lx, r.position.y + (r.size.y - 5.0 if r.size.y < 28.0 else 2.0), 3, 3, BARS[str(series[s].color)][0])
			lx -= 4.0


# paint the whole dashboard into rect of the canvas item. t = seconds since it was opened (bars grow in over about a second, red tiles
# pulse, the clock colon blinks). opts: title (bool, default true), chart (0 / 1: which chart a wide layout shows, default it rotates),
# cozy (default Difficulty.cozy_on()), glance (a colour that frames the screen, the TV hint)
static func paint(c: CanvasItem, rect: Rect2, mode: String, t: float, opts := {}) -> void:
	var cozy := bool(opts.get("cozy", Difficulty.cozy_on()))
	var with_title := bool(opts.get("title", true))
	c.draw_rect(rect, BG)
	var lay := layout(rect, with_title)
	if with_title:
		var tr: Rect2 = lay.title
		_text(c, TITLE, tr.position.x + 3, tr.position.y + 1, Color("ffb347"))
		var clock := World.clock_text()
		if int(t * 2.0) % 2 == 1:
			clock = clock.replace(":", " ")
		var tag := "%s  %s" % [mode.to_upper(), clock]
		_text(c, tag, tr.end.x - _tw(tag) - 3.0, tr.position.y + 1, LABEL)
		_r(c, tr.position.x, tr.end.y - 1, tr.size.x, 1, GRID)
	var list := tiles(mode)
	for i in 10:
		_paint_tile(c, lay.tiles[i], list[i], t, cozy)
	var both := series(mode)
	var grow := clampf(t, 0.0, 1.0)
	if lay.kind == "wide":
		var which := int(opts.get("chart", int(t / 6.0) % 2)) % 2
		_paint_chart(c, lay.charts[0], both[which], grow)
	else:
		_paint_chart(c, lay.charts[0], both[0], grow)
		_paint_chart(c, lay.charts[1], both[1], grow)
	if opts.has("glance"):
		var gc: Color = opts.glance
		var frame := rect.grow(-0.0)
		_r(c, frame.position.x, frame.position.y, frame.size.x, 1, gc)
		_r(c, frame.position.x, frame.end.y - 1, frame.size.x, 1, gc)
		_r(c, frame.position.x, frame.position.y, 1, frame.size.y, gc)
		_r(c, frame.end.x - 1, frame.position.y, 1, frame.size.y, gc)


# ---- the computer app and the wall TV takeover (Computer.app "dash", Computer.tv_mode) ---------------------------------
# In the computer it sits in a window (the window title is the board title); on the TV it fills the screen under the faded strip, read only:
# Esc (or a click on the hint) closes it. A wide screen shows one chart at a time: Enter or a click on the chart swaps it.
static func paint_app(cp) -> void:
	var mode := mode_now()
	var opts := {}
	if cp.dash_chart >= 0:
		opts["chart"] = cp.dash_chart
	if cp.tv_mode:
		var area: Rect2 = cp._area
		paint(cp._canvas, area, mode, cp.dash_t, opts)
		var hint := "ESC CLOSES"
		var tr := Rect2(area.position.x + floorf((area.size.x - _tw(hint)) * 0.5) - 2.0, area.position.y, _tw(hint) + 4.0, 7.0)
		if area.size.x >= 170.0:
			cp._fill(tr, BG)
			_text(cp._canvas, hint, tr.position.x + 2.0, tr.position.y + 1.0, DIM)
			cp._region("close_app", tr)
		var lay := layout(area, true)
		if lay.kind == "wide":
			cp._region("dash:chart", lay.charts[0])
		return
	var body: Rect2 = cp._window(TITLE, Color("1c3b63"))
	if cp._offline("PIXEL IT METRICS CANNOT REACH THE SERVER.", body):
		return
	opts["title"] = false
	paint(cp._canvas, body, mode, cp.dash_t, opts)
	var lay2 := layout(body, false)
	if lay2.kind == "wide":
		cp._region("dash:chart", lay2.charts[0])
