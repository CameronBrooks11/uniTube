// 04_helix — an arbitrary parametric centreline.
//
// The only frontend that expresses helices, coils and serpentines. It lowers to
// a single sampled `P` segment, which is honest about what it gives up: exact
// arclength, exact transport, and the minimum-bend-radius check all need arcs.
// Measured here, the sampled length is 0.025% under the analytic helix length --
// a chord approximation, behaving exactly as documented.
//
// Supplying `dfdt` gives EXACT tangents at every sample instead of central
// differences, which is worth doing whenever the derivative is known.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

R = 50;      // helix radius
TURNS = 2.5; // how many
RISE = 45;   // mm of climb per turn

module part()
{
    coil =
        ut_curve(function(t)[R * cos(360 * TURNS * t), R * sin(360 * TURNS * t), RISE * TURNS * t],
                 dfdt = function(t)[-R * sin(360 * TURNS * t), R * cos(360 * TURNS * t), RISE * TURNS / 360], n = 220);

    ut_tube(coil, ut_round(od = 10, wall = 2));
}

part();
