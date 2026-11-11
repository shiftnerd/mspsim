extends RefCounted
# R10: a small portrait of a card's speaker. The head of the speaker's character sheet (the first idle frame of the right-facing
# sheet, the head rows only) at 1x, drawn by cards.gd beside the text of a card that has no spot picture. No new art.
#   CardPortrait.head("Ross Calder") -> an AtlasTexture of that head (26 x 22), or null when the speaker has no character
const SHEET := "res://assets/characters/%s_right.png"
const HEAD := Rect2i(16, 19, 26, 22)  # the head of frame 0 (64 x 80 cells): hair, face, ear, neck. Right-facing, so it looks at the text
# people who are not in the office cast (the Year 3 beats and the sales visitors); the cast comes from World's tables
const NAMED := {
	"quinn": "office_quinn",
	"ross calder": "office_ross",
	"terry vance": "office_terry",
	"trent dagmar": "office_trent",
	"ms. pell": "office_pell",
	"greg pell": "office_pell",
}

static var _cache := {}


# the character a speaker line stands for ("Ross Calder (Auditor)" is Ross Calder), "" when there is none
static func character_for(speaker: String) -> String:
	var base := speaker.get_slice(" (", 0).strip_edges().to_lower()
	if NAMED.has(base):
		return str(NAMED[base])
	for table in [World.CAST, World.CREW_CAST, World.STAFF_CAST]:
		for who in table:
			if str(who).to_lower() == base:
				return str(table[who].character)
	return ""


static func head(speaker: String) -> Texture2D:
	var id := character_for(speaker)
	if id == "":
		return null
	if not _cache.has(id):
		var path := SHEET % id
		var tex: AtlasTexture = null
		if ResourceLoader.exists(path):
			tex = AtlasTexture.new()
			tex.atlas = load(path)
			tex.region = Rect2(HEAD)
		_cache[id] = tex
	return _cache[id]
