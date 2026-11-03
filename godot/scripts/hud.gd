extends Node2D
# A tiny pixel clock in the top-right corner (3x5 digits drawn with rectangles). F10 hides it.

const GLYPHS := {
	"0": ["XXX", "X.X", "X.X", "X.X", "XXX"],
	"1": [".X.", "XX.", ".X.", ".X.", "XXX"],
	"2": ["XXX", "..X", "XXX", "X..", "XXX"],
	"3": ["XXX", "..X", "XXX", "..X", "XXX"],
	"4": ["X.X", "X.X", "XXX", "..X", "..X"],
	"5": ["XXX", "X..", "XXX", "..X", "XXX"],
	"6": ["XXX", "X..", "XXX", "X.X", "XXX"],
	"7": ["XXX", "..X", "..X", ".X.", ".X."],
	"8": ["XXX", "X.X", "XXX", "X.X", "XXX"],
	"9": ["XXX", "X.X", "XXX", "..X", "XXX"],
	":": ["...", ".X.", "...", ".X.", "..."],
}

const PixelFont := preload("res://scripts/pixelfont.gd")

var _acc := 0.0


func _process(delta: float) -> void:
	visible = World.hud_visible and not DayReport.is_open
	_acc += delta
	if _acc > 0.25:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var text: String = World.clock_text()
	var width := text.length() * 4 - 1
	var origin := Vector2(get_viewport_rect().size.x - width - 3.0, 3.0)
	for pass_index in 2:
		var shade := pass_index == 0
		var color := Color(0.09, 0.07, 0.12, 0.9) if shade else Color(1, 1, 1, 0.95)
		var offset := Vector2(1, 1) if shade else Vector2.ZERO
		for i in text.length():
			var rows: Array = GLYPHS.get(text[i], GLYPHS["0"])
			for y in 5:
				for x in 3:
					if String(rows[y])[x] == "X":
						draw_rect(
							Rect2(origin + offset + Vector2(i * 4 + x, y), Vector2.ONE), color
						)
	if not Game.title_mode:
		var counts := "TKT %d MAIL %d" % [Msp.open_tickets().size(), Msp.unread()]
		if Msp.unread_texts() > 0:
			counts += " TXT %d" % Msp.unread_texts()
		if Lync.unread_total() > 0:
			counts += " IM %d" % Lync.unread_total()
		var lines := [counts]
		if Campaign.active:
			if Campaign.mode == "owner":
				lines.append(
					"WEEK %d/%d CASH $%d" % [Campaign.day, Campaign.TOTAL_DAYS, Owner.cash]
				)
			else:
				var day_line := (
					"DAY %d/%d REP %d" % [Campaign.day, Campaign.TOTAL_DAYS, Campaign.rep]
				)
				if Shift.active():
					day_line += (
						" NRG %d%s" % [int(Shift.energy), " ON CALL" if Shift.is_on_call() else ""]
					)
				lines.append(day_line)
		if Nerf.holding():
			if Nerf.charging:
				lines.append("AIMING %d%%  RELEASE Z TO FIRE" % int(Nerf.charge * 100.0))
			else:
				lines.append(
					(
						"DARTS %d  Z FIRE (HOLD = FAR)  G AWAY%s"
						% [Nerf.ammo, ("  WAR %d" % int(Nerf.war_t)) if Nerf.war_t > 0.0 else ""]
					)
				)
		for i in lines.size():
			PixelFont.draw(self, lines[i], Vector2(4, 4 + i * 8), Color(0.09, 0.07, 0.12, 0.9))
			PixelFont.draw(self, lines[i], Vector2(3, 3 + i * 8), Color(1, 1, 1, 0.95))
		if Hints.toast_text != "" and not Game.ui_open:
			_draw_hint(Hints.toast_text)
		elif Hints.text != "" and not Game.ui_open:
			_draw_hint(Hints.text)
		elif Hints.objective != "" and not Game.ui_open:
			_draw_hint(Hints.objective)


func _draw_hint(text: String) -> void:
	var size := get_viewport_rect().size
	var chars := int((size.x - 16.0) / 4.0)
	var words := text.split(" ")
	var rows := []
	var line := ""
	for word in words:
		if line != "" and line.length() + 1 + word.length() > chars:
			rows.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	rows.append(line)
	var h := float(rows.size()) * 7.0 + 5.0
	draw_rect(Rect2(4.0, size.y - h - 4.0, size.x - 8.0, h), Color(0.04, 0.03, 0.08, 0.8))
	for i in rows.size():
		PixelFont.draw(
			self, str(rows[i]), Vector2(8.0, size.y - h + 0.0 + float(i) * 7.0), Color("ffe08a")
		)
