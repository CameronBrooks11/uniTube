// 03_turtle_route — a bender program.
//
// This is the frontend that PROVES the IR (ADR 0002). It is shaped nothing like
// the polyline frontend -- relative rather than absolute, with an explicit roll
// command -- and it lowers to the same spine without the spine growing a case.
//
// `roll` emits NO GEOMETRY. It rotates the turtle's own up-vector, which changes
// the PLANE of every subsequent bend and therefore the shape of the path, and
// then it is gone. Nothing about roll enters the IR, because a bender rotating
// the workpiece does not twist the tube. Comment out the roll below and the last
// two bends fold back into the first plane.
//
// This is also literally how a CNC tube bender is programmed: Length, Rotation,
// Angle.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

module part()
{
    route = ut_turtle([
        [ "feed", 60 ],
        [ "bend", 90, "r", 24 ],
        [ "feed", 40 ],
        [ "roll", 90 ], // no geometry -- but the next bend leaves the plane
        [ "bend", 45, "r", 24 ],
        [ "feed", 30 ],
        [ "roll", -60 ],
        [ "bend", 60, "r", 20 ],
        [ "feed", 45 ],
    ]);

    ut_tube(route, ut_round(od = 12, wall = 2));
}

part();
