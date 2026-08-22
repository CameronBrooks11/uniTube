// t_scoping — how `use <>` and $-variables actually interact.
//
// This is here because I got it wrong and filed a bug against a gate that was
// already correct. The reasoning was: $fa is dynamically scoped, and `use <>`
// does not execute a file's top-level assignments, therefore the caller's $fa
// reaches a module called from that file. Both premises are true. The
// conclusion is false, and no test would have told me.
//
// src/ sets no $fa, $fs or $fn anywhere, which is exactly why the library picks
// up the consumer's resolution -- the behaviour asserted below is load-bearing.

// clang-format off
use <fixtures/scope_sets.scad>;
use <fixtures/scope_silent.scad>;
// clang-format on

$fa = 30;
$fs = 5;
SCOPE_K = 999;

// 1. A file's top-level values are NOT exported to the consumer.
assert($fa == 30, "the caller's own $fa is untouched by use<>");
assert(SCOPE_K == 999, "and so is an ordinary variable of the same name");

// 2. But that file's own functions still see them -- they close over the
//    defining file's scope. THIS is the half I had wrong.
assert(scope_sets_fa() == 8, str("a function whose file sets $fa sees 8, not the caller's 30; got ", scope_sets_fa()));
assert(scope_sets_k() == 100, str("ordinary variables behave the same way; got ", scope_sets_k()));

// 3. A name the defining file leaves unset IS dynamically scoped from the call
//    site. This is what lets a consumer set the library's resolution at all.
assert(scope_silent_fa() == 30, str("a function whose file is silent sees the caller's 30; got ", scope_silent_fa()));

// 4. An explicit $-argument at the call site beats both.
assert(scope_silent_fa($fa = 77) == 77, "an explicit $fa at the call site wins");
assert(scope_sets_fa($fa = 77) == 77, "and it wins even over a file that sets its own");

// The consequence for this repository: examples set $fa/$fs at their top level,
// so `part()` renders at the authored resolution however it is invoked -- which
// is why the `just cgal` wrapper was right all along. $fn, which no example
// sets, does come from the wrapper.
cube(0.001); // sentinel
