"""Make the loose glass globe's turf sound: the island's wind, muffled.

The game's own wind (game/audio/wind_loop.wav, made by
tools/generate_audio.py, seamless) low-passed hard (fourth-order
Butterworth at CUTOFF Hz) so it reads as a soft dull rub of the globe on
the grass, filtered round its loop (three copies end to end, the middle
one kept) so it stays seamless, written to
game/audio/crystal_turf_loop.wav. Run from the project root after
generate_audio.py:

    .venv\\Scripts\\python.exe tools\\cut_turf.py
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfiltfilt

AUDIO = Path(__file__).resolve().parents[1] / "game" / "audio"
SOURCE = AUDIO / "wind_loop.wav"
OUT = AUDIO / "crystal_turf_loop.wav"
CUTOFF = 300.0


def main() -> None:
    with wave.open(str(SOURCE), "rb") as w:
        sr = w.getframerate()
        channels = w.getnchannels()
        width = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if width != 2:
        raise ValueError(f"unexpected sample width {width}")
    a = (np.frombuffer(raw, dtype=np.int16) / 32768.0).reshape(-1, channels).mean(axis=1)
    sos = butter(4, CUTOFF, btype="low", fs=sr, output="sos")
    looped = sosfiltfilt(sos, np.tile(a, 3))
    out = looped[len(a):2 * len(a)]
    out *= 10 ** (-6 / 20) / np.max(np.abs(out))
    with wave.open(str(OUT), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes((out * 32767).astype(np.int16).tobytes())
    print(f"wrote {OUT.name}: {len(out) / sr:.2f} s")


if __name__ == "__main__":
    main()
