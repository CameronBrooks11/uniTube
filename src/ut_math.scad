// ut_math — the handful of functions that replace 1035 lines of vendored
// maths.scad and vector.scad. See docs/salvage.md §5.

// clang-format off
use <ut_core.scad>;
// clang-format on

function ut_unit(v) = v / norm(v);

// The angle between two 3D vectors, in degrees, ALWAYS via atan2.
// 3D only: cross() requires 3-vectors. For planar angles use atan2(y, x).
// NEVER acos: acos(1.0000001) is nan on OpenSCAD 2021.01 and near-collinear
// waypoints are the most common input there is. See AGENTS.md rule 7.
function ut_turn(a, b) = atan2(norm(cross(a, b)), a *b);

// Rodrigues' rotation of v about unit axis k by ang degrees.
// This is reference/axford/half_curvedPipe.scad:19, generalised. docs/salvage.md §2.
function ut_rotv(v, ang, k) = v * cos(ang) + cross(k, v) * sin(ang) + k * (k * v) * (1 - cos(ang));

// Project ref orthogonal to t and normalise -- the roll-reference seed.
// Falls back from UP to BACK when the run starts parallel to ref, which is the
// vertical-tangent NaN that has killed every previous attempt at this.
function ut_ref_fallback(t, ref = undef) = let(r0 = is_undef(ref) ? ut_up() : ref, tu = ut_unit(t),
                                               r = norm(cross(tu, r0)) < 1e-6
                                                       ? (norm(cross(tu, ut_back())) < 1e-6 ? [ 1, 0, 0 ] : ut_back())
                                                       : r0) ut_unit(r - tu * (r * tu));

// Re-orthogonalise n against t, preserving n's direction as closely as possible.
function ut_ortho(t, n) = let(tu = ut_unit(t), p = n - tu * (n * tu)) ut_unit(p);

// OpenSCAD's own $fn/$fa/$fs rule, applied per-radius and scaled to a partial
// sweep. This is why an arc-native IR gives better meshes than a sampled one:
// each bend gets facets from ITS OWN radius.
function ut_fragments(r, ang = 360) = let(full = $fn > 0 ? max($fn, 3) : ceil(max(min(360 / $fa, r * 2 * PI / $fs), 5)))
    max(2, ceil(full *abs(ang) / 360));

// A closed CCW polygon of n points on a circle of radius r, sampled by ANGLE.
// Angle-sampling is what makes two loops correspondence-aligned (PROF-2 /
// ADR 0006); sampling by arclength does not, and self-intersects the end caps.
function ut_ring(r, n, a0 = 0) = [for (i = [0:n - 1]) let(a = a0 + 360 * i / n)[r * cos(a), r *sin(a)]];

// Signed area of a 2D polygon. Positive = counter-clockwise.
function ut_area2d(poly) = let(n = len(poly)) 0.5 * _ut_area_sum(poly, n, 0);
function _ut_area_sum(p, n, i) = i >= n ? 0
                                        : (p[i][0] * p[(i + 1) % n][1] - p[(i + 1) % n][0] * p[i][1]) +
                                              _ut_area_sum(p, n, i + 1);

// Volume of a closed triangulated mesh by the divergence theorem.
// Replaces BOSL2's vnf_volume(). Verified exact to 6 s.f. against analytic
// values in Phase 0 -- see ADR 0001.
function ut_volume(pts, faces) = _ut_vol(pts, faces, 0);
function _ut_vol(P, F, i) = i >= len(F) ? 0 : _ut_face_vol(P, F[i]) + _ut_vol(P, F, i + 1);
function _ut_face_vol(P, f) = _ut_fan(P, f, 1);
function _ut_fan(P, f, k) = k > len(f) - 2 ? 0 : (P[f[0]] * cross(P[f[k]], P[f[k + 1]])) / 6 + _ut_fan(P, f, k + 1);
