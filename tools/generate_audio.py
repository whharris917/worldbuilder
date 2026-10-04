"""Generate the worlds' audio as WAV files, procedurally.

Run from the project root:

    .venv\\Scripts\\python.exe tools\\generate_audio.py

Writes to game/audio/:
  music_loop.wav  40 s seamless clockwork sequencer piece in D minor:
                  a tick on every beat, a sixteenth-note pluck arpeggio,
                  a pulsing sub bass, detuned pads, a sparse lead
  step_1..4.wav   footsteps: a soft thud of the sole, a faint strike, a
                  light floor knock, the roll on to the toe
  land.wav        heavier landing thump
  surf_loop.wav   16 s seamless surf on a ledge, swells breaking as hiss
  wind_loop.wav   12 s seamless wind off the water, gusting
  gull_1..3.wav   herring gull cries: one long, a long call, a pair
  river_loop.wav  10 s seamless stream over stones: a low rush, a
                  chatter of eddies, bubbles now and then
  rain_loop.wav   10 s seamless light drizzle: a soft hiss, a gentle drop
  gale_loop.wav   14 s seamless gale, gusting hard, a moan on an edge
  thunder_near.wav, thunder_1..3.wav  a close stroke's crack and roll;
                  three distant rolls, darker with distance
  bell_1..2.wav   a bell buoy's bronze bell, struck hard and soft
  leaves_loop.wav 14 s seamless wind in a summer wood's leaves
  air_loop.wav    12 s seamless steady low rush of moving air
  grass_hiss_loop.wav  10 s seamless hiss of long grass bending
  engine_loop.wav 2 s seamless 1940s pickup six-cylinder at idle
  crickets_loop.wav  10 s seamless field crickets and tree crickets
  bird_*.wav      white-throated sparrow, chickadee, robin, wood thrush
                  (two), barred owl
  knock_1..3.wav  a heavy stone ball striking a stone wall: a deep
                  falling thump, a heavy low rumble, dense grit, saturated
  swoosh_loop.wav 6 s seamless broadband rush, for air past a moving body
  step_pebbles_1..4.wav  footsteps on wet pebbles: a soft thud, the stones
                  shifting, a wet squelch, a bubble
  step_wade_1..4.wav  wading steps in shin-deep water: the leg's push
                  through it, a spatter of drops, bubbles, a muffled sole

Loops are made seamless by quantizing every sustained frequency to an
integer number of cycles per loop and forcing envelopes to zero at the
seam. Deterministic (fixed seed). Stdlib only.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 32000
OUT_DIR = Path(__file__).resolve().parents[1] / "game" / "audio"

rng = random.Random(20260829)


def write_wav(path: Path, channels: list[list[float]],
              normalize_to: float | None = None) -> None:
    peak = max(1e-9, max(abs(sample) for chan in channels for sample in chan))
    if normalize_to is not None:
        scale = normalize_to / peak
    else:
        scale = 0.9 / peak if peak > 0.9 else 1.0
    frames = bytearray()
    for i in range(len(channels[0])):
        for chan in channels:
            value = int(max(-1.0, min(1.0, chan[i] * scale)) * 32767)
            frames += struct.pack("<h", value)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(len(channels))
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(bytes(frames))
    print(f"  {path.name}  ({len(channels[0]) / SR:.2f} s, {len(channels)} ch)")


def quantize(freq: float, duration: float) -> float:
    """Snap freq to an integer number of cycles over the loop."""
    return round(freq * duration) / duration


def add_partial(buf: list[float], freq: float, amp: float, duration: float,
                env=None) -> None:
    freq = quantize(freq, duration)
    omega = 2.0 * math.pi * freq / SR
    for i in range(len(buf)):
        value = amp * math.sin(omega * i)
        if env is not None:
            value *= env(i / SR)
        buf[i] += value


def chord_env(start: float, length: float, attack: float, release: float,
              loop: float):
    """Raised-cosine gate, wrapped around the loop seam."""
    def env(t: float) -> float:
        pos = (t - start) % loop
        if pos >= length:
            return 0.0
        if pos < attack:
            return 0.5 * (1.0 - math.cos(math.pi * pos / attack))
        if pos > length - release:
            return 0.5 * (1.0 - math.cos(math.pi * (length - pos) / release))
        return 1.0
    return env


def brown_noise(n: int, leak: float = 0.996, gain: float = 0.03) -> list[float]:
    out = [0.0] * n
    acc = 0.0
    for i in range(n):
        acc = acc * leak + (rng.random() * 2.0 - 1.0) * gain
        out[i] = acc
    return out


def loop_crossfade(buf: list[float], fade_s: float) -> list[float]:
    """Fold the tail into the head so noise loops without a click."""
    fade = int(fade_s * SR)
    body = buf[:-fade]
    tail = buf[-fade:]
    for i in range(fade):
        weight = i / fade
        body[i] = body[i] * weight + tail[i] * (1.0 - weight)
    return body


# ---- music ----------------------------------------------------------------
# A clockwork sequencer piece (the vibe of
# Daniel Pemberton's "Clock Numbers" from Project Hail Mary — an
# original piece in that analog-sequencer lineage, not a copy). A tick
# on every beat, a sixteenth-note pluck arpeggio rolling through the
# chord with its filter opening across each four-bar phrase, a pulsing
# sub bass, soft detuned pads, and a sparse descending lead in the
# second half. 96 BPM makes a sixteenth exactly 5000 samples; 16 bars
# is 40 s, and every event that runs past the end wraps to the start,
# so the loop is seamless by construction.
MUSIC_BPM = 96
SIXTEENTH = int(SR * 60 / MUSIC_BPM / 4)   # 5000 samples
BAR = SIXTEENTH * 16
MUSIC_BARS = 16
MUSIC_N = BAR * MUSIC_BARS

# Chord slots: (first bar, bars, pad tones, arpeggio pitches, bass root).
# D minor throughout: i, VI, III, VII, v — the v pulls back to i at the seam.
MUSIC_CHORDS = [
    (0, 4, [146.83, 174.61, 220.00], [146.83, 174.61, 220.00, 293.66, 349.23], 73.42),   # Dm
    (4, 4, [116.54, 146.83, 174.61], [146.83, 174.61, 233.08, 293.66, 349.23], 58.27),   # Bb
    (8, 4, [174.61, 220.00, 261.63], [174.61, 220.00, 261.63, 349.23, 440.00], 87.31),   # F
    (12, 2, [130.81, 164.81, 196.00], [164.81, 196.00, 261.63, 329.63, 392.00], 65.41),  # C
    (14, 2, [110.00, 130.81, 164.81], [164.81, 220.00, 261.63, 329.63, 440.00], 55.00),  # Am
]
ARP_PATTERN = [0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1]
# (bar, sixteenth, pitch Hz, sixteenths held): a lead that steps down
# from the fifth to the root over the second half and is gone by the seam.
MUSIC_LEAD = [
    (8, 0, 440.00, 30), (10, 0, 392.00, 14), (11, 0, 349.23, 14),
    (12, 0, 329.63, 30), (14, 0, 293.66, 26),
]


def _add_wrapped(buf: list[float], start: int, samples: list[float], gain: float) -> None:
    """Mix samples into the loop from start, wrapping past the seam."""
    n = len(buf)
    for j, v in enumerate(samples):
        buf[(start + j) % n] += v * gain


def _pluck(freq: float, length: int, bright: float) -> list[float]:
    """Sequencer pluck: four harmonics, the upper ones decaying faster
    so the note darkens as it rings; bright (0..1) is the filter."""
    out = [0.0] * length
    w = 2.0 * math.pi * freq / SR
    for k, base in ((1, 1.0), (2, 0.55), (3, 0.30), (4, 0.16)):
        amp = base if k == 1 else base * (0.25 + 0.75 * bright)
        tau = 0.26 / (k ** 0.9)
        wk = w * k
        for i in range(length):
            e = math.exp(-i / SR / tau)
            if i < 64:
                e *= i / 64.0
            out[i] += amp * e * math.sin(wk * i)
    return out


def _tick(freq: float, length: int, noise: float, r: random.Random) -> list[float]:
    """A clock escapement: a short ringing ping under a burst of noise."""
    out = [0.0] * length
    w = 2.0 * math.pi * freq / SR
    for i in range(length):
        t = i / SR
        out[i] = (0.7 * math.exp(-t / 0.0045) * math.sin(w * i)
                  + noise * math.exp(-t / 0.0012) * (r.random() * 2.0 - 1.0))
    return out


def _bass_pulse(freq: float, length: int) -> list[float]:
    out = [0.0] * length
    w = 2.0 * math.pi * freq / SR
    for i in range(length):
        e = math.exp(-i / SR / 0.22) * min(1.0, i / 160.0)
        out[i] = e * (math.sin(w * i) + 0.35 * math.sin(2.0 * w * i))
    return out


def _pad_voice(freq: float, length: int, edge: int, detune: float,
               harmonics: tuple[tuple[int, float], ...]) -> list[float]:
    """A sustained voice with raised-cosine edges of `edge` samples at
    both ends; two of these a slot apart cross at equal gain."""
    out = [0.0] * length
    w = 2.0 * math.pi * freq * (1.0 + detune) / SR
    for k, amp in harmonics:
        wk = w * k
        for i in range(length):
            out[i] += amp * math.sin(wk * i)
    for i in range(edge):
        g = 0.5 * (1.0 - math.cos(math.pi * i / edge))
        out[i] *= g
        out[length - 1 - i] *= g
    return out


def _lead_note(freq: float, length: int) -> list[float]:
    """A soft lead with vibrato that arrives after the note settles."""
    out = [0.0] * length
    attack = int(0.35 * SR)
    release = int(0.6 * SR)
    phase = 0.0
    for i in range(length):
        t = i / SR
        vib = 1.0 + 0.0035 * min(1.0, max(0.0, (t - 0.4) / 0.6)) * math.sin(2.0 * math.pi * 4.6 * t)
        phase += 2.0 * math.pi * freq * vib / SR
        v = math.sin(phase) + 0.35 * math.sin(2.0 * phase) + 0.12 * math.sin(3.0 * phase)
        if i < attack:
            v *= 0.5 * (1.0 - math.cos(math.pi * i / attack))
        if i > length - release:
            v *= 0.5 * (1.0 - math.cos(math.pi * (length - i) / release))
        out[i] = v
    return out


def make_music() -> None:
    n = MUSIC_N
    left = [0.0] * n
    right = [0.0] * n
    local = random.Random(20260902)   # own stream: the other files stay byte-identical

    # The clock: tock on beats 1 and 3 to the right, tick on 2 and 4 to
    # the left, 96 to the minute.
    tock = _tick(1900.0, int(0.03 * SR), 0.9, local)
    tick = _tick(2600.0, int(0.03 * SR), 0.7, local)
    for beat in range(MUSIC_BARS * 4):
        at = beat * SIXTEENTH * 4
        if beat % 2 == 0:
            _add_wrapped(right, at, tock, 0.085)
            _add_wrapped(left, at, tock, 0.045)
        else:
            _add_wrapped(left, at, tick, 0.065)
            _add_wrapped(right, at, tick, 0.035)

    pad_h = ((1, 1.0), (2, 0.42), (3, 0.16))
    edge = int(1.0 * SR)   # the crossfade: each slot starts a second early and ends a second late
    pluck_len = int(0.34 * SR)
    pulse_len = SIXTEENTH * 2
    for first_bar, bars, tones, arp, root in MUSIC_CHORDS:
        slot_start = first_bar * BAR
        slot_len = bars * BAR
        # Pads: chord tones detuned apart left and right, the root an
        # octave down in the middle.
        for f in tones:
            _add_wrapped(left, slot_start - edge,
                         _pad_voice(f, slot_len + 2 * edge, edge, -0.0025, pad_h), 0.075)
            _add_wrapped(right, slot_start - edge,
                         _pad_voice(f, slot_len + 2 * edge, edge, 0.0025, pad_h), 0.075)
        low = _pad_voice(root, slot_len + 2 * edge, edge, 0.0, ((1, 1.0), (2, 0.2)))
        _add_wrapped(left, slot_start - edge, low, 0.06)
        _add_wrapped(right, slot_start - edge, low, 0.06)
        # Bass: an eighth-note pulse on the root, leaning on the downbeat.
        for eighth in range(bars * 8):
            at = slot_start + eighth * SIXTEENTH * 2
            g = 0.30 if eighth % 8 == 0 else 0.22
            pulse = _bass_pulse(root, pulse_len)
            _add_wrapped(left, at, pulse, g)
            _add_wrapped(right, at, pulse, g)
        # Arpeggio: sixteenths through the pattern, ping-ponging left and
        # right, accented on the beat, the filter opening over each
        # four-bar phrase, and a breath at the end of every fourth bar.
        for bar in range(bars):
            phrase_pos = ((first_bar + bar) % 4 + 0.5) / 4.0
            for step in range(16):
                if (first_bar + bar) % 4 == 3 and step >= 14:
                    continue
                bright = 0.35 + 0.65 * (phrase_pos * 0.7 + 0.3 * step / 16.0)
                note = _pluck(arp[ARP_PATTERN[step]], pluck_len, bright)
                accent = 1.0 if step % 4 == 0 else (0.8 if step % 2 == 0 else 0.66)
                pan = 0.35 if step % 2 == 0 else -0.35
                at = slot_start + bar * BAR + step * SIXTEENTH
                _add_wrapped(left, at, note, 0.21 * accent * math.sqrt((1.0 - pan) / 2.0))
                _add_wrapped(right, at, note, 0.21 * accent * math.sqrt((1.0 + pan) / 2.0))

    for bar, step, freq, held in MUSIC_LEAD:
        note = _lead_note(freq, held * SIXTEENTH)
        at = bar * BAR + step * SIXTEENTH
        _add_wrapped(left, at, note, 0.13)
        _add_wrapped(right, at, note, 0.13)

    write_wav(OUT_DIR / "music_loop.wav", [left, right])


def make_step(path: Path, f0: float, decay: float, noise_amp: float,
              duration: float = 0.28, level: float = 0.30) -> None:
    """A shoe on a floor: a soft thud. The sole meeting the floor is noise
    from about 120 to 450 Hz over some 40 ms, rising over 3 ms; a faint
    strike on top, noise from 300 Hz to 1.5 kHz fading over 9 ms; a light
    knock of the floor near 140 Hz; and 50 to 90 ms later the roll on to
    the ball of the foot, softer. A crack up at 1 to 6 kHz dying in a
    millisecond, with a little tone of the sole, sounded like clicks; a low
    thump with no strike at all, before that, like a heartbeat.

    The shared generator gives the same draws as before (one stretch of
    noise as long as the sound), so every sound made after the steps
    stays as it was; the new parts draw on their own generator, seeded
    from the step's tuning."""
    n = int(duration * SR)
    floor_noise = brown_noise(n, leak=0.97, gain=0.3)   # the shared draws, kept
    r = random.Random(int(f0 * 1000 + decay * 10 + noise_amp * 100))
    white = _noise_r(r, n)

    def band(low_hz: float, high_hz: float) -> list[float]:
        top = 1.0 - math.exp(-2.0 * math.pi * high_hz / SR)
        bottom = 1.0 - math.exp(-2.0 * math.pi * low_hz / SR)
        upper = _lowpass(_lowpass(white, top), top)
        under = _lowpass(_lowpass(upper, bottom), bottom)
        return [upper[i] - under[i] for i in range(n)]

    sole = band(120.0, 450.0)
    strike = band(300.0, 1500.0)
    floor_low = _lowpass(floor_noise, 1.0 - math.exp(-2.0 * math.pi * 400.0 / SR))
    roll = 0.05 + r.random() * 0.04                      # heel to ball of the foot, s
    knock_hz = 95.0 + f0 * 0.6
    buf = [0.0] * n
    for i in range(n):
        t = i / SR
        rise = min(1.0, t / 0.003)
        hit = sole[i] * 2.4 * math.exp(-t * 26.0) + strike[i] * 0.35 * math.exp(-t * 110.0)
        knock = math.sin(2.0 * math.pi * knock_hz * t) * 0.12 * math.exp(-t * 55.0)
        body = floor_low[i] * noise_amp * 0.25 * math.exp(-t * 35.0)
        tr = t - roll
        toe = 0.0
        if tr > 0.0:
            toe = (sole[i] * 0.9 * math.exp(-tr * 40.0) + strike[i] * 0.1 * math.exp(-tr * 150.0)) * min(1.0, tr / 0.004)
        buf[i] = (hit + knock + body) * rise + toe
    write_wav(path, [buf], normalize_to=level)


