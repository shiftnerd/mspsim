extends Node
# gdlint:disable=max-line-length
# Owner campaign: client profitability, projects and services. MSPs live on recurring revenue (the monthly fee, plus
# services like managed backup), and projects (a desktop refresh, a network or server upgrade, a security cleanup) add
# one-time money on top. Both compete for the same technicians' hours, and both can quietly lose money:
#  - every client has hours included in their fee; going over is "scope creep" (the Boardroom shows hours and profit),
#  - a project has an estimate; fixed-price jobs that creep eat the margin unless you scope first or bill a change order,
#  - firing a client costs you a little word of mouth.
# A buyer values recurring earnings, so project profit is left out of the valuation (take_week_income).

const SEC_PER_HOUR := 15.0  # one tech-hour = 15 tech-seconds of the simulation (a tech-second costs Owner.COST_PER_SEC)
const BILL_RATE := 95  # what an extra hour costs a client
const DISCOVERY_FEE := 300
# extra hours when a fixed-price job creeps
const SCOPE_CREEP := 0.25
const TYPES := {
	"desktops":
	{
		"label": "DESKTOP REFRESH (XP REPLACEMENT)",
		"price": [1800, 3600],
		"hw": 0.62,
		"hours": 18,
		"weeks": 2,
		"blurb": "five or six Windows XP desktops need replacing before April 8"
	},
	"network":
	{
		"label": "NETWORK UPGRADE (SWITCHES AND WI-FI)",
		"price": [2800, 3800],
		"hw": 0.45,
		"hours": 26,
		"weeks": 3,
		"blurb": "their wireless is a guessing game and the switches are ten years old"
	},
	"server":
	{
		"label": "SERVER REPLACEMENT",
		"price": [6500, 8500],
		"hw": 0.5,
		"hours": 44,
		"weeks": 4,
		"blurb": "the file server is out of warranty and out of disk"
	},
	"voip":
	{
		"label": "PHONE SYSTEM UPGRADE (HOSTED VOIP)",
		"price": [2200, 3200],
		"hw": 0.5,
		"hours": 20,
		"weeks": 3,
		"blurb":
		"the phones are a tangle of analog lines and a box in the closet that nobody dares touch"
	},
	"email_move":
	{
		"label": "EMAIL MIGRATION (HOSTED MAIL)",
		"price": [1500, 2400],
		"hw": 0.1,
		"hours": 22,
		"weeks": 2,
		"blurb": "the mailboxes are full and the old mail server hums like a refrigerator"
	},
	"backup_dr":
	{
		"label": "BACKUP AND RECOVERY SETUP",
		"price": [1200, 1600],
		"hw": 0.25,
		"hours": 12,
		"weeks": 2,
		"blurb": "they want to know they can recover when it all goes wrong"
	},
	"security":
	{
		"label": "SECURITY CLEANUP",
		"price": [900, 1300],
		"hw": 0.2,
		"hours": 14,
		"weeks": 2,
		"blurb": "remote access, passwords and the firewall all need attention"
	},
}
const SERVICES := {
	"backup":
	{
		"label": "MANAGED BACKUP",
		"price": 110,
		"cost": 35,
		"blurb": "we watch their backups every night and fix failures before they matter"
	},
	"patching":
	{
		"label": "MANAGED UPDATES AND AV",
		"price": 80,
		"cost": 25,
		"blurb": "we keep every machine patched and protected"
	},
}
const PLATFORM_SETUP := 600
const PLATFORM_WEEKLY := 100

var projects: Array = []  # {id, client, type, method, price, hw, est, done, weeks, total, creep, scoped, delay, status, net, profit}
var services := {}  # client -> [service ids]
var hours_hist := {}  # client -> their last weekly hours
var wom_weeks := 0  # weeks of bad word of mouth left (Vic's close rate drops)
var enabled := true  # false in the balance harness to measure the campaign without projects and services
var completed_count := 0
var completed_profit := 0
var week_income := 0  # project money banked this week (left out of the valuation)

var _queue: Array = []  # things waiting for next morning: {kind: project|service|creep|wom, ...}
var _next_id := 1


func _ready() -> void:
	reset()


