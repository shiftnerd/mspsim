extends CanvasLayer
# Decision cards: a modal dialog with a speaker, some text and 2-4 options. Used when the
# account manager walks in with a client complaint, and for the owner campaign's business
# decisions. Up/Down + Enter, number keys 1-4, or click.
#   Cards.ask("John", "text...", [{"label": "I WILL PRIORITIZE IT", "id": "a"}, ...], on_pick)
# Options can be {"label", "id", "enabled": false, "hint": "why"} to show them greyed out.

const PixelFont := preload("res://scripts/pixelfont.gd")
const PadGlyphs := preload("res://scripts/pad_glyphs.gd")  # R42: a pad button named in a card is its sprite (the lines are cut as text, the glyph is narrower)
const INK := Color("17121f")
const WHITE := Color("ffffff")
const ART_MIN_W := 200.0  # R8: a card this wide or wider has room for its spot picture (34 x 26, assets/ui/card_<art>.png) beside the text
const ART_W := 36.0
const CardPortrait := preload("res://scripts/card_portrait.gd")  # R10: the speaker's face beside the text of a card with no spot picture
const FACE_W := 30.0  # the portrait column: a 1 px frame round the 26 x 22 head, and a gap
const FACE_H := 25.0

var is_open := false
var pane_slot := -1  # co-op: a personal card shown in this player's pane (panes.gd); -1 = the full-window team card
var speaker := ""
var text := ""
var options: Array = []
var sel := 0
var art := ""  # the picture of the open card (a season or a kind of event card), "" for none
var art_next := ""  # a caller sets this just before ask(): the picture of the card it is about to ask
var icon_drawn := Rect2()  # R9: where the open card's mutator icon was painted (no size = none), for tests
var _art_cache := {}  # art id -> Texture2D or null: kept here, a texture nobody holds is freed before the frame is drawn (a white box)

var _canvas: Node2D
var _callback := Callable()
var _hits: Array = []
var _mouse := Vector2.ZERO
var _queue: Array = []
var _opened := 0  # msec the card appeared: early confirms are ignored
var _draining := false  # _show_next is handing out the next queued card (it may skip the line)


func _ready() -> void:
	layer = 65
	_canvas = Node2D.new()
	_canvas.visible = false
	add_child(_canvas)
	_canvas.draw.connect(_paint)


# `valid` (optional) is checked again when a queued card finally comes up; if it says no the card is dropped
# and on_pick gets "__none" so the asker can clean up
func ask(
	who: String, body: String, choices: Array, on_pick: Callable, valid := Callable(), slot := -1
) -> void:
	var art_id := art_next
	art_next = ""
	if slot >= 0 and pane_slot < 0 and Players.coop and Players.slot(slot).joined:
		# co-op scope "player": the card appears in that player's pane and only they are held (a team card, slot -1, is the old full-window one)
		Players.takeover_host().card_for(slot).ask(who, body, choices, on_pick, valid)
		return
	# X9: every asked card is shown once, in the order asked. A card asked while another is open, while the
	# report covers the screen, or while older cards are still waiting joins the back of the queue.
	if is_open or DayReport.is_open or (not _queue.is_empty() and not _draining):
		_queue.append([who, body, choices, on_pick, valid, art_id])
		if not is_open and not DayReport.is_open:
			_show_next()
		return
	art = art_id
	speaker = Roles.speaker(Roles.fill(who))  # a card that names you comes from somebody else
	text = Roles.fill(body)  # {tech} {ops} {partner} {me} become names
	options = []
	for choice in choices:
		var entry: Dictionary = choice
		if str(entry.get("label", "")).find("{") >= 0:
			entry = entry.duplicate()
			entry["label"] = Roles.fill(str(entry.label)).to_upper()  # X9: the UI is all caps, names included
		options.append(entry)
	choices = options
	var any_enabled := false
	for opt in choices:
		any_enabled = any_enabled or bool(opt.get("enabled", true))
	if not any_enabled:
		# nothing affordable: a card must never trap the player (or hold the week report back)
		options = choices.duplicate()
		options.append({"label": "NOT NOW", "id": "__none"})
	sel = 0
	for i in options.size():
		if bool(options[i].get("enabled", true)):
			sel = i
			break
	_callback = on_pick
	is_open = true
	Career.add("cards_seen")  # R8: the career screen counts the decisions put in front of you
	_opened = Time.get_ticks_msec()
	Sfx.play("ui_open")
	if pane_slot < 0:
		Game.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Players.set_ui(pane_slot, true)
	_canvas.visible = true
	_mouse = get_viewport().get_mouse_position()
	_canvas.queue_redraw()


