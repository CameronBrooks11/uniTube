// MUST FAIL — NET-5. A liner inside a jacket, both in the SAME lumen group.
// With one global difference the outer bore swallows the inner run entirely:
// measured, 7883.8 of 29958.5 mm3 -- 26% of the material -- silently deleted,
// with CGAL still reporting `Simple: yes`. Verified by deliberate reintroduction:
// solid_count reads `measured 1, limit equals=2`.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
path = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ] ]);
ut_assemble(ut_net([
    ut_run("jacket", path, ut_round(od = 30, id = 26)),
    ut_run("liner", path, ut_round(od = 12, id = 8)), // same group -- refused
]));
