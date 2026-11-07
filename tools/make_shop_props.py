"""Draws the desk props the NERDTHINK shop shows (roadmap S1) into godot/assets/props/shop_<id>.png.
Run:  python tools/make_shop_props.py   (then Godot --import). Each piece is a pixel map, '.' is transparent, colours come
from the PAL table. The placements (where each one sits on the player's open desk) are in godot/scripts/shop.gd (DESK)."""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "godot", "assets", "props")
O = "#17121f"


def piece(name, rows, pal):
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == w, (name, y)
        for x, ch in enumerate(row):
            if ch != ".":
                c = pal[ch].lstrip("#")
                im.putpixel((x, y), (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255))
    im.save(os.path.join(OUT, "shop_%s.png" % name))


def keyboard(name, case, key, hi):
    # same 18x5 footprint as the plain keyboard (outline, three rows), keys as a light dotted row
    rows = [
        ".oooooooooooooooo.",
        "occccccccccccccccco",
        "ockckckckckckckckco",
        "occccccccccccccccco",
        ".oooooooooooooooo.",
    ]
    rows = [r[:18] for r in rows]
    rows = [r + "." * (18 - len(r)) for r in rows]
    rows[2] = "o" + "kckckckckckckckck"[:16] + "o"
    rows[1] = "o" + "c" * 16 + "o"
    rows[3] = "o" + "cchcchcchcchcchc"[:16] + "o"
    piece(name, rows, {"o": O, "c": case, "k": key, "h": hi})


keyboard("kb_blue", "#23336b", "#6a88f0", "#3a52a8")
keyboard("kb_brown", "#4a3426", "#c89868", "#7a5a3e")
keyboard("kb_red", "#5a1e22", "#f0606a", "#8a2c34")

# the vertical mouse: 6x4 like the plain one, standing on its side (a taller grip)
piece("mouse", [
    ".oooo.",
    "ogggho",
    "oggggo",
    ".oooo.",
], {"o": O, "g": "#3a3a44", "h": "#8a8a9a"})

# a riser tray under the keyboard and the mouse
piece("riser", ["o" * 36, "t" * 36, "s" * 36], {"o": O, "t": "#a0a6b0", "s": "#5a5f68"})

# an RGB strip: near-white pixels that the stage tints and cycles
piece("rgb", ["wvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwvwv"], {"w": "#ffffff", "v": "#d8d8ff"})

# a speaker (placed twice)
piece("speakers", [
    "oooo",
    "oggo",
    "ocgo",
    "oggo",
    "oooo",
], {"o": O, "g": "#5a606c", "c": "#b8bec8"})

# a wireless headset lying on the desk
piece("headset", [
    ".oooo.",
    "obbbbo",
    "orooro",
    ".oooo.",
], {"o": O, "b": "#4f7fd0", "r": "#2a2a33"})

# a desk plant
piece("plant", [
    "..ogo..",
    ".ogGgo.",
    "ogGgGgo",
    ".ogGgo.",
    "..ogo..",
    "..opo..",
    ".oppPo.",
    ".opPPo.",
    "..ooo..",
], {"o": O, "g": "#3e8e3a", "G": "#5eb04a", "p": "#b8663f", "P": "#d88a62"})

# Newton's cradle
piece("toy", [
    "oooooooooo",
    "obbbbbbbbo",
    ".l.l.l.l.l",
    ".l.l.l.l.l",
    ".oooooooo.",
    "oowwwwwwoo",
], {"o": O, "b": "#c8ccd8", "l": "#9aa0a8", "w": "#5a3a22"})

# a wall poster: a blue sheet with a yellow star and three lines of text
piece("poster", [
    "oooooooooooo",
    "obbbbbbbbbbo",
    "obbbbyybbbbo",
    "obbbyyyybbbo",
    "obbyyyyyybbo",
    "obbbyyyybbbo",
    "obbbbyybbbbo",
    "obbbbbbbbbbo",
    "obwwwwwwwwbo",
    "obbbbbbbbbbo",
    "obwwwwwwbbbo",
    "obbbbbbbbbbo",
    "obwwwwbbbbbo",
    "obbbbbbbbbbo",
    "obbbbbbbbbbo",
    "oooooooooooo",
], {"o": O, "b": "#2a3f6a", "y": "#f2c94c", "w": "#d8dce8"})
print("shop props written to", OUT)
