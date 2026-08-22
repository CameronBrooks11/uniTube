// MUST FAIL — NET-5 with the liner OFFSET along the jacket, sharing no endpoint.
//
// This is the case the ENDPOINT heuristic missed completely until 2026-08-21.
// Measured then: ut_check_net returned true, CGAL reported "Simple: yes", and
// the assembly silently lost 3733.3 mm3 -- exactly 100% of the liner, 9.6% of
// the part. Bit for bit the failure examples/08 exists to prevent, reached by
// sliding one run 70 mm along the other.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
ut_assemble(ut_net([
    ut_run("jacket", ut_polyline([ [ 0, 0, 0 ], [ 200, 0, 0 ] ]), ut_round(od = 30, id = 26), group = 0),
    ut_run("liner", ut_polyline([ [ 70, 0, 0 ], [ 130, 0, 0 ] ]), ut_round(od = 12, id = 8), group = 0),
]));
