extends CanvasLayer
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# The yearly review at the end of the tech campaign (after day 20's report): your manager goes over the year, your
# coworkers weigh in, and you choose what comes next: become team lead, take an in-house IT job at a client, or stay
# an MSP tech. Offers depend on your reputation, your coworkers and how the big jobs went. Enter / Up / Down / click.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")
const GOOD := Color("1f7a3a")
const BAD := Color("b3262c")
const BLUE := Color("1f4e8c")
const GRADE_NAMES := {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1}
const JOBS := [
	["install", "NEW DESKTOP"],
	["ransom", "RANSOMWARE"],
	["rack", "RACK FELL OFF"],
	["migration", "SERVER MIGRATION"],
	["email24", "EMAIL OUTAGE"],
	["netinstall", "NETWORK INSTALL"],
	["rdp", "RDP BREAK-IN"],
	["ceofraud", "WIRE FRAUD EMAIL"],
	["no2fa", "TWO-STEP LOGINS"],
	["bus", "THE ONE WHO KNEW"],
]
const CLIENT_OF := {
	"rack": "Gnarly Gnomes",
	"migration": "Brightside Realty",
	"email24": "Soggy Bottom Brewing",
	"netinstall": "Hoot and Holler",
	"rdp": "Brightside Realty",
	"ceofraud": "Hoot and Holler",
	"no2fa": "Soggy Bottom Brewing",
	"bus": "Acme Dental",
}
const DEFAULT_QUOTES := {
	"FRIEND": "WORKING WITH YOU IS THE BEST PART OF MY DAY.",
	"FRIENDLY": "SOLID TEAMMATE. I WOULD WORK WITH YOU AGAIN.",
	"NEUTRAL": "DOES THE JOB. HARD TO READ.",
	"COLD": "KEEPS TO THEMSELVES. A BIT ABRUPT.",
	"HOSTILE": "HONESTLY? HARD TO WORK WITH.",
}
var QUOTES: Dictionary = DEFAULT_QUOTES.duplicate(true)
# what the two owners (Alan, Garrison) write in the yearly review instead
const DEFAULT_OWNER_QUOTES := {
	"FRIEND": "GLAD WE HIRED YOU. THE CLIENTS ASK FOR YOU BY NAME.",
	"FRIENDLY": "GOOD HIRE. I WOULD TRUST YOU WITH A CLIENT.",
	"NEUTRAL": "DOES THE JOB. NO COMPLAINTS ON MY DESK.",
	"COLD": "I SEE THE NUMBERS. I DO NOT SEE MUCH ELSE.",
	"HOSTILE": "WE NEED TO TALK ABOUT FIT. THE BOOKS DO NOT LIE.",
}
var OWNER_QUOTES: Dictionary = DEFAULT_OWNER_QUOTES.duplicate(true)
const DEFAULT_EPILOGUES := {
	"lead":
	(
		"YOU TAKE THE TEAM LEAD ROLE. MORE PAY, A PAGER AND THREE PEOPLE WHO NOW COME TO YOU WITH EVERYTHING. "
		+ "THE NEXT YEAR WILL BE A DIFFERENT KIND OF HARD."
	),
	"internal":
	(
		"YOU SWAP SIRENS FOR STEADY HOURS: ONE OFFICE, ONE NETWORK, NO ONE CALLING AT NIGHT. "
		+ "YOU WILL MISS THE CHAOS A LITTLE."
	),
	"stay":
	"YOU STAY A TECH AT PIXEL IT PARTNERS. ALAN AND GARRISON KEEP THE BUSINESS RUNNING, YOU KEEP THE TICKETS MOVING. SAME DESK, A LOT MORE SKILL.",
}
var EPILOGUES: Dictionary = DEFAULT_EPILOGUES.duplicate(true)

var is_open := false
var page := 0
var sel := 0
var ending := ""
var offers: Array = []

var _canvas: Node2D
var _mouse := Vector2.ZERO
var _hits: Array = []
var _fade := 0.0


func _ready() -> void:
	layer = 72
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)


func start() -> void:
	page = 0
	sel = 0
	ending = ""
	offers = make_offers()
	is_open = true
	Game.ui_open = true
	_canvas.visible = true
	_mouse = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	create_tween().tween_method(_set_fade, _fade, 1.0, 0.3)
	_canvas.queue_redraw()


func _set_fade(value: float) -> void:
	_fade = value
	_canvas.modulate.a = value


# clients you cost their data (a lost ransomware recovery, a wiped desktop) never offer you a job
func burned_clients() -> Array:
	var out := []
	if str(Story.flags.get("ransom", "")) == "lost":
		out.append(str(Msp.CLIENTS[Story.RANSOM_CLIENT].name))
	if str(Story.flags.get("install", "")) == "lost" and not Msp.project.is_empty():
		out.append(str(Msp.CLIENTS[int(Msp.project.client)].name))
	return out


func _is_burned(short_name: String) -> bool:
	for full in burned_clients():
		if str(full).begins_with(short_name):
			return true
	return false


