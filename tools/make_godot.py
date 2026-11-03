"""Generates the Godot project text files (project settings, SpriteFrames, scenes, scripts).
Run:  python -I tools/make_godot.py        (from D:/creative/pixelproject)
The PNGs in godot/assets/ come from Aseprite: character sheets via export_spritesheet, sets/props via
tools/build_sets.lua."""
import json
import math
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot"))
VIEW_W, VIEW_H, FLOOR_Y = 368, 128, 118
MIN_W = 320      # rooms narrower than this get an off-stage margin on each side in the background art
SET_TOP = 100   # ceiling band above the old 128px art: backgrounds are 100 + 128 + 92 tall and sit at y = -100
FW, FH = 64, 80

CHARACTERS = ["office_teen", "office_adult", "office_dan", "office_alan", "site_alan", "casual_garrison", "sales_vic"]
# background crowd (recolours of site Alan: attendees and vendors at Rodent Nation); they are never playable
EXTRA_CHARACTERS = ["expo_vendg", "expo_vendp", "expo_vendo", "expo_atta", "expo_attb", "expo_attc",
                    # women (tools/make_fem.lua): the manager, the bookkeeper, a Tier 1 tech, client staff, vendors and attendees
                    "office_maya", "office_morgan", "office_marge", "client_karen", "client_mina", "client_brandt",
                    "client_hygienist", "client_paralegal", "expo_dee", "expo_priya", "expo_tina",
                    "client_dentrec_a", "client_dentasst", "client_dentrec_b", "client_denthyg_b", "client_dentdoc_b", "client_vetrec_a",
                    "client_vettech_a", "client_vetrec_b", "client_vettech_b", "client_vetdoc_b", "client_paralegal_b", "client_agent_a",
                    "client_agent_b", "client_designer_b", "client_designer_a", "client_attorney_b", "client_foreman_a",
                    "expo_attd", "expo_atte", "expo_attf", "expo_vendh", "expo_vendi", "expo_vendj"]

# frame durations (ms), 42 frames, matching tools/poses.lua
DURS = ([500, 320, 120, 320] + [90] * 8 + [70] * 6 + [140, 80, 130, 100] + [90, 90, 110] + [80, 120, 110]
        + [80, 100, 80, 80, 80, 90, 600] + [110, 120] + [600, 500] + [150, 150, 150]
        + [90, 330, 90] + [140] * 4 + [180] * 4
        + [500, 320] + [90] * 8 + [130, 450, 130] + [150, 450, 150]
        + [450, 450] + [450, 450]
        + [200, 160, 200, 240, 240, 240, 200, 200, 240, 200, 200, 160])
NFRAMES = len(DURS)
assert NFRAMES == 85
# animation name -> (first frame, last frame, 1-based, loop)
ANIMS = {
    "idle": (1, 4, True), "walk": (5, 12, True), "run": (13, 18, True),
    "crouch": (19, 19, False), "jump": (20, 22, False), "land": (23, 25, False),
    "hurt": (26, 28, False), "death": (29, 35, False),
    "reach": (43, 45, False), "wave": (46, 49, True), "talk": (50, 53, True),
    "hold": (54, 55, True), "walkhold": (56, 63, True), "sip": (64, 66, False), "sitsip": (67, 69, False), "call": (70, 71, True), "sitcall": (72, 73, True), "dance": (74, 85, True),
    "sitdown": (36, 37, False), "sit": (38, 39, True), "type": (40, 42, True),
}

# Sets. All x values are in set pixels (0 = left edge of the set art); the generator centres each set in the
# 368-wide viewport. Seats are (x, feet_y, typing). Doors are (name, centre_x, target_scene, target_spawn, remember).
SETS = {
    "main_floor": dict(node="MainFloor", W=368,
        spawns={"start": (60, "right"), "from_office1": (181, "right"), "from_office2": (229, "right"),
                "from_kitchen": (28, "right"), "from_conf": (336, "left"), "from_cubicles": (336, "left"),
                "from_outside": (45, "right")},
        doors=[("Office1", 181, "office_one", "from_main", ""),
               ("Office2", 229, "office_two", "from_main", ""),
               ("FrontDoor", 43, "", "", "", True)],     # locked: the glass door at the end of the hallway
        exits=[("ToKitchen", "left", "kitchenette", "from_main"), ("ToCubicles", "right", "cubicle_area", "from_main")],
        seats=[(78, 101, True), (213, 101, True), (297, 101, True)]),
    "office_one": dict(node="OfficeOne", W=176,
        spawns={"start": (60, "right"), "from_main": (62, "right")},
        doors=[("ToMain", 21, "main_floor", "from_office1", "")],
        exits=[], seats=[(80, 101, True), (53, 101, False, True)]),
    "office_two": dict(node="OfficeTwo", W=176,
        spawns={"start": (60, "right"), "from_main": (62, "right")},
        doors=[("ToMain", 21, "main_floor", "from_office2", "")],
        exits=[], seats=[(100, 101, True), (55, 101, False, True), (69, 101, False, True)]),
    "conference": dict(node="Conference", W=320,
        spawns={"start": (60, "right"), "from_main": (262, "left"), "from_cubicles": (28, "right")},
        doors=[("ToMain", 299, "main_floor", "from_conf", "")],
        exits=[("ToCubicles", "left", "cubicle_area", "from_conf")],
        seats=[(65, 89, False), (97, 89, False), (129, 89, False), (161, 89, False), (193, 89, False),
               (225, 89, False)]),
    "kitchenette": dict(node="Kitchenette", W=176,
        spawns={"start": (60, "right"), "from_main": (140, "left"), "from_bath_left": (60, "right"),
                "from_bath_right": (120, "left")},
        doors=[("BathLeft", 21, "bathroom", "from_door", "bath_return=from_bath_left"),
               ("BathRight", 153, "bathroom", "from_door", "bath_return=from_bath_right")],
        exits=[("ToMain", "right", "main_floor", "from_kitchen")], seats=[]),
    "cubicle_area": dict(node="CubicleArea", W=320,
        spawns={"start": (80, "right"), "from_main": (28, "right"), "from_conf": (270, "left"),
                "from_closet": (299, "left")},
        doors=[("Closet", 299, "network_closet", "from_cubicles", "")],
        exits=[("ToMain", "left", "main_floor", "from_cubicles"), ("ToConference", "right", "conference", "from_cubicles")],
        seats=[(35, 101, True), (119, 101, True)]),
    "network_closet": dict(node="NetworkCloset", W=144,
        spawns={"start": (70, "right"), "from_cubicles": (60, "right")},
        doors=[("ToCubicles", 21, "cubicle_area", "from_closet", "")],
        exits=[], seats=[]),
    "bowling_alley": dict(node="BowlingAlley", W=320,
        spawns={"start": (60, "right"), "from_outing": (40, "right")},
        doors=[], exits=[("ToMain", "left", "main_floor", "from_outside")],
        seats=[(246, 101, False, True), (266, 101, False, True)]),
    "karaoke_bar": dict(node="KaraokeBar", W=320,
        spawns={"start": (60, "right"), "from_outing": (40, "right")},
        doors=[], exits=[("ToMain", "left", "main_floor", "from_outside")],
        seats=[(121, 89, False), (141, 89, False), (173, 89, False), (28, 101, False, True), (50, 101, False, True),
               (72, 101, False, True)]),
    "restaurant": dict(node="Restaurant", W=320,
        spawns={"start": (60, "right"), "from_outing": (40, "right")},
        doors=[], exits=[("ToMain", "left", "main_floor", "from_outside")],
        seats=[(26, 89, False), (46, 89, False), (98, 89, False), (118, 89, False),
               (212, 101, False, True), (240, 101, False, True), (268, 101, False, True), (296, 101, False, True)]),
    "escape_room": dict(node="EscapeRoom", W=320,
        spawns={"start": (60, "right"), "from_outing": (40, "right")},
        doors=[], exits=[("ToMain", "left", "main_floor", "from_outside")], seats=[]),
    "resort_lobby": dict(node="ResortLobby", W=320,
        spawns={"start": (150, "right"), "from_taxi": (150, "right"), "from_hall": (290, "left"),
                "from_ballroom": (50, "right"), "from_expo": (263, "right")},
        doors=[("Ballroom", 37, "ballroom", "from_lobby", ""), ("ToHall", 301, "resort_hall", "from_lobby", ""),
               ("Expo", 263, "vendor_hall", "from_hall", "")],
        exits=[], seats=[(51, 101, False, True), (65, 101, False, True)]),
    "resort_hall": dict(node="ResortHall", W=320,
        spawns={"start": (150, "right"), "from_lobby": (34, "right"), "from_a": (49, "right"),
                "from_b": (119, "right"), "from_c": (189, "right"), "from_d": (259, "right")},
        doors=[("ToLobby", 17, "resort_lobby", "from_hall", ""),
               ("RoomA", 49, "breakout_room", "from_hall", "conf_door=from_a"),
               ("RoomB", 119, "breakout_room", "from_hall", "conf_door=from_b"),
               ("RoomC", 189, "breakout_room", "from_hall", "conf_door=from_c"),
               ("RoomD", 259, "breakout_room", "from_hall", "conf_door=from_d")],
        exits=[], seats=[]),
    "ballroom": dict(node="Ballroom", W=320,
        spawns={"start": (150, "right"), "from_lobby": (270, "left")},
        doors=[("ToLobby", 305, "resort_lobby", "from_ballroom", "")],
        exits=[], seats=[(77, 95, False), (117, 95, False), (157, 95, False), (197, 95, False)]),
    "breakout_room": dict(node="BreakoutRoom", W=240,
        spawns={"start": (80, "right"), "from_hall": (40, "right")},
        doors=[("ToHall", 17, "resort_hall", "@conf_door", "")],
        exits=[], seats=[(79, 99, False), (119, 99, False), (159, 99, False)]),
    "vendor_hall": dict(node="VendorHall", W=320,
        spawns={"start": (150, "right"), "from_hall": (290, "left"), "from_booth": (150, "right")},
        doors=[("ToLobby", 303, "resort_lobby", "from_expo", "")],
        exits=[], seats=[]),
    "bathroom": dict(node="Bathroom", W=128,
        spawns={"start": (60, "right"), "from_door": (60, "right")},
        doors=[("ToKitchenette", 21, "kitchenette", "@bath_return", "")], exits=[], seats=[]),
}


# ---- client sites (Onsite): site_<type>_<skin>, six business types, each in two skins (a = the client, b = a prospect)
# every site is several rooms: the main office, the IT closet (rack and server), an owner / VIP office, and exam rooms (dental, vet)
SITE_TYPES = {"dental": "Dental", "law": "Law", "vet": "Vet", "arch": "Arch", "realty": "Realty", "trailer": "Trailer"}
SITE_EXAMS = {"dental": [225, 263], "vet": [225, 263]}   # door centres of the exam rooms in the main office
SITE_MAIN = {      # what you can work on in the main office: (kind, art_x, art_y, interact_x)
    "dental": [("pc", 156, 56, 168)],
    "law": [("pc", 232, 56, 244), ("printer", 150, 82, 163)],
    "vet": [("pc", 132, 56, 144)],
    "arch": [("pc", 246, 62, 256), ("printer", 186, 72, 208)],
    "realty": [("pc", 141, 62, 152), ("printer", 258, 80, 271)],
    "trailer": [("pc", 124, 62, 136), ("printer", 214, 80, 227)],
}
for _t, _label in SITE_TYPES.items():
    for _s in ("a", "b"):
        _main = "site_%s_%s" % (_t, _s)
        _doors = [("Closet", 301, "site_%s_closet_%s" % (_t, _s), "from_office", ""),
                  ("Owner", 61, "site_%s_office_%s" % (_t, _s), "from_office", "")]
        _spawns = {"start": (150, "right"), "from_van": (60, "right"), "from_closet": (301, "left"), "from_owner": (61, "right")}
        for _n, _cx in enumerate(SITE_EXAMS.get(_t, []), 1):
            _doors.append(("Exam%d" % _n, _cx, "site_%s_exam_%s" % (_t, _s), "from_office", "exam_return=from_exam%d" % _n))
            _spawns["from_exam%d" % _n] = (_cx, "right")
        SETS[_main] = dict(node="Site%s%s" % (_label, _s.upper()), W=320, spawns=_spawns, doors=_doors, exits=[], seats=[])
        SETS["site_%s_closet_%s" % (_t, _s)] = dict(node="Site%sCloset%s" % (_label, _s.upper()), W=176,
            spawns={"start": (90, "right"), "from_office": (50, "right")},
            doors=[("ToOffice", 21, _main, "from_closet", "")], exits=[], seats=[])
        SETS["site_%s_office_%s" % (_t, _s)] = dict(node="Site%sOwner%s" % (_label, _s.upper()), W=240,
            spawns={"start": (90, "right"), "from_office": (50, "right")},
            doors=[("ToOffice", 21, _main, "from_owner", "")], exits=[], seats=[])
        if _t in SITE_EXAMS:
            SETS["site_%s_exam_%s" % (_t, _s)] = dict(node="Site%sExam%s" % (_label, _s.upper()), W=240,
                spawns={"start": (90, "right"), "from_office": (50, "right")},
                doors=[("ToOffice", 21, _main, "@exam_return", "")], exits=[], seats=[])

# Story tables are `const` in the scripts (read-only in GDScript). The scripts listed here get the table renamed to
# DEFAULT_<NAME> and a mutable copy `var <NAME> = DEFAULT_<NAME>.duplicate(true)` right after it, so that the
# Strings autoload can replace text from story/strings.txt. Nothing else in the code changes.
PATCHABLE = {
    "scripts/story.gd": ["DAYS", "VIGNETTES"], "scripts/playbook.gd": ["BOOKS", "PROBLEMS"], "scripts/owner.gd": ["CARDS"],
    "scripts/msp.gd": ["PROBLEMS", "RANSOM", "ADOBE", "INSTALL"],
    "scripts/talk.gd": ["GREETINGS", "SMALL", "GOSSIP", "TIPS_GENERIC", "OWNER_HOLD"],
    "scripts/nerds.gd": ["JOKES", "THREADS"], "scripts/lync.gd": ["MESSAGES"],
    "scripts/review.gd": ["QUOTES", "OWNER_QUOTES", "EPILOGUES"], "scripts/social.gd": ["THANKS"],
    "scripts/shift.gd": ["WEEK_TRAFFIC", "REASONS", "PAGES"], "scripts/hints.gd": ["DAY1"], "scripts/career.gd": ["MEDALS", "UNLOCKS"],
    "scripts/growth.gd": ["STRETCH"], "scripts/conference.gd": ["TEXT", "ROUNDS", "VENDORS", "CHATS"], "scripts/printer_game.gd": ["TEXT", "QUESTIONS", "MODEL_TEXT"], "scripts/onsite.gd": ["TEXT", "JOBS", "MORE_JOBS", "EVENTS", "STAFF", "SITE_APPS", "PETS", "FINDINGS", "MEETINGS"],
}


# Functions whose story strings are replaced by Strings.t("Inline.<Script>.<function>.<n>", "<the text>") so the text
# can be edited in story/strings.txt (the default stays in the code).
INLINE = {}  # (an experiment: moving the strings inside the game logic out of the code; not used)
def _literals(line):
    """(start, end, body) of every double-quoted string literal on a source line (end is exclusive)"""
    found = []
    i = 0
    while i < len(line):
        c = line[i]
        if c == "#":
            break
        if c == '"':
            j = i + 1
            while j < len(line) and line[j] != '"':
                j += 2 if line[j] == "\\" else 1
            if j >= len(line):
                break
            found.append((i, j + 1, line[i + 1:j]))
            i = j
        i += 1
    return found


def externalize(text, script, funcs):
    lines = text.split("\n")
    out = []
    current = None
    count = 0
    for line in lines:
        if line.startswith("func "):
            name = line[5:].split("(")[0]
            current = name if name in funcs else None
            count = 0
        elif line and not line.startswith((" ", "	")) and current:
            current = None
        if current and not line.lstrip().startswith("#"):
            pieces = []
            last = 0
            for start, end, body in _literals(line):
                before = line[:start].rstrip()
                skip = (
                    len(body) < 10 or " " not in body or "\\" in body or before.endswith(("Strings.t(", "preload(", "load("))
                    or body.startswith(("res://", "user://"))
                )
                pieces.append(line[last:start])
                if skip:
                    pieces.append(line[start:end])
                else:
                    count += 1
                    pieces.append('Strings.t("Inline.%s.%s.%d", "%s")' % (script, current, count, body))
                last = end
            pieces.append(line[last:])
            line = "".join(pieces)
            # an autoload's return type is not known while the scripts are parsed: give the variable its type
            line = re.sub(r"^(\s*)var (\w+) := (\(?Strings\.t\()", r"\1var \2: String = \3", line)
        out.append(line)
    return "\n".join(out)


def _depth(line):
    """net bracket depth of a source line, ignoring strings and comments"""
    d = 0
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "#":
            break
        elif c in "[{(":
            d += 1
        elif c in "]})":
            d -= 1
        i += 1
    return d


def make_patchable(text, names):
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        hit = None
        for name in names:
            if line.startswith("const %s := " % name):
                hit = name
        if hit:
            kind = "Dictionary" if line.split(":= ", 1)[1].lstrip().startswith("{") else "Array"
            block = [line.replace("const %s := " % hit, "const DEFAULT_%s := " % hit, 1)]
            depth = _depth(line)
            while depth > 0:
                i += 1
                block.append(lines[i])
                depth += _depth(lines[i])
            out.extend(block)
            out.append("var %s: %s = DEFAULT_%s.duplicate(true)" % (hit, kind, hit))
        else:
            out.append(line)
        i += 1
    result = "\n".join(out)
    # the mutable copies are upper case variables declared next to their constants
    first, rest = result.split("\n", 1)
    return first + "\n# gdlint:disable=class-definitions-order,class-variable-name\n" + rest


def write(rel, text):
    if rel in INLINE:
        text = externalize(text, os.path.basename(rel)[:-3].capitalize(), INLINE[rel])
    if rel in PATCHABLE:
        text = make_patchable(text, PATCHABLE[rel])
    path = os.path.normpath(os.path.join(ROOT, rel))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\n") as f:
        f.write(text)
    print("wrote", rel)


# ---- project.godot -----------------------------------------------------------
write("project.godot", f"""; Engine configuration file (generated by tools/make_godot.py)
config_version=5

[application]

config/name="MSPSim"
run/main_scene="res://scenes/title.tscn"
config/features=PackedStringArray("4.4", "GL Compatibility")

[autoload]

Game="*res://scripts/game.gd"
World="*res://scripts/world.gd"
Net="*res://scripts/net.gd"
Msp="*res://scripts/msp.gd"
Computer="*res://scripts/computer.gd"
Phone="*res://scripts/phone.gd"
Campaign="*res://scripts/campaign.gd"
DayReport="*res://scripts/day_report.gd"
Skills="*res://scripts/skills.gd"
Story="*res://scripts/story.gd"
Social="*res://scripts/social.gd"
Playbook="*res://scripts/playbook.gd"
Review="*res://scripts/review.gd"
Cards="*res://scripts/cards.gd"
Sales="*res://scripts/sales.gd"
Owner="*res://scripts/owner.gd"
Lync="*res://scripts/lync.gd"
Nerds="*res://scripts/nerds.gd"
Shift="*res://scripts/shift.gd"
Growth="*res://scripts/growth.gd"
Difficulty="*res://scripts/difficulty.gd"
Outings="*res://scripts/outings.gd"
Hints="*res://scripts/hints.gd"
Talk="*res://scripts/talk.gd"
Meeting="*res://scripts/meeting.gd"
Nerf="*res://scripts/nerf.gd"
Projects="*res://scripts/projects.gd"
Expo="*res://scripts/conference.gd"
Onsite="*res://scripts/onsite.gd"
PrinterGame="*res://scripts/printer_game.gd"
Career="*res://scripts/career.gd"
Strings="*res://scripts/strings.gd"

[display]

window/size/viewport_width={VIEW_W}
window/size/viewport_height={VIEW_H}
window/size/window_width_override={VIEW_W * 4}
window/size/window_height_override={VIEW_H * 4}
window/stretch/mode="viewport"
window/stretch/scale_mode="integer"

[rendering]

textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.09, 0.07, 0.12, 1)
""")

# ---- SpriteFrames per character ----------------------------------------------
for ch in CHARACTERS + EXTRA_CHARACTERS:
    ext, subs, anims = [], [], []
    for sid, side in (("1", "right"), ("2", "left")):
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/characters/{ch}_{side}.png" id="{sid}"]')
    for side, sid in (("right", "1"), ("left", "2")):
        for f in range(NFRAMES):
            subs.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_{side[0]}{f + 1}"]\n'
                        f'atlas = ExtResource("{sid}")\nregion = Rect2({f * FW}, 0, {FW}, {FH})')
    for side in ("right", "left"):
        for name, (a, b, loop) in ANIMS.items():
            frames = ", ".join(
                '{\n"duration": %.2f,\n"texture": SubResource("AtlasTexture_%s%d")\n}' % (DURS[f - 1] / 100.0, side[0], f)
                for f in range(a, b + 1))
            anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": 10.0\n}'
                         % (frames, "true" if loop else "false", name, side))
    text = f'[gd_resource type="SpriteFrames" load_steps={len(ext) + len(subs) + 1} format=3]\n\n'
    text += "\n".join(ext) + "\n\n" + "\n\n".join(subs) + "\n\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"
    write(f"characters/{ch}.tres", text)

# ---- scripts -----------------------------------------------------------------
write("scripts/game.gd", '''extends Node
# Autoload: scene changes with a fade, the output format, and values that survive scene changes.
#   Format: Godot --path godot -- --format=h     (wide | h | v | vclose, or env PIXEL_FORMAT)
#   Video:  Godot --path godot --resolution 1920x1080 --fixed-fps 60 --write-movie out.avi
#           -- --format=h
# F9 cycles the format while playing.

signal format_changed

# size = logical pixels; zoom = camera zoom; cam_y = world y the camera centres on;
# scale = default window pixel scale without --resolution (6x of h = 1920x1080, 6x of v = 1080x1920)
const FORMATS := {
	"wide": {"size": Vector2i(368, 128), "zoom": 1.0, "cam_y": 64.0, "scale": 4, "follow": false},
	"h": {"size": Vector2i(320, 180), "zoom": 1.0, "cam_y": 50.0, "scale": 4, "follow": true},
	"v": {"size": Vector2i(180, 320), "zoom": 1.0, "cam_y": 60.0, "scale": 3, "follow": true},
	"vclose": {"size": Vector2i(180, 320), "zoom": 2.0, "cam_y": 92.0, "scale": 3, "follow": true},
}
const ORDER := ["wide", "h", "v", "vclose"]

const UI_STRIP := 0.2  # share of the screen height left visible above a computer / phone UI

var vars := {}  # e.g. office_return = "from_office1"
var pending_spawn := "start"
var pending_x := -1.0  # one-shot x override for the next spawn (-1 = use the spawn point)
var busy := false
var format := "wide"
var title_mode := false  # the title screen shows real rooms without the player or the cast
var ui_open := false  # a computer / phone UI is open: the player is paused
var ui_shift := 0.0  # 0..1: the stage camera slides so the player shows in the faded strip

var _fade: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var wanted := OS.get_environment("PIXEL_FORMAT")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--format="):
			wanted = arg.substr(9)
	set_format(wanted if FORMATS.has(wanted) else "wide")


func set_format(name: String) -> void:
	format = name
	var f: Dictionary = FORMATS[name]
	var size: Vector2i = f.size
	var win := get_window()
	win.content_scale_size = size
	if not "--resolution" in OS.get_cmdline_args() and DisplayServer.get_name() != "headless":
		win.size = size * int(f.scale)
	format_changed.emit()


func cycle_format() -> void:
	set_format(ORDER[(ORDER.find(format) + 1) % ORDER.size()])


func go_title() -> void:
	busy = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func go(scene: String, spawn: String) -> void:
	if busy:
		return
	busy = true
	if spawn.begins_with("@"):
		spawn = str(vars.get(spawn.substr(1), "start"))
	var here := get_tree().current_scene
	if here != null and is_instance_valid(World):
		World.player_left(here.scene_file_path.get_file().get_basename(), scene)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.15)
	await t.finished
	pending_spawn = spawn
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.15)
	await t2.finished
	busy = false
''')

write("scripts/prompt_arrow.gd", '''extends Node2D
# Small bobbing arrow shown above something the player can use.

var base_y := 0.0
var _t := 0.0
var _shake_t := 0.0


func _ready() -> void:
    z_as_relative = false
    z_index = 30
    var outline := Polygon2D.new()
    outline.polygon = PackedVector2Array([Vector2(-4, -1), Vector2(4, -1), Vector2(0, 6)])
    outline.color = Color("17121f")
    add_child(outline)
    var fill := Polygon2D.new()
    fill.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, 4)])
    fill.color = Color("ffffff")
    add_child(fill)


func shake() -> void:
    modulate = Color(1.0, 0.3, 0.3)
    _shake_t = 0.35


func _process(delta: float) -> void:
    _t += delta
    position.y = base_y + (1 if int(_t * 4.0) % 2 == 0 else 0)
    if _shake_t > 0.0:
        _shake_t -= delta
        position.x = (1 if int(_shake_t * 30.0) % 2 == 0 else -1) * 2
        if _shake_t <= 0.0:
            position.x = 0
            modulate = Color(0.62, 0.62, 0.68)

''')

write("scripts/door.gd", '''extends Area2D
# A door (press E next to it) or, with auto = true, an edge exit that fires on touch.

@export var target_scene := ""
@export var target_spawn := "start"
@export var remember := ""            # "key=value" stored in Game.vars when used
@export var auto := false
@export var locked := false           # can't be used: the arrow turns red and shakes
@export var special := ""            # "front" = the office front door: choose a client site to drive to
@export var arrow_offset := Vector2(0, -36)

var _arrow: Node2D
var _player: Node = null


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    if not auto:
        _arrow = preload("res://scripts/prompt_arrow.gd").new()
        _arrow.base_y = arrow_offset.y
        _arrow.position = arrow_offset
        _arrow.visible = false
        if locked:
            _arrow.modulate = Color(0.62, 0.62, 0.68)
        add_child(_arrow)


func _on_body_entered(body: Node) -> void:
    if not body.has_method("sit"):
        return
    if auto:
        use(body)
    else:
        _player = body
        body.add_near(self)


func _on_body_exited(body: Node) -> void:
    if auto or not body.has_method("sit"):
        return
    body.remove_near(self)
    _player = null
    _arrow.visible = false


func _process(_delta: float) -> void:
    if _arrow != null:
        _arrow.visible = _player != null and _player.nearest() == self and _player.state != "sitting"


func use(_body: Node) -> void:
    if special == "front":
        Onsite.offer_door()
        return
    if locked:
        _arrow.shake()
        return
    if remember != "":
        var kv := remember.split("=")
        Game.vars[kv[0]] = kv[1]
    Game.go(target_scene, target_spawn)
''')

write("scripts/seat.gd", '''extends Area2D
# A chair. The node sits at the seated character's feet.
# Press E next to it to sit; E / move / jump to stand.

@export var facing := "right"
@export var typing := true
@export var stash := true  # false for lounge seats (armchair, couch): the cup stays in hand
@export var cup_dx := 35.0  # where a cup stands when seated (offset from the seat, desktop y)
@export var cup_y := 84.0
@export var stand_y := 118.0
@export var arrow_offset := Vector2(0, -44)

var occupied := false

var _arrow: Node2D
var _player: Node = null


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _arrow = preload("res://scripts/prompt_arrow.gd").new()
    _arrow.base_y = arrow_offset.y
    _arrow.position = arrow_offset
    _arrow.visible = false
    add_child(_arrow)


func _on_body_entered(body: Node) -> void:
    if body.has_method("sit"):
        _player = body
        body.add_near(self)


func _on_body_exited(body: Node) -> void:
    if body.has_method("sit"):
        body.remove_near(self)
        _player = null
    _arrow.visible = false


func _process(_delta: float) -> void:
    var active: bool = (
        _player != null
        and _player.nearest() == self
        and _player.state != "sitting"
        and not occupied
    )
    _arrow.visible = active


func use(body: Node) -> void:
    if occupied:
        _arrow.shake()
        return
    _arrow.visible = false
    body.sit(self)
''')

write("scripts/fx.gd", '''extends Node2D
# gdlint:disable=class-definitions-order
# Procedural ambient motion and one-shot "use" animations, drawn over the art.
# Coordinates are art-local: (0, 0) is the top-left of the piece/background art this node sits on.

signal finished
signal handed  # the item is ready to hand over (mid-effect for the fridge)

const PixelFont := preload("res://scripts/pixelfont.gd")
const STEP := 1.0 / 12.0
const ITEMS := {"coffee": "coffee", "cooler": "water", "nerf_rack": "nerf"}
const LYRICS := [
    "OH OH FRIDAY AT FIVE", "WE ARE THE TICKET QUEUE", "GOT NO SLA TONIGHT", "TURN IT OFF AND ON AGAIN",
    "SING IT FOR THE HELP DESK", "PASSWORD ONE TWO THREE",
]
const NEON := {
    "neon_bowl": [Vector2(53, 21), Color("e04ecb")], "neon_shoes": [Vector2(44, 16), Color("f2c94c")],
    "neon_karaoke": [Vector2(60, 16), Color("3ee0e0")], "neon_bar": [Vector2(39, 21), Color("e04e4e")],
}
const DURATIONS := {
    "coffee": 7.0, "copier": 3.2, "cooler": 1.8, "sink": 2.6, "toilet": 3.0, "tv": 0.5, "monitor": 0.0, "fridge": 3.2, "desk_phone": 10.4, "switch": 0.35
}
# seconds into the effect when the item is handed over (default: at the end)
const HAND_AT := {"fridge": 1.5}

@export var kind := "monitor"
@export var seed_offset := 0
@export var desk := 0  # desk 1-8 = its patch panel port; the network decides if it works

var busy := false
var item := ""
var style := ""  # "call": the user holds the handset to the ear for the length of the effect
var ringing := false
var call_secs := 9.0  # time on the headset (plus 0.7 s to put it on and take it off)

var _handed := false
var _ring_until := 0.0
var _next_ring := 0.0
var _handset: Texture2D
var _room := ""

var _hit_until := 0.0
var _time := 0.0
var _acc := 0.0
var _scroll := 0.0
var _start := -100.0
var _level := 0.0
var _channel := 0
var _next_channel := 7.0
var _static_until := 0.0
var _player: Node = null


func _ready() -> void:
    item = ITEMS.get(kind, "")
    if str(name) == "TvB":
        seed_offset = 1
    _time = float(seed_offset) * 1.7
    _room = owner.scene_file_path.get_file().get_basename() if owner != null else ""
    if kind == "monitor":
        style = "computer"
    if kind in ["monitor", "tv", "fridge", "lyrics", "keypad", "ledtimer", "redlight", "sports_tv", "bowl_score"] or kind.begins_with("neon"):
        add_to_group("emissive")  # screens and the open fridge keep glowing when the lights are out
    if kind == "bell":
        add_to_group("bells")
    if kind == "desk_phone":
        style = "call"
        _handset = load("res://assets/props/desk_phone_handset.png")
        _next_ring = _time + 14.0 + float(seed_offset % 5) * 8.0
    _next_channel = _time + 7.0
    _start = _time - 100.0


# a foam dart hit this screen: it glitches for a moment
func hit() -> void:
    _hit_until = _time + 1.4


func play() -> void:
    if kind.begins_with("clue_") or kind == "keypad":
        Outings.interact(kind)
        return
    if kind == "bell":
        ring("vic")  # only Vic reaches that high (the player's use is blocked in interact.gd)
        return
    if kind == "rubber_duck":
        _duck_press()
        return
    if kind.begins_with("booth_"):
        Expo.booth(kind.substr(6))
        return
    if kind.begins_with("onsite_"):
        Onsite.interact(kind.substr(7))
        return
    if busy:
        return
    busy = true
    _handed = false
    _start = _time
    if kind == "fridge":
        item = ["soda", "bottle"][randi() % 2]
    if kind == "desk_phone":
        ringing = false
    if kind == "switch":
        World.toggle_lights(_room)
    if kind == "tv":
        _next_channel = _time + 7.0
        _channel = (_channel + 1) % 3
        _static_until = _time + 0.4


func _process(delta: float) -> void:
    _time += delta
    if kind == "rubber_duck":
        _duck_tick(delta)
    if _bell_t > 0.0:
        _bell_t = maxf(0.0, _bell_t - delta)
        queue_redraw()
    if _player == null and get_tree().current_scene != null:
        _player = get_tree().current_scene.get_node_or_null("Actors/Player")
    if busy and not _handed and _time - _start >= float(HAND_AT.get(kind, 99.0)):
        _handed = true
        handed.emit()
    if busy and _time - _start >= float(DURATIONS.get(kind, 1.0)):
        busy = false
        if not _handed:
            _handed = true
            handed.emit()
        if kind == "desk_phone":
            _next_ring = _time + 40.0
        finished.emit()
    if kind == "desk_phone" and not busy:
        if Net.desk_state(desk) != "ok":
            ringing = false
        elif ringing and _time > _ring_until:
            ringing = false
            _next_ring = _time + 35.0 + float(seed_offset % 4) * 6.0
        elif not ringing and _time >= _next_ring:
            ringing = true
            _ring_until = _time + 12.0
    if kind == "monitor":
        _scroll += delta * (3.0 if _typing_nearby() else 0.7)
    if kind == "coffee":
        if busy:
            _level = minf(1.0, (_time - _start) / 5.5)
        else:
            _level = maxf(0.0, _level - delta / 40.0)
    _acc += delta
    if _acc >= STEP:
        _acc = 0.0
        queue_redraw()


func _typing_nearby() -> bool:
    return (
        _player != null
        and _player.state == "sitting"
        and absf(_player.global_position.x - global_position.x) < 40.0
    )


func _draw() -> void:
    match kind:
        "monitor":
            _draw_monitor()
        "tv":
            _draw_tv()
        "rack":
            _draw_rack()
        "switch":
            _draw_switch()
        "desk_phone":
            _draw_phone()
        "fridge":
            _draw_fridge()
        "coffee":
            _draw_coffee()
        "copier":
            _draw_copier()
        "cooler":
            _draw_cooler()
        "sink":
            _draw_sink()
        "toilet":
            _draw_toilet()
        "neon_bowl", "neon_shoes", "neon_karaoke", "neon_bar":
            _draw_neon()
        "sports_tv":
            _draw_sports()
        "bowl_lane":
            _draw_bowl_lane()
        "bowl_score":
            _draw_bowl_score()
        "clue_board":
            _draw_clue_board()
        "clue_clock":
            _draw_clue_clock()
        "clue_painting":
            _draw_clue_painting()
        "lyrics":
            _draw_lyrics()
        "discoball":
            _draw_disco()
        "keypad":
            _draw_keypad()
        "ledtimer":
            _draw_timer()
        "redlight":
            _draw_redlight()
        "lamp":
            _draw_lamp()
        "session_sign":
            _draw_session_sign()
        "bell":
            _draw_bell()
        "rubber_duck":
            _draw_duck()


func _outing_escape() -> Dictionary:
    if Outings.is_open and Outings.game == "escape" and Outings.phase != "intro" and not Outings.g.is_empty():
        return Outings.g
    return {}


func _draw_neon() -> void:
    var info: Array = NEON[kind]
    var size: Vector2 = info[0]
    var col: Color = info[1]
    var pulse := 0.10 + 0.06 * sin(_time * 2.4 + float(seed_offset))
    if _h(int(_time * 9.0)) % 31 == 0:
        _r(0, 0, size.x, size.y, Color(0.05, 0.04, 0.09, 0.55))  # a flicker
        return
    _r(0, 0, size.x, size.y, Color(col, pulse))
    _r(-2, size.y, size.x + 4, 1, Color(col, pulse * 1.6))


func _bowl_game() -> Dictionary:
    if Outings.is_open and Outings.game == "bowling" and Outings.phase == "play" and Outings.g.has("up"):
        return Outings.g
    return {}


func _lane_x(lane: int, y: float) -> float:
    return lerpf(float(Outings.LANE_FAR[lane]), float(Outings.LANE_NEAR[lane]), clampf((y - 28.0) / 55.0, 0.0, 1.0))


func _lane_w(y: float) -> float:
    return lerpf(22.0, 52.0, clampf((y - 28.0) / 55.0, 0.0, 1.0))


func _draw_bowl_lane() -> void:
    var game := _bowl_game()
    for lane in 2:
        var px := float(Outings.LANE_FAR[lane])
        var idx := 0
        for row in 4:
            for k in row + 1:
                var x := px + floorf((float(k) - float(row) * 0.5) * 5.0)
                var y := 36.0 - float(row) * 3.0
                var standing := true
                var falling := false
                if not game.is_empty():
                    standing = bool(game.up[lane][idx])
                    falling = game.fall.has("%d_%d" % [lane, idx])
                if standing:
                    _r(x - 1.0, y, 2, 3, Color("f4f2ea"))
                    _r(x - 1.0, y, 2, 1, Color("e04e4e"))
                elif falling:
                    _r(x - 2.0 + float(idx % 3) - 1.0, y + 1.0, 4, 1, Color("f4f2ea"))
                idx += 1
    if game.is_empty():
        return
    if str(game.stage) == "roll":
        _draw_ball(0, float(game.ball), float(game.marker))
    if str(game.opp) != "" and int(game.opp_phase) == 0:
        _draw_ball(1, float(game.opp_ball), float(game.opp_off))


func _draw_ball(lane: int, t: float, aim: float) -> void:
    var y := lerpf(82.0, 38.0, t)
    var off := clampf((aim - 0.5) * 2.6, -1.3, 1.3)
    var x := _lane_x(lane, y) + off * _lane_w(y) * 0.5
    var r := lerpf(3.0, 1.5, t)
    _r(x - r, y - r, r * 2.0, r * 2.0, Color("2a2a8a") if lane == 0 else Color("8a2a5a"))
    _r(x - r, y - r, 1, 1, Color("ffffff"))


func _draw_bowl_score() -> void:
    _r(0, 0, 60, 14, Color("0a1a12"))
    var game := _bowl_game()
    var green := Color("5fe08a")
    if game.is_empty():
        PixelFont.draw(self, "BOWL!", Vector2(11, 2), green, 2)
        return
    if str(game.stage) == "pause" and str(game.msg) != "" and int(_time * 4.0) % 2 == 0:
        PixelFont.draw(self, str(game.msg).substr(0, 7), Vector2(2, 2), Color("ffe36b"), 2)
        return
    var t: Dictionary = game.totals
    PixelFont.draw(self, "YOU %02d ALN %02d" % [int(t["You"]), int(t["Alan"])], Vector2(2, 1), green, 1)
    PixelFont.draw(self, "GAR %02d DAN %02d" % [int(t["Garrison"]), int(t["Dan"])], Vector2(2, 8), green, 1)


func _escape_game() -> Dictionary:
    if Outings.is_open and Outings.game == "escape" and Outings.phase == "play" and Outings.g.has("eq"):
        return Outings.g
    return {}


func _draw_clue_board() -> void:
    var game := _escape_game()
    var text := "2+2=?"
    if not game.is_empty():
        text = "%d+%d=?" % [int(game.eq[0]), int(game.eq[1])]
    PixelFont.draw(self, text, Vector2(8, 10), Color("e8e8e0"), 2)


func _draw_clue_clock() -> void:
    var game := _escape_game()
    var hour := 10 if game.is_empty() else int(game.code[1])
    var c := Vector2(9, 9)
    var a := float(hour % 12) / 12.0 * TAU - PI * 0.5
    draw_line(c, c + Vector2(cos(a), sin(a)) * 4.0, Color("17121f"), 1.0)
    draw_line(c, c + Vector2(0, -6), Color("17121f"), 1.0)
    _r(c.x - 1.0, c.y - 1.0, 2, 2, Color("c0392b"))


func _draw_clue_painting() -> void:
    var game := _escape_game()
    var digit := "?" if game.is_empty() else str(int(game.code[2]))
    _r(7, 33, 12, 7, Color("c99a3c"))
    _r(7, 33, 12, 1, Color("e8c45a"))
    PixelFont.draw(self, digit, Vector2(12, 34), Color("17121f"), 1)


func _draw_sports() -> void:
    var w := 42.0
    var h := 22.0
    var replay := fmod(_time + float(seed_offset) * 4.0, 11.0) > 9.0
    _r(0, 0, w, h, Color("2a7a3a") if not replay else Color("3a9a4a"))
    for i in 6:
        _r(float(i) * 8.0 + 2.0, 0, 1, h, Color(1, 1, 1, 0.18))
    _r(0, h * 0.5, w, 1, Color(1, 1, 1, 0.18))
    for i in 8:
        var phase := _time * (0.8 + float(i % 3) * 0.35) + float(i) * 1.9 + float(seed_offset) * 2.3
        var px := fposmod(float(i) * 11.0 + sin(phase) * 7.0, w - 2.0)
        var py := 4.0 + float((i * 7) % 15) + cos(phase * 1.3) * 2.0
        _r(px, py, 2, 2, Color("e8e8f4") if i < 4 else Color("e04e4e"))
    var bx := fposmod(_time * 9.0 + float(seed_offset) * 13.0, w - 2.0)
    _r(bx, 8.0 + sin(_time * 3.0) * 4.0, 2, 2, Color("f2f2ea"))
    _r(0, 0, w, 5, Color(0.05, 0.05, 0.1, 0.8))
    PixelFont.draw(self, "3-2 Q4" if seed_offset == 0 else "7-7 2ND", Vector2(2, 0), Color("ffe36b"), 1)
    if replay:
        PixelFont.draw(self, "REPLAY", Vector2(w - 25.0, h - 6.0), Color("ffffff"), 1)


func _draw_lyrics() -> void:
    var w := 88.0
    var h := 34.0
    _r(0, 0, w, h, Color("161a44"))
    for i in 6:
        _r(0, float(i) * 6.0, w, 3.0, Color(0.35, 0.2, 0.55, 0.12))
    var line_secs := 4.5
    var idx := int(_time / line_secs) % LYRICS.size()
    var frac := fmod(_time, line_secs) / line_secs
    var line: String = LYRICS[idx]
    var words := line.split(" ")
    var total := PixelFont.width(line, 1)
    var x := floorf((w - float(total)) * 0.5)
    var y := 15.0
    var shown := frac * float(line.length())
    var pos := 0
    var ball_x := x
    for word in words:
        for ch in word:
            var done := float(pos) < shown
            PixelFont.draw(self, str(ch), Vector2(x, y), Color("ffe36b") if done else Color("e8e8f4"), 1)
            if done:
                ball_x = x
            x += 4.0
            pos += 1
        x += 4.0
        pos += 1
    var next: String = LYRICS[(idx + 1) % LYRICS.size()]
    PixelFont.draw(self, next.substr(0, 21), Vector2(floorf((w - float(PixelFont.width(next.substr(0, 21), 1))) * 0.5), 25.0), Color("7a82b8"), 1)
    PixelFont.draw(self, "TOTALLY LEGAL HIT", Vector2(4, 3), Color("e04ecb"), 1)
    _r(ball_x + 1.0, 9.0 - absf(sin(_time * 7.0)) * 4.0, 3.0, 3.0, Color("ffffff"))


func _draw_disco() -> void:
    for i in 18:
        var spd := 6.0 + float(i % 4) * 3.0
        var x := fposmod(float(i) * 37.0 + _time * spd, 320.0) - 145.0
        var y := 6.0 + float((i * 29) % 80)
        var cols := [Color("e04ecb"), Color("3ee0e0"), Color("f2c94c"), Color("ffffff")]
        _r(x, y, 3, 3, Color(cols[i % 4], 0.22))
    if _h(int(_time * 10.0)) % 3 == 0:
        _r(-3, 18, 2, 2, Color(1, 1, 1, 0.9))
        _r(8, 24, 2, 2, Color(1, 1, 1, 0.9))


func _draw_keypad() -> void:
    var game := _outing_escape()
    var digits := [0, 0, 0]
    if not game.is_empty():
        digits = game.cur
    for i in 3:
        PixelFont.draw(self, str(int(digits[i])), Vector2(4.0 + float(i) * 5.0, 4.0), Color("4cff7a"), 1)
    var solved := Outings.is_open and Outings.game == "escape" and Outings.phase == "result" and Outings.stars > 0
    var lit := solved or (int(_time * 2.0) % 2 == 0 and not game.is_empty())
    _r(18, 12, 2, 2, Color("4cff7a") if solved else (Color("ff3b30") if lit else Color("5a1812")))


func _draw_timer() -> void:
    var game := _outing_escape()
    var left := 120.0
    if not game.is_empty():
        left = maxf(0.0, float(game.time))
    var text := "%02d:%02d" % [int(left) / 60, int(left) % 60]
    var col := Color("ff3b30") if left > 20.0 or int(_time * 3.0) % 2 == 0 else Color("5a1812")
    PixelFont.draw(self, text, Vector2(4.0, 4.0), col, 2)


func _draw_redlight() -> void:
    var a := 0.20 + 0.28 * (0.5 + 0.5 * sin(_time * 4.0))
    _r(-6, -2, 24, 14, Color(1, 0.1, 0.05, a * 0.35))
    _r(2, 1, 8, 6, Color(1, 0.25, 0.2, a))


# the sales bell, hung high on the wall: Vic rings it after a deal, and a foam dart can ring it too
var _bell_t := 0.0
var _bell_msg := ""


func ring(cause := "vic") -> void:
    if _bell_t > 1.2 and cause == "dart":
        return
    _bell_t = 2.6
    _bell_msg = "DING!"
    if cause == "dart":
        Hints.toast("DING! A DART HIT THE SALES BELL.", 2.5)
        if int(Game.vars.get("bell_day", -1)) != World.day:
            Game.vars["bell_day"] = World.day
            Social.change("Vic", 1)
    else:
        Hints.toast("DING DING! " + str(Sales.last_deal), 4.0)


func hit_test(pos: Vector2) -> bool:
    return Rect2(global_position + Vector2(-9, -3), Vector2(18, 20)).has_point(pos)


func _draw_bell() -> void:
    var amp := 0.0
    if _bell_t > 0.0:
        amp = 5.0 * (_bell_t / 2.6)
    var sway := sin(_time * 22.0) * amp
    var brass := Color("d8b84a")
    var hi := Color("f2d878")
    var sh := Color("a8862a")
    var ink := Color("17121f")
    _r(-7, -5, 14, 3, ink)  # the bracket
    _r(-6, -4, 12, 1, sh)
    _r(-1, -2, 2, 3, ink)  # the chain
    var rows := [
        [2, 3], [3, 3], [4, 4], [5, 4], [6, 4], [7, 5], [8, 5], [9, 5], [10, 6], [11, 6], [12, 7], [13, 7]
    ]
    for r in rows:
        var y: float = r[0]
        var half: float = r[1]
        var off := sway * (y / 13.0)
        _r(-half - 1 + off, y, half * 2.0 + 2.0, 1, ink)
        _r(-half + off, y, half * 2.0, 1, brass)
        _r(-half + 1 + off, y, 1.0, 1, hi)
        _r(half - 2 + off, y, 1.0, 1, sh)
    _r(-8 + sway, 14, 16, 1, ink)
    _r(-1 + sway * 1.4, 15, 3, 3, ink)  # the clapper
    _r(0 + sway * 1.4, 15, 1, 2, brass)
    if _bell_t > 0.0:
        for i in 3:
            var k := float(i) * 3.0
            _r(-14 - k, 4 + k * 0.5, 3, 1, Color(1, 0.95, 0.6, minf(1.0, _bell_t)))
            _r(11 + k, 4 + k * 0.5, 3, 1, Color(1, 0.95, 0.6, minf(1.0, _bell_t)))
        if _bell_t > 1.4:
            var w := PixelFont.width(_bell_msg)
            PixelFont.draw(self, _bell_msg, Vector2(-w * 0.5, -14.0), Color("fff2a0"), 1)


# the rubber duck on your monitor: it squeaks, stares blankly or listens
var _duck_t := 0.0
var _duck_msg := ""
var _duck_count := 0
var _duck_base := 0.0


func _duck_press() -> void:
    _duck_count += 1
    Career.add("duck_squeaks")
    _duck_t = 1.6
    var roll := randf()
    if _duck_count % 10 == 0:
        _duck_msg = "!"
        Hints.toast("THE DUCK HAS HEARD ENOUGH FOR TODAY.", 3.0)
    elif roll < 0.55:
        _duck_msg = "SQUEAK!"
    elif roll < 0.85:
        _duck_msg = "..."
        Hints.toast("THE DUCK STARES AT YOU BLANKLY.", 3.0)
    else:
        _duck_msg = "?"
        Hints.toast("YOU EXPLAIN THE PROBLEM TO THE DUCK. IT SAYS NOTHING. IT HELPS ANYWAY.", 4.0)


func _duck_tick(delta: float) -> void:
    var sprite := get_parent()
    if not (sprite is Sprite2D):
        return
    if _duck_base == 0.0:
        _duck_base = sprite.offset.y
    if _duck_t > 0.0:
        _duck_t = maxf(0.0, _duck_t - delta)
        var hop := 0.0
        if _duck_msg == "SQUEAK!" and _duck_t > 1.15:
            hop = absf(sin((1.6 - _duck_t) * 16.0)) * 3.0
        sprite.offset.y = _duck_base - hop
        queue_redraw()
    elif sprite.offset.y != _duck_base:
        sprite.offset.y = _duck_base


func _draw_duck() -> void:
    if _duck_t <= 0.0:
        return
    var w := PixelFont.width(_duck_msg)
    var x := -float(w) * 0.5 + 6.0
    _r(x - 2.0, -11.0, w + 4.0, 9.0, Color(1, 1, 1, 0.92))
    _r(x - 1.0, -12.0, w + 2.0, 1.0, Color(1, 1, 1, 0.92))
    PixelFont.draw(self, _duck_msg, Vector2(x, -9.0), Color("17121f"), 1)


func _draw_session_sign() -> void:
    var lines: Array = Expo.sign_lines(int(str(name).right(1)))
    var y := 0.0
    for line in lines:
        PixelFont.draw(self, str(line), Vector2(2.0, y), Color("14566e"), 1)
        y += 6.0


func _draw_lamp() -> void:
    draw_circle(Vector2(6, 4), 26.0, Color(1.0, 0.85, 0.4, 0.07 + 0.015 * sin(_time * 3.0)))
    draw_circle(Vector2(6, 4), 14.0, Color(1.0, 0.9, 0.5, 0.09))


func _h(n: int) -> int:
    return posmod(n * 1103515245 + 12345 + seed_offset * 7919, 2147483647) >> 8


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
    draw_rect(Rect2(x, y, w, h), c)


func _draw_monitor() -> void:
    if _time < _hit_until:
        for bx in 9:
            for by in 5:
                var v := 0.3 + 0.1 * float(_h(bx + by * 9 + int(_time * 25.0)) % 6)
                _r(3 + bx * 2, 6 + by * 2, 2, 2, Color(v, v, v + 0.04))
        return
    var net := Net.desk_state(desk)
    if net != "ok":
        _draw_monitor_error(net)
        return
    var ink := Color("9fb4c8")
    var step := int(_scroll)
    _r(3, 6, 19, 9, Color("dde8f0"))
    if _h(step / 7) % 3 == 0:
        for j in 5:
            var bh := 1 + _h(j + step / 2) % 7
            _r(4 + j * 3, 14 - bh, 2, bh, Color("7fa6d8") if j % 2 == 0 else ink)
    else:
        var last_len := 0
        for i in 4:
            last_len = 4 + _h(step + i) % 14
            _r(4, 7 + i * 2, last_len, 1, ink)
        if int(_time * 2.0) % 2 == 0:
            _r(5 + last_len, 13, 1, 1, Color("3c4660"))
    if (int(_time) + seed_offset * 3) % 11 == 0 and fmod(_time, 1.0) < 0.15:
        _r(3, 3, 19, 12, Color(1, 1, 1, 0.3))


func _draw_tv() -> void:
    if _time > _next_channel:
        _next_channel = _time + 7.0
        _channel = (_channel + 1) % 3
        _static_until = _time + 0.4
    var sx := 3.0
    var sy := 3.0
    var w := 32.0
    var h := 14.0
    if _time < _static_until:
        for bx in 16:
            for by in 7:
                var v := 0.35 + 0.1 * float(_h(bx + by * 16 + int(_time * 30.0)) % 6)
                _r(sx + bx * 2, sy + by * 2, 2, 2, Color(v, v, v + 0.03))
        return
    match _channel:
        0:
            _tv_sheet(sx, sy, w, h)
        1:
            _tv_bars(sx, sy, w, h)
        _:
            _tv_news(sx, sy, w, h)


func _tv_sheet(sx: float, sy: float, w: float, h: float) -> void:
    var line := Color("c9d4dc")
    _r(sx, sy, w, h, Color("eef3f6"))
    _r(sx, sy, w, 3, Color("7fa6d8"))
    for r in 3:
        if r % 2 == 0:
            _r(sx, sy + 4 + r * 3, w, 2, line)
    _r(sx + 10, sy + 3, 1, h - 3, line)
    _r(sx + 21, sy + 3, 1, h - 3, line)
    var tick := int(_time * 1.5)
    var col := tick % 3
    var row := (tick / 3) % 3
    for c in 3:
        for r in 3:
            var n := 2 + _h(c * 3 + r) % 5
            _r(sx + 2 + c * 11, sy + 4 + r * 3, n, 1, Color("5a6a80"))
    _r(sx + col * 11, sy + 3 + row * 3, 11, 1, Color("2f6fd0"))
    _r(sx + col * 11, sy + 6 + row * 3, 11, 1, Color("2f6fd0"))


func _tv_bars(sx: float, sy: float, w: float, h: float) -> void:
    _r(sx, sy, w, h, Color("eef3f6"))
    var cols := [Color("7fa6d8"), Color("6eb45a"), Color("e6963c")]
    for i in 7:
        var bh := 2.0 + float(_h(i + int(_time * 1.2)) % 9)
        _r(sx + 2 + i * 4, sy + h - 1 - bh, 3, bh, cols[i % 3])
    _r(sx + 1, sy + h - 1, w - 2, 1, Color("3c4660"))


func _tv_news(sx: float, sy: float, w: float, h: float) -> void:
    _r(sx, sy, w, h, Color("34548c"))
    _r(sx + 14, sy + 3, 4, 4, Color("e6b48c"))
    _r(sx + 11, sy + 7, 10, 3, Color("3c3c46"))
    _r(sx + 2, sy + h - 6, 22, 3, Color("eef3f6"))
    _r(sx + 2, sy + h - 6, 5, 3, Color("d23c3c"))
    _r(sx, sy + h - 2, w, 2, Color("1e2846"))
    for i in 6:
        var x := fposmod(float(i * 6) - floorf(_time * 8.0), w)
        _r(sx + x, sy + h - 2, 3, 1, Color("c8d2e6"))
    if int(_time * 2.0) % 2 == 0:
        _r(sx + w - 4, sy + 2, 2, 2, Color("e03c3c"))



# ---- the network rack: live LEDs and cables drawn over the static rack art ----
func _draw_rack() -> void:
    var st := Net.status()
    _rack_leds(Net.layout, st)
    _rack_ups(Net.layout, st)
    _rack_cables()


func _led(pos: Array, color: Color) -> void:
    _r(pos[0], pos[1], 1, 1, color)


func _traffic(cable: String, st: Dictionary) -> bool:
    if cable.begins_with("p") and cable.length() == 2:
        return Net.desk_state(int(cable.substr(1))) == "ok"
    if cable == "up":
        return st.uplink
    return st.nas_ready


func _rack_leds(lay: Dictionary, st: Dictionary) -> void:
    var green := Color("5be07a")
    var amber := Color("ffb23c")
    var dim := Color("1d3a28")
    var blink := int(_time * 5.0) % 2 == 0
    for j in 12:
        var occ := Net.occupant("sw%d" % (j + 1))
        if occ != "" and st.sw:
            _led(lay.leds.sw_link[j], green if (st.sw_ready or blink) else dim)
            var tick: bool = (int(_time * 9.0) + j * 3) % 5 == 0
            if st.sw_ready and tick and _traffic(occ, st):
                _led(lay.leds.sw_act[j], amber)
    var rt: Dictionary = lay.leds.rt
    if st.rt:
        _led(rt.pwr, green if (st.rt_ready or blink) else amber)
        if Net.cables.wan.end == "wan":
            _led(rt.wan, green)
        if Net.cables.up.end.begins_with("sw"):
            _led(rt.lan, green)
        if st.rt_ready:
            _led(rt.net, green if st.internet else (amber if blink else dim))
    if st.nas:
        _led(lay.leds.nas_pwr, green if (st.nas_ready or blink) else amber)
        for b in 4:
            var lit: bool = (int(_time * 7.0) + b * 5) % 4 == 0 if st.nas_ready else blink
            if lit:
                _led(lay.leds.nas_bay[b], amber)
    if st.pdu:
        _led(lay.leds.pdu, green)
        for k in 6:
            if Net.occupant("pdu%d" % (k + 1)) != "":
                var pp: Vector2 = Net.port_pos["pdu%d" % (k + 1)]
                _r(pp.x - 1, pp.y - 3, 1, 1, green)


func _rack_ups(lay: Dictionary, st: Dictionary) -> void:
    var lcd: Array = lay.leds.ups_lcd
    if not Net.ups_on:
        _r(lcd[0] + 1, lcd[1] + 1, lcd[2] - 2, lcd[3] - 2, Color("0c110e"))
        return
    _led(lay.leds.ups_pwr, Color("5be07a"))
    _r(lcd[0] + 1, lcd[1] + 1, lcd[2] - 2, lcd[3] - 2, Color("324d3a"))
    var level := Net.battery
    var bars := int(ceilf(level * 5.0))
    var color := Color("5be07a")
    if level < 0.35:
        color = Color("ffb23c")
    if not st.wall and level < 0.2:
        color = Color("e04646")
    for i in 5:
        _r(lcd[0] + 3 + i * 4, lcd[1] + 3, 3, 6, color if i < bars else Color("1f2c23"))
    if not st.wall and int(_time * 3.0) % 2 == 0:
        _r(lcd[0] + lcd[2] - 5, lcd[1] + 1, 3, 1, Color("ffb23c"))  # running on battery


func _ctrl(id: String, a: Vector2, b: Vector2) -> Vector2:
    var mid := (a + b) * 0.5
    var fixed := {
        "wan": Vector2(mid.x, -12.0), "ups_in": Vector2(mid.x, 98.0), "sw_pwr": Vector2(74.0, mid.y),
        "rt_pwr": Vector2(78.0, mid.y), "nas_pwr": Vector2(82.0, mid.y), "pdu_in": Vector2(86.0, mid.y),
        "up": Vector2(mid.x - 6.0, mid.y - 4.0), "nas": Vector2(mid.x + 14.0, mid.y),
    }
    return fixed.get(id, mid + Vector2(0.0, 7.0))  # patch cables just sag a little


func _cable(a: Vector2, b: Vector2, ctrl: Vector2, color: Color) -> void:
    var steps := int(maxf(a.distance_to(b), 10.0) * 1.3)
    for i in steps + 1:
        var t := float(i) / float(steps)
        var point := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t).round()
        draw_rect(Rect2(point, Vector2.ONE), color)


func _hand() -> Vector2:
    if _player == null:
        return Vector2(40, 90)
    var side := 1.0 if _player.facing == "right" else -1.0
    return to_local(_player.global_position + Vector2(8.0 * side, -34.0))


func _rack_cables() -> void:
    var heads := []
    for id in Net.cables:
        var c: Dictionary = Net.cables[id]
        var far := Net.far_pos(id)
        var color := Net.cable_color(id)
        var near: Vector2
        var ctrl: Vector2
        if c.end != "":
            near = Net.port_pos[c.end]
            ctrl = _ctrl(id, far, near)
            heads.append([near, color])
        else:
            var power: bool = c.kind in ["pwr", "feed", "inlet"]
            near = _hand() if Net.carrying == id else far + Vector2(6.0 if power else -6.0, 14.0)
            ctrl = (far + near) * 0.5 + Vector2(0.0, 8.0)
            heads.append([near, color])
        _cable(far, near, ctrl, color)
        _r(far.x - 1, far.y - 1, 3, 3, color)
    for h in heads:
        var at: Vector2 = h[0]
        _r(at.x - 1, at.y - 2, 3, 4, h[1])
        _r(at.x, at.y - 2, 1, 1, Color(1, 1, 1, 0.55))


func _draw_monitor_error(state: String) -> void:
    _r(3, 6, 19, 9, Color("1e2a44"))
    if state == "no_link":
        for i in 7:
            _r(9 + i, 7 + i, 1, 1, Color("e04646"))
            _r(15 - i, 7 + i, 1, 1, Color("e04646"))
    else:
        for row in 6:
            _r(12 - (row >> 1), 7 + row, 1 + row, 1, Color("f2c230"))
        _r(12, 9, 1, 3, Color("1e2a44"))
        _r(12, 13, 1, 1, Color("1e2a44"))


# a desk (or the copier) that has lost its network: the interaction says no
func offline() -> bool:
    if kind == "desk_phone":
        return Net.desk_state(desk) != "ok"
    if kind == "copier":
        return Net.desk_state(8) != "ok"
    return false


func _draw_switch() -> void:
    _r(-1, -1, 7, 10, Color("17121f"))
    _r(0, 0, 5, 8, Color("efebdd"))
    _r(1, 1, 3, 6, Color("c9c4b2"))
    if World.lights_on(_room):
        _r(2, 1, 1, 3, Color("8e939e"))
        _r(2, 0, 1, 1, Color("9fe870"))
    else:
        _r(2, 4, 1, 3, Color("8e939e"))


func _draw_phone() -> void:
    if not busy and Net.desk_state(desk) != "ok":
        _r(5, 2, 5, 3, Color("4e5a4e"))  # no network: a dead, greyed LCD
        _r(6, 3, 3, 1, Color("2e382e"))
    var lcd_ink := Color("5b7a5e")
    if busy:
        var t := _time - _start
        _r(5, 2, 5, 3, Color("a9c3a4"))                          # on a call: the LCD shows a running timer
        _r(6, 3, 3, 1, lcd_ink)
        _r(6, 4, 1.0 + float(int(t * 2.0) % 3), 1, lcd_ink)
    var jitter := 0.0
    if ringing:
        var on := int(_time * 8.0) % 2 == 0
        _r(5, 2, 5, 3, Color("e9f7de") if on else Color("a9c3a4"))
        _r(11, 8, 1, 1, Color("ff6a6a") if on else Color("7a2a2a"))
        if int(_time * 16.0) % 2 == 0:
            jitter = -1.0
        var wave := Color(1, 1, 1, 0.85)
        var k := float(int(_time * 5.0) % 3)
        _r(-2.0 - k, 3, 1, 3, wave)
        _r(15.0 + k, 3, 1, 3, wave)
        _r(-4.0 - k, 2, 1, 5, Color(1, 1, 1, 0.45))
        _r(17.0 + k, 2, 1, 5, Color(1, 1, 1, 0.45))
    if _handset != null:
        draw_texture(_handset, Vector2(0.0, jitter))


func _draw_fridge() -> void:
    if not busy:
        return
    var t := _time - _start
    var dur := float(DURATIONS["fridge"])
    var p := minf(clampf(t / 0.35, 0.0, 1.0), clampf((dur - t) / 0.35, 0.0, 1.0))
    if p <= 0.0:
        return
    var taken := t >= float(HAND_AT["fridge"])
    var ink := Color("17121f")
    var dw := int(7.0 * p)
    _r(-dw - 2, 23, dw + 1, 38, ink)                           # the lower door, swung open to the left
    _r(-dw - 1, 24, dw, 36, Color("b8bcc4"))
    _r(-dw - 1, 24, 1, 36, Color("9498a2"))
    if dw >= 3:
        _r(-2, 30, 1, 10, Color("6a6f7a"))
    if p < 0.5:
        return
    _r(1, 23, 24, 37, ink)                                     # the opening
    _r(2, 24, 22, 35, Color("f2f4f8"))
    _r(2, 24, 22, 2, Color("fffbe0"))                          # the light
    _r(23, 24, 1, 35, Color("d6d9df"))
    for y in [33, 42, 51]:
        _r(2, y, 22, 1, Color("b8bcc4"))
    if not (taken and item == "bottle"):
        _r(4, 26, 3, 7, Color("5e9fd0")); _r(5, 25, 1, 1, Color("f4f2ea"))
    _r(9, 25, 5, 8, Color("f4f2ea")); _r(9, 25, 5, 2, Color("4f7fd0"))
    _r(17, 28, 4, 5, Color("c9955a"))
    for i in range(3):
        if i == 0 and taken and item == "soda":
            continue
        _r(4 + i * 4, 35, 3, 7, Color("d23c3c")); _r(4 + i * 4, 35, 3, 1, Color("b8bcc4"))
    _r(5, 44, 9, 7, Color("b8864e")); _r(5, 44, 9, 1, Color("8a5e36"))
    _r(16, 46, 3, 5, Color("f4f2ea")); _r(16, 46, 3, 1, Color("e87a9a"))
    _r(3, 53, 20, 6, Color("a9d0e6"))
    _r(-6, 61, 36, 5, Color(1.0, 0.98, 0.85, 0.28))              # light spilling onto the floor
    _r(-3, 66, 30, 4, Color(1.0, 0.98, 0.85, 0.16))


func _draw_coffee() -> void:
    var t := _time - _start
    if busy:
        _r(3, 7, 2, 2, Color("e85050") if int(_time * 3.0) % 2 == 0 else Color("5a1818"))
    if _level > 0.0:
        var ch := _level * 10.0
        _r(15, 14 - ch, 4, ch, Color("5a3620"))
    if busy and t < 5.8:
        var y := fposmod(_time * 24.0, 12.0)
        var stop := 14.0 - _level * 10.0
        if 3.0 + y < stop:
            _r(17, 3.0 + y, 1, 2, Color("5a3620"))
    if _level > 0.12:
        for i in 3:
            var p := fposmod(_time * 0.8 + float(i) * 0.33, 1.0)
            var a := (1.0 - p) * 0.85
            var sx := 15.0 + i * 2.0 + roundf(sin(_time * 3.0 + i))
            _r(sx, 1.0 - p * 6.0, 1, 2, Color(0.93, 0.95, 0.98, a))


func _draw_copier() -> void:
    var t := _time - _start
    if busy:
        var sweep := fposmod(t * 1.25, 1.0)
        var x := 3.0 + (sweep if int(t * 1.25) % 2 == 0 else 1.0 - sweep) * 24.0
        _r(x, 8, 2, 2, Color("d8ffd0"))
        _r(x - 1, 8, 4, 1, Color(0.85, 1.0, 0.8, 0.5))
        var dots := int(clampf(t / 3.0, 0.0, 1.0) * 8.0)
        _r(5, 14, dots, 1, Color("62d070"))
        if t > 1.0:
            var out := clampf((t - 1.0) / 1.6, 0.0, 1.0) * 5.0
            _r(18, 15, 8, out, Color("f4f2ea"))
    elif t < 12.0:
        _r(18, 19, 8, 2, Color("f4f2ea"))


func _draw_cooler() -> void:
    var t := _time - _start
    var amb := fposmod(_time, 9.0)
    if not busy and amb < 1.2:
        _r(5 + (seed_offset % 3), 9.0 - amb * 6.0, 1, 1, Color("e8f2fa"))
    if busy:
        for i in 3:
            var p := fposmod(t * 2.2 + float(i) * 0.37, 1.0)
            _r(4 + i * 2, 9.0 - p * 7.0, 1, 1, Color("e8f2fa"))
        _r(6, 18, 1, 3, Color("8cb4dc"))
        _r(5, 20, 3, 1, Color("c8e0f4"))


func _draw_sink() -> void:
    if busy:
        var t := _time - _start
        _r(8, 3, 1, 4, Color("8cb4dc"))
        var w := 2 + int(fposmod(t * 6.0, 3.0))
        _r(8.0 - w / 2.0, 7, w, 1, Color("8cb4dc"))


func _draw_toilet() -> void:
    var t := _time - _start
    if busy:
        _r(10, 2 if t > 0.25 else 1, 2, 2, Color("9a9ca8"))
        var k := int(t * 8.0)
        if t < 2.2:
            _r(4, 12 + k % 2, 9, 1, Color("8cb4dc"))
            _r(6 + k % 3, 14, 5, 1, Color("b4d4ec"))
''')

write("scripts/interact.gd", '''extends Area2D
# Press E next to it to play an effect (see fx.gd) on `target`.

@export var target: NodePath
@export var arrow_offset := Vector2(0, -30)
@export var look_x := 0.0  # face this x when using (0 = the zone centre)
@export var group := ""  # optional group name (phone zones are "phones")
@export var low_priority := false  # loses to nearby things (the duck must not steal the monitor)

var _arrow: Node2D
var _player: Node = null


func _ready() -> void:
    if group != "":
        add_to_group(group)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _arrow = preload("res://scripts/prompt_arrow.gd").new()
    _arrow.base_y = arrow_offset.y
    _arrow.position = arrow_offset
    _arrow.visible = false
    add_child(_arrow)


func _on_body_entered(body: Node) -> void:
    if body.has_method("sit"):
        _player = body
        body.add_near(self)


func _on_body_exited(body: Node) -> void:
    if body.has_method("sit"):
        body.remove_near(self)
        _player = null
    _arrow.visible = false


func _process(_delta: float) -> void:
    var fx := get_node(target)
    _arrow.visible = (
        _player != null
        and _player.nearest() == self
        and _player.state != "sitting"
        and not fx.busy
        and fx.kind != "bell"
    )


func _hand_over(body: Node, fx: Node) -> void:
    if is_instance_valid(body) and absf(body.global_position.x - global_position.x) < 60.0:
        body.give(fx.item)


func use(body: Node) -> void:
    var fx := get_node(target)
    if fx.kind == "bell":
        Hints.toast("TOO HIGH TO REACH. MAYBE A FOAM DART?", 2.5)
        return
    if fx.style == "computer":
        Computer.open(fx.desk)
        return
    if fx.busy or fx.offline():
        _arrow.shake()
        return
    if fx.style == "call":
        fx.play()
        Msp.phone_call(fx.desk)
        body.start_call(fx.call_secs)
        return
    body.reach(look_x if look_x != 0.0 else global_position.x)
    fx.play()
    if fx.item != "":
        fx.handed.connect(_hand_over.bind(body, fx), CONNECT_ONE_SHOT)
''')

write("scripts/bubble.gd", '''extends Node2D
# Speech bubble with a small icon (dots, !, ?, heart). The node sits at the bubble's tail tip.

const INK := Color("17121f")
const PATTERNS := {
    "!": ["XX", "XX", "XX", "XX", "  ", "XX"],
    "?": [" XX ", "X  X", "   X", "  X ", " X  ", "    ", " X  "],
    "heart": [" X X ", "XXXXX", " XXX ", "  X  "],
    "note": ["  XX ", "  X X", "  X  ", "  X  ", " XX  ", "XXX  "],
}

var glyph := "dots":
    set(value):
        glyph = value
        queue_redraw()

var _t := 0.0


func _ready() -> void:
    add_to_group("emissive")
    z_as_relative = false
    z_index = 30


func _process(delta: float) -> void:
    _t += delta
    if visible:
        queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(-8, -14, 16, 11), INK)
    draw_rect(Rect2(-7, -13, 14, 9), Color.WHITE)
    draw_rect(Rect2(-2, -4, 5, 1), INK)
    draw_rect(Rect2(-1, -3, 3, 1), INK)
    draw_rect(Rect2(0, -2, 1, 1), INK)
    draw_rect(Rect2(-1, -4, 3, 1), Color.WHITE)
    draw_rect(Rect2(0, -3, 1, 1), Color.WHITE)
    if glyph == "dots":
        var active := int(_t * 5.0) % 3
        for i in 3:
            draw_rect(Rect2(-5 + i * 3, -10 - (1 if i == active else 0), 2, 2), INK)
        return
    var rows: Array = PATTERNS.get(glyph, PATTERNS["!"])
    var color := Color("d23c3c") if glyph == "heart" else INK
    var w: int = String(rows[0]).length()
    var top := -9 - rows.size() / 2
    for y in rows.size():
        for x in w:
            if String(rows[y])[x] == "X":
                draw_rect(Rect2(-w / 2 + x, top + y, 1, 1), color)
''')

write("scripts/npc.gd", '''extends Area2D
# A background character that runs a routine of steps (strings). Cast members (cast_name set,
# see world.gd) run one leg of their agenda and then ask the World for the next; others loop:
#   walk:X (screen x)  wait:S  say:S  talk:S  use:prop  sit:Seat  stand  sip  exit:Name  sync:key:n
#   (sync waits until n characters have reached the same key)
# Waves when the player gets close; press E to chat.

const HELD_ITEM := preload("res://scripts/held_item.gd")
const PLAYER := preload("res://scripts/player.gd")
const SPEED := 32.0
const TALK_GAP := 32.0
const GREET_RANGE := 56.0
const GLYPHS := ["dots", "!", "?", "heart", "dots"]
const CHATTY := ["walk", "wait", "sync", "usewait", "await"]
const DESKS := {"Alan": 6, "Garrison": 7, "Dan": 3, "Vic": 4, "Maya": 2}

@export var character := "office_dan"
@export var facing := "right"
@export var routine: PackedStringArray = []
@export var start_seat := ""
@export var start_item := ""
@export var role := ""  # Rodent Nation crowd: checkin / vendor:<id> / att:<n> (see expo.gd)

var cast_name := ""
var following := false
var state := "wait"
var seat: Node = null
var held := ""
var sips := 0
var ducking := false  # ducking a dart: a lower target (see nerf.gd)

var _duck_t := 0.0
var _step := -1
var _timer := 0.0
var _target_x := 0.0
var _fx: Node = null
var _gen := 0
var _key := ""
var _hold := 0.0
var _hold_len := 0.0
var _inside: Node = null
var _player: Node = null
var _greeted := false
var _bubble: Node2D
var _arrow: Node2D
var _item: Node2D
var _head_item: Node2D
var _desk: Node2D
var _leaving := false
var _chat_slide := INF
var _chat_check := 0.0
var _hold_phase := 0
var _follow_key := ""
var _hidden := false
var _offline := false  # the network at my desk is down
var _net_t := 0.0
var _grumble_t := 0.0
var _call_stage := ""  # "", "tap_on", "talking", "tap_off"
var _call_t := 0.0
var _t := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var _stage: Node = get_parent().get_parent()


func _ready() -> void:
    sprite.sprite_frames = load("res://characters/%s.tres" % character)
    add_to_group("npcs")
    sprite.animation_finished.connect(_on_animation_finished)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    _arrow = preload("res://scripts/prompt_arrow.gd").new()
    _arrow.base_y = -72.0
    _arrow.position = Vector2(0, -72)
    _arrow.visible = false
    add_child(_arrow)
    _bubble = preload("res://scripts/bubble.gd").new()
    _bubble.position = Vector2(0, -64)
    _bubble.visible = false
    add_child(_bubble)
    _item = HELD_ITEM.new()
    add_child(_item)
    _head_item = HELD_ITEM.new()
    _head_item.mode = "ear"
    add_child(_head_item)
    _t = float(get_index())
    held = start_item
    _item.item = held
    if start_seat != "" and _occupy(start_seat, true):
        _stash()
        _play("type" if seat.typing else "sit")
    else:
        _play("idle")
    _next_step()


func use(body: Node) -> void:
    if role != "":
        if seat == null:
            _face(body.global_position.x)
        Expo.npc_use(self, body)
        return
    if _hold > 0.0 or Social.is_hostile(cast_name) or _hidden:
        _arrow.shake()
        return
    if Talk.available(cast_name) and (seat != null or _can_chat()):
        _talk_at_desk(body)
        return
    if not _can_chat():
        _arrow.shake()
        return
    _face(body.global_position.x)
    _begin_hold("talk", 2.6)
    var side := signf(body.global_position.x - global_position.x)
    if side == 0.0:
        side = -1.0
    var target := _clamp_x(global_position.x + side * TALK_GAP)
    if absf(target - global_position.x) < TALK_GAP - 6.0:
        target = _clamp_x(global_position.x - side * TALK_GAP)
    body.slide_to(target)
    body.start_emote("talk", 2.6, global_position.x, Social.glyph(cast_name))
    Social.note_chat(cast_name)


# a seated worker whose network is down stops typing and grumbles now and then
func _update_reactions(delta: float) -> void:
    if _grumble_t > 0.0:
        _grumble_t -= delta
        if _grumble_t <= 0.0 and state == "wait" and _hold <= 0.0:
            _bubble.visible = false
    var down := false
    if cast_name != "" and seat != null and seat.typing:
        down = Net.desk_state(int(DESKS.get(cast_name, 0))) != "ok"
    if down != _offline:
        _offline = down
        _net_t = 2.0
        if state == "wait" and _hold <= 0.0:
            _play(_rest_anim())
    if _offline and state == "wait" and _hold <= 0.0:
        _net_t -= delta
        if _net_t <= 0.0:
            _net_t = 7.0 + randf() * 4.0
            grumble()


# hit by a foam dart: flinch (standing) and show how they feel about it
func react_hit(glyph: String) -> void:
    if _hidden:
        return
    if seat == null and _hold <= 0.0 and state != "walk":
        _begin_hold("hurt", 0.8)
    _bubble.glyph = glyph
    _bubble.visible = true
    _grumble_t = 1.6


func grumble() -> void:
    if _hold > 0.0 or _hidden:
        return
    _bubble.glyph = "!" if randf() < 0.6 else "?"
    _bubble.visible = true
    _grumble_t = 2.2


# somebody turned the lights off on us: get up, walk to the switch, turn them back on, carry on
func react_lights(switch_x: float) -> void:
    if _hold > 0.0 or _hidden or cast_name == "" or following:
        return
    var steps := PackedStringArray(["wait:1"])
    var seat_name := ""
    if seat != null:
        seat_name = str(seat.name)
        steps.append("stand")
    steps.append_array(PackedStringArray(["walk:%d" % int(switch_x), "lights:on"]))
    if seat_name != "":
        steps.append("sit:" + seat_name)
    steps.append_array(routine)
    set_routine(steps)


# campaigns: a real conversation (the Talk autoload), seated at a desk or standing
func _talk_at_desk(body: Node) -> void:
    if seat == null:
        _face(body.global_position.x)
    _begin_hold(_rest_anim() if seat != null else "talk", 100000.0)
    var side := signf(body.global_position.x - global_position.x)
    if side == 0.0:
        side = -1.0
    body.global_position.x = _clamp_x(global_position.x + side * TALK_GAP)
    Talk.start(cast_name, self)


func talk_end() -> void:
    _hold = 0.05


func _clamp_x(x: float) -> float:
    var left: Node2D = _stage.get_node_or_null("WallLeft")
    var right: Node2D = _stage.get_node_or_null("WallRight")
    if left == null or right == null:
        return x
    return clampf(x, left.position.x + 14.0, right.position.x - 14.0)


func _on_body_entered(body: Node) -> void:
    if body.has_method("sit"):
        _inside = body
        body.add_near(self)


func _on_body_exited(body: Node) -> void:
    if body.has_method("sit"):
        body.remove_near(self)
        _inside = null
    _arrow.visible = false


# standing people duck under a dart that is flying at them (about 6 times in 10)
func _duck_tick(delta: float) -> bool:
    if _duck_t > 0.0:
        _duck_t -= delta
        if _duck_t <= 0.0:
            ducking = false
            _play("walk" if state == "walk" else _rest_anim())
        return true
    if seat != null or _hidden or _hold > 0.0 or not visible:
        return false
    var key := "duck_%d" % get_instance_id()
    for d in get_tree().get_nodes_in_group("darts"):
        if str(d.state) != "fly" or d.has_meta(key) or str(d.shooter) == cast_name:
            continue
        var dx: float = global_position.x - d.global_position.x
        var above: float = global_position.y - d.global_position.y
        if absf(dx) < 80.0 and signf(d.vel.x) == signf(dx) and above > 4.0 and above < 90.0:
            d.set_meta(key, true)
            if randf() < 0.6:
                ducking = true
                _duck_t = 0.9
                _face(d.global_position.x)
                _play("crouch")
                return true
    return false


func _can_chat() -> bool:
    return seat == null and state in CHATTY and not _hidden


func character_id() -> String:
    return character


func _play(anim: String) -> void:
    var a := anim
    if held != "" and seat == null:
        if anim == "idle":
            a = "hold"
        elif anim == "walk":
            a = "walkhold"
    sprite.play("%s_%s" % [a, facing])


func _give(item: String) -> void:
    if item != "":
        held = item
        sips = 0
        _item.item = held


func _face(x: float) -> void:
    if absf(x - global_position.x) > 0.5:
        facing = "right" if x > global_position.x else "left"


func _rest_anim() -> String:
    if seat == null:
        return "idle"
    return "type" if seat.typing and not _offline else "sit"


func _find(node_name: String) -> Node:
    return _stage.get_node_or_null("Interactables/%s" % node_name)


func _find_use(kind: String) -> Node:
    for child in _stage.get_node("Interactables").get_children():
        var n := String(child.name).to_lower()
        if n.begins_with("use") and kind in n and "target" in child:
            return child
    return null


func _occupy(seat_name: String, instant: bool) -> bool:
    var s := _find(seat_name)
    if s == null or s.occupied:
        return false
    seat = s
    seat.occupied = true
    global_position = seat.global_position
    facing = seat.facing
    if instant:
        state = "sitting"
    else:
        state = "sitdown"
        _play("sitdown")
    return true


func _stash() -> void:
    if held == "" or seat == null or not seat.stash:
        return
    _item.item = ""
    if _desk == null:
        _desk = preload("res://scripts/desk_cup.gd").new()
        get_parent().add_child.call_deferred(_desk)
    _desk.position = Vector2(seat.global_position.x + seat.cup_dx, 109.0)
    _desk.rest_y = seat.cup_y
    _desk.item = held


func _unstash() -> void:
    if _desk != null:
        _desk.item = ""
    _item.item = held


func _release() -> void:
    _unstash()
    global_position = Vector2(seat.global_position.x, seat.stand_y)
    seat.occupied = false
    seat = null


func _process(delta: float) -> void:
    _t += delta
    var is_player := cast_name != "" and character == PLAYER.current_character
    if is_player != _hidden:
        _hidden = is_player  # you are playing this character: the NPC lives on, unseen
        visible = not _hidden
        set_deferred("monitoring", not _hidden)
    if _update_call(delta):
        return
    if _duck_tick(delta):
        return
    if following and _follow_tick(delta):
        return
    _update_cast_chat(delta)
    _update_greeting()
    _update_reactions(delta)
    _arrow.visible = (
        _inside != null and _inside.nearest() == self and _can_chat() and _hold <= 0.0
    )
    if _hold > 0.0:
        _hold -= delta
        if _chat_slide != INF:
            global_position.x = move_toward(global_position.x, _chat_slide, 30.0 * delta)
        var turn := int((_hold_len - _hold) / 1.3) + _hold_phase
        _bubble.visible = turn % 2 == 0 and _hold_len > 2.0
        if _hold <= 0.0:
            _bubble.visible = false
            _chat_slide = INF
            _refresh()
        return
    match state:
        "walk":
            var d := _target_x - global_position.x
            if absf(d) <= SPEED * delta:
                global_position.x = _target_x
                _next_step()
            else:
                global_position.x += signf(d) * SPEED * delta
        "wait":
            _timer -= delta
            if _timer <= 0.0:
                _next_step()
        "say", "talk":
            _timer -= delta
            var turn := int(_t / 1.3)
            _bubble.visible = turn % 2 == get_index() % 2
            _bubble.glyph = GLYPHS[(turn / 2 + get_index()) % GLYPHS.size()]
            if _timer <= 0.0:
                _next_step()
        "await":
            if not _fx.busy:
                _start_use()
        "usewait":
            if not _fx.busy:
                _give(_fx.item)
                _next_step()
        "sync":
            if _stage.barriers[_key].gen > _gen:
                _next_step()


# ---- following the player ("C" next to a cast member) ------------------------
func toggle_follow(body: Node) -> void:
    if cast_name == "" or not _can_chat() or _hold > 0.0 or Social.is_cold(cast_name):
        _arrow.shake()
        return
    _face(body.global_position.x)
    World.set_following(cast_name, not following)
    _begin_hold("wave", 1.0)


# trail the player (a little behind them), stop when close; returns true while following
func _follow_tick(delta: float) -> bool:
    if _hold > 0.0 or seat != null:
        return false
    if _player == null:
        _player = _stage.get_node_or_null("Actors/Player")
        return false
    var px: float = _player.global_position.x
    var behind := -1.0 if _player.facing == "right" else 1.0
    var want := _clamp_x(px + behind * 30.0)
    var gap := want - global_position.x
    var moving := absf(gap) > 3.0
    var key := ("walk_" if moving else "stand_") + facing
    if moving:
        state = "walk"
        _target_x = want
        _face(want)
        global_position.x += signf(gap) * minf(absf(gap), SPEED * 1.4 * delta)
        key = "walk_" + facing
    else:
        state = "wait"
        _face(px)
        key = "stand_" + facing
    if key != _follow_key:
        _follow_key = key
        _refresh()
    return true


# ---- two cast members meet: they stop, face each other and talk for a few seconds --
func _update_cast_chat(delta: float) -> void:
    _chat_check -= delta
    if _chat_check > 0.0 or cast_name == "" or following or _hold > 0.0 or not _can_chat():
        return
    _chat_check = 0.25
    for other in _stage.get_node("Actors").get_children():
        if other == self or not ("cast_name" in other) or other.cast_name == "":
            continue
        var ox: float = other.global_position.x
        var close := absf(ox - global_position.x) < 52.0
        if not close or other.following or other._hold > 0.0 or not other._can_chat():
            continue
        if World.try_chat(cast_name, other.cast_name):
            var side := signf(ox - global_position.x)
            if side == 0.0:
                side = 1.0
            var mid := (global_position.x + ox) * 0.5
            var secs := randf_range(5.0, 8.0)
            begin_chat(mid - side * 16.0, ox, secs, 0)
            other.begin_chat(mid + side * 16.0, global_position.x, secs, 1)
            return


func begin_chat(target_x: float, face_x: float, secs: float, phase: int) -> void:
    _chat_slide = target_x
    _hold_phase = phase
    _face(face_x)
    _begin_hold("talk", secs)


func give_item(item: String) -> void:
    held = item
    sips = 0
    _item.item = item


func fade_in() -> void:
    create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func fade_out() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.5)
    tween.finished.connect(queue_free)


# a seated NPC answers a ringing phone: ear tap, headset on, talk while typing, tap off
# returns true while the ear tap pauses the routine
func _update_call(delta: float) -> bool:
    var pause := false
    match _call_stage:
        "":
            if seat != null and state == "wait" and _hold <= 0.0 and not Game.busy:
                var zone := _ringing_phone()
                if zone != null:
                    zone.get_node(zone.target).play()
                    _call_stage = "tap_on"
                    _call_t = 0.7
                    _play("sitcall")
                    pause = true
        "tap_on":
            pause = true
            _call_t -= delta
            if _call_t <= 0.0:
                _call_stage = "talking"
                _call_t = 9.0
                _head_item.item = "headset"
                _refresh()
        "talking":
            _call_t -= delta
            if state != "say" and state != "talk":
                _bubble.glyph = "dots"
                _bubble.visible = (int((9.0 - _call_t) / 1.3) + get_index()) % 2 == 1
            if _call_t <= 0.0 and _hold <= 0.0:
                _call_stage = "tap_off"
                _call_t = 0.7
                _bubble.visible = false
                _play("sitcall" if seat != null else "call")
                pause = true
        "tap_off":
            pause = true
            _call_t -= delta
            if _call_t <= 0.0:
                _call_stage = ""
                _head_item.item = ""
                _refresh()
    return pause


func _ringing_phone() -> Node:
    for zone in get_tree().get_nodes_in_group("phones"):
        var fx: Node = zone.get_node(zone.target)
        var dx: float = zone.global_position.x - seat.global_position.x
        var near := dx > 20.0 and dx < 70.0  # a desk phone sits to the right of its own seat
        if fx.ringing and not fx.busy and near:
            return zone
    return null


func _update_greeting() -> void:
    if _player == null:
        _player = _stage.get_node_or_null("Actors/Player")
        return
    var d := absf(_player.global_position.x - global_position.x)
    if d > GREET_RANGE * 2.0:
        _greeted = false
    elif d < GREET_RANGE and not _greeted and _can_chat() and _hold <= 0.0 and not Game.busy:
        _greeted = true
        if Social.is_cold(cast_name):
            return  # they do not wave at someone they dislike
        _face(_player.global_position.x)
        _begin_hold("wave", 1.3)
        if Social.is_friendly(cast_name):
            _bubble.glyph = "heart"


func _begin_hold(anim: String, secs: float) -> void:
    _hold = secs
    _hold_len = secs
    _bubble.glyph = "dots"
    _play(anim)


func _refresh() -> void:
    if state == "walk":
        _face(_target_x)
        _play("walk")
    else:
        _play(_rest_anim())


func _next_step() -> void:
    _bubble.visible = false
    if routine.is_empty():
        _finish_routine()
        return
    for _i in routine.size():
        _step += 1
        if _step >= routine.size():
            if cast_name != "":
                break
            _step = 0
        if _start(routine[_step].split(":")):
            return
    if cast_name != "":
        _finish_routine()
        return
    state = "wait"
    _timer = 1.0
    _play(_rest_anim())


# a cast member has run out of steps: wait quietly and let the World hand over the next leg
func _finish_routine() -> void:
    state = "wait"
    _timer = 1.0e9
    _play(_rest_anim())
    if cast_name != "":
        World.leg_done.call_deferred(cast_name)


# lights:on / lights:off / lights:last (off only if nobody else of the cast is still in the room)
func _flip_lights(mode: String) -> bool:
    var room: String = _stage.scene_file_path.get_file().get_basename()
    var on: bool = World.lights_on(room)
    var changed := false
    World.lights_by_npc = true
    if mode == "on" and not on:
        World.set_lights(room, true)
        changed = true
    elif mode == "off" and on:
        World.set_lights(room, false)
        changed = true
    elif mode == "last" and on and World.last_one_out(room, cast_name):
        World.set_lights(room, false)
        changed = true
    World.lights_by_npc = false
    return changed


func set_routine(new_routine: PackedStringArray) -> void:
    routine = new_routine
    _step = -1
    _next_step()


func _exit_tree() -> void:
    if cast_name != "" and not _leaving and is_instance_valid(World):
        World.node_left(cast_name, held, sips)


# starts a step; returns false if it was skipped or finished instantly
func _start(parts: PackedStringArray) -> bool:
    var started := true
    match parts[0]:
        "walk":
            started = _start_walk(float(parts[1]))
        "wait":
            state = "wait"
            _timer = float(parts[1])
            _play(_rest_anim())
        "say", "talk":
            state = parts[0]
            _timer = float(parts[1])
            if parts[0] == "talk":
                _play("talk")
        "use":
            started = _start_use_step(parts[1])
        "sit":
            started = seat == null and _occupy(parts[1], false)
        "stand":
            started = seat != null
            if started:
                state = "standup"
                sprite.play_backwards("sitdown_%s" % facing)
        "sync":
            started = _start_sync(parts[1], int(parts[2]))
        "sip":
            started = held != ""
            if started:
                state = "sip"
                _item.item = held
                if _desk != null:
                    _desk.item = ""
                _play("sitsip" if seat != null else "sip")
        "lights":
            started = _flip_lights(parts[1])
            if started:
                state = "wait"
                _timer = 0.8
                _play("reach")
        "notify":
            started = cast_name != ""
            if started:
                state = "wait"
                _timer = 3.0
                _play("talk")
                Sales.deliver.call_deferred()
        "exit":
            started = cast_name != ""
            if started:
                state = "wait"
                _timer = 1.0e9
                _play("idle")
                World.leg_exit.call_deferred(cast_name)
        "drop":
            held = ""
            _item.item = ""
            if _desk != null:
                _desk.item = ""
            started = false
        _:
            started = false
    return started


func _start_walk(x: float) -> bool:
    _target_x = x
    if absf(_target_x - global_position.x) < 1.0:
        return false
    state = "walk"
    _face(_target_x)
    _play("walk")
    return true


func _start_use_step(kind: String) -> bool:
    var area := _find_use(kind)
    if area == null:
        return false
    _fx = area.get_node(area.target)
    _face(area.look_x if area.look_x != 0.0 else area.global_position.x)
    if _fx.busy:
        state = "await"
        _play("idle")
    else:
        _start_use()
    return true


# barrier: returns false (do not block) for the last character to arrive
func _start_sync(key: String, count: int) -> bool:
    _key = key
    var b: Dictionary = _stage.barriers.get(key, {"arrived": 0, "gen": 0})
    _gen = b.gen
    b.arrived += 1
    var last: bool = b.arrived >= count
    if last:
        b.arrived = 0
        b.gen += 1
    _stage.barriers[key] = b
    if not last:
        state = "sync"
        _play(_rest_anim())
    return not last


func _start_use() -> void:
    state = "use"
    _play("reach")
    _fx.play()


func _on_animation_finished() -> void:
    match state:
        "use":
            state = "usewait"
            _play("idle")
        "sip":
            sips += 1
            if sips >= (6 if seat != null else 3):
                held = ""
                _item.item = ""
            else:
                _stash()
            _next_step()
        "sitdown":
            state = "sitting"
            _stash()
            _next_step()
        "standup":
            _release()
            _next_step()
''')

START_DICT = "{" + ", ".join('"%s": %d' % (k, v[0] - 1) for k, v in ANIMS.items()) + "}"
write("scripts/held_item.gd", '''extends Node2D
# An item (coffee / water cup) glued to its owner's near hand. The hand position of every
# sheet frame comes from assets/characters/<name>_<facing>_hands.json (tools/build_anims.lua).

const START := ''' + START_DICT + '''
const INK := Color("17121f")

var item := ""
var mode := "hand"  # "hand" follows the near hand, "ear" follows the ear (headset)

var _hands := {}
var _side := 1.0
var _tilt := 0.0
var _t := 0.0


func _process(delta: float) -> void:
    _t += delta
    visible = item != ""
    if not visible:
        return
    var owner_node := get_parent()
    var sprite: AnimatedSprite2D = owner_node.get_node("Sprite")
    var parts := String(sprite.animation).rsplit("_", true, 1)
    if parts.size() < 2 or not START.has(parts[0]):
        visible = false
        return
    _side = 1.0 if parts[1] == "right" else -1.0
    var key := "%s_%s" % [owner_node.character_id(), parts[1]]
    if not _hands.has(key):
        var path := "res://assets/characters/%s_hands.json" % key
        _hands[key] = JSON.parse_string(FileAccess.get_file_as_string(path))
    var table: Array = _hands[key]
    var idx: int = START[parts[0]] + sprite.frame
    if idx >= table.size():
        visible = false
        return
    var k := 2 if mode == "ear" else 0
    position = Vector2(float(table[idx][k]) - 32.0, float(table[idx][k + 1]) - 80.0)
    _tilt = 0.0
    if mode == "hand" and parts[0] in ["sip", "sitsip"]:
        var f := mini(sprite.frame, 2)
        _tilt = [30.0, 112.0, 45.0][f]
    queue_redraw()


# wireless earpiece with a short mic boom (origin = the ear)
func _draw_headset() -> void:
    var s := _side
    var body := Color("2a2a33")
    draw_rect(Rect2(-2, -3, 4, 6), INK)
    draw_rect(Rect2(-1, -2, 2, 4), body)
    var led := Color("4f7fd0") if int(_t * 2.0) % 2 == 0 else Color("1c2a4a")
    draw_rect(Rect2(-0.5 - 0.5 * s, -2, 1, 1), led)
    draw_rect(Rect2(s * 1.0 - 0.5, 2, 1, 2), INK)              # the boom curves down and forward to the mouth
    draw_rect(Rect2(s * 2.0 - 0.5, 4, 1, 2), INK)
    draw_rect(Rect2(s * 3.0 - 0.5, 6, 1, 2), INK)
    draw_rect(Rect2(s * 4.0 - 1.0, 7, 3, 2), INK)
    draw_rect(Rect2(s * 4.0 - 0.5, 7.5, 2, 1), body)


func _draw() -> void:
    if mode == "ear":
        _draw_headset()
        return
    var lift := clampf(_tilt / 112.0, 0.0, 1.0)  # the cup also moves forward / up to the lips
    var shift := Vector2(5.0 * lift * _side, -1.0 * lift)
    draw_set_transform(shift, deg_to_rad(_tilt) * _side, Vector2.ONE)
    if item == "coffee":
        draw_rect(Rect2(-3, -4, 6, 9), INK)
        draw_rect(Rect2(-2, -3, 4, 7), Color("f4f2ea"))
        draw_rect(Rect2(-2, -3, 4, 2), Color("5a3620"))
        var hx := 3.0 if _side > 0.0 else -4.0
        draw_rect(Rect2(hx, -2, 1, 4), INK)
    elif item == "nerf":
        var d := _side
        draw_rect(Rect2(-5.0 if d > 0.0 else -4.0, -3, 9, 5), INK)
        draw_rect(Rect2(-4.0 if d > 0.0 else -3.0, -2, 7, 3), Color("ff8a1f"))
        draw_rect(Rect2(2.0 if d > 0.0 else -4.0, -2, 2, 3), Color("2b79f0"))
        draw_rect(Rect2(-1, 2, 2, 3), INK)
    elif item == "plug_net":
        draw_rect(Rect2(-2, -4, 5, 7), INK)
        draw_rect(Rect2(-1, -3, 3, 4), Color("4f7fd0"))
        draw_rect(Rect2(-1, 1, 3, 2), Color("c8ccd8"))
    elif item == "plug_pwr":
        draw_rect(Rect2(-2, -4, 5, 7), INK)
        draw_rect(Rect2(-1, -3, 3, 4), Color("3c414d"))
        draw_rect(Rect2(-1, 1, 1, 3), Color("c8ccd8"))
        draw_rect(Rect2(1, 1, 1, 3), Color("c8ccd8"))
    elif item == "soda":
        draw_rect(Rect2(-3, -5, 6, 10), INK)
        draw_rect(Rect2(-2, -4, 4, 8), Color("d23c3c"))
        draw_rect(Rect2(-2, -4, 4, 1), Color("b8bcc4"))
        draw_rect(Rect2(-2, -1, 4, 2), Color("f4f2ea"))
    elif item == "bottle":
        draw_rect(Rect2(-1, -7, 2, 2), INK)
        draw_rect(Rect2(-3, -5, 6, 11), INK)
        draw_rect(Rect2(-2, -4, 4, 9), Color("cfe6f6"))
        draw_rect(Rect2(-2, -1, 4, 6), Color("8cc0e8"))
        draw_rect(Rect2(-1, -7, 2, 1), Color("f4f2ea"))
    elif item == "water":
        draw_rect(Rect2(-3, -4, 6, 9), INK)
        draw_rect(Rect2(-2, -3, 4, 7), Color("e4f2fb"))
        draw_rect(Rect2(-2, -1, 4, 5), Color("8cc0e8"))
''')

write("scripts/desk_cup.gd", '''extends Node2D
# A cup on a desk (the node sits on the desk's sort line; the cup is drawn up on the desktop).

const INK := Color("17121f")

var item := "":
    set(value):
        item = value
        queue_redraw()

var rest_y := 84.0

var _t := 0.0


func _process(delta: float) -> void:
    _t += delta
    if item == "coffee":
        queue_redraw()


func _draw() -> void:
    if item == "":
        return
    draw_set_transform(Vector2(0, rest_y - 109.0), 0.0, Vector2.ONE)
    draw_rect(Rect2(-3, -9, 6, 9), INK)
    if item == "coffee":
        draw_rect(Rect2(-2, -8, 4, 7), Color("f4f2ea"))
        draw_rect(Rect2(-2, -8, 4, 2), Color("5a3620"))
        draw_rect(Rect2(3, -7, 1, 4), INK)
        var p := fposmod(_t * 0.8, 1.0)
        var wisp := Rect2(-1 + roundf(sin(_t * 3.0)), -11 - p * 4.0, 1, 2)
        draw_rect(wisp, Color(0.93, 0.95, 0.98, 1.0 - p))
    elif item == "soda":
        draw_rect(Rect2(-2, -8, 4, 7), Color("d23c3c"))
        draw_rect(Rect2(-2, -8, 4, 1), Color("b8bcc4"))
        draw_rect(Rect2(-2, -5, 4, 2), Color("f4f2ea"))
    elif item == "bottle":
        draw_rect(Rect2(-2, -8, 4, 7), Color("cfe6f6"))
        draw_rect(Rect2(-2, -5, 4, 4), Color("8cc0e8"))
        draw_rect(Rect2(-1, -10, 2, 1), Color("f4f2ea"))
    else:
        draw_rect(Rect2(-2, -8, 4, 7), Color("e4f2fb"))
        draw_rect(Rect2(-2, -6, 4, 5), Color("8cc0e8"))
''')

write("scripts/world.gd", '''extends Node
# Autoload: the persistent cast. Alan, Garrison and Dan each live in exactly one place at a
# time and keep living when you are elsewhere. A workday clock (9:00 to 17:00, `day_len` real
# seconds long) drives their agenda: work at the desk, coffee, the copier and cooler, the
# bathroom, meetings in the conference room, lunch together at 12:00, then everyone leaves
# through the front door at 17:00 and comes back the next morning. In the room you are in they
# are real NPC nodes; anywhere else they are advanced by timers (each "leg" of their agenda has
# an estimated duration), so when you walk into a room they are where the simulation says.
# You can also ask someone to follow you (C next to them): they trail you through the doors
# until you ask again, they time out, or the day ends.

signal lights_changed(room: String)

const DATA := preload("res://scripts/world_data.gd")
const NPC_SCENE := preload("res://scenes/npc.tscn")
const HUD := preload("res://scripts/hud.gd")
const OUTSIDE := "__outside__"
const CAST := {
    "Alan": {"character": "office_alan", "home": "office_one", "seat": "Seat1"},
    "Garrison": {"character": "casual_garrison", "home": "office_two", "seat": "Seat1"},
    "Dan": {"character": "office_dan", "home": "main_floor", "seat": "Seat3"},
    "Vic": {"character": "sales_vic", "home": "cubicle_area", "seat": "Seat1", "role": "sales"},
    "Maya": {"character": "office_maya", "home": "main_floor", "seat": "Seat2"},
}
const SPEED := 32.0
const FLOOR_Y := 118.0
const SETTLE := 6.0  # after this long in a leg, someone you walk in on is already at the spot
const DAY_START := 9.0
const DAY_END := 17.0
const LUNCH_START := 12.0
const FOLLOW_SECS := 120.0
const CHAT_COOLDOWN := 60.0
const FOREVER := 1.0e9

var chars := {}  # name -> {scene, arrive, legs, leg_t, node, held, sips, ret, ...}
var time_scale := 1.0:
    get:
        # the day clock waits while a decision card or an outing is open
        if Campaign.active and (Cards.is_open or Outings.is_open):
            return 0.0
        return time_scale
var meeting_gap := Vector2(120.0, 190.0)
var day_len := 600.0  # real seconds for the 8 working hours
var clock := DAY_START
var day := 1
var hud_visible := true
var chat_count := 0
var chat_chance := 0.8
var lights := {}  # room -> bool (a missing room is lit)
var lights_by_npc := false  # a cast member is flipping a switch (nobody reacts to that)
var _outage_t := 0.0  # seconds the network has been down somewhere
var _closet_sent := false

var _meeting_t := 0.0
var _stage: Node = null
var _scene := ""
var _total := 0.0
var _pair_last := {}


func _ready() -> void:
    randomize()
    for n in CAST:
        chars[n] = _make_char(n)
    _meeting_t = randf_range(meeting_gap.x, meeting_gap.y)
    lights_changed.connect(_on_lights_changed)
    var layer := CanvasLayer.new()
    layer.layer = 90
    add_child(layer)
    var hud := HUD.new()
    hud.visible = not OS.get_cmdline_args().has("--write-movie")
    hud_visible = hud.visible
    layer.add_child(hud)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
        hud_visible = not hud_visible


# ---- lights ------------------------------------------------------------------
func lights_on(room: String) -> bool:
    return lights.get(room, true)


func set_lights(room: String, on: bool) -> void:
    if lights_on(room) != on:
        lights[room] = on
        lights_changed.emit(room)


func toggle_lights(room: String) -> void:
    set_lights(room, not lights_on(room))


# nobody else of the cast is left in the room (so whoever is walking out turns the lights off)
func last_one_out(room: String, who: String) -> bool:
    for n in chars:
        if n != who and chars[n].scene == room:
            return false
    return true


func clock_text() -> String:
    var h := int(clock)
    var m := int((clock - float(h)) * 60.0)
    return "%d:%02d" % [h % 24, m]


# ---- the room the player is in -----------------------------------------------
func populate(stage: Node) -> void:
    _stage = stage
    _scene = stage.scene_file_path.get_file().get_basename()
    for n in chars:
        chars[n].node = null
        if chars[n].scene == _scene:
            _spawn(n)


func _spawn(n: String) -> void:
    var st: Dictionary = chars[n]
    var leg: Dictionary = st.legs[0]
    var info: Dictionary = DATA.SCENES[_scene]
    var npc: Node = NPC_SCENE.instantiate()
    npc.name = n
    npc.cast_name = n
    npc.character = CAST[n].character
    npc.start_item = st.held
    npc.sips = st.sips
    npc.following = st.following
    var elapsed: float = leg.dur - st.leg_t
    var routine: PackedStringArray = leg.routine
    var dark_arrival: bool = st.arrive != "" and not lights_on(_scene) and clock < DAY_END
    var spawn: Array = info.spawns.get(st.arrive, info.spawns["start"])
    var x := float(spawn[0])
    npc.facing = str(spawn[1])
    if str(leg.get("seat", "")) != "":
        npc.start_seat = str(leg.seat)
        routine = PackedStringArray(["wait:100000"])
        x = float(info.seats[leg.seat])
    elif leg.get("seated", false) and (leg.get("start_seated", false) or elapsed > SETTLE):
        npc.start_seat = CAST[n].seat
        routine = PackedStringArray(["wait:%d" % maxi(2, int(st.leg_t))])
        x = float(info.seats[CAST[n].seat])
    elif elapsed > SETTLE and leg.target_x >= 0.0 and leg.kind != "follow":
        x = leg.target_x
    elif dark_arrival and leg.kind != "follow":
        var pre := PackedStringArray(["walk:%d" % info.uses.switch, "lights:on"])
        pre.append_array(routine)
        routine = pre
    npc.routine = routine
    npc.position = Vector2(x, FLOOR_Y)
    if st.fresh:
        npc.modulate.a = 0.0
    _stage.get_node("Actors").add_child(npc)
    st.node = npc
    if st.fresh:
        st.fresh = false
        npc.fade_in()


# ---- events from NPC nodes ---------------------------------------------------
func leg_done(n: String) -> void:
    var st: Dictionary = chars[n]
    if st.legs.is_empty() or st.following:
        return
    st.legs.pop_front()
    if st.legs.is_empty():
        st.legs = _plan(n)
    st.leg_t = st.legs[0].dur
    if st.node != null and is_instance_valid(st.node):
        st.node.set_routine(st.legs[0].routine)


func leg_exit(n: String) -> void:
    var st: Dictionary = chars[n]
    var node: Node = st.node
    var to_outside: bool = st.legs[0].get("to_scene", "") == OUTSIDE
    if node != null and is_instance_valid(node):
        st.held = node.held
        st.sips = node.sips
        node._leaving = true
        if to_outside:
            node.fade_out()
        else:
            node.queue_free()
    st.node = null
    _finish_leg(n)


func node_left(n: String, held: String, sips: int) -> void:
    # the scene changed under a living NPC: carry on off-screen from about halfway through the leg
    var st: Dictionary = chars[n]
    st.node = null
    st.held = held
    st.sips = sips
    st.leg_t = maxf(3.0, st.leg_t * 0.5)


# ---- off-screen simulation ---------------------------------------------------
func _process(delta: float) -> void:
    delta *= time_scale
    _total += delta
    clock += delta * 8.0 / day_len
    _watch_outage(delta)
    for n in chars:
        var st: Dictionary = chars[n]
        if st.following:
            st.follow_t -= delta
            if st.follow_t <= 0.0 or clock >= DAY_END:
                set_following(n, false)
        if st.node != null and is_instance_valid(st.node):
            continue
        st.leg_t -= delta
        if st.leg_t <= 0.0:
            _finish_leg(n)
    if clock >= DAY_END and _everyone_outside() and not Campaign.active:
        _new_day()
    _meeting_t -= delta
    if _meeting_t <= 0.0:
        _meeting_t = randf_range(meeting_gap.x, meeting_gap.y)
        if clock < LUNCH_START - 0.3 or (clock > LUNCH_START + 1.3 and clock < DAY_END - 0.5):
            _start_meeting()


# ---- reactions: the network goes down, somebody switches the lights off ------------------------
func _watch_outage(delta: float) -> void:
    if delta <= 0.0 or Game.title_mode:
        return
    var down := false
    for d in range(1, 9):
        down = down or Net.desk_state(d) != "ok"
    if not down:
        _outage_t = 0.0
        _closet_sent = false
        return
    _outage_t += delta
    if _outage_t < 8.0 or _closet_sent or clock >= DAY_END - 0.3:
        return
    for who in ["Dan", "Alan", "Garrison", "Maya", "Vic"]:
        if not chars.has(who):
            continue
        var st: Dictionary = chars[who]
        var kind := str(st.legs[0].kind) if not st.legs.is_empty() else ""
        if st.following or st.scene != CAST[who].home or kind != "work":
            continue  # busy elsewhere right now: the next free person goes
        _closet_sent = true  # somebody is on the way; try again only after the network comes back
        force_activity(who, "closet")
        return


func _make_char(n: String) -> Dictionary:
    var leg := _work_leg(n, true, randf_range(20.0, 50.0))
    return {
        "scene": CAST[n].home,
        "arrive": "",
        "legs": [leg],
        "leg_t": leg.dur,
        "node": null,
        "held": "",
        "sips": 0,
        "ret": "",
        "lunched": false,
        "following": false,
        "follow_t": 0.0,
        "fresh": false,
        "arriving": false,
    }


# Maya works in the tech campaign and Free Play (not on your payroll in the owner campaign).
func apply_roster() -> void:
    var owner_mode := Campaign.active and Campaign.mode == "owner"
    if owner_mode and chars.has("Maya"):
        var st: Dictionary = chars["Maya"]
        if st.node != null and is_instance_valid(st.node):
            st.node.queue_free()
        chars.erase("Maya")
    elif not owner_mode and not chars.has("Maya"):
        chars["Maya"] = _make_char("Maya")


func _on_lights_changed(room: String) -> void:
    if lights_on(room) or lights_by_npc or Game.title_mode or room != _scene or clock >= DAY_END - 0.05:
        return
    get_tree().create_timer(2.5).timeout.connect(_react_to_dark.bind(room))


func _react_to_dark(room: String) -> void:
    if lights_on(room) or room != _scene or not is_instance_valid(_stage):
        return
    var switch_x := float(DATA.SCENES[room].uses.get("switch", -1.0))
    var present := []
    for n in chars:
        var node: Node = chars[n].node
        if node != null and is_instance_valid(node) and not chars[n].following:
            present.append(node)
    for node in present:
        node.grumble()
    if not present.is_empty() and switch_x >= 0.0:
        present[randi() % present.size()].react_lights(switch_x)


func _everyone_outside() -> bool:
    for n in chars:
        if chars[n].scene != OUTSIDE:
            return false
    return true


# campaign: send the whole cast home and start the morning of `number`
func begin_next_day(number: int) -> void:
    apply_roster()
    for n in chars:
        var st: Dictionary = chars[n]
        if st.node != null and is_instance_valid(st.node):
            st.node._leaving = true
        st.node = null
        st.scene = OUTSIDE
        st.held = ""
        st.sips = 0
    lights.clear()
    day = number - 1
    _new_day()


# skip the night: next morning everyone drifts back in through the front door
func _new_day() -> void:
    day += 1
    clock = DAY_START - 0.5
    for n in chars:
        var st: Dictionary = chars[n]
        st.lunched = false
        st.following = false
        var wait_s := randf_range(5.0, 70.0)
        st.legs = [{
            "kind": "away", "scene": OUTSIDE, "routine": PackedStringArray(), "dur": wait_s,
            "target_x": -1.0, "to_scene": "main_floor", "to_spawn": "from_outside",
        }]
        st.leg_t = wait_s


# the current leg is over: step through its exit (if any) and start the next leg
func _finish_leg(n: String) -> void:
    var st: Dictionary = chars[n]
    var leg: Dictionary = st.legs.pop_front()
    if leg.get("visit", false):
        if Sales.visit_done():
            st["bell"] = true  # he rings the sales bell as soon as he is back in the office
    if leg.get("lights_last", false) and last_one_out(leg.scene, n):
        set_lights(leg.scene, false)
    if leg.has("to_scene"):
        var spawn: String = leg.to_spawn
        if spawn.begins_with("@"):
            spawn = st.ret
        if leg.get("remember", "") != "":
            st.ret = leg.remember
        st.scene = leg.to_scene
        st.arrive = spawn
        if st.scene != OUTSIDE and st.scene != _scene and clock < DAY_END:
            set_lights(st.scene, true)  # someone walking in unseen switches the lights on
        st.fresh = leg.kind == "away" and leg.scene == OUTSIDE
        st.arriving = st.fresh
        if st.scene == OUTSIDE:
            st.legs = [_away_leg()]
            st.leg_t = FOREVER
            if float(leg.get("visit_secs", 0.0)) > 0.0:
                var back: Dictionary = _away_leg()
                back["dur"] = float(leg.visit_secs)
                back["visit"] = true
                back["to_scene"] = "main_floor"
                back["to_spawn"] = "from_outside"
                st.legs = [back]
                st.leg_t = back.dur
            return
    if st.legs.is_empty():
        st.legs = _plan(n)
    if st.get("bell", false) and st.scene == "main_floor":
        st["bell"] = false
        st.legs.push_front(
            {
                "kind": "bell",
                "scene": "main_floor",
                "target_x": 132.0,
                "routine": PackedStringArray(["stand", "walk:132", "use:salesbell", "wait:2"]),
                "dur": 9.0,
            }
        )
    st.leg_t = st.legs[0].dur
    if st.scene == _scene and is_instance_valid(_stage) and st.node == null:
        _spawn(n)


# an outing: the whole cast stands around `spots` (set-pixel x values) in `room` until end_outing()
func start_outing(room: String, spots: Array, seats := {}) -> void:
    var x0 := float(DATA.SCENES[room].x0)
    var i := 0
    for n in chars:
        var st: Dictionary = chars[n]
        if st.node != null and is_instance_valid(st.node):
            st.node._leaving = true
        st.node = null
        st.scene = room
        st.arrive = "from_outing"
        st.fresh = false
        st.arriving = false
        st.following = false
        st.held = ""
        st.sips = 0
        var x := x0 + float(spots[i % spots.size()])
        st.legs = [{
            "kind": "outing", "scene": room, "dur": FOREVER, "target_x": x, "seat": str(seats.get(n, "")),
            "routine": PackedStringArray(["wait:100000"]),
        }]
        st.leg_t = FOREVER - 100.0  # already standing at their spot when the room appears
        i += 1
    set_lights(room, true)


# the outing is over (free play): everyone drifts back in through the front door
func end_outing() -> void:
    for n in chars:
        var st: Dictionary = chars[n]
        if st.node != null and is_instance_valid(st.node):
            st.node._leaving = true
        st.node = null
        st.scene = OUTSIDE
        var back: Dictionary = _away_leg()
        back["dur"] = randf_range(4.0, 20.0)
        back["to_scene"] = "main_floor"
        back["to_spawn"] = "from_outside"
        st.legs = [back]
        st.leg_t = back.dur


func _away_leg() -> Dictionary:
    return {
        "kind": "away", "scene": OUTSIDE, "routine": PackedStringArray(), "dur": FOREVER,
        "target_x": -1.0,
    }


func _follow_leg() -> Dictionary:
    return {
        "kind": "follow", "scene": "", "routine": PackedStringArray(), "dur": FOREVER,
        "target_x": -1.0,
    }


# ---- following ---------------------------------------------------------------
func set_following(n: String, on: bool) -> void:
    var st: Dictionary = chars[n]
    if on == st.following:
        return
    st.following = on
    var node: Node = st.node if (st.node != null and is_instance_valid(st.node)) else null
    if on:
        st.follow_t = FOLLOW_SECS
        st.legs = [_follow_leg()]
        st.leg_t = FOREVER
    else:
        st.legs = _plan(n)
        st.leg_t = st.legs[0].dur
    if node != null:
        node.following = on
        if not on:
            node.set_routine(st.legs[0].routine)


# the player is changing rooms: everyone following heads for the same room
func player_left(_from: String, to: String) -> void:
    for n in chars:
        var st: Dictionary = chars[n]
        if not st.following or st.scene == OUTSIDE:
            continue
        var legs := []
        if st.scene != to:
            legs = _travel(st.scene, to, _hint_x(n))
        legs.append(_follow_leg())
        st.legs = legs
        st.leg_t = legs[0].dur


func _hint_x(n: String) -> float:
    var st: Dictionary = chars[n]
    if st.node != null and is_instance_valid(st.node):
        return st.node.global_position.x
    return _spawn_x(st.scene, st.arrive)


# ---- agendas -----------------------------------------------------------------
func _plan(n: String) -> Array:
    var st: Dictionary = chars[n]
    if st.following:
        return [_follow_leg()]
    if st.scene == OUTSIDE:
        return _outside_plan()
    var origin_x := _hint_x(n)
    if clock >= DAY_END:
        return _leave_plan(n, origin_x)
    if st.scene != CAST[n].home or st.arriving:
        st.arriving = false
        var legs := _travel(st.scene, CAST[n].home, origin_x)
        legs.append(_work_leg(n, false, randf_range(25.0, 50.0)))
        return legs
    if clock >= LUNCH_START and not st.lunched and clock < LUNCH_START + 1.2:
        st.lunched = true
        # the account manager lunches with a client instead
        return _visit_plan(n, 50.0) if CAST[n].get("role", "") == "sales" else _lunch_plan(n)
    var kinds := ["work", "work", "coffee", "coffee", "cooler", "bathroom"]
    if CAST[n].get("role", "") == "sales":
        kinds = ["work", "work", "visit", "visit", "coffee", "bathroom"]
    return plan_for(n, kinds[randi() % kinds.size()])


func plan_for(n: String, kind: String) -> Array:
    var legs := []
    match kind:
        "coffee":
            legs = _trip(n, "kitchenette", _coffee_leg())
        "visit":
            return _visit_plan(n, randf_range(45.0, 90.0))
        "cooler":
            legs = _trip(n, "cubicle_area", _cooler_leg())
        "closet":
            legs = _trip(n, "network_closet", _closet_leg())
        "bathroom":
            legs = _trip(n, "bathroom", _bathroom_leg())
        _:
            return [_work_leg(n, true, randf_range(30.0, 70.0))]
    legs.append(_work_leg(n, false, randf_range(25.0, 55.0)))
    return legs


# there and back: travel legs, the activity leg, travel legs home
func _trip(n: String, scene: String, activity: Dictionary) -> Array:
    var home: String = CAST[n].home
    var x := float(DATA.SCENES[home].seats[CAST[n].seat])
    var legs := _travel(home, scene, x)
    activity.scene = scene
    legs.append(activity)
    legs.append_array(_travel(scene, home, activity.target_x))
    return legs


# lunch: bring a drink, then eat together at the conference table
func _lunch_plan(n: String) -> Array:
    var home: String = CAST[n].home
    var seat := "Seat%d" % (CAST.keys().find(n) + 1)
    var x := float(DATA.SCENES["conference"].seats[seat])
    var st: Dictionary = chars[n]
    st.held = ["soda", "bottle", "coffee"][randi() % 3]
    st.sips = 0
    if st.node != null and is_instance_valid(st.node):
        st.node.give_item(st.held)
    var routine := ["walk:%d" % x, "sit:%s" % seat]
    for _i in 9:
        routine.append_array(["wait:4", "say:2", "sip"])
    var eat := {
        "kind": "lunch", "scene": "conference", "target_x": x, "dur": 56.0,
        "routine": PackedStringArray(routine),
    }
    var legs := _travel(st.scene, "conference", _hint_x(n))
    legs.append(eat)
    legs.append_array(_travel("conference", home, x))
    legs.append(_work_leg(n, false, randf_range(25.0, 45.0)))
    return legs


# end of the day: out through the front door; back at the start of the next day
func _leave_plan(n: String, from_x: float) -> Array:
    var door_x := float(DATA.SCENES["main_floor"].outside_x)
    var legs := _travel(chars[n].scene, "main_floor", from_x, true)
    var arrive_x := door_x
    if not legs.is_empty():
        arrive_x = _spawn_x("main_floor", legs[legs.size() - 1].to_spawn)
    legs.append({
        "kind": "leave", "scene": "main_floor", "target_x": door_x,
        "routine": PackedStringArray(
            ["stand", "walk:%d" % _uses("main_floor").switch, "lights:last", "walk:%d" % door_x, "exit:FrontDoor"]
        ),
        "dur": absf(door_x - arrive_x) / SPEED + 4.0, "to_scene": OUTSIDE, "to_spawn": "",
        "lights_last": true,
    })
    return legs


# planned while outside with no way back queued: stay out after closing, else come in the front door
func _outside_plan() -> Array:
    if clock >= DAY_END:
        return [_away_leg()]
    var back := _away_leg()
    back["dur"] = randf_range(5.0, 20.0)
    back["to_scene"] = "main_floor"
    back["to_spawn"] = "from_outside"
    return [back]


# the account manager leaves for a client visit and comes back through the front door
func _visit_plan(n: String, secs: float) -> Array:
    var door_x := float(DATA.SCENES["main_floor"].outside_x)
    var legs := _travel(chars[n].scene, "main_floor", _hint_x(n))
    var arrive_x := door_x
    if not legs.is_empty():
        arrive_x = _spawn_x("main_floor", legs[legs.size() - 1].to_spawn)
    legs.append({
        "kind": "leave", "scene": "main_floor", "target_x": door_x,
        "routine": PackedStringArray(["stand", "walk:%d" % door_x, "exit:FrontDoor"]),
        "dur": absf(door_x - arrive_x) / SPEED + 3.0, "to_scene": OUTSIDE, "to_spawn": "", "visit_secs": secs,
    })
    return legs


# a client complained to Vic: he walks over to wherever you are and tells you
func send_vic_to_player() -> void:
    if not chars.has("Vic") or _scene == "":
        Sales.pending = {}
        return
    var st: Dictionary = chars["Vic"]
    if st.scene == OUTSIDE or st.following:
        var said := Sales.complaint_text()
        if said != "":
            Msp.send_text("Vic", said)
            Sales.adjust(int(Sales.pending.get("client", 0)), -2)
        Sales.pending = {}
        return
    var px := 150.0
    var player: Node = _stage.get_node_or_null("Actors/Player") if is_instance_valid(_stage) else null
    if player != null:
        px = player.global_position.x
    var info: Dictionary = DATA.SCENES[_scene]
    var from_x := _hint_x("Vic")
    var stand := clampf(px - 34.0 if from_x < px else px + 34.0, float(info.x0) + 16.0, float(info.x0 + info.W) - 16.0)
    var legs := []
    if st.scene != _scene:
        legs = _travel(st.scene, _scene, from_x)
    legs.append({
        "kind": "news", "scene": _scene, "target_x": stand,
        "routine": PackedStringArray(["stand", "walk:%d" % int(stand), "notify:news"]),
        "dur": absf(stand - from_x) / SPEED + 8.0,
    })
    st.legs = legs
    st.leg_t = legs[0].dur
    if st.node != null and is_instance_valid(st.node):
        st.node.set_routine(legs[0].routine)


func _travel(from_scene: String, to_scene: String, from_x: float, closing := false) -> Array:
    var legs := []
    var x := from_x
    for link in _route(from_scene, to_scene):
        var routine := ["stand", "walk:%d" % link.x, "exit:%s" % link.name]
        if closing:  # end of the day: the last one out of each room turns its lights off
            routine = ["stand", "walk:%d" % _uses(link.from).switch, "lights:last"] + routine.slice(1)
        legs.append({
            "kind": "travel", "scene": link.from, "target_x": float(link.x),
            "routine": PackedStringArray(routine),
            "dur": absf(float(link.x) - x) / SPEED + (4.0 if closing else 2.0),
            "to_scene": link.to, "to_spawn": link.spawn, "remember": link.get("remember", ""),
            "lights_last": closing,
        })
        x = _spawn_x(link.to, link.spawn)
    return legs


func _spawn_x(scene: String, spawn: String) -> float:
    if not DATA.SCENES.has(scene):
        return 100.0
    var spawns: Dictionary = DATA.SCENES[scene].spawns
    return float(spawns.get(spawn, spawns["start"])[0])


func _route(a: String, b: String) -> Array:
    if not DATA.SCENES.has(a) or not DATA.SCENES.has(b):
        return []
    var came := {}
    var queue := [a]
    came[a] = null
    while not queue.is_empty() and not came.has(b):
        var cur: String = queue.pop_front()
        for link in DATA.SCENES[cur].links:
            if not came.has(link.to):
                var hop: Dictionary = link.duplicate()
                hop["from"] = cur
                came[link.to] = hop
                queue.append(link.to)
    var path := []
    var at := b
    while came.has(at) and came[at] != null:
        path.push_front(came[at])
        at = came[at].from
    return path if came.has(b) else []


func _uses(scene: String) -> Dictionary:
    return DATA.SCENES[scene].uses


func _work_leg(n: String, start_seated: bool, secs: float) -> Dictionary:
    var seat: String = CAST[n].seat
    var x := float(DATA.SCENES[CAST[n].home].seats[seat])
    var half := int(secs * 0.5)
    return {
        "kind": "work", "scene": CAST[n].home, "seated": true, "start_seated": start_seated,
        "routine": PackedStringArray(
            ["walk:%d" % x, "sit:%s" % seat, "wait:%d" % half, "sip", "wait:%d" % int(secs - half)]
        ),
        "dur": secs + (0.0 if start_seated else 4.0), "target_x": x,
    }


func _coffee_leg() -> Dictionary:
    var u: Dictionary = _uses("kitchenette")
    var routine := ["walk:%d" % u.coffee, "use:coffee", "wait:1", "sip", "wait:2"]
    var dur := 20.0
    if randf() < 0.5:
        routine.append_array(["walk:%d" % u.fridge, "use:fridge", "wait:1", "sip"])
        dur += 12.0
    return {"kind": "coffee", "routine": PackedStringArray(routine), "dur": dur, "target_x": float(u.coffee)}


# somebody goes to look at the rack when the network has been down for a while
func _closet_leg() -> Dictionary:
    var x := float(DATA.SCENES["network_closet"].x0) + 86.0
    return {
        "kind": "closet", "dur": 22.0, "target_x": x,
        "routine": PackedStringArray(["walk:%d" % int(x), "wait:3", "talk:5", "wait:6"]),
    }


func _cooler_leg() -> Dictionary:
    var u: Dictionary = _uses("cubicle_area")
    return {
        "kind": "cooler", "dur": 24.0, "target_x": float(u.copier),
        "routine": PackedStringArray(
            ["walk:%d" % u.copier, "use:copier", "walk:%d" % u.cooler, "use:cooler", "wait:2", "sip"]
        ),
    }


func _bathroom_leg() -> Dictionary:
    var u: Dictionary = _uses("bathroom")
    return {
        "kind": "bathroom", "dur": 12.0, "target_x": float(u.sink),
        "routine": PackedStringArray(["walk:%d" % u.sink, "use:sink", "wait:2"]),
    }


# ---- conversations between cast members --------------------------------------
# NPC nodes ask permission when they bump into each other (a cooldown stops endless chatter)
func try_chat(a: String, b: String) -> bool:
    var key := a + "|" + b if a < b else b + "|" + a
    if _total - float(_pair_last.get(key, -1.0e9)) < CHAT_COOLDOWN:
        return false
    if randf() > chat_chance:
        _pair_last[key] = _total - CHAT_COOLDOWN + 3.0  # try again in a few seconds
        return false
    _pair_last[key] = _total
    chat_count += 1
    return true


# ---- meetings ----------------------------------------------------------------
func _start_meeting() -> void:
    var ready_names := []
    for n in chars:
        var st: Dictionary = chars[n]
        var at_desk: bool = st.scene == CAST[n].home and st.legs.size() == 1
        if at_desk and st.legs[0].kind == "work" and not st.following:
            ready_names.append(n)
    if ready_names.size() < 2:
        return
    ready_names.shuffle()
    for i in mini(3, ready_names.size()):
        send_to_meeting(ready_names[i], "Seat%d" % (i + 1))


# the weekly all-hands: everyone goes to the conference room and sits (the last seats are yours)
func start_all_hands() -> void:
    var i := 1
    for n in chars:
        if chars[n].following:
            set_following(n, false)
        send_to_meeting(n, "Seat%d" % i, 90.0)
        i += 1


func send_to_meeting(n: String, seat: String, secs := 48.0) -> void:
    var st: Dictionary = chars[n]
    var home: String = CAST[n].home
    var x := float(DATA.SCENES["conference"].seats[seat])
    var routine := ["walk:%d" % x, "sit:%s" % seat]
    for _i in int(secs / 6.0):
        routine.append_array(["wait:3", "say:2"])
    var meeting := {
        "kind": "meeting", "scene": "conference", "target_x": x, "dur": secs,
        "routine": PackedStringArray(routine),
    }
    var here: String = st.scene
    var legs := _travel(here, "conference", _hint_x(n))
    legs.append(meeting)
    legs.append_array(_travel("conference", home, x))
    legs.append(_work_leg(n, false, randf_range(25.0, 50.0)))
    st.legs = legs
    st.leg_t = legs[0].dur
    if st.node != null and is_instance_valid(st.node):
        st.node.set_routine(legs[0].routine)


# a character is sent off to do something now (used by tests and for scripted scenes)
func force_activity(n: String, kind: String) -> void:
    var st: Dictionary = chars[n]
    var legs := plan_for(n, kind)
    st.legs = legs
    st.leg_t = legs[0].dur
    if st.node != null and is_instance_valid(st.node):
        st.node.set_routine(legs[0].routine)
''')



write("scripts/pixelfont.gd", '''extends RefCounted
# gdlint: ignore=max-line-length
# A 3x5 pixel font for the in-game computer and phone screens (upper case only, like the logo tagline).
# PixelFont.draw(canvas_item, text, position, color, scale) / PixelFont.width(text, scale)

const GLYPHS := {
    "A": ["XXX", "X.X", "XXX", "X.X", "X.X"], "B": ["XX.", "X.X", "XX.", "X.X", "XX."],
    "C": [".XX", "X..", "X..", "X..", ".XX"], "D": ["XX.", "X.X", "X.X", "X.X", "XX."],
    "E": ["XXX", "X..", "XX.", "X..", "XXX"], "F": ["XXX", "X..", "XX.", "X..", "X.."],
    "G": [".XX", "X..", "X.X", "X.X", ".XX"], "H": ["X.X", "X.X", "XXX", "X.X", "X.X"],
    "I": ["XXX", ".X.", ".X.", ".X.", "XXX"], "J": ["..X", "..X", "..X", "X.X", ".X."],
    "K": ["X.X", "X.X", "XX.", "X.X", "X.X"], "L": ["X..", "X..", "X..", "X..", "XXX"],
    "M": ["X.X", "XXX", "XXX", "X.X", "X.X"], "N": ["XXX", "X.X", "X.X", "X.X", "X.X"],
    "O": [".X.", "X.X", "X.X", "X.X", ".X."], "P": ["XX.", "X.X", "XX.", "X..", "X.."],
    "Q": [".X.", "X.X", "X.X", "XX.", ".XX"], "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
    "S": [".XX", "X..", ".X.", "..X", "XX."], "T": ["XXX", ".X.", ".X.", ".X.", ".X."],
    "U": ["X.X", "X.X", "X.X", "X.X", "XXX"], "V": ["X.X", "X.X", "X.X", "X.X", ".X."],
    "W": ["X.X", "X.X", "XXX", "XXX", "X.X"], "X": ["X.X", "X.X", ".X.", "X.X", "X.X"],
    "Y": ["X.X", "X.X", ".X.", ".X.", ".X."], "Z": ["XXX", "..X", ".X.", "X..", "XXX"],
    "0": ["XXX", "X.X", "X.X", "X.X", "XXX"], "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
    "2": ["XX.", "..X", ".X.", "X..", "XXX"], "3": ["XX.", "..X", ".X.", "..X", "XX."],
    "4": ["X.X", "X.X", "XXX", "..X", "..X"], "5": ["XXX", "X..", "XX.", "..X", "XX."],
    "6": [".XX", "X..", "XXX", "X.X", "XXX"], "7": ["XXX", "..X", ".X.", ".X.", ".X."],
    "8": ["XXX", "X.X", "XXX", "X.X", "XXX"], "9": ["XXX", "X.X", "XXX", "..X", "XX."],
    ".": ["...", "...", "...", "...", ".X."], ",": ["...", "...", "...", ".X.", "X.."],
    ":": ["...", ".X.", "...", ".X.", "..."], ";": ["...", ".X.", "...", ".X.", "X.."],
    "!": [".X.", ".X.", ".X.", "...", ".X."], "?": ["XX.", "..X", ".X.", "...", ".X."],
    "-": ["...", "...", "XXX", "...", "..."], "_": ["...", "...", "...", "...", "XXX"],
    "/": ["..X", "..X", ".X.", "X..", "X.."], "(": [".X.", "X..", "X..", "X..", ".X."],
    ")": [".X.", "..X", "..X", "..X", ".X."], "'": [".X.", ".X.", "...", "...", "..."],
    "@": [".XX", "X.X", "XXX", "X..", ".XX"], "#": ["X.X", "XXX", "X.X", "XXX", "X.X"],
    "%": ["X.X", "..X", ".X.", "X..", "X.X"], "&": [".X.", "X.X", ".X.", "X.X", ".XX"],
    "+": ["...", ".X.", "XXX", ".X.", "..."], "=": ["...", "XXX", "...", "XXX", "..."],
    "*": ["...", "X.X", ".X.", "X.X", "..."], "<": ["..X", ".X.", "X..", ".X.", "..X"],
    ">": ["X..", ".X.", "..X", ".X.", "X.."], "[": ["XX.", "X..", "X..", "X..", "XX."],
    "]": [".XX", "..X", "..X", "..X", ".XX"], "|": [".X.", ".X.", ".X.", ".X.", ".X."],
    "$": [".XX", "XX.", ".X.", ".XX", "XX."], " ": ["...", "...", "...", "...", "..."],
}


static func width(text: String, scale := 1) -> int:
    return maxi(0, text.length() * 4 * scale - scale)


static func draw(canvas: CanvasItem, text: String, pos: Vector2, color: Color, scale := 1) -> void:
    var x := pos.x
    for ch in text.to_upper().replace('"', "'"):
        var rows: Array = GLYPHS.get(ch, GLYPHS["?"])
        for r in 5:
            var row: String = rows[r]
            for c in 3:
                if row[c] == "X":
                    canvas.draw_rect(Rect2(x + c * scale, pos.y + r * scale, scale, scale), color)
        x += 4.0 * scale
''')

write("scripts/msp.gd", '''extends Node
# gdlint: ignore=max-line-length
# Autoload: the managed-service-provider side of the game. Pixel IT Partners looks after a handful of silly
# small-business clients. Problems turn into tickets in the PSA (ConnectWhy PSA); the client
# emails you about them (Outlookish 2013); and the RMM (LabRat RMM) lets you remote into the
# client's PC to fix them. Your own office's network outages (the closet!) become internal
# tickets. Ticket SLA clocks run in real seconds scaled by
# World.time_scale, so they freeze on the title screen.

signal changed
signal ticket_added(ticket: Dictionary)
signal text_received(message: Dictionary)

const COMPANY := "Pixel IT Partners"
const CLIENTS := [
    {"name": "Acme Dental Group", "short": "ACME", "contact": "Dr. Patel", "mail": "patel@acmedental.example"},
    {"name": "Brightside Realty", "short": "BRSD", "contact": "Karen Whitfield", "mail": "karen@brightside.example"},
    {"name": "Gnarly Gnomes Landscaping", "short": "GNGN", "contact": "Bob Gnarly", "mail": "bob@gnarlygnomes.example"},
    {"name": "Hoot and Holler Law", "short": "HHLW", "contact": "Atty. Spence", "mail": "spence@hootholler.example"},
    {"name": "Soggy Bottom Brewing", "short": "SGBB", "contact": "Lucy Malt", "mail": "lucy@soggybottom.example"},
    {"name": "Piedmont Pediatrics", "short": "PEDI", "contact": "Dr. Okafor", "mail": "okafor@piedmontpeds.example"},
    {"name": "Rusty Anchor Marine Supply", "short": "RSTY", "contact": "Gil Anchor", "mail": "gil@rustyanchor.example"},
    {"name": "Zen Garden Yoga", "short": "ZENY", "contact": "Mina Park", "mail": "mina@zengarden.example"},
    {"name": "Paws and Claws Veterinary", "short": "PAWS", "contact": "Dr. Brandt", "mail": "brandt@pawsandclaws.example"},
    {"name": "Lindqvist and Moss Architects", "short": "LMAR", "contact": "Erik Lindqvist", "mail": "erik@lindqvistmoss.example"},
    {"name": "Iron Mule Demolition", "short": "IMUL", "contact": "Tony Marsh", "mail": "tony@ironmule.example"},
]
# fix = the RMM action that solves it; body uses %s for the contact's first name
const PROBLEMS := [
    {"summary": "Printer will not print", "fix": "spooler", "pri": 3,
     "body": "Every time I hit print it just sits there. I deleted the jobs and it did nothing. The copier down the hall is on the network too. People are waiting. Please help! - %s"},
    {"summary": "Locked out of my PC", "fix": "password", "pri": 2,
     "body": "It says my account is locked out. I swear I did nothing. Can you just give me a temporary password, or make me a fresh login? I cannot work until this is fixed. - %s"},
    {"summary": "Computer is very slow", "fix": "clear_temp", "pri": 3,
     "body": "It takes ten minutes to open one document. I emptied the recycle bin and nothing changed. Last time somebody just wiped it. Is it the weather? - %s"},
    {"summary": "Computer frozen on a blue screen", "fix": "reboot", "pri": 2,
     "body": "There is a blue screen with a sad face on it. It has been like this since lunch. I tried the F8 menu but did not know what to pick. Do I need a new computer? - %s"},
    {"summary": "Pop-ups everywhere", "fix": "av", "pri": 2,
     "body": "Hundreds of pop-ups say I won a free cruise. Did I win a cruise? I reset my browser and they came right back. Also I cannot close them. - %s"},
    {"summary": "Server not responding - nobody can work", "fix": "reboot", "pri": 1, "server": true,
     "body": "THE SERVER IS DOWN. Nobody can open anything. Everyone is standing around. Somebody says restart the services, somebody else says roll it back to last night. FIX IT! - %s"},
]
const RANSOM := {
    "summary": "Files encrypted - ransom note on the server", "fix": "restore", "pri": 1, "server": true,
    "special": "ransomware",
    "body": "All our files have strange names and there is a note demanding bitcoin! HELP! - %s",
}
const ADOBE := {
    "summary": "Adobe Reader will not print", "fix": "adobe", "pri": 4, "special": "adobe",
    "body": "I can open PDFs but print in Adobe Reader does nothing. Everything else prints, even from the browser. - %s",
}
const INSTALL := {
    "summary": "Windows XP is ending: new desktop for Dr. Patel", "fix": "project", "pri": 3, "special": "install",
    "body": "Microsoft is dropping support for Windows XP on April 8 and my old computer is on it. "
    + "The new one arrived! Please set it up and move everything over. "
    + "I am with patients all day. - %s",
}
# what lives on the old PC: key = losing it is a disaster; hidden = you must find it
const INSTALL_ITEMS := [
    {"id": "docs", "name": "MY DOCUMENTS (OFFICE 2003 FILES)", "secs": 3.0, "key": true, "hidden": ""},
    {"id": "mail", "name": "OUTLOOK 2003 PROFILE + PST", "secs": 3.0, "key": true, "hidden": ""},
    {"id": "desktop", "name": "DESKTOP FILES", "secs": 1.5, "key": false, "hidden": ""},
    {"id": "printers", "name": "PRINTERS", "secs": 1.0, "key": false, "hidden": ""},
    {"id": "bookmarks", "name": "BROWSER BOOKMARKS", "secs": 1.0, "key": false, "hidden": ""},
    {"id": "xray", "name": "XRAY SOFTWARE + XP DRIVERS", "secs": 2.5, "key": true, "hidden": "both"},
    {"id": "drives", "name": "MAPPED DRIVES", "secs": 1.0, "key": false, "hidden": "deep"},
    {"id": "sticky", "name": "STICKY NOTES", "secs": 0.5, "key": false, "hidden": "ask"},
]
const FIXES := {
    "spooler": "RESTART PRINT SPOOLER", "password": "RESET PASSWORD", "clear_temp": "CLEAR TEMP FILES",
    "reboot": "REBOOT", "av": "RUN AV SCAN", "restore": "RESTORE BACKUP", "adobe": "REPAIR ADOBE READER",
    "shadow": "RECOVER SHADOW COPIES", "pay": "PAY THE RANSOM (BITCOIN)", "save": "ASK USER TO SAVE",
}
# problems a reboot also clears (it works, but it is not the proper fix: the user is interrupted)
const ALT_FIXES := {"spooler": ["reboot"]}
# other valid fixes. kind: quick (fast, little XP, may come back 1-2 days later), heavy (slow, always
# works, costs the client something), clever (needs a skill level: faster, more XP).
# for = the problems it clears (server = a server only); mult = time vs the proper fix;
# xp = experience; mood/score = consequences; ret = chance it comes back; loses = restarts the PC
# (the user loses unsaved work they were not warned about; a blue-screened PC has none);
# back/back_body = the follow-up ticket
const ALT_DEFS := {
    "clear_queue":
    {
        "for": ["spooler"],
        "kind": "quick",
        "label": "CLEAR PRINT QUEUE",
        "mult": 0.4,
        "xp": 2,
        "ret": 0.45,
        "text": "Stuck jobs deleted. The printer wakes up, for now.",
        "note": "Deleted the stuck print jobs (the spooler itself was never restarted).",
        "back": "Printer stuck again",
        "back_body": "The printer worked for a day and now it just sits there again. - %s",
    },
    "reinstall_printer":
    {
        "for": ["spooler"],
        "kind": "heavy",
        "label": "REINSTALL PRINTER",
        "mult": 3.0,
        "xp": 3,
        "mood": -1,
        "text": "Driver removed and reinstalled. Slow, but the printer is solid now.",
        "note": "Removed and reinstalled the printer driver.",
    },
    "copier_route":
    {
        "for": ["spooler"],
        "kind": "clever",
        "label": "PRINT TO COPIER",
        "skill": "networking",
        "lvl": 2,
        "mult": 0.5,
        "xp": 6,
        "mood": 1,
        "text": "Mapped the hallway copier and made it their default printer. Back to work.",
        "note": "Pointed the user at the network copier while the spooler gets fixed later.",
    },
    "temp_pass":
    {
        "for": ["password"],
        "kind": "quick",
        "label": "GIVE TEMP PASSWORD",
        "mult": 0.4,
        "xp": 1,
        "ret": 0.5,
        "text": "Gave a temporary password over the phone. Please change it, please.",
        "note": "Read a temporary password over the phone (it will end up on a sticky note).",
        "back": "Locked out of my PC again",
        "back_body": "I wrote the temporary password on a sticky note and typed it wrong. Locked out again. - %s",
    },
    "new_profile":
    {
        "for": ["password"],
        "kind": "heavy",
        "label": "REBUILD PROFILE",
        "mult": 4.0,
        "xp": 3,
        "mood": -2,
        "loses": true,
        "text": "New domain profile built. Desktop and settings are back to factory.",
        "note": "Deleted and rebuilt the user's profile.",
    },
    "unlock_ps":
    {
        "for": ["password"],
        "kind": "clever",
        "label": "UNLOCK-ADACCOUNT",
        "skill": "powershell",
        "lvl": 2,
        "mult": 0.5,
        "xp": 6,
        "text": "One line of PowerShell unlocked the account and cleared the lockout source.",
        "note": "Unlocked the account with Unlock-ADAccount and killed the stale mapped drive.",
    },
    "recycle":
    {
        "for": ["clear_temp"],
        "kind": "quick",
        "label": "EMPTY RECYCLE BIN",
        "mult": 0.4,
        "xp": 2,
        "ret": 0.6,
        "text": "Recycle bin emptied. A few GB back, it will not last.",
        "note": "Emptied the recycle bin (the temp files are still there).",
        "back": "Computer is slow again",
        "back_body": "It was better for a day and now it is crawling again. The disk light never stops. - %s",
    },
    "disk_script":
    {
        "for": ["clear_temp"],
        "kind": "clever",
        "label": "CLEANUP SCRIPT",
        "skill": "powershell",
        "lvl": 3,
        "mult": 0.5,
        "xp": 6,
        "text": "Script cleared temp, old profiles and the update cache. Disk space is back.",
        "note": "Ran a cleanup script across the profile, temp and update cache folders.",
    },
    "browser_reset":
    {
        "for": ["av"],
        "kind": "quick",
        "label": "RESET BROWSER",
        "mult": 0.4,
        "xp": 1,
        "ret": 0.5,
        "text": "Browser reset to defaults. The pop-ups stopped, the adware did not.",
        "note": "Reset the browser settings (the adware is still installed).",
        "back": "Pop-ups are back",
        "back_body": "The pop-ups came back and now they have a new toolbar. Still no cruise. - %s",
    },
    "spyhunt":
    {
        "for": ["av"],
        "kind": "clever",
        "label": "SPYHUNT LOG SCAN",
        "skill": "security",
        "lvl": 2,
        "mult": 0.6,
        "xp": 7,
        "text": "SpyHunt log showed the startup entry. Removed it by hand, no full scan needed.",
        "note": "Read the SpyHunt log and removed the adware startup entry and its service by hand.",
    },
    "reimage":
    {
        "for": ["clear_temp", "av", "reboot"],
        "kind": "heavy",
        "label": "REIMAGE PC",
        "mult": 7.0,
        "xp": 3,
        "mood": -4,
        "loses": true,
        "text": "Reimaged from the gold image. Clean machine, but the user logs in to everything again.",
        "note": "Reimaged the PC from the gold image.",
    },
    "last_good":
    {
        "for": ["reboot"],
        "kind": "quick",
        "label": "LAST KNOWN GOOD",
        "mult": 0.6,
        "xp": 2,
        "mood": -1,
        "ret": 0.35,
        "text": "Booted the Last Known Good Configuration. Windows loads, for now.",
        "note": "Rebooted into Last Known Good Configuration (the driver is still bad).",
        "back": "Blue screen again",
        "back_body": "The blue screen is back, same as before. It came up fine for a day. - %s",
    },
    "safemode":
    {
        "for": ["reboot"],
        "kind": "clever",
        "label": "SAFE MODE DRIVER",
        "skill": "servers",
        "lvl": 2,
        "mult": 0.7,
        "xp": 7,
        "mood": -1,
        "text": "Safe mode, rolled back the bad driver, normal boot. Fixed for good.",
        "note": "Booted safe mode and rolled back the driver that caused the STOP error.",
    },
    "restart_services":
    {
        "for": ["reboot"],
        "server": true,
        "kind": "quick",
        "label": "RESTART SERVICES",
        "mult": 0.5,
        "xp": 2,
        "ret": 0.4,
        "text": "Restarted the file and mail services. Users are back, the cause is still there.",
        "note": "Restarted the key services (no root cause found).",
        "back": "Server slow and dropping again",
        "back_body": "The server is hanging again. Same as the other day. Everyone is waiting. - %s",
    },
    "snapshot":
    {
        "for": ["reboot"],
        "server": true,
        "kind": "heavy",
        "label": "ROLL BACK SNAPSHOT",
        "mult": 5.0,
        "xp": 3,
        "mood": -3,
        "score": -2,
        "text": "Rolled back to last night's snapshot. Up, but today's changes are gone.",
        "note": "Reverted the server VM to last night's snapshot (the day's file changes were lost).",
    },
    "event_log":
    {
        "for": ["reboot"],
        "server": true,
        "kind": "clever",
        "label": "FIND HUNG SERVICE",
        "skill": "servers",
        "lvl": 3,
        "mult": 0.6,
        "xp": 8,
        "mood": 1,
        "text": "The event log named the hung service. Fixed it without a reboot. Nobody noticed.",
        "note": "Read the event log, killed the hung service and patched the cause. No reboot.",
    },
    "print_browser":
    {
        "for": ["adobe"],
        "kind": "quick",
        "label": "PRINT FROM BROWSER",
        "mult": 0.3,
        "xp": 1,
        "ret": 0.6,
        "text": "Showed them how to open PDFs in the browser and print from there.",
        "note": "Workaround: open PDFs in the browser and print from there.",
        "back": "Adobe Reader still will not print",
        "back_body": "I opened another PDF in Reader and it will not print either. Please fix it properly. - %s",
    },
    "reader_reinstall":
    {
        "for": ["adobe"],
        "kind": "heavy",
        "label": "REINSTALL READER",
        "mult": 3.0,
        "xp": 3,
        "mood": -1,
        "text": "Uninstalled and reinstalled Adobe Reader. Printing works.",
        "note": "Uninstalled and reinstalled Adobe Reader.",
    },
}
const FIX_DONE_TEXT := {
    "spooler": "Print spooler restarted. Queued jobs are printing.", "password": "Password reset and account unlocked.",
    "clear_temp": "Cleared 41 GB of temp files. Disk space is back.", "reboot": "Rebooted. System is responding.",
    "av": "Scan finished. 407 threats removed (mostly cruise related).",
    "restore": "Restored from the last good backup.",
    "adobe": "Adobe Reader repaired. Printing works again.",
    "shadow": "Recovered most files from the shadow copies.", "pay": "Ransom paid. The files are decrypted.",
    "save": "The user saved their work.",
}
const SLA_SECS := {1: 120.0, 2: 200.0, 3: 300.0, 4: 480.0}
# gentle first days: random tickets allowed per day in the tech campaign (day -> cap)
const DAY_CAPS := {1: 1, 2: 3, 3: 5}
const OS_NAMES := ["Windows 7 Pro", "Windows 7 Pro", "Windows 8.1", "Windows XP SP3"]
const USERS := ["front desk", "office manager", "owner", "bookkeeper", "intern"]
const DESK_NAMES := {
    1: "Main floor desk 1", 2: "Main floor desk 2 (Maya)", 3: "Main floor desk 3", 4: "Cubicle 4", 5: "Cubicle 5",
    6: "Office 1", 7: "Office 2", 8: "The copier",
}

var tickets: Array = []
var emails: Array = []
var texts: Array = []  # {from, body, unread}: SMS on the cell phone
var endpoints: Array = []  # {name, client, user, os, problem}
var score := 0
var closed_ok := 0
var breached := 0
var reopened := 0
var backups: Array = []  # per client: {ok, good_day, checked_day}
var project := {}  # the install project in progress (see start_project)
var enabled := true  # false = free play / film mode: no random tickets, texts or SLA pressure
var pace := 1.0  # campaign difficulty: ticket spawn interval multiplier
var spawned_today := 0  # random tickets so far today (see DAY_CAPS)

var _next_id := 10421
var _next_mail := 1
var _spawn_t := 20.0
var _down := {}  # desk -> seconds without network
var _up := {}  # desk -> seconds with network
var _internal := {}  # desk -> ticket id of the open internal ticket


func _ready() -> void:
    randomize()
    reset()


func reset() -> void:
    tickets.clear()
    emails.clear()
    texts.clear()
    endpoints.clear()
    score = 0
    closed_ok = 0
    breached = 0
    reopened = 0
    pace = 1.0
    _next_id = 10421
    _next_mail = 1
    _spawn_t = 20.0
    _down.clear()
    _up.clear()
    _internal.clear()
    _later.clear()
    backups.clear()
    project = {}
    for c in CLIENTS.size():
        backups.append({"ok": true, "good_day": 0, "checked_day": -1})
    for c in CLIENTS.size():
        for n in 3:
            endpoints.append(_endpoint(c, "PC-%02d" % (n + 1), OS_NAMES[randi() % OS_NAMES.size()]))
        endpoints.append(_endpoint(c, "SRV-01", "Server 2008 R2"))
    _mail(
        COMPANY + " HR", "Welcome to the service desk",
        "Welcome aboard! Open the PSA to see the ticket board, use the RMM to fix client PCs, and watch "
        + "your inbox. If your own computer says it has no network, check the closet. - HR", 0
    )
    send_text("Dispatch", "Welcome! Press P for your phone. I will text you about urgent tickets.")


func _endpoint(client: int, suffix: String, os_name: String) -> Dictionary:
    return {
        "name": "%s-%s" % [CLIENTS[client].short, suffix], "client": client,
        "user": USERS[randi() % USERS.size()] if not suffix.begins_with("SRV") else "server", "os": os_name, "problem": "",
        "unsaved": false, "asked": false,
    }


func endpoint(name: String) -> Dictionary:
    for ep in endpoints:
        if ep.name == name:
            return ep
    return {}


func ticket(id: int) -> Dictionary:
    for t in tickets:
        if t.id == id:
            return t
    return {}


func open_tickets() -> Array:
    var out := []
    for t in tickets:
        if t.status != "Closed":
            out.append(t)
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pri < b.pri or (a.pri == b.pri and a.sla_left < b.sla_left))
    return out


func unread_texts() -> int:
    var n := 0
    for m in texts:
        if m.unread:
            n += 1
    return n


func send_text(from_name: String, body: String) -> void:
    var m := {"from": from_name, "body": body, "unread": true}
    texts.push_front(m)
    text_received.emit(m)
    changed.emit()


func unread() -> int:
    var n := 0
    for m in emails:
        if m.unread:
            n += 1
    return n


func client_text(t: Dictionary) -> String:
    return COMPANY + " (internal)" if t.client < 0 else CLIENTS[t.client].name


# ---- tickets -----------------------------------------------------------------
func create_ticket(client: int, problem: int, source: String) -> Dictionary:
    return create_problem(client, PROBLEMS[problem], source)


func create_problem(client: int, prob: Dictionary, source: String) -> Dictionary:
    var contact: String = CLIENTS[client].contact
    var eps := []
    for ep in endpoints:
        var is_server: bool = ep.name.contains("SRV")
        if ep.client == client and ep.problem == "" and is_server == prob.get("server", false):
            eps.append(ep)
    if eps.is_empty():
        return {}
    var picked: Dictionary = eps[randi() % eps.size()]
    picked.problem = prob.fix
    picked["unsaved"] = randf() < 0.65  # somebody is working on it: documents are open
    picked["asked"] = false
    var t := {
        "id": _next_id, "client": client, "contact": contact, "summary": prob.summary, "pri": prob.pri,
        "body": prob.body % contact.split(" ")[0], "status": "New", "sla_left": SLA_SECS[prob.pri],
        "sla_total": SLA_SECS[prob.pri], "endpoint": picked.name, "fix": prob.fix, "fix_done": false,
        "notes": ["Ticket created by " + source + "."], "internal": false, "special": prob.get("special", ""), "desk": 0, "source": source, "breached": false,
    }
    _next_id += 1
    tickets.append(t)
    _mail(contact + " <" + CLIENTS[client].mail + ">", t.summary, t.body, t.id)
    ticket_added.emit(t)
    if t.pri <= 2:
        send_text("Dispatch", "P%d #%d %s - %s" % [t.pri, t.id, t.summary, CLIENTS[client].name])
    changed.emit()
    return t


func day_cap() -> int:
    if Campaign.active and Campaign.mode == "tech":
        return int(DAY_CAPS.get(Campaign.day, 99))
    return 99


func _random_ticket(source: String) -> Dictionary:
    if spawned_today >= day_cap():
        return {}
    for tries in 6:
        var t := create_ticket(Sales.pick_client(), randi() % PROBLEMS.size(), source)
        if not t.is_empty():
            spawned_today += 1
            return t
    return {}


# answering the phone at a desk: a client is on the line with a problem
func phone_call(_desk: int) -> void:
    Social.note_call_answered()
    if not Game.title_mode and enabled:
        _random_ticket("phone call")


func create_internal(desk: int, summary: String, body: String) -> void:
    var t := {
        "id": _next_id, "client": -1, "contact": DESK_NAMES.get(desk, "Staff"), "summary": summary, "pri": 2, "body": body,
        "status": "New", "sla_left": SLA_SECS[2], "sla_total": SLA_SECS[2], "endpoint": "", "fix": "network",
        "fix_done": false, "internal": true, "desk": desk, "source": "monitoring",
        "notes": ["Detected automatically."] + (["Tip: check patch panel port %d in the closet." % desk] if Campaign.active and Skills.level("networking") >= 2 else []),
        "breached": false,
    }
    _next_id += 1
    tickets.append(t)
    _internal[desk] = t.id
    Social.note_outage(desk)
    _mail("Staff - " + str(DESK_NAMES.get(desk, "?")), summary, body, t.id)
    ticket_added.emit(t)
    changed.emit()


func set_status(id: int, status: String) -> void:
    var t := ticket(id)
    if not t.is_empty() and t.status != "Closed":
        t.status = status
        t.notes.append("Status: " + status + ".")
        changed.emit()


func add_note(id: int, text: String) -> void:
    var t := ticket(id)
    if not t.is_empty():
        t.notes.append(text)
        changed.emit()


# close a ticket: points if it was really fixed, otherwise it comes back with an angry email
func close_ticket(id: int) -> String:
    var t := ticket(id)
    if t.is_empty() or t.status == "Closed":
        return ""
    if not t.fix_done:
        t.status = "In Progress"
        t.sla_left = maxf(t.sla_left, t.sla_total * 0.4)
        t.notes.append("Client reopened the ticket: still broken!")
        score -= 3
        reopened += 1
        Growth.note_escalation(t)
        Social.note_reopen()
        if not t.internal:
            Sales.adjust(int(t.client), -6)
        if not t.internal:
            _mail(CLIENTS[t.client].contact + " <" + CLIENTS[t.client].mail + ">", "RE: " + t.summary, "It is STILL not fixed. Why did you close this? Please try again.", t.id)
        changed.emit()
        return "REOPENED - NOT FIXED YET"
    t.status = "Closed"
    t.notes.append("Ticket closed.")
    if t.internal:
        _internal.erase(t.desk)
    var points := 10 if not t.breached else 4
    score += points
    closed_ok += 1
    Career.note_ticket(str(t.fix))
    Skills.add_xp("networking" if t.internal else "people", 2)
    Social.note_ticket_closed(t)
    if not t.internal:
        Sales.adjust(int(t.client), 3 if t.breached else 5)
    changed.emit()
    return "CLOSED +%d" % points


# ---- the RMM -----------------------------------------------------------------
func rmm_action(name: String, action: String) -> String:
    var ep := endpoint(name)
    if ep.is_empty():
        return "NO SUCH ENDPOINT"
    var special := _rmm_special(ep, action)
    if special != "":
        return special
    if ep.problem == action and not action.begins_with("onsite_"):
        ep.problem = ""
        for t in tickets:
            if t.endpoint == name and t.status != "Closed" and t.fix == action:
                t.fix_done = true
                t.notes.append("Remote fix: " + FIXES[action].capitalize() + ".")
        Skills.add_xp(str(Skills.FIX_XP.get(action, "servers")), 4)
        changed.emit()
        return str(FIX_DONE_TEXT[action])
    if action == "reboot":
        return _reboot_other(ep)
    if ALT_DEFS.has(action):
        return _alt_fix(ep, action)
    return "DONE. NOTHING CHANGED."


# ---- other valid fixes (ALT_DEFS) -------------------------------------------------
var alt_roll := -1.0  # tests: a fixed roll for "does the workaround come back?"
var _later: Array = []  # follow-ups outside a campaign: {left, item}


func alt_unlocked(d: Dictionary) -> bool:
    var sk := str(d.get("skill", ""))
    if sk == "":
        return true
    if not Campaign.active:
        return false
    var lv: int = Skills.ps_level if sk == "powershell" else Skills.level(sk)
    return lv >= int(d.lvl)


# the other fixes on offer for this machine's problem
func alts_for(ep: Dictionary) -> Array:
    var out := []
    if str(ep.get("problem", "")) in ["", "restore", "project"]:
        return out
    var is_server: bool = ep.user == "server"
    for id in ALT_DEFS:
        var d: Dictionary = ALT_DEFS[id]
        if d["for"].has(str(ep.problem)) and bool(d.get("server", false)) == is_server:
            if alt_unlocked(d):
                out.append(id)
    return out


func alt_label(ep: Dictionary, id: String) -> String:
    var d: Dictionary = ALT_DEFS[id]
    var unsaved: bool = bool(ep.get("unsaved", false)) and not bool(ep.get("asked", false))
    var up: bool = bool(d.get("loses", false)) and unsaved and ep.problem != "reboot"
    if up and Skills.sees_open_docs():
        return str(d.label) + " !"
    return str(d.label)


func _alt_fix(ep: Dictionary, action: String) -> String:
    if not alts_for(ep).has(action):
        return "DONE. NOTHING CHANGED."
    var d: Dictionary = ALT_DEFS[action]
    var client := int(ep.client)
    var prob := str(ep.problem)
    var lost: bool = (
        bool(d.get("loses", false))
        and prob != "reboot"
        and bool(ep.get("unsaved", false))
        and not bool(ep.get("asked", false))
    )
    var tk := {}
    for t in tickets:
        if t.endpoint == str(ep.name) and t.status != "Closed" and t.fix == prob:
            tk = t
            t.fix_done = true
            t["method"] = str(d.kind)
            t.notes.append(str(d.note) + (" The user lost unsaved work." if lost else ""))
    if int(d.get("mood", 0)) != 0:
        Sales.adjust(client, int(d.mood))
    score += int(d.get("score", 0))
    Skills.add_xp(str(Skills.FIX_XP.get(prob, "servers")), int(d.xp))
    ep.problem = ""
    var text := str(d.text)
    if lost:
        _lose_work(ep, int(tk.get("id", 0)))
        text += " THE USER LOST UNSAVED WORK!"
    ep.unsaved = false
    ep.asked = false
    var roll := alt_roll if alt_roll >= 0.0 else randf()
    if roll < float(d.get("ret", 0.0)) and not tk.is_empty():
        _queue_return(tk, d, prob)
    changed.emit()
    return text


# a restart that cost somebody their unsaved work
func _lose_work(ep: Dictionary, ticket_id: int) -> void:
    var client := int(ep.client)
    Sales.adjust(client, -6)
    score -= 3
    var contact: Dictionary = CLIENTS[client]
    _mail(
        str(contact.contact) + " <" + str(contact.mail) + ">",
        "I LOST MY WORK!",
        (
            "You restarted my computer while I had a report open and I never saved it. "
            + "Hours of work, gone. A warning would have taken ten seconds. - "
            + str(contact.contact).split(" ")[0]
        ),
        ticket_id
    )


# a workaround that did not hold: the same problem is back in 1-2 days (tech campaign) or soon
func _queue_return(t: Dictionary, d: Dictionary, prob: String) -> void:
    var item := {
        "client": int(t.client),
        "summary": str(d.back),
        "pri": int(t.pri),
        "body": str(d.back_body),
        "fix": prob,
        "server": str(t.endpoint).contains("SRV"),
        "esc": true,
    }
    t.notes.append("Only a workaround: this will probably come back.")
    if Campaign.active and Campaign.mode == "tech":
        item["days"] = 1 + randi() % 2
        Story.queue_followup(item)
    else:
        _later.append({"left": randf_range(150.0, 300.0), "item": item})


# the follow-up ticket for a workaround that came back (also used by Story's follow-ups)
func spawn_return(item: Dictionary) -> void:
    var prob := {
        "summary": item.summary,
        "fix": item.get("fix", "reboot"),
        "pri": item.pri,
        "body": item.body,
        "server": item.get("server", false),
    }
    var t := create_problem(int(item.client), prob, "email")
    if not t.is_empty() and bool(item.get("esc", false)):
        Growth.note_escalation(t)


# actions with their own rules: asking the user to save, and the ransomware options
func _rmm_special(ep: Dictionary, action: String) -> String:
    if action == "save":
        return _ask_save(ep)
    if ep.problem == "restore":
        if action == "pay":
            return _ransom_pay(ep)
        if action == "shadow":
            return _ransom_shadow(ep)
        if action == "restore":
            return _restore(ep)
    return ""


# what the REBOOT button says: whether the user could lose work
func reboot_label(ep: Dictionary) -> String:
    if ep.problem in ["reboot", "restore"] or ep.user == "server":
        return str(FIXES["reboot"])
    if bool(ep.get("asked", false)):
        return "REBOOT (USER WARNED)"
    if Skills.sees_open_docs():
        return "REBOOT (OPEN DOCS!)" if bool(ep.get("unsaved", false)) else "REBOOT (NOTHING OPEN)"
    return "REBOOT (ASK FIRST?)"


# ask the person at the machine to save before you touch it
func _ask_save(ep: Dictionary) -> String:
    ep["asked"] = true
    Skills.add_xp("people", 2)
    for t in tickets:
        if t.endpoint == str(ep.name) and t.status != "Closed":
            t.notes.append("Asked the user to save their work first.")
    changed.emit()
    if bool(ep.get("unsaved", false)):
        return "THE USER SAVED THEIR WORK. THANKS FOR ASKING."
    return "THEY HAD NOTHING OPEN. THANKS FOR ASKING."


# a reboot that is not the ticket's own fix: it may still clear the problem (ALT_FIXES) but the
# user is interrupted, and anyone with unsaved work who was not warned loses it
func _reboot_other(ep: Dictionary) -> String:
    if not ep.has("unsaved"):
        ep["unsaved"] = randf() < 0.5
    var client := int(ep.client)
    var lost: bool = bool(ep.unsaved) and not bool(ep.get("asked", false))
    var alt: bool = ALT_FIXES.get(str(ep.problem), []).has("reboot")
    var ticket_id := 0
    for t in tickets:
        if t.endpoint == str(ep.name) and t.status != "Closed":
            ticket_id = int(t.id)
            t.notes.append("Rebooted the PC" + (" (the user lost unsaved work)." if lost else "."))
            if alt and t.fix == ep.problem:
                t.fix_done = true
    Sales.adjust(client, -2)  # any needless reboot interrupts people
    var text := "REBOOTED. NOTHING CHANGED."
    if alt:
        Skills.add_xp(str(Skills.FIX_XP.get(str(ep.problem), "servers")), 2)
        ep.problem = ""
        text = "REBOOTED. FIXED, BUT RESTARTING THE SERVICE WOULD HAVE BEEN QUIETER."
    if lost:
        Sales.adjust(client, -6)
        score -= 3
        var contact: Dictionary = CLIENTS[client]
        _mail(str(contact.contact) + " <" + str(contact.mail) + ">", "I LOST MY WORK!",
            "You restarted my computer while I had a report open and I never saved it. "
            + "Hours of work, gone. A warning would have taken ten seconds. - "
            + str(contact.contact).split(" ")[0], ticket_id)
        text += " THE USER LOST UNSAVED WORK!"
    ep.unsaved = false
    ep.asked = false
    changed.emit()
    return text


# fix every endpoint of one client (or all clients) that has this problem: the PowerShell scripts
func rmm_bulk(client: int, action: String, all_clients: bool) -> int:
    var done := 0
    for ep in endpoints:
        var scriptable: bool = action != "restore" and action != "project"
        if ep.problem == action and (all_clients or ep.client == client) and scriptable:
            rmm_action(ep.name, action)
            done += 1
    return done


# ---- backups -------------------------------------------------------------------
func backup_check(client: int) -> Dictionary:
    var b: Dictionary = backups[client]
    b.checked_day = Campaign.day
    Skills.add_xp("security", 1)
    changed.emit()
    return b


func backup_rerun(client: int) -> void:
    var b: Dictionary = backups[client]
    if not b.ok:
        b.ok = true
        b.good_day = Campaign.day
        Skills.add_xp("security", 6)
        changed.emit()


func break_backup(client: int) -> void:
    var b: Dictionary = backups[client]
    if b.ok:
        b.ok = false
        b.good_day = Campaign.day - 1


# start of a campaign day: working jobs refresh, a few quietly fail overnight
func new_day(day: int) -> void:
    spawned_today = 0
    if Campaign.active and Campaign.mode == "tech" and day == 1:
        _spawn_t = 75.0  # time to look around before the first ticket
    for c in backups.size():
        var b: Dictionary = backups[c]
        if not b.ok:
            continue
        if day >= 2 and c != Story.RANSOM_CLIENT and randf() < 0.08 and Campaign.active:
            b.ok = false
            b.good_day = day - 1
        else:
            b.good_day = day


func mmss(secs: float) -> String:
    var whole := maxi(0, int(secs))
    return "%d:%02d" % [whole / 60, whole % 60]


func project_busy() -> bool:
    return not project.is_empty() and not bool(project.done)


# ---- the desktop install project ------------------------------------------------
func start_project(ticket_id: int) -> void:
    project = {
        "ticket": ticket_id, "client": int(ticket(ticket_id).get("client", 0)), "found": {}, "selected": {}, "migrated": {}, "backup": false, "verified": false,
        "done": false, "result": {},
    }
    for it in INSTALL_ITEMS:
        project.found[it.id] = it.hidden == ""
    changed.emit()


func project_secs(action: String) -> float:
    var base := {"scan": 4.0, "deep": 8.0, "backup": 6.0, "verify": 3.0}
    var secs := 0.0
    if action == "migrate":
        for it in INSTALL_ITEMS:
            if project.selected.get(it.id, false) and not project.migrated.get(it.id, false):
                secs += it.secs
    else:
        secs = float(base.get(action, 0.0))
    # PowerShell makes the copy scripts faster; 0 outside a campaign = instant
    var scale := Skills.fix_secs() / 6.0
    return secs * scale


func project_scan(deep: bool) -> void:
    for it in INSTALL_ITEMS:
        if deep and (it.hidden == "deep" or it.hidden == "both"):
            project.found[it.id] = true
    changed.emit()


func project_ask() -> void:
    for it in INSTALL_ITEMS:
        if it.hidden == "ask" or it.hidden == "both":
            project.found[it.id] = true
    changed.emit()


func project_backup() -> void:
    project.backup = true
    changed.emit()


func project_toggle(item_id: String) -> void:
    if project.found.get(item_id, false) and not project.migrated.get(item_id, false):
        project.selected[item_id] = not project.selected.get(item_id, false)
        changed.emit()


func project_select_all() -> void:
    for it in INSTALL_ITEMS:
        if project.found.get(it.id, false) and not project.migrated.get(it.id, false):
            project.selected[it.id] = true
    changed.emit()


func project_migrate() -> void:
    for it in INSTALL_ITEMS:
        if project.selected.get(it.id, false):
            project.migrated[it.id] = true
    changed.emit()


# checking with the user reveals everything that is still missing; returns those names
func project_verify() -> Array:
    var missing := []
    project.verified = true
    for it in INSTALL_ITEMS:
        if not project.migrated.get(it.id, false):
            project.found[it.id] = true
            missing.append(it.name)
    changed.emit()
    return missing


# hand the PC over: the old one is wiped, so what was not copied is gone (unless backed up)
func project_handover() -> Dictionary:
    if project.is_empty() or project.done:
        return project.get("result", {})
    var pts := 0
    var lost := []
    for it in INSTALL_ITEMS:
        if project.migrated.get(it.id, false):
            pts += 20 if it.key else 5
        elif it.key:
            lost.append(it.name)
    pts += 10 if project.backup else 0
    pts += 5 if project.verified else 0
    var t := ticket(int(project.ticket))
    if not t.is_empty() and t.breached:
        pts -= 10
    pts = clampi(pts, 0, 100)
    var grade := "D"
    for entry in [[92, "S"], [80, "A"], [65, "B"], [45, "C"]]:
        if pts >= entry[0]:
            grade = entry[1]
            break
    var rep_delta: int = {"S": 5, "A": 3, "B": 1, "C": -2, "D": -5}[grade]
    var outcome := "ok"
    if not lost.is_empty():
        outcome = "restored" if project.backup else "lost"
        rep_delta -= 3 if project.backup else 8
    score += int((pts - 50) / 2.5) - (0 if outcome != "lost" else 15)
    Campaign.adjust_rep(rep_delta)
    Skills.add_xp("servers", 10)
    project.done = true
    project.result = {"pts": pts, "grade": grade, "lost": lost, "outcome": outcome}
    Story.flags["install"] = outcome
    if not t.is_empty():
        t.fix_done = true
        t.notes.append("Handed over: grade %s (%d%%)." % [grade, pts])
        var endpoint_state := endpoint(str(t.endpoint))
        if not endpoint_state.is_empty():
            endpoint_state.problem = ""
    var who: String = CLIENTS[int(project.client)].contact
    var address: String = who + " <" + CLIENTS[int(project.client)].mail + ">"
    var text := "Everything is just where I left it. Great job! - " + who
    if outcome == "lost":
        text = "WHERE IS MY XRAY SOFTWARE? Patients are waiting and the old computer is wiped!! - " + who
    elif outcome == "restored":
        text = "We were missing the xray software, but you had a backup. Phew. - " + who
    elif grade in ["C", "D"]:
        text = "It works, but a lot of little things are missing. Please be more careful. - " + who
    _mail(address, "RE: " + INSTALL.summary, text, 0)
    changed.emit()
    return project.result


func mail(from_name: String, subject: String, body: String) -> void:
    _mail(from_name, subject, body, 0)
    changed.emit()


# ransomware: with a good backup it is a save, without one the data is gone
func _restore(ep: Dictionary) -> String:
    var contact: String = CLIENTS[ep.client].contact
    var address: String = contact + " <" + CLIENTS[ep.client].mail + ">"
    ep.problem = ""
    var good: bool = backups[ep.client].ok
    for t in tickets:
        if t.endpoint == ep.name and t.status != "Closed" and t.fix == "restore":
            t.fix_done = true
            t.notes.append("Restored from backup. No data lost." if good else "NO USABLE BACKUP. Data lost.")
    if good:
        score += 15
        Campaign.adjust_rep(5)
        Skills.add_xp("security", 15)
        _mail(address, "RE: " + RANSOM.summary, "Everything is back. You saved the whole firm. Thank you!!! - " + contact, 0)
        Story.flags["ransom"] = "saved"
    else:
        score -= 30
        Campaign.adjust_rep(-15)
        _mail(address, "RE: " + RANSOM.summary, "You are saying there is NO BACKUP? Years of case files are gone. "
            + "We are reviewing our contract. - " + contact, 0)
        send_text("Boss", "No backup?! We need to talk about backups. Tomorrow. My office.")
        Story.flags["ransom"] = "lost"
    changed.emit()
    return "RESTORED. NO DATA LOST." if good else "NO BACKUP FOUND. DATA LOST."


# CryptoLocker (2013): with no backup you still have options, none of them good
func _ransom_close(ep: Dictionary, note: String) -> void:
    ep.problem = ""
    for t in tickets:
        if t.endpoint == ep.name and t.status != "Closed" and t.fix == "restore":
            t.fix_done = true
            t.notes.append(note)


func _ransom_lost(ep: Dictionary, note: String) -> String:
    var contact: String = CLIENTS[ep.client].contact
    _ransom_close(ep, note)
    score -= 30
    Campaign.adjust_rep(-15)
    _mail(CLIENTS[ep.client].contact + " <" + CLIENTS[ep.client].mail + ">", "RE: " + RANSOM.summary, "Years of files are gone and nothing worked. We are reviewing our contract. - " + contact, 0)
    send_text("Boss", "The files are gone and the backup was not there. We need to talk.")
    Story.flags["ransom"] = "lost"
    changed.emit()
    return "NOTHING WORKED. DATA LOST."


func _ransom_pay(ep: Dictionary) -> String:
    var contact: String = CLIENTS[ep.client].contact
    if randf() < 0.7:
        _ransom_close(ep, "Ransom paid in Bitcoin. Files decrypted.")
        score -= 5
        Campaign.adjust_rep(-2)
        Story.flags["ransom"] = "paid"
        _mail(CLIENTS[ep.client].contact + " <" + CLIENTS[ep.client].mail + ">", "RE: " + RANSOM.summary, "The files are back, but we paid criminals and the whole firm is shaken. "
        + "Make sure it never happens again. - " + contact, 0)
        changed.emit()
        return "RANSOM PAID. FILES DECRYPTED."
    return _ransom_lost(ep, "The criminals took the money and never sent the key.")


func _ransom_shadow(ep: Dictionary) -> String:
    if randf() < 0.4:
        var contact: String = CLIENTS[ep.client].contact
        _ransom_close(ep, "Recovered most files from shadow copies. Some are gone.")
        score -= 8
        Campaign.adjust_rep(-3)
        Story.flags["ransom"] = "partial"
        _mail(CLIENTS[ep.client].contact + " <" + CLIENTS[ep.client].mail + ">", "RE: " + RANSOM.summary, "Most of our files are back, a few are gone for good. Thank you for trying. - " + contact, 0)
        changed.emit()
        return "SHADOW COPIES RECOVERED MOST FILES."
    return "NO SHADOW COPIES LEFT. TRY SOMETHING ELSE."


# ---- clock -------------------------------------------------------------------
func _process(delta: float) -> void:
    if Game.title_mode or not enabled:
        return
    var dt := delta * World.time_scale
    if dt <= 0.0:
        return
    _spawn_t -= dt
    if _spawn_t <= 0.0:
        _spawn_t = randf_range(45.0, 90.0) * pace / maxf(0.5, Sales.workload()) / Owner.issue_mult()
        if open_tickets().size() < 6 and World.clock < World.DAY_END:
            _random_ticket("email")
    for i in range(_later.size() - 1, -1, -1):
        _later[i].left -= dt
        if _later[i].left <= 0.0:
            var item: Dictionary = _later[i].item
            _later.remove_at(i)
            spawn_return(item)
    for t in tickets:
        if t.status != "Closed" and t.status != "Waiting":
            t.sla_left -= dt * Skills.sla_pace()
            if t.sla_left <= 0.0 and not t.breached:
                t.breached = true
                breached += 1
                score -= 5
                Growth.note_escalation(t)
                if not t.internal:
                    Sales.adjust(int(t.client), -8)
                _mail("Pixel IT Partners - Manager", "SLA breached on #%d" % t.id, "Ticket #%d (%s) blew its SLA. Please look at it." % [t.id, t.summary], t.id)
                send_text("Boss", "#%d blew its SLA: -5 score, client mood -8. Why?" % t.id)
    _watch_desks(dt)


# our own network trouble becomes tickets; they resolve themselves once the desk is back online
func _watch_desks(dt: float) -> void:
    for d in range(1, 9):
        var state := Net.desk_state(d)
        if state != "ok":
            _down[d] = float(_down.get(d, 0.0)) + dt
            _up[d] = 0.0
            if _down[d] >= 8.0 and not _internal.has(d):
                var what := "no network cable" if state == "no_link" else "no internet"
                create_internal(d, "%s: %s" % [DESK_NAMES[d], what], "Help! The computer here has " + what + ". Nothing loads. Can someone check the closet? - Staff")
        else:
            _down[d] = 0.0
            _up[d] = float(_up.get(d, 0.0)) + dt
            if _internal.has(d) and _up[d] >= 3.0:
                var t := ticket(_internal[d])
                if not t.is_empty() and not t.fix_done and t.status != "Closed":
                    t.fix_done = true
                    t.status = "Resolved"
                    t.notes.append("Network restored.")
                    Social.note_outage_fixed(d)
                    changed.emit()


func _mail(from_name: String, subject: String, body: String, ticket_id: int) -> void:
    emails.push_front({"id": _next_mail, "from": from_name, "subject": subject, "body": body, "unread": true, "ticket": ticket_id})
    _next_mail += 1
''')

write("scripts/computer.gd", '''extends CanvasLayer
# gdlint: ignore=max-line-length
# The computer: interacting with a monitor takes over the screen (the office fades into the background
# above it) and shows a 2013 desktop with three apps drawn in the pixel font:
#   OUTLOOKISH 2013 (mail), CONNECTWHY PSA (the ticket board), LABRAT RMM (remote monitoring).
# Computer.open(desk): desk 1-8 decides whether this PC has network (Net.desk_state).
# Mouse to click; arrows / Enter / Esc also work. Everything is drawn in code;
# clickable regions are collected while drawing (_hits).

const PixelFont := preload("res://scripts/pixelfont.gd")
const TB := 11.0  # taskbar height
const TXT := Color("20242c")
const WHITE := Color("ffffff")
const BTN := Color("d9dde6")
const BTN_HI := Color("f4f6fa")
const BTN_SH := Color("8a93a4")
const TASK := Color("1c3b63")
const OUTLOOK := Color("2b579a")
const PSA_BLUE := Color("1f4e8c")
const RMM_GREY := Color("3b424d")
# RMM session buttons for the other fixes: quick workaround, heavy fix, clever fix
const ALT_TINTS := {"quick": Color("f2e2a0"), "heavy": Color("e9b1a8"), "clever": Color("a9e0b0")}
const ORANGE := Color("e07b22")
const GREEN := Color("2fa84f")
const RED := Color("d23c3c")
const AMBER := Color("e0a030")
const NOTES := [
    "Called the client, left a voicemail.", "Checked in with the user, working on it.", "Escalated to Tier 2.",
    "Gathered logs from the machine.", "Client says it is still broken.",
]

var is_open := false
var desk := 0
var app := "desktop"
var mail_sel := -1
var mail_top := 0  # first mail shown in the list (it scrolls with the selection)
var mail_view := false
var psa_sel := 0
var psa_detail := false
var close_ask := false  # CLOSE pressed on an unfixed ticket: waiting for YES / NO
var rmm_open := {}
var rmm_scroll := 0  # pixels the endpoint tree is scrolled
var site_info := {}  # a client's computer (onsite): their desktop, not yours
var site_view := "desktop"
var rmm_sel := ""
var rmm_detail := false
var rmm_session := false
var rmm_msg := ""
var rmm_tab := "endpoints"
var board_tab := "books"
var lync_sel := ""
var nerds_tab := "forum"
var learn_lesson := -1
var learn_q := 0
var learn_right := 0
var learn_pick := -1
var learn_done := false
var learn_opts: Array = []

var _canvas: Node2D
var _hits: Array = []
var _mouse := Vector2.ZERO
var _fade := 0.0
var _job := {}
var _area := Rect2()
var _toast := ""
var _toast_t := 0.0
var _menu := false
var _tick := 0.0


func _ready() -> void:
    layer = 60
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)
    Msp.changed.connect(_refresh)
    Lync.changed.connect(_refresh)
    Nerds.changed.connect(_refresh)


func open_site(info: Dictionary) -> void:
    site_info = info
    open(0)
    app = "site"
    site_view = "desktop"


func open(from_desk: int) -> void:
    desk = from_desk
    app = "desktop"
    mail_view = false
    psa_detail = false
    close_ask = false
    rmm_detail = false
    rmm_session = false
    _menu = false
    _toast = ""  # the toast timer only runs while open, so drop one left from the last session
    _toast_t = 0.0
    is_open = true
    Game.ui_open = true
    _canvas.visible = true
    _mouse = get_viewport().get_mouse_position()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    create_tween().tween_method(_set_fade, _fade, 1.0, 0.2)


func close() -> void:
    is_open = false
    Game.ui_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var tween := create_tween()
    tween.tween_method(_set_fade, _fade, 0.0, 0.15)
    tween.tween_callback(func() -> void: _canvas.visible = is_open)


func _set_fade(value: float) -> void:
    _fade = value
    Game.ui_shift = value
    _canvas.modulate.a = value


func _refresh() -> void:
    if is_open:
        _canvas.queue_redraw()


func _process(delta: float) -> void:
    if not is_open:
        # an RMM fix keeps running with the computer closed (the result shows when you come back);
        # anything else (playbook step, install project) is dropped
        if _job.is_empty():
            return
        if not str(_job.kind) in ["fix", "script", "scriptall"]:
            _job = {}
            return
        _job.left -= delta
        if _job.left <= 0.0:
            _finish_job()
        return
    _tick += delta
    _toast_t = maxf(0.0, _toast_t - delta)
    if not _job.is_empty():
        _job.left -= delta
        _canvas.queue_redraw()
        if _job.left <= 0.0:
            _finish_job()
    if _tick > 0.4:
        _tick = 0.0
        _canvas.queue_redraw()


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventMouseMotion:
        _mouse = get_viewport().get_mouse_position()
        _canvas.queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse = get_viewport().get_mouse_position()
        click(_mouse)
    elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
        scroll_list(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                escape()
            KEY_UP:
                move(-1)
            KEY_DOWN:
                move(1)
            KEY_ENTER, KEY_KP_ENTER:
                enter()
    else:
        return
    get_viewport().set_input_as_handled()


# ---- input actions (also used by the tests) ----------------------------------
func click(at: Vector2) -> void:
    for i in range(_hits.size() - 1, -1, -1):
        var h: Dictionary = _hits[i]
        if h.r.has_point(at):
            activate(h.id)
            return
    _menu = false
    _canvas.queue_redraw()


# Esc steps back out of a sub-view (open menu, mail, ticket, session, lesson...) one level, and otherwise
# closes the computer in a single press (it used to go app -> desktop -> closed)
func escape() -> void:
    var nested := (
        _menu
        or (app == "mail" and mail_view)
        or (app == "psa" and psa_detail)
        or (app == "rmm" and (rmm_session or rmm_detail))
        or (app == "learn" and learn_lesson >= 0)
        or (app == "lync" and lync_sel != "")
        or (app == "site" and site_view != "desktop")
    )
    if nested:
        back()
    else:
        close()


func back() -> void:
    if _menu:
        _menu = false
    elif app == "desktop":
        close()
    elif app == "mail" and mail_view:
        mail_view = false
    elif app == "psa" and psa_detail:
        if close_ask:
            close_ask = false
        else:
            psa_detail = false
    elif app == "rmm" and (rmm_session or rmm_detail):
        rmm_session = false
        rmm_detail = false
        _cancel_job()
    elif app == "learn" and learn_lesson >= 0:
        learn_lesson = -1
        learn_done = false
    elif app == "lync" and lync_sel != "":
        lync_sel = ""
    elif app == "site" and site_view != "desktop":
        site_view = "desktop"
    elif app == "site":
        close()
    else:
        app = "desktop"
    _canvas.queue_redraw()


func move(step: int) -> void:
    match app:
        "mail":
            mail_sel = clampi(mail_sel + step, 0, maxi(0, Msp.emails.size() - 1))
            if mail_sel < Msp.emails.size() and _area.size.x >= 250.0:
                Msp.emails[mail_sel].unread = false  # the reading pane shows it: it counts as read
        "psa":
            var list := Msp.open_tickets()
            if not list.is_empty():
                psa_sel = list[clampi(_psa_index() + step, 0, list.size() - 1)].id
        "rmm":
            scroll_list(step)
    _canvas.queue_redraw()


# the RMM endpoint tree scrolls three rows at a time
func scroll_list(step: int) -> void:
    if app == "rmm" and not rmm_session and rmm_tab == "endpoints":
        rmm_scroll = maxi(0, rmm_scroll + step * 24)
        _canvas.queue_redraw()


func _psa_index() -> int:
    var list := Msp.open_tickets()
    for i in list.size():
        if list[i].id == psa_sel:
            return i
    return 0


func enter() -> void:
    if app == "mail":
        if mail_sel < 0 and not Msp.emails.is_empty():
            mail_sel = 0  # Enter works from the first press: it opens the first mail
        if mail_sel >= 0:
            activate("mail:%d" % mail_sel)
    elif app == "psa" and not psa_detail and not Msp.open_tickets().is_empty():
        activate("tk:%d" % psa_sel)


func activate(id: String) -> void:
    _menu = false
    var parts := id.split(":")
    match parts[0]:
        "app":
            app = parts[1]
        "wall":
            Career.cycle_pick("wallpaper")
        "close_app":
            if app == "site":
                site_view = "desktop"
            else:
                app = "desktop"
        "site":
            _site_action(parts)
        "start":
            _menu = true
        "logoff":
            close()
        "mail":
            mail_sel = int(parts[1])
            Msp.emails[mail_sel].unread = false
            mail_view = true
        "mback":
            mail_view = false
        "reply", "delete":
            _mail_action(parts[0])
        "back", "tk", "take", "prog", "wait", "note", "close", "closeyes", "closeno", "onsite":
            _psa_action(parts)
        "rmm", "connect", "disc", "fix", "client", "rback", "script", "scriptall":
            _rmm_action(parts)
        "tab", "bkcheck", "bkrerun":
            _rmm_action(parts)
        "proj", "pitem":
            _proj_action(parts)
        "pb":
            _start_pb_job(int(parts[1]))
        "lesson", "ans", "qnext", "lback":
            _learn_action(parts)
        "btab":
            board_tab = parts[1]
        "lync":
            _lync_action(parts)
        "nerds":
            _nerds_action(parts)
    _canvas.queue_redraw()


func _say(text: String) -> void:
    _toast = text
    _toast_t = 3.0


func _mail_action(kind: String) -> void:
    if mail_sel < 0 or mail_sel >= Msp.emails.size():
        return
    var m: Dictionary = Msp.emails[mail_sel]
    if kind == "reply":
        if m.ticket > 0:
            Msp.add_note(m.ticket, "Replied to the client by email.")
        _say("REPLY SENT")
    else:
        Msp.emails.remove_at(mail_sel)
        mail_sel = -1
        mail_view = false


func _psa_action(parts: PackedStringArray) -> void:
    var was_asking := close_ask
    close_ask = false
    match parts[0]:
        "back":
            psa_detail = false
        "tk":
            psa_sel = int(parts[1])
            psa_detail = true
        "take", "prog":
            Msp.set_status(psa_sel, "In Progress")
        "wait":
            Msp.set_status(psa_sel, "Waiting")
        "note":
            Msp.add_note(psa_sel, NOTES[randi() % NOTES.size()])
        "onsite":
            Onsite.offer(psa_sel)
        "close":
            var tk := Msp.ticket(psa_sel)
            if not tk.is_empty() and tk.status != "Closed" and not tk.fix_done and not was_asking:
                close_ask = true  # not fixed yet: closing it reopens it and costs mood
                return
            _say(Msp.close_ticket(psa_sel))
            if Msp.ticket(psa_sel).status == "Closed":
                psa_detail = false
        "closeyes":
            if was_asking:
                _say(Msp.close_ticket(psa_sel))
                if Msp.ticket(psa_sel).status == "Closed":
                    psa_detail = false


func _rmm_action(parts: PackedStringArray) -> void:
    match parts[0]:
        "rmm":
            rmm_sel = parts[1]
            rmm_detail = true
        "client":
            var key := int(parts[1])
            rmm_open[key] = not rmm_open.get(key, false)
        "connect":
            rmm_session = true
            rmm_msg = "CONNECTED TO " + rmm_sel
        "disc":
            rmm_session = false
            _cancel_job()
        "fix", "script", "scriptall":
            _start_job(parts[0], parts[1] if parts.size() > 1 else "")
        "rback":
            rmm_detail = false
        "tab":
            rmm_tab = parts[1]
        "bkcheck":
            var b := Msp.backup_check(int(parts[1]))
            _say("BACKUP OK" if b.ok else "BACKUP FAILED!")
        "bkrerun":
            Msp.backup_rerun(int(parts[1]))
            _say("BACKUP RERUN OK")


func _cancel_job() -> void:
    if not _job.is_empty():
        _say("JOB CANCELLED")
    _job = {}


func _start_job(kind: String, action: String) -> void:
    var ep := Msp.endpoint(rmm_sel)
    if ep.is_empty() or not _job.is_empty():
        return
    var act := action if kind == "fix" else str(ep.problem)
    if act == "":
        rmm_msg = "NOTHING TO FIX HERE."
        return
    var secs := Skills.fix_secs_for(act)
    if kind != "fix":
        secs += 1.0
    if act == "save" and Campaign.active:
        secs = 4.0  # the user takes a moment to close things properly
    elif act == "reboot" and Campaign.active and ep.problem != "reboot":
        secs += 4.0  # the machine has to come back up
    if secs <= 0.0:
        _job = {"kind": kind, "action": act, "left": 0.0, "total": 0.1}
        _finish_job()
        return
    _job = {"kind": kind, "action": act, "left": secs, "total": secs}
    rmm_msg = "RUNNING..."


func _proj_action(parts: PackedStringArray) -> void:
    if Msp.project.is_empty() or Msp.project.done:
        return
    match parts[0]:
        "pitem":
            Msp.project_toggle(parts[1])
        "proj":
            match parts[1]:
                "ask":
                    Msp.project_ask()
                    _say("DR. PATEL REMEMBERED MORE")
                "all":
                    Msp.project_select_all()
                "hand":
                    var res := Msp.project_handover()
                    _say("HANDED OVER: GRADE %s" % str(res.grade))
                _:
                    _start_proj_job(parts[1])


func _start_pb_job(index: int) -> void:
    if not _job.is_empty() or not Playbook.is_active():
        return
    var choice: Dictionary = Playbook.current_step().choices[index]
    if Playbook.lock_reason(choice) != "":
        return
    var secs := Playbook.choice_secs(choice)
    _job = {"kind": "pb", "action": str(index), "left": secs, "total": maxf(secs, 0.1)}
    if secs <= 0.0:
        _finish_job()


func _start_proj_job(action: String) -> void:
    if not _job.is_empty():
        return
    var secs := Msp.project_secs(action)
    _job = {"kind": "proj", "action": action, "left": secs, "total": maxf(secs, 0.1)}
    if secs <= 0.0:
        _finish_job()


func _finish_proj(action: String) -> void:
    match action:
        "scan":
            Msp.project_scan(false)
            _say("SCAN DONE")
        "deep":
            Msp.project_scan(true)
            _say("DEEP SCAN FOUND HIDDEN ITEMS")
        "backup":
            Msp.project_backup()
            _say("OLD PC BACKED UP")
        "migrate":
            Msp.project_migrate()
            _say("MIGRATION COMPLETE")
        "verify":
            var missing := Msp.project_verify()
            _say("ALL GOOD" if missing.is_empty() else "%d ITEMS MISSING!" % missing.size())


func _finish_job() -> void:
    var job := _job
    _job = {}
    if str(job.kind) == "proj":
        _finish_proj(str(job.action))
        return
    if str(job.kind) == "pb":
        Playbook.choose(int(job.action))
        _say(Playbook.last_note)
        return
    var ep := Msp.endpoint(rmm_sel)
    if ep.is_empty():
        return
    if not (job.action in ["restore", "pay", "shadow", "save"]) and str(Msp.ALT_DEFS.get(str(job.action), {}).get("kind", "")) != "heavy" and randf() < Skills.fail_chance() + Growth.fail_adjust(str(job.action)):
        rmm_msg = "TIRED: TYPED IT WRONG. TRY AGAIN." if Shift.is_tired() else "FIX DID NOT STICK. TRY AGAIN."
        return
    match str(job.kind):
        "fix":
            rmm_msg = Msp.rmm_action(rmm_sel, str(job.action))
        "script":
            rmm_msg = "SCRIPT FIXED %d PC(S)." % Msp.rmm_bulk(int(ep.client), str(job.action), false)
        _:
            rmm_msg = "SCRIPT FIXED %d PC(S) ACROSS CLIENTS." % Msp.rmm_bulk(int(ep.client), str(job.action), true)


func _learn_shuffle() -> void:
    var q: Array = Skills.LESSONS[learn_lesson].qs[learn_q]
    learn_opts = [q[1], q[2], q[3]]
    learn_opts.shuffle()
    learn_pick = -1


func _learn_action(parts: PackedStringArray) -> void:
    match parts[0]:
        "lesson":
            if int(parts[1]) == Skills.ps_level and not Skills.can_study():
                _say("ONE LESSON A DAY. COME BACK TOMORROW.")
                return
            learn_lesson = int(parts[1])
            learn_q = 0
            learn_right = 0
            learn_done = false
            _learn_shuffle()
        "ans":
            if learn_pick < 0:
                learn_pick = int(parts[1])
                var q: Array = Skills.LESSONS[learn_lesson].qs[learn_q]
                if learn_opts[learn_pick] == q[1]:
                    learn_right += 1
        "qnext":
            learn_q += 1
            if learn_q >= 3:
                learn_done = true
                if learn_right >= 2:
                    Skills.pass_lesson(learn_lesson)
            else:
                _learn_shuffle()
        "lback":
            learn_lesson = -1
            learn_done = false


# ---- drawing helpers ---------------------------------------------------------
func _fill(r: Rect2, c: Color) -> void:
    _canvas.draw_rect(r, c)


func _text(s: String, p: Vector2, c: Color = TXT, scale := 1) -> void:
    PixelFont.draw(_canvas, s, p, c, scale)


func _tw(s: String, scale := 1) -> float:
    return float(PixelFont.width(s, scale))


func _clip(s: String, chars: int) -> String:
    return s if s.length() <= chars else s.substr(0, maxi(1, chars - 2)) + ".."


func _wrap(s: String, chars: int) -> Array:
    var lines := []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            lines.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    lines.append(line)
    return lines


func _region(id: String, r: Rect2) -> void:
    _hits.append({"r": r, "id": id})


func _button(id: String, r: Rect2, label: String, enabled := true, tint := BTN) -> void:
    var hot := enabled and r.has_point(_mouse)
    _fill(r, tint.lightened(0.18) if hot else tint)
    _fill(Rect2(r.position, Vector2(r.size.x, 1)), BTN_HI)
    _fill(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), BTN_SH)
    _fill(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), BTN_SH)
    var at := r.position + Vector2(floorf((r.size.x - _tw(label)) * 0.5), floorf((r.size.y - 5.0) * 0.5))
    _text(label, at, TXT if enabled else Color("8b93a1"))
    if enabled:
        _region(id, r)


func _row(r: Rect2, selected: bool, alt: bool) -> void:
    var col := Color("ffffff") if not alt else Color("eef3f9")
    if selected:
        col = Color("c7dcf5")
    elif r.has_point(_mouse):
        col = Color("e1ecf8")
    _fill(r, col)


func _window(title: String, tint: Color) -> Rect2:
    var a := Rect2(_area.position, Vector2(_area.size.x, _area.size.y - TB))
    _fill(a, Color("e9ecf1"))
    _fill(Rect2(a.position, Vector2(a.size.x, 8)), tint)
    _text(title, a.position + Vector2(3, 1), WHITE)
    _button("close_app", Rect2(a.end.x - 10, a.position.y + 1, 9, 6), "X", true, Color("d86b5e"))
    return Rect2(a.position + Vector2(0, 8), Vector2(a.size.x, a.size.y - 8))


func _offline(message: String, body: Rect2) -> bool:
    var net := Net.desk_state(desk)
    if net == "ok":
        return false
    _fill(body, Color("f3f3f5"))
    var mid := body.position + Vector2(body.size.x * 0.5, body.size.y * 0.35)
    var col := RED if net == "no_link" else AMBER
    _fill(Rect2(mid - Vector2(7, 7), Vector2(14, 14)), col)
    _text("!" if net == "no_internet" else "X", mid - Vector2(1, 2), WHITE)
    var lines := _wrap(message, int(body.size.x / 4.0) - 2)
    lines.append("")
    lines.append("NO NETWORK CONNECTION." if net == "no_link" else "NO INTERNET ACCESS.")
    lines.append("CHECK THE NETWORK CLOSET.")
    for i in lines.size():
        var s: String = lines[i]
        _text(s, Vector2(floorf(body.position.x + (body.size.x - _tw(s)) * 0.5), mid.y + 12 + i * 7), TXT)
    return true


# ---- the whole screen --------------------------------------------------------
func _paint() -> void:
    var size := get_viewport().get_visible_rect().size
    _hits.clear()
    _fill(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.62))  # the office, faded, behind
    var top := maxf(12.0, floorf(size.y * Game.UI_STRIP))
    _area = Rect2(0, top, size.x, size.y - top)
    match app:
        "mail":
            _paint_mail()
        "psa":
            _paint_psa()
        "rmm":
            _paint_rmm()
        "boardroom":
            _paint_boardroom()
        "lync":
            _paint_lync()
        "nerds":
            _paint_nerds()
        "learn":
            _paint_learn()
        "stats":
            _paint_stats()
        "site":
            _paint_site()
        _:
            _paint_desktop()
    _paint_taskbar()
    if _toast_t > 0.0:
        var msg := _clip(_toast, int((size.x - 8) / 4.0))
        var tx := floorf((size.x - _tw(msg)) * 0.5)
        _fill(Rect2(tx - 3, _area.end.y - TB - 10, _tw(msg) + 6, 9), Color("20242c"))
        _text(msg, Vector2(tx, _area.end.y - TB - 8), WHITE)
    _fill(Rect2(0, top - 1, size.x, 1), Color("0d1018"))
    _cursor()


func _cursor() -> void:
    var m := _mouse.floor()
    for i in 6:
        _fill(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), Color("17121f"))
    _fill(Rect2(m.x + 1, m.y + 2, 2, 2), WHITE)
    _fill(Rect2(m.x + 1, m.y + 1, 1, 1), WHITE)


func _paint_taskbar() -> void:
    var y := _area.end.y - TB
    _fill(Rect2(0, y, _area.size.x, TB), TASK)
    _fill(Rect2(0, y, _area.size.x, 1), Color("3c6aa5"))
    _button("start", Rect2(1, y + 1, 26, 9), "START", true, Color("3a7bd5"))
    if _menu and app == "site":
        var site_items := [["site:tools", "TOOLS"], ["logoff", "LOG OFF"]]
        for i in site_items.size():
            _button(site_items[i][0], Rect2(1, y - (site_items.size() - i) * 9, 54, 9), site_items[i][1], true, Color("e9ecf1"))
    elif _menu:
        var items := [
            ["app:mail", "OUTLOOKISH"], ["app:psa", "CONNECTWHY"], ["app:rmm", "LABRAT"], ["app:learn", "POWERSHELL"],
            ["app:stats", "PROFILE"], ["app:lync", "LYNK"], ["app:nerds", "NERDS"], ["logoff", "LOG OFF"],
        ]
        if Owner.active():
            items.insert(4, ["app:boardroom", "BOARDROOM"])
        for i in items.size():
            _button(items[i][0], Rect2(1, y - (items.size() - i) * 9, 54, 9), items[i][1], true, Color("e9ecf1"))
    var net := "ok" if app == "site" else Net.desk_state(desk)
    var dot := GREEN if net == "ok" else (AMBER if net == "no_internet" else RED)
    var clock: String = World.clock_text()
    var cx := _area.size.x - _tw(clock) - 4
    _text(clock, Vector2(cx, y + 3), WHITE)
    _fill(Rect2(cx - 7, y + 3, 5, 5), dot)
    if app != "desktop":
        _button("close_app", Rect2(30, y + 1, 36, 9), _clip(app.to_upper(), 8), true, Color("5d86bd"))


func _icon(kind: String, p: Vector2) -> void:
    match kind:
        "mail":
            _fill(Rect2(p, Vector2(16, 11)), WHITE)
            _fill(Rect2(p, Vector2(16, 1)), Color("17121f"))
            for i in 6:
                _fill(Rect2(p.x + 1 + i, p.y + 1 + i, 1, 1), Color("5a6a85"))
                _fill(Rect2(p.x + 14 - i, p.y + 1 + i, 1, 1), Color("5a6a85"))
        "psa":
            _fill(Rect2(p, Vector2(14, 14)), Color("e8e2c8"))
            _fill(Rect2(p + Vector2(4, -1), Vector2(6, 3)), PSA_BLUE)
            for i in 3:
                _fill(Rect2(p + Vector2(2, 4 + i * 3), Vector2(10, 1)), Color("7d8aa0"))
        "learn":
            _fill(Rect2(p, Vector2(16, 12)), Color("012456"))
            for i in 3:
                _fill(Rect2(p.x + 3 + i, p.y + 3 + i, 1, 1), WHITE)
                _fill(Rect2(p.x + 3 + i, p.y + 7 - i, 1, 1), WHITE)
            _fill(Rect2(p.x + 8, p.y + 8, 5, 1), WHITE)
        "lync":
            _fill(Rect2(p + Vector2(1, 1), Vector2(14, 9)), Color("0a6ab8"))
            _fill(Rect2(p + Vector2(3, 10), Vector2(3, 2)), Color("0a6ab8"))
            _fill(Rect2(p + Vector2(5, 3), Vector2(2, 5)), WHITE)
            _fill(Rect2(p + Vector2(5, 6), Vector2(5, 2)), WHITE)
        "nerds":
            _fill(Rect2(p + Vector2(1, 2), Vector2(14, 10)), Color("2a2a33"))
            _fill(Rect2(p + Vector2(1, 0), Vector2(4, 4)), Color("e07b22"))
            _fill(Rect2(p + Vector2(11, 0), Vector2(4, 4)), Color("e07b22"))
            _fill(Rect2(p + Vector2(4, 6), Vector2(2, 2)), WHITE)
            _fill(Rect2(p + Vector2(10, 6), Vector2(2, 2)), WHITE)
        "boardroom":
            _fill(Rect2(p + Vector2(1, 3), Vector2(14, 9)), Color("8a5a2b"))
            _fill(Rect2(p + Vector2(5, 0), Vector2(6, 4)), Color("6b421c"))
            _fill(Rect2(p + Vector2(7, 6), Vector2(2, 3)), Color("f5d442"))
        "stats":
            _fill(Rect2(p, Vector2(15, 12)), Color("e8ecf2"))
            _fill(Rect2(p.x + 2, p.y + 6, 3, 5), GREEN)
            _fill(Rect2(p.x + 6, p.y + 3, 3, 8), ORANGE)
            _fill(Rect2(p.x + 10, p.y + 1, 3, 10), Color("3a7bd5"))
        _:
            _fill(Rect2(p, Vector2(16, 11)), Color("2a2a33"))
            _fill(Rect2(p + Vector2(1, 1), Vector2(14, 8)), Color("4f7fd0"))
            _fill(Rect2(p + Vector2(6, 3), Vector2(4, 4)), ORANGE)
            _fill(Rect2(p + Vector2(5, 11), Vector2(6, 2)), Color("2a2a33"))


# ---- a client's computer (onsite): their desktop, software and mail -----------------
func _site_action(parts: PackedStringArray) -> void:
    if parts[1] == "diag":
        var obj := str(site_info.get("obj", "pc"))
        if not Onsite.job_here(obj):
            _say("NOTHING WRONG WITH THIS PC")
            return
        close()
        Onsite.pc_diagnose(obj)
        return
    if parts[1] == "audit":
        var obj := str(site_info.get("obj", "pc"))
        close()
        Onsite.inspect(obj)
        return
    site_view = parts[1]


func _paint_site() -> void:
    var a := _area
    var wall := Color(str(site_info.get("wall", "#CFE8EE")))
    var accent := Color(str(site_info.get("accent", "#2E9AB8")))
    if site_view != "desktop":
        _paint_site_window(accent)
        return
    var ink := Color("17121f") if wall.get_luminance() > 0.45 else WHITE
    _fill(a, wall)
    for i in 6:
        _fill(Rect2(a.position.x, a.position.y + i * 8.0, a.size.x, 3), accent.lerp(wall, 0.6))
    var title := str(site_info.get("name", ""))
    var scale := 2 if a.size.x >= 260.0 and _tw(title, 2) < a.size.x - 70.0 else 1
    var tx := floorf(a.position.x + (a.size.x - _tw(title, scale)) * 0.5)
    var ty := a.position.y + a.size.y * 0.40
    _text(title, Vector2(tx + 1, ty + 1), Color("17121f"), scale)
    _text(title, Vector2(tx, ty), WHITE, scale)
    var who := "%s   USER: %s" % [str(site_info.get("pc", "PC")), str(site_info.get("user", ""))]
    _text(who, Vector2(floorf(a.position.x + (a.size.x - _tw(who)) * 0.5), ty + 8 + 5 * scale), ink)
    _text("WINDOWS 7 PROFESSIONAL", Vector2(a.position.x + 4, a.end.y - TB - 8), ink)
    var icons := [
        ["practice", _clip(str(site_info.get("app", "APP")), 10), "app"],
        ["mail", "MAIL", "mail"],
        ["computer", "COMPUTER", "psa"],
        ["tools", "TOOLS", "stats"],
    ]
    var per_col := maxi(1, int((a.size.y - TB - 6.0) / 27.0))
    for i in icons.size():
        var p := Vector2(a.position.x + 8 + float(i / per_col) * 52.0, a.position.y + 5 + float(i % per_col) * 27.0)
        var hit := Rect2(p - Vector2(5, 3), Vector2(46, 25))
        if hit.has_point(_mouse):
            _fill(hit, Color(1, 1, 1, 0.25))
        _icon(icons[i][2], p + Vector2(10, 0))
        _text(icons[i][1], p + Vector2(0, 16), ink)
        _region("site:" + icons[i][0], hit)


func _paint_site_window(accent: Color) -> void:
    var info := site_info
    var chars := 40
    match site_view:
        "practice":
            var body := _window(str(info.get("app", "")) + " - " + str(info.get("title", "")), accent)
            chars = int(body.size.x / 4.0) - 2
            var y := body.position.y + 4
            for row in info.get("rows", []):
                _text(_clip(str(row), chars), Vector2(body.position.x + 4, y), TXT)
                y += 8
        "mail":
            var body := _window("OUTLOOKISH 2010 - INBOX", Color("2b5797"))
            chars = int(body.size.x / 4.0) - 2
            var y := body.position.y + 4
            for mail in info.get("mails", []):
                _text(_clip("FROM: " + str(mail[0]).to_upper(), chars), Vector2(body.position.x + 4, y), Color("2b5797"))
                _text(_clip(str(mail[1]), chars), Vector2(body.position.x + 4, y + 7), TXT)
                y += 18
        "computer":
            var body := _window("COMPUTER", Color("4a6a8a"))
            var lines := [
                "NAME: " + str(info.get("pc", "")),
                "USER: " + str(info.get("user", "")),
                "WINDOWS 7 PROFESSIONAL SP1",
                "DRIVE C: 82 GB FREE OF 250 GB",
                "NETWORK: " + str(info.get("net", "CONNECTED")),
            ]
            var y := body.position.y + 4
            for line in lines:
                _text(_clip(str(line), int(body.size.x / 4.0) - 2), Vector2(body.position.x + 4, y), RED if str(line).contains("NO NETWORK") else TXT)
                y += 8
        _:
            var body := _window("YOUR TOOLBOX", Color("5a5f6a"))
            _text("YOU ARE ONSITE. THIS IS THEIR COMPUTER.", Vector2(body.position.x + 4, body.position.y + 4), Color("46506a"))
            _button("site:diag", Rect2(body.position.x + 4, body.position.y + 16, minf(body.size.x - 8, 90.0), 10), "DIAGNOSE AND FIX", true, Color("9bd6a8"))
            _button("site:audit", Rect2(body.position.x + 4, body.position.y + 28, minf(body.size.x - 8, 90.0), 10), "LOOK AROUND", true, Color("e9d99b"))
            _text("EVENT LOG: NOTHING UNUSUAL", Vector2(body.position.x + 4, body.position.y + 44), TXT)
            _text("PING 8.8.8.8: " + ("TIMED OUT" if str(info.get("net", "")).contains("NO") else "OK"), Vector2(body.position.x + 4, body.position.y + 52), TXT)


func _paint_desktop() -> void:
    var a := _area
    var wall := Career.wallpaper_color()
    _fill(a, wall)
    for i in 8:
        _fill(Rect2(a.position.x, a.position.y + i * 6.0, a.size.x, 3), wall.lightened(0.1))
    var title := "PIXEL IT PARTNERS"
    var scale := 2 if a.size.x >= 220.0 else 1
    var tx := floorf(a.position.x + (a.size.x - _tw(title, scale)) * 0.5)
    var ty := a.position.y + a.size.y * 0.42
    _text(title, Vector2(tx + 1, ty + 1), Color("17121f"), scale)
    _text(title, Vector2(tx, ty), WHITE, scale)
    var sub := "SERVICE DESK - SINCE 2013"
    _text(sub, Vector2(floorf(a.position.x + (a.size.x - _tw(sub)) * 0.5), ty + 6 + 5 * scale), Color("bcd4f0"))
    var icons := [
        ["mail", "OUTLOOKISH", Msp.unread()], ["psa", "CONNECTWHY", Msp.open_tickets().size()], ["rmm", "LABRAT", 0],
        ["learn", "POWERSHELL", 0], ["stats", "PROFILE", 0],
        ["lync", "LYNK", Lync.unread_total()], ["nerds", "NERDS", 0],
    ]
    if Owner.active():
        icons.append(["boardroom", "BOARDROOM", 0])
    var per_col := maxi(1, int((a.size.y - TB - 6.0) / 27.0))
    for i in icons.size():
        var p := Vector2(a.position.x + 8 + float(i / per_col) * 52.0, a.position.y + 5 + float(i % per_col) * 27.0)
        var hit := Rect2(p - Vector2(5, 3), Vector2(46, 25))
        if hit.has_point(_mouse):
            _fill(hit, Color(1, 1, 1, 0.18))
        _icon(icons[i][0], p + Vector2(10, 0))
        _text(icons[i][1], p + Vector2(0, 16), WHITE)
        if icons[i][2] > 0:
            _fill(Rect2(p.x + 22, p.y - 3, 9, 7), RED)
            _text(str(icons[i][2]), Vector2(p.x + 25, p.y - 2), WHITE)
        _region("app:" + icons[i][0], hit)
    if Career.unlocked_of("wallpaper").size() > 1:  # a medal unlocked another wallpaper: click the chip to change
        var chip := "WALLPAPER: " + str(Career.pick_of("wallpaper").title)
        var cr := Rect2(a.end.x - _tw(chip) - 10, a.position.y + 3, _tw(chip) + 8, 9)
        _fill(cr, Color(0, 0, 0, 0.35) if not cr.has_point(_mouse) else Color(0, 0, 0, 0.6))
        _text(chip, cr.position + Vector2(4, 2), WHITE)
        _region("wall:next", cr)
    var net := Net.desk_state(desk)
    if net != "ok":
        var note := "NETWORK CABLE UNPLUGGED" if net == "no_link" else "NO INTERNET ACCESS"
        var r := Rect2(a.end.x - _tw(note) - 12, a.end.y - TB - 14, _tw(note) + 8, 11)
        _fill(r, RED if net == "no_link" else AMBER)
        _text(note, r.position + Vector2(4, 3), WHITE)


# ---- mail (Outlookish 2013) --------------------------------------------------
func _paint_mail() -> void:
    var body := _window("OUTLOOKISH 2013 - INBOX (%d UNREAD)" % Msp.unread(), OUTLOOK)
    if _offline("OUTLOOKISH CANNOT CONNECT TO THE MAIL SERVER.", body):
        return
    var narrow := body.size.x < 250.0
    var list_w := body.size.x if (narrow and not mail_view) else (0.0 if narrow else clampf(floorf(body.size.x * 0.48), 112.0, 150.0))
    if not narrow:
        _fill(Rect2(body.position, Vector2(40, body.size.y)), Color("dfe5ef"))
        _text("INBOX", body.position + Vector2(4, 4), OUTLOOK)
        _text("SENT", body.position + Vector2(4, 13), Color("7d8aa0"))
        _text("DELETED", body.position + Vector2(4, 22), Color("7d8aa0"))
    var lx := body.position.x + (0.0 if narrow else 40.0)
    if list_w > 0.0:
        _mail_list(Rect2(lx, body.position.y, list_w, body.size.y))
    if mail_sel >= 0 and mail_sel < Msp.emails.size() and (mail_view or not narrow):
        var rx := body.position.x if narrow else lx + list_w
        _mail_read(Rect2(rx, body.position.y, body.end.x - rx, body.size.y), narrow)
    elif not narrow:
        _fill(Rect2(lx + list_w, body.position.y, body.end.x - lx - list_w, body.size.y), WHITE)
        _text("SELECT AN ITEM TO READ", Vector2(lx + list_w + 6, body.position.y + 8), Color("8b93a1"))


func _mail_list(r: Rect2) -> void:
    var rows := int(r.size.y / 14.0)
    if mail_sel >= 0:  # keep the selected mail on screen
        mail_top = clampi(mail_top, mail_sel - rows + 1, mail_sel)
    mail_top = clampi(mail_top, 0, maxi(0, Msp.emails.size() - rows))
    for i in range(mail_top, mini(mail_top + rows, Msp.emails.size())):
        var m: Dictionary = Msp.emails[i]
        var rr := Rect2(r.position.x, r.position.y + (i - mail_top) * 14.0, r.size.x, 14)
        _row(rr, i == mail_sel, i % 2 == 1)
        var col := OUTLOOK if m.unread else Color("5a6372")
        _text(_clip(m.from, int(r.size.x / 4.0) - 2), rr.position + Vector2(3, 2), col)
        _text(_clip(m.subject, int(r.size.x / 4.0) - 2), rr.position + Vector2(3, 8), TXT if m.unread else Color("7d8595"))
        _region("mail:%d" % i, rr)
    if Msp.emails.is_empty():
        _fill(r, WHITE)
        _text("NO MESSAGES", r.position + Vector2(6, 6), Color("8b93a1"))


func _mail_read(r: Rect2, narrow: bool) -> void:
    var m: Dictionary = Msp.emails[mail_sel]
    _fill(r, WHITE)
    _text("FROM: " + _clip(m.from, int(r.size.x / 4.0) - 7), r.position + Vector2(4, 3), OUTLOOK)
    _text(_clip(m.subject, int(r.size.x / 4.0) - 2), r.position + Vector2(4, 10), TXT)
    _fill(Rect2(r.position.x + 3, r.position.y + 17, r.size.x - 6, 1), Color("c9d2e0"))
    var lines := _wrap(m.body, int((r.size.x - 8) / 4.0))
    for i in mini(lines.size(), int((r.size.y - 40) / 7.0)):
        _text(lines[i], r.position + Vector2(4, 21 + i * 7), TXT)
    var by := r.end.y - 11
    _button("reply", Rect2(r.position.x + 3, by, 30, 9), "REPLY")
    _button("delete", Rect2(r.position.x + 36, by, 32, 9), "DELETE")
    if narrow:
        _button("mback", Rect2(r.end.x - 31, by, 28, 9), "BACK")


# ---- PSA (ConnectWhy PSA) ----------------------------------------------------
func _paint_psa() -> void:
    var body := _window("CONNECTWHY PSA - SERVICE BOARD", PSA_BLUE)
    if _offline("CONNECTWHY PSA - SERVER NOT AVAILABLE.", body):
        return
    if psa_detail and not Msp.ticket(psa_sel).is_empty():
        _paint_ticket(body)
    else:
        psa_detail = false
        _paint_board(body)


func _pri_color(pri: int) -> Color:
    return [RED, ORANGE, AMBER, Color("7d8aa0")][clampi(pri, 1, 4) - 1]


func _mmss(secs: float) -> String:
    var s := maxi(0, int(secs))
    return "%d:%02d" % [s / 60, s % 60]


func _paint_board(body: Rect2) -> void:
    var wide := body.size.x >= 300.0
    var tickets := Msp.open_tickets()
    _fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("cfd9e8"))
    _text("OPEN %d" % tickets.size(), body.position + Vector2(3, 2), PSA_BLUE)
    var stats := "SCORE %d  CLOSED %d  SLA MISSED %d" % [Msp.score, Msp.closed_ok, Msp.breached]
    _text(_clip(stats, int((body.size.x - 40) / 4.0)), body.position + Vector2(40, 2), TXT)
    var y0 := body.position.y + 9
    _fill(Rect2(body.position.x, y0, body.size.x, 7), Color("9db3d1"))
    var cols := [0.0, 26.0]
    var sum_x := body.position.x + (74.0 if wide else 26.0)
    _text("#", Vector2(body.position.x + 2, y0 + 1), WHITE)
    if wide:
        _text("CO", Vector2(body.position.x + cols[1], y0 + 1), WHITE)
    _text("SUMMARY", Vector2(sum_x, y0 + 1), WHITE)
    _text("SLA", Vector2(body.end.x - 22, y0 + 1), WHITE)
    var rows := int((body.size.y - 16) / 9.0)
    var first := clampi(_psa_index() - rows + 1, 0, maxi(0, tickets.size() - rows))
    for i in mini(rows, tickets.size() - first):
        var t: Dictionary = tickets[first + i]
        var rr := Rect2(body.position.x, y0 + 7 + i * 9.0, body.size.x, 9)
        _row(rr, t.id == psa_sel, i % 2 == 1)
        _fill(Rect2(rr.position.x, rr.position.y, 2, 9), _pri_color(t.pri))
        _text(str(t.id), rr.position + Vector2(4, 2), TXT)
        var short := "PITP" if t.client < 0 else str(Msp.CLIENTS[t.client].short)
        if wide:
            _text(short, rr.position + Vector2(cols[1], 2), Color("5a6372"))
        var sum_chars := int((body.end.x - 26 - sum_x) / 4.0) - 3
        _text(_clip(t.summary, sum_chars), Vector2(sum_x, rr.position.y + 2), TXT)
        var late: bool = t.breached or t.sla_left < 30.0
        _text("LATE" if t.breached else _mmss(t.sla_left), Vector2(body.end.x - 22, rr.position.y + 2), RED if late else Color("5a6372"))
        _region("tk:%d" % t.id, rr)
    if tickets.is_empty():
        _text("NO OPEN TICKETS. NICE.", body.position + Vector2(8, 28), Color("8b93a1"))


func _paint_ticket(body: Rect2) -> void:
    var t := Msp.ticket(psa_sel)
    _fill(body, WHITE)
    var chars := int((body.size.x - 8) / 4.0)
    _fill(Rect2(body.position, Vector2(body.size.x, 9)), _pri_color(t.pri))
    _text(_clip("#%d  %s" % [t.id, t.summary], chars), body.position + Vector2(3, 2), WHITE)
    var y := body.position.y + 12
    var info := [
        _clip(Msp.client_text(t), chars), "PRIORITY P%d   STATUS: %s" % [t.pri, str(t.status).to_upper()],
        "SLA: %s%s" % [_mmss(t.sla_left), "  (MISSED)" if t.breached else ""],
        ("DESK: " + str(Msp.DESK_NAMES.get(t.desk, "?"))) if t.internal else ("ENDPOINT: " + str(t.endpoint)),
    ]
    for s in info:
        _text(s, Vector2(body.position.x + 4, y), PSA_BLUE if s == info[0] else TXT)
        y += 7
    y += 2
    var lines := _wrap(t.body, chars)
    var space := int((body.end.y - 24 - y) / 7.0)
    for i in mini(lines.size(), maxi(2, space - 3)):
        _text(lines[i], Vector2(body.position.x + 4, y), Color("46506a"))
        y += 7
    _fill(Rect2(body.position.x + 3, y, body.size.x - 6, 1), Color("c9d2e0"))
    y += 3
    var shown := maxi(1, int((body.end.y - 24 - y) / 7.0))
    for i in range(maxi(0, t.notes.size() - shown), t.notes.size()):
        _text("- " + _clip(t.notes[i], chars - 2), Vector2(body.position.x + 4, y), Color("7d8aa0"))
        y += 7
    _ticket_buttons(body)


func _ticket_buttons(body: Rect2) -> void:
    var tk := Msp.ticket(psa_sel)
    if close_ask:
        var warn := Rect2(body.position.x + 3, body.end.y - 33, body.size.x - 6, 20)
        _fill(warn, Color("f6d7d2"))
        var wchars := int((warn.size.x - 6.0) / 4.0)
        var wl := _wrap("NOT FIXED YET. CLOSING REOPENS IT: ANGRY CLIENT, COWORKERS -1.", wchars)
        for i in mini(2, wl.size()):
            _text(wl[i], warn.position + Vector2(3, 3 + i * 7), RED)
        var half := floorf((body.size.x - 6.0) * 0.5)
        _button("closeyes", Rect2(body.position.x + 3, body.end.y - 11, half - 2, 9), "CLOSE ANYWAY", true, Color("e8b0a8"))
        _button("closeno", Rect2(body.position.x + 3 + half, body.end.y - 11, half - 2, 9), "KEEP WORKING", true, Color("9bd6a8"))
        return
    # CLOSE sits at the far end, away from NOTE
    var items := [["back", "BACK"], ["take", "TAKE"], ["prog", "PROGRESS"], ["note", "NOTE"], ["wait", "WAIT"], ["close", "CLOSE"]]
    if not tk.is_empty() and Onsite.is_onsite(tk):
        items[2] = ["onsite", "GO ONSITE"]
    var wide := body.size.x >= 250.0
    var cols := 6 if wide else 3
    var bw := floorf((body.size.x - 6) / cols)
    for i in items.size():
        var r := Rect2(body.position.x + 3 + (i % cols) * bw, body.end.y - 11 - (0 if wide else (1 - i / cols) * 10), bw - 2, 9)
        var tint := BTN if items[i][0] != "close" else Color("9bd6a8")
        _button(items[i][0], r, items[i][1], true, tint)


# ---- RMM (LabRat RMM) --------------------------------------------------------
func _paint_rmm() -> void:
    var body := _window("LABRAT RMM - CONTROL CENTER", RMM_GREY)
    if _offline("LABRAT CANNOT REACH THE AUTOMATION SERVER.", body):
        return
    if rmm_session and not Msp.endpoint(rmm_sel).is_empty():
        _paint_session(body)
        return
    rmm_session = false
    _fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("d5d9e0"))
    _button("tab:endpoints", Rect2(body.position.x + 2, body.position.y + 1, 44, 8), "ENDPOINTS", true, BTN_HI if rmm_tab == "endpoints" else BTN)
    _button("tab:backups", Rect2(body.position.x + 48, body.position.y + 1, 38, 8), "BACKUPS", true, BTN_HI if rmm_tab == "backups" else BTN)
    _button("tab:project", Rect2(body.position.x + 88, body.position.y + 1, 38, 8), "PROJECT", true, BTN_HI if rmm_tab == "project" else BTN)
    body = Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
    if rmm_tab == "backups":
        _paint_backups(body)
        return
    if rmm_tab == "project":
        _paint_project(body)
        return
    var narrow := body.size.x < 250.0
    if narrow and rmm_detail:
        _rmm_detail(body, true)
        return
    var list_w := body.size.x if narrow else 124.0
    _rmm_list(Rect2(body.position, Vector2(list_w, body.size.y)))
    if not narrow:
        _rmm_detail(Rect2(body.position.x + list_w, body.position.y, body.size.x - list_w, body.size.y), false)


func _rmm_list(r: Rect2) -> void:
    _fill(r, Color("f4f5f7"))
    # total height of the tree: the list scrolls (wheel or Up / Down) when it is longer than the window
    var total := 0
    for c in Sales.active:
        total += 9
        if rmm_open.get(c, false):
            for ep in Msp.endpoints:
                if ep.client == c:
                    total += 8
    var max_scroll := maxi(0, total - int(r.size.y))
    rmm_scroll = clampi(rmm_scroll, 0, max_scroll)
    var y := r.position.y - float(rmm_scroll)
    for c in Sales.active:
        var alert := false
        for ep in Msp.endpoints:
            if ep.client == c and _ep_alert(ep):
                alert = true
        if y >= r.position.y and y + 9 <= r.end.y:
            var hr := Rect2(r.position.x, y, r.size.x - 4, 9)
            _fill(hr, Color("d5d9e0") if not hr.has_point(_mouse) else Color("e4e7ec"))
            _text(("- " if rmm_open.get(c, false) else "+ ") + _clip(Msp.CLIENTS[c].name, int(r.size.x / 4.0) - 6), hr.position + Vector2(3, 2), TXT)
            if alert:
                _fill(Rect2(hr.end.x - 7, y + 2, 4, 4), ORANGE)
            _region("client:%d" % c, hr)
        y += 9
        if rmm_open.get(c, false):
            for ep in Msp.endpoints:
                if ep.client != c:
                    continue
                if y >= r.position.y and y + 8 <= r.end.y:
                    var er := Rect2(r.position.x, y, r.size.x - 4, 8)
                    _row(er, ep.name == rmm_sel, false)
                    _fill(Rect2(er.position.x + 5, y + 2, 4, 4), RED if _ep_alert(ep) else GREEN)
                    _text(ep.name, er.position + Vector2(12, 1), TXT)
                    _region("rmm:" + ep.name, er)
                y += 8
    if max_scroll > 0:  # a thin scroll bar on the right edge
        var track := Rect2(r.end.x - 3, r.position.y, 2, r.size.y)
        _fill(track, Color("d5d9e0"))
        var bar_h := maxf(8.0, r.size.y * r.size.y / float(total))
        var bar_y := r.position.y + (r.size.y - bar_h) * float(rmm_scroll) / float(max_scroll)
        _fill(Rect2(track.position.x, bar_y, 2, bar_h), Color("6b7280"))


# an endpoint shows an alert when something is broken on it or an open, unfixed ticket points at it
func _ep_alert(ep: Dictionary) -> bool:
    if str(ep.problem) != "":
        return true
    for t in Msp.tickets:
        if t.status != "Closed" and not t.fix_done and str(t.endpoint) == str(ep.name):
            return true
    return false


func _symptom(problem: String) -> String:
    var texts := {
        "spooler": "PRINT SPOOLER SERVICE IS NOT RUNNING", "password": "ACCOUNT LOCKED OUT - TOO MANY BAD PASSWORDS",
        "clear_temp": "LOW DISK SPACE - DRIVE C IS 99% FULL", "reboot": "STOP ERROR 0X7B - SYSTEM HALTED",
        "av": "407 ITEMS DETECTED: ADWARE.FREECRUISE",
        "restore": "FILES ENCRYPTED (.LOCKED) AND A RANSOM NOTE. DO NOT REBOOT. RESTORE!",
        "adobe": "ADOBE READER PRINT DIALOG IS BROKEN. OTHER APPS PRINT FINE.",
        "project": "NEW PC ARRIVED. SEE THE PROJECT TAB TO SET UP AND MIGRATE.",
    }
    if problem.begins_with("onsite_"):
        return str(Onsite.TEXT.symptom)
    return str(texts.get(problem, "NO ISSUES FOUND. ALL SERVICES NORMAL."))


func _rmm_detail(r: Rect2, narrow: bool) -> void:
    _fill(r, WHITE)
    var ep := Msp.endpoint(rmm_sel)
    if ep.is_empty():
        _text("SELECT AN ENDPOINT", r.position + Vector2(6, 8), Color("8b93a1"))
        return
    var chars := int((r.size.x - 8) / 4.0)
    _text(ep.name, r.position + Vector2(4, 4), RMM_GREY)
    _text(_clip(Msp.CLIENTS[ep.client].name, chars), r.position + Vector2(4, 12), Color("5a6372"))
    _text("USER: " + str(ep.user), r.position + Vector2(4, 20), TXT)
    _text("OS: " + str(ep.os), r.position + Vector2(4, 27), TXT)
    var alert: bool = ep.problem != ""
    _fill(Rect2(r.position.x + 4, r.position.y + 36, r.size.x - 8, 9), RED if alert else GREEN)
    _text("ALERT" if alert else "ONLINE - OK", r.position + Vector2(8, 38), WHITE)
    var lines := _wrap(_symptom(ep.problem) if alert else "NO ISSUES FOUND.", chars)
    for i in lines.size():
        _text(lines[i], r.position + Vector2(4, 49 + i * 7), TXT)
    _button("connect", Rect2(r.position.x + 4, r.end.y - 12, 44, 10), "CONNECT", true, Color("f0b27a"))
    if narrow:
        _button("rback", Rect2(r.end.x - 34, r.end.y - 12, 30, 10), "BACK")


func _paint_session(body: Rect2) -> void:
    var ep := Msp.endpoint(rmm_sel)
    _fill(body, Color("245c9a"))
    _fill(Rect2(body.position, Vector2(body.size.x, 8)), Color("14263d"))
    _text(_clip("REMOTE: " + str(ep.name) + " (" + str(ep.user) + ")", int((body.size.x - 50) / 4.0)), body.position + Vector2(3, 1), WHITE)
    _button("disc", Rect2(body.end.x - 46, body.position.y + 1, 44, 6), "DISCONNECT", true, Color("d86b5e"))
    var dlg := Rect2(body.position.x + 8, body.position.y + 14, body.size.x - 16, 26)
    _fill(dlg, Color("ece9d8"))
    _fill(Rect2(dlg.position, Vector2(dlg.size.x, 6)), Color("1c3b63"))
    var alert: bool = ep.problem != ""
    _text("SYSTEM MESSAGE" if alert else "ALL CLEAR", dlg.position + Vector2(3, 1), WHITE)
    var lines := _wrap(_symptom(ep.problem), int((dlg.size.x - 8) / 4.0))
    for i in mini(lines.size(), 3):
        _text(lines[i], dlg.position + Vector2(4, 9 + i * 6), RED if alert else GREEN)
    _text(_clip(rmm_msg, int((body.size.x - 8) / 4.0)), body.position + Vector2(4, 42), WHITE)
    if not _job.is_empty():
        var frac := clampf(1.0 - float(_job.left) / float(_job.total), 0.0, 1.0)
        _fill(Rect2(body.position.x + 4, body.position.y + 48, body.size.x - 8, 4), Color("14263d"))
        _fill(Rect2(body.position.x + 4, body.position.y + 48, (body.size.x - 8) * frac, 4), GREEN)
    var actions: Array = []
    for key in Msp.FIXES:
        if (key == "shadow" or key == "pay") and ep.problem != "restore":
            continue  # only on a ransomed machine
        if key == "save" and (ep.problem in ["", "reboot", "restore", "project"] or ep.user == "server"):
            continue  # nobody to warn, or the machine is already down
        actions.append(key)
    var labels: Array = []
    for key in actions:
        labels.append(Msp.reboot_label(ep) if key == "reboot" else Msp.FIXES[key])
    for alt in Msp.alts_for(ep):
        actions.append(alt)
        labels.append(Msp.alt_label(ep, alt))
    if Skills.can_script():
        actions.append("script")
        labels.append("SCRIPT: THIS CLIENT")
    if Skills.script_all():
        actions.append("scriptall")
        labels.append("SCRIPT: ALL CLIENTS")
    var cols := clampi(int(body.size.x / 84.0), 2, 4)
    var bw := floorf((body.size.x - 6) / float(cols))
    # many buttons (other fixes + both scripts): squeeze the rows so they stay inside the window
    var rows := ceili(float(actions.size()) / float(cols))
    var pitch := clampf(floorf((body.end.y - body.position.y - 55.0) / float(rows)), 7.0, 10.0)
    for i in actions.size():
        var r := Rect2(body.position.x + 3 + float(i % cols) * bw, body.position.y + 54 + float(i / cols) * pitch, bw - 2, pitch - 1.0)
        var id: String = "fix:" + str(actions[i]) if actions[i] != "script" and actions[i] != "scriptall" else str(actions[i])
        var tint := Color("9fd8ff") if id.begins_with("script") else Color("d9dde6")
        if Msp.ALT_DEFS.has(str(actions[i])):
            tint = ALT_TINTS[str(Msp.ALT_DEFS[actions[i]].kind)]
        _button(id, r, _clip(str(labels[i]), int((bw - 4.0) / 4.0)), _job.is_empty(), tint)


func _paint_backups(body: Rect2) -> void:
    _fill(body, WHITE)
    var compact := body.size.y < 100.0
    var row_h := 14.0
    if compact:
        row_h = 11.0 if Sales.active.size() <= 5 else 8.0
    _text("NIGHTLY BACKUP JOBS - VERIFY EACH ONE EVERY DAY", body.position + Vector2(4, 3), RMM_GREY)
    for idx in Sales.active.size():
        var c: int = Sales.active[idx]
        var b: Dictionary = Msp.backups[c]
        var rr := Rect2(body.position.x, body.position.y + 11 + float(idx) * row_h, body.size.x, row_h)
        _row(rr, false, c % 2 == 1)
        _text(_clip(Msp.CLIENTS[c].name, 22), rr.position + Vector2(3, 2), TXT)
        var checked: bool = int(b.checked_day) == Campaign.day or Skills.backup_watch()
        var status := "NOT CHECKED TODAY"
        var color := Color("7d8595")
        if checked and b.ok:
            status = "OK - LAST GOOD: TODAY"
            color = GREEN
        elif checked:
            var ago := maxi(1, Campaign.day - int(b.good_day))
            status = "FAILED! LAST GOOD: %d DAY%s AGO" % [ago, "" if ago == 1 else "S"]
            color = RED
        var at := rr.position + (Vector2(100, 2) if compact else Vector2(3, 8))
        _text(_clip(status, int((body.end.x - at.x - 34) / 4.0)), at, color)
        if not checked:
            _button("bkcheck:%d" % c, Rect2(rr.end.x - 31, rr.position.y + 1, 29, 9), "CHECK")
        elif not b.ok:
            _button("bkrerun:%d" % c, Rect2(rr.end.x - 31, rr.position.y + 1, 29, 9), "RERUN", true, Color("f0b27a"))


func _paint_playbook(body: Rect2) -> void:
    _fill(body, WHITE)
    var pb := Playbook.active
    var book: Dictionary = Playbook.BOOKS[pb.id]
    var steps: Array = book.steps
    var chars := int((body.size.x - 8) / 4.0)
    var title := str(book.title)
    if not bool(pb.done):
        title = "%s - %s (%d/%d)" % [book.title, Playbook.current_step().title, int(pb.step) + 1, steps.size()]
    _text(_clip(title, chars), body.position + Vector2(4, 3), RMM_GREY)
    if not _job.is_empty():
        var frac := clampf(1.0 - float(_job.left) / float(_job.total), 0.0, 1.0)
        _fill(Rect2(body.position.x + 3, body.position.y + 10, (body.size.x - 6) * frac, 2), GREEN)
    var y := body.position.y + 13
    if bool(pb.done):
        var res: Dictionary = pb.result
        _text("JOB COMPLETE. GRADE %s (%d%%)." % [str(res.grade), int(res.pts)], Vector2(body.position.x + 4, y), GREEN)
        y += 9
        var room := int((body.end.y - y) / 7.0)
        var shown := 0
        for line in pb.log:
            if shown >= room:
                break
            _text(_clip("- " + str(line), chars), Vector2(body.position.x + 4, y), Color("46506a"))
            y += 7
            shown += 1
        return
    for line in _wrap(str(Playbook.current_step().text), chars):
        _text(line, Vector2(body.position.x + 4, y), Color("46506a"))
        y += 7
    y += 2
    var choices: Array = Playbook.current_step().choices
    var busy := not _job.is_empty()
    for i in choices.size():
        var ch: Dictionary = choices[i]
        var lock := Playbook.lock_reason(ch)
        var label := str(ch.label) if lock == "" else "%s [%s]" % [ch.label, lock]
        _button("pb:%d" % i, Rect2(body.position.x + 4, y + float(i) * 10.0, body.size.x - 8, 9), _clip(label, chars - 3), lock == "" and not busy)


func _paint_project(body: Rect2) -> void:
    _fill(body, WHITE)
    if not Playbook.active.is_empty() and (Playbook.is_active() or Msp.project.is_empty()):
        _paint_playbook(body)
        return
    var pr := Msp.project
    if pr.is_empty():
        _text("NO ACTIVE PROJECT.", body.position + Vector2(4, 6), Color("8b93a1"))
        return
    var chars := int((body.size.x - 8) / 4.0)
    var title := "PROJECT: NEW PC FOR %s (#%d)" % [str(Msp.CLIENTS[int(pr.client)].contact).to_upper(), int(pr.ticket)]
    _text(_clip(title, chars), body.position + Vector2(4, 3), RMM_GREY)
    var busy := not _job.is_empty()
    if busy:
        var frac := clampf(1.0 - float(_job.left) / float(_job.total), 0.0, 1.0)
        _fill(Rect2(body.position.x + 3, body.position.y + 10, (body.size.x - 6) * frac, 2), GREEN)
    var steps := [
        ["scan", "SCAN OLD PC"], ["deep", "DEEP SCAN"], ["ask", "ASK THE USER"], ["backup", "BACKUP OLD PC"],
        ["all", "SELECT ALL KNOWN"], ["migrate", "MIGRATE"], ["verify", "VERIFY"], ["hand", "HAND OVER"],
    ]
    var cols := clampi(int(body.size.x / 84.0), 2, 4)
    var bw := floorf((body.size.x - 6) / float(cols))
    var rows := ceili(float(steps.size()) / float(cols))
    for i in steps.size():
        var r := Rect2(body.position.x + 3 + float(i % cols) * bw, body.position.y + 13 + float(i / cols) * 10.0, bw - 2, 9)
        var tint := Color("9bd6a8") if steps[i][0] == "hand" else BTN
        _button("proj:" + steps[i][0], r, steps[i][1], not busy and not bool(pr.done), tint)
    var list_y := body.position.y + 13 + float(rows) * 10.0 + 3
    var two_cols := body.size.x >= 300.0
    var per_col := 4 if two_cols else Msp.INSTALL_ITEMS.size()
    for i in Msp.INSTALL_ITEMS.size():
        var it: Dictionary = Msp.INSTALL_ITEMS[i]
        var rx := body.position.x + 4 + (float(i / per_col) * body.size.x * 0.5 if two_cols else 0.0)
        var ry := list_y + float(i % per_col) * 8.0
        var known: bool = pr.found.get(it.id, false)
        var got: bool = pr.migrated.get(it.id, false)
        var picked: bool = pr.selected.get(it.id, false)
        _fill(Rect2(rx, ry, 5, 5), Color("c9d2e0"))
        if picked or got:
            _fill(Rect2(rx + 1, ry + 1, 3, 3), GREEN if got else ORANGE)
        var label := str(it.name) if known else "???"
        _text(label, Vector2(rx + 9, ry), TXT if known else Color("8b93a1"))
        if got:
            _text("COPIED", Vector2(rx + 9 + _tw(label) + 6, ry), GREEN)
        elif known and pr.verified:
            _text("MISSING!", Vector2(rx + 9 + _tw(label) + 6, ry), RED)
        if known and not got and not bool(pr.done):
            _region("pitem:" + str(it.id), Rect2(rx - 1, ry - 1, body.size.x * (0.5 if two_cols else 1.0) - 8, 8))
    if bool(pr.done):
        var res: Dictionary = pr.result
        var line := "HANDED OVER. GRADE %s (%d%%)." % [str(res.grade), int(res.pts)]
        _text(line, Vector2(body.position.x + 4, body.end.y - 9), GREEN if res.outcome == "ok" else ORANGE)


# ---- PowerShell Academy ------------------------------------------------------
func _paint_learn() -> void:
    var body := _window("POWERSHELL ACADEMY", Color("012456"))
    _fill(body, Color("f3f6fb"))
    if learn_lesson >= 0:
        _paint_quiz(body)
        return
    var chars := int((body.size.x - 8) / 4.0)
    _text(_clip("LEVEL %d OF 5. EACH LEVEL: FASTER, MORE RELIABLE FIXES." % Skills.ps_level, chars), body.position + Vector2(4, 3), Color("012456"))
    for i in Skills.LESSONS.size():
        var rr := Rect2(body.position.x + 3, body.position.y + 12 + float(i) * 11.0, body.size.x - 6, 10)
        var state := "DONE" if i < Skills.ps_level else ("START" if i == Skills.ps_level else "LOCKED")
        _row(rr, false, i % 2 == 1)
        var title := "%d. %s" % [i + 1, Skills.LESSONS[i].title]
        _text(title, rr.position + Vector2(3, 2), TXT if state != "LOCKED" else Color("8b93a1"))
        var col := GREEN if state == "DONE" else (ORANGE if state == "START" else Color("8b93a1"))
        _text(state, Vector2(rr.end.x - _tw(state) - 4, rr.position.y + 2), col)
        if state == "START":
            _region("lesson:%d" % i, rr)
    var lv := Skills.ps_level
    var y := body.position.y + 12 + float(Skills.LESSONS.size()) * 11.0 + 4
    var perks := [
        "FIX TIME %.1fS   FAILS %d%%" % [float(Skills.FIX_SECS[lv]), int(float(Skills.FAIL[lv]) * 100.0)],
        "SCRIPTS: " + ("ALL CLIENTS" if lv >= 4 else ("ONE CLIENT" if lv >= 2 else "NONE YET (LEVEL 2)")),
    ]
    for line in perks:
        _text(_clip(line, chars), Vector2(body.position.x + 4, y), Color("46506a"))
        y += 7


func _paint_quiz(body: Rect2) -> void:
    var lesson: Dictionary = Skills.LESSONS[learn_lesson]
    var chars := int((body.size.x - 8) / 4.0)
    var head := "%s - RESULT" % lesson.title if learn_done else "%s - QUESTION %d OF 3" % [lesson.title, mini(learn_q + 1, 3)]
    _text(_clip(head, chars), body.position + Vector2(4, 3), Color("012456"))
    if learn_done:
        var passed := learn_right >= 2
        _text("%d OF 3 RIGHT" % learn_right, body.position + Vector2(4, 16), TXT)
        _text("PASSED! LEVEL UP." if passed else "NOT QUITE. NEED 2 OF 3.", body.position + Vector2(4, 26), GREEN if passed else RED)
        _button("lback", Rect2(body.position.x + 4, body.position.y + 40, 40, 9), "BACK")
        return
    var q: Array = lesson.qs[learn_q]
    var y := body.position.y + 14
    for line in _wrap(str(q[0]), chars):
        _text(line, Vector2(body.position.x + 4, y), TXT)
        y += 7
    y += 3
    for k in learn_opts.size():
        var tint := BTN
        if learn_pick >= 0 and learn_opts[k] == q[1]:
            tint = Color("9bd6a8")
        elif learn_pick == k:
            tint = Color("e8a39b")
        _button("ans:%d" % k, Rect2(body.position.x + 4, y + float(k) * 11.0, body.size.x - 8, 10), _clip(str(learn_opts[k]), chars - 2), learn_pick < 0, tint)
    if learn_pick >= 0:
        _button("qnext", Rect2(body.end.x - 40, body.end.y - 12, 36, 9), "NEXT", true, Color("9fd8ff"))


# ---- profile / stats -----------------------------------------------------------
# ---- Lynk 2013 ------------------------------------------------------------
func _paint_lync() -> void:
    var body := _window("LYNK 2013", Color("0a6ab8"))
    _fill(body, WHITE)
    if Net.desk_state(desk) == "no_link":
        _text("LYNK CANNOT SIGN IN. NO NETWORK CABLE.", body.position + Vector2(6, 8), RED)
        return
    var contacts: Array = Lync.contacts()
    var narrow := body.size.x < 250.0
    var list_w := body.size.x if (narrow and lync_sel == "") else (0.0 if narrow else 104.0)
    if list_w > 0.0:
        for i in contacts.size():
            var who: String = contacts[i]
            var info: Array = Lync.presence(who)
            var rr := Rect2(body.position.x, body.position.y + float(i) * 11.0, list_w, 11)
            _row(rr, who == lync_sel, i % 2 == 1)
            _fill(Rect2(rr.position.x + 3, rr.position.y + 3, 5, 5), Lync.color_of(str(info[1])))
            _text(who.to_upper(), rr.position + Vector2(11, 3), TXT)
            _text(_clip(str(info[0]), int((list_w - 56) / 4.0)), rr.position + Vector2(50, 3), Color("7d8595"))
            var n := int(Lync.unread.get(who, 0))
            if n > 0:
                _fill(Rect2(rr.end.x - 11, rr.position.y + 2, 9, 7), RED)
                _text(str(mini(n, 9)), rr.position + Vector2(rr.size.x - 8, 3), WHITE)
            _region("lync:contact:" + who, rr)
    if lync_sel == "" or list_w >= body.size.x:
        if lync_sel == "" and not narrow:
            _text("PICK A CONTACT", body.position + Vector2(list_w + 6, 8), Color("8b93a1"))
        return
    var x := body.position.x + list_w
    var w := body.end.x - x
    _fill(Rect2(x, body.position.y, w, body.size.y), Color("f1f4f8"))
    var info2: Array = Lync.presence(lync_sel)
    Lync.mark_read(lync_sel)
    _text(_clip("%s%s - %s" % [lync_sel.to_upper(), " (OWNER)" if Social.is_owner(lync_sel) else "", str(info2[0])], int((w - 40) / 4.0)), Vector2(x + 4, body.position.y + 3), Color("0a6ab8"))
    if narrow:
        _button("lync:back", Rect2(body.end.x - 28, body.position.y + 1, 26, 8), "BACK")
    var chars := int((w - 8) / 4.0)
    var lines: Array = []
    for entry in Lync.chats.get(lync_sel, []):
        for part in _wrap(str(entry[1]), chars - 3):
            lines.append([str(entry[0]), part])
    var rows := int((body.size.y - 38) / 7.0)
    var y := body.position.y + 13
    for i in range(maxi(0, lines.size() - rows), lines.size()):
        var mine: bool = lines[i][0] == "me"
        _text(("> " if mine else "") + str(lines[i][1]), Vector2(x + 4, y), Color("0a6ab8") if mine else TXT)
        y += 7
    var by := body.end.y - 11
    if Lync.pending.has(lync_sel):
        var opts: Array = Lync.pending[lync_sel].options
        var bw := floorf((w - 6) / float(maxi(1, opts.size())))
        for i in opts.size():
            _button("lync:reply:%d" % i, Rect2(x + 3 + float(i) * bw, by, bw - 2, 9), _clip(str(opts[i].label), int((bw - 6) / 4.0)))
        return
    var acts := [["lunch", "LUNCH?"], ["help", "NEED A HAND"], ["thanks", "THANKS!"]]
    if lync_sel == Lync.boss():
        acts = [["boss", "ANY ADVICE?" if lync_sel == "Morgan" else "HOW ARE WE DOING?"]]
    var aw := floorf((w - 6) / float(acts.size()))
    for i in acts.size():
        _button("lync:act:" + str(acts[i][0]), Rect2(x + 3 + float(i) * aw, by, aw - 2, 9), str(acts[i][1]))


func _lync_action(parts: PackedStringArray) -> void:
    match parts[1]:
        "contact":
            lync_sel = parts[2]
            Lync.open_chat(lync_sel)
        "back":
            lync_sel = ""
        "reply":
            Lync.reply(lync_sel, int(parts[2]))
        "act":
            Lync.send_action(lync_sel, parts[2])


# ---- LabRat Nerds: forum + IRC ------------------------------------------------------
func _paint_nerds() -> void:
    var body := _window("LABRAT NERDS - COMMUNITY", Color("c0561a"))
    _fill(body, WHITE)
    if Net.desk_state(desk) != "ok":
        _text("THE FORUM NEEDS THE INTERNET.", body.position + Vector2(6, 8), AMBER)
        return
    Nerds.ensure_threads()
    _fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("f0d9c4"))
    _button("nerds:tab:forum", Rect2(body.position.x + 2, body.position.y + 1, 36, 8), "FORUM", true, BTN_HI if nerds_tab == "forum" else BTN)
    _button("nerds:tab:irc", Rect2(body.position.x + 40, body.position.y + 1, 52, 8), "IRC CHAT", true, BTN_HI if nerds_tab == "irc" else BTN)
    _text("KARMA %d  %s" % [Nerds.karma, Nerds.rank()], Vector2(body.end.x - 76, body.position.y + 2), Color("c0561a"))
    var area := Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
    if nerds_tab == "irc":
        _paint_irc(area)
        return
    var chars := int((area.size.x - 62) / 4.0)
    var y := area.position.y + 3
    for i in Nerds.threads.size():
        var th: Dictionary = Nerds.threads[i]
        var def: Dictionary = Nerds.THREADS[int(th.id)]
        var rr := Rect2(area.position.x, y, area.size.x, 11)
        _row(rr, false, i % 2 == 1)
        var tag := "ANSWERED" if th.answered else ("READ" if th.read else "NEW")
        _text(_clip(str(def.title), chars), rr.position + Vector2(3, 3), TXT if not th.read else Color("7d8595"))
        _text(tag, Vector2(rr.end.x - 58, rr.position.y + 3), GREEN if th.answered else (Color("7d8595") if th.read else ORANGE))
        _button("nerds:read:%d" % i, Rect2(rr.end.x - 32, rr.position.y + 1, 14, 9), "R", not th.read)
        _button("nerds:answer:%d" % i, Rect2(rr.end.x - 16, rr.position.y + 1, 14, 9), "A", not th.answered)
        y += 12
    _text("R = READ (A LITTLE XP)   A = ANSWER (NEEDS THE SKILL: MORE XP + KARMA)", Vector2(area.position.x + 4, y + 2), Color("7d8595"))


func _paint_irc(area: Rect2) -> void:
    var chars := int((area.size.x - 8) / 4.0)
    _text("#LABRATNERDS   6 NERDS ONLINE", area.position + Vector2(4, 3), Color("c0561a"))
    var rows := int((area.size.y - 38) / 7.0)
    var lines: Array = []
    for entry in Nerds.channel:
        for part in _wrap("%s: %s" % [str(entry[0]), str(entry[1])], chars):
            lines.append([str(entry[0]), part])
    var y := area.position.y + 12
    for i in range(maxi(0, lines.size() - rows), lines.size()):
        var nick := str(lines[i][0])
        var color: Color = Nerds.NICKS[nick].color if Nerds.NICKS.has(nick) else (BTN_SH if nick != "you" else Color("0a6ab8"))
        _text(lines[i][1], Vector2(area.position.x + 4, y), color)
        y += 7
    var by := area.end.y - 21
    var hint: Dictionary = Nerds.hint
    if not hint.is_empty() and not bool(hint.get("pending", false)):
        _text(_clip("VERDICT: %s (%d OF %d AGREE)" % [str(hint.best).to_upper(), int(hint.votes), int(hint.total)], chars), Vector2(area.position.x + 4, by - 8), GREEN)
    var wait := Nerds.cooldown_left()
    var ask_ready := Nerds.can_ask()
    var label := "ASK ABOUT THIS TICKET" if ask_ready else "WAIT %ds" % int(ceilf(wait))
    _button("nerds:ask:ticket", Rect2(area.position.x + 3, by + 9, area.size.x * 0.5 - 4, 9), label, ask_ready)
    _button("nerds:ask:step", Rect2(area.position.x + area.size.x * 0.5 + 1, by + 9, area.size.x * 0.5 - 4, 9), "ASK ABOUT THE JOB" if ask_ready else "...", ask_ready and Playbook.is_active())


func _nerds_action(parts: PackedStringArray) -> void:
    match parts[1]:
        "tab":
            nerds_tab = parts[2]
        "read":
            Nerds.read_thread(int(parts[2]))
        "answer":
            _say(Nerds.answer_thread(int(parts[2])))
        "ask":
            if parts[2] == "step":
                Nerds.ask_step()
            else:
                var t := Msp.ticket(psa_sel) if psa_sel > 0 else {}
                if t.is_empty() or t.status == "Closed":
                    var open := Msp.open_tickets()
                    t = open[0] if not open.is_empty() else {}
                Nerds.ask_ticket(t)


func _paint_boardroom() -> void:
    var body := _window("BOARDROOM - " + Msp.COMPANY, Color("6b421c"))
    _fill(body, Color("f3f6fb"))
    var tabs := [["books", "BOOKS"], ["clients", "CLIENTS"], ["projects", "PROJECTS"], ["team", "TEAM"], ["stack", "STACK"]]
    var tab_w := minf(42.0, (body.size.x - 4.0) / float(tabs.size()))
    _fill(Rect2(body.position, Vector2(body.size.x, 9)), Color("e4d9c9"))
    for i in tabs.size():
        var tint := BTN_HI if board_tab == tabs[i][0] else BTN
        var tab_label: String = tabs[i][1] if tab_w >= 40.0 or tabs[i][0] != "projects" else "PROJ"
        _button("btab:" + tabs[i][0], Rect2(body.position.x + 2 + float(i) * tab_w, body.position.y + 1, tab_w - 2.0, 8), tab_label, true, tint)
    var area := Rect2(body.position + Vector2(0, 9), body.size - Vector2(0, 9))
    match board_tab:
        "clients":
            _board_clients(area)
        "projects":
            _board_projects(area)
        "team":
            _board_team(area)
        "stack":
            _board_stack(area)
        _:
            _board_books(area)


func _board_rows(rows: Array, x: float, y: float, value_x: float, limit: int) -> float:
    for row in rows:
        _text(str(row[0]), Vector2(x, y), Color("46506a"))
        _text(_clip(str(row[1]), limit), Vector2(x + value_x, y), row[2])
        y += 7
    return y


func _board_books(a: Rect2) -> void:
    var est := Owner.weekly_estimate()
    var two := a.size.x >= 300.0
    var x := a.position.x + 4
    var y := a.position.y + 3
    var value_x := 58.0 if two else minf(104.0, a.size.x * 0.55)
    var room := int((a.size.x * (0.5 if two else 1.0) - value_x - 8.0) / 4.0)
    var w2_ok: bool = float(est.w2) <= Owner.W2_TARGET
    var margin_ok: bool = float(est.margin) >= Owner.PEER_MARGIN
    var left := [
        ["CASH", "$%d" % Owner.cash, GREEN if Owner.cash >= 0 else RED],
        ["REVENUE/WEEK", "$%d" % int(est.revenue), TXT],
        ["PAYROLL (W-2)", "-$%d" % int(est.payroll), TXT],
        ["W-2 RATIO", "%d%% (TARGET %d%%)" % [int(100.0 * float(est.w2)), int(100.0 * Owner.W2_TARGET)], GREEN if w2_ok else RED],
        ["OTHER COSTS", "-$%d" % int(est.fixed), TXT],
        ["MARKETING", "-$%d" % int(est.marketing), TXT],
        ["EBITDA", "$%d" % int(est.ebitda), GREEN if int(est.ebitda) >= 0 else RED],
        ["MARGIN", "%d%% (PEERS %d%%)" % [int(100.0 * float(est.margin)), int(100.0 * Owner.PEER_MARGIN)], GREEN if margin_ok else AMBER],
    ]
    y = _board_rows(left, x, y, value_x, room)
    var advisers := []
    if Owner.flags.get("peer_group", false):
        advisers.append("PEERS")
    if Owner.flags.get("mentor", false):
        advisers.append("DANA")
    if Owner.flags.get("backup_service", false):
        advisers.append("BACKUP SVC")
    var right := [
        ["WEEK", "%d OF %d" % [Campaign.day, Campaign.TOTAL_DAYS], TXT],
        ["A/R OWED", "$%d" % Owner.ar_total(), AMBER if Owner.ar_total() > 0 else TXT],
        ["COMPANY VALUE", "$%d (%.1fX)" % [Owner.valuation(), Owner.multiple()], Color("6b421c")],
        ["TEAM SPEED", "%.1f" % Owner.team_speed(), TXT],
        ["ON BOARD", ", ".join(advisers) if not advisers.is_empty() else "NOBODY YET", TXT],
        ["MATURITY", "%d %s" % [Owner.oml(), Owner.OML_NAMES[Owner.oml() - 1]], Color("6b421c")],
    ]
    right.append(["PATH", Owner.path_label(), Color("6b421c")])
    if Campaign.day >= 6 and not Owner.flags.get("rdp_safe", false):
        right.append(["RDP", "WEAK" if Owner.flags.get("rdp_weak", false) else "OPEN TO THE INTERNET", RED])
    if Owner.at_risk_count() > 0:
        right.append(["POACH RISK", "%d CLIENT(S) AT RISK" % Owner.at_risk_count(), RED])
    if two:
        _board_rows(right, a.position.x + a.size.x * 0.5 + 4, a.position.y + 3, 58.0, room)
    else:
        _board_rows(right, x, y + 3, value_x, room)


func _board_clients(a: Rect2) -> void:
    var x := a.position.x + 4
    var y := a.position.y + 3
    _text("CLIENT   FEE/WEEK   MOOD   PROFIT" + ("   HOURS" if a.size.x >= 300.0 else ""), Vector2(x, y), Color("6b421c"))
    y += 8
    for i in mini(Sales.active.size(), int((a.end.y - y) / 7.0)):
        var c: int = Sales.active[i]
        _text(_clip(str(Msp.CLIENTS[c].short), 5), Vector2(x, y), TXT)
        _text("$%d" % Owner.client_fee(c), Vector2(x + 24, y), Color("46506a"))
        var meter := Rect2(x + 58, y, 36, 5)
        _fill(meter, Color("c9d2e0"))
        var happy := Sales.mood(c)
        _fill(Rect2(meter.position, Vector2(meter.size.x * float(happy) / 100.0, 5)), GREEN if happy >= 55 else (AMBER if happy >= 30 else RED))
        var profit := Owner.client_profit(c)
        _text("%s$%d" % ["+" if profit >= 0 else "-", absi(profit)], Vector2(x + 98, y), GREEN if profit >= 0 else RED)
        var wide := a.size.x >= 300.0
        if wide:
            var over := Projects.over_hours(c)
            var hrs := "%dH" % int(Projects.avg_hours(c)) + ((" +%d" % int(over)) if over >= 3.0 else "")
            _text(hrs, Vector2(x + 132, y), RED if over >= 3.0 else Color("46506a"))
        var tag := ""
        if Owner.overdue(c):
            tag = "LATE $%d" % Owner.ar_total(c)
        elif Owner.pay_delay(c) > 0:
            tag = "PAYS SLOW"
        var due := Owner.review_due(c)
        var shown := tag
        if shown == "":
            shown = "AT RISK" if Owner.poach_risk(c) >= 0.12 else ("REVIEW DUE" if due else "")
        var letters := ("B" if not Msp.backups[c].ok else "") + ("P" if float(Owner.patch_debt.get(c, 0.0)) >= 4.0 else "") + ("M" if Sales.mood(c) < 50 else "")
        if letters != "":
            shown += " GAPS " + letters
        _text(_clip(shown, int((a.end.x - x - (174 if wide else 134)) / 4.0)), Vector2(x + (172 if wide else 132), y), AMBER if shown != "" else Color("46506a"))
        y += 7
    if not Owner.gone.is_empty() and y < a.end.y - 6:
        var names := []
        for lost_client in Owner.gone:
            names.append(str(Msp.CLIENTS[int(lost_client)].short))
        _text(_clip("LOST TO " + Owner.COMPETITOR.to_upper() + ": " + ", ".join(names), int((a.size.x - 8) / 4.0)), Vector2(x, y + 2), RED)


func _board_projects(a: Rect2) -> void:
    var x := a.position.x + 4
    var y := a.position.y + 3
    var limit := int((a.size.x - 8.0) / 4.0)
    var est := Owner.weekly_estimate()
    _text(_clip("RECURRING $%d/WK" % int(est.revenue), limit), Vector2(x, y), Color("6b421c"))
    y += 7
    _text(_clip("SERVICES $%d/WK   DONE %d JOBS, $%d" % [Projects.service_revenue(), Projects.completed_count, Projects.completed_profit], limit), Vector2(x, y), Color("6b421c"))
    y += 8
    var shown := 0
    for p in Projects.projects:
        if y > a.end.y - 14:
            break
        if p.status != "active" and shown >= 2 and p.status != "done":
            continue
        var left := "WEEK %d/%d" % [int(p.total) - int(p.weeks), int(p.total)] if p.status == "active" else str(p.status).to_upper()
        var money := ("EST $%d" % Projects.quote_profit({"price": p.price, "hw": p.hw, "est": p.est})) if p.status == "active" else ("%s$%d" % ["+" if int(p.profit) >= 0 else "-", absi(int(p.profit))])
        var color := RED if (p.status == "lost" or (p.status == "done" and int(p.profit) < 0) or bool(p.creep)) else (GREEN if p.status == "done" else TXT)
        _text(_clip("%s %s %s %s%s" % [str(Msp.CLIENTS[int(p.client)].short), str(Projects.TYPES[str(p.type)].label).split(" (")[0], left, money, " CREEP" if bool(p.creep) else ""], limit), Vector2(x, y), color)
        y += 7
        shown += 1
    if Projects.projects.is_empty():
        _text(_clip("NO PROJECTS YET. VIC BRINGS THEM IN: DESKTOPS, NETWORKS, SERVERS, SECURITY.", limit), Vector2(x, y), Color("46506a"))
        y += 7
    y += 3
    var drag := int(Projects.drag() * 100.0)
    _text(_clip("TEAM TIME ON PROJECTS %d%%" % drag, limit), Vector2(x, y), Color("46506a"))
    y += 7
    _text(_clip("BAD WORD OF MOUTH: %s" % (("%d WK" % Projects.wom_weeks) if Projects.wom_weeks > 0 else "NONE"), limit), Vector2(x, y), RED if Projects.wom_weeks > 0 else Color("46506a"))


func _board_team(a: Rect2) -> void:
    var x := a.position.x + 4
    var y := a.position.y + 3
    var limit := int((a.size.x - 8.0) / 4.0)
    var names := ["ALAN", "GARRISON", "DAN"]
    var rows := []
    for i in maxi(0, 3 - Owner.lost_techs):
        rows.append(["%s  SKILL 1.0  $%d/WK" % [names[i], Owner.tech_wage()], TXT])
    for hire in Owner.extra_staff:
        var tag := str(Owner.TRAITS[hire.get("trait", "steady")].label)
        rows.append(["%s  %.2f  $%d/WK  %s" % [str(hire.name).to_upper(), float(hire.skill), Owner.hire_wage(hire), tag], TXT])
    var plan: Dictionary = Owner.VIC_PLANS[Owner.vic_plan]
    rows.append(["VIC  %s  $%d/WK + $%d A DEAL" % [plan.label, int(plan.wage), int(plan.per_deal)], Color("6b421c")])
    var moods := Owner.vic_new_client_mood()
    rows.append(["VIC DEALS %d  NEW CLIENT MOOD %s" % [Owner.vic_deals, "-" if moods < 0 else "%d%%" % moods], TXT])
    var morale := Owner.stack_sum("morale")
    rows.append(["MORALE FROM TOOLS %+d%%" % int(morale), GREEN if morale >= 0.0 else RED])
    rows.append(["BURNOUT %d%%" % int(Owner.burnout), GREEN if Owner.burnout < 40.0 else (AMBER if Owner.burnout < 70.0 else RED)])
    for line in Growth.board_lines():
        rows.append(line)
    for row in rows:
        if y > a.end.y - 7:
            break
        _text(_clip(str(row[0]), limit), Vector2(x, y), row[1])
        y += 7


func _board_stack(a: Rect2) -> void:
    var x := a.position.x + 4
    var y := a.position.y + 3
    var limit := int((a.size.x - 8.0) / 4.0)
    for category in Owner.STACK:
        var option: Dictionary = Owner.stack_option(str(category))
        _text(_clip("%s: %s  $%d/WK" % [Owner.STACK[category].label, str(option.name).to_upper(), int(option.get("cost", 0))], limit), Vector2(x, y), Color("6b421c"))
        y += 7
        var fx := []
        if option.has("speed") and float(option.speed) != 0.0:
            fx.append("SPEED %+d%%" % int(100.0 * float(option.speed)))
        if option.has("morale") and int(option.morale) != 0:
            fx.append("MORALE %+d%%" % int(option.morale))
        if option.has("issues") and float(option.issues) != 1.0:
            fx.append("TICKETS %+d%%" % int(100.0 * (float(option.issues) - 1.0)))
        if option.has("sales") and float(option.sales) != 0.0:
            fx.append("SALES %+d%%" % int(100.0 * float(option.sales)))
        if option.has("margin"):
            fx.append("$%d A DEAL" % int(option.margin))
        _text(_clip("  " + str(option.note) + (": " + ", ".join(fx) if not fx.is_empty() else ""), limit), Vector2(x, y), Color("46506a"))
        y += 8
    _text(_clip("TOOLS $%d/WK   TICKET LOAD x%.2f" % [Owner.stack_cost(), Owner.issue_mult()], limit), Vector2(x, y), TXT)


func _mood_color(who: String) -> Color:
    if Social.is_friendly(who):
        return GREEN
    if Social.is_hostile(who):
        return RED
    return AMBER if Social.is_cold(who) else Color("7d8595")


func _paint_stats() -> void:
    var body := _window("PROFILE - " + Msp.COMPANY, Color("2f6b4f"))
    _fill(body, Color("f3f6fb"))
    var two_cols := body.size.x >= 300.0
    var y := body.position.y + 4
    var bar_w := minf(70.0, body.size.x * 0.5 - 96.0) if two_cols else minf(70.0, body.size.x - 96.0)
    for key in Skills.NAMES:
        _text(str(Skills.NAMES[key]), Vector2(body.position.x + 4, y), TXT)
        _text("LV %d" % Skills.level(key), Vector2(body.position.x + 60, y), ORANGE)
        var bar := Rect2(body.position.x + 84, y, bar_w, 5)
        _fill(bar, Color("c9d2e0"))
        _fill(Rect2(bar.position, Vector2(bar.size.x * Skills.progress(key), 5)), GREEN)
        y += 9
    var x := body.position.x + 4
    if two_cols:
        x = body.position.x + body.size.x * 0.5 + 4
        y = body.position.y + 4
    else:
        y += 4
    _text("OWNERS AND TEAM", Vector2(x, y), Color("2f6b4f"))
    y += 8
    for who in Social.PEOPLE:
        _text(who, Vector2(x, y), TXT)
        _text(Social.mood(who), Vector2(x + 44, y), _mood_color(who))
        var meter := Rect2(x + 92, y, 40, 5)
        _fill(meter, Color("c9d2e0"))
        _fill(Rect2(meter.position, Vector2(meter.size.x * float(Social.value(who) + 100) / 200.0, 5)), _mood_color(who))
        y += 8
    y += 4
    var lines := []
    if Campaign.active:
        lines.append("DAY %d OF %d   REPUTATION %d   CASH $%d" % [Campaign.day, Campaign.TOTAL_DAYS, Campaign.rep, Campaign.cash])
    else:
        lines.append("FREE PLAY")
    lines.append("CLOSED %d  SLA MISSED %d  REOPENED %d" % [Msp.closed_ok, Msp.breached, Msp.reopened])
    lines.append("SCORE %d   PHONE CALLS %d" % [Msp.score, Social.calls_answered])
    if Campaign.active and Campaign.mode == "tech" and Expo.invited and not Expo.decided:
        lines.append("RODENT NATION: %d OF 4 KPIS MET (NEED %d)" % [Expo.passed(), Expo.NEED])
        for k in Expo.kpis():
            if not bool(k.ok):
                lines.append("  STILL NEEDED: %s (NOW %s)" % [str(k.name), str(k.now)])
    elif Campaign.active and Campaign.mode == "tech" and Expo.decided:
        lines.append("RODENT NATION: %s" % ("YOU WENT" if Expo.qualified else "NOT THIS YEAR"))
    lines.append("CLIENTS %d   HAPPINESS %d%%" % [Sales.active.size(), int(Sales.average())])
    if Shift.active():
        lines.append("ENERGY %d%% (%s)%s" % [int(Shift.energy), Shift.label(), "  ON CALL" if Shift.is_on_call() else ""])
        lines.append(Shift.summary())
    if Growth.status_line() != "":
        lines.append(Growth.status_line())
    if Campaign.active and Skills.next_perk() != "":
        lines.append(Skills.next_perk())
    for line in lines:
        _text(_clip(line, int((body.end.x - x - 4) / 4.0)), Vector2(x, y), Color("46506a"))
        y += 7
''')

write("scripts/phone.gd", '''extends CanvasLayer
# The cell phone (2013): press P. The first time you pick iFone 5 (slate phone, iOS-style look) or Nexxus 5
# (Android-style look); the choice is saved and can be changed in Settings. Like the computer it
# takes over the screen (the office stays visible in a faded strip at the top). Apps: Mail (the
# same inbox as Outlookish), Tickets (a small ConnectWhy PSA: look, take, note), Texts (dispatch
# and the boss text you about urgent tickets) and Settings. The phone is on cellular, so it still
# works when the office network is down. Everything is drawn in code with the pixel font.

const PixelFont := preload("res://scripts/pixelfont.gd")
const SAVE := "user://mspsim_phone.cfg"
const INK := Color("17121f")
const WHITE := Color("ffffff")
const RED := Color("e0463c")
const GREEN := Color("3cc15a")
const NOTES := ["Texted the client back.", "On my way in.", "Looking at it from my phone."]

var is_open := false
var os := ""  # "ios" or "android"; "" = not chosen yet
var app := "home"
var mail_sel := -1
var tk_sel := -1
var txt_open := false
var home_sel := 0  # keyboard selection on the home screen (0 mail, 1 tickets, 2 texts, 3 settings)
const HOME_APPS := ["mail", "tickets", "texts", "settings"]

var _canvas: Node2D
var _hits: Array = []
var _mouse := Vector2.ZERO
var _fade := 0.0
var _sc := 1
var _toast := ""
var _toast_t := 0.0
var _blink := 0.0


func _ready() -> void:
    layer = 61
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)
    Msp.changed.connect(_refresh)
    var cfg := ConfigFile.new()
    if cfg.load(SAVE) == OK:
        os = str(cfg.get_value("phone", "os", ""))


func _save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("phone", "os", os)
    cfg.save(SAVE)


# the phone chosen on the character select screen (same saved preference as the first-open picker)
func set_os(value: String) -> void:
    os = value
    _save()


func open() -> void:
    if is_open or Game.ui_open or Game.busy or Game.title_mode:
        return
    app = "home" if os != "" else "choose"
    mail_sel = -1
    tk_sel = -1
    txt_open = false
    is_open = true
    Game.ui_open = true
    _canvas.visible = true
    _mouse = get_viewport().get_mouse_position()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    create_tween().tween_method(_set_fade, _fade, 1.0, 0.2)


func close() -> void:
    is_open = false
    Game.ui_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var tween := create_tween()
    tween.tween_method(_set_fade, _fade, 0.0, 0.15)
    tween.tween_callback(func() -> void: _canvas.visible = is_open)


func _set_fade(value: float) -> void:
    _fade = value
    Game.ui_shift = value
    _canvas.modulate.a = value


func _refresh() -> void:
    if is_open:
        _canvas.queue_redraw()


func _process(delta: float) -> void:
    _blink += delta
    _toast_t = maxf(0.0, _toast_t - delta)
    if is_open and _blink > 0.4:
        _blink = 0.0
        _canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if not is_open and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_P:
            open()
            get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventMouseMotion:
        _mouse = get_viewport().get_mouse_position()
        _canvas.queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse = get_viewport().get_mouse_position()
        click(_mouse)
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_ESCAPE:
                back()
            KEY_P:
                close()
            KEY_UP:
                move(-1)
            KEY_DOWN:
                move(1)
            KEY_LEFT, KEY_RIGHT:
                if app == "choose":
                    activate("os:" + ("android" if event.keycode == KEY_RIGHT else "ios"))
                elif app == "home":
                    home_move(1 if event.keycode == KEY_RIGHT else -1)
                elif app == "settings":
                    activate("ring")
            KEY_ENTER, KEY_KP_ENTER:
                enter()
    else:
        return
    get_viewport().set_input_as_handled()


# ---- actions (also used by the tests) ----------------------------------------
func click(at: Vector2) -> void:
    for i in range(_hits.size() - 1, -1, -1):
        var h: Dictionary = _hits[i]
        if h.r.has_point(at):
            activate(h.id)
            return


func back() -> void:
    if app == "home" or app == "choose":
        close()
    elif app == "mail" and mail_sel >= 0:
        mail_sel = -1
    elif app == "tickets" and tk_sel >= 0:
        tk_sel = -1
    elif app == "texts" and txt_open:
        txt_open = false
    else:
        app = "home"
    _canvas.queue_redraw()


func home_move(step: int) -> void:
    home_sel = clampi(home_sel + step, 0, HOME_APPS.size() - 1)
    _canvas.queue_redraw()


func move(step: int) -> void:
    if app == "home":
        home_move(step * 2)  # two icons per row
        return
    if app == "mail":
        mail_sel = clampi(mail_sel + step, 0, maxi(0, Msp.emails.size() - 1))
    elif app == "tickets":
        var list := Msp.open_tickets()
        if not list.is_empty():
            var at := 0
            for i in list.size():
                if list[i].id == tk_sel:
                    at = i
            tk_sel = list[clampi(at + step, 0, list.size() - 1)].id
    _canvas.queue_redraw()


func enter() -> void:
    if app == "choose":
        activate("os:ios")
    elif app == "home":
        activate("app:" + str(HOME_APPS[home_sel]))
    elif app == "settings":
        activate("career")
    elif app == "mail" and mail_sel >= 0:
        activate("mail:%d" % mail_sel)


func activate(id: String) -> void:
    var parts := id.split(":")
    match parts[0]:
        "os":
            os = parts[1]
            _save()
            app = "home"
        "app":
            app = parts[1]
            mail_sel = -1
            tk_sel = -1
            txt_open = false
            if app == "texts":
                for m in Msp.texts:
                    m.unread = false
        "home":
            app = "home"
        "ring":
            Career.cycle_pick("ringtone")
        "career":
            close()
            Career.open_screen()
        "back":
            back()
        "mail":
            mail_sel = int(parts[1])
            Msp.emails[mail_sel].unread = false
        "tk":
            tk_sel = int(parts[1])
        "take":
            Msp.set_status(tk_sel, "In Progress")
            _say("TICKET #%d TAKEN" % tk_sel)
        "note":
            Msp.add_note(tk_sel, NOTES[randi() % NOTES.size()])
            _say("NOTE ADDED")
        "txt":
            txt_open = true
        "reply":
            _say("TEXT SENT")
        "desk":
            _say("CLOSING TICKETS NEEDS A COMPUTER")
    _canvas.queue_redraw()


func _say(text: String) -> void:
    _toast = text
    _toast_t = 2.5


# ---- drawing helpers ---------------------------------------------------------
func _fill(r: Rect2, c: Color) -> void:
    _canvas.draw_rect(r, c)


func _text(s: String, p: Vector2, c: Color = INK, scale := -1) -> void:
    PixelFont.draw(_canvas, s, p, c, _sc if scale < 0 else scale)


func _tw(s: String) -> float:
    return float(PixelFont.width(s, _sc))


func _chars(width: float) -> int:
    return maxi(4, int(width / (4.0 * _sc)))


func _clip(s: String, chars: int) -> String:
    return s if s.length() <= chars else s.substr(0, maxi(1, chars - 1)) + "."


func _wrap(s: String, chars: int) -> Array:
    var lines := []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            lines.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    lines.append(line)
    return lines


func _region(id: String, r: Rect2) -> void:
    _hits.append({"r": r, "id": id})


func _round(r: Rect2, c: Color) -> void:
    # a rect with its four corner pixels cut off
    _fill(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), c)
    _fill(Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), c)


func _disc(center: Vector2, rad: int, c: Color) -> void:
    for dy in range(-rad, rad + 1):
        var w := int(sqrt(float(rad * rad - dy * dy)) + 0.5)
        _fill(Rect2(center.x - w, center.y + dy, w * 2 + 1, 1), c)


func _is_ios() -> bool:
    return os == "ios"


# ---- the whole screen --------------------------------------------------------
func _paint() -> void:
    var size := get_viewport().get_visible_rect().size
    _hits.clear()
    _fill(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.7))
    var top := maxf(12.0, floorf(size.y * Game.UI_STRIP))
    _fill(Rect2(0, top - 1, size.x, 1), Color("0d1018"))
    if app == "choose":
        _paint_choose(Rect2(0, top, size.x, size.y - top))
        _cursor()
        return
    # the phone gets as much screen as it can (a little wider than the real one) so text fits
    var ptop := maxf(12.0, floorf(size.y * 0.17))
    var avail := size.y - ptop - 6.0
    var pw := minf(avail * 0.68, size.x - 8.0)
    var ph := minf(avail, pw / 0.68)
    var body := Rect2(floorf((size.x - pw) * 0.5), ptop + 3.0 + floorf((avail - ph) * 0.5), floorf(pw), floorf(ph))
    _sc = 2 if body.size.x >= 118.0 else 1
    var screen := _skin(body)
    _paint_screen(screen)
    if _toast_t > 0.0:
        var tx := screen.position.x + floorf((screen.size.x - _tw(_toast)) * 0.5)
        _fill(Rect2(tx - 3, screen.end.y - 22 * _sc, _tw(_toast) + 6, 7 * _sc + 2), Color(0, 0, 0, 0.8))
        _text(_toast, Vector2(tx, screen.end.y - 21 * _sc), WHITE)
    _cursor()


func _cursor() -> void:
    var m := _mouse.floor()
    for i in 6:
        _fill(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
    _fill(Rect2(m.x + 1, m.y + 2, 2, 2), WHITE)
    _fill(Rect2(m.x + 1, m.y + 1, 1, 1), WHITE)


# the phone body; returns the screen rect
func _skin(b: Rect2) -> Rect2:
    if _is_ios():
        _round(b, Color("9aa0a8"))  # aluminium edge
        _round(Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)), Color("1c1e23"))  # slate front
        _fill(Rect2(b.position.x + floorf(b.size.x * 0.5) - 5, b.position.y + 3, 10, 1), Color("55595f"))  # speaker
        _disc(Vector2(b.position.x + floorf(b.size.x * 0.5) + 8, b.position.y + 3), 1, Color("2e3138"))
        var hc := Vector2(b.position.x + floorf(b.size.x * 0.5), b.end.y - 6)
        _disc(hc, 3, Color("55595f"))
        _disc(hc, 2, Color("1c1e23"))
        _region("home", Rect2(hc - Vector2(4, 4), Vector2(9, 9)))
        return Rect2(b.position.x + 3, b.position.y + 7, b.size.x - 6, b.size.y - 7 - 12)
    _round(b, Color("3a3d44"))
    _round(Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)), Color("0e0f12"))  # matte black
    _fill(Rect2(b.position.x + floorf(b.size.x * 0.5) - 4, b.position.y + 2, 8, 1), Color("2a2c31"))
    return Rect2(b.position.x + 3, b.position.y + 5, b.size.x - 6, b.size.y - 5 - 4)


func _bar_h() -> float:
    return 7.0 * _sc


func _paint_screen(s: Rect2) -> void:
    var bg := _wallpaper(s) if app == "home" else _app_bg(s)
    _hits.append({"r": s, "id": "none"})
    var content := Rect2(s.position.x, s.position.y + _bar_h(), s.size.x, s.size.y - _bar_h())
    if not _is_ios():
        content.size.y -= 9.0 * _sc  # android nav bar
    _status_bar(s, bg)
    match app:
        "mail":
            _paint_mail(content)
        "tickets":
            _paint_tickets(content)
        "texts":
            _paint_texts(content)
        "settings":
            _paint_settings(content)
        _:
            _paint_home(content)
    if not _is_ios():
        _nav_bar(Rect2(s.position.x, s.end.y - 9.0 * _sc, s.size.x, 9.0 * _sc))


func _wallpaper(s: Rect2) -> bool:
    if _is_ios():
        for i in 12:
            var t := float(i) / 11.0
            _fill(Rect2(s.position.x, s.position.y + s.size.y * i / 12.0, s.size.x, s.size.y / 12.0 + 1.0), Color("2d6fd6").lerp(Color("a259c9"), t))
    else:
        for i in 12:
            var t := float(i) / 11.0
            _fill(Rect2(s.position.x, s.position.y + s.size.y * i / 12.0, s.size.x, s.size.y / 12.0 + 1.0), Color("0b2742").lerp(Color("03060d"), t))
        _fill(Rect2(s.position.x, s.position.y + s.size.y * 0.55, s.size.x, 1), Color("1d4f7a"))
    return true


func _app_bg(s: Rect2) -> bool:
    _fill(s, WHITE if _is_ios() else Color("f2f2f2"))
    return false


func _status_bar(s: Rect2, over_wallpaper: bool) -> void:
    var r := Rect2(s.position, Vector2(s.size.x, _bar_h()))
    var light := over_wallpaper or not _is_ios()
    if _is_ios():
        _fill(r, Color(0, 0, 0, 0.0) if over_wallpaper else Color("f7f7f9"))
    else:
        _fill(r, Color("000000"))
    var col := WHITE if light else INK
    var clock: String = World.clock_text()
    var y := r.position.y + _sc
    if _is_ios():
        for i in 5:
            _disc(Vector2(r.position.x + 3 + i * 2 * _sc, y + 2 * _sc), 0 if _sc == 1 else 1, col if i < 4 else Color(col, 0.4))
        _text(clock, Vector2(r.position.x + floorf((r.size.x - _tw(clock)) * 0.5), y), col)
        _fill(Rect2(r.end.x - 9 * _sc, y + _sc, 7 * _sc, 3 * _sc), col)
    else:
        _text(clock, Vector2(r.end.x - _tw(clock) - 2, y), col)
        _text("PITP", Vector2(r.position.x + 2, y), Color("9aa0a8"))
        _fill(Rect2(r.end.x - _tw(clock) - 4 - 6 * _sc, y + _sc, 4 * _sc, 3 * _sc), col)


func _nav_bar(r: Rect2) -> void:
    _fill(r, Color("000000"))
    var cy := r.position.y + r.size.y * 0.5
    var cx := r.position.x + r.size.x * 0.5
    var u := float(_sc)
    var nav := Color("e8e8e8")
    # back triangle, home circle, recents square
    for i in int(3 * u):
        _fill(Rect2(cx - r.size.x * 0.3 - 2 * u + i, cy - (3 * u - i), 1, (3 * u - i) * 2), nav)
    _fill(Rect2(cx - 2 * u, cy - 2 * u, 4 * u, 4 * u), Color("000000"))
    _disc(Vector2(cx, cy), int(2 * u), nav)
    _disc(Vector2(cx, cy), int(2 * u) - 1, Color("000000"))
    var sq := Rect2(cx + r.size.x * 0.3 - 2 * u, cy - 2 * u, 4 * u, 4 * u)
    _fill(sq, nav)
    _fill(Rect2(sq.position + Vector2(1, 1), sq.size - Vector2(2, 2)), Color("000000"))
    _region("back", Rect2(r.position.x, r.position.y, r.size.x * 0.34, r.size.y))
    _region("home", Rect2(r.position.x + r.size.x * 0.34, r.position.y, r.size.x * 0.33, r.size.y))


# ---- first run: pick a phone -------------------------------------------------
func _paint_choose(a: Rect2) -> void:
    _sc = 1
    var t := "PICK YOUR PHONE"
    _text(t, Vector2(floorf(a.position.x + (a.size.x - _tw(t)) * 0.5), a.position.y + 6), WHITE)
    var sub := "(YOU CAN CHANGE IT IN SETTINGS)"
    _text(sub, Vector2(floorf(a.position.x + (a.size.x - _tw(sub)) * 0.5), a.position.y + 14), Color("9aa8c0"))
    var h := minf(a.size.y - 40.0, 90.0)
    var w := floorf(h * 0.52)
    for i in 2:
        var ios := i == 0
        var x: float = floorf(a.position.x + a.size.x * 0.5) + (-w - 14 if ios else 14)
        var b := Rect2(x, a.position.y + 24, w, h)
        var hot := b.has_point(_mouse) or (_blink < 0.2 and false)
        _round(Rect2(b.position - Vector2(2, 2), b.size + Vector2(4, 4)), Color("e8c34a") if hot else Color(0, 0, 0, 0))
        _round(b, Color("9aa0a8") if ios else Color("3a3d44"))
        _round(Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)), Color("1c1e23") if ios else Color("0e0f12"))
        var scr := Rect2(b.position.x + 3, b.position.y + (7 if ios else 5), b.size.x - 6, b.size.y - (19 if ios else 9))
        _fill(scr, Color("4a78d6") if ios else Color("0b2742"))
        _fill(Rect2(scr.position.x + 2, scr.position.y + 3, scr.size.x - 4, 3), Color(1, 1, 1, 0.5))
        if ios:
            _disc(Vector2(b.position.x + w * 0.5, b.end.y - 6), 2, Color("55595f"))
        else:
            _fill(Rect2(scr.position.x, scr.end.y - 3, scr.size.x, 3), Color("000000"))
        var label: String = "IFONE 5" if ios else "NEXXUS 5"
        _text(label, Vector2(floorf(x + (w - _tw(label)) * 0.5), b.end.y + 5), WHITE)
        _region("os:" + ("ios" if ios else "android"), Rect2(b.position - Vector2(4, 4), Vector2(w + 8, h + 20)))


# ---- home --------------------------------------------------------------------
func _icon(kind: String, r: Rect2) -> void:
    var cols := {"mail": Color("3b8df0"), "tickets": Color("f0a030"), "texts": Color("3cc15a"), "settings": Color("8b919c")}
    if _is_ios():
        _round(r, cols[kind])
    else:
        _fill(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), Color(cols[kind], 0.9))
    var c := r.get_center()
    var u := float(_sc)
    match kind:
        "mail":
            _fill(Rect2(c.x - 4 * u, c.y - 2.5 * u, 8 * u, 5 * u), WHITE)
            for i in int(4 * u):
                _fill(Rect2(c.x - 4 * u + i, c.y - 2.5 * u + i * 0.6, 1, 1), Color("5a6a85"))
                _fill(Rect2(c.x + 3 * u - i, c.y - 2.5 * u + i * 0.6, 1, 1), Color("5a6a85"))
        "tickets":
            _fill(Rect2(c.x - 3 * u, c.y - 4 * u, 6 * u, 8 * u), WHITE)
            for i in 3:
                _fill(Rect2(c.x - 2 * u, c.y - 2.5 * u + i * 2.5 * u, 4 * u, u), Color("c98a1c"))
        "texts":
            _fill(Rect2(c.x - 4 * u, c.y - 3 * u, 8 * u, 5 * u), WHITE)
            _fill(Rect2(c.x - 3 * u, c.y + 2 * u, 2 * u, 2 * u), WHITE)
        _:
            _disc(c, int(3 * u), WHITE)
            _disc(c, int(u), cols["settings"])


func _paint_home(a: Rect2) -> void:
    var items := [["mail", "MAIL", Msp.unread()], ["tickets", "TICKETS", Msp.open_tickets().size()], ["texts", "TEXTS", Msp.unread_texts()], ["settings", "SETTINGS", 0]]
    var isz := 12.0 * _sc
    var cell_w := floorf(a.size.x / 2.0)
    for i in items.size():
        var cx := a.position.x + (i % 2) * cell_w + floorf((cell_w - isz) * 0.5)
        var cy := a.position.y + 6 * _sc + (i / 2) * (isz + 12 * _sc)
        var r := Rect2(cx, cy, isz, isz)
        if i == home_sel:
            _fill(Rect2(r.position - Vector2(3, 2), Vector2(isz + 6, isz + 10 * _sc)), Color(1, 1, 1, 0.35))
        _icon(items[i][0], r)
        var label: String = items[i][1]
        if _tw(label) > cell_w - 2.0:
            label = {"TICKETS": "TKTS", "SETTINGS": "SETUP", "TEXTS": "TEXT"}.get(label, label)
        _text(label, Vector2(floorf(cx + (isz - _tw(label)) * 0.5), cy + isz + _sc * 2), WHITE)
        if items[i][2] > 0:
            _disc(Vector2(r.end.x, r.position.y), 2 * _sc + 1, RED)
            if _sc == 1:
                _text(str(mini(9, items[i][2])), Vector2(r.end.x - 1, r.position.y - 2), WHITE)
        _region("app:" + items[i][0], Rect2(r.position - Vector2(4, 3), Vector2(isz + 8, isz + 13 * _sc)))
    # dock (iOS) or search bar (Android)
    if _is_ios():
        _fill(Rect2(a.position.x, a.end.y - 14 * _sc, a.size.x, 14 * _sc), Color(1, 1, 1, 0.22))
        var label := "PIXEL IT PARTNERS" if _chars(a.size.x - 4) >= 17 else "PIXEL IT"
        _text(_clip(label, _chars(a.size.x - 4)), Vector2(a.position.x + 3, a.end.y - 9 * _sc), WHITE)
    else:
        var bar := Rect2(a.position.x + 3, a.end.y - 12 * _sc, a.size.x - 6, 8 * _sc)
        _fill(bar, Color("eeeeee"))
        _text("GOOGOL", bar.position + Vector2(3, 1.5 * _sc), Color("4a7bd0"))


# ---- shared app chrome -------------------------------------------------------
func _header(a: Rect2, title: String, can_back: bool) -> Rect2:
    var h := 9.0 * _sc
    var bar := Rect2(a.position.x, a.position.y, a.size.x, h)
    _fill(bar, Color("f7f7f9") if _is_ios() else Color("33b5e5"))
    if _is_ios():
        _fill(Rect2(bar.position.x, bar.end.y - 1, bar.size.x, 1), Color("c8c8cc"))
    var col := INK if _is_ios() else WHITE
    _text(_clip(title, _chars(a.size.x - 24 * _sc)), Vector2(bar.position.x + floorf((bar.size.x - _tw(_clip(title, _chars(a.size.x - 24 * _sc)))) * 0.5) if _is_ios() else bar.position.x + 3 + (6 * _sc if can_back else 0), bar.position.y + 2 * _sc), col)
    if can_back:
        if _is_ios():
            _text("<", Vector2(bar.position.x + 2, bar.position.y + 2 * _sc), Color("2b79f0"))
        else:
            _text("<", Vector2(bar.position.x + 2, bar.position.y + 2 * _sc), WHITE)
        _region("back", Rect2(bar.position, Vector2(14 * _sc, h)))
    return Rect2(a.position.x, a.position.y + h, a.size.x, a.size.y - h)


func _row(r: Rect2, alt: bool) -> void:
    var col := WHITE if not alt else Color("f1f1f4")
    if r.has_point(_mouse):
        col = Color("dce8fa")
    _fill(r, col)
    _fill(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), Color("d8d8dc"))


# ---- mail --------------------------------------------------------------------
func _paint_mail(a: Rect2) -> void:
    var body := _header(a, "INBOX" if mail_sel < 0 else "MESSAGE", mail_sel >= 0)
    if mail_sel >= 0 and mail_sel < Msp.emails.size():
        var m: Dictionary = Msp.emails[mail_sel]
        var chars := _chars(body.size.x - 6)
        _fill(body, WHITE)
        var sender := str(m.from).split(" <")[0]
        _text(_clip(sender, chars), body.position + Vector2(3, 3 * _sc), Color("2b79f0") if _is_ios() else Color("0a7ea4"))
        var subject := _wrap(str(m.subject), chars)
        var n := mini(2, subject.size())
        for i in n:
            _text(str(subject[i]), body.position + Vector2(3, (11 + 7 * i) * _sc), INK)
        var top_y := (12 + 7 * n) * _sc
        var lines := _wrap(m.body, chars)
        for i in mini(lines.size(), int((body.size.y - top_y - 3 * _sc) / (7.0 * _sc))):
            _text(lines[i], body.position + Vector2(3, top_y + i * 7 * _sc), Color("46506a"))
        return
    var rh := 15.0 * _sc
    for i in mini(int(body.size.y / rh), Msp.emails.size()):
        var m: Dictionary = Msp.emails[i]
        var rr := Rect2(body.position.x, body.position.y + i * rh, body.size.x, rh)
        _row(rr, i % 2 == 1)
        if m.unread:
            _disc(rr.position + Vector2(3, rh * 0.5), maxi(1, _sc), Color("2b79f0"))
        var chars := _chars(rr.size.x - 10)
        _text(_clip(str(m.from).split(" <")[0], chars), rr.position + Vector2(8, 2 * _sc), INK)
        _text(_clip(m.subject, chars), rr.position + Vector2(8, 2 * _sc + 7 * _sc), Color("7d8595"))
        _region("mail:%d" % i, rr)


# ---- tickets -----------------------------------------------------------------
func _pri_color(pri: int) -> Color:
    return [RED, Color("e07b22"), Color("e0a030"), Color("7d8aa0")][clampi(pri, 1, 4) - 1]


func _mmss(secs: float) -> String:
    var s := maxi(0, int(secs))
    return "%d:%02d" % [s / 60, s % 60]


func _paint_tickets(a: Rect2) -> void:
    var t := Msp.ticket(tk_sel) if tk_sel >= 0 else {}
    var body := _header(a, "TICKETS" if t.is_empty() else "#%d" % t.id, not t.is_empty())
    if not t.is_empty():
        _paint_ticket(body, t)
        return
    var list := Msp.open_tickets()
    var rh := 15.0 * _sc
    for i in mini(int(body.size.y / rh), list.size()):
        var k: Dictionary = list[i]
        var rr := Rect2(body.position.x, body.position.y + i * rh, body.size.x, rh)
        _row(rr, i % 2 == 1)
        _fill(Rect2(rr.position.x, rr.position.y, 2, rh - 1), _pri_color(k.pri))
        var chars := _chars(rr.size.x - 8)
        _text(_clip(k.summary, chars), rr.position + Vector2(5, 2 * _sc), INK)
        var late: bool = k.breached or k.sla_left < 30.0
        var left := "LATE" if k.breached else _mmss(k.sla_left)
        var who := "PITP" if k.client < 0 else str(Msp.CLIENTS[k.client].short)
        _text(who + " " + left, rr.position + Vector2(5, 2 * _sc + 7 * _sc), RED if late else Color("7d8595"))
        _region("tk:%d" % k.id, rr)
    if list.is_empty():
        _fill(body, WHITE)
        _text("NO OPEN TICKETS", body.position + Vector2(4, 6 * _sc), Color("8b93a1"))


func _paint_ticket(body: Rect2, t: Dictionary) -> void:
    _fill(body, WHITE)
    var chars := _chars(body.size.x - 6)
    var y := body.position.y + 3 * _sc
    _fill(Rect2(body.position.x, body.position.y, body.size.x, 2), _pri_color(t.pri))
    var info := [_clip(Msp.client_text(t), chars), "P%d  %s" % [t.pri, str(t.status).to_upper()], "SLA " + ("LATE" if t.breached else _mmss(t.sla_left))]
    for s in info:
        _text(s, Vector2(body.position.x + 3, y), Color("2b79f0") if s == info[0] else INK)
        y += 7 * _sc
    y += 2 * _sc
    var lines := _wrap(t.body, chars)
    var room := int((body.end.y - 24 * _sc - y) / (7.0 * _sc))
    for i in mini(lines.size(), maxi(1, room)):
        _text(lines[i], Vector2(body.position.x + 3, y), Color("46506a"))
        y += 7 * _sc
    var bw := floorf((body.size.x - 8) / 3.0)
    for i in 3:
        var id: String = ["take", "note", "desk"][i]
        var label: String = ["TAKE", "NOTE", "DONE"][i]
        var r := Rect2(body.position.x + 2 + i * (bw + 2), body.end.y - 11 * _sc, bw, 9 * _sc)
        _fill(r, Color("2b79f0") if i < 2 else Color("9aa0a8"))
        _text(label, r.position + Vector2(floorf((bw - _tw(label)) * 0.5), 2 * _sc), WHITE)
        _region(id, r)


# ---- texts -------------------------------------------------------------------
func _paint_texts(a: Rect2) -> void:
    var body := _header(a, "MESSAGES", false)
    _fill(body, WHITE)
    var chars := _chars(body.size.x - 10)
    var y := body.position.y + 3 * _sc
    var bubble := Color("2b79f0") if _is_ios() else Color("33b5e5")
    var bottom := body.end.y - 10 * _sc  # the REPLY bar
    for k in Msp.texts.size():
        var m: Dictionary = Msp.texts[Msp.texts.size() - 1 - k]  # newest first
        var lines := _wrap(m.body, chars)
        var h := (lines.size() * 7 + 11) * _sc
        if y + h > bottom:
            if k > 0:
                break
            # the newest text always shows, cut to the lines that fit
            var room := int((bottom - y - 9 * _sc - 2) / (7 * _sc))
            lines = lines.slice(0, maxi(1, room))
            h = (lines.size() * 7 + 11) * _sc
        _text(_clip(m.from, chars), Vector2(body.position.x + 3, y), Color("7d8595"))
        var r := Rect2(body.position.x + 3, y + 7 * _sc, body.size.x - 6, lines.size() * 7 * _sc + 2)
        _round(r, Color("e5e5ea") if _is_ios() else Color("dcdcdc"))
        for j in lines.size():
            _text(lines[j], r.position + Vector2(2, 1 + j * 7 * _sc), INK)
        y += h + 2 * _sc
    if Msp.texts.is_empty():
        _text("NO MESSAGES", body.position + Vector2(4, 6 * _sc), Color("8b93a1"))
    _fill(Rect2(body.position.x, body.end.y - 10 * _sc, body.size.x, 10 * _sc), Color("f1f1f4"))
    _text("REPLY", Vector2(body.position.x + 3, body.end.y - 8 * _sc), bubble)
    _region("reply", Rect2(body.position.x, body.end.y - 10 * _sc, body.size.x, 10 * _sc))


# ---- settings ----------------------------------------------------------------
func _paint_settings(a: Rect2) -> void:
    var body := _header(a, "SETTINGS", false)
    _fill(body, Color("f2f2f2"))
    var y := body.position.y + 3 * _sc
    _text("PHONE", Vector2(body.position.x + 3, y), Color("7d8595"))
    y += 8 * _sc
    for i in 2:
        var ios := i == 0
        var r := Rect2(body.position.x + 2, y + i * 11 * _sc, body.size.x - 4, 9 * _sc)
        _fill(r, Color("dce8fa") if (ios == _is_ios()) else WHITE)
        _text("IFONE 5" if ios else "NEXXUS 5", r.position + Vector2(3, 2 * _sc), INK)
        if ios == _is_ios():
            _text("*", Vector2(r.end.x - 6, r.position.y + 2 * _sc), Color("2b79f0"))
        _region("os:" + ("ios" if ios else "android"), r)
    y += 25 * _sc
    # the TONE and CAREER rows take the bottom of the screen: the network block only shows when it fits above them
    var room := y + 16 * _sc <= body.end.y - 22 * _sc
    if room:
        _text("NETWORK", Vector2(body.position.x + 3, y), Color("7d8595"))
        _text("CELLULAR 4G", Vector2(body.position.x + 3, y + 8 * _sc), INK)
    var note := _wrap("WORKS WITHOUT THE OFFICE NETWORK", _chars(body.size.x - 6))
    if not room or y + (17 + 7 * note.size()) * _sc > body.end.y - 22 * _sc:
        note = []
    for i in note.size():
        _text(str(note[i]), Vector2(body.position.x + 3, y + (17 + 7 * i) * _sc), Color("7d8595"))
    var ring := Rect2(body.position.x + 2, body.end.y - 21 * _sc, body.size.x - 4, 9 * _sc)
    _fill(ring, WHITE)
    _text("TONE: " + _clip(Career.ringtone_name(), _chars(body.size.x - 10) - 6), ring.position + Vector2(3, 2 * _sc), INK)
    _region("ring", ring)
    var cr := Rect2(body.position.x + 2, body.end.y - 10 * _sc, body.size.x - 4, 9 * _sc)
    _fill(cr, Color("dce8fa"))
    _text("CAREER", cr.position + Vector2(3, 2 * _sc), INK)
    _region("career", cr)
''')

write("scripts/campaign.gd", '''extends Node
# Fixed campaigns. Two independent saves ("tech" and "owner"); "free" is Free Play / Film Mode:
# the plain sandbox with no days, scoring, reports or random tickets, so you can film without
# worrying about a campaign. A campaign is TOTAL_DAYS working days. At closing time the day
# ends: a report shows the results, pays the paycheck, moves reputation, saves, and the next
# morning starts. Reputation 0 = fired.

signal day_started(day_number: int)

const PLAYER := preload("res://scripts/player.gd")
const TOTAL_DAYS := 20
const FREE := "free"
const MODES := {"tech": "TECH CAMPAIGN", "owner": "OWNER CAMPAIGN"}
const START_REP := 50

var active := false  # a real campaign (not free play) is running
var mode := ""
var day := 1
var rep := START_REP
var cash := 0
var history: Array = []
var save_prefix := "user://mspsim_"  # tests point this somewhere else

var _base := {}
var _awaiting := false
var _fired_out := false


func adjust_rep(amount: int) -> void:
    if active:
        rep = clampi(rep + amount, 0, 100)


func save_path(for_mode: String) -> String:
    return save_prefix + for_mode + ".cfg"


func has_save(for_mode: String) -> bool:
    return FileAccess.file_exists(save_path(for_mode))


func saved_day(for_mode: String) -> int:
    var cfg := ConfigFile.new()
    if cfg.load(save_path(for_mode)) != OK:
        return 0
    return int(cfg.get_value("campaign", "day", 1))


func new_game(for_mode: String) -> void:
    mode = for_mode
    active = MODES.has(for_mode)
    day = 1
    rep = START_REP
    cash = 0
    history = []
    _awaiting = false
    Msp.reset()
    Skills.reset()
    Story.reset()
    Social.reset()
    Sales.reset()
    Owner.reset()
    Lync.reset()
    Nerds.reset()
    Shift.reset()
    Growth.reset()
    Outings.reset()
    PrinterGame.reset()
    Difficulty.new_run()
    Talk.reset()
    Meeting.reset()
    Projects.reset()
    Expo.reset()
    Onsite.reset()
    World.day_len = 240.0 if for_mode == "owner" else 600.0
    Msp.enabled = active
    if active:
        World.begin_next_day(1)
        _begin_day()


func continue_game(for_mode: String) -> bool:
    var cfg := ConfigFile.new()
    if cfg.load(save_path(for_mode)) != OK:
        return false
    mode = for_mode
    active = true
    day = int(cfg.get_value("campaign", "day", 1))
    rep = int(cfg.get_value("campaign", "rep", START_REP))
    cash = int(cfg.get_value("campaign", "cash", 0))
    history = cfg.get_value("campaign", "history", [])
    var saved_char := str(cfg.get_value("campaign", "character", "office_adult"))
    PLAYER.current_character = saved_char if saved_char in PLAYER.CHARACTERS else "office_adult"
    _awaiting = false
    Msp.reset()
    Skills.from_dict(cfg.get_value("campaign", "skills", {}))
    Story.reset()
    Social.from_dict(cfg.get_value("campaign", "social", {}))
    Sales.from_dict(cfg.get_value("campaign", "sales", {}))
    Owner.from_dict(cfg.get_value("campaign", "owner", {}))
    Nerds.from_dict(cfg.get_value("campaign", "nerds", {}))
    Shift.from_dict(cfg.get_value("campaign", "shift", {}))
    Growth.from_dict(cfg.get_value("campaign", "growth", {}))
    Outings.from_dict(cfg.get_value("campaign", "outings", {}))
    PrinterGame.from_dict(cfg.get_value("campaign", "printer", {}))
    Difficulty.from_dict(cfg.get_value("campaign", "difficulty", {}))
    Meeting.from_dict(cfg.get_value("campaign", "meeting", {}))
    Projects.from_dict(cfg.get_value("campaign", "projects", {}))
    Expo.from_dict(cfg.get_value("campaign", "conference", {}))
    Onsite.from_dict(cfg.get_value("campaign", "onsite", {}))
    Lync.reset()
    World.day_len = 240.0 if for_mode == "owner" else 600.0
    Story.flags = cfg.get_value("campaign", "story", {})
    var saved_backups: Array = cfg.get_value("campaign", "backups", [])
    if saved_backups.size() == Msp.backups.size():
        Msp.backups = saved_backups
    Msp.enabled = true
    World.begin_next_day(day)
    _begin_day()
    return true


func save() -> void:
    if not active:
        return
    var cfg := ConfigFile.new()
    cfg.set_value("campaign", "day", day)
    cfg.set_value("campaign", "rep", rep)
    cfg.set_value("campaign", "cash", cash)
    cfg.set_value("campaign", "history", history)
    cfg.set_value("campaign", "character", PLAYER.current_character)
    cfg.set_value("campaign", "skills", Skills.to_dict())
    cfg.set_value("campaign", "story", Story.flags)
    cfg.set_value("campaign", "social", Social.to_dict())
    cfg.set_value("campaign", "sales", Sales.to_dict())
    cfg.set_value("campaign", "owner", Owner.to_dict())
    cfg.set_value("campaign", "nerds", Nerds.to_dict())
    cfg.set_value("campaign", "shift", Shift.to_dict())
    cfg.set_value("campaign", "growth", Growth.to_dict())
    cfg.set_value("campaign", "outings", Outings.to_dict())
    cfg.set_value("campaign", "printer", PrinterGame.to_dict())
    cfg.set_value("campaign", "difficulty", Difficulty.to_dict())
    cfg.set_value("campaign", "meeting", Meeting.to_dict())
    cfg.set_value("campaign", "projects", Projects.to_dict())
    cfg.set_value("campaign", "conference", Expo.to_dict())
    cfg.set_value("campaign", "onsite", Onsite.to_dict())
    cfg.set_value("campaign", "backups", Msp.backups)
    cfg.save(save_path(mode))


# the review is over: remember how the year ended and go back to the title
func finish_campaign(ending: String) -> void:
    var meta := ConfigFile.new()
    meta.load(save_prefix + "meta.cfg")
    meta.set_value(mode, "ending", ending)
    meta.save(save_prefix + "meta.cfg")
    if has_save(mode):
        DirAccess.remove_absolute(save_path(mode))
    quit_to_title()


func quit_to_title() -> void:
    World.day_len = 600.0
    active = false
    mode = ""
    Msp.enabled = true
    World.time_scale = 1.0
    Game.ui_open = false
    Game.go_title()


func _begin_day() -> void:
    _base = {
        "score": Msp.score, "closed": Msp.closed_ok, "missed": Msp.breached, "reopened": Msp.reopened,
    }
    # owner weeks are 4 minutes long: tickets arrive faster so the team can actually saturate
    Msp.pace = maxf(0.5, 1.0 - 0.025 * float(day - 1)) * (0.6 if mode == "owner" else 1.0)
    Social.begin_day()
    Story.begin_day(day)
    if mode == "owner":
        Owner.begin_day(day)
    else:
        Shift.begin_day(day)
    day_started.emit(day)


func _process(_delta: float) -> void:
    if not active or _awaiting or Game.title_mode or Onsite.busy:
        return
    if Cards.is_open or Outings.busy():
        return  # the week report waits until every card and outing is finished
    var late: bool = World.clock >= 23.5
    if World.clock >= World.DAY_END and (not Story.overtime or late) and (late or (Shift.can_end_day() and not Outings.invite_due())):
        if late and Story.overtime:
            Story.overtime = false
            Story.ot_hours = World.clock - World.DAY_END
        _end_day()


# ---- end of day ------------------------------------------------------------
func make_report() -> Dictionary:
    return Expo.adjust_report(_make_report())


func _make_report() -> Dictionary:
    var closed: int = Msp.closed_ok - int(_base.closed)
    var missed: int = Msp.breached - int(_base.missed)
    var reopened: int = Msp.reopened - int(_base.reopened)
    var open_left: int = Msp.open_tickets().size()
    var points: int = Msp.score - int(_base.score)
    var overtime: float = Story.ot_hours
    var pay := maxi(0, 100 + closed * 20 - missed * 25 - reopened * 10 + int(overtime * 30.0) + Shift.pay_extra())
    var rep_delta := clampi(closed * 2 - missed * 3 - reopened * 2 - open_left + Social.rep_bonus() + Sales.rep_effect() + Shift.rep_delta(), -10, 8)
    var grade := "D"
    if points >= 20 and missed == 0 and open_left == 0 and closed >= 4:
        grade = "S"
    elif points >= 20 and missed == 0:
        grade = "A"
    elif points >= 10:
        grade = "B"
    elif points >= 0:
        grade = "C"
    return {
        "day": day, "closed": closed, "missed": missed, "reopened": reopened, "open_left": open_left,
        "points": points, "pay": pay, "rep_delta": rep_delta, "grade": grade, "social": Social.day_delta,
        "overtime": snappedf(overtime + Shift.stay_hours, 0.1), "clients": int(Sales.average()),
        "energy": int(Shift.energy) if Shift.active() else -1, "late": Shift.late_min, "oncall": Shift.oncall_pay(),
    }


func _end_day() -> void:
    _awaiting = true
    World.time_scale = 0.0
    Shift.close_day()
    if Computer.is_open:
        Computer.close()
    if Phone.is_open:
        Phone.close()
    var r := make_report()
    if mode == "owner":
        var books := Owner.settle()
        r["rows"] = books.rows
        r["title"] = books.title
        r["grade"] = books.grade
        r["pay"] = 0
        # a profitable week helps the name; only a clearly bad one (a new hire, a project) hurts it
        var profit_rep := 1 if int(books.profit) > 0 else (-1 if int(books.profit) < -1000 else 0)
        r["rep_delta"] = clampi(int(r.rep_delta) + profit_rep, -3, 4)
        cash = Owner.cash
        r["bankrupt"] = books.bankrupt
    else:
        cash += int(r.pay)
    rep = clampi(rep + int(r.rep_delta), 0, 100)
    if r.get("bankrupt", false):
        rep = 0
    r["rep"] = rep
    r["cash"] = cash
    r["total_days"] = TOTAL_DAYS
    r["fired"] = rep <= 0
    _fired_out = rep <= 0
    r["final"] = day >= TOTAL_DAYS or rep <= 0
    r["ending"] = _ending(r)
    history.append({"day": day, "grade": r.grade, "points": r.points})
    Game.ui_open = true
    DayReport.show_report(r)


func _ending(r: Dictionary) -> String:
    if r.fired:
        if mode == "owner":
            return "THE COMPANY IS BANKRUPT." if bool(r.get("bankrupt", false)) else "YOUR NAME IS MUD. THE COMPANY CLOSES."
        return "REPUTATION GONE. YOU ARE FIRED."
    if day < TOTAL_DAYS:
        return ""
    return "YEAR COMPLETE. YOUR BOARD REVIEW IS NEXT." if mode == "owner" else "YEAR COMPLETE. YOUR YEARLY REVIEW IS NEXT."


# the report screen's button
func report_continue(final: bool) -> void:
    if final:
        _awaiting = true  # the last day settles once: the clock is still at closing time
    else:
        _awaiting = false
    if final and (mode == "tech" or mode == "owner") and not _fired_out:
        Review.start()
        return
    if final:
        if has_save(mode):
            DirAccess.remove_absolute(save_path(mode))
        quit_to_title()
        return
    day += 1
    save()
    World.time_scale = 1.0
    Game.ui_open = false
    World.begin_next_day(day)
    _begin_day()
    Game.go("main_floor", "from_outside")
''')

write("scripts/day_report.gd", '''extends CanvasLayer
# The end-of-day report for the campaigns: a dimmed screen with a dark panel: a big grade and the
# score / paycheck / reputation / cash on one side (or on top in narrow formats), the details
# grouped under TICKETS / PEOPLE / ENERGY (the owner's books as one group), then the ending text
# and a button. Enter / Space / click continues. Drawn in code with the 3x5 pixel font; the text
# scale drops from 2 to 1 when a narrow format cannot fit everything.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")
const PANEL := Color("171c2a")
const STRIPE := Color("1f2536")
const LINE := Color("3a4562")
const LABEL := Color("b4bfd6")
const HEAD := Color("7fb6ff")
const GOOD := Color("8fe3a0")
const BAD := Color("ff8a80")
const WARN := Color("ffd27a")
const ROW := 7.0  # row height in virtual pixels (one font pixel at scale 1)
const GRADE_COLORS := {
    "S": Color("f5d442"), "A": Color("5fd068"), "B": Color("5aa0e8"), "C": Color("e0a030"), "D": Color("e0463c"),
}

var is_open := false
var report := {}

var _canvas: Node2D
var _mouse := Vector2.ZERO
var _button := Rect2()
var _fade := 0.0
var _sc := 1  # text scale in use (2 on narrow screens that have room for it)
var _o := Vector2.ZERO  # panel origin in screen pixels
var _opened := 0  # the report ignores confirm keys for a moment so it is not dismissed unread


func _ready() -> void:
    layer = 70
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)


func show_report(data: Dictionary) -> void:
    report = data
    is_open = true
    _opened = Time.get_ticks_msec()
    _canvas.visible = true
    _mouse = get_viewport().get_mouse_position()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    create_tween().tween_method(_set_fade, _fade, 1.0, 0.3)
    _canvas.queue_redraw()


func _set_fade(value: float) -> void:
    _fade = value
    _canvas.modulate.a = value


func finish() -> void:
    if not is_open:
        return
    is_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _canvas.visible = false
    _fade = 0.0
    Campaign.report_continue(bool(report.get("final", false)))
    Cards.flush()


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventMouseMotion:
        _mouse = get_viewport().get_mouse_position()
        _canvas.queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse = get_viewport().get_mouse_position()
        if _button.has_point(_mouse) and Time.get_ticks_msec() - _opened >= 600:
            finish()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and Time.get_ticks_msec() - _opened >= 600:
            finish()
    else:
        return
    get_viewport().set_input_as_handled()


func _groups() -> Array:
    if report.has("rows"):
        var books := []
        for row in report.rows:
            if str(row[0]) != "":
                books.append(row)
        return [["", books]]
    var r := report
    var mood := int(r.clients)
    var social := int(r.social)
    var groups := [
        [
            "TICKETS",
            [
                ["CLOSED", str(r.closed), GOOD if int(r.closed) > 0 else WHITE],
                ["SLA MISSED", str(r.missed), BAD if int(r.missed) > 0 else GOOD],
                ["REOPENED", str(r.reopened), BAD if int(r.reopened) > 0 else GOOD],
                ["STILL OPEN", str(r.open_left), WARN if int(r.open_left) > 0 else GOOD],
            ]
        ],
        [
            "PEOPLE",
            [
                ["CLIENT MOOD", "%d%%" % mood, GOOD if mood >= 70 else (BAD if mood < 40 else WARN)],
                [
                    "COWORKERS",
                    "%+d" % social if social != 0 else "0",
                    GOOD if social > 0 else (BAD if social < 0 else WHITE)
                ],
            ]
        ],
    ]
    var energy := []
    if int(r.get("energy", -1)) >= 0:
        var e := int(r.energy)
        energy.append(["ENERGY", "%d%%" % e, BAD if e < 35 else (WARN if e < 55 else GOOD)])
        var notes := []
        if int(r.get("late", 0)) >= 10:
            notes.append("LATE %dM" % int(r.late))
        if int(r.get("oncall", 0)) > 0:
            notes.append("ON CALL")
        if not notes.is_empty():
            energy.append(["LATE / ON CALL", " ".join(notes), WARN])
    if float(r.overtime) > 0.0:
        energy.append(["OVERTIME", "%.1fH" % float(r.overtime), GOOD])
    if not energy.is_empty():
        groups.append(["ENERGY", energy])
    return groups


# the big numbers: [label, short label, value, colour]
func _hero() -> Array:
    var r := report
    var delta := int(r.get("rep_delta", 0))
    var tiles := []
    if not report.has("rows"):
        var pts := int(r.points)
        var pcol := GOOD if pts >= 10 else (BAD if pts < 0 else WHITE)
        tiles.append(["DAY SCORE", "SCORE", str(pts), pcol])
        tiles.append(["PAYCHECK", "PAY", "$%d" % int(r.pay), GOOD if int(r.pay) > 0 else WHITE])
    var rep_text := "%d (%+d)" % [int(r.rep), delta] if delta != 0 else str(int(r.rep))
    var rcol := GOOD if delta > 0 else (BAD if delta < 0 else WHITE)
    tiles.append(["REPUTATION", "REP", rep_text, rcol])
    if not report.has("rows"):
        var cash := int(r.cash)
        tiles.append(["CASH", "CASH", "%s$%d" % ["-" if cash < 0 else "", absi(cash)], GOOD if cash >= 0 else BAD])
    return tiles


# text in virtual pixels relative to the panel
func _t(s: String, x: float, y: float, c: Color, mult: int = 1) -> void:
    PixelFont.draw(_canvas, s, _o + Vector2(x, y) * float(_sc), c, _sc * mult)


func _tw(s: String, mult: int = 1) -> float:
    return float(PixelFont.width(s, _sc * mult)) / float(_sc)


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
    var u := float(_sc)
    _canvas.draw_rect(Rect2(_o + Vector2(x, y) * u, Vector2(w, h) * u), c)


# one list row: label left, value right; a value that does not fit goes on its own line
func _row(x: float, y: float, w: float, row: Array, stripe: bool, draw: bool) -> float:
    var label := str(row[0])
    var value := str(row[1])
    var two := _tw(label) + _tw(value) + 8.0 > w
    var h := ROW * (2.0 if two else 1.0)
    if draw:
        if stripe:
            _r(x, y, w, h, STRIPE)
        _t(label, x + 2.0, y + 1.0, LABEL)
        _t(value, x + w - 2.0 - _tw(value), y + 1.0 + (ROW if two else 0.0), row[2])
    return h


func _list(x: float, y: float, w: float, groups: Array, draw: bool) -> float:
    var h := 0.0
    for g in groups:
        var name := str(g[0])
        if name != "":
            if draw:
                _t(name, x + 2.0, y + h + 1.0, HEAD)
                _r(x + _tw(name) + 5.0, y + h + 3.0, w - _tw(name) - 5.0, 1.0, LINE)
            h += ROW
        var i := 0
        for row in g[1]:
            h += _row(x, y + h, w, row, i % 2 == 1, draw)
            i += 1
        h += 1.0
    return h - 1.0


# the grade box, then the stat tiles (big) or rows (compact); returns its height
func _hero_block(x: float, y: float, w: float, big: bool, draw: bool) -> float:
    var grade := str(report.grade)
    var gcol: Color = GRADE_COLORS.get(grade, WHITE)
    var tiles := _hero()
    var owner_books := report.has("rows")
    var gh := 28.0 if big else 26.0
    var gw := 30.0 if big else 22.0
    if draw:
        _r(x, y, gw, gh, gcol)
        _r(x + 1.0, y + 1.0, gw - 2.0, gh - 2.0, Color("0e121c"))
        _t(grade, x + floorf((gw - 12.0) * 0.5), y + floorf((gh - 20.0) * 0.5), gcol, 4)
    if big:
        var h := gh + 4.0
        if draw:
            _t("GRADE", x + gw + 4.0, y + 2.0, LABEL)
            if not owner_books:
                _t(str(tiles[0][0]), x + gw + 4.0, y + 12.0, LABEL)
                _t(str(tiles[0][2]), x + gw + 4.0, y + 18.0, tiles[0][3], 2)
        for k in range(0 if owner_books else 1, tiles.size()):
            var value := str(tiles[k][2])
            if draw:
                _r(x, y + h, w, 12.0, STRIPE)
                _t(str(tiles[k][0]), x + 2.0, y + h + 4.0, LABEL)
                _t(value, x + w - 2.0 - _tw(value, 2), y + h + 1.0, tiles[k][3], 2)
            h += 13.0
        return h - 1.0
    # compact: the grade box on the left, the numbers as rows beside it
    var rx := x + gw + 3.0
    var rw := w - gw - 3.0
    var rh := 0.0
    for tile in tiles:
        rh += _row(rx, y + rh, rw, [tile[1], tile[2], tile[3]], true, draw)
    return maxf(gh, rh)


func _panel_w(sc: int, size: Vector2) -> float:
    return minf(size.x / float(sc) - 8.0, 300.0)


func _button_label() -> String:
    if bool(report.final):
        return "FINISH" if bool(report.fired) or Campaign.mode == "free" else "REVIEW"
    return "NEXT DAY"


# the whole panel below the title bar; returns the panel height in virtual pixels
func _stack(sc: int, size: Vector2, draw: bool) -> float:
    _sc = sc
    var wide := size.x / float(sc) >= 200.0
    var big := size.x / float(sc) >= 140.0
    var pw := _panel_w(sc, size)
    var groups := _groups()
    var y := 11.0
    var inner := pw - 8.0
    var hero_w := 112.0
    if wide:
        var hh := _hero_block(4.0, y, hero_w, true, draw)
        var lx := 4.0 + hero_w + 6.0
        if draw:
            _r(4.0 + hero_w + 2.0, y, 1.0, hh, LINE)
        var lh := _list(lx, y, pw - lx - 4.0, groups, draw)
        y += maxf(hh, lh)
    else:
        y += _hero_block(4.0, y, inner, big, draw) + 3.0
        y += _list(4.0, y, inner, groups, draw)
    var ending := str(report.get("ending", ""))
    if ending != "":
        y += 4.0
        var col := BAD if bool(report.get("fired", false)) else WARN
        for line in _wrap(ending, int(inner / 4.0)):
            if draw:
                _t(line, 4.0, y, col)
            y += ROW
    y += 2.0
    if draw:
        _r(4.0, y, inner, 1.0, LINE)
    y += 2.0
    var label := _button_label()
    var bw := _tw(label) + 12.0
    var hint := "ENTER OR CLICK"
    if _tw(hint) + bw + 12.0 > pw:
        hint = "ENTER"
    if draw:
        _t(hint, 4.0, y + 2.5, LABEL)
        _button = Rect2(_o + Vector2(pw - bw - 4.0, y) * float(sc), Vector2(bw, 10.0) * float(sc))
        var hot := _button.has_point(_mouse)
        _r(pw - bw - 4.0, y, bw, 10.0, Color("5aa0e8") if hot else Color("3a7bd5"))
        _t(label, pw - bw + 2.0, y + 2.5, WHITE)
    return y + 10.0 + 3.0


func _paint() -> void:
    if report.is_empty():
        return
    var size := get_viewport().get_visible_rect().size
    var sc := 2 if size.x < 220.0 else 1
    var h := _stack(sc, size, false)
    if sc == 2 and h * 2.0 > size.y - 4.0:
        sc = 1
        h = _stack(sc, size, false)
    var u := float(sc)
    var pw := _panel_w(sc, size)
    _canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.86))
    _o = Vector2(floorf((size.x - pw * u) * 0.5), maxf(1.0, floorf((size.y - h * u) * 0.5)))
    _r(-1.0, -1.0, pw + 2.0, h + 2.0, LINE)
    _r(0.0, 0.0, pw, h, PANEL)
    _r(0.0, 0.0, pw, 10.0, Color("1f4e8c"))
    var title := str(
        report.get("title", "DAY %d OF %d COMPLETE" % [int(report.day), int(report.total_days)])
    )
    if _tw(title) + 8.0 > pw:
        title = title.replace(" COMPLETE", "")
    _t(title, 4.0, 2.5, WHITE)
    _stack(sc, size, true)
    var m := _mouse.floor()
    for i in 6:
        _canvas.draw_rect(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
    _canvas.draw_rect(Rect2(m.x + 1, m.y + 1, 1, 2), WHITE)


func _wrap(s: String, chars: int) -> Array:
    var lines := []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            lines.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    lines.append(line)
    return lines
''')

write("scripts/skills.gd", '''extends Node
# Tech skills for the campaign. Five skills: POWERSHELL (levels come from the Academy lessons),
# NETWORKING, SERVERS, SECURITY and CUSTOMER (levels come from experience: fixing and closing
# tickets). PowerShell is the one that changes how you play: higher levels make remote fixes
# faster and more reliable, and
# unlock scripts that fix a whole client (level 2) or every client (level 4) at once.
# Outside a campaign (free play, tests) fixes are instant and always work, like before.

signal leveled(skill: String, new_level: int)

const NAMES := {
    "powershell": "POWERSHELL", "networking": "NETWORKING", "servers": "SERVERS", "security": "SECURITY",
    "people": "CUSTOMER",
}
const XP_AT := [15, 40, 80, 130, 200]  # experience needed for levels 1 to 5
const FIX_XP := {
    "spooler": "networking", "password": "security", "clear_temp": "servers", "reboot": "servers", "av": "security",
    "restore": "security", "adobe": "servers",
}
const FIX_SECS := [6.0, 5.0, 4.0, 3.0, 2.0, 1.5]  # by PowerShell level
const FAIL := [0.25, 0.18, 0.1, 0.04, 0.0, 0.0]
# each question: [question, right answer, wrong, wrong]
const LESSONS := [
    {"title": "FIRST STEPS", "qs": [
        ["WHICH CMDLET LISTS RUNNING SERVICES?", "GET-SERVICE", "SHOW-SERVICES", "LIST-SVC"],
        ["HOW DO YOU READ HELP FOR A CMDLET?", "GET-HELP", "HELP-ME", "ASK-PS"],
        ["CMDLETS ARE NAMED LIKE...", "VERB-NOUN", "NOUN.VERB", "ANYTHING"],
    ]},
    {"title": "THE PIPELINE", "qs": [
        ["WHAT DOES THE | CHARACTER DO?", "PASSES OUTPUT ON", "ENDS THE COMMAND", "STARTS A COMMENT"],
        ["WHICH CMDLET FILTERS OBJECTS?", "WHERE-OBJECT", "FILTER-ONLY", "FIND-IT"],
        ["WHICH CMDLET PICKS PROPERTIES?", "SELECT-OBJECT", "PICK-PROP", "CHOOSE-FIELD"],
    ]},
    {"title": "FIXING THINGS", "qs": [
        ["HOW DO YOU RESTART THE SPOOLER?", "RESTART-SERVICE SPOOLER", "RELOAD SPOOLER", "REBOOT-SERVICE"],
        ["WHICH CMDLET UNLOCKS AN AD ACCOUNT?", "UNLOCK-ADACCOUNT", "OPEN-USER", "CLEAR-LOCK"],
        ["WHICH CMDLET DELETES FILES?", "REMOVE-ITEM", "ERASE-FILE", "DEL-NOW"],
    ]},
    {"title": "WRITING SCRIPTS", "qs": [
        ["A SCRIPT FILE ENDS IN...", ".PS1", ".PSX", ".SCRIPT"],
        ["RUN A COMMAND ON MANY PCS WITH...", "INVOKE-COMMAND", "RUN-ALL", "FOR-PCS"],
        ["LOOP OVER A LIST WITH...", "FOREACH", "EACHOF", "WHILEALL"],
    ]},
    {"title": "STAYING SAFE", "qs": [
        ["TEST A CHANGE WITHOUT DOING IT:", "-WHATIF", "-DRYRUN", "-PRETEND"],
        ["CATCH ERRORS WITH...", "TRY / CATCH", "OOPS", "IF-ERROR"],
        ["MAKE ERRORS STOP A SCRIPT:", "-ERRORACTION STOP", "-QUIT", "-HALT"],
    ]},
]

var xp := {}
var ps_level := 0
var lesson_day := -1  # the day an Academy lesson was last passed (one a day)


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


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
''')

write("scripts/story.gd", '''extends Node
# gdlint:disable=max-line-length
# The tech campaign's script: what happens on each day (mails, texts, set-pieces) at a time of day.
# Events are data in DAYS; `kind` is mail / text / backup_break (silent) / ransomware.
# Plan (the rest is still to build): day 3 the easy Adobe Reader print ticket (built), day 4
# desktop install + migration (built: Msp.start_project, the RMM PROJECT tab), day 10 a
# client's network rack falls off the wall, day 12 server migration, day 13 the 24x7 email
# outage and vendor call, day 16 a network install, day 20 the yearly review with the manager.

const RANSOM_CLIENT := 3  # Hoot and Holler Law
const MANAGER := "Morgan Reyes - Manager"
const VIGNETTES := {
    "iphone": {
        "speaker": "Karen Whitfield (Brightside Realty)",
        "text": "I just got a new iFone 5S and all my email is gone! I have a showing in an hour. Can you please set it up?",
        "options": [
            {"id": "proper", "label": "SET IT UP PROPERLY, WITH A PASSCODE", "text": "Her mail works and she has a passcode now. She says you are a lifesaver. (+4 customer XP)", "fx": {"xp": ["people", 4], "mood": [1, 4], "hours": 0.3}},
            {"id": "all", "label": "SET IT UP AND MOVE HER CONTACTS TOO", "text": "It takes a while, but every client's number is on the new phone. She hugs you. A little. (+3 customer XP)", "fx": {"xp": ["people", 3], "mood": [1, 6], "hours": 0.6, "energy": -1}},
            {"id": "store", "label": "TELL HER TO CALL THE PHONE STORE", "text": "She sighs and says she will ask her nephew.", "fx": {"mood": [1, -3]}},
        ],
    },
    "heartbleed": {
        "speaker": "Garrison (Co-owner)",
        "text": "Every client is asking about Heartbleed, that bug in the news with a logo, and I told them we are on it. Are any of their servers affected? Please check before they call us again.",
        "options": [
            {"id": "check", "label": "CHECK EVERY CLIENT AND WRITE A SHORT NOTE", "text": "Most are fine. One old firewall needs a patch and you schedule it for tonight. Garrison nods. (+6 security XP, reputation +1)", "fx": {"xp": ["security", 6], "rep": 1, "hours": 0.5}},
            {"id": "mail", "label": "SEND A REASSURING EMAIL TO EVERYONE", "text": "You say 'we are looking into it and will update you'. Nobody replies. That is a good sign.", "fx": {"mood_all": 2}},
            {"id": "wait", "label": "WAIT UNTIL SOMEONE ASKS", "text": "Garrison sighs. 'That is what everyone said about Target.'", "fx": {"rep": -1, "social": {"Garrison": -2}}},
        ],
    },
    "candy": {
        "speaker": "The hygienist (Acme Dental)",
        "text": "I put Sugar Smash on the front desk computer so the waiting room kids can play. Is that okay? It is very popular.",
        "options": [
            {"id": "remove", "label": "REMOVE IT AND EXPLAIN WHY", "text": "You explain malware and the license. She is a bit disappointed and very understanding. (+2 customer XP)", "fx": {"xp": ["people", 2], "mood": [0, 2]}},
            {"id": "play", "label": "PLAY ONE LEVEL TO TEST IT FIRST", "text": "Level 41. It is very hard. Your coffee goes cold. (+2 energy)", "fx": {"energy": 2, "hours": 0.2}},
            {"id": "tell", "label": "TELL DR. PATEL", "text": "Dr. Patel is not amused. The hygienist is not amused either.", "fx": {"mood": [0, -4]}},
        ],
    },
    "pizza": {
        "speaker": "A salesman from a PSA vendor",
        "text": "Hi! I am bringing free pizza for the service desk and I would love just thirty minutes of your time to show you our ticketing software.",
        "options": [
            {"id": "listen", "label": "TAKE THE PIZZA AND LISTEN", "text": "The demo is okay, and you learn what the competition charges. The pizza is good. (+2 customer XP, +3 energy)", "fx": {"xp": ["people", 2], "energy": 3, "hours": 0.5}},
            {"id": "grab", "label": "TAKE A SLICE AND LEAVE", "text": "Alan notices. He says nothing, loudly. (+2 energy)", "fx": {"energy": 2, "social": {"Alan": -1}}},
            {"id": "decline", "label": "TELL HIM WE ARE HAPPY WITH WHAT WE HAVE", "text": "He leaves the pizza anyway. Everyone is happy.", "fx": {"social_all": 1}},
        ],
    },
    "win8": {
        "speaker": "A realtor at Brightside",
        "text": "I updated my computer to Windows 8 and now there is no Start button! Where did it go? I have a listing to send in ten minutes.",
        "options": [
            {"id": "show", "label": "SHOW HER THE HOT CORNERS AND THE START SCREEN", "text": "She learns where everything went. She calls it 'the tiles' for the rest of the year. (+3 customer XP)", "fx": {"xp": ["people", 3], "mood": [1, 3], "hours": 0.3}},
            {"id": "menu", "label": "INSTALL A START MENU REPLACEMENT", "text": "A familiar button comes back and she cries a little. (+2 servers XP)", "fx": {"xp": ["servers", 2], "mood": [1, 4], "hours": 0.2}},
            {"id": "feature", "label": "TELL HER IT IS A FEATURE", "text": "Dan laughs quietly across the room. She does not.", "fx": {"mood": [1, -3], "social": {"Dan": 1}}},
        ],
    },
    "selfreview": {
        "speaker": "Morgan (Manager)",
        "text": "Before reviews: what are you proudest of this year? I will remember what you say.",
        "options": [
            {"id": "jobs", "label": "THE BIG JOBS I GOT RIGHT", "text": "Morgan writes it down. 'That is what I will say to Alan and Garrison.'", "fx": {"rep": 1}},
            {"id": "learn", "label": "HOW MUCH I HAVE LEARNED", "text": "Morgan smiles. 'Keep doing that.' (+3 customer XP)", "fx": {"xp": ["people", 3]}},
            {"id": "team", "label": "THE TEAM I WORK WITH", "text": "Morgan says the team has noticed. Word gets around.", "fx": {"social_all": 2}},
        ],
    },
    "donuts": {
        "speaker": "Alan (Co-owner)",
        "text": "I am back, and I brought donuts. Morgan says you covered for me while I was out. I read the page you wrote about the firewall I built. Show me how you set it up in the vault?",
        "options": [
            {"id": "show", "label": "SHOW HIM, HE IS PROUD", "text": "Alan nods slowly. 'That is better than what I had.' (+3 servers XP)", "fx": {"xp": ["servers", 3], "social": {"Alan": 3}}},
            {"id": "nothing", "label": "SAY IT WAS NOTHING", "text": "He insists you are being modest and gives you the last donut.", "fx": {"social": {"Alan": 1}, "energy": 1}},
            {"id": "subject", "label": "EAT A DONUT AND CHANGE THE SUBJECT", "text": "You discuss the weather for a minute. The donut is very good. (+2 energy)", "fx": {"energy": 2}},
        ],
    },
}
const DAYS := {
    1: [
        {"at": 9.1, "kind": "mail", "from": MANAGER, "subject": "Your first day",
         "body": "Welcome to Pixel IT Partners. Alan and Garrison own the place and I run the floor for them. Tickets come in on ConnectWhy PSA, you fix things "
         + "with LabRat RMM, and you only close a ticket once it is really fixed. Reopened tickets "
         + "make me sad. Clients also call and text, so check your phone (P) now and then. - Morgan"},
    ],
    2: [
        {"at": 9.1, "kind": "mail", "from": MANAGER, "subject": "Daily chore: verify backups",
         "body": "Every morning open LabRat RMM, click BACKUPS and check each client. Backup jobs "
         + "can fail silently and nobody notices until the day it really matters. It takes thirty "
         + "seconds. - Morgan"},
        {"at": 10.5, "kind": "vignette", "id": "iphone"},
    ],
    3: [
        {"at": 9.1, "kind": "mail", "from": MANAGER, "subject": "Get good at PowerShell",
         "body": "The PowerShell Academy is on your desktop. Every lesson makes your remote fixes "
         + "faster and more reliable, and later levels unlock scripts that fix a whole client at "
         + "once. Study between tickets. - Morgan"},
        {"at": 10.0, "kind": "adobe", "client": 1},
    ],
    4: [
        {"at": 9.1, "kind": "mail", "from": MANAGER, "subject": "Windows XP is going away",
         "body": "Microsoft ends support for Windows XP and Office 2003 on April 8. After that there are no "
         + "more security patches, so every XP machine at every client is a liability. "
         + "Dr. Patel at Acme Dental is first. Survey the old PC (old software, old drivers, odd "
         + "settings), back it up before you move anything, migrate, then verify with the user "
         + "before you wipe it. - Morgan"},
        {"at": 10.0, "kind": "install"},
    ],
    5: [
        {"at": 8.6, "kind": "backup_break", "client": RANSOM_CLIENT},
        {"at": 9.6, "kind": "install_followup"},
        {"at": 9.2, "kind": "mail", "from": MANAGER, "subject": "On-call rota starts Monday",
         "body": "You are on the pager next week (Monday to Friday nights). If a client alert wakes you, "
         + "you can get up and fix it, check it first, or let it ride, "
         + "but clients do not forgive a dead server. "
         + "On-call pay is $40 a day. Leave for work early enough, too: "
         + "Route 9 is down to one lane. - Morgan"},
        {"at": 10.5, "kind": "vignette", "id": "heartbleed"},
    ],
    6: [{"at": 9.8, "kind": "growth_plan"}],
    7: [
        {"at": 10.0, "kind": "mail", "from": "Atty. Spence <spence@hootholler.example>", "subject": "Backup report?",
         "body": "Hi, I have not seen the nightly backup report email for a few days. Probably nothing? - Spence"},
        {"at": 13.0, "kind": "playbook", "book": "rdp",
         "text": "Brightside's server is crawling and there are strangers in the logs. "
         + "Their remote desktop may be open to the internet. Look, then close the door."},
        {"at": 11.0, "kind": "growth_block"},
        {"at": 15.5, "kind": "vignette", "id": "candy"},
    ],
    8: [
        {"at": 9.6, "kind": "playbook", "book": "ceofraud",
         "text": "Hoot and Holler got a strange email asking to wire money. The paralegal is waiting on you before she does anything."},
        {"at": 14.0, "kind": "growth_stretch"},
    ],
    9: [{"at": 10.5, "kind": "ransomware"}],
    10: [
        {"at": 10.0, "kind": "playbook", "book": "rack",
         "text": "Gnarly Gnomes says their network rack fell off the wall. Everything is down. Go. Photos first!"},
    ],
    11: [{"at": 10.0, "kind": "callback_install"}],
    12: [
        {"at": 9.5, "kind": "playbook", "book": "migration",
         "text": "Brightside's server migration is today. Check the backups before you touch anything."},
        {"at": 11.0, "kind": "growth_block"},
        {"at": 15.5, "kind": "vignette", "id": "pizza"},
    ],
    13: [
        {"at": 15.5, "kind": "playbook", "book": "email24",
         "text": "Soggy Bottom Brewing runs 24x7 and their email just died. This could be a long night."},
        {"at": 14.0, "kind": "growth_stretch"},
    ],
    14: [
        {"at": 13.0, "kind": "playbook", "book": "no2fa",
         "text": "Soggy Bottom keeps getting phished and still refuses stronger logins. Go and have the conversation."},
        {"at": 10.0, "kind": "callback_ransom"},
        {"at": 9.2, "kind": "mail", "from": MANAGER, "subject": "About last night",
         "body": "Whatever happened with the brewery, thank you for staying late. Overtime is on your paycheck. "
         + "Take it easy today. - Morgan"},
        {"at": 15.5, "kind": "vignette", "id": "win8"},
    ],
    15: [
        {"at": 9.2, "kind": "mail", "from": MANAGER, "subject": "Pager again",
         "body": "You are back on call from Monday. First snow is forecast, so expect traffic and worse. - Morgan"},
    ],
    16: [
        {"at": 9.5, "kind": "playbook", "book": "netinstall",
         "text": "Hoot and Holler's branch office network install is today. Do it right, they remember."},
    ],
    17: [{"at": 11.0, "kind": "growth_block"}],
    18: [
        {"at": 14.0, "kind": "growth_stretch"},
        {"at": 9.2, "kind": "mail", "from": MANAGER, "subject": "Reviews are coming",
         "body": "Yearly reviews are on day 20. I look at your tickets, your big jobs and what "
         + "your coworkers say about you. No pressure. A little pressure. - Morgan"},
        {"at": 10.5, "kind": "vignette", "id": "selfreview"},
    ],
    19: [
        {"at": 9.5, "kind": "playbook", "book": "bus",
         "text": "Acme's internet is flaky and the person who knows the firewall is out sick."},
        {"at": 15.0, "kind": "vignette", "id": "donuts"},
    ],
    20: [
        {"at": 9.4, "kind": "callback_worst"},
        {"at": 9.2, "kind": "mail", "from": MANAGER, "subject": "Review at the end of the day",
         "body": "We will sit down after close for your yearly review. There may be an offer or two. - Morgan"},
    ],
}

var flags := {}  # story results (saved with the campaign)
var overtime := false  # an incident is keeping the day open past closing time
var ot_hours := 0.0

var _fired := {}
var _followed := false


func reset() -> void:
    flags = {}
    _fired = {}
    overtime = false
    ot_hours = 0.0
    _followed = false
    Playbook.reset()


func begin_day(day: int) -> void:
    _fired = {}
    _followed = false
    overtime = false
    ot_hours = 0.0
    Msp.new_day(day)


func _process(_delta: float) -> void:
    if not Campaign.active or Campaign.mode != "tech" or Game.title_mode or World.time_scale <= 0.0:
        return
    var events: Array = DAYS.get(Campaign.day, [])
    for i in events.size():
        var ev: Dictionary = events[i]
        if not _fired.has(i) and World.clock >= float(ev.at):
            _fired[i] = true
            fire(ev)
    if not _followed and World.clock >= 9.4:
        _followed = true
        _spawn_followups()


# trouble from sloppy jobs comes back the next morning
func queue_followup(item: Dictionary) -> void:
    var entry := item.duplicate()
    entry["due"] = Campaign.day + int(item.get("days", 1))
    var list: Array = flags.get("followups", [])
    list.append(entry)
    flags["followups"] = list


func _spawn_followups() -> void:
    var list: Array = flags.get("followups", [])
    var keep := []
    for item in list:
        if int(item.due) <= Campaign.day:
            Msp.spawn_return(item)
        else:
            keep.append(item)
    flags["followups"] = keep


func fire(ev: Dictionary) -> void:
    match str(ev.kind):
        "mail":
            Msp.mail(str(ev.from), str(ev.subject), str(ev.body))
        "text":
            Msp.send_text(str(ev.from), str(ev.body))
        "backup_break":
            Msp.break_backup(int(ev.client))
        "ransomware":
            _ransomware()
        "playbook":
            Playbook.start(str(ev.book))
            Msp.send_text("Boss", str(ev.get("text", "A big job just came in.")))
        "vignette":
            _vignette(str(ev.id))
        "adobe":
            Msp.create_problem(int(ev.client), Msp.ADOBE, "email")
        "callback_install":
            _callback_install()
        "callback_ransom":
            _callback_ransom()
        "callback_worst":
            _callback_worst()
        "growth_plan":
            Growth.start_plan()
        "growth_block":
            if not Expo.away:
                Growth.offer_block()
        "growth_stretch":
            if not Expo.away:
                Growth.offer_stretch()
        "install":
            var t := Msp.create_problem(0, Msp.INSTALL, "email")
            Msp.start_project(int(t.get("id", 0)))
        "install_followup":
            if flags.get("install", "") == "lost":
                Msp.mail("Dr. Patel <patel@acmedental.example>", "XRAY STILL MISSING", "I spent the evening reloading the xray software from CDs. Never again. - Patel")
                Msp.send_text("Boss", "Acme lost their xray software in the migration. Always survey and back up first.")


# ---- small quiet-day moments: a short card with a few choices and small effects
func _vignette(id: String) -> void:
    var v: Dictionary = VIGNETTES.get(id, {})
    if v.is_empty():
        return
    var options := []
    for o in v.options:
        options.append({"label": str(o.label), "id": str(o.id)})
    Cards.ask(str(v.speaker), str(v.text), options, func(pick: String) -> void: _vignette_answer(id, pick))


func _vignette_answer(id: String, pick: String) -> void:
    var v: Dictionary = VIGNETTES[id]
    var text := ""
    for o in v.options:
        if str(o.id) == pick:
            text = str(o.text)
            _vignette_fx(o.get("fx", {}))
    Cards.ask(str(v.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _vignette_fx(fx: Dictionary) -> void:
    if fx.has("xp"):
        Skills.add_xp(str(fx.xp[0]), int(fx.xp[1]))
    if fx.has("mood"):
        Sales.adjust(int(fx.mood[0]), int(fx.mood[1]))
    if fx.has("mood_all"):
        for c in Sales.active:
            Sales.adjust(int(c), int(fx.mood_all))
    if fx.has("rep"):
        Campaign.adjust_rep(int(fx.rep))
    for who in fx.get("social", {}):
        Social.change(str(who), int(fx.social[who]))
    if fx.has("social_all"):
        Social.change_all(int(fx.social_all))
    if fx.has("energy"):
        Shift.add_energy(float(fx.energy))
    if fx.has("hours"):
        World.clock += float(fx.hours)


# ---- earlier choices come back later
func _callback_install() -> void:
    var from := "Dr. Patel <patel@acmedental.example>"
    match str(flags.get("install", "")):
        "ok":
            Msp.mail(from, "The new computer", "Two weeks in and the whole front desk asks who set up the new PC. The xray software even runs faster. Thank you. - Patel")
            Sales.adjust(0, 6)
        "restored":
            Msp.mail(from, "The new computer", "It took an extra day to get the xray software back, but it works. Next time, please ask what I keep on there first. - Patel")
            Sales.adjust(0, 1)
        "lost":
            Msp.mail(from, "Still thinking about the xray software", "My staff still talk about the week we spent reloading from CDs. I am asking for a quote from another IT company. - Patel")
            Sales.adjust(0, -8)


func _callback_ransom() -> void:
    var from := "Atty. Spence <spence@hootholler.example>"
    match str(flags.get("ransom", "")):
        "saved":
            Msp.mail(from, "Renewal", "After what happened in March, the partners voted to sign a three year renewal. A colleague at another firm asked for your number. - Spence")
            Sales.adjust(RANSOM_CLIENT, 8)
            Campaign.adjust_rep(1)
        "partial":
            Msp.mail(from, "Recovered files", "We got most of the files back. Two clients' records are gone and I had to call them. The partners are watching your work closely. - Spence")
            Sales.adjust(RANSOM_CLIENT, -4)
        "paid":
            Msp.mail(from, "The ransom", "The partners still cannot believe we paid criminals in bitcoin. It worked, but we want a real backup plan, now. - Spence")
            Sales.adjust(RANSOM_CLIENT, -3)
        "lost":
            Msp.mail(from, "Reviewing our IT provider", "We lost two years of client files and had to tell the bar association. The partners are reviewing every IT provider in the county. - Spence")
            Sales.adjust(RANSOM_CLIENT, -12)


# before the review Morgan brings up the job that went worst
func _callback_worst() -> void:
    var names := {
        "install": "THE DESKTOP INSTALL", "ransom": "THE RANSOMWARE", "rack": "THE FALLEN RACK", "migration": "THE SERVER MIGRATION",
        "email24": "THE EMAIL NIGHT", "netinstall": "THE NETWORK INSTALL",
        "ceofraud": "THE WIRE FRAUD", "no2fa": "THE CLIENT WHO SAID NO", "bus": "THE DAY WITHOUT ALAN",
    }
    var scores := {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1, "ok": 5, "restored": 3, "lost": 1, "saved": 5, "partial": 3, "paid": 2}
    var worst_key := ""
    var worst := 99
    for key in names:
        var value := str(flags.get(key, ""))
        if value != "" and int(scores.get(value, 3)) < worst:
            worst = int(scores.get(value, 3))
            worst_key = key
    if worst_key == "" or worst >= 4:
        return
    Msp.mail(MANAGER.split(" - ")[0] + " <morgan@pixelit.example>", "Before we sit down", "I will ask about %s. It was your roughest job this year. Think about what you would do differently. - Morgan" % str(names[worst_key]).to_lower())


func _ransomware() -> void:
    var t := Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
    if t.is_empty():
        for ep in Msp.endpoints:
            if ep.client == RANSOM_CLIENT and ep.name.contains("SRV"):
                ep.problem = ""
        t = Msp.create_problem(RANSOM_CLIENT, Msp.RANSOM, "monitoring")
    flags["ransom_ticket"] = int(t.get("id", 0))
    var warning := "Hoot and Holler has a ransom note on their server. "
    warning += "Do NOT pay and do NOT reboot. Restore from backup!"
    Msp.send_text("Boss", warning)
''')

write("scripts/social.gd", '''extends Node
# Coworker opinions of you (campaign only). Each cast member keeps a number from -100 to 100:
#   +  chatting with them, covering the phones (every third call), closing tickets (their own
#      desk's outage ticket counts the most), the team's tickets (every fifth)
#   -  cutting their desk's network, reopened tickets
# Mood decides how they treat you: friends greet you with a heart, cold coworkers do not wave
# or follow you, hostile ones will not even chat. Reputation gets a small nudge from the
# average mood at the end of the day.

signal changed

const PEOPLE := ["Alan", "Garrison", "Dan", "Vic", "Maya"]
# Canon: Alan and Garrison are the two OWNERS of Pixel IT Partners (labels only; opinions work the same for everyone)
const OWNERS := ["Alan", "Garrison"]
const ROLES := {
    "Alan": "CO-OWNER",
    "Garrison": "CO-OWNER",
    "Dan": "NETWORK TECH",
    "Vic": "ACCOUNT MANAGER",
    "Maya": "TIER 1"
}
const DESK_OWNER := {6: "Alan", 7: "Garrison", 3: "Dan", 4: "Vic", 2: "Maya"}
const CHAT_GAP := 40.0  # seconds before another chat with the same person counts again
const THANKS := [
    "thanks for grabbing the phones earlier!", "you are a lifesaver on the phones", "hey, appreciate the phone coverage",
]

var rel := {}
var calls_answered := 0
const MAX_REOPEN_LOSS := 3

var day_delta := 0

var _last_chat := {}
var _closed := 0
var _reopen_loss := 0  # coworker opinion lost to reopens today (capped)


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


func _ready() -> void:
    reset()


func reset() -> void:
    rel = {}
    for who in PEOPLE:
        rel[who] = 0
    calls_answered = 0
    day_delta = 0
    _last_chat = {}
    _closed = 0
    _reopen_loss = 0


func value(who: String) -> int:
    return int(rel.get(who, 0))


func change(who: String, amount: int) -> void:
    if not Campaign.active or not rel.has(who):
        return
    var before := value(who)
    rel[who] = clampi(before + amount, -100, 100)
    day_delta += value(who) - before
    changed.emit()


func change_all(amount: int) -> void:
    for who in PEOPLE:
        change(who, amount)


func mood(who: String) -> String:
    var v := value(who)
    if v >= 60:
        return "FRIEND"
    if v >= 25:
        return "FRIENDLY"
    if v > -15:
        return "NEUTRAL"
    if v > -45:
        return "COLD"
    return "HOSTILE"


func is_friendly(who: String) -> bool:
    return Campaign.active and value(who) >= 25


func is_cold(who: String) -> bool:
    return Campaign.active and value(who) <= -15


func is_hostile(who: String) -> bool:
    return Campaign.active and value(who) <= -45


# the bubble icon over a chat with this person
func glyph(who: String) -> String:
    if is_friendly(who):
        return "heart"
    return "?" if is_cold(who) else "!"


func average() -> float:
    var total := 0
    for who in PEOPLE:
        total += value(who)
    return float(total) / float(PEOPLE.size())


# a small nudge to the end-of-day reputation change
func rep_bonus() -> int:
    if average() >= 40.0:
        return 1
    return -1 if average() <= -20.0 else 0


func note_chat(who: String) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    if now - float(_last_chat.get(who, -999.0)) >= CHAT_GAP:
        _last_chat[who] = now
        change(who, 1)


func note_call_answered() -> void:
    calls_answered += 1
    if Campaign.active and calls_answered % 3 == 0:
        change_all(1)
        Msp.send_text(PEOPLE[randi() % PEOPLE.size()], THANKS[randi() % THANKS.size()])


func note_ticket_closed(ticket: Dictionary) -> void:
    if ticket.internal:
        change(str(DESK_OWNER.get(int(ticket.desk), "")), 4)
        return
    _closed += 1
    if _closed % 5 == 0:
        change_all(1)


func note_reopen() -> void:
    # at most 3 points a day, so a bad habit hurts but one rough day does not wreck the row
    if _reopen_loss >= MAX_REOPEN_LOSS:
        return
    _reopen_loss += 1
    change_all(-1)


func note_outage(desk: int) -> void:
    change(str(DESK_OWNER.get(desk, "")), -2)


func note_outage_fixed(desk: int) -> void:
    change(str(DESK_OWNER.get(desk, "")), 2)


func begin_day() -> void:
    day_delta = 0
    _reopen_loss = 0


func to_dict() -> Dictionary:
    return {"rel": rel.duplicate(), "calls": calls_answered}


func from_dict(data: Dictionary) -> void:
    reset()
    var saved: Dictionary = data.get("rel", {})
    for who in saved:
        if rel.has(who):
            rel[who] = int(saved[who])
    calls_answered = int(data.get("calls", 0))
''')

write("scripts/playbook.gd", '''extends Node
# gdlint:disable=max-line-length
# Playbooks: the multi-step jobs of the tech campaign (a client's rack falls off the wall, a server migration, the 24x7
# email outage with the vendor call, a network install). Each step is a situation with choices. A choice can cost real
# seconds (`secs`, a timed job on the computer) and game hours (`hours`, the clock jumps: that is how the email outage
# runs into the night), awards points (`pts`), sets flags, and can be locked behind a skill (`req`) or an earlier flag
# (`needs`). The best path is the high-points one; sloppy choices leave flags that cause trouble later.
# The jobs show in LabRat RMM, PROJECT tab.

signal changed

const BOOKS := {
    "rack": {
        "title": "RACK RECOVERY", "client": 2, "specials": ["rack"],
        "steps": [
            {"title": "MAKE IT SAFE", "text": "The rack tore off the plywood wall and is lying on the floor, still powered, with the UPS beeping. What first?",
             "choices": [
                {"label": "POWER EVERYTHING DOWN", "secs": 4.0, "pts": 20, "hours": 0.1, "note": "Everything powered down cleanly."},
                {"label": "PHOTOGRAPH THE CABLING FIRST", "secs": 6.0, "pts": 15, "hours": 0.2, "flag": "photo", "note": "Photos taken. They will save time later."},
                {"label": "STAND IT UP RIGHT AWAY", "secs": 2.0, "pts": 0, "hours": 0.1, "flag": "damaged", "note": "Sparks! The switch fan died."},
            ]},
            {"title": "REMOUNT THE RACK", "text": "The plywood wall ripped out. How do you get the rack back up?",
             "choices": [
                {"label": "BUY ANCHORS, MOUNT TO THE STUDS", "secs": 8.0, "pts": 20, "hours": 0.5, "note": "Mounted to the studs. It is not going anywhere."},
                {"label": "PROP IT ON A DESK FOR NOW", "secs": 2.0, "pts": 5, "hours": 0.1, "flag": "temp", "note": "Propped on a desk. Temporary."},
                {"label": "SCREW IT INTO THE DRYWALL", "secs": 3.0, "pts": 0, "hours": 0.2, "flag": "weak", "note": "Hopefully those anchors hold."},
            ]},
            {"title": "RECABLE", "text": "Dozens of cables, half the labels torn off. How do you put it back together?",
             "choices": [
                {"label": "FOLLOW YOUR PHOTOS", "secs": 6.0, "pts": 25, "hours": 0.3, "needs": "photo", "needs_label": "NEEDS PHOTOS", "note": "Cables match the photos exactly."},
                {"label": "RUN THE CABLE TESTER", "secs": 6.0, "pts": 25, "hours": 0.3, "req": ["networking", 2], "note": "The tester maps every cable to its port."},
                {"label": "TRACE AND LABEL EVERY CABLE", "secs": 12.0, "pts": 20, "hours": 0.6, "note": "Slow, but every cable is now labelled."},
                {"label": "PLUG THEM WHERE THEY FIT", "secs": 3.0, "pts": 5, "hours": 0.1, "flag": "miswired", "note": "It all fits somewhere."},
            ]},
            {"title": "POWER ON", "text": "Time to bring the network back up. In what order?",
             "choices": [
                {"label": "UPS, ROUTER, SWITCH, THEN THE NAS", "secs": 10.0, "pts": 25, "hours": 0.2, "note": "Everything came up in order."},
                {"label": "SWITCH FIRST, THEN THE REST", "secs": 8.0, "pts": 10, "hours": 0.2, "note": "Worked, but the router had to be rebooted."},
                {"label": "EVERYTHING AT ONCE", "secs": 3.0, "pts": 5, "hours": 0.5, "flag": "nas_check", "note": "The NAS is running a disk check for an hour."},
            ]},
            {"title": "VERIFY", "text": "Lights are green. Are you done?",
             "choices": [
                {"label": "TEST INTERNET, PRINTERS AND PHONES", "secs": 6.0, "pts": 15, "hours": 0.2, "flag": "verified", "note": "Everything tested and working."},
                {"label": "PING THE GATEWAY AND CALL IT DONE", "secs": 2.0, "pts": 5, "hours": 0.0, "flag": "unverified", "note": "The gateway answers. Probably fine."},
            ]},
        ],
    },
    "migration": {
        "title": "SERVER MIGRATION", "client": 1, "specials": ["migration"],
        "steps": [
            {"title": "PLAN", "text": "Brightside's old 2008 server is being replaced. Before anything else...",
             "choices": [
                {"label": "CHECK THE BACKUPS FIRST", "secs": 4.0, "pts": 20, "hours": 0.1, "effect": "backup", "note": "Backups checked."},
                {"label": "SKIP IT, WE ARE IN A HURRY", "secs": 0.0, "pts": 0, "flag": "nocheck", "note": "No time for backups. What could go wrong?"},
            ]},
            {"title": "PICK A WINDOW", "text": "When do you do the cutover?",
             "choices": [
                {"label": "AFTER HOURS TONIGHT", "secs": 4.0, "pts": 20, "hours": 0.0, "note": "Scheduled after hours. Nobody is disturbed."},
                {"label": "SATURDAY MORNING", "secs": 6.0, "pts": 15, "hours": 0.0, "note": "Scheduled for the weekend."},
                {"label": "RIGHT NOW, DURING THE DAY", "secs": 1.0, "pts": 0, "flag": "downtime", "note": "Everyone is working. This will be noisy."},
            ]},
            {"title": "COPY THE DATA", "text": "File shares, line-of-business data and permissions all have to move.",
             "choices": [
                {"label": "ROBOCOPY SCRIPT, KEEP PERMISSIONS", "secs": 6.0, "pts": 25, "hours": 0.5, "req": ["powershell", 3], "note": "Scripted copy with permissions intact."},
                {"label": "DISK IMAGE THE OLD SERVER", "secs": 10.0, "pts": 15, "hours": 1.0, "note": "Imaged and restored. Slow but safe."},
                {"label": "DRAG AND DROP THE FOLDERS", "secs": 14.0, "pts": 10, "hours": 1.0, "flag": "perms", "note": "Copied, but the permissions did not follow."},
            ]},
            {"title": "CUTOVER", "text": "The new server has the data. Switch the office over.",
             "choices": [
                {"label": "REPOINT DNS, REMAP DRIVES, TEST", "secs": 8.0, "pts": 20, "hours": 0.5, "note": "Cutover smooth. Drives remapped."},
                {"label": "JUST TURN THE OLD SERVER OFF", "secs": 2.0, "pts": 0, "hours": 0.1, "flag": "outage", "note": "Nobody can find the files. Phones are ringing."},
            ]},
            {"title": "RETIRE THE OLD ONE", "text": "What happens to the old server?",
             "choices": [
                {"label": "KEEP IT POWERED OFF FOR TWO WEEKS", "secs": 2.0, "pts": 15, "hours": 0.0, "note": "Parked in the closet, just in case."},
                {"label": "WIPE IT NOW", "secs": 4.0, "pts": 5, "hours": 0.0, "flag": "nostash", "note": "Wiped. There is no way back."},
            ]},
        ],
    },
    "email24": {
        "title": "EMAIL OUTAGE", "client": 4, "specials": ["email24"],
        "steps": [
            {"title": "DIAGNOSE", "text": "The brewery runs 24x7 and nobody has had email for an hour. Fermentation alerts are not arriving. Where do you start?",
             "choices": [
                {"label": "READ THE MAIL SERVER LOGS", "secs": 6.0, "pts": 20, "hours": 0.3, "flag": "diagnosed", "note": "The mail database dismounted: the log drive is full."},
                {"label": "ASK THE STAFF WHAT THEY SEE", "secs": 5.0, "pts": 10, "hours": 0.3, "note": "Staff just says: it is broken."},
                {"label": "REBOOT THE MAIL SERVER", "secs": 8.0, "pts": 0, "hours": 0.5, "flag": "rebooted", "note": "It is stuck in recovery now."},
            ]},
            {"title": "CALL THE VENDOR", "text": "The mail software vendor has a support line. It is 17:40 and the queue is long.",
             "choices": [
                {"label": "FOLLOW THE TIER 1 SCRIPT", "secs": 20.0, "pts": 5, "hours": 1.0, "note": "Forty minutes on hold. They say: reboot it."},
                {"label": "ASK FOR TIER 2", "secs": 14.0, "pts": 20, "hours": 0.7, "note": "Tier 2 agrees it is the log drive."},
                {"label": "NEGOTIATE AN ESCALATION", "secs": 8.0, "pts": 30, "hours": 0.4, "req": ["people", 2], "note": "An engineer is calling you back in ten minutes."},
            ]},
            {"title": "FIX IT", "text": "Free up the log drive and get the database mounted.",
             "choices": [
                {"label": "MOVE THE LOGS WITH A SCRIPT", "secs": 6.0, "pts": 25, "hours": 0.5, "req": ["powershell", 2], "note": "Logs moved. The drive has 90 GB free."},
                {"label": "WAIT FOR THE VENDOR ENGINEER", "secs": 25.0, "pts": 15, "hours": 1.5, "note": "The engineer fixes it, eventually."},
                {"label": "DELETE OLD LOGS BY HAND", "secs": 14.0, "pts": 10, "hours": 1.0, "flag": "risky", "note": "You deleted logs the database still needed."},
            ]},
            {"title": "PROVE IT WORKS", "text": "The database says it is mounted.",
             "choices": [
                {"label": "REMOUNT AND SEND TEST MAIL", "secs": 6.0, "pts": 15, "hours": 0.3, "note": "Test mail went through both ways."},
                {"label": "MARK IT FIXED AND GO HOME", "secs": 1.0, "pts": 0, "hours": 0.0, "flag": "unverified", "note": "Closed without testing. Hope."},
            ]},
            {"title": "TELL THE STAFF", "text": "People have been waiting all evening.",
             "choices": [
                {"label": "EMAIL A STATUS TO EVERYONE", "secs": 4.0, "pts": 10, "hours": 0.2, "note": "A clear status email goes out."},
                {"label": "SAY NOTHING", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "Radio silence."},
            ]},
        ],
    },
    "rdp": {
        "title": "REMOTE ACCESS BREAK-IN", "client": 1, "specials": ["rdp"],
        "steps": [
            {"title": "DIAGNOSE", "text": "Brightside's server crawls and the realtors say strange users keep showing up in the logs. Where do you look?",
             "choices": [
                {"label": "READ THE SECURITY EVENT LOG", "secs": 6.0, "pts": 20, "hours": 0.3, "flag": "diag", "note": "Thousands of failed logins a day from overseas, hammering the Administrator account."},
                {"label": "ASK THE USERS WHAT CHANGED", "secs": 5.0, "pts": 10, "hours": 0.3, "note": "Nobody changed anything. It was fine last week."},
                {"label": "REBOOT THE SERVER", "secs": 8.0, "pts": 0, "hours": 0.4, "flag": "rebooted", "note": "Back up in minutes, just as slow."},
            ]},
            {"title": "FIND THE HOLE", "text": "Something is getting in. How do you find it?",
             "choices": [
                {"label": "CHECK THE FIREWALL RULES", "secs": 6.0, "pts": 20, "hours": 0.3, "flag": "found", "note": "Port 3389 (remote desktop) is forwarded straight to the server. The whole internet can try to log in."},
                {"label": "SCAN THE SERVER FOR MALWARE", "secs": 8.0, "pts": 10, "hours": 0.4, "note": "Nothing found. It is not a virus, it is somebody logging in."},
                {"label": "BLAME THE ANTIVIRUS", "secs": 1.0, "pts": 0, "hours": 0.1, "flag": "wrongtrack", "note": "The antivirus has nothing to do with it."},
            ]},
            {"title": "CONTAIN", "text": "Some of those thousands of guesses might have worked. Most attackers back then just guess common passwords.",
             "choices": [
                {"label": "AUDIT THE ACCOUNTS, RESET THE WEAK PASSWORDS", "secs": 10.0, "pts": 25, "hours": 0.6, "flag": "audited", "note": "Two accounts used passwords like Summer2013. One had been used from overseas last week: it relayed spam, nothing was copied."},
                {"label": "JUST RESET THE ADMINISTRATOR PASSWORD", "secs": 3.0, "pts": 10, "hours": 0.1, "flag": "partial", "note": "Better, but two realtor accounts still use weak passwords."},
                {"label": "DO NOTHING UNTIL THE FIREWALL IS FIXED", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "unaudited", "note": "Whatever got in is still in."},
            ]},
            {"title": "CLOSE THE DOOR", "text": "Remote desktop is wide open to the internet. What do you do about it?",
             "choices": [
                {"label": "PUT REMOTE DESKTOP BEHIND A VPN", "secs": 10.0, "pts": 25, "hours": 1.0, "flag": "vpn", "note": "Remote access now needs the VPN first. The guessing attacks hit a closed door."},
                {"label": "FIREWALL THAT AUTO-BLOCKS REPEATED FAILED LOGINS", "secs": 6.0, "pts": 20, "hours": 0.5, "flag": "autoblock", "note": "After a few bad guesses an address is blocked automatically. The attacks stop within the hour."},
                {"label": "JUST CHANGE THE REMOTE DESKTOP PORT NUMBER", "secs": 3.0, "pts": 5, "hours": 0.1, "flag": "obscurity", "note": "A new port number. They will find it."},
                {"label": "LEAVE IT, THE PASSWORDS ARE FIXED NOW", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "open", "note": "Still open to the whole internet."},
            ]},
            {"title": "TELL THE CLIENT", "text": "How do you leave things with the realtors?",
             "choices": [
                {"label": "WRITE IT UP, RECOMMEND TWO-FACTOR AND A VPN", "secs": 6.0, "pts": 15, "hours": 0.3, "flag": "documented", "note": "A clear write-up with recommendations goes to the owners."},
                {"label": "FIX IT QUIETLY", "secs": 0.0, "pts": 5, "hours": 0.0, "note": "No write-up. They never learn how close it was."},
            ]},
        ],
    },
    "ceofraud": {
        "title": "WIRE REQUEST FROM THE BOSS", "client": 3, "specials": ["ceofraud"],
        "steps": [
            {"title": "THE EMAIL", "text": "A paralegal at Hoot and Holler forwards an email that looks like it is from Atty. Spence: wire $38,000 from the client trust account today, quietly, no calls. She thinks it is odd. What do you do first?",
             "choices": [
                {"label": "LOOK AT THE FULL EMAIL HEADERS", "secs": 6.0, "pts": 20, "hours": 0.3, "flag": "headers", "note": "The sender name says Spence. The reply address is spence@hootholler-law.example: a lookalike domain."},
                {"label": "CALL ATTY. SPENCE ON HIS CELL", "secs": 4.0, "pts": 25, "hours": 0.2, "flag": "called", "note": "He never sent anything. He is in a deposition and furious that anyone would think so."},
                {"label": "REPLY AND ASK IF IT IS REAL", "secs": 2.0, "pts": 3, "hours": 0.1, "flag": "replied", "note": "'Yes, it is me. Please hurry.' The scammer answers in four minutes."},
                {"label": "TELL HER TO WIRE IT, IT LOOKS REAL", "secs": 1.0, "pts": 0, "hours": 0.0, "flag": "wired", "note": "The wire goes out before lunch."},
            ]},
            {"title": "HOW DID THEY KNOW?", "text": "The email used the right wording, the right account and the right amount. Somebody has been reading the firm's mail. Where do you look?",
             "choices": [
                {"label": "CHECK THE MAILBOX RULES AND RECENT LOGINS", "secs": 8.0, "pts": 25, "hours": 0.4, "flag": "rule", "note": "A hidden rule forwards every message mentioning wires to an outside address. The login that created it came from overseas."},
                {"label": "RESET EVERYONE'S PASSWORD AND HOPE", "secs": 5.0, "pts": 10, "hours": 0.3, "flag": "reset", "note": "New passwords, but the forwarding rule is still there."},
                {"label": "BLAME THE SPAM FILTER", "secs": 1.0, "pts": 0, "hours": 0.1, "note": "The spam filter has nothing to do with it."},
            ]},
            {"title": "CONTAIN IT", "text": "The attacker has a way into the mailbox. What do you do?",
             "choices": [
                {"label": "REMOVE THE RULE, RESET THE PASSWORD, END ALL SESSIONS", "secs": 8.0, "pts": 25, "hours": 0.4, "flag": "contained", "note": "The rule is gone, the password is new and every login session is signed out."},
                {"label": "JUST RESET THE PASSWORD", "secs": 3.0, "pts": 10, "hours": 0.1, "flag": "partial", "note": "The old session is still signed in on a server in another country."},
                {"label": "DELETE THE EMAIL AND MOVE ON", "secs": 1.0, "pts": 0, "hours": 0.0, "flag": "deleted", "note": "You deleted the evidence the bank will want."},
            ]},
            {"title": "THE MONEY", "text": "Was anything already sent? The trust account matters more than the mailbox.",
             "choices": [
                {"label": "HAVE THE FIRM CALL THE BANK AND ASK FOR A RECALL NOW", "secs": 3.0, "pts": 20, "hours": 0.2, "flag": "bank", "note": "The bank freezes the wire in time. This is a good day."},
                {"label": "SEND THE BANK AN EMAIL FOR MORNING", "secs": 2.0, "pts": 5, "hours": 0.0, "flag": "late", "note": "The bank answers tomorrow. That is probably too late."},
            ]},
            {"title": "NEXT TIME", "text": "How do you leave things with the firm?",
             "choices": [
                {"label": "CALL-BACK RULE FOR EVERY WIRE REQUEST, PLUS TWO-FACTOR LOGIN FOR EMAIL", "secs": 6.0, "pts": 20, "hours": 0.3, "flag": "trained", "note": "A new rule goes on the wall: no wire without a phone call to a known number."},
                {"label": "SEND A SCARY EMAIL TO EVERYONE", "secs": 2.0, "pts": 5, "hours": 0.1, "note": "Everybody reads it. Nobody changes anything."},
                {"label": "FIX IT QUIETLY", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "quiet", "note": "No write-up. They will be a target again."},
            ]},
        ],
    },
    "no2fa": {
        "title": "THE CLIENT WHO SAID NO", "client": 4, "specials": ["no2fa"],
        "steps": [
            {"title": "THE CONVERSATION", "text": "Soggy Bottom Brewing keeps getting phished and you want stronger passwords and a second login step. Lucy says it is too much hassle and she is not changing anything. How do you handle it?",
             "choices": [
                {"label": "SHOW HER WHAT A STOLEN PASSWORD LOOKS LIKE", "secs": 6.0, "pts": 20, "hours": 0.5, "flag": "showed", "note": "You pull up a list of leaked passwords from other companies. Hers is on it. She goes quiet."},
                {"label": "GET A SIGNED WAIVER", "secs": 5.0, "pts": 15, "hours": 0.3, "flag": "waiver", "note": "She signs that she was warned and declined. The paper trail will protect you."},
                {"label": "INSIST: NO CHANGE, NO SERVICE", "secs": 3.0, "pts": 10, "hours": 0.2, "flag": "insisted", "note": "She is furious, but she agrees to try it for a month."},
                {"label": "LET IT GO", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "ignored", "note": "You leave without a word. Nothing changes."},
            ]},
            {"title": "ROLL IT OUT", "text": "If she agrees, how do you do it so it hurts as little as possible?",
             "choices": [
                {"label": "START WITH THE OWNER AND THE BOOKKEEPER, THEN EVERYONE ELSE", "secs": 8.0, "pts": 20, "hours": 0.6, "flag": "phased", "needs": "showed", "needs_label": "SHOW HER FIRST", "note": "The two people who handle money get it first. Everyone else gets it next week."},
                {"label": "TURN IT ON FOR EVERYONE AT ONCE", "secs": 6.0, "pts": 10, "hours": 0.4, "flag": "bigbang", "needs": "insisted", "needs_label": "NEEDS THE INSIST", "note": "Everyone is locked out Monday morning. Lucy calls you eleven times."},
                {"label": "WRITE DOWN THE RISK AND LEAVE IT", "secs": 4.0, "pts": 10, "hours": 0.3, "flag": "writeup", "note": "You file the risk assessment and move on."},
            ]},
            {"title": "THE FOLLOW-UP", "text": "How do you leave it?",
             "choices": [
                {"label": "BOOK A CHECK-IN IN THREE WEEKS", "secs": 3.0, "pts": 15, "hours": 0.1, "flag": "checkin", "note": "A reminder goes on the calendar."},
                {"label": "NOTHING", "secs": 0.0, "pts": 0, "hours": 0.0, "note": "You will see how it goes."},
            ]},
        ],
    },
    "bus": {
        "title": "THE ONLY PERSON WHO KNOWS", "client": 0, "specials": ["bus"],
        "steps": [
            {"title": "ALAN IS OUT", "text": "Acme Dental's internet is flaky and the fix is a setting in their firewall. Alan, one of our owners, built it years ago and he is out sick today. Nobody has the password. What do you try?",
             "choices": [
                {"label": "LOOK IN THE DOCUMENTATION PORTAL", "secs": 6.0, "pts": 25, "hours": 0.3, "flag": "docs", "note": "There is an entry, half finished, and a note that says the password is in the safe."},
                {"label": "LOOK ON ALAN'S DESK", "secs": 4.0, "pts": 10, "hours": 0.2, "flag": "sticky", "note": "A sticky note under the keyboard has a password on it. Of course it does."},
                {"label": "CALL ALAN AT HOME", "secs": 3.0, "pts": 15, "hours": 0.2, "flag": "called", "req": ["people", 2], "note": "He answers from the couch and tells you."},
                {"label": "FACTORY RESET THE FIREWALL", "secs": 10.0, "pts": 0, "hours": 0.5, "flag": "reset", "note": "It reboots with a blank configuration. Acme's internet is now completely gone."},
            ]},
            {"title": "GET IN", "text": "You have a way in (or you wiped it). What next?",
             "choices": [
                {"label": "CHANGE THE SETTING AND TEST EVERYTHING", "secs": 8.0, "pts": 25, "hours": 0.4, "flag": "fixed", "note": "The change is small and the internet is stable again."},
                {"label": "CHANGE THE SETTING AND HOPE", "secs": 4.0, "pts": 10, "hours": 0.1, "flag": "unverified", "note": "It seems better."},
                {"label": "REBUILD THE CONFIGURATION FROM SCRATCH", "secs": 12.0, "pts": 15, "hours": 1.0, "flag": "rebuilt", "needs": "reset", "needs_label": "ONLY AFTER A RESET", "note": "It takes an hour, and you spend most of it guessing what Alan did."},
            ]},
            {"title": "NEVER AGAIN", "text": "This should never depend on one person. What do you do before you leave?",
             "choices": [
                {"label": "DOCUMENT IT AND PUT THE PASSWORD IN THE PASSWORD VAULT", "secs": 8.0, "pts": 25, "hours": 0.5, "flag": "documented", "note": "The firewall now has a page in the portal and a vaulted password everyone can use."},
                {"label": "WRITE IT ON A STICKY NOTE", "secs": 2.0, "pts": 0, "hours": 0.0, "flag": "sticky2", "note": "Alan would be proud."},
                {"label": "TELL ALAN TO WRITE IT DOWN LATER", "secs": 1.0, "pts": 5, "hours": 0.0, "note": "He promises to. He will not."},
            ]},
        ],
    },
    "netinstall": {
        "title": "NETWORK INSTALL", "client": 3, "specials": ["netinstall"],
        "steps": [
            {"title": "SURVEY THE SITE", "text": "Hoot and Holler is opening a branch office: 12 desks, a conference room and a printer room.",
             "choices": [
                {"label": "WALK THE SITE AND COUNT DROPS", "secs": 8.0, "pts": 20, "hours": 0.5, "note": "You count 14 drops, not 12."},
                {"label": "ASK FOR THE LAYOUT BY EMAIL", "secs": 5.0, "pts": 10, "hours": 0.2, "note": "You get a rough floor plan."},
                {"label": "TRUST THE FLOOR PLAN", "secs": 2.0, "pts": 5, "hours": 0.0, "flag": "guess", "note": "You plan for 12 drops."},
            ]},
            {"title": "RUN THE CABLE", "text": "Pulling cable through the ceiling.",
             "choices": [
                {"label": "CAT6, 14 DROPS", "secs": 14.0, "pts": 20, "hours": 1.0, "note": "Cat6 pulled everywhere: future-proof."},
                {"label": "CAT5E, 14 DROPS", "secs": 10.0, "pts": 15, "hours": 0.8, "note": "Cat5e is fine for gigabit."},
                {"label": "CAT5E, 10 DROPS TO SAVE TIME", "secs": 6.0, "pts": 5, "hours": 0.5, "flag": "short", "note": "Four desks have no wall jack."},
            ]},
            {"title": "TEST THE RUNS", "text": "Are all those cables good?",
             "choices": [
                {"label": "CERTIFY EVERY DROP WITH THE TESTER", "secs": 10.0, "pts": 20, "hours": 0.5, "note": "Every drop certified."},
                {"label": "SPOT CHECK A FEW", "secs": 4.0, "pts": 10, "hours": 0.2, "flag": "untested", "note": "Most look fine."},
                {"label": "SKIP IT, WE WILL FIND OUT", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "untested", "note": "We will find out."},
            ]},
            {"title": "CONFIGURE THE SWITCHES", "text": "Data, voice phones and guest Wi-Fi all share this network.",
             "choices": [
                {"label": "VLANS: DATA, VOICE AND GUEST", "secs": 8.0, "pts": 25, "hours": 0.5, "req": ["powershell", 2], "note": "Three clean VLANs with scripted configs."},
                {"label": "SEPARATE THE VOICE VLAN ONLY", "secs": 8.0, "pts": 15, "hours": 0.5, "note": "Phones are separate. Guests share the data VLAN."},
                {"label": "ONE FLAT NETWORK", "secs": 3.0, "pts": 5, "hours": 0.1, "flag": "flat", "note": "Everything on one network."},
            ]},
            {"title": "WI-FI", "text": "Staff and guests want wireless everywhere.",
             "choices": [
                {"label": "SURVEY, THEN PLACE TWO ACCESS POINTS", "secs": 8.0, "pts": 20, "hours": 0.5, "note": "Coverage is solid everywhere."},
                {"label": "ONE ACCESS POINT IN THE MIDDLE", "secs": 3.0, "pts": 10, "hours": 0.1, "flag": "deadzone", "note": "The conference room has a dead spot."},
            ]},
            {"title": "DOCUMENT IT", "text": "The job is done and it is nearly time to go.",
             "choices": [
                {"label": "LABEL THE PANEL AND WRITE IT UP", "secs": 8.0, "pts": 20, "hours": 0.4, "flag": "documented", "note": "Every port labelled. Documentation filed."},
                {"label": "SKIP THE PAPERWORK", "secs": 0.0, "pts": 0, "hours": 0.0, "flag": "undocumented", "note": "No documentation. Future you will suffer."},
            ]},
        ],
    },
}
const PROBLEMS := {
    "rack": [
        {"summary": "RACK FELL OFF THE WALL - everything is down", "fix": "project", "pri": 1, "special": "rack",
         "body": "The whole network rack came off the wall with a crash! Nothing works! Please come NOW. - %s"},
        {"summary": "No internet in the whole shop", "fix": "project", "pri": 2, "special": "rack",
         "body": "Is the internet down for you too? It is dead here. - %s"},
        {"summary": "Phones are dead", "fix": "project", "pri": 2, "special": "rack",
         "body": "Customers cannot reach us, the phones are all dead. - %s"},
    ],
    "migration": [
        {"summary": "Server migration: cutover", "fix": "project", "pri": 3, "special": "migration", "server": true,
         "body": "The old server is out of support, we agreed you would move us to the new one. Please do it carefully. - %s"},
    ],
    "email24": [
        {"summary": "EMAIL DOWN - 24x7 site", "fix": "project", "pri": 1, "special": "email24", "server": true,
         "body": "Nobody has had email for an hour and our fermentation alerts come by email. We run around the clock. FIX IT! - %s"},
    ],
    "rdp": [
        {"summary": "Server very slow, strange logins in the log", "fix": "project", "pri": 2, "special": "rdp", "server": true,
         "body": "Our server has been crawling all week and the log shows people we do not know. Can you look? - %s"},
    ],
    "ceofraud": [
        {"summary": "Odd request to wire $38,000 from the trust account", "fix": "project", "pri": 1, "special": "ceofraud",
         "body": "Our paralegal got an email from Mr. Spence asking her to wire $38,000. He says he never sent it. What is going on? - %s"},
    ],
    "no2fa": [
        {"summary": "Security review: stronger logins for Soggy Bottom", "fix": "project", "pri": 3, "special": "no2fa",
         "body": "You wanted to talk about passwords or something. I do not have time for this. - %s"},
    ],
    "bus": [
        {"summary": "Internet keeps dropping at Acme Dental", "fix": "project", "pri": 2, "special": "bus",
         "body": "The internet drops every few minutes and patients are waiting. Alan always knows what to do but he is out today! - %s"},
    ],
    "netinstall": [
        {"summary": "New branch office network install", "fix": "project", "pri": 3, "special": "netinstall",
         "body": "We open the new branch next week and need the network, phones and Wi-Fi set up. - %s"},
    ],
}

var active := {}  # the job in progress: {id, tickets, step, pts, flags, log, done, result, start_client_backup}

var last_note := ""


func reset() -> void:
    active = {}
    last_note = ""


func is_active() -> bool:
    return not active.is_empty() and not bool(active.done)


func steps_of(id: String) -> Array:
    return BOOKS[id].steps


func max_points(id: String) -> int:
    var total := 0
    for step in steps_of(id):
        var best := 0
        for ch in step.choices:
            best = maxi(best, int(ch.pts))
        total += best
    return total


# open the tickets for a job and start it; returns the main ticket id
func start(id: String, source := "email") -> int:
    var ids := []
    for prob in PROBLEMS[id]:
        var t := Msp.create_problem(int(BOOKS[id].client), prob, source)
        if not t.is_empty():
            ids.append(int(t.id))
    active = {
        "id": id, "tickets": ids, "step": 0, "pts": 0, "flags": {}, "log": [], "done": false, "result": {},
        "backup_ok": bool(Msp.backups[int(BOOKS[id].client)].ok),
    }
    if id == "email24":
        Story.overtime = true
    changed.emit()
    return int(ids[0]) if not ids.is_empty() else 0


func current_step() -> Dictionary:
    if active.is_empty() or bool(active.done):
        return {}
    return steps_of(str(active.id))[int(active.step)]


# why a choice can't be picked yet ("" = available)
func lock_reason(choice: Dictionary) -> String:
    if choice.has("req"):
        var skill: String = choice.req[0]
        if Skills.level(skill) < int(choice.req[1]):
            return "%s %d" % [str(Skills.NAMES[skill]), int(choice.req[1])]
    if choice.has("needs") and not active.flags.get(choice.needs, false):
        return str(choice.get("needs_label", "NEEDS " + str(choice.needs).to_upper()))
    return ""


func choice_secs(choice: Dictionary) -> float:
    return float(choice.secs) if Campaign.active else 0.0


func choose(index: int) -> Dictionary:
    var step := current_step()
    if step.is_empty():
        return {}
    var choice: Dictionary = step.choices[index]
    if lock_reason(choice) != "":
        return {}
    active.pts = int(active.pts) + int(choice.pts)
    if choice.has("flag"):
        active.flags[choice.flag] = true
    var note := str(choice.note)
    if choice.get("effect", "") == "backup":
        var client: int = BOOKS[active.id].client
        var b := Msp.backup_check(client)
        if not b.ok:
            Msp.backup_rerun(client)
            active.flags["backup_fixed"] = true
            note = "The backup was FAILING. You re-ran it before touching anything."
            active.pts = int(active.pts) + 10
    World.clock += float(choice.get("hours", 0.0))
    active.log.append(note)
    last_note = note
    active.step = int(active.step) + 1
    if int(active.step) >= steps_of(str(active.id)).size():
        finish()
    changed.emit()
    return choice


func grade_for(percent: int) -> String:
    for entry in [[92, "S"], [80, "A"], [65, "B"], [45, "C"]]:
        if percent >= int(entry[0]):
            return str(entry[1])
    return "D"


func finish() -> void:
    var id: String = active.id
    var flags: Dictionary = active.flags
    var percent := clampi(int(100.0 * float(active.pts) / float(max_points(id))), 0, 100)
    var grade := grade_for(percent)
    var rep_delta: int = {"S": 5, "A": 3, "B": 1, "C": -2, "D": -5}[grade]
    var client: int = BOOKS[id].client
    var contact: String = Msp.CLIENTS[client].contact
    var address: String = contact + " <" + Msp.CLIENTS[client].mail + ">"
    var extra := _outcome(id, flags, client)
    rep_delta += int(extra.rep)
    Msp.score += int((percent - 50) / 2.5) + int(extra.score)
    Campaign.adjust_rep(rep_delta)
    Sales.adjust(client, {"S": 10, "A": 6, "B": 2, "C": -5, "D": -12}[grade])
    Skills.add_xp("networking" if id in ["rack", "netinstall"] else ("security" if id in ["rdp", "ceofraud", "no2fa"] else ("people" if id == "bus" else "servers")), 12)
    for t in Msp.tickets:
        if t.status != "Closed" and BOOKS[id].specials.has(str(t.special)):
            t.fix_done = true
            t.notes.append("Job finished: grade %s (%d%%)." % [grade, percent])
            var ep := Msp.endpoint(str(t.endpoint))
            if not ep.is_empty() and ep.problem == "project":
                ep.problem = ""
    Msp.mail(address, "RE: " + str(PROBLEMS[id][0].summary), str(extra.mail))
    if id == "email24":
        Story.overtime = false
        Story.ot_hours = maxf(0.0, World.clock - World.DAY_END)
    for follow in extra.follow:
        Story.queue_followup(follow)
    active.done = true
    active.result = {"pts": percent, "grade": grade, "text": str(extra.mail)}
    Story.flags[id] = grade
    changed.emit()


# what the flags cost or earn: returns {rep, score, mail, follow: [{client, summary, body}]}
func _outcome(id: String, flags: Dictionary, client: int) -> Dictionary:
    var out := {"rep": 0, "score": 0, "mail": "Thank you, that was handled well.", "follow": []}
    match id:
        "rack":
            out.mail = "We are back up. Thank you for dropping everything!"
            if flags.get("damaged", false):
                out.score = -5
                out.mail = "We are up, but you killed the switch fan. Please be careful."
            if flags.get("weak", false) or flags.get("temp", false):
                out.follow.append({"client": client, "summary": "Rack is wobbling again", "body": "The rack is moving on the wall again. I am scared to touch it. - %s", "pri": 2})
            if flags.get("miswired", false):
                out.follow.append({"client": client, "summary": "Some desks have no network", "body": "Two desks cannot get online since the rack incident. - %s", "pri": 2})
            if flags.get("unverified", false):
                out.follow.append({"client": client, "summary": "Phones randomly dropping calls", "body": "Our phones drop calls since the rack fell. You said it was fixed! - %s", "pri": 2})
        "migration":
            out.mail = "The new server is great, nobody noticed the move."
            if flags.get("nocheck", false) and not active.backup_ok:
                out.rep = -12
                out.score = -20
                out.mail = "The cutover corrupted the accounting data and your backup was NOT running. We lost a month of books!"
                Msp.send_text("Boss", "Brightside lost data in the migration and the backup was broken. We need to talk.")
            elif flags.get("outage", false) or flags.get("downtime", false):
                out.rep = -2
                out.mail = "It works now, but we had a rough hour with nobody able to open files."
            if flags.get("perms", false):
                out.follow.append({"client": client, "summary": "Staff can see each other's files", "body": "Everyone can open the payroll folder now! - %s", "pri": 2})
        "email24":
            out.mail = "Email is back and the brewery alerts are flowing. You saved the batch. Thank you!"
            if flags.get("rebooted", false):
                out.score = -5
            if flags.get("risky", false):
                out.follow.append({"client": client, "summary": "Email database errors again", "body": "Email stopped again after midnight, errors in the log. - %s", "pri": 2})
            if flags.get("unverified", false):
                out.rep = -3
                out.mail = "You said it was fixed, but mail still bounces from outside. Please check properly!"
        "rdp":
            out.mail = "Thank you. We had no idea the server was open to the whole internet."
            if (flags.get("vpn", false) or flags.get("autoblock", false)) and flags.get("audited", false):
                out.rep = 2
                out.mail = "Door closed and accounts audited. We sleep better now. Thank you."
            if flags.get("open", false):
                out.rep = -2
                out.follow.append({"client": client, "summary": "Server hacked again from overseas", "body": "The log shows another login from overseas and files have been renamed. You said it was fixed! - %s", "pri": 1})
            if flags.get("obscurity", false):
                out.follow.append({"client": client, "summary": "Password guessing is back on the new port", "body": "The same attackers are back, on the new port number. - %s", "pri": 2})
            if flags.get("unaudited", false) or flags.get("partial", false):
                out.score = -5
                out.follow.append({"client": client, "summary": "Our email is being blocked as spam", "body": "Customers say our messages bounce as spam. Is our server sending junk? - %s", "pri": 2})
        "ceofraud":
            out.mail = "Thank you. The money is safe and Mr. Spence says he would like you to explain the whole thing to the partners."
            if flags.get("wired", false):
                out.rep = -10
                out.score = -25
                out.mail = "The $38,000 is gone. The bank cannot recall it. The partners want to know why IT did not stop it."
                Msp.send_text("Boss", "Hoot and Holler wired money to a scammer. Come see me. Now.")
            else:
                if flags.get("late", false) and not flags.get("bank", false):
                    out.score = -10
                    out.mail = "The bank says part of the wire is already gone. We will be fine, but it was close."
                if flags.get("replied", false):
                    out.score -= 3
                if flags.get("deleted", false):
                    out.follow.append({"client": client, "summary": "The bank wants the original email", "body": "The bank asked for the original fraud email and it was deleted. Can you recover it? - %s", "pri": 3})
                if flags.get("partial", false) or flags.get("reset", false):
                    out.follow.append({"client": client, "summary": "Another strange email from the boss", "body": "We just got another odd email that looks like Mr. Spence wrote it. - %s", "pri": 1})
                if flags.get("quiet", false):
                    out.follow.append({"client": client, "summary": "The same request again", "body": "Somebody emailed asking for a wire again. Is this normal? - %s", "pri": 2})
                if flags.get("trained", false):
                    out.rep = 3
        "no2fa":
            out.mail = "I did not like it, but we have it now."
            if flags.get("ignored", false):
                out.rep = -3
                out.mail = "Nobody wanted to talk about it."
                out.follow.append({"client": client, "summary": "Our email was used to send spam", "body": "Customers say they got spam from our address and one said it was a phishing email! - %s", "pri": 1})
                Sales.adjust(client, -6)
            elif flags.get("waiver", false) and not flags.get("showed", false):
                out.mail = "We signed what you asked. If something happens it is not on you, I suppose."
            if flags.get("bigbang", false):
                Sales.adjust(client, -8)
            if flags.get("showed", false) and flags.get("phased", false):
                out.rep = 2
                out.mail = "You were right about the password. Thank you for not making me feel stupid."
        "bus":
            out.mail = "Thank you for jumping in. We never realised how much depended on Alan."
            if flags.get("reset", false):
                out.score = -10
                out.mail = "We lost the internet for an hour and a half. Never touch the firewall like that again."
                Msp.send_text("Alan", "I heard you reset the firewall. I am coming in. Do not touch anything else.")
            if flags.get("sticky2", false) or flags.get("unverified", false):
                out.follow.append({"client": client, "summary": "Internet dropped again", "body": "It dropped again this morning. Was it fixed? - %s", "pri": 2})
            if flags.get("documented", false):
                out.rep = 2
                Social.change("Alan", 3)
        "netinstall":
            out.mail = "The new branch is online and everything works. Great job."
            if flags.get("documented", false):
                out.rep = 2
            if flags.get("untested", false):
                out.follow.append({"client": client, "summary": "Two wall jacks are dead", "body": "Two desks at the branch have no network from the wall. - %s", "pri": 3})
            if flags.get("flat", false):
                out.follow.append({"client": client, "summary": "Guest Wi-Fi can reach our servers", "body": "A guest could open our file server. Is that normal?! - %s", "pri": 2})
            if flags.get("deadzone", false) or flags.get("short", false):
                out.follow.append({"client": client, "summary": "Branch Wi-Fi / jacks missing", "body": "The conference room has no Wi-Fi and four desks have no jack. - %s", "pri": 3})
    return out
''')

write("scripts/review.gd", '''extends CanvasLayer
# gdlint:disable=max-line-length
# The yearly review at the end of the tech campaign (after day 20's report): your manager goes over the year, your
# coworkers weigh in, and you choose what comes next: become team lead, take an in-house IT job at a client, or stay
# an MSP tech. Offers depend on your reputation, your coworkers and how the big jobs went. Enter / Up / Down / click.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")
const GOOD := Color("1f7a3a")
const BAD := Color("b3262c")
const BLUE := Color("1f4e8c")
const GRADE_NAMES := {"S": 5, "A": 4, "B": 3, "C": 2, "D": 1}
const JOBS := [
    ["install", "NEW DESKTOP"], ["ransom", "RANSOMWARE"], ["rack", "RACK FELL OFF"], ["migration", "SERVER MIGRATION"],
    ["email24", "EMAIL OUTAGE"], ["netinstall", "NETWORK INSTALL"],
]
const CLIENT_OF := {
    "rack": "Gnarly Gnomes", "migration": "Brightside Realty", "email24": "Soggy Bottom Brewing",
    "netinstall": "Hoot and Holler",
}
const QUOTES := {
    "FRIEND": "WORKING WITH YOU IS THE BEST PART OF MY DAY.", "FRIENDLY": "SOLID TEAMMATE. I WOULD WORK WITH YOU AGAIN.",
    "NEUTRAL": "DOES THE JOB. HARD TO READ.", "COLD": "KEEPS TO THEMSELVES. A BIT ABRUPT.",
    "HOSTILE": "HONESTLY? HARD TO WORK WITH.",
}
# what the two owners (Alan, Garrison) write in the yearly review instead
const OWNER_QUOTES := {
    "FRIEND": "GLAD WE HIRED YOU. THE CLIENTS ASK FOR YOU BY NAME.", "FRIENDLY": "GOOD HIRE. I WOULD TRUST YOU WITH A CLIENT.",
    "NEUTRAL": "DOES THE JOB. NO COMPLAINTS ON MY DESK.", "COLD": "I SEE THE NUMBERS. I DO NOT SEE MUCH ELSE.",
    "HOSTILE": "WE NEED TO TALK ABOUT FIT. THE BOOKS DO NOT LIE.",
}
const EPILOGUES := {
    "lead": "YOU TAKE THE TEAM LEAD ROLE. MORE PAY, A PAGER AND THREE PEOPLE WHO NOW COME TO YOU WITH EVERYTHING. "
    + "THE NEXT YEAR WILL BE A DIFFERENT KIND OF HARD.",
    "internal": "YOU SWAP SIRENS FOR STEADY HOURS: ONE OFFICE, ONE NETWORK, NO ONE CALLING AT NIGHT. "
    + "YOU WILL MISS THE CHAOS A LITTLE.",
    "stay": "YOU STAY A TECH AT PIXEL IT PARTNERS. ALAN AND GARRISON KEEP THE BUSINESS RUNNING, YOU KEEP THE TICKETS MOVING. SAME DESK, A LOT MORE SKILL.",
}

var is_open := false
var page := 0
var sel := 0
var ending := ""
var offers: Array = []

var _canvas: Node2D
var _mouse := Vector2.ZERO
var _hits: Array = []
var _fade := 0.0


func _ready() -> void:
    layer = 72
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)


func start() -> void:
    page = 0
    sel = 0
    ending = ""
    offers = make_offers()
    is_open = true
    Game.ui_open = true
    _canvas.visible = true
    _mouse = get_viewport().get_mouse_position()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    create_tween().tween_method(_set_fade, _fade, 1.0, 0.3)
    _canvas.queue_redraw()


func _set_fade(value: float) -> void:
    _fade = value
    _canvas.modulate.a = value


func best_client() -> String:
    var best := "Acme Dental"
    var best_rank := 0
    for key in CLIENT_OF:
        var rank := int(GRADE_NAMES.get(str(Story.flags.get(key, "")), 0))
        if rank > best_rank:
            best_rank = rank
            best = str(CLIENT_OF[key])
    return best


func make_offers() -> Array:
    if Campaign.mode == "owner":
        return Owner.offers()
    var out := []
    if Campaign.rep >= (55 if Growth.graduated else 60) and Social.average() >= 0.0:
        out.append({
            "id": "lead", "label": "BECOME TEAM LEAD",
            "desc": "MORGAN AND THE OWNERS WANT YOU TO RUN THE SERVICE DESK: MORE PAY, MORE PEOPLE, MORE PAGER.",
        })
    if Campaign.rep >= 45:
        out.append({
            "id": "internal", "label": "JOIN %s AS IN-HOUSE IT" % best_client().to_upper(),
            "desc": "%s OFFERS YOU THEIR ONLY IT JOB: CALM HOURS, ONE NETWORK, NO NIGHTS." % best_client().to_upper(),
        })
    out.append({
        "id": "stay", "label": "STAY AN MSP TECH",
        "desc": "KEEP YOUR DESK, YOUR PHONES AND YOUR CHAOS." if Campaign.rep >= 45 else "ON NOTICE: PROVE YOURSELF NEXT YEAR.",
    })
    return out


func choose(index: int) -> void:
    ending = str(offers[clampi(index, 0, offers.size() - 1)].id)
    page = 3
    _canvas.queue_redraw()


func finish() -> void:
    if not is_open:
        return
    is_open = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _canvas.visible = false
    _fade = 0.0
    Career.add("endings")
    Campaign.finish_campaign(ending)


func advance() -> void:
    if page == 2:
        choose(sel)
    elif page == 3:
        finish()
    else:
        page += 1
    _canvas.queue_redraw()


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventMouseMotion:
        _mouse = get_viewport().get_mouse_position()
        _canvas.queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse = get_viewport().get_mouse_position()
        for i in range(_hits.size() - 1, -1, -1):
            if _hits[i].r.has_point(_mouse):
                if str(_hits[i].id) == "next":
                    advance()
                else:
                    sel = int(_hits[i].id)
                    choose(sel)
                break
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
            advance()
        elif event.keycode == KEY_UP and page == 2:
            sel = maxi(0, sel - 1)
            _canvas.queue_redraw()
        elif event.keycode == KEY_DOWN and page == 2:
            sel = mini(offers.size() - 1, sel + 1)
            _canvas.queue_redraw()
    else:
        return
    get_viewport().set_input_as_handled()


# ---- the pages ------------------------------------------------------------------------------
func _job_line(key: String, label: String) -> Array:
    var value := str(Story.flags.get(key, ""))
    if key == "install":
        return [label, {"ok": "PERFECT", "restored": "HAD A BACKUP", "lost": "DATA LOST"}.get(value, "-"), value == "lost"]
    if key == "ransom":
        return [label, {"saved": "SAVED BY BACKUP", "lost": "NO BACKUP!", "paid": "PAID THE RANSOM", "partial": "PARTIAL RECOVERY"}.get(str(Story.flags.get("ransom", "")), "-"), Story.flags.get("ransom", "") == "lost"]
    return [label, "GRADE " + value if value != "" else "-", value == "D"]


func page_lines() -> Array:
    if Campaign.mode == "owner":
        return Owner.review_lines(page, ending)
    var lines := []
    match page:
        0:
            lines.append(["MORGAN REYES - MANAGER", BLUE])
            lines.append(["TWENTY DAYS DONE. LET US LOOK AT THE YEAR.", INK])
            lines.append(["REPUTATION %d   CASH $%d" % [Campaign.rep, Campaign.cash], INK])
            lines.append(["CLOSED %d   SLA MISSED %d   REOPENED %d" % [Msp.closed_ok, Msp.breached, Msp.reopened], INK])
            var best_skill := "powershell"
            for key in Skills.NAMES:
                if Skills.level(key) > Skills.level(best_skill):
                    best_skill = key
            lines.append(["LEVELS: PS %d NET %d SRV %d SEC %d CUS %d (BEST %s)" % [Skills.level("powershell"), Skills.level("networking"), Skills.level("servers"), Skills.level("security"), Skills.level("people"), Skills.NAMES[best_skill]], INK])
            if Shift.enabled:
                lines.append(["HOURS: " + Shift.summary() + "   OUTINGS %d" % Outings.count, BAD if Shift.late_total >= 5 else INK])
            if Growth.status_line() != "":
                lines.append([Growth.status_line(), GOOD if Growth.graduated else INK])
            for job in JOBS:
                var row := _job_line(job[0], job[1])
                lines.append(["%s: %s" % [row[0], row[1]], BAD if row[2] else (GOOD if row[1] != "-" else INK)])
        1:
            lines.append(["WHAT THE OWNERS AND YOUR TEAM SAY", BLUE])
            for who in Social.PEOPLE:
                var quotes: Dictionary = OWNER_QUOTES if Social.is_owner(who) else QUOTES
                var tag := ", CO-OWNER" if Social.is_owner(who) else ""
                lines.append(["%s%s (%s):" % [who.to_upper(), tag, Social.mood(who)], BLUE])
                lines.append(["'%s'" % quotes[Social.mood(who)], INK])
        2:
            lines.append(["YOUR OPTIONS", BLUE])
        _:
            lines.append(["THE END", BLUE])
            lines.append([str(EPILOGUES.get(ending, "")), INK])
    return lines


func _wrap(s: String, chars: int) -> Array:
    var out := []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            out.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    out.append(line)
    return out


func _paint() -> void:
    var size := get_viewport().get_visible_rect().size
    _hits.clear()
    var sc := 1
    var u := float(sc)
    _canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.88))
    var pw := minf(size.x - 8.0, 250.0 * u)
    var chars := int((pw - 10.0 * u) / (4.0 * u))
    var rows := []
    for entry in page_lines():
        for wrapped in _wrap(str(entry[0]), chars):
            rows.append([wrapped, entry[1]])
    var extra := 0.0
    if page == 2:
        extra = float(offers.size()) * 11.0 * u + 3.0 * u + 24.0 * u
    var ph := (12.0 + float(rows.size()) * 7.0 + 18.0) * u + extra
    ph = minf(ph, size.y - 4.0)
    var panel := Rect2(floorf((size.x - pw) * 0.5), floorf((size.y - ph) * 0.5), pw, ph)
    _canvas.draw_rect(panel, Color("e9ecf1"))
    _canvas.draw_rect(Rect2(panel.position, Vector2(pw, 9.0 * u)), BLUE)
    var heading := "BOARD REVIEW" if Campaign.mode == "owner" else "YEARLY REVIEW"
    PixelFont.draw(_canvas, heading, panel.position + Vector2(3.0 * u, 2.0 * u), WHITE, sc)
    var y := panel.position.y + 12.0 * u
    for row in rows:
        PixelFont.draw(_canvas, str(row[0]), Vector2(panel.position.x + 5.0 * u, y), row[1], sc)
        y += 7.0 * u
    if page == 2:
        y += 3.0 * u
        for i in offers.size():
            var r := Rect2(panel.position.x + 4.0 * u, y, pw - 8.0 * u, 10.0 * u)
            var chosen := i == sel
            _canvas.draw_rect(r, Color("f5d442") if chosen else Color("c9d2e0"))
            PixelFont.draw(_canvas, str(offers[i].label), r.position + Vector2(3.0 * u, 2.0 * u), INK, sc)
            _hits.append({"r": r, "id": str(i)})
            y += 11.0 * u
        y += 2.0 * u
        for wrapped in _wrap(str(offers[sel].desc), chars):
            PixelFont.draw(_canvas, wrapped, Vector2(panel.position.x + 5.0 * u, y), Color("46506a"), sc)
            y += 7.0 * u
    else:
        var label := "FINISH" if page == 3 else "NEXT"
        var bw := float(PixelFont.width(label, sc)) + 12.0 * u
        var b := Rect2(panel.end.x - bw - 4.0 * u, panel.end.y - 12.0 * u, bw, 9.0 * u)
        _canvas.draw_rect(b, Color("5aa0e8") if b.has_point(_mouse) else Color("3a7bd5"))
        PixelFont.draw(_canvas, label, b.position + Vector2(6.0 * u, 2.0 * u), WHITE, sc)
        _hits.append({"r": b, "id": "next"})
    var m := _mouse.floor()
    for i in 6:
        _canvas.draw_rect(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
''')

write("scripts/cards.gd", '''extends CanvasLayer
# Decision cards: a modal dialog with a speaker, some text and 2-4 options. Used when the
# account manager walks in with a client complaint, and for the owner campaign's business
# decisions. Up/Down + Enter, number keys 1-4, or click.
#   Cards.ask("Vic", "text...", [{"label": "I WILL PRIORITIZE IT", "id": "a"}, ...], on_pick)
# Options can be {"label", "id", "enabled": false, "hint": "why"} to show them greyed out.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")

var is_open := false
var speaker := ""
var text := ""
var options: Array = []
var sel := 0

var _canvas: Node2D
var _callback := Callable()
var _hits: Array = []
var _mouse := Vector2.ZERO
var _queue: Array = []
var _opened := 0  # msec the card appeared: early confirms are ignored


func _ready() -> void:
    layer = 65
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)


func ask(who: String, body: String, choices: Array, on_pick: Callable) -> void:
    if is_open or DayReport.is_open:
        _queue.append([who, body, choices, on_pick])
        return
    speaker = who
    text = body
    options = choices
    var any_enabled := false
    for opt in choices:
        any_enabled = any_enabled or bool(opt.get("enabled", true))
    if not any_enabled:
        # nothing affordable: a card must never trap the player (or hold the week report back)
        options = choices.duplicate()
        options.append({"label": "NOT NOW", "id": "__none"})
    sel = 0
    for i in options.size():
        if bool(options[i].get("enabled", true)):
            sel = i
            break
    _callback = on_pick
    is_open = true
    _opened = Time.get_ticks_msec()
    Game.ui_open = true
    _canvas.visible = true
    _mouse = get_viewport().get_mouse_position()
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    _canvas.queue_redraw()


func pick(index: int) -> void:
    if not is_open or index < 0 or index >= options.size() or not bool(options[index].get("enabled", true)):
        return
    var id := str(options[index].id)
    is_open = false
    _canvas.visible = false
    Game.ui_open = Computer.is_open or Phone.is_open or PrinterGame.is_open or Outings.is_open
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if Game.ui_open else Input.MOUSE_MODE_VISIBLE
    if id != "__none" and _callback.is_valid():
        _callback.call(id)
    if not _queue.is_empty():
        var next: Array = _queue.pop_front()
        ask(next[0], next[1], next[2], next[3])


# cards that were asked while the day report covered the screen
func flush() -> void:
    if not is_open and not DayReport.is_open and not _queue.is_empty():
        var next: Array = _queue.pop_front()
        ask(next[0], next[1], next[2], next[3])


# Esc picks the option whose id is "leave" (conversations)
func _pick_leave() -> void:
    for i in options.size():
        if str(options[i].id) in ["leave", "__none"]:
            pick(i)
            return


func _move(step: int) -> void:
    for _n in options.size():
        sel = (sel + step + options.size()) % options.size()
        if bool(options[sel].get("enabled", true)):
            break
    _canvas.queue_redraw()


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    if event is InputEventMouseMotion:
        _mouse = get_viewport().get_mouse_position()
        for h in _hits:
            if h.r.has_point(_mouse):
                sel = int(h.i)
        _canvas.queue_redraw()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse = get_viewport().get_mouse_position()
        for h in _hits:
            if h.r.has_point(_mouse) and Time.get_ticks_msec() - _opened >= 450:
                pick(int(h.i))
                break
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_UP:
            _move(-1)
        elif event.keycode == KEY_DOWN:
            _move(1)
        elif event.keycode == KEY_ESCAPE:
            _pick_leave()
        elif Time.get_ticks_msec() - _opened < 450:
            pass  # too soon: the card just appeared
        elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
            pick(sel)
        elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
            pick(event.keycode - KEY_1)
    else:
        return
    get_viewport().set_input_as_handled()


func _wrap(s: String, chars: int) -> Array:
    var out := []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            out.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    out.append(line)
    return out


func _paint() -> void:
    var size := get_viewport().get_visible_rect().size
    _hits.clear()
    _canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.45))
    var pw := minf(size.x - 8.0, 250.0)
    var chars := int((pw - 10.0) / 4.0)
    var lines := _wrap(text, chars)
    var ph := 12.0 + float(lines.size()) * 7.0 + 4.0 + float(options.size()) * 11.0 + 4.0
    # short screens (16:9, wide) keep the people visible by putting the card at the top
    var panel_y := 6.0 if size.y < 200.0 else size.y - ph - 6.0
    var panel := Rect2(floorf((size.x - pw) * 0.5), floorf(panel_y), pw, ph)
    _canvas.draw_rect(panel, Color("e9ecf1"))
    _canvas.draw_rect(Rect2(panel.position, Vector2(pw, 9)), Color("8e3a2b"))
    PixelFont.draw(_canvas, speaker.to_upper(), panel.position + Vector2(3, 2), WHITE)
    var y := panel.position.y + 12.0
    for line in lines:
        PixelFont.draw(_canvas, line, Vector2(panel.position.x + 5, y), INK)
        y += 7.0
    y += 4.0
    for i in options.size():
        var opt: Dictionary = options[i]
        var on: bool = bool(opt.get("enabled", true))
        var r := Rect2(panel.position.x + 4, y, pw - 8, 10)
        var col := Color("f5d442") if i == sel and on else (Color("c9d2e0") if on else Color("dcdfe6"))
        _canvas.draw_rect(r, col)
        var label := "%d. %s" % [i + 1, str(opt.label)]
        if not on and opt.has("hint"):
            label += " [%s]" % str(opt.hint)
        PixelFont.draw(_canvas, label.substr(0, chars - 1), r.position + Vector2(3, 2), INK if on else Color("8b93a1"))
        _hits.append({"r": r, "i": i})
        y += 11.0
    var m := _mouse.floor()
    for i in 6:
        _canvas.draw_rect(Rect2(m.x, m.y + i, 1 + mini(i, 3), 1), INK)
''')

write("scripts/sales.gd", '''extends Node
# The sales side: the account manager (Vic) brings in the work. Clients each have a
# satisfaction (0-100) that moves with how their tickets go; the number of ACTIVE clients sets
# how many tickets come in (Msp.pace), and Vic's visits can sign new clients or sell desktop
# installs. When a client is unhappy and has an open ticket that is late, they complain to Vic,
# who walks in and tells you (a Cards decision). Everything here only runs inside a campaign.

signal changed
signal client_signed(client: int)

const START_CLIENTS := [0, 1, 2, 3, 4]
const MAX_CLIENTS := 8
const INSTALL_JOB := 150  # owner campaign: what a sold desktop install pays the company
const COMPLAINT_GAP := 75.0  # game seconds between complaints
const CLIENT_COMPLAINT_WEEKS := 2  # owner campaign: the same client complains to Vic at most every other week
const SIGN_TEXT := "Just signed %s! Their IT is a mess. Welcome them gently."

var active: Array = START_CLIENTS.duplicate()
var satisfaction := {}  # client -> 0..100
var deals := 0
var last_deal := 'VIC CLOSED A DEAL!'  # what the sales bell says
var installs_sold := 0
var pending: Dictionary = {}  # a complaint waiting for Vic to deliver it
var signed_day := {}  # client -> campaign day Vic signed them: no tickets until the next day
var complained_day := {}  # client -> campaign day of their last complaint (the owner's weeks spread them out)

var _cool := 40.0


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


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
    var roll := randf() * total
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
    return float(active.size()) / 5.0


# ---- Vic's skill ----------------------------------------------------------------------------
func vic_skill() -> float:
    var skill := 0.45 + float(Campaign.rep) / 250.0 + Owner.vic_extra()
    if Social.is_friendly("Vic"):
        skill += 0.1
    if Social.is_cold("Vic"):
        skill -= 0.15
    return clampf(skill, 0.15, 0.95)


# Vic is back from a client visit: maybe he closed something
func visit_done() -> bool:
    if not Campaign.active or not Msp.enabled:
        return false
    if randf() > vic_skill():
        Msp.send_text("Vic", "Client meeting went nowhere. Next time.")
        return false
    var dealt := -1
    if active.size() < MAX_CLIENTS and (randf() < 0.55 or Msp.project_busy()):
        dealt = sign_client()
        if dealt >= 0:
            last_deal = "VIC CLOSED " + str(Msp.CLIENTS[dealt].name).to_upper() + "!"
    else:
        dealt = sell_install()
        if dealt >= 0:
            last_deal = "VIC SOLD A DESKTOP INSTALL!"
    return dealt >= 0


func sign_client(wanted := -1) -> int:
    var pool := []
    for c in Msp.CLIENTS.size():
        if not active.has(c):
            pool.append(c)
    if pool.is_empty():
        return -1
    var client: int = pool[randi() % pool.size()]
    if wanted >= 0 and pool.has(wanted):
        client = wanted
    active.append(client)
    signed_day[client] = Campaign.day
    satisfaction[client] = Owner.new_client_mood() if Owner.active() else 75
    deals += 1
    Owner.on_deal("client", client)
    Msp.send_text("Vic", SIGN_TEXT % Msp.CLIENTS[client].name)
    Msp.mail(
        "Vic Marlowe - Sales", "New client: " + str(Msp.CLIENTS[client].name),
        "Signed %s today. Contact is %s. Expect their tickets from tomorrow. - Vic" % [Msp.CLIENTS[client].name, Msp.CLIENTS[client].contact]
    )
    client_signed.emit(client)
    changed.emit()
    return client


func sell_install() -> int:
    if Owner.active():
        # the owner campaign has no desk project for the team to work: the sale is a one-off job
        # (the crew does the setup between tickets), so it can never block the next sale
        var who := pick_client()
        installs_sold += 1
        Owner.on_deal("install", who)
        Owner.cash += INSTALL_JOB
        Owner.income_extra += INSTALL_JOB
        Msp.send_text(
            "Vic", "Sold %s a new desktop. The crew sets it up between tickets." % Msp.CLIENTS[who].name
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
    Msp.send_text("Vic", "Sold %s a new desktop. It is in your queue." % Msp.CLIENTS[client].name)
    changed.emit()
    return int(t.id)


# ---- complaints -----------------------------------------------------------------------------
# the client with a late open ticket and low satisfaction complains to Vic
func complaint_cooling(client: int) -> bool:
    return (
        Owner.active()
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
        var urgency: float = (-1000.0 if t.breached else float(t.sla_left)) + float(mood(int(t.client)))
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
    World.send_vic_to_player()


func complaint_text() -> String:
    var t := Msp.ticket(int(pending.get("ticket", 0)))
    if t.is_empty() or str(t.status) == "Closed":
        return ""
    var contact: String = Msp.CLIENTS[int(t.client)].contact
    var late := "is past its SLA" if t.breached else "has %s left" % Msp.mmss(float(t.sla_left))
    return "%s from %s called me directly. Ticket #%d (%s) %s and they are not happy." % [contact, Msp.CLIENTS[int(t.client)].name, int(t.id), t.summary, late]


# Vic reached you with the news: ask what you want to do
func deliver() -> void:
    if pending.is_empty():
        return
    var text := complaint_text()
    if text == "":
        pending = {}
        return
    Career.add("vic_calls")
    var vic_friend := Social.is_friendly("Vic")
    var options := [
        {"label": "I WILL PRIORITIZE IT", "id": "prio"},
        {"label": "TELL THEM IT IS IN THE QUEUE", "id": "queue"},
        {"label": "CAN YOU CALM THEM DOWN?", "id": "calm"},
    ]
    if vic_friend:
        options[2]["label"] = "CAN YOU CALM THEM DOWN? (VIC OWES YOU)"
    Cards.ask("Vic Marlowe", text, options, resolve)


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
            Social.change("Vic", 1)
            Skills.add_xp("people", 3)
        "queue":
            adjust(client, -6)
            Social.change("Vic", -2)
        _:
            t.sla_left = float(t.sla_left) + 60.0
            t.notes.append("Account manager managed the client.")
            adjust(client, 2)
            Social.change("Vic", 0 if Social.is_friendly("Vic") else -1)
    Msp.changed.emit()


func to_dict() -> Dictionary:
    return {"active": active.duplicate(), "sat": satisfaction.duplicate(), "deals": deals, "installs": installs_sold}


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
''')

write("scripts/owner.gd", '''extends Node
# gdlint:disable=max-line-length
# The owner campaign: you run Pixel IT Partners. Each campaign "day" is a week of the business. Your techs (Alan,
# Garrison, Dan, plus anyone you hire) work the ticket queue on their own at a speed set by the team; you make the
# business decisions as Cards (pricing, backups, hiring, quotes, vendors, crises) and watch cash, clients and
# reputation. Each week ends with a P&L report; week 20 is the board review (sell, expand or stay independent).
# Clients' moods (Sales) still drive churn, Vic still signs clients and brings complaints, and the same story beats
# (backups, ransomware, the rack, the migration, the 24x7 email outage...) happen to you as decisions.

const START_CASH := 7500
const FEE := 800  # weekly fee per client at standard pricing
const WAGE := 650  # a tech's weekly wage
const W2_TARGET := 0.55  # payroll as a share of revenue: healthy MSPs stay under this
const PEER_MARGIN := 0.15  # the peer group's typical EBITDA margin
const RENT := 500
const SEAT_COST := 55  # weekly cost of each client past five (licences, desks, insurance, a bigger line)
const ADVICE_GAP := 3  # weeks before Dana opens the same advice card again
const HIRE_RAMP_WEEKS := 3  # a new hire costs 60% of the wage for the first weeks
const TOOLS := 0  # tool costs now come from the stack
const DEFAULT_STACK := {"psa": "connectwhy", "rmm": "labrat", "hardware": "hewlitt"}
# What you run and sell. cost = weekly, speed = tech speed, morale = % effect on the crew, issues = ticket volume
# multiplier (bad hardware = more tickets), sales = Vic's close rate, margin = hardware resale profit per deal.
const STACK := {
    "psa": {"label": "PSA", "options": {
        "connectwhy": {"name": "ConnectWhy PSA", "cost": 60, "speed": 0.0, "morale": 0, "note": "THE STANDARD"},
        "ticketo": {"name": "Ticketo Lite", "cost": 15, "speed": -0.15, "morale": -8, "note": "CHEAP, THE CREW HATES IT"},
        "opsforge": {"name": "OpsForge Pro", "cost": 140, "speed": 0.1, "morale": 4, "note": "AUTOMATION THEY LOVE"},
    }},
    "rmm": {"label": "RMM", "options": {
        "labrat": {"name": "LabRat RMM", "cost": 80, "speed": 0.0, "morale": 0, "issues": 1.0, "risk": 1.0, "patching": 1.0, "note": "THE STANDARD"},
        "snoutech": {"name": "SnoutTech Basic", "cost": 25, "speed": -0.1, "morale": -4, "issues": 1.1, "risk": 1.5, "patching": 0.0, "note": "CHEAP, MISSES THINGS"},
        "labrat_gold": {"name": "LabRat Gold", "cost": 180, "speed": 0.15, "morale": 2, "issues": 0.9, "risk": 0.8, "patching": 3.0, "note": "CATCHES PROBLEMS EARLY"},
    }},
    "hardware": {"label": "HARDWARE", "options": {
        "hewlitt": {"name": "Hewlitt Packerd", "cost": 0, "issues": 1.0, "sales": 0.0, "margin": 200, "note": "THE STANDARD"},
        "dellight": {"name": "DellightCo Premium", "cost": 0, "issues": 0.85, "sales": -0.05, "margin": 350, "note": "SOLID, HARDER TO SELL"},
        "budgetbyte": {"name": "BudgetByte Value", "cost": 0, "issues": 1.35, "sales": 0.12, "margin": 120, "morale": -3, "note": "EASY SELL, FAILS OFTEN"},
    }},
}
const NAMES := ["Priya", "Marcus", "Jules", "Tomas", "Wendy", "Dev", "Rosa", "Kofi", "Ingrid", "Sal", "Mei", "Otis"]
const TRAITS := {
    "wizard": {"label": "POWERSHELL WIZARD", "wage": 30},
    "people": {"label": "GREAT WITH CLIENTS", "mood": 1},
    "green": {"label": "GREEN BUT EAGER", "grow": 0.04, "wage": -40},
    "flight": {"label": "FLIGHT RISK", "quit": 0.06, "wage": -30},
    "steady": {"label": "STEADY AND RELIABLE"},
}
const SLOW_PAYERS := {2: 2, 6: 3, 7: 3}  # client -> weeks they pay late
const VIC_PLANS := {
    "salary": {"label": "SALARY ONLY", "wage": 750, "per_deal": 0, "skill": 0.0, "start_mood": 75},
    "balanced": {"label": "BALANCED", "wage": 550, "per_deal": 150, "skill": 0.05, "start_mood": 68},
    "commission": {"label": "COMMISSION-HEAVY", "wage": 350, "per_deal": 300, "skill": 0.12, "start_mood": 58},
}
const BANKRUPT := -3000
const COMPETITOR := "ByteBrothers"  # the rival MSP that circles your clients
const HEAVY := {2: 2.0, 7: 2.0}  # clients whose requests creep: they generate twice the tickets until you enforce the scope
const COST_PER_SEC := 2.9  # what a tech-second of work costs you (wages / capacity)
const OML_NAMES := ["BEGINNING", "EMERGING", "SCALING", "OPTIMIZING", "INNOVATING"]
const GOALS := {
    "w2": "W-2 RATIO UNDER 60%",
    "mood": "AVERAGE CLIENT MOOD 70% OR BETTER",
    "ar": "RECEIVABLES UNDER $1,500",
}
const WORK := {1: 180.0, 2: 140.0, 3: 100.0, 4: 72.0}  # tech-seconds a ticket needs, by priority
const JUNIOR := {"name": "Sam", "skill": 0.7, "wage": 450}
const OPTIONS_OK := [{"label": "OK", "id": "ok"}]

# Card options: {label, need (cash), fx} or {label, need, roll: [[chance, fx, result text], ...]} plus optional text.
# fx keys: cash, rep, mood_all, mood {client: n}, flag, price, speed, weekly, vic, hire, lose_tech, sign, drop,
#          discount {mult, weeks}, ransom, quote {cash, cost, rep}
const CARDS := {
    "welcome": {
        "speaker": "Marge (Bookkeeper)",
        "text": "Welcome, boss. Five clients, three techs, Vic in sales and $5,000 in the bank. Payroll and rent come out every week. How do you want to price our service?",
        "options": [
            {"label": "VOLUME PRICING (-15% FEES, VIC SELLS MORE)", "fx": {"price": -0.15, "vic": 0.15}},
            {"label": "STANDARD PRICING", "fx": {}},
            {"label": "PREMIUM PRICING (+20% FEES, HARDER SELL)", "fx": {"price": 0.2, "vic": -0.1}},
        ],
    },
    "backup": {
        "speaker": "Alan (Co-owner)",
        "text": "Boss, backup jobs fail silently and we only find out when someone needs them. A managed backup service checks them every night: $600 to set up and $100 a week.",
        "options": [
            {"label": "BUY THE BACKUP SERVICE ($600 + $100/WEEK)", "need": 600, "fx": {"cash": -600, "weekly": 100, "flag": "backup_service"}},
            {"label": "NO, WE WILL CHECK THEM BY HAND", "fx": {"flag": "no_backup_service"}},
        ],
    },
    "queue": {
        "speaker": "Vic Marlowe",
        "text": "The queue is getting long and clients are noticing. We either need more hands or faster hands.",
        "options": [
            {"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}},
            {"label": "POWERSHELL TRAINING FOR THE CREW ($400)", "need": 400, "fx": {"cash": -400, "speed": 0.25}},
            {"label": "NEITHER, WE WILL COPE", "fx": {}},
        ],
    },
    "desktop": {
        "speaker": "Vic Marlowe",
        "text": "Dr. Patel wants a new desktop set up and migrated. What do I quote? Cheap closes easily, premium might scare him off. The job costs us about $400 of tech time.",
        "options": [
            {"label": "$600 (ALMOST SURE)", "roll": [[0.95, {"quote": {"cash": 600, "cost": 400, "rep": 1}}, "He accepts. The install goes smoothly."], [0.05, {}, "He shops around instead."]]},
            {"label": "$1,000 (PROBABLY)", "roll": [[0.75, {"quote": {"cash": 1000, "cost": 400, "rep": 1}}, "Accepted. A tidy profit."], [0.25, {}, "He says it is too much."]]},
            {"label": "$1,600 (A LONG SHOT)", "roll": [[0.4, {"quote": {"cash": 1600, "cost": 400, "rep": 2}}, "He accepts the premium quote!"], [0.6, {"mood": {"0": -4}}, "He is insulted and says so."]]},
        ],
    },
    "prospect": {
        "speaker": "Vic Marlowe",
        "text": "New prospect %s wants us but asks for 20%% off for the first 6 weeks to sign. They are a good-sized account.",
        "options": [
            {"label": "OFFER THE DISCOUNT", "fx": {"sign": true, "discount_new": {"mult": 0.8, "weeks": 6}}, "text": "Signed! Vic is thrilled. Their tickets start tomorrow."},
            {"label": "HOLD THE PRICE", "roll": [[0.5, {"sign": true}, "They sign at full price. Vic looks smug."], [0.5, {}, "They pass. Vic sulks."]]},
            {"label": "PASS", "fx": {}},
        ],
    },
    "license": {
        "speaker": "Alan (Co-owner)",
        "text": "Our remote support software renews with a 30% hike. We can pay it, or switch to a cheaper tool and migrate everyone.",
        "options": [
            {"label": "PAY THE HIKE ($500)", "need": 500, "fx": {"cash": -500}},
            {"label": "SWITCH ($300, SOME PAIN)", "need": 300, "roll": [[0.7, {"cash": -300, "weekly": -30}, "The switch goes smoothly and weekly costs drop."], [0.3, {"cash": -300, "rep": -3, "mood_all": -3}, "The migration drags and clients notice."]]},
        ],
    },
    "rack": {
        "speaker": "Vic Marlowe",
        "text": "Gnarly Gnomes' network rack fell off their plywood wall. Everything there is down and Bob is shouting. Who do we send?",
        "options": [
            {"label": "SEND ALAN NOW ($300)", "need": 300, "roll": [[0.85, {"cash": -300, "mood": {"2": 10}, "rep": 2}, "Alan rebuilds it properly. Bob buys him lunch."], [0.15, {"cash": -300, "mood": {"2": 2}}, "Fixed, but it took all night."]]},
            {"label": "SEND THE JUNIOR OR DAN ($100)", "need": 100, "roll": [[0.5, {"cash": -100, "mood": {"2": 5}}, "Back up by evening."], [0.5, {"cash": -100, "mood": {"2": -12}, "rep": -2}, "Cables were plugged into the wrong ports. Bob is furious."]]},
            {"label": "TELL THEM IT IS THEIR WALL", "roll": [[0.7, {"mood": {"2": -20}}, "They fix it themselves. They are not happy."], [0.3, {"mood": {"2": -20}, "drop": true}, "Gnarly Gnomes cancels the contract."]]},
        ],
    },
    "migration": {
        "speaker": "Vic Marlowe",
        "text": "Brightside Realty wants their old server replaced. Do we quote a fixed price or bill time and materials?",
        "options": [
            {"label": "FIXED PRICE $3,000", "roll": [[0.6, {"cash": 3000, "rep": 1}, "Smooth job, nice margin."], [0.4, {"cash": 1800, "mood": {"1": -3}}, "The job overran. You ate $1,200."]],
             "roll_scoped": [[0.9, {"cash": 3000, "rep": 2}, "The scoping day paid off: a smooth job."], [0.1, {"cash": 2400}, "A small overrun, nothing serious."]]},
            {"label": "TIME AND MATERIALS (~$2,200)", "fx": {"cash": 2200}, "text": "Brightside grumbles about the open-ended bill but pays."},
        ],
    },
    "email24": {
        "speaker": "Alan (Co-owner)",
        "text": "Soggy Bottom's email just died. They run 24x7 and their fermentation alerts come by email. The vendor offers premium support. Alan will stay late if you approve overtime.",
        "options": [
            {"label": "PREMIUM VENDOR + OVERTIME ($800)", "need": 800, "roll": [[0.9, {"cash": -800, "mood": {"4": 12}, "rep": 3}, "Fixed by 9pm. The brewery owner sends beer."], [0.1, {"cash": -800, "mood": {"4": 4}}, "Fixed, but after midnight."]]},
            {"label": "STANDARD VENDOR SUPPORT", "roll": [[0.4, {"mood": {"4": 3}}, "Fixed overnight, barely."], [0.6, {"mood": {"4": -20}, "rep": -3}, "Down until morning. A batch is lost. Lucy is livid."]]},
            {"label": "GO IN YOURSELF", "roll": [[0.6, {"rep": 1, "mood": {"4": 6}}, "You muddle through and fix it. Alan is impressed."], [0.4, {"mood": {"4": -8}}, "You make it worse before you make it better."]]},
        ],
    },
    "raise": {
        "speaker": "Alan (Co-owner)",
        "text": "Boss, I have taken on the hardest jobs all year. I would like a $100 a week raise.",
        "options": [
            {"label": "GIVE THE RAISE", "fx": {"weekly": 100, "speed": 0.1}},
            {"label": "NOT NOW", "roll": [[0.7, {}, "Alan shrugs and keeps working."], [0.3, {"lose_tech": true, "rep": -2}, "Alan hands in his notice. The team is stretched thin."]]},
        ],
    },
    "bid": {
        "speaker": "Vic Marlowe",
        "text": "Hoot and Holler is opening a branch and wants a network install. This is a big job.",
        "options": [
            {"label": "BID LOW $2,500", "roll": [[0.9, {"cash": 2500, "cost": 0, "rep": 1}, "They accept. The crew grumbles about the margin."], [0.1, {}, "They go with someone else."]]},
            {"label": "BID HIGH $4,500", "roll": [[0.45, {"cash": 4500, "rep": 2}, "They accept the premium bid."], [0.55, {}, "They balk and walk."]]},
        ],
    },
    "poach": {
        "speaker": "Vic Marlowe",
        "text": "ByteBrothers is calling our clients with a cheaper quote and a free 'IT assessment'. Word is they already talked to a couple of ours.",
        "options": [
            {"label": "LOYALTY DISCOUNT: -10% FOR 4 WEEKS", "fx": {"discount": {"mult": 0.9, "weeks": 4}, "mood_all": 8}},
            {"label": "HEALTH CHECK AT EVERY CLIENT ($300)", "need": 300, "fx": {"cash": -300, "health_check": true}, "text": "Backups verified and updates pushed everywhere. There is less for them to find."},
            {"label": "IGNORE THEM", "roll": [[0.6, {}, "Nobody leaves."], [0.4, {"drop": true}, "A client switches to ByteBrothers."]]},
        ],
    },
    "peer_invite": {
        "speaker": "Marge (Bookkeeper)",
        "text": "You were invited to the MSP Mastermind: a dozen non-competing MSP owners who meet regularly, compare their numbers (EBITDA, W-2 ratio) and warn each other about what is coming. Dues are $500 to join and $75 a week.",
        "options": [
            {"label": "JOIN THE PEER GROUP ($500 + $75/WEEK)", "need": 500, "fx": {"cash": -500, "weekly": 75, "flag": "peer_group", "vic": 0.05}, "text": "You are in. The first meeting is in a few days."},
            {"label": "NOT NOW", "fx": {}},
        ],
    },
    "mentor_offer": {
        "speaker": "Dana Whitfield (Consultant)",
        "text": "I ran an MSP for fifteen years and sold it. For $400 a week I will review your numbers, tell you what I would do, and nudge your big decisions in the right direction. You can dismiss me any time.",
        "options": [
            {"label": "HIRE DANA ($400/WEEK)", "fx": {"weekly": 400, "flag": "mentor"}, "text": "Dana opens her notebook. Expect advice on Monday mornings."},
            {"label": "NO THANKS", "fx": {}},
        ],
    },
    "peer1": {
        "speaker": "MSP Mastermind",
        "text": "Tonight's topic: backups. Two members lost clients to silent backup failures. The group has a deal on a managed backup service, and a few members say you could charge 10% more.",
        "options": [
            {"label": "BACKUP SERVICE VIA THE GROUP ($400)", "need": 400, "unless": "backup_service", "fx": {"cash": -400, "weekly": 100, "flag": "backup_service"}},
            {"label": "RAISE PRICES 10% (MOOD -2)", "fx": {"price": 0.1, "mood_all": -2}},
            {"label": "JUST NETWORK", "fx": {}},
        ],
    },
    "peer2": {
        "speaker": "MSP Mastermind",
        "text": "A member got hit by ransomware last month because their backups had quietly died and nobody had checked in weeks. The group's advice: have your team check every client's backup today.",
        "options": [
            {"label": "HAVE THE TEAM CHECK EVERY BACKUP", "fx": {"check_backups": true}, "text": "Alan checks them all. Any failing job is rerun."},
            {"label": "WE ARE FINE", "fx": {}},
        ],
    },
    "peer3": {
        "speaker": "MSP Mastermind",
        "text": "A peer says fixed-price projects are where owners lose money: spend a day scoping the job before you quote anything.",
        "options": [
            {"label": "SCOPE PROJECTS FIRST ($300)", "need": 300, "fx": {"cash": -300, "flag": "scoped"}, "text": "Your next fixed-price quote will be much safer."},
            {"label": "SKIP IT", "fx": {}},
        ],
    },
    "peer4": {
        "speaker": "MSP Mastermind",
        "text": "Year-end benchmarks: members average a 15% EBITDA margin and keep payroll under 55% of revenue. Most raised prices at least 8% this year.",
        "options": [
            {"label": "RAISE PRICES 8% (MOOD -3)", "fx": {"price": 0.08, "mood_all": -3}},
            {"label": "HOLD PRICES", "fx": {}},
        ],
    },
    "marketing": {
        "speaker": "Vic Marlowe",
        "text": "Vic wants a marketing budget: a website refresh, local events, email campaigns. It raises his close rate and brings in inbound leads. How much per week? (It counts against EBITDA.)",
        "options": [
            {"label": "NO MARKETING ($0)", "fx": {"marketing": 0}},
            {"label": "LIGHT ($150/WEEK)", "fx": {"marketing": 150}},
            {"label": "STANDARD ($400/WEEK)", "fx": {"marketing": 400}},
            {"label": "AGGRESSIVE ($900/WEEK)", "fx": {"marketing": 900}},
        ],
    },
    "stack_psa": {
        "speaker": "Alan (Co-owner)",
        "text": "Our PSA contract is up for renewal. ConnectWhy is the standard ($60/week). Ticketo Lite is much cheaper ($15) but the crew finds it clunky. OpsForge Pro ($140) is what the big shops run.",
        "options": [
            {"label": "KEEP CONNECTWHY PSA", "fx": {}},
            {"label": "TICKETO LITE ($15/WK, $300 TO MIGRATE)", "need": 300, "fx": {"cash": -300, "stack": {"psa": "ticketo"}}, "text": "Migrated. The crew is not thrilled."},
            {"label": "OPSFORGE PRO ($140/WK, $300 TO MIGRATE)", "need": 300, "fx": {"cash": -300, "stack": {"psa": "opsforge"}}, "text": "The techs love the automation."},
        ],
    },
    "stack_rmm": {
        "speaker": "Alan (Co-owner)",
        "text": "The RMM renewal is here. LabRat is the standard ($80/week). SnoutTech Basic is cheap ($25) but it misses things. LabRat Gold ($180) catches problems before clients call.",
        "options": [
            {"label": "KEEP LABRAT RMM", "fx": {}},
            {"label": "SNOUTECH BASIC ($25/WK, $300 TO MIGRATE)", "need": 300, "fx": {"cash": -300, "stack": {"rmm": "snoutech"}}, "text": "Migrated. More surprises ahead."},
            {"label": "LABRAT GOLD ($180/WK, $200 TO UPGRADE)", "need": 200, "fx": {"cash": -200, "stack": {"rmm": "labrat_gold"}}, "text": "Upgraded. Alerts start catching things early."},
        ],
    },
    "stack_hw": {
        "speaker": "Vic Marlowe",
        "text": "Which hardware vendor do we recommend and resell? Hewlitt Packerd is the standard ($200 margin a deal). BudgetByte is cheap, so I sell more, but their machines fail more. DellightCo is premium and rock solid, but harder to sell.",
        "options": [
            {"label": "HEWLITT PACKERD (THE STANDARD)", "fx": {"stack": {"hardware": "hewlitt"}}},
            {"label": "BUDGETBYTE (+12% SALES, MORE TICKETS)", "fx": {"stack": {"hardware": "budgetbyte"}}, "text": "Vic grins. Expect more calls about broken laptops."},
            {"label": "DELLIGHTCO (SOLID, $350 MARGIN)", "fx": {"stack": {"hardware": "dellight"}}, "text": "Fewer fires, fatter margins, a slower sell."},
        ],
    },
    "vic_plan": {
        "speaker": "Marge (Bookkeeper)",
        "text": "How do we pay Vic? Salesmen respond to incentives, but commission-driven reps over-promise and new clients start out unhappy. Salary is steady but he sells less hard.",
        "options": [
            {"label": "SALARY ONLY ($750/WK)", "fx": {"vic_plan": "salary"}},
            {"label": "BALANCED ($550/WK + $150 A DEAL)", "fx": {"vic_plan": "balanced"}},
            {"label": "COMMISSION-HEAVY ($350/WK + $300 A DEAL)", "fx": {"vic_plan": "commission"}},
        ],
    },
    "billing_audit": {
        "speaker": "Marge (Bookkeeper)",
        "text": "I have a hunch we are not billing for everything: extra hours, license price rises we never passed on. A one-time billing audit ($400) would check every invoice against what we pay vendors and the hours we really work.",
        "options": [
            {"label": "DO THE BILLING AUDIT ($400)", "need": 400, "fx": {"cash": -400, "fix_leak": true}, "text": "The audit finds unbilled work and vendor increases nobody passed through. Fixed from now on."},
            {"label": "SKIP IT", "fx": {}},
        ],
    },
    "after_hours": {
        "speaker": "Alan (Co-owner)",
        "text": "After-hours calls are burning the crew out: pages at 2 a.m. for things that could wait. Other owners charge an after-hours fee and most non-critical calls simply stop. Or we can pay an on-call stipend.",
        "options": [
            {"label": "ADOPT A $250/HOUR AFTER-HOURS FEE", "fx": {"flag": "after_hours_fee", "mood_all": -3}, "text": "Most non-critical after-hours calls stop. A few clients grumble."},
            {"label": "PAY AN ON-CALL STIPEND ($150/WEEK)", "fx": {"weekly": 150, "flag": "oncall_stipend"}, "text": "The crew feels valued. Calls keep coming, but the pain is shared."},
            {"label": "NEITHER, WE WILL COPE", "fx": {}},
        ],
    },
    "oncall_policy": {
        "speaker": "Alan (Co-owner)",
        "text": "Clients are starting to call after hours. Somebody has to carry the pager. How do we run it?",
        "options": [
            {"label": "ROTATE EVERYONE, $100/WEEK POOL", "fx": {"weekly": 100, "flag": "oncall_stipend", "burnout": -4}, "text": "A fair rota with a little money behind it. Nobody loves the pager, but everybody takes a turn."},
            {"label": "ALAN TAKES IT EVERY WEEK (+$150)", "fx": {"weekly": 150, "flag": "oncall_one"}, "text": "Alan says fine. For now. The same person every week is how people quit."},
            {"label": "YOU CARRY THE PAGER YOURSELF", "fx": {"flag": "owner_oncall", "burnout": -6}, "text": "The crew is thrilled. Your nights will be less so, and it eats your owner hours every week."},
        ],
    },
    "flex_hours": {
        "speaker": "Alan (Co-owner)",
        "text": "Three of the crew were late this month and two are asking for flexible hours. Route 9 is down to one lane. What is the policy?",
        "options": [
            {"label": "FLEXIBLE START TIMES (CORE 10 TO 4)", "fx": {"flag": "flex_hours", "burnout": -6, "speed": -0.02}, "text": "Morale lifts. The phones are a little thin first thing."},
            {"label": "STRICT PUNCTUALITY, A QUIET WORD", "fx": {"flag": "strict_hours", "burnout": 4, "speed": 0.03}, "text": "People are on time. They also watch the clock at 5:00."},
            {"label": "TRY A FOUR-DAY WEEK", "roll": [[0.5, {"flag": "four_day", "burnout": -15, "rep": 1}, "The crew is a different crew on Mondays. Clients barely notice."], [0.5, {"mood_all": -4, "speed": -0.08, "burnout": -8}, "Clients notice the quiet Fridays. Some are not happy."]]},
        ],
    },
    "rdp_exposed": {
        "speaker": "Alan (Co-owner)",
        "text": "Boss, remote desktop is open to the whole internet at three client sites. The logs show thousands of password guesses a day from overseas. Most are just guessing common passwords, but one lucky guess is all it takes.",
        "options": [
            {"label": "AUTO-BLOCKING FIREWALLS ($600 + $40/WEEK)", "need": 600, "fx": {"cash": -600, "weekly": 40, "flag": "rdp_safe"}, "text": "Repeated failed logins now get an address blocked automatically. The guessing stops."},
            {"label": "PUT REMOTE ACCESS BEHIND A VPN ($1,200)", "need": 1200, "fx": {"cash": -1200, "flag": "rdp_safe", "mood_all": -2}, "text": "Remote access needs the VPN first. Users complain a little, attackers get nothing."},
            {"label": "CHANGE THE PORT NUMBERS ($100)", "need": 100, "fx": {"cash": -100, "flag": "rdp_weak"}, "text": "It slows them down. It does not stop them."},
            {"label": "LEAVE IT", "fx": {}},
        ],
    },
    "ransom_options": {
        "speaker": "Alan (Co-owner)",
        "text": "Hoot and Holler's server is encrypted by CryptoLocker. There is a countdown and a ransom demand in Bitcoin. The backup was not working. What now?",
        "options": [
            {"label": "PAY THE RANSOM ($500)", "need": 500, "roll": [[0.7, {"cash": -500, "ransom_end": "paid", "rep": -1}, "The key arrives and the files unlock. Nobody feels good about it."], [0.3, {"cash": -500, "ransom_end": "lost"}, "They took the money and the key never came."]]},
            {"label": "TRY WINDOWS SHADOW COPIES", "roll": [[0.4, {"ransom_end": "partial", "rep": -2}, "Most files come back from shadow copies."], [0.6, {"ransom_end": "lost"}, "The malware deleted the shadow copies."]]},
            {"label": "ACCEPT THE LOSS", "fx": {"ransom_end": "lost"}},
        ],
    },
    "ransom_lost": {
        "speaker": "Marge (Bookkeeper)",
        "text": "Hoot and Holler lost years of case files because our backup was not working. Their lawyers are talking about suing us.",
        "options": [
            {"label": "SETTLE ($2,500)", "need": 2500, "fx": {"cash": -2500, "rep": -3, "mood": {"3": 10}}},
            {"label": "FIGHT IT", "roll": [[0.5, {"rep": -3}, "The case is dismissed, but it cost you sleep."], [0.5, {"cash": -6000, "rep": -8}, "You lose. It costs $6,000 and your name."]]},
        ],
    },
}
const DAYS := {
    1: [{"at": 9.1, "card": "welcome"}],
    2: [{"at": 9.1, "card": "backup"}, {"at": 15.0, "card": "peer_invite"}],
    3: [{"at": 9.1, "card": "queue"}, {"at": 9.3, "event": "leak_start"}, {"at": 15.0, "card": "marketing"}],
    4: [{"at": 9.5, "card": "desktop"}, {"at": 12.0, "card": "oncall_policy"}, {"at": 14.0, "card": "stack_psa"}],
    5: [{"at": 8.6, "event": "break_backup"}, {"at": 11.0, "card": "stack_hw"}, {"at": 14.0, "card": "billing_audit"}, {"at": 15.0, "event": "peer", "card": "peer1"}, {"at": 15.5, "event": "peer_goal"}, {"at": 12.0, "event": "growth_plan"}],
    6: [{"at": 9.5, "event": "prospect"}, {"at": 10.5, "event": "profit_review"}, {"at": 12.0, "event": "client_no"}, {"at": 15.0, "card": "mentor_offer"}],
    7: [{"at": 11.0, "event": "qbr"}, {"at": 12.5, "card": "rdp_exposed"}, {"at": 14.0, "card": "stack_rmm"}],
    8: [{"at": 9.5, "card": "license"}, {"at": 13.0, "card": "vic_plan"}, {"at": 15.0, "event": "peer", "card": "peer2"}, {"at": 11.0, "event": "growth_stretch"}],
    9: [{"at": 9.8, "event": "grumble"}, {"at": 10.5, "event": "ransomware"}, {"at": 14.5, "card": "marketing"}],
    10: [{"at": 10.0, "card": "rack"}, {"at": 10.8, "event": "profit_review"}, {"at": 14.0, "event": "vic_report"}, {"at": 12.0, "card": "flex_hours"}],
    11: [{"at": 11.0, "event": "qbr"}, {"at": 15.0, "event": "peer", "card": "peer3"}, {"at": 15.2, "event": "leak_hint"}, {"at": 15.5, "event": "peer_goal"}],
    12: [{"at": 9.5, "card": "migration"}, {"at": 10.5, "card": "after_hours"}, {"at": 11.5, "event": "growth_stretch"}],
    13: [{"at": 15.5, "card": "email24"}],
    14: [{"at": 10.0, "event": "vendor_breach"}, {"at": 11.0, "event": "profit_review"}, {"at": 15.0, "card": "marketing"}],
    15: [{"at": 9.5, "card": "raise"}, {"at": 10.5, "event": "grumble"}, {"at": 11.5, "event": "qbr"}],
    16: [{"at": 9.5, "card": "bid"}, {"at": 14.0, "event": "client_breach"}, {"at": 11.0, "event": "growth_stretch"}],
    17: [{"at": 15.0, "event": "peer", "card": "peer4"}, {"at": 15.5, "event": "peer_goal"}],
    18: [{"at": 9.5, "event": "poach_wave"}, {"at": 11.0, "event": "profit_review"}],
    19: [{"at": 11.0, "event": "qbr"}],
}

var cash := START_CASH
var flags := {}
var price := 1.0
var speed := 1.0
var vic_bonus := 0.0
var weekly_extra := 0
var lost_techs := 0
var extra_staff: Array = []
var marketing := 0  # weekly marketing budget
var stack := DEFAULT_STACK.duplicate()
var ar: Array = []  # unpaid invoices: {client, amount, age, delay}
var fee_boost := {}  # client -> fee multiplier won at a business review
var vic_plan := "salary"
var vic_deals := 0
var vic_signed: Array = []
var client_work := {}  # client -> tech-seconds spent this week
var profit_hist := {}  # client -> their last weekly profits
var scope_fixed := {}  # client -> true once you enforced the scope
var burnout := 0.0  # the crew's exhaustion 0-100
var leak := 0.0  # share of revenue silently lost to unbilled work and vendor increases
var leak_found := false
var risk_client := -1  # the client that refused your security recommendation
var risk_choice := ""
var goal := {}  # the accountability goal the peer group will check
var patch_debt := {}  # client -> weeks of missing updates (0-10)
var gone := {}  # clients lost to the competitor: client -> {week, reason, mood}
var discount := {}  # client -> {mult, weeks}
var income_extra := 0  # one-off income / costs this week (jobs)
var history: Array = []

var _dynamic := {}  # cards built at run time (the consultant's advice, inbound leads)
var _advised := false
var _advice_week := {}  # advice topic -> week Dana last opened it (no repeats inside ADVICE_GAP weeks)
var _leads := 0
var _work := {}
var _tick := 0.0
var _fired := {}
var _leaving: Array = []  # clients that threatened to leave, asked about next morning
var _late: Array = []  # clients with invoices long overdue, asked about next morning
var _asked := {}  # client -> week we last chased them
var _qbr_done := {}  # client -> week of their last business review
var _commission_week := 0
var _handover: Array = []  # new clients waiting for a sales-to-service handover decision
var _burn_warned := false
var _poach_queue: Array = []  # competitor attempts waiting for the next morning
var _winback_queue: Array = []  # lost clients asking to come back
var _poach_cool := 0
var _poach_wave := 0  # weeks the competitor is running a campaign (double the risk)
var _ransom_ticket := 0


func active() -> bool:
    return Campaign.active and Campaign.mode == "owner"


func reset() -> void:
    cash = START_CASH
    flags = {}
    price = 1.0
    speed = 1.0
    vic_bonus = 0.0
    weekly_extra = 0
    lost_techs = 0
    extra_staff = []
    marketing = 0
    stack = DEFAULT_STACK.duplicate()
    ar = []
    fee_boost = {}
    vic_plan = "salary"
    vic_deals = 0
    vic_signed = []
    _late = []
    _asked = {}
    _qbr_done = {}
    _commission_week = 0
    client_work = {}
    profit_hist = {}
    scope_fixed = {}
    burnout = 0.0
    leak = 0.0
    leak_found = false
    risk_client = -1
    risk_choice = ""
    goal = {}
    patch_debt = {}
    gone = {}
    _poach_queue = []
    _winback_queue = []
    _poach_cool = 0
    _poach_wave = 0
    _ransom_ticket = 0
    _handover = []
    _burn_warned = false
    discount = {}
    income_extra = 0
    history = []
    _work = {}
    _tick = 0.0
    _fired = {}
    _leaving = []
    _dynamic = {}
    _advised = false
    _advice_week = {}
    _leads = 0


# ---- the team works the queue ----------------------------------------------------------------
func team_speed() -> float:
    var total := float(maxi(0, 3 - lost_techs))
    for hire in extra_staff:
        total += float(hire.skill) + (0.1 if hire.get("trait", "") == "wizard" else 0.0)
    var morale := (0.9 + clampf(Social.average() / 400.0, -0.1, 0.2)) * (1.0 + stack_sum("morale") / 100.0)
    return total * (speed + stack_sum("speed")) * morale * (1.0 - burnout / 300.0) * (1.0 - Growth.capacity_loss()) * (1.0 - Projects.drag())


# ---- the stack you run and sell ----------------------------------------------------------------
func stack_option(category: String) -> Dictionary:
    return STACK[category].options[stack[category]]


func stack_sum(key: String) -> float:
    var total := 0.0
    for category in STACK:
        total += float(stack_option(str(category)).get(key, 0.0))
    return total


func stack_cost() -> int:
    return int(stack_sum("cost"))


# ticket volume multiplier: unreliable hardware and a weak RMM mean more calls
func issue_mult() -> float:
    if not active():
        return 1.0
    var m := 1.0
    for category in STACK:
        m *= float(stack_option(str(category)).get("issues", 1.0))
    if flags.get("after_hours_fee", false):
        m *= 0.92  # most non-critical after-hours calls stop
    return m


# how exposed you are to a vendor compromise: the RMM you chose
func security_risk() -> float:
    return float(stack_option("rmm").get("risk", 1.0))


# scope creep: a few clients generate far more requests until you enforce the contract
func client_weight(client: int) -> float:
    if not active():
        return 1.0
    return 1.0 if scope_fixed.get(client, false) else float(HEAVY.get(client, 1.0))


func client_profit(client: int) -> int:
    var hist: Array = profit_hist.get(client, [])
    if hist.is_empty():
        return client_fee(client) - int(float(client_work.get(client, 0.0)) * COST_PER_SEC)
    var total := 0
    for value in hist:
        total += int(value)
    return int(total / hist.size())


# the community's own maturity ladder (Beginning ... Innovating): count the good habits you have built
func practices() -> int:
    var n := 0
    for flag in ["practice_profit", "practice_goal", "practice_handover", "collections_done", "backup_service"]:
        n += 1 if flags.get(flag, false) else 0
    n += 1 if price != 1.0 else 0
    n += 1 if flags.get("peer_group", false) or flags.get("mentor", false) else 0
    n += 1 if vic_plan != "salary" else 0
    n += 1 if stack_sum("speed") > 0.0 else 0
    n += 1 if flags.get("growth_done", false) else 0
    n += 1 if flags.get("practice_scope", false) else 0
    n += 1 if int(flags.get("outings", 0)) >= 2 else 0
    return n


func oml() -> int:
    # a habit takes weeks to show: the level is capped by the calendar (4 at week 12, 5 at week 16)
    return clampi(mini(1 + (practices() * 2) / 5, 1 + Campaign.day / 4), 1, 5)


# everything that makes Vic better or worse at selling (pay plan, marketing, price, hardware)
func vic_extra() -> float:
    if not active():
        return 0.0
    return vic_bonus + marketing_bonus() + float(VIC_PLANS[vic_plan].skill) + stack_sum("sales") - Growth.vic_penalty() - Projects.vic_penalty()


func hardware_margin() -> int:
    return int(stack_option("hardware").margin)


func new_client_mood() -> int:
    return int(VIC_PLANS[vic_plan].start_mood)


# Vic closed something: pay his commission, bank the hardware resale margin
func on_deal(kind: String, client: int) -> void:
    if not active():
        return
    vic_deals += 1
    vic_signed.append(client)
    var bonus := int(VIC_PLANS[vic_plan].per_deal)
    cash -= bonus
    _commission_week += bonus
    var margin := hardware_margin() * (2 if kind == "client" else 1)
    cash += margin
    income_extra += margin
    if kind == "client":
        _handover.append(client)


func _process(delta: float) -> void:
    if not active() or Game.title_mode or World.time_scale <= 0.0 or not Msp.enabled:
        return
    var dt := delta * World.time_scale
    _tick += dt
    if _tick >= 3.0:
        var slice := _tick
        _tick = 0.0
        _work_queue(slice)
    var events: Array = DAYS.get(Campaign.day, [])
    for i in events.size():
        var ev: Dictionary = events[i]
        if not _fired.has(i) and World.clock >= float(ev.at):
            _fired[i] = true
            fire(ev)
    if flags.get("mentor", false) and not _advised and Campaign.day >= 7 and Campaign.day < Campaign.TOTAL_DAYS and World.clock >= 9.7:
        _advised = true
        advice()


func _work_queue(seconds: float) -> void:
    var capacity := team_speed() * seconds
    for t in Msp.open_tickets():
        if t.fix == "project" or t.fix == "network" or t.internal:
            continue
        if t.fix_done:
            Msp.close_ticket(int(t.id))
            continue
        if capacity <= 0.0:
            break
        var need: float = float(_work.get(int(t.id), WORK[int(t.pri)]))
        var take := minf(need, capacity)
        client_work[int(t.client)] = float(client_work.get(int(t.client), 0.0)) + take
        capacity -= take
        need -= take
        _work[int(t.id)] = need
        if need <= 0.0:
            _finish_ticket(t)


func _finish_ticket(t: Dictionary) -> void:
    _work.erase(int(t.id))
    if randf() < 0.07:
        Msp.close_ticket(int(t.id))  # closed too early: it comes back
        return
    Growth.owner_escalation(t)
    Msp.set_status(int(t.id), "In Progress")
    Msp.rmm_action(str(t.endpoint), str(t.fix))
    Msp.close_ticket(int(t.id))


# ---- a new week ------------------------------------------------------------------------------
func begin_day(day: int) -> void:
    _fired = {}
    _advised = false
    income_extra = 0
    if flags.get("backup_service", false):
        for c in Msp.backups.size():
            Msp.backups[c].ok = true
            Msp.backups[c].good_day = day
    else:
        for c in Sales.active:
            if not Msp.backups[int(c)].ok and randf() < 0.2:
                Msp.backup_rerun(int(c))  # a tech happened to check it
    if not _late.is_empty():
        var late_client: int = _late.pop_front()
        _collections(late_client)
    if not _leaving.is_empty():
        var client: int = _leaving.pop_front()
        _ask_leaving(client)
    if _leads > 0:
        _leads -= 1
        _inbound_lead()
    if not _handover.is_empty():
        _handover_card(int(_handover.pop_front()))
    if not _poach_queue.is_empty():
        _poach_card(_poach_queue.pop_front())
    if not _winback_queue.is_empty():
        _winback_card(int(_winback_queue.pop_front()))
    Projects.begin_week()


func fire(ev: Dictionary) -> void:
    if ev.get("event", "") == "peer":
        if flags.get("peer_group", false):
            show_card(str(ev.card))
        return
    if ev.has("card"):
        show_card(str(ev.card))
        return
    match str(ev.event):
        "prospect":
            _prospect_card()
        "qbr":
            _qbr()
        "vic_report":
            _vic_report()
        "grumble":
            _grumble()
        "leak_start":
            leak = 0.06  # a vendor price rise nobody passed on; some work nobody billed
        "leak_hint":
            if leak > 0.02 and flags.get("peer_group", false):
                show_card("billing_audit")
        "profit_review":
            _profit_review()
        "client_no":
            _client_no()
        "client_breach":
            _client_breach()
        "vendor_breach":
            _vendor_breach()
        "poach_wave":
            _poach_wave = 3
            show_card("poach")
        "peer_goal":
            _peer_goal()
        "break_backup":
            Msp.break_backup(Story.RANSOM_CLIENT)
        "ransomware":
            _ransom()
        "growth_plan":
            Growth.owner_plan_card()
        "growth_stretch":
            Growth.owner_stretch()


func card_data(id: String) -> Dictionary:
    return CARDS.get(id, _dynamic.get(id, {}))


func show_card(id: String) -> void:
    var card: Dictionary = card_data(id)
    var options := []
    for opt in card.options:
        var entry := {"label": str(opt.label), "id": str(options.size())}
        var need := int(opt.get("need", 0))
        if need > 0 and cash < need:
            entry["enabled"] = false
            entry["hint"] = "NEED $%d" % need
        if opt.has("unless") and flags.get(str(opt.unless), false):
            entry["enabled"] = false
            entry["hint"] = "OWNED"
        options.append(entry)
    Cards.ask(str(card.speaker), str(card.text), options, func(pick: String) -> void: _picked(id, int(pick)))


# a mentor shifts 10% of the odds from the worst outcome to the best
func tilted(table: Array) -> Array:
    var out := []
    for entry in table:
        out.append([float(entry[0]), entry[1], entry[2]])
    if flags.get("mentor", false) and out.size() >= 2:
        var shift := minf(0.1, float(out[out.size() - 1][0]))
        out[0][0] += shift
        out[out.size() - 1][0] -= shift
    return out


func _picked(id: String, index: int) -> void:
    var opt: Dictionary = card_data(id).options[index]
    var text := str(opt.get("text", ""))
    if opt.has("roll"):
        var roll := randf()
        var acc := 0.0
        var table: Array = opt.roll
        if opt.has("roll_scoped") and flags.get("scoped", false):
            table = opt.roll_scoped
        for entry in tilted(table):
            acc += float(entry[0])
            if roll <= acc:
                apply(entry[1])
                text = str(entry[2])
                break
    else:
        apply(opt.get("fx", {}))
    flags["card_" + id] = index
    if text != "":
        Cards.ask(str(card_data(id).speaker), text, OPTIONS_OK, func(_p: String) -> void: pass)


func apply(fx: Dictionary) -> void:
    cash += int(fx.get("cash", 0))
    if fx.has("rep"):
        Campaign.adjust_rep(int(fx.rep))
    if fx.has("mood_all"):
        for c in Sales.active:
            Sales.adjust(int(c), int(fx.mood_all))
    if fx.has("mood"):
        for key in fx.mood:
            Sales.adjust(int(key), int(fx.mood[key]))
    if fx.has("flag"):
        flags[str(fx.flag)] = true
    if fx.has("unflag"):
        flags[str(fx.unflag)] = false
    if fx.has("marketing"):
        marketing = int(fx.marketing)
    if fx.has("burnout"):
        burnout = clampf(burnout + float(fx.burnout), 0.0, 100.0)
    if fx.has("remediate"):
        var healed := int(fx.remediate)
        Msp.backup_rerun(healed)
        patch_debt[healed] = 0.0
    if fx.has("discount_one"):
        var d: Dictionary = fx.discount_one
        discount[int(d.client)] = {"mult": float(d.mult), "weeks": int(d.weeks)}
    if fx.get("health_check", false):
        for c in Sales.active:
            Msp.backup_rerun(int(c))
            patch_debt[int(c)] = float(patch_debt.get(int(c), 0.0)) * 0.5
    if fx.has("rejoin"):
        var back := int(fx.rejoin)
        if not Sales.active.has(back):
            Sales.active.append(back)
        var extra := int((fx.get("mood", {}) as Dictionary).get(str(back), 0))
        Sales.satisfaction[back] = clampi(70 + extra, 0, 100)
        patch_debt[back] = 4.0  # nobody patched them while they were away
        gone.erase(back)
    if fx.has("gone_clear"):
        gone.erase(int(fx.gone_clear))
    if fx.has("ransom_end"):
        _ransom_finish(str(fx.ransom_end))
    if fx.has("fire"):
        var told: String = Projects.fire_client(int(fx.fire.client), str(fx.fire.how))
        Msp.send_text("Marge", told)
        Hints.toast(told, 4.0)
    if fx.has("change_order"):
        var result: String = Projects.change_order(int(fx.change_order))
        Msp.send_text("Marge", result)
        Hints.toast(result, 4.0)
    if fx.has("scope"):
        scope_fixed[int(fx.scope)] = true
    if fx.get("fix_leak", false):
        leak = 0.01
        leak_found = true
    if fx.has("risk_choice"):
        risk_choice = str(fx.risk_choice)
    if fx.has("goal"):
        goal = {"id": str(fx.goal), "week": Campaign.day}
    if fx.has("stack"):
        for category in fx.stack:
            stack[str(category)] = str(fx.stack[category])
    if fx.has("vic_plan"):
        vic_plan = str(fx.vic_plan)
    if fx.has("fee_boost"):
        fee_boost[int(fx.fee_boost.client)] = float(fx.fee_boost.mult)
    if fx.has("collect"):
        _collect(int(fx.collect), float(fx.get("fraction", 1.0)))
    if fx.has("writeoff"):
        _writeoff(int(fx.writeoff))
    if fx.has("drop_client"):
        drop_client(int(fx.drop_client), str(fx.get("left_for", "")))
    if fx.get("candidates", false):
        _hire_card()
    if fx.has("show"):
        show_card(str(fx.show))
    if fx.get("check_backups", false):
        for c in Sales.active:
            Msp.backup_check(int(c))
            Msp.backup_rerun(int(c))
    price += float(fx.get("price", 0.0))
    speed += float(fx.get("speed", 0.0))
    vic_bonus += float(fx.get("vic", 0.0))
    weekly_extra += int(fx.get("weekly", 0))
    if fx.has("hire"):
        var newbie: Dictionary = fx.hire.duplicate()
        newbie["age"] = 0
        extra_staff.append(newbie)
    if fx.get("lose_tech", false):
        lost_techs += 1
    if fx.get("sign", false):
        var signed: int = Sales.sign_client(int(fx.get("client", -1)))
        if signed >= 0 and fx.has("sign_bonus"):
            # the owner closed it in person: better first-month mood and a better fee
            Sales.satisfaction[signed] = clampi(Sales.mood(signed) + int(fx.sign_bonus.mood), 0, 100)
            fee_boost[signed] = float(fx.sign_bonus.fee)
        if signed >= 0 and fx.has("discount_new"):
            discount[signed] = {
                "mult": float(fx.discount_new.mult), "weeks": int(fx.discount_new.weeks)
            }
    if fx.has("onsite_visit"):
        Onsite.start_visit(int(fx.onsite_visit.client), str(fx.onsite_visit.kind))
    if fx.get("drop", false):
        drop_random_client()
    if fx.has("discount"):
        for c in Sales.active:
            discount[int(c)] = {"mult": float(fx.discount.mult), "weeks": int(fx.discount.weeks)}
    if fx.has("quote"):
        var q: Dictionary = fx.quote
        cash += int(q.cash) - int(q.cost)
        income_extra += int(q.cash) - int(q.cost)
        Campaign.adjust_rep(int(q.rep))
    Msp.changed.emit()


# which advice card Dana opens: the relevant ones in priority order, never one shown in the last 3 weeks
func advice_topic(open: int, est: Dictionary) -> String:
    var relevant := []
    if cash < 1500:
        relevant.append("cash")
    if float(est.w2) > W2_TARGET + 0.15:
        relevant.append("w2")
    if Sales.average() < 55.0:
        relevant.append("mood")
    if open >= 5:
        relevant.append("queue")
    if relevant.is_empty():
        relevant.append("healthy")
    relevant.append_array(["train", "lunch", "push"])
    var oldest := ""
    for topic in relevant:
        var since: int = Campaign.day - int(_advice_week.get(topic, -99))
        if since >= ADVICE_GAP:
            return str(topic)
        if oldest == "" or int(_advice_week.get(topic, -99)) < int(_advice_week.get(oldest, -99)):
            oldest = str(topic)
    return oldest


# the consultant's Monday advice: a card built from your actual numbers
func advice() -> void:
    var text := ""
    var options := []
    var open := Msp.open_tickets().size()
    var est := weekly_estimate()
    var key := advice_topic(open, est)
    _advice_week[key] = Campaign.day
    if key == "cash":
        text = "Cash is thin. I would look at pricing before anything else, and I would not add payroll right now."
        options = [{"label": "RAISE PRICES 8% (MOOD -3)", "fx": {"price": 0.08, "mood_all": -3}}, {"label": "I WILL MANAGE", "fx": {}}]
    elif key == "w2":
        text = "Your W-2 ratio is %d%%. Healthy MSPs stay near %d%%. Either grow revenue or hold payroll flat until you do." % [int(100.0 * float(est.w2)), int(100.0 * W2_TARGET)]
        options = [{"label": "PUSH SALES (MARKETING $400/WEEK)", "fx": {"marketing": 400}}, {"label": "HOLD PAYROLL FLAT", "fx": {}}]
    elif key == "mood":
        text = "Your clients are unhappy. That always turns into churn a few weeks later. Fix the relationship before the revenue disappears."
        options = [{"label": "CLIENT REVIEW LUNCHES ($300)", "need": 300, "fx": {"cash": -300, "mood_all": 8}}, {"label": "FOCUS THE TEAM ON SLAS", "fx": {"speed": 0.1}}]
    elif key == "queue":
        text = "Your queue is backing up (%d open). Either add hands or make the hands you have faster." % open
        options = [{"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}}, {"label": "TRAIN THE CREW ($400)", "need": 400, "fx": {"cash": -400, "speed": 0.25}}]
    elif key == "healthy":
        text = "Things look healthy: your EBITDA margin is %d%%. This is the time to invest in growth and put money behind Vic." % int(100.0 * float(est.margin))
        options = [{"label": "MARKETING PUSH ($500)", "need": 500, "fx": {"cash": -500, "vic": 0.1}}, {"label": "KEEP DOING WHAT WORKS", "fx": {}}]
    elif key == "train":
        text = "Whatever else is going on, the crew is the product. A week of training pays back in faster tickets and fewer reopens."
        options = [
            {"label": "TRAIN THE CREW ($400)", "need": 400, "fx": {"cash": -400, "speed": 0.25}},
            {"label": "NOT NOW", "fx": {}}
        ]
    elif key == "lunch":
        text = "Clients rarely say they are unhappy until the day they leave. Take your best ones to lunch before the competitor does."
        options = [
            {"label": "CLIENT REVIEW LUNCHES ($300)", "need": 300, "fx": {"cash": -300, "mood_all": 8}},
            {"label": "NOT NOW", "fx": {}}
        ]
    else:
        text = "Pipeline pays for next year. Your EBITDA margin is %d%%: put a little money behind Vic whatever the month looks like." % int(100.0 * float(est.margin))
        options = [
            {"label": "MARKETING PUSH ($500)", "need": 500, "fx": {"cash": -500, "vic": 0.1}},
            {"label": "NOT NOW", "fx": {}}
        ]
    options.append({"label": "DISMISS DANA (SAVE $400/WEEK)", "fx": {"weekly": -400, "unflag": "mentor"}})
    _dynamic["advice"] = {"speaker": "Dana Whitfield (Consultant)", "text": text, "options": options}
    show_card("advice")


# week 6: a named prospect (one who is not a client yet) asks for a discount to sign
func _prospect_card() -> void:
    var pool := []
    for c in Msp.CLIENTS.size():
        if not Sales.active.has(c):
            pool.append(c)
    if pool.is_empty() or Sales.active.size() >= Sales.MAX_CLIENTS:
        return
    var who: int = pool[randi() % pool.size()]
    var card: Dictionary = CARDS.prospect.duplicate(true)
    card.text = str(card.text) % Msp.CLIENTS[who].name
    for opt in card.options:
        if opt.has("fx") and opt.fx.has("sign"):
            opt.fx["client"] = who
        if opt.has("roll"):
            for entry in opt.roll:
                if entry[1].has("sign"):
                    entry[1]["client"] = who
    _dynamic["prospect_live"] = card
    show_card("prospect_live")


# marketing brought in a prospect: you can take the meeting or hand it to Vic
func _inbound_lead() -> void:
    var pool := []
    for c in Msp.CLIENTS.size():
        if not Sales.active.has(c):
            pool.append(c)
    if pool.is_empty() or Sales.active.size() >= Sales.MAX_CLIENTS:
        return
    pool.sort_custom(func(a: int, b: int) -> bool: return int(Onsite.has_site(a)) > int(Onsite.has_site(b)))
    var lead: int = pool[0]
    var prospect: String = Msp.CLIENTS[lead].name
    var vic_odds := clampf(Sales.vic_skill() + 0.25, 0.3, 0.95)
    _dynamic["lead"] = {
        "speaker": "Vic Marlowe",
        "text": "An inbound lead from our marketing: %s found us online and wants a meeting." % prospect,
        "options": [
            {"label": "TAKE THE MEETING YOURSELF (60%: HAPPIER, +10% FEE)", "roll": [[0.6, {"sign": true, "client": lead, "sign_bonus": {"mood": 15, "fee": 1.1}}, "You charm them. %s signs at a better rate and starts happy." % prospect], [0.4, {}, "They say they will think about it."]]},
            {"label": "LET VIC CLOSE IT (%d%%)" % int(vic_odds * 100.0), "roll": [[vic_odds, {"sign": true, "client": lead}, "Vic closes it. %s signs." % prospect], [1.0 - vic_odds, {}, "Vic fumbles it. They go quiet."]]},
        ],
    }
    if Onsite.has_site(lead):
        _dynamic["lead"].options.append(
            {
                "label": "PITCH THEM AT THEIR OFFICE (%d MIN)" % Onsite.estimate_minutes(lead),
                "fx": {"onsite_visit": {"client": lead, "kind": "pitch"}},
            }
        )
    show_card("lead")


func marketing_bonus() -> float:
    var spend := float(marketing)
    return spend / (spend + 1500.0) * 0.4 * Growth.marketing_factor()


# ---- hiring: three named candidates with skills and quirks ----------------------------
func make_candidates() -> Array:
    var pool: Array = NAMES.duplicate()
    pool.shuffle()
    var trait_ids: Array = TRAITS.keys()
    var out := []
    for i in 3:
        var skill := snappedf(randf_range(0.5, 1.3), 0.05)
        var trait_id: String = trait_ids[randi() % trait_ids.size()]
        var wage := int(round((280.0 + 250.0 * skill) / 10.0)) * 10 + int(TRAITS[trait_id].get("wage", 0))
        out.append({"name": pool[i], "skill": skill, "wage": wage, "trait": trait_id})
    return out


func _hire_card() -> void:
    var options := []
    for cand in make_candidates():
        var label := "%s  SKILL %.2f  $%d/WK  %s" % [str(cand.name).to_upper(), float(cand.skill), int(cand.wage), str(TRAITS[cand.trait].label)]
        options.append({"label": label, "fx": {"hire": cand}, "text": "%s joins the team." % cand.name})
    options.append({"label": "NO ONE RIGHT NOW", "fx": {}})
    _dynamic["hire"] = {
        "speaker": "Marge (Bookkeeper)",
        "text": "Three candidates came through the door. Skill is relative to a senior tech at 1.0; wages are weekly and count toward your W-2 ratio.",
        "options": options,
    }
    show_card("hire")


# new hires change week by week: green ones learn, people-people please clients, flight risks leave
func _staff_week() -> void:
    for hire in extra_staff.duplicate():
        hire["age"] = int(hire.get("age", 99)) + 1
        var trait_data: Dictionary = TRAITS.get(str(hire.get("trait", "steady")), {})
        if trait_data.has("grow"):
            hire.skill = minf(1.0, float(hire.skill) + float(trait_data.grow))
        if trait_data.has("mood"):
            for c in Sales.active:
                Sales.adjust(int(c), int(trait_data.mood))
        var quit_chance := float(trait_data.get("quit", 0.0)) + (0.08 if stack_sum("morale") <= -8.0 else 0.0)
        if randf() < quit_chance:
            extra_staff.erase(hire)
            Msp.send_text("Marge", "%s quit." % hire.name)
    if stack_sum("morale") <= -8.0 and lost_techs < 2 and randf() < 0.08:
        lost_techs += 1
        Msp.send_text("Alan", "One of the techs just quit over the tooling.")
    if flags.get("oncall_one", false) and lost_techs < 2 and randf() < 0.05:
        lost_techs += 1
        flags["oncall_one"] = false
        Msp.send_text("Alan", "I am done carrying the pager every week. I quit.")


# ---- the crew complains about bad tools ---------------------------------------------------------------
func _grumble() -> void:
    if stack_sum("morale") > -6.0:
        return
    var worst_cat := ""
    var worst := 0
    for category in STACK:
        var m := int(stack_option(str(category)).get("morale", 0))
        if m < worst:
            worst = m
            worst_cat = str(category)
    if worst_cat == "":
        return
    var fallback: Dictionary = {worst_cat: DEFAULT_STACK[worst_cat]}
    _dynamic["grumble"] = {
        "speaker": "Alan (Co-owner)",
        "text": "The crew hates %s. Morale is sinking and people are updating their resumes." % str(stack_option(worst_cat).name),
        "options": [
            {"label": "SWITCH BACK TO THE STANDARD ($300)", "need": 300, "fx": {"cash": -300, "stack": fallback}, "text": "Cheers all round."},
            {"label": "PAY A TOOL BONUS ($400)", "need": 400, "fx": {"cash": -400, "speed": 0.1}, "text": "A bonus buys goodwill, for a while."},
            {"label": "TELL THEM TO DEAL WITH IT", "roll": [[0.6, {}, "They grumble and carry on."], [0.4, {"lose_tech": true, "rep": -1}, "One of the techs resigns over the tooling."]]},
        ],
    }
    show_card("grumble")


# ---- accounts receivable: some clients pay late -------------------------------------------------
func pay_delay(client: int) -> int:
    var delay := int(SLOW_PAYERS.get(client, 0))
    if Sales.mood(client) < 35:
        delay += 1
    return delay


func ar_total(client := -1) -> int:
    var total := 0
    for inv in ar:
        if client < 0 or int(inv.client) == client:
            total += int(inv.amount)
    return total


func overdue(client: int) -> bool:
    for inv in ar:
        if int(inv.client) == client and int(inv.age) >= 2:
            return true
    return false


func _collect(client: int, fraction: float) -> void:
    for inv in ar.duplicate():
        if int(inv.client) != client:
            continue
        if fraction >= 1.0:
            cash += int(inv.amount)
            ar.erase(inv)
        else:
            var part := int(float(inv.amount) * fraction)
            cash += part
            inv.amount = int(inv.amount) - part


func _writeoff(client: int) -> void:
    var lost := ar_total(client)
    for inv in ar.duplicate():
        if int(inv.client) == client:
            ar.erase(inv)
    income_extra -= lost  # bad debt hits EBITDA


func _collections(client: int) -> void:
    var owed := ar_total(client)
    if owed <= 0 or not Sales.active.has(client):
        return
    var key := str(client)
    _dynamic["collections"] = {
        "speaker": "Marge (Bookkeeper)",
        "text": "%s owes us $%d and the invoices are weeks late. Their contact keeps saying the check is in the mail." % [Msp.CLIENTS[client].name, owed],
        "options": [
            {"label": "SEND A FIRM REMINDER", "roll": [[0.55, {"collect": client, "mood": {key: -2}}, "They pay up, a bit sulkily."], [0.45, {"mood": {key: -4}}, "They promise next week. Again."]]},
            {"label": "OFFER A PAYMENT PLAN (HALF NOW)", "fx": {"collect": client, "fraction": 0.5, "mood": {key: 2}}, "text": "Half arrives now. The rest will trickle in."},
            {"label": "SUSPEND SERVICE UNTIL THEY PAY", "roll": [[0.7, {"collect": client, "mood": {key: -12}}, "They pay in a hurry, furious."], [0.3, {"writeoff": client, "drop_client": client}, "They walk away without paying."]]},
            {"label": "WRITE IT OFF", "fx": {"writeoff": client}, "text": "Written off. Marge sighs and updates the books."},
        ],
    }
    flags["collections_done"] = true
    show_card("collections")


func drop_client(client: int, reason := "") -> void:
    if reason != "":
        # lost to the competitor: they may come back if your service was otherwise good
        gone[client] = {"week": Campaign.day, "reason": reason, "mood": Sales.mood(client)}
    Sales.active.erase(client)
    discount.erase(client)
    fee_boost.erase(client)
    scope_fixed.erase(client)
    profit_hist.erase(client)
    client_work.erase(client)
    Projects.client_gone(client)
    if client == risk_client:
        risk_client = -1
    Msp.send_text("Vic", "%s is gone." % Msp.CLIENTS[client].name)


# a client is due a business review from week 6 on, 8 weeks after the last one (never at the start)
func review_due(client: int) -> bool:
    return Campaign.day >= 6 and Campaign.day - int(_qbr_done.get(client, -99)) >= 8


# ---- quarterly business review: a client meeting ----------------------------------------------------------
func _qbr() -> void:
    var pick := -1
    var worst := 100000
    for c in Sales.active:
        if not review_due(int(c)):
            continue
        var score := Sales.mood(int(c)) - client_fee(int(c)) / 100
        if score < worst:
            worst = score
            pick = int(c)
    if pick < 0:
        return
    _qbr_done[pick] = Campaign.day
    var key := str(pick)
    var odds := clampf(Sales.vic_skill() + 0.25 + (0.1 if Sales.mood(pick) >= 70 else 0.0), 0.2, 0.9)
    _dynamic["qbr"] = {
        "speaker": "Vic Marlowe",
        "text": "Business review time with %s (mood %d%%, they pay $%d a week). How much do we prepare?" % [Msp.CLIENTS[pick].name, Sales.mood(pick), client_fee(pick)],
        "options": [
            {"label": "FULL REVIEW WITH VIC ($250)", "need": 250, "roll": [[odds, {"cash": -250, "mood": {key: 12}, "fee_boost": {"client": pick, "mult": 1.1}}, "A great review: they add premium support. Their fee goes up 10%."], [1.0 - odds, {"cash": -250, "mood": {key: 6}}, "A solid review. They feel heard."]]},
            {"label": "QUICK CHECK-IN (FREE)", "roll": [[0.6, {"mood": {key: 4}}, "A friendly check-in."], [0.4, {"mood": {key: 1}}, "They seem distracted."]]},
            {"label": "JUST SEND A REPORT", "fx": {"mood": {key: 1}}},
        ],
    }
    if Onsite.has_site(pick):
        _dynamic["qbr"].options.append(
            {
                "label": "GO ONSITE FOR THE REVIEW (%d MIN)" % Onsite.estimate_minutes(pick),
                "fx": {"onsite_visit": {"client": pick, "kind": "qbr"}},
            }
        )
    show_card("qbr")


# ---- the owner's view of the sales guy ---------------------------------------------------------------------
func vic_new_client_mood() -> int:
    var total := 0
    var n := 0
    for c in vic_signed:
        if Sales.active.has(c):
            total += Sales.mood(int(c))
            n += 1
    return int(total / n) if n > 0 else -1


func _vic_report() -> void:
    var avg := vic_new_client_mood()
    var text := "I have closed %d deals so far under the %s plan." % [vic_deals, str(VIC_PLANS[vic_plan].label).to_lower()]
    if avg >= 0:
        text += " My new clients average %d%% happiness." % avg
        if avg < 60:
            text += " A few of them did say I over-promised."
    _dynamic["vic_report"] = {
        "speaker": "Vic Marlowe",
        "text": text,
        "options": [
            {"label": "GIVE HIM A BONUS ($300)", "need": 300, "fx": {"cash": -300, "vic": 0.05}, "text": "Vic puts the bonus toward a very nice watch."},
            {"label": "CHANGE HIS PAY PLAN", "fx": {"show": "vic_plan"}},
            {"label": "NO CHANGES", "fx": {}},
        ],
    }
    show_card("vic_report")


# ---- client profitability and scope creep -----------------------------------------------------------
func _profit_review() -> void:
    flags["practice_profit"] = true
    var pick := -1
    var worst := 1.0
    for c in Sales.active:
        if (profit_hist.get(int(c), []) as Array).size() < 2:
            continue
        var ratio := float(client_profit(int(c))) / float(maxi(1, client_fee(int(c))))
        if ratio < worst:
            worst = ratio
            pick = int(c)
    if pick < 0 or worst >= 0.2:
        return
    var key := str(pick)
    var fee := client_fee(pick)
    var profit := client_profit(pick)
    _dynamic["profit"] = {
        "speaker": "Marge (Bookkeeper)",
        "text": "%s pays $%d a week but the work costs us about $%d: %d hours a week against %d included. After labor we %s $%d a week on them. What do we do?" % [Msp.CLIENTS[pick].name, fee, fee - profit, int(Projects.avg_hours(pick)), int(Projects.included_hours(pick)), "make" if profit >= 0 else "LOSE", absi(profit)],
        "options": [
            {"label": "RAISE THEIR FEE 20%", "roll": [[0.55, {"fee_boost": {"client": pick, "mult": 1.2}, "mood": {key: -4}}, "They grumble and agree. The fee goes up 20%."], [0.2, {"fee_boost": {"client": pick, "mult": 1.1}, "mood": {key: -12}}, "They only accept 10% and resent it."], [0.25, {"drop_client": pick}, "They walk away rather than pay more."]]},
            {"label": "ENFORCE THE SCOPE (CHANGE ORDERS)", "roll": [[0.6, {"scope": pick, "mood": {key: -6}}, "They grumble, but the endless small requests stop."], [0.4, {"mood": {key: -12}}, "They push back hard and refuse to sign anything."]]},
            {"label": "BILL A CHANGE ORDER ($%d FOR THE EXTRA HOURS)" % Projects.change_order_amount(pick), "fx": {"change_order": pick}},
            {"label": "OTHER: LET THEM GO, OR KEEP EATING IT", "fx": {"show": "profit_fire"}},
        ],
    }
    _dynamic["profit_fire"] = {
        "speaker": "Marge (Bookkeeper)",
        "text": "Firing %s is an option, but word travels in a small business crowd, especially if they leave angry. A polite exit with notice is safer than a sudden one." % Msp.CLIENTS[pick].name,
        "options": [
            {"label": "FIRE THEM POLITELY (30 DAYS NOTICE)", "fx": {"fire": {"client": pick, "how": "polite"}}},
            {"label": "FIRE THEM NOW", "fx": {"fire": {"client": pick, "how": "now"}}},
            {"label": "KEEP THEM AND EAT THE COST", "fx": {}},
        ],
    }
    show_card("profit")


# ---- burnout: the crew has limits ------------------------------------------------------------------------------
func _burnout_week() -> void:
    var open := Msp.open_tickets().size()
    var relief := (4.0 if flags.get("after_hours_fee", false) else 0.0) + (3.0 if flags.get("oncall_stipend", false) else 0.0) + 2.0 * float(extra_staff.size())
    relief += (2.0 if flags.get("flex_hours", false) else 0.0) + (3.0 if flags.get("four_day", false) else 0.0)
    relief -= (3.0 if flags.get("oncall_one", false) else 0.0) + (2.0 if flags.get("strict_hours", false) else 0.0)
    burnout = clampf(burnout + clampf(float(open - 3) * 4.0, -6.0, 12.0) - relief, 0.0, 100.0)
    if burnout >= 50.0 and not _burn_warned:
        _burn_warned = true
        _dynamic["burnout"] = {
            "speaker": "Alan (Co-owner)",
            "text": "Boss, the crew is fried. Nights, weekends, a queue that never empties. Somebody is going to quit if nothing changes.",
            "options": [
                {"label": "SEE HIRING CANDIDATES", "fx": {"candidates": true}},
                {"label": "TALK ABOUT AFTER-HOURS PAY", "fx": {"show": "after_hours"}},
                {"label": "THEY WILL BE FINE", "fx": {}},
            ],
        }
        show_card("burnout")
    if burnout >= 70.0 and lost_techs < 2 and randf() < 0.18:
        lost_techs += 1
        burnout = maxf(0.0, burnout - 20.0)
        Msp.send_text("Alan", "One of the techs quit. Burned out.")


# ---- a vendor breach: the RMM you chose ---------------------------------------------------------------------------
func _vendor_breach() -> void:
    var hit := clampf(0.35 * security_risk(), 0.05, 0.8)
    var vendor: String = str(stack_option("rmm").name)
    _dynamic["vendor_breach"] = {
        "speaker": "Alan (Co-owner)",
        "text": "%s just announced a breach: attackers pushed malicious code through their update channel. Every shop that uses it is exposed, including us. How fast do we move?" % vendor,
        "options": [
            {"label": "NOTIFY CLIENTS + ROTATE CREDENTIALS ($600)", "need": 600, "fx": {"cash": -600, "mood_all": -3, "rep": 2}, "text": "You got ahead of it. Clients respected the honesty."},
            {"label": "WAIT FOR THE VENDOR'S STATEMENT", "roll": [[hit, {"cash": -3500, "mood_all": -10, "rep": -4}, "Two clients were hit before the vendor said a word. Lawyers are involved."], [1.0 - hit, {}, "Nothing happened, this time."]]},
            {"label": "SWITCH TO ANOTHER RMM NOW ($800)", "need": 800, "fx": {"cash": -800, "stack": {"rmm": "labrat_gold"}, "mood_all": -2}, "text": "A painful weekend, but you are off the compromised tool."},
        ],
    }
    show_card("vendor_breach")


# ---- the client who said no ---------------------------------------------------------------------------------------
func _client_no() -> void:
    var pool := []
    for c in Sales.active:
        pool.append(int(c))
    if pool.is_empty():
        return
    var pick: int = pool[randi() % pool.size()]
    risk_client = pick
    risk_choice = ""
    var key := str(pick)
    _dynamic["client_no"] = {
        "speaker": "Alan (Co-owner)",
        "text": "%s's owner refuses to turn on two-factor login for email. 'Too annoying for staff.' We have warned them twice. They will not budge." % Msp.CLIENTS[pick].name,
        "options": [
            {"label": "GET A SIGNED RISK-ACCEPTANCE WAIVER", "fx": {"risk_choice": "waiver", "mood": {key: -2}}, "text": "Signed and filed. If anything happens, there is a paper trail."},
            {"label": "INSIST OR WE WALK AWAY", "roll": [[0.5, {"risk_choice": "insisted", "mood": {key: -6}}, "They give in and turn two-factor login on."], [0.5, {"drop_client": pick}, "They fire you instead."]]},
            {"label": "LET IT GO", "fx": {"risk_choice": "ignored"}},
        ],
    }
    show_card("client_no")


func _client_breach() -> void:
    if risk_client < 0 or not Sales.active.has(risk_client):
        return
    var name: String = Msp.CLIENTS[risk_client].name
    var key := str(risk_client)
    var text := ""
    match risk_choice:
        "insisted":
            apply({"mood": {key: 10}, "rep": 1})
            text = "A phishing attempt at %s was stopped cold by the two-factor login you insisted on. They sent a thank-you." % name
        "waiver":
            apply({"cash": -500, "mood": {key: -4}})
            text = "An account at %s was taken over and a $12,000 payment redirected. Your signed waiver shows you warned them. You help them recover, and their insurer denies the claim." % name
        _:
            if randf() < 0.5:
                apply({"cash": -4000, "rep": -4, "mood": {key: -15}})
                text = "An account at %s was taken over and $12,000 was wired away. They blame you. A lawyer's letter arrives and you settle for $4,000." % name
            else:
                apply({"cash": -1200, "rep": -2, "mood": {key: -8}})
                text = "An account at %s was taken over. They blame you. You pay $1,200 to make it go away." % name
    risk_client = -1
    Cards.ask("Marge (Bookkeeper)", text, OPTIONS_OK, func(_p: String) -> void: pass)


# ---- handing a new client from sales to service ---------------------------------------------------------------------
func _handover_card(client: int) -> void:
    if not Sales.active.has(client):
        return
    var key := str(client)
    _dynamic["handover"] = {
        "speaker": "Vic Marlowe",
        "text": "Before we onboard %s: a proper handover between me and the lead tech (what I promised, their environment, their SLAs), or do we just start?" % Msp.CLIENTS[client].name,
        "options": [
            {"label": "FULL HANDOVER MEETING ($150)", "need": 150, "fx": {"cash": -150, "mood": {key: 8}, "flag": "practice_handover"}, "text": "No surprises on day one. They start off happier."},
            {"label": "QUICK HALLWAY HANDOVER", "fx": {"mood": {key: 2}}},
            {"label": "JUST START, WE WILL FIGURE IT OUT", "fx": {"mood": {key: -6}}, "text": "The first week is rough. They notice."},
        ],
    }
    show_card("handover")


# ---- the peer group holds you to your goal -----------------------------------------------------------------------------
func _goal_met(id: String) -> bool:
    match id:
        "w2":
            return float(weekly_estimate().w2) <= 0.60
        "mood":
            return Sales.average() >= 70.0
        _:
            return ar_total() <= 1500


func _peer_goal() -> void:
    if not flags.get("peer_group", false):
        return
    if not goal.is_empty():
        var met := _goal_met(str(goal.id))
        Campaign.adjust_rep(2 if met else -1)
        flags["practice_goal"] = true
        var verdict := "You hit it. The group applauds." if met else "You missed it. The group is disappointed but supportive."
        Msp.send_text("MSP Mastermind", "Goal check (%s): %s" % [str(GOALS[goal.id]).to_lower(), verdict])
        goal = {}
    if Campaign.day >= 17:
        return
    var options := []
    for id in GOALS:
        options.append({"label": str(GOALS[id]), "fx": {"goal": str(id)}})
    options.append({"label": "NO GOAL THIS QUARTER", "fx": {}})
    _dynamic["goal"] = {"speaker": "MSP Mastermind", "text": "Set a goal for next quarter. The group will check you on it at the next meeting.", "options": options}
    show_card("goal")


# ---- patching: the quiet work that keeps clients safe (and keeps competitors out) -------------------------
func _patching(spare: float) -> void:
    var order := []
    for c in Sales.active:
        patch_debt[int(c)] = minf(10.0, float(patch_debt.get(int(c), 0.0)) + 1.0)
        order.append(int(c))
    order.sort_custom(func(x: int, y: int) -> bool: return float(patch_debt[x]) > float(patch_debt[y]))
    var jobs := int(spare / 60.0) + int(stack_sum("patching"))
    for i in mini(jobs, order.size()):
        patch_debt[order[i]] = maxf(0.0, float(patch_debt[order[i]]) - 2.0)


# ---- a competing MSP circles your clients --------------------------------------------------------------------------
func poach_gaps(client: int) -> Array:
    var out := []
    if not bool(Msp.backups[client].ok):
        out.append("failing backups")
    if float(patch_debt.get(client, 0.0)) >= 4.0:
        out.append("months of missing updates")
    if Sales.mood(client) < 50:
        out.append("unhappy users")
    return out


func poach_risk(client: int) -> float:
    var r := 0.02
    var mood := Sales.mood(client)
    if mood < 35:
        r += 0.12
    elif mood < 50:
        r += 0.06
    if not bool(Msp.backups[client].ok):
        r += 0.07
    var debt := float(patch_debt.get(client, 0.0))
    if debt >= 7.0:
        r += 0.10
    elif debt >= 4.0:
        r += 0.05
    if price >= 1.15:
        r += 0.03
    if _poach_wave > 0:
        r *= 2.0
    return minf(r, 0.6)


func _poach_week() -> void:
    _poach_cool = maxi(0, _poach_cool - 1)
    if _poach_cool == 0 and Campaign.day >= 4 and not Sales.active.is_empty():
        var target := -1
        for c in Sales.active:
            if randf() < poach_risk(int(c)):
                target = int(c)
                break
        if target < 0 and randf() < 0.04:  # rarer: a lower price, even when you did everything right
            var clean := []
            for c in Sales.active:
                if poach_gaps(int(c)).is_empty():
                    clean.append(int(c))
            if not clean.is_empty():
                target = clean[randi() % clean.size()]
        if target >= 0:
            _poach_queue.append({"client": target, "kind": "gaps" if not poach_gaps(target).is_empty() else "price"})
            _poach_cool = 2
    _poach_wave = maxi(0, _poach_wave - 1)
    _winback_week()


func _poach_card(item: Dictionary) -> void:
    var client := int(item.client)
    if not Sales.active.has(client):
        return
    var name: String = Msp.CLIENTS[client].name
    var key := str(client)
    if str(item.kind) == "price":
        var saving := int(float(client_fee(client)) * 0.2)
        var odds := clampf(0.4 + float(Sales.mood(client)) / 200.0 + Sales.vic_skill() * 0.2, 0.3, 0.9)
        _dynamic["poach_price"] = {
            "speaker": "Vic Marlowe",
            "text": "%s likes us and everything is in order, but %s offered them a price we cannot easily match: about $%d a week less. 'It is just IT,' they said." % [name, COMPETITOR, saving],
            "options": [
                {"label": "SHOW THEM THE VALUE (REVIEW, $250)", "need": 250, "roll": [[odds, {"cash": -250, "mood": {key: 8}}, "You walk them through the uptime, the backups, the patching. They stay."], [1.0 - odds, {"cash": -250, "drop_client": client, "left_for": "price"}, "They liked you, but cheap won. They leave on good terms."]]},
                {"label": "MATCH PART OF IT (-10% FOR 12 WEEKS)", "roll": [[0.8, {"discount_one": {"client": client, "mult": 0.9, "weeks": 12}, "mood": {key: 4}}, "They stay on the lower price."], [0.2, {"drop_client": client, "left_for": "price"}, "They leave anyway."]]},
                {"label": "WISH THEM WELL", "fx": {"drop_client": client, "left_for": "price", "rep": 1}, "text": "You part on good terms. If the cheap service disappoints, they know where to find you."},
            ],
        }
        show_card("poach_price")
        return
    var gaps := poach_gaps(client)
    var save := clampf(0.8 - 0.12 * float(gaps.size()) + (0.1 if Sales.mood(client) >= 60 else 0.0), 0.3, 0.9)
    _dynamic["poach_gaps"] = {
        "speaker": "Vic Marlowe",
        "text": "%s's contact says %s walked in with a free 'IT assessment' that listed: %s. They are offering about 20%% less." % [name, COMPETITOR, ", ".join(gaps)],
        "options": [
            {"label": "FIX THE GAPS, PRESENT A PLAN ($400)", "need": 400, "roll": [[save, {"cash": -400, "remediate": client, "mood": {key: 15}}, "You fix everything within a week and present the plan. They stay."], [1.0 - save, {"cash": -400, "remediate": client, "drop_client": client, "left_for": "gaps"}, "You fixed it, but too late. They signed with the other MSP."]]},
            {"label": "MATCH THEIR PRICE (-15% FOR 8 WEEKS)", "roll": [[0.7, {"discount_one": {"client": client, "mult": 0.85, "weeks": 8}, "mood": {key: 6}}, "They stay at the lower price. The gaps are still there."], [0.3, {"drop_client": client, "left_for": "gaps"}, "They leave anyway. Price was never the real problem."]]},
            {"label": "LET THEM GO", "fx": {"drop_client": client, "left_for": "gaps"}},
        ],
    }
    show_card("poach_gaps")


# ---- they come back when the cheap service disappoints; you decide the price ----------------------------------------
func _winback_week() -> void:
    for key in gone.keys():
        var info: Dictionary = gone[key]
        var away := Campaign.day - int(info.week)
        if away < 3 or _winback_queue.has(int(key)):
            continue
        var mood := int(info.mood)
        var chance := 0.0
        if str(info.reason) == "price":
            chance = 0.12 if mood >= 60 else (0.04 if mood >= 45 else 0.0)
        else:
            chance = 0.06 if mood >= 45 else 0.0
        chance = minf(0.35, chance + 0.04 * float(maxi(0, away - 5)))
        if randf() < chance:
            _winback_queue.append(int(key))


func _winback_card(client: int) -> void:
    if not gone.has(client) or Sales.active.has(client):
        gone.erase(client)
        return
    var info: Dictionary = gone[client]
    var name: String = Msp.CLIENTS[client].name
    var key := str(client)
    var why := "%s's cheaper service fell apart: tickets sat for days and nobody knew their network." % COMPETITOR
    if str(info.reason) != "price":
        why = "%s did not fix their problems either." % COMPETITOR
    var odds := 0.7 if int(info.mood) >= 60 else 0.5
    _dynamic["winback"] = {
        "speaker": "Vic Marlowe",
        "text": "%s called. %s They would like to come back." % [name, why],
        "options": [
            {"label": "WELCOME THEM BACK AT THEIR OLD PRICE", "fx": {"rejoin": client, "mood": {key: 10}, "rep": 1}, "text": "They are back, a little embarrassed. Everyone is happier."},
            {"label": "RAISE THEIR PRICE 15%", "roll": [[odds, {"rejoin": client, "fee_boost": {"client": client, "mult": 1.15}, "mood": {key: 4}}, "They grumble and agree: they now know what cheap costs."], [1.0 - odds, {"gone_clear": client}, "They shop around again and sign elsewhere."]]},
            {"label": "RAISE 15% AND PUT THE SCOPE IN WRITING", "roll": [[odds - 0.1, {"rejoin": client, "fee_boost": {"client": client, "mult": 1.15}, "scope": client, "mood": {key: 2}}, "Back at a higher price, with a clear scope this time."], [1.1 - odds, {"gone_clear": client}, "They decide it is more trouble than it is worth."]]},
            {"label": "NOT AGAIN, THANKS", "fx": {"gone_clear": client}, "text": "You wish them luck."},
        ],
    }
    show_card("winback")


func drop_random_client() -> void:
    if Sales.active.size() <= 3:
        return
    var pick: int = Sales.active[randi() % Sales.active.size()]
    Sales.active.erase(pick)
    discount.erase(pick)
    Msp.send_text("Vic", "We lost %s. Ouch." % Msp.CLIENTS[pick].name)


func _ransom() -> void:
    var t := Msp.create_problem(Story.RANSOM_CLIENT, Msp.RANSOM, "monitoring")
    if t.is_empty():
        for ep in Msp.endpoints:
            if ep.client == Story.RANSOM_CLIENT and ep.name.contains("SRV"):
                ep.problem = ""
        t = Msp.create_problem(Story.RANSOM_CLIENT, Msp.RANSOM, "monitoring")
    if t.is_empty():
        return
    _ransom_ticket = int(t.id)
    if not bool(Msp.backups[Story.RANSOM_CLIENT].ok):
        show_card("ransom_options")  # no backup: pay, shadow copies, or accept the loss
        return
    Msp.rmm_action(str(t.endpoint), "restore")
    Msp.close_ticket(int(t.id))
    Msp.send_text("Alan", "Hoot and Holler got hit by CryptoLocker. We restored from backup. No data lost!")


func _ransom_finish(kind: String) -> void:
    var t := Msp.ticket(_ransom_ticket)
    if t.is_empty():
        return
    if kind == "lost":
        Msp.rmm_action(str(t.endpoint), "restore")  # no backup: records the loss
        Msp.close_ticket(int(t.id))
        show_card("ransom_lost")
        return
    t.fix_done = true
    var ep := Msp.endpoint(str(t.endpoint))
    if not ep.is_empty():
        ep.problem = ""
    Msp.close_ticket(int(t.id))
    Story.flags["ransom"] = kind
    Msp.send_text("Alan", "Hoot and Holler: %s." % ("ransom paid, the files are back" if kind == "paid" else "we recovered most files from shadow copies"))


# ---- RDP open to the internet: a stolen login ----------------------------------------------------------------
func _rdp_week() -> void:
    if Campaign.day < 6 or flags.get("rdp_safe", false) or Sales.active.is_empty():
        return
    var chance := 0.04 if flags.get("rdp_weak", false) else 0.10
    if randf() >= chance:
        return
    var victim: int = Sales.active[randi() % Sales.active.size()]
    var cost := 1200 if flags.get("backup_service", false) else 2500
    apply({"cash": -cost, "mood": {str(victim): -12}, "rep": -3})
    Cards.ask(
        "Marge (Bookkeeper)",
        "A guessed remote-desktop password at %s let someone in. They used the server to send spam and poke around the files. Cleanup and a very unhappy client cost $%d." % [Msp.CLIENTS[victim].name, cost],
        OPTIONS_OK, func(_p: String) -> void: pass
    )


func _ask_leaving(client: int) -> void:
    var name: String = Msp.CLIENTS[client].name
    Cards.ask(
        "Vic Marlowe",
        "%s is unhappy and talking about leaving. We can offer a 20%% discount for 4 weeks to keep them." % name,
        [{"label": "OFFER THE DISCOUNT", "id": "keep"}, {"label": "LET THEM GO", "id": "go"}],
        func(pick: String) -> void: _leaving_answer(client, pick)
    )


func _leaving_answer(client: int, pick: String) -> void:
    if pick == "keep":
        discount[client] = {"mult": 0.8, "weeks": 4}
        Sales.adjust(client, 25)
    else:
        Sales.active.erase(client)
        discount.erase(client)
        Msp.send_text("Vic", "%s is gone." % Msp.CLIENTS[client].name)


# ---- the books ---------------------------------------------------------------------------------
func client_fee(client: int) -> int:
    var mult := float(fee_boost.get(client, 1.0))
    if discount.has(client):
        mult *= float(discount[client].mult)
    return int(float(FEE) * price * mult)


# ---- costs that grow with the company and the calendar (X1 balance) ----------------------------
# the techs ask for a raise at week 12; a new hire works for 60% of the wage while they learn the ropes
func wage_mult() -> float:
    return 1.05 if Campaign.day >= 12 else 1.0


func tech_wage() -> int:
    return int(round(float(WAGE) * wage_mult()))


func hire_wage(hire: Dictionary) -> int:
    var wage := int(round(float(hire.wage) * wage_mult()))
    if int(hire.get("age", 99)) < HIRE_RAMP_WEEKS:
        wage = int(round(float(wage) * 0.6))
    return wage


# rent (the lease escalates at weeks 9 and 14), liability insurance (week 12) and seats/licences/desks
# for every client past five
func overhead() -> int:
    var rent := RENT + (50 if Campaign.day >= 9 else 0) + (50 if Campaign.day >= 14 else 0)
    var insurance := 80 if Campaign.day >= 12 else 0
    var seats := maxi(0, Sales.active.size() - 5) * SEAT_COST
    return rent + insurance + seats


func weekly_estimate() -> Dictionary:
    var revenue := 0
    for c in Sales.active:
        revenue += client_fee(int(c))
    revenue = int(float(revenue) * (1.0 - leak)) + Projects.service_revenue()
    var payroll := tech_wage() * maxi(0, 3 - lost_techs) + int(VIC_PLANS[vic_plan].wage) + _commission_week
    for hire in extra_staff:
        payroll += hire_wage(hire)
    var fixed := overhead() + TOOLS + weekly_extra + stack_cost() + Projects.service_cost()
    var ebitda := revenue - payroll - fixed - marketing
    var rev := float(maxi(1, revenue))
    return {
        "revenue": revenue, "payroll": payroll, "fixed": fixed, "marketing": marketing, "ebitda": ebitda,
        "profit": ebitda, "margin": float(ebitda) / rev, "w2": float(payroll) / rev,
    }


# the average weekly EBITDA of the last four settled weeks (what a buyer looks at)
func ebitda_weekly() -> float:
    if history.is_empty():
        return float(weekly_estimate().ebitda)
    var total := 0.0
    var n := mini(4, history.size())
    for i in n:
        total += float(history[history.size() - 1 - i].ebitda)
    return total / float(n)


# a buyer pays a multiple of annual EBITDA; recurring revenue quality, margin and the W-2 ratio move it
func multiple() -> float:
    var est := weekly_estimate()
    var m := 4.0
    if float(est.w2) <= W2_TARGET:
        m += 1.0
    if float(est.margin) >= PEER_MARGIN:
        m += 1.0
    if Sales.active.size() >= 6:
        m += 0.5
    if Campaign.rep >= 70:
        m += 0.5
    if oml() >= 4:
        m += 0.5  # an optimizing, innovating company is worth more
    # a buyer discounts unhappy clients, a poor name and slow collections
    if Sales.average() < 35.0:
        m -= 2.0
    elif Sales.average() < 50.0:
        m -= 1.0
    if Campaign.rep < 30:
        m -= 0.5
    if ar_total() > int(float(est.revenue) * 3.0):
        m -= 0.5
    return maxf(2.0, m)


# end of the week: pay the bills, collect the fees, check who is leaving
func settle() -> Dictionary:
    var est := weekly_estimate()
    Projects.week()  # payouts land before the books are added up, so profit and EBITDA agree
    var profit: int = int(est.ebitda) + income_extra
    # invoices: on-time clients pay now, slow payers join the receivables and pay weeks later
    var collected := 0
    for inv in ar.duplicate():
        inv.age = int(inv.age) + 1
        if int(inv.age) >= int(inv.delay):
            collected += int(inv.amount)
            ar.erase(inv)
    for c in Sales.active:
        # the billing leak is money you never invoiced: cash and reported revenue agree
        var fee := int(float(client_fee(int(c))) * (1.0 - leak))
        var delay := pay_delay(int(c))
        if delay <= 0:
            collected += fee
        else:
            ar.append({"client": int(c), "amount": fee, "age": 0, "delay": delay})
    collected += Projects.service_revenue()  # managed services are billed with the monthly fee
    for inv in ar:
        var who := int(inv.client)
        if int(inv.age) >= 2 and int(inv.delay) >= 3 and not _late.has(who) and Campaign.day - int(_asked.get(who, -99)) >= 4:
            _late.append(who)
            _asked[who] = Campaign.day
    # the commission was already paid when the deals closed
    cash += collected - (int(est.payroll) - _commission_week) - int(est.fixed) - int(est.marketing)
    _commission_week = 0
    # what each client really cost you this week
    for c in Sales.active:
        var spent := int(float(client_work.get(int(c), 0.0)) * COST_PER_SEC)
        var hist: Array = profit_hist.get(int(c), [])
        hist.append(client_fee(int(c)) - spent)
        while hist.size() > 4:
            hist.pop_front()
        profit_hist[int(c)] = hist
    var used := 0.0
    for spent_seconds in client_work.values():
        used += float(spent_seconds)
    _patching(maxf(0.0, team_speed() * 240.0 - used))
    Projects.record_week()
    client_work = {}
    _burnout_week()
    _rdp_week()
    _poach_week()
    _staff_week()
    var hours_row: Array = Growth.owner_week()
    if randf() < 0.12 + float(marketing) / 2500.0:
        _leads += 1
    for c in discount.keys():
        discount[c].weeks = int(discount[c].weeks) - 1
        if int(discount[c].weeks) <= 0:
            discount.erase(c)
    # premium prices wear clients down, volume pricing makes them happier
    var drift := -4 if price >= 1.15 else (2 if price <= 0.9 else 0)
    for c in Sales.active:
        Sales.adjust(int(c), drift)
        if Sales.mood(int(c)) < 35 and randf() < 0.6 and not _leaving.has(c):
            _leaving.append(c)
    var grade := "D"
    for entry in [[1500, "S"], [700, "A"], [0, "B"], [-1000, "C"]]:
        if profit >= int(entry[0]):
            grade = str(entry[1])
            break
    var red := Color("ff8a80")
    var green := Color("8fe3a0")
    var margin := 100.0 * float(profit) / float(maxi(1, int(est.revenue)))
    var rows := [
        ["REVENUE", "$%d" % int(est.revenue), green],
        ["PAYROLL (W-2)", "-$%d" % int(est.payroll), Color.WHITE],
        ["OTHER COSTS + MARKETING", "-$%d" % (int(est.fixed) + int(est.marketing)), Color.WHITE],
        ["JOBS AND DEALS", "%s$%d" % ["+" if income_extra >= 0 else "-", absi(income_extra)], green if income_extra >= 0 else red],
        ["EBITDA", "%s$%d" % ["" if profit >= 0 else "-", absi(profit)], green if profit >= 0 else red],
        ["EBITDA MARGIN", "%d%% (PEERS %d%%)" % [int(margin), int(100.0 * PEER_MARGIN)], green if margin >= 100.0 * PEER_MARGIN else Color.WHITE],
        ["W-2 RATIO", "%d%% (TARGET %d%%)" % [int(100.0 * float(est.w2)), int(100.0 * W2_TARGET)], green if float(est.w2) <= W2_TARGET else red],
        ["CASH", "$%d" % cash, green if cash >= 0 else red],
        ["CLIENTS, A/R OWED", "%d (%d%%), $%d" % [Sales.active.size(), int(Sales.average()), ar_total()], Color("ffd27a") if ar_total() > 0 else Color.WHITE],
    ]
    rows.append(hours_row)
    rows.append(["RECURRING + PROJECTS", "$%d/WK + $%d JOBS" % [int(est.revenue), Projects.week_income], Color("8fe3a0")])
    rows.append(["VALUE (ESTIMATE)", "$%d, %s" % [valuation(), path_label()], Color("ffd27a")])
    history.append({"day": Campaign.day, "profit": profit, "ebitda": profit - Projects.take_week_income(), "cash": cash})
    return {
        "rows": rows, "title": "WEEK %d OF %d COMPLETE" % [Campaign.day, Campaign.TOTAL_DAYS], "grade": grade,
        "profit": profit, "bankrupt": cash < BANKRUPT,
    }


# what kind of company you are building, from how it looks right now
func path_label() -> String:
    var est := weekly_estimate()
    if Sales.active.size() >= 7:
        return "A GROWTH COMPANY"
    if float(est.margin) >= PEER_MARGIN:
        return "A PROFIT COMPANY"
    if flags.get("peer_group", false) or flags.get("mentor", false) or flags.get("backup_service", false):
        return "A SAFE PAIR OF HANDS"
    return "JUST SURVIVING"


func at_risk_count() -> int:
    var n := 0
    for c in Sales.active:
        n += 1 if poach_risk(int(c)) >= 0.12 else 0
    return n


# ---- the board review at the end ----------------------------------------------------------
# a buyer pays for the earnings AND the name: a poor reputation cuts the price (40% at worst)
func quality() -> float:
    return clampf(0.4 + float(Campaign.rep) / 150.0, 0.4, 1.0)


func valuation() -> int:
    return maxi(0, int(ebitda_weekly() * 52.0 * multiple() * quality()) + cash)


func offers() -> Array:
    var out := [{
        "id": "sell", "label": "SELL THE COMPANY FOR $%d" % valuation(),
        "desc": "A BIGGER MSP OFFERS $%d FOR THE CLIENT LIST, THE TEAM AND THE NAME." % valuation(),
    }]
    if cash >= 10000 and Campaign.rep >= 55 and Sales.active.size() >= 6:
        out.append({"id": "expand", "label": "OPEN A SECOND OFFICE", "desc": "YOU HAVE THE CASH, THE CLIENTS AND THE NAME TO GROW. MORE CLIENTS, MORE FIRES."})
    out.append({
        "id": "stay", "label": "STAY INDEPENDENT" if cash >= 0 else "STAY (BARELY AFLOAT)",
        "desc": "YOUR NAME STAYS ON THE DOOR." if cash >= 0 else "THE BANK IS NERVOUS BUT THE DOORS STAY OPEN.",
    })
    return out


func review_lines(page: int, ending: String) -> Array:
    var blue := Color("1f4e8c")
    var ink := Color("17121f")
    var good := Color("1f7a3a")
    var lines := []
    match page:
        0:
            var est := weekly_estimate()
            lines.append(["MARGE (BOOKKEEPER) - BOARD REVIEW", blue])
            lines.append(["TWENTY WEEKS DONE. HERE IS WHERE WE STAND.", ink])
            lines.append(["CASH $%d   WEEKLY EBITDA ABOUT $%d" % [cash, int(ebitda_weekly())], ink])
            lines.append(["EBITDA MARGIN %d%%   W-2 RATIO %d%%" % [int(100.0 * float(est.margin)), int(100.0 * float(est.w2))], ink])
            lines.append(["CLIENTS %d   CLIENT MOOD %d%%" % [Sales.active.size(), int(Sales.average())], ink])
            lines.append(["REPUTATION %d   STAFF %d" % [Campaign.rep, 4 + extra_staff.size() - lost_techs], ink])
            lines.append(["COMPANY VALUE: $%d (%.1fX EBITDA)" % [valuation(), multiple()], good])
            lines.append(["SALES: %d NEW CLIENTS, %d INSTALLS SOLD (%s)" % [Sales.deals, Sales.installs_sold, str(VIC_PLANS[vic_plan].label)], ink])
            lines.append(["STACK: %s, %s, %s" % [stack_option("psa").name, stack_option("rmm").name, stack_option("hardware").name], ink])
            lines.append(["A/R OWED $%d   MATURITY: %s" % [ar_total(), OML_NAMES[oml() - 1]], ink])
            lines.append(["RANSOMWARE: %s" % {"saved": "SAVED BY BACKUP", "lost": "NO BACKUP!", "paid": "PAID THE RANSOM", "partial": "PARTIAL RECOVERY"}.get(str(Story.flags.get("ransom", "")), "-"), ink])
        1:
            lines.append(["WHAT YOUR TEAM SAYS", blue])
            for who in Social.PEOPLE:
                lines.append(["%s (%s):" % [who.to_upper(), Social.mood(who)], blue])
                lines.append(["'%s'" % str(Review.QUOTES[Social.mood(who)]), ink])
        2:
            lines.append(["YOUR OPTIONS", blue])
        _:
            lines.append(["THE END", blue])
            match ending:
                "sell":
                    lines.append(["YOU SELL FOR $%d. THE BUYER KEEPS THE TEAM AND THE CLIENTS. YOU TAKE A VERY LONG VACATION." % valuation(), ink])
                "expand":
                    lines.append(["THE SECOND OFFICE OPENS NEXT MONTH. NEW CLIENTS, NEW TECHS, NEW FIRES. YOU WOULD NOT HAVE IT ANY OTHER WAY.", ink])
                _:
                    lines.append(["YOU KEEP YOUR NAME ON THE DOOR. SAME TEAM, SAME PHONES, ONE MORE YEAR OF TICKETS.", ink])
            lines.append(["TECH CAMPAIGN: PLAY IT FROM THE FLOOR.", good])
    return lines


func to_dict() -> Dictionary:
    return {
        "cash": cash, "flags": flags, "price": price, "speed": speed, "vic": vic_bonus, "weekly": weekly_extra,
        "lost": lost_techs, "staff": extra_staff, "discount": discount, "history": history, "leaving": _leaving,
        "marketing": marketing, "leads": _leads, "stack": stack, "ar": ar, "fee_boost": fee_boost,
        "vic_plan": vic_plan, "vic_deals": vic_deals, "vic_signed": vic_signed, "late": _late, "asked": _asked,
        "qbr": _qbr_done, "profit_hist": profit_hist, "scope_fixed": scope_fixed, "burnout": burnout, "leak": leak,
        "leak_found": leak_found, "risk_client": risk_client, "risk_choice": risk_choice, "goal": goal,
        "handover": _handover, "burn_warned": _burn_warned, "patch_debt": patch_debt, "gone": gone,
        "poach_queue": _poach_queue, "winback": _winback_queue, "poach_cool": _poach_cool, "poach_wave": _poach_wave,
    }


func from_dict(data: Dictionary) -> void:
    reset()
    if data.is_empty():
        return
    cash = int(data.get("cash", START_CASH))
    flags = data.get("flags", {})
    price = float(data.get("price", 1.0))
    speed = float(data.get("speed", 1.0))
    vic_bonus = float(data.get("vic", 0.0))
    weekly_extra = int(data.get("weekly", 0))
    lost_techs = int(data.get("lost", 0))
    extra_staff = data.get("staff", [])
    var saved: Dictionary = data.get("discount", {})
    for key in saved:
        discount[int(key)] = saved[key]
    history = data.get("history", [])
    _leaving = data.get("leaving", [])
    marketing = int(data.get("marketing", 0))
    _leads = int(data.get("leads", 0))
    stack = data.get("stack", DEFAULT_STACK.duplicate())
    ar = data.get("ar", [])
    var boosts: Dictionary = data.get("fee_boost", {})
    for key in boosts:
        fee_boost[int(key)] = float(boosts[key])
    vic_plan = str(data.get("vic_plan", "salary"))
    vic_deals = int(data.get("vic_deals", 0))
    vic_signed = data.get("vic_signed", [])
    _late = data.get("late", [])
    var asked: Dictionary = data.get("asked", {})
    for key in asked:
        _asked[int(key)] = int(asked[key])
    var reviews: Dictionary = data.get("qbr", {})
    for key in reviews:
        _qbr_done[int(key)] = int(reviews[key])
    var hist: Dictionary = data.get("profit_hist", {})
    for key in hist:
        profit_hist[int(key)] = hist[key]
    var fixed_scopes: Dictionary = data.get("scope_fixed", {})
    for key in fixed_scopes:
        scope_fixed[int(key)] = true
    burnout = float(data.get("burnout", 0.0))
    leak = float(data.get("leak", 0.0))
    leak_found = bool(data.get("leak_found", false))
    risk_client = int(data.get("risk_client", -1))
    risk_choice = str(data.get("risk_choice", ""))
    goal = data.get("goal", {})
    _handover = data.get("handover", [])
    _burn_warned = bool(data.get("burn_warned", false))
    var debts: Dictionary = data.get("patch_debt", {})
    for key in debts:
        patch_debt[int(key)] = float(debts[key])
    var lost: Dictionary = data.get("gone", {})
    for key in lost:
        gone[int(key)] = lost[key]
    _poach_queue = data.get("poach_queue", [])
    _winback_queue = data.get("winback", [])
    _poach_cool = int(data.get("poach_cool", 0))
    _poach_wave = int(data.get("poach_wave", 0))
''')

write("scripts/lync.gd", '''extends Node
# gdlint:disable=max-line-length
# Lynk 2013 on the desktop: presence (what your coworkers are doing, read from the cast simulation) and instant
# messages. Coworkers message you (lunch, "cover my phones", "how do you fix...", a thank-you) and you answer with quick
# (the owners, Alan and Garrison, ask owner things instead: MESSAGES keys like "phones_Alan" win over "phones")
# replies that move how they feel about you; you can message them (lunch?, need a hand, thanks) and ask the boss
# (Morgan in the tech campaign, Marge in the owner campaign). Friends warn you before a ticket breaches its SLA.
# Campaign only; in free play the app shows presence and nothing else happens.

signal changed

const COLORS := {"green": Color("3cc15a"), "amber": Color("e0a030"), "red": Color("d23c3c"), "grey": Color("8b93a1")}
const KIND_PRESENCE := {
    "meeting": ["IN A MEETING", "red"], "lunch": ["AWAY - LUNCH", "amber"], "coffee": ["AWAY", "amber"],
    "cooler": ["AWAY", "amber"], "bathroom": ["AWAY", "amber"], "news": ["BUSY", "red"], "leave": ["OFFLINE", "grey"],
}
const MESSAGES := {
    "lunch": {
        "text": "Lunch? A few of us are grabbing sandwiches.",
        "options": [
            {"label": "SURE, LET'S GO", "social": 2, "reply": "Great, see you there!"},
            {"label": "CAN'T, SWAMPED", "social": 0, "reply": "No worries, next time."},
        ],
    },
    "phones": {
        "text": "Can you cover my phones for ten minutes? I am stuck in a meeting.",
        "options": [
            {"label": "SURE", "social": 2, "reply": "Thanks, you are the best."},
            {"label": "SORRY, CAN'T", "social": -1, "reply": "Okay..."},
        ],
    },
    "help": {
        "text": "Quick one: how do you fix a print spooler that keeps stopping on Server 2008?",
        "options": [
            {"label": "WALK THEM THROUGH IT", "social": 2, "xp": 2, "reply": "That did it! Thanks."},
            {"label": "TOO BUSY RIGHT NOW", "social": -1, "reply": "Sure. No problem."},
        ],
    },
    "thanks": {"text": "Hey, thanks for being easy to work with.", "options": []},
    "lunch_Alan":
    {
        "text": "Lunch? I am ordering sandwiches for whoever is around. The company is paying, God help the books.",
        "options":
        [
            {"label": "SURE, LET'S GO", "social": 2, "reply": "Good. I ordered extra pickles."},
            {
                "label": "CAN'T, SWAMPED",
                "social": 0,
                "reply": "No worries. I will leave one in the fridge."
            },
        ],
    },
    "lunch_Garrison":
    {
        "text": "Lunch? I am taking the team out for sandwiches. Company card, I promise.",
        "options":
        [
            {"label": "SURE, LET'S GO", "social": 2, "reply": "Great, see you there!"},
            {
                "label": "CAN'T, SWAMPED",
                "social": 0,
                "reply": "No worries, next time. I will tell them you said hi."
            },
        ],
    },
    "phones_Alan":
    {
        "text": "Acme's office manager wants a call back and I am buried in vendor invoices. Can you ring them for me?",
        "options":
        [
            {"label": "SURE", "social": 2, "reply": "Thanks. That saves me twenty minutes."},
            {"label": "SORRY, CAN'T", "social": -1, "reply": "Okay... I will do it after the invoices."},
        ],
    },
    "phones_Garrison":
    {
        "text": "A client wants a call back and I am stuck in a prospect meeting. Can you ring them and say we are on it?",
        "options":
        [
            {"label": "SURE", "social": 2, "reply": "Thanks, you are the best."},
            {"label": "SORRY, CAN'T", "social": -1, "reply": "Okay... I will step out."},
        ],
    },
    "help_Alan":
    {
        "text": "The backup vendor wants us to renew. Can you look at their numbers and tell me if I am being sold something?",
        "options":
        [
            {
                "label": "TAKE A LOOK AT IT",
                "social": 2,
                "xp": 2,
                "reply": "That did it! Thanks. I will push back on the price."
            },
            {
                "label": "TOO BUSY RIGHT NOW",
                "social": -1,
                "reply": "Sure. No problem. I will read the fine print myself."
            },
        ],
    },
    "help_Garrison":
    {
        "text": "I have a QBR with Brightside on Thursday. Can you join and answer the technical questions?",
        "options":
        [
            {
                "label": "JOIN THE QBR",
                "social": 2,
                "xp": 2,
                "reply": "Perfect, thank you! I do the charm, you do the facts."
            },
            {
                "label": "TOO BUSY RIGHT NOW",
                "social": -1,
                "reply": "Sure. No problem. I will fake the technical parts."
            },
        ],
    },
    "thanks_Alan":
    {
        "text": "Thanks for covering the floor lately. The clients notice, and so do the books.",
        "options": [],
    },
    "thanks_Garrison":
    {
        "text": "Thanks for being great with the clients. They keep mentioning you.",
        "options": [],
    },
}

var chats := {}  # who -> [[from, text], ...]
var unread := {}
var pending := {}  # who -> the message waiting for your reply

var _t := 40.0
var _warn_t := 5.0
var _warned := {}
var _thanked := {}


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


func _ready() -> void:
    reset()


func reset() -> void:
    chats = {}
    unread = {}
    pending = {}
    _t = 40.0
    _warn_t = 5.0
    _warned = {}
    _thanked = {}


func color_of(key: String) -> Color:
    return COLORS.get(key, Color("8b93a1"))


func boss() -> String:
    return "Marge" if Campaign.mode == "owner" else "Morgan"


func contacts() -> Array:
    var out: Array = Social.PEOPLE.duplicate()
    out.append(boss())
    return out


# [status text, colour name] from what the cast is doing right now
func presence(who: String) -> Array:
    if who == boss():
        return ["AVAILABLE", "green"]
    if not World.chars.has(who):
        return ["OFFLINE", "grey"]
    var st: Dictionary = World.chars[who]
    if st.scene == World.OUTSIDE:
        var sales: bool = World.CAST[who].get("role", "") == "sales"
        return ["WITH A CLIENT", "amber"] if (sales and World.clock < World.DAY_END) else ["OFFLINE", "grey"]
    var kind := str(st.legs[0].kind) if not st.legs.is_empty() else "work"
    return KIND_PRESENCE.get(kind, ["AVAILABLE", "green"])


func unread_total() -> int:
    var n := 0
    for who in unread:
        n += int(unread[who])
    return n


func mark_read(who: String) -> void:
    unread[who] = 0


func open_chat(who: String) -> void:
    mark_read(who)
    changed.emit()


func _push(who: String, from_name: String, text: String) -> void:
    var lines: Array = chats.get(who, [])
    lines.append([from_name, text])
    while lines.size() > 30:
        lines.pop_front()
    chats[who] = lines
    if from_name != "me":
        unread[who] = int(unread.get(who, 0)) + 1
    changed.emit()


func _process(delta: float) -> void:
    if not Campaign.active or Game.title_mode or World.time_scale <= 0.0:
        return
    var dt := delta * World.time_scale
    _t -= dt
    if _t <= 0.0:
        _t = randf_range(50.0, 100.0)
        incoming()
    _warn_t -= dt
    if _warn_t <= 0.0:
        _warn_t = 5.0
        friend_warning()


# a coworker messages you
func incoming(forced_kind := "") -> void:
    var pool := []
    for who in Social.PEOPLE:
        if presence(who)[0] == "AVAILABLE" and not pending.has(who):
            pool.append(who)
    if pool.is_empty() or pending.size() >= 2:
        return
    var who: String = pool[randi() % pool.size()]
    if forced_kind == "" and Social.is_cold(who) and randf() < 0.7:
        return
    var kind := forced_kind
    if kind == "":
        var lunch_time: bool = World.clock >= 11.4 and World.clock <= 12.4
        var roll := randf()
        if lunch_time and roll < 0.6:
            kind = "lunch"
        elif roll < 0.45:
            kind = "phones"
        elif roll < 0.8:
            kind = "help"
        else:
            kind = "thanks"
    var msg: Dictionary = MESSAGES[kind]
    if MESSAGES.has(kind + "_" + who):
        msg = MESSAGES[kind + "_" + who]
    if kind == "thanks" and Social.value(who) < 25 and forced_kind == "":
        return
    _push(who, who, str(msg.text))
    if not (msg.options as Array).is_empty():
        pending[who] = msg


func reply(who: String, index: int) -> void:
    if not pending.has(who):
        return
    var msg: Dictionary = pending[who]
    var opt: Dictionary = msg.options[clampi(index, 0, msg.options.size() - 1)]
    pending.erase(who)
    _push(who, "me", str(opt.label).capitalize())
    Social.change(who, int(opt.social))
    if opt.has("xp"):
        Skills.add_xp("people", int(opt.xp))
    _push(who, who, str(opt.reply))


# you message them: kind = lunch / help / thanks (advice / status for the boss)
func send_action(who: String, kind: String) -> String:
    if who == boss():
        return _boss_reply(who)
    var labels := {"lunch": "Lunch?", "help": "Got a minute? I could use a hand.", "thanks": "Thanks for the help earlier!"}
    _push(who, "me", str(labels.get(kind, "Hi")))
    var status := str(presence(who)[0])
    if status != "AVAILABLE":
        _push(who, who, "I am %s right now. Catch you later." % status.to_lower())
        return "away"
    match kind:
        "lunch":
            var accept: bool = Social.value(who) >= 25 or (Social.value(who) > -15 and randf() < 0.6)
            _push(who, who, "Sure, give me five minutes." if accept else "Not today, sorry.")
            if accept:
                Social.change(who, 2)
        "thanks":
            var now := Time.get_ticks_msec() / 1000.0
            if now - float(_thanked.get(who, -999.0)) > 60.0:
                Social.change(who, 1)
                _thanked[who] = now
            _push(who, who, "Anytime!")
        _:
            _lend_a_hand(who)
    return kind


func _lend_a_hand(who: String) -> void:
    var willing: bool = Social.value(who) >= 0 or randf() < 0.4
    var ticket := _helpable_ticket()
    var owner_voice := Social.is_owner(who)
    if not willing:
        _push(who, who, "Sorry, I am buried in the books today." if owner_voice else "Sorry, I am swamped.")
    elif ticket.is_empty():
        _push(who, who, "Nothing in your queue needs me. Looking good!")
    else:
        Msp.rmm_action(str(ticket.endpoint), str(ticket.fix))
        var done := "On it... done: #%d is fixed. You owe me one."
        if owner_voice:
            done = "Fine, I will look. Done: #%d is fixed. Do not make a habit of it."
        _push(who, who, done % int(ticket.id))
        Social.change(who, -1)


func _helpable_ticket() -> Dictionary:
    for t in Msp.open_tickets():
        if t.internal or t.fix_done or str(t.special) != "" or t.fix == "project" or t.fix == "network":
            continue
        return t
    return {}


func _boss_reply(who: String) -> String:
    _push(who, "me", "Any advice?" if who == "Morgan" else "How are we doing?")
    var text := "You are doing fine."
    if who == "Marge":
        var est: Dictionary = Owner.weekly_estimate()
        text = "Cash is $%d. We make about $%d a week before one-offs. Receivables are $%d." % [Owner.cash, int(est.ebitda), Owner.ar_total()]
    else:
        var unchecked := false
        for c in Sales.active:
            unchecked = unchecked or int(Msp.backups[int(c)].checked_day) != Campaign.day
        if unchecked:
            text = "Have you checked the client backups today?"
        elif Msp.open_tickets().size() >= 4:
            text = "The queue is getting long. Work the P1s first."
        elif Skills.ps_level < 2:
            text = "Try a PowerShell lesson between tickets. It pays off."
    _push(who, who, text)
    return "boss"


# a friend tells you before an SLA breach
func friend_warning() -> void:
    for t in Msp.open_tickets():
        if t.internal or _warned.has(int(t.id)) or t.breached or float(t.sla_left) > 40.0:
            continue
        for who in Social.PEOPLE:
            if Social.is_friendly(who) and presence(who)[0] == "AVAILABLE":
                _warned[int(t.id)] = true
                _push(who, who, "Heads up: #%d (%s) is about to breach its SLA." % [int(t.id), str(t.summary)])
                return
''')

write("scripts/nerds.gd", '''extends Node
# gdlint:disable=max-line-length
# LabRat Nerds: the community forum and IRC channel for LabRat users (a parody of the LabTech Geek community of the day).
#   FORUM: a few threads a day. Reading gives a little skill XP; answering (needs the skill level) gives more XP and karma.
#   IRC (#labratnerds): "call a friend". Ask the channel which fix a ticket needs, or what to do at the current job step.
#   Four nicks answer one by one; accuracy depends on the nick and on your karma; the troll may lead you astray.
#   Asking costs a little karma and has a cooldown, so you earn the right to ask by contributing on the forum.

signal changed

const NICKS := {
    "rodent_rick": {"acc": 0.85, "color": Color("5aa0e8")},
    "gnawer": {"acc": 0.75, "color": Color("3cc15a")},
    "PS_wizard": {"acc": 0.9, "color": Color("c585f0")},
    "old_hand": {"acc": 0.8, "color": Color("e0a030")},
    "xX_n00b_Xx": {"acc": 0.4, "color": Color("e07b22")},
    "trollbot": {"acc": 0.2, "color": Color("d23c3c")},
}
const JOKES := [
    "have you tried turning it off and on again?", "just reinstall windows lol", "blame the antivirus",
    "that is a PEBKAC, tell the user", "format c: fixes everything",
]
const THREADS := [
    {"title": "Print spooler keeps dying on 2008 R2", "skill": "servers", "level": 0},
    {"title": "Users locked out after bad passwords: GPO?", "skill": "security", "level": 0},
    {"title": "Disk full, where is all the temp junk?", "skill": "servers", "level": 0},
    {"title": "Blue screen 0x7B after a controller swap", "skill": "servers", "level": 1},
    {"title": "CryptoLocker: shadow copies, any luck?", "skill": "security", "level": 2},
    {"title": "Robocopy /MIR and NTFS permissions", "skill": "servers", "level": 2},
    {"title": "VLANs for voice and data on a cheap switch", "skill": "networking", "level": 2},
    {"title": "Stopping RDP brute force: what do you use?", "skill": "security", "level": 1},
    {"title": "Windows XP end of support: migration list?", "skill": "servers", "level": 1},
    {"title": "Script to clean temp files on every client", "skill": "servers", "level": 1},
]
const COOLDOWN := 45.0
const RANKS := [[40, "GURU"], [20, "REGULAR"], [8, "MEMBER"], [0, "LURKER"]]

var karma := 10
var threads: Array = []  # today's threads: {id, read, answered}
var channel: Array = []  # [nick, text]
var hint := {}  # {question, best, votes, total, pending}

var _last_ask := -999.0
var _lines: Array = []  # queued [delay, nick, text]
var _day := -1


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


func _ready() -> void:
    reset()


func reset() -> void:
    karma = 10
    threads = []
    channel = [["#labratnerds", "welcome. be nice, read the FAQ."]]
    hint = {}
    _last_ask = -999.0
    _lines = []
    _day = -1


func rank() -> String:
    for entry in RANKS:
        if karma >= int(entry[0]):
            return str(entry[1])
    return "LURKER"


# the nicks are likelier to be right the more you contribute
func accuracy_mult() -> float:
    return 0.8 + float(clampi(karma, 0, 40)) / 40.0 * 0.3


func ensure_threads() -> void:
    if Campaign.day == _day and not threads.is_empty():
        return
    _day = Campaign.day
    var ids := []
    for i in THREADS.size():
        ids.append(i)
    ids.shuffle()
    threads = []
    for i in 5:
        threads.append({"id": ids[i], "read": false, "answered": false})
    changed.emit()


func read_thread(index: int) -> void:
    ensure_threads()
    var th: Dictionary = threads[index]
    if th.read:
        return
    th.read = true
    Skills.add_xp(str(THREADS[int(th.id)].skill), 2)
    changed.emit()


func answer_thread(index: int) -> String:
    ensure_threads()
    var th: Dictionary = threads[index]
    if th.answered:
        return "ALREADY ANSWERED"
    var def: Dictionary = THREADS[int(th.id)]
    if Skills.level(str(def.skill)) < int(def.level):
        karma = maxi(0, karma - 1)
        changed.emit()
        return "YOU ARE NOT SURE ENOUGH TO ANSWER"
    th.answered = true
    th.read = true
    karma += 2
    Skills.add_xp(str(def.skill), 4)
    changed.emit()
    return "POSTED. +2 KARMA"


func cooldown_left() -> float:
    return maxf(0.0, COOLDOWN - (Time.get_ticks_msec() / 1000.0 - _last_ask))


func can_ask() -> bool:
    return cooldown_left() <= 0.0 and _lines.is_empty()


# ask the channel which option is best; returns the verdict (it fills in over a few seconds)
func ask(question: String, options: Array, best: int) -> Dictionary:
    if not can_ask() or options.is_empty():
        return {}
    _last_ask = Time.get_ticks_msec() / 1000.0
    channel.append(["you", question])
    if karma < 4:
        channel.append(["#labratnerds", "nobody answers a lurker who never posts. try the forum."])
        hint = {}
        changed.emit()
        return {"ignored": true}
    karma = maxi(0, karma - 1)
    var nicks: Array = NICKS.keys()
    nicks.shuffle()
    var votes := {}
    var total := 4
    for i in total:
        var nick: String = nicks[i]
        var right := randf() < minf(0.97, float(NICKS[nick].acc) * accuracy_mult())
        var pick := best
        if not right and options.size() > 1:
            pick = (best + 1 + randi() % (options.size() - 1)) % options.size()
        votes[pick] = int(votes.get(pick, 0)) + 1
        var text := "I would go with: " + str(options[pick]).to_lower()
        if nick == "trollbot" and randf() < 0.5:
            text = str(JOKES[randi() % JOKES.size()])
        _lines.append([1.2 + float(i) * 1.6, nick, text])
    var winner := best
    var most := -1
    for key in votes:
        if int(votes[key]) > most:
            most = int(votes[key])
            winner = int(key)
    hint = {"question": question, "best": str(options[winner]), "votes": most, "total": total, "pending": true, "winner": winner}
    changed.emit()
    return hint


# which fix does this ticket need? the channel's answer to "what should I run?"
func ask_ticket(t: Dictionary) -> Dictionary:
    if t.is_empty() or t.fix == "project" or t.fix == "network":
        channel.append(["#labratnerds", "that one is a job, not a one-click fix. ask about the job step."])
        changed.emit()
        return {}
    var correct := str(t.fix)
    if correct == "restore" and not bool(Msp.backups[int(t.client)].ok):
        correct = "shadow"  # no backup: the community says try shadow copies, do not pay
    var keys := [correct]
    var others := ["spooler", "password", "clear_temp", "reboot", "av", "adobe"]
    others.shuffle()
    for key in others:
        if keys.size() >= 4:
            break
        if key != correct:
            keys.append(key)
    keys.shuffle()
    var labels := []
    for key in keys:
        labels.append(str(Msp.FIXES[key]))
    return ask("#%d %s: what should I run?" % [int(t.id), str(t.summary)], labels, keys.find(correct))


# what next at the current step of a big job?
func ask_step() -> Dictionary:
    if not Playbook.is_active():
        channel.append(["#labratnerds", "you are not in the middle of a job. which ticket?"])
        changed.emit()
        return {}
    var step: Dictionary = Playbook.current_step()
    var labels := []
    var best := 0
    var best_pts := -1
    for i in step.choices.size():
        var ch: Dictionary = step.choices[i]
        labels.append(str(ch.label))
        if Playbook.lock_reason(ch) == "" and int(ch.pts) > best_pts:
            best_pts = int(ch.pts)
            best = i
    return ask("%s: what next?" % str(step.title), labels, best)


func _process(delta: float) -> void:
    if _lines.is_empty():
        return
    for line in _lines:
        line[0] = float(line[0]) - delta
    while not _lines.is_empty() and float(_lines[0][0]) <= 0.0:
        var line: Array = _lines.pop_front()
        channel.append([line[1], line[2]])
        while channel.size() > 14:
            channel.pop_front()
    if _lines.is_empty() and bool(hint.get("pending", false)):
        hint["pending"] = false
    changed.emit()


func to_dict() -> Dictionary:
    return {"karma": karma}


func from_dict(data: Dictionary) -> void:
    reset()
    karma = int(data.get("karma", 10))
''')

write("scripts/difficulty.gd", '''extends Node
# gdlint:disable=max-line-length
# One dial for the repeatable activities (printer, karaoke, bowling, escape room, dinner, nerf war):
# a tier (easy / normal / hard), a run seed, and a seeded random stream per system.
#
#   Difficulty.f("karaoke.gap")      a number from TABLE for the current tier
#   Difficulty.rng("karaoke")        the RandomNumberGenerator of one system (same seed = same draws)
#   Difficulty.seed_run(12345)       tests and "daily seed" runs: fixes the seed and restarts every stream
#
# TABLE is the only place the numbers live: [easy, normal, hard]. Normal is exactly today's behaviour.
# Fairness rule: every hard value stays beatable (windows stay open, timers stay long enough for a clean
# run); tests/difficulty.gd checks the karaoke windows against the note gap. Energy is not an input.
# The tier is remembered in user://mspsim_settings.cfg (title menu); the tier and run seed are saved in
# the campaign file (`difficulty` section; old saves load as normal with a fresh seed). Only the seed is
# saved, not the position inside each stream: a continued run restarts its streams from the seed.

const TIERS := ["easy", "normal", "hard"]
const LABELS := {"easy": "EASY", "normal": "NORMAL", "hard": "HARD"}
const SEED_MASK := 0xFFFFFF
const TABLE := {
    # karaoke: seconds between notes, perfect / good hit windows (a miss is a note older than the good window)
    "karaoke.gap": [0.95, 0.75, 0.55],
    "karaoke.perfect": [0.16, 0.12, 0.09],
    "karaoke.good": [0.36, 0.3, 0.24],
    # bowling: added to every opponent's skill (0.48-0.62 today), speed of the aim marker and the power bar
    "bowl.opp_skill": [-0.08, 0.0, 0.08],
    "bowl.aim_speed": [1.1, 1.5, 2.0],
    "bowl.power_speed": [0.9, 1.2, 1.6],
    # escape room: seconds on the clock, seconds a wrong code takes off (in the room)
    "escape.time": [150.0, 120.0, 105.0],
    "escape.wrong_penalty": [5.0, 10.0, 15.0],
    # dinner: how many of the three faces show their reaction (the others stay hidden for that round)
    "dinner.reveal": [3, 3, 2],
    # printer: marker speed x, green zone width x, number of test-page questions
    "printer.speed": [0.8, 1.0, 1.25],
    "printer.zone": [1.3, 1.0, 0.85],
    "printer.questions": [1, 2, 3],
    # printer: pulls in the jam chain (a torn scrap adds one, two clean pulls in a row take one off, 3 to 6)
    "printer.chain": [3, 3, 5],
    # nerf war: how long the coworkers wait between shots, x
    "nerf.gap": [1.35, 1.0, 0.7],
}

var tier := "normal"
var run_seed := 0
var settings_path := "user://mspsim_settings.cfg"

var _streams := {}
var _pinned := false  # seed_run() was called: the next new_run() keeps that seed


func _ready() -> void:
    if run_seed == 0:
        run_seed = _random_seed()


func _random_seed() -> int:
    var r := RandomNumberGenerator.new()
    r.randomize()
    return maxi(1, r.randi() & SEED_MASK)


# ---- tier ----------------------------------------------------------------------------------------
func tier_index() -> int:
    return maxi(0, TIERS.find(tier))


func set_tier(name: String) -> void:
    tier = name if name in TIERS else "normal"


func cycle_tier(step: int) -> String:
    set_tier(TIERS[(tier_index() + step + TIERS.size()) % TIERS.size()])
    return tier


func label() -> String:
    return str(LABELS.get(tier, "NORMAL"))


# the number for one key at the current tier (0 and an error for an unknown key)
func f(key: String) -> float:
    return float(at(key, tier))


func i(key: String) -> int:
    return int(at(key, tier))


func at(key: String, for_tier: String) -> Variant:
    if not TABLE.has(key):
        push_error("Difficulty: unknown key " + key)
        return 0.0
    return TABLE[key][maxi(0, TIERS.find(for_tier))]


# ---- seed and random streams -----------------------------------------------------------------------
func seed_text() -> String:
    return "%06X" % run_seed


# fix the run seed (tests, daily seed): every stream starts again from it
func seed_run(value: int) -> void:
    run_seed = maxi(1, value & SEED_MASK)
    _pinned = true
    _streams.clear()


# a fresh run (New Game): a new random seed unless seed_run() fixed one first
func new_run() -> void:
    if _pinned:
        _pinned = false
        _streams.clear()
        return
    run_seed = _random_seed()
    _streams.clear()


# one persistent generator per system: the same seed gives the same draws in the same order
func rng(stream: String) -> RandomNumberGenerator:
    if not _streams.has(stream):
        _streams[stream] = rng_for(stream, 0)
    return _streams[stream]


# an independent generator for (stream, salt), e.g. one per day or per setup
func rng_for(stream: String, salt: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = hash("%d:%s:%d" % [run_seed, stream, salt])
    return r


# Fisher-Yates with a stream (Array.shuffle() would use the global generator)
func shuffle(list: Array, stream: String) -> void:
    var r := rng(stream)
    for k in range(list.size() - 1, 0, -1):
        var j := r.randi_range(0, k)
        var tmp = list[k]
        list[k] = list[j]
        list[j] = tmp


func pick(list: Array, stream: String) -> Variant:
    return list[rng(stream).randi_range(0, list.size() - 1)]


# ---- campaign save ---------------------------------------------------------------------------------
func to_dict() -> Dictionary:
    return {"version": 1, "tier": tier, "seed": run_seed}


func from_dict(data: Dictionary) -> void:
    set_tier(str(data.get("tier", "normal")))
    var saved := int(data.get("seed", 0))
    _pinned = false
    _streams.clear()
    run_seed = saved if saved > 0 else _random_seed()


# ---- settings (the tier chosen on the title menu) ----------------------------------------------------
func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(settings_path) == OK:
        set_tier(str(cfg.get_value("difficulty", "tier", "normal")))


func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.load(settings_path)
    cfg.set_value("difficulty", "tier", tier)
    cfg.save(settings_path)
''')

write("scripts/shift.gd", '''extends Node
# gdlint:disable=max-line-length
# Hour management for the tech campaign. A tech's day is more than tickets: when you leave for
# work (traffic), whether you stay late, and the on-call pager all feed ENERGY (0-100).
#   - Every morning (from day 2) a commute card: leave early (safe, tiring), on time (a gamble) or sleep
#     in (rested, late). Arriving late means tickets already ticking, abandoned calls, a coworker covering
#     for you and a text from the boss.
#   - Weeks 2 and 4 you carry the pager: some nights a page wakes you (fix it, triage it, or ignore it).
#   - At closing with tickets open: go home, or stay 1-2 hours (paid, but it costs energy).
#   - Low energy slows RMM fixes and makes them fail more; rested (85+) is a small bonus.
# Only runs when `enabled` (the title menu turns it on), so older tests are unaffected.

signal changed

const START_ENERGY := 80
const DAY_DRAIN := 20.0  # energy lost over a full working day
const REST := 22  # energy a night of sleep gives back
const STAY_COST := 8  # per hour of overtime
const STAY_PAY := 50  # per hour of overtime
const ONCALL_PAY := 40  # per on-call day
const ONCALL_WEEKS := [1, 3]  # 0-based weeks (days 6-10 and 16-20)
const PAGE_CHANCE := 0.6
const COMMUTES := {
    "early": {"base": -45, "p": 0.10, "energy": -6},
    "ontime": {"base": -5, "p": 0.30, "energy": 0},
    "late": {"base": 20, "p": 0.60, "energy": 5},
}
const WEEK_TRAFFIC := {
    1: {"text": "THE HIGHWAY IS DOWN TO ONE LANE THIS WEEK.", "extra": 0.15},
    3: {"text": "FIRST SNOW OF THE YEAR. EVERYONE DRIVES LIKE IT IS THE END OF THE WORLD.", "extra": 0.20},
}
const REASONS := [
    "AN ACCIDENT ON THE HIGHWAY", "A STALLED TRUCK IN THE LEFT LANE", "A TRAIN SITTING ON THE CROSSING",
    "RAIN AND A FENDER BENDER", "ROAD WORK NOBODY WARNED YOU ABOUT",
]
const PAGES := [
    "the file server is almost out of disk space", "the nightly backup job failed", "the VPN is down for the remote staff",
    "the mail queue is stuck", "the domain controller stopped answering pings",
]

var enabled := false
var energy := float(START_ENERGY)
var late_min := 0  # today's arrival delay
var late_total := 0
var stays := 0
var stay_hours := 0.0  # today
var pages := 0
var pages_fixed := 0
var pages_ignored := 0
var last_note := ""

var _asked := false
var _stay_until := 0.0
var _warned := 0
var _oncall_pay := 0


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


func _ready() -> void:
    reset()


func reset() -> void:
    energy = float(START_ENERGY)
    late_min = 0
    late_total = 0
    stays = 0
    stay_hours = 0.0
    pages = 0
    pages_fixed = 0
    pages_ignored = 0
    last_note = ""
    _asked = false
    _stay_until = 0.0
    _warned = 0
    _oncall_pay = 0


func active() -> bool:
    return enabled and Campaign.active and Campaign.mode == "tech" and not Game.title_mode


func week_of(day: int) -> int:
    return (day - 1) / 5


func on_call(day: int) -> bool:
    return ONCALL_WEEKS.has(week_of(day))


func is_on_call() -> bool:
    return active() and on_call(Campaign.day)


func traffic_text(day: int) -> String:
    return str(WEEK_TRAFFIC.get(week_of(day), {}).get("text", ""))


func is_tired() -> bool:
    return active() and energy < 30.0


func slow_mult() -> float:
    if not active():
        return 1.0
    if energy >= 85.0:
        return 0.9
    return 1.0 + clampf((55.0 - energy) / 55.0, 0.0, 1.0) * 0.5


func fail_add() -> float:
    if not active():
        return 0.0
    if energy >= 85.0:
        return -0.03
    return clampf((45.0 - energy) / 45.0, 0.0, 1.0) * 0.18


func add_energy(amount: float) -> void:
    energy = clampf(energy + amount, 0.0, 100.0)
    changed.emit()


func label() -> String:
    if energy >= 70.0:
        return "RESTED" if energy >= 85.0 else "FINE"
    if energy >= 45.0:
        return "TIRED"
    return "WORN OUT" if energy >= 25.0 else "EXHAUSTED"


# ---- the morning ------------------------------------------------------------------------------
func begin_day(day: int) -> void:
    late_min = 0
    stay_hours = 0.0
    _asked = false
    _stay_until = 0.0
    _warned = 0
    _oncall_pay = ONCALL_PAY if on_call(day) else 0
    last_note = ""
    if not active():
        return
    if day > 1:
        energy = minf(100.0, energy + float(REST))
    if day <= 1:
        return
    if Expo.is_trip_day(day):
        return
    World.time_scale = 0.0
    if on_call(day - 1) and randf() < PAGE_CHANCE:
        _page_card()
    else:
        commute_card()


func _page_card() -> void:
    var client := Sales.pick_client()
    var what: String = PAGES[randi() % PAGES.size()]
    pages += 1
    var text := "2:10 AM. THE PAGER GOES OFF. %s: %s." % [str(Msp.CLIENTS[client].name).to_upper(), what.to_upper()]
    Cards.ask("PAGER", text, [
        {"label": "GET UP AND FIX IT REMOTELY", "id": "fix"},
        {"label": "CHECK THE ALERT, THEN DECIDE", "id": "triage"},
        {"label": "IGNORE IT, GO BACK TO SLEEP", "id": "ignore"},
    ], func(id: String) -> void: _page_result(id, client, what))


func _page_result(id: String, client: int, what: String) -> void:
    var cname: String = Msp.CLIENTS[client].name
    match id:
        "fix":
            add_energy(-6.0 if Skills.ps_level >= 3 else -10.0)
            if randf() < 0.9 + 0.02 * float(Skills.ps_level):
                pages_fixed += 1
                Sales.adjust(client, 4)
                Msp.score += 3
                last_note = "FIXED THE PAGE AT 2 AM."
                Msp.send_text("Boss", "%s noticed you caught their problem at 2 AM. Good catch." % cname)
            else:
                add_energy(-3.0)
                Sales.adjust(client, -2)
                last_note = "A HALF-ASLEEP TYPO MADE IT WORSE."
                Msp.send_text("Boss", "%s says last night's fix made things worse." % cname)
        "triage":
            var noise := clampf(0.4 + 0.08 * float(Skills.level("networking")), 0.4, 0.75)
            if randf() < noise:
                add_energy(-2.0)
                last_note = "FALSE ALARM."
            else:
                add_energy(-8.0)
                pages_fixed += 1
                Sales.adjust(client, 2)
                last_note = "REAL, AND YOU FIXED IT."
        _:
            pages_ignored += 1
            if randf() < 0.55:
                Sales.adjust(client, -6)
                Campaign.adjust_rep(-2)
                last_note = "THE PAGE WAS REAL. THEY CALLED THE BOSS."
                Msp.send_text("Boss", "The pager went off and nobody answered. %s called me at 7 AM. %s." % [cname, what.capitalize()])
            else:
                last_note = "IT RESOLVED ITSELF."
    commute_card()


func commute_card() -> void:
    var extra := traffic_text(Campaign.day)
    var text := "DAY %d, 6:45 AM. THE ALARM IS GOING OFF. %s WHEN DO YOU LEAVE?" % [Campaign.day, extra]
    if last_note != "":
        text = last_note + " " + text
    Cards.ask("MORNING", text, [
        {"label": "LEAVE AT 7:30. EARLY AND TIRED", "id": "early"},
        {"label": "LEAVE AT 8:00. A GAMBLE", "id": "ontime"},
        {"label": "SLEEP IN. LEAVE AT 8:30 (LATE, TICKETS WAIT)", "id": "late"},
    ], func(id: String) -> void: commute(id))


func commute(choice: String) -> void:
    var c: Dictionary = COMMUTES[choice]
    var extra: float = float(WEEK_TRAFFIC.get(week_of(Campaign.day), {}).get("extra", 0.0))
    var traffic := randf() < float(c.p) + extra
    var delay := int(c.base)
    var reason := ""
    if traffic:
        delay += randi_range(15, 60)
        reason = REASONS[randi() % REASONS.size()]
        add_energy(-3.0)
    late_min = maxi(0, delay)
    add_energy(float(c.energy))
    if late_min >= 10:
        late_total += 1
    var waiting := _arrive(reason)
    World.time_scale = 1.0
    Hints.toast(_arrival_text(delay, waiting), 6.0)
    changed.emit()


# the line shown right after the commute card: how it went
func _arrival_text(delay: int, waiting: int) -> String:
    if late_min >= 10:
        return (
            "YOU ARRIVE %d MIN LATE. %d TICKET%s WAITING."
            % [late_min, waiting, "" if waiting == 1 else "S"]
        )
    if delay < 0:
        return "YOU ARRIVE %d MIN EARLY. COFFEE FIRST." % -delay
    return "YOU ARRIVE ON TIME."


# returns how many tickets were already waiting when you got in
func _arrive(reason: String) -> int:
    var waiting := 0
    if late_min >= 10:
        var sorry := "You arrive %d minutes late" % late_min
        Msp.send_text("Commute", sorry + (": " + reason.capitalize() + "." if reason != "" else "."))
        for i in clampi(late_min / 15, 1, 3):
            var t: Dictionary = Msp._random_ticket("email")
            if not t.is_empty():
                waiting += 1
                t.sla_left = maxf(float(t.sla_total) * 0.5, float(t.sla_left) - float(late_min) * 1.25)
        for i in late_min / 12:
            Sales.adjust(Sales.pick_client(), -2)
        if late_min >= 20:
            var who: String = ["Alan", "Garrison", "Dan"][randi() % 3]
            Social.change(who, -1)
            Lync._push(who, who, "Phones were backing up and I picked up. I would rather not. Please be on time.")
        if late_min >= 30:
            Msp.send_text("Boss", "Where are you? Clients are asking for you.")
    elif reason != "":
        Msp.send_text("Commute", "Traffic: %s. You left early enough. Phew." % reason.capitalize())
    return waiting


# ---- the day ---------------------------------------------------------------------------------
func _process(delta: float) -> void:
    if not active() or World.time_scale <= 0.0 or Cards.is_open:
        return
    var dt := delta * World.time_scale
    energy = maxf(0.0, energy - DAY_DRAIN * dt / maxf(60.0, World.day_len))
    if _warned < 1 and energy < 55.0:
        _warned = 1
        Msp.send_text("You", "You are getting tired. Fixes will start taking longer.")
    if _warned < 2 and energy < 35.0:
        _warned = 2
        Msp.send_text("You", "You are running on fumes. A mistake would be easy right now.")
    if _warned < 3 and energy < 20.0:
        _warned = 3
        Msp.send_text("Boss", "You look rough. Go home when you can.")


# Campaign asks this before ending the day. With tickets still open at closing it offers to stay late.
func can_end_day() -> bool:
    if not active():
        return true
    if Cards.is_open:
        return false
    if not _asked:
        _asked = true
        var open := Msp.open_tickets().size()
        if open > 0:
            Cards.ask("5:00 PM", "%d TICKET(S) ARE STILL OPEN AND THE OFFICE IS EMPTYING OUT. STAY AND FINISH THEM?" % open, [
                {"label": "GO HOME", "id": "home"},
                {"label": "STAY 1 HOUR (+$%d, -%d ENERGY)" % [STAY_PAY, STAY_COST], "id": "1"},
                {"label": "STAY 2 HOURS (+$%d, -%d ENERGY)" % [STAY_PAY * 2, STAY_COST * 2], "id": "2"},
            ], func(id: String) -> void: stay(id))
            return false
    return World.clock >= _stay_until


# an outing took the evening: no offer to stay late
func skip_stay() -> void:
    _asked = true


func stay(id: String) -> void:
    if id == "home":
        return
    var hours := float(int(id))
    stay_hours = hours
    stays += 1
    _stay_until = World.DAY_END + hours
    add_energy(-float(STAY_COST) * hours)


# ---- the report -------------------------------------------------------------------------------
func pay_extra() -> int:
    return (int(stay_hours * float(STAY_PAY)) + _oncall_pay) if active() else 0


func oncall_pay() -> int:
    return _oncall_pay if active() else 0


func rep_delta() -> int:
    return -1 if active() and late_min >= 30 else 0


# called as the day is closed: exhaustion makes you short with your coworkers
func close_day() -> void:
    if active() and energy < 25.0:
        Social.change_all(-1)


func summary() -> String:
    return "LATE %d   PAGES %d (FIXED %d)   LATE NIGHTS %d" % [late_total, pages, pages_fixed, stays]


func to_dict() -> Dictionary:
    return {
        "energy": energy, "late": late_total, "stays": stays, "pages": pages, "fixed": pages_fixed, "ignored": pages_ignored,
    }


func from_dict(data: Dictionary) -> void:
    reset()
    energy = float(data.get("energy", START_ENERGY))
    late_total = int(data.get("late", 0))
    stays = int(data.get("stays", 0))
    pages = int(data.get("pages", 0))
    pages_fixed = int(data.get("fixed", 0))
    pages_ignored = int(data.get("ignored", 0))
''')

write("scripts/growth.gd", '''extends Node
# gdlint:disable=max-line-length
# Grow a Tier 1 into a Tier 2 (from the Empath MSP training ideas). The one-page plan as a mechanic:
#   1. a GAP LIST (what the shop cannot do: low skill levels plus the escalations: SLA breaches and reopens)
#   2. pick ONE skill, assign a learner and a HELPER who catches mistakes
#   3. protect 30 paid minutes a week (if the queue eats it, the training moves into the ticket flow and
#      you learn less, and a crew that never gets training burns out)
#   4. stretch assignments: a Tier 2 ticket with someone close enough to catch you
#   5. the measurable result: escalations drop; at 100% you are Tier 2 in that skill.
# Tech campaign: YOU are the learner (Morgan runs the plan on days 6, 7, 8, 12, 13, 17, 18).
# Owner campaign: you choose who is developed. Hard escalations land on the owner's desk (the only
# Tier 3): a weekly pool of OWNER HOURS that escalations eat; when it runs dry, sales and marketing suffer.

const SKILLS := ["servers", "security", "networking", "powershell"]
const OWNER_HOURS := 40.0
const ADMIN_HOURS := 12.0
const ESC_HOURS := 1.5
const ESC_CHANCE := 0.10  # share of closed tickets that need the owner
const STRETCH := {
    "servers": "A file server will not mount a share after a patch Tuesday",
    "security": "A user's mailbox is sending spam and nobody knows how",
    "networking": "Two buildings are on the same subnet and nobody knows why",
    "powershell": "Fifty mailboxes need a setting changed and the GUI will take all day",
}

var focus := ""
var helper := ""  # tech: the coworker (or owner: Alan, Garrison) who catches your mistakes
var learner := ""  # owner: the tech being developed
var progress := 0.0
var graduated := false
var blocks_taken := 0
var blocks_skipped := 0
var stretch_ok := 0
var stretch_caught := 0
var stretch_slipped := 0
var tier2 := 0  # owner: how many techs have grown into Tier 2
var promoted: Array = []  # owner: who graduated
var esc := {}  # period -> escalations
var esc_skill := {}  # skill -> escalations
var owner_used := 0.0  # owner hours spent on escalations this week
var owner_warned := false
var _skip_note := false


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


func _ready() -> void:
    reset()


func reset() -> void:
    focus = ""
    helper = ""
    learner = ""
    progress = 0.0
    graduated = false
    blocks_taken = 0
    blocks_skipped = 0
    stretch_ok = 0
    stretch_caught = 0
    stretch_slipped = 0
    tier2 = 0
    promoted = []
    esc = {}
    esc_skill = {}
    owner_used = 0.0
    owner_warned = false
    _skip_note = false


func period() -> int:
    return Campaign.day if Campaign.mode == "owner" else (Campaign.day - 1) / 5


func esc_now() -> int:
    return int(esc.get(period(), 0))


func esc_before() -> int:
    return int(esc.get(period() - 1, 0))


func has_plan() -> bool:
    return focus != "" and (learner != "" or helper != "")


func focus_name() -> String:
    return str(Skills.NAMES.get(focus, focus)).to_upper()


# ---- the gap list ----------------------------------------------------------------------------
func note_escalation(t: Dictionary) -> void:
    if not Campaign.active or Campaign.mode != "tech" or t.get("internal", false):
        return
    var skill: String = Skills.FIX_XP.get(str(t.get("fix", "")), "servers")
    esc[period()] = esc_now() + 1
    esc_skill[skill] = int(esc_skill.get(skill, 0)) + 1


func gaps() -> Array:
    var out := []
    for skill in SKILLS:
        var level := Skills.level(skill)
        var count := int(esc_skill.get(skill, 0))
        out.append({"skill": skill, "level": level, "esc": count, "score": (5 - level) * 2 + count * 3})
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
    return out


# fixes get safer in the skill you are growing
func fail_adjust(action: String) -> float:
    if not Campaign.active or Campaign.mode != "tech" or focus == "" or progress <= 0.0:
        return 0.0
    var matches: bool = str(Skills.FIX_XP.get(action, "")) == focus or focus == "powershell" or focus == "networking"
    return -(0.08 if matches else 0.02) * progress / 100.0


func status_line() -> String:
    if focus == "":
        return ""
    if graduated and Campaign.mode == "tech":
        return "TIER 2 IN %s" % focus_name()
    if Campaign.mode == "owner":
        return "GROWTH: %s > %s %d%%" % [learner.to_upper(), focus_name(), int(progress)]
    return "GROWTH: %s %d%% (HELPER %s)  ESC %d (LAST %d)" % [focus_name(), int(progress), helper.to_upper(), esc_now(), esc_before()]


func _add_progress(amount: float, xp: int) -> void:
    progress = minf(100.0, progress + amount)
    if Campaign.mode == "tech":
        Skills.add_xp(focus, xp)
    if progress >= 100.0 and not graduated:
        graduated = true
        if Campaign.mode == "tech":
            _graduate_tech()
        else:
            _graduate_owner()
    Msp.changed.emit()


# ---- tech: you are the learner ----------------------------------------------------------------
func start_plan() -> void:
    if Campaign.mode != "tech" or focus != "":
        return
    var list := gaps()
    var text := "Time to grow you into a Tier 2. Your gap list, from your levels and the escalations: "
    var parts := []
    var options := []
    for i in 3:
        var g: Dictionary = list[i]
        parts.append("%s L%d (%d)" % [str(Skills.NAMES[g.skill]), int(g.level), int(g.esc)])
        options.append({"label": "%s: LEVEL %d, %d ESCALATIONS" % [str(Skills.NAMES[g.skill]), int(g.level), int(g.esc)], "id": str(g.skill)})
    Cards.ask("Morgan (Manager)", text + ", ".join(parts) + ". Pick ONE skill for the next month.", options, func(id: String) -> void: _pick_helper(id))


func _pick_helper(skill: String) -> void:
    var options := []
    for who in ["Alan", "Garrison", "Dan"]:
        options.append({"label": "%s (%s)" % [who.to_upper(), Social.mood(who)], "id": who})
    Cards.ask("Morgan (Manager)", "Who should be near you to catch your mistakes while you stretch? Alan and Garrison are the owners and their time is tight. Someone you get along with will say it kindly.", options, func(who: String) -> void: _plan_set(skill, who))


func _plan_set(skill: String, who: String) -> void:
    focus = skill
    helper = who
    progress = 0.0
    graduated = false
    Msp.send_text("Boss", "Plan set: %s with %s as your helper. 30 paid minutes a week, protected, and stretch tickets." % [focus_name(), who.to_upper()])
    Msp.mail(Story.MANAGER, "Your growth plan", "One skill: %s. Helper: %s. Thirty protected minutes a week on the board (I will ask). A stretch ticket now and then, with a safety net. The goal is fewer escalations, not heroics. - Morgan" % [focus_name(), who])
    Msp.changed.emit()


func offer_block() -> void:
    if Campaign.mode != "tech" or focus == "" or graduated:
        return
    var busy := Msp.open_tickets().size() > 3
    var options := [
        {"label": "TAKE THE 30 MINUTES", "id": "take", "enabled": not busy, "hint": "QUEUE IS FULL"},
        {"label": "SQUEEZE IT INTO THE TICKET FLOW", "id": "squeeze"},
        {"label": "SKIP THIS WEEK", "id": "skip"},
    ]
    var text := "Your protected 30 minutes for %s this week. The board is %s." % [focus_name(), "full" if busy else "quiet enough"]
    Cards.ask("Morgan (Manager)", text, options, func(id: String) -> void: block_result(id))


func block_result(id: String) -> void:
    match id:
        "take":
            blocks_taken += 1
            World.clock += 0.5
            for t in Msp.open_tickets():
                t.sla_left = float(t.sla_left) - 37.5  # the queue waits
            _add_progress(25.0, 12)
            Msp.send_text("Boss", "Good. Thirty minutes of real training on %s." % focus_name())
        "squeeze":
            blocks_taken += 1
            Shift.add_energy(-2.0)
            _add_progress(8.0, 4)
            Msp.send_text("Boss", "Learning between tickets is better than nothing, and tiring.")
        _:
            blocks_skipped += 1
            Shift.add_energy(-1.0)
            Msp.send_text("Boss", "Skipping protected time is how a help desk burns out. Think about it.")


func offer_stretch() -> void:
    if Campaign.mode != "tech" or focus == "" or graduated:
        return
    var text := "A Tier 2 ticket: %s. %s is at their desk and can catch you." % [str(STRETCH[focus]), helper.to_upper()]
    Cards.ask("Morgan (Manager)", text, [
        {"label": "TRY IT, %s WATCHES" % helper.to_upper(), "id": "try"},
        {"label": "ASK %s TO DO IT WHILE YOU WATCH" % helper.to_upper(), "id": "watch"},
        {"label": "ESCALATE IT BACK TO MORGAN", "id": "escalate"},
    ], func(id: String) -> void: stretch_result(id))


func success_chance() -> float:
    return clampf(0.30 + 0.13 * float(Skills.level(focus)) + (Shift.energy - 50.0) / 400.0 + progress / 400.0, 0.15, 0.9)


func stretch_result(id: String) -> void:
    match id:
        "try":
            if randf() < success_chance():
                stretch_ok += 1
                Social.change(helper, 2)
                Campaign.adjust_rep(1)
                Msp.score += 8
                Msp.send_text(helper, "Nice. I would not have thought of that. Solid.")
                _add_progress(30.0, 20)
            elif randf() < clampf(0.5 + float(Social.value(helper)) / 200.0, 0.3, 0.95):
                stretch_caught += 1
                Social.change(helper, 1)
                Msp.send_text(helper, "Stop, stop. That would have been a bad day. Do it like this.")
                _add_progress(15.0, 10)
            else:
                stretch_slipped += 1
                var client := Sales.pick_client()
                Sales.adjust(client, -6)
                Msp.score -= 5
                Story.queue_followup({"client": client, "summary": "Odd behavior since yesterday's change", "pri": 3, "body": "Hi %s, something looks wrong since the work yesterday. - Staff"})
                Msp.send_text("Boss", "Something you touched yesterday is acting up for %s. Learning curves have a cost." % str(Msp.CLIENTS[client].name))
                _add_progress(10.0, 6)
        "watch":
            Social.change(helper, 1)
            _add_progress(10.0, 8)
        _:
            esc[period()] = esc_now() + 1
            Msp.send_text("Boss", "Fine. I will take it. Next time, try.")


func _graduate_tech() -> void:
    var lv := Skills.level(focus)
    if focus == "powershell":
        Skills.ps_level = mini(5, Skills.ps_level + 1)
    elif lv < 5:
        Skills.xp[focus] = maxi(int(Skills.xp[focus]), int(Skills.XP_AT[lv]))
    Campaign.adjust_rep(3)
    Social.change(helper, 3)
    Msp.mail(Story.MANAGER, "Congratulations: Tier 2", "You can now handle %s tickets without a safety net, and the escalations show it. I am putting that in your file. - Morgan" % focus_name())
    Msp.send_text("Boss", "You are a Tier 2 in %s now. Well done." % focus_name())


# ---- owner: the only Tier 3 ---------------------------------------------------------------------
func owner_free() -> float:
    var used := owner_used + (8.0 if Owner.flags.get("owner_oncall", false) else 0.0)
    return maxf(0.0, OWNER_HOURS - ADMIN_HOURS - used)


# the owner buried in escalations has less time for sales
func vic_penalty() -> float:
    if Campaign.mode != "owner":
        return 0.0
    return clampf((10.0 - owner_free()) / 10.0, 0.0, 1.0) * 0.12


func marketing_factor() -> float:
    if Campaign.mode != "owner":
        return 1.0
    return clampf(owner_free() / 12.0, 0.5, 1.0)


func capacity_loss() -> float:
    return 0.02 if learner != "" and not graduated else 0.0


func owner_escalation(t: Dictionary) -> void:
    if Campaign.mode != "owner":
        return
    if randf() < ESC_CHANCE * (1.0 - 0.25 * float(mini(3, tier2))):
        owner_used += ESC_HOURS * (2.0 if int(t.pri) <= 2 else 1.0)
        esc[period()] = esc_now() + 1


# the Owner calls this while settling a week; it returns the report row
func owner_week() -> Array:
    var free_hours := owner_free()
    var row := ["OWNER HOURS", "%dH FREE, %d ESCALATIONS" % [int(free_hours), esc_now()], Color("8fe3a0") if free_hours >= 10.0 else Color("ff8a80")]
    if free_hours < 6.0 and not owner_warned:
        owner_warned = true
        _bottleneck_card()
    if learner != "" and not graduated:
        if Msp.open_tickets().size() > 5:
            blocks_skipped += 1
            Owner.burnout = clampf(Owner.burnout + 3.0, 0.0, 100.0)
            _add_progress(4.0, 0)
            if not _skip_note:
                _skip_note = true
                Msp.send_text("Alan", "The queue ate the training time again. That is how people end up burned out.")
        else:
            blocks_taken += 1
            _add_progress(18.0, 0)
    owner_used = 0.0
    return row


func _bottleneck_card() -> void:
    var options := [{"label": "KEEP DOING IT MYSELF", "id": "keep"}]
    if learner == "":
        options.push_front({"label": "START A GROWTH PLAN FOR THE TEAM", "id": "plan"})
    Cards.ask("Alan (Co-owner)", "Boss, you are the only Tier 3. Every hard ticket ends on your desk and nobody else learns the work while you do it. You have no time left for clients.", options, func(id: String) -> void: _bottleneck_pick(id))


func _bottleneck_pick(id: String) -> void:
    if id == "plan":
        owner_plan_card()


func owner_plan_card() -> void:
    if Campaign.mode != "owner" or learner != "":
        return
    var names := ["Garrison", "Dan"]
    for hire in Owner.extra_staff:
        names.append(str(hire.name))
    var options := []
    for who in names:
        options.append({"label": who.to_upper(), "id": who})
    Cards.ask("Alan (Co-owner)", "Opportunity shortage, not talent shortage. Who do we grow into a Tier 2? Thirty paid minutes a week, protected, a stretch ticket now and then, and I will be the helper.", options, func(who: String) -> void: _owner_skill(who))


func _owner_skill(who: String) -> void:
    var options := []
    for skill in ["servers", "security", "networking"]:
        options.append({"label": "%s (%d ESCALATIONS SO FAR)" % [str(Skills.NAMES[skill]), int(esc_skill.get(skill, 0))], "id": skill})
    Cards.ask("Alan (Co-owner)", "Which skill? Pick the one the shop keeps escalating.", options, func(skill: String) -> void: _owner_plan_set(who, skill))


func _owner_plan_set(who: String, skill: String) -> void:
    learner = who
    focus = skill
    progress = 0.0
    graduated = false
    _skip_note = false
    Msp.send_text("Alan", "%s will learn %s. Thirty protected minutes a week, and I will catch them." % [who, str(Skills.NAMES[skill])])
    Msp.changed.emit()


func owner_stretch() -> void:
    if Campaign.mode != "owner" or learner == "" or graduated:
        return
    var chance := clampf(0.40 + progress / 250.0, 0.2, 0.85)
    Cards.ask("Alan (Co-owner)", "A Tier 2 ticket just came in (%s). %s could take it, with me at the next desk." % [str(STRETCH[focus]).to_lower(), learner], [
        {"label": "STRETCH ASSIGNMENT (%d%%)" % int(chance * 100.0), "id": "stretch"},
        {"label": "THE SENIOR TAKES IT", "id": "senior"},
        {"label": "I WILL HANDLE IT (4 OWNER HOURS)", "id": "owner"},
    ], func(id: String) -> void: owner_stretch_result(id, chance))


func owner_stretch_result(id: String, chance: float) -> void:
    match id:
        "stretch":
            if randf() < chance:
                stretch_ok += 1
                Sales.adjust(Sales.pick_client(), 3)
                Msp.send_text("Alan", "%s nailed it. I barely had to say a word." % learner)
                _add_progress(30.0, 0)
            elif randf() < 0.6:
                stretch_caught += 1
                Msp.send_text("Alan", "I caught it before the client saw. %s learned something." % learner)
                _add_progress(14.0, 0)
            else:
                stretch_slipped += 1
                Sales.adjust(Sales.pick_client(), -6)
                Campaign.adjust_rep(-1)
                Msp.send_text("Alan", "%s broke something visible. The client noticed." % learner)
                _add_progress(10.0, 0)
        "senior":
            _add_progress(8.0, 0)
        _:
            owner_used += 4.0


func _graduate_owner() -> void:
    tier2 += 1
    promoted.append(learner)
    Owner.speed += 0.05
    Owner.flags["growth_done"] = true
    var who := learner
    Cards.ask("Alan (Co-owner)", "%s is a Tier 2 in %s now. Escalations to you will drop. They also know what that is worth on the market." % [who, focus_name()], [
        {"label": "GIVE A RAISE ($60/WEEK)", "id": "raise"},
        {"label": "NOT NOW", "id": "no"},
    ], func(id: String) -> void: _raise(id, who))


func _raise(id: String, who: String) -> void:
    if id == "raise":
        Owner.weekly_extra += 60
        Msp.send_text("Alan", "%s is staying. The raise helped." % who)
    elif randf() < 0.3:
        if Owner.lost_techs < 2:
            Owner.lost_techs += 1
        Msp.send_text("Alan", "%s took a job elsewhere. Trained staff leave when the pay does not follow." % who)
    learner = ""
    focus = ""
    progress = 0.0
    graduated = false


func board_lines() -> Array:
    var lines := []
    if Campaign.mode != "owner":
        return lines
    lines.append(["OWNER HOURS %dH FREE (%d ESC THIS WEEK)" % [int(owner_free()), esc_now()], Color("8fe3a0") if owner_free() >= 10.0 else Color("ff8a80")])
    if learner != "":
        lines.append(["GROWTH: %s > %s %d%%" % [learner.to_upper(), focus_name(), int(progress)], Color("6b421c")])
    elif tier2 > 0:
        lines.append(["TIER 2 TECHS: %d (%s)" % [tier2, ", ".join(promoted).to_upper()], Color("6b421c")])
    return lines


func to_dict() -> Dictionary:
    return {
        "focus": focus, "helper": helper, "learner": learner, "progress": progress, "graduated": graduated,
        "taken": blocks_taken, "skipped": blocks_skipped, "ok": stretch_ok, "caught": stretch_caught, "slipped": stretch_slipped,
        "tier2": tier2, "promoted": promoted, "esc": esc, "esc_skill": esc_skill, "warned": owner_warned,
    }


func from_dict(data: Dictionary) -> void:
    reset()
    focus = str(data.get("focus", ""))
    helper = str(data.get("helper", ""))
    learner = str(data.get("learner", ""))
    progress = float(data.get("progress", 0.0))
    graduated = bool(data.get("graduated", false))
    blocks_taken = int(data.get("taken", 0))
    blocks_skipped = int(data.get("skipped", 0))
    stretch_ok = int(data.get("ok", 0))
    stretch_caught = int(data.get("caught", 0))
    stretch_slipped = int(data.get("slipped", 0))
    tier2 = int(data.get("tier2", 0))
    promoted = data.get("promoted", [])
    owner_warned = bool(data.get("warned", false))
    var saved: Dictionary = data.get("esc", {})
    for key in saved:
        esc[int(key)] = int(saved[key])
    var saved_skill: Dictionary = data.get("esc_skill", {})
    for key in saved_skill:
        esc_skill[str(key)] = int(saved_skill[key])
''')

write("scripts/ui_style.gd", '''extends RefCounted
# gdlint:disable=max-line-length
# One look for every outing screen (the Outings intro / result panels, the in-room HUD strips, the caption
# bar and the printer game): a bordered panel with a blue header bar, a footer hint line, the same colours,
# the same text size (the 3x5 font at scale 1) and the same star row. All helpers draw on a CanvasItem
# in screen pixels. Use UiStyle.panel() for pages, UiStyle.strip() / hint_bar() / caption_bar() in rooms.

const PixelFont := preload("res://scripts/pixelfont.gd")
const INK := Color("17121f")
const WHITE := Color("ffffff")
const PANEL := Color("e9ecf1")
const HEAD := Color("1f4e8c")
const MUTED := Color("46506a")  # hint text on a light panel
const SOFT := Color("c9d2e0")  # hint text on a dark bar, empty bars
const DARK := Color(0.04, 0.03, 0.08, 0.86)  # HUD strips, hint bar and caption bar
const GOLD := Color("e0a030")
const GREEN := Color("2f9e4f")
const RED := Color("c0392b")
const HEAD_H := 9.0
const STRIP_H := 11.0  # one-line HUD strip
const HINT_H := 9.0  # the control hint line at the bottom of the screen in a room
const MARGIN := 4.0


static func text(c: CanvasItem, s: String, x: float, y: float, color := INK) -> void:
    PixelFont.draw(c, s, Vector2(x, y), color, 1)


static func center(c: CanvasItem, s: String, cx: float, y: float, color := INK) -> void:
    PixelFont.draw(c, s, Vector2(cx - float(PixelFont.width(s, 1)) * 0.5, y), color, 1)


static func right(c: CanvasItem, s: String, rx: float, y: float, color := INK) -> void:
    PixelFont.draw(c, s, Vector2(rx - float(PixelFont.width(s, 1)), y), color, 1)


static func wrap_text(s: String, chars: int) -> Array:
    var out := []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            out.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    out.append(line)
    return out


static func star(c: CanvasItem, ctr: Vector2, r: float, color: Color) -> void:
    var pts := PackedVector2Array()
    for i in 10:
        var ang := -PI * 0.5 + PI * float(i) / 5.0
        var rr := r if i % 2 == 0 else r * 0.45
        pts.append(ctr + Vector2(cos(ang), sin(ang)) * rr)
    c.draw_colored_polygon(pts, color)


# the result page's star row: same size and place everywhere (centre cx, 10 px below the body top)
static func stars(c: CanvasItem, cx: float, body_top: float, n: int) -> void:
    for i in 3:
        star(c, Vector2(cx - 24.0 + 24.0 * float(i), body_top + 10.0), 9.0, GOLD if i < n else SOFT)


# where a page panel sits: centred, below the status row at the top of the screen
static func panel_rect(size: Vector2, w: float, h: float) -> Rect2:
    var pw := minf(size.x - 8.0, w)
    var ph := minf(size.y - 14.0, h)
    return Rect2(floorf((size.x - pw) * 0.5), 14.0 + floorf((size.y - 14.0 - ph) * 0.5), pw, ph)


# a page: border, fill, header bar with the title (and a right-aligned note); returns the body rect
# (4 px margins, below the header, above the footer hint line)
static func panel(c: CanvasItem, r: Rect2, title: String, note := "", alpha := 1.0) -> Rect2:
    c.draw_rect(Rect2(r.position - Vector2.ONE, r.size + Vector2(2, 2)), Color(INK, minf(1.0, alpha + 0.1)))
    c.draw_rect(r, Color(PANEL, alpha))
    c.draw_rect(Rect2(r.position, Vector2(r.size.x, HEAD_H)), HEAD)
    text(c, title, r.position.x + 3.0, r.position.y + 2.0, WHITE)
    if note != "":
        right(c, note, r.end.x - 3.0, r.position.y + 2.0, Color("ffd6d0"))
    return Rect2(
        r.position.x + MARGIN, r.position.y + 12.0, r.size.x - 2.0 * MARGIN, r.size.y - 12.0 - 9.0
    )


# the footer hint line of a page
static func footer(c: CanvasItem, r: Rect2, hint: String) -> void:
    text(c, hint, r.position.x + 3.0, r.end.y - 7.0, MUTED)


# a one-line HUD strip: the same dark bar with a blue accent along its top; returns the text origin
static func strip(c: CanvasItem, r: Rect2) -> Vector2:
    c.draw_rect(r, DARK)
    c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), HEAD)
    return Vector2(r.position.x + 4.0, r.position.y + 3.0)


# a HUD box (the karaoke lanes, the keypad entry): same dark fill and accent as a strip
static func box(c: CanvasItem, r: Rect2) -> void:
    c.draw_rect(r, DARK)
    c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), HEAD)


# the control hint line at the very bottom of the screen in a room (same words as a page footer)
static func hint_bar(c: CanvasItem, size: Vector2, hint: String) -> void:
    var r := Rect2(0.0, size.y - HINT_H, size.x, HINT_H)
    c.draw_rect(r, Color(0.02, 0.02, 0.05, 0.92))
    text(c, hint, 4.0, r.position.y + 2.0, SOFT)


# the caption bar sits above the hint line; returns its top edge (the HUD strip goes above it)
static func caption_bar(c: CanvasItem, size: Vector2, cap: String) -> float:
    var top := size.y - HINT_H
    if cap == "":
        return top
    var lines := wrap_text(cap, int((size.x - 2.0 * MARGIN - 8.0) / 4.0))
    var h := float(lines.size()) * 7.0 + 4.0
    top -= h
    c.draw_rect(Rect2(0.0, top, size.x, h), DARK)
    c.draw_rect(Rect2(0.0, top, 2.0, h), GOLD)
    for i in lines.size():
        text(c, str(lines[i]), 6.0, top + 2.0 + float(i) * 7.0, WHITE)
    return top
''')

write("scripts/outings.gd", '''extends CanvasLayer
# gdlint:disable=max-line-length
# Team outings: four little mini-games the crew goes out for, if you choose to go.
#   BOWLING (timing: aim, then power), KARAOKE (rhythm: arrow keys), ESCAPE ROOM (a 3-digit code, bulls and cows,
#   teammates give hints), DINNER (conversation: learn what each person likes).
# Tech campaign: on days 5, 10 and 15 Garrison (the culture owner) asks at 16:00 (open tickets wait; you go home after). Owner campaign:
# weeks 4, 9, 14 and 19, and it costs money. Free Play: press O. Results (0-3 stars) change coworker opinions, energy
# (tech) and burnout (owner); skipping invitations costs a little goodwill. Everything is drawn in code.

signal finished(game: String, stars: int)

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const INK := UiStyle.INK
const WHITE := UiStyle.WHITE
const PANEL := UiStyle.PANEL
const BLUE := UiStyle.HEAD
const GREEN := UiStyle.GREEN
const RED := UiStyle.RED
const AMBER := UiStyle.GOLD
const GAMES := {
    "bowling": {"label": "BOWLING", "cost": 120, "blurb": "FIVE FRAMES AGAINST ALAN, GARRISON AND DAN. PRESS SPACE TO STOP THE AIM, THEN AGAIN TO SET THE POWER.", "keys": "SPACE = STOP AIM / POWER  ESC = LEAVE"},
    "karaoke": {"label": "KARAOKE", "cost": 180, "blurb": "HIT THE ARROWS AS THEY REACH THE LINE. NERVOUS? THE ROOM IS RIGHT THERE WITH YOU.", "keys": "ARROW KEYS = HIT NOTES  ESC = LEAVE"},
    "escape": {"label": "ESCAPE ROOM", "cost": 240, "blurb": "CRACK THE 3 DIGIT CODE IN TWO MINUTES. BULLS = RIGHT DIGIT, RIGHT PLACE. COWS = RIGHT DIGIT, WRONG PLACE. FRIENDS GIVE HINTS.", "keys": "ARROWS  ENTER = TRY  H = HINT  ESC = LEAVE"},
    "dinner": {"label": "DINNER", "cost": 300, "blurb": "FIVE ROUNDS OF TABLE TALK. EVERYONE LOVES SOMETHING AND DREADS SOMETHING. WATCH THEIR FACES AND REMEMBER.", "keys": "UP / DOWN  ENTER = TALK  ESC = LEAVE"},
}
const DINERS := ["Alan", "Garrison", "Dan"]
const LOVES := {"Alan": ["SPORTS", "FOOD"], "Garrison": ["MOVIES", "WEEKEND PLANS"], "Dan": ["KIDS AND PETS", "FOOD"]}
const HATES := {"Alan": "WORK DRAMA", "Garrison": "SPORTS", "Dan": "MOVIES"}
const TOPICS := ["WORK DRAMA", "SPORTS", "MOVIES", "FOOD", "KIDS AND PETS", "WEEKEND PLANS"]
const BOWL_SKILL := {"Alan": 0.62, "Garrison": 0.55, "Dan": 0.48}
const SEATS := {"dinner": {"Alan": "Seat1", "Garrison": "Seat3", "Dan": "Seat4", "Vic": "Seat5"}}
const PLAYER_SEAT := "Seat2"
const LANE_NEAR := [152.0, 252.0]
const LANE_FAR := [160.0, 244.0]
const MIC_X := 238.0
const ROOM_INTRO := {
    "bowling": "TAKE YOUR TURN ON THE LANE. PRESS E TO STEP UP, E TO STOP THE AIM, E AGAIN FOR POWER. ALAN, GARRISON AND DAN BOWL ON THE NEXT LANE. FIVE FRAMES.",
    "karaoke": "YOU ARE ON THE MIC. HIT THE ARROW KEYS AS THE NOTES REACH THE LINE (BOTTOM LEFT) WHILE THE ROOM WATCHES. STRING PERFECT HITS TOGETHER.",
    "escape": "THE CODE IS HIDDEN IN THE ROOM. LOOK AT THE CHALKBOARD, THE CLOCK AND THE PAINTING (E), THEN ENTER THE CODE AT THE KEYPAD BY THE VAULT. N ASKS A FRIEND. TWO MINUTES.",
    "dinner": "WALK TO THE BOOTH AND SIT NEXT TO ALAN (E). THEN CHOOSE FIVE TOPICS FOR THE TABLE AND WATCH THEIR FACES.",
}
const SONG_LEN := 24
const LANE_KEYS := [KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT]
const LANE_COLORS := [Color("e0463c"), Color("5fd068"), Color("5aa0e8"), Color("f5d442")]
const ESCAPE_TIME := 120.0
const ROOMS := {"bowling": "bowling_alley", "karaoke": "karaoke_bar", "escape": "escape_room", "dinner": "restaurant"}
# where Alan, Garrison, Dan, Vic and Maya stand in each room (set-pixel x); a fifth spot keeps
# Maya from wrapping onto Alan's
const SPOTS := {
    "bowling": [114, 186, 214, 250, 140], "karaoke": [236, 262, 282, 130, 160],
    "escape": [118, 175, 205, 305, 325],  # clear of the clue zones (clock 86, painting 149, board 238, keypad 276)
    "dinner": [34, 62, 106, 140, 175],
}
const TECH_DAYS := [5, 10, 15]
const OWNER_WEEKS := [4, 9, 14, 19]

var enabled := false
var use_rooms := false  # go to the real room (title menu turns this on)
var is_open := false
var game := ""
var phase := "intro"  # intro, play, result
var g := {}
var stars := 0
var lines: Array = []  # the result page
var count := 0
var skipped := 0
var best := {}
var known := {}  # dinner: who likes / dreads what, learned over time

var _canvas: Node2D
var _prev_scale := 1.0
var _from_invite := false
var _peek := false  # TAB hides the panel so you can look at the room
var _wait_id := ""  # travelling to the room
var _traveled := false
var _return_scene := ""
var _return_x := -1.0
var _caption := ""
var _caption_t := 0.0
var _marks := {}  # speech bubbles to hide: node -> seconds left
var _offered := false


func _ready() -> void:
    layer = 66
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)
    Campaign.day_started.connect(func(_d: int) -> void: _offered = false)
    reset()


func reset() -> void:
    count = 0
    skipped = 0
    best = {}
    known = {}
    _offered = false


func to_dict() -> Dictionary:
    return {"count": count, "skipped": skipped, "best": best, "known": known}


func from_dict(data: Dictionary) -> void:
    reset()
    count = int(data.get("count", 0))
    skipped = int(data.get("skipped", 0))
    best = data.get("best", {})
    known = data.get("known", {})


# ---- invitations ------------------------------------------------------------------------------
# a game is open, or we are on the way to its room
func busy() -> bool:
    return is_open or _wait_id != ""


func invite_day() -> bool:
    if not Campaign.active:
        return false
    if Campaign.mode == "owner":
        return OWNER_WEEKS.has(Campaign.day)
    return TECH_DAYS.has(Campaign.day)


# the day waits for the invitation (a trip may have brought you home after five)
func invite_due() -> bool:
    return enabled and not _offered and invite_day() and not Story.overtime and not Game.title_mode


func maybe_invite() -> void:
    if not enabled or _offered or is_open or Cards.is_open or Game.title_mode or not invite_day():
        return
    if World.time_scale <= 0.0 or World.clock < 16.0 or Story.overtime:
        return
    _offered = true
    var text := "The crew is heading out after work and I would like you there. Come with us? The open tickets will still be here in the morning."
    if Campaign.mode == "owner":
        text = "The crew has been grinding for weeks. A team night would be noticed. It costs %s depending on the game." % cost_range()
    Cards.ask(_host(), text, [
        {"label": "YES, LET US GO", "id": "yes"},
        {"label": "NOT TONIGHT", "id": "no"},
    ], func(id: String) -> void: _invite_answer(id))


# the owner pays for the night: "$120 TO $300" (shown on the invitation before the game pick)
func cost_range() -> String:
    var lo := 100000
    var hi := 0
    for id in GAMES:
        lo = mini(lo, int(GAMES[id].cost))
        hi = maxi(hi, int(GAMES[id].cost))
    return "$%d to $%d" % [lo, hi]


# who asks: Garrison (culture owner) in the tech campaign; in the owner campaign the card comes from Alan
func _host() -> String:
    return "Alan (Co-owner)" if Campaign.mode == "owner" else "Garrison (Co-owner)"


func _invite_answer(id: String) -> void:
    if id == "yes":
        pick_game(true)
        return
    skipped += 1
    if Campaign.mode == "owner":
        Owner.burnout = clampf(Owner.burnout + 2.0, 0.0, 100.0)
    else:
        Social.change_all(-1)


func pick_game(from_invite: bool) -> void:
    var options := []
    for id in GAMES:
        var cost := int(GAMES[id].cost)
        var entry := {"label": "%s%s" % [str(GAMES[id].label), " ($%d)" % cost if Campaign.mode == "owner" else ""], "id": id}
        if Campaign.mode == "owner" and Owner.cash < cost:
            entry["enabled"] = false
            entry["hint"] = "NEED $%d" % cost
        options.append(entry)
    Cards.ask(_host(), "Where to? Bowling is easy, karaoke is risky, the escape room needs teamwork and dinner needs good conversation.", options, func(id: String) -> void: start(id, from_invite))


func _unhandled_input(event: InputEvent) -> void:
    if not enabled or is_open or Campaign.active or Game.title_mode or Game.ui_open:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
        Cards.ask("Team outing", "Take the team out? (Free Play: nothing is scored.)", [
            {"label": "LET US GO", "id": "yes"}, {"label": "NEVER MIND", "id": "no"},
        ], func(id: String) -> void: _free_answer(id))


func _free_answer(id: String) -> void:
    if id == "yes":
        pick_game(false)


# ---- running an outing ------------------------------------------------------------------------
func start(id: String, from_invite := false) -> void:
    var here := get_tree().current_scene
    if use_rooms and ROOMS.has(id) and here != null and not Game.title_mode:
        _return_scene = here.scene_file_path.get_file().get_basename()
        var me := here.get_node_or_null("Actors/Player")
        _return_x = me.global_position.x if me != null else -1.0
        _traveled = true
        _wait_id = id
        _from_invite = from_invite
        World.start_outing(str(ROOMS[id]), SPOTS[id], SEATS.get(id, {}))
        Game.go(str(ROOMS[id]), "from_outing")
        return
    _traveled = false
    _open(id, from_invite)


func _open(id: String, from_invite: bool) -> void:
    game = id
    _from_invite = from_invite
    phase = "intro"
    stars = 0
    g = {}
    lines = []
    _prev_scale = World.time_scale if World.time_scale > 0.0 else 1.0
    World.time_scale = 0.0
    is_open = true
    Game.ui_open = true
    _canvas.visible = true
    if Campaign.mode == "owner":
        Owner.cash -= int(GAMES[id].cost)
    _canvas.queue_redraw()


func begin_play() -> void:
    phase = "play"
    match game:
        "bowling":
            _bowl_setup()
        "karaoke":
            _kara_setup()
        "escape":
            _escape_setup()
            if room_mode():
                _escape_room_setup()
        _:
            _dinner_setup()
    if room_mode():
        _room_begin()


func close() -> void:
    if not is_open:
        return
    is_open = false
    _canvas.visible = false
    Game.ui_open = false
    World.time_scale = _prev_scale
    if _from_invite and Campaign.active:
        World.clock = maxf(World.clock, World.DAY_END)
        Shift.skip_stay()
    elif _traveled:
        World.end_outing()
        Game.pending_x = _return_x
        Game.go(_return_scene, "start")
    _traveled = false
    _peek = false
    finished.emit(game, stars)


func _process(delta: float) -> void:
    if _wait_id != "":
        var here := get_tree().current_scene
        if not Game.busy and here != null and here.scene_file_path.get_file().get_basename() == str(ROOMS[_wait_id]):
            var id := _wait_id
            _wait_id = ""
            _open(id, _from_invite)
        return
    if is_open:
        if phase == "play":
            tick(delta)
        _room_process(delta)
        _canvas.queue_redraw()
        return
    maybe_invite()


func tick(dt: float) -> void:
    if phase != "play":
        return
    match game:
        "bowling":
            _bowl_tick(dt)
        "karaoke":
            _kara_tick(dt)
        "escape":
            _escape_tick(dt)
        _:
            _dinner_tick(dt)


func _input(event: InputEvent) -> void:
    if not is_open or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if room_mode() and phase == "play" and not _room_wants(event.keycode):
        return  # in the room you keep walking around
    press(event.keycode)
    get_viewport().set_input_as_handled()


func press(key: int) -> void:
    if not is_open:
        return
    if key == KEY_TAB and _traveled:
        _peek = not _peek
        _canvas.queue_redraw()
    elif phase == "intro" or phase == "result":
        _press_page(key)
    elif key == KEY_ESCAPE:
        _escape_or_leave()
    elif not (room_mode() and _room_press(key)):
        _press_game(key)


func _press_page(key: int) -> void:
    if phase == "result":
        if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
            close()
    elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
        begin_play()
    elif key == KEY_ESCAPE:
        if Campaign.mode == "owner":
            Owner.cash += int(GAMES[game].cost)
        _finish(-1)


func _escape_or_leave() -> void:
    if game == "escape" and g.get("entry", false):
        g.entry = false
        Game.ui_open = false
    else:
        _finish(-1)


func _press_game(key: int) -> void:
    match game:
        "bowling":
            _bowl_press(key)
        "karaoke":
            _kara_press(key)
        "escape":
            _escape_press(key)
        _:
            _dinner_press(key)


# stars: 0-3, or -1 when you left early
func _finish(result: int) -> void:
    stars = result
    phase = "result"
    lines = []
    if result < 0:
        lines.append("YOU LEFT EARLY. NOBODY SAYS ANYTHING. EVERYBODY NOTICES.")
        Social.change_all(-1)
    else:
        count += 1
        best[game] = maxi(int(best.get(game, 0)), result)
        Career.note_outing(
            game,
            result,
            {
                "perfects": int(g.get("perfect", 0)),
                "secs": roundi(Difficulty.f("escape.time") - float(g.get("time", 0.0))),
                "score": int(g.get("score", 0))
            }
        )
        Social.change_all(1 + result)
        if Campaign.active:
            lines.append("EVERYONE ON THE TEAM LIKES YOU %d MORE." % (1 + result))
        else:
            lines.append("A GOOD NIGHT OUT. (FREE PLAY: NOTHING IS SCORED.)")
        if Campaign.mode == "owner":
            var relief := 5.0 + 3.0 * float(result)
            Owner.burnout = clampf(Owner.burnout - relief, 0.0, 100.0)
            Owner.flags["outings"] = int(Owner.flags.get("outings", 0)) + 1
            lines.append("BURNOUT DOWN %d POINTS. THE CREW FEELS SEEN." % int(relief))
            if game == "escape" and result >= 2:
                Owner.speed += 0.02
                lines.append("THEY WORK BETTER TOGETHER NOW: TEAM SPEED UP.")
        elif Campaign.active:
            var gain := 4.0 + 2.0 * float(result)
            Shift.add_energy(gain)
            lines.append("ENERGY +%d. A NIGHT OUT HELPS." % int(gain))
        if result >= 3:
            Campaign.adjust_rep(1)
            if Campaign.active:
                lines.append("WORD GETS AROUND ABOUT THIS ONE: REPUTATION +1.")
    if room_mode():
        _release_player()
        Game.ui_open = true
        _caption_t = 0.0
    _canvas.queue_redraw()


# ---- bowling ------------------------------------------------------------------------------------
func _all_up() -> Array:
    return [true, true, true, true, true, true, true, true, true, true]


func _bowl_setup() -> void:
    g = {
        "frame": 1, "roll": 1, "pins": 10, "stage": "aim", "marker": 0.0, "power": 0.0, "dir": 1.0, "wait": 0.0,
        "ball": 0.0, "msg": "", "totals": {"You": 0, "Alan": 0, "Garrison": 0, "Dan": 0}, "knocked": 0,
        "up": [_all_up(), _all_up()], "fall": {}, "queue": [], "opp": "", "opp_t": 0.0, "opp_ball": 0.0,
        "opp_off": 0.5, "opp_total": 0, "opp_knock": 0, "opp_phase": 0,
    }
    if room_mode():
        g.stage = "ready"
        caption("YOUR TURN. PRESS E TO STEP UP.", 99.0)


func _bowl_tick(dt: float) -> void:
    for key in g.fall.keys():
        g.fall[key] = float(g.fall[key]) - dt
        if float(g.fall[key]) <= 0.0:
            g.fall.erase(key)
    var stage: String = g.stage
    if stage == "aim" or stage == "power":
        var key := "marker" if stage == "aim" else "power"
        var speed := Difficulty.f("bowl.aim_speed" if stage == "aim" else "bowl.power_speed")
        var v: float = float(g[key]) + float(g.dir) * dt * speed
        if v >= 1.0:
            v = 1.0
            g.dir = -1.0
        elif v <= 0.0:
            v = 0.0
            g.dir = 1.0
        g[key] = v
    elif stage == "roll":
        g.ball = minf(1.0, float(g.ball) + dt * 1.6)
        if float(g.ball) >= 1.0:
            _bowl_resolve()
    elif stage == "pause":
        g.wait = float(g.wait) - dt
        if float(g.wait) <= 0.0:
            _bowl_next()
    elif stage == "others":
        _bowl_others(dt)


func _bowl_press(key: int) -> void:
    if key not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
        return
    if room_mode() and g.stage not in ["ready", "aim", "power"]:
        caption("WAIT. E DOES NOTHING UNTIL IT IS YOUR TURN.", 1.5)
        return
    if g.stage == "ready":
        _place_player(_x0() + float(LANE_NEAR[0]))
        _hold_player("idle")
        g.stage = "aim"
        g.marker = 0.0
        g.dir = 1.0
        caption("PRESS E TO STOP THE AIM (STOP IN THE GREEN).", 99.0)
    elif g.stage == "aim":
        g.stage = "power"
        g.power = 0.0
        g.dir = 1.0
        caption("PRESS E TO STOP THE POWER (STOP IN THE GREEN).", 99.0)
    elif g.stage == "power":
        g.stage = "roll"
        g.ball = 0.0
        caption("WAIT. THE BALL IS ROLLING.", 3.0)
        var p := _actor("Player")
        if p != null:
            p.start_emote("reach", 0.8)


func bowl_strength() -> float:
    var accuracy := 1.0 - absf(float(g.marker) - 0.5) * 2.0
    var quality := clampf(1.0 - absf(float(g.power) - 0.85) / 0.85, 0.0, 1.0)
    var noise := Difficulty.rng("bowl").randf_range(-0.08, 0.08)
    return clampf(accuracy * 0.6 + quality * 0.4 + noise, 0.0, 1.0)


func _bowl_resolve() -> void:
    var strength := bowl_strength()
    var left := int(g.pins)
    var knocked := left if strength > 0.92 else clampi(roundi(float(left) * minf(1.0, strength * 1.15)), 0, left)
    g.knocked = knocked
    g.pins = left - knocked
    g.totals["You"] = int(g.totals["You"]) + knocked
    Career.note_bowl(knocked, int(g.roll))
    if knocked == 10 and int(g.roll) == 1:
        g.totals["You"] = int(g.totals["You"]) + 3
        g.msg = "STRIKE!"
    elif int(g.pins) == 0:
        g.msg = "SPARE!"
    elif knocked == 0:
        g.msg = "GUTTER BALL..."
    else:
        g.msg = "%d PINS" % knocked
    g.stage = "pause"
    g.wait = 1.4 if room_mode() else 1.1
    if room_mode():
        _pins_fall(0, knocked)
        _bubble(_actor("Player"), "!" if knocked >= 8 else ("?" if knocked == 0 else "dots"), 1.2)
        for who in DINERS:
            if knocked >= 10:
                _bubble(_actor(who), "heart", 1.2)


func _bowl_roll_opp(who: String) -> Dictionary:
    var skill := float(BOWL_SKILL[who]) + Difficulty.f("bowl.opp_skill")
    var r := Difficulty.rng("bowl")
    var first := clampi(roundi(10.0 * (skill + r.randf_range(-0.28, 0.28))), 0, 10)
    var total := first
    var knock := first
    if first == 10:
        total += 3
    else:
        var second := clampi(roundi(float(10 - first) * (skill + r.randf_range(-0.28, 0.28))), 0, 10 - first)
        total += second
        knock += second
    return {"total": total, "knock": knock}


func _bowl_next() -> void:
    var frame_over: bool = int(g.roll) == 2 or int(g.pins) == 0
    if not frame_over:
        g.roll = 2
        g.stage = "aim"
        g.marker = 0.0
        g.dir = 1.0
        if room_mode():
            caption("SECOND ROLL. PRESS E TO STOP THE AIM.", 99.0)
        return
    if room_mode():
        g.queue = BOWL_SKILL.keys()
        g.opp = ""
        g.stage = "others"
        caption("WAIT. THE CREW BOWLS NEXT.", 2.0)
        return
    for who in BOWL_SKILL:
        g.totals[who] = int(g.totals[who]) + int(_bowl_roll_opp(who).total)
    _bowl_advance()


func _bowl_advance() -> void:
    if int(g.frame) >= 5:
        _bowl_end()
        return
    g.frame = int(g.frame) + 1
    g.roll = 1
    g.pins = 10
    g.stage = "ready" if room_mode() else "aim"
    g.marker = 0.0
    g.dir = 1.0
    g.msg = ""
    g.up = [_all_up(), _all_up()]
    if room_mode():
        caption("FRAME %d. YOUR TURN: PRESS E TO STEP UP." % int(g.frame), 99.0)


# the crew takes its turn on the next lane, one at a time
func _bowl_others(dt: float) -> void:
    g.opp_t = float(g.opp_t) + dt
    if str(g.opp) == "":
        if g.queue.is_empty():
            _bowl_advance()
            return
        g.opp = str(g.queue.pop_front())
        var res := _bowl_roll_opp(str(g.opp))
        g.opp_total = int(res.total)
        g.opp_knock = int(res.knock)
        var wobble := Difficulty.rng("bowl").randf_range(-0.5, 0.5)
        g.opp_off = clampf(0.5 + (1.0 - float(res.knock) / 10.0) * wobble, 0.0, 1.0)
        g.opp_ball = 0.0
        g.opp_t = 0.0
        g.opp_phase = 0
        g.up[1] = _all_up()
        caption("WAIT. %s STEPS UP." % str(g.opp).to_upper(), 1.5)
        return
    if int(g.opp_phase) == 0:
        g.opp_ball = minf(1.0, float(g.opp_t) / 0.6)
        if float(g.opp_t) >= 0.6:
            g.opp_phase = 1
            _pins_fall(1, int(g.opp_knock))
            _bubble(_actor(str(g.opp)), "!" if int(g.opp_knock) >= 8 else "dots", 1.2)
            caption("%s KNOCKS DOWN %d" % [str(g.opp).to_upper(), int(g.opp_knock)], 1.5)
    elif float(g.opp_t) >= 1.7:
        g.totals[g.opp] = int(g.totals[g.opp]) + int(g.opp_total)
        g.opp = ""
        g.opp_ball = 0.0


func _pins_fall(lane: int, count: int) -> void:
    var up: Array = g.up[lane]
    var standing := []
    for i in 10:
        if up[i]:
            standing.append(i)
    Difficulty.shuffle(standing, "bowl")
    for i in mini(count, standing.size()):
        up[standing[i]] = false
        g.fall["%d_%d" % [lane, standing[i]]] = 0.8


func bowl_rank() -> int:
    var rank := 0
    for who in BOWL_SKILL:
        if int(g.totals[who]) > int(g.totals["You"]):
            rank += 1
    return rank


func _bowl_end() -> void:
    _finish([3, 2, 1, 1][bowl_rank()])


# ---- karaoke ------------------------------------------------------------------------------------
func _kara_setup() -> void:
    var notes := []
    var gap := Difficulty.f("karaoke.gap")
    var r := Difficulty.rng("karaoke")
    for i in SONG_LEN:
        notes.append({"lane": r.randi_range(0, 3), "time": 1.5 + gap * float(i), "state": ""})
    g = {"t": 0.0, "notes": notes, "score": 0, "perfect": 0, "good": 0, "miss": 0, "streak": 0, "flash": "", "flash_t": 0.0,
        "gap": gap, "perfect_win": Difficulty.f("karaoke.perfect"), "good_win": Difficulty.f("karaoke.good"),
    }


func _kara_tick(dt: float) -> void:
    g.t = float(g.t) + dt
    g.flash_t = maxf(0.0, float(g.flash_t) - dt)
    for n in g.notes:
        if n.state == "" and float(n.time) + _good_win() < float(g.t):
            n.state = "miss"
            g.miss = int(g.miss) + 1
            g.streak = 0
            _streak_broken()
            g.flash = "MISS"
            g.flash_t = 0.5
    if float(g.t) > _song_secs() + 0.6:
        _kara_end()


func _good_win() -> float:
    return float(g.get("good_win", 0.3))


func _song_secs() -> float:
    return 1.5 + float(g.get("gap", 0.75)) * float(SONG_LEN)


func _kara_press(key: int) -> void:
    var lane := LANE_KEYS.find(key)
    if lane < 0:
        return
    kara_hit(lane)


func kara_hit(lane: int) -> String:
    var pick: Dictionary = {}
    var gap := 9.0
    for n in g.notes:
        if n.state == "" and int(n.lane) == lane and absf(float(n.time) - float(g.t)) < gap:
            gap = absf(float(n.time) - float(g.t))
            pick = n
    if pick.is_empty() or gap > _good_win():
        g.streak = 0
        _streak_broken()
        return ""
    var perfect := gap <= float(g.get("perfect_win", 0.12))
    pick.state = "perfect" if perfect else "good"
    g.score = int(g.score) + (2 if perfect else 1)
    g.perfect = int(g.perfect) + (1 if perfect else 0)
    g.good = int(g.good) + (0 if perfect else 1)
    g.streak = int(g.streak) + 1
    g.flash = "PERFECT!" if perfect else "GOOD"
    g.flash_t = 0.5
    if room_mode() and int(g.streak) % 4 == 0:
        _cheer()
    if room_mode() and int(g.streak) >= 8 and not g.get("dance", false):
        g.dance = true
        _hold_player("dance")
    return str(pick.state)


func _kara_end() -> void:
    var share := float(g.score) / float(SONG_LEN * 2)
    _finish(3 if share >= 0.75 else (2 if share >= 0.5 else (1 if share >= 0.25 else 0)))


# ---- escape room --------------------------------------------------------------------------------
func _escape_setup() -> void:
    var digits := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    Difficulty.shuffle(digits, "escape")
    var friends := 0
    for who in Social.PEOPLE:
        friends += 1 if Social.is_friendly(who) else 0
    g = {
        "code": [digits[0], digits[1], digits[2]], "cur": [0, 0, 0], "cursor": 0, "guesses": [], "time": Difficulty.f("escape.time"),
        "hints": clampi(maxi(1, friends), 1, 3), "hints_used": 0, "revealed": [], "msg": "",
    }


func _escape_tick(dt: float) -> void:
    g.time = float(g.time) - dt
    if float(g.time) <= 0.0:
        g.msg = "TIME IS UP"
        _finish(0)


func _escape_press(key: int) -> void:
    var cur: Array = g.cur
    match key:
        KEY_LEFT:
            g.cursor = (int(g.cursor) + 2) % 3
        KEY_RIGHT:
            g.cursor = (int(g.cursor) + 1) % 3
        KEY_UP:
            cur[int(g.cursor)] = (int(cur[int(g.cursor)]) + 1) % 10
        KEY_DOWN:
            cur[int(g.cursor)] = (int(cur[int(g.cursor)]) + 9) % 10
        KEY_ENTER, KEY_KP_ENTER:
            if room_mode():
                _room_submit()
            else:
                escape_try(cur.duplicate())
        KEY_H:
            if not room_mode():
                escape_hint()


func escape_score(guess: Array) -> Array:
    var code: Array = g.code
    var bulls := 0
    var cows := 0
    for i in 3:
        if int(guess[i]) == int(code[i]):
            bulls += 1
        elif code.has(int(guess[i])):
            cows += 1
    return [bulls, cows]


func escape_try(guess: Array) -> void:
    if g.guesses.size() >= 8:
        return
    var score := escape_score(guess)
    g.guesses.append([guess, score[0], score[1]])
    if int(score[0]) == 3:
        var tries: int = g.guesses.size()
        var result := 3 if tries <= 4 else (2 if tries <= 6 else 1)
        if int(g.hints_used) >= 2:
            result = maxi(1, result - 1)
        g.msg = "THE DOOR CLICKS OPEN!"
        _finish(result)
    elif g.guesses.size() >= 8:
        g.msg = "OUT OF TRIES"
        _finish(0)


func escape_hint() -> String:
    if int(g.hints) <= 0:
        return ""
    var open := []
    for i in 3:
        if not g.revealed.has(i):
            open.append(i)
    if open.is_empty():
        return ""
    var slot: int = Difficulty.pick(open, "escape")
    g.revealed.append(slot)
    g.hints = int(g.hints) - 1
    g.hints_used = int(g.hints_used) + 1
    g.cur[slot] = g.code[slot]
    var friend := "ALAN"
    for who in Social.PEOPLE:
        if Social.is_friendly(who):
            friend = who.to_upper()
            break
    g.msg = "%s: SLOT %d IS A %d" % [friend, slot + 1, int(g.code[slot])]
    return str(g.msg)


# ---- dinner -------------------------------------------------------------------------------------
func _dinner_setup() -> void:
    g = {"round": 1, "options": [], "sel": 0, "react": {}, "wait": 0.0, "score": 0, "last": ""}
    _dinner_deal()


func _dinner_deal() -> void:
    var pool: Array = TOPICS.duplicate()
    Difficulty.shuffle(pool, "dinner")
    g.options = pool.slice(0, 4)
    g.sel = 0
    g.react = {}
    g.wait = 0.0


func _dinner_tick(dt: float) -> void:
    if not g.react.is_empty():
        g.wait = float(g.wait) - dt
        if float(g.wait) <= 0.0:
            if int(g.round) >= 5:
                _dinner_end()
            else:
                g.round = int(g.round) + 1
                _dinner_deal()


func _dinner_press(key: int) -> void:
    if not g.react.is_empty() or str(g.get("stage", "")) == "sit":
        return
    match key:
        KEY_UP:
            g.sel = (int(g.sel) + 3) % 4
        KEY_DOWN:
            g.sel = (int(g.sel) + 1) % 4
        KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
            dinner_talk(int(g.sel))


func dinner_talk(index: int) -> int:
    var topic: String = g.options[index]
    var total := 0
    g.react = {}
    g.hidden = _dinner_hidden()
    for who in DINERS:
        var mood := "meh"
        var pts := 1
        if LOVES[who].has(topic):
            mood = "love"
            pts = 2
        elif HATES[who] == topic:
            mood = "hate"
            pts = 0
        total += pts
        g.react[who] = mood
        if g.hidden.has(who):
            continue  # a face you could not read teaches you nothing
        var entry: Dictionary = known.get(who, {"likes": [], "hates": []})
        if mood == "love" and not entry.likes.has(topic):
            entry.likes.append(topic)
        elif mood == "hate" and not entry.hates.has(topic):
            entry.hates.append(topic)
        known[who] = entry
    g.score = int(g.score) + total
    g.wait = 1.4
    if room_mode():
        _dinner_react()
    return total


# harder tiers hide some faces for a round (the points still count)
func _dinner_hidden() -> Array:
    var hide_n := DINERS.size() - clampi(Difficulty.i("dinner.reveal"), 0, DINERS.size())
    if hide_n <= 0:
        return []
    var order: Array = DINERS.duplicate()
    Difficulty.shuffle(order, "dinner")
    return order.slice(0, hide_n)


func _dinner_end() -> void:
    var score := int(g.score)
    _finish(3 if score >= 24 else (2 if score >= 19 else (1 if score >= 14 else 0)))


# ---- in the room: the games are played in the scene itself ---------------------------------------
func room_mode() -> bool:
    return _traveled and is_open


func _x0() -> float:
    return float(World.DATA.SCENES[str(ROOMS[game])].x0)


func _actor(who: String) -> Node:
    var scene := get_tree().current_scene
    return scene.get_node_or_null("Actors/" + who) if scene != null else null


func _place_player(x: float) -> void:
    var p := _actor("Player")
    if p != null:
        p.global_position = Vector2(x, 118.0)
        p.velocity = Vector2.ZERO


func _hold_player(anim: String, toward := INF) -> void:
    var p := _actor("Player")
    if p != null:
        p.start_emote(anim, 100000.0, toward)


func _release_player() -> void:
    var p := _actor("Player")
    if p != null and p.state == "emote":
        p.start_emote("idle", 0.05)


func caption(text: String, secs := 3.0) -> void:
    _caption = text
    _caption_t = secs


func _bubble(node: Node, glyph: String, secs := 1.2) -> void:
    if node == null or not is_instance_valid(node):
        return
    if node.has_method("_ensure_bubble"):
        node._ensure_bubble()
    if node.get("_bubble") == null:
        return
    node._bubble.glyph = glyph
    node._bubble.visible = true
    _marks[node] = secs


func _room_begin() -> void:
    Game.ui_open = false
    match game:
        "karaoke":
            var mic := _x0() + MIC_X
            _place_player(mic)
            _hold_player("talk", mic + 60.0)
            caption("ARROW KEYS AT THE LINE. SING!", 4.0)
        "escape":
            caption("LOOK AROUND. E ON THE CHALKBOARD, THE CLOCK, THE PAINTING. N = HINT", 6.0)
        "dinner":
            g.stage = "sit"
            caption("SIT AT THE BOOTH WITH ALAN (PRESS E ON THE SEAT)", 99.0)


func _room_process(delta: float) -> void:
    _caption_t = maxf(0.0, _caption_t - delta)
    for node in _marks.keys():
        _marks[node] = float(_marks[node]) - delta
        if float(_marks[node]) <= 0.0:
            if is_instance_valid(node) and node.get("_bubble") != null:
                node._bubble.visible = false
            _marks.erase(node)
    if phase == "play" and game == "dinner" and str(g.get("stage", "")) == "sit":
        var p := _actor("Player")
        if p != null and p.state == "sitting":
            g.stage = "talk"
            Game.ui_open = true
            caption("PICK A TOPIC (UP / DOWN, ENTER). WATCH THEIR FACES.", 5.0)


# keys the in-room game wants (the rest still move you around)
func _room_wants(key: int) -> bool:
    if key == KEY_ESCAPE:
        return true
    match game:
        "bowling":
            return key in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
        "karaoke":
            return key in LANE_KEYS
        "escape":
            if g.get("entry", false):
                return key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER]
            return key == KEY_N
        _:
            return str(g.get("stage", "")) == "talk" and key in [KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]


func _room_press(key: int) -> bool:
    if game == "escape" and key == KEY_N and not g.get("entry", false):
        escape_nudge()
        return true
    return false


# E belongs to the bowling game while it runs (the crew should not answer it)
func blocks_interact() -> bool:
    return is_open and room_mode() and phase == "play" and game == "bowling"


# the one control hint line: pages show it as their footer, rooms in the bar at the bottom
func hint() -> String:
    if phase == "intro":
        return "ENTER = START  ESC = SKIP  TAB = LOOK" if _traveled else "ENTER = START  ESC = SKIP"
    if phase == "result":
        return "ENTER = CONTINUE"
    if not room_mode():
        return str(GAMES[game].keys)
    match game:
        "bowling":
            match str(g.get("stage", "")):
                "ready":
                    return "E = STEP UP  ESC = LEAVE"
                "aim":
                    return "E = STOP THE AIM  ESC = LEAVE"
                "power":
                    return "E = STOP THE POWER  ESC = LEAVE"
            return "WAIT FOR YOUR TURN  ESC = LEAVE"
        "karaoke":
            return "ARROW KEYS = HIT NOTES  ESC = LEAVE"
        "escape":
            if g.get("entry", false):
                return "ARROWS  ENTER = TRY  ESC = BACK"
            return "E = LOOK / USE  N = HINT  ESC = LEAVE"
    if str(g.get("stage", "")) == "talk":
        return "UP / DOWN  ENTER = TALK  ESC = LEAVE"
    return "E = SIT DOWN  ESC = LEAVE"


# ---- karaoke extras
func _cheer() -> void:
    var who: String = Difficulty.pick(DINERS + ["Vic"], "karaoke")
    _bubble(_actor(who), "heart", 1.5)


func _streak_broken() -> void:
    if not room_mode() or game != "karaoke":
        return
    if g.get("dance", false):
        g.dance = false
        _hold_player("talk", _x0() + MIC_X + 60.0)
    if Difficulty.rng("karaoke").randf() < 0.3:
        _bubble(_actor(Difficulty.pick(DINERS, "karaoke")), "?", 1.0)


# ---- escape room extras
func _escape_room_setup() -> void:
    var pool := [1, 2, 3, 4, 5, 6, 7, 8, 9]
    Difficulty.shuffle(pool, "escape")
    var a: int = pool[0]
    var first := Difficulty.rng("escape").randi_range(0, a)
    g = {
        "code": [a, pool[1], pool[2]], "cur": [0, 0, 0], "cursor": 0, "guesses": [], "time": Difficulty.f("escape.time"),
        "hints": 3, "hints_used": 0, "revealed": [], "msg": "", "found": [], "entry": false, "wrong": 0,
        "eq": [first, a - first],
    }


func interact(kind: String) -> void:
    if not room_mode() or game != "escape" or phase != "play" or g.is_empty():
        return
    match kind:
        "clue_board":
            _found(0)
            caption("THE CHALKBOARD: %d + %d = ?   THE ANSWER IS THE FIRST DIGIT." % [int(g.eq[0]), int(g.eq[1])], 5.0)
        "clue_clock":
            _found(1)
            caption("THE CLOCK HAS STOPPED AT %d O'CLOCK. THAT IS THE SECOND DIGIT." % int(g.code[1]), 5.0)
        "clue_painting":
            _found(2)
            caption("A BRASS PLAQUE UNDER THE PAINTING: NO. %d. THE THIRD DIGIT." % int(g.code[2]), 5.0)
        "keypad":
            g.entry = true
            Game.ui_open = true
            caption("ENTER THE CODE: UP / DOWN CHANGE, LEFT / RIGHT MOVE, ENTER TRIES IT, ESC BACKS OFF", 6.0)


func _found(index: int) -> void:
    if not g.found.has(index):
        g.found.append(index)


func escape_nudge() -> String:
    if int(g.hints) <= 0:
        caption("NOBODY HAS ANYTHING LEFT TO SAY.", 2.0)
        return ""
    var friend := "ALAN"
    for who in Social.PEOPLE:
        if Social.is_friendly(who):
            friend = who.to_upper()
            break
    var text := "YOU HAVE ALL THREE. TRY THE KEYPAD ON THE VAULT."
    for i in 3:
        if not g.found.has(i):
            text = ["TRY THE CHALKBOARD.", "THAT WALL CLOCK LOOKS WRONG.", "WHAT IS UNDER THE PAINTING?"][i]
            break
    g.hints = int(g.hints) - 1
    g.hints_used = int(g.hints_used) + 1
    text = "%s: %s" % [friend, text]
    caption(text, 4.0)
    _bubble(_actor(friend.capitalize()), "!", 1.5)
    return text


func _room_submit() -> void:
    var cur: Array = g.cur
    if cur == g.code:
        var left := float(g.time)
        var result := 3 if left >= 70.0 else (2 if left >= 35.0 else 1)
        if int(g.hints_used) >= 2:
            result = maxi(1, result - 1)
        g.entry = false
        g.msg = "THE VAULT OPENS!"
        _finish(result)
        return
    g.wrong = int(g.wrong) + 1
    var penalty := Difficulty.f("escape.wrong_penalty")
    g.time = float(g.time) - penalty
    caption("WRONG CODE. THE ALARM SHAVES %d SECONDS OFF." % int(penalty), 3.0)


# ---- dinner extras
func _dinner_react() -> void:
    var parts := []
    for who in DINERS:
        var mood: String = g.react[who]
        if g.get("hidden", []).has(who):
            _bubble(_actor(who), "?", 1.3)
            parts.append("%s IS HARD TO READ" % who.to_upper())
            continue
        _bubble(_actor(who), "heart" if mood == "love" else ("!" if mood == "hate" else "dots"), 1.3)
        parts.append("%s %s" % [who.to_upper(), {"love": "LOVES IT", "hate": "DREADS IT", "meh": "IS FINE"}[mood]])
    caption(", ".join(parts), 2.0)


# ---- the in-room display (replaces the panel while you play)
func _paint_hud(size: Vector2) -> void:
    UiStyle.hint_bar(_canvas, size, hint())
    var top := UiStyle.caption_bar(_canvas, size, _caption if _caption_t > 0.0 else "")
    var strip := Rect2(0.0, top - UiStyle.STRIP_H, minf(size.x, 164.0), UiStyle.STRIP_H)
    match game:
        "bowling":
            _hud_bowling(strip)
        "karaoke":
            _hud_karaoke(strip)
        "escape":
            _hud_escape(strip)
        _:
            _hud_dinner(strip, size)


func _hud_bowling(s: Rect2) -> void:
    var o := UiStyle.strip(_canvas, s)
    _t("FRAME %d OF 5" % int(g.frame), o.x, o.y, WHITE)
    var stage := str(g.stage)
    var x := s.position.x + 58.0
    if stage == "aim" or stage == "power":
        var bar := Rect2(s.position.x + 82.0, s.position.y + 3.0, 80.0, 5.0)
        _canvas.draw_rect(bar, UiStyle.SOFT)
        if stage == "aim":
            _canvas.draw_rect(Rect2(bar.position.x + 32.0, bar.position.y, 16.0, 5.0), GREEN)
            _canvas.draw_rect(Rect2(bar.position.x + 79.0 * float(g.marker), bar.position.y - 2.0, 2.0, 9.0), WHITE)
            _t("AIM", x, o.y, WHITE)
        else:
            _canvas.draw_rect(Rect2(bar.position.x + 58.0, bar.position.y, 14.0, 5.0), GREEN)
            _canvas.draw_rect(Rect2(bar.position.x, bar.position.y, 80.0 * float(g.power), 5.0), AMBER)
            _t("POWER", x, o.y, WHITE)
    else:
        var status := "YOUR TURN" if stage == "ready" else ("ROLLING" if stage == "roll" else "CREW BOWLS")
        _t(status, x, o.y, UiStyle.SOFT)


func _hud_karaoke(s: Rect2) -> void:
    var lanes := Rect2(4.0, s.position.y - 79.0, 100.0, 78.0)
    UiStyle.box(_canvas, lanes)
    _paint_karaoke(Rect2(lanes.position.x + 2.0, lanes.position.y + 2.0, lanes.size.x - 4.0, lanes.size.y - 4.0), true)
    var o := UiStyle.strip(_canvas, s)
    _t("SCORE %d  STREAK %d" % [int(g.score), int(g.streak)], o.x, o.y, WHITE)
    if float(g.flash_t) > 0.0:
        _t(str(g.flash), s.position.x + 88.0, o.y, GREEN if g.flash != "MISS" else RED)


func _hud_escape(s: Rect2) -> void:
    var o := UiStyle.strip(_canvas, s)
    if not g.get("entry", false):
        _t("CLUES %d OF 3  HINTS %d" % [g.found.size(), int(g.hints)], o.x, o.y, WHITE)
        return
    _t("CODE", o.x, o.y, WHITE)
    for i in 3:
        var r := Rect2(s.position.x + 32.0 + 12.0 * float(i), s.position.y + 1.0, 10.0, 9.0)
        _canvas.draw_rect(r, WHITE)
        _canvas.draw_rect(
            Rect2(r.position.x, r.end.y - 1.0, 10.0, 1.0),
            BLUE if int(g.cursor) == i else UiStyle.SOFT
        )
        PixelFont.draw(
            _canvas,
            str(int(g.cur[i])),
            r.position + Vector2(3.0, 2.0),
            GREEN if g.revealed.has(i) else INK,
            1
        )


func _hud_dinner(s: Rect2, size: Vector2) -> void:
    var o := UiStyle.strip(_canvas, s)
    if str(g.get("stage", "")) != "talk":
        _t("SIT AT THE BOOTH", o.x, o.y, UiStyle.SOFT)
        return
    _t("ROUND %d OF 5  SCORE %d" % [int(g.round), int(g.score)], o.x, o.y, WHITE)
    var w := minf(size.x - 8.0, 84.0)  # narrow, so it stays right of Vic at the bar in the 320x180 format
    var box := Rect2(size.x - w - 4.0, s.position.y - 43.0, w, 42.0)
    UiStyle.box(_canvas, box)
    for i in 4:
        var on: bool = int(g.sel) == i and g.react.is_empty()
        var ry := box.position.y + 4.0 + 9.0 * float(i)
        if on:
            _canvas.draw_rect(Rect2(box.position.x + 2.0, ry - 1.0, w - 4.0, 8.0), Color("ffe08a"))
        _t(str(g.options[i]), box.position.x + 4.0, ry, INK if on else WHITE)


# ---- drawing ------------------------------------------------------------------------------------
func _t(s: String, x: float, y: float, color := INK) -> void:
    PixelFont.draw(_canvas, s, Vector2(x, y), color, 1)


func _tc(s: String, cx: float, y: float, color := INK) -> void:
    PixelFont.draw(_canvas, s, Vector2(cx - float(PixelFont.width(s, 1)) * 0.5, y), color, 1)


func _wrap(s: String, chars: int) -> Array:
    return UiStyle.wrap_text(s, chars)


func _star(c: Vector2, r: float, color: Color) -> void:
    UiStyle.star(_canvas, c, r, color)


func _arrow(lane: int, c: Vector2, size: float, color: Color) -> void:
    var s := size
    var pts := PackedVector2Array()
    match lane:
        0:
            pts = PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s, -s), c + Vector2(s, s)])
        1:
            pts = PackedVector2Array([c + Vector2(0, -s), c + Vector2(-s, s), c + Vector2(s, s)])
        2:
            pts = PackedVector2Array([c + Vector2(0, s), c + Vector2(-s, -s), c + Vector2(s, -s)])
        _:
            pts = PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s, -s), c + Vector2(-s, s)])
    _canvas.draw_colored_polygon(pts, color)


func _paint() -> void:
    if not is_open:
        return
    var size := get_viewport().get_visible_rect().size
    if room_mode() and phase == "play":
        _paint_hud(size)
        return
    if _traveled and _peek:
        UiStyle.hint_bar(_canvas, size, "TAB = BACK TO THE GAME")
        return
    _canvas.draw_rect(
        Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.0 if _traveled else 0.86)
    )
    var panel := UiStyle.panel_rect(size, 250.0, 112.0)
    var title := str(GAMES[game].label) + ("  TEAM OUTING" if phase != "result" else "  RESULT")
    var body := UiStyle.panel(_canvas, panel, title, "", 0.88 if _traveled else 1.0)
    match phase:
        "intro":
            _paint_intro(body)
        "result":
            _paint_result(body)
        _:
            match game:
                "bowling":
                    _paint_bowling(body)
                "karaoke":
                    _paint_karaoke(body)
                "escape":
                    _paint_escape(body)
                _:
                    _paint_dinner(body)
    UiStyle.footer(_canvas, panel, hint())


func _paint_intro(b: Rect2) -> void:
    var y := b.position.y + 2.0
    var blurb := str(ROOM_INTRO[game]) if _traveled else str(GAMES[game].blurb)
    for line in _wrap(blurb, int(b.size.x / 4.0)):
        _t(line, b.position.x, y)
        y += 7.0
    y += 4.0
    if Campaign.mode == "owner":
        _t("COST $%d" % int(GAMES[game].cost), b.position.x, y, RED)
        y += 7.0
    if best.has(game):
        _t("YOUR BEST: %d OF 3 STARS" % int(best[game]), b.position.x, y, GREEN)


func _paint_result(b: Rect2) -> void:
    UiStyle.stars(_canvas, b.position.x + b.size.x * 0.5, b.position.y, stars)
    var y := b.position.y + 24.0
    for line in lines:
        for part in _wrap(str(line), int(b.size.x / 4.0)):
            _t(part, b.position.x, y)
            y += 7.0
    var detail := ""
    if not g.is_empty():
        match game:
            "bowling":
                detail = (
                    "YOU %d  ALAN %d  GARRISON %d  DAN %d"
                    % [
                        int(g.totals["You"]),
                        int(g.totals["Alan"]),
                        int(g.totals["Garrison"]),
                        int(g.totals["Dan"])
                    ]
                )
            "karaoke":
                detail = "PERFECT %d  GOOD %d  MISSED %d" % [int(g.perfect), int(g.good), int(g.miss)]
            "escape":
                detail = (
                    "CODE %d%d%d  TRIES %d  HINTS %d"
                    % [
                        int(g.code[0]),
                        int(g.code[1]),
                        int(g.code[2]),
                        maxi(g.guesses.size(), int(g.get("wrong", 0)) + (1 if stars > 0 else 0)),
                        int(g.hints_used)
                    ]
                )
            "dinner":
                detail = "TABLE SCORE %d OF 30" % int(g.score)
    if detail != "":
        _t(detail, b.position.x, y + 3.0, BLUE)


func _paint_bowling(b: Rect2) -> void:
    var x := b.position.x
    var y := b.position.y
    _t("FRAME %d  ROLL %d" % [int(g.frame), int(g.roll)], x, y)
    var names := ["You", "Alan", "Garrison", "Dan"]
    for i in 4:
        _t("%s %d" % [names[i].to_upper(), int(g.totals[names[i]])], x, y + 10.0 + 8.0 * float(i), BLUE if i == 0 else INK)
    var lane := Rect2(x + 78.0, y, minf(b.size.x - 82.0, 90.0), b.size.y - 18.0)
    _canvas.draw_rect(lane, Color("d9b26b"))
    _canvas.draw_rect(Rect2(lane.position.x, lane.position.y, 3.0, lane.size.y), Color("5a3a22"))
    _canvas.draw_rect(Rect2(lane.end.x - 3.0, lane.position.y, 3.0, lane.size.y), Color("5a3a22"))
    var px := lane.position.x + lane.size.x * 0.5
    var idx := 0
    for row in 4:
        for k in row + 1:
            var standing: bool = idx < int(g.pins)
            var pos := Vector2(px + (float(k) - float(row) * 0.5) * 8.0, lane.position.y + 6.0 + float(row) * 7.0)
            _canvas.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), WHITE if standing else Color("b8975a"))
            idx += 1
    if g.stage == "roll":
        var by := lane.end.y - 4.0 - (lane.size.y - 14.0) * float(g.ball)
        var bx := px + (float(g.marker) - 0.5) * lane.size.x * 0.5
        _canvas.draw_rect(Rect2(bx - 3.0, by - 3.0, 6.0, 6.0), INK)
    var bar_y := b.end.y - 8.0
    var bar := Rect2(x, bar_y, 70.0, 5.0)
    _canvas.draw_rect(bar, Color("c9d2e0"))
    if g.stage == "aim":
        _canvas.draw_rect(Rect2(bar.position.x + 28.0, bar_y, 14.0, 5.0), GREEN)
        _canvas.draw_rect(Rect2(bar.position.x + 69.0 * float(g.marker), bar_y - 2.0, 2.0, 9.0), INK)
        _t("AIM", x + 74.0 - 4.0, bar_y - 8.0, BLUE)
    elif g.stage == "power":
        _canvas.draw_rect(Rect2(bar.position.x + 52.0, bar_y, 12.0, 5.0), GREEN)
        _canvas.draw_rect(Rect2(bar.position.x, bar_y, 70.0 * float(g.power), 5.0), AMBER)
        _t("POWER", x + 74.0 - 4.0, bar_y - 8.0, BLUE)
    if str(g.msg) != "":
        _t(str(g.msg), x, bar_y - 8.0, RED if "GUTTER" in str(g.msg) else GREEN)


func _paint_karaoke(b: Rect2, hud := false) -> void:
    var x := b.position.x
    var y := b.position.y
    var top := y + (2.0 if hud else 18.0)
    if not hud:
        _t("TOTALLY LEGAL HIT (2013)", x, y, BLUE)
        _t("SCORE %d   STREAK %d" % [int(g.score), int(g.streak)], x, y + 8.0)
    var line_y := b.end.y - 12.0
    var left := b.position.x + b.size.x * 0.5 - 40.0
    for lane in 4:
        var cx := left + 20.0 * float(lane) + 10.0
        _canvas.draw_rect(Rect2(cx - 9.0, top, 18.0, line_y + 6.0 - top), Color("dde3ee"))
        _arrow(lane, Vector2(cx, line_y), 5.0, Color(LANE_COLORS[lane], 0.45))
    for n in g.notes:
        var dy: float = (float(n.time) - float(g.t)) * 45.0
        if dy < -14.0 or dy > line_y - top + 4.0:
            continue
        var col: Color = LANE_COLORS[int(n.lane)]
        if n.state == "miss":
            col = Color("8a8f9a")
        elif n.state != "":
            col = Color(col, 0.35)
        _arrow(int(n.lane), Vector2(left + 20.0 * float(n.lane) + 10.0, line_y - dy), 5.0, col)
    if float(g.flash_t) > 0.0 and not hud:
        _tc(str(g.flash), left + 80.0 + 24.0, y + 30.0, GREEN if g.flash != "MISS" else RED)
    var song := minf(1.0, float(g.t) / _song_secs())
    _canvas.draw_rect(Rect2(x, b.end.y - 4.0, b.size.x, 3.0), UiStyle.SOFT)
    _canvas.draw_rect(Rect2(x, b.end.y - 4.0, b.size.x * song, 3.0), BLUE)


func _paint_escape(b: Rect2) -> void:
    var x := b.position.x
    var y := b.position.y
    _t("TIME %d   HINTS LEFT %d   TRIES %d OF 8" % [int(float(g.time)), int(g.hints), g.guesses.size()], x, y, RED if float(g.time) < 20.0 else INK)
    var row := 0
    for entry in g.guesses:
        if row >= 8:
            break
        _t("%d %d %d  B%d C%d" % [int(entry[0][0]), int(entry[0][1]), int(entry[0][2]), int(entry[1]), int(entry[2])], x, y + 10.0 + 7.0 * float(row), INK)
        row += 1
    var bx := x + b.size.x - 74.0
    for i in 3:
        var r := Rect2(bx + 20.0 * float(i), y + 12.0, 16.0, 22.0)
        _canvas.draw_rect(r, WHITE)
        _canvas.draw_rect(Rect2(r.position.x, r.end.y - 2.0, 16.0, 2.0), BLUE if int(g.cursor) == i else Color("c9d2e0"))
        PixelFont.draw(_canvas, str(int(g.cur[i])), r.position + Vector2(5.0, 6.0), GREEN if g.revealed.has(i) else INK, 2)
    _t("U/D CHANGE   L/R MOVE", bx - 6.0, y + 40.0, Color("46506a"))
    if str(g.msg) != "":
        for part in _wrap(str(g.msg), 18):
            y += 0.0
            _t(part, bx - 6.0, y + 50.0, BLUE)
            y += 7.0


func _paint_dinner(b: Rect2) -> void:
    var x := b.position.x
    var y := b.position.y
    _t("ROUND %d OF 5   TABLE SCORE %d" % [int(g.round), int(g.score)], x, y)
    for i in 4:
        var on: bool = int(g.sel) == i and g.react.is_empty()
        if on:
            _canvas.draw_rect(Rect2(x - 1.0, y + 9.0 + 9.0 * float(i), 82.0, 8.0), Color("ffe08a"))
        _t(str(g.options[i]), x + 2.0, y + 11.0 + 9.0 * float(i))
    var rx := x + 92.0
    for i in 3:
        var who: String = DINERS[i]
        var ry := y + 9.0 + 14.0 * float(i)
        _t(who.to_upper(), rx, ry, BLUE)
        if g.react.has(who):
            var mood: String = g.react[who]
            var face := "<3" if mood == "love" else (":(" if mood == "hate" else "OK")
            if g.get("hidden", []).has(who):
                face = "??"
                mood = "meh"
            _t(face, rx + 40.0, ry, GREEN if mood == "love" else (RED if mood == "hate" else INK))
        var entry: Dictionary = known.get(who, {"likes": [], "hates": []})
        var note := ""
        if not entry.likes.is_empty():
            note += "LIKES " + ", ".join(entry.likes)
        if not entry.hates.is_empty():
            note += ("  " if note != "" else "") + "NOT " + ", ".join(entry.hates)
        _t(note.substr(0, int((b.size.x - 92.0) / 4.0)), rx, ry + 7.0, Color("46506a"))
''')

write("scripts/hints.gd", '''extends Node
# One-line control hints for the first tech day, shown at the bottom by the HUD.
# They appear on a timer while the clock runs, so the quiet first day teaches the controls.

const SHOW_SECS := 8.0
const DAY1 := [
    {"at": 4.0, "text": "ARROWS OR A/D MOVE. HOLD SHIFT TO RUN. SPACE JUMPS."},
    {"at": 24.0, "text": "E USES WHAT IS NEAR: DOORS, THE COFFEE MACHINE, CHAIRS. TAB PICKS THE TARGET."},
    {"at": 46.0, "text": "SIT AT A DESK AND PRESS E ON THE MONITOR TO OPEN THE COMPUTER. ESC CLOSES IT."},
    {"at": 68.0, "text": "P OPENS YOUR PHONE: MAIL, TICKETS AND TEXTS. Q WAVES, C ASKS A COWORKER TO FOLLOW."},
    {"at": 90.0, "text": "TICKETS APPEAR IN THE PSA. FIX THEM IN THE RMM, THEN CLOSE THEM IN THE PSA."},
]

var text := ""
var toast_text := ""
var objective := ""  # a standing reminder (the conference trip), shown when nothing else is

var _t := 0.0
var _next := 0
var _left := 0.0
var _toast_t := 0.0


func _ready() -> void:
    Campaign.day_started.connect(func(_d: int) -> void: reset())


func reset() -> void:
    text = ""
    _t = 0.0
    _next = 0
    _left = 0.0


# a short message at the bottom of the screen (hits in a nerf fight, out of darts...)
func toast(message: String, secs := 2.5) -> void:
    toast_text = message
    _toast_t = secs


func active() -> bool:
    return Campaign.active and Campaign.mode == "tech" and Campaign.day == 1 and not Game.title_mode


func _process(delta: float) -> void:
    if _toast_t > 0.0 and not Game.ui_open:
        _toast_t -= delta
        if _toast_t <= 0.0:
            toast_text = ""
    if not active():
        text = ""
        return
    if World.time_scale > 0.0:
        _t += delta
    if _left > 0.0:
        _left -= delta
        if _left <= 0.0:
            text = ""
    if _next < DAY1.size() and _t >= float(DAY1[_next].at):
        text = str(DAY1[_next].text)
        _left = SHOW_SECS
        _next += 1
''')

write("scripts/talk.gd", '''extends Node
# gdlint:disable=max-line-length
# Talking to people at their desks (campaigns). E on a coworker, seated or standing, opens a conversation:
# SMALL TALK, ASK FOR HELP (they fix one of your tickets if they like you), ANY TIPS? (advice from the live game state,
# and a short lesson from a friend once a day) and LEAVE (Esc). Owner campaign: HOW ARE YOU HOLDING UP? and ANY IDEAS?.
# Each person has a voice and a specialty: Alan servers, Garrison security, Dan networking, Vic sales. Alan and Garrison
# are the two OWNERS (Alan technical, Garrison sales and culture): they talk about payroll, clients, the van and hiring.

const SPECIALTY := {"Alan": "servers", "Garrison": "security", "Dan": "networking", "Vic": "people", "Maya": "people"}
const LESSON_XP := 6
const GREETINGS := {
    "Alan": {
        "friend": "Hey, there you are. Coffee is fresh and the books can wait ten minutes. What is up?",
        "neutral": "Yeah? I have got about a minute. Payroll is waiting.",
        "cold": "...Yes?",
    },
    "Garrison": {
        "friend": "Oh hey! Perfect timing, I just got off with a client and my brain needed a break. What is up?",
        "neutral": "Hi. What do you need? I have a client on in five.",
        "cold": "Mm. What?",
    },
    "Dan": {
        "friend": "Hey! Pull up a chair. Well, stand there. What is up?",
        "neutral": "Hey. Need something?",
        "cold": "I am kind of in the middle of something.",
    },
    "Vic": {
        "friend": "My favourite tech! Talk to me.",
        "neutral": "Hey there. Quick one, I have a call at three.",
        "cold": "Can this wait? I am on the phone in five.",
    },
    "Maya": {
        "friend": "Hi! Want half a granola bar? I have been saving it for someone nice.",
        "neutral": "Hey! Sorry, I have a user on hold. What is up?",
        "cold": "Oh. Hi. I am just finishing something.",
    },
}
const SMALL := {
    "Alan": [
        "Windows XP goes dark on April 8th. I have got a spreadsheet of every XP box we manage. It is longer than my coffee order.",
        "I have been doing this since the NT days. These days it is payroll and vendor calls, but people still ask me to turn it off and on again. They are right more often than I like to admit.",
        "My kid asked what I do. I said I make sure the printers work. She said that sounds boring. She is not wrong.",
        "Did you see the Target breach news? Every client wants to know if they are next. Garrison has been on the phone with them since eight.",
        "The van needs brakes. The books say we can afford brakes. Barely.",
        "I priced a new rack for the closet. Buy it, do not build it, unless you enjoy supporting your own script.",
    ],
    "Garrison": [
        "Everybody is changing their passwords after that Target thing. I would love it if they used something better than Summer2013.",
        "I finally beat level 90 on Sugar Smash. Do not tell Alan how many lives I spent.",
        "I keep telling clients: not every email from your bank is from your bank.",
        "Alan's new LabRat script saved the crew an hour on Tuesday. Do not tell him I said so.",
        "I am planning the next team outing. Bowling is the safe bet, karaoke is the brave one.",
        "Hiring is the hard part. Good techs are never on the market on a Monday.",
    ],
    "Dan": [
        "I labeled every patch panel port last weekend. Nobody noticed. That is how you know it was good work.",
        "Floppy Bat got pulled and I am stuck at 31. I am taking it personally.",
        "The best network is the one nobody talks about. The worst one is every one of our clients.",
        "I have been reading about Heartbleed. It is going to be a long April.",
    ],
    "Vic": [
        "Quarter is almost over and I need two more logos. Do you know anyone who hates their IT guy?",
        "I told a prospect we are the Apple of managed services. I do not know what that means either.",
        "Golf on Friday. A good relationship is built on the fifth hole.",
        "Clients love you. I just say you are the best in the building. It is only a little bit a lie.",
    ],
    "Maya":
    [
        "Today I walked a lady through plugging in her monitor. It was not plugged in. I said that was a very common problem and she felt great.",
        "I just got a Galaxy S4 and I have not turned off the camera shutter sound yet. Sorry, Dan.",
        "Alan showed me how to read an event log. I felt like a detective. A tired one.",
        "I am trying to learn PowerShell on my lunch break. It is a lot like learning French, if French had brackets.",
    ],
}
const GOSSIP := [
    "Between us: Morgan has been in the owners' office since nine. Never a good sign.",
    "I heard Vic is already negotiating next year's commission. Good for him.",
    "Somebody microwaved fish in the kitchenette again. We are not saying who.",
    "I heard the printer on the main floor jammed again. Nobody will own up to it.",
]
const TIPS_GENERIC := {
    "Alan": [
        "Restart the print spooler instead of rebooting. People who get rebooted without warning lose their work, and the client remembers it at renewal time.",
        "Verify the backups every morning. A backup you have not tested is a hope, not a backup. It is my name on the contract, not yours.",
        "Ask the user to save before you touch anything. It takes ten seconds and saves a bad email in my inbox.",
        "Buy it, do not build it. A script nobody else can read is a bus factor of one, and that one is usually me.",
    ],
    "Garrison": [
        "Never use a default or seasonal password on a remote login. That is how they get in. I say it to every prospect.",
        "If a ransom note shows up, do not reboot. Shadow copies first, backup if you have it, paying is the last resort.",
        "Two-factor login for admins first, users second. Most attacks are still just guessing.",
        "Call the client before the invoice does. A short call keeps the contract; a long silence loses it.",
    ],
    "Dan": [
        "Label both ends of every cable. Future you will buy present you a coffee.",
        "No link on a desk? Check the patch cable in the closet before you blame the switch.",
        "The UPS gives you about ninety seconds. Plan the shutdown, do not improvise it.",
    ],
    "Vic": [
        "Clients forgive a slow fix. They do not forgive silence. Call before they call you.",
        "A happy client brings me a referral. An unhappy client brings me a competitor.",
        "If you can fix it before they notice, do. If you cannot, tell them early.",
    ],
    "Maya":
    [
        "Be kind to the user first. Half of the problem is that they are scared they broke something.",
        "Say what you are going to do before you do it. 'I am going to restart your printer, one second.' Nobody gets scared.",
        "Write down every fix in the ticket. The next person at three in the morning will thank you. That might be you.",
    ],
}
const OWNER_HOLD := {
    "low": "I am good, boss. Busy, but good.",
    "mid": "Honestly? Tired. The queue never really empties.",
    "high": "I am burning out. I am not going to lie to you.",
}

var _who := ""
var _npc: Node = null
var _taught := {}  # who -> day they last taught you something
var _listened := {}  # who -> week you last asked how they are holding up


func reset() -> void:
    _who = ""
    _npc = null
    _taught = {}
    _listened = {}


func available(who: String) -> bool:
    return Campaign.active and SPECIALTY.has(who) and not Cards.is_open


func tier(who: String) -> String:
    if Social.is_friendly(who):
        return "friend"
    return "cold" if Social.is_cold(who) else "neutral"


func start(who: String, npc: Node) -> void:
    _who = who
    _npc = npc
    var p := _player()
    if p != null:
        p.start_emote("talk", 100000.0, npc.global_position.x)
    _menu(str(GREETINGS[who][tier(who)]))


func _player() -> Node:
    var scene := get_tree().current_scene
    return scene.get_node_or_null("Actors/Player") if scene != null else null


func _bubble(glyph: String) -> void:
    if _npc != null and is_instance_valid(_npc) and _npc.get("_bubble") != null:
        _npc._bubble.glyph = glyph
        _npc._bubble.visible = true


func _menu(text: String) -> void:
    var owner_mode := Campaign.mode == "owner"
    Cards.ask(_who, text, [
        {"label": "SMALL TALK", "id": "small"},
        {"label": "HOW ARE YOU HOLDING UP?" if owner_mode else "ASK FOR HELP", "id": "ask"},
        {"label": "ANY IDEAS?" if owner_mode else "ANY TIPS?", "id": "tip"},
        {"label": "LEAVE (ESC)", "id": "leave"},
    ], func(id: String) -> void: _pick(id))


func _pick(id: String) -> void:
    match id:
        "small":
            _reply(small_talk())
        "ask":
            _reply(holding_up() if Campaign.mode == "owner" else ask_help())
        "tip":
            _reply(owner_idea() if Campaign.mode == "owner" else tip())
        _:
            _leave()


func _reply(text: String) -> void:
    Cards.ask(_who, text, [{"label": "OK", "id": "ok"}, {"label": "LEAVE (ESC)", "id": "leave"}], func(id: String) -> void: _after(id))


func _after(id: String) -> void:
    if id == "leave":
        _leave()
    else:
        _menu("Anything else?")


func _leave() -> void:
    var p := _player()
    if p != null:
        p.start_emote("idle", 0.05)
    if _npc != null and is_instance_valid(_npc) and _npc.has_method("talk_end"):
        _npc.talk_end()
    _who = ""
    _npc = null


# ---- the topics --------------------------------------------------------------------------------
func small_talk() -> String:
    Social.note_chat(_who)
    var lines: Array = SMALL[_who]
    var text: String = lines[randi() % lines.size()]
    _bubble(Social.glyph(_who))
    if tier(_who) == "cold":
        return "Mm. " + text.split(".")[0] + "."
    if randf() < 0.25:
        text += " " + str(GOSSIP[randi() % GOSSIP.size()])
    return text


func ask_help() -> String:
    var res := str(Lync.send_action(_who, "help"))
    var last := ""
    if Lync.chats.has(_who) and not Lync.chats[_who].is_empty():
        last = str(Lync.chats[_who][-1][1])
    _bubble("heart" if res == "help" and Social.is_friendly(_who) else "dots")
    return last if last != "" else "Sorry, I am swamped."


func tip() -> String:
    Social.note_chat(_who)
    _bubble("!")
    var text := _state_tip()
    if text == "":
        var pool: Array = TIPS_GENERIC[_who]
        text = pool[randi() % pool.size()]
    if tier(_who) == "cold":
        return text.split(".")[0] + ". That is all you are getting."
    var skill := str(SPECIALTY[_who])
    if Social.is_friendly(_who) and int(_taught.get(_who, -1)) != Campaign.day:
        _taught[_who] = Campaign.day
        Skills.add_xp(skill, LESSON_XP)
        text += " (+%d %s XP: they walk you through it.)" % [LESSON_XP, str(Skills.NAMES[skill])]
    elif not Social.is_friendly(_who):
        text += " (Get on their good side and they will teach you more.)"
    return text


# advice built from what is actually going on right now
func _state_tip() -> String:
    match _who:
        "Alan":
            for c in Sales.active:
                if not Msp.backups[int(c)].ok:
                    return "I was in the console before nine and %s's backup is red. Check it before it matters." % str(Msp.CLIENTS[int(c)].name)
        "Dan":
            for d in range(1, 9):
                if Net.desk_state(d) != "ok":
                    return "%s has no network. Look at the patch panel in the closet first." % str(Msp.DESK_NAMES.get(d, "A desk"))
        "Vic":
            var worst := -1
            for c in Sales.active:
                if worst < 0 or Sales.mood(int(c)) < Sales.mood(worst):
                    worst = int(c)
            if worst >= 0 and Sales.mood(worst) < 55:
                return "%s sounded annoyed when I called. Give them some attention before they start shopping around." % str(Msp.CLIENTS[worst].name)
        "Garrison":
            if Msp.breached > 0:
                return "I walked the floor and saw the SLA misses on the board. Clients bring those up at the QBR. Fix the P1s first, always. The rest can wait ten minutes."
        "Maya":
            for t in Msp.open_tickets():
                if float(t.sla_left) < 60.0 and not bool(t.breached):
                    return "Ticket #%d is almost out of time. I would hate for that to be a miss. Want a hand?" % int(t.id)
    return ""


# ---- owner campaign ---------------------------------------------------------------------------
func holding_up() -> String:
    var level := "low" if Owner.burnout < 30.0 else ("mid" if Owner.burnout < 60.0 else "high")
    var text: String = OWNER_HOLD[level]
    _bubble("heart")
    if int(_listened.get(_who, -1)) != Campaign.day:
        _listened[_who] = Campaign.day
        Owner.burnout = clampf(Owner.burnout - 2.0, 0.0, 100.0)
        Social.note_chat(_who)
        text += " Thanks for asking, though. It helps."
    return text


func owner_idea() -> String:
    Social.note_chat(_who)
    _bubble("!")
    var text := ""
    match _who:
        "Alan":
            text = "If you want fewer fires: patch on time and keep the backups green."
            if Msp.open_tickets().size() >= 5:
                text = "The queue is backed up. Another pair of hands would help more than a new tool."
        "Garrison":
            text = "Good call on the backups. Next, get remote access off the open internet."
            if not Owner.flags.get("backup_service", false):
                text = "Every client without a managed backup is one bad day from calling a lawyer. We should sell the backup service."
        "Dan":
            text = "Label everything and write it down. The day Alan is on vacation you will be glad."
            for c in Sales.active:
                if float(Owner.patch_debt.get(int(c), 0.0)) >= 4.0:
                    text = "Updates are piling up at %s. That is how somebody else's engineer ends up on their server." % str(Msp.CLIENTS[int(c)].name)
                    break
        _:
            text = "The pipeline is thin. A team night would not hurt either; the crew has not had one."
    return text
''')

write("scripts/meeting.gd", '''extends Node
# gdlint:disable=max-line-length
# The weekly all-hands (campaigns): on the first day of every week after the first (days 6, 11 and 16) at 14:00 the
# boss calls everyone to the conference room. The whole cast goes and sits down. If YOU are in the conference room
# a few minutes later you attend: a short briefing and a question to ask. Skip it and the boss notices (reputation -1).
# Owner campaign: you are the one giving the all-hands (share the numbers, thank the team, set a priority).

const MEETING_DAYS := [6, 11, 16]
const CALL_AT := 14.0
const HOLD_AT := 14.2
const BOOKS := {
    "rack": "a client's network rack", "migration": "a server migration", "email24": "an email server that never sleeps",
    "netinstall": "a network install", "rdp": "a security scare at a client",
    "ceofraud": "a suspicious wire request", "no2fa": "a client who says no", "bus": "a day without Alan",
}

var state := ""  # "", "called", "done"
var done_day := -1
var attended := 0
var missed := 0


func _ready() -> void:
    Campaign.day_started.connect(func(_d: int) -> void: state = "")


func reset() -> void:
    state = ""
    done_day = -1
    attended = 0
    missed = 0


func is_meeting_day(day: int) -> bool:
    return Campaign.active and MEETING_DAYS.has(day)


func to_dict() -> Dictionary:
    return {"attended": attended, "missed": missed}


func from_dict(data: Dictionary) -> void:
    reset()
    attended = int(data.get("attended", 0))
    missed = int(data.get("missed", 0))


func _process(_delta: float) -> void:
    if not Campaign.active or Game.title_mode or World.time_scale <= 0.0 or Cards.is_open:
        return
    if not is_meeting_day(Campaign.day) or done_day == Campaign.day or World.clock >= World.DAY_END:
        return
    if state == "" and World.clock > HOLD_AT + 0.05:
        state = "done"  # the clock jumped past it (a trip, a long job): nobody holds it without you
        done_day = Campaign.day
        return
    if state == "" and World.clock >= CALL_AT:
        call_meeting()
    elif state == "called" and World.clock >= HOLD_AT:
        hold()


func call_meeting() -> void:
    state = "called"
    Msp.send_text("Boss", "All-hands in the conference room in a few minutes. Everyone.")
    World.start_all_hands()


func in_conference() -> bool:
    var scene := get_tree().current_scene
    return scene != null and scene.scene_file_path.get_file().get_basename() == "conference"


func hold() -> void:
    state = "done"
    done_day = Campaign.day
    if in_conference():
        attended += 1
        Career.add("meetings")
        Social.change_all(1)
        Skills.add_xp("people", 3)
        if Campaign.mode == "owner":
            _run_owner()
        else:
            _run_tech()
        return
    missed += 1
    if Campaign.mode == "owner":
        Owner.burnout = clampf(Owner.burnout + 2.0, 0.0, 100.0)
        Msp.send_text("Alan", "Boss, the team waited in the conference room for the all-hands. Everyone noticed.")
    else:
        Campaign.adjust_rep(-1)
        Msp.send_text("Boss", "You missed the all-hands. I noticed. Be there next week.")


# ---- the tech campaign: Morgan runs it
func _unhappiest() -> int:
    var worst := -1
    for c in Sales.active:
        if worst < 0 or Sales.mood(int(c)) < Sales.mood(worst):
            worst = int(c)
    return worst


func _run_tech() -> void:
    var text := "Quick all-hands. Alan and Garrison asked me to share the numbers: reputation is %d and our clients are %d%% happy. " % [Campaign.rep, int(Sales.average())]
    text += ["Remember to ask users to save before you reboot anything.", "Verify the backups every morning.", "Close what you fix, and tell clients early when you cannot."][(Campaign.day / 5) % 3]
    Cards.ask("Morgan (Manager)", text, [
        {"label": "ASK ABOUT THE CLIENTS", "id": "clients"},
        {"label": "ASK ABOUT TRAINING", "id": "training"},
        {"label": "WHAT IS COMING UP?", "id": "ahead"},
        {"label": "STAY QUIET", "id": "quiet"},
    ], func(id: String) -> void: _answer(id))


func _answer(id: String) -> void:
    var text := "Morgan nods and wraps up the meeting."
    match id:
        "clients":
            var worst := _unhappiest()
            if worst >= 0:
                text = "%s is the one I worry about: %d%% happy. Call before they call you." % [str(Msp.CLIENTS[worst].name), Sales.mood(worst)]
            Skills.add_xp("people", 3)
        "training":
            var pick := "servers"
            for key in ["security", "networking"]:
                if Skills.level(key) < Skills.level(pick):
                    pick = key
            Skills.add_xp(pick, 6)
            text = "Your weakest area is %s. I will put a few hours of reading in your queue. (+6 %s XP)" % [str(Skills.NAMES[pick]).to_lower(), str(Skills.NAMES[pick])]
        "ahead":
            text = _preview()
    Cards.ask("Morgan (Manager)", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


# what is on the calendar for the next five days
func _preview() -> String:
    var names := []
    for d in range(Campaign.day + 1, Campaign.day + 6):
        for ev in Story.DAYS.get(d, []):
            var kind := str(ev.get("kind", ""))
            if kind == "playbook" and BOOKS.has(str(ev.book)):
                names.append(str(BOOKS[str(ev.book)]))
            elif kind == "install":
                names.append("a desktop install")
            elif kind == "ransomware":
                names.append("trouble at the law firm")
    if names.is_empty():
        return "Nothing scary on the calendar this week. Use the quiet to study."
    return "Coming up this week: %s. Be ready." % ", ".join(names)


# ---- the owner campaign: you give the all-hands
func _run_owner() -> void:
    Cards.ask("All-hands", "Your whole crew is here, coffee in hand. What do you want to say?", [
        {"label": "SHARE THE NUMBERS", "id": "numbers"},
        {"label": "THANK THE TEAM", "id": "thanks"},
        {"label": "SET A PRIORITY: BACKUPS AND UPDATES", "id": "priority"},
        {"label": "KEEP IT SHORT", "id": "short"},
    ], func(id: String) -> void: _owner_answer(id))


func _owner_answer(id: String) -> void:
    var text := "Short and sweet. Everybody gets back to work."
    match id:
        "numbers":
            Owner.burnout = clampf(Owner.burnout - 3.0, 0.0, 100.0)
            text = "You walk them through cash, clients and where the company is headed. Transparency feels good. (burnout -3)"
        "thanks":
            Owner.burnout = clampf(Owner.burnout - 2.0, 0.0, 100.0)
            Social.change_all(2)
            text = "You thank each of them by name. Dan looks a little misty. (burnout -2, the team likes you more)"
        "priority":
            for c in Sales.active:
                Owner.patch_debt[int(c)] = maxf(0.0, float(Owner.patch_debt.get(int(c), 0.0)) - 1.0)
            text = "Backups and updates come first this week. The crew gets a clear target. (patch debt down)"
    Cards.ask("All-hands", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
''')

write("scripts/nerf.gd", '''extends Node
# gdlint:disable=max-line-length
# Nerf guns. Take a blaster from the rack in the cubicle area (E; E again to reload), Z fires a foam dart, G puts it away.
# Darts fly in an arc, stick in walls and furniture (monitors flicker), and hit people: coworkers react in character,
# friendly ones laugh and fire back (a short nerf war in the room), and walking over a dart on the floor picks it up.
# In a campaign a hit relieves a little stress (+1 energy, up to 4 a day) and moves opinions.

const DART := preload("res://scripts/dart.gd")
const AIM := preload("res://scripts/aim.gd")
const MAX_AMMO := 6
const SPEED := 175.0
const CHARGE_SECS := 1.1  # holding Z this long = a full-power lob
const LOB_SPEED := 120.0  # extra forward speed at full charge
const LOB_LIFT := 58.0  # extra upward speed at full charge
const FIRE_GAP := 0.4
const WAR_SECS := 45.0
const DUCK_TOP := 40.0  # a ducking person is this tall (standing: 84)
const REACT := {
    "Alan": {"base": -1, "friendly": "heart", "line": "Alan: Not at my desk, please.", "mood": "!"},
    "Garrison": {"base": 1, "friendly": "heart", "line": "Garrison: Oh, it is ON.", "mood": "!"},
    "Maya": {"base": 1, "friendly": "heart", "line": "Maya: Hey! My granola bar!", "mood": "!"},
    "Dan": {"base": 1, "friendly": "heart", "line": "Dan: Okay, that was a good shot.", "mood": "dots"},
    "Vic": {"base": 1, "friendly": "heart", "line": "Vic: Careful, I have a client call at two!", "mood": "!"},
}

var ammo := 0
var hits := 0  # total hits on coworkers
var taken := 0
var war_t := 0.0
var war_hits := 0
var war_taken := 0
var dodges := 0  # darts people ducked under
# the score of the war in progress (see war_result)
var war_dodged := 0  # darts you ducked
var war_missed := 0  # your darts they ducked
var war_ff := 0  # coworkers hit by coworkers
var war_assists := 0  # ... within 2.5 s of your own hit on the same person
var war_longest := 0  # longest hit of yours, px
var last_result := {}

var charge := 0.0
var charging := false

var _cool := 0.0
var _preview: Node2D = null
var _energy_today := 0
var _energy_day := -1
var _shot_t := {}  # name -> seconds until the next war shot
var _dodge_ms := 0
var _hit_ms := {}  # name -> when you last hit them


func _ready() -> void:
    Campaign.day_started.connect(func(_d: int) -> void: _energy_today = 0)


func reset() -> void:
    ammo = 0
    hits = 0
    taken = 0
    war_t = 0.0
    war_hits = 0
    war_taken = 0
    _reset_score()
    _energy_today = 0


func _reset_score() -> void:
    war_dodged = 0
    war_missed = 0
    war_ff = 0
    war_assists = 0
    war_longest = 0
    _hit_ms = {}


func _scene() -> Node:
    return get_tree().current_scene


func _player() -> Node:
    var scene := _scene()
    return scene.get_node_or_null("Actors/Player") if scene != null else null


func holding() -> bool:
    var p := _player()
    return p != null and str(p.get("held")) == "nerf"


func on_given() -> void:
    ammo = MAX_AMMO
    Hints.toast("Z FIRES, HOLD Z TO LOB, S OR DOWN TO DUCK.", 4.0)


# ---- firing ------------------------------------------------------------------------------------------
func fire_player(p: Node, power := 0.0) -> bool:
    if str(p.held) != "nerf" or ammo <= 0 or _cool > 0.0 or Game.ui_open or Game.busy:
        if str(p.held) == "nerf" and ammo <= 0:
            Hints.toast("OUT OF DARTS. PICK THEM UP OR RELOAD AT THE RACK (E).", 2.5)
        return false
    if p.state not in ["idle", "walk", "run", "sitting", "emote"]:
        return false
    _cool = FIRE_GAP
    ammo -= 1
    var dir := 1.0 if p.facing == "right" else -1.0
    if p.state != "sitting":
        p.start_emote("reach", 0.22)
    _spawn(_muzzle(p, dir), dir, "Player", power)
    return true


# hold Z to aim: the longer you hold, the higher and further the dart goes; a tap is a quick shot
func charge_start(p: Node) -> void:
    if charging or str(p.held) != "nerf" or Game.ui_open or Game.busy:
        return
    if ammo <= 0:
        fire_player(p)  # the "out of darts" message
        return
    if p.state not in ["idle", "walk", "run"]:
        return
    charging = true
    charge = 0.0
    p.start_emote("hold", 100000.0)
    _preview = AIM.new()
    _preview.z_index = 30
    _scene().get_node("Actors").add_child(_preview)


func charge_release(p: Node) -> void:
    if not charging:
        return
    charging = false
    var power := charge if charge > 0.12 else 0.0
    charge = 0.0
    if _preview != null and is_instance_valid(_preview):
        _preview.queue_free()
    _preview = null
    _cool = 0.0
    fire_player(p, power)


func launch_velocity(dir: float, power: float) -> Vector2:
    return Vector2(dir * (SPEED + power * LOB_SPEED), -14.0 - power * LOB_LIFT)


func _update_charge(delta: float) -> void:
    var p := _player()
    if p == null or str(p.held) != "nerf" or Game.ui_open:
        charging = false
        charge = 0.0
        if _preview != null and is_instance_valid(_preview):
            _preview.queue_free()
        _preview = null
        return
    charge = minf(1.0, charge + delta / CHARGE_SECS)
    var dir := 1.0 if p.facing == "right" else -1.0
    if _preview != null and is_instance_valid(_preview):
        _preview.set_path(_muzzle(p, dir), launch_velocity(dir, charge))


func fire_npc(npc: Node, dir: float, power := 0.0) -> void:
    if not is_instance_valid(npc):
        return
    if npc.seat == null and npc._hold <= 0.0:
        npc._begin_hold("reach", 0.3)
    _spawn(_muzzle(npc, dir), dir, str(npc.cast_name), power)


# shoulder height, so darts clear desks and low furniture when you stand beside them
func _muzzle(who: Node, _dir: float) -> Vector2:
    var seated: bool = who.get("seat") != null
    return who.global_position + Vector2(_dir * 9.0, -40.0 if seated else -54.0)


func _spawn(pos: Vector2, dir: float, shooter: String, power := 0.0) -> void:
    var scene := _scene()
    if scene == null:
        return
    var dart := DART.new()
    dart.shooter = shooter
    dart.vel = launch_velocity(dir, power) + Vector2(0.0, Difficulty.rng("nerf").randf_range(-3.0, 3.0))
    dart.position = pos
    dart.set_meta("x0", pos.x)
    scene.get_node("Actors").add_child(dart)


# the sales bell (a fx in group "bells"): a dart that reaches it rings it
func hit_bell(pos: Vector2) -> bool:
    for b in get_tree().get_nodes_in_group("bells"):
        if b.hit_test(pos):
            b.ring("dart")
            return true
    return false


# ---- what a dart can hit -----------------------------------------------------------------------------
func is_ducking(who: Node) -> bool:
    return who.get("ducking") == true or who.get("state") == "duck"


# does the dart at pos hit this body? a ducking body is lower, so a high shot flies over (a dodge)
func _hits(who: Node, pos: Vector2, dart: Node) -> bool:
    if absf(who.global_position.x - pos.x) >= 8.0:
        return false
    var below: bool = pos.y > who.global_position.y - 84.0 and pos.y < who.global_position.y - 4.0
    if not below:
        return false
    if is_ducking(who) and pos.y < who.global_position.y - DUCK_TOP:
        if dart != null and not dart.has_meta("dodged"):
            dart.set_meta("dodged", true)
            _dodged(who, str(dart.shooter))
        return false
    return true


func _dodged(who: Node, shooter: String) -> void:
    dodges += 1
    if who.get("cast_name") == null:
        Career.add("nerf_dodges")
        if war_t > 0.0:
            war_dodged += 1
    elif shooter == "Player" and war_t > 0.0:
        war_missed += 1
    if who.get("cast_name") == null and Time.get_ticks_msec() - _dodge_ms > 3000:
        _dodge_ms = Time.get_ticks_msec()
        Hints.toast("DUCKED!", 1.2)
    elif shooter == "Player":
        Hints.toast("MISSED! THEY DUCKED.", 1.6)


func find_victim(pos: Vector2, shooter: String, dart: Node = null) -> Node:
    for npc in get_tree().get_nodes_in_group("npcs"):
        if str(npc.cast_name) == shooter or npc.get("_hidden") == true or not npc.visible:
            continue
        if _hits(npc, pos, dart):
            return npc
    var p := _player()
    if p != null and shooter != "Player" and _hits(p, pos, dart):
        return p
    return null


# a wall, or a prop sprite (desks, monitors, chairs): the dart sticks to it
func stick_target(pos: Vector2) -> Node:
    var scene := _scene()
    if scene == null:
        return null
    var name := scene.scene_file_path.get_file().get_basename()
    var info: Dictionary = World.DATA.SCENES.get(name, {})
    if not info.is_empty() and (pos.x < float(info.x0) + 2.0 or pos.x > float(info.x0) + float(info.W) - 2.0):
        return scene
    for child in scene.get_node("Actors").get_children():
        if child is Sprite2D and child.texture != null:
            var origin: Vector2 = child.global_position + child.offset
            if Rect2(origin, child.texture.get_size()).has_point(pos):
                return child
    return null


func dart_hit(dart: Node, victim: Node) -> void:
    if victim.has_method("sit") and victim.get("cast_name") == null:
        _hit_player(victim, str(dart.shooter))
    else:
        _hit_npc(victim, str(dart.shooter), dart)


func _hit_npc(npc: Node, shooter: String, dart: Node = null) -> void:
    var who := str(npc.cast_name)
    var react: Dictionary = REACT.get(who, REACT["Dan"])
    if shooter == "Player":
        hits += 1
        var reach := 0.0
        if dart != null:
            reach = absf(dart.position.x - float(dart.get_meta("x0", dart.position.x)))
        Career.note_nerf_hit(reach)
        _hit_ms[who] = Time.get_ticks_msec()
        if war_t > 0.0:
            war_hits += 1
            war_longest = maxi(war_longest, roundi(reach))
        var delta: int = int(react.base)
        var friendly := Social.is_friendly(who)
        if friendly:
            delta = 2
        elif Social.is_cold(who):
            delta = -2
        Social.change(who, delta)
        npc.react_hit(str(react.friendly) if delta > 0 else str(react.mood))
        Hints.toast("HIT! " + str(react.line), 2.6)
        _relieve()
        if delta > 0:
            # a coworker who takes it well fires back at once (from the desk if they are sitting)
            if war_t <= 0.0:
                start_war()
                war_hits = 1  # the hit that started the war counts
                war_longest = roundi(reach)
            _shot_t[who] = 0.8
    else:
        npc.react_hit("!")
        if war_t > 0.0:
            war_ff += 1
            if Time.get_ticks_msec() - int(_hit_ms.get(who, -99999)) < 2500:
                war_assists += 1


func _hit_player(p: Node, shooter: String) -> void:
    taken += 1
    war_taken += 1 if war_t > 0.0 else 0
    if p.state != "sitting" and p.state != "death":
        p.start_emote("hurt", 0.45)
    p._ensure_bubble()
    p._bubble.glyph = "!"
    p._bubble.visible = true
    Social.change(shooter, 1)
    Hints.toast("%s GOT YOU!" % shooter.to_upper(), 2.0)
    _relieve()


func _relieve() -> void:
    if Campaign.active and _energy_today < 4:
        _energy_today += 1
        Shift.add_energy(1.0)


# ---- the war ------------------------------------------------------------------------------------------
func start_war() -> void:
    war_t = WAR_SECS
    war_hits = 0
    war_taken = 0
    _reset_score()
    _shot_t = {}
    for npc in get_tree().get_nodes_in_group("npcs"):
        if npc.get("_hidden") != true:
            npc.give_item("nerf")  # everybody in the room, sitting or standing
        _shot_t[str(npc.cast_name)] = Difficulty.rng("nerf").randf_range(1.5, 3.5)
    Hints.toast("NERF WAR! THEY ARE FIRING BACK.", 3.0)


func _end_war() -> void:
    war_t = 0.0
    for npc in get_tree().get_nodes_in_group("npcs"):
        if is_instance_valid(npc) and str(npc.held) == "nerf":
            npc.give_item("")
    var s := war_result()
    last_result = s
    Career.add("nerf_wars")
    var msg := "NERF WAR OVER: YOU HIT %d, THEY GOT YOU %d" % [war_hits, war_taken]
    if not s.titles.is_empty():
        msg += ". " + ", ".join(PackedStringArray(s.titles))
    Hints.toast(msg, 5.0)
    if Campaign.active:
        Social.change_all(1)


# the score card of a war: hits, taken, dodged (you), missed (they), friendly fire, assists, longest hit (px), titles
func war_result() -> Dictionary:
    var s := {
        "hits": war_hits,
        "taken": war_taken,
        "dodged": war_dodged,
        "missed": war_missed,
        "ff": war_ff,
        "assists": war_assists,
        "longest": war_longest,
    }
    s["titles"] = war_titles(s)
    return s


func war_titles(s: Dictionary) -> Array:
    var out := []
    if int(s.dodged) >= 3:
        out.append("MOST DUCKED")
    if int(s.longest) >= 150:
        out.append("SNIPER")
    if int(s.ff) >= 3:
        out.append("FRIENDLY FIRE")
    if int(s.assists) >= 2:
        out.append("TEAM PLAYER")
    if int(s.hits) >= 5 and int(s.taken) == 0:
        out.append("UNTOUCHABLE")
    return out


func _process(delta: float) -> void:
    _cool = maxf(0.0, _cool - delta)
    if charging:
        _update_charge(delta)
    if war_t <= 0.0:
        return
    war_t -= delta
    if war_t <= 0.0 or _scene() == null:
        _end_war()
        return
    for npc in get_tree().get_nodes_in_group("npcs"):
        var who := str(npc.cast_name)
        if npc.get("_hidden") == true or not _shot_t.has(who) or str(npc.held) != "nerf":
            continue
        _shot_t[who] = float(_shot_t[who]) - delta
        if float(_shot_t[who]) <= 0.0:
            _shot_t[who] = Difficulty.rng("nerf").randf_range(2.0, 4.5) * Difficulty.f("nerf.gap")
            _npc_shoots(npc)


func _npc_shoots(npc: Node) -> void:
    var targets := []
    var p := _player()
    if p != null:
        targets.append(p)
    for other in get_tree().get_nodes_in_group("npcs"):
        if other != npc and other.get("_hidden") != true:
            targets.append(other)
    if targets.is_empty():
        return
    var target: Node = Difficulty.pick(targets, "nerf")
    var dx: float = target.global_position.x - npc.global_position.x
    var dir := 1.0 if dx >= 0.0 else -1.0
    if npc.seat == null:
        npc.facing = "right" if dir > 0.0 else "left"
        npc._play("idle")
    # lob it when the target is far away
    fire_npc(npc, dir, clampf((absf(dx) - 110.0) / 200.0, 0.0, 1.0))


func gone(dart: Node) -> void:
    # a dart that came to rest on the floor can be collected
    var p := _player()
    if p != null and str(p.held) == "nerf" and ammo < MAX_AMMO and absf(p.global_position.x - dart.global_position.x) < 10.0:
        ammo += 1
        dart.queue_free()
''')

write("scripts/dart.gd", '''extends Node2D
# A foam dart: arcs through the air, sticks in walls and props, hits people or lands on the floor.

const GRAVITY := 75.0
const FLOOR_Y := 116.0

var vel := Vector2.ZERO
var shooter := ""
var state := "fly"  # fly, stuck, floor
var _age := 0.0
var _trail: Array = []


func _ready() -> void:
    add_to_group("darts")
    z_index = 20


func _process(delta: float) -> void:
    _age += delta
    queue_redraw()
    if state == "fly":
        _fly(delta)
    elif _age > 45.0:
        queue_free()
    elif state == "floor":
        Nerf.gone(self)


func _fly(delta: float) -> void:
    _trail.append(global_position)
    if _trail.size() > 6:
        _trail.pop_front()
    position += vel * delta
    vel.y += GRAVITY * delta
    if not has_meta("belled") and Nerf.hit_bell(global_position):
        set_meta("belled", true)
        vel = Vector2(-vel.x * 0.2, 25.0)
        return
    var victim := Nerf.find_victim(global_position, shooter, self)
    if victim != null:
        Nerf.dart_hit(self, victim)
        position.x -= signf(vel.x) * 4.0
        _land()
        return
    var target := Nerf.stick_target(global_position)
    if target != null:
        state = "stuck"
        _age = 0.0
        if target is Sprite2D:
            var fx: Node = target.get_node_or_null("Fx")
            if fx != null and fx.has_method("hit"):
                fx.hit()
        return
    if position.y >= FLOOR_Y or _age > 4.0:
        _land()


func _land() -> void:
    state = "floor"
    position.y = FLOOR_Y
    _age = 0.0


func _draw() -> void:
    var d := signf(vel.x) if vel.x != 0.0 else 1.0
    var orange := Color("ff8a1f")
    var ink := Color("17121f")
    if state == "floor":
        draw_rect(Rect2(-5, -2, 10, 4), ink)
        draw_rect(Rect2(-4, -1, 5, 2), orange)
        draw_rect(Rect2(1, -1, 3, 2), Color("ffd23c"))
        return
    if state == "fly":
        for i in _trail.size():
            var a := 0.12 + 0.07 * float(i)
            draw_rect(Rect2(to_local(_trail[i]) - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.85, 0.3, a))
    var tilt := clampf(vel.y / 150.0, -1.0, 1.0)
    draw_rect(Rect2(-5.0, -2.0 + tilt, 10, 4), ink)
    draw_rect(Rect2(-4.0 if d > 0.0 else -3.0, -1.0 + tilt, 7, 2), orange)
    draw_rect(Rect2(2.0 if d > 0.0 else -4.0, -1.0 + tilt, 2, 2), Color("ffd23c"))
''')

write("scripts/aim.gd", '''extends Node2D
# The dotted arc that shows where a charged dart will go. Dots are in world coordinates.

const STEP := 0.05
const GRAVITY := 75.0
const FLOOR_Y := 116.0

var _dots := PackedVector2Array()


func set_path(start: Vector2, vel: Vector2) -> void:
    _dots = PackedVector2Array()
    var pos := start
    var v := vel
    for i in 90:
        _dots.append(pos)
        v.y += GRAVITY * STEP
        pos += v * STEP
        if pos.y >= FLOOR_Y:
            _dots.append(Vector2(pos.x, FLOOR_Y))
            break
    queue_redraw()


func _draw() -> void:
    for i in _dots.size():
        var last := i == _dots.size() - 1
        if last:
            draw_rect(Rect2(_dots[i] - Vector2(3, 3), Vector2(7, 7)), Color("17121f"))
            draw_rect(Rect2(_dots[i] - Vector2(2, 2), Vector2(5, 5)), Color("ff8a1f"))
            draw_rect(Rect2(_dots[i] - Vector2(1, 1), Vector2(3, 3)), Color("ffe08a"))
        elif i % 2 == 0:
            draw_rect(Rect2(_dots[i] - Vector2(3, 3), Vector2(6, 6)), Color("17121f"))
            draw_rect(Rect2(_dots[i] - Vector2(2, 2), Vector2(4, 4)), Color("ffe08a"))
''')

write("scripts/strings.gd", '''extends Node
# gdlint:disable=max-line-length
# Story text you can edit without touching code. The game's mails, texts, jobs, cards, dialogue, forum threads and
# endings live in data tables in the scripts (the defaults); `res://story/strings.txt` holds every one of those
# strings as plain text under a [key]. At startup this autoload reads the file and replaces the defaults with what
# it says, so editing the file changes the game. Rules: a string that is missing from the file keeps its default,
# a key that does not exist is reported (not an error), a line starting with # is a comment, and a replacement
# must keep the same %s / %d placeholders as the original (otherwise it is ignored and reported).
# tests/story_export.gd writes the file (--init), refreshes it after the code changes (--sync, keeps your edits)
# and writes the readable story bible res://story/STORY.md (--doc).

const FILE := "res://story/strings.txt"
const ROOTS := {
    "Story": ["DAYS", "VIGNETTES"],
    "Playbook": ["BOOKS", "PROBLEMS"],
    "Owner": ["CARDS"],
    "Msp": ["PROBLEMS", "RANSOM", "ADOBE", "INSTALL"],
    "Talk": ["GREETINGS", "SMALL", "GOSSIP", "TIPS_GENERIC", "OWNER_HOLD"],
    "Nerds": ["JOKES", "THREADS"],
    "Lync": ["MESSAGES"],
    "Review": ["QUOTES", "OWNER_QUOTES", "EPILOGUES"],
    "Social": ["THANKS"],
    "Shift": ["WEEK_TRAFFIC", "REASONS", "PAGES"],
    "Hints": ["DAY1"],
    "Career": ["MEDALS", "UNLOCKS"],
    "Growth": ["STRETCH"],
    "Expo": ["TEXT", "ROUNDS", "VENDORS", "CHATS"],
    "PrinterGame": ["TEXT", "QUESTIONS", "MODEL_TEXT"],
    "Onsite": ["TEXT", "JOBS", "MORE_JOBS", "EVENTS", "STAFF", "SITE_APPS", "PETS", "FINDINGS", "MEETINGS"],
}
# fields that are always text (even when short, like OK) and fields that never are
const TEXT_KEYS := ["title", "text", "body", "subject", "from", "label", "speaker", "note", "summary", "reply", "desc", "line", "error", "situation", "result"]
const SKIP_KEYS := ["kind", "fix", "flag", "unflag", "needs", "id", "special", "specials", "book", "event", "card", "skill", "trait", "show", "effect", "req", "fx", "stack", "client", "unless"]
const BANNED := ["chatgpt", " ai ", "artificial intelligence", "microsoft teams", "slack", "microsoft 365", "office 365", "tiktok", "discord", "windows 10", "windows 11", "gdpr", "mfa ", "edr", "zoom call"]

var report: Array = []  # what went wrong (or was suspicious) while loading the file
var applied := 0
var loaded := false


func _ready() -> void:
    load_file()
    for line in report:
        push_warning("story/strings.txt: " + str(line))


# ---- the data tables ---------------------------------------------------------------------------
func _node(root: String) -> Node:
    return get_node_or_null("/root/" + root)


func _defaults(root: String, name: String) -> Variant:
    var node := _node(root)
    if node == null:
        return null
    var map: Dictionary = node.get_script().get_script_constant_map()
    return map.get("DEFAULT_" + name, null)


func is_text(key: String, value: String) -> bool:
    if key in SKIP_KEYS:
        return false
    if key in TEXT_KEYS:
        return true
    return value.length() >= 15 and value.contains(" ")


# every editable string of the defaults: [{key, text, path}]
func entries() -> Array:
    var out := []
    for root in ROOTS:
        for name in ROOTS[root]:
            var data: Variant = _defaults(str(root), str(name))
            if data != null:
                _walk(data, [str(root), str(name)], "", out)
    return out


func _walk(value: Variant, path: Array, hint: String, out: Array) -> void:
    if value is Dictionary:
        for k in value:
            _walk(value[k], path + [str(k)], str(k), out)
    elif value is Array:
        for i in value.size():
            _walk(value[i], path + [str(i)], hint, out)
    elif value is String and is_text(hint, value):
        out.append({"key": ".".join(path), "text": value, "path": path})


# ---- reading the file ---------------------------------------------------------------------------
# [key] lines start an entry; the lines under it are joined with single spaces; # lines are comments
func parse(content: String) -> Dictionary:
    var out := {}
    var key := ""
    var parts: Array = []
    for raw in content.split("\\n"):
        var line := raw.strip_edges()
        if line.begins_with("#"):
            continue
        if line.begins_with("[") and line.ends_with("]") and line.length() > 2:
            if key != "":
                out[key] = " ".join(parts)
            key = line.substr(1, line.length() - 2)
            parts = []
        elif key != "" and line != "":
            parts.append(line)
    if key != "":
        out[key] = " ".join(parts)
    return out


func load_file(path := FILE) -> int:
    report = []
    applied = 0
    loaded = false
    if not FileAccess.file_exists(path):
        return 0
    loaded = true
    var table := parse(FileAccess.get_file_as_string(path))
    var known := {}
    for e in entries():
        known[str(e.key)] = e
    for key in table:
        if not known.has(key):
            report.append("UNKNOWN KEY (ignored): [%s]" % key)
            continue
        var text: String = table[key]
        var original: String = known[key].text
        if text == original:
            continue
        if text == "":
            report.append("EMPTY (kept the default): [%s]" % key)
            continue
        if _placeholders(text) != _placeholders(original):
            report.append("PLACEHOLDERS CHANGED (ignored): [%s] must keep %s" % [key, str(_placeholders(original))])
            continue
        if _store(known[key].path, text):
            applied += 1
            _scan_banned(key, text)
    return applied


# the %s %d %.1f ... markers in a string, in order
func _placeholders(text: String) -> Array:
    var out := []
    var i := 0
    while i < text.length():
        if text[i] == "%":
            if i + 1 < text.length() and text[i + 1] == "%":
                i += 2
                continue
            var j := i + 1
            while j < text.length() and text[j] in "0123456789.+-# ":
                j += 1
            if j < text.length():
                out.append(text[j])
            i = j
        i += 1
    return out


func _scan_banned(key: String, text: String) -> void:
    var low := " " + text.to_lower() + " "
    for word in BANNED:
        if low.contains(word):
            report.append("PERIOD CHECK (this is 2013-14): [%s] mentions '%s'" % [key, word.strip_edges()])


# write a string into the live table (the patched copy of the defaults)
func _store(path: Array, text: String) -> bool:
    var node := _node(str(path[0]))
    if node == null:
        return false
    var cur: Variant = node.get(str(path[1]))
    for i in range(2, path.size() - 1):
        cur = _child(cur, str(path[i]))
        if cur == null:
            return false
    var last := str(path[path.size() - 1])
    if cur is Array and last.is_valid_int():
        cur[int(last)] = text
        return true
    if cur is Dictionary:
        for k in cur:
            if str(k) == last:
                cur[k] = text
                return true
    return false


func _child(cur: Variant, part: String) -> Variant:
    if cur is Array and part.is_valid_int() and int(part) < cur.size():
        return cur[int(part)]
    if cur is Dictionary:
        for k in cur:
            if str(k) == part:
                return cur[k]
    return null


# ---- writing the file ----------------------------------------------------------------------------
# a short human description of where a string is used (a comment above its [key])
func describe(path: Array) -> String:
    var root := str(path[0])
    var name := str(path[1])
    var rest := path.slice(2)
    if root == "Story" and name == "DAYS" and rest.size() >= 2:
        var ev: Dictionary = _child(_child(_node("Story").get("DAYS"), str(rest[0])), str(rest[1]))
        return "Day %s, %s, %s: %s" % [str(rest[0]), _clock(float(ev.get("at", 0.0))), str(ev.get("kind", "event")).to_upper(), str(rest[rest.size() - 1])]
    if root == "Playbook" and name == "BOOKS" and rest.size() >= 1:
        var book: Dictionary = _child(_node("Playbook").get("BOOKS"), str(rest[0]))
        var where := "job: " + str(book.get("title", rest[0]))
        if rest.size() >= 3 and str(rest[1]) == "steps":
            where += ", step %d" % (int(rest[2]) + 1)
        return where
    if root == "Owner" and name == "CARDS" and rest.size() >= 1:
        return "owner card: " + str(rest[0])
    return " > ".join(path)


func _clock(hours: float) -> String:
    var h := int(hours)
    return "%d:%02d" % [h, int((hours - float(h)) * 60.0)]


# the whole file text. Existing edits (key -> text) are kept; new strings use the code's text.
func build(existing: Dictionary) -> String:
    var lines := PackedStringArray([
        "# MSPSim story text. Edit the text under each [key] and keep the [key] line as it is.",
        "# Keep %s / %d markers (they are filled in by the game). Lines under a key are joined into one paragraph.",
        "# The game is set in 2013-14: no AI, Teams, Slack, Windows 10/11, MFA, TikTok. See README.md.",
        "",
    ])
    var seen := {}
    var last_group := ""
    for e in entries():
        var group := " > ".join(PackedStringArray([str(e.path[0]), str(e.path[1])]))
        if group != last_group:
            lines.append("")
            lines.append("# ======================= " + group + " =======================")
            last_group = group
        lines.append("# " + describe(e.path))
        lines.append("[%s]" % str(e.key))
        lines.append(str(existing.get(str(e.key), e.text)))
        lines.append("")
        seen[str(e.key)] = true
    var obsolete := []
    for key in existing:
        if not seen.has(key):
            obsolete.append(key)
    if not obsolete.is_empty():
        lines.append("# ======================= NO LONGER USED BY THE GAME (safe to delete) =======================")
        for key in obsolete:
            lines.append("[%s]" % str(key))
            lines.append(str(existing[key]))
            lines.append("")
    return "\\n".join(lines)
''')

write("scripts/projects.gd", '''extends Node
# gdlint:disable=max-line-length
# Owner campaign: client profitability, projects and services. MSPs live on recurring revenue (the monthly fee, plus
# services like managed backup), and projects (a desktop refresh, a network or server upgrade, a security cleanup) add
# one-time money on top. Both compete for the same technicians' hours, and both can quietly lose money:
#  - every client has hours included in their fee; going over is "scope creep" (the Boardroom shows hours and profit),
#  - a project has an estimate; fixed-price jobs that creep eat the margin unless you scope first or bill a change order,
#  - firing a client costs you a little word of mouth.
# A buyer values recurring earnings, so project profit is left out of the valuation (take_week_income).

const SEC_PER_HOUR := 15.0  # one tech-hour = 15 tech-seconds of the simulation (a tech-second costs Owner.COST_PER_SEC)
const BILL_RATE := 95  # what an extra hour costs a client
const DISCOVERY_FEE := 300
const SCOPE_CREEP := 0.25  # extra hours when a fixed-price job creeps
const TYPES := {
    "desktops": {"label": "DESKTOP REFRESH (XP REPLACEMENT)", "price": [1800, 3600], "hw": 0.62, "hours": 18, "weeks": 2, "blurb": "five or six Windows XP desktops need replacing before April 8"},
    "network": {"label": "NETWORK UPGRADE (SWITCHES AND WI-FI)", "price": [2800, 3800], "hw": 0.45, "hours": 26, "weeks": 3, "blurb": "their wireless is a guessing game and the switches are ten years old"},
    "server": {"label": "SERVER REPLACEMENT", "price": [6500, 8500], "hw": 0.5, "hours": 44, "weeks": 4, "blurb": "the file server is out of warranty and out of disk"},
    "backup_dr": {"label": "BACKUP AND RECOVERY SETUP", "price": [1200, 1600], "hw": 0.25, "hours": 12, "weeks": 2, "blurb": "they want to know they can recover when it all goes wrong"},
    "security": {"label": "SECURITY CLEANUP", "price": [900, 1300], "hw": 0.2, "hours": 14, "weeks": 2, "blurb": "remote access, passwords and the firewall all need attention"},
}
const SERVICES := {
    "backup": {"label": "MANAGED BACKUP", "price": 110, "cost": 35, "blurb": "we watch their backups every night and fix failures before they matter"},
    "patching": {"label": "MANAGED UPDATES AND AV", "price": 80, "cost": 25, "blurb": "we keep every machine patched and protected"},
}
const PLATFORM_SETUP := 600
const PLATFORM_WEEKLY := 100

var projects: Array = []  # {id, client, type, method, price, hw, est, done, weeks, total, creep, scoped, delay, status, net, profit}
var services := {}  # client -> [service ids]
var hours_hist := {}  # client -> their last weekly hours
var wom_weeks := 0  # weeks of bad word of mouth left (Vic's close rate drops)
var enabled := true  # false in the balance harness to measure the campaign without projects and services
var completed_count := 0
var completed_profit := 0
var week_income := 0  # project money banked this week (left out of the valuation)

var _queue: Array = []  # things waiting for next morning: {kind: project|service|creep|wom, ...}
var _next_id := 1


func is_owner(who: String) -> bool:
    return OWNERS.has(who)


func role(who: String) -> String:
    return str(ROLES.get(who, ""))


func _ready() -> void:
    reset()


func reset() -> void:
    projects = []
    services = {}
    hours_hist = {}
    wom_weeks = 0
    completed_count = 0
    completed_profit = 0
    week_income = 0
    _queue = []
    _next_id = 1


func active() -> bool:
    return Campaign.active and Campaign.mode == "owner"


# ---- hours and profitability ------------------------------------------------------------------------
func hours(seconds: float) -> float:
    return seconds / SEC_PER_HOUR


func included_hours(client: int) -> float:
    return float(Owner.client_fee(client)) / 66.0  # a $800 fee covers about 12 hours a week


func client_hours(client: int) -> float:
    return hours(float(Owner.client_work.get(client, 0.0)))


# average of the recorded weeks (the Boardroom shows this)
func avg_hours(client: int) -> float:
    var list: Array = hours_hist.get(client, [])
    if list.is_empty():
        return client_hours(client)
    var total := 0.0
    for v in list:
        total += float(v)
    return total / float(list.size())


func over_hours(client: int) -> float:
    return maxf(0.0, avg_hours(client) - included_hours(client))


# called while settling, before the week's tech-seconds are reset
func record_week() -> void:
    for c in Sales.active:
        var list: Array = hours_hist.get(int(c), [])
        list.append(snappedf(client_hours(int(c)), 0.1))
        while list.size() > 4:
            list.pop_front()
        hours_hist[int(c)] = list


# ---- services (recurring) ---------------------------------------------------------------------------
func has_service(client: int, id: String) -> bool:
    return (services.get(client, []) as Array).has(id)


func service_revenue() -> int:
    var total := 0
    for c in services:
        if Sales.active.has(int(c)):
            for id in services[c]:
                total += int(SERVICES[id].price)
    return total


func service_cost() -> int:
    var total := 0
    for c in services:
        if Sales.active.has(int(c)):
            for id in services[c]:
                total += int(SERVICES[id].cost)
    return total


func sell_service(client: int, id: String) -> void:
    var list: Array = services.get(client, [])
    if not list.has(id):
        list.append(id)
    services[client] = list
    Sales.adjust(client, 4)


# every week the services do their job
func _services_week() -> void:
    for c in services:
        if not Sales.active.has(int(c)):
            continue
        if has_service(int(c), "backup"):
            Msp.backup_rerun(int(c))
        if has_service(int(c), "patching"):
            Owner.patch_debt[int(c)] = maxf(0.0, float(Owner.patch_debt.get(int(c), 0.0)) - 2.0)


# ---- capacity: projects use the same technicians as the tickets ---------------------------------------
func crew_hours() -> float:
    var crew := float(maxi(0, 3 - Owner.lost_techs)) + float(Owner.extra_staff.size())
    return crew * 240.0 / SEC_PER_HOUR


func weekly_project_hours() -> float:
    var total := 0.0
    for p in projects:
        if p.status == "active" and int(p.delay) <= 0:
            total += float(p.est) / float(p.total)
    return total


# the share of the team's time the running projects take away from tickets
func drag() -> float:
    if not active():
        return 0.0
    return clampf(weekly_project_hours() / maxf(1.0, crew_hours()), 0.0, 0.35)


# ---- opportunities -----------------------------------------------------------------------------------
func _pick_type(client: int) -> String:
    var pool := ["network", "server", "security"]
    if Campaign.day >= 3 and Campaign.day <= 14:
        pool.append_array(["desktops", "desktops", "desktops"])  # Windows XP ends on April 8
    if not has_service(client, "backup"):
        pool.append("backup_dr")
    if not Owner.flags.get("rdp_safe", false) and Campaign.day >= 7:
        pool.append("security")
    return pool[randi() % pool.size()]


func week() -> void:
    if not active() or not enabled:
        return
    _services_week()
    wom_weeks = maxi(0, wom_weeks - 1)
    _projects_week()
    if _queue.size() >= 2:
        return
    var chance := 0.22 + Sales.vic_skill() * 0.2 - (0.08 if wom_weeks > 0 else 0.0)
    if randf() < chance and not Sales.active.is_empty():
        var client := int(Sales.active[randi() % Sales.active.size()])
        if Sales.mood(client) < 45:
            return  # unhappy clients do not buy projects
        if randf() < 0.35 and (not has_service(client, "backup") or not has_service(client, "patching")):
            _queue.append({"kind": "service", "client": client, "id": "backup" if not has_service(client, "backup") else "patching"})
        else:
            _queue.append({"kind": "project", "client": client, "type": _pick_type(client)})


# the next morning: one card at a time
func begin_week() -> void:
    if not active() or not enabled or _queue.is_empty() or Cards.is_open:
        return
    var item: Dictionary = _queue.pop_front()
    match str(item.kind):
        "project":
            _quote_card(item)
        "service":
            _service_card(item)
        "creep":
            _creep_card(item)
        "wom":
            _wom_card(item)


func make_quote(client: int, type_id: String) -> Dictionary:
    var t: Dictionary = TYPES[type_id]
    var price := int(round(randf_range(float(t.price[0]), float(t.price[1])) / 50.0)) * 50
    var hw := int(float(price) * float(t.hw))
    return {"client": client, "type": type_id, "price": price, "hw": hw, "est": float(t.hours), "weeks": int(t.weeks)}


func quote_profit(q: Dictionary) -> int:
    return int(q.price) - int(q.hw) - int(float(q.est) * SEC_PER_HOUR * Owner.COST_PER_SEC)


func _quote_card(item: Dictionary) -> void:
    var client := int(item.client)
    var q := make_quote(client, str(item.type))
    var name: String = Msp.CLIENTS[client].name
    var t: Dictionary = TYPES[str(item.type)]
    var text := "%s: %s. Project: %s. About %d hours and $%d of hardware over %d weeks. At $%d fixed that is about $%d profit if nothing creeps. How do we quote it?" % [
        name, str(t.blurb), str(t.label).to_lower(), int(q.est), int(q.hw), int(q.weeks), int(q.price), quote_profit(q)]
    Cards.ask("Vic Marlowe", text, [
        {"label": "FIXED PRICE ($%d)" % int(q.price), "id": "fixed"},
        {"label": "SCOPE IT FIRST ($%d DISCOVERY, SAFER)" % DISCOVERY_FEE, "id": "scope"},
        {"label": "TIME AND MATERIALS ($%d/HOUR)" % BILL_RATE, "id": "tm"},
        {"label": "PASS ON THE PROJECT", "id": "pass"},
    ], func(id: String) -> void: _quoted(q, id))


func _quoted(q: Dictionary, method: String) -> void:
    if method == "pass":
        Msp.send_text("Vic", "I told them we are too busy. They were not thrilled.")
        return
    start_project(q, method)
    var text := "Project signed: %s." % str(TYPES[str(q.type)].label).to_lower()
    if method == "scope":
        text += " We bill $%d for discovery now and start next week with real numbers." % DISCOVERY_FEE
    elif method == "tm":
        text += " Time and materials: they pay for what it takes, and they know it."
    Msp.send_text("Vic", text)


func start_project(q: Dictionary, method: String) -> Dictionary:
    var p := {
        "id": _next_id, "client": int(q.client), "type": str(q.type), "method": method, "price": int(q.price), "hw": int(q.hw),
        "est": float(q.est), "done": 0.0, "weeks": int(q.weeks), "total": int(q.weeks), "creep": false,
        "scoped": method == "scope", "delay": 1 if method == "scope" else 0, "status": "active", "net": 0, "profit": 0,
    }
    _next_id += 1
    projects.append(p)
    if method == "scope":
        Owner.cash += DISCOVERY_FEE
        Owner.income_extra += DISCOVERY_FEE
        week_income += DISCOVERY_FEE
        Owner.flags["practice_scope"] = true
    if method == "tm":
        Sales.adjust(int(q.client), -3)
    Msp.changed.emit()
    return p


# ---- the weekly step of every running project --------------------------------------------------------
func _projects_week() -> void:
    for p in projects:
        if p.status != "active":
            continue
        if int(p.delay) > 0:
            p.delay = int(p.delay) - 1
            continue
        if not Sales.active.has(int(p.client)):
            p.status = "lost"
            continue
        p.done = float(p.done) + float(p.est) / float(p.total)
        p.weeks = int(p.weeks) - 1
        if p.method == "fixed" and not bool(p.creep) and not bool(p.scoped) and int(p.weeks) >= 1 and randf() < 0.30:
            p.creep = true
            p.est = float(p.est) * (1.0 + SCOPE_CREEP)
            _queue.push_front({"kind": "creep", "id": int(p.id)})
        if int(p.weeks) <= 0:
            _complete(p)


func project(id: int) -> Dictionary:
    for p in projects:
        if int(p.id) == id:
            return p
    return {}


func _creep_card(item: Dictionary) -> void:
    var p := project(int(item.id))
    if p.is_empty() or p.status != "active":
        return
    var client := int(p.client)
    var extra := int(float(p.price) * SCOPE_CREEP)
    var odds := 0.55 + (0.15 if Sales.mood(client) >= 70 else 0.0) + (0.1 if Owner.flags.get("practice_scope", false) else 0.0)
    var text := "%s's project is creeping: they keep adding things (extra machines, one more site, 'while you are here'). The fixed price will not cover it: about %d more hours." % [str(Msp.CLIENTS[client].name), int(float(p.est) * SCOPE_CREEP / (1.0 + SCOPE_CREEP))]
    Cards.ask("Alan (Co-owner)", text, [
        {"label": "BILL A CHANGE ORDER ($%d, %d%% THEY AGREE)" % [extra, int(odds * 100.0)], "id": "co"},
        {"label": "HOLD THE ORIGINAL SCOPE (THEY ARE ANNOYED)", "id": "hold"},
        {"label": "EAT THE COST", "id": "eat"},
    ], func(id: String) -> void: _creep_answer(int(p.id), id, extra, odds))


func _creep_answer(id: int, choice: String, extra: int, odds: float) -> void:
    var p := project(id)
    if p.is_empty():
        return
    var client := int(p.client)
    match choice:
        "co":
            if randf() < odds:
                p.price = int(p.price) + extra
                Sales.adjust(client, -2)
                Msp.send_text("Alan", "They signed the change order. $%d on top, and they now know requests cost money." % extra)
                Owner.flags["practice_scope"] = true
            else:
                Sales.adjust(client, -8)
                Msp.send_text("Alan", "They refused to pay for the extras. We are eating it and they are sulking.")
        "hold":
            p.est = float(p.est) / (1.0 + SCOPE_CREEP)
            Sales.adjust(client, -4)
            Msp.send_text("Alan", "We told them the extras are a second project. They grumbled, and the schedule held.")
        _:
            Msp.send_text("Alan", "We are absorbing it. Fine, but the margin is gone.")


func _complete(p: Dictionary) -> void:
    p.status = "done"
    var revenue := int(p.price)
    if p.method == "tm":
        revenue = int(float(p.done) * float(BILL_RATE) + float(p.hw) * 1.15)
    var labor := int(float(p.done) * SEC_PER_HOUR * Owner.COST_PER_SEC)
    p.net = revenue - int(p.hw)  # cash that arrives (labor is already in payroll)
    p.profit = revenue - int(p.hw) - labor
    Owner.cash += int(p.net)
    Owner.income_extra += int(p.net)
    week_income += int(p.net)
    completed_count += 1
    completed_profit += int(p.profit)
    var client := int(p.client)
    var smooth: bool = not bool(p.creep) or int(p.profit) > 0
    Sales.adjust(client, 8 if smooth else 3)
    if int(p.profit) > 0 and smooth:
        Campaign.adjust_rep(1)
    var verdict := "made $%d" % int(p.profit) if int(p.profit) >= 0 else "LOST $%d" % absi(int(p.profit))
    Msp.send_text("Marge", "%s finished at %s: we %s after labor." % [str(TYPES[str(p.type)].label).capitalize(), str(Msp.CLIENTS[client].name), verdict])
    if str(p.type) == "backup_dr" and not has_service(client, "backup"):
        _queue.push_front({"kind": "service", "client": client, "id": "backup"})
    Msp.changed.emit()


func _service_card(item: Dictionary) -> void:
    var client := int(item.client)
    var id := str(item.id)
    var s: Dictionary = SERVICES[id]
    var platform_missing: bool = id == "backup" and not Owner.flags.get("backup_service", false)
    var text := "%s would sign for %s: %s. $%d a week to them, about $%d a week to us. %s" % [
        str(Msp.CLIENTS[client].name), str(s.label).to_lower(), str(s.blurb), int(s.price), int(s.price) - int(s.cost),
        "We need the backup platform first ($%d plus $%d a week)." % [PLATFORM_SETUP, PLATFORM_WEEKLY] if platform_missing else "That is recurring revenue: the kind a buyer pays for."]
    var options := [{"label": "SELL IT ($%d/WEEK)" % int(s.price), "id": "sell"}, {"label": "NOT NOW", "id": "no"}]
    if platform_missing:
        options[0] = {"label": "BUY THE PLATFORM ($%d) AND SELL IT" % PLATFORM_SETUP, "id": "sell", "enabled": Owner.cash >= PLATFORM_SETUP, "hint": "NEED $%d" % PLATFORM_SETUP}
    Cards.ask("Vic Marlowe", text, options, func(choice: String) -> void: _service_answer(client, id, choice, platform_missing))


func _service_answer(client: int, id: String, choice: String, platform_missing: bool) -> void:
    if choice != "sell":
        return
    if platform_missing:
        Owner.cash -= PLATFORM_SETUP
        Owner.weekly_extra += PLATFORM_WEEKLY
        Owner.flags["backup_service"] = true
    sell_service(client, id)
    Msp.send_text("Vic", "Signed: %s for %s. Recurring revenue!" % [str(SERVICES[id].label).to_lower(), str(Msp.CLIENTS[client].name)])


# an opportunity found on a visit: the quote card comes up the next morning
func offer_project(client: int, type: String) -> void:
    var waiting := 0
    for q in _queue:
        if str(q.get("kind", "")) == "project":
            waiting += 1
            if int(q.client) == client and str(q.type) == type:
                return  # already on the list
    if waiting >= 2:
        return
    _queue.append({"kind": "project", "client": client, "type": type})


# ---- change orders and firing: the answers to a client who costs more than they pay -----------------------
func change_order_amount(client: int) -> int:
    return int(over_hours(client) * 4.0 * float(BILL_RATE))  # four weeks of the extra hours


func change_order(client: int) -> String:
    var amount := change_order_amount(client)
    var odds := 0.6 if Sales.mood(client) >= 60 else 0.35
    if randf() < odds:
        Owner.cash += amount
        Owner.income_extra += amount
        week_income += amount
        Owner.scope_fixed[client] = true  # from now on requests beyond the plan are billable
        Sales.adjust(client, -3)
        Owner.flags["practice_scope"] = true
        return "They pay $%d for the extra work and accept that requests beyond the plan are billable." % amount
    Sales.adjust(client, -8)
    return "They refuse the bill and say the work was always included. Things are tense."


# how = polite (30 days notice, a referral to another firm) or now
func fire_client(client: int, how: String) -> String:
    var mood := Sales.mood(client)
    var name: String = Msp.CLIENTS[client].name
    Owner.drop_client(client)
    var risk := 0.55 if mood < 45 else (0.25 if mood < 70 else 0.1)
    if how == "polite":
        risk *= 0.35
    else:
        Campaign.adjust_rep(-1)
    if randf() < risk:
        wom_weeks = 6
        Campaign.adjust_rep(-2)
        _queue.append({"kind": "wom", "client": client})
        return "%s is leaving angry and telling people. Expect to hear about it." % name
    if how == "polite" and mood >= 70 and randf() < 0.3:
        Owner._leads += 1
        return "%s leaves on good terms and says they will recommend you. A lead may follow." % name
    return "%s is gone. Word of mouth stays quiet, for now." % name


func _wom_card(item: Dictionary) -> void:
    var name: String = Msp.CLIENTS[int(item.client)].name
    Cards.ask("Vic Marlowe", "A prospect says %s told them we are hard to work with. It is going around the local business crowd. What do we do?" % name, [
        {"label": "CALL THE PROSPECT AND TELL OUR SIDE", "id": "call"},
        {"label": "OFFER A FREE HEALTH CHECK ($300)", "id": "check", "enabled": Owner.cash >= 300, "hint": "NEED $300"},
        {"label": "LET IT BLOW OVER", "id": "wait"},
    ], func(id: String) -> void: _wom_answer(id))


func _wom_answer(id: String) -> void:
    match id:
        "call":
            if randf() < 0.5:
                wom_weeks = maxi(0, wom_weeks - 3)
                Msp.send_text("Vic", "The prospect heard me out. Not everybody believes the other side.")
            else:
                Msp.send_text("Vic", "The prospect was polite and went with someone else.")
        "check":
            Owner.cash -= 300
            wom_weeks = 0
            Owner._leads += 1
            Msp.send_text("Vic", "The health check impressed them. They want to talk.")


func vic_penalty() -> float:
    return 0.06 if wom_weeks > 0 and active() else 0.0


# project money is not recurring: the valuation leaves it out
func take_week_income() -> int:
    var v := week_income
    week_income = 0
    return v


func recurring_share() -> float:
    var rev := float(Owner.weekly_estimate().revenue)
    return float(service_revenue()) / maxf(1.0, rev)


func client_gone(client: int) -> void:
    services.erase(client)
    hours_hist.erase(client)
    for p in projects:
        if int(p.client) == client and p.status == "active":
            p.status = "lost"


func summary_lines() -> Array:
    var active_list := []
    for p in projects:
        if p.status == "active":
            active_list.append(p)
    return active_list


func to_dict() -> Dictionary:
    return {
        "projects": projects, "services": services, "hours": hours_hist, "wom": wom_weeks, "count": completed_count,
        "profit": completed_profit, "queue": _queue, "next": _next_id,
    }


func from_dict(data: Dictionary) -> void:
    reset()
    projects = data.get("projects", [])
    var saved: Dictionary = data.get("services", {})
    for key in saved:
        services[int(key)] = saved[key]
    var hist: Dictionary = data.get("hours", {})
    for key in hist:
        hours_hist[int(key)] = hist[key]
    wom_weeks = int(data.get("wom", 0))
    completed_count = int(data.get("count", 0))
    completed_profit = int(data.get("profit", 0))
    _queue = data.get("queue", [])
    _next_id = int(data.get("next", 1))
''')

write("scripts/conference.gd", '''extends Node
# gdlint:disable=max-line-length
# RODENT NATION 2014: LabRat's yearly user conference (a parody of the real RMM vendor's June 2014 event).
# Tech campaign: Morgan announces on day 8 that the people who hit their KPIs get sent; day 12 is a progress note,
# day 16 the verdict, day 17 the trip itself (the office is frozen, you pick a session in each of three rounds, take in the
# keynote and the vendor hall, and enter the raffle). Missed the KPIs and Dan goes instead and brings back one tip.
# The story text lives in TEXT and ROUNDS so reviewers can edit it in story/strings.txt.

const INVITE_DAY := 8
const PROGRESS_DAY := 12
const VERDICT_DAY := 16
const TRIP_DAY := 17
const CLOCKS := [10.0, 13.0, 15.0]
const DOORS := ["from_a", "from_b", "from_c", "from_d"]
const NEED := 3  # how many of the four KPIs must be met
const MORGAN := "Morgan Reyes - Manager"
const TEXT := {
    "invite_subject": "Rodent Nation 2014: top performers go",
    "invite_body": "LabRat's yearly user conference, RODENT NATION, is in Orlando this June. The company pays for one tech: whoever hits the KPIs by day 16. Reputation 55 or more, SLA misses under 20 percent of closes, reopens under 15 percent of closes, and PowerShell level 2. Hit three of the four and you go. - Morgan",
    "progress": "KPI check before the Rodent Nation trip: %s. Three of four wins the ticket.",
    "yes_subject": "Pack your bags: Rodent Nation",
    "yes_body": "You hit the KPIs (%s). You fly out tomorrow for two days of sessions: labs, panels, the vendor hall and the keynote. Dan will cover your queue. Come back smarter. - Morgan",
    "no_subject": "Rodent Nation: not this year",
    "no_body": "You did not quite make the KPIs (%s), so Dan is going to Rodent Nation this year. He will bring back notes. Aim for it next year. - Morgan",
    "arrive": "RODENT NATION 2014. Orlando, a resort the size of a small town: palm trees in the lobby, carpet with swirls, a ballroom that fits a thousand MSP nerds, and breakout rooms down every hallway. Your badge says TECH and has a little rat on it.",
    "keynote": "The LabRat CEO takes the stage in the ballroom under a sign that says AUTOMATE EVERYTHING. Eleven hundred people applaud a slide about a dashboard. Meanwhile your phone buzzes: the queue back home is not empty.",
    "keynote_listen": "You put the phone away and listen. The CEO says the future is scripts, monitoring and fewer truck rolls. You take notes. (+3 customer XP)",
    "keynote_peek": "You check the queue under the table. Dan has it, but you leave a few notes. It costs you half the keynote.",
    "hall": "The solutions pavilion: a long row of booths, free pens, a man in a rat costume, and every vendor wants a scan of your badge.",
    "hall_swag": "You collect a bag of pens, stress balls and a USB drive nobody will ever plug in. Alan will want a pen. (coworkers like you a little more)",
    "hall_nerds": "You find the LabRat Nerds forum regulars at the community table. Real faces behind the nicknames. (+4 forum karma)",
    "hall_vendor": "A backup vendor walks you through a disaster recovery demo that actually works. You take the brochure. (+6 security XP)",
    "raffle_win": "They call your badge number: you won the Rock Star Upgrade! A new laptop bag, a hotel suite night and a dinner for two. You sleep like a baby. (energy full, +3 reputation)",
    "raffle_lose": "Not your number. A man from Tulsa wins the Rock Star Upgrade and cries. Oh well.",
    "wrap": "The last session lets out. You fly home with a tote bag, a head full of ideas and a lanyard you will keep. Tomorrow the queue will want to hear about it.",
    "dan_back": "Dan is back from Rodent Nation with a tote bag and one thing he swears will change your life: always label the patch panel. (+6 networking XP)",
    "home_pile": "While you were away tickets piled up. Dan did what he could.",
    "home_ok": "You checked in during the keynote, so the pile is small. Dan says thanks.",
    "report": "RODENT NATION TRIP",
    "checkin": "Welcome to Rodent Nation! Here is your badge, a lanyard, the agenda and a tote bag full of flyers. The ballroom opens at nine. The vendor hall is open all day.",
    "checkin_again": "You already have your badge, hon. Keynote is in the ballroom, left door.",
    "usher": "Badge, please. No badge, no keynote. Registration is back in the lobby.",
    "greet_lurker": "(Nobody here has ever seen your name on the forum.)",
    "greet_member": "(They know your name from the forum.)",
    "greet_regular": "(Oh, you are THE regular from the forum! They are thrilled.)",
    "greet_guru": "(A forum guru in person! People stare at your badge.)",
    "boss_morgan": "Thanks for being on time. Remember: ask users to save before you reboot, and verify the backups every morning.",
    "boss_marge": "I have the weekly numbers ready for after the meeting. Cash is tight, but we are okay.",
    "chat_again": "You already chatted. They nod and go back to their coffee.",
    "vendor_again": "Back again? Here, take another pen. Let me know if you change your mind.",
    "spam_note": "Your inbox fills with follow-ups from the vendors whose booths you gave your badge to.",
    "to_ballroom": "The keynote starts at 9:00 in the BALLROOM. Left door in the lobby.",
    "to_hall": "Breakout sessions are down the HALL (right door). Each door is a different session, check the easels. The EXPO HALL is always open too.",
    "to_booth": "The vendor hall is always open: the EXPO HALL door in the lobby. Walk into a booth to see what they have.",
    "to_raffle": "The closing raffle is in the BALLROOM. Do not miss it.",
}
const ROUNDS := [
    {
        "title": "ROUND 1: TUESDAY MORNING",
        "intro": "The agenda has seven tracks at the same time. Pick one session.",
        "sessions": [
            {"id": "ps101", "short": "SCRIPTING 101 LAB", "label": "SCRIPTING 101 LAB", "skill": "powershell", "xp": 0, "text": "A hands-on lab where you write your first real LabRat script. The instructor walks the room. Everything clicks. (+1 PowerShell level)"},
            {"id": "monitor", "short": "MONITOR BEST PRACTICE", "label": "MONITORING BEST PRACTICES", "skill": "networking", "xp": 8, "text": "How to alert on what matters and stop drowning in noise: set thresholds, skip the disk-space-at-79-percent emails. (+8 networking XP)"},
            {"id": "patch", "short": "PATCH MGMT BEST PRACTICE", "label": "PATCH MANAGEMENT BEST PRACTICES", "skill": "servers", "xp": 8, "text": "Patch Tuesday, approvals, maintenance windows and rollback plans. You leave with a checklist. (+8 servers XP)"},
            {"id": "oml", "short": "SERVICE DESK MATURITY", "label": "YOUR SERVICE DESK MATURITY LEVEL", "skill": "people", "xp": 8, "text": "A consultant shows where service desks usually stall: no process, no metrics, no follow-up. You finally have words for what Morgan keeps asking for. (+8 customer XP)"},
        ],
    },
    {
        "title": "ROUND 2: TUESDAY AFTERNOON",
        "intro": "Lunch was a rubber chicken. Pick the afternoon session.",
        "sessions": [
            {"id": "ps201", "short": "SCRIPTING 201 LAB", "label": "SCRIPTING 201 LAB", "skill": "servers", "xp": 8, "text": "Loops, variables and a script that restarts services across a whole client. Hard but useful. (+8 servers XP)"},
            {"id": "security", "short": "SECURITY FOR MODERN THREATS", "label": "RETHINKING SECURITY FOR MODERN THREATS", "skill": "security", "xp": 8, "text": "Antivirus alone is not enough anymore. Layers, patching, backups and training users. (+8 security XP)"},
            {"id": "bdr", "short": "MONEY MAKING BDR", "label": "ROLL YOUR OWN MONEY-MAKING BDR", "skill": "security", "xp": 6, "text": "A master MSP shows how a good backup and disaster recovery service pays for itself, and how to test restores. (+6 security XP)"},
            {"id": "panel", "short": "BIGGEST MISTAKE PANEL", "label": "PARTNER PANEL: MY BIGGEST MISTAKE", "skill": "people", "xp": 8, "text": "Five owners confess their worst outages. The common thread: no backups, no documentation and no one checking. (+8 customer XP)"},
        ],
    },
    {
        "title": "ROUND 3: WEDNESDAY MORNING",
        "intro": "The last round before the flight. Pick one.",
        "sessions": [
            {"id": "hipaa", "short": "HIPAA FOR MSPS", "label": "THE HIPAA QUESTIONS EVERY MSP SHOULD ASK", "skill": "security", "xp": 8, "text": "Dental offices and doctors have rules about their data. You now know what to ask Acme Dental. (+8 security XP, Acme Dental trusts you more)"},
            {"id": "managed", "short": "BREAK FIX TO MANAGED", "label": "CONVERTING CLIENTS FROM BREAK/FIX TO MANAGED", "skill": "people", "xp": 8, "text": "How to explain monthly service to an owner who only calls when it is broken. (+8 customer XP)"},
            {"id": "hood", "short": "UNDER THE HOOD", "label": "UNDER THE HOOD: ADVANCED CONCEPTS", "skill": "servers", "xp": 8, "text": "Database tables, agent logs and a few things the vendor admits they do not document. (+8 servers XP)"},
            {"id": "stay", "short": "WHY I STAY PANEL", "label": "PARTNER PANEL: WHY I STAY (A TECH PERSPECTIVE)", "skill": "people", "xp": 8, "text": "Four techs from other MSPs say why they stayed: training budgets, a boss who answers the phone, and a real path to Tier 2. You think about Morgan. (+8 customer XP)"},
        ],
    },
]

const VENDORS := [
    {
        "id": "backup", "speaker": "Brad (ShadowPoint Backup)",
        "text": "Friend! Do your clients have a real backup, or just a USB drive in a drawer? ShadowPoint does image-based backup with instant virtualization. Forty percent off if you sign up this week!",
        "options": [
            {"id": "demo", "label": "SIT THROUGH THE DEMO", "text": "Brad boots a dead server as a virtual machine in four minutes. You are actually impressed. (+6 security XP)"},
            {"id": "price", "label": "ASK ABOUT PRICING", "text": "Per server, per month, plus storage, plus a setup fee that is somehow not in the brochure. You write it all down. (+3 customer XP)"},
            {"id": "scan", "label": "SCAN MY BADGE FOR THE PRIZE", "text": "Beep. You are entered to win a tablet. Brad's smile gets a little wider. (raffle entry, expect emails)"},
            {"id": "no", "label": "NO THANKS, JUST LOOKING", "text": "Brad hands you a pen anyway and says he will be around all week."},
        ],
        "mail": {"from": "Brad Kowalski <brad@shadowpoint.example>", "subject": "Great meeting you at Rodent Nation!!!", "body": "Hi, it was great talking at the show! I wanted to follow up on that 40 percent offer. It expires FRIDAY. Can we do a quick 15 minute call? - Brad"},
    },
    {
        "id": "webwoot", "speaker": "Dee (WebWoot Security)",
        "text": "Quick question: are your clients protected from CryptoLocker? Because the other guys are not! Our cloud antivirus catches threats before they exist!",
        "options": [
            {"id": "demo", "label": "WATCH THE THREAT MAP", "text": "A glowing map of the world with red dots everywhere. Dee says each dot is somebody who did not buy WebWoot. It is mostly marketing, but you learn a few real terms. (+6 security XP)"},
            {"id": "price", "label": "ASK HOW IT WORKS UNDER THE HOOD", "text": "Dee has to fetch an engineer. He explains how definitions and heuristics differ and which clients benefit. Useful. (+3 servers XP)"},
            {"id": "scan", "label": "SCAN MY BADGE FOR THE T-SHIRT", "text": "Beep. A free t-shirt and a lifetime of email. (raffle entry, expect emails)"},
            {"id": "no", "label": "WE ALREADY HAVE ANTIVIRUS", "text": "Dee says everyone says that, until they do not. She gives you a sticker."},
        ],
        "mail": {"from": "Dee Kessler <dee@webwoot.example>", "subject": "Is your client protected? (reminder)", "body": "Hi! Following up from Rodent Nation. Did you know ransomware is way up this year? Let us show you a 30 day trial. Reply YES for a free assessment. - Dee"},
    },
    {
        "id": "psa", "speaker": "Rex (SoftSwipe PSA)",
        "text": "Still using ConnectWhy? I can hear it from here. SoftSwipe PSA: one pane of glass, tickets, billing, projects, even a CRM! Switch this quarter and we migrate your data FREE.",
        "options": [
            {"id": "demo", "label": "SEE THE DASHBOARD", "text": "A very busy dashboard with a very small font. The billing screen is genuinely good. (+6 customer XP)"},
            {"id": "price", "label": "ASK ABOUT MIGRATION", "text": "Rex goes quiet. Then he admits data migration is 'a partnership'. You note which fields are not imported. (+3 networking XP)"},
            {"id": "scan", "label": "SCAN MY BADGE FOR THE DRAWING", "text": "Beep. A chance at a game console and a follow-up call from Rex. (raffle entry, expect emails)"},
            {"id": "no", "label": "WE ARE HAPPY WITH WHAT WE HAVE", "text": "Rex hands you a stress ball shaped like a ticket and says he will check back in a month."},
        ],
        "mail": {"from": "Rex Dalton <rex@softswipe.example>", "subject": "Following up: SoftSwipe PSA demo?", "body": "Hi! I saw you stopped by the booth. I would love to give you a personal demo of SoftSwipe PSA. Are you the decision maker? - Rex"},
    },
]
const CHATS := [
    {
        "speaker": "rodent_rick (Dave, small MSP, Ohio)",
        "text": "Six techs, forty clients. We dropped per-incident billing last year. Flat monthly or nothing. Best decision we ever made.",
        "options": [
            {"id": "learn", "label": "ASK HOW HE SOLD IT", "skill": "people", "xp": 4, "text": "He says: stop calling it a price increase and call it predictable IT. And never discount the first year. (+4 customer XP)"},
            {"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "You swap cards. His has a cartoon dog on it."},
            {"id": "bye", "label": "NICE TO MEET YOU", "skill": "", "xp": 0, "text": "He tells you to look him up in the forum."},
        ],
    },
    {
        "speaker": "gnawer (Priya, in-house IT)",
        "text": "Forty Windows XP machines to go and support already ended in April. My boss thinks we can just leave them. Do you do XP migrations?",
        "options": [
            {"id": "learn", "label": "SHARE YOUR MIGRATION PLAN", "skill": "networking", "xp": 4, "text": "You compare notes: image first, move the data, check the printers. She writes it on her badge. (+4 networking XP)"},
            {"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "She promises to send you the checklist she is building."},
            {"id": "bye", "label": "GOOD LUCK WITH THAT", "skill": "", "xp": 0, "text": "She groans and laughs."},
        ],
    },
    {
        "speaker": "PS_wizard (Gary, script guy)",
        "text": "I scripted our whole new-client onboarding in PowerShell. A weekend of work, saves me five hours a week. I will show anyone who asks.",
        "options": [
            {"id": "learn", "label": "ASK TO SEE IT", "skill": "servers", "xp": 4, "text": "He walks you through loops and a function you can steal. You take screenshots with your phone. (+4 servers XP)"},
            {"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "His card says SCRIPT WIZARD, which he printed himself."},
            {"id": "bye", "label": "MAYBE LATER", "skill": "", "xp": 0, "text": "He looks a little disappointed."},
        ],
    },
    {
        "speaker": "old_hand (Tina, security consultant)",
        "text": "CryptoLocker hit two of my clients last month. Both had working backups, so it was a bad afternoon instead of a bad year. Test your restores!",
        "options": [
            {"id": "learn", "label": "ASK ABOUT HER RESTORE TEST", "skill": "security", "xp": 4, "text": "Once a quarter she restores a random file server into a lab and times it. You will do that. (+4 security XP)"},
            {"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "She hands you a card with an incident hotline on the back."},
            {"id": "bye", "label": "GOOD ADVICE, THANKS", "skill": "", "xp": 0, "text": "She tells you to do it before you need it."},
        ],
    },
    {
        "speaker": "xX_n00b_Xx (Marcus, shy owner)",
        "text": "Is it rude to take the free pen and walk away? I have a rule: twenty minute pitches are not worth a pen.",
        "options": [
            {"id": "learn", "label": "TELL HIM TO USE THE BADGE TRICK", "skill": "people", "xp": 3, "text": "You explain: turn your badge around so they cannot scan it. He laughs for a full minute. (+3 customer XP)"},
            {"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "He swaps cards, a bit surprised that anyone asked."},
            {"id": "bye", "label": "ENJOY THE SHOW", "skill": "", "xp": 0, "text": "He says he will try."},
        ],
    },
    {
        "speaker": "trollbot (Trent, 11,000 posts)",
        "text": "So YOU are the one from the forum. I read your answers. Wrong, all of them. I would correct them in person but I could go on for an hour.",
        "options": [
            {"id": "learn", "label": "ASK WHAT EXACTLY WAS WRONG", "skill": "people", "xp": 3, "text": "Forty minutes later you have learned nothing about PowerShell and a lot about staying calm with difficult people. (+3 customer XP)"},
            {"id": "cards", "label": "SWAP BUSINESS CARDS", "skill": "", "xp": 0, "text": "His card just says TRENT in a font you do not want to name."},
            {"id": "bye", "label": "WALK AWAY SLOWLY", "skill": "", "xp": 0, "text": "He is already explaining something to somebody else."},
        ],
    },
]
const CROWD := {
    "resort_lobby": [
        {"who": "client_dentrec_b", "role": "checkin", "x": 100, "facing": "right", "routine": ["wait:6", "say:2"]},
        {"who": "expo_atta", "role": "att:0", "x": 215, "facing": "left", "routine": ["talk:5", "wait:3"]},
        {"who": "expo_priya", "role": "att:1", "x": 243, "facing": "right", "routine": ["talk:5", "wait:3"]},
    ],
    "resort_hall": [
        {"who": "expo_tina", "role": "att:3", "x": 140, "facing": "right", "routine": ["walk:60", "wait:3", "walk:250", "wait:2"]},
        {"who": "expo_attd", "role": "att:2", "x": 280, "facing": "left", "routine": ["wait:4", "say:2"]},
    ],
    "ballroom": [
        {"who": "expo_atta", "role": "att:0", "x": 77, "facing": "right", "seat": "Seat1", "routine": ["wait:8"]},
        {"who": "expo_attb", "role": "att:4", "x": 157, "facing": "right", "seat": "Seat3", "routine": ["wait:8"]},
        {"who": "expo_tina", "role": "att:3", "x": 230, "facing": "left", "routine": ["wait:6", "say:2"]},
    ],
    "breakout_room": [
        {"who": "expo_attd", "role": "att:2", "x": 79, "facing": "right", "seat": "Seat1", "routine": ["wait:8"]},
        {"who": "expo_priya", "role": "att:1", "x": 159, "facing": "right", "seat": "Seat3", "routine": ["wait:8"]},
    ],
    "vendor_hall": [
        {"who": "expo_vendg", "role": "vendor:backup", "x": 159, "facing": "right", "routine": ["wait:5", "say:2"]},
        {"who": "expo_dee", "role": "vendor:webwoot", "x": 71, "facing": "right", "routine": ["wait:4", "say:2"]},
        {"who": "expo_vendo", "role": "vendor:psa", "x": 272, "facing": "right", "routine": ["wait:6", "say:2"]},
        {"who": "expo_attb", "role": "att:4", "x": 150, "facing": "right", "routine": ["walk:100", "wait:3", "walk:270", "wait:3"]},
        {"who": "expo_attc", "role": "att:5", "x": 280, "facing": "left", "routine": ["wait:5", "talk:3"]},
    ],
}

var invited := false
var qualified := false
var decided := false
var went := false  # you went (saved: the review can mention it)
var picks: Array = []
var tot_closed := 0
var tot_missed := 0
var tot_reopened := 0
var away := false
var peeked := false
var _sent := {}
var _stage := ""
var _seen := ""
var rnd := 0
var badge := false
var spam := 0
var entries := 0
var cards_swapped := 0
var _met := {}
var _booths := {}
var _talked := {}
var _sign_cache := {}


func _ready() -> void:
    Campaign.day_started.connect(_on_day)


func reset() -> void:
    invited = false
    qualified = false
    decided = false
    went = false
    picks = []
    tot_closed = 0
    tot_missed = 0
    tot_reopened = 0
    away = false
    peeked = false
    _sent = {}
    _stage = ""
    _seen = ""
    rnd = 0
    badge = false
    spam = 0
    entries = 0
    cards_swapped = 0
    _met = {}
    _booths = {}
    _talked = {}


func to_dict() -> Dictionary:
    return {
        "invited": invited, "qualified": qualified, "decided": decided, "went": went, "picks": picks,
        "closed": tot_closed, "missed": tot_missed, "reopened": tot_reopened, "spam": spam, "entries": entries, "swapped": cards_swapped,
    }


func from_dict(data: Dictionary) -> void:
    reset()
    invited = bool(data.get("invited", false))
    qualified = bool(data.get("qualified", false))
    decided = bool(data.get("decided", false))
    went = bool(data.get("went", false))
    picks = data.get("picks", [])
    tot_closed = int(data.get("closed", 0))
    tot_missed = int(data.get("missed", 0))
    tot_reopened = int(data.get("reopened", 0))
    spam = int(data.get("spam", 0))
    entries = int(data.get("entries", 0))
    cards_swapped = int(data.get("swapped", 0))


func is_tech() -> bool:
    return Campaign.active and Campaign.mode == "tech"


# ---- the KPIs
func kpis() -> Array:
    var closed := maxi(1, tot_closed)
    return [
        {"name": "REPUTATION 55+", "ok": Campaign.rep >= 55, "now": str(Campaign.rep)},
        {"name": "SLA MISSES UNDER 20%", "ok": tot_missed * 5 <= closed, "now": "%d OF %d" % [tot_missed, tot_closed]},
        {"name": "REOPENS UNDER 15%", "ok": tot_reopened * 100 <= closed * 15, "now": "%d OF %d" % [tot_reopened, tot_closed]},
        {"name": "POWERSHELL LEVEL 2", "ok": Skills.level("powershell") >= 2, "now": str(Skills.level("powershell"))},
    ]


func passed() -> int:
    var n := 0
    for k in kpis():
        n += 1 if bool(k.ok) else 0
    return n


func summary() -> String:
    var parts := []
    for k in kpis():
        parts.append("%s %s (%s)" % ["OK" if bool(k.ok) else "NO", str(k.name), str(k.now)])
    return ", ".join(parts)


func is_trip_day(day: int) -> bool:
    return is_tech() and day == TRIP_DAY and qualified


# ---- the schedule
func _process(_delta: float) -> void:
    if away and _stage != "done" and not Game.title_mode:
        _trip_tick()
        return
    if not is_tech() or Game.title_mode or World.time_scale <= 0.0 or Cards.is_open:
        return
    var day := Campaign.day
    if day == INVITE_DAY and not _sent.has("invite") and World.clock >= 10.0:
        _sent["invite"] = true
        invited = true
        Msp.mail(MORGAN, str(TEXT.invite_subject), str(TEXT.invite_body))
    elif day == PROGRESS_DAY and not _sent.has("progress") and World.clock >= 10.0:
        _sent["progress"] = true
        Msp.send_text("Boss", str(TEXT.progress) % summary())
    elif day == VERDICT_DAY and not _sent.has("verdict") and World.clock >= 9.2:
        _sent["verdict"] = true
        _verdict()


func _verdict() -> void:
    decided = true
    qualified = passed() >= NEED
    if qualified:
        Msp.mail(MORGAN, str(TEXT.yes_subject), str(TEXT.yes_body) % summary())
    else:
        Msp.mail(MORGAN, str(TEXT.no_subject), str(TEXT.no_body) % summary())


func _on_day(day: int) -> void:
    _sent = {}
    away = false
    if not is_tech():
        return
    if day == TRIP_DAY + 1:
        _home()
    if is_trip_day(day):
        away = true
        peeked = false
        picks = []
        went = true
        _stage = "arrive"
        rnd = 0
        _seen = ""
        badge = false
        _met = {}
        _booths = {}
        _talked = {}
        Msp.enabled = false
        World.time_scale = 0.0
        Cards.ask("Morgan (Manager)", str(TEXT.arrive), [{"label": "FLY OUT", "id": "go"}], func(_id: String) -> void: _fly_out())


func _home() -> void:
    if spam > 0:
        var sent := 0
        for v in VENDORS:
            if sent < spam and sent < VENDORS.size():
                Msp.mail(str(v.mail.from), str(v.mail.subject), str(v.mail.body))
                sent += 1
        Msp.send_text("You", str(TEXT.spam_note))
    if qualified and went:
        Msp.send_text("Dan", str(TEXT.home_ok) if peeked else str(TEXT.home_pile))
        if not peeked:
            for i in 2:
                var t: Dictionary = Msp._random_ticket("email")
                if not t.is_empty():
                    t.sla_left = maxf(float(t.sla_total) * 0.5, float(t.sla_left) - 150.0)
    elif decided and not qualified:
        Msp.send_text("Dan", str(TEXT.dan_back))
        Skills.add_xp("networking", 6)


# ---- the trip: keynote, three rounds, the vendor hall, the raffle
func _fly_out() -> void:
    _stage = "keynote"
    World.clock = 8.7
    Game.go("resort_lobby", "from_taxi")
    Hints.toast(str(TEXT.to_ballroom), 5.0)


func _scene_name() -> String:
    var scene := get_tree().current_scene
    return "" if scene == null else scene.scene_file_path.get_file().get_basename()


# the trip is walked: what happens depends on the room you walk into and the stage you are at
func _trip_tick() -> void:
    match _stage:
        "keynote":
            Hints.objective = "NEXT: THE KEYNOTE IN THE BALLROOM (LEFT DOOR). GET A BADGE AT REGISTRATION FIRST."
        "round":
            Hints.objective = "NEXT: PICK A SESSION DOWN THE HALL (RIGHT DOOR). THE EXPO HALL IS OPEN TOO."
        "raffle":
            Hints.objective = "NEXT: THE CLOSING RAFFLE IN THE BALLROOM."
    if Cards.is_open or Game.ui_open or Game.busy:
        return
    var scene := _scene_name()
    if scene == "vendor_hall" and str(Game.vars.get("conf_booth", "")) != "":
        var booth := str(Game.vars.get("conf_booth", ""))
        Game.vars["conf_booth"] = ""
        _hall_answer(booth)
        return
    if scene == _seen:
        return
    _seen = scene
    match _stage:
        "keynote":
            if scene == "ballroom":
                if badge:
                    World.clock = 9.0
                    _keynote()
                else:
                    Cards.ask("Usher", str(TEXT.usher), [{"label": "BACK TO REGISTRATION", "id": "back"}], func(_id: String) -> void: Game.go("resort_lobby", "from_ballroom"))
        "round":
            if scene == "breakout_room":
                _enter_breakout()
        "raffle":
            if scene == "ballroom":
                World.clock = 16.5
                _raffle()


func _enter_breakout() -> void:
    var idx := maxi(0, DOORS.find(str(Game.vars.get("conf_door", "from_a"))))
    var sessions: Array = ROUNDS[rnd].sessions
    var found: Dictionary = sessions[mini(idx, sessions.size() - 1)]
    _session(rnd, str(found.id))


# the easel outside each breakout room shows what is on in it (the sign effect reads this)
func sign_lines(door: int) -> Array:
    if away and _stage == "round" and rnd < ROUNDS.size():
        var sessions: Array = ROUNDS[rnd].sessions
        if door < sessions.size():
            var words := str(sessions[door].get("short", sessions[door].label)).split(" ")
            var lines := []
            var cur := ""
            for w in words:
                if cur != "" and cur.length() + 1 + str(w).length() > 9:
                    lines.append(cur)
                    cur = str(w)
                else:
                    cur = (cur + " " + str(w)).strip_edges()
            lines.append(cur)
            return lines
    return []


func _keynote() -> void:
    Cards.ask("RODENT NATION", str(TEXT.keynote), [
        {"label": "LISTEN TO THE KEYNOTE", "id": "listen"},
        {"label": "CHECK THE QUEUE ON YOUR PHONE", "id": "peek"},
    ], func(id: String) -> void: _keynote_answer(id))


func _keynote_answer(id: String) -> void:
    _stage = "round"
    rnd = 0
    World.clock = float(CLOCKS[0])
    var text := str(TEXT.keynote_listen)
    if id == "peek":
        peeked = true
        text = str(TEXT.keynote_peek)
    else:
        Skills.add_xp("people", 3)
    Cards.ask("RODENT NATION", text, [{"label": "ON TO THE SESSIONS", "id": "ok"}], func(_id: String) -> void: Hints.toast(str(TEXT.to_hall), 5.0))


func _session(index: int, id: String) -> void:
    var found: Dictionary = {}
    for s in ROUNDS[index].sessions:
        if str(s.id) == id:
            found = s
    picks.append(id)
    var text := str(found.get("text", ""))
    var skill := str(found.get("skill", ""))
    if id == "ps101":
        if Skills.ps_level < 3 and Skills.lesson_day != Campaign.day:
            Skills.ps_level += 1
            Skills.lesson_day = Campaign.day
            Skills.leveled.emit("powershell", Skills.ps_level)
        else:
            Skills.add_xp("servers", 8)
    elif id == "hipaa":
        Skills.add_xp("security", int(found.xp))
        Sales.adjust(0, 4)
    elif skill != "":
        Skills.add_xp(skill, int(found.xp))
    Cards.ask("SESSION", text, [{"label": "NEXT", "id": "ok"}], func(_id: String) -> void: _after_session(index))


func _after_session(index: int) -> void:
    rnd = index + 1
    if rnd >= ROUNDS.size():
        _stage = "raffle"
        World.clock = 16.0
        Hints.toast(str(TEXT.to_raffle), 5.0)
        return
    World.clock = float(CLOCKS[rnd])
    Hints.toast(str(TEXT.to_hall), 4.0)


func _hall() -> void:
    Cards.ask("VENDOR HALL", str(TEXT.hall), [
        {"label": "WORK THE BOOTHS FOR SWAG", "id": "swag"},
        {"label": "FIND THE FORUM REGULARS", "id": "nerds"},
        {"label": "SIT THROUGH A BACKUP DEMO", "id": "vendor"},
    ], func(id: String) -> void: _hall_answer(id))


# a booth in the vendor hall (E on it): what it gives you, once each
func booth(id: String) -> void:
    _hall_answer(id)


func _hall_answer(id: String) -> void:
    var text := ""
    if not Campaign.active:
        Hints.toast("A BOOTH. YOU CHAT AND TAKE A PEN.", 2.5)
        return
    if _booths.has(id):
        Cards.ask("VENDOR HALL", "You already visited this booth. They wave from behind the table.", [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
        return
    _booths[id] = true
    match id:
        "swag":
            Social.change_all(1)
            text = str(TEXT.hall_swag)
        "nerds":
            Nerds.karma += 4
            text = str(TEXT.hall_nerds)
        _:
            Skills.add_xp("security", 6)
            text = str(TEXT.hall_vendor)
    Cards.ask("VENDOR HALL", text, [{"label": "NEXT", "id": "ok"}], func(_id: String) -> void: pass)


func _raffle() -> void:
    var win := randf() < 0.08 + 0.04 * float(mini(entries, 3))
    var text := str(TEXT.raffle_win) if win else str(TEXT.raffle_lose)
    if win:
        Shift.add_energy(100.0)
        Campaign.adjust_rep(3)
    text += " " + str(TEXT.wrap)
    Cards.ask("RODENT NATION", text, [{"label": "FLY HOME", "id": "ok"}], func(_id: String) -> void: _finish())


func _finish() -> void:
    _stage = "done"
    Hints.objective = ""
    Game.vars["conf_booth"] = ""
    Msp.enabled = true
    Shift.skip_stay()
    World.time_scale = 1.0
    World.clock = World.DAY_END


# ---- the day report for the trip day
func adjust_report(r: Dictionary) -> Dictionary:
    if is_tech() and not away:
        tot_closed += int(r.closed)
        tot_missed += int(r.missed)
        tot_reopened += int(r.reopened)
    if away:
        r["closed"] = 0
        r["missed"] = 0
        r["reopened"] = 0
        r["open_left"] = Msp.open_tickets().size()
        r["points"] = 20
        r["pay"] = 150
        r["rep_delta"] = 2 + (1 if picks.size() >= 3 else 0)
        r["grade"] = "A"
    return r


# ---- the crowd: attendees and vendors in the venue rooms (npc.gd calls npc_use when you press E on one)
const NPC_SCENE := preload("res://scenes/npc.tscn")


func populate(stage: Node) -> void:
    if Game.title_mode:
        return
    var scene := stage.scene_file_path.get_file().get_basename()
    if scene == "conference" and Campaign.active and Meeting.state in ["called", "done"]:
        _boss(stage)
        return
    if not CROWD.has(scene):
        return
    var x0 := float(World.DATA.SCENES[scene].x0)
    for c in CROWD[scene]:
        var npc: Node = NPC_SCENE.instantiate()
        npc.character = str(c.who)
        npc.facing = str(c.facing)
        npc.role = str(c.role)
        npc.routine = PackedStringArray(c.routine)
        npc.start_seat = str(c.get("seat", ""))
        npc.position = Vector2(x0 + float(c.x), 118.0)
        stage.get_node("Actors").add_child(npc)


# during the all-hands the boss stands at the whiteboard: Morgan (tech campaign) or Marge, the bookkeeper (owner campaign)
func _boss(stage: Node) -> void:
    var owner_mode := Campaign.mode == "owner"
    var npc: Node = NPC_SCENE.instantiate()
    npc.character = "office_marge" if owner_mode else "office_morgan"
    npc.facing = "right"
    npc.role = "boss:marge" if owner_mode else "boss:morgan"
    npc.routine = PackedStringArray(["wait:8", "talk:3"])
    npc.position = Vector2(float(World.DATA.SCENES["conference"].x0) + 60.0, 118.0)
    stage.get_node("Actors").add_child(npc)


func npc_use(npc: Node, _body: Node) -> void:
    var role := str(npc.role)
    if role.begins_with("boss:"):
        var who := role.substr(5)
        Cards.ask("Morgan (Manager)" if who == "morgan" else "Marge (Bookkeeper)", str(TEXT.get("boss_" + who, "Thanks for coming.")), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
    elif role == "checkin":
        _checkin()
    elif role == "site:owner":
        Onsite.interact("owner")
    elif role.begins_with("site:"):
        Onsite.interact("staff")
    elif role.begins_with("vendor:"):
        _pitch(role.substr(7))
    elif role.begins_with("att:"):
        _chat(int(role.substr(4)) % CHATS.size())


func _checkin() -> void:
    var text := str(TEXT.checkin_again)
    if not badge:
        badge = true
        text = str(TEXT.checkin)
    Cards.ask("Registration", text, [{"label": "THANKS", "id": "ok"}], func(_id: String) -> void: pass)


func _vendor(id: String) -> Dictionary:
    for v in VENDORS:
        if str(v.id) == id:
            return v
    return {}


func _pitch(id: String) -> void:
    var v := _vendor(id)
    if v.is_empty():
        return
    if _met.has(id):
        Cards.ask(str(v.speaker), str(TEXT.vendor_again), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
        return
    var options := []
    for o in v.options:
        options.append({"label": str(o.label), "id": str(o.id)})
    Cards.ask(str(v.speaker), str(v.text), options, func(oid: String) -> void: _pitch_answer(id, oid))


const VENDOR_XP := {
    "backup": {"demo": ["security", 6], "price": ["people", 3]},
    "webwoot": {"demo": ["security", 6], "price": ["servers", 3]},
    "psa": {"demo": ["people", 6], "price": ["networking", 3]},
}


func _pitch_answer(id: String, oid: String) -> void:
    var v := _vendor(id)
    var text := ""
    for o in v.options:
        if str(o.id) == oid:
            text = str(o.text)
    if oid != "no":
        _met[id] = true
    if oid == "scan":
        spam += 1
        entries += 1
    elif VENDOR_XP.get(id, {}).has(oid):
        var fx: Array = VENDOR_XP[id][oid]
        Skills.add_xp(str(fx[0]), int(fx[1]))
    Cards.ask(str(v.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _chat(index: int) -> void:
    var c: Dictionary = CHATS[index]
    if _talked.has(index):
        Cards.ask(str(c.speaker), str(TEXT.chat_again), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
        return
    var options := []
    for o in c.options:
        options.append({"label": str(o.label), "id": str(o.id)})
    Cards.ask(str(c.speaker), _greeting() + str(c.text), options, func(oid: String) -> void: _chat_answer(index, oid))


func _greeting() -> String:
    var line := str(TEXT.get("greet_" + Nerds.rank().to_lower(), ""))
    return line + " " if line != "" else ""


func _chat_answer(index: int, oid: String) -> void:
    var c: Dictionary = CHATS[index]
    var text := ""
    for o in c.options:
        if str(o.id) == oid:
            text = str(o.text)
            if int(o.xp) > 0 and str(o.skill) != "":
                Skills.add_xp(str(o.skill), int(o.xp))
    _talked[index] = true
    if oid == "cards":
        cards_swapped += 1
        Nerds.karma += 3 if Nerds.rank() in ["REGULAR", "GURU"] else 2
    Cards.ask(str(c.speaker), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
''')


write("scripts/onsite.gd", '''extends Node
# gdlint:disable=max-line-length,max-returns
# Onsite visits (tech campaign): some tickets cannot be fixed from the RMM. The PSA shows GO ONSITE; you drive to the client
# (drive time passes, other tickets keep ageing), walk around their office (a real set, see tools/client_sets.lua) and work on
# the equipment with E: the network cabinet, the front desk PC, the printer, the server. Each client site type exists in two
# skins (a = the client, b = a prospect that looks like another business).
# The story text lives in TEXT / JOBS / EVENTS so reviewers can edit it in story/strings.txt.

const DRIVE_MINUTES := {0: 20, 1: 35, 3: 25, 8: 50, 9: 30, 10: 70}  # the usual drive to each client site
const DEFAULT_DRIVE := 45
const SLA_PER_HOUR := 45.0  # seconds taken off the other tickets' clocks for each hour you are away
const SITES := {
    0: {"type": "dental", "skin": "a"},
    1: {"type": "realty", "skin": "a"},
    3: {"type": "law", "skin": "a"},
    8: {"type": "vet", "skin": "a"},
    9: {"type": "arch", "skin": "a"},
    10: {"type": "trailer", "skin": "a"},
}
const OBJECTS := {
    "dental": ["pc", "exam", "xray", "cabinet", "server", "vip"],
    "law": ["pc", "printer", "cabinet", "server", "vip"],
    "vet": ["pc", "exam", "cabinet", "server", "vip"],
    "arch": ["pc", "printer", "cabinet", "server", "vip"],
    "realty": ["pc", "printer", "cabinet", "server", "vip"],
    "trailer": ["pc", "printer", "cabinet", "server", "vip"],
}
const PCS := {"pc": "FRONT1", "exam": "EXAM1", "vip": "OWNER1"}
const SKIN_COLORS := {
    "dental": {"a": ["#CFE8EE", "#2E9AB8"], "b": ["#F2E6EE", "#B8508A"]},
    "law": {"a": ["#6A4A38", "#C8A04A"], "b": ["#3E4A5E", "#D8D0B0"]},
    "vet": {"a": ["#CDE6C8", "#3E8E4A"], "b": ["#F6E2C0", "#E07A2E"]},
    "arch": {"a": ["#E8E6E0", "#2A2D36"], "b": ["#DCE4D4", "#B8503E"]},
    "realty": {"a": ["#F4ECD2", "#E0A030"], "b": ["#DCE6F2", "#2E5AA8"]},
    "trailer": {"a": ["#B8A27A", "#E0A030"], "b": ["#A8B0A0", "#D2452E"]},
}
const SITE_APPS := {
    "dental": {
        "app": "DENTALDESK PRO", "title": "TODAYS SCHEDULE",
        "rows": ["9:00 SMITH, J   CLEANING", "9:30 ORTEGA, M  CROWN PREP", "10:15 LEE, K     X-RAYS", "11:00 BAKER, T   FILLING", "1:00 NGUYEN, A  CONSULT"],
        "mails": [["Hygienist", "Please do not reboot the x-ray PC mid-scan"], ["Supplier", "Your order of gloves has shipped"]],
    },
    "law": {
        "app": "CASELINE 8", "title": "OPEN MATTERS",
        "rows": ["M-2231 ESTATE OF HOLLIS", "M-2240 BANKS V. COUNTY", "M-2252 LEASE REVIEW", "M-2257 CLOSING: MILL ST", "M-2261 DEPOSITION PREP"],
        "mails": [["Paralegal", "Filed with the court at 4:55 (phew)"], ["Court clerk", "Hearing moved to Thursday"]],
    },
    "vet": {
        "app": "PAWTRACK", "title": "TODAYS PATIENTS",
        "rows": ["8:30 REX (GOLDEN)   VACCINES", "9:00 MISS KITTY      CHECKUP", "9:45 BUDDY (BEAGLE)  EAR INFECTION", "10:30 OTIS (POODLE)   DENTAL", "11:15 PEANUT (HAMSTER) WEIGH-IN"],
        "mails": [["Vet tech", "The lab analyzer printed a blank page again"], ["Pet supplier", "New shipment of flea treatment"]],
    },
    "arch": {
        "app": "DRAFTBOX CAD", "title": "PROJECTS",
        "rows": ["13-011 RIVERSIDE LIBRARY", "13-017 MILL ST LOFTS", "14-002 FIRE STATION 4", "14-005 HOUSE ADDITION", "14-009 PARKING DECK"],
        "mails": [["Contractor", "Need the revised plans by noon"], ["Plotter", "Roll 40 ft almost out of paper"]],
    },
    "realty": {
        "app": "LISTINGHUB MLS", "title": "ACTIVE LISTINGS",
        "rows": ["412 OAK ST   $199K  2BD", "88 MAPLE CT  $249K  3BD", "7 LAKE RD    $325K  4BD", "1500 HILL DR $410K  4BD", "22 PINE LN   $179K  2BD"],
        "mails": [["Buyer", "Can we see the Oak St house Saturday?"], ["MLS", "Three new listings in your area"]],
    },
    "trailer": {
        "app": "DISPATCHPLUS", "title": "TODAYS JOBS",
        "rows": ["OLD MILL: IMPLOSION PREP", "FIFTH AND MAIN: STRIP OUT", "WAREHOUSE 9: HAUL AWAY", "SCHOOL ANNEX: ASBESTOS CHECK", "BRIDGE ST: EQUIPMENT MOVE"],
        "mails": [["Foreman", "Truck 3 is stuck in the mud again"], ["Safety", "Hard hat inspection tomorrow"]],
    },
}
const FINDINGS := {
    "pc": [
        {"text": "Drive C on this PC is 98 percent full. Nobody has noticed.", "summary": "Front desk PC is almost out of disk space", "fix": "clear_temp", "pri": 3, "body": "%s here: the front desk computer is getting slower every day. Can you take a look?", "project": "desktops"},
        {"text": "The antivirus on this PC expired in January. A small red shield sits in the corner and nobody clicks it.", "summary": "Antivirus expired on a PC", "fix": "av", "pri": 3, "body": "%s here: we think the antivirus on one of our PCs has expired. Please check.", "project": "security"},
    ],
    "exam": [
        {"text": "The exam room PC takes four minutes to open a chart. They have learned to start it before the patient arrives.", "summary": "Exam room PC is very slow", "fix": "clear_temp", "pri": 3, "body": "%s here: the exam room computer is crawling. Could you have a look?", "project": "desktops"},
    ],
    "vip": [
        {"text": "The owner's laptop has 41 pending updates and a sticker with a password on the lid.", "summary": "Owner's laptop needs updates and a password policy", "fix": "av", "pri": 3, "body": "%s here: could you make sure my laptop is up to date?", "project": "security"},
    ],
    "printer": [
        {"text": "The printer has a stack of old jobs stuck in the queue and a sticky note saying DO NOT USE.", "summary": "Printer queue is stuck", "fix": "spooler", "pri": 3, "body": "%s here: the printer is stuck again. Please clear it.", "project": ""},
    ],
    "cabinet": [
        {"text": "The network is on an old grey hub with no labels and no battery backup. One power flicker and everything is down.", "summary": "Replace the old hub and add a battery backup", "fix": "onsite_upgrade", "pri": 4, "body": "%s here: we would like the network to be more reliable. Could you look at the equipment in the closet?", "project": "network"},
    ],
    "server": [
        {"text": "The server's drive light has been amber for a while and the backup log says the last good copy was nine days ago.", "summary": "Server drive warning and old backup", "fix": "onsite_server", "pri": 2, "body": "%s here: someone noticed a light on the server. Can you check it today?", "project": "backup_dr"},
    ],
    "xray": [
        {"text": "The x-ray sensor cable is bent in half and held with tape. It works. For now.", "summary": "Replace a damaged x-ray sensor cable", "fix": "onsite_xray", "pri": 4, "body": "%s here: could you look at the x-ray cable before it fails on a patient day?", "project": ""},
    ],
}
const MEETINGS := {
    "qbr": {
        "text": "The owner welcomes you into the office: it is review time. Coffee, the numbers on your laptop and a client who has opinions about the printer.",
        "options": [
            {"id": "numbers", "label": "WALK THROUGH THE NUMBERS", "text": "You show them tickets closed, response times and what the backups caught. They nod a lot."},
            {"id": "listen", "label": "ASK WHAT KEEPS THEM UP AT NIGHT", "text": "They talk for twenty minutes, and then mention a problem they never reported."},
            {"id": "service", "label": "OFFER A MANAGED SERVICE", "text": "You explain how a managed service would take a worry off their plate. They ask for a proposal."},
        ],
    },
    "pitch": {
        "text": "The owner has twenty minutes. You have a folder, a business card and a company logo on your shirt. Their IT guy is a nephew.",
        "options": [
            {"id": "report", "label": "SHOW A SAMPLE REPORT", "text": "You show what a good month looks like: tickets, patches, backups. They look interested, with a pen in hand."},
            {"id": "pain", "label": "ASK ABOUT THEIR PAIN", "text": "You ask what goes wrong and then say nothing. People fill the silence, and you listen."},
            {"id": "moon", "label": "PROMISE THE MOON", "text": "You promise a ten minute response time, everything fixed by noon and free hardware. You are persuasive and you also know it is a lie."},
        ],
    },
}
const SITE_PROSPECT := {
    "dental": "BRIGHT SMILES DENTAL", "law": "SPENCE AND ROE LLP", "vet": "HAPPY TAILS VET", "arch": "NORTHLIGHT DESIGN",
    "realty": "KEYSTONE HOMES", "trailer": "BLACKROCK WRECKING",
}
const OBJECT_NAMES := {"pc": "THE FRONT DESK PC", "cabinet": "THE NETWORK CABINET", "printer": "THE PRINTER", "server": "THE SERVER"}
const TEXT := {
    "fine": "You look it over. Nothing wrong with this one.",
    "inspected": "You already looked at that one.",
    "found_ticket": "You log a ticket. The team will pick it up. The client likes that you spotted it.",
    "found_project": "You note it as an opportunity. A quote will be waiting for you in the morning.",
    "found_note": "You make a mental note. It might become a problem.",
    "found_nocampaign": "You would log a ticket for that.",
    "missed_mail": "You looked right at it when you visited and did not say a word. Now it has broken. Please look at it today.",
    "meeting_done": "The meeting is over. You shake hands and walk out.",
    "pitch_signed": "They sign. The owner walks you to the door and says to send the paperwork.",
    "pitch_think": "They will think about it. You leave a card and a folder.",
    "qbr_fee": "They are so happy they add premium support. Their fee goes up 10 percent.",
    "audit_button": "LOOK AROUND",
    "door_title": "Your van is parked out front. Where to?",
    "door_ticket": "Ticket #%d needs you onsite at %s.",
    "visit_confirm": "Drive to %s? About %d minutes each way, and the queue keeps ageing while you are out.",
    "offer": "%s needs you onsite: this cannot be fixed from the RMM. The drive takes about %d minutes each way and your other tickets keep ageing while you are out.",
    "go": "DRIVE THERE NOW",
    "later": "NOT YET",
    "arrive": "You arrive at %s after %d minutes on the road. Walk to the equipment and press E on it.",
    "nothing": "Nothing wrong with this one. Look for what the ticket describes.",
    "no_job": "Everything looks fine here.",
    "leave_unmet": "You have not met the owner yet. If you leave now the visit was a waste of a drive.",
    "arrive_visit": "You arrive at %s after %d minutes on the road. Look around first, then ask for the owner (the OWNER door).",
    "intro_mail": "From day 3, some problems cannot be fixed from the RMM: a dead switch, a failing drive. The ticket will say GO ONSITE in the PSA. You can also use the front door any time to visit a client. Mind the clock: your other tickets keep ageing while you are out. - Morgan",
    "cooldown": "You already logged something for them today. Give them a day.",
    "leave_ask": "The ticket is still open. If you leave now the client will not be happy.",
    "stay": "STAY AND FINISH",
    "leave": "LEAVE ANYWAY",
    "home": "You drive back to the office (%d minutes). The queue has grown.",
    "fixed": "Fixed onsite. The client signs the ticket and thanks you.",
    "dropped": "You left before finishing. The client is not pleased.",
    "symptom": "NO RESPONSE FROM THE HOST. NEEDS HANDS ON THE EQUIPMENT: GO ONSITE FROM THE PSA.",
    "staff": "The front desk person points you toward the equipment and offers you a coffee.",
    "printer_stars3": "FLAWLESS. The printer prints a perfect test page. The whole office applauds. (+12 servers XP)",
    "printer_stars2": "You win, with a few scratches. The printer works, mostly. (+8 servers XP)",
    "printer_stars1": "It prints. The streaks are still there but nobody will say anything. (+4 servers XP)",
    "printer_stars0": "The printer won. You close the lid and promise to send a quote for a new one.",
    "printer_practice": "This printer is acting up. Want to take a crack at it? (practice: it does not count for a ticket)",
    "printer_practice_done": "Printer repair: %d of 3 stars.",
}
const JOBS := [
    {
        "id": "switch", "object": "cabinet", "pri": 1,
        "summary": "The whole office has no network",
        "body": "Nothing works since this morning. The little box on the wall has no lights. Please come out, we cannot work. - %s",
        "intro": "The network cabinet is dark. The switch has no lights, the power adapter is warm and one cable end has been chewed.",
        "options": [
            {"id": "swap", "label": "SWAP IN A NEW SWITCH", "hours": 0.75, "chance": 1.0, "skill": "networking", "xp": 8, "text": "New switch, same cables. Everything lights up and the whole office cheers. (+8 networking XP)"},
            {"id": "reseat", "label": "RESEAT THE POWER AND THE CABLES", "hours": 0.25, "chance": 0.35, "skill": "networking", "xp": 4, "text": "It lights up for a minute, then dies again. It really needs replacing."},
            {"id": "shop", "label": "TAKE IT BACK TO THE SHOP", "hours": 0.5, "chance": 0.0, "skill": "", "xp": 0, "text": "You bag the switch. The office is down until you come back. Not great."},
        ],
    },
    {
        "id": "server", "object": "server", "pri": 1,
        "summary": "The server is beeping and email is slow",
        "body": "There is a loud beep coming from the server in the back and the email is crawling. Please send someone. - %s",
        "intro": "The server beeps every ten seconds. The front panel shows an amber light on the second drive: a failed disk in the RAID.",
        "options": [
            {"id": "hotswap", "label": "HOT-SWAP THE FAILED DRIVE", "hours": 0.75, "chance": 0.9, "skill": "servers", "xp": 8, "text": "You pull the dead disk and slide in the spare. The array starts to rebuild and the beeping stops. (+8 servers XP)"},
            {"id": "silence", "label": "SILENCE THE ALARM AND CHECK LATER", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "It is quiet now. That is not fixing it."},
            {"id": "backup", "label": "RUN A BACKUP FIRST, THEN SWAP", "hours": 1.25, "chance": 1.0, "skill": "security", "xp": 6, "text": "It takes a long time, but you have a fresh copy before touching anything. Then the swap goes smoothly. (+6 security XP)"},
        ],
    },
    {
        "id": "printer", "object": "printer", "pri": 3,
        "summary": "The big printer is making a grinding noise",
        "body": "The copier makes a terrible noise and the pages come out with black streaks. Nobody here knows what to do. - %s",
        "intro": "The printer grinds, leaves black streaks and smells hot. The fuser is shot and there is a scrap of paper wrapped around the rollers.",
        "options": [
            {"id": "fuser", "label": "REPLACE THE FUSER UNIT", "hours": 0.75, "chance": 0.9, "skill": "servers", "xp": 5, "text": "The new fuser snaps in. Crisp pages, no smell. (+5 servers XP)"},
            {"id": "clear", "label": "CLEAR THE PAPER AND CLEAN THE ROLLERS", "hours": 0.25, "chance": 0.4, "skill": "", "xp": 0, "text": "The streaks are gone, for now. The grinding comes back after twenty pages."},
            {"id": "vendor", "label": "CALL THE COPIER COMPANY", "hours": 0.15, "chance": 0.0, "skill": "people", "xp": 2, "text": "They can come Thursday. The client is not pleased."},
            {"id": "fight", "label": "OPEN IT UP AND FIGHT IT", "hours": 0.0, "chance": 1.0, "skill": "", "xp": 0, "text": "", "game": "printer"},
        ],
    },
    {
        "id": "pc", "object": "pc", "pri": 2,
        "summary": "The front desk computer will not turn on",
        "body": "Our front desk PC is dead. No lights, nothing. We cannot check anyone in. Please come as soon as you can. - %s",
        "intro": "The front desk PC does not respond at all. You swap the power cable and still nothing: the power supply is dead.",
        "options": [
            {"id": "psu", "label": "SWAP THE POWER SUPPLY", "hours": 0.5, "chance": 0.85, "skill": "servers", "xp": 6, "text": "A new power supply and the machine boots on the first try. Windows 7 never looked so good. (+6 servers XP)"},
            {"id": "loaner", "label": "SET UP THE LOANER PC", "hours": 1.0, "chance": 1.0, "skill": "people", "xp": 4, "text": "You plug in the spare and restore the user's profile. It takes a while, but they are back to work. (+4 customer XP)"},
            {"id": "ignore", "label": "TELL THEM TO TRY THE POWER BUTTON", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "They have tried the power button. Many times."},
        ],
    },
    {
        "id": "upgrade", "object": "cabinet", "pri": 4,
        "summary": "Network upgrade: replace the old hub",
        "body": "We are still on the little grey hub from 2006 and everything is slow. Can you swap it for something modern while you are here? - %s",
        "intro": "An old 10/100 hub with a rat's nest of cables. A new gigabit switch is in the box. Every cable is a mystery.",
        "options": [
            {"id": "label", "label": "LABEL EVERY CABLE, THEN SWAP", "hours": 1.5, "chance": 1.0, "skill": "networking", "xp": 10, "text": "It takes all afternoon, but every cable has a label and the new switch hums happily. (+8 networking XP)"},
            {"id": "quick", "label": "SWAP IT FAST AND TEST AFTER", "hours": 0.5, "chance": 0.65, "skill": "networking", "xp": 5, "text": "Mostly fine. One printer cable goes to the wrong port and takes a while to find."},
            {"id": "wait", "label": "COME BACK AFTER HOURS", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "You schedule it for tonight. The client is fine with that, but you have to come back."},
        ],
    },
]
const MORE_JOBS := [
    {
        "id": "exam", "object": "exam", "pri": 2,
        "summary": "The exam room computer froze with a patient in the room",
        "body": "Exam room 2 is frozen. The patient is in the chair and I cannot pull up their chart. Please hurry. - %s",
        "intro": "The exam room PC is frozen on the practice software. A patient is waiting and the chart will not load.",
        "options": [
            {"id": "restart", "label": "RESTART THE PRACTICE SOFTWARE", "hours": 0.25, "chance": 0.5, "skill": "servers", "xp": 3, "text": "The software restarts, but it hangs again when it opens the chart. Something else is wrong."},
            {"id": "profile", "label": "REBUILD THE USER PROFILE", "hours": 0.75, "chance": 0.95, "skill": "servers", "xp": 7, "text": "A new profile, a quick reconnect to the database and the chart loads. The patient waited, but only a little. (+7 servers XP)"},
            {"id": "move", "label": "MOVE THE PATIENT TO THE OTHER EXAM ROOM", "hours": 0.1, "chance": 0.0, "skill": "people", "xp": 2, "text": "That works for today. The PC is still broken."},
        ],
    },
    {
        "id": "xray", "object": "xray", "pri": 2,
        "summary": "The digital x-ray sensor is not detected",
        "body": "The x-ray sensor says NOT FOUND and the patient is waiting for a bitewing. Please come fix it. - %s",
        "intro": "The x-ray software cannot find the sensor. The USB cable has a kink and the driver shows a yellow warning.",
        "options": [
            {"id": "driver", "label": "REINSTALL THE SENSOR DRIVER", "hours": 0.5, "chance": 0.8, "skill": "servers", "xp": 6, "text": "The old driver was corrupted. The new one finds the sensor right away. (+6 servers XP)"},
            {"id": "cable", "label": "REPLACE THE USB CABLE", "hours": 0.25, "chance": 0.7, "skill": "networking", "xp": 4, "text": "A fresh cable and the sensor lights up. It was a kinked cable all along. (+4 networking XP)"},
            {"id": "call", "label": "CALL THE SENSOR VENDOR", "hours": 0.2, "chance": 0.0, "skill": "", "xp": 0, "text": "They want a serial number you cannot read. Nobody is happy."},
        ],
    },
    {
        "id": "vip", "object": "vip", "pri": 2, "vip": true,
        "summary": "The boss cannot get email on his tablet",
        "body": "My email has stopped working on my iPad and I have a big meeting this afternoon. Please fix it right away. - %s",
        "intro": "The owner's tablet shows 'Cannot get mail'. The account password changed last week and the tablet still has the old one.",
        "options": [
            {"id": "account", "label": "RE-ENTER THE ACCOUNT AND TEST IT", "hours": 0.35, "chance": 0.95, "skill": "people", "xp": 6, "text": "You re-enter the password and send a test message. He is delighted. (+6 customer XP)"},
            {"id": "wifi", "label": "CHECK THE WIFI AND REBOOT THE TABLET", "hours": 0.2, "chance": 0.3, "skill": "", "xp": 0, "text": "The wifi is fine. The email is still broken. He is watching you."},
            {"id": "later", "label": "PROMISE TO CALL HIM BACK", "hours": 0.1, "chance": 0.0, "skill": "", "xp": 0, "text": "He is not pleased: the owner notices when a visit ends with a promise."},
        ],
    },
]
const EVENTS := {
    "vet": {
        "id": "dog", "object": "pc",
        "text": "A golden retriever trots in, sniffs the front desk PC and lifts a leg. The tower sparks, the screen goes black and the dog looks very pleased.",
        "options": [
            {"id": "loaner", "label": "SET UP A LOANER PC", "hours": 1.0, "mood": 3, "text": "You set up the spare PC while the receptionist apologizes to the dog. The vet laughs and says it happens at least once a year."},
            {"id": "clean", "label": "CLEAN IT UP AND TRY TO REVIVE IT", "hours": 0.5, "mood": 1, "text": "The motherboard is a goner. You write up a bill and a story you will tell for years."},
            {"id": "laugh", "label": "TAKE A PHOTO FOR THE OFFICE", "hours": 0.0, "mood": -2, "text": "The photo is great. The vet was not amused."},
        ],
    },
    "dental": {
        "id": "patient", "object": "cabinet",
        "text": "A patient in the chair asks if you can please hurry: the internet is down and the x-ray would not load. The dentist looks at you hopefully.",
        "options": [
            {"id": "hurry", "label": "PRIORITIZE THE X-RAY WORKSTATION", "hours": 0.25, "mood": 3, "text": "You get the x-ray running first. The patient gives you a thumbs up from the chair."},
            {"id": "order", "label": "FINISH THE NETWORK FIRST", "hours": 0.0, "mood": -1, "text": "The dentist sighs. The patient reschedules."},
        ],
    },
    "law": {
        "id": "call", "object": "cabinet",
        "text": "Atty. Spence is on a call with a client and waves you silent. You crouch in the coat closet next to the server rack for twenty minutes.",
        "options": [
            {"id": "wait", "label": "WAIT QUIETLY", "hours": 0.35, "mood": 3, "text": "The attorney mouths a thank you when the call ends."},
            {"id": "work", "label": "KEEP WORKING (QUIETLY)", "hours": 0.0, "mood": -2, "text": "A cable tie snaps loudly in the middle of the call. Oops."},
        ],
    },
    "arch": {
        "id": "plot", "object": "printer",
        "text": "The plotter just chewed a forty-foot roll of drawings that are due at noon. Erik Lindqvist stares at you, then at the plotter, then at you.",
        "options": [
            {"id": "free", "label": "FREE THE ROLL AND REPRINT", "hours": 0.5, "mood": 4, "text": "You pull the paper out in one piece and reprint. The architect nearly hugs you."},
            {"id": "blame", "label": "SAY IT IS A PAPER PROBLEM", "hours": 0.0, "mood": -3, "text": "It was not a paper problem. He knows."},
        ],
    },
    "realty": {
        "id": "showing", "object": "pc",
        "text": "A showing is in progress: strangers walk through the office while you crawl under a desk to reach the cables.",
        "options": [
            {"id": "smile", "label": "SMILE AND KEEP WORKING", "hours": 0.1, "mood": 2, "text": "Karen introduces you as her IT genius. The prospects nod politely."},
            {"id": "hide", "label": "WAIT UNTIL THEY LEAVE", "hours": 0.3, "mood": 0, "text": "You spend ten minutes under the desk. Your knees will remember this."},
        ],
    },
    "trailer": {
        "id": "breaker", "object": "server",
        "text": "The space heater trips the breaker and the whole trailer goes dark. The foreman swears. Your laptop is the only thing still on.",
        "options": [
            {"id": "reset", "label": "RESET THE BREAKER AND TELL THEM ABOUT THE HEATER", "hours": 0.25, "mood": 3, "text": "The lights come back. The foreman grudgingly moves the heater to another outlet."},
            {"id": "ups", "label": "PLUG THE SERVER INTO A BATTERY BACKUP", "hours": 0.3, "mood": 2, "text": "You bring in a small UPS from the van. The server survives the next brownout."},
        ],
    },
}
const STAFF := {
    "dental": ["Dr. Patel is with a patient. The x-ray machine is that grey box by the chair.", "We have a patient in the chair, so please keep the vacuum noises to a minimum.", "The coffee is for patients, but I will not tell if you have one."],
    "law": ["Please be quiet in the hall, Mr. Spence is on the phone with a judge.", "Everything here is confidential. Do not read anything on the desks.", "The copier is cranky. We name it after the opposing counsel."],
    "vet": ["Do not mind the dog. She likes computers. Too much.", "If you hear a howl from the back, it is just Otis getting his nails done.", "We have a cat in the closet. She is not lost. She is hiding from the beagle."],
    "arch": ["The plotter has opinions today. Good luck.", "Mind the model on the table, it took three weeks. And a lot of glue.", "If you move my pencil I will know."],
    "realty": ["I have a showing at one, so please be quick. Do you want coffee?", "Every house has a story. Most of them involve the plumbing.", "Do not mind the lockbox on the desk. It is very important."],
    "trailer": ["Mind the mud. And do not touch the heater. Last guy did and it was a whole thing.", "If the siren goes off, walk. Do not run. That is the demolition rule.", "The trailer shakes a little when they drop a wall. You get used to it."],
}
const NPC_SCENE := preload("res://scenes/npc.tscn")
const CAST_AT := {   # [character, x, role] per site type, skin and room (main office, exam room, owner office)
    "dental": {
        "a": {"main": [["client_dentrec_a", 104, "staff"], ["client_hygienist", 190, "staff"]], "exam": [["client_dentasst", 150, "staff"]], "office": [["expo_atta", 150, "owner"]]},
        "b": {"main": [["client_dentrec_b", 104, "staff"], ["expo_attd", 190, "staff"]], "exam": [["client_denthyg_b", 150, "staff"]], "office": [["client_dentdoc_b", 150, "owner"]]},
    },
    "vet": {
        "a": {"main": [["client_vetrec_a", 104, "staff"], ["expo_vendh", 190, "staff"]], "exam": [["client_vettech_a", 150, "staff"]], "office": [["client_brandt", 150, "owner"]]},
        "b": {"main": [["client_vetrec_b", 104, "staff"], ["client_vettech_b", 190, "staff"]], "exam": [["expo_vendi", 150, "staff"]], "office": [["client_vetdoc_b", 150, "owner"]]},
    },
    "law": {
        "a": {"main": [["client_paralegal", 170, "staff"], ["expo_attc", 214, "staff"]], "office": [["expo_attb", 150, "owner"]]},
        "b": {"main": [["expo_attf", 170, "staff"], ["client_paralegal_b", 214, "staff"]], "office": [["client_attorney_b", 150, "owner"]]},
    },
    "arch": {
        "a": {"main": [["client_designer_a", 160, "staff"], ["expo_atte", 214, "staff"]], "office": [["expo_vendp", 150, "owner"]]},
        "b": {"main": [["client_designer_b", 160, "staff"], ["expo_atta", 214, "staff"]], "office": [["client_mina", 150, "owner"]]},
    },
    "realty": {
        "a": {"main": [["client_agent_a", 100, "staff"], ["expo_vendp", 230, "staff"]], "office": [["client_karen", 150, "owner"]]},
        "b": {"main": [["client_agent_b", 100, "staff"], ["expo_attc", 230, "staff"]], "office": [["expo_atte", 150, "owner"]]},
    },
    "trailer": {
        "a": {"main": [["expo_vendo", 170, "staff"], ["expo_vendj", 214, "staff"]], "office": [["expo_attb", 150, "owner"]]},
        "b": {"main": [["client_foreman_a", 170, "staff"]], "office": [["expo_atta", 150, "owner"]]},
    },
}
const OWNER_B := {
    "dental": "Dr. Okafor", "law": "Atty. Roe", "vet": "Dr. Salazar", "arch": "Anika Northlight",
    "realty": "Marcus Keystone", "trailer": "Rex Blackrock",
}
const PETS := {
    "dog": ["You scratch behind the dog's ears. Her tail thumps the floor.", "The dog leans against your leg and sighs happily.", "A very good dog. She licks your hand."],
    "cat": ["The cat purrs and head-butts your hand.", "You pet the cat. She tolerates it. Mostly.", "The cat stretches out and shows you her belly. It is a trap, but you pet her anyway."],
    "fish": ["You tap the glass. The fish pretends not to know you.", "The orange fish swims to the glass, looks at you and leaves."],
    "coffeebar": ["You pour a cup from the glass pot. It has been on the burner since the spring open house, but it is free.", "You fill a mug that says #1 IN SALES (2009). The coffee is hot and tastes like the pot.", "You help yourself to the open house coffee. The tip jar says 'for the intern'. You leave a quarter."],
    "coffeebar_full": ["You already have a cup. Greed is a sin, even in real estate.", "Your hands are full of coffee. The pot will wait."],
    "signin": ["You sign in. Reason for visit: 'IT'. Under it a previous visitor wrote 'Dave - plumbing - yes'.", "The pen is on a string and the string is shorter than your arm. You sign sideways.", "NAME / COMPANY / TIME IN / REASON. The last line says 'Karen - Karen - 9:02 - I am the owner'."],
    "recep": ["The receptionist: 'Are you here about the plotter? Please say you are here about the plotter.'", "The receptionist: 'The principals are in a charrette until five. Can I get you a coffee?'", "A roll of drawings on the desk has a sticky note: DO NOT TOUCH. NOT EVEN YOU, STEVE."],
}

var enabled := false  # set by the title menu, so older tests are not disturbed by onsite tickets
var visit_kind := ""  # "" (a plain visit or a job), "qbr" (a business review) or "pitch" (a prospect)
var visit_prospect := false  # the prospect's own office (the b skin)
var visit_findings := 0
var _inspected := {}
var _met := false
var _missed: Array = []
var _logged_day := {}
var _prev_msp := true
var _back_min := 45
var _prev_scale := 1.0
var active := false  # you are at a client site
var busy := false  # a visit is in progress (the day cannot end)
var ticket_id := 0
var client := -1
var job: Dictionary = {}
var done := false
var visits := 0
var fixed_count := 0
var pets := 0
var _pet_energy := 0
var _pet_first := true
var _event_done := false
var _roll_day := -1
var _spawn_at := -1.0


func _ready() -> void:
    Campaign.day_started.connect(_on_day)


func reset() -> void:
    active = false
    busy = false
    ticket_id = 0
    client = -1
    job = {}
    done = false
    visits = 0
    fixed_count = 0
    pets = 0
    _pet_energy = 0
    _pet_first = true
    _missed = []
    _logged_day = {}
    _inspected = {}
    visit_kind = ""
    visit_prospect = false
    _met = false
    _event_done = false
    _roll_day = -1
    _spawn_at = -1.0


func to_dict() -> Dictionary:
    return {"visits": visits, "fixed": fixed_count, "pets": pets, "missed": _missed}


func from_dict(data: Dictionary) -> void:
    reset()
    visits = int(data.get("visits", 0))
    fixed_count = int(data.get("fixed", 0))
    pets = int(data.get("pets", 0))
    _missed = data.get("missed", [])


func is_tech() -> bool:
    return Campaign.active and Campaign.mode == "tech"


func site_scene(client_index: int, prospect := false) -> String:
    var site: Dictionary = SITES.get(client_index, {})
    if site.is_empty():
        return ""
    return "site_%s_%s" % [str(site.type), "b" if prospect else str(site.skin)]


func site_type(client_index: int) -> String:
    return str(SITES.get(client_index, {}).get("type", ""))


func has_site(client_index: int) -> bool:
    return SITES.has(client_index)


# ---- onsite tickets turn up now and then
func _on_day(day: int) -> void:
    _spawn_at = -1.0
    _pet_energy = 0
    _missed_follow_up()
    if not enabled or not is_tech() or day < 3 or Game.title_mode:
        return
    if day == 3:
        Msp.mail(Story.MANAGER, "Onsite visits", str(TEXT.intro_mail))
    var guaranteed := day == 6 or day == 11 or day == 15
    var skip := [7, 9, 10, 12, 13, 16, 17, 18, 20].has(day)
    for t in Msp.tickets:
        if t.status != "Closed" and is_onsite(t):
            skip = true  # one onsite problem at a time
    if guaranteed or (not skip and randf() < 0.5):
        _spawn_at = 10.0 + randf() * 4.0
        if [5, 6, 10, 11, 15].has(day):
            _spawn_at = 9.6 + randf() * 1.6  # before the all-hands and the evening outing


func _process(_delta: float) -> void:
    if _spawn_at < 0.0 or not is_tech() or Game.title_mode or World.time_scale <= 0.0 or active:
        return
    if World.clock >= _spawn_at and World.clock < World.DAY_END - 1.0:
        _spawn_at = -1.0
        create_job()


func create_job(client_index := -1, job_id := "") -> Dictionary:
    var options := []
    for c in Sales.active:
        if SITES.has(int(c)) and Sales.takes_tickets(int(c)):
            options.append(int(c))
    if client_index < 0:
        if options.is_empty():
            return {}
        client_index = options[randi() % options.size()]
    var type := site_type(client_index)
    var pool := []
    var here: Array = OBJECTS.get(type, [])
    for j in JOBS + MORE_JOBS:
        if (job_id == "" or str(j.id) == job_id) and here.has(str(j.object)):
            pool.append(j)
    if pool.is_empty() or type == "":
        return {}
    var pick: Dictionary = pool[randi() % pool.size()]
    var prob := {
        "summary": str(pick.summary), "fix": "onsite_" + str(pick.id), "pri": int(pick.pri), "body": str(pick.body),
        "server": str(pick.object) == "server",
    }
    var made := Msp.create_problem(client_index, prob, "phone")
    if not made.is_empty() and Campaign.active:
        # the clock is paused on the road, but the client still expects a visit to be possible:
        # add the round trip (plus some work) to the SLA, in the same units as `_away`
        var extra := float(drive_minutes(client_index) * 2 + 30) / 60.0 * 60.0
        extra *= World.day_len / 600.0
        made.sla_total = float(made.sla_total) + extra
        made.sla_left = float(made.sla_left) + extra
    return made


func is_onsite(t: Dictionary) -> bool:
    return str(t.get("fix", "")).begins_with("onsite_")


func job_for(t: Dictionary) -> Dictionary:
    var id := str(t.get("fix", "")).trim_prefix("onsite_")
    for j in JOBS + MORE_JOBS:
        if str(j.id) == id:
            return j
    return {}


# ---- drive times: each site has its usual drive, and traffic changes it a little (never under 10 minutes)
func drive_minutes(c: int) -> int:
    return int(DRIVE_MINUTES.get(c, DEFAULT_DRIVE))


# the roads are busier at the morning rush, over lunch and especially in the evening rush
func traffic_factor(hour := -1.0) -> float:
    var h := World.clock if hour < 0.0 else hour
    if h < 9.5:
        return 1.35
    if h >= 16.0:
        return 1.45
    if h >= 11.5 and h < 13.5:
        return 1.2
    return 1.0


func traffic_label(hour := -1.0) -> String:
    var f := traffic_factor(hour)
    if f >= 1.4:
        return "EVENING RUSH HOUR" if (World.clock if hour < 0.0 else hour) >= 16.0 else "RUSH HOUR"
    if f >= 1.3:
        return "RUSH HOUR"
    if f > 1.0:
        return "LUNCH TRAFFIC"
    return "CLEAR ROADS"


# what the trip should take right now (shown on the cards)
# how many open tickets would run out of time during a trip of this many minutes (there and back, plus some work)
func at_risk(minutes: int, except_id := 0) -> int:
    var hours := float(minutes * 2 + 30) / 60.0
    var n := 0
    var scale := World.day_len / 600.0
    for t in Msp.tickets:
        if t.status != "Closed" and int(t.id) != except_id and float(t.sla_left) - hours * SLA_PER_HOUR * scale <= float(t.sla_total) * 0.4:
            n += 1
    return n


func _risk_text(c: int, except_id := 0) -> String:
    var n := at_risk(estimate_minutes(c), except_id) if Campaign.active else 0
    return "" if n == 0 else " %d of your open tickets will be close to breaching by the time you are back." % n


func estimate_minutes(c: int) -> int:
    return maxi(10, int(round(float(drive_minutes(c)) * traffic_factor() / 5.0)) * 5)


func _trip_minutes(c: int) -> int:
    var base := float(drive_minutes(c)) * traffic_factor()
    return maxi(10, int(round(base * randf_range(0.9, 1.15) / 5.0)) * 5)


# ---- the front door: choose where to drive (the ticket you are working comes first)
func focus_ticket() -> Dictionary:
    var sel := Msp.ticket(Computer.psa_sel)
    if not sel.is_empty() and sel.status != "Closed" and is_onsite(sel) and has_site(int(sel.client)):
        return sel
    for t in Msp.tickets:
        if t.status != "Closed" and is_onsite(t) and has_site(int(t.client)):
            return t
    return {}


func door_clients() -> Array:
    var list := []
    for c in SITES:
        var mine := Sales.active.has(int(c)) or not Campaign.active
        for t in Msp.tickets:
            if int(t.client) == int(c) and t.status != "Closed" and is_onsite(t):
                mine = true
        if mine:
            list.append(int(c))
    list.sort()
    var focus := focus_ticket()
    if not focus.is_empty() and list.has(int(focus.client)):
        list.erase(int(focus.client))
        list.push_front(int(focus.client))
    return list


func offer_door() -> void:
    if active or Cards.is_open or Game.ui_open:
        return
    _door_page(door_clients(), 0)


func _door_page(list: Array, page: int) -> void:
    var per := 2
    var focus := focus_ticket()
    var text := str(TEXT.door_title) + " " + traffic_label() + "."
    if not focus.is_empty() and page == 0:
        text = str(TEXT.door_ticket) % [int(focus.id), str(Msp.CLIENTS[int(focus.client)].name)]
        text += " " + traffic_label() + "."
    var options := []
    for c in list.slice(page * per, page * per + per):
        var label := "TO " + str(Msp.CLIENTS[int(c)].name).to_upper()
        label += " (%d MIN" % estimate_minutes(int(c))
        if not focus.is_empty() and int(focus.client) == int(c):
            label += ", TICKET #%d" % int(focus.id)
        label += ")"
        options.append({"label": label.left(44), "id": "c%d" % int(c)})
    if (page + 1) * per < list.size():
        options.append({"label": "MORE SITES...", "id": "more"})
    elif page > 0:
        options.append({"label": "BACK TO THE FIRST PAGE", "id": "back"})
    options.append({"label": "STAY HERE", "id": "leave"})
    Cards.ask("Front door", text, options, func(id: String) -> void: _door_pick(id, list, page))


func _door_pick(id: String, list: Array, page: int) -> void:
    if id == "more":
        _door_page(list, page + 1)
    elif id == "back":
        _door_page(list, 0)
    elif id.begins_with("c"):
        _go_site(int(id.substr(1)))


func _go_site(c: int) -> void:
    var focus := focus_ticket()
    var ticket := {}
    if not focus.is_empty() and int(focus.client) == c:
        ticket = focus
    else:
        for t in Msp.tickets:
            if int(t.client) == c and t.status != "Closed" and is_onsite(t):
                ticket = t
                break
    if not ticket.is_empty():
        offer(int(ticket.id))
        return
    Cards.ask("Dispatch", _visit_text(c) + _risk_text(c), [
        {"label": str(TEXT.go), "id": "go"},
        {"label": str(TEXT.later), "id": "later"},
    ], func(pick: String) -> void: _free_visit(pick, c))


func _free_visit(pick: String, c: int) -> void:
    if pick != "go":
        return
    if Computer.is_open:
        Computer.close()
    ticket_id = 0
    client = c
    job = {}
    done = false
    _event_done = false
    _begin_trip()
    var mins := _trip_minutes(client)
    _back_min = _trip_minutes(client)
    _away(float(mins) / 60.0)
    active = true
    _pet_first = true
    Game.go(site_scene(client, visit_prospect), "from_van")
    Hints.toast(str(TEXT.arrive_visit if visit_kind != "" else TEXT.arrive) % [str(Msp.CLIENTS[client].name), mins], 5.0)


# a business review (qbr) or a pitch to a prospect, at their own office
func start_visit(c: int, kind: String) -> void:
    if active or not has_site(c):
        return
    visit_kind = kind
    visit_prospect = kind == "pitch"
    _free_visit("go", c)


# freeze the office while you are away, remembering how it was (Free Play keeps its own settings)
func _begin_trip() -> void:
    _inspected = {}
    _met = false
    visit_findings = 0
    busy = true
    visits += 1
    _prev_msp = Msp.enabled
    _prev_scale = World.time_scale
    Msp.enabled = false
    World.time_scale = 0.0


# ---- go there
func offer(id: int) -> void:
    var t := Msp.ticket(id)
    if t.is_empty() or not is_onsite(t) or active or Cards.is_open:
        return
    if t.status == "Closed":
        Hints.toast("THAT TICKET IS ALREADY CLOSED.", 2.5)
        return
    if not has_site(int(t.client)):
        Hints.toast("NO SITE FOR THIS CLIENT YET.", 2.5)
        return
    Cards.ask("Dispatch", str(TEXT.offer) % [str(Msp.CLIENTS[int(t.client)].name), estimate_minutes(int(t.client))] + _risk_text(int(t.client), id), [
        {"label": str(TEXT.go), "id": "go"},
        {"label": str(TEXT.later), "id": "later"},
    ], func(pick: String) -> void: _offer_answer(pick, id))


func _offer_answer(pick: String, id: int) -> void:
    if pick == "go":
        _depart(id)


func _away(hours: float, except_id := 0) -> void:
    if not Campaign.active:
        return  # Free Play: the trip takes no time
    World.clock = minf(23.0, World.clock + hours)
    var scale := World.day_len / 600.0
    for t in Msp.tickets:
        if t.status != "Closed" and int(t.id) != except_id:
            t.sla_left = maxf(float(t.sla_total) * 0.35, t.sla_left - hours * SLA_PER_HOUR * scale)
    Shift.add_energy(-2.0 * hours)


func _depart(id: int) -> void:
    var t := Msp.ticket(id)
    if t.is_empty():
        return
    if Computer.is_open:
        Computer.close()
    ticket_id = id
    client = int(t.client)
    job = job_for(t)
    done = false
    _event_done = false
    _begin_trip()
    Msp.set_status(id, "In Progress")
    Msp.add_note(id, "Technician dispatched onsite.")
    var mins := _trip_minutes(client)
    _back_min = _trip_minutes(client)
    _away(float(mins) / 60.0, id)
    active = true
    _pet_first = true
    Game.go(site_scene(client), "from_van")
    Hints.toast(str(TEXT.arrive) % [str(Msp.CLIENTS[client].name), mins], 5.0)


# ---- at the site (E on the equipment, see fx kinds onsite_*)
func interact(obj: String) -> void:
    if Cards.is_open or Game.ui_open:
        return
    if obj == "door":
        _leave()
        return
    if obj in ["pc", "exam", "vip"]:
        _open_pc(obj)
        return
    if obj in ["dog", "cat", "fish"]:
        _pet(obj)
        return
    if obj in ["coffeebar", "signin", "recep"]:
        _site_line(obj)
        return
    if obj == "owner" and visit_kind != "" and not _met:
        _meeting()
        return
    if obj == "owner":
        var c := _site_client()
        var who := _owner_name(c)
        var greetings := [
            "Thank you for coming out. Let me know if you need anything.",
            "Come in, come in. Excuse the mess, it is a busy week.",
            "I appreciate you stopping by. Most IT people only call.",
        ]
        Cards.ask(who, "%s: %s" % [who, str(greetings[randi() % greetings.size()])], [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
        return
    if obj == "staff":
        var lines: Array = STAFF.get(site_type(client), [str(TEXT.staff)])
        Cards.ask("Staff", str(lines[randi() % lines.size()]), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)
        return
    if obj == "printer" and (not active or job.is_empty() or done or str(job.object) != "printer"):
        _printer_practice()
        return
    if not active:
        Hints.toast(str(TEXT.no_job), 2.0)
        return
    if job.is_empty() or done or obj != str(job.object):
        inspect(obj)
        return
    _work()


# the client's own computer: their desktop, their software, their mail. Your tools are in the TOOLS window.
func _scene_name() -> String:
    var sc := get_tree().current_scene
    return "" if sc == null else sc.scene_file_path.get_file().get_basename()


func _site_client() -> int:
    if client >= 0:
        return client
    var type := _scene_name().split("_")[1] if _scene_name().begins_with("site_") else ""
    for c in SITES:
        if str(SITES[c].type) == type:
            return int(c)
    return 0


# the prospect's office (the b skin) is the lead's own company: the sign, the PC and the owner use
# the client's real name and contact, so the lead card, the sign and the speaker all agree
func _host_prefix(c: int, _skin: String) -> String:
    return str(Msp.CLIENTS[c].short)


func _owner_name(c: int) -> String:
    return str(Msp.CLIENTS[c].contact)


func _open_pc(obj: String) -> void:
    var c := _site_client()
    var type := site_type(c)
    var scene := _scene_name()
    var skin := "b" if scene.ends_with("_b") else "a"
    var apps: Dictionary = SITE_APPS.get(type, {})
    var cols: Array = SKIN_COLORS.get(type, {}).get(skin, ["#CFE8EE", "#2E9AB8"])
    var mails := []
    if active and not job.is_empty():
        var t := Msp.ticket(ticket_id)
        if not t.is_empty():
            mails.append([str(Msp.CLIENTS[c].contact), "HELP: " + str(t.summary)])
    for mail in apps.get("mails", []):
        mails.append(mail)
    var info := {
        "name": str(Msp.CLIENTS[c].name).to_upper(),
        "type": type, "obj": obj, "wall": cols[0], "accent": cols[1],
        "pc": "%s-%s" % [_host_prefix(c, skin), str(PCS.get(obj, "PC1"))],
        "user": _owner_name(c),
        "app": str(apps.get("app", "PRACTICE")), "title": str(apps.get("title", "")), "rows": apps.get("rows", []),
        "mails": mails,
        "net": "NO NETWORK CONNECTION" if active and not done and not job.is_empty() and str(job.object) == "cabinet" else "CONNECTED",
    }
    Computer.open_site(info)


func job_here(obj: String) -> bool:
    return active and not job.is_empty() and not done and str(job.object) == obj


# the TOOLS window: DIAGNOSE AND FIX
func pc_diagnose(obj: String) -> void:
    if not active or job.is_empty() or done or str(job.object) != obj:
        Hints.toast(str(TEXT.nothing), 2.5)
        return
    _work()


# ---- walk-around: sales people and owners notice things while they visit, and can log them as tickets
func inspect(obj: String) -> void:
    if _inspected.has(obj):
        Hints.toast(str(TEXT.inspected), 2.0)
        return
    _inspected[obj] = true
    var pool: Array = FINDINGS.get(obj, [])
    var chance := 0.7 if visit_kind != "" else 0.3
    if pool.is_empty() or randf() > chance:
        Hints.toast(str(TEXT.fine), 2.0)
        return
    _found(pool[randi() % pool.size()])


func _found(f: Dictionary) -> void:
    var options := [{"label": "LOG A TICKET", "id": "ticket"}]
    if Owner.active() and str(f.get("project", "")) != "":
        options.append({"label": "SELL IT AS A PROJECT", "id": "project"})
    if visit_prospect:
        options = [{"label": "TELL THEM ABOUT IT (BUILDS YOUR PITCH)", "id": "tell"}]
    options.append({"label": "MAKE A NOTE FOR LATER", "id": "note"})
    Cards.ask("You notice something", str(f.text), options, func(id: String) -> void: _found_answer(f, id))


func _found_answer(f: Dictionary, id: String) -> void:
    var c := _site_client()
    visit_findings += 1
    if id in ["ticket", "project"]:
        if int(_logged_day.get(c, -1)) == Campaign.day:
            Hints.toast(str(TEXT.cooldown), 3.0)
            return
        _logged_day[c] = Campaign.day
    if id == "tell":
        Hints.toast("YOU MENTION IT. THEY LOOK IMPRESSED.", 3.0)
    elif id == "ticket":
        if Campaign.active:
            var prob := {"summary": str(f.summary), "fix": str(f.fix), "pri": int(f.pri), "body": str(f.body)}
            Msp.create_problem(c, prob, "walk-around")
            Sales.adjust(c, 2)
            Hints.toast(str(TEXT.found_ticket), 3.5)
        else:
            Hints.toast(str(TEXT.found_nocampaign), 3.0)
    elif id == "project":
        Projects.offer_project(c, str(f.project))
        Sales.adjust(c, 1)
        Hints.toast(str(TEXT.found_project), 3.5)
    else:
        if Campaign.active:
            _missed.append({"client": c, "f": f})
        Hints.toast(str(TEXT.found_note), 3.0)


# something you saw and did not log may break by itself
func _missed_follow_up() -> void:
    var keep: Array = []
    for entry in _missed:
        if randf() < 0.25 and Campaign.active and Msp.enabled:
            var f: Dictionary = entry.f
            var prob := {"summary": str(f.summary), "fix": str(f.fix), "pri": 2, "body": str(TEXT.missed_mail) + " - %s"}
            Msp.create_problem(int(entry.client), prob, "email")
            Sales.adjust(int(entry.client), -2)
        else:
            keep.append(entry)
    _missed = keep


# ---- the meeting with the owner (a business review or a pitch)
func _meeting() -> void:
    var mt: Dictionary = MEETINGS.get(visit_kind, {})
    if mt.is_empty():
        return
    var options := []
    for o in mt.options:
        options.append({"label": str(o.label), "id": str(o.id)})
    Cards.ask(_owner_name(_site_client()), str(mt.text), options, func(id: String) -> void: _meeting_answer(id))


func _meeting_answer(id: String) -> void:
    var c := _site_client()
    var mt: Dictionary = MEETINGS.get(visit_kind, {})
    var text := ""
    for o in mt.get("options", []):
        if str(o.id) == id:
            text = str(o.text)
    _met = true
    if visit_kind == "qbr":
        match id:
            "numbers":
                Sales.adjust(c, 6)
                if randf() < 0.4:
                    Owner.apply({"fee_boost": {"client": c, "mult": 1.1}})
                    text += " " + str(TEXT.qbr_fee)
            "listen":
                Sales.adjust(c, 10)
                var pool: Array = FINDINGS.get(["cabinet", "server", "pc"][randi() % 3], [])
                if not pool.is_empty():
                    Cards.ask("The owner", text, [{"label": "GO ON", "id": "ok"}], func(_id: String) -> void: _found(pool[randi() % pool.size()]))
                    return
            _:
                Sales.adjust(c, 4)
                Projects._queue.append({"kind": "service", "client": c, "id": "patching" if Projects.has_service(c, "backup") else "backup"})
    elif visit_kind == "pitch":
        var odds := 0.55
        if id == "pain":
            odds = 0.8 if visit_findings > 0 else 0.5
        elif id == "moon":
            odds = 0.45
        if randf() < odds:
            Sales.sign_client(c)
            if id == "moon":
                Sales.adjust(c, -8)
            text += " " + str(TEXT.pitch_signed)
        else:
            text += " " + str(TEXT.pitch_think)
    Cards.ask(_owner_name(c), text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


# the realty coffee bar (a cup of coffee), the sign-in clipboard and the architects' reception desk (a line, no game effect)
func _site_line(kind: String) -> void:
    var p := get_tree().current_scene.get_node_or_null("Actors/Player")
    var key := kind
    if kind == "coffeebar" and p != null and str(p.held) == "coffee":
        key = "coffeebar_full"
    var lines: Array = PETS.get(key, [])
    if lines.is_empty():
        return
    Hints.toast(str(lines[randi() % lines.size()]), 3.0)
    if key == "coffeebar":
        get_tree().create_timer(1.0).timeout.connect(_pour.bind(p))


func _pour(p: Node) -> void:
    if is_instance_valid(p) and p.has_method("give"):
        p.give("coffee")


# you can always pet the animals (the rules)
func _pet(kind: String) -> void:
    var lines: Array = PETS.get(kind, [])
    if lines.is_empty():
        return
    pets += 1
    Career.add("pets")
    Hints.toast(str(lines[randi() % lines.size()]), 3.0)
    var p := get_tree().current_scene.get_node_or_null("Actors/Player")
    if p != null and p.has_method("start_emote") and kind != "fish":
        p.start_emote("reach", 2.8, p.global_position.x + (10.0 if p.facing == "right" else -10.0), "heart")
    if Campaign.active and Shift.active() and _pet_energy < 3:
        _pet_energy += 1
        Shift.add_energy(1.0)
    if active and client >= 0 and _pet_first:
        _pet_first = false
        Sales.adjust(client, 1)


func _work() -> void:
    var options := []
    for o in job.options:
        options.append({"label": str(o.label), "id": str(o.id)})
    Cards.ask("Onsite: " + str(Msp.CLIENTS[client].name), str(job.intro), options, func(id: String) -> void: _chose(id))


func _chose(id: String) -> void:
    var opt: Dictionary = {}
    for o in job.options:
        if str(o.id) == id:
            opt = o
    if str(opt.get("game", "")).begins_with("printer"):
        PrinterGame.start(
            func(stars: int) -> void: _printer_done(stars),
            _printer_model(str(opt.get("game", ""))),
            {"onsite": true}
        )
        return
    _away(float(opt.hours), ticket_id)
    var ok := randf() < float(opt.chance)
    var text := str(opt.text)
    if float(opt.chance) <= 0.0:
        Sales.adjust(client, -4 if bool(job.get("vip", false)) else -2)
    if ok:
        if str(opt.skill) != "":
            Skills.add_xp(str(opt.skill), int(opt.xp))
        done = true
    Cards.ask("Onsite", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: _after(ok))


# the printer mini-game finished: its stars decide how it went
func _printer_done(stars: int) -> void:
    if stars < 0:
        _work()  # backed out before starting: nothing happened
        return
    _away(maxf(0.25, 1.1 - 0.25 * float(stars)), ticket_id)
    var ok := stars >= 1
    if ok:
        Skills.add_xp("servers", 4 * stars)
        done = true
    Cards.ask("Onsite", str(TEXT.get("printer_stars%d" % stars, "")), [{"label": "OK", "id": "ok"}], func(_id: String) -> void: _after(ok))


# which printer model fights back: the job's game field can force one ("printer:inkjet"), else the site decides
# (architects: plotter, dentists: receipt or laser, law: multifunction, vets: inkjet, realty: laser or dot matrix,
# the trailers: dot matrix); the either-or sites roll once per client and day from the printer stream
func _printer_model(game := "printer") -> String:
    var forced := game.get_slice(":", 1) if game.contains(":") else ""
    if PrinterGame.MODELS.has(forced):
        return forced
    var either := ""
    match site_type(client):
        "arch":
            return "plotter"
        "law":
            return "mfp"
        "vet":
            return "inkjet"
        "trailer":
            return "dot"
        "dental":
            either = "receipt"
        "realty":
            either = "dot"
        _:
            return "laser"
    var r := Difficulty.rng_for("printer.model", client * 100 + Campaign.day)
    return either if r.randi() % 2 == 0 else "laser"


func _printer_practice() -> void:
    var options := [{"label": "OPEN IT UP AND FIGHT IT", "id": "go"}]
    if active:
        options.append({"label": str(TEXT.audit_button), "id": "look"})
    options.append({"label": "LEAVE IT ALONE", "id": "no"})
    Cards.ask("Printer", str(TEXT.printer_practice), options, func(pick: String) -> void: _practice_answer(pick))


func _practice_answer(pick: String) -> void:
    if pick == "look":
        inspect("printer")
    elif pick == "go":
        PrinterGame.start(
            func(stars: int) -> void:
                if stars >= 0:  # -1 = backed out on the intro page
                    Hints.toast(str(TEXT.printer_practice_done) % stars, 3.0),
            _printer_model(),
            {"practice": true}
        )


func _after(ok: bool) -> void:
    if ok:
        _finish_job()
        return
    if not _event_done:
        _maybe_event()


# a mishap only happens where its text makes sense: the dog and the showing need a PC job,
# the breaker and the closet call need the closet, the plotter needs the printer
func event_fits(ev: Dictionary) -> bool:
    var groups := {
        "pc": ["pc", "exam", "vip", "xray"],
        "cabinet": ["cabinet", "server"],
        "server": ["cabinet", "server"],
        "printer": ["printer"],
    }
    var want := str(ev.get("object", ""))
    if want == "" or job.is_empty() or not groups.has(want):
        return true
    return (groups[want] as Array).has(str(job.get("object", "")))


# a random mishap at this kind of site (once per visit, 55%)
func _maybe_event() -> void:
    _event_done = true
    var ev: Dictionary = EVENTS.get(site_type(client), {})
    if ev.is_empty() or not event_fits(ev) or randf() > 0.55:
        return
    var options := []
    for o in ev.options:
        options.append({"label": str(o.label), "id": str(o.id)})
    Cards.ask("Onsite: " + str(Msp.CLIENTS[client].name), str(ev.text), options, func(id: String) -> void: _event_answer(ev, id))


func _event_answer(ev: Dictionary, id: String) -> void:
    var text := ""
    for o in ev.options:
        if str(o.id) == id:
            _away(float(o.hours), ticket_id)
            Sales.adjust(client, int(o.mood))
            text = str(o.text)
    Cards.ask("Onsite", text, [{"label": "OK", "id": "ok"}], func(_id: String) -> void: pass)


func _finish_job() -> void:
    var t := Msp.ticket(ticket_id)
    if t.is_empty():
        return
    t.fix_done = true
    for ep in Msp.endpoints:
        if ep.name == t.endpoint:
            ep.problem = ""
    Msp.add_note(ticket_id, "Fixed onsite.")
    fixed_count += 1
    Msp.close_ticket(ticket_id)
    if not _event_done:
        _maybe_event()
    Hints.toast(str(TEXT.fixed), 3.0)


func _leave() -> void:
    if not active:
        return
    if not done and not job.is_empty():
        Cards.ask("Onsite", str(TEXT.leave_ask), [
            {"label": str(TEXT.stay), "id": "leave"},
            {"label": str(TEXT.leave), "id": "go"},
        ], func(id: String) -> void: _leave_answer(id, true))
        return
    if visit_kind != "" and not _met:
        Cards.ask("Onsite", str(TEXT.leave_unmet), [
            {"label": "STAY AND MEET THE OWNER", "id": "leave"},
            {"label": "LEAVE WITHOUT MEETING THEM", "id": "go"},
        ], func(id: String) -> void: _leave_answer(id, false))
        return
    _go_home(false)


func _leave_answer(id: String, dropped: bool) -> void:
    if id == "go":
        _go_home(dropped)


func _go_home(dropped: bool) -> void:
    if dropped:
        Sales.adjust(client, -6)
        Msp.add_note(ticket_id, "Technician left before the problem was fixed.")
        Hints.toast(str(TEXT.dropped), 3.0)
    _back_min = _trip_minutes(client)
    _away(float(_back_min) / 60.0)
    active = false
    busy = false
    visit_kind = ""
    visit_prospect = false
    Msp.enabled = _prev_msp
    World.time_scale = _prev_scale
    Game.go("main_floor", "from_outside")
    if Campaign.active:
        Hints.toast(str(TEXT.home) % _back_min, 4.0)
    else:  # free play has no queue to grow
        Hints.toast("You drive back to the office (%d minutes)." % _back_min, 4.0)


# the drive card: free play has no queue, so it does not mention one
func _visit_text(c: int) -> String:
    var name := str(Msp.CLIENTS[c].name)
    if not Campaign.active:
        return "Drive to %s? About %d minutes each way." % [name, estimate_minutes(c)]
    return str(TEXT.visit_confirm) % [name, estimate_minutes(c)]


# one staff member stands around at every client site (E: a line about the place)
func populate(stage: Node) -> void:
    var scene := stage.scene_file_path.get_file().get_basename()
    if not scene.begins_with("site_") or Game.title_mode:
        return
    var parts := scene.split("_")
    var kind := parts[1]
    var skin := parts[parts.size() - 1]
    var room := "main" if parts.size() == 3 else parts[2]
    var people: Array = CAST_AT.get(kind, {}).get(skin, {}).get(room, [])
    var x0 := float(World.DATA.SCENES[scene].x0)
    for entry in people:
        var npc: Node = NPC_SCENE.instantiate()
        npc.character = str(entry[0])
        npc.facing = "left" if int(entry[1]) > 120 else "right"
        npc.role = "site:" + str(entry[2])
        npc.routine = PackedStringArray(["wait:7", "say:2"] if str(entry[2]) == "staff" else ["wait:7", "talk:3"])
        npc.position = Vector2(x0 + float(entry[1]), 118.0)
        var zone := RectangleShape2D.new()  # a narrower talk zone than the cast has, so doors and equipment next to them stay easy to hit
        zone.size = Vector2(30, 56)
        npc.get_node("Shape").shape = zone
        stage.get_node("Actors").add_child(npc)
''')

write("scripts/printer_game.gd", '''extends CanvasLayer
# gdlint:disable=max-line-length,max-returns,class-definitions-order
# The printer mini-game (onsite, the bane of every MSP's existence): open the printer and fight it in rounds.
# Which rounds depend on the MODEL (see MODELS): a laser has them all, the others drop or rename some.
#   JAM:   pull the stuck paper out. SPACE stops a moving marker: green = a clean pull, yellow = it holds (try again),
#          red = it tears and leaves a scrap (a mistake, and one more pull). The chain is 3 pulls (more on HARD, up to 6);
#          two clean pulls in a row shorten it again (never below 3).
#   TRAY:  the display says what is wrong with the paper (PC LOAD LETTER on a laser). Load the right paper or roll.
#   TONER: install the cartridges (ink tanks, a ribbon) in the order the printer asks (left / right, SPACE).
#   SHAKE: shake the cartridge (A and D).
#   TEST:  error messages on the little display; pick the right way to deal with each (1 / 2 / 3).
#          How many comes from Difficulty ("printer.questions": 1 / 2 / 3), drawn from QUESTIONS tagged for the model and tier.
# P prays to the sysadmin gods (3 prayers; each model has its own): good luck blesses you (the next mistake is forgiven,
# the green zone widens), bad luck costs you. Pray-free wins keep a streak. Fewer mistakes = more stars (0-3). Esc gives up.
# Used by Onsite (printer jobs, and practice in Free Play where the intro page lets you pick the model and a seed):
#   PrinterGame.start(func(stars: int) -> void: ..., "plotter", {"onsite": true})  # model and options are optional
# options: onsite (the marker runs up to 15% faster when you are tired, see Shift.slow_mult), practice, seed (practice).
# The questions and texts are in QUESTIONS / TEXT / MODEL_TEXT so reviewers can edit them in story/strings.txt.

const PixelFont := preload("res://scripts/pixelfont.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const PW := 176.0
const PH := 112.0
const INK := Color("17121f")
const BODY := Color("dfe3ea")
const PAPER := Color("f4f2ea")
const COLORS := [Color("2fa7d8"), Color("d8409a"), Color("f2d23c"), Color("2a2a33")]
const COLOR_NAMES := ["CYAN", "MAGENTA", "YELLOW", "BLACK"]
const RIBBON_COLORS := [Color("2a2a33"), Color("b3302f")]
const RIBBON_NAMES := ["BLACK", "RED"]
const TRAY := ["LETTER", "LEGAL", "A4", "HIT IT"]
const PLOTTER_TRAY := ["24 BOND", "36 BOND", "MYLAR", "HIT IT"]
const RECEIPT_TRAY := ["80 MM", "58 MM", "PLAIN", "HIT IT"]
const DOT_TRAY := ["TRACTOR", "SINGLE", "LABELS", "HIT IT"]
# the printer models. phases = the rounds in order (test is always last); tray / names / colors = what the tray and the
# cartridge round offer (the right tray is always the first, the last one is the joke); look = how it is drawn.
const MODELS := {
    "laser":
    {
        "label": "LASER",
        "phases": ["jam", "tray", "toner", "shake", "test"],
        "tray": TRAY,
        "names": COLOR_NAMES,
        "colors": COLORS,
        "look": "laser",
    },
    "inkjet":
    {
        "label": "INKJET",
        "phases": ["jam", "toner", "test"],
        "tray": TRAY,
        "names": COLOR_NAMES,
        "colors": COLORS,
        "look": "inkjet",
    },
    "plotter":
    {
        "label": "PLOTTER",
        "phases": ["jam", "tray", "toner", "shake", "test"],
        "tray": PLOTTER_TRAY,
        "names": COLOR_NAMES,
        "colors": COLORS,
        "look": "plotter",
    },
    "mfp":
    {
        "label": "MULTIFUNCTION",
        "phases": ["jam", "tray", "toner", "test"],
        "tray": TRAY,
        "names": COLOR_NAMES,
        "colors": COLORS,
        "look": "mfp",
    },
    "receipt":
    {
        "label": "RECEIPT",
        "phases": ["jam", "tray", "test"],
        "tray": RECEIPT_TRAY,
        "names": [],
        "colors": [],
        "look": "receipt",
    },
    "dot":
    {
        "label": "DOT MATRIX",
        "phases": ["jam", "tray", "toner", "test"],
        "tray": DOT_TRAY,
        "names": RIBBON_NAMES,
        "colors": RIBBON_COLORS,
        "look": "dot",
    },
}
const MODEL_ORDER := ["laser", "inkjet", "plotter", "mfp", "receipt", "dot"]
const TEXT := {
    "title": "PRINTER REPAIR",
    "intro1": "THE COPIER GRINDS AND THE DISPLAY SAYS",
    "intro2": "PAPER JAM 13.20.00. THEY ALWAYS SAY THAT.",
    "intro3": "SPACE = START  ESC = SKIP",
    "jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN",
    "jam_clean": "A CLEAN PULL. THE SHEET COMES OUT WHOLE.",
    "jam_hold": "IT HOLDS. NOT QUITE: TRY AGAIN.",
    "jam_tear": "RIP! A SCRAP IS STILL INSIDE.",
    "jam_short": "TWO CLEAN PULLS: THE JAM EASES, ONE FEWER TO GO.",
    "jam_scrap": "THE SCRAP NEEDS ONE MORE PULL.",
    "toner_help": "LEFT / RIGHT TO PICK, SPACE TO INSTALL",
    "toner_ok": "CLICK. IT SEATS.",
    "toner_bad": "WRONG CARTRIDGE. THE PRINTER BEEPS.",
    "shake_help": "SHAKE THE CARTRIDGE: A D A D A D",
    "shake_late": "TOO SLOW. TONER DUST EVERYWHERE.",
    "test_help": "PICK 1, 2 OR 3",
    "right": "RIGHT.",
    "wrong": "NOPE.",
    "hit": "YOU HIT THE PRINTER. IT WORKS. DO NOT TELL ANYONE.",
    "stars3": "PERFECT. A FLAWLESS TEST PAGE.",
    "stars2": "GOOD ENOUGH. A FEW STREAKS.",
    "stars1": "IT PRINTS. MOSTLY.",
    "stars0": "YOU GIVE UP. THE PRINTER WINS.",
    "done": "SPACE = CONTINUE",
    "tray_help": "PC LOAD LETTER. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
    "tray_ok": "LETTER PAPER IN TRAY 2. PC LOAD LETTER IS SOLVED. YOU ARE A HERO.",
    "tray_bad": "WRONG PAPER. THE PRINTER JAMS ON PRINCIPLE.",
    "tray_hit": "YOU HIT THE PRINTER AND IT WORKS. DO NOT TELL ANYONE.",
    "tray_screen": "PC LOAD LETTER",
    "tray_slot": "TRAY 2",
    "pray_help": "P: PRAY TO THE SYSADMIN GODS",
    "pray_none": "THE GODS HAVE HEARD ENOUGH FROM YOU TODAY.",
    "blessed_tag": "BLESSED",
    "tired_tag": "TIRED",
    "tired_note": "TIRED: THE MARKER RUNS %d PERCENT FASTER.",
    "practice_help": "LEFT / RIGHT = MODEL  UP / DOWN = SEED",
    "streak": "NO-PRAYER STREAK: %d",
}
# the per-model overlays on TEXT: only the keys that differ
const MODEL_TEXT := {
    "plotter":
    {
        "title": "PLOTTER REPAIR",
        "intro1": "THE FORTY-INCH PLOTTER CHEWS ITS ROLL",
        "intro2": "AND SAYS MEDIA JAM. A PRINT DUE AT NOON.",
        "jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: EASE THE ROLL OUT",
        "jam_clean": "A CLEAN PULL. THE ROLL COMES OUT WHOLE AND FLAT.",
        "jam_hold": "THE ROLL HOLDS. NOT QUITE: TRY AGAIN.",
        "jam_tear": "RIP! A STRIP OF BOND IS STILL WRAPPED INSIDE.",
        "toner_help": "LEFT / RIGHT TO PICK AN INK TANK, SPACE TO INSTALL",
        "toner_ok": "CLICK. THE INK TANK SEATS.",
        "toner_bad": "WRONG INK TANK. THE PLOTTER BEEPS AT YOU.",
        "shake_help": "ROCK THE INK TANK: A D A D A D",
        "shake_late": "TOO SLOW. INK ON THE FLOOR AND ON THE BLUEPRINTS.",
        "hit": "YOU SLAP THE PLOTTER. IT WORKS. DO NOT TELL THE ARCHITECTS.",
        "stars3": "PERFECT. A CRISP FORTY-INCH SITE PLAN.",
        "stars2": "GOOD ENOUGH. A FEW BANDING LINES.",
        "stars1": "IT PLOTS. THE SCALE BAR IS A LITTLE OFF.",
        "stars0": "YOU GIVE UP. THE PLOTTER WINS.",
        "tray_help": "MEDIA MISMATCH. LOAD THE RIGHT ROLL. LEFT / RIGHT, SPACE",
        "tray_ok": "24 INCH BOND ROLL LOADED. THE JOB NUMBER 14-0312 PRINTS.",
        "tray_bad": "WRONG ROLL. THE PLOTTER CUTS IT SHORT.",
        "tray_hit": "YOU HIT THE PLOTTER AND IT WORKS. DO NOT TELL ANYONE.",
        "tray_screen": "MEDIA MISMATCH",
        "tray_slot": "ROLL 1",
        "pray_help": "P: PRAY TO THE PLOTTER GODS",
    },
    "inkjet":
    {
        "title": "INKJET REPAIR",
        "intro1": "THE INKJET PRINTS A PAGE OF WHITE LINES",
        "intro2": "AND A PAPER JAM LIGHT BLINKS. AGAIN.",
        "jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: FREE THE SHEET",
        "jam_clean": "A CLEAN PULL. THE SHEET COMES OUT FLAT.",
        "jam_tear": "RIP! A CORNER IS STILL UNDER THE ROLLER.",
        "toner_help": "LEFT / RIGHT TO PICK AN INK TANK, SPACE TO FIT",
        "toner_ok": "CLICK. THE INK TANK SEATS.",
        "toner_bad": "WRONG SLOT. THE INKJET BEEPS.",
        "hit": "YOU TAP THE INKJET. IT PRINTS. DO NOT TELL ANYONE.",
        "stars3": "PERFECT. THE ALIGNMENT PAGE IS CRISP.",
        "stars2": "GOOD ENOUGH. A LITTLE BANDING.",
        "stars1": "IT PRINTS. THE BLACK IS A BIT GREEN.",
        "stars0": "YOU GIVE UP. THE INKJET WINS.",
        "pray_help": "P: PRAY TO THE INK GODS",
    },
    "mfp":
    {
        "title": "COPIER REPAIR",
        "intro1": "THE COPIER SCANS AND FAXES, THEN JAMS.",
        "intro2": "ADF MISFEED. PAPER EVERYWHERE.",
        "jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: PULL THE SHEET",
        "jam_clean": "A CLEAN PULL. THE SHEET LEAVES THE FEEDER WHOLE.",
        "jam_tear": "RIP! HALF A LETTER IS STUCK IN THE FEEDER.",
        "toner_help": "LEFT / RIGHT TO PICK A CARTRIDGE, SPACE TO FIT",
        "hit": "YOU THUMP THE COPIER. IT WORKS. DO NOT TELL THE PARTNERS.",
        "stars3": "PERFECT. THE FAX GOES OUT AND THE COPIES ARE CLEAN.",
        "stars1": "IT COPIES. THE FAX STILL HISSES.",
        "stars0": "YOU GIVE UP. THE COPIER WINS.",
        "tray_help": "TRAY MISMATCH. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
        "tray_ok": "LETTER PAPER IN TRAY 1. THE COPIER HUMS.",
        "tray_screen": "LOAD LETTER IN TRAY 1",
        "tray_slot": "TRAY 1",
        "pray_help": "P: PRAY TO THE COPIER GODS",
    },
    "receipt":
    {
        "title": "RECEIPT PRINTER",
        "intro1": "THE RECEIPT PRINTER BEEPS AND THE LINE",
        "intro2": "AT THE DESK GROWS. THE LIGHT IS RED.",
        "jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: FREE THE PAPER",
        "jam_clean": "A CLEAN PULL. THE PAPER FEEDS STRAIGHT.",
        "jam_tear": "RIP! A CURL OF THERMAL PAPER IS STUCK.",
        "hit": "YOU SMACK THE LID. IT CUTS A RECEIPT. DO NOT TELL ANYONE.",
        "stars3": "PERFECT. A CRISP RECEIPT AND A CLEAN CUT.",
        "stars2": "GOOD ENOUGH. THE CUT IS A LITTLE CROOKED.",
        "stars1": "IT PRINTS. THE TOTAL IS FAINT.",
        "stars0": "YOU GIVE UP. THE LINE GROWS.",
        "tray_help": "PAPER OUT LIGHT. LOAD THE RIGHT ROLL. LEFT / RIGHT, SPACE",
        "tray_ok": "THE 80 MM ROLL IS IN, HEAT SIDE UP. IT CUTS CLEANLY.",
        "tray_bad": "WRONG ROLL. THE LID WILL NOT CLOSE.",
        "tray_hit": "YOU HIT THE LID AND IT CLOSES. DO NOT TELL ANYONE.",
        "tray_screen": "PAPER OUT",
        "tray_slot": "ROLL BAY",
        "pray_help": "P: PRAY TO THE REGISTER GODS",
    },
    "dot":
    {
        "title": "DOT MATRIX REPAIR",
        "intro1": "THE OLD DOT MATRIX SCREECHES THROUGH ITS",
        "intro2": "FORMS AND THE TRACTOR FEED IS CROOKED.",
        "jam_help": "SPACE WHEN THE MARKER IS IN THE GREEN: FREE THE FORM",
        "jam_clean": "A CLEAN PULL. THE FORM COMES OUT WHOLE.",
        "jam_tear": "RIP! A STRIP OF PINFEED HOLES IS STILL INSIDE.",
        "toner_help": "LEFT / RIGHT TO PICK THE RIBBON, SPACE TO FIT",
        "toner_ok": "CLICK. THE RIBBON SEATS.",
        "toner_bad": "WRONG RIBBON. THE HEAD GRINDS.",
        "hit": "YOU THUMP THE CASE. IT SCREECHES AND WORKS.",
        "stars3": "PERFECT. THE CARBON COPY IS READABLE.",
        "stars2": "GOOD ENOUGH. A FEW PALE LINES.",
        "stars1": "IT PRINTS. THE THIRD COPY IS A GHOST.",
        "stars0": "YOU GIVE UP. THE DOT MATRIX WINS.",
        "tray_help": "FORMS OUT OF LINE. LOAD THE RIGHT PAPER. LEFT / RIGHT, SPACE",
        "tray_ok": "THE FORMS RIDE THE TRACTOR PINS, SQUARE AT LAST.",
        "tray_bad": "WRONG PAPER. THE PINS TEAR THE EDGE.",
        "tray_screen": "FORM FEED ERROR",
        "tray_slot": "TRACTOR",
        "pray_help": "P: PRAY TO THE FORMS GODS",
    },
}
# prayers: the laser (and anything without its own list) uses PRAYERS; the others have a faith of their own
const PRAYERS := {
    "good":
    [
        "THE SYSADMIN GODS SMILE. YOUR NEXT MISTAKE IS FORGIVEN.",
        "A WARM HUM FROM A DISTANT SERVER ROOM. YOU ARE BLESSED.",
        "A DOMAIN CONTROLLER REPLICATES IN YOUR HONOR. YOU ARE BLESSED.",
    ],
    "meh":
    [
        "THE GODS ARE BUSY RESTARTING A DOMAIN CONTROLLER.",
        "SILENCE. SOMEWHERE, A BACKUP FAILS.",
        "THE GODS PUT YOU ON HOLD. THE MUSIC IS BAD.",
    ],
    "bad":
    [
        "THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.",
        "A SURGE ON THE POWER LINE. THE GODS ARE DISPLEASED.",
    ],
}
const MODEL_PRAYERS := {
    "inkjet":
    {
        "good": ["A DROP OF CYAN FALLS WHERE IT SHOULD. YOU ARE BLESSED.", "THE NOZZLES CLEAR ALL BY THEMSELVES. YOU ARE BLESSED."],
        "meh": ["THE GODS OF INK ARE BUSY. THE CARTRIDGE IS EMPTY.", "A FAINT SMELL OF ISOPROPYL. NOTHING ELSE."],
        "bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE CHIP LIES ABOUT THE INK LEVEL. THE MARKER SPEEDS UP."],
    },
    "plotter":
    {
        "good": ["THE ROLL FEEDS STRAIGHT FOR ONCE. YOU ARE BLESSED.", "A SCALE BAR COMES OUT RIGHT. THE PLOTTER GODS NOD. YOU ARE BLESSED."],
        "meh": ["THE GODS ARE AT A SITE MEETING. NO REPLY.", "SOMEONE REVISES THE DRAWING. THE GODS SIGH."],
        "bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE PRINTHEAD CRASHES ACROSS THE PAGE. THE MARKER SPEEDS UP."],
    },
    "mfp":
    {
        "good": ["THE FAX HANDSHAKE SOUNDS RIGHT. YOU ARE BLESSED.", "THE FEEDER PICKS ONE SHEET AT A TIME. YOU ARE BLESSED."],
        "meh": ["THE GODS ARE ON THE OTHER LINE.", "A BUSY SIGNAL FROM ABOVE."],
        "bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "A FAX ARRIVES FOR THE WRONG OFFICE. THE MARKER SPEEDS UP."],
    },
    "receipt": {
        "good": ["THE CUTTER SNAPS CLEAN. YOU ARE BLESSED.", "THE DRAWER POPS OPEN ON ITS OWN. YOU ARE BLESSED."],
        "meh": ["THE GODS WANT A SIGNATURE ON THE SCREEN. NOTHING ELSE.", "THE GODS SAY THE TOTAL IS CORRECT. THAT IS ALL."],
        "bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE LINE AT THE DESK GROANS. THE MARKER SPEEDS UP."],
    },
    "dot":
    {
        "good": ["THE PINS FIND THEIR HOLES. YOU ARE BLESSED.", "A SOFT SCREECH OF APPROVAL FROM THE HEAD. YOU ARE BLESSED."],
        "meh": ["THE GODS ARE BUSY RE-INKING A RIBBON.", "A CARBON COPY OF SILENCE."],
        "bad": ["THE GODS DEMAND A SACRIFICE. A MISTAKE IS ADDED.", "THE HEAD SCREAMS AND THE CARRIAGE STUTTERS. THE MARKER SPEEDS UP."],
    },
}
# the test-page questions. models = which printers show it (empty = all), hard = lowest tier it appears on
# (0 easy, 1 normal, 2 hard; harder questions are only used on an easier tier when a model has too few).
# Keep error and options to 36 characters, the display is small.
const QUESTIONS := [
    {
        "error": "TONER LOW",
        "options": ["IGNORE IT", "REPLACE THE CARTRIDGE", "SHAKE IT AND KEEP PRINTING"],
        "correct": 1,
        "hit": -1,
        "why": "SHAKING BUYS ABOUT TWENTY PAGES. THEN THE STREAKS COME BACK.",
        "models": ["laser", "mfp"],
        "hard": 0,
    },
    {
        "error": "ERROR 79 SERVICE",
        "options": ["REINSTALL THE DRIVER", "POWER CYCLE AND RESEAT THE FORMATTER", "CALL THE VENDOR"],
        "correct": 1,
        "hit": -1,
        "why": "A 79 IS USUALLY THE FORMATTER OR A BAD PRINT JOB. UNPLUG, WAIT, RESEAT, TRY AGAIN.",
        "models": ["laser", "mfp"],
        "hard": 1,
    },
    {
        "error": "PRINTER OFFLINE",
        "options": ["SET IT BACK ONLINE", "BUY A NEW PRINTER", "REINSTALL WINDOWS"],
        "correct": 0,
        "hit": -1,
        "why": "SOMEONE PRESSED THE OFFLINE BUTTON. SOMEONE ALWAYS DOES.",
        "models": [],
        "hard": 0,
    },
    {
        "error": "PAPER MISMATCH TRAY 1",
        "options": ["OPEN THE FUSER", "SET TRAY 1 TO PLAIN PAPER", "BLAME THE USER"],
        "correct": 1,
        "hit": -1,
        "why": "THE TRAY SAYS LABELS BUT THE PAPER IS PLAIN. CHANGE THE TRAY SETTING.",
        "models": ["laser", "mfp", "inkjet"],
        "hard": 0,
    },
    {
        "error": "MEDIA JAM ROLL 1",
        "options": ["PULL THE ROLL OUT HARD", "OPEN THE COVER, FEED IT STRAIGHT", "ORDER A NEW ROLL"],
        "correct": 1,
        "hit": -1,
        "why": "A SKEWED LEADING EDGE JAMS THE PINCH ROLLERS. RELOAD IT STRAIGHT.",
        "models": ["plotter"],
        "hard": 0,
    },
    {
        "error": "REPLACE PRINTHEAD",
        "options": ["ALIGN THE PRINTHEAD", "SWAP THE HEAD AND ALIGN IT", "IGNORE IT"],
        "correct": 1,
        "hit": -1,
        "why": "BANDING THAT NEVER CLEARS MEANS A DEAD NOZZLE. SWAP IT, THEN ALIGN.",
        "models": ["plotter", "inkjet"],
        "hard": 1,
    },
    {
        "error": "OUT OF MEMORY",
        "options": ["ADD MEMORY OR SEND A FLAT PDF", "REINSTALL CAD", "PRINT IT AGAIN"],
        "correct": 0,
        "hit": -1,
        "why": "A BIG DRAWING WITH A HEAVY HATCH CHOKES THE PLOTTER. SEND A FLATTENED PDF.",
        "models": ["plotter"],
        "hard": 1,
    },
    {
        "error": "PAPER SIZE MISMATCH",
        "options": ["SET THE DRIVER TO ARCH D", "BLAME THE INTERN", "CUT THE ROLL BY HAND"],
        "correct": 0,
        "hit": -1,
        "why": "THE DRAWING SAYS 24 BY 36 BUT THE DRIVER SAYS LETTER. FIX THE PAPER SIZE.",
        "models": ["plotter"],
        "hard": 0,
    },
    {
        "error": "STREAKS AFTER A NEW INK TANK",
        "options": ["RUN THE ALIGNMENT PAGE", "BUY MORE INK", "SHAKE THE PRINTER"],
        "correct": 0,
        "hit": -1,
        "why": "A SWAPPED INK TANK OR HEAD NEEDS ALIGNING. PRINT THE ALIGNMENT PAGE AND PICK THE BEST BLOCKS.",
        "models": ["inkjet", "plotter"],
        "hard": 0,
    },
    {
        "error": "JOB STUCK: 400 MB IN QUEUE",
        "options": ["PRINT IT TEN MORE TIMES", "RESTART THE SPOOLER, CLEAR QUEUE", "UNPLUG THE PRINTER"],
        "correct": 1,
        "hit": -1,
        "why": "ONE HUGE SCAN BLOCKS THE QUEUE. STOP THE SPOOLER, EMPTY THE SPOOL FOLDER, START IT AGAIN.",
        "models": [],
        "hard": 1,
    },
    {
        "error": "CANNOT CONNECT TO SHARED PRINTER",
        "options": ["WAKE THE XP PC THAT SHARES IT", "REINSTALL EVERY PC", "BUY A NETWORK PRINTER"],
        "correct": 0,
        "hit": -1,
        "why": "THE USB PRINTER IS SHARED FROM AN OLD XP PC AND THAT PC WENT TO SLEEP. KEEP IT AWAKE.",
        "models": ["inkjet", "laser", "dot", "receipt"],
        "hard": 1,
    },
    {
        "error": "PRINTER NOT FOUND",
        "options": ["RESERVE ITS ADDRESS ON THE ROUTER", "REBUILD EVERY PC", "PRINT TO A FILE"],
        "correct": 0,
        "hit": -1,
        "why": "THE DHCP LEASE RAN OUT AND THE PRINTER GOT A NEW IP. RESERVE ONE OR SET A STATIC ADDRESS.",
        "models": ["laser", "mfp", "plotter"],
        "hard": 1,
    },
    {
        "error": "PRINTS COME OUT AT THE OTHER OFFICE",
        "options": ["SET THE RIGHT DEFAULT PRINTER", "REBUILD THE LAPTOP", "UNPLUG THE OTHER PRINTER"],
        "correct": 0,
        "hit": -1,
        "why": "THE LAPTOP KEPT THE DEFAULT PRINTER FROM THE OTHER OFFICE. PICK THE LOCAL ONE.",
        "models": [],
        "hard": 0,
    },
    {
        "error": "20 INSUFFICIENT MEMORY",
        "options": ["LOWER THE DPI OR ADD A DIMM", "POWER CYCLE UNTIL IT WORKS", "SEND THE JOB TWICE"],
        "correct": 0,
        "hit": -1,
        "why": "THIS LASER HAS 2 MB. A FULL PAGE AT HIGH DPI WILL NOT FIT. LOWER THE RESOLUTION OR ADD MEMORY.",
        "models": ["laser"],
        "hard": 1,
    },
    {
        "error": "CLOSE DUPLEX UNIT",
        "options": ["PUSH THE DUPLEX UNIT UNTIL IT CLICKS", "REPLACE THE FUSER", "UPDATE THE FIRMWARE"],
        "correct": 0,
        "hit": -1,
        "why": "THE DUPLEXER IS NOT SEATED, SO THE SENSOR SAYS OPEN. PUSH IT IN UNTIL IT CLICKS.",
        "models": ["laser", "mfp"],
        "hard": 0,
    },
    {
        "error": "PICKS TWO SHEETS, THEN NONE",
        "options": ["OIL THE ROLLERS", "CLEAN OR SWAP THE FEED ROLLERS", "FAN THE PAPER FOREVER"],
        "correct": 1,
        "hit": -1,
        "why": "GLAZED FEED ROLLERS LOSE THEIR GRIP. WIPE THEM WITH A DAMP CLOTH OR REPLACE THEM.",
        "models": ["laser", "mfp", "inkjet"],
        "hard": 1,
    },
    {
        "error": "PRINTER DEAD, NO LIGHTS AT ALL",
        "options": ["CHECK THE POWER CORD", "REPLACE THE POWER SUPPLY", "REIMAGE THE PC"],
        "correct": 0,
        "hit": -1,
        "why": "IT IS UNPLUGGED. THE CLEANER NEEDED THE SOCKET. PLUG IT IN AND TELL NOBODY.",
        "models": [],
        "hard": 0,
    },
    {
        "error": "WHITE LINES ACROSS THE PAGE",
        "options": ["RUN A HEAD CLEAN AND NOZZLE CHECK", "BUY A NEW PRINTER", "BLAME THE PAPER"],
        "correct": 0,
        "hit": -1,
        "why": "A CLOGGED NOZZLE LEAVES GAPS. RUN THE HEAD CLEANING CYCLE AND PRINT A NOZZLE CHECK.",
        "models": ["inkjet"],
        "hard": 0,
    },
    {
        "error": "CARTRIDGE NOT RECOGNIZED",
        "options": ["RESEAT IT, WIPE THE CHIP CONTACTS", "TURN OFF THE FIREWALL", "RESET THE PC"],
        "correct": 0,
        "hit": -1,
        "why": "THE CHIP CONTACTS ARE DIRTY OR THE CARTRIDGE IS NOT SEATED. CLEAN AND RESEAT IT.",
        "models": ["inkjet"],
        "hard": 1,
    },
    {
        "error": "VERTICAL LINES ON EVERY SCAN",
        "options": ["REINSTALL THE SCAN DRIVER", "CLEAN THE SCANNER GLASS", "REPLACE THE TONER"],
        "correct": 1,
        "hit": -1,
        "why": "A SPECK ON THE GLASS OR THE ADF STRIP DRAWS A LINE ON EVERY PAGE. WIPE BOTH.",
        "models": ["mfp"],
        "hard": 0,
    },
    {
        "error": "ADF PICK FAILED",
        "options": ["OPEN THE ADF, REMOVE THE STAPLE", "BUY A FLATBED", "SCAN WITH A PHONE"],
        "correct": 0,
        "hit": -1,
        "why": "A STAPLE OR A CURLED CORNER BLOCKS THE FEEDER. OPEN THE COVER AND CLEAR THE PATH.",
        "models": ["mfp"],
        "hard": 0,
    },
    {
        "error": "FAX: NO DIAL TONE",
        "options": ["REPLACE THE FAX BOARD", "MOVE THE CORD TO THE LINE JACK", "RESET THE ROUTER"],
        "correct": 1,
        "hit": -1,
        "why": "THE PHONE CORD IS IN THE EXT JACK, NOT THE LINE JACK. SWAP IT OVER.",
        "models": ["mfp"],
        "hard": 1,
    },
    {
        "error": "SCAN TO EMAIL FAILED",
        "options": ["CHECK THE MAIL SERVER AND PORT", "REPLACE THE SCANNER LAMP", "SCAN TO FOLDER FOREVER"],
        "correct": 0,
        "hit": -1,
        "why": "THE SMTP SERVER OR PORT IN THE SCANNER SETTINGS IS WRONG, OR THE RELAY NEEDS A LOGIN.",
        "models": ["mfp"],
        "hard": 2,
    },
    {
        "error": "PAPER OUT, BUT THERE IS PAPER",
        "options": ["FLIP THE ROLL, HEAT SIDE IN", "BUY A NEW ROLL", "HIT THE LID"],
        "correct": 0,
        "hit": 2,
        "why": "THERMAL PAPER HAS ONE HEATED SIDE. LOADED BACKWARDS IT PRINTS NOTHING. TURN THE ROLL OVER.",
        "models": ["receipt"],
        "hard": 0,
    },
    {
        "error": "RECEIPTS PRINT VERY FAINT",
        "options": ["CLEAN THE THERMAL HEAD", "ADD TONER", "REPLACE THE DRAWER"],
        "correct": 0,
        "hit": -1,
        "why": "PAPER DUST BUILDS UP ON THE THERMAL HEAD. WIPE IT WITH ALCOHOL AND LET IT DRY.",
        "models": ["receipt"],
        "hard": 0,
    },
    {
        "error": "CUTTER ERROR",
        "options": ["OPEN THE COVER, CLEAR THE SCRAP", "FORCE THE PAPER OUT", "RESTART THE REGISTER"],
        "correct": 0,
        "hit": -1,
        "why": "A SCRAP OF PAPER IS STUCK IN THE CUTTER BLADE. OPEN THE COVER, REMOVE IT, RESEAT THE BLADE.",
        "models": ["receipt"],
        "hard": 1,
    },
    {
        "error": "RECEIPT SHOWS GARBAGE LETTERS",
        "options": ["MATCH THE BAUD RATE TO THE REGISTER", "REPLACE THE ROLL", "UNPLUG THE DRAWER"],
        "correct": 0,
        "hit": -1,
        "why": "THE SERIAL SETTINGS DO NOT MATCH THE REGISTER. SET THE SAME BAUD RATE ON BOTH.",
        "models": ["receipt"],
        "hard": 2,
    },
    {
        "error": "PRINT IS PALE AND GHOSTLY",
        "options": ["REPLACE THE RIBBON", "ADD TONER", "SWITCH TO INKJET"],
        "correct": 0,
        "hit": -1,
        "why": "A WORN RIBBON LEAVES FAINT DOTS. FIT A NEW ONE AND THE CARBON COPIES WILL BE READABLE.",
        "models": ["dot"],
        "hard": 0,
    },
    {
        "error": "FORMS DRIFT DOWN THE PAGE",
        "options": ["SET TOP OF FORM, SEAT THE PINS", "REPLACE THE PRINT HEAD", "PRINT SMALLER"],
        "correct": 0,
        "hit": -1,
        "why": "THE FORM IS NOT ON THE TRACTOR PINS, OR THE TOP-OF-FORM IS WRONG. SQUARE IT UP AND SET IT.",
        "models": ["dot"],
        "hard": 1,
    },
    {
        "error": "COPY THREE IS BLANK",
        "options": ["MOVE THE HEAD GAP LEVER OUT", "ADD A RIBBON", "PRINT THREE TIMES"],
        "correct": 0,
        "hit": -1,
        "why": "A MULTI-PART FORM IS THICKER. THE HEAD GAP LEVER MUST BE SET WIDER SO THE LAST COPY GETS INKED.",
        "models": ["dot"],
        "hard": 2,
    },
    {
        "error": "NOTHING PRINTS FROM WINDOWS 7",
        "options": ["PICK THE USB TO PARALLEL PORT", "INSTALL XP", "HIT IT"],
        "correct": 0,
        "hit": 2,
        "why": "THE NEW PC HAS NO PARALLEL PORT. THE PRINTER NEEDS THE PORT OF ITS USB ADAPTER CABLE.",
        "models": ["dot"],
        "hard": 2,
    },
    {
        "error": "DRAWING PRINTS AT HALF SIZE",
        "options": ["SET THE SCALE TO 100 PERCENT", "ORDER A BIGGER ROLL", "REDRAW IT"],
        "correct": 0,
        "hit": -1,
        "why": "THE DRIVER IS ON FIT TO PAGE. SET THE SCALE TO 100 PERCENT AND CHOOSE THE RIGHT SHEET SIZE.",
        "models": ["plotter"],
        "hard": 0,
    },
    {
        "error": "50.2 FUSER ERROR",
        "options": ["LET IT COOL, POWER CYCLE", "REPLACE THE FUSER AT ONCE", "OPEN THE FUSER HOT"],
        "correct": 0,
        "hit": -1,
        "why": "A ONE-OFF FUSER ERROR OFTEN CLEARS AFTER COOLING. IF IT COMES BACK, REPLACE THE FUSER. NEVER OPEN IT HOT.",
        "models": ["laser", "mfp"],
        "hard": 2,
    },
    {
        "error": "BLACK STREAK DOWN EVERY PAGE",
        "options": ["CLEAN OR REPLACE THE DRUM", "ADD PAPER", "RESTART THE SPOOLER"],
        "correct": 0,
        "hit": -1,
        "why": "A SCRATCHED OR DIRTY DRUM PRINTS THE SAME LINE ON EVERY PAGE. CLEAN IT OR FIT A NEW ONE.",
        "models": ["laser", "mfp"],
        "hard": 1,
    },
]

var is_open := false
var model := "laser"
var phase := ""
var mistakes := 0
var stars := 0
var msg := ""
var marker := 0.0
var zone := 0.5
var spot := 0
var jam_len := 3  # pulls in this chain (3 to 6): clean pulls shorten it, a torn scrap adds one
var combo := 0  # clean pulls in a row
var order: Array = []
var step := 0
var sel := 0
var shakes := 0
var asked: Array = []
var qi := 0
var faith := 3
var blessed := 0
var tray_sel := 0
var fast := false
var prayed := false
var tired := 1.0  # marker speed x: 1.0 to 1.15 on an onsite job when Shift says you are tired
var practice := false
var practice_seed := 1
var streak := 0  # pray-free wins in a row (saved with the campaign)

var _canvas: Node2D
var _callback := Callable()
var _prng: RandomNumberGenerator = null  # only in practice: the seed on the intro page rules
var _t := 0.0
var _dir := 1.0
var _shake_t := 0.0
var _last_shake := ""
var _answered := false
var _result_t := 0.0


func _ready() -> void:
    layer = 62
    _canvas = Node2D.new()
    _canvas.visible = false
    add_child(_canvas)
    _canvas.draw.connect(_paint)


func start(callback: Callable, flavour: String = "laser", opts: Dictionary = {}) -> void:
    _callback = callback
    model = flavour if MODELS.has(flavour) else "laser"
    practice = bool(opts.get("practice", false))
    practice_seed = clampi(int(opts.get("seed", 1)), 1, 99)
    tired = 1.0
    if bool(opts.get("onsite", false)):
        tired = 1.0 + clampf(Shift.slow_mult() - 1.0, 0.0, 0.5) * 0.3
    _prng = null
    if practice:
        _reseed()
    is_open = true
    Game.ui_open = true
    _canvas.visible = true
    phase = "intro"
    mistakes = 0
    stars = 0
    msg = ""
    spot = 0
    jam_len = 3
    combo = 0
    step = 0
    sel = 0
    qi = 0
    faith = 3
    blessed = 0
    tray_sel = 0
    fast = false
    prayed = false
    marker = 0.0
    _t = 0.0
    _answered = false
    _canvas.queue_redraw()


func _finish() -> void:
    is_open = false
    Game.ui_open = false
    _canvas.visible = false
    if _callback.is_valid():
        _callback.call(stars)


func _score() -> int:
    if mistakes <= 1:
        return 3
    if mistakes <= 3:
        return 2
    if mistakes <= 5:
        return 1
    return 0


# ---- models, texts, randomness
func _tx(key: String) -> String:
    var over: Dictionary = MODEL_TEXT.get(model, {})
    if over.has(key):
        return str(over[key])
    return str(TEXT.get(key, ""))


func _qs() -> Array:
    return QUESTIONS


func _m() -> Dictionary:
    return MODELS[model]


func _phases() -> Array:
    return _m().phases


func _tray() -> Array:
    return _m().tray


func _names() -> Array:
    return _m().names


func _colors() -> Array:
    return _m().colors


func _rng() -> RandomNumberGenerator:
    return _prng if _prng != null else Difficulty.rng("printer")


func _reseed() -> void:
    _prng = RandomNumberGenerator.new()
    _prng.seed = hash("%d:%s" % [practice_seed, model])


func _shuffle(list: Array) -> void:
    var r := _rng()
    for k in range(list.size() - 1, 0, -1):
        var j := r.randi_range(0, k)
        var tmp = list[k]
        list[k] = list[j]
        list[j] = tmp


# the question indices that can come up on a model (no tier filter)
func pool_for(for_model: String) -> Array:
    var out := []
    for k in QUESTIONS.size():
        var tags: Array = QUESTIONS[k].get("models", [])
        if tags.is_empty() or tags.has(for_model):
            out.append(k)
    return out


func _prayers() -> Dictionary:
    return MODEL_PRAYERS.get(model, PRAYERS)


# ---- phases
func _begin_jam() -> void:
    phase = "jam"
    spot = 0
    combo = 0
    jam_len = clampi(Difficulty.i("printer.chain"), 3, 6)
    _new_zone()
    msg = _tx("jam_help")


func _new_zone() -> void:
    zone = _rng().randf_range(0.22, 0.78)
    marker = 0.0
    _dir = 1.0


func _begin_tray() -> void:
    phase = "tray"
    tray_sel = 0
    msg = _tx("tray_help")


# go on to the next round of this model (the test page is always the last)
func _advance(keep_msg := false) -> void:
    var keep := msg
    var list := _phases()
    var at := list.find(phase)
    var nxt := str(list[at + 1]) if at >= 0 and at + 1 < list.size() else "test"
    match nxt:
        "jam":
            _begin_jam()
        "tray":
            _begin_tray()
        "toner":
            _begin_toner()
        "shake":
            _begin_shake()
        _:
            _begin_test()
    if keep_msg:
        msg = keep


func _mistake() -> void:
    if blessed > 0:
        blessed -= 1
        msg += " THE GODS FORGIVE IT."
    else:
        mistakes += 1


func _pray() -> void:
    if faith <= 0:
        msg = _tx("pray_none")
        return
    faith -= 1
    prayed = true
    var p := _prayers()
    var r := _rng()
    var roll := r.randf()
    if roll < 0.55:
        blessed += 1
        msg = str(p.good[r.randi_range(0, p.good.size() - 1)])
    elif roll < 0.8:
        msg = str(p.meh[r.randi_range(0, p.meh.size() - 1)])
    elif roll < 0.92:
        mistakes += 1
        msg = str(p.bad[0])
    else:
        fast = true
        msg = str(p.bad[1]) if str(p.bad[1]).contains("SPEEDS UP") else str(p.bad[1]) + " THE MARKER SPEEDS UP."


func _begin_toner() -> void:
    phase = "toner"
    order = range(_names().size())
    _shuffle(order)
    step = 0
    sel = 0
    msg = _tx("toner_help")


func _begin_shake() -> void:
    phase = "shake"
    shakes = 0
    _shake_t = 5.0
    _last_shake = ""
    msg = _tx("shake_help")


func _begin_test() -> void:
    phase = "test"
    var elig := []
    var rest := []
    var level := Difficulty.tier_index()
    for k in pool_for(model):
        if int(QUESTIONS[k].get("hard", 0)) <= level:
            elig.append(k)
        else:
            rest.append(k)
    _shuffle(elig)
    _shuffle(rest)
    var pool := elig + rest
    asked = pool.slice(0, mini(Difficulty.i("printer.questions"), pool.size()))
    qi = 0
    _answered = false
    msg = _tx("test_help")


func _end() -> void:
    stars = _score()
    phase = "result"
    _result_t = 0.0
    msg = _tx("stars%d" % stars)
    _record()


# the pray-free streak: a win without a prayer adds one, a prayer or a lost run ends it
func _record() -> void:
    if stars >= 1 and not prayed:
        streak += 1
    else:
        streak = 0
    Career.note_printer(model, stars, prayed, streak)


func to_dict() -> Dictionary:
    return {"version": 1, "streak": streak}


func from_dict(data: Dictionary) -> void:
    streak = maxi(0, int(data.get("streak", 0)))


func reset() -> void:
    streak = 0


# ---- input
func _input(event: InputEvent) -> void:
    if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
        return
    match event.keycode:
        KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E:
            press("confirm")
        KEY_LEFT:
            press("left")
        KEY_RIGHT:
            press("right")
        KEY_UP:
            press("up")
        KEY_DOWN:
            press("down")
        KEY_A:
            press("a")
        KEY_D:
            press("d")
        KEY_1, KEY_2, KEY_3:
            press(str(event.keycode - KEY_0))
        KEY_P:
            press("pray")
        KEY_ESCAPE:
            press("escape")
        _:
            return
    get_viewport().set_input_as_handled()


func press(key: String) -> void:
    if not is_open:
        return
    if key == "escape":
        if phase == "result":
            return  # the result is kept
        if phase == "intro":
            stars = -1  # backed out before starting: no time is spent
            _finish()
            return
        stars = 0
        phase = "result"
        _result_t = 0.0
        msg = _tx("stars0")
        _record()
        _canvas.queue_redraw()
        return
    if key == "pray":
        if phase in ["intro", "jam", "tray", "toner", "shake", "test"]:
            _pray()
        _canvas.queue_redraw()
        return
    match phase:
        "intro":
            if key == "confirm":
                if practice:
                    _reseed()
                _begin_jam()
            elif practice and key in ["left", "a", "right", "d"]:
                var at := MODEL_ORDER.find(model)
                var dir := -1 if key in ["left", "a"] else 1
                model = str(MODEL_ORDER[posmod(at + dir, MODEL_ORDER.size())])
                _reseed()
            elif practice and key in ["up", "down"]:
                practice_seed = clampi(practice_seed + (1 if key == "up" else -1), 1, 99)
                _reseed()
        "tray":
            if key in ["left", "a"]:
                tray_sel = posmod(tray_sel - 1, _tray().size())
            elif key in ["right", "d"]:
                tray_sel = posmod(tray_sel + 1, _tray().size())
            elif key == "confirm":
                _load_paper()
        "jam":
            if key == "confirm":
                _pull()
        "toner":
            var n := _names().size()
            if key in ["left", "a"]:
                sel = posmod(sel - 1, n)
            elif key in ["right", "d"]:
                sel = posmod(sel + 1, n)
            elif key == "confirm":
                _install()
        "shake":
            if key in ["a", "left", "d", "right"]:
                var side := "a" if key in ["a", "left"] else "d"
                if side != _last_shake:
                    _last_shake = side
                    shakes += 1
                    if shakes >= 10:
                        msg = ""
                        _advance()
        "test":
            if not _answered and key in ["1", "2", "3"]:
                _answer(int(key) - 1)
            elif _answered and key == "confirm":
                _next_question()
        "result":
            if key == "confirm" and _result_t > 0.5:
                _finish()
    _canvas.queue_redraw()


func _load_paper() -> void:
    if tray_sel == 0:
        msg = _tx("tray_ok")
        _advance(true)
    elif tray_sel == 3 and _rng().randf() < 0.05:
        msg = _tx("tray_hit")
        _advance(true)
    else:
        msg = _tx("tray_bad")
        _mistake()


func _pull() -> void:
    var d := absf(marker - zone)
    var zw := Difficulty.f("printer.zone")
    if d <= (0.07 + 0.03 * float(mini(blessed, 2))) * zw:
        spot += 1
        combo += 1
        msg = _tx("jam_clean")
        if combo >= 2 and jam_len > 3 and jam_len - spot >= 2:
            jam_len -= 1
            combo = 0
            msg += " " + _tx("jam_short")
        _new_zone()
        if spot >= jam_len:
            _advance()
    elif d <= (0.16 + 0.04 * float(mini(blessed, 2))) * zw:
        msg = _tx("jam_hold")
    else:
        msg = _tx("jam_tear")
        combo = 0
        if jam_len < 6:
            jam_len += 1
            msg += " " + _tx("jam_scrap")
        _mistake()
        _new_zone()


func _install() -> void:
    if sel == int(order[step]):
        step += 1
        msg = _tx("toner_ok")
        if step >= _names().size():
            _advance(true)
    else:
        msg = _tx("toner_bad")
        _mistake()


func _answer(choice: int) -> void:
    var q: Dictionary = _qs()[int(asked[qi])]
    _answered = true
    if choice == int(q.correct):
        msg = _tx("right") + " " + str(q.why)
    elif choice == int(q.hit) and _rng().randf() < 0.05:
        msg = _tx("hit")
    else:
        msg = _tx("wrong") + " " + str(q.why)
        _mistake()


func _next_question() -> void:
    qi += 1
    _answered = false
    if qi >= asked.size():
        _end()
    else:
        msg = _tx("test_help")


func _process(delta: float) -> void:
    if not is_open:
        return
    _t += delta
    _result_t += delta
    if phase == "jam":
        var speed := Difficulty.f("printer.speed") * tired
        marker += _dir * delta * (0.8 + 0.3 * float(mini(spot, 4))) * speed * (1.5 if fast else 1.0)
        if marker >= 1.0:
            marker = 1.0
            _dir = -1.0
        elif marker <= 0.0:
            marker = 0.0
            _dir = 1.0
    elif phase == "shake":
        _shake_t -= delta
        if _shake_t <= 0.0:
            msg = _tx("shake_late")
            _mistake()
            _advance(true)
    _canvas.queue_redraw()


# ---- drawing
var _o := Vector2.ZERO
var _pw := PW


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
    _canvas.draw_rect(Rect2(_o + Vector2(x, y), Vector2(w, h)), c)


func _txt(s: String, x: float, y: float, c: Color = INK, scale := 1) -> void:
    PixelFont.draw(_canvas, s, _o + Vector2(x, y), c, scale)


func _wrap(s: String, chars: int) -> Array:
    var lines := []
    var cur := ""
    for w in s.split(" "):
        if cur != "" and cur.length() + 1 + w.length() > chars:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip_edges()
    if cur != "":
        lines.append(cur)
    return lines


func _paint() -> void:
    var size := get_viewport().get_visible_rect().size
    _canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.7))
    var panel := UiStyle.panel_rect(size, PW, PH)
    _o = panel.position
    _pw = panel.size.x
    var note := "MISTAKES %d" % mistakes
    if phase != "result":
        note += "  PRAY %d" % faith
    UiStyle.panel(_canvas, panel, _tx("title"), note)
    if blessed > 0 and phase != "result":
        _txt(str(TEXT.blessed_tag), PW - 32.0, 10, Color("1f7a3a"))
    match phase:
        "intro":
            _paint_intro()
        "jam":
            _paint_jam()
        "tray":
            _paint_tray()
        "toner":
            _paint_toner()
        "shake":
            _paint_shake()
        "test":
            _paint_test()
        "result":
            _paint_result()
    if phase != "result":
        var lines := _wrap(msg, int((panel.size.x - 8.0) / 4.0))
        for i in mini(lines.size(), 3):
            _txt(
                str(lines[i]),
                4,
                panel.size.y - 9.0 - float(mini(lines.size(), 3) - i) * 7.0,
                UiStyle.MUTED
            )
    UiStyle.footer(_canvas, panel, _hint())


# the same KEY = ACTION hint line the outing pages use
func _hint() -> String:
    match phase:
        "intro":
            return _tx("intro3")
        "jam":
            return "SPACE = PULL  P = PRAY  ESC = GIVE UP"
        "tray":
            return "LEFT / RIGHT  SPACE = LOAD  P = PRAY"
        "toner":
            return "LEFT / RIGHT  SPACE = FIT  P = PRAY"
        "shake":
            return "A / D = SHAKE  P = PRAY  ESC = GIVE UP"
        "test":
            return (
                "SPACE = NEXT  ESC = GIVE UP" if _answered else "1 / 2 / 3 = ANSWER  ESC = GIVE UP"
            )
    return _tx("done")


# the printer, drawn in 160 x 40 at y: every model has its own shape
func _printer(y: float) -> void:
    var cols := _colors()
    match str(_m().look):
        "inkjet":
            _r(30, y, 116, 6, PAPER)  # the sheet in the rear feed
            _r(8, y + 6, 160, 30, Color("e8e2d0"))
            _r(8, y + 6, 160, 3, Color("fbf8ee"))
            _r(12, y + 14, 152, 14, Color("2e3138"))
            _r(52, y + 31, 72, 5, Color("2e3138"))  # the output tray
            for i in 4:
                _r(24.0 + 38.0 * float(i), y + 17, 26, 8, cols[i])
        "plotter":
            _r(8, y, 160, 22, Color("d5d8de"))
            _r(8, y, 160, 3, Color("f2f4f8"))
            _r(12, y + 8, 152, 8, Color("2e3138"))
            _r(26, y + 22, 5, 18, Color("8e939e"))  # the stand
            _r(145, y + 22, 5, 18, Color("8e939e"))
            _r(44, y + 22, 88, 16, PAPER)  # the plot hanging out
            _r(44, y + 22, 88, 1, Color("9aa7b8"))
            _r(52, y + 28, 30, 1, Color("2fa7d8"))
            _r(52, y + 32, 60, 1, Color("8a8f9a"))
        "mfp":
            _r(8, y, 160, 8, Color("9fb4c8"))  # the scanner lid and glass
            _r(8, y, 160, 2, Color("d4e2ee"))
            _r(8, y + 8, 160, 32, Color("c9cdd6"))
            _r(8, y + 37, 160, 3, Color("8e939e"))
            _r(12, y + 13, 152, 18, Color("2e3138"))
            _r(18, y + 16, 30, 11, Color("3a6a42"))  # the little display
            for i in 4:
                _r(60.0 + 22.0 * float(i), y + 17, 16, 9, Color("6a6f7a"))
        "receipt":
            _r(52, y + 6, 72, 32, Color("e3e0d6"))
            _r(52, y + 6, 72, 3, Color("fbf8ee"))
            _r(56, y + 14, 64, 8, Color("2e3138"))  # the slot
            _r(70, y + 22, 36, 16, PAPER)  # the receipt
            for i in 4:
                _r(70.0 + 9.0 * float(i), y + 36, 5, 2, PAPER)  # the torn edge
            _r(60, y, 56, 6, Color("8e939e"))  # the lid
            _canvas.draw_circle(_o + Vector2(114.0, y + 12.0), 2.0, Color("e04a3a"))
        "dot":
            _r(34, y, 108, 12, PAPER)  # the form coming up
            for i in 5:
                _r(36, y + 1.0 + 2.0 * float(i), 2, 1, Color("8a8f9a"))  # pinfeed holes
                _r(138, y + 1.0 + 2.0 * float(i), 2, 1, Color("8a8f9a"))
            _r(8, y + 12, 160, 26, Color("d9d2b8"))
            _r(8, y + 12, 160, 3, Color("efe9d2"))
            _r(8, y + 35, 160, 3, Color("a89f84"))
            _r(20, y + 19, 136, 8, Color("3b3a36"))  # the carriage track
            _r(80, y + 16, 14, 12, Color("2a2a33"))  # the head
        _:
            _r(8, y, 160, 40, Color("c9cdd6"))
            _r(8, y, 160, 3, Color("f2f4f8"))
            _r(8, y + 37, 160, 3, Color("8e939e"))
            _r(12, y + 8, 152, 24, Color("2e3138"))
            for i in 4:
                _canvas.draw_circle(_o + Vector2(32.0 + 40.0 * float(i), y + 20.0), 7.0, Color("6a6f7a"))
                _canvas.draw_circle(_o + Vector2(32.0 + 40.0 * float(i), y + 20.0), 3.0, Color("4a4f5a"))


func _paint_intro() -> void:
    _printer(16)
    var lines := [_tx("intro1"), _tx("intro2")]
    for i in lines.size():
        _txt(str(lines[i]), 4, 58.0 + float(i) * 7.0)
    var y := 74.0
    if practice:
        _txt(
            "< %s >  SEED %02d" % [str(_m().label), practice_seed],
            4,
            y,
            UiStyle.HEAD
        )
        _txt(_tx("practice_help"), 4, y + 7.0, UiStyle.MUTED)
        y += 14.0
    if tired > 1.01:
        _txt(_tx("tired_note") % int(roundf((tired - 1.0) * 100.0)), 4, y, Color("c0392b"))


func _paint_jam() -> void:
    _printer(14)
    var n := jam_len
    var w := minf(28.0, 160.0 / float(n) - 4.0)
    for i in n:
        var x := 8.0 + (float(i) + 0.5) * 160.0 / float(n)
        if i < spot:
            _r(x - w * 0.5, 28, w, 5, PAPER)
        else:
            var bits := maxi(2, int(w / 5.0))
            for k in bits:
                var bx := x - w * 0.5 + float(k) * w / float(bits)
                _r(bx, 24.0 + float((k + i) % 3) * 3.0, w / float(bits) + 1.0, 9, PAPER)
                _r(bx, 24.0 + float((k + i) % 3) * 3.0, w / float(bits) + 1.0, 1, Color("c9c3b2"))
    _txt("PULLED %d OF %d" % [spot, jam_len], 8, 58)
    if tired > 1.01:
        _txt(_tx("tired_tag"), 80, 58, Color("c0392b"))
    _r(16, 74, 144, 10, Color("8a8f9a"))
    var zw := Difficulty.f("printer.zone")
    _r(16.0 + 144.0 * (zone - 0.16 * zw), 74, 144.0 * 0.32 * zw, 10, Color("f2c94c"))
    _r(16.0 + 144.0 * (zone - 0.07 * zw), 74, 144.0 * 0.14 * zw, 10, Color("4cff7a"))
    _r(16.0 + 144.0 * marker - 1.0, 71, 3, 16, INK)


func _paint_tray() -> void:
    _r(10, 14, 156, 20, Color("14301c"))
    _r(12, 16, 152, 16, Color("3a6a42"))
    _txt(_tx("tray_screen"), 16, 21, Color("d8f8d8"), 1)
    _txt(_tx("tray_slot"), 160.0 - float(_tx("tray_slot").length()) * 4.0, 21, Color("d8f8d8"), 1)
    for i in _tray().size():
        var x := 12.0 + 38.0 * float(i)
        _r(x, 40, 34, 28, INK)
        _r(x + 1, 41, 32, 26, PAPER if i < 3 else Color("c9cdd6"))
        if i < 3:
            for k in 3:
                _r(x + 5, 46.0 + float(k) * 5.0, 24.0 - float(i) * 2.0, 1, Color("8a8f9a"))
        _txt(str(_tray()[i]).substr(0, 8), x + 3, 58, INK)
        if i == tray_sel:
            _r(x - 2, 38, 38, 2, Color("ff6a3a"))
            _r(x - 2, 68, 38, 2, Color("ff6a3a"))


func _paint_toner() -> void:
    var n := _names().size()
    var x0 := (PW - (40.0 * float(n) - 10.0)) * 0.5
    for i in n:
        var x := x0 + 40.0 * float(i)
        _r(x, 24, 30, 36, INK)
        _r(x + 1, 25, 28, 34, _colors()[i])
        _r(x + 3, 28, 24, 5, Color(1, 1, 1, 0.35))
        _txt(str(_names()[i]).substr(0, 4), x + 2, 50, Color.WHITE if i != 2 or n < 4 else INK)
        if i == sel:
            _r(x - 2, 22, 34, 2, Color("ff6a3a"))
            _r(x - 2, 60, 34, 2, Color("ff6a3a"))
    if step < n:
        _txt("INSTALL: " + str(_names()[int(order[step])]), 8, 70, INK, 1)
    for i in n:
        _r(
            160.0 - 10.0 * float(n) + 10.0 * float(i),
            70,
            7,
            7,
            _colors()[int(order[i])] if i < step else Color("8a8f9a")
        )


func _paint_shake() -> void:
    var off := sin(_t * 30.0) * 3.0
    _r(70.0 + off, 22, 36, 44, INK)
    _r(71.0 + off, 23, 34, 42, _colors().back())
    _r(75.0 + off, 27, 26, 5, Color(1, 1, 1, 0.3))
    _r(16, 72, 144, 7, Color("8a8f9a"))
    _r(16, 72, 144.0 * float(shakes) / 10.0, 7, Color("4cff7a"))
    _r(16, 82, 144.0 * clampf(_shake_t / 5.0, 0.0, 1.0), 3, Color("ff6a3a"))


func _paint_test() -> void:
    var q: Dictionary = _qs()[int(asked[qi])]
    _r(10, 14, 156, 22, Color("14301c"))
    _r(12, 16, 152, 18, Color("3a6a42"))
    _txt(str(q.error), 16, 22, Color("d8f8d8"), 1)
    for i in 3:
        _txt("%d  %s" % [i + 1, str(q.options[i])], 10, 42.0 + float(i) * 8.0)


func _paint_result() -> void:
    UiStyle.stars(_canvas, _o.x + _pw * 0.5, _o.y + 12.0, stars)
    var y := 36.0
    for part in _wrap(msg, int((PW - 8.0) / 4.0)):
        _txt(str(part), 4, y)
        y += 7.0
    _txt("MISTAKES %d" % mistakes, 4, y + 3.0, UiStyle.HEAD)
    if streak >= 2:
        _txt(_tx("streak") % streak, 4, y + 10.0, UiStyle.GOLD)
''')

write("scripts/hud.gd", '''extends Node2D
# A tiny pixel clock in the top-right corner (3x5 digits drawn with rectangles). F10 hides it.

const GLYPHS := {
    "0": ["XXX", "X.X", "X.X", "X.X", "XXX"],
    "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
    "2": ["XXX", "..X", "XXX", "X..", "XXX"],
    "3": ["XXX", "..X", "XXX", "..X", "XXX"],
    "4": ["X.X", "X.X", "XXX", "..X", "..X"],
    "5": ["XXX", "X..", "XXX", "..X", "XXX"],
    "6": ["XXX", "X..", "XXX", "X.X", "XXX"],
    "7": ["XXX", "..X", "..X", ".X.", ".X."],
    "8": ["XXX", "X.X", "XXX", "X.X", "XXX"],
    "9": ["XXX", "X.X", "XXX", "..X", "XXX"],
    ":": ["...", ".X.", "...", ".X.", "..."],
}

const PixelFont := preload("res://scripts/pixelfont.gd")

var _acc := 0.0


func _process(delta: float) -> void:
    # the card header sits over the HUD text, so hide it while a card is up
    visible = World.hud_visible and not DayReport.is_open and not Cards.is_open
    _acc += delta
    if _acc > 0.25:
        _acc = 0.0
        queue_redraw()


func _draw() -> void:
    var text: String = World.clock_text()
    var width := text.length() * 4 - 1
    var origin := Vector2(get_viewport_rect().size.x - width - 3.0, 3.0)
    for pass_index in 2:
        var shade := pass_index == 0
        var color := Color(0.09, 0.07, 0.12, 0.9) if shade else Color(1, 1, 1, 0.95)
        var offset := Vector2(1, 1) if shade else Vector2.ZERO
        for i in text.length():
            var rows: Array = GLYPHS.get(text[i], GLYPHS["0"])
            for y in 5:
                for x in 3:
                    if String(rows[y])[x] == "X":
                        draw_rect(Rect2(origin + offset + Vector2(i * 4 + x, y), Vector2.ONE), color)
    if not Game.title_mode:
        var counts := "TKT %d MAIL %d" % [Msp.open_tickets().size(), Msp.unread()]
        if Msp.unread_texts() > 0:
            counts += " TXT %d" % Msp.unread_texts()
        if Lync.unread_total() > 0:
            counts += " IM %d" % Lync.unread_total()
        var lines := [counts]
        if Campaign.active:
            if Campaign.mode == "owner":
                lines.append("WEEK %d/%d CASH $%d" % [Campaign.day, Campaign.TOTAL_DAYS, Owner.cash])
            else:
                var day_line := "DAY %d/%d REP %d" % [Campaign.day, Campaign.TOTAL_DAYS, Campaign.rep]
                if Shift.active():
                    day_line += " NRG %d%s" % [int(Shift.energy), " ON CALL" if Shift.is_on_call() else ""]
                lines.append(day_line)
        if Nerf.holding():
            if Nerf.charging:
                lines.append("AIMING %d%%  RELEASE Z TO FIRE" % int(Nerf.charge * 100.0))
            else:
                lines.append("DARTS %d  Z FIRE (HOLD = FAR)  G AWAY%s" % [Nerf.ammo, ("  WAR %d" % int(Nerf.war_t)) if Nerf.war_t > 0.0 else ""])
        for i in lines.size():
            PixelFont.draw(self, lines[i], Vector2(4, 4 + i * 8), Color(0.09, 0.07, 0.12, 0.9))
            PixelFont.draw(self, lines[i], Vector2(3, 3 + i * 8), Color(1, 1, 1, 0.95))
        if Hints.toast_text != "" and not Game.ui_open:
            _draw_hint(Hints.toast_text)
        elif Hints.text != "" and not Game.ui_open:
            _draw_hint(Hints.text)
        elif Hints.objective != "" and not Game.ui_open:
            _draw_hint(Hints.objective)


func _draw_hint(text: String) -> void:
    var size := get_viewport_rect().size
    var chars := int((size.x - 16.0) / 4.0)
    var words := text.split(" ")
    var rows := []
    var line := ""
    for word in words:
        if line != "" and line.length() + 1 + word.length() > chars:
            rows.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    rows.append(line)
    var h := float(rows.size()) * 7.0 + 5.0
    draw_rect(Rect2(4.0, size.y - h - 4.0, size.x - 8.0, h), Color(0.04, 0.03, 0.08, 0.8))
    for i in rows.size():
        PixelFont.draw(self, str(rows[i]), Vector2(8.0, size.y - h + 0.0 + float(i) * 7.0), Color("ffe08a"))
''')

write("scripts/charselect.gd", '''extends Node2D
# Character select / first-day screen, shown by the title menu before a new run starts. A row of
# the playable characters (a carousel in narrow portrait) with an idle preview, a name and a short
# blurb; the tech campaign then asks for your phone. Left / Right move, Enter / E / Space confirm,
# Esc goes back, mouse hover and click work like the title menu. Confirming applies the choice
# (Player.current_character, Phone.os) and emits done(result); Esc on the first step emits
# cancelled. In the campaigns the cast members (Alan, Garrison, Dan, Vic ...) are already at
# their desks as NPCs, so only the people who are not in World.CAST are offered; Free Play
# offers everyone.

signal done(result: Dictionary)
signal cancelled

const PixelFont := preload("res://scripts/pixelfont.gd")
const PLAYER := preload("res://scripts/player.gd")
const GOLD := Color("f5d442")
const INK := Color("17121f")
const PANEL := Color(0.05, 0.07, 0.12, 0.85)
const DIM := Color("9aa8c0")
const PEOPLE := {
    "office_teen":
    {
        "name": "TEEN",
        "blurb": "FRESH HIRE WITH LONG HAIR AND BIG PLANS. LEARNS FAST, SPILLS COFFEE."
    },
    "office_adult":
    {"name": "ADULT", "blurb": "SEASONED TECH IN A MAROON POLO. HAS REBOOTED EVERY XP BOX TWICE."},
    "office_dan":
    {"name": "DAN", "blurb": "CALM IN A BLUE SHIRT AND GLASSES. NETWORKS ARE HIS THING."},
    "office_alan":
    {"name": "ALAN", "blurb": "CO-OWNER IN A RED SHIRT AND GREEN VEST. SERVER ROOM REGULAR, WATCHES THE BACKUPS."},
    "site_alan":
    {
        "name": "ALAN - ON SITE",
        "blurb": "ALAN IN THE GRAY WORK POLO. VAN KEYS, CABLE TESTER, NO TIME TO CHAT."
    },
    "casual_garrison":
    {
        "name": "GARRISON",
        "blurb": "CO-OWNER IN TEAL PLAID AND A GOATEE. CLIENTS AND CULTURE, ALWAYS TIME FOR A CHAT."
    },
    "sales_vic":
    {
        "name": "VIC",
        "blurb": "ACCOUNT MANAGER IN A JACKET AND RED TIE. A DEAL IS ALWAYS ABOUT TO CLOSE."
    },
}
const PHONES := [
    {
        "id": "ios",
        "name": "IFONE 5",
        "blurb": "SLATE, IOS 7, ONE HOME BUTTON. EVERYONE ELSE'S SCREEN IS CRACKED."
    },
    {
        "id": "android",
        "name": "NEXXUS 5",
        "blurb": "MATTE BLACK, ANDROID 4.4 KITKAT. THE $349 PHONE WITH THE GOOD SCREEN."
    },
]

var mode := "free"
var step := "char"  # "char" then (tech campaign only) "phone"
var ids: Array = []
var sel := 0
var phone_sel := 0
var facing := "right"
var _sprites: Array = []
var _rects: Array = []  # [Rect2, kind, index] for the mouse
var _born := -1


func _ready() -> void:
    _born = Engine.get_process_frames()
    Game.format_changed.connect(queue_redraw)
    queue_redraw()


func is_campaign() -> bool:
    return Campaign.MODES.has(mode)


func needs_phone() -> bool:
    return mode == "tech"


# who this mode offers: everyone in Free Play, only non-cast people in a campaign
func choices(for_mode: String) -> Array:
    var cast: Array = []
    for n in World.CAST:
        cast.append(str(World.CAST[n].character))
    var out: Array = []
    for id in PLAYER.CHARACTERS:
        if Campaign.MODES.has(for_mode) and id in cast:
            continue
        out.append(id)
    return out


func setup(for_mode: String) -> void:
    mode = for_mode
    step = "char"
    ids = choices(mode)
    sel = maxi(0, ids.find(PLAYER.current_character))
    if not PLAYER.current_character in ids:
        sel = maxi(0, ids.find("office_adult"))
    phone_sel = 1 if Phone.os == "android" else 0
    facing = "right"
    for spr in _sprites:
        spr.queue_free()
    _sprites.clear()
    for id in ids:
        var spr := AnimatedSprite2D.new()
        spr.sprite_frames = load("res://characters/%s.tres" % id)
        spr.play("idle_right")
        add_child(spr)
        _sprites.append(spr)
    queue_redraw()


func current_id() -> String:
    return str(ids[sel]) if sel < ids.size() else PLAYER.current_character


func info(id: String) -> Dictionary:
    return PEOPLE.get(id, {"name": id.to_upper(), "blurb": ""})


func summary(with_tier := true) -> String:
    var label: String = Campaign.MODES.get(mode, "FREE PLAY")
    var s := "%s - %s" % [label, str(info(current_id()).name)]
    if needs_phone():
        s += " - " + str(PHONES[phone_sel].name)
    if with_tier:
        s += " - " + Difficulty.label()
    return s


# Up / Down (or a click on the arrows) change the difficulty; it is remembered in the settings file
func change_tier(delta_tier: int) -> void:
    Difficulty.cycle_tier(delta_tier)
    Difficulty.save_settings()
    queue_redraw()


func move(delta_sel: int) -> void:
    if step == "char":
        if ids.is_empty():
            return
        sel = (sel + delta_sel + ids.size()) % ids.size()
        facing = "right" if delta_sel > 0 else "left"
    else:
        phone_sel = (phone_sel + delta_sel + PHONES.size()) % PHONES.size()
    queue_redraw()


func confirm() -> void:
    if step == "char" and needs_phone():
        step = "phone"
        queue_redraw()
        return
    var result := {
        "mode": mode,
        "character": current_id(),
        "phone": str(PHONES[phone_sel].id) if needs_phone() else "",
        "summary": summary(),
        "tier": Difficulty.tier,
    }
    PLAYER.current_character = current_id()
    if needs_phone():
        Phone.set_os(result.phone)
    done.emit(result)


func back() -> void:
    if step == "phone":
        step = "char"
        queue_redraw()
    else:
        cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
    if Engine.get_process_frames() == _born:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F9:
                Game.cycle_format()
            KEY_LEFT, KEY_A:
                move(-1)
            KEY_RIGHT, KEY_D:
                move(1)
            KEY_UP, KEY_W:
                change_tier(1)
            KEY_DOWN, KEY_S:
                change_tier(-1)
            KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
                confirm()
            KEY_ESCAPE, KEY_BACKSPACE:
                back()
            _:
                return
    elif event is InputEventMouseMotion:
        _hover(get_viewport().get_mouse_position())
        return
    elif (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ):
        _click(get_viewport().get_mouse_position())
    else:
        return
    get_viewport().set_input_as_handled()


func _hit(at: Vector2) -> Array:
    for r in _rects:
        if r[0].has_point(at):
            return r
    return []


func _hover(at: Vector2) -> void:
    var r := _hit(at)
    if r.is_empty():
        return
    var kind: String = r[1]
    if kind == "item" and step == "char" and sel != int(r[2]):
        sel = int(r[2])
        queue_redraw()
    elif kind == "phone" and phone_sel != int(r[2]):
        phone_sel = int(r[2])
        queue_redraw()


func _click(at: Vector2) -> void:
    var r := _hit(at)
    if r.is_empty():
        return
    match str(r[1]):
        "back":
            back()
        "prev":
            move(-1)
        "next":
            move(1)
        "tier_down":
            change_tier(-1)
        "tier_up":
            change_tier(1)
        _:
            _hover(at)
            confirm()


# ---- drawing --------------------------------------------------------------------
func _size() -> Vector2:
    return Vector2(Game.FORMATS[Game.format].size)


func _txt(s: String, p: Vector2, c := Color.WHITE) -> void:
    PixelFont.draw(self, s, p, c)


func _ctxt(s: String, y: float, c := Color.WHITE) -> void:
    _txt(s, Vector2(floorf((_size().x - float(PixelFont.width(s))) * 0.5), y), c)


func _wrap(s: String, chars: int, max_lines := 4) -> Array:
    var lines: Array = []
    var line := ""
    for word in s.split(" "):
        if line != "" and line.length() + 1 + word.length() > chars:
            lines.append(line)
            line = word
        else:
            line = word if line == "" else line + " " + word
    if line != "":
        lines.append(line)
    return lines.slice(0, max_lines)


func _para(s: String, y: float, c: Color, max_lines := 4) -> float:
    var chars := int((_size().x - 20.0) / 4.0)
    for line in _wrap(s, chars, max_lines):
        _ctxt(str(line), y, c)
        y += 8.0
    return y


func _draw() -> void:
    var size := _size()
    var narrow := size.x < 250.0
    _rects.clear()
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.08, 0.9))
    var heading := "CHOOSE YOUR CHARACTER" if step == "char" else "PICK YOUR PHONE"
    _ctxt(heading, 22.0 if narrow else 6.0, GOLD)
    var back_r := Rect2(3.0, 3.0, 28.0, 9.0)
    draw_rect(back_r, PANEL)
    _txt("< ESC", back_r.position + Vector2(2, 2), DIM)
    _rects.append([back_r, "back", 0])
    _draw_tier(size, narrow)
    if step == "char":
        _draw_chars(size, narrow)
    else:
        _place_sprites(size, narrow)
        _draw_phones(size, narrow)
    _ctxt(
        summary(false), size.y - (34.0 if narrow else (18.0 if size.y <= 130.0 else 19.0)), Color.WHITE
    )
    var hint := "LEFT RIGHT CHOOSE   UP DOWN LEVEL   ENTER PICK   ESC BACK"
    if narrow:
        _ctxt("LEFT RIGHT CHOOSE   UP DOWN LEVEL", size.y - 20.0, DIM)
        _ctxt("ENTER PICK   ESC BACK", size.y - 12.0, DIM)
    else:
        _ctxt(hint, size.y - 9.0, DIM)


# the difficulty chip: LEVEL < NORMAL > (top right, or under the heading in narrow portrait)
func _draw_tier(size: Vector2, narrow: bool) -> void:
    var text := "LEVEL  %s" % Difficulty.label()
    var w := float(PixelFont.width("LEVEL  HARD")) + 24.0
    var r := Rect2(floorf((size.x - w) * 0.5) if narrow else size.x - w - 3.0, 30.0 if narrow else 3.0, w, 9.0)
    draw_rect(r, PANEL)
    draw_rect(r, GOLD if Difficulty.tier != "normal" else DIM, false, 1.0)
    _txt("<", r.position + Vector2(3, 2), GOLD)
    _txt(">", r.position + Vector2(r.size.x - 7.0, 2), GOLD)
    var tw := float(PixelFont.width(text))
    _txt(text, r.position + Vector2(floorf((r.size.x - tw) * 0.5), 2), Color.WHITE)
    _rects.append([Rect2(r.position, Vector2(w * 0.5, 9.0)), "tier_down", 0])
    _rects.append([Rect2(r.position + Vector2(w * 0.5, 0.0), Vector2(w * 0.5, 9.0)), "tier_up", 0])


func _place_sprites(size: Vector2, narrow: bool) -> void:
    var n := ids.size()
    var pitch := minf(50.0, (size.x - 16.0) / maxf(1.0, float(n)))
    var feet := 83.0 if size.y <= 130.0 else 104.0
    if narrow:
        feet = 176.0
    for i in n:
        var spr: AnimatedSprite2D = _sprites[i]
        var show_it := step == "char" and (not narrow or i == sel)
        spr.visible = show_it
        spr.scale = Vector2(2, 2) if narrow else Vector2.ONE
        var cx := size.x * 0.5 if narrow else (size.x - pitch * n) * 0.5 + pitch * (i + 0.5)
        spr.position = Vector2(cx, feet - (80.0 if narrow else 40.0))
        var face := facing if i == sel else ("right" if i < sel else "left")
        var anim := "idle_" + face
        if spr.animation != anim:
            spr.play(anim)


func _draw_chars(size: Vector2, narrow: bool) -> void:
    _place_sprites(size, narrow)
    var n := ids.size()
    var pitch := minf(50.0, (size.x - 16.0) / maxf(1.0, float(n)))
    var feet := 83.0 if size.y <= 130.0 else 104.0
    if narrow:
        feet = 176.0
        var panel := Rect2(26.0, feet - 136.0, size.x - 52.0, 146.0)
        draw_rect(panel, PANEL)
        draw_rect(panel, GOLD, false, 1.0)
        var mid := panel.position.y + panel.size.y * 0.5
        for side in 2:
            var ar := Rect2(2.0 if side == 0 else size.x - 22.0, mid - 12.0, 20.0, 24.0)
            _rects.append([ar, "prev" if side == 0 else "next", 0])
            _txt("<" if side == 0 else ">", ar.position + Vector2(8, 9), GOLD)
        _rects.append([panel, "item", sel])
        var dots_y := feet + 22.0
        for i in n:
            var dx := size.x * 0.5 + (float(i) - float(n - 1) * 0.5) * 8.0
            draw_rect(Rect2(dx - 1.5, dots_y, 3, 3), GOLD if i == sel else Color("46506a"))
    else:
        for i in n:
            var cx := (size.x - pitch * n) * 0.5 + pitch * (i + 0.5)
            var r := Rect2(cx - pitch * 0.5 + 1.0, feet - 68.0, pitch - 2.0, 76.0)
            _rects.append([r, "item", i])
            draw_rect(r, Color(0.1, 0.13, 0.2, 0.9) if i == sel else PANEL)
            if i == sel:
                draw_rect(r, GOLD, false, 1.0)
    var data := info(current_id())
    var name_y := feet + (12.0 if narrow else 10.0)
    _ctxt(str(data.name), name_y, GOLD)
    var by := name_y + (20.0 if narrow else 9.0)
    var end_y := _para(str(data.blurb), by, Color.WHITE, 4 if narrow else 2)
    if is_campaign():
        var note := "THE REST OF THE TEAM IS ALREADY AT THEIR DESKS"
        if end_y + 8.0 < size.y - (46.0 if narrow else 28.0):
            _para(note, end_y + 2.0, DIM, 2)


func _draw_phones(size: Vector2, narrow: bool) -> void:
    var ph := 54.0 if size.y <= 130.0 else (80.0 if not narrow else 92.0)
    var pw := floorf(ph * 0.52)
    var top := 22.0 if size.y <= 130.0 else (26.0 if not narrow else 56.0)
    for i in 2:
        var ios := i == 0
        var x := floorf(size.x * 0.5) + (-pw - 16.0 if ios else 16.0)
        var b := Rect2(x, top, pw, ph)
        var hot := phone_sel == i
        _rects.append([Rect2(b.position - Vector2(6, 4), b.size + Vector2(12, 16)), "phone", i])
        if hot:
            draw_rect(Rect2(b.position - Vector2(3, 3), b.size + Vector2(6, 6)), GOLD)
        draw_rect(b, Color("9aa0a8") if ios else Color("3a3d44"))
        draw_rect(
            Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)),
            Color("1c1e23") if ios else Color("0e0f12")
        )
        var scr := Rect2(
            b.position.x + 3,
            b.position.y + (7 if ios else 5),
            b.size.x - 6,
            b.size.y - (19 if ios else 9)
        )
        draw_rect(scr, Color("4a78d6") if ios else Color("0b2742"))
        draw_rect(
            Rect2(scr.position.x + 2, scr.position.y + 3, scr.size.x - 4, 3), Color(1, 1, 1, 0.5)
        )
        if ios:
            draw_circle(Vector2(b.position.x + pw * 0.5, b.end.y - 6), 2, Color("55595f"))
        else:
            draw_rect(Rect2(scr.position.x, scr.end.y - 3, scr.size.x, 3), Color("000000"))
        var label: String = PHONES[i].name
        _txt(
            label,
            Vector2(floorf(x + (pw - float(PixelFont.width(label))) * 0.5), b.end.y + 5),
            Color.WHITE if hot else DIM
        )
    _para(str(PHONES[phone_sel].blurb), top + ph + 16.0, Color.WHITE, 3)
''')

write("scripts/title.gd", '''extends Node2D
# Title screen. A few vignettes rotate behind the MSPSim logo: the cast lined up in the office, two
# people on the phones at their desks, coffee and the fridge in the kitchenette, and a meeting in
# the conference room. Each one is the real room scene in "title mode" (no player, no World cast)
# with NPC nodes acting it out. Enter / Space / E / a click starts the game; F9 cycles the output
# format. The office clock is frozen until you start.

const NPC_SCENE := preload("res://scenes/npc.tscn")
const LOGO := preload("res://assets/ui/mspsim_logo.png")
const LOGO_SMALL := preload("res://assets/ui/mspsim_logo_s.png")
const PROMPT := preload("res://assets/ui/press_start.png")
const PixelFont := preload("res://scripts/pixelfont.gd")
const CharSelect := preload("res://scripts/charselect.gd")
const FLOOR_Y := 118.0
const SHOW_SECS := 9.0
const VIGNETTES := ["lineup", "phones", "kitchen", "conference"]
const ROOMS := {
    "lineup": "main_floor",
    "phones": "cubicle_area",
    "kitchen": "kitchenette",
    "conference": "conference"
}

var _cam: Camera2D
var _logo: Sprite2D
var _prompt: Sprite2D
var _fade: ColorRect
var _room: Node = null
var _index := 0
var _t := 0.0
var _busy := false
var _started := false
var _hud_was := true
var _menu_open := false
var _sel := 0
var _items: Array = []
var _menu: Node2D
var _front: CanvasLayer
var _select: Node2D = null  # the character select screen while it is open
var _career: Node = null  # the career screen while it is open


func _ready() -> void:
    World.time_scale = 0.0
    _hud_was = World.hud_visible
    World.hud_visible = false
    Game.title_mode = true
    _cam = Camera2D.new()
    add_child(_cam)
    var back := CanvasLayer.new()
    back.layer = 10
    add_child(back)
    _fade = ColorRect.new()
    _fade.color = Color(0.05, 0.04, 0.08, 0.0)
    _fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    back.add_child(_fade)
    var front := CanvasLayer.new()
    front.layer = 20
    add_child(front)
    _front = front
    _logo = Sprite2D.new()
    _logo.centered = false
    front.add_child(_logo)
    _prompt = Sprite2D.new()
    _prompt.centered = false
    _prompt.texture = PROMPT
    front.add_child(_prompt)
    var blink := Timer.new()
    blink.wait_time = 0.55
    blink.autostart = true
    blink.timeout.connect(func() -> void: _prompt.visible = not _prompt.visible and not _menu_open)
    add_child(blink)
    _menu = Node2D.new()
    _menu.visible = false
    front.add_child(_menu)
    _menu.draw.connect(_draw_menu)
    Game.format_changed.connect(_on_format)
    Difficulty.load_settings()
    show_vignette(0)


func _on_format() -> void:
    show_vignette(_index)


func _size() -> Vector2:
    return Vector2(Game.FORMATS[Game.format].size)


func _layout() -> void:
    var size := _size()
    var wide := size.x > 340.0 and size.y <= 130.0
    var narrow := size.x < 250.0
    var cam_y := 64.0 if size.y <= 130.0 else (50.0 if size.y <= 200.0 else 60.0)
    var cam_x := 184.0
    if VIGNETTES[_index] == "phones" and narrow:
        cam_x = 117.0  # the two desks
    _cam.zoom = Vector2.ONE
    _cam.position = Vector2(cam_x, cam_y)
    _logo.texture = LOGO_SMALL if narrow else LOGO
    var top := 4.0 if wide else (14.0 if not narrow else 24.0)
    _logo.position = Vector2(floorf((size.x - _logo.texture.get_width()) * 0.5), top)
    var pw := float(PROMPT.get_width())
    var ph := float(PROMPT.get_height())
    if wide:
        _prompt.position = Vector2(size.x - pw - 8.0, size.y - ph - 3.0)
    else:
        _prompt.position = Vector2(
            floorf((size.x - pw) * 0.5), size.y - ph - (17.0 if not narrow else 40.0)
        )


# build vignette number i (no fade; used at start, on a format change and by tests)
func show_vignette(i: int) -> void:
    _index = i % VIGNETTES.size()
    _t = 0.0
    if _room != null:
        remove_child(_room)
        _room.queue_free()
    var kind: String = VIGNETTES[_index]
    _room = load("res://scenes/%s.tscn" % ROOMS[kind]).instantiate()
    add_child(_room)
    _act(kind)
    _layout()


func _npc(who: String, facing: String, x: float, routine: Array, seat := "", item := "") -> void:
    var npc: Node = NPC_SCENE.instantiate()
    npc.character = who
    npc.facing = facing
    npc.routine = PackedStringArray(routine)
    npc.start_seat = seat
    npc.start_item = item
    npc.position = Vector2(x, FLOOR_Y)
    _room.get_node("Actors").add_child(npc)


func _act(kind: String) -> void:
    var data: Dictionary = World.DATA.SCENES[ROOMS[kind]]
    match kind:
        "lineup":
            var size := _size()
            var wide := size.x > 340.0 and size.y <= 130.0
            var narrow := size.x < 250.0
            var xs := (
                [150.0, 184.0, 218.0, -1.0]
                if narrow
                else ([128.0, 168.0, 208.0, -1.0] if wide else [142.0, 182.0, 270.0, 310.0])
            )
            var gap := ["talk:4", "wait:3"]
            _npc("casual_garrison", "left", xs[0], gap)
            _npc("office_alan", "right", xs[1], gap)
            _npc("office_dan", "left", xs[2], ["wait:3", "say:2", "wait:4"])
            if xs[3] >= 0.0:
                _npc("office_adult", "right", xs[3], ["wait:30"])
        "phones":
            _npc("casual_garrison", "right", data.seats.Seat1, ["wait:60"], "Seat1", "coffee")
            _npc("office_dan", "right", data.seats.Seat2, ["wait:60"], "Seat2")
            var phones := get_tree().get_nodes_in_group("phones")
            for i in phones.size():
                var zone: Node = phones[i]
                get_tree().create_timer(1.2 + 2.2 * i).timeout.connect(_ring.bind(zone))
        "kitchen":
            var u: Dictionary = data.uses
            _npc(
                "office_dan",
                "right",
                u.fridge + 40.0,
                [
                    "walk:%d" % (u.fridge + 8),
                    "use:fridge",
                    "wait:1",
                    "sip",
                    "wait:4",
                    "sip",
                    "wait:2"
                ]
            )
            _npc(
                "office_alan",
                "left",
                u.coffee + 40.0,
                [
                    "walk:%d" % (u.coffee + 20),
                    "use:coffee",
                    "wait:1",
                    "sip",
                    "wait:4",
                    "sip",
                    "wait:3"
                ]
            )
            _npc(
                "casual_garrison",
                "left",
                u.coffee + 70.0,
                ["wait:2", "talk:5", "wait:2", "talk:4", "wait:1"]
            )
        "conference":
            var s: Dictionary = data.seats
            _npc(
                "office_dan",
                "right",
                s.Seat1,
                ["wait:1", "say:3", "wait:4", "say:2"],
                "Seat1",
                "coffee"
            )
            _npc(
                "office_alan",
                "right",
                s.Seat2,
                ["wait:4", "say:3", "wait:2", "say:3"],
                "Seat2",
                "soda"
            )
            _npc(
                "casual_garrison",
                "right",
                s.Seat3,
                ["wait:2", "say:2", "wait:5", "say:2"],
                "Seat3",
                "bottle"
            )


func _ring(zone: Variant) -> void:
    if is_instance_valid(zone):
        var fx: Node = zone.get_node(zone.target)
        if not fx.busy:
            fx.ringing = true
            fx._ring_until = fx._time + 20.0


func _process(delta: float) -> void:
    if _busy or _started:
        return
    _t += delta
    if _t >= SHOW_SECS:
        _rotate()


func _rotate() -> void:
    _busy = true
    var tween := create_tween()
    tween.tween_property(_fade, "color:a", 1.0, 0.3)
    tween.tween_callback(func() -> void: show_vignette(_index + 1))
    tween.tween_property(_fade, "color:a", 0.0, 0.3)
    tween.tween_callback(func() -> void: _busy = false)


func _unhandled_input(event: InputEvent) -> void:
    if _started or _select != null or _career != null:
        return
    var go := false
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F9:
            Game.cycle_format()
            _menu.queue_redraw()
        go = event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]
        if _menu_open:
            _menu_key(event.keycode, go)
            return
    elif event is InputEventMouseMotion and _menu_open:
        _hover(get_viewport().get_mouse_position())
        return
    elif (
        event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
    ):
        go = true
        if _menu_open:
            if _hover(get_viewport().get_mouse_position()):
                _choose(_sel)
            return
    if go:
        _open_menu()


func _menu_key(code: Key, confirm: bool) -> void:
    if code == KEY_UP:
        _move(-1)
    elif code == KEY_DOWN:
        _move(1)
    elif confirm:
        _choose(_sel)
    elif code == KEY_ESCAPE:
        _menu_open = false
        _menu.visible = false


func _open_menu() -> void:
    _items = []
    if Campaign.has_save("tech"):
        var label := "CONTINUE TECH - DAY %d" % Campaign.saved_day("tech")
        _items.append({"label": label, "id": "tech_continue", "enabled": true})
        _items.append({"label": "NEW TECH CAMPAIGN", "id": "tech_new", "enabled": true})
    else:
        _items.append({"label": "TECH CAMPAIGN", "id": "tech_new", "enabled": true})
    if Campaign.has_save("owner"):
        var owner_label := "CONTINUE OWNER - WEEK %d" % Campaign.saved_day("owner")
        _items.append({"label": owner_label, "id": "owner_continue", "enabled": true})
        _items.append({"label": "NEW OWNER CAMPAIGN", "id": "owner_new", "enabled": true})
    else:
        _items.append({"label": "OWNER CAMPAIGN", "id": "owner_new", "enabled": true})
    _items.append({"label": "FREE PLAY - FILM MODE", "id": "free", "enabled": true})
    _items.append({"label": "CAREER", "id": "career", "enabled": true})
    _sel = 0
    _menu_open = true
    _prompt.visible = false
    _menu.visible = true
    _menu.queue_redraw()


func _move(step: int) -> void:
    var i := _sel
    for _n in _items.size():
        i = (i + step + _items.size()) % _items.size()
        if _items[i].enabled:
            _sel = i
            break
    _menu.queue_redraw()


func _hover(at: Vector2) -> bool:
    for i in _items.size():
        if _items[i].enabled and _items[i].get("rect", Rect2()).has_point(at):
            _sel = i
            _menu.queue_redraw()
            return true
    return false


func _choose(i: int) -> void:
    if i < 0 or i >= _items.size() or not _items[i].enabled:
        return
    var id := str(_items[i].id)
    if id == "career":
        _open_career()
        return
    if id.ends_with("_continue"):
        _start(id)  # a saved run keeps its character: no select screen
    else:
        _open_select(id)


func _open_career() -> void:
    if _career != null:
        return
    _logo.visible = false
    _menu.visible = false
    _career = Career.open_screen(_close_career)


func _close_career() -> void:
    _career = null
    _logo.visible = true
    _menu.visible = _menu_open
    _menu.queue_redraw()


# new runs pick their character (and, in the tech campaign, their phone) first
func _open_select(id: String) -> void:
    if _select != null:
        return
    var mode := Campaign.FREE
    if id == "tech_new":
        mode = "tech"
    elif id == "owner_new":
        mode = "owner"
    _select = CharSelect.new()
    _select.setup(mode)
    _select.done.connect(_on_select_done.bind(id))
    _select.cancelled.connect(_close_select)
    _front.add_child(_select)
    _logo.visible = false
    _menu.visible = false


func _close_select() -> void:
    if _select == null:
        return
    _select.queue_free()
    _select = null
    _logo.visible = true
    _menu.visible = _menu_open
    _menu.queue_redraw()


func _on_select_done(result: Dictionary, id: String) -> void:
    _select.queue_free()
    _select = null
    _start(id, str(result.summary))


func _start(id: String, summary := "") -> void:
    _started = true
    World.time_scale = 1.0
    World.hud_visible = _hud_was
    Game.title_mode = false
    Shift.enabled = true
    Outings.enabled = true
    Onsite.enabled = true
    Outings.use_rooms = true
    match id:
        "tech_new":
            Campaign.new_game("tech")
        "tech_continue":
            Campaign.continue_game("tech")
        "owner_new":
            Campaign.new_game("owner")
        "owner_continue":
            Campaign.continue_game("owner")
        _:
            Campaign.new_game(Campaign.FREE)
    Game.go("main_floor", "start")
    if summary != "":
        var wide_enough: bool = Game.FORMATS[Game.format].size.x >= 300
        Hints.toast(summary + ("  RUN " + Difficulty.seed_text() if wide_enough else ""), 4.0)


func _draw_menu() -> void:
    var size := _size()
    var y := _logo.position.y + float(_logo.texture.get_height()) + 7.0
    for i in _items.size():
        var item: Dictionary = _items[i]
        var label: String = item.label
        var w := float(PixelFont.width(label)) + 12.0
        var r := Rect2(floorf((size.x - w) * 0.5), y + float(i) * 10.0, w, 9.0)
        item["rect"] = r
        var chosen: bool = i == _sel and item.enabled
        var back := Color("f5d442") if chosen else Color(0.05, 0.07, 0.12, 0.8)
        var ink := Color("17121f") if chosen else (Color.WHITE if item.enabled else Color("7d8595"))
        _menu.draw_rect(r, back)
        PixelFont.draw(_menu, label, r.position + Vector2(6, 2), ink)
''')

write("scripts/net.gd", '''extends Node
# Autoload: the network closet. A UPS feeds a PDU that powers the switch, router and NAS; one
# patch cable per desk runs from the patch panel into a switch port; an uplink joins switch and
# router; the router's WAN cable goes to the ISP; the UPS plugs into the wall. Desks (monitors,
# phones, the copier) only work while their whole chain is plugged in and the devices have
# finished booting. Cable ends can be pulled out and plugged into other ports of the right kind.

const LAYOUT_PATH := "res://assets/props/network_rack_layout.json"
const BOOT := {"sw": 3.0, "rt": 6.0, "nas": 8.0}  # seconds from power to ready
# cable id -> [kind, port the movable end sits in]
const DEFAULTS := {
    "p1": ["net", "sw1"], "p2": ["net", "sw2"], "p3": ["net", "sw3"], "p4": ["net", "sw4"],
    "p5": ["net", "sw5"], "p6": ["net", "sw6"], "p7": ["net", "sw7"], "p8": ["net", "sw8"],
    "up": ["net", "sw9"], "nas": ["net", "sw10"], "wan": ["wan", "wan"],
    "sw_pwr": ["pwr", "pdu1"], "rt_pwr": ["pwr", "pdu2"], "nas_pwr": ["pwr", "pdu3"],
    "pdu_in": ["feed", "ups1"], "ups_in": ["inlet", "wall"],
}
const PATCH_COLORS := ["#4f7fd0", "#4f9c8e", "#e0a030", "#9a60c8"]

var layout := {}
var cables := {}  # id -> {kind, end}
var port_pos := {}  # port id -> Vector2 in rack coordinates
var carrying := ""  # the cable whose end is in the player's hand
var ups_on := true
var nas_on := true
var battery := 1.0
var _boot := {"sw": 99.0, "rt": 99.0, "nas": 99.0}


func _ready() -> void:
    layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
    for p in layout.ports:
        port_pos[p.id] = Vector2(float(p.x), float(p.y))
    reset()


func reset() -> void:
    cables.clear()
    for id in DEFAULTS:
        cables[id] = {"kind": DEFAULTS[id][0], "end": DEFAULTS[id][1]}
    carrying = ""
    ups_on = true
    nas_on = true
    battery = 1.0
    for key in _boot:
        _boot[key] = 99.0


func cable_color(id: String) -> Color:
    if id.begins_with("p"):
        return Color(PATCH_COLORS[(int(id.substr(1)) - 1) % PATCH_COLORS.size()])
    match id:
        "up":
            return Color("e8d43c")
        "nas":
            return Color("6ec24e")
        "wan":
            return Color("d23c3c")
        "ups_in":
            return Color("b8bcc4")
    return Color("7b808c")


func far_pos(id: String) -> Vector2:
    var f: Array = layout.far[id]
    return Vector2(float(f[0]), float(f[1]))


func occupant(port: String) -> String:
    for id in cables:
        if cables[id].end == port:
            return id
    return ""


func accepts(cable: String, port: String) -> bool:
    match cables[cable].kind:
        "net":
            return port.begins_with("sw")
        "wan":
            return port == "wan"
        "pwr":
            return port.begins_with("pdu")
        "feed":
            return port.begins_with("ups")
        "inlet":
            return port == "wall"
    return false


func pick(cable: String) -> void:
    cables[cable].end = ""
    carrying = cable
    _cut_power_timers()


func plug(port: String) -> void:
    cables[carrying].end = port
    carrying = ""


func drop_carry() -> void:
    carrying = ""


func press(button: String) -> void:
    if button == "ups_btn":
        ups_on = not ups_on
    elif button == "nas_btn":
        nas_on = not nas_on
    _cut_power_timers()


# a device that lost power forgets that it was booted
func _cut_power_timers() -> void:
    var p := power()
    for key in ["sw", "rt", "nas"]:
        if not p[key]:
            _boot[key] = 0.0


# which devices are being fed power right now (before boot time)
func power() -> Dictionary:
    var p := {}
    p.wall = cables.ups_in.end == "wall"
    p.ups_out = ups_on and (p.wall or battery > 0.0)
    p.pdu = p.ups_out and cables.pdu_in.end.begins_with("ups")
    p.sw = p.pdu and cables.sw_pwr.end.begins_with("pdu")
    p.rt = p.pdu and cables.rt_pwr.end.begins_with("pdu")
    p.nas = p.pdu and cables.nas_pwr.end.begins_with("pdu") and nas_on
    return p


func status() -> Dictionary:
    var s := power()
    s.sw_ready = s.sw and _boot.sw >= BOOT.sw
    s.rt_ready = s.rt and _boot.rt >= BOOT.rt
    s.nas_ready = s.nas and _boot.nas >= BOOT.nas
    s.uplink = s.sw_ready and s.rt_ready and cables.up.end.begins_with("sw")
    s.wan = s.rt_ready and cables.wan.end == "wan"
    s.internet = s.uplink and s.wan
    return s


# "ok", "no_internet" (linked, but router / WAN / uplink down) or "no_link" (no cable / switch)
func desk_state(desk: int) -> String:
    if desk < 1 or desk > 8:
        return "ok"
    var s := status()
    if not (s.sw_ready and cables["p%d" % desk].end.begins_with("sw")):
        return "no_link"
    return "ok" if s.internet else "no_internet"


func _process(delta: float) -> void:
    var p := power()
    for key in ["sw", "rt", "nas"]:
        _boot[key] = _boot[key] + delta if p[key] else 0.0
    if ups_on:
        if p.wall:
            battery = minf(1.0, battery + delta / 100.0)
        else:
            battery = maxf(0.0, battery - delta / 90.0)
''')

write("scripts/port.gd", '''extends Node2D
# One plug point in the network closet: a switch port, a PDU or UPS outlet, the router's WAN
# port, the wall outlet, or a power button. E pulls the plug out (you carry the cable end) or
# plugs the cable you carry into it.

@export var port_id := ""
@export var arrow_offset := Vector2(0, -5)

var player: Node = null
var _arrow: Node2D


func _ready() -> void:
    add_to_group("ports")
    _arrow = preload("res://scripts/prompt_arrow.gd").new()
    _arrow.base_y = arrow_offset.y
    _arrow.position = arrow_offset
    _arrow.visible = false
    add_child(_arrow)


func _process(_delta: float) -> void:
    _arrow.visible = player != null and player.nearest() == self


func use(body: Node) -> void:
    if port_id.ends_with("_btn"):
        Net.press(port_id)
        body.reach(global_position.x)
        return
    var cable := Net.occupant(port_id)
    var done := false
    if Net.carrying == "":
        if cable != "" and body.held == "":
            Net.pick(cable)
            body.give("plug_net" if Net.cables[cable].kind in ["net", "wan"] else "plug_pwr")
            done = true
    elif cable == "" and Net.accepts(Net.carrying, port_id):
        Net.plug(port_id)
        body.give("")
        done = true
    if done:
        body.reach(global_position.x)
    else:
        _arrow.shake()
''')

write("scripts/rack_zone.gd", '''extends Area2D
# Standing anywhere in the closet puts every plug point in reach (Tab moves the arrow around).


func _ready() -> void:
    body_entered.connect(_on_enter)
    body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
    if body.has_method("sit"):
        for port in get_tree().get_nodes_in_group("ports"):
            body.add_near(port)
            port.player = body


func _on_exit(body: Node) -> void:
    if body.has_method("sit"):
        for port in get_tree().get_nodes_in_group("ports"):
            body.remove_near(port)
            port.player = null
''')

write("scripts/stage.gd", '''extends Node2D
# Put the player on the spawn point chosen by the door they came through, and run the follow
# camera for the current output format (Game.format). F1-F7 jump between sets, F9 cycles format.

const SETS := [
    "main_floor", "office_one", "office_two", "conference", "kitchenette", "bathroom", "cubicle_area",
    "network_closet"
]

var barriers := {}  # npc sync points: key -> {arrived, gen}

var _cam: Camera2D
var _player: Node2D
var _room := ""
var _dark_a := 0.0  # 0 = lit, 1 = lights out


func _ready() -> void:
    if Game.title_mode:
        var shown_player := get_node_or_null("Actors/Player")
        if shown_player != null:
            shown_player.free()
        return
    var spawn: Node = get_node_or_null("Spawns/%s" % Game.pending_spawn)
    if spawn == null:
        spawn = get_node_or_null("Spawns/start")
    Game.pending_spawn = "start"
    _player = get_node("Actors/Player")
    _player.global_position = spawn.global_position
    if Game.pending_x >= 0.0:  # a one-shot "put me back where I was" (after an outing)
        _player.global_position.x = Game.pending_x
        Game.pending_x = -1.0
    _player.face(str(spawn.get_meta("facing", "right")))
    _cam = Camera2D.new()
    _cam.position_smoothing_enabled = true
    _cam.position_smoothing_speed = 7.0
    add_child(_cam)
    var bg: Sprite2D = get_node("Background")
    var tex := bg.texture.get_size()
    _cam.limit_left = int(bg.position.x)
    _cam.limit_right = int(bg.position.x + tex.x)
    _cam.limit_top = int(bg.position.y)
    _cam.limit_bottom = int(bg.position.y + tex.y)
    Game.format_changed.connect(_apply_format)
    _apply_format()
    World.populate(self)
    Expo.populate(self)
    Onsite.populate(self)
    _room = scene_file_path.get_file().get_basename()
    _set_dark(0.0 if World.lights_on(_room) else 1.0)
    World.lights_changed.connect(_on_lights)
    if Net.carrying != "" and _room != "network_closet":
        Net.drop_carry()  # a cable end cannot leave the closet
        _player.give("")


func _on_lights(room: String) -> void:
    if room == _room:
        var target := 0.0 if World.lights_on(_room) else 1.0
        create_tween().tween_method(_set_dark, _dark_a, target, 0.25)


# lights out = a blue-grey tint on the background, the fx and everything standing in the room, so
# the depth order is untouched; screens and bubbles (group "emissive") cancel the tint and glow
func _set_dark(amount: float) -> void:
    _dark_a = amount
    var tint := Color(lerpf(1.0, 0.34, amount), lerpf(1.0, 0.38, amount), lerpf(1.0, 0.58, amount))
    for layer in ["Background", "Fx", "Actors"]:
        get_node(layer).modulate = tint
    var inverse := Color(1.0 / tint.r, 1.0 / tint.g, 1.0 / tint.b)
    for node in get_tree().get_nodes_in_group("emissive"):
        node.modulate = inverse


func _apply_format() -> void:
    var f: Dictionary = Game.FORMATS[Game.format]
    _cam.zoom = Vector2.ONE * float(f.zoom)
    _cam.enabled = true
    if not f.follow:
        # classic 368x128 view: no camera movement, the room sits centred like before
        _cam.limit_left = -10000000
        _cam.limit_right = 10000000
        _cam.limit_top = -10000000
        _cam.limit_bottom = 10000000
        _cam.position_smoothing_enabled = false
        _cam.global_position = Vector2(184, 64)
    else:
        var bg: Sprite2D = get_node("Background")
        var tex := bg.texture.get_size()
        _cam.limit_left = int(bg.position.x)
        _cam.limit_right = int(bg.position.x + tex.x)
        _cam.limit_top = int(bg.position.y)
        _cam.limit_bottom = int(bg.position.y + tex.y)
        _cam.position_smoothing_enabled = true
        _cam.global_position = Vector2(_player.global_position.x, float(f.cam_y))
        _cam.reset_smoothing()


func _process(_delta: float) -> void:
    if Game.title_mode:
        return
    var f: Dictionary = Game.FORMATS[Game.format]
    if f.follow or Game.ui_shift > 0.0:
        var base_y: float = float(f.cam_y) if f.follow else 64.0
        _cam.global_position = Vector2(_player.global_position.x, _ui_cam_y(base_y, f))
        if not f.follow:
            _cam.global_position.x = 184.0


# a UI covers all but a strip at the top: slide the camera down so the player shows there
func _ui_cam_y(base_y: float, f: Dictionary) -> float:
    if Game.ui_shift <= 0.0:
        var bg: Sprite2D = get_node("Background")
        if _cam.limit_bottom == 100000 and Game.FORMATS[Game.format].follow:
            _cam.limit_bottom = int(bg.position.y + bg.texture.get_size().y)
            _cam.position_smoothing_enabled = true
        return base_y
    var half := get_viewport_rect().size.y * 0.5
    var strip := maxf(12.0, floorf(half * 2.0 * Game.UI_STRIP))
    var zoom: float = float(f.zoom)
    var target := _player.global_position.y - 28.0 + (half - strip * 0.5) / zoom
    # whatever lies below the art is hidden by the UI window: the camera may leave the set
    _cam.limit_bottom = 100000
    _cam.position_smoothing_enabled = false
    return lerpf(base_y, target, Game.ui_shift)


func _unhandled_input(event: InputEvent) -> void:
    if Game.title_mode:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F9:
            Game.cycle_format()
            return
        if event.keycode == KEY_F11 and event.ctrl_pressed:
            var sites := []
            for t in ["dental", "law", "vet", "arch", "realty", "trailer"]:
                for skin in ["a", "b"]:
                    sites.append("site_%s_%s" % [t, skin])
            var at := get_tree().current_scene.scene_file_path.get_file().get_basename()
            Game.go(sites[(sites.find(at) + 1) % sites.size()], "start")
            return
        if event.keycode == KEY_F11:
            Game.go("escape_room" if event.shift_pressed else "bowling_alley", "start")
            return
        if event.keycode == KEY_F12 and event.ctrl_pressed:
            var venue := ["resort_lobby", "resort_hall", "ballroom", "breakout_room", "vendor_hall"]
            var here := get_tree().current_scene.scene_file_path.get_file().get_basename()
            Game.go(venue[(venue.find(here) + 1) % venue.size()], "start")
            return
        if event.keycode == KEY_F12:
            Game.go("restaurant" if event.shift_pressed else "karaoke_bar", "start")
            return
        var i: int = event.keycode - KEY_F1
        if i >= 0 and i < SETS.size():
            Game.go(SETS[i], "start")
''')

write("scripts/player.gd", '''extends CharacterBody2D
# Side-on character controller. A/D or arrows move, Shift run, Space jump,
# E use/sit/chat, Q wave, X dance, C follow me, F sip, H/K/R hurt/die/revive, 1-6 character.

const HELD_ITEM := preload("res://scripts/held_item.gd")
const WALK_SPEED := 40.0
const RUN_SPEED := 90.0
const GRAVITY := 900.0
const JUMP_SPEED := 230.0
const CHARACTERS := [
    "office_teen", "office_adult", "office_dan", "office_alan", "site_alan", "casual_garrison", "sales_vic"
]

static var current_character := "office_adult"

var facing := "right"
var state := "idle"   # idle walk run crouch jump land hurt death sitdown sitting standup
var grounded_once := false   # no "airborne" until first floor contact (spawning on the floor)
var seat: Node = null
var held := ""  # "", "coffee", "water" (kept in Game.vars across rooms)
var sips := 0
var _item: Node2D
var _sip_pending := false
var _call_stage := ""  # "", "tap_on", "talking", "tap_off"
var _call_t := 0.0
var _call_len := 0.0
var _head_item: Node2D
var _dance_t := 0.0
var _slide_to := INF
var _desk: Node2D
var _emote_t := 0.0
var _emote_len := 0.0
var _bubble: Node2D = null
var _pick: Node = null  # the target chosen with Tab (until you walk away from it)
var _pick_x := 0.0
var _near: Array[Node] = []  # doors / seats whose area we are inside

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Collision


func _ready() -> void:
    _add_inputs()
    held = str(Game.vars.get("held", ""))
    sips = int(Game.vars.get("sips", 0))
    _item = HELD_ITEM.new()
    _item.item = held
    add_child(_item)
    _head_item = HELD_ITEM.new()
    _head_item.mode = "ear"
    add_child(_head_item)
    add_to_group("player")
    _load_character(current_character)
    sprite.animation_finished.connect(_on_animation_finished)
    _play("idle")


func add_near(n: Node) -> void:
    if n not in _near:
        _near.append(n)


func remove_near(n: Node) -> void:
    _near.erase(n)


# the closest door/seat by x, so overlapping zones pick what you are standing at
func nearest() -> Node:
    if _pick != null and (_pick not in _near or absf(global_position.x - _pick_x) > 10.0):
        _pick = null
    if _pick != null:
        return _pick
    var best: Node = null
    var best_d := INF
    for n in _near:
        var d := absf(n.global_position.x - global_position.x)
        d += 0.02 * absf(n.global_position.y - (global_position.y - 40.0))
        if n.get("low_priority") == true:
            d += 14.0
        elif n.is_in_group("npcs") and str(n.get("role")) == "site:owner":
            d -= 8.0  # the client owner beats the PC on their own desk (E talks to them, Tab still picks the PC)
        elif n.is_in_group("npcs") and str(n.get("role")).begins_with("site:"):
            d += 20.0  # doors and equipment beat small talk with the client staff (Tab still selects them)
        if d < best_d:
            best_d = d
            best = n
    return best


# Tab / Shift+Tab: move the arrow to the next / previous thing within reach without walking
func cycle_pick(step: int) -> void:
    var list: Array = _near.duplicate()
    if list.is_empty():
        return
    list.sort_custom(
        func(a: Node, b: Node) -> bool:
            if absf(a.global_position.x - b.global_position.x) > 0.5:
                return a.global_position.x < b.global_position.x
            return a.global_position.y < b.global_position.y
    )
    var at := list.find(nearest())
    _pick = list[posmod(at + step, list.size())]
    _pick_x = global_position.x


func face(side: String) -> void:
    facing = side
    _play("idle")


func _add_inputs() -> void:
    var keys := {
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "jump": [KEY_SPACE, KEY_W, KEY_UP], "run": [KEY_SHIFT], "interact": [KEY_E],
        "hurt": [KEY_H], "die": [KEY_K], "revive": [KEY_R],
        "wave": [KEY_Q],
        "drink": [KEY_F],
        "dance": [KEY_X],
        "follow": [KEY_C],
        "duck": [KEY_S, KEY_DOWN],
    }
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
            for code in keys[action]:
                var ev := InputEventKey.new()
                ev.physical_keycode = code
                InputMap.action_add_event(action, ev)


func _load_character(name: String) -> void:
    current_character = name
    sprite.sprite_frames = load("res://characters/%s.tres" % name)


# swap the sprite sheet without losing the running animation (one-shots like sitdown / land /
# hurt would otherwise never emit animation_finished and the state machine would hang)
func _switch_character(name: String) -> void:
    var anim := sprite.animation
    var frame := sprite.frame
    var progress := sprite.frame_progress
    var was_playing := sprite.is_playing()
    var speed := sprite.get_playing_speed()
    _load_character(name)
    sprite.animation = anim
    if was_playing:
        sprite.play(anim, speed, speed < 0.0)
    sprite.set_frame_and_progress(frame, progress)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.keycode == KEY_Z and not event.pressed:
        Nerf.charge_release(self)
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_TAB:
            cycle_pick(-1 if event.shift_pressed else 1)
            return
        if event.keycode == KEY_Z:
            Nerf.charge_start(self)
            return
        if event.keycode == KEY_G and held == "nerf":
            give("")
            return
        var i: int = event.keycode - KEY_1
        if i >= 0 and i < CHARACTERS.size() and not Campaign.active:
            _switch_character(CHARACTERS[i])


func _play(action: String) -> void:
    var anim := action
    if action == "duck":
        anim = "crouch"
    if held != "":
        if action == "idle":
            anim = "hold"
        elif action in ["walk", "run"]:
            anim = "walkhold"
    sprite.play("%s_%s" % [anim, facing])


func character_id() -> String:
    return current_character


func give(item: String) -> void:
    if item == "nerf":
        Nerf.on_given()
    held = item
    sips = 0
    Game.vars["held"] = held
    Game.vars["sips"] = sips
    _item.item = held
    if state in ["idle", "walk", "run"]:
        _play(state)


# answer: tap the ear, a wireless headset appears, talk (walk or keep typing), tap it off
# step to this x while a conversation starts (so you stand a talking distance from the other person)
func slide_to(x: float) -> void:
    _slide_to = x


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


# the nearest ringing desk phone within reach of the seat (answered without standing up)
func _ringing_phone() -> Node:
    if seat == null:
        return null
    for zone in get_tree().get_nodes_in_group("phones"):
        var fx: Node = zone.get_node(zone.target)
        var dx: float = zone.global_position.x - seat.global_position.x
        var near := dx > 20.0 and dx < 70.0  # a desk phone sits to the right of its own seat
        if fx.ringing and not fx.busy and near:
            return zone
    return null


# the computer in front of the seat (opened with E while seated)
func _seat_computer() -> Node:
    if seat == null:
        return null
    for zone in get_tree().get_nodes_in_group("computers"):
        var dx: float = zone.global_position.x - seat.global_position.x
        if dx > 5.0 and dx < 60.0:
            return zone
    return null


func drink() -> void:
    _sip_pending = true
    if state == "sitting":
        _item.item = held
        if _desk != null:
            _desk.item = ""
        start_emote("sitsip", 0.75)
    else:
        start_emote("sip", 0.75)


# seated at a desk the cup stands on the desktop; standing up picks it back up
func _stash() -> void:
    if held == "" or seat == null or not seat.stash:
        return
    _item.item = ""
    if _desk == null:
        _desk = preload("res://scripts/desk_cup.gd").new()
        get_parent().add_child.call_deferred(_desk)
    _desk.position = Vector2(seat.global_position.x + seat.cup_dx, 109.0)
    _desk.rest_y = seat.cup_y
    _desk.item = held


func _unstash() -> void:
    if _desk != null:
        _desk.item = ""
    _item.item = held


func _set_state(new_state: String) -> void:
    state = new_state
    if new_state != "jump":
        _play(new_state)


func sit(s: Node) -> void:
    seat = s
    state = "sitdown"
    velocity = Vector2.ZERO
    body_shape.set_deferred("disabled", true)
    global_position = s.global_position
    facing = s.facing
    _play("sitdown")


func _stand_up() -> void:
    state = "standup"
    sprite.play_backwards("sitdown_%s" % facing)


func reach(toward_x: float) -> void:
    _face_toward(toward_x)
    velocity = Vector2.ZERO
    state = "use"
    _play("reach")


# a timed gesture (wave / talk), optionally with a speech-bubble icon
func start_emote(anim: String, secs: float, toward_x := INF, glyph := "") -> void:
    if toward_x != INF:
        _face_toward(toward_x)
    velocity = Vector2.ZERO
    state = "emote"
    _emote_t = secs
    _emote_len = secs
    _play(anim)
    if glyph != "":
        _ensure_bubble()
        _bubble.glyph = glyph
        _bubble.visible = false


# X: dance on the spot until X again, a move or a jump (the player's choice; NPCs never dance)
func _start_dance() -> void:
    velocity = Vector2.ZERO
    state = "dance"
    _dance_t = 0.0
    _play("dance")
    _ensure_bubble()
    _bubble.glyph = "note"
    _bubble.visible = true


func _stop_dance() -> void:
    if _bubble != null:
        _bubble.visible = false
    _set_state("idle")


func _dance_tick(delta: float, wants_out: bool) -> bool:
    if state != "dance":
        return false
    velocity = Vector2.ZERO
    _dance_t += delta
    _bubble.visible = int(_dance_t / 0.9) % 2 == 0
    if wants_out or Input.is_action_just_pressed("dance"):
        _stop_dance()
    return true


# X dance, Q wave, F sip: gestures from the ground (returns true when one started)
func _try_gesture(locked: bool) -> bool:
    if locked or not is_on_floor():
        return false
    var did := true
    if Input.is_action_just_pressed("dance"):
        _start_dance()
    elif Input.is_action_just_pressed("wave"):
        start_emote("wave", 1.3)
    elif Input.is_action_just_pressed("drink") and held != "" and not held.begins_with("plug_") and held != "nerf":
        drink()
    elif Input.is_action_just_pressed("follow"):
        did = _ask_follow()
    else:
        did = false
    return did


# C next to someone: ask them to follow you (or to stop)
func _ask_follow() -> bool:
    var best: Node = null
    var best_d := INF
    for zone in _near:
        if zone.has_method("toggle_follow"):
            var d := absf(zone.global_position.x - global_position.x)
            if d < best_d:
                best_d = d
                best = zone
    if best != null:
        best.toggle_follow(self)
    return best != null


func _end_emote() -> void:
    if _bubble != null:
        _bubble.visible = false
    if _call_stage == "tap_on":
        _call_stage = "talking"
        _call_t = _call_len
        _head_item.item = "headset"
    elif _call_stage == "tap_off":
        _call_stage = ""
        _head_item.item = ""
        if _bubble != null:
            _bubble.visible = false
    if _sip_pending:
        _sip_pending = false
        sips += 1
        Game.vars["sips"] = sips
        if sips >= (6 if seat != null else 3):
            held = ""
            Game.vars["held"] = ""
            _item.item = ""
            if _desk != null:
                _desk.item = ""
    if seat != null:
        state = "sitting"
        _play("type" if seat.typing else "sit")
        _stash()
        return
    _set_state("idle")


func _face_toward(x: float) -> void:
    if absf(x - global_position.x) > 0.5:
        facing = "right" if x > global_position.x else "left"


func _physics_process(delta: float) -> void:
    if Game.ui_open:
        velocity = Vector2.ZERO
        return
    _call_tick(delta)
    var locked: bool = Game.busy
    var dir := 0.0 if locked else Input.get_axis("move_left", "move_right")
    var running := Input.is_action_pressed("run")
    var interact := (not locked) and Input.is_action_just_pressed("interact") and not Outings.blocks_interact()
    var jump := (not locked) and Input.is_action_just_pressed("jump")

    if state in ["use", "emote"]:
        velocity = Vector2.ZERO
        if _slide_to != INF:
            global_position.x = move_toward(global_position.x, _slide_to, 80.0 * delta)
            if is_equal_approx(global_position.x, _slide_to):
                _slide_to = INF
        if state == "emote":
            _emote_t -= delta
            if _bubble != null:
                _bubble.visible = int((_emote_len - _emote_t) / 1.3) % 2 == 1 and _emote_len > 2.0
            if _emote_t <= 0.0:
                _end_emote()
        return

    if _dance_tick(delta, dir != 0.0 or jump or interact):
        return

    if state in ["sitdown", "sitting", "standup"]:
        velocity = Vector2.ZERO
        if state == "sitting" and interact and _ringing_phone() != null:
            _ringing_phone().use(self)
        elif state == "sitting" and interact and _seat_computer() != null:
            _seat_computer().use(self)
        elif state == "sitting" and held != "" and held != "nerf" and Input.is_action_just_pressed("drink"):
            drink()
        elif state == "sitting" and (interact or jump or dir != 0.0):
            _stand_up()
        return

    if not is_on_floor():
        velocity.y += GRAVITY * delta

    if not locked and not Campaign.active:
        if Input.is_action_just_pressed("die") and state != "death":
            _set_state("death")
            velocity.x = -60.0 * (1 if facing == "right" else -1)
        elif Input.is_action_just_pressed("hurt") and state not in ["death", "hurt"]:
            _set_state("hurt")
            velocity.x = -50.0 * (1 if facing == "right" else -1)
        elif Input.is_action_just_pressed("revive") and state == "death":
            _set_state("idle")

    var duck_held := (not locked) and Input.is_action_pressed("duck")
    if state == "duck" and (not duck_held or not is_on_floor()):
        _set_state("idle")
    elif duck_held and state in ["idle", "walk", "run"] and is_on_floor() and not Nerf.charging:
        _set_state("duck")
    match state:
        "death", "hurt":
            velocity.x = move_toward(velocity.x, 0.0, 250.0 * delta)
        "crouch", "land", "duck":
            velocity.x = 0.0
        _:
            velocity.x = dir * (RUN_SPEED if running else WALK_SPEED)
            if dir != 0.0:
                var side := "right" if dir > 0.0 else "left"
                if side != facing:
                    facing = side
                    if state != "jump":
                        _play(state)

    if state in ["idle", "walk", "run"]:
        if _try_gesture(locked):
            return
        var target := nearest()
        if interact and target != null:
            target.use(self)
            if state in ["sitdown", "use", "emote"]:
                return
        if jump and is_on_floor():
            velocity.x = 0.0
            _set_state("crouch")
        elif not is_on_floor() and grounded_once:
            state = "jump"
        else:
            var want := "idle"
            if dir != 0.0:
                want = "run" if running else "walk"
            if want != state:
                _set_state(want)

    move_and_slide()
    if is_on_floor():
        grounded_once = true

    if state == "jump":
        # pick the frame from vertical speed: rise, apex, fall
        var frame := 0 if velocity.y < -90.0 else (1 if velocity.y < 90.0 else 2)
        if sprite.animation != StringName("jump_%s" % facing):
            sprite.play("jump_%s" % facing)
        sprite.pause()
        sprite.frame = frame
        if is_on_floor() and velocity.y >= 0.0:
            _set_state("land")


func _on_animation_finished() -> void:
    match state:
        "crouch":
            velocity.y = -JUMP_SPEED
            state = "jump"
        "land", "hurt", "use":
            _set_state("idle")
        "sitdown":
            state = "sitting"
            _play("type" if seat.typing else "sit")
            _stash()
        "standup":
            _unstash()
            global_position = Vector2(seat.global_position.x, seat.stand_y)
            body_shape.set_deferred("disabled", false)
            seat = null
            velocity = Vector2.ZERO
            state = "idle"
            _play("idle")
''')

write("scenes/player.tscn", '''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://characters/office_adult.tres" id="2"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]
size = Vector2(14, 56)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"idle_right"
offset = Vector2(0, -40)

[node name="Collision" type="CollisionShape2D" parent="."]
position = Vector2(0, -28)
shape = SubResource("RectangleShape2D_body")
''')


# Ambient/interactive effects. Props: copier/cooler get an effect on the sprite (their art is y-sorted), monitors
# get a live screen. BGFX are on the background art: (name, kind, art_x, art_y, interact_x)
PIECE_W = {"copier": 30, "cooler": 14, "desk_phone": 14, "monitor": 26, "rubber_duck": 4}
# effects with no interaction: (name, kind, art_x, art_y)
AMBIENT = {
    "resort_hall": [("Sign0", "session_sign", 66, 57), ("Sign1", "session_sign", 136, 57), ("Sign2", "session_sign", 206, 57),
                    ("Sign3", "session_sign", 276, 57)],
    "bowling_alley": [("NeonBowl", "neon_bowl", 176, 6), ("NeonShoes", "neon_shoes", 22, 6), ("Lanes", "bowl_lane", 0, 0),
                      ("Scores", "bowl_score", 108, 8)],
    "karaoke_bar": [("NeonKaraoke", "neon_karaoke", 12, 4), ("Lyrics", "lyrics", 208, 28), ("Disco", "discoball", 145, -4)],
    "restaurant": [("NeonBar", "neon_bar", 162, 2), ("TvA", "sports_tv", 208, 2), ("TvB", "sports_tv", 264, 2),
                   ("PendantA", "lamp", 28, 2), ("PendantB", "lamp", 100, 2)],
    "escape_room": [("Timer", "ledtimer", 140, 4), ("RedLight", "redlight", 226, 4),
                    ("LampGlow", "lamp", 124, 68)],
}
BGFX = {
    "main_floor": [("TV", "tv", 261, 25, 280), ("Switch", "switch", 148, 54, 150), ("SalesBell", "bell", 124, 36, 132)],
    "office_one": [("Switch", "switch", 42, 54, 44)],
    "office_two": [("Switch", "switch", 42, 54, 44)],
    "conference": [("Switch", "switch", 8, 54, 10)],
    "cubicle_area": [("Switch", "switch", 8, 54, 10), ("NerfRack", "nerf_rack", 190, 34, 203)],
    "kitchenette": [("Coffee", "coffee", 82, 60, 90), ("Fridge", "fridge", 46, 30, 78, 59, -46),
                    ("Switch", "switch", 40, 54, 42)],
    "bathroom": [("Sink", "sink", 65, 64, 73), ("Toilet", "toilet", 100, 66, 108), ("Switch", "switch", 42, 54, 44)],
    "network_closet": [("Switch", "switch", 40, 54, 42)],
    "bowling_alley": [("Switch", "switch", 8, 54, 10)],
    "karaoke_bar": [("Switch", "switch", 8, 54, 10)],
    "escape_room": [("Switch", "switch", 8, 54, 10), ("Keypad", "keypad", 244, 40, 252),
                    ("Board", "clue_board", 192, 14, 214), ("WallClock", "clue_clock", 54, 20, 62),
                    ("Painting", "clue_painting", 112, 10, 125)],
    "restaurant": [("Switch", "switch", 8, 54, 10)],
    "vendor_hall": [("BoothSwag", "booth_swag", 40, 36, 71), ("BoothBackup", "booth_vendor", 128, 36, 159),
                    ("BoothForum", "booth_nerds", 216, 36, 247)],
}

for _t in SITE_TYPES:
    for _s in ("a", "b"):
        BGFX["site_%s_%s" % (_t, _s)] = (
            [("Obj%s%d" % (_k.title(), _n), "onsite_" + _k, _ax, _ay, _ix) for _n, (_k, _ax, _ay, _ix) in enumerate(SITE_MAIN[_t])]
            + [("Door", "onsite_door", 4, 18, 21)])
        BGFX["site_%s_closet_%s" % (_t, _s)] = [("ObjCabinet", "onsite_cabinet", 56, 4, 89), ("ObjServer", "onsite_server", 126, 80, 135)]
        BGFX["site_%s_office_%s" % (_t, _s)] = [("ObjVip", "onsite_vip", 96, 54, 108)]
        if _t == "dental":
            BGFX["site_%s_%s" % (_t, _s)].append(("ObjFish", "onsite_fish", 84, 52, 104))
        if _t == "realty":   # the coffee bar and the sign-in clipboard (E: a coffee, a line)
            BGFX["site_%s_%s" % (_t, _s)] += [("ObjCoffee", "onsite_coffeebar", 82, 62, 97), ("ObjSignin", "onsite_signin", 114, 30, 129)]
        if _t == "arch":     # the reception desk (low priority: the PC beside it wins)
            BGFX["site_%s_%s" % (_t, _s)].append(("ObjRecep", "onsite_recep", 234, 77, 241))
        if _t == "vet":
            BGFX["site_%s_%s" % (_t, _s)] += [("ObjDog", "onsite_dog", 184, 94, 196), ("ObjCat", "onsite_cat", 106, 58, 114)]
            BGFX["site_%s_office_%s" % (_t, _s)] += [("ObjDog", "onsite_dog", 150, 94, 162), ("ObjCat", "onsite_cat", 200, 64, 208)]
        if _t in SITE_EXAMS:
            BGFX["site_%s_exam_%s" % (_t, _s)] = [("ObjExam", "onsite_exam", 86, 64, 100)] + ([("ObjXray", "onsite_xray", 200, 44, 215)] if _t == "dental" else [("ObjDog", "onsite_dog", 204, 94, 216), ("ObjCat", "onsite_cat", 160, 56, 168)])


write("scenes/title.tscn", '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/title.gd" id="1"]

[node name="Title" type="Node2D"]
script = ExtResource("1")
''')

write("scenes/npc.tscn", '''[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/npc.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://characters/office_dan.tres" id="2"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_npc"]
size = Vector2(46, 56)

[node name="Npc" type="Area2D"]
script = ExtResource("1")

[node name="Sprite" type="AnimatedSprite2D" parent="."]
sprite_frames = ExtResource("2")
animation = &"idle_right"
offset = Vector2(0, -40)

[node name="Shape" type="CollisionShape2D" parent="."]
position = Vector2(0, -30)
shape = SubResource("RectangleShape2D_npc")
''')

# Background characters: (node name, character, start x, facing, start seat, routine). x values are set pixels.


# ---- map data for the persistent cast (scripts/world_data.gd) ----------------
world_scenes = {}
for fname, cfg in SETS.items():
    W = cfg["W"]
    x0 = (VIEW_W - W) // 2
    links = []
    outside_x = -1
    for d in cfg["doors"]:
        dname, cx, tscene, tspawn, remember = d[:5]
        locked = len(d) > 5 and d[5]
        if locked and dname == "FrontDoor":
            outside_x = x0 + cx
        if locked or not tscene:
            continue
        link = {"name": dname, "x": x0 + cx, "to": tscene, "spawn": tspawn}
        if remember.startswith("bath_return="):
            link["remember"] = remember.split("=")[1]
        links.append(link)
    for ename, side, tscene, tspawn in cfg["exits"]:
        links.append({"name": ename, "x": x0 + 4 if side == "left" else x0 + W - 4, "to": tscene, "spawn": tspawn})
    seats = {f"Seat{i + 1}": x0 + sc[0] for i, sc in enumerate(cfg["seats"])}
    uses = {}
    for entry in BGFX.get(fname, []):
        uses[entry[1]] = x0 + entry[4]
    mp = os.path.join(ROOT, "assets", "sets", f"{fname}_props.json")
    for pr in (json.load(open(mp)) if os.path.exists(mp) else []):
        if pr["piece"] in ("copier", "cooler"):
            uses[pr["piece"]] = x0 + pr["x"] + PIECE_W[pr["piece"]] // 2
    spawns = {n: [x0 + sx, face] for n, (sx, face) in cfg["spawns"].items()}
    world_scenes[fname] = {"x0": x0, "W": W, "spawns": spawns, "links": links, "seats": seats, "uses": uses,
                           "outside_x": outside_x}
write("scripts/world_data.gd", "extends RefCounted\n# generated by tools/make_godot.py (do not edit): the map for the persistent cast\nconst SCENES := "
      + json.dumps(world_scenes, indent=1) + "\n")

DESK_BASE = {"main_floor": 1, "cubicle_area": 4, "office_one": 6, "office_two": 7}


def desk_line(scene, piece, counts):
    """`desk = N` for monitors and phones (N = their patch panel port); the copier is desk 8."""
    if piece == "copier":
        return ["desk = 8"]
    if piece not in ("monitor", "desk_phone") or scene not in DESK_BASE:
        return []
    n = counts.get(piece, 0)
    counts[piece] = n + 1
    return [f"desk = {DESK_BASE[scene] + n}"]


# ---- one scene per set -------------------------------------------------------
for fname, cfg in SETS.items():
    W, node = cfg["W"], cfg["node"]
    x0 = (VIEW_W - W) // 2
    manifest_path = os.path.join(ROOT, "assets", "sets", f"{fname}_props.json")
    props = json.load(open(manifest_path)) if os.path.exists(manifest_path) else []
    pieces = sorted({p["piece"] for p in props})

    ext = [('Texture2D', f'res://assets/sets/{fname}.png', 'bg'), ('PackedScene', 'res://scenes/player.tscn', 'player'),
           ('Script', 'res://scripts/stage.gd', 'stage'), ('Script', 'res://scripts/door.gd', 'door'),
           ('Script', 'res://scripts/seat.gd', 'seat'),
           ('Script', 'res://scripts/fx.gd', 'fx'), ('Script', 'res://scripts/interact.gd', 'interact'),
           ('Script', 'res://scripts/port.gd', 'port'), ('Script', 'res://scripts/rack_zone.gd', 'rack_zone'),
           ('PackedScene', 'res://scenes/npc.tscn', 'npc')]
    ext += [('Texture2D', f'res://assets/props/{p}.png', f'prop_{p}') for p in pieces]
    lines = [f'[ext_resource type="{t}" path="{path}" id="{i}"]' for t, path, i in ext]
    lines.append("")
    shapes = {"floor": (VIEW_W + 400, 20), "wall": (8, 300), "door": (30, 96), "exit": (12, 200), "seat": (26, 60), "fx": (24, 96), "rack": (100, 60)}
    if fname == "escape_room":
        shapes["clue"] = (36, 96)  # the clue zones are wider so they are easy to hit
    for k, (w, h) in shapes.items():
        lines += [f'[sub_resource type="RectangleShape2D" id="shape_{k}"]', f'size = Vector2({w}, {h})', ""]
    lines += [f'[node name="{node}" type="Node2D"]', 'script = ExtResource("stage")', ""]
    lines += ['[node name="Background" type="Sprite2D" parent="."]', f'position = Vector2({x0 - max(0, (MIN_W - W) // 2)}, {-SET_TOP})',
              'centered = false', 'texture = ExtResource("bg")', ""]
    # collision: floor + side walls
    def body(name, pos, shape):
        return [f'[node name="{name}" type="StaticBody2D" parent="."]', f'position = Vector2({pos[0]}, {pos[1]})', "",
                f'[node name="Shape" type="CollisionShape2D" parent="{name}"]', f'shape = SubResource("shape_{shape}")', ""]
    lines += body("Ground", (VIEW_W // 2, FLOOR_Y + 10), "floor")
    lines += body("WallLeft", (x0 - 4, 0), "wall")
    lines += body("WallRight", (x0 + W + 4, 0), "wall")
    # spawns
    lines += ['[node name="Spawns" type="Node2D" parent="."]', ""]
    for sname, (sx, sface) in cfg["spawns"].items():
        lines += [f'[node name="{sname}" type="Marker2D" parent="Spawns"]', f'position = Vector2({x0 + sx}, {FLOOR_Y})',
                  f'metadata/facing = "{sface}"', ""]
    # interactables
    lines += ['[node name="Interactables" type="Node2D" parent="."]', ""]
    for d in cfg["doors"]:
        dname, cx, tscene, tspawn, remember = d[:5]
        locked = len(d) > 5 and d[5]
        lines += [f'[node name="Door{dname}" type="Area2D" parent="Interactables"]', f'position = Vector2({x0 + cx}, 70)',
                  'script = ExtResource("door")', f'target_scene = "{tscene}"', f'target_spawn = "{tspawn}"']
        if remember:
            lines.append(f'remember = "{remember}"')
        if locked and dname == "FrontDoor":
            lines.append('special = "front"')   # the front door opens the where-to menu (Onsite.offer_door)
        elif locked:
            lines.append('locked = true')
        lines += ["", f'[node name="Shape" type="CollisionShape2D" parent="Interactables/Door{dname}"]',
                  'shape = SubResource("shape_door")', ""]
    for ename, side, tscene, tspawn in cfg["exits"]:
        ex = x0 + 4 if side == "left" else x0 + W - 4
        lines += [f'[node name="Exit{ename}" type="Area2D" parent="Interactables"]', f'position = Vector2({ex}, 60)',
                  'script = ExtResource("door")', f'target_scene = "{tscene}"', f'target_spawn = "{tspawn}"', 'auto = true', "",
                  f'[node name="Shape" type="CollisionShape2D" parent="Interactables/Exit{ename}"]',
                  'shape = SubResource("shape_exit")', ""]
    for i, seat_cfg in enumerate(cfg["seats"]):
        sx, sy, typing = seat_cfg[:3]
        lounge = len(seat_cfg) > 3 and seat_cfg[3]
        lines += [f'[node name="Seat{i + 1}" type="Area2D" parent="Interactables"]', f'position = Vector2({x0 + sx}, {sy})',
                  'script = ExtResource("seat")', 'facing = "right"', f'typing = {"true" if typing else "false"}',
                  *(['stash = false'] if lounge else ([] if typing else ['cup_dx = 14.0', 'cup_y = 80.0'])), "",
                  f'[node name="Shape" type="CollisionShape2D" parent="Interactables/Seat{i + 1}"]',
                  'position = Vector2(0, -14)', 'shape = SubResource("shape_seat")', ""]
    bgfx = BGFX.get(fname, [])
    for i, p in enumerate(props):
        p["_node"] = f'{p["piece"]}_{i}'
    for p in [q for q in props if q["piece"] in PIECE_W]:
        ix = p["x"] + PIECE_W[p["piece"]] // 2
        lines += [f'[node name="Use{p["_node"]}" type="Area2D" parent="Interactables"]', f'position = Vector2({x0 + ix}, 70)',
                  'script = ExtResource("interact")', f'target = NodePath("../../Actors/{p["_node"]}/Fx")',
                  *(['group = "phones"'] if p["piece"] == "desk_phone" else (['group = "computers"'] if p["piece"] == "monitor" else (['low_priority = true'] if p["piece"] == "rubber_duck" else []))), "",
                  f'[node name="Shape" type="CollisionShape2D" parent="Interactables/Use{p["_node"]}"]',
                  'shape = SubResource("shape_fx")', ""]
    for name, kind, ax, ay, ix, *opt in bgfx:
        lines += [f'[node name="Use{name}" type="Area2D" parent="Interactables"]', f'position = Vector2({x0 + ix}, 70)',
                  'script = ExtResource("interact")', f'target = NodePath("../../Fx/{name}")',
                  *(['low_priority = true'] if kind in ("bell", "onsite_recep", "onsite_signin") else []),
                  *([f'look_x = {x0 + opt[0]}.0', f'arrow_offset = Vector2({opt[0] - ix}, {opt[1]})'] if len(opt) > 1 else []),
                  "",
                  f'[node name="Shape" type="CollisionShape2D" parent="Interactables/Use{name}"]',
                  'shape = SubResource("shape_clue")' if fname == "escape_room" and (kind.startswith("clue_") or kind == "keypad") else 'shape = SubResource("shape_fx")', ""]
    lines += ['[node name="Fx" type="Node2D" parent="."]', ""]
    for name, kind, ax, ay, ix, *opt in bgfx:
        lines += [f'[node name="{name}" type="Node2D" parent="Fx"]', f'position = Vector2({x0 + ax}, {ay})',
                  'script = ExtResource("fx")', f'kind = "{kind}"', ""]
    for name, kind, ax, ay in AMBIENT.get(fname, []):
        lines += [f'[node name="{name}" type="Node2D" parent="Fx"]', f'position = Vector2({x0 + ax}, {ay})',
                  'script = ExtResource("fx")', f'kind = "{kind}"', ""]
    if fname == "network_closet":
        lay = json.load(open(os.path.join(ROOT, "assets", "props", "network_rack_layout.json")))
        rx, ry = lay["rack"]
        lines += ['[node name="Rack" type="Node2D" parent="Fx"]', f'position = Vector2({x0 + rx}, {ry})',
                  'script = ExtResource("fx")', 'kind = "rack"', ""]
        lines += ['[node name="Ports" type="Node2D" parent="."]', ""]
        for pt in lay["ports"]:
            lines += [f'[node name="{pt["id"]}" type="Node2D" parent="Ports"]',
                      f'position = Vector2({x0 + rx + pt["x"]}, {ry + pt["y"]})',
                      'script = ExtResource("port")', f'port_id = "{pt["id"]}"', ""]
        lines += ['[node name="RackZone" type="Area2D" parent="Interactables"]', f'position = Vector2({x0 + 86}, 95)',
                  'script = ExtResource("rack_zone")', "",
                  '[node name="Shape" type="CollisionShape2D" parent="Interactables/RackZone"]',
                  'shape = SubResource("shape_rack")', ""]
    # y-sorted actors: furniture sprites + the player
    lines += ['[node name="Actors" type="Node2D" parent="."]', 'y_sort_enabled = true', ""]
    desk_count = {}
    for i, p in enumerate(props):
        # Godot 2D sorts by the node's own y, so put the node origin ON the sort line and shift the art
        # up with `offset` (centered = false: the texture's top-left lands at position + offset).
        sort_y = int(math.floor(p["sort"] + 0.5))
        lines += [f'[node name="{p["piece"]}_{i}" type="Sprite2D" parent="Actors"]',
                  f'position = Vector2({x0 + p["x"]}, {sort_y})', 'centered = false',
                  f'offset = Vector2(0, {p["y"] - sort_y})',
                  f'texture = ExtResource("prop_{p["piece"]}")', ""]
        if p["piece"] in PIECE_W or p["piece"] == "monitor":
            lines += [f'[node name="Fx" type="Node2D" parent="Actors/{p["piece"]}_{i}"]',
                      f'position = Vector2(0, {p["y"] - sort_y})', 'script = ExtResource("fx")',
                      f'kind = "{p["piece"]}"', f'seed_offset = {i}', *desk_line(fname, p["piece"], desk_count), ""]
    lines += ['[node name="Player" parent="Actors" instance=ExtResource("player")]',
              f'position = Vector2({x0 + 60}, {FLOOR_Y})', ""]
    text = f'[gd_scene load_steps={len(ext) + len(shapes) + 1} format=3]\n\n' + "\n".join(lines)
    write(f"scenes/{fname}.tscn", text)

write("scripts/career.gd", '''extends Node
# gdlint:disable=max-line-length
# The Career: lifetime counters and medals that belong to YOU, not to one campaign slot. They are saved in
# user://mspsim_career.cfg (Campaign.save_prefix + "career.cfg"), so New Game, a deleted campaign and the end of a
# year do not reset them. The game feeds them through small hooks (Career.add / best / fastest and the note_*
# helpers); every change re-checks the MEDALS table and toasts a new medal.
#
#   Career.value("tickets")          a counter ("tk.<fix>", "pr.<printer model>", "stars.<game>", "days.<mode>" ...)
#   Career.unlocked("wall_sunset")   a cosmetic unlock (UNLOCKS): true once its medal is earned
#   Career.wallpaper_color()         the Computer desktop tint you picked
#   Career.ringtone_name()           the phone ringtone you picked
#
# MEDALS rules are lists of [counter, op, number] that must all hold; op is ">=" or "<=" (a "<=" counter must be
# set, 0 means never done). Derived counters: printer_models, stars3, days_total, tk_other.
# MEDALS and UNLOCKS are patchable text tables (story/strings.txt): title and desc are the text. Keep a desc under
# 31 characters so it fits one line on the career screen.

const SCREEN := preload("res://scripts/career_screen.gd")
const VERSION := 1
const GAMES := ["bowling", "karaoke", "escape", "dinner"]
const KNOWN_FIXES := ["password", "spooler", "clear_temp", "reboot", "av", "restore", "adobe", "network", "project"]
const MEDALS := [
    {"id": "ticket_machine", "title": "TICKET MACHINE", "desc": "CLOSE 50 TICKETS", "rules": [["tickets", ">=", 50]]},
    {"id": "help_desk_hero", "title": "HELP DESK HERO", "desc": "CLOSE 250 TICKETS", "rules": [["tickets", ">=", 250]]},
    {"id": "sticky_savior", "title": "STICKY NOTES SAVIOR", "desc": "CLOSE 10 PASSWORD TICKETS", "rules": [["tk.password", ">=", 10]]},
    {"id": "printer_whisperer", "title": "PRINTER WHISPERER", "desc": "WIN WITH EVERY PRINTER MODEL", "rules": [["printer_models", ">=", 6]]},
    {"id": "never_restarted", "title": "NEVER RESTARTED", "desc": "5 PRINTER WINS, NO PRAYERS", "rules": [["pr_streak", ">=", 5]]},
    {"id": "toner_wrangler", "title": "TONER WRANGLER", "desc": "WIN 20 PRINTER GAMES", "rules": [["printer_wins", ">=", 20]]},
    {"id": "meeting_survivor", "title": "MEETING SURVIVOR", "desc": "ATTEND 5 ALL-HANDS", "rules": [["meetings", ">=", 5]]},
    {"id": "duck_whisperer", "title": "DUCK WHISPERER", "desc": "TALK TO THE DUCK 50 TIMES", "rules": [["duck_squeaks", ">=", 50]]},
    {"id": "people_person", "title": "PEOPLE PERSON", "desc": "PLAY 3 TEAM OUTINGS", "rules": [["outings", ">=", 3]]},
    {"id": "full_house", "title": "FULL HOUSE", "desc": "3 STARS IN ALL FOUR GAMES", "rules": [["stars3", ">=", 4]]},
    {"id": "gutter_guru", "title": "GUTTER GURU", "desc": "ROLL 10 GUTTER BALLS", "rules": [["bowl_gutters", ">=", 10]]},
    {"id": "strike_zone", "title": "STRIKE ZONE", "desc": "ROLL 10 STRIKES", "rules": [["bowl_strikes", ">=", 10]]},
    {"id": "crowd_pleaser", "title": "CROWD PLEASER", "desc": "HIT 20 PERFECT KARAOKE NOTES", "rules": [["kara_perfects", ">=", 20]]},
    {"id": "vault_cracker", "title": "VAULT CRACKER", "desc": "OPEN THE VAULT IN 50 SECONDS", "rules": [["escape_best", "<=", 50]]},
    {"id": "dinner_diplomat", "title": "DINNER DIPLOMAT", "desc": "SCORE 24 AT THE TEAM DINNER", "rules": [["dinner_best", ">=", 24]]},
    {"id": "friday_warrior", "title": "FRIDAY WARRIOR", "desc": "SURVIVE 5 NERF WARS", "rules": [["nerf_wars", ">=", 5]]},
    {"id": "dead_eye", "title": "DEAD EYE", "desc": "HIT COWORKERS 30 TIMES", "rules": [["nerf_hits", ">=", 30]]},
    {"id": "long_shot", "title": "LONG SHOT", "desc": "HIT SOMEONE FROM 150 PX AWAY", "rules": [["nerf_longest", ">=", 150]]},
    {"id": "limbo_legend", "title": "LIMBO LEGEND", "desc": "DUCK 25 DARTS", "rules": [["nerf_dodges", ">=", 25]]},
    {"id": "cat_person", "title": "CAT PERSON", "desc": "PET 10 OFFICE ANIMALS", "rules": [["pets", ">=", 10]]},
    {"id": "on_hold", "title": "ON HOLD, PLEASE", "desc": "HEAR OUT 5 CLIENT COMPLAINTS", "rules": [["vic_calls", ">=", 5]]},
    {"id": "year_one", "title": "YEAR ONE", "desc": "FINISH A CAMPAIGN YEAR", "rules": [["endings", ">=", 1]]},
    {"id": "regular", "title": "REGULAR", "desc": "PLAY 20 DAYS OR WEEKS", "rules": [["days_total", ">=", 20]]},
    {"id": "corner_office", "title": "CORNER OFFICE", "desc": "RUN 10 OWNER WEEKS", "rules": [["days.owner", ">=", 10]]},
]
# cosmetic unlocks: data the rest of the game reads with unlocked(id). kind: wallpaper (value = desktop colour),
# ringtone (the phone Settings picks the name), duck and desk_toy (data only for now, no art yet).
# medal "" = always available; the first entry of a kind is its default.
const UNLOCKS := [
    {"id": "wall_standard", "kind": "wallpaper", "title": "STANDARD BLUE", "medal": "", "value": "2d6ca8"},
    {"id": "wall_sunset", "kind": "wallpaper", "title": "SUNSET ORANGE", "medal": "ticket_machine", "value": "b8683a"},
    {"id": "wall_graphite", "kind": "wallpaper", "title": "GRAPHITE", "medal": "help_desk_hero", "value": "454b58"},
    {"id": "wall_mint", "kind": "wallpaper", "title": "MINT", "medal": "printer_whisperer", "value": "3a9a84"},
    {"id": "wall_plum", "kind": "wallpaper", "title": "PLUM", "medal": "friday_warrior", "value": "6a4690"},
    {"id": "ring_classic", "kind": "ringtone", "title": "RING RING", "medal": "", "value": ""},
    {"id": "ring_dial", "kind": "ringtone", "title": "OLD DIAL TONE", "medal": "never_restarted", "value": ""},
    {"id": "ring_chime", "kind": "ringtone", "title": "WIND CHIME", "medal": "people_person", "value": ""},
    {"id": "ring_marimba", "kind": "ringtone", "title": "MARIMBA", "medal": "crowd_pleaser", "value": ""},
    {"id": "ring_quack", "kind": "ringtone", "title": "QUACK QUACK", "medal": "duck_whisperer", "value": ""},
    {"id": "duck_gold", "kind": "duck", "title": "GOLD RUBBER DUCK", "medal": "duck_whisperer", "value": ""},
    {"id": "duck_pirate", "kind": "duck", "title": "PIRATE RUBBER DUCK", "medal": "limbo_legend", "value": ""},
    {"id": "toy_stress_ball", "kind": "desk_toy", "title": "STRESS BALL", "medal": "meeting_survivor", "value": ""},
    {"id": "toy_pendulum", "kind": "desk_toy", "title": "DESK PENDULUM", "medal": "full_house", "value": ""},
]
# what the career screen lists: [section, label, counter, format]
const COUNTERS := [
    ["DESK", "TICKETS CLOSED", "tickets", "n"],
    ["", "  PASSWORDS", "tk.password", "n"],
    ["", "  PRINTERS", "tk.spooler", "n"],
    ["", "  CLEAN-UPS", "tk.clear_temp", "n"],
    ["", "  REBOOTS", "tk.reboot", "n"],
    ["", "  VIRUSES", "tk.av", "n"],
    ["", "  RESTORES", "tk.restore", "n"],
    ["", "  OTHER", "tk_other", "n"],
    ["", "TECH DAYS WORKED", "days.tech", "n"],
    ["", "OWNER WEEKS RUN", "days.owner", "n"],
    ["", "YEARS FINISHED", "endings", "n"],
    ["", "ALL-HANDS ATTENDED", "meetings", "n"],
    ["OUTINGS", "OUTINGS PLAYED", "outings", "n"],
    ["", "BOWLING BEST", "stars.bowling", "stars"],
    ["", "KARAOKE BEST", "stars.karaoke", "stars"],
    ["", "ESCAPE ROOM BEST", "stars.escape", "stars"],
    ["", "DINNER BEST", "stars.dinner", "stars"],
    ["", "STRIKES", "bowl_strikes", "n"],
    ["", "GUTTER BALLS", "bowl_gutters", "n"],
    ["", "PERFECT NOTES", "kara_perfects", "n"],
    ["", "FASTEST ESCAPE", "escape_best", "secs"],
    ["", "BEST DINNER SCORE", "dinner_best", "n"],
    ["PRINTER", "PRINTER WINS", "printer_wins", "n"],
    ["", "  LASER", "pr.laser", "n"],
    ["", "  INKJET", "pr.inkjet", "n"],
    ["", "  PLOTTER", "pr.plotter", "n"],
    ["", "  COPIER", "pr.mfp", "n"],
    ["", "  RECEIPT", "pr.receipt", "n"],
    ["", "  DOT MATRIX", "pr.dot", "n"],
    ["", "BEST NO-PRAYER RUN", "pr_streak", "n"],
    ["NERF AND OFFICE", "NERF HITS", "nerf_hits", "n"],
    ["", "DARTS DUCKED", "nerf_dodges", "n"],
    ["", "NERF WARS", "nerf_wars", "n"],
    ["", "LONGEST HIT", "nerf_longest", "px"],
    ["", "ANIMALS PETTED", "pets", "n"],
    ["", "COMPLAINTS HEARD", "vic_calls", "n"],
    ["", "DUCK CHATS", "duck_squeaks", "n"],
]
const FLUSH_SECS := 3.0

var counters := {}
var earned := {}  # medal id -> true
var prefs := {"wallpaper": "", "ringtone": ""}
var toasts := true  # tests switch the medal toast off
var last_medal := ""

var _dirty := false
var _flush_t := 0.0


func _ready() -> void:
    load_file()
    Campaign.day_started.connect(_on_day)


func path() -> String:
    return Campaign.save_prefix + "career.cfg"


# ---- save / load ------------------------------------------------------------------------------------
func load_file() -> void:
    counters = {}
    earned = {}
    prefs = {"wallpaper": "", "ringtone": ""}
    var cfg := ConfigFile.new()
    if cfg.load(path()) != OK:
        return  # no file yet (or an old build): everything starts at zero
    if cfg.has_section("counters"):
        for k in cfg.get_section_keys("counters"):
            counters[k] = int(cfg.get_value("counters", k, 0))
    if cfg.has_section("medals"):
        for k in cfg.get_section_keys("medals"):
            if bool(cfg.get_value("medals", k, false)):
                earned[k] = true
    for k in prefs:
        prefs[k] = str(cfg.get_value("prefs", k, ""))


func save_file() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("career", "version", VERSION)
    for k in counters:
        cfg.set_value("counters", k, int(counters[k]))
    for k in earned:
        cfg.set_value("medals", k, true)
    for k in prefs:
        cfg.set_value("prefs", k, str(prefs[k]))
    cfg.save(path())
    _dirty = false


func reset_all() -> void:
    counters = {}
    earned = {}
    prefs = {"wallpaper": "", "ringtone": ""}
    _dirty = true


func _process(delta: float) -> void:
    if _dirty:
        _flush_t += delta
        if _flush_t >= FLUSH_SECS:
            _flush_t = 0.0
            save_file()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty:
        save_file()


# ---- counters ---------------------------------------------------------------------------------------
func value(key: String) -> int:
    match key:
        "printer_models":
            var n := 0
            for m in PrinterGame.MODELS:
                if int(counters.get("pr." + str(m), 0)) > 0:
                    n += 1
            return n
        "stars3":
            var n := 0
            for g in GAMES:
                if int(counters.get("stars." + g, 0)) >= 3:
                    n += 1
            return n
        "days_total":
            return int(counters.get("days.tech", 0)) + int(counters.get("days.owner", 0)) + int(counters.get("days.free", 0))
        "tk_other":
            var sum := 0
            for f in ["password", "spooler", "clear_temp", "reboot", "av", "restore"]:
                sum += int(counters.get("tk." + f, 0))
            return maxi(0, int(counters.get("tickets", 0)) - sum)
    return int(counters.get(key, 0))


func add(key: String, n := 1) -> void:
    counters[key] = int(counters.get(key, 0)) + n
    _changed()


func best(key: String, v: int) -> void:
    if v > int(counters.get(key, 0)):
        counters[key] = v
        _changed()


func fastest(key: String, v: int) -> void:
    var cur := int(counters.get(key, 0))
    if v > 0 and (cur == 0 or v < cur):
        counters[key] = v
        _changed()


func _changed() -> void:
    _dirty = true
    check_medals()


# ---- the hooks the game calls --------------------------------------------------------------------------
func note_ticket(fix: String) -> void:
    counters["tickets"] = int(counters.get("tickets", 0)) + 1
    counters["tk." + fix] = int(counters.get("tk." + fix, 0)) + 1
    _changed()


# a finished outing (result 0-3, or -1 for leaving early); info: strikes, gutters, perfects, escape_secs, dinner_score
func note_outing(game: String, result: int, info := {}) -> void:
    if result < 0:
        return
    add("outings")
    best("stars." + game, result)
    match game:
        "karaoke":
            add("kara_perfects", int(info.get("perfects", 0)))
        "escape":
            if result >= 1:
                fastest("escape_best", int(info.get("secs", 0)))
        "dinner":
            best("dinner_best", int(info.get("score", 0)))


func note_bowl(knocked: int, roll: int) -> void:
    if knocked >= 10 and roll == 1:
        add("bowl_strikes")
    elif knocked == 0:
        add("bowl_gutters")


func note_printer(model: String, stars: int, prayed: bool, streak: int) -> void:
    if stars >= 1:
        add("printer_wins")
        add("pr." + model)
    best("pr_streak", streak if not prayed else 0)


func note_nerf_hit(reach: float) -> void:
    add("nerf_hits")
    best("nerf_longest", roundi(reach))


func _on_day(_d: int) -> void:
    add("days." + (Campaign.mode if Campaign.mode != "" else "free"))


# ---- medals -----------------------------------------------------------------------------------------
func rule_ok(r: Array) -> bool:
    var v := value(str(r[0]))
    var n := int(r[2])
    if str(r[1]) == "<=":
        return v > 0 and v <= n
    return v >= n


func met(m: Dictionary) -> bool:
    for r in m.rules:
        if not rule_ok(r):
            return false
    return true


func has_medal(id: String) -> bool:
    return earned.has(id)


func medal(id: String) -> Dictionary:
    for m in MEDALS:
        if str(m.id) == id:
            return m
    return {}


# award every medal whose rule now holds; returns the ids that are new
func check_medals() -> Array:
    var fresh := []
    for m in MEDALS:
        var id := str(m.id)
        if not earned.has(id) and met(m):
            earned[id] = true
            fresh.append(id)
    if not fresh.is_empty():
        last_medal = str(fresh[fresh.size() - 1])
        if toasts:
            Hints.toast("MEDAL EARNED: " + str(medal(last_medal).title), 4.0)
        save_file()
    return fresh


# progress text for a locked single-rule medal: "3/10" (empty when it has no count)
func progress(m: Dictionary) -> String:
    if m.rules.size() != 1 or str(m.rules[0][1]) != ">=":
        return ""
    return "%d/%d" % [mini(value(str(m.rules[0][0])), int(m.rules[0][2])), int(m.rules[0][2])]


func earned_count() -> int:
    var n := 0
    for m in MEDALS:
        if earned.has(str(m.id)):
            n += 1
    return n


# ---- cosmetic unlocks -------------------------------------------------------------------------------
func unlock_entry(id: String) -> Dictionary:
    for u in UNLOCKS:
        if str(u.id) == id:
            return u
    return {}


func unlocked(id: String) -> bool:
    var u := unlock_entry(id)
    if u.is_empty():
        return false
    return str(u.medal) == "" or earned.has(str(u.medal))


func unlocked_of(kind: String) -> Array:
    var out := []
    for u in UNLOCKS:
        if str(u.kind) == kind and unlocked(str(u.id)):
            out.append(u)
    return out


# the id picked for a kind (falls back to the default when the pick is not unlocked)
func pick_of(kind: String) -> Dictionary:
    var list := unlocked_of(kind)
    if list.is_empty():
        return {}
    for u in list:
        if str(u.id) == str(prefs.get(kind, "")):
            return u
    return list[0]


func cycle_pick(kind: String, step := 1) -> Dictionary:
    var list := unlocked_of(kind)
    if list.is_empty():
        return {}
    var cur := str(pick_of(kind).id)
    var at := 0
    for i in list.size():
        if str(list[i].id) == cur:
            at = i
    var nxt: Dictionary = list[posmod(at + step, list.size())]
    prefs[kind] = str(nxt.id)
    _dirty = true
    save_file()
    return nxt


func wallpaper_color() -> Color:
    var u := pick_of("wallpaper")
    return Color(str(u.value)) if not u.is_empty() and str(u.value) != "" else Color("2d6ca8")


func ringtone_name() -> String:
    var u := pick_of("ringtone")
    return str(u.title) if not u.is_empty() else "RING RING"


# ---- the screen -------------------------------------------------------------------------------------
# open the career screen on a CanvasLayer under the scene tree root; closing frees it. Returns the screen.
func open_screen(on_close := Callable()) -> Node:
    var layer := CanvasLayer.new()
    layer.layer = 70
    var screen: Node2D = SCREEN.new()
    layer.add_child(screen)
    get_tree().root.add_child(layer)
    var was_ui := Game.ui_open
    Game.ui_open = true
    screen.closed.connect(
        func() -> void:
            Game.ui_open = was_ui
            layer.queue_free()
            if on_close.is_valid():
                on_close.call()
    )
    return screen
''')

write("scripts/career_screen.gd", '''extends Node2D
# gdlint:disable=max-line-length
# The CAREER screen: lifetime counters (pages of rows) and the medal board (earned / locked with the rule hint),
# drawn with the 3x5 font in the shared UiStyle panel. Opened by Career.open_screen() from the title menu and the
# phone Settings. Left / Right (A / D) change page, Esc / Backspace go back, F9 cycles the format; the mouse can
# click the < > buttons (or the wheel) and X. Two columns when the panel is wide (368x128, 320x180), one in portrait.

signal closed

const UiStyle := preload("res://scripts/ui_style.gd")
const PixelFont := preload("res://scripts/pixelfont.gd")
const MEDAL_H := 16.0
const ROW_H := 7.0
const HEAD_ROW_H := 9.0

var page := 0
var pages: Array = []
var _built_for := Vector2.ZERO
var _btns: Array = []  # [Rect2, id]
var _hover := ""
var _born := -1


func _ready() -> void:
    _born = Engine.get_process_frames()
    Game.format_changed.connect(queue_redraw)
    queue_redraw()


func page_count() -> int:
    return pages.size()


func go(step: int) -> void:
    if pages.is_empty():
        return
    page = posmod(page + step, pages.size())
    queue_redraw()


func close() -> void:
    closed.emit()


func _input(event: InputEvent) -> void:
    if Engine.get_process_frames() == _born:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F9:
                Game.cycle_format()
            KEY_LEFT, KEY_A:
                go(-1)
            KEY_RIGHT, KEY_D:
                go(1)
            KEY_ESCAPE, KEY_BACKSPACE:
                close()
            _:
                pass
    elif event is InputEventMouseMotion:
        var h := _hit(get_viewport().get_mouse_position())
        if h != _hover:
            _hover = h
            queue_redraw()
        return
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            go(-1)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            go(1)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            click(get_viewport().get_mouse_position())
    else:
        return
    get_viewport().set_input_as_handled()


func _hit(at: Vector2) -> String:
    for b in _btns:
        if b[0].has_point(at):
            return str(b[1])
    return ""


func click(at: Vector2) -> void:
    match _hit(at):
        "prev":
            go(-1)
        "next":
            go(1)
        "back":
            close()


# ---- layout -----------------------------------------------------------------------------------------
func _body_rect(size: Vector2) -> Rect2:
    var r := UiStyle.panel_rect(size, 360.0, 124.0 if size.y < 150.0 else 400.0)
    return Rect2(r.position.x + 4.0, r.position.y + 12.0, r.size.x - 8.0, r.size.y - 21.0)


func columns(body_w: float) -> int:
    return 2 if body_w >= 290.0 else 1


# split the counter rows and the medals into pages that fit the body
func build(size: Vector2) -> void:
    var body := _body_rect(size)
    var cols := columns(body.size.x)
    pages = []
    var cap_c := int(body.size.y / ROW_H) * cols
    var items: Array = []
    for row in Career.COUNTERS:
        if str(row[0]) != "":
            items.append({"head": str(row[0])})
        items.append({"label": str(row[1]), "key": str(row[2]), "fmt": str(row[3])})
    var i := 0
    while i < items.size():
        var chunk: Array = items.slice(i, i + cap_c)
        # do not leave a section title alone at the bottom of a page
        if chunk.size() == cap_c and chunk.back().has("head"):
            chunk.pop_back()
        i += chunk.size()
        pages.append({"title": "CAREER - TOTALS", "items": chunk})
    var cap_m := maxi(1, int(body.size.y / MEDAL_H)) * cols
    var n_pages := int(ceil(float(Career.MEDALS.size()) / float(cap_m)))
    for p in n_pages:
        pages.append({"title": "CAREER - MEDALS %d/%d" % [Career.earned_count(), Career.MEDALS.size()], "medals": Career.MEDALS.slice(p * cap_m, (p + 1) * cap_m)})
    page = clampi(page, 0, maxi(0, pages.size() - 1))
    _built_for = size


func _fmt(v: int, fmt: String) -> String:
    match fmt:
        "stars":
            return "-" if v <= 0 else "%d/3" % v
        "secs":
            return "-" if v <= 0 else "%d SEC" % v
        "px":
            return "-" if v <= 0 else "%d PX" % v
    return str(v)


func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.8))
    if size != _built_for or pages.is_empty():
        build(size)
    _btns.clear()
    var pg: Dictionary = pages[page]
    var r := UiStyle.panel_rect(size, 360.0, 124.0 if size.y < 150.0 else 400.0)
    var body := UiStyle.panel(self, r, str(pg.title), "%d/%d" % [page + 1, pages.size()])
    var cols := columns(body.size.x)
    var gap := 6.0
    var colw := (body.size.x - gap * float(cols - 1)) / float(cols)
    if pg.has("items"):
        _draw_counters(pg.items, body, cols, colw, gap)
    else:
        _draw_medals(pg.medals, body, cols, colw, gap)
    UiStyle.footer(self, r, "ARROWS PAGE  ESC BACK")
    _button("prev", "<", Rect2(r.end.x - 34.0, r.end.y - 9.0, 9.0, 8.0))
    _button("next", ">", Rect2(r.end.x - 23.0, r.end.y - 9.0, 9.0, 8.0))
    _button("back", "X", Rect2(r.end.x - 12.0, r.end.y - 9.0, 9.0, 8.0))


func _button(id: String, label: String, rc: Rect2) -> void:
    _btns.append([rc, id])
    draw_rect(rc, UiStyle.GOLD if _hover == id else UiStyle.SOFT)
    UiStyle.center(self, label, rc.position.x + rc.size.x * 0.5, rc.position.y + 2.0, UiStyle.INK)


func _draw_counters(items: Array, body: Rect2, cols: int, colw: float, gap: float) -> void:
    var per_col := int(body.size.y / ROW_H)
    for i in items.size():
        var it: Dictionary = items[i]
        var cx := body.position.x + float(i / per_col) * (colw + gap)
        var cy := body.position.y + float(i % per_col) * ROW_H
        if it.has("head"):
            UiStyle.text(self, str(it.head), cx, cy, UiStyle.HEAD)
            draw_rect(Rect2(cx, cy + 6.0, colw, 1.0), UiStyle.SOFT)
            continue
        var v := Career.value(str(it.key))
        UiStyle.text(self, str(it.label), cx, cy, UiStyle.INK)
        UiStyle.right(self, _fmt(v, str(it.fmt)), cx + colw, cy, UiStyle.GOLD.darkened(0.35) if v > 0 else UiStyle.MUTED)


func _draw_medals(list: Array, body: Rect2, cols: int, colw: float, gap: float) -> void:
    var per_col := maxi(1, int(body.size.y / MEDAL_H))
    var chars := int((colw - 9.0) / 4.0)
    for i in list.size():
        var m: Dictionary = list[i]
        var x := body.position.x + float(i / per_col) * (colw + gap)
        var y := body.position.y + float(i % per_col) * MEDAL_H
        var got := Career.has_medal(str(m.id))
        if got:
            UiStyle.star(self, Vector2(x + 3.5, y + 3.0), 4.0, UiStyle.GOLD)
        else:
            draw_rect(Rect2(x, y, 7.0, 7.0), UiStyle.SOFT)
            draw_rect(Rect2(x + 1.0, y + 1.0, 5.0, 5.0), UiStyle.PANEL)
            draw_rect(Rect2(x + 2.0, y + 3.0, 3.0, 3.0), UiStyle.MUTED)
        var prog := "" if got else Career.progress(m)
        var name_chars := chars - (prog.length() + 1 if prog != "" else 0)
        UiStyle.text(self, str(m.title).substr(0, name_chars), x + 9.0, y, UiStyle.INK if got else UiStyle.MUTED)
        if prog != "":
            UiStyle.right(self, prog, x + colw, y, UiStyle.MUTED)
        UiStyle.text(self, str(m.desc).substr(0, chars), x + 9.0, y + 7.0, UiStyle.HEAD if got else UiStyle.MUTED.lightened(0.25))
''')

# format the generated scripts if gdtoolkit is installed (pip install gdtoolkit)
import shutil
import subprocess
if shutil.which("gdformat"):
    subprocess.run(["gdformat", os.path.join(ROOT, "scripts")], check=False)
    print("formatted scripts with gdformat")
# Godot only re-imports changed PNGs in the editor or an import pass; a stale import makes new sheet frames blank
GODOT_EXE = r"C:\Program Files\Godot\Godot.exe"
if os.path.exists(GODOT_EXE):
    subprocess.run([GODOT_EXE, "--headless", "--path", ROOT, "--import"], check=False, capture_output=True)
    print("re-imported assets")
print("done")
