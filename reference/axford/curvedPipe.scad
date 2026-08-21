// Including external libraries for vector operations, math functions, and additional shapes
use <libs/maths.scad>      // Author: William A Adams, Public Domain
use <libs/someShapes.scad> // Author: Damian Axford, with elements by nophead, Public Domain
use <libs/vector.scad>     // Author: Juan Gonzalez-Gomez, GPL

// Small value to avoid precision issues
fudge = 0.01;

// Function to subtract two vectors, resulting in u-v
function subv(u, v) = [ u[0] - v[0], u[1] - v[1], u[2] - v[2] ];

// Function to convert a 4D vector to a 3D vector
function vec3_from_vec4(v) = [ v[0], v[1], v[2] ];

// Function to convert a 3D vector to a 4D vector
function vec4_from_vec3(v) = [ v[0], v[1], v[2], 1 ];

/*
 * Module to orient a pipe between two vectors v1 and v2
 * This involves calculating the rotation necessary to align v1
 * and then rotating v2 accordingly.
 */
module pipeOrientate(v1, v2)
{
    // Calculate rotation axis for v1, special handling if v1 is aligned with the z-axis
    v1axis = v1[0] == 0 && v1[1] == 0 ? [ 0, 1, 0 ] : cross([ 0, 0, 1 ], v1);

    v1ang = anglev([ 0, 0, 1 ], v1);

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
    rotate(a = v1ang, v = v1axis) rotate(a = theta != 0 ? theta : 0, v = [ 0, 0, 1 ])
        // rotate(a = 90, v = [ 0, 1, 0 ]);
        children(0);
}

/*
 * Module to create a curved pipe segment between points with specified radii.
 * Handles the transition between straight and curved segments and ensures smooth transitions.
 */
module pipeCurve(points, point, radii, od, id, isLastSegment = false)
{
    // Define points for the current segment
    pre = points[point - 1]; // Previous point
    start = points[point];   // Starting point of the current segment
    mid = points[point + 1]; // Middle point of the curve
    end = points[point + 2]; // Ending point of the curve

    // Define the point after the end for calculating post-direction
    post = points[point + 3];

    // Radii for the previous, current, and next segments
    preR = radii[point - 1];
    r = radii[point];
    postR = radii[point + 1];

    // Calculate direction vectors and their lengths
    dir1 = subv(mid, start);  // Direction from start to mid
    dir2 = subv(end, mid);    // Direction from mid to end
    l1 = mod(dir1);           // Length of dir1
    l2 = mod(dir2);           // Length of dir2
    ang = anglev(dir1, dir2); // Angle between dir1 and dir2

    // Calculate pre-direction and inset for smooth transition
    preDir = pre ? subv(start, pre) : dir1;
    preAng = pre ? anglev(preDir, dir1) : 0;
    preInset = pre ? preR * tan(preAng / 2) : 0;

    // Calculate post-direction and inset for smooth transition
    postDir = post ? subv(post, end) : dir2;
    postAng = post ? anglev(dir2, postDir) : 0;
    postInset = post ? postR * tan(postAng / 2) : 0;

    // Calculate the unit vector and inset for the current segment
    dir1u = unitv(dir1);
    inset = r * tan(ang / 2);
    rStart = start + (l1 - inset) * dir1u;

    // Create the starting straight segment
    translate(start) orientate(dir1) translate([ 0, 0, preInset ])
        tube(h = l1 - preInset - inset, or = od / 2, ir = id / 2, center = false);

    // Create the ending straight segment
    translate(mid) orientate(dir2) translate([ 0, 0, inset ])
        tube(h = l2 - postInset - inset, or = od / 2, ir = id / 2, center = false);

    // Create the curved section
    // Note: torus slice always starts at x-axis and goes counterclockwise around z-axis
    translate(rStart) pipeOrientate(dir1, dir2) rotate([ 0, 0, 180 ]) // Rotate to align along x-axis
        rotate([ 90, 0, 0 ])                                          // Flip up
        translate([ -r, 0, 0 ]) torusSlice(r1 = r, r2 = od / 2, r3 = id / 2, start_angle = 0, end_angle = ang);
}

/*
 * Module to create a curved pipe consisting of multiple segments
 * Calls the pipeCurve module for each segment to ensure smooth transitions.
 */
module curvedPipe(points, segments, radii, od, id)
{
    union()
    {
        for (point = [0:segments - 2])
            pipeCurve(points, point, radii, od, id);
    }
}

// Test pieces to visualize the curved pipe module
if (true)
{
    curvedPipe(
        [
            [ 0, 0, 0 ], [ 100, 0, 0 ], [ 100, 100, 0 ], [ 50, 100, 100 ], [ 50, 100, 150 ], [ 0, 100, 50 ],
            [ 0, 0, 0 ], [ 50, 0, 50 ]
        ],
        7, [ 70, 30, 30, 6, 50, 30 ], 10, 8);

    rotate([ 0, 0, 180 ]) curvedPipe(
        [
            [ 0, 0, 0 ], [ 100, 0, 0 ], [ 100, 100, 0 ], [ 100, 100, 100 ], [ 0, 100, 100 ], [ 0, 100, 0 ], [ 0, 0, 0 ],
            [ 50, 0, 50 ]
        ],
        7, [ 70, 30, 30, 6, 50, 30 ], 10, 8);
}