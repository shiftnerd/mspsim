extends SceneTree
# gdlint:disable=max-line-length
# X13: a scripted scan of every decision card that can take money. The defect it looks for is the one that bankrupted a careful
# owner on hard: an option that takes cash (or can, through a roll or a percentage) and says neither how much nor NEED.
#   owner    every card that goes through Owner.show_card: the static tables (Owner.CARDS with the rival, temptation and second
#            cast cards merged in, Habits.CARDS) and the cards built at run time (each builder is called in a prepared owner
#            game and its card read from Owner._dynamic). Per option, from Owner.option_cost and the label as the card shows it:
#              - a sure cost is on the label as dollars and greys the option out when the bank cannot pay (need >= the cost),
#                or the option is `later` (a dated bill)
#              - the worst case of a gamble is on the label ("RISK $3,500" or the figure itself)
#              - a card never leaves only gambles with money at stake once the priced answers are greyed (the vendor breach)
#            and the cards that are asked directly (Projects, ByName, the leaving client): picked option by option, a pick
#            that moves the bank must have had dollars on its label
#   service  every option of the Service / ServiceArc tables whose fx spends money (cost, stipend) names dollars
#   sales    the beat answers that cost the company money name dollars
#   Godot --headless --path godot -s res://tests/card_costs.gd [-- list]     (list prints every option that can take money)

const SAFE_CASH := 0  # the most an always-open answer may take out of the bank
const HURT_REP := -3  # a reputation loss this large (or a lost client or tech) is lasting damage
const BIG := 60000

var failures := 0
var ops: Script
var listing := false
var scanned := 0
var costly := 0
var seen_cards := {}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drop_cards(cards: Node) -> void:
	# close whatever is open or waiting without answering it (an answer would spend the money this scan is about)
	cards._queue.clear()
	if cards.is_open:
		cards._callback = Callable()
		for i in cards.options.size():
			if bool(cards.options[i].get("enabled", true)):
				cards.pick(i)
				break
	cards._queue.clear()
	if cards.is_open:
		cards.is_open = false
		cards._canvas.visible = false
	root.get_node("Game").ui_open = false


# the problems of one card shown through Owner.show_card
func _scan(id: String, card: Dictionary) -> Array:
	var o := root.get_node("Owner")
	var out := []
	var options: Array = card.get("options", [])
	var open_ok := 0  # options no bank balance can grey out
	var open_safe := 0  # ... that cannot take more than SAFE_CASH
	var open_fine := 0  # ... and that do no lasting damage either (no client or tech lost, no heavy reputation loss)
	var money_gated := 0  # harmless answers the bank can grey out (a card where EVERY answer can hurt is not a trap: a poach)
	var priced := 0
	for i in options.size():
		var opt: Dictionary = options[i]
		scanned += 1
		var cost: Array = ops.cost(opt)
		var lo := int(cost[0])
		var hi := int(cost[1])
		var label: String = ops.label(opt, cost)
		var need := int(ops.need(opt, cost))
		var later := bool(opt.get("later", false))
		if hi > 0:
			costly += 1
			priced += 1
			if listing:
				print("  %s [%d] %s  cost %d..%d need %d%s" % [id, i, label, lo, hi, need, " later" if later else ""])
		if lo > 0 and not label.contains("$"):
			out.append("%s option %d takes $%d and the label does not say so: %s" % [id, i, lo, label])
		# (a card with one button is a bill, not a choice: it only has to name the sum)
		if lo > 0 and need < lo and not later and options.size() > 1:
			out.append("%s option %d takes $%d and is not greyed out without it (need %d): %s" % [id, i, lo, need, label])
		if hi > lo and not (label.contains("RISK") or label.contains(o.money(hi))):
			out.append("%s option %d can take $%d and the label does not say so: %s" % [id, i, hi, label])
		var gated: bool = (need > 0 and not later) or bool(opt.get("policy", false)) or opt.has("unless")
		if not gated:
			open_ok += 1
			# a `later` option is a dated bill when the bank is short: it never takes the sum at once
			if hi <= SAFE_CASH or later:
				open_safe += 1
				open_fine += 0 if _hurts(opt) else 1
		elif need > 0 and not _hurts(opt):
			money_gated += 1  # a harmless answer that only money buys
	# when every option can be greyed the card adds NOT NOW by itself (Cards.ask); the trap is a card whose only answers
	# left open are gambles for money
	if options.size() >= 2 and priced > 0 and open_ok > 0 and open_safe == 0:
		out.append("%s: with an empty bank every answer left is a gamble for money" % id)
	elif options.size() >= 2 and money_gated > 0 and open_ok > 0 and open_fine == 0:
		out.append("%s: with an empty bank every answer left can lose a client, a tech or %d reputation" % [id, -HURT_REP])
	return out


