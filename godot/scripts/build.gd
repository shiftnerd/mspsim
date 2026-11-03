extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# POINT-BUY CHARACTER BUILD (roadmap X7, docs/campaign-paths.md section 13). A build is a small Dictionary
#   {version, preset, stats {stat: level}, quirks [ids], spent, tier, seed}
# chosen on the third step of the character select screen and saved with the campaign (`Campaign.build`).
# `Build.from_dict({})` is the FLAT build (every stat at its free bias floor, no quirks, nothing spent): it behaves
# exactly like the game did before point-buy, so old saves, direct `Campaign.new_game` calls in tests and Free Play
# are unchanged. Every stat is a 0-5 level read through `Build.level(stat)`.
#
#   Stat sets   PATHS: tech (the five Skills), owner (TECHNICAL FINANCE SALES CULTURE CLIENTS, read through
#               Owner.edges_for), service (Dan) and sales (Vic) as data rows (not selectable yet).
#   Bias        BIAS[cast name]: free floors and creation caps that cost no points, so a cast member stays himself.
#   Budget      BUDGET by Difficulty tier (12 normal, 15 easy, 9 hard), cumulative COST 1/2/4/7/11 per level, at most 4
#               at creation and only one stat at 4, MAX_TOTAL levels in all. Quirks give or cost points.
#   Guards      validate() lists the errors that block the confirm button, warnings() the soft ones.
#   Feeding     Skills.reset (starting XP from the level), Skills.need (SLOW STARTER), Shift (energy quirks),
#               Social (CUSTOMER), Owner.edges_for / cash and Partner trust (owner stats), Career counters.
# QUIRKS, PRESETS and INFO are patchable text tables (story/strings.txt).

const VERSION := 1
const COST := [0, 1, 2, 4, 7, 11]  # cumulative points for level 0..5
const BUDGET := {"easy": 15, "normal": 12, "hard": 9}
const MAX_START := 4  # the most any stat can be at creation (5 is earned)
const MAX_TOTAL := 14  # the most levels in all, however many quirk points there are
const MAX_NEG := 2  # quirks that give points
const MAX_POS := 1  # quirks that cost points
const PATHS := {
	"tech": {"selectable": true, "stats": ["powershell", "networking", "servers", "security", "people"]},
	"owner": {"selectable": true, "stats": ["technical", "finance", "sales", "culture", "clients"]},
	"service": {"selectable": true, "stats": ["dispatch", "process", "people", "escalation", "relations"]},
	"sales": {"selectable": false, "stats": ["pitch", "discovery", "negotiation", "relationships", "honesty"]},
}
# free floors and creation caps per cast member; "skills" are floors on the five tech Skills the service campaign applies itself
const BIAS := {
	"Alan": {"floor": {"technical": 2}, "cap": {"sales": 2, "culture": 2}},
	"Garrison": {"floor": {"sales": 2, "culture": 2}, "cap": {"technical": 2}},
	"Dan": {"floor": {"process": 2, "dispatch": 1}, "cap": {"people": 2, "relations": 2}, "skills": {"networking": 3, "servers": 1}},
	"Vic": {"floor": {"pitch": 2}, "cap": {}},
}
# owner stat -> what one level above the free floor adds to Owner.edges_for (see the key list in owner.gd)
const OWNER_FX := {
	"technical": {"close_miss": -0.006, "rdp": -0.04, "stack_risk": -0.03, "issues": -0.01, "backup_check": 0.03},
	"finance": {"fee_accept": 0.02},
	"sales": {"marketing": 0.08},
	"culture": {"morale": 1.0, "outing_relief": 0.1},
	"clients": {"qbr": 0.03, "new_mood": 1.0, "poach": -0.004},
}
const CASH_PER_FINANCE := 250  # starting cash per FINANCE level above the floor
const TRUST_PER_CULTURE := 3  # starting partner trust per CULTURE level above the floor
const SOCIAL_PER_PEOPLE := 2.5  # starting opinion with the team per CUSTOMER level
const EDGE_LIMITS := {"close_miss": [0.01, 0.2], "rdp": [0.4, 1.6], "stack_risk": [0.5, 1.6], "issues": [0.8, 1.2], "backup_check": [0.0, 0.6], "marketing": [0.4, 1.8], "fee_accept": [-0.2, 0.2], "qbr": [-0.2, 0.25], "new_mood": [0.0, 10.0], "poach": [-0.05, 0.1], "morale": [-5.0, 8.0], "outing_relief": [0.5, 2.0]}

