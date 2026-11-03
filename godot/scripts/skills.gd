extends Node
# Tech skills for the campaign. Five skills: POWERSHELL (levels come from the Academy lessons),
# NETWORKING, SERVERS, SECURITY and CUSTOMER (levels come from experience: fixing and closing
# tickets). PowerShell is the one that changes how you play: higher levels make remote fixes
# faster and more reliable, and
# unlock scripts that fix a whole client (level 2) or every client (level 4) at once.
# Outside a campaign (free play, tests) fixes are instant and always work, like before.

signal leveled(skill: String, new_level: int)

const NAMES := {
	"powershell": "POWERSHELL",
	"networking": "NETWORKING",
	"servers": "SERVERS",
	"security": "SECURITY",
	"people": "CUSTOMER",
}
const XP_AT := [15, 40, 80, 130, 200]  # experience needed for levels 1 to 5
const FIX_XP := {
	"spooler": "networking",
	"password": "security",
	"clear_temp": "servers",
	"reboot": "servers",
	"av": "security",
	"restore": "security",
	"adobe": "servers",
}
const FIX_SECS := [6.0, 5.0, 4.0, 3.0, 2.0, 1.5]  # by PowerShell level
const FAIL := [0.25, 0.18, 0.1, 0.04, 0.0, 0.0]
# each question: [question, right answer, wrong, wrong]
const LESSONS := [
	{
		"title": "FIRST STEPS",
		"qs":
		[
			["WHICH CMDLET LISTS RUNNING SERVICES?", "GET-SERVICE", "SHOW-SERVICES", "LIST-SVC"],
			["HOW DO YOU READ HELP FOR A CMDLET?", "GET-HELP", "HELP-ME", "ASK-PS"],
			["CMDLETS ARE NAMED LIKE...", "VERB-NOUN", "NOUN.VERB", "ANYTHING"],
		]
	},
	{
		"title": "THE PIPELINE",
		"qs":
		[
			[
				"WHAT DOES THE | CHARACTER DO?",
				"PASSES OUTPUT ON",
				"ENDS THE COMMAND",
				"STARTS A COMMENT"
			],
			["WHICH CMDLET FILTERS OBJECTS?", "WHERE-OBJECT", "FILTER-ONLY", "FIND-IT"],
			["WHICH CMDLET PICKS PROPERTIES?", "SELECT-OBJECT", "PICK-PROP", "CHOOSE-FIELD"],
		]
	},
	{
		"title": "FIXING THINGS",
		"qs":
		[
			[
				"HOW DO YOU RESTART THE SPOOLER?",
				"RESTART-SERVICE SPOOLER",
				"RELOAD SPOOLER",
				"REBOOT-SERVICE"
			],
			["WHICH CMDLET UNLOCKS AN AD ACCOUNT?", "UNLOCK-ADACCOUNT", "OPEN-USER", "CLEAR-LOCK"],
			["WHICH CMDLET DELETES FILES?", "REMOVE-ITEM", "ERASE-FILE", "DEL-NOW"],
		]
	},
	{
		"title": "WRITING SCRIPTS",
		"qs":
		[
			["A SCRIPT FILE ENDS IN...", ".PS1", ".PSX", ".SCRIPT"],
			["RUN A COMMAND ON MANY PCS WITH...", "INVOKE-COMMAND", "RUN-ALL", "FOR-PCS"],
			["LOOP OVER A LIST WITH...", "FOREACH", "EACHOF", "WHILEALL"],
		]
	},
	{
		"title": "STAYING SAFE",
		"qs":
		[
			["TEST A CHANGE WITHOUT DOING IT:", "-WHATIF", "-DRYRUN", "-PRETEND"],
			["CATCH ERRORS WITH...", "TRY / CATCH", "OOPS", "IF-ERROR"],
			["MAKE ERRORS STOP A SCRIPT:", "-ERRORACTION STOP", "-QUIT", "-HALT"],
		]
	},
]

var xp := {}
var ps_level := 0
var lesson_day := -1  # the day an Academy lesson was last passed (one a day)


func _ready() -> void:
	reset()


func reset() -> void:
	xp = {}
	for key in NAMES:
		xp[key] = 0
	ps_level = 0
	lesson_day = -1


func level(skill: String) -> int:
	if skill == "powershell":
		return ps_level
	var n := 0
	for need in XP_AT:
		if int(xp.get(skill, 0)) >= int(need):
			n += 1
	return n


