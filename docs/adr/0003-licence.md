# ADR 0003 — uniTube is BSD-2-Clause; prior art is quarantined

**Status:** accepted (2026-08-21) · **amended 2026-08-21 — see below**

## Context

The repository had **no root LICENSE** while mixing five regimes: public domain
(`maths.scad`), BSD-3 (`pipe-joints/`), GPL unspecified (`vector.scad`), GPLv3
(`path_extrude.scad`, `Round_Ducting`), CC-BY (`curvedPipe/LICENSE.txt`), and one
file copied from a personal blog with **no licence statement at all**.

The binding problem: GPL `vector.scad` was `use <>`d by every core file, and
OpenSCAD's `use <>` is source-level inclusion at parse time. The conservative
reading is that uniTube as it stood had to be GPL — a real adoption tax for a
library meant to be dropped into commercial part designs, and in direct conflict
with the BSD-3 `pipe-joints` code already in the tree.

## Decision

- uniTube is **BSD-2-Clause**.
- All third-party and historical code moves to `reference/`, which is a
  **read-only quarantine**. No file under `src/` may import from it, enforced by
  `just lint` (rule 2 in `AGENTS.md`).
- Provenance for every retained file is recorded in `NOTICE`.
- `vector.scad`'s six consumed functions are reimplemented from their
  mathematical definitions in `src/ut_math.scad`. `cross` and `norm` are OpenSCAD
  builtins; the vendored versions were shadowing them.

## Consequences

- With ADR 0001 (no dependencies) there is now **no upstream licence to
  accommodate at all**.
- The axford lineage is CC-BY, which is attribution-only and would be workable
  with a credit line. It is still reimplemented rather than forked, because
  `someShapes.scad` claims "Public Domain" while admitting it borrowed from
  GPLv3 Mendel90 — a contradiction unresolvable from the files. The affected code
  is ~20 lines of `linear_extrude`/`rotate_extrude`; rewriting is cheaper than
  adjudicating. axford is credited in `README.md` and `NOTICE`.
- `reference/jantecnl/` has no licence of any kind. Only its run *coordinates*
  are used, as a test fixture. If provenance is ever contested, deleting that
  directory costs nothing.
- **Lint cannot detect copy-paste.** `reference/gringer/path_extrude.scad` is
  GPLv3 and is the most tempting file to crib from while writing
  `src/ut_mesh.scad`. This is called out in `NOTICE` and `AGENTS.md`.


## Amendment — `reference/jantecnl/` deleted

This ADR originally kept the 4-into-1 prototype on the grounds that "only its run
*coordinates* are used, as a test fixture" and "if provenance is ever contested,
deleting that directory costs nothing".

It has been deleted. The coordinates are now first-party geometry in
`examples/06_manifold_4into1.scad`, so the directory bought nothing but a file
with **no licence statement of any kind** sitting in a repository whose whole
licence story is otherwise clean. The historical record survives in
`docs/salvage.md` §4 and in the git history.

Everything else in this ADR stands.
