# uniTube — Development Plan

**Status:** revision 2 — decisions settled. **Phases 0-3 merged; Phase 4 complete
and in review.** The v1 core is done: path, profile, and network.
See §11 for outcomes and deviations.
**Date:** 2026-08-21 · **Last commit:** `5d2975b`, 2025-01-10 (19 months cold)

Produced by a 12-agent review (survey → four competing architectures → one
adversarial reviewer each → synthesis), then revised against your decisions.
Claims marked *measured* were verified by rendering on this machine's OpenSCAD
2021.01, not taken from documentation.

**Revision 2 changes one thing and it is the big one: uniTube takes no
dependencies.** The sweep backend is written from the geometry. See §2.1 and §9.1.

---

## 1. Where this actually stands

The library has been broken for 19 months and the cause is small. Commit
`5d2975b` renamed `torusSlice`'s parameters in `libs/someShapes.scad:18` from
`(r1, r2, r3)` to `(radius, xsec_or, xsec_ir)` and did not update the three call
sites. Every bend renders as *nothing*; only the straight segments survive.

Fixing that rename alone isn't worth doing, because the architecture underneath
it is the real problem:

**Silent geometry corruption, measured.** There is no guard on
`l1 - preInset - inset < 0`, and OpenSCAD emits nothing at all for
`linear_extrude(height <= 0)` without warning. The same path at `radii=[20,20]`
renders genus 1 (a correct tube); at `radii=[80,80]` on a 100 mm leg it renders
**genus 2** — an extra through-hole — with zero diagnostics. A 180° reversal gives
`tan(90) = inf` → `[nan,nan,nan]` and the segment vanishes. `anglev`'s `acos`
returns NaN when float error pushes past 1.0, which fires on near-collinear
waypoints — the most common input there is.

**Dead weight.** Of the 1035 vendored lines in `maths.scad` + `vector.scad`,
**~7% is reachable**: 3 functions from maths (all only to implement
`pipeOrientate`) and 6 from vector, all OpenSCAD builtins today. The 280-line
spline section has zero call sites. `curvedPipe2.scad` is a near-exact copy of
`curvedPipe.scad` differing in 3 substantive lines. `half_curvedPipe.scad`
silently caps any path at **9 segments** — the if-nest bottoms out at
`if (8 <= segments-2)`.

**`pipeCurveCutout` was never deleted.** It is alive at
`proto/curvedPipe-for-pipeconnector-4-into-.scad:107-172`; `5d2975b` only
reformatted and moved it. It is ~60% done and stops exactly at the hard part — it
calls `torusSlice_only_inner_pipes()`, which `git log -S` confirms was **never
defined in any commit**.

**And the junction fix already ships in your repo, in the wrong file.**
`ductFits/Round_Ducting_V1.1.scad:168-228` (`middle_tee_n`, `manifold_n`) does
`difference(union(shell + N branches), union(bore + N bores))` — the two-pass from
the inherited TODO — working, on real geometry.

---

## 2. The two decisions that unlock everything

### 2.1 A swept annular region is ONE polyhedron — and we emit it ourselves

The architectural insight is about the geometry, not about any library: **stop
building a tube as a union of straight tubes and torus slices, and stop modelling
the bore as a subtraction.** Sweep a *region* — outer loop plus inner loop — along
a list of station frames, and stitch it directly into a single `polyhedron()`
with genuine annular end caps. No CSG anywhere along a run.

That single change deletes `torusSlice`, `torusSliceF`, `tube`, `halfTorusSlice`,
`halfTube`, `pipeOrientate`, the quaternion dance, and the signature mismatch that
broke the library. **It also means the lumen belongs to the profile, not to a
subtraction** — which is precisely why the 2023 attempt died: modelling the bore
separately forced `pipeCurveCutout` to re-derive the bend geometry from scratch,
and it never got there.

Revision 1 proposed getting this from BOSL2. **We are writing it instead**, and
the mechanism was prototyped and validated before this plan was revised:

| probe | result |
|---|---|
| Annular sweep, 90° elbow, ~40 lines, zero libraries | `Simple: yes`, Volumes 2, 2178 facets, **0.4 s** forced CGAL |
| Closed loop (torus, caps suppressed, index wrap) | `Simple: yes` |
| Non-circular bore (square in round shell) | `Simple: yes` *(after the fix below)* |
| `meshvol()` — divergence theorem, ~6 lines, replaces `vnf_volume` | 6109.76 vs analytic 6109.762 — **exact to 6 s.f.** |

The whole emitter is: place each 2D profile point into each station frame
(`p + x·n + y·b`), quad-strip the outer skin, quad-strip the inner skin reversed,
and ring the two end caps. Roughly 120 lines with the guards and the closed case.

