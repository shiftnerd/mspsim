extends RefCounted
# gdlint:disable=class-definitions-order
# The metrics record (roadmap R20, docs/scope-dashboard.md): one entry per campaign day, {d, opened, closed, missed, hours: {who: h}},
# kept as a rolling window of WINDOW days and saved with the campaign (section "dash"; an old save has none and loads empty:
# the charts show zeros, nothing is invented). Msp hooks note tickets opened, closed and missed; Owner and Service add the hours
# the crew worked. The last entry is always today. Static, so it needs no autoload: `const Dash := preload("res://scripts/dash.gd")`.

const WINDOW := 21
const SHOWN := 14  # days on the opened / resolved chart and on the day report sparkline

static var days: Array = []
static var glanced := -1  # the day the glance hint (TV toast) last fired


static func blank(d: int) -> Dictionary:
	return {"d": d, "opened": 0, "closed": 0, "missed": 0, "hours": {}}


static func now() -> int:
	return Campaign.day if Campaign.active else World.day


static func reset() -> void:
	days = []
	glanced = -1


# a new morning: a fresh entry (a day that is already the last one is kept), the oldest drop out of the window
static func begin_day(d: int) -> void:
	if days.is_empty() or int(days[days.size() - 1].d) != d:
		days.append(blank(d))
	while days.size() > WINDOW:
		days.remove_at(0)
	glanced = -1


# today's entry (created on first use, so Free Play and a fresh run both have one)
static func today() -> Dictionary:
	if days.is_empty():
		days.append(blank(now()))
	return days[days.size() - 1]


static func note_opened() -> void:
	today().opened = int(today().opened) + 1


static func note_closed() -> void:
	today().closed = int(today().closed) + 1


static func note_missed() -> void:
	today().missed = int(today().missed) + 1


# game seconds of work by one person or the whole crew, stored as working hours (8 hours = one day_len)
static func add_hours(who: String, secs: float) -> void:
	if secs <= 0.0:
		return
	var h: Dictionary = today().hours
	h[who] = float(h.get(who, 0.0)) + secs * 8.0 / maxf(1.0, World.day_len)


# the last `count` days oldest first, padded in front with empty days so a short history still lines up: [{d, opened, closed, ...}]
static func recent(count := SHOWN) -> Array:
	var out := []
	var have := days.size()
	var last_d := int(days[have - 1].d) if have > 0 else now()
	for i in count:
		var idx := have - count + i
		if idx >= 0:
			out.append(days[idx])
		else:
			var e := blank(last_d - (count - 1 - i))
			out.append(e)
	return out


static func to_dict() -> Dictionary:
	return {"version": 1, "days": days.duplicate(true)}


# an old save (no section) or a damaged one loads empty
static func from_dict(data: Dictionary) -> void:
	days = []
	var saved: Variant = data.get("days", [])
	if saved is Array:
		for e in saved:
			if e is Dictionary and e.has("d"):
				var hours := {}
				var raw: Variant = e.get("hours", {})
				if raw is Dictionary:
					for k in raw:
						hours[str(k)] = float(raw[k])
				days.append({"d": int(e.d), "opened": int(e.get("opened", 0)), "closed": int(e.get("closed", 0)), "missed": int(e.get("missed", 0)), "hours": hours})
	while days.size() > WINDOW:
		days.remove_at(0)
	glanced = -1
