// 07_ports_debug — the termination seam, made visible.
//
// A port carries a full FRAME, not a position and a diameter. Red is the
// OUTWARD direction; blue is the roll reference, which is the clocking a hex
// flat or bayonet lug would be aligned to. Terminations themselves are a
// separate library (ADR 0005) -- this is the interface they attach to.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 8;
$fs = 1;

path = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 40, 0 ], [ 60, 40, 40 ] ], r = 18);
prof = ut_round(id = 8, wall = 2);
ports = ut_run_ports(path, prof, "demo");

color("silver") ut_tube(path, prof);
for (p = ports)
    ut_port_marker(p);
