extends SceneTree
# gdlint:disable=max-line-length
# Dev tool (slug soak-sim, not in the default suite): long bot runs of the simulation that fail on errors, stalls, growth and bad saves.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/soak_sim.gd -- --cells=tech1,owner2 --tiers=easy,normal --strats=careful,chaotic --seeds=3 --minutes=30 --out=C:/x/soak.jsonl
# Words (all `--name=value`):
#   --cells=     comma list of cell names (default: tech1). A name is one of
#                  tech1 tech2 tech3 owner1 owner2 owner3 sales1 sales2 sales3 service1 service2 service3   campaigns by year
#                  coop_tech coop_owner coop_sales coop_service     two-pilot runs
#                  free            Free Play with every mutator (one run per mutator)
#                  outings         every outing started from Free Play (bowling, karaoke songs, escape themes x recipes, dinner, chair, cornhole, grill, darts, paintball)
#                  nerf printer expo saves ablate
#                  all             every campaign cell
#   --tiers=     easy,normal,hard   --strats= careful,lazy,mixed,chaotic   --seeds=N (default 3)   --first=K (first seed, default 1)
#   --pairs=easy:careful,normal:lazy   only these tier:strategy pairs (seeds rotate)
#   --cover      instead of the full tier x strategy x seed product, run every (tier, strategy) pair once per cell, rotating the seed
#   --chaos      every campaign cell also gets the chaotic hands (random screens, pace / day length / tier changes, skipped days)
#   --reload     reload the end-of-day save at the morning of every day and compare (default on for campaign cells; --reload=0 off)
#   --resumes=N  N random mid-day resume points per campaign run (default 0)
#   --minutes=N  wall-clock budget: no new cell starts after N minutes (default 0 = no limit)
#   --ts=N       bot time compression (default 20; owner 4)   --max_frames=N per run
#   --out=PATH   append one JSON line per cell   --preset=fast the smoke preset   --skip=K  skip the first K cells (continue a chunk)   --list  print the cells and exit
# Prints a `SOAK` line per cell (ok / FAIL and what), `SOAKERR` lines for every captured error, and a `SOAKSUM` line. Exit 1 on any failure.

const THEMES := ["study", "server", "detective", "lab"]
const SONGS := ["rock", "ballad", "pop"]


func _init() -> void:
	_run.call_deferred()


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--%s=" % name):
			return s.substr(name.length() + 3)
	return default


func _flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + name)