def highpassed_noise(n: int, cutoff: float, leak: float = 0.6,
                     gain: float = 0.8) -> list[float]:
    """White-ish noise with the low band removed: the hiss register."""
    noise = brown_noise(n, leak=leak, gain=gain)
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
    lp = 0.0
    out = [0.0] * n
    for i in range(n):
        lp += alpha * (noise[i] - lp)
        out[i] = noise[i] - lp
    return out


def _noise_r(r: random.Random, n: int) -> list[float]:
    return [r.random() * 2.0 - 1.0 for _ in range(n)]


def _lowpass(buf: list[float], alpha: float) -> list[float]:
    """One-pole low-pass; the cutoff is about alpha * SR / 2 pi."""
    out = [0.0] * len(buf)
    acc = 0.0
    for i, value in enumerate(buf):
        acc += alpha * (value - acc)
        out[i] = acc
    return out


def make_surf() -> None:
    """Surf on a ledge: the sea's low body under swells that break as a
    rising hiss and drag back. Two swell periods share the loop, so the
    seam falls where both are quiet."""
    r = random.Random(20260913)
    dur = 16.0
    n = int(SR * dur)
    fade = int(0.6 * SR)
    total = n + fade
    white = _noise_r(r, total)
    body = _lowpass(white, 0.012)
    high = _lowpass(white, 0.25)
    hiss = [w - h for w, h in zip(white, high)]
    out = [0.0] * total
    for i in range(total):
        t = i / SR
        s1 = math.sin(2.0 * math.pi * t * 2.0 / dur)
        s2 = math.sin(2.0 * math.pi * t * 3.0 / dur + 1.3)
        env = max(0.0, 0.55 * s1 + 0.45 * s2) ** 1.6
        out[i] = body[i] * (0.35 + 0.65 * env) * 4.0 + hiss[i] * env * 0.9
    out = loop_crossfade(out, 0.6)
    write_wav(OUT_DIR / "surf_loop.wav", [out], normalize_to=0.45)


