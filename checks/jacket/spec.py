"""Declared intent for the coaxial jacket (examples/08_coaxial_jacket.scad).

A tube inside a tube. Under ONE global difference over the whole assembly, the
outer run's bore swallows the inner run's shell entirely: measured in design
review, 26% of the material silently deleted while CGAL still reported
`Simple: yes`. Lumen groups are the fix, and `solid_count(2)` is the claim that
would have caught the loss -- an assembly with the liner deleted has ONE solid.
"""

from partspec import Part, openscad, region


def jacket() -> Part:
    p = Part("unitube-coaxial-jacket", openscad("../../examples/08_coaxial_jacket.scad"))

    p.watertight()

    # THE CHECK. Two separate solids: the jacket and the liner inside it. If the
    # jacket's bore had swallowed the liner, this is 1.
    p.solid_count(2)

    # The liner's own lumen stays open along the first straight leg.
    p.keep_out(
        region.cylinder(d=6.0, h=30.0, at=(3.0, 0.0, 0.0), axis="x"),
        shell=1.5,
        id="liner_lumen_open",
    )

    # And the ANNULAR GAP between liner and jacket stays open -- that is the
    # space the jacket exists to provide. Sampled with a small box at radius ~9,
    # between the liner's outer surface (r=6) and the jacket's bore (r=13).
    p.keep_out(
        region.box(min=(18.0, 7.5, -1.5), max=(24.0, 10.5, 1.5)),
        shell=2.0,
        id="annulus_open",
    )

    return p
