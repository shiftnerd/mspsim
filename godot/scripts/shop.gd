extends Node
# gdlint:disable=max-line-length
# The shop (roadmap S1, docs/scope-shop.md): the tech campaign earns a paycheck every day (Campaign.cash) and can now spend it on desk
# upgrades from the NERDTHINK app on the work computer (scripts/shop_app.gd paints it). Every item has a small real effect, read through
# one place (factor / bonus) so each hook elsewhere is one line: Skills.fix_secs_for (fix_secs), Shift's daily drain (drain), the night's
# rest (rest) and the ticket-close XP (people_xp). A slot holds one item (one keyboard at a time: buying another switch replaces it, and
# the old one is not refunded). Purchases are saved with the campaign and come over into Year 2. Free Play owns everything. The Easy tier
# (cozy) takes a quarter off the price. The desk props that show what you bought are drawn by the stage (stage.gd, `Shop.owns`).

const STORE := "NERDTHINK"
const TAGLINE := "STUFF FOR GEEKS SINCE 2011"
const COZY_OFF := 0.75
# slot: one item per slot. fx: fix_secs and drain are multipliers, rest and people_xp are added. loud: coworkers near the desk hear it.
const CATALOG := [
	{"id": "kb_blue", "name": "CLICKY BLUE KEYBOARD", "price": 90, "slot": "keyboard", "fx": {"fix_secs": 0.95}, "loud": true, "what": "FIXES TAKE 5 PERCENT LESS TIME. LOUD: COWORKERS NOTICE."},
	{"id": "kb_brown", "name": "BROWN SWITCH KEYBOARD", "price": 100, "slot": "keyboard", "fx": {"fix_secs": 0.97}, "loud": false, "what": "FIXES TAKE 3 PERCENT LESS TIME. TACTILE AND QUIET."},
	{"id": "kb_red", "name": "RED SWITCH KEYBOARD", "price": 110, "slot": "keyboard", "fx": {"fix_secs": 0.96}, "loud": false, "what": "FIXES TAKE 4 PERCENT LESS TIME. SMOOTH, LIGHT AND QUIET."},
	{"id": "mouse", "name": "VERTICAL MOUSE", "price": 45, "slot": "mouse", "fx": {"drain": 0.95}, "what": "YOUR WRIST AND YOUR ENERGY LAST LONGER: 5 PERCENT LESS DRAIN."},
	{"id": "riser", "name": "STANDING DESK RISER", "price": 180, "slot": "riser", "fx": {"drain": 0.90}, "what": "FEWER SLUMPS: 10 PERCENT LESS ENERGY DRAIN."},
	{"id": "cushion", "name": "LUMBAR CUSHION", "price": 60, "slot": "chair", "fx": {"rest": 3}, "what": "A NIGHT'S SLEEP GIVES BACK 3 MORE ENERGY."},
	{"id": "headset", "name": "WIRELESS HEADSET", "price": 110, "slot": "headset", "fx": {"people_xp": 1}, "what": "CLEARER CALLS: EVERY CLIENT TICKET YOU CLOSE GIVES 1 MORE CUSTOMER XP."},
	{"id": "plant", "name": "DESK PLANT", "price": 20, "slot": "plant", "fx": {"rest": 1}, "what": "A LITTLE CALM: 1 MORE ENERGY BACK EACH NIGHT."},
	{"id": "rgb", "name": "RGB DESK STRIP", "price": 70, "slot": "light", "fx": {}, "what": "A COLOUR CYCLING GLOW BEHIND THE MONITORS. LOOKS GREAT, DOES NOTHING."},
	{"id": "speakers", "name": "DESK SPEAKERS", "price": 55, "slot": "speakers", "fx": {}, "what": "TWO SMALL SPEAKERS. FOR THE VIBE."},
	{"id": "toy", "name": "NEWTON'S CRADLE", "price": 30, "slot": "toy", "fx": {}, "what": "CLICK, CLICK, CLICK. PURELY FOR THINKING."},
	{"id": "poster", "name": "WALL POSTER", "price": 20, "slot": "poster", "fx": {}, "what": "SOMETHING TO LOOK AT BESIDE THE MONITORS."},
]

var owned: Array = []  # item ids, in the order bought
var sel := 0  # the selected row in the app (not saved)


func reset() -> void:
	owned = []


func to_dict() -> Dictionary:
	return {"owned": owned.duplicate()}


func from_dict(d: Variant) -> void:
	owned = []
	if d is Dictionary:
		for id in d.get("owned", []):
			if item(str(id)).size() > 0 and not owned.has(str(id)):
				owned.append(str(id))


# a new run that keeps the desk (Year 2)
func restore(ids: Variant) -> void:
	from_dict({"owned": ids if ids is Array else []})


func item(id: String) -> Dictionary:
	for it in CATALOG:
		if str(it.id) == id:
			return it
	return {}


func available() -> bool:
	return Campaign.active and Campaign.mode == "tech"


# Free Play owns everything (for filming); a campaign owns what it bought
func owns(id: String) -> bool:
	if not Campaign.active:
		return not item(id).is_empty()
	return owned.has(id)


func price(id: String) -> int:
	var it := item(id)
	if it.is_empty():
		return 0
	var p := float(it.price)
	if Difficulty.cozy_on():
		p *= COZY_OFF
	return int(round(p))


func in_slot(slot: String) -> String:
	for id in owned:
		if str(item(str(id)).get("slot", "")) == slot:
			return str(id)
	return ""


# can you buy it right now? "" = yes, otherwise the reason
func why_not(id: String) -> String:
	var it := item(id)
	if it.is_empty():
		return "NOT SOLD HERE"
	if not available():
		return "THE SHOP IS FOR THE TECH CAMPAIGN"
	if owned.has(id):
		return "YOU OWN IT"
	if Campaign.cash < price(id):
		return "NOT ENOUGH CASH ($%d)" % price(id)
	return ""


func buy(id: String) -> Dictionary:
	var why := why_not(id)
	if why != "":
		return {"ok": false, "msg": why}
	var it := item(id)
	var old := in_slot(str(it.slot))
	if old != "":
		owned.erase(old)  # the new one takes its place (no refund)
	Campaign.cash -= price(id)
	owned.append(id)
	Career.add("shop_items")
	var msg := "BOUGHT %s FOR $%d." % [str(it.name), price(id)]
	if old != "":
		msg += " THE OLD %s GOES IN THE DRAWER." % str(item(old).name)
	return {"ok": true, "msg": msg}


# the effects: a multiplier (1.0 = none) and an added amount (0 = none)
func factor(key: String) -> float:
	var f := 1.0
	for id in owned:
		var fx: Dictionary = item(str(id)).get("fx", {})
		if fx.has(key) and key in ["fix_secs", "drain"]:
			f *= float(fx[key])
	return f if Campaign.active else 1.0


func bonus(key: String) -> float:
	var b := 0.0
	for id in owned:
		var fx: Dictionary = item(str(id)).get("fx", {})
		if fx.has(key) and key in ["rest", "people_xp"]:
			b += float(fx[key])
	return b if Campaign.active else 0.0


# somebody near the desk can hear a clicky keyboard
func is_loud() -> bool:
	return Campaign.active and in_slot("keyboard") != "" and bool(item(in_slot("keyboard")).get("loud", false))
