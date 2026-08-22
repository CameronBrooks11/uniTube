// 12_section_view — how to LOOK at a hollow part.
//
// Two questions come up on every model this library makes, and neither is
// answerable by rotating the viewport:
//
//   * IS THE BORE OPEN? An open bore seen at a shallow angle and a sealed end
//     render identically, and `Simple: yes` does not settle it -- a sealed lumen
//     reports exactly that.
//   * WHERE IS THE ROLL? A round tube looks the same however the frame is
//     clocked, so a twist or the wrong frame policy stays invisible.
//
// They are the SAME question, and one cut answers both: the section shows the
// bore directly, and because this profile has a SQUARE bore, the orientation of
// the cut face is the roll. The run is twisted a quarter turn, and you can watch
// the square rotate along it.
//
// SECTION is the toggle. Set it false and this is an ordinary solid part.
//
// preview-exposes-interior -- `just preview` reads this line. A cutaway shows
// back faces BY DESIGN, and that is the one legitimate reason to.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

SECTION = true;

// A square bore in a round tube -- ut_profile asserts PROF-2, so the square is
// sampled BY ANGLE to stay index-aligned with the outer circle (ADR 0006).
function square_by_angle(h, n) = [for (i = [0:n - 1]) let(a = 360 * i / n, c = cos(a), s = sin(a)) h /
                                  max(abs(c), abs(s)) * [ c, s ]];

N = ut_fragments(9, 360);
prof = ut_profile(ut_ring(9, N), square_by_angle(5, N), [ [ "od", 18 ], [ "kind", "square-bore" ] ]);
path = ut_polyline([ [ 0, 0, 0 ], [ 70, 0, 0 ], [ 70, 60, 0 ] ], r = 22);

module part()
{
    ut_cutaway([ 0, 0, 1 ], at = 0, on = SECTION) ut_tube(path, prof, opts = [[ "twist", 90 ]]);
}

part();
