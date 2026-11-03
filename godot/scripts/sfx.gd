extends Node
# gdlint:disable=max-line-length,class-definitions-order
# P4: procedural audio. There are no sound files: every sound is synthesised in code at the first time it is asked for
# (square / triangle / saw / sine / noise blips, 8 bit style, 16 bit mono AudioStreamWAV) and played through a small pool of
# AudioStreamPlayers. Two seeded chiptune lo-fi loops (title, day) are built the same way and play quietly.
#
#   Sfx.play("ticket")            start a sound (ids are the keys of SOUNDS)
#   Sfx.play_near("phone_ring", node)   the same, softer the further the node is from the player
#   Sfx.play_music("day")         the loop of a SONGS entry ("" stops it); Sfx.stop_music()
#   Sfx.stream("bell")            the AudioStreamWAV of a sound (cached), Sfx.music_stream("day") for a loop
#   Sfx.volume / music_volume / muted        0..1 settings, saved in user://mspsim_settings.cfg ([audio]); M toggles mute
#
# Nothing in the game depends on sound: every sound sits next to a visual cue that already exists (toast, bubble, ring
# animation, flash). Headless runs (and tests, with `silent = true`) never touch an audio device but still record: `played`
# gets every id that was asked for, `heard` only the ones that were not muted. Real recorded files could replace the synth
# later: stream(id) is the one place that decides what a sound is, so load a file there (see CLAUDE.md, "Audio").

signal settings_changed