# 0..1 progress toward the next level
func progress(skill: String) -> float:
	var lv := level(skill)
	if skill == "powershell":
		return float(lv) / 5.0
	if lv >= XP_AT.size():
		return 1.0
	var low := 0 if lv == 0 else int(XP_AT[lv - 1])
	return clampf(float(int(xp.get(skill, 0)) - low) / float(int(XP_AT[lv]) - low), 0.0, 1.0)


func add_xp(skill: String, amount: int) -> void:
	if not Campaign.active or skill == "powershell" or not NAMES.has(skill):
		return
	var before := level(skill)
	xp[skill] = int(xp.get(skill, 0)) + amount
	if level(skill) > before:
		leveled.emit(skill, level(skill))
		var perk := perk_text(skill, level(skill))
		var note := "Nice work: %s is now level %d." % [NAMES[skill].capitalize(), level(skill)]
		Msp.send_text("Boss", note + (" New: %s." % perk.to_lower() if perk != "" else ""))


func can_study() -> bool:
	return not Campaign.active or lesson_day != Campaign.day


# one lesson a day: studying takes real time and a little energy
func pass_lesson(index: int) -> void:
	if Campaign.active and lesson_day == Campaign.day:
		return
	if index == ps_level and ps_level < LESSONS.size():
		ps_level += 1
		lesson_day = Campaign.day
		if Campaign.active:
			Shift.add_energy(-3.0)
		leveled.emit("powershell", ps_level)


func fix_secs() -> float:
	return float(FIX_SECS[ps_level]) * Shift.slow_mult() if Campaign.active else 0.0


func fail_chance() -> float:
	return maxf(0.0, float(FAIL[ps_level]) + Shift.fail_add()) if Campaign.active else 0.0


# CUSTOMER level 2: you read the room and can tell whether the person at the machine has work open
func sees_open_docs() -> bool:
	return Campaign.active and level("people") >= 2


# the time a remote fix takes: PowerShell sets the base, then the fix's own skill speeds it up
func fix_secs_for(action: String) -> float:
	var base := fix_secs()
	if base <= 0.0:
		return base
	var alt: Dictionary = Msp.ALT_DEFS.get(action, {})
	var skill := str(FIX_XP.get(str(alt["for"][0]) if not alt.is_empty() else action, ""))
	var mult := float(alt.get("mult", 1.0))
	if skill in ["servers", "security", "networking"]:
		mult -= 0.06 * float(level(skill))
		if Campaign.mode == "tech" and Growth.graduated and Growth.focus == skill:
			mult *= 0.75  # Tier 2 in this skill
	return base * mult


# SECURITY level 3: the backup jobs tell you when they fail without a daily CHECK
func backup_watch() -> bool:
	return Campaign.active and level("security") >= 3


# CUSTOMER level 3+: clients are more patient, so SLA clocks tick a little slower
func sla_pace() -> float:
	if not Campaign.active:
		return 1.0
	return 1.0 - 0.05 * float(maxi(0, level("people") - 2))


func perk_text(skill: String, lv: int) -> String:
	match skill:
		"servers", "security", "networking":
			if skill == "security" and lv == 3:
				return "BACKUP WATCH: BACKUPS CHECK THEMSELVES"
			if skill == "networking" and lv == 2:
				return "CLOSET TIP + COPIER REROUTE"
			return "%s FIXES %d%% FASTER" % [NAMES[skill], 6 * lv]
		"people":
			if lv == 2:
				return "YOU CAN SEE IF A USER HAS WORK OPEN"
			return "SLAS TICK %d%% SLOWER" % (5 * (lv - 2)) if lv > 2 else ""
	return ""


# the next special perk the player has not reached yet (for the profile)
func next_perk() -> String:
	for entry in [["people", 2], ["networking", 2], ["security", 3], ["people", 3]]:
		if level(str(entry[0])) < int(entry[1]):
			var text := perk_text(str(entry[0]), int(entry[1]))
			return "NEXT PERK: %s %d = %s" % [NAMES[entry[0]], int(entry[1]), text]
	return ""


func can_script() -> bool:
	return ps_level >= 2


func script_all() -> bool:
	return ps_level >= 4


func to_dict() -> Dictionary:
	return {"xp": xp.duplicate(), "ps": ps_level, "lesson_day": lesson_day}


func from_dict(data: Dictionary) -> void:
	reset()
	var saved: Dictionary = data.get("xp", {})
	for key in saved:
		xp[key] = int(saved[key])
	ps_level = int(data.get("ps", 0))
	lesson_day = int(data.get("lesson_day", -1))
