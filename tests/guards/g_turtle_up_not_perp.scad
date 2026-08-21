// MUST FAIL — the turtle's up-vector must be perpendicular to its heading, or
// the bend plane is undefined and every subsequent command compounds the error.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_turtle([[ "feed", 40 ]], dir = [ 1, 0, 0 ], up = [ 1, 1, 0 ]);
echo(len(ut_segs(p)));
cube(0.001);