def make_wind() -> None:
    """Wind off the water: filtered noise breathing in gusts, quiet."""
    r = random.Random(20260914)
    dur = 12.0
    n = int(SR * dur)
    fade = int(0.5 * SR)
    total = n + fade
    white = _noise_r(r, total)
    low = _lowpass(white, 0.05)
    mid = _lowpass(white, 0.18)
    out = [0.0] * total
    for i in range(total):
        t = i / SR
        gust = 0.5 + 0.3 * math.sin(2.0 * math.pi * t * 1.0 / dur + 0.4) \
            + 0.2 * math.sin(2.0 * math.pi * t * 3.0 / dur + 2.0)
        gust = max(0.0, gust)
        out[i] = low[i] * (0.4 + 0.6 * gust) * 3.0 + (mid[i] - low[i]) * gust * gust * 1.2
    out = loop_crossfade(out, 0.5)
    write_wav(OUT_DIR / "wind_loop.wav", [out], normalize_to=0.35)


def make_river() -> None:
    """A stream over stones: a low rush that never stops, a mid-band
    chatter of eddies breathing on several slow cycles that share the
    loop, and the odd bubble — a short falling chirp. Its own RNG, so
    the older files stay byte-identical."""
    r = random.Random(20260918)
    dur = 10.0
    n = int(SR * dur)
    fade = int(0.5 * SR)
    total = n + fade
    white = _noise_r(r, total)
    low = _lowpass(white, 0.04)
    mid = _lowpass(white, 0.16)
    high = _lowpass(white, 0.45)
    out = [0.0] * total
    for i in range(total):
        t = i / SR
        eddy = 0.55 + 0.25 * math.sin(2.0 * math.pi * t * 3.0 / dur + 0.9) \
            + 0.2 * math.sin(2.0 * math.pi * t * 7.0 / dur + 2.4)
        eddy = max(0.0, eddy)
        out[i] = low[i] * 2.2 + (mid[i] - low[i]) * (0.6 + 0.9 * eddy) * 1.6 \
            + (high[i] - mid[i]) * eddy * eddy * 0.9
    bubbles = int(dur * 6)
    for _b in range(bubbles):
        start = int(r.random() * n)
        f0 = r.uniform(900.0, 1600.0)
        length = int(SR * r.uniform(0.02, 0.05))
        phase = 0.0
        for k in range(length):
            tt = k / length
            f = f0 * (0.55 ** tt)
            phase += 2.0 * math.pi * f / SR
            env = math.sin(math.pi * tt) ** 2
            idx = (start + k) % total
            out[idx] += math.sin(phase) * env * 0.16
    out = loop_crossfade(out, 0.5)
    write_wav(OUT_DIR / "river_loop.wav", [out], normalize_to=0.40)


