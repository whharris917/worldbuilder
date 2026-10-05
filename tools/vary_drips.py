"""Make variations of single water-drop recordings for the light pool's drips.

Run from the project root:

    .venv\\Scripts\\python.exe tools\\vary_drips.py

Reads the drop recordings in SOURCES (from Freesound, in game/audio/,
see drip_one_SOURCE.txt) and writes drip_one_<source>_<step>.wav: each
drop at five playback speeds, from 0.84 to 1.19 (about three semitones
down to three up). A drop played faster is higher and shorter, as a
smaller drop's trapped bubble rings higher and dies sooner; slower is a
larger drop. Each is decoded to mono 48 kHz (ffmpeg, from imageio_ffmpeg),
resampled, trimmed from 3 ms before the sound starts (where it first
passes 5% of its peak), faded out over its last 40 ms, peak set to -6 dB,
written as 16-bit WAV.
"""
from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np

AUDIO = Path(__file__).resolve().parents[1] / "game" / "audio"
SOURCES = {
    "a": "853900__alexzavesa__water-drop-tap-4.wav",
    "b": "863461__robo9418__low-quality-water-drop.wav",
    "c": "868240__noisyredfox__waterdrop.ogg",
}
SPEEDS = [0.84, 0.92, 1.0, 1.09, 1.19]
SR = 48000


def decode(name: str, speed: float) -> np.ndarray:
    """Mono at SR, played back `speed` times as fast (pitch and length together)."""
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    rate = int(round(SR * speed))
    cmd = [ff, "-v", "error", "-i", str(AUDIO / name), "-ac", "1", "-ar", str(SR),
           "-af", f"asetrate={rate},aresample={SR}", "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def shape(x: np.ndarray) -> np.ndarray:
    peak = np.abs(x).max()
    start = max(0, int(np.argmax(np.abs(x) > peak * 0.05)) - int(0.003 * SR))
    x = x[start:].copy()
    fade = min(int(0.04 * SR), len(x) // 2)
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    return x * (0.5 / max(np.abs(x).max(), 1e-9))


def main() -> None:
    for key, name in SOURCES.items():
        for i, speed in enumerate(SPEEDS, start=1):
            y = shape(decode(name, speed))
            out = AUDIO / f"drip_one_{key}{i}.wav"
            with wave.open(str(out), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes((y * 32767).astype(np.int16).tobytes())
            print(f"  {out.name}: {name[:30]} at {speed:.2f}x, {len(y) / SR * 1000:.0f} ms")


if __name__ == "__main__":
    main()