# quirks: pts > 0 gives points (a negative quirk), pts < 0 costs points (a positive one). fx keys: energy (start energy), drain
# (extra energy drain per day, a fraction), rest (extra morning rest), xp (extra XP needed, a fraction), fail (extra remote fix failure), trust
# (starting partner trust). "excl" lists quirks it cannot be taken with. Never tied to family or health.
const DEFAULT_QUIRKS := {
	"caffeine": {"name": "CAFFEINE DEPENDENT", "pts": 2, "paths": ["tech"], "fx": {"energy": -15.0, "drain": 0.25}, "text": "START AT 65 ENERGY AND TIRE A QUARTER FASTER. THE COFFEE MACHINE IS YOUR FRIEND."},
	"slow": {"name": "SLOW STARTER", "pts": 2, "paths": ["tech"], "excl": ["quick"], "fx": {"xp": 0.2}, "text": "EVERY SKILL NEEDS 20 PERCENT MORE EXPERIENCE TO LEVEL UP."},
	"butter": {"name": "BUTTERFINGERS", "pts": 2, "paths": ["tech"], "fx": {"fail": 0.04}, "text": "REMOTE FIXES FAIL 4 PERCENT MORE OFTEN. CHECK YOUR TYPING TWICE."},
	"quick": {"name": "QUICK STUDY", "pts": -2, "paths": ["tech"], "excl": ["slow"], "fx": {"xp": -0.15}, "text": "EVERY SKILL NEEDS 15 PERCENT LESS EXPERIENCE TO LEVEL UP."},
	"early": {"name": "EARLY BIRD", "pts": -2, "paths": ["tech"], "fx": {"energy": 10.0, "rest": 4.0}, "text": "START AT 90 ENERGY AND WAKE UP A LITTLE MORE RESTED EVERY MORNING."},
	"stubborn": {"name": "STUBBORN", "pts": 2, "paths": ["owner"], "fx": {"trust": -10.0}, "text": "YOUR PARTNER STARTS WITH 10 LESS TRUST. YOU DO NOT BACK DOWN."},
	"listener": {"name": "GOOD LISTENER", "pts": -2, "paths": ["owner"], "fx": {"trust": 10.0}, "text": "YOUR PARTNER STARTS WITH 10 MORE TRUST. YOU HEAR THEM OUT."},
	"overpromise": {"name": "OVER-PROMISER", "pts": 2, "paths": ["sales"], "fx": {}, "text": "YOU SAY YES TO EVERYTHING. DELIVERY HAS TO CATCH UP."},
	"quiet": {"name": "QUIET TYPE", "pts": 2, "paths": ["service"], "fx": {"oto": -0.15}, "text": "YOU PREFER A CLOSED DOOR AND A SHORT MEETING. ONE ON ONES GAIN 15 PERCENT LESS."},
}
var QUIRKS: Dictionary = DEFAULT_QUIRKS.duplicate(true)
# what each stat does, one line for the build screen
const DEFAULT_INFO := {
	"tech": {
		"powershell": {"name": "POWERSHELL", "text": "FASTER AND SAFER RMM FIXES. LEVEL 2 SCRIPTS A WHOLE CLIENT, LEVEL 4 EVERY CLIENT."},
		"networking": {"name": "NETWORKING", "text": "FASTER NETWORK AND PRINTER FIXES. LEVEL 2 NAMES THE PATCH PANEL PORT."},
		"servers": {"name": "SERVERS", "text": "SERVER AND WORKSTATION FIXES ARE 6 PERCENT FASTER PER LEVEL."},
		"security": {"name": "SECURITY", "text": "FASTER SECURITY FIXES. LEVEL 3 MAKES BACKUPS CHECK THEMSELVES."},
		"people": {"name": "CUSTOMER", "text": "LEVEL 2 SHOWS WHO HAS WORK OPEN. LEVEL 3 AND UP SLOWS THE SLA CLOCKS. THE TEAM LIKES YOU MORE."},
	},
	"owner": {
		"technical": {"name": "TECHNICAL", "text": "FEWER REOPENED TICKETS AND BREAK-INS. FAILING BACKUPS GET NOTICED SOONER."},
		"finance": {"name": "FINANCE", "text": "FEE RISES ARE ACCEPTED MORE OFTEN AND THE BANK STARTS FATTER."},
		"sales": {"name": "SALES", "text": "MARKETING WORKS BETTER AND VIC CLOSES MORE."},
		"culture": {"name": "CULTURE", "text": "A HAPPIER CREW, BIGGER RELIEF FROM OUTINGS AND MORE TRUST FROM YOUR PARTNER."},
		"clients": {"name": "CLIENTS", "text": "BUSINESS REVIEWS GO BETTER, NEW CLIENTS START HAPPIER, FEWER ARE POACHED."},
	},
	"service": {
		"dispatch": {"name": "DISPATCH", "text": "THE BOARD IS LESS FUZZY (LEVEL 3): EXACT SLA TIMES, FIT AND LOAD."},
		"process": {"name": "PROCESS", "text": "RUNBOOKS COST LESS TO WRITE AND THE CREW FOLLOWS THEM BETTER."},
		"people": {"name": "PEOPLE", "text": "ONE ON ONES GAIN MORE, THE CREW STAYS LONGER AND LYNK REPLIES ARE WARMER."},
		"escalation": {"name": "ESCALATION", "text": "SENDING A TICKET TO AN OWNER COSTS LESS TRUST. YOU KNOW WHEN IT SHOULD GO UP."},
		"relations": {"name": "CLIENT REL", "text": "OWNER AND CLIENT TRUST GROWS FASTER AND FALLS SLOWER."},
	},
	"sales": {
		"pitch": {"name": "PITCH", "text": "MORE LEADS BECOME MEETINGS AND MORE MEETINGS BECOME QUOTES."},
		"discovery": {"name": "DISCOVERY", "text": "YOU FIND THE REAL PROBLEM BEFORE YOU QUOTE."},
		"negotiation": {"name": "NEGOTIATION", "text": "DISCOUNT ASKS COST LESS AND DEALS CLOSE AT A BETTER PRICE."},
		"relationships": {"name": "RELATIONSHIPS", "text": "RENEWALS AND REFERRALS COME EASIER."},
		"honesty": {"name": "HONESTY", "text": "FEWER PROMISES TO KEEP AND LESS RISK OF A CLAWBACK."},
	},
}
var INFO: Dictionary = DEFAULT_INFO.duplicate(true)
# presets: steps raise a stat one level each, in order, while the budget and the guards allow it (so a preset fits every tier)
const DEFAULT_PRESETS := {
	"tech": [
		{"id": "generalist", "name": "GENERALIST", "quirks": [], "steps": ["powershell", "networking", "servers", "security", "people", "powershell", "networking", "servers", "security", "people", "powershell", "networking", "servers", "security", "people"], "text": "A BIT OF EVERYTHING. NO BAD DAYS, NO BIG WINS."},
		{"id": "scripter", "name": "SCRIPTER", "quirks": [], "steps": ["powershell", "powershell", "powershell", "powershell", "security", "servers", "people", "networking", "security", "servers", "people", "networking"], "text": "FIXES RUN FASTER AND SCRIPTS WORK ON DAY ONE. NOBODY LIKES YOU YET."},
		{"id": "network", "name": "NETWORK NERD", "quirks": [], "steps": ["networking", "networking", "networking", "networking", "servers", "security", "powershell", "people", "servers", "security", "powershell", "people"], "text": "THE CLOSET IS YOUR HAPPY PLACE. PRINTERS AND OUTAGES FEAR YOU."},
		{"id": "people", "name": "PEOPLE PERSON", "quirks": [], "steps": ["people", "people", "people", "people", "powershell", "security", "networking", "servers", "powershell", "security", "networking", "servers"], "text": "CLIENTS WAIT LONGER AND THE TEAM LIKES YOU. THE SERVERS NOT SO MUCH."},
	],
	"owner_alan": [
		{"id": "architect", "name": "ARCHITECT", "quirks": [], "steps": ["technical", "technical", "technical", "finance", "clients", "finance", "clients", "technical", "finance", "clients"], "text": "A CLEAN STACK AND QUIET SERVERS. THE BOOKS ARE ALMOST AS TIDY."},
		{"id": "cutter", "name": "COST CUTTER", "quirks": [], "steps": ["finance", "finance", "finance", "finance", "technical", "clients", "technical", "clients", "finance"], "text": "EVERY DOLLAR HAS A JOB. CLIENTS ACCEPT FEE RISES AND THE BANK STARTS FATTER."},
		{"id": "hirer", "name": "HIRER", "quirks": [], "steps": ["clients", "clients", "culture", "culture", "technical", "technical", "clients", "finance", "technical", "finance"], "text": "YOU PICK GOOD PEOPLE. CLIENTS LIKE THEM AND THE CREW STAYS."},
	],
	"owner_garrison": [
		{"id": "brand", "name": "BRAND BUILDER", "quirks": [], "steps": ["sales", "sales", "sales", "clients", "clients", "finance", "technical", "finance", "clients", "technical"], "text": "MARKETING WORKS HARD FOR YOU AND VIC CLOSES MORE."},
		{"id": "people_first", "name": "PEOPLE FIRST", "quirks": [], "steps": ["culture", "culture", "culture", "clients", "clients", "finance", "technical", "clients", "finance", "technical"], "text": "A HAPPY CREW AND A TRUSTING PARTNER. THE NUMBERS FOLLOW, MAYBE."},
		{"id": "closer", "name": "CLOSER", "quirks": [], "steps": ["clients", "clients", "clients", "finance", "finance", "sales", "sales", "technical", "finance", "clients"], "text": "REVIEWS GO WELL, FEES GO UP, NEW CLIENTS START HAPPY."},
	],
	"service": [
		{"id": "label_maker", "name": "LABEL MAKER", "quirks": [], "steps": ["process", "process", "process", "process", "escalation", "dispatch", "people", "relations"], "text": "EVERYTHING HAS A RUNBOOK AND A LABEL."},
		{"id": "coach", "name": "COACH", "quirks": [], "steps": ["people", "people", "people", "relations", "relations", "escalation", "process", "dispatch"], "text": "ONE ON ONES THAT WORK. THE BOARD LOOKS A LITTLE MESSY."},
		{"id": "firefighter", "name": "FIREFIGHTER", "quirks": [], "steps": ["dispatch", "dispatch", "escalation", "escalation", "dispatch", "process", "people", "relations"], "text": "YOU SEE THE FIRE BEFORE IT STARTS."},
		{"id": "diplomat", "name": "DIPLOMAT", "quirks": [], "steps": ["relations", "relations", "people", "people", "escalation", "process", "dispatch"], "text": "CLIENTS CALL YOU FIRST. YOUR CREW KNOWS WHY."},
	],
	"sales": [
		{"id": "hunter", "name": "HUNTER", "quirks": [], "steps": ["pitch", "pitch", "pitch", "pitch", "discovery", "negotiation", "relationships", "honesty"], "text": "NEW LEADS EVERY WEEK. RENEWALS ARE SOMEBODY ELSE'S PROBLEM."},
		{"id": "farmer", "name": "FARMER", "quirks": [], "steps": ["relationships", "relationships", "relationships", "honesty", "honesty", "discovery", "pitch", "negotiation"], "text": "RENEWALS AND REFERRALS. NOBODY EVER LEAVES."},
		{"id": "consultant", "name": "CONSULTANT", "quirks": [], "steps": ["discovery", "discovery", "discovery", "honesty", "honesty", "pitch", "relationships", "negotiation"], "text": "YOU FIND THE REAL PROBLEM AND QUOTE THE REAL FIX."},
		{"id": "smooth", "name": "SMOOTH TALKER", "quirks": [], "steps": ["negotiation", "negotiation", "pitch", "pitch", "relationships", "discovery", "honesty"], "text": "YOU CLOSE ANYTHING. KEEP THE PROMISES YOU MAKE."},
	],
}
var PRESETS: Dictionary = DEFAULT_PRESETS.duplicate(true)

