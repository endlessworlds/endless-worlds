"""HUD / button art (original pixel art).  Run: python tools/make_ui_art.py [preview.png]

Draws small pixel grids and saves them scaled up by whole numbers (crisp pixels at their
on-screen size):
  assets/ui/hints_bulb.png       hint bulbs, lit | unlit (HintBulb shows one half), x3
  assets/ui/hints_bulb_lit.png   the bulb you pick up on the island, x3
  assets/ui/rl_badge.png         Difficulty-AI button (brain medallion), x2
  assets/ui/tutorial_badge.png   How-to-play button (book medallion), x2
  assets/ui/joystick_base.png    joystick ring, x4
  assets/ui/joystick_knob.png    joystick knob, x4
Shapes are measured from the exact centre of the grid, so they are mirror-symmetric.
"""
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, 'assets', 'ui')
K = (24, 20, 30, 255)          # outline

YEL, LYEL, DYEL, CORE = (255, 206, 58), (255, 238, 150), (222, 146, 30), (255, 252, 226)
GLS, LGLS, DGLS = (150, 168, 198), (206, 218, 236), (104, 118, 152)
MET, LMET, DMET = (176, 180, 192), (222, 224, 232), (110, 114, 128)
GOLD, LGOLD, DGOLD = (250, 196, 60), (255, 236, 140), (176, 112, 22)
NAVY, LNAVY = (34, 40, 66), (52, 62, 98)
PINK, LPINK, DPINK = (246, 140, 176), (255, 196, 216), (196, 84, 128)
CYAN = (92, 232, 240)
PAGE, DPAGE, COVER, DCOVER = (248, 240, 220), (206, 192, 162), (188, 74, 52), (130, 44, 34)
WHITE = (255, 255, 255)


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        self.cx, self.cy = (w - 1) / 2, (h - 1) / 2

    def put(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), tuple(c[:3]) + (a,))

    def get(self, x, y):
        return self.img.getpixel((x, y))

    def sym(self, x, y, c):       # a pixel and its mirror image
        self.put(x, y, c)
        self.put(self.w - 1 - x, y, c)

    def ellipse(self, cx, cy, rx, ry, fn):
        for y in range(self.h):
            for x in range(self.w):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0:
                    c = fn(x, y, d)
                    if c:
                        self.put(x, y, c)

    def outline(self, c=K):
        src = self.img.copy()
        for y in range(self.h):
            for x in range(self.w):
                if src.getpixel((x, y))[3] == 0 and any(
                        0 <= x + dx < self.w and 0 <= y + dy < self.h and src.getpixel((x + dx, y + dy))[3] > 200
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.put(x, y, c)

    def scaled(self, k):
        return self.img.resize((self.w * k, self.h * k), Image.NEAREST)


def bulb(lit):
    g = Grid(24, 26)
    cx, cy = g.cx, 10.0
    glass, light, dark = (YEL, LYEL, DYEL) if lit else (GLS, LGLS, DGLS)

    def shade(x, y, d):
        if lit and d < 0.6:
            return light
        if y > cy + 3 and d > 0.55:
            return dark
        return glass
    g.ellipse(cx, cy, 6.6, 6.8, shade)
    for y in (16, 17):                       # neck
        for x in range(8, 12):
            g.sym(x, y, dark if y == 17 else glass)
    for y, c in ((18, LMET), (19, DMET), (20, MET), (21, DMET)):   # screw base
        for x in range(8, 12):
            g.sym(x, y, c)
    for x in range(10, 12):
        g.sym(x, 22, DMET)
    fil = DYEL if lit else DMET              # filament: two posts and a peak between them
    post = fil
    for y in range(12, 17):
        g.sym(9, y, post)
    for x, y in ((9, 11), (10, 10), (11, 11)):
        g.sym(x, y, fil)
    if not lit:                              # glint on the cold glass
        for x, y in ((7, 6), (7, 7), (8, 5)):
            g.put(x, y, WHITE)
    g.outline()
    if lit:                                  # rays, the same on both sides
        for x, y in ((0, 10), (1, 10), (3, 3), (4, 4), (2, 17), (3, 16)):
            g.sym(x, y, LYEL if (x, y) in ((1, 10), (4, 4), (3, 16)) else YEL)
        for x in (11,):
            g.sym(x, 0, LYEL)
    return g


def medallion(size=32):
    g = Grid(size, size)
    r = size / 2 - 1.0

    def ring(x, y, d):
        dist = d ** 0.5
        if dist > 1 - 1.6 / r:
            return DGOLD if y > g.cy else GOLD
        if dist > 1 - 3.0 / r:
            return LGOLD if y < g.cy else GOLD
        return LNAVY if y < g.cy - r * 0.35 else NAVY
    g.ellipse(g.cx, g.cy, r, r, ring)
    return g


# Left half of the brain (the right half is its mirror). L light, P pink, D fold / fissure.
BRAIN = ["....LLLLD",
         "..LLLPLLD",
         ".LLPDDPLD",
         ".LPDPPDPD",
         "LPPPPDPPD",
         "LPDDPPPDD",
         "PPPPDPPPD",
         "PDPPPDDPD",
         "PPDDPPPPD",
         ".PPPPDPPD",
         ".PDPPPDPD",
         "..PPDPPPD",
         "...PPPPDD"]


def rl_badge():
    g = medallion()
    for j, row in enumerate(BRAIN):
        for i, ch in enumerate(row):
            if ch != '.':
                g.sym(7 + i, 8 + j, {'L': LPINK, 'P': PINK, 'D': DPINK}[ch])
    for x, y in ((13, 21), (12, 22), (11, 23), (11, 24)):   # circuit traces out of the brain
        g.sym(x, y, CYAN)
    g.sym(10, 24, WHITE)
    return g


def tutorial_badge():
    g = medallion()
    for y in range(15, 24):                        # open book: pages, then cover underneath
        for x in range(6, 16):
            sag = 1 if x > 12 else 0
            if y >= 15 + sag:
                g.sym(x, y, PAGE if y < 22 else DPAGE)
    for x in range(6, 16):
        g.sym(x, 24, COVER)
    g.sym(5, 23, COVER)
    g.sym(5, 24, DCOVER)
    for y in range(15, 24):
        g.sym(15, y, DPAGE)                         # spine
    for y in (17, 19, 21):                         # lines of text
        for x in range(8, 13):
            g.sym(x, y, DPAGE)
    q = [".GGGG.", "GG..GG", "....GG", "...GG.", "..GG..", "......", "..GG.."]   # gold "?" above the book
    for j, row in enumerate(q):
        for i, ch in enumerate(row):
            if ch == 'G':
                g.put(13 + i, 5 + j, LGOLD if j < 2 else GOLD)
    return g


def joystick_base():
    g = Grid(50, 50)
    r = 24.0

    def fill(x, y, d):
        dist = d ** 0.5
        if dist > 1 - 1.2 / r:
            return (240, 240, 250)
        if dist > 1 - 2.4 / r:
            return (120, 128, 156)
        return None
    g.ellipse(g.cx, g.cy, r, r, fill)
    for y in range(g.h):                           # dark glass inside the ring
        for x in range(g.w):
            if g.get(x, y)[3] == 0 and ((x - g.cx) ** 2 + (y - g.cy) ** 2) ** 0.5 < r - 2.2:
                g.put(x, y, (18, 22, 38), 150)
    chev = [(0, 0), (-1, 1), (1, 1), (-2, 2), (2, 2)]   # arrow tips pointing out on 4 sides
    for dx, dy in chev:
        for i in (0, 1):                           # 2 px wide (the grid centre is between pixels)
            g.put(24 + i + dx, 4 + dy, (240, 240, 250))
            g.put(24 + i + dx, 45 - dy, (240, 240, 250))
            g.put(4 + dy, 24 + i + dx, (240, 240, 250))
            g.put(45 - dy, 24 + i + dx, (240, 240, 250))
    return g


def joystick_knob():
    g = Grid(24, 24)

    def knob(x, y, d):
        if d > 0.72:
            return (150, 156, 180) if y > g.cy else (214, 218, 232)
        return (200, 204, 222) if y > g.cy + 3 else (236, 238, 246)
    g.ellipse(g.cx, g.cy, 10.4, 10.4, knob)
    for x, y in ((6, 8), (6, 7), (7, 6), (8, 5), (9, 5), (7, 7)):   # shine
        g.put(x, y, WHITE)
    g.outline()
    return g


def main():
    lit, off = bulb(True), bulb(False)
    sheet = Image.new('RGBA', (lit.w * 2, lit.h), (0, 0, 0, 0))
    sheet.paste(lit.img, (0, 0))
    sheet.paste(off.img, (lit.w, 0))
    out = {
        'hints_bulb.png': sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST),
        'hints_bulb_lit.png': lit.scaled(3),
        'rl_badge.png': rl_badge().scaled(2),
        'tutorial_badge.png': tutorial_badge().scaled(2),
        'joystick_base.png': joystick_base().scaled(4),
        'joystick_knob.png': joystick_knob().scaled(4),
    }
    for name, im in out.items():
        im.save(os.path.join(UI, name))
    if len(sys.argv) > 1:                          # preview sheet on a grass-green background
        pad = 16
        W = sum(im.width for im in out.values()) + pad * (len(out) + 1)
        H = max(im.height for im in out.values()) + pad * 2
        pv = Image.new('RGBA', (W, H), (70, 110, 70, 255))
        x = pad
        for im in out.values():
            pv.paste(im, (x, pad), im)
            x += im.width + pad
        pv.save(sys.argv[1])
    print('wrote', ', '.join(out))


if __name__ == '__main__':
    main()
