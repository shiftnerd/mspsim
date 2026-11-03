extends SceneTree
# Content validators for the outing tables (songs, escape recipes and hints, dinner topics and
# people, budgets): every row has the right shape, text fits the 3x5 font and the screens, family is
# never a dinner trap, and a deny-list keeps real bands, songs, shows and brands out.
# Headless: `Godot --headless --fixed-fps 60 --path godot -s res://tests/content.gd`

const PixelFont := preload("res://scripts/pixelfont.gd")
# real bands, artists, songs, shows, teams and brands (lower case; spaces mean whole words)
const DENY := [
	"beatles",
	"rolling stones",
	"madonna",
	"michael jackson",
	"springsteen",
	"elvis",
	"queen ",
	" abba",
	" u2 ",
	"nirvana",
	"metallica",
	"taylor swift",
	"beyonce",
	"rihanna",
	"eminem",
	"drake ",
	"pharrell",
	"daft punk",
	"lady gaga",
	"katy perry",
	"miley",
	"justin ",
	"bieber",
	"macklemore",
	"lorde",
	"gangnam",
	"harlem shake",
	"blurred lines",
	"thrift shop",
	"royals",
	"uptown funk",
	"let it go",
	"call me maybe",
	"wrecking ball",
	"timber",
	"get lucky",
	"dark horse",
	"party rock",
	"sweet caroline",
	"bon jovi",
	"journey",
	"don't stop",
	"footloose",
	"flashdance",
	"thriller",
	"wham",
	"duran",
	"billy joel",
	"johnny cash",
	"dolly",
	"garth",
	"shania",
	"game of thrones",
	"breaking bad",
	"walking dead",
	"star wars",
	"marvel",
	"disney",
	"pixar",
	"harry potter",
	"frozen",
	"seinfeld",
	"super bowl",
	" nfl",
	" nba",
	" mlb",
	"espn",
	"coca",
	"pepsi",
	"mcdonald",
	"starbucks",
	"nike",
	"apple",
	"google",
	"samsung",
	"nintendo",
	"playstation",
	"xbox",
	"netflix",
	"hulu",
	"amazon",
	"ikea",
	"walmart",
	"budweiser",
	"heineken",
	"toyota",
	"facebook",
	"twitter",
	"spotify",
	"youtube",
	"iphone",
	"android",
]
const FAMILY := ["KIDS AND PETS", "A NEW BABY", "MOVING HOUSE"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


# every letter has a glyph in the 3x5 font (an unknown one would draw as a question mark)
func _drawable(text: String) -> bool:
	for ch in text.to_upper():
		if not PixelFont.GLYPHS.has(ch):
			return false
	return true


func _clean(text: String) -> String:
	var low := " " + text.to_lower() + " "
	for word in DENY:
		if low.contains(str(word)):
			return str(word)
	return ""


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var social := root.get_node("Social")
	var strings := root.get_node("Strings")

	# ---- the deny-list itself works
	_check(_clean("PLAY SOME BEATLES") != "", "the deny-list catches a real band")
	_check(_clean("FOOTLOOSE TONIGHT") != "", "...and a real song")
	_check(_clean("WOBBLE WOBBLE POP") == "", "...and lets an invented title through")

	# ---- songs
	var ids := {}
	var all_text: Array = []
	var patterns := ["mix", "sweep", "sync", "burst"]
	for song in o.SONGS:
		var tag := str(song.get("id", "?"))
		for key in [
			"id",
			"title",
			"artist",
			"genre",
			"len",
			"gap",
			"rhythm",
			"pattern",
			"doubles",
			"win",
			"cuts",
			"speed",
			"unlock",
			"lines"
		]:
			_check(song.has(key), "%s has %s" % [tag, key])
		ids[song.id] = true
		_check(int(song.len) >= 16 and int(song.len) <= 40, "%s: %d notes" % [tag, song.len])
		_check(patterns.has(song.pattern), "%s: a known lane pattern" % tag)
		_check(song.doubles.size() == 3, "%s: doubles for easy / normal / hard" % tag)
		for chance in song.doubles:
			_check(
				float(chance) >= 0.0 and float(chance) <= 0.4,
				"%s: double chance %.2f" % [tag, chance]
			)
		_check(float(song.doubles[0]) == 0.0, "%s: no doubles on easy" % tag)
		_check(
			float(song.win) >= 0.7 and float(song.win) <= 1.3,
			"%s: hit window scale %.2f" % [tag, song.win]
		)
		_check(
			(
				song.cuts.size() == 3
				and float(song.cuts[0]) > float(song.cuts[1])
				and float(song.cuts[1]) > float(song.cuts[2])
				and float(song.cuts[2]) > 0.0
				and float(song.cuts[0]) <= 0.8
			),
			"%s: star cut-offs %s fall and stay reachable" % [tag, str(song.cuts)]
		)
		_check(float(song.speed) >= 35.0 and float(song.speed) <= 70.0, "%s: scroll speed" % tag)
		_check(
			song.lines.size() >= 6 and song.lines.size() <= 8,
			"%s: %d lyric lines" % [tag, song.lines.size()]
		)
		var rhythm_ok: bool = song.rhythm.size() >= 1
		for m in song.rhythm:
			rhythm_ok = rhythm_ok and float(m) >= 0.5 and float(m) <= 2.0
		_check(rhythm_ok, "%s: rhythm multipliers" % tag)
		all_text.append_array([song.title, song.artist, song.genre])
		_check(
			str(song.title).length() <= 21 and _drawable(str(song.title)),
			"%s: the title fits the lyrics screen" % tag
		)
		for line in song.lines:
			all_text.append(line)
			_check(str(line).length() <= 21, "%s: '%s' fits the screen" % [tag, line])
			_check(
				_drawable(str(line)) and str(line).length() >= 15,
				"%s: '%s' can be drawn and edited" % [tag, line]
			)
		# the chart works at every tier: all lanes, notes further apart than the good window
		for tier in d.TIERS:
			var lanes := {}
			var times := []
			for s in 5:
				var chart: Dictionary = o.kara_chart(song, tier, d.rng_for("content", s))
				times = []
				for n in chart.notes:
					lanes[int(n.lane)] = true
					if not times.has(float(n.time)):
						times.append(float(n.time))
				var gap := 99.0
				for i in range(1, times.size()):
					gap = minf(gap, float(times[i]) - float(times[i - 1]))
				if gap <= float(d.at("karaoke.good", tier)) * float(song.win):
					_check(false, "%s / %s: notes %.2f s apart" % [tag, tier, gap])
			_check(lanes.size() == 4, "%s / %s: all four lanes" % [tag, tier])
	_check(ids.size() == o.SONGS.size(), "song ids are unique")

	# ---- escape recipes, clue text and hints
	var zones: Array = o.CLUE_ZONES
	_check(zones.size() == 4 and o.CLUE_KINDS.size() == 4, "four clue zones")
	_check(o.RECIPES.keys().size() == zones.size(), "recipes for every zone")
	var rng: RandomNumberGenerator = d.rng_for("content", 99)
	for zone in zones:
		for recipe in o.RECIPES[zone]:
			var fitted := 0
			for digit in range(1, 10):
				if not o.recipe_fits(str(recipe), digit):
					continue
				fitted += 1
				var clue: Dictionary = o.make_clue(str(zone), str(recipe), digit, rng)
				if o.clue_answer(clue) != digit or str(clue.show) == "" or str(clue.say) == "":
					_check(false, "%s / %s / %d: %s" % [zone, recipe, digit, str(clue)])
				for part in str(clue.show).split("|"):
					if not _drawable(str(part)):
						_check(false, "%s / %s: '%s' cannot be drawn" % [zone, recipe, part])
				all_text.append(clue.say)
			_check(fitted >= 4, "%s / %s fits %d digits" % [zone, recipe, fitted])
			_check(o.RECIPE_TIPS.has(recipe), "%s has a hint" % recipe)
	_check(o.RECIPE_TIPS.has("dial") and o.RECIPE_TIPS.has("nodial"), "the lock hints exist")
	for tip in o.RECIPE_TIPS.values():
		all_text.append(tip)
	_check(
		o.ROMAN.size() == 10 and o.ROMAN[4] == "IV" and o.ROMAN[9] == "IX", "roman numerals 1 to 9"
	)
	_check(o.PRODUCTS.size() >= 3, "products need a pair that really multiplies")
	for digit in o.PRODUCTS:
		_check(
			int(o.PRODUCTS[digit][0]) * int(o.PRODUCTS[digit][1]) == int(digit),
			"%d = %s" % [digit, str(o.PRODUCTS[digit])]
		)
	for who in social.PEOPLE:
		_check(o.FRIEND_HINTS.has(who), "%s has hints" % who)
	for who in o.FRIEND_HINTS:
		for zone in zones + ["keypad"]:
			var line := str(o.FRIEND_HINTS[who].get(zone, ""))
			all_text.append(line)
			_check(
				line != "" and line.length() <= 80 and _drawable(line),
				"%s / %s: '%s'" % [who, zone, line]
			)
	for who in o.SPECIALTY:
		_check(
			(
				o.FRIEND_HINTS.has(who)
				and (zones.has(o.SPECIALTY[who]) or o.SPECIALTY[who] == "keypad")
			),
			"%s's specialty is a real zone" % who
		)
	_check(
		(
			o.SPECIALTY.get("Alan") == "board"
			and o.SPECIALTY.get("Dan") == "clock"
			and o.SPECIALTY.get("Garrison") == "keypad"
			and o.SPECIALTY.get("Maya") == "plaque"
		),
		"Alan the board, Dan the wiring, Garrison the lock, Maya the plaque"
	)
	_check(o.HERRINGS.size() >= 3, "red herrings for the spare zone")
	for line in o.HERRINGS:
		all_text.append(line)
		_check(_drawable(str(line)) and str(line).length() <= 80, "herring '%s'" % line)
	for tier in d.TIERS:
		_check(
			d.at("escape.digits", tier) in [3, 4] and d.at("escape.dial", tier) in [0, 1],
			"%s: digits and dial" % tier
		)

	# ---- dinner topics, people, moods, budgets
	var topic_ids: Array = o.topic_ids()
	var seen := {}
	var tags := ["light", "deep", "touchy"]
	for t in o.TOPICS:
		_check(tags.has(t.tag), "%s: tag %s" % [t.id, t.tag])
		_check(not seen.has(t.id), "%s is listed once" % t.id)
		seen[t.id] = true
		all_text.append(t.id)
		_check(str(t.id).length() <= 19 and _drawable(str(t.id)), "%s fits the topic list" % t.id)
	_check(topic_ids.size() >= 16, "%d topics" % topic_ids.size())
	var counts := {"light": 0, "deep": 0, "touchy": 0}
	for t in o.TOPICS:
		counts[t.tag] += 1
	_check(
		counts.light >= 6 and counts.deep >= 2 and counts.touchy >= 3,
		"every tag has topics %s" % str(counts)
	)
	for t in FAMILY:
		_check(
			o.PROTECTED_TOPICS.has(t) and topic_ids.has(t), "%s is a family topic nobody dreads" % t
		)
	for who in o.PEOPLE:
		var row: Dictionary = o.PEOPLE[who]
		var mixed := []
		mixed.append_array(row.loves)
		mixed.append_array(row.hates)
		var unique := {}
		for t in mixed:
			unique[t] = true
		_check(
			row.loves.size() == 3 and row.hates.size() >= 1 and row.hates.size() <= 2,
			"%s: 3 loves, 1-2 dislikes" % who
		)
		_check(unique.size() == mixed.size(), "%s: no topic both loved and dreaded" % who)
		for t in mixed:
			_check(topic_ids.has(t), "%s: '%s' is a topic" % [who, t])
		for t in row.hates:
			_check(not o.PROTECTED_TOPICS.has(t), "%s does not dread %s" % [who, t])
	for who in o.DINERS:
		_check(o.PEOPLE.has(who), "%s (at the table) has a personality" % who)
	# the shuffled tastes keep those rules for any seed
	var shuffled_ok := true
	for s in 50:
		d.seed_run(500 + s)
		o.reset()
		for who in o.PEOPLE:
			var tt: Dictionary = o.taste(who)
			for h in tt.hates:
				shuffled_ok = shuffled_ok and not o.PROTECTED_TOPICS.has(h) and not tt.loves.has(h)
			shuffled_ok = shuffled_ok and tt.loves.size() == 3
	_check(shuffled_ok, "50 shuffled sets of tastes: family is never dreaded, loves stay three")
	for id in o.DINNER_MOODS:
		var m: Dictionary = o.DINNER_MOODS[id]
		_check(
			(
				int(m.shift) >= -1
				and int(m.shift) <= 1
				and _drawable(str(m.face))
				and str(m.face).length() <= 3
			),
			"mood %s" % id
		)
	var shifts := {}
	for id in o.DINNER_MOODS:
		shifts[int(o.DINNER_MOODS[id].shift)] = true
	_check(shifts.size() == 3, "moods lift, sink and leave alone")
	_check(
		(
			o.BUDGETS.cheap.cost < o.BUDGETS.normal.cost
			and o.BUDGETS.normal.cost < o.BUDGETS.fancy.cost
			and o.BUDGETS.normal.cost == o.GAMES.dinner.cost
			and o.BUDGETS.cheap.mood < 0
			and o.BUDGETS.normal.mood == 0
			and o.BUDGETS.fancy.mood > 0
		),
		"cheap < normal < fancy, and normal is today's price"
	)
	for id in o.BUDGETS:
		all_text.append(o.BUDGETS[id].label)
		_check(_drawable(str(o.BUDGETS[id].label)), "budget %s can be drawn" % id)

	# ---- every text in the tables: no real names, nothing from after 2014
	var bad := 0
	for text in all_text:
		var hit := _clean(str(text))
		if hit != "":
			bad += 1
			print("FAIL '%s' contains '%s'" % [text, hit])
		var low := " " + str(text).to_lower() + " "
		for word in strings.BANNED:
			if low.contains(str(word)):
				bad += 1
				print("FAIL '%s' is not 2013-14 (%s)" % [text, word])
	_check(bad == 0, "%d texts: no real names, no modern tech" % all_text.size())

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
