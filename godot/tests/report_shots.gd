extends SceneTree
# Screenshots of the day report in its worst cases (needs a renderer): a tech day with every row,
# the final day with an ending, a firing, and an owner week. Use -- --format=h|v|wide.

var frame := 0
var variants := ["tech", "ending", "fired", "owner", "cozy"]


func _initialize() -> void:
	change_scene_to_file("res://scenes/main_floor.tscn")


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("user://report_%s.png" % name)


func _report(kind: String) -> Dictionary:
	var r := {
		"day": 7,
		"total_days": 20,
		"closed": 6,
		"missed": 1,
		"reopened": 0,
		"open_left": 2,
		"clients": 72,
		"points": 14,
		"overtime": 1.5,
		"social": 3,
		"energy": 31,
		"late": 25,
		"oncall": 1,
		"pay": 340,
		"rep_delta": 3,
		"rep": 53,
		"cash": 1280,
		"grade": "B",
		"fired": false,
		"final": false,
		"ending": "",
	}
	match kind:
		"cozy":  # cozy Easy (R16): a bad day with no red, no minus lines, a probation note
			r["cozy"] = true
			r["missed"] = 3
			r["reopened"] = 2
			r["open_left"] = 4
			r["points"] = -9
			r["social"] = -2
			r["pay"] = 100
			r["rep_delta"] = -3
			r["rep"] = 15
			r["grade"] = "D"
			r["notes"] = [root.get_node("Difficulty").ct("probation_note")]
		"ending":
			r["day"] = 20
			r["final"] = true
			r["grade"] = "A"
			r["ending"] = "YOU KEPT YOUR JOB. MORGAN SAYS THE TEAM IS GLAD YOU STAYED AND THE CLIENTS ASK FOR YOU BY NAME."
		"fired":
			r["fired"] = true
			r["final"] = true
			r["grade"] = "D"
			r["rep"] = 0
			r["rep_delta"] = -10
			r["cash"] = -50
			r["ending"] = "YOUR REPUTATION HIT ZERO. THE BOSS ASKS FOR YOUR BADGE AND YOUR VAN KEYS."
		"owner":
			r["grade"] = "A"
			r["title"] = "WEEK 9 OF 20 COMPLETE"
			r["rows"] = [
				["REVENUE", "$6400", Color("8fe3a0")],
				["PAYROLL (W-2)", "-$3100", Color.WHITE],
				["OTHER COSTS + MARKETING", "-$1300", Color.WHITE],
				["JOBS AND DEALS", "+$450", Color("8fe3a0")],
				["EBITDA", "$2450", Color("8fe3a0")],
				["EBITDA MARGIN", "38% (PEERS 15%)", Color("8fe3a0")],
				["W-2 RATIO", "48% (TARGET 55%)", Color("8fe3a0")],
				["CASH", "$9800", Color("8fe3a0")],
				["CLIENTS, A/R OWED", "8 (70%), $1200", Color("ffd27a")],
				["OWNER HOURS", "22 FREE", Color.WHITE],
				["RECURRING + PROJECTS", "$6400/WK + $450 JOBS", Color("8fe3a0")],
				["VALUE (ESTIMATE)", "$412000, GROWTH", Color("ffd27a")],
			]
	return r


func _process(_delta: float) -> bool:
	frame += 1
	if current_scene == null:
		return false
	var step := frame / 20
	if frame % 20 == 0 and step >= 1 and step <= variants.size():
		if step > 1:
			_shot(variants[step - 2])
		root.get_node("DayReport").is_open = false
		root.get_node("DayReport").show_report(_report(variants[step - 1]))
	if frame == 20 * (variants.size() + 1):
		_shot(variants[variants.size() - 1])
		quit()
	return false
