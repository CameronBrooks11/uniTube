// MUST FAIL — GUARD 1. A 180 degree doubleback gives tan(90) = inf, so the arc
// centre is [nan,nan,nan] and the segment silently disappears.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 0, 0, 0 ] ], r = 10);
echo(len(ut_segs(p)));
cube(0.001);
