extends SceneTree
# R37 phone upgrades: the lock screen, the PHONE app (contacts, keypad, text-only calls with cooldowns), the
# notification banner on the HUD (queueing, buzz, cozy Easy, lights out) and the campaign save section.
#   Godot --headless --path godot -s res://tests/phone2.gd

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _has(opts: Array, id: String) -> bool:
	for o in opts:
		if o.id == id:
			return true
	return false


func _init() -> void:
	await process_frame
	var phone := root.get_node("Phone")
	var msp := root.get_node("Msp")
	var c := root.get_node("Campaign")
	var world := root.get_node("World")
	var sales := root.get_node("Sales")
	var social := root.get_node("Social")
	var cards := root.get_node("Cards")
	var game := root.get_node("Game")
	var diff := root.get_node("Difficulty")
	var sfx := root.get_node("Sfx")
	var lync := root.get_node("Lync")
	var Calls = load("res://scripts/phone_calls.gd")
	c.save_prefix = "user://test_%d_" % OS.get_process_id()
	phone.save_path = "user://test_%d_phone.cfg" % OS.get_process_id()
	game.title_mode = false
	diff.set_tier("normal")
	c.new_game("tech")
	phone.os = "ios"
	world.clock = 10.0
	var story := root.get_node("Story")
	for k in story.events_on(c.day).size():
		story._fired[k] = true  # day 1's own cards (Dan's intro at 9:20) are not what this test is about

	# ---- contacts
	var list: Array = Calls.contacts()
	var ids := []
	for k in list:
		ids.append(k.id)
	_check(ids.has("c:0") and ids.has("w:Morgan") and ids.has("w:Alan") and ids.has("pizza"), "contacts: a client, Morgan, an owner, the pizza place")
	var names := []
	for k in list:
		names.append(k.name)
	_check(names.has("DR. PATEL") and names.has("MORGAN"), "contacts are listed by name")
	var nums := {}
	for k in list:
		nums[k.num] = true
	_check(nums.size() == list.size(), "every contact has its own number")

	# ---- lock screen
	phone.open()
	_check(phone.is_open and phone.locked and phone.app == "home", "opening the phone shows the lock screen")
	phone.activate("app:mail")
	_check(not phone.locked, "anything you do wakes it past the lock screen (test shortcut)")
	phone.close()
	await create_timer(0.3).timeout
	phone.open()
	_check(phone.locked, "every open starts locked")
	phone.enter()
	_check(phone.unlock_t >= 0.0 and phone.locked, "Enter starts the slide to unlock")
	phone._process(0.2)
	_check(phone.locked, "still sliding")
	phone._process(0.2)
	_check(not phone.locked and phone.app == "home", "slide finished: the home screen")
	phone.close()
	await create_timer(0.3).timeout
	phone.os = "android"
	phone.open()
	_check(phone.locked, "Nexxus locks too")
	phone.move(-1)
	phone._process(0.4)
	_check(not phone.locked, "Nexxus: Up swipes up to unlock")
	phone.close()
	await create_timer(0.3).timeout
	phone.os = "ios"
	phone.open()
	phone.back()
	_check(not phone.is_open, "Esc on the lock screen closes the phone")
	await create_timer(0.3).timeout

	# ---- calling a client
	phone.open()
	phone.activate("unlock")
	phone._process(0.5)
	phone.activate("app:phone")
	_check(phone.app == "phone" and phone.ph_view == "contacts", "the PHONE app opens on the contacts")
	var t: Dictionary = msp.create_ticket(0, 5, "test")
	sales.satisfaction[0] = 60
	var ep: Dictionary = msp.endpoint(str(t.endpoint))
	ep["unsaved"] = true
	ep["asked"] = false
	var clock0: float = world.clock
	phone.activate("call:0")
	_check(phone.dialog.stage == "dial", "dialling rings first")
	phone.step_call(1.3)
	_check(phone.dialog.stage == "talk" and (phone.dialog.opts as Array).size() >= 2, "they pick up after the ring")
	_check(_has(phone.dialog.opts, "check") and not _has(phone.dialog.opts, "sorry") and not _has(phone.dialog.opts, "refer"), "no apology without a late ticket, no referral at mood 60")
	phone.step_call(14.0)
	_check(absf(float(phone.dialog.t) - 14.0) < 0.01, "the call timer counts")
	phone.choose(0)
	_check(phone.dialog.stage == "done", "one thing said, then the call winds down")
	_check(sales.mood(0) == 62, "checking in on an open ticket: client mood +2")
	_check(str(phone.dialog.say).contains("#%d" % t.id) and str(phone.dialog.say).contains("DOCUMENTS"), "the hint names the ticket and the open documents")
	_check(world.clock > clock0, "a call takes game time")
	phone.hang_up()
	_check(phone.dialog.is_empty(), "hung up")
	phone.activate("call:0")
	_check(phone.dialog.is_empty() and Calls.wait_left(Calls.find("c:0")) > 2.0, "the same client is on cooldown")
	world.clock += 3.2
	_check(Calls.ready(Calls.find("c:0")), "ready again after three game hours")
	t["breached"] = true
	sales.satisfaction[0] = 85
	phone.activate("call:0")
	phone.pick_up()
	_check(_has(phone.dialog.opts, "sorry") and _has(phone.dialog.opts, "refer"), "late ticket: apologise; mood 85: referral")
	var at: int = phone.dialog.opts.find(phone.dialog.opts.filter(func(o: Dictionary) -> bool: return o.id == "sorry")[0])
	phone.choose(at)
	_check(sales.mood(0) == 89, "apologising for a late ticket: mood +4")
	phone.hang_up()

	# referrals are rare and seeded
	diff.run_seed = 4242
	var hits := 0
	var c0: int = c.rep
	for n in 60:
		var r: Dictionary = Calls._client_act(Calls.find("c:1"), "refer", n)
		hits += 1 if str(r.say).contains("FRIEND") else 0
	_check(hits >= 8 and hits <= 36, "referrals land about 35 percent of the time (%d of 60)" % hits)
	_check(c.rep >= c0, "a referral never costs reputation")
	var again := 0
	diff.run_seed = 4242
	for n in 60:
		again += 1 if str(Calls._client_act(Calls.find("c:1"), "refer", n).say).contains("FRIEND") else 0
	_check(again == hits, "same seed, same referrals")

	# ---- a coworker
	var who := "Dan"
	for w in ["Dan", "John", "Maya"]:
		if social.people().has(w):
			who = w
			break
	world.chars[who].scene = world.CAST[who].home
	world.force_activity(who, "work")
	social.rel[who] = 0
	phone.activate("call:%d" % ids.find("w:" + who))
	phone.pick_up()
	_check(_has(phone.dialog.opts, "talk") and not phone.dialog.voicemail, "a coworker at their desk picks up")
	phone.choose(0)
	_check(social.value(who) == 1, "a chat is Social opinion +1")
	phone.hang_up()
	phone.activate("call:%d" % ids.find("w:" + who))
	_check(phone.dialog.is_empty(), "coworker cooldown (two game hours)")
	world.clock += 2.1
	social.rel[who] = -80
	phone.activate("call:%d" % ids.find("w:" + who))
	phone.pick_up()
	phone.choose(0)
	_check(social.value(who) == -80, "a hostile coworker gives you nothing")
	phone.hang_up()
	world.chars[who].scene = world.OUTSIDE
	var away: Dictionary = Calls.open_call(Calls.find("w:" + who))
	_check(away.voicemail and (away.opts as Array).size() == 1, "an absent coworker sends you to voicemail")

	# ---- pizza
	phone.activate("call:%d" % ids.find("pizza"))
	phone.pick_up()
	var e0: float = root.get_node("Shift").energy
	phone.choose(0)
	_check(root.get_node("Shift").energy >= e0, "ordering lunch never costs energy")
	phone.hang_up()

	# ---- keypad
	phone.activate("keypad")
	phone.kp_text = ""
	phone.activate("key:4")
	phone.activate("key:10")
	_check(phone.kp_text == "50", "keypad digits (key 5 then key 0)")
	phone.activate("del")
	_check(phone.kp_text == "5", "DEL")
	var ev := InputEventKey.new()
	ev.keycode = KEY_5
	ev.pressed = true
	phone._dial_key(ev)
	_check(phone.kp_text == "55", "keyboard digits work on the keypad")
	phone.kp_text = "5550111"
	world.clock = 10.0
	phone.call_cd.clear()
	phone.dial_number()
	_check(phone.dialog.contact.id == "c:1", "dialling a known number calls that contact")
	phone.hang_up()
	phone.kp_text = "1234567"
	phone.dial_number()
	phone.pick_up()
	_check(phone.dialog.voicemail and str(phone.dialog.say).contains("NOT IN SERVICE"), "an unknown number is not in service")
	phone.hang_up()
	phone.kp_sel = 4
	phone.kp_move(3)
	phone.kp_move(3)
	phone.kp_move(3)
	_check(phone.kp_sel == 12, "keypad: down reaches DEL")
	phone.kp_move(1)
	_check(phone.kp_sel == 13, "keypad: right reaches CALL")
	phone.back()
	_check(phone.ph_view == "contacts", "back leaves the keypad")
	phone.back()
	_check(phone.app == "home", "back leaves the PHONE app")

	# ---- Free Play: free and no cooldown
	phone.call_cd.clear()
	c.active = false
	world.clock = 10.0
	phone.activate("app:phone")
	phone.activate("call:0")
	phone.pick_up()
	phone.choose(0)
	phone.hang_up()
	_check(world.clock == 10.0, "Free Play calls cost no time")
	phone.activate("call:0")
	_check(not phone.dialog.is_empty(), "Free Play: no cooldown")
	phone.hang_up()
	c.active = true

	# ---- save
	phone.call_cd = {"c:0": 123.5}
	phone.call_n = {"c:0": 2}
	var d: Dictionary = phone.to_dict()
	phone.reset()
	_check(phone.call_cd.is_empty(), "a new campaign starts clean")
	phone.from_dict(d)
	_check(float(phone.call_cd["c:0"]) == 123.5 and int(phone.call_n["c:0"]) == 2, "to_dict / from_dict round trip")
	phone.from_dict({})
	_check(phone.call_cd.is_empty(), "an old save with no phone section loads clean")
	phone.call_cd = {"c:3": 77.0}
	c.save()
	phone.reset()
	var cfg := ConfigFile.new()
	cfg.load(c.save_path("tech"))
	_check(cfg.has_section_key("campaign", "phone"), "the campaign save has a phone section")
	phone.from_dict(cfg.get_value("campaign", "phone", {}))
	_check(float(phone.call_cd.get("c:3", 0.0)) == 77.0, "cooldowns come back from the file")
	phone.close()
	await create_timer(0.3).timeout

	# ---- the notification banner
	phone.reset()
	phone.poll_notifications()  # primes the mail and Lynk counters
	diff.set_tier("normal")
	world.hud_visible = true
	world.lights.clear()
	var buzz0: int = phone.buzz_count
	msp.send_text("Boss", "Hello there")
	_check(phone.feed.size() >= 1 and phone.feed[0].kind == "TEXT", "a text lands in the notification feed")
	_check(msp.unread_texts() >= 1, "the TXT counter still counts it")
	phone.step_banner(0.0)
	_check(str(phone.banner.get("kind", "")) == "TEXT" and phone.buzz_count == buzz0 + 1, "a text while the phone is closed: banner and buzz")
	_check(phone.banner_slide() == 0.0, "it starts above the screen")
	phone.step_banner(0.25)
	_check(phone.banner_slide() == 1.0, "slid in after a quarter second")
	phone.step_banner(2.0)
	_check(phone.banner_slide() == 1.0 and not phone.banner.is_empty(), "held for two seconds")
	phone.step_banner(0.3)
	_check(phone.banner.is_empty(), "gone after about 2.5 seconds")
	# mail and Lynk have no signal: the poll finds them
	msp._mail("Dr. Patel <patel@acmedental.example>", "PRINTER IS ON FIRE", "Help", 0)
	phone.poll_notifications()
	_check(phone._bq.size() == 1 and phone._bq[0].kind == "MAIL" and phone._bq[0].who == "Dr. Patel", "new mail makes a banner")
	phone._bq.clear()
	lync._push("Dan", "Dan", "Heads up: #9 is about to breach its SLA.")
	phone.poll_notifications()
	_check(phone._bq.size() == 1 and phone._bq[0].kind == "SLA", "a Lynk SLA warning is flagged SLA")
	phone._bq.clear()
	lync._push("John", "John", "Lunch?")
	phone.poll_notifications()
	_check(phone._bq.size() == 1 and phone._bq[0].kind == "IM", "a Lynk message makes an IM banner")
	phone._bq.clear()
	# modal queue
	cards.is_open = true
	msp.send_text("Dispatch", "queued while a card is open")
	phone.step_banner(0.5)
	_check(phone.banner.is_empty() and phone._bq.size() == 1, "banners wait while a card is open")
	cards.is_open = false
	phone.step_banner(0.0)
	_check(not phone.banner.is_empty(), "and show when it closes")
	phone.banner = {}
	root.get_node("DayReport").is_open = true
	msp.send_text("Dispatch", "queued while the day report is open")
	phone.step_banner(0.5)
	_check(phone.banner.is_empty() and phone._bq.size() == 1, "banners wait while the day report is open")
	root.get_node("DayReport").is_open = false
	phone._bq.clear()
	# the buzz: rate limited, silent in the dark
	phone._buzz_ms = -100000
	var b1: int = phone.buzz_count
	phone.buzz()
	phone.buzz()
	_check(phone.buzz_count == b1 + 1, "no buzz spam (2.5 s apart on Normal)")
	diff.set_tier("easy")
	phone._buzz_ms = Time.get_ticks_msec() - 5000
	phone.buzz()
	_check(phone.buzz_count == b1 + 1, "cozy Easy: gentler, 5 s is too soon")
	phone._buzz_ms = -100000
	phone.buzz()
	_check(phone.buzz_count == b1 + 2, "cozy Easy still buzzes after a long quiet")
	diff.set_tier("normal")
	phone._buzz_ms = -100000
	world.lights[world._scene] = false
	phone.buzz()
	_check(phone.buzz_count == b1 + 2, "lights out: the banner shows but the phone stays quiet")
	world.lights.clear()
	_check(sfx.ids().has("buzz"), "Sfx has a buzz sound")
	# an open phone gets no banner
	phone.open()
	msp.send_text("Boss", "while open")
	phone.step_banner(0.0)
	_check(phone.banner.is_empty() and phone._bq.is_empty() and phone.feed[0].body == "while open", "an open phone only fills the feed")
	phone.close()
	await create_timer(0.3).timeout

	print("failures=", failures)
	quit(1 if failures > 0 else 0)
