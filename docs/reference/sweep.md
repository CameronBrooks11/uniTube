---
title: Sweep API
parent: Reference
nav_order: 3
---

# Sweeping — API

Source: `src/ut_mesh.scad`. A region swept along stations becomes one
polyhedron, with no CSG.

## Modules

| | |
|---|---|
| `ut_tube(path, prof, part = "solid", opts = [])` | Sweeps one run. Runs `ut_check` first. `part` is `"solid"` (the finished wall), `"shell"` (the outside, filled) or `"bore"` (the bore as a solid); any other value is an error. `opts` are frame options. |
| `ut_sweep(rgn, sts, closed = false, open = false)` | The underlying sweep: a region along a station list. `closed` wraps the last station to the first and omits end caps. `open` adds the two seam walls of a split section. |

## Functions

| | returns |
|---|---|
| `ut_run_volume(path, prof, part = "solid", opts = [])` | the volume of the mesh `ut_tube` would emit, without rendering it |
| `ut_run_ports(path, prof, name = "run", opts = [])` | the two end ports of a single run, named `name.a` and `name.b` |
| `ut_part_rgn(prof, part)` | the region a `part` name selects |
| `ut_place(st, q)` | a 2D profile point `q` placed in station `st`: `p + q[0]*n + q[1]*cross(t, n)` |
| `ut_mesh_points(rgn, sts, closed = false)` | the vertex list |
| `ut_mesh_faces(rgn, sts, closed = false, open = false)` | the face list. Every face is a triangle. |

`ut_mesh_points` and `ut_mesh_faces` are what `polyhedron()` receives. With
`ut_volume` they let a test measure a mesh as data:

```scad
sts = ut_stations(path);
rgn = ut_solid_rgn(prof);
echo(ut_volume(ut_mesh_points(rgn, sts), ut_mesh_faces(rgn, sts)));
```
