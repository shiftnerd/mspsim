extends Node
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# The other owner (X5, owner campaign). You are one of the two owners of Pixel IT Partners; the other one is the
# partner NPC (Roles.partner()). Trust runs 0-100: it moves when you follow or override the partner's stance on a card,
# at four partner meetings, with the owners' draw and with joint outings. Trust opens or closes doors: help with the
# owner hours, a veto on cards the partner opposes, a partner who walks out, and the ending offers (buy-out, sell together).
# Stances are DERIVED from the effect tags of a card's option and the partner's priorities (Alan: technical, careful with
# money and prices; Garrison: sales, people and culture), so no card needs a stance table of its own.

signal changed

const MEETING_WEEKS := [5, 9, 13, 17]
const START_TRUST := 55  # help (owner hours) has to be earned: it starts at HELP_TRUST 60
const HELP_TRUST := 60  # from here the partner takes owner hours off you
const BLOCK_TRUST := 30  # below this the partner vetoes what they oppose
const RIFT_TRUST := 40  # below this the ending offers a buy-out
const BUYOUT_COST := 15000
const PRIORITIES := {
	"Alan":
	{
		"tech": 2.0, "security": 1.5, "people": 1.0, "culture": 0.3, "sales": -0.4, "marketing": -1.0,
		"premium": -1.6, "volume": 0.4, "spend": -0.5, "cheap_tools": -2.0, "draw": -1.5
	},
	"Garrison":
	{
		"tech": -0.2, "security": 0.4, "people": 1.5, "culture": 2.0, "sales": 1.6, "marketing": 1.5,
		"premium": -1.2, "volume": 0.8, "spend": -0.5, "cheap_tools": -0.5, "draw": 0.4
	},
}
const SECURITY_FLAGS := ["backup_service", "rdp_safe"]
const CULTURE_FLAGS := ["flex_hours", "four_day", "oncall_stipend", "after_hours_fee"]
const WORDS := {"agree": "AGREES", "warn": "WARNS", "oppose": "OPPOSES"}

