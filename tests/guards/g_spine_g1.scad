// MUST FAIL — SPINE-3. A tangent discontinuity at an interior joint is a mitre,
// and an orthonormal frame cannot render one at any resolution (ADR 0004).
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_spine([ ut_line([ 0, 0, 0 ], [ 50, 0, 0 ]), ut_line([ 50, 0, 0 ], [ 50, 50, 0 ]) ]);
echo(len(ut_segs(p)));
cube(0.001);
