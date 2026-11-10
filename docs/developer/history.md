# Salvage — what the old implementation got right

Recorded in Phase 0, while the reasoning is fresh, so that the *understanding*
survives even though the code does not. The code itself is in `reference/axford/`
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
