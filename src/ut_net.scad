// ut_net — the hollow-network assembler.
//
// This is the part no library provides, and the part three previous attempts in
// this repository died on. The problem in one line: union() two hollow tubes and
// branch B's WALL seals branch A's LUMEN at the junction.
//
// THE RULE — the two-pass, scoped to a lumen group:
//
//     for g in groups:
//       difference() {
//         union() { shells of runs in g;  joint shells in g }
//         union() { bores  of runs in g;  joint cores  in g }
//       }
//
// The subtraction happens once per group, AFTER all unions in that group, so B's
// shell cannot seal A's lumen: B's shell is unioned before A's bore is cut, and
// A's bore always wins. This is the inherited TODO at
// the 2023 prototype (removed; see docs/salvage.md §4), promoted from a comment to
// an architectural invariant -- and it already ships, in the wrong file, as
// reference/doommeister/Round_Ducting_V1.1.scad:168 middle_tee_n.
//
// Three things make it actually work, each forced by a counterexample that
// rendered as `Simple: yes`:
//
//   1. THE BORE COMES FREE. Same spine, same stations, same frame, different
//      region (ut_profile.scad). The 2023 attempt modelled the lumen as a
//      separate subtraction, so its second pass had to re-derive the bend
//      geometry and called torusSlice_only_inner_pipes() -- a module git log -S
//      confirms was never defined in any commit.
//   2. PER-JOINT BORE OVERLAP, NOT A GLOBAL EPSILON. A branch that stops on the
//      trunk WALL leaves a plug across its own lumen. The depth needed is a
//      function of the mating run's geometry, which is topology -- so joints are
//      DECLARED, never inferred from coincidence.
//   3. LUMEN GROUPS. With one global difference, a coaxial jacket's outer bore
//      swallows the inner tube entirely.

// clang-format off
use <ut_core.scad>;
use <ut_math.scad>;
use <ut_path.scad>;
use <ut_profile.scad>;
use <ut_mesh.scad>;
use <ut_port.scad>;
use <ut_check.scad>;
// clang-format on

// =============================================================== records

//   run   = ["utrun",   name, path, profile, group, opts]
//   joint = ["utjoint", at, incident, body, opts]
//   net   = ["utnet",   runs, joints, opts]
//
// An incident entry is [runName, end] where end is "a", "b" or ["s", arclength].
// "a"/"b" are run ENDS and get their bores extended; ["s", x] is a MID-RUN
// landing -- the run passes through and is not extended.

function ut_run(name, path, profile, group = 0, opts = []) = assert(is_string(name), "ut_run(): name must be a string")
    assert(!ut_prof_open(profile),
           str("ut_run(\"", name,
               "\"): a split (open) profile has no enclosed lumen, so it cannot take part in a network"))["utrun", name,
                                                                                                          path, profile,
                                                                                                          group, opts];

function ut_joint(incident, body = "ball", at = undef,
                  opts = []) = assert(len(incident) >= 2, "ut_joint(): a joint needs at least two incident run ends")
    assert(body == "ball" || body == "none",
           str("ut_joint(): body must be \"ball\" or \"none\", got \"", body,
               "\". Fillets are not in this version -- see docs/junctions.md."))["utjoint", at, incident, body, opts];

function ut_net(runs, joints = [], opts = []) = [ "utnet", runs, joints, opts ];

function ut_run_name(r) = r[1];
function ut_run_path(r) = r[2];
function ut_run_prof(r) = r[3];
function ut_run_group(r) = r[4];
function ut_run_opts(r) = r[5];

function ut_joint_at(j) = j[1];
function ut_joint_incident(j) = j[2];
function ut_joint_body(j) = j[3];

function ut_net_runs(n) = n[1];
function ut_net_joints(n) = n[2];

function ut_net_run(net, name) = let(hit = [for (r = ut_net_runs(net)) if (ut_run_name(r) == name) r])
    assert(len(hit) == 1, str("ut_net: no run named \"", name, "\"")) hit[0];

// =============================================================== geometry helpers

// The largest sphere that fits inside a profile's bore, and the farthest the
// outer surface reaches. Both measured from the OUTLINE, never assumed from od.
function ut_bore_inradius(prof) = ut_prof_hollow(prof) ? min([for (q = ut_prof_inner(prof)) norm(q)]) : 0;

// The station at one end of a run, and the outward direction there.
function _ut_end_station(run, end, opts = []) = let(sts = ut_stations(ut_run_path(run), opts), N = len(sts)) end == "a"
                                                    ? sts[0]
                                                    : sts[N - 1];
