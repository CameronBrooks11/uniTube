// MUST FAIL — ut_curve takes a FUNCTION LITERAL. Passing a point list is the
// obvious mistake, and it would otherwise fail deep inside the sampler.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_curve([ [ 0, 0, 0 ], [ 10, 0, 0 ] ]);
echo(len(ut_segs(p)));
cube(0.001);
