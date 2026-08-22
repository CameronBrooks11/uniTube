// GUARD — a caller-supplied frame list whose normal is PARALLEL to the tangent.
// Projection leaves nothing and ut_ortho() returns [nan, nan, nan]. This was
// silent, and it defeated the very test written to catch it: OpenSCAD's max()
// drops nan, so `max([abs(t*n)]) < 1e-9` measured 2.22e-16 and passed.
// clang-format off
include <../../src/uniTube.scad>;
// clang-format on

// The last leg runs straight up, so an all-UP normal list is parallel there.
path = ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ], [ 40, 40, 0 ], [ 40, 40, 40 ] ], r = 12);
n = len(ut_stations(path));
ut_tube(path, ut_round(od = 16, wall = 2), opts = [[ "frame", [for (i = [0:n - 1])[0, 0, 1]] ]]);
