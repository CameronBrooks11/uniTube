// ut_port — the termination seam, and nothing more (ADR 0005).
//
// uniTube ships this record and a placement module. It ships zero threads,
// barbs, clamps, sockets or grooves; those belong to a separate library that
// consumes only this file. THIS FILE HAS NO DEPENDENCIES ON PURPOSE -- a
// fittings library couples to a data format, not to a geometry engine.
//
//     port = ["utport", name, p, dir, n, profile, s]
//
//   dir  points OUTWARD, away from the material. Fixed once, here.
//   n    is the roll reference at that end -- the CLOCKING. A port carries a
//        full FRAME, not a position and a diameter, so a hex flat, keyway or
//        bayonet lug lands repeatably.

function ut_port(name, p, dir, n, profile, s) = [ "utport", name, p, dir, n, profile, s ];

// These accessors are the documented public surface of the seam (ADR 0005) and
// are deliberately unused inside this library: a terminations library reads
// them, and coupling to a DATA FORMAT rather than a geometry engine is the whole
// point. Do not delete them for being uncalled here.
function ut_port_name(p) = p[1];
function ut_port_pos(p) = p[2];
function ut_port_dir(p) = p[3];
function ut_port_normal(p) = p[4];
function ut_port_profile(p) = p[5];
function ut_port_s(p) = p[6];

// Place children at a port: +Z along the outward direction, +X along the roll
// reference, origin at the end plane. This is already the convention every
// create_*_part in reference/makrokaba/ emits into.
module ut_at_port(port)
{
    d = port[3];
    n = port[4];
    b = cross(d, n);
    p = port[2];
    multmatrix([[n [0], b [0], d [0], p [0]], [n [1], b [1], d [1], p [1]], [n [2], b [2], d [2], p [2]], [0, 0, 0, 1]])
        children();
}

// A debug marker: the outward direction as an arrow, plus the roll reference.
// This is how you verify the seam is right before any termination exists.
module ut_port_marker(port, len = 12)
{
    d = port[3];
    n = port[4];
    p = port[2];
    color("red") translate(p) linear_extrude(0.1) circle(1.2, $fn = 12);
    color("red") translate(p) _ut_arrow(d, len);
    color("blue") translate(p) _ut_arrow(n, len * 0.6);
}

module _ut_arrow(v, len)
{
    u = v / norm(v);
    hull()
    {
        sphere(0.4, $fn = 8);
        translate(u * len) sphere(0.4, $fn = 8);
    }
    translate(u * len) sphere(1.0, $fn = 12);
}
