# Utilities — API

Source: `src/ut_core.scad`, `src/ut_math.scad`, `src/ut_view.scad`.

## Constants

OpenSCAD's `use` does not export variables, so every constant is a function.

| | value |
|---|---|
| `ut_eps()` | `1e-9`, the tolerance for "zero" |
| `ut_min_wall()` | `1.2`, the wall in mm below which `CHECK-3` and `NET-4` warn |
| `ut_up()` | `[0, 0, 1]` |
| `ut_back()` | `[0, 1, 0]` |

## Options and assertions

| | |
|---|---|
| `ut_opt(opts, key, dflt = undef)` | The value of the first `[key, value]` pair in `opts` with that key, else `dflt`. |
| `ut_req(cond, msg)` | Asserts `cond` with `msg` and returns `true`, so it can prefix an expression. |

## Vectors and angles

All angles are in degrees.

| | returns |
|---|---|
| `ut_unit(v)` | `v` normalised |
| `ut_turn(a, b)` | the angle between two 3D vectors, by `atan2`, never `acos` |
| `ut_rotv(v, ang, k)` | `v` rotated by `ang` about the unit axis `k` |
| `ut_ortho(t, n)` | `n` made orthogonal to `t` and normalised |
| `ut_ref_fallback(t, ref = undef)` | `ref` (default up) projected orthogonal to `t`; falls back to back, then +X, when `t` is parallel to it |

## Circles, polygons and meshes

| | returns |
|---|---|
| `ut_fragments(r, ang = 360)` | the number of facets OpenSCAD's `$fn`/`$fa`/`$fs` rule gives a radius `r` over `ang` degrees; at least 2 |
| `ut_ring(r, n, a0 = 0)` | `n` points on a circle of radius `r`, counter-clockwise from angle `a0` |
| `ut_inradius(loop)` | the radius of the largest origin-centred circle inside a 2D loop, measured to its edges |
| `ut_sphere_inradius(r)` | the distance from the centre to the nearest face of the `sphere(r)` OpenSCAD emits at the current resolution: `r*cos(180/n)^2`, exact for 8 or more facets and low below that |
| `ut_area2d(poly)` | signed area; positive for counter-clockwise |
| `ut_volume(pts, faces)` | the volume of a closed mesh, by the divergence theorem |

A polygon's inscribed circle is smaller than the circle its vertices lie on by
`cos(180/n)`, and a faceted sphere loses that factor twice. Use `ut_inradius`
and `ut_sphere_inradius` for anything that must fit inside.

## Viewing

| | |
|---|---|
| `ut_cutaway(normal = [0,1,0], at = 0, on = true, size = 1000)` | Module. Removes the part of its children on the `normal` side of the plane at distance `at` along `normal`. `on = false` passes the children through. `size` is the edge of the cutting cube. |

It forces a CSG difference, so do not leave it on around geometry you export.
