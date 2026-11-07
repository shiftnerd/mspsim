extends Node
# gdlint:disable=class-definitions-order,max-returns
# Autoload (registered right after Controls): who is playing. Co-op phase 1 (docs/scope-coop.md, section 5.1).
#   Players.coop            the feature flag. false = single player, byte for byte (the default). `-- --coop` on the
#                           command line or Players.enable_coop(true) turns it on; nothing else changes until then.
#   Players.slot(i)         the Slot record of player i (0 or 1): device, character, look, held, joined
#   Players.node(i)         the Player body of slot i in the current scene (Actors/Player, Actors/Player2) or null
#   Players.player0(scene)  the slot 0 body of `scene` (default: the current scene) or null: the safe replacement for
#                           get_node_or_null("Actors/Player")
#   Players.join(1, device) slot 1 joins (coop only): registers its p2_ actions and spawns Actors/Player2 in a stage
#   Players.slot_of(event)  which slot owns an input event (keys and pad 0 = slot 0, pad N = the slot that joined on N)
# Slot 0 is a read-through mirror of today's globals (Player.current_character, Look.look, Game.vars.held): it holds
# no copy of its own, so nothing can drift. Slot 1 owns its own character and held item.
# NOT per slot yet (phase 3+): Game.ui_open and Game.busy stay ONE global freeze for both bodies, the camera follows
# slot 0 only, a door or auto exit still takes only the player who used it, Skills / Shift / Growth / Campaign are slot 0.

signal roster_changed

const MAX_SLOTS := 2
const TETHER_MARGIN := 10.0  # px kept between a body and the edge of the view (co-op camera)
const P2_CHARACTER := "office_dan"  # slot 1's stock person (the intern when slot 0 already is Dan)
const P2_FALLBACK := "office_intern"

var coop := false
var slots: Array = []
var ui := [false, false]  # per slot: this player has a takeover (a pane) open; Game.ui_open stays the global freeze
var _fades := [0.0, 0.0]
var _host: Node = null


class Slot:
	extends RefCounted
	const PLAYER_SCRIPT := preload("res://scripts/player.gd")
	var index := 0
	var device := -1  # -1 keyboard (slot 0 also owns pad 0), 1.. the joypad slot 1 joined with
	var joined := false
	var stored_character := ""
	var stored_held := ""

	var character: String:
		get:
			return PLAYER_SCRIPT.current_character if index == 0 else stored_character
		set(value):
			if index == 0:
				PLAYER_SCRIPT.current_character = value
			else:
				stored_character = value

	# a Look dictionary: slot 0 is the custom person of the Look autoload, slot 1 always a stock character for now
	var look: Dictionary:
		get:
			return Look.look if index == 0 else {}

	var held: String:
		get:
			var body: Node = Players.node(index)
			if body != null:
				return str(body.held)
			return str(Game.vars.get("held", "")) if index == 0 else stored_held
		set(value):
			if index == 0:
				Game.vars["held"] = value
			else:
				stored_held = value

	func _init(i := 0) -> void:
		index = i
		joined = i == 0


func _init() -> void:
	for i in MAX_SLOTS:
		slots.append(Slot.new(i))


func _ready() -> void:
	if "--coop" in OS.get_cmdline_user_args():
		enable_coop(true)


# co-op phase 3: the pane host (panes.gd), made the first time a pane opens
func takeover_host() -> Node:
	if _host == null:
		_host = preload("res://scripts/panes.gd").new()
		add_child(_host)
	return _host


func set_ui(i: int, on: bool) -> void:
	ui[clampi(i, 0, MAX_SLOTS - 1)] = on


# a pane fading in or out: the camera slides down (Game.ui_shift) by the deepest of the open panes
func pane_fade(i: int, value: float) -> void:
	_fades[clampi(i, 0, MAX_SLOTS - 1)] = value
	Game.ui_shift = maxf(float(_fades[0]), float(_fades[1]))


func slot(i: int) -> Slot:
	return slots[clampi(i, 0, MAX_SLOTS - 1)]


# how many players are in
func count() -> int:
	var n := 0
	for s in slots:
		if s.joined:
			n += 1
	return n


