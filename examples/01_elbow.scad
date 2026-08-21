// 01_elbow — the worked example from PLAN.md §2.2.
//
// A 90-degree hollow elbow: three spine segments, one polyhedron, no CSG.
// render() forces CGAL, so `just verify` has a report to read; a raw
// polyhedron() is never validated otherwise. A tiny subtracted cube would do it
// too, but it PERTURBS THE GEOMETRY -- at the origin of a manifold that is
// inside the material.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

path = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 15);
prof = ut_round(od = 12, wall = 2);

// The example geometry, as a module so `just verify` can wrap it in a no-op
// boolean to force CGAL. A raw polyhedron() is never validated otherwise.
module part()
{
    ut_tube(path, prof);
}

part();
