// t_mesh — mesh properties WITHOUT rendering. This is the tier that catches the
// silent-material-loss class; CGAL's "Simple: yes" does not (PLAN.md §6).

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

path = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 15);
prof = ut_round(od = 12, wall = 2);
N = len(ut_prof_outer(prof));

// Analytic expectation: the swept area is the annulus between two N-gons, and
// the developed length is exact. Faceting the arc makes the mesh slightly
// smaller than the ideal, hence the band rather than an equality.
poly_area = function(r)(N / 2) * r * r * sin(360 / N);
expected = (poly_area(6) - poly_area(4)) * ut_length(path);
vol = ut_run_volume(path, prof);
assert(abs(vol - expected) / expected < 0.005,
       str("mesh volume ", vol, " must be within 0.5% of the analytic ", expected));

// The bore is a POSITIVE solid built from the same spine, stations and frame.
// That is what makes the junction two-pass free (AGENTS.md rule 5).
bore = ut_run_volume(path, prof, "bore");
shell = ut_run_volume(path, prof, "shell");
assert(abs(shell - bore - vol) / vol < 1e-6, "shell - bore must equal the finished wall exactly");
assert(abs(bore - poly_area(4) * ut_length(path)) / bore < 0.005, "bore volume matches the analytic lumen");

// Face and vertex counts are structural, not approximate.
sts = ut_stations(path);
pts = ut_mesh_points(ut_solid_rgn(prof), sts);
fcs = ut_mesh_faces(ut_solid_rgn(prof), sts);
assert(len(pts) == len(sts) * 2 * N, "annular mesh has 2N vertices per station");
assert(len(fcs) == (len(sts) - 1) * 4 * N + 4 * N, "annular mesh face count: skins plus two ring caps");
assert(min([for (f = fcs) len(f)]) == 3 && max([for (f = fcs) len(f)]) == 3,
       "every face is a TRIANGLE -- swept quads are non-planar and OpenSCAD would guess");

// Every vertex index is in range: an out-of-range index is a silent bad mesh.
assert(max([for (f = fcs) max(f)]) == len(pts) - 1, "face indices reach exactly the last vertex");
assert(min([for (f = fcs) min(f)]) == 0, "face indices start at 0");

cube(0.001); // sentinel
