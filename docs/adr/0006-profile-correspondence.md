# ADR 0006 — Profile loops must be correspondence-aligned, not merely equal in count

**Status:** accepted (2026-08-21) · discovered while prototyping ADR 0001

## Context

`src/ut_mesh.scad` sweeps a *region* — an outer loop and an inner loop — and caps
each end with a **ring strip** between corresponding points, rather than running a
general polygon-with-holes triangulation. That is what keeps the emitter to ~120
lines. It requires `len(outer) == len(inner)`.

## Decision

Equal point count is **necessary but not sufficient**. Invariant `PROF-2`
additionally requires that both loops be parameterised by the **same angular
sweep from the same reference**, so that `outer[i]` and `inner[i]` correspond.

Constructors (`ut_round`, `ut_round(split=)`) guarantee it. `ut_profile()`
asserts it.

## Evidence

A square bore resampled by *perimeter* into 32 points satisfies the count rule
but starts at a corner (225°) while the circle starts at 0°. The cap strip then
twists around the annulus and self-intersects. Rendered result: **`CGAL error in
CGAL_Nef_polyhedron3(): assertion violation!`** — no useful diagnostic.

Re-parameterising the square by angle (ray-cast from the centre at the same
angles as the circle) fixes it: `Simple: yes`, Volumes 2, and the mesh volume
matches the analytic value to six significant figures.

## Consequences

- Arbitrary hollow sections (rect duct, D-section, keyed bore) are supported, but
  their generators must sample by angle, not by arclength.
- A profile with **more than one** bore is *not* supported by the ring-strip cap
  and needs a real triangulator. Deferred to Phase 5 with that cost stated.
- This would otherwise have surfaced in Phase 2 as an unexplained CGAL assertion
  on the first non-circular profile.
