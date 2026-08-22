# uniTube — project rules

These take precedence over the global rules where they conflict.
The architecture and the reasoning behind it is in `docs/`; the decisions are
in `docs/adr/`. Outstanding and deliberately-deferred work is tracked in GitHub
issues, not in a file.

## What this library is

A **path compiler and a hollow-network assembler**. uniTube owns the tube: how a
centreline is described, how a cross-section is carried along it, and how several
hollow runs join without sealing each other's bores.

**This library stays the tube path.** Terminations — threads, barbs, clamps,
solvent sockets, bayonets — are explicitly out of scope and will live in a
separate repository consuming only `src/ut_port.scad`'s record. Do not add them
here. See ADR 0005 and issue #19.

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

## OpenSCAD 2021.01 gotchas, all verified in this repo

These cost real time in Phase 1. Each is a silent or misleading failure.

- **`use` does NOT transitively re-export.** A consumer doing `use <A>` where A
  does `use <B>` cannot see B's functions. `include` merges into the file scope
  and IS re-exported. That is why `src/uniTube.scad` uses `include` and every
  other file uses `use`. Relative paths resolve against the file containing the
  directive, so `frontend/`'s `../` imports survive being included from `src/`.
- **`use` does not export top-level VARIABLES either.** Every shared constant in
  this library is a zero-argument function (`ut_eps()`, `ut_up()`).
- **`assert` messages are evaluated EAGERLY**, even when the condition passes.
  `assert(is_num(r) || ..., str("...", len(r)))` warns on a scalar `r` because
  the message runs regardless. Keep messages free of calls that can fail.
- **clang-format destroys import lines** — `use <a/b.scad>` becomes
  `use<a / b.scad>` and the resulting error names the wrong file. Always wrap the
  import block in `// clang-format off` / `on`, and terminate each with `;`
  (without the semicolon clang-format also mis-indents the whole file after it).
  `just lint` rule 3 enforces the well-formed shape.
- **clang-format splits long string literals**, producing `"a" "b"`, which is a C
  idiom and a SYNTAX ERROR in OpenSCAD. `BreakStringLiterals: false` is set in
  `.clang-format` for exactly this reason. Never turn it back on.
- **`is_nan()` does not exist.** Use `is_num(x)` (false for nan, TRUE for inf) or
  `x == x` (false for nan only). The two distinguish the failure modes this
  library cares about: `acos` past 1.0 gives nan, `tan(90)` gives inf.
- **`cross()` requires 3-vectors.** For a planar angle use `atan2(y, x)`.
- **`max()` and `min()` SILENTLY DROP `nan`.** `max([1e-16, nan])` is `1e-16`,
  not `nan`. So `assert(max([...]) < eps)` is blind to exactly the failure it is
  usually written to catch — this let a station frame of `[nan,nan,nan]` pass the
  one assert guarding frame validity. Count offenders instead:
  `assert(len([for (x = v) if (!is_num(x)) 1]) == 0, ...)`.
- **A descending range is SILENTLY REVERSED.** `[0:-1]` evaluates to `[-1, 0]`,
  not to an empty list, and `--hardwarnings` says nothing. Any `[for (k = [0:i-1])
  ...]` prefix slice must be guarded with `i == 0 ? [] : ...`, and any
  `[i+1:len(v)-1]` suffix with `i >= len(v)-1 ? [] : ...`. This corrupted
  `ut_turtle`'s >180° bend split at both ends of a program, and the abort named
  the wrong cause: `unknown command "undef"`.
- **Swept quads are non-planar.** Emit triangles, or OpenSCAD prints "PolySet has
  nonplanar faces. Attempting alternate construction" and guesses the topology.

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

## Verification tiers

`just check` is the commit gate. `just verify` is the slow pre-release gate and
splits in two:

- **`just cgal`** — forced-CGAL manifoldness over every example. Each example
  exposes a `part()` module so the recipe can wrap it in a PROVABLY NO-OP
  intersection. Do not force CGAL by subtracting a tiny cube: it perturbs the
  geometry, and at the origin of a manifold that is inside the material.
- **`just preview`** — renders every example through **OpenCSG**, the F5 path,
  and fails if a closed part shows back faces. Every other gate uses CGAL, so
  none of them can see a preview that lies. One did: an assembly displayed as a
  solid slug, 79.3% of its pixels the subtracted bore, while CGAL said
  `Simple: yes`. Preview is the mode this library is used in.
- **`just partspec`** — declared engineering intent in `checks/`, verified with
  [partspec](https://github.com/CameronBrooks11/partspec). This is a DEV-TIME
  tool; uniTube itself still links to nothing.

**`Simple: yes` is necessary and nowhere near sufficient.** Every silent failure
this design was reviewed against passed it — a sealed branch lumen, a deleted
coaxial liner, a self-intersecting bend, a junction held together by slivers.
Assert patency with a `keep_out` down the lumen, and size the region INSIDE the
modelled bore: `region.cylinder` circumscribes its declared circle while the
modelled bore is inscribed in its own `$fn`, so a probe at nominal `d` cannot pass.

**Validate every new check by deliberately reintroducing the bug it claims to
catch.** A check that cannot fail is worth nothing. `tests/guards/` does this for
asserts; the partspec contracts were validated the same way.

## Commits

Conventional Commits, per the global rules. Scopes in use: `path`, `profile`,
`mesh`, `net`, `port`, `frontend`, `docs`, `build`.
