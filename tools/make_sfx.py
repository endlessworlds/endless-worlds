"""Game sound effects (original, synthesized).  Run: python tools/make_sfx.py

Writes assets/audio/sfx/<name>.wav (44.1 kHz, 16-bit mono). core/sound.gd plays them on the
"SFX" bus. Each sound is built from a few voices: bell (sine partials, like a glockenspiel),
soft square (retro, low-passed), noise (whooshes, pops, thuds) and pitch sweeps, then gets
a short room reverb and is normalised to the same peak.
"""
import os, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio', 'sfx')
SR = 44100
rng = np.random.default_rng(7)


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.004, decay=6.0):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-decay * t)


def bell(f, dur, decay=7.0, amp=1.0):
    t = t_of(dur)
    s = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-4 * t)
         + 0.2 * np.sin(2 * np.pi * 3.01 * f * t) * np.exp(-7 * t)
         + 0.12 * np.sin(2 * np.pi * 4.2 * f * t) * np.exp(-12 * t))
    return amp * s * env(len(t), 0.002, decay)


def square(f0, f1, dur, decay=8.0, amp=1.0, duty=0.5):
    t = t_of(dur)
    f = np.linspace(f0, f1, len(t))
    ph = np.cumsum(f) / SR
    s = np.where((ph % 1.0) < duty, 1.0, -1.0)
    s = lowpass(s, 3500)
    return amp * s * env(len(t), 0.003, decay)


def sine_sweep(f0, f1, dur, decay=8.0, amp=1.0):
    t = t_of(dur)
    f = np.geomspace(f0, f1, len(t))
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.002, decay)


def noise(dur, decay=10.0, amp=1.0, lp=None, hp=None, attack=0.002):
    s = rng.uniform(-1, 1, int(SR * dur))
    if lp:
        s = lowpass(s, lp)
    if hp:
        s = s - lowpass(s, hp)
    return amp * s * env(len(s), attack, decay)


