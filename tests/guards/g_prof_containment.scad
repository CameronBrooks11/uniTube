// MUST FAIL — PROF-1 containment. docs/profile.md has always stated the inner
// loop must lie inside the outer; nothing asserted it. Measured before the fix:
// ut_profile(ut_ring(4,N), ut_ring(6,N)) was accepted, ut_check returned true,
// and the swept mesh had volume -3105.83 -- inside-out.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
N = 24;
bad = ut_profile(ut_ring(4, N), ut_ring(6, N)); // inner LARGER than outer
ut_tube(ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ] ]), bad);
