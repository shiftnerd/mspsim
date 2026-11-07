extends RefCounted
# gdlint:disable=class-definitions-order,class-variable-name,max-line-length,unsafe-method-access
# The NERDTHINK app (roadmap S1): the shop on the work computer. A list of the catalogue (Shop.CATALOG) with the price or OWNED, the
# selected item's effect underneath and a BUY button. Up / Down pick an item, Enter buys it. The state lives in Shop (sel, msg);
# this script only paints and routes input for the Computer (`cp` is the Computer autoload, same helpers as crm.gd).

const INK := Color("20242c")
const MUTED := Color("5a6a85")
const GOOD := Color("2f7d46")
const BAD := Color("a83a2e")


static func selected() -> Dictionary:
	return Shop.CATALOG[clampi(Shop.sel, 0, Shop.CATALOG.size() - 1)]


static func paint(cp) -> void:
	var body: Rect2 = cp._window("%s - %s" % [Shop.STORE, Shop.TAGLINE], Color("c0661f"))
	cp._fill(body, Color("f6f1e8"))
	var w: float = body.size.x
	cp._fill(Rect2(body.position, Vector2(w, 9)), Color("e8d9c0"))
	var strip := "CASH $%d   ITEMS %d OF %d" % [Campaign.cash, Shop.owned.size(), Shop.CATALOG.size()]
	if not Shop.available():
		strip = "THE SHOP IS FOR THE TECH CAMPAIGN. FREE PLAY OWNS IT ALL."
	cp._text(cp._clip(strip, int(w / 4.0) - 1), body.position + Vector2(3, 2), INK)
	var detail_h := 30.0
	var list := Rect2(body.position + Vector2(0, 10), Vector2(w, body.size.y - 10.0 - detail_h))
	cp._fill(list, Color("ffffff"))
	var per: int = maxi(1, int(list.size.y / 7.0))
	var top: int = clampi(Shop.sel - per + 1, 0, maxi(0, Shop.CATALOG.size() - per)) if Shop.sel >= per else 0
	for k in per:
		var i: int = top + k
		if i >= Shop.CATALOG.size():
			break
		var it: Dictionary = Shop.CATALOG[i]
		var row := Rect2(list.position.x, list.position.y + float(k) * 7.0, w, 7)
		cp._row(row, i == Shop.sel, k % 2 == 1)
		cp._region("shop:sel:%d" % i, row)
		var mine: bool = Shop.owns(str(it.id))
		cp._text(cp._clip(str(it.name), int((w - 44.0) / 4.0)), row.position + Vector2(2, 1), MUTED if mine else INK)
		var tag := "OWNED" if mine else "$%d" % Shop.price(str(it.id))
		cp._text(tag, row.position + Vector2(w - cp._tw(tag) - 3.0, 1), GOOD if mine else INK)
	var d := Rect2(body.position + Vector2(0, body.size.y - detail_h), Vector2(w, detail_h))
	cp._fill(d, Color("e8d9c0"))
	var it := selected()
	var lines: Array = cp._wrap(str(it.what), int((w - 52.0) / 4.0))
	for j in mini(lines.size(), 3):
		cp._text(str(lines[j]), d.position + Vector2(3, 2 + j * 7), INK)
	var why := Shop.why_not(str(it.id))
	var label := "BUY"
	if Shop.owns(str(it.id)):
		label = "OWNED"
	elif Shop.in_slot(str(it.slot)) != "":
		label = "SWAP"
	cp._button("shop:buy", Rect2(d.end.x - 44.0, d.position.y + 2.0, 42, 9), label, why == "")
	if why != "" and not Shop.owns(str(it.id)):
		cp._text(cp._clip(why, int((w - 6.0) / 4.0)), d.position + Vector2(3, d.size.y - 8.0), BAD)


static func move(cp, step: int) -> void:
	Shop.sel = clampi(Shop.sel + step, 0, Shop.CATALOG.size() - 1)
	cp._canvas.queue_redraw()


static func enter(cp) -> void:
	action(cp, ["shop", "buy"])


static func action(cp, parts: PackedStringArray) -> void:
	match parts[1]:
		"sel":
			Shop.sel = clampi(int(parts[2]), 0, Shop.CATALOG.size() - 1)
		"buy":
			var res := Shop.buy(str(selected().id))
			cp._say(str(res.msg))
	cp._canvas.queue_redraw()
