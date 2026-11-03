extends SceneTree
# The network model without any room: cables, power, boot times and the UPS battery.

var failures := 0
var net: Node


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = got == want
	if not ok:
		failures += 1
	print(
		(
			"%s %s: %s%s"
			% ["ok  " if ok else "FAIL", label, str(got), "" if ok else "  (wanted %s)" % str(want)]
		)
	)


func _run(secs: float) -> void:
	for i in int(secs * 10.0):
		net._process(0.1)


func _process(_delta: float) -> bool:
	net = root.get_node("Net")
	net.reset()
	_check("all desks fine at the start", [net.desk_state(1), net.desk_state(8)], ["ok", "ok"])
	net.pick("up")
	_check("uplink pulled: linked but no internet", net.desk_state(1), "no_internet")
	_check("carrying the uplink", net.carrying, "up")
	_check("a network cable fits a switch port", net.accepts("up", "sw12"), true)
	_check("...but not a PDU outlet", net.accepts("up", "pdu4"), false)
	net.plug("sw12")
	_check("uplink back (any switch port)", net.desk_state(1), "ok")
	net.pick("p3")
	_check("desk 3 patch cable pulled: no link", net.desk_state(3), "no_link")
	_check("other desks unaffected", net.desk_state(2), "ok")
	net.plug("sw11")
	_check("replugged into another port", net.desk_state(3), "ok")
	net.pick("wan")
	_check("WAN cable pulled: internet down", net.desk_state(2), "no_internet")
	_check(
		"the WAN cable only fits the WAN port",
		[net.accepts("wan", "sw1"), net.accepts("wan", "wan")],
		[false, true]
	)
	net.plug("wan")
	net.pick("sw_pwr")
	_check("switch power pulled: everything is dark", net.desk_state(2), "no_link")
	net.plug("pdu5")
	_check("switch power back: still booting", net.desk_state(2), "no_link")
	_run(3.5)
	_check("switch booted", net.desk_state(2), "ok")
	net.pick("rt_pwr")
	_check("router power pulled", net.desk_state(2), "no_internet")
	net.plug("pdu6")
	_run(3.0)
	_check("router booting (6 s)", net.desk_state(2), "no_internet")
	_run(4.0)
	_check("router up", net.desk_state(2), "ok")
	net.pick("ups_in")
	_check("UPS unplugged from the wall: runs on battery", net.desk_state(2), "ok")
	_run(45.0)
	_check("battery about half after 45 s", snappedf(net.battery, 0.1), 0.5)
	_check("...and the desks still work", net.desk_state(2), "ok")
	_run(50.0)
	_check("battery flat: everything off", [net.battery, net.desk_state(2)], [0.0, "no_link"])
	net.plug("wall")
	_check("wall power back: UPS feeds the rack again", net.power().pdu, true)
	_run(8.0)
	_check("rack rebooted", net.desk_state(2), "ok")
	net.press("ups_btn")
	_check("UPS switched off", net.desk_state(2), "no_link")
	net.press("ups_btn")
	_run(8.0)
	_check("UPS back on", net.desk_state(2), "ok")
	net.press("nas_btn")
	_check("NAS switched off (nobody notices at the desks)", net.desk_state(2), "ok")
	net.reset()
	print("DONE failures=%d" % failures)
	quit()
	return false
