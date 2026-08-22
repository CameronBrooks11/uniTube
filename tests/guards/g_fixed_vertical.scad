// GUARD — frame="fixed" on a run that turns to VERTICAL. A seam pinned to a
// world direction is undefined where the axis points along it. This is the exact
// path examples/05 used to ship: the seam flipped 174 degrees in a single
// 6-degree step, the mesh stayed manifold, and every gate passed.
// clang-format off
include <../../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;
ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 40, 0 ], [ 60, 40, 40 ] ], r = 20),
        ut_round(od = 16, wall = 2, split = [ -30, 30 ]), opts = [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]);
