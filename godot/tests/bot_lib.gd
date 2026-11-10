extends RefCounted
# gdlint:disable=class-definitions-order,duplicated-load,max-line-length,max-returns,unused-argument
# Q6: the shared bot driver. One class plays any campaign (tech / owner / sales / service) at any difficulty tier with a
# strategy (careful / lazy / chaotic, plus tech-only "shortcut") for one seed, in compressed time, and returns one row:
#   {mode, tier, strategy, seed, rep, score, ending, cls ("good" / "mid" / "bad"), fired, info}
# Used by tests/tiers_balance.gd (fast smoke asserts), tests/bot_run.gd (the slow harness, one cell per process) and
# tests/shortcut_sim.gd (alt-fix economics). The three older harnesses (owner_balance, sales_balance, service_balance)
# keep their own copies for natural-time work; the bots below were ported from them.
#
#   var bots := load("res://tests/bot_lib.gd").new(self)   (inside a SceneTree script)
#   var row: Dictionary = await bots.play("tech", "normal", "careful", 11)

const MODES := ["tech", "owner", "sales", "service"]
const STRATEGIES := ["careful", "lazy", "chaotic"]
# "mixed" (tech and service): careful on even days, lazy on odd ones (T2: an average player, part careful and part lazy)
const TIERS := ["easy", "normal", "hard"]

var tree: SceneTree
var root: Node
var strategy := "careful"
var ts := 20.0  # time compression: game seconds per real second at 60 fps = ts (World.time_scale)
var build_name := ""
var preset_build := {}  # a build set as the pending one for tech and service runs (sales uses build_name)
var rng := RandomNumberGenerator.new()
var _last_day := 0
var _ticks := 0
var _jobs := 0
var _talk_i := 0
var _sa_bell: Node = null
var log_days := false
var policy: Dictionary = {}
var card_log: Array = []  # every card this run answered: {day, clock, who, text, pick}
var year2 := false  # the next play() starts a New Game Plus on the meta record the run before left (see play_year2)
var keep_meta := false  # play() ends through Campaign.finish_campaign, so the meta record of the run exists
var stop_day := 0  # tech: stop after this day's report (0 = play to the end); tests/bot_determinism.gd
var frame_hook := Callable()  # dev: called once per bot frame (tests/bot_det.gd traces state with it)


var year := 1  # R10: 2 or 3 starts every run as START YEAR 2 / 3, from the record of a decent finished year before (_seed_year)


func _init(t: SceneTree) -> void:
	tree = t
	root = t.root


func _wait(secs: float) -> void:
	await tree.create_timer(secs).timeout


# ---- the entry point ---------------------------------------------------------------------------------------------
func play(mode: String, tier: String, strat: String, seed_n: int) -> Dictionary:
	strategy = strat
	card_log = []
	if not year2:
		_purge_own_files()
	var d := root.get_node("Difficulty")
	d.settings_path = "user://bot_%d_settings.cfg" % OS.get_process_id()  # set_tier saves: never write the player's real settings file
	d.set_tier(tier)
	var c := root.get_node("Campaign")
	c.save_prefix = "user://bot_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	_clean_slate()
	# every run starts on a freshly loaded office floor, as a new game does from the title. (Without it the first run of a process
	# played day 1 with no scene at all, so nobody in the office had a body, while a second run inherited the floor of the first.)
	tree.change_scene_to_file("res://scenes/main_floor.tscn")
	for i in 4:
		await tree.process_frame
	await tree.process_frame  # and at the same point of a frame (a caller that comes from a timer is half a frame off)
	root.get_node("Build").pending = preset_build.duplicate(true)
	if year2:
		root.get_node("Yeartwo").begin_select(mode, true, 2)  # taken by Campaign.new_game (needs the finished run's meta record)
	else:
		root.get_node("Yeartwo").pending = false
	d.seed_run(seed_n)
	seed(seed_n * 31 + 7)  # the owner campaign and the Shift cards still draw from the global generator
	rng.seed = seed_n * 7919
	if year >= 2:
		_seed_year(mode)
	var row: Dictionary = {}
	if coop and mode in ["sales", "service"]:
		root.get_node("Players").enable_coop(true)
		root.get_node("Players").join(1, 1)  # player 2 is in the room (their sheet is the stock fallback person)
	match mode:
		"tech":
			row = await tech_run(seed_n)
		"owner":
			row = await ow_run(seed_n)
		"sales":
			row = await _sales_row(seed_n)
		"service":
			row = await _service_row(seed_n)
	if coop and mode != "tech":
		root.get_node("Players").leave(1)
		root.get_node("Players").enable_coop(false)
	row["mode"] = mode
	row["tier"] = tier
	row["strategy"] = strat
	row["seed"] = seed_n
	row["year"] = 2 if year2 else year
	row["last_day"] = int(c.day)
	row["cards"] = card_log.duplicate(true)
	strategy = strat
	if keep_meta and c.active:
		c.finish_campaign(str(row.get("ending", "bot")))  # writes the meta record New Game Plus reads
		await _wait(0.3)
		root.get_node("Game").busy = false
	d.set_tier("normal")
	return row


# R10: a year 1 run, then Year 2 (New Game Plus) on what it left behind: the carry-over (skills, reputation, cash, trust), the three
# newer clients, tighter clocks, one tier more mutators, the story shuffle. Returns the Year 2 row with the year 1 row in `year1`.
func play_year2(mode: String, tier: String, strat: String, seed_n: int) -> Dictionary:
	year2 = false
	keep_meta = true
	var first: Dictionary = await play(mode, tier, strat, seed_n)
	if bool(first.fired) or not root.get_node("Yeartwo").available(mode):
		keep_meta = false
		first["info"] = "NO YEAR 2 (year 1 %s) %s" % ["fired" if bool(first.fired) else "left no record", str(first.get("info", ""))]
		return first
	year2 = true
	var row: Dictionary = await play(mode, tier, strat, seed_n + 500)
	year2 = false
	keep_meta = false
	row["year1"] = first
	row["seed"] = seed_n
	var carried: Dictionary = root.get_node("Yeartwo").carried
	row["info"] = "Y2 (year 1: rep %d %s; start rep %d) %s" % [int(first.rep), str(first.cls), int(carried.get("rep", -1)), str(row.get("info", ""))]
	return row


func _note_card(cards: Node, pick: int) -> void:
	var o: Variant = cards.options[pick] if pick >= 0 and pick < cards.options.size() else {}
	var id := str(o.get("id", pick)) if o is Dictionary else str(pick)
	card_log.append({"day": int(root.get_node("Campaign").day), "clock": float(root.get_node("World").clock), "who": str(cards.speaker), "text": str(cards.text).substr(0, 56).replace("\n", " "), "pick": id, "n": _enabled_idx(cards).size()})


# nothing of an earlier run in this process may leak into the next one: a card that was still waiting would be answered inside
# the new game (its callback moves energy, cash or reputation), and a run that was cut short leaves the clock stopped
func _clean_slate() -> void:
	var cards := root.get_node("Cards")
	var guard := 0
	while (cards.is_open or cards.waiting() > 0) and guard < 60:
		guard += 1
		if cards.is_open:
			var en := _enabled_idx(cards)
			cards.pick(int(en[0]) if not en.is_empty() else 0)
		else:
			cards._queue.clear()
	cards._queue.clear()
	var pb := root.get_node("Playbook")
	if pb.is_active():
		pb.reset()
	root.get_node("Game").ui_open = false
	root.get_node("World").time_scale = 1.0


