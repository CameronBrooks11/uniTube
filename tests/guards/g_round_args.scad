// MUST FAIL — exactly two of od/id/wall. Three is over-determined and the third
// value would be silently ignored.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_round(od = 12, id = 8, wall = 5);
echo(ut_prof_od(p));
cube(0.001);
