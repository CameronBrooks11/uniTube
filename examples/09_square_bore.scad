// 09_square_bore — an arbitrary hollow section, with no special case anywhere in
// the backend. A round shell over a square lumen.
//
// The bore is sampled BY ANGLE, at the same angles as the shell. That is what
// PROF-2 requires and it is not optional: sampling the square by PERIMETER gives
// the right point count, starts the loop at a corner while the shell starts at
// 0 degrees, twists the end-cap strip around the annulus, and CGAL reports only
// "assertion violation". See ADR 0006 and tests/guards/g_prof_align.scad.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

function square_by_angle(h, n) = [for (k = [0:n - 1])
        let(t = 360 * k / n, cx = cos(t), cy = sin(t), m = h / max(abs(cx), abs(cy)))[m * cx, m *cy]];

N = ut_fragments(7, 360);
prof = ut_profile(ut_ring(7, N), square_by_angle(4, N), [ [ "od", 14 ], [ "kind", "square-bore" ] ]);
path = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 40, 0 ] ], r = 18);

difference()
{
    ut_tube(path, prof);
    cube(0.001);
}
