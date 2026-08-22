// MUST FAIL — two identical consecutive waypoints. The leg has no direction.
// Used to surface as "SPINE-3 violated: tangent discontinuity of 90 deg", which
// names the wrong cause entirely.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 10);
echo(len(ut_segs(p)));
cube(0.001);
