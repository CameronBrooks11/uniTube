// 10_tee_wall_landing — the junction case that breaks the naive construction.
//
// The branch starts on the trunk's outer WALL, not on its axis. That is how
// every real tee is described, and how reference/doommeister/'s own middle_tee_n
// is parameterised -- and in design review it produced a 0.95 mm PLUG across the
// branch lumen while CGAL reported `Simple: yes, Volumes: 2` and a naive
// manifoldness regression test PASSED.
//
// Two things fix it, and neither is a global epsilon:
//   * the joint is DECLARED, with a mid-run landing ["s", 50] on the trunk, so
//     the assembler knows the node is on the trunk CENTRELINE;
//   * both the shell AND the bore are extended from the branch end to that node.
//     Extending only the bore leaves the shells touching tangentially -- measured
//     `Simple: yes, Volumes: 3`, two solids sharing a circle.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 8;
$fs = 1;

module part()
{
    trunk = ut_run("trunk", ut_polyline([ [ -50, 0, 0 ], [ 50, 0, 0 ] ]), ut_round(od = 20, wall = 2));
    // Starts at y = 10, exactly on the trunk's outer surface.
    branch = ut_run("branch", ut_polyline([ [ 0, 10, 0 ], [ 0, 50, 0 ] ]), ut_round(od = 12, wall = 2));

    ut_assemble(ut_net([ trunk, branch ], [ut_joint([ [ "trunk", [ "s", 50 ] ], [ "branch", "a" ] ])]));
}

part();
