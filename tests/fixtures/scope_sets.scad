// Fixture for tests/t_scoping.scad. Sets $fa/$fs at its own top level.
// Not a test: it lives below tests/ so `just test` and `just check`, which use
// -maxdepth 1, do not try to run it.
$fa = 8;
$fs = 1;
SCOPE_K = 100;

function scope_sets_fa() = $fa;
function scope_sets_k() = SCOPE_K;
