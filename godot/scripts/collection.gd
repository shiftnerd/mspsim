extends RefCounted
# gdlint:disable=max-line-length
# R16 (cozy design review): the COLLECTION pages of the career screen and the cast RELATIONSHIP LEVELS. Static, no state:
# everything shown comes from the Career counters (lifetime) plus, while a campaign runs, this run's numbers.
#
# Collection: the cast you have met and your level with each, the karaoke songs you have sung, the escape room clue
# recipes you have seen, the printer models you have beaten, the medal count and the decor of this run's office.
# Career keys: met.<name> / cast_met, rel.<name> (best level), song.<id> / songs_sung, recipe.<id> / recipes_seen
# (Career.note_outing fills the last two), pr.<model> (PrinterGame).
#
# Relationship levels: Social.value(who) (-100..100, 0 at the start) read as a level 0-4 (LEVELS). Social.change calls
# note_change(): the first time a run reaches a level with somebody you get a toast with their line, the career keeps
# the best level, and from FRIEND up they leave a coffee on your desk (+COFFEE energy, the tech campaign's Shift only).
# The levels this run has reached are Story.flags["rel_lv"] (saved with the campaign), so a level is announced once.

const UiStyle := preload("res://scripts/ui_style.gd")
const OfficeDecor := preload("res://scripts/office_decor.gd")
const COFFEE := 3.0  # energy for the coffee at levels 3 and 4
# level -> the Social value it starts at, its name, the line they say and the perk as shown on the page
const LEVELS := [
	{"at": -999, "name": "NEW FACE", "line": "", "perk": ""},
	{"at": 10, "name": "COWORKER", "line": "YOU ARE ALRIGHT. I WILL STOP PRETENDING TO BE ON A CALL WHEN YOU WALK UP.", "perk": "A NOD IN THE HALLWAY"},
	{"at": 25, "name": "LUNCH BUDDY", "line": "LUNCH? I AM BUYING THE FIRST ONE. AFTER THAT WE KEEP SCORE.", "perk": "A SEAT AT LUNCH"},
	{"at": 45, "name": "FRIEND", "line": "I LEFT A COFFEE ON YOUR DESK. DO NOT MAKE IT WEIRD.", "perk": "A COFFEE ON YOUR DESK"},
	{"at": 70, "name": "WORK FAMILY", "line": "IF YOU EVER LEAVE, TELL ME FIRST. I WILL NEED TIME TO UPDATE MY RESUME TOO.", "perk": "ANOTHER COFFEE, AND THEY MEAN IT"},
]
const PRINTERS := [["laser", "LASER"], ["inkjet", "INKJET"], ["plotter", "PLOTTER"], ["mfp", "COPIER"], ["receipt", "RECEIPT"], ["dot", "DOT MATRIX"], ["line", "THE LINE PRINTER"]]


# ---- relationship levels ------------------------------------------------------------------------------
static func level_of(value: int) -> int:
	var lv := 0
	for i in LEVELS.size():
		if value >= int(LEVELS[i].at):
			lv = i
	return lv


static func level_name(lv: int) -> String:
	return str(LEVELS[clampi(lv, 0, LEVELS.size() - 1)].name)


# this run's level with somebody (0 outside a campaign)
static func level(who: String) -> int:
	return level_of(Social.value(who)) if Campaign.active else 0


# the best level ever reached with somebody, this run included
static func best_level(who: String) -> int:
	return maxi(Career.value("rel." + who), level(who))


# the Social value still missing for the next level (0 at the top)
static func to_next(who: String) -> int:
	var lv := level(who)
	if lv >= LEVELS.size() - 1:
		return 0
	return maxi(0, int(LEVELS[lv + 1].at) - Social.value(who))


# Social.change calls this after every move; returns the level newly reached (0 = none)
static func note_change(who: String, _before: int, after: int) -> int:
	if not Campaign.active:
		return 0
	var lv := level_of(after)
	var seen: Dictionary = Story.flags.get("rel_lv", {})
	if lv <= int(seen.get(who, 0)):
		return 0
	seen[who] = lv
	Story.flags["rel_lv"] = seen
	Career.note_first("met", who, "cast_met")
	Career.best("rel." + who, lv)
	var perk := ""
	if lv >= 3 and Shift.active():
		Shift.add_energy(COFFEE)
		perk = " +%d ENERGY." % int(COFFEE)
	Hints.toast("%s, LEVEL %d: %s. \"%s\"%s" % [who.to_upper(), lv, level_name(lv), str(LEVELS[lv].line), perk], 7.0)
	return lv


