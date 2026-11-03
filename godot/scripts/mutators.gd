extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Mutators and starting conditions (roadmap R9, docs/replayability-ideas.md 3.2).
#
# A MUTATOR is a short twist on the world (Heartbleed week, flu season ...) announced by a morning card and
# shown as a small tag on the HUD and the day report. It is a row of DATA: the keys are READ by existing
# functions through one getter, `Mutators.hook(key, default)`, which returns the default (the neutral value)
# when nothing is active, so a run without a mutator behaves exactly like before (tests/mutators.gd checks it):
#   ticket_weight {fix or "server": x}   how likely a problem kind is (Msp._random_ticket)
#   extra_problems [], extra_chance      extra ticket kinds that join the draw
#   user_weight {user: x}                which desk the ticket lands on (accountants: "bookkeeper")
#   ticket_rate x                        spawn interval multiplier (below 1 = more tickets)
#   sla_mult x                           SLA clocks of new tickets
#   xp_pri n                             tickets on XP PCs are at least this priority
#   energy_drain x, fail_add n           Shift: the day's energy drain, extra RMM failure chance
#   event_boost {card id: x}             Events draw weight
#   cast_out {count}                     that many coworkers are out (World.apply_roster)
#   price_pressure n, lead_mult x, pay_delay n   owner: poach risk, inbound leads, weeks an invoice is late
#   batch {count, problem}, backup_break n, mails [], texts [], offer {}   one-off things on the first morning
# Never a penalty for family or health: flu season only changes who is in the building.
#
# SCHEDULE: `plan` = [{id, from, to}] over tech days or owner weeks, made once at New Game with
# Difficulty.rng("mutators") (a fixed seed repeats), only on SLOTS (never the days that already have a
# playbook or the ransomware), at most one at a time, and saved in the campaign file (`mutators` section).
# Easy: none or one; normal: two or three; hard: four or five. Free Play has none unless you pick one
# with the ` key (`forced`).
#
# STARTING CONDITIONS (STARTS): picked on the character select screen, applied once in new_game,
# saved. STANDARD changes nothing.

const VERSION := 1
const KINDS := ["tech", "owner", "both"]
const STANDARD := "standard"
const START_ORDER := ["standard", "messy", "only_tech", "rival", "family"]
# tech days / owner weeks a mutator may START on (no playbook days 7-9, 12-13, 16-19, nothing on days 1-5 or 20)
const TECH_SLOTS := [6, 10, 11, 14, 15]
const OWNER_SLOTS := [3, 6, 7, 8, 11, 17]
const COUNT_BY_TIER := {"easy": [0, 1], "normal": [2, 3], "hard": [4, 5]}
const MAX_TEXT := 300
# hook key -> kind of value, lowest, highest (the validator in tests/mutators.gd and problems())
const SCHEMA := {
	"ticket_rate": ["f", 0.5, 1.5],
	"sla_mult": ["f", 0.8, 1.5],
	"energy_drain": ["f", 0.8, 1.5],
	"fail_add": ["f", -0.05, 0.1],
	"price_pressure": ["f", 0.0, 0.1],
	"lead_mult": ["f", 0.3, 1.0],
	"extra_chance": ["f", 0.0, 0.5],
	"pay_delay": ["i", 0, 2],
	"xp_pri": ["i", 1, 3],
	"backup_break": ["i", 0, 2],
	"ticket_weight": ["w", 0.5, 4.0],
	"user_weight": ["w", 1.0, 3.0],
	"event_boost": ["w", 1.0, 6.0],
}
const MUTATOR_KEYS := [
	"name",
	"text",
	"kinds",
	"duration",
	"extra_problems",
	"batch",
	"mails",
	"texts",
	"offer",
	"cast_out",
	"flavor"
]
const START_KEYS := [
	"name",
	"short",
	"text",
	"kinds",
	"angry",
	"angry_mood",
	"patch_debt",
	"ticket_rate",
	"ticket_weight",
	"until",
	"cast_join",
	"poach_wave",
	"rival_drain",
	"stack_fee",
	"texts"
]
const OUT_POOL := {"tech": ["Dan", "Vic", "Maya"], "owner": ["Dan", "Vic"]}

