# Junctions

The problem in one line: `union()` two hollow tubes and branch B's **wall** seals
branch A's **lumen** at the junction.

This is the thing no library does, the thing this project was started for, and
the thing three previous attempts in this repository died on.

## The two-pass, scoped to a lumen group

```scad
for (g = ut_groups(net))
  difference() {
    union() { shells of runs in g;  joint shells in g }
    union() { bores  of runs in g;  joint cores  in g }
  }
```

The subtraction happens **once per group, after all unions in that group**, so B's
shell cannot seal A's lumen: B's shell is unioned before A's bore is cut, and A's
bore always wins.

This is the inherited TODO from the 2023 prototype (removed with `reference/jantecnl/`; see `docs/salvage.md` §4 and the git history),
promoted from a comment to an architectural invariant. It already ships in this
repository, in the wrong file, as `reference/doommeister/Round_Ducting_V1.1.scad:168`
(`middle_tee_n`) — working, on real geometry, hardcoded to straight radial branches.

CSG appears in **exactly one place** in this library, and that is it. Everything
along a run is a single swept polyhedron.

## Three things make it actually work

### 1. The bore comes free

Same spine, same stations, same frame, different region
(`ut_bore_rgn`). No second implementation of the path arithmetic.

This is precisely where the 2023 attempt died: it modelled the lumen as a
*separate subtraction*, so `pipeCurveCutout` had to re-derive the bend geometry
and called `torusSlice_only_inner_pipes()` — a module `git log -S` confirms was
**never defined in any commit**. The second pass got about 60% written and
stopped at the hard part, and the hard part only existed because the lumen was
modelled in the wrong place.

### 2. Per-joint overlap, and BOTH shell and bore are extended

Joints are **declared**, never inferred from geometric coincidence. Coincidence
cannot find a branch that terminates *inside* a trunk, and a synthesised joint
has nowhere to hang an overlap depth.

Each joint-incident run end is extended along its **exact end tangent**:

| part | extension |
|---|---|
| shell | reaches the joint node |
| bore | half a core-radius further, so it is safely inside the core sphere |

Extending only the bore is not enough. A branch whose end sits exactly on the
trunk's outer surface then touches it **tangentially** — the shells share a
circle and overlap in nothing. Measured: `Simple: yes, Volumes: 3`, two solids.

The extension is collinear with the end tangent, so it adds no curvature and
cannot disturb the frame.

### 3. Lumen groups

Every run carries a group id, default 0. With one global difference over the
whole assembly, a coaxial jacket's outer bore swallows the inner run entirely —
measured, 7883.8 of 29958.5 mm³, **26% of the material**, silently deleted, with
CGAL still reporting `Simple: yes`.

`NET-5` refuses an assembly where two runs that can nest share a group, and names
the fix.

`NET-5` compares the two centrelines by **sampled path distance**, not by
endpoints. It was an endpoint test until 2026-08-21, and that miss was total:
sliding a liner 70 mm along a jacket so the two shared no endpoint lost **3733.3
mm³ — exactly 100% of the liner** — with `ut_check_net` returning `true` and CGAL
reporting `Simple: yes`.

**Runs that share a joint are exempt, and that exemption is not optional.** Two
runs meeting at a joint necessarily approach within a bore radius — that is what
a joint *is*. Without the exemption the check rejects a perfectly ordinary tee
whose trunk bore is large enough to contain its branch; verified by removing it
and watching exactly that case fail. Sharing a joint is the declaration that the
approach is deliberate.

Two limits worth knowing:

- It is a **sampled** test (k=24 per path). A crossing that happens entirely
  between two samples is not seen. The case it exists for is a long overlap
  rather than a point contact, so this is a reasonable trade rather than a
  silent hole.
- It only fires when the inner run **fits** inside the outer's bore. That is what
  distinguishes *nesting* — which the subtraction pass deletes — from
  *intersecting*, which is the point of a junction.

## Joint bodies

| body | what it is |
|---|---|
| `"ball"` *(default, explicit)* | a sphere at the node of the largest incident outer reach, with a matching core sphere of the smallest incident bore inradius. Literally `middle_tee_n`'s approach: ugly, correct, shippable. |
| `"none"` | the runs simply overlap. Allowed, never synthesised. |

Both radii are **measured from the incident profiles**, never assumed from `od`,
so an arbitrary hollow section works without a special case.

## What v1 explicitly does not do

Stated loudly rather than discovered:

- **No fillets. Junctions are correct and CREASED.** A sharp interior corner is a
  stress riser and prints with a visible crease, and that is what ships. The
  manifold renders correctly today; a fillet that self-intersects when three
  branches crowd is worse than no fillet.
- **No branch onto a bend.** Every known filleted-join implementation requires the
  base to be a plane, sphere, straight cylinder or straight prism. For a library
  whose premise is curved paths this is the binding constraint.
- **Thin walls at a shallow crotch are not fixed.** Generous ball sizing and a
  `NET-4` warning are all v1 offers.
- **Mid-run landings** (`["s", x]`) work with `"ball"` and `"none"` only.

## Cost

The 4-into-1 manifold renders in about 8 s. A single run is 0.4–60 ms, because it
involves no boolean at all — the cost is entirely CGAL's, at the junctions.

Iterating? Comment out the bore pass, or wrap the network in `render()` so it
caches.

## Why `Simple: yes` is not the acceptance criterion

Every silent failure this design was reviewed against reported `Simple: yes`:

| failure | what CGAL said |
|---|---|
| branch lumen sealed by a 0.95 mm plug | `Simple: yes, Volumes: 2` |
| coaxial inner tube deleted, 26% of material gone | `Simple: yes` |
| od=12 swept through an r=4 bend, self-intersecting | `Simple: yes, Volumes: 2` |
| junction rendering as two pieces joined by slivers | `Simple: yes` |

So the gate is four tiers (`PLAN.md` §6), and the two that matter here are:

- **`ut_check_net`** — `NET-1..5`, analytic, on the IR as pure data, no rendering.
- **`checks/`** — declared engineering intent, verified with
  [partspec](https://github.com/CameronBrooks11/partspec). `keep_out` regions down
  each lumen assert patency directly, with a mandatory anti-vacuity shell so a
  *deleted* part fails rather than passes.

Both were validated by deliberately reintroducing the bugs. Disabling the bore
extension produced `61.02 mm3 of material intrudes into the keep-out region`
while `watertight` and `solid_count` both still passed. Collapsing the lumen
groups produced `solid_count — measured 1, limit equals=2`. A check that cannot
fail is worth nothing, and these can.
