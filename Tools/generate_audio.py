#!/usr/bin/env python3
"""Generates LetterLock's placeholder music and sound effects as 16-bit mono WAV files.

Everything is synthesised from scratch (original melody, no samples), so it is safe to
ship in the prototype and easy to swap for final audio later.

Usage: python3 Tools/generate_audio.py LetterLock/Audio
"""

import math
import os
import random
import sys
import wave
from array import array

SR = 44100
TAU = 2 * math.pi
random.seed(7)


def silence(seconds):
    return [0.0] * int(SR * seconds)


def mix(buffer, start_seconds, samples, gain=1.0, wrap=False):
    start = int(start_seconds * SR)
    n = len(buffer)
    for i, s in enumerate(samples):
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buffer[j] += s * gain


def write(directory, name, samples, peak=0.89):
    top = max(1e-9, max(abs(s) for s in samples))
    gain = peak / top
    data = array("h", (int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples))
    with wave.open(os.path.join(directory, name + ".wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(data.tobytes())


def mtof(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(samples, alpha):
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


# ---------------------------------------------------------------- instruments

def kick():
    out, phase = [], 0.0
    for i in range(int(SR * 0.25)):
        t = i / SR
        phase += TAU * (45 + 75 * math.exp(-t * 30)) / SR
        out.append(math.sin(phase) * math.exp(-t * 16))
    return out


def shaker():
    out, prev = [], 0.0
    for i in range(int(SR * 0.06)):
        t = i / SR
        noise = random.random() * 2 - 1
        high = noise - prev
        prev = noise
        out.append(high * math.exp(-t * 55))
    return out


def bell(freq, seconds, decay=4.0):
    out = []
    for i in range(int(SR * seconds)):
        t = i / SR
        tone = (math.sin(TAU * freq * t)
                + 0.5 * math.sin(TAU * 2.76 * freq * t) * math.exp(-t * 3)
                + 0.25 * math.sin(TAU * 5.40 * freq * t) * math.exp(-t * 6))
        out.append(tone * math.exp(-t * decay) * min(1.0, t / 0.003))
    return out


# ---------------------------------------------------------------- music loop

def snare():
    out, prev = [], 0.0
    for i in range(int(SR * 0.18)):
        t = i / SR
        noise = random.random() * 2 - 1
        high = noise - prev
        prev = noise
        body = math.sin(TAU * 190 * t) * math.exp(-t * 32)
        out.append(0.8 * high * math.exp(-t * 20) + 0.6 * body)
    return out


def chip_lead(freq, seconds):
    """A bright 50% pulse with a little vibrato, played short and bouncy."""
    raw, phase = [], 0.0
    for i in range(int(SR * seconds)):
        t = i / SR
        phase = (phase + freq * (1 + 0.005 * math.sin(TAU * 6 * t)) / SR) % 1.0
        pulse = 1.0 if phase < 0.5 else -1.0
        env = min(1.0, t / 0.004) * (0.6 + 0.4 * math.exp(-t * 18)) * min(1.0, (seconds - t) / 0.015)
        raw.append(pulse * env)
    return lowpass(raw, 0.22)


def play_hook(loop, at, hook, voice, gain, sixteenth, legato=0.85):
    for bar, notes in hook.items():
        for step, length, note in notes:
            mix(loop, at(bar, step), voice(mtof(note), length * sixteenth * legato), gain, wrap=True)


def bright_lead(freq, seconds):
    """Early-2000s handheld lead: detuned saws with a square underneath and a quick vibrato."""
    raw, phases = [], [0.0, 0.0, 0.0]
    for i in range(int(SR * seconds)):
        t = i / SR
        vib = 1 + 0.006 * math.sin(TAU * 6.5 * t) * min(1.0, t / 0.15)
        for k, detune in enumerate((0.996, 1.004, 1.0)):
            phases[k] = (phases[k] + freq * detune * vib / SR) % 1.0
        saw = (2 * phases[0] - 1) + (2 * phases[1] - 1)
        square = 1.0 if phases[2] < 0.5 else -1.0
        env = min(1.0, t / 0.006) * (0.7 + 0.3 * math.exp(-t * 10)) * min(1.0, (seconds - t) / 0.02)
        raw.append((0.35 * saw + 0.3 * square) * env)
    return lowpass(raw, 0.3)


def supersaw(freqs, seconds, attack=0.03, release=0.12, cutoff=0.14):
    """Wide detuned-saw chord, the core synthwave pad sound."""
    detunes = (0.988, 0.995, 1.0, 1.005, 1.012)
    raw, phases = [], [random.random() for _ in range(len(freqs) * len(detunes))]
    for i in range(int(SR * seconds)):
        t = i / SR
        s = 0.0
        for k, f in enumerate(freqs):
            for d, detune in enumerate(detunes):
                idx = k * len(detunes) + d
                phases[idx] = (phases[idx] + f * detune / SR) % 1.0
                s += 2 * phases[idx] - 1
        env = min(1.0, t / attack) * min(1.0, (seconds - t) / release)
        raw.append(s / (len(freqs) * len(detunes)) * env)
    return lowpass(lowpass(raw, cutoff), cutoff * 1.5)


def saw_pluck(freq, seconds, decay=16.0):
    """Short, punchy saw pluck for arps and basslines."""
    raw, phase = [], 0.0
    for i in range(int(SR * seconds)):
        t = i / SR
        phase = (phase + freq / SR) % 1.0
        env = math.exp(-t * decay) * min(1.0, t / 0.002) * min(1.0, (seconds - t) / 0.01)
        raw.append((2 * phase - 1) * env)
    return lowpass(raw, 0.25)


def big_snare():
    """Snare with a long, roomy tail for that 80s gated-reverb feel."""
    out = snare() + silence(0.35)
    prev = 0.0
    for i in range(len(out)):
        t = i / SR
        noise = random.random() * 2 - 1
        prev += 0.25 * (noise - prev)
        out[i] += prev * 0.55 * math.exp(-t * 7) * (1.0 if t < 0.42 else 0.0)
    return out


def add_echo(loop, at, hook, voice, gain, sixteenth, delay_steps=3, feedback=0.35, legato=0.85):
    """Plays a hook and a quieter delayed copy for a spacey synth echo."""
    play_hook(loop, at, hook, voice, gain, sixteenth, legato)
    shifted = {bar: [(step + delay_steps, length, note) for step, length, note in notes] for bar, notes in hook.items()}
    play_hook(loop, at, shifted, voice, gain * feedback, sixteenth, legato)


def music_midnight():
    """Option 9, Midnight Pulse: 100 bpm dark retro-synth. Minor key, gated square arp, deep saw bass, punchy drums."""
    bpm, bars = 100, 8
    sixteenth = 60 / bpm / 4
    loop = silence(bars * 16 * sixteenth)

    def at(bar, step):
        return (bar * 16 + step) * sixteenth

    # Dm - Bb - Gm - A, twice.
    chords = [(50, [62, 65, 69]), (46, [58, 62, 65]), (43, [55, 58, 62]), (45, [57, 61, 64])] * 2
    pads = silence(len(loop) / SR)
    for bar, (root, tones) in enumerate(chords):
        for step, gain in ((0, 0.46), (6, 0.30), (10, 0.38)):
            mix(loop, at(bar, step), kick(), gain, wrap=True)
        for step in (4, 12):
            mix(loop, at(bar, step), big_snare(), 0.28, wrap=True)
        for step in range(16):
            mix(loop, at(bar, step), shaker(), 0.07 if step % 2 else 0.04, wrap=True)
        # Deep, steady saw bass in eighths.
        for step in range(0, 16, 2):
            mix(loop, at(bar, step), saw_pluck(mtof(root - 12), sixteenth * 1.9, 6), 0.30, wrap=True)
        # Gated square arpeggio up and down the chord.
        arp = [tones[0], tones[1], tones[2], tones[0] + 12, tones[2], tones[1]]
        for step in range(16):
            mix(loop, at(bar, step), chip_lead(mtof(arp[step % 6] + 12), sixteenth * 0.55), 0.06, wrap=True)
        mix(pads, at(bar, 0), supersaw([mtof(n) for n in tones], 16 * sixteenth, attack=0.3, release=0.3, cutoff=0.09), 1.0, wrap=True)
    mix(loop, 0, pads, 0.30)

    hook = {
        0: [(0, 4, 74), (4, 2, 77), (6, 2, 76), (8, 8, 74)],
        1: [(0, 4, 74), (4, 2, 77), (6, 2, 81), (8, 8, 77)],
        2: [(0, 4, 79), (4, 2, 77), (6, 2, 74), (8, 8, 70)],
        3: [(0, 8, 73), (8, 4, 76), (12, 4, 79)],
        4: [(0, 4, 81), (4, 2, 79), (6, 2, 77), (8, 8, 74)],
        5: [(0, 4, 77), (4, 2, 74), (6, 2, 77), (8, 8, 82)],
        6: [(0, 4, 79), (4, 4, 82), (8, 8, 86)],
        7: [(0, 8, 85), (8, 8, 81)],
    }
    add_echo(loop, at, hook, bright_lead, 0.11, sixteenth, delay_steps=3)
    return loop


# ---------------------------------------------------------------- sound effects

def tick():
    out = []
    for i in range(int(SR * 0.09)):
        t = i / SR
        out.append((math.sin(TAU * 1150 * t) + 0.6 * math.sin(TAU * 1720 * t)) * math.exp(-t * 70))
    return out


# ---------------------------------------------------------------- end of round
# The 0:00 sound (Dark Gong). It rings only on notes from D minor, so it sits with Midnight Pulse.

D4, F4, A4, C5, D5, F5, A5, D6 = 62, 65, 69, 72, 74, 77, 81, 86


def thud(start_hz, sweep_hz, seconds, decay):
    """A falling-pitch body thump, the weight behind a bell strike."""
    out, phase = [], 0.0
    for i in range(int(SR * seconds)):
        t = i / SR
        phase += TAU * (start_hz + sweep_hz * math.exp(-t * 40)) / SR
        out.append(math.sin(phase) * math.exp(-t * decay))
    return out


def ring_bell(midi, seconds, decay):
    """A metal bell with an inharmonic upper partial so it clangs rather than chimes."""
    base = bell(mtof(midi), seconds, decay)
    clang = bell(mtof(midi) * 1.505, seconds * 0.75, decay * 1.4)
    out = list(base)
    for i, s in enumerate(clang):
        out[i] += 0.45 * s
    return out


def end_darkgong():
    """Dark Gong: a very low, slow-swelling strike on D with a shimmering wobble. The moodiest."""
    buffer = silence(2.3)
    mix(buffer, 0.0, thud(55, 90, 0.5, 7), 0.9)
    gong = ring_bell(D4, 2.3, 1.3)
    # A slow beating wobble, like a gong's surface settling.
    gong = [s * (1 + 0.25 * math.sin(TAU * 4.2 * (i / SR))) for i, s in enumerate(gong)]
    mix(buffer, 0.0, gong, 0.8)
    mix(buffer, 0.0, ring_bell(A4, 1.8, 2.0), 0.25)
    mix(buffer, 0.02, bell(mtof(D5), 1.5, 2.5), 0.2)
    return buffer


def veto():
    buffer = silence(1.6)
    # Record scratch: a buzzy tone whose speed swings back and forth.
    scratch, phase, prev = [], 0.0, 0.0
    for i in range(int(SR * 0.34)):
        t = i / SR
        speed = 250 + 1100 * abs(math.sin(TAU * 4.5 * t))
        phase = (phase + speed / SR) % 1.0
        noise = random.random() * 2 - 1
        prev += 0.3 * (noise - prev)
        env = min(1.0, t / 0.01) * min(1.0, (0.34 - t) / 0.05)
        scratch.append((0.6 * (2 * phase - 1) + 0.6 * prev) * env)
    mix(buffer, 0, scratch, 0.8)
    # Suspicious chime: a falling tritone.
    mix(buffer, 0.38, bell(mtof(76), 1.0, 3.5), 0.55)
    mix(buffer, 0.62, bell(mtof(70), 0.95, 3.0), 0.55)
    return buffer


def sparkle():
    buffer = silence(1.1)
    for k, note in enumerate([84, 88, 91, 96, 100]):
        mix(buffer, k * 0.055, bell(mtof(note), 0.8, 6), 0.35)
    shimmer = [(random.random() * 2 - 1) * math.exp(-(i / SR) * 9) * 0.05 for i in range(int(SR * 0.5))]
    prev, high = 0.0, []
    for s in shimmer:
        high.append(s - prev)
        prev = s
    mix(buffer, 0.05, high)
    return buffer


def pop():
    out, phase = [], 0.0
    for i in range(int(SR * 0.12)):
        t = i / SR
        phase += TAU * (350 + 550 * math.exp(-t * 45)) / SR
        out.append(math.sin(phase) * math.exp(-t * 35) * min(1.0, t / 0.002))
    return out


def clack():
    out = []
    for i in range(int(SR * 0.055)):
        t = i / SR
        noise = (random.random() * 2 - 1) * math.exp(-t * 140)
        click = 0.6 * math.sin(TAU * 2300 * t) * math.exp(-t * 150) + 0.5 * math.sin(TAU * 880 * t) * math.exp(-t * 90)
        out.append(0.5 * noise + click)
    return out


def land():
    buffer = silence(0.35)
    thunk, phase = [], 0.0
    for i in range(int(SR * 0.3)):
        t = i / SR
        phase += TAU * (110 + 120 * math.exp(-t * 25)) / SR
        thunk.append(math.sin(phase) * math.exp(-t * 13))
    mix(buffer, 0, thunk)
    mix(buffer, 0, clack(), 0.7)
    return buffer


def lock():
    buffer = silence(0.25)
    mix(buffer, 0, clack(), 0.8)
    chunk = [math.sin(TAU * 180 * (i / SR)) * math.exp(-(i / SR) * 30) for i in range(int(SR * 0.15))]
    mix(buffer, 0.07, chunk, 0.8)
    mix(buffer, 0.07, clack(), 0.6)
    return buffer


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(directory, exist_ok=True)
    write(directory, "music_midnight", music_midnight(), peak=0.85)
    for name, make in [("tick", tick), ("veto", veto), ("sparkle", sparkle),
                       ("pop", pop), ("clack", clack), ("land", land), ("lock", lock),
                       ("end_darkgong", end_darkgong)]:
        write(directory, name, make())
    print("Wrote audio to", directory)


if __name__ == "__main__":
    main()
