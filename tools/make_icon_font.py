"""Pixel icon font: 16x16 glyphs mapped onto the emoji code points the UI uses.
Output: <out>/pixel_icons.png + pixel_icons.fnt (BMFont text) — Godot imports it as a bitmap font."""
import math, os, sys
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "fonts")  # Run: python tools/make_icon_font.py [preview.png]
O = (22, 18, 32, 255)
CREAM = (246, 236, 210, 255); SHADE = (176, 160, 138, 255)
GOLD = (255, 200, 70, 255); DGOLD = (196, 128, 30, 255)
RED = (232, 72, 72, 255); DRED = (150, 36, 44, 255)
BLUE = (96, 186, 255, 255); DBLUE = (44, 104, 176, 255)
GREEN = (110, 220, 120, 255); DGREEN = (40, 130, 70, 255)
ORANGE = (255, 140, 40, 255); YEL = (255, 232, 120, 255)
PINK = (244, 150, 180, 255); BROWN = (140, 88, 46, 255); DBROWN = (96, 58, 30, 255)
GREY = (150, 156, 170, 255); DGREY = (90, 96, 110, 255); WHITE = (255, 255, 255, 255)


def new():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def outline(im):
    src = im.copy(); px = src.load(); out = im.load()
    for y in range(16):
        for x in range(16):
            if px[x, y][3] == 0 and any(0 <= x + dx < 16 and 0 <= y + dy < 16 and px[x + dx, y + dy][3] > 0
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[x, y] = O
    return im


def disc(d, cx, cy, r, c):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


I = {}

def icon(*names):
    def deco(fn):
        im, d = new(); fn(im, d); outline(im)
        for n in names:
            I[n] = im
        return fn
    return deco

@icon("search")
def _(im, d):
    d.ellipse((2, 2, 10, 10), fill=CREAM); d.ellipse((4, 4, 8, 8), fill=BLUE)
    d.line((9, 9, 13, 13), fill=GOLD, width=2)

@icon("offline")
def _(im, d):
    for i, h in enumerate((3, 6, 9)):
        d.rectangle((2 + i * 4, 13 - h, 4 + i * 4, 13), fill=GREY)
    d.line((2, 2, 13, 13), fill=RED, width=2)

@icon("doc")
def _(im, d):
    d.rectangle((3, 1, 12, 14), fill=CREAM)
    for y in (4, 7, 10):
        d.line((5, y, 10, y), fill=DBLUE)

@icon("warn")
def _(im, d):
    d.polygon([(7.5, 1), (14, 14), (1, 14)], fill=YEL)
    d.rectangle((7, 5, 8, 10), fill=O); d.rectangle((7, 12, 8, 12), fill=O)

@icon("brain")
def _(im, d):
    disc(d, 5, 8, 4, PINK); disc(d, 10, 8, 4, PINK); disc(d, 7, 5, 3, PINK)
    d.line((7, 4, 7, 12), fill=DRED); d.point([(4, 7), (10, 6), (11, 10), (4, 10)], fill=DRED)

@icon("check")
def _(im, d):
    d.rectangle((1, 1, 14, 14), fill=GREEN)
    d.line((4, 8, 7, 11), fill=CREAM, width=2); d.line((7, 11, 12, 4), fill=CREAM, width=2)

def heart(d, c):
    disc(d, 5, 6, 3, c); disc(d, 10, 6, 3, c); d.polygon([(2, 7), (13, 7), (7.5, 13)], fill=c)

@icon("heart")
def _(im, d):
    heart(d, RED); d.point([(4, 5), (5, 4)], fill=WHITE)

@icon("blueheart")
def _(im, d):
    heart(d, BLUE); d.point([(4, 5), (5, 4)], fill=WHITE)

@icon("wave")
def _(im, d):
    d.pieslice((2, 3, 14, 15), 180, 360, fill=BLUE); d.rectangle((1, 9, 14, 13), fill=DBLUE)
    disc(d, 11, 7, 2, CREAM)

@icon("fire")
def _(im, d):
    d.polygon([(7.5, 1), (12, 8), (3, 8)], fill=ORANGE); disc(d, 7, 10, 4, ORANGE)
    d.polygon([(7.5, 6), (10, 10), (5, 10)], fill=YEL); disc(d, 7, 11, 2, YEL)

@icon("sparkle")
def _(im, d):
    d.polygon(star_pts(6, 7, 6, 1.6, 4), fill=YEL); d.polygon(star_pts(12, 3, 3, 1, 4), fill=CREAM)

@icon("star")
def _(im, d):
    d.polygon(star_pts(7.5, 8, 7, 3), fill=GOLD); d.point([(6, 6), (7, 5)], fill=YEL)

@icon("cross")
def _(im, d):
    d.line((3, 3, 12, 12), fill=RED, width=3); d.line((12, 3, 3, 12), fill=RED, width=3)

@icon("hourglass")
def _(im, d):
    d.rectangle((3, 1, 12, 2), fill=BROWN); d.rectangle((3, 13, 12, 14), fill=BROWN)
    d.polygon([(4, 3), (11, 3), (7.5, 8)], fill=CREAM); d.polygon([(7.5, 8), (11, 12), (4, 12)], fill=CREAM)
    d.polygon([(6, 10), (9, 10), (10, 12), (5, 12)], fill=GOLD)

@icon("party")
def _(im, d):
    d.polygon([(2, 14), (6, 4), (12, 10)], fill=GOLD); d.line((4, 10, 8, 12), fill=RED)
    for p, c in (((11, 2), RED), ((14, 5), BLUE), ((9, 1), GREEN), ((13, 1), YEL)):
        d.rectangle((p[0], p[1], p[0] + 1, p[1] + 1), fill=c)

@icon("bolt")
def _(im, d):
    d.polygon([(9, 1), (3, 9), (7, 9), (5, 15), (12, 6), (8, 6), (10, 1)], fill=YEL)

@icon("halfmoon")
def _(im, d):
    disc(d, 7, 8, 6, CREAM); d.pieslice((1, 2, 13, 14), 90, 270, fill=DGREY)

@icon("chart")
def _(im, d):
    d.rectangle((1, 13, 14, 14), fill=CREAM)
    d.rectangle((2, 7, 4, 12), fill=BLUE); d.rectangle((6, 3, 8, 12), fill=GREEN); d.rectangle((10, 9, 12, 12), fill=GOLD)

@icon("phone")
def _(im, d):
    d.rectangle((4, 1, 11, 14), fill=DGREY); d.rectangle((5, 3, 10, 11), fill=BLUE); d.point((7, 13), fill=CREAM); d.point((8, 13), fill=CREAM)

@icon("laptop")
def _(im, d):
    d.rectangle((3, 2, 12, 9), fill=DGREY); d.rectangle((4, 3, 11, 8), fill=BLUE)
    d.line((5, 5, 7, 5), fill=GREEN); d.line((5, 7, 9, 7), fill=CREAM)
    d.rectangle((1, 10, 14, 12), fill=GREY)

@icon("bulb")
def _(im, d):
    disc(d, 7, 6, 5, YEL); d.rectangle((5, 10, 10, 13), fill=GREY); d.point([(5, 4), (6, 3)], fill=WHITE)

@icon("bucket")
def _(im, d):
    d.polygon([(2, 4), (13, 4), (11, 14), (4, 14)], fill=BROWN)
    d.line((3, 7, 12, 7), fill=GREY); d.line((4, 11, 11, 11), fill=GREY); d.rectangle((3, 4, 12, 5), fill=BLUE)
    d.arc((3, 0, 12, 8), 180, 360, fill=GREY)

@icon("trophy")
def _(im, d):
    d.polygon([(3, 1), (12, 1), (11, 7), (4, 7)], fill=GOLD); disc(d, 7, 6, 3, GOLD)
    d.rectangle((7, 9, 8, 11), fill=DGOLD); d.rectangle((4, 12, 11, 14), fill=DGOLD)
    d.point([(1, 3), (2, 4), (14, 3), (13, 4)], fill=GOLD)

@icon("compass")
def _(im, d):
    disc(d, 7, 8, 6, CREAM); d.polygon([(7.5, 3), (9, 8), (6, 8)], fill=RED); d.polygon([(7.5, 13), (9, 8), (6, 8)], fill=DBLUE)

@icon("book")
def _(im, d):
    d.rectangle((1, 3, 14, 13), fill=BROWN); d.rectangle((2, 3, 7, 12), fill=CREAM); d.rectangle((8, 3, 13, 12), fill=CREAM)
    d.line((7, 3, 7, 13), fill=DBROWN)

@icon("globe")
def _(im, d):
    disc(d, 7, 8, 6, BLUE); disc(d, 5, 6, 2, GREEN); d.rectangle((8, 9, 10, 12), fill=GREEN); d.point((10, 4), fill=GREEN)

@icon("target")
def _(im, d):
    disc(d, 7, 8, 6, RED); disc(d, 7, 8, 4, CREAM); disc(d, 7, 8, 2, RED)

@icon("pickaxe")
def _(im, d):
    d.line((4, 13, 11, 4), fill=BROWN, width=2); d.arc((2, 1, 14, 11), 200, 340, fill=GREY, width=2)

@icon("gem")
def _(im, d):
    d.polygon([(4, 2), (11, 2), (14, 6), (7.5, 14), (1, 6)], fill=BLUE); d.line((1, 6, 14, 6), fill=DBLUE)
    d.point([(5, 4), (6, 3)], fill=WHITE)

@icon("dynamite")
def _(im, d):
    d.rectangle((3, 5, 12, 13), fill=RED); d.line((3, 9, 12, 9), fill=DRED); d.line((7, 5, 9, 1), fill=GREY)
    d.point((10, 1), fill=YEL)

@icon("flask")
def _(im, d):
    d.rectangle((6, 1, 9, 5), fill=CREAM); d.polygon([(6, 5), (9, 5), (13, 14), (2, 14)], fill=CREAM)
    d.polygon([(4, 10), (11, 10), (13, 14), (2, 14)], fill=GREEN)

@icon("bars")
def _(im, d):
    d.rectangle((1, 2, 14, 14), fill=CREAM); d.rectangle((3, 9, 4, 12), fill=BLUE); d.rectangle((7, 5, 8, 12), fill=RED); d.rectangle((11, 7, 12, 12), fill=GREEN)

@icon("bug")
def _(im, d):
    d.ellipse((4, 4, 11, 14), fill=(110, 200, 90, 255)); d.line((7, 5, 7, 13), fill=(40, 110, 50, 255))
    d.ellipse((5, 1, 10, 5), fill=(40, 110, 50, 255))
    d.line((5, 1, 3, 0), fill=(40, 110, 50, 255)); d.line((10, 1, 12, 0), fill=(40, 110, 50, 255))
    for y in (6, 9, 12):
        d.line((4, y, 1, y - 1), fill=(40, 110, 50, 255)); d.line((11, y, 14, y - 1), fill=(40, 110, 50, 255))
    d.point([(6, 8), (9, 10), (6, 12)], fill=(220, 240, 120, 255))

@icon("skull")
def _(im, d):
    d.ellipse((2, 1, 13, 11), fill=CREAM); d.rectangle((4, 10, 11, 13), fill=CREAM)
    d.rectangle((4, 5, 6, 7), fill=O); d.rectangle((9, 5, 11, 7), fill=O); d.point((7, 9), fill=O)
    d.line((6, 13, 6, 12), fill=O); d.line((9, 13, 9, 12), fill=O)

@icon("swords")
def _(im, d):
    d.line((2, 2, 12, 12), fill=GREY, width=2); d.line((13, 2, 3, 12), fill=GREY, width=2)
    d.line((10, 13, 13, 10), fill=GOLD, width=2); d.line((5, 13, 2, 10), fill=GOLD, width=2)

@icon("blank")
def _(im, d):
    pass

# emoji code point -> icon
MAP = {
    0x1F50D: "search", 0x1F4F4: "offline", 0x1F4C4: "doc", 0x26A0: "warn", 0x1F9E0: "brain", 0x2705: "check",
    0x1F499: "blueheart", 0x2764: "heart", 0x1F30A: "wave", 0x1F525: "fire", 0x2728: "sparkle", 0x2B50: "star",
    0x2605: "star", 0x274C: "cross", 0x2715: "cross", 0x23F3: "hourglass", 0x231B: "hourglass", 0x1F389: "party",
    0x26A1: "bolt", 0x1F313: "halfmoon", 0x1F4CA: "bars", 0x1F4DE: "phone", 0x1F4BB: "laptop", 0x1F4A1: "bulb",
    0x1FAA3: "bucket", 0x1F3C6: "trophy", 0x1F9ED: "compass", 0x1F4D6: "book", 0x1F310: "globe", 0x1F3AF: "target",
    0x1F41B: "bug", 0x1F480: "skull", 0x2694: "swords",
    0x26CF: "pickaxe", 0x1F48E: "gem", 0x1F9E8: "dynamite", 0x1F9EA: "flask", 0x1F4C8: "chart",
}
names = sorted(set(MAP.values()))
cols = 16
rows = math.ceil(len(names) / cols)
atlas = Image.new("RGBA", (cols * 16, rows * 16), (0, 0, 0, 0))
pos = {}
for i, n in enumerate(names):
    x, y = (i % cols) * 16, (i // cols) * 16
    atlas.alpha_composite(I[n], (x, y)); pos[n] = (x, y)
atlas.save(os.path.join(OUT, "pixel_icons.png"))

lines = [
    'info face="PixelIcons" size=16 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0',
    f'common lineHeight=16 base=14 scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0',
    'page id=0 file="pixel_icons.png"',
    f'chars count={len(MAP) + 1}',
]
for cp, n in sorted(MAP.items()):
    x, y = pos[n]
    lines.append(f"char id={cp} x={x} y={y} width=16 height=16 xoffset=0 yoffset=0 xadvance=17 page=0 chnl=15")
# variation selector-16 follows many emoji: make it zero-width so it never shows a box
lines.append("char id=65039 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=0 page=0 chnl=15")
open(os.path.join(OUT, "pixel_icons.fnt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

prev = Image.new("RGBA", (atlas.width, atlas.height), (34, 40, 60, 255)); prev.alpha_composite(atlas)
if len(sys.argv) > 1:
    prev.resize((atlas.width * 4, atlas.height * 4), Image.NEAREST).save(sys.argv[1])
print(len(names), "icons,", len(MAP), "code points")
