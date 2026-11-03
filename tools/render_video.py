"""Record the Godot project as a video in a chosen output format.

  python tools/render_video.py --format h --seconds 10 --name main_floor_h
  python tools/render_video.py --format v --script res://tests/followcam.gd --upscale 6 --name walk_v

Formats (logical size -> render size at --upscale 6):
  wide    368x128   the original stage letterbox
  h       320x180   16:9  -> 1920x1080 (YouTube)
  v       180x320   9:16  -> 1080x1920 (phones), whole set height
  vclose  180x320   9:16 with a 2x camera zoom (shows about 90x160 of the set; characters twice as big)

How it works: Godot's movie writer records at the project's viewport size, so a temporary godot/override.cfg sets
that size for the run (deleted afterwards) and `-- --format=<name>` tells the Game autoload which camera/zoom to use.
Output: renders/<name>/f########.png at the logical size; with --upscale N a nearest-neighbour copy in
renders/<name>_x<N>/, and an .mp4 if ffmpeg is on PATH.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT_DIR = os.path.join(ROOT, "godot")
SIZES = {"wide": (368, 128), "h": (320, 180), "v": (180, 320), "vclose": (180, 320)}
GODOT_EXE = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot.exe")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--format", choices=sorted(SIZES), default="h")
    ap.add_argument("--seconds", type=float, default=10.0, help="length when no --script (the main scene is recorded)")
    ap.add_argument("--script", help="res:// path of a SceneTree script to run instead (it must quit itself)")
    ap.add_argument("--fps", type=int, default=60)
    ap.add_argument("--upscale", type=int, default=0, help="integer nearest-neighbour upscale (6 = 1080p for h)")
    ap.add_argument("--name", default=None)
    ap.add_argument("--out", default=os.path.join(ROOT, "renders"))
    a = ap.parse_args()

    w, h = SIZES[a.format]
    name = a.name or ("render_" + a.format)
    frames_dir = os.path.join(a.out, name)
    os.makedirs(frames_dir, exist_ok=True)
    cfg = os.path.join(GODOT_DIR, "override.cfg")
    with open(cfg, "w") as f:
        f.write("[display]\n\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\n" % (w, h))
    cmd = [GODOT_EXE, "--path", GODOT_DIR, "--fixed-fps", str(a.fps), "--write-movie", os.path.join(frames_dir, "f.png")]
    if a.script:
        cmd += ["-s", a.script]
    else:
        cmd += ["--quit-after", str(int(a.seconds * a.fps))]
    cmd += ["--", "--format=" + a.format]
    try:
        print(" ".join(cmd))
        subprocess.run(cmd, check=True)
    finally:
        if os.path.exists(cfg):
            os.remove(cfg)

    frames = sorted(glob.glob(os.path.join(frames_dir, "f0*.png")))
    print("recorded %d frames in %s" % (len(frames), frames_dir))
    src_dir = frames_dir
    if a.upscale > 1:
        from PIL import Image
        src_dir = os.path.join(a.out, "%s_x%d" % (name, a.upscale))
        os.makedirs(src_dir, exist_ok=True)
        for fp in frames:
            im = Image.open(fp)
            im.resize((im.width * a.upscale, im.height * a.upscale), Image.NEAREST).save(
                os.path.join(src_dir, os.path.basename(fp)))
        print("upscaled to %dx%d in %s" % (w * a.upscale, h * a.upscale, src_dir))
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        mp4 = os.path.join(a.out, name + ".mp4")
        subprocess.run([ffmpeg, "-y", "-framerate", str(a.fps), "-i", os.path.join(src_dir, "f%08d.png"),
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", mp4], check=True)
        print("encoded", mp4)
    else:
        print("ffmpeg not found: import %s/f%%08d.png as an image sequence in your editor (or install ffmpeg)." % src_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
