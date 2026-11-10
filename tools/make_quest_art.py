"""Coding-quest item sprites (original pixel art).  Run: python tools/make_quest_art.py [preview.png]

Each item is drawn on a 16x16 canvas, auto-outlined, and saved to assets/quest/<name>.png.
The coding popup composes them into little "recipe" illustrations (coal + stick -> torch,
ore -> gems, water + magic -> potion) so short questions get a picture to go with them.
"""
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'quest')
os.makedirs(OUT, exist_ok=True)
K = (24, 20, 30, 255)

WOOD, DWOOD, LWOOD = (168, 112, 58), (112, 70, 34), (206, 152, 92)
STONE, DSTONE, LSTONE = (128, 130, 140), (88, 90, 102), (164, 166, 176)
IRON, DIRON, LIRON = (196, 200, 210), (130, 136, 150), (236, 238, 244)
GOLD, DGOLD, LGOLD = (250, 196, 60), (190, 128, 26), (255, 236, 140)
DIA, DDIA, LDIA = (92, 222, 230), (36, 150, 170), (200, 252, 255)
EME, DEME, LEME = (70, 206, 110), (24, 130, 64), (170, 250, 190)
COAL, DCOAL, LCOAL = (58, 58, 66), (32, 32, 38), (98, 98, 110)
RED, DRED = (220, 64, 64), (150, 34, 44)
FIRE, LFIRE = (255, 140, 40), (255, 230, 120)
WHITE, CREAM, SHADE = (255, 255, 255), (244, 238, 222), (196, 188, 170)
BLUE, DBLUE, LBLUE = (80, 160, 255), (40, 96, 196), (170, 214, 255)
PURP, DPURP, LPURP = (176, 96, 236), (112, 50, 170), (230, 190, 255)
GLASS = (210, 232, 246)


def canvas():
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def outline(im):
    src = im.copy(); px = src.load(); out = im.load()
    for y in range(16):
        for x in range(16):
            if px[x, y][3] == 0 and any(0 <= x + dx < 16 and 0 <= y + dy < 16 and px[x + dx, y + dy][3]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[x, y] = K
    return im


ITEMS = {}


def item(name, outlined=True):
    def deco(fn):
        im, d = canvas(); fn(d)
        ITEMS[name] = outline(im) if outlined else im
        return fn
    return deco


def diag(d, x0, y0, n, c, w=1):
    """Diagonal bar going up-right from (x0, y0) for n pixels."""
    for i in range(n):
        d.rectangle((x0 + i, y0 - i - (w - 1), x0 + i, y0 - i), fill=c)


# ---------------------------------------------------------------- raw materials
@item('stick')
def _(d):
    for i in range(10):
        d.point((3 + i, 12 - i), fill=WOOD); d.point((4 + i, 12 - i), fill=DWOOD)
    d.point([(5, 10), (9, 6)], fill=LWOOD)


@item('coal')
def _(d):
    d.polygon([(4, 6), (8, 3), (12, 5), (13, 10), (9, 13), (4, 12), (3, 9)], fill=COAL)
    d.polygon([(8, 9), (12, 8), (13, 10), (9, 13)], fill=DCOAL)
    d.point([(6, 6), (7, 5), (10, 6), (5, 9)], fill=LCOAL)


@item('iron')
def _(d):   # ingot
    d.polygon([(2, 9), (6, 5), (14, 5), (14, 8), (10, 12), (2, 12)], fill=IRON)
    d.polygon([(2, 9), (6, 5), (14, 5), (10, 9)], fill=LIRON)
    d.polygon([(10, 9), (14, 5), (14, 8), (10, 12)], fill=DIRON)
    d.line((3, 11, 9, 11), fill=DIRON)


@item('gold')
def _(d):   # nugget pile
    d.ellipse((2, 7, 9, 13), fill=GOLD); d.ellipse((7, 4, 13, 10), fill=GOLD); d.ellipse((8, 9, 14, 14), fill=DGOLD)
    d.point([(4, 8), (9, 5), (10, 6), (5, 9)], fill=LGOLD)


def gem(d, c, dc, lc):
    d.polygon([(3, 6), (6, 3), (10, 3), (13, 6), (8, 13)], fill=c)
    d.polygon([(3, 6), (13, 6), (8, 13)], fill=dc)
    d.polygon([(6, 6), (10, 6), (8, 12)], fill=c)
    d.line((6, 4, 9, 4), fill=lc); d.point([(5, 5), (7, 7)], fill=lc)


@item('diamond')
def _(d): gem(d, DIA, DDIA, LDIA)


@item('emerald')
def _(d):
    d.polygon([(8, 1), (12, 5), (12, 11), (8, 15), (4, 11), (4, 5)], fill=EME)
    d.polygon([(8, 8), (12, 11), (8, 15), (4, 11)], fill=DEME)
    d.rectangle((6, 4, 7, 8), fill=LEME); d.point((9, 4), fill=LEME)


@item('string')
def _(d):   # spool of thread
    d.rectangle((4, 3, 12, 4), fill=WOOD); d.rectangle((4, 12, 12, 13), fill=WOOD)
    d.rectangle((5, 5, 11, 11), fill=CREAM)
    for y in (6, 8, 10):
        d.line((5, y, 11, y), fill=SHADE)
    d.line((11, 9, 14, 14), fill=CREAM)


@item('plank')
def _(d):
    d.rectangle((1, 4, 14, 12), fill=WOOD)
    d.line((1, 8, 14, 8), fill=DWOOD)
    d.line((1, 4, 14, 4), fill=LWOOD)
    d.point([(4, 6), (11, 10), (8, 6)], fill=DWOOD)
    d.point([(3, 6), (12, 10)], fill=K)


@item('wool')
def _(d):
    for cx, cy in ((5, 7), (10, 6), (7, 11), (11, 11), (4, 11)):
        d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=CREAM)
    d.point([(5, 5), (10, 4), (8, 9)], fill=WHITE)
    d.point([(6, 13), (12, 13), (13, 9)], fill=SHADE)


