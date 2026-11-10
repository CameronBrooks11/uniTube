# Frames and roll

A cross-section has to be oriented at every point along the path. The direction
its local +X axis points is the **roll**. On a plain round tube roll is
invisible. It matters as soon as anything is not rotationally symmetric: a split
conduit's gap, a square bore, a keyway, or the clocking of whatever gets bolted
to a port.

Roll is decided in exactly one function, `ut_stations(path, opts)`. Frontends do
not set it and the mesh backend does not guess it. You choose a policy.

## Choosing a policy

| option | behaviour |
|---|---|
| `frame = "transport"` *(default)* | rotation-minimizing: the section does not spiral relative to the tube |
| `frame = "fixed"`, `normal = [0,0,1]` | the reference is projected orthogonal to the tangent at every station, so the section's +X points in one world direction along the whole run |
| `frame = <list>` | one normal per station, supplied by you |
| `twist = <deg>` | extra roll, distributed by arclength on top of any of the above |

Every frontend takes `frame`, `normal` and `twist` as arguments:

```scad
path = ut_polyline(pts, r = 18, frame = "fixed", normal = [0, 0, 1]);
```

They can also be given, or overridden, where the path is swept. Options given
here win over the ones stored in the path:

```scad
ut_tube(path, prof, opts = [["frame", "fixed"], ["normal", [0, 0, 1]]]);
ut_run("a", path, prof, opts = [["twist", 90]]);
```

> **Known issue ([#35]).** An unrecognised `frame` string, or a misspelled option
> key, is not refused: the run is swept with the transport frame and no warning.
> Check the spelling.

## Transport

The frame is carried along the path without adding twist:

- **Lines** leave the normal unchanged.
- **Arcs** rotate the normal about the arc's own axis by the arc's own sweep
  angle. This is closed form and exact.
- **Sampled segments** use a discrete rotation-minimizing step between
  consecutive samples.

On a **planar** bend the normal is parallel to the bend axis, and a rotation
leaves a vector parallel to its axis unchanged. So a planar bend produces
exactly zero twist; `tests/t_path.scad` asserts it to 1e-12.

The starting normal is `normal` (default `[0,0,1]`) projected orthogonal to the
first tangent. When the run starts parallel to it, the seed falls back to
`[0,1,0]`, then to `[1,0,0]`.

## Fixed

Use `frame = "fixed"` when the requirement is relative to the world rather than
to the tube. The usual case is a lengthwise-split conduit that must print as an
open channel: the gap has to face up along the whole run, and transport only
promises that it does not spiral relative to the tube.

```scad
ut_tube(path, ut_round(od = 16, wall = 2, split = [-30, 30]),
        opts = [["frame", "fixed"], ["normal", [0, 0, 1]]]);
```

**The run must never point along `normal`.** A vertical pipe has no
upward-facing side, so the ask is undefined there. `ut_stations()` asserts when
any station's tangent comes within 0.5° of the normal, naming the station. The
projection itself is smooth right up to that point (measured to 1e-13 at 1°
from the axis), so there is no gradual loss of accuracy to allow for.

## A normal per station

`frame` may be a list with one normal per station. Each is projected orthogonal
to its station's tangent, and a normal within 0.5° of the tangent is refused.

The station count depends on `$fa`/`$fs`, so read it rather than assuming it:

```scad
n = len(ut_stations(path));
ut_tube(path, prof, opts = [["frame", [for (i = [0 : n - 1]) [0, 0, 1]]]]);
```

> **Known issue ([#35]).** A list longer than the station count is accepted and
> the extra entries are ignored.

## Twist

`twist` adds a roll that grows linearly with arclength, from 0 at the start to
the full value at the end. It is applied after the policy above.

> **Known issue ([#33]).** A straight leg has only two stations, so the twist
> across it is a single strip between two rotated rings and the tube necks in
> the middle. A 60 mm straight with `twist = 90` keeps 64.9% of its volume.
> Until this is fixed, twist is only sound across bends and sampled paths.

## Closed paths

On a closed path (`ut_spine(segs, closed = true)`) the frame is transported all
the way round and compared with where it started. The mismatch, the loop's
holonomy, is distributed by arclength so the section meets itself. Measured on a
four-arc torus: residual 0°.

The option `["symmetry", k]` tells the compiler the section looks the same every
`360/k` degrees, so only the remainder past the nearest such multiple is
distributed.

> **Known issue ([#34]).** `symmetry` is read from the options only; a profile's
> own symmetry is not passed in. And `twist` on a closed path is not required to
> close: `twist = 45` leaves a 44.25° step at the seam.

## What is asserted

`STATION-6`: between consecutive stations, the roll may not turn more than 45°
further than the tangent does. Transport measures 0 by construction and a fixed
frame measures 1e-13, while a flipped frame measures 84° to 174°, so the
threshold sits in an empty gap. The check runs before `twist` is applied, so
asking for a large twist does not trip it.

The full list of station invariants is in
[`reference/ir.md`](../reference/ir.md). How the fixed-frame and frame-list
refusals came to exist is in [`developer/history.md`](../developer/history.md) §6.

Every angle in the frame code is computed as `atan2(norm(cross(a,b)), a*b)`,
never `acos`: `acos(1.0000001)` is `nan` on OpenSCAD 2021.01, and near-collinear
waypoints are the most common input there is.

[#33]: https://github.com/CameronBrooks11/uniTube/issues/33
[#34]: https://github.com/CameronBrooks11/uniTube/issues/34
[#35]: https://github.com/CameronBrooks11/uniTube/issues/35