func reset() -> void:
	projects = []
	services = {}
	hours_hist = {}
	wom_weeks = 0
	completed_count = 0
	completed_profit = 0
	week_income = 0
	_queue = []
	_next_id = 1


func active() -> bool:
	return Campaign.books_active()


# ---- hours and profitability ------------------------------------------------------------------------
func hours(seconds: float) -> float:
	return seconds / SEC_PER_HOUR


func included_hours(client: int) -> float:
	return float(Owner.client_fee(client)) / 66.0  # a $800 fee covers about 12 hours a week


func client_hours(client: int) -> float:
	return hours(float(Owner.client_work.get(client, 0.0)))


# average of the recorded weeks (the Boardroom shows this)
func avg_hours(client: int) -> float:
	var list: Array = hours_hist.get(client, [])
	if list.is_empty():
		return client_hours(client)
	var total := 0.0
	for v in list:
		total += float(v)
	return total / float(list.size())


func over_hours(client: int) -> float:
	return maxf(0.0, avg_hours(client) - included_hours(client))


# called while settling, before the week's tech-seconds are reset
func record_week() -> void:
	for c in Sales.active:
		var list: Array = hours_hist.get(int(c), [])
		list.append(snappedf(client_hours(int(c)), 0.1))
		while list.size() > 4:
			list.pop_front()
		hours_hist[int(c)] = list


# ---- services (recurring) ---------------------------------------------------------------------------
func has_service(client: int, id: String) -> bool:
	return (services.get(client, []) as Array).has(id)


func service_revenue() -> int:
	var total := 0
	for c in services:
		if Sales.active.has(int(c)):
			for id in services[c]:
				total += int(SERVICES[id].price)
	return total


func service_cost() -> int:
	var total := 0
	for c in services:
		if Sales.active.has(int(c)):
			for id in services[c]:
				total += int(SERVICES[id].cost)
	return total


func sell_service(client: int, id: String) -> void:
	var list: Array = services.get(client, [])
	if not list.has(id):
		list.append(id)
	services[client] = list
	Sales.adjust(client, 4)


# every week the services do their job
func _services_week() -> void:
	for c in services:
		if not Sales.active.has(int(c)):
			continue
		if has_service(int(c), "backup"):
			Msp.backup_rerun(int(c))
		if has_service(int(c), "patching"):
			Owner.patch_debt[int(c)] = maxf(0.0, float(Owner.patch_debt.get(int(c), 0.0)) - 2.0)


# ---- capacity: projects use the same technicians as the tickets ---------------------------------------
func crew_hours() -> float:
	var crew := Owner.crew_heads()
	return crew * 240.0 / SEC_PER_HOUR


func weekly_project_hours() -> float:
	var total := 0.0
	for p in projects:
		if p.status == "active" and int(p.delay) <= 0:
			total += float(p.est) / float(p.total)
	return total


# the share of the team's time the running projects take away from tickets
func drag() -> float:
	if not active():
		return 0.0
	return clampf(weekly_project_hours() / maxf(1.0, crew_hours()), 0.0, 0.35)


# ---- opportunities -----------------------------------------------------------------------------------
func _pick_type(client: int) -> String:
	var pool := ["network", "server", "security"]
	if Campaign.day >= 3 and Campaign.day <= 8:
		pool.append_array(["desktops", "desktops", "desktops"])  # Windows XP ends on April 8; the wave ends with it (X9)
	if not has_service(client, "backup"):
		pool.append("backup_dr")
	if Campaign.day >= 5:
		pool.append("voip")  # P5: hosted phones, once the first weeks of fires are out of the way
	if Campaign.day >= 4:
		pool.append("email_move")
	if not Owner.flags.get("rdp_safe", false) and Campaign.day >= 7:
		pool.append("security")
	return pool[randi() % pool.size()]


