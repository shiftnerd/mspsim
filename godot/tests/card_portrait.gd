extends SceneTree
# gdlint:disable=max-line-length
# R10: the speaker's face on a decision card (scripts/card_portrait.gd): a speaker line maps to a character, the head crop of that
# character's first idle frame has the head in it (hair to chin, nothing of the shoulders), people without a character get none,
# and a card from such a speaker opens and paints without a picture asked for. `tests/layout_audit.gd` draws the cards in every format.
# `Godot --headless --fixed-fps 60 --path godot -s res://tests/card_portrait.gd`

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	await process_frame
	var P: Script = load("res://scripts/card_portrait.gd")
	var want := {
		"Quinn": "office_quinn", "Ross Calder": "office_ross", "Terry Vance (Recruiter)": "office_terry", "Trent Dagmar": "office_trent",
		"Ms. Pell": "office_pell", "Morgan": "office_morgan", "MORGAN (MANAGER)": "office_morgan", "Christy": "office_christy",
	}
	for who in want:
		_check(P.character_for(who) == want[who], "%s is %s (%s)" % [who, want[who], P.character_for(who)])
	_check(P.character_for("THE TONER SUPPLIER") == "" and P.head("THE TONER SUPPLIER") == null and P.head("") == null, "a speaker with no character gets no portrait")
	for who in ["Quinn", "Ross Calder", "Terry Vance", "Trent Dagmar", "Ms. Pell", "Morgan", "Alan"]:
		var tex: Texture2D = P.head(who)
		_check(tex != null and Vector2i(tex.get_size()) == Vector2i(26, 22), "%s has a 26 x 22 head" % who)
		if tex == null:
			continue
		var img := tex.get_image()
		var opaque := 0
		var top_row := 0
		var bottom_row := 0
		for y in 22:
			for x in 26:
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					if y == 0:
						top_row += 1
					if y == 21:
						bottom_row += 1
					opaque += 1
		_check(opaque > 300 and top_row > 0 and bottom_row > 0, "%s: the crop holds the head (%d of 572 pixels drawn, hair on the top row, the chin on the bottom row)" % [who, opaque])
	var first: Texture2D = P.head("Quinn")
	_check(first == P.head("Quinn"), "the crops are cached")
	# the open card: a speaker with a face and one without both open and paint at the wide size
	var cards := root.get_node("Cards")
	root.get_node("Game").title_mode = false
	for who in ["Ross Calder", "THE TONER SUPPLIER"]:
		cards.ask(who, "A SHORT LINE OF TEXT THAT WRAPS ONTO A SECOND AND A THIRD LINE SO THE FACE COLUMN HAS SOMETHING TO SIT NEXT TO.", [{"label": "FINE", "id": "a"}], func(_id: String) -> void: pass)
		await process_frame
		await process_frame
		_check(cards.is_open and cards.speaker == who, "%s: the card is open" % who)
		cards.pick(0)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
