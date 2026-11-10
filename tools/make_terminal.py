"""Retro CRT terminal (original pixel art) that replaces the wells in coding mode.
Run: python tools/make_terminal.py [preview.png]

64x64 frames (same footprint as assets/well.png, so the well's collision fits), saved as a
3-frame horizontal strip assets/terminal.png: cursor on / cursor off / a new line typed.
"""
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'terminal.png')
K = (20, 16, 26, 255)

CASE, CASE_L, CASE_D, CASE_DD = (214, 202, 172), (236, 228, 204), (172, 158, 128), (124, 112, 90)
BEZEL, BEZEL_D = (64, 64, 76), (42, 42, 52)
SCREEN, SCREEN_SCAN = (14, 44, 30), (10, 34, 24)
GLOW, GLOW_D, GLOW_L = (96, 255, 150), (50, 170, 96), (200, 255, 214)
WOOD, WOOD_L, WOOD_D, WOOD_DD = (150, 98, 52), (190, 132, 76), (110, 68, 34), (78, 46, 22)
KEY, KEY_D = (198, 188, 162), (150, 140, 116)
LED = (90, 255, 120)


def outline(im):
    w, h = im.size
    src = im.copy(); px = src.load(); out = im.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 and any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[x, y] = K
    return im


def frame(variant):
    im = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    # --- desk: top slab + two legs + cross bar
    d.rectangle((4, 45, 59, 50), fill=WOOD)
    d.line((4, 45, 59, 45), fill=WOOD_L)
    d.line((4, 50, 59, 50), fill=WOOD_D)
    for x in (12, 30, 47):
        d.point((x, 47), fill=WOOD_D)
    for lx in (7, 52):
        d.rectangle((lx, 51, lx + 4, 62), fill=WOOD_D)
        d.line((lx, 51, lx, 62), fill=WOOD)
    d.rectangle((12, 57, 51, 58), fill=WOOD_DD)

    # --- monitor case (chunky CRT, slightly rounded)
    d.rounded_rectangle((10, 3, 53, 41), radius=4, fill=CASE)
    d.line((13, 3, 50, 3), fill=CASE_L); d.line((10, 6, 10, 38), fill=CASE_L)
    d.line((53, 6, 53, 38), fill=CASE_D); d.line((13, 41, 50, 41), fill=CASE_D)
    # bezel + screen with rounded CRT corners
    d.rounded_rectangle((14, 7, 49, 33), radius=3, fill=BEZEL)
    d.line((15, 33, 48, 33), fill=BEZEL_D)
    d.rounded_rectangle((16, 9, 47, 31), radius=3, fill=SCREEN)
    for y in range(10, 31, 2):                   # scanlines
        d.line((17, y, 46, y), fill=SCREEN_SCAN)

    # screen text
    lines = [(19, 12, 34), (19, 15, 41), (21, 18, 38), (21, 21, 30)]
    if variant == 2:
        lines.append((19, 24, 36))
    for x0, y, x1 in lines:
        d.line((x0, y, x1, y), fill=GLOW_D)
        d.line((x0, y, x0 + 2, y), fill=GLOW)      # keyword-ish bright bit
    py = 27 if variant != 2 else 28
    d.line((19, py - 1, 20, py), fill=GLOW); d.line((20, py, 19, py + 1), fill=GLOW)   # ">" prompt
    if variant in (0, 2):
        d.rectangle((23, py - 1, 25, py + 1), fill=GLOW_L)                         # cursor
    d.point([(18, 11), (19, 10), (20, 10)], fill=(150, 220, 180))                   # glass glare

    # chin: vents + power led + brand plate
    for x in range(16, 27, 3):
        d.line((x, 36, x, 38), fill=CASE_DD)
    d.rectangle((44, 36, 46, 38), fill=CASE_DD); d.point((45, 37), fill=LED)
    d.rectangle((31, 36, 38, 38), fill=CASE_D)

    # --- keyboard on the desk, in front of the monitor
    d.polygon([(15, 42), (48, 42), (51, 47), (12, 47)], fill=KEY)
    d.line((12, 47, 51, 47), fill=KEY_D)
    for row, (y, x0, x1) in enumerate(((43, 17, 46), (45, 15, 48))):
        for x in range(x0, x1, 3):
            d.point((x, y), fill=KEY_D)
    d.line((24, 46, 39, 46), fill=CASE_L)        # space bar
    return outline(im)


def main():
    frames = [frame(i) for i in range(3)]
    strip = Image.new('RGBA', (64 * 3, 64), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (64 * i, 0), f)
    strip.save(OUT)
    print('wrote', OUT)
    if len(sys.argv) > 1:
        s = 4
        prev = Image.new('RGBA', (64 * 3 * s, 64 * s), (74, 140, 74, 255))
        big = strip.resize((64 * 3 * s, 64 * s), Image.NEAREST)
        prev.paste(big, (0, 0), big)
        prev.save(sys.argv[1])


if __name__ == '__main__':
    main()
