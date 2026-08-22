# uniTube — work queue

**Status:** **Tiers 0-4 complete and merged** (2026-08-21). `PLAN.md` is the
architecture; this is the record of what was found and what was done about it.
The queue below is kept as written, annotated with outcomes.
**Date:** 2026-08-21 · v1 core complete (`PLAN.md` §12) · PRs #4-#9 merged

Produced by a 5-agent review (independent gap audit, biarc design, release
readiness, sequencing, adversarial challenge) and then re-verified. **Every
number in §1 and §2 I reproduced myself on this machine** — the agents found
them, but nothing below is taken on their word.

---

## 1. Six confirmed bugs, all silent, all in the flagship capability

These were not on any tracked list. Each is *silent wrong geometry* — the exact
class this project exists to kill — and each renders `Simple: yes`.

### 1.1 `ut_assemble` never runs `ut_check` — CHECK-1 does not exist for networks

`ut_tube` opens with `assert(ut_check(path, prof))`. `ut_assemble` opens with
`assert(ut_check_net(net))`, and `ut_check_net` is NET-1..5 only. It never calls
`ut_check`.

Identical geometry, `od=12` (reach 6) through an `r=5.5` bend:

| entry point | result |
|---|---|
| `ut_tube` | **aborts** — `CHECK-1: bend radius 5.5 is not greater than the profile's outer reach 6` |
| `ut_assemble` | `ut_check_net` → `true`, exit 0, `Simple: yes`, Volumes 2 |

Examples 06, 08 and 10 — the network examples, the flagship — all forfeit the
check. `tests/guards/g_check_bend.scad` proves the check works *through one entry
point only*. **~5 lines + a guard.**

### 1.2 `ut_ports` ignores `ut_run_opts` — port clocking up to 90° wrong

`ut_ports` calls `_ut_end_station(r, end)` with the default `opts=[]`, while
`ut_assemble` sweeps with `concat(opts, ut_run_opts(r))`.

With `ut_run(..., opts=[["twist",90]])`:

```
PORT normal  = [0, 0, 1]
SWEPT normal = [0, -1, 0]
SKEW         = 90 degrees
```

A port carrying a **frame** rather than a diameter is the entire premise of
ADR 0005 and the terminations story. `tests/t_curve.scad` prices 2.2° at ~0.8 mm
across a 20 mm flange; 90° is a part that cannot be assembled. `ut_run_opts` is
the only place a network run can carry a roll policy, so this fires on the
intended usage. **~2 lines + a test.**

### 1.3 NET-5's endpoint heuristic misses any offset nesting — 100% material loss

`_ut_nests` compares *endpoints only*. Slide a liner 70 mm along a shared axis
and it is invisible:

| | volume |
|---|---|
| both in group 0 (wrong) | 35007.7 mm³ |
| correctly grouped | 38741.0 mm³ |
| **lost** | **3733.3 mm³ — exactly 100% of the liner, 9.6% of the assembly** |

`ut_check_net` returns `true`. This is bit-for-bit the bug `examples/08` and
`g_net5_nesting.scad` exist to prevent, reached by sliding one run along the
other. **See §4 — the obvious fix has a false-positive problem.**

### 1.4 A joint whose runs are in different lumen groups is accepted

`_ut_joints_in` assigns a joint to the group of its *first* incident run; no
invariant requires the others to agree. An elbow with `group=0` and `group=1`:

| | volume |
|---|---|
| same group (correct) | 4924.3 mm³ |
| across two groups | 5103.2 mm³ |
| **extra material obstructing the junction** | **+178.9 mm³ (+3.6%)** |

`ut_check_net` → `true`, `Simple: yes`. Groups are the user's job by design, so a
mis-declared group is the *expected* user error — and NET-5 already guards the
opposite mistake. Needs **NET-6, ~5 lines + a guard.**

### 1.5 A typo in `part=` silently renders the bore

The selector's final `else` is unguarded:

```
solid = 3701.57   shell = 6662.83   bore = 2961.26
part="wall"  -> 2961.26      <- the BORE
part="Shell" -> 2961.26      <- the BORE
```

