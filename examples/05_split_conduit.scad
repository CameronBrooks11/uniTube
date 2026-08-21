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
// "fixed" is strictly better than transport for a printable part: transport only
// guarantees the seam does not spiral relative to the TUBE, whereas a printed
// part has a gravity-relative requirement. Here the gap faces world-up the whole
// way, so it prints as an open channel with no bridging.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

path = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 40, 0 ], [ 60, 40, 40 ] ], r = 20);
prof = ut_round(od = 16, wall = 2, split = [ -30, 30 ]);

// The example geometry, as a module so `just verify` can wrap it in a no-op
// boolean to force CGAL. A raw polyhedron() is never validated otherwise.
module part()
{
    ut_tube(path, prof, opts = [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]);
}

part();
