# worldbuilder

Real places built in 3D and walked in first person: historic buildings and towns modelled from their survey drawings and photographs, generated from architectural decisions and validated as sound buildings. Godot 4 for the worlds; Python for the building generator, its validator and the fitting tools.

- `docs/real_buildings.md` is the method for a real building. Read it before building work.
- `docs/history.md` is the session-by-session record: why each rule exists, measurements, findings. New history goes there, not here. This work began inside flowstate (the factory game, `C:\Users\wilha\projects\flowstate`) and moved here on 2026-10-01.
- This file holds rules and current state only. Keep it under 5,000 words, in the plain register below.

## Communicating with the director

The director is the creative director: does not code, reviews builds by walking them.

- Every message is an executive summary: a few sentences, answer first. What changed, whether it works, what to look at, what needs their call.
- Report what they can do and see in the game. Leave out test counts, timings, iteration counts, file lists and how a bug was found. Give a number only when it changes a decision.
- State each fact once, in plain words. Describe behaviour rather than using a term of art; in-game text too.
- Avoid: dramatic framing; contrast for effect ("not X, just Y"); giving objects agency ("load-bearing"); verdicts; asides about yourself; openers ("Certainly", "You're right"); hedges ("It's worth noting"); narrating an action before taking it; softening adverbs (simply, just, actually, genuinely, quietly); recaps of work they watched; closing summaries; habitual next-step menus.
- A building that fails its checks, or a world that shows something other than what the data says, leads the message and is fixed or escalated with a recommendation. Never mention one in passing or offer it as an option.
- During a walkdown, acknowledge each observation in a line and wait. Fixes start when they say so.
- Player-facing prose (menu notes, signs, inscriptions, films' words) is drafted by hand for their review, never generated from code.
- Commit messages use the same register. A delivery ends with: what changed, how to see it in Godot, what to look for.

## Roles

- Director: sets vision, reviews builds, reports what they saw. Never asked to write code.
- Claude: the whole development team. Decide technical questions and explain briefly; ask only when a choice is creative.
- Claude can see rendered output: each world's windowed probe saves screenshots to `user://*.png` (`%APPDATA%\Godot\app_userdata\worldbuilder\`) and Claude reads them. Use this for visual work instead of guessing.

## Environment (Windows)

- Python: `.venv\Scripts\python.exe` only (3.11; numpy, scipy, Pillow, imageio_ffmpeg, pytest). There is no bare `python` or `py`.
- Shell: PowerShell 5.1. Commit messages go in single-quoted here-strings with no embedded double quotes. Never edit text with `Get-Content | Set-Content` or `-replace` (they corrupt UTF-8 and add BOMs); use Edit or a scratch Python script. In the Bash tool a quoted heredoc breaks on any apostrophe in its body; use Write or a scratch `.py` in the scratchpad.
- `open(path, "w")` empties the file before it checks its other arguments. Commit work in progress before any bulk edit, and keep patch scripts until their work is committed.
- Before writing a new script, grep for its `class_name` and filename: Write overwrites silently.
- Godot 4.7.2: `C:\Users\wilha\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe` (`godot` on PATH in fresh PowerShell shells, not in Bash). Claude writes `.gd`, `.tscn`, `.tres` and `.gdshader` as text; the director opens `game/project.godot`.
- Survey sources live outside the repo: the Twain house's HABS sheets and photographs in `C:\Users\wilha\projects\habs\twain\`, the Middaugh house's in `C:\Users\wilha\projects\habs\middaugh\` (named in each building's json).
- Reference scenes for "realistic" (outside the repo): `godot-demos`, `grass-demo`, `jungle-demo` under `C:\Users\wilha\projects`.

### Checks

- **Per change:** `& $exe --headless --path <repo>\game --import`, then one headless smoke, `--quit-after 600` with the world named (the default scene is the title menu, which quits at once headless): `res://world/town.tscn`, `courthouse.tscn`, `twain.tscn`, `twain_data.tscn`. Each prints its build report (and the town its self-check), a startup time and the main loop's cost. Watch the exit output for "resources still in use".
- **Building data or generator:** `.venv\Scripts\python.exe tools\building\build.py <name>` (writes the `.bld` only when clean) and `.venv\Scripts\python.exe -m pytest tests -q`.
- If `--import` reports only `Could not resolve class "X"`, run `--check-only -s res://path/to/changed.gd` on each changed script to find the real error.
- **Windowed probes** take minutes; run them once per batch of related edits and before a delivery that needs a screenshot: `town_probe.tscn` (`WORLDBUILDER_TOWN_SHOTS`), `courthouse_probe.tscn` (`WORLDBUILDER_CH_SHOTS`), `twain_probe.tscn` (`WORLDBUILDER_TW_SHOTS`, `WORLDBUILDER_TW_VIEWS`, `WORLDBUILDER_TW_ORTHO` for the elevations, `WORLDBUILDER_TW_BUILDER=data` for the generated house), `twain_audit.tscn`, `middaugh_probe.tscn` (`WORLDBUILDER_MD_SHOTS`, `WORLDBUILDER_MD_VIEWS`). The director launches the game to check; do not add automated tests beyond what a change needs.
- Every probe sets `MouseMode.probe = true` first in `_ready`. All mouse capture goes through `MouseMode.capture()` (`player/mouse_mode.gd`); never write `Input.MOUSE_MODE_CAPTURED` directly.
- A temporary probe to look at one thing several times is fine; delete it before committing.

### GDScript and shader gotchas

- Untyped for-loop variables break `:=` inference.
- A ternary of two array literals is an untyped Array: declare typed, then assign.
- `var x := <Variant comparison>` cannot infer bool: annotate it.
- A Packed*Array taken out of an Array or Dictionary is a copy; `dict[k].append(x)` changes nothing. Write it back or hold a plain Array.
- `%g` is not a format specifier; use `%f`.
- A colour literal in a shader is linear; a `source_color` uniform is converted. Literals go through `lin()` in `granite.gdshaderinc`.
- Clamp the base of every `pow()` in a shader: a negative base gives NaN, which the glow turns into flickering blobs.
- `SurfaceTool.append_from` of a non-indexed source after an indexed one draws nothing of it.

## Layout

```
worldbuilder/
  CLAUDE.md
  docs/            history.md, real_buildings.md
  tools/
    building/      generator, validator, fitting tools; examples/cottage.json
    film/          takes to film: edit, voices, soundtrack
    twain_*.py     Twain house comparison tools
    generate_audio.py, build_sky.py
  tests/           pytest for tools/building
  game/            Godot 4 project
    project.godot
    world/         worlds, their builders, probes, shaders; building/ draws a .bld
    player/        first-person controller and body
    ui/            HUD, options, graphics presets
    components/    view_util.gd (materials)
    data/          buildings/, stars.bin, actor_handbook.md
    audio/
```

## World rules

- **The world base.** `WorldBase` (`world/world_base.gd`): player, HUD, options (time of day, weather, music, graphics), audio buses, the sun and moon by the clock (`SkyClock`), F5/F9 saving where the player stands. `OutdoorWorld` (`outdoor.gd`) adds the sky, the night sky and woods; `CoastWorld` (`coast_world.gd`) the Maine coast's fog, tide and underwater. A world builds its ground in `_build_ground`, places its actors and spawn point in `_after_build`, and keeps its clock and weather under its own `settings_prefix`.
- **Realism is the art direction.** Choose colours by what a thing is made of; matte for masonry and paint. Keep the screen calm: realism is finish and light, not more objects. Judge in probe screenshots, never by guessing.
- **Sensory layer** (the director's favourite): sound and effects come from real state edges (the bell from the buoy's motion, thunder from a stroke), never a timer. Audio is generated by `tools/generate_audio.py`; regenerate, never hand-edit WAVs, and give each new sound its own RNG so existing files stay identical.
- **Performance target:** each world at 60 fps on Low on the director's laptop (Ryzen 7 5700U, integrated Vega 8, 1600×900). Medium is the default preset. No FSR 2 on an integrated GPU. Measure in a windowed probe, best of two runs.
- Anything placed in a world must sit inside the 3.8 km star dome.
- Floating labels show only on hover; signs and plates are physical and stay.
- An interact body's `view` meta names the node the player acts on.

## Real buildings

A real building is generated from architectural decisions and validated as a solid; nothing in it is placed or sized by hand. Method, generator and fitting tools: `docs/real_buildings.md`.

- **Validity first.** Judge a model as a sound, weathertight, livable building before any comparison with drawings or photographs.
- **Shell before interiors.** Get the exterior right against the elevations before interior detail.
- **Data, not geometry.** `game/data/buildings/<name>.json`: grid lines, levels, spaces, openings (point on a wall, width, sill, head), roofs (footprint; per edge eave, gable or abut, with plate, pitch, overhang; dormers by host, side, centre, width, setback), chimneys, style. A number that is not the obvious reading of a drawing carries a `note` naming its sheet.
- **Derived, never typed.** `tools/building/arch.py` computes walls from the spaces' outlines, roof surfaces from plates and pitches (hips, ridges, valleys as intersections), roof joins, cheeks, openings cut from their walls, porch posts and railings. A kind of fault is fixed in the generator, not in the data.
- **Refused, not drawn.** Parameters that cannot make a building raise `GenError` with the reason.
- **Validated after every change** (`tools/building/validate.py`): closed solids, no overlap, every face fitted, sealed with openings shut, no inside finish in the weather, every roof edge classified (eave, rake, ridge, hip, valley, deck edge, abutment, well, seam, cricket), openings in their walls clear of roof and neighbours, chimneys 2 ft over their roof, headroom, every roof carried. A building that fails is broken, not a draft: `tools/building/build.py <name>` writes the game's `.bld` only when clean.
- **Fitting comes last** and only moves parameters, then validates again.
- `tools/building/examples/cottage.json` with `tests/test_building_generator.py`: the test house stays clean and each kind of fault stays found. A new kind of fault gets a case there.
- **Sources.** Survey drawings come from the Library of Congress (HABS); research the building, then render from the photographs' own cameras (`tools/building/camera.py`) to correct proportions.

## Conventions

- GDScript: static typing, snake_case, one class per file, `class_name` on shared classes.
- Python: 3.11, type hints, pytest.
- Comments describe the code as it is now: what it does and, where not obvious, why, as a present-tense rule. No dates, attributions, prior behaviour or how a bug was found; that goes in the commit message and `docs/history.md`.
- Commit small and often. Never commit `.venv/` or `game/.godot/`. Ask before pushing.

## Where things stand

**Worlds** (title screen `world/menu.tscn`; each saves to its own file):
- **Harbor town** (`town.tscn`, `town_probe.tscn`): a 1940s town on the Maine coast (`harbor_town.gd`, `full_house.gd`, `main_street.gd`, `water_street.gd`, `harbor.gd`, `weather.gd`, `town_coast.gd` on `maine_coast.gd`). Water Street is pinned by the director (`HOUSE_DRAWS`); Main Street after Montpelier; real night sky, stars as points.
- **Monroe courthouse** (`courthouse.tscn`, `courthouse_probe.tscn`): the Union County courthouse (1886), its square and blocks (`union_courthouse.gd`, `courthouse_*.gd`). Its stage (`stage*.gd`, `actor*.gd`) hosts actors driven over `http://127.0.0.1:47886`, documented in `data/actor_handbook.md`. Films are scripted top-down by Claude, no agent actors; pipeline in `tools/film/`, rendered by `take_render.tscn`.
- **Mark Twain house** (`twain.tscn`, `twain_probe.tscn`): the Clemens house, Hartford (1874), from the HABS drawings (CT-359), with its grounds (`twain_*.gd`). The plain entry is hand-built; FROM ITS DATA (`twain_data.tscn`) is generated (see Real buildings). `TwainInterior.snap` places pieces against a wall.
- **Middaugh house** (`middaugh.tscn`, `middaugh_probe.tscn`): the Henry C. Middaugh house, Clarendon Hills, Illinois (1888-1892), generated from `data/buildings/middaugh.json` (HABS IL-1213: three plans, four elevations, a section; no roof plan, no photographs; demolished about 2003). Plans run x south, z west; the world turns it half round so the front faces south. The second building for the method. A building in progress goes into the menu at its first clean build.
- **Forest meadow** (`meadow.tscn`, `meadow_probe.tscn` with `WORLDBUILDER_MEADOW_SHOTS`, `_VIEWS`, `_HIDE`, `_PRESET`): a study in atmosphere, not a real place. A summer meadow in a New England wood with a brook (`meadow.gd`, `meadow_land.gd` on `Landscape`, `grass_field.gd` and `grass.gdshader`, `meadow_ground.gdshader`, `mist.gdshader`, `air.gdshader`, `meadow_sound.gd`). One breeze value drives the grass, the trees and the leaves' sound; mist, birds, crickets and fireflies follow the clock. The wood is drawn with leaves along the meadow's edge and within 60 m of the camera, plain beyond.

**Open for the director:**
1. **Twain house, generated from its data**: clean and fitted to the survey and photographs; awaits the director's look and the judgment calls in `docs/history.md` (2026-09-30). Next: stair, finishes and furniture, then retire the hand-built house.
2. **Monroe courthouse:** the monument's inscriptions (modelled plain).
3. **Harbor town:** the domed hall, the sign names, the town's name, the moon's phase (`SkyClock.MOON_AGE`), the noon sun's height (60°).
4. **Middaugh house**: shell, windows and porches, clean; not yet fitted to the sheets (`overlay.py`); one large room per block and floor; no ornament. The menu note and arrival message are drafts. Next: fit, then the tower's top floor (as its own floor it left a leak; the third-floor tower room rises open to its roof).
5. **The title screen's subtitle** ("real buildings, generated and checked"), a draft.
6. **Forest meadow**: first walkdown. The menu note and arrival message are drafts. Medium runs about 26 to 39 fps on the development machine (Low holds 60).

**Known gaps:**
- The town and the courthouse are hand-built, not generated from data; they predate the method.
- `thunder_near.wav` is generated but nothing plays it.
