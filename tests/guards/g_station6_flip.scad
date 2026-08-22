// GUARD — STATION-6 itself, reached through a caller-supplied frame list so the
// flip is the ONLY defect. One normal is negated; the tangent does not move.
// Without this check the sweep is manifold, CGAL reports Simple: yes, and any
// profile that is not rotationally symmetric is wrong from that station on.
// clang-format off
include <../../src/uniTube.scad>;
// clang-format on

path = ut_polyline([ [ 0, 0, 0 ], [ 80, 0, 0 ] ]);
n = len(ut_stations(path));
frames = [for (i = [0:n - 1])(i == floor(n / 2)) ? [ 0, 0, -1 ] : [ 0, 0, 1 ]];
ut_tube(path, ut_round(od = 16, wall = 2, split = [ -30, 30 ]), opts = [[ "frame", frames ]]);
