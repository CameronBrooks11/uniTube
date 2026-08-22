// t_curve — the parametric frontend, and the dedupe that keeps it finite.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

// ============================================ a helix
R = 60;
T = 2;
RISE = 40;
h = ut_curve(function(t)[R * cos(360 * T * t), R *sin(360 * T * t), RISE *T *t], n = 160);

assert(len(ut_segs(h)) == 1, "a parametric curve lowers to ONE sampled segment");
assert(ut_seg_kind(ut_segs(h)[0]) == "P", "of kind P");

// A sampled segment measures CHORDS, so it under-reads the true arclength. That
// is the honest cost of an arc-native IR and it is documented, not hidden.
true_len = sqrt(pow(2 * PI * R * T, 2) + pow(RISE * T, 2));
assert(ut_length(h) < true_len, "chords are shorter than the curve");
assert((true_len - ut_length(h)) / true_len < 0.001, str("but within 0.1% at n=160: ", ut_length(h), " vs ", true_len));

// ============================================ MANDATORY dedupe
// Two coincident consecutive samples make the tangent [0,0,0], and normalising
// that is [nan,nan,nan]. This is the exact failure in path_extrude.scad:58, and
// it fires on the most obvious thing a user does: joining two pieces that share
// an endpoint.
flat = ut_curve(function(t)[t < 0.5 ? 20 * t : 10, 0, 0], n = 20);
assert(abs(ut_length(flat) - 10) < 1e-9, str("the repeated tail collapses to one point, got ", ut_length(flat)));
fsts = ut_stations(flat);
assert(min([for (i = [0:len(fsts) - 2]) norm(ut_st_p(fsts[i + 1]) - ut_st_p(fsts[i]))]) > 1e-9,
       "STATION-1: no duplicate stations survive");
assert(max([for (s = fsts) is_num(ut_st_t(s)[0]) ? 0 : 1]) == 0, "and no tangent is NaN");

// ============================================ exact tangents when dfdt is given
// ONLY the direction of dfdt is used, but the RELATIVE SCALING of its components
// matters: OpenSCAD trig is in DEGREES, so d/dt cos(360*k*t) = -2*PI*k*sin(...).
// Dropping the 2*PI leaves every tangent ~6 degrees out while looking plausible.
he = ut_curve(function(t)[R * cos(360 * T * t), R *sin(360 * T * t), RISE *T *t],
              dfdt = function(t)[-2 * PI * T * R * sin(360 * T * t), 2 * PI *T *R *cos(360 * T * t), RISE *T], n = 160);
ae = ut_stations(he);
ac = ut_stations(h);
m = floor(len(ae) / 2);

// IN THE INTERIOR central differences are second-order accurate and agree with
// the analytic tangent almost exactly -- measured 0.006 deg at n=160.
assert(ut_turn(ut_st_t(ae[m]), ut_st_t(ac[m])) < 0.05,
       str("interior tangents should agree closely, got ", ut_turn(ut_st_t(ae[m]), ut_st_t(ac[m]))));

// AT THE ENDS a two-point chord would be FIRST order -- its error is about half
// a sample's rotation (2.24 deg at n=160 here). _ut_central uses a THREE-POINT
// one-sided difference instead, which is second order like the interior.
// Measured: 8.949 -> 0.460 at n=40, 2.237 -> 0.0141 at n=160.
err0 = ut_turn(ut_st_t(ae[0]), ut_st_t(ac[0]));
assert(err0 < 0.05, str("the END tangent must be second order too, got ", err0, " deg"));

// And it really is second order: quartering n's step should quarter... quarter
// the error. Compare n=80 against n=160 on the same curve.
c80 = ut_stations(ut_curve(function(t)[R * cos(360 * T * t), R *sin(360 * T * t), RISE *T *t], n = 80));
e80 = ut_turn(ut_st_t(c80[0]), ut_st_t(ae[0]));
assert(e80 > err0 * 3, str("halving n should roughly quadruple the end error; got ", e80, " vs ", err0));

// WHICH IS WHY dfdt MATTERS MOST FOR PORTS. STATION-3 wants exact terminal
// tangents, and a port frame 2.2 degrees out is ~0.8 mm of gap across a 20 mm
// flange. On a sampled path, supplying dfdt is how you get that back.
assert(abs(ut_st_t(ae[0])[0]) < 1e-9, "with dfdt the start tangent is exact: no X component at t=0");

// ============================================ frames over a sampled path
assert(max([for (s = ut_stations(h)) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "frames stay orthonormal");
assert(max([for (s = ut_stations(h)) abs(norm(ut_st_n(s)) - 1)]) < 1e-9, "and unit");

cube(0.001); // sentinel