# a follow-up to the card that was just picked: it goes in front of cards that were already waiting
func ask_first(who: String, body: String, choices: Array, on_pick: Callable) -> void:
	_queue.push_front([who, body, choices, on_pick, Callable()])
	if not is_open and not DayReport.is_open:
		_show_next()


func pick(index: int) -> void:
	if is_open and index >= 0 and index < options.size() and not bool(options[index].get("enabled", true)):
		Sfx.play("ui_error")
	if (
		not is_open
		or index < 0
		or index >= options.size()
		or not bool(options[index].get("enabled", true))
	):
		return
	var id := str(options[index].id)
	Sfx.play("ui_pick")
	is_open = false
	_canvas.visible = false
	if pane_slot >= 0:  # the player is still held while their computer or phone pane is under the card
		var host: Node = Players.takeover_host()
		Players.set_ui(pane_slot, host.screen_open(pane_slot))
	else:
		Game.ui_open = Computer.is_open or Phone.is_open or PrinterGame.is_open or Outings.is_open or Toolbox.outfit_open
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if Game.ui_open else Input.MOUSE_MODE_VISIBLE
	if id != "__none" and _callback.is_valid():
		_callback.call(id)
	_show_next()


# the run is over (QUIT TO TITLE): drop the open card and every card waiting behind it, without answering them
func clear_all() -> void:
	_queue.clear()
	is_open = false
	_canvas.visible = false


# the next queued card whose reason still holds (a John complaint for a ticket that closed meanwhile is dropped)
func _show_next() -> void:
	while not _queue.is_empty() and not is_open and not DayReport.is_open:
		var next: Array = _queue.pop_front()
		var valid: Callable = next[4] if next.size() > 4 else Callable()
		if valid.is_valid() and not bool(valid.call()):
			if next[3].is_valid():
				next[3].call("__none")
			continue
		_draining = true
		art_next = str(next[5]) if next.size() > 5 else ""
		ask(next[0], next[1], next[2], next[3], valid)
		_draining = false


# cards that were asked while the day report covered the screen
func flush() -> void:
	if DayReport.is_open:
		return
	if is_open:
		_canvas.visible = true  # a card that opened under the report comes back after it
		_opened = Time.get_ticks_msec()
		_canvas.queue_redraw()
	else:
		_show_next()


# the weekly report is about to cover the screen: a card that is open waits underneath (its keys are ignored)
func cover() -> void:
	_canvas.visible = false


# how many cards wait to be shown (tests)
func waiting() -> int:
	return _queue.size()


# Esc picks the option whose id is "leave" (conversations)
func _pick_leave() -> void:
	for i in options.size():
		if str(options[i].id) in ["leave", "__none", "close"]:  # "close": the Free Play menu's CLOSE row, so Esc / B leave it too
			pick(i)
			return