# the four partner meetings: Marge brings the numbers, the partner brings an opinion. Texts differ per partner (their voice);
# options carry real effects plus a trust change for each partner.
const BEATS := {
	"partner1":
	{
		"week": 5,
		"speaker": "{partner}",
		"text":
		{
			"Alan": "Marge printed the quarter. We have some money. I want it in the rack and the tools, not in a banner. Where does it go?",
			"Garrison": "Marge printed the quarter and I have IDEAS. A client lunch! A banner on the van! A bigger sign! Where does the money go?"
		},
		"options":
		[
			{
				"label": "INVEST IN THE STACK AND THE RACK ($400)", "need": 400,
				"fx": {"cash": -400, "speed": 0.04, "trust": {"Alan": 4, "Garrison": -1}},
				"text": "The money goes into the rack. {partner} and Marge agree on exactly one thing today: the invoice is correct."
			},
			{
				"label": "INVEST IN THE CLIENTS: A THANK-YOU LUNCH ($300)", "need": 300,
				"fx": {"cash": -300, "mood_all": 5, "trust": {"Alan": -1, "Garrison": 4}},
				"text": "The clients get lunch. Dr. Patel asks if there is a dessert plan. There is now."
			},
			{
				"label": "KEEP IT IN THE BANK",
				"fx": {"trust": {"Alan": 1, "Garrison": 1}},
				"text": "Marge approves. Nobody else gets excited, but nobody gets upset either."
			},
		],
	},
	"partner2":
	{
		"week": 9,
		"speaker": "{partner}",
		"text":
		{
			"Alan": "That ransomware mess. The staff are asking who dropped it. I would like to know too. How do we handle it?",
			"Garrison": "The ransomware! Everyone is whispering! Somebody is going to get blamed and I hate that. What do we say to the team?"
		},
		"options":
		[
			{
				"label": "WRITE UP A REVIEW TOGETHER, NO BLAME",
				"fx": {"rep": 1, "mood_all": 1, "trust": {"Alan": 4, "Garrison": 4}},
				"text": "One page: what happened, what changes. {partner} reads it twice and pins it up. The whispering stops."
			},
			{
				"label": "POINT AT THEIR SIDE OF THE BUSINESS",
				"fx": {"burnout": 3, "trust": {"Alan": -8, "Garrison": -8}},
				"text": "{partner} goes very quiet. The staff notice the quiet, and the coffee machine hears everything."
			},
			{
				"label": "TAKE THE BLAME YOURSELF",
				"fx": {"rep": -1, "trust": {"Alan": 6, "Garrison": 6}},
				"text": "You say it was on you. {partner} did not expect that, and respects it."
			},
		],
	},
	"partner3":
	{
		"week": 13,
		"speaker": "{partner}",
		"text":
		{
			"Alan": "Costs are up and the crew wants more money. The books say one of two things has to give. Fees or wages. Pick.",
			"Garrison": "Okay, big one. The crew deserves a raise and the clients deserve a fee freeze, and the books say we cannot have both. Help!"
		},
		"options":
		[
			{
				"label": "RAISE FEES 8%",
				"fx": {"price": 0.08, "mood_all": -3, "trust": {"Alan": 2, "Garrison": -4}},
				"text": "A polite letter goes out. Most clients shrug. A few write back with long emails."
			},
			{
				"label": "RAISE THE CREW'S PAY ($60/WEEK)",
				"fx": {"payroll": 60, "burnout": -6, "speed": 0.03, "trust": {"Alan": 0, "Garrison": 4}},
				"text": "The crew gets a raise. Morgan says the break room mood improved by one whole donut."
			},
			{
				"label": "SPLIT IT: SMALL RAISE, SMALL FEE RISE",
				"fx": {"price": 0.04, "payroll": 30, "mood_all": -1, "trust": {"Alan": 1, "Garrison": 1}},
				"text": "Everyone gets a little and everyone complains a little. {partner} calls it fair."
			},
		],
	},
	"partner4":
	{
		"week": 17,
		"speaker": "{partner}",
		"text":
		{
			"Alan": "Marge says the valuation people are circling. Do we sell, or do we keep going? I want one answer from both of us.",
			"Garrison": "Sell or stay! The review is almost here and I am excited and terrified. Are we selling? Or are we building?"
		},
		"options":
		[
			{
				"label": "AIM TO SELL: TRIM COSTS, POLISH THE BOOKS",
				"fx": {"marketing": 0, "flag": "plan_sell", "trust": {"Alan": 2, "Garrison": -3}},
				"text": "The marketing budget goes to zero and the books get a polish. {partner} nods, a little sadly."
			},
			{
				"label": "STAY AND GROW: KEEP INVESTING",
				"fx": {"vic": 0.03, "flag": "plan_grow", "trust": {"Alan": 1, "Garrison": 3}},
				"text": "Neither of you says it, but the sign out front stays. {partner} grins."
			},
			{
				"label": "WE DISAGREE: SORT IT OUT AT THE REVIEW",
				"fx": {"flag": "plan_split", "trust": {"Alan": -6, "Garrison": -6}},
				"text": "The meeting ends with two coffees going cold and a long hallway."
			},
		],
	},
}

var trust := START_TRUST
var left := false  # the partner walked out of the company (trust hit 0)
var met: Array = []  # beats already held
var overrides := 0  # cards where you did what they opposed
var follows := 0
var _pending_leave := false
var sulk := 0  # weeks the partner holds back after you overrode them (no owner-hours help, slower hands)


func reset() -> void:
	trust = clampi(START_TRUST + Build.trust_bonus(), 0, 100)  # CULTURE and the quirks (X7)
	left = false
	met = []
	overrides = 0
	follows = 0
	_pending_leave = false
	sulk = 0


func to_dict() -> Dictionary:
	return {"trust": trust, "left": left, "met": met, "overrides": overrides, "follows": follows, "sulk": sulk}


func from_dict(data: Dictionary) -> void:
	reset()
	trust = int(data.get("trust", START_TRUST))
	left = bool(data.get("left", false))
	met = data.get("met", [])
	overrides = int(data.get("overrides", 0))
	follows = int(data.get("follows", 0))
	sulk = int(data.get("sulk", 0))


func who() -> String:
	return Roles.partner()


# there is a partner to deal with (owner campaign, they have not left)
func active() -> bool:
	return Campaign.cards_active() and who() != "" and not left


# ---- trust ---------------------------------------------------------------------------------------------------
func change(amount: int) -> void:
	if not Campaign.cards_active() or left or amount == 0:
		return
	trust = clampi(trust + amount, 0, 100)
	if trust <= 0 and Campaign.day >= 3:
		_pending_leave = true
	changed.emit()


