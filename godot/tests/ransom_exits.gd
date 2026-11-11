extends SceneTree
# gdlint:disable=max-line-length
# P6 / Q6: the ransomware exits of the tech campaign, measured instead of worked out on paper. Each policy (an order of exits
# to try once the backup restore has failed) is played on N seeded runs: the real ticket, the real Msp.rmm_action calls. The
# table shows what a policy costs on average in score, reputation and time (in units of one plain fix), how often the files come
# back and how often everything is lost. The asserts say what "every exit is a real choice" means:
#   - giving up is the worst on score and reputation
#   - trying the free things first (vendor, insurer, shadow copies) and rebuilding only then has the best score
#   - paying at once is the fastest way to probably get the files, and costs clearly more score than the careful order
#   - the rebuild never loses the case and never brings the files back; it sits between the careful order and giving up
#   - no policy is the best on score AND the fastest
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/ransom_exits.gd [-- n=200]

const POLICIES := {
	"careful (vendor, insurer, shadow, rebuild)": ["vendor", "insurer", "shadow", "rebuild"],
	"free first, then pay (vendor, insurer, shadow, pay)": ["vendor", "insurer", "shadow", "pay"],
	"shadow, then pay": ["shadow", "pay"],
	"shadow, then rebuild": ["shadow", "rebuild"],
	"pay at once": ["pay"],
	"rebuild at once": ["rebuild"],
	"give up (close the ticket)": [],
}
const FILES_BACK := ["vendor", "insured", "paid", "restored"]

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	var n := 150
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("n="):
			n = int(str(a).substr(2))
	await process_frame
	var c := root.get_node("Campaign")
	var d := root.get_node("Difficulty")
	var msp := root.get_node("Msp")
	var story := root.get_node("Story")
	var sk := root.get_node("Skills")
	var cards := root.get_node("Cards")
	c.save_prefix = "user://test_%d_ransom_" % OS.get_process_id()
	d.settings_path = "user://test_%d_ransom_settings.cfg" % OS.get_process_id()
	root.get_node("Game").title_mode = false
	var res := {}
	for name in POLICIES:
		var plan: Array = POLICIES[name]
		var score := 0.0
		var rep := 0.0
		var time := 0.0
		var back := 0
		var most := 0
		var lost := 0
		for k in n:
			d.set_tier("normal")
			d.seed_run(1000 + k)
			c.new_game("tech")
			cards.flush()
			c.day = 9
			c.rep = 60
			msp.break_backup(story.RANSOM_CLIENT)
			story._ransomware()
			var t: Dictionary = msp.ticket(int(story.flags.get("ransom_ticket", 0)))
			var ep_name := str(t.endpoint)
			var score0: int = msp.score
			var base: float = maxf(1.0, sk.fix_secs())
			msp.rmm_action(ep_name, "restore")  # the backup is broken: this only tells you so
			time += 1.0
			for act in plan:
				if bool(t.fix_done):
					break
				if act == "insurer" and not msp.cyber_insured(story.RANSOM_CLIENT):
					continue
				time += sk.fix_secs_for(act) / base
				msp.rmm_action(ep_name, act)
			if not bool(t.fix_done):
				msp.close_ticket(int(t.id))  # closing it unfixed is giving up
			var how := str(story.flags.get("ransom", ""))
			back += 1 if how in FILES_BACK else 0
			most += 1 if how == "partial" else 0
			lost += 1 if how == "lost" else 0
			score += float(msp.score - score0)
			rep += float(c.rep - 60)
			cards.flush()
		res[name] = {"score": score / n, "rep": rep / n, "time": time / n, "back": 100.0 * back / n, "most": 100.0 * most / n, "lost": 100.0 * lost / n}
		print("EXIT %-52s score %6.1f  rep %5.1f  time x%.1f  files back %3.0f%%  most %3.0f%%  lost %3.0f%%" % [name, res[name].score, res[name].rep, res[name].time, res[name].back, res[name].most, res[name].lost])
	var careful: Dictionary = res["careful (vendor, insurer, shadow, rebuild)"]
	var pay: Dictionary = res["pay at once"]
	var rebuild: Dictionary = res["rebuild at once"]
	var give_up: Dictionary = res["give up (close the ticket)"]
	var best_score := ""
	var fastest := ""
	for name in res:
		if name.begins_with("give up"):
			continue
		_check(res[name].score > give_up.score and res[name].rep > give_up.rep, "%s beats giving up (score %.1f vs %.1f)" % [name, res[name].score, give_up.score])
		if best_score == "" or res[name].score > res[best_score].score:
			best_score = name
		if fastest == "" or res[name].time < res[fastest].time:
			fastest = name
	_check(best_score.begins_with("careful") or best_score.begins_with("free first"), "the best score comes from trying the free exits first (%s)" % best_score)
	_check(pay.back >= 60.0 and pay.time <= careful.time - 1.0, "paying at once is fast and usually returns the files (x%.1f against x%.1f, %d%%)" % [pay.time, careful.time, int(pay.back)])
	_check(pay.score <= careful.score - 4.0, "and costs clearly more score than the careful order (%.1f vs %.1f)" % [pay.score, careful.score])
	_check(is_zero_approx(rebuild.lost) and is_zero_approx(rebuild.back), "the rebuild never loses the case and never returns the files")
	_check(rebuild.score < careful.score and rebuild.score > give_up.score, "the rebuild sits between the careful order and giving up (%.1f)" % rebuild.score)
	_check(best_score != fastest, "no policy is both the best on score and the fastest (%s / %s)" % [best_score, fastest])
	c.quit_to_title()
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
