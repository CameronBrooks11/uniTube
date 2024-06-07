// Including external libraries for vector operations, math functions, and additional shapes
use <maths.scad>      // Author: William A Adams, Public Domain
use <moreShapes.scad> // Author: Damian Axford, with elements by nophead, Public Domain
use <vector.scad>     // Author: Juan Gonzalez-Gomez, GPL

$fn = 64;

// Unit vectors
unitZ = [0, 0, 1];
unitY = [0, 1, 0];
unitX = [1, 0, 0];

// Small value to avoid precision issues
fudge = 0.01;

// Function to subtract two vectors, resulting in u-v
function subv(u, v) = [u[0] - v[0], u[1] - v[1], u[2] - v[2]];

// Function to convert a 4D vector to a 3D vector
function vec3_from_vec4(v) = [v[0], v[1], v[2]];

// Function to convert a 3D vector to a 4D vector
function vec4_from_vec3(v) = [v[0], v[1], v[2], 1];

// Rotate a vector: v - vector to be rotated, ang - angle of rotation, vRef - unit vector
function rotVec(v, ang, vRef) = (v * cos(ang) + cross(vRef, v) * sin(ang) + vRef * dot(vRef, v) * (1 - cos(ang)));

// Function to handle each segment of the half pipe
function handleHalfPipeSegment(points, point, radii, od, id, openVec) = let (
    v1 = subv(points[point + 1], points[point]),
    v2 = subv(points[point + 2], points[point + 1]),
    tubeVec1 = openTubeVec(v1, v2, unitZ),
    openVecAng = anglev(unitZ, tubeVec1) - 90,
    newOpenVec = rotVec(unitZ, openVecAng, unitv(cross(unitZ, tubeVec1))),
    torusVertVec = openTubeVec(v1, v2, unitY),
    _ = halfPipeCurve(points, point, radii, od, id, newOpenVec, torusVertVec),
    resultVec = rotVec(newOpenVec, anglev(v1, v2), unitv(torusVertVec))
) newOpenVec;

// Function to create a curved half pipe
module curvedHalfPipe(points, segments, radii, od, id) {
    openVec = [0, 0, 1];
    for (point = [0 : segments - 2]) {
        openVec = handleHalfPipeSegment(points, point, radii, od, id, openVec);
    }
}

// Module to handle each segment of the half pipe curve
module halfPipeCurve(points, point, radii, od, id, openVec, torusVertVec) {
    pre = points[point - 1];
    start = points[point];
    mid = points[point + 1];
    end = points[point + 2];
    post = points[point + 3];
    preR = radii[point - 1];
    r = radii[point];
    postR = radii[point + 1];

    dir1 = subv(mid, start);
    dir2 = subv(end, mid);
    l1 = mod(dir1);
    l2 = mod(dir2);
    ang = anglev(dir1, dir2);

    preDir = pre ? subv(start, pre) : dir1;
    preAng = pre ? anglev(preDir, dir1) : 0;
    preInset = pre ? preR * tan(preAng / 2) : 0;

    postDir = post ? subv(post, end) : dir2;
    postAng = post ? anglev(dir2, postDir) : 0;
    postInset = post ? postR * tan(postAng / 2) : 0;

    dir1u = unitv(dir1);
    inset = r * tan(ang / 2);
    rStart = start + (l1 - inset) * dir1u;

    // Start
    raxis = dir1[0] == 0 && dir1[1] == 0 ? [0, 1, 0] : cross([0, 0, 1], dir1);
    rang = anglev(dir1, [0, 0, 1]);
    strt1Vec = rotVec([0, 1, 0], rang, unitv(raxis));
    tubeVec = rotVec(unitZ, rang, unitv(raxis));
    startAng = anglev3(strt1Vec, openVec, tubeVec);

    translate(start) orientate(dir1) translate([0, 0, preInset - 0.5])
        halfTube(h = l1 - preInset - inset, or = od / 2, ir = id / 2, ang = startAng, center = false);

    // Curved section
    torusAng = anglev3(openVec, torusVertVec, tubeVec);
    translate(rStart) pipeOrientate(dir1, dir2) rotate([0, 0, 180]) // rotate to lie along x
        rotate([90, 0, 0])                                          // flip up
        translate([-r, 0, 0])
            halfTorusSlice(r1 = r, r2 = od / 2, r3 = id / 2, start_angle = 0, end_angle = ang, openAng = torusAng);

