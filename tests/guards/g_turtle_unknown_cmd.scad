// MUST FAIL — an unrecognised turtle command. Silently ignoring one would build
// a different part from the one described, which is the failure class this
// library exists to prevent.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_turtle([ [ "feed", 40 ], [ "twist", 90 ], [ "feed", 40 ] ]);
echo(len(ut_segs(p)));
cube(0.001);
