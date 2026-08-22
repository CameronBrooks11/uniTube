// MUST FAIL — 2D waypoints. cross() needs 3-vectors, so this used to report only
// "atan2() parameter could not be converted" from inside ut_math.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_polyline([ [ 0, 0 ], [ 50, 0 ], [ 50, 50 ] ], r = 10);
echo(len(ut_segs(p)));
cube(0.001);
