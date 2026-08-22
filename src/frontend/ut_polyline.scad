// ut_polyline — the incumbent frontend: waypoints plus per-vertex fillet radii.
//
// The arithmetic is reference/axford/curvedPipe.scad:71-105 verbatim -- the one
// unambiguously correct piece of the old library (docs/salvage.md §1) -- plus
// the three guards it never had. Those guards are the whole point: each of the
// three inputs below used to produce WRONG GEOMETRY SILENTLY.

// clang-format off
use <../ut_core.scad>;
use <../ut_math.scad>;
use <../ut_path.scad>;
// clang-format on

// r may be a scalar (applied to interior vertices only), a list of len(pts)
// (indexed by vertex, ends ignored), or a list of len(pts)-2 (interior only --
// the legacy `radii` spelling).
function _ut_r_at(r, k, n) = is_num(r) ? r : len(r) == n ? r[k] : r[k - 1];

function ut_polyline(pts, r = 0, closed = false, frame = "transport", normal = undef,
                     twist = 0) = assert(len(pts) >= 2, "ut_polyline(): need at least 2 points")
    // FIRST-USE GUARDS. Both of these used to surface from deep inside the math,
    // naming the wrong cause entirely.
    assert(
        _ut_all3d(pts, 0),
        "ut_polyline(): every waypoint must be a 3-vector [x,y,z]. A 2D point reaches cross() and reports only \"atan2() parameter could not be converted\".")
        assert(
            _ut_nodup(pts, 1),
            "ut_polyline(): two consecutive waypoints are identical -- remove the duplicate. The leg has no direction, and the failure otherwise surfaces as a SPINE-3 tangent discontinuity naming the wrong cause.")
            assert(is_num(r) || len(r) == len(pts) || len(r) == len(pts) - 2,
                   str("ut_polyline(): r must be a scalar, or a list of ", len(pts), " or ", len(pts) - 2,
                       " values")) assert(closed == false, "ut_polyline(): closed paths land in a later phase")
                let(n = len(pts), dirs = [for (i = [0:n - 2]) pts[i + 1] - pts[i]], lens = [for (d = dirs) norm(d)],
                    // vertex-indexed; ends are 0
                    angs = [for (k = [0:n - 1])(k == 0 || k == n - 1) ? 0
                                                                      : _ut_defl(dirs[k - 1], dirs[k], k, pts, r, n)],
                    insets = [for (k = [0:n - 1]) angs[k] < ut_eps() ? 0 : _ut_r_at(r, k, n) * tan(angs[k] / 2)],
                    ok = _ut_fits(lens, insets, 0, pts, r))
                    ut_spine([for (i = [0:n - 2]) each concat(_ut_leg(pts, dirs, lens, insets, i),
                                                              (i < n - 2 && angs[i + 1] >= ut_eps())
                                                                  ? [_ut_bend(pts, dirs, insets, angs, i + 1, r, n)]
                                                                  : [])],
                             false,
                             concat([ [ "frame", frame ], [ "twist", twist ] ],
                                    is_undef(normal) ? [] : [[ "normal", normal ]]));

// GUARD 1 and 2 -- the deflection angle, with the two degeneracies that used to
// vanish silently. A 180 deg doubleback gives tan(90) = inf and [nan,nan,nan];
// a collinear waypoint with r>0 gives a NaN arc centre.
function _ut_defl(d1, d2, k, pts, r, n) = let(a = ut_turn(d1, d2))
    assert(a < 180 - 1e-6,
           str("ut_polyline(): 180 degree reversal at vertex ", k, " ", pts[k],
               " -- a path cannot double back on itself (tan(90) is inf, and the segment would silently vanish)"))
    // ADR 0004: r=0 at an interior vertex is an ERROR, not a mitre. The
    // DEFAULT is r=0, so the most natural first call lands here -- and used
    // to report "Invalid value (NaN) in parameter vector for cross()".
    assert(
        a<ut_eps() || _ut_r_at(r, k, n)> ut_eps(),
        str("ut_polyline(): vertex ", k, " at ", pts[k], " turns ", a,
            " degrees but its fillet radius is 0. A sharp corner cannot be swept by an orthonormal frame (ADR 0004) -- give it a radius, or remove the vertex."))
        a;

// GUARD 3 -- the overlap bug. Verified: the same path at radii [20,20] renders
// genus 1 and at [80,80] on a 100 mm leg renders GENUS 2 -- an extra through-hole
// -- with zero diagnostics, because OpenSCAD emits nothing for a non-positive
// extrusion height. ERROR, never "scale to fit": on a doubleback that rule
// scales the radius to exactly 0, which is itself NaN. See PLAN.md §9.5.
function _ut_fits(lens, insets, i, pts,
                  r) = i >= len(lens)
                           ? true
                           : let(need = insets[i] + insets[i + 1], have = lens[i])
                                 assert(have - need > -ut_eps(),
                                        str("ut_polyline(): fillet radii do not fit on the leg from ", pts[i], " to ",
                                            pts[i + 1], " -- leg is ", have, " mm but the two bends need ", need,
                                            " mm of tangent length (", insets[i], " + ", insets[i + 1],
                                            "). Reduce the radius at one of those vertices."))
                                     _ut_fits(lens, insets, i + 1, pts, r);

// The trimmed straight. Omitted entirely when two bends are exactly tangent.
function _ut_leg(pts, dirs, lens, insets, i) = let(u = ut_unit(dirs[i]), a = pts[i] + insets[i] * u,
                                                   b = pts[i + 1] - insets[i + 1] * u,
                                                   rem = lens[i] - insets[i] - insets[i + 1]) rem
                                                       > ut_eps()
                                                   ? [ut_line(a, b)]
                                                   : [];

// The arc at an interior vertex. The centre lies along the internal bisector at
// r / cos(ang/2) from the vertex; see docs/salvage.md §1 for the derivation.
function _ut_bend(pts, dirs, insets, angs, k, r,
                  n) = let(u1 = ut_unit(dirs[k - 1]), u2 = ut_unit(dirs[k]), ang = angs[k], rad = _ut_r_at(r, k, n),
                           tin = pts[k] - insets[k] * u1, axis = ut_unit(cross(dirs[k - 1], dirs[k])),
                           c = pts[k] + ut_unit(u2 - u1) * (rad / cos(ang / 2)), uu = ut_unit(tin - c),
                           vv = cross(axis, uu)) ut_arc(c, uu, vv, rad, ang);

function _ut_all3d(p, i) = i >= len(p) ? true : (is_list(p[i]) && len(p[i]) == 3) && _ut_all3d(p, i + 1);
function _ut_nodup(p, i) = i >= len(p) ? true : (norm(p[i] - p[i - 1]) > ut_eps()) && _ut_nodup(p, i + 1);
