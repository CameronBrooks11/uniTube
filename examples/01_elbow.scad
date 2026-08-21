// 01_elbow — the worked example from PLAN.md §2.2.
//
// A 90-degree hollow elbow: three spine segments, one polyhedron, no CSG.
// The difference() against a tiny cube forces CGAL so `just verify` has a report
// to read; a raw polyhedron() is never validated otherwise.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

path = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 15);
prof = ut_round(od = 12, wall = 2);

difference()
{
    ut_tube(path, prof);
    cube(0.001);
}
