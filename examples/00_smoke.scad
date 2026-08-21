// 00_smoke — toolchain and mechanism smoke test.
//
// Self-contained on purpose: this file proves that `just check` and `just verify`
// work end to end BEFORE src/ has any content. It is throwaway; Phase 1 replaces
// it with 01_elbow.scad built on src/.
//
// It also demonstrates the backend mechanism in miniature (PLAN.md §2.1):
// place a 2D region at each station frame, quad-strip the outer and inner skins,
// ring the two end caps, emit ONE polyhedron. No CSG along the run.

N = 32; // profile points per loop -- SAME for both, and angle-aligned (PROF-2)
M = 16; // stations across the bend
od = 12;
id = 8;

function unit(v) = v / norm(v);

// --- profile: two angle-parameterised loops, so outer[i] corresponds to inner[i]
function ring(r) = [for (i = [0:N - 1]) let(a = 360 * i / N)[r * cos(a), r *sin(a)]];

// --- stations for a 90-degree elbow: [position, tangent, roll-normal] ---------
// Arc is the canonical ["A", c, u, v, r, ang] form: point(x) = c + r*(cos*u + sin*v)
c = [ 35, 15, 0 ];
u = [ 0, -1, 0 ];
v = [ 1, 0, 0 ];
r = 15;
ang = 90;
arc = [for (k = [0:M])
        let(x = k / M)[c + r * (cos(ang * x) * u + sin(ang * x) * v), -sin(ang *x) * u + cos(ang *x) * v, [ 0, 0, 1 ]]];
sts = concat([[ [ 0, 0, 0 ], [ 1, 0, 0 ], [ 0, 0, 1 ] ]], arc, [[ [ 50, 50, 0 ], [ 0, 1, 0 ], [ 0, 0, 1 ] ]]);

// --- place a profile point into a station frame: p + x*n + y*b ----------------
function place(st, q) = let(t = unit(st[1]), n = unit(st[2]), b = cross(t, n)) st[0] + q[0] * n + q[1] * b;

outer = ring(od / 2);
inner = ring(id / 2);
S = len(sts);

pts = [for (j = [0:S - 1]) each concat([for (q = outer) place(sts[j], q)], [for (q = inner) place(sts[j], q)])];

function OI(j, i) = j * 2 * N + (i % N);     // outer vertex index
function II(j, i) = j * 2 * N + N + (i % N); // inner vertex index

// Quads on a swept skin are generally NON-PLANAR, and OpenSCAD then says
// "PolySet has nonplanar faces. Attempting alternate construction" and guesses.
// Emit triangles so the topology is ours, not the renderer's.
function quad(a, b, c, d) = [[a, b, c], [a, c, d]];

faces = concat([for (j = [0:S - 2], i = [0:N - 1]) each quad(OI(j, i), OI(j, i + 1), OI(j + 1, i + 1), OI(j + 1, i))],
               [for (j = [0:S - 2], i = [0:N - 1]) each quad(II(j, i), II(j + 1, i), II(j + 1, i + 1), II(j, i + 1))],
               [for (i = [0:N - 1]) each quad(OI(0, i), II(0, i), II(0, i + 1), OI(0, i + 1))],
               [for (i = [0:N - 1]) each quad(OI(S - 1, i), OI(S - 1, i + 1), II(S - 1, i + 1), II(S - 1, i))]);

// The difference() against a tiny cube FORCES CGAL to evaluate the mesh. A raw
// polyhedron() is never validated, so "renders clean" would prove nothing and
// `just verify` would have no report to read. See AGENTS.md.
difference()
{
    polyhedron(points = pts, faces = faces, convexity = 8);
    cube(0.001);
}
