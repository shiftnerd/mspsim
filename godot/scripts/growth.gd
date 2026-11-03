extends Node
# gdlint:disable=class-definitions-order,class-variable-name
# gdlint:disable=max-line-length
# Grow a Tier 1 into a Tier 2 (from the Empath MSP training ideas). The one-page plan as a mechanic:
#   1. a GAP LIST (what the shop cannot do: low skill levels plus the escalations: SLA breaches and reopens)
#   2. pick ONE skill, assign a learner and a HELPER who catches mistakes
#   3. protect 30 paid minutes a week (if the queue eats it, the training moves into the ticket flow and
#      you learn less, and a crew that never gets training burns out)
#   4. stretch assignments: a Tier 2 ticket with someone close enough to catch you
#   5. the measurable result: escalations drop; at 100% you are Tier 2 in that skill.
# Tech campaign: YOU are the learner (Morgan runs the plan on days 6, 7, 8, 12, 13, 17, 18).
# Owner campaign: you choose who is developed. Hard escalations land on the owner's desk (the only
# Tier 3): a weekly pool of OWNER HOURS that escalations eat; when it runs dry, sales and marketing suffer.

const SKILLS := ["servers", "security", "networking", "powershell"]
const OWNER_HOURS := 40.0
const ADMIN_HOURS := 12.0
const ESC_HOURS := 1.5
const ESC_CHANCE := 0.10  # share of closed tickets that need the owner
const DEFAULT_STRETCH := {
	"servers": "A file server will not mount a share after a patch Tuesday",
	"security": "A user's mailbox is sending spam and nobody knows how",
	"networking": "Two buildings are on the same subnet and nobody knows why",
	"powershell": "Fifty mailboxes need a setting changed and the GUI will take all day",
}
var STRETCH: Dictionary = DEFAULT_STRETCH.duplicate(true)

var focus := ""
var helper := ""  # tech: the coworker (or owner: Alan, Garrison) who catches your mistakes
var learner := ""  # owner: the tech being developed
var progress := 0.0
var graduated := false
var blocks_taken := 0
var blocks_skipped := 0
var stretch_ok := 0
var stretch_caught := 0
var stretch_slipped := 0
var tier2 := 0  # owner: how many techs have grown into Tier 2
var promoted: Array = []  # owner: who graduated
var esc := {}  # period -> escalations
var esc_skill := {}  # skill -> escalations
var owner_used := 0.0  # owner hours spent on escalations this week
var owner_warned := false
var _skip_note := false


func _ready() -> void:
	reset()


func reset() -> void:
	focus = ""
	helper = ""
	learner = ""
	progress = 0.0
	graduated = false
	blocks_taken = 0
	blocks_skipped = 0
	stretch_ok = 0
	stretch_caught = 0
	stretch_slipped = 0
	tier2 = 0
	promoted = []
	esc = {}
	esc_skill = {}
	owner_used = 0.0
	owner_warned = false
	_skip_note = false


func period() -> int:
	return Campaign.day if Campaign.mode == "owner" else (Campaign.day - 1) / 5


func esc_now() -> int:
	return int(esc.get(period(), 0))


func esc_before() -> int:
	return int(esc.get(period() - 1, 0))


func has_plan() -> bool:
	return focus != "" and (learner != "" or helper != "")


func focus_name() -> String:
	return str(Skills.NAMES.get(focus, focus)).to_upper()


# ---- the gap list ----------------------------------------------------------------------------
func note_escalation(t: Dictionary) -> void:
	if not Campaign.active or Campaign.mode != "tech" or t.get("internal", false):
		return
	var skill: String = Skills.FIX_XP.get(str(t.get("fix", "")), "servers")
	esc[period()] = esc_now() + 1
	esc_skill[skill] = int(esc_skill.get(skill, 0)) + 1


func gaps() -> Array:
	var out := []
	for skill in SKILLS:
		var level := Skills.level(skill)
		var count := int(esc_skill.get(skill, 0))
		out.append(
			{"skill": skill, "level": level, "esc": count, "score": (5 - level) * 2 + count * 3}
		)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	return out