func best_client() -> String:
	var best := ""
	var best_rank := 0
	for key in CLIENT_OF:
		var rank := int(GRADE_NAMES.get(str(Story.flags.get(key, "")), 0))
		if rank > best_rank and not _is_burned(str(CLIENT_OF[key])):
			best_rank = rank
			best = str(CLIENT_OF[key])
	if best == "":
		for name in ["Acme Dental", "Piedmont Pediatrics", "Zen Garden Yoga"]:
			if not _is_burned(name):
				return name
	return best


func make_offers() -> Array:
	if Campaign.mode == "owner":
		return Owner.offers()
	var out := []
	if Campaign.rep >= (55 if Growth.graduated else 60) and Social.average() >= 0.0:
		(
			out
			. append(
				{
					"id": "lead",
					"label": "BECOME TEAM LEAD",
					"desc":
					"MORGAN AND THE OWNERS WANT YOU TO RUN THE SERVICE DESK: MORE PAY, MORE PEOPLE, MORE PAGER.",
				}
			)
		)
	if Campaign.rep >= 45:
		(
			out
			. append(
				{
					"id": "internal",
					"label": "JOIN %s AS IN-HOUSE IT" % best_client().to_upper(),
					"desc":
					(
						"%s OFFERS YOU THEIR ONLY IT JOB: CALM HOURS, ONE NETWORK, NO NIGHTS."
						% best_client().to_upper()
					),
				}
			)
		)
	(
		out
		. append(
			{
				"id": "stay",
				"label": "STAY AN MSP TECH",
				"desc":
				(
					"KEEP YOUR DESK, YOUR PHONES AND YOUR CHAOS."
					if Campaign.rep >= 45
					else "ON NOTICE: PROVE YOURSELF NEXT YEAR."
				),
			}
		)
	)
	return out


func choose(index: int) -> void:
	ending = str(offers[clampi(index, 0, offers.size() - 1)].id)
	page = _end_page()
	_canvas.queue_redraw()


# the owner review has a PARTNERSHIP page (X5), so its offers and its end come one page later
func _opt_page() -> int:
	return 3 if Campaign.mode == "owner" else 2


func _end_page() -> int:
	return _opt_page() + 1


func finish() -> void:
	if not is_open:
		return
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_canvas.visible = false
	_fade = 0.0
	Career.add("endings")
	Campaign.finish_campaign(ending)


func advance() -> void:
	if page == _opt_page():
		choose(sel)
	elif page == _end_page():
		finish()
	else:
		page += 1
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		_mouse = get_viewport().get_mouse_position()
		_canvas.queue_redraw()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_mouse = get_viewport().get_mouse_position()
		for i in range(_hits.size() - 1, -1, -1):
			if _hits[i].r.has_point(_mouse):
				if str(_hits[i].id) == "next":
					advance()
				else:
					sel = int(_hits[i].id)
					choose(sel)
				break
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			advance()
		elif event.keycode == KEY_UP and page == _opt_page():
			sel = maxi(0, sel - 1)
			_canvas.queue_redraw()
		elif event.keycode == KEY_DOWN and page == _opt_page():
			sel = mini(offers.size() - 1, sel + 1)
			_canvas.queue_redraw()
	else:
		return
	get_viewport().set_input_as_handled()


# ---- the pages ------------------------------------------------------------------------------
func _job_line(key: String, label: String) -> Array:
	var value := str(Story.flags.get(key, ""))
	if key == "install":
		return [
			label,
			{"ok": "PERFECT", "restored": "HAD A BACKUP", "lost": "DATA LOST"}.get(value, "-"),
			value == "lost"
		]
	if key == "ransom":
		return [
			label,
			(
				{
					"saved": "SAVED BY BACKUP",
					"lost": "NO BACKUP!",
					"paid": "PAID THE RANSOM",
					"partial": "PARTIAL RECOVERY"
				}
				. get(str(Story.flags.get("ransom", "")), "-")
			),
			Story.flags.get("ransom", "") == "lost"
		]
	return [label, "GRADE " + value if value != "" else "-", value == "D"]


