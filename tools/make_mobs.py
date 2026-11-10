"""Survival-mode mob sprites (original pixel art).  Run: python tools/make_mobs.py [preview.png]

Each mob is drawn from simple shapes on a 16x16 canvas, auto-outlined, and saved as a
2-frame strip (frame 2 = 1px bob) in assets/survival/<name>.png. Bosses reuse these
templates scaled up and tinted in-game.
"""
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'survival')
os.makedirs(OUT, exist_ok=True)
K = (24, 20, 30, 255)


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


MOBS = {}


def mob(name):
    def deco(fn):
        im, d = canvas(); fn(d); MOBS[name] = outline(im); return fn
    return deco


@mob('zombie')
def _(d):
    skin, shirt, pants = (112, 172, 92), (70, 92, 146), (66, 54, 44)
    d.rectangle((5, 1, 10, 6), fill=skin)
    d.point([(6, 3), (9, 3)], fill=(220, 40, 40)); d.line((6, 5, 9, 5), fill=(60, 90, 50))
    d.rectangle((4, 7, 11, 11), fill=shirt); d.point([(5, 10), (9, 8), (10, 11)], fill=(50, 66, 110))
    d.rectangle((1, 8, 3, 9), fill=skin); d.rectangle((12, 8, 14, 9), fill=skin)   # arms reaching out
    d.rectangle((5, 12, 6, 14), fill=pants); d.rectangle((9, 12, 10, 14), fill=pants)


@mob('skeleton')
def _(d):
    bone, dark = (232, 226, 206), (150, 140, 120)
    d.rectangle((5, 1, 10, 6), fill=bone)
    d.rectangle((6, 3, 6, 4), fill=K); d.rectangle((9, 3, 9, 4), fill=K); d.line((6, 6, 9, 6), fill=dark)
    d.line((7, 7, 7, 11), fill=bone); d.line((8, 7, 8, 11), fill=bone)
    for y in (8, 10):
        d.line((5, y, 10, y), fill=bone)
    d.line((4, 8, 4, 11), fill=bone); d.line((11, 8, 11, 11), fill=bone)
    d.line((6, 12, 5, 15), fill=bone); d.line((9, 12, 10, 15), fill=bone)
    d.arc((11, 4, 16, 13), 270, 90, fill=(150, 96, 50))                     # bow


@mob('slime')
def _(d):
    d.ellipse((1, 5, 14, 15), fill=(96, 206, 104))
    d.ellipse((3, 7, 7, 10), fill=(170, 240, 170))
    d.rectangle((5, 10, 5, 11), fill=K); d.rectangle((10, 10, 10, 11), fill=K)


@mob('bat')
def _(d):
    body, wing = (96, 64, 132), (70, 44, 102)
    d.polygon([(0, 4), (6, 7), (6, 10), (3, 9), (1, 10)], fill=wing)
    d.polygon([(15, 4), (9, 7), (9, 10), (12, 9), (14, 10)], fill=wing)
    d.ellipse((5, 5, 10, 11), fill=body)
    d.point([(5, 4), (10, 4)], fill=body)
    d.point([(6, 7), (9, 7)], fill=(240, 60, 70))


@mob('spider')
def _(d):
    body = (54, 42, 56)
    for i, y in enumerate((6, 8, 10, 12)):
        d.line((4, 8 + i // 2, 0, y - 1 + i), fill=body); d.line((11, 8 + i // 2, 15, y - 1 + i), fill=body)
    d.ellipse((4, 7, 11, 13), fill=body)
    d.ellipse((6, 3, 9, 7), fill=(74, 58, 76))
    d.point([(6, 5), (9, 5), (7, 4), (8, 4)], fill=(236, 52, 52))
    d.point([(7, 10), (8, 10)], fill=(200, 50, 60))


@mob('ghost')
def _(d):
    sheet = (232, 236, 246)
    d.ellipse((3, 1, 12, 10), fill=sheet); d.rectangle((3, 6, 12, 13), fill=sheet)
    for x in range(3, 13, 2):
        d.point((x, 13), fill=(0, 0, 0, 0)); d.point((x + 1, 14), fill=sheet)
    d.rectangle((5, 5, 6, 6), fill=K); d.rectangle((9, 5, 10, 6), fill=K)
    d.ellipse((7, 8, 8, 10), fill=(60, 60, 80))


@mob('bomber')
def _(d):
    d.ellipse((2, 4, 13, 14), fill=(44, 46, 66))
    d.ellipse((4, 6, 7, 8), fill=(110, 112, 140))
    d.line((9, 4, 11, 1), fill=(150, 100, 50)); d.point([(11, 0), (12, 1)], fill=(255, 210, 60))
    d.point([(6, 9), (9, 9)], fill=(240, 240, 240))
    d.rectangle((4, 14, 5, 15), fill=(230, 120, 40)); d.rectangle((10, 14, 11, 15), fill=(230, 120, 40))


@mob('mage')
def _(d):
    robe = (104, 62, 176)
    d.polygon([(7, 4), (12, 15), (2, 15)], fill=robe)
    d.polygon([(7, 0), (10, 4), (4, 4)], fill=(80, 44, 140))
    d.rectangle((5, 4, 9, 6), fill=(232, 186, 150)); d.point([(6, 5), (8, 5)], fill=K)
    d.line((5, 10, 9, 10), fill=(226, 190, 70))
    d.line((13, 4, 13, 15), fill=(140, 92, 50)); d.ellipse((12, 1, 15, 4), fill=(110, 230, 250))


@mob('golem')
def _(d):
    rock, dark = (134, 134, 146), (96, 96, 108)
    d.rectangle((3, 4, 12, 12), fill=rock); d.rectangle((5, 0, 10, 4), fill=rock)
    d.rectangle((0, 5, 2, 11), fill=dark); d.rectangle((13, 5, 15, 11), fill=dark)
    d.rectangle((4, 13, 6, 15), fill=dark); d.rectangle((9, 13, 11, 15), fill=dark)
    d.point([(6, 2), (9, 2)], fill=(255, 220, 80))
    d.line((5, 7, 7, 9), fill=dark); d.line((10, 6, 9, 10), fill=dark)


@mob('wolf')
def _(d):
    fur, dark = (128, 128, 138), (86, 86, 96)
    d.ellipse((2, 6, 12, 11), fill=fur)
    d.polygon([(0, 5), (3, 7), (2, 8)], fill=fur)                         # tail
    d.ellipse((10, 3, 15, 8), fill=fur); d.polygon([(11, 1), (12, 4), (10, 4)], fill=dark)
    d.point((13, 5), fill=(250, 210, 60)); d.point((15, 7), fill=K)
    for x in (3, 5, 9, 11):
        d.line((x, 10, x, 14), fill=dark)


for name, im in MOBS.items():
    strip = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    strip.alpha_composite(im, (0, 0))
    bob = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); bob.alpha_composite(im, (0, -1))
    strip.alpha_composite(bob, (16, 0))
    strip.save(os.path.join(OUT, f'{name}.png'))
print(len(MOBS), 'mobs ->', OUT)

if len(sys.argv) > 1:
    P = Image.new('RGBA', (len(MOBS) * 20 + 4, 20), (70, 110, 60, 255))
    for i, im in enumerate(MOBS.values()):
        P.alpha_composite(im, (4 + i * 20, 2))
    P.resize((P.width * 6, P.height * 6), Image.NEAREST).save(sys.argv[1])