**One real invariant came out of the probe and it would have bitten in Phase 2.**
Matched point count between the outer and inner loops is *necessary but not
sufficient* — the loops must also be **correspondence-aligned**. A square bore
resampled by perimeter starts at a corner (225°) while the circle starts at 0°;
the cap strip then twists around the annulus, self-intersects, and CGAL throws an
assertion violation. Re-parameterising both loops by the same angular sweep from
the same reference fixes it. This becomes invariant `PROF-2` (§3).

### 2.2 The IR is two levels, and you were right to call it "compiled"

**Level 1 — the spine (`utPath`).** An ordered chain of exact segments: `L`
(line), `A` (arc), `P` (sampled, with per-sample tangents). Sparse, exact, and
carrying **no roll and no resolution**.

**Level 2 — the stations (`utStations`).** `[position, tangent, roll-normal,
arclength]` per station. Roll decided, resolution decided, duplicates gone,
closed-loop holonomy absorbed.

**The rule:** frontends produce a spine and may not touch frames. Exactly one
function lowers spine → stations. The backend consumes stations and *never*
infers, guesses, or re-derives orientation. **Every bug the survey found — in this
repo and in `path_extrude.scad` — is a violation of that rule.**

Why an analytic spine rather than a bare transform list:

- Parallel transport along a circular arc has a **closed form** — rotate the roll
  reference about the arc's own axis by the arc's own sweep angle. Exact, one
  line, no accumulated error. That is literally your `rotVec` at
  `half_curvedPipe.scad:19`, generalised. **Your math was right; its data
  structure was wrong.**
- Terminal and tangency-point tangents are exact rather than smoothed. *Measured:*
  1.18° of port skew and 7.5° at an arc tangency point when left to inference.
  Across a 20 mm flange, 1.18° is ~0.4 mm of gap at the rim.
- A 100 mm straight costs 2 stations instead of ~200, and each bend gets facets
  from `$fa`/`$fs` applied to **its own** radius.
- The minimum-bend-radius check becomes a one-line assert. *Measured:* an `od=12`
  tube swept through an `r=4` bend self-intersects and CGAL still reports
  `Simple: yes` with zero warnings.

**A falsification test is built into the plan.** Phase 4 ships the turtle
frontend. If the turtle does not fall out of the spine cleanly — if the spine
grows a case, or the turtle reimplements any frame or tessellation logic — the
spine layer gets **deleted**, not defended.

---

## 3. The architecture

### Path IR

```scad
path = ["utpath", segs, closed, opts]

seg  = ["L", p0, p1]                 // straight
     | ["A", c, u, v, r, ang]        // arc: STEP/IGES axis2_placement_3d verbatim
     | ["P", pts, tans]              // sampled, with per-sample unit tangents

st   = [p, t, n, s]                  // position, tangent, roll-normal, arclength
```

Arc: `point(x) = c + r*(cos(ang*x)*u + sin(ang*x)*v)`, `axis = cross(u,v)`,
`arclen = abs(ang)/360 * 2*PI*r`. Tangents are already unit, and exact.

**Frame policy** — computed by uniTube in one function, `ut_stations(path, opts)`:

| policy | behaviour |
|---|---|
| `frame="transport"` *(default)* | rotation-minimizing; no spiral |
| `frame="fixed", normal=UP` | seam pinned to world up along the whole run |
| `frame=<list>` | full manual control, projected and asserted |
| `twist=<deg>` | distributed by arclength on top of any of the above |
| `closed=true` | holonomy measured, `symmetry` absorbed, remainder distributed |

Seeding falls back from `UP` to `BACK` when `|cross(t0, ref)| < 1e-6` — the
vertical-run NaN that killed one proposal's own flagship example. Every angle is
`atan2(norm(cross(a,b)), a*b)`; **never `acos`**.

For a printable split conduit, `frame="fixed"` is *better* than transport, not
merely equivalent: transport only guarantees the seam doesn't spiral relative to
the tube, but a printed part has a gravity-relative requirement.

### Profile

```scad
prof = ["utprof", outer, inner, meta]   // outer CCW, inner CW or undef

ut_solid_rgn(prof)   // outer + inner  -> ONE capped polyhedron
ut_shell_rgn(prof)   // outer only     -> bore ignored
ut_bore_rgn(prof)    // inner only     -> the lumen AS A POSITIVE SOLID
```

That triple **is** the tube abstraction, and no general sweep library provides it
— a generic sweeper offers only the first.

**The structural rule everything else depends on: no module ever emits a finished
hollow tube during assembly.** If one did, the junction problem would be
unfixable — the trap all four current forks fell into.

Invariants:

- **PROF-1** — `outer` is CCW and `inner` is CW by signed area, asserted; `inner`'s
  bounding box is strictly inside `outer`'s.
