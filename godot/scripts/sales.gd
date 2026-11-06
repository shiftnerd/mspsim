extends Node
# The sales side: the account manager (John) brings in the work. Clients each have a
# satisfaction (0-100) that moves with how their tickets go; the number of ACTIVE clients sets
# how many tickets come in (Msp.pace), and John's visits can sign new clients or sell desktop
# installs. When a client is unhappy and has an open ticket that is late, they complain to John,
# who walks in and tells you (a Cards decision). Everything here only runs inside a campaign.

signal changed
signal client_signed(client: int)

const START_CLIENTS := [0, 1, 2, 3, 4]
const MAX_CLIENTS := 8
const INSTALL_JOB := 150  # owner campaign: what a sold desktop install pays the company
const COMPLAINT_GAP := 75.0  # game seconds between complaints
const CLIENT_COMPLAINT_WEEKS := 2  # owner campaign: the same client complains to John at most every other week
const SIGN_TEXT := "Just signed %s! Their IT is a mess. Welcome them gently."

var active: Array = START_CLIENTS.duplicate()
var satisfaction := {}  # client -> 0..100
var deals := 0
var last_deal := "JOHN CLOSED A DEAL!"  # what the sales bell says
var installs_sold := 0
var pending: Dictionary = {}  # a complaint waiting for John to deliver it
var signed_day := {}  # client -> campaign day John signed them: no tickets until the next day
var complained_day := {}  # client -> campaign day of their last complaint (the owner's weeks spread them out)

var _cool := 40.0


func _ready() -> void:
	reset()


func reset() -> void:
	active = START_CLIENTS.duplicate()
	satisfaction = {}
	for c in Msp.CLIENTS.size():
		satisfaction[c] = 70
	deals = 0
	installs_sold = 0
	pending = {}
	signed_day = {}
	complained_day = {}
	_cool = 40.0


# Year 2 raises the cap (the three newer clients start on the books)
func max_clients() -> int:
	return Yeartwo.max_clients(MAX_CLIENTS)


func is_active(client: int) -> bool:
	return active.has(client)


# a client signed today only starts sending tickets tomorrow (the sign-up mail says so)
func takes_tickets(client: int) -> bool:
	if not active.has(client):
		return false
	return not (Campaign.active and int(signed_day.get(client, -1)) == Campaign.day)


func pick_client() -> int:
	var ready: Array = []
	for c in active:
		if takes_tickets(int(c)):
			ready.append(c)
	if ready.is_empty():
		ready = active
	var total := 0.0
	for c in ready:
		total += Owner.client_weight(int(c))
	var roll := Difficulty.rng("msp.tickets").randf() * total
	for c in ready:
		roll -= Owner.client_weight(int(c))
		if roll <= 0.0:
			return int(c)
	return int(ready[0])


func mood(client: int) -> int:
	return int(satisfaction.get(client, 70))


func adjust(client: int, amount: int) -> void:
	if not Campaign.active:
		return
	satisfaction[client] = clampi(mood(client) + amount, 0, 100)
	changed.emit()


func average() -> float:
	var total := 0
	for c in active:
		total += mood(int(c))
	return float(total) / float(maxi(1, active.size()))


# end-of-day nudge to reputation from how happy the clients are
func rep_effect() -> int:
	var a := average()
	if a >= 80.0:
		return 1
	if a <= 45.0:
		return -2
	return -1 if a <= 60.0 else 0


# more clients = more tickets; Msp asks for this every time it schedules one
func workload() -> float:
	return float(active.size()) / 5.0 + SalesCampaign.extra_load()


# ---- John's skill ----------------------------------------------------------------------------
func vic_skill() -> float:
	var skill := 0.45 + float(Campaign.rep) / 250.0 + Owner.vic_extra()
	if Social.is_friendly("John"):
		skill += 0.1
	if Social.is_cold("John"):
		skill -= 0.15
	return clampf(skill, 0.15, 0.95)


# John is back from a client visit: maybe he closed something
func visit_done() -> bool:
	if not Campaign.active or not Msp.enabled:
		return false
	if Difficulty.rng("sales").randf() > vic_skill():
		Msp.send_text("John", "Client meeting went nowhere. Next time.")
		return false
	var dealt := -1
	if active.size() < max_clients() and (Difficulty.rng("sales").randf() < 0.55 or Msp.project_busy()):
		dealt = sign_client()
		if dealt >= 0:
			last_deal = "JOHN CLOSED " + str(Msp.CLIENTS[dealt].name).to_upper() + "!"
	else:
		dealt = sell_install()
		if dealt >= 0:
			last_deal = "JOHN SOLD A DESKTOP INSTALL!"
	return dealt >= 0


func sign_client(wanted := -1) -> int:
	var pool := []
	for c in Msp.CLIENTS.size():
		if not active.has(c):
			pool.append(c)
	if pool.is_empty():
		return -1
	var client: int = pool[Difficulty.rng("sales").randi() % pool.size()]
	if wanted >= 0 and pool.has(wanted):
		client = wanted
	active.append(client)
	signed_day[client] = Campaign.day
	satisfaction[client] = Owner.new_client_mood() if Campaign.cards_active() else 75
	deals += 1
	Owner.on_deal("client", client)
	Msp.send_text("John", SIGN_TEXT % Msp.CLIENTS[client].name)
	Msp.mail(
		"John Marlowe - Sales",
		"New client: " + str(Msp.CLIENTS[client].name),
		(
			"Signed %s today. Contact is %s. Expect their tickets from tomorrow. - John"
			% [Msp.CLIENTS[client].name, Msp.CLIENTS[client].contact]
		)
	)
	client_signed.emit(client)
	changed.emit()
	return client


