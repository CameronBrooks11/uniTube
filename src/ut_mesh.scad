// ut_mesh — THE BACKEND. A region swept along stations becomes ONE polyhedron.
//
// This is the whole of uniTube's geometry engine, and it is why the library has
// no dependencies (ADR 0001). Place each 2D loop point into each station frame,
// quad-strip the skins, close the ends, emit. No CSG anywhere along a run.
//
// Quads on a swept skin are generally NON-PLANAR. Every face emitted here is a
// TRIANGLE, so the topology is ours rather than something OpenSCAD guesses at
// ("PolySet has nonplanar faces. Attempting alternate construction").

// clang-format off
use <ut_core.scad>;
use <ut_math.scad>;
use <ut_path.scad>;
use <ut_profile.scad>;
use <ut_port.scad>;
use <ut_check.scad>;
// clang-format on

// Place a profile-local point into a station frame: p + x*n + y*b.
// +X is the station's roll-reference normal, +Y its binormal. That convention is
// what makes "the seam faces up" mean something.
function ut_place(st, q) = let(t = ut_st_t(st), n = ut_st_n(st), b = cross(t, n)) ut_st_p(st) + q[0] * n + q[1] * b;

function _ut_quad(a, b, c, d) = [[a, b, c], [a, c, d]];
function _ut_centroid(loop) = _ut_csum(loop, 0) / len(loop);
function _ut_csum(l, i) = i >= len(l) ? [ 0, 0 ] : l[i] + _ut_csum(l, i + 1);

// ---------------------------------------------------------------- vertices

// Annular (2 loops): per station, N outer points then N inner points.
// Solid (1 loop): per station, N points; plus one centroid vertex per open end.
function ut_mesh_points(rgn, sts, closed = false) =
    let(S = len(sts), N = len(rgn[0]), hollow = len(rgn) > 1) hollow
        ? [for (j = [0:S - 1])
                  each concat([for (q = rgn[0]) ut_place(sts[j], q)], [for (q = rgn[1]) ut_place(sts[j], q)])]
        : concat([for (j = [0:S - 1]) each[for (q = rgn[0]) ut_place(sts[j], q)]],
                 closed ? [] : [ ut_place(sts[0], _ut_centroid(rgn[0])), ut_place(sts[S - 1], _ut_centroid(rgn[0])) ]);

// ---------------------------------------------------------------- faces

function ut_mesh_faces(rgn, sts, closed = false, open = false) = let(S = len(sts), N = len(rgn[0]),
                                                                     hollow = len(rgn) > 1,
                                                                     last = closed ? S - 1 : S - 2) hollow
                                                                     ? _ut_faces_hollow(S, N, closed, last, open)
                                                                     : _ut_faces_solid(S, N, closed, last);

function _ut_oi(j, i, S, N) = (j % S) * 2 * N + (i % N);
function _ut_ii(j, i, S, N) = (j % S) * 2 * N + N + (i % N);
function _ut_vi(j, i, S, N) = (j % S) * N + (i % N);

function _ut_faces_hollow(S, N, closed, last, open = false) = let(iLast = open ? N - 2 : N - 1) concat(
    // outer skin
    [for (j = [0:last], i = [0:iLast]) each _ut_quad(_ut_oi(j, i, S, N), _ut_oi(j, i + 1, S, N),
                                                     _ut_oi(j + 1, i + 1, S, N), _ut_oi(j + 1, i, S, N))],
    // inner skin -- reversed, so it faces INTO the bore. This one line is where
    // the CCW/CCW storage convention is paid for (see ut_profile.scad header).
    [for (j = [0:last], i = [0:iLast]) each _ut_quad(_ut_ii(j, i, S, N), _ut_ii(j + 1, i, S, N),
                                                     _ut_ii(j + 1, i + 1, S, N), _ut_ii(j, i + 1, S, N))],
    // annular end caps -- a ring strip, NOT a polygon-with-holes triangulation.
    // This is what keeps the emitter short, and what PROF-2 exists to protect.
    closed ? []
           : concat([for (i = [0:iLast]) each _ut_quad(_ut_oi(0, i, S, N), _ut_ii(0, i, S, N), _ut_ii(0, i + 1, S, N),
                                                       _ut_oi(0, i + 1, S, N))],
                    [for (i = [0:iLast]) each _ut_quad(_ut_oi(S - 1, i, S, N), _ut_oi(S - 1, i + 1, S, N),
                                                       _ut_ii(S - 1, i + 1, S, N), _ut_ii(S - 1, i, S, N))]),
    // THE TWO SEAM WALLS of a C-section: the cut faces that close the split
    // along the whole run. Without them the surface is not closed and CGAL
    // rejects the mesh outright rather than reporting a plausible solid.
    !open ? []
          : concat([for (j = [0:last]) each _ut_quad(_ut_oi(j, 0, S, N), _ut_oi(j + 1, 0, S, N), _ut_ii(j + 1, 0, S, N),
                                                     _ut_ii(j, 0, S, N))],
                   [for (j = [0:last]) each _ut_quad(_ut_oi(j, N - 1, S, N), _ut_ii(j, N - 1, S, N),
                                                     _ut_ii(j + 1, N - 1, S, N), _ut_oi(j + 1, N - 1, S, N))]));

