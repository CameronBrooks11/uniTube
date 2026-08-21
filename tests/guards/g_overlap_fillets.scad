// MUST FAIL — GUARD 3, the repo's worst latent bug.
// The identical path at r=[20,20] renders genus 1 (a correct tube); at r=[80,80]
// on a 100 mm leg it used to render GENUS 2 -- an extra through-hole -- because
// OpenSCAD emits nothing for a non-positive extrusion height and says nothing.
// docs/salvage.md §3.
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
p = ut_polyline([ [ 0, 0, 0 ], [ 100, 0, 0 ], [ 100, 100, 0 ], [ 100, 100, 100 ] ], r = [ 80, 80 ]);
echo(len(ut_segs(p)));
cube(0.001);