func sell_install() -> int:
	if Campaign.books_active():
		# the owner campaign has no desk project for the team to work: the sale is a one-off job
		# (the crew does the setup between tickets), so it can never block the next sale
		var who := pick_client()
		installs_sold += 1
		Owner.on_deal("install", who)
		Owner.cash += INSTALL_JOB
		Owner.income_extra += INSTALL_JOB
		Msp.send_text(
			"John", "Sold %s a new desktop. The crew sets it up between tickets." % Msp.CLIENTS[who].name
		)
		changed.emit()
		return who
	if Msp.project_busy():
		return -1
	var client := pick_client()
	var contact: String = Msp.CLIENTS[client].contact
	var prob := Msp.INSTALL.duplicate()
	prob["summary"] = "New desktop for %s - set up and migrate" % contact
	var t := Msp.create_problem(client, prob, "sales")
	if t.is_empty():
		return -1
	Msp.start_project(int(t.id))
	installs_sold += 1
	Owner.on_deal("install", client)
	Msp.send_text("John", "Sold %s a new desktop. It is in your queue." % Msp.CLIENTS[client].name)
	changed.emit()
	return int(t.id)


# ---- complaints -----------------------------------------------------------------------------
# the client with a late open ticket and low satisfaction complains to John
func complaint_cooling(client: int) -> bool:
	return (
		Campaign.cards_active()
		and Campaign.day - int(complained_day.get(client, -99)) < CLIENT_COMPLAINT_WEEKS
	)


func find_complaint() -> Dictionary:
	var best := {}
	var worst := 1000.0
	for t in Msp.open_tickets():
		if t.internal or not active.has(int(t.client)) or str(t.special) != "":
			continue
		if complaint_cooling(int(t.client)):
			continue
		var urgency: float = (
			(-1000.0 if t.breached else float(t.sla_left)) + float(mood(int(t.client)))
		)
		if (t.breached or float(t.sla_left) < 45.0) and urgency < worst:
			worst = urgency
			best = {"ticket": int(t.id), "client": int(t.client)}
	return best


func _process(delta: float) -> void:
	if not Campaign.active or not Msp.enabled or Game.title_mode or World.time_scale <= 0.0:
		return
	_cool -= delta * World.time_scale
	if _cool > 0.0 or not pending.is_empty():
		return
	var found := find_complaint()
	if found.is_empty():
		_cool = 10.0
		return
	_cool = COMPLAINT_GAP
	pending = found
	complained_day[int(found.client)] = Campaign.day
	if Campaign.player_as == "John":
		deliver()  # you are John: the client phones you directly
	else:
		World.send_vic_to_player()


func complaint_text() -> String:
	var t := Msp.ticket(int(pending.get("ticket", 0)))
	if t.is_empty() or str(t.status) == "Closed":
		return ""
	var contact: String = Msp.CLIENTS[int(t.client)].contact
	var late := "is past its SLA" if t.breached else "has %s left" % Msp.mmss(float(t.sla_left))
	if Campaign.player_as == "John":
		return "Ticket #%d (%s) %s and my staff are not happy. Is anyone working on it?" % [int(t.id), t.summary, late]
	return (
		"%s from %s called me directly. Ticket #%d (%s) %s and they are not happy."
		% [contact, Msp.CLIENTS[int(t.client)].name, int(t.id), t.summary, late]
	)


# John reached you with the news: ask what you want to do
func deliver() -> void:
	if pending.is_empty():
		return
	var text := complaint_text()
	if text == "":
		pending = {}
		return
	Career.add("vic_calls")
	var vic_friend := Social.is_friendly("John")
	var options := [
		{"label": "I WILL PRIORITIZE IT", "id": "prio"},
		{"label": "TELL THEM IT IS IN THE QUEUE", "id": "queue"},
		{"label": "CAN YOU CALM THEM DOWN?", "id": "calm"},
	]
	if vic_friend:
		options[2]["label"] = "CAN YOU CALM THEM DOWN? (JOHN OWES YOU)"
	var ticket_id := int(pending.get("ticket", 0))
	var speaker := "John Marlowe"
	if Campaign.player_as == "John":
		speaker = str(Msp.CLIENTS[int(pending.get("client", 0))].contact)
		options[2]["label"] = "I WILL CALL THEM AND CALM THEM DOWN"
	Cards.ask(
		speaker,
		text,
		options,
		resolve,
		func() -> bool: return str(Msp.ticket(ticket_id).get("status", "Closed")) != "Closed"
	)


func resolve(choice: String) -> void:
	var t := Msp.ticket(int(pending.get("ticket", 0)))
	var client := int(pending.get("client", 0))
	pending = {}
	if t.is_empty() or str(t.status) == "Closed":
		return
	match choice:
		"prio":
			t.pri = 1
			t.sla_left = maxf(float(t.sla_left), 60.0)
			t.breached = false if float(t.sla_left) > 0.0 else t.breached
			t.notes.append("Escalated by the account manager.")
			adjust(client, 6)
			Social.change("John", 1)
			Skills.add_xp("people", 3)
		"queue":
			adjust(client, -6)
			Social.change("John", -2)
		_:
			t.sla_left = float(t.sla_left) + 60.0
			t.notes.append("Account manager managed the client.")
			adjust(client, 2)
			Social.change("John", 0 if Social.is_friendly("John") else -1)
	Msp.changed.emit()


func to_dict() -> Dictionary:
	return {
		"active": active.duplicate(),
		"sat": satisfaction.duplicate(),
		"deals": deals,
		"installs": installs_sold
	}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Array = data.get("active", [])
	if not saved.is_empty():
		active = saved
	var sat: Dictionary = data.get("sat", {})
	for key in sat:
		satisfaction[int(key)] = int(sat[key])
	deals = int(data.get("deals", 0))
	installs_sold = int(data.get("installs", 0))