var pending := {}  # the build chosen on the select screen, taken by Campaign.new_game


# ---- the flat default and (de)serialising -----------------------------------------------------------------------
func flat() -> Dictionary:
	return {"version": VERSION, "preset": "flat", "stats": {}, "quirks": [], "spent": 0, "tier": "normal", "seed": 0}


func from_dict(data: Dictionary) -> Dictionary:
	var out := flat()
	if data.is_empty():
		return out
	out["preset"] = str(data.get("preset", "flat"))
	var saved: Dictionary = data.get("stats", {})
	for key in saved:
		out.stats[str(key)] = clampi(int(saved[key]), 0, 5)
	for q in data.get("quirks", []):
		if QUIRKS.has(str(q)) and not out.quirks.has(str(q)):
			out.quirks.append(str(q))
	out["spent"] = int(data.get("spent", 0))
	out["tier"] = str(data.get("tier", "normal"))
	out["seed"] = int(data.get("seed", 0))
	return out


# the build the running campaign has (flat when none)
func cur() -> Dictionary:
	var campaign := get_node_or_null("/root/Campaign")
	if campaign == null or typeof(campaign.get("build")) != TYPE_DICTIONARY or campaign.build.is_empty():
		return flat()
	return campaign.build


func is_flat(b: Dictionary) -> bool:
	return b.get("quirks", []).is_empty() and int(b.get("spent", 0)) == 0 and str(b.get("preset", "flat")) != "max"