# R10: the meta record a decent finished run of the year before leaves (reputation 70, skills at level 3, a company worth
# $150,000), and the START YEAR 2 / 3 choice of the title row: the run's own new_game picks it up
func _seed_year(mode: String) -> void:
	var y := root.get_node("Yeartwo")
	var skills := {}
	for key in root.get_node("Skills").NAMES:
		skills[key] = 3
	var rec := {"ending": "stay", "rep": 70, "tier": "normal", "cozy": false, "seed": 1, "clients": 8, "skills": skills, "value": 150000, "cash": 15000, "trust": 60, "shop": [], "standard": 0}
	var meta := ConfigFile.new()
	for key in rec:
		meta.set_value(mode, key, rec[key])
	for key in ["finished", "year", "top_year"]:
		meta.set_value(mode, key, year - 1)
	if year >= 3:
		meta.set_value(mode, "y2", rec)
	meta.save(y.meta_path())
	y.begin_select(mode, true, year)


# process ids are reused: a bot must not inherit the career or campaign files an earlier run left under its pid
func _purge_own_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var prefix := "bot_%d_" % OS.get_process_id()
	for f in dir.get_files():
		if f.begins_with(prefix):
			dir.remove(f)


func line(r: Dictionary) -> String:
	return "BOT %s %s %s seed %d: rep %d score %d ending %s cls %s fired %s | %s" % [r.mode, r.tier, r.strategy, int(r.seed), int(r.rep), int(r.score), str(r.ending), str(r.cls), str(r.fired), str(r.get("info", ""))]


# ---- cards ---------------------------------------------------------------------------------------------------------
func _enabled_idx(cards: Node) -> Array:
	var out := []
	for i in cards.options.size():
		if bool(cards.options[i].get("enabled", true)):
			out.append(i)
	return out


func _first_of(cards: Node, ids: Array) -> int:
	for want in ids:
		for i in cards.options.size():
			if str(cards.options[i].get("id", "")) == want and bool(cards.options[i].get("enabled", true)):
				return i
	return -1


# the tech campaign's cards (commute, pager, stay late, protected time, story and event cards)
func tech_pick(cards: Node) -> int:
	var en := _enabled_idx(cards)
	if en.is_empty():
		return 0
	var shift := root.get_node("Shift")
	if strategy == "chaotic":
		return int(en[rng.randi() % en.size()])
	var pref: Array
	if strategy == "lazy":
		pref = ["late", "ignore", "home", "skip", "squeeze", "fav_ignore"]
	else:  # careful and shortcut
		pref = ["take", "early" if shift.energy >= 45.0 else "ontime", "triage" if shift.energy < 55.0 else "fix", "1" if root.get_node("Msp").open_tickets().size() > 2 else "home", "fav_desk"]
	var i := _first_of(cards, pref)
	return i if i >= 0 else int(en[0])


