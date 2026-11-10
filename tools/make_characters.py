"""Pixel-perfect character variants.   Run: python tools/make_characters.py [preview.png]

The hero sheet is a soft, non-integer-resized drawing (28k colours, 256 alpha levels).
Each 144px frame is shown at 0.25 scale = 36 map pixels, so we:
  1. downsample every frame to 36x36 real pixels (premultiplied box filter, hard alpha),
  2. label pixels: skin / eye-white / pupil / hair / outfit,
  3. paint each region from a 4-shade ramp (+ hue-tinted outline), or a garment pattern,
  4. upscale x4 with nearest-neighbour back into the original sheet layout.
"""
import colorsys, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # project root
os.chdir(ROOT)
OUT = 'assets/characters'
os.makedirs(OUT, exist_ok=True)
S = 4                       # 144 / 36
PREVIEW = sys.argv[1] if len(sys.argv) > 1 else None


def ramp(base, shift=0.03):
    """4 shades dark->light with a slight hue shift (cool shadows, warm lights)."""
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in base])
    out = []
    for k, (vm, sm, hs) in enumerate([(0.45, 1.1, shift), (0.7, 1.05, shift / 2), (0.88, 1.0, 0), (1.06, 0.88, -shift / 2)]):
        r, g, b = colorsys.hsv_to_rgb((h + hs) % 1, min(1, s * sm), min(1, v * vm))
        out.append((int(r * 255), int(g * 255), int(b * 255), 255))
    return out


def outline_of(base):
    h, s, v = colorsys.rgb_to_hsv(*[c / 255 for c in base])
    r, g, b = colorsys.hsv_to_rgb(h, min(1, s * 1.1), max(0.08, v * 0.3))
    return (int(r * 255), int(g * 255), int(b * 255), 255)


# name, hair, outfit(painter)   painter = colour tuple or a function(x, y, ctx) -> colour tuple
def solid(c):
    return lambda x, y, ctx: c


def dhoti(x, y, ctx):
    top, bot, l, r = ctx["body"]
    t = (y - top) / max(1, bot - top)
    cx = (l + r) // 2
    # angavastram: saffron band from the left shoulder down to the right waist
    if t <= 0.5 and abs((x - (l + 2)) - (y - top) * 1.1) <= 0.6:
        return (232, 122, 34)
    if t < 0.42:
        return (236, 226, 200)                      # kurta
    if t < 0.48:
        return (196, 146, 40)                       # gold waist border where the dhoti is tied
    if x == cx or y >= bot - 2:
        return (206, 156, 46)                       # front pleat (kaccha) + gold hem
    return (250, 248, 242)                          # white dhoti


def chudidar(x, y, ctx):
    top, bot, l, r = ctx["body"]
    t = (y - top) / max(1, bot - top)
    if t < 0.18:
        return (240, 192, 58)                       # dupatta over the shoulders
    if (x == l or x == r) and t < 0.75:
        return (240, 192, 58)                       # dupatta ends falling at the sides
    if t < 0.72:
        if 0.6 < t < 0.72 and (x + y) % 2 == 0:
            return (240, 200, 90)                   # embroidered hem
        return (32, 150, 150)                       # teal kurta
    return (244, 238, 226)                          # churidar leggings


def saree(x, y, ctx):
    top, bot, l, r = ctx["body"]
    t = (y - top) / max(1, bot - top)
    # pallu: gold-bordered drape over the left shoulder (viewer's right) across to the hip
    d = (r - 2 - x) - (y - top) * 1.0
    if t < 0.7 and -0.5 <= d <= 3.5:
        return (232, 182, 50) if (d < 0.5 or d > 2.5) else (176, 20, 52)
    if t < 0.2 and x <= l + 2:
        return (40, 124, 72)                        # blouse sleeve
    if y >= bot - 2:
        return (232, 182, 50)                       # gold border hem
    if t > 0.5 and (x - l) % 3 == 1:
        return (166, 20, 48)                        # pleats
    return (200, 30, 60)                            # red silk


