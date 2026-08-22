// MUST FAIL — NET-6. A joint whose incident runs sit in different lumen groups.
// The joint's core sphere is cut in ONE group only, so material is left across
// the junction: measured +178.9 mm3 (+3.6%) on this exact elbow, with
// ut_check_net returning true and CGAL reporting "Simple: yes".
// clang-format off
use <../../src/uniTube.scad>;
// clang-format on
prof = ut_round(od = 12, id = 8);
a = ut_run("a", ut_polyline([ [ 0, 0, 0 ], [ 40, 0, 0 ] ]), prof, group = 0);
b = ut_run("b", ut_polyline([ [ 40, 0, 0 ], [ 40, 40, 0 ] ]), prof, group = 1);
ut_assemble(ut_net([ a, b ], [ut_joint([ [ "a", "b" ], [ "b", "a" ] ])]));