# the Player body of slot i in `scene` (default: the current scene), or null
func node(i: int, scene: Node = null) -> Node:
	var sc: Node = scene if scene != null else get_tree().current_scene
	if sc == null or i < 0 or i >= MAX_SLOTS:
		return null
	return sc.get_node_or_null("Actors/Player" if i == 0 else "Actors/Player%d" % (i + 1))


func player0(scene: Node = null) -> Node:
	return node(0, scene)


# every Player body in the current scene, slot order
func nodes(scene: Node = null) -> Array:
	var out := []
	for i in MAX_SLOTS:
		var body := node(i, scene)
		if body != null:
			out.append(body)
	return out


# the body closest to x (what an NPC should look at once it cares about both)
func nearest_to(x: float, scene: Node = null) -> Node:
	var best: Node = null
	var best_d := INF
	for body in nodes(scene):
		var d := absf(body.global_position.x - x)
		if d < best_d:
			best_d = d
			best = body
	return best


func enable_coop(on := true) -> void:
	coop = on
	if on:
		Controls.ensure_slot(1, 1)
	else:
		leave(1)


# Free Play only for phase 1, and only in a room (not the title, not under a card or a takeover)
func can_join() -> bool:
	var sc := get_tree().current_scene
	return (
		coop
		and not slots[1].joined
		and sc != null
		and sc.has_method("spawn_player2")
		and not Game.title_mode
		and not Campaign.active
		and not Game.ui_open
		and not Game.busy
	)


# slot i joins on joypad `device` (pad 0 is slot 0's). Returns false when co-op is off or the slot is taken by another pad
func join(i: int, device := 1) -> bool:
	if not coop or i != 1 or device < 1:
		return false
	var s: Slot = slots[i]
	if s.joined:
		return s.device == device
	s.device = device
	s.joined = true
	if s.stored_character == "":
		s.stored_character = P2_CHARACTER if Slot.PLAYER_SCRIPT.current_character != P2_CHARACTER else P2_FALLBACK
	Controls.ensure_slot(i, device)
	var sc := get_tree().current_scene
	if sc != null and sc.has_method("spawn_player2"):
		sc.spawn_player2()
	roster_changed.emit()
	return true


func leave(i: int) -> void:
	if i != 1 or not slots[1].joined:
		return
	var body := node(1)
	slots[1].joined = false
	slots[1].stored_held = ""
	if body != null:
		body.get_parent().remove_child(body)
		body.queue_free()
	roster_changed.emit()


# which slot an input event belongs to: keys and mouse are slot 0, a pad is the slot that joined on its device (pad 0 is
# slot 0's); -1 for a pad nobody has joined with
func slot_of(event: InputEvent) -> int:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		for s in slots:
			if s.index > 0 and s.joined and s.device == event.device:
				return s.index
		return 0 if event.device == 0 else -1
	return 0


# A on an unclaimed pad joins slot 1 (co-op only)
func _input(event: InputEvent) -> void:
	if not coop or slots[1].joined:
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A and event.device >= 1:
		if can_join() and join(1, event.device):
			get_viewport().set_input_as_handled()


# ---- the shared camera and the tether (co-op phase 2, docs/scope-coop.md) ---------------------------------------
# the camera frames both bodies: the middle of the two (one body: its own x)
func coop_focus(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var lo: float = xs[0]
	var hi: float = xs[0]
	for x in xs:
		lo = minf(lo, float(x))
		hi = maxf(hi, float(x))
	return (lo + hi) * 0.5


# the x range the bodies may stand in so both stay on screen: the view around the camera centre (the focus kept inside the
# room, as the camera's limits do), less a margin. A room that fits the view has no tether (the range is the whole room).
func tether_range(focus: float, view_w: float, room_l: float, room_r: float) -> Vector2:
	if room_r - room_l <= view_w:
		return Vector2(room_l, room_r)
	var half := view_w * 0.5
	var centre := clampf(focus, room_l + half, room_r - half)
	return Vector2(centre - half + TETHER_MARGIN, centre + half - TETHER_MARGIN)
