extends SceneTree
# gdlint:disable=max-line-length
# The systems and content reference: docs/design/systems-reference.md, written from the real data tables so its numbers cannot go stale.
# Run from the repository root (the file is rewritten in place):
#   Godot --headless --path godot -s res://tests/make_systems_reference.gd
# To write somewhere else (the check tool does this) add an output path: ... -- --out C:/some/where/systems-reference.md
# Nothing here is typed by hand except the one-line "what this is" notes. Where a rule lives in a function and not in a table, the
# section says "text scan" (a small read of the script text, quoted verbatim) or "not data driven: see <file>".

const DOC_REL := "docs/design/systems-reference.md"
const MAX_CELL := 100

const PAD_NAMES := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 5: "Guide", 6: "Start", 7: "L3", 8: "R3", 9: "LB", 10: "RB", 11: "D-up", 12: "D-down", 13: "D-left", 14: "D-right"}
const AXIS_NAMES := {0: "LeftX", 1: "LeftY", 2: "RightX", 3: "RightY", 4: "LT", 5: "RT"}

var md := PackedStringArray()
var toc := PackedStringArray()
var errors := PackedStringArray()
var section_count := 0
var table_count := 0
var _root_dir := ""


func _initialize() -> void:
	await process_frame
	_root_dir = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var out_path := _root_dir.path_join(DOC_REL)
	var args := OS.get_cmdline_user_args()
	var oi := args.find("--out")
	if oi >= 0 and oi + 1 < args.size():
		out_path = args[oi + 1]
	_build()
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("cannot write ", out_path)
		quit(1)
		return
	f.store_string("\n".join(md) + "\n")
	f.close()
	print("wrote %s (%d sections, %d tables)" % [out_path, section_count, table_count])
	for e in errors:
		printerr("ERROR: ", e)
	quit(1 if errors.size() > 0 else 0)


# ---- access helpers ---------------------------------------------------------------------------------------
# a constant or variable of an autoload ("Msp", "CLIENTS") or of a plain script ("world_data", "SCENES")
func _k(src: String, key: String) -> Variant:
	var n: Node = root.get_node_or_null(src)
	if n != null:
		var v: Variant = n.get(key)
		if v != null:
			return v
		var sc: Script = n.get_script()
		if sc != null:
			return sc.get_script_constant_map().get(key)
		return null
	var s: Script = load("res://scripts/%s.gd" % src.to_snake_case()) as Script
	if s == null:
		errors.append("no script " + src)
		return null
	return s.get_script_constant_map().get(key)


func _kd(src: String, key: String) -> Dictionary:
	var v: Variant = _k(src, key)
	if v is Dictionary:
		return v
	errors.append("%s.%s is not a Dictionary" % [src, key])
	return {}


func _ka(src: String, key: String) -> Array:
	var v: Variant = _k(src, key)
	if v is Array:
		return v
	errors.append("%s.%s is not an Array" % [src, key])
	return []


func _read(rel: String) -> String:
	var p := rel if rel.begins_with("res://") else _root_dir.path_join(rel)
	if rel.begins_with("res://"):
		p = ProjectSettings.globalize_path(rel)
	return FileAccess.get_file_as_string(p)


# ---- markdown helpers -------------------------------------------------------------------------------------
func _s(v: Variant) -> String:
	var t := ""
	if v is Array:
		var parts := PackedStringArray()
		for x in v:
			parts.append(_s(x))
		t = ", ".join(parts)
	elif v is Dictionary:
		var parts := PackedStringArray()
		for k in v:
			parts.append("%s=%s" % [str(k), _s(v[k])])
		t = ", ".join(parts)
	elif v is float:
		t = "%s" % snappedf(v, 0.0001)
	else:
		t = str(v)
	t = t.replace("|", "/").replace("\n", " ").replace("\r", "")
	if t.length() > MAX_CELL:
		t = t.substr(0, MAX_CELL - 1) + "..."
	return t


func _h1(title: String, anchor_note: String = "") -> void:
	section_count += 1
	md.append("")
	md.append("## %d. %s" % [section_count, title])
	toc.append("%d. %s" % [section_count, title])
	if anchor_note != "":
		md.append("")
		md.append(anchor_note)


# a table: heading, one-line "what this is", source, column names, rows (each an Array)
func _t(title: String, what: String, source: String, cols: Array, rows: Array) -> void:
	table_count += 1
	md.append("")
	md.append("### %s" % title)
	md.append("")
	md.append("%s Source: `%s`. Rows: %d." % [what, source, rows.size()])
	md.append("")
	if rows.is_empty():
		errors.append("empty table: " + title)
		md.append("(none)")
		return
	var head := PackedStringArray()
	var sep := PackedStringArray()
	for c in cols:
		head.append(str(c))
		sep.append("---")
	md.append("| " + " | ".join(head) + " |")
	md.append("| " + " | ".join(sep) + " |")
	for r in rows:
		var cells := PackedStringArray()
		for v in r:
			cells.append(_s(v))
		md.append("| " + " | ".join(cells) + " |")


# a note under the last table (facts that are one line, not a table)
func _p(text: String) -> void:
	md.append("")
	md.append(text)


func _keys_sorted(d: Dictionary) -> Array:
	var ks: Array = d.keys()
	ks.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a).naturalnocasecmp_to(str(b)) < 0 if typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING else int(a) < int(b))
	return ks


func _count(v: Variant) -> int:
	if v is Dictionary or v is Array:
		return v.size()
	return 0


# total items in a dict of arrays (a day schedule: day -> [entries])
func _sum_sizes(d: Variant) -> int:
	var n := 0
	if d is Dictionary:
		for k in d:
			n += _count(d[k])
	return n


# the text of one function in a script (from "func name" to the next top-level line), for the text scans
func _func_text(script_rel: String, fname: String) -> String:
	var lines := _read(script_rel).split("\n")
	var out := PackedStringArray()
	var inside := false
	for line in lines:
		if line.begins_with("func %s(" % fname):
			inside = true
			continue
		if inside:
			if line.length() > 0 and not line.begins_with("\t") and not line.begins_with(" ") and not line.begins_with("#"):
				break
			out.append(line)
	return "\n".join(out)


# text scan: the gate (the enclosing `if` / `elif` lines) in front of every `"id": "x"` in a function
func _scan_ids(script_rel: String, fname: String) -> Array:
	var rows := []
	var stack := []  # [indent, condition] of the blocks that still enclose the current line
	var re := RegEx.new()
	re.compile("\"id\":\\s*\"([a-z0-9_]+)\"")
	for line in _func_text(script_rel, fname).split("\n"):
		var t := line.strip_edges()
		if t == "" or t.begins_with("#"):
			continue
		var indent := line.length() - line.lstrip("	").length()
		if t.begins_with("elif ") or t.begins_with("else"):
			while stack.size() > 0 and stack[-1][0] >= indent:
				stack.pop_back()
			stack.append([indent, t.trim_suffix(":") if t.begins_with("elif") else "otherwise"])
		elif t.begins_with("if "):
			while stack.size() > 0 and stack[-1][0] >= indent:
				stack.pop_back()
			stack.append([indent, t.trim_suffix(":")])
		else:
			while stack.size() > 0 and stack[-1][0] >= indent:
				stack.pop_back()
		var m := re.search(t)
		if m != null:
			var conds := PackedStringArray()
			for e in stack:
				conds.append(e[1])
			rows.append([m.get_string(1), " and ".join(conds) if conds.size() > 0 else "always"])
	return rows


func _key_name(k: int) -> String:
	return OS.get_keycode_string(k)



