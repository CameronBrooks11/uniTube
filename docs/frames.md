# Frames

> **Historical note.** This page was `curvedPipe/README.md` and is kept for its
> derivation, which is correct and worth having. **The module it documents is
> superseded.** `pipeOrientate` built the frame by a quaternion round-trip;
> uniTube builds it directly from `(n, cross(t,n), t)` — see `docs/salvage.md` §5
> and ADR 0002. The transport/fixed frame-policy spec lands here in Phase 2.

## Origin

Inspired by the Curved Pipe Library for OpenSCAD by axford on Thingiverse
(thing:71464) — see `reference/axford/` and the root `NOTICE`.

## Pipe Orientation Module

The `pipeOrientate` module calculates the necessary rotations to align a pipe segment between two vectors, `v1` and `v2`. This involves determining the rotation axis and angle for `v1`, converting `v2` to a 4D vector, and then applying the required transformations.

### Mathematical Representation

Given two vectors $\mathbf{v1}$ and $\mathbf{v2}$, the module performs the following steps:

1. **Calculate the Rotation Axis for $\mathbf{v1}$**:
   - If $\mathbf{v1}$ is aligned with the z-axis, set the rotation axis $\mathbf{v1axis}$ to $[0, 1, 0]$ to avoid an indeterminate axis result ($[0, 0, 0]$).
   - Otherwise, calculate the cross product of $[0, 0, 1]$ and $\mathbf{v1}$:
     $$
     \mathbf{v1axis} = 
     \begin{cases} 
     [0, 1, 0] & \text{if } \mathbf{v1}[0] = 0 \text{ and } \mathbf{v1}[1] = 0 \\
     \mathbf{v1} \times [0, 0, 1] & \text{otherwise}
     \end{cases}
     $$

2. **Calculate the Rotation Angle for $\mathbf{v1}$**:
   - The angle $\theta$ between the z-axis and $\mathbf{v1}$:
     $$
     \theta = \text{acos}\left(\frac{\mathbf{v1} \cdot [0, 0, 1]}{|\mathbf{v1}| \cdot |[0, 0, 1]|}\right)
     $$

3. **Calculate the Length of the Rotation Axis**:
   - The magnitude of the rotation axis vector $\mathbf{v1axis}$:
     $$
     |\mathbf{v1axis}| = \sqrt{\mathbf{v1axis}[0]^2 + \mathbf{v1axis}[1]^2 + \mathbf{v1axis}[2]^2}
     $$

4. **Convert $\mathbf{v2}$ to a 4D Vector**:
   - Add a fourth dimension with a value of 1 to $\mathbf{v2}$:
     $$
     \mathbf{vec2} = [\mathbf{v2}[0], \mathbf{v2}[1], \mathbf{v2}[2], 1]
     $$

5. **Create a Quaternion for the Rotation**:
   - Define the quaternion $\mathbf{qRev}$ based on the rotation axis and angle:
     $$
     \mathbf{qRev} = \left[\text{normalize}(\mathbf{v1axis}) \cdot \sin\left(\frac{\theta}{2}\right), \cos\left(\frac{\theta}{2}\right)\right]
     $$

6. **Convert Quaternion to a 4x4 Matrix**:
   - Generate the transformation matrix $\mathbf{qRevMat}$ from the quaternion $\mathbf{qRev}$.

7. **Rotate $\mathbf{v2}$ by $\mathbf{qRev}$ if the Axis Length is Greater Than 0**:
   - Apply the matrix multiplication if $|\mathbf{v1axis}| > 0$:
     $$
     \mathbf{vec2Rev} = 
     \begin{cases} 
     \mathbf{vec2} \cdot \mathbf{qRevMat} & \text{if } |\mathbf{v1axis}| > 0 \\
     \mathbf{vec2} & \text{otherwise}
     \end{cases}
     $$

8. **Calculate the Rotation Angle About the Z-Axis Based on the Rotated $\mathbf{v2}$**:
   - Determine the angle $\theta$ using the arctangent function:
     $$
     \theta = \text{atan2}(\mathbf{vec2Rev}[1], \mathbf{vec2Rev}[0])
     $$

9. **Apply the Rotations**:
   - Rotate around $\mathbf{v1axis}$ by $\theta$ and then around the z-axis by $\theta$:
     $$
     \text{rotate}(a = \theta, v = \mathbf{v1axis}) \text{rotate}(a = \theta \neq 0 ? \theta : 0, v = [0, 0, 1]) \text{children}(0)
     $$

