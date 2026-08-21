// MUST FAIL — a C-section has no ENCLOSED lumen, so it has no bore to sweep and
// cannot participate in a junction. Documented rather than discovered.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ] ]), ut_round(od = 16, wall = 2, split = [ -30, 30 ]), part = "bore");
