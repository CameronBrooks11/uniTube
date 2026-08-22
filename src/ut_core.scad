// ut_core — shared constants, record access, and assertion helpers.
//
// NOTE, verified on 2021.01: `use <>` does not export top-level VARIABLES at
// all, and it does not re-export transitively either -- see src/uniTube.scad for
// why the entry point is the one file that `include`s. Every shared constant in
// this library is therefore a zero-argument FUNCTION, not a variable.

function ut_eps() = 1e-9;
function ut_min_wall() = 1.2; // ~3 perimeters on a 0.4 nozzle; a warning, not an error

function ut_up() = [ 0, 0, 1 ];
function ut_back() = [ 0, 1, 0 ];

// --- association lists: opts = [["key", value], ...] --------------------------
function ut_opt(opts, key, dflt = undef) = let(hit = [for (e = opts) if (e[0] == key) e[1]]) len(hit) > 0 ? hit[0]
                                                                                                          : dflt;

// --- tagged records -----------------------------------------------------------
// Every record is ["tag", ...fields]. User code reads them through accessors,
// never by index, so a field can be added without invalidating existing values.
// The accessors live beside their constructors; there is no generic reader here,
// because nothing ever needed to ask a record what it was.

// --- assertion helper ---------------------------------------------------------
// Usage: function f(x) = ut_req(x > 0, str("f(): x must be positive, got ", x)) x * 2;
// Returns true when the condition holds so it can prefix an expression.
function ut_req(cond, msg) = assert(cond, msg) true;