# duration = [tech days, owner weeks]; fix names are the RMM actions of Msp.FIXES
const DEFAULT_MUTATORS := {
	"heartbleed":
	{
		"name": "HEARTBLEED WEEK",
		"text":
		"Everybody has read the news about Heartbleed, the bug in the encryption library half the web uses. Clients want their certificates checked and their passwords changed, and the vendors are slow to answer.",
		"kinds": ["both"],
		"duration": [2, 1],
		"ticket_weight": {"password": 2.0},
		"extra_chance": 0.3,
		"extra_problems":
		[
			{
				"summary": "Server certificate check after the Heartbleed news",
				"fix": "reboot",
				"pri": 2,
				"server": true,
				"body":
				"The news says our website and mail server might be affected. Please check the certificate and restart the services after the patch. A customer already asked me about it. - %s"
			},
			{
				"summary": "Asked to change every password",
				"fix": "password",
				"pri": 3,
				"body":
				"A website told us to change all our passwords because of that bug in the news. I changed one and now I am locked out of everything else. Can you reset mine? - %s"
			}
		],
		"event_boost": {"scam_call": 3.0, "sticky_password": 3.0, "pw_reset_call": 3.0},
		"texts":
		[
			{
				"from": "Boss",
				"body":
				"Heartbleed week: expect certificate checks and password resets. Be calm and write down what you checked."
			}
		],
	},
	"xp_eol":
	{
		"name": "XP END OF LIFE",
		"text":
		"Support for Windows XP ends on April 8 and every client suddenly remembers the old PC in the back office. Any ticket on an XP machine is urgent this week, and the owners smell a project.",
		"kinds": ["both"],
		"duration": [2, 1],
		"xp_pri": 2,
		"event_boost": {"xp_panic": 4.0},
		"offer":
		{
			"speaker": "Vic Marlowe",
			"text":
			"Three of our clients still have XP desktops. Want me to send them a replacement quote? It is a real project, but the deadline helps us.",
			"options":
			[
				{
					"id": "quote",
					"label": "YES, SEND THE UPGRADE QUOTES",
					"text":
					"Vic sends tidy quotes with a date on them. Two clients say yes to a few new PCs.",
					"fx": {"xp": ["people", 3], "rep": 1, "hours": 0.4}
				},
				{
					"id": "later",
					"label": "LATER, WE ARE BUSY",
					"text": "Vic shrugs. The deadline will not move, so he will ask again.",
					"fx": {}
				}
			]
		},
	},
	"flu_season":
	{
		"name": "FLU SEASON",
		"text":
		"The flu is going around. A couple of coworkers are out for a day or two. Nothing changes for you: no extra work to prove anything, and the team covers.",
		"kinds": ["both"],
		"duration": [2, 2],
		"cast_out": {"count": 2},
		"texts":
		[
			{
				"from": "Boss",
				"body":
				"{names} are out with the flu. Rest up, everyone, and wash your hands. Nothing is expected of you beyond the usual."
			}
		],
	},
	"printer_apocalypse":
	{
		"name": "PRINTER APOCALYPSE",
		"text":
		"Every printer in the county decided to jam this week. Print queue tickets come in three times as often, the toner supplier is late, and the boss left notes on the machines.",
		"kinds": ["both"],
		"duration": [2, 1],
		"ticket_weight": {"spooler": 3.0},
		"event_boost": {"toner_late": 3.0, "toner_mixup": 3.0, "home_printer": 3.0},
		"texts":
		[
			{
				"from": "Boss",
				"body":
				"Printer week. Restart the print spooler first. A reboot works too, but the user loses whatever they had open."
			}
		],
	},
	"tax_season":
	{
		"name": "TAX SEASON",
		"text":
		"It is tax season. Every bookkeeper and accountant is on the phone twice as often, deadlines are real, and nobody has time for a sales meeting. New leads dry up for a while.",
		"kinds": ["both"],
		"duration": [2, 2],
		"user_weight": {"bookkeeper": 2.0},
		"lead_mult": 0.5,
		"price_pressure": 0.02,
		"event_boost": {"tax_season": 5.0},
	},
	"slow_payers":
	{
		"name": "SLOW PAYERS",
		"text":
		"Money is tight all over town. Clients are paying their invoices a week late, and the bank balance is the thing to watch until it passes.",
		"kinds": ["owner"],
		"duration": [1, 2],
		"pay_delay": 1,
		"texts":
		[
			{
				"from": "Boss",
				"body":
				"Several clients are paying late this month. Mind the cash, and keep the invoices going out on time."
			}
		],
	},
	"hardware_recall":
	{
		"name": "HARDWARE RECALL",
		"text":
		"A drive maker recalled a whole batch of disks and three clients have them. Machines start clicking and freezing, and there is a notice in your inbox.",
		"kinds": ["both"],
		"duration": [1, 1],
		"ticket_weight": {"reboot": 1.5},
		"batch":
		{
			"count": 3,
			"problem":
			{
				"summary": "Computer clicking and freezing: drive on the recall list",
				"fix": "reboot",
				"pri": 2,
				"body":
				"The computer makes a clicking sound and freezes every few minutes. The vendor sent us a recall letter about the drive. Can you look at it today? - %s"
			}
		},
		"mails":
		[
			{
				"from": "Parts Desk <parts@example.com>",
				"subject": "Recall notice: hard drive batch",
				"body":
				"A batch of drives sold in the last year may fail early. Check clients for clicking or freezing PCs, and back them up first."
			}
		],
	},
	"hurricane_drill":
	{
		"name": "HURRICANE DRILL",
		"text":
		"After the storm season the owners want proof that a restore really works. A disaster-recovery drill is on: check every client's backups today, one of them failed overnight.",
		"kinds": ["both"],
		"duration": [1, 1],
		"backup_break": 1,
		"event_boost": {"tape_check": 4.0},
		"texts":
		[
			{
				"from": "Boss",
				"body":
				"Disaster-recovery drill today. Open the RMM, check each client's backups and re-run the one that failed."
			}
		],
	},
	"new_psa":
	{
		"name": "THE NEW PSA",
		"text":
		"The company moved to a new ticket system over the weekend. Nothing is where it was, customers cannot log in to the new portal, and every second call starts with 'where did my ticket go'.",
		"kinds": ["both"],
		"duration": [1, 1],
		"ticket_rate": 0.8,
		"fail_add": 0.03,
		"extra_chance": 0.25,
		"extra_problems":
		[
			{
				"summary": "New ticket portal will not let me log in",
				"fix": "password",
				"pri": 3,
				"body":
				"The new portal sent me a password and it does not work. I tried it six times. Please reset it so I can see my tickets. - %s"
			},
			{
				"summary": "New ticket portal page is stuck",
				"fix": "clear_temp",
				"pri": 3,
				"body":
				"The portal page just spins. Last time you told me to clear something out of the browser. Can you do it for me again? - %s"
			}
		],
		"mails":
		[
			{
				"from": "Morgan Reyes - Manager",
				"subject": "Migration day",
				"body":
				"The new PSA is live. The old one is read-only. If you cannot find something, ask me before you panic. - Morgan"
			}
		],
	},
	"heat_wave":
	{
		"name": "HEAT WAVE",
		"text":
		"A heat wave. The air conditioning cannot keep up, the server closets run hot and everyone is slower by the afternoon.",
		"kinds": ["both"],
		"duration": [2, 1],
		"ticket_weight": {"reboot": 1.5},
		"energy_drain": 1.2,
		"event_boost": {"heat_wave": 5.0},
	},
	"cold_snap":
	{
		"name": "COLD SNAP",
		"text":
		"A cold snap. The roads are icy, fewer people call and the office heater clicks all day. Everything takes a little longer.",
		"kinds": ["both"],
		"duration": [2, 1],
		"ticket_rate": 1.15,
		"sla_mult": 1.1,
		"energy_drain": 1.1,
		"event_boost": {"cold_snap": 5.0},
	},
}
var MUTATORS: Dictionary = DEFAULT_MUTATORS.duplicate(true)

