// ut_path — the two-level path IR (ADR 0002).
//
//   LEVEL 1  utPath ("the spine")  — exact L / A / P segments. No roll, no
//                                    resolution. This is what frontends build.
//   LEVEL 2  utStations            — [p, t, n, s] per station. Roll decided,
//                                    resolution decided, holonomy absorbed.
//
// THE RULE (AGENTS.md rule 4): frontends produce a spine and never touch frames.
// Exactly one function — ut_stations() — lowers spine to stations. The backend
// consumes stations and never infers orientation.

// clang-format off
use <ut_core.scad>;
use <ut_math.scad>;
// clang-format on

// =============================================================== constructors

// A straight segment.
function ut_line(p0, p1) = assert(norm(p1 - p0) > ut_eps(), str("ut_line(): zero-length segment at ", p0))["L", p0, p1];

// A circular arc, parameterised exactly as STEP/IGES axis2_placement_3d:
//     point(x)   = c + r*(cos(ang*x)*u + sin(ang*x)*v)
//     tangent(x) = -sin(ang*x)*u + cos(ang*x)*v          (already unit)
//     axis       = cross(u, v)                           (the transport axis)
// Sweep direction is encoded in the (u,v) basis, NOT in the sign of ang, so ang
// is always positive. That removes a whole class of tangent sign errors.
function ut_arc(c, u, v, r, ang) = assert(r > ut_eps(), str("ut_arc(): radius must be positive, got ", r))
    assert(ang > ut_eps() && ang <= 180 + ut_eps(),
           str("ut_arc(): sweep must be in (0, 180], got ", ang, " -- split larger arcs"))
        assert(abs(norm(u) - 1) < 1e-9 && abs(norm(v) - 1) < 1e-9, "ut_arc(): u and v must be unit vectors")
            assert(abs(u *v) < 1e-9, "ut_arc(): u and v must be orthogonal")["A", c, u, v, r, ang];

// Build an arc from a centre, its two endpoints and the plane normal.
function ut_arc_from(c, from, to, axis) = let(u = ut_unit(from - c), ax = ut_unit(axis), v = cross(ax, u),
                                              r = norm(from - c), ang = ut_turn(from - c, to - c))
    ut_arc(c, u, v, r, ang);

// A sampled chain. Tangents are carried per sample: a bare point list
// reintroduces the chord-tangent error this IR exists to avoid.
function ut_sampled(pts, tans) = assert(len(pts) >= 2, "ut_sampled(): need at least 2 points")
    assert(len(pts) == len(tans), "ut_sampled(): one tangent per point")
    // The same first-use mistake ut_polyline guards (frontend/ut_polyline.scad),
    // guarded HERE because every P segment from every frontend passes through
    // this one constructor. Without it ut_curve(function(t) [t, t*t]) built a
    // spine happily and failed at SWEEP time, far from the cause, with the
    // identical misleading message quoted below.
    assert(
        _ut_p3d(pts, 0) && _ut_p3d(tans, 0),
        "ut_sampled(): every point and tangent must be a 3-vector [x,y,z]. A 2D value reaches cross() and reports only \"atan2() parameter could not be converted\", naming ut_math rather than your curve.")
        ["P", pts, tans];

function _ut_p3d(v, i) = i >= len(v) ? true : (is_list(v[i]) && len(v[i]) == 3) && _ut_p3d(v, i + 1);

// =============================================================== accessors

function ut_seg_kind(s) = s[0];
function ut_seg_p0(s) = s[0] == "L" ? s[1] : s[0] == "A" ? s[1] + s[4] * s[2] : s[1][0];
function ut_seg_p1(s) = s[0] == "L"   ? s[2]
                        : s[0] == "A" ? s[1] + s[4] * (cos(s[5]) * s[2] + sin(s[5]) * s[3])
                                      : s[1][len(s[1]) - 1];
function ut_seg_t0(s) = s[0] == "L" ? ut_unit(s[2] - s[1]) : s[0] == "A" ? s[3] : ut_unit(s[2][0]);
function ut_seg_t1(s) = s[0] == "L"   ? ut_unit(s[2] - s[1])
                        : s[0] == "A" ? -sin(s[5]) * s[2] + cos(s[5]) * s[3]
                                      : ut_unit(s[2][len(s[2]) - 1]);
function ut_seg_len(s) = s[0] == "L"   ? norm(s[2] - s[1])
                         : s[0] == "A" ? abs(s[5]) / 360 * 2 * PI * s[4]
                                       : _ut_chain_len(s[1], 0);
function _ut_chain_len(p, i) = i >= len(p) - 1 ? 0 : norm(p[i + 1] - p[i]) + _ut_chain_len(p, i + 1);

function ut_segs(path) = path[1];
function ut_closed(path) = path[2];
function ut_popts(path) = path[3];

// Exact developed length. No tessellation involved.
function ut_length(path) = _ut_sum_len(ut_segs(path), 0);
function _ut_sum_len(segs, i) = i >= len(segs) ? 0 : ut_seg_len(segs[i]) + _ut_sum_len(segs, i + 1);

// =============================================================== the spine

