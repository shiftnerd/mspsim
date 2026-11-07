extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Year 2 / New Game Plus (roadmap R10b, docs/replayability-ideas.md 3.2 and 3.3).
#
# Finishing a campaign (Campaign.finish_campaign, after the review or the board review) records the mode, the ending
# id, the final reputation, the company value / partner trust / skill levels, the difficulty and the year in the meta
# file (`user://mspsim_meta.cfg`, one section per mode). A mode whose registry row says `"year2": true` and that has
# been finished gets a title menu entry NEW GAME PLUS - <MODE> (YEAR 2). It opens the usual character select (the
# point-buy step gets +2 points) plus a MUT chip: AUTO, PICK <mutator> or BAN <mutator> (keys M and B).
#
# Year 2 is a number on the run: `Campaign.year` (1 = the normal game, 2 = Year 2; saved as `campaign/year`, an old
# save has none and loads as 1). Everything below is READ by existing functions through this autoload, so a Year 1
# run behaves exactly as before (tests/yeartwo.gd checks the neutral values):
#   CARRY   what comes over from the finished run: skills (a capped level), reputation (a fraction), the owner's company
#           value as a capped bit of start cash, the partner's trust, +2 build points. Career and Outings.known live
#           outside the campaign slot and simply stay.
#   YEAR2   what is harder: SLA clocks (Mutators.sla), the ticket weights and P1 share (Mutators.ticket_weights /
#           priority), the three newer clients active from day 1 (Sales.reset / max_clients), one tier more mutators
#           (Mutators.make_plan), the story shuffle (Story.events_on / Owner.events_on), the Year 2 beat cards that set
#           choice flags (`Story.flags["y2"]`, saved with the campaign) and the extra endings those flags unlock.
#   TEXT    the intro card, the beat cards, the offers and the epilogues (patchable like the rest).
# A new mode (service, sales) plugs in by getting `"year2": true` in Campaign.MODE_DEFS and rows in YEAR2.beats /
# YEAR2.shuffle / YEAR2.endings and TEXT; nothing else in this file names a mode except the day tables of `_base`.

