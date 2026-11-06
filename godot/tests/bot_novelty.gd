extends SceneTree
# Dev tool (not a test): the novelty timeline. Plays the tech campaign with a bot and prints WHEN each kind of thing first
# shows up (a card from each speaker, each story ticket, texts, mail), then the new-thing count per day and the longest
# stretches with nothing new. Times are play minutes at the normal clock (a tech day is day_len seconds).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_novelty.gd -- [strategy=careful] [seed=1] [ts=20]
# Read it as "where is the lull", not as a score: a lull is a long stretch with no first.

var firsts: Array = []  # [minutes, label]
var seen := {}
var per_day_new := {}
var per_day_cards := {}
var per_day_tickets := {}
var per_day_texts := {}
var _card_was_open := false
var _mail_n := 0


func _init() -> void:
	await process_frame
	var strat := "careful"
	var seed_n := 1
	var ts := 20.0
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("strategy="):
			strat = s.substr(9)
		elif s.begins_with("seed="):
			seed_n = int(s.substr(5))
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	var msp: Node = root.get_node("Msp")
	msp.ticket_added.connect(_on_ticket)
	msp.text_received.connect(func(_m: Dictionary) -> void: _on_text())
	var t := Timer.new()
	t.wait_time = 0.02
	t.autostart = true
	root.add_child(t)
	t.timeout.connect(_poll)
	var r: Dictionary = await bots.play("tech", "normal", strat, seed_n)
	_report(strat, seed_n, r)
	quit()


func _minutes() -> float:
	var c: Node = root.get_node("Campaign")
	var w: Node = root.get_node("World")
	var day_len := float(w.day_len)
	var span := float(w.DAY_END - w.DAY_START)
	var frac := clampf((float(w.clock) - float(w.DAY_START)) / span, 0.0, 1.0)
	return (float(c.day - 1) + frac) * day_len / 60.0


func _day() -> int:
	return int(root.get_node("Campaign").day)


func _first(label: String) -> void:
	if seen.has(label):
		return
	seen[label] = true
	firsts.append([_minutes(), label])
	per_day_new[_day()] = int(per_day_new.get(_day(), 0)) + 1


func _on_ticket(tk: Dictionary) -> void:
	per_day_tickets[_day()] = int(per_day_tickets.get(_day(), 0)) + 1
	var sp := str(tk.get("special", ""))
	_first("ticket: " + (sp if sp != "" else "an ordinary one"))


func _on_text() -> void:
	per_day_texts[_day()] = int(per_day_texts.get(_day(), 0)) + 1
	_first("a text message")


func _poll() -> void:
	var cards: Node = root.get_node("Cards")
	var open := bool(cards.is_open)
	if open and not _card_was_open:
		per_day_cards[_day()] = int(per_day_cards.get(_day(), 0)) + 1
		var sp := str(cards.speaker)
		var body := str(cards.text).substr(0, 44).replace("\n", " ")
		_first("card from " + sp)
		_first("card: " + body)
	_card_was_open = open
	var n: int = root.get_node("Msp").emails.size()
	if n > _mail_n:
		_mail_n = n
		_first("mail in the inbox")


func _report(strat: String, seed_n: int, r: Dictionary) -> void:
	print("NOVELTY %s seed %d: rep %s %s, %d distinct firsts" % [strat, seed_n, str(r.rep), str(r.cls), firsts.size()])
	for f in firsts:
		if str(f[1]).begins_with("card: "):
			continue  # the per-card lines are only counted; the speaker lines carry the timeline
		print("NOVELTY  %5.1f min  %s" % [float(f[0]), str(f[1])])
	print("NOVELTY by day (new / cards / tickets / texts):")
	var last_day := 0
	for d in per_day_new:
		last_day = maxi(last_day, int(d))
	for d in per_day_cards:
		last_day = maxi(last_day, int(d))
	var row := ""
	for d in range(1, last_day + 1):
		row += "d%d %d/%d/%d/%d  " % [d, int(per_day_new.get(d, 0)), int(per_day_cards.get(d, 0)), int(per_day_tickets.get(d, 0)), int(per_day_texts.get(d, 0))]
	print("NOVELTY ", row)
	var times: Array = []
	for f in firsts:
		times.append(float(f[0]))
	times.sort()
	var gap := 0.0
	var at := 0.0
	var prev := 0.0
	for tm in times:
		if tm - prev > gap:
			gap = tm - prev
			at = prev
		prev = tm
	print("NOVELTY first new thing at %.1f min; longest stretch with nothing new: %.1f min (from minute %.1f)" % [times[0] if not times.is_empty() else 0.0, gap, at])