def make_gull(path: Path, calls: list[tuple[float, float, float, float]],
              r: random.Random) -> None:
    """A herring gull: a reedy descending cry — a stack of harmonics
    under a fast vibrato, with a scratch at the onset. calls are
    (start Hz, end Hz, length s, gap s), one per note."""
    out: list[float] = []
    phase = 0.0
    for f0, f1, length, gap in calls:
        m = int(SR * length)
        for i in range(m):
            t = i / m
            tt = i / SR
            f = f0 * (f1 / f0) ** t
            vib = 1.0 + 0.025 * math.sin(2.0 * math.pi * 38.0 * tt)
            phase += 2.0 * math.pi * f * vib / SR
            attack = min(1.0, tt / 0.015)
            release = min(1.0, (length - tt) / (0.3 * length))
            env = attack * release
            tone = (math.sin(phase) + 0.55 * math.sin(2.0 * phase) + 0.35 * math.sin(3.0 * phase)
                    + 0.2 * math.sin(4.0 * phase) + 0.12 * math.sin(5.0 * phase))
            scratch = (r.random() * 2.0 - 1.0) * 0.10 * (1.0 - t) ** 2
            out.append((tone * 0.5 + scratch) * env)
        out.extend([0.0] * int(SR * gap))
    write_wav(path, [out], normalize_to=0.40)


def make_gulls() -> None:
    r = random.Random(20260915)
    make_gull(OUT_DIR / "gull_1.wav", [(1250.0, 820.0, 0.75, 0.05)], r)
    make_gull(OUT_DIR / "gull_2.wav",
              [(1150.0, 950.0, 0.16, 0.08)] * 4 + [(1300.0, 800.0, 0.55, 0.05)], r)
    make_gull(OUT_DIR / "gull_3.wav",
              [(1380.0, 900.0, 0.45, 0.12), (1300.0, 880.0, 0.45, 0.05)], r)


def make_rain() -> None:
    """A light drizzle: a soft, even hiss with the top rolled off, a
    faint wash of water running in the gutters under it, and now and
    then a single gentle drop close by. Seamless over ten seconds."""
    r = random.Random(20260925)
    dur = 10.0
    n = int(SR * dur)
    fade = int(0.5 * SR)
    total = n + fade
    white = _noise_r(r, total)
    low = _lowpass(white, 0.02)
    soft = _lowpass(white, 0.12)
    softer = _lowpass(soft, 0.35)
    out = [0.0] * total
    for i in range(total):
        t = i / SR
        swell = 0.9 + 0.1 * math.sin(2.0 * math.pi * t * 2.0 / dur + 0.3)
        out[i] = ((softer[i] - low[i]) * 1.0 + low[i] * 0.6) * swell
    for _ in range(int(dur * 14)):
        start = int(r.random() * n)
        f0 = r.uniform(900.0, 2200.0)
        amp = r.uniform(0.02, 0.10)
        length = int(SR * 0.03)
        for k in range(length):
            t = k / SR
            env = math.exp(-t / 0.006) * min(1.0, t / 0.001)
            out[(start + k) % total] += math.sin(2.0 * math.pi * f0 * t) * env * amp
    out = loop_crossfade(out, 0.5)
    write_wav(OUT_DIR / "rain_loop.wav", [out], normalize_to=0.30)


def make_gale() -> None:
    """A gale: the wind loop's big brother, a roaring low band that
    gusts hard on slow cycles, and a thin moan where it finds an edge,
    rising and falling with the gusts."""
    r = random.Random(20260926)
    dur = 14.0
    n = int(SR * dur)
    fade = int(0.7 * SR)
    total = n + fade
    white = _noise_r(r, total)
    low = _lowpass(white, 0.035)
    mid = _lowpass(white, 0.20)
    out = [0.0] * total
    phase = 0.0
    for i in range(total):
        t = i / SR
        gust = 0.55 + 0.30 * math.sin(2.0 * math.pi * t * 2.0 / dur + 0.4) \
            + 0.25 * math.sin(2.0 * math.pi * t * 5.0 / dur + 1.9)
        gust = max(0.0, gust)
        phase += 2.0 * math.pi * (310.0 + 140.0 * gust) / SR
        moan = math.sin(phase) * max(0.0, gust - 0.55) ** 2 * 0.35
        out[i] = low[i] * (0.5 + 0.8 * gust) * 3.2 + (mid[i] - low[i]) * gust * gust * 1.6 + moan * 0.05
    out = loop_crossfade(out, 0.7)
    write_wav(OUT_DIR / "gale_loop.wav", [out], normalize_to=0.40)


def make_thunder(path: Path, r: random.Random, crack: float, length: float,
                 bumps: int, darkness: float) -> None:
    """Thunder: a crack (a split second of broadband tearing, several
    tears in a row) when the stroke is close, then the roll: brown
    noise under an envelope of rumbles, each a stretch of the channel
    heard later from further along it, decaying. darkness is the
    low-pass on the roll: distance takes the top off."""
    n = int(SR * length)
    white = _noise_r(r, n)
    roll_src = _lowpass(_lowpass(white, 0.012 * (1.0 - darkness) + 0.002), 0.05)
    env = [0.0] * n
    for b in range(bumps):
        at = r.uniform(0.05, 0.55) * length * (b + 1) / bumps
        width = r.uniform(0.4, 1.4)
        amp = r.uniform(0.5, 1.0) * math.exp(-at / (0.35 * length))
        for i in range(n):
            d = (i / SR - at) / width
            if -3.0 < d < 8.0:
                env[i] += amp * (math.exp(-d * d) if d < 0.0 else math.exp(-d * 0.7))
    out = [roll_src[i] * env[i] * 9.0 for i in range(n)]
    if crack > 0.0:
        tears = _lowpass(white, 0.6)
        for k in range(4):
            start = int(SR * (0.02 + 0.07 * k + r.uniform(0.0, 0.03)))
            m = int(SR * 0.18)
            for j in range(m):
                t = j / SR
                e = math.exp(-t / 0.045) * min(1.0, t / 0.002) * (1.0 - 0.18 * k)
                if start + j < n:
                    out[start + j] += tears[start + j] * e * crack * 1.4
    # Fade the last half second so nothing is cut off.
    tail = int(0.5 * SR)
    for i in range(tail):
        out[n - tail + i] *= 1.0 - i / tail
    write_wav(path, [out], normalize_to=0.55)