    // End
    raxisEnd = dir2[0] == 0 && dir2[1] == 0 ? [0, 1, 0] : cross([0, 0, 1], dir2);
    rangEnd = anglev([0, 0, 1], dir2);
    tVec = rotVec([0, 1, 0], rangEnd, unitv(raxisEnd));
    tubeVecEnd = rotVec(unitZ, rangEnd, unitv(raxisEnd));
    openVec2 = rotVec(openVec, ang, unitv(torusVertVec));
    endAng = anglev3(tVec, openVec2, tubeVecEnd);

    translate(mid) orientate(dir2) translate([0, 0, inset - 0.5])
        halfTube(h = l2 - postInset - inset, or = od / 2, ir = id / 2, ang = endAng, center = false);
}

// Function to calculate the angle between two vectors relative to a normal vector
function anglev3(v1, v2, nvec) = let (
    a1 = anglev(v1, v2),
    normv = unitv(cross(v1, v2)),
    nvec1 = unitv(nvec)
) (abs(nvec1.x - normv.x) < 1 && abs(nvec1.y - normv.y) < 1 && abs(nvec1.z - normv.z) < 1) ? a1 : -a1;

// Function to get the open tube vector
function openTubeVec(v1, v2, rtVec) = let (
    v1axis = v1[0] == 0 && v1[1] == 0 ? [0, 1, 0] : cross([0, 0, 1], v1),
    v1ang = anglev([0, 0, 1], v1),
    v1axisLen = mod(v1axis),
    vec2 = vec4_from_vec3(v2),
    qRev = quat(v1axis, v1ang),
    qRevMat = quat_to_mat4(qRev),
    vec2Rev = v1axisLen > 0 ? vec4_mult_mat4(vec2, qRevMat) : vec2,
    theta = atan2(vec2Rev[1], vec2Rev[0]),
    a = theta < 0 || theta > 0 ? theta : 0,
    rVec1 = rotVec(rtVec, a, [0, 0, 1])
) rotVec(rVec1, v1ang, unitv(v1axis));

// Placeholder modules for shapes
module halfTorusSlice(r1, r2, start_angle, end_angle, openAng, convexity = 10, r3 = 0, $fn = 64) {
    if (end_angle > start_angle) {
        rotate_extrude(convexity = convexity, angle = end_angle - start_angle) translate([r1, 0, 0]) difference() {
            circle(r2);
            union() {
                circle(r3);
                rotate(openAng) translate([-(r2 + 1), 0, 0]) square(2 * r2 + 2);
            }
        }
    }
}

module halfTube(or, ir, h, ang, center = true) {
    linear_extrude(height = h + 1, center = center, convexity = 5) difference() {
        circle(or);
        union() {
            circle(ir);
            rotate(ang) translate([-(or + 1), 0, 0]) square(2 * or + 2);
        }
    }
}

// Test pieces
if (true) {
    curvedHalfPipe(
        [
            [0, 0, 0], [100, 0, 0], [100, 100, 0], [50, 100, 100], [50, 100, 150], [0, 100, 50],
            [0, 0, 0], [50, 0, 50]
        ],
        7, [70, 30, 30, 6, 50, 30], 10, 8
    );

    rotate([0, 0, 180]) curvedHalfPipe(
        [
            [0, 0, 0], [100, 0, 0], [100, 100, 0], [100, 100, 100], [0, 100, 100], [0, 100, 0], [0, 0, 0],
            [50, 0, 50]
        ],
        7, [70, 30, 30, 6, 50, 30], 10, 8
    );

    translate([200, 0, 0]) curvedHalfPipe(
        [
            [100, 0, 50], [50, 0, 0], [0, 0, 0], [-70, 1/8*10, 0], [-70, 3/8*10, 140],
            [70, 5/8*10, 140], [70, 7/8*10, 0], [0, 10, 0], [-50, 10*0.9, 0], [-100, 10*0.8, 50]
        ],
        9, [100, 100, 70, 70, 70, 70, 100, 100], 10, 8
    );
}
