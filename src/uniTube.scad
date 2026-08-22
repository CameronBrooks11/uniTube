// uniTube — The Universal Tube Library for OpenSCAD
//
// The only public entry point:
//     use <uniTube/src/uniTube.scad>;
//
// NOTE ON `include` vs `use`, verified on OpenSCAD 2021.01:
//   * `use` does NOT transitively re-export. A consumer doing `use <A>` where A
//     does `use <B>` CANNOT see B's functions.
//   * `include` merges a file into this one's scope, and `use` then exports what
//     it finds there. So the entry point must `include`, not `use`.
//   * Relative paths resolve against the file containing the directive, so
//     frontend/'s `../` imports still work when included from here.
// Internal modules use `use <>` for their own dependencies; only this file
// includes. Nothing in src/ emits geometry or echoes on import (AGENTS.md rule 3).

// clang-format off
include <ut_core.scad>;
include <ut_math.scad>;
include <ut_path.scad>;
include <ut_profile.scad>;
include <ut_check.scad>;
include <ut_mesh.scad>;
include <ut_port.scad>;
include <ut_net.scad>;
include <ut_view.scad>;
include <frontend/ut_polyline.scad>;
include <frontend/ut_turtle.scad>;
include <frontend/ut_curve.scad>;
// clang-format on