# fixes get safer in the skill you are growing
func fail_adjust(action: String) -> float:
	if not Campaign.active or Campaign.mode != "tech" or focus == "" or progress <= 0.0:
		return 0.0
	var matches: bool = (
		str(Skills.FIX_XP.get(action, "")) == focus
		or focus == "powershell"
		or focus == "networking"
	)
	return -(0.08 if matches else 0.02) * progress / 100.0


func status_line() -> String:
	if focus == "":
		return ""
	if graduated and Campaign.mode == "tech":
		return "TIER 2 IN %s" % focus_name()
	if Campaign.mode == "owner":
		return "GROWTH: %s > %s %d%%" % [learner.to_upper(), focus_name(), int(progress)]
	return (
		"GROWTH: %s %d%% (HELPER %s)  ESC %d (LAST %d)"
		% [focus_name(), int(progress), helper.to_upper(), esc_now(), esc_before()]
	)


func _add_progress(amount: float, xp: int) -> void:
	progress = minf(100.0, progress + amount)
	if Campaign.mode == "tech":
		Skills.add_xp(focus, xp)
	if progress >= 100.0 and not graduated:
		graduated = true
		if Campaign.mode == "tech":
			_graduate_tech()
		else:
			_graduate_owner()
	Msp.changed.emit()


# ---- tech: you are the learner ----------------------------------------------------------------
func start_plan() -> void:
	if Campaign.mode != "tech" or focus != "":
		return
	var list := gaps()
	var text := "Time to grow you into a Tier 2. Your gap list, from your levels and the escalations: "
	var parts := []
	var options := []
	for i in 3:
		var g: Dictionary = list[i]
		parts.append("%s L%d (%d)" % [str(Skills.NAMES[g.skill]), int(g.level), int(g.esc)])
		options.append(
			{
				"label":
				(
					"%s: LEVEL %d, %d ESCALATIONS"
					% [str(Skills.NAMES[g.skill]), int(g.level), int(g.esc)]
				),
				"id": str(g.skill)
			}
		)
	Cards.ask(
		"Morgan (Manager)",
		text + ", ".join(parts) + ". Pick ONE skill for the next month.",
		options,
		func(id: String) -> void: _pick_helper(id)
	)


func _pick_helper(skill: String) -> void:
	var options := []
	for who in ["Alan", "Garrison", "Dan"]:
		if Social.people().has(who):
			options.append({"label": "%s (%s)" % [who.to_upper(), Social.mood(who)], "id": who})
	Cards.ask(
		"Morgan (Manager)",
		"Who should be near you to catch your mistakes while you stretch? Alan and Garrison are the owners and their time is tight. Someone you get along with will say it kindly.",
		options,
		func(who: String) -> void: _plan_set(skill, who)
	)


func _plan_set(skill: String, who: String) -> void:
	focus = skill
	helper = who
	progress = 0.0
	graduated = false
	(
		Msp
		. send_text(
			"Boss",
			(
				"Plan set: %s with %s as your helper. 30 paid minutes a week, protected, and stretch tickets."
				% [focus_name(), who.to_upper()]
			)
		)
	)
	(
		Msp
		. mail(
			Story.MANAGER,
			"Your growth plan",
			(
				"One skill: %s. Helper: %s. Thirty protected minutes a week on the board (I will ask). A stretch ticket now and then, with a safety net. The goal is fewer escalations, not heroics. - Morgan"
				% [focus_name(), who]
			)
		)
	)
	Msp.changed.emit()


func offer_block() -> void:
	if Campaign.mode != "tech" or focus == "" or graduated:
		return
	var busy := Msp.open_tickets().size() > 3
	var options := [
		{
			"label": "TAKE THE 30 MINUTES",
			"id": "take",
			"enabled": not busy,
			"hint": "QUEUE IS FULL"
		},
		{"label": "SQUEEZE IT INTO THE TICKET FLOW", "id": "squeeze"},
		{"label": "SKIP THIS WEEK", "id": "skip"},
	]
	var text := (
		"Your protected 30 minutes for %s this week. The board is %s."
		% [focus_name(), "full" if busy else "quiet enough"]
	)
	Cards.ask("Morgan (Manager)", text, options, func(id: String) -> void: block_result(id))


