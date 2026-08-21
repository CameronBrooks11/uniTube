// t_check — the positive side of the analytic guards. The negative side lives in
// tests/guards/, since an assert that fires cannot be caught from inside OpenSCAD.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

prof = ut_round(od = 12, wall = 2);
assert(abs(ut_prof_reach(prof) - 6) < 1e-9, "a round profile reaches od/2 from the centreline");

// Reach is a property of the OUTLINE, not of od -- an arbitrary section is
// measured, not assumed.
sq = ut_profile(ut_ring(6, 32), ut_ring(4, 32), [[ "od", 12 ]]);
assert(abs(ut_prof_reach(sq) - 6) < 1e-6, "reach measures the farthest vertex");

// CHECK-1 passes comfortably here: r=15 against a reach of 6.
ok = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 15);
assert(ut_check(ok, prof), "a well-proportioned bend passes");

// The boundary: r must be STRICTLY greater than the reach. r = 6.0001 passes,
// r = 4 aborts (tests/guards/g_check_bend.scad). At r == reach the inner
// extremity of the swept surface collapses onto the bend axis.
edge = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 6.0001);
assert(ut_check(edge, prof), "just above the reach is legal");

// A straight run has no arcs, so CHECK-1 has nothing to say.
assert(ut_check(ut_polyline([ [ 0, 0, 0 ], [ 30, 0, 0 ] ]), prof), "a straight run always passes");

cube(0.001); // sentinel
