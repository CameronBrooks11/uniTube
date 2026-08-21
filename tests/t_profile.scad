// t_profile — the cross-section and the lumen. Pure data.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

// --- od / id / wall are three spellings of one profile -----------------------
a = ut_round(od = 12, id = 8);
b = ut_round(od = 12, wall = 2);
c = ut_round(id = 8, wall = 2);
assert(abs(ut_prof_od(a) - 12) < 1e-9 && abs(ut_prof_id(a) - 8) < 1e-9, "ut_round(od,id)");
assert(abs(ut_prof_wall(a) - 2) < 1e-9, "ut_round(od,id): wall is derived");
assert(abs(ut_prof_id(b) - 8) < 1e-9, "ut_round(od,wall): id is derived");
assert(abs(ut_prof_od(c) - 12) < 1e-9, "ut_round(id,wall): od is derived");
assert(len(ut_prof_outer(a)) == len(ut_prof_outer(b)), "all three spellings agree on facet count");

// --- PROF-1: winding ---------------------------------------------------------
assert(ut_area2d(ut_prof_outer(a)) > 0, "PROF-1: outer is CCW");
assert(ut_area2d(ut_prof_inner(a)) > 0, "PROF-1: inner is ALSO CCW -- the emitter orients it, not the profile");

// --- PROF-2: correspondence (ADR 0006) ---------------------------------------
o = ut_prof_outer(a);
i = ut_prof_inner(a);
assert(len(o) == len(i), "PROF-2: equal point count");
assert(max([for (k = [0:len(o) - 1]) abs(atan2(o[k][1], o[k][0]) - atan2(i[k][1], i[k][0]))]) < 1e-6,
       "PROF-2: outer[k] and inner[k] sit at the same polar angle");

// --- the three regions -------------------------------------------------------
assert(len(ut_solid_rgn(a)) == 2, "solid region = outer + bore");
assert(len(ut_shell_rgn(a)) == 1, "shell region = outer only");
assert(len(ut_bore_rgn(a)) == 1, "bore region = the lumen as a POSITIVE solid");
rod = ut_rod(d = 10);
assert(!ut_prof_hollow(rod), "a rod has no lumen");
assert(len(ut_bore_rgn(rod)) == 0, "a rod's bore region is empty -- callers must guard on this");

// --- PROF-3: thin wall is a WARNING, not an error ----------------------------
assert(ut_prof_thin(ut_round(od = 10, id = 8)), "PROF-3: a 1 mm wall is below the minimum");
assert(!ut_prof_thin(ut_round(od = 12, wall = 2)), "PROF-3: a 2 mm wall is fine");

// --- an arbitrary hollow section: square bore in a round shell ---------------
// Sampled BY ANGLE, which is what makes it correspondence-aligned. Sampling the
// square by perimeter instead satisfies the count rule, self-intersects the end
// caps, and CGAL reports only "assertion violation" (ADR 0006).
function sq_by_angle(h, n) = [for (k = [0:n - 1])
        let(t = 360 * k / n, cx = cos(t), cy = sin(t), m = h / max(abs(cx), abs(cy)))[m * cx, m *cy]];
N = len(ut_prof_outer(a));
sqp = ut_profile(ut_ring(6, N), sq_by_angle(3, N), [[ "kind", "square-bore" ]]);
assert(len(ut_solid_rgn(sqp)) == 2, "arbitrary hollow section is a first-class profile");

cube(0.001); // sentinel