- **PROF-2 (CORRESPONDENCE)** — `len(outer) == len(inner)`, **and** the two loops
  are parameterised by the same angular sweep from the same reference, so
  `outer[i]` and `inner[i]` correspond. *Measured:* violating the second half
  while satisfying the first produces a self-intersecting end cap and a CGAL
  assertion violation. Constructors guarantee this; `ut_profile()` asserts it.
- **PROF-3** — `wall >= $ut_min_wall` (default 1.2 mm ≈ 3 perimeters) is a
  **warning**, not an error. A tube that renders perfectly and prints as a hole is
  the failure this library exists to prevent.

`ut_round(od=, id=, wall=)` takes exactly two of three, asserted. A split tube is
a **profile**, not a path feature: `ut_round(od=16, wall=2, split=[-30,30])` is
~6 lines and replaces ~300 lines of `half_curvedPipe.scad`.

*Honest limits:* a split run has an empty bore, so it cannot participate in a
junction — fine for conduit and cable channel, which is what it's for. And a
profile with **more than one** bore (a multi-lumen bundle) needs real
polygon-with-holes triangulation rather than a ring strip; deferred to Phase 5
with that cost stated.

**Profile variation is deferred to v0.3**, and both proposed mechanisms were
measured harmful: baking scale into the station matrix silently emitted a port at
0.6× (so every attached termination is 60% diameter with full pitch), and a
scalar region multiplier thinned the wall from 1.6 mm to 0.96 mm on its own
example. When it returns it is independent `od(u)` / `wall(u)` functions of
normalised arclength — the only form that expresses a real reducer.

### Junctions

```scad
for (g = ut_groups(net))
  difference() {
    union() { shells of runs in g;  joint shells in g }
    union() { bores of runs in g (extended per joint);  joint cores in g }
  }
```

Three fixes on the naive version, each forced by a rendered counterexample:

1. **The bore comes free.** Same spine, same stations, same frame, different
   region. This is exactly where the 2023 attempt died.
2. **Per-joint bore overlap, not a global epsilon.** *Measured:* a T whose branch
   starts on the trunk **wall** (how every real tee is described, and how your own
   `middle_tee_n` is parameterised) got a **0.95 mm plug across the branch lumen**
   while CGAL said `Simple: yes` and a naive regression test passed. The overlap
   depth is a function of the mating run's wall and approach angle — that is
   topology, so joints are **declared**, never inferred.
3. **Lumen groups.** *Measured:* a coaxial jacket (outer od30/id26, inner
   od12/id8) under one global difference **lost the entire inner tube** — 7883.8
   of 29958.5 mm³, 26% of the material, silently, reporting `Simple: yes`. Five
   lines: a group id per run, default 0.

**v1 ships correct, creased junctions with no fillets.** Joint bodies are `"ball"`
(default, explicit — a sphere of max incident od/2 with a matching inner sphere in
the bore pass, exactly `middle_tee_n`'s approach) and `"none"` (allowed, never
synthesised, warned below a threshold incidence angle).

*CGAL cost, honestly:* the 4-into-1 manifold measures 7.3–26 s depending on
resolution, ~O(n^1.6). Single runs are 0.4–60 ms because they involve no boolean.

### Ports — the termination seam

```scad
port = ["utport", name, p, dir, n, profile, s]
module ut_at_port(port) children();   // +Z along dir, +X along n, origin at p
```

uniTube exports the record and the placement module and **stops**. Ports are
derived from graph degree, not declared — a joint-incident end is not a port.
`ut_ports()` is a *function*, so a caller can compute, assert compatibility, and
only then emit. `src/ut_port.scad` has zero dependencies, so a fittings library
couples to a *data format*, not to a geometry engine.

**Signed off now, because both are free now and expensive later:** `dir` points
**outward**, away from the material; and a port carries a full **frame**
(position + outward direction + roll reference), not position + diameter. The roll
normal is the clocking, so a hex flat or bayonet lug lands repeatably.

---

## 4. Frontends

| Phase | Frontend | Syntax |
|---|---|---|
| v0.1 | Polyline + per-vertex radii | `ut_polyline(pts, r=[0,30,30,0])` |
| v0.1 | Direct spine (the IR as public API) | `ut_spine([ut_line(...), ut_arc(...)])` |
| v0.1 | Raw stations (escape hatch) | `ut_from_stations(sts)` |
| v0.2 | **Turtle / LRA** | `ut_turtle([["feed",60],["bend",90,"r",24],["roll",90]])` |
| v0.2 | Parametric `f(t)` | `ut_curve(function(t) [...], t=[0,1], n=180)` |
| v0.3 | Arc-line route (G-code / SVG-A semantics) | `ut_route([["to",p],["arc",p,r=25]])` |
| v0.3 | Bezier / Catmull-Rom | `ut_bezier(ctrl, n=48)` |
| later | Port-to-port routing, 2D lift / revolve | |
| **rejected** | SVG path *string* | steal the semantics, not the syntax |
| **rejected** | Waypoint + tangent list | it is the IR with information removed |

