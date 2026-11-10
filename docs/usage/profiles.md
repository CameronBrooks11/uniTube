# Profiles

A profile is the tube's cross-section: a **wall between two boundaries**. The
inner boundary, the bore, is a first-class part of it.

```scad
ut_round(od = 12, wall = 2)                 // a round tube
ut_round(od = 16, wall = 2, split = [-30, 30])   // a C-section
ut_rod(d = 10)                              // solid, no bore
ut_profile(outer, inner)                    // any hollow section
```

## Round tubes

```scad
ut_round(od = undef, id = undef, wall = undef, n = undef, a0 = 0, split = undef)
```

Give **exactly two** of `od`, `id` and `wall`; the third is derived. One or
three is an error. `(id, wall)` is often the natural pair: the bore is the
functional dimension and the wall is a multiple of extrusion width.

The outline is a polygon. Its point count follows `$fa`/`$fs` at the place
`ut_round` is called, or set it with `n`. `a0` rotates the first point.

A wall below 1.2 mm (about three perimeters on a 0.4 mm nozzle) is legal and
warns when the run is checked: such a tube renders perfectly and can print as a
hole.

`id = 0` is an error. For a solid section use `ut_rod(d)`.

## Split tubes

`split = [a, b]` removes the angular range from `a` to `b` degrees, leaving a
C-section. The angles are in the profile's own frame, whose +X axis is the
station's roll reference. So `split = [-30, 30]` puts a 60° gap centred on the
frame normal, and the frame policy decides where that points:
[`frames.md`](frames.md).

A split section has an inner surface but no enclosed bore. It can be swept with
`ut_tube`, and it cannot be a run in a network.

## Any other hollow section

```scad
ut_profile(outer, inner = undef, meta = [])
```

`outer` and `inner` are lists of 2D points. Rectangular duct, D-sections and
keyed bores all work, under three rules that `ut_profile` asserts:

- **Both loops are counter-clockwise** (`PROF-1`). The inner loop too.
- **Both loops have the same number of points, and `outer[i]` and `inner[i]`
  sit at the same angle from the centre** (`PROF-2`). Equal count is not
  enough. Sample both loops by angle, not by distance along the outline.
- **The inner loop lies inside the outer loop at every angle** (`PROF-1`).

The codes are the ones the assert messages carry. `PROF-3` is the thin-wall
warning above.

A square bore in a round tube, sampled by angle:

```scad
function square_by_angle(h, n) = [for (k = [0 : n - 1])
    let(t = 360 * k / n, c = cos(t), s = sin(t)) h / max(abs(c), abs(s)) * [c, s]];

N = ut_fragments(7, 360);
prof = ut_profile(ut_ring(7, N), square_by_angle(4, N), [["od", 14]]);
```

`meta` is a list of `[key, value]` pairs. `ut_round` fills in `od`, `id` and
`wall`. For your own sections, the tight-bend warning uses `od` when it is set
and twice the reach otherwise; the thin-wall warning needs `wall`.

The angle rule exists because each end of a tube is capped by a strip between
corresponding points, not by a general polygon triangulation. See ADR 0006.

## Shell, bore and solid

One profile yields three regions, and the network assembler depends on being
able to ask for each:

```scad
ut_solid_rgn(p)   // [outer, inner]   the finished wall
ut_shell_rgn(p)   // [outer]          the outside, filled
ut_bore_rgn(p)    // [inner]          the bore, as a solid
```

`ut_tube(path, prof, part = "shell")` or `part = "bore"` sweeps one of them
alone. The bore uses the same path and the same frames as the wall, so a
network can union every shell and then cut every bore
([`networks.md`](networks.md)).

## Reading a profile

| | |
|---|---|
| `ut_prof_outer(p)`, `ut_prof_inner(p)` | the two loops |
| `ut_prof_od(p)`, `ut_prof_id(p)`, `ut_prof_wall(p)` | declared dimensions, `undef` if not in `meta` |
| `ut_prof_hollow(p)` | has an inner loop |
| `ut_prof_open(p)` | is a split section |
| `ut_prof_reach(p)` | farthest outer point from the centreline |
| `ut_bore_inradius(p)` | largest circle that fits inside the bore polygon |

A polygon's inscribed circle is smaller than the circle its points lie on, by
`cos(180/n)`. Use `ut_bore_inradius` for anything that must fit inside the
bore, and `ut_prof_reach` for anything that must clear the outside.

## Limits

- **One bore.** Multi-lumen sections are not supported ([#22]).
- **One profile per run, constant along its length.** Tapers and reducers are
  not supported ([#20]). Both mechanisms tried in design review did harm:
  scale baked into the station frame emitted a port at 0.6×, and a scalar
  multiplier on the region thinned a 1.6 mm wall to 0.96 mm. When variation
  arrives it will be separate `od(u)` and `wall(u)` functions of arclength.
- **`ut_rod` outlines must be star-shaped about their centroid**, which any
  convex shape is. Its end caps are a fan from the centre.

The reasoning behind the two-loop representation of a split section is in
ADR 0007.

[#20]: https://github.com/CameronBrooks11/uniTube/issues/20
[#22]: https://github.com/CameronBrooks11/uniTube/issues/22