# ---- the document -----------------------------------------------------------------------------------------
func _build() -> void:
	_modes()
	_cast()
	_tickets()
	_cards()
	_outings()
	_progression()
	_rooms()
	_controls()
	_tech()
	var head := PackedStringArray()
	head.append("# MSPSim systems and content reference")
	head.append("")
	head.append("Generated file: do not edit by hand. It is written from the game's own data tables by `godot/tests/make_systems_reference.gd`, so every number here")
	head.append("is read from the code at the time of generation. Regenerate after content changes with one command, from the repository root:")
	head.append("")
	head.append("```")
	head.append("\"C:\\Program Files\\Godot\\Godot.exe\" --headless --path godot -s res://tests/make_systems_reference.gd")
	head.append("```")
	head.append("")
	head.append("`python tools/check_systems_reference.py` regenerates to a temporary file and lists which sections changed against this one.")
	head.append("The test `tests/systems_reference.gd` warns (never fails) when the committed copy has drifted.")
	head.append("")
	head.append("This is the \"tables of everything\" companion to the design document: it quantifies the game (modes, people, tickets, cards, outings, medals,")
	head.append("rooms, controls) the way the original Grand Theft Auto design document listed every object with its attributes. The game is set in 2013-14.")
	head.append("Where a rule is not stored in a table, the section either quotes the script text (marked \"text scan\") or says \"not data driven\" and names the file.")
	head.append("")
	head.append("## Contents")
	head.append("")
	for t in toc:
		head.append("- " + t)
	md = head + md


# ---- 1. modes and structure -------------------------------------------------------------------------------
func _modes() -> void:
	_h1("Modes and structure")
	var defs := _kd("Campaign", "MODE_DEFS")
	var rows := []
	for m in defs:
		var d: Dictionary = defs[m]
		rows.append([m, d.get("label", ""), d.get("selectable", false), d.get("unit", ""), d.get("total_days", 0), d.get("day_len", 0), d.get("review", ""), d.get("review_pages", 0), d.get("pace", 0), d.get("year2", false)])
	_t("1.1 The four campaigns", "One row per campaign mode (Free Play is a separate flag, see below). `day_len` is seconds per in-game day at normal day length.", "scripts/campaign.gd MODE_DEFS", ["mode", "label", "selectable", "unit", "days", "day_len s", "review", "review pages", "crew pace", "year 2"], rows)
	rows = []
	for m in defs:
		var d: Dictionary = defs[m]
		rows.append([m, d.get("crew", false), d.get("books", false), d.get("cards", false), d.get("books_lite", false), d.get("hud", ""), d.get("report", ""), d.get("shift", false), d.get("scars", false), d.get("ending_fired", "")])
	_t("1.2 Machinery gates per mode", "Which systems each mode runs: the crew works the queue, the books (cash, P&L), the weekly decision cards, the lite books of the sales mode.", "scripts/campaign.gd MODE_DEFS", ["mode", "crew", "books", "cards", "books lite", "HUD", "report", "shift", "scars", "fired text"], rows)
	_p("Free Play: `Campaign.FREE` = `%s` (no days, no ending; the toolbox, mutators and outings are open). Total days in a year: `Campaign.TOTAL_DAYS` = %d." % [str(_k("Campaign", "FREE")), int(_k("Campaign", "TOTAL_DAYS"))])

	var y2 := _kd("Yeartwo", "DEFAULT_YEAR2")
	var y3 := _kd("Yeartwo", "DEFAULT_YEAR3")
	rows = []
	for m in defs:
		var b2: Dictionary = (y2.get("beats", {}) as Dictionary).get(m, {})
		var b3: Dictionary = (y3.get("beats", {}) as Dictionary).get(m, {})
		var e2: Array = (y2.get("endings", {}) as Dictionary).get(m, [])
		var e3: Array = (y3.get("endings", {}) as Dictionary).get(m, [])
		rows.append([m, defs[m].get("total_days", 0), b2.size(), b2, b3.size(), b3, e2.size(), e3.size()])
	_t("1.3 Years 1 to 3", "Year 1 is the base campaign. Year 2 (New Game Plus) and Year 3 add beats on given days or weeks and their own endings. `beats` lists beat id = day or week.", "scripts/yeartwo.gd DEFAULT_YEAR2 / DEFAULT_YEAR3", ["mode", "days in year", "Y2 beats", "Y2 beat id = day", "Y3 beats", "Y3 beat id = day", "Y2 endings", "Y3 endings"], rows)
	_p("Year chapters: `Yeartwo.YEAR` = %d, `Yeartwo.LAST_YEAR` = %d (no year 4). Year 2 SLA multiplier %s, Year 3 SLA multiplier %s." % [int(_k("Yeartwo", "YEAR")), int(_k("Yeartwo", "LAST_YEAR")), str((y2.sla as Dictionary).mult), str((y3.sla as Dictionary).mult)])
	rows = []
	for k in ["tickets", "clients", "mutators", "shuffle"]:
		rows.append([k, _s(y2.get(k, ""))])
	_t("1.4 Year 2 changes", "What the second year changes on top of the carried-over run.", "scripts/yeartwo.gd DEFAULT_YEAR2", ["key", "value"], rows)

	# endings: year 1 by text scan, years 2 and 3 from tables
	rows = []
	for spec in [["tech", "res://scripts/review.gd", "make_offers"], ["owner", "res://scripts/owner.gd", "_base_offers"], ["service", "res://scripts/service.gd", "review_offers"], ["sales", "res://scripts/sales_campaign.gd", "offers"]]:
		for r in _scan_ids(spec[1], spec[2]):
			if (r[0] as String) in ["ok", "yes", "no"]:
				continue
			rows.append([spec[0], r[0], r[1], "text scan: %s %s()" % [spec[1].get_file(), spec[2]]])
	_t("1.5 Year 1 endings and what each needs (text scan)", "Offered at the end of the first year. The need column is the `if` line in front of the offer, quoted from the source; `otherwise` and `always` mean no gate. Not stored as data.", "scripts/review.gd make_offers, owner.gd _base_offers, service.gd review_offers, sales_campaign.gd offers", ["mode", "ending id", "gate (source line)", "where"], rows)
	var needs: Dictionary = y3.get("needs", {})
	rows = []
	for m in y2.get("endings", {}):
		for e in y2.endings[m]:
			rows.append(["Y2", m, e, "see Yeartwo._offer_ok (not data driven: scripts/yeartwo.gd)"])
	for m in y3.get("endings", {}):
		for e in y3.endings[m]:
			rows.append(["Y3", m, e, needs.get(e, {})])
	_t("1.6 Year 2 and Year 3 endings", "Year 3 thresholds come from the `needs` table (rep = reputation, clients, trust). Year 2 gates are in `_offer_ok` (not data driven).", "scripts/yeartwo.gd DEFAULT_YEAR2 / DEFAULT_YEAR3", ["year", "mode", "ending id", "needs"], rows)
	_p("Other ways a run ends: fired at zero reputation (`ending_fired` in 1.2); owner-mode partner endings (buyout, sellout, left) from `scripts/owner.gd _ending_text` (not data driven).")

	# difficulty
	var tiers: Array = _k("Difficulty", "TIERS")
	var notes := _kd("Difficulty", "TIER_NOTES")
	rows = []
	for m in notes:
		for t in tiers:
			rows.append([m, t, notes[m][t]])
	_t("1.7 Difficulty tiers", "Three tiers (easy is the cozy tier). The line shown under the tier picker for each campaign.", "scripts/difficulty.gd TIER_NOTES", ["mode", "tier", "tier note"], rows)
	_p("Day length option (x on the mode's `day_len`): %s. Mastery ramp: `RAMP_PLAYS` = %s good plays to full mastery, easy blends %s of the way, hard goes at most %s beyond its own value." % [_s(_k("Difficulty", "DAY_SCALES")), str(_k("Difficulty", "RAMP_PLAYS")), str(_k("Difficulty", "EASY_RAMP")), str(_k("Difficulty", "HARD_OVER"))])
	var table := _kd("Difficulty", "TABLE")
	var mastery: Array = _k("Difficulty", "MASTERY_KEYS")
	rows = []
	for k in table:
		var area := str(k).split(".")[0]
		var v: Array = table[k]
		rows.append([area, k, v[0], v[1], v[2], "yes" if mastery.has(k) else ""])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return str(a[1]) < str(b[1]))
	_t("1.8 Difficulty table (every key)", "Every `Difficulty.TABLE` dial, grouped by area (the part of the key before the dot). `mastery` marks the keys that tighten with the per-game mastery ramp.", "scripts/difficulty.gd TABLE", ["area", "key", "easy", "normal", "hard", "mastery"], rows)
	var cozy := _kd("Difficulty", "COZY")
	rows = []
	for k in cozy:
		rows.append([k, cozy[k]])
	_t("1.9 Cozy tier dials", "What the easy (cozy) tier changes outside the mini-games.", "scripts/difficulty.gd COZY", ["key", "value"], rows)
	var tq := _kd("SalesCampaign", "TIER_QUOTA")
	var bb := _kd("Build", "BUDGET")
	var dr := _kd("Deals", "TIER_RIVAL")
	rows = []
	for t in tiers:
		rows.append([t, bb.get(t), tq.get(t), dr.get(t), (_k("Mutators", "COUNT_BY_TIER") as Dictionary).get(t)])
	_t("1.10 Tier perks outside the table", "Per-tier numbers kept in other scripts: character build points, sales quota multiplier, rival bid multiplier, mutator count range.", "scripts/build.gd BUDGET, sales_campaign.gd TIER_QUOTA, deals.gd TIER_RIVAL, mutators.gd COUNT_BY_TIER", ["tier", "build points", "quota x", "rival bid x", "mutators (min, max)"], rows)


