// MUST FAIL — closed paths are reachable through ut_spine ONLY. ut_polyline
// refuses them explicitly rather than silently ignoring the argument, because
// "what does a closed polyline's fillet at the seam vertex do?" is a real
// question that is deliberately unanswered. ut_turtle and ut_curve have no
// `closed` parameter at all, so --hardwarnings catches those.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 10, closed = true);
echo(len(ut_segs(p)));
cube(0.001);
