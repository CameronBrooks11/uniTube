# The path IR

Two levels, one compiler function between them, and a hard rule about who may
look at which. See ADR 0002 for why, and `src/ut_path.scad` for the code.

## Level 1 — `utPath`, the spine

An ordered chain of exact curve segments describing ONE strand of centreline.
Sparse (a five-bend run is eleven segments regardless of `$fn`), exact (arc
length, tangents and bend radii are closed-form), and carrying **no roll and no
resolution**.

```scad
path = ["utpath", segs, closed, opts]

seg  = ["L", p0, p1]                  // straight
     | ["A", c, u, v, r, ang]         // circular arc
     | ["P", pts, tans]               // sampled chain, one unit tangent per point
```

Arcs are parameterised exactly as STEP/IGES `axis2_placement_3d`:

```
point(x)   = c + r*(cos(ang*x)*u + sin(ang*x)*v)
tangent(x) = -sin(ang*x)*u + cos(ang*x)*v          (already unit)
axis       = cross(u, v)                           (the transport axis)
arclen     = ang/360 * 2*PI*r
```

Sweep direction lives in the `(u, v)` basis, never in the sign of `ang`, so `ang`
is always positive. That removes an entire class of tangent-sign bug.

`P` carries per-sample tangents deliberately: a bare point list reintroduces the
chord-tangent error this IR exists to avoid. Frontends with an analytic
derivative must supply it.

## Level 2 — `utStations`

```scad
st = [p, t, n, s]     // position, unit tangent, unit roll normal (n·t = 0), arclength
```

Produced by exactly one function, `ut_stations(path, opts)`. Roll is decided,
resolution is decided, duplicates are gone, closed-loop holonomy is absorbed.

`ut_st_mat(st)` converts a station to a 4×4 frame — columns `(n, cross(t,n), t)`
plus the position. **No scale, no shear, ever.** A tapered run that baked scale
into its frames would hand every attached termination a silently shrunken port.

## The rule

Frontends produce a spine and never touch frames. Exactly one function lowers
spine → stations. The backend consumes stations and never infers, guesses,
corrects or re-derives orientation.

Every historical geometry bug in this repository, and both of the bugs found in
`reference/gringer/path_extrude.scad`, is a violation of that rule.

## Invariants

| | |
|---|---|
| `SPINE-1` | every segment is exactly `L`, `A` or `P`; arc bases are orthonormal |
| `SPINE-2` | contiguity — each segment ends where the next begins, to 1e-6 |
| `SPINE-3` | tangent continuity everywhere. There is no G0 / mitre case (ADR 0004) |
| `SPINE-4` | non-degenerate: lines have length, arcs have `0 < ang ≤ 180` |
| `SPINE-5` | no roll. **No resolution for `L` and `A`** — see the caveat below |
| `SPINE-6` | a spine is a STRAND, not a graph. Branching lives in the network (Phase 3) |
| `STATION-1` | no two consecutive positions coincide — the unconditional dedupe |
| `STATION-2` | orthonormal frames, right-handed, det +1, no scale or shear |
| `STATION-3` | terminal and arc-tangency tangents are EXACT, never smoothed |
| `STATION-4` | `s[0] = 0`, strictly increasing, `s[last] = ut_length(path)` |
| `STATION-5` | bounded turn between consecutive tangents |
| `STATION-6` | continuous roll — the frame never flips |

### `SPINE-5` and sampled segments — a stated limit

`SPINE-5` holds fully for `L` and `A` segments: they are exact, and `$fa`/`$fs`
decide the station count at compile time.

**It does not hold for `P`.** `ut_curve` bakes its `n` into the spine, and the
resolution knobs are inert on the result:

| path | `$fa=24, $fs=4` | `$fa=0.5, $fs=0.1` |
|---|---|---|
| arc-based (`ut_polyline`, `ut_turtle`) | 7 stations | 183 stations |
| sampled (`ut_curve`) | **161** | **161** |

This is recorded rather than fixed. Closing it means fitting arcs to the samples
— see `spikes/biarc_fitter.scad`, which exists and works — and that is deferred
(`BACKLOG.md` §3). Resolution independence is the one argument that genuinely
justifies building it; the arclength and transport arguments do not survive
measurement.

## Frame policy

| policy | behaviour |
|---|---|
| `frame="transport"` *(default)* | rotation-minimizing; no spiral |
| `frame="fixed"`, `normal=UP` | seam pinned to a world direction along the whole run |
| `frame=<list>` | one normal per station, projected and asserted |
| `twist=<deg>` | distributed by arclength on top of any of the above |
| `closed=true` | holonomy measured, `symmetry` absorbed, remainder distributed |

Transport across an arc is **closed form** — rotate the roll reference about the
arc's own axis by the arc's own sweep angle. Exact, one line, no accumulated
error. This is the single strongest argument for an arc-native IR, and it is
`reference/axford/half_curvedPipe.scad:19` generalised (docs/salvage.md §2).

A consequence worth knowing: on a **planar** bend the roll reference is parallel
to the bend axis, and Rodrigues leaves a vector parallel to its axis invariant.
So a planar bend produces **exactly zero twist**, asserted in `tests/t_path.scad`.

Seeding falls back from `UP` to `BACK` when the run starts parallel to the
reference. Without that, a vertical run yields `[nan,nan,nan]` for every station.

## Worked example

`ut_polyline([[0,0,0],[50,0,0],[50,50,0]], r=15)` lowers to:

```scad
["utpath",
 [ ["L", [0,0,0],   [35,0,0] ],                 // trimmed by inset = r*tan(ang/2) = 15
   ["A", [35,15,0], [0,-1,0], [1,0,0], 15, 90],
   ["L", [50,15,0], [50,50,0] ] ],
 false, [["frame","transport"], ["twist",0]]]
```

Verifiable by hand, no rendering:

```
c + r*u                   = [35,15,0] + 15*[0,-1,0] = [35,0,0]   arc start == leg 1 end
c + r*(cos90*u+sin90*v)   = [35,15,0] + 15*[1,0,0]  = [50,15,0]  arc end   == leg 2 start
tangent(0) = v            = [1,0,0]    == leg 1 direction
tangent(1) = -u           = [0,1,0]    == leg 2 direction
ut_length(path)           = 35 + (90/360)*2*PI*15 + 35 = 93.5619449019   exact
```