const RATE := 22050
const MUSIC_RATE := 11025
const POOL := 8
const MASTER := 0.55  # headroom: the synth mixes up to full scale
const MIN_GAP_MS := 60  # the same sound does not restart faster than this
const LOG_MAX := 400
const MAX_SECS := 4.0  # no effect is longer than this (tests check it)
# A layer: w wave (sq tri saw sine noise), f / f2 start and end Hz (noise: how crunchy), t seconds, at start offset, v volume,
# k decay (0 = flat), duty for sq, am tremolo Hz, lp noise smoothing 0..1. "seq" (MIDI notes, 0 = rest) with "step" and "rep"
# / "gap" expands to one layer per note.
const SOUNDS := {
	# ---- menus
	"ui_open": [{"w": "sq", "seq": [72, 79], "step": 0.045, "t": 0.07, "v": 0.22, "duty": 0.25}],
	"ui_pick": [{"w": "sq", "seq": [79, 86], "step": 0.05, "t": 0.09, "v": 0.25, "duty": 0.5}],
	"ui_tick":
	[
		{"w": "noise", "f": 5000.0, "t": 0.012, "v": 0.22, "k": 2.0},
		{"w": "sq", "f": 1800.0, "t": 0.012, "v": 0.1}
	],
	"ui_error":
	[{"w": "sq", "seq": [55, 50], "step": 0.11, "t": 0.12, "v": 0.26, "duty": 0.5, "k": 1.5}],
	"phone_ring":
	[
		# ---- the office
		{
			"w": "sq",
			"seq": [81, 84],
			"step": 0.045,
			"rep": 6,
			"t": 0.045,
			"v": 0.2,
			"duty": 0.5,
			"k": 0.0
		},
		{
			"w": "sq",
			"seq": [81, 84],
			"step": 0.045,
			"rep": 6,
			"t": 0.045,
			"v": 0.2,
			"duty": 0.5,
			"k": 0.0,
			"at": 0.9
		}
	],
	"headset":
	[
		{"w": "noise", "f": 3000.0, "t": 0.015, "v": 0.2, "k": 2.0},
		{"w": "tri", "seq": [76, 81], "step": 0.05, "t": 0.07, "v": 0.3}
	],
	"ticket":
	[
		{"w": "tri", "seq": [76, 83], "step": 0.09, "t": 0.18, "v": 0.36, "k": 2.5},
		{"w": "sq", "seq": [88, 95], "step": 0.09, "t": 0.1, "v": 0.05, "duty": 0.125}
	],
	"sla_breach":
	[
		{"w": "sq", "f": 150.0, "t": 0.2, "v": 0.3, "k": 0.5, "duty": 0.4},
		{"w": "saw", "f": 100.0, "t": 0.2, "v": 0.2, "k": 0.5},
		{"w": "sq", "f": 150.0, "t": 0.2, "v": 0.3, "k": 0.5, "duty": 0.4, "at": 0.26},
		{"w": "saw", "f": 100.0, "t": 0.2, "v": 0.2, "k": 0.5, "at": 0.26}
	],
	"ticket_closed":
	[
		{"w": "sine", "f": 1318.5, "t": 0.55, "v": 0.34, "k": 5.0},
		{"w": "sine", "f": 1976.0, "t": 0.35, "v": 0.14, "k": 6.0}
	],
	"text": [{"w": "sq", "seq": [88, 93], "step": 0.07, "t": 0.07, "v": 0.2, "duty": 0.125}],
	"mail": [{"w": "tri", "seq": [76, 81, 84], "step": 0.08, "t": 0.14, "v": 0.3, "k": 2.5}],
	"bell":
	[
		{"w": "sine", "f": 1760.0, "t": 1.0, "v": 0.34, "k": 4.5},
		{"w": "sine", "f": 2349.0, "t": 0.7, "v": 0.18, "k": 5.0},
		{"w": "sine", "f": 3520.0, "t": 0.45, "v": 0.1, "k": 6.0}
	],
	"coffee":
	[
		{"w": "noise", "f": 1500.0, "t": 1.7, "v": 0.2, "k": 0.0, "am": 9.0, "lp": 0.35},
		{"w": "tri", "f": 1568.0, "t": 0.1, "v": 0.26, "at": 1.75}
	],
	"printer_jam":
	[
		{"w": "noise", "f": 500.0, "t": 0.55, "v": 0.26, "k": 0.5, "am": 24.0, "lp": 0.5},
		{"w": "sq", "f": 90.0, "t": 0.55, "v": 0.14, "k": 1.0, "duty": 0.3}
	],
	"footstep": [{"w": "noise", "f": 700.0, "t": 0.03, "v": 0.18, "k": 3.0, "lp": 0.4}],
	"grade_s":
	[
		# ---- the day report grades
		{
			"w": "sq",
			"seq": [72, 76, 79, 84, 79, 84, 88],
			"step": 0.09,
			"t": 0.12,
			"v": 0.2,
			"duty": 0.25,
			"k": 1.5
		},
		{"w": "tri", "f": 1046.5, "t": 0.5, "v": 0.3, "k": 3.0, "at": 0.63}
	],
	"grade_a":
	[
		{
			"w": "sq",
			"seq": [72, 76, 79, 84],
			"step": 0.1,
			"t": 0.13,
			"v": 0.2,
			"duty": 0.25,
			"k": 1.5
		},
		{"w": "tri", "f": 1046.5, "t": 0.4, "v": 0.26, "k": 3.0, "at": 0.4}
	],
	"grade_b":
	[{"w": "sq", "seq": [72, 76, 79], "step": 0.11, "t": 0.15, "v": 0.2, "duty": 0.5, "k": 1.5}],
	"grade_c": [{"w": "tri", "seq": [67, 64], "step": 0.2, "t": 0.26, "v": 0.3, "k": 1.5}],
	"grade_d":
	[
		{
			"w": "sq",
			"seq": [60, 58, 55, 52],
			"step": 0.17,
			"t": 0.2,
			"v": 0.2,
			"duty": 0.5,
			"k": 1.5
		},
		{"w": "saw", "f": 55.0, "t": 0.3, "v": 0.18, "k": 3.0, "at": 0.68}
	],
	"dart_fire":
	[
		# ---- nerf, chairs, bowling, karaoke
		{"w": "sq", "f": 700.0, "f2": 160.0, "t": 0.09, "v": 0.22, "k": 2.0, "duty": 0.25},
		{"w": "noise", "f": 4000.0, "t": 0.05, "v": 0.18, "k": 3.0}
	],
	"dart_hit":
	[
		{"w": "noise", "f": 2000.0, "t": 0.06, "v": 0.3, "k": 3.0, "lp": 0.6},
		{"w": "sq", "f": 240.0, "f2": 110.0, "t": 0.07, "v": 0.2, "k": 2.0}
	],
	"squeak":
	[
		{"w": "sq", "f": 1400.0, "f2": 2300.0, "t": 0.1, "v": 0.14, "duty": 0.125, "k": 1.0},
		{
			"w": "sq",
			"f": 2000.0,
			"f2": 1300.0,
			"t": 0.08,
			"v": 0.12,
			"duty": 0.125,
			"k": 1.0,
			"at": 0.12
		}
	],
	"clunk":
	[
		{"w": "tri", "f": 150.0, "f2": 55.0, "t": 0.14, "v": 0.5, "k": 3.0},
		{"w": "noise", "f": 900.0, "t": 0.04, "v": 0.25, "k": 3.0, "lp": 0.5}
	],
	"bowl_roll":
	[
		{"w": "noise", "f": 300.0, "t": 0.9, "v": 0.28, "k": 0.0, "am": 6.0, "lp": 0.12},
		{"w": "sine", "f": 70.0, "t": 0.9, "v": 0.2, "k": 0.0}
	],
	"bowl_strike":
	[
		{"w": "noise", "f": 1800.0, "t": 0.55, "v": 0.4, "k": 4.0, "lp": 0.7},
		{"w": "tri", "f": 130.0, "f2": 60.0, "t": 0.3, "v": 0.4, "k": 3.0},
		{"w": "sq", "seq": [84, 88, 91], "step": 0.07, "t": 0.1, "v": 0.14, "duty": 0.25, "at": 0.3}
	],
	"kara_perfect":
	[{"w": "sq", "seq": [84, 88, 91], "step": 0.045, "t": 0.07, "v": 0.18, "duty": 0.25}],
	"kara_good": [{"w": "sq", "seq": [79, 84], "step": 0.05, "t": 0.08, "v": 0.16, "duty": 0.5}],
}
# Songs: bpm, root (MIDI), chords as [offset, tones], seed (the melody and the arpeggio shape come from it), crush (bit steps)
const SONGS := {
	"title":
	{
		"bpm": 76,
		"root": 45,
		"seed": 2013,
		"arp": [0, 1, 2, 1, 3, 2, 1, 2],
		"chords": [[0, [0, 3, 7, 10]], [-4, [0, 4, 7, 11]], [3, [0, 4, 7, 11]], [-2, [0, 4, 7, 9]]]
	},
	"day":
	{
		"bpm": 88,
		"root": 50,
		"seed": 1403,
		"arp": [0, 2, 1, 3, 2, 1, 3, 1],
		"chords": [[0, [0, 3, 7, 10]], [5, [0, 4, 7, 10]], [-2, [0, 4, 7, 11]], [3, [0, 4, 7, 11]]]
	},
}
const PENTA := [0, 3, 5, 7, 10]

