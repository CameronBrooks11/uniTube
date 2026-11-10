---
title: Home
layout: home
nav_order: 1
---

# uniTube

The Universal Tube Library for OpenSCAD: describe a tube's centreline, give it a
cross-section, and join several into branching networks whose bores stay open.

```scad
use <uniTube/src/uniTube.scad>;

// waypoints and fillet radii
ut_tube(ut_polyline([[0,0,0], [50,0,0], [50,50,0]], r = 15),
        ut_round(od = 12, wall = 2));
```

It has no dependencies and needs OpenSCAD 2021.01.

## What it is for

General sweep libraries move a solid outline along a curve. A tube needs more:

- a **bore** that survives every union in the model,
- **several ways to describe a path** — waypoints with fillet radii, a bender
  program, a formula, or arcs and lines — that all behave the same downstream,
- **branching networks** where hollow runs meet without sealing each other,
- **ports** as data, so fittings can be a separate library.

## Where to go

| | |
|---|---|
| [Getting started](getting-started.md) | Install, a first tube, looking inside. |
| [Usage](usage/index.md) | Paths, profiles, frames, networks. |
| [Examples](examples/index.md) | Twelve runnable models. |
| [Reference](reference/index.md) | Every function, and every error code. |
| [Developer](developer/index.md) | Verification, design decisions, history. |

## Status

`v0.1.0`. The geometry is verified, but the API has not yet been used by
anything outside the repository, so names and argument shapes may still move.

Not shipped, deliberately: terminations (a separate library), junction fillets,
profile variation along a path, and multi-lumen sections. Open work is in
[GitHub issues](https://github.com/CameronBrooks11/uniTube/issues).
