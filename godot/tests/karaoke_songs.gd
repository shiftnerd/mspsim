extends SceneTree
# The karaoke song table: every song at every tier makes a fair chart (all four lanes, notes further
# apart than the good window), perfect play is 3 stars, no input is 0 stars, the same seed gives the
# same chart, doubles show up on hard and in the rap, the crowd meter moves, songs unlock.
# Headless: `Godot --headless --fixed-fps 60 --path godot -s res://tests/karaoke_songs.gd`

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _lanes(notes: Array) -> Array:
	var out := []
	for n in notes:
		out.append([n.lane, n.time])
	return out


# the smallest score that reaches this share of the points
func _min_score(cut: float, total: int) -> int:
	for s in total + 1:
		if float(s) / float(total) >= cut:
			return s
	return total


func _play(o: Node, song_id: String, perfect: bool) -> int:
	o.start("karaoke")
	o.begin_play(song_id)
	if perfect:
		for n in o.g.notes:
			o.g.t = n.time
			o.kara_hit(int(n.lane))
	o.g.t = 1000.0
	o.tick(0.1)
	var result: int = o.stars
	o.press(KEY_ENTER)
	return result


func _init() -> void:
	await process_frame
	var o := root.get_node("Outings")
	var d := root.get_node("Difficulty")
	var c := root.get_node("Campaign")
	var game := root.get_node("Game")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false
	o.enabled = true
	c.new_game("free")
	root.get_node("World").time_scale = 1.0
	o.best["karaoke"] = 3  # opens the rap for this test (see the unlock checks below)

	_check(o.SONGS.size() == 4, "four songs")
	var titles := []
	for song in o.SONGS:
		titles.append(song.title)
	_check(
		titles == ["WOBBLE WOBBLE POP", "DIRT ROAD FRIDAY", "NEON GYM CLASS", "FAST RAP HOT MESS"],
		"the four invented titles"
	)

	for tier in d.TIERS:
		d.set_tier(tier)
		for song in o.SONGS:
			var tag := "%s / %s" % [song.id, tier]
			d.seed_run(900)
			var chart: Dictionary = o.kara_chart(song, tier, d.rng("karaoke"))
			var lanes := {}
			var times := []
			for n in chart.notes:
				lanes[int(n.lane)] = true
				if not times.has(float(n.time)):
					times.append(float(n.time))
			_check(lanes.size() == 4, "all four lanes appear: " + tag)
			var good: float = d.at("karaoke.good", tier) * float(song.win)
			var min_gap := 99.0
			for i in range(1, times.size()):
				min_gap = minf(min_gap, float(times[i]) - float(times[i - 1]))
			_check(
				min_gap > good,
				"notes stay apart (%.2f s vs the %.2f s window): %s" % [min_gap, good, tag]
			)
			_check(
				is_equal_approx(
					float(chart.span),
					(
						float(times[times.size() - 1])
						+ (
							float(chart.gap)
							* float(song.rhythm[(int(song.len) - 1) % song.rhythm.size()])
						)
					)
				),
				"the song length follows the chart: " + tag
			)
			# the same seed, the same chart; another seed, another one
			d.seed_run(900)
			var again: Dictionary = o.kara_chart(song, tier, d.rng("karaoke"))
			_check(
				_lanes(again.notes) == _lanes(chart.notes),
				"the same seed gives the same chart: " + tag
			)
			d.seed_run(901)
			var other: Dictionary = o.kara_chart(song, tier, d.rng("karaoke"))
			_check(
				_lanes(other.notes) != _lanes(chart.notes),
				"another seed gives another chart: " + tag
			)
			# playing it through the game
			d.seed_run(902)
			_check(_play(o, str(song.id), true) == 3, "perfect play is 3 stars: " + tag)
			_check(o.g.perfect == o.g.notes.size(), "every note perfect: " + tag)
			_check(_play(o, str(song.id), false) == 0, "no input is 0 stars: " + tag)

	# the song is what the game reads, not constants
	d.set_tier("normal")
	d.seed_run(3)
	o.start("karaoke")
	o.begin_play("dirt")
	var dirt: Dictionary = o.song_by_id("dirt")
	_check(
		(
			o.g.len == dirt.len
			and is_equal_approx(float(o.g.gap), float(dirt.gap))
			and o.g.speed == dirt.speed
		),
		"g.len, g.gap and g.speed come from the song"
	)
	_check(
		is_equal_approx(float(o.g.good_win), 0.3 * float(dirt.win)),
		"the hit windows scale with the song"
	)
	_check(
		o._song_secs() == o.g.span and o.g.span > 1.5 + 0.9 * 19.0, "the song length is the chart's"
	)
	o._finish(-1)
	o.press(KEY_ENTER)

	# doubles: none on easy, some on hard, the rap has them on normal
	var seen := {}
	for t in d.TIERS:
		var count := 0
		for s in 20:
			d.set_tier(t)
			var rap: Dictionary = o.kara_chart(o.song_by_id("rap"), t, d.rng_for("test", s))
			var times := {}
			for n in rap.notes:
				times[float(n.time)] = int(times.get(float(n.time), 0)) + 1
			for k in times:
				if times[k] > 1:
					count += 1
					_check(times[k] == 2, "a double is exactly two notes")
		seen[t] = count
	_check(
		seen.easy == 0 and seen.normal > 0 and seen.hard > seen.normal,
		"doubles: rap %s" % str(seen)
	)
	var pop_hard := 0
	for s in 20:
		var pop: Dictionary = o.kara_chart(o.song_by_id("wobble"), "hard", d.rng_for("test", s))
		pop_hard += pop.notes.size() - 24
	_check(pop_hard == 0, "the pop song has no doubles even on hard")
	var neon_hard := 0
	for s in 20:
		var neon: Dictionary = o.kara_chart(o.song_by_id("neon"), "hard", d.rng_for("test", s))
		neon_hard += neon.notes.size() - 26
	_check(neon_hard > 0, "the 80s song has doubles on hard")
	d.set_tier("normal")

	# star cut-offs belong to the song
	for song in o.SONGS:
		d.seed_run(5)
		o.start("karaoke")
		o.begin_play(str(song.id))
		var total: int = o.g.notes.size() * 2
		var cuts: Array = song.cuts
		var got := []
		for step in 3:
			var need := _min_score(float(cuts[step]), total)
			o.g.score = need - 1
			o.g.chorus = false
			o.phase = "play"
			o._kara_end()
			got.append(o.stars)
			o.phase = "play"
			o.g.score = need
			o._kara_end()
			got.append(o.stars)
		_check(
			got == [2, 3, 1, 2, 0, 1],
			"%s: stars change exactly at its cut-offs %s" % [song.id, str(got)]
		)
		o._finish(-1)
		o.press(KEY_ENTER)
	_check(o.song_by_id("rap").cuts != o.song_by_id("wobble").cuts, "the rap has its own cut-offs")

	# the crowd
	d.seed_run(8)
	o.start("karaoke")
	o.begin_play("wobble")
	var mood0: float = o.g.mood
	var n0: Dictionary = o.g.notes[0]
	o.g.t = n0.time
	o.kara_hit(int(n0.lane))
	_check(o.g.mood > mood0, "a perfect lifts the crowd")
	var mood1: float = o.g.mood
	o.kara_hit((int(n0.lane) + 1) % 4)
	_check(o.g.mood < mood1, "a wrong arrow cools it")
	o.g.t = n0.time + 5.0
	o.tick(0.0)
	_check(o.g.mood < mood1, "misses cool it")
	o.tick(120.0)
	_check(
		o.phase == "result" and o.stars == 0 and str(o.g.msg).contains("LAUGH"),
		"an empty room ends the song with a laugh, not a scolding"
	)
	_check(o.g.miss < o.g.notes.size(), "the song stopped early")
	o.press(KEY_ENTER)
	o.start("karaoke")
	o.begin_play("wobble")
	for n in o.g.notes:
		o.g.t = n.time
		o.kara_hit(int(n.lane))
	_check(o.g.chorus and o.g.mood == 100.0, "a full room sings the last chorus")
	o.g.t = 100.0
	o.tick(0.1)
	o.press(KEY_ENTER)

	# unlocking and the default song
	o.reset()
	c.new_game("tech")
	_check(not o.song_unlocked("rap") and o.song_unlocked("neon"), "the rap starts locked")
	_check(o.default_song() == "wobble", "the first song is the default")
	o.song_best["wobble"] = 3
	_check(o.default_song() == "dirt", "then the first one you have not three-starred")
	_check(o.song_unlocked("rap"), "a 3 star night opens the rap")
	var opts: Array = o.song_options()
	_check(
		opts.size() == 4 and opts[0].id == "dirt" and opts[0].label.contains("DIRT ROAD"),
		"the card lists the default first"
	)
	o.song_best = {}
	var locked: Array = o.song_options()
	_check(
		locked[3].id == "rap" and not bool(locked[3].get("enabled", true)),
		"a locked song is greyed out last"
	)
	# the record is kept with the save
	o._open("karaoke", false)
	o.begin_play("neon")
	o.g.score = o.g.notes.size() * 2
	o._kara_end()
	_check(o.song_best.get("neon", 0) == 3, "the best stars per song are recorded")
	var data: Dictionary = o.to_dict()
	o.reset()
	o.from_dict(data)
	_check(o.song_best.get("neon", 0) == 3, "and saved")
	o.press(KEY_ENTER)

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
