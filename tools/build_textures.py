"""Generate the stone-tile texture set for the one-bulb study.

One tileable height field, in metres, is built first; every other map
is derived from it, so they agree: mortar is low, dark, rough and
occluded; tiles are high, pale, smoother, with polished patches where
feet wear them. The image covers 2 m square (4 x 4 tiles of 0.5 m), the
same as the ambientCG set beside it.

Maps written to game/textures/generated_tiles/:
  albedo.png     sRGB colour
  roughness.png  linear, 0 to 1
  normal.png     tangent space, OpenGL convention (green toward the
                 image's top), as Godot expects
  height.png     16-bit, 0 lowest to 1 highest
  ao.png         linear, 1 open to 0 fully occluded

Run: .venv\\Scripts\\python.exe tools\\build_textures.py
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

N = 1024                     # pixels a side
SIZE_M = 2.0                 # metres the image covers
TILES = 4                    # tiles a side
PX_M = SIZE_M / N            # metres a pixel
MORTAR_PX = 7                # joint width
BEVEL_PX = 5                 # rounding of a tile's edge
MORTAR_DEPTH = 0.006         # m below the tile face
OUT = Path(__file__).resolve().parent.parent / "game" / "textures" / "generated_tiles"

rng = np.random.default_rng(1874)


def noise(scale_px: float, octaves: int = 1) -> np.ndarray:
    """Tileable noise: white noise low-passed in the frequency domain,
    so it wraps at the image's edges. Mean 0, standard deviation 1."""
    out = np.zeros((N, N))
    for o in range(octaves):
        s = scale_px / (2 ** o)
        f = np.fft.fftfreq(N)
        k2 = f[None, :] ** 2 + f[:, None] ** 2
        spectrum = np.fft.fft2(rng.standard_normal((N, N))) * np.exp(-k2 * (np.pi * s) ** 2)
        layer = np.real(np.fft.ifft2(spectrum))
        out += layer / layer.std() * 0.5 ** o
    return out / out.std()


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    return ndimage.gaussian_filter(a, sigma, mode="wrap")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    tile_px = N // TILES
    y, x = np.mgrid[0:N, 0:N]
    # Distance from each pixel to its tile's nearest edge, in pixels,
    # with the joint centred on the tile boundary.
    lx = (x + MORTAR_PX // 2) % tile_px
    ly = (y + MORTAR_PX // 2) % tile_px
    edge = np.minimum(np.minimum(lx, tile_px - 1 - lx), np.minimum(ly, tile_px - 1 - ly)) - MORTAR_PX / 2
    tile_id = ((y + MORTAR_PX // 2) // tile_px % TILES) * TILES + (x + MORTAR_PX // 2) // tile_px % TILES
    mortar = edge < 0

    # Each tile laid a little high or low and a little tilted.
    lift = rng.normal(0, 0.0006, TILES * TILES)[tile_id]
    tilt_x = rng.normal(0, 0.0015, TILES * TILES)[tile_id]
    tilt_y = rng.normal(0, 0.0015, TILES * TILES)[tile_id]
    tilt = (tilt_x * (lx - tile_px / 2) + tilt_y * (ly - tile_px / 2)) * PX_M
    bevel = np.clip(edge / BEVEL_PX, 0, 1)
    bevel = np.sin(bevel * np.pi / 2)                       # a rounded arris
    face = 0.00015 * noise(40, 3) + 0.00004 * noise(4, 2)   # the stone's own unevenness, honed flat
    pits = np.where(noise(2) > 2.6, -0.0008, 0.0)           # small pits in the face
    height = np.where(mortar, -MORTAR_DEPTH + 0.0008 * noise(3, 2),
                      -MORTAR_DEPTH * (1 - bevel) + bevel * (lift + tilt + face + pits))

    # Normal from the height's slope, in metres per metre; wrapped so
    # the image tiles. Image rows run down, the OpenGL green runs up.
    dhdx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) / (2 * PX_M)
    dhdy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) / (2 * PX_M)
    normal = np.stack([-dhdx, dhdy, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)

    # Occlusion: how far a point sits below its surroundings.
    below = np.clip(blur(height, 6) - height, 0, None)
    ao = np.clip(1 - below / 0.004, 0.35, 1)

    # Colour: a pale limestone, each tile its own shade, clouded and
    # speckled; the joints a grey grout, darker where they are deep.
    shade = rng.normal(0, 0.05, TILES * TILES)[tile_id]
    stone = np.array([0.62, 0.57, 0.48])
    cloud = 0.07 * noise(60, 3) + 0.03 * noise(8, 2)
    speckle = np.where(noise(1.5) > 2.2, -0.12, 0.0)
    base = stone[None, None, :] * (1 + shade + cloud + speckle)[..., None]
    grout = np.array([0.30, 0.29, 0.27])[None, None, :] * (1 + 0.1 * noise(3))[..., None]
    albedo = np.where(mortar[..., None], grout, base) * (0.6 + 0.4 * ao)[..., None]
    albedo = np.clip(albedo, 0, 1)

    # Roughness: honed stone, polished smooth where walked on, the grout
    # matte, the pits rough.
    worn = np.clip((blur(noise(90, 2), 4) - 0.3) * 1.5, 0, 1)
    rough = 0.6 + 0.08 * noise(10, 2) - 0.3 * worn
    rough = np.where(mortar, 0.92, np.where(pits < 0, 0.85, rough))
    rough = np.clip(rough, 0.05, 1)

    # Height scaled to 0..1 over its own range.
    h01 = (height - height.min()) / (height.max() - height.min())

    def srgb(linear: np.ndarray) -> np.ndarray:
        return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - 0.055)

    Image.fromarray((srgb(albedo) * 255 + 0.5).astype(np.uint8), "RGB").save(OUT / "albedo.png")
    Image.fromarray((rough * 255 + 0.5).astype(np.uint8), "L").save(OUT / "roughness.png")
    Image.fromarray(((normal * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8), "RGB").save(OUT / "normal.png")
    Image.fromarray((h01 * 65535 + 0.5).astype(np.uint16)).save(OUT / "height.png")
    Image.fromarray((ao * 255 + 0.5).astype(np.uint8), "L").save(OUT / "ao.png")
    print(f"wrote {OUT}: height range {height.min() * 1000:.1f} to {height.max() * 1000:.1f} mm")


if __name__ == "__main__":
    main()
