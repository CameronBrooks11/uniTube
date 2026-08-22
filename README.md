# uniTube

The Universal Tube Library for OpenSCAD.

A **path compiler and a hollow-network assembler**: many ways to describe a tube
centreline, all compiled down to one canonical form, swept as a single polyhedron,
and assembled into branching networks whose bores stay open.

> **Status: v1 core complete — path, profile, and network.** Four frontends
> compile to one canonical spine, sweep as a single polyhedron, and assemble into
> branching hollow networks whose bores stay open. See [`PLAN.md`](PLAN.md) for
> the architecture and [`BACKLOG.md`](BACKLOG.md) for what is next.
>
> Not yet shipped, deliberately: terminations (a separate library), junction
> fillets, profile variation. Not yet tagged.

## Why

A tube is **path × profile × terminations**, and general sweep libraries only
solve the first two — and only for a solid cross-section. uniTube is about the
parts that are specific to tubes:

- a **lumen** that must survive every union in the model,
- **many path frontends** — polyline with fillet radii, turtle/bender program,
  parametric function, arcs and lines — that all compile to one canonical spine,
- **branching networks** where several hollow runs meet without sealing each
  other's bores,
- **ports** as data, so terminations can be a separate library.

## What it looks like

```scad
use <uniTube/src/uniTube.scad>;

// waypoints and fillet radii
ut_tube(ut_polyline([[0,0,0], [50,0,0], [50,50,0]], r = 15),
        ut_round(od = 12, wall = 2));

// or a bender program -- feed, bend, roll
ut_tube(ut_turtle([["feed",60], ["bend",90,"r",24], ["roll",90], ["bend",45,"r",24]]),
        ut_round(id = 8, wall = 2));

// or a branching network whose lumens stay open
ut_assemble(ut_net([trunk, branch],
                   [ut_joint([["trunk", ["s", 50]], ["branch", "a"]])]));
```

See [`examples/`](examples/) — an elbow, a split conduit, a helix, a square bore,
a 4-into-1 manifold, a coaxial jacket, a wall-landing tee.

## Requirements

OpenSCAD 2021.01 or newer. **Nothing else** — uniTube has no dependencies and a
fresh clone renders immediately.

## Layout

```
src/         the library. No file here emits geometry on import.
examples/    runnable demos, one per capability
tests/       assert-only; `just test`
reference/   read-only quarantine of prior art. src/ never imports from here.
docs/        the IR, frames, profiles, junctions, and ADRs
```

## Development

```sh
just            # list recipes
just setup      # verify the toolchain (there is nothing to install)
just check      # CI equivalent: fmt-check + lint + render everything warning-free
just test       # the assert-only subset
just verify     # slow: forced-CGAL manifoldness + the partspec contracts
```

## Credits

The fillet arithmetic derives from a derivation published by Thingiverse user
**axford** ([thing:71464](https://www.thingiverse.com/thing:71464), CC-BY), read
and reimplemented. Full provenance for every retained file is in [`NOTICE`](NOTICE).

## Licence

BSD-2-Clause. See [`LICENSE`](LICENSE).