const RivalTouches := preload("res://scripts/rival_touches.gd")  # R38 P6: the Standard carry-over and the Year 2 rival
const VERSION := 1
const YEAR := 2
const DEFAULT_CARRY := {
	"skills": {"offset": -1, "cap": 3, "text": "SKILLS CARRY OVER ONE LEVEL LOWER, NEVER ABOVE 3."},
	"powershell": {"offset": 0, "cap": 3, "text": "POWERSHELL LESSONS YOU PASSED COUNT AS YOUR LEVEL, UP TO 3."},
	"rep": {"fraction": 0.6, "min": 40, "max": 70, "text": "REPUTATION RESTARTS AT 60 PERCENT OF WHERE YOU ENDED (40 AT LEAST)."},
	"cash": {"fraction": 0.01, "cap": 5000, "text": "ONE PERCENT OF THE COMPANY VALUE BECOMES START CASH, UP TO $5000."},
	"trust": {"min": 40, "max": 75, "text": "YOUR PARTNER'S TRUST CARRIES OVER (BETWEEN 40 AND 75)."},
	"build": {"points": 2, "text": "TWO EXTRA BUILD POINTS."},
}
var CARRY: Dictionary = DEFAULT_CARRY.duplicate(true)
const DEFAULT_YEAR2 := {
	"sla": {"mult": 0.85, "text": "SLA CLOCKS RUN 15 PERCENT TIGHTER."},
	"tickets": {
		"weights": {"spooler": 1.7, "av": 1.7, "password": 1.3, "server": 1.6},
		"p1_promote": 0.12,
		"text": "MORE PRINTER AND SECURITY TICKETS, AND MORE OF THEM ARE P1.",
	},
	"clients": {
		"client": ["Paws and Claws Veterinary", "Lindqvist and Moss Architects", "Iron Mule Demolition"],
		"max": 10,
		"text": "THREE NEW CLIENTS ARE ON THE BOOKS FROM DAY ONE.",
	},
	"mutators": {
		"counts": {"easy": [2, 3], "normal": [4, 5], "hard": [5, 6]},
		"text": "ONE TIER MORE MUTATORS.",
	},
	"shuffle": {
		"max_shift": 2,
		"text": "THE YEAR'S BIG JOBS MOVE AROUND BY A DAY OR TWO.",
		"tech": {
			"min_day": 3,
			"books": ["rdp", "ceofraud", "rack", "migration", "no2fa", "netinstall", "bus"],
			"vignettes": ["iphone", "heartbleed", "candy", "pizza", "win8", "selfreview"],
			"linked": {"donuts": "bus"},
			"fixed": ["email24", "ransomware", "install"],
		},
		"owner": {
			"min_day": 3,
			"events": ["qbr", "profit_review", "grumble", "vic_report"],
			"fixed": ["ransomware", "poach_wave", "vendor_breach", "client_breach"],
		},
	},
	"beats": {"tech": {"courted": 6, "desk": 11}, "owner": {"merger": 10, "franchise": 15}, "service": {"headhunt": 8}, "sales": {"poach": 9, "director": 14}},
	"endings": {"tech": ["head", "clientbuy"], "owner": ["merger", "franchise"]},
}
var YEAR2: Dictionary = DEFAULT_YEAR2.duplicate(true)
const DEFAULT_TEXT := {
	"intro": {
		"speaker": "YEAR 2",
		"text": "A NEW YEAR AT PIXEL IT PARTNERS. YOU KEEP WHAT YOU LEARNED, THE CLIENTS EXPECT MORE.",
	},
	"beats": {
		"tech": {
			"courted": {
				"speaker": "Tony Marsh (Iron Mule Demolition)",
				"text": "Between you and me: if you ever want out of the MSP life, I would pay Pixel a buyout fee and put you on my payroll as the IT director. Nothing to decide today.",
				"options": [
					{"label": "I AM LISTENING", "id": "listen", "reply": "Tony grins and slides over a business card with a hard hat on it.", "fx": {}},
					{"label": "TELL MORGAN FIRST", "id": "told", "reply": "Tony nods. Morgan hears it from you and quietly approves.", "fx": {"social": {"Morgan": 2}}},
					{"label": "THANKS, NO", "id": "no", "reply": "Tony shrugs. The offer stays open, he says, like a garage door.", "fx": {"rep": 1}},
				],
			},
			"desk": {
				"speaker": "Morgan (Manager)",
				"text": "I am at the vendor summit for a week. Could you run the morning stand-up and look after the desk schedule while I am gone?",
				"options": [
					{"label": "I WILL RUN THE DESK", "id": "run", "reply": "Morgan hands over the clipboard and the good pen. The team behaves, mostly.", "fx": {"xp": ["people", 8], "social_all": 1}},
					{"label": "MAYBE NEXT TIME", "id": "pass", "reply": "Morgan asks Dan instead and does not mention it again.", "fx": {}},
				],
			},
		},
		"service": {
			"headhunt": {
				"speaker": "Terry Vance (Recruiter)",
				"text": "I recruit for a bigger MSP across town. I hear your desk runs itself now. Anyone on your crew who would take a call? I pay a finder's fee for names.",
				"options": [
					{"label": "NOT MY CREW", "id": "no", "reply": "Terry smiles. Everybody says that until the offer is bigger.", "fx": {"rep": 1}},
					{"label": "ASK THEM ABOUT IT", "id": "ask", "reply": "Your crew is flattered and a little nervous. Morgan hears about it by lunch.", "fx": {"social_all": 1}},
					{"label": "GIVE HIM A NAME", "id": "name", "reply": "Terry writes it on a napkin. Somebody's phone buzzes before Friday.", "fx": {"rep": -2, "social_all": -1}},
				],
			},
		},
		"sales": {
			"poach": {
				"speaker": "Greg Pell (ByteBrothers)",
				"text": "You closed more than my whole team last year. ByteBrothers would pay you a signing bonus and a nicer tie. One lunch, no commitment.",
				"options": [
					{"label": "TELL GARRISON", "id": "told", "reply": "Garrison laughs, then asks what they offered. Then he matches half of it.", "fx": {"social": {"Garrison": 2}}},
					{"label": "KEEP IT TO YOURSELF", "id": "quiet", "reply": "Pell nods. The offer has a long shelf life, he says.", "fx": {}},
					{"label": "GO TO LUNCH", "id": "talk", "reply": "Pell buys lunch and a second dessert. Your phone shows a missed call from Garrison.", "fx": {"social": {"Garrison": -2}}},
				],
			},
			"director": {
				"speaker": "Garrison (Owner)",
				"text": "Same quota, new title. I want you running the sales side, and Wes reports to you now. You still close your own deals. You also answer for his.",
				"options": [
					{"label": "TAKE THE CHAIR", "id": "take", "reply": "Garrison hands you a key to the good filing cabinet. Wes salutes, then sits down fast.", "fx": {"xp": ["people", 8], "social": {"Garrison": 2}}},
					{"label": "STAY A CLOSER", "id": "closer", "reply": "Garrison sighs, then grins. Somebody has to keep selling, he says.", "fx": {"rep": 1}},
					{"label": "RAISE FIRST", "id": "raise", "reply": "Alan hears about it from the hallway. A title is not a salary, he says.", "fx": {"social": {"Alan": -1, "Garrison": 1}}},
				],
			},
		},
		"owner": {
			"merger": {
				"speaker": "Walt Reiner (Tri-County Tech Group)",
				"text": "I run the biggest shop in three counties and I like how yours is run. Lunch? I would like to talk about putting our names on one door.",
				"options": [
					{"label": "TAKE THE MEETING", "id": "talks", "reply": "Walt orders for both of you and asks for your client list on a napkin.", "fx": {}},
					{"label": "NOT INTERESTED", "id": "no", "reply": "Walt shakes your hand anyway. He has a long memory and a short lunch break.", "fx": {}},
				],
			},
			"franchise": {
				"speaker": "Pat Okafor (Consultant)",
				"text": "Your runbooks are better than most. Two shops in other towns would pay to use your name and your procedures. A pilot costs $1,500 for the binders and the signs.",
				"options": [
					{"label": "START A PILOT ($1500)", "id": "pilot", "reply": "Pat prints thirty binders. Christy frames the first invoice.", "fx": {"cash": -1500}, "need": 1500},
					{"label": "MAYBE LATER", "id": "later", "reply": "Pat leaves a folder on your desk. It stays there, glowing.", "fx": {}},
				],
			},
		},
	},
	"offers": {
		"head": {
			"label": "BECOME DEPARTMENT HEAD",
			"desc": "MORGAN MOVES UP AND THE OWNERS GIVE YOU THE WHOLE SERVICE DEPARTMENT: THE DESK, THE SCHEDULE AND THE BUDGET.",
		},
		"clientbuy": {
			"label": "LET IRON MULE BUY OUT YOUR CONTRACT",
			"desc": "TONY MARSH PAYS PIXEL A BUYOUT FEE AND MAKES YOU HIS IT DIRECTOR.",
		},
		"merger": {
			"label": "MERGE WITH TRI-COUNTY TECH GROUP",
			"desc": "A BIGGER SHOP, A BIGGER NOC AND BOTH NAMES ON THE DOOR. THEY VALUE YOUR SIDE AT ABOUT ${value}.",
		},
		"franchise": {
			"label": "LICENSE THE PIXEL IT NAME",
			"desc": "TWO SHOPS IN OTHER TOWNS RUN ON YOUR BINDERS AND PAY YOU A FEE. THE BRAND GOES REGIONAL.",
		},
	},
	"habits": {
		"carry": "YOUR GOOD HABITS COME OVER AT 60 PERCENT OF LAST YEAR'S STANDARD.",
		"rival_note": "BIG CHEESE IS GONE. HARD RIND IT HAS THE SAME FLYERS AND THE SAME HABITS.",
		"rival": {
			"name": "HARD RIND IT",
			"owner": "LYLE PRUITT",
			"blurb": "Hard Rind IT Services. Everything included, $41 a seat. Same flyers, new paint. Booked solid.",
		},
	},
	"endings": {
		"head": "YOU TAKE THE DEPARTMENT HEAD JOB. A DOOR WITH YOUR NAME ON IT, A BUDGET MEETING EVERY MONDAY AND A TEAM THAT LEARNED HOW TO RUN WITHOUT YOU WATCHING.",
		"clientbuy": "IRON MULE PAYS PIXEL THE BUYOUT FEE. YOUR NEW OFFICE SMELLS OF SAWDUST AND COFFEE, AND TONY MARSH TELLS EVERYONE HE HIRED THE BEST TECH IN THE COUNTY.",
		"merger": "THE PAPERS ARE SIGNED. TRI-COUNTY TECH GROUP AND PIXEL IT PARTNERS BECOME ONE SHOP WITH TWO LOGOS AND ONE VERY LONG ALL-HANDS. YOUR SIDE IS WORTH ABOUT ${value}.",
		"franchise": "TWO SHOPS IN OTHER TOWNS HANG A PIXEL IT SIGN AND RUN YOUR BINDERS. THE PHONE STILL RINGS IN YOUR OFFICE FIRST. CHRISTY ORDERS MORE FRAMES.",
	},
}
var TEXT: Dictionary = DEFAULT_TEXT.duplicate(true)

