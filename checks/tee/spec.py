"""Declared intent for the wall-landing tee (examples/10_tee_wall_landing.scad).

The claim that matters is LUMEN PATENCY. In design review this exact geometry
produced a 0.95 mm plug across the branch lumen while CGAL reported
`Simple: yes, Volumes: 2` and a naive manifoldness test passed. A keep_out down
the branch bore, crossing the trunk wall, is a check that plug cannot survive.
"""

from partspec import Part, openscad, region

TRUNK_OD = 20.0
BRANCH_ID = 8.0

# The keep-out must sit INSIDE the modelled bore, not at its nominal diameter:
# region.cylinder CIRCUMSCRIBES the declared circle while the modelled bore is
# INSCRIBED in its own $fn, so a keep-out at d=8 cannot pass. d=6 clears both.
PROBE_D = 6.0


def tee() -> Part:
    p = Part("unitube-tee", openscad("../../examples/10_tee_wall_landing.scad"))

    p.watertight()
    p.solid_count(1)

    # THE CHECK. Down the branch bore, starting on the trunk CENTRELINE and
    # running out past the branch's open end. It crosses the trunk wall at
    # y = 8..10, which is exactly where the plug formed.
    p.keep_out(
        region.cylinder(d=PROBE_D, h=48.0, at=(0.0, 0.0, 0.0), axis="y"),
        shell=1.5,
        id="branch_lumen_open",
    )

    # And the trunk's own lumen, straight through, unobstructed by the branch.
    # d=14 inside a d=16 bore: close enough that the trunk wall falls within the
    # shell. At d=12 the nearest material was 2 mm away and the claim was
    # refused as vacuous -- correctly, since an absent part would also satisfy it.
    p.keep_out(
        region.cylinder(d=14.0, h=90.0, at=(-45.0, 0.0, 0.0), axis="x"),
        shell=1.5,
        id="trunk_lumen_open",
    )

    return p
