// 02_polyline_run — the legacy demo path, ported.
//
// These are the exact waypoints and radii from reference/axford/curvedPipe.scad's
// own test piece. Since commit 5d2975b (2025-01-10) every BEND in this path has
// rendered as literally nothing, because torusSlice's parameters were renamed
// without updating the call sites. This is the regression made visible.
//
// It lowers to 12 spine segments over 544.21 mm. Note that two of the bends are
// exactly tangent -- the straight between them is zero-length and is omitted
// rather than emitted as a degenerate segment.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 8;
$fs = 1;

pts = [
    [ 0, 0, 0 ], [ 100, 0, 0 ], [ 100, 100, 0 ], [ 50, 100, 100 ], [ 50, 100, 150 ], [ 0, 100, 50 ], [ 0, 0, 0 ],
    [ 50, 0, 50 ]
];
radii = [ 70, 30, 30, 6, 50, 30 ];

// The example geometry, as a module so `just verify` can wrap it in a no-op
// boolean to force CGAL. A raw polyhedron() is never validated otherwise.
module part()
{
    ut_tube(ut_polyline(pts, r = radii), ut_round(od = 10, id = 8));
}

part();
