"""Declared intent for the 4-into-1 manifold (examples/06_manifold_4into1.scad).

This is the part the whole project exists to make, and it has never rendered in
any commit of this repository. `Simple: yes` proves nothing about it: the SEALED
version reports exactly the same. What must be true is that every inlet lumen
reaches the outlet lumen, and that is what the keep_out regions below assert.

Every probe sits INSIDE the modelled bore rather than at its nominal diameter:
region.cylinder CIRCUMSCRIBES the declared circle while the modelled bore is
INSCRIBED in its own $fn, so a keep-out at nominal d cannot pass.
"""

import math

from partspec import Part, openscad, region

N = 4
RING = 50.0
DROP = -55.0


def manifold() -> Part:
    p = Part("unitube-manifold-4into1", openscad("../../examples/06_manifold_4into1.scad"))

    p.watertight()
    p.solid_count(1)

    # THE JUNCTION VOID. If any inlet's wall sealed the shared lumen, or the
    # two-pass ran in the wrong order, material appears here. The joint's core
    # sphere has radius ~3.99 mm, so a box of half-extent 2.2 (corner at 3.81)
    # sits inside it.
    p.keep_out(
        region.box(min=(-2.2, -2.2, -2.2), max=(2.2, 2.2, 2.2)),
        shell=2.5,
        id="junction_void_open",
    )

    # The outlet lumen, from just above the joint to near the open end.
    p.keep_out(
        region.cylinder(d=11.0, h=45.0, at=(0.0, 0.0, 5.0), axis="z"),
        shell=1.0,
        id="outlet_lumen_open",
    )

    # Each inlet's lumen, on its straight lower leg.
    for i in range(N):
        th = math.radians(360.0 * i / N)
        p.keep_out(
            region.cylinder(
                d=6.0, h=17.0, at=(RING * math.cos(th), RING * math.sin(th), DROP + 2.0), axis="z"
            ),
            shell=1.5,
            id=f"inlet{i}_lumen_open",
        )

    return p
