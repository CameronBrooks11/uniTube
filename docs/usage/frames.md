# Frames

Frames are computed by uniTube, in exactly one function — `ut_stations(path,
opts)`. Not by the frontend, which has no business deciding roll, and not by the
backend, which has no business guessing it.

| policy | behaviour |
|---|---|
| `frame="transport"` *(default)* | rotation-minimizing; the seam does not spiral relative to the tube |
| `frame="fixed"`, `normal=UP` | the reference is projected orthogonal to the tangent at EVERY station, so the seam points in a fixed WORLD direction |
| `frame=<list>` | one normal per station, projected and asserted non-degenerate |
| `twist=<deg>` | distributed by arclength on top of any of the above |
| `closed=true` | holonomy measured, `symmetry` absorbed, remainder distributed |

## Transport

Per segment kind:

- **L** — the normal is unchanged. Exact.
- **A** — rotate the normal about `cross(u,v)`, the arc's OWN axis, by the arc's
  OWN sweep angle. **Closed form, exact, one line of Rodrigues.** This is the
  payoff of an arc-native IR, and it is
  `reference/axford/half_curvedPipe.scad:19` generalised (`docs/developer/history.md` §2).
- **P** — discrete rotation-minimizing frame between consecutive samples.

Between segments the transport is the identity, because `SPINE-3` guarantees the
tangents already match.

A consequence worth knowing: on a **planar** bend the roll reference is parallel
to the bend axis, and Rodrigues leaves a vector parallel to its axis invariant.
So a planar bend produces **exactly zero twist** — asserted to 1e-12 in
`tests/t_path.scad`, not approximated.

## Fixed, and why it is the right default for a printed part

For a lengthwise-split conduit, `frame="fixed"` is **stronger** than transport,
not merely equivalent. Transport guarantees only that the seam does not spiral
*relative to the tube*. A printed part has a *gravity-relative* requirement: the
gap must face up along the whole run so it prints as an open channel without
bridging. That is `frame="fixed", normal=UP`, and it is one argument.

## The degeneracy that kills naive implementations

Seeding projects a world reference orthogonal to the tangent. When the run starts
**parallel** to that reference — a vertical run against `UP` — the projection is
zero and normalising it gives `[nan,nan,nan]` for every station on that leg.

`ut_ref_fallback()` falls back from `UP` to `BACK`, and from `BACK` to `+X`, when
`|cross(t, ref)| < 1e-6`. Three lines.

### The fallback is a SEED, and using it per-station made it a discontinuity

That fallback is correct for what it was written for: choosing a starting
reference **once**, at station 0, for a transport frame. Used once there is no
discontinuity to create.

`frame="fixed"` derived every station's normal independently, so the fallback
became a **hard switch in the middle of a run**. Measured on the old
`examples/05`: as the conduit turned to vertical the seam jumped **174° in a
single 6° step**. The mesh stayed manifold, CGAL reported `Simple: yes`, `just
check`, `just cgal` and all 19 partspec assertions passed, and the C-section was
simply wrong from that station on.

The projection is smooth to 1e-13 at every approach angle **down to 1° from the
axis** and only breaks *at* it — a cliff, not gradual ill-conditioning. So
`ut_stations()` now refuses the genuinely undefined ask rather than substituting
a different reference for it: a vertical pipe has no upward-facing side.

### Three tests asserted the wrong property

`tests/t_frame.scad` and `tests/t_split.scad` both ended on a vertical leg *on
purpose*, and both asserted that the result was **not NaN**. It is not NaN — the
fallback guarantees that. Finiteness was never the requirement; **continuity**
is, and nothing checked it. `STATION-6` was documented from Phase 1 and enforced
by nothing.

The third was worse. A caller-supplied `frame=<list>` parallel to the tangent
*does* produce `[nan,nan,nan]`, and the assert written to catch it —
`max([for (s = sts) abs(t * n)]) < 1e-9` — **passed**, reporting `2.22e-16`,
because OpenSCAD's `max()` silently drops `nan` entries. Never test a frame for
validity with `max()` alone; count the bad stations instead.

All three are now refused at the cause, and each refusal has a guard in
`tests/guards/` that is watched to fire.

Every angle in the frame path is computed as `atan2(norm(cross(a,b)), a*b)`.
**Never `acos`** — `acos(1.0000001)` is `nan` on 2021.01, and near-collinear
waypoints are the most common input there is.