func week() -> void:
	if not active() or not enabled:
		return
	_services_week()
	wom_weeks = maxi(0, wom_weeks - 1)
	_projects_week()
	if _queue.size() >= 2:
		return
	var chance := 0.22 + Sales.vic_skill() * 0.2 - (0.08 if wom_weeks > 0 else 0.0)
	if randf() < chance and not Sales.active.is_empty():
		var client := int(Sales.active[randi() % Sales.active.size()])
		if Sales.mood(client) < 45:
			return  # unhappy clients do not buy projects
		if (
			randf() < 0.35
			and (not has_service(client, "backup") or not has_service(client, "patching"))
		):
			_queue.append(
				{
					"kind": "service",
					"client": client,
					"id": "backup" if not has_service(client, "backup") else "patching"
				}
			)
		else:
			_queue.append({"kind": "project", "client": client, "type": _pick_type(client)})


# the next morning: one card at a time
func begin_week() -> void:
	if not active() or not enabled or _queue.is_empty() or Cards.is_open:
		return
	var item: Dictionary = _queue.pop_front()
	match str(item.kind):
		"project":
			_quote_card(item)
		"service":
			_service_card(item)
		"creep":
			_creep_card(item)
		"wom":
			_wom_card(item)


func make_quote(client: int, type_id: String) -> Dictionary:
	var t: Dictionary = TYPES[type_id]
	var price := int(round(randf_range(float(t.price[0]), float(t.price[1])) / 50.0)) * 50
	var hw := int(float(price) * float(t.hw))
	return {
		"client": client,
		"type": type_id,
		"price": price,
		"hw": hw,
		"est": float(t.hours),
		"weeks": int(t.weeks)
	}


func quote_profit(q: Dictionary) -> int:
	return int(q.price) - int(q.hw) - int(float(q.est) * SEC_PER_HOUR * Owner.COST_PER_SEC)


func _quote_card(item: Dictionary) -> void:
	var client := int(item.client)
	var q := make_quote(client, str(item.type))
	var name: String = Msp.CLIENTS[client].name
	var t: Dictionary = TYPES[str(item.type)]
	var blurb := str(t.blurb)
	if Campaign.day > 8:
		blurb = blurb.replace(" before April 8", " that are out of warranty")  # X9: the XP deadline has passed
	var text := (
		"%s: %s. Project: %s. About %d hours and $%d of hardware over %d weeks. At $%d fixed that is about %s profit if nothing creeps. How do we quote it?"
		% [
			name,
			blurb,
			str(t.label).to_lower(),
			int(q.est),
			int(q.hw),
			int(q.weeks),
			int(q.price),
			Owner.money(quote_profit(q))
		]
	)
	Cards.ask(
		"Vic Marlowe",
		text,
		[
			{"label": "FIXED PRICE ($%d)" % int(q.price), "id": "fixed"},
			{"label": "SCOPE IT FIRST ($%d DISCOVERY, SAFER)" % DISCOVERY_FEE, "id": "scope"},
			{"label": "TIME AND MATERIALS ($%d/HOUR)" % BILL_RATE, "id": "tm"},
			{"label": "PASS ON THE PROJECT", "id": "pass"},
		],
		func(id: String) -> void: _quoted(q, id)
	)


func _quoted(q: Dictionary, method: String) -> void:
	if method == "pass":
		Msp.send_text("Vic", "I told them we are too busy. They were not thrilled.")
		return
	start_project(q, method)
	var text := "Project signed: %s." % str(TYPES[str(q.type)].label).to_lower()
	if method == "scope":
		text += (
			" We bill $%d for discovery now and start next week with real numbers." % DISCOVERY_FEE
		)
	elif method == "tm":
		text += " Time and materials: they pay for what it takes, and they know it."
	Msp.send_text("Vic", text)


func start_project(q: Dictionary, method: String) -> Dictionary:
	var p := {
		"id": _next_id,
		"client": int(q.client),
		"type": str(q.type),
		"method": method,
		"price": int(q.price),
		"hw": int(q.hw),
		"est": float(q.est),
		"done": 0.0,
		"weeks": int(q.weeks),
		"total": int(q.weeks),
		"creep": false,
		"scoped": method == "scope",
		"delay": 1 if method == "scope" else 0,
		"status": "active",
		"net": 0,
		"profit": 0,
	}
	_next_id += 1
	projects.append(p)
	if method == "scope":
		Owner.cash += DISCOVERY_FEE
		Owner.income_extra += DISCOVERY_FEE
		week_income += DISCOVERY_FEE
		Owner.flags["practice_scope"] = true
	if method == "tm":
		Sales.adjust(int(q.client), -3)
	Msp.changed.emit()
	return p


