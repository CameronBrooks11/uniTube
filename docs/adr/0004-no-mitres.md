# ADR 0004 — `r = 0` at an interior vertex is an error, not a mitre

**Status:** accepted (2026-08-21)

## Context

It is tempting to let a fillet radius of zero mean "sharp mitred corner", the way
a plumbing elbow is mitred. Two independent design proposals specified it.

## Decision

**`r = 0` at an interior vertex is an ERROR**, naming the vertex. There is no G0
case in the IR; invariant `SPINE-3` requires tangent continuity everywhere.

## Why

Both proposals' reviewers *built* the specified representation and rendered it.
One produced a silent non-manifold with no assert; the other produced a 40 mm
skew funnel where a straight leg should have been, because an orthonormal frame
cannot place a cross-section on a bisector plane.

A working mitre needs a non-orthonormal **shear** matrix plus two coincident
stations, which violates `STATION-2` (frames are orthonormal, no scale or shear)
and `STATION-1` (no coincident stations). Legalising a construct the backend
cannot render reintroduces exactly the silent-non-manifold class this rewrite
exists to eliminate.

## Consequences

A genuinely mitred joint is expressible later as a **junction** — two runs
meeting at a declared joint — not as a path feature. That is the right layer for
it anyway, because a real mitred elbow has a weld or a moulded fillet at the
corner, which is junction geometry.