var volume := 0.7
var music_volume := 0.25  # quiet by default
var muted := false
var settings_path := "user://mspsim_settings.cfg"
var silent := false  # headless / tests: nothing reaches an audio device
var played: Array = []  # every sound id that was asked for (tests)
var heard: Array = []  # the ones that were not muted
var music_id := ""

var _cache := {}
var _songs := {}
var _players: Array = []
var _music: AudioStreamPlayer = null
var _last := {}


func _ready() -> void:
	silent = DisplayServer.get_name() == "headless"
	load_settings()
	Msp.ticket_added.connect(func(_t: Dictionary) -> void: play("ticket"))
	Msp.text_received.connect(func(_m: Dictionary) -> void: play("text"))
	Campaign.day_started.connect(func(_d: int) -> void: play_music("day"))


# ---- playing ---------------------------------------------------------------------------------------------------
func ids() -> Array:
	return SOUNDS.keys()


func play(id: String, gain := 1.0) -> void:
	if not SOUNDS.has(id):
		return
	_log(played, id)
	if muted or volume <= 0.0 or gain <= 0.0:
		return
	_log(heard, id)
	if silent:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -10000)) < MIN_GAP_MS:
		return
	_last[id] = now
	var p := _free_player()
	p.stream = stream(id)
	p.volume_db = linear_to_db(clampf(volume * gain, 0.0, 1.0) * MASTER)
	p.play()


