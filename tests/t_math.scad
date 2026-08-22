// t_math — the primitives everything else rests on.

// clang-format off
use <../src/ut_core.scad>;
use <../src/ut_math.scad>;
// clang-format on

// --- ut_turn: the acos replacement (AGENTS.md rule 7, docs/salvage.md §3) -----
assert(abs(ut_turn([ 1, 0, 0 ], [ 0, 1, 0 ]) - 90) < 1e-9, "ut_turn: orthogonal -> 90");
assert(abs(ut_turn([ 1, 0, 0 ], [ 1, 0, 0 ])) < 1e-9, "ut_turn: identical -> 0");
assert(abs(ut_turn([ 1, 0, 0 ], [ -1, 0, 0 ]) - 180) < 1e-9, "ut_turn: opposed -> 180");
assert(abs(ut_turn([ 2, 0, 0 ], [ 0, 5, 0 ]) - 90) < 1e-9, "ut_turn: magnitude-independent");
assert(is_num(ut_turn([ 1, 0, 0 ], [ 1, 1e-9, 0 ])), "ut_turn: must not NaN on near-collinear input");
assert(!is_num(acos(1.0000001)), "acos past 1.0 is nan on 2021.01 -- the bug ut_turn exists to avoid");

// --- ut_rotv: Rodrigues -------------------------------------------------------
assert(norm(ut_rotv([ 1, 0, 0 ], 90, [ 0, 0, 1 ]) - [ 0, 1, 0 ]) < 1e-9, "ut_rotv: x about z by 90 -> y");
assert(norm(ut_rotv([ 0, 0, 1 ], 90, [ 0, 0, 1 ]) - [ 0, 0, 1 ]) < 1e-9,
       "ut_rotv: a vector PARALLEL to the axis is invariant -- this is why a planar bend has zero twist");
assert(abs(norm(ut_rotv([ 1, 2, 3 ], 37, ut_unit([ 1, 1, 0 ]))) - norm([ 1, 2, 3 ])) < 1e-9,
       "ut_rotv: rotation preserves length");

// --- ut_ref_fallback: the vertical-tangent NaN --------------------------------
assert(norm(ut_ref_fallback([ 1, 0, 0 ]) - [ 0, 0, 1 ]) < 1e-9, "ut_ref_fallback: horizontal run seeds UP");
n_vert = ut_ref_fallback([ 0, 0, 1 ]);
assert(is_num(n_vert[0]) && is_num(n_vert[1]) && is_num(n_vert[2]),
       "ut_ref_fallback: a VERTICAL run must not produce NaN -- UP is parallel to the tangent there");
assert(abs(norm(n_vert) - 1) < 1e-9, "ut_ref_fallback: result is a unit vector");
assert(abs(n_vert * [ 0, 0, 1 ]) < 1e-9, "ut_ref_fallback: result is orthogonal to the tangent");

// --- ut_ring: angle sampling, the basis of PROF-2 (ADR 0006) -----------------
r8 = ut_ring(5, 8);
assert(len(r8) == 8, "ut_ring: point count");
assert(abs(norm(r8[0]) - 5) < 1e-9, "ut_ring: radius");
assert(ut_area2d(r8) > 0, "ut_ring: counter-clockwise (positive signed area)");
assert(ut_area2d([for (i = [len(r8) - 1:-1:0]) r8[i]]) < 0, "ut_area2d: reversed loop is negative");
// Correspondence: two rings of different radius agree in ANGLE at every index.
// (ut_turn is 3D-only -- cross() needs 3-vectors -- so compare planar angles.)
a = ut_ring(10, 8);
b = ut_ring(4, 8);
assert(max([for (i = [0:7]) abs(atan2(a[i][1], a[i][0]) - atan2(b[i][1], b[i][0]))]) < 1e-9,
       "PROF-2: rings of different radii must be angle-aligned index-for-index");

// --- ut_fragments -------------------------------------------------------------
assert(ut_fragments(15, 90, $fn = 0, $fa = 12, $fs = 2) == 8, "ut_fragments: r=15 over 90deg at default $fa/$fs");
assert(ut_fragments(15, 360, $fn = 64) == 64, "ut_fragments: explicit $fn, full circle");
assert(ut_fragments(15, 90, $fn = 64) == 16, "ut_fragments: explicit $fn scales with sweep");
assert(ut_fragments(1000, 1) >= 2, "ut_fragments: never fewer than 2 per segment");

// --- ut_volume ----------------------------------------------------------------
// Unit cube as 12 triangles, outward-facing.
cp = [ [ 0, 0, 0 ], [ 1, 0, 0 ], [ 1, 1, 0 ], [ 0, 1, 0 ], [ 0, 0, 1 ], [ 1, 0, 1 ], [ 1, 1, 1 ], [ 0, 1, 1 ] ];
cf = [
    [ 0, 3, 2 ], [ 0, 2, 1 ], [ 4, 5, 6 ], [ 4, 6, 7 ], [ 0, 1, 5 ], [ 0, 5, 4 ], [ 1, 2, 6 ], [ 1, 6, 5 ], [ 2, 3, 7 ],
    [ 2, 7, 6 ], [ 3, 0, 4 ], [ 3, 4, 7 ]
];
assert(abs(ut_volume(cp, cf) - 1) < 1e-9, "ut_volume: unit cube must measure exactly 1");

// ============================================ inradius: EDGES, not vertices
// ut_ring puts every point exactly on the nominal circle, so a vertex-based
// "inradius" returns the nominal radius at every resolution while the real
// inscribed circle is smaller by cos(180/n). That overstatement sized a
// subtracted sphere and put a hole through a junction.
for (n = [ 5, 6, 8, 12, 24, 64 ])
{
    let(ring = ut_ring(10, n), want = 10 * cos(180 / n))
    {
        assert(abs(max([for (q = ring) norm(q)]) - 10) < 1e-9,
               "the vertices are on the nominal circle -- that is the trap");
        assert(abs(ut_inradius(ring) - want) < 1e-9,
               str("ut_inradius at n=", n, ": expected ", want, " got ", ut_inradius(ring)));
        assert(ut_inradius(ring) <= 10 + 1e-9, "the inradius never exceeds the circumradius");
    }
}
// A square, where the answer is known by inspection: circumradius 10*sqrt(2),
// inradius exactly 10.
sq = [ [ 10, 10 ], [ -10, 10 ], [ -10, -10 ], [ 10, -10 ] ];
assert(abs(ut_inradius(sq) - 10) < 1e-9, str("square inradius must be 10, got ", ut_inradius(sq)));

// ============================================ the sphere OpenSCAD actually emits
// A sphere is faceted in two directions, so it loses cos(180/n) twice. Measured
// against the emitted mesh: exact for n >= 8, conservative below.
for (t = [ [ 8, 8.5355 ], [ 12, 9.3301 ], [ 24, 9.8296 ], [ 32, 9.9039 ], [ 48, 9.9572 ] ])
{
    let(got = ut_sphere_inradius(10, $fn = t[0]))
        assert(abs(got - t[1]) < 1e-3, str("sphere inradius at $fn=", t[0], ": expected ", t[1], " got ", got));
}
// Below n=8 it must UNDER-estimate -- erring low is the safe direction for
// anything that has to fit inside the result.
assert(ut_sphere_inradius(10, $fn = 5) < 7.33, "at $fn=5 the model must sit below the true 7.330");
assert(ut_sphere_inradius(10, $fn = 6) < 7.746, "at $fn=6 the model must sit below the true 7.746");

cube(0.001); // sentinel