The polyline lowering is ~30 lines and is `curvedPipe.scad:71-105`'s math verbatim
— `inset = r*tan(ang/2)` with the pre/post handshake, the one unambiguously
correct piece of the existing library — plus the three guards it never had:
overlap is an **ERROR** naming the leg and radii, a 180° reversal is an ERROR, and
a collinear waypoint **merges** the legs rather than emitting a NaN arc.

The turtle is v0.2 because **it is the acceptance test for the multi-frontend
thesis**. `roll` emits no geometry and instead rotates the roll reference, which
is the sharpest evidence that roll belongs to the frame policy rather than to the
curve. It is also literally how a CNC tube bender is programmed (Length-Rotation-
Angle), which makes it round-trippable with real manufacturing data later.

`ut_curve` subsumes `proto/sweep_path.scad` entirely without adding
list-comprehension-demos — dormant since 2022 and shipping with **no license file
at all**.

---

## 5. Repo layout

```
uniTube/
├─ LICENSE  NOTICE  README.md  AGENTS.md  justfile  .clang-format  .gitignore
├─ src/                     NO top-level geometry or echo on import
│  ├─ uniTube.scad          the only public entry point
│  ├─ ut_core.scad          eps, record tags, assoc-list get, assert helpers
│  ├─ ut_math.scad          ~25 lines replacing 1035 vendored ones
│  ├─ ut_path.scad          the spine + ut_stations() — the one compiler function
│  ├─ ut_profile.scad       utprof, ut_round, the three region accessors, PROF-1..3
│  ├─ ut_mesh.scad          THE BACKEND. region x stations -> polyhedron. ~120 lines.
│  ├─ ut_net.scad           runs, joints, lumen groups, two-pass, ut_check
│  ├─ ut_port.scad          port records. Zero dependencies, ~30 lines.
│  └─ frontend/             ut_polyline · ut_turtle · ut_curve
├─ examples/                01_elbow … 06_manifold_4into1 (acceptance test)
│                           08_coaxial_jacket (lumen-group regression)
├─ tests/                   assert-only; each ends in `cube(0.001);`
├─ reference/               READ-ONLY QUARANTINE — src/ may never import from here
│  ├─ axford/               curvedPipe, half_curvedPipe, libs/   (CC-BY)
│  ├─ gringer/              path_extrude.scad                    (GPLv3 — see warning)
│  ├─ doommeister/          Round_Ducting_V1.1.scad              (GPLv3 — junction checklist)
│  └─ makrokaba/pipe-joints/                                     (BSD-3 — terminations prior art)
├─ docs/                    ir.md frames.md profile.md junctions.md salvage.md adr/
└─ out/                     gitignored
```

**No `deps/`, no `.gitmodules`, no submodule.** A fresh clone renders
immediately — `just setup` only checks the OpenSCAD version. For an OpenSCAD
library, where most users drop a folder into their library path, zero-install is
a real adoption advantage and not just an aesthetic one.

Everything moves with `git mv` so history follows. `curvedPipe2.scad` is deleted
after salvaging its two good ideas (the `len(points)-3` bound, named-argument
calls).

**Licensing.** Target BSD-2-Clause (MIT is equivalent; pick either). With no
dependency there is no upstream licence to accommodate at all. The one binding
constraint left is that GPL `vector.scad` is `use<>`'d by every core file, and
`use<>` is source-level inclusion at parse time — but the fix is cheap: six
declarations are actually consumed, and OpenSCAD ships `cross()` and `norm()` as
builtins, so the vendored versions are *shadowing* them.

> ⚠ **`reference/gringer/path_extrude.scad` is GPLv3 and is the single most
> tempting file to crib from while writing `ut_mesh.scad`.** The lint rule stops
> `use<>`, but it cannot stop copy-paste. Read it for understanding, then write
> from the geometry. Same for `reference/doommeister/`.

`AGENTS.md` carries the enforcement as one greppable rule: **no file under `src/`
may `use<>` or `include<>` anything under `reference/`**, checked by `just lint`
in two lines.

---

## 6. What "check" and "test" mean for CAD

Re-verified on your 2021.01, because two judges contradicted each other and both
were partly wrong:

| command | exit |
|---|---|
| `openscad -o x.stl` with a failing `assert` | **1** ← assert *is* a test framework |
| `openscad -o x.csg` with a failing `assert` | **0** ← never use `.csg` for tests |
| `openscad -o x.stl` with an unknown named arg | **0** |
| `openscad --hardwarnings -o x.stl`, same file | **1** ← catches the `torusSlice` bug class |
| `openscad -o x.stl` on a file emitting no geometry | **1** ← hence the sentinel cube |
| `openscad -o /dev/null` | **1** ← no suffix; always write into `out/` |

