extends Node
# Who is who. Cards, texts and ticket owners name a person by their job ("Alan (Co-owner)" advises you,
# "Boss" texts you). When you play AS that person (Campaign.player_as) the line has to come from somebody else:
# the other owner in the owner campaign, otherwise the manager. `speaker()` and `sender()` do that remap; Cards.ask and
# Msp.send_text call them, so no card has to know. X4 (the owner campaign rework) will give the cards real owner voices.

const OWNERS := ["Alan", "Garrison"]
const LABELS := {
	"Alan": "Alan (Co-owner)",
	"Garrison": "Garrison (Co-owner)",
	"Dan": "Dan (Network Tech)",
	"Vic": "Vic (Account Manager)",
	"Maya": "Maya (Tier 1)",
	"Morgan": "Morgan (Manager)",
}
# job -> the person who normally does it
const JOBS := {
	"tech owner": "Alan",
	"sales owner": "Garrison",
	"manager": "Morgan",
	"network": "Dan",
	"accounts": "Vic",
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
