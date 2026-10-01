"""The building generator and its validator (tools/building/): the test
house is clean, bad parameters are refused, and each kind of fault a
building can have is found."""
import copy
import json
import os
import sys

import pytest

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "tools", "building"))

import arch  # noqa: E402
from validate import Validator  # noqa: E402

with open(os.path.join(HERE, "..", "tools", "building", "examples", "cottage.json"), encoding="utf-8") as f:
    COTTAGE = json.load(f)


def checks(data: dict) -> set:
    m = arch.Model(data).generate()
    v = Validator(m)
    v.run()
    return {f.check for f in v.findings}


def mutate(fn) -> dict:
    d = copy.deepcopy(COTTAGE)
    fn(d)
    return d


def test_the_test_house_is_a_building():
    assert checks(COTTAGE) == set()


def test_a_window_into_the_roof_is_refused():
    def f(d):
        d["openings"].append({"at": [20, 0], "w": 3.0, "sill": 12.5, "head": 19.5})
    with pytest.raises(arch.GenError):
        arch.Model(mutate(f)).generate()


def test_walls_with_no_roof_over_them_are_found():
    def f(d):
        d["roofs"] = [r for r in d["roofs"] if r["id"] != "wing"]
        d["openings"] = [o for o in d["openings"] if o["at"][0] != 60]
    found = checks(mutate(f))
    assert "generation" in found and "sealed" in found


def test_a_short_chimney_is_found():
    def f(d):
        d["chimneys"][0]["top"] = 31.0
    assert "chimneys" in checks(mutate(f))


def test_a_porch_over_a_room_is_found():
    def f(d):
        d["spaces"][-1]["poly"] = {"rect": [10, 26, 30, 38]}
    assert "overlap" in checks(mutate(f))


@pytest.mark.parametrize("change", [
    lambda d: d["roofs"][0].update(footprint=[[0, 0], [40, 0], [40, 30], [20, 15], [0, 30]]),
    lambda d: d["roofs"][0].update(pitch=45.0),
    lambda d: d["roofs"][2].update(plate=40.0),
    lambda d: d["openings"].append({"at": [15, 15], "w": 3.0, "sill": 3.0, "head": 8.0}),
    lambda d: d["roofs"][1].update(sides={"x1": {"kind": "gable", "rake": 12.0}}),
])
def test_bad_parameters_are_refused(change):
    with pytest.raises(arch.GenError):
        arch.Model(mutate(change)).generate()


def test_a_room_with_a_bay_on_a_straight_wall_is_split():
    import plan
    room = [(0, 0), (40, 0), (40, 30), (28, 30), (28, 35), (12, 35), (12, 30), (0, 30)]
    parts = plan.convex_parts(room)
    assert abs(sum(plan.area(p) for p in parts) - (40 * 30 + 16 * 5)) < 1e-6


def test_an_eave_stops_at_a_tower_on_its_corner():
    # a tower set diagonally over the main roof's corner: the main roof's
    # overhang must not run on past the tower's far faces
    d = mutate(lambda d: d["roofs"].append(
        {"id": "tower", "footprint": [[38, 22], [44, 28], [38, 34], [32, 28]], "apex": [38, 28], "peak": 34.0,
         "eave": 26.0, "overhang": 1.0}))
    m = arch.Model(d).generate()
    from arch import contains
    for c in m.roofs["main"].eave:
        for y in (17.4, 17.8, 18.2, 18.6, 19.0):
            assert not contains(c, (41.2, y, 31.2), 1e-6), "the main eave sticks out past the tower"


def test_a_face_less_one_sharing_its_edge_stays_within_it():
    # a wall's slanted top less the one under the next storey's wall, the
    # two edges along one line to rounding: no point thrown past the face
    import solid
    p = [(23.700000000001037, -62.96785886466206), (47.373749999998836, -31.678383797157334),
         (46.77374999999999, -31.678383797157334), (23.099999999999078, -62.96785886466206)]
    q = [(23.69999999999934, -62.96785886466206), (40.44549999999898, -40.83541661352312),
         (39.845500000000214, -40.83541661352312), (23.10000000000004, -62.96785886466206)]
    xs, zs = [v[0] for v in p], [v[1] for v in p]
    for piece in solid.poly_less(p, q):
        for x, z in piece:
            assert min(xs) - 1e-6 <= x <= max(xs) + 1e-6 and min(zs) - 1e-6 <= z <= max(zs) + 1e-6
