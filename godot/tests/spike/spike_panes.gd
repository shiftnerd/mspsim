extends SceneTree
# THROWAWAY coop spike, risk 1 (docs/coop-risk-findings.md): a SECOND Computer / Phone / Cards / DayReport in a SubViewport at
# half-window sizes, every app screenshotted, layout audit lines per screen. Needs a renderer (not --headless):
#   SPIKE_OUT=<dir> Godot --fixed-fps 60 --path godot -s res://tests/spike/spike_panes.gd [-- --sizes=184x128,160x180,180x160]
# Writes <dir>/pane_<WxH>_<tag>.png (3x nearest) and prints OFF (text outside the pane) / OVL (text overlaps) per screen.

const Lib := preload("res://tests/spike/spike_lib.gd")
const PixelFont := preload("res://scripts/pixelfont.gd")

var sizes: Array = [Vector2i(184, 128), Vector2i(160, 180), Vector2i(180, 160)]
var out := ""
var sv: SubViewport
var tot_off := 0
var tot_ovl := 0
var cur := Vector2i.ZERO


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sizes="):
			sizes = []
			for s in arg.substr(8).split(","):
				var p := s.split("x")
				sizes.append(Vector2i(int(p[0]), int(p[1])))
	out = Lib.out_dir()
	change_scene_to_file("res://scenes/main_floor.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _shot(tag: String) -> void:
	await _wait(3)
	var lines: Array = PixelFont.audit_report(tag, true)
	var off := 0
	var ovl := 0
	for l in lines:
		if str(l).begins_with("OFFSCREEN"):
			off += 1
			print("  ", l)
		else:
			ovl += 1
			print("  ", l)
	tot_off += off
	tot_ovl += ovl
	var img := sv.get_texture().get_image()
	var nonblank := img != null and not img.is_empty()
	if nonblank:
		Lib.save_scaled(img, "%s/pane_%dx%d_%s.png" % [out, cur.x, cur.y, tag], 3)
	print("SHOT %dx%d %-16s off=%d ovl=%d img=%s" % [cur.x, cur.y, tag, off, ovl, nonblank])
	PixelFont.audit = []


func _run() -> void:
	while current_scene == null:
		await process_frame
	await _wait(10)
	var camp := root.get_node("Campaign")
	camp.save_prefix = "user://test_spike_%d_" % OS.get_process_id()
	root.get_node("Difficulty").settings_path = "user://test_spike_%d_settings.cfg" % OS.get_process_id()
	camp.new_game("tech")
	camp.day = 9
	root.get_node("World").clock = 9.4
	var sk := root.get_node("Skills")
	sk.ps_level = 2
	sk.xp["servers"] = 60
	root.get_node("Expo").went = true
	var nerds := root.get_node("Nerds")
	nerds.karma = 24
	var msp := root.get_node("Msp")
	var t0: Dictionary = msp.create_ticket(0, 0, "spike")
	var t1: Dictionary = msp.create_ticket(1, 1, "spike")
	msp.create_ticket(2, 2, "spike")
	msp.create_ticket(3, 5, "spike")
	msp.create_ticket(4, 3, "spike")
	var game := root.get_node("Game")
	PixelFont.audit = []
	for size in sizes:
		cur = size
		sv = Lib.make_pane(root, size)
		var comp = Lib.pane_script("res://scripts/computer.gd").new()
		comp.pad_device = 1
		sv.add_child(comp)
		await _wait(2)
		comp.open(2)
		await create_timer(0.4).timeout
		print("== pane %s: global Game.ui_open=%s (must stay false), Computer autoload open=%s" % [size, game.ui_open, root.get_node("Computer").is_open])
		await _shot("desktop")
		var apps := ["mail", "psa", "rmm", "learn", "stats", "lync", "nerds", "dash", "boardroom"]
		# mail
		comp.activate("app:mail")
		await _shot("mail_list")
		comp.activate("mail:1")
		await _shot("mail_read")
		comp.activate("mback")
		# psa
		comp.activate("app:psa")
		await _shot("psa_board")
		comp.activate("tk:%d" % t1.id)
		await _shot("psa_ticket")
		comp.activate("close")
		await _shot("psa_close_ask")
		comp.activate("closeno")
		comp.activate("back")
		# rmm
		comp.activate("app:rmm")
		await _shot("rmm_tree")
		comp.activate("client:%d" % t1.client)
		comp.activate("rmm:" + t1.endpoint)
		await _shot("rmm_detail")
		comp.activate("connect")
		await _shot("rmm_session")
		comp.activate("disc")
		comp.activate("rback")
		comp.activate("tab:backups")
		await _shot("rmm_backups")
		comp.activate("tab:project")
		await _shot("rmm_project")
		comp.activate("tab:endpoints")
		# learn
		comp.activate("app:learn")
		await _shot("learn_list")
		comp.activate("lesson:0")
		await _shot("learn_lesson")
		comp.activate("lback")
		# profile
		comp.activate("app:stats")
		await _shot("profile")
		# lync
		comp.activate("app:lync")
		await _shot("lync")
		# nerds
		comp.activate("app:nerds")
		comp.forum.reset()
		nerds.reset()
		nerds.karma = 24
		nerds.ensure_threads()
		await _shot("forum_index")
		comp.activate("nerds:board:0")
		await _shot("forum_board")
		comp.activate("nerds:tab:irc")
		await _shot("irc_chat")
		comp.activate("nerds:view:who")
		await _shot("irc_who")
		comp.activate("nerds:tab:forum")
		# metrics
		comp.activate("app:dash")
		await create_timer(0.5).timeout
		await _shot("metrics")
		# boardroom
		comp.activate("app:boardroom")
		for tab in ["books", "clients", "projects", "team", "stack"]:
			comp.activate("btab:" + tab)
			await _shot("board_" + tab)
		comp.activate("close_app")
		# a pad-only keyboard click path: moves + confirm through parse_input_event(device 1)
		comp.close()
		await create_timer(0.3).timeout
		# open_site
		var info := {
			"name": "BRIGHTSIDE REALTY", "type": "office", "obj": "pc", "wall": "#CFE8EE", "accent": "#2E9AB8",
			"pc": "BSR-PC1", "user": "KIM", "app": "PRACTICE", "title": "LISTINGS",
			"rows": ["12 OAK ST   OPEN HOUSE", "44 ELM AVE   PENDING", "9 PINE CT   NEW"],
			"mails": [["Kim Park", "HELP: PRINTER SAYS NO"], ["Sam", "LUNCH?"]], "net": "CONNECTED",
		}
		comp.open_site(info)
		await create_timer(0.4).timeout
		await _shot("site_desktop")
		for v in ["practice", "mail", "computer", "tools"]:
			comp.activate("site:" + v)
			await _shot("site_" + v)
		comp.close()
		await create_timer(0.3).timeout
		# ---- phone
		var ph = Lib.pane_script("res://scripts/phone.gd").new()
		ph.save_path = "user://test_spike_%d_phone.cfg" % OS.get_process_id()
		sv.add_child(ph)
		await _wait(2)
		ph.os = ""
		ph.open()
		await create_timer(0.4).timeout
		await _shot("phone_choose")
		for os_name in ["ios", "android"]:
			ph.activate("os:" + os_name)
			await _shot("phone_%s_home" % os_name)
			for a in ["mail", "tickets", "texts", "settings"]:
				ph.activate("app:" + a)
				if a == "mail":
					ph.activate("mail:1")
				if a == "tickets":
					ph.activate("tk:%d" % t0.id)
				await _shot("phone_%s_%s" % [os_name, a])
				ph.back()
			ph.activate("home")
		ph.close()
		await create_timer(0.3).timeout
		# ---- cards in a pane (second Cards instance), then the day report
		var cards = Lib.pane_script("res://scripts/cards.gd").new()
		sv.add_child(cards)
		await _wait(2)
		cards.ask("MAYA", "THE CLIENT WANTS A DISCOUNT ON THE RENEWAL BECAUSE THE PRINTER KEPT JAMMING LAST MONTH AND THEY HAVE A COMPETITOR QUOTE. WHAT DO YOU SAY?", [
			{"label": "OFFER 10 PERCENT OFF", "id": "a"}, {"label": "HOLD THE PRICE AND OFFER A FREE PRINTER CHECK", "id": "b"},
			{"label": "ESCALATE TO THE OWNER", "id": "c"}, {"label": "NOT NOW", "id": "__none"}], func(_id: String) -> void: pass)
		await create_timer(0.1).timeout
		await _shot("card_long")
		cards.pick(3)
		cards.ask("DAN", "SHORT ONE?", [{"label": "YES", "id": "y"}, {"label": "NO", "id": "n"}], func(_id: String) -> void: pass)
		await _shot("card_short")
		cards.pick(0)
		var rep = Lib.pane_script("res://scripts/day_report.gd").new()
		sv.add_child(rep)
		await _wait(2)
		var r := {
			"day": 7, "total_days": 20, "closed": 6, "missed": 1, "reopened": 0, "open_left": 2, "clients": 72,
			"points": 14, "overtime": 1.5, "social": 3, "energy": 31, "late": 25, "oncall": 1, "pay": 340,
			"rep_delta": 3, "rep": 53, "cash": 1280, "grade": "B", "fired": false, "final": false, "ending": "",
		}
		rep.show_report(r)
		await create_timer(0.5).timeout
		await _shot("day_report_tech")
		r["title"] = "WEEK 9 OF 20 COMPLETE"
		r["grade"] = "A"
		r["rows"] = [
			["REVENUE", "$6400", Color("8fe3a0")], ["PAYROLL (W-2)", "-$3100", Color.WHITE],
			["OTHER COSTS + MARKETING", "-$1300", Color.WHITE], ["JOBS AND DEALS", "+$450", Color("8fe3a0")],
			["EBITDA", "$2450", Color("8fe3a0")], ["EBITDA MARGIN", "38% (PEERS 15%)", Color("8fe3a0")],
			["W-2 RATIO", "48% (TARGET 55%)", Color("8fe3a0")], ["CASH", "$9800", Color("8fe3a0")],
			["CLIENTS, A/R OWED", "8 (70%), $1200", Color("ffd27a")], ["OWNER HOURS", "22 FREE", Color.WHITE],
			["PARTNER TRUST", "GARRISON 55 (SOLID)", Color.WHITE], ["PERSONAL GOAL", "A CLEAN YEAR: 3/3 ON TRACK", Color.WHITE],
			["RECURRING + PROJECTS", "$6400/WK + $450 JOBS", Color("8fe3a0")],
			["VALUE (ESTIMATE)", "$412000, A GROWTH COMPANY", Color("ffd27a")],
		]
		rep.show_report(r)
		await create_timer(0.5).timeout
		await _shot("day_report_owner")
		rep.is_open = false  # NOT finish(): that would advance the campaign
		sv.get_parent().get_parent().queue_free()
		await _wait(3)
	print("TOTAL off=%d ovl=%d" % [tot_off, tot_ovl])
	quit(0)
