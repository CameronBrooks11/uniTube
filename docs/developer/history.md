---
title: History
parent: Developer
nav_order: 2
---

# History

The numbered sections first record what the pre-2026 implementation got right,
then the defects found after the rewrite. Source comments cite them by number,
so the numbers are stable.

The first five were recorded in Phase 0, while the reasoning was fresh, so that
the *understanding* survives even though the code does not. The code itself is in `reference/axford/`
and nothing under `src/` may import it.

## 1. The fillet arithmetic is correct (`reference/axford/curvedPipe.scad:71-105`)

`ang = anglev(dir1, dir2)` is the **deflection** angle, so the corner's interior
angle is `180 - ang`. A circle of radius `r` inscribed tangent to both legs has
tangent length

```
T = r / tan((180 - ang)/2) = r * cot(90 - ang/2) = r * tan(ang/2)
```

so `inset = r * tan(ang/2)` is the distance from the corner vertex back to the
arc's tangent point, and `rStart = start + (l1 - inset) * dir1u` is that point.
`preInset` / `postInset` exist because a straight leg is trimmed at **both** ends
— by the previous vertex's tangent length at its start and this vertex's at its
end — so the drawn run is `l1 - preInset - inset`. The indexing is consistent:
`radii` is indexed by leg, `radii[point]` is the bend at `points[point+1]`.

**This is the one unambiguously correct piece of the old library** and it is
carried into `src/frontend/ut_polyline.scad` verbatim — with the guards it never
had (see §3).

## 2. The seam transport is real parallel transport (`reference/axford/half_curvedPipe.scad:19,141`)

```scad
function rotVec(v, ang, vRef) = v*cos(ang) + cross(vRef,v)*sin(ang) + vRef*dot(vRef,v)*(1-cos(ang));
```

