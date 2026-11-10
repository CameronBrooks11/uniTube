# Networks and junctions

`union()` two hollow tubes and one tube's **wall** seals the other's **bore** at
the junction. A network is how several hollow runs meet with every bore left
open.

```scad
trunk  = ut_run("trunk",  ut_polyline([[-50,0,0], [50,0,0]]), ut_round(od = 20, wall = 2));
branch = ut_run("branch", ut_polyline([[0,10,0],  [0,50,0]]), ut_round(od = 12, wall = 2));

ut_assemble(ut_net([trunk, branch],
                   [ut_joint([["trunk", ["s", 50]], ["branch", "a"]])]));
```

## Runs, joints, nets

```scad
ut_run(name, path, profile, group = 0, opts = [])
ut_joint(incident, body = "ball", at = undef)
ut_net(runs, joints = [])
ut_assemble(net, opts = [])
```

A **run** is a named path with a profile. `opts` are frame options for that run
([`frames.md`](frames.md)). A split profile cannot be a run.

A **joint** lists the run ends that meet. Each entry is `[runName, end]`, where
`end` is:

| end | meaning |
|---|---|
| `"a"` | the start of the run |
| `"b"` | the end of the run |
| `["s", x]` | a point `x` mm along the run. The run passes through. |

Joints are always declared. Nothing is inferred from two runs happening to
touch, because coincidence cannot find a branch that ends inside a trunk.

The joint's **node** is `at` if you give it. Otherwise it is the first mid-run
landing's point on that run's centreline, or failing that the mean of the
incident end positions.

