"""How the game's sounds come through a laptop's speakers.

Every sound in game/audio is played through a simulated laptop speaker
and compared with its full-range self (good headphones):

  laptop speaker: a 4th-order high-pass at 180 Hz (small drivers give
                  almost nothing below it), a +4 dB presence peak near
                  3 kHz, a gentle roll-off above 12 kHz.

For each sound it reports how much quieter it comes out (loudness here is
K-weighted RMS, as in LUFS; A-weighting, tried first, discounts bass so
much that even thunder seemed to lose nothing), and the share of its
energy in four bands. A sound that loses more than 6 dB on the speaker is
flagged: much of its weight lives below what the speaker plays.

MP3s are decoded with the ffmpeg that comes with imageio_ffmpeg.

Run: .venv\\Scripts\\python.exe tools\\audio_check.py [name filter]
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from scipy import signal

AUDIO = Path(__file__).resolve().parent.parent / "game" / "audio"
SR = 32000
BANDS = [(20, 150), (150, 600), (600, 3000), (3000, 12000)]


def load(path: Path) -> np.ndarray:
    """Mono samples at SR, -1..1. 16-bit WAVs are read directly; anything
    else (other bit depths, MP3, Ogg) is decoded by ffmpeg."""
    sixteen_bit = False
    if path.suffix.lower() == ".wav":
        with wave.open(str(path)) as w:
            sixteen_bit = w.getsampwidth() == 2
    if sixteen_bit:
        with wave.open(str(path)) as w:
            raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768.0
            x = raw.reshape(-1, w.getnchannels()).mean(axis=1)
            rate = w.getframerate()
        if rate != SR:
            x = signal.resample_poly(x, SR, rate)
        return x
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    out = subprocess.run([ffmpeg, "-v", "quiet", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<i2").astype(float) / 32768.0


def laptop(x: np.ndarray) -> np.ndarray:
    high = signal.butter(4, 180.0, "highpass", fs=SR, output="sos")
    low = signal.butter(1, 12000.0, "lowpass", fs=SR, output="sos")
    y = signal.sosfilt(low, signal.sosfilt(high, x))
    # A +4 dB peak at 3 kHz, Q 1 (the RBJ peaking filter).
    a_gain = 10 ** (4.0 / 40.0)
    w0 = 2 * np.pi * 3000.0 / SR
    alpha = np.sin(w0) / 2.0
    b = [1 + alpha * a_gain, -2 * np.cos(w0), 1 - alpha * a_gain]
    a = [1 + alpha / a_gain, -2 * np.cos(w0), 1 - alpha / a_gain]
    return signal.lfilter(b, a, y)


def k_weighted_rms(x: np.ndarray) -> float:
    """RMS after the K-weighting of ITU-R BS.1770 (the measure behind
    LUFS): a +4 dB shelf above about 1.5 kHz and a high-pass near 38 Hz.
    Unlike A-weighting it keeps the bass in the count, so a sound that
    loses its low end on small speakers shows it."""
    shelf_b, shelf_a = signal.iirfilter(2, 1500.0, btype="highpass", ftype="butter", fs=SR)
    hp = signal.butter(2, 38.0, "highpass", fs=SR, output="sos")
    y = signal.sosfilt(hp, x)
    y = y + (10 ** (4.0 / 20.0) - 1.0) * signal.lfilter(shelf_b, shelf_a, y)
    return float(np.sqrt(np.mean(y ** 2)) + 1e-12)


def shares(x: np.ndarray) -> list[float]:
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    energy = [spec[(f >= a) & (f < b)].sum() for a, b in BANDS]
    total = sum(energy) + 1e-12
    return [100.0 * e / total for e in energy]


def main() -> None:
    pick = sys.argv[1] if len(sys.argv) > 1 else ""
    files = sorted(p for p in AUDIO.iterdir() if p.suffix.lower() in (".wav", ".mp3") and pick in p.name)
    print(f"{'sound':24} {'loss on laptop':>15}   energy by band (Hz): " + "  ".join(f"{a}-{b}" for a, b in BANDS))
    for path in files:
        x = load(path)
        if len(x) > SR * 30:
            x = x[: SR * 30]
        loss = 20.0 * np.log10(k_weighted_rms(laptop(x)) / k_weighted_rms(x))
        flag = "  <- weak on speakers" if loss < -6.0 else ""
        bands = "  ".join(f"{s:5.0f}%" for s in shares(x))
        print(f"{path.name:24} {loss:12.1f} dB   {bands}{flag}")


if __name__ == "__main__":
    main()