def make_thunders() -> None:
    r = random.Random(20260927)
    make_thunder(OUT_DIR / "thunder_near.wav", r, crack=1.0, length=9.0, bumps=5, darkness=0.2)
    make_thunder(OUT_DIR / "thunder_1.wav", r, crack=0.0, length=10.0, bumps=6, darkness=0.6)
    make_thunder(OUT_DIR / "thunder_2.wav", r, crack=0.0, length=12.0, bumps=7, darkness=0.85)
    make_thunder(OUT_DIR / "thunder_3.wav", r, crack=0.0, length=15.0, bumps=9, darkness=0.92)


def make_bell(path: Path, f0: float, bright: float) -> None:
    """A bell buoy's bell: bronze, struck by a free clapper as the buoy
    rolls. The partials of a heavy bell (the hum an octave under the
    strike, the strike, the minor third, the fifth, the octave, the
    upper partials) each ring out at their own rate, the hum longest;
    each is a pair a fraction of a hertz apart, as a cast bell never is
    quite round, which gives the slow shimmer. Over them, the clang of
    the clapper: a few hundredths of a second of high, fast-dying
    partials. bright is how hard it struck. Pure sines, no RNG."""
    duration = 7.0
    n = int(duration * SR)
    partials = [(0.5, 0.45, 0.35, 0.21), (1.0, 1.0, 0.7, 0.37), (1.19, 0.5, 1.0, 0.53),
                (1.50, 0.28, 1.4, 0.61), (2.0, 0.40 * bright, 1.9, 0.83), (2.51, 0.22 * bright, 2.6, 0.97),
                (3.01, 0.14 * bright, 3.4, 1.21), (4.07, 0.07 * bright, 5.0, 1.43)]
    clang = [(5.3, 0.30), (6.9, 0.22), (8.4, 0.16), (10.2, 0.10)]
    buf = [0.0] * n
    for i in range(n):
        t = i / SR
        v = 0.0
        for ratio, amp, decay, split in partials:
            f = f0 * ratio
            env = math.exp(-t * decay)
            v += amp * env * 0.5 * (math.sin(2.0 * math.pi * f * t) + math.sin(2.0 * math.pi * (f + split) * t + 0.7))
        for ratio, amp in clang:
            v += amp * bright * math.sin(2.0 * math.pi * f0 * ratio * t) * math.exp(-t * 45.0)
        buf[i] = v * min(1.0, t / 0.0015)
    tail = int(0.4 * SR)
    for i in range(tail):
        buf[n - tail + i] *= 1.0 - i / tail
    write_wav(path, [buf], normalize_to=0.45)


def make_bells() -> None:
    make_bell(OUT_DIR / "bell_1.wav", 330.0, 1.0)
    make_bell(OUT_DIR / "bell_2.wav", 330.0, 0.55)


def _bandpass(buf: list[float], low_alpha: float, high_alpha: float) -> list[float]:
    """The band between two one-pole low-passes."""
    hi = _lowpass(buf, high_alpha)
    lo = _lowpass(buf, low_alpha)
    return [h - l for h, l in zip(hi, lo)]


def make_leaves() -> None:
    """Wind in a summer wood's leaves: a soft roar of the canopy under a
    fine rustle — countless short ticks of leaf on leaf in the upper
    band, thick in the gusts and sparse between them. Two gust cycles
    share the loop."""
    r = random.Random(20261003)
    dur = 14.0
    n = int(SR * dur)
    fade = int(0.7 * SR)
    total = n + fade
    white = _noise_r(r, total)
    roar = _bandpass(white, 0.02, 0.09)
    hiss = _bandpass(white, 0.25, 0.75)
    gust = [0.0] * total
    for i in range(total):
        t = i / SR
        g = 0.5 + 0.3 * math.sin(2.0 * math.pi * t * 2.0 / dur + 0.7) \
            + 0.2 * math.sin(2.0 * math.pi * t * 5.0 / dur + 2.9)
        gust[i] = max(0.05, g)
    out = [roar[i] * (0.3 + 0.7 * gust[i]) * 1.6 + hiss[i] * gust[i] * 0.25 for i in range(total)]
    # The rustle: ticks, each a few milliseconds of bright noise.
    ticks = int(dur * 900)
    for _k in range(ticks):
        start = int(r.random() * total)
        if r.random() > gust[start] ** 1.5:
            continue
        length = int(SR * r.uniform(0.002, 0.012))
        amp = r.uniform(0.05, 0.3) * gust[start]
        last = 0.0
        for k in range(length):
            env = math.sin(math.pi * k / length)
            w = r.random() * 2.0 - 1.0
            out[(start + k) % total] += (w - last) * env * amp
            last = w
    out = loop_crossfade(out, 0.7)
    write_wav(OUT_DIR / "leaves_loop.wav", [out], normalize_to=0.35)


def make_grass_wind() -> None:
    """Wind over open grass, as two steady loops the world swells by
    its own gusts: the low rush of moving air, and the hiss of long
    grass bending, a fine rustle of blade on blade."""
    r = random.Random(20261008)
    dur = 12.0
    n = int(SR * dur)
    fade = int(0.8 * SR)
    total = n + fade
    white = _noise_r(r, total)
    air = _bandpass(white, 0.006, 0.04)
    out = loop_crossfade(air, 0.8)
    write_wav(OUT_DIR / "air_loop.wav", [out], normalize_to=0.35)

    r = random.Random(20261009)
    dur = 10.0
    n = int(SR * dur)
    fade = int(0.6 * SR)
    total = n + fade
    white = _noise_r(r, total)
    hiss = _bandpass(white, 0.12, 0.55)
    out = [h * 0.5 for h in hiss]
    ticks = int(dur * 1400)
    for _k in range(ticks):
        start = int(r.random() * total)
        length = int(SR * r.uniform(0.003, 0.02))
        amp = r.uniform(0.03, 0.16)
        last = 0.0
        for k in range(length):
            env = math.sin(math.pi * k / length)
            w = r.random() * 2.0 - 1.0
            out[(start + k) % total] += (w - last) * env * amp
            last = w
    out = loop_crossfade(out, 0.6)
    write_wav(OUT_DIR / "grass_hiss_loop.wav", [out], normalize_to=0.35)


