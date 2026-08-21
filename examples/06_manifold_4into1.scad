// 06_manifold_4into1 — THE ACCEPTANCE TEST.
//
// Four inlets converging into one outlet. This is the driving application the
// whole project was started for, and it has never rendered in ANY commit of this
// repository: the 2023 attempt (reference/jantecnl/) got about 60% of the way
// and stopped at the bend lumen, calling torusSlice_only_inner_pipes(), which
// `git log -S` confirms was never defined anywhere.
//
// What makes it work is that the bore is FREE: the same spine, the same
// stations and the same frame as the shell, swept with a different region. The
// assembler then runs one difference per lumen group -- all shells unioned
// first, all bores cut second -- so no branch's wall can seal another's lumen.
//
// `Simple: yes` does NOT prove the lumens are open; the sealed version reports
// exactly the same. checks/manifold/ asserts patency independently.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 8;
$fs = 1;

BRANCH_OD = 12;
BRANCH_ID = 8;
TRUNK_OD = 16;
TRUNK_ID = 12;
N = 4;      // inlets
RING = 50;  // how far out each inlet starts
DROP = -55; // and how far below

module part()
{
    prof = ut_round(od = BRANCH_OD, id = BRANCH_ID);
    branches = [for (i = [0:N - 1]) let(th = 360 * i / N) ut_run(
        str("in", i),
        ut_polyline([[RING * cos(th), RING * sin(th), DROP], [RING * cos(th), RING * sin(th), -25], [0, 0, 0]], r = 15),
        prof)];
    trunk = ut_run("out", ut_polyline([ [ 0, 0, 0 ], [ 0, 0, 55 ] ]), ut_round(od = TRUNK_OD, id = TRUNK_ID));

    net = ut_net(concat(branches, [trunk]),
                 [ut_joint(concat([for (i = [0:N - 1])[str("in", i), "b"]], [[ "out", "a" ]]), at = [ 0, 0, 0 ])]);

    ut_assemble(net);
}

part();
