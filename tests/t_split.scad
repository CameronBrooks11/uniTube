// t_split — the C-section. A split tube is a PROFILE, not a path feature, and
// the seam is a FRAME POLICY. Between them they replace ~300 lines of
// reference/axford/half_curvedPipe.scad and its hard nine-segment ceiling.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 6;
$fs = 0.5;

prof = ut_round(od = 16, wall = 2, split = [ -30, 30 ]);
N = len(ut_prof_outer(prof));

// --- the profile is OPEN ------------------------------------------------------
assert(ut_prof_open(prof), "a split profile is open");
assert(ut_prof_hollow(prof), "it still has an inner surface");
assert(len(ut_bore_rgn(prof)) == 0, "but NO enclosed lumen -- it cannot join to anything");
assert(len(ut_shell_rgn(prof)) == 0, "and no meaningful shell region either");
assert(len(ut_solid_rgn(prof)) == 2, "the finished wall is still outer + inner");
assert(ut_prof_symmetry(prof) == 1, "a split section has 1-fold symmetry, which matters for closed-loop holonomy");

// --- the gap is where it was asked for ---------------------------------------
o = ut_prof_outer(prof);
first = atan2(o[0][1], o[0][0]);
last = atan2(o[N - 1][1], o[N - 1][0]);
assert(abs(first - 30) < 1e-9, str("material starts at the far edge of the gap, got ", first));
assert(abs(last - (-30)) < 1e-9, str("material ends at the near edge of the gap, got ", last));
// The gap is centred on profile-local +X, which IS the station's roll reference.
// That is what makes "the seam faces up" mean something.
assert(abs(norm(o[0]) - 8) < 1e-9 && abs(norm(o[N - 1]) - 8) < 1e-9, "outer edge sits at od/2");

// --- PROF-2 still holds across the open span ---------------------------------
i = ut_prof_inner(prof);
assert(len(i) == N, "PROF-2: equal point count");
assert(max([for (k = [0:N - 1]) abs(atan2(o[k][1], o[k][0]) - atan2(i[k][1], i[k][0]))]) < 1e-6,
       "PROF-2: angle-aligned index-for-index across the material span");

// --- a STRAIGHT run: volume is exactly area x length, no Pappus correction ----
L = 60;
straight = ut_polyline([ [ 0, 0, 0 ], [ L, 0, 0 ] ]);
seg_area = (N - 1) * 0.5 * (8 * 8 - 6 * 6) * sin(300 / (N - 1));
vol = ut_run_volume(straight, prof);
assert(abs(vol - seg_area * L) / (seg_area * L) < 1e-6,
       str("straight C-section volume ", vol, " must be exactly area*length ", seg_area *L));

// --- the mesh is CLOSED: two seam walls are added, and they are not optional --
sts = ut_stations(straight);
S = len(sts);
fcs = ut_mesh_faces(ut_solid_rgn(prof), sts, false, true);
// skins: 2 * (S-1) * (N-1) quads; caps: 2 * (N-1) quads; seam walls: 2 * (S-1) quads
expect_quads = 2 * (S - 1) * (N - 1) + 2 * (N - 1) + 2 * (S - 1);
assert(len(fcs) == expect_quads * 2, str("open-annulus face count: expected ", expect_quads * 2, " got ", len(fcs)));
assert(min([for (f = fcs) len(f)]) == 3, "every face is a triangle");

// --- the seam does not spiral over bends in DIFFERENT planes -----------------
// This is the exit criterion, and the case half_curvedPipe.scad was built for.
//
// The final leg CLIMBS AT 37 DEGREES rather than running straight up, and that
// matters. This test used to finish vertical and then assert only that the
// frame was not NaN there. It is not NaN -- ut_ref_fallback swaps UP for BACK --
// but that swap is a discontinuity, and the seam jumped 174 degrees in one
// 6-degree step while this assert passed. "Not NaN" was never the requirement;
// continuity is, and STATION-6 now enforces it in ut_stations().
bendy = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 40, 0 ], [ 100, 40, 30 ] ], r = 18);
fx = ut_stations(bendy, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]);
horiz = [for (s = fx) if (abs(ut_st_t(s)[2]) < 1e-9) s];
assert(len(horiz) > 4, "expected many horizontal stations across two bends");
assert(max([for (s = horiz) norm(ut_st_n(s) - [ 0, 0, 1 ])]) < 1e-9,
       "the gap must face EXACTLY world-up on every horizontal station -- no spiral");
// The seam is continuous across BOTH bends, including the one that climbs.
assert(max([for (i = [1:len(fx) - 1]) ut_turn(ut_st_n(fx[i]), ut_st_n(fx[i - 1])) -
            ut_turn(ut_st_t(fx[i]), ut_st_t(fx[i - 1]))]) < 1e-9,
       "STATION-6: the seam never outruns the axis, so a C-section stays a C-section");
// Every frame is real. Counting is the only way to see this -- max() drops nan.
assert(len([for (s = fx) if (!is_num(ut_st_n(s)[0]) || !is_num(ut_st_n(s)[1]) || !is_num(ut_st_n(s)[2])) 1]) == 0,
       "no station frame may contain nan");

cube(0.001); // sentinel
