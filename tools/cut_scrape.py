"""Make the shed crystal's scrape loop from a recording of scraping on wood.

The recording: "Scraping Fingernails Against Wood 2" by F.M.Audio,
Freesound #612763, CC BY 4.0 (credit required; see CREDITS.md), 96 kHz,
24-bit mono, recorded with a contact microphone, about 3.5 s of strokes
one after another. It is kept beside the game's sounds under its
Freesound name. Run from the project root:

    .venv\\Scripts\\python.exe tools\\cut_scrape.py

The stretch from START to END, where the scraping runs on, is taken; its
strokes evened out (divided by its loudness smoothed over 0.2 s, by
LEVEL of the way, so one stroke does not stand out each time the loop
comes round); its ends folded together over 0.15 s so it loops without a
seam; resampled to 48 kHz, its peak set to -7 dB, and written to
game/audio/crystal_scrape_loop.wav (16-bit).
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

AUDIO = Path(__file__).resolve().parents[1] / "game" / "audio"
SOURCE = AUDIO / "612763__fmaudio__scraping-fingernails-against-wood-2.wav"
OUT = AUDIO / "crystal_scrape_loop.wav"
START = 0.55
END = 3.25
LEVEL = 0.7
FOLD = 0.15
RATE = 48000


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        sr = w.getframerate()
        width = w.getsampwidth()
        channels = w.getnchannels()
        raw = w.readframes(w.getnframes())
    if width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        a = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        a = np.where(a >= 1 << 23, a - (1 << 24), a) / float(1 << 23)
    elif width == 2:
        a = np.frombuffer(raw, dtype=np.int16) / 32768.0
    else:
        raise ValueError(f"unexpected sample width {width}")
    return a.reshape(-1, channels).mean(axis=1), sr


def main() -> None:
    a, sr = read_wav(SOURCE)
    piece = a[int(START * sr):int(END * sr)]
    # Even out the strokes.
    win = int(0.2 * sr)
    loud = np.sqrt(np.convolve(piece ** 2, np.ones(win) / win, mode="same")) + 1e-6
    piece = piece / loud ** LEVEL
    # Fold the tail into the head.
    fold = int(FOLD * sr)
    body = piece[:-fold].copy()
    tail = piece[-fold:]
    w = np.linspace(0.0, 1.0, fold)
    body[:fold] = body[:fold] * w + tail * (1.0 - w)
    # To 48 kHz.
    n_out = int(len(body) * RATE / sr)
    out = np.interp(np.arange(n_out) * sr / RATE, np.arange(len(body)), body)
    out *= 10 ** (-7 / 20) / np.max(np.abs(out))
    with wave.open(str(OUT), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((out * 32767).astype(np.int16).tobytes())
    print(f"wrote {OUT.name}: {len(out) / RATE:.2f} s")


if __name__ == "__main__":
    main()
