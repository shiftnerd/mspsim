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
const PadGlyphs := preload("res://scripts/pad_glyphs.gd")  # R14: pad buttons in a hint are small sprites
const Goals := preload("res://scripts/goals.gd")  # R16: today's goal and the next-up list
const Micro := preload("res://scripts/micro.gd")

var _acc := 0.0


# a panel with its own title bar is up: the strip would sit over its heading
func modal_open() -> bool:
	if DayReport.is_open or Cards.is_open or Review.is_open or PrinterGame.is_open:
		return true
	return Outings.is_open and not (Outings.room_mode() and Outings.phase == "play")


func _process(delta: float) -> void:
	# the card header sits over the HUD text, so hide it while a card or any panel is up
	visible = World.hud_visible and not modal_open()
	Micro.tick()
	_acc += delta
	if not Phone.banner.is_empty():
		queue_redraw()  # the notification banner slides every frame
	if _acc > 0.25:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var text: String = World.clock_text()
	var width := text.length() * 4 - 1
	var origin := Vector2(get_viewport_rect().size.x - width - 3.0, 3.0)
	# the same soft dark plate as the goal chip: white text over the ceiling's lamps did not read (QA in a real window)
	draw_rect(Rect2(origin.x - 2.0, 1.0, float(width) + 5.0, 8.0), Goals.BACK)
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
		var counts := "TKT %d MAIL %d" % [Msp.open_tickets().size(), mini(Msp.unread(), 99)]
		if Campaign.active and Campaign.prop("hud", "day_rep") == "week_cash":
			counts = "TKT %d" % Msp.open_tickets().size()  # X9: the owner's mail is not a counter to clear
		if Msp.unread_texts() > 0:
			counts += " TXT %d" % Msp.unread_texts()
		if Lync.unread_total() > 0:
			counts += " IM %d" % Lync.unread_total()
		var lines := [counts]
		if Campaign.active:
			if Campaign.prop("hud", "day_rep") == "week_quota":
				lines.append("WEEK %d/%d %s %d%% HRS %d" % [Campaign.day, Campaign.total_days(), SalesCampaign.quarter_label(), SalesCampaign.quota_pct(), SalesCampaign.slots_left()])
			elif Campaign.prop("hud", "day_rep") == "week_cash":
				lines.append(
					"%s %d/%d CASH $%d" % [Campaign.prop("unit", "DAY"), Campaign.day, Campaign.total_days(), Owner.cash]
				)
			else:
				var day_line := (
					"%s %d/%d %s %d" % [Campaign.prop("unit", "DAY"), Campaign.day, Campaign.total_days(), Campaign.prop("rep_label", "REP"), Campaign.rep]
				)
				if Shift.active():
					day_line += (
						" NRG %d%s" % [int(Shift.energy), " ON CALL" if Shift.is_on_call() else ""]
					)
				lines.append(day_line)
		if Yeartwo.active():
			lines.append(Yeartwo.label())  # YEAR 2 / YEAR 3
		if Mutators.tag() != "":
			lines.append("* " + Mutators.tag())
		if Nerf.holding():
			if Nerf.charging:
				lines.append(Controls.world_hint("AIMING %d%%  RELEASE Z TO FIRE" % int(Nerf.charge * 100.0)))
			else:
				var war := ("WAR %d%s" % [int(Nerf.war_t), Nerf.hud_extra()]) if Nerf.war_t > 0.0 else ""
				if get_viewport_rect().size.x < 260.0:  # narrow formats: the war status gets its own line
					lines.append(Controls.world_hint("DARTS %d  Z FIRE{ (HOLD = FAR)|}  {G} AWAY" % Nerf.ammo))
					if war != "":
						lines.append(war)
				else:
					lines.append(Controls.world_hint("DARTS %d  Z FIRE (HOLD = FAR)  {G} AWAY" % Nerf.ammo) + (("  " + war) if war != "" else ""))
		var seat_line := -1  # X13: seated, the line says what the use button will do (Player.seat_target decides both)
		var p1 := Players.player0()
		if p1 != null and not Game.ui_open and not Game.busy and not Cards.is_open and p1.seat_hint() != "":
			seat_line = lines.size()
			lines.append(Controls.keys(p1.seat_hint()))
		var p2 := Players.node(1) if Players.coop else null
		if p2 != null and str(p2.held) == "nerf":
			lines.append("P2 AIMING %d%%" % int(Nerf._charges[1] * 100.0) if Nerf.is_charging(1) else "P2 DARTS %d" % Nerf._ammo[1])
		var widest := 0
		for line in lines:
			widest = maxi(widest, PixelFont.width(str(line)))
		draw_rect(Rect2(1.0, 1.0, float(widest) + 5.0, float(lines.size()) * 8.0), Goals.BACK)
		for i in lines.size():
			if i == seat_line:  # a pad's button is drawn as its glyph
				PadGlyphs.draw(self, lines[i], Vector2(4, 4 + i * 8), Color(0.09, 0.07, 0.12, 0.9), 1, true)
				PadGlyphs.draw(self, lines[i], Vector2(3, 3 + i * 8), Color(1, 1, 1, 0.95), 1, true)
				continue
			PixelFont.draw(self, lines[i], Vector2(4, 4 + i * 8), Color(0.09, 0.07, 0.12, 0.9))
			PixelFont.draw(self, lines[i], Vector2(3, 3 + i * 8), Color(1, 1, 1, 0.95))
		if Phone.banner.is_empty():
			Goals.draw(self, lines.size())
		if Hints.toast_text != "" and not Game.ui_open:
			_draw_hint(Hints.toast_text)
		elif Hints.text != "" and not Game.ui_open:
			_draw_hint(Hints.text)
		elif Hints.objective != "" and not Game.ui_open:
			_draw_hint(Hints.objective)
		if not Phone.banner.is_empty():
			_draw_banner()