func _move(step: int) -> void:
	Sfx.play("ui_tick")
	for _n in options.size():
		sel = (sel + step + options.size()) % options.size()
		if bool(options[sel].get("enabled", true)):
			break
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open or DayReport.is_open:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		for h in _hits:
			if h.r.has_point(_mouse) and int(h.i) < options.size() and bool(options[int(h.i)].get("enabled", true)):  # a greyed-out row is not selectable (Enter would do nothing)
				sel = int(h.i)
		_canvas.queue_redraw()
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		_mouse = event.position
		for h in _hits:
			if h.r.has_point(_mouse) and Time.get_ticks_msec() - _opened >= 450:
				pick(int(h.i))
				break
	elif Controls.pressed(event):
		var dir := Controls.nav(event, false)
		if dir == "up":
			_move(-1)
		elif dir == "down":
			_move(1)
		elif Controls.back_any(event, false):
			_pick_leave()
		elif Time.get_ticks_msec() - _opened < 450:
			pass  # too soon: the card just appeared
		elif Controls.confirm_any(event, false, false):
			pick(sel)
		elif Controls.digit(event) >= 1 and Controls.digit(event) <= 4:
			pick(Controls.digit(event) - 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _wrap(s: String, chars: int) -> Array:
	s = Controls.keys(s)  # R42: key tokens become the key or the pad button before the lines are cut
	var out := []
	var line := ""
	for word in s.split(" "):
		if line != "" and line.length() + 1 + word.length() > chars:
			out.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	out.append(line)
	return out


# the open card's spot picture, or null (none asked for, the file is missing)
func _art_tex() -> Texture2D:
	if not _art_cache.has(art):
		var path := "res://assets/ui/card_%s.png" % art
		_art_cache[art] = load(path) if art != "" and ResourceLoader.exists(path) else null
	return _art_cache[art]


# R9: an art id "mut_<id>" is a mutator's 12 x 12 icon (the morning briefing). It sits on the right end of the title bar
# and overhangs into the padding under it, so it takes no room from the text and every format shows it.
func icon_tex() -> Texture2D:
	return Mutators.icon(art.substr(4)) if art.begins_with("mut_") else null


func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_hits.clear()
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.45))
	var pw := minf(size.x - 8.0, 250.0)
	var chars := int((pw - 10.0) / 4.0)
	var art_tex: Texture2D = _art_tex() if pw >= ART_MIN_W else null  # a narrow card (the tall format) goes without the picture
	var face: Texture2D = CardPortrait.head(speaker) if art_tex == null and pw >= ART_MIN_W else null  # R10: no picture, then the speaker's face
	var lines := []
	var plain_lines := []
	for para in text.split("\n"):
		lines.append_array(_wrap(para, chars - int(ART_W / 4.0) if art_tex != null else (chars - int(FACE_W / 4.0) if face != null else chars)))
		plain_lines.append_array(_wrap(para, chars))
	# option labels wrap onto more rows instead of being cut off (the room left for chips depends on the option)
	var opt_lines := []
	var opts_h := 0.0
	var tap_h := 19.0 if size.y > size.x else 0.0  # R14 (5): the tall format gets thumb-sized answers
	for opt in options:
		var chip_w := (str(opt.get("chip", "")).length() + 1 if str(opt.get("chip", "")) != "" else 0)
		chip_w += (str(opt.get("trust_chip", "")).length() + 1 if str(opt.get("trust_chip", "")) != "" else 0)
		var full := "%d. %s" % [opt_lines.size() + 1, str(opt.label)]
		if not bool(opt.get("enabled", true)) and opt.has("hint"):
			full += " [%s]" % str(opt.hint)
		var rows: Array = _wrap(full, chars - 1 - chip_w)
		opt_lines.append(rows)
		opts_h += maxf(3.0 + 7.0 * float(rows.size()), tap_h) + 1.0
	var body_h := maxf(float(lines.size()) * 7.0, 27.0 if art_tex != null else (FACE_H if face != null else 0.0))
	var ph := 12.0 + body_h + 4.0 + opts_h + 4.0
	if art_tex != null and ph > size.y - 14.0:  # no room for the picture on this screen: the plain card, the text at full width
		art_tex = null
		lines = plain_lines
		body_h = float(lines.size()) * 7.0
		ph = 12.0 + body_h + 4.0 + opts_h + 4.0
	if face != null and ph > size.y - 14.0:  # no room for the face either: the plain card
		face = null
		lines = plain_lines
		body_h = float(lines.size()) * 7.0
		ph = 12.0 + body_h + 4.0 + opts_h + 4.0
	# short screens (16:9, wide) keep the people visible by putting the card at the top
	var opt_pad := 3.0
	var top_y := 6.0
	if size.y < 200.0 and ph > size.y - 12.0:  # R42 LARGE: a very short screen: the card hugs the top and its answers sit closer
		opt_pad = 1.0
		top_y = 2.0
		ph -= 2.0 * float(options.size()) + 2.0
	var panel_y := top_y if size.y < 200.0 else size.y - ph - 6.0
	var panel := Rect2(floorf((size.x - pw) * 0.5), floorf(panel_y), pw, ph)
	_canvas.draw_rect(panel, Color("e9ecf1"))
	_canvas.draw_rect(Rect2(panel.position, Vector2(pw, 9)), Color("8e3a2b"))
	var title_chars := int((pw - 6.0) / 4.0)
	var title_text := speaker.to_upper()
	if title_text.length() > title_chars:  # R42 LARGE: a long speaker line is cut at the card's edge
		title_text = title_text.substr(0, maxi(1, title_chars - 2)) + ".."
	PixelFont.draw(_canvas, title_text, panel.position + Vector2(3, 2), WHITE)
	icon_drawn = Rect2()
	var icon := icon_tex()
	if icon != null and PixelFont.width(speaker) + 3.0 < pw - 18.0:
		icon_drawn = Rect2(panel.end.x - 15.0, panel.position.y - 1.0, 12.0, 12.0)
		_canvas.draw_texture(icon, icon_drawn.position)
	var y := panel.position.y + 12.0
	for line in lines:
		PadGlyphs.draw(_canvas, line, Vector2(panel.position.x + 5 + (FACE_W if face != null else 0.0), y), INK, 1, true)
		y += 7.0
	if face != null:
		_canvas.draw_rect(Rect2(panel.position.x + 4.0, panel.position.y + 11.0, 28.0, 24.0), Color("c9d2e0"))
		_canvas.draw_texture(face, panel.position + Vector2(5, 12))
	if art_tex != null:
		_canvas.draw_texture(art_tex, Vector2(panel.end.x - ART_W + 1.0, panel.position.y + 11.0))
	y = panel.position.y + 12.0 + body_h + 4.0
	for i in options.size():
		var opt: Dictionary = options[i]
		var on: bool = bool(opt.get("enabled", true))
		var rows: Array = opt_lines[i]
		var r := Rect2(panel.position.x + 4, y, pw - 8, maxf(opt_pad + 7.0 * float(rows.size()), tap_h))
		var ty := floorf((r.size.y - 7.0 * float(rows.size()) + 2.0) * 0.5)
		var col := (
			Color("f5d442") if i == sel and on else (Color("c9d2e0") if on else Color("dcdfe6"))
		)
		_canvas.draw_rect(r, col)
		var chip := str(opt.get("chip", ""))  # the partner's stance (owner campaign)
		var tchip := str(opt.get("trust_chip", ""))  # X9: what the choice does to the partner's trust
		var right_edge := r.end.x
		for k in rows.size():
			PadGlyphs.draw(_canvas, str(rows[k]), r.position + Vector2(3, ty + 7 * k), INK if on else Color("8b93a1"), 1, true)
		if chip != "":
			var tint := Color("2f7d46")
			if str(opt.get("stance", "")) == "warn":
				tint = Color("b9791a")
			elif str(opt.get("stance", "")) == "oppose":
				tint = Color("b02a2a")
			var cw := float(chip.length()) * 4.0 + 3.0
			var chip_rect := Rect2(r.end.x - cw - 1.0, r.position.y + 1.0, cw, 8.0)
			_canvas.draw_rect(chip_rect, tint)
			PixelFont.draw(_canvas, chip, chip_rect.position + Vector2(2, 1), WHITE)
			right_edge = chip_rect.position.x - 1.0
		if tchip != "":
			var dir := int(opt.get("trust_dir", 0))
			var ttint := Color("2f7d46") if dir > 0 else (Color("b02a2a") if dir < 0 else Color("6b7385"))
			var tw := float(tchip.length()) * 4.0 + 3.0
			var trect := Rect2(right_edge - tw - 1.0, r.position.y + 1.0, tw, 8.0)
			_canvas.draw_rect(trect, ttint)
			PixelFont.draw(_canvas, tchip, trect.position + Vector2(2, 1), WHITE)
		_hits.append({"r": r, "i": i})
		y += r.size.y + 1.0
	var m := _mouse.floor()
	for i in 6:
		_canvas.draw_rect(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
