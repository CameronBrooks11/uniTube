// ut_profile — the cross-section, and the lumen that must survive every union.
//
//     prof = ["utprof", outer, inner, meta]
//
// A "region" here is a list of closed loops: the first is the outer boundary,
// any others are holes. Three regions are derivable from one profile, and the
// entire junction story depends on being able to ask for each independently:
//
//     ut_solid_rgn  [outer, inner]   the finished wall  -> ONE capped polyhedron
//     ut_shell_rgn  [outer]          outer filled, bore ignored
//     ut_bore_rgn   [inner]          the lumen AS A POSITIVE SOLID
//
// NO MODULE EVER EMITS A FINISHED HOLLOW TUBE DURING ASSEMBLY (AGENTS.md rule 5).
//
// WINDING CONVENTION — deviates from PLAN.md §3 deliberately. Both loops are
// stored COUNTER-CLOCKWISE, not outer-CCW/inner-CW. Reversing the inner loop
// would destroy the index correspondence that PROF-2 requires, and the bore
// would no longer be a directly usable positive solid. The mesh emitter orients
// the inner skin's faces instead -- one line, in one place. See ADR 0006.

// clang-format off
use <ut_core.scad>;
use <ut_math.scad>;
// clang-format on

// =============================================================== constructors

// Exactly two of {od, id, wall}. Supplying one or three is an error naming what
// was given -- all three spellings describe the same profile.
function ut_round(od = undef, id = undef, wall = undef, n = undef, a0 = 0,
                  split = undef) = let(given = (is_undef(od) ? 0 : 1) + (is_undef(id) ? 0 : 1) +
                                               (is_undef(wall) ? 0 : 1))
    assert(given == 2,
           str("ut_round(): give exactly two of od/id/wall, got ", given, " (od=", od, " id=", id, " wall=", wall, ")"))
        let(OD = is_undef(od) ? id + 2 * wall : od, ID = is_undef(id) ? od - 2 * wall : id,
            W = is_undef(wall) ? (od - id) / 2 : wall)
            assert(OD > 0 && ID >= 0 && W > 0,
                   str("ut_round(): implied dimensions must be positive (od=", OD, " id=", ID, " wall=", W, ")"))
                assert(ID < OD, str("ut_round(): id (", ID, ") must be less than od (", OD,
                                    ")"))(is_undef(split) ? _ut_round_closed(OD, ID, W, n, a0)
                                                          : _ut_round_split(OD, ID, W, n, split));

function _ut_round_closed(OD, ID, W, n, a0) = let(N = is_undef(n) ? ut_fragments(OD / 2, 360) : n)
    ut_profile(ut_ring(OD / 2, N, a0), ut_ring(ID / 2, N, a0),
               [ [ "od", OD ], [ "id", ID ], [ "wall", W ], [ "symmetry", 0 ], [ "kind", "round" ] ]);

// A C-SECTION. `split` is the angular GAP in profile-local degrees, so material
// spans split[1] .. split[0]+360. Local +X is the station roll reference, which
// is what makes "the seam faces up" mean something.
//
// A split tube is a PROFILE, not a path feature. That is the strongest single
// piece of evidence that path/profile is the right cut, and it replaces roughly
// 300 lines of reference/axford/half_curvedPipe.scad -- including its hard
// nine-segment ceiling -- with a constructor and a policy string.
function _ut_round_split(OD, ID, W, n, split) = assert(is_list(split) && len(split) == 2,
                                                       "ut_round(): split must be [gap_start, gap_end] in degrees")
    let(span = (split[0] + 360) - split[1])
        assert(span > ut_eps() && span < 360 - ut_eps(),
               str("ut_round(): the split gap leaves a material span of ", span, " degrees; it must be in (0, 360)"))
            let(N = is_undef(n) ? ut_fragments(OD / 2, span) + 1 : n,
                angs = [for (k = [0:N - 1]) split[1] + span * k / (N - 1)])
                ut_profile([for (a = angs)[OD / 2 * cos(a), OD / 2 * sin(a)]],
                           [for (a = angs)[ID / 2 * cos(a), ID / 2 * sin(a)]], [
                               [ "od", OD ], [ "id", ID ], [ "wall", W ], [ "symmetry", 1 ], [ "kind", "split" ],
                               [ "open", true ], [ "split", split ]
                           ]);