# R37: a phone notification slides in from the top for about two and a half seconds (iFone: rounded grey card; Nexxus:
# flat black card with a teal edge). Phone queues them while a card, the day report or any panel is up.
func _draw_banner() -> void:
	var size := get_viewport_rect().size
	var b: Dictionary = Phone.banner
	var ios: bool = Phone.os != "android"
	var h := 15.0
	var w := minf(size.x - 8.0, 150.0)
	if size.x < 220.0:
		w = size.x  # the portrait screen: the card spans it, or the ends of the status lines and the clock stuck out at its sides
	var x := floorf((size.x - w) * 0.5)
	var y := floorf(-h - 1.0 + (h + 3.0) * Phone.banner_slide())
	var kind_color: Color = Phone.KIND_COLORS.get(b.kind, Color.WHITE)
	if ios:
		draw_rect(Rect2(x + 1.0, y, w - 2.0, h), Color(0.11, 0.12, 0.15, 0.94))
		draw_rect(Rect2(x, y + 1.0, w, h - 2.0), Color(0.11, 0.12, 0.15, 0.94))
		draw_rect(Rect2(x + 1.0, y + h - 1.0, w - 2.0, 1.0), Color(1, 1, 1, 0.15))
	else:
		draw_rect(Rect2(x, y, w, h), Color(0.03, 0.03, 0.04, 0.96))
		draw_rect(Rect2(x, y + h - 1.0, w, 1.0), Color("33b5e5"))
	draw_rect(Rect2(x + 3.0, y + 3.0, 5.0, 5.0), kind_color)
	var chars := int((w - 14.0) / 4.0)
	var head := "%s  %s" % [b.kind, str(b.who)]
	var body := Controls.keys(str(b.body))  # R42: a text message may name a key ("Press {P} for your phone")
	if head.length() > chars:
		head = head.substr(0, chars - 1) + "."
	if body.length() > chars:
		body = body.substr(0, chars - 1) + "."
	PixelFont.draw(self, head, Vector2(x + 11.0, y + 2.0), Color.WHITE)
	PadGlyphs.draw(self, body, Vector2(x + 11.0, y + 8.0), Color(0.78, 0.8, 0.86), 1, true)


func _draw_hint(raw: String) -> void:
	var text := Controls.world_hint(raw)  # R34: a remapped key (or a pad) shows what works now
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
		PadGlyphs.draw(
			self, str(rows[i]), Vector2(8.0, size.y - h + 0.0 + float(i) * 7.0), Color("ffe08a")
		)