# an answer that can do lasting damage: a client or a tech lost, or a heavy reputation loss (any outcome of a roll counts)
func _hurts(opt: Dictionary) -> bool:
	var outcomes := [opt.get("fx", {})]
	for table in [opt.get("roll", []), opt.get("roll_scoped", [])]:
		for entry in table:
			outcomes.append(entry[1])
	for fx in outcomes:
		if fx.has("drop_client") or fx.has("drop") or fx.has("lose_tech") or fx.has("fire") or int(fx.get("rep", 0)) <= HURT_REP:
			return true
	return false


func _scan_dynamic(what: String, build: Callable, problems: Array) -> void:
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	o.cash = BIG
	var before := {}
	for k in o._dynamic:
		before[k] = str(o._dynamic[k])
	build.call()
	var n := 0
	for k in o._dynamic:
		if not before.has(k) or str(before[k]) != str(o._dynamic[k]):
			problems.append_array(_scan(str(k), o._dynamic[k]))
			seen_cards[str(k)] = true
			n += 1
	if n == 0 and listing:
		print("  (no card from: %s)" % what)
	_drop_cards(cards)


# a card asked directly: every option is picked once in a fresh copy of the situation; money that leaves must have been named
func _probe(what: String, open: Callable, problems: Array) -> void:
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var k := 0
	var guard := 0
	while guard < 8:
		guard += 1
		_drop_cards(cards)
		o.cash = BIG
		open.call()
		if not cards.is_open or k >= cards.options.size():
			break
		var label := str(cards.options[k].label)
		var cash0: int = o.cash
		scanned += 1
		cards.pick(k)
		if o.cash < cash0:
			costly += 1
			if listing:
				print("  %s [%d] %s  took %d" % [what, k, label, cash0 - o.cash])
			if not label.contains("$"):
				problems.append("%s option %d took $%d and the label does not say so: %s" % [what, k, cash0 - o.cash, label])
		# and with an empty bank the same option is greyed out
		_drop_cards(cards)
		if o.cash < cash0:
			var took: int = cash0 - o.cash
			o.cash = 0
			open.call()
			if cards.is_open and k < cards.options.size() and bool(cards.options[k].get("enabled", true)):
				problems.append("%s option %d takes $%d and is open with an empty bank: %s" % [what, k, took, label])
		k += 1
	_drop_cards(cards)
	seen_cards[what] = true


func _walk_fx(v: Variant, path: String, out: Array) -> void:
	if v is Dictionary:
		if v.has("label") and v.get("fx") is Dictionary:
			var fx: Dictionary = v.fx
			var money := 0
			for key in ["cost", "stipend"]:
				if fx.get(key) is int or fx.get(key) is float:
					money = maxi(money, int(fx[key]))
			scanned += 1
			if money > 0:
				costly += 1
				if listing:
					print("  %s  %s  cost %d" % [path, str(v.label), money])
				if not str(v.label).contains("$"):
					out.append("%s spends $%d and the label does not say so: %s" % [path, money, str(v.label)])
		for k in v:
			_walk_fx(v[k], path + "." + str(k), out)
	elif v is Array:
		for i in v.size():
			_walk_fx(v[i], path + "." + str(i), out)


