extends CanvasLayer
# Decision cards: a modal dialog with a speaker, some text and 2-4 options. Used when the
# account manager walks in with a client complaint, and for the owner campaign's business
# decisions. Up/Down + Enter, number keys 1-4, or click.
#   Cards.ask("Vic", "text...", [{"label": "I WILL PRIORITIZE IT", "id": "a"}, ...], on_pick)
# Options can be {"label", "id", "enabled": false, "hint": "why"} to show them greyed out.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")

var is_open := false
var speaker := ""
var text := ""
var options: Array = []
var sel := 0

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
	who: String, body: String, choices: Array, on_pick: Callable, valid := Callable()
) -> void:
	# X9: every asked card is shown once, in the order asked. A card asked while another is open, while the
	# report covers the screen, or while older cards are still waiting joins the back of the queue.
	if is_open or DayReport.is_open or (not _queue.is_empty() and not _draining):
		_queue.append([who, body, choices, on_pick, valid])
		if not is_open and not DayReport.is_open:
			_show_next()
		return
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
	_opened = Time.get_ticks_msec()
	Game.ui_open = true
	_canvas.visible = true
	_mouse = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_canvas.queue_redraw()


# a follow-up to the card that was just picked: it goes in front of cards that were already waiting
func ask_first(who: String, body: String, choices: Array, on_pick: Callable) -> void:
	_queue.push_front([who, body, choices, on_pick, Callable()])
	if not is_open and not DayReport.is_open:
		_show_next()


func pick(index: int) -> void:
	if (
		not is_open
		or index < 0
		or index >= options.size()
		or not bool(options[index].get("enabled", true))
	):
		return
	var id := str(options[index].id)
	is_open = false
	_canvas.visible = false
	Game.ui_open = Computer.is_open or Phone.is_open or PrinterGame.is_open or Outings.is_open
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if Game.ui_open else Input.MOUSE_MODE_VISIBLE
	if id != "__none" and _callback.is_valid():
		_callback.call(id)
	_show_next()


# the next queued card whose reason still holds (a Vic complaint for a ticket that closed meanwhile is dropped)
func _show_next() -> void:
	while not _queue.is_empty() and not is_open and not DayReport.is_open:
		var next: Array = _queue.pop_front()
		var valid: Callable = next[4] if next.size() > 4 else Callable()
		if valid.is_valid() and not bool(valid.call()):
			if next[3].is_valid():
				next[3].call("__none")
			continue
		_draining = true
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
		if str(options[i].id) in ["leave", "__none"]:
			pick(i)
			return


func _move(step: int) -> void:
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
			if h.r.has_point(_mouse):
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
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			_move(-1)
		elif event.keycode == KEY_DOWN:
			_move(1)
		elif event.keycode == KEY_ESCAPE:
			_pick_leave()
		elif Time.get_ticks_msec() - _opened < 450:
			pass  # too soon: the card just appeared
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			pick(sel)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			pick(event.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()


func _wrap(s: String, chars: int) -> Array:
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


func _paint() -> void:
	var size := get_viewport().get_visible_rect().size
	_hits.clear()
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.45))
	var pw := minf(size.x - 8.0, 250.0)
	var chars := int((pw - 10.0) / 4.0)
	var lines := []
	for para in text.split("\n"):
		lines.append_array(_wrap(para, chars))
	# option labels wrap onto more rows instead of being cut off (the room left for chips depends on the option)
	var opt_lines := []
	var opts_h := 0.0
	for opt in options:
		var chip_w := (str(opt.get("chip", "")).length() + 1 if str(opt.get("chip", "")) != "" else 0)
		chip_w += (str(opt.get("trust_chip", "")).length() + 1 if str(opt.get("trust_chip", "")) != "" else 0)
		var full := "%d. %s" % [opt_lines.size() + 1, str(opt.label)]
		if not bool(opt.get("enabled", true)) and opt.has("hint"):
			full += " [%s]" % str(opt.hint)
		var rows: Array = _wrap(full, chars - 1 - chip_w)
		opt_lines.append(rows)
		opts_h += 3.0 + 7.0 * float(rows.size()) + 1.0
	var ph := 12.0 + float(lines.size()) * 7.0 + 4.0 + opts_h + 4.0
	# short screens (16:9, wide) keep the people visible by putting the card at the top
	var panel_y := 6.0 if size.y < 200.0 else size.y - ph - 6.0
	var panel := Rect2(floorf((size.x - pw) * 0.5), floorf(panel_y), pw, ph)
	_canvas.draw_rect(panel, Color("e9ecf1"))
	_canvas.draw_rect(Rect2(panel.position, Vector2(pw, 9)), Color("8e3a2b"))
	PixelFont.draw(_canvas, speaker.to_upper(), panel.position + Vector2(3, 2), WHITE)
	var y := panel.position.y + 12.0
	for line in lines:
		PixelFont.draw(_canvas, line, Vector2(panel.position.x + 5, y), INK)
		y += 7.0
	y += 4.0
	for i in options.size():
		var opt: Dictionary = options[i]
		var on: bool = bool(opt.get("enabled", true))
		var rows: Array = opt_lines[i]
		var r := Rect2(panel.position.x + 4, y, pw - 8, 3.0 + 7.0 * float(rows.size()))
		var col := (
			Color("f5d442") if i == sel and on else (Color("c9d2e0") if on else Color("dcdfe6"))
		)
		_canvas.draw_rect(r, col)
		var chip := str(opt.get("chip", ""))  # the partner's stance (owner campaign)
		var tchip := str(opt.get("trust_chip", ""))  # X9: what the choice does to the partner's trust
		var right_edge := r.end.x
		for k in rows.size():
			PixelFont.draw(_canvas, str(rows[k]), r.position + Vector2(3, 2 + 7 * k), INK if on else Color("8b93a1"))
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
