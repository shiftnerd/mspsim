extends SceneTree
# Client site leftovers: realty coffee bar and sign-in, architect reception, plotter text, business names on the signs.
# gdlint:disable=max-line-length

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _only_font_chars(s: String) -> bool:
	for ch in s:
		if not (ch >= "A" and ch <= "Z") and not (ch >= "0" and ch <= "9") and not " &.'-".contains(ch):
			return false
	return true


func _init() -> void:
	await process_frame
	var game := root.get_node("Game")
	var on := root.get_node("Onsite")
	var msp := root.get_node("Msp")
	var pg := root.get_node("PrinterGame")
	root.get_node("Campaign").save_prefix = "user://test_%d_" % OS.get_process_id()
	game.title_mode = false

	# signs: the a skins use the Msp.CLIENTS names, the b skins SITE_PROSPECT; all fit the 3x5 font and a sign
	for idx in on.SITES.keys():
		var t: String = on.site_type(idx)
		var full := str(msp.CLIENTS[idx].name).to_upper()
		var prospect := str(on.SITE_PROSPECT.get(t, ""))
		_check(full != "" and prospect != "" and full != prospect, "%s: client and prospect names differ" % t)
		for n: String in [full, prospect]:
			_check(_only_font_chars(n), "%s: '%s' uses only font characters" % [t, n])
			_check(n.length() * 4 + 8 <= 190, "%s: '%s' fits a sign (%d px)" % [t, n, n.length() * 4 + 8])

	# the architects: the reception desk and the plotter, staff off the player's start (x 150) and the zones
	for skin in ["a", "b"]:
		game.go("site_arch_" + skin, "start")
		await _wait(0.6)
		var sc := current_scene
		var names: Array = []
		for z in sc.find_children("UseObj*", "", true, false):
			names.append(str(z.name))
		_check("UseObjPc0" in names and "UseObjPrinter1" in names and "UseObjRecep" in names, "arch %s: PC and plotter zones" % skin)
		_check(sc.find_children("*ecep*", "", true, false).size() > 0, "arch %s: reception desk node" % skin)
		for p: Array in on.CAST_AT.arch[skin].main:
			_check(absf(float(p[1]) - 150.0) >= 20.0, "arch %s: %s stands clear of the player start" % [skin, p[0]])
			_check(absf(float(p[1]) - 256.0) >= 20.0 and absf(float(p[1]) - 244.0) >= 20.0, "arch %s: %s is off the PC zone" % [skin, p[0]])

	# realty: coffee bar and sign-in zones
	for skin in ["a", "b"]:
		game.go("site_realty_" + skin, "start")
		await _wait(0.6)
		var rn: Array = []
		for z in current_scene.find_children("UseObj*", "", true, false):
			rn.append(str(z.name))
		_check("UseObjCoffee" in rn and "UseObjSignin" in rn, "realty %s: coffee bar and sign-in zones" % skin)

	# printer game: the architects get the plotter, with its roll and ink wording
	on.client = 9
	_check(on._printer_model() == "plotter", "architect sites use the plotter model")
	pg.start(func(_s: int) -> void: pass, "plotter")
	_check(pg._tx("intro2").contains("FORTY-FOOT") and pg._tx("toner_help").contains("INK TANK"), "plotter intro mentions the forty-foot roll and ink tank")
	_check(pg._tray()[0] == "24 BOND", "plotter rolls, not paper")
	pg.is_open = false

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