# ---- 2. the cast ------------------------------------------------------------------------------------------
func _cast() -> void:
	_h1("The cast")
	var rows := []
	var soc := _kd("Social", "ROLES")
	var jobs := _kd("Roles", "JOBS")
	var job_of := {}
	for j in jobs:
		job_of[jobs[j]] = j
	for spec in [["World", "CAST", "main cast"], ["World", "CREW_CAST", "crew (owner / service)"], ["World", "STAFF_CAST", "staff (family of the office)"]]:
		var d := _kd(spec[0], spec[1])
		for n in d:
			var e: Dictionary = d[n]
			rows.append([n, spec[2], e.get("character", ""), e.get("role", ""), soc.get(n, ""), job_of.get(n, ""), e.get("home", ""), e.get("seat", "")])
	_t("2.1 Named people", "Everyone who has a desk in the office, with the scene they start in, their seat and their title.", "scripts/world.gd CAST / CREW_CAST / STAFF_CAST, social.gd ROLES, roles.gd JOBS", ["name", "group", "character file", "role", "title", "job (in the role map)", "home scene", "seat"], rows)
	_p("Counts: %d main cast + %d crew + %d staff = %d people with a seat." % [_kd("World", "CAST").size(), _kd("World", "CREW_CAST").size(), _kd("World", "STAFF_CAST").size(), rows.size()])
	var ros := _ka("Crew", "ROSTER")
	var wages := _kd("Crew", "WAGES")
	var lanes := _kd("Crew", "START_LANE")
	rows = []
	for r in ros:
		var a: Dictionary = r.areas
		rows.append([r.name, r.title, r.skill, a.get("powershell"), a.get("networking"), a.get("servers"), a.get("security"), a.get("people"), wages.get(r.name, ""), lanes.get(r.name, "")])
	_t("2.2 The crew", "The service-desk crew in the owner, service and sales campaigns: area levels (0 to 3), base speed, weekly wage, tier lane.", "scripts/crew.gd ROSTER / WAGES / START_LANE", ["name", "tier", "speed", "powershell", "networking", "servers", "security", "people", "wage $/week", "lane"], rows)
	var clients := _ka("Msp", "CLIENTS")
	var sites := _kd("Onsite", "SITES")
	var drive := _kd("Onsite", "DRIVE_MINUTES")
	rows = []
	for i in clients.size():
		var c: Dictionary = clients[i]
		var s: Dictionary = sites.get(i, {})
		rows.append([i, c.name, c.short, c.contact, s.get("type", ""), s.get("skin", ""), drive.get(i, "")])
	_t("2.3 Clients", "The client companies (tickets, onsite visits and sales). `site type` and `drive` exist only for clients with an onsite job site.", "scripts/msp.gd CLIENTS, onsite.gd SITES / DRIVE_MINUTES", ["index", "name", "short", "contact", "site type", "site skin", "drive min"], rows)
	var staff := _kd("Onsite", "CAST_AT")
	rows = []
	for t in staff:
		var n := 0
		var rooms := 0
		for v in staff[t]:
			for room in staff[t][v]:
				rooms += 1
				n += (staff[t][v][room] as Array).size()
		rows.append([t, (staff[t] as Dictionary).size(), rooms, n])
	_t("2.4 People at client sites", "How many people stand in each type of client site (variants a and b, rooms, people placed).", "scripts/onsite.gd CAST_AT", ["site type", "variants", "rooms", "people placed"], rows)
	var crowd := _kd("Expo", "CROWD")
	rows = []
	for sc in crowd:
		var roles := {}
		for p in crowd[sc]:
			var r := str(p.get("role", "")).split(":")[0]
			roles[r] = int(roles.get(r, 0)) + 1
		rows.append([sc, (crowd[sc] as Array).size(), roles])
	_t("2.5 People at the trade expo", "The expo crowd per scene, by role.", "scripts/conference.gd CROWD", ["scene", "people", "roles"], rows)
	var forum := _ka("Expo", "FORUM")
	rows = []
	for f in forum:
		rows.append([f.id, f.speaker, (f.options as Array).size()])
	_t("2.6 Forum characters at the expo", "The forum people met at the expo, each with a choice card.", "scripts/conference.gd FORUM", ["id", "speaker", "options"], rows)
	var guests := _kd("Outings", "DEFAULT_GUESTS")
	rows = []
	for g in guests:
		rows.append([g, guests[g].get("code", ""), guests[g].get("comes", "")])
	_t("2.7 Outing guests and visitors", "Who joins a team outing and how likely they come; the client guest pool for dinners follows.", "scripts/outings.gd DEFAULT_GUESTS", ["name", "code", "comes (chance)"], rows)
	_p("Dinner guest pool (clients and owners who can sit at the table): %d people (`Outings.GUEST_POOL`)." % _ka("Outings", "GUEST_POOL").size())
	# character files by group
	rows = []
	var total := 0
	for grp in ["staff", "clients", "expo", "custom"]:
		var names := _list_files("sprites/" + grp, ".aseprite")
		var stills := 0
		var anims := 0
		for nme in names:
			if nme.ends_with("_anim.aseprite"):
				anims += 1
			else:
				stills += 1
		total += stills
		rows.append([grp, stills, anims, stills / 2])
	_t("2.8 Character files", "Sprite files per folder (a person is a left and a right file). Counted from the file system.", "sprites/<group>/*.aseprite (file system)", ["folder", "stills", "animations", "people (stills / 2)"], rows)
	_p("Total character stills: %d." % total)


func _list_files(rel: String, ext: String) -> Array:
	var out := []
	var d := DirAccess.open(_root_dir.path_join(rel))
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(f)
	out.sort()
	return out


func _list_dirs(rel: String) -> Array:
	var d := DirAccess.open(_root_dir.path_join(rel))
	if d == null:
		return []
	var out: Array = Array(d.get_directories())
	out.sort()
	return out


