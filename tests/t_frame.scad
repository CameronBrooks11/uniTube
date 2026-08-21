// t_frame — roll policy. The requirement half_curvedPipe.scad discovered
// (docs/salvage.md §2), now expressed as two policy strings.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

// A path with two bends in DIFFERENT planes -- the case where a naively derived
// frame spirals and a split seam would wander around the tube.
sp = ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ], [ 40, 40, 0 ], [ 40, 40, 40 ] ], r = 12);

// --- transport (default): rotation-minimizing -------------------------------
tr = ut_stations(sp, [[ "frame", "transport" ]]);
assert(max([for (s = tr) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "transport: n stays orthogonal to t");
assert(max([for (s = tr) abs(norm(ut_st_n(s)) - 1)]) < 1e-9, "transport: n stays unit");
// STATION-6: the frame never flips -- consecutive normals differ by < 90 deg.
assert(max([for (i = [0:len(tr) - 2]) ut_turn(ut_st_n(tr[i]), ut_st_n(tr[i + 1]))]) < 90,
       "STATION-6: continuous roll, no frame flip");

// --- fixed: the seam is pinned to a WORLD direction --------------------------
// Stronger than transport for a printable split conduit: transport only stops
// the seam spiralling relative to the TUBE, but a printed part has a
// gravity-relative requirement.
fx = ut_stations(sp, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]);
assert(max([for (s = fx) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "fixed: n stays orthogonal to t");
// Every normal is UP projected into the station's plane, so on any station whose
// tangent is horizontal the normal is exactly UP.
horiz = [for (s = fx) if (abs(ut_st_t(s)[2]) < 1e-9) s];
assert(len(horiz) > 0, "expected some horizontal stations");
assert(max([for (s = horiz) norm(ut_st_n(s) - [ 0, 0, 1 ])]) < 1e-9, "fixed: horizontal stations point exactly UP");

// --- the vertical-tangent degeneracy -----------------------------------------
// The final leg runs straight up, where UP is parallel to the tangent and the
// projection is undefined. The UP->BACK fallback must keep everything finite.
vlast = ut_st_n(fx[len(fx) - 1]);
assert(is_num(vlast[0]) && is_num(vlast[1]) && is_num(vlast[2]),
       "fixed: a vertical run must not produce NaN -- this killed the previous attempt's own example");
assert(abs(norm(vlast) - 1) < 1e-9, "fixed: still a unit vector on a vertical run");

// --- an explicit per-station normal list --------------------------------------
n = len(tr);
manual = ut_stations(sp, [[ "frame", [for (i = [0:n - 1])[0, 0, 1]] ]]);
assert(len(manual) == n, "manual policy preserves station count");
assert(max([for (s = manual) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "manual: projected orthogonal to t");

cube(0.001); // sentinel
