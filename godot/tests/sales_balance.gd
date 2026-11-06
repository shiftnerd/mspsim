extends SceneTree
# gdlint:disable=max-line-length,unused-argument
# Dev tool (not a test): plays the 20 weeks of the sales campaign with a scripted strategy, several seeds, and prints the numbers
# (quota %, commission, clawbacks, churn, renewals, rep, cash and the verdict). One strategy per process:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/sales_balance.gd -- careful 11 12 13
#   strategies: careful (honest, safe promises, follows up), pushy (promises the moon, discounts, drops promises), lazy (one quote a
#   week at most, never follows up, takes the paperwork). Add `smooth` / `farmer` / `overpromise` as a 2nd word to try a John build.

const PREFS := {
	"careful": ["standard", "balanced", "work", "go", "honest", "take", "no", "value", "own", "qbr", "phone", "listen", "numbers", "comfort", "discount", "happy", "sell", "broker", "credit", "decline", "disclose", "ticket", "same", "ok"],
	"pushy": ["stretch", "commission", "loose", "work", "go", "moon", "take", "yes", "match", "blame", "report", "renew", "bluff", "all", "garrison", "refuse", "both", "shade", "raise", "project", "numbers", "ok"],
	"shady": ["match", "cheap", "take", "undercut", "back", "standard", "balanced", "work", "go", "honest", "no", "value", "own", "qbr", "phone", "listen", "numbers", "comfort", "discount", "happy", "sell", "broker", "credit", "decline", "disclose", "ticket", "same", "ok"],
	"lazy": ["safe", "salary", "standard", "work", "skip", "no", "same", "report", "wait", "none", "refuse", "decline", "pass", "ok"],
}
var strategy := "careful"
var build_name := ""
var seeds: Array = []
var results: Array = []
var _bell_node: Node = null


class _FakeBell:
	extends Node

	func ring(_cause := "vic") -> void:
		pass


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


# answer the open cards by the strategy's list of ids (the first option whose id comes earliest; the first enabled one otherwise)
func _answer(cards: Node, handover_gap: float) -> int:
	var n := 0
	var prefs: Array = PREFS[strategy]
	while cards.is_open and n < 40:
		var best := -1
		var best_rank := 999
		var is_handover := false
		for i in cards.options.size():
			if not bool(cards.options[i].get("enabled", true)):
				continue
			var id := str(cards.options[i].get("id", ""))
			if id in ["kept", "renegotiated", "dropped"]:
				is_handover = true
			var rank: int = prefs.find(id)
			if rank >= 0 and rank < best_rank:
				best_rank = rank
				best = i
		if is_handover:
			var want := "dropped" if strategy == "pushy" else ("kept" if strategy == "lazy" else "kept")
			if strategy in ["careful", "shady"]:
				var g := 0.0
				var rx := RegEx.new()
				rx.compile("gap ([0-9.]+)")
				var m := rx.search(str(cards.text))
				if m != null:
					g = float(m.get_string(1))
				want = "renegotiated" if g >= 0.5 else "kept"
			for i in cards.options.size():
				if str(cards.options[i].id) == want:
					best = i
		if best < 0:
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					best = i
					break
		cards.pick(maxi(best, 0))
		n += 1
	return n


func o_consc() -> int:
	return int(root.get_node("Owner").consc)


func _quote_for(sc: Node, l: Dictionary) -> Dictionary:
	var deals: GDScript = load("res://scripts/deals.gd")
	var q := {"method": "fixed", "promise": "std", "price": "list", "discount": 0, "extras": [], "onboard": "std"}
	if strategy == "pushy":
		q.promise = "high"
		q.onboard = "rush"
		q.discount = 20 if sc.discount_ok(l) else 10
		return q
	if strategy == "lazy":
		return q
	# careful: the best promise that keeps the gap small and the margin above Alan's floor
	for promise in ["std", "low"]:
		q.promise = promise
		var g: Dictionary = deals.gauges(l, q)
		if float(g.gap) <= 0.35 and bool(g.can_send):
			break
	for e in ["backup", "patching", "security"]:
		if deals.pain_match(l, e) and q.extras.size() < 1:
			var q2: Dictionary = q.duplicate(true)
			q2.extras = [e]
			if float(deals.gauges(l, q2).gap) <= 0.6:
				q = q2
	return q


func _act(sc: Node, world: Node, day: int, hour: float) -> void:
	var open: Array = sc.open_leads()
	open.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.quality) > int(y.quality))
	var max_quotes := 4 if strategy != "lazy" else (1 if day % 2 == 0 else 0)
	var sent := 0
	for l in open:
		if sent >= max_quotes or sc.slots_left() < 2:
			break
		if str(l.stage) not in ["LEAD", "MEETING"]:
			continue
		if strategy in ["careful", "shady"] and int(l.quality) < 28:
			continue
		sc.call_lead(int(l.id))
		world.clock = maxf(world.clock, hour)
		if strategy == "pushy":
			l["moon"] = true  # promised the moon at the office
		sc.send_quote(l, _quote_for(sc, l))
		sent += 1
	if strategy in ["careful", "shady"]:
		for l in sc.open_leads():
			if sc.slots_left() < 1:
				break
			if str(l.stage) == "QUOTED" and int(l.get("follow", 0)) < 2:
				sc.follow_up(int(l.id))


func _dummy_bell() -> Node:
	if _bell_node == null:
		_bell_node = _FakeBell.new()
	return _bell_node