func take_pending(for_mode: String) -> Dictionary:
	var b: Dictionary = from_dict(pending)
	pending = {}
	if for_mode == "free" and str(b.preset) != "max":
		return flat()  # Free Play has no build screen; only the MAX preset for filming
	if is_flat(b):
		return flat()
	b["seed"] = Difficulty.run_seed
	return b


# ---- paths, stats, bias ---------------------------------------------------------------------------------------------
func path_of(for_mode: String) -> String:
	return for_mode if PATHS.has(for_mode) else "tech"  # Free Play and tests: the tech stat set


func selectable(for_mode: String) -> bool:
	return bool(PATHS.get(for_mode, {}).get("selectable", false)) and Campaign.is_selectable(for_mode)


func stats_of(path: String) -> Array:
	return PATHS.get(path, PATHS.tech).stats


func stat_name(path: String, stat: String) -> String:
	return str(INFO.get(path, {}).get(stat, {}).get("name", stat.to_upper()))


func stat_text(path: String, stat: String) -> String:
	return str(INFO.get(path, {}).get(stat, {}).get("text", ""))


func floor_of(stat: String, who: String) -> int:
	return int(BIAS.get(who, {}).get("floor", {}).get(stat, 0))


func cap_of(stat: String, who: String) -> int:
	return int(BIAS.get(who, {}).get("cap", {}).get(stat, MAX_START))


