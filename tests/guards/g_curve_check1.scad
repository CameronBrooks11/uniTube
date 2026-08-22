// MUST FAIL — CHECK-1 on a SAMPLED path.
//
// A helix of R=10 rising 20 mm per turn has a curvature radius of 11.013 mm.
// Swept with od=24 (reach 12) it passes THROUGH ITSELF. Before this check
// existed, a P segment was exempt from the library's flagship safety assert
// entirely and this rendered "Simple: yes, Volumes: 2" with zero warnings --
// exactly the case that justified ut_check in Phase 2, reached through the one
// frontend that was not covered.
//
// The discrete estimate recovers 11.014 against an analytic 11.0132.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
$fa = 8;
$fs = 1;
R = 10;
RISE = 20;
T = 3;
ut_tube(ut_curve(function(t)[R * cos(360 * T * t), R *sin(360 * T * t), RISE *T *t], n = 200),
        ut_round(od = 24, wall = 3));