# ---- 3. tickets -------------------------------------------------------------------------------------------
func _tickets() -> void:
	_h1("Tickets and fixes")
	var rows := []
	for p in _ka("Msp", "DEFAULT_PROBLEMS"):
		rows.append([p.summary, p.fix, p.pri, "no"])
	for spec in [["Msp", "DEFAULT_RANSOM", "ransomware (server)"], ["Msp", "DEFAULT_ADOBE", "special: Adobe"]]:
		var p := _kd(spec[0], spec[1])
		rows.append([p.summary, p.fix, p.pri, spec[2]])
	_t("3.1 Base ticket problem types", "The everyday problems a client can call in. `fix` is the correct fix; `pri` 1 is the most urgent.", "scripts/msp.gd DEFAULT_PROBLEMS / DEFAULT_RANSOM / DEFAULT_ADOBE", ["problem", "fix", "priority", "special"], rows)
	var inst := _kd("Msp", "DEFAULT_INSTALL")
	var items := _ka("Msp", "INSTALL_ITEMS")
	rows = []
	for i in items:
		rows.append([i.id, i.name, i.key, i.secs, i.hidden])
	_t("3.2 New-desktop install items", "The checklist of the desktop replacement job (`key` items are the ones that must not be missed; `hidden` ones show only on some difficulty or ask paths).", "scripts/msp.gd INSTALL_ITEMS", ["id", "item", "key item", "seconds", "hidden for"], rows)
	var fixes := _kd("Msp", "FIXES")
	var fa := _kd("Crew", "FIX_AREA")
	var fx := _kd("Skills", "FIX_XP")
	var need := _kd("Crew", "FIX_NEED")
	var alt := _kd("Msp", "ALT_FIXES")
	var heavy: Array = _k("Msp", "HEAVY_ONSITE")
	rows = []
	for f in fixes:
		rows.append([f, fixes[f], fa.get(f, ""), fx.get(f, ""), need.get(f, ""), alt.get(f, ""), "yes" if heavy.has(f) else ""])
	_t("3.3 Fixes", "Every fix button in the ticket tool. `area` is the crew skill area that does it, `XP area` where the player gains skill, `crew level` the area level a crew member needs, `alt` the other accepted fix, `heavy` fixes that need an onsite visit.", "scripts/msp.gd FIXES / ALT_FIXES / HEAVY_ONSITE, crew.gd FIX_AREA / FIX_NEED, skills.gd FIX_XP", ["fix id", "button", "crew area", "XP area", "crew level gate", "alt fix", "heavy onsite"], rows)
	var secs: Array = _k("Skills", "FIX_SECS")
	var fail: Array = _k("Skills", "FAIL")
	var xp: Array = _k("Skills", "XP_AT")
	rows = []
	for i in secs.size():
		rows.append([i, secs[i], fail[i], xp[i - 1] if i >= 1 and i - 1 < xp.size() else 0])
	_t("3.4 Fix time and fail chance by skill level", "Seconds a fix takes and the chance it fails, by the player's PowerShell level. `XP needed` is the experience to reach that level.", "scripts/skills.gd FIX_SECS / FAIL / XP_AT", ["level", "fix seconds", "fail chance", "XP needed"], rows)
	var alts := _kd("Msp", "ALT_DEFS")
	rows = []
	for a in alts:
		var d: Dictionary = alts[a]
		rows.append([a, d.get("label", ""), d.get("for", []), d.get("kind", ""), d.get("mult", ""), d.get("xp", ""), d.get("ret", "")])
	_t("3.5 Alternative fixes", "Cheaper or riskier ways to handle a problem. `mult` scales the time, `ret` is the chance the problem returns.", "scripts/msp.gd ALT_DEFS", ["id", "label", "for fix", "kind", "time x", "xp", "return chance"], rows)
	var rl := _kd("Msp", "RANSOM_LABELS")
	var rm := _kd("Msp", "RANSOM_MULT")
	rows = []
	for k in rl:
		rows.append([k, rl[k], rm.get(k, ""), fixes.get(k, "")])
	_t("3.6 Ransomware exits", "The ways a ransomware ticket can end. `cost x` multiplies the base ransom for the vendor, rebuild and insurer routes.", "scripts/msp.gd RANSOM_LABELS / RANSOM_MULT / FIXES", ["exit", "ending label", "cost x", "button"], rows)
	var sla := _kd("Msp", "SLA_SECS")
	rows = []
	for p in sla:
		rows.append([p, sla[p]])
	_t("3.7 SLA clocks", "Seconds a ticket may wait by priority (before the year multipliers and tier scale).", "scripts/msp.gd SLA_SECS", ["priority", "seconds"], rows)
	var caps := _kd("Msp", "DAY_CAPS")
	var oc := _kd("Msp", "OPEN_CAPS")
	rows = []
	for d in caps:
		rows.append([d, caps[d], oc.get(d, oc.get(oc.keys()[oc.size() - 1]))])
	_t("3.8 Tickets per day (tech campaign)", "How many tickets can arrive on each day and the cap on the open queue (`OPEN_CAPS` ends at day 9 and holds after).", "scripts/msp.gd DAY_CAPS / OPEN_CAPS", ["day", "ticket cap", "open queue cap"], rows)
	var pn: Array = _k("Msp", "PACE_NAMES")
	rows = []
	for i in pn.size():
		rows.append([pn[i], (_k("Msp", "PACE_DAY") as Array)[i], (_k("Msp", "PACE_GAP") as Array)[i], (_k("Msp", "PACE_OPEN") as Array)[i]])
	_t("3.9 Ticket pace option", "The TICKET PACE setting (tech campaign) multiplies the day cap, the gap between timed tickets and the open cap.", "scripts/msp.gd PACE_*", ["pace", "day cap x", "gap x", "open cap +"], rows)
	var jobs := _ka("Onsite", "DEFAULT_JOBS") + _ka("Onsite", "DEFAULT_MORE_JOBS")
	rows = []
	for j in jobs:
		var chances := []
		for o in j.options:
			chances.append(o.get("chance", ""))
		rows.append([j.id, j.object, j.pri, (j.options as Array).size(), chances])
	_t("3.10 Onsite jobs", "Visits to a client site. `options` is how many ways to attempt it (each with a skill, hours, XP and success chance).", "scripts/onsite.gd DEFAULT_JOBS + DEFAULT_MORE_JOBS", ["job id", "object", "priority", "options", "option success chances"], rows)
	var ev := _kd("Onsite", "DEFAULT_EVENTS")
	_p("Onsite site events: %d (`Onsite.DEFAULT_EVENTS`); site findings: %d; site meetings: %d." % [ev.size(), _kd("Onsite", "DEFAULT_FINDINGS").size(), _kd("Onsite", "DEFAULT_MEETINGS").size()])
	var books := _kd("Playbook", "DEFAULT_BOOKS")
	var pp := _kd("Playbook", "DEFAULT_PROBLEMS")
	rows = []
	for b in books:
		var choices := 0
		for s in books[b].steps:
			choices += (s.choices as Array).size()
		rows.append([b, books[b].title, books[b].client, books[b].specials, (books[b].steps as Array).size(), choices, (pp.get(b, []) as Array).size()])
	_t("3.11 Playbook jobs", "The multi-step incident jobs (rack recovery, mail migration, and so on): a client, the steps, the choices in them and the follow-on tickets.", "scripts/playbook.gd DEFAULT_BOOKS / DEFAULT_PROBLEMS", ["job id", "title", "client", "specials", "steps", "choices", "follow-on tickets"], rows)
	var models := _kd("printer_game", "MODELS")
	var order: Array = _k("printer_game", "MODEL_ORDER")
	var bagfor := _kd("printer_game", "BAG_FOR")
	var bags := _kd("printer_game", "BAGS")
	rows = []
	for m in order:
		var d: Dictionary = models[m]
		rows.append([m, d.label, d.phases, (d.tray as Array).size(), bagfor.get(m, ""), bags.get(bagfor.get(m, ""), "")])
	_t("3.12 Printer models and bag choices", "The printer mini-game: each model has its own phases, and the repair bag choice that fits it.", "scripts/printer_game.gd MODELS / BAG_FOR / BAGS", ["model", "label", "phases", "tray choices", "right bag", "bag name"], rows)
	var dp := _kd("Playbook", "DEFAULT_BOOKS")
	_p("Mutator extra problems and Year 2 mutators are in section 6. Playbook jobs: %d. Base problem types: %d plus ransomware, Adobe and the desktop replacement." % [dp.size(), _ka("Msp", "DEFAULT_PROBLEMS").size()])
	if inst.size() == 0:
		errors.append("install empty")


