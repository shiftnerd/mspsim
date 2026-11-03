extends SceneTree
# Coworker opinions: chats, phones, tickets, outages, reopens; moods, rep bonus, report, save.

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var c := root.get_node("Campaign")
	var so := root.get_node("Social")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	c.save_prefix = "user://test_"

	c.new_game("free")
	so.note_call_answered()
	so.note_outage(6)
	_check(so.value("Alan") == 0, "free play: opinions never change")

	c.new_game("tech")
	_check(so.mood("Alan") == "NEUTRAL" and so.glyph("Alan") == "!", "everyone starts neutral")
	so.note_chat("Alan")
	so.note_chat("Alan")
	_check(so.value("Alan") == 1, "chatting counts once per cooldown")

	for i in 3:
		so.note_call_answered()
	_check(
		so.value("Garrison") == 1 and so.value("Dan") == 1 and so.value("Alan") == 2,
		"every third call helps everyone"
	)
	_check(msp.texts.size() >= 2, "a coworker texts a thank-you")

	# their own desk's outage ticket matters most
	msp.create_internal(6, "Office 1: no internet", "help")
	_check(so.value("Alan") == 0, "cutting Alan's network annoys him")
	var tid: int = msp.tickets[msp.tickets.size() - 1].id
	msp.ticket(tid).fix_done = true
	_check(
		msp.close_ticket(tid).begins_with("CLOSED") and so.value("Alan") == 4,
		"fixing it wins him over"
	)

	# reopened tickets annoy everybody
	var t: Dictionary = msp.create_ticket(0, 0, "test")
	var before: int = so.value("Dan")
	msp.close_ticket(t.id)
	_check(so.value("Dan") == before - 1, "closing an unfixed ticket annoys everyone")

	# moods, reactions and the reputation nudge
	so.rel["Garrison"] = 30
	so.rel["Dan"] = -20
	so.rel["Alan"] = -50
	_check(so.is_friendly("Garrison") and so.glyph("Garrison") == "heart", "friendly: heart bubble")
	_check(
		so.is_cold("Dan") and so.glyph("Dan") == "?" and so.mood("Dan") == "COLD",
		"cold: question mark, no wave"
	)
	_check(so.is_hostile("Alan") and so.mood("Alan") == "HOSTILE", "hostile")
	so.rel = {"Alan": 70, "Garrison": 50, "Dan": 40, "Vic": 40, "Maya": 40}
	_check(so.rep_bonus() == 1 and so.mood("Alan") == "FRIEND", "friends: +1 reputation a day")
	so.rel = {"Alan": -40, "Garrison": -20, "Dan": 0, "Vic": -30, "Maya": -30}
	_check(so.rep_bonus() == -1, "average dislike: -1 reputation a day")

	# the end of day report shows the coworker change
	so.day_delta = 3
	c._base = {"score": 0, "closed": 0, "missed": 0, "reopened": 0}
	var r: Dictionary = c.make_report()
	_check(r.social == 3, "report has the coworker delta")

	# saved with the campaign
	so.rel = {"Alan": 12, "Garrison": -8, "Dan": 33, "Vic": 5}
	so.calls_answered = 7
	c.save()
	c.new_game("free")
	_check(
		(
			c.continue_game("tech")
			and so.value("Dan") == 33
			and so.value("Garrison") == -8
			and so.calls_answered == 7
		),
		"saved"
	)
	DirAccess.remove_absolute(c.save_path("tech"))
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
