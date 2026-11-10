---
title: Developer
nav_order: 6
has_children: true
---

# Developer

How the library is verified, why it is built the way it is, and what was
learned getting there.

| | |
|---|---|
| [Verification](verification.md) | What "check" and "test" mean for CAD: OpenSCAD's exit codes, the gate tiers, and why a valid solid proves little. |
| [History](history.md) | What the pre-2026 implementation got right, and the defects found since the rewrite. |
| [Decisions](../adr/index.md) | The architecture decision records. |

Where a page gives a number, it was measured on OpenSCAD 2021.01. Where a check
exists, it was validated by reintroducing the bug it catches; `tests/guards/`
holds those reintroductions.

Outstanding and deliberately deferred work is tracked in
[GitHub issues](https://github.com/CameronBrooks11/uniTube/issues), not in a
file.

## Working on the library

```sh
just            # list recipes
just setup      # verify the toolchain
just check      # the commit gate: format, lint, guards, warnings, preview, renders
just test       # the assert-only tests
just verify     # slow: forced-CGAL manifoldness and the partspec contracts
```

The project rules are in
[`AGENTS.md`](https://github.com/CameronBrooks11/uniTube/blob/main/AGENTS.md).
Licence and provenance are in
[`NOTICE`](https://github.com/CameronBrooks11/uniTube/blob/main/NOTICE).