function _ut_end_pos(run, end, opts = []) = is_list(end) ? ut_at(ut_run_path(run), end[1])[0]
                                                         : ut_st_p(_ut_end_station(run, end, opts));
// Outward: away from the material at that end.
function _ut_end_dir(run, end, opts = []) = is_list(end) ? undef
                                                         : (end == "a" ? -ut_st_t(_ut_end_station(run, end, opts))
                                                                       : ut_st_t(_ut_end_station(run, end, opts)));

// The joint node. Declared if given; otherwise a mid-run landing defines it
// (the node sits on the trunk's CENTRELINE), else the mean of the incident ends.
function ut_joint_node(net, j) = !is_undef(ut_joint_at(j)) ? ut_joint_at(j)
                                 : let(inc = ut_joint_incident(j), mids = [for (e = inc) if (is_list(e[1]))
                                                                           _ut_end_pos(ut_net_run(net, e[0]), e[1])])
                                             len(mids) > 0
                                     ? mids[0]
                                     : _ut_mean([for (e = inc) _ut_end_pos(ut_net_run(net, e[0]), e[1])]);
function _ut_mean(v) = _ut_vsum(v, 0) / len(v);
function _ut_vsum(v, i) = i >= len(v) ? [ 0, 0, 0 ] : v[i] + _ut_vsum(v, i + 1);

// The joint's two radii, both derived from the incident profiles.
//   shell = the farthest any incident run's outer surface reaches
//   core  = the largest sphere guaranteed inside EVERY incident bore
function ut_joint_shell_r(net,
                          j) = max([for (e = ut_joint_incident(j)) ut_prof_reach(ut_run_prof(ut_net_run(net, e[0])))]);
function ut_joint_core_r(net, j) = min([for (e = ut_joint_incident(j))
        ut_bore_inradius(ut_run_prof(ut_net_run(net, e[0])))]);

// Every joint touching this run end, if any.
function _ut_joints_at(net, name, end) =
    [for (j = ut_net_joints(net)) if (len([for (e = ut_joint_incident(j)) if (e[0] == name && e[1] == end) 1]) > 0) j];

// =============================================================== ports

// An open end is one incident to NO joint. Ports are DERIVED FROM GRAPH DEGREE,
// never declared -- so "which ends are open?" is a computed fact.
function ut_ports(net, opts = []) = [for (r = ut_net_runs(net),
                                          end = [ "a", "b" ]) if (len(_ut_joints_at(net, ut_run_name(r), end)) == 0)
        let(st = _ut_end_station(r, end, concat(opts, ut_run_opts(r))), path = ut_run_path(r))
            ut_port(str(ut_run_name(r), ".", end), ut_st_p(st), end == "a" ? -ut_st_t(st) : ut_st_t(st), ut_st_n(st),
                    ut_run_prof(r), end == "a" ? 0 : ut_length(path))];

function ut_port_named(net, name) = let(hit = [for (p = ut_ports(net)) if (ut_port_name(p) == name) p])
    assert(len(hit) == 1, str("ut_port_named: no open port \"", name, "\"")) hit[0];

// =============================================================== bore extension

// How far a run end must be pushed past itself to reach into the joint.
//
// BOTH the shell and the bore are extended. Extending only the bore leaves a
// branch whose end sits ON the mating surface touching it TANGENTIALLY -- the
// shells share a circle and overlap in nothing, and the assembly renders as
// separate volumes. Measured: a branch starting exactly on a trunk of the same
// radius gave `Simple: yes, Volumes: 3`.
//
// The shell reaches the node. The bore goes half a core-radius further, so it is
// safely inside the joint's core sphere without over-running into the far wall.
// The extension is collinear with the end tangent, so it adds no curvature and
// cannot disturb the frame.
function _ut_extension(net, run, end, part) = let(js = _ut_joints_at(net, ut_run_name(run), end)) len(js) == 0 ? 0
                                              : let(node = ut_joint_node(net, js[0]), p = _ut_end_pos(run, end),
                                                    d = norm(node - p)) part
                                                      == "bore"
                                                  ? d + ut_joint_core_r(net, js[0]) / 2
                                                  : d;

// Stations for one sweep, extended at any joint-incident end.
function _ut_run_stations(net, run, part, opts = []) =
    let(sts = ut_stations(ut_run_path(run), opts), N = len(sts), da = _ut_extension(net, run, "a", part),
        db = _ut_extension(net, run, "b", part),
        head = da <= ut_eps()
                   ? []
                   : [[ut_st_p(sts[0]) - da * ut_st_t(sts[0]), ut_st_t(sts[0]), ut_st_n(sts[0]), ut_st_s(sts[0]) - da]],
        tail = db <= ut_eps() ? []
                              : [[ut_st_p(sts[N - 1]) + db * ut_st_t(sts[N - 1]), ut_st_t(sts[N - 1]),
                                  ut_st_n(sts[N - 1]), ut_st_s(sts[N - 1]) + db]]) concat(head, sts, tail);

