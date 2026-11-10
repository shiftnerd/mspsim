extends SceneTree
# Dev tool (not a test): the per-day ticket count probe for the tech campaign (roadmap X10). Plays the 20 days with a bot
# and prints, per day: tickets opened (and how many of them by each source), the highest open count, SLAs missed, and
# how many story / event tickets were held back by the queue (Msp.held_total).
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_pace.gd -- [strategy=careful] [seed=1] [ts=20] [pace=1] [tier=normal]
# pace: 0 relaxed, 1 normal, 2 busy (the pause menu's TICKET PACE row).

var per_day := {}  # day -> {n, max_open, missed, src: {source: n}}
var _missed_was := 0


func _init() -> void:
	await process_frame
	var strat := "careful"
	var seed_n := 1
	var ts := 20.0
	var pace := 1
	var tier := "normal"
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("strategy="):
			strat = s.substr(9)
		elif s.begins_with("seed="):
			seed_n = int(s.substr(5))
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
		elif s.begins_with("pace="):
			pace = int(s.substr(5))
		elif s.begins_with("tier="):
			tier = s.substr(5)
	var bots: RefCounted = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	var msp: Node = root.get_node("Msp")
	if "pace_setting" in msp:
		msp.pace_setting = pace
	msp.ticket_added.connect(_on_ticket)
	var t := Timer.new()
	t.wait_time = 0.02
	t.autostart = true
	root.add_child(t)
	t.timeout.connect(_poll)
	var r: Dictionary = await bots.play("tech", tier, strat, seed_n)
	if "pace_setting" in msp:
		msp.pace_setting = 1
	print("PACE %s seed %d pace %d: rep %s %s" % [strat, seed_n, pace, str(r.rep), str(r.cls)])
	var top := 0
	var total := 0
	var missed := 0
	for d in range(1, 21):
		var e: Dictionary = _row(d)
		top = maxi(top, int(e.n))
		total += int(e.n)
		missed += int(e.missed)
		print("PACE  d%-2d tickets %2d  max open %2d  missed %d  %s" % [d, int(e.n), int(e.max_open), int(e.missed), str(e.src)])
	print("PACE total %d, busiest day %d, missed %d, held %s" % [total, top, missed, str(msp.get("held_total"))])
	quit()


func _row(d: int) -> Dictionary:
	if not per_day.has(d):
		per_day[d] = {"n": 0, "max_open": 0, "missed": 0, "src": {}}
	return per_day[d]


func _on_ticket(tk: Dictionary) -> void:
	var e: Dictionary = _row(int(root.get_node("Campaign").day))
	e.n = int(e.n) + 1
	var s := str(tk.get("source", "?"))
	if bool(tk.get("internal", false)):
		s = "internal"
	e.src[s] = int(e.src.get(s, 0)) + 1
	var msp: Node = root.get_node("Msp")
	if msp.open_tickets().size() > msp.open_cap():  # this one came in over the cap: who sent it?
		print("PACE over the cap d%d %.1fh: %s / %s (%d open)" % [int(root.get_node("Campaign").day), float(root.get_node("World").clock), s, str(tk.summary), msp.open_tickets().size()])


func _poll() -> void:
	var msp: Node = root.get_node("Msp")
	var e: Dictionary = _row(int(root.get_node("Campaign").day))
	e.max_open = maxi(int(e.max_open), int(msp.open_tickets().size()))
	var m := int(msp.breached)
	if m > _missed_was:
		e.missed = int(e.missed) + m - _missed_was
	_missed_was = m