func level_of(b: Dictionary, stat: String, who: String) -> int:
	return clampi(maxi(floor_of(stat, who), int(b.get("stats", {}).get(stat, 0))), 0, 5)


# the level of a stat in the running campaign
func level(stat: String) -> int:
	return level_of(cur(), stat, Campaign.player_as)


func total_levels(b: Dictionary, path: String, who: String) -> int:
	var n := 0
	for s in stats_of(path):
		n += level_of(b, str(s), who)
	return n


# ---- budget and cost -------------------------------------------------------------------------------------------
func budget(tier: String) -> int:
	return int(BUDGET.get(tier, BUDGET.normal)) + Yeartwo.build_bonus()  # Year 2: +2 points


func quirk_points(b: Dictionary) -> int:
	var n := 0
	for q in b.get("quirks", []):
		n += int(QUIRKS.get(str(q), {}).get("pts", 0))
	return n


func cost_of(b: Dictionary, path: String, who: String) -> int:
	var n := 0
	for s in stats_of(path):
		var lv := level_of(b, str(s), who)
		var fl := floor_of(str(s), who)
		if lv > fl:
			n += int(COST[lv]) - int(COST[fl])
	return n


func points_left(b: Dictionary, path: String, who: String) -> int:
	return budget(str(b.get("tier", "normal"))) + quirk_points(b) - cost_of(b, path, who)


