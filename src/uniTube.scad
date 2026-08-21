// uniTube — The Universal Tube Library for OpenSCAD
//
// This is the only public entry point. Consumers write:
//     use <uniTube/src/uniTube.scad>
//
// It re-exports the library by `use <>`ing each module below. Nothing in src/
// emits geometry or echoes on import — demos live in examples/ (see AGENTS.md).
//
// PHASE 0: this file is a stub. The modules below land in Phase 1; see PLAN.md.
//
//   use <ut_core.scad>      // eps, record tags, assoc-list access, assert helpers
//   use <ut_math.scad>      // unit, turn (atan2, never acos), Rodrigues rotv, fragments
//   use <ut_path.scad>      // the spine (L/A/P) + ut_stations() — the one compiler function
//   use <ut_profile.scad>   // utprof, ut_round, solid/shell/bore regions, PROF-1..3
//   use <ut_mesh.scad>      // the backend: region x stations -> one polyhedron
//   use <ut_net.scad>       // runs, joints, lumen groups, the two-pass, ut_check
//   use <ut_port.scad>      // port records + ut_at_port. Zero dependencies.
//   use <frontend/ut_polyline.scad>