def lowpass(s, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    out = np.empty_like(s)
    y = 0.0
    for i, x in enumerate(s):
        y = (1 - a) * x + a * y
        out[i] = y
    return out


def at(total, parts):
    """Mix [(start_seconds, signal), ...] into one buffer `total` seconds long."""
    buf = np.zeros(int(SR * total))
    for start, s in parts:
        i = int(SR * start)
        n = min(len(s), len(buf) - i)
        buf[i:i + n] += s[:n]
    return buf


def reverb(s, mix=0.18):
    out = s.copy()
    for d, g in [(0.029, 0.5), (0.037, 0.42), (0.053, 0.33), (0.071, 0.25)]:
        k = int(SR * d)
        wet = np.zeros_like(s)
        for rep in range(1, 6):
            if k * rep < len(s):
                wet[k * rep:] += s[:-k * rep] * (g ** rep)
        out += wet * mix
    return out


def save(name, s, peak=0.85, verb=0.18):
    s = reverb(s, verb) if verb else s
    fade = min(len(s), int(SR * 0.01))
    s[-fade:] *= np.linspace(1, 0, fade)
    s = s / (np.max(np.abs(s)) + 1e-9) * peak
    data = (s * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


N = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate('C C# D D# E F F# G G# A A# B'.split())}


def note(name, octave):
    return N[name] * 2 ** (octave - 4)


def main():
    os.makedirs(OUT, exist_ok=True)
    # UI
    save('click', at(0.06, [(0, bell(1900, 0.06, 60, 0.6)), (0, noise(0.02, 200, 0.3, hp=2000))]), 0.6, 0)
    save('key', at(0.04, [(0, noise(0.03, 180, 0.6, lp=6000, hp=1500)), (0, bell(2600, 0.03, 120, 0.3))]), 0.45, 0)
    save('open', at(0.28, [(0, noise(0.22, 10, 0.35, lp=2500, attack=0.08)),
                           (0.05, bell(note('E', 5), 0.2, 14, 0.5)), (0.1, bell(note('B', 5), 0.18, 14, 0.4))]), 0.6)
    save('close', at(0.2, [(0, noise(0.16, 16, 0.35, lp=1800, attack=0.03)),
                           (0.02, bell(note('B', 5), 0.15, 18, 0.4)), (0.07, bell(note('E', 5), 0.13, 20, 0.35))]), 0.55)
    # world
    save('hint', at(0.75, [(0, bell(note('E', 6), 0.5, 7, 0.7)), (0.07, bell(note('G#', 6), 0.5, 7, 0.6)),
                           (0.14, bell(note('B', 6), 0.55, 6, 0.6)), (0.21, bell(note('E', 7), 0.5, 6, 0.45)),
                           (0, noise(0.6, 5, 0.06, hp=7000, attack=0.1))]), 0.75, 0.3)
    save('jump', at(0.12, [(0, noise(0.1, 30, 0.7, lp=1400, attack=0.01)), (0, sine_sweep(150, 240, 0.08, 40, 0.5))]), 0.35, 0)   # soft puff
    save('hurt', at(0.3, [(0, sine_sweep(220, 60, 0.25, 12, 1.0)), (0, noise(0.12, 30, 0.6, lp=1200)),
                          (0.02, square(180, 90, 0.18, 14, 0.35))]), 0.8, 0.1)
    save('torch', at(0.35, [(0, noise(0.3, 9, 0.8, lp=1800, hp=300, attack=0.04)),
                            (0.03, noise(0.12, 25, 0.3, hp=4000))]), 0.55, 0.1)
    save('whack', at(0.25, [(0, sine_sweep(320, 90, 0.18, 18, 1.0)), (0, noise(0.05, 60, 0.8, lp=3000)),
                            (0.01, bell(1200, 0.1, 30, 0.25))]), 0.8, 0.1)
    save('chest', at(1.2, [(0, sine_sweep(140, 260, 0.25, 4, 0.4)), (0, noise(0.25, 6, 0.15, lp=900, attack=0.05))]
                     + [(0.25 + i * 0.06, bell(note(n, o), 0.5, 8, 0.5))
                        for i, (n, o) in enumerate([('C', 6), ('E', 6), ('G', 6), ('C', 7), ('E', 7), ('G', 7)])]), 0.75, 0.3)
    # answers
    save('wrong', at(0.5, [(0, square(note('D#', 3), note('D#', 3), 0.18, 6, 0.7, 0.4)),
                           (0, square(note('D#', 3) * 1.012, note('D#', 3) * 1.012, 0.18, 6, 0.5, 0.4)),
                           (0.2, square(note('C', 3), note('A', 2), 0.28, 5, 0.7, 0.4)),
                           (0.2, square(note('C', 3) * 1.012, note('A', 2) * 1.012, 0.28, 5, 0.5, 0.4))]), 0.7, 0.15)
    # fanfare: arpeggio up, then a held major chord with a shimmer on top
    arp = [('C', 5), ('E', 5), ('G', 5), ('C', 6)]
    parts = [(i * 0.09, bell(note(n, o), 0.5, 6, 0.8)) for i, (n, o) in enumerate(arp)]
    parts += [(i * 0.09, square(note(n, o) / 2, note(n, o) / 2, 0.12, 12, 0.25, 0.25)) for i, (n, o) in enumerate(arp)]
    for n, o in [('C', 5), ('E', 5), ('G', 5), ('C', 6), ('E', 6)]:
        parts.append((0.38, bell(note(n, o), 1.3, 2.2, 0.45)))
        parts.append((0.38, square(note(n, o) / 2, note(n, o) / 2, 0.9, 3.5, 0.08, 0.5)))
    parts += [(0.45 + i * 0.05, bell(note(n, 7), 0.4, 9, 0.18)) for i, n in enumerate('C E G C E G'.split())]
    save('win', at(1.8, parts), 0.85, 0.3)
    save('lose', at(1.4, [(0, bell(note('G', 4), 0.5, 4, 0.7)), (0.25, bell(note('D#', 4), 0.5, 4, 0.7)),
                          (0.5, bell(note('C', 4), 0.9, 2.5, 0.8)),
                          (0.5, square(note('C', 3), note('C', 3) * 0.97, 0.8, 3, 0.2, 0.5))]), 0.75, 0.3)
    # party popper: a pop, then paper crackle
    crack = [(0.05 + rng.uniform(0, 0.45), noise(0.012, 300, rng.uniform(0.2, 0.5), hp=3000)) for _ in range(28)]
    save('confetti', at(0.7, [(0, noise(0.06, 60, 1.0, lp=2500)), (0, sine_sweep(180, 70, 0.08, 40, 0.9))] + crack), 0.75, 0.1)
    print('wrote', len(os.listdir(OUT)), 'files to', OUT)


if __name__ == '__main__':
    main()
