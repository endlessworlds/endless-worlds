"""Bolt, the helper robot (original pixel art).  Run: python tools/make_bot.py [preview.png]

Writes assets/agentic_bot.png: 6 columns x 5 rows of 48x48 frames, saved at x2 (96 px), the
layout ai/agentic_bot.gd expects:
  row 0 idle (blink, antenna pulse)   row 1 talking (mouth + chest waveform)
  row 2 thinking (hand to chin)       row 3 happy (^^ eyes, hop)      row 4 waving

Three-quarter view: Bolt is turned a little to his left, so the head and body show a front
face, a darker right side face and a lit top face (light comes from the top-left). Navy body,
cyan screen-face and lights, gold trim to match the HUD badges.
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_ui_art import Grid, GOLD, LGOLD, DGOLD, WHITE  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAVY, LNAVY, TOP, SIDE, DNAVY = (44, 54, 96), (66, 80, 132), (118, 138, 200), (28, 34, 64), (20, 24, 46)
SCREEN, GLARE = (12, 16, 30), (60, 84, 120)
CYAN, LCYAN, DCYAN = (80, 232, 246), (200, 252, 255), (30, 140, 170)
METAL, DMETAL, LMETAL, FAR = (150, 158, 182), (96, 102, 128), (206, 212, 230), (88, 94, 120)
LEDS = [(255, 92, 92), (255, 210, 70), (110, 230, 110), (80, 232, 246)]


def rect(g, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g.put(x, y, c)


def box(g, x0, y0, x1, y1, depth, front, top, side, rim=None, rim_side=None):
    """A box in 3/4 view: front face x0..x1 / y0..y1, a top face and a right side face
    `depth` px deep that climb up-right (one row per two columns)."""
    for k in range(depth):                      # side face, each column a little higher
        lift = (k + 2) // 2
        for y in range(y0 - lift, y1 - lift + 1):
            c = rim_side if (rim_side and y >= y1 - lift - 1) else side
            g.put(x1 + 1 + k, y, c)
    for r in range(1, (depth + 1) // 2 + 1):    # top face rows
        for x in range(x0 + 2 * r - 1, x1 + 2 * r):
            g.put(x, y0 - r, top)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = rim if (rim and y >= y1 - 1) else front
            if x == x0 and y0 < y < y1 - 1:
                c = LNAVY if c == front else c     # lit left edge
            g.put(x, y, c)
    g.put(x0, y0, (0, 0, 0, 0)[:3], 0)          # soft cut corners
    g.put(x0, y1, (0, 0, 0, 0)[:3], 0)


def arm_down(g, x, dy, far=False):
    m, l = (FAR, METAL) if far else (METAL, LMETAL)
    for y in range(28, 35):
        g.put(x, y + dy, DMETAL if y % 3 == 0 else m)
        g.put(x + 1, y + dy, DMETAL if y % 3 == 0 else l)
    for dx in (-1, 0, 1, 2):
        g.put(x + dx, 35 + dy, m)
    g.put(x - 1, 36 + dy, DMETAL)
    g.put(x + 2, 36 + dy, DMETAL)


def arm_path(g, pts, dy, far=False):
    m, l = (FAR, METAL) if far else (METAL, LMETAL)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            g.put(x, y + dy, m)
            g.put(x + 1, y + dy, l)
    ex, ey = pts[-1]
    for dx in (-1, 0, 1, 2):
        g.put(ex + dx, ey - 1 + dy, m)
    g.put(ex - 1, ey - 2 + dy, DMETAL)
    g.put(ex + 2, ey - 2 + dy, DMETAL)


def bot(face='neutral', mouth=None, wave=0, arm=None, dy=0, glow=1, chest=1):
    g = Grid(48, 48)
    for x in range(11, 38):                     # ground shadow (stays put while he hops)
        g.put(x, 46, (0, 0, 0), 75 if 15 <= x <= 33 else 35)
    # far arm first (behind the body), unless it is the waving / raised one
    if not wave and arm != 'up':
        arm_down(g, 33, dy - 1, far=True)
    # legs: far leg darker and a touch higher
    rect(g, 24, 38 + dy, 26, 43 + dy, FAR)
    rect(g, 23, 44 + dy, 28, 45 + dy, DNAVY)
    rect(g, 16, 39 + dy, 18, 43 + dy, DMETAL)
    rect(g, 17, 39 + dy, 17, 43 + dy, METAL)
    rect(g, 14, 44 + dy, 20, 45 + dy, DNAVY)
    rect(g, 15, 44 + dy, 19, 44 + dy, NAVY)
    # body
    box(g, 14, 27 + dy, 29, 38 + dy, 4, NAVY, TOP, SIDE, rim=DNAVY, rim_side=DNAVY)
    for x in range(15, 30):
        g.put(x, 27 + dy, GOLD)                  # gold shoulder trim
    for k in range(4):
        g.put(30 + k, 26 + dy - (k + 2) // 2, DGOLD)
    rect(g, 17, 29 + dy, 26, 33 + dy, SCREEN)
    wave_h = {0: [0] * 10, 1: [0, 1, 0, 1, 1, 0, 1, 0, 1, 0], 2: [1, 2, 0, 2, 1, 2, 2, 1, 2, 0]}[chest]
    for i, h in enumerate(wave_h):
        g.put(17 + i, 31 + dy, CYAN)
        for k in range(1, h + 1):
            g.put(17 + i, 31 + dy - k, DCYAN)
            g.put(17 + i, 31 + dy + k, DCYAN)
    for i, c in enumerate(LEDS):
        g.put(18 + i * 2 + (i // 2), 35 + dy, c)
    # neck
    rect(g, 19, 24 + dy, 24, 25 + dy, DMETAL)
    rect(g, 19, 24 + dy, 22, 24 + dy, METAL)
    # head
    box(g, 12, 9 + dy, 31, 23 + dy, 5, NAVY, TOP, SIDE, rim=GOLD, rim_side=DGOLD)
    rect(g, 10, 13 + dy, 11, 18 + dy, GOLD)      # near ear pod
    rect(g, 10, 14 + dy, 10, 17 + dy, LGOLD)
    rect(g, 36, 10 + dy, 37, 15 + dy, DGOLD)     # far ear pod, on the side face
    rect(g, 15, 11 + dy, 28, 20 + dy, SCREEN)
    for x, y in ((25, 12), (26, 12), (27, 13)):  # glare on the screen glass
        g.put(x, y + dy, GLARE)
    # antenna on the middle of the top face
    rect(g, 24, 3 + dy, 24, 6 + dy, METAL)
    rect(g, 25, 4 + dy, 25, 6 + dy, DMETAL)
    tip = [DCYAN, CYAN, LCYAN][glow]
    rect(g, 23, 0 + dy, 25, 2 + dy, tip)
    if glow == 2:
        g.put(22, 1 + dy, DCYAN)
        g.put(26, 1 + dy, DCYAN)
    # eyes (looking a little to his left, towards the player's view)
    ey = 13 + dy
    eyes = (16, 23)
    if face == 'neutral':
        for ex in eyes:
            rect(g, ex, ey, ex + 3, ey + 2, CYAN)
            g.put(ex, ey, LCYAN)
            g.put(ex + 3, ey + 2, DCYAN)
    elif face == 'blink':
        for ex in eyes:
            rect(g, ex, ey + 2, ex + 3, ey + 2, CYAN)
    elif face == 'happy':
        for ex in eyes:
            g.put(ex, ey + 2, CYAN); g.put(ex + 1, ey + 1, CYAN); g.put(ex + 2, ey + 1, CYAN); g.put(ex + 3, ey + 2, CYAN)
    elif face in ('look', 'squint'):            # thinking: eyes up and away
        for ex in (17, 24):
            rect(g, ex, ey - 1, ex + 2, ey + 1, CYAN)
            g.put(ex + 2, ey - 1, LCYAN)
        if face == 'squint':
            rect(g, 24, ey - 1, 26, ey - 1, SCREEN)
            rect(g, 24, ey + 1, 26, ey + 1, SCREEN)
    elif face == 'wide':
        for ex in eyes:
            rect(g, ex, ey - 1, ex + 3, ey + 2, CYAN)
            g.put(ex, ey - 1, LCYAN)
    if face in ('happy', 'wide'):               # little cheek glow
        g.put(15, ey + 4, DCYAN)
        g.put(27, ey + 4, DCYAN)
    my = 18 + dy
    if mouth == 'line':
        rect(g, 19, my, 22, my, DCYAN)
    elif mouth == 'small':
        rect(g, 19, my, 22, my + 1, CYAN)
    elif mouth == 'open':
        rect(g, 18, my - 1, 23, my + 1, CYAN)
        rect(g, 19, my, 22, my, DCYAN)
    elif mouth == 'smile':
        g.put(18, my - 1, CYAN); g.put(23, my - 1, CYAN)
        rect(g, 19, my, 22, my, CYAN)
    # arms in front
    if arm == 'chin':
        arm_path(g, [(12, 29), (8, 26), (11, 22), (15, 22)], dy)   # hand on the chin
    elif arm == 'up':
        arm_path(g, [(12, 29), (8, 24), (9, 18)], dy)
        arm_path(g, [(33, 28), (37, 23), (36, 17)], dy, far=True)
    else:
        arm_down(g, 11, dy)
    if wave:
        end = {1: (39, 23), 2: (40, 17), 3: (37, 15), 4: (41, 16), 5: (39, 21)}[wave]
        arm_path(g, [(33, 28), (37, 26), end], dy, far=True)
    g.outline()
    return g


def frames():
    rows = []
    rows.append([bot(glow=1), bot(glow=2), bot(glow=2), bot(glow=1), bot(face='blink', glow=0), bot(glow=1)])
    rows.append([bot(mouth=m, chest=c, glow=2 if i % 2 else 1) for i, (m, c) in enumerate(
        [('line', 1), ('small', 2), ('open', 2), ('small', 1), ('open', 2), ('line', 1)])])
    rows.append([bot(face=f, arm='chin', glow=gl, mouth='line', chest=0) for f, gl in
                 [('neutral', 1), ('look', 1), ('look', 2), ('squint', 2), ('look', 1), ('squint', 0)]])
    rows.append([bot(face='happy', mouth='smile', dy=d, arm='up' if d <= -3 else None, glow=2, chest=2)
                 for d in (0, -2, -3, -3, -1, 0)])
    rows.append([bot(face='wide' if w in (2, 3) else 'neutral', mouth='smile', wave=w, glow=2) for w in (1, 2, 3, 4, 3, 5)])
    return rows


def main():
    rows = frames()
    sheet = Image.new('RGBA', (48 * 6, 48 * 5), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for c, g in enumerate(row):
            sheet.paste(g.img, (c * 48, r * 48))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(os.path.join(ROOT, 'assets', 'agentic_bot.png'))
    if len(sys.argv) > 1:
        pv = Image.new('RGBA', sheet.size, (70, 110, 70, 255))
        pv.paste(sheet, (0, 0), sheet)
        pv.resize((pv.width * 4, pv.height * 4), Image.NEAREST).save(sys.argv[1])
    print('wrote assets/agentic_bot.png')


if __name__ == '__main__':
    main()