func block_result(id: String) -> void:
	match id:
		"take":
			blocks_taken += 1
			World.clock += 0.5
			for t in Msp.open_tickets():
				t.sla_left = float(t.sla_left) - 37.5  # the queue waits
			_add_progress(25.0, 12)
			Msp.send_text("Boss", "Good. Thirty minutes of real training on %s." % focus_name())
		"squeeze":
			blocks_taken += 1
			Shift.add_energy(-2.0)
			_add_progress(8.0, 4)
			Msp.send_text("Boss", "Learning between tickets is better than nothing, and tiring.")
		_:
			blocks_skipped += 1
			Shift.add_energy(-1.0)
			Msp.send_text(
				"Boss", "Skipping protected time is how a help desk burns out. Think about it."
			)


func offer_stretch() -> void:
	if Campaign.mode != "tech" or focus == "" or graduated:
		return
	var text := (
		"A Tier 2 ticket: %s. %s is at their desk and can catch you."
		% [str(STRETCH[focus]), helper.to_upper()]
	)
	Cards.ask(
		"Morgan (Manager)",
		text,
		[
			{"label": "TRY IT, %s WATCHES" % helper.to_upper(), "id": "try"},
			{"label": "ASK %s TO DO IT WHILE YOU WATCH" % helper.to_upper(), "id": "watch"},
			{"label": "ESCALATE IT BACK TO MORGAN", "id": "escalate"},
		],
		func(id: String) -> void: stretch_result(id)
	)


func success_chance() -> float:
	return clampf(
		0.30 + 0.13 * float(Skills.level(focus)) + (Shift.energy - 50.0) / 400.0 + progress / 400.0,
		0.15,
		0.9
	)


func stretch_result(id: String) -> void:
	match id:
		"try":
			if randf() < success_chance():
				stretch_ok += 1
				Social.change(helper, 2)
				Campaign.adjust_rep(1)
				Msp.score += 8
				Msp.send_text(helper, "Nice. I would not have thought of that. Solid.")
				_add_progress(30.0, 20)
			elif randf() < clampf(0.5 + float(Social.value(helper)) / 200.0, 0.3, 0.95):
				stretch_caught += 1
				Social.change(helper, 1)
				Msp.send_text(
					helper, "Stop, stop. That would have been a bad day. Do it like this."
				)
				_add_progress(15.0, 10)
			else:
				stretch_slipped += 1
				var client := Sales.pick_client()
				Sales.adjust(client, -6)
				Msp.score -= 5
				Story.queue_followup(
					{
						"client": client,
						"summary": "Odd behavior since yesterday's change",
						"pri": 3,
						"body": "Hi %s, something looks wrong since the work yesterday. - Staff"
					}
				)
				(
					Msp
					. send_text(
						"Boss",
						(
							"Something you touched yesterday is acting up for %s. Learning curves have a cost."
							% str(Msp.CLIENTS[client].name)
						)
					)
				)
				_add_progress(10.0, 6)
		"watch":
			Social.change(helper, 1)
			_add_progress(10.0, 8)
		_:
			esc[period()] = esc_now() + 1
			Msp.send_text("Boss", "Fine. I will take it. Next time, try.")


func _graduate_tech() -> void:
	var lv := Skills.level(focus)
	if focus == "powershell":
		Skills.ps_level = mini(5, Skills.ps_level + 1)
	elif lv < 5:
		Skills.xp[focus] = maxi(int(Skills.xp[focus]), int(Skills.XP_AT[lv]))
	Campaign.adjust_rep(3)
	Social.change(helper, 3)
	(
		Msp
		. mail(
			Story.MANAGER,
			"Congratulations: Tier 2",
			(
				"You can now handle %s tickets without a safety net, and the escalations show it. I am putting that in your file. - Morgan"
				% focus_name()
			)
		)
	)
	Msp.send_text("Boss", "You are a Tier 2 in %s now. Well done." % focus_name())


# ---- owner: the only Tier 3 ---------------------------------------------------------------------
func owner_free() -> float:
	var used := owner_used + (8.0 if Owner.flags.get("owner_oncall", false) else 0.0)
	return maxf(0.0, OWNER_HOURS - ADMIN_HOURS - used)


# the owner buried in escalations has less time for sales
func vic_penalty() -> float:
	if Campaign.mode != "owner":
		return 0.0
	return clampf((10.0 - owner_free()) / 10.0, 0.0, 1.0) * 0.12


