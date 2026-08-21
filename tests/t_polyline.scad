// t_polyline — the incumbent frontend and its three guards.
// The guards themselves ABORT, so they cannot be asserted from inside OpenSCAD:
// they are exercised by tests/guards/ via `just guards`.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

// --- the worked elbow lowers to L, A, L --------------------------------------
p = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 15);
segs = ut_segs(p);
assert(len(segs) == 3, str("elbow should lower to 3 segments, got ", len(segs)));
assert(ut_seg_kind(segs[0]) == "L" && ut_seg_kind(segs[1]) == "A" && ut_seg_kind(segs[2]) == "L", "L, A, L");
assert(abs(ut_length(p) - 93.5619449019) < 1e-9, "exact developed length");

// The inset math: inset = r*tan(ang/2) = 15*tan(45) = 15, so the first leg is
// trimmed from 50 mm to 35 mm. docs/salvage.md §1.
assert(abs(ut_seg_len(segs[0]) - 35) < 1e-9, str("leg trimmed by the tangent length, got ", ut_seg_len(segs[0])));
assert(norm(ut_seg_p1(segs[0]) - [ 35, 0, 0 ]) < 1e-9, "tangent point at 35 mm");

// The arc centre lies on the internal bisector at r/cos(ang/2) from the vertex.
assert(norm(segs[1][1] - [ 35, 15, 0 ]) < 1e-9, str("arc centre should be [35,15,0], got ", segs[1][1]));

// --- a straight run with no interior vertices --------------------------------
// BOSL2's round_corners hard-asserts on a 2-point path; ours must not, because a
// plain straight pipe is the trunk of every manifold.
straight = ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ] ]);
assert(len(ut_segs(straight)) == 1, "a 2-point path is one straight segment");
assert(abs(ut_length(straight) - 40) < 1e-9, "straight length");

// --- a scalar radius applies to INTERIOR vertices only -----------------------
sc = ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ], [ 0, 50, 0 ] ], r = 10);
assert(len([for (s = ut_segs(sc)) if (ut_seg_kind(s) == "A") 1]) == 2, "2 interior vertices -> 2 arcs");

// --- GUARD 2, benign half: a collinear waypoint MERGES rather than NaN --------
col = ut_polyline([ [ 0, 0, 0 ], [ 25, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 10);
assert(len([for (s = ut_segs(col)) if (ut_seg_kind(s) == "A") 1]) == 1,
       "a collinear waypoint must emit NO arc -- an arc there has a NaN centre");
assert(abs(ut_length(col) - ut_length(ut_polyline([ [ 0, 0, 0 ], [ 50, 0, 0 ], [ 50, 50, 0 ] ], r = 10))) < 1e-9,
       "the collinear waypoint changes nothing about the geometry");

// --- exactly-tangent bends: the zero-length straight is omitted --------------
// This is not an error; it is an S-bend with no straight between the arcs.
tang = ut_polyline([ [ 0, 0, 0 ], [ 100, 0, 0 ], [ 100, 100, 0 ], [ 0, 100, 0 ] ], r = 50);
assert(len([for (s = ut_segs(tang)) if (ut_seg_kind(s) == "L" && ut_seg_len(s) < 1e-9) 1]) == 0,
       "no degenerate zero-length straights are emitted");

// --- the legacy demo path lowers cleanly -------------------------------------
legacy = ut_polyline(
    [
        [ 0, 0, 0 ], [ 100, 0, 0 ], [ 100, 100, 0 ], [ 50, 100, 100 ], [ 50, 100, 150 ], [ 0, 100, 50 ], [ 0, 0, 0 ],
        [ 50, 0, 50 ]
    ],
    r = [ 70, 30, 30, 6, 50, 30 ]);
assert(len(ut_segs(legacy)) == 12, str("legacy demo lowers to 12 segments, got ", len(ut_segs(legacy))));
assert(len([for (s = ut_segs(legacy)) if (ut_seg_kind(s) == "A") 1]) == 6,
       "all SIX bends must be present -- they have rendered as nothing since 2025-01-10");

cube(0.001); // sentinel