# ---- 4. cards and story -----------------------------------------------------------------------------------
func _cards() -> void:
	_h1("Cards and story")
	var rows := []
	var total := 0
	var add := func(deck: String, what: String, n: int, source: String, sched: String) -> void:
		rows.append([deck, what, n, sched, source])
	add.call("Owner cards", "weekly decision cards of the owner campaign", _kd("Owner", "DEFAULT_CARDS").size(), "owner.gd DEFAULT_CARDS", "%d week slots, %d placements" % [_kd("Owner", "DAYS").size(), _sum_sizes(_kd("Owner", "DAYS"))])
	add.call("Owner ops leads", "client leads the owner can chase", _ka("owner_ops", "DEFAULT_LEADS").size(), "owner_ops.gd DEFAULT_LEADS", "")
	add.call("Owner cast cards", "Jen and Michael decision cards", _kd("owner_cast", "DEFAULT_CARDS").size(), "owner_cast.gd DEFAULT_CARDS", "%d weeks" % _kd("owner_cast", "DEFAULT_DAYS").size())
	add.call("Partner beats", "partner meetings (owner)", _kd("Partner", "BEATS").size(), "partner.gd BEATS", "weeks %s" % _s(_k("Partner", "MEETING_WEEKS")))
	add.call("Vignettes", "story scenes of the tech campaign", _kd("Story", "DEFAULT_VIGNETTES").size(), "story.gd DEFAULT_VIGNETTES", "%d days, %d placements" % [_kd("Story", "DEFAULT_DAYS").size(), _sum_sizes(_kd("Story", "DEFAULT_DAYS"))])
	add.call("Postmortems", "end-of-ticket story reviews", _kd("Story", "DEFAULT_POSTMORTEMS").size(), "story.gd DEFAULT_POSTMORTEMS", "")
	add.call("Random events", "the shared event deck (tech, owner or both)", _kd("Events", "DEFAULT_DECK").size(), "events.gd DEFAULT_DECK", "")
	add.call("Seasonal cards", "holiday, tax and end-of-support cards", _kd("seasons", "DEFAULT_CARDS").size(), "seasons.gd DEFAULT_CARDS", "%d seasons" % _kd("seasons", "SEASONS").size())
	add.call("Seasonal events", "potluck, tax basket and so on", _kd("seasons", "DEFAULT_EVENTS").size(), "seasons.gd DEFAULT_EVENTS", "")
	add.call("Temptation cards", "shortcuts that grow into skeletons", _kd("temptation", "BILLS").size(), "temptation.gd BILLS (one bill per card)", "")
	add.call("Good habits", "habits you can adopt (the Standard)", _kd("habits", "DEFAULT_HABITS").size(), "habits.gd DEFAULT_HABITS", "")
	add.call("Habit cards", "offer, lapse, revenge and similar cards", _kd("habits", "DEFAULT_CARDS").size(), "habits.gd DEFAULT_CARDS", "")
	add.call("Rival habits", "what the rival firms do wrong", _kd("rival", "DEFAULT_HABITS").size(), "rival.gd DEFAULT_HABITS", "%d rivals" % _kd("rival", "DEFAULT_RIVALS").size())
	add.call("Rival cards", "rival-firm decision cards", _kd("rival_cards", "DEFAULT_CARDS").size(), "rival_cards.gd DEFAULT_CARDS", "%d weeks" % _kd("rival_cards", "DEFAULT_DAYS").size())
	add.call("Service huddle memos", "memos of Alan and Garrison", _sum_sizes(_kd("Service", "DEFAULT_MEMOS")), "service.gd DEFAULT_MEMOS", "")
	add.call("Service beats", "story beats of the service campaign", _kd("Service", "DEFAULT_BEATS").size(), "service.gd DEFAULT_BEATS", "%d days" % _kd("Service", "DEFAULT_DAYS").size())
	add.call("Service incidents", "incident cards", _kd("Service", "DEFAULT_INCIDENTS").size(), "service.gd DEFAULT_INCIDENTS", "")
	add.call("Service arc cards", "annual arc (Heartbleed wave, resets, promotion)", _kd("ServiceArc", "DEFAULT_ARC").size(), "service_arc.gd DEFAULT_ARC", "")
	var one := _kd("Service", "DEFAULT_ONE_ON_ONES")
	for p in one:
		add.call("Service 1:1 deck: " + str(p), "one-to-one conversations with this person", (one[p] as Array).size(), "service.gd DEFAULT_ONE_ON_ONES", "")
	add.call("Sales beats", "story beats of the sales campaign", _kd("SalesCampaign", "DEFAULT_BEAT_TEXT").size(), "sales_campaign.gd DEFAULT_BEAT_TEXT", "%d scheduled weeks" % _kd("sales_beats", "WEEKS").size())
	var y2 := _kd("Yeartwo", "DEFAULT_YEAR2")
	var y3 := _kd("Yeartwo", "DEFAULT_YEAR3")
	var n2 := 0
	var n3 := 0
	for m in (y2.beats as Dictionary):
		n2 += (y2.beats[m] as Dictionary).size()
	for m in (y3.beats as Dictionary):
		n3 += (y3.beats[m] as Dictionary).size()
	add.call("Year 2 beats", "second-year beats, all modes", n2, "yeartwo.gd DEFAULT_YEAR2", "")
	add.call("Year 3 beats", "third-year beats, all modes", n3, "yeartwo.gd DEFAULT_YEAR3", "")
	add.call("Expo forum cards", "forum people at the trade expo", _ka("Expo", "FORUM").size(), "conference.gd FORUM", "")
	add.call("Expo vendors", "vendor booth cards", _ka("Expo", "DEFAULT_VENDORS").size() + _ka("trip_variety", "EXTRA_VENDORS").size(), "conference.gd + trip_variety.gd", "")
	add.call("Expo chats", "hallway chat cards", _ka("Expo", "DEFAULT_CHATS").size() + _ka("trip_variety", "EXTRA_CHATS").size(), "conference.gd + trip_variety.gd", "")
	add.call("Nerd forum boards", "boards of the in-game forum", _ka("Nerds", "DEFAULT_BOARDS").size(), "nerds.gd DEFAULT_BOARDS", "")
	add.call("Nerd forum threads", "threads of the in-game forum", _ka("Nerds", "DEFAULT_THREADS").size(), "nerds.gd DEFAULT_THREADS", "")
	_t("4.1 Decks and counts", "Every deck of cards or beats. `schedule` is how the deck is placed. The total adds the counts; decks that share a card format are separate rows.", "see the source column", ["deck", "what it is", "count", "schedule", "source"], rows)
	for r in rows:
		total += int(r[2])
	_p("Total cards and beats counted above: %d. The owner campaign's live deck (`Owner.CARDS`) merges the owner, cast and rival cards at start-up: %d cards in all, so those rows overlap with it." % [total, _kd("Owner", "CARDS").size()])
	var ys := _kd("Yeartwo", "DEFAULT_TEXT")
	rows = []
	for k in ys:
		rows.append([k, _count(ys[k])])
	_t("4.2 Year 2 text blocks", "Parts of the Year 2 narrative text (intro, beats per mode, offers, habit cards, ending texts).", "scripts/yeartwo.gd DEFAULT_TEXT", ["block", "entries"], rows)
	var all_stories := 0
	for sc in ["Story", "Owner", "Service"]:
		all_stories += 1
	var seas := _kd("seasons", "SEASONS")
	rows = []
	for s in seas:
		var d: Dictionary = seas[s]
		rows.append([s, d.name, d.from, d.to, d.year, d.dressing])
	_t("4.3 Seasons", "Calendar seasons that change the decor and unlock their cards (month index from November).", "scripts/seasons.gd SEASONS", ["id", "name", "from month", "to month", "year", "dressing"], rows)
	if all_stories == 0:
		errors.append("unreachable")


