extends RefCounted
# gdlint:disable=max-line-length
# R16 (cozy design review): micro-sessions, the QUICK PLAY rows of the title menu. Both run on Free Play (no campaign,
# no save, your saved look):
#  - "outing": ONE OUTING. The Free Play toolbox launches one team game (Toolbox.queued, the same path as its GO
#    button); the game rotates with every quick outing played (career counter micro_outings).
#  - "tickets": ONE TICKET SHIFT. TARGET tickets land in the queue at once (drawn on the run's seeded `micro` stream);
#    Free Play fixes take no time, so it is a few minutes at the desk. The HUD goal chip counts them down and a toast
#    with your time ends it (career counters micro_shifts, micro_best = the fastest shift in seconds).
# State is static (a session lives only as long as the Free Play run): Campaign.new_game and the title clear it.

const OUTINGS := ["bowling", "karaoke", "escape", "dinner", "cornhole", "darts"]
const TARGET := 5

static var kind := ""  # "", "outing" or "tickets"
static var base_closed := 0
static var started_ms := 0
static var game := ""  # the outing that was launched


static func active() -> bool:
	return kind != "" and not Campaign.active and not Game.title_mode


static func clear() -> void:
	kind = ""
	game = ""


# the game the next quick outing plays: they take turns
static func next_outing() -> String:
	return str(OUTINGS[Career.value("micro_outings") % OUTINGS.size()])


# called by the title right after Free Play has started (the room is loading)
static func begin(which: String) -> void:
	clear()
	if Campaign.active:
		return
	kind = which
	started_ms = Time.get_ticks_msec()
	match which:
		"outing":
			game = next_outing()
			Toolbox.game_i = Toolbox.GAMES.find(game)
			Toolbox.queued = true  # Toolbox.after_start launches it once the room is up
			Career.add("micro_outings")
		"tickets":
			var r: RandomNumberGenerator = Difficulty.rng("micro")
			var made := 0
			for i in TARGET * 6:
				if made >= TARGET:
					break
				var t: Dictionary = Msp.create_ticket(r.randi() % Msp.CLIENTS.size(), r.randi() % Msp.PROBLEMS.size(), "email")
				made += 0 if t.is_empty() else 1
			base_closed = Msp.closed_ok
			Hints.toast("ONE TICKET SHIFT: CLOSE %d TICKETS AT YOUR DESK" % TARGET, 5.0)
		_:
			kind = ""


static func closed() -> int:
	return clampi(Msp.closed_ok - base_closed, 0, TARGET)


static func goal() -> String:
	match kind:
		"tickets":
			return "ONE SHIFT: %d OF %d TICKETS CLOSED" % [closed(), TARGET]
		"outing":
			return "ONE OUTING: %s" % str(Outings.GAMES.get(game, {}).get("label", game.to_upper()))
	return ""


# called every frame by the HUD: ends the session when its goal is met
static func tick() -> void:
	if kind == "":
		return
	if Campaign.active or Game.title_mode:
		clear()
		return
	if kind == "tickets" and closed() >= TARGET:
		var secs := maxi(1, (Time.get_ticks_msec() - started_ms) / 1000)
		Career.add("micro_shifts")
		Career.fastest("micro_best", secs)
		Hints.toast("SHIFT DONE: %d TICKETS IN %d:%02d. {ESC:pause} FOR THE MENU, OR STAY A WHILE" % [TARGET, secs / 60, secs % 60], 7.0)
		clear()
	elif kind == "outing" and Toolbox.last_launch.get("game", "") == game and not Toolbox.queued and not Outings.is_open and not Outings.busy():
		if Time.get_ticks_msec() - started_ms > 4000:
			Hints.toast("THAT WAS ONE OUTING. {ESC:pause} FOR THE MENU, OR STAY A WHILE", 6.0)
			clear()
