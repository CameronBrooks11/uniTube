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

// ============================================ the port frame IS the swept frame
// ut_ports() used to call _ut_end_station with the DEFAULT opts, while
// ut_assemble sweeps with concat(opts, ut_run_opts(r)). Measured before the fix:
// a run carrying opts=[["twist",90]] reported a port normal 90 degrees from the
// geometry it would be bolted to -- silently, exit 0. A port carrying a FRAME
// rather than a diameter is the entire premise of ADR 0005.
tw = ut_run("tw", ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ] ]), prof, opts = [[ "twist", 90 ]]);
twnet = ut_net([tw]);
pb2 = ut_port_named(twnet, "tw.b");
swept = ut_stations(ut_polyline([ [ 0, 0, 0 ], [ 60, 0, 0 ] ]), [[ "twist", 90 ]]);
assert(ut_turn(ut_port_normal(pb2), ut_st_n(swept[len(swept) - 1])) < 1e-9,
       str("the port frame must equal the frame actually swept; skew was ",
           ut_turn(ut_port_normal(pb2), ut_st_n(swept[len(swept) - 1])), " deg"));

// ============================================ NET-5 and its joint exemption
// NET-5 was an ENDPOINT test until 2026-08-21 and the miss was total. It is now
// a SAMPLED path-distance test, which introduces the opposite hazard: two runs
// meeting at a joint NECESSARILY approach within a bore radius -- that is what a
// joint is -- so without an exemption the check rejects every tee in the library.
// Both directions are asserted here; the negative cases live in tests/guards/.

JK = ut_round(od = 30, id = 26);
LN = ut_round(od = 12, id = 8);

// Correctly grouped: no comparison happens at all, offset or not.
assert(ut_check_net(ut_net([
           ut_run("j", ut_polyline([ [ 0, 0, 0 ], [ 200, 0, 0 ] ]), JK, group = 0),
           ut_run("l", ut_polyline([ [ 70, 0, 0 ], [ 130, 0, 0 ] ]), LN, group = 1),
       ])),
       "a correctly grouped jacket validates whether or not the liner is offset");

// THE EXEMPTION, and it is load-bearing rather than decorative. A BIG trunk whose
// bore comfortably contains a small branch satisfies the nesting precondition,
// and the branch's centreline enters that bore by design. Verified: removing the
// exemption makes exactly this case fail.
bigtee = ut_net(
    [
        ut_run("trunk", ut_polyline([ [ -60, 0, 0 ], [ 60, 0, 0 ] ]), ut_round(od = 40, id = 34)),
        ut_run("branch", ut_polyline([ [ 0, 0, 0 ], [ 0, 60, 0 ] ]), LN),
    ],
    [ut_joint([ [ "trunk", [ "s", 60 ] ], [ "branch", "a" ] ])]);
assert(ut_check_net(bigtee), "a branch that FITS inside its trunk's bore and is JOINED to it must not trip NET-5");

// And the 4-into-1 manifold, five runs meeting at one node, still validates.
assert(ut_check_net(man), "the manifold must not trip NET-5 either");

// ============================================ body = "none"
// A documented joint body with no coverage at all. It emits no sphere, so the
// shells must overlap on their own -- NET-3 is what makes that safe. NET-4 must
// SKIP it: a "none" joint has no ball, so "the ball has no wall" cannot apply,
// and a bodyless joint whose incident bores happen to match the reach would
// otherwise abort on a rule about a sphere that is never emitted.
bare = ut_net(
    [
        ut_run("t2", ut_polyline([ [ -60, 0, 0 ], [ 60, 0, 0 ] ]), ut_round(od = 20, wall = 2.5)),
        ut_run("b2", ut_polyline([ [ 0, 0, 0 ], [ 0, 0, 55 ] ]), ut_round(od = 12, wall = 2)),
    ],
    [ut_joint([ [ "t2", [ "s", 60 ] ], [ "b2", "a" ] ], body = "none")]);
assert(ut_check_net(bare), "a joint with body=\"none\" must validate");
assert(ut_joint_body(ut_net_joints(bare)[0]) == "none", "and it must round-trip through the record");
// Its ends are still consumed by the joint, so neither becomes a port.
assert(len([for (pt = ut_ports(bare)) if (ut_port_name(pt) == "b2.a") 1]) == 0,
       "a bodyless joint still consumes the run ends incident to it");

cube(0.001); // sentinel