# ---- 5. outings and mini-games ----------------------------------------------------------------------------
func _outings() -> void:
	_h1("Outings and mini-games")
	var games := _kd("Outings", "GAMES")
	var rows := []
	for g in games:
		rows.append([g, games[g].label, games[g].cost, games[g].get("keys", "")])
	_t("5.1 Outing games", "The games a team outing can offer, with the cost in dollars of one outing.", "scripts/outings.gd GAMES", ["id", "label", "cost $", "keys line"], rows)
	var rooms := _kd("Outings", "ROOMS")
	rows = []
	for r in rooms:
		rows.append([r, rooms[r]])
	_t("5.2 Outing venues", "The scene each outing game plays in.", "scripts/outings.gd ROOMS", ["game", "scene"], rows)
	rows = [
		["tech campaign outing days", _k("Outings", "TECH_DAYS")],
		["tech campaign lunch days", _k("Outings", "LUNCH_TECH")],
		["owner campaign lunch weeks", _k("Outings", "LUNCH_OWNER")],
		["owner campaign outing weeks", _k("Outings", "OWNER_WEEKS")],
		["chair race events on the card", _k("Outings", "CHAIR_EVENTS")],
		["meeting days (tech)", _k("Meeting", "MEETING_DAYS")],
		["expo trip clocks", _k("Expo", "CLOCKS")],
		["expo trip reputation gain by effort 0..4", _k("Expo", "TRIP_GAIN")],
	]
	_t("5.3 When outings happen", "The scheduled days or weeks for outings, lunches, meetings and the expo trip.", "scripts/outings.gd, meeting.gd, conference.gd", ["what", "days or values"], rows)
	var songs := _ka("Outings", "DEFAULT_SONGS")
	rows = []
	for s in songs:
		rows.append([s.id, s.title, s.artist, s.genre, s.len, s.gap, s.speed, s.unlock, s.pattern])
	_t("5.4 Karaoke songs", "Every song: length in notes, gap between notes, scroll speed, how many wins unlock it.", "scripts/outings.gd DEFAULT_SONGS", ["id", "title", "artist", "genre", "notes", "gap s", "speed", "unlock at", "pattern"], rows)
	var themes := _kd("Outings", "DEFAULT_ESCAPE_THEMES")
	var order: Array = _k("Outings", "THEME_ORDER")
	var recipes := _kd("Outings", "RECIPES")
	rows = []
	for t in order:
		rows.append([t, themes[t].title, themes[t].short, (themes[t].get("say", {}) as Dictionary).size()])
	_t("5.5 Escape room themes", "Four rooms. `clue lines` is how many sentence templates the room can say.", "scripts/outings.gd DEFAULT_ESCAPE_THEMES / THEME_ORDER", ["theme", "title", "short", "clue lines"], rows)
	rows = []
	var nrec := 0
	for z in recipes:
		var rs: Array = recipes[z]
		nrec += rs.size()
		rows.append([z, rs.size(), rs])
	_t("5.6 Escape recipes", "How a code digit is built from a clue, per clue zone. Themes x zones x recipes give the puzzle variety.", "scripts/outings.gd RECIPES", ["zone", "recipes", "recipe ids"], rows)
	_p("Escape variety: %d themes x %d clue zones, %d recipes in total; the code has %s digits (easy / normal / hard)." % [order.size(), recipes.size(), nrec, _s((_kd("Difficulty", "TABLE")["escape.digits"]))])
	var bud := _kd("Outings", "BUDGETS")
	rows = []
	for b in bud:
		rows.append([b, bud[b].label, bud[b].cost, bud[b].mood])
	_t("5.7 Dinner budgets", "The three dinner budgets.", "scripts/outings.gd BUDGETS", ["id", "label", "cost $", "mood"], rows)
	var dishes := _ka("Outings", "DISHES")
	_p("Dinner: %d dishes, %d table topics (%d protected), %d diets (%s), %d guest topics." % [dishes.size(), _ka("Outings", "TOPICS").size(), _ka("Outings", "PROTECTED_TOPICS").size(), _kd("Outings", "DIETS").size(), _s(_kd("Outings", "DIETS").keys()), _ka("Outings", "GUEST_TOPICS").size()])
	var nm := _kd("nerf_modes", "MODES")
	var nar := _kd("nerf_modes", "ARENAS")
	rows = []
	for m in nm:
		rows.append([m, nm[m].label, nm[m].win])
	_t("5.8 Nerf war modes", "The dart-gun game modes and the win line of each.", "scripts/nerf_modes.gd MODES", ["id", "label", "win condition"], rows)
	rows = []
	for a in nar:
		rows.append([a, nar[a].label, nar[a].secs, nar[a].gap, nar[a].lives, nar[a].cups])
	_t("5.9 Nerf arenas", "Where the nerf war is played, and its clock, lives and cups.", "scripts/nerf_modes.gd ARENAS", ["scene", "label", "seconds", "gap", "lives", "cups"], rows)
	var cr := _kd("chair_race", "COURSES")
	rows = []
	for c in cr:
		rows.append([c, cr[c].label, cr[c].len, cr[c].checks, cr[c].par])
	_t("5.10 Chair race courses", "The chair race (warehouse): the straight and the gauntlet. The chair fight is its own mode.", "scripts/chair_race.gd COURSES", ["id", "label", "length", "checkpoints", "par"], rows)
	var racers := _kd("chair_race", "RACERS")
	rows = []
	for r in racers:
		rows.append([r, racers[r].skill, racers[r].style])
	_t("5.11 Chair racers", "Skill (0 to 1) and driving style of each racer.", "scripts/chair_race.gd RACERS", ["racer", "skill", "style"], rows)
	var bowlers := _kd("Outings", "BOWLERS")
	rows = []
	for b in bowlers:
		rows.append([b, bowlers[b].skill, bowlers[b].noise, bowlers[b].streak, bowlers[b].turkey, bowlers[b].gutter])
	_t("5.12 Bowling opponents", "Skill and temperament of each bowler (added to by the opp_skill dial).", "scripts/outings.gd BOWLERS", ["name", "skill", "noise", "streak", "turkey", "gutter"], rows)
	rows = []
	for pair in [["cornhole", "cornhole_game"], ["darts", "darts_game"]]:
		var tem := _kd(pair[1], "TEMPERS")
		for t in tem:
			rows.append([pair[0], t, tem[t]])
	_t("5.13 Cornhole and darts opponents", "Temperament presets of the opponents (accuracy, streaks, show-off).", "scripts/cornhole_game.gd, darts_game.gd TEMPERS", ["game", "temper", "values"], rows)
	var styles := _kd("paintball_game", "STYLES")
	rows = []
	for s in styles:
		rows.append([s, styles[s]])
	_t("5.14 Paintball styles", "The playing styles of the paintball teammates and opponents. Day, night and co-op variants share them.", "scripts/paintball_game.gd STYLES", ["style", "values"], rows)
	var rounds := _ka("Expo", "DEFAULT_ROUNDS")
	rows = []
	for r in rounds:
		rows.append([r.title, (r.sessions as Array).size()])
	_t("5.15 Expo trip rounds", "The three rounds of the trade expo trip and their sessions (more sessions come from the trip variety pool).", "scripts/conference.gd DEFAULT_ROUNDS", ["round", "sessions"], rows)
	_p("Extra expo sessions: %d (`trip_variety.gd MORE_SESSIONS`). Grill game: not data driven, see `scripts/grill_game.gd` (customer notes: %d). Printer game: see 3.12." % [_ka("trip_variety", "MORE_SESSIONS").size(), _ka("grill_game", "NOTES").size()])
	var mg := _kd("Difficulty", "MASTERY_GAMES")
	var mk: Array = _k("Difficulty", "MASTERY_KEYS")
	rows = []
	for g in mg:
		var keys := []
		for k in mk:
			if str(k).begins_with(str(g) + "."):
				keys.append(k)
		rows.append([g, mg[g], keys.size(), keys])
	_t("5.16 Mastery ramps", "Per-game mastery (0 to 1) grows with good plays and tightens the listed dials; the `Difficulty.TABLE` values are in 1.8.", "scripts/difficulty.gd MASTERY_GAMES / MASTERY_KEYS", ["dial prefix", "game key", "ramped dials", "dials"], rows)
	var counters := _ka("Career", "COUNTERS")
	rows = []
	for c in counters:
		rows.append([c[0], c[1], c[2], c[3]])
	_t("5.17 Career stats recorded", "Every counter the career screen records.", "scripts/career.gd COUNTERS", ["group", "label", "key", "format"], rows)


