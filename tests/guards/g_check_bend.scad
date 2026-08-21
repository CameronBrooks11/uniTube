// MUST FAIL — CHECK-1. An od=12 tube swept through an r=4 bend passes THROUGH
// ITSELF, and CGAL reports `Simple: yes, Volumes: 2` with a plausible positive
// volume and zero warnings. Verified on this machine. Only arithmetic on the
// spine catches it, which is why ut_check exists.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ], [ 40, 40, 0 ] ], r = 4), ut_round(od = 12, wall = 2));