var pending := false  # New Game Plus was chosen on the title menu: the next Campaign.new_game takes it
var pick := ""  # a mutator the plan must contain ("" = AUTO)
var ban := ""  # a mutator the plan must not contain
var mut_mode := "pick"  # what the character select chip does with the chosen mutator: "pick" or "ban"
var moves: Array = []  # the story shuffle: [{mode, key, from, to}]
var carried: Dictionary = {}  # what this run took over from the last one (shown on the intro card, saved)
var prev: Dictionary = {}  # the meta record of the finished run this one follows


func reset() -> void:
	moves = []
	carried = {}
	prev = {}
	RivalTouches.rival_year(1)


# ---- the meta record (unlock) ---------------------------------------------------------------------------------
func meta_path() -> String:
	return Campaign.save_prefix + "meta.cfg"


func meta_get(mode: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(meta_path()) != OK or not cfg.has_section(mode):
		return {}
	var out := {}
	for key in cfg.get_section_keys(mode):
		out[key] = cfg.get_value(mode, key)
	return out


# finish_campaign calls this with the open meta file, after it wrote the ending id
func record(meta: ConfigFile, mode: String, ending: String) -> void:
	var done := int(meta.get_value(mode, "finished", 0)) + 1
	meta.set_value(mode, "finished", done)
	meta.set_value(mode, "ending", ending)
	meta.set_value(mode, "year", maxi(1, Campaign.year))
	meta.set_value(mode, "rep", Campaign.rep)
	meta.set_value(mode, "tier", Difficulty.tier)
	meta.set_value(mode, "cozy", Difficulty.cozy_on())  # R16: a cozy run is tagged; it still unlocks Year 2
	meta.set_value(mode, "seed", Difficulty.run_seed)
	meta.set_value(mode, "clients", Sales.active.size())
	var levels := {}
	for key in Skills.NAMES:
		levels[key] = Skills.level(str(key))
	meta.set_value(mode, "skills", levels)
	var books := Campaign.books_active()
	meta.set_value(mode, "value", Owner.valuation() if books else 0)
	meta.set_value(mode, "cash", Owner.cash if books else Campaign.cash)
	meta.set_value(mode, "trust", Partner.trust)
	meta.set_value(mode, "shop", Shop.owned.duplicate())
	meta.set_value(mode, "standard", RivalTouches.standard_now() if books else 0)  # R38: the Standard comes over at 60 percent
	if books:
		RivalTouches.note_year_end()
	if Campaign.year >= YEAR:
		Career.add("year2_done")


# can this mode start a Year 2? (the registry row allows it and a run of it has been finished)
func available(mode: String) -> bool:
	if not Campaign.is_selectable(mode) or not bool(Campaign.prop("year2", false, mode)):
		return false
	var rec := meta_get(mode)
	return int(rec.get("finished", 1 if str(rec.get("ending", "")) != "" else 0)) > 0


# R17: what a START YEAR 2 run keeps from the finished one, as one short line for the title menu row
func carry_summary(mode: String) -> String:
	var rec := meta_get(mode)
	if rec.is_empty():
		return ""
	var kept := carry_for(mode, rec)
	var parts := ["REP %d" % int(kept.rep)]
	if int(kept.cash) > 0:
		parts.append("$%d CASH" % int(kept.cash))
	if int(kept.trust) >= 0 and mode == "owner":
		parts.append("TRUST %d" % int(kept.trust))
	var levels := 0
	for key in kept.skills:
		levels += int(kept.skills[key])
	if levels > 0 or int(kept.ps) > 0:
		parts.append("SKILLS KEPT")
	return ", ".join(parts)


# the title menu rows (one per finished mode)
func menu_items() -> Array:
	var out := []
	for mode in Campaign.MODE_DEFS:
		if available(str(mode)):
			out.append({"label": "NEW GAME PLUS - %s (YEAR 2)" % str(mode).to_upper(), "id": "%s_y2" % str(mode), "enabled": true})
	return out


# the " - YEAR 2" mark of a saved run for the CONTINUE entries
func saved_tag(mode: String, for_slot := 0) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(Campaign.save_path(mode, for_slot)) != OK:
		return ""
	return " (YEAR 2)" if int(cfg.get_value("campaign", "year", 1)) >= YEAR else ""


# ---- choosing it on the character select ---------------------------------------------------------------------------
# the screen opens (setup): remember the choice; a normal run clears it
func begin_select(mode: String, year2: bool) -> void:
	pending = year2 and available(mode)
	pick = ""
	ban = ""
	mut_mode = "pick"


func take_pending(mode: String) -> bool:
	var yes := pending and available(mode)
	pending = false
	prev = meta_get(mode) if yes else {}
	return yes


func active() -> bool:
	return Campaign.active and Campaign.year >= YEAR


# the build step is open for a Year 2 run, or one is running
func build_bonus() -> int:
	return int(CARRY.build.points) if (pending or active()) else 0


# the ids the chip cycles through (AUTO first)
func mutator_ids(mode: String) -> Array:
	var out := [""]
	out.append_array(Mutators.ids_for(mode))
	return out


func change_mut(mode: String, step: int) -> void:
	var ids := mutator_ids(mode)
	var cur := pick if mut_mode == "pick" else ban
	var i := maxi(0, ids.find(cur))
	var next := str(ids[(i + step + ids.size()) % ids.size()])
	pick = next if mut_mode == "pick" else ""
	ban = next if mut_mode == "ban" else ""


func toggle_mut_mode() -> void:
	var cur := pick if mut_mode == "pick" else ban
	mut_mode = "ban" if mut_mode == "pick" else "pick"
	pick = cur if mut_mode == "pick" else ""
	ban = cur if mut_mode == "ban" else ""


func chip_text() -> String:
	var id := pick if pick != "" else ban
	if id == "":
		return "MUT  AUTO"
	var label := str(Mutators.MUTATORS.get(id, {}).get("name", id)).to_upper()
	if label.length() > 13:
		label = label.substr(0, 12) + "."
	return "%s %s" % ["PICK" if pick != "" else "BAN", label]


# ---- the numbers other scripts read ------------------------------------------------------------------------------
func sla_mult() -> float:
	return float(YEAR2.sla.mult) if active() else 1.0


func ticket_weights() -> Dictionary:
	return YEAR2.tickets.weights if active() else {}


# a P2 ticket that becomes P1 (drawn from the year2 stream; never in Year 1)
func promote() -> bool:
	if not active():
		return false
	return Difficulty.rng("year2.p1").randf() < float(YEAR2.tickets.p1_promote)


func max_clients(base: int) -> int:
	return maxi(base, int(YEAR2.clients.max)) if active() else base


# Mutators.make_plan: the count range of the tier, one tier up in Year 2
func counts(tier: String, normal: Array) -> Array:
	if not active():
		return normal
	return YEAR2.mutators.counts.get(tier, normal)


func without_banned(ids: Array) -> Array:
	if not active() or ban == "" or pick != "":
		return ids
	var out := []
	for id in ids:
		if str(id) != ban:
			out.append(id)
	return out


# Mutators.start: the picked mutator is in the plan (it takes over one entry)
func apply_pick(plan: Array, mode: String) -> Array:
	if not active() or pick == "" or not Mutators.MUTATORS.has(pick):
		return plan
	for e in plan:
		if str(e.id) == pick:
			return plan
	var slots: Array = Mutators.slots_for(mode)
	if plan.is_empty():
		plan.append({"id": pick, "from": int(slots[0]), "to": int(slots[0])})
		return plan
	var r := Difficulty.rng("year2")
	var at := r.randi_range(0, plan.size() - 1)
	var e: Dictionary = plan[at]
	var next_from := 9999
	if at + 1 < plan.size():
		next_from = int(plan[at + 1].from)
	var to := int(e.from)
	while to - int(e.from) + 1 < Mutators.duration_of(pick, mode) and slots.has(to + 1) and to + 1 < next_from:
		to += 1
	plan[at] = {"id": pick, "from": int(e.from), "to": to}
	return plan


# ---- carrying over ---------------------------------------------------------------------------------------------
# the rules applied to a meta record: pure, so tests can feed it any record
func carry_for(_mode: String, rec: Dictionary) -> Dictionary:
	var out := {"rep": Campaign.START_REP, "skills": {}, "ps": 0, "cash": 0, "trust": -1}
	if rec.is_empty():
		return out
	var rep_row: Dictionary = CARRY.rep
	out["rep"] = clampi(roundi(float(rec.get("rep", Campaign.START_REP)) * float(rep_row.fraction)), int(rep_row.min), int(rep_row.max))
	var sk_row: Dictionary = CARRY.skills
	var saved: Dictionary = rec.get("skills", {}) if rec.get("skills", {}) is Dictionary else {}
	for key in Skills.NAMES:
		if str(key) == "powershell":
			continue
		out.skills[key] = clampi(int(saved.get(key, 0)) + int(sk_row.offset), 0, int(sk_row.cap))
	var ps_row: Dictionary = CARRY.powershell
	out["ps"] = clampi(int(saved.get("powershell", 0)) + int(ps_row.offset), 0, int(ps_row.cap))
	var cash_row: Dictionary = CARRY.cash
	out["cash"] = clampi(roundi(float(rec.get("value", 0)) * float(cash_row.fraction)), 0, int(cash_row.cap))
	var trust_row: Dictionary = CARRY.trust
	out["trust"] = clampi(int(rec.get("trust", 55)), int(trust_row.min), int(trust_row.max))
	return out


# Campaign.new_game, after the usual start (build, starting condition): the carry-over, the clients, the shuffle
func begin_run(mode: String) -> void:
	if not active():
		return
	carried = carry_for(mode, prev)
	Campaign.rep = int(carried.rep)
	Shop.restore(prev.get("shop", []))
	if not Campaign.books_active():
		for key in carried.skills:
			var lv := int(carried.skills[key])
			if lv > Skills.level(str(key)):
				Skills.xp[key] = Skills.need(lv - 1)
		Skills.ps_level = maxi(Skills.ps_level, int(carried.ps))
	else:
		Owner.cash += int(carried.cash)
		Partner.trust = clampi(int(carried.trust) + Build.trust_bonus(), 0, 100)
		RivalTouches.rival_year(2)
		carried["habits"] = RivalTouches.year2_begin(prev)
	for cname in YEAR2.clients.client:
		var idx := client_index(str(cname))
		if idx >= 0 and not Sales.active.has(idx):
			Sales.active.append(idx)
	moves = story_shuffle(mode)
	Career.add("year2_runs")


func client_index(cname: String) -> int:
	for i in Msp.CLIENTS.size():
		if str(Msp.CLIENTS[i].name) == cname:
			return i
	return -1


func intro_text() -> String:
	var parts: Array = [str(TEXT.intro.text)]
	for key in ["sla", "tickets", "clients", "mutators", "shuffle"]:
		parts.append(str(YEAR2[key].text))
	if not carried.is_empty():
		var s := "YOU CARRY OVER: REPUTATION %d" % int(carried.rep)
		if Campaign.books_active():
			s += ", $%d START CASH, PARTNER TRUST %d" % [int(carried.cash), Partner.trust]
		else:
			var bits := []
			for key in carried.skills:
				if int(carried.skills[key]) > 0:
					bits.append("%s %d" % [str(Skills.NAMES[key]), int(carried.skills[key])])
			if int(carried.ps) > 0:
				bits.append("POWERSHELL %d" % int(carried.ps))
			if not bits.is_empty():
				s += ", " + ", ".join(bits)
		parts.append(s + ".")
		if Campaign.books_active() and not (carried.get("habits", []) as Array).is_empty():
			parts.append(str(TEXT.habits.carry))
			parts.append(str(TEXT.habits.rival_note))
	return " ".join(parts)


# ---- the story shuffle -----------------------------------------------------------------------------------------
# the day table of a mode (the scripted beats): the tech story or the owner weeks
func _base(mode: String) -> Dictionary:
	return Story.DAYS if mode == "tech" else (Owner.DAYS if mode == "owner" else {})


func _key(ev: Dictionary) -> String:
	var kind := str(ev.get("kind", ""))
	if kind == "playbook":
		return "book:" + str(ev.get("book", ""))
	if kind == "vignette":
		return "vig:" + str(ev.get("id", ""))
	if ev.has("kind"):
		return "kind:" + kind
	if ev.has("event") and not ev.has("card"):
		return "ev:" + str(ev.event)
	return ""


# the events of one day with the moves applied (the day tables are never edited)
func events_on(mode: String, day: int, base: Dictionary) -> Array:
	var list: Array = base.get(day, [])
	if moves.is_empty():
		return list
	var out := []
	for ev in list:
		var gone := false
		for m in moves:
			if str(m.mode) == mode and int(m.from) == day and str(m.key) == _key(ev):
				gone = true
				break
		if not gone:
			out.append(ev)
	for m in moves:
		if str(m.mode) == mode and int(m.to) == day:
			for ev in base.get(int(m.from), []):
				if _key(ev) == str(m.key):
					out.append(ev)
					break
	return out


# the days a moved beat may not land on
func blocked_days(mode: String) -> Dictionary:
	var out := {}
	var base := _base(mode)
	var cfg: Dictionary = YEAR2.shuffle.get(mode, {})
	var fixed: Array = cfg.get("fixed", [])
	for day in base:
		for ev in base[day]:
			var key := _key(ev)
			for f in fixed:
				if key.ends_with(":" + str(f)):
					out[int(day)] = true
	var outings: Array = Outings.OWNER_WEEKS if mode == "owner" else Outings.TECH_DAYS
	for d in outings:
		out[int(d)] = true
	if mode == "tech":
		out[Expo.TRIP_DAY] = true
	var beats: Dictionary = YEAR2.beats.get(mode, {})
	for id in beats:
		out[int(beats[id])] = true
	for e in Mutators.plan:
		for d in range(int(e.from), int(e.to) + 1):
			out[d] = true
	return out


# the beats that may move, as groups (a linked vignette follows its job): [{members: [{key, kind, from}]}]
func _groups(mode: String, base: Dictionary, cfg: Dictionary) -> Array:
	var movable: Array = []
	if mode == "tech":
		for b in cfg.get("books", []):
			movable.append("book:" + str(b))
		for v in cfg.get("vignettes", []):
			movable.append("vig:" + str(v))
	else:
		for e in cfg.get("events", []):
			movable.append("ev:" + str(e))
	var linked: Dictionary = cfg.get("linked", {})
	var days: Array = base.keys()
	days.sort()
	var out := []
	for key in movable:
		for day in days:
			for ev in base[day]:
				if _key(ev) != key:
					continue
				var members := [{"key": key, "from": int(day)}]
				for v in linked:
					if str(linked[v]) == key.substr(5):
						for d2 in days:
							for ev2 in base[d2]:
								if _key(ev2) == "vig:" + str(v):
									members.append({"key": "vig:" + str(v), "from": int(d2)})
				out.append({"members": members})
	return out


func _kind_of(key: String) -> String:
	return key.split(":")[0]


# one day's load: how many playbooks, vignettes and which keys are there after the moves so far
func _load(_mode: String, base: Dictionary, placed: Array, day: int) -> Dictionary:
	var out := {"books": 0, "vigs": 0, "n": 0, "keys": {}}
	var moved_away := []
	for p in placed:
		if int(p.from) == day:
			moved_away.append(str(p.key))
	for ev in base.get(day, []):
		var key := _key(ev)
		if moved_away.has(key):
			continue
		_count(out, key)
	for p in placed:
		if int(p.to) == day:
			_count(out, str(p.key))
	return out


func _count(loaded: Dictionary, key: String) -> void:
	loaded.n += 1
	loaded.keys[key] = true
	if key.begins_with("book:"):
		loaded.books += 1
	elif key.begins_with("vig:"):
		loaded.vigs += 1


# Where can the beats of a group go? Deterministic for a seed (Difficulty.rng("year2")), by at most `max_shift`
# days, never onto an outing day, the trip day, the overtime night, the ransomware or install day, a Year 2 beat
# day, a day inside the mutator plan, a day that already has a playbook (for a playbook) or a vignette (for a vignette).
func story_shuffle(mode: String, rng: RandomNumberGenerator = null) -> Array:
	var cfg: Dictionary = YEAR2.shuffle.get(mode, {})
	if cfg.is_empty():
		return []
	var r: RandomNumberGenerator = rng if rng != null else Difficulty.rng("year2")
	var base := _base(mode)
	var span := int(YEAR2.shuffle.max_shift)
	var lo := int(cfg.get("min_day", 3))
	var hi := Campaign.total_days() - 1
	var blocked := blocked_days(mode)
	var placed: Array = []  # the moves made so far
	var order: Array = _groups(mode, base, cfg)
	Difficulty.shuffle_with(order, r)  # who gets the free days first changes with the seed
	for g in order:
		var deltas: Array = []
		for d in range(-span, span + 1):
			if d != 0:
				deltas.append(d)
		Difficulty.shuffle_with(deltas, r)
		deltas.append(0)
		for d in deltas:
			if d == 0:
				break
			var ok := true
			var trial: Array = placed.duplicate()
			for m in g.members:
				var t := int(m.from) + int(d)
				var loaded := _load(mode, base, trial, t)
				var kind := _kind_of(str(m.key))
				if t < mini(lo, int(m.from)) or t > hi or blocked.has(t):
					ok = false
				elif kind == "book" and int(loaded.books) > 0:
					ok = false
				elif kind == "vig" and int(loaded.vigs) > 0:
					ok = false
				elif kind == "ev" and (loaded.keys.has(str(m.key)) or int(loaded.n) >= 4):
					ok = false
				if not ok:
					break
				trial.append({"key": str(m.key), "from": int(m.from), "to": t})
			if ok:
				placed = trial
				break
	var out := []
	for p in placed:
		out.append({"mode": mode, "key": str(p.key), "from": int(p.from), "to": int(p.to)})
	return out


# ---- the Year 2 beats (cards that set flags) ----------------------------------------------------------------------
func flag(key: String) -> String:
	var f: Dictionary = Story.flags.get("y2", {})
	return str(f.get(key, ""))


func set_flag(key: String, value: String) -> void:
	var f: Dictionary = Story.flags.get("y2", {})
	f[key] = value
	Story.flags["y2"] = f


# Campaign._begin_day
func begin_day(day: int) -> void:
	if not active() or Game.title_mode:
		return
	if day == 1:
		Cards.ask(str(TEXT.intro.speaker), intro_text(), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
	var beats: Dictionary = YEAR2.beats.get(Campaign.mode, {})
	for id in beats:
		if int(beats[id]) == day:
			beat(str(id))


func beat(id: String) -> void:
	var row: Dictionary = TEXT.beats.get(Campaign.mode, {}).get(id, {})
	if row.is_empty():
		return
	var options := []
	for o in row.options:
		var enabled := true
		if o.has("need") and Campaign.books_active():
			enabled = Owner.cash >= int(o.need)
		options.append({"label": str(o.label), "id": str(o.id), "enabled": enabled})
	Cards.ask(str(row.speaker), str(row.text), options, func(oid: String) -> void: answer(id, oid))


func answer(id: String, oid: String) -> void:
	var row: Dictionary = TEXT.beats.get(Campaign.mode, {}).get(id, {})
	for o in row.get("options", []):
		if str(o.id) != oid:
			continue
		set_flag(id, oid)
		var fx: Dictionary = o.get("fx", {})
		if not fx.is_empty():
			Events.apply_fx(fx)
		Cards.ask(str(row.speaker), str(o.reply), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


# ---- the Year 2 endings -----------------------------------------------------------------------------------------
func _offer_ok(id: String) -> bool:
	match id:
		"head":
			var need := 60 if str(prev.get("ending", "")) == "lead" else 65
			return flag("desk") == "run" and Campaign.rep >= need and Social.average() >= 0.0
		"clientbuy":
			return (flag("courted") == "listen" or flag("courted") == "told") and Campaign.rep >= 50
		"merger":
			return flag("merger") == "talks" and Campaign.rep >= 55 and Sales.active.size() >= 6 and Owner.cash >= 0
		"franchise":
			return flag("franchise") == "pilot" and Campaign.rep >= 60 and Sales.active.size() >= 6 and Owner.oml() >= 2
	return false


func _fill(text: String) -> String:
	var value := "0"
	if Campaign.books_active():
		value = str(int(Owner.valuation() * 11 / 10))
	return text.replace("${value}", "$" + value).replace("{value}", value)


# the offers of the review, with the Year 2 endings the flags unlock slotted in before STAY
func extra_offers(out: Array) -> Array:
	if not active():
		return out
	var add := []
	for id in YEAR2.endings.get(Campaign.mode, []):
		if _offer_ok(str(id)):
			var row: Dictionary = TEXT.offers.get(str(id), {})
			add.append({"id": str(id), "label": _fill(str(row.get("label", id))), "desc": _fill(str(row.get("desc", "")))})
	if add.is_empty():
		return out
	var at := out.size()
	for i in out.size():
		if str(out[i].id) in ["stay", "left"]:
			at = i
			break
	var merged: Array = out.slice(0, at)
	merged.append_array(add)
	merged.append_array(out.slice(at))
	return merged


func ending_text(id: String) -> String:
	return _fill(str(TEXT.endings.get(id, "")))


func is_year2_ending(id: String) -> bool:
	return TEXT.endings.has(id)


# ---- saving ---------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"version": VERSION, "moves": moves.duplicate(true), "carried": carried.duplicate(true), "pick": pick, "ban": ban, "prev": prev.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Variant = data.get("moves", [])
	if saved is Array:
		for m in saved:
			if m is Dictionary and m.has("key"):
				moves.append({"mode": str(m.get("mode", "tech")), "key": str(m.key), "from": int(m.get("from", 0)), "to": int(m.get("to", 0))})
	carried = data.get("carried", {}) if data.get("carried", {}) is Dictionary else {}
	prev = data.get("prev", {}) if data.get("prev", {}) is Dictionary else {}
	pick = str(data.get("pick", ""))
	ban = str(data.get("ban", ""))
	RivalTouches.rival_year(Campaign.year)  # a saved Year 2 run keeps the new rival name