func _run() -> void:
	await process_frame
	var lib: RefCounted = load("res://tests/soak_lib.gd").new(self)
	lib.install_capture()
	lib.verbose = _flag("verbose")
	if _arg("ts", "") != "":
		lib.ts = float(_arg("ts", "20"))
	var cells := _expand(lib)
	var skip := int(_arg("skip", "0"))
	if _flag("list"):
		for i in cells.size():
			print("%d %s" % [i, lib.cfg_text(cells[i])])
		quit(0)
		return
	var minutes := float(_arg("minutes", "0"))
	var out_path := _arg("out", "")
	var t0 := Time.get_ticks_msec()
	var runs := 0
	var fails := 0
	var days := 0
	var errs := 0
	var stuck := 0
	var started := 0
	for i in range(skip, cells.size()):
		if minutes > 0.0 and float(Time.get_ticks_msec() - t0) > minutes * 60000.0:
			print("SOAKSTOP budget used after cell %d of %d (resume with --skip=%d)" % [i - 1, cells.size(), i])
			break
		started += 1
		var cell: Dictionary = cells[i]
		for k in ["max_frames"]:
			if _arg(k, "") != "":
				cell[k] = int(_arg(k, "0"))
		var res: Dictionary = await lib.run_cell(cell)
		runs += 1
		days += int(res.days)
		errs += (res.errors as Array).size()
		stuck += 0 if (res.stuck as Dictionary).is_empty() else 1
		fails += 0 if bool(res.ok) else 1
		var why: Array = []
		if not (res.errors as Array).is_empty():
			why.append("%d errors" % (res.errors as Array).size())
		if not (res.stuck as Dictionary).is_empty():
			why.append("STUCK")
		why.append_array(res.flags)
		why.append_array(res.save_fail)
		why.append_array(res.resume_fail)
		print("SOAK %s #%d %s | days %d frames %d saves %d resumes %d %.0fs | %s%s" % ["ok  " if bool(res.ok) else "FAIL", i, res.cfg, int(res.days), int(res.frames), int(res.saves), int(res.resumes), float(res.secs), str(res.info), "" if bool(res.ok) else " | " + "; ".join(why)])
		for e in res.errors:
			print("SOAKERR [%s] %s :: %s" % [e.kind, e.cfg, e.text])
		if not (res.stuck as Dictionary).is_empty():
			print("SOAKSTUCK %s :: %s" % [res.cfg, JSON.stringify(res.stuck)])
		if out_path != "":
			var f := FileAccess.open(out_path, FileAccess.READ_WRITE) if FileAccess.file_exists(out_path) else FileAccess.open(out_path, FileAccess.WRITE)
			if f != null:
				f.seek_end()
				f.store_line(JSON.stringify(res))
				f.close()
	print("SOAKSUM runs %d fails %d errors %d stuck %d game-days %d minutes %.1f" % [runs, fails, errs, stuck, days, float(Time.get_ticks_msec() - t0) / 60000.0])
	quit(1 if fails > 0 else 0)


# ---- the cell list -------------------------------------------------------------------------------------------------------------
func _expand(lib: RefCounted) -> Array:
	if _arg("preset", "") == "fast":
		return lib.fast_preset()
	var names := _arg("cells", "tech1").split(",", false)
	var tiers := _arg("tiers", "easy,normal,hard").split(",", false)
	var strats := _arg("strats", "careful,lazy,mixed,chaotic").split(",", false)
	var seeds := int(_arg("seeds", "3"))
	var first := int(_arg("first", "1"))
	var chaos := _flag("chaos")
	var reload := _arg("reload", "1") != "0"
	var resumes := int(_arg("resumes", "0"))
	var out: Array = []
	var all_names: Array = []
	for name in names:
		if str(name) == "all":
			for m in ["tech", "owner", "sales", "service"]:
				for y in [1, 2, 3]:
					all_names.append("%s%d" % [m, y])
		else:
			all_names.append(str(name))
	for name in all_names:
		var n := str(name)
		if n.length() > 1 and n.left(n.length() - 1) in ["tech", "owner", "sales", "service"] and n.right(1) in ["1", "2", "3"]:
			var mode := n.left(n.length() - 1)
			var year := int(n.substr(n.length() - 1))
			var combos: Array = []
			if _arg("pairs", "") != "":  # --pairs=easy:careful,normal:lazy: just these (tier:strategy) pairs, seeds rotating
				var k2 := 0
				for pr in _arg("pairs", "").split(",", false):
					combos.append({"tier": pr.get_slice(":", 0), "strat": pr.get_slice(":", 1), "seed": first + (k2 % seeds)})
					k2 += 1
			elif _flag("cover"):
				var k := 0
				for tier in tiers:
					for strat in strats:
						combos.append({"tier": tier, "strat": strat, "seed": first + (k % seeds)})
						k += 1
			else:
				for tier in tiers:
					for strat in strats:
						for s in seeds:
							combos.append({"tier": tier, "strat": strat, "seed": first + s})
			for cb in combos:
				var cell := {"kind": "campaign", "mode": mode, "year": year, "tier": cb.tier, "strat": cb.strat, "seed": cb.seed, "reload": reload, "resumes": resumes}
				if chaos or cb.strat == "chaotic" and _flag("chaosbot"):
					cell["chaos"] = true
				out.append(cell)
		elif n.begins_with("coop_"):
			for tier in tiers:
				for s in seeds:
					out.append({"kind": "campaign", "mode": n.substr(5), "year": 1, "tier": tier, "strat": str(strats[s % strats.size()]), "seed": first + s, "coop": true, "reload": reload, "chaos": chaos})
		elif n == "free":
			var mids: Array = [""]
			mids.append_array(load("res://scripts/mutators.gd").new().MUTATORS.keys())
			for mid in mids:
				for s in seeds:
					out.append({"kind": "free", "mut": mid, "tier": tiers[s % tiers.size()], "strat": strats[s % strats.size()], "seed": first + s, "chaos": chaos, "sim_secs": 120.0})
		elif n == "outings":
			out.append_array(outing_cells(seeds, first, tiers))
		elif n == "nerf":
			for mid in ["", "cup", "elim", "team", "hide"]:
				for scene in ["main_floor", "cubicles"]:
					for s in seeds:
						out.append({"kind": "nerf", "id": mid, "scene": scene, "seed": first + s})
		elif n == "printer":
			for model in ["laser", "inkjet", "plotter", "mfp", "receipt", "dot"]:
				for s in seeds:
					out.append({"kind": "printer", "model": model, "seed": first + s})
			for s in seeds:
				out.append({"kind": "printer", "model": "laser", "boss": true, "seed": first + s})
		elif n == "expo":
			for tier in tiers:
				for s in seeds:
					out.append({"kind": "expo", "mode": "tech", "tier": tier, "strat": strats[s % strats.size()], "seed": first + s, "reload": reload})
		elif n == "saves":
			for mode in ["tech", "owner", "sales", "service"]:
				for s in seeds:
					out.append({"kind": "saves", "mode": mode, "tier": tiers[s % tiers.size()], "strat": strats[s % strats.size()], "seed": first + s})
		elif n == "ablate":
			for mode in ["tech", "owner", "sales", "service"]:
				out.append({"kind": "ablate", "mode": mode, "seed": first})
	return out