# ---- 6. progression ---------------------------------------------------------------------------------------
func _progression() -> void:
	_h1("Progression")
	var medals := _ka("Career", "DEFAULT_MEDALS")
	var rows := []
	for m in medals:
		var rules := []
		for r in m.rules:
			rules.append("%s %s %s" % [r[0], r[1], r[2]])
		rows.append([m.id, m.title, m.desc, "; ".join(rules)])
	_t("6.1 Career medals", "Every medal: its id, title, description and the counter rule that earns it.", "scripts/career.gd DEFAULT_MEDALS", ["id", "title", "what earns it", "rule (counter op value)"], rows)
	var unl := _ka("Career", "DEFAULT_UNLOCKS")
	rows = []
	for u in unl:
		rows.append([u.id, u.kind, u.title, u.medal, u.value])
	_t("6.2 Medal unlocks", "Cosmetic and option unlocks (wallpapers, desk items and so on) and the medal that grants each.", "scripts/career.gd DEFAULT_UNLOCKS", ["id", "kind", "title", "needs medal", "value"], rows)
	var mut := _kd("Mutators", "DEFAULT_MUTATORS")
	rows = []
	for m in mut:
		var d: Dictionary = mut[m]
		rows.append([m, d.name, d.kinds, d.duration, d.get("ticket_weight", ""), d.get("extra_chance", ""), (d.get("extra_problems", []) as Array).size()])
	_t("6.3 Mutators", "Temporary world changes (a bad week) that Free Play and Year 2 can switch on.", "scripts/mutators.gd DEFAULT_MUTATORS", ["id", "name", "campaigns", "duration", "ticket weight", "extra chance", "extra problems"], rows)
	var st := _kd("Mutators", "DEFAULT_STARTS")
	var so: Array = _k("Mutators", "START_ORDER")
	rows = []
	for s in so:
		rows.append([s, st[s].name, st[s].short, st[s].kinds])
	_t("6.4 Starts", "Run starts (how a new year opens).", "scripts/mutators.gd DEFAULT_STARTS", ["id", "name", "short", "campaigns"], rows)
	var paths := _kd("Build", "PATHS")
	var cost: Array = _k("Build", "COST")
	rows = []
	for p in paths:
		rows.append([p, paths[p].selectable, paths[p].stats])
	_t("6.5 Build paths and stats", "The point-buy character build: which campaigns have one and the stats it spends points on (level 0 to 5; cumulative cost %s)." % _s(cost), "scripts/build.gd PATHS / COST", ["campaign", "selectable", "stats"], rows)
	var pre := _kd("Build", "DEFAULT_PRESETS")
	rows = []
	for p in pre:
		for q in pre[p]:
			rows.append([p, q.id, q.name, (q.steps as Array).size(), q.quirks, q.text])
	_t("6.6 Build presets", "Ready-made builds: the order the points are spent in (`steps`) and the quirks they carry.", "scripts/build.gd DEFAULT_PRESETS", ["path", "id", "name", "steps", "quirks", "text"], rows)
	var cat := _ka("Shop", "CATALOG")
	rows = []
	for c in cat:
		rows.append([c.id, c.name, c.price, c.slot, c.fx, c.get("loud", false)])
	_t("6.7 Shop items", "Desk upgrades you can buy; `fx` are the gameplay effects and `loud` ones annoy coworkers.", "scripts/shop.gd CATALOG", ["id", "name", "price $", "slot", "effect", "loud"], rows)
	var dec := _ka("office_decor", "ITEMS")
	var rn := _kd("office_decor", "RULE_NAMES")
	rows = []
	for d in dec:
		rows.append([d.id, d.name, "%s >= %s" % [rn.get(d.rule[0], d.rule[0]), d.rule[1]]])
	_t("6.8 Office decor unlocks", "Items that appear in the office when a score reaches a threshold.", "scripts/office_decor.gd ITEMS", ["id", "name", "unlock rule"], rows)
	_p("Relationship levels: `Social.mood()` is a text scan of the value range -100 to 100: FRIEND at 60 and above, FRIENDLY at 25, NEUTRAL above -15, COLD above -45, HOSTILE below (not data driven: scripts/social.gd).")
	var xpat: Array = _k("Skills", "XP_AT")
	var sk := _kd("Skills", "NAMES")
	rows = []
	for i in xpat.size():
		rows.append([i + 1, xpat[i]])
	_t("6.9 Skill levels", "Experience needed for levels 1 to 5 in each of the %d skill areas (%s)." % [sk.size(), _s(sk.values())], "scripts/skills.gd XP_AT / NAMES", ["level", "XP needed"], rows)
	var ty := _kd("Projects", "DEFAULT_TYPES")
	rows = []
	for t in ty:
		rows.append([t, ty[t].label, ty[t].price, ty[t].hours, ty[t].weeks])
	_t("6.10 Owner projects", "Client projects the owner can sell (priced, with the hours and weeks they take).", "scripts/projects.gd DEFAULT_TYPES", ["id", "label", "price $", "hours", "weeks"], rows)
	var ex := _kd("Deals", "EXTRAS")
	rows = []
	for e in ex:
		rows.append([e, ex[e].label, ex[e].fee, ex[e].cost, ex[e].pts])
	_t("6.11 Deal extras", "Add-ons to a managed service contract (monthly fee, cost, points).", "scripts/deals.gd EXTRAS", ["id", "label", "fee", "cost", "points"], rows)
	var qs := _kd("SalesCampaign", "QUOTAS")
	rows = []
	for q in qs:
		rows.append([q, qs[q].label, qs[q].target])
	_t("6.12 Sales quotas", "The three quota choices of the sales campaign.", "scripts/sales_campaign.gd QUOTAS", ["id", "label", "target"], rows)
	var ty2 := _kd("SalesCampaign", "TYPES")
	rows = []
	for t in ty2:
		rows.append([t, ty2[t].label, (ty2[t].names as Array).size(), (ty2[t].pains as Array).size()])
	_t("6.13 Sales prospect types", "Kinds of prospect the pipeline draws, with the number of company names and pain points of each.", "scripts/sales_campaign.gd TYPES", ["id", "label", "names", "pains"], rows)


# ---- 7. rooms and scenes ----------------------------------------------------------------------------------
func _rooms() -> void:
	_h1("Rooms and scenes")
	var sc := _kd("world_data", "SCENES")
	var rows := []
	var seats_total := 0
	for s in _keys_sorted(sc):
		var d: Dictionary = sc[s]
		var links := []
		for l in d.get("links", []):
			links.append(l.to)
		var seats: Dictionary = d.get("seats", {})
		seats_total += seats.size()
		rows.append([s, d.get("W", ""), d.get("x0", ""), seats.size(), _count(d.get("spawns", {})), _count(d.get("uses", [])), links])
	_t("7.1 Every scene", "Each scene: width in pixels, left edge, seats, spawn points, usable objects, and the doors to other scenes.", "scripts/world_data.gd SCENES", ["scene", "width", "x0", "seats", "spawns", "uses", "doors to"], rows)
	_p("Scenes: %d. Seats in total: %d. Scene width runs from %d to %d pixels." % [sc.size(), seats_total, _min_w(sc), _max_w(sc)])
	var onsite := _kd("Onsite", "SITES")
	rows = []
	var objs := _kd("Onsite", "OBJECTS")
	for i in onsite:
		rows.append([clients_name(i), onsite[i].type, onsite[i].skin, objs.get(onsite[i].type, [])])
	_t("7.2 Client sites", "The sites you can visit (client index, type, look) and the objects you can use in each site type.", "scripts/onsite.gd SITES / OBJECTS", ["client", "type", "skin", "objects"], rows)
	var spots := _kd("Outings", "SPOTS")
	rows = []
	for s in spots:
		rows.append([s, (spots[s] as Array).size()])
	_t("7.3 Outing floor spots", "Standing spots for the crew in each outing room.", "scripts/outings.gd SPOTS", ["outing", "spots"], rows)


