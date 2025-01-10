// taken from:
// moreShapes library
// 2D and 3D utility shape functions
// Author: Damian Axford
// Updated:  8 Apr 2013
// Public Domain

// some borrowed from nophead / Mendel90 utils.scad

use <FunctionalOpenSCAD/functional.scad>;

function vec2_from_vec3(v) = [ v[0], v[1] ];

function enumerate_nfaces_vec(nfaces) = [for (i = [0:nfaces - 1]) i];

echo("enumerate_nfaces_vec(5) = ", enumerate_nfaces_vec(5));

module torusSlice(radius, xsec_or, start_angle, end_angle, convexity = 10, xsec_ir = 0, $fn = 64)
{
    rx = radius + xsec_or;
    ry = rx;
    trx = rx * sqrt(2) + 1;
    try = ry * sqrt(2) + 1;
    a0 = (4 * start_angle + 0 * end_angle) / 4;
    a1 = (3 * start_angle + 1 * end_angle) / 4;
    a2 = (2 * start_angle + 2 * end_angle) / 4;
    a3 = (1 * start_angle + 3 * end_angle) / 4;
    a4 = (0 * start_angle + 4 * end_angle) / 4;
    if (end_angle > start_angle)
    {

        rotate(a = start_angle, v = [ 0, 0, 1 ]) rotate_extrude(angle = end_angle - start_angle, convexity = convexity)
            translate([ radius, 0, 0 ]) difference()
        {
            circle(xsec_or, $fn = $fn / 4);
            circle(xsec_ir, $fn = $fn / 4);
        }
    }
    else
    {
        echo("end_angle must be greater than start_angle");
    }
}

// function to shift all values in a flat array by given amount
function shiftFlatArray(arr, shift) = [for (i = [0:len(arr) - 1]) arr[i] + shift];

module torusSliceF(radius, xsec_or, start_angle, end_angle, convexity = 10, xsec_ir = 0, $fn = 64)
{
    rx = radius + xsec_or;
    ry = rx;
    trx = rx * sqrt(2) + 1;
    try = ry * sqrt(2) + 1;
    a0 = (4 * start_angle + 0 * end_angle) / 4;
    a1 = (3 * start_angle + 1 * end_angle) / 4;
    a2 = (2 * start_angle + 2 * end_angle) / 4;
    a3 = (1 * start_angle + 3 * end_angle) / 4;
    a4 = (0 * start_angle + 4 * end_angle) / 4;

    or_poly = translate([ radius, 0 ], circle(xsec_or));
    ir_poly = translate([ radius, 0 ], circle(xsec_ir));

    echo("or_poly = ", or_poly);

    or_rot_poly = rotate_extrude(angle = 180, poly = or_poly);
    ir_rot_poly = rotate_extrude(angle = 180, poly = ir_poly);

    prerot_poly = [
        concat(or_rot_poly[0], ir_poly[0]),
        concat((or_rot_poly[1]), [shiftFlatArray(flatten(ir_poly[1]), len(or_rot_poly[1][0]))])
    ];

    poly = [
        concat(or_poly[0], ir_poly[0]), concat((or_poly[1]), [shiftFlatArray(flatten(ir_poly[1]), len(or_poly[1][0]))])
    ];
    echo("poly = ", poly);

    poly_rot = rotate_extrude(angle = 180, poly = poly);

    if (end_angle > start_angle)
    {

        // rotate(a = start_angle, v = [ 0, 0, 1 ]) rotate_extrude(angle = end_angle - start_angle, convexity =
        // convexity)
        translate([ radius, 0, 0 ])
        {
            // showPoints(poly);

            // poly2d(poly);
            // poly3d(poly_rot);
            poly3d(prerot_poly);
        }
    }
    else
    {
        echo("end_angle must be greater than start_angle");
    }
}

module tube(or, ir, h, center = true)
{
    linear_extrude(height = h, center = center, convexity = 5) difference()
    {
        circle(or);
        circle(ir);
    }
}

translate([ -50, 0, 0 ]) torusSliceF(radius = 10, xsec_or = 5, xsec_ir = 3, start_angle = 50, end_angle = 255);

// translate([ -20, 0, 0 ]) torusSlice(radius = 10, xsec_or = 5, xsec_ir = 3, start_angle = 50, end_angle = 255);

// translate([ 20, 0, 0 ]) tube(or = 10, ir = 5, h = 30, center = false);