`--hardwarnings` catches an unknown *argument name* (the `torusSlice` class) but
not an unknown *value*. **~2 lines + a guard.**

### 1.6 `ut_profile` accepts an inner loop outside the outer — negative volume

`docs/profile.md` states PROF-1 includes "inner's bounding box is strictly inside
outer's". Nothing asserts it. `ut_profile(ut_ring(4,N), ut_ring(6,N))`:

```
accepted.  ut_check says: true.  volume = -3105.83
```

An inside-out mesh with negative volume, and the library's own validator passes
it. **~3 lines + a guard.**

---

## 2. The gate itself has a hole

**`just cgal` passes a model CGAL choked on.** Its only pass criterion is
`grep -q 'Simple: *yes'`; it never greps for errors. Reproduced — a self-
intersecting network run produces a log containing *both*:

```
ERROR: CGAL error in CGALUtils::applyBinaryOperator difference: CGAL ERROR: assertion violation!
   Simple:        yes
```

openscad exits 0, and the recipe reports **`ok`**. `AGENTS.md` already says
`Simple: yes` is "necessary and nowhere near sufficient" — the recipe does not
implement its own rule. **~2 lines.**

Two further coverage holes from the audit (not independently re-verified):

- **The warning tier has zero coverage** — CHECK-2, CHECK-3 and NET-4-thin are
  `echo()` calls, and `tests/guards/` structurally cannot cover a warning.
  Silencing all three would pass every gate.
- **Six existing asserts have no negative test**, including **NET-2** — which
  `PLAN.md` §6 calls "the most important test in the library".

---

## 3. Biarc fitting: the billing in `PLAN.md` §10 is wrong

`PLAN.md` calls it "the single highest-value deferred item" because a `P` segment
forfeits exact arclength, exact transport, and CHECK-1. **Two of those three do
not survive measurement**, and the one real defect a fitter *would not fix* is
fixable in one line.

| billed benefit | measured worth |
|---|---|
| exact arclength | 0.025% at n=160 — **0.19 mm on a 758 mm helix**, and `s` is only ever used as a *ratio* (`s_i/s_last`), so a uniform shrink cancels exactly |
| exact transport | **0.04°** end-normal error, clean second order |
| CHECK-1 on a `P` segment | **a real hole** — a self-intersecting swept helix renders `Simple: yes` — but closed by ~8 lines of discrete curvature, at the same accuracy |

**The one error large enough to ruin a physical part is the end tangent, and a
fitter inherits it** (it derives span tangents from the same estimator).
A three-point one-sided difference fixes it outright. Verified:

| n | 2-point (current) | 3-point (proposed) |
|---|---|---|
| 40 | 8.949° | 0.460° |
| 80 | 4.475° | 0.0731° |
| **160** | **2.237°** | **0.0141°** |
| 320 | 1.119° | 0.0032° |

Current is first-order (halves with n); proposed is second-order (quarters).
**159× better at n=160, for one line.**

### The argument that *is* real, and is written down nowhere

**Resolution independence.** `docs/ir.md` states `SPINE-5 | no roll, no
resolution`. `ut_curve` bakes `n` into the spine. Verified:

| path | `$fa=24, $fs=4` | `$fa=0.5, $fs=0.1` |
|---|---|---|
| arc-based (`ut_polyline`) | 7 stations | 183 stations |
| sampled (`ut_curve`) | **161** | **161** |

`$fa`/`$fs` are **inert** on a sampled path. So **SPINE-5 is false for `P`
segments** — a stated invariant that does not hold, in a library whose thesis is
that stated-but-unenforced things are the enemy.

**Verdict: defer the fitter, ship the 9 lines, and fix SPINE-5 where it lives**
(`docs/ir.md` and ADR 0002 — *not* by rewriting `PLAN.md` §10). Either narrow the
invariant to say `P` segments carry their sampling, or accept shipping a false
row in the invariant table.