func _drain_tech(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		n += 1
		var tp := tech_pick(cards)
		_note_card(cards, tp)
		cards.pick(tp)


func _cleanup_review(review: Node, game: Node, pick: int) -> void:
	if review.offers.is_empty():
		return
	review.choose(pick)
	review.is_open = false  # (finish() would send the game back to the title screen)
	review._canvas.visible = false
	game.ui_open = false


# ---- tech ---------------------------------------------------------------------------------------------------------
# One bot tick is dt game seconds. A job is one remote fix: {tid, ep, act, left}. Reading the ticket, switching windows and
# closing it add TECH_OVERHEAD seconds (the real UI takes about that long); the lazy bot also idles between tickets.
const TECH_OVERHEAD := {"careful": 28.0, "proper": 28.0, "shortcut": 28.0, "heavy": 28.0, "lazy": 30.0, "chaotic": 22.0}
const TECH_IDLE := {"careful": 0.0, "proper": 0.0, "shortcut": 0.0, "heavy": 0.0, "lazy": 55.0, "chaotic": 25.0}
const TECH_STEADY := ["careful", "proper", "shortcut", "heavy"]  # the ones who study, keep the backups green and run the projects
# P6: what each strategy tries on a ransomed machine, in order, once the backup restore has failed (an exit that is not on
# offer, like the insurer without a policy, is skipped). `ransom_order` (non-empty) replaces it for every strategy.
const RANSOM_PLANS := {
	"careful": ["restore", "vendor", "insurer", "shadow", "rebuild"],
	"lazy": ["restore", "shadow", "pay"],
	"chaotic": ["pay"],
}
var ransom_order: Array = []
var use_scripts := true  # X7: the careful bot runs the PowerShell scripts (off = the bot of before, for comparison)
var _ransom_i: Dictionary = {}

var _tj: Dictionary = {}
var _tbusy := 0.0
var coop := false  # co-op (R34 phase 5): a second bot works the same queue as player 2 (own skills, ticket pace x1.5)
var _bot_state := [{"busy": 0.0, "tj": {}}, {"busy": 0.0, "tj": {}}]
var _bot_k := 0
var _other_tid := -1
var _att: Dictionary = {}
var tech_stats := {"quick": 0, "proper": 0, "clever": 0, "returns": 0, "wrong": 0, "unfixed_closes": 0, "work": 0.0, "fails": 0, "heavy": 0, "scripted": 0, "exits": []}
var _base_strategy := ""


func _tech_morning() -> void:
	var sk := root.get_node("Skills")
	var msp := root.get_node("Msp")
	_tj = {}
	_tbusy = 0.0
	if strategy in TECH_STEADY:
		if sk.can_study() and sk.ps_level < sk.LESSONS.size():
			sk.pass_lesson(sk.ps_level)
			_tbusy += 45.0  # a lesson takes real time
		# X7: without BACKUP WATCH (security 3) the daily check of every job is the only way to see a failed one; with it the
		# failed jobs announce themselves and only those cost time
		var failed := 0
		for client in msp.backups.size():
			failed += 0 if bool(msp.backups[client].ok) else 1
			msp.backup_rerun(client)  # a careful tech keeps the backups green
		_tbusy += (5.0 * float(failed)) if sk.backup_watch() else 20.0


func _tech_story() -> void:
	var pb := root.get_node("Playbook")
	var msp := root.get_node("Msp")
	if pb.is_active():
		var guard := 0
		while pb.is_active() and guard < 12:
			guard += 1
			var step: Dictionary = pb.current_step()
			var best := -1
			var best_pts := -9999
			for i in step.choices.size():
				var ch: Dictionary = step.choices[i]
				if pb.lock_reason(ch) == "":
					var p := int(ch.pts)
					if strategy == "chaotic":
						p = rng.randi() % 10
					elif strategy == "lazy":
						p = 100 - i  # the first thing that is not locked
					if p > best_pts:
						best_pts = p
						best = i
			if best < 0:
				break
			pb.choose(best)
		_tbusy += 30.0
	if strategy in TECH_STEADY and not msp.project.is_empty() and not msp.project.done:
		msp.project_ask()
		msp.project_scan(true)
		msp.project_backup()
		msp.project_select_all()
		msp.project_migrate()
		msp.project_verify()
		msp.project_select_all()
		msp.project_migrate()
		msp.project_handover()
		_tbusy += 120.0


# choose the action for a ticket: the proper fix, a clever alternative, or (shortcut) the quick workaround
func _tech_action(t: Dictionary) -> String:
	var msp := root.get_node("Msp")
	var ep: Dictionary = msp.endpoint(str(t.endpoint))
	var act := str(t.fix)
	if ep.is_empty():
		return act
	if act == "restore":  # the ransomed machine: the next exit of the plan
		var plan: Array = ransom_order if not ransom_order.is_empty() else RANSOM_PLANS.get(strategy, RANSOM_PLANS.careful)
		var i := int(_ransom_i.get(int(t.id), 0))
		while i < plan.size() - 1 and str(plan[i]) == "insurer" and not msp.cyber_insured(int(ep.client)):
			i += 1
		_ransom_i[int(t.id)] = i + 1
		return str(plan[mini(i, plan.size() - 1)])
	var sk := root.get_node("Skills")
	if use_scripts and strategy in ["careful", "proper"] and sk.can_script() and str(ep.problem) == act and not (act in ["restore", "project", "network"]):
		# X7: POWERSHELL 2 runs one script for every PC of this client with the same problem (level 4: every client). A player who
		# has it uses it as soon as two tickets ask for the same fix, so the bot does too
		var everywhere: bool = sk.script_all()
		for o in msp.open_tickets():
			if int(o.id) == int(t.id) or str(o.fix) != act or bool(o.fix_done) or not (everywhere or int(o.client) == int(t.client)):
				continue
			var oep: Dictionary = msp.endpoint(str(o.endpoint))
			if not oep.is_empty() and str(oep.problem) == act:
				return ("scriptall:" if everywhere else "script:") + act
	if strategy == "chaotic" and rng.randf() < 0.5:
		var wrong: Array = ["reboot", "av", "clear_temp", "password", "spooler"]
		var w := str(wrong[rng.randi() % wrong.size()])
		if w != act:
			tech_stats.wrong += 1
			return w
	var alts: Array = msp.alts_for(ep)
	var want := "quick" if strategy == "shortcut" else ("clever" if strategy == "careful" else ("heavy" if strategy == "heavy" else ""))
	if want != "":
		for id in alts:
			if str(msp.ALT_DEFS[id].kind) == want:
				return str(id)
	return act


# One frame of bot time. The steps below (busy, the fix, picking the next ticket) share the frame's dt: what one step does not
# use goes to the next, so the bot's speed does not depend on the time scale. (Before, every change of step cost a whole frame:
# four frames a ticket, 1.3 game seconds at ts=20 but 8 at ts=120, which made the same seed a harder game the faster it ran.)
func _tech_tick(dt: float) -> void:
	var left := dt
	var guard := 0
	while left > 0.0 and guard < 12:
		guard += 1
		left = _tech_step(left)


# returns the part of dt this step did not use
func _tech_step(dt: float) -> float:
	var msp := root.get_node("Msp")
	var sk := root.get_node("Skills")
	var growth := root.get_node("Growth")
	if _tbusy > 0.0:
		var spent := minf(dt, _tbusy)
		_tbusy -= spent
		return dt - spent
	if not _tj.is_empty():
		var used := minf(dt, float(_tj.left))
		_tj.left = float(_tj.left) - used
		if float(_tj.left) > 0.0:
			return 0.0
		dt -= used
		var job := _tj
		_tj = {}
		var t: Dictionary = msp.ticket(int(job.tid))
		if t.is_empty() or t.status == "Closed":
			return dt
		var raw := str(job.act)
		var bulk := raw.begins_with("script")
		var act := raw.get_slice(":", 1) if bulk else raw
		var ep_now: Dictionary = msp.endpoint(str(t.endpoint))
		var is_heavy := str(msp.ALT_DEFS.get(act, {}).get("kind", "")) == "heavy"
		if is_heavy and not ep_now.is_empty() and rng.randf() < msp.heavy_fail_chance(ep_now, act):
			_tj = {"tid": job.tid, "act": act, "left": sk.fix_secs_for(act) * msp.heavy_slow(ep_now, act)}  # hard: "THE IMAGE FAILED AT 90 PERCENT"
			tech_stats.fails += 1
			tech_stats.work += float(_tj.left)
			return dt
		if not (act in ["restore", "pay", "shadow", "save", "vendor", "insurer", "rebuild"]) and not is_heavy and rng.randf() < sk.fail_chance() + growth.fail_adjust(act):
			_tj = {"tid": job.tid, "act": raw, "left": sk.fix_secs_for(act) + 2.0}  # "FIX DID NOT STICK. TRY AGAIN."
			tech_stats.fails += 1
			tech_stats.work += float(_tj.left)
			return dt
		var story := root.get_node("Story")
		var before: int = story.flags.get("followups", []).size()
		if bulk:
			tech_stats.scripted += msp.rmm_bulk(int(t.client), act, raw.begins_with("scriptall"))
		else:
			msp.rmm_action(str(t.endpoint), act)
		var kind := str(msp.ALT_DEFS.get(act, {}).get("kind", "proper"))
		tech_stats[kind if tech_stats.has(kind) else "proper"] += 1
		tech_stats.returns += maxi(0, story.flags.get("followups", []).size() - before)
		if str(t.fix) == "restore":
			tech_stats.exits.append(act)
		if t.fix_done or (strategy == "chaotic" and rng.randf() < 0.7):
			if not t.fix_done:
				tech_stats.unfixed_closes += 1
			msp.close_ticket(int(t.id))
		_tbusy = float(TECH_IDLE[strategy]) * rng.randf_range(0.5, 1.5)
		return dt
	if _bot_k == 0:
		_tech_story()
	if _tbusy > 0.0:
		return dt
	var open: Array = msp.open_tickets()
	var pool := []
	for t in open:
		if str(t.fix) in ["project", "network"] or t.status == "Waiting" or int(_att.get(int(t.id), 0)) >= (8 if str(t.fix) == "restore" else 3) or int(t.id) == _other_tid:
			continue
		pool.append(t)
	if pool.is_empty():
		_tbusy = 4.0
		return dt
	var pick: Dictionary = pool[0]  # sorted by priority, then by the SLA clock
	if strategy == "lazy":
		pool.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.id) < int(y.id))
		pick = pool[0]  # first come, first served, whatever the priority
	elif strategy == "chaotic":
		pick = pool[rng.randi() % pool.size()]
	if bool(pick.fix_done):
		msp.close_ticket(int(pick.id))
		_tbusy = 3.0
		return dt
	_att[int(pick.id)] = int(_att.get(int(pick.id), 0)) + 1
	var act := _tech_action(pick)
	var secs: float = (sk.fix_secs_for(act.get_slice(":", 1)) + 1.0) if act.begins_with("script") else sk.fix_secs_for(act)
	if act == "reboot":
		secs += 4.0
	if str(msp.ALT_DEFS.get(act, {}).get("kind", "")) == "heavy":
		secs *= msp.heavy_slow(msp.endpoint(str(pick.endpoint)), act)
	_tj = {"tid": pick.id, "act": act, "left": secs}
	tech_stats.work += secs
	_tbusy = float(TECH_OVERHEAD[strategy]) * rng.randf_range(0.7, 1.3)
	return dt


