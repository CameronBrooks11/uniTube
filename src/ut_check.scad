// ut_check — analytic validation, because CGAL is a weak oracle.
//
// Every check here runs on the IR as PURE DATA. Nothing is rendered, nothing is
// tessellated, and the answer does not depend on $fa/$fs.
//
// This exists because "Simple: yes" is necessary and nowhere near sufficient.
// Measured on this machine: an od=12 tube swept through an r=4 bend passes
// THROUGH ITSELF at the bend, and CGAL still reports `Simple: yes, Volumes: 2`
// with a plausible positive volume and zero warnings. No amount of rendering
// finds that; only arithmetic on the spine does.

// clang-format off
use <ut_core.scad>;
use <ut_math.scad>;
use <ut_path.scad>;
use <ut_profile.scad>;
// clang-format on

// The outer extremity of the profile, measured from the centreline. For a round
// section that is od/2; for an arbitrary one it is the farthest vertex.
function ut_prof_reach(prof) = max([for (q = ut_prof_outer(prof)) norm(q)]);

// The tightest curvature anywhere along a sampled chain, as the smallest
// circumradius of three consecutive points: r = abc / 4A.
//
// This is an ESTIMATE and it FAILS OPEN -- measured, it over-reads the true
// minimum radius by ~6.5% on a fast-varying curve, so a marginal case can slip
// through. It is still worth having: without it a P segment was exempt from the
// library's flagship safety assert entirely, and a self-intersecting swept helix
// rendered "Simple: yes, Volumes: 2" with zero warnings. Collinear triples give
// an infinite radius and are skipped.
function _ut_min_circumradius(p, i, acc) =
    i > len(p) - 3 ? acc
                   : let(a = norm(p[i + 1] - p[i]), b = norm(p[i + 2] - p[i + 1]), c = norm(p[i + 2] - p[i]),
                         area = norm(cross(p[i + 1] - p[i], p[i + 2] - p[i])) / 2)
                         _ut_min_circumradius(p, i + 1, area < 1e-12 ? acc : min(acc, a *b *c / (4 * area)));

// CHECK-1 — a bend radius must exceed the profile's outer reach, strictly.
// At r == reach the inner extremity of the swept surface collapses onto the bend
// axis; below it, the tube passes through itself.
function _ut_chk_bends(segs, i, reach) =
    i >= len(segs) ? true
    : (ut_seg_kind(segs[i]) == "P")
        ? let(r = _ut_min_circumradius(segs[i][1], 0, 1e18)) assert(
              r > reach + ut_eps(),
              str("CHECK-1: the tightest curvature on this sampled path has radius ", r,
                  ", which is not greater than the profile's outer reach ", reach,
                  " -- the tube passes through itself. Sampled estimate: it fails OPEN, so a marginal case can still slip through."))
              _ut_chk_bends(segs, i + 1, reach)
    : (ut_seg_kind(segs[i]) != "A")
        ? _ut_chk_bends(segs, i + 1, reach)
        : let(r = segs[i][4])
              assert(r > reach + ut_eps(),
                     str("CHECK-1: bend radius ", r, " is not greater than the profile's outer reach ", reach,
                         " -- the tube passes through itself at this bend. CGAL will still report \"Simple: yes\"."))
                  _ut_chk_bends(segs, i + 1, reach);

// CHECK-2 — a bend tighter than one full diameter is legal but ugly and hard to
// print. A warning, never an error.
function _ut_warn_tight(segs, i, od) = i >= len(segs) ? true
                                       : (ut_seg_kind(segs[i]) == "A" && segs[i][4] < od)
                                           ? echo(str("WARNING [uniTube] CHECK-2: bend radius ", segs[i][4],
                                                      " is less than one full od (", od,
                                                      ") -- legal, but tight to print")) _ut_warn_tight(segs, i + 1, od)
                                           : _ut_warn_tight(segs, i + 1, od);

// CHECK-3 — PROF-3 restated at run level: a wall below the minimum renders
// perfectly and prints as a hole.
function _ut_warn_wall(prof) = !ut_prof_thin(prof)
                                   ? true
                                   : echo(str("WARNING [uniTube] CHECK-3: wall ", ut_prof_wall(prof),
                                              " mm is below the ", ut_min_wall(),
                                              " mm minimum -- this may render perfectly and print as a hole")) true;

// Validate a run. Returns true so it can prefix an expression or sit in an
// assert. ut_tube() calls this on every render.
function ut_check(path, prof) = let(segs = ut_segs(path), reach = ut_prof_reach(prof), od = ut_prof_od(prof))
                                    _ut_chk_bends(segs, 0, reach) &&
                                _ut_warn_tight(segs, 0, is_undef(od) ? 2 * reach : od) && _ut_warn_wall(prof);