# ---- the weekly step of every running project --------------------------------------------------------
func _projects_week() -> void:
	for p in projects:
		if p.status != "active":
			continue
		if int(p.delay) > 0:
			p.delay = int(p.delay) - 1
			continue
		if not Sales.active.has(int(p.client)):
			p.status = "lost"
			continue
		p.done = float(p.done) + float(p.est) / float(p.total)
		p.weeks = int(p.weeks) - 1
		if (
			p.method == "fixed"
			and not bool(p.creep)
			and not bool(p.scoped)
			and int(p.weeks) >= 1
			and randf() < 0.30
		):
			p.creep = true
			p.est = float(p.est) * (1.0 + SCOPE_CREEP)
			_queue.push_front({"kind": "creep", "id": int(p.id)})
		if int(p.weeks) <= 0:
			_complete(p)


func project(id: int) -> Dictionary:
	for p in projects:
		if int(p.id) == id:
			return p
	return {}


func _creep_card(item: Dictionary) -> void:
	var p := project(int(item.id))
	if p.is_empty() or p.status != "active":
		return
	var client := int(p.client)
	var extra := int(float(p.price) * SCOPE_CREEP)
	var odds := (
		0.55
		+ (0.15 if Sales.mood(client) >= 70 else 0.0)
		+ (0.1 if Owner.flags.get("practice_scope", false) else 0.0)
	)
	var text := (
		"%s project is creeping: they keep adding things (extra machines, one more site, 'while you are here'). The fixed price will not cover it: about %d more hours."
		% [Owner.poss(str(Msp.CLIENTS[client].name)), int(float(p.est) * SCOPE_CREEP / (1.0 + SCOPE_CREEP))]
	)
	Cards.ask(
		"Alan (Co-owner)",
		text,
		[
			{
				"label": "BILL A CHANGE ORDER ($%d, %d%% THEY AGREE)" % [extra, int(odds * 100.0)],
				"id": "co"
			},
			{"label": "HOLD THE ORIGINAL SCOPE (THEY ARE ANNOYED)", "id": "hold"},
			{"label": "EAT THE COST", "id": "eat"},
		],
		func(id: String) -> void: _creep_answer(int(p.id), id, extra, odds)
	)


func _creep_answer(id: int, choice: String, extra: int, odds: float) -> void:
	var p := project(id)
	if p.is_empty():
		return
	var client := int(p.client)
	match choice:
		"co":
			if randf() < odds:
				p.price = int(p.price) + extra
				Sales.adjust(client, -2)
				(
					Msp
					. send_text(
						"Alan",
						(
							"They signed the change order. $%d on top, and they now know requests cost money."
							% extra
						)
					)
				)
				Owner.flags["practice_scope"] = true
			else:
				Sales.adjust(client, -8)
				Msp.send_text(
					"Alan",
					"They refused to pay for the extras. We are eating it and they are sulking."
				)
		"hold":
			p.est = float(p.est) / (1.0 + SCOPE_CREEP)
			Sales.adjust(client, -4)
			(
				Msp
				. send_text(
					"Alan",
					"We told them the extras are a second project. They grumbled, and the schedule held."
				)
			)
		_:
			Msp.send_text("Alan", "We are absorbing it. Fine, but the margin is gone.")


func _complete(p: Dictionary) -> void:
	p.status = "done"
	var revenue := int(p.price)
	if p.method == "tm":
		revenue = int(float(p.done) * float(BILL_RATE) + float(p.hw) * 1.15)
	var labor := int(float(p.done) * SEC_PER_HOUR * Owner.COST_PER_SEC)
	p.net = revenue - int(p.hw)  # cash that arrives (labor is already in payroll)
	p.profit = revenue - int(p.hw) - labor
	Owner.cash += int(p.net)
	Owner.income_extra += int(p.net)
	week_income += int(p.net)
	completed_count += 1
	completed_profit += int(p.profit)
	var client := int(p.client)
	var smooth: bool = not bool(p.creep) or int(p.profit) > 0
	Sales.adjust(client, 8 if smooth else 3)
	if int(p.profit) > 0 and smooth:
		Campaign.adjust_rep(1)
	var verdict := (
		"made $%d" % int(p.profit) if int(p.profit) >= 0 else "LOST $%d" % absi(int(p.profit))
	)
	Msp.send_text(
		"Marge",
		(
			"%s finished at %s: we %s after labor."
			% [str(TYPES[str(p.type)].label).capitalize(), str(Msp.CLIENTS[client].name), verdict]
		)
	)
	if str(p.type) == "backup_dr" and not has_service(client, "backup"):
		_queue.push_front({"kind": "service", "client": client, "id": "backup"})
	Msp.changed.emit()


