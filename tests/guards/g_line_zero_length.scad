// MUST FAIL — a zero-length line. Its direction is [0,0,0], which normalises to
// [nan,nan,nan] and poisons every frame downstream.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_spine([ut_line([ 10, 0, 0 ], [ 10, 0, 0 ])]);
echo(len(ut_segs(p)));
cube(0.001);