VARIANTS = [
    ("Shadow", None, None, False),
    ("Ember", (210, 82, 38), solid((96, 48, 40)), False),
    ("Frost", (222, 232, 244), solid((52, 102, 188)), False),
    ("Forest", (126, 82, 46), solid((54, 132, 72)), False),
    ("Royal", (236, 196, 86), solid((112, 62, 168)), False),
    ("Rose", (236, 118, 168), solid((226, 218, 204)), False),
    ("Dhoti", (34, 30, 34), dhoti, False),
    ("Chudidar", (34, 30, 34), chudidar, True),
    ("Saree", (34, 30, 34), saree, True),
]


def downsample(frame):
    """144x144 RGBA -> 36x36 with premultiplied box filter and hard alpha."""
    w, h = frame.size
    src = frame.load()
    out = Image.new("RGBA", (w // S, h // S), (0, 0, 0, 0))
    o = out.load()
    for by in range(h // S):
        for bx in range(w // S):
            ar = ag = ab = aa = 0
            for j in range(S):
                for i in range(S):
                    r, g, b, a = src[bx * S + i, by * S + j]
                    ar += r * a; ag += g * a; ab += b * a; aa += a
            if aa / (S * S) >= 110:
                o[bx, by] = (ar // aa, ag // aa, ab // aa, 255)
    return out


def classify(px, w, h):
    lab = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if v > 0.78 and s < 0.22:
                lab[(x, y)] = "white"
            elif s > 0.22 and (hh < 0.13 or hh > 0.95) and v > 0.5:
                lab[(x, y)] = "skin"
            else:
                lab[(x, y)] = "dark"
    return lab


def face_box(lab, h):
    """Bounding box of the skin in the upper 60% (the face), or None (back view)."""
    pts = [(x, y) for (x, y), c in lab.items() if c in ("skin", "white") and y < h * 0.6]
    if len(pts) < 6:
        return None
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def paint(frame36, hair, outfit, bindi, chin_fallback):
    w, h = frame36.size
    px = frame36.load()
    lab = classify(px, w, h)
    face = face_box(lab, h)
    chin = face[3] if face else chin_fallback
    # pupils / brows: dark pixels inside the face box with skin on both sides of the row
    feat = set()
    if face:
        fx0, fy0, fx1, fy1 = face
        for (x, y), c in lab.items():
            if c == "dark" and fx0 < x < fx1 and fy0 <= y <= fy1:
                left = any(lab.get((x - k, y)) in ("skin", "white") for k in range(1, 4))
                right = any(lab.get((x + k, y)) in ("skin", "white") for k in range(1, 4))
                if left and right:
                    feat.add((x, y))
    body = [(x, y) for (x, y), c in lab.items() if c == "dark" and y > chin and (x, y) not in feat]
    if body:
        bt, bb = min(p[1] for p in body), max(p[1] for p in body)
        bl, br = min(p[0] for p in body), max(p[0] for p in body)
    else:
        bt = bb = bl = br = 0
    ctx = {"body": (bt, bb, bl, br)}

    # luminance range per region for 4-level shading
    def lum(p):
        r, g, b, _ = px[p]
        return 0.3 * r + 0.59 * g + 0.11 * b
    regions = {"hair": [], "outfit": []}
    for p, c in lab.items():
        if c == "dark" and p not in feat:
            regions["hair" if p[1] <= chin else "outfit"].append(p)
    rng = {}
    for k, pts in regions.items():
        ls = sorted(lum(p) for p in pts) or [0, 1]
        rng[k] = (ls[int(len(ls) * 0.05)], ls[int(len(ls) * 0.95) - 1] if len(ls) > 1 else ls[0] + 1)

    def shade_idx(p, k):
        lo, hi = rng[k]
        t = (lum(p) - lo) / max(1.0, hi - lo)
        return max(0, min(3, int(t * 4)))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    hair_ramp = ramp(hair) if hair else None
    for p, c in lab.items():
        col = px[p]
        if hair is None:                                   # Shadow: keep original colours, just crisp
            o[p] = col
            continue
        if c == "white":
            o[p] = (238, 238, 242, 255)
        elif c == "skin":
            o[p] = col
        elif p in feat:
            o[p] = (26, 24, 34, 255)                          # pupils stay dark
        elif p[1] <= chin:
            o[p] = hair_ramp[shade_idx(p, "hair")]
        else:
            base = outfit(p[0], p[1], ctx)
            o[p] = ramp(base)[max(1, shade_idx(p, "outfit"))] # keep garment colours readable
    # hue-tinted outline on every edge pixel
    edge = []
    for (x, y) in lab:
        if any((x + dx, y + dy) not in lab for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            edge.append((x, y))
    for (x, y) in edge:
        if lab[(x, y)] in ("skin", "white"):
            o[x, y] = (110, 62, 50, 255)
        elif hair is not None:
            base = hair if y <= chin else outfit(x, y, ctx)
            o[x, y] = outline_of(base)
    if bindi and face:
        fx0, fy0, fx1, fy1 = face
        cx = (fx0 + fx1) // 2
        for y in range(fy0, fy0 + 4):
            if lab.get((cx, y)) == "skin":
                o[cx, y] = (210, 24, 40, 255)
                break
    return out


def frames_of(sheet, fw, fh):
    cols, rows = sheet.width // fw, sheet.height // fh
    return [(c * fw, r * fh) for r in range(rows) for c in range(cols)]


def build(name_idx, hair, outfit, bindi):
    sheet = Image.open('assets/player.png').convert('RGBA')
    out = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    chins = []
    for (x, y) in frames_of(sheet, 144, 144):
        small = downsample(sheet.crop((x, y, x + 144, y + 144)))
        lab = classify(small.load(), 36, 36)
        f = face_box(lab, 36)
        if f:
            chins.append(f[3])
    chin_fb = sorted(chins)[len(chins) // 2] if chins else 20
    for (x, y) in frames_of(sheet, 144, 144):
        small = downsample(sheet.crop((x, y, x + 144, y + 144)))
        big = paint(small, hair, outfit, bindi, chin_fb).resize((144, 144), Image.NEAREST)
        out.alpha_composite(big, (x, y))
    out.save(f'{OUT}/player_{name_idx}.png')
    front = Image.open('assets/front-player.png').convert('RGBA')
    fs = downsample(front)                               # 100x144 -> 25x36
    fbig = paint(fs, hair, outfit, bindi, chin_fb).resize((fs.width * S, fs.height * S), Image.NEAREST)
    canvas = Image.new('RGBA', front.size, (0, 0, 0, 0))
    canvas.alpha_composite(fbig, (0, 0))
    canvas.save(f'{OUT}/front_{name_idx}.png')
    return canvas, out


previews = []
for i, (name, hair, outfit, bindi) in enumerate(VARIANTS):
    front, sheet = build(i, hair, outfit, bindi)
    previews.append((front, sheet))
    print('built', i, name)

if PREVIEW:
    P = Image.new('RGBA', (144 * 4 * 3, 144 * 3 * 2 + 10), (70, 110, 60, 255))
    for i, (front, sheet) in enumerate(previews):
        gx, gy = (i % 3) * 144 * 4, (i // 3) * 150
        for k, (fx, fy) in enumerate([(144, 0), (144, 144), (144, 288), (144, 432)]):
            P.alpha_composite(sheet.crop((fx, fy, fx + 144, fy + 144)), (gx + k * 144, gy))
    P = P.resize((P.width // 2, P.height // 2), Image.NEAREST)
    P.save(PREVIEW)
    print('preview', P.size)
