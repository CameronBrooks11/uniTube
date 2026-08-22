// Provokes EVERY advisory warning the library can emit, so that silencing one
// is caught. This cannot live in tests/guards/: a guard must ABORT, and these
// are echo() calls that deliberately do not.
//
// --hardwarnings does NOT promote them -- they are ECHO: lines, not WARNING:
// lines -- so a green `just check` is NOT evidence that no uniTube warning was
// emitted. `just warnings` is what checks these, by asserting each one appears.

// clang-format off
use <../../src/uniTube.scad>;
// clang-format on

$fa = 12;
$fs = 2;

// CHECK-2 — a bend tighter than one full od. Legal, but tight to print.
// CHECK-3 — a wall below ut_min_wall(). Renders perfectly, prints as a hole.
ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ], [ 40, 40, 0 ] ], r = 7), ut_round(od = 10, id = 8));

// NET-4 — a joint ball whose own wall is below the minimum.
translate([ 0, 0, 60 ])
{
    prof = ut_round(od = 12, id = 11); // 0.5 mm wall
    a = ut_run("a", ut_polyline([ [ 0, 0, 0 ], [ 30, 0, 0 ] ]), prof);
    b = ut_run("b", ut_polyline([ [ 30, 0, 0 ], [ 30, 30, 0 ] ]), prof);
    ut_assemble(ut_net([ a, b ], [ut_joint([ [ "a", "b" ], [ "b", "a" ] ])]));
}
