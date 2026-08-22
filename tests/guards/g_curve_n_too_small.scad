// MUST FAIL — ut_curve needs at least two intervals to have a path at all.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_curve(function(t)[10 * t, 0, 0], n = 1);
echo(len(ut_segs(p)));
cube(0.001);
