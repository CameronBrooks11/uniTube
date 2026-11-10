# Checks, errors and warnings

uniTube validates the description of a part before drawing it. The checks are
arithmetic on paths and profiles: nothing is rendered, and CGAL calling a result
a valid solid is not one of them.

An **error** is an OpenSCAD `assert`: the render stops and the message names the
offending element. A **warning** is a console line beginning
`ECHO: "WARNING [uniTube]` and does not stop anything. OpenSCAD's
`--hardwarnings` flag does not promote these, because they are echoes.

## Entry points

| | |
|---|---|
| `ut_check(path, prof)` | Runs `CHECK-1` to `CHECK-3` on one run. Returns `true` or asserts. `ut_tube` calls it. |
| `ut_check_net(net)` | Runs `NET-0` to `NET-6`. Returns `true` or asserts. `ut_assemble` calls it. |

Both return `true` so they can sit inside your own `assert(...)`.

## Runs

| code | kind | condition | fix |
|---|---|---|---|
| `CHECK-1` | error | A bend's radius is not greater than the profile's outer reach, so the tube passes through itself. Exact on arcs; on a sampled path it is estimated from three-point curvature and can miss a marginal case. | Increase the bend radius or use a smaller section. |
| `CHECK-2` | warning | An arc's radius is less than one outside diameter. Legal, tight to print. | None needed. |
| `CHECK-3` | warning | The wall is below `ut_min_wall()`, 1.2 mm. It can render perfectly and print as a hole. | Thicken the wall, if the part is printed. |

`CHECK-2` and `CHECK-3` judge every run as a printed part. There is no way yet to
mark a run as bought stock ([#30]).

## Profiles

Raised by `ut_profile`, and so by `ut_round` and `ut_rod`.

| code | condition |
|---|---|
| `PROF-1` | The outer loop, or the inner loop, is not counter-clockwise. |
| `PROF-1` | The inner loop is not strictly inside the outer loop at every angle. |
| `PROF-2` | The loops have different point counts. |
| `PROF-2` | `outer[i]` and `inner[i]` are not at the same angle from the centre. |

`PROF-3` is the thin-wall rule; it is reported as `CHECK-3`. See
[`usage/profiles.md`](../usage/profiles.md).

## Paths and frames

| code | condition |
|---|---|
| `SPINE-2` | A segment does not start where the previous one ends (gap over 1e-6). |
| `SPINE-3` | The tangent is discontinuous between two segments: a sharp corner. |
| `STATION-6` | The roll frame turns over 45° more than the tangent between two stations: the frame has flipped. |
| `frame="fixed"` | A station's tangent is within 0.5° of the fixed normal. |
| `frame=<list>` | A supplied normal is within 0.5° of its station's tangent. |

Each frontend and constructor also refuses malformed input with a message that
starts with its own name, for example `ut_polyline(): fillet radii do not fit on
the leg from ...`. Those are listed with the frontends in
[`usage/paths.md`](../usage/paths.md). The invariants behind the `SPINE` and
`STATION` codes are in [`ir.md`](ir.md).

## Networks

| code | kind | condition | fix |
|---|---|---|---|
| `NET-0` | error | A run fails `ut_check`. Reported as `CHECK-1`. | As above. |
| `NET-1` | error | A run end is incident to more than one joint. | Merge the joints. |
| `NET-2` | error | A run at a joint has no bore. | A rod cannot join; use a hollow profile. |
| `NET-3` | error | A run end is farther from the joint node than its reach plus the ball's radius. | Move the end nearer the node, or set `at`. |
| `NET-4` | error | The joint ball has no wall between the outer ball's facets and the core sphere. | Raise `$fn`, or thicken the wall. |
| `NET-4` | warning | That wall is below 1.2 mm. | The same. |
| `NET-5` | error | Two runs in one group nest: one fits in the other's bore and their centrelines come that close. | Give the inner run its own `group`. |
| `NET-6` | error | The runs at a joint are in different groups. | Put them in one group. |

See [`usage/networks.md`](../usage/networks.md).

## Known gaps

Some wrong input is not yet refused, or is refused with a misleading message:

- An unknown `frame` value, option key or joint end is accepted ([#35]).
- A rod in a network, duplicate run names and a zero `dfdt` abort naming the
  wrong cause ([#36]).
- `twist` over a straight leg, and on a closed path, produces wrong geometry
  without a message ([#33], [#34]).

[#30]: https://github.com/CameronBrooks11/uniTube/issues/30
[#33]: https://github.com/CameronBrooks11/uniTube/issues/33
[#34]: https://github.com/CameronBrooks11/uniTube/issues/34
[#35]: https://github.com/CameronBrooks11/uniTube/issues/35
[#36]: https://github.com/CameronBrooks11/uniTube/issues/36
