// MUST FAIL — an unrecognised `part` value. --hardwarnings catches an unknown
// named ARGUMENT (the torusSlice bug class) but not an unknown VALUE, so the
// unguarded else silently rendered the BORE: measured, part="wall" gave 2961.26
// mm3, exactly the lumen, as a solid rod. Exit 0, no warning.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ] ]), ut_round(od = 12, wall = 2), part = "wall");
