// ut_curve — an arbitrary parametric centreline.
//
//     ut_curve(function(t) [80 * cos(360 * t), 80 * sin(360 * t), 60 * t], n = 180)
//
// The only frontend that expresses helices, coils, serpentines and generated or
// optimised routes. It subsumes reference/proto/sweep_path.scad's entire idea
// without adding list-comprehension-demos, which has been dormant since 2022 and
// ships with NO LICENCE FILE AT ALL.
//
// HONEST COST, stated rather than discovered: a `P` segment forfeits exact
// arclength, exact transport and the bend-radius check. That is the price of an
// arc-native IR, and users whose primary case is organic paths should know the
// design is optimised against them. The honest upgrade is a BIARC FITTER --
// approximate each span by a pair of tangent-continuous arcs to a tolerance,
// emitting real ["A"] segments and restoring all three. PLAN.md §10.

// clang-format off
use <../ut_core.scad>;
use <../ut_math.scad>;
use <../ut_path.scad>;
// clang-format on

// `f` is a function literal of one parameter. `dfdt`, when supplied, gives EXACT
// tangents; otherwise they come from central differences.
//
// ONLY THE DIRECTION of dfdt is used, but the RELATIVE SCALING of its components
// matters, and that is where it is easy to go wrong: OpenSCAD's trig takes
// DEGREES, so
//     d/dt cos(360*k*t)  =  -2*PI*k * sin(360*k*t)
// and dropping the 2*PI leaves a helix's tangent 6 degrees out at every sample --
// measured, while looking perfectly plausible. When in doubt omit dfdt and let
// central differences do it.
function ut_curve(f, t = [ 0, 1 ], n = 100, dfdt = undef, frame = "transport", normal = undef,
                  twist = 0) = assert(is_function(f),
                                      "ut_curve(): f must be a function literal, e.g. function(t) [t, 0, 0]")
    assert(n >= 2, str("ut_curve(): n must be at least 2, got ", n))
        let(ts0 = [for (k = [0:n]) t[0] + (t[1] - t[0]) * k / n], ps0 = [for (tv = ts0) f(tv)],
            // Dedupe returns INDICES, so the surviving samples keep their own
            // parameter values. Mapping index -> t after the fact is wrong the
            // moment a single sample is dropped.
            keep = _ut_keep(ps0, 1, [0]), pts = [for (i = keep) ps0[i]],
            ts = [for (i = keep) ts0[i]]) assert(len(pts) >= 2, "ut_curve(): every sample collapsed to one point")
            ut_spine([ut_sampled(pts, is_undef(dfdt) ? _ut_central(pts) : [for (tv = ts) ut_unit(dfdt(tv))])], false,
                     concat([ [ "frame", frame ], [ "twist", twist ] ],
                            is_undef(normal) ? [] : [[ "normal", normal ]]));

// MANDATORY dedupe, returning the indices that survive. Two coincident
// consecutive samples make the tangent [0,0,0], and normalising that is
// [nan,nan,nan]. This is the exact failure in
// reference/gringer/path_extrude.scad:58, and it fires on the single most
// obvious thing a user does: concatenating two path pieces that share an
// endpoint. STATION-1 depends on it.
function _ut_keep(p, i, acc) = i >= len(p)
                                   ? acc
                                   : _ut_keep(p, i + 1,
                                              norm(p[i] - p[acc[len(acc) - 1]]) > ut_eps() ? concat(acc, [i]) : acc);

// Central differences on the DEDUPED points, so a repeated sample cannot poison
// a neighbour.
//
// THE ENDS USE A THREE-POINT ONE-SIDED DIFFERENCE, not a chord. A two-point end
// estimate is FIRST order -- its error is about half a sample's rotation, and it
// is the only error in a sampled path large enough to make a physical part
// wrong: STATION-3 says the ends are where port frames come from, and 2.2 deg
// across a 20 mm flange is ~0.8 mm of gap. Measured on a 2-turn helix:
//
//     n     2-point (chord)   3-point one-sided
//     40        8.949 deg         0.460 deg
//     80        4.475             0.0731
//     160       2.237             0.0141      <- 159x better, for one line
//     320       1.119             0.0032
//
// The two-point estimate halves with n; this one quarters. Second order at both
// ends and in the interior.
function _ut_central(p) = let(m = len(p) - 1)[for (i = [0:m]) ut_unit(m < 2 ? (i == 0 ? p[1] - p[0] : p[m] - p[m - 1])
                                                                      : i == 0 ? -3 * p[0] + 4 * p[1] - p[2]
                                                                      : i == m ? 3 * p[m] - 4 * p[m - 1] + p[m - 2]
                                                                               : p[i + 1] - p[i - 1])];