function _ut_faces_solid(S, N, closed, last) = let(C0 = S * N, C1 = S * N + 1)
    concat([for (j = [0:last], i = [0:N - 1]) each _ut_quad(_ut_vi(j, i, S, N), _ut_vi(j, i + 1, S, N),
                                                            _ut_vi(j + 1, i + 1, S, N), _ut_vi(j + 1, i, S, N))],
           closed ? []
                  : concat([for (i = [0:N - 1])[C0, _ut_vi(0, i + 1, S, N), _ut_vi(0, i, S, N)]],
                           [for (i = [0:N - 1])[C1, _ut_vi(S - 1, i, S, N), _ut_vi(S - 1, i + 1, S, N)]]));

// ---------------------------------------------------------------- emission

// Sweep a region along stations. ONE polyhedron, no CSG.
module ut_sweep(rgn, sts, closed = false, open = false)
{
    assert(len(rgn) > 0, "ut_sweep(): empty region -- a split profile has no bore to sweep");
    assert(len(sts) >= 2, "ut_sweep(): need at least 2 stations");
    polyhedron(points = ut_mesh_points(rgn, sts, closed), faces = ut_mesh_faces(rgn, sts, closed, open),
               convexity = 10);
}

// Sweep one run. `part` selects which region: the finished wall, the outer shell,
// or the bore as a positive solid. Assembly NEVER asks for "solid" (rule 5).
module ut_tube(path, prof, part = "solid", opts = [])
{
    assert(ut_check(path, prof));
    sts = ut_stations(path, opts);
    rgn = part == "solid" ? ut_solid_rgn(prof) : part == "shell" ? ut_shell_rgn(prof) : ut_bore_rgn(prof);
    assert(len(rgn) > 0, str("ut_tube(): part=\"", part, "\" is empty for this profile"));
    ut_sweep(rgn, sts, ut_closed(path), ut_prof_open(prof) && part == "solid");
}

// The mesh volume of a run, without rendering it. Used by tests/t_mesh.scad to
// catch the silent-material-loss class that CGAL's "Simple: yes" does not.
function ut_run_volume(path, prof, part = "solid", opts = []) = let(sts = ut_stations(path, opts),
                                                                    rgn = part == "solid"   ? ut_solid_rgn(prof)
                                                                          : part == "shell" ? ut_shell_rgn(prof)
                                                                                            : ut_bore_rgn(prof))
    ut_volume(ut_mesh_points(rgn, sts, ut_closed(path)),
              ut_mesh_faces(rgn, sts, ut_closed(path), ut_prof_open(prof) && part == "solid"));

// The two open ends of a single run. Phase 3 moves this to ut_net.scad, where
// ports are derived from GRAPH DEGREE and a joint-incident end is not a port.
// `dir` points OUTWARD: away from the material at each end.
function ut_run_ports(path, prof, name = "run", opts = []) =
    let(sts = ut_stations(path, opts),
        N = len(sts))[ut_port(str(name, ".a"), ut_st_p(sts[0]), -ut_st_t(sts[0]), ut_st_n(sts[0]), prof, 0),
                      ut_port(str(name, ".b"), ut_st_p(sts[N - 1]), ut_st_t(sts[N - 1]), ut_st_n(sts[N - 1]), prof,
                              ut_st_s(sts[N - 1]))];
