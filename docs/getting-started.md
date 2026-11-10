---
title: Getting started
nav_order: 2
---

# Getting started

## Requirements

OpenSCAD **2021.01**. uniTube has no other dependencies.

> **Known issue ([#40]).** Use 2021.01 for now. On newer versions that use the
> Manifold backend (measured on 2026.10.15), joined networks export the wrong
> solid: the bores are not cut. A single tube exports with its faces inside-out
> on every version. 2021.01 is the only version the library is tested on ([#38]).

## Install

Clone or download the repository, then do one of these:

- **Put it in your OpenSCAD library folder.** In OpenSCAD, *File → Show Library
  Folder* opens it. Place the `uniTube` folder there (a symlink works) and write:

  ```scad
  use <uniTube/src/uniTube.scad>;
  ```

- **Or point at it directly:**

  ```scad
  use </path/to/uniTube/src/uniTube.scad>;
  ```

`src/uniTube.scad` is the only file you import. Importing it draws nothing.

## A first tube

A tube is a **path** swept with a **profile**:

```scad
use <uniTube/src/uniTube.scad>;

$fa = 6;
$fs = 0.5;

path = ut_polyline([[0, 0, 0], [50, 0, 0], [50, 50, 0]], r = 15);
prof = ut_round(od = 12, wall = 2);

ut_tube(path, prof);
```

That is a 90° elbow: two straights joined by an arc of radius 15, with a 12 mm
outside diameter and a 2 mm wall.

**Resolution is yours to set.** The library sets no `$fa`, `$fs` or `$fn`, so the
values in your model decide how finely bends and cross-sections are faceted.

## Looking inside

A shaded hollow tube is hard to read: an open bore at a shallow angle and a
sealed end look the same. Cut it:

```scad
ut_cutaway([0, 0, 1]) ut_tube(path, prof);
```

`ut_cutaway(normal, at, on)` removes everything on the `normal` side of a plane.
Pass `on = false` to switch it off without removing it. It is for looking, not
for parts you export.

## Other ways to describe a path

```scad
// a bender program: feed, bend, roll
ut_tube(ut_turtle([["feed", 60], ["bend", 90, "r", 24], ["roll", 90], ["bend", 45, "r", 24]]),
        ut_round(id = 8, wall = 2));

// a formula
ut_tube(ut_curve(function(t) [50 * cos(720 * t), 50 * sin(720 * t), 90 * t], n = 200),
        ut_round(od = 10, wall = 2));
```

See [`usage/paths.md`](usage/paths.md).

## Tubes that join

Runs that meet are declared as a network, so every bore stays open:

```scad
trunk  = ut_run("trunk",  ut_polyline([[-50, 0, 0], [50, 0, 0]]), ut_round(od = 20, wall = 2));
branch = ut_run("branch", ut_polyline([[0, 10, 0],  [0, 50, 0]]), ut_round(od = 12, wall = 2));

ut_assemble(ut_net([trunk, branch],
                   [ut_joint([["trunk", ["s", 50]], ["branch", "a"]])]));
```

See [`usage/networks.md`](usage/networks.md).

## When it refuses

uniTube stops with a message rather than drawing a part you did not describe. A
bend tighter than the tube's own radius, fillets that do not fit on a leg, and a
sharp corner are all errors, each naming the offending element:

```
CHECK-1: bend radius 4 is not greater than the profile's outer reach 6 -- the tube passes through itself at this bend. CGAL will still report "Simple: yes".
```

Advisory warnings appear in the console as `ECHO: "WARNING [uniTube] ..."` and
do not stop the render. Every code is listed in
[`reference/checks.md`](reference/checks.md).

## Where next

| | |
|---|---|
| [`usage/paths.md`](usage/paths.md) | the four ways to describe a centreline |
| [`usage/profiles.md`](usage/profiles.md) | round, split and arbitrary sections |
| [`usage/frames.md`](usage/frames.md) | which way the section faces, and twist |
| [`usage/networks.md`](usage/networks.md) | junctions, lumen groups, ports |
| [`examples/`](examples/index.md) | twelve runnable models |
| [`reference/`](reference/path.md) | every function and module |

[#38]: https://github.com/CameronBrooks11/uniTube/issues/38
[#40]: https://github.com/CameronBrooks11/uniTube/issues/40
