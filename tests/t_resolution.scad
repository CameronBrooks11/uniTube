// t_resolution — the library across the resolutions a CONSUMER might set.
//
// Nothing under src/ sets $fa, $fs or $fn, so every one of them comes from the
// calling model. Every other gate pins exactly one resolution per example, so
// until this file existed the library's behaviour across resolutions had never
// been tested at all -- and a resolution-dependent hole through a junction sat
// there rendering `Simple: yes`.

// clang-format off
use <../src/uniTube.scad>;
// clang-format on

// A representative hollow tee, built fresh at each resolution because the
// profiles' point counts depend on it.
function tee() = ut_net(
    [
        ut_run("t", ut_polyline([ [ -50, 0, 0 ], [ 50, 0, 0 ] ]), ut_round(od = 20, wall = 2)),
        ut_run("b", ut_polyline([ [ 0, 10, 0 ], [ 0, 50, 0 ] ]), ut_round(od = 12, wall = 2)),
    ],
    [ut_joint([ [ "t", [ "s", 50 ] ], [ "b", "a" ] ])]);

// --- every analytic check holds across the whole usable range -----------------
for (n = [ 8, 12, 16, 24, 32, 48, 64, 96, 128 ])
{
    assert(ut_check_net(tee(), $fn = n), str("the network must validate at $fn=", n));
}
// And with $fa/$fs instead of $fn, which is the more common way to ask.
for (fa = [ 24, 12, 8, 6, 3, 1 ])
{
    assert(ut_check_net(tee(), $fa = fa, $fs = 0.5), str("the network must validate at $fa=", fa));
}

// --- the bore inradius converges to the nominal from BELOW, never above -------
// This is the property whose absence sized a subtracted sphere too large.
prof = ut_round(od = 20, id = 16, n = 8);
assert(ut_bore_inradius(prof) < 8, "a faceted bore holds a SMALLER sphere than its nominal radius");
assert(ut_bore_inradius(prof) > 0, "but a positive one");
for (n = [ 6, 12, 48 ])
{
    let(p2 = ut_round(od = 20, id = 16, n = n))
    {
        assert(ut_bore_inradius(p2) <= 8 + 1e-9, str("never above nominal, at n=", n));
        assert(ut_bore_inradius(p2) < ut_prof_reach(p2), str("and always inside the outer reach, at n=", n));
    }
}
// Finer sampling must get closer to nominal, never further.
assert(ut_bore_inradius(ut_round(od = 20, id = 16, n = 48)) > ut_bore_inradius(ut_round(od = 20, id = 16, n = 6)),
       "refining the profile must raise the inradius toward the nominal");

// --- the joint ball keeps a real wall across the range ------------------------
// Measured facet to facet. At $fn=5 on a thin-walled tee this goes NEGATIVE,
// which is a hole through the junction -- tests/guards/g_net4_facet_wall.scad.
for (n = [ 12, 24, 64 ])
{
    let(net = tee(), j = ut_net_joints(net)[0])
    {
        assert(ut_sphere_inradius(ut_joint_shell_r(net, j), $fn = n) - ut_joint_core_r(net, j) > 0,
               str("the joint ball must keep material between its facets at $fn=", n));
    }
}

cube(0.001); // sentinel
