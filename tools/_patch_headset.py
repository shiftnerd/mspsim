# one-off patch: wireless headset instead of a handset to the ear (applied once, then deleted)
B = 'D:/creative/pixelproject/tools/'


def load(n):
    return open(B + n, encoding='utf-8').read()


def save(n, s):
    open(B + n, 'w', encoding='utf-8').write(s)


# ---- anim.lua: also report where the ear is ----------------------------------------------------
s = load('anim.lua')
assert "  return out, hand\n" in s
s = s.replace("  return out, hand\n", "  local ear = {round(an.headCx + OX + headDx - 6.5 * f), 13 + OY + headDy}\n  return out, hand, ear\n", 1)
s = s.replace("    local imgs, hand = E.render(an, pose, f)\n    hands[fi] = hand or {32, 50}",
              "    local imgs, hand, ear = E.render(an, pose, f)\n    hands[fi] = {(hand or {32, 50})[1], (hand or {32, 50})[2], (ear or {32, 31})[1], (ear or {32, 31})[2]}")
save('anim.lua', s)
s = load('build_anims.lua')
s = s.replace('for i, h in ipairs(hands) do parts[i] = string.format("[%d,%d]", h[1], h[2]) end',
              'for i, h in ipairs(hands) do parts[i] = string.format("[%d,%d,%d,%d]", h[1], h[2], h[3], h[4]) end')
save('build_anims.lua', s)

# ---- make_godot.py -------------------------------------------------------------------------------
p = B + 'make_godot.py'
s = open(p, encoding='utf-8').read()


def rep(old, new, count=1):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, count)


# held_item: hand or ear mode, headset drawing, no handset item
rep('var item := ""\n\nvar _hands := {}', 'var item := ""\nvar mode := "hand"  # "hand" follows the near hand, "ear" follows the ear (headset)\n\nvar _hands := {}')
rep('    position = Vector2(float(table[idx][0]) - 32.0, float(table[idx][1]) - 80.0)',
    '    var k := 2 if mode == "ear" else 0\n    position = Vector2(float(table[idx][k]) - 32.0, float(table[idx][k + 1]) - 80.0)')
rep('    _tilt = 0.0\n    if parts[0] in ["sip", "sitsip"]:', '    _tilt = 0.0\n    if mode == "hand" and parts[0] in ["sip", "sitsip"]:')
i = s.index('    elif item == "handset":')
j = s.index('    elif item == "soda":', i)
s = s[:i] + s[j:]
rep('func _draw() -> void:\n    draw_set_transform(Vector2.ZERO, deg_to_rad(_tilt) * _side, Vector2.ONE)\n    if item == "coffee":',
    '''func _draw() -> void:
    if mode == "ear":
        _draw_headset()
        return
    draw_set_transform(Vector2.ZERO, deg_to_rad(_tilt) * _side, Vector2.ONE)
    if item == "coffee":''')
rep('var _tilt := 0.0\n', 'var _tilt := 0.0\nvar _t := 0.0\n')
rep('func _process(_delta: float) -> void:\n    visible = item != ""', 'func _process(delta: float) -> void:\n    _t += delta\n    visible = item != ""')
s = s.replace('''    elif item == "water":
        draw_rect(Rect2(-3, -4, 6, 9), INK)''', '''    elif item == "water":
        draw_rect(Rect2(-3, -4, 6, 9), INK)''')
# add _draw_headset to held_item (insert before the first "func _draw() -> void:\n    if mode")
rep('func _draw() -> void:\n    if mode == "ear":', '''# wireless earpiece with a short mic boom (origin = the ear)
func _draw_headset() -> void:
    var s := _side
    var body := Color("2a2a33")
    draw_rect(Rect2(-2, -3, 4, 6), INK)
    draw_rect(Rect2(-1, -2, 2, 4), body)
    draw_rect(Rect2(-1 - 0.5 * s - 0.5, -2, 1, 1), Color("4f7fd0") if int(_t * 2.0) % 2 == 0 else Color("1c2a4a"))
    draw_rect(Rect2(s * 1 - 0.5, 2, 1, 2), INK)                 # the boom curves down and forward to the mouth
    draw_rect(Rect2(s * 2 - 0.5, 4, 1, 2), INK)
    draw_rect(Rect2(s * 3 - 0.5, 6, 1, 2), INK)
    draw_rect(Rect2(s * 4 - 1.0, 7, 3, 2), INK)
    draw_rect(Rect2(s * 4 - 0.5, 7.5, 2, 1), body)


func _draw() -> void:
    if mode == "ear":''')

