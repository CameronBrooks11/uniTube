// MUST FAIL — NET-4, the joint ball's wall measured FACET TO FACET.
//
// Two od=20 id=17 runs meeting at a joint, at $fn=5. Comparing the two spheres
// by RADIUS says the ball has a 3.1 mm wall and everything is fine. The facets
// say -0.33 mm, and the junction has a hole punched clean through it -- rendered
// before this check existed, with CGAL reporting Simple: yes, Volumes: 2 and
// every gate passing.
// clang-format off
include <../../src/uniTube.scad>;
// clang-format on

$fn = 5;
prof = ut_round(od = 20, id = 17);
ut_assemble(ut_net(
    [
        ut_run("t", ut_polyline([ [ -40, 0, 0 ], [ 40, 0, 0 ] ]), prof),
        ut_run("b", ut_polyline([ [ 0, 10, 0 ], [ 0, 40, 0 ] ]), prof),
    ],
    [ut_joint([ [ "t", [ "s", 40 ] ], [ "b", "a" ] ])]));
