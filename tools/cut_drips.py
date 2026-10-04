"""Cut single water drops out of BigSoundBank's "Drops of water" recordings.

The recordings (CC0, Joseph Sardin, BigSoundBank #1384-#1387, 48 kHz,
24-bit mono, "many drops of water", indoors) are downloaded by hand into
a folder given on the command line. Run from the project root:

    .venv\\Scripts\\python.exe tools\\cut_drips.py <folder with 1384.wav ...>

A drop's start is where the sound's envelope (absolute value smoothed
over 2 ms) rises past six times the recording's quiet level (its 20th
percentile). A drop is kept when nothing else starts within 0.35 s after
it and its peak is well above the quiet level; it is cut from 5 ms before
its start to 0.35 s after, faded out over the last 80 ms, its peak set to
-6 dB, and written to game/audio/drip_rec_<n>.wav (16-bit, 48 kHz).
Writes the N_KEEP clearest, taken evenly from the three distinct recordings.
"""
from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

OUT_DIR = Path(__file__).resolve().parents[1] / "game" / "audio"
# #1386 is #1385 again: the same audio, sample for sample, under other metadata.
IDS = ["1384", "1385", "1387"]
N_KEEP = 8
AFTER = 0.35
BEFORE = 0.005


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        sr = w.getframerate()
        width = w.getsampwidth()
        channels = w.getnchannels()
        raw = w.readframes(w.getnframes())
    if width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        v = (b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (b[:, 2].astype(np.int32) << 16))
        v = np.where(v >= 1 << 23, v - (1 << 24), v)
        x = v.astype(np.float64) / (1 << 23)
    elif width == 2:
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    else:
        raise ValueError(f"{path.name}: {width * 8}-bit not handled")
    if channels > 1:
        x = x.reshape(-1, channels).mean(axis=1)
    return x, sr


def drops(x: np.ndarray, sr: int) -> list[tuple[int, float]]:
    """(start sample, peak over quiet level) of each isolated drop."""
    k = max(1, int(0.002 * sr))
    env = np.convolve(np.abs(x), np.ones(k) / k, mode="same")
    quiet = np.percentile(env, 20)
    above = env > quiet * 6.0
    starts = []
    i = 0
    gap = int(0.08 * sr)
    while i < len(above):
        if above[i]:
            starts.append(i)
            i += gap
        else:
            i += 1
    kept = []
    after = int(AFTER * sr)
    for j, s in enumerate(starts):
        nxt = starts[j + 1] if j + 1 < len(starts) else len(x)
        if nxt - s < after or s + after > len(x) or s < int(BEFORE * sr):
            continue
        peak = env[s:s + after].max() / max(quiet, 1e-9)
        kept.append((s, peak))
    return kept


def main() -> None:
    folder = Path(sys.argv[1])
    per_file = []
    for id_ in IDS:
        x, sr = read_wav(folder / f"{id_}.wav")
        found = sorted(drops(x, sr), key=lambda d: -d[1])
        print(f"{id_}: {len(found)} isolated drops")
        per_file.append((x, sr, id_, found))
    n = 0
    rank = 0
    while n < N_KEEP:
        took = False
        for x, sr, id_, found in per_file:
            if rank < len(found) and n < N_KEEP:
                s, peak = found[rank]
                a = s - int(BEFORE * sr)
                seg = x[a:s + int(AFTER * sr)].copy()
                fade = int(0.08 * sr)
                seg[-fade:] *= np.linspace(1.0, 0.0, fade)
                seg *= 0.5 / max(np.abs(seg).max(), 1e-9)
                n += 1
                out = OUT_DIR / f"drip_rec_{n}.wav"
                with wave.open(str(out), "wb") as w:
                    w.setnchannels(1)
                    w.setsampwidth(2)
                    w.setframerate(sr)
                    w.writeframes((seg * 32767).astype(np.int16).tobytes())
                print(f"  {out.name}: #{id_} at {s / sr:.2f} s, {20 * np.log10(peak):.0f} dB over quiet")
                took = True
        rank += 1
        if not took:
            break


if __name__ == "__main__":
    main()
