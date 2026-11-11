"""Survival-mode mob sprites (original pixel art, 16x16 and 24x24).  Run: python tools/make_mobs.py [preview.png]

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


# ---------------------------------------------------------------- 24x24, 2 real animation frames
# Newer mobs (and redrawn zombie / skeleton / slime). The slime is drawn pale so the game
# can tint each one a different colour. mob.gd scales sprites by their frame height.
S = 24

def canvas_hd():
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)

def outline_hd(im):
    src = im.copy(); px = src.load(); out = im.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3] == 0 and any(0 <= x + dx < S and 0 <= y + dy < S and px[x + dx, y + dy][3] > 60
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[x, y] = K
    return im

def zombie(d, f):
    skin, skin_d, skin_l = (118, 150, 104), (82, 110, 76), (150, 178, 132)
    shirt, shirt_d = (78, 70, 92), (54, 48, 66)
    pants, pants_d = (60, 66, 84), (42, 46, 60)
    # legs (shambling)
    lx = (0, 1) if f == 0 else (1, 0)
    d.rectangle((8 + lx[0], 17, 10 + lx[0], 22), fill=pants); d.rectangle((8 + lx[0], 21, 10 + lx[0], 22), fill=pants_d)
    d.rectangle((13 - lx[1], 17, 15 - lx[1], 22), fill=pants); d.rectangle((13 - lx[1], 21, 15 - lx[1], 22), fill=pants_d)
    d.point([(9 + lx[0], 18), (14 - lx[1], 19)], fill=skin_d)            # torn knees
    # torso, hunched forward
    d.rectangle((7, 10, 16, 17), fill=shirt)
    d.rectangle((7, 15, 16, 17), fill=shirt_d)
    d.point([(9, 12), (14, 14), (11, 16), (15, 11)], fill=shirt_d)        # rips
    d.point([(10, 13), (13, 11)], fill=skin_d)                            # skin through rips
    # arms reaching forward (right), one lower
    ay = 0 if f == 0 else 1
    d.rectangle((15, 11 + ay, 21, 12 + ay), fill=skin); d.point((21, 13 + ay), fill=skin_d)
    d.rectangle((14, 14 - ay, 20, 15 - ay), fill=skin_d); d.point((20, 16 - ay), fill=skin_d)
    # head, tilted
    d.rectangle((9, 3, 16, 10), fill=skin)
    d.rectangle((9, 9, 16, 10), fill=skin_d); d.line((9, 3, 16, 3), fill=skin_l)
    d.rectangle((11, 5, 12, 6), fill=(30, 22, 30)); d.point((12, 5), fill=(250, 196, 70))  # sunken glowing eyes
    d.rectangle((14, 5, 15, 6), fill=(30, 22, 30)); d.point((15, 5), fill=(250, 196, 70))
    d.line((12, 8, 15, 8), fill=(60, 30, 36)); d.point([(13, 9)], fill=(214, 208, 190))   # jaw, tooth
    d.point([(10, 2), (12, 2), (14, 2)], fill=(52, 44, 40))              # thin hair

def slime(d, f):
    body, shade, hi = (232, 232, 236, 215), (176, 178, 190, 225), (255, 255, 255, 240)
    if f == 0:
        d.ellipse((3, 8, 20, 22), fill=body); d.rectangle((3, 16, 20, 22), fill=body)
        d.ellipse((4, 16, 19, 23), fill=shade); d.rectangle((5, 15, 18, 19), fill=body)
        d.ellipse((6, 10, 10, 13), fill=hi); d.point((11, 10), fill=hi)
        ey = 13
    else:
        d.ellipse((1, 11, 22, 22), fill=body); d.rectangle((1, 17, 22, 22), fill=body)
        d.ellipse((2, 18, 21, 23), fill=shade); d.rectangle((3, 16, 20, 20), fill=body)
        d.ellipse((5, 13, 9, 15), fill=hi)
        ey = 15
    d.rectangle((7, ey, 9, ey + 2), fill=K); d.rectangle((14, ey, 16, ey + 2), fill=K)
    d.point([(7, ey), (14, ey)], fill=(255, 255, 255))
    d.line((10, ey + 4, 13, ey + 4), fill=(90, 90, 100, 220))

def skeleton(d, f):
    bone, bone_d, dark = (236, 230, 212), (178, 170, 150), (40, 32, 40)
    lx = 0 if f == 0 else 1
    d.line((10 - lx, 16, 9 - lx, 22), fill=bone); d.line((13 + lx, 16, 14 + lx, 22), fill=bone)
    d.point([(8 - lx, 22), (15 + lx, 22)], fill=bone_d)
    d.line((11, 10, 11, 16), fill=bone_d); d.line((12, 10, 12, 16), fill=bone)       # spine
    for y in (11, 13):
        d.line((8, y, 15, y), fill=bone); d.point([(8, y + 1), (15, y + 1)], fill=bone_d)
    d.rectangle((9, 15, 14, 16), fill=bone)                                           # pelvis
    d.line((7, 11, 6, 16), fill=bone)                                                 # left arm
    d.line((16, 11, 18, 13 + lx), fill=bone)                                          # bow arm
    d.arc((15, 5, 23, 21), 280, 80, fill=(152, 98, 52), width=1)                      # bow
    d.line((21, 6, 21, 20), fill=(220, 220, 220, 160))                                # string
    d.rectangle((8, 2, 15, 8), fill=bone); d.rectangle((9, 8, 14, 9), fill=bone_d)    # skull + jaw
    d.rectangle((9, 4, 10, 6), fill=dark); d.rectangle((13, 4, 14, 6), fill=dark)
    d.point([(9, 5), (13, 5)], fill=(220, 60, 60)); d.point((11, 7), fill=dark)
    d.point([(10, 9), (12, 9)], fill=dark)

def eye(d, f):
    w = (244, 240, 236); vein = (200, 40, 50); iris = (60, 150, 230)
    tx = 0 if f == 0 else 1
    for i, y in enumerate((11, 13, 15)):   # trailing tendrils (left)
        d.line((5, y, 1 + (i + tx) % 2, y + (1 if (i + tx) % 2 else -1)), fill=(150, 30, 40))
        d.point((0 + (i + tx) % 2, y + (2 if (i + tx) % 2 else -2)), fill=(110, 20, 30))
    d.ellipse((4, 4, 21, 21), fill=w)
    d.ellipse((5, 14, 20, 21), fill=(214, 206, 204))
    d.line((5, 9, 9, 11), fill=vein); d.line((6, 16, 10, 14), fill=vein); d.line((14, 5, 13, 9), fill=vein)
    d.line((8, 19, 11, 16), fill=vein)
    d.ellipse((11, 8, 19, 16), fill=iris); d.ellipse((12, 9, 18, 15), fill=(40, 110, 190))
    d.ellipse((14, 10, 17, 14), fill=K); d.point((13, 9), fill=(255, 255, 255))

def hornet(d, f):
    yel, yel_d, blk = (250, 196, 40), (196, 140, 20), (36, 28, 30)
    wing = (210, 236, 255, 150)
    if f == 0:
        d.ellipse((6, 1, 13, 9), fill=wing); d.ellipse((11, 0, 18, 8), fill=wing)
    else:
        d.ellipse((4, 4, 12, 10), fill=wing); d.ellipse((12, 3, 20, 9), fill=wing)
    d.ellipse((3, 10, 14, 19), fill=yel)                                  # abdomen
    for x in (5, 8, 11):
        d.line((x, 10, x, 19), fill=blk)
    d.polygon([(2, 15), (0, 17), (3, 17)], fill=blk)                      # stinger
    d.ellipse((12, 9, 17, 15), fill=yel_d)                                # thorax
    d.ellipse((16, 8, 22, 14), fill=yel)                                  # head
    d.point([(20, 10), (19, 10)], fill=(220, 30, 40)); d.line((20, 8, 22, 5), fill=blk)
    d.line((13, 15, 12, 19), fill=blk); d.line((15, 15, 16, 19), fill=blk)

def slime_king(d, f):
    slime(d, f)
    y = 6 if f == 0 else 9
    gold, gold_d = (255, 206, 60), (200, 140, 30)
    d.rectangle((7, y, 16, y + 3), fill=gold); d.line((7, y + 3, 16, y + 3), fill=gold_d)
    for x in (7, 11, 15):
        d.polygon([(x, y), (x + 1, y - 3), (x + 2, y)], fill=gold)
    d.point([(9, y + 1), (13, y + 1)], fill=(220, 50, 70)); d.point((11, y + 1), fill=(80, 170, 255))

HD = {'zombie': zombie, 'slime': slime, 'skeleton': skeleton, 'eye': eye, 'hornet': hornet, 'slime_king': slime_king}

def build():
    out = {}
    for name, fn in HD.items():
        strip = Image.new('RGBA', (S * 2, S), (0, 0, 0, 0))
        for f in range(2):
            im, d = canvas_hd(); fn(d, f); outline_hd(im)
            strip.alpha_composite(im, (f * S, 0))
        out[name] = strip
    return out


for name, im in MOBS.items():
    strip = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    strip.alpha_composite(im, (0, 0))
    bob = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); bob.alpha_composite(im, (0, -1))
    strip.alpha_composite(bob, (16, 0))
    strip.save(os.path.join(OUT, f'{name}.png'))
for name, strip in build().items():
    strip.save(os.path.join(OUT, f'{name}.png'))
print(len(MOBS) + len(HD), 'mobs ->', OUT)

if len(sys.argv) > 1:
    P = Image.new('RGBA', (len(MOBS) * 20 + 4, 20), (70, 110, 60, 255))
    for i, im in enumerate(MOBS.values()):
        P.alpha_composite(im, (4 + i * 20, 2))
    P.resize((P.width * 6, P.height * 6), Image.NEAREST).save(sys.argv[1])
