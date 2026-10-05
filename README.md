# worldbuilder

Real places built in 3D and walked in first person: historic buildings and towns modelled from their survey drawings and photographs, generated from architectural decisions and validated as sound buildings. Working agreement: `CLAUDE.md`. Method: `docs/real_buildings.md`.

Open `game/project.godot` in Godot 4.7 and press play. The title screen offers:

- **Real places:** a 1940s Maine harbour town, the Monroe courthouse (1886), the Mark Twain house (1874), the same house built from its data, and the Middaugh house (1888), the last two generated from their survey drawings.
- **Studies:** a forest meadow in four looks (atmosphere), open hills of long grass (wind and scale), and two labs for learning how a scene is lit and drawn, each with panels of controls: ONE BULB (a floor under a single bulb) and LIGHT POOL (a room lit from below through a glass floor, with rippling water and drips).

WASD and the mouse to move, E to use, O for options (time of day, weather, music, graphics), F7 to cycle graphics presets, F5/F9 to save and load where you stand. In the two labs, Esc frees the mouse for their panels.

```powershell
# generate a building from its data, validate it, write its .bld if clean
.venv\Scripts\python.exe tools\building\build.py twain

# the generator and validator tests
.venv\Scripts\python.exe -m pytest tests -q
```

## Credits

Textures, sounds, planet and star data, and survey drawings come from others; most are public domain. One sound, "water drop tap 4" by alexzavesa (Freesound, CC BY 4.0), requires credit, and the Godot Engine's MIT licence notice must accompany any exported build. All are listed, with sources and licences, in [`CREDITS.md`](CREDITS.md).

