extends SceneTree
# The systems reference (docs/design/systems-reference.md) is generated from the game's data by tests/make_systems_reference.gd.
#   Godot --headless --fixed-fps 60 --path godot -s res://tests/systems_reference.gd
# (a) HARD checks: the generator runs without an error, writes a document, and every section has a table with rows.
# (b) SOFT check: the section headings and the row count of each table are compared with the committed document. A difference is only
#     printed as WARN (other branches add content all the time, a hard failure would break every merge). Regenerate to clear it:
#       Godot --headless --path godot -s res://tests/make_systems_reference.gd
# (c) SOFT check: the era words and real vendor names of tests/canon_text.gd are looked for in the generated text (WARN only).

const DOC_REL := "docs/design/systems-reference.md"
const MIN_SECTIONS := 9
const MIN_TABLES := 60

var failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print(("ok   " if ok else "FAIL ") + what)


func _init() -> void:
	_run.call_deferred()


# headings and the number of table rows under each "###" heading
func _profile(text: String) -> Dictionary:
	var out := {}
	var cur := ""
	for line in text.split("\n"):
		if line.begins_with("## ") or line.begins_with("### "):
			cur = line.strip_edges()
			out[cur] = 0
		elif cur != "" and line.begins_with("| ") and not line.begins_with("| ---"):
			out[cur] = int(out[cur]) + 1
	# the first row under a heading is the column header: do not count it
	for k in out:
		out[k] = maxi(0, int(out[k]) - 1)
	return out


func _run() -> void:
	var repo := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var tmp := OS.get_user_data_dir().path_join("test_%d_systems_reference.md" % OS.get_process_id())
	var output := []
	var gen_args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/make_systems_reference.gd", "--", "--out", tmp]
	var code := OS.execute(OS.get_executable_path(), gen_args, output, true)
	_check(code == 0, "the generator ran without an error (exit code %d)" % code)
	if code != 0:
		print("".join(output).right(1500))
	_check(FileAccess.file_exists(tmp), "the generator wrote a document")
	var fresh := FileAccess.get_file_as_string(tmp)
	var fp := _profile(fresh)
	var sections := 0
	var tables := 0
	var empty := []
	for k in fp:
		if str(k).begins_with("## "):
			sections += 1
		else:
			tables += 1
			if int(fp[k]) == 0:
				empty.append(k)
	_check(sections >= MIN_SECTIONS, "the document has %d sections (at least %d)" % [sections, MIN_SECTIONS])
	_check(tables >= MIN_TABLES, "the document has %d tables (at least %d)" % [tables, MIN_TABLES])
	_check(empty.is_empty(), "no table is empty %s" % str(empty))
	_check(fresh.contains("Contents"), "the document has a contents list")
	# soft: drift against the committed copy
	var committed_path := repo.path_join(DOC_REL)
	if not FileAccess.file_exists(committed_path):
		print("WARN the committed %s does not exist: run make_systems_reference.gd" % DOC_REL)
	else:
		var cp := _profile(FileAccess.get_file_as_string(committed_path))
		var drift := 0
		for k in fp:
			if not cp.has(k):
				print("WARN section only in the fresh output: %s" % k)
				drift += 1
			elif int(cp[k]) != int(fp[k]):
				print("WARN rows changed in %s: committed %d, now %d" % [k, int(cp[k]), int(fp[k])])
				drift += 1
		for k in cp:
			if not fp.has(k):
				print("WARN section only in the committed doc: %s" % k)
				drift += 1
		print("%s: %d section/table differences (warnings only)" % [DOC_REL, drift])
	# soft: canon words
	var low := fresh.to_lower()
	var banned: Array = load("res://scripts/strings.gd").BANNED
	var canon_hits := 0
	for w in banned:
		var re := RegEx.new()
		var esc := ""
		for ch in str(w).strip_edges().to_lower():
			esc += ("\\" + ch) if ch in ".-+*?()[]{}|^$\\" else ch
		re.compile("(?<![a-z0-9])" + esc + "(?![a-z0-9])")
		var m := re.search(low)
		if m != null:
			canon_hits += 1
			print("WARN era word in the generated text: %s" % str(w))
	print("canon: %d era words found (warnings only)" % canon_hits)
	DirAccess.remove_absolute(tmp)
	print("failures = %d" % failures)
	quit(1 if failures > 0 else 0)