# one bot's turn: its own busy timer and job, and (bot 1) its own skills through Players.run_as
func _tick_bot(k: int, dt: float) -> void:
	var players := root.get_node("Players")
	var st: Dictionary = _bot_state[k]
	var other: Dictionary = _bot_state[1 - k]
	_bot_k = k
	_tbusy = float(st.busy)
	_tj = st.tj
	_other_tid = int(other.tj.get("tid", -1)) if not other.tj.is_empty() else -1
	if k == 0:
		_tech_tick(dt)
	else:
		players.run_as(1, _tech_tick.bind(dt))
	st.busy = _tbusy
	st.tj = _tj
	_bot_k = 0


func _partner_morning() -> void:
	var sk := root.get_node("Skills")
	var st: Dictionary = _bot_state[1]
	st.tj = {}
	st.busy = 0.0
	if strategy in TECH_STEADY and sk.can_study() and sk.ps_level < sk.LESSONS.size():
		sk.pass_lesson(sk.ps_level)
		st.busy = 45.0


func tech_run(seed_n: int) -> Dictionary:
	var c := root.get_node("Campaign")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var game := root.get_node("Game")
	c.new_game("tech")
	var players := root.get_node("Players")
	_bot_state = [{"busy": 0.0, "tj": {}}, {"busy": 0.0, "tj": {}}]
	if coop:
		players.enable_coop(true)
		players.join(1, 1)
	_last_day = 0
	_att = {}
	tech_stats = {"quick": 0, "proper": 0, "clever": 0, "returns": 0, "wrong": 0, "unfixed_closes": 0, "work": 0.0, "fails": 0, "heavy": 0, "scripted": 0, "exits": []}
	_base_strategy = strategy
	_ransom_i = {}
	if _base_strategy == "mixed":
		strategy = "lazy"  # day 1 is an odd day
	var frames := 0
	var row := {}
	var days: Array = []
	var fired := false
	while frames < 200000:
		frames += 1
		await tree.process_frame
		if frame_hook.is_valid():
			frame_hook.call(frames)
		if report.is_open:
			var r: Dictionary = report.report
			days.append(int(r.get("rep", 0)))
			if OS.has_environment("BOT_DEBUG"):
				print("  d%d rep %d (report %+d%s) closed %d missed %d reo %d open %d grade %s frames %d" % [c.day, c.rep, int(r.get("rep_delta", 0)), " sloppy" if bool(r.get("sloppy", false)) else "", r.closed, r.missed, r.reopened, r.open_left, str(r.get("grade", "")), frames])
				for ot in msp.open_tickets():
					print("     open #%d %s fix %s special %s tries %d breached %s: %s" % [int(ot.id), str(ot.status), str(ot.fix), str(ot.special), int(_att.get(int(ot.id), 0)), str(ot.breached), str(ot.summary).substr(0, 40)])
			if stop_day > 0 and c.day >= stop_day and not bool(r.get("final", false)):
				row = {"rep": c.rep, "score": msp.score, "fired": false, "ending": "STOPPED", "closed": msp.closed_ok, "missed": msp.breached, "reopened": msp.reopened}
				report.finish()
				await _wait(0.7)
				game.busy = false
				break
			if bool(r.get("final", false)):
				fired = bool(r.get("fired", false))
				row = {"rep": c.rep, "score": msp.score, "fired": fired, "closed": msp.closed_ok, "missed": msp.breached, "reopened": msp.reopened}
				report.finish()
				await tree.process_frame
				await _wait(0.3)
				var ids := []
				for o in review.offers:
					ids.append(str(o.id))
				row["ending"] = "FIRED" if fired else ("lead" if ids.has("lead") else ("internal" if ids.has("internal") else "stay"))
				if not fired:
					var pick := 0
					for want in ["lead", "internal", "stay"]:
						for i in review.offers.size():
							if str(review.offers[i].id) == want:
								pick = i
								break
						if ids.has(want):
							break
					_cleanup_review(review, game, pick)
				break
			report.finish()
			await _wait(0.7)
			game.busy = false
			continue
		if cards.is_open:
			_drain_tech(cards)
			continue
		if c.day != _last_day:
			_last_day = c.day
			if _base_strategy == "mixed":
				strategy = "careful" if c.day % 2 == 0 else "lazy"
			_tech_morning()
			_bot_state[0] = {"busy": _tbusy, "tj": {}}
			if coop:
				players.run_as(1, _partner_morning)
			continue
		world.time_scale = ts
		_tick_bot(0, ts / 60.0)
		if coop:
			_tick_bot(1, ts / 60.0)
	if row.is_empty():
		row = {"rep": c.rep, "score": msp.score, "fired": false, "ending": "TIMEOUT", "closed": msp.closed_ok, "missed": msp.breached, "reopened": msp.reopened}
	row["cls"] = "bad" if (fired or c.rep < 45) else ("good" if str(row.ending) == "lead" else "mid")
	strategy = _base_strategy
	row["curve"] = days
	row["info"] = "closed %d missed %d reopen %d scars %d ps %d quick %d proper %d clever %d returns %d fails %d work %ds heavy %d scripted %d ransom %s %s curve %s" % [int(row.closed), int(row.missed), int(row.reopened), c.scars, root.get_node("Skills").ps_level, tech_stats.quick, tech_stats.proper, tech_stats.clever, tech_stats.returns, int(tech_stats.fails), int(tech_stats.work), int(tech_stats.heavy), int(tech_stats.scripted), str(root.get_node("Story").flags.get("ransom", "-")), "+".join(tech_stats.exits), str(days)]
	row["tech_stats"] = tech_stats.duplicate()
	if coop:
		var xp_total := 0
		for k in players.slot(1).skills.get("xp", {}):
			xp_total += int(players.slot(1).skills.xp[k])
		row["info"] += " | p2 xp %d ps %d" % [xp_total, int(players.slot(1).skills.get("ps_level", 0))]
		players.leave(1)
		players.enable_coop(false)
	return row



# ---- service bot body ---------------------------------------------------------------------------------------------
const SV_KB_ORDER := ["password", "spooler", "reboot", "clear_temp", "av", "restore", "adobe", "rdp", "ransom", "rack", "email24", "migration"]

func sv_enabled(cards: Node) -> Array:
	var out := []
	for i in cards.options.size():
		if bool(cards.options[i].get("enabled", true)):
			out.append(i)
	return out


func sv_idx_of(cards: Node, id: String) -> int:
	for i in cards.options.size():
		if str(cards.options[i].id) == id and bool(cards.options[i].get("enabled", true)):
			return i
	return -1