That is Rodrigues' rotation formula, correct, in one line. `openTubeVec(v1, v2,
rtVec)` carries the previous station's seam vector forward by rotating it about
**that bend's own binormal** by **that bend's own turn angle** — discrete parallel
transport along a circular arc, i.e. a rotation-minimizing frame.

**The geometric problem it solves:** a lengthwise-split tube needs a roll
reference marking the cut plane. Derive it independently at each station from a
fixed world axis and it rotates relative to the tube as the axis turns, so the
split plane spirals. Transport fixes that.

**The insight that generalises:** transport along an arc has a *closed form* —
rotate about the arc's own axis by the arc's own sweep angle. Exact, no
integration, no accumulated error. This is the single strongest argument for
keeping arcs in the IR rather than sampling to points, and it is why `utPath`
has an `["A", c, u, v, r, ang]` segment kind.

**What was wrong was the plumbing, not the math.** OpenSCAD cannot thread state
through a `for` loop, so the scan was hand-unrolled into a nine-deep nested `if`
(lines 167-264, 98 of the file's 288), capping any path at **9 segments** with no
warning. The fix is to compute the frame list in a pure recursive *function* up
front and then emit in a single flat loop — which is precisely the
"compile the path to a canonical IR" architecture, arrived at from the other
direction.

**Note also** that `path_extrude.scad`'s `cumPreRots` is a second, independent
hand-rolled solution to the same missing datum, in the same repo. Two independent
implementations of "carry a roll reference along the path" is the strongest
evidence for what the IR must contain: **stations, not points.**

## 3. The three silent failures the guards must catch

All three were confirmed by rendering, not by reading. Each must now `assert`
with a message naming the offending element.

| input | what happens today | why it is invisible |
|---|---|---|
| `preInset + inset > l1` (fillets overlap a short leg) | The straight leg silently vanishes and the two bend tori interpenetrate. **Verified: the same path at `radii=[20,20]` renders genus 1; at `radii=[80,80]` on a 100 mm leg it renders genus 2 — an extra through-hole.** | OpenSCAD emits *nothing* for `linear_extrude(height <= 0)`, with no warning. |
| 180° reversal | `tan(90)` is literally `inf`, so `rStart` becomes `[nan,nan,nan]` and the segment disappears. | No guard anywhere. |
| near-collinear waypoints | `anglev` = `acos(dot/(mod*mod))` returns NaN once float error pushes the argument past 1.0. **Verified: `acos(1.0000001)` is `nan`.** | NaN propagates silently through `inset` and every frame. |

Fix for the third is global: **never use `acos` for an angle between vectors.**
Use `atan2(norm(cross(a,b)), a*b)`, which never NaNs.

## 4. The junction fix already works, in the wrong file

`reference/doommeister/Round_Ducting_V1.1.scad:168-228` (`middle_tee_n`,
`manifold_n`) implements

```scad
difference() {
  union()  { sphere + N outer branches }
  union()  { inner sphere + N bores }
}
```

— the two-pass outer-union-minus-lumen-union fix — working, on real shipping
geometry. It is hardcoded to straight radial branches, but it is a reference
implementation and it predates the 2023 attempt that failed to build the same
thing.

**Why the 2023 attempt failed:** `pipeCurveCutout` modelled the lumen as a
*separate subtraction*, so it had to re-derive the bend geometry from scratch,
and it called `torusSlice_only_inner_pipes()` — a module `git log -S` confirms
was **never defined in any commit**. Making the lumen an inner boundary of the
swept *profile* is what makes the bore pass free: same spine, same stations,
same frame, different region.

## 5. What is being discarded, and why it costs nothing

- `libs/maths.scad` — 677 lines, ~130 functions, **3 are reachable** (`quat`,
  `quat_to_mat4`, `vec4_mult_mat4`), all only to implement `pipeOrientate`. The
  entire 280-line spline section has zero call sites.
- `libs/vector.scad` — 358 lines, **6 reachable** (`mod`, `cross`, `dot`,
  `unitv`, `anglev`, `orientate`). `cross` and `norm` are OpenSCAD builtins; the
  vendored versions were *shadowing* them. This is also the only GPL file in the
  old core.
- `pipeOrientate`'s 25 lines of quaternion machinery — replaced by building the
  frame matrix directly from `(n, cross(t,n), t)`.
- `torusSlice` / `torusSliceF` / `tube` / `halfTorusSlice` / `halfTube` — all
  obsolete once a run is one swept polyhedron rather than a union of primitives.

**1035 vendored lines are replaced by roughly 25** in `src/ut_math.scad`.

---

The sections above were written before the rewrite. The ones below record
defects found after it, moved here from the pages that now describe only the
current behaviour. Each has a guard or a test that was watched to fail.

## 6. A fixed frame's fallback was a discontinuity

`ut_ref_fallback()` swaps the reference vector when a run starts parallel to it.
That is correct for what it was written for: choosing a starting reference
**once**, at station 0, for a transport frame. Used once there is no
discontinuity to create.

`frame="fixed"` derived every station's normal independently, so the fallback
became a **hard switch in the middle of a run**. Measured on the old
`examples/05`: as the conduit turned to vertical the seam jumped **174° in a
single 6° step**. The mesh stayed manifold, CGAL reported `Simple: yes`, `just
check`, `just cgal` and all 19 partspec assertions passed, and the C-section was
simply wrong from that station on.

The projection is smooth to 1e-13 at every approach angle **down to 1° from the
axis** and only breaks *at* it — a cliff, not gradual ill-conditioning. So
`ut_stations()` now refuses the genuinely undefined ask rather than substituting
a different reference for it: a vertical pipe has no upward-facing side.

**Three tests asserted the wrong property.**

`tests/t_frame.scad` and `tests/t_split.scad` both ended on a vertical leg *on
purpose*, and both asserted that the result was **not NaN**. It is not NaN — the
fallback guarantees that. Finiteness was never the requirement; **continuity**
is, and nothing checked it. `STATION-6` was documented from Phase 1 and enforced
by nothing.

The third was worse. A caller-supplied `frame=<list>` parallel to the tangent
*does* produce `[nan,nan,nan]`, and the assert written to catch it —
`max([for (s = sts) abs(t * n)]) < 1e-9` — **passed**, reporting `2.22e-16`,
because OpenSCAD's `max()` silently drops `nan` entries. Never test a frame for
validity with `max()` alone; count the bad stations instead.

All three are now refused at the cause, and each refusal has a guard in
`tests/guards/` that is watched to fire.

## 7. Sampled paths: three first-order mistakes

**End tangents.** The ends used to be first-order — a two-point chord, error about half a
sample's rotation, measured 2.24° at n=160. Since the ends are exactly where port
frames come from (`STATION-3`) and 2.2° across a 20 mm flange is ~0.8 mm of gap,
that was the only error in a sampled path large enough to make a physical part
wrong. `_ut_central` now uses a **three-point one-sided difference**, which is
second order like the interior:

| n | two-point (old) | three-point (now) |
|---|---|---|
| 40 | 8.949° | 0.460° |
| 160 | 2.237° | **0.0141°** |
| 320 | 1.119° | 0.0032° |

**`ut_at` on a sampled segment.** It used to return the tangent at the far end of the chord for every `s`, which
made `ut_at(path, 0)` report the tangent one sample downstream: 8.94° out at
the start of a 2-turn helix at n=40, exactly one sample's rotation. The function had
no test at all, which is how it survived. It has one now.

**The turtle's bend split.** `ut_turtle` splits by replacing the oversized bend in its
own command list with two halves and re-entering at the same index. Both slices
around it must be guarded against being empty, because **OpenSCAD silently
reverses a descending range**: `[0:-1]` is `[-1, 0]`, not `[]`, and
`--hardwarnings` says nothing. Unguarded, a bend over 180° as the *first* or
*last* command spliced `undef` into the program and aborted with
`unknown command "undef"` — naming the wrong cause entirely. The only case
covered had commands on both sides of the bend, so neither boundary was tested.

## 8. Networks: two measurements taken in the wrong place

**`NET-5` was an endpoint test.** `NET-5` compares the two centrelines by **sampled path distance**, not by
endpoints. It was an endpoint test until 2026-08-21, and that miss was total:
sliding a liner 70 mm along a jacket so the two shared no endpoint lost **3733.3
mm³ — exactly 100% of the liner** — with `ut_check_net` returning `true` and CGAL
reporting `Simple: yes`.

**Radii where facets were needed.** `NET-4` compared the ball's two radii, which
treats both spheres as smooth; on two `od=20 id=17` runs at `$fn=5` the radii
said a 3.1 mm wall and the facets said −0.33 mm, a hole through the junction.
The same mistake sized the core sphere itself: `ut_bore_inradius` used to return
`min(norm(q))` over the bore's **vertices**, which `ut_ring()` places exactly on
the nominal circle — so it returned `id/2` at every resolution while the real
inscribed radius is `id/2·cos(180/n)`. It uses `ut_inradius()` now, which
measures to the **edges**.