// A solid rod -- no lumen. Its end caps are triangulated by a centroid fan, so
// the outline must be star-shaped about its centroid (true for any convex shape).
function ut_rod(d, n = undef, a0 = 0) = let(N = is_undef(n) ? ut_fragments(d / 2, 360) : n)
    ut_profile(ut_ring(d / 2, N, a0), undef, [ [ "od", d ], [ "symmetry", 0 ], [ "kind", "rod" ] ]);

// An arbitrary hollow section. Asserts the profile invariants.
function ut_profile(outer, inner = undef, meta = []) = assert(len(outer) >= 3,
                                                              "ut_profile(): outer loop needs at least 3 points")
    assert(ut_area2d(outer) > 0, "PROF-1: outer loop must be counter-clockwise (positive signed area)") assert(
        is_undef(inner) || len(inner) == len(outer),
        str("PROF-2: outer and inner loops must have the SAME point count (got ", len(outer), " and ",
            is_undef(inner) ? 0 : len(inner), ") -- see ADR 0006"))
        assert(is_undef(inner) || ut_area2d(inner) > 0,
               "PROF-1: inner loop must also be counter-clockwise -- the emitter orients it, not the profile")
            assert(
                is_undef(inner) || _ut_aligned(outer, inner),
                "PROF-2: outer and inner loops must be ANGLE-ALIGNED index-for-index. Sampling a bore by perimeter instead of by angle self-intersects the end caps, and CGAL reports only an assertion violation. See ADR 0006.")
                ["utprof", outer, inner, meta];

// PROF-2 correspondence: outer[i] and inner[i] must sit at the same polar angle.
function _ut_aligned(o, i) = max([for (k = [0:len(o) - 1])
                                     abs(_ut_dang(atan2(o[k][1], o[k][0]), atan2(i[k][1], i[k][0])))]) < 1e-6;
function _ut_dang(a, b) = let(d = a - b) d - round(d / 360) * 360;

// =============================================================== accessors

function ut_prof_outer(p) = p[1];
function ut_prof_inner(p) = p[2];
function ut_prof_meta(p) = p[3];
function ut_prof_od(p) = ut_opt(ut_prof_meta(p), "od");
function ut_prof_id(p) = ut_opt(ut_prof_meta(p), "id");
function ut_prof_wall(p) = ut_opt(ut_prof_meta(p), "wall");
function ut_prof_symmetry(p) = ut_opt(ut_prof_meta(p), "symmetry", 0);
function ut_prof_hollow(p) = !is_undef(ut_prof_inner(p));
// An OPEN section (a C-section) has an inner surface but no ENCLOSED lumen, so
// it cannot participate in a junction. Documented rather than discovered.
function ut_prof_open(p) = ut_opt(ut_prof_meta(p), "open", false);

// =============================================================== regions

function ut_solid_rgn(p) = ut_prof_hollow(p) ? [ ut_prof_outer(p), ut_prof_inner(p) ] : [ut_prof_outer(p)];

// shell and bore are only meaningful for a CLOSED section. A split run has no
// enclosed lumen, contributes nothing to the subtraction pass, and therefore
// cannot join to anything -- fine for conduit and cable channel, which is what
// C-sections are for.
function ut_shell_rgn(p) = ut_prof_open(p) ? [] : [ut_prof_outer(p)];
function ut_bore_rgn(p) = (ut_prof_open(p) || !ut_prof_hollow(p)) ? [] : [ut_prof_inner(p)];

// PROF-3 — a wall below the minimum is a WARNING, not an error: a tube that
// renders perfectly and prints as a hole is the failure this library prevents.
function ut_prof_thin(p) = let(w = ut_prof_wall(p)) !is_undef(w) && w < ut_min_wall();