# a sound that belongs to something in the room (a ringing phone): quieter the further it is from the player
func play_near(id: String, node: Node2D) -> void:
	var gain := 0.6
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and is_instance_valid(node):
		gain = clampf(
			1.15 - node.global_position.distance_to(player.global_position) / 260.0, 0.0, 1.0
		)
	play(id, gain)


# the day report's grade letter (S A B C D)
func play_grade(grade: String) -> void:
	play("grade_" + grade.to_lower())


func play_music(id: String) -> void:
	if id == music_id and _music != null and _music.playing:
		return
	music_id = id
	_apply_music()


func stop_music() -> void:
	music_id = ""
	_apply_music()


func _apply_music() -> void:
	if silent:
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		add_child(_music)
	if music_id == "" or muted or music_volume <= 0.0 or not SONGS.has(music_id):
		_music.stop()
		return
	_music.volume_db = linear_to_db(music_volume * MASTER)
	if _music.stream != music_stream(music_id) or not _music.playing:
		_music.stream = music_stream(music_id)
		_music.play()


func _free_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			return p
	if _players.size() < POOL:
		var np := AudioStreamPlayer.new()
		add_child(np)
		_players.append(np)
		return np
	return _players[0]  # all busy: the oldest voice is cut


func _log(list: Array, id: String) -> void:
	list.append(id)
	if list.size() > LOG_MAX:
		list.pop_front()


func clear_log() -> void:
	played.clear()
	heard.clear()


# ---- settings --------------------------------------------------------------------------------------------------
func set_muted(on: bool) -> void:
	muted = on
	_apply_music()
	save_settings()
	settings_changed.emit()


# M: mute or unmute everything; the toast is the visual side of it
func toggle_mute() -> void:
	set_muted(not muted)
	Hints.toast("SOUND OFF" if muted else "SOUND ON", 1.5)
	if not muted:
		play("ui_pick")


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	save_settings()
	settings_changed.emit()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_music()
	save_settings()
	settings_changed.emit()


func status_text() -> String:
	return "SOUND OFF" if muted else "SOUND ON"


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
		muted = bool(cfg.get_value("audio", "muted", muted))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(settings_path)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_M
		and not event.ctrl_pressed
	):
		toggle_mute()


# ---- synthesis -------------------------------------------------------------------------------------------------
func stream(id: String) -> AudioStreamWAV:
	if not SOUNDS.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = _wav(_render(_expand(SOUNDS[id]), RATE, 0.0, hash(id)), RATE, false)
	return _cache[id]


func music_stream(id: String) -> AudioStreamWAV:
	if not SONGS.has(id):
		return null
	if not _songs.has(id):
		var song: Dictionary = SONGS[id]
		_songs[id] = _wav(
			_render(_song_layers(song), MUSIC_RATE, 28.0, int(song.seed)), MUSIC_RATE, true
		)
	return _songs[id]


