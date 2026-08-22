// 11_closed_loop — a closed path.
//
// The closed machinery has existed since Phase 1 and was never reachable: the
// holonomy absorption in ut_stations, the cap-suppressing wrap in ut_mesh, and
// SPINE-2's closed contiguity check were all built and all correct. What was
// missing was a way to ask for one, a test, and the STATION-7 fix.
//
// Closed paths are reachable through ut_spine ONLY. ut_polyline refuses them
// explicitly, and ut_turtle and ut_curve have no `closed` parameter at all
// (--hardwarnings turns passing one into an error). Wiring `closed` through the
// other frontends raises a real question each -- what IS a closed turtle
// program? -- and is deliberately not answered yet.
//
// WHAT A CLOSED TUBE IS: its lumen is a SEALED INTERNAL CAVITY. CGAL reports
// `Volumes: 3` -- the outside, the material, and the trapped bore -- which is
// geometrically correct and means the part is useless until something breaches
// it. That is a property of the topology, not a defect.
//
// The frame is transported all the way round and the loop holonomy is measured,
// absorbed against the profile's rotational symmetry, and distributed by
// arclength, so the seam meets itself exactly. Measured residual: 0 degrees.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

R = 60;

module part()
{
    // Four quarter arcs about the origin, tangent-continuous, closing on themselves.
    loop = ut_spine(
        [
            ut_arc([ 0, 0, 0 ], [ 1, 0, 0 ], [ 0, 1, 0 ], R, 90),
            ut_arc([ 0, 0, 0 ], [ 0, 1, 0 ], [ -1, 0, 0 ], R, 90),
            ut_arc([ 0, 0, 0 ], [ -1, 0, 0 ], [ 0, -1, 0 ], R, 90),
            ut_arc([ 0, 0, 0 ], [ 0, -1, 0 ], [ 1, 0, 0 ], R, 90),
        ],
        closed = true);

    ut_tube(loop, ut_round(od = 14, wall = 2));
}

part();