// Assemble segments into a spine, asserting the SPINE invariants.
function ut_spine(segs, closed = false, opts = []) = assert(len(segs) >= 1, "ut_spine(): need at least one segment")
    assert(_ut_contig(segs, closed, 0), "unreachable")
        assert(_ut_g1(segs, closed, 0), "unreachable")["utpath", segs, closed, opts];

// SPINE-2 — the end of each segment is the start of the next.
function _ut_contig(segs, closed,
                    i) = i >= len(segs) - (closed ? 0 : 1)
                             ? true
                             : let(a = ut_seg_p1(segs[i]), b = ut_seg_p0(segs[(i + 1) % len(segs)]), d = norm(a - b))
                                   assert(d < 1e-6, str("SPINE-2 violated: segment ", i, " ends at ", a,
                                                        " but segment ", (i + 1) % len(segs), " starts at ", b,
                                                        " (gap ", d, ")")) _ut_contig(segs, closed, i + 1);

// SPINE-3 — tangent continuity everywhere. There is no G0 / mitre case (ADR 0004).
function _ut_g1(segs, closed,
                i) = i >= len(segs) - (closed ? 0 : 1)
                         ? true
                         : let(a = ut_seg_t1(segs[i]), b = ut_seg_t0(segs[(i + 1) % len(segs)]), d = ut_turn(a, b))
                               assert(d < 1e-4,
                                      str("SPINE-3 violated: tangent discontinuity of ", d, " deg between segment ", i,
                                          " and ", (i + 1) % len(segs), " -- r=0 at an interior vertex is an error"))
                                   _ut_g1(segs, closed, i + 1);

// =============================================================== tessellation

// Per-segment samples: [position, tangent, transport axis, transport angle, local arclength].
// `first` includes the segment's start point; otherwise it is the previous
// segment's end point and is skipped -- this is the unconditional dedupe that
// stops the coincident-point NaN (docs/salvage.md §3).
function _ut_samples(seg, first) = seg[0] == "L"   ? _ut_samples_L(seg, first)
                                   : seg[0] == "A" ? _ut_samples_A(seg, first)
                                                   : _ut_samples_P(seg, first);

function _ut_samples_L(s, first) = let(d = ut_unit(s[2] - s[1]), L = norm(s[2] - s[1])) first
                                       ? [[s [1], d, ut_up(), 0, 0], [s [2], d, ut_up(), 0, L]]
                                       : [[s [2], d, ut_up(), 0, L]];

function _ut_samples_A(s, first) = let(c = s[1], u = s[2], v = s[3], r = s[4], ang = s[5], n = ut_fragments(r, ang),
                                       ax = ut_unit(cross(u, v)), arclen = ang / 360 * 2 * PI * r,
                                       k0 = first ? 0 : 1)[for (k = [k0:n]) let(
    x = k / n,
    a = ang * x)[c + r * (cos(a) * u + sin(a) * v), -sin(a) * u + cos(a) * v, ax, k == 0 ? 0 : ang / n, arclen *x]];

// The cumulative chain length, computed ONCE per segment. Recomputing it per
// sample made this O(n^2): a 220-sample helix did ~24k norm() calls to place
// 220 stations.
function _ut_cumlen(p, i = 0, acc = [0]) = i >= len(p) - 1
                                               ? acc
                                               : _ut_cumlen(p, i + 1, concat(acc, [acc[i] + norm(p[i + 1] - p[i])]));

function _ut_samples_P(s, first) = let(p = s[1], t = s[2], k0 = first ? 0 : 1,
                                       cum = _ut_cumlen(p))[for (k = [k0:len(p) - 1]) let(
    prev = k == 0 ? t[0] : t[k - 1], d = ut_turn(prev, t[k]),
    cx = cross(prev, t[k]))[p[k], ut_unit(t[k]), d < 1e-9 ? ut_up() : ut_unit(cx), k == 0 ? 0 : d, cum[k]]];

function _ut_gather(segs, i, base, acc) = i >= len(segs)
                                              ? acc
                                              : let(sm = _ut_samples(segs[i], i == 0),
                                                    shifted = [for (e = sm)[e[0], e[1], e[2], e[3], e[4] + base]])
                                                    _ut_gather(segs, i + 1, base + ut_seg_len(segs[i]),
                                                               concat(acc, shifted));

// =============================================================== frames

// Transport scan: n[i] = rotate(n[i-1]) about this step's own axis by its own
// angle. For an arc that is CLOSED FORM and exact -- the payoff of an arc-native
// IR, and the generalisation of half_curvedPipe.scad:19 (docs/salvage.md §2).
function _ut_transport(raw, i, prev,
                       acc) = i >= len(raw) ? acc
                                            : let(nx = raw[i][3] < 1e-12
                                                           ? ut_ortho(raw[i][1], prev)
                                                           : ut_ortho(raw[i][1], ut_rotv(prev, raw[i][3], raw[i][2])))
                                                  _ut_transport(raw, i + 1, nx, concat(acc, [nx]));

// Signed roll angle from a to b about axis t.
function _ut_signed_roll(a, b, t) = atan2(cross(a, b) * ut_unit(t), a *b);