# ---- guards ------------------------------------------------------------------------------------------------------
func quirks_ok(list: Array, path: String) -> bool:
	var neg := 0
	var pos := 0
	for q in list:
		var row: Dictionary = QUIRKS.get(str(q), {})
		if row.is_empty() or not (path in row.paths):
			return false
		if int(row.pts) > 0:
			neg += 1
		else:
			pos += 1
		for other in row.get("excl", []):
			if list.has(other):
				return false
	return neg <= MAX_NEG and pos <= MAX_POS and list.size() == _unique(list).size()


func _unique(list: Array) -> Array:
	var out := []
	for x in list:
		if not out.has(x):
			out.append(x)
	return out


# the errors that block the confirm button (empty = fine). The flat build and the MAX filming preset are always fine.
func validate(b: Dictionary, path: String, who: String) -> Array:
	var out := []
	if str(b.get("preset", "flat")) == "max":
		return out
	var fours := 0
	for s in stats_of(path):
		var lv := level_of(b, str(s), who)
		if lv > MAX_START:
			out.append("MAX LEVEL AT START IS %d" % MAX_START)
		if lv > cap_of(str(s), who) and lv > floor_of(str(s), who):
			out.append("%s IS CAPPED AT %d" % [stat_name(path, str(s)), cap_of(str(s), who)])
		if lv == MAX_START:
			fours += 1
	if fours > 1:
		out.append("ONLY ONE STAT CAN START AT 4")
	if total_levels(b, path, who) > MAX_TOTAL:
		out.append("AT MOST %d LEVELS IN ALL" % MAX_TOTAL)
	if points_left(b, path, who) < 0:
		out.append("OVER BUDGET BY %d" % -points_left(b, path, who))
	if not quirks_ok(b.get("quirks", []), path):
		out.append("THOSE QUIRKS DO NOT GO TOGETHER")
	return out


# soft warnings shown under the stats (they do not block)
func warnings(b: Dictionary, path: String, who: String) -> Array:
	var out := []
	if path == "tech":
		if total_levels(b, path, who) < 4:
			out.append("FEW LEVELS: THE FIRST DAYS WILL BE SLOW")
		if level_of(b, "people", who) == 0 and level_of(b, "security", who) == 0:
			out.append("NO CUSTOMER AND NO SECURITY: RISKY")
	return out


# set one stat to a level when the guards allow it (lowering always works unless it leaves the floor)
func try_set(b: Dictionary, stat: String, lv: int, path: String, who: String) -> bool:
	if lv < floor_of(stat, who) or lv < 0 or lv > MAX_START:
		return false
	var before := level_of(b, stat, who)
	if lv == before:
		return false
	var copy: Dictionary = b.duplicate(true)
	copy.stats[stat] = lv
	if lv > before and not validate(copy, path, who).is_empty():
		return false
	b.stats[stat] = lv
	b["spent"] = cost_of(b, path, who)
	return true


# ---- presets ----------------------------------------------------------------------------------------------------
func preset_key(path: String, who: String) -> String:
	return "owner_" + who.to_lower() if path == "owner" else path


func presets_for(path: String, who: String) -> Array:
	return PRESETS.get(preset_key(path, who), [])


func preset_row(path: String, who: String, id: String) -> Dictionary:
	for row in presets_for(path, who):
		if str(row.id) == id:
			return row
	return {}


func preset_name(b: Dictionary, path: String, who: String) -> String:
	var id := str(b.get("preset", "flat"))
	if id == "custom":
		return "CUSTOM"
	if id == "max":
		return "MAX"
	if id == "flat":
		return "DEFAULT"
	return str(preset_row(path, who, id).get("name", id.to_upper()))


func new_build(tier: String) -> Dictionary:
	var b := flat()
	b["tier"] = tier
	b["seed"] = Difficulty.run_seed
	return b


# a preset fitted to the tier's budget
func apply_preset(path: String, who: String, tier: String, id: String) -> Dictionary:
	var b := new_build(tier)
	var row := preset_row(path, who, id)
	if row.is_empty():
		b["preset"] = "custom"
		return b
	b["preset"] = id
	b["quirks"] = row.get("quirks", []).duplicate()
	for step in row.steps:
		try_set(b, str(step), level_of(b, str(step), who) + 1, path, who)
	for _pass in 6:  # then spend what is left on the same priorities, so a preset fits every tier
		for step in row.steps:
			try_set(b, str(step), level_of(b, str(step), who) + 1, path, who)
	b["spent"] = cost_of(b, path, who)
	return b


