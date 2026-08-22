# uniTube documentation

Start with [`../README.md`](../README.md) for what the library is and how to run
it. This directory is the reference.

## The design

| | |
|---|---|
| [`ir.md`](ir.md) | **Start here.** The two-level path IR — the exact `L`/`A`/`P` spine, the stations it compiles to, all 13 invariants, and the frame policy. Includes a worked elbow you can verify by hand. |
| [`profile.md`](profile.md) | The cross-section, the lumen, split C-sections, and the correspondence rule that keeps end caps from self-intersecting. |
| [`junctions.md`](junctions.md) | How several hollow runs meet without sealing each other's bores: the two-pass, lumen groups, joint bodies, and the limits stated out loud. |
| [`frontends.md`](frontends.md) | The four ways to describe a path, how to choose one, and the measured cost of a sampled path. |
| [`frames.md`](frames.md) | Roll: transport versus fixed, the vertical-tangent degeneracy, and the historical `pipeOrientate` derivation. |
| [`salvage.md`](salvage.md) | What the pre-2026 implementation got right, recorded as understanding rather than code. |
| [`verification.md`](verification.md) | What "check" and "test" mean for CAD: OpenSCAD's real exit codes, the gate tiers, and why `Simple: yes` proves almost nothing. |

## The decisions

Architecture decision records, in [`adr/`](adr/). Each says what was decided, why,
and — where it matters — what was measured.

| | |
|---|---|
| [0001](adr/0001-no-dependencies.md) | uniTube takes no dependencies |
| [0002](adr/0002-two-level-ir.md) | The path IR has two levels — **including the falsification test it later passed** |
| [0003](adr/0003-licence.md) | BSD-2-Clause; prior art quarantined |
| [0004](adr/0004-no-mitres.md) | `r = 0` at an interior vertex is an error |
| [0005](adr/0005-terminations-are-separate.md) | Terminations are a separate library; uniTube ships a port record |
| [0006](adr/0006-profile-correspondence.md) | Profile loops must be correspondence-aligned |
| [0007](adr/0007-open-annulus.md) | A C-section is an open annulus, not one closed loop |

## What is next

Outstanding work, and work deliberately not being done, is tracked in
[GitHub issues](https://github.com/CameronBrooks11/uniTube/issues) rather than in
a file in the repository. Each deferred item carries the reasoning and the
measurements that led to deferring it.

## A note on how to read these

Where a document gives a number — a tolerance, an error, a volume — it was
measured on OpenSCAD 2021.01, not estimated. Where a check exists, it was
validated by deliberately reintroducing the bug it catches; `tests/guards/` holds
those reintroductions, and every one is watched to fail before it is trusted.

That is also the standard for changing anything here: a claim without a
measurement behind it is the thing this library was rebuilt to remove.