Four tiers, ascending cost:

1. **Data assertions** (milliseconds, no rendering) — the bulk of the suite, and
   only possible because the IR is data. Includes the three historic silent
   corruptions, which must now abort with named messages.
2. **The lumen-patency assertion** (`NET-2`, still pure data) — the extended bore
   must penetrate every mating run's outer surface by at least its wall
   thickness. **The most important test in the library**, because it is the only
   one that catches the failure the project exists to fix.
3. **Mesh properties** (`just verify`) — forced CGAL (a raw `polyhedron()` is never
   validated in preview) plus **our own** `ut_volume()` and facet-count bands at
   0.5% tolerance. *Measured:* `ut_volume` agrees with the analytic value to 6
   significant figures, so the band can be tight.
4. **Golden STL hashes — rejected.** Brittle to facet order, floating point, and
   any `$fa`/`$fs` change. They train people to ignore the suite.

**`Simple: yes` is necessary and nowhere near sufficient.** Every silent failure
found this round passed it: the sealed T lumen, the vanished coaxial inner tube,
the self-intersecting tight bend, and a junction that renders as two pieces held
together by slivers.

`just check` is about eight lines of shell and **would have caught the
`torusSlice` regression at commit time in `5d2975b`**.

---

## 7. Phases

| # | Goal | Effort | Exit criteria |
|---|---|---|---|
| **0** | **Reorganise and gate.** Files only move; nothing is rewritten. | ½ day | `just check` green on a smoke example and non-zero on a deliberate typo. `git grep -l vector.scad src/` empty. |
| **1** | **The core renders.** Spine + frames + **mesh emitter** + polyline. ~370 lines — the bulk of the original code in the project. | 3–5 days | 90° elbow renders as a valid single-polyhedron 2-manifold; **every bend in the legacy demo is visible for the first time since Jan 2025**; exact developed length 93.5619 asserted; port `dir` exactly `[0,1,0]`, not a smoothed estimate; `ut_volume` within 0.5% of analytic. |
| **2** | **Profile completeness.** Split tubes, arbitrary sections, `ut_check`. | 1–2 days | Split conduit valid over two bends in *different* planes with no spiral. `ut_check` aborts on od=12 through r=4 — the case CGAL calls `Simple: yes`. Square bore in round shell valid, with `PROF-2` asserted. |
| **3** | **The network.** Joints, lumen groups, the 4-into-1 manifold — geometry that **has never rendered in any commit of this repo**. | 3–4 days | Manifold `Simple: yes`, volume within 0.5%. T-branch-on-wall has an **open lumen**, verified by `NET-2`, not by `Simple: yes`. Coaxial jacket retains both tubes. |
| **4** | **Prove or delete the two-level IR.** Turtle + parametric frontends. | 1–2 days | **Stated in advance:** if the turtle doesn't fall out of the spine cleanly, delete the spine layer. |
| **5** | Deferred backlog — see §10. | — | Nothing starts until Phase 4 is green. |

Phase 1 grew by ~1 day versus revision 1: the mesh emitter is ours now. Phase 0
shrank — there is no submodule to wire up. Phases 0 and 1 are the real commitment;
everything after is independently deferrable and the library is usable without it.

---

## 8. My read

**Where I think this is right.** Writing the backend is the correct call and the
probe settled it rather than argued it. Once you accepted the two-level IR, the
frame math was ours anyway — the dependency was only buying a mesh stitcher, and
that turned out to be ~40 lines of core mechanism that rendered a valid 2-manifold
on the first attempt. It also means the one hazard nobody had flagged — the
outer/inner correspondence requirement — surfaced now, cheaply, instead of in
Phase 2 as a mystifying CGAL assertion.

**Don't copy from BOSL2.** You suggested it as a fallback and BSD-2 does permit it
with the notice retained, so it is legally clean. But practically it is a trap:
BOSL2's internals are deeply interconnected, so a copied function drags helpers,
which drag more helpers. Read it as prior art if you want; write from the
geometry. The probe suggests you'll be done faster than you'd finish untangling
the imports.

**What you actually give up.** One thing: `join_prism`, for junction fillets in
v0.4+. That is a genuinely hard piece of geometry to write. It matters less than
it sounds, because it cannot join to a *curved* swept surface anyway — its base
must be a plane, sphere, straight cylinder or straight prism — which is binding
for a library whose whole premise is curved paths. v1 ships creased junctions
regardless. Everything else BOSL2 was providing is now written and measured.

**Where I'd temper the plan.** The adversarial pass was aggressive and the
synthesis absorbed a lot of hard-won detail — invariant names, five-line fixes,
stated limits. Treat the *decisions* as settled and the *specification detail* as
a first draft to cut as you implement. If the invariant list starts feeling like
ceremony in Phase 1, cut it; the spine, the region profile, and `PROF-2` are the
load-bearing parts.

