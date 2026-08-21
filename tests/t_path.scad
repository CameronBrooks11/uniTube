// t_path — the spine IR and the frame compiler. Pure data: nothing renders.
// This whole file is only possible because the IR is data (PLAN.md §6 tier 1).

// clang-format off
use <../src/ut_core.scad>;
use <../src/ut_math.scad>;
use <../src/ut_path.scad>;
// clang-format on

// ============================================ the worked 90-degree elbow (PLAN.md §2.2)
c = [ 35, 15, 0 ];
u = [ 0, -1, 0 ];
v = [ 1, 0, 0 ];
elbow =
    ut_spine([ ut_line([ 0, 0, 0 ], [ 35, 0, 0 ]), ut_arc(c, u, v, 15, 90), ut_line([ 50, 15, 0 ], [ 50, 50, 0 ]) ]);

// The arc's endpoints and tangents, verifiable by hand with no rendering:
segA = ut_segs(elbow)[1];
assert(norm(ut_seg_p0(segA) - [ 35, 0, 0 ]) < 1e-9, "arc start = c + r*u");
assert(norm(ut_seg_p1(segA) - [ 50, 15, 0 ]) < 1e-9, "arc end = c + r*v at 90 deg");
assert(norm(ut_seg_t0(segA) - [ 1, 0, 0 ]) < 1e-9, "arc start tangent = v");
assert(norm(ut_seg_t1(segA) - [ 0, 1, 0 ]) < 1e-9, "arc end tangent = -u at 90 deg");

// EXIT CRITERION: exact developed length, no tessellation.
assert(abs(ut_length(elbow) - 93.5619449019) < 1e-9,
       str("exact developed length must be 93.5619449019, got ", ut_length(elbow)));

// ============================================ SPINE invariants must abort
// (Each of these is verified by the negative tests in `just check` rather than
// here, since an assert that fires cannot be caught inside OpenSCAD.)

// ============================================ stations
sts = ut_stations(elbow, [[ "frame", "transport" ]]);
N = len(sts);
assert(N >= 4, str("expected several stations, got ", N));

// STATION-1 — no two consecutive positions coincide (the dedupe that kills the
// coincident-point NaN in path_extrude.scad:58).
assert(min([for (i = [0:N - 2]) norm(ut_st_p(sts[i + 1]) - ut_st_p(sts[i]))]) > 1e-9,
       "STATION-1: duplicate consecutive stations");

// STATION-2 — orthonormal frames, no scale, no shear.
assert(max([for (s = sts) abs(norm(ut_st_t(s)) - 1)]) < 1e-9, "STATION-2: |t| = 1");
assert(max([for (s = sts) abs(norm(ut_st_n(s)) - 1)]) < 1e-9, "STATION-2: |n| = 1");
assert(max([for (s = sts) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "STATION-2: n must be orthogonal to t");

// STATION-3 — EXACT terminal tangents, not smoothed finite differences.
// This is what a threaded adapter is clocked against; inference measured 1.18 deg
// of skew here, which is ~0.4 mm of gap across a 20 mm flange.
assert(norm(ut_st_t(sts[0]) - [ 1, 0, 0 ]) < 1e-12, "STATION-3: first tangent must be EXACTLY [1,0,0]");
assert(norm(ut_st_t(sts[N - 1]) - [ 0, 1, 0 ]) < 1e-12, "STATION-3: last tangent must be EXACTLY [0,1,0]");

// STATION-4 — arclength starts at 0, strictly increases, ends at ut_length().
assert(abs(ut_st_s(sts[0])) < 1e-12, "STATION-4: s[0] = 0");
assert(min([for (i = [0:N - 2]) ut_st_s(sts[i + 1]) - ut_st_s(sts[i])]) > 0, "STATION-4: s strictly increasing");
assert(abs(ut_st_s(sts[N - 1]) - ut_length(elbow)) < 1e-6, "STATION-4: s[last] = exact developed length");

// STATION-5 — bounded turn between consecutive tangents.
assert(max([for (i = [0:N - 2]) ut_turn(ut_st_t(sts[i]), ut_st_t(sts[i + 1]))]) < 45, "STATION-5: bounded turn");

// EXIT CRITERION: a PLANAR bend produces EXACTLY zero twist.
// The roll reference [0,0,1] is parallel to the bend axis [0,0,1], and Rodrigues
// leaves a vector parallel to its axis invariant. docs/salvage.md §2.
assert(max([for (s = sts) norm(ut_st_n(s) - [ 0, 0, 1 ])]) < 1e-12,
       "a planar bend must produce exactly zero twist -- every normal stays [0,0,1]");

// ============================================ the frame matrix
m = ut_st_mat(sts[N - 1]);
assert(abs(m[0][3] - 50) < 1e-9 && abs(m[1][3] - 50) < 1e-9, "ut_st_mat: translation column is the position");
det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
assert(abs(det - 1) < 1e-9, str("ut_st_mat: rotation must be right-handed with det +1, got ", det));

// ============================================ a NON-planar path really does twist
// Two bends in different planes: the frame must carry roll through, and must not
// spiral. This is the case half_curvedPipe.scad existed to solve.
sp2 = ut_spine([
    ut_line([ 0, 0, 0 ], [ 30, 0, 0 ]),                                      // +X
    ut_arc_from([ 30, 20, 0 ], [ 30, 0, 0 ], [ 50, 20, 0 ], [ 0, 0, 1 ]),    // bend in XY: +X -> +Y
    ut_line([ 50, 20, 0 ], [ 50, 50, 0 ]),                                   // +Y
    ut_arc_from([ 50, 50, 20 ], [ 50, 50, 0 ], [ 50, 70, 20 ], [ 1, 0, 0 ]), // bend in YZ: +Y -> +Z
    ut_line([ 50, 70, 20 ], [ 50, 70, 60 ]),                                 // +Z, vertical: the UP-seed degeneracy
]);
s2 = ut_stations(sp2);
assert(max([for (s = s2) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "non-planar: frames stay orthonormal");
assert(abs(ut_st_s(s2[len(s2) - 1]) - ut_length(sp2)) < 1e-6, "non-planar: arclength closes");
// The final leg runs straight up (+Z), where the UP seed is degenerate. The
// fallback must keep every normal finite -- this is the NaN that killed the
// previous attempt's own flagship example.
nlast = ut_st_n(s2[len(s2) - 1]);
assert(is_num(nlast[0]) && is_num(nlast[1]) && is_num(nlast[2]), "vertical final leg must not produce NaN normals");

// ============================================ explicit twist distributes by arclength
tw = ut_stations(elbow, [[ "twist", 90 ]]);
assert(abs(_t_roll(ut_st_n(tw[0]), [ 0, 0, 1 ])) < 1e-9, "twist: zero at the start");
function _t_roll(a, b) = ut_turn(a, b);
assert(abs(_t_roll(ut_st_n(tw[len(tw) - 1]), [ 0, 0, 1 ]) - 90) < 1e-6, "twist: full 90 deg by the end");

cube(0.001); // sentinel