func clients_name(i: Variant) -> String:
	var c: Array = _k("Msp", "CLIENTS")
	return str(c[int(i)].name) if int(i) < c.size() else str(i)


func _min_w(sc: Dictionary) -> int:
	var m := 99999
	for s in sc:
		m = mini(m, int(sc[s].get("W", 99999)))
	return m


func _max_w(sc: Dictionary) -> int:
	var m := 0
	for s in sc:
		m = maxi(m, int(sc[s].get("W", 0)))
	return m


# ---- 8. controls and settings -----------------------------------------------------------------------------
func _controls() -> void:
	_h1("Controls and settings")
	var acts := _kd("Controls", "ACTIONS")
	var rows := []
	for a in acts:
		var keys := PackedStringArray()
		for k in acts[a][0]:
			keys.append(_key_name(int(k)))
		var pad := PackedStringArray()
		for b in acts[a][1]:
			pad.append(PAD_NAMES.get(int(b), str(b)))
		for ax in acts[a][2]:
			pad.append("%s%s" % [AXIS_NAMES.get(int(ax[0]), str(ax[0])), "+" if float(ax[1]) > 0 else "-"])
		rows.append([a, ", ".join(keys), ", ".join(pad)])
	_t("8.1 Input actions", "Every input action with its keyboard keys and pad buttons or axes (the remappable ones can be changed on the controls screen).", "scripts/controls.gd ACTIONS", ["action", "keyboard", "pad"], rows)
	var rem: Array = _k("Controls", "REMAPPABLE")
	var remp: Array = _k("Controls", "REMAPPABLE_PAD")
	_p("Remappable on keyboard: %d actions (%s). Remappable on pad: %d (%s)." % [rem.size(), _s(rem), remp.size(), _s(remp)])
	# settings rows: text scan of the pause menu _labels()
	var re := RegEx.new()
	re.compile("\"([A-Z][A-Z ]+?)(?::|\")")
	var seen := {}
	rows = []
	for line in _func_text("res://scripts/pause_menu.gd", "_labels").split("\n"):
		for m in re.search_all(line):
			var lbl := m.get_string(1).strip_edges()
			if m.get_string(0).ends_with("\"") and line.contains(" if "):
				continue  # a value inside an if-expression ("OFF" if muted else "ON"), not a row
			if lbl != "" and not seen.has(lbl):
				seen[lbl] = true
				rows.append([lbl, "pause_menu.gd _labels()"])
	_t("8.2 Settings and pause menu rows (text scan)", "The row labels of the pause menu and the SETTINGS screen, read from `_labels()`. Which rows appear depends on the mode (the day length, ticket pace and outfit rows show only in some modes).", "scripts/pause_menu.gd _labels()", ["row", "source function"], rows)
	var skeys := {}
	re.compile("set_value\\(\"(\\w+)\",\\s*\"(\\w+)\"")
	for f in ["game", "difficulty", "look", "msp", "sfx", "controls"]:
		var txt := _read("res://scripts/%s.gd" % f)
		if txt.find("settings_path") < 0:
			continue
		for m in re.search_all(txt):
			skeys["%s.%s" % [m.get_string(1), m.get_string(2)]] = f + ".gd"
	rows = []
	for k in _keys_sorted(skeys):
		rows.append([k, skeys[k]])
	_t("8.3 What the settings file saves (text scan)", "Every `section.key` written to the settings file by the scripts that use it (`user://mspsim_settings.cfg`).", "scripts/{game,difficulty,look,msp,sfx,controls}.gd set_value calls", ["section.key", "written by"], rows)


# ---- 9. tech ----------------------------------------------------------------------------------------------
func _tech() -> void:
	_h1("Technical facts")
	var fm := _kd("Game", "FORMATS")
	var order: Array = _k("Game", "ORDER")
	var rows := []
	for f in order:
		var d: Dictionary = fm[f]
		var sz: Vector2i = d.size
		rows.append([f, "%d x %d" % [sz.x, sz.y], d.scale, "%d x %d" % [sz.x * int(d.scale), sz.y * int(d.scale)], d.zoom, d.follow])
	_t("9.1 Screen formats", "The window shapes (the SHAPE setting): logical size, integer scale, resulting window, camera zoom, whether the camera follows.", "scripts/game.gd FORMATS / ORDER", ["format", "logical size", "scale", "window px", "zoom", "camera follows"], rows)
	var cfg := _read("godot/export_presets.cfg")
	rows = []
	var cur := ""
	for line in cfg.split("\n"):
		if line.begins_with("name="):
			cur = line.trim_prefix("name=").strip_edges().trim_prefix("\"").trim_suffix("\"")
		elif line.begins_with("platform=") and cur != "":
			rows.append([cur, line.trim_prefix("platform=").strip_edges().trim_prefix("\"").trim_suffix("\"")])
			cur = ""
	_t("9.2 Export presets", "The platforms the project exports to (read from the export presets file).", "godot/export_presets.cfg", ["preset", "platform"], rows)
	var n_scripts := 0
	var lines_scripts := 0
	var n_scenes := 0
	for f in _list_files("godot/scripts", ".gd"):
		n_scripts += 1
		lines_scripts += _read("res://scripts/" + f).count("\n")
	var n_tests := 0
	var lines_tests := 0
	for f in _list_files("godot/tests", ".gd"):
		n_tests += 1
		lines_tests += _read("res://tests/" + f).count("\n")
	n_scenes = _list_files("godot/scenes", ".tscn").size()
	var n_tools := _list_files("tools", ".py").size() + _list_files("tools", ".lua").size()
	var autoloads := 0
	for line in _read("res://project.godot").split("\n"):
		if line.contains("=\"*res://scripts/"):
			autoloads += 1
	rows = [
		["game scripts (godot/scripts/*.gd)", n_scripts, lines_scripts],
		["tests (godot/tests/*.gd, one test each)", n_tests, lines_tests],
		["scenes (godot/scenes/*.tscn)", n_scenes, ""],
		["autoloads", autoloads, ""],
		["tools (tools/*.py and *.lua)", n_tools, ""],
	]
	_t("9.3 Code size", "Counted from the file system when generated (this table changes whenever code is added).", "godot/scripts, godot/tests, godot/scenes, tools (file system)", ["what", "files", "lines"], rows)
	rows = []
	for d in _list_dirs("godot/assets"):
		var n := 0
		for sub in _list_files("godot/assets/" + d, ".png"):
			n += 1
		var subtotal := 0
		for sd in _list_dirs("godot/assets/" + d):
			subtotal += _list_files("godot/assets/%s/%s" % [d, sd], ".png").size()
		rows.append([d, n, subtotal])
	_t("9.4 Game art (Godot PNGs)", "Image files per asset folder, directly inside it and in its sub-folders.", "godot/assets/<folder>/*.png (file system)", ["folder", "PNGs", "PNGs in sub-folders"], rows)
	rows = [
		["animation frames per character", int(_k("Look", "FRAMES")), "scripts/look.gd FRAMES"],
		["head gear frames", int(_k("head_gear", "FRAMES")), "scripts/head_gear.gd FRAMES"],
		["clothes gear frames", int(_k("clothes_gear", "FRAMES")), "scripts/clothes_gear.gd FRAMES"],
	]
	_t("9.5 Character sheet frames", "Frames per character sheet (idle, walk, run, jump, seated life poses, toss, couch and so on, all tagged).", "scripts/look.gd, head_gear.gd, clothes_gear.gd", ["sheet", "frames", "source"], rows)
	var story := _list_files("godot/story", ".txt").size() + _list_files("godot/story", ".md").size()
	_p("Test files: %d. Story files: %d. The shared `Strings` autoload holds the patchable player-facing text." % [n_tests, story])
