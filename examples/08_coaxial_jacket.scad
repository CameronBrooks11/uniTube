// 08_coaxial_jacket — the LUMEN GROUP regression.
//
// A tube inside a tube: a Bowden liner in a conduit, a double-wall flue, a
// vacuum jacket, a tube-in-tube exchanger. Ordinary tube topology.
//
// Under ONE global difference over the whole assembly, the outer run's bore
// (d26) swallows the inner run's shell (d12) entirely -- measured, 7883.8 of
// 29958.5 mm3, 26% of the material, silently deleted, with CGAL still reporting
// `Simple: yes`. The invariant did not remove silent corruption, it swapped one
// flavour for its dual, and the new one looks plausible.
//
// The fix is five lines: every run carries a lumen group, and the two-pass runs
// once per group. Declaring the group is the user's job, and ut_check_net's
// NET-5 refuses the assembly if two nesting runs share one.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 8;
$fs = 1;

module part()
{
    path = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 50, 0 ] ], r = 20);
    jacket = ut_run("jacket", path, ut_round(od = 30, id = 26), group = 0);
    liner = ut_run("liner", path, ut_round(od = 12, id = 8), group = 1);

    ut_assemble(ut_net([ jacket, liner ]));
}

part();