func _service_card(item: Dictionary) -> void:
	var client := int(item.client)
	var id := str(item.id)
	var s: Dictionary = SERVICES[id]
	var platform_missing: bool = id == "backup" and not Owner.flags.get("backup_service", false)
	var text := (
		"%s would sign for %s: %s. $%d a week to them, about $%d a week to us. %s"
		% [
			str(Msp.CLIENTS[client].name),
			str(s.label).to_lower(),
			str(s.blurb),
			int(s.price),
			int(s.price) - int(s.cost),
			(
				(
					"We need the backup platform first ($%d plus $%d a week)."
					% [PLATFORM_SETUP, PLATFORM_WEEKLY]
				)
				if platform_missing
				else "That is recurring revenue: the kind a buyer pays for."
			)
		]
	)
	var options := [
		{"label": "SELL IT ($%d/WEEK)" % int(s.price), "id": "sell"},
		{"label": "NOT NOW", "id": "no"}
	]
	if platform_missing:
		options[0] = {
			"label": "BUY THE PLATFORM ($%d) AND SELL IT" % PLATFORM_SETUP,
			"id": "sell",
			"enabled": Owner.cash >= PLATFORM_SETUP,
			"hint": "NEED $%d" % PLATFORM_SETUP
		}
	Cards.ask(
		"Vic Marlowe",
		text,
		options,
		func(choice: String) -> void: _service_answer(client, id, choice, platform_missing)
	)


func _service_answer(client: int, id: String, choice: String, platform_missing: bool) -> void:
	if choice != "sell":
		return
	if platform_missing:
		Owner.cash -= PLATFORM_SETUP
		Owner.weekly_extra += PLATFORM_WEEKLY
		Owner.flags["backup_service"] = true
	sell_service(client, id)
	Msp.send_text(
		"Vic",
		(
			"Signed: %s for %s. Recurring revenue!"
			% [str(SERVICES[id].label).to_lower(), str(Msp.CLIENTS[client].name)]
		)
	)


# an opportunity found on a visit: the quote card comes up the next morning
func offer_project(client: int, type: String) -> void:
	var waiting := 0
	for q in _queue:
		if str(q.get("kind", "")) == "project":
			waiting += 1
			if int(q.client) == client and str(q.type) == type:
				return  # already on the list
	if waiting >= 2:
		return
	_queue.append({"kind": "project", "client": client, "type": type})


# ---- change orders and firing: the answers to a client who costs more than they pay -----------------------
func change_order_amount(client: int) -> int:
	return int(over_hours(client) * 4.0 * float(BILL_RATE))  # four weeks of the extra hours


# X9: a change order is a gamble. A happy client, a pricing-minded owner and an early week help; a late-game squeeze hurts
func change_order_odds(client: int) -> float:
	return clampf(
		0.22 + float(Sales.mood(client) - 40) / 200.0 + float(Owner.edge("fee_accept")) - Owner.pressure() * 0.15,
		0.1,
		0.7
	)


