extends RefCounted
# X11: a save from before the second cast. The account manager and the bookkeeper had other names then; John and Christy took over
# their roles, so every saved key and value that is exactly one of the old names is mapped to the new one when a save is loaded
# (Campaign.continue_game calls names(cfg) right after reading the file). Text inside sentences (old messages) is left as it was.
# The old names are split so a rename script cannot touch them.

const OLD_SALES := "Vi" + "c"
const OLD_BOOKS := "Mar" + "ge"
const MAP := {
	OLD_SALES: "John",
	OLD_BOOKS: "Christy",
	OLD_SALES + " Marlowe": "John Marlowe",
	OLD_SALES + " (Account Manager)": "John (Account Manager)",
	OLD_BOOKS + " (Bookkeeper)": "Christy (Controller)",
	"office_" + "vi" + "c": "office_john",
	"office_" + "mar" + "ge": "office_christy",
}


# rewrites the loaded file in memory; returns how many keys and values were renamed
static func names(cfg: ConfigFile) -> int:
	var count := [0]
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			var before: Variant = cfg.get_value(section, key)
			var n := int(count[0])
			var after: Variant = fix(before, count)
			if int(count[0]) != n:
				cfg.set_value(section, key, after)
	return int(count[0])


# the value with every exact old name (a string, a dictionary key, an array entry) replaced. Containers are changed in place, so a
# typed array keeps its type.
static func fix(v: Variant, count: Array) -> Variant:
	if v is String:
		if MAP.has(v):
			count[0] = int(count[0]) + 1
			return MAP[v]
		return v
	if v is Array:
		for i in v.size():
			if v[i] is String or v[i] is Array or v[i] is Dictionary:
				v[i] = fix(v[i], count)
		return v
	if v is Dictionary:
		for k in v.keys():
			if v[k] is String or v[k] is Array or v[k] is Dictionary:
				v[k] = fix(v[k], count)
			if k is String and MAP.has(k):
				count[0] = int(count[0]) + 1
				if not v.has(MAP[k]):  # a save that somehow has both keeps the new name's value
					v[MAP[k]] = v[k]
				v.erase(k)
		return v
	return v
