# Frontends

There are many reasonable ways to describe a tube centreline. They all compile to
one canonical spine (`docs/ir.md`), and the backend never learns which was used.

## Shipped

| frontend | what it is for |
|---|---|
| `ut_polyline(pts, r=)` | waypoints plus per-vertex fillet radii. The incumbent API and the migration path. |
| `ut_spine([...])` | the IR itself, as public API. |
| `ut_turtle([...])` | a bender program — Length, Rotation, Angle. Relative, with an explicit roll. |
| `ut_curve(f, dfdt=)` | an arbitrary parametric centreline: helices, coils, serpentines, generated routes. |

```scad
ut_polyline([[0,0,0], [50,0,0], [50,50,0]], r = 15)

ut_spine([ ut_line([0,0,0], [35,0,0]),
           ut_arc_from(c = [35,15,0], from = [35,0,0], to = [50,15,0], axis = [0,0,1]),
           ut_line([50,15,0], [50,50,0]) ])

ut_turtle([["feed", 60], ["bend", 90, "r", 24], ["feed", 40],
           ["roll", 90], ["bend", 45, "r", 24], ["feed", 30]])

ut_curve(function(t) [80*cos(360*t), 80*sin(360*t), 60*t], n = 180)
```

## Choosing one

- **Known absolute coordinates?** `ut_polyline`. Its guards are the strongest,
  because it is the one that can be over-constrained (see `PLAN.md` §9.5).
- **Describing how the tube is BENT rather than where it goes?** `ut_turtle`. It
  is how a real bender is programmed and it round-trips with manufacturing data.
- **A formula?** `ut_curve`.
- **Something else entirely?** `ut_spine`. The IR is public precisely so an
  unanticipated source — a solver, a CSV of surveyed points, another library's
  output — is never blocked.

## What `roll` proves

`ut_turtle`'s `roll` command emits **no geometry**. It rotates the turtle's own
up-vector, which changes the PLANE of every subsequent bend and therefore the
shape of the path — and then it is gone. Nothing about roll enters the spine,
because a bender rotating the workpiece does not twist the tube.

That is the sharpest evidence that `SPINE-5` — *the IR carries no roll* — is the
right invariant, and it survived contact with the one frontend that has an
explicit roll command. See ADR 0002.

## The honest cost of a sampled path

`ut_curve` lowers to a single `P` segment, and a `P` segment gives up three
things that arcs provide:

| | arc-based (`ut_polyline`, `ut_turtle`) | sampled (`ut_curve`) |
|---|---|---|
| arclength | exact, closed form | chord sum, slightly under |
| transport | exact, closed form | discrete, O(h²) |
| `CHECK-1` min bend radius | asserted, exact | asserted from **discrete curvature** — accurate (11.014 against an analytic 11.013 on a helix) but it fails OPEN, so a marginal case can slip through |

Measured on a 2-turn helix at n=160: the sampled length is 0.025% under the
analytic value, and interior tangents from central differences agree with the
analytic tangent to 0.006°.

**The ends used to be first-order** — a two-point chord, error about half a
sample's rotation, measured 2.24° at n=160. Since the ends are exactly where port
frames come from (`STATION-3`) and 2.2° across a 20 mm flange is ~0.8 mm of gap,
that was the only error in a sampled path large enough to make a physical part
wrong. `_ut_central` now uses a **three-point one-sided difference**, which is
second order like the interior:

| n | two-point (old) | three-point (now) |
|---|---|---|
| 40 | 8.949° | 0.460° |
| 160 | 2.237° | **0.0141°** |
| 320 | 1.119° | 0.0032° |

Supplying `dfdt` is still exact and still worth doing when you know the
derivative — it is just no longer the difference between a usable port and a bad
one.

> **Foot-gun.** Only the *direction* of `dfdt` is used, but the relative scaling
> of its components matters — and OpenSCAD's trig is in DEGREES:
> `d/dt cos(360*k*t) = -2*PI*k * sin(360*k*t)`.
> Dropping the `2*PI` leaves a helix's tangents ~6° out at every sample while
> looking entirely plausible. Measured, while writing this. When in doubt, omit
> `dfdt` and let central differences do it.

The honest upgrade is a **biarc fitter**: approximate each span by a pair of
tangent-continuous arcs to a tolerance, emitting real `["A"]` segments and
restoring all three properties. CAM systems have done this since the 1980s.
`PLAN.md` §10.

## Not shipped, and why

| | verdict |
|---|---|
| **Arc-line route** (G-code / SVG-`A` semantics) | Later. The turtle covers most of its expressive range with better ergonomics, and in 3D the arc plane is underdetermined by two endpoints and a radius. |
| **Bezier / Catmull-Rom** | Later, and second-class in an arc-native IR: a continuously varying radius is precisely wrong for a part with a minimum printable bend radius. Wants the biarc fitter first. |
| **Port-to-port routing** | Later. The right frontend when the constraint is a *direction* — "leave the pump axially, arrive at the tank radially" — but its killer use case needs terminations, which are a separate library (ADR 0005). |
| **SVG path strings** | **Rejected.** Steal the semantics, not the syntax: the modal cursor and smooth-continuation ideas are already in the turtle. But SVG is 2D, so the interesting half (Z, roll) is undefined; OpenSCAD has no regex or split, so a real parser is hundreds of lines of the least testable code in the language; and nobody exports 3D pipe runs as SVG. Preprocess outside OpenSCAD and feed `ut_spine`. |
| **Waypoint + tangent list** | **Rejected.** It is the IR with information removed and a conversion pass added. Anyone who can supply exact tangents can supply an exact spine. |

## Writing your own

A frontend produces a spine and **never touches frames**. That is the whole
contract, and it is why the two shipped in Phase 4 needed no change to the core:

```scad
function my_frontend(...) =
    ut_spine([ ut_line(a, b), ut_arc(c, u, v, r, ang), ... ],
             false,
             [["frame", "transport"]]);
```

The constructors assert the `SPINE` invariants for you. If your source can
produce a bend beyond 180°, split it — `SPINE-4` caps a single arc so the tangent
sign can never be ambiguous, and splitting is the frontend's job.

> **Splice carefully.** `ut_turtle` splits by replacing the oversized bend in its
> own command list with two halves and re-entering at the same index. Both slices
> around it must be guarded against being empty, because **OpenSCAD silently
> reverses a descending range**: `[0:-1]` is `[-1, 0]`, not `[]`, and
> `--hardwarnings` says nothing. Unguarded, a bend over 180° as the *first* or
> *last* command spliced `undef` into the program and aborted with
> `unknown command "undef"` — naming the wrong cause entirely. The only case
> covered had commands on both sides of the bend, so neither boundary was tested.

A frontend that emits `P` segments gets one guard for free: `ut_sampled()` rejects
2D points and tangents by name. Without it a 2D curve builds a spine happily and
fails at *sweep* time with `atan2() parameter could not be converted`, pointing at
`ut_math` rather than at your curve.
