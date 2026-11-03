extends SceneTree
# Dev tool (not a test): plays the owner campaign in natural time with one fixed strategy.
# ends. One strategy per process:
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/owner_balance.gd -- smart

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
	},
}

var policy: Dictionary = {}


func _answer(cards: Node, ids: Dictionary) -> void:
	var n := 0
	while cards.is_open and n < 20:
		var pick := 0
		if cards.options.size() > 1:
			for id in ids:
				if cards.text.begins_with(str(ids[id])):
					pick = mini(int(policy.get(id, 0)), cards.options.size() - 1)
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
		var cut := card_text.find("%s")  # templated cards (the named prospect) match up to the name
		ids[key] = card_text.substr(0, 40 if cut < 0 else mini(40, cut))
	c.save_prefix = (
		"user://bal_%s_"
		% (
			"-".join(OS.get_cmdline_user_args())
			if not OS.get_cmdline_user_args().is_empty()
			else "all"
		)
	)
	root.get_node("Game").title_mode = false
	if OS.get_environment("NOPROJ") != "":
		root.get_node("Projects").enabled = false  # A/B: the campaign without projects and services
	var wanted := OS.get_cmdline_user_args()
	for policy_name in POLICIES:
		if not wanted.is_empty() and not wanted.has(policy_name):
			continue
		policy = POLICIES[policy_name]
		c.new_game("owner")
		var last := 0
		var frames_total := 0
		for day in range(1, 21):
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
				print("  w%d cash %d rep %d ebitda %d clients %d oml %d val %d" % [day, o.cash, c.rep, int(hh.get("ebitda", 0)), sales.active.size(), o.oml(), o.valuation()])
			if report.report.get("final", false):
				break
			report.finish()
			await create_timer(0.7).timeout
			root.get_node("Game").busy = false
		var line := (
			"%s: week %d cash $%d clients %d mood %d rep %d"
			% [policy_name, last, o.cash, sales.active.size(), int(sales.average()), c.rep]
		)
		print(
			line,
			(
				" value $%d (%.1fx) fired=%s frames=%d"
				% [
					o.valuation(),
					o.multiple(),
					str(report.report.get("fired", false)),
					frames_total
				]
			)
		)
	quit()
