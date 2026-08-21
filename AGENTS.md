# uniTube — project rules

These take precedence over the global rules where they conflict.
The full architecture and the reasoning behind it is in `PLAN.md`.

## What this library is

A **path compiler and a hollow-network assembler**. uniTube owns the tube: how a
centreline is described, how a cross-section is carried along it, and how several
hollow runs join without sealing each other's bores.

**This library stays the tube path.** Terminations — threads, barbs, clamps,
solvent sockets, bayonets — are explicitly out of scope and will live in a
separate repository consuming only `src/ut_port.scad`'s record. Do not add them
here. See `PLAN.md` §10.

## Hard rules

1. **No dependencies.** uniTube links to nothing and vendors nothing. A fresh
   clone must render immediately. `just setup` only verifies the toolchain.
   Adding a dependency is an architectural change requiring its own ADR.

2. **No file under `src/` may `use <>` or `include <>` anything under
   `reference/`.** `reference/` is a licence quarantine holding GPLv3, CC-BY and
   unlicensed prior art. `just lint` enforces this. Copy-paste from `reference/`
   is the same violation and lint cannot see it — read for understanding, write
   from the geometry. See `NOTICE`.

3. **No file under `src/` emits top-level geometry or `echo`s on import.** Library
   and demo never share a file; demos live in `examples/`. Enforced by `just lint`.
   Every file in the pre-2026 layout violated this.

4. **Frontends produce a spine and never touch frames. Exactly one function
   lowers spine → stations. The backend consumes stations and never infers,
   guesses, or re-derives orientation.** Every historical geometry bug in this
   repo was a violation of this rule.

5. **No module emits a finished hollow tube during assembly.** The shell and the
   bore must always be separately obtainable, or the junction problem becomes
   structurally unfixable. This is why the 2023 attempt died.

6. **Silent wrong geometry is the enemy, not a hard error.** When input cannot
   produce the part that was described — overlapping fillet insets, a 180°
   reversal, a bend radius below the outer radius — `assert` with a message
   naming the offending element. Never "scale to fit", never clamp silently.
   CGAL reporting `Simple: yes` is necessary and nowhere near sufficient.

7. **Never use `acos` for an angle between vectors.** `acos(1.0000001)` is `nan`
   on OpenSCAD 2021.01, and near-collinear waypoints are the most common input
   there is. Use `atan2(norm(cross(a,b)), a*b)`.

## Toolchain

- OpenSCAD **2021.01** is the version floor. No features newer than that.
- `just check` is the CI equivalent. Run `just check && just test` before every
  commit.
- Tests are `assert`-only and must end in a `cube(0.001);` sentinel — a file
  emitting no geometry exits 1 under `-o *.stl`.
- Always render tests to `.stl`, never `.csg`: **with `-o *.csg` a failing
  `assert` exits 0**, so a `.csg` gate reports every failing test as green.
- `--hardwarnings` is mandatory in every gate. Without it an unknown named
  argument exits 0 — the exact bug that broke this library for 19 months.

## Commits

Conventional Commits, per the global rules. Scopes in use: `path`, `profile`,
`mesh`, `net`, `port`, `frontend`, `docs`, `build`.
