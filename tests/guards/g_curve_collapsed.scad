// MUST FAIL — every sample coincides, so after the mandatory dedupe there is no
// path left. Without the dedupe this is the [nan,nan,nan] in path_extrude.scad:58.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_curve(function(t)[5, 5, 5], n = 20);
echo(len(ut_segs(p)));
cube(0.001);