func change_order(client: int) -> String:
	var amount := change_order_amount(client)
	var odds := change_order_odds(client)
	var roll := randf()
	if roll < odds:
		Owner.cash += amount
		Owner.income_extra += amount
		week_income += amount
		Owner.scope_fixed[client] = true  # from now on requests beyond the plan are billable
		Sales.adjust(client, -5)
		Owner.flags["practice_scope"] = true
		return (
			"They pay $%d for the extra work and accept that requests beyond the plan are billable."
			% amount
		)
	if roll < odds + (1.0 - odds) * 0.35:
		# a scope dispute: they pay half, want a discount to stay, and the relationship cools
		var half := amount / 2
		Owner.cash += half
		Owner.income_extra += half
		week_income += half
		Owner.discount[client] = {"mult": 0.9, "weeks": 6}
		Sales.adjust(client, -8)
		return (
			"A scope dispute: they pay half ($%d), ask for 10%% off for six weeks, and say the work was always included."
			% half
		)
	Sales.adjust(client, -12)
	if randf() < 0.5:
		Owner.discount[client] = {"mult": 0.9, "weeks": 4}
	return "They refuse the bill outright and threaten to review their contract. Things are tense."


# how = polite (30 days notice, a referral to another firm) or now
func fire_client(client: int, how: String) -> String:
	var mood := Sales.mood(client)
	var name: String = Msp.CLIENTS[client].name
	Owner.drop_client(client)
	var risk := 0.55 if mood < 45 else (0.25 if mood < 70 else 0.1)
	if how == "polite":
		risk *= 0.35
	else:
		Campaign.adjust_rep(-1)
	if randf() < risk:
		wom_weeks = 6
		Campaign.adjust_rep(-2)
		_queue.append({"kind": "wom", "client": client})
		return "%s is leaving angry and telling people. Expect to hear about it." % name
	if how == "polite" and mood >= 70 and randf() < 0.3:
		Owner._leads += 1
		return "%s leaves on good terms and says they will recommend you. A lead may follow." % name
	return "%s is gone. Word of mouth stays quiet, for now." % name


func _wom_card(item: Dictionary) -> void:
	var name: String = Msp.CLIENTS[int(item.client)].name
	Cards.ask(
		"Vic Marlowe",
		(
			"A prospect says %s told them we are hard to work with. It is going around the local business crowd. What do we do?"
			% name
		),
		[
			{"label": "CALL THE PROSPECT AND TELL OUR SIDE", "id": "call"},
			{
				"label": "OFFER A FREE HEALTH CHECK ($300)",
				"id": "check",
				"enabled": Owner.cash >= 300,
				"hint": "NEED $300"
			},
			{"label": "LET IT BLOW OVER", "id": "wait"},
		],
		func(id: String) -> void: _wom_answer(id)
	)


func _wom_answer(id: String) -> void:
	match id:
		"call":
			if randf() < 0.5:
				wom_weeks = maxi(0, wom_weeks - 3)
				Msp.send_text(
					"Vic", "The prospect heard me out. Not everybody believes the other side."
				)
			else:
				Msp.send_text("Vic", "The prospect was polite and went with someone else.")
		"check":
			Owner.cash -= 300
			wom_weeks = 0
			Owner._leads += 1
			Msp.send_text("Vic", "The health check impressed them. They want to talk.")


func vic_penalty() -> float:
	return 0.06 if wom_weeks > 0 and active() else 0.0


# project money is not recurring: the valuation leaves it out
func take_week_income() -> int:
	var v := week_income
	week_income = 0
	return v


func recurring_share() -> float:
	var rev := float(Owner.weekly_estimate().revenue)
	return float(service_revenue()) / maxf(1.0, rev)


func client_gone(client: int) -> void:
	services.erase(client)
	hours_hist.erase(client)
	for p in projects:
		if int(p.client) == client and p.status == "active":
			p.status = "lost"


func summary_lines() -> Array:
	var active_list := []
	for p in projects:
		if p.status == "active":
			active_list.append(p)
	return active_list


func to_dict() -> Dictionary:
	return {
		"projects": projects,
		"services": services,
		"hours": hours_hist,
		"wom": wom_weeks,
		"count": completed_count,
		"profit": completed_profit,
		"queue": _queue,
		"next": _next_id,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	projects = data.get("projects", [])
	var saved: Dictionary = data.get("services", {})
	for key in saved:
		services[int(key)] = saved[key]
	var hist: Dictionary = data.get("hours", {})
	for key in hist:
		hours_hist[int(key)] = hist[key]
	wom_weeks = int(data.get("wom", 0))
	completed_count = int(data.get("count", 0))
	completed_profit = int(data.get("profit", 0))
	_queue = data.get("queue", [])
	_next_id = int(data.get("next", 1))