// =============================================================== groups

function ut_groups(net) = _ut_uniq([for (r = ut_net_runs(net)) ut_run_group(r)]);
function _ut_uniq(v, i = 0, acc = [
]) = i >= len(v) ? acc : _ut_uniq(v, i + 1, len([for (a = acc) if (a == v[i]) 1]) > 0 ? acc : concat(acc, [v[i]]));

function _ut_runs_in(net, g) = [for (r = ut_net_runs(net)) if (ut_run_group(r) == g) r];
function _ut_joints_in(net, g) =
    [for (j = ut_net_joints(net)) if (ut_run_group(ut_net_run(net, ut_joint_incident(j)[0][0])) == g) j];

// =============================================================== emission

// Assemble the network. CSG appears in exactly ONE place in this library, and
// this is it.
module ut_assemble(net, opts = [])
{
    assert(ut_check_net(net));
    for (g = ut_groups(net))
    {
        difference()
        {
            union()
            {
                for (r = _ut_runs_in(net, g))
                    ut_sweep(ut_shell_rgn(ut_run_prof(r)),
                             _ut_run_stations(net, r, "shell", concat(opts, ut_run_opts(r))),
                             ut_closed(ut_run_path(r)));
                for (j = _ut_joints_in(net, g))
                    if (ut_joint_body(j) == "ball")
                        translate(ut_joint_node(net, j)) sphere(r = ut_joint_shell_r(net, j));
            }
            union()
            {
                for (r = _ut_runs_in(net, g))
                    ut_sweep(ut_bore_rgn(ut_run_prof(r)),
                             _ut_run_stations(net, r, "bore", concat(opts, ut_run_opts(r))), ut_closed(ut_run_path(r)));
                for (j = _ut_joints_in(net, g))
                    if (ut_joint_body(j) == "ball")
                        translate(ut_joint_node(net, j)) sphere(r = ut_joint_core_r(net, j));
            }
        }
    }
}

// =============================================================== NET checks
//
// All analytic, all on the IR as pure data, none requiring a render. This is the
// tier that catches what "Simple: yes" cannot -- and every silent failure this
// design was reviewed against passed "Simple: yes".

// NET-1 — every run end is either a degree-1 PORT or incident to EXACTLY ONE
// joint. Joints are never synthesised from geometric coincidence: coincidence
// cannot find a branch that terminates INSIDE a trunk, and a synthesised joint
// has nowhere to hang an overlap depth.
function _ut_net1(net) = let(bad = [for (r = ut_net_runs(net),
                                         end = [ "a", "b" ]) if (len(_ut_joints_at(net, ut_run_name(r), end)) > 1)
                                     str(ut_run_name(r), ".", end)])
    assert(len(bad) == 0, str("NET-1: these run ends are incident to more than one joint: ", bad)) true;

// NET-2 — LUMEN PATENCY. Every incident run must have a bore for the joint's
// core sphere to connect to. This is the check the whole project exists to make
// possible: a sealed branch lumen renders as `Simple: yes, Volumes: 2` and
// passes a naive manifoldness regression test.
function _ut_net2(net) = let(bad = [for (j = ut_net_joints(net)) if (ut_joint_core_r(net, j) <= ut_eps())
                                     str("joint at ", ut_joint_node(net, j), " has an incident run with no bore")])
    assert(len(bad) == 0, str("NET-2 (lumen patency): ", bad, ". A run with no lumen cannot join to anything.")) true;

// NET-3 — the shells must actually MEET. A branch declared incident to a joint
// but placed beyond reach of it floats free, and the assembly renders as
// separate volumes held together by nothing.
function _ut_net3(net) =
    let(bad = [for (j = ut_net_joints(net), e = ut_joint_incident(j))
                let(r = ut_net_run(net, e[0]), node = ut_joint_node(net, j), p = _ut_end_pos(r, e[1]),
                    gap = norm(node - p) - ut_prof_reach(ut_run_prof(r)) - ut_joint_shell_r(net, j)) if (gap > 0)
                    str(e[0], ".", e[1], " is ", gap, " mm short of the joint at ", node)])
        assert(len(bad) == 0, str("NET-3 (shells do not meet): ", bad,
                                  ". Move the run end nearer the joint node, or the shells never touch.")) true;

