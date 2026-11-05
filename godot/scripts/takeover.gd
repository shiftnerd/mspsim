extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length
# R38 P0: inherited messes (docs/scope-bad-habits.md section 3). A static helper like Incident.
# A client that switches to you from a rival is a takeover onboarding: an onsite visit of the kind "takeover". The state is
# Owner.inherit: client -> inherited risk 0-100 (starts at the unresolved findings x 15, each fixed finding drops it, saved with the campaign).
# FINDINGS_TAKEOVER (the six walk-around findings, same shape as Onsite.FINDINGS) is empty until the onsite agent fills it.
# The visit itself is NOT wired yet: ENABLED stays false until Onsite knows the kind "takeover" (meeting row, findings, grade).
# OWNER OF THIS FILE: the takeover agent (takeover.gd + onsite.gd hooks + the Playbook books). Public signatures below are FINAL.

const ENABLED := false  # TODO(takeover agent): true when Onsite.start_visit(c, "takeover") works end to end
const KIND := "takeover"
const PER_FINDING := 15  # inherited risk per unresolved finding
const FINDINGS_TAKEOVER: Array = []  # TODO(takeover agent): six entries, one per job below

# the six jobs: name (card text), rap (the habit that becomes PROVEN when it is done), twin (the good habit it teaches)
const JOBS := {
	"T1": {"name": "THE FREEZER BAG", "rap": "R01", "twin": "H1"},
	"T2": {"name": "STICKY NOTES AND THE ONE PASSWORD", "rap": "R02", "twin": "H7"},
	"T3": {"name": "THE DOOR THAT WAS ALWAYS OPEN", "rap": "R15", "twin": "H8"},
	"T4": {"name": "GREEN AND EMPTY", "rap": "R04", "twin": "H11"},
	"T5": {"name": "DEFAULT PASSWORDS", "rap": "R15", "twin": "H14"},
	"T6": {"name": "WHO STILL HAS A KEY", "rap": "R14", "twin": "H6"},
}


# the inherited risk of a client (0 = none)
static func inherit(client: int) -> int:
	return clampi(int(Owner.inherit.get(client, 0)), 0, 100)


static func set_inherit(client: int, value: int) -> void:
	value = clampi(value, 0, 100)
	if value <= 0:
		Owner.inherit.erase(client)
	else:
		Owner.inherit[client] = value


# a takeover starts: the risk is the number of open findings times PER_FINDING (T1-T6 unless told otherwise)
static func begin(client: int, open_findings := 6) -> void:
	set_inherit(client, open_findings * PER_FINDING)


# a finding was fixed: the risk drops by PER_FINDING. Returns the new risk.
static func fixed(client: int, _job := "") -> int:
	set_inherit(client, inherit(client) - PER_FINDING)
	return inherit(client)


# clients that still carry an inherited mess
static func open_clients() -> Array:
	var out := []
	for c in Owner.inherit:
		if inherit(int(c)) > 0:
			out.append(int(c))
	return out


# weekly effect of the unfixed mess on a client's incident chances (1.0 = none). TODO(takeover agent): ransom, breach, outage hooks
static func risk_mult(client: int) -> float:
	return 1.0 + float(inherit(client)) / 200.0


# the fx visit <kind>: start a takeover visit for the most recently returned client. A no-op until ENABLED.
static func visit(owner: Node, kind: String) -> void:
	if kind != KIND or not ENABLED:
		return
	var client := -1
	for c in owner.gone:
		client = int(c)
	if client < 0 and not Sales.active.is_empty():
		client = int(Sales.active[0])
	if client >= 0:
		begin(client, FINDINGS_TAKEOVER.size())
		Onsite.start_visit(client, KIND)


# the walk-around hook (Onsite.inspect calls it with the object): record the evidence a job proves. TODO(takeover agent)
static func on_inspect(_client: int, _obj: String) -> void:
	pass
