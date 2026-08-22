// GUARD — a 2D parametric curve. Every point must be a 3-vector.
// Without the guard in ut_sampled() this built a spine happily and failed at
// SWEEP time with "atan2() parameter could not be converted", naming ut_math.
// clang-format off
include <../../src/uniTube.scad>;
// clang-format on

ut_tube(ut_curve(function(t)[t * 50, t *t * 20], n = 10), ut_round(od = 8, wall = 1.5));
