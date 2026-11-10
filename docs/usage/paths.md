# Paths

A path is the tube's centreline. There are four ways to describe one, and all of
them produce the same thing: a **spine** of exact lines, arcs and sampled chains
([`reference/ir.md`](../reference/ir.md)). Everything downstream sees only the
spine, so the frontends can be mixed freely in one model.

| frontend | what it is for |
|---|---|
| `ut_polyline(pts, r=)` | waypoints plus fillet radii |
| `ut_turtle([...])` | a bender program: feed, bend, roll |
| `ut_curve(f)` | a parametric centreline: helices, coils, generated routes |
| `ut_spine([...])` | the spine itself, built from segments |

```scad
ut_polyline([[0,0,0], [50,0,0], [50,50,0]], r = 15)

ut_turtle([["feed", 60], ["bend", 90, "r", 24], ["feed", 40],
           ["roll", 90], ["bend", 45, "r", 24], ["feed", 30]])

ut_curve(function(t) [80*cos(360*t), 80*sin(360*t), 60*t], n = 180)

ut_spine([ ut_line([0,0,0], [35,0,0]),
           ut_arc_from(c = [35,15,0], from = [35,0,0], to = [50,15,0], axis = [0,0,1]),
           ut_line([50,15,0], [50,50,0]) ])
```

## Choosing one

- **Known absolute coordinates?** `ut_polyline`.
- **Describing how the tube is bent rather than where it goes?** `ut_turtle`. It
  is how a CNC tube bender is programmed.
- **A formula?** `ut_curve`.
- **Anything else** — a solver's output, surveyed points, another library —
  build a spine directly with `ut_spine`.

Every frontend also takes `frame`, `normal` and `twist`; see
[`frames.md`](frames.md).

## `ut_polyline` — waypoints and radii

```scad
ut_polyline(pts, r = 0, frame = "transport", normal = undef, twist = 0)
```

`pts` is a list of 3D points. Each interior waypoint is rounded by an arc tangent
to both legs. `r` is one of:

- a number, applied to every interior waypoint;
- a list with one entry per waypoint (the two end entries are ignored);
- a list with one entry per interior waypoint.

A collinear waypoint adds no arc. Two bends that are exactly tangent leave no
straight between them, which is fine.

These inputs are errors, each naming the waypoint or leg:

| input | why |
|---|---|
| a turning waypoint with radius 0 | a sharp corner cannot be swept (ADR 0004). `r` defaults to 0, so a path with a corner needs an explicit radius. |
| radii that do not fit on a leg | see below |
| a 180° reversal | a path cannot double back on itself |
| two identical consecutive waypoints | the leg has no direction |
| 2D points | every waypoint must be `[x, y, z]` |
| `closed = true` | closed paths go through `ut_spine` |

**Radii that do not fit are an error, never scaled to fit.** A leg must be at
least as long as the two tangent lengths that trim it, `r * tan(angle/2)` at each
end. Shrinking the radius until it fits looks forgiving and is the opposite: it
hides the problem at exactly the input that most needs a message. On a doubleback
it shrinks the radius to exactly zero, which is a sharp corner and no tube at
all.

## `ut_turtle` — a bender program

```scad
ut_turtle(cmds, start = [0,0,0], dir = [1,0,0], up = [0,0,1],
          frame = "transport", normal = undef, twist = 0)
```

| command | effect |
|---|---|
| `["feed", d]` | straight, `d` mm along the current heading |
| `["bend", ang, "r", r]` or `["bend", ang, r]` | bend by `ang` degrees at radius `r`, toward `up`. A negative angle bends away from `up`. |
| `["roll", ang]` | rotate `up` about the heading |

`up` must be perpendicular to `dir`. A bend over 180° is split into equal arcs
for you. An unknown command is an error.

`roll` emits no geometry. It turns the turtle, which changes the plane of every
later bend and therefore the shape of the path. It does not twist the tube, just
as rotating the workpiece in a bender does not; for twist see
[`frames.md`](frames.md).

## `ut_curve` — a parametric centreline

```scad
ut_curve(f, t = [0, 1], n = 100, dfdt = undef,
         frame = "transport", normal = undef, twist = 0)
```

`f` is a function literal returning `[x, y, z]`. The curve is sampled at `n + 1`
values of `t`, and coincident consecutive samples are dropped.

Tangents come from finite differences, second order in the interior and at both
ends. Supply `dfdt` to make them exact.