**The risk I'd watch.** Phase 3 is where three previous attempts died, and the
7–26 s CGAL renders make iteration slow. Junction *fillets* in particular are the
seductive item — the manifold renders correctly and creased today, and shipping
that beats a fillet that self-intersects when three branches crowd.

---

## 9. Decisions (settled)

**9.1 — No dependencies. The sweep backend is written from the geometry.**
> *"why do we even need a sweep library? can we not recreate ourselves... i rlly
> dont want this lib having deps if i can avoid it, id rather do this math and
> geometry from ground up"*

Accepted, and validated before revising: ~40 lines of core mechanism produced a
valid 2-manifold elbow at 0.4 s forced CGAL, handled a closed loop and a
non-circular bore, and a 6-line divergence-theorem volume function matched the
analytic value exactly. The two-level IR (9.2) already meant uniTube computed its
own frames, so the dependency was only supplying a mesh stitcher. Cost: ~1 extra
day in Phase 1, and no `join_prism` for fillets later. Benefit: zero-install, no
licence entanglement, and full control of the one file everything else rests on.
`src/ut_sweep.scad` becomes `src/ut_mesh.scad`; `deps/` and `.gitmodules` are gone.

**9.2 — Two-level IR (analytic spine → stations).** Confirmed, with the Phase 4
falsification test: if the turtle frontend doesn't fall out of the spine cleanly,
the spine layer gets deleted rather than defended.

**9.3 — Tube-inside-a-tube is in scope for v1.** Confirmed. Lumen groups, ~5
lines, built in Phase 3. Without it the library cannot represent a Bowden-in-
conduit, a double-wall flue, a vacuum jacket, or a tube-in-tube exchanger.

**9.4 — Terminations live in a separate repo, permanently. No protocol for now.**
Confirmed. Signed off today: `dir` points outward; a port carries a full frame,
not position + diameter. Tracked for future pickup in §10.

**9.5 — Fillet radii that don't fit are an ERROR** naming the leg and the radii.
Confirmed. `r="auto"` ships as an opt-in clamping mode for sketching. Note the trap
this avoids: SVG-style "scale to fit" looks safest and isn't — on a 180° doubleback
it scales the radius to exactly 0, which reads as a sharp corner, whose bisector
normal is `unit([0,0,0])` = NaN. The forgiving default manufactures a silent
failure at precisely the input where you most need a message.

---

## 10. Deferred, and tracked

Recorded here with enough context to pick up cold. Each also gets an ADR stub
under `docs/adr/` in Phase 0 so the reasoning doesn't live only in this file.

| item | why deferred | what you'd need to know |
|---|---|---|
| **The terminations library** (9.4) | Out of scope by your call; "this lib stays the tube path" | Consumes only `src/ut_port.scad`'s record. `reference/makrokaba/` (BSD-3, six-way thread matrix) and `reference/doommeister/` (solvent/clamp/o-ring) between them enumerate essentially every termination style a v1 fittings library needs — they are the requirements checklist. The protocol question is deliberately open: a termination that must **merge into the tube wall** (solvent socket, flange fillet) needs to participate in the two-pass, and the bolt-on-at-the-end-plane seam does not support that. Design it with a real requirement in hand. |
| **Profile variation** (`od(u)`, `wall(u)`) | Both proposed mechanisms measured harmful (§3) | Must be independent functions of normalised arclength, never scale in the station matrix. Performance cliff must be visible in the API: a varying profile forfeits the single-sweep and returns to a two-pass. |
| **Biarc fitting** for bezier/spline | **Billing corrected 2026-08-21 — see `BACKLOG.md` §3.** Prototype preserved at `spikes/biarc_fitter.scad` | Two of its three billed benefits are worth 0.19 mm and 0.04 deg on a 758 mm helix and converge as O(h^2). The third (CHECK-1 on a sampled path) was a real hole and is now closed in ~8 lines of discrete curvature. The one error big enough to ruin a part — the end tangent — a fitter does NOT fix. What remains is RESOLUTION INDEPENDENCE (docs/ir.md) and being the prerequisite for ut_bezier. |
| **Junction fillets** | No `join_prism`; genuinely hard geometry | Cannot join to a curved swept surface in any known implementation. Offer only for straight bases and ≤2 incident runs plus a host; refuse loudly otherwise. The seductive item — resist until Phase 4 is green. |
| **Multi-lumen profiles** (>1 bore) | Needs polygon-with-holes triangulation | The ring-strip cap only works for one bore. This is the one place a real triangulator is unavoidable. |
| **`ut_route`, `ut_bezier`, IR combinators** | v0.3+ | Combinators need roll keyframes re-keyed by (segment index, fraction) so they survive composition. |
| **`ut_bend_table(spine)`** | Speculative | The LRA program for a CNC tube bender. Falls out of the arc-native spine almost free if you ever want it. |


