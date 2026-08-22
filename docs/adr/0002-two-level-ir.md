# ADR 0002 — The path IR has two levels

**Status:** accepted (2026-08-21) · **falsification test PASSED in Phase 4 — see below**

## Context

Many reasonable ways exist to describe a tube centreline — polyline with
per-vertex fillet radii, a turtle/bender program, a parametric function, arcs and
lines, splines. They should all compile down to one shared form. The question is
what that form *is*.

The ecosystem's native currency is a list of 4×4 transforms. Three of four
independent design proposals wanted exactly that.

## Decision

**Two levels.**

- **`utPath` (the spine)** — an ordered chain of exact segments: `L` (line),
  `A` (arc, parameterised as STEP/IGES `axis2_placement_3d`), `P` (sampled, with
  per-sample tangents). Sparse, exact, carrying **no roll and no resolution**.
- **`utStations`** — `[position, tangent, roll-normal, arclength]`, produced from
  the spine by exactly one function, `ut_stations()`.

Frontends produce a spine and never touch frames. The backend consumes stations
and never infers orientation.

## Why not a bare transform list

- Parallel transport along a circular arc has a **closed form** — rotate the roll
  reference about the arc's own axis by the arc's own sweep angle. Exact, one
  line. Sampling to points forfeits it.
- Terminal and tangency-point tangents stay exact rather than smoothed. Measured
  error when left to inference: 1.18° at a port, 7.5° at an arc tangency point.
  Across a 20 mm flange, 1.18° is ~0.4 mm of gap at the rim.
- A 100 mm straight costs 2 stations instead of ~200, and each bend takes facets
  from `$fa`/`$fs` applied to its own radius.
- The minimum-bend-radius check becomes a one-line assert. This cannot be
  delegated to the geometry: an `od=12` tube swept through an `r=4` bend
  self-intersects and CGAL reports `Simple: yes` with zero warnings.

The transform list still exists — as the *output* of `ut_stations()`, produced at
the backend boundary.

## Consequences

Roughly 80 extra lines, and the layer most at risk of being ceremony.

**Falsification test, stated in advance:** Phase 4 ships the turtle frontend. If
the turtle does not fall out of the spine cleanly — if the spine has to grow a
case, or the turtle reimplements any frame or tessellation logic — **delete the
spine layer** in favour of a bare station list. Do not defend it.


---

## Falsification result (Phase 4)

The test was stated in advance, in this ADR and in the phase plan: if the turtle
frontend did not fall out of the spine cleanly — if the spine had to grow a case,
or the turtle reimplemented any frame or tessellation logic — **the spine layer
would be deleted in favour of a bare station list, not defended.**

It fell out cleanly. Recorded as facts, not recollection:

- **No core module changed.** `ut_path.scad`, `ut_profile.scad`, `ut_mesh.scad`,
  `ut_core.scad` and `ut_math.scad` were checksummed before `ut_turtle.scad` was
  written and verified byte-identical after both new frontends were finished.
- **Neither frontend references frame or tessellation logic at all** — zero
  mentions of `ut_fragments`, `ut_ref_fallback`, `ut_ortho`, `_ut_transport`,
  `ut_st_mat` or `ut_stations` between them.
- `ut_turtle.scad` is 65 lines; `ut_curve.scad` is 53.

**The strongest single piece of evidence** is the turtle's `roll` command. It
emits no geometry: it rotates the turtle's own up-vector, which changes the plane
of every subsequent bend and therefore the shape of the path, and then it is
gone. Nothing about roll enters the spine, because a bender rotating the
workpiece does not twist the tube. `SPINE-5` — *the IR carries no roll* — survived
contact with the one frontend that has an explicit roll command, which is the
case most likely to have broken it.

Two frontend-side responsibilities were confirmed as belonging to the frontend
rather than the spine, and neither required a change to the IR: splitting a bend
beyond 180° into two arcs (`SPINE-4`), and deduping coincident samples before
building a `P` segment (`STATION-1`).

**The spine stays.**

## Known limit, recorded 2026-08-21

`SPINE-5` says the IR carries no roll and no resolution. The roll half holds
everywhere — `ut_turtle`'s `roll` command proved it above. **The resolution half
does not hold for `P` segments:** `ut_curve` bakes its sample count into the
spine, and `$fa`/`$fs` are inert on the result (measured: 161 stations at both
`$fa=24` and `$fa=0.5`, where an arc path gives 7 and 183).

`docs/ir.md` now states this as a limit rather than claiming the invariant. The
fix is a biarc fitter, which exists as a working prototype in
`spikes/biarc_fitter.scad` and is deliberately not built — see issue #17
for the measurements that demoted it.