# starting conditions: tech days / owner weeks in `until` = [tech, owner]
const DEFAULT_STARTS := {
	"standard":
	{
		"name": "STANDARD",
		"short": "STANDARD",
		"text": "A normal first day at Pixel IT Partners.",
		"kinds": ["both"],
	},
	"messy":
	{
		"name": "INHERIT A MESSY MSP",
		"short": "MESSY MSP",
		"text":
		"The last tech left a mess: two accounts are already angry, patches are months behind and the first weeks bring more tickets.",
		"kinds": ["both"],
		"angry": 2,
		"angry_mood": 28,
		"patch_debt": 6,
		"ticket_rate": 0.75,
		"ticket_weight": {"reboot": 1.5, "av": 1.5},
		"until": [10, 2],
	},
	"only_tech":
	{
		"name": "THE ONLY TECH",
		"short": "ONLY TECH",
		"text":
		"The team is thin at first: Maya joins on day 3 and Dan on day 5. Until then the desk is yours.",
		"kinds": ["tech"],
		"cast_join": {"Maya": 3, "Dan": 5},
	},
	"rival":
	{
		"name": "A RIVAL WANTS YOUR CLIENT",
		"short": "RIVAL",
		"text":
		"A competitor is already calling your clients. Keep them happy from the first day, or they walk.",
		"kinds": ["both"],
		"poach_wave": 4,
		"rival_drain": 2,
		"until": [10, 2],
		"texts":
		[
			{
				"from": "Vic",
				"body":
				"Heads up: a rival shop is handing out flyers to our clients. Keep them happy this month."
			}
		],
	},
	"family":
	{
		"name": "FAMILY BUSINESS",
		"short": "FAMILY BIZ",
		"text":
		"Your father-in-law built this company and does not like change. Every card that changes the stack costs $250 more in 'conversations'.",
		"kinds": ["owner"],
		"stack_fee": 250,
	},
}
var STARTS: Dictionary = DEFAULT_STARTS.duplicate(true)

var plan: Array = []  # [{id, from, to}] over the days (tech) or weeks (owner) of the run
var start_id := STANDARD  # the starting condition of this run (saved)
var pending_start := STANDARD  # chosen on the character select screen, taken by new_game
var forced := ""  # Free Play: the mutator picked with the ` key
var announced := ""  # the id of the mutator whose card was last shown (tests)
var cards_shown := 0