// NET-4 — the ball's own wall. A core sphere as large as the shell sphere leaves
// no material at all and opens the junction to the outside.
function _ut_net4(net) = let(
    bad = [for (j = ut_net_joints(net)) if (ut_joint_body(j) == "ball" &&
                                            ut_joint_shell_r(net, j) - ut_joint_core_r(net, j) <= ut_eps())
            str("joint at ", ut_joint_node(net, j))],
    thin = [for (j = ut_net_joints(net)) if (ut_joint_body(j) == "ball")
            let(w = ut_joint_shell_r(net, j) - ut_joint_core_r(net, j)) if (w > ut_eps() && w < ut_min_wall())
                str(ut_joint_node(net, j), " wall ", w)])
    assert(len(bad) == 0, str("NET-4: joint ball has no wall at ",
                              bad))(len(thin) == 0 ? true
                                                   : echo(str("WARNING [uniTube] NET-4: joint ball wall is below the ",
                                                              ut_min_wall(), " mm minimum at ", thin)) true);

// NET-5 — LUMEN GROUPS. With one global difference over the whole assembly, a
// coaxial jacket's outer bore swallows the inner tube entirely: measured, 26% of
// the material vanished while CGAL still reported `Simple: yes`. Two runs whose
// geometries can nest MUST be in different groups.
function _ut_net5(net) =
    let(bad = [for (g = ut_groups(net))
                let(rs = _ut_runs_in(net, g)) for (i = [0:max(0, len(rs) - 1)],
                                                   k = [0:max(0, len(rs) - 1)]) if (i != k && _ut_nests(rs[i], rs[k]))
                    str(ut_run_name(rs[k]), " nests inside ", ut_run_name(rs[i]), "'s bore")])
        assert(len(bad) == 0,
               str("NET-5 (lumen nesting): ", bad,
                   ". These runs share a lumen group, so the outer bore would delete the inner run entirely. ",
                   "Put the inner run in its own group: ut_run(name, path, prof, group=1).")) true;

// B nests inside A's bore when B fits within it AND the two are actually near
// each other. A heuristic on endpoints, documented as one -- it catches the real
// case (a jacket sharing a path) without a full path-distance computation.
function _ut_nests(a, b) = let(ra = ut_bore_inradius(ut_run_prof(a)), rb = ut_prof_reach(ut_run_prof(b))) ra
                           > rb &&min([for (pa = _ut_ends(a), pb = _ut_ends(b)) norm(pa - pb)]) < ra;
function _ut_ends(r) = let(p = ut_run_path(r))[ut_at(p, 0)[0], ut_at(p, ut_length(p))[0]];

// Validate a network. Returns true so it can sit in an assert.
// NET-0 — every RUN in the network gets the same analytic check a standalone
// run gets. ut_tube() has always called ut_check(); ut_assemble() did not, so
// CHECK-1 did not exist for the network layer at all -- which is the flagship
// capability. Measured: od=12 through an r=5.5 bend aborts via ut_tube and
// renders "Simple: yes" via ut_assemble.
function _ut_net0(net, i = 0) = let(rs = ut_net_runs(net)) i >= len(rs)
                                    ? true
                                    : ut_check(ut_run_path(rs[i]), ut_run_prof(rs[i])) && _ut_net0(net, i + 1);

// NET-6 — every run incident to a joint must share ONE lumen group. The joint's
// core sphere is cut in one group only, so a joint spanning two groups leaves
// material across the junction: measured +178.9 mm3 (+3.6%) on a two-run elbow,
// with ut_check_net returning true. Groups are the user's job by design, so a
// mis-declared group is the EXPECTED user error, and NET-5 already guards the
// opposite mistake.
function _ut_net6(net) = let(bad = [for (j = ut_net_joints(net))
                                     let(gs = _ut_uniq([for (e = ut_joint_incident(j))
                                                 ut_run_group(ut_net_run(net, e[0]))])) if (len(gs) > 1)
                                         str("joint at ", ut_joint_node(net, j), " spans lumen groups ", gs)])
    assert(
        len(bad) == 0,
        str("NET-6 (joint spans lumen groups): ", bad,
            ". Every run meeting at a joint must share one group, or the joint's core sphere is subtracted in one group only and leaves material across the junction.")) true;

function ut_check_net(net) = _ut_net0(net) && _ut_net1(net) && _ut_net2(net) && _ut_net3(net) && _ut_net4(net) &&
                             _ut_net5(net) && _ut_net6(net);
