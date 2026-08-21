# uniTube

The Universal Tube Library for OpenSCAD.

A **path compiler and a hollow-network assembler**: many ways to describe a tube
centreline, all compiled down to one canonical form, swept as a single polyhedron,
and assembled into branching networks whose bores stay open.

> **Status: under reconstruction.** The library is being rewritten from the
> ground up. See [`PLAN.md`](PLAN.md) for the architecture and the phase plan.
> The previous implementation is in [`reference/axford/`](reference/) and does
> not currently render its bends.

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
just verify     # slow: forced-CGAL manifoldness
```

## Credits

The fillet arithmetic derives from a derivation published by Thingiverse user
**axford** ([thing:71464](https://www.thingiverse.com/thing:71464), CC-BY), read
and reimplemented. Full provenance for every retained file is in [`NOTICE`](NOTICE).

## Licence

BSD-2-Clause. See [`LICENSE`](LICENSE).
