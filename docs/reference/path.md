---
title: Path API
parent: Reference
nav_order: 1
---

# Paths — API

Source: `src/ut_path.scad` and `src/frontend/`. For how to choose and use these,
see [`usage/paths.md`](../usage/paths.md); for the data format, [`ir.md`](ir.md).

## Frontends

Each returns a path.

| | |
|---|---|
| `ut_polyline(pts, r = 0, closed = false, frame = "transport", normal = undef, twist = 0)` | Waypoints with fillet radii. `closed = true` is refused. |
| `ut_turtle(cmds, start = [0,0,0], dir = [1,0,0], up = [0,0,1], frame = "transport", normal = undef, twist = 0)` | A list of `feed`, `bend` and `roll` commands. |
| `ut_curve(f, t = [0, 1], n = 100, dfdt = undef, frame = "transport", normal = undef, twist = 0)` | A function literal sampled at `n + 1` points. |
| `ut_spine(segs, closed = false, opts = [])` | A list of segments. Asserts contiguity and tangent continuity. |

## Segment constructors

| | |
|---|---|
| `ut_line(p0, p1)` | A straight. Zero length is an error. |
| `ut_arc(c, u, v, r, ang)` | An arc: `point(x) = c + r*(cos(ang*x)*u + sin(ang*x)*v)` for `x` in 0..1. `u`, `v` orthonormal, `r > 0`, `0 < ang <= 180`. |
| `ut_arc_from(c, from, to, axis)` | The arc about `c` from `from` to `to`, turning about `axis`. |
| `ut_sampled(pts, tans)` | A sampled chain: at least two 3D points, one tangent per point. |

## Reading a path

| | returns |
|---|---|
| `ut_segs(path)` | the segment list |
| `ut_closed(path)` | `true` for a closed path |
| `ut_popts(path)` | the options stored in the path |
| `ut_length(path)` | developed length. Exact for lines and arcs; a chord sum for sampled segments. |
| `ut_at(path, s)` | `[position, unit tangent]` at arclength `s`, read from the segments, independent of `$fa`/`$fs`. Asserts `0 <= s <= ut_length(path)`. |

Per segment:

| | returns |
|---|---|
| `ut_seg_kind(s)` | `"L"`, `"A"` or `"P"` |
| `ut_seg_p0(s)`, `ut_seg_p1(s)` | start and end points |
| `ut_seg_t0(s)`, `ut_seg_t1(s)` | unit tangents at the start and end |
| `ut_seg_len(s)` | length |

## Stations

| | |
|---|---|
| `ut_stations(path, opts = [])` | Compiles a path to a list of stations `[p, t, n, s]`. The only function that decides roll and resolution. |

`opts` is a list of `[key, value]` pairs, taking precedence over the path's own:

| key | default | |
|---|---|---|
| `"frame"` | `"transport"` | `"transport"`, `"fixed"`, or a list of one normal per station |
| `"normal"` | `[0,0,1]` | the reference for `"fixed"`, and the seed for `"transport"` |
| `"twist"` | `0` | degrees, distributed by arclength |
| `"symmetry"` | `0` | on a closed path, the section's rotational symmetry order |

See [`usage/frames.md`](../usage/frames.md).

| | returns |
|---|---|
| `ut_st_p(st)` | position |
| `ut_st_t(st)` | unit tangent |
| `ut_st_n(st)` | unit roll normal, orthogonal to the tangent |
| `ut_st_s(st)` | arclength |
| `ut_st_mat(st)` | the 4×4 frame: columns `n`, `cross(t, n)`, `t`, and the position. No scale or shear. |

A closed path's station list does not repeat its first station at the end.