func _run(seed_value: int) -> Dictionary:
	var c := root.get_node("Campaign")
	var sc := root.get_node("SalesCampaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var report := root.get_node("DayReport")
	var game := root.get_node("Game")
	var onsite := root.get_node("Onsite")
	var owner_node := root.get_node("Owner")
	var player_script: GDScript = load("res://scripts/player.gd")
	player_script.current_character = "office_john"
	game.title_mode = false
	game.busy = false
	root.get_node("Difficulty").seed_run(seed_value)
	root.get_node("Build").pending = {}
	if build_name != "":
		var b: Dictionary = root.get_node("Build").apply_preset("sales", "John", "normal", build_name) if build_name != "overpromise" else root.get_node("Build").apply_preset("sales", "John", "normal", "hunter")
		if build_name == "overpromise":
			b["quirks"] = ["overpromise"]
		root.get_node("Build").pending = b
	c.new_game("sales")
	await _wait(0.5)
	_answer(cards, 0.0)
	var out := {"seed": seed_value, "weeks": 0, "fired": false}
	for day in range(1, 21):
		world.clock = 8.6
		var hour := 8.6
		var acted := false
		var guard := 0
		while not report.is_open and hour < 23.9 and guard < 400:
			guard += 1
			hour += 0.25
			if not acted and hour > 9.2:
				acted = true
				_act(sc, world, day, hour)
				_answer(cards, 0.0)
			if not acted or hour > 9.3:
				world.clock = maxf(world.clock, hour)
			await process_frame
			await process_frame
			_answer(cards, 0.0)
			if onsite.active:
				onsite._go_home(false)
				await _wait(0.3)
				_answer(cards, 0.0)
			if hour > 10.0 and sc.pending_handover != 0 and strategy != "lazy" and not sc.Handover.pending().is_empty():
				sc.Handover.start(sc.Handover.pending())
				_answer(cards, 0.0)
			if hour > 13.0 and sc.bell_ready:
				sc.ring_bell(_dummy_bell())
		out.weeks = day
		if not report.is_open:
			break
		if report.report.get("final", false):
			out.fired = bool(report.report.get("fired", false))
			break
		report.finish()
		await _wait(0.5)
		game.busy = false
		_answer(cards, 0.0)
	out["q2"] = sc.quota_pct(0)
	out["q3"] = sc.quota_pct(1)
	out["res"] = "%s/%s" % [str(sc.q_result[0]), str(sc.q_result[1])]
	out["commission"] = sc.commission_total
	out["wins"] = sc.wins
	out["losses"] = sc.losses
	out["claw"] = sc.clawbacks
	out["churn"] = sc.churned.size()
	out["renew"] = "%d/%d" % [sc.renewals_won, sc.renewals_won + sc.renewals_lost]
	out["mood"] = int(sc.client_mood())
	out["rep"] = c.rep
	out["cash"] = owner_node.cash
	out["book"] = sc.book_mrr()
	var ids := []
	for o in sc.offers():
		ids.append(str(o.id))
	out["verdict"] = ",".join(ids) if not out.fired else "FIRED"
	out["lies"] = sc.SalesRival.lies()
	out["folder"] = sc.SalesRival.open_bills().size()
	out["consc"] = o_consc()
	out["bb"] = str(sc.flags.get("bb", "-"))
	out["dd"] = str(sc.flags.get("dd", "-"))
	if report.is_open:
		report.finish()
		await _wait(0.4)
	var review := root.get_node("Review")
	if review.is_open:
		review.finish()
		await _wait(0.4)
	if c.active:
		c.finish_campaign("balance")
		await _wait(0.3)
	game.busy = false
	return out


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		strategy = str(args[0])
	for i in range(1, args.size()):
		if str(args[i]).is_valid_int():
			seeds.append(int(args[i]))
		else:
			build_name = str(args[i])
	if seeds.is_empty():
		seeds = [11, 12, 13]
	await process_frame
	root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
	print("strategy=%s build=%s seeds=%s" % [strategy, build_name if build_name != "" else "flat", str(seeds)])
	var tot := {"q2": 0, "q3": 0, "commission": 0, "claw": 0, "churn": 0, "wins": 0, "cash": 0, "rep": 0, "book": 0}
	var hit := 0
	var good := 0
	for s in seeds:
		var r: Dictionary = await _run(int(s))
		results.append(r)
		print("seed %d: Q2 %d%% Q3 %d%% (%s) wins %d lost %d commission $%d claw %d churn %d renew %s mood %d rep %d cash $%d book $%d bb=%s audit=%s lies %d folder %d consc %d -> %s" % [r.seed, r.q2, r.q3, r.res, r.wins, r.losses, r.commission, r.claw, r.churn, r.renew, r.mood, r.rep, r.cash, r.book, r.bb, r.dd, r.lies, r.folder, r.consc, r.verdict])
		for k in tot:
			tot[k] += int(r[k])
		hit += str(r.res).count("HIT")
		if str(r.verdict).contains("director"):
			good += 1
	var n := float(seeds.size())
	print("AVERAGE %s: Q2 %d%% Q3 %d%% quarters hit %.1f of 2, commission $%d, wins %.1f, clawbacks %.1f, churned %.1f, rep %d, cash $%d, book $%d, director verdicts %d of %d" % [strategy, tot.q2 / n, tot.q3 / n, hit / n, tot.commission / n, tot.wins / n, tot.claw / n, tot.churn / n, tot.rep / n, tot.cash / n, tot.book / n, good, seeds.size()])
	quit(0)