A working 47-line prototype exists but is in a **session-scoped scratch
directory** and will be lost. Preserve it or discard it deliberately.

---

## 4. `NET-5` — RESOLVED 2026-08-21

The obvious fix — sample both paths and compare distances — **false-positives on
every tee**. Two runs that meet at a joint necessarily approach within a bore
radius; that is what a joint *is*. The adversary implemented it and a normal
trunk-and-branch tee tripped it.

**Resolved: sampled path distance, with joint-sharing pairs exempt.** The
exemption was proven load-bearing rather than assumed — a tee whose trunk bore
comfortably contains its branch fails without it. Six cases are covered, three
positive and three negative; see `tests/t_net.scad` and
`tests/guards/g_net5_offset_nesting.scad`.

Two limits are documented in `docs/junctions.md` rather than hidden: the test is
sampled (k=24), so a crossing entirely between samples is unseen; and it only
fires when the inner run *fits* inside the outer's bore, which is what separates
nesting from an ordinary junction.

---

## 5. The queue

**Tiers 0–2 are a pool, not a chain.** Their items touch disjoint files
(`ut_net`, `ut_port`, `ut_mesh`, `ut_profile`, `ut_curve`, `ut_polyline`) with no
shared state; ordering them 1..n would be false precision. Only Tier 3 has a real
sequence: fix things → describe the repo → tag it.

### Tier 0 — the bugs (~1 day total; most are a handful of lines)

| # | item | size |
|---|---|---|
| 0.1 | `ut_check_net` runs `ut_check` per run — **§1.1** | 5 lines + guard |
| 0.2 | `ut_ports` honours `ut_run_opts` — **§1.2** | 2 lines + test |
| 0.3 | NET-6: joint-incident runs share a lumen group — **§1.4** | 5 lines + guard |
| 0.4 | Validate `part=` — **§1.5** | 2 lines + guard |
| 0.5 | PROF-1 containment assert — **§1.6** | 3 lines + guard |
| 0.6 | `just cgal` fails on `CGAL error` — **§2** | 2 lines |

*Exit:* every one has a guard built by reintroducing the bug, and the guard is
watched to fail before it is trusted. Then `just partspec` re-run — ~20 new
asserts land across five modules and nothing currently checks the contracts still
pass.

### Tier 1 — close the `ut_curve` exemption (~half a day)

| # | item | size |
|---|---|---|
| 1.1 | Three-point one-sided end tangents — **§3**, 159× | **1 line** |
| 1.2 | Discrete-curvature CHECK-1 for `P` segments | ~8 lines + guard |

*Exit:* a self-intersecting swept helix that renders `Simple: yes` today aborts.

### Tier 2 — make the documents true (~half a day)

| # | item |
|---|---|
| 2.1 | **README is false** — still says "does not currently render its bends" |
| 2.2 | `SPINE-5` in `docs/ir.md` + ADR 0002 — narrow it, or admit `P` violates it |
| 2.3 | Correct `PLAN.md` §10's biarc row; drop `ut_curve.scad`'s "restores all three" |
| 2.4 | `docs/junctions.md` — NET-5's real blind spot (§4) |
| 2.5 | Preserve or discard the biarc prototype deliberately |
| 2.6 | `ut_polyline` first-use guards: `r=0` is the function's own **default** and ADR 0004 says it must be an error |

2.6 is the highest user-facing value per hour in the whole queue — it is the
first mistake a newcomer makes.

### Tier 3 — go public (ordered; ~1 day)

| # | item | note |
|---|---|---|
| 3.1 | CI: one Actions job, `just check && just test` | pin clang-format — local 18.1.8 vs runner 18.1.3; a formatter minor bump would red the build for nobody's benefit |
| 3.2 | Warning-tier coverage + guards for the six untested asserts, incl. **NET-2** | §2 |
| 3.3 | Housekeeping: 4 dead helpers, `00_smoke` retire, `_ut_samples_P` O(n²) | |
| 3.4 | README first screen, `docs/README.md` index, install story | after 3.3 |
| 3.5 | Tag `v0.1.0` | **decision** — see §6 |

