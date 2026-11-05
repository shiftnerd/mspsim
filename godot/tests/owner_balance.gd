extends SceneTree
# gdlint:disable=max-line-length
# Dev tool (not a test): plays the owner campaign in natural time with one fixed strategy.
# ends. One strategy per process:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/owner_balance.gd -- smart [alan|garrison]

const POLICIES := {
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
		"stack_psa": 0,
		"stack_rmm": 0,
		"stack_hw": 0,
		"vic_plan": 1,
		"draw": 0,
		"bec_scare": 0,
		"bec_marge": 0,
		"pm_ransom": 0,
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
		"bec_scare": 3,
		"bec_marge": 1,
		"pm_ransom": 2,
		"pm_rack": 2,
		"pm_email": 2,
		"pm_bec": 2,
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
		"bec_scare": 3,
		"bec_marge": 1,
		"pm_ransom": 2,
		"pm_rack": 2,
		"pm_email": 2,
		"pm_bec": 2,
	},
}

var Habits: Script = load("res://scripts/habits.gd")
const HONEST_ORDER := ["H1", "H7", "H2", "H6", "H12", "H3", "H4", "H5", "H13", "H11", "H10", "H9", "H14", "H8"]

var policy: Dictionary = {}


# the honest owner: one new habit a week while the bank can take it, and every habit redone before it goes stale
func _honest_week(day: int) -> void:
	var o := root.get_node("Owner")
	for id in HONEST_ORDER:
		var st: String = Habits.state(id)
		var every := int(Habits.HABITS[id].every)
		var due: bool = st == Habits.STALE or st == Habits.LAPSED or (st == Habits.ADOPTED and every > 0 and Habits.age(id) >= every - 1)
		if st != Habits.NONE and due and (Habits.DOABLE.has(id) or st != Habits.ADOPTED) and o.cash > 1500:
			Habits.act(id)
	if o.cash < 3000:
		return
	for id in HONEST_ORDER:
		if Habits.state(id) == Habits.NONE and (id != "H8" or o.cash > 5000):
			Habits.act(id)
			return
	# every client mapped, every site done
	if Habits.mapped_count() < root.get_node("Sales").active.size():
		Habits.act("H11")
	elif day > 0:
		Habits.act("H14")


func _answer(cards: Node, ids: Dictionary) -> void:
	var n := 0
	while cards.is_open and n < 20:
		var pick := 0
		if cards.options.size() > 1:
			for id in ids:
				if cards.text.contains(str(ids[id])) and str(ids[id]).length() > 8:
					pick = mini(int(policy.get(id, 0)), cards.options.size() - 1)
		if not bool(cards.options[pick].get("enabled", true)):  # greyed out (cash, or the partner vetoes): take an open option
			for i in cards.options.size():
				if bool(cards.options[i].get("enabled", true)):
					pick = i
					break
		cards.pick(pick)
		n += 1


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var o := root.get_node("Owner")
	var cards := root.get_node("Cards")
	var report := root.get_node("DayReport")
	var sales := root.get_node("Sales")
	var ids := {}
	for key in o.CARDS:
		var card_text := str(o.CARDS[key].text)
		if card_text.begins_with("{"):  # a name token opens the text ("{me}, backup jobs..."): match what follows it
			card_text = card_text.substr(card_text.find("}") + 1)
		var cut := card_text.find("%s")  # templated cards (the named prospect) match up to the name
		var brace := card_text.find("{")  # name tokens ({partner}) are filled in when the card opens
		if brace >= 0 and (cut < 0 or brace < cut):
			cut = brace
		ids[key] = card_text.substr(0, 40 if cut < 0 else mini(40, cut))
	c.save_prefix = (
		"user://bal_%s_%s_"
		% [OS.get_environment("SEED"), (
			"-".join(OS.get_cmdline_user_args())
			if not OS.get_cmdline_user_args().is_empty()
			else "all"
		)]
	)
	root.get_node("Game").title_mode = false
	if OS.get_environment("NOPROJ") != "":
		root.get_node("Projects").enabled = false  # A/B: the campaign without projects and services
	var wanted := OS.get_cmdline_user_args()
	# X4: play as `alan` or `garrison` (default alan); everything else names a strategy
	var as_who := "alan"
	for arg in wanted.duplicate():
		if arg in ["alan", "garrison"]:
			as_who = arg
			wanted.erase(arg)
	load("res://scripts/player.gd").current_character = "office_alan" if as_who == "alan" else "casual_garrison"
	for policy_name in POLICIES.keys() + ["honest"]:  # R38: honest = smart's answers plus the good habits
		if not wanted.is_empty() and not wanted.has(policy_name):
			continue
		policy = POLICIES["smart" if policy_name == "honest" else policy_name]
		if OS.get_environment("SEED") != "":  # R38: the same seed for the same strategy (global randf too)
			var run_seed := int(OS.get_environment("SEED"))
			root.get_node("Difficulty").seed_run(run_seed)
			seed(run_seed)
		c.new_game("owner")
		var last := 0
		var frames_total := 0
		for day in range(1, 21):
			if policy_name == "honest":
				_honest_week(day)
			var frames := 0
			while not report.is_open and frames < 40000:
				await process_frame
				frames += 1
				_answer(cards, ids)
			frames_total += frames
			if frames >= 40000:
				print("  STUCK w%d cards=%s outing=%s ts=%s clock=%s awaiting=%s txt=%s" % [day, str(cards.is_open), str(root.get_node("Outings").busy()), str(root.get_node("World").time_scale), str(root.get_node("World").clock), str(c._awaiting), str(cards.text).substr(0, 60)])
			last = day
			if OS.get_environment("WEEKLY") != "" and not o.history.is_empty():
				var hh: Dictionary = o.history[o.history.size() - 1]
				print("  w%d cash %d rep %d trust %d ebitda %d clients %d mood %d oml %d val %d" % [day, o.cash, c.rep, root.get_node("Partner").trust, int(hh.get("ebitda", 0)), sales.active.size(), int(sales.average()), o.oml(), o.valuation()])
			if report.report.get("final", false):
				break
			report.finish()
			await create_timer(0.7).timeout
			root.get_node("Game").busy = false
		var line := (
			"%s as %s: week %d cash $%d clients %d mood %d rep %d trust %d draw $%d goal %s"
			% [policy_name, c.player_as, last, o.cash, sales.active.size(), int(sales.average()), c.rep, root.get_node("Partner").trust, o.draw_paid, str(o.goal_met())]
		)
		print(
			line,
			(
				" value $%d (%.1fx) fired=%s frames=%d standard=%d"
				% [
					o.valuation(),
					o.multiple(),
					str(report.report.get("fired", false)),
					frames_total,
					Habits.standard()
				]
			)
		)
	quit()
