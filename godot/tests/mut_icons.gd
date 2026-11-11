extends SceneTree
# gdlint:disable=max-line-length
# R9: the fourteen mutator icons (assets/ui/mut_<id>.png, 12 x 12) on the Free Play toolbox's MUTATOR row and on the morning
# briefing card. In every screen format the icon is inside the viewport and inside its panel's column, and it covers no text
# (the row is 9 px, the icon 12: it overhangs into the padding, the text is not made smaller). Mutators.announce asks the
# briefing with its icon; a card without a mutator and the toolbox on NONE draw none.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/mut_icons.gd

const PixelFont := preload("res://scripts/pixelfont.gd")
const FORMATS := ["wide", "h", "deck", "v"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


# the texts a canvas drew in its newest frame that touch `rect`
func _covered(rect: Rect2) -> Array:
	var out := []
	for rec in PixelFont.audit:
		if (rec.rect as Rect2).intersects(rect):
			out.append(str(rec.text))
	return out


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var pid := OS.get_process_id()
	var game := root.get_node("Game")
	var c := root.get_node("Campaign")
	var muts := root.get_node("Mutators")
	var cards := root.get_node("Cards")
	var tb := root.get_node("Toolbox")
	c.save_prefix = "user://test_%d_muticons_" % pid
	root.get_node("Difficulty").settings_path = "user://test_%d_muticons_settings.cfg" % pid
	game.title_mode = false

	var all := true
	for id in muts.MUTATORS:
		var tex: Texture2D = muts.icon(str(id))
		all = all and tex != null and tex.get_size() == Vector2(12, 12)
	_check(all and muts.MUTATORS.size() == 14, "Mutators.icon() has a 12 x 12 picture for each of the %d mutators" % muts.MUTATORS.size())
	_check(muts.icon("") == null and muts.icon("no_such_week") == null, "none for no mutator or an unknown one")

	change_scene_to_file("res://scenes/main_floor.tscn")
	await _wait(20)
	for f in FORMATS:
		game.set_format(f)
		await _wait(3)
		var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		# ---- the toolbox's MUTATOR row, every mutator
		var tool_ok := true
		var tool_note := ""
		tb.open_tools(false, Callable())
		var row := -1
		for i in tb.rows().size():
			if str(tb.rows()[i].id) == "mutator":
				row = i
		_check(row >= 0, "%s: the toolbox has a MUTATOR row" % f)
		for id in muts.ids_for("tech"):
			tb.mutator = str(id)
			for hot in [false, true]:
				tb.sel = row if hot else 0
				PixelFont.audit = []
				tb._canvas.queue_redraw()
				await _wait(2)
				var r: Rect2 = tb.icon_drawn
				var over := _covered(r)
				if not r.has_area() or not vp.encloses(r) or not over.is_empty():
					tool_ok = false
					tool_note = "%s %s: rect %s over %s" % [id, "selected" if hot else "", str(r), str(over)]
				PixelFont.audit = null
		_check(tool_ok, "%s: every mutator's icon is on the MUTATOR row, on screen, over no text %s" % [f, tool_note])
		# the row's own rectangle is 9 px and the icon 12: it hangs over, by at most 2 px each way
		var row_rect: Rect2 = Rect2()
		for hit in tb._rects:
			if str(hit[1]) == "row" and int(hit[2]) == row:
				row_rect = hit[0]
		var icon: Rect2 = tb.icon_drawn
		_check(row_rect.has_area() and icon.position.y >= row_rect.position.y - 2.0 and icon.end.y <= row_rect.end.y + 2.0 and row_rect.size.y == 9.0, "%s: the row is still 9 px and the icon overhangs it by at most 2 px (row %s, icon %s)" % [f, str(row_rect), str(icon)])
		tb.mutator = ""
		tb._canvas.queue_redraw()
		await _wait(2)
		_check(not tb.icon_drawn.has_area(), "%s: NONE draws no icon" % f)
		tb.close()
		await _wait(2)
		# ---- the morning briefing card
		var card_ok := true
		var card_note := ""
		for id in muts.MUTATORS:
			var n := 0
			while cards.is_open and n < 10:
				cards.pick(0)
				n += 1
			PixelFont.audit = []
			cards.art_next = "mut_" + str(id)
			cards.ask("MORNING BRIEFING", "%s. %s" % [str(muts.MUTATORS[id].name), str(muts.MUTATORS[id].text)], [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
			await _wait(3)
			var r2: Rect2 = cards.icon_drawn
			var over2 := _covered(r2)
			if not r2.has_area() or not vp.encloses(r2) or not over2.is_empty():
				card_ok = false
				card_note = "%s: rect %s over %s" % [id, str(r2), str(over2)]
			PixelFont.audit = null
			cards.pick(0)
		_check(card_ok, "%s: every mutator's icon is on its briefing card, on screen, over no text %s" % [f, card_note])
		cards.ask("MORNING BRIEFING", "A quiet week.", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
		await _wait(3)
		_check(not cards.icon_drawn.has_area(), "%s: a card without a mutator has no icon" % f)
		cards.pick(0)
		cards.art_next = "tax"
		cards.ask("THE ACCOUNTANT", "It is that time of year.", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
		await _wait(3)
		_check(not cards.icon_drawn.has_area() and str(cards.art) == "tax", "%s: an event card's picture is not taken for an icon" % f)
		cards.pick(0)
	game.set_format("h")

	# ---- the real briefing: Mutators.announce asks the card with the icon
	c.new_game("tech")
	await _wait(5)
	var n2 := 0
	while cards.is_open and n2 < 20:
		cards.pick(0)
		n2 += 1
	muts.announce("heat_wave")
	await _wait(3)
	_check(cards.is_open and str(cards.speaker) == "MORNING BRIEFING" and str(cards.art) == "mut_heat_wave" and cards.icon_tex() == muts.icon("heat_wave") and cards.icon_drawn.has_area(), "the heat wave's briefing shows the heat wave's icon (art %s, drawn at %s)" % [cards.art, str(cards.icon_drawn)])
	cards.pick(0)

	print("done, failures: %d" % failures)
	quit(1 if failures > 0 else 0)
