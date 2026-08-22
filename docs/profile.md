# The profile

A profile is a **wall between two boundaries**, and the inner boundary is a
first-class object that must survive every union in the model.

```scad
prof = ["utprof", outer, inner, meta]
```

Three regions are derivable from one profile, and the entire junction story
depends on being able to ask for each independently:

```scad
ut_solid_rgn(p)   // [outer, inner]  the finished wall -> ONE capped polyhedron
ut_shell_rgn(p)   // [outer]         outer filled, bore ignored
ut_bore_rgn(p)    // [inner]         the lumen AS A POSITIVE SOLID
```

That triple **is** the tube abstraction. A generic sweeper offers only the first.

**No module ever emits a finished hollow tube during assembly** (AGENTS.md rule
5). If one did, the junction problem would be structurally unfixable — which is
exactly the trap the 2023 attempt fell into: it modelled the lumen as a separate
subtraction, so the bore pass had to re-derive the bend geometry from scratch and
never got there.

Because the lumen is an inner boundary of the *swept region*, the bore is the
same spine, the same stations and the same frame with a different region. Free.

## Winding — a deliberate deviation from the original design sketch

Both loops are stored **counter-clockwise**, not outer-CCW / inner-CW.

Reversing the inner loop would destroy the index correspondence `PROF-2`
requires, and the bore would no longer be a directly usable positive solid. The
mesh emitter reverses the inner skin's face winding instead — one line, in one
place (`src/ut_mesh.scad`, `_ut_faces_hollow`).

## Invariants

- **PROF-1** — `outer` is CCW by signed area; `inner`, when present, is also CCW.
- **PROF-2** — `len(outer) == len(inner)`, **and** both loops are parameterised by
  the same angular sweep from the same reference, so `outer[i]` corresponds to
  `inner[i]`. Equal count alone is **not** sufficient. See ADR 0006 — a square
  bore sampled by perimeter satisfies the count rule, self-intersects the end
  caps, and CGAL reports only `assertion violation`.
- **PROF-3** — a wall below `ut_min_wall()` (1.2 mm, ≈3 perimeters) is a
  **warning**, not an error. A tube that renders perfectly and prints as a hole
  is the failure this library exists to prevent.

`PROF-2` exists because the annular end cap is a **ring strip** between
corresponding points, not a polygon-with-holes triangulation. That is what keeps
the whole backend to ~120 lines.

## Constructors

```scad
ut_round(od=12, wall=2)      // exactly two of od / id / wall, asserted
ut_round(od=16, wall=2, split=[-30,30])   // C-section; split is the angular GAP
ut_round(id=8,  wall=2)      // (id, wall) is the primary spelling in the docs:
ut_round(od=12, id=8)        //   the bore is the functional dimension, the wall
                             //   is a multiple of extrusion width
ut_rod(d=10)                 // solid, no lumen -- centroid-fan end caps
ut_profile(outer, inner)     // arbitrary hollow section; asserts PROF-1..2
```

Arbitrary hollow sections — rectangular duct, D-section, keyed bore — are native.
Their generators must sample **by angle**, not by arclength.

## Known limits, stated rather than discovered

- A profile with **more than one** bore (a multi-lumen bundle) is not supported.
  The ring-strip cap handles exactly one hole; more needs a real
  polygon-with-holes triangulator. Deferred, with that cost stated.
- `ut_rod`'s centroid-fan cap requires the outline to be **star-shaped about its
  centroid** — true for any convex section. No shipped constructor produces a
  non-star-shaped closed section; one would need a real triangulator.
- A **split** section has an inner surface but no *enclosed* lumen, so
  `ut_bore_rgn()` and `ut_shell_rgn()` both return empty and the run cannot
  participate in a junction. Fine for conduit and cable channel.

  *(An earlier revision of this page predicted that a C-section would need its
  own cap strategy because it is not star-shaped. It does not: representing it as
  an OPEN ANNULUS — two loops plus two seam walls — dissolves the problem instead
  of solving it. See ADR 0007.)*

## Deferred: variation along the path

A run has ONE profile, constant along its whole length. Both mechanisms proposed
during design review were measured to be actively harmful: baking scale into the
station matrix silently emitted a port at 0.6×, and a scalar region multiplier
thinned the wall from 1.6 mm to 0.96 mm on its own example. When variation
returns it will be independent `od(u)` and `wall(u)` functions of normalised
arclength — the only form that expresses a real reducer.
