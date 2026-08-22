// MUST FAIL — NET-0. ut_tube() has always run ut_check(); ut_assemble() did not,
// so CHECK-1 did not exist for the NETWORK layer -- the flagship capability, and
// the one all three network examples use. Measured before the fix: od=12 (reach
// 6) through an r=5.5 bend aborted via ut_tube and rendered "Simple: yes,
// Volumes: 2" via ut_assemble, with ut_check_net returning true.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
r = ut_run("a", ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ], [ 40, 40, 0 ] ], r = 5.5), ut_round(od = 12, wall = 2));
ut_assemble(ut_net([r]));