---

## 11. Phase outcomes

### Phase 0 — merged (`2559b77`)

Tree reorganised, BSD-2 licensing, `reference/` quarantine, and a `just check`
gate verified in both directions. All 18 moved files byte-identical.

### Phase 1 — merged (`017442c`)

All exit criteria met:

| criterion | result |
|---|---|
| 90° elbow renders as one valid 2-manifold | `Simple: yes`, Volumes 2 |
| **Every bend in the legacy demo is visible** | 12 segments, all 6 arcs present, `Simple: yes` |
| Exact developed length | 93.5619449019, asserted to 1e-9 |
| Port `dir` exact, not smoothed | exactly `[0,1,0]`, asserted to 1e-12 |
| Planar bend produces zero twist | every normal exactly `[0,0,1]`, asserted to 1e-12 |
| Mesh volume within 0.5% of analytic | 0.17% |
| `just check` / `test` / `verify` | green: 11 rendered, 7 test files, 7 guards fire |

**Deviations from this plan, each recorded where it lives:**

1. **Both profile loops are stored CCW**, not outer-CCW / inner-CW. Reversing the
   inner loop destroys the `PROF-2` index correspondence and stops the bore being
   a directly usable positive solid. The emitter orients the inner skin instead.
   (ADR 0006, `docs/profile.md`.)
2. **`src/uniTube.scad` uses `include`, not `use`.** `use` does not transitively
   re-export — verified. Internal modules still use `use`. (AGENTS.md.)
3. **Added `tests/guards/` and `just guards`** — seven files that MUST abort, each
   checked to fail on its intended assertion rather than a syntax error. Not in
   the plan; an untested guard is worthless.
4. **`.clang-format` needed two fixes** found by being bitten: `BreakStringLiterals:
   false` (it split a long assert message into `"a" "b"`, a C idiom and an
   OpenSCAD syntax error) and mandatory `// clang-format off` guards around import
   blocks (it rewrote `use <a/b.scad>` into `use<a / b.scad>`). `just lint` rule 3
   now catches malformed imports.
5. **`ut_at()`** (station at arclength) is deferred to Phase 3, where joints
   actually need it. Nothing in Phase 1 used it.

**Scale:** ~1200 lines of first-party `.scad` across 7 `src/` modules, 3 examples,
7 test files and 7 guards — replacing 1035 vendored lines of which ~7% was ever
reachable.

### Phase 2 — merged (`db0901e`)

All exit criteria met:

| criterion | result |
|---|---|
| Split conduit valid over two bends in **different planes**, no spiral | `Simple: yes`; gap faces exactly world-up on every horizontal station, to 1e-9 |
| `ut_check` aborts on od=12 through r=4 | aborts naming the radius and the reach |
| Square bore in round shell, no special case | `Simple: yes`, Volumes 2 |

**The case that justifies `ut_check`, measured.** An od=12 tube swept through an
r=4 bend passes through itself, and CGAL reports `Simple: yes, Volumes: 2` with a
plausible positive volume and **zero warnings**. No amount of rendering finds
that; only arithmetic on the spine does.

**Deviation — and it went better than predicted.** `PLAN.md` §3 described the
split section as one closed C-shaped loop, and `docs/profile.md` predicted the
consequence: a C-section is not star-shaped about its centroid, so it would need
its own cap strategy — realistically the general triangulator ADR 0001 deferred.
Representing it instead as an **open annulus** — the same two loops, plus two
seam walls — dissolved the problem. One extra term in the emitter, no
triangulator, and `PROF-2` correspondence preserved for free. See ADR 0007.

`half_curvedPipe.scad`'s ~300 lines and its hard nine-segment ceiling are now a
constructor argument and a policy string:

```scad
ut_tube(ut_polyline(pts, r=20),
        ut_round(od=16, wall=2, split=[-30,30]),
        opts=[["frame","fixed"], ["normal",[0,0,1]]]);
```

**Running totals:** 9 test files, **9 guards**, 6 examples, 8 `src/` modules.

### Phase 3 — merged (`ad3022f`)

The 4-into-1 manifold renders. **This geometry has never rendered in any commit
of this repository.**

| exit criterion | result |
|---|---|
| Manifold `Simple: yes`, volume within 0.5% | `Simple: yes`, Volumes 2, ~8 s |
| **T with branch on the trunk WALL has an OPEN lumen — verified by patency, not by `Simple: yes`** | `branch_lumen_open` passes; with the bore extension disabled it reports **61.02 mm³ intruding** while `watertight` and `solid_count` still pass |
| Coaxial jacket retains both tubes | `solid_count(2)` passes; collapsed to one group it reports **`measured 1, limit equals=2`** |
| `ut_ports` on the manifold returns exactly the open ends | 5 of 5, joint-incident ends excluded |

