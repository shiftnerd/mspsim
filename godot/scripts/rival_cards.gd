extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: the story cards of the rival arc and the temptations, as DATA (docs/scope-bad-habits.md sections 2.4, 5 and 7).
# CARDS has the same shape as Owner.CARDS (speaker, text, options with label, optional need, fx, text) and is merged into Owner.CARDS when
# the Owner autoload starts (the card dictionaries are shared, so story/strings.txt edits to RivalCards.* show up in both).
# DAYS places cards like Owner.DAYS: {week: [{"at": 9.5, "card": "id"}]} and Owner.events_on() merges it. Beat cards that Rival.ARC queues
# need NO DAYS entry; use DAYS only for cards that appear on a fixed morning or time of day.
# New fx keys (Owner.apply): rap [rival, habit, level], habit id, habit_start id, consc n, skel [id, weeks], visit kind, lead n.
# The text is editable in story/strings.txt under [RivalCards.CARDS...]. Charset: the 3x5 font, 2013-14, no AI, "two-factor login", no MFA.
# OWNERS: rival.gd agent (rival_*), temptation agent (temp_*, bill_*), habits agent (habit_*). Add entries, do not change other files.

const DEFAULT_CARDS := {}
static var CARDS: Dictionary = DEFAULT_CARDS.duplicate(true)

const DEFAULT_DAYS := {}
static var DAYS: Dictionary = DEFAULT_DAYS.duplicate(true)


# the Owner.DAYS table plus the placements of this file (the owner's events_on reads it)
static func merged_days(base: Dictionary) -> Dictionary:
	if DAYS.is_empty():
		return base
	var out := base.duplicate()
	for day in DAYS:
		out[day] = (out.get(day, []) as Array) + (DAYS[day] as Array)
	return out
