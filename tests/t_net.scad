// t_net — the network layer, as PURE DATA. Nothing here renders, and none of it
// depends on $fa/$fs. This is the tier that catches what "Simple: yes" cannot,
// and every silent failure this design was reviewed against passed "Simple: yes".

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

$fa = 12;
$fs = 2;

prof = ut_round(od = 12, id = 8);
big = ut_round(od = 20, wall = 2);

// ============================================ a wall-landing tee
trunk = ut_run("trunk", ut_polyline([ [ -50, 0, 0 ], [ 50, 0, 0 ] ]), big);
branch = ut_run("branch", ut_polyline([ [ 0, 10, 0 ], [ 0, 50, 0 ] ]), prof);
tee = ut_net([ trunk, branch ], [ut_joint([ [ "trunk", [ "s", 50 ] ], [ "branch", "a" ] ])]);

// --- ports are DERIVED FROM GRAPH DEGREE, never declared ---------------------
// A joint-incident end is not a port, so "which ends are open?" is a computed
// fact rather than user bookkeeping.
names = [for (p = ut_ports(tee)) ut_port_name(p)];
assert(len(names) == 3, str("a tee has 3 open ends, got ", len(names), ": ", names));
assert(len([for (n = names) if (n == "branch.a") 1]) == 0, "branch.a is joint-incident and must NOT be a port");
assert(len([for (n = names) if (n == "branch.b") 1]) == 1, "branch.b is open");

// A port still carries a full FRAME, and its direction is OUTWARD.
pb = ut_port_named(tee, "branch.b");
assert(norm(ut_port_pos(pb) - [ 0, 50, 0 ]) < 1e-9, "port position");
assert(norm(ut_port_dir(pb) - [ 0, 1, 0 ]) < 1e-12, "port dir points OUTWARD, exactly");
assert(abs(norm(ut_port_normal(pb)) - 1) < 1e-9, "port carries a unit roll reference");

// --- the joint node sits on the trunk CENTRELINE, not on its wall ------------
// This is the whole reason a mid-run landing is expressible: the node must be
// somewhere the branch bore can be aimed at.
j = ut_net_joints(tee)[0];
node = ut_joint_node(tee, j);
assert(norm(node - [ 0, 0, 0 ]) < 1e-9, str("mid-run landing puts the node on the trunk axis, got ", node));

// --- the joint's two radii are MEASURED from the incident profiles -----------
assert(abs(ut_joint_shell_r(tee, j) - 10) < 1e-9, "shell radius = the farthest incident outer reach (trunk od/2)");
core = ut_joint_core_r(tee, j);
assert(core > 3.9 && core < 4.0, str("core radius = the smallest incident bore inradius (~4), got ", core));
assert(core < ut_joint_shell_r(tee, j), "NET-4: the ball must have a wall");

// --- BOTH shell and bore are extended into the joint -------------------------
// Extending only the bore leaves the shells touching TANGENTIALLY: measured,
// `Simple: yes, Volumes: 3` -- two solids sharing a circle.
sh = _ut_run_stations(tee, branch, "shell");
bo = _ut_run_stations(tee, branch, "bore");
base = ut_stations(ut_run_path(branch));
assert(len(sh) == len(base) + 1, "the shell gains one station at the joint-incident end");
assert(len(bo) == len(base) + 1, "so does the bore");
// The shell reaches the node; the bore goes half a core-radius further.
assert(norm(ut_st_p(sh[0]) - node) < 1e-6, str("shell extension reaches the node, got ", ut_st_p(sh[0])));
assert(norm(ut_st_p(bo[0]) - node) - core / 2 < 1e-6, "bore extension passes the node by half a core radius");
// The extension is COLLINEAR, so it cannot disturb the frame.
assert(ut_turn(ut_st_t(sh[0]), ut_st_t(base[0])) < 1e-9, "extension shares the end tangent exactly");
assert(norm(ut_st_n(sh[0]) - ut_st_n(base[0])) < 1e-9, "and the end roll reference");

// --- the open end is NOT extended -------------------------------------------
assert(norm(ut_st_p(sh[len(sh) - 1]) - [ 0, 50, 0 ]) < 1e-9, "a port end is left exactly where the path put it");

// ============================================ lumen groups
path = ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ], [ 60, 50, 0 ] ], r = 20);
jack = ut_net([
    ut_run("jacket", path, ut_round(od = 30, id = 26), group = 0),
    ut_run("liner", path, ut_round(od = 12, id = 8), group = 1),
]);
assert(len(ut_groups(jack)) == 2, "two lumen groups");
assert(ut_check_net(jack), "a correctly grouped jacket validates");
// Every end is open: no joints, so four ports.
assert(len(ut_ports(jack)) == 4, "a jacket has four open ends");

// ============================================ the 4-into-1 manifold
N = 4;
branches = [for (i = [0:N - 1]) let(th = 360 * i / N) ut_run(
    str("in", i),
    ut_polyline([ [ 50 * cos(th), 50 * sin(th), -55 ], [ 50 * cos(th), 50 * sin(th), -25 ], [ 0, 0, 0 ] ], r = 15),
    prof)];
man = ut_net(concat(branches, [ut_run("out", ut_polyline([ [ 0, 0, 0 ], [ 0, 0, 55 ] ]), ut_round(od = 16, id = 12))]),
             [ut_joint(concat([for (i = [0:N - 1])[str("in", i), "b"]], [[ "out", "a" ]]), at = [ 0, 0, 0 ])]);

assert(ut_check_net(man), "the manifold validates");
mp = [for (p = ut_ports(man)) ut_port_name(p)];
assert(len(mp) == 5, str("the manifold has exactly 5 open ends, got ", len(mp), ": ", mp));
assert(len([for (n = mp) if (n == "out.b") 1]) == 1, "the outlet is open");
assert(len([for (n = mp) if (n == "in0.b") 1]) == 0, "every inlet's joint end is consumed by the joint");
// Five runs meet at one node, and every one of them is extended to reach it.
mj = ut_net_joints(man)[0];
assert(len(ut_joint_incident(mj)) == 5, "five incident ends");
assert(abs(ut_joint_shell_r(man, mj) - 8) < 1e-9, "shell radius = the trunk's od/2, the largest incident reach");

cube(0.001); // sentinel