@item('water')
def _(d):   # flask of water
    d.rectangle((6, 1, 9, 2), fill=WOOD)
    d.rectangle((6, 3, 9, 5), fill=GLASS)
    d.ellipse((2, 5, 13, 15), fill=GLASS)
    d.chord((2, 5, 13, 15), 10, 170, fill=BLUE)
    d.line((4, 11, 11, 11), fill=LBLUE)
    d.point([(4, 8), (5, 7)], fill=WHITE)


@item('magic')
def _(d):   # sparkle orb
    d.ellipse((3, 3, 12, 12), fill=PURP)
    d.ellipse((5, 5, 10, 10), fill=LPURP)
    d.point([(6, 6)], fill=WHITE)
    d.line((7, 0, 7, 2), fill=GOLD); d.line((7, 13, 7, 15), fill=GOLD)
    d.line((0, 7, 2, 7), fill=GOLD); d.line((13, 7, 15, 7), fill=GOLD)
    d.point([(13, 2), (2, 13)], fill=LGOLD)


# ---------------------------------------------------------------- crafted results
@item('torch')
def _(d):
    d.rectangle((7, 7, 8, 15), fill=WOOD); d.line((8, 7, 8, 15), fill=DWOOD)
    d.rectangle((6, 5, 9, 7), fill=COAL)
    d.polygon([(7, 0), (10, 3), (9, 5), (6, 5), (5, 3)], fill=FIRE)
    d.rectangle((7, 2, 8, 4), fill=LFIRE)


@item('sword')
def _(d):
    for i in range(9):            # blade
        d.point((6 + i, 9 - i), fill=IRON); d.point((7 + i, 9 - i), fill=LIRON); d.point((6 + i, 10 - i), fill=DIRON)
    d.line((3, 9, 7, 13), fill=DWOOD); d.line((4, 9, 7, 12), fill=WOOD)   # guard
    diag(d, 1, 15, 4, WOOD); d.point((1, 15), fill=GOLD)                   # grip + pommel


@item('pickaxe')
def _(d):
    for i in range(11):
        d.point((2 + i, 15 - i), fill=WOOD); d.point((3 + i, 15 - i), fill=DWOOD)
    d.arc((3, 1, 15, 13), 200, 340, fill=DIA, width=2)
    d.point([(5, 4), (6, 3)], fill=LDIA); d.point([(13, 9), (14, 10)], fill=DDIA)


@item('bow')
def _(d):
    d.arc((0, 1, 12, 15), 270, 90, fill=WOOD, width=2)
    d.arc((1, 2, 11, 14), 300, 60, fill=LWOOD)
    d.line((6, 2, 6, 14), fill=CREAM)
    d.line((2, 8, 13, 8), fill=DWOOD); d.polygon([(13, 6), (15, 8), (13, 10)], fill=IRON)
    d.point([(1, 7), (1, 9), (2, 7), (2, 9)], fill=WHITE)


@item('bed')
def _(d):
    d.rectangle((1, 8, 14, 12), fill=RED); d.rectangle((1, 11, 14, 12), fill=DRED)
    d.rectangle((1, 6, 4, 10), fill=CREAM); d.point((2, 7), fill=WHITE)
    d.rectangle((0, 4, 1, 14), fill=WOOD); d.rectangle((14, 8, 15, 14), fill=WOOD)
    d.line((5, 9, 13, 9), fill=(240, 110, 110))


@item('potion')
def _(d):
    d.rectangle((6, 0, 9, 2), fill=WOOD)
    d.rectangle((6, 3, 9, 5), fill=GLASS)
    d.ellipse((2, 5, 13, 15), fill=GLASS)
    d.chord((2, 5, 13, 15), 350, 190, fill=PURP)
    d.line((4, 10, 11, 10), fill=LPURP)
    d.point([(5, 12), (9, 13), (10, 11)], fill=LPURP)
    d.point([(4, 8), (5, 7)], fill=WHITE)


# ---------------------------------------------------------------- ore blocks
def ore(name, c, lc):
    @item('ore_' + name)
    def _(d):
        d.rectangle((1, 1, 14, 14), fill=STONE)
        d.line((1, 1, 14, 1), fill=LSTONE); d.line((1, 14, 14, 14), fill=DSTONE); d.line((14, 1, 14, 14), fill=DSTONE)
        d.point([(3, 9), (11, 3), (8, 12)], fill=DSTONE)
        for x, y in ((3, 3), (9, 5), (5, 9), (11, 10)):
            d.rectangle((x, y, x + 1, y + 1), fill=c); d.point((x, y), fill=lc)
    return _


ore('diamond', DIA, LDIA)
ore('gold', GOLD, LGOLD)
ore('iron', (214, 168, 126), (240, 210, 180))
ore('coal', COAL, LCOAL)
ore('emerald', EME, LEME)


def main():
    for name, im in ITEMS.items():
        im.save(os.path.join(OUT, name + '.png'))
    print('wrote', len(ITEMS), 'sprites to', OUT)
    if len(sys.argv) > 1:
        names = list(ITEMS)
        s = 8
        sheet = Image.new('RGBA', (len(names) * 18 * s, 18 * s), (44, 48, 70, 255))
        for i, n in enumerate(names):
            big = ITEMS[n].resize((16 * s, 16 * s), Image.NEAREST)
            sheet.paste(big, (i * 18 * s + s, s), big)
        sheet.save(sys.argv[1])


if __name__ == '__main__':
    main()