# ---- what each strategy answers --------------------------------------------------------------------------------
func sv_answer(cards: Node) -> int:
	var en := sv_enabled(cards)
	if en.is_empty():
		return 0
	var ids := []
	for o in cards.options:
		ids.append(str(o.id))
	var text := str(cards.text)
	if strategy == "lazy":
		return int(en[0])
	if strategy == "chaotic":
		if ids.has("tiered") and ids.has("swarm"):
			return sv_idx_of(cards, "swarm")
		return int(en[rng.randi() % en.size()])
	# careful
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var day: int = root.get_node("Campaign").day
	if text.contains("check the lesson"):  # C7: a runbook lesson to sign off: the careful manager knows the safe first step
		for rid in sv.RUNBOOKS:
			var quiz: Dictionary = sv.RUNBOOKS[rid].get("quiz", {})
			if not quiz.is_empty() and text.contains(str(quiz.q)):
				var right := sv_idx_of(cards, str(int(quiz.answer)))
				if right >= 0:
					return right
	if ids.has("p1") and ids.has("queue") and ids.has("mentor"):
		return sv_idx_of(cards, "mentor") if (day % 4 == 2 and crew.morale_avg() >= 50) else sv_idx_of(cards, "p1")
	if ids.has("tiered"):
		return sv_idx_of(cards, "tiered")
	if ids.has("decide"):
		var done: int = sv.interviewed.size()
		if done < 2:
			for i in en:
				if str(cards.options[i].id).begins_with("i"):
					return int(i)
		return sv_idx_of(cards, "decide")
	if ids.has("h0"):
		var best := 0
		var best_v := -1.0
		for i in sv.cands.size():
			var f: Dictionary = sv.cands[i].fit
			var v := float(f.culture) + float(f.comm) + float(f.curiosity) + 2.0 * float(sv.cands[i].skill)
			if v > best_v:
				best_v = v
				best = i
		return sv_idx_of(cards, "h%d" % best)
	if ids.has("structured"):
		var s := sv_idx_of(cards, "structured")
		return s if s >= 0 else sv_idx_of(cards, "shadow")
	if ids.has("take") and ids.has("send") and ids.has("ask"):
		if text.contains("ransom") or text.contains("Ransom"):
			return sv_idx_of(cards, "ask")
		return sv_idx_of(cards, "take")
	for pref in ["broker", "small", "doc", "train", "par", "none", "both", "tier", "n", "pull", "40", "l", "m", "t", "home", "cover"]:
		if ids.has(pref) and not (pref == "m" and ids.has("p")):
			var j := sv_idx_of(cards, pref)
			if j >= 0:
				return j
	if ids.has("a") and ids.has("b") and ids.has("c"):  # an owner memo: do both while the crew is rested, else the sender's ask
		return sv_idx_of(cards, "c") if crew.morale_avg() >= 55 else sv_idx_of(cards, "a")
	if ids.has("q") and ids.has("s") and ids.has("b"):
		return sv_idx_of(cards, "q")
	if ids.has("d") and ids.has("n") and ids.has("m"):
		return sv_idx_of(cards, "n")
	return int(en[0])


# a taken Playbook job: the best choice of every step (the careful manager does the work properly)
func sv_do_job() -> void:
	var pb := root.get_node("Playbook")
	var guard := 0
	while pb.is_active() and guard < 12:
		guard += 1
		var choices: Array = pb.current_step().choices
		var best := -1
		for i in choices.size():
			if pb.lock_reason(choices[i]) == "":
				if best < 0 or int(choices[i].pts) > int(choices[best].pts):
					best = i
		if best < 0:
			break
		pb.choose(best)
	root.get_node("ServiceArc").job_done_check()


func sv_morning() -> void:
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var c := root.get_node("Campaign")
	if OS.has_environment("SB_DEBUG"):
		print("  day %d conf %d trust %d/%d morale %d doc %d%% mood %d" % [c.day, c.rep, sv.trust_of("Alan"), sv.trust_of("Garrison"), crew.morale_avg(), sv.kb.doc_pct(), int(root.get_node("Sales").average())])
	if strategy == "careful":
		# the runbooks: the cheapest next step of the first class that is not live
		var guard := 0
		while sv.kb.hours_left() >= 0.5 and guard < 12:
			guard += 1
			var did := false
			for id in SV_KB_ORDER:
				var cost: Dictionary = sv.kb.cost_of(id)
				if str(cost.act) in ["none", "wait", "train"]:
					if str(cost.act) == "train" and sv.kb.hours_left() >= float(cost.dan) and guard < 12 and c.day >= 8:
						pass
					else:
						continue
				if float(cost.dan) <= sv.kb.hours_left() + 0.001:
					var res: Dictionary = sv.kb.advance(str(id))
					if bool(res.get("ok", false)):
						did = true
						break
			if not did:
				break
		# one on ones: two people a day, in turn, and the quiet ones first
		var who := ["Maya", "John"]
		for n in crew.names():
			if n != "Maya":
				who.append(str(n))
		for k in 2:
			sv.one_on_one(str(who[_talk_i % who.size()]))
			_talk_i += 1
		sv_drain_cards()
		if c.day == 4 and sv.training == "none":
			sv.training = "light"


func sv_drain_cards() -> void:
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 60:
		n += 1
		var sp := sv_answer(cards)
		_note_card(cards, sp)
		cards.pick(sp)
	if strategy == "careful" and root.get_node("Playbook").is_active():
		sv_do_job()
		sv_drain_cards_tail()


func sv_drain_cards_tail() -> void:
	var cards := root.get_node("Cards")
	var n := 0
	while cards.is_open and n < 20:
		n += 1
		var sp := sv_answer(cards)
		_note_card(cards, sp)
		cards.pick(sp)


func sv_board_tick() -> void:
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var msp := root.get_node("Msp")
	_ticks += 1
	if strategy == "careful":
		for who in crew.stuck.keys():
			var st: Dictionary = crew.stuck[who]
			var t: Dictionary = msp.ticket(int(st.ticket))
			if t.is_empty():
				continue
			var better: String = crew.best_for(t, 2)
			if better != "" and better != who:
				sv.assign(int(t.id), better, true)
			else:
				sv.assign(int(t.id), "Dan", true)
		# your own hands: close the tickets on your lane, one every few seconds
		if _ticks % 6 == 0:
			for t in msp.open_tickets():
				if crew.assignee_of(t) == "Dan" and str(t.special) == "":
					t["fix_done"] = true
					msp.close_ticket(int(t.id))
					break
	elif strategy == "chaotic" and _ticks % 4 == 0:
		var open: Array = msp.open_tickets()
		if not open.is_empty():
			var t: Dictionary = open[rng.randi() % open.size()]
			if str(t.special) == "":
				var lanes: Array = crew.names() + ["Dan", "ESC", ""]
				sv.assign(int(t.id), str(lanes[rng.randi() % lanes.size()]), true)