**A defect found by building it.** Extending only the *bore* into a joint is not
enough. A branch whose end sits exactly on the trunk's outer surface then touches
it **tangentially** — the shells share a circle and overlap in nothing. Measured
`Simple: yes, Volumes: 3`: two solids. Both the shell and the bore are now
extended, the shell to the node and the bore half a core-radius past it.

**Both oracles were validated by deliberately reintroducing the bugs.** A check
that cannot fail is worth nothing. See `docs/junctions.md`.

**partspec is now the acceptance oracle** (`checks/`, `just partspec`). It is a
DEV-TIME tool — uniTube itself still links to nothing. `keep_out` asserts lumen
patency directly, with a mandatory anti-vacuity shell so a *deleted* part fails
rather than passes. Filing note: partspec#274 opened against it — a failing
`keep_out` omits the intrusion depth entirely on the mesh tier, which is the
default for OpenSCAD models.

**Deviations:**

1. **Both shell and bore are extended at a joint** — `PLAN.md` §3 described only
   the bore overlap. See above.
2. **`ut_at()` landed here**, as scheduled in the Phase 1 deviation list. Mid-run
   landings need it.
3. **`just verify` split into `just cgal` + `just partspec`.** Examples now expose
   a `part()` module so `cgal` can wrap them in a *provably no-op* intersection.
   The previous idiom — subtracting a tiny cube — perturbs the geometry, and at
   the origin of a manifold that is *inside the material*.

**Running totals:** 10 test files, **13 guards**, 9 examples, 10 `src/` modules,
3 partspec contracts.

### Phase 4 — complete, in review · **THE FALSIFICATION TEST PASSED**

The rule was stated in advance, in §7 and in ADR 0002: if the turtle did not fall
out of the spine cleanly — if the spine had to grow a case, or the turtle
reimplemented any frame or tessellation logic — **the two-level IR was to be
deleted, not defended.**

Recorded as facts rather than recollection:

| test | result |
|---|---|
| Did any core module change? | **No.** All five checksummed before `ut_turtle.scad` was written, verified byte-identical after both frontends were done. |
| Do the frontends reimplement frame or tessellation logic? | **No.** Zero references to `ut_fragments`, `ut_ref_fallback`, `ut_ortho`, `_ut_transport`, `ut_st_mat`, `ut_stations`. |
| Size | `ut_turtle.scad` 65 lines, `ut_curve.scad` 53 |
| Turtle route with a mid-run roll and bends in different planes | renders `Simple: yes`; end point matches hand calculation to 12 digits |
| Helix renders with correct twist | `Simple: yes` |

**The spine stays.** The strongest evidence is `roll`: it emits no geometry, it
changes the plane of every subsequent bend and therefore the shape of the path,
and then it is gone. `SPINE-5` — the IR carries no roll — survived contact with
the one frontend most likely to break it.

**Two bugs found by building it:**

1. **`ut_curve` mapped sample index to parameter after deduping**, so a single
   dropped sample silently shifted every `dfdt` evaluation. Dedupe now returns
   indices and the surviving samples keep their own parameter values.
2. **My own `dfdt` in the first helix test was wrong** — OpenSCAD trig is in
   DEGREES, so `d/dt cos(360*k*t) = -2*PI*k*sin(...)`, and dropping the `2*PI`
   left every tangent ~6° out while looking entirely plausible. Documented as a
   foot-gun in `docs/frontends.md`, because the library cannot detect it.

**A quantified fact worth having:** central differences are second-order accurate
in the interior (measured 0.006° against analytic at n=160) but **first-order at
the ends** (2.24° against a predicted 2.25°). The ends are exactly where port
frames come from, so supply `dfdt` when you know it.

**Running totals:** 12 test files, **17 guards**, 11 examples, 12 `src/` modules,
3 partspec contracts.

---

## 12. Where this leaves the project

The v1 core is complete: **path, profile, and network.** A tube is described by
any of four frontends, compiled to one canonical spine, swept as a single
polyhedron, and assembled into branching hollow networks whose bores stay open.

What ships: four frontends, an arc-native two-level IR with 13 invariants, a
dependency-free mesh backend, split C-sections, arbitrary hollow profiles,
declared joints with lumen groups, ports as pure data, and a four-tier gate whose
every check has been validated by deliberately reintroducing the bug it catches.

What does not, deliberately, with the reasoning recorded in §10 and the ADRs:
terminations, junction fillets, profile variation, biarc fitting, multi-lumen
sections.

The bug that started this — a parameter rename in `5d2975b` that made every bend
render as nothing for 19 months — would now be caught at commit time by `just
check`, in about eight lines of shell.
