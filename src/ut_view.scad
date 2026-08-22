// ut_view — inspection helpers. Nothing here is part of a part.
//
// This exists because a shaded render of a hollow tube is genuinely ambiguous:
// an open bore seen at a shallow angle and a sealed end look the same, and
// `Simple: yes` does not settle it either -- a sealed lumen reports exactly that.
//
// A cut answers BOTH of the questions these models raise, because they are the
// same question. It shows the bore directly, and on any section that is not
// rotationally symmetric -- a split, a square bore, a keyway -- the orientation
// of the cut face IS the roll. Nothing else is needed to see it.

// clang-format off
use <ut_core.scad>;
use <ut_math.scad>;
// clang-format on

// Cut the half-space on the +normal side away from whatever is passed in.
//
//     ut_cutaway() part();                       // default: remove +Y
//     ut_cutaway([0,0,1], at = 5) part();        // remove everything above z=5
//     ut_cutaway(on = SECTION) part();           // togglable from one variable
//
// `on = false` passes the children through untouched, so a model can carry the
// wrapper permanently and be switched with a single top-level variable.
//
// This is a VIEW, not a part: it forces a CSG difference, so never leave it on
// around geometry being exported for printing.
module ut_cutaway(normal = [ 0, 1, 0 ], at = 0, on = true, size = 1000)
{
    if (!on)
    {
        children();
    }
    else
    {
        difference()
        {
            children();
            translate(ut_unit(normal) * at) _ut_halfspace(ut_unit(normal), size);
        }
    }
}

module _ut_halfspace(n, size)
{
    u = ut_ref_fallback(n);
    v = cross(n, u);
    multmatrix([[u [0], v [0], n [0], 0], [u [1], v [1], n [1], 0], [u [2], v [2], n [2], 0], [0, 0, 0, 1]])
        translate([ -size / 2, -size / 2, 0 ]) cube(size);
}
