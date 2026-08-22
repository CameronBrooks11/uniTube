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
//
// THIS PATH IS NOT `sp`. `sp` finishes by running straight up, and a seam pinned
// to UP has no defined direction where the axis points along UP -- see below.
spf = ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ], [ 40, 40, 0 ], [ 70, 40, 25 ] ], r = 12);
fx = ut_stations(spf, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]);
assert(max([for (s = fx) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "fixed: n stays orthogonal to t");
// Every normal is UP projected into the station's plane, so on any station whose
// tangent is horizontal the normal is exactly UP.
horiz = [for (s = fx) if (abs(ut_st_t(s)[2]) < 1e-9) s];
assert(len(horiz) > 0, "expected some horizontal stations");
assert(max([for (s = horiz) norm(ut_st_n(s) - [ 0, 0, 1 ])]) < 1e-9, "fixed: horizontal stations point exactly UP");

// --- the vertical-tangent degeneracy -----------------------------------------
// THIS SECTION USED TO ASSERT THE WRONG PROPERTY, and that is how a 174-degree
// seam flip shipped in examples/05 for the whole life of the library.
//
// It ran `sp` -- whose final leg goes straight up -- through frame="fixed", and
// checked that the result was FINITE. It is finite: ut_ref_fallback() swaps UP
// for BACK when the tangent is parallel to UP, so nothing is NaN. But finite is
// not the requirement. The fallback is a hard switch, so applying it PER STATION
// makes it a DISCONTINUITY: the seam jumped 174 degrees in a single 6-degree
// step, the mesh stayed manifold, CGAL said Simple: yes, and every gate passed.
//
// The right answer is that the ask is undefined, not that it is finite. A
// vertical pipe has no upward-facing side. ut_stations() refuses it now, and
// tests/guards/g_fixed_vertical.scad is that refusal, watched to fire.
//
// ut_ref_fallback IS still correct for what it was written for: seeding a
// transport frame ONCE on a run that starts vertical. Used once there is no
// discontinuity to create, and that is what is asserted here.
vert = ut_stations(ut_polyline([ [ 0, 0, 0 ], [ 0, 0, 60 ] ]));
vn = ut_st_n(vert[0]);
assert(
    is_num(vn[0]) && is_num(vn[1]) && is_num(vn[2]),
    "transport: a run that STARTS vertical must not seed a NaN frame -- this killed the previous attempt's own example");
assert(abs(norm(vn) - 1) < 1e-9, "transport: the seeded normal is still a unit vector");
assert(abs(vn *ut_st_t(vert[0])) < 1e-9, "transport: and still orthogonal to a vertical tangent");

// --- an explicit per-station normal list --------------------------------------
// Again NOT `sp`: an all-UP list on a run that finishes vertical leaves nothing
// after projection, and ut_ortho() returned [nan, nan, nan] SILENTLY. The assert
// below is the one that was supposed to catch it and did not -- OpenSCAD's max()
// drops nan, so it measured 2.22e-16 on a frame list ending in nan and passed.
// Orthogonality is now checked per station with an explicit is_num, and
// ut_stations() refuses the degenerate list outright
// (tests/guards/g_frame_list_parallel.scad).
nf = len(ut_stations(spf));
manual = ut_stations(spf, [[ "frame", [for (i = [0:nf - 1])[0, 0, 1]] ]]);
assert(len(manual) == nf, "manual policy preserves station count");
assert(len([for (s = manual) if (!is_num(ut_st_n(s)[0]) || !is_num(ut_st_n(s)[1]) || !is_num(ut_st_n(s)[2])) 1]) == 0,
       "manual: no station frame may contain nan -- max() cannot see this, so count it instead");
assert(max([for (s = manual) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "manual: projected orthogonal to t");

// ============================================ STATION-6, now enforced
// "Continuous roll -- the frame never flips" was documented from Phase 1 and
// never checked. The measure is the roll step IN EXCESS of the tangent step:
// parallel transport turns the normal exactly as much as the tangent, so the
// excess is 0 by construction, and a fixed frame measures 0 to 1e-13.
function _excess(sts) = max([for (i = [1:len(sts) - 1]) ut_turn(ut_st_n(sts[i]), ut_st_n(sts[i - 1])) -
                             ut_turn(ut_st_t(sts[i]), ut_st_t(sts[i - 1]))]);

s6 = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 40, 0 ], [ 100, 40, 30 ] ], r = 18);
assert(_excess(ut_stations(s6)) < 1e-9, "STATION-6: transport never outruns the tangent");
assert(_excess(ut_stations(s6, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ])) < 1e-9,
       str("STATION-6: a fixed frame away from its own axis is smooth, got ",
           _excess(ut_stations(s6, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]))));
// twist is DECLARED intent distributed by arclength, not a flip, and the check
// runs on the pre-twist normals so it cannot be tripped by asking for one.
assert(len(ut_stations(s6, [[ "twist", 720 ]])) > 2, "a large declared twist is not a flip");

// A fixed frame stays smooth right up to 1 degree from its own reference axis --
// the failure is a cliff AT the axis, not gradual ill-conditioning, which is why
// _ut_fixed_ok refuses only the genuinely undefined ask.
near = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 61.05, 0, 60 ] ], r = 15);
assert(min([for (st = ut_stations(near, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ]))
               let(a = ut_turn(ut_st_t(st), [ 0, 0, 1 ])) min(a, 180 - a)]) < 2,
       "this path really does come within 2 degrees of vertical");
assert(_excess(ut_stations(near, [ [ "frame", "fixed" ], [ "normal", [ 0, 0, 1 ] ] ])) < 1e-9,
       "and the fixed frame is still smooth there");

cube(0.001); // sentinel