# ---- one run -----------------------------------------------------------------------------------------------------
func sv_run(seed_n: int) -> Dictionary:
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var cards := root.get_node("Cards")
	var world := root.get_node("World")
	var msp := root.get_node("Msp")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var arc := root.get_node("ServiceArc")
	var sales := root.get_node("Sales")
	load("res://scripts/player.gd").current_character = "office_dan"
	root.get_node("Game").title_mode = false
	root.get_node("Game").busy = false
	c.save_prefix = "user://bal_%d_" % OS.get_process_id()
	if year >= 2:
		_seed_year("service")  # R10: the record has to sit under this run's own prefix
	rng.seed = seed_n * 7919
	root.get_node("Difficulty").seed_run(seed_n)
	c.new_game("service")
	var base := strategy
	if base == "mixed":
		strategy = "lazy"
	_last_day = 0
	_ticks = 0
	_talk_i = 0
	var frames := 0
	var ended := false
	var fired := false
	var row := {}
	while frames < 400000 and not ended:
		frames += 1
		await tree.process_frame
		if frame_hook.is_valid():
			frame_hook.call(frames)
		if report.is_open:
			var r: Dictionary = report.report
			if bool(r.get("final", false)):
				fired = bool(r.get("fired", false))
				row = sv_snapshot(seed_n, fired)
				report.finish()
				await tree.process_frame
				if not fired:
					await tree.create_timer(0.3).timeout
					review.page = 2
					var pick := sv_ending_index(review)
					row["offers"] = sv_offer_ids(review)
					row["ending"] = str(review.offers[pick].id) if not review.offers.is_empty() else "?"
					review.choose(pick)
					review.is_open = false  # (finish() would send the game back to the title screen)
					review._canvas.visible = false
					root.get_node("Game").ui_open = false
				else:
					row["offers"] = []
					row["ending"] = "FIRED"
				ended = true
				break
			report.finish()
			await tree.create_timer(0.7).timeout
			root.get_node("Game").busy = false
			continue
		if cards.is_open:
			sv_drain_cards()
			continue
		if c.day != _last_day:
			_last_day = c.day
			if base == "mixed":
				strategy = "careful" if c.day % 2 == 0 else "lazy"
			sv_morning()
			continue
		world.time_scale = ts
		if frames % 10 == 0:
			sv_board_tick()
	if not ended:
		row = sv_snapshot(seed_n, false)
		row["ending"] = "TIMEOUT"
		row["offers"] = []
	strategy = base
	await tree.process_frame
	return row

func sv_offer_ids(review: Node) -> Array:
	var out := []
	for o in review.offers:
		out.append(str(o.id))
	return out


func sv_ending_index(review: Node) -> int:
	var arc := root.get_node("ServiceArc")
	var prio := ["ops", "alan", "garrison", "rollup_yes", "leave", "stay"]
	for p in prio:
		if p == "rollup_yes" and int(arc.audit_score().tier) < 2:
			continue  # a low-ball offer is not an ending anyone is proud of
		for i in review.offers.size():
			if str(review.offers[i].id) == p:
				return i
	return review.offers.size() - 1


func sv_snapshot(seed_n: int, fired: bool) -> Dictionary:
	var c := root.get_node("Campaign")
	var sv := root.get_node("Service")
	var crew := root.get_node("Crew")
	var arc := root.get_node("ServiceArc")
	var msp := root.get_node("Msp")
	var count := {"S": 0, "A": 0, "B": 0, "C": 0, "D": 0}
	for g in sv.grades:
		count[str(g.grade)] = int(count[str(g.grade)]) + 1
	var a: Dictionary = arc.audit_score()
	return {
		"seed": seed_n, "day": c.day, "conf": c.rep, "ta": sv.trust_of("Alan"), "tg": sv.trust_of("Garrison"), "crew": crew.size(), "quits": crew.quits.size(),
		"morale": crew.morale_avg(), "doc": sv.kb.doc_pct(), "ret": crew.retention_pct(), "sla": arc._sla_pct(), "closed": msp.closed_ok, "missed": msp.breached,
		"reopened": msp.reopened, "audit": int(a.total), "tier": int(a.tier), "grades": count, "fired": fired, "sides": arc.sides.duplicate(), "credits": arc.credits,
		"wave": arc.wave_pct(), "design": sv.design, "pages": arc.oncall.nights, "fair": snappedf(arc.fairness(), 0.01),
	}



# ---- sales bot body ------------------------------------------------------------------------------------------------
const SA_PREFS := {
	"careful": ["standard", "balanced", "work", "go", "honest", "take", "no", "value", "own", "qbr", "phone", "listen", "numbers", "comfort", "discount", "happy", "sell", "broker", "credit", "decline", "disclose", "ticket", "same", "ok"],
	"pushy": ["stretch", "commission", "loose", "work", "go", "moon", "take", "yes", "match", "blame", "report", "renew", "bluff", "all", "garrison", "refuse", "both", "shade", "raise", "project", "numbers", "ok"],
	"lazy": ["safe", "salary", "standard", "work", "skip", "no", "same", "report", "wait", "none", "refuse", "decline", "pass", "ok"],
}
var strategy_sa := ""


class SaFakeBell:
	extends Node

	func ring(_cause := "vic") -> void:
		pass


func sa_answer(cards: Node, handover_gap: float) -> int:
	var n := 0
	var prefs: Array = SA_PREFS[strategy]
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
			if strategy == "careful":
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
		_note_card(cards, maxi(best, 0))
		cards.pick(maxi(best, 0))
		n += 1
	return n


func sa_quote_for(sc: Node, l: Dictionary) -> Dictionary:
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


func sa_act(sc: Node, world: Node, day: int, hour: float) -> void:
	var open: Array = sc.open_leads()
	open.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.quality) > int(y.quality))
	var max_quotes := 4 if strategy != "lazy" else (1 if day % 2 == 0 else 0)
	var sent := 0
	for l in open:
		if sent >= max_quotes or sc.slots_left() < 2:
			break
		if str(l.stage) not in ["LEAD", "MEETING"]:
			continue
		if strategy == "careful" and int(l.quality) < 28:
			continue
		sc.call_lead(int(l.id))
		world.clock = maxf(world.clock, hour)
		if strategy == "pushy":
			l["moon"] = true  # promised the moon at the office
		sc.send_quote(l, sa_quote_for(sc, l))
		sent += 1
	if strategy == "careful":
		for l in sc.open_leads():
			if sc.slots_left() < 1:
				break
			if str(l.stage) == "QUOTED" and int(l.get("follow", 0)) < 2:
				sc.follow_up(int(l.id))


func sa_dummy_bell() -> Node:
	if _sa_bell == null:
		_sa_bell = SaFakeBell.new()
	return _sa_bell


func sa_run(seed_value: int) -> Dictionary:
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
	sa_answer(cards, 0.0)
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
				sa_act(sc, world, day, hour)
				sa_answer(cards, 0.0)
			if not acted or hour > 9.3:
				world.clock = maxf(world.clock, hour)
			await tree.process_frame
			await tree.process_frame
			sa_answer(cards, 0.0)
			if onsite.active:
				onsite._go_home(false)
				await _wait(0.3)
				sa_answer(cards, 0.0)
			if hour > 10.0 and sc.pending_handover != 0 and strategy != "lazy" and not sc.Handover.pending().is_empty():
				sc.Handover.start(sc.Handover.pending())
				sa_answer(cards, 0.0)
			if hour > 13.0 and sc.bell_ready:
				sc.ring_bell(sa_dummy_bell())
		out.weeks = day
		if not report.is_open:
			break
		if report.report.get("final", false):
			out.fired = bool(report.report.get("fired", false))
			break
		report.finish()
		await _wait(0.5)
		game.busy = false
		sa_answer(cards, 0.0)
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