### Module Code

```scad
module pipeOrientate(v1, v2) {
    // Calculate rotation axis for v1, special handling if v1 is aligned with the z-axis
    v1axis = v1[0] == 0 && v1[1] == 0 
        ? [0, 1, 0] 
        : cross([0, 0, 1], v1);
        
    // Calculate the angle between the z-axis and vector v1
    v1ang = anglev([0, 0, 1], v1);

    // Calculate the length (magnitude) of the rotation axis vector
    v1axisLen = mod(v1axis);

    // Convert v2 to a 4D vector
    vec2 = vec4_from_vec3(v2);

    // Create a quaternion to reverse the final rotation
    qRev = quat(v1axis, v1ang);
    qRevMat = quat_to_mat4(qRev);

    // Rotate v2 by qRev if the axis length is greater than 0
    vec2Rev = v1axisLen > 0 ? vec4_mult_mat4(vec2, qRevMat) : vec2;

    // Calculate the rotation angle about the z-axis based on the rotated v2
    theta = atan2(vec2Rev[1], vec2Rev[0]);

    // Apply the rotations
    rotate(a = v1ang, v = v1axis) rotate(a = theta != 0 ? theta : 0, v = [0, 0, 1]) children(0);
}


---

# Frame policy

*(Added in Phase 2. The derivation above is the historical record of how
`pipeOrientate` did it; this is how uniTube does it.)*

Frames are computed by uniTube, in exactly one function — `ut_stations(path,
opts)`. Not by the frontend, which has no business deciding roll, and not by the
backend, which has no business guessing it.

| policy | behaviour |
|---|---|
| `frame="transport"` *(default)* | rotation-minimizing; the seam does not spiral relative to the tube |
| `frame="fixed"`, `normal=UP` | the reference is projected orthogonal to the tangent at EVERY station, so the seam points in a fixed WORLD direction |
| `frame=<list>` | one normal per station, projected and asserted non-degenerate |
| `twist=<deg>` | distributed by arclength on top of any of the above |
| `closed=true` | holonomy measured, `symmetry` absorbed, remainder distributed |

## Transport

Per segment kind:

- **L** — the normal is unchanged. Exact.
- **A** — rotate the normal about `cross(u,v)`, the arc's OWN axis, by the arc's
  OWN sweep angle. **Closed form, exact, one line of Rodrigues.** This is the
  payoff of an arc-native IR, and it is
  `reference/axford/half_curvedPipe.scad:19` generalised (`docs/salvage.md` §2).
- **P** — discrete rotation-minimizing frame between consecutive samples.

Between segments the transport is the identity, because `SPINE-3` guarantees the
tangents already match.

A consequence worth knowing: on a **planar** bend the roll reference is parallel
to the bend axis, and Rodrigues leaves a vector parallel to its axis invariant.
So a planar bend produces **exactly zero twist** — asserted to 1e-12 in
`tests/t_path.scad`, not approximated.

## Fixed, and why it is the right default for a printed part

For a lengthwise-split conduit, `frame="fixed"` is **stronger** than transport,
not merely equivalent. Transport guarantees only that the seam does not spiral
*relative to the tube*. A printed part has a *gravity-relative* requirement: the
gap must face up along the whole run so it prints as an open channel without
bridging. That is `frame="fixed", normal=UP`, and it is one argument.

## The degeneracy that kills naive implementations

Seeding projects a world reference orthogonal to the tangent. When the run starts
**parallel** to that reference — a vertical run against `UP` — the projection is
zero and normalising it gives `[nan,nan,nan]` for every station on that leg.

`ut_ref_fallback()` falls back from `UP` to `BACK`, and from `BACK` to `+X`, when
`|cross(t, ref)| < 1e-6`. Three lines.

### The fallback is a SEED, and using it per-station made it a discontinuity

That fallback is correct for what it was written for: choosing a starting
reference **once**, at station 0, for a transport frame. Used once there is no
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

### Three tests asserted the wrong property

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

Every angle in the frame path is computed as `atan2(norm(cross(a,b)), a*b)`.
**Never `acos`** — `acos(1.0000001)` is `nan` on 2021.01, and near-collinear
waypoints are the most common input there is.