def make_engine() -> None:
    """A 1940s pickup's six-cylinder at idle, as a 2 s loop the game
    raises in pitch with the engine's speed: a firing every 1/32 s,
    each a short thump through the exhaust (a damped low tone and a
    burst of dull noise), the six cylinders each a little different, so
    the beat lopes; under it a faint mechanical whir. Every firing
    falls on the loop's own grid, so the seam is a firing like any
    other."""
    r = random.Random(20261013)
    dur = 2.0
    n = int(SR * dur)
    fire = 32.0
    count = int(dur * fire)
    out = [0.0] * n
    cyl = [r.uniform(0.75, 1.0) for _ in range(6)]
    for k in range(count):
        start = int(k * n / count)
        amp = cyl[k % 6] * r.uniform(0.92, 1.0)
        length = int(0.03 * SR)
        burst = []
        last = 0.0
        for i in range(length):
            t = i / SR
            env = math.exp(-t / 0.008)
            last += 0.08 * ((r.random() * 2.0 - 1.0) - last)
            burst.append((math.sin(2.0 * math.pi * 85.0 * t) * 0.8 + last * 3.0) * env * amp)
        _add_wrapped(out, start, burst, 1.0)
    whir_f = quantize(410.0, dur)
    for i in range(n):
        out[i] += 0.03 * math.sin(2.0 * math.pi * whir_f * i / SR)
    pre = int(0.1 * SR)
    x = _lowpass(_lowpass(out[-pre:] + out, 0.12), 0.12)[pre:]
    write_wav(OUT_DIR / "engine_loop.wav", [x], normalize_to=0.4)


def make_crickets() -> None:
    """A summer night in a meadow: field crickets near and far, each
    chirping three or four pulses of a pure note round 4.5 kHz at its
    own steady rate, and under them the even, pulsing trill of snowy
    tree crickets in the wood at 2.8 kHz. Every rate is a whole number
    of chirps a loop, so the loop is seamless."""
    r = random.Random(20261004)
    dur = 10.0
    n = int(SR * dur)
    out = [0.0] * n
    for _c in range(7):
        freq = quantize(r.uniform(4200.0, 5000.0), dur)
        chirps = r.randint(14, 26)
        period = n // chirps
        offset = r.randrange(period)
        pulses = r.choice([3, 3, 4])
        amp = r.uniform(0.15, 1.0) ** 2
        pulse = int(SR * 0.016)
        gap = int(SR * 0.014)
        for c in range(chirps):
            base = offset + c * period
            for p in range(pulses):
                start = base + p * (pulse + gap)
                for k in range(pulse):
                    env = math.sin(math.pi * k / pulse) ** 2
                    idx = (start + k) % n
                    out[idx] += math.sin(2.0 * math.pi * freq * idx / SR) * env * amp * 0.3
    # The tree crickets: a soft trill, two or three to a second, all in step.
    trill = quantize(2800.0, dur)
    beats = int(dur * 2.4)
    for i in range(n):
        t = i / SR
        swell = math.sin(math.pi * ((t * beats / dur) % 1.0)) ** 3
        flutter = 0.5 + 0.5 * math.sin(2.0 * math.pi * 50.0 * t)
        out[i] += math.sin(2.0 * math.pi * trill * t) * swell * flutter * 0.08
    write_wav(OUT_DIR / "crickets_loop.wav", [out], normalize_to=0.35)


def _whistle(out: list[float], at: float, f0: float, f1: float, length: float,
             amp: float, vib: float = 0.0, harm: float = 0.0, attack: float = 0.02) -> None:
    """One whistled note, gliding from f0 to f1, with an optional vibrato
    (Hz) and a little second harmonic for a fluty tone."""
    start = int(at * SR)
    m = int(length * SR)
    phase = 0.0
    while len(out) < start + m + 1:
        out.append(0.0)
    for k in range(m):
        t = k / m
        tt = k / SR
        f = f0 + (f1 - f0) * t
        if vib > 0.0:
            f *= 1.0 + 0.02 * math.sin(2.0 * math.pi * vib * tt)
        phase += 2.0 * math.pi * f / SR
        env = min(1.0, tt / attack) * min(1.0, (length - tt) / max(attack, 0.25 * length))
        out[start + k] += (math.sin(phase) + harm * math.sin(2.0 * phase)) * env * amp