// THE one compiler function: spine -> stations.
function ut_stations(path, opts = []) =
    let(segs = ut_segs(path), closed = ut_closed(path), po = ut_popts(path), o = concat(opts, po), // caller's opts win
        raw = _ut_gather(segs, 0, 0, []), N = len(raw), policy = ut_opt(o, "frame", "transport"),
        ref = ut_opt(o, "normal", ut_up()), twist = ut_opt(o, "twist", 0), sym = ut_opt(o, "symmetry", 0),
        n0 = ut_ref_fallback(raw[0][1], is_list(policy) ? ut_up() : ref),

        // --- roll policy ---
        norms = is_list(policy)     ? [for (i = [0:N - 1]) ut_ortho(raw[i][1], policy[i])]
                : policy == "fixed" ? [for (i = [0:N - 1]) ut_ref_fallback(raw[i][1], ref)]
                                    : _ut_transport(raw, 1, n0, [n0]),

        // --- closed-loop holonomy, absorbed and distributed (path_extrude gets
        //     this off by one and leaves a permanent 0.75 deg seam residual) ---
        sLast = raw[N - 1][4],
        hol = (closed && policy == "transport")
                  ? let(h = _ut_signed_roll(norms[N - 1], n0, raw[N - 1][1]), step = sym > 0 ? 360 / sym : 360) h -
                        round(h / step) * step
                  : 0,
        extra = twist + hol,
        // STATION-7 — a CLOSED station list carries NO duplicated terminal
        // station. The last raw sample coincides with the first by construction.
        // It must survive long enough to measure the loop holonomy above, but it
        // must not reach the backend: the wrap ring would stitch a station to
        // itself. Measured before this: 88 degenerate triangles out of 2904.
        last = closed ? N - 2 : N - 1)[for (i = [0:last]) let(
        a = sLast > ut_eps() ? extra * raw[i][4] / sLast
                             : 0)[raw[i][0], ut_unit(raw[i][1]),
                                  a == 0 ? norms[i] : ut_rotv(norms[i], a, ut_unit(raw[i][1])), raw[i][4]]];

// A station's 4x4 frame: columns (n, b, t) and the position. No scale, no shear
// -- STATION-2. A tapered run must never bake scale in here (ADR 0002 rationale).
function ut_st_mat(st) = let(t = st[1], n = st[2], b = cross(t, n), p = st[0])
    [[n [0], b [0], t [0], p [0]], [n [1], b [1], t [1], p [1]], [n [2], b [2], t [2], p [2]], [0, 0, 0, 1]];

function ut_st_p(st) = st[0];
function ut_st_t(st) = st[1];
function ut_st_n(st) = st[2];
function ut_st_s(st) = st[3];

// ---------------------------------------------------------------- ut_at

// Position and tangent at a given arclength, computed EXACTLY from the spine --
// no tessellation, no interpolation between stations. Deferred from Phase 1
// because nothing needed it; joints need it for mid-run landings, which is the
// case where a branch meets a trunk somewhere along its length.
// Returns [position, unit tangent].
function ut_at(path, s) = let(segs = ut_segs(path), total = ut_length(path))
    assert(s >= -ut_eps() && s <= total + ut_eps(),
           str("ut_at(): arclength ", s, " is outside the path (0 .. ", total, ")")) _ut_at(segs, 0, s);

function _ut_at(segs, i, s) = let(L = ut_seg_len(segs[i]))(i >= len(segs) - 1 || s <= L + ut_eps())
                                  ? _ut_seg_at(segs[i], min(s, L))
                                  : _ut_at(segs, i + 1, s - L);

function _ut_seg_at(seg, s) = seg[0] == "L" ? let(d = ut_unit(seg[2] - seg[1]))[seg[1] + s * d, d]
                              : seg[0] == "A"
                                  ? let(c = seg[1], u = seg[2], v = seg[3], r = seg[4], ang = seg[5],
                                        x = s / (ang / 360 * 2 * PI * r),
                                        a = ang * x)[c + r * (cos(a) * u + sin(a) * v), -sin(a) * u + cos(a) * v]
                                  : _ut_chain_at(seg[1], seg[2], 0, s);

// The tangent is INTERPOLATED along the chord, so it is exactly the stored
// tangent at each sample and continuous in between. It used to be t[i+1] --
// the far end of the chord -- for every s, which made ut_at(path, 0) return the
// tangent one sample downstream: measured 8.94 degrees out at the start of an
// n=40 helix, exactly one sample's rotation. L and A segments are exact; this is
// the best a sampled segment can do without re-deriving the source curve.
function _ut_chain_at(p, t, i, s) =
    let(L = norm(p[i + 1] - p[i]))(i >= len(p) - 2 || s <= L + ut_eps())
        ? let(x = L > ut_eps() ? min(max(s / L, 0), 1)
                               : 0)[p[i] + min(s, L) * ut_unit(p[i + 1] - p[i]), ut_unit(t[i] * (1 - x) + t[i + 1] * x)]
        : _ut_chain_at(p, t, i + 1, s - L);