# every stat at 5: Free Play's optional filming preset (no guards)
func max_build(path := "tech") -> Dictionary:
	var b := new_build("normal")
	b["preset"] = "max"
	for s in stats_of(path):
		b.stats[str(s)] = 5
	return b


func finalize(b: Dictionary, path: String, who: String) -> Dictionary:
	var out: Dictionary = b.duplicate(true)
	for s in stats_of(path):
		out.stats[str(s)] = level_of(out, str(s), who)
	out["spent"] = cost_of(out, path, who)
	out["seed"] = Difficulty.run_seed
	return out


# ---- what the build does in the game ----------------------------------------------------------------------------
# the sum of one quirk effect key over the running build's quirks
func fx(key: String) -> float:
	var n := 0.0
	for q in cur().get("quirks", []):
		n += float(QUIRKS.get(str(q), {}).get("fx", {}).get(key, 0.0))
	return n


func xp_mult() -> float:
	return maxf(0.5, 1.0 + fx("xp"))


# the tech Skills levels a non-flat build starts with (empty for the flat build and outside the tech stat set)
func tech_levels() -> Dictionary:
	var out := {}
	var b := cur()
	if is_flat(b):
		return out
	var campaign := get_node_or_null("/root/Campaign")
	var for_mode := str(campaign.mode) if campaign != null else ""
	if path_of(for_mode) != "tech":
		return out
	for s in stats_of("tech"):
		var lv := level_of(b, str(s), "")
		if lv > 0:
			out[str(s)] = lv
	return out


# the top stat of the running build ("" when flat); a hook for dialogue tone
func top_stat() -> String:
	var best := ""
	var best_lv := 0
	var tl := tech_levels()
	for s in tl:
		if int(tl[s]) > best_lv:
			best = str(s)
			best_lv = int(tl[s])
	return best


# owner edges: the deltas of one owner's stats above their free floors, added to Owner.edges_for (clamped)
func edge_deltas(owner_name: String) -> Dictionary:
	var out := {}
	var b := cur()
	if is_flat(b) or owner_name != Campaign.player_as or Campaign.mode != "owner":
		return out
	for stat in OWNER_FX:
		var up := level_of(b, str(stat), owner_name) - floor_of(str(stat), owner_name)
		if up == 0:
			continue
		for key in OWNER_FX[stat]:
			out[key] = float(out.get(key, 0.0)) + float(OWNER_FX[stat][key]) * float(up)
	return out


func clamp_edge(key: String, value: float) -> float:
	var lim: Array = EDGE_LIMITS.get(key, [-1000.0, 1000.0])
	return clampf(value, float(lim[0]), float(lim[1]))


func _owner_up(stat: String) -> int:
	var b := cur()
	if is_flat(b) or Campaign.mode != "owner":
		return 0
	return level_of(b, stat, Campaign.player_as) - floor_of(stat, Campaign.player_as)


func cash_bonus() -> int:
	return CASH_PER_FINANCE * _owner_up("finance")


func trust_bonus() -> int:
	if Campaign.mode != "owner":
		return 0
	return TRUST_PER_CULTURE * _owner_up("culture") + int(fx("trust"))


# called at the end of Campaign.new_game: the parts of a build that are not a plain number elsewhere
func apply_start() -> void:
	var b := cur()
	if not Campaign.active or is_flat(b):
		return
	var tl := tech_levels()
	if tl.has("people"):
		for who in Social.rel:
			Social.rel[who] = int(Social.rel[who]) + roundi(float(tl.people) * SOCIAL_PER_PEOPLE)
	Career.add("builds")
	Career.add("build." + str(b.preset))


# the line the review and the profile quote
func describe(b: Dictionary, path: String, who: String) -> String:
	var parts := []
	for s in stats_of(path):
		var lv := level_of(b, str(s), who)
		if lv > 0:
			parts.append("%s %d" % [stat_name(path, str(s)), lv])
	return "%s: %s" % [preset_name(b, path, who), ", ".join(parts) if not parts.is_empty() else "ALL ZERO"]