func trust_word() -> String:
	if left:
		return "GONE"
	if trust >= 75:
		return "CLOSE"
	if trust >= 55:
		return "SOLID"
	if trust >= BLOCK_TRUST:
		return "STRAINED"
	if trust >= 10:
		return "ON THE OUTS"
	return "BROKEN"


# the partner's hands-on share of the ticket queue (they also run the other half of the company)
func hands() -> float:
	if left or who() == "":
		return 0.0
	var share := 0.5 if trust >= BLOCK_TRUST else 0.35
	return share * (0.7 if sulk > 0 else 1.0)  # X9: a partner you overrode pulls fewer tickets for a while


# owner hours the partner takes off you while they trust you
func help_hours() -> float:
	return 6.0 if active() and trust >= HELP_TRUST and sulk <= 0 else 0.0


# ---- stance chips ----------------------------------------------------------------------------------------------
func _add(out: Dictionary, tag: String, amount: float) -> void:
	out[tag] = float(out.get(tag, 0.0)) + amount


func _tag_fx(out: Dictionary, fx: Dictionary, w: float) -> void:
	var cash := float(fx.get("cash", 0))
	var weekly := float(fx.get("weekly", 0)) + float(fx.get("payroll", 0))
	_add(out, "spend", (maxf(0.0, -cash) / 600.0 + maxf(0.0, weekly) / 100.0) * w)
	if fx.has("marketing") and int(fx.marketing) > 0:
		_add(out, "marketing", float(fx.marketing) / 900.0 * w)
		_add(out, "sales", float(fx.marketing) / 900.0 * w)
	var price := float(fx.get("price", 0.0))
	if price > 0.0:
		_add(out, "premium", price / 0.2 * w)
	elif price < 0.0:
		_add(out, "volume", -price / 0.15 * w)
		_add(out, "sales", -price / 0.15 * w)
	if float(fx.get("vic", 0.0)) > 0.0:
		_add(out, "sales", 0.5 * w)
	if fx.has("stack"):
		for category in fx.stack:
			var opt: Dictionary = Owner.STACK[str(category)].options.get(str(fx.stack[category]), {})
			if float(opt.get("morale", 0)) < 0.0 or float(opt.get("issues", 1.0)) > 1.1:
				_add(out, "cheap_tools", w)
			elif float(opt.get("speed", 0)) > 0.0 or float(opt.get("morale", 0)) > 0.0:
				_add(out, "tech", w)
	var flag := str(fx.get("flag", ""))
	if SECURITY_FLAGS.has(flag):
		_add(out, "security", w)
		_add(out, "tech", 0.5 * w)
	elif flag == "rdp_weak":
		_add(out, "security", 0.3 * w)
	elif CULTURE_FLAGS.has(flag):
		_add(out, "culture", w)
	if fx.get("check_backups", false) or fx.get("health_check", false) or fx.has("remediate"):
		_add(out, "tech", w)
		_add(out, "security", 0.5 * w)
	var burn := float(fx.get("burnout", 0.0))
	if burn != 0.0:
		_add(out, "culture", -burn / 6.0 * w)
	var mood := float(fx.get("mood_all", 0.0))
	if mood != 0.0:
		_add(out, "culture", mood / 6.0 * w)
		_add(out, "sales", mood / 6.0 * w)
	if fx.has("candidates") or fx.has("hire"):
		_add(out, "people", w)
	if fx.get("lose_tech", false):
		_add(out, "people", -w)
	if float(fx.get("speed", 0.0)) > 0.0:
		_add(out, "tech", 0.3 * w)
	if str(fx.get("draw", "")) == "generous":
		_add(out, "draw", w)


# the weighted effect tags of an option (a roll counts as the average of its outcomes)
func tags(opt: Dictionary) -> Dictionary:
	var out := {}
	var fxs: Array = []
	if opt.has("fx"):
		fxs.append(opt.fx)
	if opt.has("roll"):
		for entry in opt.roll:
			fxs.append(entry[1])
	for fx in fxs:
		_tag_fx(out, fx, 1.0 / float(maxi(1, fxs.size())))
	return out


# the partner's score for an option (positive = they like it)
func score(opt: Dictionary, partner := "") -> float:
	var p := partner if partner != "" else who()
	var weights: Dictionary = PRIORITIES.get(p, {})
	var total := 0.0
	var t := tags(opt)
	for tag in t:
		total += float(t[tag]) * float(weights.get(tag, 0.0))
	return total


