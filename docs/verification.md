# What "check" and "test" mean for CAD

A geometry library has no natural notion of a passing test. There is no return
value to compare, the output is a mesh, and the failures that matter are the ones
that still render. This is the answer this project settled on.

## OpenSCAD's exit codes, measured

Re-verified on 2021.01, because the received wisdom is contradictory and mostly
wrong. Every gate in this repository is shaped by this table.

| command | exit |
|---|---|
| `openscad -o x.stl` with a failing `assert` | **1** — `assert` *is* a test framework |
| `openscad -o x.csg` with a failing `assert` | **0** — never use `.csg` for tests |
| `openscad -o x.stl` with an unknown named argument | **0** |
| `openscad --hardwarnings -o x.stl`, same file | **1** — catches the `torusSlice` bug class |
| `openscad -o x.stl` on a file emitting no geometry | **1** — hence the sentinel `cube(0.001)` |
| `openscad -o /dev/null` | **1** — no suffix; always write into `out/` |

Two consequences worth stating on their own, because both were once wrong here
and neither is visible from a green build:

- **Always render tests to `.stl`, never `.csg`.** A `.csg` gate reports every
  failing test as green.
- **`--hardwarnings` is mandatory in every gate.** Without it an unknown named
  argument exits 0 — the exact bug that made every bend render as nothing for 19
  months.

## The tiers, in ascending cost

1. **Data assertions** — milliseconds, no rendering. The bulk of the suite, and
   only possible because the IR is data rather than geometry. `just test`.
2. **Guards** — every file in `tests/guards/` *must* fail. An assert nobody has
   watched fail is not known to work. `just guards`, folded into `just check`.
3. **Advisory warnings** — `echo()` calls, which `--hardwarnings` does *not*
   promote and which a guard therefore cannot cover. Silencing one would
   otherwise pass every gate. `just warnings`.
4. **Mesh properties** — forced CGAL, because a raw `polyhedron()` is never
   validated in preview, so "renders clean" is not evidence of a valid solid.
   Plus this library's own `ut_volume()`, which agrees with analytic values to 6
   significant figures, so volume bands can be tight. `just cgal`.
5. **Declared engineering intent** — `checks/`, verified with
   [partspec](https://github.com/CameronBrooks11/partspec). A dev-time oracle;
   uniTube itself still links to nothing. `just partspec`.

**Golden STL hashes were considered and rejected.** They are brittle to facet
order, floating point, and any `$fa`/`$fs` change, and they train people to
ignore the suite.

## `Simple: yes` is necessary and nowhere near sufficient

Every silent failure this design has been reviewed against passed it:

- a sealed branch lumen — `Simple: yes, Volumes: 2`,
- a coaxial liner deleted entirely — 26% of the material gone,
- a tube swept through a bend tighter than its own radius, passing through
  itself — `Simple: yes, Volumes: 2` and a plausible positive volume,
- a junction rendering as separate solids held together by a shared circle.

A self-intersecting run logs **both** `CGAL ERROR: assertion violation!` and
`Simple: yes`, and `openscad` exits 0 — so `just cgal` greps for the error text
as well, and grepping only for `Simple: yes` was itself a bug here once.

Assert lumen patency with a `keep_out` down the bore, and size the region
*inside* the modelled bore: `region.cylinder` circumscribes its declared circle
while the modelled bore is inscribed in its own `$fn`, so a probe at nominal `d`
cannot pass.

## The rule that makes any of it worth having

**Validate every new check by deliberately reintroducing the bug it claims to
catch.** A check that cannot fail is worth nothing. `tests/guards/` holds those
reintroductions, and every one is watched to fail before it is trusted.

That standard is why `just check` would have caught the regression that started
this project, at commit time, in about eight lines of shell.
