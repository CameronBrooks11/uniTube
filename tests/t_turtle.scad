// t_turtle — THE FALSIFICATION TEST for the two-level IR (ADR 0002, PLAN.md §7).
//
// The rule, stated in advance: if the turtle does not fall out of the spine
// cleanly -- if the spine has to grow a case, or the turtle reimplements any
// frame or tessellation logic -- the spine layer gets DELETED in favour of a
// bare station list, not defended.
//
// It fell out cleanly. No core module changed, and neither new frontend
// references ut_fragments, ut_ref_fallback, ut_ortho or ut_stations at all.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

// ============================================ hand-verified geometry
// start [0,0,0], dir +X, up +Z:
//   feed 60      -> [60,0,0]
//   bend 90 r24  -> centre [60,0,24], end [84,0,24], dir +Z, up -X
//   feed 40      -> [84,0,64]
//   roll 90      -> up = -Y   (NO geometry emitted)
//   bend 45 r24  -> centre [84,-24,64], end [84,-7.0294,80.9706]
//   feed 30      -> [84,-28.2426407,102.1837662]
p = ut_turtle([
    [ "feed", 60 ], [ "bend", 90, "r", 24 ], [ "feed", 40 ], [ "roll", 90 ], [ "bend", 45, "r", 24 ], [ "feed", 30 ]
]);

segs = ut_segs(p);
assert(len(segs) == 5, str("expected L,A,L,A,L -- got ", len(segs), " segments"));
assert([for (s = segs) ut_seg_kind(s)] == [ "L", "A", "L", "A", "L" ], "roll emits NO segment of its own");

// Exact developed length: 60 + quarter-arc(24) + 40 + eighth-arc(24) + 30.
expect_len = 60 + (90 / 360) * 2 * PI * 24 + 40 + (45 / 360) * 2 * PI * 24 + 30;
assert(abs(ut_length(p) - expect_len) < 1e-9, str("developed length ", ut_length(p), " != ", expect_len));

// The end point, hand-derived above.
sts = ut_stations(p);
endp = ut_st_p(sts[len(sts) - 1]);
assert(norm(endp - [ 84, -28.2426406871, 102.1837661841 ]) < 1e-6, str("end point ", endp));

// The first bend's arc, verifiable by hand with no rendering.
a1 = segs[1];
assert(norm(a1[1] - [ 60, 0, 24 ]) < 1e-9, "first arc centre is r along `up` from the bend point");
assert(norm(ut_seg_t0(a1) - [ 1, 0, 0 ]) < 1e-9, "arc enters along the incoming heading");
assert(norm(ut_seg_t1(a1) - [ 0, 0, 1 ]) < 1e-9, "and leaves bent 90 degrees toward `up`");

// ============================================ roll changes the PATH, not the IR
// Same commands without the roll: the second bend stays in the first plane, so
// the part is a different SHAPE -- but the spine still carries no roll field.
flat = ut_turtle([ [ "feed", 60 ], [ "bend", 90, "r", 24 ], [ "feed", 40 ], [ "bend", 45, "r", 24 ], [ "feed", 30 ] ]);
assert(abs(ut_length(flat) - ut_length(p)) < 1e-9, "roll costs no length");
assert(norm(ut_st_p(ut_stations(flat)[len(ut_stations(flat)) - 1]) - endp) > 1,
       "but it genuinely moves the end of the path -- roll is geometry, consumed by the frontend");
// SPINE-5: nothing in either spine records a roll.
assert(len(ut_segs(p)[1]) == 6, "an arc is [kind, c, u, v, r, ang] -- six fields, none of them roll");

// ============================================ bends over 180 degrees are SPLIT
// SPINE-4 caps one arc at 180 so the tangent sign can never be ambiguous.
// Splitting is the FRONTEND's job; the spine does not grow a case for it.
coil = ut_turtle([ [ "feed", 10 ], [ "bend", 270, "r", 20 ], [ "feed", 10 ] ]);
arcs = [for (s = ut_segs(coil)) if (ut_seg_kind(s) == "A") s];
assert(len(arcs) == 2, str("a 270 degree bend splits into 2 arcs, got ", len(arcs)));
assert(max([for (s = arcs) s[5]]) <= 180 + 1e-9, "and neither exceeds 180");
assert(abs(ut_length(coil) - (10 + (270 / 360) * 2 * PI * 20 + 10)) < 1e-9, "the split preserves total length");

// The split rebuilds the command list around the bend, and BOTH slices used to
// be unguarded. OpenSCAD silently reverses a descending range -- [0:-1] is
// [-1, 0] -- so a >180 bend as the FIRST or LAST command spliced garbage into
// the program and aborted with `unknown command "undef"`, naming the wrong
// cause. Neither boundary was covered: the case above has commands on both sides.
first = ut_turtle([ [ "bend", 270, "r", 30 ], [ "feed", 20 ] ]);
assert(abs(ut_length(first) - ((270 / 360) * 2 * PI * 30 + 20)) < 1e-9,
       "a >180 bend as the FIRST command splits correctly");
last = ut_turtle([ [ "feed", 20 ], [ "bend", 270, "r", 30 ] ]);
assert(abs(ut_length(last) - (20 + (270 / 360) * 2 * PI * 30)) < 1e-9,
       "a >180 bend as the LAST command splits correctly");
// Repeated halving: 400 degrees needs two rounds, because 200 is still over 180.
big = ut_turtle([[ "bend", 400, "r", 40 ]]);
bigarcs = [for (s = ut_segs(big)) if (ut_seg_kind(s) == "A") s];
assert(len(bigarcs) == 4, str("400 degrees halves twice, into 4 arcs, got ", len(bigarcs)));
assert(abs(ut_length(big) - (400 / 360) * 2 * PI * 40) < 1e-9, "and still preserves total length");

// ============================================ negative bends go the other way
down = ut_turtle([ [ "feed", 20 ], [ "bend", -90, "r", 15 ], [ "feed", 20 ] ]);
dsts = ut_stations(down);
assert(ut_st_p(dsts[len(dsts) - 1])[2] < -1, "a negative bend curves AWAY from `up`");

// ============================================ frames still work over a turtle path
assert(max([for (s = sts) abs(ut_st_t(s) * ut_st_n(s))]) < 1e-9, "frames stay orthonormal over a turtle path");
assert(abs(ut_st_s(sts[len(sts) - 1]) - ut_length(p)) < 1e-6, "arclength closes");

cube(0.001); // sentinel