# "agree", "warn", "oppose" or "" (no opinion)
func stance(opt: Dictionary, partner := "") -> String:
	if not Campaign.cards_active() or (partner == "" and not active()):
		return ""
	var s := score(opt, partner)
	if s >= 1.5:
		return "agree"
	if s <= -1.5:
		return "oppose"
	if s <= -0.75:
		return "warn"
	return ""


func chip(stance_id: String) -> String:
	return "%s %s" % [who().substr(0, 1), str(WORDS.get(stance_id, ""))] if stance_id != "" else ""


# a partner who is fed up vetoes what they oppose
func blocks(stance_id: String) -> bool:
	return active() and trust < BLOCK_TRUST and stance_id == "oppose"


# the card was answered: following their stance earns trust, overriding costs it
func on_pick(stance_id: String) -> String:
	match stance_id:
		"agree":
			follows += 1
			change(2)
			return "%s: TRUST +2." % who().to_upper()
		"warn":
			change(-1)
			return "%s: TRUST -1." % who().to_upper()
		"oppose":
			# X9: going against a partner's firm no is felt: more trust lost each time, and they sulk for two weeks
			overrides += 1
			var cost := 5 + mini(overrides - 1, 3)
			change(-cost)
			sulk = 2
			return "%s OPPOSED THIS: TRUST -%d, AND THEY HOLD BACK FOR TWO WEEKS." % [who().to_upper(), cost]
	return ""


# X9: what an option does to the trust of THIS partner: the arrows on a card ("UP", "DOWN", "SAME")
func trust_delta(opt: Dictionary) -> int:
	var fx: Dictionary = opt.get("fx", {})
	if not fx.has("trust"):
		return 0
	return int((fx.trust as Dictionary).get(who(), 0))


func trust_word_for(delta: int) -> String:
	if delta > 0:
		return "UP"
	return "DOWN" if delta < 0 else "SAME"


# ---- the weekly settle and the meetings --------------------------------------------------------------------------
# called from Owner.settle: the quiet drift of the partnership, and the walk-out at zero
func week(profit: int) -> void:
	if not Campaign.cards_active() or left:
		return
	sulk = maxi(0, sulk - 1)
	if profit > 0 and Owner.cash >= 2000 and Campaign.day % 2 == 0:
		change(1)
	elif Owner.cash < 0:
		change(-1)
	if _pending_leave:
		leave()


func leave() -> void:
	if left:
		return
	left = true
	_pending_leave = false
	var pname := who()
	Owner.burnout = clampf(Owner.burnout + 4.0, 0.0, 100.0)
	for c in Sales.active:
		Sales.adjust(int(c), -2)
	World.apply_roster()
	changed.emit()
	Cards.ask(
		"Marge (Bookkeeper)",
		"%s cleared out their desk this morning. They are leaving the company. We will sort out the share at the board review. Until then the work and the draw are all yours." % pname,
		[{"label": "OK", "id": "ok"}],
		func(_p: String) -> void: pass
	)


func beat_for_week(week_no: int) -> String:
	for id in BEATS:
		if int(BEATS[id].week) == week_no:
			return str(id)
	return ""


# opens the partner meeting of this week (as an Owner dynamic card so it uses the usual card machinery)
func hold_beat(id: String) -> void:
	if not Campaign.cards_active() or left or met.has(id) or not BEATS.has(id):
		return
	met.append(id)
	var beat: Dictionary = BEATS[id]
	var card := {"speaker": str(beat.speaker), "beat": true, "options": beat.options.duplicate(true)}
	card["text"] = str(beat.text.get(who(), beat.text.values()[0]))
	Owner._dynamic[id] = card
	Owner.show_card(id)


# ---- the endings ------------------------------------------------------------------------------------------------
# a rift: the partnership is not going to survive the review (a buy-out becomes possible)
func rift() -> bool:
	return left or trust < RIFT_TRUST


func status_lines() -> Array:
	var pname := who().to_upper()
	var lines := []
	if left:
		lines.append(["%s LEFT THE COMPANY." % pname, Color("a02828")])
	else:
		lines.append(["TRUST WITH %s: %d (%s)" % [pname, trust, trust_word()], Color("17121f")])
		lines.append(
			["YOU FOLLOWED %d OF THEIR CALLS AND OVERRODE %d." % [follows, overrides], Color("17121f")]
		)
	return lines
