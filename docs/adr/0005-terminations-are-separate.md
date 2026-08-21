# ADR 0005 — Terminations live in a separate library; uniTube ships only a port record

**Status:** accepted (2026-08-21)

## Context

Threads, barbs, clamps, solvent sockets and bayonets are what make a tube
connect to something real. `reference/makrokaba/` (BSD-3) and
`reference/doommeister/` (GPLv3) between them enumerate essentially every style a
v1 fittings library needs.

Two of the four design proposals specified a plug-in protocol: a termination
module taking a port and a `part="shell"|"bore"` selector, which the network
compiler would fold into both passes of the junction difference.

## Decision

uniTube exports a **port record** and a placement module, and stops.

```scad
port = ["utport", name, p, dir, n, profile, s]
module ut_at_port(port) children();   // +Z along dir, +X along n, origin at p
```

Ports are *derived from graph degree*, not declared — a joint-incident end is not
a port. `ut_ports()` is a **function**, so a caller can compute, assert
compatibility, and only then emit geometry. `src/ut_port.scad` has **zero
dependencies**, so a fittings library couples to a data format rather than to a
geometry engine.

Signed off now because both are free now and expensive later:
- `dir` points **outward**, away from the material.
- A port carries a full **frame** (position + outward direction + roll
  reference), not position + diameter. The roll normal is the clocking, so a hex
  flat or bayonet lug lands repeatably.

## Why not the protocol

**It is not expressible in OpenSCAD 2021.01.** Modules are not values, there is
no dynamic dispatch, and `children()` takes no arguments. The obvious
`$`-variable rescue provably fails: assigning a `$`-var twice around two
`children()` calls in one scope warns "was assigned but was overwritten" and
gives **both** calls the last value, because scopes are declarative, not
sequential.

Even the working nested-wrapper form cannot express a termination that
**occludes** the lumen — an orifice restrictor, a valve seat, a blank cap —
because its contribution is unioned into the subtrahend and the plate gets
subtracted away.

## Consequences

- The dependency arrow points one way, forever. A termination is a module that
  emits geometry at the origin pointing +Z, which is already what every
  `create_*_part` in `reference/makrokaba/` does.
- **Known gap, deliberately left open:** a termination that must *merge into the
  tube wall* — a solvent socket, a flange fillet — needs to participate in the
  two-pass, and a bolt-on-at-the-end-plane seam does not support that. The
  two-pass is the right shape for it and the extension is obvious, but it should
  be designed alongside the terminations library, with a real requirement in
  hand, not guessed at now.