> **Known issue ([#35]).** An `end` that is none of the three forms is accepted
> and treated as an unjoined `"b"`: the network validates, the end stays an open
> port and its bore is not opened into the joint.

> **Known issue ([#36]).** A solid rod as an unjoined run, and two runs with the
> same name, both abort with a message that names the wrong cause.

## How the bores stay open

For each lumen group, every shell is unioned first and every bore is cut second:

```scad
for (g = ut_groups(net))
  difference() {
    union() { shells of runs in g;  joint shells in g }
    union() { bores  of runs in g;  joint cores  in g }
  }
```

Because the cut comes after all the unions, no run's wall can seal another's
bore. A run's bore is the same path and frames as its shell, swept with the
inner loop of the profile, so nothing is computed twice.

This is the only CSG in the library. Along a run, a tube is one swept
polyhedron.

### Ends are extended into the joint

Each joint-incident `"a"` or `"b"` end is pushed along its own end tangent:

| part | extended |
|---|---|
| shell | to the node |
| bore | half a core radius past the node |

So a branch can be drawn the way a tee is normally described, starting on the
trunk's outer wall, and the assembler carries it to the trunk's centreline.
Extending only the bore is not enough: a branch ending exactly on the trunk's
surface would touch it along a circle and overlap in nothing.

### Joint bodies

| body | what it is |
|---|---|
| `"ball"` *(default)* | a sphere at the node as large as the largest incident outer reach, with a core sphere cut from it as large as the smallest incident bore's inscribed circle |
| `"none"` | no sphere. The runs simply overlap. |

Both radii are measured from the incident profiles, so an arbitrary section
needs no special case.

## Lumen groups

Every run carries a `group`, default 0, and the union-then-cut runs once per
group. Runs that join must share a group. Runs that **nest** — a liner in a
jacket, a tube-in-tube exchanger — must be in different groups, or the outer
bore cuts the inner run away entirely:

```scad
jacket = ut_run("jacket", path, ut_round(od = 30, id = 26), group = 0);
liner  = ut_run("liner",  path, ut_round(od = 12, id = 8),  group = 1);
ut_assemble(ut_net([jacket, liner]));
```

Measured with both in one group: 7883.8 of 29958.5 mm³, 26% of the material,
gone, with CGAL reporting a valid solid.

## What is checked

`ut_assemble` runs `ut_check_net(net)` first. All of it is arithmetic on the
paths and profiles; nothing is rendered.

| check | refuses |
|---|---|
| `NET-0` | any run that fails the single-run checks (a bend radius not greater than the profile's reach) |
| `NET-1` | a run end incident to more than one joint |
| `NET-2` | a joint with an incident run that has no bore |
| `NET-3` | a run end farther from the node than its own reach plus the ball's radius |
| `NET-4` | a ball with no wall. Warns when the wall is under 1.2 mm. |
| `NET-5` | two runs in one group where one fits inside the other's bore and their centrelines come within that bore |
| `NET-6` | a joint whose runs are in different groups |

Notes on two of them:

- **`NET-4` depends on resolution.** Both spheres are faceted, and the wall is
  measured from the outer ball's nearest face to the core's vertices. Two
  `od=20 id=17` runs at `$fn=5` have a 3.1 mm wall by radius and −0.33 mm by
  facet, which is a hole. Raise `$fn` or thicken the wall.
- **`NET-5` is sampled**, 24 points per path, so a crossing that falls entirely
  between samples is not seen. Runs that share a joint are exempt: meeting at a
  joint necessarily brings them within a bore radius.

## Ports

An open end is one that no joint claims. Ports are derived, not declared:

```scad
ports = ut_ports(net);                 // every open end
p     = ut_port_named(net, "branch.b");

ut_at_port(p) my_fitting();            // +Z outward, +X along the roll reference
ut_port_marker(p);                     // debug arrows
```

A port is a full frame, not a position and a diameter:

| accessor | |
|---|---|
| `ut_port_name(p)` | `"run.a"` or `"run.b"` |
| `ut_port_pos(p)` | the end point |
| `ut_port_dir(p)` | unit vector pointing outward, away from the material |
| `ut_port_normal(p)` | the roll reference there, so a hex flat or lug lands repeatably |
| `ut_port_profile(p)` | the run's profile |
| `ut_port_s(p)` | arclength at that end |

For a single run outside a network, use `ut_run_ports(path, prof, name)`.

uniTube ships no threads, barbs or sockets. Terminations are a separate library
that reads this record (ADR 0005, [#19]).

> **Known issue ([#34]).** A closed run reports an `a` and a `b` port although it
> has no ends.

## What this version does not do

- **No fillets.** Junctions are correct and creased. A sharp interior corner is
  a stress riser and shows when printed ([#21]).
- **No branch onto a bend.** Every known filleted-join method needs the base to
  be a plane, a sphere, or a straight cylinder or prism.
- **Thin walls at a shallow crotch are not repaired.** A generous ball and the
  `NET-4` warning are what there is.
- **Mid-run landings** work with `"ball"` and `"none"` only.

## Cost, and previewing

A single run involves no boolean and takes 0.4–60 ms. The junctions cost a CGAL
evaluation: the 4-into-1 manifold renders in about 8 s.

`ut_assemble()` wraps its CSG in `render()`, so preview pays that cost too
(1.9 s for the coaxial jacket). That is deliberate: OpenSCAD's fast preview can
draw a hollow assembly as a solid slug. For a model too heavy to evaluate live,
pass `opts = [["preview", "fast"]]`, and do not trust what that preview shows.
The measurements are in
[`developer/verification.md`](../developer/verification.md).

## Checking a finished part

A valid, manifold solid can still have a sealed bore. To assert that a bore is
open, put a keep-out region down it; `checks/` does this for three examples
with [partspec](https://github.com/CameronBrooks11/partspec). See
[`developer/verification.md`](../developer/verification.md).

[#19]: https://github.com/CameronBrooks11/uniTube/issues/19
[#21]: https://github.com/CameronBrooks11/uniTube/issues/21
[#34]: https://github.com/CameronBrooks11/uniTube/issues/34
[#35]: https://github.com/CameronBrooks11/uniTube/issues/35
[#36]: https://github.com/CameronBrooks11/uniTube/issues/36
