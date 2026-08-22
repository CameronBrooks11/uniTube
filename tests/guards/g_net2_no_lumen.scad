// MUST FAIL — NET-2, LUMEN PATENCY. docs/verification.md calls this "the most important
// test in the library, because it is the only one that catches the failure the
// project exists to fix" -- and it had no negative test at all until now.
// A solid rod has no lumen, so there is nothing for the joint's core sphere to
// connect to and the junction cannot be opened.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
a = ut_run("a", ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ] ]), ut_round(od = 12, id = 8));
rod = ut_run("rod", ut_polyline([ [ 40, 0, 0 ], [ 40, 40, 0 ] ]), ut_rod(d = 12));
ut_assemble(ut_net([ a, rod ], [ut_joint([ [ "a", "b" ], [ "rod", "a" ] ])]));
