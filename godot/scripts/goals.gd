extends RefCounted
# gdlint:disable=max-line-length,max-returns
# R16 (cozy design review): the HUD's TODAY'S GOAL chip and NEXT-UP list. A static helper with no state: goal() is one
# line saying what the day wants from you, next_up() the next two or three things coming (things with a time first,
# then tonight, then tomorrow). Only what the player may already know is listed: the schedule (lunch, the all-hands,
# closing time, an outing after work, on call tonight, a calendar event of the season), never a surprise mail or card.
# Hud._draw calls draw(); a quick-play session (Micro) supplies its own goal line. Free Play shows nothing.

const PixelFont := preload("res://scripts/pixelfont.gd")
const Seasons := preload("res://scripts/seasons.gd")
const Micro := preload("res://scripts/micro.gd")
const MAX_NEXT := 3
const SHORT_NEXT := 2  # on the short wide screen (128 px): the chip stays above the wall TV
const GOAL_COLOR := Color("ffe08a")
const NEXT_COLOR := Color(0.86, 0.9, 0.96, 0.95)
const SHADE := Color(0.09, 0.07, 0.12, 0.9)
const BACK := Color(0.04, 0.03, 0.08, 0.5)
const LUNCH_AT := 12.0


static func shown() -> bool:
	return (Campaign.active or Micro.active()) and not Game.title_mode


# one line: what today wants from you
static func goal() -> String:
	if Micro.active():
		return Micro.goal()
	if not Campaign.active:
		return ""
	var open: int = Msp.open_tickets().size()
	match Campaign.mode:
		"tech":
			if Playbook.is_active():
				return "FINISH THE JOB: %s" % str(Playbook.BOOKS[str(Playbook.active.id)].title)
			if Onsite.active:
				return "FINISH UP HERE AND DRIVE BACK"
			if Onsite.has_open_job():
				return "VISIT A CLIENT: SEE THE PSA"
			if Campaign.day == 1 and Msp.closed_ok == 0:
				return "CLOSE YOUR FIRST TICKET" if open > 0 else "OPEN THE COMPUTER AT YOUR DESK"
			if open > 0:
				return "CLEAR THE QUEUE: %d OPEN" % open
			return "QUEUE CLEAR. STUDY OR SAY HI"
		"service":
			if open > 0:
				return "KEEP THE BOARD MOVING: %d OPEN" % open
			return "BOARD CLEAR. CHECK ON THE CREW"
		"sales":
			return "%s QUOTA %d%%: WORK THE PIPELINE" % [SalesCampaign.quarter_label(), SalesCampaign.quota_pct()]
		"owner":
			if Owner.cash < 0:
				return "GET THE CASH BACK ABOVE ZERO"
			return Owner.goal_title()
	return ""


static func _clock(at: float) -> String:
	return "%d:%02d" % [int(at), int(round((at - floorf(at)) * 60.0))]


# the next things coming, soonest first: [{at (clock, 99 = tonight, 100 = tomorrow), text}]
static func next_up(limit := MAX_NEXT) -> Array:
	var out := []
	if not Campaign.active or Micro.active():
		return out
	var now: float = World.clock
	var day: int = Campaign.day
	var weekly: bool = str(Campaign.prop("unit", "DAY")) == "WEEK"
	if not weekly and now < LUNCH_AT:
		out.append({"at": LUNCH_AT, "text": "%s LUNCH" % _clock(LUNCH_AT)})
	var ev: Dictionary = Seasons.event_today()
	if not ev.is_empty() and now < float(ev.at):
		out.append({"at": float(ev.at), "text": "%s %s" % [_clock(float(ev.at)), str(ev.name)]})
	if Meeting.is_meeting_day(day) and Meeting.done_day != day and now < Meeting.CALL_AT:
		out.append({"at": Meeting.CALL_AT, "text": "%s ALL-HANDS" % _clock(Meeting.CALL_AT)})
	if now < World.DAY_END:
		var close_text := "THE BOOKS CLOSE" if bool(Campaign.prop("books", false)) else "CLOSING TIME"
		out.append({"at": World.DAY_END, "text": "%s %s" % [_clock(World.DAY_END), close_text]})
	if (Campaign.mode == "tech" and Outings.TECH_DAYS.has(day)) or (Campaign.mode == "owner" and Outings.OWNER_WEEKS.has(day)):
		out.append({"at": 99.0, "text": "AFTER WORK: A TEAM OUTING"})
	if Shift.is_on_call():
		out.append({"at": 99.5, "text": "TONIGHT: ON CALL"})
	if day < Campaign.total_days():
		var unit := "WEEK" if weekly else "DAY"
		if Campaign.mode == "tech" and day + 1 == Expo.TRIP_DAY and Expo.qualified:
			out.append({"at": 100.0, "text": "TOMORROW: THE CONFERENCE TRIP"})
		for id in Seasons.tags(day + 1, Campaign.year):
			if not Seasons.tags(day, Campaign.year).has(id):
				out.append({"at": 100.5, "text": "NEXT %s: %s" % [unit, Seasons.season_name(str(id))]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	return out.slice(0, limit)


# the chip's text rows: ["GOAL: ...", "NEXT: ...", "      ...", ...] cut to max_chars
static func rows(max_chars: int, compact := false, limit := MAX_NEXT) -> Array:
	var out := []
	var g := goal()
	if g != "":
		out.append(_fit("GOAL: " + g, max_chars))
	if compact:
		return out
	var first := true
	for item in next_up(limit):
		out.append(_fit(("NEXT: " if first else "      ") + str(item.text), max_chars))
		first = false
	return out


static func _fit(text: String, max_chars: int) -> String:
	return text if text.length() <= max_chars else text.substr(0, maxi(1, max_chars - 1)) + "."


# Drawn by the HUD under its own lines. Wide screens: right-aligned under the clock (two next-up rows on the short
# 128 px screen); narrow ones (portrait): stacked under the left lines. `left_lines` = how many lines the HUD already drew on the left. Returns the rects it used.
static func draw(canvas: CanvasItem, left_lines: int) -> Array:
	var used := []
	if not shown():
		return used
	var size := canvas.get_viewport_rect().size
	var narrow := size.x < 260.0
	var max_chars := int((size.x - 8.0) / 4.0) if narrow else 38
	var list := rows(max_chars, Game.ui_open, SHORT_NEXT if size.y < 150.0 else MAX_NEXT)
	var y := 4.0 + float(left_lines) * 8.0 + 2.0 if narrow else 11.0
	var widest := 0.0
	for row in list:
		widest = maxf(widest, float(PixelFont.width(str(row))))
	if not list.is_empty():  # a soft dark plate, so the chip reads over the wall, the TV and the ceiling
		var px := 3.0 if narrow else size.x - widest - 3.0
		canvas.draw_rect(Rect2(px - 2.0, y - 2.0, widest + 4.0, float(list.size()) * 7.0 + 2.0), BACK)
	for i in list.size():
		var text := str(list[i])
		var w := float(PixelFont.width(text))
		var x := 3.0 if narrow else size.x - w - 3.0
		var color := GOAL_COLOR if i == 0 and text.begins_with("GOAL") else NEXT_COLOR
		PixelFont.draw(canvas, text, Vector2(x + 1.0, y + 1.0), SHADE)
		PixelFont.draw(canvas, text, Vector2(x, y), color)
		used.append(Rect2(x, y, w, 5.0))
		y += 7.0
	return used
