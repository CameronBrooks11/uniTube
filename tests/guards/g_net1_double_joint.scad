// MUST FAIL — NET-1. One run end declared incident to TWO joints. The bore can
// only be aimed at one node, so the second is silently ignored.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
a = ut_run("a", ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ] ]), ut_round(od = 12, id = 8));
b = ut_run("b", ut_polyline([ [ 40, 0, 0 ], [ 40, 40, 0 ] ]), ut_round(od = 12, id = 8));
c = ut_run("c", ut_polyline([ [ 40, 0, 0 ], [ 40, 0, 40 ] ]), ut_round(od = 12, id = 8));
ut_assemble(ut_net([ a, b, c ],
                   [ ut_joint([ [ "a", "b" ], [ "b", "a" ] ]), ut_joint([ [ "a", "b" ], [ "c", "a" ] ]) ]));
