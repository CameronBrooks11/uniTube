// MUST FAIL — SPINE-2 contiguity. Each segment must end where the next begins.
// A gap here means the frontend produced a broken spine, and the failure would
// otherwise appear far downstream as a strange mesh.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_spine([ ut_line([ 0, 0, 0 ], [ 40, 0, 0 ]), ut_line([ 50, 0, 0 ], [ 90, 0, 0 ]) ]);
echo(len(ut_segs(p)));
cube(0.001);
