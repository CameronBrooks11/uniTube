// t_smoke — proves the assert gate itself works.
//
// Tests are assert-only and must end in a sentinel cube: a file that emits no
// geometry exits 1 under `-o *.stl`, which would look like a test failure.
// Always render tests to .stl, never .csg -- with -o *.csg a FAILING assert
// exits 0, so a .csg gate reports every broken test as green. See AGENTS.md.

// The rule that replaces acos() everywhere (docs/salvage.md §3).
function turn(a, b) = atan2(norm(cross(a, b)), a *b);

assert(abs(turn([ 1, 0, 0 ], [ 0, 1, 0 ]) - 90) < 1e-9, "turn(): orthogonal vectors must give 90 degrees");
assert(abs(turn([ 1, 0, 0 ], [ 1, 0, 0 ])) < 1e-9, "turn(): identical vectors must give 0 degrees");
assert(abs(turn([ 1, 0, 0 ], [ -1, 0, 0 ]) - 180) < 1e-9, "turn(): opposed vectors must give 180 degrees");

// The specific failure this rule exists to prevent: acos() NaNs when float error
// pushes its argument past 1.0, which is the near-collinear waypoint case.
// OpenSCAD 2021.01 has no is_nan(); the idioms that DO work here are
// `is_num(x)` (false for nan, true for inf) and `x == x` (false for nan only).
nearly = [ 1, 1e-9, 0 ];
assert(is_num(turn([ 1, 0, 0 ], nearly)), "turn(): must not NaN on near-collinear vectors");
assert(!is_num(acos(1.0000001)), "acos() past 1.0 is nan on 2021.01 -- this is why turn() exists");

// Exact developed length of the worked elbow (docs/ir.md): 35 + quarter-arc + 35.
len_expected = 35 + (90 / 360) * 2 * PI * 15 + 35;
assert(abs(len_expected - 93.5619449019) < 1e-9, "worked elbow developed length");

cube(0.001); // sentinel -- see header
