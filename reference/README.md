# reference/ — read-only quarantine

Nothing here is part of uniTube. Nothing under `src/` may import from here, and
`just lint` fails the build if it does. Licences are recorded in the root
`NOTICE`; several are copyleft and one is unlicensed.

This directory exists for three reasons: prior art worth reading, a requirements
checklist for work that is deliberately deferred, and the historical record of
what this project grew out of.

| directory | licence | what it is | why it is kept |
|---|---|---|---|
| `axford/` | CC-BY | The Curved Pipe Library this project began as, plus `half_curvedPipe.scad` (which contains Cameron's original seam-transport work) and the `libs/` they depend on. | The fillet arithmetic in `curvedPipe.scad:71-105` is correct and is the reference semantics for the polyline frontend. `half_curvedPipe.scad` states the split-tube requirement. |
| `gringer/` | **GPLv3** | `path_extrude.scad` — a working polyhedron sweep engine. | Prior art for `src/ut_mesh.scad`. **Do not copy from it.** Its frame math is sound; it also has two real bugs (NaN on coincident path points, an off-by-one in the closed-loop twist correction) worth knowing about. |
| `doommeister/` | **GPLv3** | Round duct fittings — elbow, tee, n-way, reducer, manifold, with solvent/clamp/o-ring ends. | `middle_tee_n` and `manifold_n` are a **working reference implementation of the two-pass junction fix** (`difference(union(shells), union(bores))`) on real shipping geometry. This is the requirements checklist for `src/ut_net.scad`. |
| `makrokaba/` | BSD-3 | Six-way threaded/nozzle adapter matrix, threadlib-based. | The requirements checklist for the future, separate terminations library. Between this and `doommeister/` they enumerate essentially every termination style a v1 fittings library needs. |
| `jantecnl/` | **none stated** | The 4-into-1 manifold prototype. | The driving application and the source of the acceptance-test geometry. Its `pipeCurveCutout` is the ~60%-complete second pass of the two-pass fix — it stops at `torusSlice_only_inner_pipes()`, which `git log -S` confirms was never defined in any commit. Only its run coordinates are used. |
| `proto/` | — | Owner-written experiments. | `sweep_path.scad` is subsumed by `ut_curve`. |
