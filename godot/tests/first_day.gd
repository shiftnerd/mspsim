extends SceneTree
# gdlint:disable=max-line-length
# X10 idea: the first-day choice of the tech campaign. Right after Dan's intro card Garrison has you say hello to the room: a joke,
# the keen answer or the quiet one. Each moves two coworkers' opinions a little, sets the saved flag `hello`, and the one who liked
# it texts you the next morning. Dan's intro card stays, and the card does not touch the first ticket's timer.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/first_day.gd

const WANT := {
	"joke": {"Garrison": 2, "Alan": -1},
	"keen": {"Alan": 2, "Garrison": -1},
	"quiet": {"Dan": 1, "Maya": 1},
}
const FROM := {"joke": "Garrison", "keen": "Alan", "quiet": "Maya"}

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _drain(cards: Node) -> void:
	var n := 0
	while cards.is_open and n < 20:
		cards.pick(0)
		n += 1


func _new(c: Node, cards: Node) -> void:
	c.new_game("tech")
	_drain(cards)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var story := root.get_node("Story")
	var msp := root.get_node("Msp")
	var cards := root.get_node("Cards")
	var soc := root.get_node("Social")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	root.get_node("Difficulty").set_tier("normal")
	_new(c, cards)

	# ---- the schedule: Dan's card is still the day 1 card; the hello hangs off his answer (no event of its own to shuffle)
	var day1: Array = story.events_on(1)
	var at_dan := -1
	var own_event := false
	for i in day1.size():
		if str(day1[i].get("id", "")) == "mentor_intro":
			at_dan = i
		own_event = own_event or str(day1[i].get("id", "")) == "hello"
	_check(at_dan >= 0 and at_dan == day1.size() - 1 and not own_event, "day 1: Dan's intro card is kept, and it is still the last event of the morning")
	_check(story.VIGNETTES.has("hello") and story.VIGNETTES.hello.options.size() == 3, "three ways to say hello")
	var first_ticket: float = msp._spawn_t
	_check(first_ticket > 30.0, "the first ticket's timer is running (%d s)" % int(first_ticket))

	# ---- the card: both cards open in order, the first ticket's timer is not pushed back
	story.fire(day1[at_dan])
	_check(cards.is_open and cards.speaker.begins_with("Dan"), "Dan speaks first")
	cards.pick(0)  # WALK ME THROUGH IT
	_check(cards.is_open and cards.speaker.begins_with("Dan") and cards.options.size() == 1, "his answer comes before anything else")
	cards.pick(0)  # his answer
	_check(cards.is_open and cards.speaker.begins_with("Garrison") and cards.options.size() == 3, "then Garrison asks you to say something to the room")
	for i in 30:
		await process_frame
	_check(msp._spawn_t <= first_ticket, "while the card is up the first ticket is not delayed (timer %.1f s, was %.1f)" % [msp._spawn_t, first_ticket])
	cards.pick(0)
	_check(cards.is_open and cards.options.size() == 1, "the room reacts (one more card)")
	cards.pick(0)
	_check(not cards.is_open and str(story.flags.get("hello", "")) == "joke" and str(story.flags.get("mentor", "")) == "on", "the pick is kept as a flag, next to Dan's")
	_check(msp._spawn_t <= first_ticket and msp._spawn_t > 0.0, "and the first ticket still arrives on its own timer")

	# ---- each answer: two opinions move a little, the others stay, and the echo comes the next morning
	for id in WANT:
		_new(c, cards)
		var before := {}
		for who in soc.ALL:
			before[who] = soc.value(who)
		story._vignette("hello")
		var index := -1
		for i in cards.options.size():
			if str(cards.options[i].id) == id:
				index = i
		cards.pick(index)
		_drain(cards)
		var moved := {}
		for who in soc.ALL:
			if soc.value(who) != int(before[who]):
				moved[who] = soc.value(who) - int(before[who])
		_check(moved == WANT[id], "%s: the opinions that move are %s (got %s)" % [id, str(WANT[id]), str(moved)])
		_check(str(story.flags.get("hello", "")) == id, "%s: the flag" % id)
		var texts0: int = msp.texts.size()
		for ev in story.events_on(2):
			if str(ev.kind) == "hello_echo":
				story.fire(ev)
		_check(msp.texts.size() == texts0 + 1 and str(msp.texts[0].from) == str(FROM[id]), "%s: %s texts you on day 2 (%s)" % [id, str(FROM[id]), str(msp.texts[0].from)])
	var total := 0
	for id in WANT:
		for who in WANT[id]:
			total = maxi(total, absi(int(WANT[id][who])))
	_check(total <= 2, "no opinion moves by more than 2")

	# ---- once a run, on day 1 only, and not in a second year
	_new(c, cards)
	story._vignette_answer("mentor_intro", "alone")
	cards.pick(0)
	_check(cards.is_open and cards.speaker.begins_with("Garrison"), "I'VE GOT THIS leads to the hello as well")
	_drain(cards)
	story._vignette_answer("mentor_intro", "alone")
	_drain(cards)
	_check(not cards.is_open and str(story.flags.get("hello", "")) == "joke", "it is asked once a run")
	_new(c, cards)
	c.day = 2
	story._vignette_answer("mentor_intro", "alone")
	cards.pick(0)
	_check(not cards.is_open and not story.flags.has("hello"), "not after day 1")
	c.day = 1

	# ---- never answered (an old save, a skipped day): no text, no error
	_new(c, cards)
	var n0: int = msp.texts.size()
	story._hello_echo()
	_check(msp.texts.size() == n0, "no hello on file: nobody texts")

	# ---- the flag is saved with the campaign
	story._vignette_answer("hello", "keen")
	_drain(cards)
	c.save()
	story.flags.erase("hello")
	c.continue_game("tech")
	_drain(cards)
	_check(str(story.flags.get("hello", "")) == "keen", "the hello survives a save and a load")
	print("first_day: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