static func mtof(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


# "seq" layers become one layer per note
static func _expand(spec: Array) -> Array:
	var out := []
	for raw in spec:
		var l: Dictionary = raw
		if not l.has("seq"):
			out.append(l)
			continue
		var notes: Array = l.seq
		var step := float(l.get("step", 0.1))
		var reps := int(l.get("rep", 1))
		var span := step * float(notes.size()) + float(l.get("gap", 0.0))
		for r in reps:
			for i in notes.size():
				if int(notes[i]) <= 0:
					continue
				var one := l.duplicate()
				one.erase("seq")
				one["f"] = mtof(int(notes[i]))
				one["at"] = float(l.get("at", 0.0)) + float(r) * span + float(i) * step
				out.append(one)
	return out


# mixes the layers into one float buffer (-1..1). `crush` > 0 rounds to that many steps (lo-fi)
static func _render(layers: Array, rate: int, crush: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var total := 0.0
	for l: Dictionary in layers:
		total = maxf(total, float(l.get("at", 0.0)) + float(l.get("t", 0.1)))
	var buf := PackedFloat32Array()
	buf.resize(int(total * float(rate)) + 1)
	for l: Dictionary in layers:
		var start := int(float(l.get("at", 0.0)) * float(rate))
		var cnt := int(float(l.get("t", 0.1)) * float(rate))
		var f0 := float(l.get("f", 440.0))
		var f1 := float(l.get("f2", f0))
		var vol := float(l.get("v", 0.3))
		var k := float(l.get("k", 3.0))
		var wave := str(l.get("w", "sq"))
		var duty := float(l.get("duty", 0.5))
		var am := float(l.get("am", 0.0))
		var lp := float(l.get("lp", 1.0))
		var phase := 0.0
		var held := 0.0
		var smooth := 0.0
		var hold_n := 0
		for i in cnt:
			var x := float(i) / float(cnt)
			var f := lerpf(f0, f1, x)
			phase = fmod(phase + f / float(rate), 1.0)
			var s := 0.0
			if wave == "sq":
				s = 1.0 if phase < duty else -1.0
			elif wave == "tri":
				s = 4.0 * absf(phase - 0.5) - 1.0
			elif wave == "saw":
				s = 2.0 * phase - 1.0
			elif wave == "sine":
				s = sin(TAU * phase)
			else:
				if hold_n <= 0:
					held = rng.randf() * 2.0 - 1.0
					hold_n = maxi(1, int(float(rate) / maxf(f, 1.0)))
				hold_n -= 1
				smooth += (held - smooth) * lp
				s = smooth
			var env := exp(-k * x)
			if i < 40:
				env *= float(i) / 40.0
			if cnt - i < 60:
				env *= float(cnt - i) / 60.0
			if am > 0.0:
				env *= 0.65 + 0.35 * sin(TAU * am * float(i) / float(rate))
			var at := start + i
			if at < buf.size():
				buf[at] += s * vol * env
	for i in buf.size():
		var v := clampf(buf[i], -1.0, 1.0)
		buf[i] = roundf(v * crush) / crush if crush > 0.0 else v
	return buf


static func _wav(buf: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


# four bars of eighth notes: a triangle bass, a soft square arpeggio, a hat and a sparse seeded melody
static func _song_layers(song: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(song.seed)
	var step := 60.0 / float(song.bpm) / 2.0
	var arp: Array = song.arp
	var layers := []
	var chords: Array = song.chords
	for bar in chords.size():
		var chord: Array = chords[bar]
		var root := int(song.root) + int(chord[0])
		var tones: Array = chord[1]
		var t0 := float(bar) * 8.0 * step
		for beat in [0, 3, 4, 6]:
			var note := root + (7 if beat == 4 else 0)
			layers.append(
				{
					"w": "tri",
					"f": mtof(note),
					"t": step * 1.8,
					"at": t0 + float(beat) * step,
					"v": 0.24,
					"k": 1.2
				}
			)
		for s in 8:
			var tone := int(tones[int(arp[s]) % tones.size()])
			layers.append(
				{
					"w": "sq",
					"f": mtof(root + 12 + tone),
					"t": step * 0.9,
					"at": t0 + float(s) * step,
					"v": 0.05,
					"k": 4.0,
					"duty": 0.25
				}
			)
			if s % 2 == 1:
				layers.append(
					{
						"w": "noise",
						"f": 7000.0,
						"t": 0.03,
						"at": t0 + float(s) * step,
						"v": 0.035,
						"k": 3.0
					}
				)
		for s in [0, 2, 3, 5, 6]:
			if rng.randf() < 0.55:
				var pick := int(PENTA[rng.randi() % PENTA.size()])
				layers.append(
					{
						"w": "tri",
						"f": mtof(root + 24 + pick),
						"t": step * 1.7,
						"at": t0 + float(s) * step,
						"v": 0.1,
						"k": 1.5
					}
				)
	return layers