# ---- the collection pages -------------------------------------------------------------------------------
static func _seen(key: String) -> bool:
	return Career.value(key) > 0


# every row of the collection: {head} or {label, value, on}
static func items() -> Array:
	var out := []
	var met := 0
	var cast := []
	for who in Social.ALL:
		var known: bool = _seen("met." + who) or best_level(who) > 0
		met += 1 if known else 0
		var lv := best_level(who)
		cast.append({"label": str(who).to_upper(), "value": ("LV %d %s" % [lv, level_name(lv)]) if known else "NOT MET", "on": known})
	out.append({"head": "THE CAST %d/%d" % [met, Social.ALL.size()]})
	out.append_array(cast)
	var sung := 0
	var songs := []
	for s in Outings.SONGS:
		var got := _seen("song." + str(s.id))
		sung += 1 if got else 0
		songs.append({"label": str(s.title), "value": "SUNG" if got else "-", "on": got})
	out.append({"head": "KARAOKE SONGS %d/%d" % [sung, Outings.SONGS.size()]})
	out.append_array(songs)
	var seen_n := 0
	var recipes := []
	for zone in Outings.CLUE_ZONES:
		for rc in Outings.RECIPES[zone]:
			var got := _seen("recipe." + str(rc))
			seen_n += 1 if got else 0
			recipes.append({"label": "%s: %s" % [str(zone).to_upper(), str(rc).to_upper()], "value": "SEEN" if got else "-", "on": got})
	out.append({"head": "ESCAPE CLUES %d/%d" % [seen_n, recipes.size()]})
	out.append_array(recipes)
	var beaten := 0
	var printers := []
	for p in PRINTERS:
		var n := Career.value("pr." + str(p[0]))
		beaten += 1 if n > 0 else 0
		printers.append({"label": str(p[1]), "value": ("%d WIN%s" % [n, "" if n == 1 else "S"]) if n > 0 else "-", "on": n > 0})
	out.append({"head": "PRINTERS BEATEN %d/%d" % [beaten, PRINTERS.size()]})
	out.append_array(printers)
	out.append({"head": "MEDALS"})
	out.append({"label": "EARNED", "value": "%d/%d" % [Career.earned_count(), Career.MEDALS.size()], "on": Career.earned_count() > 0})
	out.append({"head": "THE OFFICE (THIS RUN)"})
	for it in OfficeDecor.ITEMS:
		var here: bool = OfficeDecor.has(str(it.id))
		out.append({"label": str(it.name), "value": "HERE" if here else OfficeDecor.rule_text(it), "on": here})
	return out


# the rows cut into pages of `cap` rows; a section title never sits alone at the bottom of a page
static func pages(cap: int) -> Array:
	var out := []
	var all := items()
	var i := 0
	while i < all.size():
		var chunk: Array = all.slice(i, i + maxi(2, cap))
		if chunk.size() == maxi(2, cap) and chunk.back().has("head"):
			chunk.pop_back()
		i += chunk.size()
		out.append({"title": "COLLECTION", "rows": chunk})
	return out


# drawn by the career screen inside its panel body, in columns of `colw`
static func draw(canvas: CanvasItem, rows: Array, body: Rect2, colw: float, gap: float, row_h: float) -> void:
	var per_col := maxi(1, int(body.size.y / row_h))
	var chars := int(colw / 4.0)
	for i in rows.size():
		var it: Dictionary = rows[i]
		var cx := body.position.x + float(i / per_col) * (colw + gap)
		var cy := body.position.y + float(i % per_col) * row_h
		if it.has("head"):
			UiStyle.text(canvas, str(it.head), cx, cy, UiStyle.HEAD)
			canvas.draw_rect(Rect2(cx, cy + 6.0, colw, 1.0), UiStyle.SOFT)
			continue
		var value := str(it.value)
		var label := str(it.label).substr(0, maxi(4, chars - value.length() - 1))
		var on: bool = bool(it.on)
		UiStyle.text(canvas, label, cx, cy, UiStyle.INK if on else UiStyle.MUTED)
		UiStyle.right(canvas, value, cx + colw, cy, UiStyle.GOLD.darkened(0.35) if on else UiStyle.MUTED)
