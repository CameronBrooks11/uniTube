// MUST FAIL — ADR 0004: r=0 at an interior vertex is an ERROR, not a mitre.
// This is the FIRST mistake a newcomer makes, because r=0 is ut_polyline's own
// DEFAULT: `ut_polyline([[0,0,0],[50,0,0],[50,50,0]])` used to report
// "WARNING: Invalid value (NaN) in parameter vector for cross()" from deep
// inside ut_math, naming nothing useful.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ]); // no r
echo(len(ut_segs(p)));
cube(0.001);
