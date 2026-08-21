# ADR 0001 — uniTube takes no dependencies

**Status:** accepted (2026-08-21) · supersedes an earlier proposal to depend on BOSL2

## Context

A tube swept along a path needs a mesh backend: stamp a cross-section at each
station frame, stitch the sides, cap the ends. BOSL2's `sweep()` does this and
accepts a *region* (outer loop plus inner loop), which makes a hollow tube one
polyhedron with annular end caps and no CSG along a run. That capability is what
made the whole redesign affordable and it was the original recommendation.

The counter-pressure: the project's own rules prefer no dependency where one can
be avoided, and the owner's position was explicit — *"I really don't want this
lib having deps if I can avoid it, I'd rather do this math and geometry from
ground up."*

## Decision

**No dependencies.** The backend is written from the geometry in `src/ut_mesh.scad`.

The decisive argument is that ADR 0002 (the two-level IR) already means uniTube
computes its **own** frames. That reduced the dependency's contribution to a mesh
stitcher — and a prototype of exactly that was written and validated before this
decision was taken:

| probe | result |
|---|---|
| Annular sweep, 90° elbow, ~40 lines, no libraries | `Simple: yes`, 2178 facets, 0.4 s forced CGAL |
| Closed loop (torus, caps suppressed, index wrap) | `Simple: yes` |
| Non-circular bore (square in round shell) | `Simple: yes`, once correspondence-aligned |
| `ut_volume()` — divergence theorem, ~6 lines | 6109.76 vs analytic 6109.762 — exact to 6 s.f. |

## Consequences

- Zero-install. A fresh clone renders immediately; `just setup` only checks the
  toolchain. For an OpenSCAD library, where users drop a folder into their
  library path, this is a real adoption advantage.
- No upstream licence to accommodate, which simplifies ADR 0003.
- **Cost:** roughly one extra day in Phase 1, and no `join_prism` for junction
  fillets later. That matters less than it appears — `join_prism` cannot join to
  a *curved* swept surface (its base must be a plane, sphere, straight cylinder
  or straight prism), which is binding for a library whose premise is curved
  paths. v1 ships creased junctions regardless.
- **Do not copy from BOSL2 as a shortcut.** BSD-2 permits it with the notice
  retained, so it is legally clean, but its internals are deeply interconnected
  and a copied function drags helpers that drag more helpers.
- One invariant surfaced from the probe that would otherwise have appeared in
  Phase 2 as an unexplained CGAL assertion: see `PROF-2` in ADR 0006.
