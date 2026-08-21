// MUST FAIL — PROF-2, correspondence half (ADR 0006). This bore has the right
// POINT COUNT but is sampled by perimeter, so it starts at a corner (225 deg)
// while the shell starts at 0 deg. The cap strip then twists around the annulus
// and self-intersects, and CGAL reports only "assertion violation".
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
N = 32;
function sq_by_perimeter(h, n) = [for (i = [0:n - 1]) let(u = 4 * i / n, s = floor(u), f = u - s) s == 0
                                      ? [ h * (2 * f - 1), -h ]
                                  : s == 1 ? [ h, h * (2 * f - 1) ]
                                  : s == 2 ? [ h * (1 - 2 * f), h ]
                                           : [ -h, h * (1 - 2 * f) ]];
p = ut_profile(ut_ring(6, N), sq_by_perimeter(3, N));
echo(len(ut_prof_outer(p)));
cube(0.001);