func marketing_factor() -> float:
	if Campaign.mode != "owner":
		return 1.0
	return clampf(owner_free() / 12.0, 0.5, 1.0)


func capacity_loss() -> float:
	return 0.02 if learner != "" and not graduated else 0.0


func owner_escalation(t: Dictionary) -> void:
	if Campaign.mode != "owner":
		return
	if randf() < ESC_CHANCE * (1.0 - 0.25 * float(mini(3, tier2))):
		owner_used += ESC_HOURS * (2.0 if int(t.pri) <= 2 else 1.0)
		esc[period()] = esc_now() + 1


# the Owner calls this while settling a week; it returns the report row
func owner_week() -> Array:
	var free_hours := owner_free()
	var row := [
		"OWNER HOURS",
		"%dH FREE, %d ESCALATIONS" % [int(free_hours), esc_now()],
		Color("8fe3a0") if free_hours >= 10.0 else Color("ff8a80")
	]
	if free_hours < 6.0 and not owner_warned:
		owner_warned = true
		_bottleneck_card()
	if learner != "" and not graduated:
		if Msp.open_tickets().size() > 5:
			blocks_skipped += 1
			Owner.burnout = clampf(Owner.burnout + 3.0, 0.0, 100.0)
			_add_progress(4.0, 0)
			if not _skip_note:
				_skip_note = true
				Msp.send_text(
					"Alan",
					"The queue ate the training time again. That is how people end up burned out."
				)
		else:
			blocks_taken += 1
			_add_progress(18.0, 0)
	owner_used = 0.0
	return row


func _bottleneck_card() -> void:
	var options := [{"label": "KEEP DOING IT MYSELF", "id": "keep"}]
	if learner == "":
		options.push_front({"label": "START A GROWTH PLAN FOR THE TEAM", "id": "plan"})
	Cards.ask(
		"Alan (Co-owner)",
		"Boss, you are the only Tier 3. Every hard ticket ends on your desk and nobody else learns the work while you do it. You have no time left for clients.",
		options,
		func(id: String) -> void: _bottleneck_pick(id)
	)


func _bottleneck_pick(id: String) -> void:
	if id == "plan":
		owner_plan_card()


func owner_plan_card() -> void:
	if Campaign.mode != "owner" or learner != "":
		return
	var names := ["Garrison", "Dan"]
	for hire in Owner.extra_staff:
		names.append(str(hire.name))
	var options := []
	for who in names:
		options.append({"label": who.to_upper(), "id": who})
	Cards.ask(
		"Alan (Co-owner)",
		"Opportunity shortage, not talent shortage. Who do we grow into a Tier 2? Thirty paid minutes a week, protected, a stretch ticket now and then, and I will be the helper.",
		options,
		func(who: String) -> void: _owner_skill(who)
	)


func _owner_skill(who: String) -> void:
	var options := []
	for skill in ["servers", "security", "networking"]:
		options.append(
			{
				"label":
				(
					"%s (%d ESCALATIONS SO FAR)"
					% [str(Skills.NAMES[skill]), int(esc_skill.get(skill, 0))]
				),
				"id": skill
			}
		)
	Cards.ask(
		"Alan (Co-owner)",
		"Which skill? Pick the one the shop keeps escalating.",
		options,
		func(skill: String) -> void: _owner_plan_set(who, skill)
	)


func _owner_plan_set(who: String, skill: String) -> void:
	learner = who
	focus = skill
	progress = 0.0
	graduated = false
	_skip_note = false
	Msp.send_text(
		"Alan",
		(
			"%s will learn %s. Thirty protected minutes a week, and I will catch them."
			% [who, str(Skills.NAMES[skill])]
		)
	)
	Msp.changed.emit()


func owner_stretch() -> void:
	if Campaign.mode != "owner" or learner == "" or graduated:
		return
	var chance := clampf(0.40 + progress / 250.0, 0.2, 0.85)
	Cards.ask(
		"Alan (Co-owner)",
		(
			"A Tier 2 ticket just came in (%s). %s could take it, with me at the next desk."
			% [str(STRETCH[focus]).to_lower(), learner]
		),
		[
			{"label": "STRETCH ASSIGNMENT (%d%%)" % int(chance * 100.0), "id": "stretch"},
			{"label": "THE SENIOR TAKES IT", "id": "senior"},
			{"label": "I WILL HANDLE IT (4 OWNER HOURS)", "id": "owner"},
		],
		func(id: String) -> void: owner_stretch_result(id, chance)
	)


