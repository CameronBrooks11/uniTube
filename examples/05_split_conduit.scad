// 05_split_conduit — replaces reference/axford/half_curvedPipe.scad.
//
// A lengthwise-split conduit over two bends in DIFFERENT planes. The seam must
// not wander around the tube as the axis turns; that is the entire problem
// half_curvedPipe.scad existed to solve, in ~300 lines and with a hard
// nine-segment ceiling.
//
// Here it is two things:
//   * the split is a PROFILE          ut_round(..., split=[-30,30])
//   * the seam is a FRAME POLICY      frame="fixed", normal=UP
//
// "fixed" is better than transport for a printable part: transport only
// guarantees the seam does not spiral relative to the TUBE, whereas a printed
// part has a gravity-relative requirement. Here the gap faces as near world-up
// as the axis allows the whole way, so it prints as an open channel with no
// bridging.
//
// THE RUN NEVER GOES VERTICAL, AND THAT IS A CONSTRAINT, NOT AN ACCIDENT. A seam
// pinned to a world direction is undefined where the axis points along it -- a
// vertical pipe has no upward-facing side. This example used to climb straight
// up +Z at the end, and the seam flipped 174 degrees in a single 6-degree step
// while the mesh stayed manifold and every gate passed. The final leg now rises
// at 37 degrees, and ut_stations() refuses the degenerate ask outright.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

path = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 40, 0 ], [ 100, 40, 30 ] ], r = 18);
prof = ut_round(od = 16, wall = 2, split = [ -30, 30 ]);

// The example geometry, as a module so `just verify` can wrap it in a no-op
// boolean to force CGAL. A raw polyhedron() is never validated otherwise.
module part()
{
    ut_tube(path, prof, opts = [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]);
}

part();