var _out: Array = []  # cast members out today (flu season)


func _ready() -> void:
	set_process_unhandled_input(true)


func reset() -> void:
	plan = []
	start_id = STANDARD
	forced = ""
	announced = ""
	cards_shown = 0
	_out = []


# ---- the getter every hooked function uses ---------------------------------------------------------------------
func current_id() -> String:
	if Game.title_mode:
		return ""
	if Campaign.active:
		return id_at(Campaign.day)
	return "" if Difficulty.fixed_take else forced


func id_at(day: int) -> String:
	for e in plan:
		if day >= int(e.from) and day <= int(e.to):
			return str(e.id)
	return ""


func current() -> Dictionary:
	var id := current_id()
	if id == "" or not MUTATORS.has(id):
		return {}
	return MUTATORS[id]


# the value of one key of the active mutator, or `default` (the neutral value) when none is active
func hook(key: String, default: Variant = null) -> Variant:
	var m := current()
	if m.is_empty():
		return default
	return m.get(key, default)


# the name shown on the HUD and the day report ("" = none)
func tag() -> String:
	return str(current().get("name", ""))


# ---- starting condition ----------------------------------------------------------------------------------------
func start_row() -> Dictionary:
	if start_id == STANDARD or not STARTS.has(start_id):
		return {}
	return STARTS[start_id]


func starts_for(mode: String) -> Array:
	var out := []
	for id in START_ORDER:
		if not STARTS.has(id):
			continue
		var kinds: Array = STARTS[id].get("kinds", [])
		if kinds.has("both") or kinds.has(mode):
			out.append(id)
	return out


# true while the early-game part of the starting condition runs (tech days 1-10, owner weeks 1-2)
func start_window() -> bool:
	var s := start_row()
	if s.is_empty() or not Campaign.active:
		return false
	var until: Array = s.get("until", [0, 0])
	return Campaign.day <= int(until[1] if Campaign.mode == "owner" else until[0])


# combined multipliers of the active mutator and the starting condition
func ticket_rate() -> float:
	var r := float(hook("ticket_rate", 1.0))
	if start_window():
		r *= float(start_row().get("ticket_rate", 1.0))
	return r


func ticket_weights() -> Dictionary:
	var out: Dictionary = hook("ticket_weight", {}).duplicate()
	var y2: Dictionary = Yeartwo.ticket_weights()  # Year 2: more printer and security tickets, more servers
	for k in y2:
		out[k] = float(out.get(k, 1.0)) * float(y2[k])
	if start_window():
		var s: Dictionary = start_row().get("ticket_weight", {})
		for k in s:
			out[k] = float(out.get(k, 1.0)) * float(s[k])
	return out


# Events.pool: the draw weight multiplier of one card id
func boost(card_id: String) -> float:
	var b: Dictionary = hook("event_boost", {})
	return float(b.get(card_id, 1.0))


func sla(secs: float) -> float:
	return secs * float(hook("sla_mult", 1.0)) * Yeartwo.sla_mult() * Difficulty.cm("sla")


# the ticket kind of the next random ticket: {} = the usual uniform pick (nothing is active, no random number used)
func pick_problem() -> Dictionary:
	var w := ticket_weights()
	var extras: Array = hook("extra_problems", [])
	if w.is_empty() and extras.is_empty():
		return {}
	if not extras.is_empty() and Difficulty.rng("msp.tickets").randf() < float(hook("extra_chance", 0.0)):
		return extras[Difficulty.rng("msp.tickets").randi() % extras.size()]
	var weights := []
	var total := 0.0
	for p in Msp.PROBLEMS:
		var x := float(w.get(str(p.fix), 1.0))
		if p.get("server", false) and w.has("server"):
			x = float(w.server)
		weights.append(x)
		total += x
	var roll := Difficulty.rng("msp.tickets").randf() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return Msp.PROBLEMS[i]
	return Msp.PROBLEMS[Msp.PROBLEMS.size() - 1]


# which of the clients' PCs the ticket lands on (Msp.create_problem): the usual uniform pick unless desks are weighted
func pick_endpoint(eps: Array) -> Dictionary:
	var w: Dictionary = hook("user_weight", {})
	if w.is_empty():
		return eps[Difficulty.rng("msp.tickets").randi() % eps.size()]
	var total := 0.0
	for ep in eps:
		total += float(w.get(str(ep.get("user", "")), 1.0))
	var roll := Difficulty.rng("msp.tickets").randf() * total
	for ep in eps:
		roll -= float(w.get(str(ep.get("user", "")), 1.0))
		if roll < 0.0:
			return ep
	return eps[eps.size() - 1]