func _init() -> void:
	await process_frame
	ops = load("res://scripts/owner_ops.gd")  # after the autoloads exist (it names Owner)
	listing = OS.get_cmdline_user_args().has("list")
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var sales := root.get_node("Sales")
	var msp := root.get_node("Msp")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Difficulty").seed_run(4242)
	c.new_game("owner")
	_drop_cards(cards)
	c.day = 14
	o.flags["card_bec_scare"] = 0
	o.flags["bec_client"] = int(sales.active[0])
	o.flags["bec_amount"] = 10000
	o.flags["peer_group"] = true
	o.flags["mentor"] = true

	# ---- owner, the static tables
	var problems := []
	for id in o.CARDS:
		problems.append_array(_scan(str(id), o.CARDS[id]))
		seen_cards[str(id)] = true
	var habits: Script = load("res://scripts/habits.gd")
	for id in habits.CARDS:
		if habits.CARDS[id] is Dictionary and habits.CARDS[id].has("options"):
			problems.append_array(_scan("habit " + str(id), habits.CARDS[id]))
	var static_n := scanned
	_check(static_n > 200, "the static owner tables were scanned (%d options)" % static_n)

	# ---- owner, the cards built at run time
	var first: int = int(sales.active[0])
	var second: int = int(sales.active[1])
	var builders := [
		["goal", func() -> void: o._goal_card()],
		["prospect", func() -> void: o._prospect_card()],
		["hire", func() -> void: o._hire_card()],
		["vendor rise", func() -> void: o._vendor_rise()],
		["key poach", func() -> void: o._key_poach()],
		["audit", func() -> void: o._audit()],
		["credit squeeze", func() -> void: o._credit_squeeze()],
		["vendor breach", func() -> void: o._vendor_breach()],
		["client no", func() -> void: o._client_no()],
		["handover", func() -> void: o._handover_card(first)],
		["peer goal", func() -> void: o._peer_goal()],
		["qbr", func() -> void: o._qbr()],
		["vic report", func() -> void: o._vic_report()],
		["winback", func() -> void:
			o.gone[7] = {"week": 9, "reason": "price", "mood": 50}
			o._winback_card(7)],
		["poach price", func() -> void: o._poach_card({"client": first, "kind": "price"})],
		["poach gaps", func() -> void: o._poach_card({"client": first, "kind": "gaps"})],
		["collections", func() -> void:
			o.ar.append({"client": second, "amount": 800, "age": 3, "delay": 3})
			o._collections(second)],
		["grumble", func() -> void:
			var st: Dictionary = o.stack.duplicate()
			for category in o.STACK:
				var worst := ""
				var low := 0
				for key in o.STACK[category].options:
					if int(o.STACK[category].options[key].get("morale", 0)) < low:
						low = int(o.STACK[category].options[key].morale)
						worst = str(key)
				if worst != "":
					o.stack[category] = worst
			o._grumble()
			o.stack = st],
		["burnout", func() -> void:
			o.burnout = 60.0
			o._burn_warned = false
			o._burnout_week()],
		["draw warning", func() -> void:
			o.cash = 500
			o.draw_warned = -9
			o._draw_check(600)],
		["desk", func() -> void:
			o.flags["desk_over"] = 2
			o.flags["desk_warned"] = 0
			o.flags.erase("desk_warn_week")
			o._desk_morning()],
		["profit review", func() -> void:
			o.profit_hist[first] = [-300, -300, -300]
			o.client_work[first] = 900.0
			o._profit_review()],
	]
	for i in 9:
		builders.append(["advice %d" % i, func() -> void:
			if i == 1:
				o.cash = 900
			o._advice_week = {} if i == 0 else o._advice_week
			o.advice()])
	for i in ops.LEADS.size() + 1:
		builders.append(["lead %d" % i, func() -> void: o._inbound_lead()])
	for b in builders:
		_scan_dynamic(str(b[0]), b[1], problems)
	var partner := root.get_node("Partner")
	for beat in partner.get("BEATS") if partner.get("BEATS") is Dictionary else {}:
		_scan_dynamic("partner beat " + str(beat), func() -> void: partner.hold_beat(str(beat)), problems)
	_check(seen_cards.has("vendor_breach") and seen_cards.has("audit") and seen_cards.has("lead") and seen_cards.has("advice") and seen_cards.has("desk"), "the run-time cards were built and read (%d cards in all)" % seen_cards.size())

	# ---- owner, the cards asked directly
	var projects := root.get_node("Projects")
	_probe("leaving client", func() -> void: o._ask_leaving(first), problems)
	_probe("word of mouth", func() -> void: projects._wom_card({"client": first}), problems)
	var byname: Script = load("res://scripts/byname.gd")
	_probe("lopsided crew", func() -> void:
		var st: Dictionary = byname.ostate()
		for k in sales.active:
			st.fav[str(k)] = "Dan"
		byname.lopsided_card(o, "Dan"), problems)

	for p in problems:
		_check(false, str(p))
	_check(problems.is_empty(), "owner: no option takes money without a price, a NEED or a named risk (%d options, %d can take money)" % [scanned, costly])

	# ---- the cards this row was written for
	_drop_cards(cards)
	o.cash = 214
	o._vendor_breach()
	var open_free := -1
	for i in cards.options.size():
		var data: Dictionary = o._dynamic["vendor_breach"].options[i]
		if bool(cards.options[i].get("enabled", true)) and not data.has("roll") and int(ops.cost(data)[1]) == 0:
			open_free = i
	_check(cards.is_open and not bool(cards.options[0].get("enabled", true)) and open_free >= 0, "vendor breach with $214: the $600 answer is greyed and an honest answer without a gamble is open (option %d)" % open_free)
	var rep0: int = c.rep
	var burn0: float = o.burnout
	cards.pick(open_free)
	_check(o.cash == 214 and o.burnout > burn0 and c.rep >= rep0, "it costs no cash: a tired crew (burnout %.0f to %.0f), no reputation lost" % [burn0, o.burnout])
	_drop_cards(cards)
	o.cash = 100
	o._audit()
	open_free = -1
	for i in cards.options.size():
		var data2: Dictionary = o._dynamic["audit"].options[i]
		if bool(cards.options[i].get("enabled", true)) and not data2.has("roll") and int(ops.cost(data2)[1]) == 0:
			open_free = i
	_check(open_free >= 0, "the audit with $100: an answer without a gamble is open (option %d)" % open_free)
	_drop_cards(cards)

	# ---- service: an answer that spends money says so
	var service_problems := []
	var before_service := scanned
	var strings := root.get_node("Strings")
	for root_name in ["Service", "ServiceArc"]:
		var node := root.get_node(root_name)
		for table in strings.ROOTS[root_name]:
			var data: Variant = node.get(str(table))
			if data != null:
				_walk_fx(data, "%s.%s" % [root_name, str(table)], service_problems)
	for p in service_problems:
		_check(false, str(p))
	_check(service_problems.is_empty() and scanned > before_service, "service: every answer that spends money names dollars (%d options read)" % (scanned - before_service))

	# ---- sales: the beat answers that cost the company money
	var sc := root.get_node("SalesCampaign")
	var sales_ok := true
	for pair in [["refund", "card", "refund"], ["refund", "card", "credit"], ["logo", "pick", "broker"]]:
		var row: Dictionary = sc.BEAT_TEXT.get(pair[0], {}).get(pair[1], {})
		var found := false
		for opt in row.get("options", []):
			if str(opt.id) == pair[2]:
				found = true
				if not str(opt.label).contains("$"):
					sales_ok = false
					_check(false, "sales beat %s answer %s costs the company money and the label does not say so: %s" % [pair[0], pair[2], str(opt.label)])
		if not found:
			sales_ok = false
			_check(false, "sales beat %s has no answer %s" % [pair[0], pair[2]])
	_check(sales_ok, "sales: the refund, the half month and the brokered discovery name dollars")

	c.quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