# fx: handset always on the cradle, call just runs a timer on the LCD
rep('''        _r(9, 5, 2.0 + float(int(t * 2.0) % 4), 1, lcd_ink)
        return
    var jitter := 0.0''', '''        _r(9, 5, 2.0 + float(int(t * 2.0) % 4), 1, lcd_ink)
    var jitter := 0.0''')
rep('"fridge": 3.2, "desk_phone": 9.0\n}', '"fridge": 3.2, "desk_phone": 10.4\n}')
rep('var call_secs := 9.0\n', 'var call_secs := 9.0  # time on the headset (plus 0.7 s to put it on and take it off)\n')

# player: headset call
rep('var _on_call := false\nvar _call_prev := ""\n', 'var _call_stage := ""  # "", "tap_on", "talking", "tap_off"\nvar _call_t := 0.0\nvar _call_len := 0.0\nvar _head_item: Node2D\n')
rep('    _item = preload("res://scripts/held_item.gd").new()\n    _item.item = held\n    add_child(_item)\n',
    '    _item = preload("res://scripts/held_item.gd").new()\n    _item.item = held\n    add_child(_item)\n    _head_item = preload("res://scripts/held_item.gd").new()\n    _head_item.mode = "ear"\n    add_child(_head_item)\n')
rep('    if _on_call:\n        _on_call = false\n        held = _call_prev\n        _item.item = held\n',
    '''    if _call_stage == "tap_on":
        _call_stage = "talking"
        _call_t = _call_len
        _head_item.item = "headset"
    elif _call_stage == "tap_off":
        _call_stage = ""
        _head_item.item = ""
        if _bubble != null:
            _bubble.visible = false
''')
i = s.index('func start_call(secs: float) -> void:')
j = s.index('# the nearest ringing desk phone within reach', i)
s = s[:i] + '''# answer: tap the ear, a wireless headset appears, you talk (and can walk or keep typing), then tap it off
func start_call(secs: float) -> void:
    _call_len = secs
    _call_stage = "tap_on"
    start_emote("sitcall" if state == "sitting" else "call", 0.7)


func _call_tick(delta: float) -> void:
    if _call_stage != "talking":
        return
    _call_t -= delta
    _ensure_bubble()
    _bubble.glyph = "dots"
    _bubble.visible = state != "emote" and int((_call_len - _call_t) / 1.3) % 2 == 1
    if _call_t <= 0.0 and state in ["idle", "walk", "run", "sitting"]:
        _call_stage = "tap_off"
        start_emote("sitcall" if state == "sitting" else "call", 0.7)


func _ensure_bubble() -> void:
    if _bubble == null:
        _bubble = preload("res://scripts/bubble.gd").new()
        _bubble.position = Vector2(0, -64)
        add_child(_bubble)


''' + s[j:]
rep('''    if glyph != "":
        if _bubble == null:
            _bubble = preload("res://scripts/bubble.gd").new()
            _bubble.position = Vector2(0, -64)
            add_child(_bubble)
        _bubble.glyph = glyph''', '''    if glyph != "":
        _ensure_bubble()
        _bubble.glyph = glyph''')
rep('func _physics_process(delta: float) -> void:\n    var locked: bool = Game.busy', 'func _physics_process(delta: float) -> void:\n    _call_tick(delta)\n    var locked: bool = Game.busy')
open(p, 'w', encoding='utf-8').write(s)
print("patched")