func page_lines() -> Array:
	if Campaign.mode == "owner":
		return Owner.review_lines(page, ending)
	var lines := []
	match page:
		0:
			lines.append(["MORGAN REYES - MANAGER", BLUE])
			lines.append(["TWENTY DAYS DONE. LET US LOOK AT THE YEAR.", INK])
			lines.append(["REPUTATION %d   CASH $%d" % [Campaign.rep, Campaign.cash], INK])
			lines.append(
				[
					(
						"CLOSED %d   SLA MISSED %d   REOPENED %d"
						% [Msp.closed_ok, Msp.breached, Msp.reopened]
					),
					INK
				]
			)
			var best_skill := "powershell"
			for key in Skills.NAMES:
				if Skills.level(key) > Skills.level(best_skill):
					best_skill = key
			lines.append(
				[
					(
						"LEVELS: PS %d NET %d SRV %d SEC %d CUS %d (BEST %s)"
						% [
							Skills.level("powershell"),
							Skills.level("networking"),
							Skills.level("servers"),
							Skills.level("security"),
							Skills.level("people"),
							Skills.NAMES[best_skill]
						]
					),
					INK
				]
			)
			if Shift.enabled:
				lines.append(
					[
						"HOURS: " + Shift.summary() + "   OUTINGS %d" % Outings.count,
						BAD if Shift.late_total >= 5 else INK
					]
				)
			if Growth.status_line() != "":
				lines.append([Growth.status_line(), GOOD if Growth.graduated else INK])
			for job in JOBS:
				var row := _job_line(job[0], job[1])
				lines.append(
					[
						"%s: %s" % [row[0], row[1]],
						BAD if row[2] else (GOOD if row[1] != "-" else INK),
						"job"
					]
				)
		1:
			lines.append(["WHAT THE OWNERS AND YOUR TEAM SAY", BLUE])
			for who in Social.people():
				var quotes: Dictionary = OWNER_QUOTES if Social.is_owner(who) else QUOTES
				var tag := ", CO-OWNER" if Social.is_owner(who) else ""
				lines.append(["%s%s (%s):" % [who.to_upper(), tag, Social.mood(who)], BLUE])
				lines.append(["'%s'" % quotes[Social.mood(who)], INK])
		2:
			lines.append(["YOUR OPTIONS", BLUE])
		_:
			lines.append(["THE END", BLUE])
			lines.append([str(EPILOGUES.get(ending, "")), INK])
			if ending == "internal":
				lines.append(["YOUR NEW DESK IS AT %s." % best_client().to_upper(), INK])
	return lines


func _wrap(s: String, chars: int) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		if line != "" and line.length() + 1 + word.length() > chars:
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	out.append(line)
	return out


func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_hits.clear()
	var sc := 1
	var u := float(sc)
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.88))
	var pw := minf(size.x - 8.0, 250.0 * u)
	var chars := int((pw - 10.0 * u) / (4.0 * u))
	var rows := []
	var held: Array = []  # job lines sit two to a row when the panel is wide enough
	for entry in page_lines():
		if entry.size() > 2 and chars >= 58:
			if held.is_empty():
				held = entry
				continue
			rows.append([held[0], held[1], entry[0], entry[1]])
			held = []
			continue
		if not held.is_empty():
			rows.append([held[0], held[1]])
			held = []
		for wrapped in _wrap(str(entry[0]), chars):
			rows.append([wrapped, entry[1]])
	if not held.is_empty():
		rows.append([held[0], held[1]])
	var extra := 0.0
	if page == _opt_page():
		extra = float(offers.size()) * 11.0 * u + 3.0 * u + 24.0 * u
	var ph := (12.0 + float(rows.size()) * 7.0 + 18.0) * u + extra
	ph = minf(ph, size.y - 4.0)
	var panel := Rect2(floorf((size.x - pw) * 0.5), floorf((size.y - ph) * 0.5), pw, ph)
	_canvas.draw_rect(panel, Color("e9ecf1"))
	_canvas.draw_rect(Rect2(panel.position, Vector2(pw, 9.0 * u)), BLUE)
	var heading := "BOARD REVIEW" if Campaign.mode == "owner" else "YEARLY REVIEW"
	PixelFont.draw(_canvas, heading, panel.position + Vector2(3.0 * u, 2.0 * u), WHITE, sc)
	var y := panel.position.y + 12.0 * u
	for row in rows:
		PixelFont.draw(_canvas, str(row[0]), Vector2(panel.position.x + 5.0 * u, y), row[1], sc)
		if row.size() > 2:
			var col_x: float = panel.position.x + (5.0 + 4.0 * 30.0) * u
			PixelFont.draw(_canvas, str(row[2]), Vector2(col_x, y), row[3], sc)
		y += 7.0 * u
	if page == _opt_page():
		y += 3.0 * u
		for i in offers.size():
			var r := Rect2(panel.position.x + 4.0 * u, y, pw - 8.0 * u, 10.0 * u)
			var chosen := i == sel
			_canvas.draw_rect(r, Color("f5d442") if chosen else Color("c9d2e0"))
			PixelFont.draw(
				_canvas, str(offers[i].label), r.position + Vector2(3.0 * u, 2.0 * u), INK, sc
			)
			_hits.append({"r": r, "id": str(i)})
			y += 11.0 * u
		y += 2.0 * u
		for wrapped in _wrap(str(offers[sel].desc), chars):
			PixelFont.draw(
				_canvas, wrapped, Vector2(panel.position.x + 5.0 * u, y), Color("46506a"), sc
			)
			y += 7.0 * u
	else:
		var label := "FINISH" if page == _end_page() else "NEXT"
		var bw := float(PixelFont.width(label, sc)) + 12.0 * u
		var b := Rect2(panel.end.x - bw - 4.0 * u, panel.end.y - 12.0 * u, bw, 9.0 * u)
		_canvas.draw_rect(b, Color("5aa0e8") if b.has_point(_mouse) else Color("3a7bd5"))
		PixelFont.draw(_canvas, label, b.position + Vector2(6.0 * u, 2.0 * u), WHITE, sc)
		_hits.append({"r": b, "id": "next"})
	var m := _mouse.floor()
	for i in 6:
		_canvas.draw_rect(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
