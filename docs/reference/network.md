---
title: Network and port API
parent: Reference
nav_order: 4
---

# Networks and ports — API

Source: `src/ut_net.scad` and `src/ut_port.scad`. For how to use these, see
[`usage/networks.md`](../usage/networks.md).

```scad
run   = ["utrun",   name, path, profile, group, opts]
joint = ["utjoint", at, incident, body, opts]
net   = ["utnet",   runs, joints, opts]
port  = ["utport",  name, p, dir, n, profile, s]
```

Read them through the accessors, not by index.

## Building a network

| | |
|---|---|
| `ut_run(name, path, profile, group = 0, opts = [])` | A named run. `opts` are frame options. A split profile is refused. |
| `ut_joint(incident, body = "ball", at = undef, opts = [])` | A joint of two or more `[runName, end]` entries; `end` is `"a"`, `"b"` or `["s", arclength]`. `body` is `"ball"` or `"none"`. `at` fixes the node. |
| `ut_net(runs, joints = [], opts = [])` | The network. |
| `ut_assemble(net, opts = [])` | Module. Validates with `ut_check_net`, then emits the assembly. `opts = [["preview", "fast"]]` skips the `render()` wrapper. |
| `ut_check_net(net)` | `true`, or asserts one of `NET-0` to `NET-6` ([`checks.md`](checks.md)). |

## Reading a network

| | returns |
|---|---|
| `ut_net_runs(n)`, `ut_net_joints(n)` | the run and joint lists |
| `ut_net_run(net, name)` | the run with that name; asserts if there is not exactly one |
| `ut_groups(net)` | the distinct lumen groups |
| `ut_run_name(r)`, `ut_run_path(r)`, `ut_run_prof(r)`, `ut_run_group(r)`, `ut_run_opts(r)` | a run's fields |
| `ut_joint_incident(j)`, `ut_joint_body(j)`, `ut_joint_at(j)` | a joint's fields; `at` is `undef` unless declared |
| `ut_joint_node(net, j)` | the joint's node: `at`, else the first mid-run landing's point, else the mean of the incident ends |
| `ut_joint_shell_r(net, j)` | the ball's outer radius: the largest incident reach |
| `ut_joint_core_r(net, j)` | the core sphere's radius: the smallest incident bore inradius |

## Ports

| | |
|---|---|
| `ut_ports(net, opts = [])` | Every open end of the network, as port records. |
| `ut_port_named(net, name)` | One open port by name, e.g. `"branch.b"`; asserts if there is none. |
| `ut_port(name, p, dir, n, profile, s)` | The record constructor. |
| `ut_at_port(port)` | Module. Places its children at the port: origin at the end, +Z outward, +X along the roll reference. |
| `ut_port_marker(port, len = 12)` | Module. Debug arrows: outward in red, roll reference in blue. |

| | returns |
|---|---|
| `ut_port_name(p)` | the name |
| `ut_port_pos(p)` | the end point |
| `ut_port_dir(p)` | the outward unit direction |
| `ut_port_normal(p)` | the roll reference |
| `ut_port_profile(p)` | the run's profile |
| `ut_port_s(p)` | arclength at that end |

`src/ut_port.scad` imports nothing, so a terminations library can depend on the
port record alone (ADR 0005).
