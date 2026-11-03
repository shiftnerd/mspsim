extends SceneTree
# X7: the point-buy character build (Build, BuildPanel). Costs, the budget per tier, the caps and guards, presets for every
# path and tier, quirk points and effects, the owner bias floors and caps, the flat default (= today's behaviour: old
# saves, direct new_game, Free Play), saving, and what a build does on day 1 (starting XP, perks, owner edges, energy).
# The 20-day story at the build extremes is `tests/storyline.gd -- --build=zero|worst|ps4|net4|people4|scripter`.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/build.gd

var failures := 0
var player_script: GDScript


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _clear(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 30:
		cards.pick(cards.options.size() - 1)
		n += 1


func _init() -> void:
	await process_frame
	var b := root.get_node("Build")
	var c := root.get_node("Campaign")
	var sk := root.get_node("Skills")
	var sh := root.get_node("Shift")
	var o := root.get_node("Owner")
	var partner := root.get_node("Partner")
	var diff := root.get_node("Difficulty")
	var cards := root.get_node("Cards")
	var career := root.get_node("Career")
	var growth := root.get_node("Growth")
	player_script = load("res://scripts/player.gd")
	c.save_prefix = "user://test_build_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false

	# ---- costs and budgets
	_check(b.COST == [0, 1, 2, 4, 7, 11], "cumulative costs 1 / 2 / 4 / 7 / 11")
	_check(b.budget("easy") == 15 and b.budget("normal") == 12 and b.budget("hard") == 9, "budget 15 easy, 12 normal, 9 hard")
	var t: Dictionary = b.new_build("normal")
	_check(b.cost_of(t, "tech", "") == 0 and b.points_left(t, "tech", "") == 12, "a new build has 12 points to spend")
	_check(b.try_set(t, "powershell", 3, "tech", "") and b.cost_of(t, "tech", "") == 4 and t.spent == 4, "level 3 costs 4 points")
	_check(b.try_set(t, "networking", 4, "tech", "") and b.cost_of(t, "tech", "") == 11, "level 4 costs 7 more")
	_check(not b.try_set(t, "servers", 4, "tech", ""), "only one stat can be at 4")
	_check(not b.try_set(t, "servers", 2, "tech", "") and b.points_left(t, "tech", "") == 1, "a purchase over budget is refused (1 point left)")
	_check(b.try_set(t, "servers", 1, "tech", "") and b.points_left(t, "tech", "") == 0, "spending to exactly 0 is fine")
	_check(not b.try_set(t, "security", 5, "tech", "") and not b.try_set(t, "security", 1, "tech", ""), "max 4 at creation; nothing left to spend")
	_check(b.try_set(t, "networking", 0, "tech", "") and b.points_left(t, "tech", "") == 7, "lowering refunds the points")
	var hard: Dictionary = b.new_build("hard")
	b.try_set(hard, "powershell", 4, "tech", "")
	_check(b.points_left(hard, "tech", "") == 2 and not b.try_set(hard, "security", 3, "tech", ""), "hard: 9 points, level 4 leaves 2")
	var easy: Dictionary = b.new_build("easy")
	for stat in ["powershell", "networking", "servers", "security"]:
		b.try_set(easy, stat, 3, "tech", "")
	_check(b.cost_of(easy, "tech", "") == 12 and b.points_left(easy, "tech", "") == 3, "easy: four stats at 3 cost 12, 3 points left")

	# ---- total effect cap and soft warnings
	var rich: Dictionary = b.new_build("easy")
	rich.quirks = ["caffeine", "slow", "butter"]  # +6 points, but only two negative quirks are allowed
	_check(not b.quirks_ok(rich.quirks, "tech"), "three negative quirks are refused")
	rich.quirks = ["caffeine", "slow"]
	_check(b.points_left(rich, "tech", "") == 19, "two quirks add 4 points (19 on easy)")
	for stat in b.stats_of("tech"):
		for lv in [1, 2, 3]:
			b.try_set(rich, stat, lv, "tech", "")
	_check(b.total_levels(rich, "tech", "") <= b.MAX_TOTAL, "the total of levels stays at or under %d (%d)" % [b.MAX_TOTAL, b.total_levels(rich, "tech", "")])
	_check(b.validate(rich, "tech", "").is_empty(), "a maxed-out quirky easy build is still a valid build")
	var warn: Dictionary = b.new_build("normal")
	_check(not b.warnings(warn, "tech", "").is_empty(), "an empty build warns (few levels, no customer / security)")

	# ---- quirks
	_check(b.quirks_ok(["slow"], "tech") and not b.quirks_ok(["slow", "quick"], "tech"), "SLOW STARTER and QUICK STUDY exclude each other")
	_check(not b.quirks_ok(["stubborn"], "tech") and b.quirks_ok(["stubborn"], "owner"), "quirks belong to their paths")
	_check(b.quirks_ok(["caffeine", "butter", "early"], "tech") and not b.quirks_ok(["early", "quick"], "tech"), "two negative quirks and one positive are allowed, two positives are not")
	var q: Dictionary = b.new_build("normal")
	q.quirks = ["caffeine"]
	_check(b.points_left(q, "tech", "") == 14, "CAFFEINE DEPENDENT gives +2 points")
	q.quirks = ["early"]
	_check(b.points_left(q, "tech", "") == 10, "EARLY BIRD costs 2 points")
	for key in b.QUIRKS:
		var row: Dictionary = b.QUIRKS[key]
		var text := (str(row.name) + " " + str(row.text)).to_lower()
		_check(not (text.contains("family") or text.contains("health") or text.contains("sick") or text.contains("kid")), "quirk %s is kind (no family or health)" % key)

	# ---- presets: every path, every tier
	for path_info in [["tech", ""], ["owner", "Alan"], ["owner", "Garrison"], ["service", "Dan"], ["sales", "Vic"]]:
		var path: String = path_info[0]
		var who: String = path_info[1]
		var list: Array = b.presets_for(path, who)
		_check(list.size() >= 3, "%s %s has %d presets" % [path, who, list.size()])
		for p in list:
			for tier in ["easy", "normal", "hard"]:
				var pb: Dictionary = b.apply_preset(path, who, tier, str(p.id))
				var errs: Array = b.validate(pb, path, who)
				var left: int = b.points_left(pb, path, who)
				_check(errs.is_empty() and left >= 0 and left <= 3, "%s / %s / %s: valid, %d points left" % [path, str(p.id), tier, left])
	_check(b.presets_for("tech", "").map(func(p): return p.name) == ["GENERALIST", "SCRIPTER", "NETWORK NERD", "PEOPLE PERSON"], "the four tech presets")
	var sc: Dictionary = b.apply_preset("tech", "", "normal", "scripter")
	_check(b.level_of(sc, "powershell", "") == 4 and b.level_of(sc, "people", "") <= 1, "SCRIPTER is PowerShell 4, low CUSTOMER")
	_check(not b.selectable("service") and not b.selectable("sales") and b.selectable("tech") and b.selectable("owner"), "service and sales are data rows, not selectable yet")

	# ---- bias floors and caps (owner, service, sales)
	var alan: Dictionary = b.new_build("normal")
	_check(b.level_of(alan, "technical", "Alan") == 2 and b.cost_of(alan, "owner", "Alan") == 0, "Alan: TECHNICAL starts at 2 for free")
	_check(not b.try_set(alan, "technical", 1, "owner", "Alan"), "Alan cannot go under his floor")
	_check(b.try_set(alan, "technical", 3, "owner", "Alan") and b.cost_of(alan, "owner", "Alan") == 2, "raising above the floor costs the difference (2)")
	_check(b.try_set(alan, "sales", 2, "owner", "Alan") and not b.try_set(alan, "sales", 3, "owner", "Alan"), "Alan: SALES is capped at 2")
	_check(not b.try_set(alan, "culture", 3, "owner", "Alan"), "Alan: CULTURE is capped at 2")
	var gar: Dictionary = b.new_build("normal")
	_check(b.level_of(gar, "sales", "Garrison") == 2 and b.level_of(gar, "culture", "Garrison") == 2 and b.level_of(gar, "technical", "Garrison") == 0, "Garrison: SALES and CULTURE start at 2")
	_check(not b.try_set(gar, "technical", 3, "owner", "Garrison") and b.try_set(gar, "technical", 2, "owner", "Garrison"), "Garrison: TECHNICAL is capped at 2")
	var dan: Dictionary = b.new_build("normal")
	_check(b.level_of(dan, "process", "Dan") == 2 and b.level_of(dan, "dispatch", "Dan") == 1 and not b.try_set(dan, "people", 3, "service", "Dan"), "Dan: PROCESS 2 and DISPATCH 1 free, PEOPLE capped at 2")
	_check(b.BIAS.Dan.skills.networking == 3, "Dan's free NETWORKING 3 is kept as data for the service campaign")
	var vic: Dictionary = b.new_build("normal")
	_check(b.level_of(vic, "pitch", "Vic") == 2, "Vic: PITCH starts at 2")

	# ---- the flat default is today's behaviour
	var flat: Dictionary = b.from_dict({})
	_check(b.is_flat(flat) and flat.preset == "flat" and flat.quirks.is_empty() and flat.stats.is_empty(), "from_dict({}) is the flat build")
	_check(b.validate(flat, "tech", "").is_empty() and b.cost_of(flat, "tech", "") == 0, "the flat build is valid and free")
	player_script.current_character = "office_adult"
	c.new_game("tech")
	_check(c.build.is_empty() or b.is_flat(c.build), "a direct new_game gets the flat build")
	var zero_xp := true
	for key in sk.NAMES:
		if int(sk.xp[key]) != 0:
			zero_xp = false
	_check(zero_xp and sk.ps_level == 0, "flat: every skill at 0, PowerShell 0")
	_check(sh.energy == 80.0 and sk.need(0) == 15 and sk.need(4) == 200, "flat: energy 80, the XP table is unchanged")
	_check(b.fx("drain") == 0.0 and b.xp_mult() == 1.0 and b.tech_levels().is_empty(), "flat: no quirk effects, no starting levels")
	_check(not sk.can_script() and not sk.backup_watch() and sk.sla_pace() == 1.0, "flat: no perks on day 1")
	c.save()
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	cfg.erase_section_key("campaign", "build")
	cfg.save(c.save_path("tech"))
	player_script.current_character = "site_alan"
	_check(c.continue_game("tech") and b.is_flat(c.build), "an old save without a build loads flat")
	DirAccess.remove_absolute(c.save_path("tech"))
	b.pending = {}
	c.new_game("free")
	_check(b.is_flat(c.build) and not c.active, "Free Play starts flat")
	b.pending = b.apply_preset("tech", "", "normal", "scripter")
	c.new_game("free")
	_check(b.is_flat(c.build) and sk.ps_level == 0, "Free Play ignores a chosen build")
	b.pending = b.max_build("tech")
	c.new_game("free")
	_check(c.build.preset == "max" and sk.ps_level == 5 and sk.level("servers") == 5, "Free Play's MAX preset sets every skill to 5 (filming)")

	# ---- a tech build on day 1: starting XP from the level, live perks
	diff.set_tier("normal")
	var two: Dictionary = b.new_build("normal")
	two.preset = "custom"
	b.try_set(two, "powershell", 4, "tech", "")
	b.try_set(two, "security", 3, "tech", "")
	two = b.finalize(two, "tech", "")
	_check(two.spent == 11 and b.validate(two, "tech", "").is_empty(), "PowerShell 4 + Security 3 = 11 points, valid")
	b.pending = two
	diff.seed_run(0x4F2A9C)
	c.new_game("tech")
	_check(c.build.preset == "custom" and c.build.seed == 0x4F2A9C, "the build is kept on the campaign with the run seed")
	_check(sk.ps_level == 4 and sk.level("security") == 3 and sk.xp.security == 80, "starting XP is XP_AT[level - 1] (security 80)")
	_check(sk.can_script() and sk.script_all(), "PowerShell 4: both scripts are live on day 1")
	_check(sk.backup_watch(), "Security 3: backup watch from day 1")
	_check(absf(sk.fix_secs() - 2.0 * sh.slow_mult()) < 0.01, "PowerShell 4 fixes take the level 4 time (2 s)")
	_check(career.value("builds") >= 1 and career.value("build.custom") >= 1, "Career counts builds used")
	var gap: Array = growth.gaps()
	_check(gap[0].skill in ["networking", "servers", "people"] and gap[0].level == 0, "Growth.gaps names a weakest skill (%s)" % str(gap[0].skill))
	var ppl: Dictionary = b.new_build("normal")
	b.try_set(ppl, "people", 4, "tech", "")
	b.try_set(ppl, "powershell", 1, "tech", "")
	b.pending = b.finalize(ppl, "tech", "")
	c.new_game("tech")
	_check(sk.sla_pace() < 1.0 and sk.sees_open_docs(), "Customer 4: SLA clocks tick slower and open docs are visible on day 1")
	_check(root.get_node("Social").value("Alan") >= 9, "Customer 4 starts the team a little friendlier (+10)")
	var weak: Dictionary = b.new_build("normal")
	for stat in ["powershell", "networking", "security", "people"]:
		b.try_set(weak, stat, 2, "tech", "")
	b.pending = b.finalize(weak, "tech", "")
	c.new_game("tech")
	_check(growth.gaps()[0].skill == "servers", "Growth.gaps names the one skill the build left at 0 (servers)")

	# ---- quirks do something
	var cq: Dictionary = b.new_build("normal")
	cq.quirks = ["caffeine", "slow"]
	cq.preset = "custom"
	b.try_set(cq, "powershell", 2, "tech", "")
	b.try_set(cq, "networking", 2, "tech", "")
	b.pending = b.finalize(cq, "tech", "")
	c.new_game("tech")
	_check(sh.energy == 65.0, "CAFFEINE DEPENDENT: start at 65 energy")
	_check(b.fx("drain") == 0.25 and sk.need(0) == 18 and sk.need(1) == 48, "extra energy drain 25%; SLOW STARTER: 15 -> 18, 40 -> 48 XP")
	_check(sk.xp.networking == sk.need(1) and sk.level("networking") == 2, "starting XP uses the scaled table, so the level holds (2)")
	sk.add_xp("servers", 20)
	_check(sk.level("servers") == 1, "SLOW STARTER: 20 XP is level 1 (needs 18)")
	var fast: Dictionary = b.new_build("normal")
	fast.quirks = ["early"]
	fast.preset = "custom"
	b.try_set(fast, "powershell", 1, "tech", "")
	b.pending = b.finalize(fast, "tech", "")
	c.new_game("tech")
	_check(sh.energy == 90.0, "EARLY BIRD: start at 90 energy")
	var clumsy: Dictionary = b.new_build("normal")
	clumsy.quirks = ["butter"]
	clumsy.preset = "custom"
	b.pending = clumsy
	c.new_game("tech")
	_check(absf(sk.fail_chance() - (0.25 + b.fx("fail"))) < 0.001 and b.fx("fail") == 0.04, "BUTTERFINGERS: remote fixes fail 4% more often")

	# ---- save round trip
	b.pending = b.apply_preset("tech", "", "normal", "scripter")
	diff.seed_run(0x1234AB)
	c.new_game("tech")
	var made: Dictionary = c.build.duplicate(true)
	c.save()
	b.pending = {}
	c.new_game("tech")
	_check(b.is_flat(c.build) and sk.ps_level == 0, "a new flat run follows")
	player_script.current_character = "office_teen"
	_check(c.continue_game("tech"), "continue loads the saved run")
	_check(c.build.preset == made.preset and c.build.stats == made.stats and c.build.quirks == made.quirks and c.build.spent == made.spent and c.build.tier == made.tier and c.build.seed == made.seed, "the build survives the save: %s" % str(c.build.stats))
	_check(sk.ps_level == 4, "and the skills came back from the save")
	var round_trip: Dictionary = b.from_dict(made)
	_check(round_trip == made, "from_dict(build) is the identity")
	DirAccess.remove_absolute(c.save_path("tech"))

	# ---- the owner campaign: edges, cash, trust
	player_script.current_character = "office_alan"
	b.pending = {}
	c.new_game("owner")
	_clear(cards)
	var flat_edges: Dictionary = o.edges_for("Alan")
	var table_ok := true
	for key in o.OWNER_EDGES.Alan:
		if flat_edges[key] != o.OWNER_EDGES.Alan[key]:
			table_ok = false
	_check(table_ok, "flat Alan: edges_for equals the OWNER_EDGES row")
	_check(o.cash == o.START_CASH and partner.trust == partner.START_TRUST, "flat owner: start cash and partner trust unchanged")
	var arch: Dictionary = b.apply_preset("owner", "Alan", "normal", "architect")
	b.pending = arch
	c.new_game("owner")
	_clear(cards)
	var e: Dictionary = o.edges_for("Alan")
	_check(c.build.preset == "architect" and b.level("technical") > 2, "Alan ARCHITECT: TECHNICAL above his free 2 (%d)" % b.level("technical"))
	_check(e.close_miss < o.OWNER_EDGES.Alan.close_miss and e.backup_check > o.OWNER_EDGES.Alan.backup_check, "ARCHITECT: fewer premature closes, backup problems noticed sooner")
	_check(o.edges_for("Garrison") == o.edges_for("Garrison") and o.edge("close_miss") == e.close_miss, "only the player's own edges move (edge() reads the build)")
	_check(o.cash > o.START_CASH or b.level("finance") == 0, "FINANCE levels add starting cash")
	player_script.current_character = "casual_garrison"
	var cl: Dictionary = b.apply_preset("owner", "Garrison", "normal", "people_first")
	b.pending = cl
	c.new_game("owner")
	_clear(cards)
	_check(b.level("culture") > 2 and partner.trust > partner.START_TRUST, "Garrison PEOPLE FIRST: CULTURE raises the starting partner trust (%d)" % partner.trust)
	_check(o.edge("morale") > o.OWNER_EDGES.Garrison.morale, "CULTURE adds crew morale")
	var stub: Dictionary = b.new_build("normal")
	stub.quirks = ["stubborn"]
	stub.preset = "custom"
	b.pending = stub
	c.new_game("owner")
	_clear(cards)
	_check(partner.trust == partner.START_TRUST - 10, "STUBBORN: partner trust -10")
	# edge limits
	var maxed: Dictionary = b.new_build("easy")
	b.try_set(maxed, "technical", 4, "owner", "Alan")
	_check(b.clamp_edge("close_miss", -1.0) == 0.01, "edge deltas are clamped (close_miss never under 1%)")

	# ---- patchable tables
	_check(b.DEFAULT_QUIRKS.size() == b.QUIRKS.size() and b.DEFAULT_PRESETS.has("tech") and b.DEFAULT_INFO.has("owner"), "the tables are patchable (DEFAULT_ copies)")

	b.pending = {}
	c.active = false
	c.mode = ""
	c.build = {}
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