Flip repo visibility at 3.1 if it is private: visibility is free and reversible,
the tag is the commitment.

---

## 6. Decisions — all settled, all acted on

1. **Closed paths — wire up or delete?** *(recommend: wire up, minimally.)*
   ~80% built and **verified working** — a closed 4-arc torus gives exact length
   376.991 and holonomy residual **exactly 0**. But no frontend can reach it and
   there is zero coverage. Minimal resolution: reachable through `ut_spine` only,
   one test, one example, and the other frontends keep refusing it explicitly.
   The audit also found closed paths emit a **duplicate final station** —
   a STATION-1 violation plus a ring of degenerate triangles — so this is a small
   real fix, not just plumbing. Wiring `closed` through all four frontends is
   days and each raises its own question (what *is* a closed turtle program?).
   > yes wire them up minimally

2. **NET-5: exempt joint-sharing pairs, or document the blind spot?**
   *(recommend: document now, exempt later.)* §4. The patch is small; getting it
   wrong makes every tee fail.
   > document the blind spot now, exempt later

3. **`v0.1.0` now, or after closed paths?** *(recommend: now, after Tiers 0-3.)*
   `0.x` promises nothing. Shipping the six bug fixes matters more than feature
   completeness, and asserts are free to add until someone depends on you.
   > no rush, lets get this done then we will talk about tag release

4. **Biarc — confirm the deferral?** *(recommend: yes, per §3.)* And with it:
   preserve the prototype as `docs/adr/0008-biarc-fitting.md` or a `spikes/`
   directory, or delete it and accept rebuilding later.
   > yes, defer biarc and preserve the prototype

5. **`reference/jantecnl/` — keep or delete?** *(recommend: delete.)* It has no
   licence of any kind. Only its run coordinates were ever used, and those now
   live in `examples/06`. It was kept as a historical record; that record is now
   in `docs/salvage.md` and the git history.
   > delete `reference/jantecnl/`

---

## 7. Explicitly not doing

Junction fillets (`PLAN.md` already calls this "the seductive item"), profile
variation, multi-lumen profiles, the terminations library, `ut_route`/`ut_bezier`/
combinators/`ut_bend_table`, a full API reference, package metadata (no tool reads
it), and `1.0.0`.

Reasoning for each is in `PLAN.md` §10 and unchanged — except biarc, whose
reasoning is corrected in §3 above.


---

## 8. Outcome

All five tiers merged as PRs #5-#9. `main` is green on `check`, `test`, `cgal`,
`warnings` and `partspec`, and **CI now runs all five on every push** (1m34s).

| tier | what shipped |
|---|---|
| 0 | Five silent-wrong-geometry bugs closed, plus the `cgal` gate that hid them. Each reproduced first, each held by a guard built from that reproduction. |
| 1 | `ut_curve`'s end tangents made second order (**2.237° → 0.0141°** at n=160, one line) and CHECK-1 extended to sampled paths via discrete curvature. |
| 2 | Documents made true: `SPINE-5` recorded as a limit rather than claimed, biarc billing corrected, NET-5's blind spot documented, README fixed. Three first-use guards in `ut_polyline`. `reference/jantecnl/` deleted. Biarc prototype preserved in `spikes/`. |
| 3 | Closed paths reachable through `ut_spine`, with the STATION-7 duplicate-station fix: **88 degenerate triangles → 0**. |
| 4 | CI, the warning tier under a gate, five previously untested asserts guarded (including **NET-2**), dead code removed, `docs/README.md`. |

**Guards: 17 → 31.** Every one is watched to fail before it is trusted.

### What remains, unchanged

Everything in §7, plus:

- **Biarc fitting** — deferred with its billing corrected (§3). The prototype is
  at `spikes/biarc_fitter.scad` with the measurements that demoted it. The one
  argument that would justify building it is resolution independence, now
  recorded as a stated limit on `SPINE-5` in `docs/ir.md`.
- **A release tag** — deliberately not taken. To be discussed.