def make_birds() -> None:
    """Birds of a New England wood in June, as whistles: the
    white-throated sparrow's 'old Sam Peabody, Peabody, Peabody', the
    chickadee's 'fee-bee', the robin's carol, the wood thrush's
    flute phrase and its double-voiced trill, and at night the barred
    owl's 'who cooks for you, who cooks for you all'. Each from its own
    RNG."""
    r = random.Random(20261005)

    # White-throated sparrow: a long note, a higher one, then three
    # triplets on the higher pitch.
    out: list[float] = []
    lo = r.uniform(3000.0, 3200.0)
    hi = lo * 1.26
    _whistle(out, 0.05, lo, lo, 0.7, 0.8)
    _whistle(out, 0.85, hi, hi * 0.995, 0.65, 0.9)
    at = 1.6
    for _t in range(3):
        for _k in range(3):
            _whistle(out, at, hi, hi, 0.13, 0.85, attack=0.01)
            at += 0.16
        at += 0.06
    out.extend([0.0] * int(0.2 * SR))
    write_wav(OUT_DIR / "bird_whitethroat.wav", [out], normalize_to=0.45)

    # Chickadee: 'fee' and a lower 'bee' with a catch in it.
    out = []
    _whistle(out, 0.05, 4000.0, 3950.0, 0.38, 0.9)
    _whistle(out, 0.5, 3450.0, 3400.0, 0.16, 0.8)
    _whistle(out, 0.68, 3420.0, 3380.0, 0.18, 0.75)
    out.extend([0.0] * int(0.2 * SR))
    write_wav(OUT_DIR / "bird_chickadee.wav", [out], normalize_to=0.40)

    # Robin: four phrases of two or three quick slurred notes.
    out = []
    at = 0.05
    for _p in range(r.randint(4, 6)):
        for _s in range(r.choice([2, 3])):
            f0 = r.uniform(2200.0, 2900.0)
            f1 = f0 * r.uniform(0.8, 1.2)
            _whistle(out, at, f0, f1, r.uniform(0.12, 0.2), 0.8, vib=r.uniform(30.0, 60.0), harm=0.15, attack=0.01)
            at += r.uniform(0.17, 0.24)
        at += r.uniform(0.25, 0.45)
    out.extend([0.0] * int(0.2 * SR))
    write_wav(OUT_DIR / "bird_robin.wav", [out], normalize_to=0.40)

    # Wood thrush: a few soft notes, a fluted 'ee-o-lay', then a trill of
    # two voices at once.
    for v in (1, 2):
        out = []
        at = 0.05
        for _k in range(3):
            f = r.uniform(1300.0, 1700.0)
            _whistle(out, at, f, f, 0.07, 0.35, harm=0.3, attack=0.01)
            at += 0.11
        at += 0.08
        for _k in range(3):
            f = r.uniform(1800.0, 3000.0)
            _whistle(out, at, f, f * r.uniform(0.95, 1.05), r.uniform(0.15, 0.24), 0.9, vib=8.0, harm=0.25)
            at += r.uniform(0.2, 0.28)
        start = int(at * SR)
        m = int(0.35 * SR)
        while len(out) < start + m + 1:
            out.append(0.0)
        pa = 0.0
        pb = 0.0
        fa = r.uniform(3500.0, 4500.0)
        fb = r.uniform(5000.0, 6200.0)
        for k in range(m):
            tt = k / SR
            env = min(1.0, tt / 0.02) * min(1.0, (0.35 - tt) / 0.1)
            pa += 2.0 * math.pi * fa * (1.0 + 0.15 * math.sin(2.0 * math.pi * 55.0 * tt)) / SR
            pb += 2.0 * math.pi * fb * (1.0 + 0.12 * math.sin(2.0 * math.pi * 70.0 * tt + 1.0)) / SR
            out[start + k] += (math.sin(pa) * 0.4 + math.sin(pb) * 0.3) * env
        out.extend([0.0] * int(0.4 * SR))
        write_wav(OUT_DIR / f"bird_thrush_{v}.wav", [out], normalize_to=0.40)

    # Barred owl: eight hoots in the rhythm of the phrase, the last sliding
    # down. A hoot is a low note rich in harmonics, breathy at the start.
    out = []
    rhythm = [(0.0, 0.22, 1.0), (0.35, 0.18, 1.05), (0.6, 0.18, 1.08), (0.85, 0.5, 1.12),
              (1.75, 0.22, 1.0), (2.1, 0.18, 1.05), (2.35, 0.18, 1.08), (2.6, 0.9, 1.15)]
    for k, (at, length, lift) in enumerate(rhythm):
        start = int(at * SR)
        m = int(length * SR)
        while len(out) < start + m + 1:
            out.append(0.0)
        phase = 0.0
        last = k == len(rhythm) - 1
        for i in range(m):
            t = i / m
            tt = i / SR
            f = 380.0 * lift * (1.0 - (0.35 * t * t if last else 0.04 * t))
            phase += 2.0 * math.pi * f / SR
            env = min(1.0, tt / 0.04) * min(1.0, (length - tt) / (0.4 * length))
            tone = math.sin(phase) + 0.4 * math.sin(2.0 * phase) + 0.15 * math.sin(3.0 * phase)
            breath = (r.random() * 2.0 - 1.0) * 0.08 * (1.0 - t)
            out[start + i] += (tone * 0.5 + breath) * env
    out.extend([0.0] * int(0.3 * SR))
    write_wav(OUT_DIR / "bird_owl.wav", [out], normalize_to=0.45)


def make_knock(path: Path, r: random.Random, f0: float, decay: float, rumble_hz: float) -> None:
    """A heavy stone ball striking a stone wall. Large stone is heavy and
    damped: it does not ring in the middle register as wood does, so
    there is no tonal knock. A deep body thump falling in pitch as the
    contact springs back; a heavy low rumble carried through the mass
    (noise between about 60 Hz and rumble_hz); grit crushed at the
    contact, a dense spatter of crackles over 60 ms with a short crunch
    of noise under them; then gentle saturation, which adds the thump's
    harmonics at 100 to 200 Hz, where small speakers still play and the
    ear hears the deep fundamental from them. Its own generator, so the
    other files stay as they are."""
    duration = 0.8
    n = int(duration * SR)
    noise = _noise_r(r, n)
    top = 1.0 - math.exp(-2.0 * math.pi * rumble_hz / SR)
    bottom = 1.0 - math.exp(-2.0 * math.pi * 60.0 / SR)
    low = _lowpass(_lowpass(_lowpass(noise, top), top), top)
    under = _lowpass(low, bottom)
    rumble = [low[i] - under[i] for i in range(n)]
    # Grit: many tiny impulses, denser at first, softened to crackle.
    grit = [0.0] * n
    for _ in range(45):
        at = int(r.random() ** 2 * 0.06 * SR)
        grit[at] += (r.random() * 2.0 - 1.0) * (1.0 - at / (0.06 * SR))
    soft = 1.0 - math.exp(-2.0 * math.pi * 3500.0 / SR)
    grit = _lowpass(_lowpass(grit, soft), soft)
    # Crunch: noise from about 800 Hz to 4 kHz in the first 25 ms.
    hiss = _noise_r(r, n)
    upper = _lowpass(_lowpass(hiss, 1.0 - math.exp(-2.0 * math.pi * 4000.0 / SR)), 1.0 - math.exp(-2.0 * math.pi * 4000.0 / SR))
    lower = _lowpass(upper, 1.0 - math.exp(-2.0 * math.pi * 800.0 / SR))
    crunch = [upper[i] - lower[i] for i in range(n)]
    phase = 0.0
    buf = [0.0] * n
    for i in range(n):
        t = i / SR
        attack = min(1.0, t / 0.0015)
        phase += 2.0 * math.pi * (f0 * (0.64 + 0.36 * math.exp(-t * 12.0))) / SR
        body = 1.6 * math.sin(phase) * math.exp(-t * decay)
        boom = rumble[i] * 70.0 * math.exp(-t * 10.0)
        crackle = grit[i] * 70.0
        crush = crunch[i] * 3.0 * math.exp(-t * 120.0)
        buf[i] = (body + boom + crackle + crush) * attack
    peak = max(abs(v) for v in buf)
    drive = 2.2
    buf = [math.tanh(drive * v / peak) / math.tanh(drive) for v in buf]
    write_wav(path, [buf], normalize_to=0.9)


def make_knocks() -> None:
    r = random.Random(20261003)
    for idx, (f0, decay, rumble_hz) in enumerate([(55.0, 7.0, 240.0), (50.0, 6.5, 220.0), (60.0, 7.5, 260.0)], start=1):
        make_knock(OUT_DIR / f"knock_{idx}.wav", r, f0, decay, rumble_hz)


def make_swoosh() -> None:
    """Seamless broadband noise, gently tilted toward the bass (each octave
    about 1.5 dB quieter than the one below), for the rush of air past a
    moving object: the game band-passes it at a pitch set by the object's
    speed over its size and sets its loudness by speed and size. Its own
    generator, so the other files stay as they are."""
    r = random.Random(20261004)
    n = int(6.0 * SR)
    white = _noise_r(r, n + int(0.5 * SR))
    tilted = _lowpass(white, 0.35)
    buf = [0.6 * w + 0.4 * t * 2.2 for w, t in zip(white, tilted)]
    out = loop_crossfade(buf, 0.5)
    write_wav(OUT_DIR / "swoosh_loop.wav", [out], normalize_to=0.5)


