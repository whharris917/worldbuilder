"""Make the loose glass globe's turf sound from the scraping recording.

A stone dragged on grass is the scrape muffled: the turf takes the
bright edge off and leaves a dull rubbing. The same recording as the
shed crystal's scrape ("Scraping Fingernails Against Wood 2" by
F.M.Audio, Freesound #612763, CC BY 4.0; see CREDITS.md and
tools/cut_scrape.py), the same stretch, its strokes evened out, then
low-passed hard (fourth-order Butterworth at CUTOFF Hz), its ends
folded into a loop, at 48 kHz, written to
game/audio/crystal_turf_loop.wav. Run from the project root:

    .venv\\Scripts\\python.exe tools\\cut_turf.py
"""
from __future__ import annotations

import wave

import numpy as np
from scipy.signal import butter, sosfiltfilt

from cut_scrape import FOLD, LEVEL, RATE, SOURCE, START, END, AUDIO, read_wav

OUT = AUDIO / "crystal_turf_loop.wav"
CUTOFF = 300.0


def main() -> None:
    a, sr = read_wav(SOURCE)
    piece = a[int(START * sr):int(END * sr)]
    win = int(0.2 * sr)
    loud = np.sqrt(np.convolve(piece ** 2, np.ones(win) / win, mode="same")) + 1e-6
    piece = piece / loud ** LEVEL
    sos = butter(4, CUTOFF, btype="low", fs=sr, output="sos")
    piece = sosfiltfilt(sos, piece)
    fold = int(FOLD * sr)
    body = piece[:-fold].copy()
    tail = piece[-fold:]
    w = np.linspace(0.0, 1.0, fold)
    body[:fold] = body[:fold] * w + tail * (1.0 - w)
    n_out = int(len(body) * RATE / sr)
    out = np.interp(np.arange(n_out) * sr / RATE, np.arange(len(body)), body)
    out *= 10 ** (-6 / 20) / np.max(np.abs(out))
    with wave.open(str(OUT), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((out * 32767).astype(np.int16).tobytes())
    print(f"wrote {OUT.name}: {len(out) / RATE:.2f} s")


if __name__ == "__main__":
    main()
