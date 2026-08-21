# ADR 0007 — A C-section is an OPEN ANNULUS, not a single closed loop

**Status:** accepted (2026-08-21) · Phase 2

## Context

`PLAN.md` §3 described the split tube as returning "ONE closed C-shaped loop —
the outer arc from 30 to 330, then the inner arc back from 330 to 30 — with
`inner=undef`". `docs/profile.md` then predicted the consequence: a C-section is
**not star-shaped about its centroid**, so `ut_rod`'s centroid-fan end cap would
produce faces crossing the void, and the section would need "its own cap
strategy" — realistically a general polygon triangulator, the one piece of work
ADR 0001 deliberately deferred.

## Decision

Keep the split section as **two loops, outer and inner**, exactly like a closed
tube — but mark the profile `open` in its meta. The emitter then:

- runs the outer and inner skins over `i = 0 .. N-2` instead of wrapping,
- runs the end caps as ring strips over the same range,
- and adds **two seam walls**, the cut faces that close the split along the whole
  run: a quad strip at `i = 0` and another at `i = N-1`.

That is one extra term in `_ut_faces_hollow` and one conditional index bound.

## Consequences

**No triangulator is needed, and none of the deferred work came due.** The
prediction in `docs/profile.md` was pessimistic because it accepted the plan's
single-loop framing; changing the representation dissolved the problem rather
than solving it.

`PROF-2` correspondence is preserved for free — both loops are sampled at the
same angles across the material span, exactly as in the closed case.

The seam walls are **not optional**. Without them the surface is not closed and
CGAL rejects the mesh outright, which is at least a loud failure rather than a
plausible-looking wrong solid.

A split run still has no **enclosed** lumen, so `ut_bore_rgn()` and
`ut_shell_rgn()` both return empty and the run cannot participate in a junction.
That limit is unchanged and is what C-sections are for: conduit, cable channel,
and parts that print open-side-up without bridging.

`ut_rod`'s centroid fan remains, and remains restricted to sections that are
star-shaped about their centroid. A genuinely non-star-shaped *closed* profile
would still need a triangulator — but no shipped constructor produces one.
