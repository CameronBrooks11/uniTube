---
title: Verification
parent: Developer
nav_order: 1
---

# What "check" and "test" mean for CAD

A geometry library has no natural notion of a passing test. There is no return
value to compare, the output is a mesh, and the failures that matter are the ones
that still render. This is the answer this project settled on.

## OpenSCAD's exit codes, measured

Re-verified on 2021.01, because the received wisdom is contradictory and mostly
wrong. Every gate in this repository is shaped by this table.

> **Known issue ([#38](https://github.com/CameronBrooks11/uniTube/issues/38)).**
> Everything here is measured on 2021.01, the version CI pins. On 2026.10.15
> `tests/t_scoping.scad` fails and `just cgal` cannot pass, because that version
> prints no `Simple: yes` line.

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
   `just check` also measures the **signed volume of every exported mesh**
   (`tools/stl_volume.py`) and fails on a negative one. CGAL cannot stand in for
   that: it repairs an inside-out polyhedron in any boolean and says nothing.
5. **Preview correctness** — `just preview`. Renders each example through
   **OpenCSG**, not CGAL, and fails if a closed part shows back faces. See below.
   Known issue ([#37](https://github.com/CameronBrooks11/uniTube/issues/37)):
   an example is reported ok when the pixel checker prints nothing.
6. **Declared engineering intent** — `checks/`, verified with
   [partspec](https://github.com/CameronBrooks11/partspec). A dev-time oracle;
   uniTube itself still links to nothing. `just partspec`.

**Golden STL hashes were considered and rejected.** They are brittle to facet
order, floating point, and any `$fa`/`$fs` change, and they train people to
ignore the suite.

## Preview draws the mesh as given, including inside-out

Every tier above except `just preview` evaluates geometry with CGAL, and CGAL
repairs an inside-out polyhedron in any boolean without a word. **F5 preview does
not.** OpenCSG draws the operands of a `difference()` as they were handed to it.

So preview was the one place the winding defect showed
([`history.md`](history.md) §9), and it showed as an assembly that looked solid.
Measured on `examples/08_coaxial_jacket`, previewed without `ut_assemble()`'s
`render()` wrapper, as the percentage of model pixels that are back faces:

| swept faces | 2021.01 | 2026.10.15 |
|---|---|---|
| inside-out, as emitted before the fix | **79.3%** | **79.3%** |
| wound the way `polyhedron()` expects | 0.0% | 0.0% |

At 79.3% the part is a solid green slug: no bore, no liner, no annulus. Every
CGAL gate said `Simple: yes`, `Volumes: 3`, with 19/19 partspec assertions
passing.

**This page used to give a different cause.** It said OpenCSG ran out of depth
layers on a hollow assembly and painted the subtracted solid over the shell, and
that wrapping the CSG in `render()` cured it by evaluating the booleans for real.
The control above settles it: the same OpenCSG and the same model go from 79.3%
to 0.0% when only the winding changes. `render()` helped because it runs CGAL,
which repairs the orientation. `polyhedron(convexity=)` made no difference at 10,
20 or 40, which fits: convexity was never the problem.

The STL once recorded here as "exported from preview" — 9688 triangles, signed
volume −174446, and at the time 3429 non-manifold edges — is what an ordinary
`-o x.stl` export of that example produced on 2026.10.15 while the faces were
inside-out.

`ut_assemble()` still wraps its CSG in `render()`. With the winding right, the
unwrapped preview of that example is also correct. Whether the wrapper is still
worth a CGAL evaluation in preview is open; see the colouring note below before
removing it.

### What the gate measures, and what it cannot

OpenSCAD's Cornfield scheme paints front faces yellow and back faces green, and
a part viewed from outside shows no back faces. `just preview` fails an example
with more than 2% green. On 2021.01 every example reads 0.0%.

Three things about that colour, each measured on a cut tube:

| preview of | 2021.01 | 2026.10.15 |
|---|---|---|
| `difference()` with a 160 mm cutter, not rendered | cut, 28.9% green | cut, 28.9% green |
| the same wrapped in `render()` | cut, 0.0% | cut, 28.7% green |
| `difference()` with a 1000 mm cutter, not rendered | **not cut**, 0.0% | cut, 28.9% green |
| OpenSCAD's own `cylinder` minus `cube(1000)` | **not cut** | **not cut** |
| OpenSCAD's own `cylinder` minus `cube(160)` | cut | cut |

- **OpenCSG draws a subtracted solid's faces green.** That is by design, on both
  versions, so green is not only a symptom of a defect. Every boolean in this
  library is wrapped in `render()`, and on 2021.01 a rendered result is drawn
  all yellow, which is why the gate reads 0.0% there. 2026.10.15 keeps the
  green on a rendered result, so the gate does not apply to it ([#38]).
- **A cutter that contains the camera is not subtracted at all.** The last two
  rows use no uniTube geometry. `ut_cutaway()` needs a cutter far larger than
  the part, so it evaluates its difference with `render()`. It did not before,
  and while the swept faces were inside-out the two errors drew something that
  passed for a section.
- **The gate cannot see a cut that did not happen.** An uncut part reads 0.0%,
  the same as a clean one. `examples/12_section_view` passed with no section
  drawn. Nothing yet asserts that a cutaway cuts in preview.

[#38]: https://github.com/CameronBrooks11/uniTube/issues/38

## `Simple: yes` is necessary and nowhere near sufficient

Every silent failure this design has been reviewed against passed it:

- a sealed branch lumen — `Simple: yes, Volumes: 2`,
- a coaxial liner deleted entirely — 26% of the material gone,
- a tube swept through a bend tighter than its own radius, passing through
  itself — `Simple: yes, Volumes: 2` and a plausible positive volume,
- a junction rendering as separate solids held together by a shared circle,
- and every swept solid inside-out: a plain tube exporting −5865.23 mm³ for
  +5865.23, and an assembly previewing as a solid slug.

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

The partspec contracts in `checks/` were validated the same way. Disabling the
bore extension produced `61.02 mm3 of material intrudes into the keep-out region`
while `watertight` and `solid_count` both still passed. Collapsing the lumen
groups produced `solid_count — measured 1, limit equals=2`.

That standard is why `just check` would have caught the regression that started
this project, at commit time, in about eight lines of shell.