# ---- owner bot body ------------------------------------------------------------------------------------------------
const OW_POLICIES := {
	"smart":
	{
		"welcome": 1,
		"backup": 0,
		"queue": 0,
		"marketing": 2,
		"peer_invite": 0,
		"mentor_offer": 1,
		"desktop": 1,
		"prospect": 0,
		"license": 0,
		"rack": 0,
		"migration": 1,
		"email24": 0,
		"raise": 0,
		"bid": 0,
		"poach": 0,
		"peer1": 2,
		"peer2": 0,
		"peer3": 0,
		"peer4": 1,
		"rn_invite": 1,
		"rn_rmm": 1,
		"rn_psa": 1,
		"rn_hw": 1,
		"stack_psa": 0,
		"stack_rmm": 0,
		"stack_hw": 0,
		"vic_plan": 1,
		"draw": 0,
		"temp_seats": 1,  # R38: the honest answer of every temptation (the shortcut is option 0), as in owner_balance.gd
		"temp_reboot": 1,
		"temp_launder": 1,
		"temp_review": 1,
		"temp_restore": 1,
		"temp_price": 1,
		"temp_2fa": 1,
		"temp_quest": 1,
		"jen_phones": 0,  # X11: the free answers (overflow rings the techs, three questions, a cap on hand-offs, write it down)
		"jen_intake": 0,
		"jen_wall": 0,
		"michael_catch": 1,
		"michael_teach": 1,
		"michael_offer": 0,
	},
	"cheap":
	{
		"welcome": 0,
		"backup": 1,
		"queue": 2,
		"marketing": 0,
		"peer_invite": 1,
		"mentor_offer": 1,
		"desktop": 0,
		"prospect": 2,
		"license": 1,
		"rack": 1,
		"migration": 0,
		"email24": 1,
		"raise": 1,
		"bid": 0,
		"poach": 1,
		"peer1": 2,
		"peer2": 1,
		"peer3": 1,
		"peer4": 1,
		"stack_psa": 1,
		"stack_rmm": 1,
		"stack_hw": 2,
		"vic_plan": 2,
		"draw": 1,
	},
	"greedy":
	{
		"welcome": 2,
		"backup": 1,
		"queue": 2,
		"marketing": 3,
		"peer_invite": 1,
		"mentor_offer": 1,
		"desktop": 2,
		"prospect": 1,
		"license": 1,
		"rack": 2,
		"migration": 0,
		"email24": 2,
		"raise": 1,
		"bid": 1,
		"poach": 1,
		"peer1": 2,
		"peer2": 1,
		"peer3": 1,
		"peer4": 1,
		"stack_psa": 1,
		"stack_rmm": 1,
		"stack_hw": 2,
		"vic_plan": 2,
		"draw": 2,
	},
}


# R38 / P5: the shortcut owner is the smart one who takes every temptation (option 0) and matches the flat price
const OW_SHORTCUTS := {"temp_seats": 0, "temp_reboot": 0, "temp_launder": 0, "temp_review": 0, "temp_restore": 0, "temp_price": 0, "temp_2fa": 0, "temp_quest": 0, "rival_flat": 2}
# R38: the "takeover" owner is the smart one who lets the week 7 client go with an exit chat, takes them back in week 11 with a
# takeover assessment and walks the site (so a bot run exercises the takeover visit); week 19 he assesses before he signs
const OW_TAKEOVER := {"rival_defect": 2, "rival_takeover": 0, "rival_badday": 1}
const OW_CAREFUL := ["careful", "shortcut", "takeover"]
const OW_TRIP_CASH := 3000  # Q6d: the careful bot sends someone to Rodent Nation only with at least this much in the bank


func ow_answer(cards: Node, ids: Dictionary) -> void:
	var n := 0
	while cards.is_open and n < 20:
		var pick := 0
		if cards.options.size() > 1:
			for id in ids:
				if cards.text.contains(str(ids[id])) and str(ids[id]).length() > 8:
					pick = mini(int(policy.get(id, 0)), cards.options.size() - 1)
					if id == "rn_invite" and strategy in OW_CAREFUL and root.get_node("Owner").cash < OW_TRIP_CASH:
						pick = 2  # Q6d: STAY HOME: a trip is not worth it out of a thin bank
		if strategy in OW_CAREFUL and cards.text.begins_with("We drew $") and cards.options.size() > 1:
			pick = 1  # Q6d: the bank is thin and the draw is a choice: a careful owner skips the draw (the bot only cut it to SMALL)
		if strategy in OW_CAREFUL and cards.options.size() == 3 and cards.text.contains("will only talk to"):
			pick = 2  # R36: the lopsided crew: pair the techs (falls back to an open option without the cash)
		if strategy in OW_CAREFUL and cards.options.size() == 3 and cards.text.contains("non-solicit line"):
			pick = 1  # R36: a client wants to follow a tech out: go and see them
		# R38: the takeover visit's own cards (the owner meeting, a finding): ask about the backups; take the job, else sell the
		# project, else patch it (the lazy owner makes a note)
		var opt_ids := []
		for entry in cards.options:
			opt_ids.append(str(entry.get("id", "")))
		if opt_ids.has("past") and opt_ids.has("list"):
			pick = opt_ids.find("past")
		elif opt_ids.has("note") and opt_ids.has("quick"):
			pick = opt_ids.find("note")
			if strategy != "lazy":
				for want in ["job", "project", "quick"]:
					var at: int = opt_ids.find(want)
					if at >= 0 and bool(cards.options[at].get("enabled", true)):
						pick = at
						break
			ow_findings += 1
			ow_jobs += 1 if opt_ids[pick] == "job" else 0
		if not bool(cards.options[pick].get("enabled", true)):  # greyed out (cash, or the partner vetoes): take an open option
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					pick = i
					break
		if OS.get_environment("BOT_TRACE") != "":  # dev: BOT_TRACE=1 prints every card, the pick and the cash before it
			var shown: String = cards.text.substr(0, 70).replace("\n", " ")
			print("TRACE card cash %d: %s -> %d (%s)" % [root.get_node("Owner").cash, shown, pick, str(cards.options[pick].get("text", cards.options[pick])).substr(0, 60)])
		_note_card(cards, pick)
		cards.pick(pick)
		n += 1
		var pb := root.get_node("Playbook")
		var guard := 0
		while pb.is_active() and guard < 12:  # a taken takeover job: the best unlocked choice of every step
			guard += 1
			var choices: Array = pb.current_step().choices
			var best := -1
			for i in choices.size():
				if pb.lock_reason(choices[i]) == "" and (best < 0 or int(choices[i].pts) > int(choices[best].pts)):
					best = i
			if best < 0:
				break
			pb.choose(best)


var ow_visits := 0  # takeover visits walked this run
var ow_findings := 0  # findings answered on them
var ow_jobs := 0  # takeover Playbook jobs finished


# R38: the takeover visit, walked the way a careful owner would: the meeting, then every object, then home
func ow_takeover_walk(ids: Dictionary) -> void:
	var on := root.get_node("Onsite")
	var cards := root.get_node("Cards")
	if not on.active or str(on.visit_kind) != "takeover":
		return
	ow_visits += 1
	ow_answer(cards, ids)
	on.interact("owner")
	ow_answer(cards, ids)
	for obj in ["server", "cabinet", "pc", "vip", "printer", "exam"]:
		on.inspect(obj)
		ow_answer(cards, ids)
	on._go_home(false)
	ow_answer(cards, ids)



