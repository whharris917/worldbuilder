"""Build global texture maps of the Moon, Earth and Mars for the one-bulb
study's ball, from public-domain NASA and USGS data.

Every source is a simple cylindrical (equirectangular) map: longitude
across, latitude down, as Godot's sphere mesh lays out its texture
coordinates (u once round from the left edge, v from the north pole),
so a map wraps the ball without fitting.

Sources (downloaded once into a cache folder outside the repo):
  Moon   colour  NASA SVS CGI Moon Kit, LRO LROC WAC mosaic, 4096 x 2048
         height  NASA SVS CGI Moon Kit, LOLA elevation, 16 px/deg, half-metres
  Earth  colour  NASA Blue Marble Next Generation, July 2004, no relief shading
         height  NASA Visible Earth GEBCO 08 land elevation, 8-bit, sea = 0
  Mars   colour  USGS Viking Orbiter global colour mosaic, 925 m/px
         height  NASA PDS MGS MOLA MEGDR, 4 px/deg, metres

Written to game/textures/planet_<name>/:
  albedo.jpg     colour, 4096 x 2048
  normal.png     tangent space, OpenGL convention (green toward north),
                 2048 x 1024, slopes taken on the planet's own sphere
                 and multiplied by RELIEF
  roughness.png  Earth only: oceans glossy, land rough

Run: .venv\\Scripts\\python.exe tools\\build_planets.py [cache folder]
"""
from __future__ import annotations

import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

Image.MAX_IMAGE_PIXELS = None
OUT = Path(__file__).resolve().parent.parent / "game" / "textures"
CACHE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".cache" / "worldbuilder_planets"
COLOUR_SIZE = (4096, 2048)
NORMAL_SIZE = (2048, 1024)

SOURCES = {
    "moon_color_4k.tif": "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_4k.tif",
    "moon_ldem_16_uint.tif": "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/ldem_16_uint.tif",
    "earth_bmng_july.jpg": "https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/july/world.200407.3x5400x2700.jpg",
    "earth_gebco_elev.png": "https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73934/gebco_08_rev_elev_21600x10800.png",
    "mars_viking_925m.tif": "https://planetarymaps.usgs.gov/mosaic/Mars_Viking_ClrMosaic_global_925m.tif",
    "mars_mola_4ppd.img": "https://pds-geosciences.wustl.edu/mgs/mgs-m-mola-5-megdr-l3-v1/mgsl_300x/meg004/megt90n000cb.img",
}

# Mean radius, metres; and how much the relief is exaggerated. At these
# map sizes one pixel spans 5 to 20 km, over which real slopes are
# gentle; the Moon's craters read at their true steepness doubled, the
# Earth's mountains and Mars's volcanoes need more.
PLANETS = {
    "moon": {"radius": 1_737_400.0, "relief": 2.0},
    "earth": {"radius": 6_371_000.0, "relief": 12.0},
    "mars": {"radius": 3_389_500.0, "relief": 6.0},
}


def fetch(name: str) -> Path:
    path = CACHE / name
    if not path.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        print("downloading", name)
        request = urllib.request.Request(SOURCES[name], headers={"User-Agent": "curl/8.4.0"})
        with urllib.request.urlopen(request, timeout=3600) as response:
            path.write_bytes(response.read())
    return path


def resize(a: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize(size, Image.BILINEAR))


def normal_map(height_m: np.ndarray, radius: float, relief: float) -> np.ndarray:
    """Tangent-space normals from a height map on a sphere. East is
    +u (right), north is up the image; an east step is shorter toward
    the poles by cos(latitude)."""
    h, w = height_m.shape
    lat = (0.5 - (np.arange(h) + 0.5) / h) * np.pi
    d_lon = 2 * np.pi / w
    d_lat = np.pi / h
    east = (np.roll(height_m, -1, 1) - np.roll(height_m, 1, 1)) / (2 * radius * d_lon * np.maximum(np.cos(lat), 0.05)[:, None])
    padded = np.pad(height_m, ((1, 1), (0, 0)), mode="edge")
    north = (padded[:-2] - padded[2:]) / (2 * radius * d_lat)
    n = np.stack([-east * relief, -north * relief, np.ones_like(height_m)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    slope = np.hypot(east, north) * relief
    print(f"  slope after relief: median {np.median(slope):.3f}, 99th percentile {np.percentile(slope, 99):.3f}")
    return ((n * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)


def save(name: str, colour: Image.Image, height_m: np.ndarray, roughness: np.ndarray | None = None) -> None:
    out = OUT / f"planet_{name}"
    out.mkdir(parents=True, exist_ok=True)
    colour.convert("RGB").resize(COLOUR_SIZE, Image.LANCZOS).save(out / "albedo.jpg", quality=92)
    p = PLANETS[name]
    small = resize(height_m, NORMAL_SIZE)
    Image.fromarray(normal_map(small, p["radius"], p["relief"]), "RGB").save(out / "normal.png")
    if roughness is not None:
        Image.fromarray((resize(roughness, NORMAL_SIZE) * 255 + 0.5).clip(0, 255).astype(np.uint8), "L").save(out / "roughness.png")
    print("wrote", out)


def moon() -> None:
    print("moon")
    colour = Image.open(fetch("moon_color_4k.tif"))
    height = np.asarray(Image.open(fetch("moon_ldem_16_uint.tif")), dtype=np.float64) * 0.5
    save("moon", colour, height)


def earth() -> None:
    print("earth")
    colour = Image.open(fetch("earth_bmng_july.jpg"))
    elev = Image.open(fetch("earth_gebco_elev.png"))
    elev = np.asarray(elev.reduce(4), dtype=np.float64)        # 5400 x 2700
    land = elev > 0
    # The 8-bit scale puts the highest land near 250: about 35 m a step.
    height = elev * (8848.0 / 250.0)
    # Water: a sheen where the sun glints; land: matte.
    rough = np.where(land, 0.85, 0.22)
    rough = ndimage.gaussian_filter(rough, 1.0)
    save("earth", colour, height, rough)


def mars() -> None:
    print("mars")
    colour = Image.open(fetch("mars_viking_925m.tif"))
    colour.draft("RGB", (COLOUR_SIZE[0] * 2, COLOUR_SIZE[1] * 2))
    raw = np.fromfile(fetch("mars_mola_4ppd.img"), dtype=">i2").reshape(720, 1440).astype(np.float64)
    # MOLA runs 0 to 360 east from the left edge; the Viking mosaic, as
    # the others, -180 to 180. Half a turn lines them up.
    height = np.roll(raw, 720, axis=1)
    save("mars", colour, height)


if __name__ == "__main__":
    for build in (moon, earth, mars):
        build()
