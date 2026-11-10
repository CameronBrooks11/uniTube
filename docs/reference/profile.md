---
title: Profile API
parent: Reference
nav_order: 2
---

# Profiles — API

Source: `src/ut_profile.scad`. For how to use these, see
[`usage/profiles.md`](../usage/profiles.md).

```scad
prof = ["utprof", outer, inner, meta]
```

Read a profile through the accessors, not by index.

## Constructors

| | |
|---|---|
| `ut_round(od = undef, id = undef, wall = undef, n = undef, a0 = 0, split = undef)` | A round tube from exactly two of `od`, `id`, `wall`. `n` sets the point count (default from `$fa`/`$fs`), `a0` the first point's angle. `split = [a, b]` removes the angles from `a` to `b` and makes a C-section. |
| `ut_rod(d, n = undef, a0 = 0)` | A solid round section, no bore. |
| `ut_profile(outer, inner = undef, meta = [])` | Any section from 2D loops. Asserts `PROF-1` and `PROF-2`. |

## Accessors

| | returns |
|---|---|
| `ut_prof_outer(p)` | the outer loop |
| `ut_prof_inner(p)` | the inner loop, or `undef` |
| `ut_prof_meta(p)` | the `[key, value]` list |
| `ut_prof_od(p)`, `ut_prof_id(p)`, `ut_prof_wall(p)` | the declared dimension, or `undef` |
| `ut_prof_symmetry(p)` | the declared symmetry order, default 0 |
| `ut_prof_hollow(p)` | `true` if there is an inner loop |
| `ut_prof_open(p)` | `true` for a split section |
| `ut_prof_thin(p)` | `true` if the declared wall is below `ut_min_wall()` |

Two measurements live in other modules:

| | returns |
|---|---|
| `ut_prof_reach(prof)` | the farthest outer point from the centre (`src/ut_check.scad`) |
| `ut_bore_inradius(prof)` | the radius of the largest circle inside the bore polygon, 0 for a rod (`src/ut_net.scad`) |

## Regions

A region is a list of loops, which `ut_sweep` takes.

| | returns |
|---|---|
| `ut_solid_rgn(p)` | `[outer, inner]`, or `[outer]` for a rod |
| `ut_shell_rgn(p)` | `[outer]`; `[]` for a split section |
| `ut_bore_rgn(p)` | `[inner]`; `[]` for a rod or a split section |
