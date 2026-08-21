// MUST FAIL — NET-3. The branch is declared incident to the joint but placed far
// beyond reach of it. The shells never touch, and the assembly would render as
// separate volumes joined by nothing.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
trunk = ut_run("trunk", ut_polyline([ [ -50, 0, 0 ], [ 50, 0, 0 ] ]), ut_round(od = 20, wall = 2));
branch = ut_run("branch", ut_polyline([ [ 0, 80, 0 ], [ 0, 120, 0 ] ]), ut_round(od = 12, wall = 2));
ut_assemble(ut_net([ trunk, branch ], [ut_joint([ [ "trunk", [ "s", 50 ] ], [ "branch", "a" ] ])]));
