# ADR 0002 — The path IR has two levels

**Status:** accepted (2026-08-21), with a falsification test scheduled in Phase 4

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