# the priority of a new ticket: XP desktops are at least `xp_pri` during XP end of life
func priority(pri: int, ep: Dictionary) -> int:
	var cap := int(hook("xp_pri", 0))
	if cap > 0 and str(ep.get("os", "")).contains("XP") and pri > cap:
		return cap
	if pri == 2 and Yeartwo.promote():
		return 1  # Year 2: a bigger share of P1s
	return pri


# owner: false = this inbound lead does not come (tax season), drawn from the mutators stream
func chance(key: String) -> bool:
	var p := float(hook(key, 1.0))
	if p >= 1.0:
		return true
	return Difficulty.rng("mutators_chance").randf() < p


# owner: the extra cost of a card that changes the stack (family business); 0 when the choice is the same
func stack_fee(category: String, choice: String) -> int:
	var fee := int(start_row().get("stack_fee", 0))
	if fee > 0 and str(Owner.stack.get(category, "")) != choice:
		return fee
	return 0


# ---- the cast: who is out today (flu season, the only tech) ---------------------------------------------------------
func absent() -> Array:
	var out := _out.duplicate()
	var join: Dictionary = start_row().get("cast_join", {})
	if Campaign.active and Campaign.mode == "tech":
		for who in join:
			if Campaign.day < int(join[who]) and not out.has(str(who)):
				out.append(str(who))
	return out


func day_blocked(day: int) -> bool:
	if Campaign.mode == "owner":
		return Outings.OWNER_WEEKS.has(day)
	return Outings.TECH_DAYS.has(day) or Expo.is_trip_day(day)


func _pick_out(count: int, salt: int) -> Array:
	var kind := "owner" if Campaign.mode == "owner" else "tech"
	var gone := World.roster_gone()
	var pool := []
	for who in OUT_POOL[kind]:
		if not gone.has(who):
			pool.append(who)
	var r := Difficulty.rng_for("flu", salt)
	for k in range(pool.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = pool[k]
		pool[k] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(count, pool.size()))


# called by World.begin_next_day before the cast is placed: decides who is out today
func prepare_day(day: int) -> void:
	_out = []
	if not Campaign.active:
		return
	var co: Dictionary = MUTATORS.get(id_at(day), {}).get("cast_out", {})
	if not co.is_empty() and not day_blocked(day):
		_out = _pick_out(int(co.get("count", 1)), day)


# ---- scheduling ---------------------------------------------------------------------------------------------------
func slots_for(mode: String) -> Array:
	return OWNER_SLOTS if mode == "owner" else TECH_SLOTS


func ids_for(mode: String) -> Array:
	var out := []
	for id in MUTATORS:
		var kinds: Array = MUTATORS[id].get("kinds", [])
		if kinds.has("both") or kinds.has(mode):
			out.append(str(id))
	out.sort()
	return out


func duration_of(id: String, mode: String) -> int:
	var d: Array = MUTATORS.get(id, {}).get("duration", [1, 1])
	return maxi(1, int(d[1] if mode == "owner" else d[0]))


