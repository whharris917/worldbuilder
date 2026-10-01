# veribuilder

Real places built in 3D and walked in first person: historic buildings and towns modelled from their survey drawings and photographs, generated from architectural decisions and validated as sound buildings. Working agreement: `CLAUDE.md`. Method: `docs/real_buildings.md`.

Open `game/project.godot` in Godot 4.7 and press play: the title screen offers the harbour town, the Monroe courthouse and the Mark Twain house. WASD and the mouse to move, E to use, O for options (time of day, weather, music, graphics), F7 to cycle graphics presets, F5/F9 to save and load where you stand.

```powershell
# generate a building from its data, validate it, write its .bld if clean
.venv\Scripts\python.exe tools\building\build.py twain

# the generator and validator tests
.venv\Scripts\python.exe -m pytest tests -q
```
