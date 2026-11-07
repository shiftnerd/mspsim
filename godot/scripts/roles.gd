extends Node
# gdlint:disable=max-returns
# Who is who. Cards, texts and ticket owners name a person by their job ("Alan (Co-owner)" advises you,
# "Boss" texts you). When you play AS that person (Campaign.player_as) the line has to come from somebody else:
# the other owner in the owner campaign, otherwise the manager. `speaker()` and `sender()` do that remap; Cards.ask and
# Msp.send_text call them, so no card has to know. X4 (the owner campaign rework) will give the cards real owner voices.

const OWNERS := ["Alan", "Garrison"]
const LABELS := {
	"Alan": "Alan (Co-owner)",
	"Garrison": "Garrison (Co-owner)",
	"Dan": "Dan (Service Manager)",
	"John": "John (Account Manager)",
	"Maya": "Maya (Tier 1)",
	"Morgan": "Morgan (Manager)",
}
# job -> the person who normally does it
const JOBS := {
	"tech owner": "Alan",
	"sales owner": "Garrison",
	"manager": "Morgan",
	"network": "Dan",
	"accounts": "John",
	"tier1": "Maya",
}


func player() -> String:
	return Campaign.player_as


# the owner who is NOT you (owner campaign), "" otherwise
func partner() -> String:
	var me := Campaign.player_as
	if Campaign.mode != "owner" or not OWNERS.has(me):
		return ""
	return "Garrison" if me == "Alan" else "Alan"


# somebody who can say what `name` would have said
func stand_in(who_name: String) -> String:
	if who_name == "" or who_name != Campaign.player_as:
		return who_name
	var other := partner()
	return other if other != "" else "Morgan"


# the person doing a job right now ("tech owner" is Alan, unless you are Alan)
func who(job: String) -> String:
	return stand_in(str(JOBS.get(job, "Morgan")))


func label(who_name: String) -> String:
	return str(LABELS.get(who_name, who_name))


# "Alan (Co-owner)" / "Alan" -> the name part when it is a known cast member, else ""
func base_name(text: String) -> String:
	for n in LABELS:
		if text == n or text.begins_with(n + " ("):
			return n
	return ""


# a card speaker: the same text unless it names you
func speaker(text: String) -> String:
	var n := base_name(text)
	if n == "" or n != Campaign.player_as:
		return text
	return label(stand_in(n))


# a phone text sender
func sender(text: String) -> String:
	var n := base_name(text)
	if n == "" or n != Campaign.player_as:
		return text
	return stand_in(n)


# ---- names for the owner campaign's cards (X4): {tech} {ops} {partner} {me} --------------------------------------
# the colleague who gives you technical advice: Dan when you are Alan (the technical owner yourself), otherwise Alan
func tech() -> String:
	return "Dan" if Campaign.player_as == "Alan" else "Alan"


# the colleague who runs the desk day to day
func ops() -> String:
	return "Morgan"


# your own first name ("boss" when you are nobody in particular)
func me() -> String:
	return Campaign.player_as if Campaign.player_as != "" else "boss"


func _token(key: String) -> String:
	match key:
		"tech":
			return tech()
		"ops":
			return ops()
		"partner":
			return partner() if partner() != "" else "Morgan"
		"me":
			return me()
		"sales_owner":
			return stand_in("Garrison")
		"tech_owner":
			return stand_in("Alan")
	return ""


# {tech} -> a name, or "Dan (Service Manager)" when the whole text is the token (a speaker line)
func fill(text: String) -> String:
	if text.find("{") < 0:
		return text
	for key in ["tech", "ops", "partner", "me", "sales_owner", "tech_owner"]:
		var tok: String = "{" + str(key) + "}"
		if text == tok:
			return label(_token(key))
		text = text.replace(tok, _token(key))
	return text
