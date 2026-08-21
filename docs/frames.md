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