# ---- sales (ported from tests/sales_balance.gd: careful / lazy / pushy) -------------------------------------------
func _sales_row(seed_n: int) -> Dictionary:
	if strategy == "chaotic":
		strategy = "pushy"
	var r: Dictionary = await sa_run(seed_n)
	strategy = "chaotic" if strategy == "pushy" else strategy
	var verdict := str(r.verdict)
	var cls := "mid"
	if bool(r.fired) or verdict.contains("let_go") or verdict == "leave":
		cls = "bad"
	elif verdict.contains("director"):
		cls = "good"
	r["ending"] = verdict
	r["cls"] = cls
	r["score"] = (int(r.q2) + int(r.q3)) / 2
	r["info"] = "Q2 %d%% Q3 %d%% (%s) commission $%d claw %d churn %d mood %d book $%d" % [r.q2, r.q3, r.res, r.commission, r.claw, r.churn, r.mood, r.book]
	return r


# ---- service (ported from tests/service_balance.gd) ---------------------------------------------------------------
func _service_row(seed_n: int) -> Dictionary:
	var r: Dictionary = await sv_run(seed_n)
	var offers: Array = r.get("offers", [])
	var cls := "bad"
	if not bool(r.fired):
		cls = "mid" if int(r.conf) >= 45 else "bad"
		if offers.has("ops") or offers.has("alan") or offers.has("garrison"):
			cls = "good"
	r["rep"] = r.conf
	r["score"] = r.audit
	r["cls"] = cls
	r["info"] = "TRUST A %d G %d MORALE %d DOC %d%% SLA %d%% AUDIT %d CREW %d quit %d" % [r.ta, r.tg, r.morale, r.doc, r.sla, r.audit, r.crew, r.quits]
	return r


# ---- owner (ported from tests/owner_balance.gd: careful = smart, lazy = cheap, chaotic = greedy) -----------------------
func ow_run(seed_n: int) -> Dictionary:
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var report := root.get_node("DayReport")
	var review := root.get_node("Review")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var game := root.get_node("Game")
	var ids := {}
	for key in o.CARDS:
		var card_text := str(o.CARDS[key].text)
		if card_text.begins_with("{"):
			card_text = card_text.substr(card_text.find("}") + 1)
		var cut := card_text.find("%s")
		var brace := card_text.find("{")
		if brace >= 0 and (cut < 0 or brace < cut):
			cut = brace
		ids[key] = card_text.substr(0, 40 if cut < 0 else mini(40, cut))
	load("res://scripts/player.gd").current_character = "office_alan"
	var policy_name: String = {"careful": "smart", "lazy": "cheap", "chaotic": "greedy", "shortcut": "smart", "takeover": "smart"}[strategy]
	ow_visits = 0
	ow_findings = 0
	ow_jobs = 0
	policy = OW_POLICIES[policy_name]
	if strategy == "shortcut":  # R38 / P5: smart's answers with every temptation taken
		policy = policy.duplicate()
		for key in OW_SHORTCUTS:
			policy[key] = OW_SHORTCUTS[key]
	if strategy == "takeover":
		policy = policy.duplicate()
		for key in OW_TAKEOVER:
			policy[key] = OW_TAKEOVER[key]
	c.new_game("owner")
	if coop:
		root.get_node("Players").enable_coop(true)
		root.get_node("Players").join(1, 1)  # the other owner is player 2
	var frames_total := 0
	var last := 0
	var row := {}
	var weeks := []
	var seen_cards := 0
	for day in range(1, 21):
		var frames := 0
		while not report.is_open and frames < 40000:
			await tree.process_frame
			frames += 1
			world.time_scale = ts
			ow_answer(cards, ids)
			if root.get_node("Onsite").active:
				ow_takeover_walk(ids)
		frames_total += frames
		last = day
		var wk_cards := []
		for k in range(seen_cards, card_log.size()):
			wk_cards.append(str(card_log[k].text).substr(0, 28))
		seen_cards = card_log.size()
		weeks.append({"week": day, "cash": int(o.cash), "rep": int(c.rep), "trust": int(root.get_node("Partner").trust), "value": int(o.valuation()), "clients": sales.active.size(), "cards": wk_cards})
		if OS.get_environment("BOT_TRACE") != "":
			var est: Dictionary = o.weekly_estimate()
			print("TRACE week %d cash %d rep %d" % [day, o.cash, c.rep])
			print("TRACE est week %d clients %d revenue %d payroll %d fixed %d mkt %d ebitda %d draw %d ar %d extra %d" % [day, sales.active.size(), est.revenue, est.payroll, est.fixed, est.marketing, est.ebitda, est.draw, o.ar_total(), o.income_extra])
		if report.report.get("final", false):
			break
		report.finish()
		await _wait(0.7)
		game.busy = false
	var fired := bool(report.report.get("fired", false))
	var rep: int = c.rep
	row = {"rep": rep, "score": o.valuation(), "fired": fired, "cash": o.cash, "week": last, "weeks": weeks}
	report.finish()
	await _wait(0.4)
	var offers_ids := []
	for of in review.offers:
		offers_ids.append(str(of.id))
	row["ending"] = "FIRED" if fired else ("sell" if offers_ids.has("sell") else "stay")
	row["cls"] = "bad" if (fired or rep < 45) else ("good" if rep >= 60 and o.goal_met() else "mid")
	row["info"] = "week %d cash $%d clients %d mood %d trust %d draw $%d goal %s value $%d (%.1fx)" % [last, o.cash, sales.active.size(), int(sales.average()), root.get_node("Partner").trust, o.draw_paid, str(o.goal_met()), o.valuation(), o.multiple()]
	# P5: the newer owner content (temptations, takeover, the second cast's cards, by-name requests)
	var bn: Dictionary = o.flags.get("bn", {})
	var cast_seen := 0
	var takeovers := 0
	for key in o.flags:
		if str(key).begins_with("card_jen_") or str(key).begins_with("card_michael_"):
			cast_seen += 1
		if str(key).begins_with("tk_"):
			takeovers += 1
	var inherit_open := 0
	for key in o.inherit:
		inherit_open += 1 if int(o.inherit[key]) > 0 else 0
	row["folder"] = o.skel.size()
	row["consc"] = int(o.consc)
	row["cast_cards"] = cast_seen
	row["takeovers"] = takeovers
	row["tk_visits"] = ow_visits
	row["tk_findings"] = ow_findings
	row["tk_jobs"] = ow_jobs
	row["info"] += " | folder %d consc %d habits %d takeovers %d (still risky %d) cast cards %d fans %d followed %d incidents %d | takeover visits %d findings %d jobs %d" % [o.skel.size(), int(o.consc), o.habits.size(), takeovers, inherit_open, cast_seen, (bn.get("fav", {}) as Dictionary).size(), int(bn.get("followed", 0)), int(o.incidents), ow_visits, ow_findings, ow_jobs]
	if not fired:
		_cleanup_review(review, game, 0)
	return row