func owner_stretch_result(id: String, chance: float) -> void:
	match id:
		"stretch":
			if randf() < chance:
				stretch_ok += 1
				Sales.adjust(Sales.pick_client(), 3)
				Msp.send_text("Alan", "%s nailed it. I barely had to say a word." % learner)
				_add_progress(30.0, 0)
			elif randf() < 0.6:
				stretch_caught += 1
				Msp.send_text(
					"Alan", "I caught it before the client saw. %s learned something." % learner
				)
				_add_progress(14.0, 0)
			else:
				stretch_slipped += 1
				Sales.adjust(Sales.pick_client(), -6)
				Campaign.adjust_rep(-1)
				Msp.send_text("Alan", "%s broke something visible. The client noticed." % learner)
				_add_progress(10.0, 0)
		"senior":
			_add_progress(8.0, 0)
		_:
			owner_used += 4.0


func _graduate_owner() -> void:
	tier2 += 1
	promoted.append(learner)
	Owner.speed += 0.05
	Owner.flags["growth_done"] = true
	var who := learner
	Cards.ask(
		"Alan (Co-owner)",
		(
			"%s is a Tier 2 in %s now. Escalations to you will drop. They also know what that is worth on the market."
			% [who, focus_name()]
		),
		[
			{"label": "GIVE A RAISE ($60/WEEK)", "id": "raise"},
			{"label": "NOT NOW", "id": "no"},
		],
		func(id: String) -> void: _raise(id, who)
	)


func _raise(id: String, who: String) -> void:
	if id == "raise":
		Owner.weekly_extra += 60
		Msp.send_text("Alan", "%s is staying. The raise helped." % who)
	elif randf() < 0.3:
		if Owner.lost_techs < 2:
			Owner.lost_techs += 1
		Msp.send_text(
			"Alan",
			"%s took a job elsewhere. Trained staff leave when the pay does not follow." % who
		)
	learner = ""
	focus = ""
	progress = 0.0
	graduated = false


func board_lines() -> Array:
	var lines := []
	if Campaign.mode != "owner":
		return lines
	lines.append(
		[
			"OWNER HOURS %dH FREE (%d ESC THIS WEEK)" % [int(owner_free()), esc_now()],
			Color("8fe3a0") if owner_free() >= 10.0 else Color("ff8a80")
		]
	)
	if learner != "":
		lines.append(
			[
				"GROWTH: %s > %s %d%%" % [learner.to_upper(), focus_name(), int(progress)],
				Color("6b421c")
			]
		)
	elif tier2 > 0:
		lines.append(
			["TIER 2 TECHS: %d (%s)" % [tier2, ", ".join(promoted).to_upper()], Color("6b421c")]
		)
	return lines


func to_dict() -> Dictionary:
	return {
		"focus": focus,
		"helper": helper,
		"learner": learner,
		"progress": progress,
		"graduated": graduated,
		"taken": blocks_taken,
		"skipped": blocks_skipped,
		"ok": stretch_ok,
		"caught": stretch_caught,
		"slipped": stretch_slipped,
		"tier2": tier2,
		"promoted": promoted,
		"esc": esc,
		"esc_skill": esc_skill,
		"warned": owner_warned,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	focus = str(data.get("focus", ""))
	helper = str(data.get("helper", ""))
	learner = str(data.get("learner", ""))
	progress = float(data.get("progress", 0.0))
	graduated = bool(data.get("graduated", false))
	blocks_taken = int(data.get("taken", 0))
	blocks_skipped = int(data.get("skipped", 0))
	stretch_ok = int(data.get("ok", 0))
	stretch_caught = int(data.get("caught", 0))
	stretch_slipped = int(data.get("slipped", 0))
	tier2 = int(data.get("tier2", 0))
	promoted = data.get("promoted", [])
	owner_warned = bool(data.get("warned", false))
	var saved: Dictionary = data.get("esc", {})
	for key in saved:
		esc[int(key)] = int(saved[key])
	var saved_skill: Dictionary = data.get("esc_skill", {})
	for key in saved_skill:
		esc_skill[str(key)] = int(saved_skill[key])
