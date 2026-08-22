// GUARD — id = 0. A zero bore is a rod, not a tube: the inner loop collapses to
// a point and PROF-1 used to report "inner loop must also be counter-clockwise",
// naming the wrong cause. ut_rod() is the answer.
// clang-format off
include <../../src/uniTube.scad>;
// clang-format on

ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ] ]), ut_round(od = 10, id = 0));