# the schedule of a run: [{id, from, to}], drawn from the `mutators` stream (same seed, same plan)
func make_plan(mode: String, tier: String) -> Array:
	var out := []
	if not Campaign.MODES.has(mode):
		return out
	var r := Difficulty.rng("mutators")
	var range_n: Array = Yeartwo.counts(tier, COUNT_BY_TIER.get(tier, COUNT_BY_TIER.normal))
	var slots: Array = slots_for(mode).duplicate()
	var n := mini(r.randi_range(int(range_n[0]), int(range_n[1])), slots.size())
	for k in range(slots.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = slots[k]
		slots[k] = slots[j]
		slots[j] = tmp
	var starts: Array = slots.slice(0, n)
	starts.sort()
	var pool := Yeartwo.without_banned(ids_for(mode))
	var deck := pool.duplicate()
	for day in starts:
		if deck.is_empty():
			deck = pool.duplicate()
		var pick := r.randi_range(0, deck.size() - 1)
		var id: String = deck[pick]
		deck.remove_at(pick)
		var to: int = day
		var all: Array = slots_for(mode)
		while (
			to - int(day) + 1 < duration_of(id, mode) and all.has(to + 1) and not starts.has(to + 1)
		):
			to += 1
		out.append({"id": id, "from": int(day), "to": to})
	return out


# New Game: choose the starting condition and make the schedule (Free Play: nothing)
func start(mode: String) -> void:
	forced = ""
	_out = []
	announced = ""
	cards_shown = 0
	start_id = STANDARD
	if Campaign.MODES.has(mode) and starts_for(mode).has(pending_start):
		start_id = pending_start
	pending_start = STANDARD
	plan = Yeartwo.apply_pick(make_plan(mode, Difficulty.tier), mode)


# the starting condition's overrides on the fresh state (after Sales / Owner were reset)
func apply_start() -> void:
	var s := start_row()
	if s.is_empty() or not Campaign.active:
		return
	var angry := int(s.get("angry", 0))
	if angry > 0:
		var r := Difficulty.rng_for("start", 1)
		var pool: Array = Sales.active.duplicate()
		for k in range(pool.size() - 1, 0, -1):
			var j := r.randi_range(0, k)
			var tmp = pool[k]
			pool[k] = pool[j]
			pool[j] = tmp
		for c in pool.slice(0, mini(angry, pool.size())):
			Sales.satisfaction[int(c)] = int(s.get("angry_mood", 28))
	if Campaign.mode == "owner":
		var debt := float(s.get("patch_debt", 0.0))
		if debt > 0.0:
			for c in Sales.active:
				Owner.patch_debt[int(c)] = debt
		if int(s.get("poach_wave", 0)) > 0:
			Owner._poach_wave = int(s.poach_wave)
	for t in s.get("texts", []):
		Msp.send_text(str(t.from), str(t.body))


# ---- the morning ---------------------------------------------------------------------------------------------------
func entry_at(day: int) -> Dictionary:
	for e in plan:
		if day >= int(e.from) and day <= int(e.to):
			return e
	return {}


# Campaign._begin_day: the rival's daily call, the mutator's morning card, the Career counters
func begin_day(day: int) -> void:
	if day > 1 and not entry_at(day - 1).is_empty():
		Career.add("mut_days")
	if not Campaign.active or Game.title_mode:
		return
	var s := start_row()
	if day == 1 and not s.is_empty():
		Cards.ask(
			"STARTING POSITION",
			"%s. %s" % [str(s.name), str(s.text)],
			[{"label": "OK", "id": "ok"}],
			func(_id: String) -> void: pass
		)
	var drain := int(s.get("rival_drain", 0))
	if (
		drain > 0
		and Campaign.mode == "tech"
		and day > 1
		and start_window()
		and not Sales.active.is_empty()
	):
		var r := Difficulty.rng_for("rival", day)
		Sales.adjust(int(Sales.active[r.randi_range(0, Sales.active.size() - 1)]), -drain)
	var e := entry_at(day)
	if e.is_empty():
		return
	if int(e.from) == day:
		announce(str(e.id))
	else:
		Hints.toast(tag(), 3.0)


# the card, the mails and texts, the batch of tickets and the failed backup of the first morning
func announce(id: String) -> void:
	if not MUTATORS.has(id):
		return
	var m: Dictionary = MUTATORS[id]
	announced = id
	cards_shown += 1
	ServiceArc.on_mutator(id)  # C7: a systems change makes the Service runbooks stale
	var options := [{"label": "OK", "id": "ok"}]
	var body := "%s. %s" % [str(m.name), str(m.text)]
	var pick: Callable = func(_id: String) -> void: pass
	var offer: Dictionary = m.get("offer", {})
	if not offer.is_empty():
		options = []
		for o in offer.options:
			options.append({"label": str(o.label), "id": str(o.id)})
		pick = func(oid: String) -> void: _answer_offer(offer, oid)
	Cards.ask("MORNING BRIEFING", body, options, pick)
	var names := ", ".join(absent())
	for t in m.get("texts", []):
		Msp.send_text(
			str(t.from), str(t.body).replace("{names}", names if names != "" else "A few of us")
		)
	for mail in m.get("mails", []):
		Msp.mail(str(mail.from), str(mail.subject), str(mail.body))
	_batch(m.get("batch", {}))
	for k in int(m.get("backup_break", 0)):
		var clients := []
		for c in Sales.active:
			if Msp.backups[int(c)].ok and int(c) != Story.RANSOM_CLIENT:
				clients.append(int(c))
		if not clients.is_empty():
			Msp.break_backup(
				clients[Difficulty.rng_for("drill", Campaign.day).randi_range(
					0, clients.size() - 1
				)]
			)


func _batch(b: Dictionary) -> void:
	if b.is_empty():
		return
	var pool: Array = Sales.active.duplicate()
	var r := Difficulty.rng_for("batch", Campaign.day)
	for k in int(b.get("count", 1)):
		if pool.is_empty():
			break
		var c: int = pool.pop_at(r.randi_range(0, pool.size() - 1))
		Msp.create_problem(c, b.problem, "recall notice")


func _answer_offer(offer: Dictionary, oid: String) -> void:
	for o in offer.options:
		if str(o.id) == oid:
			Events.apply_fx(o.get("fx", {}))
			Cards.ask(
				str(offer.speaker),
				str(o.text),
				[{"label": "OK", "id": "ok"}],
				func(_id: String) -> void: pass
			)


# the year ended: the starting condition counts as completed
func note_finish() -> void:
	Career.add("starts_done")
	if start_id != STANDARD:
		Career.add("start." + start_id)


# ---- Free Play: pick one with the ` key ----------------------------------------------------------------------------------
func set_forced(id: String) -> void:
	forced = id if MUTATORS.has(id) else ""
	_out = []
	var co: Dictionary = MUTATORS.get(forced, {}).get("cast_out", {})
	if not co.is_empty():
		_out = _pick_out(int(co.get("count", 1)), 0)
	World.apply_roster()


func cycle_forced(step: int) -> String:
	var ids := [""]
	ids.append_array(ids_for("tech"))
	var i := ids.find(forced)
	set_forced(str(ids[(maxi(i, 0) + step + ids.size()) % ids.size()]))
	return forced


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_QUOTELEFT or Game.title_mode or Campaign.active or Game.ui_open:
		return
	if Campaign.mode != Campaign.FREE or Difficulty.fixed_take:
		return
	cycle_forced(1)
	Hints.toast("MUTATOR: " + (tag() if forced != "" else "NONE"), 3.0)


# ---- saving -----------------------------------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"version": VERSION, "plan": plan.duplicate(true), "start": start_id}


# an old save has no section: no mutators, the standard start
func from_dict(data: Dictionary) -> void:
	reset()
	var saved_start := str(data.get("start", STANDARD))
	start_id = saved_start if STARTS.has(saved_start) else STANDARD
	var saved: Variant = data.get("plan", [])
	if saved is Array:
		for e in saved:
			if e is Dictionary and MUTATORS.has(str(e.get("id", ""))):
				plan.append(
					{"id": str(e.id), "from": int(e.get("from", 0)), "to": int(e.get("to", 0))}
				)


# ---- the validator (tests/mutators.gd and a hand-edited strings.txt) -----------------------------------------------------
func _weights_problems(key: String, v: Variant, lo: float, hi: float) -> Array:
	var out := []
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		return ["%s needs a dictionary" % key]
	for k in v:
		var x := float(v[k])
		if x < lo or x > hi:
			out.append("%s.%s %s is out of range" % [key, str(k), str(x)])
		if key == "ticket_weight" and str(k) != "server" and not Msp.FIXES.has(str(k)):
			out.append("ticket_weight.%s is not a fix" % str(k))
		if key == "user_weight" and not Msp.USERS.has(str(k)):
			out.append("user_weight.%s is not a user" % str(k))
		if key == "event_boost" and not Events.DECK.has(str(k)):
			out.append("event_boost.%s is not a card" % str(k))
	return out


func _problem_problems(p: Dictionary) -> Array:
	var out := []
	for k in ["summary", "fix", "pri", "body"]:
		if not p.has(k):
			out.append("problem lacks %s" % k)
	if out.is_empty():
		if not Msp.FIXES.has(str(p.fix)) or str(p.fix) in ["restore", "shadow", "pay", "save", "vendor", "rebuild", "insurer"]:
			out.append("problem fix %s" % str(p.fix))
		if int(p.pri) < 1 or int(p.pri) > 4:
			out.append("problem pri")
		if not str(p.body).contains("%s"):
			out.append("problem body needs %s")
	return out


func problems(id: String, m: Dictionary) -> Array:
	var out := []
	for k in m:
		var key := str(k)
		if not (SCHEMA.has(key) or MUTATOR_KEYS.has(key)):
			out.append("%s: unknown key %s" % [id, key])
	var kinds: Array = m.get("kinds", [])
	if kinds.is_empty():
		out.append("%s: no kinds" % id)
	for kind in kinds:
		if not KINDS.has(str(kind)):
			out.append("%s: bad kind %s" % [id, str(kind)])
	if str(m.get("name", "")) == "" or str(m.get("name", "")).length() > 24:
		out.append("%s: name must be 1-24 characters" % id)
	if str(m.get("text", "")) == "" or str(m.get("text", "")).length() > MAX_TEXT:
		out.append("%s: text must be 1-%d characters" % [id, MAX_TEXT])
	var dur: Variant = m.get("duration", [])
	if (
		not (dur is Array)
		or dur.size() != 2
		or int(dur[0]) < 1
		or int(dur[0]) > 3
		or int(dur[1]) < 1
		or int(dur[1]) > 3
	):
		out.append("%s: duration is [tech days, owner weeks], each 1-3" % id)
	var hooks := 0
	for key in SCHEMA:
		if not m.has(key):
			continue
		hooks += 1
		var spec: Array = SCHEMA[key]
		var v: Variant = m[key]
		if spec[0] == "w":
			out.append_array(_weights_problems(key, v, float(spec[1]), float(spec[2])))
		elif float(v) < float(spec[1]) or float(v) > float(spec[2]):
			out.append("%s: %s %s is out of range" % [id, key, str(v)])
	for key in ["extra_problems", "batch", "mails", "texts", "offer", "cast_out"]:
		if m.has(key):
			hooks += 1
	for p in m.get("extra_problems", []):
		out.append_array(_problem_problems(p))
	if m.has("extra_problems") and not m.has("extra_chance"):
		out.append("%s: extra_problems needs extra_chance" % id)
	if m.has("batch"):
		out.append_array(_problem_problems(m.batch.get("problem", {})))
		if int(m.batch.get("count", 0)) < 1 or int(m.batch.get("count", 0)) > 4:
			out.append("%s: batch count 1-4" % id)
	for mail in m.get("mails", []):
		for k in ["from", "subject", "body"]:
			if str(mail.get(k, "")) == "":
				out.append("%s: mail lacks %s" % [id, k])
	for t in m.get("texts", []):
		for k in ["from", "body"]:
			if str(t.get(k, "")) == "":
				out.append("%s: text lacks %s" % [id, k])
		if str(t.get("body", "")).length() > 160:
			out.append("%s: text message is too long" % id)
	if (
		m.has("cast_out")
		and (int(m.cast_out.get("count", 0)) < 1 or int(m.cast_out.get("count", 0)) > 2)
	):
		out.append("%s: cast_out count 1-2" % id)
	if m.has("offer"):
		var offer: Dictionary = m.offer
		var safe := false
		var offer_kinds := (
			["tech"] if kinds == ["tech"] else (["owner"] if kinds == ["owner"] else ["both"])
		)
		for o in offer.get("options", []):
			for p in Events.fx_problems(o.get("fx", {}), offer_kinds):
				out.append("%s/%s: %s" % [id, str(o.get("id", "")), p])
			if Events.is_safe_fx(o.get("fx", {})):
				safe = true
		if not safe or offer.get("options", []).size() < 2 or offer.get("options", []).size() > 3:
			out.append("%s: offer needs 2-3 options, one of them safe" % id)
	if hooks == 0:
		out.append("%s: a mutator needs at least one effect" % id)
	return out


func start_problems(id: String, s: Dictionary) -> Array:
	var out := []
	for k in s:
		if not START_KEYS.has(str(k)):
			out.append("%s: unknown key %s" % [id, str(k)])
	var kinds: Array = s.get("kinds", [])
	for kind in kinds:
		if not KINDS.has(str(kind)):
			out.append("%s: bad kind %s" % [id, str(kind)])
	if kinds.is_empty():
		out.append("%s: no kinds" % id)
	if str(s.get("name", "")) == "" or str(s.get("name", "")).length() > 28:
		out.append("%s: name must be 1-28 characters" % id)
	if str(s.get("short", "")) == "" or str(s.get("short", "")).length() > 12:
		out.append("%s: short must be 1-12 characters" % id)
	if str(s.get("text", "")) == "" or str(s.get("text", "")).length() > MAX_TEXT:
		out.append("%s: text must be 1-%d characters" % [id, MAX_TEXT])
	var limits := {
		"angry": [0, 3],
		"angry_mood": [10, 50],
		"patch_debt": [0, 10],
		"ticket_rate": [0.6, 1.0],
		"poach_wave": [0, 6],
		"rival_drain": [0, 3],
		"stack_fee": [0, 400]
	}
	for key in limits:
		if (
			s.has(key)
			and (float(s[key]) < float(limits[key][0]) or float(s[key]) > float(limits[key][1]))
		):
			out.append("%s: %s %s is out of range" % [id, key, str(s[key])])
	if s.has("ticket_weight"):
		out.append_array(_weights_problems("ticket_weight", s.ticket_weight, 0.5, 4.0))
	if s.has("until"):
		var u: Variant = s.until
		if (
			not (u is Array)
			or u.size() != 2
			or int(u[0]) < 1
			or int(u[0]) > 14
			or int(u[1]) < 1
			or int(u[1]) > 4
		):
			out.append("%s: until is [tech days, owner weeks]" % id)
	if s.has("cast_join"):
		for who in s.cast_join:
			if (
				not World.CAST.has(str(who))
				or int(s.cast_join[who]) < 2
				or int(s.cast_join[who]) > 5
			):
				out.append("%s: cast_join %s" % [id, str(who)])
	if (
		(s.has("stack_fee") or s.has("patch_debt") or s.has("poach_wave"))
		and not (kinds.has("owner") or kinds.has("both"))
	):
		out.append("%s: owner keys on a tech-only start" % id)
	if s.has("cast_join") and kinds != ["tech"]:
		out.append("%s: cast_join belongs on a tech-only start" % id)
	return out


func validate_all() -> Array:
	var out := []
	for id in MUTATORS:
		out.append_array(problems(str(id), MUTATORS[id]))
	for id in STARTS:
		out.append_array(start_problems(str(id), STARTS[id]))
	if not STARTS.has(STANDARD) or STARTS[STANDARD].size() > 4:
		out.append("standard must exist and change nothing")
	return out
