extends SceneTree
# Sfx: every sound and both songs synthesise a sane stream, events record their ids, mute silences them, the
# settings are saved and loaded. Headless (no audio device is touched).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/sfx.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var s := root.get_node("Sfx")
	s.silent = true
	s.settings_path = "user://test_%d_sfx_settings.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(s.settings_path)
	s.muted = false
	s.volume = 0.7
	root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Campaign").new_game("tech")

	# ---- every sound generates
	var bad := []
	for id: String in s.ids():
		var st: AudioStreamWAV = s.stream(id)
		if (
			st == null
			or st.data.size() < 200
			or st.get_length() <= 0.0
			or st.get_length() > s.MAX_SECS
		):
			bad.append(id)
	_check(bad.is_empty(), "every sound makes a non-empty stream of sane length " + str(bad))
	_check(s.ids().size() >= 28, "the sound list is complete (%d sounds)" % s.ids().size())
	var needed := [
		"ui_open",
		"ui_pick",
		"ui_tick",
		"ui_error",
		"phone_ring",
		"headset",
		"ticket",
		"sla_breach",
		"ticket_closed",
		"text",
		"mail",
		"bell",
		"dart_fire",
		"dart_hit",
		"squeak",
		"clunk",
		"bowl_roll",
		"bowl_strike",
		"kara_perfect",
		"kara_good",
		"printer_jam",
		"coffee"
	]
	for g in ["s", "a", "b", "c", "d"]:
		needed.append("grade_" + g)
	var missing := []
	for id in needed:
		if not s.ids().has(id):
			missing.append(id)
	_check(missing.is_empty(), "every requested sound exists " + str(missing))
	var st1: AudioStreamWAV = s.stream("bell")
	_check(st1 == s.stream("bell"), "a sound is made once and cached")
	_check(
		st1.mix_rate == s.RATE and st1.format == AudioStreamWAV.FORMAT_16_BITS,
		"16 bit mono at the sfx rate"
	)
	var peak := 0
	for i in range(0, st1.data.size() - 1, 2):
		peak = maxi(peak, absi(st1.data.decode_s16(i)))
	_check(
		peak > 2000 and peak <= 32767,
		"the bell is audible and not past full scale (peak %d)" % peak
	)
	_check(s.stream("nope") == null, "an unknown id has no stream")

	# ---- songs
	for id in ["title", "day"]:
		var m: AudioStreamWAV = s.music_stream(id)
		_check(
			(
				m != null
				and m.loop_mode == AudioStreamWAV.LOOP_FORWARD
				and m.get_length() > 8.0
				and m.get_length() < 30.0
			),
			(
				"%s loop is a looping stream of 8 to 30 s (%.1f s)"
				% [id, m.get_length() if m != null else 0.0]
			)
		)
	_check(s.music_stream("title").data != s.music_stream("day").data, "title and day loops differ")
	var again: AudioStreamWAV = s._wav(
		s._render(s._song_layers(s.SONGS.title), s.MUSIC_RATE, 28.0, 2013), s.MUSIC_RATE, true
	)
	_check(again.data == s.music_stream("title").data, "the same seed makes the same loop")
	s.play_music("day")
	_check(s.music_id == "day", "music id is recorded headless")
	s.stop_music()
	_check(s.music_id == "", "stop_music clears it")

	# ---- play / record / mute
	s.clear_log()
	s.play("ui_pick")
	s.play("nope")
	_check(s.played == ["ui_pick"] and s.heard == ["ui_pick"], "play records known ids only")
	s.play_grade("S")
	_check(s.played.back() == "grade_s", "play_grade maps the letter")
	s.muted = true
	s.clear_log()
	s.play("bell")
	_check(s.played == ["bell"] and s.heard.is_empty(), "muted: requested but not heard")
	s.muted = false
	s.volume = 0.0
	s.play("bell")
	_check(s.heard.is_empty(), "volume 0 is silent too")
	s.volume = 0.7

	# ---- events fire ids
	s.clear_log()
	var msp := root.get_node("Msp")
	msp.send_text("Boss", "hello")
	_check(s.played.has("text"), "a text message pings")
	msp.create_ticket(0, 0, "phone")
	_check(s.played.has("ticket"), "a new ticket chimes")
	var t: Dictionary = msp.tickets[msp.tickets.size() - 1]
	s.clear_log()
	t.fix_done = true
	msp.close_ticket(int(t.id))
	_check(s.played.has("ticket_closed"), "closing a ticket dings")
	s.clear_log()
	var t2: Dictionary = msp.create_ticket(0, 0, "phone")
	t2.sla_left = 0.01
	msp._process(1.0)
	_check(s.played.has("sla_breach"), "an SLA breach buzzes")
	s.clear_log()
	msp.mail("Someone", "Hi", "Body")
	_check(s.played.has("mail"), "new mail pings")
	s.clear_log()
	var r: Dictionary = root.get_node("Campaign").make_report()
	r.merge(
		{
			"grade": "B",
			"rep": 50,
			"cash": 0,
			"total_days": 20,
			"fired": false,
			"final": false,
			"ending": ""
		},
		true
	)
	root.get_node("DayReport").show_report(r)
	root.get_node("DayReport")._canvas.visible = false
	_check(s.played.has("grade_b"), "the day report plays its grade jingle")
	root.get_node("DayReport").is_open = false
	root.get_node("DayReport")._canvas.visible = false
	s.clear_log()
	var cards := root.get_node("Cards")
	cards.ask(
		"Dan",
		"Pick one",
		[{"label": "A", "id": "a"}, {"label": "B", "id": "b"}],
		func(_id: String) -> void: pass
	)
	_check(s.played.has("ui_open"), "a card opening sounds")
	cards.pick(1)
	_check(s.played.has("ui_pick"), "picking a card sounds")

	# ---- the real playback path (the dummy audio driver takes it)
	s.silent = false
	s.play("bell")
	s.play_music("title")
	_check(s._players.size() == 1 and s._players[0].playing, "a pooled player starts the sound")
	_check(s._music != null and s._music.playing, "the music player loops the song")
	s.stop_music()
	_check(not s._music.playing, "stop_music stops it")
	s.silent = true

	# ---- settings file
	s.volume = 0.4
	s.music_volume = 0.1
	s.set_muted(true)
	_check(FileAccess.file_exists(s.settings_path), "set_muted saves the settings file")
	s.volume = 0.9
	s.music_volume = 0.9
	s.muted = false
	s.load_settings()
	_check(
		is_equal_approx(s.volume, 0.4) and is_equal_approx(s.music_volume, 0.1) and s.muted,
		"volume, music volume and mute load back"
	)
	var cfg := ConfigFile.new()
	cfg.load(s.settings_path)
	cfg.set_value("difficulty", "tier", "hard")
	cfg.save(s.settings_path)
	s.save_settings()
	cfg.load(s.settings_path)
	_check(
		str(cfg.get_value("difficulty", "tier", "")) == "hard",
		"saving audio keeps the difficulty section"
	)
	s.set_volume(7.0)
	_check(s.volume == 1.0, "volume is clamped")
	s.toggle_mute()
	_check(not s.muted, "toggle_mute flips it")
	DirAccess.remove_absolute(s.settings_path)

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