> **Foot-gun.** Only the direction of `dfdt` is used, but the relative size of
> its components matters, and OpenSCAD's trig is in degrees:
> `d/dt cos(360*k*t) = -2*PI*k * sin(360*k*t)`. Dropping the `2*PI` leaves a
> helix's tangents about 6° out at every sample while looking plausible. When in
> doubt, omit `dfdt`.

> **Known issue ([#36]).** A `dfdt` that is the zero vector at a sample — an
> eased parametrisation stops at its ends — aborts with a `cross()` NaN warning
> that names `ut_math` rather than your curve.

### What a sampled path costs

`ut_curve` produces one sampled segment, which gives up things arcs provide:

| | arc-based (`ut_polyline`, `ut_turtle`) | sampled (`ut_curve`) |
|---|---|---|
| arclength | exact | chord sum, slightly under |
| frame transport | exact | discrete, second order |
| minimum bend radius check | exact | estimated from three-point curvature |
| resolution | follows `$fa`/`$fs` | fixed by `n` |

Measured on a 2-turn helix at n=160: the length is 0.025% under the analytic
value, and interior tangents agree with the analytic tangent to 0.006°. The end
tangents, which are where port frames come from, without `dfdt`:

| n | end-tangent error |
|---|---|
| 40 | 0.460° |
| 160 | 0.0141° |
| 320 | 0.0032° |

Two of these deserve attention:

- **The bend-radius check fails open.** The estimate is accurate (11.014 against
  an analytic 11.013 on a helix) but over-reads on fast-varying curves, so a
  marginal self-intersection can slip through. Leave margin.
- **`$fa` and `$fs` do nothing.** An n=160 curve has 161 stations at any
  setting, where an arc path measured 7 at `$fa=24` and 183 at `$fa=0.5`. Choose
  `n` for the finest resolution you need.

Fitting arcs to the samples would restore all four. It is prototyped in
`spikes/biarc_fitter.scad` and deferred ([#17]).

## `ut_spine` — segments directly

```scad
ut_spine(segs, closed = false, opts = [])
```

| constructor | segment |
|---|---|
| `ut_line(p0, p1)` | a straight |
| `ut_arc(c, u, v, r, ang)` | an arc about `c`, starting at `c + r*u`, sweeping `ang` degrees toward `v`. `u` and `v` are orthonormal; `0 < ang <= 180`. |
| `ut_arc_from(c, from, to, axis)` | the same arc, from its centre, endpoints and plane normal |
| `ut_sampled(pts, tans)` | a sampled chain with one tangent per point |

`ut_spine` asserts that each segment ends where the next begins and that the
tangent is continuous across every joint. A sharp corner is an error here too.

`closed = true` is the only way to make a closed path. A closed tube's bore is a
sealed cavity until something breaches it.

## Writing your own frontend

A frontend is a function that returns `ut_spine([...])` and never touches frames:

```scad
function my_frontend(...) =
    ut_spine([ ut_line(a, b), ut_arc(c, u, v, r, ang), ... ],
             false,
             [["frame", "transport"]]);
```

Two jobs belong to the frontend rather than the spine:

- **Split bends over 180°.** A single arc is capped at 180° so its tangent sign
  is never ambiguous.
- **Drop coincident samples** before calling `ut_sampled`.

If you build lists by slicing, guard the empty case: OpenSCAD silently reverses
a descending range, so `[0:-1]` is `[-1, 0]`, not empty.

## Not shipped

| | |
|---|---|
| Arc-line route (G-code / SVG-`A` semantics) | Later. The turtle covers most of it, and in 3D two endpoints and a radius do not fix the arc's plane. |
| Bezier / Catmull-Rom | Later, after arc fitting. A continuously varying radius suits a part with a minimum bend radius badly. |
| Port-to-port routing | Later. Its main use needs terminations, which are a separate library (ADR 0005). |
| SVG path strings | Rejected. SVG is 2D, and OpenSCAD has no string parsing worth the name. Preprocess outside and feed `ut_spine`. |
| Waypoint + tangent list | Rejected. It is the spine with information removed. |

More frontends are tracked in [#23].

[#17]: https://github.com/CameronBrooks11/uniTube/issues/17
[#23]: https://github.com/CameronBrooks11/uniTube/issues/23
[#36]: https://github.com/CameronBrooks11/uniTube/issues/36