func outing_cells(seeds: int, first: int, tiers: Array) -> Array:
	var out: Array = []
	var lib_recipes: Dictionary = load("res://scripts/outings.gd").RECIPES
	for s in seeds:
		var sd := first + s
		var tier := str(tiers[s % tiers.size()])
		out.append({"kind": "outing", "id": "bowling", "tier": tier, "seed": sd})
		out.append({"kind": "outing", "id": "dinner", "tier": tier, "seed": sd, "party": ["Alan", "Garrison", "Dan"], "variety": true})
		out.append({"kind": "outing", "id": "dinner", "tier": tier, "seed": sd, "party": ["Alan", "Garrison"], "variety": false})
		for song in SONGS:
			out.append({"kind": "outing", "id": "karaoke", "tier": tier, "seed": sd, "song": song})
		out.append({"kind": "outing", "id": "cornhole", "tier": tier, "seed": sd})
		out.append({"kind": "outing", "id": "grill", "tier": tier, "seed": sd, "party": ["Alan", "Garrison", "Dan"]})
		out.append({"kind": "outing", "id": "darts", "tier": tier, "seed": sd, "party": ["Alan", "Garrison"]})
		for ev in 3:
			out.append({"kind": "outing", "id": "chair", "tier": tier, "seed": sd, "party": ["Alan", "Garrison", "Dan", "Maya", "John"], "event": ["straight", "gauntlet", "fight"][ev]})
		for night in [false, true]:
			out.append({"kind": "outing", "id": "paintball", "tier": tier, "seed": sd, "night": night, "party": ["Alan", "Garrison", "Dan", "Maya", "John"]})
		# every escape theme x clue recipe
		for theme in THEMES:
			for zone in lib_recipes:
				for rc in lib_recipes[zone]:
					out.append({"kind": "outing", "id": "escape", "tier": tier, "seed": sd, "theme": theme, "recipes": {zone: rc}, "recipe": "%s:%s" % [zone, rc]})
	return out