def make_pebble_step(path: Path, r: random.Random) -> None:
    """A foot on wet pebbles: a soft thud of the foot (noise at 100 to
    350 Hz); the pebbles shifting under it, a spatter of small stone
    knocks over the first 120 ms, each a ping of 1.2 to 3.5 kHz dying in
    about 2.5 ms, damped and dulled by the water; a short wet squelch, noise
    at 250 Hz to 1.1 kHz swelling and fading over about a tenth of a
    second; and a small bubble, a tone rising from about 350 to 900 Hz."""
    duration = 0.4
    n = int(duration * SR)
    white = _noise_r(r, n)

    def band(low_hz: float, high_hz: float) -> list[float]:
        top = 1.0 - math.exp(-2.0 * math.pi * high_hz / SR)
        bottom = 1.0 - math.exp(-2.0 * math.pi * low_hz / SR)
        upper = _lowpass(_lowpass(white, top), top)
        under = _lowpass(_lowpass(upper, bottom), bottom)
        return [upper[i] - under[i] for i in range(n)]

    thud = band(100.0, 350.0)
    wet = band(250.0, 1100.0)
    grains = [0.0] * n
    for _ in range(26):
        t0 = 0.004 + r.random() ** 1.5 * 0.12
        f = 1200.0 + r.random() * 2300.0
        amp = (0.3 + 0.7 * r.random()) * math.exp(-t0 * 12.0)
        start = int(t0 * SR)
        for k in range(int(0.012 * SR)):
            if start + k < n:
                tk = k / SR
                grains[start + k] += amp * math.sin(2.0 * math.pi * f * tk) * math.exp(-tk * 400.0)
    soft = 1.0 - math.exp(-2.0 * math.pi * 3500.0 / SR)
    grains = _lowpass(_lowpass(grains, soft), soft)
    squelch_at = 0.035 + r.random() * 0.02
    bubble_at = 0.05 + r.random() * 0.03
    phase = 0.0
    buf = [0.0] * n
    for i in range(n):
        t = i / SR
        rise = min(1.0, t / 0.003)
        foot = thud[i] * 2.2 * math.exp(-t * 24.0) * rise
        x = t / squelch_at
        swell = x * math.exp(1.0 - x)
        squelch = wet[i] * 1.2 * swell * swell
        bub = 0.0
        tb = t - bubble_at
        if tb > 0.0:
            phase += 2.0 * math.pi * (350.0 + 550.0 * min(1.0, tb / 0.04)) / SR
            bub = math.sin(phase) * 0.18 * math.exp(-tb * 45.0)
        buf[i] = foot + grains[i] * 0.55 + squelch + bub
    write_wav(path, [buf], normalize_to=0.32)


def make_pebble_steps() -> None:
    r = random.Random(20261005)
    for idx in range(1, 5):
        make_pebble_step(OUT_DIR / f"step_pebbles_{idx}.wav", r)


def make_wade_step(path: Path, r: random.Random) -> None:
    """A step through water a little over the ankle: the leg pushing
    through it, a rush of noise at 300 Hz to 2.5 kHz swelling over about
    a tenth of a second and dying over a quarter; the water thrown up
    falling back as a spatter of drops over the next 300 ms, each a
    short ping of 1.5 to 4 kHz; a few bubbles, tones rising from about
    500 Hz to 1.4 kHz; and the sole on the glass under the water, a
    soft thud at 90 to 300 Hz."""
    duration = 0.6
    n = int(duration * SR)
    white = _noise_r(r, n)

    def band(low_hz: float, high_hz: float) -> list[float]:
        top = 1.0 - math.exp(-2.0 * math.pi * high_hz / SR)
        bottom = 1.0 - math.exp(-2.0 * math.pi * low_hz / SR)
        upper = _lowpass(_lowpass(white, top), top)
        under = _lowpass(_lowpass(upper, bottom), bottom)
        return [upper[i] - under[i] for i in range(n)]

    rush = band(300.0, 2500.0)
    thud = band(90.0, 300.0)
    drops = [0.0] * n
    for _ in range(34):
        t0 = 0.06 + r.random() ** 1.3 * 0.3
        f = 1500.0 + r.random() * 2500.0
        amp = (0.2 + 0.8 * r.random()) * math.exp(-(t0 - 0.06) * 6.0)
        start = int(t0 * SR)
        for k in range(int(0.02 * SR)):
            if start + k < n:
                tk = k / SR
                chirp = f * (1.0 + 0.6 * tk / 0.02)
                drops[start + k] += amp * math.sin(2.0 * math.pi * chirp * tk) * math.exp(-tk * 260.0)
    bubbles = [0.0] * n
    for _ in range(4):
        t0 = 0.04 + r.random() * 0.2
        f_lo = 450.0 + r.random() * 200.0
        f_hi = f_lo * (2.0 + r.random())
        amp = 0.4 + 0.6 * r.random()
        start = int(t0 * SR)
        phase = 0.0
        for k in range(int(0.06 * SR)):
            if start + k < n:
                tk = k / SR
                phase += 2.0 * math.pi * (f_lo + (f_hi - f_lo) * min(1.0, tk / 0.03)) / SR
                bubbles[start + k] += amp * math.sin(phase) * math.exp(-tk * 60.0)
    push_at = 0.08 + r.random() * 0.04
    buf = [0.0] * n
    for i in range(n):
        t = i / SR
        x = t / push_at
        swell = x * math.exp(1.0 - x) if x < 1.0 else math.exp(-(t - push_at) * 9.0)
        sole_t = t - 0.03
        sole = thud[i] * 1.4 * math.exp(-sole_t * 30.0) * min(1.0, sole_t / 0.004) if sole_t > 0.0 else 0.0
        buf[i] = rush[i] * 1.6 * swell + drops[i] * 0.35 + bubbles[i] * 0.12 + sole
    write_wav(path, [buf], normalize_to=0.32)


def make_wade_steps() -> None:
    r = random.Random(20261004)
    for idx in range(1, 5):
        make_wade_step(OUT_DIR / f"step_wade_{idx}.wav", r)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("generating audio ->", OUT_DIR)
    make_music()
    make_surf()
    make_wind()
    make_gulls()
    make_river()
    for idx, (f0, decay, noise_amp) in enumerate(
            [(72.0, 16.0, 0.50), (78.0, 18.0, 0.42), (66.0, 15.0, 0.55), (84.0, 17.0, 0.38)],
            start=1):
        make_step(OUT_DIR / f"step_{idx}.wav", f0, decay, noise_amp)
    make_step(OUT_DIR / "land.wav", 46.0, 7.0, 0.50, duration=0.55, level=0.42)
    make_rain()
    make_gale()
    make_thunders()
    make_bells()
    make_leaves()
    make_grass_wind()
    make_engine()
    make_crickets()
    make_birds()
    make_knocks()
    make_swoosh()
    make_pebble_steps()
    make_wade_steps()
    print("done")


if __name__ == "__main__":
    main()
