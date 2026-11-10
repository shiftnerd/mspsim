extends SceneTree
# gdlint:disable=max-line-length
# Dev tool (not a test): a per-frame state trace of one bot run, to find where two runs of the same seed part ways.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/bot_det.gd -- tech hard careful seed=11 ts=120 frames=400 > a.log
# `twice` plays the seed a second time in the same process after a "==== SECOND RUN" line (state that survives Campaign.new_game
# shows up as a difference between the halves); `stop=N` ends a tech run after day N.
# Run it twice and diff the two logs: the first differing line names the frame and the value (clock, rep, score, energy,
# ticket list, the bot's own generator and every seeded Difficulty stream).

var bots: RefCounted
var limit := 400
var show_chars := false
var step := 1  # trace every Nth frame


func _trace(frame: int) -> void:
	if frame > limit or frame % step != 0:
		return
	var d := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var world := root.get_node("World")
	var c := root.get_node("Campaign")
	var tick := []
	for t in msp.open_tickets():
		tick.append("%d:%s:%s:%d" % [int(t.id), str(t.status), str(t.fix), int(float(t.get("sla_left", t.get("sla", 0))))])
	var st := []
	var names: Array = d._streams.keys()
	names.sort()
	for k in names:
		st.append("%s=%d" % [str(k), int(d._streams[k].state) & 0xFFFF])
	var who := []
	if show_chars:  # where everybody in the office is, and what they are doing
		for n in world.chars:
			var ch: Dictionary = world.chars[n]
			var body := ""
			if ch.node != null and is_instance_valid(ch.node):  # a body in the loaded scene: its own state, timer and place
				body = "*%s/%d/%.2f/%.2f/%s" % [str(ch.node.get("state")), int(ch.node.get("_step")), float(ch.node.get("_timer")), float(ch.node.global_position.x), str(ch.node.get("seat") != null)]
			who.append("%s@%s:%s:%.1f%s" % [str(n).substr(0, 4), str(ch.scene).substr(0, 5), str(ch.legs[0].kind) if not ch.legs.is_empty() else "-", float(ch.leg_t), body])
	st.append(" ".join(who))
	var o := root.get_node("Owner")
	st.append("cash %d trust %d clients %d mood %.2f social %.2f burn %.2f" % [int(o.cash), int(root.get_node("Partner").trust), root.get_node("Sales").active.size(), float(root.get_node("Sales").average()), float(root.get_node("Social").average()), float(o.burnout)])
	print("F %d d%d clock %.4f rep %d score %d en %.3f bot %d | %s | %s" % [frame, c.day, world.clock, c.rep, msp.score, float(root.get_node("Shift").energy), int(bots.rng.state) & 0xFFFF, ",".join(tick), " ".join(st)])


func _init() -> void:
	var mode := "tech"
	var tier := "hard"
	var strat := "careful"
	var seed_n := 11
	var ts := 120.0
	var twice := false
	var stop := 0
	var before := 0  # play this seed first, untraced (state an earlier run leaves behind)
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s == "twice":
			twice = true
		elif s == "chars":
			show_chars = true
		elif s.begins_with("stop="):
			stop = int(s.substr(5))
		elif s.begins_with("before="):
			before = int(s.substr(7))
		elif s.begins_with("every="):
			step = int(s.substr(6))
		elif s.begins_with("seed="):
			seed_n = int(s.substr(5))
		elif s.begins_with("ts="):
			ts = float(s.substr(3))
		elif s.begins_with("frames="):
			limit = int(s.substr(7))
		elif s in ["tech", "owner", "sales", "service"]:
			mode = s
		elif s in ["easy", "normal", "hard"]:
			tier = s
		else:
			strat = s
	await process_frame
	bots = load("res://tests/bot_lib.gd").new(self)
	bots.ts = ts
	if before > 0:
		await bots.play(mode, tier, strat, before)
	bots.frame_hook = _trace
	bots.stop_day = stop
	var r: Dictionary = await bots.play(mode, tier, strat, seed_n)
	print(bots.line(r))
	if twice:  # the same seed again in the same process: split the log at this line and diff the halves
		print("==== SECOND RUN")
		r = await bots.play(mode, tier, strat, seed_n)
		print(bots.line(r))
	quit(0)
